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
Registry.M1Swing = Signal.new() -- (player, center: Vector3, radius: number) used for gathering
Registry.SanityChange = Signal.new() -- (player, delta: number)
Registry.Rescued = Signal.new() -- (player, townsfolkId)

-- Base barriers currently in the world: [Player] = { center: Vector3, radius: number }
Registry.Barriers = {}

-- True if `position` is inside any player's base barrier.
function Registry.InBarrier(position: Vector3): (boolean, Player?)
	for owner, barrier in Registry.Barriers do
		local offset = position - barrier.center
		if Vector2.new(offset.X, offset.Z).Magnitude <= barrier.radius then
			return true, owner
		end
	end
	return false, nil
end

return Registry
