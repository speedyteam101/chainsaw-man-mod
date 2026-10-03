--!nonstrict
-- Holographic placement. Pick a structure (or your base crystal) in the Build menu, then a
-- hologram follows your aim: green where it fits, red where it doesn't. Click to place a
-- blueprint, R to rotate, X to stop. Also handles a few local-only base touches: other players'
-- base prompts are hidden from you, and townsfolk you've already rescued vanish from their cocoons.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Areas = require(ReplicatedStorage.Shared.Areas)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Structures = require(ReplicatedStorage.Shared.Structures)
local Ui = require(script.Parent.Ui)
local ClientState = require(script.Parent.ClientState)

local BuildMode = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local GOOD = Color3.fromRGB(90, 255, 140)
local BAD = Color3.fromRGB(255, 70, 70)

local active = nil -- { id, def, model, rotation, valid, cf }
local ring: Part?
local helpGui
local titleLabel, reasonLabel
local busy = false
BuildMode.OnMessage = nil -- function(text, color) set by Main to show toasts

local function message(text: string, color: Color3?)
	if BuildMode.OnMessage then
		BuildMode.OnMessage(text, color)
	end
end

local function aimRay()
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local mouse = UserInputService:GetMouseLocation()
		return camera:ViewportPointToRay(mouse.X, mouse.Y)
	end
	local size = camera.ViewportSize
	return camera:ViewportPointToRay(size.X / 2, size.Y / 2)
end

local function excludeList()
	local list = { player.Character }
	for _, name in { "LocalFx", "Enemies", "Stalkers", "Ducks", "Cocoons" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	if active then
		table.insert(list, active.model)
	end
	if ring then
		table.insert(list, ring)
	end
	return list
end

local function overlapBlocked(cf: CFrame, size: Vector3): boolean
	local exclude = excludeList()
	local map = workspace:FindFirstChild("Map")
	local floors = map and map:FindFirstChild("Floors")
	if floors then
		table.insert(exclude, floors)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	for _, part in workspace:GetPartBoundsInBox(cf, size, params) do
		if part.CanCollide or part.Name == "Bounds" or (part.Parent and part.Parent.Name == "BaseCrystal") then
			return true
		end
	end
	return false
end

local function paint(color: Color3)
	for _, part in active.model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Bounds" then
			part.Color = color
			part.Material = Enum.Material.Neon
			part.Transparency = 0.55
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
		end
	end
end

local function makeHologram()
	if active.model then
		active.model:Destroy()
	end
	local model
	if active.id == "Crystal" then
		model = Structures.BuildCrystal(CFrame.new(), player:GetAttribute("BaseLevel") or 1)
	else
		model = Structures.Build(active.def, CFrame.new())
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Light") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	model.Name = "Hologram"
	local fx = workspace:FindFirstChild("LocalFx") or workspace
	model.Parent = fx
	active.model = model
	paint(GOOD)
end

local function placeRing(center: Vector3, radius: number)
	if not ring then
		local p = Instance.new("Part")
		p.Name = "BuildRing"
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.ForceField
		p.Color = Color3.fromRGB(110, 190, 255)
		p.Transparency = 0.1
		p.Parent = workspace:FindFirstChild("LocalFx") or workspace
		ring = p
	end
	local r = ring :: Part
	r.Size = Vector3.new(0.3, radius * 2, radius * 2)
	r.CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
end

local function snap(value: number, origin: number, step: number): number
	return origin + math.floor((value - origin) / step + 0.5) * step
end

local function update()
	if not active then
		return
	end
	local ray = aimRay()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList()
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 160, params)
	if not hit then
		active.valid = false
		paint(BAD)
		return
	end
	local position = hit.Position
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local reason = nil

	if active.id == "Crystal" then
		local cf = CFrame.new(position)
		active.model:PivotTo(cf * CFrame.new(0, 0.75, 0))
		active.cf = cf
		local area = Areas.At(position)
		local flat = Vector2.new(position.X, position.Z)
		local arena = Areas.ById.town.boss.arena
		if not area or area.id ~= "town" then
			reason = "Must be in Hollow Creek"
		elseif flat.Magnitude < Config.Base.MinDistanceFromCamp then
			reason = "Too close to the camp"
		elseif (flat - Vector2.new(arena.X, arena.Z)).Magnitude < 55 then
			reason = "Too close to the churchyard"
		elseif overlapBlocked(cf * CFrame.new(0, 5.5, 0), Vector3.new(5.6, 10, 5.6)) then
			reason = "Something is in the way"
		end
		placeRing(position, Config.Base.Levels[player:GetAttribute("BaseLevel") or 1].radius)
	else
		local def = active.def
		local center = player:GetAttribute("BaseCenter") or Vector3.zero
		local radius = player:GetAttribute("BaseRadius") or 0
		local step = def.snap or Config.Base.Grid
		-- Snap to a grid centred on the crystal so walls and floors line up edge to edge.
		local x = snap(position.X, center.X, step)
		local z = snap(position.Z, center.Z, step)
		local cf = CFrame.new(x, position.Y, z) * CFrame.Angles(0, math.rad(active.rotation), 0)
		active.model:PivotTo(cf * CFrame.new(0, def.size.Y / 2, 0))
		active.cf = cf
		local offset = cf.Position - center
		local reach = Vector2.new(def.size.X, def.size.Z).Magnitude / 2
		if radius <= 0 then
			reason = "Place your base crystal first"
		elseif Vector2.new(offset.X, offset.Z).Magnitude + reach > radius then
			reason = "Outside your barrier"
		elseif offset.Y < -6 or offset.Y > 40 then
			reason = "Too high or too low"
		elseif overlapBlocked(cf * CFrame.new(0, def.size.Y / 2, 0), def.size - Vector3.new(math.min(def.size.X * 0.5, 1.1), 0.3, math.min(def.size.Z * 0.5, 1.1))) then
			reason = "Something is in the way"
		end
		placeRing(center, radius)
	end
	if root and (active.cf.Position - root.Position).Magnitude > 90 then
		reason = "Too far away"
	end
	active.valid = reason == nil
	active.reason = reason
	paint(active.valid and GOOD or BAD)
	reasonLabel.Text = reason or ""
end

local function place()
	if not active or busy then
		return
	end
	if not active.valid then
		message(active.reason or "Can't build there.", BAD)
		return
	end
	busy = true
	local result
	if active.id == "Crystal" then
		result = Remotes.Request:InvokeServer("PlaceCrystal", active.cf.Position)
	else
		result = Remotes.Request:InvokeServer("PlaceStructure", { id = active.id, position = active.cf.Position, rotation = active.rotation })
	end
	busy = false
	if result and result.ok then
		if active and active.id == "Crystal" then
			message("Your base crystal is placed! Its barrier keeps shadows out.", GOOD)
			BuildMode.Stop()
		end
	else
		message(result and result.message or "Can't build there.", BAD)
	end
end

function BuildMode.Stop()
	if not active then
		return
	end
	if active.model then
		active.model:Destroy()
	end
	active = nil
	if ring then
		ring:Destroy()
		ring = nil
	end
	helpGui.Enabled = false
	ClientState.BuildMode = false
	for _, name in { "ShadowfallBuildPlace", "ShadowfallBuildRotate", "ShadowfallBuildCancel" } do
		ContextActionService:UnbindAction(name)
	end
end

function BuildMode.Begin(id: string)
	if player:GetAttribute("Act") ~= 2 then
		return
	end
	BuildMode.Stop()
	local def = Structures.ById[id]
	if id ~= "Crystal" and not def then
		return
	end
	active = { id = id, def = def, rotation = 0, valid = false }
	ClientState.BuildMode = true
	makeHologram()
	titleLabel.Text = id == "Crystal" and "Placing: Base Crystal" or ("Placing: " .. def.name)
	helpGui.Enabled = true

	ContextActionService:BindAction("ShadowfallBuildPlace", function(_, state)
		if state == Enum.UserInputState.Begin then
			task.spawn(place)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("ShadowfallBuildPlace", "Place")
	ContextActionService:BindAction("ShadowfallBuildRotate", function(_, state)
		if state == Enum.UserInputState.Begin and active then
			active.rotation = (active.rotation + 90) % 360
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("ShadowfallBuildRotate", "Rotate")
	ContextActionService:BindAction("ShadowfallBuildCancel", function(_, state)
		if state == Enum.UserInputState.Begin then
			BuildMode.Stop()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.X, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
	ContextActionService:SetTitle("ShadowfallBuildCancel", "Stop")
end

-- Local-only touches ---------------------------------------------------------------------------

local function ownerOf(instance: Instance): number?
	local node = instance.Parent
	while node and node ~= workspace do
		local owner = node:GetAttribute("Owner")
		if owner then
			return owner
		end
		node = node.Parent
	end
	return nil
end

local function filterPrompt(prompt: Instance)
	if prompt:IsA("ProximityPrompt") then
		local owner = ownerOf(prompt)
		if owner and owner ~= player.UserId then
			prompt.Enabled = false
		end
	end
end

local function watchFolder(name: string)
	local folder = workspace:WaitForChild(name, 30)
	if not folder then
		return
	end
	for _, d in folder:GetDescendants() do
		filterPrompt(d)
	end
	folder.DescendantAdded:Connect(function(d)
		task.defer(filterPrompt, d)
	end)
end

local function refreshCocoons()
	local rescued = ClientState.rescued or {}
	for _, model in CollectionService:GetTagged("Cocoon") do
		local hidden = rescued[model:GetAttribute("TownsfolkId")] == true
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = hidden and 1 or 0
			elseif d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Smoke") or d:IsA("Light") then
				d.Enabled = not hidden
			end
		end
	end
end

function BuildMode.Start()
	helpGui = Ui.screen("BuildHelp", 15)
	helpGui.Enabled = false
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.new(0, 460, 0, 70),
		BackgroundColor3 = Ui.Theme.Panel,
		BackgroundTransparency = 0.15,
		Parent = helpGui,
	}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(90, 200, 255), 1), Ui.padding(8) })
	titleLabel = Ui.label("", { Name = "Title", Size = UDim2.new(1, 0, 0, 20), Font = Ui.Theme.Bold, TextSize = 16, TextColor3 = Color3.fromRGB(140, 220, 255), TextXAlignment = Enum.TextXAlignment.Center, Parent = panel })
	Ui.label("Click: place blueprint   R: rotate   X: stop", { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 16), TextSize = 13, TextColor3 = Ui.Theme.Muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = panel })
	reasonLabel = Ui.label("", { Name = "Reason", Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, 0, 0, 16), TextSize = 13, Font = Ui.Theme.Bold, TextColor3 = BAD, TextXAlignment = Enum.TextXAlignment.Center, Parent = panel })

	RunService.RenderStepped:Connect(function()
		if active then
			if player:GetAttribute("Act") ~= 2 then
				BuildMode.Stop()
			else
				update()
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		BuildMode.Stop()
	end)

	task.spawn(watchFolder, "Bases")
	task.spawn(watchFolder, "Ducks")
	ClientState.Changed:Connect(refreshCocoons)
	CollectionService:GetInstanceAddedSignal("Cocoon"):Connect(function()
		task.defer(refreshCocoons)
	end)
	task.defer(refreshCocoons)
end

return BuildMode
