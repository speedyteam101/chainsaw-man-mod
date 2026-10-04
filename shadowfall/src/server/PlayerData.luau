--!nonstrict
-- Loads and saves player progress with DataStoreService.
-- If DataStores are unavailable (e.g. Studio without "Enable Studio Access to API Services"),
-- the game still runs; progress just isn't saved and a warning is printed.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Achievements = require(ReplicatedStorage.Shared.Achievements)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Townsfolk = require(ReplicatedStorage.Shared.Townsfolk)
local Passes = require(ReplicatedStorage.Shared.Passes)

local PlayerData = {}

PlayerData.SpawnOverride = nil :: ((Player) -> boolean)? -- set by Main (LookService.Spawn)

local profiles: { [Player]: any } = {}
local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore(Config.DataStoreName)
end)
if not storeOk then
	warn("[Shadowfall] DataStore unavailable, progress will not be saved:", store)
	store = nil
end

local function defaults()
	return {
		version = 1,
		act = 1,
		act1Stage = 0, -- 0 = the intro (save Biscuit)
		duckSaved = false,
		power = nil,
		level = 1,
		achievements = {},
		essence = 0,
		pity = 0,
		totalRolls = 0,
		stats = { kills = 0, parries = 0, perfectDodges = 0, bruteClean = 0, crafted = 0, built = 0 },
		inventory = {}, -- [materialId] = count
		items = {}, -- [recipeId] = count (tools/gear: 1, consumables: stack)
		rescued = {}, -- [townsfolkId] = true
		base = { placed = false, level = 1, x = 0, y = 0, z = 0, structures = {}, cleared = {} },
		story = { chapter = 1, seen = {}, pages = {} },
		tokens = 0,
		essenceTraded = 0, -- lifetime Essence traded for Tokens (the newcomer rate uses this)
		welcomeTokens = false,
		passes = {}, -- [passId] = true
		vault = {}, -- [powerId] = true (Power Vault pass)
		duckOutfit = 1,
		auraOn = true, -- Radiant Aura pass
		-- clan = nil until chosen (Clans.luau)
		clanFreeRolls = 3,
		clanOptions = {}, -- rolled clans waiting to be picked
		clanPity = 0,
		-- look = nil until the character creator is finished (see Looks.luau)
	}
end

-- Fill in fields added in later versions without wiping old saves.
local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
	return data
end

local function key(player: Player)
	return "player_" .. player.UserId
end

function PlayerData.Load(player: Player)
	local data
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(key(player))
			end)
			if ok then
				data = result
				break
			end
			warn("[Shadowfall] Load failed (attempt " .. attempt .. "):", result)
			task.wait(1.5 * attempt)
		end
	end
	data = reconcile(type(data) == "table" and data or {}, defaults())
	-- Saves made before the intro existed are already past it: give them Biscuit.
	if not data.duckSaved and (data.act == 2 or data.act1Stage >= 1) then
		data.duckSaved = true
	end
	profiles[player] = data
	PlayerData.Sync(player)
	return data
end

function PlayerData.Get(player: Player)
	return profiles[player]
end

function PlayerData.Save(player: Player)
	local data = profiles[player]
	if not data or not store then
		return
	end
	if RunService:IsStudio() and player.UserId <= 0 then
		return -- local test players
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:SetAsync(key(player), data)
		end)
		if ok then
			return
		end
		warn("[Shadowfall] Save failed (attempt " .. attempt .. "):", err)
		task.wait(1.5 * attempt)
	end
end

function PlayerData.Release(player: Player)
	PlayerData.Save(player)
	profiles[player] = nil
end

-- Progress toward feats that have a goal, for the feat list.
local function progressOf(player: Player, data)
	local Registry = require(script.Parent.Registry)
	local state = Registry.PlayerState[player]
	local session = state and state.session or {}
	return {
		untouchable = session.noDamageStreak or 0,
		steady_hand = data.stats.parries,
		shadowstep = data.stats.perfectDodges,
		giant_slayer = data.stats.bruteClean,
		unbroken = session.noDeathStreak or 0,
		last_light = session.noDeathStreak or 0,
		hundred = data.stats.kills,
		good_neighbour = Townsfolk.Count(data.rescued),
		full_house = Townsfolk.Count(data.rescued),
		master_builder = data.stats.built,
		crafter = data.stats.crafted,
		archivist = (function()
			local found = 0
			for _ in (data.story and data.story.pages) or {} do
				found += 1
			end
			return found
		end)(),
	}
end

-- Pushes the important values to attributes (cheap, replicated) and sends the full
-- snapshot (feats, progress) to the owning client.
function PlayerData.Sync(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	player:SetAttribute("Act", data.act)
	player:SetAttribute("Act1Stage", data.act1Stage)
	player:SetAttribute("Level", data.level)
	player:SetAttribute("Power", data.power or "")
	player:SetAttribute("Essence", data.essence)
	player:SetAttribute("Pity", data.pity)
	player:SetAttribute("Tokens", data.tokens)
	player:SetAttribute("Clan", data.clan or "")
	player:SetAttribute("PassSpeed", if data.passes.swift then Passes.SpeedMultiplier else nil) -- Fleet Feet
	player:SetAttribute(
		"CanAscend",
		data.act == 2 and data.level < Config.MaxLevel and Achievements.IsQualified(data.achievements, data.level + 1)
	)
	Remotes.Notify:FireClient(player, "State", {
		achievements = data.achievements,
		progress = progressOf(player, data),
		totalRolls = data.totalRolls,
		kills = data.stats.kills,
		inventory = data.inventory,
		items = data.items,
		rescued = data.rescued,
		baseLevel = data.base.level,
		basePlaced = data.base.placed,
		duckSaved = data.duckSaved,
		story = data.story,
		passes = data.passes,
		vault = data.vault,
		essenceTraded = data.essenceTraded,
		duckOutfit = data.duckOutfit,
		auraOn = data.auraOn,
		clan = data.clan,
		clanOptions = data.clanOptions,
		clanFreeRolls = data.clanFreeRolls,
		look = data.look,
	})
end

-- (Re)spawns a player's character. LoadCharacterAsync is the current API; fall back to the older
-- LoadCharacter in case the running engine version doesn't have it.
function PlayerData.Respawn(player: Player)
	if not player.Parent then
		return
	end
	-- Wear the look from the character creator, if one was chosen.
	if PlayerData.SpawnOverride and PlayerData.SpawnOverride(player) then
		return
	end
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
	end)
	if not ok then
		local fallbackOk, fallbackErr = pcall(function()
			(player :: any):LoadCharacter()
		end)
		if not fallbackOk then
			warn("[Shadowfall] Could not spawn", player.Name, err, fallbackErr)
		end
	end
end

function PlayerData.StartAutosave()
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for player in profiles do
				task.spawn(PlayerData.Save, player)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				PlayerData.Save(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
end

return PlayerData
