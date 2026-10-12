-- Owns each player's aura (saved, with their class), style meter, combat
-- timers and the heroic / villain line handling.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local AuraMath = require(Shared:WaitForChild("AuraMath"))
local Classes = require(Shared:WaitForChild("Classes"))
local HeroicLines = require(Shared:WaitForChild("HeroicLines"))
local Effects = require(script.Parent.Effects)
local Remotes = require(script.Parent.Remotes)

local AuraService = {}

export type State = {
	aura: number,
	loaded: boolean,
	savedClassId: string?,
	style: number,
	lastStyleGain: number,
	lastDodge: number,
	lastHit: number,
	lastKill: number,
	lastHeroicLine: number,
	lastLineTime: number,
	lineHistory: { [string]: number },
	lastMessage: string,
	lastMessageTime: number,
	lastSlash: number,
	lastDash: number,
	dashStartPos: Vector3?,
	invulnerableUntil: number,
	lastUltimate: number,
	-- PvP bookkeeping (see PvpService)
	lastAttacker: Player?,
	lastAttackTime: number,
	lastAttackSource: string,
	lastAttackStyle: number, -- attacker's style when they last hit us
	dodgedDash: number, -- the dash a PvP perfect dodge was already given for
	lastKilledBy: Player?,
	kills: { [number]: { number } }, -- victim UserId -> times defeated
	lastClassChange: number,
	rankIndex: number,
	auraValue: IntValue,
	rankValue: StringValue,
}

local states: { [Player]: State } = {}

-- Supplies { inFight, foeHealthFraction } for a player. Main sets this from
-- BossService and PvpService (they can't be required from here without a
-- require cycle).
local contextProvider = function(_player: Player)
	return { inFight = false, foeHealthFraction = nil }
end

function AuraService.setContextProvider(fn)
	contextProvider = fn
end

---------------------------------------------------------------------------
-- Class helpers (the class lives in player attributes, set by ClassService)
---------------------------------------------------------------------------

function AuraService.sideOf(player: Player): string?
	local side = player:GetAttribute("Side")
	return if side == "Good" or side == "Evil" then side else nil
end

-- The player's class, or nil while they're undecided.
function AuraService.classOf(player: Player)
	return Classes.get(player:GetAttribute("ClassId"))
end

-- A class stat, falling back to the defaults for undecided players.
function AuraService.stat(player: Player, key: string): number
	local class = AuraService.classOf(player)
	if class then
		return class[key]
	end
	return Classes.Defaults[key]
end

---------------------------------------------------------------------------
-- Saving
---------------------------------------------------------------------------

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[AuraFarm] DataStore unavailable, aura won't be saved:", result)
	end
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

-- Returns saved aura and class id.
local function load(player: Player): (number, string?)
	if not store then
		return 0, nil
	end
	local ok, result = pcall(function()
		return store:GetAsync(key(player))
	end)
	if not ok then
		warn("[AuraFarm] Couldn't load aura for", player.Name, result)
		return 0, nil
	end
	if type(result) == "table" then
		local aura = if type(result.Aura) == "number" then result.Aura else 0
		local classId = if Classes.get(result.ClassId) then result.ClassId else nil
		return aura, classId
	end
	return 0, nil
end

function AuraService.save(player: Player)
	local state = states[player]
	-- Never overwrite saved aura with a profile that failed to load.
	if not store or not state or not state.loaded then
		return
	end
	local classId = player:GetAttribute("ClassId") or state.savedClassId
	local ok, err = pcall(function()
		store:SetAsync(key(player), { Aura = state.aura, ClassId = classId })
	end)
	if not ok then
		warn("[AuraFarm] Couldn't save aura for", player.Name, err)
	end
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

function AuraService.get(player: Player): State?
	return states[player]
end

local function notify(player: Player, payload)
	Remotes.Notify:FireClient(player, payload)
end
AuraService.notify = notify

-- Tells every player (except `except`, if given) about something.
function AuraService.announce(text: string, except: Player?)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= except then
			notify(player, { Kind = "Announce", Text = text })
		end
	end
end

function AuraService.rankName(player: Player): string
	local state = states[player]
	local rank = Config.Ranks[state and state.rankIndex or 1]
	return AuraMath.rankName(rank, AuraService.sideOf(player))
end

-- Re-applies rank name, overhead tag and aura particles.
function AuraService.refreshVisuals(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.rankValue.Value = AuraService.rankName(player)
	local character = player.Character
	if not character then
		return
	end
	local rank = Config.Ranks[state.rankIndex]
	local color = Effects.color(rank.Color)
	local class = AuraService.classOf(player)
	local classLabel = if class then class.Name else "Undecided"
	local sideColor = if class then Effects.color(Classes.Sides[class.Side].Color) else Color3.fromRGB(200, 200, 200)
	Effects.updateOverhead(character, AuraService.rankName(player), color, state.aura, classLabel, sideColor)
	Effects.setAura(character, state.rankIndex, if class then Effects.color(class.Color) else color)
end

--[[
	Adds (or with a negative amount, removes) aura. Aura never drops below 0.
	title/tags describe why, for the client's popup. silent skips the popup
	(used for small per-hit aura and for big rewards, which get a banner).
]]
function AuraService.addAura(player: Player, amount: number, title: string?, tags: { string }?, silent: boolean?)
	local state = states[player]
	if not state or amount == 0 then
		return
	end
	state.aura = math.max(0, state.aura + amount)
	state.auraValue.Value = state.aura

	local rank, index = AuraMath.getRank(state.aura, Config.Ranks)
	if index ~= state.rankIndex then
		local rankedUp = index > state.rankIndex
		state.rankIndex = index
		if rankedUp then
			local name = AuraMath.rankName(rank, AuraService.sideOf(player))
			notify(player, { Kind = "RankUp", Rank = name, Color = rank.Color })
			AuraService.announce(string.format("%s is now a %s!", player.DisplayName, name), player)
		end
	end
	AuraService.refreshVisuals(player)

	if not silent then
		notify(player, { Kind = "Aura", Amount = amount, Title = title or "", Tags = tags or {} })
	end
end

---------------------------------------------------------------------------
-- Style meter
---------------------------------------------------------------------------

local function setStyle(player: Player, state: State, value: number)
	state.style = math.clamp(value, 0, Config.Style.Max)
	player:SetAttribute("Style", math.floor(state.style + 0.5))
end

-- Gains are multiplied by the class's StyleGain; losses aren't.
function AuraService.addStyle(player: Player, amount: number)
	local state = states[player]
	if not state then
		return
	end
	if amount > 0 then
		state.lastStyleGain = os.clock()
		amount *= AuraService.stat(player, "StyleGain")
	end
	setStyle(player, state, state.style + amount)
end

function AuraService.resetStyle(player: Player)
	local state = states[player]
	if state then
		setStyle(player, state, 0)
	end
end

function AuraService.styleRank(player: Player)
	local state = states[player]
	return AuraMath.getRank(state and state.style or 0, Config.Style.Ranks)
end

---------------------------------------------------------------------------
-- Damage and combat bookkeeping (called by Combat / BossService / PvpService)
---------------------------------------------------------------------------

-- Hurts a player, reduced by their class armor. Returns the damage dealt
-- (0 if they're invincible from a dash or Fortify).
function AuraService.takeDamage(player: Player, amount: number): number
	local state = states[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not state or not humanoid or humanoid.Health <= 0 then
		return 0
	end
	if os.clock() < state.invulnerableUntil then
		return 0
	end
	local dealt = amount * (1 - AuraService.stat(player, "Armor"))
	humanoid:TakeDamage(dealt)
	state.lastHit = os.clock()
	AuraService.addStyle(player, -Config.Style.LostWhenHit)
	return dealt
end

function AuraService.heal(player: Player, amount: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and amount > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
end

-- Lifesteal for damage the player dealt.
function AuraService.onDealtDamage(player: Player, amount: number)
	local lifesteal = AuraService.stat(player, "Lifesteal")
	if lifesteal > 0 then
		AuraService.heal(player, amount * lifesteal)
	end
end

function AuraService.onPerfectDodge(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.lastDodge = os.clock()
	AuraService.addStyle(player, Config.Style.PerPerfectDodge)
	local styleRank = AuraService.styleRank(player)
	local amount = math.floor(Config.Combat.PerfectDodgeAura * styleRank.Multiplier + 0.5)
	AuraService.addAura(player, amount, "PERFECT DODGE", { "STYLE " .. styleRank.Name })
end

-- After a big win: walk away from `position` without looking back.
function AuraService.startWalkAwayCheck(player: Player, position: Vector3)
	local settings = Config.WalkAway
	local function rootOf(): BasePart?
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return nil
		end
		return character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	local function flatDistance(at: Vector3): number
		return Vector3.new(at.X - position.X, 0, at.Z - position.Z).Magnitude
	end
	task.spawn(function()
		local startRoot = rootOf()
		if not startRoot then
			return
		end
		-- Uses positions rather than Humanoid.MoveDirection, which the API
		-- marks as not replicated.
		local lastDistance = flatDistance(startRoot.Position)
		local samples, good = 0, 0
		local elapsed = 0
		while elapsed < settings.Duration do
			task.wait(settings.SampleInterval)
			elapsed += settings.SampleInterval
			local root = rootOf()
			if not root then
				return
			end
			samples += 1
			local look = root.CFrame.LookVector
			local toTarget = position - root.Position
			local distance = flatDistance(root.Position)
			if AuraMath.isWalkingAway(look.X, look.Z, toTarget.X, toTarget.Z, distance - lastDistance) then
				good += 1
			end
			lastDistance = distance
		end
		if samples > 0 and good / samples >= settings.RequiredFraction then
			AuraService.addAura(player, settings.Aura, settings.Label, { "Cool people don't look at explosions" })
		end
	end)
end

---------------------------------------------------------------------------
-- Heroic / villain lines
---------------------------------------------------------------------------

function AuraService.handleMessage(player: Player, text: any)
	local state = states[player]
	if not state or type(text) ~= "string" or #text == 0 or #text > 200 then
		return
	end
	local now = os.clock()

	-- The same message can arrive twice (Player.Chatted and the client's
	-- chat hook); only score it once.
	local normalized = HeroicLines.normalize(text)
	if normalized == state.lastMessage and now - state.lastMessageTime < 2 then
		return
	end
	state.lastMessage, state.lastMessageTime = normalized, now

	if now - state.lastLineTime < Config.LineGlobalCooldown then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local fight = contextProvider(player)
	local context = {
		inFight = fight.inFight,
		foeHealthFraction = fight.foeHealthFraction,
		healthFraction = if humanoid and humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1,
		sinceDodge = now - state.lastDodge,
		sinceHit = now - state.lastHit,
		sinceKill = now - state.lastKill,
	}

	local side = AuraService.sideOf(player)
	local result = HeroicLines.evaluate(text, context, Config, state.lineHistory, now, side)
	if result.kind == "None" then
		return
	end
	state.lastLineTime = now
	state.lineHistory[result.historyKey] = now

	if result.kind == "Repeat" then
		AuraService.addAura(player, result.amount, "AURA LOSS", result.tags)
		return
	end

	state.lastHeroicLine = now
	if context.inFight then
		AuraService.addStyle(player, Config.Style.PerHeroicLineInFight)
	end
	local title = if side == "Evil" then "Villainous freestyle" else "Freestyle heroics"
	if result.line then
		title = "\u{201C}" .. result.line.Text .. "\u{201D}"
		if character then
			local speechColor = if side == "Evil" then Color3.fromRGB(255, 110, 110) else Color3.fromRGB(255, 240, 160)
			Effects.showSpeech(character, result.line.Text, Config.SpeechDuration, speechColor)
		end
	end
	AuraService.addAura(player, result.amount, title, result.tags)
end

---------------------------------------------------------------------------
-- Player lifecycle
---------------------------------------------------------------------------

function AuraService.setupCharacter(player: Player, character: Model)
	character:WaitForChild("Head", 10)
	character:WaitForChild("HumanoidRootPart", 10)
	Effects.buildOverhead(character)
	local class = AuraService.classOf(player)
	Effects.buildSword(character, if class then Effects.color(class.Color) else nil)
	AuraService.refreshVisuals(player)
	local state = states[player]
	if state then
		setStyle(player, state, 0)
		state.invulnerableUntil = 0
		state.lastAttacker = nil
	end
end

-- Calls onLoaded(savedClassId) once the player's save has loaded (or failed).
function AuraService.setupPlayer(player: Player, onLoaded: (string?) -> ())
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local auraValue = Instance.new("IntValue")
	auraValue.Name = "Aura"
	auraValue.Parent = leaderstats
	local rankValue = Instance.new("StringValue")
	rankValue.Name = "Rank"
	rankValue.Value = Config.Ranks[1].Name
	rankValue.Parent = leaderstats
	leaderstats.Parent = player

	local never = -math.huge
	local state: State = {
		aura = 0,
		loaded = false,
		savedClassId = nil,
		style = 0,
		lastStyleGain = never,
		lastDodge = never,
		lastHit = never,
		lastKill = never,
		lastHeroicLine = never,
		lastLineTime = never,
		lineHistory = {},
		lastMessage = "",
		lastMessageTime = never,
		lastSlash = never,
		lastDash = never,
		dashStartPos = nil,
		invulnerableUntil = 0,
		lastUltimate = never,
		lastAttacker = nil,
		lastAttackTime = never,
		lastAttackSource = "",
		lastAttackStyle = 0,
		dodgedDash = never,
		lastKilledBy = nil,
		kills = {},
		lastClassChange = never,
		rankIndex = 1,
		auraValue = auraValue,
		rankValue = rankValue,
	}
	states[player] = state
	player:SetAttribute("Style", 0)

	-- Load in the background so the player's state exists right away.
	task.spawn(function()
		local saved, classId = load(player)
		if states[player] ~= state then
			return -- left while loading
		end
		state.loaded = true
		state.savedClassId = classId
		if saved > 0 then
			-- Silent: just restoring, not earning. Keep anything earned
			-- while the load was in flight.
			state.aura += saved
			auraValue.Value = state.aura
			local _, index = AuraMath.getRank(state.aura, Config.Ranks)
			state.rankIndex = index
			AuraService.refreshVisuals(player)
		end
		onLoaded(classId)
	end)
end

function AuraService.removePlayer(player: Player)
	AuraService.save(player)
	states[player] = nil
	-- Forget this player in everyone else's PvP bookkeeping.
	for _, state in pairs(states) do
		if state.lastAttacker == player then
			state.lastAttacker = nil
		end
		if state.lastKilledBy == player then
			state.lastKilledBy = nil
		end
	end
end

-- Style decay and autosave.
function AuraService.start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		local step = accumulator
		accumulator = 0
		local now = os.clock()
		for player, state in pairs(states) do
			if state.style > 0 then
				local decayed = AuraMath.decayStyle(state.style, now - state.lastStyleGain, step, Config.Style)
				if decayed ~= state.style then
					setStyle(player, state, decayed)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(AuraService.save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				AuraService.save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 20
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return AuraService
