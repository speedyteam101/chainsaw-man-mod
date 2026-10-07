-- Fighting. Everything that decides a hit happens here on the server: the
-- client only says "I used ability N, aiming here". Visual effects are sent to
-- every client through the Fx remote and drawn there.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Elements = require(Shared.Elements)
local AbilityTypes = require(Shared.AbilityTypes)
local Remotes = require(Shared.Remotes)
local Status = require(script.Parent.Status)
local Visuals = require(script.Parent.Visuals)

local CombatService = {}

local GLOBAL_COOLDOWN = 0.25 -- minimum time between two abilities
local DASH_SPEED = 110

local playerStates = {} -- [Player] = state, see getPlayerState
local enemiesFolder: Folder

local function fx(kind: string, info)
	Remotes.Fx:FireAllClients(kind, info)
end
CombatService.fx = fx

----------------------------------------------------------------------
-- Targets and geometry
----------------------------------------------------------------------

export type Target = { model: Model, humanoid: Humanoid, root: BasePart, player: Player? }

local function asTarget(model: Instance?, player: Player?): Target?
	if not model or not model:IsA("Model") then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 then
		return { model = model, humanoid = humanoid, root = root, player = player }
	end
	return nil
end

-- Every living thing that can be hit: player characters, enemies and dummies.
function CombatService.getTargets(): { Target }
	local list = {}
	for _, player in Players:GetPlayers() do
		local target = asTarget(player.Character, player)
		if target then
			table.insert(list, target)
		end
	end
	for _, model in enemiesFolder:GetChildren() do
		local target = asTarget(model, nil)
		if target then
			table.insert(list, target)
		end
	end
	return list
end

-- Raycast params that only see the map (characters are hit with distance checks).
local function worldParams(): RaycastParams
	local exclude: { Instance } = { enemiesFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	return params
end
CombatService.worldParams = worldParams

-- Distance along segment a->b to the point closest to `point`, and how far away it is.
local function closestOnSegment(point: Vector3, a: Vector3, b: Vector3): (number, number)
	local ab = b - a
	local lengthSquared = ab:Dot(ab)
	local t = 0
	if lengthSquared > 0 then
		t = math.clamp((point - a):Dot(ab) / lengthSquared, 0, 1)
	end
	local closest = a + ab * t
	return t * math.sqrt(lengthSquared), (point - closest).Magnitude
end

function CombatService.inSafeZone(position: Vector3): boolean
	local center = Config.SafeZoneCenter
	local flat = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
	return flat.Magnitude <= Config.SafeZoneRadius
end

local function isEnemy(model: Model?): boolean
	return model ~= nil and model.Parent == enemiesFolder
end

-- Can `attacker` hurt `target` right now?
local function canDamage(attacker: Model?, target: Model, targetRoot: BasePart): boolean
	if attacker == target then
		return false
	end
	-- Enemies don't hurt each other
	if isEnemy(attacker) and isEnemy(target) then
		return false
	end
	local targetIsPlayer = Players:GetPlayerFromCharacter(target) ~= nil
	if targetIsPlayer and CombatService.inSafeZone(targetRoot.Position) then
		return false
	end
	-- No sniping other players from inside the safe zone
	if targetIsPlayer and attacker and Players:GetPlayerFromCharacter(attacker) then
		local attackerRoot = attacker:FindFirstChild("HumanoidRootPart")
		if attackerRoot and attackerRoot:IsA("BasePart") and CombatService.inSafeZone(attackerRoot.Position) then
			return false
		end
	end
	return true
end

----------------------------------------------------------------------
-- Damage
----------------------------------------------------------------------

-- Pushes a part with a short burst of velocity. Works for player characters
-- too, because the mover instance replicates to the client that simulates it.
local function push(root: BasePart, velocity: Vector3, duration: number)
	if root.Anchored then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "PushAttachment"
	attachment.Parent = root

	local mover = Instance.new("LinearVelocity")
	mover.Name = "Push"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.MaxForce = 1e6
	mover.VectorVelocity = velocity
	mover.Parent = root

	Debris:AddItem(mover, duration)
	Debris:AddItem(attachment, duration)
end

local function attackerMultiplier(attacker: Model?): number
	if not attacker then
		return 1
	end
	local multiplier = 1
	local player = Players:GetPlayerFromCharacter(attacker)
	if player then
		local state = playerStates[player]
		if state and state.power then
			multiplier += state.power.stats.strength * Config.DamagePerStrength
		end
	else
		multiplier = attacker:GetAttribute("DamageMultiplier") or 1
	end
	local humanoid = attacker:FindFirstChildOfClass("Humanoid")
	if humanoid then
		multiplier *= Status.damageMultiplier(humanoid)
	end
	return multiplier
end

local function nameOf(model: Model): string
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		return player.DisplayName
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.DisplayName ~= "" and humanoid.DisplayName or model.Name
end

local function onKill(attacker: Model?, victim: Model)
	if not attacker then
		return
	end
	local player = Players:GetPlayerFromCharacter(attacker)
	if not player then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local kos = leaderstats and leaderstats:FindFirstChild("KOs")
	if kos and kos:IsA("IntValue") then
		kos.Value += 1
	end
	Remotes.Notify:FireClient(player, "You defeated " .. nameOf(victim) .. "!")
end

export type DamageOptions = {
	element: string?,
	direction: Vector3?, -- knockback direction
	knockback: number?, -- knockback speed before element bonus
	noEffects: boolean?, -- skip element effects and knockback (burn ticks)
	raw: boolean?, -- skip the attacker's damage multipliers
}

-- Deals damage with all the rules applied. Returns the damage actually dealt.
function CombatService.damage(attacker: Model?, targetModel: Model, baseAmount: number, options: DamageOptions?): number
	local opts: DamageOptions = options or {}
	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	local root = targetModel:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return 0
	end
	if not canDamage(attacker, targetModel, root) then
		return 0
	end
	if targetModel:FindFirstChildOfClass("ForceField") then
		return 0 -- spawn protection
	end

	local element = Elements.get(opts.element or "Ki")
	local effects = element.effects

	local amount = baseAmount
	if not opts.raw then
		amount *= attackerMultiplier(attacker) * (effects.damage or 1)
	end
	amount = Status.absorb(humanoid, amount)

	if amount > 0 then
		local attackerPlayer = attacker and Players:GetPlayerFromCharacter(attacker)
		if attackerPlayer then
			-- Standard "creator" tag, so other kill-credit scripts work too
			local old = humanoid:FindFirstChild("creator")
			if old then
				old:Destroy()
			end
			local tag = Instance.new("ObjectValue")
			tag.Name = "creator"
			tag.Value = attackerPlayer
			tag.Parent = humanoid
			Debris:AddItem(tag, 3)
		end

		local before = humanoid.Health
		humanoid:TakeDamage(amount)
		if before > 0 and humanoid.Health <= 0 then
			onKill(attacker, targetModel)
		end

		if not opts.noEffects then
			if effects.burn then
				Status.burn(humanoid, attacker, effects.burn[1], effects.burn[2], opts.element or "Ki")
			end
			if effects.slow then
				Status.slow(humanoid, effects.slow[1], effects.slow[2])
			end
			if effects.stun then
				Status.stun(humanoid, effects.stun)
			end
			if effects.lifesteal and attacker then
				local attackerHumanoid = attacker:FindFirstChildOfClass("Humanoid")
				if attackerHumanoid and attackerHumanoid.Health > 0 then
					attackerHumanoid.Health =
						math.min(attackerHumanoid.MaxHealth, attackerHumanoid.Health + amount * effects.lifesteal)
				end
			end
			local direction = opts.direction
			if direction and direction.Magnitude > 0.01 then
				local force = (opts.knockback or 15) * (effects.knockback or 1)
				local flat = Vector3.new(direction.X, 0, direction.Z)
				flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.zero
				push(root, flat * force + Vector3.new(0, force * 0.35, 0), 0.15)
			end
		end
	end

	fx("Damage", {
		position = root.Position + Vector3.new(0, 3, 0),
		amount = math.floor(amount + 0.5),
		color = element.color,
		blocked = amount <= 0,
	})
	return amount
end

-- Burns tick through the normal damage rules, without re-applying effects
Status.burnDamage = function(attacker, target, amount, element)
	CombatService.damage(attacker, target, amount, { element = element, noEffects = true, raw = true })
end

-- Damages everyone within `radius` of `center` and pushes them outward.
function CombatService.areaDamage(
	attacker: Model?,
	center: Vector3,
	radius: number,
	amount: number,
	element: string,
	knockback: number
)
	for _, target in CombatService.getTargets() do
		if target.model ~= attacker then
			local offset = target.root.Position - center
			if offset.Magnitude <= radius + 1.5 then
				local direction = offset.Magnitude > 0.1 and offset or Vector3.new(0, 0, 1)
				CombatService.damage(attacker, target.model, amount, {
					element = element,
					direction = direction,
					knockback = knockback,
				})
			end
		end
	end
end

-- A single close-range hit in front of `attacker` (basic attacks and enemies).
function CombatService.frontHit(
	attacker: Model,
	root: BasePart,
	facing: Vector3,
	reach: number,
	amount: number,
	element: string,
	knockback: number
): number
	local hits = 0
	for _, target in CombatService.getTargets() do
		if target.model ~= attacker then
			local offset = target.root.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local inFront = flat.Magnitude < 2 or flat.Unit:Dot(facing) > 0.25
			if offset.Magnitude <= reach + 1 and inFront then
				if
					CombatService.damage(attacker, target.model, amount, {
						element = element,
						direction = facing,
						knockback = knockback,
					}) > 0
				then
					hits += 1
				end
			end
		end
	end
	return hits
end

----------------------------------------------------------------------
-- Projectiles (simulated on the server, drawn by clients)
----------------------------------------------------------------------

local projectiles = {}
local nextProjectileId = 0

export type ProjectileInfo = {
	damage: number,
	radius: number,
	speed: number,
	range: number,
	element: string,
	splash: number?, -- explode on impact with this radius instead of hitting one target
	knockback: number?,
}

function CombatService.fireProjectile(caster: Model, origin: Vector3, direction: Vector3, info: ProjectileInfo)
	if direction.Magnitude < 0.001 then
		return
	end
	nextProjectileId += 1
	local element = Elements.get(info.element)
	local projectile = {
		id = nextProjectileId,
		caster = caster,
		position = origin,
		direction = direction.Unit,
		speed = info.speed * (element.effects.speed or 1),
		traveled = 0,
		range = info.range,
		radius = info.radius,
		damage = info.damage,
		element = info.element,
		splash = info.splash or 0,
		knockback = info.knockback or 18,
		color = element.color,
	}
	table.insert(projectiles, projectile)
	fx("Projectile", {
		id = projectile.id,
		origin = origin,
		direction = projectile.direction,
		speed = projectile.speed,
		radius = projectile.radius,
		range = projectile.range,
		color = projectile.color,
	})
end

local function endProjectile(projectile, position: Vector3, target: Target?)
	if projectile.splash > 0 then
		CombatService.areaDamage(
			projectile.caster,
			position,
			projectile.splash,
			projectile.damage,
			projectile.element,
			projectile.knockback
		)
	elseif target then
		CombatService.damage(projectile.caster, target.model, projectile.damage, {
			element = projectile.element,
			direction = projectile.direction,
			knockback = projectile.knockback,
		})
	end
	fx("ProjectileEnd", {
		id = projectile.id,
		position = position,
		color = projectile.color,
		radius = math.max(projectile.radius * 2.5, projectile.splash),
	})
end

local function stepProjectiles(dt: number)
	if #projectiles == 0 then
		return
	end
	local targets = CombatService.getTargets()
	local params = worldParams()

	for i = #projectiles, 1, -1 do
		local projectile = projectiles[i]
		local stepLength = math.min(projectile.speed * dt, projectile.range - projectile.traveled)
		local from = projectile.position
		local step = projectile.direction * stepLength
		local to = from + step

		-- Closest character along this step
		local hitTarget: Target? = nil
		local hitAlong = math.huge
		for _, target in targets do
			if
				target.model ~= projectile.caster
				and target.humanoid.Health > 0
				and canDamage(projectile.caster, target.model, target.root)
			then
				local along, distance = closestOnSegment(target.root.Position, from, to)
				if distance <= projectile.radius + 2 and along < hitAlong then
					hitTarget, hitAlong = target, along
				end
			end
		end

		local wall = workspace:Raycast(from, step, params)
		local wallAlong = wall and (wall.Position - from).Magnitude or math.huge

		local finished = true
		if hitTarget and hitAlong <= wallAlong then
			endProjectile(projectile, from + projectile.direction * hitAlong, hitTarget)
		elseif wall then
			endProjectile(projectile, wall.Position, nil)
		else
			projectile.position = to
			projectile.traveled += stepLength
			if projectile.traveled >= projectile.range - 0.01 then
				endProjectile(projectile, to, nil)
			else
				finished = false
			end
		end

		if finished then
			table.remove(projectiles, i)
		end
	end
end

----------------------------------------------------------------------
-- Player state (power, energy, cooldowns)
----------------------------------------------------------------------

local function getPlayerState(player: Player)
	local state = playerStates[player]
	if not state then
		state = {
			power = nil,
			abilityStats = {},
			cooldowns = {},
			lastAbility = 0,
			lastBasic = 0,
			energy = Config.BaseEnergy,
			maxEnergy = Config.BaseEnergy,
			regen = Config.BaseEnergyRegen,
		}
		playerStates[player] = state
	end
	return state
end

-- Called by PowerService when a player equips a power (or nil for none).
-- Cooldowns and current energy carry over, so switching powers can't be used
-- to skip cooldowns.
function CombatService.setPower(player: Player, power)
	local state = getPlayerState(player)
	state.power = power
	state.abilityStats = {}
	if power then
		for i, ability in power.abilities do
			state.abilityStats[i] = AbilityTypes.computeStats(ability)
		end
	end
	local energyPoints = power and power.stats.energy or 0
	state.maxEnergy = Config.BaseEnergy + energyPoints * Config.EnergyPerPoint
	state.regen = Config.BaseEnergyRegen + energyPoints * Config.EnergyRegenPerPoint
	state.energy = math.min(state.energy, state.maxEnergy)
	player:SetAttribute("MaxEnergy", state.maxEnergy)
	player:SetAttribute("Energy", math.floor(state.energy))
end

function CombatService.onCharacterSpawned(player: Player)
	local state = getPlayerState(player)
	state.energy = state.maxEnergy
	player:SetAttribute("Energy", math.floor(state.energy))
end

----------------------------------------------------------------------
-- Abilities
----------------------------------------------------------------------

type Context = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	ability: any,
	stats: any,
	element: string,
	color: Color3,
	aim: Vector3,
	origin: Vector3, -- chest height
	direction: Vector3, -- unit vector toward the aim
	flat: Vector3, -- unit vector toward the aim, ignoring height
}

local function alive(ctx: Context): boolean
	return ctx.humanoid.Health > 0 and ctx.character.Parent ~= nil
end

-- Moves `point` toward `from` so it is at most `range` away.
local function clampRange(from: Vector3, point: Vector3, range: number): Vector3
	local offset = point - from
	if offset.Magnitude > range then
		return from + offset.Unit * range
	end
	return point
end

-- Finds the ground below a point (or returns the point if there is none).
local function groundBelow(point: Vector3): Vector3
	local hit = workspace:Raycast(point + Vector3.new(0, 6, 0), Vector3.new(0, -120, 0), worldParams())
	return hit and hit.Position or point
end

local Executors = {}

function Executors.Projectile(ctx: Context)
	local stats = ctx.stats
	CombatService.fireProjectile(ctx.character, ctx.origin + ctx.direction * 2, ctx.direction, {
		damage = stats.damage,
		radius = stats.radius,
		speed = stats.speed,
		range = stats.range,
		element = ctx.element,
	})
end

function Executors.Barrage(ctx: Context)
	local stats = ctx.stats
	for i = 1, stats.count do
		task.delay((i - 1) * 0.07, function()
			if not alive(ctx) then
				return
			end
			local spread = (i - (stats.count + 1) / 2) * 3.5
			local direction = CFrame.Angles(0, math.rad(spread), 0):VectorToWorldSpace(ctx.direction)
			local origin = ctx.root.Position + Vector3.new(0, 1, 0) + direction * 2
			CombatService.fireProjectile(ctx.character, origin, direction, {
				damage = stats.damage,
				radius = stats.radius,
				speed = stats.speed,
				range = stats.range,
				element = ctx.element,
				knockback = 6,
			})
		end)
	end
end

function Executors.Beam(ctx: Context)
	local stats = ctx.stats
	local start = ctx.origin + ctx.direction * 1.5
	local length = stats.range
	local wall = workspace:Raycast(start, ctx.direction * length, worldParams())
	if wall then
		length = (wall.Position - start).Magnitude
	end
	local finish = start + ctx.direction * length

	fx("Beam", { from = start, to = finish, width = stats.width, color = ctx.color })

	for _, target in CombatService.getTargets() do
		if target.model ~= ctx.character then
			local _, distance = closestOnSegment(target.root.Position, start, finish)
			if distance <= stats.width / 2 + 2 then
				CombatService.damage(ctx.character, target.model, stats.damage, {
					element = ctx.element,
					direction = ctx.direction,
					knockback = 30,
				})
			end
		end
	end
end

function Executors.Blast(ctx: Context)
	local stats = ctx.stats
	local center = ctx.root.Position
	fx("Burst", { position = center, radius = stats.radius, color = ctx.color })
	CombatService.areaDamage(ctx.character, center, stats.radius, stats.damage, ctx.element, stats.knockback)
end

function Executors.Explosion(ctx: Context)
	local stats = ctx.stats
	local point = groundBelow(clampRange(ctx.root.Position, ctx.aim, stats.range))
	fx("Warning", { position = point, radius = stats.radius, color = ctx.color, duration = stats.delay })
	task.delay(stats.delay, function()
		fx("Burst", { position = point, radius = stats.radius, color = ctx.color })
		CombatService.areaDamage(ctx.character, point, stats.radius, stats.damage, ctx.element, 30)
	end)
end

function Executors.MeteorRain(ctx: Context)
	local stats = ctx.stats
	local center = groundBelow(clampRange(ctx.root.Position, ctx.aim, stats.range))
	fx("Warning", { position = center, radius = stats.area, color = ctx.color, duration = 0.4 + stats.count * 0.12 })
	for i = 1, stats.count do
		task.delay(0.3 + i * 0.12, function()
			local angle = math.random() * math.pi * 2
			local distance = math.sqrt(math.random()) * stats.area
			local landing = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			local origin = landing + Vector3.new(-10, 70, -10)
			local direction = landing - origin
			CombatService.fireProjectile(ctx.character, origin, direction, {
				damage = stats.damage,
				radius = 1.5,
				speed = 140,
				range = direction.Magnitude + 15,
				element = ctx.element,
				splash = stats.radius,
				knockback = 12,
			})
		end)
	end
end

function Executors.Melee(ctx: Context)
	local stats = ctx.stats
	for i = 1, stats.hits do
		task.delay((i - 1) * 0.2, function()
			if not alive(ctx) then
				return
			end
			local last = i == stats.hits
			fx("Slash", {
				cframe = CFrame.lookAt(ctx.root.Position, ctx.root.Position + ctx.flat),
				reach = stats.reach,
				color = ctx.color,
				flip = i % 2 == 0,
			})
			CombatService.frontHit(
				ctx.character,
				ctx.root,
				ctx.flat,
				stats.reach,
				stats.damage,
				ctx.element,
				last and stats.knockback or 4
			)
		end)
	end
end

function Executors.DashStrike(ctx: Context)
	local stats = ctx.stats
	local start = ctx.root.Position
	local distance = stats.distance
	local wall = workspace:Raycast(start, ctx.flat * distance, worldParams())
	if wall then
		distance = math.max(0, (wall.Position - start).Magnitude - 3)
	end
	local finish = start + ctx.flat * distance
	local duration = math.max(distance / DASH_SPEED, 0.05)

	push(ctx.root, ctx.flat * DASH_SPEED, duration)
	fx("Dash", { from = start, to = finish, width = stats.width, color = ctx.color })

	task.delay(duration * 0.5, function()
		for _, target in CombatService.getTargets() do
			if target.model ~= ctx.character then
				local _, away = closestOnSegment(target.root.Position, start, finish)
				if away <= stats.width / 2 + 2 then
					CombatService.damage(ctx.character, target.model, stats.damage, {
						element = ctx.element,
						direction = ctx.flat,
						knockback = 25,
					})
				end
			end
		end
	end)
end

function Executors.Teleport(ctx: Context)
	local stats = ctx.stats
	local start = ctx.root.Position
	local destination = clampRange(start, ctx.aim + Vector3.new(0, 3, 0), stats.range)
	local offset = destination - start
	if offset.Magnitude > 0.5 then
		local wall = workspace:Raycast(start, offset, worldParams())
		if wall then
			destination = wall.Position - offset.Unit * 2.5
		end
	end
	local ground = workspace:Raycast(destination + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), worldParams())
	if ground then
		destination = ground.Position + Vector3.new(0, 3, 0)
	end

	fx("Teleport", { from = start, to = destination, color = ctx.color })
	ctx.character:PivotTo(CFrame.lookAt(destination, destination + ctx.flat))

	if stats.damage > 0 then
		task.delay(0.05, function()
			fx("Burst", { position = destination, radius = stats.radius, color = ctx.color })
			CombatService.areaDamage(ctx.character, destination, stats.radius, stats.damage, ctx.element, 25)
		end)
	end
end

function Executors.Shield(ctx: Context)
	local stats = ctx.stats
	local bubble = Visuals.makeBubble(ctx.root, ctx.color, 8)
	Status.addShield(ctx.humanoid, stats.absorb, stats.duration, bubble)
end

function Executors.Heal(ctx: Context)
	local humanoid = ctx.humanoid
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + ctx.stats.heal)
	fx("Heal", { position = ctx.root.Position, color = ctx.color })
end

function Executors.PowerUp(ctx: Context)
	local stats = ctx.stats
	Status.powerUp(ctx.humanoid, stats.damageMultiplier, stats.walkSpeedBonus, stats.duration)

	local power = playerStates[ctx.player].power
	local style = power and power.aura ~= "None" and power.aura or "Flames"
	for _, instance in Visuals.makeAura(ctx.root, style, ctx.color, 2.2) do
		Debris:AddItem(instance, stats.duration)
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "PowerUpHighlight"
	highlight.FillColor = ctx.color
	highlight.OutlineColor = ctx.color
	highlight.FillTransparency = 0.75
	highlight.Parent = ctx.character
	Debris:AddItem(highlight, stats.duration)

	fx("Burst", { position = ctx.root.Position, radius = 12, color = ctx.color })
end

local function validAim(aim: any): boolean
	if typeof(aim) ~= "Vector3" then
		return false
	end
	for _, value in { aim.X, aim.Y, aim.Z } do
		if value ~= value or math.abs(value) > 1e6 then
			return false -- NaN or absurdly far
		end
	end
	return true
end

-- Builds the context for an attack, or nil if the player can't attack now.
local function makeContext(player: Player, aim: any): Context?
	if not validAim(aim) then
		return nil
	end
	local character = player.Character
	local target = asTarget(character, player)
	if not target or not character then
		return nil
	end
	if Status.isStunned(target.humanoid) then
		return nil
	end
	local root = target.root
	local origin = root.Position + Vector3.new(0, 1, 0)
	local clampedAim = clampRange(origin, aim, Config.MaxAimDistance)
	local offset = clampedAim - origin
	local direction = offset.Magnitude > 0.1 and offset.Unit or root.CFrame.LookVector
	local flat = Vector3.new(direction.X, 0, direction.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit
		or Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit

	local state = getPlayerState(player)
	local element = state.power and state.power.element or "Ki"
	return {
		player = player,
		character = character,
		humanoid = target.humanoid,
		root = root,
		ability = nil,
		stats = nil,
		element = element,
		color = Elements.get(element).color,
		aim = clampedAim,
		origin = origin,
		direction = direction,
		flat = flat,
	}
end

local function useAbility(player: Player, slot: any, aim: any)
	local state = playerStates[player]
	if not state or not state.power then
		return
	end
	if type(slot) ~= "number" or slot ~= math.floor(slot) then
		return
	end
	local ability = state.power.abilities[slot]
	local stats = state.abilityStats[slot]
	if not ability or not stats then
		return
	end

	local now = os.clock()
	if now - state.lastAbility < GLOBAL_COOLDOWN or (state.cooldowns[slot] or 0) > now then
		return
	end

	local ctx = makeContext(player, aim)
	if not ctx then
		return
	end
	if state.energy < stats.energy then
		Remotes.Notify:FireClient(player, "Not enough energy!")
		return
	end

	state.energy -= stats.energy
	state.cooldowns[slot] = now + stats.cooldown
	state.lastAbility = now
	player:SetAttribute("Energy", math.floor(state.energy))
	Remotes.AbilityResult:FireClient(player, slot, stats.cooldown)

	ctx.ability = ability
	ctx.stats = stats
	ctx.element = ability.element
	ctx.color = Elements.get(ability.element).color

	-- Anime rule: shout the attack's name
	fx("Shout", { character = ctx.character, text = ability.name, color = ctx.color })

	local executor = Executors[ability.type]
	if executor then
		executor(ctx)
	end
end

local function basicAttack(player: Player, aim: any)
	local state = getPlayerState(player)
	local now = os.clock()
	if now - state.lastBasic < Config.BasicAttackCooldown then
		return
	end
	local ctx = makeContext(player, aim)
	if not ctx then
		return
	end
	state.lastBasic = now
	fx("Slash", {
		cframe = CFrame.lookAt(ctx.root.Position, ctx.root.Position + ctx.flat),
		reach = Config.BasicAttackRange,
		color = ctx.color,
		flip = math.random() < 0.5,
		small = true,
	})
	CombatService.frontHit(
		ctx.character,
		ctx.root,
		ctx.flat,
		Config.BasicAttackRange,
		Config.BasicAttackDamage,
		ctx.element,
		8
	)
end

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------

function CombatService.init(folder: Folder)
	enemiesFolder = folder

	Remotes.UseAbility.OnServerEvent:Connect(useAbility)
	Remotes.BasicAttack.OnServerEvent:Connect(basicAttack)

	Players.PlayerRemoving:Connect(function(player)
		playerStates[player] = nil
	end)

	RunService.Heartbeat:Connect(stepProjectiles)

	-- Energy regeneration
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		for player, state in playerStates do
			if state.energy < state.maxEnergy then
				state.energy = math.min(state.maxEnergy, state.energy + state.regen * elapsed)
				local shown = math.floor(state.energy)
				if player:GetAttribute("Energy") ~= shown then
					player:SetAttribute("Energy", shown)
				end
			end
		end
		elapsed = 0
	end)
end

return CombatService
