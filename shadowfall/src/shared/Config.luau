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
		[1] = { maxStalkers = 0, speed = 0 },
		[2] = { maxStalkers = 1, speed = 10 },
		[3] = { maxStalkers = 2, speed = 12 },
		[4] = { maxStalkers = 3, speed = 14.5 },
	},
	StalkerRespawn = { 6, 11 },
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

-- Lets the in-game Dev tab work. It is also hard-gated to Studio by RunService:IsStudio().
Config.EnableStudioDevTools = true

return Config
