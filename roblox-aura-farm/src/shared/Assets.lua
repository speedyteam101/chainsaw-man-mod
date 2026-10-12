--[[
	Finds your models in ReplicatedStorage.AuraFarmAssets (the `assets/`
	folder in the Rojo project) and spawns effect models.

	Layout (every entry is optional; anything missing uses the built-in look):
		AuraFarmAssets/
			Sword                  the sword everyone holds
			Effects/<Name>         effect models, see Assets.EffectNames
			Sides/Good/...         same layout, used by heroes
			Sides/Evil/...         same layout, used by villains
			Classes/<ClassId>/...  same layout, used by one class

	A class's own entry wins over its side's, which wins over the shared one.

	Recolouring: any part, ParticleEmitter, Trail, Beam or light with the
	attribute ClassColor = true is painted in the class's colour (or the
	effect's colour).

	Effect attributes (set on the effect model itself, all optional):
		Lifetime   number  seconds before it's removed (default 1.5)
		BaseRadius number  the radius it was built at; it's scaled to fit
		                   the real size (e.g. a Nova's blast radius)
	ParticleEmitter attribute:
		EmitCount  number  burst this many particles when it spawns
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = {}

-- Every effect the game looks for, and where it's placed.
Assets.EffectNames = {
	Slash = "In front of the attacker on each slash, facing the way they face",
	Hit = "On whoever a slash hits",
	Dash = "Where a dash starts, facing the dash direction",
	UltimatePillar = "On the Pillar target",
	UltimateNova = "Around the caster (scaled to the blast radius)",
	UltimateRush = "At the start of the rush line, facing along it",
	UltimateDrain = "Around the caster (scaled to the drain radius)",
	UltimateMend = "Around the caster (scaled to the heal radius)",
	UltimateFortify = "Around the caster (scaled to the shield radius)",
}

local function root(): Instance?
	return ReplicatedStorage:FindFirstChild("AuraFarmAssets")
end

local function walk(from: Instance?, path: { string }): Instance?
	local current = from
	for _, name in ipairs(path) do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

-- The most specific asset at `path` for this class / side, or nil.
function Assets.find(path: { string }, classId: string?, side: string?): Instance?
	local base = root()
	if not base then
		return nil
	end
	if classId then
		local found = walk(walk(base, { "Classes", classId }), path)
		if found then
			return found
		end
	end
	if side then
		local found = walk(walk(base, { "Sides", side }), path)
		if found then
			return found
		end
	end
	return walk(base, path)
end

-- Paints everything marked ClassColor = true (including `instance` itself).
function Assets.recolor(instance: Instance, color: Color3)
	local items = instance:GetDescendants()
	table.insert(items, instance)
	for _, item in ipairs(items) do
		if item:GetAttribute("ClassColor") == true then
			if item:IsA("BasePart") or item:IsA("Light") then
				item.Color = color
			elseif item:IsA("ParticleEmitter") or item:IsA("Trail") or item:IsA("Beam") then
				item.Color = ColorSequence.new(color)
			end
		end
	end
end

local function allParts(instance: Instance): { BasePart }
	local parts = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, item in ipairs(instance:GetDescendants()) do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end
	return parts
end
Assets.allParts = allParts

--[[
	Spawns the effect model `name` at `cframe` if you've added one.
	options = { classId, side, color, radius, parent }
	Returns true if a custom effect was spawned (so the caller can skip its
	built-in effect).
]]
function Assets.spawnEffect(name: string, cframe: CFrame, options): boolean
	local template = Assets.find({ "Effects", name }, options.classId, options.side)
	if not template or not (template:IsA("Model") or template:IsA("BasePart")) then
		return false
	end
	local effect = template:Clone()
	for _, part in ipairs(allParts(effect)) do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end

	local baseRadius = effect:GetAttribute("BaseRadius")
	local scale = if type(baseRadius) == "number" and baseRadius > 0 and options.radius
		then options.radius / baseRadius
		else 1

	if effect:IsA("Model") then
		if scale ~= 1 then
			effect:ScaleTo(effect:GetScale() * scale)
		end
		effect:PivotTo(cframe)
	elseif effect:IsA("BasePart") then
		effect.Size *= scale
		effect.CFrame = cframe
	end

	if options.color then
		Assets.recolor(effect, options.color)
	end
	effect.Parent = options.parent or workspace

	for _, item in ipairs(effect:GetDescendants()) do
		local count = item:GetAttribute("EmitCount")
		if item:IsA("ParticleEmitter") and type(count) == "number" then
			item:Emit(count)
		end
	end
	local lifetime = effect:GetAttribute("Lifetime")
	Debris:AddItem(effect, if type(lifetime) == "number" then lifetime else 1.5)
	return true
end

return Assets
