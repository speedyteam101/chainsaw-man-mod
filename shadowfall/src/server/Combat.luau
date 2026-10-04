--!nonstrict
-- Core combat rules: player combat state, basic attacks (M1 combo), block/parry, dodge with
-- i-frames, damage to players and enemies, and status effects on enemies.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Powers = require(ReplicatedStorage.Shared.Powers)
local Passes = require(ReplicatedStorage.Shared.Passes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)
local PlayerData = require(script.Parent.PlayerData)
local InventoryService = require(script.Parent.InventoryService)

local Combat = {}

local C = Config.Combat

function Combat.GetState(player: Player)
	local state = Registry.PlayerState[player]
	if not state then
		state = {
			combo = 0,
			lastM1 = 0,
			m1Ready = 0,
			blocking = false,
			blockStart = 0,
			dodgeUntil = 0,
			dodgeReady = 0,
			cooldowns = {},
			lastDamaged = 0,
			damageBuff = 1,
			damageBuffUntil = 0,
			awakenedUntil = 0,
			awakenReady = 0,
			stunUntil = 0,
			inSafeZone = false,
			session = { noDamageStreak = 0, noDeathStreak = 0, killTimes = {} },
		}
		Registry.PlayerState[player] = state
	end
	return state
end

function Combat.GetCharacter(player: Player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end
	return character, humanoid, root
end

local function power(player: Player)
	local data = PlayerData.Get(player)
	return data and data.power and Powers.ById[data.power]
end

local function passive(player: Player)
	local p = power(player)
	return p and p.passiveEffect or {}
end

-- Everything that multiplies a player's outgoing damage.
function Combat.DamageMultiplier(player: Player): number
	local data = PlayerData.Get(player)
	if not data then
		return 1
	end
	local state = Combat.GetState(player)
	local now = os.clock()
	local mult = Config.LevelDamage[data.level] or 1
	local p = power(player)
	if p then
		mult *= Powers.RarityById[p.rarity].damage
		mult *= p.passiveEffect.allDamage or 1
	end
	if now < state.damageBuffUntil then
		mult *= state.damageBuff
	end
	if now < state.awakenedUntil then
		mult *= C.AwakeningDamage
	end
	if InventoryService.HasItem(player, "Charm") then
		mult *= 1.1
	end
	-- Flow: chaining different moves together.
	if (state.flow or 0) > 0 and now < (state.flowUntil or 0) then
		mult *= 1 + state.flow * Config.Combos.FlowPerStack
	end
	return mult
end

-- Flow: using a different move than the last one within the window builds a stack (up to the
-- max); repeating the same move keeps it; getting hit or waiting too long drops it.
function Combat.AddFlow(player: Player, slot: number)
	local K = Config.Combos
	local state = Combat.GetState(player)
	local now = os.clock()
	if now > (state.flowUntil or 0) then
		state.flow = 0
	end
	if state.lastFlowSlot ~= slot then
		state.flow = math.min(K.FlowMax, (state.flow or 0) + 1)
	end
	state.lastFlowSlot = slot
	state.flowUntil = now + K.FlowWindow
	Remotes.Notify:FireClient(player, "Flow", { stacks = state.flow, duration = K.FlowWindow })
end

function Combat.BreakFlow(player: Player)
	local state = Combat.GetState(player)
	if (state.flow or 0) > 0 then
		state.flow = 0
		state.flowUntil = 0
		Remotes.Notify:FireClient(player, "Flow", { stacks = 0 })
	end
end

-- Spatial queries over the enemy registry ------------------------------------------------

local function hitRadius(enemy)
	return 1.4 * (enemy.scale or 1)
end

-- The point on a shadow's body (a vertical line from its feet to the top of its head) closest
-- to `point`. Big rigs have their root far above the ground, so testing only the root would
-- let attacks pass under bosses.
local function bodyPointNear(enemy, point: Vector3): Vector3
	local root = enemy.root.Position
	local s = enemy.scale or 1
	return Vector3.new(root.X, math.clamp(point.Y, root.Y - 3 * s, root.Y + 2 * s), root.Z)
end

function Combat.EnemiesInSphere(center: Vector3, radius: number)
	local result = {}
	for _, enemy in Registry.Enemies do
		if not enemy.dead and (bodyPointNear(enemy, center) - center).Magnitude <= radius + hitRadius(enemy) then
			table.insert(result, enemy)
		end
	end
	return result
end

local function distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	if lengthSq < 1e-6 then
		return (point - a).Magnitude
	end
	local t = math.clamp((point - a):Dot(ab) / lengthSq, 0, 1)
	return (point - (a + ab * t)).Magnitude
end
Combat.DistanceToSegment = distanceToSegment

local function closestOnSegment(point: Vector3, a: Vector3, b: Vector3): Vector3
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	if lengthSq < 1e-6 then
		return a
	end
	return a + ab * math.clamp((point - a):Dot(ab) / lengthSq, 0, 1)
end

function Combat.EnemiesAlongSegment(a: Vector3, b: Vector3, width: number)
	local result = {}
	for _, enemy in Registry.Enemies do
		if not enemy.dead then
			local onLine = closestOnSegment(enemy.root.Position, a, b)
			local body = bodyPointNear(enemy, onLine)
			if distanceToSegment(body, a, b) <= width / 2 + hitRadius(enemy) then
				table.insert(result, enemy)
			end
		end
	end
	return result
end

-- Act 2 players that enemies may hurt.
function Combat.TargetablePlayers()
	local result = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Act") == 2 then
			local character, humanoid, root = Combat.GetCharacter(player)
			if character and not Combat.GetState(player).inSafeZone then
				table.insert(result, { player = player, character = character, humanoid = humanoid, root = root })
			end
		end
	end
	return result
end

function Combat.PlayersInSphere(center: Vector3, radius: number)
	local result = {}
	for _, target in Combat.TargetablePlayers() do
		if (target.root.Position - center).Magnitude <= radius + 1.5 then
			table.insert(result, target)
		end
	end
	return result
end

-- Damage to enemies ------------------------------------------------------------------------

function Combat.ApplyEffects(enemy, effects, sourcePosition: Vector3, attacker: Player?, damageDealt: number)
	if not effects or enemy.dead then
		return
	end
	local now = os.clock()
	local resist = enemy.isBoss and 0.3 or 1
	if effects.burn then
		enemy.burn = { dps = effects.burn.dps * (attacker and Combat.DamageMultiplier(attacker) or 1), untilTime = now + effects.burn.time, attacker = attacker }
	end
	if effects.slow then
		enemy.slowMult = math.min(enemy.slowUntil > now and enemy.slowMult or 1, effects.slow.mult + (1 - effects.slow.mult) * (1 - resist))
		enemy.slowUntil = now + effects.slow.time
	end
	if effects.stun then
		enemy.stunUntil = math.max(enemy.stunUntil, now + effects.stun * resist)
	end
	if effects.weaken then
		enemy.weakenMult = effects.weaken.mult
		enemy.weakenUntil = now + effects.weaken.time
	end
	local root = enemy.root
	if effects.knockback and not enemy.isBoss then
		local away = root.Position - sourcePosition
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude < 0.1 then
			away = Vector3.new(0, 0, 1)
		end
		root.AssemblyLinearVelocity = away.Unit * effects.knockback / (enemy.scale or 1) + Vector3.new(0, 18, 0)
		enemy.stunUntil = math.max(enemy.stunUntil, now + 0.35)
	end
	if effects.pull and not enemy.isBoss then
		local toward = sourcePosition - root.Position
		toward = Vector3.new(toward.X, 0, toward.Z)
		if toward.Magnitude > 2 then
			root.AssemblyLinearVelocity = toward.Unit * math.min(effects.pull, toward.Magnitude * 3) + Vector3.new(0, 8, 0)
			enemy.stunUntil = math.max(enemy.stunUntil, now + 0.3)
		end
	end
	if effects.lifesteal and attacker then
		Combat.HealPlayer(attacker, damageDealt * effects.lifesteal)
	end
end

-- Elemental reactions: some effects combine with what's already on a shadow.
--   SHATTER  burn a frozen/slowed shadow, or freeze a burning one: a burst of bonus damage
--   OVERLOAD shock (chain or stun) a burning shadow: it explodes, hurting those around it
--   CRUSH    knock back a stunned shadow: bonus damage
function Combat.React(enemy, amount: number, attacker: Player, opts)
	local K = Config.Combos
	local effects = opts.effects
	local now = os.clock()
	if now < (enemy.reactReady or 0) then
		return
	end
	local burning = enemy.burn ~= nil and now < enemy.burn.untilTime
	local slowed = now < enemy.slowUntil
	local stunned = now < enemy.stunUntil
	local kind
	if (effects.burn and slowed) or (effects.slow and burning) then
		kind = "SHATTER"
	elseif burning and not effects.burn and (effects.chain or effects.stun) then
		kind = "OVERLOAD"
	elseif stunned and effects.knockback then
		kind = "CRUSH"
	end
	if not kind then
		return
	end
	enemy.reactReady = now + K.ReactionCooldown
	local position = enemy.root.Position
	Remotes.Fx:FireAllClients("Reaction", { kind = kind, position = position, color = opts.color })
	if kind == "SHATTER" then
		enemy.slowUntil = 0 -- the ice breaks
		Combat.DamageEnemy(enemy, amount * K.Shatter, attacker, { reaction = true, color = Color3.fromRGB(200, 240, 255) })
	elseif kind == "OVERLOAD" then
		for _, other in Combat.EnemiesInSphere(position, K.Overload.radius) do
			Combat.DamageEnemy(other, amount * K.Overload.damage, attacker, { reaction = true, color = Color3.fromRGB(255, 200, 90), effects = { knockback = 40 } })
		end
	else
		Combat.DamageEnemy(enemy, amount * K.Crush, attacker, { reaction = true, color = Color3.fromRGB(255, 120, 90) })
	end
end

-- opts: { effects, sourcePosition, noFx, color, crit, chained, reaction }
function Combat.DamageEnemy(enemy, amount: number, attacker: Player?, opts)
	if enemy.dead or amount <= 0 then
		return 0
	end
	opts = opts or {}
	local now = os.clock()
	if now < enemy.weakenUntil then
		amount *= enemy.weakenMult
	end
	amount = math.floor(amount + 0.5)
	enemy.hp -= amount
	enemy.lastHitTime = now
	enemy.model:SetAttribute("Health", math.max(0, enemy.hp))
	if attacker then
		enemy.damagers[attacker] = (enemy.damagers[attacker] or 0) + amount
		enemy.lastAttacker = attacker
		enemy.aggroOn = attacker
		local lifesteal = passive(attacker).lifesteal
		if lifesteal then
			Combat.HealPlayer(attacker, amount * lifesteal)
		end
	end
	if not opts.noFx then
		Remotes.Fx:FireAllClients("Hit", { position = enemy.root.Position + Vector3.new(0, 2 * (enemy.scale or 1), 0), amount = amount, color = opts.color, crit = opts.crit, target = enemy.model })
	end
	if opts.effects and attacker and not opts.chained and not opts.reaction and enemy.hp > 0 then
		Combat.React(enemy, amount, attacker, opts)
	end
	if opts.effects and not enemy.dead then
		Combat.ApplyEffects(enemy, opts.effects, opts.sourcePosition or enemy.root.Position, attacker, amount)
		-- Chain: arc to nearby shadows (the arcs themselves don't chain again).
		local chain = opts.effects.chain
		if chain and not opts.chained then
			local from = enemy.root.Position
			local targets = {}
			for _, other in Combat.EnemiesInSphere(from, chain.range) do
				if other ~= enemy then
					table.insert(targets, other)
				end
			end
			table.sort(targets, function(a, b)
				return (a.root.Position - from).Magnitude < (b.root.Position - from).Magnitude
			end)
			for i = 1, math.min(chain.count, #targets) do
				local other = targets[i]
				Remotes.Fx:FireAllClients("Bolt", { from = from, to = other.root.Position, color = opts.color or Color3.fromRGB(150, 210, 255) })
				Combat.DamageEnemy(other, amount * chain.damage, attacker, { chained = true, color = opts.color, effects = { stun = 0.3 } })
			end
		end
	end
	if enemy.hp <= 0 and not enemy.dead then -- (a reaction's bonus hit may already have finished it)
		enemy.dead = true
		Registry.EnemyKilled:Fire(enemy, enemy.lastAttacker, enemy.damagers)
	end
	return amount
end

-- Damage to players ------------------------------------------------------------------------

function Combat.HealPlayer(player: Player, amount: number)
	local _, humanoid = Combat.GetCharacter(player)
	if humanoid then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
end

-- source: { enemy = enemy?, position = Vector3, kind = "melee" | "projectile" | "aoe" }
-- Returns "hit", "blocked", "parried", "dodged" or nil if nothing happened.
function Combat.DamagePlayer(player: Player, amount: number, source)
	local character, humanoid, root = Combat.GetCharacter(player)
	if not character then
		return nil
	end
	local state = Combat.GetState(player)
	if state.inSafeZone then
		return nil
	end
	local now = os.clock()
	if now < (state.storyShieldUntil or 0) or now < (state.invulnUntil or 0) then
		return nil -- watching a story scene, or invulnerable (Phase Shift, Time Blur, a Phoenix rebirth)
	end

	-- Dodging through an attack: no damage, and you hit harder for a moment.
	if now < state.dodgeUntil then
		state.damageBuff = C.PerfectDodgeBuff
		state.damageBuffUntil = now + C.PerfectDodgeBuffTime
		state.dodgeUntil = 0 -- one perfect dodge per dash
		Remotes.Fx:FireAllClients("Evade", { character = character })
		Registry.PerfectDodge:Fire(player)
		return "dodged"
	end

	local facing = true
	if source.position then
		local toSource = source.position - root.Position
		toSource = Vector3.new(toSource.X, 0, toSource.Z)
		if toSource.Magnitude > 0.5 then
			facing = root.CFrame.LookVector:Dot(toSource.Unit) > -0.2
		end
	end

	local result = "hit"
	if state.blocking and facing then
		if source.kind == "melee" and now - state.blockStart <= C.ParryWindow and source.enemy then
			source.enemy.stunUntil = math.max(source.enemy.stunUntil, now + C.ParryStun * (source.enemy.isBoss and 0.4 or 1))
			Remotes.Fx:FireAllClients("Parry", { character = character, position = root.Position })
			Registry.Parried:Fire(player, source.enemy)
			return "parried"
		end
		amount *= 1 - C.BlockReduction
		result = "blocked"
	end

	amount *= passive(player).defense or 1
	-- Beginner's Blessing: new players take less damage until their first Ascension.
	local data = PlayerData.Get(player)
	if data and data.act == 2 and data.level < Config.Beginner.UntilLevel then
		amount *= Config.Beginner.DamageTaken
	end
	if InventoryService.HasItem(player, "Coat") then
		amount *= 0.85
	end
	-- Phoenix: a killing blow sets you ablaze and you rise instead.
	local revive = passive(player).revive
	if revive and humanoid.Health - amount <= 0 and now >= (state.reviveReady or 0) then
		state.reviveReady = now + revive
		humanoid.Health = humanoid.MaxHealth * 0.5
		state.invulnUntil = now + 1.5
		Remotes.Fx:FireAllClients("Revive", { character = character, color = Color3.fromRGB(255, 150, 40) })
		Remotes.Notify:FireClient(player, "Toast", { text = "You burn, and rise again!", color = Color3.fromRGB(255, 170, 80) })
		return "revived"
	end
	-- Second Wind (pass): the same idea on a long cooldown.
	if data and data.passes and data.passes.secondwind and humanoid.Health - amount <= 0 and now >= (state.secondWindReady or 0) then
		local SW = Passes.SecondWind
		state.secondWindReady = now + SW.Cooldown
		humanoid.Health = math.max(1, humanoid.MaxHealth * SW.Health)
		state.invulnUntil = now + SW.Protection
		Remotes.Fx:FireAllClients("Revive", { character = character, color = Color3.fromRGB(255, 130, 120) })
		Remotes.Notify:FireClient(player, "Toast", { text = "Second Wind! You stay on your feet.", color = Color3.fromRGB(255, 150, 140) })
		return "revived"
	end
	amount = math.max(1, math.floor(amount + 0.5))
	if result == "hit" then
		Combat.BreakFlow(player)
	end
	humanoid.Health -= amount
	state.lastDamaged = now
	Remotes.Fx:FireAllClients("PlayerHit", { character = character, amount = amount, blocked = result == "blocked" })
	Registry.PlayerDamaged:Fire(player, amount, source)
	return result
end

-- Basic attack ----------------------------------------------------------------------------

function Combat.M1(player: Player, aim: Vector3?)
	local character, _, root = Combat.GetCharacter(player)
	if not character or player:GetAttribute("Act") ~= 2 then
		return
	end
	local state = Combat.GetState(player)
	local now = os.clock()
	if now < state.m1Ready or now < state.stunUntil or state.blocking then
		return
	end
	if now - state.lastM1 > C.M1ComboReset then
		state.combo = 0
	end
	state.combo = state.combo % #C.M1Damage + 1
	state.lastM1 = now
	local finisher = state.combo == #C.M1Damage
	state.m1Ready = now + (finisher and C.M1ComboFinisherCooldown or C.M1Cooldown) * (passive(player).m1Speed or 1)

	local p = power(player)
	local effect = passive(player)
	local look = root.CFrame.LookVector
	if aim then
		local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
		if flat.Magnitude > 0.5 then
			look = flat.Unit
		end
	end
	local center = root.Position + look * (C.M1Range / 2 + 0.5)
	local damage = C.M1Damage[state.combo] * Combat.DamageMultiplier(player) * (effect.m1Damage or 1)
	local color = p and p.color or Color3.new(1, 1, 1)

	Remotes.Fx:FireAllClients("Swing", { character = character, combo = state.combo, color = color, style = p and p.vfx })

	local hits = Combat.EnemiesInSphere(center, C.M1Range / 2 + 0.5)
	Registry.M1Swing:Fire(player, center, C.M1Range / 2 + 0.5)
	local effects = {}
	if finisher then
		effects.knockback = 55
		effects.stun = 0.4
	end
	if effect.m1Burn then
		effects.burn = effect.m1Burn
	end
	if effect.m1Slow then
		effects.slow = effect.m1Slow
	end
	if effect.m1Weaken then
		effects.weaken = effect.m1Weaken
	end
	if effect.m1Pull then
		effects.pull = effect.m1Pull
	end
	for _, enemy in hits do
		Combat.DamageEnemy(enemy, damage, player, { effects = effects, sourcePosition = root.Position, color = color, crit = finisher })
		if effect.m1Heal then
			Combat.HealPlayer(player, effect.m1Heal)
		end
	end
	-- Volt: every 4th hit chains to the nearest other shadow.
	if effect.m1Chain and finisher and #hits > 0 then
		local first = hits[1]
		local best, bestDistance = nil, 26
		for _, enemy in Combat.EnemiesInSphere(first.root.Position, 26) do
			local d = (enemy.root.Position - first.root.Position).Magnitude
			if enemy ~= first and d < bestDistance then
				best, bestDistance = enemy, d
			end
		end
		if best then
			Remotes.Fx:FireAllClients("Bolt", { from = first.root.Position, to = best.root.Position, color = color })
			Combat.DamageEnemy(best, effect.m1Chain * Combat.DamageMultiplier(player), player, { effects = { stun = 0.4 }, color = color })
		end
	end
end

function Combat.SetBlocking(player: Player, blocking: boolean)
	local state = Combat.GetState(player)
	if blocking and not state.blocking then
		state.blockStart = os.clock()
	end
	state.blocking = blocking and player:GetAttribute("Act") == 2
	local character = player.Character
	if character then
		character:SetAttribute("Blocking", state.blocking)
	end
end

function Combat.Dodge(player: Player): boolean
	local character = Combat.GetCharacter(player)
	if not character or player:GetAttribute("Act") ~= 2 then
		return false
	end
	local state = Combat.GetState(player)
	local now = os.clock()
	if now < state.dodgeReady or now < state.stunUntil then
		return false
	end
	state.dodgeReady = now + C.DodgeCooldown
	state.dodgeUntil = now + C.DodgeIFrames
	Remotes.Fx:FireAllClients("Dodge", { character = character })
	return true
end

return Combat
