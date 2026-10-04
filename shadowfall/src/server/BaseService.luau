--!nonstrict
-- Player bases. You place one Base Crystal anywhere in an unlocked area; it raises a barrier shadows can't
-- cross. Inside the barrier you place holographic blueprints and fill them with materials until
-- they become real buildings. Upgrading the crystal grows the barrier (and your buildable area).
-- Rescued townsfolk live at your base. Bases are saved relative to the crystal, so if your old
-- spot is taken when you rejoin, you can place the crystal somewhere else and everything follows.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(ReplicatedStorage.Shared.Achievements)
local Areas = require(ReplicatedStorage.Shared.Areas)
local Config = require(ReplicatedStorage.Shared.Config)
local Materials = require(ReplicatedStorage.Shared.Materials)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Structures = require(ReplicatedStorage.Shared.Structures)
local Townsfolk = require(ReplicatedStorage.Shared.Townsfolk)
local Figure = require(ReplicatedStorage.Shared.Figure)
local Registry = require(script.Parent.Registry)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local InventoryService = require(script.Parent.InventoryService)
local AchievementService = require(script.Parent.AchievementService)
local HouseService = require(script.Parent.HouseService)
local NpcService = require(script.Parent.NpcService)

local BaseService = {}

local BC = Config.Base
local HOLO = Color3.fromRGB(90, 200, 255)
local MAX_STRUCTURES = 250
local bases: { [Player]: any } = {}
local root: Folder
local world

local function radiusOf(level: number): number
	return BC.Levels[math.clamp(level, 1, #BC.Levels)].radius
end

local function toast(player: Player, text: string, color: Color3?)
	Remotes.Notify:FireClient(player, "Toast", { text = text, color = color })
end

local function builderBonus(player: Player): number
	local data = PlayerData.Get(player)
	local builders = 0
	for _, person in Townsfolk.List do
		if data.rescued[person.id] and #person.roles > 0 then
			builders += 1
		end
	end
	return math.min(builders * BC.BuilderBonusPerNpc, BC.MaxBuilderBonus)
end

local function syncAttributes(player: Player)
	local base = bases[player]
	local data = PlayerData.Get(player)
	player:SetAttribute("BasePlaced", base ~= nil)
	player:SetAttribute("BaseLevel", data and data.base.level or 1)
	if base then
		player:SetAttribute("BaseCenter", base.center)
		player:SetAttribute("BaseRadius", radiusOf(base.level))
	else
		player:SetAttribute("BaseRadius", 0)
	end
end

-- Saves the in-world base back into the player's data (structures relative to the crystal).
local function persist(player: Player)
	local base = bases[player]
	local data = PlayerData.Get(player)
	if not base or not data then
		return
	end
	local list = {}
	for _, s in base.structures do
		local offset = s.cf.Position - base.center
		table.insert(list, {
			d = s.def.id,
			x = math.floor(offset.X * 100 + 0.5) / 100,
			y = math.floor(offset.Y * 100 + 0.5) / 100,
			z = math.floor(offset.Z * 100 + 0.5) / 100,
			r = s.rot,
			b = s.built,
			dep = if s.built then nil else s.deposited,
		})
	end
	data.base.placed = true
	data.base.x, data.base.y, data.base.z = base.center.X, base.center.Y, base.center.Z
	data.base.level = base.level
	data.base.structures = list
end

local function overlapParams(extra)
	local exclude = { world.floors, workspace.Terrain }
	for _, name in { "Enemies", "Stalkers", "Ducks", "LocalFx" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	for _, item in extra or {} do
		table.insert(exclude, item)
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

-- Structures --------------------------------------------------------------------------------

local function updateBlueprintGui(s)
	local lines = {}
	local total, done = 0, 0
	for _, material in Materials.List do
		local need = s.def.cost[material.id]
		if need then
			local have = math.min(need, math.floor(s.deposited[material.id] or 0))
			total += need
			done += have
			table.insert(lines, string.format("%s  %d / %d", material.name, have, need))
		end
	end
	s.gui.Body.Text = table.concat(lines, "\n")
	s.gui.Bar.Fill.Size = UDim2.fromScale(total > 0 and done / total or 0, 1)
	return total > 0 and done / total or 1
end

local function addLights(s)
	for _, part in s.model:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("Glow") then
			local light = Instance.new("PointLight")
			light.Color = part.Color
			light.Range = s.def.lamp and 26 or 16
			light.Brightness = s.def.lamp and 1.8 or 1.4
			light.Shadows = s.def.lamp == true
			light.Parent = part
			if s.def.fire then
				local fire = Instance.new("Fire")
				fire.Size = 4
				fire.Heat = 6
				fire.Color = Color3.fromRGB(255, 140, 50)
				fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
				fire.Parent = part
			end
		end
	end
end

local function setPromptMode(s)
	local prompt = s.prompt
	if s.built then
		prompt.ActionText = "Dismantle"
		prompt.HoldDuration = 1.2
		prompt.KeyboardKeyCode = Enum.KeyCode.T
		prompt.GamepadKeyCode = Enum.KeyCode.DPadDown
		prompt.MaxActivationDistance = 10
		s.cancelPrompt.Enabled = false
		s.gui.Enabled = false
	else
		prompt.ActionText = "Add materials"
		prompt.HoldDuration = 0.35
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = 14
		s.cancelPrompt.Enabled = true
		s.gui.Enabled = true
	end
end

local function finish(player: Player, base, s, quiet: boolean?)
	s.built = true
	s.deposited = {}
	Structures.SetSolid(s.model)
	s.model:SetAttribute("Blueprint", false)
	addLights(s)
	setPromptMode(s)
	if not quiet then
		local data = PlayerData.Get(player)
		data.stats.built += 1
		local achievement = Achievements.ById.master_builder
		if data.stats.built >= achievement.goal then
			AchievementService.Grant(player, "master_builder")
		end
		Remotes.Fx:FireAllClients("Built", { position = s.model.PrimaryPart.Position, size = s.def.size })
		toast(player, s.def.name .. " finished!", Color3.fromRGB(140, 220, 255))
		PlayerData.Sync(player)
	end
end

local function removeStructure(player: Player, base, s, refund: boolean)
	if refund then
		local data = PlayerData.Get(player)
		local bonus = 1 + builderBonus(player)
		if s.built then
			for id, amount in s.def.cost do
				InventoryService.Add(player, id, math.floor(amount * BC.DismantleRefund), false)
			end
		else
			for id, amount in s.deposited do
				InventoryService.Add(player, id, math.floor(amount / bonus), false)
			end
		end
		if data then
			InventoryService.Changed(player)
		end
	end
	base.structures[s.id] = nil
	s.model:Destroy()
end

local function deposit(player: Player, base, s)
	if s.built then
		return
	end
	local bonus = 1 + builderBonus(player)
	local added = false
	for id, need in s.def.cost do
		local remaining = need - (s.deposited[id] or 0)
		if remaining > 1e-4 then
			local realNeeded = math.max(1, math.ceil(remaining / bonus - 1e-6))
			local take = math.min(realNeeded, InventoryService.Count(player, id))
			if take > 0 and InventoryService.Spend(player, { [id] = take }) then
				s.deposited[id] = math.min(need, (s.deposited[id] or 0) + take * bonus)
				if need - s.deposited[id] < 1e-4 then
					s.deposited[id] = need
				end
				added = true
			end
		end
	end
	if not added then
		local missing = {}
		for id, need in s.def.cost do
			local remaining = math.ceil(need - (s.deposited[id] or 0))
			if remaining > 0 then
				missing[id] = remaining
			end
		end
		toast(player, "You need: " .. Materials.Describe(missing), Color3.fromRGB(255, 160, 160))
		return
	end
	local progress = updateBlueprintGui(s)
	Remotes.Fx:FireAllClients("Deposit", { position = s.model.PrimaryPart.Position })
	if progress >= 1 - 1e-6 then
		finish(player, base, s)
	else
		Structures.SetHologram(s.model, HOLO, progress)
	end
	persist(player)
end

local function spawnStructure(player: Player, base, def, cf: CFrame, rot: number, built: boolean, deposited)
	base.nextId += 1
	local model = Structures.Build(def, cf)
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Blueprint", not built)
	CollectionService:AddTag(model, "BaseStructure")
	local s = { id = base.nextId, def = def, cf = cf, rot = rot, model = model, built = false, deposited = deposited or {} }

	local bounds = model.PrimaryPart
	local gui = Instance.new("BillboardGui")
	gui.Name = "Blueprint"
	gui.Size = UDim2.fromOffset(190, 96)
	gui.StudsOffsetWorldSpace = Vector3.new(0, def.size.Y / 2 + 2.5, 0)
	gui.MaxDistance = 40
	gui.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = HOLO
	title.TextStrokeTransparency = 0.4
	title.Text = def.name .. " (blueprint)"
	title.Parent = gui
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Position = UDim2.new(0, 0, 0, 22)
	body.Size = UDim2.new(1, 0, 0, 56)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamMedium
	body.TextSize = 13
	body.TextColor3 = Color3.fromRGB(220, 235, 255)
	body.TextStrokeTransparency = 0.5
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = gui
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.new(0.1, 0, 1, -10)
	bar.Size = UDim2.new(0.8, 0, 0, 6)
	bar.BackgroundColor3 = Color3.fromRGB(20, 30, 40)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = HOLO
	fill.BorderSizePixel = 0
	fill.Parent = bar
	gui.Parent = bounds
	s.gui = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = def.name
	prompt.RequiresLineOfSight = false
	prompt.Parent = bounds
	s.prompt = prompt
	local cancel = Instance.new("ProximityPrompt")
	cancel.ActionText = "Cancel blueprint"
	cancel.ObjectText = def.name
	cancel.HoldDuration = 1
	cancel.KeyboardKeyCode = Enum.KeyCode.T
	cancel.GamepadKeyCode = Enum.KeyCode.DPadDown
	cancel.MaxActivationDistance = 14
	cancel.RequiresLineOfSight = false
	cancel.UIOffset = Vector2.new(0, 60)
	cancel.Parent = bounds
	s.cancelPrompt = cancel

	prompt.Triggered:Connect(function(who: Player)
		if who ~= player or not base.structures[s.id] then
			return
		end
		if s.built then
			removeStructure(player, base, s, true)
			toast(player, def.name .. " dismantled. Half the materials returned.")
			persist(player)
		else
			deposit(player, base, s)
		end
	end)
	cancel.Triggered:Connect(function(who: Player)
		if who ~= player or s.built or not base.structures[s.id] then
			return
		end
		removeStructure(player, base, s, true)
		persist(player)
	end)

	model.Parent = base.folder
	base.structures[s.id] = s
	if built then
		finish(player, base, s, true)
	else
		setPromptMode(s)
		local progress = updateBlueprintGui(s)
		Structures.SetHologram(model, HOLO, progress)
	end
	return s
end

-- Townsfolk at your base --------------------------------------------------------------------

local function roleOf(person): string
	if table.find(person.roles, "Blacksmith") then
		return "blacksmith"
	elseif table.find(person.roles, "Carpenter") then
		return "carpenter"
	end
	return "townsfolk"
end

-- A rescued townsperson: a living rig that wanders inside your barrier (NpcService).
local function buildPerson(person, cf: CFrame, parent: Instance): Model
	local blacksmith = table.find(person.roles, "Blacksmith") ~= nil
	local carpenter = table.find(person.roles, "Carpenter") ~= nil
	local spec = Figure.SpecFor(person.id, {
		shirt = person.shirt,
		pants = person.pants,
		outfit = blacksmith and "apron" or (carpenter and "overalls" or nil),
	})
	spec.cf = cf
	spec.name = person.name
	local model, parts = Figure.BuildRig(spec)
	local torso = parts.Torso
	-- Tools held in the right hand (welded, so they swing with the arm).
	local hand = parts["Right Arm"]
	local function prop(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = hand.CFrame * offset
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
	end
	if carpenter then
		prop("HammerHandle", Vector3.new(0.22, 0.22, 1.5), CFrame.new(0, -1.05, -0.6), Color3.fromRGB(120, 86, 52), Enum.Material.Wood)
		prop("HammerHead", Vector3.new(0.35, 0.8, 0.35), CFrame.new(0, -1.05, -1.3), Color3.fromRGB(90, 90, 96), Enum.Material.Metal)
	end
	if blacksmith then
		prop("Tongs", Vector3.new(0.12, 0.12, 1.6), CFrame.new(0, -1.05, -0.7), Color3.fromRGB(60, 60, 64), Enum.Material.Metal)
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 38)
	gui.StudsOffset = Vector3.new(0, 6.6, 0)
	gui.MaxDistance = 50
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(255, 225, 180)
	label.TextStrokeTransparency = 0.4
	label.Text = person.name .. "\n" .. (#person.roles > 0 and table.concat(person.roles, " & ") or "Survivor")
	label.Parent = gui
	gui.Parent = torso
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = person.name
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = torso
	prompt.Triggered:Connect(function(who: Player)
		Remotes.Notify:FireClient(who, "Dialogue", { speaker = person.name, lines = person.lines })
	end)
	model.Parent = parent
	return model
end

function BaseService.RefreshTownsfolk(player: Player)
	local base = bases[player]
	local data = PlayerData.Get(player)
	if not base or not data then
		return
	end
	base.npcFolder:ClearAllChildren()
	local rescued = {}
	for _, person in Townsfolk.List do
		if data.rescued[person.id] then
			table.insert(rescued, person)
		end
	end
	for index, person in rescued do
		local angle = index / math.max(#rescued, 1) * math.pi * 2 + 0.4
		local spot = base.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 9
		local model = buildPerson(person, CFrame.lookAt(spot, Vector3.new(base.center.X, spot.Y, base.center.Z)), base.npcFolder)
		NpcService.Register(model, { home = base.center, radius = math.max(6, radiusOf(base.level) - 5), role = roleOf(person) })
	end
end

-- Crystal -----------------------------------------------------------------------------------

local function buildCrystal(player: Player, base)
	if base.crystal then
		base.crystal:Destroy()
	end
	local crystal = Structures.BuildCrystal(CFrame.new(base.center), base.level)
	crystal:SetAttribute("Owner", player.UserId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Manage base"
	prompt.ObjectText = player.DisplayName .. "'s Base Crystal"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = crystal.PrimaryPart
	prompt.Triggered:Connect(function(who: Player)
		if who == player then
			Remotes.Notify:FireClient(player, "OpenMenu", { tab = "Base" })
		end
	end)
	crystal.Parent = base.folder
	base.crystal = crystal

	local radius = radiusOf(base.level)
	if not base.barrier then
		local barrier = Instance.new("Part")
		barrier.Name = "Barrier"
		barrier.Shape = Enum.PartType.Ball
		barrier.Anchored = true
		barrier.CanCollide = false
		barrier.CanQuery = false
		barrier.CanTouch = false
		barrier.CastShadow = false
		barrier.Material = Enum.Material.ForceField
		barrier.Color = Color3.fromRGB(110, 190, 255)
		barrier.Transparency = 0.2
		barrier.Parent = base.folder
		base.barrier = barrier
	end
	base.barrier.Size = Vector3.one * radius * 2
	base.barrier.CFrame = CFrame.new(base.center)
	Registry.Barriers[player] = { center = base.center, radius = radius }
end

-- `saved` = re-checking an existing base on load: the keep-away rules (arena, gates, level)
-- only apply to new placements, so rule changes never break an existing base.
local function validCrystalSpot(player: Player, position: Vector3, saved: boolean?): (boolean, string?, Vector3?)
	-- Anywhere in any area you've unlocked, except the camp, boss arenas and area entrances.
	local area = Areas.At(position)
	local data = PlayerData.Get(player)
	if not area then
		return false, "Your base has to be in the shadow world."
	end
	if not saved and data and data.level < area.level then
		return false, area.name .. " needs level " .. area.level .. "."
	end
	if not saved and Vector2.new(position.X, position.Z).Magnitude < BC.MinDistanceFromCamp then
		return false, "Too close to the camp. Move further out."
	end
	local flat = Vector2.new(position.X, position.Z)
	local arena = area.boss.arena
	if not saved then
		if (flat - Vector2.new(arena.X, arena.Z)).Magnitude < 60 then
			return false, "Too close to where " .. area.name .. "'s guardian waits."
		end
		if (flat - Vector2.new(area.spawn.X, area.spawn.Z)).Magnitude < 30 or (area.gateX and math.abs(position.X - area.gateX) < 30) then
			return false, "Don't block the way in. Move away from the gate."
		end
	end
	for other, base in bases do
		if other ~= player and (Vector2.new(position.X, position.Z) - Vector2.new(base.center.X, base.center.Z)).Magnitude < BC.MinDistanceBetweenCrystals then
			return false, "Too close to " .. other.DisplayName .. "'s base."
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world.floors, workspace.Terrain }
	params.IgnoreWater = true
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
	if not hit then
		return false, "That isn't solid ground."
	end
	local ground = hit.Position
	local blocking = workspace:GetPartBoundsInBox(CFrame.new(ground + Vector3.new(0, 5.5, 0)), Vector3.new(5.6, 10, 5.6), overlapParams())
	for _, part in blocking do
		if part.CanCollide or part.Name == "Bounds" then
			return false, "Something is in the way."
		end
	end
	return true, nil, ground
end

local function createBase(player: Player, center: Vector3)
	local data = PlayerData.Get(player)
	local folder = Instance.new("Folder")
	folder.Name = "Base_" .. player.UserId
	folder.Parent = root
	local npcFolder = Instance.new("Folder")
	npcFolder.Name = "Townsfolk"
	npcFolder.Parent = folder
	local base = { owner = player, center = center, level = data.base.level, folder = folder, npcFolder = npcFolder, structures = {}, nextId = 0 }
	bases[player] = base
	-- Houses cleared around this spot stay down (and get remembered for next time).
	HouseService.ClearAt(player, center, radiusOf(base.level))
	HouseService.Remember(player, center, radiusOf(base.level))
	buildCrystal(player, base)
	-- Rebuild saved structures relative to the crystal.
	for _, saved in data.base.structures do
		local def = Structures.ById[saved.d]
		if def then
			local cf = CFrame.new(center + Vector3.new(saved.x, saved.y, saved.z)) * CFrame.Angles(0, math.rad(saved.r or 0), 0)
			spawnStructure(player, base, def, cf, saved.r or 0, saved.b == true, saved.dep)
		end
	end
	BaseService.RefreshTownsfolk(player)
	persist(player)
	syncAttributes(player)
	return base
end

-- Requests ----------------------------------------------------------------------------------

function BaseService.PlaceCrystal(player: Player, position)
	local data = PlayerData.Get(player)
	if not data or data.act ~= 2 or typeof(position) ~= "Vector3" then
		return { ok = false, message = "You can't do that right now." }
	end
	if bases[player] then
		return { ok = false, message = "Your crystal is already placed." }
	end
	local ok, message, ground = validCrystalSpot(player, position)
	if not ok then
		return { ok = false, message = message }
	end
	createBase(player, ground)
	AchievementService.Grant(player, "homestead")
	Remotes.Fx:FireAllClients("BarrierGrow", { position = ground, radius = radiusOf(PlayerData.Get(player).base.level) })
	PlayerData.Sync(player)
	PlayerData.Save(player)
	return { ok = true }
end

function BaseService.PlaceStructure(player: Player, defId, position, rotation)
	local data = PlayerData.Get(player)
	local base = bases[player]
	local def = Structures.ById[tostring(defId)]
	if not data or not base or not def or typeof(position) ~= "Vector3" or type(rotation) ~= "number" then
		return { ok = false, message = "Place your base crystal first." }
	end
	if def.needs and Townsfolk.Roles(data.rescued)[def.needs] == 0 then
		return { ok = false, message = "You need a rescued " .. string.lower(def.needs) .. " to build this." }
	end
	if def.baseLevel and base.level < def.baseLevel then
		return { ok = false, message = "Upgrade your crystal to level " .. def.baseLevel .. " first." }
	end
	local count = 0
	for _ in base.structures do
		count += 1
	end
	if count >= MAX_STRUCTURES then
		return { ok = false, message = "Your base is full." }
	end
	local rot = (math.floor(rotation / 90 + 0.5) * 90) % 360
	local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(rot), 0)
	if not BaseService.CanPlace(player, def, cf) then
		return { ok = false, message = "Can't build there." }
	end
	spawnStructure(player, base, def, cf, rot, false, nil)
	persist(player)
	return { ok = true }
end

-- Shared by the request and (as a preview) by the client: inside your barrier, near the ground
-- level of your base, and not overlapping anything solid.
function BaseService.CanPlace(player: Player, def, cf: CFrame): boolean
	local base = bases[player]
	if not base then
		return false
	end
	local radius = radiusOf(base.level)
	local offset = cf.Position - base.center
	local reach = Vector2.new(def.size.X, def.size.Z).Magnitude / 2
	if Vector2.new(offset.X, offset.Z).Magnitude + reach > radius then
		return false
	end
	if offset.Y < -6 or offset.Y > 40 then
		return false
	end
	local box = cf * CFrame.new(0, def.size.Y / 2, 0)
	local parts = workspace:GetPartBoundsInBox(box, def.size - Vector3.new(math.min(def.size.X * 0.5, 1.1), 0.3, math.min(def.size.Z * 0.5, 1.1)), overlapParams({ base.npcFolder }))
	for _, part in parts do
		if part.CanCollide or part.Name == "Bounds" or part.Parent and part.Parent.Name == "BaseCrystal" then
			return false
		end
	end
	return true
end

function BaseService.Upgrade(player: Player)
	local base = bases[player]
	local data = PlayerData.Get(player)
	if not base or not data then
		return { ok = false, message = "Place your base crystal first." }
	end
	local nextLevel = base.level + 1
	local tier = BC.Levels[nextLevel]
	if not tier then
		return { ok = false, message = "Your crystal is already at full strength." }
	end
	if not InventoryService.Spend(player, tier.cost) then
		return { ok = false, message = "You need: " .. Materials.Describe(tier.cost) }
	end
	base.level = nextLevel
	data.base.level = nextLevel
	buildCrystal(player, base)
	HouseService.Remember(player, base.center, radiusOf(base.level))
	BaseService.RefreshTownsfolk(player)
	Remotes.Fx:FireAllClients("BarrierGrow", { position = base.center, radius = tier.radius })
	if nextLevel >= 3 then
		AchievementService.Grant(player, "fortress")
	end
	persist(player)
	syncAttributes(player)
	PlayerData.Sync(player)
	PlayerData.Save(player)
	return { ok = true, level = nextLevel, radius = tier.radius }
end

function BaseService.Abandon(player: Player)
	local base = bases[player]
	local data = PlayerData.Get(player)
	if not base or not data then
		return { ok = false, message = "You don't have a base placed." }
	end
	for _, s in table.clone(base.structures) do
		removeStructure(player, base, s, true)
	end
	BaseService.Unload(player)
	data.base.placed = false
	data.base.structures = {}
	data.base.cleared = {}
	syncAttributes(player)
	PlayerData.Sync(player)
	return { ok = true }
end

-- Queries used by other services ------------------------------------------------------------

function BaseService.InOwnBase(player: Player): boolean
	local base = bases[player]
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not base or not rootPart then
		return false
	end
	local offset = rootPart.Position - base.center
	return Vector2.new(offset.X, offset.Z).Magnitude <= radiusOf(base.level)
end

function BaseService.SanityBonus(player: Player): number
	if not BaseService.InOwnBase(player) then
		return 0
	end
	local base = bases[player]
	local lamps = 0
	for _, s in base.structures do
		if s.built and s.def.lamp then
			lamps += 1
		end
	end
	local data = PlayerData.Get(player)
	local morale = Townsfolk.Roles(data.rescued).Survivor * 0.5
	return Config.Sanity.OwnBaseRegen + math.min(lamps * Config.Sanity.LampRegen, Config.Sanity.MaxLampBonus) + morale
end

function BaseService.HasStationNearby(player: Player, station: string): boolean
	local base = bases[player]
	if not base or not BaseService.InOwnBase(player) then
		return false
	end
	for _, s in base.structures do
		if s.built and s.def.station == station then
			return true
		end
	end
	return false
end

function BaseService.RespawnCFrame(player: Player): CFrame?
	local base = bases[player]
	if not base then
		return nil
	end
	for _, s in base.structures do
		if s.built and s.def.bed then
			return s.cf * CFrame.new(0, 5, -6)
		end
	end
	return nil
end

-- Lifecycle ---------------------------------------------------------------------------------

function BaseService.Load(player: Player)
	local data = PlayerData.Get(player)
	if not data or not data.base.placed or bases[player] then
		syncAttributes(player)
		return
	end
	local saved = Vector3.new(data.base.x, data.base.y, data.base.z)
	-- Knock down the houses that were cleared there before checking the spot is free.
	HouseService.ClearAt(player, saved, radiusOf(data.base.level))
	local ok = validCrystalSpot(player, saved, true)
	if ok then
		createBase(player, saved)
	else
		-- Keep the layout; the player places the crystal somewhere else and it all comes along.
		data.base.placed = true
		syncAttributes(player)
		if player:GetAttribute("BaseSpotWarned") then
			return
		end
		player:SetAttribute("BaseSpotWarned", true)
		toast(player, "Someone has built where your base was. Place your crystal somewhere new (Build menu) and your base will follow.", Color3.fromRGB(255, 210, 140))
	end
end

function BaseService.Unload(player: Player)
	local base = bases[player]
	if base then
		persist(player)
		base.folder:Destroy()
		bases[player] = nil
	end
	Registry.Barriers[player] = nil
end

function BaseService.Start(worldInfo)
	world = worldInfo
	root = Instance.new("Folder")
	root.Name = "Bases"
	root.Parent = workspace

	Players.PlayerRemoving:Connect(BaseService.Unload)
	Registry.Rescued:Connect(function(player: Player)
		BaseService.RefreshTownsfolk(player)
	end)

	-- Turrets zap nearby shadows; campfires heal anyone standing at them.
	task.spawn(function()
		while true do
			task.wait(BC.TurretInterval)
			for owner, base in bases do
				local data = PlayerData.Get(owner)
				for _, s in base.structures do
					if s.built and s.def.turret then
						local top = s.cf.Position + Vector3.new(0, 6, 0)
						local best, bestDistance = nil, BC.TurretRange
						for _, enemy in Registry.Enemies do
							local d = (enemy.root.Position - top).Magnitude
							if not enemy.dead and d < bestDistance then
								best, bestDistance = enemy, d
							end
						end
						if best then
							Remotes.Fx:FireAllClients("Bolt", { from = top, to = best.root.Position, color = Color3.fromRGB(255, 245, 190) })
							Combat.DamageEnemy(best, BC.TurretDamage * (Config.LevelDamage[data and data.level or 1] or 1), owner, { effects = { stun = 0.3 }, color = Color3.fromRGB(255, 245, 190) })
						end
					elseif s.built and s.def.heal then
						for _, p in Players:GetPlayers() do
							local _, humanoid, r = Combat.GetCharacter(p)
							if r and (r.Position - s.cf.Position).Magnitude < 14 then
								humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * 0.03 * BC.TurretInterval)
							end
						end
					end
				end
			end
		end
	end)
end

return BaseService
