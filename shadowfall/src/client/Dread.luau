--!nonstrict
-- Act 2 horror. The shadow world should never feel safe outside the firelight:
--   * darkness: outside the camp and your base the world goes darker and the fog closes in
--   * a flashlight (L) that lights what you look at (others see your head lamp)
--   * fear: when shadows are close, the edges of the screen close in and your heart pounds
--   * Watchers: figures standing still at the edge of the fog that vanish when you look right
--     at them
--   * shadows crawling up out of the ground when they appear
--   * the Blackout (BlackoutService): the bell, the lights dying, and the Hollow
--   * a jumpscare when the Hollow catches you
-- Brightness: Config.Horror.Darkness (0 = off) controls how dark it gets.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShadowRig = require(ReplicatedStorage.Shared.ShadowRig)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)
local Atmosphere = require(script.Parent.Atmosphere)
local ClientState = require(script.Parent.ClientState)
local VfxKit = require(script.Parent.VfxKit)

local Dread = {}

local H = Config.Horror
local T = Ui.Theme
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rng = Random.new()

local gui, vignette, scareFrame, banner, bannerSub, timerLabel
local flashlightOn = false
local lightPart: Part
local localLight: SpotLight
local fear = 0
local shake = 0
local watcher = nil
local nextWatcher = os.clock() + 30
local nextWhisper = os.clock() + 40
local lightsKilled = {}

local function act2(): boolean
	return player:GetAttribute("Act") == 2
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Safe = the camp's firelight or inside your own base barrier.
local function isSafe(root: BasePart): boolean
	local character = player.Character
	if character and character:GetAttribute("Safe") == true then
		return true
	end
	local center = player:GetAttribute("BaseCenter")
	local radius = player:GetAttribute("BaseRadius") or 0
	if typeof(center) == "Vector3" and radius > 0 then
		local flat = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
		return flat.Magnitude <= radius
	end
	return false
end

-- UI ---------------------------------------------------------------------------------------------

local function buildUi()
	gui = Ui.screen("Dread", 6)
	vignette = {}
	local edges = {
		{ UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.25, 0), 90 },
		{ UDim2.new(0, 0, 0.75, 0), UDim2.new(1, 0, 0.25, 0), -90 },
		{ UDim2.new(0, 0, 0, 0), UDim2.new(0.22, 0, 1, 0), 0 },
		{ UDim2.new(0.78, 0, 0, 0), UDim2.new(0.22, 0, 1, 0), 180 },
	}
	for _, edge in edges do
		local frame = Ui.new("Frame", { Position = edge[1], Size = edge[2], BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui }, {
			Ui.new("UIGradient", { Rotation = edge[3], Transparency = NumberSequence.new(0, 1) }),
		})
		table.insert(vignette, frame)
	end
	banner = Ui.label("", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.18, 0), Size = UDim2.new(0.9, 0, 0, 50), Font = T.Horror, TextSize = 46, TextColor3 = Color3.fromRGB(230, 225, 235), TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, TextStrokeTransparency = 1, Parent = gui })
	bannerSub = Ui.label("", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.18, 52), Size = UDim2.new(0.9, 0, 0, 22), TextSize = 16, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, Parent = gui })
	timerLabel = Ui.label("", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 86), Size = UDim2.new(0, 520, 0, 22), Font = T.Bold, TextSize = 15, TextColor3 = Color3.fromRGB(230, 200, 255), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, Visible = false, Parent = gui })

	-- Jumpscare: the Hollow's face, far too close.
	scareFrame = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 50, Parent = gui })
	for _, x in { 0.3, 0.58 } do
		Ui.new("Frame", { Position = UDim2.fromScale(x, 0.34), Size = UDim2.fromScale(0.12, 0.07), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 51, Rotation = x < 0.5 and 8 or -8, Parent = scareFrame }, { Ui.corner(40) })
	end
	for i = 0, 9 do
		Ui.new("Frame", { Position = UDim2.fromScale(0.3 + i * 0.04, 0.6 + (i % 2) * 0.02), Size = UDim2.fromScale(0.025, 0.12), BackgroundColor3 = Color3.fromRGB(210, 205, 200), BorderSizePixel = 0, ZIndex = 51, Rotation = (i % 2 == 0) and 6 or -6, Parent = scareFrame })
	end
	Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 0, 0), BackgroundTransparency = 0.75, BorderSizePixel = 0, ZIndex = 52, Parent = scareFrame })
end

local function showBanner(title: string, sub: string, hold: number?)
	banner.Text = title
	bannerSub.Text = sub
	Ui.tween(banner, 0.8, { TextTransparency = 0, TextStrokeTransparency = 0.5 })
	Ui.tween(bannerSub, 0.8, { TextTransparency = 0 })
	task.delay(hold or 4, function()
		if banner.Text == title then
			Ui.tween(banner, 1.2, { TextTransparency = 1, TextStrokeTransparency = 1 })
			Ui.tween(bannerSub, 1.2, { TextTransparency = 1 })
		end
	end)
end

local function jumpscare()
	scareFrame.Visible = true
	shake = 2
	for _ = 1, 7 do
		scareFrame.Position = UDim2.fromOffset(rng:NextInteger(-18, 18), rng:NextInteger(-18, 18))
		scareFrame.Size = UDim2.new(1, rng:NextInteger(0, 40), 1, rng:NextInteger(0, 40))
		task.wait(0.045)
	end
	scareFrame.Visible = false
	scareFrame.Position = UDim2.fromOffset(0, 0)
	scareFrame.Size = UDim2.fromScale(1, 1)
end

-- Flashlight ---------------------------------------------------------------------------------------

local function setFlashlight(on: boolean)
	flashlightOn = on
	localLight.Enabled = on
	Audio.Play("RollTick", 0.3, on and 1.4 or 1.1)
end

-- Lights out (Blackout) -------------------------------------------------------------------------------

local function killLights()
	for _, part in CollectionService:GetTagged("FlickerLight") do
		for _, light in part:GetChildren() do
			if light:IsA("Light") and light.Enabled then
				light.Enabled = false
				lightsKilled[light] = true
			end
		end
	end
end

local function restoreLights()
	for light in lightsKilled do
		if light.Parent then
			light.Enabled = true
		end
	end
	lightsKilled = {}
end

local function darkThud()
	-- A dull thud of darkness: a quick fade to black and back.
	local fade = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 40, Parent = gui })
	Ui.tween(fade, 1.6, { BackgroundTransparency = 1 })
	task.delay(1.7, function()
		fade:Destroy()
	end)
end

local function onBlackoutChanged()
	local phase = workspace:GetAttribute("Blackout")
	if not act2() then
		return
	end
	if phase == "warning" then
		Audio.Play("Bell", 0.9, 0.85)
		showBanner("THE LIGHTS ARE GOING OUT", "Get to the camp or your base, or keep your flashlight (L) ready.", 6)
		-- The lamps stutter harder and harder.
		task.spawn(function()
			for i = 1, 8 do
				if workspace:GetAttribute("Blackout") ~= "warning" then
					break
				end
				killLights()
				task.wait(0.08 + i * 0.02)
				restoreLights()
				task.wait(rng:NextNumber(0.4, 1.2))
			end
		end)
	elseif phase == "active" then
		killLights()
		darkThud()
		showBanner("BLACKOUT", "Something is hunting you. It can't be hurt. Only light stops it.", 5)
		timerLabel.Visible = true
	else
		restoreLights()
		timerLabel.Visible = false
	end
end

-- Watchers ----------------------------------------------------------------------------------------

local function removeWatcher(puff: boolean)
	if not watcher then
		return
	end
	local model = watcher.model
	watcher = nil
	if puff and model.PrimaryPart then
		VfxKit.Smoke(model.PrimaryPart.Position, 2, Color3.fromRGB(10, 8, 14), 10, 3, 1.5)
		Audio.Play("Whisper", 0.35, 0.8, model.PrimaryPart.Position)
	end
	model:Destroy()
end

local function spawnWatcher(root: BasePart)
	-- Off to one side of where you're looking, out at the edge of the fog.
	local look = camera.CFrame.LookVector
	local yaw = math.atan2(look.Z, look.X) + (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(0.6, 1.1)
	local distance = rng:NextNumber(H.Watchers.MinDistance, H.Watchers.MaxDistance)
	local spot = root.Position + Vector3.new(math.cos(yaw), 0, math.sin(yaw)) * distance
	local ground = VfxKit.Ground(spot + Vector3.new(0, 30, 0), 80)
	if not ground then
		return
	end
	local model = ShadowRig.Build({ name = "Watcher", scale = 1.15, armLength = 1.5, eyeColor = Color3.fromRGB(240, 240, 255), smokeRate = 10, tendrils = 3, eyeLight = true })
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	model:PivotTo(CFrame.lookAt(ground.position + Vector3.new(0, 4, 0), Vector3.new(root.Position.X, ground.position.Y + 4, root.Position.Z)))
	model.Parent = workspace
	watcher = { model = model, born = os.clock(), seen = 0 }
end

local function updateWatcher(root: BasePart, dt: number, safe: boolean)
	local now = os.clock()
	if not watcher then
		if not safe and fear < 0.2 and workspace:GetAttribute("Blackout") == nil and now >= nextWatcher then
			nextWatcher = now + rng:NextNumber(H.Watchers.Interval[1], H.Watchers.Interval[2])
			if rng:NextNumber() < H.Watchers.Chance then
				spawnWatcher(root)
			end
		end
		return
	end
	local pivot = watcher.model:GetPivot()
	local offset = pivot.Position - camera.CFrame.Position
	if safe or offset.Magnitude < 25 or now - watcher.born > 14 then
		removeWatcher(offset.Magnitude < 25)
		return
	end
	-- It turns to keep facing you.
	watcher.model:PivotTo(CFrame.lookAt(pivot.Position, Vector3.new(root.Position.X, pivot.Position.Y, root.Position.Z)))
	-- Look straight at it and it's gone.
	if camera.CFrame.LookVector:Dot(offset.Unit) > 0.985 then
		watcher.seen += dt
		if watcher.seen > 0.35 then
			removeWatcher(true)
		end
	end
end

-- Fear -----------------------------------------------------------------------------------------------

local function nearestThreat(root: BasePart): number
	local best = math.huge
	for _, model in CollectionService:GetTagged("Enemy") do
		local primary = model.PrimaryPart
		if primary and (model:GetAttribute("Health") or 1) > 0 then
			best = math.min(best, (primary.Position - root.Position).Magnitude)
		end
	end
	for _, model in CollectionService:GetTagged("Hollow") do
		if model:GetAttribute("Owner") == player.UserId and model.PrimaryPart then
			best = math.min(best, (model.PrimaryPart.Position - root.Position).Magnitude * 0.6) -- it's worse
		end
	end
	return best
end

local heartbeatTimer = 0
local packetTimer = 0
local atmosphereTimer = 0

local function onStep(dt: number)
	local root = rootPart()
	if not act2() or not root then
		gui.Enabled = false
		if localLight then
			localLight.Enabled = false
		end
		removeWatcher(false)
		return
	end
	gui.Enabled = true
	localLight.Enabled = flashlightOn
	lightPart.CFrame = camera.CFrame * CFrame.new(0.5, -0.45, 0)
	local safe = isSafe(root)

	-- Mood: darker outside safety, darkest in a Blackout. (The ending's dawn is left alone.)
	atmosphereTimer += dt
	if atmosphereTimer > 0.5 then
		atmosphereTimer = 0
		local want = workspace:GetAttribute("Blackout") == "active" and "blackout" or (safe and 2 or "2dark")
		if Atmosphere.Current ~= want and Atmosphere.Current ~= "dawn" then
			Atmosphere.Apply(want, want == "blackout" and 1.5 or 3)
		end
	end

	-- Fear from nearby shadows.
	local nearest = nearestThreat(root)
	local target = safe and 0 or math.clamp(1 - (nearest - 8) / 40, 0, 1)
	fear += (target - fear) * math.min(1, dt * 3)
	for _, frame in vignette do
		frame.BackgroundTransparency = 1 - fear * 0.7
	end
	if fear > 0.15 then
		heartbeatTimer += dt
		local interval = 1.2 - fear * 0.8
		if heartbeatTimer >= interval then
			heartbeatTimer = 0
			Audio.Play("Heartbeat", 0.4 + fear * 0.5, 1 + fear * 0.25)
			shake = math.max(shake, fear * 0.35)
		end
	end
	shake = math.max(0, shake - dt * 2.5)

	-- Blackout timer.
	if workspace:GetAttribute("Blackout") == "active" then
		local ends = workspace:GetAttribute("BlackoutEnds") or 0
		local left = math.max(0, math.ceil(ends - workspace:GetServerTimeNow()))
		timerLabel.Text = string.format("BLACKOUT  %d:%02d   |   Hold your light (L) on the Hollow to drive it off", left // 60, left % 60)
	end

	updateWatcher(root, dt, safe)

	-- Ambient whispers out in the dark.
	if not safe and os.clock() >= nextWhisper then
		nextWhisper = os.clock() + rng:NextNumber(35, 80)
		Audio.Play("Whisper", 0.25, rng:NextNumber(0.7, 1), root.Position + rng:NextUnitVector() * 30)
	end

	-- Tell the server where you're looking and whether your light is on (the Hollow needs it).
	packetTimer += dt
	if packetTimer >= 0.1 then
		packetTimer = 0
		Remotes.Flashlight:FireServer(flashlightOn, camera.CFrame.Position, camera.CFrame.LookVector)
	end
end

local function cameraShake()
	if shake < 0.01 or camera.CameraType == Enum.CameraType.Scriptable or not act2() then
		return
	end
	local t = os.clock() * 30
	camera.CFrame = camera.CFrame * CFrame.Angles(math.noise(t, 0) * shake * 0.04, math.noise(0, t) * shake * 0.04, 0)
end

-- Shadows claw their way up out of the ground.
local startedAt = os.clock()
local function onEnemyAdded(model: Instance)
	if os.clock() - startedAt < 5 or not act2() or not model:IsA("Model") then
		return
	end
	task.wait()
	local primary = model.PrimaryPart
	if not primary or (primary.Position - camera.CFrame.Position).Magnitude > 140 then
		return
	end
	local ground = VfxKit.Ground(primary.Position, 20)
	local at = ground and ground.position or primary.Position
	VfxKit.Splatter(at, Color3.fromRGB(8, 6, 10), 2.4, true)
	VfxKit.Smoke(at, 2.2, Color3.fromRGB(10, 8, 14), 12, 4, 2.2)
	VfxKit.Flash(at, Color3.fromRGB(120, 60, 200), 18, 2, 0.8, true)
	VfxKit.Rubble(at, 5, 14)
	Audio.Play("ShadowBreath", 0.5, 0.8, at)
end

function Dread.Start()
	buildUi()
	lightPart = Instance.new("Part")
	lightPart.Name = "Act2Flashlight"
	lightPart.Anchored = true
	lightPart.CanCollide = false
	lightPart.CanQuery = false
	lightPart.CanTouch = false
	lightPart.Transparency = 1
	lightPart.Size = Vector3.one * 0.2
	lightPart.Parent = camera
	localLight = Instance.new("SpotLight")
	localLight.Angle = 48
	localLight.Range = H.FlashlightRange
	localLight.Brightness = 3
	localLight.Color = Color3.fromRGB(255, 244, 222)
	localLight.Shadows = true
	localLight.Face = Enum.NormalId.Front
	localLight.Enabled = false
	localLight.Parent = lightPart

	ContextActionService:BindAction("ShadowfallAct2Light", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin or not act2() or ClientState.MenuOpen or ClientState.CreatorOpen then
			return Enum.ContextActionResult.Pass
		end
		setFlashlight(not flashlightOn)
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.L, Enum.KeyCode.DPadDown)
	ContextActionService:SetTitle("ShadowfallAct2Light", "Light")

	workspace:GetAttributeChangedSignal("Blackout"):Connect(onBlackoutChanged)
	player:GetAttributeChangedSignal("Act"):Connect(function()
		if act2() then
			onBlackoutChanged()
		end
	end)
	Remotes.Story.OnClientEvent:Connect(function(kind)
		if kind == "Jumpscare" and act2() then
			task.spawn(jumpscare)
		end
	end)
	CollectionService:GetInstanceAddedSignal("Enemy"):Connect(function(model)
		task.spawn(onEnemyAdded, model)
	end)
	RunService.RenderStepped:Connect(onStep)
	RunService:BindToRenderStep("ShadowfallDreadShake", Enum.RenderPriority.Camera.Value + 2, cameraShake)
end

return Dread
