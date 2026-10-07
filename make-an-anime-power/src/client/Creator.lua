-- The Power Creator window. Three tabs:
--   My Powers  - saved powers: equip, edit or delete them
--   Templates  - the anime template list; picking one starts a new power
--   Edit Power - change everything about a power and build its abilities

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Elements = require(Shared.Elements)
local AbilityTypes = require(Shared.AbilityTypes)
local Templates = require(Shared.Templates)
local PowerValidator = require(Shared.PowerValidator)
local UIKit = require(script.Parent.UIKit)

local Theme = UIKit.Theme

local Creator = {}
Creator.__index = Creator

local STAT_INFO = {
	strength = { "Strength", string.format("+%d%% damage per point", Config.DamagePerStrength * 100) },
	defense = { "Defense", string.format("+%d max health per point", Config.HealthPerDefense) },
	speed = { "Speed", string.format("+%.1f walk speed per point", Config.WalkSpeedPerSpeed) },
	energy = { "Energy", string.format("+%d max energy and faster regen per point", Config.EnergyPerPoint) },
}

-- How to show each computed ability number in the preview
local STAT_FORMATS = {
	{ "damage", "Damage", "%.0f" },
	{ "count", "Count", "%.0f" },
	{ "hits", "Hits", "%.0f" },
	{ "radius", "Radius", "%.1f" },
	{ "width", "Width", "%.1f" },
	{ "area", "Area", "%.0f" },
	{ "reach", "Reach", "%.1f" },
	{ "range", "Range", "%.0f" },
	{ "distance", "Distance", "%.0f" },
	{ "speed", "Speed", "%.0f" },
	{ "knockback", "Knockback", "%.0f" },
	{ "absorb", "Blocks", "%.0f damage" },
	{ "heal", "Heals", "%.0f HP" },
	{ "damageMultiplier", "Damage boost", "x%.2f" },
	{ "walkSpeedBonus", "Speed boost", "+%.0f" },
	{ "duration", "Lasts", "%.1fs" },
}

local EXTRA_COLORS = {
	{ 255, 255, 255 },
	{ 255, 120, 200 },
	{ 255, 150, 60 },
	{ 40, 40, 50 },
}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function toRGB(color: Color3)
	return {
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5),
	}
end

----------------------------------------------------------------------
-- Small widgets
----------------------------------------------------------------------

local function row(parent: Instance, height: number, order: number): Frame
	return UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order,
		Parent = parent,
	})
end

local function heading(parent: Instance, text: string, order: number)
	return UIKit.label(text, {
		Font = Theme.FontBold,
		TextColor3 = Theme.Accent,
		TextSize = 16,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function note(parent: Instance, text: string, order: number)
	return UIKit.label(text, {
		TextColor3 = Theme.Muted,
		TextSize = 13,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = order,
		Parent = parent,
	})
end

-- "Label   <  value  >" for picking from a list
local function cycler(
	parent: Instance,
	labelText: string,
	list: { string },
	current: string,
	display: ((string) -> string)?,
	onChange: (string) -> (),
	order: number
)
	local frame = row(parent, 32, order)
	UIKit.label(labelText, { Size = UDim2.new(0.32, 0, 1, 0), Parent = frame })
	local index = table.find(list, current) or 1
	local function step(delta: number)
		index = (index - 1 + delta) % #list + 1
		onChange(list[index])
	end
	UIKit.button("<", {
		Position = UDim2.new(0.32, 0, 0, 0),
		Size = UDim2.new(0, 32, 1, 0),
		Parent = frame,
	}, function()
		step(-1)
	end)
	UIKit.label(display and display(current) or current, {
		Position = UDim2.new(0.32, 36, 0, 0),
		Size = UDim2.new(0.68, -72, 1, 0),
		Font = Theme.FontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		Parent = frame,
	})
	UIKit.button(">", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 32, 1, 0),
		Parent = frame,
	}, function()
		step(1)
	end)
	return frame
end

-- "Label   -  [bar] value  +" for numbers
local function stepper(
	parent: Instance,
	labelText: string,
	value: number,
	max: number,
	canAdd: boolean,
	onChange: (number) -> (),
	order: number
)
	local frame = row(parent, 30, order)
	UIKit.label(labelText, {
		Size = UDim2.new(0.38, 0, 1, 0),
		TextScaled = true,
		Parent = frame,
	})
	UIKit.button("-", {
		Position = UDim2.new(0.38, 0, 0, 0),
		Size = UDim2.new(0, 30, 1, 0),
		Parent = frame,
	}, function()
		onChange(value - 1)
	end)
	local bar = UIKit.new("Frame", {
		Position = UDim2.new(0.38, 36, 0.5, -7),
		Size = UDim2.new(0.62, -108, 0, 14),
		BackgroundColor3 = Theme.Background,
		Parent = frame,
	})
	UIKit.corner(bar, 4)
	local fill = UIKit.new("Frame", {
		Size = UDim2.fromScale(value / max, 1),
		BackgroundColor3 = Theme.Accent,
		Parent = bar,
	})
	UIKit.corner(fill, 4)
	UIKit.label(tostring(value), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -36, 0, 0),
		Size = UDim2.new(0, 30, 1, 0),
		Font = Theme.FontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	local plus = UIKit.button("+", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 30, 1, 0),
		Parent = frame,
	}, function()
		if canAdd then
			onChange(value + 1)
		end
	end)
	if not canAdd then
		plus.BackgroundTransparency = 0.6
	end
	return frame
end

local function scrolling(parent: Instance, props: { [string]: any }): ScrollingFrame
	local frame = UIKit.new("ScrollingFrame", {
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Muted,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
	for key, value in props do
		frame[key] = value
	end
	UIKit.corner(frame, 8)
	UIKit.padding(frame, 10)
	return frame
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------

export type Api = {
	save: (index: number?, power: any) -> any,
	delete: (index: number) -> any,
	equip: (index: number) -> any,
	notify: (text: string) -> (),
}

function Creator.new(screenGui: ScreenGui, api: Api)
	local self = setmetatable({}, Creator)
	self.api = api
	self.data = { powers = {}, equipped = 0, canSave = true }
	self.draft = nil
	self.draftIndex = nil :: number?
	self.editingAbility = nil :: number?
	self.tab = "Templates"
	self.saving = false
	self.confirmDelete = nil :: number?

	local window = UIKit.new("Frame", {
		Name = "PowerCreator",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.9),
		BackgroundColor3 = Theme.Background,
		Visible = false,
		Parent = screenGui,
	})
	UIKit.corner(window, 12)
	UIKit.stroke(window, Theme.Accent, 2)
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(900, 600), Parent = window })
	self.window = window

	UIKit.label("MAKE AN ANIME POWER", {
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -70, 0, 32),
		Font = Theme.FontBold,
		TextSize = 22,
		TextColor3 = Theme.Accent,
		Parent = window,
	})
	UIKit.button("X", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Theme.Danger,
		Parent = window,
	}, function()
		self:close()
	end)

	-- Tabs
	local tabBar = UIKit.new("Frame", {
		Position = UDim2.fromOffset(10, 42),
		Size = UDim2.new(1, -20, 0, 32),
		BackgroundTransparency = 1,
		Parent = window,
	})
	UIKit.list(tabBar, 6, true)
	self.tabButtons = {}
	for i, tab in { { "MyPowers", "My Powers" }, { "Templates", "Anime Templates" }, { "Edit", "Edit Power" } } do
		self.tabButtons[tab[1]] = UIKit.button(tab[2], {
			Size = UDim2.new(1 / 3, -4, 1, 0),
			LayoutOrder = i,
			Parent = tabBar,
		}, function()
			self:showTab(tab[1])
		end)
	end

	-- Pages
	local content = UIKit.new("Frame", {
		Position = UDim2.fromOffset(10, 82),
		Size = UDim2.new(1, -20, 1, -92),
		BackgroundTransparency = 1,
		Parent = window,
	})

	self.myPowersPage = scrolling(content, { Size = UDim2.fromScale(1, 1) })
	UIKit.list(self.myPowersPage, 8)

	self.templatesPage = scrolling(content, { Size = UDim2.fromScale(1, 1) })
	UIKit.new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -5, 0, 92),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.templatesPage,
	})

	self.editPage = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content })
	self.leftColumn = scrolling(self.editPage, { Size = UDim2.new(0.5, -5, 1, -46) })
	UIKit.list(self.leftColumn, 6)
	self.rightColumn = scrolling(self.editPage, {
		Position = UDim2.new(0.5, 5, 0, 0),
		Size = UDim2.new(0.5, -5, 1, -46),
	})
	UIKit.list(self.rightColumn, 6)

	local footer = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = self.editPage,
	})
	self.statusLabel = UIKit.label("", {
		Size = UDim2.new(1, -200, 1, 0),
		TextWrapped = true,
		TextSize = 14,
		Parent = footer,
	})
	self.saveButton = UIKit.button("SAVE & EQUIP", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 190, 1, 0),
		BackgroundColor3 = Theme.Good,
		TextColor3 = Theme.Background,
		TextSize = 17,
		Parent = footer,
	}, function()
		self:save()
	end)

	self:_renderTemplates()
	self:showTab("Templates")
	return self
end

function Creator:isOpen(): boolean
	return self.window.Visible
end

function Creator:open(tab: string?)
	self.window.Visible = true
	self:showTab(tab or self.tab)
end

function Creator:close()
	self.window.Visible = false
end

function Creator:toggle()
	if self:isOpen() then
		self:close()
	else
		self:open()
	end
end

function Creator:setData(data)
	self.data = data
	if self.tab == "MyPowers" then
		self:_renderMyPowers()
	end
end

function Creator:showTab(tab: string)
	if tab == "Edit" and not self.draft then
		self:_startDraft(Templates.makePower("Blank"), nil)
	end
	self.tab = tab
	self.myPowersPage.Visible = tab == "MyPowers"
	self.templatesPage.Visible = tab == "Templates"
	self.editPage.Visible = tab == "Edit"
	for name, button in self.tabButtons do
		button.BackgroundColor3 = name == tab and Theme.Accent or Theme.PanelLight
		button.TextColor3 = name == tab and Theme.Background or Theme.Text
	end
	if tab == "MyPowers" then
		self:_renderMyPowers()
	elseif tab == "Edit" then
		self:_renderEdit()
	end
end

function Creator:_startDraft(power, index: number?)
	self.draft = power
	self.draftIndex = index
	self.editingAbility = nil
	self.statusLabel.Text = ""
end

function Creator:_setStatus(text: string, good: boolean)
	self.statusLabel.Text = text
	self.statusLabel.TextColor3 = good and Theme.Good or Theme.Danger
end

----------------------------------------------------------------------
-- My Powers tab
----------------------------------------------------------------------

function Creator:_renderMyPowers()
	local page = self.myPowersPage
	UIKit.clear(page)
	local powers = self.data.powers

	heading(page, string.format("Your powers (%d/%d)", #powers, Config.MaxSavedPowers), 0)
	if not self.data.canSave then
		note(page, "Saving isn't available in this server, so powers are kept only until you leave.", 1)
	end
	if #powers == 0 then
		note(page, "You haven't made a power yet. Pick an anime template to start, then make it your own!", 2)
	end

	for i, power in powers do
		local color = PowerValidator.colorOf(power)
		local card = UIKit.new("Frame", {
			Size = UDim2.new(1, 0, 0, 58),
			BackgroundColor3 = Theme.PanelLight,
			LayoutOrder = 10 + i,
			Parent = page,
		})
		UIKit.corner(card, 8)
		UIKit.stroke(card, color, i == self.data.equipped and 3 or 1)
		local strip = UIKit.new("Frame", { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = color, Parent = card })
		UIKit.corner(strip, 4)

		UIKit.label(power.name, {
			Position = UDim2.fromOffset(18, 6),
			Size = UDim2.new(1, -300, 0, 24),
			Font = Theme.FontBold,
			TextSize = 18,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		local names = {}
		for _, ability in power.abilities do
			table.insert(names, ability.name)
		end
		UIKit.label(power.element .. "  |  " .. table.concat(names, ", "), {
			Position = UDim2.fromOffset(18, 30),
			Size = UDim2.new(1, -300, 0, 20),
			TextColor3 = Theme.Muted,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})

		local buttons = UIKit.new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(276, 34),
			BackgroundTransparency = 1,
			Parent = card,
		})
		local layout = UIKit.list(buttons, 6, true)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right

		local equipped = i == self.data.equipped
		UIKit.button(equipped and "EQUIPPED" or "EQUIP", {
			Size = UDim2.fromOffset(96, 34),
			BackgroundColor3 = equipped and Theme.Good or Theme.Accent,
			TextColor3 = Theme.Background,
			LayoutOrder = 1,
			Parent = buttons,
		}, function()
			if not equipped then
				local result = self.api.equip(i)
				if result then
					self.api.notify(result.message)
				end
			end
		end)
		UIKit.button("EDIT", { Size = UDim2.fromOffset(80, 34), LayoutOrder = 2, Parent = buttons }, function()
			self:_startDraft(deepCopy(power), i)
			self:showTab("Edit")
		end)
		local confirming = self.confirmDelete == i
		UIKit.button(confirming and "SURE?" or "DELETE", {
			Size = UDim2.fromOffset(84, 34),
			BackgroundColor3 = Theme.Danger,
			LayoutOrder = 3,
			Parent = buttons,
		}, function()
			if self.confirmDelete == i then
				self.confirmDelete = nil
				local result = self.api.delete(i)
				if result then
					self.api.notify(result.message)
				end
				if self.draftIndex == i then
					self.draft = nil
					self.draftIndex = nil
				elseif self.draftIndex and self.draftIndex > i then
					self.draftIndex -= 1 -- the list shifted up
				end
			else
				self.confirmDelete = i
			end
			self:_renderMyPowers()
		end)
	end

	if #powers < Config.MaxSavedPowers then
		UIKit.button("+ NEW POWER", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Theme.Accent,
			TextColor3 = Theme.Background,
			LayoutOrder = 100,
			Parent = page,
		}, function()
			self:showTab("Templates")
		end)
	end
end

----------------------------------------------------------------------
-- Templates tab
----------------------------------------------------------------------

function Creator:_renderTemplates()
	local page = self.templatesPage
	for i, template in Templates.List do
		local power = template.power
		local color = Color3.fromRGB(power.color[1], power.color[2], power.color[3])
		local card = UIKit.button("", {
			BackgroundColor3 = Theme.PanelLight,
			LayoutOrder = i,
			Parent = page,
		}, function()
			self:_startDraft(Templates.makePower(template.id), nil)
			self:showTab("Edit")
			self:_setStatus("Template loaded. Change anything you like, then press Save & Equip.", true)
		end)
		UIKit.stroke(card, color, 2)
		UIKit.label(template.name, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 0, 24),
			Font = Theme.FontBold,
			TextSize = 18,
			TextColor3 = color,
			TextStrokeTransparency = 0.6,
			Parent = card,
		})
		UIKit.label(template.description, {
			Position = UDim2.fromOffset(12, 30),
			Size = UDim2.new(1, -24, 0, 34),
			TextSize = 13,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = card,
		})
		local names = {}
		for _, ability in power.abilities do
			table.insert(names, ability.name)
		end
		UIKit.label(power.element .. "  |  " .. table.concat(names, ", "), {
			Position = UDim2.new(0, 12, 1, -24),
			Size = UDim2.new(1, -24, 0, 18),
			TextSize = 12,
			TextColor3 = Theme.Muted,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
	end
end

----------------------------------------------------------------------
-- Edit tab
----------------------------------------------------------------------

function Creator:_renderEdit()
	self:_renderLeft()
	self:_renderRight()
	self.saveButton.Text = self.draftIndex and "SAVE & EQUIP" or "SAVE NEW POWER"
end

function Creator:_renderLeft()
	local column = self.leftColumn
	local draft = self.draft
	UIKit.clear(column)

	heading(column, "Power Name", 1)
	local nameBox = UIKit.textBox(draft.name, {
		PlaceholderText = "Name your power",
		LayoutOrder = 2,
		Parent = column,
	})
	nameBox:GetPropertyChangedSignal("Text"):Connect(function()
		local trimmed = PowerValidator.truncate(nameBox.Text)
		if trimmed and trimmed ~= nameBox.Text then
			nameBox.Text = trimmed
		end
		draft.name = nameBox.Text
	end)

	cycler(column, "Element", Elements.Order, draft.element, nil, function(element)
		draft.element = element
		draft.color = toRGB(Elements.get(element).color)
		self:_renderLeft()
	end, 3)
	note(column, Elements.get(draft.element).description, 4)

	heading(column, "Aura Color", 5)
	local swatches = row(column, 0, 6)
	swatches.AutomaticSize = Enum.AutomaticSize.Y
	UIKit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(26, 26),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = swatches,
	})
	local colors = {}
	for _, element in Elements.Order do
		table.insert(colors, toRGB(Elements.get(element).color))
	end
	for _, extra in EXTRA_COLORS do
		table.insert(colors, extra)
	end
	for i, rgb in colors do
		local selected = rgb[1] == draft.color[1] and rgb[2] == draft.color[2] and rgb[3] == draft.color[3]
		local swatch = UIKit.button("", {
			BackgroundColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3]),
			LayoutOrder = i,
			Parent = swatches,
		}, function()
			draft.color = table.clone(rgb)
			self:_renderLeft()
		end)
		UIKit.stroke(swatch, selected and Theme.Text or Theme.Background, selected and 3 or 1)
	end

	cycler(column, "Aura", PowerValidator.Auras, draft.aura, nil, function(aura)
		draft.aura = aura
		self:_renderLeft()
	end, 7)

	local used = PowerValidator.statPointsUsed(draft.stats)
	local left = Config.StatPointBudget - used
	heading(column, string.format("Stats  (%d points left)", left), 8)
	for i, statName in PowerValidator.StatNames do
		local info = STAT_INFO[statName]
		local value = draft.stats[statName]
		stepper(column, info[1], value, Config.StatMax, left > 0 and value < Config.StatMax, function(newValue)
			draft.stats[statName] = math.clamp(newValue, 0, Config.StatMax)
			self:_renderLeft()
			self:_renderRight() -- Strength changes the damage preview
		end, 8 + i * 2 - 1)
		note(column, info[2], 8 + i * 2)
	end
end

function Creator:_renderRight()
	local column = self.rightColumn
	UIKit.clear(column)
	if self.editingAbility and self.draft.abilities[self.editingAbility] then
		self:_renderAbilityEditor(column, self.editingAbility)
		return
	end
	self.editingAbility = nil

	local abilities = self.draft.abilities
	heading(column, string.format("Abilities  (%d/%d)", #abilities, Config.MaxAbilities), 1)

	for i, ability in abilities do
		local def = AbilityTypes.get(ability.type)
		local color = Elements.get(ability.element).color
		local card = UIKit.new("Frame", {
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = Theme.PanelLight,
			LayoutOrder = 1 + i,
			Parent = column,
		})
		UIKit.corner(card, 8)
		UIKit.stroke(card, color, 2)
		UIKit.label(Config.AbilityKeys[i] or "?", {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0, 22, 1, 0),
			Font = Theme.FontBold,
			TextSize = 20,
			TextColor3 = Theme.Accent,
			Parent = card,
		})
		UIKit.label(ability.name, {
			Position = UDim2.fromOffset(34, 5),
			Size = UDim2.new(1, -150, 0, 22),
			Font = Theme.FontBold,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		UIKit.label(def.displayName .. "  |  " .. ability.element, {
			Position = UDim2.fromOffset(34, 26),
			Size = UDim2.new(1, -150, 0, 18),
			TextSize = 13,
			TextColor3 = color,
			Parent = card,
		})
		UIKit.button("EDIT", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -48, 0.5, 0),
			Size = UDim2.fromOffset(64, 32),
			Parent = card,
		}, function()
			self.editingAbility = i
			self:_renderRight()
		end)
		UIKit.button("X", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(34, 32),
			BackgroundColor3 = Theme.Danger,
			Parent = card,
		}, function()
			table.remove(abilities, i)
			self:_renderRight()
		end)
	end

	if #abilities < Config.MaxAbilities then
		UIKit.button("+ ADD ABILITY", {
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = Theme.Accent,
			TextColor3 = Theme.Background,
			LayoutOrder = 50,
			Parent = column,
		}, function()
			table.insert(abilities, {
				name = "New Ability",
				type = "Projectile",
				element = self.draft.element,
				damage = 5,
				size = 5,
				speed = 5,
			})
			self.editingAbility = #abilities
			self:_renderRight()
		end)
	end
	note(
		column,
		"Make any ability you want! Stronger abilities get longer cooldowns and cost more energy. "
			.. "Left click (or the Attack button) is a basic attack every power has.",
		60
	)
end

function Creator:_abilityPreview(ability): string
	local stats = AbilityTypes.computeStats(ability)
	local strength = self.draft.stats.strength or 0
	local elementBonus = Elements.get(ability.element).effects.damage or 1
	local lines = {}
	for _, format in STAT_FORMATS do
		local value = stats[format[1]]
		if value then
			if format[1] == "damage" then
				value *= (1 + strength * Config.DamagePerStrength) * elementBonus
			end
			table.insert(lines, format[2] .. ": " .. string.format(format[3], value))
		end
	end
	table.insert(lines, string.format("Cooldown: %.1fs   Energy: %d", stats.cooldown, stats.energy))
	return table.concat(lines, "\n")
end

function Creator:_renderAbilityEditor(column: Instance, index: number)
	local ability = self.draft.abilities[index]
	local def = AbilityTypes.get(ability.type)

	UIKit.button("< BACK TO ABILITIES", {
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 1,
		Parent = column,
	}, function()
		self.editingAbility = nil
		self:_renderRight()
	end)

	heading(column, string.format("Ability %d  [%s]", index, Config.AbilityKeys[index] or "?"), 2)
	local nameBox = UIKit.textBox(ability.name, {
		PlaceholderText = "Name your attack (you'll shout it!)",
		LayoutOrder = 3,
		Parent = column,
	})
	nameBox:GetPropertyChangedSignal("Text"):Connect(function()
		local trimmed = PowerValidator.truncate(nameBox.Text)
		if trimmed and trimmed ~= nameBox.Text then
			nameBox.Text = trimmed
		end
		ability.name = nameBox.Text
	end)

	cycler(column, "Type", AbilityTypes.Order, ability.type, function(typeName)
		return AbilityTypes.get(typeName).displayName
	end, function(typeName)
		ability.type = typeName
		self:_renderRight()
	end, 4)
	note(column, def.description, 5)

	cycler(column, "Element", Elements.Order, ability.element, nil, function(element)
		ability.element = element
		self:_renderRight()
	end, 6)
	note(column, Elements.get(ability.element).description, 7)

	heading(column, "Levels", 8)
	local order = 9
	for _, key in { "damage", "size", "speed" } do
		local label = def.labels[key]
		if label then
			stepper(
				column,
				label,
				ability[key],
				Config.AbilityLevelMax,
				ability[key] < Config.AbilityLevelMax,
				function(value)
					ability[key] = math.clamp(value, 1, Config.AbilityLevelMax)
					self:_renderRight()
				end,
				order
			)
			order += 1
		end
	end

	heading(column, "Preview", 20)
	local preview = note(column, self:_abilityPreview(ability), 21)
	preview.TextColor3 = Theme.Text
	preview.TextSize = 14
end

----------------------------------------------------------------------
-- Saving
----------------------------------------------------------------------

function Creator:save()
	if self.saving or not self.draft then
		return
	end
	if #self.draft.abilities == 0 then
		self:_setStatus("Add at least one ability first.", false)
		return
	end
	self.saving = true
	self.saveButton.Text = "SAVING..."
	local result = self.api.save(self.draftIndex, self.draft)
	self.saving = false
	self.saveButton.Text = self.draftIndex and "SAVE & EQUIP" or "SAVE NEW POWER"

	if result and result.ok then
		self.draft = nil
		self.draftIndex = nil
		self.editingAbility = nil
		self.api.notify(result.message)
		self:close()
		self.tab = "MyPowers"
	else
		self:_setStatus(result and result.message or "Couldn't save. Try again.", false)
	end
end

return Creator
