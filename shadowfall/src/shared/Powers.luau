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
--   buff        self buff (heal, damageMult, speedMult, iframes = invulnerable seconds,
--               rewind = restore the health you had that many seconds ago)
--   summon      raises `count` allies (ally = "Skeleton" | "Clone") that fight for `duration`
--   blinkchain  teleports between up to `count` shadows within `range`, striking each one
--   (strike also takes `count` + `spread` to rain several blasts around the aim point)
--
-- Effects: burn {dps, time}, slow {mult, time}, stun (seconds), knockback (force),
--          pull (force), weaken {mult, time}, lifesteal (fraction of damage dealt),
--          chain {count, damage (fraction), range} (arcs to nearby shadows)
-- `vfx` picks the visual style the client uses for casts, projectiles and impacts.

local Powers = {}

Powers.Rarities = {
	{ id = "Common", weight = 42, color = Color3.fromRGB(190, 190, 190), damage = 1.0 },
	{ id = "Uncommon", weight = 30, color = Color3.fromRGB(90, 220, 120), damage = 1.08 },
	{ id = "Rare", weight = 16, color = Color3.fromRGB(80, 160, 255), damage = 1.16 },
	{ id = "Epic", weight = 9, color = Color3.fromRGB(190, 90, 255), damage = 1.25 },
	{ id = "Legendary", weight = 2.4, color = Color3.fromRGB(255, 190, 40), damage = 1.38 },
	{ id = "Mythic", weight = 0.5, color = Color3.fromRGB(255, 70, 90), damage = 1.55 },
	{ id = "Transcendent", weight = 0.1, color = Color3.fromRGB(150, 255, 240), damage = 1.75 },
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
		vfx = "fire",
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
		vfx = "wind",
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
		vfx = "ice",
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
		vfx = "stone",
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
		vfx = "volt",
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
		vfx = "light",
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
		vfx = "gravity",
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
		vfx = "eclipse",
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
		vfx = "dawn",
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
	-- Rare ------------------------------------------------------------------------------------
	{
		id = "Venom",
		rarity = "Rare",
		vfx = "venom",
		color = Color3.fromRGB(120, 220, 60),
		blurb = "The marsh behind the mill was always poisonous. Now so are you.",
		passive = "Basic attacks poison shadows.",
		passiveEffect = { m1Burn = { dps = 4, time = 3 } },
		moves = {
			{ name = "Toxic Spit", kind = "projectile", damage = 18, cooldown = 2.2, speed = 90, range = 90, radius = 1.8, count = 1, effect = { burn = { dps = 9, time = 4 }, weaken = { mult = 1.1, time = 3 } } },
			{ name = "Plague Cloud", kind = "zone", damage = 10, cooldown = 9, radius = 14, duration = 5, tick = 0.5, range = 70, effect = { burn = { dps = 6, time = 2 }, slow = { mult = 0.6, time = 1 } } },
			{ name = "Serpent Lunge", kind = "dash", damage = 32, cooldown = 5.5, distance = 36, width = 6, effect = { burn = { dps = 10, time = 3 } } },
			{ name = "Pandemic", kind = "strike", damage = 110, cooldown = 16, radius = 20, delay = 0.9, range = 90, effect = { burn = { dps = 18, time = 5 }, weaken = { mult = 1.3, time = 5 } } },
		},
	},
	{
		id = "Blade",
		rarity = "Rare",
		vfx = "blade",
		color = Color3.fromRGB(205, 215, 235),
		blurb = "Grandpa's sabre was on the mantelpiece. Now a hundred of them answer you.",
		passive = "+15% basic attack damage.",
		passiveEffect = { m1Damage = 1.15 },
		moves = {
			{ name = "Sword Wave", kind = "projectile", damage = 30, cooldown = 2.6, speed = 120, range = 80, radius = 3.4, count = 1, pierce = true, effect = {} },
			{ name = "Whirlwind", kind = "zone", damage = 8, cooldown = 8, radius = 11, duration = 2.4, tick = 0.2, range = 0, effect = {} },
			{ name = "Phantom Cut", kind = "dash", damage = 44, cooldown = 5, distance = 40, width = 7, effect = { stun = 0.5 } },
			{ name = "Thousand Swords", kind = "strike", damage = 70, cooldown = 15, radius = 10, delay = 0.6, range = 80, count = 5, spread = 16, effect = {} },
		},
	},
	-- Epic ------------------------------------------------------------------------------------
	{
		id = "Storm",
		rarity = "Epic",
		vfx = "storm",
		color = Color3.fromRGB(120, 200, 255),
		blurb = "The storm that never broke over Hollow Creek finally found somewhere to go.",
		passive = "Every 4th basic attack calls lightning down on another shadow.",
		passiveEffect = { m1Chain = 26 },
		moves = {
			{ name = "Chain Lightning", kind = "projectile", damage = 30, cooldown = 3, speed = 180, range = 110, radius = 1.6, count = 1, effect = { chain = { count = 4, damage = 0.7, range = 26 } } },
			{ name = "Thunderclap", kind = "nova", damage = 38, cooldown = 7, radius = 17, effect = { knockback = 90, stun = 0.6 } },
			{ name = "Tornado", kind = "zone", damage = 16, cooldown = 13, radius = 15, duration = 5, tick = 0.4, range = 70, effect = { pull = 45 } },
			{ name = "Tempest", kind = "zone", damage = 40, cooldown = 18, radius = 24, duration = 5, tick = 0.7, range = 80, effect = { stun = 0.4, chain = { count = 2, damage = 0.5, range = 20 } } },
		},
	},
	-- Legendary -------------------------------------------------------------------------------
	{
		id = "Hemomancy",
		rarity = "Legendary",
		vfx = "blood",
		color = Color3.fromRGB(190, 20, 40),
		blurb = "They don't bleed. You do. It turns out that's a weapon.",
		passive = "Heal 8% of damage dealt. +10% basic attack damage.",
		passiveEffect = { lifesteal = 0.08, m1Damage = 1.1 },
		moves = {
			{ name = "Blood Lance", kind = "beam", damage = 52, cooldown = 3.5, range = 90, width = 4, effect = { lifesteal = 0.25 } },
			{ name = "Crimson Burst", kind = "nova", damage = 50, cooldown = 7, radius = 18, effect = { lifesteal = 0.3, weaken = { mult = 1.2, time = 4 } } },
			{ name = "Sanguine Rush", kind = "dash", damage = 46, cooldown = 4.5, distance = 46, width = 7, effect = { lifesteal = 0.2 } },
			{ name = "Blood Moon", kind = "zone", damage = 30, cooldown = 17, radius = 22, duration = 6, tick = 0.5, range = 0, effect = { lifesteal = 0.15, weaken = { mult = 1.25, time = 1 } } },
		},
	},
	{
		id = "Phantom",
		rarity = "Legendary",
		vfx = "phantom",
		color = Color3.fromRGB(170, 140, 255),
		blurb = "Which one of you is real? Even you aren't sure anymore.",
		passive = "+10% movement speed.",
		passiveEffect = { speed = 1.1 },
		moves = {
			{ name = "Phantom Bolts", kind = "projectile", damage = 22, cooldown = 2, speed = 130, range = 100, radius = 1.6, count = 3, spread = 10, effect = {} },
			{ name = "Mirror Images", kind = "summon", ally = "Clone", count = 2, duration = 14, damage = 14, cooldown = 14 },
			{ name = "Blink", kind = "blinkchain", damage = 40, cooldown = 5, count = 1, range = 45 },
			{ name = "Phantom Legion", kind = "summon", ally = "Clone", count = 5, duration = 16, damage = 18, cooldown = 26 },
		},
	},
	-- Mythic ----------------------------------------------------------------------------------
	{
		id = "Necromancer",
		rarity = "Mythic",
		vfx = "necro",
		color = Color3.fromRGB(110, 255, 150),
		blurb = "The dead of Hollow Creek aren't resting. You can at least give them a purpose.",
		passive = "Shadows you defeat have a 25% chance to rise and fight for you.",
		passiveEffect = { raiseChance = 0.25, allDamage = 1.15 },
		moves = {
			{ name = "Bone Spear", kind = "projectile", damage = 36, cooldown = 2.2, speed = 140, range = 110, radius = 1.8, count = 1, pierce = true, effect = { weaken = { mult = 1.15, time = 3 } } },
			{ name = "Raise Dead", kind = "summon", ally = "Skeleton", count = 3, duration = 22, damage = 20, cooldown = 12 },
			{ name = "Soul Harvest", kind = "nova", damage = 52, cooldown = 7, radius = 20, effect = { pull = 45, lifesteal = 0.35 } },
			{ name = "Army of the Damned", kind = "summon", ally = "Skeleton", count = 8, duration = 18, damage = 26, cooldown = 30 },
		},
	},
	{
		id = "Phoenix",
		rarity = "Mythic",
		vfx = "phoenix",
		color = Color3.fromRGB(255, 150, 40),
		blurb = "Burn down, rise up. Again and again.",
		passive = "Once every 3 minutes, a killing blow sets you ablaze and you rise at half health. Basic attacks burn.",
		passiveEffect = { revive = 180, m1Burn = { dps = 6, time = 3 }, allDamage = 1.15 },
		moves = {
			{ name = "Phoenix Feathers", kind = "projectile", damage = 26, cooldown = 1.8, speed = 150, range = 110, radius = 2, count = 3, spread = 12, effect = { burn = { dps = 10, time = 3 } } },
			{ name = "Flame Wings", kind = "dash", damage = 50, cooldown = 4, distance = 55, width = 10, effect = { burn = { dps = 14, time = 3 } } },
			{ name = "Rebirth Flare", kind = "buff", cooldown = 20, heal = 0.5, duration = 6, damageMult = 1.25 },
			{ name = "Sunfall Dive", kind = "strike", damage = 240, cooldown = 17, radius = 26, delay = 1.1, range = 90, effect = { burn = { dps = 24, time = 5 }, knockback = 90 } },
		},
	},
	{
		id = "Void",
		rarity = "Mythic",
		vfx = "void",
		color = Color3.fromRGB(110, 50, 200),
		blurb = "Between the shadow world and ours there is nothing at all. You learned to stand in it.",
		passive = "Basic attacks weaken shadows. +15% damage.",
		passiveEffect = { m1Weaken = { mult = 1.2, time = 3 }, allDamage = 1.15 },
		moves = {
			{ name = "Void Orb", kind = "projectile", damage = 38, cooldown = 2.6, speed = 80, range = 100, radius = 3.2, count = 1, pierce = true, effect = { pull = 50 } },
			{ name = "Phase Shift", kind = "buff", cooldown = 10, duration = 2, iframes = 2, speedMult = 1.5, damageMult = 1.15 },
			{ name = "Rift Tear", kind = "zone", damage = 26, cooldown = 12, radius = 16, duration = 3, tick = 0.3, range = 80, effect = { pull = 60, stun = 0.25 } },
			{ name = "Black Hole", kind = "zone", damage = 48, cooldown = 22, radius = 28, duration = 6, tick = 0.4, range = 90, effect = { pull = 80, weaken = { mult = 1.4, time = 1 } } },
		},
	},
	-- Transcendent ----------------------------------------------------------------------------
	{
		id = "GodSpeed",
		name = "God Speed",
		rarity = "Transcendent",
		vfx = "speed",
		color = Color3.fromRGB(255, 240, 150),
		blurb = "Faster than the dark can follow. Faster than the dark can think.",
		passive = "Move 60% faster and swing 40% faster. Afterimages trail you.",
		passiveEffect = { speed = 1.6, m1Speed = 0.6, allDamage = 1.2 },
		moves = {
			{ name = "Flash Step", kind = "blinkchain", damage = 70, cooldown = 3.5, count = 5, range = 60 },
			{ name = "Thousand Cuts", kind = "zone", damage = 12, cooldown = 9, radius = 13, duration = 2.5, tick = 0.1, range = 0, effect = { stun = 0.15 } },
			{ name = "Time Blur", kind = "buff", cooldown = 18, duration = 8, speedMult = 1.5, damageMult = 1.35, iframes = 0.6 },
			{ name = "Lightspeed Barrage", kind = "blinkchain", damage = 95, cooldown = 15, count = 14, range = 90 },
		},
	},
	{
		id = "Chronos",
		rarity = "Transcendent",
		vfx = "chrono",
		color = Color3.fromRGB(205, 185, 255),
		blurb = "Noon, 12:04. You were there when time broke. You took a piece of it.",
		passive = "Basic attacks slow time around shadows. +20% damage.",
		passiveEffect = { m1Slow = { mult = 0.5, time = 2 }, allDamage = 1.2 },
		moves = {
			{ name = "Time Bolt", kind = "projectile", damage = 40, cooldown = 2, speed = 150, range = 110, radius = 2, count = 1, effect = { stun = 0.9 } },
			{ name = "Stop", kind = "zone", damage = 20, cooldown = 13, radius = 22, duration = 3.5, tick = 0.5, range = 70, effect = { stun = 0.6 } },
			{ name = "Rewind", kind = "buff", cooldown = 25, duration = 1, rewind = 4, damageMult = 1.2 },
			{ name = "Time Collapse", kind = "strike", damage = 280, cooldown = 18, radius = 26, delay = 1.2, range = 100, effect = { stun = 3 } },
		},
	},
	{
		id = "Celestial",
		rarity = "Transcendent",
		vfx = "celestial",
		color = Color3.fromRGB(160, 210, 255),
		blurb = "There are no stars in the shadow world. So you brought them.",
		passive = "+30% damage.",
		passiveEffect = { allDamage = 1.3 },
		moves = {
			{ name = "Starfall", kind = "strike", damage = 70, cooldown = 4, radius = 9, delay = 0.7, range = 90, count = 4, spread = 14, effect = { stun = 0.3 } },
			{ name = "Constellation", kind = "beam", damage = 90, cooldown = 6, range = 120, width = 7, effect = { weaken = { mult = 1.25, time = 4 } } },
			{ name = "Nova Star", kind = "nova", damage = 95, cooldown = 8, radius = 26, effect = { knockback = 120, stun = 1 } },
			{ name = "Supernova", kind = "strike", damage = 360, cooldown = 20, radius = 34, delay = 1.5, range = 110, effect = { burn = { dps = 30, time = 5 }, stun = 2 } },
		},
	},
}

Powers.ById = {}
for _, power in Powers.List do
	power.name = power.name or power.id
	Powers.ById[power.id] = power
	for index, move in power.moves do
		move.slot = index
		move.unlockLevel = index
		move.key = Powers.Keys[index]
	end
end

-- Weighted roll. `rng` is a Random object, `forceLegendary` is the pity guarantee and `luck`
-- multiplies the weight of Legendary-or-better rarities (a Star Shard sets it to 3).
function Powers.Roll(rng: Random, forceLegendary: boolean?, luck: number?)
	local legendaryRank = Powers.RarityById.Legendary.rank
	local function weight(rarity)
		if forceLegendary and rarity.rank < legendaryRank then
			return 0
		end
		return rarity.rank >= legendaryRank and rarity.weight * (luck or 1) or rarity.weight
	end
	local total = 0
	for _, rarity in Powers.Rarities do
		total += weight(rarity)
	end
	local pick = rng:NextNumber() * total
	local chosen = Powers.Rarities[#Powers.Rarities]
	for _, rarity in Powers.Rarities do
		local w = weight(rarity)
		if w > 0 then
			pick -= w
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
