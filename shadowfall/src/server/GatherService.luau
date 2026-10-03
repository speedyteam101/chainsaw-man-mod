--!nonstrict
-- Resource nodes. Hit them with your basic attack to gather: trees give wood, rocks and rubble
-- give stone, cars give scrap, supply crates give cloth, Rift crystals give crystal shards and
-- obsidian in the Heart gives umbral shards. Crafted tools multiply what you get.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Areas)
local Config = require(ReplicatedStorage.Shared.Config)
local Materials = require(ReplicatedStorage.Shared.Materials)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)
local PlayerData = require(script.Parent.PlayerData)
local InventoryService = require(script.Parent.InventoryService)
local PassService = require(script.Parent.PassService)
local WorldBuilder = require(script.Parent.World.WorldBuilder)
local B = require(script.Parent.World.Builders)

local GatherService = {}

local KINDS = {
	Tree = { hp = 6, material = "Wood", perHit = 1, final = { Wood = 3 }, verb = "Chop" },
	Car = { hp = 8, material = "Scrap", perHit = 1, final = { Scrap = 3, Cloth = 1 }, verb = "Salvage" },
	Rock = { hp = 8, material = "Stone", perHit = 1, final = { Stone = 3 }, verb = "Mine" },
	Crate = { hp = 3, material = "Cloth", perHit = 1, final = { Cloth = 2, Scrap = 1 }, verb = "Break" },
	Rubble = { hp = 6, material = "Stone", perHit = 1, final = { Scrap = 2, Stone = 1 }, verb = "Dig" },
	Crystal = { hp = 5, material = "Crystal", perHit = 1, final = { Crystal = 1 }, verb = "Mine" },
	Obsidian = { hp = 7, material = "Umbral", perHit = 1, final = { Umbral = 2 }, verb = "Mine" },
}

local nodes = {}
local rng = Random.new()

local function partsOf(model: Instance)
	local parts = {}
	if model:IsA("BasePart") then
		table.insert(parts, model)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end

local function register(model: Instance, kind: string)
	local parts = partsOf(model)
	if #parts == 0 then
		return
	end
	local sum = Vector3.zero
	local lowest = math.huge
	for _, part in parts do
		sum += part.Position
		lowest = math.min(lowest, part.Position.Y - part.Size.Y / 2)
		part:SetAttribute("BaseTransparency", part.Transparency)
		part:SetAttribute("BaseCollide", part.CanCollide)
	end
	local center = sum / #parts
	local node = {
		model = model,
		kind = kind,
		def = KINDS[kind],
		parts = parts,
		position = Vector3.new(center.X, lowest + 3, center.Z),
		hp = KINDS[kind].hp,
	}
	model:SetAttribute("GatherKind", kind)
	table.insert(nodes, node)
end

-- Extra nodes scattered with the same spawn sampling as shadows -------------------------------

local function rock(parent: Instance, at: Vector3, color: Color3)
	local model = Instance.new("Model")
	model.Name = "Rock"
	for i = 1, rng:NextInteger(2, 3) do
		local size = Vector3.new(rng:NextNumber(2.5, 4.5), rng:NextNumber(2, 3.5), rng:NextNumber(2.5, 4.5))
		B.block(model, {
			name = "Stone",
			size = size,
			cf = CFrame.new(at + Vector3.new(rng:NextNumber(-1.2, 1.2), size.Y / 2 - 0.4 + (i - 1) * 0.6, rng:NextNumber(-1.2, 1.2))) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)),
			color = color,
			material = Enum.Material.Slate,
		})
	end
	model.Parent = parent
	return model
end

local function crate(parent: Instance, at: Vector3)
	local model = Instance.new("Model")
	model.Name = "SupplyCrate"
	local cf = CFrame.new(at + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	B.block(model, { name = "Box", size = Vector3.new(3, 3, 3), cf = cf, color = Color3.fromRGB(120, 90, 55), material = Enum.Material.WoodPlanks })
	B.block(model, { name = "Band", size = Vector3.new(3.1, 0.4, 3.1), cf = cf * CFrame.new(0, 0.9, 0), color = Color3.fromRGB(70, 70, 76), material = Enum.Material.Metal })
	B.block(model, { name = "Cloth", size = Vector3.new(2.4, 0.5, 2.4), cf = cf * CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0.3, 0.1), color = Color3.fromRGB(200, 190, 160), material = Enum.Material.Fabric })
	model.Parent = parent
	return model
end

local function rubble(parent: Instance, at: Vector3)
	local model = rock(parent, at, Color3.fromRGB(90, 94, 100))
	model.Name = "Rubble"
	B.block(model, { name = "Rebar", size = Vector3.new(0.3, 0.3, 4), cf = CFrame.new(at + Vector3.new(0, 2, 0)) * CFrame.Angles(0.5, rng:NextNumber(0, 6), 0), color = Color3.fromRGB(120, 80, 60), material = Enum.Material.CorrodedMetal })
	return model
end

local function obsidian(parent: Instance, at: Vector3)
	local model = Instance.new("Model")
	model.Name = "Obsidian"
	for _ = 1, 3 do
		local h = rng:NextNumber(3, 6)
		B.block(model, {
			class = "WedgePart",
			name = "Spike",
			size = Vector3.new(2, h, 2),
			cf = CFrame.new(at + Vector3.new(rng:NextNumber(-1.5, 1.5), h / 2, rng:NextNumber(-1.5, 1.5))) * CFrame.Angles(0, rng:NextNumber(0, 6), rng:NextNumber(-0.2, 0.2)),
			color = Color3.fromRGB(14, 10, 16),
			material = Enum.Material.Glass,
		})
	end
	B.block(model, { name = "Vein", size = Vector3.new(0.3, 3, 0.3), cf = CFrame.new(at + Vector3.new(0, 1.5, 0)), color = Color3.fromRGB(220, 20, 50), material = Enum.Material.Neon, collide = false })
	model.Parent = parent
	return model
end

local function scatter(world, folder: Folder)
	local sampler = Random.new(4242)
	local function region(area)
		local minX = (area.gateX or area.minX) + 14
		local maxX = area.maxX - 6
		if area.id == "town" then
			minX, maxX = -172, 172
		end
		return Vector3.new(minX, 0, -165), Vector3.new(maxX, 0, 165)
	end
	local function avoidFor(area)
		local avoid = { { at = area.boss.arena, r = 45 }, { at = area.spawn, r = 20 } }
		if area.id == "town" then
			table.insert(avoid, { at = Vector3.zero, r = Config.Act2.CampRadius + 15 })
		end
		return avoid
	end
	local plan = {
		town = { { "Rock", 22 }, { "Crate", 24 } },
		woods = { { "Rock", 26 }, { "Crate", 8 } },
		rift = { { "Rock", 10 } },
		cathedral = { { "Rubble", 24 }, { "Crate", 12 } },
		heart = { { "Obsidian", 20 }, { "Rubble", 8 } },
	}
	for _, area in Areas.List do
		local minCorner, maxCorner = region(area)
		for _, entry in plan[area.id] or {} do
			local kind, count = entry[1], entry[2]
			for _, p in WorldBuilder.SamplePoints(world.floors, minCorner, maxCorner, count, sampler, avoidFor(area)) do
				local model
				if kind == "Rock" then
					model = rock(folder, p, area.id == "rift" and Color3.fromRGB(60, 50, 76) or Color3.fromRGB(100, 100, 104))
				elseif kind == "Crate" then
					model = crate(folder, p)
				elseif kind == "Rubble" then
					model = rubble(folder, p)
				elseif kind == "Obsidian" then
					model = obsidian(folder, p)
				end
				register(model, kind)
			end
		end
	end
end

-- Gathering -----------------------------------------------------------------------------------

local function toolMultiplier(player: Player, material: string): number
	local data = PlayerData.Get(player)
	local best = 1
	if data then
		for id, count in data.items do
			local recipe = Recipes.ById[id]
			if count > 0 and recipe and recipe.kind == "tool" and recipe.bonus and recipe.bonus[material] then
				best = math.max(best, recipe.bonus[material])
			end
		end
	end
	return best
end

local function setVisible(node, visible: boolean)
	for _, part in node.parts do
		part.Transparency = visible and part:GetAttribute("BaseTransparency") or 1
		part.CanCollide = visible and part:GetAttribute("BaseCollide") or false
		for _, child in part:GetChildren() do
			if child:IsA("Light") then
				child.Enabled = visible
			end
		end
	end
end

local function hit(player: Player, node)
	local def = node.def
	node.hp -= 1
	local amount = def.perHit * toolMultiplier(player, def.material)
	local belt = PassService.GatherMultiplier(player)
	if belt ~= 1 then
		amount = math.ceil(amount * belt) -- Builder's Belt
	end
	InventoryService.Add(player, def.material, amount, false)
	local color = Materials.ById[def.material].color
	Remotes.Fx:FireAllClients("Gather", { position = node.position, color = color, kind = node.kind })
	Remotes.Notify:FireClient(player, "Gathered", { id = def.material, amount = amount, position = node.position })
	if node.hp <= 0 then
		node.depleted = true
		for id, bonus in def.final do
			local total = bonus * toolMultiplier(player, id)
			if belt ~= 1 then
				total = math.ceil(total * belt)
			end
			InventoryService.Add(player, id, total, false)
			Remotes.Notify:FireClient(player, "Gathered", { id = id, amount = total, position = node.position })
		end
		setVisible(node, false)
		Remotes.Fx:FireAllClients("GatherBreak", { position = node.position, color = color })
		task.delay(rng:NextNumber(60, 110), function()
			node.hp = def.hp
			node.depleted = false
			setVisible(node, true)
		end)
	end
end

function GatherService.Start(world)
	local folder = Instance.new("Folder")
	folder.Name = "Resources"
	folder.Parent = world.map
	for _, entry in world.nodes do
		register(entry.model, entry.kind)
	end
	scatter(world, folder)

	Registry.M1Swing:Connect(function(player: Player, center: Vector3, radius: number)
		local count = 0
		for _, node in nodes do
			local offset = node.position - center
			if not node.depleted and Vector2.new(offset.X, offset.Z).Magnitude <= radius + 3 and math.abs(offset.Y) < 10 then
				hit(player, node)
				count += 1
				if count >= 2 then
					break
				end
			end
		end
	end)
end

return GatherService
