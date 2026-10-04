--!nonstrict
-- Biscuit's Tips: a small "what now?" card for new players. It isn't a quest log (nothing is
-- rewarded for following it). It just looks at where you are and suggests one useful next thing,
-- and shows the controls for your first few minutes in the camp. Press H to hide or show it.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Passes = require(ReplicatedStorage.Shared.Passes)
local Townsfolk = require(ReplicatedStorage.Shared.Townsfolk)
local Ui = require(script.Parent.Ui)
local ClientState = require(script.Parent.ClientState)

local Guide = {}

local T = Ui.Theme
local player = Players.LocalPlayer
local card, tipLabel, controlsLabel, blessingLabel
local hidden = false
local act2Since = nil

local CONTROLS = "Click: punch   F: block   Q: dodge   Shift: sprint\nZ X C V: powers   G: ultimate   1 2 3: items\nL: flashlight   E: talk / pick up   M: menu   B: build   Tab: pack"

local function cheapestPassLeft(): number?
	local best = nil
	for _, pass in Passes.List do
		if not (ClientState.passes and ClientState.passes[pass.id]) then
			best = math.min(best or math.huge, pass.price)
		end
	end
	return best
end

local function nextTip(): string
	local level = player:GetAttribute("Level") or 1
	local essence = player:GetAttribute("Essence") or 0
	local tokens = player:GetAttribute("Tokens") or 0
	if workspace:GetAttribute("Blackout") ~= nil then
		return "BLACKOUT: get to the camp or your base, or turn your flashlight on (L) and keep it on the Hollow. Your powers can't hurt it."
	end
	if (player:GetAttribute("Clan") or "") == "" then
		return "You don't have a clan yet. Open the menu (M) > Clan and use your free rolls: clans give big perks."
	end
	if player:GetAttribute("CanAscend") then
		return "You earned a feat that lets you level up! Open the menu (M) and press Ascend."
	end
	if not ClientState.basePlaced then
		return "Build a safe place: open the Build tab (B) and place your Base Crystal away from the camp. Shadows can't cross its barrier."
	end
	local cheapest = cheapestPassLeft()
	if cheapest and tokens >= cheapest then
		return "You have enough Tokens for a pass. Have a look in the menu (M) > Tokens."
	end
	if Townsfolk.Count(ClientState.rescued or {}) == 0 then
		return "People from town are trapped by shadows. Find them, clear the shadows and press E to free them. Builders make your base better."
	end
	if essence >= 40 and (ClientState.essenceTraded or 0) < Passes.Exchange.NewcomerAllowance then
		return string.format("Essence buys rerolls and shop items, and you can trade it for Tokens at a newcomer rate (%d Essence = 1 Token) in menu > Tokens.", Passes.Exchange.NewcomerEssencePerToken)
	end
	if level < Config.MaxLevel then
		return string.format("To reach level %d, earn any feat marked \"qualifies for level %d\" (menu > Ascension), then Ascend.", level + 1, level + 1)
	end
	return "The Umbral King waits in the Heart of Shadow. Bring Biscuit, and bring snacks."
end

local function refresh()
	local act2 = player:GetAttribute("Act") == 2
	if act2 and not act2Since then
		act2Since = os.clock()
	end
	card.Visible = act2 and not hidden and not ClientState.InCutscene and not ClientState.BuildMode
	if not card.Visible then
		return
	end
	tipLabel.Text = nextTip()
	-- Controls for the first ten minutes (or until you reach level 2).
	local showControls = (player:GetAttribute("Level") or 1) < 2 and os.clock() - (act2Since or 0) < 600
	controlsLabel.Visible = showControls
	controlsLabel.Text = CONTROLS
	local blessed = (player:GetAttribute("Level") or 1) < Config.Beginner.UntilLevel
	blessingLabel.Visible = blessed
end

function Guide.Start()
	if not Config.Beginner.ShowGuide then
		return
	end
	local gui = Ui.screen("Guide", 9)
	card = Ui.new("Frame", {
		Position = UDim2.new(0, 20, 0, 20),
		Size = UDim2.new(0, 330, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(255, 220, 140), 1, 0.6), Ui.padding(10), Ui.list(4) })
	Ui.label("BISCUIT'S TIP  (H to hide)", { Size = UDim2.new(1, 0, 0, 14), Font = T.Bold, TextSize = 11, TextColor3 = Color3.fromRGB(255, 220, 140), LayoutOrder = 1, Parent = card })
	tipLabel = Ui.label("", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 13, LayoutOrder = 2, Parent = card })
	controlsLabel = Ui.label("", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 11, TextColor3 = T.Muted, LayoutOrder = 3, Parent = card })
	blessingLabel = Ui.label(
		string.format("Beginner's Blessing: you take %d%% less damage until level %d.", math.floor((1 - Config.Beginner.DamageTaken) * 100 + 0.5), Config.Beginner.UntilLevel),
		{ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 11, TextColor3 = T.Good, LayoutOrder = 4, Parent = card }
	)

	ContextActionService:BindAction("ShadowfallGuide", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin or player:GetAttribute("Act") ~= 2 then
			return Enum.ContextActionResult.Pass
		end
		hidden = not hidden
		refresh()
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.H)

	ClientState.Changed:Connect(refresh)
	for _, name in { "Act", "Level", "Essence", "Tokens", "CanAscend" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	-- Cheap periodic refresh for things that don't fire a signal (cutscenes, build mode, the
	-- controls timer).
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)
	refresh()
end

return Guide
