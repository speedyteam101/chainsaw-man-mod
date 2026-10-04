--!nonstrict
-- World layout. The Act 2 world runs west to east along the X axis: five big cities, one per area,
-- each about 720 x 760 studs, joined by bridges over the void. Each bridge ends in a gate that only
-- opens at the area's level.
--
-- `shift` is how far east an area moved when the cities were added; landmark data written for the
-- old layout (townsfolk, merchants, journal pages, Rift islands) is moved by it.
-- The Act 1 version of Hollow Creek (the night of the shift) sits far away at negative Z.

local Areas = {}

Areas.Act1Origin = Vector3.new(0, 0, -1400)
Areas.Act1MaxZ = -900 -- anything south of this line is the Act 1 map

Areas.List = {
	{
		id = "town",
		name = "Hollow Creek",
		subtitle = "What's left of home",
		level = 1,
		minX = -580,
		maxX = 255,
		-- The playable ground (used for the town layout, enemy spawns and resources).
		bounds = { minX = -540, maxX = 180, minZ = -380, maxZ = 380 },
		shift = 0,
		center = Vector3.new(0, 0, 0),
		spawn = Vector3.new(0, 4, 30),
		hpMult = 1,
		damageMult = 1,
		essenceMult = 1,
		enemies = { { type = "Shade", count = 30 }, { type = "Lurker", count = 10 } },
		boss = { id = "Warden", arena = Vector3.new(0, 0, -135) },
		color = Color3.fromRGB(255, 170, 90),
	},
	{
		id = "woods",
		name = "Whispering Woods",
		subtitle = "The trees grew back wrong",
		level = 2,
		minX = 255,
		maxX = 1135,
		gateX = 325,
		bounds = { minX = 340, maxX = 1060, minZ = -380, maxZ = 380 },
		shift = 220,
		center = Vector3.new(700, 0, 0),
		spawn = Vector3.new(355, 4, 0),
		hpMult = 1.6,
		damageMult = 1.5,
		essenceMult = 1.5,
		enemies = { { type = "Shade", count = 26 }, { type = "Lurker", count = 15 }, { type = "Howler", count = 15 } },
		boss = { id = "Stag", arena = Vector3.new(780, 0, -85) },
		color = Color3.fromRGB(120, 220, 140),
	},
	{
		id = "rift",
		name = "The Rift",
		subtitle = "Pieces of other towns, falling forever",
		level = 3,
		minX = 1135,
		maxX = 2015,
		gateX = 1205,
		bounds = { minX = 1220, maxX = 1940, minZ = -380, maxZ = 380 },
		shift = 655,
		center = Vector3.new(1580, 0, 0),
		spawn = Vector3.new(1235, 4, 0),
		hpMult = 2.5,
		damageMult = 2.2,
		essenceMult = 2.2,
		enemies = { { type = "Howler", count = 15 }, { type = "Lurker", count = 13 }, { type = "Brute", count = 10 }, { type = "Shade", count = 14 } },
		boss = { id = "Eyes", arena = Vector3.new(1630, 0, 0) },
		color = Color3.fromRGB(170, 120, 255),
	},
	{
		id = "cathedral",
		name = "Sunken Cathedral",
		subtitle = "They still sing down here",
		level = 4,
		minX = 2015,
		maxX = 2895,
		gateX = 2085,
		bounds = { minX = 2100, maxX = 2820, minZ = -380, maxZ = 380 },
		shift = 1120,
		center = Vector3.new(2460, 0, 0),
		spawn = Vector3.new(2115, 4, 0),
		hpMult = 3.6,
		damageMult = 3.0,
		essenceMult = 3.0,
		enemies = { { type = "Wraith", count = 18 }, { type = "Brute", count = 10 }, { type = "Howler", count = 13 }, { type = "Lurker", count = 12 } },
		boss = { id = "Choir", arena = Vector3.new(2520, 0, 0) },
		color = Color3.fromRGB(110, 170, 255),
	},
	{
		id = "heart",
		name = "Heart of Shadow",
		subtitle = "Where the dark comes from",
		level = 5,
		minX = 2895,
		maxX = 3800,
		gateX = 2965,
		bounds = { minX = 2980, maxX = 3700, minZ = -380, maxZ = 380 },
		shift = 1580,
		center = Vector3.new(3340, 0, 0),
		spawn = Vector3.new(2995, 4, 0),
		hpMult = 5.0,
		damageMult = 4.0,
		essenceMult = 4.0,
		enemies = { { type = "Wraith", count = 15 }, { type = "Brute", count = 10 }, { type = "Howler", count = 10 }, { type = "Lurker", count = 10 } },
		boss = { id = "King", arena = Vector3.new(3355, 0, 0) },
		color = Color3.fromRGB(255, 60, 80),
	},
}

Areas.ById = {}
for index, area in Areas.List do
	area.index = index
	Areas.ById[area.id] = area
end

-- Which area a world position is in. Returns nil for the Act 1 map.
function Areas.At(position: Vector3)
	if position.Z < Areas.Act1MaxZ then
		return nil
	end
	for _, area in Areas.List do
		if position.X >= area.minX and position.X < area.maxX then
			return area
		end
	end
	return position.X < 0 and Areas.List[1] or Areas.List[#Areas.List]
end

-- The highest-level area a position has crossed into, judged by gates (used to block players).
function Areas.GateLevelAt(position: Vector3): number
	local level = 1
	for _, area in Areas.List do
		if area.gateX and position.X > area.gateX then
			level = area.level
		end
	end
	return level
end

return Areas
