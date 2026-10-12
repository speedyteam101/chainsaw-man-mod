-- Sides and classes: Roblox Teams for Heroes / Villains / Undecided, class
-- selection, and applying a class's health and speed to the character.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Classes = require(Shared:WaitForChild("Classes"))
local AuraService = require(script.Parent.AuraService)
local World = require(script.Parent.World)

local ClassService = {}

local teams: { [string]: Team } = {}

local function makeTeam(key: string, name: string, autoAssign: boolean)
	local team = Instance.new("Team")
	team.Name = name
	team.TeamColor = World.TeamColors[key]
	team.AutoAssignable = autoAssign
	team.Parent = Teams
	teams[key] = team
end

function ClassService.start()
	makeTeam("Undecided", "Undecided", true)
	makeTeam("Good", Classes.Sides.Good.Name, false)
	makeTeam("Evil", Classes.Sides.Evil.Name, false)
end

-- Respawns at the player's team spawn. (Player:LoadCharacter is
-- deprecated in favour of LoadCharacterAsync.)
local function respawn(player: Player)
	task.spawn(function()
		local ok, err = pcall(function()
			player:LoadCharacterAsync()
		end)
		if not ok and player.Parent then
			warn("[AuraFarm] Couldn't respawn", player.Name, err)
		end
	end)
end

-- Health and walk speed from the class (defaults while undecided).
function ClassService.applyCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.MaxHealth = AuraService.stat(player, "MaxHealth")
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = AuraService.stat(player, "WalkSpeed")
end

local function setClass(player: Player, class)
	player:SetAttribute("ClassId", class.Id)
	player:SetAttribute("Side", class.Side)
	player.Neutral = false
	player.Team = teams[class.Side]
	local state = AuraService.get(player)
	if state then
		state.savedClassId = class.Id
	end
	AuraService.refreshVisuals(player)
	respawn(player)
end

-- A player asked to become `classId` (from the class picker).
function ClassService.request(player: Player, classId: any)
	local class = Classes.get(classId)
	local state = AuraService.get(player)
	if not class or not state then
		return
	end
	if player:GetAttribute("ClassId") == class.Id then
		AuraService.notify(player, { Kind = "ClassChosen", ClassId = class.Id })
		return
	end
	local now = os.clock()
	if now - state.lastClassChange < Config.Pvp.ClassChangeCooldown then
		AuraService.notify(player, { Kind = "Message", Text = "Wait a moment before changing class again." })
		return
	end
	if state.lastAttacker and now - state.lastAttackTime < Config.Pvp.CombatLock then
		AuraService.notify(player, { Kind = "Message", Text = "You can't change class in the middle of a fight!" })
		return
	end
	state.lastClassChange = now

	local previousSide = AuraService.sideOf(player)
	setClass(player, class)
	AuraService.notify(player, { Kind = "ClassChosen", ClassId = class.Id })
	if previousSide ~= class.Side then
		local verb = if class.Side == "Evil" then "has turned to evil" else "has joined the heroes"
		AuraService.announce(string.format("%s %s as a %s!", player.DisplayName, verb, class.Name), player)
	end
end

function ClassService.setupPlayer(player: Player)
	player.Neutral = false
	player.Team = teams.Undecided
end

-- After the save loads: bring back the saved class, or ask them to pick.
function ClassService.onLoaded(player: Player, savedClassId: string?)
	if not player.Parent then
		return
	end
	local class = Classes.get(savedClassId)
	if class and player:GetAttribute("ClassId") == nil then
		setClass(player, class)
		AuraService.notify(player, { Kind = "ClassChosen", ClassId = class.Id })
	elseif not class then
		AuraService.notify(player, { Kind = "PickClass" })
	end
	-- The client waits for this before deciding whether to open the picker
	-- (the PickClass message can arrive before its scripts are listening).
	player:SetAttribute("Loaded", true)
end

return ClassService
