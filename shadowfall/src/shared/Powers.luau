--!nonstrict
-- Every rollable power. Each power has a passive and four moves (Z, X, C, V) that unlock at levels 1-4.
-- Level 5 unlocks Awakening (G) for every power.
--
-- Move kinds (handled by server/PowerService):
--   projectile  fires `count` bolts toward the aim point
--   nova        burst around the caster
--   dash        caster lunges forward, hitting everything along the path
--   beam        instant line from the caster toward the aim point
--   zone        lingering field at the aim point (or the caster) that ticks damage
--   strike      telegraphed blast that lands at the aim point after `delay`
--   buff        self buff (heal, damage, speed)
--
-- Effects: burn {dps, time}, slow {mult, time}, stun (seconds), knockback (force),
--          pull (force), weaken {mult, time}, lifesteal (fraction of damage dealt)

local Powers = {}

Powers.Rarities = {
	{ id = "Common", weight = 42, color = Color3.fromRGB(190, 190, 190), damage = 1.0 },
	{ id = "Uncommon", weight = 30, color = Color3.fromRGB(90, 220, 120), damage = 1.08 },
	{ id = "Rare", weight = 16, color = Color3.fromRGB(80, 160, 255), damage = 1.16 },
	{ id = "Epic", weight = 9, color = Color3.fromRGB(190, 90, 255), damage = 1.25 },
	{ id = "Legendary", weight = 2.5, color = Color3.fromRGB(255, 190, 40), damage = 1.38 },
	{ id = "Mythic", weight = 0.5, color = Color3.fromRGB(255, 70, 90), damage = 1.55 },
}

Powers.RarityById = {}
for index, rarity in Powers.Rarities do
	rarity.rank = index
	Powers.RarityById[rarity.id] = rarity
end

Powers.Keys = { "Z", "X", "C", "V" }

Powers.List = {
	{
		id = "Ember",
		rarity = "Common",
		color = Color3.fromRGB(255, 120, 40),
		blurb = "A spark that refused to go out. Fire is the oldest answer to the dark.",
		passive = "Your basic attacks set shadows alight.",
		passiveEffect = { m1Burn = { dps = 3, time = 2 } },
		moves = {
			{ name = "Fireball", kind = "projectile", damage = 26, cooldown = 3, speed = 95, range = 110, radius = 2.2, count = 1, effect = { burn = { dps = 6, time = 3 } } },
			{ name = "Flame Ring", kind = "nova", damage = 34, cooldown = 7, radius = 14, effect = { burn = { dps = 8, time = 3 }, knockback = 40 } },
			{ name = "Blaze Dash", kind = "dash", damage = 30, cooldown = 6, distance = 34, width = 7, effect = { burn = { dps = 8, time = 3 } } },
			{ name = "Inferno Meteor", kind = "strike", damage = 120, cooldown = 16, radius = 18, delay = 1.0, range = 90, effect = { burn = { dps = 14, time = 4 }, knockback = 70 } },
		},
	},
	{
		id = "Gale",
		rarity = "Common",
		color = Color3.fromRGB(170, 255, 210),
		blurb = "The wind that carried the town here. Now it answers you.",
		passive = "+12% movement speed.",
		passiveEffect = { speed = 1.12 },
		moves = {
			{ name = "Wind Blade", kind = "projectile", damage = 22, cooldown = 2.5, speed = 120, range = 100, radius = 2.6, count = 1, pierce = true, effect = {} },
			{ name = "Gust", kind = "nova", damage = 24, cooldown = 6, radius = 16, effect = { knockback = 110 } },
			{ name = "Tailwind", kind = "dash", damage = 26, cooldown = 5, distance = 44, width = 6, effect = { knockback = 50 } },
			{ name = "Cyclone", kind = "zone", damage = 14, cooldown = 15, radius = 16, duration = 5, tick = 0.5, range = 70, effect = { pull = 30 } },
		},
	},
	{
		id = "Frost",
		rarity = "Uncommon",
		color = Color3.fromRGB(140, 220, 255),
		blurb = "Cold enough that even smoke stops moving.",
		passive = "Your basic attacks slow shadows.",
		passiveEffect = { m1Slow = { mult = 0.75, time = 1.5 } },
		moves = {
			{ name = "Ice Shards", kind = "projectile", damage = 14, cooldown = 3, speed = 105, range = 95, radius = 1.8, count = 3, spread = 14, effect = { slow = { mult = 0.6, time = 2 } } },
			{ name = "Frost Nova", kind = "nova", damage = 30, cooldown = 8, radius = 15, effect = { stun = 1.4 } },
			{ name = "Glacier Lance", kind = "beam", damage = 48, cooldown = 7, range = 80, width = 5, effect = { slow = { mult = 0.5, time = 3 } } },
			{ name = "Blizzard", kind = "zone", damage = 18, cooldown = 16, radius = 20, duration = 6, tick = 0.5, range = 70, effect = { slow = { mult = 0.4, time = 1 } } },
		},
	},
	{
		id = "Stone",
		rarity = "Uncommon",
		color = Color3.fromRGB(170, 130, 90),
		blurb = "The ground under the town came with it. It remembers being home.",
		passive = "Take 12% less damage.",
		passiveEffect = { defense = 0.88 },
		moves = {
			{ name = "Boulder", kind = "projectile", damage = 34, cooldown = 4, speed = 75, range = 90, radius = 3.4, count = 1, effect = { knockback = 80 } },
			{ name = "Quake", kind = "nova", damage = 32, cooldown = 8, radius = 17, effect = { stun = 1.2 } },
			{ name = "Earthen Charge", kind = "dash", damage = 38, cooldown = 7, distance = 30, width = 8, effect = { knockback = 90, stun = 0.6 } },
			{ name = "Monolith Fall", kind = "strike", damage = 140, cooldown = 17, radius = 16, delay = 1.2, range = 80, effect = { stun = 2 } },
		},
	},
	{
		id = "Volt",
		rarity = "Rare",
		color = Color3.fromRGB(255, 240, 90),
		blurb = "The town's last power line, still humming, now humming through you.",
		passive = "Every 4th basic attack chains lightning to a nearby shadow.",
		passiveEffect = { m1Chain = 18 },
		moves = {
			{ name = "Spark Bolt", kind = "projectile", damage = 24, cooldown = 1.8, speed = 170, range = 120, radius = 1.8, count = 1, effect = { stun = 0.3 } },
			{ name = "Discharge", kind = "nova", damage = 40, cooldown = 7, radius = 16, effect = { stun = 0.8 } },
			{ name = "Lightning Step", kind = "dash", damage = 34, cooldown = 4.5, distance = 50, width = 6, effect = { stun = 0.5 } },
			{ name = "Thunder Judgment", kind = "strike", damage = 150, cooldown = 16, radius = 15, delay = 0.7, range = 100, effect = { stun = 1.5 } },
		},
	},
	{
		id = "Radiance",
		rarity = "Epic",
		color = Color3.fromRGB(255, 245, 200),
		blurb = "Light, pure and simple. The one thing every shadow is afraid of.",
		passive = "+20% damage with basic attacks. Basic attacks weaken shadows.",
		passiveEffect = { m1Damage = 1.2, m1Weaken = { mult = 1.15, time = 3 } },
		moves = {
			{ name = "Light Lance", kind = "beam", damage = 44, cooldown = 4, range = 100, width = 4, effect = { weaken = { mult = 1.2, time = 4 } } },
			{ name = "Solar Flare", kind = "nova", damage = 36, cooldown = 9, radius = 20, effect = { stun = 2 } },
			{ name = "Halo", kind = "buff", cooldown = 18, heal = 0.35, duration = 6, damageMult = 1.2 },
			{ name = "Sunrise", kind = "strike", damage = 175, cooldown = 18, radius = 24, delay = 1.3, range = 90, effect = { weaken = { mult = 1.3, time = 5 } } },
		},
	},
	{
		id = "Gravity",
		rarity = "Epic",
		color = Color3.fromRGB(150, 110, 255),
		blurb = "Everything falls. You decide where.",
		passive = "Your basic attacks pull shadows toward you.",
		passiveEffect = { m1Pull = 18 },
		moves = {
			{ name = "Gravity Orb", kind = "projectile", damage = 28, cooldown = 3, speed = 70, range = 90, radius = 3, count = 1, pierce = true, effect = { pull = 40 } },
			{ name = "Repulse", kind = "nova", damage = 34, cooldown = 7, radius = 18, effect = { knockback = 140 } },
			{ name = "Singularity", kind = "zone", damage = 22, cooldown = 14, radius = 18, duration = 4, tick = 0.4, range = 80, effect = { pull = 55 } },
			{ name = "Collapse", kind = "strike", damage = 165, cooldown = 17, radius = 20, delay = 1.1, range = 90, effect = { stun = 1.8, pull = 60 } },
		},
	},
	{
		id = "Eclipse",
		rarity = "Legendary",
		color = Color3.fromRGB(220, 30, 70),
		blurb = "You did not escape the shadows. You took a piece of them with you.",
		passive = "Heal for 10% of all damage you deal.",
		passiveEffect = { lifesteal = 0.1 },
		moves = {
			{ name = "Umbral Spear", kind = "projectile", damage = 40, cooldown = 2.5, speed = 140, range = 120, radius = 2, count = 1, pierce = true, effect = { weaken = { mult = 1.2, time = 3 } } },
			{ name = "Devour", kind = "nova", damage = 46, cooldown = 7, radius = 18, effect = { pull = 50, lifesteal = 0.3 } },
			{ name = "Shadow Step", kind = "dash", damage = 42, cooldown = 4, distance = 55, width = 7, effect = { stun = 0.7 } },
			{ name = "Total Eclipse", kind = "zone", damage = 32, cooldown = 16, radius = 24, duration = 6, tick = 0.5, range = 0, effect = { weaken = { mult = 1.35, time = 1 }, lifesteal = 0.2 } },
		},
	},
	{
		id = "Dawnbringer",
		rarity = "Mythic",
		color = Color3.fromRGB(255, 210, 120),
		blurb = "The morning this world never had. The shadows have a word for you, and it is not a kind one.",
		passive = "+25% damage. Basic attacks heal you.",
		passiveEffect = { allDamage = 1.25, m1Heal = 2 },
		moves = {
			{ name = "Dawn Arrow", kind = "projectile", damage = 30, cooldown = 1.6, speed = 160, range = 130, radius = 2.2, count = 3, spread = 8, pierce = true, effect = { burn = { dps = 8, time = 3 } } },
			{ name = "Daybreak", kind = "nova", damage = 55, cooldown = 6, radius = 22, effect = { stun = 1.5, knockback = 80 } },
			{ name = "Radiant Rush", kind = "dash", damage = 50, cooldown = 4, distance = 60, width = 9, effect = { burn = { dps = 10, time = 3 } } },
			{ name = "Second Sun", kind = "strike", damage = 230, cooldown = 18, radius = 28, delay = 1.4, range = 100, effect = { burn = { dps = 20, time = 5 }, stun = 1.5 } },
		},
	},
}

Powers.ById = {}
for _, power in Powers.List do
	Powers.ById[power.id] = power
	for index, move in power.moves do
		move.slot = index
		move.unlockLevel = index
		move.key = Powers.Keys[index]
	end
end

-- Weighted roll. `rng` is a Random object, `forceLegendary` is the pity guarantee.
function Powers.Roll(rng: Random, forceLegendary: boolean?)
	local pool = Powers.Rarities
	local total = 0
	for _, rarity in pool do
		if not forceLegendary or rarity.rank >= Powers.RarityById.Legendary.rank then
			total += rarity.weight
		end
	end
	local pick = rng:NextNumber() * total
	local chosen = pool[#pool]
	for _, rarity in pool do
		if not forceLegendary or rarity.rank >= Powers.RarityById.Legendary.rank then
			pick -= rarity.weight
			if pick <= 0 then
				chosen = rarity
				break
			end
		end
	end
	local candidates = {}
	for _, power in Powers.List do
		if power.rarity == chosen.id then
			table.insert(candidates, power)
		end
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

-- Total chance (percent) of each rarity, for the odds table in the menu.
function Powers.Odds()
	local total = 0
	for _, rarity in Powers.Rarities do
		total += rarity.weight
	end
	local odds = {}
	for _, rarity in Powers.Rarities do
		table.insert(odds, { id = rarity.id, color = rarity.color, percent = rarity.weight / total * 100 })
	end
	return odds
end

return Powers
