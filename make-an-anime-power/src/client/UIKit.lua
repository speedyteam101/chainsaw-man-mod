-- Small helpers for building UI in code.

local UIKit = {}

UIKit.Theme = {
	Background = Color3.fromRGB(20, 18, 30),
	Panel = Color3.fromRGB(34, 31, 50),
	PanelLight = Color3.fromRGB(50, 46, 72),
	Accent = Color3.fromRGB(255, 196, 60),
	AccentDark = Color3.fromRGB(200, 140, 20),
	Text = Color3.fromRGB(245, 242, 255),
	Muted = Color3.fromRGB(170, 165, 195),
	Danger = Color3.fromRGB(230, 70, 80),
	Good = Color3.fromRGB(90, 210, 120),
	Health = Color3.fromRGB(230, 60, 70),
	Energy = Color3.fromRGB(70, 170, 255),
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBlack,
}

local Theme = UIKit.Theme

-- Creates an instance, sets its properties (Parent last) and returns it.
function UIKit.new(className: string, props: { [string]: any }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIKit.corner(parent: Instance, radius: number?)
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

function UIKit.stroke(parent: Instance, color: Color3?, thickness: number?)
	return UIKit.new("UIStroke", {
		Color = color or Theme.PanelLight,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UIKit.padding(parent: Instance, pixels: number)
	local p = UDim.new(0, pixels)
	return UIKit.new("UIPadding", {
		PaddingTop = p,
		PaddingBottom = p,
		PaddingLeft = p,
		PaddingRight = p,
		Parent = parent,
	})
end

function UIKit.list(parent: Instance, spacing: number?, horizontal: boolean?)
	return UIKit.new("UIListLayout", {
		Padding = UDim.new(0, spacing or 6),
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = horizontal and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end

function UIKit.label(text: string, props: { [string]: any }?)
	local label = UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = text,
		TextColor3 = Theme.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 22),
	})
	if props then
		for key, value in props do
			label[key] = value
		end
	end
	return label
end

function UIKit.button(text: string, props: { [string]: any }?, onClick: (() -> ())?)
	local button = UIKit.new("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = Theme.PanelLight,
		Font = Theme.FontBold,
		Text = text,
		TextColor3 = Theme.Text,
		TextSize = 15,
		Size = UDim2.fromOffset(100, 32),
	})
	UIKit.corner(button, 6)
	if props then
		for key, value in props do
			button[key] = value
		end
	end
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

function UIKit.textBox(text: string, props: { [string]: any }?)
	local box = UIKit.new("TextBox", {
		BackgroundColor3 = Theme.Background,
		ClearTextOnFocus = false,
		Font = Theme.Font,
		Text = text,
		PlaceholderColor3 = Theme.Muted,
		TextColor3 = Theme.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 32),
	})
	UIKit.corner(box, 6)
	UIKit.padding(box, 6)
	if props then
		for key, value in props do
			box[key] = value
		end
	end
	return box
end

function UIKit.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

return UIKit
