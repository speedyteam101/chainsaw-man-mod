--!nonstrict
-- Element-specific animation and effects for powers. Fx draws the basic shape of every move;
-- this module adds the casting animation (arms thrusting, raising, slamming) and each power's
-- own look: embers and flames, ice shards, rock debris, lightning, bones and souls, clock rings,
-- stars, blood, poison clouds, blades, void implosions and speed afterimages.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ShadowRig = require(ReplicatedStorage.Shared.ShadowRig)

local PowerVfx = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local rng = Random.new()
local folder: Instance = workspace

-- Which family of effects each power style uses, and its secondary colour.
local STYLES = {
	fire = { family = "fire", accent = Color3.fromRGB(255, 70, 20) },
	phoenix = { family = "fire", accent = Color3.fromRGB(255, 220, 90), feathers = true },
	dawn = { family = "light", accent = Color3.fromRGB(255, 200, 120) },
	wind = { family = "wind", accent = Color3.fromRGB(235, 255, 245) },
	ice = { family = "ice", accent = Color3.fromRGB(225, 250, 255) },
	stone = { family = "stone", accent = Color3.fromRGB(110, 90, 70) },
	volt = { family = "electric", accent = Color3.new(1, 1, 1) },
	storm = { family = "electric", accent = Color3.fromRGB(220, 240, 255) },
	speed = { family = "electric", accent = Color3.new(1, 1, 1), afterimages = true },
	light = { family = "light", accent = Color3.new(1, 1, 1) },
	celestial = { family = "light", accent = Color3.fromRGB(230, 240, 255), stars = true },
	gravity = { family = "dark", accent = Color3.fromRGB(60, 20, 120) },
	eclipse = { family = "dark", accent = Color3.fromRGB(30, 0, 10) },
	void = { family = "dark", accent = Color3.new(0, 0, 0) },
	venom = { family = "toxic", accent = Color3.fromRGB(60, 140, 20) },
	blade = { family = "blade", accent = Color3.new(1, 1, 1) },
	phantom = { family = "blade", accent = Color3.fromRGB(230, 220, 255), afterimages = true },
	blood = { family = "blood", accent = Color3.fromRGB(90, 0, 10) },
	necro = { family = "necro", accent = Color3.fromRGB(20, 70, 30) },
	chrono = { family = "chrono", accent = Color3.new(1, 1, 1) },
}

local function styleOf(d)
	return STYLES[d.style or ""] or { family = "plain", accent = Color3.new(1, 1, 1) }
end

-- Helpers ------------------------------------------------------------------------------------

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
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = folder
	if lifetime then
		Debris:AddItem(p, lifetime)
	end
	return p
end

local function tween(instance: Instance, time: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function fadeOut(p: BasePart, time: number, goal)
	goal = goal or {}
	goal.Transparency = 1
	tween(p, time, goal)
	Debris:AddItem(p, time + 0.05)
end

-- A one-shot burst of particles at a point.
local function burst(position: Vector3, color: Color3, count: number, speed: number, size: number, texture: string?, lifetime: number?, gravity: number?)
	local holder = part({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(position) }, (lifetime or 0.8) + 0.6)
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture or SPARK
	e.Color = ColorSequence.new(color)
	e.LightEmission = texture == SMOKE and 0 or 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0, 1)
	e.Lifetime = NumberRange.new((lifetime or 0.8) * 0.6, lifetime or 0.8)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, gravity or 0, 0)
	e.Rate = 0
	e.Parent = holder
	e:Emit(count)
	return holder
end

local function flashLight(position: Vector3, color: Color3, range: number, time: number)
	local holder = part({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(position) }, time + 0.1)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 4
	light.Parent = holder
	tween(light, time, { Brightness = 0 })
end

local function bolt(from: Vector3, to: Vector3, color: Color3, thickness: number?)
	local points = { from }
	local segments = math.clamp(math.floor((to - from).Magnitude / 4), 3, 10)
	for i = 1, segments - 1 do
		table.insert(points, from:Lerp(to, i / segments) + rng:NextUnitVector() * 1.3)
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = part({ Size = Vector3.new(thickness or 0.3, thickness or 0.3, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color })
		fadeOut(seg, 0.22)
	end
end

local function ring(position: Vector3, radius: number, color: Color3, time: number, thickness: number?, tilt: CFrame?)
	local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(thickness or 0.3, 1, 1), CFrame = CFrame.new(position) * (tilt or CFrame.Angles(0, 0, math.pi / 2)), Color = color, Transparency = 0.1 })
	fadeOut(p, time, { Size = Vector3.new(thickness or 0.3, radius * 2, radius * 2) })
end

local function star(position: Vector3, size: number, color: Color3, time: number)
	for i = 0, 3 do
		local ray = part({ Size = Vector3.new(size * 0.12, size, size * 0.12), CFrame = CFrame.new(position) * CFrame.Angles(0, 0, i * math.pi / 4), Color = color })
		fadeOut(ray, time, { Size = Vector3.new(0.05, size * 1.8, 0.05) })
	end
end

local function chunks(position: Vector3, color: Color3, material: Enum.Material, count: number, power: number)
	for _ = 1, count do
		local s = rng:NextNumber(0.6, 1.6)
		local chunk = part({ Size = Vector3.new(s, s, s), CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Color = color, Material = material })
		local direction = (rng:NextUnitVector() * Vector3.new(1, 0, 1) + Vector3.new(0, rng:NextNumber(0.6, 1.4), 0)).Unit
		local target = position + direction * power * rng:NextNumber(0.6, 1)
		tween(chunk, 0.45, { CFrame = CFrame.new(target) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0) })
		task.delay(0.45, function()
			fadeOut(chunk, 0.5, { CFrame = CFrame.new(target - Vector3.new(0, power * 0.6, 0)) })
		end)
	end
end

local function souls(position: Vector3, color: Color3, count: number)
	for _ = 1, count do
		local orb = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(0.6, 1.2), CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))), Color = color, Transparency = 0.2 })
		tween(orb, 1.2, { CFrame = orb.CFrame + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(6, 10), rng:NextNumber(-2, 2)), Transparency = 1, Size = Vector3.one * 0.1 }, Enum.EasingStyle.Sine)
		Debris:AddItem(orb, 1.3)
	end
end

local function clockRing(position: Vector3, radius: number, color: Color3, time: number, reverse: boolean?)
	local holder = part({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(position) }, time + 0.1)
	local ticks = {}
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local tick = part({ Size = Vector3.new(0.25, 0.25, i % 3 == 0 and 2 or 1), CFrame = CFrame.new(position + Vector3.new(math.cos(a), 0, math.sin(a)) * radius) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = color })
		table.insert(ticks, { part = tick, angle = a })
		Debris:AddItem(tick, time + 0.1)
	end
	local hand = part({ Size = Vector3.new(0.3, 0.3, radius), CFrame = CFrame.new(position), Color = color }, time + 0.1)
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > time or not holder.Parent then
			connection:Disconnect()
			return
		end
		local spin = (reverse and -1 or 1) * t * 4
		hand.CFrame = CFrame.new(position) * CFrame.Angles(0, spin, 0) * CFrame.new(0, 0, -radius / 2)
		local alpha = t / time
		for _, tick in ticks do
			tick.part.Transparency = alpha
		end
		hand.Transparency = alpha
	end)
end

local function afterimage(character: Model, color: Color3, time: number?)
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.Transparency < 1 then
			local ghost = part({ Size = child.Size, CFrame = child.CFrame, Color = color, Transparency = 0.45 })
			fadeOut(ghost, time or 0.45)
		end
	end
end

-- Casting animation ----------------------------------------------------------------------------

local restC0 = setmetatable({}, { __mode = "k" }) -- [Motor6D] = C0 at rest
local poseToken = setmetatable({}, { __mode = "k" }) -- [Model] = number

local function joints(character: Model)
	local torso = character:FindFirstChild("Torso")
	if not torso then
		return nil
	end
	local right = torso:FindFirstChild("Right Shoulder")
	local left = torso:FindFirstChild("Left Shoulder")
	if not (right and right:IsA("Motor6D") and left and left:IsA("Motor6D")) then
		return nil
	end
	for _, m in { right, left } do
		if not restC0[m] then
			restC0[m] = ShadowRig.R6RestC0[m.Name] or m.C0
		end
	end
	return right, left
end

-- angles: forward swing for each arm, plus sideways spread
local function poseArms(character: Model, keyframes)
	local right, left = joints(character)
	if not right then
		return
	end
	poseToken[character] = (poseToken[character] or 0) + 1
	local token = poseToken[character]
	task.spawn(function()
		for _, frame in keyframes do
			if poseToken[character] ~= token then
				return
			end
			local spread = frame.spread or 0
			tween(right, frame.time, { C0 = restC0[right] * CFrame.Angles(-spread, 0, frame.right) }, Enum.EasingStyle.Quad)
			tween(left, frame.time, { C0 = restC0[left] * CFrame.Angles(-spread, 0, -frame.left) }, Enum.EasingStyle.Quad)
			task.wait(frame.time + (frame.hold or 0))
		end
		if poseToken[character] == token then
			tween(right, 0.2, { C0 = restC0[right] })
			tween(left, 0.2, { C0 = restC0[left] })
		end
	end)
end

local POSES = {
	projectile = { { right = 1.7, left = 0, time = 0.07, hold = 0.18 } },
	beam = { { right = 1.6, left = 1.6, time = 0.1, hold = 0.45 } },
	nova = { { right = 3, left = 3, time = 0.1, spread = 0.3 }, { right = 0.4, left = 0.4, time = 0.08, spread = 0.6, hold = 0.15 } },
	strike = { { right = 3.1, left = 0, time = 0.12, hold = 0.2 }, { right = 1.2, left = 0, time = 0.08, hold = 0.1 } },
	zone = { { right = 2.7, left = 2.7, time = 0.15, spread = 0.4, hold = 0.45 } },
	buff = { { right = 0.3, left = 0.3, time = 0.15, spread = 1.4, hold = 0.4 } },
	summon = { { right = 3, left = 3, time = 0.15, hold = 0.15 }, { right = 0.6, left = 0.6, time = 0.08, hold = 0.25 } },
	dash = { { right = -0.9, left = -0.9, time = 0.06, hold = 0.25 } },
	blinkchain = { { right = -1, left = 1.4, time = 0.05, hold = 0.3 } },
}

local function handPosition(character: Model): Vector3?
	local arm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
	return arm and (arm :: BasePart).CFrame * Vector3.new(0, -1, 0) or nil
end

function PowerVfx.Cast(d)
	local character = d.character
	if not character then
		return
	end
	local s = styleOf(d)
	poseArms(character, POSES[d.kind] or POSES.projectile)
	-- A charge-up glow in the hand.
	task.delay(0.05, function()
		local hand = handPosition(character)
		if hand then
			local orb = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, CFrame = CFrame.new(hand), Color = d.color })
			fadeOut(orb, 0.35, { Size = Vector3.one * 2.4 })
			burst(hand, s.accent, 10, 8, 0.5)
			flashLight(hand, d.color, 12, 0.35)
		end
	end)
	if s.afterimages then
		afterimage(character, d.color, 0.5)
	end
end

-- Projectiles: decorate the flying part --------------------------------------------------------

function PowerVfx.Projectile(d, p: Part)
	if d.team ~= "player" then
		return
	end
	local s = styleOf(d)
	local e = Instance.new("ParticleEmitter")
	e.Texture = (s.family == "toxic" or s.family == "dark" or s.family == "necro") and SMOKE or SPARK
	e.Color = ColorSequence.new(d.color, s.accent)
	e.LightEmission = s.family == "dark" and 0 or 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, d.radius * 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Lifetime = NumberRange.new(0.25, 0.5)
	e.Rate = 60
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Parent = p
	local light = Instance.new("PointLight")
	light.Color = d.color
	light.Range = 10
	light.Brightness = 2
	light.Parent = p
	if s.family == "fire" then
		local fire = Instance.new("Fire")
		fire.Size = d.radius * 2.5
		fire.Heat = 2
		fire.Color = d.color
		fire.SecondaryColor = s.accent
		fire.Parent = p
	elseif s.family == "ice" or s.family == "stone" or s.family == "blade" then
		p.Shape = Enum.PartType.Block
		p.Size = s.family == "blade" and Vector3.new(d.radius * 2.6, 0.25, d.radius) or Vector3.one * d.radius * 1.6
		p.Material = s.family == "stone" and Enum.Material.Slate or (s.family == "ice" and Enum.Material.Glass or Enum.Material.Neon)
		if s.family == "stone" then
			p.Color = Color3.fromRGB(110, 96, 84)
		end
	elseif s.family == "dark" then
		p.Color = Color3.new(0, 0, 0)
		local rim = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * (d.radius * 2.4), CFrame = p.CFrame, Color = d.color, Transparency = 0.6 })
		local weld = Instance.new("WeldConstraint")
		rim.Anchored = false
		weld.Part0 = p
		weld.Part1 = rim
		weld.Parent = rim
		rim.Parent = p
	elseif s.family == "necro" then
		-- A little skull: bone ball with dark eye sockets.
		p.Color = Color3.fromRGB(230, 222, 200)
		p.Material = Enum.Material.SmoothPlastic
	end
end

function PowerVfx.ProjectileEnd(d)
	if d.team ~= "player" then
		return
	end
	PowerVfx.Impact(d.position, d, (d.radius or 1) * 3)
end

-- Impacts --------------------------------------------------------------------------------------

function PowerVfx.Impact(position: Vector3, d, radius: number)
	local s = styleOf(d)
	local color = d.color or Color3.new(1, 1, 1)
	flashLight(position, color, radius * 3, 0.4)
	local family = s.family
	if family == "fire" then
		burst(position, color, 26, radius * 4, 0.8, SPARK, 0.9, 6)
		burst(position, Color3.fromRGB(40, 30, 30), 10, radius * 1.5, radius * 0.9, SMOKE, 1.4, 4)
		if s.feathers then
			for _ = 1, 5 do
				local feather = part({ Size = Vector3.new(0.15, 1.6, 0.6), CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Color = s.accent })
				fadeOut(feather, 1, { CFrame = feather.CFrame + rng:NextUnitVector() * 5 })
			end
		end
	elseif family == "ice" then
		for _ = 1, 7 do
			local shard = part({ Size = Vector3.new(0.5, rng:NextNumber(1.5, 3.5), 0.5), CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(-1, 1), rng:NextNumber(0, 6), rng:NextNumber(-1, 1)), Color = s.accent, Material = Enum.Material.Glass, Transparency = 0.2 })
			fadeOut(shard, 0.9)
		end
		burst(position, s.accent, 18, radius * 3, 0.5)
	elseif family == "stone" then
		chunks(position, Color3.fromRGB(110, 96, 84), Enum.Material.Slate, 8, radius * 2)
		burst(position, Color3.fromRGB(120, 110, 100), 12, radius * 2, radius, SMOKE, 1.2, -2)
	elseif family == "electric" then
		for _ = 1, 4 do
			bolt(position, position + rng:NextUnitVector() * radius * 2, rng:NextNumber() < 0.5 and color or s.accent, 0.25)
		end
		burst(position, s.accent, 16, radius * 5, 0.4, SPARK, 0.4)
	elseif family == "light" then
		for _ = 1, 6 do
			local beam = part({ Size = Vector3.new(0.25, radius * 3, 0.25), CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Color = s.accent })
			fadeOut(beam, 0.35)
		end
		if s.stars then
			star(position, radius * 1.6, s.accent, 0.5)
		end
		burst(position, color, 20, radius * 3, 0.6)
	elseif family == "dark" then
		local core = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * radius * 2.4, CFrame = CFrame.new(position), Color = Color3.new(0, 0, 0), Transparency = 0.1 })
		tween(core, 0.35, { Size = Vector3.one * 0.2 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		Debris:AddItem(core, 0.4)
		ring(position, radius * 1.4, color, 0.4, 0.4)
		burst(position, color, 14, radius * 2, radius * 0.7, SMOKE, 0.9)
	elseif family == "toxic" then
		burst(position, color, 16, radius * 1.5, radius * 0.9, SMOKE, 1.6, 1)
		burst(position, s.accent, 12, radius * 2, 0.4, SPARK, 0.8, -6)
	elseif family == "blade" then
		for i = 1, 3 do
			local slash = part({ Size = Vector3.new(radius * 2.2, 0.12, 0.5), CFrame = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(rng:NextNumber(-40, 40))), Color = s.accent })
			task.delay(i * 0.04, function()
				fadeOut(slash, 0.25, { Size = Vector3.new(radius * 3, 0.03, 0.2) })
			end)
		end
	elseif family == "blood" then
		for _ = 1, 10 do
			local drop = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(0.3, 0.7), CFrame = CFrame.new(position), Color = color, Material = Enum.Material.Glass })
			local target = position + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1), rng:NextNumber(-1, 1)) * radius * 2
			tween(drop, 0.35, { CFrame = CFrame.new(target) })
			task.delay(0.35, function()
				fadeOut(drop, 0.4, { CFrame = CFrame.new(target - Vector3.new(0, 3, 0)) })
			end)
		end
	elseif family == "necro" then
		souls(position, color, 5)
		burst(position, s.accent, 12, radius * 1.5, radius * 0.8, SMOKE, 1.2, 3)
	elseif family == "chrono" then
		clockRing(position, radius * 1.2, color, 0.7)
	elseif family == "wind" then
		for i = 0, 2 do
			ring(position, radius * (1 + i * 0.4), s.accent, 0.35 + i * 0.1, 0.2, CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, math.pi / 2 + rng:NextNumber(-0.4, 0.4)))
		end
	else
		burst(position, color, 14, radius * 3, 0.5)
	end
end

-- Bigger moves -------------------------------------------------------------------------------

function PowerVfx.Nova(d)
	local s = styleOf(d)
	PowerVfx.Impact(d.position, d, d.radius * 0.5)
	for i = 1, 2 do
		task.delay(i * 0.08, function()
			ring(d.position - Vector3.new(0, 2.5, 0), d.radius * (0.7 + i * 0.3), i == 1 and d.color or s.accent, 0.5, 0.6)
		end)
	end
	if s.family == "stone" or s.family == "fire" then
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			local spot = d.position + Vector3.new(math.cos(a), -2.5, math.sin(a)) * d.radius * 0.7
			local spike = part({ Size = Vector3.new(1.4, 0.2, 1.4), CFrame = CFrame.new(spot), Color = s.family == "stone" and Color3.fromRGB(110, 96, 84) or d.color, Material = s.family == "stone" and Enum.Material.Slate or Enum.Material.Neon })
			tween(spike, 0.12, { Size = Vector3.new(1.4, 5, 1.4), CFrame = CFrame.new(spot + Vector3.new(0, 2.5, 0)) })
			task.delay(0.4, function()
				fadeOut(spike, 0.4)
			end)
		end
	end
end

function PowerVfx.Beam(d)
	local s = styleOf(d)
	local length = (d.to - d.from).Magnitude
	for i = 1, math.floor(length / 8) do
		local at = d.from:Lerp(d.to, i / math.floor(length / 8))
		task.delay(i * 0.02, function()
			if s.family == "electric" then
				bolt(at, at + rng:NextUnitVector() * 4, s.accent, 0.2)
			elseif s.family == "light" and s.stars then
				star(at, 2.5, s.accent, 0.4)
			else
				burst(at, s.accent, 4, 4, 0.5, SPARK, 0.5)
			end
		end)
	end
	local core = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, d.width * 0.35, d.width * 0.35), CFrame = CFrame.lookAt((d.from + d.to) / 2, d.to) * CFrame.Angles(0, math.pi / 2, 0), Color = s.accent })
	fadeOut(core, 0.3, { Size = Vector3.new(length, 0.05, 0.05) })
	PowerVfx.Impact(d.to, d, d.width)
end

function PowerVfx.StrikeWarn(d)
	local s = styleOf(d)
	local family = s.family
	local ground = d.position
	-- Something falls from the sky: a meteor, a bolt, a sword, a star, a skull...
	local falling
	if family == "blade" then
		falling = part({ Size = Vector3.new(0.4, d.radius * 0.9, 1.2), CFrame = CFrame.new(ground + Vector3.new(0, 70, 0)), Color = s.accent })
	elseif family == "light" and s.stars then
		falling = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * d.radius * 0.35, CFrame = CFrame.new(ground + Vector3.new(rng:NextNumber(-30, 30), 90, rng:NextNumber(-30, 30))), Color = s.accent })
	elseif family == "chrono" then
		clockRing(ground + Vector3.new(0, 0.5, 0), d.radius, d.color, d.delay, true)
		return
	elseif family == "electric" then
		task.delay(d.delay - 0.05, function()
			bolt(ground + Vector3.new(rng:NextNumber(-6, 6), 80, rng:NextNumber(-6, 6)), ground, s.accent, 0.8)
			bolt(ground + Vector3.new(rng:NextNumber(-6, 6), 80, rng:NextNumber(-6, 6)), ground, d.color, 0.5)
		end)
		return
	else
		falling = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * d.radius * 0.5, CFrame = CFrame.new(ground + Vector3.new(rng:NextNumber(-20, 20), 80, rng:NextNumber(-20, 20))), Color = family == "stone" and Color3.fromRGB(90, 80, 70) or d.color, Material = family == "stone" and Enum.Material.Slate or Enum.Material.Neon })
		if family == "fire" then
			local fire = Instance.new("Fire")
			fire.Size = d.radius
			fire.Color = d.color
			fire.SecondaryColor = s.accent
			fire.Parent = falling
		end
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = family == "dark" and SMOKE or SPARK
	e.Color = ColorSequence.new(d.color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(1.5, 0)
	e.Lifetime = NumberRange.new(0.4)
	e.Rate = 80
	e.Speed = NumberRange.new(0)
	e.Parent = falling
	tween(falling, d.delay, { CFrame = CFrame.new(ground) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(falling, d.delay)
end

function PowerVfx.Strike(d)
	local s = styleOf(d)
	PowerVfx.Impact(d.position, d, d.radius * 0.6)
	if s.family == "stone" or s.family == "fire" then
		chunks(d.position, Color3.fromRGB(80, 70, 62), Enum.Material.Slate, 10, d.radius)
	end
	if s.stars then
		star(d.position + Vector3.new(0, 3, 0), d.radius, s.accent, 0.7)
	end
end

function PowerVfx.Zone(d)
	local s = styleOf(d)
	local started = os.clock()
	local holder = part({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(d.position) }, d.duration + 1)
	local e = Instance.new("ParticleEmitter")
	e.Texture = (s.family == "toxic" or s.family == "dark" or s.family == "necro") and SMOKE or SPARK
	e.Color = ColorSequence.new(d.color, s.accent)
	e.LightEmission = s.family == "dark" and 0 or 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s.family == "toxic" and 4 or 0.8), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.3, 1)
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Rate = math.clamp(d.radius * 6, 30, 160)
	e.Speed = NumberRange.new(d.radius * 0.4, d.radius)
	e.SpreadAngle = Vector2.new(180, 20)
	e.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = d.color
	light.Range = d.radius * 1.5
	light.Brightness = 1.5
	light.Parent = holder
	if s.family == "chrono" then
		clockRing(d.position, d.radius, d.color, d.duration)
	end
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		if t > d.duration then
			connection:Disconnect()
			e.Enabled = false
			return
		end
		local followRoot = d.follow and d.follow:FindFirstChild("HumanoidRootPart")
		if followRoot then
			holder.CFrame = followRoot.CFrame
		end
		-- Flickers of the element inside the zone.
		if rng:NextNumber() < 0.25 then
			local at = holder.Position + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * d.radius * 0.8
			if s.family == "electric" then
				bolt(at + Vector3.new(0, 12, 0), at, s.accent, 0.2)
			elseif s.family == "blade" or s.afterimages then
				local slash = part({ Size = Vector3.new(d.radius * 0.8, 0.1, 0.4), CFrame = CFrame.new(at + Vector3.new(0, rng:NextNumber(1, 4), 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), rng:NextNumber(-0.6, 0.6)), Color = s.accent })
				fadeOut(slash, 0.15)
			elseif s.family == "dark" then
				local wisp = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, CFrame = CFrame.new(at + Vector3.new(0, 2, 0)), Color = Color3.new(0, 0, 0), Transparency = 0.2 })
				tween(wisp, 0.5, { CFrame = CFrame.new(holder.Position + Vector3.new(0, 2, 0)), Size = Vector3.one * 0.2 })
				Debris:AddItem(wisp, 0.55)
			end
		end
	end)
end

function PowerVfx.DashTrail(d)
	local s = styleOf(d)
	local length = (d.to - d.from).Magnitude
	for i = 0, 5 do
		local at = d.from:Lerp(d.to, i / 5)
		task.delay(i * 0.03, function()
			burst(at, s.accent, 6, 6, 0.6, SPARK, 0.5)
			if s.family == "fire" then
				burst(at, d.color, 6, 3, 1.2, SPARK, 0.8, 4)
			end
		end)
	end
	if d.character and (s.afterimages or s.family == "blade" or s.family == "dark") then
		for i = 0, 3 do
			task.delay(i * 0.04, function()
				afterimage(d.character, d.color, 0.5)
			end)
		end
	end
	if length > 1 and s.family == "electric" then
		bolt(d.from, d.to, s.accent, 0.4)
	end
end

function PowerVfx.Buff(d)
	local s = styleOf(d)
	local root = d.character and d.character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	PowerVfx.Impact(root.Position, d, 4)
	for i = 0, 2 do
		task.delay(i * 0.12, function()
			ring(root.Position - Vector3.new(0, 2.6 - i * 2, 0), 4 + i, i == 1 and s.accent or d.color, 0.5, 0.25)
		end)
	end
	if s.family == "fire" then
		-- Wings of flame
		for _, side in { -1, 1 } do
			local wing = part({ Size = Vector3.new(0.2, 3, 6), CFrame = root.CFrame * CFrame.new(side * 3, 1.5, 1) * CFrame.Angles(0, side * 0.6, side * 0.4), Color = d.color })
			fadeOut(wing, 1)
		end
	end
end

function PowerVfx.BlinkChain(d)
	local s = styleOf(d)
	local points = d.points or {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		task.delay((i - 1) * 0.04, function()
			local streak = part({ Size = Vector3.new(0.4, 0.4, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = s.accent })
			fadeOut(streak, 0.35, { Size = Vector3.new(0.05, 0.05, (b - a).Magnitude) })
			bolt(a, b, d.color, 0.2)
			PowerVfx.Impact(b, d, 2.5)
			-- An afterimage of you at each stop.
			local rootPart = d.character and d.character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				for _, child in d.character:GetChildren() do
					if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.Transparency < 1 then
						local relative = rootPart.CFrame:ToObjectSpace(child.CFrame)
						local ghost = part({ Size = child.Size, CFrame = CFrame.new(b) * rootPart.CFrame.Rotation * relative, Color = d.color, Transparency = 0.4 })
						fadeOut(ghost, 0.4)
					end
				end
			end
		end)
	end
end

function PowerVfx.Rise(d)
	souls(d.position, d.color, 4)
	burst(d.position, d.color, 18, 6, 1.2, SMOKE, 1.2, 6)
	local pillar = part({ Size = Vector3.new(3, 0.2, 3), CFrame = CFrame.new(d.position - Vector3.new(0, 2.5, 0)), Color = d.color, Transparency = 0.2 })
	tween(pillar, 0.25, { Size = Vector3.new(3, 9, 3), CFrame = CFrame.new(d.position + Vector3.new(0, 2, 0)) })
	task.delay(0.3, function()
		fadeOut(pillar, 0.4, { Size = Vector3.new(0.2, 10, 0.2) })
	end)
end

function PowerVfx.Rewind(d)
	local root = d.character and d.character:FindFirstChild("HumanoidRootPart")
	if root then
		clockRing(root.Position - Vector3.new(0, 2, 0), 6, d.color, 1, true)
	end
end

function PowerVfx.Revive(d)
	local root = d.character and d.character:FindFirstChild("HumanoidRootPart")
	if root then
		local fire = { color = d.color, style = "phoenix" }
		PowerVfx.Impact(root.Position, fire, 6)
		PowerVfx.Buff({ character = d.character, color = d.color, style = "phoenix" })
	end
end

function PowerVfx.Swing(d)
	if not d.style or not d.character then
		return
	end
	local root = d.character:FindFirstChild("HumanoidRootPart")
	if root and d.combo == 4 then
		PowerVfx.Impact(root.Position + root.CFrame.LookVector * 4, d, 2.5)
	elseif root and rng:NextNumber() < 0.5 then
		burst(root.Position + root.CFrame.LookVector * 3.5, styleOf(d).accent, 5, 5, 0.4, SPARK, 0.4)
	end
end

function PowerVfx.SetFolder(f: Instance)
	folder = f
end

return PowerVfx
