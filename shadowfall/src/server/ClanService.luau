--!nonstrict
-- Clans: rolling (3 free, then Essence, with pity), choosing, and Mythic+ Modes.
--
-- Rolling adds the result to your "options"; you then pick which one to keep. In the character
-- creator the free rolls pile up (pick any of them). A paid reroll later offers your current clan
-- or the new one, like a power reroll.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clans = require(ReplicatedStorage.Shared.Clans)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local PassService = require(script.Parent.PassService)

local ClanService = {}
ClanService.OnRolled = nil :: ((Player, string) -> ())? -- set by Main (feats)

local K = Config.Clans
local rng = Random.new()

-- Applies the clan's always-on effects that live outside combat maths: speed and max health.
function ClanService.Apply(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local clan = Clans.Of(data.clan)
	player:SetAttribute("Clan", data.clan or "")
	local state = Combat.GetState(player)
	local mode = clan.mode and os.clock() < (state.clanModeUntil or 0) and clan.mode or nil
	local speed = (clan.speed or 1) * (mode and mode.speed or 1)
	player:SetAttribute("ClanSpeed", speed ~= 1 and speed or nil)
	local _, humanoid = Combat.GetCharacter(player)
	if humanoid and data.act == 2 then
		local wanted = Combat.MaxHealthFor(data)
		if math.abs(humanoid.MaxHealth - wanted) > 0.5 then
			local fraction = humanoid.Health / math.max(1, humanoid.MaxHealth)
			humanoid.MaxHealth = wanted
			humanoid.Health = math.min(wanted, wanted * fraction)
		end
	end
end

function ClanService.Roll(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return { ok = false }
	end
	data.clanOptions = data.clanOptions or {}
	local free = (data.clanFreeRolls or 0) > 0
	if free then
		data.clanFreeRolls -= 1
	else
		if data.act ~= 2 then
			return { ok = false, message = "You're out of free clan rolls." }
		end
		if data.essence < K.RerollCost then
			return { ok = false, message = string.format("A clan reroll costs %d Essence (you have %d).", K.RerollCost, data.essence) }
		end
		data.essence -= K.RerollCost
		-- A paid reroll: keep what you have, or take the new one.
		data.clanOptions = data.clan and { data.clan } or {}
	end
	data.clanPity = (data.clanPity or 0) + 1
	local clan = Clans.Roll(rng, data.clanPity >= K.PityAt, PassService.RollLuck(player))
	if Clans.RarityRank[clan.rarity] >= Clans.RarityRank.Legendary then
		data.clanPity = 0
	end
	table.insert(data.clanOptions, clan.id)
	if ClanService.OnRolled then
		ClanService.OnRolled(player, clan.id)
	end
	PlayerData.Sync(player)
	return { ok = true, clan = clan.id, options = data.clanOptions, free = data.clanFreeRolls, current = data.clan }
end

function ClanService.Choose(player: Player, clanId)
	local data = PlayerData.Get(player)
	if not data or type(clanId) ~= "string" or not Clans.ById[clanId] then
		return { ok = false }
	end
	if not table.find(data.clanOptions or {}, clanId) then
		return { ok = false, message = "That clan isn't one of your rolls." }
	end
	data.clan = clanId
	data.clanOptions = {}
	ClanService.Apply(player)
	PlayerData.Sync(player)
	PlayerData.Save(player)
	return { ok = true, clan = clanId }
end

-- Makes sure the player ends up with a clan (after the character creator).
function ClanService.Finalize(player: Player)
	local data = PlayerData.Get(player)
	if not data or data.clan then
		return
	end
	if #(data.clanOptions or {}) == 0 then
		data.clanFreeRolls = math.max(1, data.clanFreeRolls or 0)
		ClanService.Roll(player)
	end
	local options = data.clanOptions
	-- They never picked: keep the best one they rolled.
	local best = options[1]
	for _, id in options do
		if Clans.RarityRank[Clans.ById[id].rarity] > Clans.RarityRank[Clans.ById[best].rarity] then
			best = id
		end
	end
	data.clan = best
	data.clanOptions = {}
	ClanService.Apply(player)
	PlayerData.Sync(player)
end

-- Mythic and Transcendent clans: the Mode transformation.
function ClanService.Mode(player: Player)
	local data = PlayerData.Get(player)
	local clan = Clans.Of(data and data.clan)
	local mode = clan.mode
	if not data or data.act ~= 2 or not mode then
		return
	end
	local character = Combat.GetCharacter(player)
	if not character then
		return
	end
	local state = Combat.GetState(player)
	local now = os.clock()
	if now < (state.clanModeReady or 0) then
		return
	end
	state.clanModeReady = now + mode.cooldown
	state.clanModeUntil = now + mode.duration
	ClanService.Apply(player)
	Remotes.Fx:FireAllClients("ClanMode", { character = character, color = mode.color, duration = mode.duration, name = mode.name, clan = clan.id })
	Remotes.Notify:FireClient(player, "ModeCooldown", { duration = mode.cooldown, active = mode.duration })

	-- Seen by everyone: an outline in the clan's colour for the duration.
	local highlight = Instance.new("Highlight")
	highlight.Name = "ClanMode"
	highlight.FillColor = mode.color
	highlight.FillTransparency = 0.75
	highlight.OutlineColor = mode.color
	highlight.OutlineTransparency = 0
	highlight.Parent = character
	task.delay(mode.duration, function()
		if highlight.Parent then
			highlight:Destroy()
		end
		if player.Parent then
			ClanService.Apply(player) -- speed back to normal
		end
	end)
end

return ClanService
