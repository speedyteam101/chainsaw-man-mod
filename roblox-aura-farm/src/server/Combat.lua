-- Validates the player's Slash / Dash / Ultimate requests using their
-- class's stats. Slashes and ultimates hit the boss and enemy players.
-- The client moves itself for dashes; the server owns cooldowns, i-frames
-- and damage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local AuraMath = require(Shared:WaitForChild("AuraMath"))
local Classes = require(Shared:WaitForChild("Classes"))
local AuraService = require(script.Parent.AuraService)
local BossService = require(script.Parent.BossService)
local Effects = require(script.Parent.Effects)
local PvpService = require(script.Parent.PvpService)

local Combat = {}

local DEFAULT_COLOR = Color3.fromRGB(210, 235, 255)

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function classColor(player: Player): Color3
	local class = AuraService.classOf(player)
	return if class then Effects.color(class.Color) else DEFAULT_COLOR
end

-- Options for your custom effect models (see Assets.lua).
local function effectOptions(player: Player, color: Color3, radius: number?)
	local class = AuraService.classOf(player)
	return {
		classId = if class then class.Id else nil,
		side = AuraService.sideOf(player),
		color = color,
		radius = radius,
	}
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Hits the boss for `amount`; returns true if it landed.
local function hitBoss(player: Player, amount: number, source: string): boolean
	if BossService.damage(player, amount, source) then
		AuraService.onDealtDamage(player, amount)
		return true
	end
	return false
end

---------------------------------------------------------------------------
-- Slash and dash
---------------------------------------------------------------------------

local function slash(player: Player, root: BasePart, state)
	local now = os.clock()
	if now - state.lastSlash < AuraService.stat(player, "SlashCooldown") then
		return
	end
	state.lastSlash = now
	local color = classColor(player)
	local options = effectOptions(player, color)
	Effects.slash(root.CFrame, color, options.classId, options.side)

	local damage = AuraService.stat(player, "SlashDamage")
	local range = AuraService.stat(player, "SlashRange")
	local landed = false

	local distance = BossService.distanceTo(root.Position)
	if distance and distance <= range and hitBoss(player, damage, "Slash") then
		landed = true
		local boss = BossService.getActive()
		if boss then
			-- On the boss's surface, on the attacker's side.
			local centre = boss.model:GetPivot().Position
			local toward = flat(root.Position - centre)
			local at = centre + (if toward.Magnitude > 0.1 then toward.Unit * boss.radius else Vector3.zero)
			Effects.custom("Hit", CFrame.lookAt(at, root.Position), effectOptions(player, color))
		end
	end

	-- Enemy players roughly in front of you (or right on top of you).
	local look = flat(root.CFrame.LookVector).Unit
	for _, enemy in ipairs(PvpService.enemiesNear(player, root.Position, range + Config.Pvp.HitRangeBonus)) do
		local enemyRoot = aliveRoot(enemy)
		if enemyRoot then
			local offset = flat(enemyRoot.Position - root.Position)
			local inFront = offset.Magnitude < 3 or look:Dot(offset.Unit) >= Config.Pvp.HitConeDot
			if inFront and PvpService.damage(player, enemy, damage * Config.Pvp.HitPlayerDamageFactor, "Slash") > 0 then
				landed = true
				Effects.custom("Hit", CFrame.lookAt(enemyRoot.Position, root.Position), effectOptions(player, color))
			end
		end
	end

	if landed then
		AuraService.addStyle(player, Config.Style.PerHit)
		local styleRank = AuraService.styleRank(player)
		local aura = math.floor(Config.Combat.AuraPerHit * styleRank.Multiplier + 0.5)
		AuraService.addAura(player, aura, nil, nil, true)
	end
end

local function dash(player: Player, root: BasePart, state)
	local now = os.clock()
	-- A little slack for network jitter versus the client's own cooldown.
	if now - state.lastDash < AuraService.stat(player, "DashCooldown") - 0.15 then
		return
	end
	state.lastDash = now
	state.dashStartPos = root.Position
	state.invulnerableUntil = math.max(state.invulnerableUntil, now + Config.Combat.DashInvulnerability)
	-- Every client draws this player's avatar afterimages (and your custom
	-- Dash effect, if any).
	AuraService.broadcast({ Kind = "Dash", UserId = player.UserId })
end

---------------------------------------------------------------------------
-- Ultimates. Each returns true if it was used (and should cost style).
---------------------------------------------------------------------------

local function nearestEnemy(player: Player, position: Vector3, radius: number): Player?
	local best, bestDistance = nil, math.huge
	for _, enemy in ipairs(PvpService.enemiesNear(player, position, radius)) do
		local enemyRoot = aliveRoot(enemy)
		if enemyRoot then
			local distance = (enemyRoot.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = enemy, distance
			end
		end
	end
	return best
end

-- Damage everything around `position` within `radius`. Returns damage dealt.
local function blast(player: Player, position: Vector3, radius: number, kind, power: number): number
	local total = 0
	local distance = BossService.distanceTo(position)
	if distance and distance <= radius and hitBoss(player, kind.BossDamage * power, "Ultimate") then
		total += kind.BossDamage * power
	end
	for _, enemy in ipairs(PvpService.enemiesNear(player, position, radius)) do
		total += PvpService.damage(player, enemy, kind.PlayerDamage * power, "Ultimate")
	end
	return total
end

-- Heal allies (and yourself) around you; aura for each ally helped.
local function supportAllies(player: Player, root: BasePart, kind, power: number, title: string, perAlly: (Player) -> ())
	local allies = PvpService.alliesNear(player, root.Position, kind.Radius)
	local helped = 0
	for _, ally in ipairs(allies) do
		local character = ally.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			AuraService.heal(ally, humanoid.MaxHealth * kind.HealPercent * power)
		end
		perAlly(ally)
		if ally ~= player then
			helped += 1
		end
	end
	if helped > 0 then
		AuraService.addAura(player, helped * kind.AuraPerAlly, title, { string.format("Helped %d all%s", helped, if helped == 1 then "y" else "ies") })
	end
end

local ULTIMATES = {}

-- Your Ultimate<Kind> effect model if you've added one, otherwise the
-- built-in visuals.
local function ultimateVisual(player: Player, kindName: string, cframe: CFrame, radius: number?, color: Color3, builtIn: () -> ())
	if not Effects.custom("Ultimate" .. kindName, cframe, effectOptions(player, color, radius)) then
		builtIn()
	end
end

function ULTIMATES.Pillar(player: Player, root: BasePart, kind, power: number, color: Color3): boolean
	local boss = BossService.getActive()
	local distance = BossService.distanceTo(root.Position)
	if boss and distance and distance <= kind.Range then
		local target = boss.model:GetPivot().Position
		local ground = Vector3.new(target.X, root.Position.Y - 3, target.Z)
		ultimateVisual(player, "Pillar", CFrame.new(ground), nil, color, function()
			Effects.pillar(ground, color)
		end)
		hitBoss(player, (boss.maxHealth * kind.BossFraction + kind.BossFlat) * power, "Ultimate")
		return true
	end
	local enemy = nearestEnemy(player, root.Position, kind.Range)
	local enemyRoot = enemy and aliveRoot(enemy)
	if enemy and enemyRoot then
		local ground = enemyRoot.Position - Vector3.new(0, 3, 0)
		ultimateVisual(player, "Pillar", CFrame.new(ground), nil, color, function()
			Effects.pillar(ground, color)
		end)
		PvpService.damage(player, enemy, kind.PlayerDamage * power, "Ultimate")
		return true
	end
	AuraService.notify(player, { Kind = "Message", Text = "No target in range for your ultimate!" })
	return false
end

function ULTIMATES.Nova(player: Player, root: BasePart, kind, power: number, color: Color3): boolean
	ultimateVisual(player, "Nova", root.CFrame, kind.Radius, color, function()
		Effects.burst(root.Position, kind.Radius, color, 0.5)
		Effects.shockwave(root.Position - Vector3.new(0, 2.5, 0), kind.Radius, color)
	end)
	blast(player, root.Position, kind.Radius, kind, power)
	return true
end

function ULTIMATES.Drain(player: Player, root: BasePart, kind, power: number, color: Color3): boolean
	ultimateVisual(player, "Drain", root.CFrame, kind.Radius, color, function()
		Effects.shockwave(root.Position - Vector3.new(0, 2.5, 0), kind.Radius, color)
		Effects.dome(root.Position, kind.Radius, color)
	end)
	local dealt = blast(player, root.Position, kind.Radius, kind, power)
	AuraService.heal(player, dealt * kind.HealFraction)
	return true
end

function ULTIMATES.Rush(player: Player, root: BasePart, kind, power: number, color: Color3): boolean
	local direction = flat(root.CFrame.LookVector)
	if direction.Magnitude < 0.1 then
		return false
	end
	direction = direction.Unit
	local origin = root.Position
	ultimateVisual(player, "Rush", CFrame.lookAt(origin, origin + direction), nil, color, function()
		Effects.streak(origin, origin + direction * kind.Length, kind.Width, color)
	end)

	local boss = BossService.getActive()
	if boss and boss.alive then
		local position = boss.model:GetPivot().Position
		-- Widen the line by the boss's size so grazing it still counts.
		local width = kind.Width + boss.radius * 2
		if AuraMath.inRect(position.X, position.Z, origin.X, origin.Z, direction.X, direction.Z, kind.Length + boss.radius, width) then
			hitBoss(player, kind.BossDamage * power, "Ultimate")
		end
	end
	for _, enemy in ipairs(PvpService.enemiesNear(player, origin, kind.Length + 2)) do
		local enemyRoot = aliveRoot(enemy)
		if enemyRoot and AuraMath.inRect(enemyRoot.Position.X, enemyRoot.Position.Z, origin.X, origin.Z, direction.X, direction.Z, kind.Length, kind.Width) then
			PvpService.damage(player, enemy, kind.PlayerDamage * power, "Ultimate")
		end
	end
	-- Invincible during the rush, and the client carries you along the line.
	local state = AuraService.get(player)
	if state then
		state.invulnerableUntil = math.max(state.invulnerableUntil, os.clock() + 0.4)
	end
	AuraService.notify(player, { Kind = "Rush", Distance = kind.Length })
	return true
end

function ULTIMATES.Mend(player: Player, root: BasePart, kind, power: number, color: Color3): boolean
	ultimateVisual(player, "Mend", root.CFrame, kind.Radius, color, function()
		Effects.dome(root.Position, kind.Radius, color)
	end)
	supportAllies(player, root, kind, power, "HEALER", function() end)
	return true
end

function ULTIMATES.Fortify(player: Player, root: BasePart, kind, power: number, color: Color3): boolean
	ultimateVisual(player, "Fortify", root.CFrame, kind.Radius, color, function()
		Effects.dome(root.Position, kind.Radius, color)
	end)
	local untilTime = os.clock() + kind.Duration * power
	supportAllies(player, root, kind, power, "PROTECTOR", function(ally)
		local allyState = AuraService.get(ally)
		if allyState then
			allyState.invulnerableUntil = math.max(allyState.invulnerableUntil, untilTime)
		end
	end)
	return true
end

local function ultimate(player: Player, root: BasePart, state)
	local now = os.clock()
	if now - state.lastUltimate < Config.Combat.UltimateCooldown then
		return
	end
	local class = AuraService.classOf(player)
	if not class then
		AuraService.notify(player, { Kind = "Message", Text = "Pick a class to unlock your ultimate!" })
		return
	end
	if state.style < Config.Combat.UltimateStyleCost then
		AuraService.notify(player, { Kind = "Message", Text = "Reach S style rank to unleash your ultimate!" })
		return
	end

	local ult = class.Ultimate
	local kind = Classes.UltimateKinds[ult.Kind]
	local color = Effects.color(class.Color):Lerp(Color3.new(1, 1, 1), 0.4)
	-- Damage first: a finishing ultimate is paid out at your full style rank.
	if ULTIMATES[ult.Kind](player, root, kind, ult.Power, color) then
		state.lastUltimate = now
		AuraService.addStyle(player, -Config.Combat.UltimateStyleCost)
		if player.Character then
			Effects.showSpeech(player.Character, string.upper(ult.Name) .. "!", 2, Effects.color(class.Color))
		end
	end
end

local HANDLERS = { Slash = slash, Dash = dash, Ultimate = ultimate }

function Combat.handle(player: Player, action: any)
	local handler = type(action) == "string" and HANDLERS[action]
	if not handler then
		return
	end
	local state = AuraService.get(player)
	local root = aliveRoot(player)
	if state and root then
		handler(player, root, state)
	end
end

return Combat
