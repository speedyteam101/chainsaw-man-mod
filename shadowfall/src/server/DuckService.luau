--!nonstrict
-- Biscuit, your call duck. Saved in the intro, then follows you for the whole game.
-- Being near Biscuit restores sanity and health. You can pet Biscuit for an extra boost.
-- The client (DuckClient) handles the waddling, quacking and advice bubbles.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)
local PlayerData = require(script.Parent.PlayerData)

local DuckService = {}

local S = Config.Sanity
local ducks: { [Player]: any } = {}
local folder: Folder

local WHITE = Color3.fromRGB(252, 250, 244)
local ORANGE = Color3.fromRGB(255, 165, 40)

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

-- A small, round, very white call duck with rosy cheeks.
local function buildDuck(owner: Player): Model
	local model = Instance.new("Model")
	model.Name = "Biscuit"
	local origin = CFrame.new()
	local root = piece(model, "HumanoidRootPart", Vector3.new(1.4, 1.2, 1.8), WHITE, origin)
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = true
	root.Massless = false
	model.PrimaryPart = root

	local body = piece(model, "Body", Vector3.new(1.6, 1.25, 2), WHITE, origin)
	joint("Waddle", root, body, CFrame.new(), CFrame.new())
	local chest = piece(model, "Chest", Vector3.new(1.4, 1, 0.6), WHITE, body.CFrame * CFrame.new(0, 0.1, -1.05))
	weldTo(body, chest)
	local tail = piece(model, "Tail", Vector3.new(0.7, 0.45, 0.5), WHITE, body.CFrame * CFrame.new(0, 0.4, 1.1) * CFrame.Angles(math.rad(30), 0, 0))
	weldTo(body, tail)

	local head = piece(model, "Head", Vector3.new(1.15, 1.1, 1.1), WHITE, origin)
	joint("Neck", body, head, CFrame.new(0, 1.0, -0.95), CFrame.new())
	local beak = piece(model, "Beak", Vector3.new(0.75, 0.3, 0.6), ORANGE, head.CFrame * CFrame.new(0, -0.12, -0.78))
	weldTo(head, beak)
	for _, side in { -1, 1 } do
		local eye = piece(model, "Eye", Vector3.new(0.17, 0.24, 0.05), Color3.fromRGB(20, 20, 24), head.CFrame * CFrame.new(0.3 * side, 0.16, -0.57))
		weldTo(head, eye)
		local sparkle = piece(model, "Sparkle", Vector3.new(0.06, 0.06, 0.03), Color3.new(1, 1, 1), head.CFrame * CFrame.new(0.3 * side + 0.03, 0.22, -0.6))
		sparkle.Material = Enum.Material.Neon
		weldTo(head, sparkle)
		local cheek = piece(model, "Cheek", Vector3.new(0.24, 0.13, 0.04), Color3.fromRGB(255, 160, 180), head.CFrame * CFrame.new(0.43 * side, -0.12, -0.57))
		weldTo(head, cheek)
		local wing = piece(model, "Wing", Vector3.new(0.22, 0.85, 1.35), Color3.fromRGB(240, 238, 230), origin)
		joint(side < 0 and "WingL" or "WingR", body, wing, CFrame.new(0.82 * side, 0.45, 0.1), CFrame.new(0, 0.4, 0))
		local leg = piece(model, "Leg", Vector3.new(0.18, 0.45, 0.18), ORANGE, body.CFrame * CFrame.new(0.35 * side, -0.78, 0))
		weldTo(body, leg)
		local foot = piece(model, "Foot", Vector3.new(0.5, 0.12, 0.55), ORANGE, body.CFrame * CFrame.new(0.35 * side, -0.97, -0.15))
		weldTo(body, foot)
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
