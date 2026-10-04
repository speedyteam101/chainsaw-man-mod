--!nonstrict
-- Draws every visual effect the server announces through the Fx remote. All effect parts are
-- local, non-colliding and short-lived.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)
local CameraFx = require(script.Parent.CameraFx)
local PowerVfx = require(script.Parent.PowerVfx)
local VfxKit = require(script.Parent.VfxKit)

local Fx = {}

local player = Players.LocalPlayer
local folder: Folder
local projectiles = {} -- [id] = { part, origin, direction, speed, range, started }
local rng = Random.new()

local function part(props, lifetime: number?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = folder
	if lifetime then
		Debris:AddItem(p, lifetime)
	end
	return p
end

local function fade(p: BasePart, time: number, size: Vector3?)
	local goal = { Transparency = 1 }
	if size then
		goal.Size = size
	end
	Ui.tween(p, time, goal)
	Debris:AddItem(p, time + 0.05)
end

local function ring(position: Vector3, radius: number, color: Color3, time: number, thickness: number?)
	local p = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness or 0.4, 1, 1),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Transparency = 0.2,
	})
	fade(p, time, Vector3.new(thickness or 0.4, radius * 2, radius * 2))
	return p
end

local function sphere(position: Vector3, radius: number, color: Color3, time: number, startTransparency: number?)
	local p = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.5,
		CFrame = CFrame.new(position),
		Color = color,
		Transparency = startTransparency or 0.3,
	})
	fade(p, time, Vector3.one * radius * 2)
	return p
end

local function groundBelow(position: Vector3): Vector3
	local params = RaycastParams.new()
	local map = workspace:FindFirstChild("Map")
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map, workspace.Terrain }
	params.IgnoreWater = true
	local hit = map and workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
	return hit and hit.Position or position
end

local function floatingText(position: Vector3, text: string, color: Color3, size: number, rise: number?)
	local attachment = part({ Size = Vector3.one * 0.1, Transparency = 1, CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))) })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.Adornee = attachment
	gui.Parent = attachment
	local label = Ui.label(text, {
		Size = UDim2.fromScale(1, 1),
		Font = Ui.Theme.Bold,
		TextSize = size,
		TextColor3 = color,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = gui,
	})
	Ui.tween(gui, 0.9, { StudsOffset = Vector3.new(0, rise or 3, 0) })
	task.delay(0.45, function()
		Ui.tween(label, 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(attachment, 1)
end

local function rootOf(character: Instance?)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function afterimage(character: Model, color: Color3)
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.Transparency < 1 then
			local ghost = part({ Size = child.Size, CFrame = child.CFrame, Color = color, Transparency = 0.5 })
			fade(ghost, 0.4)
		end
	end
end

local function aura(character: Model, color: Color3, duration: number)
	local root = rootOf(character)
	if not root then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Rate = 40
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = root
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 2
	light.Parent = root
	task.delay(duration, function()
		emitter.Enabled = false
		light:Destroy()
		Debris:AddItem(emitter, 1.2)
	end)
end

local function lightning(from: Vector3, to: Vector3, color: Color3)
	local points = { from }
	local segments = 6
	for i = 1, segments - 1 do
		local p = from:Lerp(to, i / segments) + rng:NextUnitVector() * 1.2
		table.insert(points, p)
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = part({ Size = Vector3.new(0.25, 0.25, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color, Transparency = 0 })
		fade(seg, 0.25)
	end
end

-- Handlers ---------------------------------------------------------------------------------

local handlers = {}

function handlers.Hit(d)
	local crit = d.crit
	floatingText(d.position, tostring(d.amount), d.color or Color3.new(1, 1, 1), crit and 30 or 22)
	local spark = sphere(d.position, crit and 2.2 or 1.4, d.color or Color3.new(1, 1, 1), 0.18, 0.1)
	spark.Material = Enum.Material.Neon
	Audio.Play("Hit", 0.35, rng:NextNumber(0.9, 1.15), d.position)
	-- Shadows bleed black.
	if (d.position - workspace.CurrentCamera.CFrame.Position).Magnitude < 120 then
		VfxKit.Ichor(d.position, d.amount or 10)
		VfxKit.Sparks(d.position, d.color or Color3.new(1, 1, 1), crit and 14 or 6, crit and 30 or 18)
	end
end

local REACTION_COLORS = {
	SHATTER = Color3.fromRGB(190, 240, 255),
	OVERLOAD = Color3.fromRGB(255, 190, 80),
	CRUSH = Color3.fromRGB(255, 120, 90),
}

function handlers.Reaction(d)
	local color = REACTION_COLORS[d.kind] or Color3.new(1, 1, 1)
	local position = d.position
	floatingText(position + Vector3.new(0, 4, 0), d.kind .. "!", color, 36, 6)
	if d.kind == "SHATTER" then
		VfxKit.Flash(position, color, 26, 6, 0.4)
		VfxKit.Rubble(position + Vector3.new(0, 2, 0), 12, 28, Enum.Material.Ice, Color3.fromRGB(210, 240, 255))
		VfxKit.Sparks(position, color, 30, 40)
		VfxKit.Smoke(position, 2.5, Color3.fromRGB(220, 235, 245), 8, -0.5, 1.6)
		ring(position, 7, color, 0.35, 0.3)
	elseif d.kind == "OVERLOAD" then
		VfxKit.Flash(position, color, 40, 10, 0.7, true)
		VfxKit.Sparks(position, color, 40, 60)
		VfxKit.Smoke(position, 3.5, Color3.fromRGB(40, 30, 28), 14, 4)
		VfxKit.Embers(position, color, 20, 6)
		local ground = VfxKit.Ground(position, 12)
		if ground then
			VfxKit.DustRing(ground.position, 14, ground.color)
			VfxKit.Scorch(ground.position, 6, Color3.fromRGB(255, 120, 30))
		end
		sphere(position, 9, color, 0.35, 0.2)
	else
		local ground = VfxKit.Ground(position, 12)
		if ground then
			VfxKit.Rubble(ground.position, 10, 30)
			VfxKit.DustRing(ground.position, 10, ground.color)
			VfxKit.Cracks(ground.position, 6)
		end
		VfxKit.Flash(position, color, 20, 4, 0.3)
	end
	CameraFx.ShakeAt(position, d.kind == "OVERLOAD" and 0.7 or 0.45)
end

-- Awakening's Ultimate: everything gets pulled in, then it detonates.
function handlers.Ultimate(d)
	local position = d.position
	local color = d.color or Color3.new(1, 1, 1)
	VfxKit.Implode(position, d.radius * 0.6, color)
	local pillar = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(300, 1, 1), CFrame = CFrame.new(position + Vector3.new(0, 140, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Transparency = 0.2 })
	Ui.tween(pillar, 0.45, { Size = Vector3.new(300, 7, 7) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.45, function()
		fade(pillar, 0.6, Vector3.new(300, 0.3, 0.3))
		sphere(position, d.radius * 2, color, 0.7, 0)
		for i = 0, 2 do
			task.delay(i * 0.09, function()
				ring(position - Vector3.new(0, 2.5, 0), d.radius * (1 + i * 0.35), color, 0.7, 1.2)
			end)
		end
		VfxKit.Flash(position, color, 60, 12, 1.4, true)
		VfxKit.Sparks(position, color, 60, 80)
		VfxKit.Smoke(position, 6, Color3.fromRGB(28, 24, 30), 20, 3, 3.5)
		local ground = VfxKit.Ground(position, 14)
		if ground then
			VfxKit.DustRing(ground.position, d.radius * 1.4, ground.color)
			VfxKit.Rubble(ground.position, 22, 55)
			VfxKit.Cracks(ground.position, d.radius * 0.7, color)
			VfxKit.Scorch(ground.position, d.radius * 0.35, color)
		end
		CameraFx.ShakeAt(position, 1.4)
		if (position - workspace.CurrentCamera.CFrame.Position).Magnitude < d.radius * 2 then
			CameraFx.Flash(color, 0.5)
		end
	end)
end

-- The basic attack: a four-hit boxing combo. Jab (left), cross (right), hook (left), and a
-- rising uppercut finisher (right). Each strike snaps out, twists the torso into it (seen by
-- other players), leaves a short streak behind the fist, and settles back into a guard.
local GUARD = { right = 0.95, left = 0.95, spread = -0.38, time = 0.1, hold = 0.35 }
local COMBO = {
	{ -- jab
		{ left = 1.72, right = 0.95, leftSpread = -0.08, rightSpread = -0.38, time = 0.05, hold = 0.05, twist = 0.28, style = Enum.EasingStyle.Back },
		GUARD,
	},
	{ -- cross
		{ right = 1.75, left = 0.9, rightSpread = -0.12, leftSpread = -0.38, time = 0.05, hold = 0.05, twist = -0.42, lean = 0.06, style = Enum.EasingStyle.Back },
		GUARD,
	},
	{ -- hook: wind out, then sweep across
		{ left = 1.35, right = 0.95, leftSpread = 0.65, rightSpread = -0.38, time = 0.05, twist = -0.15 },
		{ left = 1.5, right = 0.95, leftSpread = -0.75, rightSpread = -0.38, time = 0.06, hold = 0.05, twist = 0.62 },
		GUARD,
	},
	{ -- uppercut: dip, then drive up
		{ right = -0.35, left = 1.0, rightSpread = 0.1, leftSpread = -0.4, time = 0.07, lean = 0.22, twist = -0.25 },
		{ right = 2.85, left = 0.6, rightSpread = -0.1, leftSpread = -0.3, time = 0.07, hold = 0.14, lean = -0.12, twist = 0.3, style = Enum.EasingStyle.Back },
	},
}

-- A short streak behind the striking fist.
local function fistTrail(character: Model, right: boolean, color: Color3)
	local arm = character:FindFirstChild(right and "Right Arm" or "Left Arm")
	if not arm or not arm:IsA("BasePart") then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, -1, 0)
	a0.Parent = arm
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.35, 0)
	a1.Parent = arm
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.14
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Parent = arm
	task.delay(0.32, function()
		trail.Enabled = false
		task.delay(0.2, function()
			trail:Destroy()
			a0:Destroy()
			a1:Destroy()
		end)
	end)
end

function handlers.Swing(d)
	local character = d.character
	local root = rootOf(character)
	if not root then
		return
	end
	local combo = math.clamp(d.combo or 1, 1, 4)
	local color = d.color or Color3.new(1, 1, 1)
	local right = combo % 2 == 0
	PowerVfx.PoseArms(character, COMBO[combo])
	task.delay(0.02, fistTrail, character, right, color)
	-- The strike's arc in the air.
	local reach = root.CFrame * CFrame.new(right and 0.6 or -0.6, 0.5, -3.2)
	if combo == 3 then
		local arc = part({ Size = Vector3.new(6, 0.12, 1.4), CFrame = root.CFrame * CFrame.new(0, 0.6, -3) * CFrame.Angles(0, 0, math.rad(8)), Color = color, Transparency = 0.35 })
		fade(arc, 0.18, Vector3.new(8, 0.04, 2.2))
	elseif combo == 4 then
		local arc = part({ Size = Vector3.new(0.12, 6, 1.4), CFrame = root.CFrame * CFrame.new(0.5, 1, -3), Color = color, Transparency = 0.3 })
		fade(arc, 0.2, Vector3.new(0.04, 9, 2.4))
		ring(root.Position + root.CFrame.LookVector * 4, 4.5, color, 0.25)
		VfxKit.DustRing(root.Position - Vector3.new(0, 2.6, 0) + root.CFrame.LookVector * 2, 6, Color3.fromRGB(130, 120, 110))
	else
		local streak = part({ Size = Vector3.new(0.5, 0.5, 3.2), CFrame = reach, Color = color, Transparency = 0.45 })
		fade(streak, 0.12, Vector3.new(0.1, 0.1, 5))
	end
	if character == player.Character then
		CameraFx.Kick(combo == 4 and 0.4 or (combo == 3 and 0.2 or 0.12))
	end
end

-- Guard up while blocking (watched for every character, so everyone sees it).
local function watchBlocking(character: Model)
	character:GetAttributeChangedSignal("Blocking"):Connect(function()
		if character:GetAttribute("Blocking") then
			PowerVfx.PoseArms(character, { { right = 1.45, left = 1.45, spread = -0.6, time = 0.08, hold = 600, lean = 0.05 } })
		else
			PowerVfx.PoseArms(character, { { right = 0.9, left = 0.9, spread = -0.3, time = 0.08 } })
		end
	end)
end
Fx.WatchBlocking = watchBlocking

function handlers.Evade(d)
	local character = d.character
	local root = rootOf(character)
	if not root then
		return
	end
	afterimage(character, Color3.fromRGB(150, 220, 255))
	floatingText(root.Position + Vector3.new(0, 3, 0), "EVADE", Color3.fromRGB(150, 220, 255), 24, 4)
	if character == player.Character then
		CameraFx.SlowFlash(Color3.fromRGB(150, 220, 255))
	end
end

function handlers.Parry(d)
	local root = rootOf(d.character)
	if not root then
		return
	end
	ring(root.Position + root.CFrame.LookVector * 2, 6, Color3.new(1, 1, 1), 0.3, 0.6)
	sphere(root.Position + root.CFrame.LookVector * 2.5, 2.5, Color3.fromRGB(255, 240, 200), 0.2, 0)
	floatingText(root.Position + Vector3.new(0, 3, 0), "PARRY", Color3.fromRGB(255, 230, 140), 28, 4)
	if d.character == player.Character then
		CameraFx.Kick(0.4)
	end
end

function handlers.PlayerHit(d)
	local root = rootOf(d.character)
	if not root then
		return
	end
	floatingText(root.Position + Vector3.new(0, 2.5, 0), (d.blocked and "BLOCKED " or "-") .. tostring(d.amount), d.blocked and Color3.fromRGB(170, 170, 190) or Color3.fromRGB(255, 70, 70), 20)
	if d.character == player.Character then
		CameraFx.Hurt(d.blocked and 0.25 or 0.6)
	end
end

function handlers.Dodge(d)
	if d.character then
		afterimage(d.character, Color3.fromRGB(120, 120, 160))
		PowerVfx.PoseArms(d.character, { { right = -0.5, left = -0.5, spread = 0.35, time = 0.05, hold = 0.22, lean = 0.3 } })
	end
end

function handlers.Bolt(d)
	lightning(d.from, d.to, d.color)
end

function handlers.Projectile(d)
	local enemy = d.team == "enemy"
	local p = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * d.radius * 2,
		CFrame = CFrame.new(d.origin),
		Color = enemy and Color3.fromRGB(10, 0, 18) or d.color,
		Transparency = enemy and 0 or 0.1,
	})
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, d.radius * 0.6, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -d.radius * 0.6, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.25
	trail.Color = ColorSequence.new(enemy and Color3.fromRGB(120, 40, 200) or d.color)
	trail.LightEmission = enemy and 0.3 or 1
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = p
	if enemy then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(150, 60, 255)
		light.Range = 8
		light.Brightness = 2
		light.Parent = p
	end
	projectiles[d.id] = { part = p, origin = d.origin, direction = d.direction, speed = d.speed, range = d.range, started = os.clock() }
end

function handlers.ProjectileEnd(d)
	local info = projectiles[d.id]
	if info then
		projectiles[d.id] = nil
		info.part:Destroy()
	end
	sphere(d.position, (d.radius or 1) * 2, d.color or Color3.new(1, 1, 1), 0.2, 0.2)
end

function handlers.Nova(d)
	local ground = groundBelow(d.position)
	ring(ground + Vector3.new(0, 0.3, 0), d.radius, d.color, 0.4, 0.8)
	sphere(d.position, d.radius, d.color, 0.35, 0.55)
	Audio.Play("Power", 0.5, 1, d.position)
end

function handlers.DashTrail(d)
	local length = (d.to - d.from).Magnitude
	if length < 1 then
		return
	end
	local slab = part({ Size = Vector3.new(d.width * 0.6, 3, length), CFrame = CFrame.lookAt((d.from + d.to) / 2, d.to), Color = d.color, Transparency = 0.35 })
	fade(slab, 0.35, Vector3.new(0.1, 0.5, length))
end

function handlers.Beam(d)
	local length = (d.to - d.from).Magnitude
	local beam = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, d.width, d.width),
		CFrame = CFrame.lookAt((d.from + d.to) / 2, d.to) * CFrame.Angles(0, math.pi / 2, 0),
		Color = d.color,
		Transparency = 0.05,
	})
	fade(beam, 0.4, Vector3.new(length, 0.2, 0.2))
	Audio.Play("Power", 0.5, 1.2, d.from)
end

function handlers.StrikeWarn(d)
	local ground = groundBelow(d.position)
	local disc = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, d.radius * 2, d.radius * 2),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = d.color,
		Transparency = 0.7,
	})
	Debris:AddItem(disc, d.delay)
	local orb = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * d.radius * 0.5, CFrame = CFrame.new(ground + Vector3.new(0, 80, 0)), Color = d.color, Transparency = 0 })
	Ui.tween(orb, d.delay, { CFrame = CFrame.new(ground) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(orb, d.delay)
end

function handlers.Strike(d)
	local ground = groundBelow(d.position)
	sphere(ground, d.radius, d.color, 0.6, 0.1)
	ring(ground + Vector3.new(0, 0.3, 0), d.radius * 1.4, d.color, 0.6, 1)
	local pillar = part({ Size = Vector3.new(d.radius * 0.6, 120, d.radius * 0.6), CFrame = CFrame.new(ground + Vector3.new(0, 60, 0)), Color = d.color, Transparency = 0.2 })
	fade(pillar, 0.5, Vector3.new(0.5, 120, 0.5))
	CameraFx.ShakeAt(ground, 0.8)
	Audio.Play("Power", 0.9, 0.8, ground)
end

function handlers.Zone(d)
	local ground = groundBelow(d.position)
	local disc = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, d.radius * 2, d.radius * 2),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = d.color,
		Transparency = 0.6,
	})
	local swirl = part({ Size = Vector3.new(d.radius * 1.6, 0.2, 0.6), CFrame = CFrame.new(ground + Vector3.new(0, 1.5, 0)), Color = d.color, Transparency = 0.3 })
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		if elapsed > d.duration then
			connection:Disconnect()
			fade(disc, 0.4)
			fade(swirl, 0.4)
			return
		end
		local center = ground
		local followRoot = d.follow and rootOf(d.follow)
		if followRoot then
			center = groundBelow(followRoot.Position)
			disc.CFrame = CFrame.new(center + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		end
		swirl.CFrame = CFrame.new(center + Vector3.new(0, 1.5 + math.sin(elapsed * 3), 0)) * CFrame.Angles(0, elapsed * 6, 0)
	end)
end

function handlers.Buff(d)
	if d.character then
		aura(d.character, d.color, d.duration or 4)
		local root = rootOf(d.character)
		if root then
			ring(root.Position - Vector3.new(0, 2.5, 0), 6, d.color, 0.5)
		end
	end
end

function handlers.Cast(d)
	local root = rootOf(d.character)
	if root then
		sphere(root.Position + root.CFrame.LookVector * 1.5 + Vector3.new(0, 0.5, 0), 1.6, d.color, 0.2, 0.2)
	end
end

function handlers.Awaken(d)
	local root = rootOf(d.character)
	if root then
		sphere(root.Position, 22, d.color, 0.8, 0)
		ring(root.Position - Vector3.new(0, 2.5, 0), 30, d.color, 1, 1)
	end
	if d.character then
		aura(d.character, d.color, d.duration)
	end
	if d.character == player.Character then
		CameraFx.Flash(d.color, 0.6)
		CameraFx.Kick(1)
	end
end

function handlers.Ascend(d)
	local root = rootOf(d.character)
	if not root then
		return
	end
	local pillar = part({ Size = Vector3.new(6, 200, 6), CFrame = CFrame.new(root.Position + Vector3.new(0, 97, 0)), Color = d.color, Transparency = 0.1 })
	fade(pillar, 1.5, Vector3.new(0.5, 200, 0.5))
	ring(root.Position - Vector3.new(0, 2.5, 0), 26, d.color, 1.2, 1)
	if d.character == player.Character then
		Audio.Play("Ascend", 1)
		CameraFx.Flash(d.color, 0.5)
	end
end

function handlers.AwakenBurst(d)
	sphere(d.position, 45, d.color, 1.2, 0)
	ring(d.position - Vector3.new(0, 2.5, 0), 60, d.color, 1.4, 2)
end

function handlers.Claw(d)
	local root = d.model and d.model.PrimaryPart
	if not root then
		return
	end
	local scale = d.model:GetAttribute("RigScale") or 1
	for i = -1, 1 do
		local slash = part({
			Size = Vector3.new(0.2, 3.2 * scale, 0.2),
			CFrame = root.CFrame * CFrame.new(i * 0.7 * scale, 0.5 * scale, -2.5 * scale) * CFrame.Angles(0, 0, math.rad(35)),
			Color = Color3.fromRGB(255, 40, 40),
			Transparency = 0.1,
		})
		fade(slash, 0.2)
	end
end

function handlers.Shockwave(d)
	local ground = groundBelow(d.position)
	ring(ground + Vector3.new(0, 0.3, 0), d.radius, Color3.fromRGB(20, 0, 30), 0.45, 1.2)
	local dust = part({ Shape = Enum.PartType.Ball, Size = Vector3.one, CFrame = CFrame.new(ground), Color = Color3.new(0, 0, 0), Material = Enum.Material.SmoothPlastic, Transparency = 0.3 })
	fade(dust, 0.5, Vector3.one * d.radius * 1.6)
	CameraFx.ShakeAt(ground, 0.6)
end

function handlers.Eruption(d)
	local ground = groundBelow(d.position)
	local pillar = part({ Size = Vector3.new(d.radius * 1.4, 1, d.radius * 1.4), CFrame = CFrame.new(ground), Color = Color3.new(0, 0, 0), Transparency = 0 })
	Ui.tween(pillar, 0.15, { Size = Vector3.new(d.radius * 1.4, 26, d.radius * 1.4), CFrame = CFrame.new(ground + Vector3.new(0, 13, 0)) })
	task.delay(0.2, function()
		fade(pillar, 0.4, Vector3.new(0.5, 30, 0.5))
	end)
	ring(ground + Vector3.new(0, 0.3, 0), d.radius, d.color or Color3.fromRGB(255, 40, 40), 0.4, 0.6)
	CameraFx.ShakeAt(ground, 0.4)
end

function handlers.Blink(d)
	for _, position in { d.from, d.to } do
		sphere(position, 4, Color3.new(0, 0, 0), 0.5, 0.2).Material = Enum.Material.SmoothPlastic
	end
end

local function dissolve(model: Model, color: Color3?, time: number)
	if not model or not model.Parent then
		return
	end
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child.Transparency < 1 then
			Ui.tween(child, time, { Transparency = 1, Size = child.Size * 0.4 })
		elseif child:IsA("ParticleEmitter") then
			child:Emit(20)
			child.Enabled = false
		elseif child:IsA("Smoke") then
			child.Enabled = false
		end
	end
	local root = model.PrimaryPart
	if root then
		sphere(root.Position, 3 * (tonumber(model:GetAttribute("RigScale")) or 1), color or Color3.new(0, 0, 0), time, 0.2).Material = color and Enum.Material.Neon or Enum.Material.SmoothPlastic
	end
end

-- A house coming down: a rolling wall of dust, splinters and rubble.
function handlers.Demolish(d)
	local position = d.position
	local size = d.size or Vector3.new(20, 12, 20)
	local ground = VfxKit.Ground(position, size.Y + 10)
	local base = ground and ground.position or position - Vector3.new(0, size.Y / 2, 0)
	local reach = math.max(size.X, size.Z)
	VfxKit.Smoke(base + Vector3.new(0, 3, 0), reach * 0.35, Color3.fromRGB(140, 128, 116), 26, 2, 4)
	VfxKit.DustRing(base, reach * 1.2, Color3.fromRGB(150, 138, 124))
	VfxKit.Rubble(base + Vector3.new(0, 2, 0), 18, 26, Enum.Material.WoodPlanks, Color3.fromRGB(110, 84, 60))
	VfxKit.Rubble(base + Vector3.new(0, 2, 0), 10, 20, Enum.Material.Concrete, Color3.fromRGB(120, 116, 110))
	task.delay(0.6, function()
		VfxKit.Smoke(base + Vector3.new(0, 1, 0), reach * 0.45, Color3.fromRGB(120, 110, 100), 18, 1, 5)
	end)
	CameraFx.ShakeAt(base, 0.8)
	Audio.Play("Build", 0.8, 0.6, base)
end

function handlers.Dissolve(d)
	local root = d.model and d.model.PrimaryPart
	if root then
		VfxKit.Disintegrate(root.Position, (tonumber(d.model:GetAttribute("RigScale")) or 1) * (d.boss and 2 or 1))
	end
	dissolve(d.model, nil, d.boss and 2 or 0.8)
end

function handlers.Banish(d)
	local root = d.model and d.model.PrimaryPart
	if root then
		sphere(root.Position, 4, Color3.new(1, 1, 1), 0.35, 0)
	end
	dissolve(d.model, Color3.new(1, 1, 1), 0.5)
end

function handlers.Hearts(d)
	local head = d.model and d.model:FindFirstChild("Head")
	if not head then
		return
	end
	for i = 1, d.small and 1 or 4 do
		task.delay(i * 0.12, function()
			floatingText(head.Position + Vector3.new(0, 1, 0), "\u{2665}", Color3.fromRGB(255, 120, 160), d.small and 18 or 26, 4)
		end)
	end
	if not d.small then
		sphere(head.Position, 2, Color3.fromRGB(255, 170, 200), 0.4, 0.4)
		Audio.Play("Quack", 0.7, 1.4, head.Position)
	end
end

function handlers.Gather(d)
	for _ = 1, 4 do
		local chip = part({
			Size = Vector3.one * rng:NextNumber(0.3, 0.6),
			CFrame = CFrame.new(d.position + rng:NextUnitVector() * 1.5),
			Color = d.color,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0,
		})
		Ui.tween(chip, 0.4, { CFrame = chip.CFrame + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(1, 3), rng:NextNumber(-2, 2)) })
		fade(chip, 0.45)
	end
	Audio.Play("Gather", 0.5, rng:NextNumber(0.9, 1.15), d.position)
	CameraFx.ShakeAt(d.position, 0.08)
end

function handlers.GatherBreak(d)
	sphere(d.position, 4, d.color, 0.35, 0.3)
	ring(d.position - Vector3.new(0, 2, 0), 5, d.color, 0.4, 0.4)
end

function handlers.Deposit(d)
	ring(d.position, 3, Color3.fromRGB(110, 200, 255), 0.3, 0.3)
end

function handlers.Built(d)
	local size = d.size or Vector3.new(4, 4, 4)
	local box = part({ Size = size + Vector3.one * 0.4, CFrame = CFrame.new(d.position), Color = Color3.fromRGB(140, 220, 255), Transparency = 0.2 })
	fade(box, 0.6, size + Vector3.one * 2)
	Audio.Play("Build", 0.8, 1, d.position)
end

function handlers.BarrierGrow(d)
	local dome = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = CFrame.new(d.position), Color = Color3.fromRGB(140, 210, 255), Transparency = 0.3 })
	Ui.tween(dome, 0.9, { Size = Vector3.one * d.radius * 2, Transparency = 1 })
	Debris:AddItem(dome, 1)
	ring(d.position + Vector3.new(0, 0.3, 0), d.radius, Color3.fromRGB(140, 210, 255), 1, 1)
end

function handlers.Freed(d)
	sphere(d.position, 8, Color3.fromRGB(255, 245, 220), 0.6, 0)
	ring(d.position - Vector3.new(0, 2.5, 0), 12, Color3.fromRGB(200, 170, 255), 0.8, 0.8)
end

function handlers.Crafted(d)
	local root = rootOf(d.character)
	if root then
		ring(root.Position - Vector3.new(0, 2.5, 0), 4, Color3.fromRGB(255, 220, 140), 0.4, 0.3)
		if d.character == player.Character then
			Audio.Play("Craft", 0.8)
		end
	end
end

function Fx.Start()
	folder = Instance.new("Folder")
	folder.Name = "LocalFx"
	folder.Parent = workspace

	PowerVfx.SetFolder(folder)
	VfxKit.Start()
	local function watchPlayer(other: Player)
		if other.Character then
			watchBlocking(other.Character)
		end
		other.CharacterAdded:Connect(watchBlocking)
	end
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Remotes.Fx.OnClientEvent:Connect(function(kind, data)
		local handler = handlers[kind]
		if handler then
			local ok, err = pcall(handler, data)
			if not ok then
				warn("[Shadowfall] fx error", kind, err)
			end
		end
		-- Power styling on top of the basic effect.
		local extra = PowerVfx[kind]
		if extra then
			local ok, err = pcall(function()
				if kind == "Projectile" then
					local info = projectiles[data.id]
					if info then
						extra(data, info.part)
					end
				else
					extra(data)
				end
			end)
			if not ok then
				warn("[Shadowfall] power fx error", kind, err)
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for id, info in projectiles do
			local travelled = (now - info.started) * info.speed
			if travelled > info.range + 5 then
				info.part:Destroy()
				projectiles[id] = nil
			else
				info.part.CFrame = CFrame.new(info.origin + info.direction * travelled)
			end
		end
	end)
end

return Fx
