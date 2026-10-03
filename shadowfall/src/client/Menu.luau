--!nonstrict
-- The menu (M): Ascension, Feats, Power (reroll + odds), Warp, and a Studio-only Dev tab.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Achievements = require(ReplicatedStorage.Shared.Achievements)
local Areas = require(ReplicatedStorage.Shared.Areas)
local Config = require(ReplicatedStorage.Shared.Config)
local Powers = require(ReplicatedStorage.Shared.Powers)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local RollUI = require(script.Parent.RollUI)
local Hud = require(script.Parent.Hud)
local ClientState = require(script.Parent.ClientState)

local Menu = {}

local T = Ui.Theme
local player = Players.LocalPlayer
local gui, panel, content, tabButtons
local currentTab = "Ascension"
local busy = false

local TABS = { "Ascension", "Feats", "Power", "Warp" }
if Config.EnableStudioDevTools and RunService:IsStudio() then
	table.insert(TABS, "Dev")
end

local function level(): number
	return player:GetAttribute("Level") or 1
end

local function owned(id: string): boolean
	return ClientState.achievements[id] ~= nil
end

local function clear()
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local order = 0
local function add(instance)
	order += 1
	instance.LayoutOrder = order
	instance.Parent = content
	return instance
end

local function heading(text: string)
	return add(Ui.label(text, { Size = UDim2.new(1, 0, 0, 34), Font = T.Title, TextSize = 30 }))
end

local function paragraph(text: string, color: Color3?)
	return add(Ui.label(text, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 15, TextColor3 = color or T.Muted }))
end

local function featRow(achievement)
	local has = owned(achievement.id)
	local row = add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = has and Color3.fromRGB(34, 28, 12) or T.PanelLight }, {
		Ui.corner(8),
		Ui.stroke(has and T.Gold or T.Stroke, 1, has and 0 or 0.4),
		Ui.padding(10),
		Ui.label((has and "* " or "") .. achievement.name, { Size = UDim2.new(1, -90, 0, 20), Font = T.Bold, TextSize = 16, TextColor3 = has and T.Gold or T.Text }),
		Ui.label(achievement.desc, { Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, -90, 0, 18), TextSize = 13, TextColor3 = T.Muted }),
	}))
	local right = has and "EARNED" or ""
	if not has and achievement.goal then
		local progress = ClientState.progress[achievement.id] or 0
		right = string.format("%d / %d", math.min(progress, achievement.goal), achievement.goal)
	end
	Ui.label(right, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 8), Size = UDim2.new(0, 86, 0, 20), Font = T.Bold, TextSize = 14, TextColor3 = has and T.Gold or T.Text, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	return row
end

-- Tabs -------------------------------------------------------------------------------------

local render = {}

function render.Ascension()
	local lv = level()
	heading("Ascension")
	add(Ui.label(string.format("LEVEL %d / %d", lv, Config.MaxLevel), { Size = UDim2.new(1, 0, 0, 22), Font = T.Bold, TextSize = 18, TextColor3 = T.Accent }))
	paragraph("There is no experience in the shadow world and no one hands out quests. You grow stronger only by proving it: earn any one of the feats below, then Ascend.")
	if lv >= Config.MaxLevel then
		paragraph("You have reached the peak. Only the Umbral King, in the Heart of Shadow, is left.", T.Gold)
		return
	end
	local nextLevel = lv + 1
	local unlocks = {}
	local p = Powers.ById[player:GetAttribute("Power") or ""]
	if p and p.moves[nextLevel] then
		table.insert(unlocks, string.format("Move: %s [%s]", p.moves[nextLevel].name, p.moves[nextLevel].key))
	end
	if nextLevel == 5 then
		table.insert(unlocks, "Awakening [G]")
	end
	for _, area in Areas.List do
		if area.level == nextLevel then
			table.insert(unlocks, "Area: " .. area.name)
		end
	end
	table.insert(unlocks, string.format("Damage x%.1f  |  Max health %d", Config.LevelDamage[nextLevel], Config.Act2.BaseMaxHealth + (nextLevel - 1) * Config.Act2.HealthPerLevel))
	add(Ui.label("LEVEL " .. nextLevel .. " UNLOCKS", { Size = UDim2.new(1, 0, 0, 22), Font = T.Bold, TextSize = 14, TextColor3 = T.Muted }))
	for _, line in unlocks do
		add(Ui.label("  -  " .. line, { Size = UDim2.new(1, 0, 0, 20), TextSize = 15 }))
	end
	add(Ui.label("QUALIFYING FEATS (any one)", { Size = UDim2.new(1, 0, 0, 28), Font = T.Bold, TextSize = 14, TextColor3 = T.Muted }))
	for _, achievement in Achievements.QualifiersFor(nextLevel) do
		featRow(achievement)
	end
	local can = player:GetAttribute("CanAscend") == true
	add(Ui.button(can and "ASCEND" or "NOT YET QUALIFIED", {
		Size = UDim2.new(1, 0, 0, 48),
		TextSize = 20,
		Font = T.Title,
		BackgroundColor3 = can and Color3.fromRGB(70, 50, 10) or T.PanelLight,
		TextColor3 = can and T.Gold or T.Muted,
		AutoButtonColor = can,
	}, function()
		if not can or busy then
			return
		end
		busy = true
		local result = Remotes.Request:InvokeServer("Ascend")
		busy = false
		if result and result.ok then
			Hud.Toast("You ascended to level " .. result.level .. "!", T.Gold, 5)
			for _, line in result.unlocks do
				Hud.Toast(line, T.Text, 6)
			end
		elseif result then
			Hud.Toast(result.message or "You can't ascend yet.", T.Bad)
		end
		Menu.Render()
	end))
end

function render.Feats()
	heading("Feats")
	paragraph("Feats are the only path to power here. Gold feats are earned.")
	for lv = 2, Config.MaxLevel do
		add(Ui.label("QUALIFY FOR LEVEL " .. lv, { Size = UDim2.new(1, 0, 0, 26), Font = T.Bold, TextSize = 14, TextColor3 = T.Accent }))
		for _, achievement in Achievements.QualifiersFor(lv) do
			featRow(achievement)
		end
	end
	add(Ui.label("HONOURS", { Size = UDim2.new(1, 0, 0, 26), Font = T.Bold, TextSize = 14, TextColor3 = T.Accent }))
	for _, achievement in Achievements.List do
		if not achievement.qualifies then
			featRow(achievement)
		end
	end
end

local function reroll()
	if busy then
		return
	end
	busy = true
	local result = Remotes.Request:InvokeServer("Reroll")
	if not result or not result.ok then
		busy = false
		Hud.Toast(result and result.message or "The shrine is silent.", T.Bad)
		return
	end
	Menu.Close()
	ClientState.InCutscene = true
	local keepNew = RollUI.Play(result.power, { current = result.current })
	ClientState.InCutscene = false
	local resolved = Remotes.Request:InvokeServer("KeepRoll", keepNew)
	busy = false
	if resolved and resolved.ok then
		Hud.Toast("Your power: " .. tostring(resolved.power), Powers.ById[resolved.power] and Powers.ById[resolved.power].color or T.Text)
	end
end

function render.Power()
	local p = Powers.ById[player:GetAttribute("Power") or ""]
	heading("Power")
	if not p then
		paragraph("Your power hasn't awakened yet.")
		return
	end
	local rarity = Powers.RarityById[p.rarity]
	add(Ui.label(string.upper(p.id) .. "  -  " .. p.rarity, { Size = UDim2.new(1, 0, 0, 28), Font = T.Title, TextSize = 26, TextColor3 = p.color }))
	paragraph(p.blurb)
	add(Ui.label("Passive: " .. p.passive, { Size = UDim2.new(1, 0, 0, 22), Font = T.Bold, TextSize = 15, TextColor3 = rarity.color }))
	for slot, move in p.moves do
		local unlocked = level() >= slot
		add(Ui.label(string.format("[%s]  %s  -  %s, %ss cooldown%s", move.key, move.name, move.kind, tostring(move.cooldown), unlocked and "" or ("   (level " .. slot .. ")")), {
			Size = UDim2.new(1, 0, 0, 20),
			TextSize = 14,
			TextColor3 = unlocked and T.Text or T.Muted,
		}))
	end
	add(Ui.label("[G]  Awakening  -  1.5x damage, half cooldowns" .. (level() >= 5 and "" or "   (level 5)"), { Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextColor3 = level() >= 5 and T.Text or T.Muted }))

	add(Ui.label("THE SHRINE", { Size = UDim2.new(1, 0, 0, 30), Font = T.Bold, TextSize = 14, TextColor3 = T.Accent }))
	local pity = player:GetAttribute("Pity") or 0
	paragraph(string.format("Reroll for %d Essence (you have %d). If you don't like the result, keep your current power. Guaranteed Legendary or better within %d rolls.", Config.Roll.RerollCost, player:GetAttribute("Essence") or 0, math.max(1, Config.Roll.PityAt - pity)))
	add(Ui.button("REROLL  (" .. Config.Roll.RerollCost .. " Essence)", { Size = UDim2.new(1, 0, 0, 44), TextSize = 18, BackgroundColor3 = Color3.fromRGB(40, 30, 64) }, function()
		task.spawn(reroll)
	end))
	add(Ui.label("ODDS", { Size = UDim2.new(1, 0, 0, 26), Font = T.Bold, TextSize = 14, TextColor3 = T.Muted }))
	for _, odds in Powers.Odds() do
		local names = {}
		for _, power in Powers.List do
			if power.rarity == odds.id then
				table.insert(names, power.id)
			end
		end
		add(Ui.label(string.format("%s  %.1f%%   (%s)", odds.id, odds.percent, table.concat(names, ", ")), { Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextColor3 = odds.color }))
	end
end

function render.Warp()
	heading("Warp")
	paragraph("Travel to any area you've unlocked. You can't warp in combat.")
	for _, area in Areas.List do
		local unlocked = level() >= area.level
		local row = add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = T.PanelLight }, {
			Ui.corner(8),
			Ui.stroke(unlocked and area.color or T.Stroke, 1, unlocked and 0.2 or 0.5),
			Ui.padding(10),
			Ui.label(area.name, { Size = UDim2.new(1, -150, 0, 22), Font = T.Title, TextSize = 20, TextColor3 = unlocked and area.color or T.Muted }),
			Ui.label(area.subtitle .. "   |   Level " .. area.level, { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, -150, 0, 18), TextSize = 13, TextColor3 = T.Muted }),
		}))
		Ui.button(unlocked and "Warp" or ("Level " .. area.level), {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 130, 0, 34),
			AutoButtonColor = unlocked,
			TextColor3 = unlocked and T.Text or T.Muted,
			Parent = row,
		}, function()
			if not unlocked then
				return
			end
			local result = Remotes.Request:InvokeServer("Warp", area.id)
			if result and result.ok then
				Menu.Close()
			else
				Hud.Toast(result and result.message or "You can't warp right now.", T.Bad)
			end
		end)
	end
end

function render.Dev()
	heading("Dev (Studio only)")
	paragraph("Shortcuts for testing. These are refused by the server outside Studio.")
	for _, command in { { "Skip Act 1", "SkipAct1" }, { "Grant a qualifying feat", "Qualify" }, { "+1000 Essence", "Essence" }, { "Reset my data", "Reset" } } do
		add(Ui.button(command[1], { Size = UDim2.new(1, 0, 0, 40) }, function()
			local result = Remotes.Request:InvokeServer("Dev", command[2])
			Hud.Toast(result and result.ok and ("Done: " .. command[1]) or (result and result.message or "Failed"), T.Accent)
			Menu.Render()
		end))
	end
end

-- Shell ------------------------------------------------------------------------------------

function Menu.Render()
	if not panel.Visible then
		return
	end
	for name, button in tabButtons do
		button.BackgroundColor3 = name == currentTab and Color3.fromRGB(46, 36, 70) or T.PanelLight
	end
	clear()
	order = 0
	render[currentTab]()
end

function Menu.Open(tab: string?)
	if player:GetAttribute("Act") ~= 2 or ClientState.InCutscene then
		return
	end
	currentTab = tab or currentTab
	panel.Visible = true
	ClientState.MenuOpen = true
	Menu.Render()
end

function Menu.Close()
	panel.Visible = false
	ClientState.MenuOpen = false
end

function Menu.Start()
	gui = Ui.screen("Menu", 20)
	panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.82, 0),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(14),
		Ui.stroke(T.Stroke, 1),
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(820, 600) }),
	})
	local tabs = Ui.new("Frame", { Position = UDim2.new(0, 14, 0, 14), Size = UDim2.new(0, 150, 1, -28), BackgroundTransparency = 1, Parent = panel }, { Ui.list(8) })
	tabButtons = {}
	for index, name in TABS do
		tabButtons[name] = Ui.button(name, { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = index, Parent = tabs }, function()
			currentTab = name
			Menu.Render()
		end)
	end
	Ui.button("Close", { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 99, BackgroundColor3 = Color3.fromRGB(50, 20, 26), Parent = tabs }, Menu.Close)

	content = Ui.new("ScrollingFrame", {
		Position = UDim2.new(0, 178, 0, 14),
		Size = UDim2.new(1, -192, 1, -28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	}, { Ui.list(8), Ui.new("UIPadding", { PaddingRight = UDim.new(0, 12) }) })

	ContextActionService:BindAction("ShadowfallMenu", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin or player:GetAttribute("Act") ~= 2 then
			return Enum.ContextActionResult.Pass
		end
		if panel.Visible then
			Menu.Close()
		else
			Menu.Open(nil)
			if not panel.Visible then
				return Enum.ContextActionResult.Pass
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)

	Hud.MenuRequested = function(tab)
		if panel.Visible and tab == nil then
			Menu.Close()
		else
			Menu.Open(tab)
		end
	end
	ClientState.Changed:Connect(Menu.Render)
	for _, name in { "Level", "Power", "Essence", "CanAscend", "Pity" } do
		player:GetAttributeChangedSignal(name):Connect(Menu.Render)
	end
end

return Menu
