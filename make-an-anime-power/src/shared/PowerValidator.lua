-- Cleans up a power table so it always follows the rules. The server runs every
-- power a client sends through `sanitize` before using or saving it, so a
-- modified client can't create an over-powered ability. The client uses the
-- same code to show what the server will accept.

local Config = require(script.Parent.Config)
local Elements = require(script.Parent.Elements)
local AbilityTypes = require(script.Parent.AbilityTypes)

local PowerValidator = {}

PowerValidator.Auras = { "None", "Flames", "Sparkles", "Smoke", "Glow" }

local STAT_NAMES = { "strength", "defense", "speed", "energy" }
PowerValidator.StatNames = STAT_NAMES

local function clampInt(value: any, min: number, max: number, default: number): number
	if type(value) ~= "number" or value ~= value then -- reject non-numbers and NaN
		return default
	end
	return math.clamp(math.floor(value + 0.5), min, max)
end

-- Cuts a name down to Config.MaxNameLength characters (not bytes, so
-- multi-byte characters are never split). Returns nil for invalid UTF-8.
function PowerValidator.truncate(text: string): string?
	local length = utf8.len(text)
	if length == nil then
		return nil
	end
	if length > Config.MaxNameLength then
		local cut = utf8.offset(text, Config.MaxNameLength + 1) :: number
		return text:sub(1, cut - 1)
	end
	return text
end

local function cleanText(value: any, default: string): string
	if type(value) ~= "string" then
		return default
	end
	-- Drop control characters and trim spaces
	local text = PowerValidator.truncate((value:gsub("%c", ""):gsub("^%s+", ""):gsub("%s+$", "")))
	if text == nil or text == "" then
		return default
	end
	return text
end

local function isAura(value: any): boolean
	return table.find(PowerValidator.Auras, value) ~= nil
end

function PowerValidator.sanitizeAbility(raw: any, fallbackElement: string)
	if type(raw) ~= "table" then
		return nil
	end
	local level = Config.AbilityLevelMax
	return {
		name = cleanText(raw.name, "Ability"),
		type = AbilityTypes.isValid(raw.type) and raw.type or "Projectile",
		element = Elements.isValid(raw.element) and raw.element or fallbackElement,
		damage = clampInt(raw.damage, 1, level, 5),
		size = clampInt(raw.size, 1, level, 5),
		speed = clampInt(raw.speed, 1, level, 5),
	}
end

function PowerValidator.sanitize(raw: any)
	if type(raw) ~= "table" then
		return nil
	end

	local element = Elements.isValid(raw.element) and raw.element or "Ki"

	local color = { 255, 255, 255 }
	if type(raw.color) == "table" then
		for i = 1, 3 do
			color[i] = clampInt(raw.color[i], 0, 255, 255)
		end
	end

	-- Stats: each 0..StatMax, and the total can't go over the budget.
	-- If it does, points are removed from the last stats first.
	local stats = {}
	local rawStats = type(raw.stats) == "table" and raw.stats or {}
	local remaining = Config.StatPointBudget
	for _, statName in STAT_NAMES do
		local value = math.min(clampInt(rawStats[statName], 0, Config.StatMax, 0), remaining)
		stats[statName] = value
		remaining -= value
	end

	local abilities = {}
	if type(raw.abilities) == "table" then
		for i = 1, Config.MaxAbilities do
			local ability = PowerValidator.sanitizeAbility(raw.abilities[i], element)
			if ability then
				table.insert(abilities, ability)
			end
		end
	end

	return {
		name = cleanText(raw.name, "My Power"),
		template = type(raw.template) == "string" and raw.template:sub(1, 32) or "Blank",
		element = element,
		color = color,
		aura = isAura(raw.aura) and raw.aura or "None",
		stats = stats,
		abilities = abilities,
	}
end

function PowerValidator.statPointsUsed(stats): number
	local total = 0
	for _, statName in STAT_NAMES do
		total += stats[statName] or 0
	end
	return total
end

function PowerValidator.colorOf(power): Color3
	return Color3.fromRGB(power.color[1], power.color[2], power.color[3])
end

return PowerValidator
