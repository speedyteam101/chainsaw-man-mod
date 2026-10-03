--!nonstrict
-- The trading window for merchants.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Materials = require(ReplicatedStorage.Shared.Materials)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shops = require(ReplicatedStorage.Shared.Shops)
local Ui = require(script.Parent.Ui)
local Hud = require(script.Parent.Hud)
local ClientState = require(script.Parent.ClientState)

local ShopUI = {}

local T = Ui.Theme
local player = Players.LocalPlayer
local panel, title, greeting, essenceLabel, list
local currentShop = nil
local busy = false

local function describe(entry): string
	if entry.give then
		local parts = {}
		for id, amount in entry.give do
			local material = Materials.ById[id]
			table.insert(parts, string.format("%d %s", amount, material and material.name or id))
		end
		return table.concat(parts, ", ")
	end
	local recipe = Recipes.ById[entry.item]
	local item = Shops.Items[entry.item]
	return (recipe and recipe.desc) or (item and item.desc) or ""
end

local function render()
	if not currentShop then
		return
	end
	local shop = Shops.ById[currentShop]
	title.Text = shop.name
	greeting.Text = '"' .. shop.greeting .. '"'
	essenceLabel.Text = string.format("You have %d Essence", player:GetAttribute("Essence") or 0)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index, entry in shop.stock do
		local affordable = (player:GetAttribute("Essence") or 0) >= entry.price
		local owned = entry.item and (ClientState.items[entry.item] or 0) or nil
		local row = Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = T.PanelLight, LayoutOrder = index, Parent = list }, {
			Ui.corner(8),
			Ui.padding(8),
			Ui.label(entry.name .. (owned and owned > 0 and ("  (you have " .. owned .. ")") or ""), { Size = UDim2.new(1, -130, 0, 18), Font = T.Bold, TextSize = 15 }),
			Ui.label(describe(entry), { Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, -130, 0, 18), TextSize = 12, TextColor3 = T.Muted }),
		})
		Ui.button(entry.price .. " Essence", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 120, 0, 34),
			BackgroundColor3 = affordable and Color3.fromRGB(60, 44, 10) or T.PanelLight,
			TextColor3 = affordable and T.Gold or T.Muted,
			Parent = row,
		}, function()
			if busy then
				return
			end
			busy = true
			local result = Remotes.Request:InvokeServer("ShopBuy", { shop = currentShop, item = entry.id })
			busy = false
			if result and result.ok then
				Hud.Toast("Bought " .. result.name, T.Gold, 2.5)
			else
				Hud.Toast(result and result.message or "Can't buy that.", T.Bad)
			end
			task.wait(0.2)
			render()
		end)
	end
end

function ShopUI.Open(shopId: string)
	currentShop = shopId
	panel.Visible = true
	ClientState.DialogueOpen = true
	render()
end

function ShopUI.Close()
	panel.Visible = false
	currentShop = nil
	ClientState.DialogueOpen = false
end

function ShopUI.Start()
	local gui = Ui.screen("Shop", 22)
	panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.8, 0, 0.75, 0),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(14), Ui.stroke(T.Gold, 1, 0.4), Ui.padding(16), Ui.new("UISizeConstraint", { MaxSize = Vector2.new(620, 560) }) })
	title = Ui.label("", { Size = UDim2.new(1, -120, 0, 32), Font = T.Title, TextSize = 28, TextColor3 = T.Gold, Parent = panel })
	greeting = Ui.label("", { Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 0, 36), TextSize = 14, TextColor3 = T.Muted, Parent = panel })
	essenceLabel = Ui.label("", { Position = UDim2.new(0, 0, 0, 72), Size = UDim2.new(1, 0, 0, 18), Font = T.Bold, TextSize = 14, TextColor3 = Color3.fromRGB(190, 160, 255), Parent = panel })
	Ui.button("Close", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 100, 0, 32), Parent = panel }, ShopUI.Close)
	list = Ui.new("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 98),
		Size = UDim2.new(1, 0, 1, -98),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	}, { Ui.list(6) })

	Remotes.Notify.OnClientEvent:Connect(function(kind, data)
		if kind == "OpenShop" then
			ShopUI.Open(data.shop)
		end
	end)
	player:GetAttributeChangedSignal("Essence"):Connect(render)
	ClientState.Changed:Connect(render)
end

return ShopUI
