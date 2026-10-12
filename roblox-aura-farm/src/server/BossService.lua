-- Summons, moves and fights the bosses, and pays out aura when one dies.
-- One boss can be in the arena at a time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local AuraMath = require(Shared:WaitForChild("AuraMath"))
local AuraService = require(script.Parent.AuraService)
local Effects = require(script.Parent.Effects)
local World = require(script.Parent.World)

local BossService = {}

type Participant = { damage: number, hurt: boolean }
type Boss = {
	def: any,
	model: Model,
	body: BasePart,
	eyes: { BasePart },
	radius: number,
	hoverY: number,
	health: number,
	maxHealth: number,
	alive: boolean,
	busy: boolean,
	enraged: boolean,
	target: Player?,
	lastEngaged: number,
	participants: { [Player]: Participant },
	baseColors: { [BasePart]: Color3 },
}

local active: Boss? = nil
local readyAt: { [string]: number } = {}

local bossFolder = Instance.new("Folder")
bossFolder.Name = "AuraFarmBosses"
bossFolder.Parent = workspace

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function inArena(position: Vector3): boolean
	return AuraMath.inCircle(position.X, position.Z, World.ArenaCenter.X, World.ArenaCenter.Z, Config.ArenaRadius)
end

-- Living players standing in the arena.
local function fighters(): { Player }
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = rootOf(player)
		if root and inArena(root.Position) then
			table.insert(list, player)
		end
	end
	return list
end

local function participant(boss: Boss, player: Player): Participant
	local entry = boss.participants[player]
	if not entry then
		entry = { damage = 0, hurt = false }
		boss.participants[player] = entry
	end
	return entry
end

local function bossPosition(boss: Boss): Vector3
	return boss.model:GetPivot().Position
end

local function groundUnder(position: Vector3): Vector3
	return Vector3.new(position.X, World.FloorY + 0.1, position.Z)
end

-- Distance from a point to the boss's surface (roughly).
function BossService.distanceTo(position: Vector3): number?
	local boss = active
	if not boss or not boss.alive then
		return nil
	end
	return (bossPosition(boss) - position).Magnitude - boss.radius
end

function BossService.getActive(): Boss?
	return active
end

-- For AuraService: is this player in a fight, and how hurt is the boss?
function BossService.contextFor(player: Player)
	local boss = active
	local root = rootOf(player)
	if boss and boss.alive and root and inArena(root.Position) then
		return { inBossFight = true, bossHealthFraction = boss.health / boss.maxHealth }
	end
	return { inBossFight = false, bossHealthFraction = nil }
end

---------------------------------------------------------------------------
-- Model
---------------------------------------------------------------------------

local function buildModel(def): (Model, BasePart, { BasePart })
	local s = def.Size
	local color = Effects.color(def.Color)
	local eyeColor = Effects.color(def.EyeColor)
	local model = Instance.new("Model")
	model.Name = def.Name

	local function piece(name: string, size: Vector3, offset: CFrame, partColor: Color3, material: Enum.Material, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.Color = partColor
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = offset
		p.Parent = model
		return p
	end

	-- Built around the origin facing -Z, then moved into place with PivotTo.
	local body = piece("Body", Vector3.new(s, s * 1.1, s * 0.8), CFrame.new(), color, Enum.Material.Slate)
	piece("Head", Vector3.new(s * 0.55, s * 0.5, s * 0.55), CFrame.new(0, s * 0.8, -s * 0.05), color, Enum.Material.Slate)
	local eyes = {
		piece("EyeL", Vector3.new(s * 0.12, s * 0.07, 0.2), CFrame.new(-s * 0.13, s * 0.85, -s * 0.33), eyeColor, Enum.Material.Neon),
		piece("EyeR", Vector3.new(s * 0.12, s * 0.07, 0.2), CFrame.new(s * 0.13, s * 0.85, -s * 0.33), eyeColor, Enum.Material.Neon),
	}
	for side = -1, 1, 2 do
		piece("Shoulder", Vector3.new(s * 0.4, s * 0.4, s * 0.4), CFrame.new(side * s * 0.65, s * 0.4, 0) * CFrame.Angles(0, 0, math.rad(45)), color, Enum.Material.Slate)
		piece("Spike", Vector3.new(s * 0.12, s * 0.5, s * 0.12), CFrame.new(side * s * 0.75, s * 0.8, 0) * CFrame.Angles(0, 0, math.rad(-side * 25)), eyeColor, Enum.Material.Neon)
		piece("Fist", Vector3.new(s * 0.35, s * 0.35, s * 0.35), CFrame.new(side * s * 0.75, -s * 0.35, -s * 0.2), color, Enum.Material.Slate)
		piece("Horn", Vector3.new(s * 0.08, s * 0.35, s * 0.08), CFrame.new(side * s * 0.2, s * 1.15, -s * 0.05) * CFrame.Angles(0, 0, math.rad(-side * 20)), eyeColor, Enum.Material.Neon)
	end
	piece("Core", Vector3.new(s * 0.3, s * 0.3, s * 0.3), CFrame.new(0, 0, -s * 0.4), eyeColor, Enum.Material.Neon, Enum.PartType.Ball)

	model.PrimaryPart = body

	-- Overhead name + health bar.
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossBar"
	gui.Size = UDim2.fromOffset(260, 46)
	gui.StudsOffset = Vector3.new(0, s * 1.5, 0)
	gui.MaxDistance = 250
	gui.LightInfluence = 0
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromOffset(260, 24)
	name.Font = Enum.Font.GothamBlack
	name.TextSize = 20
	name.TextColor3 = eyeColor
	name.TextStrokeTransparency = 0.2
	name.Text = def.Name
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Position = UDim2.fromOffset(10, 28)
	back.Size = UDim2.fromOffset(240, 12)
	back.BackgroundColor3 = Color3.fromRGB(30, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 50, 50)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = body

	return model, body, eyes
end

local function updateHealthDisplay(boss: Boss)
	boss.model:SetAttribute("Health", math.max(0, math.floor(boss.health + 0.5)))
	local gui = boss.body:FindFirstChild("BossBar")
	local back = gui and gui:FindFirstChild("Back")
	local fill = back and back:FindFirstChild("Fill")
	if fill then
		fill.Size = UDim2.fromScale(math.clamp(boss.health / boss.maxHealth, 0, 1), 1)
	end
end

local function flash(boss: Boss)
	for part in pairs(boss.baseColors) do
		part.Color = Color3.new(1, 1, 1)
	end
	task.delay(0.07, function()
		for part, color in pairs(boss.baseColors) do
			if part.Parent then
				part.Color = color
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Attacks
---------------------------------------------------------------------------

local function windup(boss: Boss): number
	return boss.def.Windup * (if boss.enraged then boss.def.EnrageSpeedup else 1)
end

-- Damages everyone standing in the zone, or rewards them for a last-second
-- dash. inZone(x, z) -> boolean.
local function resolve(boss: Boss, inZone: (number, number) -> boolean)
	local now = os.clock()
	for _, player in ipairs(fighters()) do
		local root = rootOf(player)
		local state = AuraService.get(player)
		if root and state then
			local position = root.Position
			local hit = inZone(position.X, position.Z)
			local dashedRecently = now - state.lastDash <= Config.Combat.PerfectDodgeWindow
			local startedInZone = state.dashStartPos ~= nil and inZone(state.dashStartPos.X, state.dashStartPos.Z)
			local protected = now < state.invulnerableUntil

			if hit and not protected then
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:TakeDamage(boss.def.Damage)
					participant(boss, player).hurt = true
					AuraService.onHurt(player)
				end
			elseif dashedRecently and (hit or startedInZone) then
				participant(boss, player)
				AuraService.onPerfectDodge(player)
			end
		end
	end
end

local function slam(boss: Boss)
	local radius = Config.Attacks.Slam.Radius + boss.radius
	local centre = groundUnder(bossPosition(boss))
	local t = windup(boss)
	Effects.telegraphCircle(centre, radius, t)
	-- Rise up during the windup, then drop.
	local start = boss.model:GetPivot()
	boss.model:PivotTo(start + Vector3.new(0, 4, 0))
	task.wait(t)
	if not boss.alive then
		return
	end
	boss.model:PivotTo(start - Vector3.new(0, 1.5, 0))
	Effects.shockwave(centre, radius, Effects.color(boss.def.EyeColor))
	resolve(boss, function(x, z)
		return AuraMath.inCircle(x, z, centre.X, centre.Z, radius)
	end)
	task.wait(0.25)
	if boss.alive then
		boss.model:PivotTo(start)
	end
end

local function charge(boss: Boss)
	local target = boss.target
	local targetRoot = target and rootOf(target)
	if not targetRoot then
		return
	end
	local from = bossPosition(boss)
	local flat = Vector3.new(targetRoot.Position.X - from.X, 0, targetRoot.Position.Z - from.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, 1)
	end
	local direction = flat.Unit
	local length = Config.Attacks.Charge.Length
	local width = Config.Attacks.Charge.Width + boss.radius
	-- Don't charge out of the arena: shorten the run, or slam instead.
	local function staysInside(distance: number): boolean
		local finish = from + direction * distance
		return AuraMath.inCircle(finish.X, finish.Z, World.ArenaCenter.X, World.ArenaCenter.Z, Config.ArenaRadius - 8)
	end
	while length > 10 and not staysInside(length) do
		length -= 5
	end
	if length <= 10 then
		slam(boss)
		return
	end
	local origin = groundUnder(from)
	local t = windup(boss)
	Effects.telegraphRect(origin, direction, length, width, t)
	boss.model:PivotTo(CFrame.lookAt(from, from + direction))
	task.wait(t)
	if not boss.alive then
		return
	end

	resolve(boss, function(x, z)
		return AuraMath.inRect(x, z, origin.X, origin.Z, direction.X, direction.Z, length, width)
	end)
	-- Rush along the line.
	local duration = Config.Attacks.Charge.Duration
	local elapsed = 0
	while elapsed < duration and boss.alive do
		elapsed += RunService.Heartbeat:Wait()
		local alpha = math.min(elapsed / duration, 1)
		local position = from + direction * (length * alpha)
		boss.model:PivotTo(CFrame.lookAt(position, position + direction))
	end
end

local function barrage(boss: Boss)
	local radius = Config.Attacks.Barrage.Radius
	local spots = {}
	for _, player in ipairs(fighters()) do
		local root = rootOf(player)
		if root then
			table.insert(spots, groundUnder(root.Position))
		end
	end
	local t = windup(boss) * 1.2
	for _, spot in ipairs(spots) do
		Effects.telegraphCircle(spot, radius, t)
	end
	task.wait(t)
	if not boss.alive then
		return
	end
	local color = Effects.color(boss.def.EyeColor)
	for _, spot in ipairs(spots) do
		Effects.burst(spot + Vector3.new(0, 2, 0), radius, color, 0.35)
	end
	resolve(boss, function(x, z)
		for _, spot in ipairs(spots) do
			if AuraMath.inCircle(x, z, spot.X, spot.Z, radius) then
				return true
			end
		end
		return false
	end)
end

local ATTACKS = { Slam = slam, Charge = charge, Barrage = barrage }

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

local function despawn(boss: Boss, reason: string)
	boss.alive = false
	if active == boss then
		active = nil
	end
	boss.model:Destroy()
	AuraService.announce(reason)
end

local function startWalkAwayCheck(player: Player, explosion: Vector3)
	local settings = Config.WalkAway
	task.spawn(function()
		local function flatDistance(position: Vector3): number
			return Vector3.new(position.X - explosion.X, 0, position.Z - explosion.Z).Magnitude
		end
		local startRoot = rootOf(player)
		if not startRoot then
			return
		end
		-- Uses positions rather than Humanoid.MoveDirection, which the API
		-- marks as not replicated.
		local lastDistance = flatDistance(startRoot.Position)
		local samples, good = 0, 0
		local elapsed = 0
		while elapsed < settings.Duration do
			task.wait(settings.SampleInterval)
			elapsed += settings.SampleInterval
			local root = rootOf(player)
			if not root then
				return
			end
			samples += 1
			local look = root.CFrame.LookVector
			local toBoss = explosion - root.Position
			local distance = flatDistance(root.Position)
			if AuraMath.isWalkingAway(look.X, look.Z, toBoss.X, toBoss.Z, distance - lastDistance) then
				good += 1
			end
			lastDistance = distance
		end
		if samples > 0 and good / samples >= settings.RequiredFraction then
			AuraService.addAura(player, settings.Aura, settings.Label, { "Cool guys don't look at explosions" })
		end
	end)
end

local function defeat(boss: Boss, killer: Player, source: string)
	boss.alive = false
	if active == boss then
		active = nil
	end
	local def = boss.def
	local now = os.clock()
	local explosion = bossPosition(boss)

	AuraService.announce(string.format("%s defeated %s!", killer.DisplayName, def.Name))

	for player, entry in pairs(boss.participants) do
		local state = AuraService.get(player)
		if state and player.Parent and entry.damage > 0 then
			local isKiller = player == killer
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local healthFraction = if humanoid and humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
			local flags = {
				Killer = isKiller,
				Flawless = not entry.hurt,
				Clutch = isKiller and healthFraction > 0 and healthFraction < Config.ClutchHealthFraction,
				CalledIt = isKiller and now - state.lastHeroicLine <= Config.CalledItWindow,
				Finisher = isKiller and source == "Ultimate",
			}
			local styleRank = AuraService.styleRank(player)
			local total, breakdown = AuraMath.defeatReward(def.Reward, styleRank, flags, Config.DefeatBonuses, Config.AssistFraction)
			AuraService.addAura(player, total, nil, nil, true)
			AuraService.notify(player, {
				Kind = "Banner",
				Title = def.Name .. " DEFEATED",
				Lines = breakdown,
				Total = total,
				Color = def.EyeColor,
			})
			startWalkAwayCheck(player, explosion)
		end
	end

	-- Out of the boss folder first so clients drop the health bar.
	boss.model.Parent = workspace
	Effects.explodeModel(boss.model, Effects.color(def.EyeColor))
end

-- Deal damage to the active boss. source is "Slash" or "Ultimate".
-- Returns true if the hit landed.
function BossService.damage(player: Player, amount: number, source: string): boolean
	local boss = active
	if not boss or not boss.alive then
		return false
	end
	local entry = participant(boss, player)
	entry.damage += amount
	boss.health -= amount
	boss.lastEngaged = os.clock()
	flash(boss)
	updateHealthDisplay(boss)

	local def = boss.def
	if def.EnrageAt and not boss.enraged and boss.health > 0 and boss.health / boss.maxHealth < def.EnrageAt then
		boss.enraged = true
		for _, eye in ipairs(boss.eyes) do
			eye.Color = Color3.fromRGB(255, 30, 30)
			boss.baseColors[eye] = eye.Color
		end
		boss.model:SetAttribute("Enraged", true)
		AuraService.announce(def.Name .. " is ENRAGED!")
	end

	if boss.health <= 0 then
		defeat(boss, player, source)
	end
	return true
end

-- Movement: drift toward the target and bob, unless mid-attack.
local function step(boss: Boss, dt: number)
	if boss.busy or not boss.alive then
		return
	end
	local current = bossPosition(boss)
	local bob = math.sin(os.clock() * 2) * 0.6
	local flatPos = Vector3.new(current.X, boss.hoverY + bob, current.Z)
	local facing = boss.model:GetPivot().LookVector
	local root = boss.target and rootOf(boss.target)
	if root then
		local toTarget = Vector3.new(root.Position.X - current.X, 0, root.Position.Z - current.Z)
		local distance = toTarget.Magnitude
		if distance > 0.1 then
			facing = toTarget.Unit
			local keepAway = boss.radius + 5
			if distance > keepAway then
				local speed = boss.def.Speed * (if boss.enraged then 1.3 else 1)
				flatPos += facing * math.min(speed * dt, distance - keepAway)
			end
		end
	end
	if not inArena(flatPos) then
		flatPos = Vector3.new(current.X, flatPos.Y, current.Z)
	end
	boss.model:PivotTo(CFrame.lookAt(flatPos, flatPos + Vector3.new(facing.X, 0, facing.Z)))
end

local function closestFighter(boss: Boss): Player?
	local best, bestDistance = nil, math.huge
	local position = bossPosition(boss)
	for _, player in ipairs(fighters()) do
		local root = rootOf(player)
		if root then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best
end

local function brain(boss: Boss)
	local def = boss.def
	local nextAttack = os.clock() + 2.5 -- a moment to say your opening line
	while boss.alive do
		local now = os.clock()
		boss.target = closestFighter(boss)
		if boss.target then
			boss.lastEngaged = now
		elseif now - boss.lastEngaged > Config.BossLeashTime then
			despawn(boss, def.Name .. " got bored and left.")
			return
		end

		if boss.target and now >= nextAttack then
			boss.busy = true
			local attack = ATTACKS[def.Attacks[math.random(1, #def.Attacks)]]
			local ok, err = pcall(attack, boss)
			if not ok then
				warn("[AuraFarm] Boss attack failed:", err)
			end
			boss.busy = false
			local interval = def.AttackInterval * (if boss.enraged then def.EnrageSpeedup else 1)
			nextAttack = os.clock() + interval
		end
		task.wait(0.1)
	end
end

function BossService.summon(player: Player, def)
	if active then
		AuraService.notify(player, { Kind = "Message", Text = active.def.Name .. " is already in the arena!" })
		return
	end
	local now = os.clock()
	if readyAt[def.Id] and now < readyAt[def.Id] then
		AuraService.notify(player, {
			Kind = "Message",
			Text = string.format("%s is recovering. Try again in %ds.", def.Name, math.ceil(readyAt[def.Id] - now)),
		})
		return
	end
	readyAt[def.Id] = now + def.Cooldown

	local model, body, eyes = buildModel(def)
	local hoverY = World.FloorY + def.Size * 0.55 + 1.5
	local spawnAt = Vector3.new(World.BossSpawn.X, hoverY, World.BossSpawn.Z)
	model:PivotTo(CFrame.lookAt(spawnAt, spawnAt + Vector3.new(0, 0, 1)))
	model:SetAttribute("DisplayName", def.Name)
	model:SetAttribute("Title", def.Title)
	model:SetAttribute("MaxHealth", def.MaxHealth)
	model:SetAttribute("Health", def.MaxHealth)
	model:SetAttribute("Enraged", false)
	model.Parent = bossFolder

	local baseColors = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			baseColors[descendant] = descendant.Color
		end
	end

	local boss: Boss = {
		def = def,
		model = model,
		body = body,
		eyes = eyes,
		radius = def.Size * 0.6,
		hoverY = hoverY,
		health = def.MaxHealth,
		maxHealth = def.MaxHealth,
		alive = true,
		busy = false,
		enraged = false,
		target = nil,
		lastEngaged = now,
		participants = {},
		baseColors = baseColors,
	}
	active = boss

	Effects.burst(spawnAt, 20, Effects.color(def.EyeColor), 0.7)
	Effects.shockwave(groundUnder(spawnAt), 30, Effects.color(def.EyeColor))
	AuraService.announce(string.format("%s challenged %s, %s!", player.DisplayName, def.Name, def.Title))

	task.spawn(brain, boss)
end

-- Losing aura for dying mid-fight.
function BossService.watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		local boss = active
		if boss and boss.alive and boss.participants[player] then
			AuraService.onDiedInFight(player)
		end
	end)
end

function BossService.start(altars)
	for _, def in ipairs(Config.Bosses) do
		local altar = altars[def.Id]
		altar.prompt.Triggered:Connect(function(player)
			BossService.summon(player, def)
		end)
	end

	RunService.Heartbeat:Connect(function(dt)
		local boss = active
		if boss then
			step(boss, dt)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local boss = active
		if boss then
			boss.participants[player] = nil
		end
	end)
end

return BossService
