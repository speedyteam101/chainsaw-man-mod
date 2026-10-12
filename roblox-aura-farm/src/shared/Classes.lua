--[[
	Every class, for both sides. Pure Luau (no Roblox types) so it can be
	unit tested outside Roblox; colors are {R, G, B} arrays.

	Stats (all optional except Id/Name/Side/Role/Ultimate; missing ones use
	Classes.Defaults):
		MaxHealth, WalkSpeed
		SlashDamage, SlashRange (studs), SlashCooldown (seconds)
		DashCooldown (seconds)
		Armor      fraction of incoming damage ignored (0..0.5)
		Lifesteal  fraction of damage dealt healed back
		StyleGain  multiplier on style meter gains
	Ultimate = { Kind = <one of Classes.UltimateKinds>, Name = string, Power = number }
		Power multiplies the kind's damage and healing.
]]

local Classes = {}

Classes.Defaults = {
	MaxHealth = 100,
	WalkSpeed = 16,
	SlashDamage = 22,
	SlashRange = 9,
	SlashCooldown = 0.35,
	DashCooldown = 1.2,
	Armor = 0,
	Lifesteal = 0,
	StyleGain = 1,
}

-- The six ultimate mechanics. Damage numbers are before the class's Power.
Classes.UltimateKinds = {
	-- A column of light on one target (the boss, or the nearest enemy player).
	Pillar = { Range = 30, BossFraction = 0.12, BossFlat = 150, PlayerDamage = 45, Description = "Huge hit on one target" },
	-- An explosion around you.
	Nova = { Radius = 18, BossDamage = 180, PlayerDamage = 35, Description = "Blast everything around you" },
	-- A long dash that cuts through everything in a line.
	Rush = { Length = 32, Width = 9, BossDamage = 170, PlayerDamage = 40, Description = "Dash through enemies in a line" },
	-- Damage around you and heal yourself for part of it.
	Drain = { Radius = 16, BossDamage = 130, PlayerDamage = 28, HealFraction = 0.6, Description = "Steal life from enemies around you" },
	-- Heal yourself and allies around you.
	Mend = { Radius = 25, HealPercent = 0.4, AuraPerAlly = 8, Description = "Heal yourself and nearby allies" },
	-- Brief invincibility (and a small heal) for you and allies around you.
	Fortify = { Radius = 20, Duration = 3, HealPercent = 0.15, AuraPerAlly = 6, Description = "Make you and nearby allies invincible" },
}

Classes.Sides = {
	Good = { Name = "Heroes", Color = { 255, 205, 80 } },
	Evil = { Name = "Villains", Color = { 200, 40, 60 } },
}

local good = {
	{ Id = "Paladin", Name = "Paladin", Role = "Tank", Color = { 255, 225, 120 },
		Description = "Holy armor and a steady blade. Shields the team when it matters.",
		MaxHealth = 160, WalkSpeed = 14, SlashDamage = 20, Armor = 0.1,
		Ultimate = { Kind = "Fortify", Name = "Sacred Bulwark", Power = 1 } },
	{ Id = "Guardian", Name = "Guardian", Role = "Tank", Color = { 150, 200, 255 },
		Description = "A walking fortress. Slow, but almost impossible to take down.",
		MaxHealth = 180, WalkSpeed = 13, SlashDamage = 16, Armor = 0.2,
		Ultimate = { Kind = "Fortify", Name = "Unbreakable Wall", Power = 1.3 } },
	{ Id = "Swordmaster", Name = "Swordmaster", Role = "Duelist", Color = { 220, 240, 255 },
		Description = "Perfect technique. Every cut lands where it should.",
		MaxHealth = 100, WalkSpeed = 17, SlashDamage = 26,
		Ultimate = { Kind = "Pillar", Name = "Heaven Splitter", Power = 1.1 } },
	{ Id = "LightningKnight", Name = "Lightning Knight", Role = "Speedster", Color = { 255, 255, 120 },
		Description = "Too fast to see. Dashes twice as often as anyone else.",
		MaxHealth = 90, WalkSpeed = 22, SlashDamage = 20, DashCooldown = 0.7,
		Ultimate = { Kind = "Rush", Name = "Thunderclap Rush", Power = 1 } },
	{ Id = "SkyLancer", Name = "Sky Lancer", Role = "Duelist", Color = { 140, 220, 255 },
		Description = "Long spear, long reach. Hits from where others can't.",
		MaxHealth = 105, WalkSpeed = 17, SlashDamage = 22, SlashRange = 13,
		Ultimate = { Kind = "Rush", Name = "Falling Star Lance", Power = 1.1 } },
	{ Id = "Cleric", Name = "Cleric", Role = "Support", Color = { 255, 250, 210 },
		Description = "Keeps everyone standing. Earns aura for every ally healed.",
		MaxHealth = 110, WalkSpeed = 16, SlashDamage = 15,
		Ultimate = { Kind = "Mend", Name = "Grand Blessing", Power = 1.2 } },
	{ Id = "SunMonk", Name = "Sun Monk", Role = "Fighter", Color = { 255, 170, 60 },
		Description = "A flurry of fists. Fastest attacks in the game.",
		MaxHealth = 110, WalkSpeed = 18, SlashDamage = 15, SlashRange = 7, SlashCooldown = 0.22,
		Ultimate = { Kind = "Nova", Name = "Solar Flare Palm", Power = 1 } },
	{ Id = "StormCaller", Name = "Storm Caller", Role = "Mage", Color = { 120, 180, 255 },
		Description = "Fragile, but the storm answers when called.",
		MaxHealth = 85, WalkSpeed = 16, SlashDamage = 18, SlashRange = 11,
		Ultimate = { Kind = "Nova", Name = "Tempest Crown", Power = 1.45 } },
	{ Id = "StarArcher", Name = "Star Archer", Role = "Ranged", Color = { 200, 230, 255 },
		Description = "Strikes from the longest range of any hero.",
		MaxHealth = 85, WalkSpeed = 17, SlashDamage = 18, SlashRange = 15,
		Ultimate = { Kind = "Pillar", Name = "Starfall Arrow", Power = 1.2 } },
	{ Id = "IronFist", Name = "Iron Fist", Role = "Bruiser", Color = { 200, 200, 210 },
		Description = "Heavy, slow punches that hit like a truck.",
		MaxHealth = 140, WalkSpeed = 15, SlashDamage = 28, SlashRange = 8, SlashCooldown = 0.5,
		Ultimate = { Kind = "Nova", Name = "Earthshaker", Power = 1.1 } },
	{ Id = "ShieldBearer", Name = "Shield Bearer", Role = "Tank", Color = { 180, 160, 120 },
		Description = "Shield first, sword second. The best armor on the hero side.",
		MaxHealth = 150, WalkSpeed = 14, SlashDamage = 17, Armor = 0.3,
		Ultimate = { Kind = "Fortify", Name = "Phalanx", Power = 1.1 } },
	{ Id = "DawnBlade", Name = "Dawn Blade", Role = "Duelist", Color = { 255, 200, 150 },
		Description = "Each strike draws strength from the morning sun.",
		MaxHealth = 110, WalkSpeed = 17, SlashDamage = 24, Lifesteal = 0.1,
		Ultimate = { Kind = "Pillar", Name = "First Light", Power = 1 } },
	{ Id = "WindDancer", Name = "Wind Dancer", Role = "Speedster", Color = { 170, 255, 210 },
		Description = "Moves like the wind and fills the style meter faster.",
		MaxHealth = 90, WalkSpeed = 23, SlashDamage = 17, DashCooldown = 0.9, StyleGain = 1.3,
		Ultimate = { Kind = "Rush", Name = "Gale Waltz", Power = 0.9 } },
	{ Id = "FrostWarden", Name = "Frost Warden", Role = "Bruiser", Color = { 170, 230, 255 },
		Description = "Cold, calm and very hard to move.",
		MaxHealth = 130, WalkSpeed = 15, SlashDamage = 20, Armor = 0.1,
		Ultimate = { Kind = "Nova", Name = "Absolute Zero", Power = 1.1 } },
	{ Id = "GroveHealer", Name = "Grove Healer", Role = "Support", Color = { 140, 230, 120 },
		Description = "The strongest healer on either side.",
		MaxHealth = 105, WalkSpeed = 16, SlashDamage = 14,
		Ultimate = { Kind = "Mend", Name = "Bloom of Life", Power = 1.5 } },
	{ Id = "Lionheart", Name = "Lionheart", Role = "Bruiser", Color = { 255, 190, 90 },
		Description = "Charges in first and roars the loudest.",
		MaxHealth = 135, WalkSpeed = 17, SlashDamage = 23,
		Ultimate = { Kind = "Rush", Name = "Pride Charge", Power = 1.1 } },
	{ Id = "SpiritSage", Name = "Spirit Sage", Role = "Support", Color = { 210, 180, 255 },
		Description = "Calls on ancestors to protect the team.",
		MaxHealth = 100, WalkSpeed = 16, SlashDamage = 16, SlashRange = 11,
		Ultimate = { Kind = "Fortify", Name = "Ancestral Ward", Power = 1 } },
	{ Id = "Crusader", Name = "Crusader", Role = "Fighter", Color = { 240, 240, 240 },
		Description = "Balanced in every way. A good first pick.",
		MaxHealth = 125, WalkSpeed = 16, SlashDamage = 22,
		Ultimate = { Kind = "Pillar", Name = "Righteous Verdict", Power = 1 } },
	{ Id = "PhoenixKnight", Name = "Phoenix Knight", Role = "Fighter", Color = { 255, 120, 60 },
		Description = "Burns bright and heals from every hit.",
		MaxHealth = 115, WalkSpeed = 17, SlashDamage = 20, Lifesteal = 0.15,
		Ultimate = { Kind = "Nova", Name = "Rebirth Flame", Power = 1 } },
	{ Id = "Valkyrie", Name = "Valkyrie", Role = "Duelist", Color = { 230, 220, 255 },
		Description = "Swift wings, sharp spear.",
		MaxHealth = 115, WalkSpeed = 19, SlashDamage = 22, SlashRange = 11,
		Ultimate = { Kind = "Rush", Name = "Winged Descent", Power = 1 } },
	{ Id = "CometStriker", Name = "Comet Striker", Role = "Speedster", Color = { 255, 230, 200 },
		Description = "Hits hard for something so fast.",
		MaxHealth = 95, WalkSpeed = 20, SlashDamage = 23, DashCooldown = 1,
		Ultimate = { Kind = "Rush", Name = "Comet Trail", Power = 1.2 } },
	{ Id = "LegendHero", Name = "Hero of Legend", Role = "All-rounder", Color = { 255, 215, 0 },
		Description = "The classic hero. Gains style faster than anyone.",
		MaxHealth = 120, WalkSpeed = 17, SlashDamage = 21, StyleGain = 1.25,
		Ultimate = { Kind = "Pillar", Name = "Legendary Strike", Power = 1.05 } },
}

local evil = {
	{ Id = "Warlord", Name = "Warlord", Role = "Bruiser", Color = { 200, 60, 40 },
		Description = "Conquers by force. Big hits, big health.",
		MaxHealth = 145, WalkSpeed = 15, SlashDamage = 25,
		Ultimate = { Kind = "Nova", Name = "Warpath", Power = 1.1 } },
	{ Id = "ShadowAssassin", Name = "Shadow Assassin", Role = "Assassin", Color = { 120, 60, 180 },
		Description = "Deadliest blade in the game, but goes down fast.",
		MaxHealth = 80, WalkSpeed = 22, SlashDamage = 29, DashCooldown = 0.8,
		Ultimate = { Kind = "Rush", Name = "Thousand Shadows", Power = 1.2 } },
	{ Id = "Necromancer", Name = "Necromancer", Role = "Mage", Color = { 120, 255, 150 },
		Description = "Feeds on the life of anything nearby.",
		MaxHealth = 95, WalkSpeed = 16, SlashDamage = 18, SlashRange = 11,
		Ultimate = { Kind = "Drain", Name = "Grave Harvest", Power = 1.3 } },
	{ Id = "BloodKnight", Name = "Blood Knight", Role = "Fighter", Color = { 180, 0, 30 },
		Description = "Every wound he deals keeps him alive.",
		MaxHealth = 120, WalkSpeed = 16, SlashDamage = 21, Lifesteal = 0.15,
		Ultimate = { Kind = "Drain", Name = "Crimson Feast", Power = 1 } },
	{ Id = "DreadJuggernaut", Name = "Dread Juggernaut", Role = "Tank", Color = { 90, 80, 90 },
		Description = "The most health in the game. Slow as a glacier.",
		MaxHealth = 190, WalkSpeed = 12, SlashDamage = 20, Armor = 0.2,
		Ultimate = { Kind = "Nova", Name = "Cataclysm Stomp", Power = 1 } },
	{ Id = "HexWitch", Name = "Hex Witch", Role = "Mage", Color = { 200, 90, 255 },
		Description = "Curses from a distance and drinks the life out of heroes.",
		MaxHealth = 90, WalkSpeed = 16, SlashDamage = 18, SlashRange = 12,
		Ultimate = { Kind = "Drain", Name = "Withering Hex", Power = 1.2 } },
	{ Id = "VoidReaper", Name = "Void Reaper", Role = "Duelist", Color = { 60, 0, 90 },
		Description = "A scythe with terrible reach.",
		MaxHealth = 105, WalkSpeed = 16, SlashDamage = 26, SlashRange = 12, SlashCooldown = 0.42,
		Ultimate = { Kind = "Pillar", Name = "Void Sentence", Power = 1.15 } },
	{ Id = "PlagueDoctor", Name = "Plague Doctor", Role = "Support", Color = { 160, 200, 60 },
		Description = "Patches up villains so they can keep fighting.",
		MaxHealth = 105, WalkSpeed = 16, SlashDamage = 16,
		Ultimate = { Kind = "Mend", Name = "Dark Remedy", Power = 1.2 } },
	{ Id = "InfernoTyrant", Name = "Inferno Tyrant", Role = "Mage", Color = { 255, 80, 0 },
		Description = "The biggest explosion on the villain side.",
		MaxHealth = 90, WalkSpeed = 15, SlashDamage = 19, SlashRange = 10,
		Ultimate = { Kind = "Nova", Name = "Hellfire Eruption", Power = 1.5 } },
	{ Id = "BoneColossus", Name = "Bone Colossus", Role = "Tank", Color = { 230, 220, 200 },
		Description = "A wall of bones that protects its allies.",
		MaxHealth = 170, WalkSpeed = 13, SlashDamage = 17, Armor = 0.2,
		Ultimate = { Kind = "Fortify", Name = "Ossuary Shell", Power = 1.2 } },
	{ Id = "VenomStalker", Name = "Venom Stalker", Role = "Speedster", Color = { 100, 255, 60 },
		Description = "Hunts heroes down before they can run.",
		MaxHealth = 90, WalkSpeed = 22, SlashDamage = 19, DashCooldown = 0.8,
		Ultimate = { Kind = "Rush", Name = "Fang Lunge", Power = 1 } },
	{ Id = "DoomKnight", Name = "Doom Knight", Role = "Fighter", Color = { 80, 80, 120 },
		Description = "Balanced in every way. A good first pick.",
		MaxHealth = 125, WalkSpeed = 16, SlashDamage = 22,
		Ultimate = { Kind = "Pillar", Name = "Doomfall", Power = 1 } },
	{ Id = "StormDespot", Name = "Storm Despot", Role = "Mage", Color = { 100, 120, 200 },
		Description = "Rules the sky with dark lightning.",
		MaxHealth = 95, WalkSpeed = 16, SlashDamage = 18, SlashRange = 11,
		Ultimate = { Kind = "Nova", Name = "Black Thunder", Power = 1.35 } },
	{ Id = "NightHunter", Name = "Night Hunter", Role = "Ranged", Color = { 90, 70, 140 },
		Description = "Picks heroes off from the longest range of any villain.",
		MaxHealth = 85, WalkSpeed = 17, SlashDamage = 18, SlashRange = 15,
		Ultimate = { Kind = "Pillar", Name = "Moonless Shot", Power = 1.2 } },
	{ Id = "ChaosBrawler", Name = "Chaos Brawler", Role = "Fighter", Color = { 255, 60, 120 },
		Description = "Wild, fast swings that never stop.",
		MaxHealth = 115, WalkSpeed = 18, SlashDamage = 16, SlashRange = 7, SlashCooldown = 0.24,
		Ultimate = { Kind = "Nova", Name = "Pandemonium", Power = 1 } },
	{ Id = "IronTyrant", Name = "Iron Tyrant", Role = "Tank", Color = { 120, 110, 110 },
		Description = "Thick iron plating. The best armor on the villain side.",
		MaxHealth = 150, WalkSpeed = 14, SlashDamage = 18, Armor = 0.3,
		Ultimate = { Kind = "Fortify", Name = "Iron Dominion", Power = 1 } },
	{ Id = "SoulEater", Name = "Soul Eater", Role = "Fighter", Color = { 150, 220, 255 },
		Description = "Weak hits, but devours life with every one.",
		MaxHealth = 110, WalkSpeed = 17, SlashDamage = 18, Lifesteal = 0.2,
		Ultimate = { Kind = "Drain", Name = "Soul Devour", Power = 1.1 } },
	{ Id = "CursedSamurai", Name = "Cursed Samurai", Role = "Duelist", Color = { 150, 0, 0 },
		Description = "A cursed blade that cuts deeper than any other.",
		MaxHealth = 100, WalkSpeed = 17, SlashDamage = 27,
		Ultimate = { Kind = "Pillar", Name = "Cursed Iaido", Power = 1.1 } },
	{ Id = "AbyssWalker", Name = "Abyss Walker", Role = "Speedster", Color = { 30, 60, 90 },
		Description = "Steps out of the dark right behind you.",
		MaxHealth = 95, WalkSpeed = 20, SlashDamage = 22, DashCooldown = 0.9,
		Ultimate = { Kind = "Rush", Name = "Abyssal Step", Power = 1.1 } },
	{ Id = "DarkPriest", Name = "Dark Priest", Role = "Support", Color = { 120, 40, 80 },
		Description = "Unholy prayers that keep the villains fighting.",
		MaxHealth = 100, WalkSpeed = 16, SlashDamage = 16, SlashRange = 11,
		Ultimate = { Kind = "Fortify", Name = "Unholy Covenant", Power = 1 } },
	{ Id = "FallenHero", Name = "Fallen Hero", Role = "All-rounder", Color = { 160, 140, 100 },
		Description = "Was a hero once. Gains style faster than anyone.",
		MaxHealth = 120, WalkSpeed = 17, SlashDamage = 21, StyleGain = 1.25,
		Ultimate = { Kind = "Pillar", Name = "Betrayal", Power = 1.05 } },
	{ Id = "DemonLord", Name = "Demon Lord", Role = "Bruiser", Color = { 255, 0, 60 },
		Description = "Raw demonic power. Slow, tough and terrifying.",
		MaxHealth = 150, WalkSpeed = 14, SlashDamage = 25, Armor = 0.1,
		Ultimate = { Kind = "Nova", Name = "Demon King's Wrath", Power = 1.2 } },
}

Classes.Good = good
Classes.Evil = evil

-- Lookup by Id, with defaults filled in and Side set.
Classes.byId = {}
for side, list in pairs({ Good = good, Evil = evil }) do
	for _, class in ipairs(list) do
		class.Side = side
		for key, value in pairs(Classes.Defaults) do
			if class[key] == nil then
				class[key] = value
			end
		end
		Classes.byId[class.Id] = class
	end
end

function Classes.get(id: any)
	if type(id) ~= "string" then
		return nil
	end
	return Classes.byId[id]
end

return Classes
