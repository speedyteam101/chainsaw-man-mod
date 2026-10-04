--!nonstrict
-- Animates the living people of Hollow Creek (models tagged "Villager": camp survivors, rescued
-- townsfolk, merchants) entirely on this client, procedurally:
--   * a walk cycle that follows how fast they're actually moving (legs and opposite arms swing,
--     a slight bounce and lean)
--   * idle breathing and small weight shifts
--   * heads that turn to look at you when you're close
--   * activities set by the server (NpcService): wave, talk (hand gestures), work (hammering),
--     warm (hands held out to the fire), lookaround
--
-- Joint maths (standard R6 joints): limb C0 * Angles(0, 0, a * side) swings a limb forward by a;
-- Neck/RootJoint C0 * Angles(x, 0, z) nods/leans by x and turns by z.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VillagerAnimator = {}

local ANIMATE_RANGE = 160
local LOOK_RANGE = 14
local player = Players.LocalPlayer

local rigs = {} -- [Model] = { joints, phase, smoothed, seed }

local function register(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			joints[d.Name] = { motor = d, base = d.C0 }
		end
	end
	if not joints.Neck or not joints["Right Shoulder"] then
		return
	end
	rigs[model] = { joints = joints, phase = math.random() * 6, seed = math.random() * 100, smoothed = {} }
end

-- Smoothly moves a joint towards a target angle set.
local function drive(rig, name: string, a: number, b: number, c: number, alpha: number)
	local joint = rig.joints[name]
	if not joint then
		return
	end
	local s = rig.smoothed[name]
	if not s then
		s = { a = 0, b = 0, c = 0 }
		rig.smoothed[name] = s
	end
	s.a += (a - s.a) * alpha
	s.b += (b - s.b) * alpha
	s.c += (c - s.c) * alpha
	joint.motor.C0 = joint.base * CFrame.Angles(s.a, s.b, s.c)
end

-- forward swing for a limb, plus sideways spread
local function limb(rig, name: string, forward: number, spread: number, alpha: number)
	local side = string.sub(name, 1, 5) == "Right" and 1 or -1
	drive(rig, name, spread * side, 0, forward * side, alpha)
end

local function lookYaw(model: Model, torso: BasePart): (number, number)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return 0, 0
	end
	local rel = torso.CFrame:PointToObjectSpace(head.Position)
	local flat = Vector2.new(rel.X, rel.Z).Magnitude
	if flat > LOOK_RANGE or flat < 0.5 then
		return 0, 0
	end
	local yaw = math.atan2(-rel.X, -rel.Z)
	if math.abs(yaw) > math.rad(80) then
		return 0, 0 -- behind them: they don't crane round
	end
	local pitch = math.atan2(rel.Y - 1.5, flat)
	return math.clamp(yaw, -1.1, 1.1), math.clamp(pitch, -0.4, 0.4)
end

function VillagerAnimator.Start()
	for _, model in CollectionService:GetTagged("Villager") do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal("Villager"):Connect(function(model)
		task.defer(register, model)
	end)
	CollectionService:GetInstanceRemovedSignal("Villager"):Connect(function(model)
		rigs[model] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		local cameraPosition = workspace.CurrentCamera.CFrame.Position
		local t = os.clock()
		local alpha = math.min(1, dt * 10)
		for model, rig in rigs do
			local root = model.PrimaryPart
			local torso = model:FindFirstChild("Torso")
			if not model.Parent or not root or not torso then
				rigs[model] = nil
				continue
			end
			if (root.Position - cameraPosition).Magnitude > ANIMATE_RANGE then
				continue
			end
			local velocity = root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local walking = math.clamp(speed / 7, 0, 1)
			rig.phase += dt * speed * 0.95
			local swing = math.sin(rig.phase) * 0.75 * walking
			local tt = t + rig.seed
			local breath = math.sin(tt * 1.6)

			-- Legs and arms: walk cycle, or standing.
			local rightArm, leftArm = -swing * 0.8 + breath * 0.02, swing * 0.8 + breath * 0.02
			local rightSpread, leftSpread = 0.04, 0.04
			local lean = walking * 0.08
			local neckNod, neckTurn = breath * 0.02, 0
			local twist = math.sin(rig.phase) * 0.06 * walking

			local activity = model:GetAttribute("Activity") or ""
			if walking < 0.2 then
				if activity == "wave" then
					rightArm, rightSpread = 2.7, 0.35 + math.sin(tt * 11) * 0.35
				elseif activity == "talk" then
					rightArm = 0.45 + math.sin(tt * 2.7) * 0.3
					leftArm = 0.25 + math.sin(tt * 2.1 + 1) * 0.2
					rightSpread, leftSpread = 0.15, 0.1
					neckNod += math.sin(tt * 3.3) * 0.05
				elseif activity == "work" then
					-- Hammering: raise, strike, raise...
					local beat = (tt * 1.6) % 1
					rightArm = beat < 0.7 and 1.2 + beat * 1.6 or 2.3 - (beat - 0.7) * 6
					leftArm, leftSpread = 0.7, 0.2
					lean = 0.18
					neckNod = -0.15
				elseif activity == "warm" then
					rightArm, leftArm = 1.25 + breath * 0.05, 1.25 - breath * 0.05
					rightSpread, leftSpread = -0.25, -0.25
					lean = 0.06
					neckNod = -0.1
				elseif activity == "lookaround" then
					neckTurn = math.sin(tt * 0.7) * 0.9
				end
			end

			-- Look at you when you're close (unless they're busy hammering).
			if activity ~= "work" then
				local yaw, pitch = lookYaw(model, torso)
				if yaw ~= 0 then
					neckTurn = yaw
					neckNod = pitch
				end
			end

			limb(rig, "Right Hip", swing, 0, alpha)
			limb(rig, "Left Hip", -swing, 0, alpha)
			limb(rig, "Right Shoulder", rightArm, rightSpread, alpha)
			limb(rig, "Left Shoulder", leftArm, leftSpread, alpha)
			drive(rig, "Neck", -neckNod, 0, neckTurn, alpha)
			drive(rig, "RootJoint", lean, 0, twist, alpha)
		end
	end)
end

return VillagerAnimator
