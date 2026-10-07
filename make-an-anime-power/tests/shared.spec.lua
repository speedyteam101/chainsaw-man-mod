-- Tests for the shared modules. Run with: python3 tests/run.py
-- (This file is appended to a bundle made by run.py, so `require` and
-- `script` here are the stand-ins defined there.)

local Config = require(script.Parent.Config)
local Elements = require(script.Parent.Elements)
local AbilityTypes = require(script.Parent.AbilityTypes)
local Templates = require(script.Parent.Templates)
local PowerValidator = require(script.Parent.PowerValidator)

local failures, passes = 0, 0

local function check(condition, message)
	if condition then
		passes += 1
	else
		failures += 1
		print("FAIL: " .. message)
	end
end

local function deepEqual(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function isNumber(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Element and ability-type lists match their tables
for _, name in Elements.Order do
	check(Elements.List[name] ~= nil, "element in Order but not List: " .. name)
end
for name in Elements.List do
	check(table.find(Elements.Order, name) ~= nil, "element in List but not Order: " .. name)
end
for _, name in AbilityTypes.Order do
	check(AbilityTypes.List[name] ~= nil, "ability type in Order but not List: " .. name)
end
for name in AbilityTypes.List do
	check(table.find(AbilityTypes.Order, name) ~= nil, "ability type in List but not Order: " .. name)
end

-- Every ability type gives sensible numbers at every level
for _, typeName in AbilityTypes.Order do
	local def = AbilityTypes.List[typeName]
	check(type(def.displayName) == "string" and type(def.description) == "string", typeName .. " has text")
	for _, key in { "damage", "size", "speed" } do
		check(type(def.weights[key]) == "number", typeName .. " has weight " .. key)
		if def.labels[key] == nil then
			check(def.weights[key] == 0, typeName .. ": unused level " .. key .. " should not cost anything")
		end
	end
	for level = 1, Config.AbilityLevelMax do
		local stats = AbilityTypes.computeStats({ type = typeName, damage = level, size = level, speed = level })
		for key, value in stats do
			check(isNumber(value) and value >= 0, typeName .. " stat " .. key .. " at level " .. level)
		end
		check(stats.cooldown > 0 and stats.energy > 0, typeName .. " has cooldown and energy cost")
		check(stats.energy <= Config.BaseEnergy, typeName .. " costs no more than the base energy pool")
	end
	-- Stronger means slower to recharge
	local weak = AbilityTypes.computeStats({ type = typeName, damage = 1, size = 1, speed = 1 })
	local strong = AbilityTypes.computeStats({ type = typeName, damage = 10, size = 10, speed = 10 })
	check(strong.cooldown > weak.cooldown, typeName .. " cooldown grows with strength")
end

-- Templates are valid and survive the server's sanitizer unchanged
local seenIds = {}
for _, template in Templates.List do
	local id = template.id
	check(not seenIds[id], "duplicate template id " .. id)
	seenIds[id] = true
	local power = Templates.makePower(id)
	check(Elements.isValid(power.element), id .. " element")
	check(PowerValidator.statPointsUsed(power.stats) <= Config.StatPointBudget, id .. " stat budget")
	check(#power.abilities >= 1 and #power.abilities <= Config.MaxAbilities, id .. " ability count")
	for _, ability in power.abilities do
		check(AbilityTypes.isValid(ability.type), id .. " ability type " .. tostring(ability.type))
		check(Elements.isValid(ability.element), id .. " ability element " .. tostring(ability.element))
		check(utf8.len(ability.name) <= Config.MaxNameLength, id .. " ability name length " .. ability.name)
	end
	local clean = PowerValidator.sanitize(power)
	check(deepEqual(clean, power), id .. " is unchanged by sanitize")

	-- makePower returns a copy, so editing it can't change the template
	power.abilities[1].damage = 99
	power.stats.strength = 99
	local again = Templates.makePower(id)
	check(again.abilities[1].damage ~= 99 and again.stats.strength ~= 99, id .. " makePower copies")
end

-- The sanitizer fixes up bad input from a modified client
check(PowerValidator.sanitize(nil) == nil, "nil power rejected")
check(PowerValidator.sanitize("hello") == nil, "string power rejected")

local nan = 0 / 0
local bad = PowerValidator.sanitize({
	name = string.rep("A", 100),
	element = "Banana",
	color = { 999, -5, nan },
	aura = "Rainbow",
	stats = { strength = 10, defense = 10, speed = 10, energy = 10 },
	abilities = {
		{ name = "", type = "Nuke", element = "Fire", damage = 1000, size = -4, speed = nan },
		"not an ability",
		{ name = "Two", type = "Beam", damage = 3, size = 3, speed = 3 },
		{ name = "Three", type = "Heal", damage = 3, size = 3, speed = 3 },
		{ name = "Four", type = "Blast", damage = 3, size = 3, speed = 3 },
		{ name = "Five", type = "Blast", damage = 3, size = 3, speed = 3 },
	},
})
check(utf8.len(bad.name) == Config.MaxNameLength, "long name trimmed")
check(bad.element == "Ki", "bad element replaced")
check(bad.color[1] == 255 and bad.color[2] == 0 and bad.color[3] == 255, "color clamped")
check(bad.aura == "None", "bad aura replaced")
check(PowerValidator.statPointsUsed(bad.stats) == Config.StatPointBudget, "stats trimmed to budget")
check(bad.stats.speed == 0 and bad.stats.energy == 0, "later stats lose points first")
check(#bad.abilities == 3, "non-table ability dropped and list capped at MaxAbilities slots")
local first = bad.abilities[1]
check(first.name == "Ability", "empty ability name replaced")
check(first.type == "Projectile", "bad ability type replaced")
check(first.damage == Config.AbilityLevelMax and first.size == 1 and first.speed == 5, "levels clamped")
check(bad.abilities[2].element == "Ki", "missing ability element uses the power's element")

local controlChars = PowerValidator.sanitize({ name = "  Hi\nthere\0  ", abilities = {} })
check(controlChars.name == "Hithere", "control characters and spaces stripped")

local unicode = PowerValidator.sanitize({ name = string.rep("é", 40), abilities = {} })
check(utf8.len(unicode.name) == Config.MaxNameLength, "multi-byte names trimmed on character boundaries")

print(string.format("%d passed, %d failed", passes, failures))
if failures > 0 then
	error("tests failed")
end
