--!nonstrict
-- Global tuning values. Change numbers here rather than inside the systems.

local Config = {}

-- Sound asset ids. These are deliberately empty: pick sounds you have the rights to use
-- from the Creator Store and paste their ids here as "rbxassetid://123456".
-- Every system checks for an empty string and simply stays silent if one is missing.
Config.Sounds = {
	Ambience = "", -- low drone, looped during Act 1
	Heartbeat = "", -- single heartbeat thump (pitched up as shadows get close)
	Whisper = "", -- whisper/breath, played when a stalker appears
	Scream = "", -- jumpscare sting when a stalker catches you
	Bell = "", -- clock tower bell
	Radio = "", -- radio static loop for the broadcast
	Hit = "", -- punch impact
	Power = "", -- power move cast
	RollTick = "", -- reel tick during the power roll
	RollReveal = "", -- reveal sting at the end of a roll
	Ascend = "", -- level-up sting
	Achievement = "", -- achievement unlocked
	CombatMusic = "", -- looped while a boss is nearby
	ShadowBreath = "", -- slow ragged breathing, looped on nearby shadows
	Quack = "", -- Biscuit the call duck
	Gather = "", -- chop / mine / salvage hit
	Build = "", -- blueprint completed
	Craft = "", -- item crafted
	Hallucination = "", -- whisper sting at low sanity
}

Config.DataStoreName = "Shadowfall_PlayerData_v1"
Config.AutosaveSeconds = 120
Config.RespawnSeconds = 4

Config.Act1 = {
	WalkSpeed = 12,
	SprintSpeed = 20,
	StaminaMax = 100,
	StaminaDrain = 22, -- per second while sprinting
	StaminaRegen = 14,
	BatteryMax = 100,
	BatteryDrain = 5, -- per second while the flashlight is on
	BatteryRegen = 3.5, -- per second while it is off
	FlashlightRange = 46,
	FlashlightConeDot = 0.93, -- cos(~21 degrees)
	FlashlightBurnTime = 1.1, -- seconds of light to banish a stalker
	CatchDamage = 34,
	CatchDistance = 3.6,
	-- Stalker speed and count per story stage.
	Stages = {
		[0] = { maxStalkers = 0, speed = 0 }, -- intro: save Biscuit
		[1] = { maxStalkers = 0, speed = 0 },
		[2] = { maxStalkers = 1, speed = 10 },
		[3] = { maxStalkers = 2, speed = 12 },
		[4] = { maxStalkers = 3, speed = 14.5 },
	},
	StalkerRespawn = { 6, 11 },
	IntruderBurnTime = 1.6, -- seconds of light to banish the shadow cornering Biscuit
	FinaleStalkers = 9,
}

Config.Act2 = {
	WalkSpeed = 18,
	SprintSpeed = 28,
	BaseMaxHealth = 100,
	HealthPerLevel = 30,
	RegenDelay = 6, -- seconds without taking damage before regen starts
	RegenPerSecond = 0.03, -- fraction of max health
	CampRadius = 48, -- safe zone around the bonfire
}

Config.Combat = {
	M1Damage = { 8, 8, 10, 15 },
	M1Cooldown = 0.3,
	M1ComboFinisherCooldown = 0.75,
	M1ComboReset = 1.1,
	M1Range = 7.5,
	BlockReduction = 0.75,
	ParryWindow = 0.25,
	ParryStun = 1.6,
	DodgeCooldown = 1.4,
	DodgeIFrames = 0.38,
	DodgeSpeed = 70,
	PerfectDodgeBuff = 1.25, -- damage multiplier for a short time after a perfect dodge
	PerfectDodgeBuffTime = 2.5,
	AwakeningDuration = 18,
	AwakeningCooldown = 90,
	AwakeningDamage = 1.5,
	AwakeningCooldownMult = 0.5,
}

-- Player damage multiplier by level (index = level).
Config.LevelDamage = { 1.0, 1.5, 2.2, 3.1, 4.3 }
Config.MaxLevel = 5

Config.Roll = {
	RerollCost = 150, -- Essence
	PityAt = 50, -- the 50th roll since your last Legendary-or-better is guaranteed Legendary-or-better
}

Config.Sanity = {
	Max = 100,
	RespawnValue = 70,
	Act1Drain = 0.45, -- per second in the dark
	Act1FlashlightDrain = 0.15, -- per second while your light is on
	NearShadowDrain = 2.2, -- per second with a shadow within NearShadowRange
	NearShadowRange = 22,
	AreaDrain = { town = 0, woods = 0.15, rift = 0.4, cathedral = 0.6, heart = 1.0 },
	CaughtLoss = 20, -- a stalker touches you
	DuckRange = 20,
	DuckRegen = 4, -- per second near Biscuit
	DuckHealthRegen = 2, -- HP per second near Biscuit
	CampRegen = 3,
	OwnBaseRegen = 2,
	LampRegen = 0.5, -- per lit lamp in your base (up to MaxLampBonus)
	MaxLampBonus = 2,
	AnyBarrierRegen = 1,
	DamageBelow = 15, -- below this, the dark starts hurting you
	DamagePerSecond = 0.02, -- fraction of max health
	PetBonus = 15,
	PetCooldown = 20,
}

Config.Base = {
	MinDistanceFromCamp = 75,
	MinDistanceBetweenCrystals = 50,
	Grid = 1,
	-- Barrier radius and upgrade cost for each crystal level (cost is to reach that level).
	Levels = {
		{ radius = 24 },
		{ radius = 34, cost = { Wood = 30, Stone = 30, Scrap = 10 } },
		{ radius = 46, cost = { Planks = 30, IronBar = 12, Crystal = 6 } },
		{ radius = 58, cost = { IronBar = 35, LightCore = 3, Umbral = 20 } },
		{ radius = 72, cost = { IronBar = 60, LightCore = 8, Umbral = 50 } },
	},
	DismantleRefund = 0.5,
	BuilderBonusPerNpc = 0.1, -- each rescued builder makes deposited materials count 10% more
	MaxBuilderBonus = 0.3,
	TurretDamage = 30,
	TurretRange = 40,
	TurretInterval = 1.5,
}

-- Visual effects. The textures below are Roblox's built-in particle textures (I believe these
-- paths exist in every Roblox client, but haven't been able to confirm it outside Studio). For
-- more realistic results, swap in flipbook textures from the Creator Store ("rbxassetid://...").
Config.Vfx = {
	Textures = {
		Spark = "rbxasset://textures/particles/sparkles_main.dds",
		Smoke = "rbxasset://textures/particles/smoke_main.dds",
		Fire = "rbxasset://textures/particles/fire_main.dds",
	},
	Quality = 1, -- 0.5 = half the particles and debris (for slow devices), 1 = full
	MaxDebris = 60, -- physical rock/ice chunks alive at once
	MarkLifetime = 9, -- seconds scorch marks, cracks and splatters stay on the ground
}

-- Act 2 horror.
Config.Horror = {
	-- 0 = Act 2 looks like before, 1 = very dark outside the camp and your base. Raise or lower this
	-- to taste; the camp and your base always stay at the normal Act 2 lighting.
	Darkness = 0.6,
	FlashlightRange = 60,
	Watchers = { Interval = { 25, 50 }, Chance = 0.45, MinDistance = 45, MaxDistance = 85 },
	Blackout = {
		Enabled = true,
		FirstDelay = 360, -- seconds after the server starts
		Interval = { 480, 720 }, -- between blackouts
		Warning = 12, -- seconds of warning (lights stutter, the bell tolls)
		Duration = 75,
		StalkerSpeed = 15,
		CatchDistance = 4,
		CatchDamage = 0.35, -- fraction of max health
		SanityLoss = 25,
		BurnTime = 1.6, -- seconds of flashlight to banish the Hollow
		Respawn = 10, -- seconds before another Hollow comes for you
		Reward = 60, -- Essence for getting through without being caught
	},
}

-- Combat flair: elemental reactions and the Flow meter.
Config.Combos = {
	ReactionCooldown = 0.8, -- per enemy
	Shatter = 0.6, -- bonus damage (fraction of the hit) for burning a frozen/slowed foe or freezing a burning one
	Overload = { damage = 0.45, radius = 9 }, -- shocking a burning foe makes it explode
	Crush = 0.5, -- bonus damage for knocking back a stunned foe
	FlowPerStack = 0.06, -- +6% damage per Flow stack
	FlowMax = 5,
	FlowWindow = 4, -- seconds to use a different move to keep Flow going
	UltimateDamage = 110, -- Awakening burst (scaled by your damage multiplier)
	UltimateRadius = 26,
}

-- Help for new players.
Config.Beginner = {
	DamageTaken = 0.7, -- Beginner's Blessing: take 30% less damage...
	UntilLevel = 2, -- ...until you first Ascend to this level
	ShowGuide = true, -- the "what now?" hint card in the top-left (players can hide it with H)
}

-- Lets the in-game Dev tab work. It is also hard-gated to Studio by RunService:IsStudio().
Config.EnableStudioDevTools = true

return Config
