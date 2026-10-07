-- Server-side visuals that need to stick to a character (so every player sees
-- them and they move with it): power auras and barrier bubbles.

local Visuals = {}

local function sequence(color: Color3)
	return ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.5))
end

-- Adds an aura to a character's root part. `scale` makes it bigger (used by
-- Power Up). Returns the created instances so the caller can remove them.
function Visuals.makeAura(root: BasePart, style: string, color: Color3, scale: number?): { Instance }
	local s = scale or 1
	local created = {}

	local light = Instance.new("PointLight")
	light.Name = "PowerAuraLight"
	light.Color = color
	light.Range = 8 * s
	light.Brightness = 1.5
	light.Parent = root
	table.insert(created, light)

	if style == "None" then
		return created
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PowerAura"
	emitter.Color = sequence(color)
	emitter.LightEmission = 0.8
	emitter.LockedToPart = false
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Parent = root

	if style == "Flames" then
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.6 * s),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new(0.3, 1)
		emitter.Lifetime = NumberRange.new(0.5, 0.9)
		emitter.Rate = 40 * s
		emitter.Speed = NumberRange.new(4, 8)
		emitter.Acceleration = Vector3.new(0, 8, 0)
		emitter.Shape = Enum.ParticleEmitterShape.Box
	elseif style == "Sparkles" then
		emitter.Size = NumberSequence.new(0.35 * s)
		emitter.Transparency = NumberSequence.new(0, 1)
		emitter.Lifetime = NumberRange.new(0.6, 1.2)
		emitter.Rate = 30 * s
		emitter.Speed = NumberRange.new(2, 6)
		emitter.SpreadAngle = Vector2.new(180, 180)
	elseif style == "Smoke" then
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 * s),
			NumberSequenceKeypoint.new(1, 3 * s),
		})
		emitter.Transparency = NumberSequence.new(0.5, 1)
		emitter.LightEmission = 0.1
		emitter.Lifetime = NumberRange.new(1, 1.6)
		emitter.Rate = 18 * s
		emitter.Speed = NumberRange.new(1, 3)
		emitter.Acceleration = Vector3.new(0, 3, 0)
	else -- Glow
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 3 * s),
			NumberSequenceKeypoint.new(1, 5 * s),
		})
		emitter.Transparency = NumberSequence.new(0.75, 1)
		emitter.Lifetime = NumberRange.new(0.4, 0.6)
		emitter.Rate = 12 * s
		emitter.Speed = NumberRange.new(0, 0.5)
	end

	table.insert(created, emitter)
	return created
end

-- A see-through bubble welded around a character, used by Barrier.
function Visuals.makeBubble(root: BasePart, color: Color3, size: number): BasePart
	local bubble = Instance.new("Part")
	bubble.Name = "BarrierBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.one * size
	bubble.Material = Enum.Material.ForceField
	bubble.Color = color
	bubble.Transparency = 0.1
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.CastShadow = false
	bubble.Massless = true
	bubble.CFrame = root.CFrame

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = bubble
	weld.Parent = bubble

	bubble.Parent = root.Parent
	return bubble
end

return Visuals
