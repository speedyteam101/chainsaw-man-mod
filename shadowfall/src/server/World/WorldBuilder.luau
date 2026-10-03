--!nonstrict
-- Generates the whole world at server start:
--   * Act 1: Hollow Creek on the night it was taken (a dark, empty town for the horror chapter)
--   * Act 2: Hollow Creek (survivor camp hub) -> Whispering Woods -> The Rift -> Sunken Cathedral -> Heart of Shadow
-- Returns positions of landmarks, spawn points and interactive prompts for the other services.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Areas)
local B = require(script.Parent.Builders)

local WorldBuilder = {}

local STREETS = { -100, 0, 100 }

type Reserved = { { at: Vector2, r: number } }

local function isReserved(reserved: Reserved, x: number, z: number, pad: number): boolean
	for _, zone in reserved do
		if (Vector2.new(x, z) - zone.at).Magnitude < zone.r + pad then
			return true
		end
	end
	return false
end

local function nearestStreetDistance(value: number): (number, number)
	local best, bestLine = math.huge, 0
	for _, line in STREETS do
		local d = math.abs(value - line)
		if d < best then
			best, bestLine = d, line
		end
	end
	return best, bestLine
end

-- Lays out a 3x3 street grid with houses in the blocks. Coordinates are relative to `origin`.
local function buildTown(parent: Instance, origin: Vector3, half: number, rng: Random, options)
	local reserved: Reserved = options.reserved or {}
	B.ground(parent, origin, Vector2.new(half * 2, half * 2), Color3.fromRGB(30, 32, 30), Enum.Material.Ground)

	-- Streets
	for _, line in STREETS do
		B.road(parent, origin + Vector3.new(-half, 0, line), origin + Vector3.new(half, 0, line), 20)
		B.road(parent, origin + Vector3.new(line, 0, -half), origin + Vector3.new(line, 0, half), 20)
	end
	-- Pavement edges along streets
	for _, line in STREETS do
		for _, side in { -1, 1 } do
			B.block(parent, {
				name = "Curb",
				size = Vector3.new(half * 2, 0.6, 1.2),
				cf = CFrame.new(origin + Vector3.new(0, 0.3, line + side * 10.6)),
				color = Color3.fromRGB(56, 56, 60),
				material = Enum.Material.Concrete,
				floor = true,
			})
		end
	end

	-- Houses
	local coords = { -70, -30, 30, 70, -128, 128 }
	if half >= 175 then
		table.insert(coords, -162)
		table.insert(coords, 162)
	end
	local houses = {}
	for _, cx in coords do
		for _, cz in coords do
			if not isReserved(reserved, cx, cz, 14) then
				local dx, lineX = nearestStreetDistance(cx)
				local dz, lineZ = nearestStreetDistance(cz)
				local position = origin + Vector3.new(cx, 0, cz)
				local look
				if dx < dz then
					look = Vector3.new(lineX - cx, 0, 0).Unit
				else
					look = Vector3.new(0, 0, lineZ - cz).Unit
				end
				local cf = CFrame.lookAt(position, position + look)
				if rng:NextNumber() < 0.14 and not options.noEmptyLots then
					-- Empty lot: a dead tree and a broken fence.
					B.tree(parent, position, rng, true)
					B.fence(parent, position + Vector3.new(-9, 0, -9), position + Vector3.new(9, 0, -9))
				else
					local model = B.house(parent, cf, rng, { litWindows = options.litWindows, broken = rng:NextNumber() < 0.25 })
					table.insert(houses, { model = model, cf = cf })
				end
			end
		end
	end

	-- Street lamps every 40 studs, alternating sides.
	for _, line in STREETS do
		local toggle = 1
		for along = -half + 20, half - 20, 40 do
			toggle = -toggle
			local pa = Vector2.new(along, line + toggle * 12)
			local pb = Vector2.new(line + toggle * 12, along)
			for _, p in { pa, pb } do
				if not isReserved(reserved, p.X, p.Y, 2) and rng:NextNumber() < (options.lampChance or 0.8) then
					B.lamp(parent, origin + Vector3.new(p.X, 0, p.Y), nil, options.lampStrength, true)
				end
			end
		end
	end

	-- Abandoned cars
	for _ = 1, options.cars or 10 do
		local line = STREETS[rng:NextInteger(1, #STREETS)]
		local along = rng:NextNumber(-half + 15, half - 15)
		local alongX = rng:NextNumber() < 0.5
		local x, z = if alongX then along else line + rng:NextNumber(-5, 5), if alongX then line + rng:NextNumber(-5, 5) else along
		if not isReserved(reserved, x, z, 6) then
			local yaw = (alongX and math.pi / 2 or 0) + rng:NextNumber(-0.5, 0.5) + (rng:NextNumber() < 0.5 and math.pi or 0)
			B.car(parent, CFrame.new(origin + Vector3.new(x, 0, z)) * CFrame.Angles(0, yaw, 0), rng)
		end
	end

	-- Torn edges where the town was ripped out of the ground.
	for _ = 1, 40 do
		local side = rng:NextInteger(1, 4)
		local t = rng:NextNumber(-half, half)
		local edge = ({ Vector3.new(half, 0, t), Vector3.new(-half, 0, t), Vector3.new(t, 0, half), Vector3.new(t, 0, -half) })[side]
		B.block(parent, {
			name = "TornEdge",
			size = Vector3.new(rng:NextNumber(6, 16), rng:NextNumber(6, 16), rng:NextNumber(6, 16)),
			cf = CFrame.new(origin + edge + Vector3.new(0, -rng:NextNumber(4, 12), 0)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), rng:NextNumber(0, 1)),
			color = Color3.fromRGB(34, 28, 24),
			material = Enum.Material.Ground,
		})
	end
	return houses
end

-- Classic blocky townsperson for the camp. Anchored, no humanoid; talks through a prompt.
local function survivor(parent: Instance, cf: CFrame, name: string, shirt: Color3, pants: Color3, skin: Color3)
	local model = Instance.new("Model")
	model.Name = name
	local function limb(n: string, size: Vector3, offset: CFrame, color: Color3)
		return B.block(model, { name = n, size = size, cf = cf * offset, color = color, material = Enum.Material.SmoothPlastic })
	end
	local torso = limb("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), shirt)
	limb("Head", Vector3.new(2, 1, 1), CFrame.new(0, 4.5, 0), skin)
	limb("Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), skin)
	limb("Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3, 0), skin)
	limb("Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), pants)
	limb("Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), pants)
	for _, x in { -0.4, 0.4 } do
		limb("Eye", Vector3.new(0.2, 0.25, 0.05), CFrame.new(x, 4.6, -0.52), Color3.new(0, 0, 0))
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 26)
	gui.StudsOffset = Vector3.new(0, 6.2, 0)
	gui.MaxDistance = 45
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 170)
	label.TextStrokeTransparency = 0.5
	label.Text = name
	label.Parent = gui
	gui.Adornee = torso
	gui.Parent = torso
	model.Parent = parent
	local prompt = B.prompt(torso, "Talk", name, 0, 10)
	return model, prompt
end

local SURVIVORS = {
	{
		name = "Mara, the mechanic",
		shirt = Color3.fromRGB(70, 90, 130),
		pants = Color3.fromRGB(40, 40, 50),
		lines = {
			"Power's been out since the sky went black. Funny thing is, the shadows hate light more than anything.",
			"You won't get stronger just by swinging at them. Out here strength comes from proving yourself.",
			"Do something worth remembering, a Feat, and you'll be able to Ascend. Press M and look at the Ascension page.",
		},
	},
	{
		name = "Old Tobias",
		shirt = Color3.fromRGB(110, 80, 50),
		pants = Color3.fromRGB(60, 50, 40),
		lines = {
			"Sixty years in Hollow Creek. Never once did the town move. Then one night... it did.",
			"Past the east bridge are the Whispering Woods. The gate there won't open for anyone who hasn't ascended.",
			"Each new level opens another gate. Every gate leads deeper into where the dark comes from.",
		},
	},
	{
		name = "Jun",
		shirt = Color3.fromRGB(200, 70, 60),
		pants = Color3.fromRGB(50, 60, 90),
		lines = {
			"Did you roll something cool? I didn't roll anything. I just hide by the fire.",
			"The shrine can reroll your power if you've got enough Essence. Shadows drop it when they fade.",
			"If you roll something worse you can keep your old power. The shrine always lets you choose.",
		},
	},
	{
		name = "Sister Agnes",
		shirt = Color3.fromRGB(30, 30, 34),
		pants = Color3.fromRGB(30, 30, 34),
		lines = {
			"The cathedral bells ring down below. I don't think anyone is ringing them.",
			"Hold your guard (F) and the blows hurt less. Raise it just as a blow lands and they'll stagger. That is a parry.",
		},
	},
	{
		name = "Dex, ex-cop",
		shirt = Color3.fromRGB(40, 60, 90),
		pants = Color3.fromRGB(25, 25, 30),
		lines = {
			"Watch their eyes. When they go red, something's about to hit you.",
			"Dodge (Q) through an attack at the last second and you'll hit harder for a moment. Feels good.",
			"The big ones, Brutes, telegraph their slams with a red circle. Get out of it.",
		},
	},
}

local function buildCamp(parent: Instance, center: Vector3, rng: Random, info)
	local camp = B.folder(parent, "Camp")
	-- Paved square
	B.block(camp, {
		name = "Plaza",
		size = Vector3.new(84, 0.6, 84),
		cf = CFrame.new(center + Vector3.new(0, 0.3, 0)),
		color = Color3.fromRGB(58, 54, 52),
		material = Enum.Material.Cobblestone,
		floor = true,
	})
	-- Bonfire
	for i = 0, 5 do
		B.block(camp, {
			name = "Log",
			size = Vector3.new(1.2, 1.2, 7),
			cf = CFrame.new(center + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, i * math.pi / 3, math.rad(20)),
			color = Color3.fromRGB(50, 32, 22),
			material = Enum.Material.Wood,
		})
	end
	local core = B.block(camp, {
		name = "FireCore",
		size = Vector3.new(3, 2, 3),
		cf = CFrame.new(center + Vector3.new(0, 1.6, 0)),
		color = Color3.fromRGB(255, 140, 50),
		material = Enum.Material.Neon,
		collide = false,
	})
	local fire = Instance.new("Fire")
	fire.Size = 9
	fire.Heat = 14
	fire.Color = Color3.fromRGB(255, 140, 50)
	fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
	fire.Parent = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Range = 60
	light.Brightness = 3
	light.Shadows = true
	light.Parent = core
	CollectionService:AddTag(core, "FlickerLight")

	-- Ring of lanterns marking the safe zone
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * 46
		B.block(camp, { name = "Stone", size = Vector3.new(2.4, 1.4, 2.4), cf = CFrame.new(p + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, a, 0), color = Color3.fromRGB(70, 66, 62), material = Enum.Material.Slate })
		if i % 2 == 0 then
			local lantern = B.block(camp, { name = "Lantern", size = Vector3.new(1, 1.4, 1), cf = CFrame.new(p + Vector3.new(0, 2.2, 0)), color = Color3.fromRGB(255, 190, 110), material = Enum.Material.Neon, collide = false })
			local l = Instance.new("PointLight")
			l.Color = Color3.fromRGB(255, 180, 100)
			l.Range = 14
			l.Brightness = 1.2
			l.Parent = lantern
		end
	end

	-- Tents
	for i, a in { 0.9, 2.2, 3.3, 5.6 } do
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * 28
		local cf = CFrame.lookAt(p, center)
		local colors = { Color3.fromRGB(110, 70, 50), Color3.fromRGB(60, 80, 70), Color3.fromRGB(90, 90, 70), Color3.fromRGB(70, 60, 90) }
		for _, sideSign in { -1, 1 } do
			B.block(camp, {
				class = "WedgePart",
				name = "Tent",
				size = Vector3.new(8, 6, 4),
				cf = cf * CFrame.new(sideSign * 2, 3, 0) * CFrame.Angles(0, -sideSign * math.pi / 2, 0),
				color = colors[i],
				material = Enum.Material.Fabric,
			})
		end
	end

	-- Log benches around the fire
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * 11
		B.block(camp, { name = "Bench", size = Vector3.new(1.6, 1.6, 8), cf = CFrame.lookAt(p, center) * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, math.pi / 2, 0), color = Color3.fromRGB(60, 40, 28), material = Enum.Material.Wood, shape = Enum.PartType.Cylinder })
	end

	-- Survivors
	info.survivors = {}
	for i, data in SURVIVORS do
		local a = (i - 1) / #SURVIVORS * math.pi * 2 + 0.3
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * 16
		local skinTones = { Color3.fromRGB(255, 220, 180), Color3.fromRGB(200, 150, 110), Color3.fromRGB(140, 95, 65), Color3.fromRGB(240, 200, 160) }
		local _, prompt = survivor(camp, CFrame.lookAt(p, center), data.name, data.shirt, data.pants, skinTones[(i % #skinTones) + 1])
		table.insert(info.survivors, { prompt = prompt, name = data.name, lines = data.lines })
	end

	-- Roll shrine
	local shrinePos = center + Vector3.new(0, 0, -30)
	B.block(camp, { name = "ShrineBase", size = Vector3.new(8, 2, 8), cf = CFrame.new(shrinePos + Vector3.new(0, 1, 0)), color = Color3.fromRGB(40, 36, 46), material = Enum.Material.Slate })
	B.block(camp, { name = "ShrinePillar", size = Vector3.new(3, 7, 3), cf = CFrame.new(shrinePos + Vector3.new(0, 5.5, 0)), color = Color3.fromRGB(50, 44, 58), material = Enum.Material.Slate })
	local orb = B.block(camp, { name = "ShrineOrb", size = Vector3.new(3.4, 3.4, 3.4), cf = CFrame.new(shrinePos + Vector3.new(0, 11, 0)), color = Color3.fromRGB(200, 170, 255), material = Enum.Material.Neon, shape = Enum.PartType.Ball, collide = false })
	local orbLight = Instance.new("PointLight")
	orbLight.Color = Color3.fromRGB(190, 160, 255)
	orbLight.Range = 20
	orbLight.Brightness = 2
	orbLight.Parent = orb
	CollectionService:AddTag(orb, "Bob")
	info.shrinePrompt = B.prompt(orb, "Roll for a power", "Awakening Shrine", 0, 14)

	-- Feat board
	local board = B.block(camp, { name = "FeatBoard", size = Vector3.new(10, 7, 0.6), cf = CFrame.new(center + Vector3.new(30, 4.5, 6)) * CFrame.Angles(0, -math.pi / 2, 0), color = Color3.fromRGB(70, 52, 36), material = Enum.Material.WoodPlanks })
	B.block(camp, { name = "BoardLeg", size = Vector3.new(0.6, 4.5, 0.6), cf = CFrame.new(center + Vector3.new(30, 1.25, 2)), color = Color3.fromRGB(50, 36, 26), material = Enum.Material.Wood })
	B.block(camp, { name = "BoardLeg", size = Vector3.new(0.6, 4.5, 0.6), cf = CFrame.new(center + Vector3.new(30, 1.25, 10)), color = Color3.fromRGB(50, 36, 26), material = Enum.Material.Wood })
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.SpecialElite
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(240, 225, 200)
	text.Text = "NO ONE GETS STRONGER\nBY WAITING.\n\nProve yourself.\nThen Ascend."
	text.Parent = surface
	surface.Parent = board
	info.boardPrompt = B.prompt(board, "Read", "Feats & Ascension", 0, 12)

	-- A sign pointing east
	local sign = B.block(camp, { name = "Sign", size = Vector3.new(8, 2, 0.4), cf = CFrame.new(center + Vector3.new(40, 6, -14)), color = Color3.fromRGB(60, 44, 30), material = Enum.Material.WoodPlanks })
	B.block(camp, { name = "SignPost", size = Vector3.new(0.5, 6, 0.5), cf = CFrame.new(center + Vector3.new(40, 3, -14)), color = Color3.fromRGB(40, 30, 22), material = Enum.Material.Wood })
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Back
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.Font = Enum.Font.SpecialElite
	signText.TextScaled = true
	signText.TextColor3 = Color3.fromRGB(230, 210, 180)
	signText.Text = "WOODS  ->"
	signText.Parent = signGui
	signGui.Parent = sign
	return camp
end

local function buildChurchyard(parent: Instance, center: Vector3, rng: Random)
	local yard = B.folder(parent, "Churchyard")
	-- Iron fence around the yard with an opening to the north (toward the street)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		-- Leave an entrance facing the street (+Z) and no railings through the chapel (-Z).
		if math.sin(a) < 0.9 and math.sin(a) > -0.75 then
			local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * 40
			B.block(yard, { name = "Railing", size = Vector3.new(0.5, 5, 0.5), cf = CFrame.new(p + Vector3.new(0, 2.5, 0)), color = Color3.fromRGB(20, 20, 24), material = Enum.Material.Metal })
		end
	end
	-- Gravestones
	for _ = 1, 28 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(18, 36)
		local p = center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		B.block(yard, {
			name = "Grave",
			size = Vector3.new(2.6, rng:NextNumber(2.5, 4), 0.7),
			cf = CFrame.new(p + Vector3.new(0, 1.5, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), rng:NextNumber(-0.3, 0.3), math.rad(rng:NextNumber(-10, 10))),
			color = Color3.fromRGB(70, 70, 74),
			material = Enum.Material.Slate,
		})
	end
	-- Small chapel at the back
	local chapelCf = CFrame.lookAt(center + Vector3.new(0, 0, -40), center)
	B.house(yard, chapelCf, rng, { width = 22, depth = 14, height = 18, name = "Chapel", litWindows = 0 })
	B.block(yard, { name = "Steeple", size = Vector3.new(6, 18, 6), cf = chapelCf * CFrame.new(0, 30, 0), color = Color3.fromRGB(50, 46, 50), material = Enum.Material.Slate })
	return yard
end

-- ACT 1 ------------------------------------------------------------------------------------

local function buildAct1(map: Instance, rng: Random, info)
	local origin = Areas.Act1Origin
	local folder = B.folder(map, "Act1_HollowCreek")
	local playerHouseAt = Vector2.new(-70, 30)
	local radioAt = Vector2.new(50, -70)
	local towerAt = Vector2.new(-50, 128)
	buildTown(folder, origin, 150, rng, {
		reserved = {
			{ at = Vector2.new(0, 0), r = 30 },
			{ at = playerHouseAt, r = 4 },
			{ at = radioAt, r = 26 },
			{ at = towerAt, r = 24 },
		},
		litWindows = 0,
		lampChance = 0.55,
		lampStrength = 0.6,
		cars = 12,
	})

	-- Player's house: a hollow house with a bed and a table. The player wakes up inside.
	local houseCf = CFrame.lookAt(origin + Vector3.new(playerHouseAt.X, 0, playerHouseAt.Y), origin + Vector3.new(playerHouseAt.X, 0, 0))
	local _, size = B.house(folder, houseCf, rng, { width = 22, depth = 20, height = 12, litWindows = 0, name = "YourHouse" })
	B.block(folder, { name = "Bed", size = Vector3.new(5, 1.6, 8), cf = houseCf * CFrame.new(-6, 1.4, 4), color = Color3.fromRGB(110, 40, 40), material = Enum.Material.Fabric })
	B.block(folder, { name = "Pillow", size = Vector3.new(4, 0.6, 1.6), cf = houseCf * CFrame.new(-6, 2.4, 7.2), color = Color3.fromRGB(220, 220, 210), material = Enum.Material.Fabric })
	B.block(folder, { name = "Table", size = Vector3.new(5, 0.4, 3), cf = houseCf * CFrame.new(6, 3, 4), color = Color3.fromRGB(70, 50, 36), material = Enum.Material.Wood })
	local note = B.block(folder, { name = "Note", size = Vector3.new(1, 0.05, 1.3), cf = houseCf * CFrame.new(6, 3.25, 4), color = Color3.fromRGB(240, 235, 210), material = Enum.Material.SmoothPlastic, collide = false })
	info.act1.notePrompt = B.prompt(note, "Read", "Note", 0, 8)
	local lampInside = B.block(folder, { name = "DeadBulb", size = Vector3.new(1, 1, 1), cf = houseCf * CFrame.new(0, 11.2, 0), color = Color3.fromRGB(255, 170, 90), material = Enum.Material.Neon, collide = false, shape = Enum.PartType.Ball })
	local insideLight = Instance.new("PointLight")
	insideLight.Range = 14
	insideLight.Brightness = 0.8
	insideLight.Color = Color3.fromRGB(255, 170, 90)
	insideLight.Parent = lampInside
	CollectionService:AddTag(lampInside, "FlickerLight")
	info.act1.houseSpawn = houseCf * CFrame.new(0, 3.5, 3)
	info.act1.houseExit = (houseCf * CFrame.new(0, 0, -size.Z / 2 - 5)).Position

	-- Town square: a dead fountain and benches.
	local square = origin
	B.block(folder, { name = "Plaza", size = Vector3.new(56, 0.6, 56), cf = CFrame.new(square + Vector3.new(0, 0.5, 0)), color = Color3.fromRGB(54, 52, 52), material = Enum.Material.Cobblestone, floor = true })
	B.block(folder, { name = "FountainRim", size = Vector3.new(3, 16, 16), cf = CFrame.new(square + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), color = Color3.fromRGB(80, 80, 84), material = Enum.Material.Marble, shape = Enum.PartType.Cylinder })
	B.block(folder, { name = "FountainWater", size = Vector3.new(0.4, 14, 14), cf = CFrame.new(square + Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.pi / 2), color = Color3.fromRGB(6, 6, 10), material = Enum.Material.Glass, shape = Enum.PartType.Cylinder })
	B.block(folder, { name = "Statue", size = Vector3.new(2.4, 8, 2.4), cf = CFrame.new(square + Vector3.new(0, 7, 0)) * CFrame.Angles(0.1, 0, 0.25), color = Color3.fromRGB(70, 74, 70), material = Enum.Material.Marble })
	info.act1.square = square
	info.act1.squareSpawn = CFrame.new(square + Vector3.new(0, 3.5, 20))

	-- Radio station: a squat brick building with a tall blinking antenna and a radio outside.
	local stationCf = CFrame.lookAt(origin + Vector3.new(radioAt.X, 0, radioAt.Y), origin + Vector3.new(radioAt.X, 0, -100))
	B.house(folder, stationCf, rng, { width = 30, depth = 22, height = 12, litWindows = 0, name = "RadioStation" })
	B.block(folder, { name = "Antenna", size = Vector3.new(1.2, 60, 1.2), cf = stationCf * CFrame.new(8, 42, 4), color = Color3.fromRGB(90, 90, 96), material = Enum.Material.DiamondPlate })
	local beacon = B.block(folder, { name = "Beacon", size = Vector3.new(1.6, 1.6, 1.6), cf = stationCf * CFrame.new(8, 72.5, 4), color = Color3.fromRGB(255, 30, 30), material = Enum.Material.Neon, collide = false, shape = Enum.PartType.Ball })
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = Color3.fromRGB(255, 40, 40)
	beaconLight.Range = 30
	beaconLight.Brightness = 3
	beaconLight.Parent = beacon
	CollectionService:AddTag(beacon, "Blink")
	local radioTableCf = stationCf * CFrame.new(0, 0, -18)
	B.block(folder, { name = "RadioTable", size = Vector3.new(5, 3, 3), cf = radioTableCf * CFrame.new(0, 1.5, 0), color = Color3.fromRGB(60, 44, 30), material = Enum.Material.Wood })
	local radio = B.block(folder, { name = "Radio", size = Vector3.new(2.4, 1.6, 1.2), cf = radioTableCf * CFrame.new(0, 3.8, 0), color = Color3.fromRGB(40, 40, 36), material = Enum.Material.Metal })
	local dial = B.block(folder, { name = "RadioDial", size = Vector3.new(0.9, 0.5, 0.1), cf = radioTableCf * CFrame.new(-0.4, 3.9, -0.62), color = Color3.fromRGB(120, 255, 140), material = Enum.Material.Neon, collide = false })
	local dialLight = Instance.new("PointLight")
	dialLight.Color = Color3.fromRGB(120, 255, 140)
	dialLight.Range = 10
	dialLight.Brightness = 1.5
	dialLight.Parent = dial
	CollectionService:AddTag(dial, "FlickerLight")
	info.act1.radio = radio.Position
	info.act1.radioSpawn = radioTableCf * CFrame.new(0, 3.5, -6)

	-- Clock tower: tall, with a glowing clock face and a bell rope at the door.
	local towerCf = CFrame.lookAt(origin + Vector3.new(towerAt.X, 0, towerAt.Y), origin + Vector3.new(towerAt.X, 0, 100))
	local tower = B.folder(folder, "ClockTower")
	for _, x in { -8, 8 } do
		B.block(tower, { name = "TowerWall", size = Vector3.new(2, 64, 18), cf = towerCf * CFrame.new(x, 32, 0), color = Color3.fromRGB(64, 56, 54), material = Enum.Material.Brick })
	end
	B.block(tower, { name = "TowerWall", size = Vector3.new(18, 64, 2), cf = towerCf * CFrame.new(0, 32, 8), color = Color3.fromRGB(64, 56, 54), material = Enum.Material.Brick })
	B.block(tower, { name = "TowerFront", size = Vector3.new(18, 54, 2), cf = towerCf * CFrame.new(0, 37, -8), color = Color3.fromRGB(64, 56, 54), material = Enum.Material.Brick })
	B.block(tower, { name = "TowerRoof", size = Vector3.new(20, 4, 20), cf = towerCf * CFrame.new(0, 66, 0), color = Color3.fromRGB(36, 30, 30), material = Enum.Material.Slate })
	B.block(tower, { name = "Spire", size = Vector3.new(6, 16, 6), cf = towerCf * CFrame.new(0, 76, 0), color = Color3.fromRGB(36, 30, 30), material = Enum.Material.Slate })
	local face = B.block(tower, { name = "ClockFace", size = Vector3.new(0.6, 12, 12), cf = towerCf * CFrame.new(0, 52, -9.2) * CFrame.Angles(0, math.pi / 2, 0), color = Color3.fromRGB(230, 220, 190), material = Enum.Material.Neon, shape = Enum.PartType.Cylinder, collide = false })
	face.Transparency = 0.2
	B.block(tower, { name = "Hand", size = Vector3.new(0.6, 5, 0.3), cf = towerCf * CFrame.new(0, 53.5, -9.6), color = Color3.new(0, 0, 0), collide = false })
	B.block(tower, { name = "Hand", size = Vector3.new(3.4, 0.6, 0.3), cf = towerCf * CFrame.new(1.4, 52, -9.6), color = Color3.new(0, 0, 0), collide = false })
	local faceLight = Instance.new("SurfaceLight")
	faceLight.Face = Enum.NormalId.Right
	faceLight.Range = 30
	faceLight.Brightness = 1
	faceLight.Color = Color3.fromRGB(230, 220, 190)
	faceLight.Parent = face
	local rope = B.block(tower, { name = "BellRope", size = Vector3.new(0.4, 8, 0.4), cf = towerCf * CFrame.new(0, 4, -4), color = Color3.fromRGB(150, 120, 80), material = Enum.Material.Fabric, collide = false })
	info.act1.bellPrompt = B.prompt(rope, "Ring the bell", "Clock Tower", 1.2, 9)
	info.act1.tower = (towerCf * CFrame.new(0, 0, -14)).Position

	-- Invisible wall around the map edge so nobody wanders off the torn edge by accident.
	B.debrisField(folder, origin, 520, 70, rng)
	info.act1.bounds = { min = origin - Vector3.new(150, 0, 150), max = origin + Vector3.new(150, 0, 150) }
end

-- ACT 2 AREAS ------------------------------------------------------------------------------

local function buildHub(map: Instance, rng: Random, info)
	local folder = B.folder(map, "HollowCreek")
	buildTown(folder, Vector3.zero, 180, rng, {
		reserved = {
			{ at = Vector2.new(0, 0), r = 44 },
			{ at = Vector2.new(0, -135), r = 40 },
		},
		litWindows = 0.25,
		lampChance = 0.85,
		lampStrength = 0.9,
		cars = 14,
	})
	buildCamp(folder, Vector3.zero, rng, info)
	buildChurchyard(folder, Areas.ById.town.boss.arena, rng)
	B.debrisField(folder, Vector3.zero, 480, 50, rng)
end

local function buildWoods(map: Instance, rng: Random)
	local area = Areas.ById.woods
	local folder = B.folder(map, "WhisperingWoods")
	local c = area.center
	B.ground(folder, c, Vector2.new(300, 300), Color3.fromRGB(20, 30, 24), Enum.Material.Grass)
	B.road(folder, c + Vector3.new(-150, 0, 0), c + Vector3.new(150, 0, 0), 14, Color3.fromRGB(46, 36, 28))
	local clearing = area.boss.arena
	local placed = {}
	for _ = 1, 340 do
		if #placed >= 150 then
			break
		end
		local p = c + Vector3.new(rng:NextNumber(-145, 145), 0, rng:NextNumber(-145, 145))
		local ok = math.abs(p.Z - c.Z) > 11 and (Vector2.new(p.X, p.Z) - Vector2.new(clearing.X, clearing.Z)).Magnitude > 40 and (p - area.spawn).Magnitude > 22
		if ok then
			for _, q in placed do
				if (p - q).Magnitude < 9 then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(placed, p)
			B.tree(folder, p, rng, rng:NextNumber() < 0.3)
		end
	end
	-- Ruined cabins
	for _, offset in { Vector3.new(-80, 0, 60), Vector3.new(40, 0, 90), Vector3.new(-30, 0, -100), Vector3.new(110, 0, 40) } do
		local p = c + offset
		B.house(folder, CFrame.lookAt(p, Vector3.new(p.X, 0, c.Z)), rng, { width = 16, depth = 14, height = 10, broken = true, litWindows = 0.1, name = "Cabin" })
	end
	-- Will-o'-wisps
	for _ = 1, 26 do
		local p = c + Vector3.new(rng:NextNumber(-140, 140), rng:NextNumber(3, 9), rng:NextNumber(-140, 140))
		local wisp = B.block(folder, { name = "Wisp", size = Vector3.new(0.8, 0.8, 0.8), cf = CFrame.new(p), color = Color3.fromRGB(120, 255, 170), material = Enum.Material.Neon, collide = false, shape = Enum.PartType.Ball })
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(120, 255, 170)
		l.Range = 12
		l.Brightness = 1
		l.Parent = wisp
		CollectionService:AddTag(wisp, "Bob")
	end
	-- Stone circle at the boss clearing
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local p = clearing + Vector3.new(math.cos(a), 0, math.sin(a)) * 36
		B.block(folder, { name = "Monolith", size = Vector3.new(4, rng:NextNumber(9, 14), 3), cf = CFrame.lookAt(p, clearing) * CFrame.new(0, 5, 0), color = Color3.fromRGB(56, 60, 58), material = Enum.Material.Slate })
	end
	B.block(folder, { name = "Altar", size = Vector3.new(8, 2, 5), cf = CFrame.new(clearing + Vector3.new(0, 1, 0)), color = Color3.fromRGB(46, 50, 48), material = Enum.Material.Slate })
	B.debrisField(folder, c, 420, 35, rng)
end

local function buildRift(map: Instance, rng: Random)
	local area = Areas.ById.rift
	local folder = B.folder(map, "TheRift")
	local islands = {
		{ p = Vector3.new(810, 0, 0), r = 22 },
		{ p = Vector3.new(855, 0, -48), r = 26 },
		{ p = Vector3.new(865, 0, 52), r = 24 },
		{ p = Vector3.new(912, 0, -86), r = 22 },
		{ p = Vector3.new(918, 0, 92), r = 24 },
		{ p = area.boss.arena, r = 46 },
		{ p = Vector3.new(1045, 0, 0), r = 22 },
		{ p = Vector3.new(1010, 0, -82), r = 20 },
		{ p = Vector3.new(1012, 0, 84), r = 20 },
	}
	for _, island in islands do
		B.island(folder, island.p, island.r, rng)
	end
	local links = { { 1, 2 }, { 1, 3 }, { 2, 4 }, { 3, 5 }, { 4, 6 }, { 5, 6 }, { 2, 6 }, { 3, 6 }, { 6, 7 }, { 4, 8 }, { 8, 7 }, { 5, 9 }, { 9, 7 } }
	for _, link in links do
		local a, b = islands[link[1]], islands[link[2]]
		local dir = (b.p - a.p).Unit
		B.walkway(folder, a.p + dir * (a.r - 3), b.p - dir * (b.r - 3), 8)
	end
	B.debrisField(folder, area.center, 380, 90, rng)
end

local function buildCathedral(map: Instance, rng: Random)
	local area = Areas.ById.cathedral
	local folder = B.folder(map, "SunkenCathedral")
	local c = area.center
	B.ground(folder, c, Vector2.new(280, 280), Color3.fromRGB(36, 40, 46), Enum.Material.Slate)
	-- Flood water (walk-through)
	B.block(folder, { name = "Floodwater", size = Vector3.new(280, 1, 280), cf = CFrame.new(c + Vector3.new(0, 0.4, 0)), color = Color3.fromRGB(10, 22, 36), material = Enum.Material.Glass, transparency = 0.45, collide = false })
	-- The nave
	local nave = area.boss.arena
	local length, width, height = 120, 72, 46
	local wallColor = Color3.fromRGB(70, 74, 82)
	local function wall(size: Vector3, offset: Vector3)
		B.block(folder, { name = "NaveWall", size = size, cf = CFrame.new(nave + offset), color = wallColor, material = Enum.Material.Slate })
	end
	wall(Vector3.new(length, height, 3), Vector3.new(0, height / 2, -width / 2))
	wall(Vector3.new(length, height, 3), Vector3.new(0, height / 2, width / 2))
	wall(Vector3.new(3, height, width), Vector3.new(length / 2, height / 2, 0))
	-- West wall with a great doorway
	local doorW = 22
	local sideW = (width - doorW) / 2
	wall(Vector3.new(3, height, sideW), Vector3.new(-length / 2, height / 2, -(doorW / 2 + sideW / 2)))
	wall(Vector3.new(3, height, sideW), Vector3.new(-length / 2, height / 2, doorW / 2 + sideW / 2))
	wall(Vector3.new(3, height - 28, doorW), Vector3.new(-length / 2, 28 + (height - 28) / 2, 0))
	-- Columns
	for x = -length / 2 + 14, length / 2 - 14, 16 do
		for _, z in { -24, 24 } do
			local broken = rng:NextNumber() < 0.25
			local h = broken and rng:NextNumber(12, 26) or height
			B.block(folder, { name = "Column", size = Vector3.new(h, 4.5, 4.5), cf = CFrame.new(nave + Vector3.new(x, h / 2, z)) * CFrame.Angles(0, 0, math.pi / 2), color = Color3.fromRGB(84, 88, 96), material = Enum.Material.Marble, shape = Enum.PartType.Cylinder })
		end
	end
	-- Partial roof beams
	for x = -length / 2 + 8, length / 2 - 8, 22 do
		if rng:NextNumber() < 0.6 then
			B.block(folder, { name = "Beam", size = Vector3.new(3, 3, width), cf = CFrame.new(nave + Vector3.new(x, height - 2, 0)), color = Color3.fromRGB(46, 40, 38), material = Enum.Material.Wood })
		end
	end
	-- Rose window
	local rose = B.block(folder, { name = "RoseWindow", size = Vector3.new(1, 20, 20), cf = CFrame.new(nave + Vector3.new(length / 2 - 1.8, 30, 0)), color = Color3.fromRGB(90, 150, 255), material = Enum.Material.Neon, shape = Enum.PartType.Cylinder, collide = false })
	rose.Transparency = 0.3
	local roseLight = Instance.new("SurfaceLight")
	roseLight.Face = Enum.NormalId.Left
	roseLight.Range = 60
	roseLight.Angle = 70
	roseLight.Brightness = 2
	roseLight.Color = Color3.fromRGB(110, 160, 255)
	roseLight.Parent = rose
	-- Pews
	for x = -length / 2 + 10, length / 2 - 30, 9 do
		for _, z in { -13, 13 } do
			if rng:NextNumber() < 0.7 then
				B.block(folder, { name = "Pew", size = Vector3.new(2, 2.4, 14), cf = CFrame.new(nave + Vector3.new(x, 1.2, z)) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.15, 0.15)), color = Color3.fromRGB(56, 38, 28), material = Enum.Material.Wood })
			end
		end
	end
	-- Graveyard and broken arches outside
	for _ = 1, 40 do
		local p = c + Vector3.new(rng:NextNumber(-130, -10), 0, rng:NextNumber(-130, 130))
		if math.abs(p.Z) > 14 then
			B.block(folder, { name = "Grave", size = Vector3.new(2.6, rng:NextNumber(2.5, 5), 0.8), cf = CFrame.new(p + Vector3.new(0, 1.6, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), rng:NextNumber(0, 6), 0), color = Color3.fromRGB(64, 68, 74), material = Enum.Material.Slate })
		end
	end
	for _ = 1, 10 do
		local p = c + Vector3.new(rng:NextNumber(-130, 130), 0, rng:NextNumber(-130, 130))
		if (Vector2.new(p.X, p.Z) - Vector2.new(nave.X, nave.Z)).Magnitude > 80 then
			local yaw = rng:NextNumber(0, 6)
			local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
			B.block(folder, { name = "ArchLeg", size = Vector3.new(3, 18, 3), cf = cf * CFrame.new(-6, 9, 0), color = Color3.fromRGB(80, 84, 92), material = Enum.Material.Slate })
			B.block(folder, { name = "ArchLeg", size = Vector3.new(3, rng:NextNumber(6, 18), 3), cf = cf * CFrame.new(6, 4, 0), color = Color3.fromRGB(80, 84, 92), material = Enum.Material.Slate })
			if rng:NextNumber() < 0.5 then
				B.block(folder, { name = "ArchTop", size = Vector3.new(16, 3, 3), cf = cf * CFrame.new(0, 19, 0), color = Color3.fromRGB(80, 84, 92), material = Enum.Material.Slate })
			end
		end
	end
	B.debrisField(folder, c, 420, 40, rng)
end

local function buildHeart(map: Instance, rng: Random)
	local area = Areas.ById.heart
	local folder = B.folder(map, "HeartOfShadow")
	local c = area.center
	B.block(folder, { name = "Platform", size = Vector3.new(8, 280, 280), cf = CFrame.new(c - Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.pi / 2), color = Color3.fromRGB(12, 10, 14), material = Enum.Material.Basalt, shape = Enum.PartType.Cylinder, floor = true })
	-- Veins of red light running out from the centre
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local len = rng:NextNumber(70, 130)
		local mid = c + Vector3.new(math.cos(a), 0, math.sin(a)) * (len / 2 + 10)
		local vein = B.block(folder, { name = "Vein", size = Vector3.new(1.2, 0.2, len), cf = CFrame.lookAt(mid, c) + Vector3.new(0, 0.05, 0), color = Color3.fromRGB(200, 20, 40), material = Enum.Material.Neon, collide = false })
		CollectionService:AddTag(vein, "Pulse")
	end
	-- Obsidian spikes around the rim
	for i = 0, 35 do
		local a = i / 36 * math.pi * 2
		local h = rng:NextNumber(10, 30)
		local p = c + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(128, 138)
		B.block(folder, { class = "WedgePart", name = "Spike", size = Vector3.new(4, h, 4), cf = CFrame.lookAt(p, c) * CFrame.new(0, h / 2, 0), color = Color3.fromRGB(16, 12, 18), material = Enum.Material.Glass })
	end
	-- The heart itself, floating above the arena
	local heartPos = c + Vector3.new(60, 70, 0)
	local heart = B.block(folder, { name = "ShadowHeart", size = Vector3.new(48, 48, 48), cf = CFrame.new(heartPos), color = Color3.new(0, 0, 0), material = Enum.Material.Neon, shape = Enum.PartType.Ball, collide = false })
	CollectionService:AddTag(heart, "Heartbeat")
	for _ = 1, 14 do
		local dir = rng:NextUnitVector()
		local crack = B.block(folder, { name = "Crack", size = Vector3.new(0.8, 0.8, rng:NextNumber(8, 18)), cf = CFrame.lookAt(heartPos + dir * 23.6, heartPos + dir * 30) * CFrame.Angles(0, 0, rng:NextNumber(0, 3)), color = Color3.fromRGB(255, 30, 50), material = Enum.Material.Neon, collide = false })
		CollectionService:AddTag(crack, "Pulse")
	end
	local heartLight = Instance.new("PointLight")
	heartLight.Color = Color3.fromRGB(255, 30, 50)
	heartLight.Range = 60
	heartLight.Brightness = 3
	heartLight.Parent = heart
	B.debrisField(folder, c, 400, 70, rng)
end

local function buildSky(map: Instance)
	local sky = B.folder(map, "Sky")
	-- A black eclipse with a violet corona hanging over the whole world.
	local at = Vector3.new(700, 520, -900)
	local corona = B.block(sky, { name = "Corona", size = Vector3.new(2, 330, 330), cf = CFrame.lookAt(at, Vector3.new(700, 0, 0)) * CFrame.Angles(0, math.pi / 2, 0), color = Color3.fromRGB(130, 70, 255), material = Enum.Material.Neon, shape = Enum.PartType.Cylinder, collide = false })
	corona.Transparency = 0.35
	B.block(sky, { name = "Eclipse", size = Vector3.new(300, 300, 300), cf = CFrame.new(at + (Vector3.new(700, 0, 0) - at).Unit * 8), color = Color3.new(0, 0, 0), material = Enum.Material.Neon, shape = Enum.PartType.Ball, collide = false })
end

function WorldBuilder.Build()
	local rng = Random.new(1347)
	local map = workspace:FindFirstChild("Map")
	if map then
		map:Destroy()
	end
	map = B.folder(workspace, "Map")
	B.Floors = B.folder(map, "Floors")

	local info = { act1 = {} }
	buildAct1(map, rng, info)
	buildHub(map, rng, info)
	buildWoods(map, rng)
	buildRift(map, rng)
	buildCathedral(map, rng)
	buildHeart(map, rng)
	buildSky(map)

	-- Bridges and gates between the areas
	local bridges = B.folder(map, "Bridges")
	B.bridge(bridges, 178, 332, 0, 22)
	B.bridge(bridges, 628, 790, 0, 22)
	B.bridge(bridges, 1065, 1202, 0, 22)
	B.bridge(bridges, 1478, 1622, 0, 22)
	for _, area in Areas.List do
		if area.gateX then
			B.gate(bridges, area.gateX, 0, 22, area.level, area.name)
		end
	end

	info.floors = B.Floors
	info.map = map
	return info
end

-- Finds walkable points inside a box: raycasts down onto floor parts and rejects points
-- that are cramped by walls or props. Call after the world has been built.
function WorldBuilder.SamplePoints(floors: Folder, minCorner: Vector3, maxCorner: Vector3, count: number, rng: Random, avoid: { { at: Vector3, r: number } }?)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { floors }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { floors }
	local points = {}
	local attempts = 0
	while #points < count and attempts < count * 25 do
		attempts += 1
		local x = rng:NextNumber(minCorner.X, maxCorner.X)
		local z = rng:NextNumber(minCorner.Z, maxCorner.Z)
		local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), rayParams)
		if hit and hit.Position.Y > -10 then
			local p = hit.Position
			local ok = true
			if avoid then
				for _, zone in avoid do
					if (Vector2.new(p.X, p.Z) - Vector2.new(zone.at.X, zone.at.Z)).Magnitude < zone.r then
						ok = false
						break
					end
				end
			end
			if ok then
				for _, other in workspace:GetPartBoundsInRadius(p + Vector3.new(0, 3.5, 0), 3.2, overlap) do
					if other.Anchored and other.CanCollide then
						ok = false
						break
					end
				end
			end
			if ok then
				table.insert(points, p)
			end
		end
	end
	return points
end

return WorldBuilder
