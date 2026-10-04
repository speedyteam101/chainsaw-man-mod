--!nonstrict
-- Realistic effect building blocks, layered on top of each power's stylised effects.
--
-- The idea is to borrow what makes real explosions and impacts read as real:
--   * light that actually lights the scene, and flickers as it dies
--   * smoke that is lit by the world (not glowing), billows, slows down and drifts upward
--   * debris that is the same material as the ground it came from, and bounces with physics
--   * sparks that are fast, fall with gravity and streak along their path
--   * marks left behind: scorch, cracks, frost, splatter, which fade slowly
--   * a ground-hugging dust ring for the shockwave
-- Everything here is local to this client and cleans itself up.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local VfxKit = {}

local V = Config.Vfx
local TEX = V.Textures
local rng = Random.new()
local folder: Folder
local debrisAlive = 0

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = true

local function q(n: number): number
	return math.max(1, math.floor(n * V.Quality + 0.5))
end

local function tween(instance: Instance, time: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function anchor(position: Vector3, lifetime: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.new(position)
	p.Parent = folder
	Debris:AddItem(p, lifetime)
	return p
end

local function seq(...): NumberSequence
	local points = {}
	for _, pair in { ... } do
		table.insert(points, NumberSequenceKeypoint.new(pair[1], pair[2]))
	end
	return NumberSequence.new(points)
end

-- The ground under a point: position, normal, material and colour (terrain or part).
function VfxKit.Ground(position: Vector3, depth: number?)
	groundParams.FilterDescendantsInstances = { folder, workspace.CurrentCamera }
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -(depth or 30), 0), groundParams)
	if not hit then
		return nil
	end
	local color = Color3.fromRGB(90, 84, 78)
	local material = hit.Material
	if hit.Instance:IsA("BasePart") and hit.Instance ~= workspace.Terrain then
		color = hit.Instance.Color
	else
		local ok, terrainColor = pcall(function()
			return workspace.Terrain:GetMaterialColor(material)
		end)
		if ok then
			color = terrainColor
		end
	end
	if material == Enum.Material.Air or material == Enum.Material.Water then
		material = Enum.Material.Slate
	end
	return { position = hit.Position, normal = hit.Normal, material = material, color = color }
end

-- Light ----------------------------------------------------------------------------------------

-- A flash that lights up the surroundings, then flickers out like a real fire/explosion.
function VfxKit.Flash(position: Vector3, color: Color3, range: number, brightness: number, time: number, flicker: boolean?)
	local holder = anchor(position, time + 0.2)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.min(range, 60)
	light.Brightness = brightness
	light.Shadows = true
	light.Parent = holder
	if flicker then
		task.spawn(function()
			local started = os.clock()
			while os.clock() - started < time and light.Parent do
				local alpha = 1 - (os.clock() - started) / time
				light.Brightness = brightness * alpha * rng:NextNumber(0.55, 1.15)
				task.wait(rng:NextNumber(0.03, 0.08))
			end
		end)
	else
		tween(light, time, { Brightness = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
end

-- Particles -------------------------------------------------------------------------------------

local function emitter(parent: Instance, props)
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.LockedToPart = false
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- Billowing smoke, lit by the world. `dark` for soot (fire, explosions), light for dust.
function VfxKit.Smoke(position: Vector3, size: number, color: Color3, count: number?, rise: number?, life: number?)
	local lifetime = life or 2.6
	local holder = anchor(position, lifetime + 0.5)
	local e = emitter(holder, {
		Texture = TEX.Smoke,
		Color = ColorSequence.new(color, color:Lerp(Color3.fromRGB(70, 70, 75), 0.5)),
		LightEmission = 0,
		LightInfluence = 1,
		Size = seq({ 0, size * 0.4 }, { 0.35, size }, { 1, size * 1.6 }),
		Transparency = seq({ 0, 1 }, { 0.12, 0.35 }, { 0.6, 0.6 }, { 1, 1 }),
		Lifetime = NumberRange.new(lifetime * 0.6, lifetime),
		Speed = NumberRange.new(size * 0.8, size * 2.2),
		Drag = 2.5,
		Acceleration = Vector3.new(0, rise or 2.5, 0),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-35, 35),
		ZOffset = -0.5,
	})
	e:Emit(q(count or 10))
end

-- Fast glowing sparks that fall and streak.
function VfxKit.Sparks(position: Vector3, color: Color3, count: number, speed: number, direction: Vector3?)
	local holder = anchor(position, 2)
	if direction and direction.Magnitude > 0.01 then
		holder.CFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(-math.pi / 2, 0, 0)
	end
	local e = emitter(holder, {
		Texture = TEX.Spark,
		Color = ColorSequence.new(Color3.new(1, 1, 0.92), color),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 3,
		Size = seq({ 0, 0.22 }, { 1, 0 }),
		Squash = seq({ 0, -1.5 }, { 1, -0.5 }),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Transparency = seq({ 0, 0 }, { 0.8, 0.2 }, { 1, 1 }),
		Lifetime = NumberRange.new(0.35, 0.9),
		Speed = NumberRange.new(speed * 0.5, speed),
		Drag = 1.2,
		Acceleration = Vector3.new(0, -workspace.Gravity * 0.35, 0),
		SpreadAngle = direction and Vector2.new(55, 55) or Vector2.new(180, 180),
		EmissionDirection = Enum.NormalId.Top,
	})
	e:Emit(q(count))
end

-- Slow glowing embers that drift up and wink out.
function VfxKit.Embers(position: Vector3, color: Color3, count: number, spread: number?)
	local holder = anchor(position, 4)
	holder.Size = Vector3.one * (spread or 3)
	local e = emitter(holder, {
		Texture = TEX.Spark,
		Color = ColorSequence.new(color, Color3.fromRGB(255, 80, 20)),
		LightEmission = 1,
		Brightness = 2,
		Size = seq({ 0, 0.18 }, { 0.5, 0.12 }, { 1, 0 }),
		Transparency = seq({ 0, 0 }, { 0.7, 0.3 }, { 1, 1 }),
		Lifetime = NumberRange.new(1.5, 3),
		Speed = NumberRange.new(1, 4),
		Drag = 0.6,
		Acceleration = Vector3.new(rng:NextNumber(-1, 1), 3, rng:NextNumber(-1, 1)),
		SpreadAngle = Vector2.new(60, 60),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	e:Emit(q(count))
end

-- Flame tongues that lick upward (for fire impacts and burning ground).
function VfxKit.Flames(position: Vector3, color: Color3, size: number, time: number)
	local holder = anchor(position, time + 1.5)
	holder.Size = Vector3.new(size, 0.2, size)
	local e = emitter(holder, {
		Texture = TEX.Fire,
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), color),
		LightEmission = 0.9,
		Brightness = 2,
		Size = seq({ 0, size * 0.35 }, { 0.4, size * 0.5 }, { 1, 0 }),
		Transparency = seq({ 0, 0.3 }, { 0.5, 0.4 }, { 1, 1 }),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(2, 5),
		Acceleration = Vector3.new(0, 8, 0),
		Rotation = NumberRange.new(-20, 20),
		RotSpeed = NumberRange.new(-60, 60),
		SpreadAngle = Vector2.new(15, 15),
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = 40 * V.Quality,
	})
	task.delay(time, function()
		e.Enabled = false
	end)
end

-- A ring of dust that rolls out along the ground (the visible part of a shockwave).
function VfxKit.DustRing(position: Vector3, radius: number, color: Color3)
	local holder = anchor(position + Vector3.new(0, 0.4, 0), 3)
	holder.Size = Vector3.new(radius * 0.5, 0.2, radius * 0.5)
	local e = emitter(holder, {
		Texture = TEX.Smoke,
		Color = ColorSequence.new(color:Lerp(Color3.fromRGB(150, 140, 130), 0.4)),
		LightEmission = 0,
		LightInfluence = 1,
		Size = seq({ 0, radius * 0.15 }, { 1, radius * 0.45 }),
		Transparency = seq({ 0, 0.4 }, { 0.5, 0.65 }, { 1, 1 }),
		Lifetime = NumberRange.new(0.9, 1.6),
		Speed = NumberRange.new(radius * 1.2, radius * 2),
		Drag = 3,
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		Acceleration = Vector3.new(0, 0.6, 0),
	})
	e:Emit(q(math.clamp(radius * 3, 16, 48)))
end

-- Particles sucked inward (implosions, void, gravity).
function VfxKit.Implode(position: Vector3, radius: number, color: Color3)
	local holder = anchor(position, 2)
	holder.Shape = Enum.PartType.Ball
	holder.Size = Vector3.one * radius * 2
	local e = emitter(holder, {
		Texture = TEX.Smoke,
		Color = ColorSequence.new(color, Color3.new(0, 0, 0)),
		LightEmission = 0.3,
		Size = seq({ 0, radius * 0.25 }, { 1, 0 }),
		Transparency = seq({ 0, 0.2 }, { 1, 1 }),
		Lifetime = NumberRange.new(0.35, 0.5),
		Speed = NumberRange.new(radius * 2, radius * 3),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
	})
	e:Emit(q(30))
end

-- Physical debris ------------------------------------------------------------------------------

-- Chunks of whatever the ground is made of, thrown up and bouncing with real physics.
function VfxKit.Rubble(position: Vector3, count: number, force: number, material: Enum.Material?, color: Color3?)
	local ground = VfxKit.Ground(position)
	local mat = material or (ground and ground.material) or Enum.Material.Slate
	local col = color or (ground and ground.color) or Color3.fromRGB(100, 92, 84)
	local origin = (ground and ground.position or position) + Vector3.new(0, 0.6, 0)
	for _ = 1, q(count) do
		if debrisAlive >= V.MaxDebris then
			return
		end
		debrisAlive += 1
		local s = rng:NextNumber(0.35, 1.2)
		local chunk = Instance.new("Part")
		chunk.Size = Vector3.new(s, s * rng:NextNumber(0.5, 1), s * rng:NextNumber(0.6, 1.2))
		chunk.Material = mat
		chunk.Color = col:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.25))
		chunk.CFrame = CFrame.new(origin + rng:NextUnitVector() * 0.8) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		chunk.CanQuery = false
		chunk.CanTouch = false
		chunk.CollisionGroup = "Debris"
		chunk.CastShadow = true
		chunk.Parent = folder
		local flat = rng:NextUnitVector() * Vector3.new(1, 0, 1)
		chunk.AssemblyLinearVelocity = flat * force * rng:NextNumber(0.4, 1) + Vector3.new(0, force * rng:NextNumber(0.7, 1.3), 0)
		chunk.AssemblyAngularVelocity = rng:NextUnitVector() * rng:NextNumber(5, 15)
		task.delay(rng:NextNumber(2.5, 3.5), function()
			if chunk.Parent then
				chunk.Anchored = true
				tween(chunk, 0.8, { Size = chunk.Size * 0.1, Transparency = 1 })
				task.delay(0.85, function()
					chunk:Destroy()
				end)
			end
			debrisAlive -= 1
		end)
	end
end

-- Ground marks ---------------------------------------------------------------------------------

local function decalOnGround(position: Vector3, size: Vector3, color: Color3, material: Enum.Material, transparency: number, rotation: number?)
	local ground = VfxKit.Ground(position)
	if not ground then
		return nil
	end
	local up = ground.normal
	local cf = CFrame.lookAt(ground.position, ground.position + up) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, rotation or rng:NextNumber(0, math.pi * 2), 0)
	local mark = Instance.new("Part")
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark.CastShadow = false
	mark.Size = size
	mark.CFrame = cf * CFrame.new(0, size.Y / 2 + 0.03, 0)
	mark.Color = color
	mark.Material = material
	mark.Transparency = transparency
	mark.Parent = folder
	task.delay(V.MarkLifetime, function()
		if mark.Parent then
			tween(mark, 2, { Transparency = 1 })
			Debris:AddItem(mark, 2.1)
		end
	end)
	return mark
end

-- A blackened scorch with a soft edge (two overlapping discs).
function VfxKit.Scorch(position: Vector3, radius: number, glow: Color3?)
	local inner = decalOnGround(position, Vector3.new(radius * 1.3, 0.05, radius * 1.3), Color3.fromRGB(14, 12, 12), Enum.Material.SmoothPlastic, 0.15)
	if inner then
		inner.Shape = Enum.PartType.Cylinder
		inner.Size = Vector3.new(0.05, radius * 1.3, radius * 1.3)
		inner.CFrame = inner.CFrame * CFrame.Angles(0, 0, math.pi / 2)
	end
	local outer = decalOnGround(position, Vector3.new(0.04, radius * 2, radius * 2), Color3.fromRGB(25, 20, 18), Enum.Material.SmoothPlastic, 0.55)
	if outer then
		outer.Shape = Enum.PartType.Cylinder
		outer.CFrame = outer.CFrame * CFrame.Angles(0, 0, math.pi / 2)
	end
	if glow then
		-- Embers still glowing in the scorch for a moment.
		local hot = decalOnGround(position, Vector3.new(0.06, radius * 0.7, radius * 0.7), glow, Enum.Material.Neon, 0.3)
		if hot then
			hot.Shape = Enum.PartType.Cylinder
			hot.CFrame = hot.CFrame * CFrame.Angles(0, 0, math.pi / 2)
			tween(hot, 2.5, { Transparency = 1, Color = Color3.fromRGB(40, 10, 0) })
		end
	end
end

-- Cracks radiating out from an impact point.
function VfxKit.Cracks(position: Vector3, radius: number, color: Color3?)
	for i = 1, q(7) do
		local length = radius * rng:NextNumber(0.6, 1.3)
		local angle = (i / 7) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local mid = position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * length / 2
		local crack = decalOnGround(mid, Vector3.new(rng:NextNumber(0.12, 0.3), 0.05, length), color or Color3.fromRGB(12, 10, 10), color and Enum.Material.Neon or Enum.Material.SmoothPlastic, 0.1, -angle + math.pi / 2)
		if crack and color then
			tween(crack, 1.5, { Color = Color3.fromRGB(12, 10, 10) })
		end
	end
end

-- Liquid splatter (blood, venom, shadow ichor).
function VfxKit.Splatter(position: Vector3, color: Color3, radius: number, glossy: boolean?)
	for _ = 1, q(6) do
		local r = rng:NextNumber(0.3, 1) * radius
		local spot = position + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * radius
		local blob = decalOnGround(spot, Vector3.new(0.04, r, r * rng:NextNumber(0.6, 1.4)), color, glossy and Enum.Material.Glass or Enum.Material.SmoothPlastic, 0.1)
		if blob then
			blob.Shape = Enum.PartType.Cylinder
			blob.CFrame = blob.CFrame * CFrame.Angles(0, 0, math.pi / 2)
		end
	end
end

-- A frost patch with little crystals.
function VfxKit.Frost(position: Vector3, radius: number, color: Color3)
	local patch = decalOnGround(position, Vector3.new(0.05, radius * 2, radius * 2), color, Enum.Material.Ice, 0.25)
	if patch then
		patch.Shape = Enum.PartType.Cylinder
		patch.CFrame = patch.CFrame * CFrame.Angles(0, 0, math.pi / 2)
	end
	for _ = 1, q(8) do
		local spot = position + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * radius * 0.8
		local h = rng:NextNumber(0.6, 2)
		local crystal = decalOnGround(spot, Vector3.new(0.35, h, 0.35), color, Enum.Material.Glass, 0.2)
		if crystal then
			crystal.CFrame = crystal.CFrame * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4))
		end
	end
end

-- Combined effects -----------------------------------------------------------------------------

-- The realistic layer for a power impact, chosen by the power's family.
function VfxKit.Impact(position: Vector3, family: string, radius: number, color: Color3, accent: Color3)
	local r = math.clamp(radius, 1, 30)
	local ground = VfxKit.Ground(position, r + 8)
	local onGround = ground ~= nil and (position - ground.position).Magnitude < r + 4
	local base = onGround and ground.position or position
	if family == "fire" then
		VfxKit.Flash(position, Color3.fromRGB(255, 150, 60), r * 5, 6, 0.9, true)
		VfxKit.Sparks(position, color, 22, r * 9)
		VfxKit.Smoke(position, r * 0.9, Color3.fromRGB(40, 34, 32), 9, 4)
		VfxKit.Embers(position, accent, 18, r)
		if onGround then
			VfxKit.Flames(base, color, r, 1.4)
			VfxKit.Scorch(base, r, Color3.fromRGB(255, 110, 30))
		end
	elseif family == "stone" then
		VfxKit.Flash(position, Color3.fromRGB(255, 220, 180), r * 3, 2, 0.3)
		VfxKit.Rubble(position, 6 + r, 18 + r * 3)
		VfxKit.Smoke(base, r * 1.1, ground and ground.color or Color3.fromRGB(120, 110, 100), 10, 1)
		if onGround then
			VfxKit.DustRing(base, r * 2, ground.color)
			VfxKit.Cracks(base, r * 1.6)
		end
	elseif family == "electric" then
		VfxKit.Flash(position, color, r * 6, 8, 0.35, true)
		VfxKit.Sparks(position, color, 30, r * 14)
		VfxKit.Smoke(position, r * 0.5, Color3.fromRGB(70, 70, 80), 4, 3, 1.5)
		if onGround then
			VfxKit.Scorch(base, r * 0.8, color)
			VfxKit.Cracks(base, r * 1.2, color)
		end
	elseif family == "ice" then
		VfxKit.Flash(position, accent, r * 3, 2, 0.5)
		VfxKit.Rubble(position, 5 + r, 14 + r * 2, Enum.Material.Ice, accent)
		VfxKit.Smoke(position, r * 0.9, Color3.fromRGB(220, 235, 245), 8, -0.5, 2)
		if onGround then
			VfxKit.Frost(base, r * 1.3, accent)
		end
	elseif family == "light" then
		VfxKit.Flash(position, accent, r * 7, 7, 0.6)
		VfxKit.Sparks(position, accent, 20, r * 10)
		VfxKit.Embers(position, accent, 12, r)
		if onGround then
			VfxKit.Scorch(base, r * 0.7, accent)
		end
	elseif family == "dark" then
		VfxKit.Implode(position, r * 1.5, color)
		VfxKit.Flash(position, color, r * 4, 3, 0.5, true)
		task.delay(0.3, function()
			VfxKit.Smoke(position, r * 1.1, Color3.fromRGB(10, 6, 14), 12, 1.5)
			if onGround then
				VfxKit.DustRing(base, r * 2.2, Color3.fromRGB(20, 14, 26))
				VfxKit.Cracks(base, r * 1.4, color)
			end
		end)
	elseif family == "toxic" then
		VfxKit.Flash(position, color, r * 3, 2, 0.8, true)
		VfxKit.Smoke(position, r * 1.2, color:Lerp(Color3.fromRGB(40, 60, 20), 0.5), 14, 0.4, 3.5)
		if onGround then
			VfxKit.Splatter(base, color, r * 0.9, true)
		end
	elseif family == "blade" then
		VfxKit.Sparks(position, Color3.fromRGB(255, 240, 200), 26, r * 14)
		VfxKit.Flash(position, Color3.new(1, 1, 1), r * 3, 4, 0.15)
		if onGround then
			VfxKit.Cracks(base, r)
		end
	elseif family == "blood" then
		VfxKit.Flash(position, color, r * 3, 2, 0.4)
		VfxKit.Sparks(position, color, 16, r * 8)
		if onGround then
			VfxKit.Splatter(base, Color3.fromRGB(90, 0, 10), r, true)
		end
	elseif family == "necro" then
		VfxKit.Flash(position, color, r * 4, 3, 0.8, true)
		VfxKit.Smoke(position, r, Color3.fromRGB(20, 40, 25), 10, 2)
		if onGround then
			VfxKit.Cracks(base, r * 1.3, color)
			VfxKit.Rubble(position, 4, 14, Enum.Material.Slate, Color3.fromRGB(230, 222, 200))
		end
	elseif family == "wind" then
		if onGround then
			VfxKit.DustRing(base, r * 2.5, ground.color)
		end
		VfxKit.Smoke(position, r * 0.6, Color3.fromRGB(220, 230, 225), 6, 0.5, 1.2)
	elseif family == "chrono" then
		VfxKit.Flash(position, color, r * 4, 3, 0.7)
		VfxKit.Sparks(position, accent, 14, r * 6)
	else
		VfxKit.Flash(position, color, r * 3, 3, 0.4)
		VfxKit.Sparks(position, color, 12, r * 8)
	end
end

-- Shadows bleed black: smoke, droplets and a splash on the ground.
function VfxKit.Ichor(position: Vector3, amount: number)
	VfxKit.Smoke(position, 0.9, Color3.fromRGB(8, 6, 10), math.clamp(math.floor(amount / 6), 2, 8), 2, 1.4)
	local holder = anchor(position, 2)
	local e = emitter(holder, {
		Texture = TEX.Spark,
		Color = ColorSequence.new(Color3.fromRGB(10, 8, 14)),
		LightEmission = 0,
		LightInfluence = 1,
		Size = seq({ 0, 0.35 }, { 1, 0.1 }),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(6, 14),
		Acceleration = Vector3.new(0, -workspace.Gravity * 0.4, 0),
		SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top,
	})
	e:Emit(q(math.clamp(math.floor(amount / 3), 4, 18)))
	if amount >= 20 then
		VfxKit.Splatter(position, Color3.fromRGB(8, 6, 10), 1.4, true)
	end
end

-- A shadow being destroyed: it comes apart into ash and smoke that rise.
function VfxKit.Disintegrate(position: Vector3, scale: number)
	VfxKit.Smoke(position, 1.6 * scale, Color3.fromRGB(10, 8, 12), 14, 5, 3)
	local holder = anchor(position, 5)
	holder.Size = Vector3.new(2, 4, 1) * scale
	local e = emitter(holder, {
		Texture = TEX.Spark,
		Color = ColorSequence.new(Color3.fromRGB(30, 26, 34), Color3.fromRGB(120, 110, 130)),
		LightEmission = 0,
		LightInfluence = 1,
		Size = seq({ 0, 0.25 }, { 1, 0.05 }),
		Lifetime = NumberRange.new(1.5, 3),
		Speed = NumberRange.new(0.5, 2),
		Acceleration = Vector3.new(0, 4, 0),
		Drag = 0.5,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
	})
	e:Emit(q(40 * scale))
	VfxKit.Splatter(position - Vector3.new(0, 2.5 * scale, 0), Color3.fromRGB(8, 6, 10), 2 * scale, true)
end

function VfxKit.Start()
	folder = Instance.new("Folder")
	folder.Name = "RealisticVfx"
	folder.Parent = workspace
end

return VfxKit
