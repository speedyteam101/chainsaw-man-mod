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
	inventory = {},
	items = {},
	rescued = {},
	baseLevel = 1,
	basePlaced = false,
	duckSaved = false,
	MenuOpen = false,
	InCutscene = false,
	BuildMode = false,
	DialogueOpen = false,
	CreatorOpen = false, -- the character creator (its own flag, so dialogues can't re-lock the mouse under it)
	story = { chapter = 1, seen = {}, pages = {} },
}

function ClientState.Apply(snapshot)
	for key, value in snapshot do
		ClientState[key] = value
	end
	ClientState.Changed:Fire()
end

return ClientState
