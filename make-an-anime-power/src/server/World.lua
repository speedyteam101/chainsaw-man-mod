-- Builds the map with code, so the place works straight from a Rojo build:
-- a safe spawn plaza, a training ground with dummies, and a battle arena
-- where enemies roam. Anything already in Workspace is left alone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local World = {}

-- Where things are, used by EnemyService
World.DummyRow = { center = Vector3.new(0, 0, 70), spacing = 14 }
World.Arena = { center = Vector3.new(0, 0, -130), size = 170 }

local mapFolder: Folder

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape -- set first so it can't reset the size
	end
	for key, value in props do
		if key ~= "Shape" and key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent or mapFolder
	return p
end

local function sign(position: Vector3, text: string, color: Color3)
	local post = part({
		Name = "Sign",
		Size = Vector3.new(1, 8, 1),
		Position = position + Vector3.new(0, 4, 0),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(110, 80, 50),
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 50)
	gui.StudsOffset = Vector3.new(0, 5.5, 0)
	gui.MaxDistance = 200
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = post
end

local function buildGround()
	if workspace:FindFirstChild("Baseplate") then
		return
	end
	part({
		Name = "Ground",
		Size = Vector3.new(600, 4, 600),
		Position = Vector3.new(0, -2, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(90, 150, 80),
	})
end

local function buildSpawn()
	local center = Config.SafeZoneCenter
	local radius = Config.SafeZoneRadius

	local plaza = part({
		Name = "SafeZone",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(235, 230, 245),
	})
	plaza.CanCollide = true

	local ring = part({
		Name = "SafeZoneEdge",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2 + 2, radius * 2 + 2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 200, 255),
	})
	ring.CanCollide = false

	if not workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(12, 1, 12)
		spawn.Position = center + Vector3.new(0, 0.9, 0)
		spawn.Material = Enum.Material.Neon
		spawn.Color = Color3.fromRGB(255, 200, 80)
		spawn.Duration = 3
		spawn.Neutral = true
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Parent = mapFolder
	end

	sign(center + Vector3.new(-16, 0, -16), "SAFE ZONE", Color3.fromRGB(120, 200, 255))
	sign(center + Vector3.new(16, 0, 16), "Press P to make a power!", Color3.fromRGB(255, 220, 90))
end

local function buildTrainingGround()
	local row = World.DummyRow
	local width = row.spacing * (Config.DummyCount + 1)
	part({
		Name = "TrainingFloor",
		Size = Vector3.new(width, 0.4, 30),
		Position = row.center + Vector3.new(0, 0.2, 0),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(170, 130, 90),
	})
	sign(row.center + Vector3.new(-width / 2 - 4, 0, 0), "TRAINING DUMMIES", Color3.fromRGB(255, 180, 120))
end

local function buildArena()
	local arena = World.Arena
	local half = arena.size / 2
	local center = arena.center

	part({
		Name = "ArenaFloor",
		Size = Vector3.new(arena.size, 0.4, arena.size),
		Position = center + Vector3.new(0, 0.2, 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(110, 105, 120),
	})

	-- Low walls with an opening facing the spawn
	local wallColor = Color3.fromRGB(80, 75, 90)
	local gap = 30
	local sideLength = (arena.size - gap) / 2
	for _, side in { -1, 1 } do
		part({
			Name = "ArenaWall",
			Size = Vector3.new(sideLength, 8, 3),
			Position = center + Vector3.new(side * (gap / 2 + sideLength / 2), 4, half),
			Material = Enum.Material.Brick,
			Color = wallColor,
		})
	end
	part({
		Name = "ArenaWall",
		Size = Vector3.new(arena.size, 8, 3),
		Position = center + Vector3.new(0, 4, -half),
		Material = Enum.Material.Brick,
		Color = wallColor,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "ArenaWall",
			Size = Vector3.new(3, 8, arena.size),
			Position = center + Vector3.new(side * half, 4, 0),
			Material = Enum.Material.Brick,
			Color = wallColor,
		})
	end

	-- Pillars and rocks for cover (same layout every time)
	local random = Random.new(2024)
	for _ = 1, 14 do
		local x = random:NextNumber(-half + 15, half - 15)
		local z = random:NextNumber(-half + 15, half - 25)
		if random:NextNumber() < 0.5 then
			local height = random:NextNumber(10, 22)
			part({
				Name = "Pillar",
				Size = Vector3.new(5, height, 5),
				Position = center + Vector3.new(x, height / 2, z),
				Material = Enum.Material.Cobblestone,
				Color = Color3.fromRGB(140, 135, 150),
			})
		else
			local size = random:NextNumber(5, 10)
			part({
				Name = "Rock",
				Size = Vector3.new(size, size * 0.7, size),
				CFrame = CFrame.new(center + Vector3.new(x, size * 0.3, z))
					* CFrame.Angles(0, random:NextNumber(0, math.pi), random:NextNumber(-0.2, 0.2)),
				Material = Enum.Material.Rock,
				Color = Color3.fromRGB(105, 100, 95),
			})
		end
	end

	sign(center + Vector3.new(-gap / 2 - 4, 0, half + 4), "BATTLE ARENA", Color3.fromRGB(255, 90, 90))
end

-- Builds the map. Returns the folder enemies and dummies should go in.
function World.build(): Folder
	local existing = workspace:FindFirstChild("Map")
	if existing and existing:IsA("Folder") then
		mapFolder = existing
	else
		local folder = Instance.new("Folder")
		folder.Name = "Map"
		folder.Parent = workspace
		mapFolder = folder
		buildGround()
		buildSpawn()
		buildTrainingGround()
		buildArena()
	end

	local enemies = workspace:FindFirstChild("Enemies")
	if enemies and enemies:IsA("Folder") then
		return enemies
	end
	local folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace
	return folder
end

return World
