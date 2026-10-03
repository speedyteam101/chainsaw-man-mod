--!nonstrict
-- Tokens and passes.
--
-- Tokens are a second currency. The ONLY way to get them is to trade Essence for them (plus a
-- one-time welcome gift). Passes are permanent upgrades bought with Tokens.
--
-- Robux rules:
--   * Essence and Tokens can never be bought with Robux. This game has no developer products and
--     no ProcessReceipt handler, and nothing here should ever add one for a currency.
--   * A pass MAY also be sold as a real Roblox game pass. Create the game pass on the Creator
--     Dashboard and paste its id into `robuxId` below. Left at 0, the pass is Tokens-only and
--     no Robux button is shown.
--   * `suggestedRobux` is only a suggestion (shown nowhere in game). The real Robux price is
--     whatever you set on the game pass in the Creator Dashboard; Roblox's own prompt shows it.

local Passes = {}

Passes.Exchange = {
	EssencePerToken = 4, -- normal rate: 4 Essence -> 1 Token
	NewcomerEssencePerToken = 2, -- newcomer rate: 2 Essence -> 1 Token...
	NewcomerAllowance = 1000, -- ...for the first 1000 Essence you ever trade
	WelcomeTokens = 100, -- a gift the first time you reach the camp
	Presets = { 40, 200, 1000 }, -- quick-trade buttons (Essence)
	Step = 4, -- trades are rounded down to a multiple of this, so no Essence is ever lost to rounding
}

Passes.List = {
	{
		id = "vault",
		name = "Power Vault",
		price = 300, -- Tokens
		robuxId = 0,
		suggestedRobux = 349,
		color = Color3.fromRGB(190, 140, 255),
		desc = "Permanent powers. Every power you own or roll from now on is kept in your vault forever, even if you replace it. Swap between them for free in the Power tab.",
	},
	{
		id = "lucky",
		name = "Lucky Star",
		price = 400,
		robuxId = 0,
		suggestedRobux = 399,
		color = Color3.fromRGB(255, 220, 110),
		desc = "Every roll is 1.5x as likely to be Legendary or better, forever. Stacks with Star Shards.",
	},
	{
		id = "belt",
		name = "Builder's Belt",
		price = 200,
		robuxId = 0,
		suggestedRobux = 149,
		color = Color3.fromRGB(200, 160, 110),
		desc = "Gather 50% more Wood, Stone, Scrap and everything else from trees, rocks and wrecks.",
	},
	{
		id = "wardrobe",
		name = "Biscuit's Wardrobe",
		price = 120,
		robuxId = 0,
		suggestedRobux = 79,
		color = Color3.fromRGB(255, 190, 210),
		desc = "Dress Biscuit up: a bow tie, a top hat, a flower crown or a tiny scarf. Purely for looks (and cuteness).",
	},
	{
		id = "secondwind",
		name = "Second Wind",
		price = 350,
		robuxId = 0,
		suggestedRobux = 249,
		color = Color3.fromRGB(255, 120, 110),
		desc = "Once every 5 minutes, a blow that would kill you leaves you standing at 30% health instead, with a moment of protection.",
	},
	{
		id = "swift",
		name = "Fleet Feet",
		price = 220,
		robuxId = 0,
		suggestedRobux = 149,
		color = Color3.fromRGB(130, 230, 200),
		desc = "Walk and sprint 12% faster in the shadow world.",
	},
	{
		id = "steady",
		name = "Steady Mind",
		price = 180,
		robuxId = 0,
		suggestedRobux = 99,
		color = Color3.fromRGB(170, 150, 255),
		desc = "The dark wears on you less: sanity drains 35% slower everywhere. Stacks with the Lantern.",
	},
	{
		id = "glow",
		name = "Biscuit's Glow",
		price = 180,
		robuxId = 0,
		suggestedRobux = 99,
		color = Color3.fromRGB(255, 230, 140),
		desc = "Biscuit's comforting aura reaches 50% further and restores sanity and health 50% faster.",
	},
	{
		id = "aura",
		name = "Radiant Aura",
		price = 150,
		robuxId = 0,
		suggestedRobux = 99,
		color = Color3.fromRGB(255, 255, 255),
		desc = "A glow in your power's colour lights the ground around you, and other players see you sparkle. Looks only; switch it on or off any time.",
	},
}

Passes.ById = {}
for _, pass in Passes.List do
	Passes.ById[pass.id] = pass
end

Passes.LuckMultiplier = 1.5
Passes.GatherMultiplier = 1.5
Passes.SecondWind = { Cooldown = 300, Health = 0.3, Protection = 1.5 }
Passes.SpeedMultiplier = 1.12
Passes.SanityDrainMultiplier = 0.65
Passes.DuckGlowMultiplier = 1.5

-- Biscuit's outfits (the Wardrobe pass).
Passes.DuckOutfits = { "None", "Bow Tie", "Top Hat", "Flower Crown", "Scarf" }

-- How many Tokens `essence` buys, given how much Essence has already been traded.
function Passes.Quote(essence: number, alreadyTraded: number): number
	local E = Passes.Exchange
	local cheap = math.clamp(E.NewcomerAllowance - alreadyTraded, 0, essence)
	local normal = essence - cheap
	return math.floor(cheap / E.NewcomerEssencePerToken + normal / E.EssencePerToken)
end

return Passes
