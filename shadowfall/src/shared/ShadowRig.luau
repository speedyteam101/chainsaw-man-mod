--!nonstrict
-- Builds a shadow on the default Roblox R6 character template: the same parts, sizes, rounded
-- head mesh and Motor6D joint layout (RootJoint, Neck, shoulders, hips) as the standard R6 rig,
-- but pitch black, with glowing eyes and smoke pouring off it.
--
-- Parts use black Neon so they render as flat, unlit black: a silhouette cut out of the world.
-- The humanoid uses an explicit HipHeight so scaled rigs (brutes, bosses) stand correctly.
-- Limbs are joined with Motor6Ds named like a classic R6 rig; the client animates them.

local CollectionService = game:GetService("CollectionService")

local ShadowRig = {}

local BLACK = Color3.new(0, 0, 0)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local function part(name: string, size: Vector3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = BLACK
	p.Material = Enum.Material.Neon
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part0
	return m
end

local function weld(part0: BasePart, part1: BasePart, offset: CFrame)
	part1.CFrame = part0.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part1
end

local function addSmoke(target: BasePart, scale: number, rate: number)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(8, 6, 12)
	smoke.Opacity = 0.18
	smoke.RiseVelocity = 2.5 * scale
	smoke.Size = 1.6 * scale
	smoke.TimeScale = 0.6
	smoke.Parent = target

	local wisps = Instance.new("ParticleEmitter")
	wisps.Name = "Wisps"
	wisps.Texture = SMOKE_TEXTURE
	wisps.Color = ColorSequence.new(Color3.fromRGB(0, 0, 0))
	wisps.LightEmission = 0
	wisps.LightInfluence = 0
	wisps.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.6, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	wisps.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9 * scale),
		NumberSequenceKeypoint.new(1, 2.4 * scale),
	})
	wisps.Lifetime = NumberRange.new(0.8, 1.6)
	wisps.Rate = rate
	wisps.Speed = NumberRange.new(1, 3)
	wisps.SpreadAngle = Vector2.new(35, 35)
	wisps.Acceleration = Vector3.new(0, 3, 0)
	wisps.Rotation = NumberRange.new(0, 360)
	wisps.RotSpeed = NumberRange.new(-40, 40)
	wisps.EmissionDirection = Enum.NormalId.Top
	wisps.Parent = target
end

export type RigOptions = {
	name: string?,
	scale: number?,
	eyeColor: Color3?,
	armLength: number?, -- 1 = classic R6 arms; stalkers get longer arms
	smokeRate: number?,
	tendrils: number?, -- smoke tendrils trailing from the back (0-5)
	eyeLight: boolean?, -- eyes cast a faint light (stalkers, bosses)
	antlers: boolean?,
	crown: boolean?,
	manyEyes: boolean?,
}

function ShadowRig.Build(options: RigOptions): Model
	local s = options.scale or 1
	-- Default R6 proportions for every shadow (armLength is kept for API compatibility only).
	local armLength = 1
	local eyeColor = options.eyeColor or Color3.fromRGB(235, 235, 255)

	local model = Instance.new("Model")
	model.Name = options.name or "Shadow"

	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1) * s, model)
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = true
	root.Massless = false
	model.PrimaryPart = root

	local torso = part("Torso", Vector3.new(2, 2, 1) * s, model)
	local head = part("Head", Vector3.new(2, 1, 1) * s, model)
	local rightArm = part("Right Arm", Vector3.new(1, 2 * armLength, 1) * s, model)
	local leftArm = part("Left Arm", Vector3.new(1, 2 * armLength, 1) * s, model)
	local rightLeg = part("Right Leg", Vector3.new(1, 2, 1) * s, model)
	local leftLeg = part("Left Leg", Vector3.new(1, 2, 1) * s, model)

	-- The default R6 rig's joints (same C0/C1 positions and orientations), scaled.
	local function r6(x: number, y: number, z: number, ...)
		return CFrame.new(x * s, y * s, z * s, ...)
	end
	motor("RootJoint", root, torso, r6(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), r6(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Neck", torso, head, r6(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), r6(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Right Shoulder", torso, rightArm, r6(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), r6(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Shoulder", torso, leftArm, r6(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), r6(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	motor("Right Hip", torso, rightLeg, r6(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), r6(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Hip", torso, leftLeg, r6(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), r6(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))

	-- The default R6 head is a rounded mesh 1.25x the part size.
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head

	-- Snap the limbs into place so welded extras line up before the first physics step.
	torso.CFrame = root.CFrame
	head.CFrame = torso.CFrame * CFrame.new(0, 1.5 * s, 0)

	-- Eyes: two thin glowing slits on the front (-Z) face of the head.
	local eyes = {}
	local function eye(name: string, offset: Vector3, size: Vector3)
		local e = part(name, size, model)
		e.Color = eyeColor
		e.Material = Enum.Material.Neon
		weld(head, e, CFrame.new(offset))
		table.insert(eyes, e)
	end
	eye("EyeL", Vector3.new(-0.36, 0.1, -0.62) * s, Vector3.new(0.34, 0.13, 0.08) * s)
	eye("EyeR", Vector3.new(0.36, 0.1, -0.62) * s, Vector3.new(0.34, 0.13, 0.08) * s)
	if options.manyEyes then
		local spots = {
			Vector3.new(0, 0.38, -0.6), Vector3.new(-0.62, -0.25, -0.58), Vector3.new(0.62, -0.25, -0.58),
			Vector3.new(0.6, 0.6, 0.2), Vector3.new(-0.6, 0.6, 0.2), Vector3.new(0, -0.45, -0.6),
		}
		for index, spot in spots do
			eye("EyeExtra" .. index, spot * s, Vector3.new(0.2, 0.2, 0.08) * s)
		end
		for index = 1, 8 do
			local offset = Vector3.new((index % 2 == 0 and 0.5 or -0.5), 0.9 - index * 0.25, -0.52)
			local e = part("TorsoEye" .. index, Vector3.new(0.22, 0.12, 0.06) * s, model)
			e.Color = eyeColor
			weld(torso, e, CFrame.new(offset * s))
			table.insert(eyes, e)
		end
	end

	if options.antlers then
		for _, side in { -1, 1 } do
			local base = part("Antler", Vector3.new(0.3, 2.2, 0.3) * s, model)
			weld(head, base, CFrame.new(0.6 * side * s, 1.4 * s, 0) * CFrame.Angles(0, 0, math.rad(-25 * side)))
			for branch = 1, 3 do
				local tine = part("Tine", Vector3.new(0.22, 1.1, 0.22) * s, model)
				weld(base, tine, CFrame.new(0.35 * side * s, (branch * 0.6 - 0.8) * s, 0) * CFrame.Angles(0, 0, math.rad(-55 * side)))
			end
		end
	end

	if options.crown then
		for index = 0, 6 do
			local angle = index / 7 * math.pi * 2
			local spike = part("CrownSpike", Vector3.new(0.25, 1.3, 0.25) * s, model)
			spike.Color = Color3.fromRGB(60, 0, 10)
			weld(head, spike, CFrame.new(math.cos(angle) * 0.85 * s, 0.95 * s, math.sin(angle) * 0.45 * s))
		end
	end

	-- Detail: the body is only barely holding together.
	local veinColor = eyeColor:Lerp(Color3.new(0, 0, 0), 0.55)

	-- Cracks of dim light running across the torso, arms and face (the client pulses them).
	local cracks = {
		{ torso, Vector3.new(0.12, 1.3, 0.04), CFrame.new(-0.35, 0.1, -0.51) * CFrame.Angles(0, 0, 0.35) },
		{ torso, Vector3.new(0.1, 0.9, 0.04), CFrame.new(0.4, -0.3, -0.51) * CFrame.Angles(0, 0, -0.5) },
		{ torso, Vector3.new(0.6, 0.08, 0.04), CFrame.new(0.15, 0.55, -0.51) * CFrame.Angles(0, 0, 0.2) },
		{ head, Vector3.new(0.08, 0.45, 0.04), CFrame.new(0.5, 0.2, -0.61) * CFrame.Angles(0, 0, 0.4) },
		{ torso, Vector3.new(0.1, 1.2, 0.04), CFrame.new(0.2, 0, 0.51) * CFrame.Angles(0, 0, -0.3) },
	}
	for _, crack in cracks do
		local v = part("Vein", crack[2] * s, model)
		v.Color = veinColor
		local base = crack[3]
		weld(crack[1], v, CFrame.new(base.Position * s) * base.Rotation)
	end

	-- A mouth that splits open when it attacks (hidden until then; the client shows it).
	for index, x in { -0.3, 0, 0.3 } do
		local tooth = part("Mouth", Vector3.new(0.26, 0.1 + (index == 2 and 0.08 or 0), 0.06) * s, model)
		tooth.Color = Color3.fromRGB(120, 0, 10)
		tooth.Transparency = 1
		weld(head, tooth, CFrame.new(Vector3.new(x, -0.25, -0.62) * s) * CFrame.Angles(0, 0, (index - 2) * 0.25))
	end

	-- A pool of darkness under its feet.
	local pool = part("Pool", Vector3.new(0.1, 4.2, 4.2) * s, model)
	pool.Shape = Enum.PartType.Cylinder
	pool.Transparency = 0.35
	weld(root, pool, CFrame.new(0, -3 * s + 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2))

	-- Smoke tendrils trailing from the back, jointed so the client can make them sway.
	local tendrilCount = options.tendrils or 3
	local anchors = { Vector3.new(-0.55, 0.6, 0.5), Vector3.new(0.55, 0.6, 0.5), Vector3.new(0, -0.2, 0.5), Vector3.new(-0.3, 0.9, 0.5), Vector3.new(0.3, -0.6, 0.5) }
	for t = 1, math.min(tendrilCount, #anchors) do
		local previous: BasePart = torso
		local attach = CFrame.new(anchors[t] * s) * CFrame.Angles(math.rad(-15 + t * 6), math.rad((t % 2 == 0 and 1 or -1) * 12), 0)
		for segment = 1, 3 do
			local thickness = (0.42 - segment * 0.09) * s
			local length = (1.5 - segment * 0.2) * s
			local seg = part("Tendril", Vector3.new(thickness, thickness, length), model)
			motor("Tendril" .. t .. "_" .. segment, previous, seg, attach, CFrame.new(0, 0, -length / 2))
			previous = seg
			attach = CFrame.new(0, 0, length / 2)
		end
	end

	-- Smoke trails off the head and hands while it moves.
	local function trail(target: BasePart, a: Vector3, b: Vector3, width: number)
		local a0 = Instance.new("Attachment")
		a0.Position = a
		a0.Parent = target
		local a1 = Instance.new("Attachment")
		a1.Position = b
		a1.Parent = target
		local t = Instance.new("Trail")
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Color = ColorSequence.new(Color3.new(0, 0, 0))
		t.LightInfluence = 0
		t.Transparency = NumberSequence.new(0.35, 1)
		t.Lifetime = 0.45
		t.WidthScale = NumberSequence.new(1, 0.2)
		t.MinLength = 0.05
		t.Parent = target
		return t
	end
	trail(head, Vector3.new(0, 0.45, 0) * s, Vector3.new(0, -0.45, 0) * s, 1)
	for _, arm in { rightArm, leftArm } do
		local tip = -(armLength - 0.15) * s
		trail(arm, Vector3.new(0, tip, 0.4 * s), Vector3.new(0, tip, -0.4 * s), 1)
		-- Smoke dripping off the fingertips.
		local drip = Instance.new("ParticleEmitter")
		drip.Name = "Drip"
		drip.Texture = SMOKE_TEXTURE
		drip.Color = ColorSequence.new(Color3.new(0, 0, 0))
		drip.LightInfluence = 0
		drip.Size = NumberSequence.new(0.35 * s, 0.05)
		drip.Transparency = NumberSequence.new(0.2, 1)
		drip.Lifetime = NumberRange.new(0.5, 0.9)
		drip.Rate = 5
		drip.Speed = NumberRange.new(0, 0.5)
		drip.Acceleration = Vector3.new(0, -28, 0)
		local emitAt = Instance.new("Attachment")
		emitAt.Position = Vector3.new(0, tip, 0)
		emitAt.Parent = arm
		drip.Parent = emitAt
	end

	if options.eyeLight then
		local glow = Instance.new("PointLight")
		glow.Name = "EyeGlow"
		glow.Color = eyeColor
		glow.Range = 7 * s
		glow.Brightness = 1.2
		glow.Shadows = false
		glow.Parent = head
	end

	addSmoke(torso, s, options.smokeRate or 14)
	addSmoke(head, s * 0.7, (options.smokeRate or 14) * 0.5)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- R15 so HipHeight is honoured exactly
	humanoid.HipHeight = 2 * s
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.AutoJumpEnabled = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	humanoid.Parent = model

	model:SetAttribute("RigScale", s)
	CollectionService:AddTag(model, "ShadowRig")
	return model
end

-- Recolours the eyes (used for attack tells: eyes flash red during a wind-up).
function ShadowRig.SetEyeColor(model: Model, color: Color3)
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and (string.sub(child.Name, 1, 3) == "Eye" or string.sub(child.Name, 1, 8) == "TorsoEye") then
			child.Color = color
		end
	end
end

return ShadowRig
