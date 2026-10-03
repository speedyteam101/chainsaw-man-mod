--!nonstrict
-- Act 2 HUD: health, level, power, essence, move bar with cooldowns, area banners, boss bar,
-- toasts, feat unlocks, NPC dialogue and shadow health bars.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Areas = require(ReplicatedStorage.Shared.Areas)
local Powers = require(ReplicatedStorage.Shared.Powers)
local Materials = require(ReplicatedStorage.Shared.Materials)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)
local Atmosphere = require(script.Parent.Atmosphere)
local ClientState = require(script.Parent.ClientState)

local Hud = {}

local T = Ui.Theme
local player = Players.LocalPlayer

local gui
local healthFill, healthText, levelText, powerText, rarityText, essenceText, ascendPill, sanityFill
local gatherFeed, itemSlots = nil, {}
local slots = {} -- [slot] = { frame, cover, timer, lock, name }
local cooldownEnds = {}
local bossFrame, bossName, bossFill
local toastHolder
local dialogue
local bannerTitle, bannerSub
local currentArea

Hud.MenuRequested = nil -- set by Main: function(tab)

local function power()
	local id = player:GetAttribute("Power")
	return id and Powers.ById[id]
end

-- Building --------------------------------------------------------------------------------

local function buildStatus()
	local card = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -20),
		Size = UDim2.new(0, 300, 0, 124),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { Ui.corner(12), Ui.stroke(T.Stroke, 1, 0.3), Ui.padding(12) })

	local badge = Ui.new("Frame", { Size = UDim2.new(0, 54, 0, 54), BackgroundColor3 = T.PanelLight, Parent = card }, { Ui.corner(27), Ui.stroke(T.Accent, 2) })
	Ui.label("LV", { Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(1, 0, 0, 12), TextSize = 11, Font = T.Bold, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = badge })
	levelText = Ui.label("1", { Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 28), TextSize = 26, Font = T.Title, TextXAlignment = Enum.TextXAlignment.Center, Parent = badge })

	powerText = Ui.label("", { Position = UDim2.new(0, 66, 0, 2), Size = UDim2.new(1, -66, 0, 24), TextSize = 22, Font = T.Title, Parent = card })
	rarityText = Ui.label("", { Position = UDim2.new(0, 66, 0, 26), Size = UDim2.new(1, -66, 0, 16), TextSize = 13, Font = T.Bold, Parent = card })
	essenceText = Ui.label("", { Position = UDim2.new(0, 66, 0, 42), Size = UDim2.new(1, -66, 0, 16), TextSize = 13, Font = T.Bold, TextColor3 = Color3.fromRGB(190, 160, 255), Parent = card })

	local sanityBack = Ui.new("Frame", { Position = UDim2.new(0, 0, 1, -36), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = Color3.fromRGB(24, 16, 34), Parent = card }, { Ui.corner(5) })
	sanityFill = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(170, 130, 255), Parent = sanityBack }, { Ui.corner(5) })
	Ui.label("SANITY", { Position = UDim2.new(1, -60, 0, -1), Size = UDim2.new(0, 56, 1, 2), TextSize = 9, Font = T.Bold, TextColor3 = Color3.fromRGB(230, 220, 255), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 2, Parent = sanityBack })
	local barBack = Ui.new("Frame", { Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = Color3.fromRGB(30, 14, 18), Parent = card }, { Ui.corner(6) })
	healthFill = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(220, 60, 70), Parent = barBack }, {
		Ui.corner(6),
		Ui.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 110, 110), Color3.fromRGB(170, 30, 50)), Rotation = 90 }),
	})
	healthText = Ui.label("", { Size = UDim2.fromScale(1, 1), TextSize = 13, Font = T.Bold, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2, Parent = barBack })

	ascendPill = Ui.button("FEAT EARNED - ASCEND  [M]", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -152),
		Size = UDim2.new(0, 300, 0, 34),
		BackgroundColor3 = Color3.fromRGB(60, 44, 10),
		TextColor3 = T.Gold,
		Visible = false,
		Parent = gui,
	}, function()
		if Hud.MenuRequested then
			Hud.MenuRequested("Ascension")
		end
	end)
end

local SLOT_KEYS = { "Z", "X", "C", "V", "G" }

local function buildMoveBar()
	local bar = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.new(0, 5 * 86 + 4 * 8, 0, 86),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Ui.list(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center) })
	for slot = 1, 5 do
		local frame = Ui.new("Frame", { Size = UDim2.new(0, 86, 0, 86), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.1, LayoutOrder = slot, ClipsDescendants = true, Parent = bar }, {
			Ui.corner(10),
			Ui.stroke(T.Stroke, 1, 0.2),
		})
		local key = Ui.label(SLOT_KEYS[slot], { Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(0, 20, 0, 18), Font = T.Bold, TextSize = 15, TextColor3 = T.Muted, ZIndex = 3, Parent = frame })
		local name = Ui.label("", { Position = UDim2.new(0, 6, 1, -40), Size = UDim2.new(1, -12, 0, 36), Font = T.Bold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Bottom, ZIndex = 3, Parent = frame })
		local cover = Ui.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 4, Parent = frame })
		local timer = Ui.label("", { Size = UDim2.fromScale(1, 1), Font = T.Title, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5, Parent = frame })
		local lock = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 6, 8), BackgroundTransparency = 0.15, ZIndex = 6, Visible = false, Parent = frame }, {
			Ui.label("LOCKED", { Position = UDim2.new(0, 0, 0.3, 0), Size = UDim2.new(1, 0, 0, 16), Font = T.Bold, TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 }),
			Ui.label("", { Name = "Req", Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 18), Font = T.Title, TextSize = 16, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 }),
		})
		slots[slot] = { frame = frame, cover = cover, timer = timer, lock = lock, name = name, key = key }
	end
end

local function refreshMoves()
	local p = power()
	local level = player:GetAttribute("Level") or 1
	for slot = 1, 5 do
		local s = slots[slot]
		if slot <= 4 then
			local move = p and p.moves[slot]
			s.name.Text = move and move.name or ""
			s.frame.BackgroundColor3 = p and p.color:Lerp(Color3.new(0, 0, 0), 0.82) or T.Panel
			s.lock.Visible = not move or level < slot
			s.lock.Req.Text = "LEVEL " .. slot
		else
			s.name.Text = "Awakening"
			s.frame.BackgroundColor3 = p and p.color:Lerp(Color3.new(0, 0, 0), 0.7) or T.Panel
			s.lock.Visible = level < 5
			s.lock.Req.Text = "LEVEL 5"
		end
	end
end

local function refreshStatus()
	local p = power()
	local level = player:GetAttribute("Level") or 1
	levelText.Text = tostring(level)
	if p then
		local rarity = Powers.RarityById[p.rarity]
		powerText.Text = string.upper(p.name)
		powerText.TextColor3 = p.color
		rarityText.Text = p.rarity
		rarityText.TextColor3 = rarity.color
	end
	essenceText.Text = string.format("%d Essence   |   %d Tokens", player:GetAttribute("Essence") or 0, player:GetAttribute("Tokens") or 0)
	ascendPill.Visible = player:GetAttribute("CanAscend") == true
	refreshMoves()
end

local function buildItems()
	local bar = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -114),
		Size = UDim2.new(0, 3 * 120 + 2 * 6, 0, 30),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Ui.list(6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center) })
	for index, id in Recipes.Consumables do
		local recipe = Recipes.ById[id]
		local slot = Ui.label("", {
			Size = UDim2.new(0, 120, 0, 30),
			BackgroundTransparency = 0.2,
			BackgroundColor3 = T.Panel,
			TextSize = 13,
			Font = T.Bold,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = index,
			Parent = bar,
		})
		Ui.corner(8).Parent = slot
		itemSlots[id] = { label = slot, name = recipe.name, key = recipe.key }
	end
	gatherFeed = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.new(0, 200, 0, 220),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

local feedEntries = {} -- [materialId] = { label, amount, token }
local feedOrder = 0
local function showGathered(id: string, amount: number)
	local material = Materials.ById[id]
	if not material then
		return
	end
	local entry = feedEntries[id]
	if not entry or not entry.label.Parent then
		feedOrder += 1
		entry = {
			amount = 0,
			token = 0,
			label = Ui.label("", { Size = UDim2.new(1, 0, 0, 22), TextSize = 16, Font = T.Bold, TextColor3 = material.color, TextStrokeTransparency = 0.4, TextXAlignment = Enum.TextXAlignment.Right, LayoutOrder = feedOrder, Parent = gatherFeed }),
		}
		feedEntries[id] = entry
	end
	entry.amount += amount
	entry.token += 1
	local token = entry.token
	entry.label.Text = string.format("+%d %s", entry.amount, material.name)
	entry.label.TextTransparency = 0
	task.delay(2.5, function()
		if entry.token == token then
			Ui.tween(entry.label, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
			task.wait(0.55)
			if entry.token == token then
				entry.label:Destroy()
				feedEntries[id] = nil
			end
		end
	end)
end

local function refreshItems()
	for id, slot in itemSlots do
		local count = ClientState.items and (ClientState.items[id] or 0) or 0
		slot.label.Text = string.format("[%s] %s  x%d", slot.key, slot.name, count)
		slot.label.TextColor3 = count > 0 and T.Text or T.Muted
		slot.label.Visible = count > 0
	end
end

local function buildBanner()
	bannerTitle = Ui.label("", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Size = UDim2.new(0.8, 0, 0, 56), Font = T.Title, TextSize = 52, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, TextStrokeTransparency = 1, Parent = gui })
	bannerSub = Ui.label("", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 146), Size = UDim2.new(0.8, 0, 0, 24), Font = T.Body, TextSize = 18, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, Parent = gui })
end

local function showBanner(title: string, sub: string, color: Color3)
	bannerTitle.Text = string.upper(title)
	bannerTitle.TextColor3 = color
	bannerSub.Text = sub
	Ui.tween(bannerTitle, 0.6, { TextTransparency = 0, TextStrokeTransparency = 0.6 })
	Ui.tween(bannerSub, 0.6, { TextTransparency = 0 })
	task.delay(3.2, function()
		if bannerTitle.Text == string.upper(title) then
			Ui.tween(bannerTitle, 1, { TextTransparency = 1, TextStrokeTransparency = 1 })
			Ui.tween(bannerSub, 1, { TextTransparency = 1 })
		end
	end)
end

local function buildBossBar()
	bossFrame = Ui.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.new(0, 560, 0, 52), BackgroundTransparency = 1, Visible = false, Parent = gui })
	bossName = Ui.label("", { Size = UDim2.new(1, 0, 0, 24), Font = T.Title, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5, Parent = bossFrame })
	local back = Ui.new("Frame", { Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = Color3.fromRGB(20, 10, 14), Parent = bossFrame }, { Ui.corner(4), Ui.stroke(Color3.fromRGB(90, 30, 40), 1) })
	bossFill = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 30, 50), Parent = back }, { Ui.corner(4) })
end

local function buildToasts()
	toastHolder = Ui.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 80), Size = UDim2.new(0, 340, 0.6, 0), BackgroundTransparency = 1, Parent = gui }, {
		Ui.list(8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right),
	})
end

function Hud.Toast(text: string, color: Color3?, duration: number?)
	local toast = Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Panel, BackgroundTransparency = 0.1, Parent = toastHolder }, {
		Ui.corner(8),
		Ui.stroke(color or T.Stroke, 1),
		Ui.padding(10),
		Ui.label(text, { AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextSize = 15, TextColor3 = color or T.Text }),
	})
	task.delay(duration or 4, function()
		Ui.tween(toast, 0.4, { BackgroundTransparency = 1 })
		for _, d in toast:GetDescendants() do
			if d:IsA("TextLabel") then
				Ui.tween(d, 0.4, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then
				Ui.tween(d, 0.4, { Transparency = 1 })
			end
		end
		task.wait(0.45)
		toast:Destroy()
	end)
end

local function featUnlocked(data)
	Audio.Play("Achievement", 0.8)
	local card = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -120),
		Size = UDim2.new(0, 460, 0, 96),
		BackgroundColor3 = Color3.fromRGB(26, 20, 8),
		Parent = gui,
	}, {
		Ui.corner(12),
		Ui.stroke(T.Gold, 2),
		Ui.padding(14),
		Ui.label("FEAT EARNED", { Size = UDim2.new(1, 0, 0, 14), TextSize = 12, Font = T.Bold, TextColor3 = T.Gold }),
		Ui.label(data.name, { Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 28), TextSize = 26, Font = T.Title, TextColor3 = Color3.fromRGB(255, 240, 210) }),
		Ui.label(data.desc .. (data.qualifies and string.format("   Qualifies for level %d.", data.qualifies) or ""), { Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(1, 0, 0, 22), TextSize = 13, TextColor3 = T.Muted }),
	})
	Ui.tween(card, 0.5, { Position = UDim2.new(0.5, 0, 0, 90) }, Enum.EasingStyle.Back)
	task.delay(4.5, function()
		Ui.tween(card, 0.4, { Position = UDim2.new(0.5, 0, 0, -140) })
		task.wait(0.5)
		card:Destroy()
	end)
	if data.canAscendNow then
		Hud.Toast("You can Ascend! Open the menu (M) and press Ascend.", T.Gold, 6)
	end
end

local function buildDialogue()
	dialogue = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -130),
		Size = UDim2.new(0, 620, 0, 110),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.05,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(12),
		Ui.stroke(Color3.fromRGB(255, 190, 120), 1, 0.3),
		Ui.padding(14),
		Ui.label("", { Name = "Speaker", Size = UDim2.new(1, 0, 0, 20), Font = T.Bold, TextSize = 16, TextColor3 = Color3.fromRGB(255, 200, 140) }),
		Ui.label("", { Name = "Line", Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 1, -40), TextSize = 17, TextYAlignment = Enum.TextYAlignment.Top }),
		Ui.label("click to continue", { Position = UDim2.new(0, 0, 1, -14), Size = UDim2.new(1, 0, 0, 14), TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Right }),
	})
end

local dialogueToken = 0
local function playDialogue(speaker: string, lines)
	dialogueToken += 1
	local token = dialogueToken
	dialogue.Visible = true
	ClientState.DialogueOpen = true
	dialogue.Speaker.Text = speaker
	for _, line in lines do
		if token ~= dialogueToken then
			return
		end
		task.spawn(Ui.typewrite, dialogue.Line, line, 0.018)
		local advanced = false
		local connection = dialogue.MouseButton1Click:Connect(function()
			advanced = true
		end)
		local started = os.clock()
		while not advanced and os.clock() - started < 9 and token == dialogueToken do
			task.wait()
		end
		connection:Disconnect()
	end
	if token == dialogueToken then
		dialogue.Visible = false
		ClientState.DialogueOpen = false
	end
end

-- Enemy health bars ------------------------------------------------------------------------

local function attachBar(model: Model)
	if model:GetAttribute("Boss") then
		return
	end
	local head = model:WaitForChild("Head", 5)
	if not head then
		return
	end
	local billboard = Ui.new("BillboardGui", {
		Size = UDim2.fromOffset(110, 26),
		StudsOffsetWorldSpace = Vector3.new(0, 2 * (tonumber(model:GetAttribute("RigScale")) or 1), 0),
		MaxDistance = 60,
		AlwaysOnTop = false,
		LightInfluence = 0,
		Adornee = head,
		Parent = head,
	})
	Ui.label(tostring(model:GetAttribute("EnemyName") or "Shadow"), { Size = UDim2.new(1, 0, 0, 14), TextSize = 12, Font = T.Bold, TextColor3 = Color3.fromRGB(220, 210, 230), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, Parent = billboard })
	local back = Ui.new("Frame", { Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Color3.fromRGB(20, 10, 14), BorderSizePixel = 0, Parent = billboard })
	local fill = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(190, 60, 255), BorderSizePixel = 0, Parent = back })
	local function update()
		local hp = model:GetAttribute("Health") or 0
		local max = model:GetAttribute("MaxHealth") or 1
		fill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
	end
	model:GetAttributeChangedSignal("Health"):Connect(update)
	update()
end

-- Frame update -----------------------------------------------------------------------------

local function nearestBoss(root: BasePart)
	local best, bestDistance = nil, 110
	for _, model in CollectionService:GetTagged("Enemy") do
		if model:GetAttribute("Boss") and model.PrimaryPart and not model:GetAttribute("Dead") then
			local d = (model.PrimaryPart.Position - root.Position).Magnitude
			if d < bestDistance then
				best, bestDistance = model, d
			end
		end
	end
	return best
end

local function onStep()
	local isAct2 = player:GetAttribute("Act") == 2
	gui.Enabled = isAct2 and not ClientState.InCutscene
	if not gui.Enabled then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid then
		local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		healthFill.Size = UDim2.fromScale(ratio, 1)
		healthText.Text = string.format("%d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth)
		sanityFill.Size = UDim2.fromScale(math.clamp((player:GetAttribute("Sanity") or 100) / 100, 0, 1), 1)
	end
	local now = os.clock()
	for slot, s in slots do
		local finish = cooldownEnds[slot]
		if finish and now < finish.time then
			local left = finish.time - now
			s.cover.Size = UDim2.fromScale(1, left / finish.duration)
			s.timer.Text = left >= 10 and tostring(math.floor(left)) or string.format("%.1f", left)
		else
			s.cover.Size = UDim2.fromScale(1, 0)
			s.timer.Text = ""
		end
	end
	if root then
		local area = Areas.At(root.Position)
		if area and area ~= currentArea then
			currentArea = area
			showBanner(area.name, area.subtitle, area.color)
		end
		local boss = nearestBoss(root)
		bossFrame.Visible = boss ~= nil
		if boss then
			bossName.Text = boss:GetAttribute("EnemyName")
			bossFill.Size = UDim2.fromScale(math.clamp((boss:GetAttribute("Health") or 0) / (boss:GetAttribute("MaxHealth") or 1), 0, 1), 1)
			Audio.Loop("CombatMusic", 0.35)
		else
			Audio.StopLoop("CombatMusic")
		end
	end
end

function Hud.Start()
	gui = Ui.screen("Hud", 10)
	buildStatus()
	buildMoveBar()
	buildItems()
	buildBanner()
	buildBossBar()
	buildToasts()
	buildDialogue()

	Ui.button("MENU  [M]", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 20), Size = UDim2.new(0, 130, 0, 36), Parent = gui }, function()
		if Hud.MenuRequested then
			Hud.MenuRequested(nil)
		end
	end)

	for _, name in { "Level", "Power", "Essence", "Tokens", "CanAscend" } do
		player:GetAttributeChangedSignal(name):Connect(refreshStatus)
	end
	refreshStatus()

	for _, model in CollectionService:GetTagged("Enemy") do
		task.spawn(attachBar, model)
	end
	CollectionService:GetInstanceAddedSignal("Enemy"):Connect(function(model)
		task.spawn(attachBar, model)
	end)

	Remotes.Notify.OnClientEvent:Connect(function(kind, data)
		if kind == "State" then
			ClientState.Apply(data)
			refreshItems()
		elseif kind == "Gathered" then
			showGathered(data.id, data.amount)
		elseif kind == "Rescued" then
			showBanner(data.name .. " is free!", (#data.roles > 0 and table.concat(data.roles, " & ") or "Survivor") .. "  -  they'll wait for you at your base", Color3.fromRGB(220, 190, 255))
			Hud.Toast(string.format("%s: \"%s\"", data.name, data.line), Color3.fromRGB(255, 225, 180), 7)
		elseif kind == "Toast" then
			Hud.Toast(data.text, data.color)
		elseif kind == "Achievement" then
			featUnlocked(data)
		elseif kind == "Cooldown" then
			cooldownEnds[data.slot] = { time = os.clock() + data.duration, duration = data.duration }
		elseif kind == "ResetCooldowns" then
			cooldownEnds = {}
		elseif kind == "Essence" then
			Hud.Toast(string.format("+%d Essence", data.amount), Color3.fromRGB(190, 160, 255), 1.5)
		elseif kind == "PassUnlocked" then
			showBanner(data.name .. " unlocked", "It's yours for good. Thank you for playing!", Color3.fromRGB(120, 230, 255))
		elseif kind == "Dialogue" then
			task.spawn(playDialogue, data.speaker, data.lines)
		elseif kind == "OpenMenu" then
			if Hud.MenuRequested then
				Hud.MenuRequested(data.tab)
			end
		end
	end)

	Remotes.Fx.OnClientEvent:Connect(function(kind, data)
		if kind == "BossDefeated" then
			showBanner(data.name .. " has fallen", "The dark recoils, for now.", T.Gold)
			if data.name == "The Umbral King" then
				-- The ending: dawn breaks, just for a moment.
				Atmosphere.Apply("dawn", 4)
				task.delay(25, function()
					Atmosphere.Apply(player:GetAttribute("Act") == 2 and 2 or 1, 6)
				end)
			end
		elseif kind == "BossPhase" then
			Hud.Toast(data.name .. " is enraged!", T.Bad, 3)
		elseif kind == "BossSpawn" and currentArea and currentArea.name == data.area then
			Hud.Toast(data.name .. " has risen in " .. data.area .. ".", Color3.fromRGB(255, 140, 140), 4)
		end
	end)

	-- Shows when you're inside the camp's safe zone.
	local safeLabel = Ui.label("SAFE - shadows can't reach you here", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.new(0, 360, 0, 20), TextSize = 14, Font = T.Bold, TextColor3 = Color3.fromRGB(255, 190, 120), TextXAlignment = Enum.TextXAlignment.Center, Visible = false, Parent = gui })
	local function watchSafe(character)
		character:GetAttributeChangedSignal("Safe"):Connect(function()
			safeLabel.Visible = character:GetAttribute("Safe") == true
		end)
	end
	if player.Character then
		watchSafe(player.Character)
	end
	player.CharacterAdded:Connect(watchSafe)

	RunService.RenderStepped:Connect(onStep)
	Remotes.Request:InvokeServer("State")
end

return Hud
