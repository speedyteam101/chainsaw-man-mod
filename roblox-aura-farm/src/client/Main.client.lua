-- Aura Farm client: input (slash / dash / ultimate), dash movement,
-- animations and afterimages, forwarding chat to the server, and feeding
-- the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Assets = require(Shared:WaitForChild("Assets"))
local Classes = require(Shared:WaitForChild("Classes"))
local Afterimages = require(script.Parent:WaitForChild("Afterimages"))
local AnimationPlayer = require(script.Parent:WaitForChild("AnimationPlayer"))
local ClassPicker = require(script.Parent:WaitForChild("ClassPicker"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("AuraFarmRemotes")
local ActionRemote = remotes:WaitForChild("Action") :: RemoteEvent
local ShoutRemote = remotes:WaitForChild("Shout") :: RemoteEvent
local NotifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent
local ChooseClassRemote = remotes:WaitForChild("ChooseClass") :: RemoteEvent

-- A stat of the player's class (defaults while undecided). Cooldowns here
-- only stop pointless requests; the server enforces the real ones.
local function stat(key: string): number
	local class = Classes.get(player:GetAttribute("ClassId"))
	return if class then class[key] else Classes.Defaults[key]
end

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function liveCharacter()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, humanoid, root :: BasePart
end

---------------------------------------------------------------------------
-- Chat
---------------------------------------------------------------------------

-- Shout box: post to the real chat (so everyone sees it, filtered by
-- Roblox) when TextChatService is in use, and always tell the server
-- directly too. The server ignores duplicates.
local function shout(message: string)
	pcall(function()
		if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			local channels = TextChatService:FindFirstChild("TextChannels")
			local general = channels and channels:FindFirstChild("RBXGeneral")
			if general then
				(general :: TextChannel):SendAsync(message)
			end
		end
	end)
	ShoutRemote:FireServer(message)
end

-- Messages typed into the normal chat box.
pcall(function()
	TextChatService.SendingMessage:Connect(function(message: TextChatMessage)
		ShoutRemote:FireServer(message.Text)
	end)
end)

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local hud
local lastSlash, lastDash, lastUltimate = -math.huge, -math.huge, -math.huge

-- Your custom Dash effect (Assets.lua) for a player dashing from `root`.
local function dashEffect(dasher: Player, root: BasePart, direction: Vector3)
	local class = Classes.get(dasher:GetAttribute("ClassId"))
	Assets.spawnEffect("Dash", CFrame.lookAt(root.Position, root.Position + direction), {
		classId = if class then class.Id else nil,
		side = dasher:GetAttribute("Side"),
		color = if class then rgb(class.Color) else nil,
	})
end

local function slash()
	local now = os.clock()
	local cooldown = stat("SlashCooldown")
	if now - lastSlash < cooldown or not liveCharacter() then
		return
	end
	lastSlash = now
	ActionRemote:FireServer("Slash")
	AnimationPlayer.playSlash()
	hud.cooldown("Slash", cooldown)
end

-- Turning AutoRotate off during a lunge keeps the character facing the same
-- way, so a back or side dash actually looks like one. Counted, so
-- overlapping lunges (a dash into a Rush) restore it correctly.
local rotateLocks = 0
local savedAutoRotate = true

-- Pushes the character along `direction` (a flat unit vector) at `speed`
-- for `duration` seconds, leaving avatar afterimages behind.
local function lunge(direction: Vector3, speed: number, duration: number)
	local character, humanoid, root = liveCharacter()
	if not character or not humanoid or not root then
		return
	end
	if rotateLocks == 0 then
		savedAutoRotate = humanoid.AutoRotate
	end
	rotateLocks += 1
	humanoid.AutoRotate = false
	Afterimages.trail(character, duration + 0.05)

	local elapsed = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= duration or not root.Parent then
			connection:Disconnect()
			rotateLocks -= 1
			if rotateLocks == 0 and humanoid.Parent then
				humanoid.AutoRotate = savedAutoRotate
			end
			return
		end
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(direction.X * speed, math.max(velocity.Y, 0), direction.Z * speed)
	end)
end

local function flatUnit(v: Vector3): Vector3?
	local flat = Vector3.new(v.X, 0, v.Z)
	return if flat.Magnitude > 0.1 then flat.Unit else nil
end

local function dash()
	local now = os.clock()
	local cooldown = stat("DashCooldown")
	local _, humanoid, root = liveCharacter()
	if now - lastDash < cooldown or not humanoid or not root then
		return
	end
	-- Dash the way you're moving (or forward if you're standing still).
	local direction = flatUnit(humanoid.MoveDirection) or flatUnit(root.CFrame.LookVector)
	if not direction then
		return
	end
	lastDash = now
	ActionRemote:FireServer("Dash")
	hud.cooldown("Dash", cooldown)

	local relative = root.CFrame:VectorToObjectSpace(direction)
	AnimationPlayer.playDash(relative.X, relative.Z)
	dashEffect(player, root, direction)
	lunge(direction, Config.Combat.DashSpeed, Config.Combat.DashDuration)
end

local function ultimate()
	local now = os.clock()
	if now - lastUltimate < Config.Combat.UltimateCooldown or not liveCharacter() then
		return
	end
	lastUltimate = now
	ActionRemote:FireServer("Ultimate")
	-- Only animate if the server will accept it (it re-checks).
	if Classes.get(player:GetAttribute("ClassId")) and (player:GetAttribute("Style") or 0) >= Config.Combat.UltimateStyleCost then
		AnimationPlayer.playUltimate()
	end
	hud.cooldown("Ultimate", Config.Combat.UltimateCooldown)
end

local ACTIONS = { Slash = slash, Dash = dash, Ultimate = ultimate }

local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local picker = ClassPicker.new(playerGui, function(classId: string)
	ChooseClassRemote:FireServer(classId)
end)

hud = Hud.new(playerGui, {
	onClassButton = function()
		picker.open(player:GetAttribute("ClassId"))
	end,
	onShout = shout,
	onAction = function(name: string)
		local action = ACTIONS[name]
		if action then
			action()
		end
	end,
})

-- Hold the mouse button (or gamepad trigger) to keep slashing.
local holdingSlash = false
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		holdingSlash = true
		slash()
	elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB then
		dash()
	elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonY then
		ultimate()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		holdingSlash = false
	end
end)
RunService.Heartbeat:Connect(function()
	if holdingSlash then
		slash()
	end
end)

---------------------------------------------------------------------------
-- HUD feeds
---------------------------------------------------------------------------

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local aura = leaderstats:WaitForChild("Aura") :: IntValue
	hud.setAura(aura.Value)
	aura.Changed:Connect(function(value)
		hud.setAura(value)
	end)
end)

hud.setStyle(player:GetAttribute("Style") or 0)
player:GetAttributeChangedSignal("Style"):Connect(function()
	hud.setStyle(player:GetAttribute("Style") or 0)
end)

task.spawn(function()
	local bosses = workspace:WaitForChild("AuraFarmBosses")
	local function refresh()
		local model = bosses:FindFirstChildWhichIsA("Model")
		hud.setBoss(model)
	end
	bosses.ChildAdded:Connect(refresh)
	bosses.ChildRemoved:Connect(refresh)
	refresh()
end)

-- Your movement animations, on every spawn.
player.CharacterAdded:Connect(function(character)
	AnimationPlayer.applyMovement(character)
end)
if player.Character then
	task.spawn(AnimationPlayer.applyMovement, player.Character)
end

-- Class: update the HUD when it changes, and open the picker for new
-- players once their save has loaded.
local function onClassChanged()
	local class = Classes.get(player:GetAttribute("ClassId"))
	hud.setClass(class)
	if class then
		picker.close()
	end
end
player:GetAttributeChangedSignal("ClassId"):Connect(onClassChanged)
onClassChanged()

local function onLoaded()
	if player:GetAttribute("Loaded") and player:GetAttribute("ClassId") == nil and not picker.isOpen() then
		picker.open(nil)
	end
end
player:GetAttributeChangedSignal("Loaded"):Connect(onLoaded)
onLoaded()

NotifyRemote.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.Kind == "Aura" then
		hud.popup(payload)
	elseif payload.Kind == "Banner" then
		hud.banner(payload.Title, payload.Lines, payload.Total, rgb(payload.Color))
	elseif payload.Kind == "RankUp" then
		-- Not a banner: a rank up usually lands together with a boss banner.
		hud.announce("RANK UP!  You are now a " .. payload.Rank, rgb(payload.Color))
	elseif payload.Kind == "Message" then
		hud.announce(payload.Text, Color3.fromRGB(255, 160, 160))
	elseif payload.Kind == "Announce" then
		hud.announce(payload.Text)
	elseif payload.Kind == "PickClass" then
		if not picker.isOpen() then
			picker.open(player:GetAttribute("ClassId"))
		end
	elseif payload.Kind == "ClassChosen" then
		picker.close()
	elseif payload.Kind == "Rush" and type(payload.Distance) == "number" then
		-- The Rush ultimate: carry the character along the line it hit.
		local _, _, root = liveCharacter()
		local direction = root and flatUnit(root.CFrame.LookVector)
		if direction then
			local duration = 0.3
			lunge(direction, payload.Distance / duration, duration)
		end
	elseif payload.Kind == "Dash" and payload.UserId ~= player.UserId then
		-- Someone else dashed: draw their avatar afterimages here too.
		local dasher = Players:GetPlayerByUserId(payload.UserId)
		local character = dasher and dasher.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if dasher and character and root and root:IsA("BasePart") then
			Afterimages.trail(character, Config.Combat.DashDuration + 0.1)
			dashEffect(dasher, root, flatUnit(root.CFrame.LookVector) or Vector3.new(0, 0, -1))
		end
	end
end)
