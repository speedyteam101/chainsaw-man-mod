--!nonstrict
-- Rolling powers (with pity and keep-or-replace) and running power moves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Powers = require(ReplicatedStorage.Shared.Powers)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)
local Combat = require(script.Parent.Combat)
local Projectiles = require(script.Parent.Projectiles)
local PlayerData = require(script.Parent.PlayerData)

local PowerService = {}

local rng = Random.new()
local pendingRolls: { [Player]: string } = {} -- rerolled power waiting for keep/replace

-- Rolls a power, advancing pity. Returns the power definition.
local function roll(data)
	data.totalRolls += 1
	data.pity += 1
	local forced = data.pity >= Config.Roll.PityAt
	local power = Powers.Roll(rng, forced)
	if Powers.RarityById[power.rarity].rank >= Powers.RarityById.Legendary.rank then
		data.pity = 0
	end
	return power
end

-- The free roll at the end of Act 1. Always kept.
function PowerService.AwakeningRoll(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	if data.power then
		return Powers.ById[data.power]
	end
	local power = roll(data)
	data.power = power.id
	Registry.PowerRolled:Fire(player, power.id)
	PlayerData.Sync(player)
	return power
end

-- A paid reroll at the shrine. The result waits for the player to keep it or not.
function PowerService.Reroll(player: Player)
	local data = PlayerData.Get(player)
	if not data or data.act ~= 2 then
		return { ok = false, message = "Your power hasn't awakened yet." }
	end
	if pendingRolls[player] then
		return { ok = false, message = "Choose what to do with your last roll first." }
	end
	if data.essence < Config.Roll.RerollCost then
		return { ok = false, message = string.format("You need %d Essence (you have %d).", Config.Roll.RerollCost, data.essence) }
	end
	data.essence -= Config.Roll.RerollCost
	local power = roll(data)
	pendingRolls[player] = power.id
	Registry.PowerRolled:Fire(player, power.id)
	PlayerData.Sync(player)
	return { ok = true, power = power.id, current = data.power }
end

function PowerService.ResolveReroll(player: Player, keepNew: boolean)
	local data = PlayerData.Get(player)
	local pending = pendingRolls[player]
	if not data or not pending then
		return { ok = false }
	end
	pendingRolls[player] = nil
	if keepNew then
		data.power = pending
		local state = Combat.GetState(player)
		state.cooldowns = {}
	end
	PlayerData.Sync(player)
	return { ok = true, power = data.power }
end

function PowerService.Forget(player: Player)
	-- If someone leaves mid-choice, they keep their current power.
	pendingRolls[player] = nil
end

-- Moves ------------------------------------------------------------------------------------

local function flatDirection(from: Vector3, to: Vector3, fallback: Vector3): Vector3
	local d = to - from
	d = Vector3.new(d.X, 0, d.Z)
	if d.Magnitude < 0.1 then
		return fallback
	end
	return d.Unit
end

local function clampAim(origin: Vector3, aim: Vector3, range: number): Vector3
	local offset = aim - origin
	if offset.Magnitude > range then
		return origin + offset.Unit * range
	end
	return aim
end

function PowerService.UseMove(player: Player, slot: number, aim: Vector3?)
	local data = PlayerData.Get(player)
	if not data or data.act ~= 2 or not data.power then
		return
	end
	local power = Powers.ById[data.power]
	local move = power and power.moves[slot]
	if not move or data.level < move.unlockLevel then
		return
	end
	local character, _, root = Combat.GetCharacter(player)
	if not character then
		return
	end
	local state = Combat.GetState(player)
	local now = os.clock()
	if now < state.stunUntil or state.blocking or now < (state.cooldowns[slot] or 0) then
		return
	end
	local cooldownMult = now < state.awakenedUntil and Config.Combat.AwakeningCooldownMult or 1
	state.cooldowns[slot] = now + move.cooldown * cooldownMult
	Remotes.Notify:FireClient(player, "Cooldown", { slot = slot, duration = move.cooldown * cooldownMult })

	local origin = root.Position
	local aimAt: Vector3 = if typeof(aim) == "Vector3" then aim else origin + root.CFrame.LookVector * 30
	local direction = flatDirection(origin, aimAt, root.CFrame.LookVector)
	local mult = Combat.DamageMultiplier(player)
	local damage = (move.damage or 0) * mult
	local color = power.color
	local effects = move.effect

	if move.kind == "projectile" then
		local count = move.count or 1
		local spread = move.spread or 0
		local start = origin + Vector3.new(0, 1, 0) + direction * 2
		for i = 1, count do
			local offset = count == 1 and 0 or ((i - 1) / (count - 1) - 0.5) * spread
			local dir = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(offset)):VectorToWorldSpace(direction)
			Projectiles.Fire({
				team = "player",
				owner = player,
				origin = start,
				direction = dir,
				speed = move.speed,
				range = move.range,
				radius = move.radius,
				damage = damage,
				pierce = move.pierce,
				effects = effects,
				color = color,
			})
		end
	elseif move.kind == "nova" then
		Remotes.Fx:FireAllClients("Nova", { position = origin, radius = move.radius, color = color })
		for _, enemy in Combat.EnemiesInSphere(origin, move.radius) do
			Combat.DamageEnemy(enemy, damage, player, { effects = effects, sourcePosition = origin, color = color })
		end
	elseif move.kind == "dash" then
		-- The client moves its own character; the server resolves hits along the path.
		local finish = origin + direction * move.distance
		local mapParams = RaycastParams.new()
		mapParams.FilterType = Enum.RaycastFilterType.Include
		mapParams.FilterDescendantsInstances = { workspace:FindFirstChild("Map"), workspace.Terrain }
		mapParams.IgnoreWater = true
		local wall = workspace:Raycast(origin, direction * move.distance, mapParams)
		if wall then
			finish = wall.Position - direction * 2
		end
		Remotes.Fx:FireAllClients("DashTrail", { from = origin, to = finish, color = color, width = move.width })
		Remotes.Notify:FireClient(player, "DashMotion", { to = finish })
		state.dodgeUntil = math.max(state.dodgeUntil, now + 0.3) -- brief i-frames while dashing
		for _, enemy in Combat.EnemiesAlongSegment(origin, finish, move.width) do
			Combat.DamageEnemy(enemy, damage, player, { effects = effects, sourcePosition = origin, color = color })
		end
	elseif move.kind == "beam" then
		local finish = origin + direction * move.range
		Remotes.Fx:FireAllClients("Beam", { from = origin + Vector3.new(0, 1, 0), to = finish + Vector3.new(0, 1, 0), color = color, width = move.width })
		for _, enemy in Combat.EnemiesAlongSegment(origin, finish, move.width) do
			Combat.DamageEnemy(enemy, damage, player, { effects = effects, sourcePosition = origin, color = color })
		end
	elseif move.kind == "strike" then
		local target = clampAim(origin, aimAt, move.range)
		Remotes.Fx:FireAllClients("StrikeWarn", { position = target, radius = move.radius, color = color, delay = move.delay })
		task.delay(move.delay, function()
			Remotes.Fx:FireAllClients("Strike", { position = target, radius = move.radius, color = color })
			for _, enemy in Combat.EnemiesInSphere(target, move.radius) do
				Combat.DamageEnemy(enemy, damage, player, { effects = effects, sourcePosition = target, color = color, crit = true })
			end
		end)
	elseif move.kind == "zone" then
		local center = (move.range or 0) > 0 and clampAim(origin, aimAt, move.range) or origin
		local followSelf = (move.range or 0) == 0
		Remotes.Fx:FireAllClients("Zone", { position = center, radius = move.radius, color = color, duration = move.duration, follow = followSelf and character or nil })
		task.spawn(function()
			local elapsed = 0
			while elapsed < move.duration do
				task.wait(move.tick)
				elapsed += move.tick
				local here = center
				if followSelf then
					local _, _, r = Combat.GetCharacter(player)
					if not r then
						break
					end
					here = r.Position
				end
				for _, enemy in Combat.EnemiesInSphere(here, move.radius) do
					Combat.DamageEnemy(enemy, damage, player, { effects = effects, sourcePosition = here, color = color })
				end
			end
		end)
	elseif move.kind == "buff" then
		Remotes.Fx:FireAllClients("Buff", { character = character, color = color, duration = move.duration })
		if move.heal then
			local _, humanoid = Combat.GetCharacter(player)
			if humanoid then
				Combat.HealPlayer(player, humanoid.MaxHealth * move.heal)
			end
		end
		if move.damageMult then
			state.damageBuff = move.damageMult
			state.damageBuffUntil = now + move.duration
		end
	end
	Remotes.Fx:FireAllClients("Cast", { character = character, color = color, kind = move.kind })
end

function PowerService.Awaken(player: Player)
	local data = PlayerData.Get(player)
	if not data or data.act ~= 2 or not data.power or data.level < 5 then
		return
	end
	local character = Combat.GetCharacter(player)
	if not character then
		return
	end
	local state = Combat.GetState(player)
	local now = os.clock()
	if now < state.awakenReady then
		return
	end
	state.awakenReady = now + Config.Combat.AwakeningCooldown
	state.awakenedUntil = now + Config.Combat.AwakeningDuration
	state.cooldowns = {}
	local power = Powers.ById[data.power]
	Remotes.Fx:FireAllClients("Awaken", { character = character, color = power.color, duration = Config.Combat.AwakeningDuration })
	Remotes.Notify:FireClient(player, "ResetCooldowns", {})
	Remotes.Notify:FireClient(player, "Cooldown", { slot = 5, duration = Config.Combat.AwakeningCooldown })
end

return PowerService
