-- The class picker: Heroes / Villains tabs, a grid of class cards, and a
-- details panel with stats, the ultimate and a CHOOSE button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))

local ClassPicker = {}

local DARK = Color3.fromRGB(20, 16, 28)
local WHITE = Color3.new(1, 1, 1)

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function new(className: string, props, children: { Instance }?)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function corner(radius: number)
	return new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = WHITE,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return new("TextLabel", defaults)
end

local function percent(x: number): string
	return string.format("%d%%", math.floor(x * 100 + 0.5))
end

-- One line of stats for the details panel.
local function statLine(class): string
	local parts = {
		string.format("HP %d", class.MaxHealth),
		string.format("Speed %d", class.WalkSpeed),
		string.format("Damage %d", class.SlashDamage),
		string.format("Reach %d", class.SlashRange),
		string.format("Attack every %.2fs", class.SlashCooldown),
		string.format("Dash every %.1fs", class.DashCooldown),
	}
	if class.Armor > 0 then
		table.insert(parts, "Armor " .. percent(class.Armor))
	end
	if class.Lifesteal > 0 then
		table.insert(parts, "Lifesteal " .. percent(class.Lifesteal))
	end
	if class.StyleGain > 1 then
		table.insert(parts, "Style +" .. percent(class.StyleGain - 1))
	end
	return table.concat(parts, "   ")
end

function ClassPicker.new(playerGui: PlayerGui, onChoose: (string) -> ())
	local self = {}

	local screen = new("ScreenGui", {
		Name = "AuraFarmClassPicker",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Enabled = false,
		Parent = playerGui,
	})
	local panel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.9),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.05,
		Parent = screen,
	}, {
		corner(14),
		new("UISizeConstraint", { MaxSize = Vector2.new(960, 640) }),
		new("UIStroke", { Color = Color3.fromRGB(255, 215, 110), Thickness = 2 }),
	})

	label({
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -80, 0, 36),
		Font = Enum.Font.GothamBlack,
		TextSize = 28,
		Text = "CHOOSE YOUR PATH",
		Parent = panel,
	})
	local closeButton = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Color3.fromRGB(60, 50, 70),
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = WHITE,
		Text = "X",
		Parent = panel,
	}, { corner(8) })

	-- Side tabs
	local tabs = {}
	local function tab(side: string, x: number)
		local info = Classes.Sides[side]
		tabs[side] = new("TextButton", {
			Position = UDim2.new(x, if x == 0 then 20 else 6, 0, 54),
			Size = UDim2.new(0.5, -26, 0, 40),
			BackgroundColor3 = rgb(info.Color),
			Font = Enum.Font.GothamBlack,
			TextSize = 18,
			TextColor3 = DARK,
			Text = string.format("%s  (%d)", string.upper(info.Name), #Classes[side]),
			Parent = panel,
		}, { corner(8) })
	end
	tab("Good", 0)
	tab("Evil", 0.5)

	-- Class grid
	local grid = new("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 104),
		Size = UDim2.new(1, -40, 1, -260),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(198, 70),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Details panel
	local details = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -14),
		Size = UDim2.new(1, -40, 0, 136),
		BackgroundColor3 = Color3.fromRGB(38, 32, 50),
		Parent = panel,
	}, { corner(10) })
	local nameLabel = label({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -200, 0, 28), Font = Enum.Font.GothamBlack, TextSize = 24, Text = "Pick a class", Parent = details })
	local descLabel = label({ Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -200, 0, 34), TextSize = 14, TextColor3 = Color3.fromRGB(220, 220, 220), Text = "", Parent = details })
	local statsLabel = label({ Position = UDim2.fromOffset(14, 74), Size = UDim2.new(1, -200, 0, 18), TextSize = 12, TextColor3 = Color3.fromRGB(150, 220, 255), Text = "", Parent = details })
	local ultLabel = label({ Position = UDim2.fromOffset(14, 96), Size = UDim2.new(1, -200, 0, 34), TextSize = 13, TextColor3 = Color3.fromRGB(255, 200, 120), Text = "", Parent = details })
	local chooseButton = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(170, 56),
		BackgroundColor3 = Color3.fromRGB(255, 215, 110),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = DARK,
		Text = "CHOOSE",
		Visible = false,
		Parent = details,
	}, { corner(10) })

	local selected = nil
	local currentClassId: string? = nil
	local canClose = false
	local cards: { [string]: TextButton } = {}

	local function selectClass(class)
		selected = class
		for id, card in pairs(cards) do
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = if id == class.Id then 3 else 0
			end
		end
		nameLabel.Text = string.format("%s  -  %s", class.Name, class.Role)
		nameLabel.TextColor3 = rgb(class.Color)
		descLabel.Text = class.Description
		statsLabel.Text = statLine(class)
		local kind = Classes.UltimateKinds[class.Ultimate.Kind]
		ultLabel.Text = string.format("Ultimate: %s (%s). %s.", class.Ultimate.Name, class.Ultimate.Kind, kind.Description)
		chooseButton.Visible = true
		chooseButton.Text = if class.Id == currentClassId then "CURRENT" else "CHOOSE"
	end

	local function showSide(side: string)
		for _, card in pairs(cards) do
			card:Destroy()
		end
		table.clear(cards)
		for name, button in pairs(tabs) do
			button.BackgroundTransparency = if name == side then 0 else 0.6
		end
		for i, class in ipairs(Classes[side]) do
			local card = new("TextButton", {
				BackgroundColor3 = Color3.fromRGB(45, 38, 58),
				AutoButtonColor = true,
				Text = "",
				LayoutOrder = i,
				Parent = grid,
			}, {
				corner(8),
				new("UIStroke", { Color = rgb(class.Color), Thickness = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				new("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = rgb(class.Color), BorderSizePixel = 0 }),
			})
			label({ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -20, 0, 20), Font = Enum.Font.GothamBlack, TextSize = 15, Text = class.Name, Parent = card })
			label({ Position = UDim2.fromOffset(14, 26), Size = UDim2.new(1, -20, 0, 16), TextSize = 12, TextColor3 = Color3.fromRGB(190, 190, 200), Text = string.format("%s  -  HP %d", class.Role, class.MaxHealth), Parent = card })
			label({ Position = UDim2.fromOffset(14, 44), Size = UDim2.new(1, -20, 0, 16), TextSize = 12, TextColor3 = Color3.fromRGB(255, 200, 120), Text = class.Ultimate.Name, Parent = card })
			card.Activated:Connect(function()
				selectClass(class)
			end)
			cards[class.Id] = card
		end
		grid.CanvasPosition = Vector2.zero
	end

	tabs.Good.Activated:Connect(function()
		showSide("Good")
	end)
	tabs.Evil.Activated:Connect(function()
		showSide("Evil")
	end)
	chooseButton.Activated:Connect(function()
		if selected and selected.Id ~= currentClassId then
			onChoose(selected.Id)
		end
	end)
	closeButton.Activated:Connect(function()
		if canClose then
			screen.Enabled = false
		end
	end)

	-- Opens on the player's current class (or the hero tab).
	function self.open(classId: string?)
		currentClassId = classId
		canClose = classId ~= nil
		closeButton.Visible = canClose
		local class = Classes.get(classId)
		showSide(if class then class.Side else "Good")
		if class then
			selectClass(class)
		else
			selected = nil
			nameLabel.Text = "Pick a class"
			nameLabel.TextColor3 = WHITE
			descLabel.Text = "Heroes fight villains and villains fight heroes. Your own side can't hurt you."
			statsLabel.Text = ""
			ultLabel.Text = ""
			chooseButton.Visible = false
		end
		screen.Enabled = true
	end

	function self.close()
		screen.Enabled = false
	end

	function self.isOpen(): boolean
		return screen.Enabled
	end

	return self
end

return ClassPicker
