--!nonstrict
-- Server entry point: builds the world, starts every service, spawns players, and routes remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Achievements = require(ReplicatedStorage.Shared.Achievements)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Server = script.Parent
local WorldBuilder = require(Server.World.WorldBuilder)
local Registry = require(Server.Registry)
local PlayerData = require(Server.PlayerData)
local Combat = require(Server.Combat)
local Projectiles = require(Server.Projectiles)
local EnemyService = require(Server.EnemyService)
local PowerService = require(Server.PowerService)
local AchievementService = require(Server.AchievementService)
local Act1Director = require(Server.Act1Director)
local ZoneService = require(Server.ZoneService)
local InventoryService = require(Server.InventoryService)
local DuckService = require(Server.DuckService)
local SanityService = require(Server.SanityService)
local GatherService = require(Server.GatherService)
local CraftingService = require(Server.CraftingService)
local BaseService = require(Server.BaseService)
local RescueService = require(Server.RescueService)
local AllyService = require(Server.AllyService)
local ShopService = require(Server.ShopService)
local StoryService = require(Server.StoryService)
local PassService = require(Server.PassService)
local LookService = require(Server.LookService)
local Townsfolk = require(ReplicatedStorage.Shared.Townsfolk)
local Materials = require(ReplicatedStorage.Shared.Materials)

Players.CharacterAutoLoads = false

local world = WorldBuilder.Build()
Registry.World = world
task.wait() -- let the new parts settle into the spatial index before sampling spawn points

Projectiles.Start()
AchievementService.Start()
EnemyService.Start(world)
Act1Director.Start(world)
ZoneService.Start()
DuckService.Start()
SanityService.Start()
GatherService.Start(world)
BaseService.Start(world)
RescueService.Start(world)
AllyService.Start()
ShopService.Start(world)
StoryService.Start(world)
PassService.Start()
PassService.OnOutfitChanged = DuckService.ApplyOutfit
PlayerData.SpawnOverride = LookService.Spawn
StoryService.OnAllPages = function(player: Player)
	AchievementService.Grant(player, "archivist")
end

-- Late wiring between services that would otherwise require each other in a loop.
SanityService.BaseBonus = BaseService.SanityBonus
CraftingService.HasStationNearby = BaseService.HasStationNearby
CraftingService.OnCrafted = function(player: Player)
	local data = PlayerData.Get(player)
	if data and data.stats.crafted >= Achievements.ById.crafter.goal then
		AchievementService.Grant(player, "crafter")
	end
end
PlayerData.StartAutosave()

-- Spawning ---------------------------------------------------------------------------------

local function placeCharacter(character: Model, cf: CFrame)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	if not character:IsDescendantOf(workspace) then
		character.AncestryChanged:Wait()
	end
	task.wait()
	character:PivotTo(cf)
end

local function onCharacterAdded(player: Player, character: Model)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local state = Combat.GetState(player)
	state.blocking = false
	state.stunUntil = 0
	state.cooldowns = {}
	state.awakenedUntil = 0
	state.inSafeZone = false
	SanityService.OnCharacter(player)
	task.spawn(DuckService.OnCharacter, player, character)
	task.spawn(LookService.OnCharacter, player, character)
	task.spawn(PassService.OnCharacter, player, character)

	if data.act == 1 then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid.WalkSpeed = Config.Act1.WalkSpeed
		task.spawn(placeCharacter, character, Act1Director.SpawnCFrame(player))
		task.spawn(Act1Director.OnCharacter, player, character)
	else
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		humanoid.MaxHealth = Config.Act2.BaseMaxHealth + (data.level - 1) * Config.Act2.HealthPerLevel
		humanoid.Health = humanoid.MaxHealth
		humanoid.WalkSpeed = Config.Act2.WalkSpeed
		BaseService.Load(player)
		task.spawn(placeCharacter, character, BaseService.RespawnCFrame(player) or ZoneService.HubSpawn())
		task.delay(8, PassService.Welcome, player)
	end

	humanoid.Died:Connect(function()
		Registry.PlayerDied:Fire(player)
		task.wait(Config.RespawnSeconds)
		if player.Parent then
			PlayerData.Respawn(player)
		end
	end)
end

local joined: { [Player]: boolean } = {}
local function onPlayerAdded(player: Player)
	if joined[player] then
		return
	end
	joined[player] = true
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	PlayerData.Load(player)
	PassService.OnLoaded(player)
	-- New players make their character first (the client shows the creator while this waits).
	LookService.WaitForLook(player)
	if player.Parent then
		PlayerData.Respawn(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- Players who joined while the world was building
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	PowerService.Forget(player)
	Act1Director.Forget(player)
	LookService.Forget(player)
	ZoneService.Forget(player)
	PlayerData.Release(player)
	Registry.PlayerState[player] = nil
	joined[player] = nil
end)

-- Combat input -----------------------------------------------------------------------------

Remotes.Action.OnServerEvent:Connect(function(player: Player, action, arg1, arg2)
	if action == "M1" then
		Combat.M1(player, typeof(arg1) == "Vector3" and arg1 or nil)
	elseif action == "Block" then
		Combat.SetBlocking(player, arg1 == true)
	elseif action == "Dodge" then
		Combat.Dodge(player)
	elseif action == "Move" then
		if type(arg1) == "number" and arg1 >= 1 and arg1 <= 4 then
			PowerService.UseMove(player, math.floor(arg1), typeof(arg2) == "Vector3" and arg2 or nil)
		end
	elseif action == "Awaken" then
		PowerService.Awaken(player)
	end
end)

-- Menu requests ----------------------------------------------------------------------------

local function grantNextQualifier(player: Player)
	local data = PlayerData.Get(player)
	local qualifiers = Achievements.QualifiersFor(data.level + 1)
	if qualifiers[1] then
		AchievementService.Grant(player, qualifiers[1].id)
	end
end

local function devCommand(player: Player, command)
	if not (Config.EnableStudioDevTools and RunService:IsStudio()) then
		return { ok = false, message = "Dev tools only work in Studio." }
	end
	local data = PlayerData.Get(player)
	if command == "SkipAct1" then
		if data.act == 1 then
			PowerService.AwakeningRoll(player)
			data.act = 2
			data.duckSaved = true
			data.act1Stage = 4
			AchievementService.Grant(player, "awakened")
			PlayerData.Sync(player)
			PlayerData.Respawn(player)
		end
	elseif command == "Qualify" then
		grantNextQualifier(player)
	elseif command == "Essence" then
		data.essence += 1000
		PlayerData.Sync(player)
	elseif command == "Tokens" then
		data.tokens += 500
		PlayerData.Sync(player)
	elseif command == "Materials" then
		for _, material in Materials.List do
			InventoryService.Add(player, material.id, 60, false)
		end
	elseif command == "RescueAll" then
		for _, person in Townsfolk.List do
			data.rescued[person.id] = true
		end
		BaseService.RefreshTownsfolk(player)
		PlayerData.Sync(player)
	elseif command == "Reset" then
		BaseService.Unload(player)
		DuckService.Remove(player)
		local look = data.look -- keep the character you made
		for key in table.clone(data) do
			data[key] = nil
		end
		data.look = look
		data.version, data.act, data.act1Stage, data.level, data.essence, data.pity, data.totalRolls = 1, 1, 1, 1, 0, 0, 0
		data.achievements = {}
		data.act1Stage = 0
		data.duckSaved = false
		data.stats = { kills = 0, parries = 0, perfectDodges = 0, bruteClean = 0, crafted = 0, built = 0 }
		data.inventory, data.items, data.rescued = {}, {}, {}
		data.base = { placed = false, level = 1, x = 0, y = 0, z = 0, structures = {} }
		data.story = { chapter = 1, seen = {}, pages = {} }
		data.tokens, data.essenceTraded, data.welcomeTokens = 0, 0, false
		data.passes, data.vault, data.duckOutfit, data.auraOn = {}, {}, 1, true
		PlayerData.Sync(player)
		PlayerData.Respawn(player)
	end
	return { ok = true }
end

Remotes.Request.OnServerInvoke = function(player: Player, request, arg)
	if request == "Ascend" then
		return AchievementService.Ascend(player)
	elseif request == "Reroll" then
		return PowerService.Reroll(player, arg == "die")
	elseif request == "SceneDone" then
		StoryService.SceneDone(player)
		return { ok = true }
	elseif request == "ShopBuy" then
		if type(arg) ~= "table" then
			return { ok = false }
		end
		return ShopService.Buy(player, arg.shop, arg.item)
	elseif request == "KeepRoll" then
		return PowerService.ResolveReroll(player, arg == true)
	elseif request == "Warp" then
		return ZoneService.Warp(player, tostring(arg))
	elseif request == "FinishAct1" then
		Act1Director.FinishRequested(player)
		return { ok = true }
	elseif request == "State" then
		PlayerData.Sync(player)
		return { ok = true }
	elseif request == "Craft" then
		return CraftingService.Craft(player, tostring(arg))
	elseif request == "Use" then
		return CraftingService.Use(player, tostring(arg))
	elseif request == "PlaceCrystal" then
		return BaseService.PlaceCrystal(player, arg)
	elseif request == "PlaceStructure" then
		if type(arg) ~= "table" then
			return { ok = false }
		end
		return BaseService.PlaceStructure(player, arg.id, arg.position, arg.rotation)
	elseif request == "UpgradeBase" then
		return BaseService.Upgrade(player)
	elseif request == "AbandonBase" then
		return BaseService.Abandon(player)
	elseif request == "Exchange" then
		return PassService.Exchange(player, arg)
	elseif request == "BuyPass" then
		return PassService.BuyWithTokens(player, arg)
	elseif request == "PromptPass" then
		return PassService.PromptRobux(player, arg)
	elseif request == "EquipPower" then
		return PassService.EquipVaulted(player, arg)
	elseif request == "DuckOutfit" then
		return PassService.SetDuckOutfit(player, arg)
	elseif request == "Aura" then
		return PassService.SetAura(player, arg)
	elseif request == "SaveLook" then
		return LookService.Save(player, arg)
	elseif request == "Dev" then
		return devCommand(player, arg)
	end
	return { ok = false }
end

-- Camp interactions ------------------------------------------------------------------------

for _, survivor in world.survivors do
	survivor.prompt.Triggered:Connect(function(player: Player)
		Remotes.Notify:FireClient(player, "Dialogue", { speaker = survivor.name, lines = survivor.lines })
	end)
end
world.shrinePrompt.Triggered:Connect(function(player: Player)
	Remotes.Notify:FireClient(player, "OpenMenu", { tab = "Power" })
end)
world.boardPrompt.Triggered:Connect(function(player: Player)
	Remotes.Notify:FireClient(player, "OpenMenu", { tab = "Ascension" })
end)

print("[Shadowfall] Server ready.")
