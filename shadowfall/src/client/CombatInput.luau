--!nonstrict
-- Act 2 controls. Keyboard/mouse, gamepad and touch (ContextActionService adds touch buttons).
--   Mouse1 / R2 attack    F / L2 block (hold)    Q / B dodge    Shift sprint
--   Z X C V power moves   G Awakening (level 5)  M menu

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Powers = require(ReplicatedStorage.Shared.Powers)
local Clans = require(ReplicatedStorage.Shared.Clans)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ClientState = require(script.Parent.ClientState)

local CombatInput = {}
CombatInput.OnMessage = nil -- function(text) set by Main to show toasts

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local C = Config.Combat

local attacking = false
local blocking = false
local sprinting = false
local lastDodge = 0
local dashing = false

local function active(): boolean
	return player:GetAttribute("Act") == 2 and not ClientState.MenuOpen and not ClientState.CreatorOpen and not ClientState.InCutscene and not ClientState.BuildMode
end

local function characterParts()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return character, humanoid, root
	end
	return nil
end

-- Where the player is aiming: the mouse on desktop, the camera's centre otherwise.
local function aimPoint(): Vector3?
	local character, _, root = characterParts()
	if not character then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("LocalFx") }
	local ray
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local mouse = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	else
		local size = camera.ViewportSize
		ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	end
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if hit then
		return hit.Position
	end
	local fallback = ray.Origin + ray.Direction * 80
	return Vector3.new(fallback.X, root.Position.Y, fallback.Z)
end

local function faceAim(aim: Vector3?)
	local _, _, root = characterParts()
	if not root or not aim then
		return
	end
	local flat = Vector3.new(aim.X, root.Position.Y, aim.Z)
	if (flat - root.Position).Magnitude > 1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

local function attack()
	if not active() or blocking then
		return
	end
	local aim = aimPoint()
	faceAim(aim)
	Remotes.Action:FireServer("M1", aim)
end

local function setBlocking(on: boolean)
	if blocking == on then
		return
	end
	blocking = on
	Remotes.Action:FireServer("Block", on)
end

local function dodge()
	local _, humanoid, root = characterParts()
	if not root or not active() then
		return
	end
	local now = os.clock()
	if now - lastDodge < C.DodgeCooldown then
		return
	end
	lastDodge = now
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = -root.CFrame.LookVector -- step back if standing still
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	root.AssemblyLinearVelocity = direction * C.DodgeSpeed + Vector3.new(0, 6, 0)
	Remotes.Action:FireServer("Dodge")
end

local function useMove(slot: number)
	if not active() then
		return
	end
	local power = Powers.ById[player:GetAttribute("Power") or ""]
	if not power or (player:GetAttribute("Level") or 1) < slot then
		return
	end
	local aim = aimPoint()
	faceAim(aim)
	Remotes.Action:FireServer("Move", slot, aim)
end

-- The server tells us where a dash move ends; we glide the character there quickly.
local function dashTo(target: Vector3)
	local character, _, root = characterParts()
	if not character or dashing then
		return
	end
	dashing = true
	local start = root.Position
	local finish = Vector3.new(target.X, start.Y, target.Z)
	local look = (finish - start)
	local rotation = look.Magnitude > 0.1 and CFrame.lookAt(Vector3.zero, Vector3.new(look.X, 0, look.Z)) or root.CFrame.Rotation
	local duration = 0.18
	local started = os.clock()
	while true do
		local t = math.min((os.clock() - started) / duration, 1)
		if not root.Parent then
			break
		end
		root.CFrame = CFrame.new(start:Lerp(finish, t)) * rotation
		root.AssemblyLinearVelocity = Vector3.zero
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	dashing = false
end

-- Actions are only bound during Act 2, so their touch buttons don't show up in the horror chapter.
local bindings = {}
local bound = false

local function bind(name: string, title: string?, handler, ...)
	table.insert(bindings, { name = name, title = title, handler = handler, keys = { ... } })
end

local function setBound(on: boolean)
	if on == bound then
		return
	end
	bound = on
	for _, b in bindings do
		if on then
			ContextActionService:BindAction(b.name, function(_, inputState, inputObject)
				if player:GetAttribute("Act") ~= 2 then
					return Enum.ContextActionResult.Pass
				end
				return b.handler(inputState, inputObject) or Enum.ContextActionResult.Pass
			end, b.title ~= nil, table.unpack(b.keys))
			if b.title then
				ContextActionService:SetTitle(b.name, b.title)
			end
		else
			ContextActionService:UnbindAction(b.name)
		end
	end
end

function CombatInput.Start()
	-- Mouse attack goes through UserInputService so clicks on UI don't count.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			attacking = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			attacking = false
		end
	end)

	bind("ShadowfallAttack", "Hit", function(state)
		attacking = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, Enum.KeyCode.ButtonR2)
	bind("ShadowfallBlock", "Block", function(state)
		setBlocking(state == Enum.UserInputState.Begin and active())
		return Enum.ContextActionResult.Sink
	end, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
	bind("ShadowfallDodge", "Dodge", function(state)
		if state == Enum.UserInputState.Begin then
			dodge()
		end
		return Enum.ContextActionResult.Sink
	end, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	bind("ShadowfallSprint", nil, function(state)
		sprinting = state == Enum.UserInputState.Begin
	end, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	local moveKeys = {
		{ Enum.KeyCode.Z, Enum.KeyCode.ButtonX },
		{ Enum.KeyCode.X, Enum.KeyCode.ButtonY },
		{ Enum.KeyCode.C, Enum.KeyCode.DPadLeft },
		{ Enum.KeyCode.V, Enum.KeyCode.DPadRight },
	}
	for slot, keys in moveKeys do
		bind("ShadowfallMove" .. slot, Powers.Keys[slot], function(state)
			if state == Enum.UserInputState.Begin then
				useMove(slot)
			end
			return Enum.ContextActionResult.Sink
		end, keys[1], keys[2])
	end
	for index, itemId in { "Bandage", "Tonic", "LightBomb" } do
		bind("ShadowfallItem" .. index, nil, function(state)
			if state == Enum.UserInputState.Begin and active() then
				task.spawn(function()
					local result = Remotes.Request:InvokeServer("Use", itemId)
					if result and not result.ok and result.message and CombatInput.OnMessage then
						CombatInput.OnMessage(result.message)
					end
				end)
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, ({ Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three })[index])
	end
	bind("ShadowfallAwaken", "G", function(state)
		if state == Enum.UserInputState.Begin and active() and (player:GetAttribute("Level") or 1) >= 5 then
			Remotes.Action:FireServer("Awaken")
		end
		return Enum.ContextActionResult.Sink
	end, Enum.KeyCode.G, Enum.KeyCode.DPadUp)
	-- Clan Mode (Mythic and Transcendent clans only; the server checks).
	bind("ShadowfallClanMode", "Mode", function(state)
		local clan = Clans.ById[player:GetAttribute("Clan") or ""]
		if state == Enum.UserInputState.Begin and active() and clan and clan.mode then
			Remotes.Action:FireServer("Mode")
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, Enum.KeyCode.Y, Enum.KeyCode.ButtonL1)

	local function onAct()
		setBound(player:GetAttribute("Act") == 2)
	end
	player:GetAttributeChangedSignal("Act"):Connect(onAct)
	onAct()

	Remotes.Notify.OnClientEvent:Connect(function(kind, data)
		if kind == "DashMotion" and typeof(data.to) == "Vector3" then
			task.spawn(dashTo, data.to)
		end
	end)

	-- Held attack repeats; walk speed reflects sprint, block and passives.
	local lastAttack = 0
	RunService.RenderStepped:Connect(function()
		if player:GetAttribute("Act") ~= 2 then
			attacking, blocking = false, false
			return
		end
		local _, humanoid = characterParts()
		if not humanoid then
			return
		end
		if ClientState.InCutscene then
			humanoid.WalkSpeed = 0
			return
		end
		local now = os.clock()
		if attacking and now - lastAttack > 0.15 then
			lastAttack = now
			attack()
		end
		local power = Powers.ById[player:GetAttribute("Power") or ""]
		local passive = power and power.passiveEffect.speed or 1
		local speed = sprinting and Config.Act2.SprintSpeed or Config.Act2.WalkSpeed
		if blocking then
			speed = 8
		end
		humanoid.WalkSpeed = speed * passive * (tonumber(player:GetAttribute("SpeedBuff")) or 1) * (tonumber(player:GetAttribute("PassSpeed")) or 1) * (tonumber(player:GetAttribute("ClanSpeed")) or 1)
	end)

	player.CharacterAdded:Connect(function()
		blocking = false
		attacking = false
		dashing = false
	end)
end

return CombatInput
