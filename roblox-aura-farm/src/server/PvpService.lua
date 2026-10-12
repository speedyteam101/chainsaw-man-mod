-- Good vs Evil PvP: who can hurt whom, kill credit, kill rewards and the
-- aura lost for dying.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local AuraMath = require(Shared:WaitForChild("AuraMath"))
local Classes = require(Shared:WaitForChild("Classes"))
local AuraService = require(script.Parent.AuraService)
local BossService = require(script.Parent.BossService)
local World = require(script.Parent.World)

local PvpService = {}

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function healthFraction(player: Player): number
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.MaxHealth <= 0 then
		return 0
	end
	return humanoid.Health / humanoid.MaxHealth
end

-- Only Good vs Evil, both alive, neither standing in a safe zone.
function PvpService.canHurt(attacker: Player, victim: Player): boolean
	if attacker == victim then
		return false
	end
	local attackerSide, victimSide = AuraService.sideOf(attacker), AuraService.sideOf(victim)
	if not attackerSide or not victimSide or attackerSide == victimSide then
		return false
	end
	local attackerRoot, victimRoot = aliveRoot(attacker), aliveRoot(victim)
	if not attackerRoot or not victimRoot then
		return false
	end
	return not World.inSafeZone(attackerRoot.Position) and not World.inSafeZone(victimRoot.Position)
end

-- Enemy players `player` can hurt within `radius` of `position`.
function PvpService.enemiesNear(player: Player, position: Vector3, radius: number): { Player }
	local list = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local root = aliveRoot(other)
		if root and (root.Position - position).Magnitude <= radius and PvpService.canHurt(player, other) then
			table.insert(list, other)
		end
	end
	return list
end

-- Living players on `player`'s side (including `player`) within `radius`.
function PvpService.alliesNear(player: Player, position: Vector3, radius: number): { Player }
	local side = AuraService.sideOf(player)
	local list = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local root = aliveRoot(other)
		if root and (root.Position - position).Magnitude <= radius and (other == player or (side ~= nil and AuraService.sideOf(other) == side)) then
			table.insert(list, other)
		end
	end
	return list
end

-- For heroic lines: an enemy player nearby counts as a fight.
function PvpService.contextFor(player: Player)
	local root = aliveRoot(player)
	if not root then
		return { inFight = false, foeHealthFraction = nil }
	end
	local lowest = nil
	for _, enemy in ipairs(PvpService.enemiesNear(player, root.Position, Config.Pvp.FightRadius)) do
		local fraction = healthFraction(enemy)
		if not lowest or fraction < lowest then
			lowest = fraction
		end
	end
	return { inFight = lowest ~= nil, foeHealthFraction = lowest }
end

--[[
	Damages an enemy player. Returns the damage dealt (0 if not allowed, or
	if the victim was invincible). A blocked hit right after the victim
	dashed counts as their perfect dodge (once per dash).
]]
function PvpService.damage(attacker: Player, victim: Player, amount: number, source: string): number
	if not PvpService.canHurt(attacker, victim) then
		return 0
	end
	local victimState = AuraService.get(victim)
	local attackerState = AuraService.get(attacker)
	if not victimState or not attackerState then
		return 0
	end

	-- Record the attacker before the damage: Humanoid.Died may fire during
	-- TakeDamage, and the kill must already be credited. Undone below if
	-- the hit is blocked.
	local now = os.clock()
	local previous = {
		victimState.lastAttacker,
		victimState.lastAttackTime,
		victimState.lastAttackSource,
		victimState.lastAttackStyle,
	}
	victimState.lastAttacker = attacker
	victimState.lastAttackTime = now
	victimState.lastAttackSource = source
	-- The attacker's style now: an ultimate spends style right after
	-- hitting, and a finishing blow should pay at the old rank.
	victimState.lastAttackStyle = attackerState.style

	local dealt = AuraService.takeDamage(victim, amount)
	if dealt > 0 then
		AuraService.onDealtDamage(attacker, dealt)
		return dealt
	end
	victimState.lastAttacker, victimState.lastAttackTime, victimState.lastAttackSource, victimState.lastAttackStyle =
		previous[1], previous[2], previous[3], previous[4]
	if now - victimState.lastDash <= Config.Combat.PerfectDodgeWindow and victimState.dodgedDash ~= victimState.lastDash then
		victimState.dodgedDash = victimState.lastDash
		AuraService.onPerfectDodge(victim)
	end
	return dealt
end

local function rewardKill(killer: Player, victim: Player, source: string, styleAtHit: number, position: Vector3)
	local killerState = AuraService.get(killer)
	local victimState = AuraService.get(victim)
	if not killerState or not victimState then
		return
	end
	local now = os.clock()

	-- How often the killer already beat this victim recently.
	local recent = {}
	for _, time in ipairs(killerState.kills[victim.UserId] or {}) do
		if now - time < Config.Pvp.RepeatWindow then
			table.insert(recent, time)
		end
	end
	local repeats = #recent
	table.insert(recent, now)
	killerState.kills[victim.UserId] = recent

	local killerHealth = healthFraction(killer)
	local flags = {
		Clutch = killerHealth > 0 and killerHealth < Config.ClutchHealthFraction,
		CalledIt = now - killerState.lastHeroicLine <= Config.CalledItWindow,
		Finisher = source == "Ultimate",
		Revenge = killerState.lastKilledBy == victim,
	}
	if flags.Revenge then
		killerState.lastKilledBy = nil
	end

	local styleRank = AuraMath.getRank(styleAtHit, Config.Style.Ranks)
	local total, breakdown = AuraMath.pvpKillReward(
		Config.Pvp,
		Config.PvpBonuses,
		Config.DefeatBonuses,
		killerState.rankIndex,
		victimState.rankIndex,
		styleRank,
		flags,
		repeats
	)
	killerState.lastKill = now
	AuraService.addAura(killer, total, nil, nil, true)
	local side = AuraService.sideOf(killer)
	AuraService.notify(killer, {
		Kind = "Banner",
		Title = "DEFEATED " .. string.upper(victim.DisplayName),
		Lines = breakdown,
		Total = total,
		Color = if side then Classes.Sides[side].Color else { 255, 255, 255 },
	})
	AuraService.announce(string.format("%s (%s) defeated %s (%s)!", killer.DisplayName, AuraService.rankName(killer), victim.DisplayName, AuraService.rankName(victim)))
	AuraService.startWalkAwayCheck(killer, position)
end

local function onDied(player: Player, position: Vector3)
	local state = AuraService.get(player)
	if not state then
		return
	end
	local killer = state.lastAttacker
	if killer and killer.Parent and os.clock() - state.lastAttackTime <= Config.Pvp.KillCreditWindow then
		rewardKill(killer, player, state.lastAttackSource, state.lastAttackStyle, position)
		state.lastKilledBy = killer
		AuraService.addAura(player, -Config.Pvp.DeathAuraLoss, "DEFEATED", { "by " .. killer.DisplayName })
	elseif BossService.isParticipant(player) then
		AuraService.addAura(player, -Config.Combat.DeathAuraLoss, "TOOK THE L", { "Fell in battle" })
	end
	state.lastAttacker = nil
	AuraService.resetStyle(player)
end

function PvpService.watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		onDied(player, if root then root.Position else Vector3.zero)
	end)
end

return PvpService
