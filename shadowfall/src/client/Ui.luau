--!nonstrict
-- Tiny UI toolkit: create instances from property tables, plus the game's visual theme.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Ui = {}

Ui.Theme = {
	Panel = Color3.fromRGB(12, 11, 16),
	PanelLight = Color3.fromRGB(24, 22, 30),
	Stroke = Color3.fromRGB(70, 60, 90),
	Text = Color3.fromRGB(235, 230, 240),
	Muted = Color3.fromRGB(150, 145, 165),
	Accent = Color3.fromRGB(170, 130, 255),
	Good = Color3.fromRGB(110, 230, 140),
	Bad = Color3.fromRGB(255, 80, 90),
	Gold = Color3.fromRGB(255, 200, 90),
	Title = Enum.Font.SpecialElite,
	Body = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Horror = Enum.Font.Creepster,
}

-- Ui.new("Frame", { Size = ..., Parent = ... }, { children })
function Ui.new(className: string, props, children)
	local instance = Instance.new(className)
	for key, value in props or {} do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Ui.corner(radius: number?)
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Ui.stroke(color: Color3?, thickness: number?, transparency: number?)
	return Ui.new("UIStroke", {
		Color = color or Ui.Theme.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(px: number)
	return Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function Ui.list(padding: number?, direction: Enum.FillDirection?, align: Enum.HorizontalAlignment?)
	return Ui.new("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Ui.label(text: string, props)
	local base = {
		BackgroundTransparency = 1,
		Text = text,
		Font = Ui.Theme.Body,
		TextColor3 = Ui.Theme.Text,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
	}
	for key, value in props or {} do
		base[key] = value
	end
	return Ui.new("TextLabel", base)
end

function Ui.button(text: string, props, onClick: () -> ())
	local base = {
		BackgroundColor3 = Ui.Theme.PanelLight,
		Text = text,
		Font = Ui.Theme.Bold,
		TextColor3 = Ui.Theme.Text,
		TextSize = 16,
		AutoButtonColor = true,
		Size = UDim2.new(0, 160, 0, 38),
	}
	for key, value in props or {} do
		base[key] = value
	end
	local button = Ui.new("TextButton", base, { Ui.corner(8), Ui.stroke() })
	button.MouseButton1Click:Connect(onClick)
	return button
end

function Ui.screen(name: string, order: number?)
	local gui = Ui.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = order or 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function Ui.tween(instance: Instance, time: number, props, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- Types `text` into a label one character at a time.
function Ui.typewrite(label: TextLabel, text: string, perChar: number?)
	label.Text = text
	label.MaxVisibleGraphemes = 0
	local total = utf8.len(text) or #text
	for i = 1, total do
		if label.Text ~= text then
			return -- something else replaced the text
		end
		label.MaxVisibleGraphemes = i
		task.wait(perChar or 0.03)
	end
	label.MaxVisibleGraphemes = -1
end

return Ui
