--[[
	Decides how much aura a chat message is worth.

	Pure Luau (no Roblox APIs) so it can be unit tested outside Roblox; all
	tuning comes in through the `config` argument (see Config.lua).
]]

local HeroicLines = {}

-- Lowercase, drop apostrophes ("you've" -> "youve"), turn everything that
-- isn't a letter or digit into a space, collapse runs of spaces.
function HeroicLines.normalize(text: string): string
	local s = string.lower(text)
	s = string.gsub(s, "\226\128\153", "") -- curly apostrophe (UTF-8 E2 80 99)
	s = string.gsub(s, "'", "")
	s = string.gsub(s, "[^%w]+", " ")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return s
end

function HeroicLines.words(text: string): { string }
	local out = {}
	for word in string.gmatch(HeroicLines.normalize(text), "%S+") do
		table.insert(out, word)
	end
	return out
end

local function wordSet(words: { string }): { [string]: boolean }
	local set = {}
	for _, w in ipairs(words) do
		set[w] = true
	end
	return set
end

-- Fraction of the line's unique words that appear in the message (0..1).
function HeroicLines.similarity(messageWords: { string }, lineText: string): number
	local lineWords = HeroicLines.words(lineText)
	local unique = wordSet(lineWords)
	local messageSet = wordSet(messageWords)
	local total, found = 0, 0
	for w in pairs(unique) do
		total += 1
		if messageSet[w] then
			found += 1
		end
	end
	if total == 0 then
		return 0
	end
	return found / total
end

-- Best matching heroic line, or nil. A message far longer than the line
-- (e.g. every line pasted at once) never matches.
function HeroicLines.match(message: string, lines, threshold: number)
	local messageWords = HeroicLines.words(message)
	if #messageWords == 0 then
		return nil, 0
	end
	local best, bestScore, bestLength = nil, 0, 0
	for _, line in ipairs(lines) do
		local lineLength = #HeroicLines.words(line.Text)
		if #messageWords <= lineLength * 2 + 3 then
			local score = HeroicLines.similarity(messageWords, line.Text)
			if score >= threshold and (score > bestScore or (score == bestScore and lineLength > bestLength)) then
				best, bestScore, bestLength = line, score, lineLength
			end
		end
	end
	return best, bestScore
end

-- Aura for an unscripted message made of heroic words, and how many
-- different keywords it used.
function HeroicLines.freestyle(message: string, freestyleConfig): (number, number)
	local messageSet = wordSet(HeroicLines.words(message))
	local count = 0
	for _, keyword in ipairs(freestyleConfig.Keywords) do
		if messageSet[keyword] then
			count += 1
		end
	end
	if count < freestyleConfig.MinKeywords then
		return 0, count
	end
	return math.min(count * freestyleConfig.AuraPerKeyword, freestyleConfig.MaxAura), count
end

--[[
	context = {
		inFight: boolean,           -- boss fight, or an enemy player nearby
		healthFraction: number,     -- the speaker's health, 0..1
		foeHealthFraction: number?, -- lowest health fraction of the boss /
		                            -- nearby enemy players; nil if none
		sinceDodge: number,         -- seconds since the last perfect dodge
		sinceHit: number,           -- seconds since the speaker was last hit
		sinceKill: number,          -- seconds since the speaker defeated an enemy player
	}
]]
function HeroicLines.conditionMet(condition: string?, context): boolean
	if condition == nil then
		return false
	elseif condition == "FoeLow" then
		return context.foeHealthFraction ~= nil and context.foeHealthFraction < 0.25
	elseif condition == "LowHealth" then
		return context.healthFraction < 0.3
	elseif condition == "AfterDodge" then
		return context.sinceDodge <= 4
	elseif condition == "AfterHit" then
		return context.sinceHit <= 4
	elseif condition == "AfterKill" then
		return context.sinceKill <= 5
	elseif condition == "NoFight" then
		return not context.inFight
	end
	return false
end

HeroicLines.ConditionLabels = {
	FoeLow = "FOE ON ITS LAST LEGS",
	LowHealth = "LOW HP",
	AfterDodge = "AFTER A PERFECT DODGE",
	AfterHit = "SHRUGGED IT OFF",
	AfterKill = "RIGHT AFTER A TAKEDOWN",
	NoFight = "PRE-FIGHT",
}

-- The line list and freestyle words for a side ("Good", "Evil" or nil).
-- Undecided players use the heroic lines.
function HeroicLines.forSide(config, side: string?)
	if side == "Evil" then
		return config.VillainLines, config.VillainFreestyle
	end
	return config.HeroicLines, config.Freestyle
end

--[[
	Scores a message. Doesn't change any state: the caller records
	history[result.historyKey] = now when result.historyKey is set.

	history: { [string]: number } -- key -> last time it was said
	side: "Good" | "Evil" | nil   -- picks heroic or villain lines
	Returns {
		kind = "Line" | "Freestyle" | "Repeat" | "None",
		line = <line table>?, amount = number, tags = { string },
		historyKey = string?,
	}
]]
function HeroicLines.evaluate(message: string, context, config, history, now: number, side: string?)
	local lines, freestyleConfig = HeroicLines.forSide(config, side)
	local line = HeroicLines.match(message, lines, config.LineMatchThreshold)
	local tags = {}
	local amount
	local historyKey

	if line then
		historyKey = "line:" .. line.Id
		amount = line.Aura
		if line.Condition and HeroicLines.conditionMet(line.Condition, context) then
			amount *= line.Bonus
			table.insert(tags, string.format("%s x%s", HeroicLines.ConditionLabels[line.Condition], tostring(line.Bonus)))
		end
	else
		local freestyleAura = HeroicLines.freestyle(message, freestyleConfig)
		if freestyleAura <= 0 then
			return { kind = "None", amount = 0, tags = tags }
		end
		historyKey = "free:" .. HeroicLines.normalize(message)
		amount = freestyleAura
		table.insert(tags, "FREESTYLE")
	end

	local last = history[historyKey]
	if last and now - last < config.LineRepeatWindow then
		return {
			kind = "Repeat",
			line = line,
			amount = -config.LineRepeatPenalty,
			tags = { "CRINGE: YOU ALREADY SAID THAT" },
			historyKey = historyKey,
		}
	end

	if context.inFight then
		amount *= config.FightLineMultiplier
		table.insert(tags, string.format("IN A FIGHT x%s", tostring(config.FightLineMultiplier)))
	end

	return {
		kind = if line then "Line" else "Freestyle",
		line = line,
		amount = math.floor(amount + 0.5),
		tags = tags,
		historyKey = historyKey,
	}
end

return HeroicLines
