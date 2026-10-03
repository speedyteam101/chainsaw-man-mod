--!nonstrict
-- Animates every shadow locally: walk cycle, idle sway, wind-up pose, swaying smoke tendrils,
-- pulsing cracks, a mouth that tears open to attack, glitchy flickers, twitching heads, and
-- breathing. Stalkers move in a jerky, stop-motion way. Only this client sees these changes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local ShadowAnimator = {}

local rigs = {} -- [Model] = rig state
local ANIMATE_RANGE = 220
local DETAIL_RANGE = 110 -- tendrils, flicker and breathing only up close

local function register(model: Model)
	local joints = {}
	local tendrils = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local entry = { motor = descendant, base = descendant.C0 }
			if string.sub(descendant.Name, 1, 7) == "Tendril" then
				local t, segment = string.match(descendant.Name, "Tendril(%d+)_(%d+)")
				entry.t = tonumber(t) or 1
				entry.segment = tonumber(segment) or 1
				table.insert(tendrils, entry)
			else
				joints[descendant.Name] = entry
			end
		end
	end
	local veins, mouth, body = {}, {}, {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			if child.Name == "Vein" then
				table.insert(veins, child)
			elseif child.Name == "Mouth" then
				table.insert(mouth, child)
			elseif child.Name ~= "HumanoidRootPart" and child.Name ~= "Pool" then
				table.insert(body, child)
			end
		end
	end
	local breath
	local id = Config.Sounds.ShadowBreath
	local head = model:FindFirstChild("Head")
	if id and id ~= "" and head then
		breath = Instance.new("Sound")
		breath.SoundId = id
		breath.Looped = true
		breath.Volume = 0.35
		breath.RollOffMaxDistance = 40
		breath.PlaybackSpeed = 0.9 + math.random() * 0.2
		breath.Parent = head
	end
	rigs[model] = {
		joints = joints,
		tendrils = tendrils,
		veins = veins,
		mouth = mouth,
		body = body,
		breath = breath,
		phase = 0,
		seed = math.random() * 100,
		stalker = CollectionService:HasTag(model, "Stalker"),
		nextPose = 0,
		glitchUntil = 0,
		mouthOpen = false,
	}
end

-- Shadows use the default R6 joint layout, so (like Roblox's own R6 animations) limbs swing
-- around each joint's Z axis, mirrored between the right and left side.
--   limbs: angleX = swing forward (+) / back (-), angleZ = small sideways spread
--   neck:  angleX = nod, angleZ = tilt, angleY = turn
local function pose(joint, angleX: number, angleZ: number?, angleY: number?)
	if not joint then
		return
	end
	local name = joint.motor.Name
	if name == "Neck" then
		joint.motor.C0 = joint.base * CFrame.Angles(-angleX, angleZ or 0, angleY or 0)
	else
		local side = string.sub(name, 1, 5) == "Right" and 1 or -1
		joint.motor.C0 = joint.base * CFrame.Angles((angleZ or 0) * side, 0, angleX * side)
	end
end

local function setMouth(rig, open: boolean)
	if rig.mouthOpen == open then
		return
	end
	rig.mouthOpen = open
	for _, tooth in rig.mouth do
		tooth.Transparency = open and 0 or 1
	end
end

function ShadowAnimator.Start()
	for _, model in CollectionService:GetTagged("ShadowRig") do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal("ShadowRig"):Connect(function(model)
		task.defer(register, model)
	end)
	CollectionService:GetInstanceRemovedSignal("ShadowRig"):Connect(function(model)
		rigs[model] = nil
	end)

	RunService.Stepped:Connect(function(time, dt)
		local cameraPosition = workspace.CurrentCamera.CFrame.Position
		for model, rig in rigs do
			local root = model.PrimaryPart
			if not model.Parent or not root then
				rigs[model] = nil
				continue
			end
			local distance = (root.Position - cameraPosition).Magnitude
			if rig.breath then
				local wantPlaying = distance < 45 and not model:GetAttribute("Dead")
				if wantPlaying ~= rig.breath.IsPlaying then
					if wantPlaying then
						rig.breath:Play()
					else
						rig.breath:Stop()
					end
				end
			end
			if distance > ANIMATE_RANGE then
				continue
			end
			local j = rig.joints
			local velocity = root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local scale = model:GetAttribute("RigScale") or 1
			rig.phase += dt * math.clamp(speed / scale, 0, 30) * 0.55
			local attacking = model:GetAttribute("Attacking") == true
			setMouth(rig, attacking or model:GetAttribute("Lit") == true)

			-- Stalkers only update their pose a few times a second: stop-motion, wrong.
			local updatePose = true
			if rig.stalker then
				if time < rig.nextPose then
					updatePose = false
				else
					rig.nextPose = time + 0.09 + math.random() * 0.08
				end
			end

			if updatePose then
				local swing = math.clamp(speed / (14 * scale), 0, 1) * 0.9
				local s = math.sin(rig.phase)
				if model:GetAttribute("Lit") then
					-- Frozen in the light: shake violently.
					local jitter = (math.random() - 0.5) * 0.5
					pose(j["Right Shoulder"], -0.4 + jitter)
					pose(j["Left Shoulder"], -0.4 - jitter)
					pose(j["Neck"], jitter, (math.random() - 0.5) * 0.6)
					pose(j["Right Hip"], 0)
					pose(j["Left Hip"], 0)
				elseif attacking then
					-- Wind-up: arms raised high, head cocked, jaw open.
					pose(j["Right Shoulder"], 2.6 + math.sin(time * 30) * 0.08, 0.2)
					pose(j["Left Shoulder"], 2.6 - math.sin(time * 30) * 0.08, -0.2)
					pose(j["Neck"], -0.35, math.sin(time * 9) * 0.15)
					pose(j["Right Hip"], 0.25)
					pose(j["Left Hip"], -0.25)
				else
					-- Arms hang a little too long and swing a little too loosely.
					local idle = math.sin(time * 1.6 + rig.seed) * 0.08
					local hunch = rig.stalker and 0.25 or 0.1
					pose(j["Right Shoulder"], -s * swing + idle + hunch, 0.06)
					pose(j["Left Shoulder"], s * swing + idle + hunch, -0.06)
					pose(j["Right Hip"], s * swing)
					pose(j["Left Hip"], -s * swing)
					local twitch = math.noise(time * 0.7, rig.seed) > 0.42 and (math.random() - 0.5) * 0.6 or 0
					-- Every so often the head snaps sideways.
					local snap = math.noise(time * 0.25, rig.seed + 7) > 0.55 and 1.2 or 0
					pose(j["Neck"], idle * 0.5 - hunch * 0.6, twitch + snap * 0.6, snap * 0.3)
				end
			end

			if distance > DETAIL_RANGE then
				continue
			end

			-- Tendrils sway like smoke underwater, each segment lagging the one before it.
			for _, tendril in rig.tendrils do
				local wave = time * (2.2 + tendril.t * 0.3) + rig.seed - tendril.segment * 0.9
				local drag = math.clamp(speed / 20, 0, 1) * 0.35
				tendril.motor.C0 = tendril.base * CFrame.Angles(math.sin(wave) * 0.35 + drag, math.cos(wave * 0.8) * 0.4, 0)
			end

			-- Cracks pulse like a slow heartbeat.
			local beat = (math.sin(time * 2.4 + rig.seed) + 1) / 2
			for _, vein in rig.veins do
				vein.Transparency = 0.15 + beat * 0.6
			end

			-- Glitch: the body flickers out for a frame or two.
			if time > rig.glitchUntil and math.random() < 0.004 then
				rig.glitchUntil = time + 0.05 + math.random() * 0.08
			end
			local glitching = time < rig.glitchUntil
			if glitching ~= rig.glitching then
				rig.glitching = glitching
				for _, part in rig.body do
					part.LocalTransparencyModifier = glitching and 0.85 or 0
				end
			end
		end
	end)
end

return ShadowAnimator
