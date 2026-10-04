--!nonstrict
-- The character creator. Shown before the story starts for new players (the server sets the
-- "NeedsLook" attribute and waits), and any time later from the menu's Look tab.
--
-- The preview is built by the same shared Figure module that dresses your real character, so what
-- you see here is what everyone sees in game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Looks = require(ReplicatedStorage.Shared.Looks)
local Figure = require(ReplicatedStorage.Shared.Figure)
local Clans = require(ReplicatedStorage.Shared.Clans)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local ClanUI = require(script.Parent.ClanUI)

local CharacterCreator = {}

local T = Ui.Theme
local player = Players.LocalPlayer
local rng = Random.new()

local gui, root, viewport, camera, dummy, options, saveButton, subtitle
local look = Looks.Default()
local firstTime = false
local busy = false
local spin = 0
local refreshers = {}

-- Preview figure ---------------------------------------------------------------------------

local function buildDummy()
	if dummy then
		dummy:Destroy()
	end
	local spec = Figure.FromLook(look)
	spec.cf = CFrame.new(0, -3, 0)
	spec.name = "Preview"
	dummy = Figure.Build(spec)
	dummy.Parent = viewport
end

local function refresh()
	if look.avatar then
		subtitle.Text = "You'll look like your own Roblox avatar. Pick any option below to design a character instead."
	else
		subtitle.Text = firstTime and "Before the night begins: who are you? You can change this later in the menu (Look tab)."
			or "Change how you look. Saving applies it straight away."
	end
	buildDummy()
	viewport.ImageTransparency = look.avatar and 0.65 or 0
	for _, fn in refreshers do
		fn()
	end
end

-- Option rows ------------------------------------------------------------------------------

local rowOrder = 0
local function section(title: string)
	rowOrder += 1
	Ui.label(title, { Size = UDim2.new(1, 0, 0, 20), Font = T.Bold, TextSize = 14, TextColor3 = T.Muted, LayoutOrder = rowOrder, Parent = options })
end

local function swatchRow(title: string, palette: { Color3 }, field: string)
	section(title)
	rowOrder += 1
	local row = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = rowOrder,
		Parent = options,
	}, { Ui.new("UIGridLayout", { CellSize = UDim2.fromOffset(34, 34), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local strokes = {}
	for i, color in palette do
		local button = Ui.new("TextButton", { Text = "", BackgroundColor3 = color, AutoButtonColor = true, LayoutOrder = i, Parent = row }, { Ui.corner(17) })
		strokes[i] = Ui.stroke(Color3.new(1, 1, 1), 3, 1)
		strokes[i].Parent = button
		button.MouseButton1Click:Connect(function()
			look[field] = i
			look.avatar = false
			refresh()
		end)
	end
	table.insert(refreshers, function()
		for i, stroke in strokes do
			stroke.Transparency = (not look.avatar and look[field] == i) and 0 or 1
		end
	end)
end

local function choiceRow(title: string, names: { string }, field: string)
	section(title)
	rowOrder += 1
	local row = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = rowOrder,
		Parent = options,
	}, { Ui.new("UIGridLayout", { CellSize = UDim2.fromOffset(92, 32), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local buttons = {}
	for i, name in names do
		buttons[i] = Ui.button(name, { TextSize = 14, LayoutOrder = i, Parent = row }, function()
			look[field] = i
			look.avatar = false
			refresh()
		end)
	end
	table.insert(refreshers, function()
		for i, button in buttons do
			local on = not look.avatar and look[field] == i
			button.BackgroundColor3 = on and Color3.fromRGB(60, 44, 100) or T.PanelLight
			button.TextColor3 = on and T.Text or T.Muted
		end
	end)
end

-- Open / close -----------------------------------------------------------------------------

function CharacterCreator.IsOpen(): boolean
	return root ~= nil and root.Visible
end

-- Clan rolling (first time only) --------------------------------------------------------------

local clanBox, clanReel, clanPerks, clanCards, clanRollButton
local clanOptions: { string } = {}
local selectedClan: string? = nil
local freeRolls = 0
local rolling = false

local function renderClan()
	clanBox.Visible = firstTime
	for _, child in clanCards:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for index, id in clanOptions do
		ClanUI.Card(id, id == selectedClan, index, clanCards, function()
			selectedClan = id
			clanReel.Text = string.upper(Clans.ById[id].name) .. "  -  " .. string.upper(Clans.ById[id].rarity)
			clanReel.TextColor3 = Clans.RarityColors[Clans.ById[id].rarity]
			renderClan()
		end)
	end
	clanPerks.Text = ClanUI.Perks(selectedClan)
	clanRollButton.Text = freeRolls > 0 and string.format("ROLL CLAN  (%d free roll%s left)", freeRolls, freeRolls == 1 and "" or "s") or "No free rolls left (reroll later at the shrine)"
	clanRollButton.AutoButtonColor = freeRolls > 0
end

local function rollClan()
	if rolling or freeRolls <= 0 then
		return
	end
	rolling = true
	local result = Remotes.Request:InvokeServer("RollClan")
	if result and result.ok then
		freeRolls = result.free or 0
		ClanUI.Reel(clanReel, result.clan)
		clanOptions = table.clone(result.options or { result.clan })
		selectedClan = result.clan
	else
		clanReel.Text = (result and result.message) or "The bloodline is silent. Try again."
	end
	rolling = false
	renderClan()
end

function CharacterCreator.Open(current, isFirstTime: boolean?)
	firstTime = isFirstTime == true
	if firstTime then
		clanOptions = table.clone(ClientState.clanOptions or {})
		freeRolls = ClientState.clanFreeRolls or 3
		selectedClan = clanOptions[#clanOptions]
		clanReel.Text = selectedClan and string.upper(Clans.ById[selectedClan].name) or "?"
	end
	renderClan()
	look = Looks.Sanitize(current or Looks.Default())
	saveButton.Text = firstTime and "BEGIN" or "SAVE"
	root.Visible = true
	ClientState.CreatorOpen = true
	refresh()
end

local function close()
	root.Visible = false
	ClientState.CreatorOpen = false
end

local function save()
	if busy then
		return
	end
	if rolling then
		return
	end
	busy = true
	saveButton.Text = "..."
	-- Keep the clan they picked (if they rolled none, the server rolls one for them).
	if firstTime and selectedClan then
		Remotes.Request:InvokeServer("ChooseClan", selectedClan)
	end
	local result = Remotes.Request:InvokeServer("SaveLook", look)
	busy = false
	if result and result.ok then
		close()
	else
		subtitle.Text = (result and result.message) or "Couldn't save that. Try again."
		saveButton.Text = firstTime and "BEGIN" or "SAVE"
	end
end

function CharacterCreator.Start()
	gui = Ui.screen("CharacterCreator", 60)
	root = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 7, 11),
		Visible = false,
		Parent = gui,
	})
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -32, 1, -32),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Ui.new("UISizeConstraint", { MaxSize = Vector2.new(900, 640) }) })

	Ui.label("CREATE YOUR CHARACTER", { Size = UDim2.new(1, 0, 0, 40), Font = T.Title, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, Parent = panel })
	subtitle = Ui.label("", { Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 0, 36), TextSize = 14, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = panel })

	-- Left: the preview. Right: the options. On narrow screens the preview shrinks.
	viewport = Ui.new("ViewportFrame", {
		Position = UDim2.new(0, 0, 0, 86),
		Size = UDim2.new(0.4, -8, 1, -150),
		BackgroundColor3 = Color3.fromRGB(18, 16, 24),
		Ambient = Color3.fromRGB(170, 170, 180),
		LightColor = Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		Parent = panel,
	}, { Ui.corner(12), Ui.stroke(T.Stroke, 1, 0.3) })
	camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	options = Ui.new("ScrollingFrame", {
		Position = UDim2.new(0.4, 8, 0, 86),
		Size = UDim2.new(0.6, -8, 1, -150),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	}, { Ui.list(6), Ui.new("UIPadding", { PaddingRight = UDim.new(0, 10) }) })

	-- The clan roller sits at the top of the options (first time only).
	clanBox = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(24, 18, 30),
		LayoutOrder = -10,
		Parent = options,
	}, { Ui.corner(10), Ui.stroke(T.Gold, 1, 0.5), Ui.padding(10), Ui.list(6) })
	Ui.label("YOUR CLAN", { Size = UDim2.new(1, 0, 0, 16), Font = T.Bold, TextSize = 13, TextColor3 = T.Gold, LayoutOrder = 1, Parent = clanBox })
	Ui.label("Your family line gives you perks. Roll up to 3 times for free, then pick the one you want to keep.", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 12, TextColor3 = T.Muted, LayoutOrder = 2, Parent = clanBox })
	clanReel = Ui.label("?", { Size = UDim2.new(1, 0, 0, 30), Font = T.Title, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Parent = clanBox })
	clanCards = Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 4, Parent = clanBox }, {
		Ui.new("UIGridLayout", { CellSize = UDim2.fromOffset(150, 42), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	clanPerks = Ui.label("", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 12, LayoutOrder = 5, Parent = clanBox })
	clanRollButton = Ui.button("ROLL CLAN", { Size = UDim2.new(1, 0, 0, 40), TextSize = 16, BackgroundColor3 = Color3.fromRGB(60, 44, 10), TextColor3 = T.Gold, LayoutOrder = 6, Parent = clanBox }, function()
		task.spawn(rollClan)
	end)

	swatchRow("SKIN", Looks.Skin, "skin")
	swatchRow("EYES", Figure.EyeColors, "eyes")
	local hairNames = {}
	for _, style in Looks.Hair do
		table.insert(hairNames, style.name)
	end
	choiceRow("HAIR", hairNames, "hair")
	swatchRow("HAIR COLOUR", Looks.HairColors, "hairColor")
	choiceRow("OUTFIT", Figure.OutfitNames, "outfit")
	swatchRow("SHIRT / TOP", Looks.Clothes, "shirt")
	section("SLEEVES")
	rowOrder += 1
	local sleeveButton
	sleeveButton = Ui.button("", { Size = UDim2.new(0, 190, 0, 32), TextSize = 14, LayoutOrder = rowOrder, Parent = options }, function()
		look.sleeves = not look.sleeves
		look.avatar = false
		refresh()
	end)
	table.insert(refreshers, function()
		sleeveButton.Text = look.sleeves and "Long sleeves" or "Short sleeves"
	end)
	swatchRow("TROUSERS", Looks.Clothes, "pants")

	-- Bottom bar.
	local bar = Ui.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, Parent = panel }, {
		Ui.list(10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center),
	})
	Ui.button("Random", { Size = UDim2.new(0, 130, 0, 46), LayoutOrder = 1, Parent = bar }, function()
		look = Looks.Random(rng)
		refresh()
	end)
	Ui.button("Use my Roblox avatar", { Size = UDim2.new(0, 210, 0, 46), TextSize = 14, LayoutOrder = 2, Parent = bar }, function()
		look.avatar = true
		refresh()
	end)
	saveButton = Ui.button("BEGIN", { Size = UDim2.new(0, 170, 0, 46), TextSize = 20, BackgroundColor3 = Color3.fromRGB(60, 44, 10), TextColor3 = T.Gold, LayoutOrder = 3, Parent = bar }, function()
		task.spawn(save)
	end)
	local cancel = Ui.button("Cancel", { Size = UDim2.new(0, 110, 0, 46), LayoutOrder = 4, Parent = bar }, close)
	table.insert(refreshers, function()
		cancel.Visible = not firstTime
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not root.Visible then
			return
		end
		spin += dt * 0.6
		local target = Vector3.new(0, 0.3, 0)
		camera.CFrame = CFrame.lookAt(target + Vector3.new(math.sin(spin) * 11, 1.5, -math.cos(spin) * 11), target)
	end)

	local function check()
		if player:GetAttribute("NeedsLook") == true and not CharacterCreator.IsOpen() then
			CharacterCreator.Open(nil, true)
		elseif player:GetAttribute("NeedsLook") ~= true and firstTime and CharacterCreator.IsOpen() then
			close() -- the server gave up waiting and spawned you with the default look
		end
	end
	player:GetAttributeChangedSignal("NeedsLook"):Connect(check)
	check()
end

return CharacterCreator
