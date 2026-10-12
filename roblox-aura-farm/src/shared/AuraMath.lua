--[[
	Rank lookups, style meter maths, boss reward maths and the 2D (top-down)
	geometry used for attack zones.

	Pure Luau (no Roblox APIs) so it can be unit tested outside Roblox.
]]

local AuraMath = {}

-- Highest entry of `ranks` whose Min <= value. Returns rank, index, next rank.
function AuraMath.getRank(value: number, ranks)
	local index = 1
	for i, rank in ipairs(ranks) do
		if value >= rank.Min then
			index = i
		end
	end
	return ranks[index], index, ranks[index + 1]
end

-- A rank's display name for a side (villains get EvilName).
function AuraMath.rankName(rank, side: string?): string
	if side == "Evil" and rank.EvilName then
		return rank.EvilName
	end
	return rank.Name
end

-- 0..1 progress from the current rank to the next (1 at the top rank).
function AuraMath.rankProgress(value: number, ranks): number
	local rank, _, nextRank = AuraMath.getRank(value, ranks)
	if not nextRank then
		return 1
	end
	return math.clamp((value - rank.Min) / (nextRank.Min - rank.Min), 0, 1)
end

-- Style after `dt` seconds, given `sinceGain` seconds since it last went up.
function AuraMath.decayStyle(style: number, sinceGain: number, dt: number, styleConfig): number
	if sinceGain < styleConfig.DecayDelay then
		return style
	end
	return math.max(0, style - styleConfig.DecayPerSecond * dt)
end

--[[
	Aura for one participant when a boss dies.

	flags = { Killer = bool, Flawless = bool, Clutch = bool, CalledIt = bool, Finisher = bool }
	Only the killer can earn Clutch / CalledIt / Finisher. Everyone can earn
	Flawless. Non-killers start from base * assistFraction.

	Returns total (integer) and a breakdown list of label strings.
]]
function AuraMath.defeatReward(base: number, styleRank, flags, bonuses, assistFraction: number)
	local breakdown = {}
	local start = base
	if flags.Killer then
		table.insert(breakdown, string.format("Boss defeated: %d", base))
	else
		start = base * assistFraction
		table.insert(breakdown, string.format("Assist: %d", math.floor(start + 0.5)))
	end

	local bonusTotal = 0
	local order = { "Flawless", "Clutch", "CalledIt", "Finisher" }
	for _, key in ipairs(order) do
		local killerOnly = key ~= "Flawless"
		if flags[key] and (flags.Killer or not killerOnly) then
			bonusTotal += bonuses[key].Bonus
			table.insert(breakdown, string.format("%s  +%d%%", bonuses[key].Label, math.floor(bonuses[key].Bonus * 100 + 0.5)))
		end
	end

	if styleRank.Multiplier ~= 1 then
		table.insert(breakdown, string.format("STYLE %s  x%s", styleRank.Name, tostring(styleRank.Multiplier)))
	end

	local total = math.floor(start * styleRank.Multiplier * (1 + bonusTotal) + 0.5)
	return total, breakdown
end

--[[
	Aura for defeating an enemy player.

	killerRank / victimRank: aura rank indexes (1 = lowest).
	flags = { Clutch = bool, CalledIt = bool, Finisher = bool, Revenge = bool }
	repeats: how many times the killer already defeated this victim within
	         the repeat window (0 for the first time).

	reward = KillAura * style * (1 + bonuses) * RepeatFalloff^repeats
	Returns total (integer) and a breakdown list of label strings.
]]
function AuraMath.pvpKillReward(pvp, pvpBonuses, defeatBonuses, killerRank: number, victimRank: number, styleRank, flags, repeats: number)
	local breakdown = { string.format("Enemy defeated: %d", pvp.KillAura) }
	local bonusTotal = 0

	local ranksAbove = victimRank - killerRank
	if ranksAbove > 0 then
		local bonus = math.min(ranksAbove * pvp.GiantSlayerPerRank, pvp.GiantSlayerMax)
		bonusTotal += bonus
		table.insert(breakdown, string.format("%s  +%d%%", pvpBonuses.GiantSlayer, math.floor(bonus * 100 + 0.5)))
	end
	if flags.Revenge then
		bonusTotal += pvp.RevengeBonus
		table.insert(breakdown, string.format("%s  +%d%%", pvpBonuses.Revenge, math.floor(pvp.RevengeBonus * 100 + 0.5)))
	end
	for _, key in ipairs({ "Clutch", "CalledIt", "Finisher" }) do
		if flags[key] then
			bonusTotal += defeatBonuses[key].Bonus
			table.insert(breakdown, string.format("%s  +%d%%", defeatBonuses[key].Label, math.floor(defeatBonuses[key].Bonus * 100 + 0.5)))
		end
	end
	if styleRank.Multiplier ~= 1 then
		table.insert(breakdown, string.format("STYLE %s  x%s", styleRank.Name, tostring(styleRank.Multiplier)))
	end

	local falloff = pvp.RepeatFalloff ^ repeats
	if repeats > 0 then
		table.insert(breakdown, string.format("Same target again  x%s", tostring(falloff)))
	end

	local total = math.floor(pvp.KillAura * styleRank.Multiplier * (1 + bonusTotal) * falloff + 0.5)
	return total, breakdown
end

---------------------------------------------------------------------------
-- Top-down geometry (x/z plane)
---------------------------------------------------------------------------

function AuraMath.inCircle(px: number, pz: number, cx: number, cz: number, radius: number): boolean
	local dx, dz = px - cx, pz - cz
	return dx * dx + dz * dz <= radius * radius
end

-- Rectangle starting at (ox, oz), running `length` along the unit direction
-- (dirX, dirZ), `width` wide (centred on that line).
function AuraMath.inRect(
	px: number,
	pz: number,
	ox: number,
	oz: number,
	dirX: number,
	dirZ: number,
	length: number,
	width: number
): boolean
	local rx, rz = px - ox, pz - oz
	local along = rx * dirX + rz * dirZ
	local across = math.abs(rx * -dirZ + rz * dirX)
	return along >= 0 and along <= length and across <= width / 2
end

-- One "walking away without looking back" sample: facing away from the
-- explosion and actually getting further from it. movedAway is how much the
-- distance to the explosion grew since the last sample, in studs.
function AuraMath.isWalkingAway(lookX: number, lookZ: number, toBossX: number, toBossZ: number, movedAway: number): boolean
	local length = math.sqrt(toBossX * toBossX + toBossZ * toBossZ)
	if length < 1e-3 or movedAway < 0.5 then
		return false
	end
	local dot = (lookX * toBossX + lookZ * toBossZ) / length
	return dot < -0.3
end

return AuraMath
