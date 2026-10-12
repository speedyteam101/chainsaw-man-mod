--[[
	Every tunable number in Aura Farm lives here.

	This module is plain Luau (no Roblox types) so the pure game logic can be
	unit tested outside Roblox. Colors are {R, G, B} arrays (0-255).
]]

local Config = {}

---------------------------------------------------------------------------
-- Aura ranks (lowest first). You hold the highest rank whose Min you meet.
-- Villains see EvilName instead of Name.
---------------------------------------------------------------------------
Config.Ranks = {
	{ Name = "NPC", EvilName = "Minion", Min = 0, Color = { 170, 170, 170 } },
	{ Name = "Background Character", EvilName = "Henchman", Min = 100, Color = { 120, 200, 255 } },
	{ Name = "Side Character", EvilName = "Enforcer", Min = 500, Color = { 90, 255, 160 } },
	{ Name = "Rival", EvilName = "Nemesis", Min = 1500, Color = { 255, 230, 80 } },
	{ Name = "Main Character", EvilName = "Main Villain", Min = 4000, Color = { 255, 150, 40 } },
	{ Name = "Protagonist", EvilName = "Overlord", Min = 10000, Color = { 255, 70, 70 } },
	{ Name = "Legend", EvilName = "Calamity", Min = 25000, Color = { 200, 90, 255 } },
	{ Name = "Aura God", EvilName = "Demon King", Min = 60000, Color = { 255, 255, 255 } },
}

---------------------------------------------------------------------------
-- Heroic lines (Good side and undecided players). Villains use
-- Config.VillainLines further down.
--   Aura:      base aura for saying it.
--   Condition: optional situation that makes it hit much harder:
--     "FoeLow"     the boss you're fighting, or an enemy player near you,
--                  is below 25% health
--     "LowHealth"  you are below 30% health
--     "AfterDodge" you perfect-dodged in the last 4 seconds
--     "AfterHit"   you took a hit in the last 4 seconds
--     "AfterKill"  you defeated an enemy player in the last 5 seconds
--     "NoFight"    you're not in a fight (pre-fight trash talk)
--   Bonus:     multiplier applied when the Condition is met.
---------------------------------------------------------------------------
Config.HeroicLines = {
	{ Id = "notHere", Text = "I won't lose. Not here. Not now.", Aura = 15, Condition = "LowHealth", Bonus = 3 },
	{ Id = "standBack", Text = "Stand back. I'll handle this.", Aura = 10, Condition = "NoFight", Bonus = 2 },
	{ Id = "wrongHero", Text = "You picked the wrong hero to fight.", Aura = 20 },
	{ Id = "friends", Text = "My friends are my power!", Aura = 15 },
	{ Id = "endsNow", Text = "This ends now.", Aura = 10, Condition = "FoeLow", Bonus = 4 },
	{ Id = "thatsAll", Text = "Is that all you've got?", Aura = 15, Condition = "AfterHit", Bonus = 3 },
	{ Id = "neverBackDown", Text = "I never back down.", Aura = 10 },
	{ Id = "getBackUp", Text = "Even if I fall, I'll get back up.", Aura = 20, Condition = "LowHealth", Bonus = 2 },
	{ Id = "beyondLimits", Text = "Today, I go beyond my limits!", Aura = 25 },
	{ Id = "yourMistake", Text = "You hurt the people I care about. That was your mistake.", Aura = 30 },
	{ Id = "notTrying", Text = "I'm not even trying yet.", Aura = 25, Condition = "AfterDodge", Bonus = 2 },
	{ Id = "getBehindMe", Text = "Get behind me.", Aura = 10, Condition = "NoFight", Bonus = 2 },
	{ Id = "fightForAll", Text = "I fight for everyone who can't.", Aura = 25 },
	{ Id = "rememberName", Text = "Remember my name.", Aura = 20, Condition = "FoeLow", Bonus = 3 },
	{ Id = "oneMoreRound", Text = "One more round.", Aura = 10, Condition = "LowHealth", Bonus = 3 },
	{ Id = "heroShowsUp", Text = "The hero always shows up.", Aura = 15, Condition = "NoFight", Bonus = 2 },
	{ Id = "myTurn", Text = "It's my turn now.", Aura = 15, Condition = "AfterDodge", Bonus = 3 },
	{ Id = "nothingStops", Text = "Nothing can stop me.", Aura = 15 },
	{ Id = "cameThisFar", Text = "I didn't come this far to quit.", Aura = 20, Condition = "LowHealth", Bonus = 2 },
	{ Id = "watchClosely", Text = "Watch closely. This is how it's done.", Aura = 25, Condition = "FoeLow", Bonus = 2 },
	{ Id = "tooSlow", Text = "Too slow.", Aura = 10, Condition = "AfterDodge", Bonus = 4 },
	{ Id = "barelyScratch", Text = "That barely scratched me.", Aura = 15, Condition = "AfterHit", Bonus = 3 },
	{ Id = "justiceServed", Text = "Justice is served.", Aura = 15, Condition = "AfterKill", Bonus = 3 },
	{ Id = "stayDown", Text = "Stay down.", Aura = 10, Condition = "AfterKill", Bonus = 4 },
}

-- Villain lines: same rules as the heroic lines, for the Evil side.
Config.VillainLines = {
	{ Id = "neverThreat", Text = "You were never a threat to me.", Aura = 20 },
	{ Id = "kneel", Text = "Kneel.", Aura = 10, Condition = "FoeLow", Bonus = 4 },
	{ Id = "bestHeroes", Text = "Is this the best your heroes can do?", Aura = 15, Condition = "AfterDodge", Bonus = 3 },
	{ Id = "pathetic", Text = "Pathetic.", Aura = 10, Condition = "AfterDodge", Bonus = 4 },
	{ Id = "hopeEnds", Text = "Your hope ends here.", Aura = 15, Condition = "FoeLow", Bonus = 3 },
	{ Id = "letYouHit", Text = "I let you hit me.", Aura = 15, Condition = "AfterHit", Bonus = 3 },
	{ Id = "painStronger", Text = "Pain only makes me stronger.", Aura = 20, Condition = "AfterHit", Bonus = 2 },
	{ Id = "runWhileYouCan", Text = "Run while you still can.", Aura = 10, Condition = "NoFight", Bonus = 2 },
	{ Id = "worldBows", Text = "This world will bow to me.", Aura = 25 },
	{ Id = "heroOnce", Text = "I was the hero once.", Aura = 25 },
	{ Id = "darknessWins", Text = "Darkness always wins.", Aura = 15 },
	{ Id = "mercyWeak", Text = "Mercy is for the weak.", Aura = 20 },
	{ Id = "alreadyWon", Text = "I've already won. You just don't know it yet.", Aura = 30 },
	{ Id = "nobodyComing", Text = "Nobody is coming to save you.", Aura = 20, Condition = "FoeLow", Bonus = 2 },
	{ Id = "anotherFalls", Text = "Another one falls.", Aura = 15, Condition = "AfterKill", Bonus = 3 },
	{ Id = "whosNext", Text = "Who's next?", Aura = 10, Condition = "AfterKill", Bonus = 4 },
	{ Id = "whatsComing", Text = "You can't stop what's coming.", Aura = 15, Condition = "NoFight", Bonus = 2 },
	{ Id = "evenBroken", Text = "Even broken, I am stronger than you.", Aura = 20, Condition = "LowHealth", Bonus = 3 },
	{ Id = "fearMe", Text = "Fear me.", Aura = 10 },
	{ Id = "lightFading", Text = "Your light is fading.", Aura = 20, Condition = "FoeLow", Bonus = 2 },
	{ Id = "iDontLose", Text = "I don't lose.", Aura = 15, Condition = "LowHealth", Bonus = 3 },
	{ Id = "newRuler", Text = "Bow before your new ruler.", Aura = 25 },
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

-- Freestyle words for villains.
Config.VillainFreestyle = {
	MinKeywords = 2,
	AuraPerKeyword = 4,
	MaxAura = 16,
	Keywords = {
		"weak", "kneel", "pathetic", "despair", "destroy", "darkness", "dark",
		"fear", "crush", "mercy", "worthless", "bow", "ruin", "hopeless",
		"suffer", "doom", "power", "rule", "conquer", "fall", "chaos", "beg",
		"tremble", "shadow", "hero", "heroes", "nothing",
	},
}

-- Saying a line while in a fight (boss fight, or an enemy player nearby)
-- multiplies its aura.
Config.FightLineMultiplier = 2
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
	-- Slash damage / range / speed, dash cooldown, health and move speed
	-- come from your class (see Classes.lua).
	AuraPerHit = 1, -- multiplied by your style rank multiplier, rounded

	DashSpeed = 95,
	DashDuration = 0.18, -- how long the client pushes you forward
	DashInvulnerability = 0.45, -- i-frames, seconds
	PerfectDodgeWindow = 0.6, -- dash this close before an impact = perfect dodge
	PerfectDodgeAura = 15,

	UltimateStyleCost = 80, -- needs S rank or higher; spends this much style
	UltimateCooldown = 3,

	DeathAuraLoss = 20, -- dying in a boss fight ("took the L")
}

---------------------------------------------------------------------------
-- PvP: Good vs Evil only. Players on the same side can't hurt each other,
-- and nobody can be hurt by players inside a spawn's safe zone.
---------------------------------------------------------------------------
Config.Pvp = {
	KillAura = 40, -- base aura for defeating an enemy player
	DeathAuraLoss = 10, -- for being defeated by one
	KillCreditWindow = 10, -- your hit must be this recent to get the kill
	-- Defeating the same player again within RepeatWindow seconds pays
	-- RepeatFalloff times less each time (stops kill farming).
	RepeatWindow = 120,
	RepeatFalloff = 0.5,
	GiantSlayerPerRank = 0.5, -- bonus per aura rank the victim is above you
	GiantSlayerMax = 1.5,
	RevengeBonus = 0.5, -- for defeating whoever last defeated you
	HitRangeBonus = 2, -- extra slash reach against players (hit boxes are small)
	HitConeDot = 0.2, -- players must be roughly in front of you to be slashed
	FightRadius = 40, -- an enemy player this close counts as "in a fight"
	SafeZoneRadius = 30,
	ClassChangeCooldown = 5,
	CombatLock = 8, -- can't change class this soon after a player hit you
	HitPlayerDamageFactor = 1, -- multiplies slash damage against players
}
Config.PvpBonuses = {
	GiantSlayer = "GIANT SLAYER (they outranked you)",
	Revenge = "REVENGE",
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
