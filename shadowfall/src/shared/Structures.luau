--!nonstrict
-- Everything you can build in your base, plus the shared model builder. The server uses Build()
-- for blueprints and finished buildings; the client uses the same function for the placement
-- hologram, so what you preview is exactly what gets built.
--
-- A structure's origin is the centre of its bottom face. `size` is its bounding box, used for
-- overlap checks. Part offsets (`at`) are measured from that origin.

local Structures = {}

Structures.Categories = { "Walls", "Floors", "Stations", "Utility", "Defense", "Decor" }

local WOOD = Color3.fromRGB(120, 84, 52)
local WOOD_DARK = Color3.fromRGB(80, 56, 36)
local PLANK = Color3.fromRGB(170, 126, 82)
local STONE = Color3.fromRGB(110, 110, 116)
local METAL = Color3.fromRGB(120, 124, 132)

local function p(size: Vector3, at: Vector3, color: Color3, material: Enum.Material, extra)
	local spec = { size = size, at = at, color = color, material = material }
	for k, v in extra or {} do
		spec[k] = v
	end
	return spec
end

local function wallParts(color: Color3, material: Enum.Material, trim: Color3, thickness: number)
	return {
		p(Vector3.new(8, 10, thickness), Vector3.new(0, 5, 0), color, material),
		p(Vector3.new(0.7, 10, thickness + 0.3), Vector3.new(-3.65, 5, 0), trim, Enum.Material.Wood),
		p(Vector3.new(0.7, 10, thickness + 0.3), Vector3.new(3.65, 5, 0), trim, Enum.Material.Wood),
		p(Vector3.new(8, 0.6, thickness + 0.3), Vector3.new(0, 9.7, 0), trim, Enum.Material.Wood),
	}
end

Structures.List = {
	-- Walls -------------------------------------------------------------------------------
	{
		id = "WoodWall", name = "Wooden Wall", category = "Walls", size = Vector3.new(8, 10, 1), snap = 4,
		cost = { Wood = 6 }, desc = "A simple wall of rough boards.",
		parts = wallParts(WOOD, Enum.Material.WoodPlanks, WOOD_DARK, 1),
	},
	{
		id = "WoodDoorway", name = "Wooden Doorway", category = "Walls", size = Vector3.new(8, 10, 1), snap = 4,
		cost = { Wood = 5 }, desc = "A wall with a gap to walk through.",
		parts = {
			p(Vector3.new(2, 10, 1), Vector3.new(-3, 5, 0), WOOD, Enum.Material.WoodPlanks),
			p(Vector3.new(2, 10, 1), Vector3.new(3, 5, 0), WOOD, Enum.Material.WoodPlanks),
			p(Vector3.new(4, 3, 1), Vector3.new(0, 8.5, 0), WOOD, Enum.Material.WoodPlanks),
			p(Vector3.new(4.4, 0.5, 1.3), Vector3.new(0, 7, 0), WOOD_DARK, Enum.Material.Wood),
		},
	},
	{
		id = "WoodWindow", name = "Wooden Window Wall", category = "Walls", size = Vector3.new(8, 10, 1), snap = 4,
		cost = { Wood = 5 }, desc = "Watch the dark from inside.",
		parts = {
			p(Vector3.new(8, 4, 1), Vector3.new(0, 2, 0), WOOD, Enum.Material.WoodPlanks),
			p(Vector3.new(8, 3, 1), Vector3.new(0, 8.5, 0), WOOD, Enum.Material.WoodPlanks),
			p(Vector3.new(2, 3, 1), Vector3.new(-3, 5.5, 0), WOOD, Enum.Material.WoodPlanks),
			p(Vector3.new(2, 3, 1), Vector3.new(3, 5.5, 0), WOOD, Enum.Material.WoodPlanks),
			p(Vector3.new(0.3, 3, 0.4), Vector3.new(0, 5.5, 0), WOOD_DARK, Enum.Material.Wood),
		},
	},
	{
		id = "Fence", name = "Fence", category = "Walls", size = Vector3.new(8, 4, 1), snap = 4,
		cost = { Wood = 3 }, desc = "Knee-high. It won't stop anything, but it looks like home.",
		parts = {
			p(Vector3.new(0.6, 4, 0.6), Vector3.new(-3.7, 2, 0), WOOD_DARK, Enum.Material.Wood),
			p(Vector3.new(0.6, 4, 0.6), Vector3.new(3.7, 2, 0), WOOD_DARK, Enum.Material.Wood),
			p(Vector3.new(8, 0.5, 0.3), Vector3.new(0, 1.4, 0), WOOD, Enum.Material.Wood),
			p(Vector3.new(8, 0.5, 0.3), Vector3.new(0, 3.2, 0), WOOD, Enum.Material.Wood),
		},
	},
	{
		id = "PlankWall", name = "Plank Wall", category = "Walls", size = Vector3.new(8, 10, 1), snap = 4, needs = "Carpenter",
		cost = { Planks = 6 }, desc = "Neatly joined planks. A carpenter's work.",
		parts = wallParts(PLANK, Enum.Material.WoodPlanks, Color3.fromRGB(110, 76, 46), 1),
	},
	{
		id = "StoneWall", name = "Stone Wall", category = "Walls", size = Vector3.new(8, 10, 1.6), snap = 4,
		cost = { Stone = 10 }, desc = "Heavy, cold and solid.",
		parts = {
			p(Vector3.new(8, 10, 1.6), Vector3.new(0, 5, 0), STONE, Enum.Material.Cobblestone),
			p(Vector3.new(8.4, 0.8, 2), Vector3.new(0, 0.4, 0), Color3.fromRGB(90, 90, 96), Enum.Material.Slate),
		},
	},
	{
		id = "MetalWall", name = "Metal Wall", category = "Walls", size = Vector3.new(8, 10, 1), snap = 4, needs = "Blacksmith", baseLevel = 3,
		cost = { IronBar = 4, Scrap = 4 }, desc = "Riveted plate. A blacksmith's work.",
		parts = {
			p(Vector3.new(8, 10, 1), Vector3.new(0, 5, 0), METAL, Enum.Material.DiamondPlate),
			p(Vector3.new(8.2, 0.6, 1.2), Vector3.new(0, 3.3, 0), Color3.fromRGB(80, 82, 90), Enum.Material.Metal),
			p(Vector3.new(8.2, 0.6, 1.2), Vector3.new(0, 6.7, 0), Color3.fromRGB(80, 82, 90), Enum.Material.Metal),
		},
	},

	-- Floors -------------------------------------------------------------------------------
	{
		id = "WoodFloor", name = "Wooden Floor", category = "Floors", size = Vector3.new(8, 1, 8), snap = 4,
		cost = { Wood = 4 }, desc = "A floor tile. Stack it on walls to make a roof.",
		parts = { p(Vector3.new(8, 1, 8), Vector3.new(0, 0.5, 0), WOOD, Enum.Material.WoodPlanks) },
	},
	{
		id = "StoneFloor", name = "Stone Floor", category = "Floors", size = Vector3.new(8, 1, 8), snap = 4,
		cost = { Stone = 5 }, desc = "Flagstones.",
		parts = { p(Vector3.new(8, 1, 8), Vector3.new(0, 0.5, 0), Color3.fromRGB(96, 94, 98), Enum.Material.Slate) },
	},
	{
		id = "WoodRamp", name = "Wooden Ramp", category = "Floors", size = Vector3.new(8, 10, 8), snap = 4,
		cost = { Wood = 6 }, desc = "Climbs one wall's height.",
		parts = { p(Vector3.new(8, 10, 8), Vector3.new(0, 5, 0), WOOD, Enum.Material.WoodPlanks, { class = "WedgePart" }) },
	},

	-- Stations -----------------------------------------------------------------------------
	{
		id = "Workbench", name = "Workbench", category = "Stations", size = Vector3.new(6, 3.6, 3), station = "Workbench",
		cost = { Wood = 12, Stone = 4 }, desc = "Unlocks workbench recipes while you're in your base.",
		parts = {
			p(Vector3.new(6, 0.5, 3), Vector3.new(0, 3, 0), WOOD, Enum.Material.WoodPlanks),
			p(Vector3.new(0.5, 2.8, 0.5), Vector3.new(-2.6, 1.4, -1.1), WOOD_DARK, Enum.Material.Wood),
			p(Vector3.new(0.5, 2.8, 0.5), Vector3.new(2.6, 1.4, -1.1), WOOD_DARK, Enum.Material.Wood),
			p(Vector3.new(0.5, 2.8, 0.5), Vector3.new(-2.6, 1.4, 1.1), WOOD_DARK, Enum.Material.Wood),
			p(Vector3.new(0.5, 2.8, 0.5), Vector3.new(2.6, 1.4, 1.1), WOOD_DARK, Enum.Material.Wood),
			p(Vector3.new(1.2, 0.8, 0.8), Vector3.new(-1.8, 3.65, 0), Color3.fromRGB(60, 60, 66), Enum.Material.Metal),
			p(Vector3.new(1.6, 0.2, 0.5), Vector3.new(1.2, 3.35, 0.4), Color3.fromRGB(150, 150, 155), Enum.Material.Metal),
		},
	},
	{
		id = "CarpenterBench", name = "Carpenter's Bench", category = "Stations", size = Vector3.new(7, 4.4, 3.6), station = "CarpenterBench", needs = "Carpenter",
		cost = { Wood = 20, Stone = 6 }, desc = "Turns wood into planks. Needs a rescued carpenter.",
		parts = {
			p(Vector3.new(7, 0.6, 3.6), Vector3.new(0, 3, 0), PLANK, Enum.Material.WoodPlanks),
			p(Vector3.new(6.4, 2.7, 3), Vector3.new(0, 1.35, 0), WOOD_DARK, Enum.Material.WoodPlanks),
			p(Vector3.new(0.15, 2.2, 2.2), Vector3.new(0.5, 3.6, 0), Color3.fromRGB(190, 190, 195), Enum.Material.Metal, { shape = Enum.PartType.Cylinder, rot = Vector3.new(0, 90, 0) }),
		},
	},
	{
		id = "Forge", name = "Forge", category = "Stations", size = Vector3.new(6, 7, 6), station = "Forge", needs = "Blacksmith",
		cost = { Stone = 25, Scrap = 10 }, desc = "Melts scrap into iron. Needs a rescued blacksmith.",
		fire = true,
		parts = {
			p(Vector3.new(6, 4, 6), Vector3.new(0, 2, 0), Color3.fromRGB(80, 74, 72), Enum.Material.Cobblestone),
			p(Vector3.new(3, 1.6, 0.3), Vector3.new(0, 2, -3.05), Color3.fromRGB(255, 120, 30), Enum.Material.Neon, { collide = false, glow = true }),
			p(Vector3.new(2, 3, 2), Vector3.new(1.4, 5.5, 1.4), Color3.fromRGB(70, 66, 64), Enum.Material.Brick),
			p(Vector3.new(2.2, 1, 1.2), Vector3.new(-1.6, 4.5, -1.2), Color3.fromRGB(40, 40, 46), Enum.Material.Metal),
		},
	},

	-- Utility -------------------------------------------------------------------------------
	{
		id = "Lamp", name = "Lamp Post", category = "Utility", size = Vector3.new(2, 10, 2),
		cost = { Scrap = 3, Cloth = 1 }, desc = "Light keeps the mind steady. Each lamp adds sanity regeneration in your base.",
		lamp = true,
		parts = {
			p(Vector3.new(0.6, 9, 0.6), Vector3.new(0, 4.5, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Metal),
			p(Vector3.new(1.6, 1.2, 1.6), Vector3.new(0, 9.4, 0), Color3.fromRGB(255, 220, 150), Enum.Material.Neon, { collide = false, glow = true }),
			p(Vector3.new(2, 0.4, 2), Vector3.new(0, 0.2, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Metal),
		},
	},
	{
		id = "Campfire", name = "Campfire", category = "Utility", size = Vector3.new(5, 2, 5),
		cost = { Wood = 8, Stone = 4 }, desc = "Heals you while you stand near it.",
		fire = true, heal = true,
		parts = {
			p(Vector3.new(1, 1, 5), Vector3.new(0, 0.5, 0), WOOD_DARK, Enum.Material.Wood, { rot = Vector3.new(0, 45, 0) }),
			p(Vector3.new(1, 1, 5), Vector3.new(0, 0.5, 0), WOOD_DARK, Enum.Material.Wood, { rot = Vector3.new(0, -45, 0) }),
			p(Vector3.new(1.6, 1.4, 1.6), Vector3.new(0, 1, 0), Color3.fromRGB(255, 140, 50), Enum.Material.Neon, { collide = false, glow = true }),
		},
	},
	{
		id = "Bed", name = "Bed", category = "Utility", size = Vector3.new(5, 2.6, 8),
		cost = { Wood = 10, Cloth = 6 }, desc = "You respawn here instead of at the camp.",
		bed = true,
		parts = {
			p(Vector3.new(5, 1, 8), Vector3.new(0, 0.9, 0), WOOD_DARK, Enum.Material.Wood),
			p(Vector3.new(4.6, 0.8, 7.4), Vector3.new(0, 1.8, 0), Color3.fromRGB(110, 40, 40), Enum.Material.Fabric),
			p(Vector3.new(3.6, 0.5, 1.4), Vector3.new(0, 2.35, 3), Color3.fromRGB(230, 225, 215), Enum.Material.Fabric),
			p(Vector3.new(5, 2.6, 0.5), Vector3.new(0, 1.3, 3.9), WOOD_DARK, Enum.Material.Wood),
		},
	},

	-- Defense --------------------------------------------------------------------------------
	{
		id = "LightTurret", name = "Light Turret", category = "Defense", size = Vector3.new(4, 7, 4), needs = "Blacksmith", baseLevel = 3,
		cost = { IronBar = 6, LightCore = 1 }, desc = "Zaps shadows that come near your barrier.",
		turret = true,
		parts = {
			p(Vector3.new(4, 1, 4), Vector3.new(0, 0.5, 0), METAL, Enum.Material.DiamondPlate),
			p(Vector3.new(1.4, 4, 1.4), Vector3.new(0, 3, 0), Color3.fromRGB(70, 72, 80), Enum.Material.Metal),
			p(Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 6, 0), Color3.fromRGB(255, 245, 190), Enum.Material.Neon, { shape = Enum.PartType.Ball, collide = false, glow = true }),
		},
	},
	{
		id = "Spikes", name = "Spike Barricade", category = "Defense", size = Vector3.new(8, 3, 2), snap = 4,
		cost = { Wood = 8 }, desc = "Sharpened stakes. Mostly for morale.",
		parts = {
			p(Vector3.new(8, 0.6, 0.6), Vector3.new(0, 0.8, 0), WOOD_DARK, Enum.Material.Wood),
			p(Vector3.new(0.5, 3, 0.5), Vector3.new(-3, 1.5, 0), WOOD, Enum.Material.Wood, { rot = Vector3.new(-30, 0, 0) }),
			p(Vector3.new(0.5, 3, 0.5), Vector3.new(-1, 1.5, 0), WOOD, Enum.Material.Wood, { rot = Vector3.new(-30, 0, 0) }),
			p(Vector3.new(0.5, 3, 0.5), Vector3.new(1, 1.5, 0), WOOD, Enum.Material.Wood, { rot = Vector3.new(-30, 0, 0) }),
			p(Vector3.new(0.5, 3, 0.5), Vector3.new(3, 1.5, 0), WOOD, Enum.Material.Wood, { rot = Vector3.new(-30, 0, 0) }),
		},
	},

	-- Decor ----------------------------------------------------------------------------------
	{
		id = "Table", name = "Table", category = "Decor", size = Vector3.new(6, 3.2, 4),
		cost = { Wood = 5 }, desc = "Somewhere to eat, if there were food.",
		parts = {
			p(Vector3.new(6, 0.4, 4), Vector3.new(0, 3, 0), PLANK, Enum.Material.WoodPlanks),
			p(Vector3.new(0.4, 2.8, 0.4), Vector3.new(-2.6, 1.4, -1.6), WOOD_DARK, Enum.Material.Wood),
			p(Vector3.new(0.4, 2.8, 0.4), Vector3.new(2.6, 1.4, -1.6), WOOD_DARK, Enum.Material.Wood),
			p(Vector3.new(0.4, 2.8, 0.4), Vector3.new(-2.6, 1.4, 1.6), WOOD_DARK, Enum.Material.Wood),
			p(Vector3.new(0.4, 2.8, 0.4), Vector3.new(2.6, 1.4, 1.6), WOOD_DARK, Enum.Material.Wood),
		},
	},
	{
		id = "Crate", name = "Storage Crate", category = "Decor", size = Vector3.new(3, 3, 3),
		cost = { Wood = 4 }, desc = "Stacks nicely.",
		parts = {
			p(Vector3.new(3, 3, 3), Vector3.new(0, 1.5, 0), WOOD, Enum.Material.WoodPlanks),
			p(Vector3.new(3.1, 0.4, 3.1), Vector3.new(0, 2.6, 0), WOOD_DARK, Enum.Material.Wood),
			p(Vector3.new(3.1, 0.4, 3.1), Vector3.new(0, 0.4, 0), WOOD_DARK, Enum.Material.Wood),
		},
	},
	{
		id = "DuckHouse", name = "Duck House", category = "Decor", size = Vector3.new(4, 4, 4),
		cost = { Wood = 6, Cloth = 2 }, desc = "A tiny house for Biscuit. Biscuit approves.",
		parts = {
			p(Vector3.new(4, 2.6, 4), Vector3.new(0, 1.3, 0), Color3.fromRGB(230, 200, 120), Enum.Material.WoodPlanks),
			p(Vector3.new(4.4, 1.4, 4.4), Vector3.new(0, 3.3, 0), Color3.fromRGB(190, 70, 60), Enum.Material.Slate, { class = "WedgePart" }),
			p(Vector3.new(1.6, 1.6, 0.2), Vector3.new(0, 1, -2), Color3.fromRGB(40, 30, 24), Enum.Material.SmoothPlastic, { collide = false }),
		},
	},
}

Structures.ById = {}
for index, def in Structures.List do
	def.order = index
	Structures.ById[def.id] = def
end

-- Builds a structure's model at `cf` (bottom centre). Parts are anchored; their original look is
-- saved in attributes so blueprints can switch between hologram and solid.
function Structures.Build(def, cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = def.id
	local bounds = Instance.new("Part")
	bounds.Name = "Bounds"
	bounds.Size = def.size
	bounds.CFrame = cf * CFrame.new(0, def.size.Y / 2, 0)
	bounds.Anchored = true
	bounds.CanCollide = false
	bounds.CanTouch = false
	bounds.Transparency = 1
	bounds.Parent = model
	model.PrimaryPart = bounds
	for index, spec in def.parts do
		local part: BasePart = (Instance.new(spec.class or "Part") :: any)
		part.Name = "Piece" .. index
		part.Size = spec.size
		local rot = spec.rot or Vector3.zero
		part.CFrame = cf * CFrame.new(spec.at) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		part.Anchored = true
		part.Color = spec.color
		part.Material = spec.material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanTouch = false
		if spec.shape and part:IsA("Part") then
			part.Shape = spec.shape
		end
		part:SetAttribute("Collide", spec.collide ~= false)
		part:SetAttribute("Glow", spec.glow == true)
		part:SetAttribute("BaseColor", spec.color)
		part:SetAttribute("BaseMaterial", spec.material.Name)
		part.Parent = model
	end
	model:SetAttribute("StructureId", def.id)
	return model
end

-- Makes a model look like a hologram (`progress` 0-1 fills it in from the bottom up).
function Structures.SetHologram(model: Model, color: Color3, progress: number)
	local pieces = {}
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Bounds" then
			table.insert(pieces, part)
		end
	end
	table.sort(pieces, function(a, b)
		return a.Position.Y < b.Position.Y
	end)
	local solid = math.floor(#pieces * progress + 1e-6)
	for index, part in pieces do
		part.CanCollide = false
		part.CastShadow = false
		if index <= solid then
			part.Color = part:GetAttribute("BaseColor")
			part.Material = (Enum.Material :: any)[part:GetAttribute("BaseMaterial")]
			part.Transparency = 0.15
		else
			part.Color = color
			part.Material = Enum.Material.ForceField
			part.Transparency = 0.2
		end
	end
end

-- Turns a finished blueprint into the real thing.
function Structures.SetSolid(model: Model)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Bounds" then
			part.Color = part:GetAttribute("BaseColor")
			part.Material = (Enum.Material :: any)[part:GetAttribute("BaseMaterial")]
			part.Transparency = 0
			part.CanCollide = part:GetAttribute("Collide") == true
			part.CastShadow = true
		end
	end
end

-- The base crystal: a floating crystal over a stone pedestal. Bigger and brighter per level.
function Structures.BuildCrystal(cf: CFrame, level: number): Model
	local model = Instance.new("Model")
	model.Name = "BaseCrystal"
	local function part(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?)
		local x = Instance.new("Part")
		x.Name = name
		x.Size = size
		x.CFrame = cf * offset
		x.Anchored = true
		x.Color = color
		x.Material = material
		x.CanTouch = false
		x.TopSurface = Enum.SurfaceType.Smooth
		x.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			x.Shape = shape
		end
		x.Parent = model
		return x
	end
	local base = part("Pedestal", Vector3.new(6, 1.5, 6), CFrame.new(0, 0.75, 0), Color3.fromRGB(60, 56, 70), Enum.Material.Slate)
	part("Step", Vector3.new(4, 1.5, 4), CFrame.new(0, 2.25, 0), Color3.fromRGB(70, 66, 82), Enum.Material.Slate)
	local s = 1 + (level - 1) * 0.15
	local crystal = part("Crystal", Vector3.new(2.2, 5, 2.2) * s, CFrame.new(0, 7 + level * 0.3, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(150, 210, 255), Enum.Material.Neon)
	crystal.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 210, 255)
	light.Range = 18 + level * 4
	light.Brightness = 2
	light.Parent = crystal
	for i = 1, math.min(level, 5) do
		local a = i / 5 * math.pi * 2
		local shard = part("Shard", Vector3.new(0.6, 1.6, 0.6) * s, CFrame.new(math.cos(a) * 2.6, 7, math.sin(a) * 2.6) * CFrame.Angles(0.3, a, 0.2), Color3.fromRGB(190, 230, 255), Enum.Material.Neon)
		shard.CanCollide = false
	end
	model.PrimaryPart = base
	return model
end

return Structures
