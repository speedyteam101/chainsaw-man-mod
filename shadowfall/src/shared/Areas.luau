--!nonstrict
-- World layout. The Act 2 world runs west to east along the X axis, one area after another,
-- joined by bridges over the void. Each bridge ends in a gate that only opens at the area's level.
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
		minX = -190,
		maxX = 255,
		center = Vector3.new(0, 0, 0),
		spawn = Vector3.new(0, 4, 30),
		hpMult = 1,
		damageMult = 1,
		essenceMult = 1,
		enemies = { { type = "Shade", count = 12 }, { type = "Lurker", count = 4 } },
		boss = { id = "Warden", arena = Vector3.new(0, 0, -135) },
		color = Color3.fromRGB(255, 170, 90),
	},
	{
		id = "woods",
		name = "Whispering Woods",
		subtitle = "The trees grew back wrong",
		level = 2,
		minX = 255,
		maxX = 710,
		gateX = 325,
		center = Vector3.new(480, 0, 0),
		spawn = Vector3.new(345, 4, 0),
		hpMult = 1.6,
		damageMult = 1.5,
		essenceMult = 1.5,
		enemies = { { type = "Shade", count = 9 }, { type = "Lurker", count = 5 }, { type = "Howler", count = 5 } },
		boss = { id = "Stag", arena = Vector3.new(560, 0, -85) },
		color = Color3.fromRGB(120, 220, 140),
	},
	{
		id = "rift",
		name = "The Rift",
		subtitle = "Pieces of other towns, falling forever",
		level = 3,
		minX = 710,
		maxX = 1130,
		gateX = 785,
		center = Vector3.new(925, 0, 0),
		spawn = Vector3.new(810, 4, 0),
		hpMult = 2.5,
		damageMult = 2.2,
		essenceMult = 2.2,
		enemies = { { type = "Howler", count = 6 }, { type = "Lurker", count = 5 }, { type = "Brute", count = 4 }, { type = "Shade", count = 5 } },
		boss = { id = "Eyes", arena = Vector3.new(975, 0, 0) },
		color = Color3.fromRGB(170, 120, 255),
	},
	{
		id = "cathedral",
		name = "Sunken Cathedral",
		subtitle = "They still sing down here",
		level = 4,
		minX = 1130,
		maxX = 1550,
		gateX = 1195,
		center = Vector3.new(1340, 0, 0),
		spawn = Vector3.new(1215, 4, 0),
		hpMult = 3.6,
		damageMult = 3.0,
		essenceMult = 3.0,
		enemies = { { type = "Wraith", count = 7 }, { type = "Brute", count = 4 }, { type = "Howler", count = 5 }, { type = "Lurker", count = 4 } },
		boss = { id = "Choir", arena = Vector3.new(1400, 0, 0) },
		color = Color3.fromRGB(110, 170, 255),
	},
	{
		id = "heart",
		name = "Heart of Shadow",
		subtitle = "Where the dark comes from",
		level = 5,
		minX = 1550,
		maxX = 2000,
		gateX = 1615,
		center = Vector3.new(1760, 0, 0),
		spawn = Vector3.new(1638, 4, 0),
		hpMult = 5.0,
		damageMult = 4.0,
		essenceMult = 4.0,
		enemies = { { type = "Wraith", count = 7 }, { type = "Brute", count = 5 }, { type = "Howler", count = 5 }, { type = "Lurker", count = 5 } },
		boss = { id = "King", arena = Vector3.new(1775, 0, 0) },
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
