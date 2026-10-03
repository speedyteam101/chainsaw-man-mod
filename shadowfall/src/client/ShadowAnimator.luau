--!nonstrict
-- Animates every shadow's blocky limbs locally (walk cycle, idle sway, wind-up pose, twitching
-- when caught in a flashlight). Only C0 offsets are changed, and only on this client.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ShadowAnimator = {}

local rigs = {} -- [Model] = { joints = { name = { motor, base } }, phase, seed }

local function register(model: Model)
	local joints = {}
	for _, name in { "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip", "Neck" } do
		local motor = model:FindFirstChild(name, true)
		if motor and motor:IsA("Motor6D") then
			joints[name] = { motor = motor, base = motor.C0 }
		end
	end
	rigs[model] = { joints = joints, phase = 0, seed = math.random() * 100 }
end

local function pose(joint, angleX: number, angleZ: number?)
	if joint then
		joint.motor.C0 = joint.base * CFrame.Angles(angleX, 0, angleZ or 0)
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
		local camera = workspace.CurrentCamera
		local cameraPosition = camera.CFrame.Position
		for model, rig in rigs do
			local root = model.PrimaryPart
			if not model.Parent or not root then
				rigs[model] = nil
				continue
			end
			if (root.Position - cameraPosition).Magnitude > 260 then
				continue
			end
			local j = rig.joints
			local velocity = root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local scale = model:GetAttribute("RigScale") or 1
			rig.phase += dt * math.clamp(speed / scale, 0, 30) * 0.55
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
			elseif model:GetAttribute("Attacking") then
				-- Wind-up: arms raised high, head tilted.
				pose(j["Right Shoulder"], 2.6 + math.sin(time * 30) * 0.08)
				pose(j["Left Shoulder"], 2.6 - math.sin(time * 30) * 0.08)
				pose(j["Neck"], -0.3)
				pose(j["Right Hip"], 0.2)
				pose(j["Left Hip"], -0.2)
			else
				local idle = math.sin(time * 1.6 + rig.seed) * 0.08
				pose(j["Right Shoulder"], -s * swing + idle)
				pose(j["Left Shoulder"], s * swing + idle)
				pose(j["Right Hip"], s * swing)
				pose(j["Left Hip"], -s * swing)
				-- Head twitches every so often: they're not quite right.
				local twitch = math.noise(time * 0.7, rig.seed) > 0.42 and (math.random() - 0.5) * 0.5 or 0
				pose(j["Neck"], idle * 0.5, twitch)
			end
		end
	end)
end

return ShadowAnimator
