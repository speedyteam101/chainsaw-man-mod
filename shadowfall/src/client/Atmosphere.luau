--!nonstrict
-- Local lighting and world animation: per-act mood, flickering street lamps, blinking beacons,
-- bobbing wisps, the pulsing Heart of Shadow, telegraph fills, and level gates.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)

local Atmosphere = {}

local player = Players.LocalPlayer
local rng = Random.new()

local function ensure(className: string, name: string, parent: Instance)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local atmosphere = ensure("Atmosphere", "ShadowAtmosphere", Lighting) :: Atmosphere
local grade = ensure("ColorCorrectionEffect", "ShadowGrade", Lighting) :: ColorCorrectionEffect
local bloom = ensure("BloomEffect", "ShadowBloom", Lighting) :: BloomEffect
local sky = Lighting:FindFirstChildOfClass("Sky") or ensure("Sky", "ShadowSky", Lighting) :: Sky
sky.CelestialBodiesShown = false
sky.StarCount = 0
Atmosphere.Grade = grade

local PRESETS = {
	[1] = {
		lighting = { Ambient = Color3.fromRGB(8, 8, 12), OutdoorAmbient = Color3.fromRGB(14, 14, 20), Brightness = 0, ClockTime = 0, ExposureCompensation = -0.2, EnvironmentDiffuseScale = 0, EnvironmentSpecularScale = 0 },
		atmosphere = { Density = 0.52, Offset = 0, Color = Color3.fromRGB(8, 7, 12), Decay = Color3.fromRGB(0, 0, 0), Glare = 0, Haze = 2.2 },
		grade = { Saturation = -0.55, Contrast = 0.18, Brightness = 0, TintColor = Color3.fromRGB(215, 220, 235) },
		bloom = { Intensity = 0.4, Size = 20, Threshold = 1.8 },
	},
	[2] = {
		lighting = { Ambient = Color3.fromRGB(34, 28, 46), OutdoorAmbient = Color3.fromRGB(44, 36, 62), Brightness = 0.6, ClockTime = 0, ExposureCompensation = 0, EnvironmentDiffuseScale = 0.3, EnvironmentSpecularScale = 0.3 },
		atmosphere = { Density = 0.33, Offset = 0.1, Color = Color3.fromRGB(32, 22, 48), Decay = Color3.fromRGB(70, 34, 100), Glare = 0, Haze = 1.6 },
		grade = { Saturation = -0.12, Contrast = 0.12, Brightness = 0, TintColor = Color3.fromRGB(235, 225, 255) },
		bloom = { Intensity = 0.7, Size = 24, Threshold = 1.5 },
	},
	dawn = {
		lighting = { Ambient = Color3.fromRGB(90, 70, 60), OutdoorAmbient = Color3.fromRGB(150, 110, 90), Brightness = 2, ClockTime = 6.4, ExposureCompensation = 0.2, EnvironmentDiffuseScale = 0.6, EnvironmentSpecularScale = 0.6 },
		atmosphere = { Density = 0.25, Offset = 0.2, Color = Color3.fromRGB(255, 190, 140), Decay = Color3.fromRGB(255, 140, 90), Glare = 0.6, Haze = 1.2 },
		grade = { Saturation = 0.15, Contrast = 0.05, Brightness = 0.05, TintColor = Color3.fromRGB(255, 235, 215) },
		bloom = { Intensity = 1, Size = 30, Threshold = 1.2 },
	},
}

-- Act 2 horror: darker versions of the Act 2 preset for outside the camp/base and for the
-- Blackout, derived from preset 2 so brightening preset 2 brightens these too.
-- Config.Horror.Darkness (0..1) sets how dark.
local function darkened(base, amount: number)
	local out = { lighting = table.clone(base.lighting), atmosphere = table.clone(base.atmosphere), grade = table.clone(base.grade), bloom = table.clone(base.bloom) }
	local black = Color3.new(0, 0, 0)
	out.lighting.Ambient = base.lighting.Ambient:Lerp(black, amount * 0.6)
	out.lighting.OutdoorAmbient = base.lighting.OutdoorAmbient:Lerp(black, amount * 0.65)
	out.lighting.Brightness = base.lighting.Brightness * (1 - amount * 0.7)
	out.lighting.ExposureCompensation = base.lighting.ExposureCompensation - amount * 0.6
	out.atmosphere.Density = math.min(0.75, base.atmosphere.Density + amount * 0.22)
	out.atmosphere.Haze = base.atmosphere.Haze + amount * 1.2
	out.atmosphere.Color = base.atmosphere.Color:Lerp(black, amount * 0.5)
	out.grade.Saturation = base.grade.Saturation - amount * 0.3
	out.grade.Contrast = base.grade.Contrast + amount * 0.1
	return out
end
local darkness = math.clamp(Config.Horror.Darkness, 0, 1)
PRESETS["2dark"] = darkened(PRESETS[2], darkness)
PRESETS.blackout = darkened(PRESETS[2], math.min(1, darkness + 0.45))
PRESETS.blackout.grade.TintColor = Color3.fromRGB(200, 205, 230)

Atmosphere.Current = nil

function Atmosphere.Apply(presetKey, time: number?)
	local preset = PRESETS[presetKey]
	if not preset then
		return
	end
	Atmosphere.Current = presetKey
	local t = time or 2
	for key, value in preset.lighting do
		if typeof(value) == "number" and key ~= "ClockTime" then
			Ui.tween(Lighting, t, { [key] = value })
		else
			(Lighting :: any)[key] = value
		end
	end
	Ui.tween(atmosphere, t, preset.atmosphere)
	Ui.tween(grade, t, preset.grade)
	Ui.tween(bloom, t, preset.bloom)
end

-- Gates -------------------------------------------------------------------------------------

local function refreshGates()
	local level = player:GetAttribute("Level") or 1
	for _, barrier in CollectionService:GetTagged("AreaGate") do
		local open = level >= (barrier:GetAttribute("Level") or 99) and player:GetAttribute("Act") == 2
		barrier.CanCollide = not open
		barrier.Transparency = open and 0.9 or 0.1
		local gui = barrier:FindFirstChildOfClass("BillboardGui")
		if gui then
			gui.Enabled = not open
		end
	end
end

-- Animated world bits ----------------------------------------------------------------------

local flickers = {} -- [Light] = base brightness
local blinkers = {}
local bobbers = {} -- [BasePart] = { base = CFrame, phase = number }
local pulsers = {}
local hearts = {}

local function track(tag: string, onAdd: (Instance) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		onAdd(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onAdd)
end

local function startTelegraph(part: Part)
	local duration = part:GetAttribute("Duration") or 1
	local fill = part:Clone()
	CollectionService:RemoveTag(fill, "Telegraph")
	fill.Name = "TelegraphFill"
	fill.Transparency = 0.45
	local fullSize = part.Size
	local isCircle = part.Shape == Enum.PartType.Cylinder
	if isCircle then
		fill.Size = Vector3.new(fullSize.X + 0.02, 0.1, 0.1)
	else
		fill.Size = Vector3.new(fullSize.X, fullSize.Y + 0.02, 0.1)
		fill.CFrame = part.CFrame * CFrame.new(0, 0, fullSize.Z / 2)
	end
	fill.Parent = workspace
	if isCircle then
		Ui.tween(fill, duration, { Size = Vector3.new(fullSize.X + 0.02, fullSize.Y, fullSize.Z) }, Enum.EasingStyle.Linear)
	else
		Ui.tween(fill, duration, { Size = Vector3.new(fullSize.X, fullSize.Y + 0.02, fullSize.Z), CFrame = part.CFrame }, Enum.EasingStyle.Linear)
	end
	task.delay(duration + 0.05, function()
		fill:Destroy()
	end)
end

function Atmosphere.Start()
	Atmosphere.Apply(player:GetAttribute("Act") == 2 and 2 or 1, 0)
	player:GetAttributeChangedSignal("Act"):Connect(function()
		Atmosphere.Apply(player:GetAttribute("Act") == 2 and 2 or 1, 3)
		refreshGates()
	end)
	player:GetAttributeChangedSignal("Level"):Connect(refreshGates)
	track("AreaGate", function()
		refreshGates()
	end)

	track("FlickerLight", function(part)
		for _, light in part:GetChildren() do
			if light:IsA("Light") then
				flickers[light] = light.Brightness
			end
		end
	end)
	track("Blink", function(part)
		table.insert(blinkers, part)
	end)
	track("Bob", function(part)
		bobbers[part] = { base = part.CFrame, phase = rng:NextNumber(0, math.pi * 2) }
	end)
	track("Pulse", function(part)
		table.insert(pulsers, part)
	end)
	track("Heartbeat", function(part)
		table.insert(hearts, { part = part, base = part.Size })
	end)
	track("Telegraph", function(part)
		if part:IsA("Part") then
			startTelegraph(part)
		end
	end)

	-- Flicker: every so often a light stutters or drops out briefly.
	task.spawn(function()
		while true do
			task.wait(0.08)
			for light, base in flickers do
				if not light.Parent then
					flickers[light] = nil
				elseif rng:NextNumber() < 0.04 then
					local out = rng:NextNumber() < 0.35
					light.Brightness = out and 0 or base * rng:NextNumber(0.3, 0.8)
					local bulb = light.Parent
					if bulb:IsA("BasePart") and out then
						bulb.Transparency = 0.7
					end
					task.delay(rng:NextNumber(0.05, 0.25), function()
						light.Brightness = base
						if bulb:IsA("BasePart") then
							bulb.Transparency = 0
						end
					end)
				end
			end
		end
	end)

	local elapsed = 0
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		accumulator += dt
		if accumulator < 1 / 30 then
			return
		end
		accumulator = 0
		for part, info in bobbers do
			if not part.Parent then
				bobbers[part] = nil
			else
				part.CFrame = info.base * CFrame.new(0, math.sin(elapsed * 1.4 + info.phase) * 0.8, 0)
			end
		end
		local blinkOn = math.floor(elapsed) % 2 == 0
		for _, part in blinkers do
			part.Transparency = blinkOn and 0 or 0.9
			local light = part:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = blinkOn
			end
		end
		local beat = math.max(0, math.sin(elapsed * 4)) ^ 6
		for _, part in pulsers do
			part.Transparency = 0.6 - beat * 0.6
		end
		for _, heart in hearts do
			heart.part.Size = heart.base * (1 + beat * 0.06)
		end
	end)
end

return Atmosphere
