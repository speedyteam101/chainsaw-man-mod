--!nonstrict
-- Screen feedback: camera kicks and shakes, red damage flash, colour flashes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Ui = require(script.Parent.Ui)

local CameraFx = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local trauma = 0
local overlay: Frame

local function ensureOverlay()
	if overlay then
		return overlay
	end
	local gui = Ui.screen("CameraFx", 30)
	overlay = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
	return overlay
end

function CameraFx.Kick(amount: number)
	trauma = math.min(1.2, trauma + amount)
end

function CameraFx.ShakeAt(position: Vector3, amount: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local distance = (root.Position - position).Magnitude
		CameraFx.Kick(amount * math.clamp(1 - distance / 80, 0, 1))
	end
end

function CameraFx.Flash(color: Color3, time: number?)
	local frame = ensureOverlay()
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0.35
	Ui.tween(frame, time or 0.4, { BackgroundTransparency = 1 })
end

function CameraFx.Hurt(amount: number)
	CameraFx.Flash(Color3.fromRGB(160, 0, 0), 0.35)
	CameraFx.Kick(amount)
end

function CameraFx.SlowFlash(color: Color3)
	CameraFx.Flash(color, 0.8)
end

function CameraFx.Start()
	ensureOverlay()
	RunService:BindToRenderStep("ShadowfallCameraFx", Enum.RenderPriority.Camera.Value + 2, function(dt)
		if trauma <= 0 then
			return
		end
		local shake = trauma * trauma
		local t = os.clock() * 30
		camera.CFrame = camera.CFrame * CFrame.Angles(math.noise(t, 1) * shake * 0.04, math.noise(2, t) * shake * 0.04, math.noise(t, 3) * shake * 0.02)
		trauma = math.max(0, trauma - dt * 2.2)
	end)
end

return CameraFx
