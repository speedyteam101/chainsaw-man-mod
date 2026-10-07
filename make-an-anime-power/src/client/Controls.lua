-- Input: keys / clicks / touch buttons -> ability and attack requests.
-- Works out where the player is aiming and turns the character to face it.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Controls = {}

local player = Players.LocalPlayer
local AIM_DISTANCE = 300
local AUTO_AIM_RANGE = 80

local fxFolder: Instance?

local function aimParams(): RaycastParams
	local exclude = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	if fxFolder then
		table.insert(exclude, fxFolder)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

local function castRay(ray: Ray): Vector3
	local result = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, aimParams())
	return result and result.Position or ray.Origin + ray.Direction * AIM_DISTANCE
end

-- On touch screens there is no mouse, so aim at the closest enemy roughly in
-- front of the camera (or straight ahead if there is none).
local function autoAim(camera: Camera): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local candidates = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			table.insert(candidates, other.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		for _, model in enemies:GetChildren() do
			table.insert(candidates, model)
		end
	end

	local look = camera.CFrame.LookVector
	local best, bestDistance = nil, AUTO_AIM_RANGE
	for _, model in candidates do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local targetRoot = model:FindFirstChild("HumanoidRootPart")
		if humanoid and targetRoot and humanoid.Health > 0 then
			local offset = targetRoot.Position - root.Position
			local distance = offset.Magnitude
			if distance < bestDistance and distance > 0.1 and offset.Unit:Dot(look) > 0.4 then
				best, bestDistance = targetRoot.Position, distance
			end
		end
	end
	return best
end

-- Where the player is aiming, in world space.
function Controls.getAim(fromTouch: boolean): Vector3
	local camera = workspace.CurrentCamera
	if fromTouch then
		local target = autoAim(camera)
		if target then
			return target
		end
		local size = camera.ViewportSize
		return castRay(camera:ViewportPointToRay(size.X / 2, size.Y / 2))
	end
	local mouse = UserInputService:GetMouseLocation()
	return castRay(camera:ViewportPointToRay(mouse.X, mouse.Y))
end

local function faceAim(aim: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local flat = Vector3.new(aim.X, root.Position.Y, aim.Z)
	if (flat - root.Position).Magnitude > 1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

export type Handlers = {
	useAbility: (slot: number, aim: Vector3) -> (),
	basicAttack: (aim: Vector3) -> (),
	toggleCreator: () -> (),
}

function Controls.init(handlers: Handlers, localFxFolder: Instance)
	fxFolder = localFxFolder

	local keyToSlot = {}
	for slot, keyName in Config.AbilityKeys do
		keyToSlot[Enum.KeyCode[keyName]] = slot
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return -- typing in a text box, clicking a button, etc.
		end
		if input.KeyCode == Enum.KeyCode.P then
			handlers.toggleCreator()
			return
		end
		local slot = keyToSlot[input.KeyCode]
		if slot then
			local aim = Controls.getAim(false)
			faceAim(aim)
			handlers.useAbility(slot, aim)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			local aim = Controls.getAim(false)
			faceAim(aim)
			handlers.basicAttack(aim)
		end
	end)
end

-- Used by the on-screen hotbar and Attack buttons.
function Controls.aimForButton(): Vector3
	local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local aim = Controls.getAim(touch)
	faceAim(aim)
	return aim
end

return Controls
