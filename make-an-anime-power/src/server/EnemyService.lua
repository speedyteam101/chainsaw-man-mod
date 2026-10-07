-- Training dummies (stand still, heal back up) and arena enemies (chase,
-- punch and shoot at players). Both respawn after being defeated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Status = require(script.Parent.Status)
local CombatService = require(script.Parent.CombatService)
local World = require(script.Parent.World)

local EnemyService = {}

local ENEMY_KINDS = {
	{
		name = "Rogue Ninja",
		element = "Wind",
		health = 120,
		damage = 9,
		speed = 20,
		color = Color3.fromRGB(60, 70, 80),
		attackName = "Wind Star!",
	},
	{
		name = "Fire Cultist",
		element = "Fire",
		health = 140,
		damage = 10,
		speed = 15,
		color = Color3.fromRGB(170, 50, 30),
		attackName = "Hellfire!",
	},
	{
		name = "Ice Phantom",
		element = "Ice",
		health = 130,
		damage = 9,
		speed = 16,
		color = Color3.fromRGB(150, 210, 240),
		attackName = "Frost Bite!",
	},
	{
		name = "Thunder Brute",
		element = "Lightning",
		health = 260,
		damage = 14,
		speed = 12,
		color = Color3.fromRGB(200, 180, 40),
		attackName = "Thunder Smash!",
	},
	{
		name = "Shadow Fiend",
		element = "Shadow",
		health = 160,
		damage = 11,
		speed = 17,
		color = Color3.fromRGB(70, 30, 100),
		attackName = "Night Claw!",
	},
}

local AGGRO_RANGE = 90
local MELEE_RANGE = 6
local MELEE_COOLDOWN = 1.2
local SHOT_COOLDOWN = 3.5

local folder: Folder
local enemies = {} -- list of enemy records driven by the AI loop

----------------------------------------------------------------------
-- Rigs
----------------------------------------------------------------------

-- A plain blocky rig, only used if Roblox can't build a normal character.
local function fallbackRig(color: Color3): Model
	local model = Instance.new("Model")

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.Parent = model
	model.PrimaryPart = root

	local function limb(name: string, size: Vector3, offset: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.CFrame = root.CFrame * CFrame.new(offset)
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	limb("Torso", Vector3.new(2, 2, 1), Vector3.zero)
	limb("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0))
	limb("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0))
	limb("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0))
	limb("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0))
	limb("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0))

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.Parent = model
	return model
end

local function makeRig(color: Color3): Model
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = color:Lerp(Color3.new(1, 1, 1), 0.3)
		description.TorsoColor = color
		description.LeftArmColor = color
		description.RightArmColor = color
		description.LeftLegColor = color:Lerp(Color3.new(0, 0, 0), 0.3)
		description.RightLegColor = color:Lerp(Color3.new(0, 0, 0), 0.3)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		return model
	end
	warn("[EnemyService] Using fallback rig:", model)
	return fallbackRig(color)
end

local function randomArenaPoint(): Vector3
	local arena = World.Arena
	local half = math.floor(arena.size / 2 - 12)
	return arena.center + Vector3.new(math.random(-half, half), 0, math.random(-half, half))
end

----------------------------------------------------------------------
-- Dummies
----------------------------------------------------------------------

local function spawnDummy(position: Vector3)
	local model = makeRig(Color3.fromRGB(210, 160, 90))
	model.Name = "Training Dummy"
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayName = "Training Dummy"
	humanoid.MaxHealth = 400
	humanoid.Health = 400
	humanoid.WalkSpeed = 0
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	root.Anchored = true
	model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.pi, 0))
	model.Parent = folder

	-- Heal back to full after a few seconds without being hit
	local lastHit = 0
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth then
			lastHit = os.clock()
		end
		lastHealth = health
	end)
	task.spawn(function()
		while model.Parent and humanoid.Health > 0 do
			task.wait(1)
			if humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth and os.clock() - lastHit > 4 then
				humanoid.Health = humanoid.MaxHealth
			end
		end
	end)

	humanoid.Died:Connect(function()
		task.wait(3)
		model:Destroy()
		spawnDummy(position)
	end)
end

----------------------------------------------------------------------
-- Enemies
----------------------------------------------------------------------

local spawnEnemy

local function onEnemyDied(record)
	local index = table.find(enemies, record)
	if index then
		table.remove(enemies, index)
	end
	task.delay(3, function()
		record.model:Destroy()
	end)
	task.delay(Config.EnemyRespawnTime, function()
		spawnEnemy(record.kind)
	end)
end

function spawnEnemy(kind)
	local model = makeRig(kind.color)
	model.Name = kind.name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayName = kind.name
	humanoid.MaxHealth = kind.health
	humanoid.Health = kind.health
	humanoid.WalkSpeed = kind.speed
	model:SetAttribute("DamageMultiplier", 1)
	model:PivotTo(CFrame.new(randomArenaPoint() + Vector3.new(0, 4, 0)))
	model.Parent = folder
	Status.setBaseSpeed(humanoid, kind.speed)

	-- Let the server simulate enemy physics so knockback is smooth
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local record = {
		model = model,
		humanoid = humanoid,
		root = root,
		kind = kind,
		lastMelee = 0,
		lastShot = os.clock(),
		wanderTarget = nil :: Vector3?,
		nextWander = 0,
	}
	table.insert(enemies, record)
	humanoid.Died:Connect(function()
		onEnemyDied(record)
	end)
end

local function nearestPlayer(position: Vector3)
	local best, bestDistance = nil, AGGRO_RANGE
	for _, target in CombatService.getTargets() do
		if target.player and not CombatService.inSafeZone(target.root.Position) then
			local distance = (target.root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = target, distance
			end
		end
	end
	return best, bestDistance
end

local function think(record)
	local root = record.root
	local humanoid = record.humanoid
	if humanoid.Health <= 0 or Status.isStunned(humanoid) then
		return
	end
	local now = os.clock()
	local kind = record.kind

	-- Don't wander off too far from the arena
	local arena = World.Arena
	local fromCenter = Vector3.new(root.Position.X - arena.center.X, 0, root.Position.Z - arena.center.Z).Magnitude
	if fromCenter > arena.size * 0.8 then
		humanoid:MoveTo(arena.center)
		return
	end

	local target, distance = nearestPlayer(root.Position)
	if target then
		local offset = target.root.Position - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local facing = flat.Magnitude > 0.1 and flat.Unit or root.CFrame.LookVector

		if distance > MELEE_RANGE - 1 then
			humanoid:MoveTo(target.root.Position)
		end

		if distance <= MELEE_RANGE and now - record.lastMelee >= MELEE_COOLDOWN then
			record.lastMelee = now
			CombatService.fx("Slash", {
				cframe = CFrame.lookAt(root.Position, root.Position + facing),
				reach = MELEE_RANGE,
				color = Color3.new(1, 1, 1),
				flip = math.random() < 0.5,
				small = true,
			})
			CombatService.frontHit(record.model, root, facing, MELEE_RANGE, kind.damage, kind.element, 20)
		elseif distance > 14 and distance < 70 and now - record.lastShot >= SHOT_COOLDOWN then
			record.lastShot = now + math.random() -- a little randomness so they don't all fire together
			local origin = root.Position + Vector3.new(0, 1, 0)
			local direction = (target.root.Position - origin).Unit
			CombatService.fx(
				"Shout",
				{ character = record.model, text = kind.attackName, color = Color3.new(1, 0.4, 0.4) }
			)
			CombatService.fireProjectile(record.model, origin + direction * 2, direction, {
				damage = kind.damage * 0.8,
				radius = 1,
				speed = 70,
				range = 120,
				element = kind.element,
			})
		end
	else
		-- Wander around the arena
		if not record.wanderTarget or now >= record.nextWander then
			record.wanderTarget = randomArenaPoint()
			record.nextWander = now + math.random(4, 8)
			humanoid:MoveTo(record.wanderTarget)
		end
	end
end

function EnemyService.init(enemiesFolder: Folder)
	folder = enemiesFolder

	local row = World.DummyRow
	for i = 1, Config.DummyCount do
		local x = (i - (Config.DummyCount + 1) / 2) * row.spacing
		task.spawn(spawnDummy, row.center + Vector3.new(x, 0, 0))
	end

	for i = 1, Config.EnemyCount do
		task.spawn(spawnEnemy, ENEMY_KINDS[(i - 1) % #ENEMY_KINDS + 1])
	end

	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, record in table.clone(enemies) do
				local ok, err = pcall(think, record)
				if not ok then
					warn("[EnemyService]", err)
				end
			end
		end
	end)
end

return EnemyService
