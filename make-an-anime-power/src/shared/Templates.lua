-- Anime templates. Picking one in the Power Creator fills in a complete power
-- that the player can then change however they like (or use as-is).
-- Names are generic anime archetypes, not characters from real shows.

local Templates = {}

local function ability(name, abilityType, element, damage, size, speed)
	return { name = name, type = abilityType, element = element, damage = damage, size = size, speed = speed }
end

Templates.List = {
	{
		id = "KiWarrior",
		name = "Ki Warrior",
		description = "Scream, power up, fire giant energy waves.",
		power = {
			element = "Ki",
			color = { 255, 215, 70 },
			aura = "Flames",
			stats = { strength = 7, defense = 4, speed = 4, energy = 5 },
			abilities = {
				ability("Ki Blast", "Barrage", "Ki", 4, 6, 6),
				ability("Wave Cannon", "Beam", "Ki", 8, 6, 6),
				ability("Instant Step", "Teleport", "Ki", 3, 3, 6),
				ability("Super Form", "PowerUp", "Ki", 8, 1, 6),
			},
		},
	},
	{
		id = "Ninja",
		name = "Shadow Ninja",
		description = "Fast, sneaky, throws stars and vanishes.",
		power = {
			element = "Wind",
			color = { 80, 200, 140 },
			aura = "Smoke",
			stats = { strength = 5, defense = 3, speed = 8, energy = 4 },
			abilities = {
				ability("Star Throw", "Barrage", "Wind", 4, 4, 8),
				ability("Wind Palm", "Blast", "Wind", 5, 5, 8),
				ability("Body Flicker", "Teleport", "Shadow", 2, 2, 7),
				ability("Spiral Sphere", "Projectile", "Wind", 8, 6, 4),
			},
		},
	},
	{
		id = "FlameFist",
		name = "Flame Fist",
		description = "A body made of fire. Punches that burn.",
		power = {
			element = "Fire",
			color = { 255, 100, 30 },
			aura = "Flames",
			stats = { strength = 8, defense = 5, speed = 4, energy = 3 },
			abilities = {
				ability("Fire Fist", "Projectile", "Fire", 7, 7, 5),
				ability("Fire Pillar", "Blast", "Fire", 7, 6, 4),
				ability("Flame Comet", "MeteorRain", "Fire", 5, 5, 5),
				ability("Blazing Rush", "DashStrike", "Fire", 6, 4, 6),
			},
		},
	},
	{
		id = "IceMage",
		name = "Ice Maker",
		description = "Freeze enemies in place and wall yourself in ice.",
		power = {
			element = "Ice",
			color = { 140, 220, 255 },
			aura = "Sparkles",
			stats = { strength = 5, defense = 7, speed = 3, energy = 5 },
			abilities = {
				ability("Ice Lance", "Projectile", "Ice", 6, 4, 7),
				ability("Frozen Field", "Explosion", "Ice", 6, 7, 5),
				ability("Ice Wall", "Shield", "Ice", 7, 1, 5),
				ability("Blizzard", "MeteorRain", "Ice", 4, 7, 6),
			},
		},
	},
	{
		id = "ThunderBreath",
		name = "Thunder Breathing",
		description = "One perfect, lightning-fast sword dash.",
		power = {
			element = "Lightning",
			color = { 255, 240, 90 },
			aura = "Sparkles",
			stats = { strength = 7, defense = 3, speed = 8, energy = 2 },
			abilities = {
				ability("Thunderclap Flash", "DashStrike", "Lightning", 8, 4, 9),
				ability("Sword Combo", "Melee", "Lightning", 6, 5, 6),
				ability("Lightning Rain", "MeteorRain", "Lightning", 4, 4, 7),
				ability("Focused Breath", "PowerUp", "Lightning", 6, 1, 7),
			},
		},
	},
	{
		id = "CursedSorcerer",
		name = "Cursed Sorcerer",
		description = "Cursed energy techniques and a deadly domain.",
		power = {
			element = "Cursed",
			color = { 120, 50, 200 },
			aura = "Smoke",
			stats = { strength = 7, defense = 5, speed = 4, energy = 4 },
			abilities = {
				ability("Black Flash", "Melee", "Cursed", 8, 3, 3),
				ability("Hollow Purple", "Beam", "Cursed", 9, 7, 6),
				ability("Domain Expansion", "Blast", "Cursed", 7, 9, 5),
				ability("Reverse Technique", "Heal", "Cursed", 7, 1, 1),
			},
		},
	},
	{
		id = "ChainsawDevil",
		name = "Chainsaw Devil",
		description = "Rev up and shred. Heals by drinking blood.",
		power = {
			element = "Blood",
			color = { 220, 30, 40 },
			aura = "Flames",
			stats = { strength = 8, defense = 6, speed = 4, energy = 2 },
			abilities = {
				ability("Chainsaw Slash", "Melee", "Blood", 7, 6, 9),
				ability("Rev Dash", "DashStrike", "Blood", 7, 5, 6),
				ability("Chain Shot", "Projectile", "Blood", 5, 3, 7),
				ability("Blood Drink", "Heal", "Blood", 6, 1, 1),
			},
		},
	},
	{
		id = "SpiritGunner",
		name = "Spirit Gunner",
		description = "Charge your spirit into one huge finger-gun shot.",
		power = {
			element = "Light",
			color = { 120, 200, 255 },
			aura = "Glow",
			stats = { strength = 8, defense = 4, speed = 5, energy = 3 },
			abilities = {
				ability("Spirit Gun", "Projectile", "Light", 9, 6, 6),
				ability("Spirit Shotgun", "Barrage", "Light", 4, 10, 5),
				ability("Spirit Sword", "Melee", "Light", 6, 7, 3),
				ability("Spirit Barrier", "Shield", "Light", 5, 1, 5),
			},
		},
	},
	{
		id = "Psychic",
		name = "Psychic",
		description = "Telekinesis. Throw people around with your mind.",
		power = {
			element = "Wind",
			color = { 230, 120, 255 },
			aura = "Glow",
			stats = { strength = 5, defense = 4, speed = 5, energy = 6 },
			abilities = {
				ability("Mind Push", "Blast", "Wind", 5, 8, 10),
				ability("Psychic Crush", "Explosion", "Wind", 7, 4, 6),
				ability("Psi Shield", "Shield", "Light", 6, 1, 6),
				ability("Blink", "Teleport", "Light", 1, 1, 8),
			},
		},
	},
	{
		id = "WaterHashira",
		name = "Water Swordsman",
		description = "Flowing water sword forms.",
		power = {
			element = "Water",
			color = { 60, 140, 255 },
			aura = "Sparkles",
			stats = { strength = 6, defense = 5, speed = 6, energy = 3 },
			abilities = {
				ability("Water Surface Slash", "Melee", "Water", 6, 6, 6),
				ability("Whirlpool", "Blast", "Water", 5, 6, 7),
				ability("Flowing Dance", "DashStrike", "Water", 6, 6, 7),
				ability("Water Wheel", "Projectile", "Water", 6, 6, 5),
			},
		},
	},
	{
		id = "EarthTitan",
		name = "Earth Titan",
		description = "Slow, huge and almost impossible to knock down.",
		power = {
			element = "Earth",
			color = { 160, 110, 60 },
			aura = "Smoke",
			stats = { strength = 7, defense = 10, speed = 1, energy = 2 },
			abilities = {
				ability("Ground Slam", "Blast", "Earth", 7, 7, 6),
				ability("Boulder Toss", "Projectile", "Earth", 8, 9, 3),
				ability("Stone Skin", "Shield", "Earth", 9, 1, 6),
				ability("Titan Punch", "Melee", "Earth", 9, 4, 1),
			},
		},
	},
	{
		id = "PoisonAssassin",
		name = "Poison Assassin",
		description = "Wear enemies down with poison that keeps hurting.",
		power = {
			element = "Poison",
			color = { 140, 230, 60 },
			aura = "Smoke",
			stats = { strength = 5, defense = 3, speed = 7, energy = 5 },
			abilities = {
				ability("Venom Needles", "Barrage", "Poison", 4, 8, 7),
				ability("Toxic Cloud", "Explosion", "Poison", 4, 8, 5),
				ability("Shadow Step", "DashStrike", "Shadow", 5, 3, 7),
				ability("Fang Strike", "Melee", "Poison", 6, 3, 6),
			},
		},
	},
	{
		id = "Blank",
		name = "Blank Power",
		description = "Start from nothing and invent your own power.",
		power = {
			element = "Ki",
			color = { 255, 255, 255 },
			aura = "None",
			stats = { strength = 5, defense = 5, speed = 5, energy = 5 },
			abilities = {
				ability("My First Ability", "Projectile", "Ki", 5, 5, 5),
			},
		},
	},
}

function Templates.get(id: string)
	for _, template in Templates.List do
		if template.id == id then
			return template
		end
	end
	return nil
end

-- A fresh copy of a template's power, named after the template.
function Templates.makePower(id: string)
	local template = Templates.get(id) or Templates.List[1]
	local p = template.power
	local abilities = {}
	for i, a in p.abilities do
		abilities[i] = table.clone(a)
	end
	return {
		name = template.name,
		template = template.id,
		element = p.element,
		color = table.clone(p.color),
		aura = p.aura,
		stats = table.clone(p.stats),
		abilities = abilities,
	}
end

return Templates
