-- Game-wide tuning numbers. Shared by the server (which enforces them) and the
-- client (which uses them to show limits in the Power Creator).

local Config = {}

-- Power creation limits
Config.MaxSavedPowers = 6
Config.MaxAbilities = 4
Config.MaxNameLength = 24
Config.StatPointBudget = 20 -- points to spread across the four stats
Config.StatMax = 10 -- max points in a single stat
Config.AbilityLevelMax = 10 -- max level for an ability's Damage / Size / Speed

-- Keys bound to ability slots 1..MaxAbilities (the client also shows these)
Config.AbilityKeys = { "Q", "E", "R", "F" }

-- Base character numbers before stats are applied
Config.BaseHealth = 100
Config.HealthPerDefense = 15 -- +15 max HP per Defense point
Config.BaseWalkSpeed = 16
Config.WalkSpeedPerSpeed = 1.2 -- +1.2 studs/s per Speed point
Config.DamagePerStrength = 0.06 -- +6% damage per Strength point
Config.BaseEnergy = 100
Config.EnergyPerPoint = 10 -- +10 max energy per Energy point
Config.BaseEnergyRegen = 8 -- energy per second
Config.EnergyRegenPerPoint = 1.2

-- Basic attack (left click / Attack button), always available
Config.BasicAttackDamage = 8
Config.BasicAttackRange = 7
Config.BasicAttackCooldown = 0.45

-- Fighting
Config.SafeZoneCenter = Vector3.new(0, 0, 0) -- around the spawn, players can't be hurt here
Config.SafeZoneRadius = 34
Config.MaxAimDistance = 300 -- clamp for client-sent aim points
Config.RespawnTime = 4
Config.EnemyCount = 5 -- roaming enemies in the arena
Config.DummyCount = 5 -- training dummies
Config.EnemyRespawnTime = 8

-- Saving
Config.DataStoreName = "MakeAnAnimePower_v1"

return Config
