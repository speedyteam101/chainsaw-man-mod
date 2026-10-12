--[[
	Your animations. Paste animation asset IDs here, either as
	"rbxassetid://1234567890" or just the number. Leave a name empty ("") to
	keep Roblox's default animation (for movement) or no animation (for
	dashes and attacks).

	Lookup order for each animation: the player's class, then their side,
	then Default. So you can give every class its own slashes, give all
	villains a creepier walk, and so on, and only fill in what you want.

	Note: Roblox only plays animations that the game's owner (you, or your
	group for a group game) is allowed to use, so upload them to the same
	account or group that owns the game.

	Pure Luau (no Roblox APIs) so it can be unit tested outside Roblox.
]]

local Animations = {}

Animations.Default = {
	-- Movement. These replace the animations in the character's "Animate"
	-- script, so Roblox picks between walk and run by speed as usual.
	Idle = "",
	Walk = "",
	Run = "",
	Jump = "",
	Fall = "",

	-- Dashes, picked by which way you dash compared to where you're facing.
	-- Missing directions fall back to DashForward.
	DashForward = "",
	DashBack = "",
	DashLeft = "",
	DashRight = "",

	-- Attacks. Slash is a combo: each click plays the next one in the list,
	-- and it goes back to the first after a pause. Add as many as you like.
	Slash = { "", "", "" },
	Ultimate = "",
}

-- Per side: { Good = { Walk = "rbxassetid://..." }, Evil = { ... } }
Animations.Sides = {
	Good = {},
	Evil = {},
}

-- Per class, by class Id from Classes.lua. For example:
-- Paladin = { Slash = { "rbxassetid://111", "rbxassetid://222" }, Ultimate = "rbxassetid://333" },
Animations.Classes = {}

Animations.Settings = {
	FadeTime = 0.08, -- seconds to blend into and out of an animation
	DashHold = 0.4, -- stop a dash animation after this long (if it loops)
	ComboReset = 1.0, -- seconds without slashing before the combo restarts
}

-- The names that can be set, and whether each is a list.
Animations.Names = {
	Idle = false,
	Walk = false,
	Run = false,
	Jump = false,
	Fall = false,
	DashForward = false,
	DashBack = false,
	DashLeft = false,
	DashRight = false,
	Slash = true,
	Ultimate = false,
}

-- "123" / 123 / " rbxassetid://123 " -> "rbxassetid://123"; "" -> nil.
function Animations.normalize(id: any): string?
	if type(id) == "number" then
		return "rbxassetid://" .. tostring(math.floor(id))
	end
	if type(id) ~= "string" then
		return nil
	end
	local trimmed = string.match(id, "^%s*(.-)%s*$")
	if trimmed == "" then
		return nil
	end
	if string.match(trimmed, "^%d+$") then
		return "rbxassetid://" .. trimmed
	end
	return trimmed
end

local function resolve(value: any): any
	if type(value) == "table" then
		local list = {}
		for _, id in ipairs(value) do
			local normalized = Animations.normalize(id)
			if normalized then
				table.insert(list, normalized)
			end
		end
		return if #list > 0 then list else nil
	end
	return Animations.normalize(value)
end

--[[
	The animation for `name` (a string ID, or a list of IDs for Slash), or
	nil if none is set. classId and side may be nil.
]]
function Animations.get(name: string, classId: string?, side: string?, config: any?): any
	local source = config or Animations
	local layers = {
		classId and source.Classes[classId],
		side and source.Sides[side],
		source.Default,
	}
	for i = 1, 3 do
		local layer = layers[i]
		if layer then
			local found = resolve(layer[name])
			if found then
				return found
			end
		end
	end
	return nil
end

-- "Forward" / "Back" / "Left" / "Right" for a dash, from the dash direction
-- in the character's own space (x = right, z = back, as Roblox's
-- CFrame:VectorToObjectSpace gives it).
function Animations.dashDirection(localX: number, localZ: number): string
	if math.abs(localX) > math.abs(localZ) then
		return if localX > 0 then "Right" else "Left"
	end
	return if localZ > 0 then "Back" else "Forward"
end

return Animations
