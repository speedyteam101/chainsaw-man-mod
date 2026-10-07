-- Ability types. A player-made ability picks one type, an element, and three
-- levels (Damage, Size, Speed, each 1..Config.AbilityLevelMax). What each level
-- means depends on the type (see `labels`). Stronger abilities get a longer
-- cooldown and cost more energy, so any combination is allowed and stays fair.

local AbilityTypes = {}

AbilityTypes.Order = {
	"Projectile",
	"Barrage",
	"Beam",
	"Blast",
	"Explosion",
	"MeteorRain",
	"Melee",
	"DashStrike",
	"Teleport",
	"Shield",
	"Heal",
	"PowerUp",
}

-- Each entry:
--   displayName, description
--   labels   = what the Damage / Size / Speed levels control (nil = unused)
--   weights  = how much each level adds to cooldown and energy cost
--   cooldown = base cooldown in seconds, energy = base energy cost
--   compute(d, s, v) -> table of real numbers used by the server
AbilityTypes.List = {
	Projectile = {
		displayName = "Projectile",
		description = "Fire a blast that flies toward your aim.",
		labels = { damage = "Damage", size = "Size", speed = "Speed" },
		weights = { damage = 1, size = 0.5, speed = 0.4 },
		cooldown = 2.5,
		energy = 15,
		compute = function(d, s, v)
			return { damage = 10 + 3 * d, radius = 0.8 + 0.25 * s, speed = 70 + 12 * v, range = 260 }
		end,
	},
	Barrage = {
		displayName = "Barrage",
		description = "Rapid-fire a spread of small shots.",
		labels = { damage = "Damage per shot", size = "Shot count", speed = "Speed" },
		weights = { damage = 1, size = 1, speed = 0.4 },
		cooldown = 5,
		energy = 25,
		compute = function(d, s, v)
			return {
				damage = 3 + 1.2 * d,
				count = 3 + math.floor(s / 2),
				radius = 0.6,
				speed = 80 + 10 * v,
				range = 200,
			}
		end,
	},
	Beam = {
		displayName = "Beam",
		description = "A long energy beam that pierces through everyone in its path.",
		labels = { damage = "Damage", size = "Width", speed = "Length" },
		weights = { damage = 1, size = 0.6, speed = 0.5 },
		cooldown = 6,
		energy = 30,
		compute = function(d, s, v)
			return { damage = 15 + 4 * d, width = 1 + 0.4 * s, range = 40 + 8 * v }
		end,
	},
	Blast = {
		displayName = "Shockwave",
		description = "Explode outward from your body, hitting everyone around you.",
		labels = { damage = "Damage", size = "Radius", speed = "Knockback" },
		weights = { damage = 1, size = 0.7, speed = 0.3 },
		cooldown = 6,
		energy = 30,
		compute = function(d, s, v)
			return { damage = 14 + 3.5 * d, radius = 8 + 1.5 * s, knockback = 30 + 8 * v }
		end,
	},
	Explosion = {
		displayName = "Explosion",
		description = "After a short warning, the spot you aim at explodes.",
		labels = { damage = "Damage", size = "Radius", speed = "Range" },
		weights = { damage = 1, size = 0.7, speed = 0.3 },
		cooldown = 6,
		energy = 30,
		compute = function(d, s, v)
			return { damage = 16 + 3.8 * d, radius = 5 + 1.2 * s, range = 40 + 10 * v, delay = 0.6 }
		end,
	},
	MeteorRain = {
		displayName = "Meteor Rain",
		description = "Call down a rain of falling blasts around your aim.",
		labels = { damage = "Damage per meteor", size = "Area", speed = "Meteor count" },
		weights = { damage = 1, size = 0.4, speed = 0.9 },
		cooldown = 10,
		energy = 40,
		compute = function(d, s, v)
			return { damage = 6 + 2 * d, area = 8 + 1.2 * s, count = 4 + v, radius = 4, range = 120 }
		end,
	},
	Melee = {
		displayName = "Melee Combo",
		description = "A powerful close-range strike combo.",
		labels = { damage = "Damage per hit", size = "Reach", speed = "Hits" },
		weights = { damage = 1, size = 0.4, speed = 0.8 },
		cooldown = 2,
		energy = 10,
		compute = function(d, s, v)
			return { damage = 8 + 2.6 * d, reach = 6 + 0.8 * s, hits = 1 + math.floor(v / 3), knockback = 25 }
		end,
	},
	DashStrike = {
		displayName = "Dash Strike",
		description = "Dash toward your aim, hitting everyone you pass through.",
		labels = { damage = "Damage", size = "Hit width", speed = "Distance" },
		weights = { damage = 1, size = 0.4, speed = 0.4 },
		cooldown = 4,
		energy = 20,
		compute = function(d, s, v)
			return { damage = 10 + 3 * d, width = 3 + 0.4 * s, distance = 20 + 5 * v }
		end,
	},
	Teleport = {
		displayName = "Teleport",
		description = "Vanish and reappear at your aim, with a shockwave where you land.",
		labels = { damage = "Landing damage", size = "Landing radius", speed = "Range" },
		weights = { damage = 0.8, size = 0.4, speed = 0.5 },
		cooldown = 5,
		energy = 20,
		compute = function(d, s, v)
			return { damage = 2.5 * d, radius = 5 + 0.6 * s, range = 25 + 7 * v }
		end,
	},
	Shield = {
		displayName = "Barrier",
		description = "Surround yourself with a barrier that blocks damage.",
		labels = { damage = "Strength", size = nil, speed = "Duration" },
		weights = { damage = 1, size = 0, speed = 0.6 },
		cooldown = 12,
		energy = 30,
		compute = function(d, _s, v)
			return { absorb = 20 + 8 * d, duration = 3 + 0.5 * v }
		end,
	},
	Heal = {
		displayName = "Heal",
		description = "Recover health.",
		labels = { damage = "Healing", size = nil, speed = nil },
		weights = { damage = 1.2, size = 0, speed = 0 },
		cooldown = 14,
		energy = 35,
		compute = function(d, _s, _v)
			return { heal = 12 + 5 * d }
		end,
	},
	PowerUp = {
		displayName = "Power Up / Transform",
		description = "Transform for 12 seconds: more damage, more speed, a huge aura.",
		labels = { damage = "Damage boost", size = nil, speed = "Speed boost" },
		weights = { damage = 1, size = 0, speed = 0.6 },
		cooldown = 30,
		energy = 50,
		compute = function(d, _s, v)
			return { damageMultiplier = 1.1 + 0.04 * d, walkSpeedBonus = 2 + 1.5 * v, duration = 12 }
		end,
	},
}

function AbilityTypes.get(name: string)
	return AbilityTypes.List[name]
end

function AbilityTypes.isValid(name: any): boolean
	return type(name) == "string" and AbilityTypes.List[name] ~= nil
end

-- Weighted strength of an ability's levels. Used for cooldown and energy cost.
local function strength(def, d: number, s: number, v: number): number
	return d * def.weights.damage + s * def.weights.size + v * def.weights.speed
end

-- Returns the real numbers for an ability, plus its cooldown and energy cost.
function AbilityTypes.computeStats(ability)
	local def = AbilityTypes.List[ability.type]
	local stats = def.compute(ability.damage, ability.size, ability.speed)
	local power = strength(def, ability.damage, ability.size, ability.speed)
	-- Scale from ~0.6x (all level 1) to ~2x (everything maxed)
	local scale = 0.55 + 0.05 * power
	stats.cooldown = math.floor(def.cooldown * scale * 10 + 0.5) / 10
	stats.energy = math.floor(def.energy * scale + 0.5)
	return stats
end

return AbilityTypes
