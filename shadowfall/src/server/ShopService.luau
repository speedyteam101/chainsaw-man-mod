--!nonstrict
-- Merchant NPCs. Talk to one (E) to open their shop; prices are in Essence.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Areas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shops = require(ReplicatedStorage.Shared.Shops)
local Figure = require(ReplicatedStorage.Shared.Figure)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local InventoryService = require(script.Parent.InventoryService)

local ShopService = {}

local positions = {} -- [shopId] = Vector3

local function block(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function buildMerchant(shop, cf: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = shop.name
	local spec = Figure.SpecFor(shop.id, {
		shirt = shop.shirt,
		pants = shop.pants,
		outfit = shop.id == "medic" and "doctor" or (shop.id == "scavenger" and "jacket" or nil),
	})
	if shop.hooded then
		spec.skin = Color3.fromRGB(20, 18, 24)
		spec.hair = 1
		spec.expression = "closed"
		spec.outfit = "coat"
	end
	spec.cf = cf
	spec.name = shop.name
	spec.collide = true
	local built, parts = Figure.Build(spec)
	for _, child in built:GetChildren() do
		child.Parent = model
	end
	built:Destroy()
	model.PrimaryPart = parts.Torso
	local torso = parts.Torso
	if shop.hooded then
		-- A deep hood with two pale points of light inside it.
		block(model, "Hood", Vector3.new(2.6, 2, 1.8), cf * CFrame.new(0, 4.7, 0.15), shop.shirt, Enum.Material.Fabric)
		block(model, "Cloak", Vector3.new(2.6, 4.6, 1.4), cf * CFrame.new(0, 2.5, 0.2), shop.shirt, Enum.Material.Fabric)
		for _, x in { -0.35, 0.35 } do
			local eye = block(model, "Eye", Vector3.new(0.18, 0.12, 0.05), cf * CFrame.new(x, 4.6, -0.78), Color3.fromRGB(220, 220, 255), Enum.Material.Neon)
			eye.CanCollide = false
		end
		local lantern = block(model, "Lantern", Vector3.new(0.8, 1.1, 0.8), cf * CFrame.new(1.6, 1.6, -0.6), Color3.fromRGB(180, 140, 255), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(180, 140, 255)
		light.Range = 14
		light.Brightness = 1.2
		light.Parent = lantern
	else
		-- A stall: counter, awning and goods.
		local stall = cf * CFrame.new(0, 0, -3.5)
		block(model, "Counter", Vector3.new(7, 3, 2), stall * CFrame.new(0, 1.5, 0), Color3.fromRGB(90, 66, 44), Enum.Material.WoodPlanks)
		block(model, "Awning", Vector3.new(8, 0.3, 4), stall * CFrame.new(0, 7.2, 1) * CFrame.Angles(math.rad(-12), 0, 0), shop.id == "medic" and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(60, 90, 70), Enum.Material.Fabric)
		for _, x in { -3.4, 3.4 } do
			block(model, "Pole", Vector3.new(0.3, 7, 0.3), stall * CFrame.new(x, 3.5, 0.8), Color3.fromRGB(60, 44, 30), Enum.Material.Wood)
		end
		for i = 1, 4 do
			block(model, "Goods", Vector3.new(0.9, 0.9, 0.9), stall * CFrame.new(-2.6 + i * 1.05, 3.45, 0) * CFrame.Angles(0, i, 0), i % 2 == 0 and Color3.fromRGB(150, 120, 80) or Color3.fromRGB(200, 200, 190), Enum.Material.Fabric)
		end
		local lamp = block(model, "StallLamp", Vector3.new(0.6, 0.8, 0.6), stall * CFrame.new(0, 6.4, 1.2), Color3.fromRGB(255, 200, 130), Enum.Material.Neon)
		lamp.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 190, 120)
		light.Range = 16
		light.Brightness = 1.4
		light.Parent = lamp
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffset = Vector3.new(0, 6.8, 0)
	gui.MaxDistance = 50
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(255, 220, 150)
	label.TextStrokeTransparency = 0.4
	label.Text = shop.name .. "\n" .. shop.title
	label.Parent = gui
	gui.Parent = torso
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Trade"
	prompt.ObjectText = shop.name
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = torso
	model.Parent = parent
	return prompt
end

function ShopService.Buy(player: Player, shopId, itemId)
	local data = PlayerData.Get(player)
	local shop = Shops.ById[tostring(shopId)]
	local entry = shop and shop.byItem[tostring(itemId)]
	local _, _, root = Combat.GetCharacter(player)
	if not data or not entry or not root or data.act ~= 2 then
		return { ok = false, message = "You can't trade right now." }
	end
	if (root.Position - positions[shop.id]).Magnitude > 22 then
		return { ok = false, message = "You walked away from the stall." }
	end
	if data.essence < entry.price then
		return { ok = false, message = string.format("You need %d Essence (you have %d).", entry.price, data.essence) }
	end
	data.essence -= entry.price
	player:SetAttribute("Essence", data.essence)
	if entry.give then
		for id, amount in entry.give do
			InventoryService.Add(player, id, amount, false)
		end
	end
	if entry.item then
		InventoryService.AddItem(player, entry.item, 1)
	end
	InventoryService.Changed(player)
	return { ok = true, name = entry.name }
end

function ShopService.Start(world)
	local folder = Instance.new("Folder")
	folder.Name = "Merchants"
	folder.Parent = world.map
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world.floors, workspace.Terrain }
	params.IgnoreWater = true
	for _, shop in Shops.List do
		local hit = workspace:Raycast(shop.at + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params)
		local ground = hit and hit.Position or shop.at
		local area = Areas.ById[shop.area]
		-- Face the camp fire (or the area's centre).
		local lookAt = shop.area == "town" and Vector3.new(0, ground.Y, 0) or Vector3.new(area.center.X, ground.Y, area.center.Z)
		local cf = CFrame.lookAt(ground, lookAt)
		positions[shop.id] = ground
		local prompt = buildMerchant(shop, cf, folder)
		prompt.Triggered:Connect(function(player: Player)
			local data = PlayerData.Get(player)
			if not data or data.act ~= 2 then
				return
			end
			Remotes.Notify:FireClient(player, "OpenShop", { shop = shop.id })
		end)
	end
end

return ShopService
