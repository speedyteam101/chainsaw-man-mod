-- Aura Farm client: input (slash / dash / ultimate), the dash movement,
-- forwarding chat to the server, and feeding the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("AuraFarmRemotes")
local ActionRemote = remotes:WaitForChild("Action") :: RemoteEvent
local ShoutRemote = remotes:WaitForChild("Shout") :: RemoteEvent
local NotifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent

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

local function afterimage(root: BasePart)
	local ghost = Instance.new("Part")
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.CastShadow = false
	ghost.Material = Enum.Material.Neon
	ghost.Color = Color3.fromRGB(150, 255, 190)
	ghost.Transparency = 0.5
	ghost.Size = Vector3.new(2, 4.5, 1)
	ghost.CFrame = root.CFrame
	ghost.Parent = workspace
	TweenService:Create(ghost, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	task.delay(0.35, function()
		ghost:Destroy()
	end)
end

local function slash()
	local now = os.clock()
	if now - lastSlash < Config.Combat.SlashCooldown or not liveCharacter() then
		return
	end
	lastSlash = now
	ActionRemote:FireServer("Slash")
	hud.cooldown("Slash", Config.Combat.SlashCooldown)
end

local function dash()
	local now = os.clock()
	if now - lastDash < Config.Combat.DashCooldown then
		return
	end
	local _, humanoid, root = liveCharacter()
	if not humanoid then
		return
	end
	lastDash = now
	ActionRemote:FireServer("Dash")
	hud.cooldown("Dash", Config.Combat.DashCooldown)

	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.1 then
		return
	end
	direction = direction.Unit
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)

	local speed = Config.Combat.DashSpeed
	local elapsed, sinceGhost = 0, 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		sinceGhost += dt
		if elapsed >= Config.Combat.DashDuration or not root.Parent then
			connection:Disconnect()
			return
		end
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(direction.X * speed, math.max(velocity.Y, 0), direction.Z * speed)
		if sinceGhost >= 0.04 then
			sinceGhost = 0
			afterimage(root)
		end
	end)
end

local function ultimate()
	local now = os.clock()
	if now - lastUltimate < Config.Combat.UltimateCooldown or not liveCharacter() then
		return
	end
	lastUltimate = now
	ActionRemote:FireServer("Ultimate")
	hud.cooldown("Ultimate", Config.Combat.UltimateCooldown)
end

local ACTIONS = { Slash = slash, Dash = dash, Ultimate = ultimate }

hud = Hud.new(player:WaitForChild("PlayerGui") :: PlayerGui, {
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
	end
end)
