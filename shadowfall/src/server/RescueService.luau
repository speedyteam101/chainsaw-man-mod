--!nonstrict
-- Townsfolk trapped in shadow cocoons. Get close and the shadows guarding them come for you;
-- defeat the guards, then hold the prompt to cut the person free. Rescues are per player: each
-- player frees their own copy of each person, who then moves into that player's base.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Areas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Townsfolk = require(ReplicatedStorage.Shared.Townsfolk)
local Figure = require(ReplicatedStorage.Shared.Figure)
local Registry = require(script.Parent.Registry)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local AchievementService = require(script.Parent.AchievementService)
local EnemyService = require(script.Parent.EnemyService)

local RescueService = {}

local GUARD_RANGE = 34
local cocoons = {} -- [id] = { person, position, model }
local guards = {} -- [Player] = { [id] = { enemies = {}, spawnedAt = number } }

local function toast(player: Player, text: string, color: Color3?)
	Remotes.Notify:FireClient(player, "Toast", { text = text, color = color })
end

local function block(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function buildCocoon(person, ground: Vector3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Cocoon_" .. person.id
	local cf = CFrame.new(ground) * CFrame.Angles(0, math.rad((person.order * 47) % 360), 0)
	-- The trapped person: eyes shut, head lolling, fully detailed under the bands.
	local spec = Figure.SpecFor(person.id, { shirt = person.shirt, pants = person.pants, expression = "closed" })
	spec.cf = cf
	spec.name = "Trapped"
	spec.pose = { Head = CFrame.new(0, 4.5, 0) * CFrame.Angles(0.2, 0, 0.15) }
	local built = Figure.Build(spec)
	for _, child in built:GetChildren() do
		child.Parent = model
	end
	built:Destroy()
	-- Bands of living shadow wrapped around them.
	for i = 1, 7 do
		local y = 0.6 + i * 0.68
		local band = block(model, "Band", Vector3.new(4.4, 0.42, 1.9), cf * CFrame.new(0, y, 0) * CFrame.Angles(0, i * 0.5, (i % 2 == 0 and 0.25 or -0.25)), Color3.new(0, 0, 0), Enum.Material.Neon)
		band.CanQuery = false
		CollectionService:AddTag(band, "CocoonBand")
	end
	local core = block(model, "Core", Vector3.new(1, 1, 1), cf * CFrame.new(0, 3, 0), Color3.new(0, 0, 0), Enum.Material.Neon)
	core.Transparency = 1
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(8, 6, 12)
	smoke.Opacity = 0.25
	smoke.RiseVelocity = 3
	smoke.Size = 3
	smoke.Parent = core
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(150, 80, 255)
	glow.Range = 12
	glow.Brightness = 1
	glow.Parent = core

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(220, 190, 255)
	label.TextStrokeTransparency = 0.3
	label.Text = string.format("%s is trapped!\n%s", person.name, #person.roles > 0 and table.concat(person.roles, " & ") or "Survivor")
	label.Parent = gui
	gui.Parent = core

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Free " .. person.name
	prompt.ObjectText = "Shadow cocoon"
	prompt.HoldDuration = 2.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = core
	model:SetAttribute("TownsfolkId", person.id)
	CollectionService:AddTag(model, "Cocoon")
	model.Parent = parent
	return model, prompt
end

local function guardState(player: Player, id: string)
	guards[player] = guards[player] or {}
	return guards[player][id]
end

local function aliveGuards(state): number
	local alive = 0
	for _, enemy in state.enemies do
		if not enemy.dead and Registry.Enemies[enemy.model] then
			alive += 1
		end
	end
	return alive
end

local function spawnGuards(player: Player, cocoon)
	local person = cocoon.person
	local area = Areas.ById[person.area]
	local state = { enemies = {}, spawnedAt = os.clock() }
	guards[player] = guards[player] or {}
	guards[player][person.id] = state
	for index, typeName in person.guards do
		local angle = index / #person.guards * math.pi * 2
		local at = cocoon.position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 9
		local enemy = EnemyService.SpawnAdd(typeName, area, at, player)
		table.insert(state.enemies, enemy)
	end
	Remotes.Fx:FireAllClients("Blink", { from = cocoon.position, to = cocoon.position })
	toast(player, string.format("Shadows guard %s! Defeat them to cut %s free.", person.name, person.name), Color3.fromRGB(220, 190, 255))
end

local function rescue(player: Player, cocoon)
	local data = PlayerData.Get(player)
	local person = cocoon.person
	data.rescued[person.id] = true
	if guards[player] then
		guards[player][person.id] = nil
	end
	Remotes.Fx:FireAllClients("Freed", { position = cocoon.position })
	Remotes.Notify:FireClient(player, "Rescued", { id = person.id, name = person.name, roles = person.roles, line = person.lines[1] })
	local count = Townsfolk.Count(data.rescued)
	if count >= 3 then
		AchievementService.Grant(player, "good_neighbour")
	end
	if count >= #Townsfolk.List then
		AchievementService.Grant(player, "full_house")
	end
	Registry.Rescued:Fire(player, person.id)
	Registry.SanityChange:Fire(player, 15)
	PlayerData.Sync(player)
	PlayerData.Save(player)
end

function RescueService.Start(world)
	local folder = Instance.new("Folder")
	folder.Name = "Cocoons"
	folder.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world.floors, workspace.Terrain }
	params.IgnoreWater = true

	for _, person in Townsfolk.List do
		local hit = workspace:Raycast(person.at + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params)
		local ground = hit and hit.Position or person.at
		local model, prompt = buildCocoon(person, ground, folder)
		local cocoon = { person = person, position = ground + Vector3.new(0, 3, 0), model = model }
		cocoons[person.id] = cocoon
		prompt.Triggered:Connect(function(player: Player)
			local data = PlayerData.Get(player)
			if not data or data.act ~= 2 or data.rescued[person.id] then
				return
			end
			local area = Areas.ById[person.area]
			if data.level < area.level then
				return
			end
			local state = guardState(player, person.id)
			if not state then
				spawnGuards(player, cocoon)
				return
			end
			local alive = aliveGuards(state)
			if alive > 0 then
				toast(player, string.format("%d shadow%s still guarding %s.", alive, alive == 1 and " is" or "s are", person.name), Color3.fromRGB(255, 170, 170))
				return
			end
			rescue(player, cocoon)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		local mine = guards[player]
		guards[player] = nil
		for _, state in mine or {} do
			for _, enemy in state.enemies do
				EnemyService.Despawn(enemy)
			end
		end
	end)

	-- Guards wake up when you get close; they give up if you leave for a long time.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.Get(player)
				local _, _, root = Combat.GetCharacter(player)
				if data and data.act == 2 and root then
					for id, cocoon in cocoons do
						if not data.rescued[id] and data.level >= Areas.ById[cocoon.person.area].level then
							local distance = (root.Position - cocoon.position).Magnitude
							local state = guardState(player, id)
							if not state and distance < GUARD_RANGE then
								spawnGuards(player, cocoon)
							elseif state and distance > 150 and os.clock() - state.spawnedAt > 120 and aliveGuards(state) > 0 then
								for _, enemy in state.enemies do
									EnemyService.Despawn(enemy)
								end
								guards[player][id] = nil
							end
						end
					end
				end
			end
		end
	end)
end

return RescueService
