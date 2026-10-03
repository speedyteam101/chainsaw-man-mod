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

function B.ground(parent: Instance, center: Vector3, size: Vector2, color: Color3, material: Enum.Material, thickness: number?)
	local t = thickness or 6
	return B.block(parent, {
		name = "Ground",
		size = Vector3.new(size.X, t, size.Y),
		cf = CFrame.new(center - Vector3.new(0, t / 2, 0)),
		color = color,
		material = material,
		floor = true,
	})
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

-- A light that the client flickers. `strength` 0-1 controls how bright it is.
function B.lamp(parent: Instance, position: Vector3, color: Color3?, strength: number?, flicker: boolean?)
	local model = Instance.new("Model")
	model.Name = "StreetLamp"
	B.block(model, {
		name = "Pole",
		size = Vector3.new(0.6, 14, 0.6),
		cf = CFrame.new(position + Vector3.new(0, 7, 0)),
		color = Color3.fromRGB(20, 20, 22),
		material = Enum.Material.Metal,
	})
	B.block(model, {
		name = "Arm",
		size = Vector3.new(0.4, 0.4, 3),
		cf = CFrame.new(position + Vector3.new(0, 13.8, -1.3)),
		color = Color3.fromRGB(20, 20, 22),
		material = Enum.Material.Metal,
	})
	local bulb = B.block(model, {
		name = "Bulb",
		size = Vector3.new(1.4, 0.8, 1.4),
		cf = CFrame.new(position + Vector3.new(0, 13.3, -2.6)),
		color = color or Color3.fromRGB(255, 200, 120),
		material = Enum.Material.Neon,
		collide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = color or Color3.fromRGB(255, 190, 110)
	light.Range = 26
	light.Brightness = 1.6 * (strength or 1)
	light.Shadows = false
	light.Parent = bulb
	if flicker ~= false then
		CollectionService:AddTag(bulb, "FlickerLight")
	end
	model.Parent = parent
	return model
end

local WALL_COLORS = {
	Color3.fromRGB(92, 78, 70), Color3.fromRGB(70, 74, 82), Color3.fromRGB(96, 92, 80),
	Color3.fromRGB(64, 58, 62), Color3.fromRGB(80, 66, 56), Color3.fromRGB(58, 66, 64),
}
local ROOF_COLORS = {
	Color3.fromRGB(45, 30, 30), Color3.fromRGB(30, 34, 40), Color3.fromRGB(40, 40, 36), Color3.fromRGB(52, 36, 30),
}

export type HouseOptions = {
	width: number?,
	depth: number?,
	height: number?,
	litWindows: number?, -- chance (0-1) a window glows
	broken: boolean?, -- missing roof chunks / tilted
	name: string?,
}

-- A hollow, enterable house. The door is on the front face (the CFrame's look direction).
function B.house(parent: Instance, cf: CFrame, rng: Random, options: HouseOptions?)
	local o = options or {}
	local w = o.width or rng:NextInteger(18, 24)
	local d = o.depth or rng:NextInteger(16, 22)
	local h = o.height or rng:NextInteger(11, 14)
	local t = 1
	local wallColor = WALL_COLORS[rng:NextInteger(1, #WALL_COLORS)]
	local roofColor = ROOF_COLORS[rng:NextInteger(1, #ROOF_COLORS)]
	local model = Instance.new("Model")
	model.Name = o.name or "House"

	local function wall(size: Vector3, offset: Vector3)
		return B.block(model, { name = "Wall", size = size, cf = cf * CFrame.new(offset), color = wallColor, material = Enum.Material.WoodPlanks })
	end

	-- Floor
	B.block(model, {
		name = "Floor",
		size = Vector3.new(w, 0.6, d),
		cf = cf * CFrame.new(0, 0.3, 0),
		color = Color3.fromRGB(60, 46, 38),
		material = Enum.Material.WoodPlanks,
		floor = true,
	})
	-- Back and sides
	wall(Vector3.new(w, h, t), Vector3.new(0, h / 2, d / 2 - t / 2))
	wall(Vector3.new(t, h, d), Vector3.new(-w / 2 + t / 2, h / 2, 0))
	wall(Vector3.new(t, h, d), Vector3.new(w / 2 - t / 2, h / 2, 0))
	-- Front with a doorway (5 wide, 8 tall)
	local doorW, doorH = 5, 8
	local side = (w - doorW) / 2
	wall(Vector3.new(side, h, t), Vector3.new(-w / 2 + side / 2, h / 2, -d / 2 + t / 2))
	wall(Vector3.new(side, h, t), Vector3.new(w / 2 - side / 2, h / 2, -d / 2 + t / 2))
	wall(Vector3.new(doorW, h - doorH, t), Vector3.new(0, doorH + (h - doorH) / 2, -d / 2 + t / 2))
	-- Ceiling
	B.block(model, { name = "Ceiling", size = Vector3.new(w, 0.6, d), cf = cf * CFrame.new(0, h, 0), color = Color3.fromRGB(40, 36, 34) })

	-- Gable roof from two wedges. A wedge's tall face is its back (+Z), so each one is turned
	-- to put that face at the ridge in the middle of the house.
	local roofH = 6
	for _, sideSign in { -1, 1 } do
		local wedge = B.block(model, {
			class = "WedgePart",
			name = "Roof",
			size = Vector3.new(d + 2, roofH, w / 2 + 1),
			cf = cf * CFrame.new(sideSign * (w / 4 + 0.5), h + roofH / 2, 0) * CFrame.Angles(0, -sideSign * math.pi / 2, 0),
			color = roofColor,
			material = Enum.Material.Slate,
		})
		if o.broken and rng:NextNumber() < 0.5 then
			wedge.Transparency = 1
			wedge.CanCollide = false
		end
	end

	-- Windows: dark glass, some faintly lit from inside.
	local lit = o.litWindows or 0.15
	for _, x in { -w / 2 + side / 2, w / 2 - side / 2 } do
		local glowing = rng:NextNumber() < lit
		local win = B.block(model, {
			name = "Window",
			size = Vector3.new(3, 3.5, 0.3),
			cf = cf * CFrame.new(x, h * 0.55, -d / 2 - 0.05),
			color = glowing and Color3.fromRGB(255, 180, 90) or Color3.fromRGB(8, 8, 12),
			material = glowing and Enum.Material.Neon or Enum.Material.Glass,
			collide = false,
		})
		if glowing then
			win.Transparency = 0.35
		end
	end
	-- Chimney
	if rng:NextNumber() < 0.6 then
		B.block(model, {
			name = "Chimney",
			size = Vector3.new(2.4, 5, 2.4),
			cf = cf * CFrame.new(w / 4, h + roofH, d / 4),
			color = Color3.fromRGB(70, 50, 46),
			material = Enum.Material.Brick,
		})
	end
	model.Parent = parent
	return model, Vector3.new(w, h, d)
end

function B.tree(parent: Instance, position: Vector3, rng: Random, dead: boolean?)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = rng:NextNumber(12, 22)
	local trunkW = rng:NextNumber(1.4, 2.4)
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-6, 6)))
	local trunkCf = CFrame.new(position) * lean * CFrame.new(0, height / 2, 0)
	B.block(model, {
		name = "Trunk",
		size = Vector3.new(trunkW, height, trunkW),
		cf = trunkCf,
		color = Color3.fromRGB(26, 20, 18),
		material = Enum.Material.Wood,
	})
	if dead then
		for _ = 1, rng:NextInteger(2, 4) do
			local branchLength = rng:NextNumber(4, 8)
			B.block(model, {
				name = "Branch",
				size = Vector3.new(0.7, branchLength, 0.7),
				cf = trunkCf * CFrame.new(0, rng:NextNumber(0, height / 2), 0)
					* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(35, 70)))
					* CFrame.new(0, branchLength / 2, 0),
				color = Color3.fromRGB(26, 20, 18),
				material = Enum.Material.Wood,
				collide = false,
			})
		end
	else
		local leafColor = Color3.fromRGB(rng:NextInteger(14, 26), rng:NextInteger(18, 34), rng:NextInteger(26, 40))
		for layer = 1, 3 do
			local size = (4 - layer) * rng:NextNumber(3.2, 4.2) + 2
			B.block(model, {
				name = "Leaves",
				size = Vector3.new(size, 3.4, size),
				cf = trunkCf * CFrame.new(0, height / 2 - 2 + layer * 3, 0) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
				color = leafColor,
				material = Enum.Material.Grass,
				collide = false,
			})
		end
	end
	model.Parent = parent
	return model
end

function B.car(parent: Instance, cf: CFrame, rng: Random)
	local model = Instance.new("Model")
	model.Name = "AbandonedCar"
	local color = Color3.fromRGB(rng:NextInteger(30, 90), rng:NextInteger(20, 50), rng:NextInteger(20, 50))
	B.block(model, { name = "Body", size = Vector3.new(6, 2.6, 12), cf = cf * CFrame.new(0, 2.1, 0), color = color, material = Enum.Material.Metal })
	B.block(model, { name = "Cabin", size = Vector3.new(5.6, 2.2, 6), cf = cf * CFrame.new(0, 4.5, 0.5), color = color, material = Enum.Material.Metal })
	B.block(model, { name = "Glass", size = Vector3.new(5.7, 1.6, 6.1), cf = cf * CFrame.new(0, 4.6, 0.5), color = Color3.fromRGB(10, 12, 16), material = Enum.Material.Glass, transparency = 0.2, collide = false })
	for _, x in { -2.6, 2.6 } do
		for _, z in { -4, 4 } do
			B.block(model, {
				name = "Wheel",
				size = Vector3.new(1, 2.4, 2.4),
				cf = cf * CFrame.new(x, 1.2, z),
				color = Color3.fromRGB(15, 15, 15),
				shape = Enum.PartType.Cylinder,
			})
		end
	end
	-- Headlights left on, long since dimmed.
	if rng:NextNumber() < 0.3 then
		local lamp = B.block(model, { name = "Headlight", size = Vector3.new(4.5, 0.6, 0.3), cf = cf * CFrame.new(0, 2.4, -6.05), color = Color3.fromRGB(255, 240, 200), material = Enum.Material.Neon, collide = false })
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = 50
		spot.Range = 30
		spot.Brightness = 1.2
		spot.Color = Color3.fromRGB(255, 235, 190)
		spot.Parent = lamp
		CollectionService:AddTag(lamp, "FlickerLight")
	end
	model.Parent = parent
	return model
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
		local position = center + Vector3.new(math.cos(angle) * distance, rng:NextNumber(-120, 160), math.sin(angle) * distance)
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

-- A floating island (flat top at `top`) for the Rift.
function B.island(parent: Instance, center: Vector3, radius: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Island"
	B.block(model, {
		name = "Top",
		size = Vector3.new(6, radius * 2, radius * 2),
		cf = CFrame.new(center - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color = Color3.fromRGB(34, 28, 44),
		material = Enum.Material.Slate,
		shape = Enum.PartType.Cylinder,
		floor = true,
	})
	local layers = 4
	for i = 1, layers do
		local r = radius * (1 - i / (layers + 1))
		B.block(model, {
			name = "Underside",
			size = Vector3.new(7, r * 2, r * 2),
			cf = CFrame.new(center - Vector3.new(rng:NextNumber(-2, 2), 3 + i * 6, rng:NextNumber(-2, 2))) * CFrame.Angles(0, 0, math.pi / 2),
			color = Color3.fromRGB(24, 18, 30),
			material = Enum.Material.Rock,
			shape = Enum.PartType.Cylinder,
		})
	end
	for _ = 1, math.floor(radius / 6) do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(radius * 0.55, radius * 0.9)
		local h = rng:NextNumber(3, 8)
		local crystal = B.block(model, {
			name = "Crystal",
			size = Vector3.new(1.6, h, 1.6),
			cf = CFrame.new(center + Vector3.new(math.cos(a) * d, h / 2, math.sin(a) * d)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)),
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
	end
	model.Parent = parent
	return model
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
