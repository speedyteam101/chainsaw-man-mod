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
local AllyService = require(script.Parent.AllyService)
local InventoryService = require(script.Parent.InventoryService)
local PassService = require(script.Parent.PassService)

local PowerService = {}

local rng = Random.new()

-- Health samples for Rewind.
task.spawn(function()
	while true do
		task.wait(0.5)
		for player, state in Registry.PlayerState do
			local _, humanoid = Combat.GetCharacter(player)
			if humanoid then
				state.healthHistory = state.healthHistory or {}
				table.insert(state.healthHistory, { t = os.clock(), hp = humanoid.Health })
				while #state.healthHistory > 16 do
					table.remove(state.healthHistory, 1)
				end
			end
		end
	end
end)
local pendingRolls: { [Player]: string } = {} -- rerolled power waiting for keep/replace

-- Rolls a power, advancing pity. Returns the power definition.
local function roll(data, luck: number?)
	data.totalRolls += 1
	data.pity += 1
	local forced = data.pity >= Config.Roll.PityAt
	local power = Powers.Roll(rng, forced, luck)
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
	local power = roll(data, PassService.RollLuck(player))
	data.power = power.id
	PassService.Remember(player, power.id)
	Registry.PowerRolled:Fire(player, power.id)
	PlayerData.Sync(player)
	return power
end

-- A paid reroll at the shrine. The result waits for the player to keep it or not.
-- A paid reroll at the shrine (or a free one with a Fate Die). A Star Shard, if you have one,
-- is used up to triple your chance of Legendary or better.
function PowerService.Reroll(player: Player, useDie: boolean?)
	local data = PlayerData.Get(player)
	if not data or data.act ~= 2 then
		return { ok = false, message = "Your power hasn't awakened yet." }
	end
	if pendingRolls[player] then
		return { ok = false, message = "Choose what to do with your last roll first." }
	end
	if useDie then
		if not InventoryService.TakeItem(player, "FateDie") then
			return { ok = false, message = "You don't have a Fate Die." }
		end
	else
		if data.essence < Config.Roll.RerollCost then
			return { ok = false, message = string.format("You need %d Essence (you have %d).", Config.Roll.RerollCost, data.essence) }
		end
		data.essence -= Config.Roll.RerollCost
	end
	local luck = (InventoryService.TakeItem(player, "StarShard") and 3 or 1) * PassService.RollLuck(player)
	local power = roll(data, luck)
	pendingRolls[player] = power.id
	-- With the Power Vault, every roll is kept forever, whichever one you choose to use now.
	PassService.Remember(player, power.id)
	Registry.PowerRolled:Fire(player, power.id)
	PlayerData.Sync(player)
	return { ok = true, power = power.id, current = data.power, vaulted = PassService.Has(player, "vault") }
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
	Combat.AddFlow(player, slot)

	local origin = root.Position
	local aimAt: Vector3 = if typeof(aim) == "Vector3" then aim else origin + root.CFrame.LookVector * 30
	local direction = flatDirection(origin, aimAt, root.CFrame.LookVector)
	local mult = Combat.DamageMultiplier(player)
	local damage = (move.damage or 0) * mult
	local color = power.color
	local effects = move.effect
	local style = power.vfx
	-- Cast animation first, so the arms move as the effect appears.
	Remotes.Fx:FireAllClients("Cast", { character = character, color = color, kind = move.kind, style = style, aim = aimAt })

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
				style = style,
			})
		end
	elseif move.kind == "nova" then
		Remotes.Fx:FireAllClients("Nova", { position = origin, radius = move.radius, color = color, style = style })
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
		Remotes.Fx:FireAllClients("DashTrail", { from = origin, to = finish, color = color, width = move.width, style = style, character = character })
		Remotes.Notify:FireClient(player, "DashMotion", { to = finish })
		state.dodgeUntil = math.max(state.dodgeUntil, now + 0.3) -- brief i-frames while dashing
		for _, enemy in Combat.EnemiesAlongSegment(origin, finish, move.width) do
			Combat.DamageEnemy(enemy, damage, player, { effects = effects, sourcePosition = origin, color = color })
		end
	elseif move.kind == "beam" then
		local finish = origin + direction * move.range
		Remotes.Fx:FireAllClients("Beam", { from = origin + Vector3.new(0, 1, 0), to = finish + Vector3.new(0, 1, 0), color = color, width = move.width, style = style })
		for _, enemy in Combat.EnemiesAlongSegment(origin, finish, move.width) do
			Combat.DamageEnemy(enemy, damage, player, { effects = effects, sourcePosition = origin, color = color })
		end
	elseif move.kind == "strike" then
		local center = clampAim(origin, aimAt, move.range)
		for i = 1, move.count or 1 do
			local target = center
			if i > 1 then
				local a = rng:NextNumber(0, math.pi * 2)
				target = center + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(4, move.spread or 12)
			end
			local delayTime = move.delay + (i - 1) * 0.18
			Remotes.Fx:FireAllClients("StrikeWarn", { position = target, radius = move.radius, color = color, delay = delayTime, style = style })
			task.delay(delayTime, function()
				Remotes.Fx:FireAllClients("Strike", { position = target, radius = move.radius, color = color, style = style })
				for _, enemy in Combat.EnemiesInSphere(target, move.radius) do
					Combat.DamageEnemy(enemy, damage, player, { effects = effects, sourcePosition = target, color = color, crit = true })
				end
			end)
		end
	elseif move.kind == "zone" then
		local center = (move.range or 0) > 0 and clampAim(origin, aimAt, move.range) or origin
		local followSelf = (move.range or 0) == 0
		Remotes.Fx:FireAllClients("Zone", { position = center, radius = move.radius, color = color, duration = move.duration, follow = followSelf and character or nil, style = style })
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
		Remotes.Fx:FireAllClients("Buff", { character = character, color = color, duration = move.duration, style = style })
		local _, humanoid = Combat.GetCharacter(player)
		if move.heal and humanoid then
			Combat.HealPlayer(player, humanoid.MaxHealth * move.heal)
		end
		if move.rewind and humanoid then
			-- Back to the health you had a few seconds ago (never lower than now).
			local past = humanoid.Health
			for _, sample in state.healthHistory or {} do
				if now - sample.t >= move.rewind - 0.5 and now - sample.t <= move.rewind + 1.5 then
					past = math.max(past, sample.hp)
				end
			end
			humanoid.Health = math.min(humanoid.MaxHealth, past)
			Remotes.Fx:FireAllClients("Rewind", { character = character, color = color })
		end
		if move.damageMult then
			state.damageBuff = move.damageMult
			state.damageBuffUntil = now + move.duration
		end
		if move.iframes then
			state.invulnUntil = math.max(state.invulnUntil or 0, now + move.iframes)
		end
		if move.speedMult then
			player:SetAttribute("SpeedBuff", move.speedMult)
			local token = now
			state.speedToken = token
			task.delay(move.duration, function()
				if state.speedToken == token then
					player:SetAttribute("SpeedBuff", nil)
				end
			end)
		end
	elseif move.kind == "summon" then
		AllyService.Summon(player, move.ally, move.count, move.duration, move.damage, nil)
	elseif move.kind == "blinkchain" then
		-- Zip from shadow to shadow, striking each one.
		local points = { origin }
		local hit = {}
		local current = origin
		local sight = RaycastParams.new()
		sight.FilterType = Enum.RaycastFilterType.Include
		sight.FilterDescendantsInstances = { workspace:FindFirstChild("Map"), workspace.Terrain }
		sight.IgnoreWater = true
		for _ = 1, move.count do
			local best, bestDistance = nil, move.range
			for _, enemy in Combat.EnemiesInSphere(current, move.range) do
				local d = (enemy.root.Position - current).Magnitude
				-- The first hop prefers shadows in front of you.
				local ahead = #points > 1 or (enemy.root.Position - origin).Unit:Dot(direction) > 0.2
				if not hit[enemy] and ahead and d < bestDistance and not workspace:Raycast(current, enemy.root.Position - current, sight) then
					best, bestDistance = enemy, d
				end
			end
			if not best then
				break
			end
			hit[best] = true
			current = best.root.Position
			table.insert(points, current)
			Combat.DamageEnemy(best, damage, player, { effects = { stun = 0.4 }, sourcePosition = current, color = color, crit = true })
		end
		local finish
		if #points > 1 then
			finish = points[#points] - (points[#points] - points[#points - 1]).Unit * 3
		else
			-- Nothing to hit: blink forward, stopping short of walls.
			local wall = workspace:Raycast(origin, direction * 30, sight)
			finish = wall and wall.Position - direction * 2.5 or origin + direction * 30
			table.insert(points, finish)
		end
		-- Land on solid ground, never over the void.
		local floor = workspace:Raycast(finish + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), sight)
		if floor then
			finish = floor.Position + Vector3.new(0, 3, 0)
		else
			finish = origin
		end
		state.dodgeUntil = math.max(state.dodgeUntil, now + 0.2 + 0.05 * #points)
		Remotes.Fx:FireAllClients("BlinkChain", { points = points, color = color, style = style, character = character })
		Remotes.Notify:FireClient(player, "DashMotion", { to = finish })
	end
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

	-- The Ultimate: awakening detonates around you, carrying your power's signature effect.
	local K = Config.Combos
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local signature = {}
		for _, move in power.moves do
			if move.effect then
				for key, value in move.effect do
					if key ~= "chain" and key ~= "pull" and signature[key] == nil then
						signature[key] = value
					end
				end
			end
		end
		signature.knockback = 70
		signature.stun = math.max(signature.stun or 0, 1)
		local center = root.Position
		Remotes.Fx:FireAllClients("Ultimate", { position = center, color = power.color, style = power.vfx, radius = K.UltimateRadius })
		task.delay(0.45, function()
			local damage = K.UltimateDamage * Combat.DamageMultiplier(player)
			for _, enemy in Combat.EnemiesInSphere(center, K.UltimateRadius) do
				Combat.DamageEnemy(enemy, damage, player, { effects = signature, sourcePosition = center, color = power.color, crit = true })
			end
		end)
	end
	Remotes.Notify:FireClient(player, "ResetCooldowns", {})
	Remotes.Notify:FireClient(player, "Cooldown", { slot = 5, duration = Config.Combat.AwakeningCooldown })
end

return PowerService
