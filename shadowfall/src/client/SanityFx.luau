--!nonstrict
-- What low sanity feels like: the world blurs and drains of colour, the screen edges throb,
-- the camera sways, and shadows that aren't really there appear at the corner of your eye.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShadowRig = require(ReplicatedStorage.Shared.ShadowRig)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)
local ClientState = require(script.Parent.ClientState)

local SanityFx = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rng = Random.new()

local blur: BlurEffect
local grade: ColorCorrectionEffect
local gui, edge, whisperLabel
local phantoms = {}
local nextPhantom = os.clock() + 10

local WHISPERS = { "they're behind you", "it's your fault", "turn around", "they're still in the house", "you should have stayed asleep", "it's too late" }

local function sanity(): number
	return player:GetAttribute("Sanity") or 100
end

local function spawnPhantom(close: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	-- Somewhere off to the side, where you'll only half see it.
	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit
	local side = rng:NextNumber() < 0.5 and -1 or 1
	local angle = math.rad(rng:NextNumber(45, 75)) * side
	local direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(flatLook)
	local distance = close and rng:NextNumber(10, 18) or rng:NextNumber(24, 42)
	local spot = root.Position + direction * distance
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local map = workspace:FindFirstChild("Map")
	params.FilterDescendantsInstances = { map, workspace.Terrain }
	params.IgnoreWater = true
	local hit = map and workspace:Raycast(spot + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	if not hit then
		return
	end
	local model = ShadowRig.Build({ name = "Phantom", scale = rng:NextNumber(1, 1.3), armLength = 1.5, tendrils = 3, smokeRate = 10 })
	-- Anchor only the root: the limbs hang off it through their joints.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	model.PrimaryPart.Anchored = true
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Destroy()
	end
	model:PivotTo(CFrame.lookAt(hit.Position + Vector3.new(0, 3, 0), Vector3.new(root.Position.X, hit.Position.Y + 3, root.Position.Z)))
	model.Parent = workspace
	table.insert(phantoms, { model = model, born = os.clock(), life = rng:NextNumber(1.8, 3.2) })
	Audio.Play("Hallucination", 0.5, rng:NextNumber(0.8, 1.1), hit.Position)
end

local function removePhantom(index: number)
	local phantom = table.remove(phantoms, index)
	if phantom and phantom.model then
		phantom.model:Destroy()
	end
end

function SanityFx.Start()
	blur = Instance.new("BlurEffect")
	blur.Name = "SanityBlur"
	blur.Size = 0
	blur.Parent = Lighting
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "SanityGrade"
	grade.Parent = Lighting

	gui = Ui.screen("Sanity", 4)
	edge = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui }, {
		Ui.new("UIStroke", { Color = Color3.fromRGB(60, 0, 20), Thickness = 0, Transparency = 0.3 }),
	})
	whisperLabel = Ui.label("", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.8, 0, 0, 40),
		Font = Ui.Theme.Horror,
		TextSize = 34,
		TextColor3 = Color3.fromRGB(150, 20, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Parent = gui,
	})
	local stroke = edge:FindFirstChildOfClass("UIStroke")

	RunService.RenderStepped:Connect(function()
		local s = sanity()
		local now = os.clock()
		local strain = math.clamp(1 - s / 60, 0, 1) -- 0 above 60 sanity, 1 at 0
		blur.Size = strain * 7
		grade.Saturation = -strain * 0.45
		grade.Contrast = strain * 0.25
		grade.TintColor = Color3.new(1, 1 - strain * 0.18, 1 - strain * 0.08)
		local pulse = s < 35 and (math.sin(now * (s < 15 and 9 or 4)) + 1) / 2 or 0
		stroke.Thickness = s < 35 and (30 + pulse * 40) * (1 - s / 35) + 1 or 0
		if s < 25 and not ClientState.InCutscene then
			camera.FieldOfView = 70 + math.sin(now * 1.3) * 4 * (1 - s / 25)
		elseif camera.FieldOfView ~= 70 and not ClientState.InCutscene then
			camera.FieldOfView = 70
		end

		-- Phantoms vanish when you look straight at them.
		for index = #phantoms, 1, -1 do
			local phantom = phantoms[index]
			local root = phantom.model.PrimaryPart
			local seen = root and (root.Position - camera.CFrame.Position).Unit:Dot(camera.CFrame.LookVector) > 0.93
			if not root or seen or now - phantom.born > phantom.life then
				removePhantom(index)
			end
		end
		if s < 40 and now >= nextPhantom and not ClientState.InCutscene then
			nextPhantom = now + rng:NextNumber(4, 12) * (s / 40 + 0.4)
			spawnPhantom(s < 20)
			if s < 25 and rng:NextNumber() < 0.5 then
				whisperLabel.Text = WHISPERS[rng:NextInteger(1, #WHISPERS)]
				whisperLabel.TextTransparency = 0.2
				Ui.tween(whisperLabel, 1.6, { TextTransparency = 1 })
			end
		end
	end)
end

return SanityFx
