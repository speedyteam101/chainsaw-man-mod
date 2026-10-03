--!nonstrict
-- Feats. There is no XP in Shadowfall: you level up (Ascend) only after earning a feat that
-- qualifies you for the next level. `qualifies` is the level the feat lets you ascend to.
-- Feats without `qualifies` are honours that only show in your feat list.

local Achievements = {}

Achievements.List = {
	-- Act 1
	{ id = "awakened", name = "Awakened", desc = "Survive the night in Hollow Creek and discover your power." },
	{ id = "unseen", name = "Unseen", desc = "Reach the clock tower without a shadow ever touching you." },
	{ id = "duck_parent", name = "Duck Parent", desc = "Save Biscuit from the shadow in your living room." },

	-- Ascend to level 2
	{ id = "boss_warden", name = "First Light", desc = "Defeat the Hollow Warden in the churchyard.", qualifies = 2 },
	{ id = "untouchable", name = "Untouchable", desc = "Defeat 10 shadows in a row without taking damage.", qualifies = 2, goal = 10 },
	{ id = "steady_hand", name = "Steady Hand", desc = "Parry 5 shadow attacks (block right as they land).", qualifies = 2, goal = 5 },

	-- Ascend to level 3
	{ id = "boss_stag", name = "Antlers in the Dark", desc = "Defeat the Antlered Shade in the Whispering Woods.", qualifies = 3 },
	{ id = "chain_reaction", name = "Chain Reaction", desc = "Defeat 4 shadows within 3 seconds.", qualifies = 3 },
	{ id = "shadowstep", name = "Shadowstep", desc = "Perfectly dodge 15 attacks (dodge through them).", qualifies = 3, goal = 15 },
	{ id = "good_neighbour", name = "Good Neighbour", desc = "Free 3 townsfolk from shadow cocoons.", qualifies = 3, goal = 3 },

	-- Ascend to level 4
	{ id = "boss_eyes", name = "Blind Them", desc = "Defeat the Many-Eyed on the Rift's central island.", qualifies = 4 },
	{ id = "giant_slayer", name = "Giant Slayer", desc = "Defeat 3 Brutes without any of their attacks hitting you.", qualifies = 4, goal = 3 },
	{ id = "unbroken", name = "Unbroken", desc = "Defeat 40 shadows without dying.", qualifies = 4, goal = 40 },
	{ id = "fortress", name = "Fortress", desc = "Upgrade your base crystal to level 3.", qualifies = 4 },

	-- Ascend to level 5
	{ id = "boss_choir", name = "Silence the Choir", desc = "Defeat the Choir Below in the Sunken Cathedral.", qualifies = 5 },
	{ id = "flawless", name = "Flawless", desc = "Defeat any boss without it hitting you once.", qualifies = 5 },
	{ id = "last_light", name = "Last Light", desc = "Defeat 100 shadows without dying.", qualifies = 5, goal = 100 },

	-- Honours
	{ id = "lucky", name = "Golden Hour", desc = "Roll a Legendary power." },
	{ id = "mythic", name = "Impossible Dawn", desc = "Roll a Mythic power." },
	{ id = "ascendant", name = "Ascendant", desc = "Reach level 5." },
	{ id = "boss_king", name = "Dawn", desc = "Defeat the Umbral King in the Heart of Shadow." },
	{ id = "hundred", name = "Exterminator", desc = "Defeat 500 shadows in total.", goal = 500 },
	{ id = "homestead", name = "Homestead", desc = "Place your base crystal." },
	{ id = "full_house", name = "Full House", desc = "Free every trapped townsperson.", goal = 8 },
	{ id = "master_builder", name = "Master Builder", desc = "Finish 25 buildings.", goal = 25 },
	{ id = "crafter", name = "Handy", desc = "Craft 15 items.", goal = 15 },
}

Achievements.ById = {}
for index, achievement in Achievements.List do
	achievement.order = index
	Achievements.ById[achievement.id] = achievement
end

-- Feats that qualify for a given level.
function Achievements.QualifiersFor(level: number)
	local result = {}
	for _, achievement in Achievements.List do
		if achievement.qualifies == level then
			table.insert(result, achievement)
		end
	end
	return result
end

-- True if `owned` (a set of feat ids) contains a feat that qualifies for `level`.
function Achievements.IsQualified(owned, level: number): boolean
	for _, achievement in Achievements.QualifiersFor(level) do
		if owned[achievement.id] then
			return true
		end
	end
	return false
end

return Achievements
