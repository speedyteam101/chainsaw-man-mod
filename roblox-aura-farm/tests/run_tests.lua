--[[
	Unit tests for the pure modules in src/shared. They run outside Roblox with
	any Luau runtime whose global `require(name)` loads src/shared/<name>.lua
	(see README.md, "Tests").
]]

local Config = require("Config")
local HeroicLines = require("HeroicLines")
local AuraMath = require("AuraMath")

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
	local ctx = { inBossFight = false, healthFraction = 1, bossHealthFraction = nil, sinceDodge = math.huge, sinceHit = math.huge }
	for k, v in pairs(overrides or {}) do
		ctx[k] = v
	end
	return ctx
end

local function lineById(id: string)
	for _, line in ipairs(Config.HeroicLines) do
		if line.Id == id then
			return line
		end
	end
	error("no line " .. id)
end

-- Config sanity ------------------------------------------------------------

test("line ids are unique and lines are well formed", function()
	local seen = {}
	for _, line in ipairs(Config.HeroicLines) do
		assert(not seen[line.Id], "duplicate id " .. line.Id)
		seen[line.Id] = true
		assert(line.Aura > 0, line.Id .. " has no aura")
		assert((line.Condition == nil) == (line.Bonus == nil), line.Id .. " needs both Condition and Bonus")
		if line.Condition then
			assert(HeroicLines.conditionMet(line.Condition, calm()) ~= nil, line.Id)
		end
	end
end)

test("every line matches its own text", function()
	for _, line in ipairs(Config.HeroicLines) do
		local found = HeroicLines.match(line.Text, Config.HeroicLines, Config.LineMatchThreshold)
		assert(found == line, line.Id .. " matched " .. tostring(found and found.Id))
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
	local result = HeroicLines.evaluate("Nothing can stop me", calm({ inBossFight = true, bossHealthFraction = 0.9 }), Config, {}, 0)
	eq(result.amount, lineById("nothingStops").Aura * Config.BossFightLineMultiplier)
end)

test("condition bonus stacks with the fight multiplier", function()
	local line = lineById("endsNow")
	local ctx = calm({ inBossFight = true, bossHealthFraction = 0.1 })
	local result = HeroicLines.evaluate("This ends now!", ctx, Config, {}, 0)
	eq(result.amount, line.Aura * line.Bonus * Config.BossFightLineMultiplier)
	eq(#result.tags, 2)
end)

test("conditions", function()
	eq(HeroicLines.conditionMet("BossLow", calm()), false)
	eq(HeroicLines.conditionMet("BossLow", calm({ inBossFight = true, bossHealthFraction = 0.2 })), true)
	eq(HeroicLines.conditionMet("LowHealth", calm({ healthFraction = 0.29 })), true)
	eq(HeroicLines.conditionMet("LowHealth", calm({ healthFraction = 0.5 })), false)
	eq(HeroicLines.conditionMet("AfterDodge", calm({ sinceDodge = 3 })), true)
	eq(HeroicLines.conditionMet("AfterHit", calm({ sinceHit = 5 })), false)
	eq(HeroicLines.conditionMet("NoBoss", calm()), true)
	eq(HeroicLines.conditionMet("NoBoss", calm({ inBossFight = true })), false)
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
