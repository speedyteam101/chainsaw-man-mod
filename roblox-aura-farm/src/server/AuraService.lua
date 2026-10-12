-- Owns each player's aura (saved), style meter, combat timers and the
-- heroic-line handling.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local AuraMath = require(Shared:WaitForChild("AuraMath"))
local HeroicLines = require(Shared:WaitForChild("HeroicLines"))
local Effects = require(script.Parent.Effects)
local Remotes = require(script.Parent.Remotes)

local AuraService = {}

export type State = {
	aura: number,
	loaded: boolean,
	style: number,
	lastStyleGain: number,
	lastDodge: number,
	lastHit: number,
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
	rankIndex: number,
	auraValue: IntValue,
	rankValue: StringValue,
}

local states: { [Player]: State } = {}

-- Supplies { inBossFight, bossHealthFraction } for a player. BossService sets
-- this (it can't be required from here without a require cycle).
local contextProvider = function(_player: Player)
	return { inBossFight = false, bossHealthFraction = nil }
end

function AuraService.setContextProvider(fn)
	contextProvider = fn
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

local function load(player: Player): number
	if not store then
		return 0
	end
	local ok, result = pcall(function()
		return store:GetAsync(key(player))
	end)
	if not ok then
		warn("[AuraFarm] Couldn't load aura for", player.Name, result)
		return 0
	end
	if type(result) == "table" and type(result.Aura) == "number" then
		return result.Aura
	end
	return 0
end

function AuraService.save(player: Player)
	local state = states[player]
	-- Never overwrite saved aura with a profile that failed to load.
	if not store or not state or not state.loaded then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(key(player), { Aura = state.aura })
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

local function refreshVisuals(player: Player)
	local state = states[player]
	local character = player.Character
	if not state or not character then
		return
	end
	local rank = Config.Ranks[state.rankIndex]
	local color = Effects.color(rank.Color)
	Effects.updateOverhead(character, rank.Name, color, state.aura)
	Effects.setAura(character, state.rankIndex, color)
end

--[[
	Adds (or with a negative amount, removes) aura. Aura never drops below 0.
	title/tags describe why, for the client's popup. silent skips the popup
	(used for small per-hit aura and for boss rewards, which get a banner).
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
		state.rankValue.Value = rank.Name
		if rankedUp then
			notify(player, { Kind = "RankUp", Rank = rank.Name, Color = rank.Color })
			AuraService.announce(string.format("%s is now a %s!", player.DisplayName, rank.Name), player)
		end
	end
	refreshVisuals(player)

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

function AuraService.addStyle(player: Player, amount: number)
	local state = states[player]
	if not state then
		return
	end
	if amount > 0 then
		state.lastStyleGain = os.clock()
	end
	setStyle(player, state, state.style + amount)
end

function AuraService.styleRank(player: Player)
	local state = states[player]
	return AuraMath.getRank(state and state.style or 0, Config.Style.Ranks)
end

---------------------------------------------------------------------------
-- Combat bookkeeping (called by Combat / BossService)
---------------------------------------------------------------------------

function AuraService.onHurt(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.lastHit = os.clock()
	AuraService.addStyle(player, -Config.Style.LostWhenHit)
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

function AuraService.onDiedInFight(player: Player)
	local state = states[player]
	if not state then
		return
	end
	setStyle(player, state, 0)
	AuraService.addAura(player, -Config.Combat.DeathAuraLoss, "TOOK THE L", { "Fell in battle" })
end

---------------------------------------------------------------------------
-- Heroic lines
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
		inBossFight = fight.inBossFight,
		bossHealthFraction = fight.bossHealthFraction,
		healthFraction = if humanoid and humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1,
		sinceDodge = now - state.lastDodge,
		sinceHit = now - state.lastHit,
	}

	local result = HeroicLines.evaluate(text, context, Config, state.lineHistory, now)
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
	if context.inBossFight then
		AuraService.addStyle(player, Config.Style.PerHeroicLineInFight)
	end
	local title = "Freestyle heroics"
	if result.line then
		title = "\u{201C}" .. result.line.Text .. "\u{201D}"
		if character then
			Effects.showSpeech(character, result.line.Text, Config.SpeechDuration)
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
	Effects.buildSword(character)
	refreshVisuals(player)
	local state = states[player]
	if state then
		setStyle(player, state, 0)
		state.invulnerableUntil = 0
	end
end

function AuraService.setupPlayer(player: Player)
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
		style = 0,
		lastStyleGain = never,
		lastDodge = never,
		lastHit = never,
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
		rankIndex = 1,
		auraValue = auraValue,
		rankValue = rankValue,
	}
	states[player] = state
	player:SetAttribute("Style", 0)

	-- Load in the background so the player's state exists right away.
	task.spawn(function()
		local saved = load(player)
		if states[player] ~= state then
			return -- left while loading
		end
		state.loaded = true
		if saved > 0 then
			-- Silent: just restoring, not earning. Keep anything earned
			-- while the load was in flight.
			state.aura += saved
			auraValue.Value = state.aura
			local rank, index = AuraMath.getRank(state.aura, Config.Ranks)
			state.rankIndex = index
			rankValue.Value = rank.Name
			refreshVisuals(player)
		end
	end)
end

function AuraService.removePlayer(player: Player)
	AuraService.save(player)
	states[player] = nil
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
