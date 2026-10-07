-- The in-game HUD: health and energy bars, the ability hotbar with cooldowns,
-- an Attack button (for touch screens), the Power Creator button and
-- notifications.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Elements = require(Shared.Elements)
local UIKit = require(script.Parent.UIKit)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local HUD = {}
HUD.__index = HUD

local SLOT_SIZE = 74

local function makeBar(parent: Instance, color: Color3, order: number)
	local bar = UIKit.new("Frame", {
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.2,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = order,
		Parent = parent,
	})
	UIKit.corner(bar, 5)
	local fill = UIKit.new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromScale(1, 1),
		Parent = bar,
	})
	UIKit.corner(fill, 5)
	local text = UIKit.label("", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.FontBold,
		TextSize = 13,
		TextStrokeTransparency = 0.5,
		ZIndex = 2,
		Parent = bar,
	})
	return fill, text
end

function HUD.new(screenGui: ScreenGui)
	local self = setmetatable({}, HUD)
	self.slots = {}
	self.cooldownEnds = {}
	self.cooldownLengths = {}
	self.onSlotPressed = nil :: ((number) -> ())?
	self.onAttackPressed = nil :: (() -> ())?
	self.onCreatorPressed = nil :: (() -> ())?

	-- Bottom panel
	local bottom = UIKit.new("Frame", {
		Name = "BottomPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(SLOT_SIZE * 5 + 8 * 4, 70 + SLOT_SIZE),
		BackgroundTransparency = 1,
		Parent = screenGui,
	})
	UIKit.list(bottom, 4)

	self.powerLabel = UIKit.label("No power - press P to make one!", {
		Font = Theme.FontBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		LayoutOrder = 1,
		Parent = bottom,
	})
	self.healthFill, self.healthText = makeBar(bottom, Theme.Health, 2)
	self.energyFill, self.energyText = makeBar(bottom, Theme.Energy, 3)

	local hotbar = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, SLOT_SIZE),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = bottom,
	})
	local hotbarLayout = UIKit.list(hotbar, 8, true)
	hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	for slot = 1, Config.MaxAbilities do
		self.slots[slot] = self:_makeSlot(hotbar, slot)
	end

	local attack = UIKit.button("ATTACK\n(Click)", {
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
		BackgroundColor3 = Theme.Danger,
		TextSize = 13,
		LayoutOrder = Config.MaxAbilities + 1,
		Parent = hotbar,
	}, function()
		if self.onAttackPressed then
			self.onAttackPressed()
		end
	end)
	UIKit.stroke(attack, Color3.new(0, 0, 0), 2)

	-- Power Creator button (top left, below the Roblox menu buttons)
	UIKit.button("MAKE A POWER  [P]", {
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.fromOffset(190, 40),
		BackgroundColor3 = Theme.Accent,
		TextColor3 = Theme.Background,
		TextSize = 16,
		Parent = screenGui,
	}, function()
		if self.onCreatorPressed then
			self.onCreatorPressed()
		end
	end)

	-- Notifications (top middle)
	self.notifications = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.fromOffset(420, 200),
		BackgroundTransparency = 1,
		Parent = screenGui,
	})
	UIKit.list(self.notifications, 4)

	RunService.RenderStepped:Connect(function()
		self:_update()
	end)
	return self
end

function HUD:_makeSlot(parent: Instance, slot: number)
	local button = UIKit.button("", {
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
		BackgroundColor3 = Theme.Panel,
		LayoutOrder = slot,
		ClipsDescendants = true,
		Parent = parent,
	}, function()
		if self.onSlotPressed then
			self.onSlotPressed(slot)
		end
	end)
	local stroke = UIKit.stroke(button, Theme.PanelLight, 2)

	UIKit.label(Config.AbilityKeys[slot] or tostring(slot), {
		Position = UDim2.fromOffset(5, 2),
		Size = UDim2.fromOffset(20, 18),
		Font = Theme.FontBold,
		TextColor3 = Theme.Accent,
		TextSize = 15,
		ZIndex = 3,
		Parent = button,
	})
	local name = UIKit.label("-", {
		Position = UDim2.fromOffset(4, 18),
		Size = UDim2.new(1, -8, 1, -22),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		Font = Theme.FontBold,
		ZIndex = 3,
		Parent = button,
	})
	local overlay = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		ZIndex = 4,
		Parent = button,
	})
	local timer = UIKit.label("", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.FontBold,
		TextSize = 22,
		ZIndex = 5,
		Parent = button,
	})
	return { button = button, stroke = stroke, name = name, overlay = overlay, timer = timer }
end

-- Shows the equipped power (or nil) on the hotbar.
function HUD:setPower(power)
	self.power = power
	if power then
		self.powerLabel.Text = power.name
		self.powerLabel.TextColor3 = Color3.fromRGB(power.color[1], power.color[2], power.color[3])
	else
		self.powerLabel.Text = "No power - press P to make one!"
		self.powerLabel.TextColor3 = Theme.Text
	end
	for slot, ui in self.slots do
		local ability = power and power.abilities[slot]
		ui.name.Text = ability and ability.name or "-"
		ui.stroke.Color = ability and Elements.get(ability.element).color or Theme.PanelLight
		ui.button.Visible = ability ~= nil
	end
end

function HUD:startCooldown(slot: number, seconds: number)
	self.cooldownEnds[slot] = os.clock() + seconds
	self.cooldownLengths[slot] = seconds
end

function HUD:isOnCooldown(slot: number): boolean
	return (self.cooldownEnds[slot] or 0) > os.clock()
end

function HUD:notify(text: string)
	local label = UIKit.label(text, {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Font = Theme.FontBold,
		TextSize = 16,
		Parent = self.notifications,
	})
	UIKit.corner(label, 6)
	local children = self.notifications:GetChildren()
	if #children > 6 then -- 5 labels + the layout
		for _, child in children do
			if child:IsA("TextLabel") and child ~= label then
				child:Destroy()
				break
			end
		end
	end
	task.delay(3, function()
		local fade =
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		label:Destroy()
	end)
end

function HUD:_update()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local max = math.max(humanoid.MaxHealth, 1)
		local health = math.max(humanoid.Health, 0)
		self.healthFill.Size = UDim2.fromScale(health / max, 1)
		self.healthText.Text = string.format("%d / %d", math.ceil(health), math.floor(max))
	end

	local energy = player:GetAttribute("Energy") or 0
	local maxEnergy = player:GetAttribute("MaxEnergy") or Config.BaseEnergy
	self.energyFill.Size = UDim2.fromScale(math.clamp(energy / math.max(maxEnergy, 1), 0, 1), 1)
	self.energyText.Text = string.format("Energy %d / %d", math.floor(energy), math.floor(maxEnergy))

	local now = os.clock()
	for slot, ui in self.slots do
		local remaining = (self.cooldownEnds[slot] or 0) - now
		if remaining > 0 then
			ui.overlay.Size = UDim2.fromScale(1, remaining / math.max(self.cooldownLengths[slot], 0.01))
			ui.timer.Text = remaining >= 10 and string.format("%d", math.ceil(remaining))
				or string.format("%.1f", remaining)
		else
			ui.overlay.Size = UDim2.fromScale(1, 0)
			ui.timer.Text = ""
		end
	end
end

return HUD
