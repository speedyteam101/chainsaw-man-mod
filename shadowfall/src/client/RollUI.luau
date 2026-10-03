--!nonstrict
-- The power roll: a reel of powers that spins, slows, and lands on your result, followed by a
-- reveal card. Used for the free awakening roll and for shrine rerolls (keep new / keep current).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Powers = require(ReplicatedStorage.Shared.Powers)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)

local RollUI = {}

local T = Ui.Theme
local CARD_W, CARD_GAP = 170, 12
local rng = Random.new()

local function card(power, index: number)
	local rarity = Powers.RarityById[power.rarity]
	return Ui.new("Frame", {
		Name = "Card" .. index,
		Position = UDim2.new(0, (index - 1) * (CARD_W + CARD_GAP), 0, 0),
		Size = UDim2.new(0, CARD_W, 1, 0),
		BackgroundColor3 = Color3.fromRGB(16, 14, 20),
	}, {
		Ui.corner(10),
		Ui.stroke(rarity.color, 2),
		Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = rarity.color, BorderSizePixel = 0 }, { Ui.corner(3) }),
		Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 22),
			Size = UDim2.new(0, 56, 0, 56),
			BackgroundColor3 = power.color,
			Rotation = 45,
		}, { Ui.corner(6), Ui.stroke(Color3.new(1, 1, 1), 1, 0.6) }),
		Ui.label(string.upper(power.id), { Position = UDim2.new(0, 0, 0, 98), Size = UDim2.new(1, 0, 0, 26), Font = T.Title, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = T.Text }),
		Ui.label(power.rarity, { Position = UDim2.new(0, 0, 0, 126), Size = UDim2.new(1, 0, 0, 18), Font = T.Bold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = rarity.color }),
	})
end

-- opts: { first: boolean?, current: string? }  Returns true to keep the new power (rerolls only).
function RollUI.Play(powerId: string, opts)
	opts = opts or {}
	local result = Powers.ById[powerId]
	local rarity = Powers.RarityById[result.rarity]
	local gui = Ui.screen("PowerRoll", 50)

	local backdrop = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(4, 3, 8), BackgroundTransparency = 1, Parent = gui })
	Ui.tween(backdrop, 0.5, { BackgroundTransparency = 0.08 })

	local title = Ui.label(opts.first and "SOMETHING INSIDE YOU ANSWERS" or "THE SHRINE ANSWERS", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.14, 0),
		Size = UDim2.new(0.9, 0, 0, 40),
		Font = T.Title,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(230, 220, 255),
		Parent = backdrop,
	})
	title.TextTransparency = 1
	Ui.tween(title, 0.8, { TextTransparency = 0 })

	local window = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(0.9, 0, 0, 170),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = backdrop,
	})
	local strip = Ui.new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, Parent = window })
	local marker = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(0, 4, 0, 200),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = backdrop,
	}, { Ui.corner(2) })

	-- Build the reel: weighted random filler, with the real result at a fixed slot.
	local total, landing = 48, 42
	for i = 1, total do
		local power = i == landing and result or Powers.Roll(rng, false)
		card(power, i).Parent = strip
	end

	local windowWidth = window.AbsoluteSize.X
	if windowWidth <= 0 then
		windowWidth = 800
	end
	local jitter = rng:NextNumber(-CARD_W * 0.35, CARD_W * 0.35)
	local finalX = windowWidth / 2 - ((landing - 1) * (CARD_W + CARD_GAP) + CARD_W / 2) + jitter
	local duration = opts.first and 5.5 or 4.5
	local started = os.clock()
	local lastIndex = -1
	local done = false
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started) / duration, 0, 1)
		local eased = 1 - (1 - t) ^ 4
		local x = windowWidth / 2 + (finalX - windowWidth / 2) * eased
		strip.Position = UDim2.new(0, x, 0, 0)
		local centerIndex = math.floor((windowWidth / 2 - x) / (CARD_W + CARD_GAP))
		if centerIndex ~= lastIndex then
			lastIndex = centerIndex
			Audio.Play("RollTick", 0.3, 1 + t * 0.4)
			marker.Size = UDim2.new(0, 6, 0, 210)
			Ui.tween(marker, 0.12, { Size = UDim2.new(0, 4, 0, 200) })
		end
		if t >= 1 then
			done = true
			connection:Disconnect()
		end
	end)
	while not done do
		task.wait()
	end
	-- Settle the jitter so the result card centres under the marker.
	Ui.tween(strip, 0.4, { Position = UDim2.new(0, finalX - jitter, 0, 0) }, Enum.EasingStyle.Back)
	task.wait(0.6)

	-- Reveal
	Audio.Play("RollReveal", 0.9)
	local flash = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rarity.color, BackgroundTransparency = 0.2, ZIndex = 5, Parent = backdrop })
	Ui.tween(flash, 0.8, { BackgroundTransparency = 1 })
	window.Visible = false
	marker.Visible = false
	title.Text = opts.first and "YOU HAVE AWAKENED" or "YOU ROLLED"

	local reveal = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0, 560, 0, 330),
		BackgroundColor3 = Color3.fromRGB(14, 12, 20),
		Parent = backdrop,
	}, {
		Ui.corner(14),
		Ui.stroke(rarity.color, 3),
		Ui.padding(22),
		Ui.label(string.upper(result.id), { Size = UDim2.new(1, 0, 0, 56), Font = T.Title, TextSize = 52, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = result.color }),
		Ui.label(string.upper(result.rarity), { Position = UDim2.new(0, 0, 0, 58), Size = UDim2.new(1, 0, 0, 22), Font = T.Bold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = rarity.color }),
		Ui.label(result.blurb, { Position = UDim2.new(0, 0, 0, 92), Size = UDim2.new(1, 0, 0, 48), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = T.Muted, Font = T.Body }),
		Ui.label("Passive: " .. result.passive, { Position = UDim2.new(0, 0, 0, 146), Size = UDim2.new(1, 0, 0, 22), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = T.Text, Font = T.Bold }),
		Ui.label(string.format("Moves: %s, %s, %s, %s", result.moves[1].name, result.moves[2].name, result.moves[3].name, result.moves[4].name), {
			Position = UDim2.new(0, 0, 0, 174),
			Size = UDim2.new(1, 0, 0, 40),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = T.Muted,
		}),
	})
	reveal.Size = UDim2.new(0, 500, 0, 290)
	Ui.tween(reveal, 0.35, { Size = UDim2.new(0, 560, 0, 330) }, Enum.EasingStyle.Back)

	local choice: boolean? = nil
	local buttons = Ui.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = reveal }, {
		Ui.list(14, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center),
	})
	if opts.first then
		Ui.label("Your power grows only when you prove yourself. Earn feats, then Ascend.", {
			Position = UDim2.new(0, 0, 0, 218),
			Size = UDim2.new(1, 0, 0, 22),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = T.Gold,
			Parent = reveal,
		})
		Ui.button("Rise", { Size = UDim2.new(0, 180, 0, 40), BackgroundColor3 = Color3.fromRGB(40, 30, 60), Parent = buttons }, function()
			choice = true
		end)
	else
		local current = opts.current and Powers.ById[opts.current]
		Ui.button("Take " .. result.id, { Size = UDim2.new(0, 220, 0, 40), BackgroundColor3 = Color3.fromRGB(40, 60, 40), Parent = buttons }, function()
			choice = true
		end)
		Ui.button("Keep " .. (current and current.id or "current"), { Size = UDim2.new(0, 220, 0, 40), Parent = buttons }, function()
			choice = false
		end)
	end

	while choice == nil do
		task.wait()
	end
	Ui.tween(backdrop, 0.4, { BackgroundTransparency = 1 })
	for _, child in backdrop:GetDescendants() do
		if child:IsA("GuiObject") then
			child.Visible = false
		end
	end
	task.wait(0.4)
	gui:Destroy()
	return choice
end

return RollUI
