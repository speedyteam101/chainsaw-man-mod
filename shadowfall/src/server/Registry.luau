--!nonstrict
-- Shared server state: live enemies, per-player combat state, and the signals services use
-- to talk to each other without requiring one another in circles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Signal)

local Registry = {}

Registry.Enemies = {} -- [Model] = enemy object (see EnemyService)
Registry.PlayerState = {} -- [Player] = combat state (see Combat.GetState)
Registry.World = nil -- info table returned by WorldBuilder.Build

Registry.EnemyKilled = Signal.new() -- (enemy, killer: Player?, damagers: {[Player]: number})
Registry.PlayerDamaged = Signal.new() -- (player, amount, source)
Registry.Parried = Signal.new() -- (player, enemy)
Registry.PerfectDodge = Signal.new() -- (player)
Registry.PlayerDied = Signal.new() -- (player)
Registry.PowerRolled = Signal.new() -- (player, powerId)
Registry.Ascended = Signal.new() -- (player, level)

return Registry
