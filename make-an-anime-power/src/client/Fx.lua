-- Draws the visual effects the server sends through the Fx remote. Everything
-- here is client-only decoration: hits are decided on the server.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Fx = {}

local player = Players.LocalPlayer
local folder: Folder
local projectiles = {} -- [id] = { part, origin, direction, speed, range, started }

local function neon(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Shape" then
			(p :: any)[key] = value
		end
	end
	p.Parent = folder
	return p
end

local function tween(instance: Instance, seconds: number, goal, style: Enum.EasingStyle?)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

local function isNear(position: Vector3, distance: number): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= distance
end

----------------------------------------------------------------------
-- Effects
----------------------------------------------------------------------

local Handlers = {}

local function burst(position: Vector3, radius: number, color: Color3, seconds: number?)
	local duration = seconds or 0.35
	local sphere = neon({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one,
		Color = color,
		Transparency = 0.15,
		CFrame = CFrame.new(position),
	})
	tween(sphere, duration, { Size = Vector3.one * radius * 2, Transparency = 1 })
	Debris:AddItem(sphere, duration + 0.05)

	local ring = neon({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 1, 1),
		Color = color:Lerp(Color3.new(1, 1, 1), 0.4),
		Transparency = 0.2,
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
	})
	tween(ring, duration * 1.3, { Size = Vector3.new(0.3, radius * 2.6, radius * 2.6), Transparency = 1 })
	Debris:AddItem(ring, duration * 1.3 + 0.05)
end

function Handlers.Burst(info)
	burst(info.position, info.radius, info.color)
end

function Handlers.Projectile(info)
	local radius = info.radius
	local part = neon({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 2,
		Color = info.color,
		CFrame = CFrame.new(info.origin),
	})

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, radius * 0.6, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -radius * 0.6, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(info.color)
	trail.LightEmission = 1
	trail.Lifetime = 0.25
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = part

	local light = Instance.new("PointLight")
	light.Color = info.color
	light.Range = 6 + radius * 3
	light.Parent = part

	projectiles[info.id] = {
		part = part,
		origin = info.origin,
		direction = info.direction,
		speed = info.speed,
		range = info.range,
		started = os.clock(),
	}
end

function Handlers.ProjectileEnd(info)
	local projectile = projectiles[info.id]
	if projectile then
		projectiles[info.id] = nil
		projectile.part:Destroy()
	end
	burst(info.position, info.radius, info.color, 0.3)
end

function Handlers.Beam(info)
	local from, to = info.from, info.to
	local length = (to - from).Magnitude
	local middle = (from + to) / 2
	-- Cylinders point along X; turn X to face along the beam
	local cframe = CFrame.lookAt(middle, to) * CFrame.Angles(0, math.rad(90), 0)

	local outer = neon({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, info.width, info.width),
		Color = info.color,
		Transparency = 0.25,
		CFrame = cframe,
	})
	local core = neon({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, info.width * 0.45, info.width * 0.45),
		Color = Color3.new(1, 1, 1),
		Transparency = 0,
		CFrame = cframe,
	})
	tween(outer, 0.5, { Size = Vector3.new(length, 0.1, 0.1), Transparency = 1 })
	tween(core, 0.4, { Size = Vector3.new(length, 0.05, 0.05), Transparency = 1 })
	Debris:AddItem(outer, 0.55)
	Debris:AddItem(core, 0.45)
	burst(to, info.width * 1.5, info.color)
end

function Handlers.Warning(info)
	local circle = neon({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, info.radius * 2, info.radius * 2),
		Color = info.color,
		Transparency = 0.65,
		CFrame = CFrame.new(info.position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	tween(circle, info.duration, { Transparency = 0.3 }, Enum.EasingStyle.Linear)
	Debris:AddItem(circle, info.duration)
end

function Handlers.Slash(info)
	local reach = info.reach
	local blade = neon({
		Size = Vector3.new(0.3, info.small and 0.6 or 1.4, reach),
		Color = info.color,
		Transparency = 0.1,
		CFrame = info.cframe,
	})
	local tilt = CFrame.Angles(0, 0, math.rad(info.flip and -25 or 25))
	local from, to = -70, 70
	if info.flip then
		from, to = to, from
	end
	local duration = info.small and 0.12 or 0.16
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.min((os.clock() - started) / duration, 1)
		local angle = math.rad(from + (to - from) * alpha)
		blade.CFrame = info.cframe * tilt * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -reach / 2)
		blade.Transparency = 0.1 + 0.9 * alpha * alpha
		if alpha >= 1 then
			connection:Disconnect()
			blade:Destroy()
		end
	end)
end

function Handlers.Dash(info)
	local from, to = info.from, info.to
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local streak = neon({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, info.width * 0.6, info.width * 0.6),
		Color = info.color,
		Transparency = 0.4,
		CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0),
	})
	tween(streak, 0.45, { Transparency = 1, Size = Vector3.new(length, 0.1, 0.1) })
	Debris:AddItem(streak, 0.5)
end

function Handlers.Teleport(info)
	burst(info.from, 4, info.color)
	burst(info.to, 4, info.color)
end

function Handlers.Heal(info)
	burst(info.position, 5, Color3.fromRGB(120, 255, 140))
	local holder = neon({
		Size = Vector3.one,
		Transparency = 1,
		CFrame = CFrame.new(info.position),
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(140, 255, 150))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.4, 0)
	emitter.Lifetime = NumberRange.new(0.8, 1.2)
	emitter.Speed = NumberRange.new(4, 8)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(30)
	Debris:AddItem(holder, 1.5)
end

-- Floating text above a character or a point
local function floatingText(adornee: Instance, text: string, color: Color3, size: number, rise: number, seconds: number)
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(300, size)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 150

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	tween(gui, seconds, { StudsOffset = Vector3.new(0, 3 + rise, 0) })
	tween(label, seconds, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(gui, seconds)
end

function Handlers.Shout(info)
	local character = info.character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") or not isNear(head.Position, 150) then
		return
	end
	floatingText(head, string.upper(info.text) .. "!", info.color, 42, 1.5, 1.4)
end

function Handlers.Damage(info)
	if not isNear(info.position, 120) then
		return
	end
	local anchor = neon({
		Size = Vector3.one * 0.1,
		Transparency = 1,
		CFrame = CFrame.new(info.position + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)),
	})
	Debris:AddItem(anchor, 1)
	local text = info.blocked and "BLOCKED" or tostring(info.amount)
	floatingText(anchor, text, info.blocked and Color3.fromRGB(180, 220, 255) or info.color, 28, 2.5, 0.9)
end

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------

function Fx.getFolder(): Folder
	return folder
end

function Fx.init(fxRemote: RemoteEvent)
	folder = Instance.new("Folder")
	folder.Name = "LocalFx"
	folder.Parent = workspace

	fxRemote.OnClientEvent:Connect(function(kind, info)
		local handler = Handlers[kind]
		if handler and type(info) == "table" then
			local ok, err = pcall(handler, info)
			if not ok then
				warn("[Fx]", kind, err)
			end
		end
	end)

	-- Move projectiles along their path
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for id, projectile in projectiles do
			local age = now - projectile.started
			local distance = math.min(projectile.speed * age, projectile.range)
			projectile.part.CFrame = CFrame.new(projectile.origin + projectile.direction * distance)
			-- Safety net in case the end message is missed
			if age > 10 or projectile.speed * age >= projectile.range + 30 then
				projectiles[id] = nil
				projectile.part:Destroy()
			end
		end
	end)
end

return Fx
