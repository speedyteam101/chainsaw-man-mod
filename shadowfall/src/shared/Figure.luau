--!nonstrict
-- Realistic blocky people. Keeps the R6 body (the whole game, its animations and the shadows
-- are built on it) and adds the details that make a figure read as a person rather than six
-- boxes: a proper rounded head with eyes, irises, brows, nose, mouth and ears; hands; fabric
-- clothes with collars, cuffs, buttons, pockets, belts and shoes; and hair.
--
-- Two ways to use it:
--   Figure.Build(spec)            a complete static (anchored) NPC, standing or posed
--   Figure.Dress(character, spec) adds the details to a live player character (welded)
--
-- spec fields (all optional): skin, shirt, pants, shoes, eyes (Color3), hair (Looks.Hair index),
-- hairColor (Color3), outfit ("casual", "hoodie", "jacket", "overalls", "apron", "coat",
-- "doctor"), sleeves (true = long), expression ("neutral", "worried", "closed").
--
-- Every detail is placed relative to its limb, so poses (Build's `pose` option) carry them along.
-- The head mesh is about 1.2 studs across; if a face feature looks slightly off, nudge it here.

local CollectionService = game:GetService("CollectionService")

local Looks = require(script.Parent.Looks)

local Figure = {}

local BLACK = Color3.new(0, 0, 0)
local function darker(c: Color3, amount: number): Color3
	return c:Lerp(BLACK, amount)
end
local LEATHER = Color3.fromRGB(52, 36, 26)
local BRASS = Color3.fromRGB(196, 170, 110)

-- Standing offsets of the six R6 parts from the feet.
Figure.Rest = {
	Torso = CFrame.new(0, 3, 0),
	Head = CFrame.new(0, 4.5, 0),
	["Left Arm"] = CFrame.new(-1.5, 3, 0),
	["Right Arm"] = CFrame.new(1.5, 3, 0),
	["Left Leg"] = CFrame.new(-0.5, 1, 0),
	["Right Leg"] = CFrame.new(0.5, 1, 0),
}
local SIZES = {
	Torso = Vector3.new(2, 2, 1),
	Head = Vector3.new(2, 1, 1),
	["Left Arm"] = Vector3.new(1, 2, 1),
	["Right Arm"] = Vector3.new(1, 2, 1),
	["Left Leg"] = Vector3.new(1, 2, 1),
	["Right Leg"] = Vector3.new(1, 2, 1),
}

Figure.EyeColors = {
	Color3.fromRGB(90, 60, 35), -- brown
	Color3.fromRGB(60, 110, 170), -- blue
	Color3.fromRGB(70, 120, 70), -- green
	Color3.fromRGB(110, 100, 70), -- hazel
	Color3.fromRGB(90, 95, 105), -- grey
}
Figure.Outfits = { "casual", "hoodie", "jacket", "overalls", "coat" }
Figure.OutfitNames = { "T-shirt", "Hoodie", "Jacket", "Overalls", "Long coat" }

local function d(limb: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?, group: string?)
	return { limb = limb, size = size, offset = offset, color = color, material = material or Enum.Material.SmoothPlastic, shape = shape, group = group or "body" }
end

-- The list of detail pieces for a spec, each relative to its limb's centre.
function Figure.Details(spec)
	local skin = spec.skin or Color3.fromRGB(225, 185, 150)
	local shirt = spec.shirt or Color3.fromRGB(70, 90, 130)
	local pants = spec.pants or Color3.fromRGB(45, 45, 55)
	local shoes = spec.shoes or Color3.fromRGB(38, 32, 30)
	local eyes = spec.eyes or Figure.EyeColors[1]
	local hairColor = spec.hairColor or Color3.fromRGB(60, 40, 28)
	local outfit = spec.outfit or "casual"
	local longSleeves = spec.sleeves ~= false
	local list = {}
	local function add(piece)
		table.insert(list, piece)
	end

	-- Face -------------------------------------------------------------------------------------
	local F = Enum.Material.SmoothPlastic
	for _, side in { -1, 1 } do
		local x = 0.2 * side
		if spec.expression == "closed" then
			add(d("Head", Vector3.new(0.22, 0.04, 0.04), CFrame.new(x, 0.06, -0.575), darker(skin, 0.45), F, nil, "face"))
		else
			add(d("Head", Vector3.new(0.2, 0.15, 0.05), CFrame.new(x, 0.08, -0.56), Color3.fromRGB(240, 236, 228), F, nil, "face"))
			add(d("Head", Vector3.new(0.1, 0.12, 0.04), CFrame.new(x, 0.08, -0.585), eyes, F, nil, "face"))
			add(d("Head", Vector3.new(0.05, 0.06, 0.03), CFrame.new(x, 0.08, -0.6), Color3.fromRGB(10, 10, 12), F, nil, "face"))
			add(d("Head", Vector3.new(0.03, 0.03, 0.02), CFrame.new(x - 0.02, 0.11, -0.61), Color3.new(1, 1, 1), Enum.Material.Neon, nil, "face"))
		end
		local browTilt = spec.expression == "worried" and math.rad(14 * side) or math.rad(-4 * side)
		add(d("Head", Vector3.new(0.24, 0.05, 0.04), CFrame.new(x, 0.21, -0.565) * CFrame.Angles(0, 0, browTilt), darker(hairColor, 0.15), F, nil, "face"))
		add(d("Head", Vector3.new(0.08, 0.22, 0.16), CFrame.new(0.62 * side, 0.02, 0.02), darker(skin, 0.05), F, nil, "face"))
	end
	add(d("Head", Vector3.new(0.1, 0.16, 0.1), CFrame.new(0, -0.04, -0.6), darker(skin, 0.07), F, nil, "face"))
	add(d("Head", Vector3.new(0.26, 0.035, 0.03), CFrame.new(0, -0.21, -0.575) * CFrame.Angles(0, 0, spec.expression == "worried" and math.rad(4) or 0), Color3.fromRGB(125, 62, 60), F, nil, "face"))

	-- Hair -------------------------------------------------------------------------------------
	local style = spec.hair and Looks.Hair[spec.hair]
	if style then
		for _, p in style.pieces do
			add(d("Head", p.size, CFrame.new(p.offset) * CFrame.Angles(math.rad(p.rot.X), math.rad(p.rot.Y), math.rad(p.rot.Z)), hairColor, Enum.Material.SmoothPlastic, p.shape == "Ball" and Enum.PartType.Ball or nil, "hair"))
		end
	end

	-- Torso -------------------------------------------------------------------------------------
	local Fab = Enum.Material.Fabric
	local belt = true
	if outfit == "hoodie" then
		add(d("Torso", Vector3.new(1.5, 0.5, 0.55), CFrame.new(0, 1.05, 0.5), darker(shirt, 0.08), Fab))
		add(d("Torso", Vector3.new(1.2, 0.5, 0.04), CFrame.new(0, -0.5, -0.515), darker(shirt, 0.12), Fab))
		for _, x in { -0.2, 0.2 } do
			add(d("Torso", Vector3.new(0.05, 0.55, 0.03), CFrame.new(x, 0.62, -0.52), Color3.fromRGB(230, 228, 220), Fab))
		end
		belt = false
	elseif outfit == "jacket" then
		local jacket = darker(shirt, 0.45)
		for _, side in { -1, 1 } do
			add(d("Torso", Vector3.new(0.78, 2.02, 0.06), CFrame.new(0.61 * side, 0, -0.52), jacket, Enum.Material.Leather))
			add(d("Torso", Vector3.new(0.5, 0.32, 0.14), CFrame.new(0.5 * side, 0.92, -0.42) * CFrame.Angles(math.rad(-20), 0, 0), jacket, Enum.Material.Leather))
		end
		add(d("Torso", Vector3.new(2.02, 2.02, 0.06), CFrame.new(0, 0, 0.52), jacket, Enum.Material.Leather))
		add(d("Torso", Vector3.new(0.04, 1.9, 0.04), CFrame.new(-0.23, 0, -0.56), BRASS, Enum.Material.Metal))
	elseif outfit == "overalls" then
		add(d("Torso", Vector3.new(1.2, 1.05, 0.04), CFrame.new(0, -0.45, -0.515), pants, Fab))
		add(d("Torso", Vector3.new(0.5, 0.3, 0.03), CFrame.new(0, -0.35, -0.535), darker(pants, 0.15), Fab))
		for _, x in { -0.55, 0.55 } do
			add(d("Torso", Vector3.new(0.24, 1.0, 0.04), CFrame.new(x, 0.5, -0.515), pants, Fab))
			add(d("Torso", Vector3.new(0.24, 1.9, 0.04), CFrame.new(x, 0.05, 0.515), pants, Fab))
			add(d("Torso", Vector3.new(0.12, 0.12, 0.03), CFrame.new(x, 0.05, -0.54), BRASS, Enum.Material.Metal))
		end
		belt = false
	elseif outfit == "apron" then
		add(d("Torso", Vector3.new(1.7, 2.6, 0.08), CFrame.new(0, -0.55, -0.56), Color3.fromRGB(80, 56, 40), Enum.Material.Leather))
		add(d("Torso", Vector3.new(1.2, 0.08, 1.04), CFrame.new(0, 0.98, 0), Color3.fromRGB(80, 56, 40), Enum.Material.Leather))
		belt = false
	elseif outfit == "coat" or outfit == "doctor" then
		local coat = outfit == "doctor" and Color3.fromRGB(236, 236, 232) or darker(shirt, 0.35)
		for _, side in { -1, 1 } do
			add(d("Torso", Vector3.new(0.82, 2.02, 0.07), CFrame.new(0.59 * side, 0, -0.53), coat, Fab))
			add(d("Torso", Vector3.new(0.95, 1.5, 0.08), CFrame.new(0.52 * side, -1.72, -0.54), coat, Fab))
			add(d("Torso", Vector3.new(0.45, 0.4, 0.12), CFrame.new(0.55 * side, 0.85, -0.45) * CFrame.Angles(math.rad(-15), 0, math.rad(-15 * side)), coat, Fab))
		end
		add(d("Torso", Vector3.new(2.04, 3.5, 0.08), CFrame.new(0, -0.75, 0.54), coat, Fab))
		if outfit == "doctor" then
			add(d("Torso", Vector3.new(0.06, 0.9, 0.06), CFrame.new(-0.3, 0.45, -0.58) * CFrame.Angles(0, 0, math.rad(12)), Color3.fromRGB(30, 30, 34), Enum.Material.Rubber))
			add(d("Torso", Vector3.new(0.06, 0.9, 0.06), CFrame.new(0.3, 0.45, -0.58) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(30, 30, 34), Enum.Material.Rubber))
			add(d("Torso", Vector3.new(0.2, 0.2, 0.06), CFrame.new(0, -0.05, -0.59), Color3.fromRGB(190, 190, 200), Enum.Material.Metal, Enum.PartType.Cylinder))
		end
		belt = false
	else
		-- A plain shirt: V collar, button placket, buttons and a chest pocket.
		for _, side in { -1, 1 } do
			add(d("Torso", Vector3.new(0.5, 0.12, 0.08), CFrame.new(0.22 * side, 0.88, -0.52) * CFrame.Angles(0, 0, math.rad(-25 * side)), darker(shirt, 0.2), Fab))
		end
		add(d("Torso", Vector3.new(0.1, 1.6, 0.03), CFrame.new(0, -0.05, -0.515), darker(shirt, 0.12), Fab))
		for _, y in { 0.5, 0.05, -0.4 } do
			add(d("Torso", Vector3.new(0.07, 0.07, 0.03), CFrame.new(0, y, -0.535), darker(shirt, 0.45), Enum.Material.SmoothPlastic, Enum.PartType.Ball))
		end
		add(d("Torso", Vector3.new(0.42, 0.4, 0.03), CFrame.new(0.52, 0.42, -0.515), darker(shirt, 0.08), Fab))
		add(d("Torso", Vector3.new(0.44, 0.1, 0.035), CFrame.new(0.52, 0.6, -0.52), darker(shirt, 0.18), Fab))
	end
	if belt then
		add(d("Torso", Vector3.new(2.03, 0.2, 1.03), CFrame.new(0, -0.9, 0), LEATHER, Enum.Material.Leather))
		add(d("Torso", Vector3.new(0.28, 0.17, 0.04), CFrame.new(0, -0.9, -0.53), BRASS, Enum.Material.Metal))
	end

	-- Arms -----------------------------------------------------------------------------------------
	local sleeveColor = (outfit == "jacket" and darker(shirt, 0.45)) or ((outfit == "coat") and darker(shirt, 0.35)) or (outfit == "doctor" and Color3.fromRGB(236, 236, 232)) or shirt
	for _, arm in { "Left Arm", "Right Arm" } do
		if longSleeves or outfit == "jacket" or outfit == "coat" or outfit == "doctor" or outfit == "hoodie" then
			add(d(arm, Vector3.new(1.03, 1.58, 1.03), CFrame.new(0, 0.2, 0), sleeveColor, outfit == "jacket" and Enum.Material.Leather or Fab))
			add(d(arm, Vector3.new(1.05, 0.14, 1.05), CFrame.new(0, -0.6, 0), darker(sleeveColor, 0.2), Fab))
			add(d(arm, Vector3.new(0.98, 0.42, 0.98), CFrame.new(0, -0.79, 0), skin))
		else
			add(d(arm, Vector3.new(1.04, 0.72, 1.04), CFrame.new(0, 0.65, 0), shirt, Fab))
			add(d(arm, Vector3.new(1.06, 0.1, 1.06), CFrame.new(0, 0.28, 0), darker(shirt, 0.2), Fab))
		end
	end

	-- Legs -----------------------------------------------------------------------------------------
	for _, leg in { "Left Leg", "Right Leg" } do
		add(d(leg, Vector3.new(1.03, 0.1, 1.03), CFrame.new(0, -0.55, 0), darker(pants, 0.2), Fab))
		add(d(leg, Vector3.new(1.04, 0.42, 1.16), CFrame.new(0, -0.8, -0.07), shoes, Enum.Material.Leather))
		add(d(leg, Vector3.new(1.06, 0.1, 1.2), CFrame.new(0, -0.96, -0.07), darker(shoes, 0.5), Enum.Material.Rubber))
		add(d(leg, Vector3.new(0.5, 0.05, 0.36), CFrame.new(0, -0.58, -0.4), Color3.fromRGB(215, 210, 200), Fab))
	end
	return list
end

local function makePart(piece, cf: CFrame, anchored: boolean): Part
	local p = Instance.new("Part")
	p.Name = piece.group == "hair" and "Hair" or "Detail"
	p.Size = piece.size
	p.Color = piece.color
	p.Material = piece.material
	if piece.shape then
		p.Shape = piece.shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = piece.group ~= "face"
	p.Anchored = anchored
	p.CFrame = cf
	p:SetAttribute("Limb", piece.limb)
	return p
end

-- A complete static figure. spec.cf = where the feet stand. spec.pose = { [limb] = CFrame }
-- overrides limb placement (in standing space); spec.lay = an extra CFrame applied to everything
-- (e.g. lying down).
function Figure.Build(spec): (Model, { [string]: BasePart })
	local model = Instance.new("Model")
	model.Name = spec.name or "Person"
	local base = spec.cf * (spec.lay or CFrame.new())
	local skin = spec.skin or Color3.fromRGB(225, 185, 150)
	local shirt = spec.shirt or Color3.fromRGB(70, 90, 130)
	local pants = spec.pants or Color3.fromRGB(45, 45, 55)
	local colors = {
		Torso = shirt,
		Head = skin,
		["Left Arm"] = spec.sleeves == false and skin or shirt,
		["Right Arm"] = spec.sleeves == false and skin or shirt,
		["Left Leg"] = pants,
		["Right Leg"] = pants,
	}
	local parts = {}
	for name, rest in Figure.Rest do
		local p = Instance.new("Part")
		p.Name = name
		p.Size = SIZES[name]
		p.CFrame = base * ((spec.pose and spec.pose[name]) or rest)
		p.Color = colors[name]
		p.Material = name == "Head" and Enum.Material.SmoothPlastic or Enum.Material.Fabric
		p.Anchored = true
		p.CanCollide = spec.collide == true
		p.CanQuery = spec.collide == true
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		parts[name] = p
		if name == "Head" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
			mesh.Parent = p
		end
	end
	for _, piece in Figure.Details(spec) do
		local limb = parts[piece.limb]
		makePart(piece, limb.CFrame * piece.offset, true).Parent = model
	end
	model.PrimaryPart = parts.Torso
	return model, parts
end

-- Adds the details to a live R6 character. Removes any previous details first. The default face
-- decal is removed because the figure has its own face.
function Figure.Dress(character: Model, spec)
	local old = character:FindFirstChild("LookDetails")
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Model")
	holder.Name = "LookDetails"
	local head = character:FindFirstChild("Head")
	local face = head and head:FindFirstChild("face")
	if face then
		face:Destroy()
	end
	for _, name in { "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		local limb = character:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			limb.Material = Enum.Material.Fabric
		end
	end
	for _, piece in Figure.Details(spec) do
		local limb = character:FindFirstChild(piece.limb)
		if limb and limb:IsA("BasePart") then
			local p = makePart(piece, limb.CFrame * piece.offset, false)
			if piece.limb == "Head" or piece.limb == "Torso" then
				p.CastShadow = false -- would throw a shadow into your own flashlight beam
			end
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = limb
			weld.Part1 = p
			weld.Parent = p
			p.Parent = holder
		end
	end
	holder.Parent = character
	return holder
end

-- A living, walking figure: the same person as Build, but as a real R6-jointed rig with a
-- Humanoid so it can walk around (NpcService) and be animated (VillagerAnimator on the client).
-- spec.cf = where the feet stand.
function Figure.BuildRig(spec): (Model, { [string]: BasePart }, Humanoid)
	local model = Instance.new("Model")
	model.Name = spec.name or "Person"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- arrive on clients whole (streaming)
	local skin = spec.skin or Color3.fromRGB(225, 185, 150)
	local shirt = spec.shirt or Color3.fromRGB(70, 90, 130)
	local pants = spec.pants or Color3.fromRGB(45, 45, 55)
	local rootCf = spec.cf * CFrame.new(0, 3, 0)
	local function limb(name: string, size: Vector3, offset: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = rootCf * offset
		p.Color = color
		p.Material = name == "Head" and Enum.Material.SmoothPlastic or Enum.Material.Fabric
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local root = limb("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(), Color3.new())
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	local parts = {
		HumanoidRootPart = root,
		Torso = limb("Torso", SIZES.Torso, CFrame.new(), shirt),
		Head = limb("Head", SIZES.Head, CFrame.new(0, 1.5, 0), skin),
		["Left Arm"] = limb("Left Arm", SIZES["Left Arm"], CFrame.new(-1.5, 0, 0), spec.sleeves == false and skin or shirt),
		["Right Arm"] = limb("Right Arm", SIZES["Right Arm"], CFrame.new(1.5, 0, 0), spec.sleeves == false and skin or shirt),
		["Left Leg"] = limb("Left Leg", SIZES["Left Leg"], CFrame.new(-0.5, -2, 0), pants),
		["Right Leg"] = limb("Right Leg", SIZES["Right Leg"], CFrame.new(0.5, -2, 0), pants),
	}
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = parts.Head
	-- The standard R6 joints (same C0/C1 as a Roblox R6 character).
	local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = part0
		m.Part1 = part1
		m.C0 = c0
		m.C1 = c1
		m.Parent = part0
	end
	motor("RootJoint", root, parts.Torso, CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Neck", parts.Torso, parts.Head, CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Right Shoulder", parts.Torso, parts["Right Arm"], CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Shoulder", parts.Torso, parts["Left Arm"], CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	motor("Right Hip", parts.Torso, parts["Right Leg"], CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Hip", parts.Torso, parts["Left Leg"], CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- R15 so HipHeight is honoured exactly (as ShadowRig does)
	humanoid.HipHeight = 2
	humanoid.WalkSpeed = spec.walkSpeed or 7
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	for _, stateType in { Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.Dead } do
		humanoid:SetStateEnabled(stateType, false)
	end
	humanoid.Parent = model
	model.PrimaryPart = root

	Figure.Dress(model, spec)
	CollectionService:AddTag(model, "Villager")
	return model, parts, humanoid
end

-- Turns a saved look (Looks.luau indexes) into a Figure spec.
function Figure.FromLook(look)
	return {
		skin = Looks.Skin[look.skin],
		shirt = Looks.Clothes[look.shirt],
		pants = Looks.Clothes[look.pants],
		hair = look.hair,
		hairColor = Looks.HairColors[look.hairColor],
		eyes = Figure.EyeColors[look.eyes or 1],
		outfit = Figure.Outfits[look.outfit or 1],
		sleeves = look.sleeves,
	}
end

-- A deterministic "random" look for an NPC from its name, so everyone looks different but the
-- same person always looks the same.
function Figure.SpecFor(name: string, base)
	local hash = 0
	for i = 1, #name do
		hash = (hash * 31 + string.byte(name, i)) % 1000003
	end
	local function pick(list)
		return list[(hash % #list) + 1]
	end
	local spec = table.clone(base or {})
	spec.skin = spec.skin or Looks.Skin[(hash % 7) + 1]
	spec.hair = spec.hair or ((hash // 7) % (#Looks.Hair - 1)) + 2
	spec.hairColor = spec.hairColor or Looks.HairColors[((hash // 13) % 6) + 1]
	spec.eyes = spec.eyes or Figure.EyeColors[((hash // 17) % #Figure.EyeColors) + 1]
	spec.outfit = spec.outfit or pick({ "casual", "casual", "jacket", "hoodie", "coat", "overalls" })
	spec.shoes = spec.shoes or pick({ Color3.fromRGB(38, 32, 30), Color3.fromRGB(70, 50, 36), Color3.fromRGB(30, 30, 34), Color3.fromRGB(110, 100, 90) })
	return spec
end

return Figure
