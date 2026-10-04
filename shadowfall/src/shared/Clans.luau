--!nonstrict
-- Clans: your family line, rolled in the character creator (3 free rolls, then rerolls at the
-- shrine for Essence). Every clan gives perks; most give extra damage to the powers that match
-- their element (e.g. Pyro, a Common clan, gives fire powers 1.5x damage). Mythic and
-- Transcendent clans also have a Mode: a transformation (Y) with at least 2x damage and 1.2x speed.
--
-- Perk fields (all optional, 1 / 0 = no effect):
--   styles      power styles (Powers.luau `vfx`) that get `affinity`x damage; "*" = every power
--   affinity    damage multiplier for those powers' moves
--   damage      all damage multiplier          flat      + damage on every hit (punches and moves)
--   hp          max health multiplier           defense   damage taken multiplier (0.8 = -20%)
--   speed       move speed multiplier           cooldown  power cooldown multiplier
--   luck        power-roll luck (Legendary+ odds multiplier)
--   lifesteal   fraction of damage dealt healed  sanity   sanity drain multiplier
--   gather      gathering multiplier            essence   Essence from kills multiplier
--   mode        { name, damage, speed, defense?, duration, cooldown, color, desc }

local Powers = require(script.Parent.Powers)

local Clans = {}

Clans.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Transcendent" }

Clans.List = {
	-- Common ------------------------------------------------------------------------------------
	{ id = "pyro", name = "Pyro", rarity = "Common", color = Color3.fromRGB(255, 120, 50), styles = { "fire", "phoenix" }, affinity = 1.5, lore = "Hearth-keepers. Fire answers when they call." },
	{ id = "frostborne", name = "Frostborne", rarity = "Common", color = Color3.fromRGB(160, 220, 255), styles = { "ice" }, affinity = 1.5, lore = "Born in the hard winters up north." },
	{ id = "galewind", name = "Galewind", rarity = "Common", color = Color3.fromRGB(200, 255, 230), styles = { "wind" }, affinity = 1.5, lore = "Shepherds of the hill winds." },
	{ id = "stonehand", name = "Stonehand", rarity = "Common", color = Color3.fromRGB(150, 130, 110), styles = { "stone" }, affinity = 1.5, defense = 0.95, lore = "Quarry folk. Hard to knock down." },
	{ id = "sparkwright", name = "Sparkwright", rarity = "Common", color = Color3.fromRGB(255, 240, 120), styles = { "volt", "storm" }, affinity = 1.5, lore = "Linemen and tinkerers who never feared a live wire." },
	{ id = "lumen", name = "Lumen", rarity = "Common", color = Color3.fromRGB(255, 250, 210), styles = { "light", "dawn" }, affinity = 1.5, lore = "Lamplighters of Hollow Creek." },
	{ id = "thornvale", name = "Thornvale", rarity = "Common", color = Color3.fromRGB(120, 200, 80), styles = { "venom" }, affinity = 1.5, lore = "Herbalists. Some of their herbs are not for tea." },
	{ id = "edgewalker", name = "Edgewalker", rarity = "Common", color = Color3.fromRGB(220, 220, 230), styles = { "blade" }, affinity = 1.5, lore = "A line of fencers and knife-throwers." },
	{ id = "haemo", name = "Haemo", rarity = "Common", color = Color3.fromRGB(180, 30, 50), styles = { "blood" }, affinity = 1.5, lore = "Old doctors' family. They know what blood can do." },
	{ id = "gravedigger", name = "Gravedigger", rarity = "Common", color = Color3.fromRGB(90, 160, 110), styles = { "necro" }, affinity = 1.5, lore = "Keepers of the churchyard for six generations." },
	{ id = "tinker", name = "Tinker", rarity = "Common", color = Color3.fromRGB(190, 160, 110), gather = 1.3, lore = "Scavengers. Nothing goes to waste." },
	{ id = "oakheart", name = "Oakheart", rarity = "Common", color = Color3.fromRGB(140, 100, 60), hp = 1.25, lore = "Big, stubborn, and very hard to kill." },
	{ id = "scrapper", name = "Scrapper", rarity = "Common", color = Color3.fromRGB(200, 120, 90), flat = 3, lore = "Bar-room brawlers." },
	{ id = "fortune", name = "Fortune", rarity = "Common", color = Color3.fromRGB(255, 220, 120), luck = 1.3, lore = "Born lucky, mostly." },

	-- Uncommon ----------------------------------------------------------------------------------
	{ id = "emberkin", name = "Emberkin", rarity = "Uncommon", color = Color3.fromRGB(255, 100, 40), styles = { "fire", "phoenix" }, affinity = 1.6, flat = 2, lore = "Smiths who work the forge bare-handed." },
	{ id = "glacierborn", name = "Glacierborn", rarity = "Uncommon", color = Color3.fromRGB(140, 210, 255), styles = { "ice" }, affinity = 1.6, defense = 0.9, lore = "Cold-blooded, in every sense." },
	{ id = "tempest", name = "Tempest", rarity = "Uncommon", color = Color3.fromRGB(150, 200, 255), styles = { "storm", "volt", "wind" }, affinity = 1.6, lore = "Storm-chasers. They go towards the lightning." },
	{ id = "quarryman", name = "Quarryman", rarity = "Uncommon", color = Color3.fromRGB(160, 140, 120), styles = { "stone" }, affinity = 1.6, hp = 1.15, lore = "They broke the mountain to build the town." },
	{ id = "dawnward", name = "Dawnward", rarity = "Uncommon", color = Color3.fromRGB(255, 210, 140), styles = { "dawn", "light", "celestial" }, affinity = 1.6, lore = "They always wake before the sun." },
	{ id = "nightshade", name = "Nightshade", rarity = "Uncommon", color = Color3.fromRGB(120, 60, 160), styles = { "venom", "eclipse" }, affinity = 1.6, lore = "Poisoners. Polite ones." },
	{ id = "duelist", name = "Duelist", rarity = "Uncommon", color = Color3.fromRGB(230, 230, 255), styles = { "blade", "phantom" }, affinity = 1.6, cooldown = 0.95, lore = "Never refuse a challenge." },
	{ id = "swiftfoot", name = "Swiftfoot", rarity = "Uncommon", color = Color3.fromRGB(150, 255, 200), speed = 1.15, lore = "Couriers and runners." },
	{ id = "ironhide", name = "Ironhide", rarity = "Uncommon", color = Color3.fromRGB(150, 150, 160), hp = 1.5, lore = "Skin like boot leather, nerves like iron." },
	{ id = "brawler", name = "Brawler", rarity = "Uncommon", color = Color3.fromRGB(220, 90, 70), flat = 5, lore = "+5 damage on every hit. They hit hard." },
	{ id = "starseeker", name = "Starseeker", rarity = "Uncommon", color = Color3.fromRGB(200, 200, 255), luck = 1.6, lore = "Astronomers who read the luck in the sky." },
	{ id = "lanternkeeper", name = "Lanternkeeper", rarity = "Uncommon", color = Color3.fromRGB(255, 230, 160), sanity = 0.6, lore = "The dark doesn't frighten them much." },

	-- Rare --------------------------------------------------------------------------------------
	{ id = "infernal", name = "Infernal", rarity = "Rare", color = Color3.fromRGB(255, 80, 30), styles = { "fire", "phoenix" }, affinity = 1.75, damage = 1.05, lore = "Their tempers burn hotter than their fires." },
	{ id = "permafrost", name = "Permafrost", rarity = "Rare", color = Color3.fromRGB(180, 230, 255), styles = { "ice" }, affinity = 1.75, defense = 0.85, lore = "Nothing thaws them." },
	{ id = "thunderclan", name = "Thunderclan", rarity = "Rare", color = Color3.fromRGB(255, 255, 140), styles = { "volt", "storm", "speed" }, affinity = 1.75, speed = 1.05, lore = "Loud, fast and bright." },
	{ id = "bedrock", name = "Bedrock", rarity = "Rare", color = Color3.fromRGB(130, 110, 90), styles = { "stone", "gravity" }, affinity = 1.75, hp = 1.25, lore = "The foundation everything else stands on." },
	{ id = "radiant", name = "Radiant", rarity = "Rare", color = Color3.fromRGB(255, 255, 220), styles = { "light", "dawn", "celestial" }, affinity = 1.75, sanity = 0.8, lore = "They glow faintly in the dark." },
	{ id = "umbral", name = "Umbral", rarity = "Rare", color = Color3.fromRGB(90, 50, 140), styles = { "void", "eclipse", "gravity" }, affinity = 1.75, lore = "They were always a little too comfortable in the dark." },
	{ id = "bladesworn", name = "Bladesworn", rarity = "Rare", color = Color3.fromRGB(210, 220, 240), styles = { "blade", "phantom" }, affinity = 1.75, flat = 3, lore = "Sworn to the sword for twelve generations." },
	{ id = "sanguine", name = "Sanguine", rarity = "Rare", color = Color3.fromRGB(160, 20, 40), styles = { "blood" }, affinity = 1.75, lifesteal = 0.05, lore = "Every wound they give, they drink a little from." },
	{ id = "titanborn", name = "Titanborn", rarity = "Rare", color = Color3.fromRGB(180, 140, 100), hp = 2, lore = "2x HP. Descended from giants, they say." },
	{ id = "gambler", name = "Gambler", rarity = "Rare", color = Color3.fromRGB(255, 200, 80), luck = 2, lore = "2x luck on power spins. The house always loses." },

	-- Epic --------------------------------------------------------------------------------------
	{ id = "phoenixblood", name = "Phoenix Blood", rarity = "Epic", color = Color3.fromRGB(255, 150, 40), styles = { "phoenix", "fire" }, affinity = 2, hp = 1.2, lore = "Burned and reborn, again and again." },
	{ id = "stormcaller", name = "Stormcaller", rarity = "Epic", color = Color3.fromRGB(160, 200, 255), styles = { "storm", "volt" }, affinity = 2, cooldown = 0.9, lore = "Clouds gather when they're angry." },
	{ id = "voidtouched", name = "Voidtouched", rarity = "Epic", color = Color3.fromRGB(70, 30, 120), styles = { "void", "gravity", "eclipse" }, affinity = 2, damage = 1.1, lore = "Something looked back at them once." },
	{ id = "lichborn", name = "Lichborn", rarity = "Epic", color = Color3.fromRGB(110, 200, 140), styles = { "necro" }, affinity = 2, lifesteal = 0.08, lore = "Death is more of a suggestion in their family." },
	{ id = "chronist", name = "Chronist", rarity = "Epic", color = Color3.fromRGB(230, 230, 255), styles = { "chrono" }, affinity = 2, cooldown = 0.85, lore = "Clockmakers. Time owes them favours." },
	{ id = "berserker", name = "Berserker", rarity = "Epic", color = Color3.fromRGB(220, 40, 40), damage = 1.25, flat = 6, defense = 1.1, lore = "All attack, no defence." },
	{ id = "sentinel", name = "Sentinel", rarity = "Epic", color = Color3.fromRGB(170, 190, 220), hp = 1.75, defense = 0.8, lore = "They stand between the town and the dark." },

	-- Legendary ---------------------------------------------------------------------------------
	{ id = "solaris", name = "Solaris", rarity = "Legendary", color = Color3.fromRGB(255, 230, 120), styles = { "light", "dawn", "celestial", "fire" }, affinity = 2.25, damage = 1.1, hp = 1.2, lore = "Children of a sun that went out." },
	{ id = "rimekings", name = "Rime Kings", rarity = "Legendary", color = Color3.fromRGB(190, 240, 255), styles = { "ice", "wind" }, affinity = 2.25, defense = 0.8, speed = 1.05, lore = "They ruled the frozen north, once." },
	{ id = "kensei", name = "Kensei", rarity = "Legendary", color = Color3.fromRGB(240, 240, 255), styles = { "blade", "phantom", "speed" }, affinity = 2.25, flat = 8, lore = "Sword saints. One cut is enough." },
	{ id = "abyssal", name = "Abyssal", rarity = "Legendary", color = Color3.fromRGB(40, 20, 80), styles = { "void", "eclipse", "gravity" }, affinity = 2.25, lifesteal = 0.06, lore = "They came up from somewhere very deep." },
	{ id = "fateweavers", name = "Fate-Weavers", rarity = "Legendary", color = Color3.fromRGB(255, 210, 255), luck = 3, essence = 1.25, lore = "They don't roll the dice. They choose the number." },

	-- Mythic (each has a Mode) ------------------------------------------------------------------
	{
		id = "dragonblood", name = "Dragonblood", rarity = "Mythic", color = Color3.fromRGB(255, 110, 20),
		styles = { "fire", "phoenix", "stone" }, affinity = 2.5, hp = 1.3,
		lore = "There was a dragon in the family tree. It shows.",
		mode = { name = "Dragon Form", damage = 2, speed = 1.25, defense = 0.8, duration = 20, cooldown = 90, color = Color3.fromRGB(255, 110, 20), desc = "Scales harden, fire pours off you." },
	},
	{
		id = "moonshadow", name = "Moonshadow", rarity = "Mythic", color = Color3.fromRGB(150, 140, 255),
		styles = { "eclipse", "void", "phantom", "chrono" }, affinity = 2.5, cooldown = 0.85,
		lore = "They walk where the moonlight doesn't reach.",
		mode = { name = "Eclipse Form", damage = 2.2, speed = 1.3, duration = 18, cooldown = 90, color = Color3.fromRGB(150, 140, 255), desc = "You become half shadow, half moonlight." },
	},
	{
		id = "asura", name = "Asura", rarity = "Mythic", color = Color3.fromRGB(230, 40, 60),
		styles = { "blade", "blood", "speed" }, affinity = 2.5, flat = 10,
		lore = "War-spirits in human skin.",
		mode = { name = "Asura Rage", damage = 2.5, speed = 1.2, duration = 15, cooldown = 90, color = Color3.fromRGB(230, 40, 60), desc = "Pure fury. Everything hits twice as hard, and then some." },
	},
	{
		id = "seraphim", name = "Seraphim", rarity = "Mythic", color = Color3.fromRGB(255, 250, 220),
		styles = { "light", "celestial", "dawn" }, affinity = 2.5, defense = 0.8,
		lore = "Something holy hides in their blood.",
		mode = { name = "Seraph Wings", damage = 2, speed = 1.35, defense = 0.7, duration = 20, cooldown = 90, color = Color3.fromRGB(255, 250, 220), desc = "Burning wings unfold behind you." },
	},

	-- Transcendent (each has a Mode) ------------------------------------------------------------
	{
		id = "primordial", name = "Primordial", rarity = "Transcendent", color = Color3.fromRGB(255, 255, 255),
		styles = { "*" }, affinity = 2.5, hp = 1.5, damage = 1.2, luck = 1.5,
		lore = "The first people. Before the dark, before the light.",
		mode = { name = "Primordial Awakening", damage = 3, speed = 1.5, defense = 0.6, duration = 22, cooldown = 100, color = Color3.fromRGB(255, 255, 255), desc = "Every element at once, shifting across your skin." },
	},
	{
		id = "hollowcrown", name = "Hollow Crown", rarity = "Transcendent", color = Color3.fromRGB(120, 0, 30),
		styles = { "void", "necro", "eclipse", "gravity" }, affinity = 3, lifesteal = 0.1,
		lore = "Distant blood of the Umbral King himself. The shadows hesitate.",
		mode = { name = "Crown of Shadows", damage = 2.75, speed = 1.4, defense = 0.6, duration = 22, cooldown = 100, color = Color3.fromRGB(200, 0, 50), desc = "A crown of black fire. The shadows bow." },
	},
}

-- Same rarity weights and colours as powers.
Clans.Weights = {}
Clans.RarityColors = {}
for _, rarity in Powers.Rarities do
	Clans.Weights[rarity.id] = rarity.weight
	Clans.RarityColors[rarity.id] = rarity.color
end
Clans.RarityRank = {}
for index, name in Clans.RarityOrder do
	Clans.RarityRank[name] = index
end

Clans.ById = {}
for _, clan in Clans.List do
	Clans.ById[clan.id] = clan
end

local NONE = {}

function Clans.Of(id: string?)
	return (id and Clans.ById[id]) or NONE
end

-- Damage multiplier a clan gives a power with this vfx style.
function Clans.AffinityFor(id: string?, style: string?): number
	local clan = Clans.Of(id)
	if not clan.styles or not style then
		return 1
	end
	for _, s in clan.styles do
		if s == "*" or s == style then
			return clan.affinity or 1
		end
	end
	return 1
end

-- Rolls a clan. luck multiplies the weight of Legendary and better; forceLegendary is the pity.
function Clans.Roll(rng: Random, forceLegendary: boolean?, luck: number?)
	local legendary = Clans.RarityRank.Legendary
	local function weight(rarity: string): number
		local rank = Clans.RarityRank[rarity]
		if forceLegendary and rank < legendary then
			return 0
		end
		return rank >= legendary and Clans.Weights[rarity] * (luck or 1) or Clans.Weights[rarity]
	end
	local total = 0
	for _, rarity in Clans.RarityOrder do
		total += weight(rarity)
	end
	local pick = rng:NextNumber() * total
	local chosen = Clans.RarityOrder[#Clans.RarityOrder]
	for _, rarity in Clans.RarityOrder do
		local w = weight(rarity)
		if w > 0 then
			pick -= w
			if pick <= 0 then
				chosen = rarity
				break
			end
		end
	end
	local candidates = {}
	for _, clan in Clans.List do
		if clan.rarity == chosen then
			table.insert(candidates, clan)
		end
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

-- Short human-readable perk lines for the UI.
function Clans.Describe(id: string?): { string }
	local c = Clans.Of(id)
	local lines = {}
	local function pct(mult: number): string
		return string.format("%+d%%", math.floor((mult - 1) * 100 + 0.5))
	end
	if c.styles then
		local list = table.concat(c.styles, ", ")
		table.insert(lines, string.format("%.2gx damage with %s powers", c.affinity or 1, list == "*" and "ALL" or list))
	end
	if c.damage then
		table.insert(lines, pct(c.damage) .. " all damage")
	end
	if c.flat then
		table.insert(lines, string.format("+%d damage per hit", c.flat))
	end
	if c.hp then
		table.insert(lines, string.format("%.2gx max health", c.hp))
	end
	if c.defense then
		table.insert(lines, pct(c.defense) .. " damage taken")
	end
	if c.speed then
		table.insert(lines, pct(c.speed) .. " move speed")
	end
	if c.cooldown then
		table.insert(lines, pct(c.cooldown) .. " power cooldowns")
	end
	if c.luck then
		table.insert(lines, string.format("%.2gx luck on power spins", c.luck))
	end
	if c.lifesteal then
		table.insert(lines, string.format("Heal %d%% of damage dealt", math.floor(c.lifesteal * 100 + 0.5)))
	end
	if c.sanity then
		table.insert(lines, pct(c.sanity) .. " sanity drain")
	end
	if c.gather then
		table.insert(lines, pct(c.gather) .. " gathered materials")
	end
	if c.essence then
		table.insert(lines, pct(c.essence) .. " Essence from kills")
	end
	if c.mode then
		local m = c.mode
		table.insert(lines, string.format("MODE [Y] %s: %.2gx damage, %.2gx speed for %ds (%ds cooldown)", m.name, m.damage, m.speed, m.duration, m.cooldown))
	end
	return lines
end

return Clans
