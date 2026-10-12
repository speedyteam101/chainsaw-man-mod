--[[
	Every tunable number in Aura Farm lives here.

	This module is plain Luau (no Roblox types) so the pure game logic can be
	unit tested outside Roblox. Colors are {R, G, B} arrays (0-255).
]]

local Config = {}

---------------------------------------------------------------------------
-- Aura ranks (lowest first). You hold the highest rank whose Min you meet.
---------------------------------------------------------------------------
Config.Ranks = {
	{ Name = "NPC", Min = 0, Color = { 170, 170, 170 } },
	{ Name = "Background Character", Min = 100, Color = { 120, 200, 255 } },
	{ Name = "Side Character", Min = 500, Color = { 90, 255, 160 } },
	{ Name = "Rival", Min = 1500, Color = { 255, 230, 80 } },
	{ Name = "Main Character", Min = 4000, Color = { 255, 150, 40 } },
	{ Name = "Protagonist", Min = 10000, Color = { 255, 70, 70 } },
	{ Name = "Legend", Min = 25000, Color = { 200, 90, 255 } },
	{ Name = "Aura God", Min = 60000, Color = { 255, 255, 255 } },
}

---------------------------------------------------------------------------
-- Heroic lines.
--   Aura:      base aura for saying it.
--   Condition: optional situation that makes it hit much harder:
--     "BossLow"    the boss you're fighting is below 25% health
--     "LowHealth"  you are below 30% health
--     "AfterDodge" you perfect-dodged in the last 4 seconds
--     "AfterHit"   you took a hit in the last 4 seconds
--     "NoBoss"     no boss is active (pre-fight trash talk)
--   Bonus:     multiplier applied when the Condition is met.
---------------------------------------------------------------------------
Config.HeroicLines = {
	{ Id = "notHere", Text = "I won't lose. Not here. Not now.", Aura = 15, Condition = "LowHealth", Bonus = 3 },
	{ Id = "standBack", Text = "Stand back. I'll handle this.", Aura = 10, Condition = "NoBoss", Bonus = 2 },
	{ Id = "wrongHero", Text = "You picked the wrong hero to fight.", Aura = 20 },
	{ Id = "friends", Text = "My friends are my power!", Aura = 15 },
	{ Id = "endsNow", Text = "This ends now.", Aura = 10, Condition = "BossLow", Bonus = 4 },
	{ Id = "thatsAll", Text = "Is that all you've got?", Aura = 15, Condition = "AfterHit", Bonus = 3 },
	{ Id = "neverBackDown", Text = "I never back down.", Aura = 10 },
	{ Id = "getBackUp", Text = "Even if I fall, I'll get back up.", Aura = 20, Condition = "LowHealth", Bonus = 2 },
	{ Id = "beyondLimits", Text = "Today, I go beyond my limits!", Aura = 25 },
	{ Id = "yourMistake", Text = "You hurt the people I care about. That was your mistake.", Aura = 30 },
	{ Id = "notTrying", Text = "I'm not even trying yet.", Aura = 25, Condition = "AfterDodge", Bonus = 2 },
	{ Id = "getBehindMe", Text = "Get behind me.", Aura = 10, Condition = "NoBoss", Bonus = 2 },
	{ Id = "fightForAll", Text = "I fight for everyone who can't.", Aura = 25 },
	{ Id = "rememberName", Text = "Remember my name.", Aura = 20, Condition = "BossLow", Bonus = 3 },
	{ Id = "oneMoreRound", Text = "One more round.", Aura = 10, Condition = "LowHealth", Bonus = 3 },
	{ Id = "heroShowsUp", Text = "The hero always shows up.", Aura = 15, Condition = "NoBoss", Bonus = 2 },
	{ Id = "myTurn", Text = "It's my turn now.", Aura = 15, Condition = "AfterDodge", Bonus = 3 },
	{ Id = "nothingStops", Text = "Nothing can stop me.", Aura = 15 },
	{ Id = "cameThisFar", Text = "I didn't come this far to quit.", Aura = 20, Condition = "LowHealth", Bonus = 2 },
	{ Id = "watchClosely", Text = "Watch closely. This is how it's done.", Aura = 25, Condition = "BossLow", Bonus = 2 },
	{ Id = "tooSlow", Text = "Too slow.", Aura = 10, Condition = "AfterDodge", Bonus = 4 },
	{ Id = "barelyScratch", Text = "That barely scratched me.", Aura = 15, Condition = "AfterHit", Bonus = 3 },
}

-- A message counts as a heroic line when at least this fraction of the
-- line's words appear in it (so small typos / missing words still count).
Config.LineMatchThreshold = 0.75

-- Freestyle: a message that isn't a known line but uses heroic words still
-- earns a little aura (per keyword, capped). Needs at least MinKeywords.
Config.Freestyle = {
	MinKeywords = 2,
	AuraPerKeyword = 4,
	MaxAura = 16,
	Keywords = {
		"protect", "never", "hero", "friends", "believe", "destiny", "promise",
		"power", "fight", "limit", "limits", "end", "defeat", "win", "strong",
		"stronger", "courage", "justice", "everyone", "unstoppable", "legend",
		"rise", "stand", "glory", "brave", "fear", "surrender",
	},
}

-- Saying anything heroic while a boss is active multiplies its aura.
Config.BossFightLineMultiplier = 2
-- Ignore heroic messages sent closer together than this (anti-spam), seconds.
Config.LineGlobalCooldown = 2.5
-- Repeating the same line within this window costs aura instead ("cringe").
Config.LineRepeatWindow = 30
Config.LineRepeatPenalty = 15
-- How long the line floats over your head, seconds.
Config.SpeechDuration = 3.5

---------------------------------------------------------------------------
-- Style meter (0-100). Fighting cool fills it, getting hit drains it.
---------------------------------------------------------------------------
Config.Style = {
	Max = 100,
	PerHit = 5,
	PerPerfectDodge = 18,
	PerHeroicLineInFight = 10,
	LostWhenHit = 35,
	DecayDelay = 3, -- seconds without gaining style before it decays
	DecayPerSecond = 6,
	-- Letter ranks (lowest first): reached when Style >= Min.
	Ranks = {
		{ Name = "D", Min = 0, Multiplier = 1 },
		{ Name = "C", Min = 20, Multiplier = 1.2 },
		{ Name = "B", Min = 40, Multiplier = 1.4 },
		{ Name = "A", Min = 60, Multiplier = 1.7 },
		{ Name = "S", Min = 80, Multiplier = 2 },
		{ Name = "SSS", Min = 100, Multiplier = 3 },
	},
}

---------------------------------------------------------------------------
-- Player combat
---------------------------------------------------------------------------
Config.Combat = {
	SlashDamage = 22,
	SlashCooldown = 0.35,
	SlashRange = 9, -- studs from your body to the boss's edge
	AuraPerHit = 1, -- multiplied by your style rank multiplier, rounded

	DashCooldown = 1.2,
	DashSpeed = 95,
	DashDuration = 0.18, -- how long the client pushes you forward
	DashInvulnerability = 0.45, -- i-frames, seconds
	PerfectDodgeWindow = 0.6, -- dash this close before an impact = perfect dodge
	PerfectDodgeAura = 15,

	UltimateStyleCost = 80, -- needs S rank or higher; spends this much style
	UltimateDamageFraction = 0.12, -- of the boss's max health...
	UltimateFlatDamage = 150, -- ...plus this
	UltimateRange = 30,
	UltimateCooldown = 3,

	DeathAuraLoss = 20, -- dying in a boss fight ("took the L")
}

---------------------------------------------------------------------------
-- Boss defeat bonuses. Bonuses add together, then multiply the base reward:
--   reward = Reward * styleMultiplier * (1 + sum of bonuses)
---------------------------------------------------------------------------
Config.DefeatBonuses = {
	Flawless = { Label = "FLAWLESS (no damage taken)", Bonus = 1.0 },
	Clutch = { Label = "CLUTCH (final blow under 25% HP)", Bonus = 0.75 },
	CalledIt = { Label = "CALLED IT (heroic line right before the kill)", Bonus = 0.5 },
	Finisher = { Label = "FINISHER (killed with your ultimate)", Bonus = 0.5 },
}
Config.ClutchHealthFraction = 0.25
Config.CalledItWindow = 6 -- seconds between your line and the killing blow
-- Participants who didn't land the kill get this fraction of the base reward.
Config.AssistFraction = 0.6

-- After a kill, walk away from the explosion without looking back.
Config.WalkAway = {
	Label = "DIDN'T LOOK BACK",
	Aura = 50,
	Duration = 2.5, -- seconds you must keep walking away
	SampleInterval = 0.25,
	RequiredFraction = 0.8, -- of samples that must be "walking away"
}

---------------------------------------------------------------------------
-- Bosses. Attacks: "Slam" (circle around the boss), "Charge" (line toward
-- the target), "Barrage" (circles under every fighter).
---------------------------------------------------------------------------
Config.Bosses = {
	{
		Id = "Brute",
		Name = "Grand Brute",
		Title = "The Wall That Hits Back",
		MaxHealth = 700,
		Reward = 120,
		Size = 9,
		Speed = 10,
		Color = { 120, 85, 60 },
		EyeColor = { 255, 60, 30 },
		Attacks = { "Slam", "Charge" },
		AttackInterval = 3.2,
		Windup = 1.1,
		Damage = 25,
		Cooldown = 20, -- seconds before this altar can be used again
	},
	{
		Id = "Storm",
		Name = "Storm Tyrant",
		Title = "Lord of the Grey Sky",
		MaxHealth = 1800,
		Reward = 350,
		Size = 11,
		Speed = 13,
		Color = { 60, 70, 110 },
		EyeColor = { 120, 220, 255 },
		Attacks = { "Slam", "Charge", "Barrage" },
		AttackInterval = 2.7,
		Windup = 0.95,
		Damage = 30,
		Cooldown = 30,
	},
	{
		Id = "Rival",
		Name = "The Final Rival",
		Title = "The One Who Was Always Stronger",
		MaxHealth = 3600,
		Reward = 900,
		Size = 8,
		Speed = 17,
		Color = { 25, 25, 30 },
		EyeColor = { 200, 80, 255 },
		Attacks = { "Slam", "Charge", "Barrage" },
		AttackInterval = 2.3,
		Windup = 0.85,
		Damage = 35,
		Cooldown = 45,
		EnrageAt = 0.5, -- below this health fraction, attacks speed up
		EnrageSpeedup = 0.7, -- windup and interval multiply by this
	},
}

Config.Attacks = {
	Slam = { Radius = 16 },
	Charge = { Length = 60, Width = 10, Duration = 0.45 },
	Barrage = { Radius = 8 },
}

-- The boss gives up and leaves if nobody is fighting it for this long.
Config.BossLeashTime = 12
-- Fighters must be within this distance of the arena centre.
Config.ArenaRadius = 90

---------------------------------------------------------------------------
-- Saving
---------------------------------------------------------------------------
Config.DataStoreName = "AuraFarm_v1"
Config.AutosaveInterval = 120

return Config
