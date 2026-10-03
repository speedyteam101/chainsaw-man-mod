--!nonstrict
-- Spawns and drives every Act 2 shadow and boss. All attacks have a wind-up: the eyes turn red,
-- big attacks draw a red telegraph on the ground, and stunning a shadow mid-wind-up cancels it.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Areas)
local Config = require(ReplicatedStorage.Shared.Config)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShadowRig = require(ReplicatedStorage.Shared.ShadowRig)
local Registry = require(script.Parent.Registry)
local Combat = require(script.Parent.Combat)
local Projectiles = require(script.Parent.Projectiles)
local PlayerData = require(script.Parent.PlayerData)
local WorldBuilder = require(script.Parent.World.WorldBuilder)

local EnemyService = {}

local TICK = 0.1
local RED = Color3.fromRGB(255, 30, 30)
local rng = Random.new()
local spawnPoints = {} -- [areaId] = { Vector3 }
local folder: Folder
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include

local function groundAt(position: Vector3): Vector3
	local hit = workspace:Raycast(position + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), floorParams)
	return hit and hit.Position or Vector3.new(position.X, 0, position.Z)
end

-- Red disc on the ground that fills up over `duration` (the client animates the fill).
local function telegraphCircle(position: Vector3, radius: number, duration: number)
	local ground = groundAt(position)
	local p = Instance.new("Part")
	p.Name = "Telegraph"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.2, radius * 2, radius * 2)
	p.CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = RED
	p.Transparency = 0.75
	p:SetAttribute("Duration", duration)
	CollectionService:AddTag(p, "Telegraph")
	p.Parent = workspace
	Debris:AddItem(p, duration + 0.05)
	return ground
end

local function telegraphLine(from: Vector3, to: Vector3, width: number, duration: number)
	local ground = groundAt(from)
	local flatTo = Vector3.new(to.X, ground.Y, to.Z)
	local mid = (ground + flatTo) / 2
	local p = Instance.new("Part")
	p.Name = "Telegraph"
	p.Size = Vector3.new(width, 0.2, (flatTo - ground).Magnitude)
	p.CFrame = CFrame.lookAt(mid, flatTo) + Vector3.new(0, 0.15, 0)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = RED
	p.Transparency = 0.75
	p:SetAttribute("Duration", duration)
	CollectionService:AddTag(p, "Telegraph")
	p.Parent = workspace
	Debris:AddItem(p, duration + 0.05)
end

-- Creation ---------------------------------------------------------------------------------

local function create(def, area, position: Vector3, bossId: string?)
	local isBoss = bossId ~= nil
	local scale = def.scale or 1
	local model = ShadowRig.Build({
		name = def.name,
		scale = scale,
		eyeColor = def.eyeColor or Color3.fromRGB(230, 230, 255),
		armLength = def.behaviour == "wraith" and 1.35 or 1,
		antlers = def.antlers,
		crown = def.crown,
		manyEyes = def.manyEyes,
		smokeRate = isBoss and 30 or 14,
	})
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	local ground = groundAt(position)
	model:PivotTo(CFrame.new(ground + Vector3.new(0, 3 * scale + 0.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	humanoid.WalkSpeed = def.speed
	humanoid.MaxHealth = 1e6
	humanoid.Health = 1e6

	local maxHp = math.floor(def.hp * (isBoss and 1 or area.hpMult))
	model:SetAttribute("EnemyName", def.name)
	model:SetAttribute("MaxHealth", maxHp)
	model:SetAttribute("Health", maxHp)
	model:SetAttribute("Boss", isBoss)
	model:SetAttribute("AreaLevel", area.level)
	CollectionService:AddTag(model, "Enemy")
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local enemy = {
		model = model,
		humanoid = humanoid,
		root = root,
		def = def,
		area = area,
		isBoss = isBoss,
		bossId = bossId,
		scale = scale,
		hp = maxHp,
		maxHp = maxHp,
		damage = def.damage * (isBoss and 1 or area.damageMult),
		home = ground,
		state = "idle",
		nextAttack = os.clock() + rng:NextNumber(0.5, 1.5),
		nextBlink = os.clock() + (def.blinkCooldown or 0),
		stunUntil = 0,
		slowMult = 1,
		slowUntil = 0,
		weakenMult = 1,
		weakenUntil = 0,
		damagers = {},
		hitPlayers = {},
		lastMoveCheck = os.clock(),
		lastPosition = ground,
		phase = 1,
	}
	Registry.Enemies[model] = enemy
	return enemy
end

local function randomSpawn(area)
	local points = spawnPoints[area.id]
	if points and #points > 0 then
		return points[rng:NextInteger(1, #points)]
	end
	return area.center
end

local function spawnEnemy(typeName: string, area, position: Vector3?)
	return create(Enemies.Types[typeName], area, position or randomSpawn(area))
end

local function spawnBoss(bossId: string, area)
	local def = Enemies.Bosses[bossId]
	local enemy = create(def, area, area.boss.arena, bossId)
	enemy.home = groundAt(area.boss.arena)
	Remotes.Fx:FireAllClients("BossSpawn", { name = def.name, area = area.name })
	return enemy
end

-- Targeting --------------------------------------------------------------------------------

local function findTarget(enemy)
	local position = enemy.root.Position
	local aggro = enemy.isBoss and 75 or enemy.def.aggro
	local leashCenter = enemy.home
	local leash = enemy.isBoss and 95 or 90
	local best, bestDistance = nil, math.huge
	for _, target in Combat.TargetablePlayers() do
		local d = (target.root.Position - position).Magnitude
		local fromHome = (target.root.Position - leashCenter).Magnitude
		local preferred = enemy.aggroOn == target.player
		if fromHome < leash and (d < aggro or (preferred and d < aggro * 2)) then
			local score = preferred and d * 0.5 or d
			if score < bestDistance then
				best, bestDistance = target, score
			end
		end
	end
	return best
end

local function face(enemy, position: Vector3)
	local root = enemy.root
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

local function stunned(enemy)
	return os.clock() < enemy.stunUntil or enemy.dead
end

-- Wind-up shared by every attack. Returns false if the shadow was stunned (or died) during it.
local function windup(enemy, duration: number, target)
	enemy.state = "attacking"
	enemy.model:SetAttribute("Attacking", true)
	ShadowRig.SetEyeColor(enemy.model, RED)
	enemy.humanoid.WalkSpeed = 0
	local started = os.clock()
	while os.clock() - started < duration do
		if stunned(enemy) then
			break
		end
		if target and target.root.Parent then
			face(enemy, target.root.Position)
		end
		task.wait(0.05)
	end
	local ok = not stunned(enemy)
	return ok
end

local function endAttack(enemy, cooldown: number)
	if enemy.dead then
		return
	end
	enemy.model:SetAttribute("Attacking", false)
	ShadowRig.SetEyeColor(enemy.model, enemy.def.eyeColor or Color3.fromRGB(230, 230, 255))
	enemy.nextAttack = os.clock() + cooldown * rng:NextNumber(0.85, 1.2)
	enemy.state = "chase"
end

local function hitPlayersInRadius(enemy, center: Vector3, radius: number, damage: number)
	for _, target in Combat.PlayersInSphere(center, radius) do
		Combat.DamagePlayer(target.player, damage, { enemy = enemy, position = center, kind = "aoe" })
	end
end

-- Regular attacks --------------------------------------------------------------------------

local function meleeAttack(enemy, target)
	if not windup(enemy, enemy.def.windup, target) then
		endAttack(enemy, enemy.def.cooldown * 0.5)
		return
	end
	local root = enemy.root
	root.AssemblyLinearVelocity = root.CFrame.LookVector * 30
	Remotes.Fx:FireAllClients("Claw", { model = enemy.model })
	task.wait(0.08)
	if target.root.Parent and not enemy.dead then
		local toTarget = target.root.Position - root.Position
		if toTarget.Magnitude <= enemy.def.range + 2.5 * enemy.scale then
			Combat.DamagePlayer(target.player, enemy.damage, { enemy = enemy, position = root.Position, kind = "melee" })
		end
	end
	endAttack(enemy, enemy.def.cooldown)
end

local function rangedAttack(enemy, target)
	if not windup(enemy, enemy.def.windup, target) then
		endAttack(enemy, enemy.def.cooldown * 0.5)
		return
	end
	local origin = enemy.root.Position + Vector3.new(0, 1.5 * enemy.scale, 0)
	local aim = target.root.Position + target.root.AssemblyLinearVelocity * 0.25
	Projectiles.Fire({
		team = "enemy",
		enemy = enemy,
		origin = origin,
		direction = aim - origin,
		speed = enemy.def.projectileSpeed,
		range = enemy.def.range + 10,
		radius = 1.4,
		damage = enemy.damage,
		color = Color3.fromRGB(40, 10, 60),
	})
	endAttack(enemy, enemy.def.cooldown)
end

local function slamAttack(enemy, target, radius: number, windupTime: number, damage: number)
	local center = telegraphCircle(enemy.root.Position, radius, windupTime)
	if not windup(enemy, windupTime, target) then
		return false
	end
	Remotes.Fx:FireAllClients("Shockwave", { position = center, radius = radius, color = Color3.fromRGB(20, 0, 30) })
	hitPlayersInRadius(enemy, center, radius, damage)
	return true
end

local function lunge(enemy, target)
	if not windup(enemy, enemy.def.windup, target) then
		endAttack(enemy, enemy.def.cooldown * 0.5)
		return
	end
	local root = enemy.root
	local direction = target.root.Position - root.Position
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	root.AssemblyLinearVelocity = direction * 85 + Vector3.new(0, 10, 0)
	Remotes.Fx:FireAllClients("Claw", { model = enemy.model })
	local hit = false
	for _ = 1, 6 do
		task.wait(0.05)
		if enemy.dead then
			return
		end
		if not hit and target.root.Parent and (target.root.Position - root.Position).Magnitude < 5.5 then
			hit = true
			Combat.DamagePlayer(target.player, enemy.damage * 1.2, { enemy = enemy, position = root.Position, kind = "melee" })
		end
	end
	endAttack(enemy, enemy.def.cooldown)
end

local function blink(enemy, target)
	local behind = target.root.CFrame * CFrame.new(rng:NextNumber(-2, 2), 0, 6)
	local from = enemy.root.Position
	local ground = groundAt(behind.Position)
	enemy.model:PivotTo(CFrame.lookAt(ground + Vector3.new(0, 3 * enemy.scale + 0.5, 0), Vector3.new(target.root.Position.X, ground.Y + 3 * enemy.scale + 0.5, target.root.Position.Z)))
	Remotes.Fx:FireAllClients("Blink", { from = from, to = ground })
	enemy.nextBlink = os.clock() + enemy.def.blinkCooldown
	enemy.nextAttack = os.clock()
end

-- Boss attacks -----------------------------------------------------------------------------

local function bossAttack(enemy, target)
	local def = enemy.def
	local attacks = table.clone(def.attacks)
	if enemy.phase == 2 and def.phase2 then
		table.insert(attacks, def.phase2)
	end
	local total = 0
	for _, a in attacks do
		total += a.weight
	end
	local pick = rng:NextNumber() * total
	local attack = attacks[1]
	for _, a in attacks do
		pick -= a.weight
		if pick <= 0 then
			attack = a
			break
		end
	end
	local speedUp = enemy.phase == 2 and 0.8 or 1
	local windupTime = attack.windup * speedUp
	local damage = enemy.damage * (attack.damageMult or 1)
	local root = enemy.root

	if attack.kind == "slam" then
		slamAttack(enemy, target, attack.radius, windupTime, damage)
	elseif attack.kind == "charge" then
		local direction = target.root.Position - root.Position
		direction = Vector3.new(direction.X, 0, direction.Z)
		direction = direction.Magnitude > 0.1 and direction.Unit or root.CFrame.LookVector
		local finish = root.Position + direction * attack.distance
		telegraphLine(root.Position, finish, attack.width, windupTime)
		face(enemy, finish)
		enemy.state = "attacking"
		enemy.model:SetAttribute("Attacking", true)
		ShadowRig.SetEyeColor(enemy.model, RED)
		enemy.humanoid.WalkSpeed = 0
		task.wait(windupTime)
		if not enemy.dead then
			local hit = {}
			local start = os.clock()
			local duration = attack.distance / 110
			while os.clock() - start < duration and not enemy.dead do
				root.AssemblyLinearVelocity = direction * 110
				for _, t in Combat.PlayersInSphere(groundAt(root.Position) + Vector3.new(0, 3, 0), attack.width / 2 + 2) do
					if not hit[t.player] then
						hit[t.player] = true
						Combat.DamagePlayer(t.player, damage, { enemy = enemy, position = root.Position, kind = "aoe" })
					end
				end
				task.wait(0.03)
			end
			root.AssemblyLinearVelocity = Vector3.zero
		end
	elseif attack.kind == "volley" then
		if windup(enemy, windupTime, target) then
			local origin = root.Position + Vector3.new(0, 2 * enemy.scale, 0)
			local base = target.root.Position - origin
			local baseYaw = math.atan2(-base.X, -base.Z)
			for i = 1, attack.count do
				local offset = attack.count == 1 and 0 or (i - 1) / (attack.count - (attack.spread >= 360 and 0 or 1)) * attack.spread - attack.spread / 2
				local yaw = baseYaw + math.rad(offset)
				local direction = CFrame.Angles(0, yaw, 0).LookVector
				local flatDistance = math.max(Vector3.new(base.X, 0, base.Z).Magnitude, 1)
				local drop = (target.root.Position.Y - origin.Y) / flatDistance
				Projectiles.Fire({
					team = "enemy",
					enemy = enemy,
					origin = origin,
					direction = Vector3.new(direction.X, drop, direction.Z),
					speed = attack.speed,
					range = 120,
					radius = 1.8,
					damage = damage,
					color = def.eyeColor,
				})
			end
		end
	elseif attack.kind == "summon" then
		if windup(enemy, windupTime, target) then
			enemy.adds = enemy.adds or {}
			for index = #enemy.adds, 1, -1 do
				if enemy.adds[index].dead then
					table.remove(enemy.adds, index)
				end
			end
			for _ = 1, math.min(attack.count, 6 - #enemy.adds) do
				local offset = Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14))
				local add = create(Enemies.Types[attack.type], enemy.area, root.Position + offset)
				add.isAdd = true
				add.home = enemy.home
				add.aggroOn = target.player
				table.insert(enemy.adds, add)
				Remotes.Fx:FireAllClients("Blink", { from = root.Position, to = add.root.Position })
			end
		end
	elseif attack.kind == "eruptions" then
		local spots = {}
		local targets = Combat.PlayersInSphere(enemy.home, 100)
		for i = 1, attack.count do
			local t = targets[(i - 1) % math.max(#targets, 1) + 1] or target
			local jitter = i <= #targets and Vector3.zero or Vector3.new(rng:NextNumber(-16, 16), 0, rng:NextNumber(-16, 16))
			local spot = telegraphCircle(t.root.Position + jitter, attack.radius, windupTime)
			table.insert(spots, spot)
		end
		if windup(enemy, windupTime, target) then
			for _, spot in spots do
				Remotes.Fx:FireAllClients("Eruption", { position = spot, radius = attack.radius, color = def.eyeColor })
				hitPlayersInRadius(enemy, spot, attack.radius, damage)
			end
		end
	end
	endAttack(enemy, (enemy.phase == 2 and 1.3 or 1.9))
end

-- Brain ------------------------------------------------------------------------------------

local function think(enemy)
	if enemy.dead or enemy.state == "attacking" then
		return
	end
	local now = os.clock()
	local humanoid = enemy.humanoid
	local root = enemy.root
	local def = enemy.def

	-- Burning
	if enemy.burn then
		if now < enemy.burn.untilTime then
			enemy.burnAccumulated = (enemy.burnAccumulated or 0) + enemy.burn.dps * TICK
			if enemy.burnAccumulated >= 4 then
				local amount = enemy.burnAccumulated
				enemy.burnAccumulated = 0
				Combat.DamageEnemy(enemy, amount, enemy.burn.attacker, { color = Color3.fromRGB(255, 120, 40) })
				if enemy.dead then
					return
				end
			end
		else
			enemy.burn = nil
		end
	end

	if now < enemy.stunUntil then
		humanoid.WalkSpeed = 0
		return
	end
	local speed = def.speed * (now < enemy.slowUntil and enemy.slowMult or 1)
	humanoid.WalkSpeed = speed

	-- Fell off the world
	if root.Position.Y < -60 then
		enemy.model:PivotTo(CFrame.new(enemy.home + Vector3.new(0, 3 * enemy.scale + 0.5, 0)))
		root.AssemblyLinearVelocity = Vector3.zero
		return
	end

	-- Boss phase change
	if enemy.isBoss and enemy.phase == 1 and enemy.hp <= enemy.maxHp * 0.5 then
		enemy.phase = 2
		humanoid.WalkSpeed = speed * 1.2
		Remotes.Fx:FireAllClients("BossPhase", { model = enemy.model, name = def.name })
	end

	local target = findTarget(enemy)
	if not target then
		enemy.aggroOn = nil
		local fromHome = (root.Position - enemy.home).Magnitude
		if fromHome > 6 then
			humanoid:MoveTo(enemy.home)
		elseif not enemy.isBoss and rng:NextNumber() < 0.02 then
			humanoid:MoveTo(enemy.home + Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14)))
		end
		-- Recover while idle so kiting a shadow away and back doesn't cheese it.
		if enemy.hp < enemy.maxHp and now - (enemy.lastHitTime or 0) > 6 then
			enemy.hp = math.min(enemy.maxHp, enemy.hp + enemy.maxHp * 0.05)
			enemy.model:SetAttribute("Health", enemy.hp)
		end
		return
	end
	enemy.state = "chase"
	local targetPosition = target.root.Position
	local distance = (targetPosition - root.Position).Magnitude
	local ready = now >= enemy.nextAttack

	-- Unstick: jump if we've barely moved while chasing.
	if now - enemy.lastMoveCheck > 1.5 then
		if (root.Position - enemy.lastPosition).Magnitude < 1 and distance > 8 then
			humanoid.Jump = true
		end
		enemy.lastMoveCheck = now
		enemy.lastPosition = root.Position
	end

	if enemy.isBoss then
		if distance > 2.5 * enemy.scale + 4 then
			humanoid:MoveTo(targetPosition)
		else
			face(enemy, targetPosition)
		end
		if ready and distance < 70 then
			task.spawn(bossAttack, enemy, target)
		end
		return
	end

	local behaviour = def.behaviour
	if behaviour == "ranged" then
		if distance < def.keepAway then
			local away = (root.Position - targetPosition)
			away = Vector3.new(away.X, 0, away.Z).Unit
			humanoid:MoveTo(root.Position + away * 14)
		elseif distance > def.range * 0.75 then
			humanoid:MoveTo(targetPosition)
		else
			-- Strafe sideways while in range.
			local side = root.CFrame.RightVector * (math.floor(now / 2) % 2 == 0 and 1 or -1)
			humanoid:MoveTo(root.Position + side * 8)
		end
		if ready and distance <= def.range then
			task.spawn(rangedAttack, enemy, target)
		end
		return
	end

	if behaviour == "lurker" and now >= enemy.nextBlink and distance > 12 and distance < 50 then
		blink(enemy, target)
		return
	end

	if behaviour == "wraith" and ready and distance > 8 and distance < def.lungeRange then
		task.spawn(lunge, enemy, target)
		return
	end

	humanoid:MoveTo(targetPosition)
	local reach = def.range + 1.5 * enemy.scale
	if behaviour == "brute" then
		if ready and distance <= reach then
			task.spawn(function()
				slamAttack(enemy, target, def.slamRadius, def.windup, enemy.damage)
				endAttack(enemy, def.cooldown)
			end)
		end
	elseif ready and distance <= reach then
		task.spawn(meleeAttack, enemy, target)
	end
end

-- Death and respawn ------------------------------------------------------------------------

local function onKilled(enemy, killer: Player?, damagers)
	local model = enemy.model
	Registry.Enemies[model] = nil
	enemy.humanoid.WalkSpeed = 0
	enemy.model:SetAttribute("Dead", true)
	Remotes.Fx:FireAllClients("Dissolve", { model = model, boss = enemy.isBoss })

	-- Essence to everyone who meaningfully helped.
	local essence = math.floor(enemy.def.essence * (enemy.isBoss and 1 or enemy.area.essenceMult))
	for player, dealt in damagers do
		if player.Parent and (player == killer or dealt >= enemy.maxHp * 0.1) then
			local data = PlayerData.Get(player)
			if data then
				data.essence += essence
				player:SetAttribute("Essence", data.essence)
				Remotes.Notify:FireClient(player, "Essence", { amount = essence, position = enemy.root.Position })
			end
		end
	end

	if enemy.isBoss then
		Remotes.Fx:FireAllClients("BossDefeated", { name = enemy.def.name })
		for _, add in enemy.adds or {} do
			if not add.dead then
				add.dead = true
				Registry.Enemies[add.model] = nil
				Remotes.Fx:FireAllClients("Dissolve", { model = add.model })
				Debris:AddItem(add.model, 1.2)
			end
		end
	end
	Debris:AddItem(model, enemy.isBoss and 2.5 or 1.2)

	if enemy.isAdd then
		return
	end
	local delayTime = enemy.isBoss and enemy.def.respawn or rng:NextNumber(8, 14)
	task.delay(delayTime, function()
		if enemy.isBoss then
			spawnBoss(enemy.bossId, enemy.area)
		else
			spawnEnemy(enemy.def.name, enemy.area)
		end
	end)
end

function EnemyService.Start(world)
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace
	floorParams.FilterDescendantsInstances = { world.floors }

	-- Spawn points for each area.
	local sampler = Random.new(99)
	for _, area in Areas.List do
		local minX = (area.gateX or area.minX) + 14
		local maxX = area.maxX - 6
		if area.id == "town" then
			minX, maxX = -172, 172
		end
		local avoid = {
			{ at = area.boss.arena, r = 50 },
			{ at = area.spawn, r = 30 },
		}
		if area.id == "town" then
			table.insert(avoid, { at = Vector3.zero, r = Config.Act2.CampRadius + 20 })
		end
		spawnPoints[area.id] = WorldBuilder.SamplePoints(world.floors, Vector3.new(minX, 0, -170), Vector3.new(maxX, 0, 170), 60, sampler, avoid)
	end

	for _, area in Areas.List do
		for _, group in area.enemies do
			for _ = 1, group.count do
				spawnEnemy(group.type, area)
			end
		end
		spawnBoss(area.boss.id, area)
	end

	Registry.EnemyKilled:Connect(onKilled)

	task.spawn(function()
		while true do
			for _, enemy in Registry.Enemies do
				local ok, err = pcall(think, enemy)
				if not ok then
					warn("[Shadowfall] enemy AI error:", err)
				end
			end
			task.wait(TICK)
		end
	end)
end

return EnemyService
