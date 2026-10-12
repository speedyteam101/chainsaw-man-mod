-- Builds the map from code so the place works straight out of `rojo build`:
-- sunset lighting, a grass field, a round stone arena ringed with pillars,
-- one summoning altar per boss and a spawn point with a how-to board.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local World = {}

World.FloorY = 1.2 -- top of the arena floor
World.ArenaCenter = Vector3.new(0, World.FloorY, 0)
World.BossSpawn = Vector3.new(0, World.FloorY, -25)

local map = Instance.new("Folder")
map.Name = "AuraFarmMap"

local function block(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in pairs(props) do
		if key ~= "Shape" and key ~= "Parent" then
			p[key] = value
		end
	end
	p.Parent = props.Parent or map
	return p
end

local function setupLighting()
	Lighting.ClockTime = 17.6
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 120, 140)
	Lighting.Ambient = Color3.fromRGB(70, 60, 80)

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Color = Color3.fromRGB(255, 190, 150)
	atmosphere.Decay = Color3.fromRGB(120, 80, 140)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 30
	bloom.Threshold = 0.9
	bloom.Parent = Lighting
end

local function buildArena()
	-- Ground (top at y = 1, above a template Baseplate's top at y = 0).
	block({
		Name = "Ground",
		Size = Vector3.new(700, 1, 700),
		Position = Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(70, 120, 60),
		Material = Enum.Material.Grass,
	})

	-- Arena floor: a flat cylinder (cylinders point along X, so roll it).
	local radius = Config.ArenaRadius
	block({
		Name = "ArenaFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		CFrame = CFrame.new(0, World.FloorY - 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(95, 90, 100),
		Material = Enum.Material.Slate,
	})
	block({
		Name = "ArenaSeal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.42, 30, 30),
		CFrame = CFrame.new(0, World.FloorY - 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 200, 90),
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
	})

	-- Pillars around the edge, leaving a gap on the spawn (+Z) side.
	local count = 14
	for i = 0, count - 1 do
		local angle = (i / count) * math.pi * 2
		local x, z = math.sin(angle) * (radius + 4), math.cos(angle) * (radius + 4)
		if z < radius * 0.8 then
			local height = 26 + (i % 3) * 6
			block({
				Name = "Pillar",
				Size = Vector3.new(6, height, 6),
				Position = Vector3.new(x, World.FloorY + height / 2, z),
				Color = Color3.fromRGB(80, 75, 90),
				Material = Enum.Material.Cobblestone,
			})
			block({
				Name = "PillarFlame",
				Size = Vector3.new(3, 3, 3),
				Position = Vector3.new(x, World.FloorY + height + 1.6, z),
				Color = Color3.fromRGB(255, 160, 60),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
		end
	end
end

local function billboard(adornee: BasePart, lines: { { text: string, size: number, color: Color3 } }, offset: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(300, #lines * 30)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	for i, line in ipairs(lines) do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromOffset(300, 30)
		l.Position = UDim2.fromOffset(0, (i - 1) * 30)
		l.Font = Enum.Font.GothamBlack
		l.TextSize = line.size
		l.TextColor3 = line.color
		l.TextStrokeTransparency = 0.3
		l.Text = line.text
		l.Parent = gui
	end
	gui.Parent = adornee
	return gui
end

-- Returns { [bossId] = { prompt = ProximityPrompt, crystal = Part } }
local function buildAltars()
	local altars = {}
	local spacing = 30
	for i, def in ipairs(Config.Bosses) do
		local x = (i - (#Config.Bosses + 1) / 2) * spacing
		local base = block({
			Name = def.Id .. "Altar",
			Size = Vector3.new(7, 3, 7),
			Position = Vector3.new(x, World.FloorY + 1.5, Config.ArenaRadius - 22),
			Color = Color3.fromRGB(60, 55, 70),
			Material = Enum.Material.Basalt,
		})
		local eye = def.EyeColor
		local crystal = block({
			Name = def.Id .. "Crystal",
			Size = Vector3.new(2.5, 5, 2.5),
			CFrame = CFrame.new(x, World.FloorY + 6, Config.ArenaRadius - 22) * CFrame.Angles(0, math.rad(45), math.rad(45)),
			Color = Color3.fromRGB(eye[1], eye[2], eye[3]),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})

		billboard(base, {
			{ text = def.Name, size = 24, color = Color3.fromRGB(eye[1], eye[2], eye[3]) },
			{ text = def.Title, size = 15, color = Color3.fromRGB(230, 230, 230) },
			{ text = string.format("%d HP  -  %d base aura", def.MaxHealth, def.Reward), size = 14, color = Color3.fromRGB(255, 230, 120) },
		}, 9)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Challenge"
		prompt.ObjectText = def.Name
		prompt.HoldDuration = 0.8
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = base

		altars[def.Id] = { prompt = prompt, crystal = crystal }
	end
	return altars
end

local HOW_TO = table.concat({
	"HOW TO FARM AURA",
	"",
	"1. Pick a side and a class: Heroes or Villains (CLASS button).",
	"2. Say heroic (or villainous) lines in chat or the SHOUT box.",
	"   The right line at the right moment is worth way more.",
	"   Repeating yourself is cringe.",
	"3. Challenge a boss at an altar, or fight the other side.",
	"   Click: slash    Q: dash    F: ultimate (at S style)",
	"4. Fight cool: last-second dodges, no damage taken,",
	"   call your shot, finish with your ultimate...",
	"   then walk away without looking back.",
	"",
	"Spawns are safe zones. Heroes can't hurt heroes,",
	"and villains can't hurt villains.",
}, "\n")

-- Team colors (BrickColor is what Teams and SpawnLocations use).
World.TeamColors = {
	Undecided = BrickColor.Gray(),
	Good = BrickColor.new("Bright yellow"),
	Evil = BrickColor.new("Really red"),
}

-- Where nobody can be hurt by other players: { position, radius }.
World.SafeZones = {}

local function spawnPad(name: string, position: Vector3, teamColor: BrickColor, color: Color3, facing: Vector3)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	-- Players spawn facing the pad's front (-Z), so point it at `facing`.
	spawn.CFrame = CFrame.lookAt(position, Vector3.new(facing.X, position.Y, facing.Z))
	spawn.Color = color
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 3
	spawn.Neutral = false
	spawn.TeamColor = teamColor
	spawn.AllowTeamChangeOnTouch = false
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = map

	local radius = Config.Pvp.SafeZoneRadius
	block({
		Name = name .. "SafeZone",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(position.X, 1.05, position.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.85,
		CanCollide = false,
		CanQuery = false,
	})
	table.insert(World.SafeZones, { position = position, radius = radius })
	return spawn
end

local function sign(position: Vector3, lines: { { text: string, size: number, color: Color3 } })
	local post = block({
		Name = "Sign",
		Size = Vector3.new(1, 10, 1),
		Position = position + Vector3.new(0, 5, 0),
		Color = Color3.fromRGB(50, 45, 55),
		Material = Enum.Material.Wood,
	})
	billboard(post, lines, 7)
end

local function buildBase(side: string, position: Vector3)
	local isGood = side == "Good"
	local color = if isGood then Color3.fromRGB(255, 205, 80) else Color3.fromRGB(200, 40, 60)
	local stone = if isGood then Color3.fromRGB(235, 230, 215) else Color3.fromRGB(40, 30, 40)
	spawnPad(if isGood then "HeroSpawn" else "VillainSpawn", position, World.TeamColors[side], color, World.ArenaCenter)

	-- A ring of columns (heroes) or spikes (villains) around the base.
	for i = 0, 7 do
		local angle = (i / 8) * math.pi * 2
		local at = position + Vector3.new(math.sin(angle) * 24, 0, math.cos(angle) * 24)
		if isGood then
			block({ Name = "Column", Size = Vector3.new(3, 16, 3), Position = at + Vector3.new(0, 8, 0), Color = stone, Material = Enum.Material.Marble })
			block({ Name = "ColumnLight", Size = Vector3.new(2, 2, 2), Position = at + Vector3.new(0, 17, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false })
		else
			block({
				Name = "Spike",
				Size = Vector3.new(3, 18, 3),
				CFrame = CFrame.new(at + Vector3.new(0, 8, 0)) * CFrame.Angles(math.rad(12), angle, 0),
				Color = stone,
				Material = Enum.Material.Basalt,
			})
			block({ Name = "SpikeGlow", Size = Vector3.new(1.5, 1.5, 1.5), Position = at + Vector3.new(0, 17.5, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false })
		end
	end

	sign(position + Vector3.new(0, 0, 18), {
		{ text = if isGood then "HALL OF HEROES" else "VILLAINS' LAIR", size = 26, color = color },
		{ text = "Safe zone: no PvP inside the glowing circle", size = 14, color = Color3.fromRGB(230, 230, 230) },
	})
end

local function buildSpawns()
	-- Lobby: where undecided players pick a class.
	local spawnPos = Vector3.new(0, 1.5, Config.ArenaRadius + 35)
	spawnPad("LobbySpawn", spawnPos, World.TeamColors.Undecided, Color3.fromRGB(200, 200, 210), World.ArenaCenter)

	buildBase("Good", Vector3.new(-(Config.ArenaRadius + 70), 1.5, 0))
	buildBase("Evil", Vector3.new(Config.ArenaRadius + 70, 1.5, 0))

	-- Front-left of the lobby spawn (players spawn facing the arena, -Z),
	-- with its Front face (-Z) turned to look at the spawn.
	local boardPos = spawnPos + Vector3.new(-22, 9.5, -12)
	local board = block({
		Name = "HowToBoard",
		Size = Vector3.new(30, 18, 1),
		CFrame = CFrame.lookAt(boardPos, Vector3.new(spawnPos.X, boardPos.Y, spawnPos.Z)),
		Color = Color3.fromRGB(35, 30, 45),
		Material = Enum.Material.SmoothPlastic,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = board
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 30
	text.TextColor3 = Color3.fromRGB(255, 235, 190)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Text = HOW_TO
	text.Parent = surface
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 30)
	padding.PaddingTop = UDim.new(0, 24)
	padding.Parent = text
end

function World.inSafeZone(position: Vector3): boolean
	for _, zone in ipairs(World.SafeZones) do
		local dx, dz = position.X - zone.position.X, position.Z - zone.position.Z
		if dx * dx + dz * dz <= zone.radius * zone.radius then
			return true
		end
	end
	return false
end

function World.build()
	setupLighting()
	buildArena()
	buildSpawns()
	local altars = buildAltars()
	map.Parent = workspace
	return altars
end

return World
