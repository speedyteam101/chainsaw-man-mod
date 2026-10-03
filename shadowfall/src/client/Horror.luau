--!nonstrict
-- Act 1 on the client: first-person flashlight with a draining battery, sprint stamina,
-- a heartbeat that speeds up as stalkers close in, subtitles, the radio broadcast, the note,
-- jumpscares and the bell-tower finale.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)
local Atmosphere = require(script.Parent.Atmosphere)
local RollUI = require(script.Parent.RollUI)
local ClientState = require(script.Parent.ClientState)

local Horror = {}

local A = Config.Act1
local T = Ui.Theme
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local gui
local objectiveLabel, subtitleLabel, hintLabel, batteryFill, staminaFill, sanityFill, meters
local vignette = {}
local notePanel, scareFrame, fadeFrame

local battery = A.BatteryMax
local stamina = A.StaminaMax
local flashlightOn = false
local sprinting = false
local localLight: SpotLight?
local lightPart: Part?
local shake = 0
local finaleRunning = false

local function act1(): boolean
	return player:GetAttribute("Act") == 1
end

-- UI ---------------------------------------------------------------------------------------

local function buildUi()
	gui = Ui.screen("Horror", 5)

	-- Vignette: four edge gradients that close in when stalkers are near.
	local edges = {
		{ size = UDim2.new(1, 0, 0.35, 0), pos = UDim2.new(0, 0, 0, 0), rot = 90 },
		{ size = UDim2.new(1, 0, 0.35, 0), pos = UDim2.new(0, 0, 0.65, 0), rot = -90 },
		{ size = UDim2.new(0.3, 0, 1, 0), pos = UDim2.new(0, 0, 0, 0), rot = 0 },
		{ size = UDim2.new(0.3, 0, 1, 0), pos = UDim2.new(0.7, 0, 0, 0), rot = 180 },
	}
	for _, edge in edges do
		local frame = Ui.new("Frame", {
			Size = edge.size,
			Position = edge.pos,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			BackgroundTransparency = 0,
			Parent = gui,
		}, {
			Ui.new("UIGradient", {
				Rotation = edge.rot,
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			}),
		})
		table.insert(vignette, frame)
	end

	objectiveLabel = Ui.label("", {
		Position = UDim2.new(0, 28, 0, 52),
		Size = UDim2.new(0, 520, 0, 28),
		Font = T.Title,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(220, 215, 205),
		TextStrokeTransparency = 0.6,
		Parent = gui,
	})

	subtitleLabel = Ui.label("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.new(0.7, 0, 0, 60),
		Font = T.Title,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Parent = gui,
	})

	hintLabel = Ui.label("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -60),
		Size = UDim2.new(0.6, 0, 0, 24),
		Font = T.Body,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(190, 185, 170),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Parent = gui,
	})

	meters = Ui.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 28, 1, -100), Size = UDim2.new(0, 220, 0, 70), Parent = gui })
	local function meter(y: number, color: Color3, name: string)
		local back = Ui.new("Frame", {
			Position = UDim2.new(0, 0, 0, y),
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundColor3 = Color3.fromRGB(20, 20, 24),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Parent = meters,
		}, { Ui.corner(4) })
		Ui.label(name, { Position = UDim2.new(0, 0, 0, -16), Size = UDim2.new(1, 0, 0, 14), TextSize = 12, Font = T.Bold, TextColor3 = Color3.fromRGB(160, 155, 150), Parent = back })
		return Ui.new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0, Parent = back }, { Ui.corner(4) })
	end
	batteryFill = meter(14, Color3.fromRGB(255, 235, 170), "FLASHLIGHT  [F]")
	staminaFill = meter(38, Color3.fromRGB(170, 200, 220), "STAMINA  [SHIFT]")
	sanityFill = meter(62, Color3.fromRGB(190, 150, 255), "SANITY")

	notePanel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 460, 0, 420),
		BackgroundColor3 = Color3.fromRGB(232, 224, 200),
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(3),
		Ui.padding(26),
		Ui.label("", { Name = "Body", Size = UDim2.new(1, 0, 1, -30), Font = T.Title, TextSize = 19, TextColor3 = Color3.fromRGB(40, 32, 28), TextYAlignment = Enum.TextYAlignment.Top }),
		Ui.label("(click or press E to put it down)", { Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), TextSize = 13, TextColor3 = Color3.fromRGB(110, 100, 90), TextXAlignment = Enum.TextXAlignment.Center }),
	})
	local closeNote = Ui.new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = notePanel })
	closeNote.MouseButton1Click:Connect(function()
		notePanel.Visible = false
	end)

	-- Jumpscare: a shadow face filling the screen for a split second.
	scareFrame = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 50, Parent = gui })
	for _, x in { 0.3, 0.58 } do
		Ui.new("Frame", { Position = UDim2.fromScale(x, 0.38), Size = UDim2.fromScale(0.12, 0.05), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 51, Parent = scareFrame })
	end
	Ui.new("Frame", { Position = UDim2.fromScale(0.36, 0.62), Size = UDim2.fromScale(0.28, 0.02), BackgroundColor3 = Color3.fromRGB(60, 60, 60), BorderSizePixel = 0, ZIndex = 51, Rotation = -3, Parent = scareFrame })

	fadeFrame = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 40, Parent = gui })
end

local subtitleQueue = {}
local subtitleRunning = false
local function runSubtitles()
	if subtitleRunning then
		return
	end
	subtitleRunning = true
	while #subtitleQueue > 0 do
		local item = table.remove(subtitleQueue, 1)
		subtitleLabel.TextColor3 = item.color or Color3.fromRGB(235, 230, 220)
		subtitleLabel.TextTransparency = 0
		Ui.typewrite(subtitleLabel, item.text, item.radio and 0.035 or 0.03)
		task.wait(math.clamp(#item.text * 0.035, 1.6, 4))
		Ui.tween(subtitleLabel, 0.4, { TextTransparency = 1 })
		task.wait(0.45)
	end
	subtitleRunning = false
end

local function queueLines(lines, color: Color3?, radio: boolean?)
	for _, line in lines do
		table.insert(subtitleQueue, { text = line, color = color, radio = radio })
	end
	task.spawn(runSubtitles)
end

local function showHint(text: string)
	hintLabel.Text = text
	Ui.tween(hintLabel, 0.5, { TextTransparency = 0 })
	task.delay(6, function()
		if hintLabel.Text == text then
			Ui.tween(hintLabel, 1, { TextTransparency = 1 })
		end
	end)
end

local function setObjective(text: string)
	objectiveLabel.TextTransparency = 1
	Ui.tween(objectiveLabel, 0.6, { TextTransparency = 0 })
	task.spawn(Ui.typewrite, objectiveLabel, "> " .. text, 0.025)
end

-- Flashlight & movement --------------------------------------------------------------------

local function setFlashlight(on: boolean)
	if on and battery < 5 then
		on = false
	end
	flashlightOn = on
	if localLight then
		localLight.Enabled = on
	end
end

local function myStalkers()
	local result = {}
	for _, model in CollectionService:GetTagged("Stalker") do
		if model:GetAttribute("Owner") == player.UserId and model.PrimaryPart then
			table.insert(result, model)
		end
	end
	return result
end

local function onStep(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local isAct1 = act1()
	gui.Enabled = isAct1 or finaleRunning
	if not isAct1 then
		if localLight then
			localLight.Enabled = false
		end
		return
	end

	-- Battery
	if flashlightOn then
		battery = math.max(0, battery - A.BatteryDrain * dt)
		if battery <= 0 then
			setFlashlight(false)
			showHint("The battery is dead. Let it rest a moment.")
		end
	else
		battery = math.min(A.BatteryMax, battery + A.BatteryRegen * dt)
	end
	batteryFill.Size = UDim2.new(battery / A.BatteryMax, 0, 1, 0)

	-- Stamina / sprint
	if humanoid then
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local canSprint = sprinting and moving and stamina > 0 and not finaleRunning
		if canSprint then
			stamina = math.max(0, stamina - A.StaminaDrain * dt)
		else
			stamina = math.min(A.StaminaMax, stamina + A.StaminaRegen * dt)
		end
		humanoid.WalkSpeed = if ClientState.InCutscene and not finaleRunning then 0 else (finaleRunning and 4 or (canSprint and A.SprintSpeed or A.WalkSpeed))
	end
	staminaFill.Size = UDim2.new(stamina / A.StaminaMax, 0, 1, 0)
	sanityFill.Size = UDim2.new(math.clamp((player:GetAttribute("Sanity") or 100) / 100, 0, 1), 0, 1, 0)

	-- Local flashlight follows the camera (the server-side one in your head is for other players).
	if lightPart then
		lightPart.CFrame = camera.CFrame * CFrame.new(0.6, -0.5, 0)
	end

	-- Fear: how close is the nearest stalker?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local nearest = math.huge
	if root then
		for _, model in myStalkers() do
			nearest = math.min(nearest, (model.PrimaryPart.Position - root.Position).Magnitude)
		end
	end
	local fear = math.clamp(1 - (nearest - 6) / 50, 0, 1)
	if finaleRunning then
		fear = 1
	end
	for _, frame in vignette do
		frame.BackgroundTransparency = 0.55 - fear * 0.55
	end
	Atmosphere.Grade.Saturation = -0.55 - fear * 0.4
	shake = math.max(shake - dt * 3, fear * 0.15)
end

local heartbeatAccumulator = 0
local function heartbeat(dt: number)
	if not act1() then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local nearest = math.huge
	for _, model in myStalkers() do
		nearest = math.min(nearest, (model.PrimaryPart.Position - root.Position).Magnitude)
	end
	if nearest > 60 and not finaleRunning then
		return
	end
	local interval = finaleRunning and 0.35 or math.clamp(nearest / 60, 0.35, 1.1)
	heartbeatAccumulator += dt
	if heartbeatAccumulator >= interval then
		heartbeatAccumulator = 0
		Audio.Play("Heartbeat", 0.8, 1 + (1 - interval) * 0.3)
		shake = math.max(shake, 0.25)
	end
end

local packetTimer = 0
local function sendPackets(dt: number)
	if not act1() then
		return
	end
	packetTimer += dt
	if packetTimer < 0.1 then
		return
	end
	packetTimer = 0
	local cf = camera.CFrame
	Remotes.Flashlight:FireServer(flashlightOn, cf.Position, cf.LookVector)
end

local function cameraShake()
	if camera.CameraType == Enum.CameraType.Scriptable then
		return -- cutscene shots set the camera themselves; shaking here would accumulate
	end
	if shake > 0.01 and (act1() or finaleRunning) then
		local t = os.clock() * 40
		camera.CFrame = camera.CFrame * CFrame.Angles(math.noise(t, 0) * shake * 0.05, math.noise(0, t) * shake * 0.05, 0)
	end
end

-- Story events -----------------------------------------------------------------------------

local function jumpscare()
	Audio.Play("Scream", 1)
	scareFrame.Visible = true
	shake = 1.5
	for _ = 1, 6 do
		scareFrame.Position = UDim2.fromOffset(math.random(-14, 14), math.random(-14, 14))
		task.wait(0.05)
	end
	scareFrame.Visible = false
	scareFrame.Position = UDim2.fromOffset(0, 0)
end

local function lightsOut()
	-- Kill every light locally for the finale.
	for _, part in CollectionService:GetTagged("FlickerLight") do
		for _, light in part:GetChildren() do
			if light:IsA("Light") then
				light.Enabled = false
			end
		end
		if part:IsA("BasePart") then
			part.Transparency = 0.8
		end
	end
	setFlashlight(false)
end

local function lightsBack()
	for _, part in CollectionService:GetTagged("FlickerLight") do
		for _, light in part:GetChildren() do
			if light:IsA("Light") then
				light.Enabled = true
			end
		end
		if part:IsA("BasePart") then
			part.Transparency = 0
		end
	end
end

-- The opening: waking up, finding Mum and Dad, and Biscuit in trouble ------------------------

local introPlayed = false

local function shot(view, time: number, style: Enum.EasingStyle?)
	local goal = CFrame.lookAt(view.from, view.to)
	if time <= 0 then
		camera.CFrame = goal
		return
	end
	local tween = Ui.tween(camera, time, { CFrame = goal }, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	tween.Completed:Wait()
end

local function playIntro(payload)
	if introPlayed then
		showHint("Hold your flashlight [F] on the shadow to drive it away from Biscuit!")
		return
	end
	introPlayed = true
	ClientState.InCutscene = true
	camera.CameraType = Enum.CameraType.Scriptable

	-- Eyelids and blur for waking up.
	local blur = Instance.new("BlurEffect")
	blur.Size = 24
	blur.Parent = game:GetService("Lighting")
	local top = Ui.new("Frame", { Size = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 45, Parent = gui })
	local bottom = Ui.new("Frame", { Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 45, Parent = gui })
	local clock = Ui.label("", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(0.6, 0, 0, 60), Font = T.Title, TextSize = 46, TextColor3 = Color3.fromRGB(200, 40, 40), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 46, Parent = gui })
	shot(payload.bedView, 0)

	Ui.typewrite(clock, "12:04 PM", 0.12)
	task.wait(1.2)
	Ui.tween(clock, 0.8, { TextTransparency = 1 })
	Audio.Play("Quack", 0.9, 1.3)
	queueLines({ "*QUACK! QUACK QUACK!*" }, Color3.fromRGB(255, 230, 150))
	task.wait(1.4)
	Audio.Play("Quack", 1, 1.45)

	-- Open your eyes... slowly, then a blink.
	local function lids(open: number, time: number)
		Ui.tween(top, time, { Size = UDim2.new(1, 0, 0.5 - open * 0.5, 0) })
		local t = Ui.tween(bottom, time, { Position = UDim2.new(0, 0, 0.5 + open * 0.5, 0), Size = UDim2.new(1, 0, 0.5 - open * 0.5, 0) })
		t.Completed:Wait()
	end
	lids(0.35, 1.2)
	lids(0, 0.25)
	lids(1, 0.9)
	Ui.tween(blur, 2.5, { Size = 0 })
	queueLines({ "Why is it so dark? It's noon...", "Biscuit? What's wrong?" })
	task.wait(2.6)

	shot(payload.parentsView, 2.6)
	queueLines({ "...Mum? Dad?", "No. No, no, no..." }, Color3.fromRGB(255, 210, 200))
	shake = 0.4
	task.wait(4)

	Audio.Play("Quack", 1, 1.6)
	shot(payload.duckView, 1.4, Enum.EasingStyle.Quad)
	shake = 1.2
	queueLines({ "BISCUIT!" }, Color3.fromRGB(255, 120, 120))
	task.wait(2.2)

	blur:Destroy()
	top:Destroy()
	bottom:Destroy()
	clock:Destroy()
	camera.CameraType = Enum.CameraType.Custom
	ClientState.InCutscene = false
	showHint("Press F for your flashlight. Hold the light on the shadow to drive it away from Biscuit!")
end

local function onStory(kind: string, payload)
	if kind == "Intro" then
		playIntro(payload)
	elseif kind == "DuckSaved" then
		Audio.Play("Quack", 1, 1.2)
		task.delay(5, function()
			showHint("Biscuit follows you now. Staying close to Biscuit calms you and slowly heals you.")
		end)
	elseif kind == "Objective" then
		setObjective(payload.text)
	elseif kind == "Subtitles" then
		queueLines(payload.lines)
	elseif kind == "Hint" then
		showHint(payload.text)
	elseif kind == "Broadcast" then
		local static = Audio.Loop("Radio", 0.3)
		queueLines(payload.lines, Color3.fromRGB(150, 255, 170), true)
		task.delay(#payload.lines * 4.5, function()
			if static then
				Audio.StopLoop("Radio")
			end
		end)
	elseif kind == "Note" then
		notePanel.Body.Text = payload.text
		notePanel.Visible = true
	elseif kind == "Jumpscare" then
		task.spawn(jumpscare)
	elseif kind == "Whisper" then
		Audio.Play("Whisper", 0.5, 1, payload.position)
	elseif kind == "Finale" then
		finaleRunning = true
		ClientState.InCutscene = true
		Audio.Play("Bell", 1)
		queueLines(payload.lines, Color3.fromRGB(255, 220, 200))
		task.delay(3, lightsOut)
	elseif kind == "FinaleAborted" then
		finaleRunning = false
		ClientState.InCutscene = false
		lightsBack()
	elseif kind == "Surrounded" then
		queueLines(payload.lines, Color3.fromRGB(255, 200, 160))
	elseif kind == "Roll" then
		-- The awakening: white flash, then the roll.
		fadeFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		fadeFrame.BackgroundTransparency = 0
		shake = 2
		task.wait(0.4)
		RollUI.Play(payload.power, { first = true })
		fadeFrame.BackgroundTransparency = 1
		fadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
		finaleRunning = false
		lightsBack()
		Remotes.Request:InvokeServer("FinishAct1")
		ClientState.InCutscene = false
	end
end

local function bindAct1(on: boolean)
	if not on then
		for _, name in { "ShadowfallFlashlight", "ShadowfallAct1Sprint", "ShadowfallCloseNote" } do
			ContextActionService:UnbindAction(name)
		end
		sprinting = false
		return
	end
	ContextActionService:BindAction("ShadowfallFlashlight", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and act1() and not finaleRunning then
			setFlashlight(not flashlightOn)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonL1)
	ContextActionService:SetTitle("ShadowfallFlashlight", "Light")
	ContextActionService:SetPosition("ShadowfallFlashlight", UDim2.new(1, -170, 1, -150))

	ContextActionService:BindAction("ShadowfallAct1Sprint", function(_, inputState)
		if not act1() then
			return Enum.ContextActionResult.Pass
		end
		sprinting = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("ShadowfallAct1Sprint", "Run")
	ContextActionService:SetPosition("ShadowfallAct1Sprint", UDim2.new(1, -240, 1, -90))

	ContextActionService:BindAction("ShadowfallCloseNote", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and notePanel.Visible then
			notePanel.Visible = false
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E)
end

function Horror.Start()
	buildUi()
	local part = Instance.new("Part")
	part.Name = "LocalFlashlight"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = workspace
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 40
	light.Range = A.FlashlightRange + 6
	light.Brightness = 3.2
	light.Color = Color3.fromRGB(255, 244, 220)
	light.Shadows = true
	light.Enabled = false
	light.Parent = part
	lightPart = part
	localLight = light

	RunService.RenderStepped:Connect(function(dt)
		onStep(dt)
		heartbeat(dt)
		sendPackets(dt)
	end)
	RunService:BindToRenderStep("ShadowfallShake", Enum.RenderPriority.Camera.Value + 1, cameraShake)

	Remotes.Story.OnClientEvent:Connect(function(kind, payload)
		task.spawn(onStory, kind, payload)
	end)

	local function onAct()
		bindAct1(act1())
		if act1() then
			Audio.Loop("Ambience", 0.35)
		else
			Audio.StopLoop("Ambience")
			setFlashlight(false)
		end
	end
	player:GetAttributeChangedSignal("Act"):Connect(onAct)
	onAct()
end

return Horror
