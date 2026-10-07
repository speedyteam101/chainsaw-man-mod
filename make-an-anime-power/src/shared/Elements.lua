-- Elements. Every power and every ability has one. The element sets the
-- default color and adds a side effect to every hit.
--
-- Effect fields (all optional):
--   burn        = { damagePerSecond, duration }   damage over time
--   slow        = { speedMultiplier, duration }   lowers WalkSpeed
--   stun        = duration                        can't move or jump
--   knockback   = multiplier on the normal knockback
--   lifesteal   = fraction of damage dealt that heals the attacker
--   damage      = multiplier on damage dealt
--   speed       = multiplier on projectile speed

local Elements = {}

Elements.Order = {
	"Ki",
	"Fire",
	"Ice",
	"Lightning",
	"Wind",
	"Water",
	"Earth",
	"Shadow",
	"Light",
	"Poison",
	"Blood",
	"Cursed",
}

Elements.List = {
	Ki = {
		color = Color3.fromRGB(255, 220, 90),
		description = "Raw spirit energy. +10% damage.",
		effects = { damage = 1.1 },
	},
	Fire = {
		color = Color3.fromRGB(255, 110, 40),
		description = "Sets targets on fire (burn damage over time).",
		effects = { burn = { 4, 3 } },
	},
	Ice = {
		color = Color3.fromRGB(140, 220, 255),
		description = "Freezes targets, slowing them down.",
		effects = { slow = { 0.5, 2.5 } },
	},
	Lightning = {
		color = Color3.fromRGB(255, 255, 120),
		description = "Shocks targets, stunning them briefly. Fast projectiles.",
		effects = { stun = 0.5, speed = 1.3 },
	},
	Wind = {
		color = Color3.fromRGB(190, 255, 210),
		description = "Blows targets far away. Fast projectiles.",
		effects = { knockback = 2.2, speed = 1.2 },
	},
	Water = {
		color = Color3.fromRGB(60, 140, 255),
		description = "Heavy waves: extra knockback and a small slow.",
		effects = { knockback = 1.5, slow = { 0.75, 1.5 } },
	},
	Earth = {
		color = Color3.fromRGB(150, 105, 60),
		description = "Crushing rock: +20% damage, slower projectiles.",
		effects = { damage = 1.2, speed = 0.8 },
	},
	Shadow = {
		color = Color3.fromRGB(110, 60, 170),
		description = "Drains life: heals you for 20% of damage dealt.",
		effects = { lifesteal = 0.2 },
	},
	Light = {
		color = Color3.fromRGB(255, 255, 235),
		description = "Blinding speed: much faster projectiles.",
		effects = { speed = 1.6 },
	},
	Poison = {
		color = Color3.fromRGB(140, 230, 60),
		description = "Long-lasting poison damage over time.",
		effects = { burn = { 3, 6 } },
	},
	Blood = {
		color = Color3.fromRGB(190, 20, 40),
		description = "Drinks blood: heals you for 30% of damage dealt.",
		effects = { lifesteal = 0.3, damage = 0.95 },
	},
	Cursed = {
		color = Color3.fromRGB(70, 20, 90),
		description = "Cursed energy: +15% damage and a short slow.",
		effects = { damage = 1.15, slow = { 0.8, 1.5 } },
	},
}

function Elements.get(name: string)
	return Elements.List[name] or Elements.List.Ki
end

function Elements.isValid(name: any): boolean
	return type(name) == "string" and Elements.List[name] ~= nil
end

return Elements
