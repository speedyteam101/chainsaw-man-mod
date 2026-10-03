--!nonstrict
-- Biscuit, your call duck. Saved in the intro, then follows you for the whole game.
-- Being near Biscuit restores sanity and health. You can pet Biscuit for an extra boost.
-- The client (DuckClient) handles the waddling, quacking and advice bubbles.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Passes = require(ReplicatedStorage.Shared.Passes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)
local PlayerData = require(script.Parent.PlayerData)

local DuckService = {}

local S = Config.Sanity
local ducks: { [Player]: any } = {}
local folder: Folder

local WHITE = Color3.fromRGB(252, 250, 244)

local function piece(model: Model, name: string, size: Vector3, color: Color3, cf: CFrame, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = cf
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function weldTo(part0: BasePart, part1: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part1
end

local function joint(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part0
	part1.CFrame = part0.CFrame * c0 * c1:Inverse()
	return m
end

-- An ellipsoid: a part whose sphere mesh stretches to its size, for smooth rounded shapes.
local function blob(model: Model, name: string, size: Vector3, color: Color3, cf: CFrame)
	local p = piece(model, name, size, color, cf)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Biscuit: a white call duck built from smooth rounded shapes. Round body and chest, a big round
-- head on a short neck, a short orange bill whose lower half opens when Biscuit quacks, small dark
-- eyes with a glint, folded wings with grey-tipped flight feathers, a little upturned tail, and
-- orange legs with webbed feet. Head, bill, wings and tail are jointed so the client can animate
-- them.
local function buildDuck(owner: Player): Model
	local model = Instance.new("Model")
	model.Name = "Biscuit"
	local origin = CFrame.new()
	local CREAM = Color3.fromRGB(246, 243, 234)
	local BILL = Color3.fromRGB(240, 160, 50)
	local root = piece(model, "HumanoidRootPart", Vector3.new(1.4, 1.2, 1.8), WHITE, origin)
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = true
	root.Massless = false
	model.PrimaryPart = root

	local body = blob(model, "Body", Vector3.new(1.55, 1.3, 2.2), WHITE, origin)
	joint("Waddle", root, body, CFrame.new(), CFrame.new())
	weldTo(body, blob(model, "Chest", Vector3.new(1.35, 1.25, 1.1), WHITE, body.CFrame * CFrame.new(0, 0.18, -0.85)))
	weldTo(body, blob(model, "Belly", Vector3.new(1.3, 0.8, 1.6), CREAM, body.CFrame * CFrame.new(0, -0.32, -0.1)))

	-- Tail: a small upturned tuft with a curled feather.
	local tail = blob(model, "Tail", Vector3.new(0.75, 0.55, 0.8), WHITE, origin)
	joint("TailJoint", body, tail, CFrame.new(0, 0.32, 1.05) * CFrame.Angles(math.rad(35), 0, 0), CFrame.new())
	local curl = piece(model, "TailCurl", Vector3.new(0.12, 0.35, 0.3), WHITE, tail.CFrame * CFrame.new(0, 0.32, 0.12) * CFrame.Angles(math.rad(-40), 0, 0))
	weldTo(tail, curl)

	-- Head on a short neck.
	weldTo(body, blob(model, "NeckFeathers", Vector3.new(0.85, 0.9, 0.85), WHITE, body.CFrame * CFrame.new(0, 0.75, -0.95)))
	local head = blob(model, "Head", Vector3.new(1.05, 1, 1.05), WHITE, origin)
	joint("Neck", body, head, CFrame.new(0, 1.15, -1.05), CFrame.new())
	local upperBill = blob(model, "Bill", Vector3.new(0.5, 0.2, 0.55), BILL, head.CFrame * CFrame.new(0, -0.08, -0.62))
	weldTo(head, upperBill)
	local lowerBill = blob(model, "LowerBill", Vector3.new(0.44, 0.13, 0.48), Color3.fromRGB(230, 145, 45), origin)
	joint("Jaw", head, lowerBill, CFrame.new(0, -0.2, -0.38), CFrame.new(0, 0, 0.2))
	weldTo(head, piece(model, "BillTip", Vector3.new(0.14, 0.05, 0.1), Color3.fromRGB(200, 120, 40), head.CFrame * CFrame.new(0, -0.03, -0.88)))
	for _, side in { -1, 1 } do
		local eye = blob(model, "Eye", Vector3.new(0.13, 0.15, 0.1), Color3.fromRGB(16, 14, 16), head.CFrame * CFrame.new(0.38 * side, 0.12, -0.36))
		weldTo(head, eye)
		local glint = blob(model, "Glint", Vector3.new(0.045, 0.045, 0.02), Color3.new(1, 1, 1), head.CFrame * CFrame.new(0.4 * side, 0.16, -0.405))
		glint.Material = Enum.Material.Neon
		weldTo(head, glint)

		-- Folded wing with grey-tipped flight feathers along the back.
		local wing = blob(model, "Wing", Vector3.new(0.28, 0.85, 1.6), Color3.fromRGB(240, 238, 230), origin)
		joint(side < 0 and "WingL" or "WingR", body, wing, CFrame.new(0.68 * side, 0.32, 0.15), CFrame.new(0, 0.3, -0.1))
		local tips = blob(model, "WingTip", Vector3.new(0.22, 0.45, 0.9), Color3.fromRGB(205, 205, 205), wing.CFrame * CFrame.new(0, -0.05, 0.55))
		weldTo(wing, tips)

		-- Leg and webbed foot.
		weldTo(body, piece(model, "Leg", Vector3.new(0.14, 0.42, 0.14), BILL, body.CFrame * CFrame.new(0.32 * side, -0.82, 0.05)))
		local web = piece(model, "Foot", Vector3.new(0.5, 0.06, 0.5), BILL, body.CFrame * CFrame.new(0.32 * side, -1.0, -0.18))
		weldTo(body, web)
		for toe = -1, 1 do
			weldTo(body, piece(model, "Toe", Vector3.new(0.07, 0.06, 0.42), Color3.fromRGB(225, 140, 40), body.CFrame * CFrame.new(0.32 * side + toe * 0.17, -0.99, -0.34) * CFrame.Angles(0, math.rad(toe * 22), 0)))
		end
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 0.42
	humanoid.WalkSpeed = 16
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.Parent = model

	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(120, 22)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 235, 170)
	label.TextStrokeTransparency = 0.4
	label.Text = "Biscuit"
	label.Parent = tag
	tag.Parent = head

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pet"
	prompt.ObjectText = "Biscuit"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = "Ducks"
		end
	end
	model:SetAttribute("Owner", owner.UserId)
	CollectionService:AddTag(model, "Duck")
	return model
end

-- Biscuit's Wardrobe: little outfits welded onto the head or body.
function DuckService.ApplyOutfit(player: Player)
	local duck = ducks[player]
	if not duck then
		return
	end
	local old = duck.model:FindFirstChild("Outfit")
	if old then
		old:Destroy()
	end
	local data = PlayerData.Get(player)
	if not data or not (data.passes and data.passes.wardrobe) then
		return
	end
	local outfit = Passes.DuckOutfits[data.duckOutfit or 1]
	local head = duck.model:FindFirstChild("Head") :: BasePart?
	local body = duck.model:FindFirstChild("Body") :: BasePart?
	if not outfit or outfit == "None" or not head or not body then
		return
	end
	local holder = Instance.new("Model")
	holder.Name = "Outfit"
	holder.Parent = duck.model
	local function add(anchor: BasePart, name: string, size: Vector3, color: Color3, offset: CFrame, shape: Enum.PartType?)
		local p = piece(holder, name, size, color, anchor.CFrame * offset, shape)
		weldTo(anchor, p)
		return p
	end
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- cylinders point along X; this stands them up
	if outfit == "Bow Tie" then
		local red = Color3.fromRGB(190, 30, 40)
		add(body, "BowL", Vector3.new(0.3, 0.26, 0.1), red, CFrame.new(-0.17, 0.62, -1.4) * CFrame.Angles(0, 0, math.rad(12)))
		add(body, "BowR", Vector3.new(0.3, 0.26, 0.1), red, CFrame.new(0.17, 0.62, -1.4) * CFrame.Angles(0, 0, math.rad(-12)))
		add(body, "Knot", Vector3.new(0.13, 0.13, 0.12), Color3.fromRGB(150, 20, 30), CFrame.new(0, 0.62, -1.42))
	elseif outfit == "Top Hat" then
		local black = Color3.fromRGB(20, 18, 22)
		add(head, "Brim", Vector3.new(0.06, 0.9, 0.9), black, CFrame.new(0, 0.47, 0.05) * upright, Enum.PartType.Cylinder)
		add(head, "Crown", Vector3.new(0.55, 0.6, 0.6), black, CFrame.new(0, 0.78, 0.05) * upright, Enum.PartType.Cylinder)
		add(head, "Band", Vector3.new(0.12, 0.62, 0.62), Color3.fromRGB(170, 30, 40), CFrame.new(0, 0.58, 0.05) * upright, Enum.PartType.Cylinder)
	elseif outfit == "Flower Crown" then
		local colors = { Color3.fromRGB(255, 150, 190), Color3.fromRGB(255, 240, 140), Color3.fromRGB(190, 160, 255) }
		for i = 1, 8 do
			local angle = (i / 8) * math.pi * 2
			local offset = CFrame.new(math.cos(angle) * 0.42, 0.4, math.sin(angle) * 0.42)
			add(head, "Flower", Vector3.new(0.17, 0.17, 0.17), colors[(i % #colors) + 1], offset, Enum.PartType.Ball)
			add(head, "Leaf", Vector3.new(0.1, 0.04, 0.16), Color3.fromRGB(90, 170, 90), offset * CFrame.new(0, -0.06, 0.08))
		end
	elseif outfit == "Scarf" then
		local red = Color3.fromRGB(200, 40, 50)
		add(body, "Wrap", Vector3.new(0.95, 0.24, 0.95), red, CFrame.new(0, 0.66, -0.95))
		add(body, "Stripe", Vector3.new(0.97, 0.07, 0.97), Color3.new(1, 1, 1), CFrame.new(0, 0.66, -0.95))
		add(body, "Tail", Vector3.new(0.22, 0.55, 0.08), red, CFrame.new(0.3, 0.38, -1.42) * CFrame.Angles(0, 0, math.rad(-10)))
	end
end

function DuckService.Get(player: Player)
	return ducks[player]
end

-- Spawns (or moves) the player's duck. `scared` = cowering, not following (the intro).
function DuckService.Place(player: Player, cf: CFrame, scared: boolean?)
	local duck = ducks[player]
	if not duck then
		local model = buildDuck(player)
		model.Parent = folder
		duck = { model = model, humanoid = model:FindFirstChildOfClass("Humanoid"), root = model.PrimaryPart, lastPet = 0 }
		ducks[player] = duck
		DuckService.ApplyOutfit(player)
		model.PrimaryPart.ProximityPrompt.Triggered:Connect(function(who: Player)
			if who ~= player or duck.state ~= "follow" then
				return
			end
			local now = os.clock()
			Remotes.Fx:FireAllClients("Hearts", { model = model })
			if now - duck.lastPet >= S.PetCooldown then
				duck.lastPet = now
				Registry.SanityChange:Fire(player, S.PetBonus)
				Remotes.Notify:FireClient(player, "DuckSay", { text = "Quack! (Biscuit leans into your hand. You feel a little steadier.)" })
			else
				Remotes.Notify:FireClient(player, "DuckSay", { text = "*happy quack*" })
			end
		end)
		pcall(function()
			model.PrimaryPart:SetNetworkOwner(nil)
		end)
	end
	duck.state = scared and "scared" or "follow"
	duck.model:SetAttribute("Scared", scared == true)
	duck.model:PivotTo(cf)
	duck.root.AssemblyLinearVelocity = Vector3.zero
	return duck
end

function DuckService.SetFollowing(player: Player)
	local duck = ducks[player]
	if duck then
		duck.state = "follow"
		duck.model:SetAttribute("Scared", false)
	end
end

function DuckService.IsNear(player: Player): boolean
	local duck = ducks[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not duck or duck.state ~= "follow" or not root then
		return false
	end
	return (duck.root.Position - root.Position).Magnitude <= S.DuckRange
end

function DuckService.Remove(player: Player)
	local duck = ducks[player]
	if duck then
		duck.model:Destroy()
		ducks[player] = nil
	end
end

local function follow(player: Player, duck)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		duck.humanoid:MoveTo(duck.root.Position)
		return
	end
	local target = (root.CFrame * CFrame.new(3, -2, -4.5)).Position
	local offset = target - duck.root.Position
	local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if distance > 50 or math.abs(offset.Y) > 14 then
		-- Too far behind (warped, fell, respawned): hop straight to you.
		duck.model:PivotTo(CFrame.lookAt(target + Vector3.new(0, 1.1, 0), root.Position * Vector3.new(1, 0, 1) + Vector3.new(0, target.Y + 1.1, 0)))
		duck.root.AssemblyLinearVelocity = Vector3.zero
		Remotes.Fx:FireAllClients("Hearts", { model = duck.model, small = true })
	elseif distance > 2 then
		duck.humanoid.WalkSpeed = distance > 10 and 30 or (distance > 5 and 20 or 12)
		duck.humanoid:MoveTo(target)
	else
		duck.humanoid:MoveTo(duck.root.Position)
	end
	if duck.root.Position.Y < -60 then
		duck.model:PivotTo(CFrame.new(target + Vector3.new(0, 1.1, 0)))
	end
end

function DuckService.Start()
	-- Ducks and players pass through each other so Biscuit can walk in front of you.
	if not PhysicsService:IsCollisionGroupRegistered("Ducks") then
		PhysicsService:RegisterCollisionGroup("Ducks")
	end
	if not PhysicsService:IsCollisionGroupRegistered("Players") then
		PhysicsService:RegisterCollisionGroup("Players")
	end
	PhysicsService:CollisionGroupSetCollidable("Ducks", "Players", false)
	local function groupCharacter(character: Model)
		for _, p in character:GetDescendants() do
			if p:IsA("BasePart") then
				p.CollisionGroup = "Players"
			end
		end
		character.DescendantAdded:Connect(function(p)
			if p:IsA("BasePart") then
				p.CollisionGroup = "Players"
			end
		end)
	end
	local function watchPlayer(p: Player)
		if p.Character then
			groupCharacter(p.Character)
		end
		p.CharacterAdded:Connect(groupCharacter)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end

	folder = Instance.new("Folder")
	folder.Name = "Ducks"
	folder.Parent = workspace

	-- Players who already saved Biscuit get the duck back whenever they spawn.
	Players.PlayerRemoving:Connect(DuckService.Remove)

	task.spawn(function()
		while true do
			task.wait(0.15)
			for player, duck in ducks do
				if not player.Parent or not duck.model.Parent then
					ducks[player] = nil
				elseif duck.state == "follow" then
					local ok, err = pcall(follow, player, duck)
					if not ok then
						warn("[Shadowfall] duck error:", err)
					end
				end
			end
		end
	end)
end

-- Called on every spawn: bring Biscuit along if the player has saved them.
function DuckService.OnCharacter(player: Player, character: Model)
	local data = PlayerData.Get(player)
	if not data or not data.duckSaved then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait(0.3)
	DuckService.Place(player, (root :: BasePart).CFrame * CFrame.new(3, -1.9, -4.5), false)
end

return DuckService
