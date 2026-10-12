-- The on-screen UI, built in code: aura + rank panel, style meter, boss
-- health bar, aura popups, defeat banner, shout box with a line list, and
-- touch-friendly action buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local AuraMath = require(Shared:WaitForChild("AuraMath"))
local HeroicLines = require(Shared:WaitForChild("HeroicLines"))

local Hud = {}

local GOLD = Color3.fromRGB(255, 215, 110)
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

local function stroke(color: Color3, thickness: number)
	return new("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function text(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.4,
		TextSize = 18,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return new("TextLabel", defaults)
end

local function fadeOut(root: GuiObject, delay: number, duration: number)
	task.delay(delay, function()
		if not root.Parent then
			return
		end
		local info = TweenInfo.new(duration)
		for _, item in ipairs(root:GetDescendants()) do
			if item:IsA("TextLabel") then
				TweenService:Create(item, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end
		if root:IsA("TextLabel") then
			TweenService:Create(root, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		if root.BackgroundTransparency < 1 then
			TweenService:Create(root, info, { BackgroundTransparency = 1 }):Play()
		end
		task.wait(duration)
		root:Destroy()
	end)
end

function Hud.new(
	playerGui: PlayerGui,
	callbacks: { onShout: (string) -> (), onAction: (string) -> (), onClassButton: () -> () }
)
	local self = {}
	local side: string? = nil -- "Good" / "Evil" / nil (undecided)
	local currentAura = 0
	local currentStyle = 0
	local ultimateName = ""

	local screen = new("ScreenGui", {
		Name = "AuraFarmHud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	-------------------------------------------------------------------------
	-- Aura panel + style meter (bottom centre)
	-------------------------------------------------------------------------
	local panel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(300, 118),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.25,
		Parent = screen,
	}, { corner(10), stroke(GOLD, 1.5) })

	local styleLetter = text({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.fromOffset(60, 44),
		TextSize = 40,
		Text = "D",
		TextColor3 = Color3.fromRGB(160, 160, 160),
		Parent = panel,
	})
	text({
		Position = UDim2.fromOffset(72, 6),
		Size = UDim2.fromOffset(150, 16),
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "STYLE",
		Parent = panel,
	})
	local styleBack = new("Frame", {
		Position = UDim2.fromOffset(72, 24),
		Size = UDim2.fromOffset(216, 10),
		BackgroundColor3 = Color3.fromRGB(50, 45, 60),
		BorderSizePixel = 0,
		Parent = panel,
	}, { corner(5) })
	local styleFill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Parent = styleBack,
	}, { corner(5) })
	local ultReady = text({
		Position = UDim2.fromOffset(72, 36),
		Size = UDim2.fromOffset(216, 14),
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 120, 120),
		Text = "",
		Parent = panel,
	})

	local auraLabel = text({
		Position = UDim2.fromOffset(10, 52),
		Size = UDim2.fromOffset(280, 28),
		TextSize = 26,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0 AURA",
		Parent = panel,
	})
	local rankLabel = text({
		Position = UDim2.fromOffset(10, 80),
		Size = UDim2.fromOffset(280, 18),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = Config.Ranks[1].Name,
		Parent = panel,
	})
	local rankBack = new("Frame", {
		Position = UDim2.fromOffset(10, 102),
		Size = UDim2.fromOffset(280, 6),
		BackgroundColor3 = Color3.fromRGB(50, 45, 60),
		BorderSizePixel = 0,
		Parent = panel,
	}, { corner(3) })
	local rankFill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = rankBack,
	}, { corner(3) })

	function self.setAura(aura: number)
		currentAura = aura
		local rank, _, nextRank = AuraMath.getRank(aura, Config.Ranks)
		local name = AuraMath.rankName(rank, side)
		auraLabel.Text = string.format("%d AURA", aura)
		rankLabel.Text = if nextRank
			then string.format("%s   (next: %s at %d)", name, AuraMath.rankName(nextRank, side), nextRank.Min)
			else name .. "   (max rank)"
		rankLabel.TextColor3 = rgb(rank.Color)
		rankFill.BackgroundColor3 = rgb(rank.Color)
		rankFill.Size = UDim2.fromScale(AuraMath.rankProgress(aura, Config.Ranks), 1)
	end

	local STYLE_COLORS = {
		D = Color3.fromRGB(160, 160, 160),
		C = Color3.fromRGB(120, 200, 255),
		B = Color3.fromRGB(90, 255, 160),
		A = Color3.fromRGB(255, 230, 80),
		S = Color3.fromRGB(255, 120, 40),
		SSS = Color3.fromRGB(255, 60, 200),
	}

	function self.setStyle(style: number)
		currentStyle = style
		local rank = AuraMath.getRank(style, Config.Style.Ranks)
		styleLetter.Text = rank.Name
		styleLetter.TextColor3 = STYLE_COLORS[rank.Name] or WHITE
		styleFill.Size = UDim2.fromScale(style / Config.Style.Max, 1)
		styleFill.BackgroundColor3 = STYLE_COLORS[rank.Name] or GOLD
		ultReady.Text = if style >= Config.Combat.UltimateStyleCost and ultimateName ~= ""
			then string.format("[F] %s READY", string.upper(ultimateName))
			else ""
	end

	-------------------------------------------------------------------------
	-- Boss bar (top centre)
	-------------------------------------------------------------------------
	local bossFrame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(460, 62),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	local bossName = text({ Size = UDim2.new(1, 0, 0, 24), TextSize = 22, Text = "", Parent = bossFrame })
	local bossTitle = text({
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(220, 220, 220),
		Text = "",
		Parent = bossFrame,
	})
	local bossBack = new("Frame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundColor3 = Color3.fromRGB(40, 20, 20),
		BorderSizePixel = 0,
		Parent = bossFrame,
	}, { corner(4), stroke(Color3.fromRGB(0, 0, 0), 1.5) })
	local bossFill = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(220, 45, 45),
		BorderSizePixel = 0,
		Parent = bossBack,
	}, { corner(4) })
	local bossHp = text({
		Size = UDim2.fromScale(1, 1),
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		Text = "",
		ZIndex = 2,
		Parent = bossBack,
	})

	local bossConnections: { RBXScriptConnection } = {}
	function self.setBoss(model: Model?)
		for _, connection in ipairs(bossConnections) do
			connection:Disconnect()
		end
		table.clear(bossConnections)
		bossFrame.Visible = model ~= nil
		if not model then
			return
		end
		local function refresh()
			local health = model:GetAttribute("Health") or 0
			local maxHealth = model:GetAttribute("MaxHealth") or 1
			bossName.Text = model:GetAttribute("DisplayName") or model.Name
			bossTitle.Text = model:GetAttribute("Title") or ""
			bossFill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
			bossFill.BackgroundColor3 = if model:GetAttribute("Enraged")
				then Color3.fromRGB(200, 40, 255)
				else Color3.fromRGB(220, 45, 45)
			bossHp.Text = string.format("%d / %d", health, maxHealth)
		end
		table.insert(bossConnections, model.AttributeChanged:Connect(refresh))
		refresh()
	end

	-------------------------------------------------------------------------
	-- Aura popups (right side)
	-------------------------------------------------------------------------
	local feed = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.42, 0),
		Size = UDim2.fromOffset(340, 320),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	})
	local popupCount = 0

	function self.popup(payload)
		popupCount += 1
		local positive = payload.Amount >= 0
		local entry = new("Frame", {
			Size = UDim2.fromOffset(340, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = DARK,
			BackgroundTransparency = 0.35,
			LayoutOrder = popupCount,
			Parent = feed,
		}, {
			corner(8),
			new("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			}),
			new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		text({
			Size = UDim2.new(1, 0, 0, 26),
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if positive then GOLD else Color3.fromRGB(255, 80, 80),
			Text = string.format("%s%d AURA", if positive then "+" else "", payload.Amount),
			LayoutOrder = 1,
			Parent = entry,
		})
		if payload.Title ~= "" then
			text({
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextSize = 15,
				TextWrapped = true,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = payload.Title,
				LayoutOrder = 2,
				Parent = entry,
			})
		end
		for i, tag in ipairs(payload.Tags) do
			text({
				Size = UDim2.new(1, 0, 0, 16),
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Color3.fromRGB(150, 220, 255),
				Text = tag,
				LayoutOrder = 2 + i,
				Parent = entry,
			})
		end
		fadeOut(entry, 3.5, 0.6)
	end

	-------------------------------------------------------------------------
	-- Big centre banner (boss defeated / rank up) and small announcements
	-------------------------------------------------------------------------
	local currentBanner: Frame? = nil

	function self.banner(title: string, lines: { string }, total: number?, color: Color3)
		if currentBanner then
			currentBanner:Destroy()
		end
		local frame = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.36),
			Size = UDim2.fromOffset(520, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = DARK,
			BackgroundTransparency = 0.2,
			Parent = screen,
		}, {
			corner(12),
			stroke(color, 2),
			new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }),
			new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		})
		currentBanner = frame
		text({ Size = UDim2.new(1, 0, 0, 40), TextSize = 34, TextColor3 = color, Text = title, LayoutOrder = 0, Parent = frame })
		for i, line in ipairs(lines) do
			text({
				Size = UDim2.new(1, 0, 0, 22),
				TextSize = 17,
				Font = Enum.Font.GothamBold,
				Text = line,
				LayoutOrder = i,
				Parent = frame,
			})
		end
		if total then
			text({
				Size = UDim2.new(1, 0, 0, 44),
				TextSize = 36,
				TextColor3 = GOLD,
				Text = string.format("+%d AURA FARMED", total),
				LayoutOrder = #lines + 1,
				Parent = frame,
			})
		end
		fadeOut(frame, 5.5, 0.8)
	end

	local announceList = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.fromOffset(600, 90),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
	local announceCount = 0

	function self.announce(message: string, color: Color3?)
		announceCount += 1
		local label = text({
			Size = UDim2.new(1, 0, 0, 24),
			TextSize = 18,
			TextColor3 = color or WHITE,
			Text = message,
			LayoutOrder = announceCount,
			Parent = announceList,
		})
		local labels = {}
		for _, child in ipairs(announceList:GetChildren()) do
			if child:IsA("TextLabel") then
				table.insert(labels, child)
			end
		end
		if #labels > 3 then
			table.sort(labels, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			labels[1]:Destroy()
		end
		fadeOut(label, 4, 0.6)
	end

	-------------------------------------------------------------------------
	-- Shout box + heroic line list (left side)
	-------------------------------------------------------------------------
	local shoutFrame = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.62, 0),
		Size = UDim2.fromOffset(392, 40),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.25,
		Parent = screen,
	}, { corner(8), stroke(GOLD, 1) })
	local box = new("TextBox", {
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.fromOffset(196, 32),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamBold,
		PlaceholderText = "Say something heroic...",
		PlaceholderColor3 = Color3.fromRGB(150, 140, 160),
		Text = "",
		TextColor3 = WHITE,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = shoutFrame,
	})
	local function button(label: string, position: UDim2, size: UDim2, color: Color3, parent: Instance)
		return new("TextButton", {
			Position = position,
			Size = size,
			BackgroundColor3 = color,
			Font = Enum.Font.GothamBlack,
			Text = label,
			TextColor3 = DARK,
			TextSize = 13,
			AutoButtonColor = true,
			Parent = parent,
		}, { corner(6) })
	end
	local shoutButton = button("SHOUT", UDim2.fromOffset(208, 5), UDim2.fromOffset(62, 30), GOLD, shoutFrame)
	local linesButton = button("LINES", UDim2.fromOffset(274, 5), UDim2.fromOffset(50, 30), Color3.fromRGB(150, 220, 255), shoutFrame)
	local classButton = button("CLASS", UDim2.fromOffset(328, 5), UDim2.fromOffset(58, 30), Color3.fromRGB(255, 140, 140), shoutFrame)
	classButton.Activated:Connect(callbacks.onClassButton)

	local function submit()
		local message = box.Text
		if string.match(message, "%S") then
			callbacks.onShout(message)
		end
		box.Text = ""
	end
	shoutButton.Activated:Connect(submit)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)

	local CONDITION_HINTS = {
		FoeLow = "enemy under 25% HP",
		LowHealth = "you under 30% HP",
		AfterDodge = "right after a perfect dodge",
		AfterHit = "right after taking a hit",
		AfterKill = "right after a takedown",
		NoFight = "before a fight",
	}
	local list = new("ScrollingFrame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(0, -6),
		Size = UDim2.fromOffset(392, 260),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = shoutFrame,
	}, {
		corner(8),
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
	})
	text({
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 12,
		TextWrapped = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(200, 200, 200),
		Text = "Tap a line to load it. x2 in a fight. Saying the same line twice in 30s costs aura!",
		LayoutOrder = 0,
		Parent = list,
	})
	local function buildLines()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local lines = HeroicLines.forSide(Config, side)
		local accent = if side == "Evil" then "#FF7878" else "#FFD76E"
		for i, line in ipairs(lines) do
			local hint = if line.Condition
				then string.format("  (x%s %s)", tostring(line.Bonus), CONDITION_HINTS[line.Condition] or "")
				else ""
			local entry = new("TextButton", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Color3.fromRGB(45, 38, 58),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = WHITE,
				RichText = true,
				Text = string.format('<font color="%s">+%d</font>  %s<font color="#96DCFF">%s</font>', accent, line.Aura, line.Text, hint),
				LayoutOrder = i,
				Parent = list,
			}, { corner(6), new("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}) })
			entry.Activated:Connect(function()
				box.Text = line.Text
				list.Visible = false
			end)
		end
	end
	buildLines()

	-- Switch rank names, line list and ultimate label to a class (nil = undecided).
	function self.setClass(class)
		side = if class then class.Side else nil
		ultimateName = if class then class.Ultimate.Name else ""
		box.PlaceholderText = if side == "Evil" then "Say something villainous..." else "Say something heroic..."
		buildLines()
		self.setAura(currentAura)
		self.setStyle(currentStyle)
	end

	linesButton.Activated:Connect(function()
		list.Visible = not list.Visible
	end)

	-------------------------------------------------------------------------
	-- Action buttons (right side, above the mobile jump button)
	-------------------------------------------------------------------------
	local actions = new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -150),
		Size = UDim2.fromOffset(110, 3 * 46),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }) })
	local cooldownBars = {}
	local ACTIONS = {
		{ Name = "Slash", Label = "SLASH [Click]", Color = Color3.fromRGB(210, 235, 255) },
		{ Name = "Dash", Label = "DASH [Q]", Color = Color3.fromRGB(150, 255, 190) },
		{ Name = "Ultimate", Label = "ULT [F]", Color = Color3.fromRGB(255, 140, 80) },
	}
	for i, action in ipairs(ACTIONS) do
		local b = new("TextButton", {
			Size = UDim2.fromOffset(110, 40),
			BackgroundColor3 = action.Color,
			Font = Enum.Font.GothamBlack,
			TextSize = 13,
			TextColor3 = DARK,
			Text = action.Label,
			LayoutOrder = i,
			Parent = actions,
		}, { corner(8) })
		cooldownBars[action.Name] = new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Parent = b,
		}, { corner(8) })
		b.Activated:Connect(function()
			callbacks.onAction(action.Name)
		end)
	end

	function self.cooldown(actionName: string, seconds: number)
		local bar = cooldownBars[actionName]
		if not bar then
			return
		end
		bar.Size = UDim2.fromScale(1, 1)
		TweenService:Create(bar, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
	end

	self.setAura(0)
	self.setStyle(0)
	return self
end

return Hud
