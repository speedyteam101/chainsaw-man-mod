--!nonstrict
-- Demolishing houses to make room for your base.
--
-- Every house in Hollow Creek (and every cabin in the Woods) has a "Demolish" prompt: hold E and
-- it comes down in a cloud of dust, leaving salvage behind. Houses you knock down inside or right
-- next to your own base barrier stay down: they're cleared again every time your base loads.
-- Houses demolished anywhere else come back when the server restarts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local InventoryService = require(script.Parent.InventoryService)

local HouseService = {}

local HOLD_SECONDS = 2.5
local SALVAGE = { Wood = 12, Stone = 5, Scrap = 4 }
local KEEP_MARGIN = 20 -- houses this close to your barrier stay demolished

local houses = {} -- [key] = { key, model, center, size, alive, prompt }

-- Houses are identified by where they stand (rounded), so saved lists survive map changes:
-- a house that no longer exists at that spot is simply not found.
local function keyOf(position: Vector3): string
	return string.format("%d,%d", math.floor(position.X + 0.5), math.floor(position.Z + 0.5))
end

local function within(house, center: Vector3, radius: number): boolean
	return Vector2.new(house.center.X - center.X, house.center.Z - center.Z).Magnitude <= radius + KEEP_MARGIN
end
local rng = Random.new()

local function partsOf(house): { BasePart }
	local parts = {}
	for _, d in house.model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif d:IsA("ObjectValue") and d.Name == "FloorRef" and d.Value and d.Value:IsA("BasePart") then
			table.insert(parts, d.Value)
		end
	end
	return parts
end

-- Brings a house down. `quiet` skips the collapse and the salvage (used when a base loads).
function HouseService.Demolish(house, player: Player?, quiet: boolean?)
	if not house.alive then
		return
	end
	house.alive = false
	if house.prompt then
		house.prompt:Destroy()
		house.prompt = nil
	end
	local parts = partsOf(house)
	if quiet then
		for _, p in parts do
			p:Destroy()
		end
		house.model:Destroy()
		return
	end

	Remotes.Fx:FireAllClients("Demolish", { position = house.center, ground = house.center - Vector3.new(0, house.size.Y / 2, 0), size = house.size })
	-- The floor goes at once; the rest collapses inwards and down under its own weight.
	for _, p in parts do
		if p.Name == "Floor" or p.Name == "Porch" or p.Name == "Step" or p.Name == "Walkway" then
			p:Destroy()
		else
			for _, light in p:GetChildren() do
				if light:IsA("Light") then
					light.Enabled = false
				end
			end
			p.CanQuery = false
			p.CanTouch = false
			p.CollisionGroup = "Debris"
			p.Anchored = false
			local inward = house.center - p.Position
			inward = Vector3.new(inward.X, 0, inward.Z)
			local push = inward.Magnitude > 0.1 and inward.Unit * rng:NextNumber(4, 12) or Vector3.zero
			p.AssemblyLinearVelocity = push + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-4, 4), rng:NextNumber(-3, 3))
			p.AssemblyAngularVelocity = rng:NextUnitVector() * rng:NextNumber(0.5, 2.5)
		end
	end
	task.delay(5, function()
		house.model:Destroy()
	end)

	if player then
		for id, amount in SALVAGE do
			InventoryService.Add(player, id, amount, true)
		end
		Remotes.Notify:FireClient(player, "Toast", { text = "Demolished. You salvage some wood, stone and scrap.", color = Color3.fromRGB(230, 200, 150) })
		-- Inside (or right beside) your own base: keep it cleared for good.
		local center = player:GetAttribute("BaseCenter")
		local radius = player:GetAttribute("BaseRadius") or 0
		if typeof(center) == "Vector3" and radius > 0 then
			HouseService.Remember(player, center, radius)
		end
	end
end

-- Knocks down (quietly) the houses this player cleared around a base at `center`, and forgets any
-- saved entries that aren't near it (e.g. after the base moved). Call before checking the spot.
function HouseService.ClearAt(player: Player, center: Vector3, radius: number)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	data.base.cleared = data.base.cleared or {}
	for key in table.clone(data.base.cleared) do
		local house = houses[key]
		if house and within(house, center, radius) then
			HouseService.Demolish(house, nil, true)
		else
			data.base.cleared[key] = nil
		end
	end
end

-- Saves every house that is already down around a base (whoever demolished it), so it stays down
-- next time. Called when the crystal is placed, when the barrier grows, and after a demolition.
function HouseService.Remember(player: Player, center: Vector3, radius: number)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	data.base.cleared = data.base.cleared or {}
	for key, house in houses do
		if not house.alive and within(house, center, radius) then
			data.base.cleared[key] = true
		end
	end
end

function HouseService.Start(world)
	for _, entry in world.houses or {} do
		local model = entry.model
		if model and model.Parent then
			local cf, size = model:GetBoundingBox()
			local key = keyOf(entry.cf and entry.cf.Position or cf.Position)
			local house = { key = key, model = model, center = cf.Position, size = size, alive = true }
			houses[key] = house
			local anchor = Instance.new("Part")
			anchor.Name = "DemolishPoint"
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Transparency = 1
			anchor.Size = Vector3.one
			anchor.CFrame = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 + 4, cf.Position.Z)
			anchor.Parent = model
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Demolish"
			prompt.ObjectText = model.Name
			prompt.HoldDuration = HOLD_SECONDS
			prompt.MaxActivationDistance = math.max(size.X, size.Z) / 2 + 6
			prompt.RequiresLineOfSight = false
			prompt.Style = Enum.ProximityPromptStyle.Default
			prompt.Parent = anchor
			house.prompt = prompt
			prompt.Triggered:Connect(function(player: Player)
				local data = PlayerData.Get(player)
				if data and data.act == 2 then
					HouseService.Demolish(house, player, false)
				end
			end)
		end
	end
end

return HouseService
