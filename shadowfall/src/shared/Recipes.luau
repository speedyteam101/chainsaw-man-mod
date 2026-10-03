--!nonstrict
-- Crafting recipes.
--   station: nil (craft anywhere), or a station you have built in your base and are standing inside
--   needs:   a role you must have rescued someone for ("Carpenter" / "Blacksmith")
--   kind:    "material" (adds to inventory), "tool" / "gear" (owned once, passive), "consumable" (stackable, use with 1/2/3)

local Recipes = {}

Recipes.List = {
	-- Refining
	{ id = "Planks", name = "Planks x2", kind = "material", output = { Planks = 2 }, cost = { Wood = 3 }, station = "CarpenterBench", needs = "Carpenter", desc = "Sawn boards for sturdier buildings." },
	{ id = "IronBar", name = "Iron Bar", kind = "material", output = { IronBar = 1 }, cost = { Scrap = 4 }, station = "Forge", needs = "Blacksmith", desc = "Scrap melted down into something useful." },
	{ id = "Rope", name = "Rope", kind = "material", output = { Rope = 1 }, cost = { Cloth = 2 }, desc = "Twisted strips of cloth." },
	{ id = "LightCore", name = "Light Core", kind = "material", output = { LightCore = 1 }, cost = { Crystal = 2, Umbral = 1, IronBar = 1 }, station = "Forge", needs = "Blacksmith", desc = "A caged spark. Shadows hate being near one." },

	-- Tools (gathering multipliers)
	{ id = "StoneAxe", name = "Stone Axe", kind = "tool", cost = { Wood = 5, Stone = 4 }, desc = "Chop trees twice as fast.", bonus = { Wood = 2 } },
	{ id = "StonePick", name = "Stone Pickaxe", kind = "tool", cost = { Wood = 5, Stone = 6 }, desc = "Mine rock and crystal twice as fast.", bonus = { Stone = 2, Crystal = 2, Umbral = 2 } },
	{ id = "SalvageKit", name = "Salvage Kit", kind = "tool", cost = { Scrap = 6, Rope = 2 }, station = "Workbench", desc = "Salvage twice as much scrap and cloth.", bonus = { Scrap = 2, Cloth = 2 } },
	{ id = "IronAxe", name = "Iron Axe", kind = "tool", cost = { Planks = 4, IronBar = 3 }, station = "Forge", needs = "Blacksmith", requiresItem = "StoneAxe", desc = "Chop trees three times as fast.", bonus = { Wood = 3 } },
	{ id = "IronPick", name = "Iron Pickaxe", kind = "tool", cost = { Planks = 4, IronBar = 4 }, station = "Forge", needs = "Blacksmith", requiresItem = "StonePick", desc = "Mine three times as fast.", bonus = { Stone = 3, Crystal = 3, Umbral = 3 } },

	-- Gear (passive)
	{ id = "Lantern", name = "Lantern", kind = "gear", cost = { Scrap = 4, Cloth = 2, Umbral = 2 }, station = "Workbench", desc = "A little light that goes everywhere with you. Sanity drains 40% slower." },
	{ id = "Coat", name = "Reinforced Coat", kind = "gear", cost = { Cloth = 8, IronBar = 3 }, station = "Forge", needs = "Blacksmith", desc = "Take 15% less damage." },
	{ id = "Charm", name = "Shadow Charm", kind = "gear", cost = { Umbral = 6, LightCore = 1 }, station = "Forge", needs = "Blacksmith", desc = "Deal 10% more damage." },

	-- Consumables
	{ id = "Bandage", name = "Bandage", kind = "consumable", key = "1", cost = { Cloth = 2 }, desc = "Heal 35% of your health." },
	{ id = "Tonic", name = "Sanity Tonic", kind = "consumable", key = "2", cost = { Wood = 1, Cloth = 1, Umbral = 1 }, station = "Workbench", desc = "Restore 40 sanity." },
	{ id = "LightBomb", name = "Light Bomb", kind = "consumable", key = "3", cost = { Scrap = 2, Umbral = 2 }, station = "Workbench", desc = "A burst of light that damages and stuns nearby shadows." },
}

Recipes.ById = {}
for index, recipe in Recipes.List do
	recipe.order = index
	Recipes.ById[recipe.id] = recipe
end

Recipes.Consumables = { "Bandage", "Tonic", "LightBomb" }

Recipes.StationNames = {
	Workbench = "Workbench",
	CarpenterBench = "Carpenter's Bench",
	Forge = "Forge",
}

return Recipes
