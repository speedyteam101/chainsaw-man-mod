--!nonstrict
-- The latest snapshot of the local player's progress (feats, progress counters),
-- plus a signal that fires whenever it changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Signal)

local ClientState = {
	achievements = {},
	progress = {},
	totalRolls = 0,
	kills = 0,
	Changed = Signal.new(),
	MenuOpen = false,
	InCutscene = false,
}

function ClientState.Apply(snapshot)
	for key, value in snapshot do
		ClientState[key] = value
	end
	ClientState.Changed:Fire()
end

return ClientState
