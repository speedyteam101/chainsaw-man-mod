--!nonstrict
-- Merchants and what they sell (prices in Essence). `give` adds materials; `item` adds an item.

local Shops = {}

-- Items that only come from shops (crafted items are described in Recipes).
Shops.Items = {
	FateDie = { name = "Fate Die", desc = "A bone die that hums. Use it at the shrine for a free reroll." },
	StarShard = { name = "Star Shard", desc = "A sliver of a star. Your next roll is about three times as likely to be Legendary or better." },
	DuckBread = { name = "Duck Bread", desc = "Biscuit's favourite. Feed it to Biscuit (use it near them) for a big sanity boost." },
}

Shops.List = {
	{
		id = "scavenger",
		name = "Ollie the Scavenger",
		title = "Scavenger",
		area = "town",
		at = Vector3.new(-36, 0, 10),
		shirt = Color3.fromRGB(110, 100, 60),
		pants = Color3.fromRGB(60, 50, 40),
		greeting = "Found it, fixed it, flogging it. Everything's got a price, friend. Even in the end of the world.",
		stock = {
			{ id = "wood", name = "Wood x20", price = 30, give = { Wood = 20 } },
			{ id = "stone", name = "Stone x20", price = 30, give = { Stone = 20 } },
			{ id = "scrap", name = "Scrap Metal x15", price = 45, give = { Scrap = 15 } },
			{ id = "cloth", name = "Cloth x10", price = 40, give = { Cloth = 10 } },
			{ id = "rope", name = "Rope x5", price = 40, give = { Rope = 5 } },
			{ id = "planks", name = "Planks x10", price = 90, give = { Planks = 10 } },
			{ id = "iron", name = "Iron Bars x5", price = 130, give = { IronBar = 5 } },
		},
	},
	{
		id = "medic",
		name = "Doc Mercer",
		title = "Medic",
		area = "town",
		at = Vector3.new(16, 0, -36),
		shirt = Color3.fromRGB(230, 230, 226),
		pants = Color3.fromRGB(50, 60, 80),
		greeting = "Bandages, tonics, and something for the shakes. And bread for the duck. I'm not a monster.",
		stock = {
			{ id = "bandage", name = "Bandage", price = 35, item = "Bandage" },
			{ id = "tonic", name = "Sanity Tonic", price = 60, item = "Tonic" },
			{ id = "bomb", name = "Light Bomb", price = 90, item = "LightBomb" },
			{ id = "bread", name = "Duck Bread", price = 25, item = "DuckBread" },
		},
	},
	{
		id = "stranger",
		name = "The Hooded Stranger",
		title = "???",
		area = "woods",
		at = Vector3.new(400, 0, -40),
		hooded = true,
		shirt = Color3.fromRGB(26, 22, 30),
		pants = Color3.fromRGB(20, 18, 24),
		greeting = "You can see me. Interesting. Most of them stopped seeing me a long time ago. I trade in luck.",
		stock = {
			{ id = "die", name = "Fate Die", price = 400, item = "FateDie" },
			{ id = "star", name = "Star Shard", price = 900, item = "StarShard" },
			{ id = "core", name = "Light Core", price = 220, give = { LightCore = 1 } },
			{ id = "crystal", name = "Crystal Shards x5", price = 200, give = { Crystal = 5 } },
			{ id = "umbral", name = "Umbral Shards x10", price = 150, give = { Umbral = 10 } },
		},
	},
}

Shops.ById = {}
for _, shop in Shops.List do
	Shops.ById[shop.id] = shop
	shop.byItem = {}
	for _, entry in shop.stock do
		shop.byItem[entry.id] = entry
	end
end

return Shops
