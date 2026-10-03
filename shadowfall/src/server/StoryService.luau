--!nonstrict
-- Plays story scenes when things happen and places the journal pages. Each scene plays once
-- per player (saved), so the story moves forward with you.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Story = require(ReplicatedStorage.Shared.Story)
local Registry = require(script.Parent.Registry)
local PlayerData = require(script.Parent.PlayerData)
local Combat = require(script.Parent.Combat)

local StoryService = {}
StoryService.OnAllPages = nil :: ((Player) -> ())? -- set by Main (grants the Archivist feat)

local function storyOf(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	data.story = data.story or { seen = {}, pages = {} }
	data.story.seen = data.story.seen or {}
	data.story.pages = data.story.pages or {}
	return data.story
end

function StoryService.Play(player: Player, beatId: string)
	local story = storyOf(player)
	local beat = Story.Beats[beatId]
	if not story or not beat or story.seen[beatId] then
		return
	end
	story.seen[beatId] = os.time()
	if beat.chapter then
		story.chapter = math.max(story.chapter or 1, beat.chapter)
	end
	if beat.blocking then
		-- Nothing can hurt you while a scene plays.
		-- Same timing the client uses per line, plus letterbox, chapter card and slack. The client
		-- also reports when the scene ends ("SceneDone"), which lifts the shield early.
		local duration = 1 + (beat.chapter and 3.3 or 0) + 5
		for _, line in beat.lines do
			duration += math.clamp(#line.text * 0.045, 2.2, 6.5) + 0.5
		end
		Combat.GetState(player).storyShieldUntil = os.clock() + duration
	end
	Remotes.Notify:FireClient(player, "Scene", { id = beatId, chapter = beat.chapter, blocking = beat.blocking, lines = beat.lines })
	PlayerData.Sync(player)
end

local function makePage(page, ground: Vector3, parent: Instance)
	local stand = Instance.new("Part")
	stand.Name = "PageStand"
	stand.Anchored = true
	stand.Size = Vector3.new(1.4, 2.4, 1.4)
	stand.CFrame = CFrame.new(ground + Vector3.new(0, 1.2, 0))
	stand.Color = Color3.fromRGB(70, 52, 36)
	stand.Material = Enum.Material.Wood
	stand.Parent = parent
	local paper = Instance.new("Part")
	paper.Name = "JournalPage"
	paper.Anchored = true
	paper.CanCollide = false
	paper.Size = Vector3.new(1.1, 0.05, 1.4)
	paper.CFrame = CFrame.new(ground + Vector3.new(0, 2.45, 0)) * CFrame.Angles(math.rad(-15), math.rad(20), 0)
	paper.Color = Color3.fromRGB(236, 228, 205)
	paper.Material = Enum.Material.SmoothPlastic
	paper.Parent = parent
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 230, 170)
	glow.Range = 8
	glow.Brightness = 0.8
	glow.Parent = paper
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(255, 230, 170)
	sparkle.Parent = paper
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Read"
	prompt.ObjectText = page.title
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = paper
	return prompt
end

function StoryService.SceneDone(player: Player)
	Combat.GetState(player).storyShieldUntil = 0
end

function StoryService.Start(world)
	local folder = Instance.new("Folder")
	folder.Name = "JournalPages"
	folder.Parent = world.map
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world.floors, workspace.Terrain }
	params.IgnoreWater = true
	for _, page in Story.Pages do
		local hit = workspace:Raycast(page.at + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params)
		local prompt = makePage(page, hit and hit.Position or page.at, folder)
		prompt.Triggered:Connect(function(player: Player)
			local story = storyOf(player)
			if not story then
				return
			end
			local isNew = not story.pages[page.id]
			story.pages[page.id] = true
			Remotes.Notify:FireClient(player, "JournalPage", { id = page.id, title = page.title, text = page.text, new = isNew })
			if isNew then
				local found = 0
				for _ in story.pages do
					found += 1
				end
				if found >= #Story.Pages and StoryService.OnAllPages then
					StoryService.OnAllPages(player)
				end
				PlayerData.Sync(player)
			end
		end)
	end

	-- Scenes ------------------------------------------------------------------------------------
	local function watch(player: Player)
		player:GetAttributeChangedSignal("Area"):Connect(function()
			local area = player:GetAttribute("Area")
			if area and area ~= "town" then
				StoryService.Play(player, "area_" .. area)
			end
		end)
		player:GetAttributeChangedSignal("Act"):Connect(function()
			if player:GetAttribute("Act") == 2 then
				task.delay(4, StoryService.Play, player, "camp_arrival")
			end
		end)
		-- Returning players who are already in Act 2 still get the camp scene once.
		task.delay(6, function()
			if player.Parent and player:GetAttribute("Act") == 2 then
				StoryService.Play(player, "camp_arrival")
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	Registry.EnemyKilled:Connect(function(enemy, _, damagers)
		if not enemy.isBoss then
			return
		end
		for player, dealt in damagers do
			if player.Parent and dealt >= enemy.maxHp * 0.05 then
				task.delay(2.5, StoryService.Play, player, "boss_" .. enemy.bossId)
			end
		end
	end)
	Registry.Ascended:Connect(function(player: Player, level: number)
		task.delay(1.5, StoryService.Play, player, "ascend_" .. level)
	end)
	Registry.Rescued:Connect(function(player: Player)
		task.delay(3, StoryService.Play, player, "first_rescue")
	end)
end

return StoryService
