--[[
	Unit tests for the pure modules in src/shared. They run outside Roblox with
	any Luau runtime whose global `require(name)` loads src/shared/<name>.lua
	(see README.md, "Tests").
]]

local Config = require("Config")
local HeroicLines = require("HeroicLines")
local AuraMath = require("AuraMath")
local Classes = require("Classes")
local Animations = require("Animations")

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function eq(actual, expected, what: string?)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
	end
end

local function calm(overrides)
	local ctx = {
		inFight = false,
		healthFraction = 1,
		foeHealthFraction = nil,
		sinceDodge = math.huge,
		sinceHit = math.huge,
		sinceKill = math.huge,
	}
	for k, v in pairs(overrides or {}) do
		ctx[k] = v
	end
	return ctx
end

local function lineById(id: string)
	for _, list in ipairs({ Config.HeroicLines, Config.VillainLines }) do
		for _, line in ipairs(list) do
			if line.Id == id then
				return line
			end
		end
	end
	error("no line " .. id)
end

-- Config sanity ------------------------------------------------------------

test("line ids are unique and lines are well formed", function()
	local seen = {}
	for _, list in ipairs({ Config.HeroicLines, Config.VillainLines }) do
		for _, line in ipairs(list) do
			assert(not seen[line.Id], "duplicate id " .. line.Id)
			seen[line.Id] = true
			assert(line.Aura > 0, line.Id .. " has no aura")
			assert((line.Condition == nil) == (line.Bonus == nil), line.Id .. " needs both Condition and Bonus")
			if line.Condition then
				assert(HeroicLines.ConditionLabels[line.Condition], line.Id .. " has unknown condition " .. line.Condition)
			end
		end
	end
end)

test("every line matches its own text, on its own side only", function()
	for _, side in ipairs({ "Good", "Evil" }) do
		local lines = HeroicLines.forSide(Config, side)
		local other = HeroicLines.forSide(Config, if side == "Good" then "Evil" else "Good")
		for _, line in ipairs(lines) do
			local found = HeroicLines.match(line.Text, lines, Config.LineMatchThreshold)
			assert(found == line, line.Id .. " matched " .. tostring(found and found.Id))
			local crossed = HeroicLines.match(line.Text, other, Config.LineMatchThreshold)
			assert(crossed == nil, line.Id .. " also matches the other side's " .. tostring(crossed and crossed.Id))
		end
	end
end)

test("ranks are sorted", function()
	for i = 2, #Config.Ranks do
		assert(Config.Ranks[i].Min > Config.Ranks[i - 1].Min, Config.Ranks[i].Name)
	end
	for i = 2, #Config.Style.Ranks do
		assert(Config.Style.Ranks[i].Min > Config.Style.Ranks[i - 1].Min, Config.Style.Ranks[i].Name)
	end
end)

test("boss attacks exist", function()
	for _, boss in ipairs(Config.Bosses) do
		for _, attack in ipairs(boss.Attacks) do
			assert(Config.Attacks[attack], boss.Id .. " uses unknown attack " .. attack)
		end
	end
end)

-- Normalising and matching ---------------------------------------------------

test("normalize strips punctuation, case and apostrophes", function()
	eq(HeroicLines.normalize("  Is THAT all you've got?!  "), "is that all youve got")
	eq(HeroicLines.normalize("It\226\128\153s my turn now"), "its my turn now")
end)

test("match tolerates a missing word and messy punctuation", function()
	local line = HeroicLines.match("you picked the wrong hero to fight!!!", Config.HeroicLines, Config.LineMatchThreshold)
	eq(line and line.Id, "wrongHero")
	line = HeroicLines.match("i wont lose not here", Config.HeroicLines, Config.LineMatchThreshold)
	eq(line and line.Id, "notHere")
end)

test("match rejects unrelated text and walls of text", function()
	eq(HeroicLines.match("anyone want to trade pets", Config.HeroicLines, Config.LineMatchThreshold), nil)
	local wall = {}
	for _, line in ipairs(Config.HeroicLines) do
		table.insert(wall, line.Text)
	end
	eq(HeroicLines.match(table.concat(wall, " "), Config.HeroicLines, Config.LineMatchThreshold), nil)
end)

test("empty message never matches", function()
	eq(HeroicLines.match("?!", Config.HeroicLines, Config.LineMatchThreshold), nil)
end)

-- Evaluating ---------------------------------------------------------------

test("plain line outside a fight gives base aura", function()
	local result = HeroicLines.evaluate("Remember my name.", calm(), Config, {}, 100)
	eq(result.kind, "Line")
	eq(result.amount, lineById("rememberName").Aura)
	eq(result.historyKey, "line:rememberName")
end)

test("boss fight multiplier applies", function()
	local result = HeroicLines.evaluate("Nothing can stop me", calm({ inFight = true, foeHealthFraction = 0.9 }), Config, {}, 0)
	eq(result.amount, lineById("nothingStops").Aura * Config.FightLineMultiplier)
end)

test("condition bonus stacks with the fight multiplier", function()
	local line = lineById("endsNow")
	local ctx = calm({ inFight = true, foeHealthFraction = 0.1 })
	local result = HeroicLines.evaluate("This ends now!", ctx, Config, {}, 0)
	eq(result.amount, line.Aura * line.Bonus * Config.FightLineMultiplier)
	eq(#result.tags, 2)
end)

test("conditions", function()
	eq(HeroicLines.conditionMet("FoeLow", calm()), false)
	eq(HeroicLines.conditionMet("FoeLow", calm({ inFight = true, foeHealthFraction = 0.2 })), true)
	eq(HeroicLines.conditionMet("AfterKill", calm({ sinceKill = 4 })), true)
	eq(HeroicLines.conditionMet("AfterKill", calm({ sinceKill = 6 })), false)
	eq(HeroicLines.conditionMet("LowHealth", calm({ healthFraction = 0.29 })), true)
	eq(HeroicLines.conditionMet("LowHealth", calm({ healthFraction = 0.5 })), false)
	eq(HeroicLines.conditionMet("AfterDodge", calm({ sinceDodge = 3 })), true)
	eq(HeroicLines.conditionMet("AfterHit", calm({ sinceHit = 5 })), false)
	eq(HeroicLines.conditionMet("NoFight", calm()), true)
	eq(HeroicLines.conditionMet("NoFight", calm({ inFight = true })), false)
end)

test("repeating a line inside the window is cringe", function()
	local history = { ["line:myTurn"] = 10 }
	local result = HeroicLines.evaluate("It's my turn now", calm(), Config, history, 10 + Config.LineRepeatWindow - 1)
	eq(result.kind, "Repeat")
	eq(result.amount, -Config.LineRepeatPenalty)
	result = HeroicLines.evaluate("It's my turn now", calm(), Config, history, 10 + Config.LineRepeatWindow + 1)
	eq(result.kind, "Line")
end)

test("freestyle needs enough heroic keywords and is capped", function()
	eq(HeroicLines.evaluate("I will protect everyone", calm(), Config, {}, 0).kind, "Freestyle")
	eq(HeroicLines.evaluate("protect", calm(), Config, {}, 0).kind, "None")
	local loud = "protect never hero friends believe destiny promise power fight"
	local aura = HeroicLines.freestyle(loud, Config.Freestyle)
	eq(aura, Config.Freestyle.MaxAura)
end)

test("villains use villain lines and words", function()
	local result = HeroicLines.evaluate("Who's next?", calm({ sinceKill = 1 }), Config, {}, 0, "Evil")
	eq(result.kind, "Line")
	eq(result.amount, lineById("whosNext").Aura * lineById("whosNext").Bonus)
	-- A heroic line from a villain isn't a line (but its words may be freestyle).
	result = HeroicLines.evaluate("Remember my name.", calm(), Config, {}, 0, "Evil")
	assert(result.kind ~= "Line", "villain matched a heroic line")
	eq(HeroicLines.evaluate("Kneel and despair, you are worthless", calm(), Config, {}, 0, "Evil").kind, "Freestyle")
	-- Undecided players use the heroic lines.
	eq(HeroicLines.evaluate("Remember my name.", calm(), Config, {}, 0, nil).kind, "Line")
end)

-- Classes ------------------------------------------------------------------

test("each side has more than 20 classes", function()
	assert(#Classes.Good > 20, "only " .. #Classes.Good .. " good classes")
	assert(#Classes.Evil > 20, "only " .. #Classes.Evil .. " evil classes")
end)

test("classes are well formed", function()
	local names = {}
	for _, side in ipairs({ "Good", "Evil" }) do
		for _, class in ipairs(Classes[side]) do
			local id = class.Id
			assert(Classes.get(id) == class, "duplicate or missing id " .. id)
			assert(class.Side == side, id .. " side")
			assert(not names[class.Name], "duplicate name " .. class.Name)
			names[class.Name] = true
			assert(type(class.Description) == "string" and #class.Description > 0, id .. " description")
			assert(type(class.Role) == "string", id .. " role")
			assert(#class.Color == 3, id .. " color")
			assert(class.MaxHealth >= 60 and class.MaxHealth <= 200, id .. " health")
			assert(class.WalkSpeed >= 10 and class.WalkSpeed <= 24, id .. " speed")
			assert(class.SlashDamage >= 10 and class.SlashDamage <= 30, id .. " damage")
			assert(class.SlashRange >= 6 and class.SlashRange <= 16, id .. " range")
			assert(class.SlashCooldown >= 0.2 and class.SlashCooldown <= 0.6, id .. " slash cooldown")
			assert(class.DashCooldown >= 0.6 and class.DashCooldown <= 1.5, id .. " dash cooldown")
			assert(class.Armor >= 0 and class.Armor <= 0.5, id .. " armor")
			assert(class.Lifesteal >= 0 and class.Lifesteal <= 0.3, id .. " lifesteal")
			assert(class.StyleGain >= 1 and class.StyleGain <= 1.5, id .. " style gain")
			local ult = class.Ultimate
			assert(Classes.UltimateKinds[ult.Kind], id .. " has unknown ultimate " .. tostring(ult.Kind))
			assert(type(ult.Name) == "string" and ult.Power > 0 and ult.Power <= 2, id .. " ultimate")
		end
	end
	eq(Classes.get("nope"), nil)
	eq(Classes.get(42), nil)
end)

-- Animations ---------------------------------------------------------------

test("animation config only uses known names and real classes", function()
	local function check(layer, where)
		for name, value in pairs(layer) do
			local isList = Animations.Names[name]
			assert(isList ~= nil, where .. " has unknown animation " .. tostring(name))
			assert(type(value) == (if isList then "table" else "string"), where .. "." .. name .. " has the wrong type")
		end
	end
	check(Animations.Default, "Default")
	for side, layer in pairs(Animations.Sides) do
		assert(side == "Good" or side == "Evil", "unknown side " .. tostring(side))
		check(layer, side)
	end
	for classId, layer in pairs(Animations.Classes) do
		assert(Classes.get(classId), "unknown class " .. tostring(classId))
		check(layer, classId)
	end
end)

test("animation ids normalize", function()
	eq(Animations.normalize(""), nil)
	eq(Animations.normalize("   "), nil)
	eq(Animations.normalize("123"), "rbxassetid://123")
	eq(Animations.normalize(" rbxassetid://456 "), "rbxassetid://456")
	eq(Animations.normalize(789), "rbxassetid://789")
	eq(Animations.normalize(nil), nil)
end)

test("animation lookup goes class, then side, then default", function()
	local config = {
		Default = { Walk = "1", Slash = { "", "" }, Ultimate = "" },
		Sides = { Good = {}, Evil = { Walk = "2" } },
		Classes = { DemonLord = { Walk = "3", Slash = { "4", "", "5" } } },
	}
	eq(Animations.get("Walk", nil, nil, config), "rbxassetid://1")
	eq(Animations.get("Walk", nil, "Evil", config), "rbxassetid://2")
	eq(Animations.get("Walk", "DemonLord", "Evil", config), "rbxassetid://3")
	eq(Animations.get("Walk", "Paladin", "Good", config), "rbxassetid://1")
	eq(Animations.get("Ultimate", "DemonLord", "Evil", config), nil)
	-- Empty slots are skipped; an all-empty list counts as unset.
	eq(Animations.get("Slash", nil, nil, config), nil)
	local slashes = Animations.get("Slash", "DemonLord", "Evil", config)
	eq(#slashes, 2)
	eq(slashes[2], "rbxassetid://5")
end)

test("dash directions", function()
	eq(Animations.dashDirection(0, -1), "Forward")
	eq(Animations.dashDirection(0, 1), "Back")
	eq(Animations.dashDirection(1, 0.2), "Right")
	eq(Animations.dashDirection(-1, -0.5), "Left")
end)

-- AuraMath -----------------------------------------------------------------

test("getRank and progress", function()
	eq(AuraMath.getRank(0, Config.Ranks).Name, "NPC")
	eq(AuraMath.getRank(99, Config.Ranks).Name, "NPC")
	eq(AuraMath.getRank(100, Config.Ranks).Name, "Background Character")
	local top, _, nextRank = AuraMath.getRank(10 ^ 9, Config.Ranks)
	eq(top.Name, "Aura God")
	eq(nextRank, nil)
	eq(AuraMath.rankProgress(10 ^ 9, Config.Ranks), 1)
	eq(AuraMath.rankProgress(300, Config.Ranks), 0.5)
end)

test("style decay waits for the delay", function()
	eq(AuraMath.decayStyle(50, Config.Style.DecayDelay - 0.1, 1, Config.Style), 50)
	eq(AuraMath.decayStyle(50, Config.Style.DecayDelay, 1, Config.Style), 50 - Config.Style.DecayPerSecond)
	eq(AuraMath.decayStyle(1, 100, 1, Config.Style), 0)
end)

test("defeat reward for the killer stacks bonuses and style", function()
	local s = AuraMath.getRank(80, Config.Style.Ranks)
	eq(s.Name, "S")
	local total, breakdown = AuraMath.defeatReward(
		100,
		s,
		{ Killer = true, Flawless = true, Clutch = false, CalledIt = true, Finisher = true },
		Config.DefeatBonuses,
		Config.AssistFraction
	)
	eq(total, math.floor(100 * 2 * (1 + 1 + 0.5 + 0.5) + 0.5))
	eq(#breakdown, 5) -- base, flawless, called it, finisher, style
end)

test("assists only get Flawless", function()
	local d = AuraMath.getRank(0, Config.Style.Ranks)
	local total = AuraMath.defeatReward(
		100,
		d,
		{ Killer = false, Flawless = true, Clutch = true, CalledIt = true, Finisher = true },
		Config.DefeatBonuses,
		Config.AssistFraction
	)
	eq(total, math.floor(100 * Config.AssistFraction * 2 + 0.5))
end)

test("rank names per side", function()
	eq(AuraMath.rankName(Config.Ranks[1], "Good"), "NPC")
	eq(AuraMath.rankName(Config.Ranks[1], "Evil"), "Minion")
	eq(AuraMath.rankName(Config.Ranks[1], nil), "NPC")
end)

test("pvp kill reward", function()
	local d = AuraMath.getRank(0, Config.Style.Ranks)
	local function reward(killerRank, victimRank, flags, repeats)
		return AuraMath.pvpKillReward(Config.Pvp, Config.PvpBonuses, Config.DefeatBonuses, killerRank, victimRank, d, flags, repeats)
	end
	local base = Config.Pvp.KillAura
	eq(reward(1, 1, {}, 0), base)
	-- Two ranks above you: giant slayer.
	eq(reward(1, 3, {}, 0), math.floor(base * (1 + 2 * Config.Pvp.GiantSlayerPerRank) + 0.5))
	-- Capped.
	eq(reward(1, 8, {}, 0), math.floor(base * (1 + Config.Pvp.GiantSlayerMax) + 0.5))
	-- Lower-ranked victims give no penalty or bonus.
	eq(reward(5, 1, {}, 0), base)
	-- Revenge + finisher.
	eq(reward(1, 1, { Revenge = true, Finisher = true }, 0), math.floor(base * (1 + Config.Pvp.RevengeBonus + Config.DefeatBonuses.Finisher.Bonus) + 0.5))
	-- Farming the same victim falls off.
	eq(reward(1, 1, {}, 2), math.floor(base * Config.Pvp.RepeatFalloff ^ 2 + 0.5))
	local _, breakdown = reward(1, 3, { Clutch = true }, 1)
	eq(#breakdown, 4) -- base, giant slayer, clutch, repeat
end)

test("circle and rectangle zones", function()
	eq(AuraMath.inCircle(3, 4, 0, 0, 5), true)
	eq(AuraMath.inCircle(3, 4.1, 0, 0, 5), false)
	-- Rectangle from origin pointing +x, 10 long, 4 wide.
	eq(AuraMath.inRect(5, 1.9, 0, 0, 1, 0, 10, 4), true)
	eq(AuraMath.inRect(5, 2.1, 0, 0, 1, 0, 10, 4), false)
	eq(AuraMath.inRect(-0.1, 0, 0, 0, 1, 0, 10, 4), false)
	eq(AuraMath.inRect(10.1, 0, 0, 0, 1, 0, 10, 4), false)
	-- Pointing +z.
	eq(AuraMath.inRect(0, 9, 0, 0, 0, 1, 10, 4), true)
end)

test("walking away", function()
	-- Boss is +x of us; we look -x and move.
	eq(AuraMath.isWalkingAway(-1, 0, 10, 0, 2), true)
	eq(AuraMath.isWalkingAway(1, 0, 10, 0, 2), false) -- looking at it
	eq(AuraMath.isWalkingAway(-1, 0, 10, 0, 0), false) -- standing still
	eq(AuraMath.isWalkingAway(-1, 0, 10, 0, -2), false) -- backing into it
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
