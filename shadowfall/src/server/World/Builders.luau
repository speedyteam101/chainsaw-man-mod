--!nonstrict
-- Small procedural building blocks: ground, houses, lamps, trees, cars, bridges, gates.
-- Everything is anchored, blocky and made of plain parts, so the whole world is generated
-- from code and needs no uploaded assets.

local CollectionService = game:GetService("CollectionService")

local B = {}

B.Floors = nil :: Folder? -- set by WorldBuilder; walkable surfaces go here (used for spawn raycasts)

type BlockProps = {
	name: string?,
	size: Vector3,
	cf: CFrame,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	collide: boolean?,
	shape: Enum.PartType?,
	floor: boolean?,
	class: string?,
}

function B.block(parent: Instance, props: BlockProps): BasePart
	local p: BasePart = (Instance.new((props.class or "Part") :: any) :: any)
	p.Name = props.name or "Block"
	p.Anchored = true
	p.Size = props.size
	p.CFrame = props.cf
	p.Color = props.color or Color3.fromRGB(40, 40, 45)
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.CanCollide = props.collide ~= false
	-- Decorations you can walk through shouldn't stop projectiles or spawn raycasts either.
	p.CanQuery = p.CanCollide
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape and p:IsA("Part") then
		p.Shape = props.shape
	end
	if props.floor and B.Floors then
		p.Parent = B.Floors
		-- Remember which model owns this floor piece (so a house can be demolished completely).
		if parent:IsA("Model") then
			local ref = Instance.new("ObjectValue")
			ref.Name = "FloorRef"
			ref.Value = p
			ref.Parent = parent
		end
	else
		p.Parent = parent
	end
	return p
end

function B.folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Terrain ground: real grass, mud, rock and water instead of flat plates. The top of the fill
-- sits at center.Y. Terrain isn't in the Floors folder, so spawn and ground raycasts include
-- workspace.Terrain as well (see WorldBuilder.GroundFilter).
function B.ground(_parent: Instance, center: Vector3, size: Vector2, _color: Color3, material: Enum.Material, thickness: number?)
	local t = thickness or 12
	workspace.Terrain:FillBlock(CFrame.new(center - Vector3.new(0, t / 2, 0)), Vector3.new(size.X, t, size.Y), material)
end

function B.terrainBall(center: Vector3, radius: number, material: Enum.Material)
	workspace.Terrain:FillBall(center, radius, material)
end

function B.terrainBlock(cf: CFrame, size: Vector3, material: Enum.Material)
	workspace.Terrain:FillBlock(cf, size, material)
end

-- Gloomy, realistic terrain colours and still, dark water.
function B.setupTerrain()
	local terrain = workspace.Terrain
	terrain:Clear()
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(62, 74, 50))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(54, 66, 42))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(74, 62, 50))
	terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(62, 50, 40))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(84, 82, 86))
	terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(72, 74, 80))
	terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(32, 28, 32))
	terrain.WaterColor = Color3.fromRGB(22, 32, 40)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.05
	terrain.WaterWaveSpeed = 4
	terrain.WaterReflectance = 0.4
end


-- A flat road strip, slightly raised above the ground so it never z-fights.
function B.road(parent: Instance, from: Vector3, to: Vector3, width: number, color: Color3?)
	local mid = (from + to) / 2
	local length = (to - from).Magnitude
	return B.block(parent, {
		name = "Road",
		size = Vector3.new(width, 0.4, length),
		cf = CFrame.lookAt(mid, to) + Vector3.new(0, 0.2, 0),
		color = color or Color3.fromRGB(28, 28, 32),
		material = Enum.Material.Asphalt,
		floor = true,
	})
end

-- A cast-iron street lamp with a curved arm and a glass lantern. The client flickers it.
function B.lamp(parent: Instance, position: Vector3, color: Color3?, strength: number?, flicker: boolean?, facing: Vector3?)
	local model = Instance.new("Model")
	model.Name = "StreetLamp"
	local iron = Color3.fromRGB(26, 28, 30)
	local dir = facing and Vector3.new(facing.X, 0, facing.Z).Unit or Vector3.new(0, 0, -1)
	local base = CFrame.lookAt(position, position + dir)
	B.block(model, { name = "Base", size = Vector3.new(1.2, 1.4, 1.2), cf = base * CFrame.new(0, 0.7, 0), color = iron, material = Enum.Material.Metal })
	B.block(model, { name = "Pole", size = Vector3.new(14, 0.5, 0.5), cf = base * CFrame.new(0, 7.6, 0) * CFrame.Angles(0, 0, math.pi / 2), color = iron, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder })
	B.block(model, { name = "Arm", size = Vector3.new(0.3, 0.3, 3.2), cf = base * CFrame.new(0, 14.3, -1.4), color = iron, material = Enum.Material.Metal })
	B.block(model, { name = "Brace", size = Vector3.new(0.2, 0.2, 2), cf = base * CFrame.new(0, 13.4, -0.8) * CFrame.Angles(math.rad(-40), 0, 0), color = iron, material = Enum.Material.Metal, collide = false })
	B.block(model, { name = "Cap", size = Vector3.new(1.8, 0.4, 1.8), cf = base * CFrame.new(0, 14.1, -2.9), color = iron, material = Enum.Material.Metal, collide = false })
	local bulb = B.block(model, {
		name = "Bulb",
		size = Vector3.new(1.1, 1.1, 1.1),
		cf = base * CFrame.new(0, 13.3, -2.9),
		color = color or Color3.fromRGB(255, 200, 120),
		material = Enum.Material.Neon,
		collide = false,
	})
	B.block(model, { name = "Glass", size = Vector3.new(1.5, 1.4, 1.5), cf = bulb.CFrame, color = Color3.fromRGB(255, 230, 180), material = Enum.Material.Glass, transparency = 0.6, collide = false })
	local light = Instance.new("PointLight")
	light.Color = color or Color3.fromRGB(255, 190, 110)
	light.Range = 28
	light.Brightness = 1.6 * (strength or 1)
	light.Shadows = false -- dozens of lamps: shadow-casting all of them would be too slow
	light.Parent = bulb
	if flicker ~= false then
		CollectionService:AddTag(bulb, "FlickerLight")
	end
	model.Parent = parent
	return model
end


local SIDING = {
	Color3.fromRGB(196, 190, 176), Color3.fromRGB(150, 160, 168), Color3.fromRGB(170, 176, 150),
	Color3.fromRGB(184, 168, 140), Color3.fromRGB(120, 132, 146), Color3.fromRGB(200, 198, 190),
	Color3.fromRGB(146, 120, 104),
}
local ROOFS = {
	Color3.fromRGB(58, 52, 50), Color3.fromRGB(44, 48, 56), Color3.fromRGB(70, 46, 40), Color3.fromRGB(54, 56, 50),
}
local TRIM = Color3.fromRGB(226, 222, 212)

export type HouseOptions = {
	width: number?,
	depth: number?,
	height: number?,
	litWindows: number?, -- chance (0-1) a window glows
	broken: boolean?, -- missing roof chunks
	name: string?,
	porch: boolean?, -- default true
	yard: number?, -- distance from the front wall to the sidewalk (walkway + mailbox)
}

-- A framed window on a wall. `cf` is the centre of the window on the wall's outer face, with its
-- look direction (-Z) pointing away from the house.
local function window(model: Model, cf: CFrame, width: number, height: number, glowing: boolean)
	local glassColor = glowing and Color3.fromRGB(255, 190, 110) or Color3.fromRGB(14, 18, 24)
	local glass = B.block(model, {
		name = "Window",
		size = Vector3.new(width, height, 0.2),
		cf = cf * CFrame.new(0, 0, -0.1),
		color = glassColor,
		material = glowing and Enum.Material.Neon or Enum.Material.Glass,
		transparency = glowing and 0.45 or 0.15,
		collide = false,
	})
	glass.Reflectance = glowing and 0 or 0.15
	local t = 0.3
	B.block(model, { name = "Frame", size = Vector3.new(width + t * 2, t, 0.4), cf = cf * CFrame.new(0, height / 2 + t / 2, 0), color = TRIM, material = Enum.Material.Wood })
	B.block(model, { name = "Sill", size = Vector3.new(width + t * 3, t, 0.7), cf = cf * CFrame.new(0, -height / 2 - t / 2, -0.3), color = TRIM, material = Enum.Material.Wood })
	B.block(model, { name = "Frame", size = Vector3.new(t, height, 0.4), cf = cf * CFrame.new(-width / 2 - t / 2, 0, 0), color = TRIM, material = Enum.Material.Wood })
	B.block(model, { name = "Frame", size = Vector3.new(t, height, 0.4), cf = cf * CFrame.new(width / 2 + t / 2, 0, 0), color = TRIM, material = Enum.Material.Wood })
	B.block(model, { name = "Mullion", size = Vector3.new(0.15, height, 0.12), cf = cf * CFrame.new(0, 0, -0.22), color = TRIM, material = Enum.Material.Wood, collide = false })
	B.block(model, { name = "Mullion", size = Vector3.new(width, 0.15, 0.12), cf = cf * CFrame.new(0, 0, -0.22), color = TRIM, material = Enum.Material.Wood, collide = false })
end

-- A hollow, enterable two-storey-or-bungalow house with siding, trim, framed windows, an open
-- front door, a porch with steps, an overhanging gable roof, a chimney, and a front walk with a
-- mailbox. The door is on the front face (the CFrame's look direction). Floor top is at y = 0.6.
function B.house(parent: Instance, cf: CFrame, rng: Random, options: HouseOptions?)
	local o = options or {}
	local w = o.width or rng:NextInteger(18, 24)
	local d = o.depth or rng:NextInteger(16, 22)
	local twoStorey = o.height == nil and rng:NextNumber() < 0.35
	local h = o.height or (twoStorey and rng:NextInteger(19, 21) or rng:NextInteger(11, 13))
	local t = 1
	local brick = rng:NextNumber() < 0.2
	local wallColor = brick and Color3.fromRGB(120, 66, 52) or SIDING[rng:NextInteger(1, #SIDING)]
	local wallMaterial = brick and Enum.Material.Brick or Enum.Material.WoodPlanks
	local roofColor = ROOFS[rng:NextInteger(1, #ROOFS)]
	local lit = o.litWindows or 0.15
	local model = Instance.new("Model")
	model.Name = o.name or "House"

	local function wall(size: Vector3, offset: Vector3)
		return B.block(model, { name = "Wall", size = size, cf = cf * CFrame.new(offset), color = wallColor, material = wallMaterial })
	end

	-- Floor, foundation and ceiling(s)
	B.block(model, { name = "Floor", size = Vector3.new(w, 0.6, d), cf = cf * CFrame.new(0, 0.3, 0), color = Color3.fromRGB(96, 70, 50), material = Enum.Material.WoodPlanks, floor = true })
	for _, side in { { Vector3.new(w + 0.8, 1.2, 0.4), Vector3.new(0, 0.3, -d / 2 - 0.2) }, { Vector3.new(w + 0.8, 1.2, 0.4), Vector3.new(0, 0.3, d / 2 + 0.2) }, { Vector3.new(0.4, 1.2, d), Vector3.new(-w / 2 - 0.2, 0.3, 0) }, { Vector3.new(0.4, 1.2, d), Vector3.new(w / 2 + 0.2, 0.3, 0) } } do
		B.block(model, { name = "Foundation", size = side[1], cf = cf * CFrame.new(side[2]), color = Color3.fromRGB(110, 106, 102), material = Enum.Material.Concrete })
	end
	B.block(model, { name = "Ceiling", size = Vector3.new(w, 0.6, d), cf = cf * CFrame.new(0, h, 0), color = Color3.fromRGB(70, 66, 62), material = Enum.Material.SmoothPlastic })

	-- Walls: back and sides solid, front with a doorway (5 wide, 8 tall)
	wall(Vector3.new(w, h, t), Vector3.new(0, h / 2, d / 2 - t / 2))
	wall(Vector3.new(t, h, d), Vector3.new(-w / 2 + t / 2, h / 2, 0))
	wall(Vector3.new(t, h, d), Vector3.new(w / 2 - t / 2, h / 2, 0))
	local doorW, doorH = 5, 8
	local side = (w - doorW) / 2
	wall(Vector3.new(side, h, t), Vector3.new(-w / 2 + side / 2, h / 2, -d / 2 + t / 2))
	wall(Vector3.new(side, h, t), Vector3.new(w / 2 - side / 2, h / 2, -d / 2 + t / 2))
	wall(Vector3.new(doorW, h - doorH, t), Vector3.new(0, doorH + (h - doorH) / 2, -d / 2 + t / 2))

	-- Corner boards and a band between storeys
	for _, x in { -w / 2, w / 2 } do
		for _, z in { -d / 2, d / 2 } do
			B.block(model, { name = "CornerBoard", size = Vector3.new(0.5, h, 0.5), cf = cf * CFrame.new(x, h / 2 + 0.3, z), color = TRIM, material = Enum.Material.Wood })
		end
	end
	if twoStorey then
		B.block(model, { name = "Band", size = Vector3.new(w + 0.3, 0.4, d + 0.3), cf = cf * CFrame.new(0, h / 2, 0), color = TRIM, material = Enum.Material.Wood, collide = false })
		B.block(model, { name = "Floor2", size = Vector3.new(w - 2, 0.4, d - 2), cf = cf * CFrame.new(0, h / 2, 2), color = Color3.fromRGB(80, 60, 44), material = Enum.Material.WoodPlanks })
	end

	-- Door frame and a door hanging open against the inside wall
	B.block(model, { name = "DoorFrame", size = Vector3.new(0.4, doorH, 1.2), cf = cf * CFrame.new(-doorW / 2 - 0.2, doorH / 2 + 0.6, -d / 2 + 0.5), color = TRIM, material = Enum.Material.Wood })
	B.block(model, { name = "DoorFrame", size = Vector3.new(0.4, doorH, 1.2), cf = cf * CFrame.new(doorW / 2 + 0.2, doorH / 2 + 0.6, -d / 2 + 0.5), color = TRIM, material = Enum.Material.Wood })
	B.block(model, { name = "DoorFrame", size = Vector3.new(doorW + 0.8, 0.4, 1.2), cf = cf * CFrame.new(0, doorH + 0.6, -d / 2 + 0.5), color = TRIM, material = Enum.Material.Wood })
	local doorCf = cf * CFrame.new(-doorW / 2, 0.6, -d / 2 + t) * CFrame.Angles(0, math.rad(rng:NextNumber(70, 95)), 0) * CFrame.new(-(doorW - 0.4) / 2, doorH / 2 - 0.2, 0)
	B.block(model, { name = "Door", size = Vector3.new(doorW - 0.4, doorH - 0.4, 0.3), cf = doorCf, color = Color3.fromRGB(70, 40, 32), material = Enum.Material.Wood, collide = false })
	B.block(model, { name = "Knob", size = Vector3.new(0.25, 0.25, 0.5), cf = doorCf * CFrame.new((doorW - 0.4) / 2 - 0.5, -0.4, 0), color = Color3.fromRGB(180, 150, 80), material = Enum.Material.Metal, collide = false })

	-- Windows on every side (some faintly lit from inside)
	local storeys = twoStorey and { h * 0.27, h * 0.75 } or { h * 0.52 }
	for _, y in storeys do
		for _, x in { -w / 2 + side / 2, w / 2 - side / 2 } do
			window(model, cf * CFrame.new(x, y, -d / 2), 3, 3.6, rng:NextNumber() < lit)
		end
		for _, x in { -w / 4, w / 4 } do
			window(model, cf * CFrame.new(x, y, d / 2) * CFrame.Angles(0, math.pi, 0), 3, 3.6, rng:NextNumber() < lit)
		end
		for _, s in { -1, 1 } do
			window(model, cf * CFrame.new(s * w / 2, y, 0) * CFrame.Angles(0, -s * math.pi / 2, 0), 3, 3.6, rng:NextNumber() < lit)
		end
	end

	-- Gable roof with eaves overhanging the walls. A wedge's tall face is its back (+Z), so each one
	-- is turned to put that face at the ridge.
	local roofH = math.max(5, w * 0.3)
	local eave = 1.4
	for _, sideSign in { -1, 1 } do
		local wedge = B.block(model, {
			class = "WedgePart",
			name = "Roof",
			size = Vector3.new(d + eave * 2, roofH, w / 2 + eave),
			cf = cf * CFrame.new(sideSign * (w / 4 + eave / 2), h + 0.3 + roofH / 2, 0) * CFrame.Angles(0, -sideSign * math.pi / 2, 0),
			color = roofColor,
			material = Enum.Material.Slate,
		})
		if o.broken and rng:NextNumber() < 0.5 then
			wedge.Transparency = 1
			wedge.CanCollide = false
			wedge.CanQuery = false
		end
	end
	-- Gable end triangles (fill the wall under the roof)
	for _, z in { -d / 2 + t / 2, d / 2 - t / 2 } do
		for _, sideSign in { -1, 1 } do
			B.block(model, {
				class = "WedgePart",
				name = "Gable",
				size = Vector3.new(t, roofH, w / 2),
				cf = cf * CFrame.new(sideSign * w / 4, h + 0.3 + roofH / 2, z) * CFrame.Angles(0, -sideSign * math.pi / 2, 0),
				color = wallColor,
				material = wallMaterial,
			})
		end
	end
	if rng:NextNumber() < 0.7 then
		local chimneyCf = cf * CFrame.new(w / 4 + rng:NextNumber(-1, 1), h + roofH * 0.6, d / 4)
		B.block(model, { name = "Chimney", size = Vector3.new(2.4, roofH + 3, 2.4), cf = chimneyCf, color = Color3.fromRGB(104, 58, 46), material = Enum.Material.Brick })
		B.block(model, { name = "ChimneyCap", size = Vector3.new(2.9, 0.4, 2.9), cf = chimneyCf * CFrame.new(0, (roofH + 3) / 2, 0), color = Color3.fromRGB(80, 80, 80), material = Enum.Material.Concrete })
	end

	-- Porch, steps, posts, a small roof and (sometimes) a porch light
	if o.porch ~= false then
		local porchW, porchD = math.min(w * 0.6, 12), 4
		local porchCf = cf * CFrame.new(0, 0, -d / 2 - porchD / 2)
		B.block(model, { name = "Porch", size = Vector3.new(porchW, 0.6, porchD), cf = porchCf * CFrame.new(0, 0.3, 0), color = Color3.fromRGB(110, 90, 72), material = Enum.Material.WoodPlanks, floor = true })
		B.block(model, { name = "Step", size = Vector3.new(4, 0.3, 1.2), cf = porchCf * CFrame.new(0, 0.15, -porchD / 2 - 0.6), color = Color3.fromRGB(120, 116, 110), material = Enum.Material.Concrete, floor = true })
		for _, x in { -porchW / 2 + 0.3, porchW / 2 - 0.3 } do
			B.block(model, { name = "PorchPost", size = Vector3.new(0.5, 8, 0.5), cf = porchCf * CFrame.new(x, 4.6, -porchD / 2 + 0.3), color = TRIM, material = Enum.Material.Wood })
			B.block(model, { name = "Rail", size = Vector3.new(0.25, 0.25, porchD - 0.6), cf = porchCf * CFrame.new(x, 3, 0), color = TRIM, material = Enum.Material.Wood })
		end
		B.block(model, { name = "PorchRoof", size = Vector3.new(porchW + 1, 0.4, porchD + 0.6), cf = porchCf * CFrame.new(0, 8.8, -0.3) * CFrame.Angles(math.rad(-8), 0, 0), color = roofColor, material = Enum.Material.Slate })
		if rng:NextNumber() < 0.35 then
			local lamp = B.block(model, { name = "PorchLight", size = Vector3.new(0.5, 0.7, 0.5), cf = cf * CFrame.new(doorW / 2 + 1, 7.5, -d / 2 - 0.4), color = Color3.fromRGB(255, 200, 130), material = Enum.Material.Neon, collide = false })
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 190, 120)
			light.Range = 14
			light.Brightness = 0.9
			light.Parent = lamp
			CollectionService:AddTag(lamp, "FlickerLight")
		end
	end

	-- Front walk and mailbox out to the sidewalk
	if o.yard and o.yard > d / 2 + 5 then
		local fromZ, toZ = -d / 2 - 4.6, -o.yard
		local length = fromZ - toZ
		B.block(model, { name = "Walkway", size = Vector3.new(3.2, 0.3, length), cf = cf * CFrame.new(0, 0.15, (fromZ + toZ) / 2), color = Color3.fromRGB(118, 116, 112), material = Enum.Material.Concrete, floor = true })
		local post = cf * CFrame.new(3.4, 0, toZ + 1)
		B.block(model, { name = "MailboxPost", size = Vector3.new(0.3, 3.2, 0.3), cf = post * CFrame.new(0, 1.6, 0), color = Color3.fromRGB(70, 56, 44), material = Enum.Material.Wood })
		B.block(model, { name = "Mailbox", size = Vector3.new(0.8, 0.8, 1.6), cf = post * CFrame.new(0, 3.5, 0), color = Color3.fromRGB(40, 44, 50), material = Enum.Material.Metal })
		-- A hedge or two along the front
		for _, x in { -w / 2 + 2.5, w / 2 - 2.5 } do
			if rng:NextNumber() < 0.7 then
				B.bush(model, (cf * CFrame.new(x, 0, -d / 2 - 2)).Position, rng)
			end
		end
	end
	model.Parent = parent
	return model, Vector3.new(w, h, d)
end


-- A tree: a round trunk with a little lean, a few branches, and a rounded canopy of overlapping
-- leaf clusters. Dead trees are bare and twisted. `position` is where it meets the ground.
function B.tree(parent: Instance, position: Vector3, rng: Random, dead: boolean?)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = rng:NextNumber(14, 24)
	local radius = rng:NextNumber(0.7, 1.2)
	local bark = Color3.fromRGB(rng:NextInteger(46, 60), rng:NextInteger(36, 44), rng:NextInteger(28, 34))
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-5, 5)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-5, 5)))
	local base = CFrame.new(position) * lean
	-- Root flare
	B.block(model, { name = "Roots", size = Vector3.new(1.6, radius * 3.4, radius * 3.4), cf = base * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2), color = bark, material = Enum.Material.Wood, shape = Enum.PartType.Cylinder })
	local trunkCf = base * CFrame.new(0, height / 2, 0)
	B.block(model, { name = "Trunk", size = Vector3.new(height, radius * 2, radius * 2), cf = trunkCf * CFrame.Angles(0, 0, math.pi / 2), color = bark, material = Enum.Material.Wood, shape = Enum.PartType.Cylinder })
	local branchCount = dead and rng:NextInteger(4, 6) or rng:NextInteger(2, 4)
	for i = 1, branchCount do
		local length = rng:NextNumber(4, dead and 9 or 7)
		local at = rng:NextNumber(height * 0.45, height * 0.9)
		local branchCf = base * CFrame.new(0, at, 0) * CFrame.Angles(0, i / branchCount * math.pi * 2 + rng:NextNumber(-0.4, 0.4), math.rad(rng:NextNumber(35, 65))) * CFrame.new(0, length / 2, 0)
		B.block(model, { name = "Branch", size = Vector3.new(length, radius * 0.7, radius * 0.7), cf = branchCf * CFrame.Angles(0, 0, math.pi / 2), color = bark, material = Enum.Material.Wood, shape = Enum.PartType.Cylinder, collide = false })
		if dead then
			local twig = rng:NextNumber(2, 4)
			B.block(model, { name = "Twig", size = Vector3.new(twig, 0.25, 0.25), cf = branchCf * CFrame.new(0, length / 2, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-40, 40))) * CFrame.new(0, twig / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), color = bark, material = Enum.Material.Wood, shape = Enum.PartType.Cylinder, collide = false })
		end
	end
	if not dead then
		local green = Color3.fromRGB(rng:NextInteger(36, 52), rng:NextInteger(54, 72), rng:NextInteger(32, 44))
		local top = base * CFrame.new(0, height, 0)
		for _ = 1, rng:NextInteger(5, 8) do
			local size = rng:NextNumber(5, 9)
			local offset = Vector3.new(rng:NextNumber(-3.5, 3.5), rng:NextNumber(-3, 2.5), rng:NextNumber(-3.5, 3.5))
			B.block(model, {
				name = "Leaves",
				size = Vector3.one * size,
				cf = top * CFrame.new(offset),
				color = green:Lerp(Color3.fromRGB(30, 40, 26), rng:NextNumber(0, 0.4)),
				material = Enum.Material.Grass,
				shape = Enum.PartType.Ball,
				collide = false,
			})
		end
	end
	model.Parent = parent
	return model
end

-- A shrub: a few overlapping rounded clumps.
function B.bush(parent: Instance, position: Vector3, rng: Random)
	local green = Color3.fromRGB(rng:NextInteger(40, 56), rng:NextInteger(58, 74), rng:NextInteger(36, 46))
	for _ = 1, rng:NextInteger(2, 4) do
		local size = rng:NextNumber(2.2, 3.6)
		B.block(parent, {
			name = "Bush",
			size = Vector3.one * size,
			cf = CFrame.new(position + Vector3.new(rng:NextNumber(-1.2, 1.2), size * 0.35, rng:NextNumber(-1.2, 1.2))),
			color = green:Lerp(Color3.fromRGB(30, 40, 26), rng:NextNumber(0, 0.4)),
			material = Enum.Material.Grass,
			shape = Enum.PartType.Ball,
			collide = false,
		})
	end
end


-- An abandoned sedan: low body, sloped hood and windshield, cabin with tinted glass, wheels
-- with hubcaps, bumpers, head and tail lights.
function B.car(parent: Instance, cf: CFrame, rng: Random)
	local model = Instance.new("Model")
	model.Name = "AbandonedCar"
	local palette = { Color3.fromRGB(110, 30, 30), Color3.fromRGB(40, 60, 90), Color3.fromRGB(180, 180, 176), Color3.fromRGB(30, 30, 32), Color3.fromRGB(70, 80, 60), Color3.fromRGB(150, 120, 70) }
	local color = palette[rng:NextInteger(1, #palette)]
	local paint = { color = color, material = Enum.Material.SmoothPlastic }
	local function piece(name: string, size: Vector3, offset: CFrame, c: Color3?, material: Enum.Material?, extra)
		local props = { name = name, size = size, cf = cf * offset, color = c or paint.color, material = material or paint.material }
		for k, v in extra or {} do
			props[k] = v
		end
		return B.block(model, props)
	end
	piece("Body", Vector3.new(6, 1.8, 13), CFrame.new(0, 1.9, 0))
	piece("Hood", Vector3.new(5.8, 0.7, 3.6), CFrame.new(0, 3.05, -4.4) * CFrame.Angles(math.rad(-4), 0, 0))
	piece("Trunk", Vector3.new(5.8, 0.7, 2.6), CFrame.new(0, 3.05, 5))
	piece("Cabin", Vector3.new(5.4, 2.2, 5.6), CFrame.new(0, 4.1, 0.6))
	piece("Windshield", Vector3.new(5.2, 2.1, 1.6), CFrame.new(0, 4.05, -2.75), Color3.fromRGB(16, 20, 26), Enum.Material.Glass, { class = "WedgePart", transparency = 0.15 })
	piece("RearGlass", Vector3.new(5.2, 2.1, 1.3), CFrame.new(0, 4.05, 4.05) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(16, 20, 26), Enum.Material.Glass, { class = "WedgePart", transparency = 0.15 })
	piece("SideGlass", Vector3.new(5.5, 1.4, 5), CFrame.new(0, 4.3, 0.6), Color3.fromRGB(16, 20, 26), Enum.Material.Glass, { transparency = 0.1, collide = false })
	piece("Roof", Vector3.new(5.5, 0.25, 5.4), CFrame.new(0, 5.25, 0.6))
	for _, z in { -6.6, 6.6 } do
		piece("Bumper", Vector3.new(6.2, 0.7, 0.5), CFrame.new(0, 1.3, z), Color3.fromRGB(60, 60, 64), Enum.Material.Metal)
	end
	for _, x in { -2.9, 2.9 } do
		for _, z in { -4.2, 4.4 } do
			piece("Tyre", Vector3.new(1, 2.6, 2.6), CFrame.new(x, 1.3, z), Color3.fromRGB(18, 18, 20), Enum.Material.Rubber, { shape = Enum.PartType.Cylinder })
			piece("Hubcap", Vector3.new(1.05, 1.3, 1.3), CFrame.new(x, 1.3, z), Color3.fromRGB(160, 160, 166), Enum.Material.Metal, { shape = Enum.PartType.Cylinder, collide = false })
		end
		piece("TailLight", Vector3.new(1.2, 0.5, 0.2), CFrame.new(x * 0.8, 2.4, 6.5), Color3.fromRGB(120, 10, 10), Enum.Material.Glass, { collide = false })
		piece("HeadlightLens", Vector3.new(1.2, 0.6, 0.2), CFrame.new(x * 0.8, 2.4, -6.5), Color3.fromRGB(200, 200, 190), Enum.Material.Glass, { collide = false })
	end
	-- Headlights left on, long since dimmed.
	if rng:NextNumber() < 0.3 then
		local lamp = piece("Headlight", Vector3.new(4.4, 0.5, 0.2), CFrame.new(0, 2.4, -6.55), Color3.fromRGB(255, 240, 200), Enum.Material.Neon, { collide = false })
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = 50
		spot.Range = 34
		spot.Brightness = 1.4
		spot.Color = Color3.fromRGB(255, 235, 190)
		spot.Shadows = true
		spot.Parent = lamp
		CollectionService:AddTag(lamp, "FlickerLight")
	end
	if rng:NextNumber() < 0.4 then
		piece("OpenDoor", Vector3.new(0.3, 2.2, 3.4), CFrame.new(3.6, 3.2, -1.2) * CFrame.Angles(0, math.rad(-50), 0), nil, nil, { collide = false })
	end
	model.Parent = parent
	return model
end

-- Street furniture ------------------------------------------------------------------------

function B.hydrant(parent: Instance, position: Vector3)
	local red = Color3.fromRGB(150, 30, 26)
	B.block(parent, { name = "Hydrant", size = Vector3.new(2, 1, 1), cf = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2), color = red, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder })
	B.block(parent, { name = "HydrantCap", size = Vector3.new(0.6, 1.2, 1.2), cf = CFrame.new(position + Vector3.new(0, 2.2, 0)), color = red, material = Enum.Material.Metal, shape = Enum.PartType.Ball })
	B.block(parent, { name = "HydrantNozzle", size = Vector3.new(1.6, 0.45, 0.45), cf = CFrame.new(position + Vector3.new(0, 1.3, 0)), color = red, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder })
end

function B.trashCan(parent: Instance, position: Vector3, rng: Random)
	local tipped = rng:NextNumber() < 0.3
	local cf = CFrame.new(position + Vector3.new(0, tipped and 0.9 or 1.6, 0)) * (tipped and CFrame.Angles(math.pi / 2, rng:NextNumber(0, 6), 0) or CFrame.new())
	B.block(parent, { name = "TrashCan", size = Vector3.new(3.2, 1.8, 1.8), cf = cf * CFrame.Angles(0, 0, math.pi / 2), color = Color3.fromRGB(60, 66, 64), material = Enum.Material.Metal, shape = Enum.PartType.Cylinder })
end

function B.powerPole(parent: Instance, position: Vector3, facing: Vector3)
	local cf = CFrame.lookAt(position, position + facing)
	B.block(parent, { name = "PowerPole", size = Vector3.new(22, 0.9, 0.9), cf = cf * CFrame.new(0, 11, 0) * CFrame.Angles(0, 0, math.pi / 2), color = Color3.fromRGB(70, 54, 40), material = Enum.Material.Wood, shape = Enum.PartType.Cylinder })
	B.block(parent, { name = "CrossArm", size = Vector3.new(0.4, 0.4, 6), cf = cf * CFrame.new(0, 20.5, 0), color = Color3.fromRGB(70, 54, 40), material = Enum.Material.Wood })
	for _, z in { -2.6, 2.6 } do
		B.block(parent, { name = "Insulator", size = Vector3.new(0.3, 0.5, 0.3), cf = cf * CFrame.new(0, 20.9, z), color = Color3.fromRGB(120, 140, 120), material = Enum.Material.Glass, collide = false })
	end
	return cf
end

-- A cable between two points that sags in the middle (two straight segments).
function B.wire(parent: Instance, a: Vector3, b: Vector3, sag: number)
	local mid = (a + b) / 2 - Vector3.new(0, sag, 0)
	for _, pair in { { a, mid }, { mid, b } } do
		local p, q = pair[1], pair[2]
		B.block(parent, { name = "Wire", size = Vector3.new(0.12, 0.12, (q - p).Magnitude), cf = CFrame.lookAt((p + q) / 2, q), color = Color3.fromRGB(16, 16, 18), material = Enum.Material.SmoothPlastic, collide = false })
	end
end

function B.streetSign(parent: Instance, position: Vector3, text: string, rng: Random)
	B.block(parent, { name = "SignPole", size = Vector3.new(0.25, 9, 0.25), cf = CFrame.new(position + Vector3.new(0, 4.5, 0)), color = Color3.fromRGB(110, 114, 118), material = Enum.Material.Metal })
	local sign = B.block(parent, { name = "StreetSign", size = Vector3.new(4.5, 0.9, 0.12), cf = CFrame.new(position + Vector3.new(0, 9, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), color = Color3.fromRGB(30, 90, 50), material = Enum.Material.Metal, collide = false })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = text
		label.Parent = gui
		gui.Parent = sign
	end
end


function B.fence(parent: Instance, from: Vector3, to: Vector3, color: Color3?)
	local direction = to - from
	local count = math.floor(direction.Magnitude / 4)
	local col = color or Color3.fromRGB(50, 42, 36)
	for i = 0, count do
		local p = from + direction.Unit * i * 4
		B.block(parent, { name = "FencePost", size = Vector3.new(0.6, 4, 0.6), cf = CFrame.new(p + Vector3.new(0, 2, 0)), color = col, material = Enum.Material.Wood })
	end
	local mid = (from + to) / 2
	for _, y in { 1.4, 3.2 } do
		B.block(parent, {
			name = "FenceRail",
			size = Vector3.new(0.3, 0.5, direction.Magnitude),
			cf = CFrame.lookAt(mid, to) + Vector3.new(0, y, 0),
			color = col,
			material = Enum.Material.Wood,
		})
	end
end

-- A wooden bridge over the void along the X axis, with railings and dim lanterns.
function B.bridge(parent: Instance, fromX: number, toX: number, z: number, width: number, y: number?)
	local model = Instance.new("Model")
	model.Name = "Bridge"
	local height = y or 0
	local length = toX - fromX
	local mid = Vector3.new((fromX + toX) / 2, height, z)
	B.block(model, {
		name = "Deck",
		size = Vector3.new(length, 2, width),
		cf = CFrame.new(mid - Vector3.new(0, 1, 0)),
		color = Color3.fromRGB(46, 36, 30),
		material = Enum.Material.WoodPlanks,
		floor = true,
	})
	for _, side in { -1, 1 } do
		B.block(model, {
			name = "Rail",
			size = Vector3.new(length, 0.6, 0.6),
			cf = CFrame.new(mid + Vector3.new(0, 3.4, side * (width / 2 - 0.4))),
			color = Color3.fromRGB(38, 30, 26),
			material = Enum.Material.Wood,
		})
		B.block(model, {
			name = "RailWall",
			size = Vector3.new(length, 3.4, 0.4),
			cf = CFrame.new(mid + Vector3.new(0, 1.7, side * (width / 2 - 0.4))),
			color = Color3.fromRGB(38, 30, 26),
			material = Enum.Material.Wood,
			transparency = 1,
		})
		local posts = math.floor(length / 30)
		for i = 0, posts do
			local x = fromX + i * (length / math.max(posts, 1))
			B.block(model, {
				name = "Post",
				size = Vector3.new(1, 5, 1),
				cf = CFrame.new(x, height + 2.5, z + side * (width / 2 - 0.4)),
				color = Color3.fromRGB(30, 24, 20),
				material = Enum.Material.Wood,
			})
			if i % 2 == 0 then
				local lantern = B.block(model, {
					name = "Lantern",
					size = Vector3.new(0.9, 1.1, 0.9),
					cf = CFrame.new(x, height + 5.6, z + side * (width / 2 - 0.4)),
					color = Color3.fromRGB(150, 110, 255),
					material = Enum.Material.Neon,
					collide = false,
				})
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(150, 110, 255)
				light.Range = 18
				light.Brightness = 1.2
				light.Parent = lantern
			end
		end
	end
	model.Parent = parent
	return model
end

-- Gate across the bridge end. The barrier is solid on the server; the client turns it
-- off locally once the player's level is high enough. The server also enforces it.
function B.gate(parent: Instance, x: number, z: number, width: number, level: number, areaName: string)
	local model = Instance.new("Model")
	model.Name = "Gate_" .. areaName
	for _, side in { -1, 1 } do
		B.block(model, {
			name = "Pillar",
			size = Vector3.new(4, 30, 4),
			cf = CFrame.new(x, 15, z + side * (width / 2 + 2)),
			color = Color3.fromRGB(16, 14, 20),
			material = Enum.Material.Slate,
		})
	end
	B.block(model, {
		name = "Lintel",
		size = Vector3.new(4, 4, width + 8),
		cf = CFrame.new(x, 32, z),
		color = Color3.fromRGB(16, 14, 20),
		material = Enum.Material.Slate,
	})
	local barrier = B.block(model, {
		name = "Barrier",
		size = Vector3.new(1.5, 30, width),
		cf = CFrame.new(x, 15, z),
		color = Color3.fromRGB(70, 20, 120),
		material = Enum.Material.ForceField,
		transparency = 0.1,
	})
	barrier:SetAttribute("Level", level)
	CollectionService:AddTag(barrier, "AreaGate")

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.SpecialElite
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(210, 180, 255)
	label.TextStrokeTransparency = 0.4
	label.Text = string.format("%s\nRequires Level %d", areaName, level)
	label.Parent = gui
	gui.Parent = barrier
	model.Parent = parent
	return barrier
end

-- Chunks of rock and pieces of houses drifting in the void around the world.
function B.debrisField(parent: Instance, center: Vector3, radius: number, count: number, rng: Random)
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(radius * 0.6, radius)
		-- Well above or below street level, never drifting through houses and roads.
		local height = rng:NextNumber() < 0.4 and rng:NextNumber(-140, -45) or rng:NextNumber(70, 180)
		local position = center + Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance)
		local size = Vector3.new(rng:NextNumber(6, 30), rng:NextNumber(4, 18), rng:NextNumber(6, 30))
		local rock = B.block(parent, {
			name = "Debris",
			size = size,
			cf = CFrame.new(position) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6), rng:NextNumber(-0.6, 0.6)),
			color = Color3.fromRGB(rng:NextInteger(18, 30), rng:NextInteger(16, 24), rng:NextInteger(22, 34)),
			material = Enum.Material.Rock,
			collide = false,
		})
		CollectionService:AddTag(rock, "Drift")
		if rng:NextNumber() < 0.25 then
			local crystal = B.block(parent, {
				name = "Crystal",
				size = Vector3.new(1.4, rng:NextNumber(4, 9), 1.4),
				cf = rock.CFrame * CFrame.new(0, size.Y / 2 + 2, 0) * CFrame.Angles(0.2, 0, 0.3),
				color = Color3.fromRGB(120, 60, 220),
				material = Enum.Material.Neon,
				collide = false,
			})
			CollectionService:AddTag(crystal, "Drift")
		end
	end
end

-- A floating island for the Rift: a terrain rock mass with a flat top at `center.Y`, plus
-- glowing crystals (returned so they can be mined).
function B.island(parent: Instance, center: Vector3, radius: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Island"
	local terrain = workspace.Terrain
	terrain:FillCylinder(CFrame.new(center - Vector3.new(0, 3, 0)), 6, radius, Enum.Material.Ground)
	terrain:FillCylinder(CFrame.new(center - Vector3.new(0, 0.6, 0)), 1.2, radius - 1, Enum.Material.LeafyGrass)
	local layers = 4
	for i = 1, layers do
		local r = radius * (1 - i / (layers + 1))
		terrain:FillBall(center - Vector3.new(rng:NextNumber(-3, 3), 4 + i * 6, rng:NextNumber(-3, 3)), r, Enum.Material.Rock)
	end
	-- Hanging chunks and roots underneath
	for _ = 1, math.floor(radius / 5) do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0, radius * 0.7)
		terrain:FillBall(center + Vector3.new(math.cos(a) * d, -rng:NextNumber(10, 26), math.sin(a) * d), rng:NextNumber(2, 5), Enum.Material.Slate)
	end
	local crystals = {}
	for _ = 1, math.floor(radius / 6) do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(radius * 0.55, radius * 0.9)
		local h = rng:NextNumber(3, 8)
		local crystal = B.block(model, {
			name = "Crystal",
			size = Vector3.new(1.6, h, 1.6),
			cf = CFrame.new(center + Vector3.new(math.cos(a) * d, h / 2 - 0.5, math.sin(a) * d)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)),
			color = Color3.fromRGB(140, 80, 255),
			material = Enum.Material.Neon,
			collide = false,
		})
		if rng:NextNumber() < 0.4 then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(150, 90, 255)
			light.Range = 16
			light.Brightness = 1
			light.Parent = crystal
		end
		table.insert(crystals, crystal)
	end
	model.Parent = parent
	return model, crystals
end


-- A narrow plank walkway between two points (for the Rift islands).
function B.walkway(parent: Instance, from: Vector3, to: Vector3, width: number)
	local mid = (from + to) / 2
	local length = (to - from).Magnitude
	return B.block(parent, {
		name = "Walkway",
		size = Vector3.new(width, 1.2, length),
		cf = CFrame.lookAt(mid, to) * CFrame.new(0, -0.6, 0),
		color = Color3.fromRGB(44, 34, 30),
		material = Enum.Material.WoodPlanks,
		floor = true,
	})
end

function B.prompt(parent: BasePart, action: string, objectText: string, holdDuration: number?, distance: number?)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdDuration or 0
	prompt.MaxActivationDistance = distance or 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

return B
