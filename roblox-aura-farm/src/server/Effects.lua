-- Visuals built from plain parts (no uploaded assets needed): attack
-- telegraphs, slashes, explosions, the hero blade, aura particles and the
-- overhead name tag.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = {}

local folder = Instance.new("Folder")
folder.Name = "AuraFarmEffects"
folder.Parent = workspace

function Effects.color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	-- Shape first: changing it afterwards can reshape the part's Size.
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in pairs(props) do
		if key ~= "Shape" and key ~= "Parent" then
			p[key] = value
		end
	end
	p.Parent = props.Parent or folder
	return p
end
Effects.part = part

local function fade(p: BasePart, duration: number, goal)
	goal = goal or {}
	goal.Transparency = 1
	TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, duration + 0.1)
end

-- A flat disc lying on the ground (cylinders point along X, so roll 90 degrees).
local function flatDiscCFrame(position: Vector3): CFrame
	return CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

---------------------------------------------------------------------------
-- Attack telegraphs: a red outline plus a fill that grows until impact.
---------------------------------------------------------------------------

function Effects.telegraphCircle(position: Vector3, radius: number, duration: number)
	local outline = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, radius * 2, radius * 2),
		CFrame = flatDiscCFrame(position),
		Color = Color3.fromRGB(255, 40, 40),
		Transparency = 0.75,
	})
	local fill = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 0.5, 0.5),
		CFrame = flatDiscCFrame(position + Vector3.new(0, 0.02, 0)),
		Color = Color3.fromRGB(255, 90, 40),
		Transparency = 0.4,
	})
	TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.15, radius * 2, radius * 2),
	}):Play()
	Debris:AddItem(outline, duration)
	Debris:AddItem(fill, duration)
end

-- origin is on the ground, direction is a flat unit vector.
function Effects.telegraphRect(origin: Vector3, direction: Vector3, length: number, width: number, duration: number)
	local centre = origin + direction * (length / 2)
	local cframe = CFrame.lookAt(centre, centre + direction)
	local outline = part({
		Size = Vector3.new(width, 0.1, length),
		CFrame = cframe,
		Color = Color3.fromRGB(255, 40, 40),
		Transparency = 0.75,
	})
	local fill = part({
		Size = Vector3.new(width, 0.15, 0.5),
		CFrame = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0.02, -0.25),
		Color = Color3.fromRGB(255, 90, 40),
		Transparency = 0.4,
	})
	TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = Vector3.new(width, 0.15, length),
		CFrame = cframe * CFrame.new(0, 0.02, 0),
	}):Play()
	Debris:AddItem(outline, duration)
	Debris:AddItem(fill, duration)
end

---------------------------------------------------------------------------
-- Impacts
---------------------------------------------------------------------------

function Effects.shockwave(position: Vector3, radius: number, color: Color3)
	local ring = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2, 2),
		CFrame = flatDiscCFrame(position + Vector3.new(0, 0.1, 0)),
		Color = color,
		Transparency = 0.2,
	})
	fade(ring, 0.45, { Size = Vector3.new(0.3, radius * 2.2, radius * 2.2) })
end

function Effects.burst(position: Vector3, radius: number, color: Color3, duration: number?)
	local ball = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1,
		Position = position,
		Color = color,
		Transparency = 0.1,
	})
	fade(ball, duration or 0.4, { Size = Vector3.one * radius * 2 })
end

-- A crescent-ish neon streak in front of the attacker.
function Effects.slash(rootCFrame: CFrame, color: Color3)
	local roll = math.rad(math.random(-50, 50))
	local streak = part({
		Size = Vector3.new(9, 0.25, 1.4),
		CFrame = rootCFrame * CFrame.new(0, 0.5, -4.5) * CFrame.Angles(0, 0, roll),
		Color = color,
		Transparency = 0.15,
	})
	fade(streak, 0.18, { Size = Vector3.new(12, 0.1, 0.3) })
end

-- The ultimate: a column of light slamming down on the target.
function Effects.pillar(position: Vector3, color: Color3)
	local height = 120
	local column = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 14, 14),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.1,
	})
	fade(column, 0.8, { Size = Vector3.new(height, 1, 1) })
	Effects.burst(position, 22, Color3.new(1, 1, 1), 0.6)
	Effects.shockwave(position, 30, color)
end

-- Unanchor every part of a model and throw them outwards.
function Effects.explodeModel(model: Model, color: Color3)
	local centre = model:GetPivot().Position
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = true
			local away = (descendant.Position - centre)
			if away.Magnitude < 0.1 then
				away = Vector3.new(0, 1, 0)
			end
			descendant.AssemblyLinearVelocity = away.Unit * math.random(40, 80) + Vector3.new(0, math.random(30, 60), 0)
		elseif descendant:IsA("BillboardGui") then
			descendant:Destroy()
		end
	end
	Effects.burst(centre, 30, color, 0.8)
	Effects.burst(centre, 18, Color3.new(1, 1, 1), 0.5)
	Effects.shockwave(Vector3.new(centre.X, centre.Y - 6, centre.Z), 45, color)
	Debris:AddItem(model, 4)
end

---------------------------------------------------------------------------
-- The hero blade, welded to the right hand (R15) or right arm (R6).
---------------------------------------------------------------------------

function Effects.buildSword(character: Model)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("HeroBlade")
	if old then
		old:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "HeroBlade"

	local function swordPart(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.CFrame = hand.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = hand
		weld.Part1 = p
		weld.C0 = offset
		weld.Parent = p
		p.Parent = model
		return p
	end

	-- Grip sits at the bottom of the hand, blade points forward.
	local base = CFrame.new(0, -hand.Size.Y / 2, 0)
	swordPart("Grip", Vector3.new(0.3, 0.3, 1.1), base, Color3.fromRGB(40, 30, 30), Enum.Material.Fabric)
	swordPart("Guard", Vector3.new(1.3, 0.25, 0.25), base * CFrame.new(0, 0, -0.65), Color3.fromRGB(230, 190, 60), Enum.Material.Metal)
	swordPart("Blade", Vector3.new(0.35, 0.12, 4), base * CFrame.new(0, 0, -2.75), Color3.fromRGB(210, 235, 255), Enum.Material.Neon)

	model.Parent = character
end

---------------------------------------------------------------------------
-- Aura particles around the hero. Brighter and denser at higher ranks.
---------------------------------------------------------------------------

function Effects.setAura(character: Model, rankIndex: number, color: Color3)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local attachment = root:FindFirstChild("AuraAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "AuraAttachment"
		attachment.Position = Vector3.new(0, -1.5, 0)
		attachment.Parent = root

		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Aura"
		emitter.LightEmission = 1
		emitter.Lifetime = NumberRange.new(0.6, 1.1)
		emitter.Speed = NumberRange.new(4, 7)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.Acceleration = Vector3.new(0, 6, 0)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Parent = attachment

		local light = Instance.new("PointLight")
		light.Name = "AuraLight"
		light.Range = 10
		light.Parent = attachment
	end

	local emitter = attachment:FindFirstChild("Aura") :: ParticleEmitter
	local light = attachment:FindFirstChild("AuraLight") :: PointLight
	emitter.Color = ColorSequence.new(color)
	-- NPCs (rank 1) get no visible aura; it grows from there.
	emitter.Rate = if rankIndex <= 1 then 0 else (rankIndex - 1) * 8
	light.Color = color
	light.Brightness = if rankIndex <= 1 then 0 else 0.4 * (rankIndex - 1)
end

---------------------------------------------------------------------------
-- Overhead tag: rank, aura, and the heroic line you just said.
---------------------------------------------------------------------------

local function label(parent: Instance, name: string, position: UDim2, size: UDim2, textSize: number)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = position
	l.Size = size
	l.Font = Enum.Font.GothamBlack
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.TextWrapped = true
	l.Text = ""
	l.Parent = parent
	return l
end

function Effects.buildOverhead(character: Model): BillboardGui?
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "AuraTag"
	gui.Size = UDim2.fromOffset(320, 130)
	gui.StudsOffset = Vector3.new(0, 4.2, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	label(gui, "Speech", UDim2.fromOffset(0, 0), UDim2.fromOffset(320, 70), 20)
	label(gui, "Rank", UDim2.fromOffset(0, 72), UDim2.fromOffset(320, 30), 22)
	label(gui, "Aura", UDim2.fromOffset(0, 100), UDim2.fromOffset(320, 26), 16)
	gui.Parent = head
	return gui
end

function Effects.updateOverhead(character: Model, rankName: string, color: Color3, aura: number)
	local head = character:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("AuraTag")
	if not gui then
		return
	end
	local rank = gui:FindFirstChild("Rank") :: TextLabel
	rank.Text = rankName
	rank.TextColor3 = color
	local auraLabel = gui:FindFirstChild("Aura") :: TextLabel
	auraLabel.Text = string.format("%d aura", aura)
end

-- Only ever shows lines from Config (never raw player text), so nothing
-- unfiltered is displayed to other players.
function Effects.showSpeech(character: Model, text: string, duration: number)
	local head = character:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("AuraTag")
	if not gui then
		return
	end
	local speech = gui:FindFirstChild("Speech") :: TextLabel
	speech.Text = "\u{201C}" .. text .. "\u{201D}"
	speech.TextColor3 = Color3.fromRGB(255, 240, 160)
	local stamp = os.clock()
	speech:SetAttribute("Stamp", stamp)
	task.delay(duration, function()
		if speech.Parent and speech:GetAttribute("Stamp") == stamp then
			speech.Text = ""
		end
	end)
end

return Effects
