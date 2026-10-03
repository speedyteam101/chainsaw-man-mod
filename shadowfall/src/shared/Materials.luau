--!nonstrict
-- Every material in the game. Raw materials come from gathering and shadows; refined ones are crafted.

local Materials = {}

Materials.List = {
	{ id = "Wood", name = "Wood", color = Color3.fromRGB(150, 105, 65), source = "Chop trees" },
	{ id = "Stone", name = "Stone", color = Color3.fromRGB(150, 150, 155), source = "Mine rocks and rubble" },
	{ id = "Scrap", name = "Scrap Metal", color = Color3.fromRGB(170, 120, 90), source = "Salvage cars and crates" },
	{ id = "Cloth", name = "Cloth", color = Color3.fromRGB(210, 200, 175), source = "Break supply crates" },
	{ id = "Crystal", name = "Crystal Shard", color = Color3.fromRGB(170, 120, 255), source = "Mine Rift crystals" },
	{ id = "Umbral", name = "Umbral Shard", color = Color3.fromRGB(120, 30, 60), source = "Dropped by shadows; mined in the Heart" },
	{ id = "Planks", name = "Planks", color = Color3.fromRGB(190, 140, 90), source = "Crafted (carpenter)" },
	{ id = "IronBar", name = "Iron Bar", color = Color3.fromRGB(190, 195, 205), source = "Crafted (blacksmith)" },
	{ id = "Rope", name = "Rope", color = Color3.fromRGB(200, 170, 120), source = "Crafted" },
	{ id = "LightCore", name = "Light Core", color = Color3.fromRGB(255, 240, 170), source = "Crafted (blacksmith)" },
}

Materials.ById = {}
for index, material in Materials.List do
	material.order = index
	Materials.ById[material.id] = material
end

-- "Wood 5, Stone 3" in material-list order.
function Materials.Describe(cost): string
	local parts = {}
	for _, material in Materials.List do
		local amount = cost[material.id]
		if amount and amount > 0 then
			table.insert(parts, string.format("%s %d", material.name, amount))
		end
	end
	return table.concat(parts, ", ")
end

return Materials
