--!nonstrict
-- The character creator. Shown before the story starts for new players (the server sets the
-- "NeedsLook" attribute and waits), and any time later from the menu's Look tab.
--
-- The preview is a blocky R6 figure built from plain parts in a ViewportFrame, coloured and given
-- hair by the same shared Looks module the server uses for your real character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Looks = require(ReplicatedStorage.Shared.Looks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local ClientState = require(script.Parent.ClientState)

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

local R6 = {
	{ name = "Torso", size = Vector3.new(2, 2, 1), offset = CFrame.new(0, 0, 0) },
	{ name = "Head", size = Vector3.new(2, 1, 1), offset = CFrame.new(0, 1.5, 0) },
	{ name = "Left Arm", size = Vector3.new(1, 2, 1), offset = CFrame.new(-1.5, 0, 0) },
	{ name = "Right Arm", size = Vector3.new(1, 2, 1), offset = CFrame.new(1.5, 0, 0) },
	{ name = "Left Leg", size = Vector3.new(1, 2, 1), offset = CFrame.new(-0.5, -2, 0) },
	{ name = "Right Leg", size = Vector3.new(1, 2, 1), offset = CFrame.new(0.5, -2, 0) },
}

local function buildDummy()
	if dummy then
		dummy:Destroy()
	end
	dummy = Instance.new("Model")
	dummy.Name = "Preview"
	local colors = Looks.Colors(look)
	local head
	for _, def in R6 do
		local part = Instance.new("Part")
		part.Name = def.name
		part.Size = def.size
		part.CFrame = def.offset
		part.Anchored = true
		part.Color = colors[def.name]
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = dummy
		if def.name == "Head" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
			mesh.Parent = part
			head = part
		end
	end
	-- A simple painted-on face (your real character gets Roblox's default face).
	for _, x in { -0.2, 0.2 } do
		local eye = Instance.new("Part")
		eye.Size = Vector3.new(0.1, 0.18, 0.05)
		eye.CFrame = head.CFrame * CFrame.new(x, 0.08, -0.6)
		eye.Color = Color3.fromRGB(20, 20, 20)
		eye.Anchored = true
		eye.Parent = dummy
	end
	local mouth = Instance.new("Part")
	mouth.Size = Vector3.new(0.34, 0.06, 0.05)
	mouth.CFrame = head.CFrame * CFrame.new(0, -0.2, -0.6)
	mouth.Color = Color3.fromRGB(20, 20, 20)
	mouth.Anchored = true
	mouth.Parent = dummy
	local hair = Looks.BuildHair(head, look)
	if hair then
		for _, part in hair:GetChildren() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		hair.Parent = dummy
	end
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

function CharacterCreator.Open(current, isFirstTime: boolean?)
	firstTime = isFirstTime == true
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
	busy = true
	saveButton.Text = "..."
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

	swatchRow("SKIN", Looks.Skin, "skin")
	local hairNames = {}
	for _, style in Looks.Hair do
		table.insert(hairNames, style.name)
	end
	choiceRow("HAIR", hairNames, "hair")
	swatchRow("HAIR COLOUR", Looks.HairColors, "hairColor")
	swatchRow("SHIRT", Looks.Clothes, "shirt")
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
