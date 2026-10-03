--!nonstrict
-- Character customisation: the choices in the character creator, how a look turns into body
-- colours, and the blocky part-built hairstyles. Shared so the server (real character) and the
-- client (the creator's preview) build exactly the same thing.
--
-- A look is a small table of indexes into the palettes below, so it is cheap to save and easy to
-- validate:
--   { avatar = false, skin = 3, shirt = 2, pants = 5, hair = 2, hairColor = 1, sleeves = true }
-- `avatar = true` means "use my own Roblox avatar" instead.

local Looks = {}

Looks.Skin = {
	Color3.fromRGB(255, 224, 196),
	Color3.fromRGB(241, 194, 158),
	Color3.fromRGB(224, 172, 128),
	Color3.fromRGB(198, 140, 98),
	Color3.fromRGB(160, 106, 70),
	Color3.fromRGB(122, 78, 50),
	Color3.fromRGB(88, 56, 38),
	Color3.fromRGB(255, 204, 51), -- classic block yellow
}

Looks.Clothes = {
	Color3.fromRGB(196, 40, 28), -- red
	Color3.fromRGB(13, 105, 172), -- blue
	Color3.fromRGB(40, 127, 71), -- green
	Color3.fromRGB(245, 205, 48), -- yellow
	Color3.fromRGB(107, 50, 124), -- purple
	Color3.fromRGB(218, 133, 65), -- orange
	Color3.fromRGB(255, 152, 220), -- pink
	Color3.fromRGB(242, 243, 243), -- white
	Color3.fromRGB(99, 95, 98), -- grey
	Color3.fromRGB(27, 42, 53), -- navy
	Color3.fromRGB(105, 64, 40), -- brown
	Color3.fromRGB(17, 17, 17), -- black
}

Looks.HairColors = {
	Color3.fromRGB(30, 22, 18), -- black
	Color3.fromRGB(78, 50, 30), -- dark brown
	Color3.fromRGB(140, 92, 52), -- light brown
	Color3.fromRGB(225, 190, 120), -- blonde
	Color3.fromRGB(170, 70, 30), -- ginger
	Color3.fromRGB(200, 200, 205), -- grey
	Color3.fromRGB(80, 120, 230), -- dyed blue
	Color3.fromRGB(230, 90, 160), -- dyed pink
}

-- Hairstyles. Each piece is { size, offset from the head's centre, rotation in degrees }.
-- The default R6 head is about 1.2 studs across once its mesh is scaled, so the pieces sit just
-- outside that. If a style looks off on your build, nudge the offsets here.
local function piece(size: Vector3, offset: Vector3, rot: Vector3?, shape: string?)
	return { size = size, offset = offset, rot = rot or Vector3.zero, shape = shape }
end
local TOP = piece(Vector3.new(1.3, 0.3, 1.3), Vector3.new(0, 0.5, 0.03))
local BACK = piece(Vector3.new(1.3, 0.55, 0.3), Vector3.new(0, 0.22, 0.52))

Looks.Hair = {
	{ name = "None", pieces = {} },
	{ name = "Short", pieces = { TOP, BACK } },
	{
		name = "Messy",
		pieces = {
			TOP,
			BACK,
			piece(Vector3.new(0.4, 0.3, 0.5), Vector3.new(-0.35, 0.68, -0.2), Vector3.new(-20, 0, 25)),
			piece(Vector3.new(0.4, 0.3, 0.5), Vector3.new(0.3, 0.7, 0.1), Vector3.new(15, 0, -20)),
			piece(Vector3.new(0.5, 0.25, 0.3), Vector3.new(0.05, 0.42, -0.58), Vector3.new(0, 0, 10)),
		},
	},
	{
		name = "Long",
		pieces = {
			TOP,
			piece(Vector3.new(1.3, 1.5, 0.3), Vector3.new(0, -0.2, 0.55)),
			piece(Vector3.new(0.18, 0.95, 1.0), Vector3.new(-0.64, 0.05, 0.1)),
			piece(Vector3.new(0.18, 0.95, 1.0), Vector3.new(0.64, 0.05, 0.1)),
		},
	},
	{
		name = "Ponytail",
		pieces = {
			TOP,
			BACK,
			piece(Vector3.new(0.35, 1.0, 0.35), Vector3.new(0, -0.05, 0.85), Vector3.new(-20, 0, 0)),
		},
	},
	{
		name = "Spiky",
		pieces = {
			TOP,
			BACK,
			piece(Vector3.new(0.32, 0.55, 0.32), Vector3.new(-0.38, 0.75, 0.05), Vector3.new(0, 0, 25)),
			piece(Vector3.new(0.32, 0.6, 0.32), Vector3.new(0, 0.8, 0.05)),
			piece(Vector3.new(0.32, 0.55, 0.32), Vector3.new(0.38, 0.75, 0.05), Vector3.new(0, 0, -25)),
			piece(Vector3.new(0.32, 0.5, 0.32), Vector3.new(0, 0.7, 0.4), Vector3.new(-30, 0, 0)),
		},
	},
	{
		name = "Beanie",
		pieces = {
			piece(Vector3.new(1.32, 0.55, 1.32), Vector3.new(0, 0.45, 0.02)),
			piece(Vector3.new(1.38, 0.16, 1.38), Vector3.new(0, 0.22, 0.02)),
			piece(Vector3.new(0.32, 0.32, 0.32), Vector3.new(0, 0.82, 0.02), nil, "Ball"),
		},
	},
	{
		name = "Cap",
		pieces = {
			piece(Vector3.new(1.3, 0.35, 1.3), Vector3.new(0, 0.55, 0.05)),
			piece(Vector3.new(1.1, 0.08, 0.6), Vector3.new(0, 0.42, -0.78)),
		},
	},
}

function Looks.Default()
	return { avatar = false, skin = 2, shirt = 2, pants = 10, hair = 2, hairColor = 2, sleeves = true }
end

local function index(value, list, fallback: number): number
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	return math.clamp(math.floor(value), 1, #list)
end

-- Turns whatever a client sent into a valid look.
function Looks.Sanitize(look)
	local default = Looks.Default()
	if type(look) ~= "table" then
		return default
	end
	return {
		avatar = look.avatar == true,
		skin = index(look.skin, Looks.Skin, default.skin),
		shirt = index(look.shirt, Looks.Clothes, default.shirt),
		pants = index(look.pants, Looks.Clothes, default.pants),
		hair = index(look.hair, Looks.Hair, default.hair),
		hairColor = index(look.hairColor, Looks.HairColors, default.hairColor),
		sleeves = look.sleeves ~= false,
	}
end

function Looks.Random(rng: Random)
	return {
		avatar = false,
		skin = rng:NextInteger(1, #Looks.Skin),
		shirt = rng:NextInteger(1, #Looks.Clothes),
		pants = rng:NextInteger(1, #Looks.Clothes),
		hair = rng:NextInteger(1, #Looks.Hair),
		hairColor = rng:NextInteger(1, #Looks.HairColors),
		sleeves = rng:NextNumber() < 0.6,
	}
end

-- Body part colours for a look (R6 part names).
function Looks.Colors(look)
	local skin = Looks.Skin[look.skin]
	local shirt = Looks.Clothes[look.shirt]
	local pants = Looks.Clothes[look.pants]
	local arms = look.sleeves and shirt or skin
	return {
		Head = skin,
		Torso = shirt,
		["Left Arm"] = arms,
		["Right Arm"] = arms,
		["Left Leg"] = pants,
		["Right Leg"] = pants,
	}
end

-- Builds the hairstyle as a model of parts welded to `head`. Returns nil for "None".
function Looks.BuildHair(head: BasePart, look): Model?
	local style = Looks.Hair[look.hair]
	if not style or #style.pieces == 0 then
		return nil
	end
	local color = Looks.HairColors[look.hairColor]
	local model = Instance.new("Model")
	model.Name = "LookHair"
	for i, p in style.pieces do
		local part = Instance.new("Part")
		part.Name = "Hair" .. i
		part.Size = p.size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if p.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		end
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = head.CFrame
			* CFrame.new(p.offset)
			* CFrame.Angles(math.rad(p.rot.X), math.rad(p.rot.Y), math.rad(p.rot.Z))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	return model
end

return Looks
