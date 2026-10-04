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
local Materials = require(ReplicatedStorage.Shared.Materials)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Structures = require(ReplicatedStorage.Shared.Structures)
local Townsfolk = require(ReplicatedStorage.Shared.Townsfolk)
local Shops = require(ReplicatedStorage.Shared.Shops)
local Story = require(ReplicatedStorage.Shared.Story)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local RollUI = require(script.Parent.RollUI)
local Hud = require(script.Parent.Hud)
local ClientState = require(script.Parent.ClientState)
local BuildMode = require(script.Parent.BuildMode)
local Cinematic = require(script.Parent.Cinematic)
local CharacterCreator = require(script.Parent.CharacterCreator)
local Passes = require(ReplicatedStorage.Shared.Passes)
local Clans = require(ReplicatedStorage.Shared.Clans)
local ClanUI = require(script.Parent.ClanUI)

local Menu = {}

local T = Ui.Theme
local player = Players.LocalPlayer
local gui, panel, content, tabButtons
local currentTab = "Ascension"
local busy = false

local TABS = { "Ascension", "Feats", "Power", "Clan", "Tokens", "Pack", "Build", "Base", "Journal", "Warp", "Look" }
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

local function reroll(useDie: boolean?)
	if busy then
		return
	end
	busy = true
	local result = Remotes.Request:InvokeServer("Reroll", useDie and "die" or nil)
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
		local p = Powers.ById[resolved.power]
		Hud.Toast("Your power: " .. (p and p.name or tostring(resolved.power)), p and p.color or T.Text)
		if result.vaulted then
			Hud.Toast("Both powers are safe in your Power Vault. Swap any time in the Power tab.", Color3.fromRGB(190, 140, 255), 4)
		end
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
	add(Ui.label(string.upper(p.name) .. "  -  " .. p.rarity, { Size = UDim2.new(1, 0, 0, 28), Font = T.Title, TextSize = 26, TextColor3 = p.color }))
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

	add(Ui.label("POWER VAULT", { Size = UDim2.new(1, 0, 0, 30), Font = T.Bold, TextSize = 14, TextColor3 = Color3.fromRGB(190, 140, 255) }))
	if ClientState.passes and ClientState.passes.vault then
		paragraph("Every power you've owned since getting the Vault is kept here. Swap for free (not mid-fight).")
		for _, vaulted in Powers.List do
			if ClientState.vault and ClientState.vault[vaulted.id] then
				local current = vaulted.id == p.id
				local row = add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.PanelLight }, {
					Ui.corner(8),
					Ui.padding(6),
					Ui.label(vaulted.name .. "  -  " .. vaulted.rarity, { Size = UDim2.new(1, -120, 1, 0), Font = T.Bold, TextSize = 15, TextColor3 = vaulted.color }),
				}))
				Ui.button(current and "In use" or "Use", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.new(0, 110, 0, 28),
					TextSize = 14,
					AutoButtonColor = not current,
					TextColor3 = current and T.Muted or T.Text,
					Parent = row,
				}, function()
					if current or busy then
						return
					end
					busy = true
					local result = Remotes.Request:InvokeServer("EquipPower", vaulted.id)
					busy = false
					if result and result.ok then
						Hud.Toast("Your power: " .. vaulted.name, vaulted.color)
					else
						Hud.Toast(result and result.message or "Can't swap right now.", T.Bad)
					end
				end)
			end
		end
	else
		paragraph("Want to keep every power you roll, forever? The Power Vault pass (Tokens tab) stores them so you can swap any time.")
	end

	add(Ui.label("THE SHRINE", { Size = UDim2.new(1, 0, 0, 30), Font = T.Bold, TextSize = 14, TextColor3 = T.Accent }))
	local pity = player:GetAttribute("Pity") or 0
	paragraph(string.format("Reroll for %d Essence (you have %d). If you don't like the result, keep your current power. Guaranteed Legendary or better within %d rolls.", Config.Roll.RerollCost, player:GetAttribute("Essence") or 0, math.max(1, Config.Roll.PityAt - pity)))
	add(Ui.button("REROLL  (" .. Config.Roll.RerollCost .. " Essence)", { Size = UDim2.new(1, 0, 0, 44), TextSize = 18, BackgroundColor3 = Color3.fromRGB(40, 30, 64) }, function()
		task.spawn(reroll, false)
	end))
	local dice = ClientState.items["FateDie"] or 0
	local stars = ClientState.items["StarShard"] or 0
	if dice > 0 then
		add(Ui.button(string.format("USE A FATE DIE  (you have %d)", dice), { Size = UDim2.new(1, 0, 0, 40), TextSize = 16, BackgroundColor3 = Color3.fromRGB(60, 44, 10), TextColor3 = T.Gold }, function()
			task.spawn(reroll, true)
		end))
	end
	if stars > 0 then
		paragraph(string.format("You have %d Star Shard%s. Your next roll uses one and is about three times as likely to be Legendary or better.", stars, stars == 1 and "" or "s"), T.Gold)
	end
	add(Ui.label("ODDS", { Size = UDim2.new(1, 0, 0, 26), Font = T.Bold, TextSize = 14, TextColor3 = T.Muted }))
	for _, odds in Powers.Odds() do
		local names = {}
		for _, power in Powers.List do
			if power.rarity == odds.id then
				table.insert(names, power.name)
			end
		end
		add(Ui.label(string.format("%s  %.1f%%   (%s)", odds.id, odds.percent, table.concat(names, ", ")), { Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextColor3 = odds.color }))
	end
end

-- Pack: materials, items and crafting ------------------------------------------------------

local function costLine(cost): (string, boolean)
	local parts = {}
	local affordable = true
	for _, material in Materials.List do
		local need = cost[material.id]
		if need then
			local have = ClientState.inventory[material.id] or 0
			if have < need then
				affordable = false
			end
			table.insert(parts, string.format('<font color="#%s">%s %d/%d</font>', (have >= need and Color3.fromRGB(150, 230, 160) or Color3.fromRGB(255, 130, 130)):ToHex(), material.name, have, need))
		end
	end
	return table.concat(parts, "   "), affordable
end

local function roleCount(role: string): number
	return Townsfolk.Roles(ClientState.rescued or {})[role] or 0
end

function render.Pack()
	heading("Pack")
	add(Ui.label("MATERIALS", { Size = UDim2.new(1, 0, 0, 20), Font = T.Bold, TextSize = 14, TextColor3 = T.Accent }))
	local grid = add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, {
		Ui.new("UIGridLayout", { CellSize = UDim2.new(0, 170, 0, 44), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	}))
	for index, material in Materials.List do
		Ui.new("Frame", { BackgroundColor3 = T.PanelLight, LayoutOrder = index, Parent = grid }, {
			Ui.corner(6),
			Ui.padding(6),
			Ui.label(material.name, { Size = UDim2.new(1, 0, 0, 16), TextSize = 13, Font = T.Bold, TextColor3 = material.color }),
			Ui.label(tostring(ClientState.inventory[material.id] or 0), { Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 16), TextSize = 15, Font = T.Bold }),
		})
	end
	paragraph("Hit trees, rocks, old cars, supply crates and crystals with your basic attack to gather. Shadows drop Umbral Shards.")

	add(Ui.label("ITEMS", { Size = UDim2.new(1, 0, 0, 24), Font = T.Bold, TextSize = 14, TextColor3 = T.Accent }))
	local anyItem = false
	for _, recipe in Recipes.List do
		local count = ClientState.items[recipe.id] or 0
		if recipe.kind ~= "material" and count > 0 then
			anyItem = true
			local row = add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.PanelLight }, {
				Ui.corner(6),
				Ui.padding(8),
				Ui.label(recipe.name .. (recipe.kind == "consumable" and ("  x" .. count) or "") .. "  -  " .. recipe.desc, { Size = UDim2.new(1, -110, 1, 0), TextSize = 14 }),
			}))
			if recipe.kind == "consumable" then
				Ui.button("Use [" .. recipe.key .. "]", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 100, 0, 28), TextSize = 14, Parent = row }, function()
					local result = Remotes.Request:InvokeServer("Use", recipe.id)
					if result and not result.ok and result.message then
						Hud.Toast(result.message, T.Bad)
					end
				end)
			end
		end
	end
	for id, info in Shops.Items do
		local count = ClientState.items[id] or 0
		if count > 0 then
			anyItem = true
			local row = add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.PanelLight }, {
				Ui.corner(6),
				Ui.padding(8),
				Ui.label(string.format("%s  x%d  -  %s", info.name, count, info.desc), { Size = UDim2.new(1, -110, 1, 0), TextSize = 14 }),
			}))
			if id == "DuckBread" then
				Ui.button("Feed Biscuit", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 100, 0, 28), TextSize = 13, Parent = row }, function()
					local result = Remotes.Request:InvokeServer("Use", "DuckBread")
					if result and not result.ok and result.message then
						Hud.Toast(result.message, T.Bad)
					end
				end)
			end
		end
	end
	if not anyItem then
		paragraph("Nothing yet. Craft something below, or visit the merchants at the camp.")
	end

	local groups = { { "material", "REFINING" }, { "tool", "TOOLS" }, { "gear", "GEAR" }, { "consumable", "CONSUMABLES" } }
	for _, group in groups do
		add(Ui.label("CRAFT: " .. group[2], { Size = UDim2.new(1, 0, 0, 26), Font = T.Bold, TextSize = 14, TextColor3 = T.Accent }))
		for _, recipe in Recipes.List do
			if recipe.kind == group[1] then
				local line, affordable = costLine(recipe.cost)
				local needs = {}
				if recipe.station then
					table.insert(needs, Recipes.StationNames[recipe.station] .. " in your base")
				end
				if recipe.needs then
					table.insert(needs, (roleCount(recipe.needs) > 0 and "" or "[locked] ") .. "a rescued " .. string.lower(recipe.needs))
				end
				if recipe.requiresItem then
					table.insert(needs, Recipes.ById[recipe.requiresItem].name)
				end
				local owned = (recipe.kind == "tool" or recipe.kind == "gear") and (ClientState.items[recipe.id] or 0) > 0
				local row = add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = T.PanelLight }, {
					Ui.corner(8),
					Ui.stroke(owned and T.Gold or T.Stroke, 1, owned and 0 or 0.5),
					Ui.padding(8),
					Ui.label(recipe.name .. (owned and "  (owned)" or ""), { Size = UDim2.new(1, -120, 0, 18), Font = T.Bold, TextSize = 15, TextColor3 = owned and T.Gold or T.Text }),
					Ui.label(recipe.desc, { Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, -120, 0, 16), TextSize = 12, TextColor3 = T.Muted }),
					Ui.label(line, { Position = UDim2.new(0, 0, 0, 36), Size = UDim2.new(1, -120, 0, 16), TextSize = 12, RichText = true }),
					Ui.label(#needs > 0 and ("Needs: " .. table.concat(needs, ", ")) or "Craft anywhere", { Position = UDim2.new(0, 0, 0, 52), Size = UDim2.new(1, -120, 0, 14), TextSize = 11, TextColor3 = T.Muted }),
				}))
				Ui.button(owned and "Owned" or "Craft", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.new(0, 110, 0, 34),
					BackgroundColor3 = (affordable and not owned) and Color3.fromRGB(40, 60, 40) or T.PanelLight,
					TextColor3 = (affordable and not owned) and T.Text or T.Muted,
					Parent = row,
				}, function()
					if owned or busy then
						return
					end
					busy = true
					local result = Remotes.Request:InvokeServer("Craft", recipe.id)
					busy = false
					if result and result.ok then
						Hud.Toast("Crafted " .. result.name, T.Good, 2.5)
					else
						Hud.Toast(result and result.message or "Can't craft that.", T.Bad)
					end
				end)
			end
		end
	end
end

-- Build: the blueprint catalogue -----------------------------------------------------------

local buildCategory = "Walls"

function render.Build()
	heading("Build")
	if not player:GetAttribute("BasePlaced") then
		if ClientState.basePlaced then
			paragraph("Your old base spot is taken. Place your crystal somewhere new and everything you built will move with it.", T.Gold)
		else
			paragraph("You don't have a base yet. Place your Base Crystal anywhere in an area you've unlocked: the town, the Woods, the Rift, the Cathedral (away from the camp, boss arenas and gates). Houses in the way? Hold E on one to demolish it. It raises a barrier the shadows can't cross, and you can only build inside it.")
		end
		add(Ui.button("PLACE BASE CRYSTAL", { Size = UDim2.new(1, 0, 0, 48), Font = T.Title, TextSize = 20, BackgroundColor3 = Color3.fromRGB(30, 60, 80) }, function()
			Menu.Close()
			BuildMode.Begin("Crystal")
		end))
		return
	end
	paragraph("Pick something to build, then place its hologram inside your barrier. Blueprints are free to place. Stand next to one and hold E to pour in materials until it's finished. Hold T to cancel or dismantle.")
	local bar = add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 }, { Ui.list(6, Enum.FillDirection.Horizontal) }))
	for index, category in Structures.Categories do
		Ui.button(category, {
			Size = UDim2.new(0, 92, 0, 32),
			TextSize = 14,
			LayoutOrder = index,
			BackgroundColor3 = category == buildCategory and Color3.fromRGB(30, 60, 80) or T.PanelLight,
			Parent = bar,
		}, function()
			buildCategory = category
			Menu.Render()
		end)
	end
	local baseLevel = player:GetAttribute("BaseLevel") or 1
	for _, def in Structures.List do
		if def.category == buildCategory then
			local line = costLine(def.cost)
			local locked = nil
			if def.needs and roleCount(def.needs) == 0 then
				locked = "Rescue a " .. string.lower(def.needs) .. " to unlock"
			elseif def.baseLevel and baseLevel < def.baseLevel then
				locked = "Crystal level " .. def.baseLevel .. " required"
			end
			local row = add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = T.PanelLight }, {
				Ui.corner(8),
				Ui.padding(8),
				Ui.label(def.name, { Size = UDim2.new(1, -130, 0, 18), Font = T.Bold, TextSize = 15, TextColor3 = locked and T.Muted or Color3.fromRGB(150, 220, 255) }),
				Ui.label(def.desc, { Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, -130, 0, 16), TextSize = 12, TextColor3 = T.Muted }),
				Ui.label(locked or line, { Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, -130, 0, 16), TextSize = 12, RichText = true, TextColor3 = locked and T.Bad or T.Text }),
			}))
			Ui.button(locked and "Locked" or "Blueprint", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0, 120, 0, 34),
				BackgroundColor3 = locked and T.PanelLight or Color3.fromRGB(30, 60, 80),
				TextColor3 = locked and T.Muted or T.Text,
				Parent = row,
			}, function()
				if locked then
					Hud.Toast(locked, T.Bad)
					return
				end
				Menu.Close()
				BuildMode.Begin(def.id)
			end)
		end
	end
end

-- Base: crystal upgrades and your people ---------------------------------------------------

local abandonArmed = false

function render.Base()
	heading("Base")
	local level = player:GetAttribute("BaseLevel") or 1
	if not player:GetAttribute("BasePlaced") then
		paragraph("You haven't placed your Base Crystal yet. Open the Build tab to place it.")
	else
		add(Ui.label(string.format("CRYSTAL LEVEL %d / %d   -   barrier radius %d studs", level, #Config.Base.Levels, Config.Base.Levels[level].radius), { Size = UDim2.new(1, 0, 0, 22), Font = T.Bold, TextSize = 16, TextColor3 = Color3.fromRGB(150, 220, 255) }))
		paragraph("The barrier keeps shadows out, heals you and steadies your mind. Upgrading the crystal grows the barrier, which gives you more room to build.")
		local nextTier = Config.Base.Levels[level + 1]
		if nextTier then
			local line, affordable = costLine(nextTier.cost)
			add(Ui.label(string.format("Next: level %d, radius %d", level + 1, nextTier.radius), { Size = UDim2.new(1, 0, 0, 20), Font = T.Bold, TextSize = 14 }))
			add(Ui.label(line, { Size = UDim2.new(1, 0, 0, 20), TextSize = 13, RichText = true }))
			add(Ui.button("UPGRADE CRYSTAL", {
				Size = UDim2.new(1, 0, 0, 44),
				Font = T.Title,
				TextSize = 18,
				BackgroundColor3 = affordable and Color3.fromRGB(30, 60, 80) or T.PanelLight,
				TextColor3 = affordable and T.Text or T.Muted,
			}, function()
				if busy then
					return
				end
				busy = true
				local result = Remotes.Request:InvokeServer("UpgradeBase")
				busy = false
				if result and result.ok then
					Hud.Toast(string.format("Crystal upgraded to level %d! Barrier radius %d.", result.level, result.radius), Color3.fromRGB(150, 220, 255), 4)
				else
					Hud.Toast(result and result.message or "Can't upgrade.", T.Bad)
				end
				Menu.Render()
			end))
		else
			paragraph("Your crystal is at full strength.", T.Gold)
		end
	end

	add(Ui.label("TOWNSFOLK", { Size = UDim2.new(1, 0, 0, 28), Font = T.Bold, TextSize = 14, TextColor3 = T.Accent }))
	local roles = Townsfolk.Roles(ClientState.rescued or {})
	paragraph(string.format("Carpenters: %d   Blacksmiths: %d   Survivors: %d. Each rescued builder makes the materials you put into blueprints go 10%% further (up to 30%%). Survivors keep spirits up: more sanity regeneration at your base.", roles.Carpenter, roles.Blacksmith, roles.Survivor))
	for _, person in Townsfolk.List do
		local saved = ClientState.rescued and ClientState.rescued[person.id]
		local area = Areas.ById[person.area]
		add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = saved and Color3.fromRGB(30, 26, 40) or T.PanelLight }, {
			Ui.corner(6),
			Ui.padding(8),
			Ui.label(person.name .. "  -  " .. (#person.roles > 0 and table.concat(person.roles, " & ") or "Survivor"), { Size = UDim2.new(1, 0, 0, 16), Font = T.Bold, TextSize = 14, TextColor3 = saved and Color3.fromRGB(220, 190, 255) or T.Text }),
			Ui.label(saved and "Safe at your base." or ("Trapped somewhere in " .. area.name), { Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 14), TextSize = 12, TextColor3 = T.Muted }),
		}))
	end

	if player:GetAttribute("BasePlaced") then
		add(Ui.button(abandonArmed and "CLICK AGAIN TO ABANDON (half refund)" or "Abandon base", {
			Size = UDim2.new(1, 0, 0, 36),
			TextSize = 14,
			BackgroundColor3 = Color3.fromRGB(60, 20, 26),
		}, function()
			if not abandonArmed then
				abandonArmed = true
				Menu.Render()
				task.delay(4, function()
					abandonArmed = false
				end)
				return
			end
			abandonArmed = false
			local result = Remotes.Request:InvokeServer("AbandonBase")
			Hud.Toast(result and result.ok and "Base abandoned. Place your crystal again from the Build tab." or (result and result.message or "Failed"), T.Muted)
			Menu.Render()
		end))
	end
end

function render.Journal()
	heading("Journal")
	local story = ClientState.story or {}
	local chapter = story.chapter or 1
	add(Ui.label("CHAPTERS", { Size = UDim2.new(1, 0, 0, 22), Font = T.Bold, TextSize = 14, TextColor3 = T.Accent }))
	for _, c in Story.Chapters do
		local reached = c.id <= chapter
		add(Ui.label(string.format("%s  Chapter %d: %s", reached and "*" or " ", c.id, reached and c.title or "???"), {
			Size = UDim2.new(1, 0, 0, 22),
			Font = reached and T.Title or T.Body,
			TextSize = 17,
			TextColor3 = c.id == chapter and T.Gold or (reached and T.Text or T.Muted),
		}))
	end
	local found = 0
	for _ in story.pages or {} do
		found += 1
	end
	add(Ui.label(string.format("PAGES FOUND  %d / %d", found, #Story.Pages), { Size = UDim2.new(1, 0, 0, 28), Font = T.Bold, TextSize = 14, TextColor3 = T.Accent }))
	paragraph("Pages are scattered across every area. Look for a faint glow on a little wooden stand.")
	for _, page in Story.Pages do
		local has = story.pages and story.pages[page.id]
		local row = add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = has and Color3.fromRGB(40, 34, 24) or T.PanelLight }, {
			Ui.corner(6),
			Ui.padding(8),
			Ui.label(has and page.title or ("??? (somewhere in " .. Areas.ById[page.area].name .. ")"), { Size = UDim2.new(1, -100, 1, 0), TextSize = 14, TextColor3 = has and Color3.fromRGB(240, 225, 190) or T.Muted }),
		}))
		if has then
			Ui.button("Read", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 90, 0, 26), TextSize = 13, Parent = row }, function()
				Menu.Close()
				Cinematic.ShowPage(page)
			end)
		end
	end
end

-- Tokens: the Essence exchange and passes ------------------------------------------------------

local TOKEN_COLOR = Color3.fromRGB(120, 230, 255)

local function exchange(amount: number)
	if busy then
		return
	end
	busy = true
	local result = Remotes.Request:InvokeServer("Exchange", amount)
	busy = false
	if result and result.ok then
		Hud.Toast(string.format("Traded %d Essence for %d Tokens", result.essence, result.tokens), TOKEN_COLOR, 3)
	else
		Hud.Toast(result and result.message or "The exchange is closed.", T.Bad)
	end
end

function render.Tokens()
	local essence = player:GetAttribute("Essence") or 0
	local tokens = player:GetAttribute("Tokens") or 0
	local traded = ClientState.essenceTraded or 0
	local E = Passes.Exchange
	heading("Tokens")
	add(Ui.label(string.format("%d Tokens      %d Essence", tokens, essence), { Size = UDim2.new(1, 0, 0, 24), Font = T.Bold, TextSize = 18, TextColor3 = TOKEN_COLOR }))
	paragraph("Tokens buy passes: permanent upgrades that stay with you forever. You get Tokens by trading Essence here. Essence and Tokens can never be bought with Robux, so everything in this game can be earned just by playing.")

	add(Ui.label("THE EXCHANGE", { Size = UDim2.new(1, 0, 0, 30), Font = T.Bold, TextSize = 14, TextColor3 = TOKEN_COLOR }))
	local cheapLeft = math.max(0, E.NewcomerAllowance - traded)
	if cheapLeft > 0 then
		paragraph(string.format("Newcomer rate: %d Essence = 1 Token for your next %d Essence. After that, %d Essence = 1 Token.", E.NewcomerEssencePerToken, cheapLeft, E.EssencePerToken), T.Good)
	else
		paragraph(string.format("Rate: %d Essence = 1 Token.", E.EssencePerToken))
	end
	paragraph(string.format("Remember a shrine reroll costs %d Essence, so keep some if you want one.", Config.Roll.RerollCost))
	local row = add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, {
		Ui.new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 40), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	}))
	local amounts = table.clone(E.Presets)
	local all = essence - essence % E.Step
	table.insert(amounts, all)
	for index, amount in amounts do
		local affordable = amount >= E.Step and essence >= amount
		local label = index == #amounts and string.format("Trade all (%d)  ->  %d Tokens", amount, Passes.Quote(amount, traded))
			or string.format("Trade %d  ->  %d Tokens", amount, Passes.Quote(amount, traded))
		Ui.button(label, {
			TextSize = 14,
			LayoutOrder = index,
			AutoButtonColor = affordable,
			BackgroundColor3 = affordable and Color3.fromRGB(14, 50, 64) or T.PanelLight,
			TextColor3 = affordable and TOKEN_COLOR or T.Muted,
			Parent = row,
		}, function()
			if affordable then
				task.spawn(exchange, amount)
			end
		end)
	end

	add(Ui.label("PASSES", { Size = UDim2.new(1, 0, 0, 30), Font = T.Bold, TextSize = 14, TextColor3 = T.Gold }))
	for _, pass in Passes.List do
		local owned = ClientState.passes and ClientState.passes[pass.id]
		local affordable = tokens >= pass.price
		local robux = (pass.robuxId or 0) > 0 and not owned
		local card = add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = owned and Color3.fromRGB(20, 30, 24) or T.PanelLight }, {
			Ui.corner(8),
			Ui.stroke(owned and T.Good or pass.color, 1, owned and 0.2 or 0.5),
			Ui.padding(10),
			Ui.label(pass.name .. (owned and "   (owned)" or ""), { Size = UDim2.new(1, -140, 0, 22), Font = T.Title, TextSize = 20, TextColor3 = pass.color }),
			Ui.label(pass.desc, { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, -140, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 13, TextColor3 = T.Muted }),
		}))
		if owned then
			Ui.label("OWNED", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 130, 0, 32), Font = T.Bold, TextSize = 15, TextColor3 = T.Good, TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
		else
			Ui.button(pass.price .. " Tokens", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.new(0, 130, 0, 32),
				TextSize = 14,
				AutoButtonColor = affordable,
				BackgroundColor3 = affordable and Color3.fromRGB(60, 44, 10) or T.PanelLight,
				TextColor3 = affordable and T.Gold or T.Muted,
				Parent = card,
			}, function()
				if busy then
					return
				end
				busy = true
				local result = Remotes.Request:InvokeServer("BuyPass", pass.id)
				busy = false
				if not (result and result.ok) then
					Hud.Toast(result and result.message or "Can't buy that right now.", T.Bad)
				end
			end)
		end
		if robux then
			Ui.button("or buy with Robux", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 38),
				Size = UDim2.new(0, 130, 0, 26),
				TextSize = 12,
				TextColor3 = T.Muted,
				Parent = card,
			}, function()
				local result = Remotes.Request:InvokeServer("PromptPass", pass.id)
				if not (result and result.ok) then
					Hud.Toast(result and result.message or "The store isn't available.", T.Bad)
				end
			end)
		end
		if owned and pass.id == "aura" then
			local on = ClientState.auraOn ~= false
			add(Ui.button(on and "Aura: ON  (click to turn off)" or "Aura: OFF  (click to turn on)", {
				Size = UDim2.new(0, 260, 0, 32),
				TextSize = 13,
				BackgroundColor3 = on and Color3.fromRGB(50, 46, 30) or T.PanelLight,
			}, function()
				Remotes.Request:InvokeServer("Aura", not on)
			end))
		end
		if owned and pass.id == "wardrobe" then
			local outfits = add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, {
				Ui.new("UIGridLayout", { CellSize = UDim2.fromOffset(120, 32), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
			}))
			for index, name in Passes.DuckOutfits do
				local on = (ClientState.duckOutfit or 1) == index
				Ui.button(name, {
					TextSize = 13,
					LayoutOrder = index,
					BackgroundColor3 = on and Color3.fromRGB(70, 40, 60) or T.PanelLight,
					TextColor3 = on and Color3.fromRGB(255, 190, 210) or T.Text,
					Parent = outfits,
				}, function()
					Remotes.Request:InvokeServer("DuckOutfit", index)
				end)
			end
		end
	end
end

-- Clan: your family line, its perks, and rerolls ----------------------------------------------

local clanRolling = false

function render.Clan()
	local clan = Clans.ById[player:GetAttribute("Clan") or ""]
	local free = ClientState.clanFreeRolls or 0
	heading("Clan")
	if clan then
		add(Ui.label(string.upper(clan.name) .. "  -  " .. clan.rarity, { Size = UDim2.new(1, 0, 0, 28), Font = T.Title, TextSize = 26, TextColor3 = Clans.RarityColors[clan.rarity] }))
	else
		add(Ui.label("NO CLAN YET", { Size = UDim2.new(1, 0, 0, 28), Font = T.Title, TextSize = 26, TextColor3 = T.Muted }))
	end
	paragraph(ClanUI.Perks(clan and clan.id), T.Text)

	-- A reroll waiting for a decision: keep the current clan or take the new one.
	local options = ClientState.clanOptions or {}
	if #options > 0 then
		add(Ui.label("CHOOSE YOUR CLAN", { Size = UDim2.new(1, 0, 0, 26), Font = T.Bold, TextSize = 14, TextColor3 = T.Gold }))
		local grid = add(Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, {
			Ui.new("UIGridLayout", { CellSize = UDim2.fromOffset(170, 44), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		}))
		for index, id in options do
			ClanUI.Card(id, id == (clan and clan.id), index, grid, function()
				local result = Remotes.Request:InvokeServer("ChooseClan", id)
				if result and result.ok then
					Hud.Toast("You are of the " .. Clans.ById[id].name .. " clan.", Clans.RarityColors[Clans.ById[id].rarity], 3)
				end
			end)
		end
		for _, id in options do
			if id ~= (clan and clan.id) then
				paragraph(Clans.ById[id].name .. ": " .. table.concat(Clans.Describe(id), ", "))
			end
		end
	end

	add(Ui.label("REROLL", { Size = UDim2.new(1, 0, 0, 26), Font = T.Bold, TextSize = 14, TextColor3 = T.Accent }))
	local reel = add(Ui.label("", { Size = UDim2.new(1, 0, 0, 30), Font = T.Title, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center }))
	local label = free > 0 and string.format("ROLL CLAN  (%d free)", free) or string.format("REROLL CLAN  (%d Essence)", Config.Clans.RerollCost)
	add(Ui.button(label, { Size = UDim2.new(1, 0, 0, 44), TextSize = 17, BackgroundColor3 = Color3.fromRGB(60, 44, 10), TextColor3 = T.Gold }, function()
		if clanRolling then
			return
		end
		clanRolling = true
		local result = Remotes.Request:InvokeServer("RollClan")
		if result and result.ok then
			ClanUI.Reel(reel, result.clan)
			if not result.current then
				-- First clan ever: take it straight away (you can still reroll).
				Remotes.Request:InvokeServer("ChooseClan", result.clan)
			end
		else
			Hud.Toast(result and result.message or "Can't roll right now.", T.Bad)
		end
		clanRolling = false
		Menu.Render()
	end))
	paragraph(string.format("After a reroll you choose: keep your clan or take the new one. Guaranteed Legendary or better within %d rolls.", Config.Clans.PityAt))
	add(Ui.label("ODDS", { Size = UDim2.new(1, 0, 0, 22), Font = T.Bold, TextSize = 13, TextColor3 = T.Muted }))
	local total = 0
	for _, rarity in Clans.RarityOrder do
		total += Clans.Weights[rarity]
	end
	for _, rarity in Clans.RarityOrder do
		local names = {}
		for _, c in Clans.List do
			if c.rarity == rarity then
				table.insert(names, c.name)
			end
		end
		add(Ui.label(string.format("%s  %.1f%%   (%s)", rarity, Clans.Weights[rarity] / total * 100, table.concat(names, ", ")), { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 12, TextColor3 = Clans.RarityColors[rarity] }))
	end
end

function render.Look()
	heading("Look")
	paragraph("Change how your character looks: skin, hair, shirt and trousers, or switch back to your own Roblox avatar. Everyone else sees it too.")
	add(Ui.button("OPEN THE CHARACTER CREATOR", { Size = UDim2.new(1, 0, 0, 46), TextSize = 18, BackgroundColor3 = Color3.fromRGB(40, 30, 64) }, function()
		Menu.Close()
		CharacterCreator.Open(ClientState.look, false)
	end))
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
	for _, command in { { "Skip Act 1", "SkipAct1" }, { "Grant a qualifying feat", "Qualify" }, { "+1000 Essence", "Essence" }, { "+500 Tokens", "Tokens" }, { "+60 of every material", "Materials" }, { "Rescue all townsfolk", "RescueAll" }, { "Reset my data", "Reset" } } do
		add(Ui.button(command[1], { Size = UDim2.new(1, 0, 0, 40) }, function()
			local result = Remotes.Request:InvokeServer("Dev", command[2])
			Hud.Toast(result and result.ok and ("Done: " .. command[1]) or (result and result.message or "Failed"), T.Accent)
			Menu.Render()
		end))
	end
end

-- Shell ------------------------------------------------------------------------------------

function Menu.Render()
	if not panel.Visible or (clanRolling and currentTab == "Clan") then
		return -- (don't wipe the clan reel while it's spinning)
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
	local tabs = Ui.new("ScrollingFrame", {
		Position = UDim2.new(0, 14, 0, 14),
		Size = UDim2.new(0, 150, 1, -28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	}, { Ui.list(6) })
	tabButtons = {}
	for index, name in TABS do
		tabButtons[name] = Ui.button(name, { Size = UDim2.new(1, -6, 0, 36), LayoutOrder = index, Parent = tabs }, function()
			currentTab = name
			Menu.Render()
		end)
	end
	Ui.button("Close", { Size = UDim2.new(1, -6, 0, 34), LayoutOrder = 99, BackgroundColor3 = Color3.fromRGB(50, 20, 26), Parent = tabs }, Menu.Close)

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
	ContextActionService:BindAction("ShadowfallBuildMenu", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin or player:GetAttribute("Act") ~= 2 or ClientState.BuildMode then
			return Enum.ContextActionResult.Pass
		end
		if panel.Visible and currentTab == "Build" then
			Menu.Close()
		else
			Menu.Open("Build")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.B)
	ContextActionService:BindAction("ShadowfallPackMenu", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin or player:GetAttribute("Act") ~= 2 or ClientState.BuildMode then
			return Enum.ContextActionResult.Pass
		end
		if panel.Visible and currentTab == "Pack" then
			Menu.Close()
		else
			Menu.Open("Pack")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Tab)
	ClientState.Changed:Connect(Menu.Render)
	for _, name in { "Level", "Power", "Essence", "Tokens", "CanAscend", "Pity", "BasePlaced", "BaseLevel", "Clan" } do
		player:GetAttributeChangedSignal(name):Connect(Menu.Render)
	end
end

return Menu
