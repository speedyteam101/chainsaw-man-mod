--!nonstrict
-- Act 1: the horror chapter. You wake up in Hollow Creek after it has been pulled into the
-- shadow world. No powers, no HUD, just a flashlight with a weak battery. Stalkers creep after you,
-- freeze in your light and move when you're not looking. Ringing the clock tower bell brings
-- every shadow in town down on you... and wakes something up inside you.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShadowRig = require(ReplicatedStorage.Shared.ShadowRig)
local Registry = require(script.Parent.Registry)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local PowerService = require(script.Parent.PowerService)
local AchievementService = require(script.Parent.AchievementService)
local WorldBuilder = require(script.Parent.World.WorldBuilder)
local DuckService = require(script.Parent.DuckService)

local Act1Director = {}

local A = Config.Act1
local rng = Random.new()
local states: { [Player]: any } = {}
local world
local points = {} -- walkable points across the Act 1 map
local folder: Folder
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Include

local OBJECTIVES = {
	[0] = "Save Biscuit! Hold your flashlight [F] on the shadow.",
	[1] = "Get out of the house.",
	[2] = "Find someone. Try the town square.",
	[3] = "Follow the blinking light to the radio station.",
	[4] = "Ring the bell at the clock tower.",
}

local function story(player: Player, kind: string, payload)
	Remotes.Story:FireClient(player, kind, payload or {})
end

local function getState(player: Player)
	local state = states[player]
	if not state then
		state = {
			stalkers = {},
			look = Vector3.new(0, 0, -1),
			eye = Vector3.zero,
			flashlight = false,
			lastPacket = 0,
			nextSpawn = os.clock() + 4,
			sighted = false,
			finale = false,
		}
		states[player] = state
	end
	return state
end

local function clearStalkers(state)
	for stalker in state.stalkers do
		if stalker.model.Parent then
			stalker.model:Destroy()
		end
	end
	state.stalkers = {}
end

function Act1Director.SpawnCFrame(player: Player): CFrame
	local data = PlayerData.Get(player)
	local stage = data and data.act1Stage or 1
	if stage <= 1 then
		return world.act1.houseSpawn
	elseif stage >= 4 then
		return world.act1.radioSpawn
	elseif stage == 3 then
		return world.act1.squareSpawn
	end
	return world.act1.houseSpawn
end

local function setStage(player: Player, stage: number)
	local data = PlayerData.Get(player)
	if not data or data.act1Stage >= stage then
		return
	end
	data.act1Stage = stage
	PlayerData.Sync(player)
	story(player, "Objective", { text = OBJECTIVES[stage], stage = stage })
	if stage == 1 then
		story(player, "Subtitles", {
			lines = {
				"Biscuit... you're okay. You're okay.",
				"Mom. Dad. I...",
				"I can't stay here. Not with them still out there.",
			},
		})
	elseif stage == 2 then
		story(player, "Subtitles", { lines = { "Hello? Is anyone out here?", "...", "Where is everyone?" } })
	elseif stage == 3 then
		story(player, "Subtitles", {
			lines = {
				"The square is empty. Everyone is just... gone.",
				"There's a red light blinking on the radio tower.",
				"Someone is broadcasting.",
			},
		})
	elseif stage == 4 then
		story(player, "Broadcast", {
			lines = {
				"—if anyone can hear this, this is Mara, at the old garage.",
				"The town isn't where it was. Look up. There is no sky anymore.",
				"They came out of the dark at noon. Black. Smoking. They don't stop.",
				"Light hurts them. Keep your light on them and they can't move.",
				"Ring the bell at the clock tower so we know someone's still alive.",
				"We'll find you. Just ring the bell...",
			},
		})
	end
end

-- Stalkers -------------------------------------------------------------------------------

local function pickSpawnPoint(root: BasePart, look: Vector3)
	local best
	for _ = 1, 30 do
		local p = points[rng:NextInteger(1, #points)]
		local offset = p - root.Position
		local distance = offset.Magnitude
		if distance > 42 and distance < 85 then
			best = p
			if Vector3.new(offset.X, 0, offset.Z).Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit) < 0.2 then
				return p -- prefer spawning where you aren't looking
			end
		end
	end
	return best
end

local function spawnStalker(player: Player, state, position: Vector3, speed: number, finale: boolean?)
	local model = ShadowRig.Build({ name = "Stalker", scale = 1.05, armLength = 1.35, eyeColor = Color3.fromRGB(245, 245, 255), smokeRate = 18, tendrils = 4, eyeLight = true })
	model:PivotTo(CFrame.new(position + Vector3.new(0, 3.7, 0)))
	model:SetAttribute("Owner", player.UserId)
	CollectionService:AddTag(model, "Stalker")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.WalkSpeed = speed
	model.Parent = folder
	pcall(function()
		model.PrimaryPart:SetNetworkOwner(nil)
	end)
	local stalker = { model = model, humanoid = humanoid, root = model.PrimaryPart, lit = 0, speed = speed, lastCreep = os.clock(), finale = finale }
	state.stalkers[stalker] = true
	if not state.sighted and not finale then
		state.sighted = true
		task.delay(1.5, function()
			story(player, "Subtitles", { lines = { "...what is that?" } })
			story(player, "Hint", { text = "Press F to use your flashlight. Hold the light on them." })
		end)
	end
	Remotes.Story:FireClient(player, "Whisper", { position = position })
	return stalker
end

local function removeStalker(state, stalker, banished: boolean)
	state.stalkers[stalker] = nil
	if stalker.model.Parent then
		if banished then
			Remotes.Fx:FireAllClients("Banish", { model = stalker.model })
			task.delay(0.6, function()
				stalker.model:Destroy()
			end)
		else
			stalker.model:Destroy()
		end
	end
	state.nextSpawn = os.clock() + rng:NextNumber(A.StalkerRespawn[1], A.StalkerRespawn[2])
end

local function isLit(state, stalker, character): boolean
	if not state.flashlight or os.clock() - state.lastPacket > 0.6 then
		return false
	end
	local target = stalker.root.Position + Vector3.new(0, 1, 0)
	local offset = target - state.eye
	if offset.Magnitude > A.FlashlightRange then
		return false
	end
	if offset.Unit:Dot(state.look) < A.FlashlightConeDot then
		return false
	end
	local hit = workspace:Raycast(state.eye, offset, losParams)
	return hit == nil
end

local function catch(player: Player, state, stalker)
	local _, humanoid = Combat.GetCharacter(player)
	removeStalker(state, stalker, false)
	if humanoid then
		humanoid.Health -= A.CatchDamage
	end
	state.touched = true
	Registry.SanityChange:Fire(player, -Config.Sanity.CaughtLoss)
	story(player, "Jumpscare", {})
end

-- The intro: a shadow has Biscuit cornered in the living room ----------------------------

local function clearIntruder(state)
	if state.intruder and state.intruder.model.Parent then
		state.intruder.model:Destroy()
	end
	state.intruder = nil
end

local function startIntro(player: Player, state)
	clearIntruder(state)
	local act1 = world.act1
	DuckService.Place(player, act1.duckCorner, true)
	local model = ShadowRig.Build({ name = "Intruder", scale = 1.1, armLength = 1.4, eyeColor = Color3.fromRGB(245, 245, 255), smokeRate = 20, tendrils = 5, eyeLight = true })
	model:PivotTo(act1.intruderStart)
	model:SetAttribute("Owner", player.UserId)
	CollectionService:AddTag(model, "Stalker")
	model.Parent = folder
	pcall(function()
		model.PrimaryPart:SetNetworkOwner(nil)
	end)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.WalkSpeed = 1.2
	state.intruder = { model = model, humanoid = humanoid, root = model.PrimaryPart, lit = 0 }
	story(player, "Intro", {
		duck = DuckService.Get(player).model,
		intruder = model,
		bedView = act1.bedView,
		parentsView = act1.parentsView,
		duckView = act1.duckView,
	})
end

local function saveDuck(player: Player, state)
	local data = PlayerData.Get(player)
	local intruder = state.intruder
	state.intruder = nil
	if intruder then
		Remotes.Fx:FireAllClients("Banish", { model = intruder.model })
		task.delay(0.6, function()
			intruder.model:Destroy()
		end)
	end
	data.duckSaved = true
	DuckService.SetFollowing(player)
	AchievementService.Grant(player, "duck_parent")
	Registry.SanityChange:Fire(player, 25)
	local duck = DuckService.Get(player)
	if duck then
		Remotes.Fx:FireAllClients("Hearts", { model = duck.model })
	end
	story(player, "DuckSaved", {})
	setStage(player, 1)
	PlayerData.Save(player)
end

local function updateIntro(player: Player, state, character: Model, root: BasePart, dt: number)
	local intruder = state.intruder
	if not intruder or not intruder.model.Parent then
		return
	end
	if isLit(state, intruder, character) then
		intruder.humanoid.WalkSpeed = 0
		intruder.humanoid:MoveTo(intruder.root.Position)
		intruder.lit += dt
		intruder.model:SetAttribute("Lit", true)
		if intruder.lit >= A.IntruderBurnTime then
			saveDuck(player, state)
		end
		return
	end
	intruder.model:SetAttribute("Lit", false)
	intruder.lit = math.max(0, intruder.lit - dt * 0.4)
	-- It creeps toward Biscuit, and turns on you if you get too close without your light.
	local toPlayer = (root.Position - intruder.root.Position).Magnitude
	if toPlayer < A.CatchDistance + 0.6 then
		local _, humanoid = Combat.GetCharacter(player)
		if humanoid then
			humanoid.Health -= A.CatchDamage * 0.6
		end
		Registry.SanityChange:Fire(player, -Config.Sanity.CaughtLoss * 0.5)
		story(player, "Jumpscare", {})
		intruder.model:PivotTo(world.act1.intruderStart)
		return
	end
	local duckPosition = world.act1.duckCorner.Position
	if (intruder.root.Position - duckPosition).Magnitude > 3.5 then
		intruder.humanoid.WalkSpeed = 1.2
		intruder.humanoid:MoveTo(duckPosition)
	else
		intruder.humanoid:MoveTo(intruder.root.Position)
	end
end

local function updatePlayer(player: Player, state, dt: number)
	local data = PlayerData.Get(player)
	local character, humanoid, root = Combat.GetCharacter(player)
	if not data or data.act ~= 1 or not character then
		clearStalkers(state)
		return
	end
	local stage = data.act1Stage

	if stage == 0 then
		if data.duckSaved then
			setStage(player, 1)
		else
			updateIntro(player, state, character, root, dt)
		end
		return
	end

	-- Story triggers
	if stage == 1 and (root.Position - world.act1.houseExit).Magnitude < 8 then
		setStage(player, 2)
	elseif stage == 2 and (root.Position - world.act1.square).Magnitude < 30 then
		setStage(player, 3)
	elseif stage == 3 and (root.Position - world.act1.radio).Magnitude < 13 then
		setStage(player, 4)
	end

	-- Fell off the edge of the world: put them back (no death, this isn't that kind of scary).
	if root.Position.Y < -40 then
		character:PivotTo(Act1Director.SpawnCFrame(player))
		root.AssemblyLinearVelocity = Vector3.zero
	end

	if state.finale then
		return
	end

	local tuning = A.Stages[math.clamp(stage, 0, 4)]
	local count = 0
	for _ in state.stalkers do
		count += 1
	end
	if count < tuning.maxStalkers and os.clock() >= state.nextSpawn and #points > 0 then
		local spot = pickSpawnPoint(root, state.look)
		if spot then
			spawnStalker(player, state, spot, tuning.speed)
			state.nextSpawn = os.clock() + rng:NextNumber(A.StalkerRespawn[1], A.StalkerRespawn[2])
		end
	end

	local now = os.clock()
	for stalker in table.clone(state.stalkers) do
		if not stalker.model.Parent then
			state.stalkers[stalker] = nil
			continue
		end
		local offset = root.Position - stalker.root.Position
		local distance = offset.Magnitude
		if isLit(state, stalker, character) then
			stalker.humanoid.WalkSpeed = 0
			stalker.humanoid:MoveTo(stalker.root.Position)
			stalker.lit += dt
			stalker.model:SetAttribute("Lit", true)
			if stalker.lit >= A.FlashlightBurnTime then
				removeStalker(state, stalker, true)
			end
			continue
		end
		stalker.model:SetAttribute("Lit", false)
		stalker.lit = math.max(0, stalker.lit - dt * 0.5)
		stalker.humanoid.WalkSpeed = stalker.speed
		stalker.humanoid:MoveTo(root.Position)

		-- When you're not looking, they get closer.
		local toStalker = -offset.Unit
		local watched = state.look:Dot(toStalker) > 0.5
		if not watched and distance > 30 and now - stalker.lastCreep > 4 then
			stalker.lastCreep = now
			local closer = stalker.root.Position + offset.Unit * 12
			stalker.model:PivotTo(CFrame.lookAt(closer, Vector3.new(root.Position.X, closer.Y, root.Position.Z)))
		end
		if distance < A.CatchDistance and humanoid.Health > 0 then
			catch(player, state, stalker)
		end
	end
end

-- Finale -----------------------------------------------------------------------------------

local function finishAct1(player: Player)
	local data = PlayerData.Get(player)
	if not data or data.act ~= 2 or not states[player] or states[player].finished then
		return
	end
	states[player].finished = true
	clearStalkers(states[player])
	PlayerData.Respawn(player)
end

local function finale(player: Player)
	local data = PlayerData.Get(player)
	local state = getState(player)
	local character, humanoid, root = Combat.GetCharacter(player)
	if not data or data.act ~= 1 or data.act1Stage < 4 or state.finale or not character then
		return
	end
	state.finale = true
	clearStalkers(state)
	story(player, "Finale", {
		lines = {
			"The bell rings out across the dead town.",
			"Every light in Hollow Creek goes out at once.",
			"They heard it. All of them.",
		},
	})
	task.wait(5)
	if not state.finale or not root.Parent or humanoid.Health <= 0 then
		state.finale = false
		story(player, "FinaleAborted", {})
		return
	end
	local center = root.Position
	for i = 1, A.FinaleStalkers do
		local angle = i / A.FinaleStalkers * math.pi * 2
		local p = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 30
		local stalker = spawnStalker(player, state, Vector3.new(p.X, center.Y - 3, p.Z), 3.2, true)
		stalker.humanoid:MoveTo(center)
	end
	story(player, "Surrounded", { lines = { "There's nowhere left to run.", "Your hands are burning.", "Something inside you answers." } })
	-- Close in slowly.
	local started = os.clock()
	while os.clock() - started < 9 do
		if not state.finale then
			story(player, "FinaleAborted", {}) -- died during the finale; they can ring the bell again
			return
		end
		for stalker in state.stalkers do
			stalker.humanoid:MoveTo(root.Position)
		end
		task.wait(0.2)
	end
	if humanoid.Health < humanoid.MaxHealth * 0.5 then
		humanoid.Health = humanoid.MaxHealth * 0.5
	end
	-- The awakening.
	for stalker in table.clone(state.stalkers) do
		removeStalker(state, stalker, true)
	end
	if not player.Parent or not state.finale then
		return
	end
	local power = PowerService.AwakeningRoll(player)
	if not power then
		return
	end
	data.act = 2
	AchievementService.Grant(player, "awakened")
	if not state.touched then
		AchievementService.Grant(player, "unseen")
	end
	PlayerData.Sync(player)
	PlayerData.Save(player)
	Remotes.Fx:FireAllClients("AwakenBurst", { position = root.Position, color = power.color })
	story(player, "Roll", { power = power.id })
	-- If the client never reports the roll animation finished, move on anyway.
	task.delay(30, finishAct1, player)
end

-- Setup -----------------------------------------------------------------------------------

function Act1Director.OnCharacter(player: Player, character: Model)
	local state = getState(player)
	clearStalkers(state)
	state.finale = false
	state.finished = nil
	state.nextSpawn = os.clock() + 6
	local head = character:WaitForChild("Head", 5)
	if head then
		local light = Instance.new("SpotLight")
		light.Name = "Flashlight"
		light.Face = Enum.NormalId.Front
		light.Angle = 42
		light.Range = A.FlashlightRange
		light.Brightness = 3
		light.Color = Color3.fromRGB(255, 244, 220)
		light.Shadows = true
		light.Enabled = false
		light.Parent = head
	end
	local data = PlayerData.Get(player)
	local stage = data and data.act1Stage or 0
	if stage == 0 and data and not data.duckSaved then
		startIntro(player, state)
	end
	story(player, "Objective", { text = OBJECTIVES[stage], stage = stage })
end

function Act1Director.IsFlashlightOn(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.flashlight and os.clock() - state.lastPacket < 0.6
end

function Act1Director.NearestStalkerDistance(player: Player): number
	local state = states[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not state or not root then
		return math.huge
	end
	local best = math.huge
	for stalker in state.stalkers do
		if stalker.root.Parent then
			best = math.min(best, (stalker.root.Position - root.Position).Magnitude)
		end
	end
	if state.intruder and state.intruder.root.Parent then
		best = math.min(best, (state.intruder.root.Position - root.Position).Magnitude)
	end
	return best
end

function Act1Director.Start(worldInfo)
	world = worldInfo
	folder = Instance.new("Folder")
	folder.Name = "Stalkers"
	folder.Parent = workspace
	losParams.FilterDescendantsInstances = { world.map, workspace.Terrain }
	losParams.IgnoreWater = true

	local act1 = world.act1
	points = WorldBuilder.SamplePoints(world.floors, act1.bounds.min + Vector3.new(8, 0, 8), act1.bounds.max - Vector3.new(8, 0, 8), 220, Random.new(7), {
		{ at = act1.houseSpawn.Position, r = 18 },
	})

	Remotes.Flashlight.OnServerEvent:Connect(function(player: Player, on, eye, look)
		if typeof(eye) ~= "Vector3" or typeof(look) ~= "Vector3" or look.Magnitude < 0.5 then
			return
		end
		local state = getState(player)
		state.flashlight = on == true
		state.eye = eye
		state.look = look.Unit
		state.lastPacket = os.clock()
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local light = head and head:FindFirstChild("Flashlight")
		if light and light.Enabled ~= state.flashlight then
			light.Enabled = state.flashlight
		end
	end)

	act1.bellPrompt.Triggered:Connect(function(player: Player)
		task.spawn(finale, player)
	end)
	act1.notePrompt.Triggered:Connect(function(player: Player)
		story(player, "Note", {
			text = "If you wake up and we're not... I'm sorry, kiddo.\n\nThe sky went out at noon. They came in under the door like smoke. Your mother tried to keep them off Biscuit.\n\nLight hurts them. Keep your flashlight on them and they freeze.\n\nTake Biscuit and get to someone. Anyone. The radio station still has power.\n\nWe love you.\n- Dad",
		})
	end)

	Registry.PlayerDied:Connect(function(player: Player)
		local state = states[player]
		if state then
			clearStalkers(state)
			clearIntruder(state)
			state.finale = false
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local dt = now - last
			last = now
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("Act") == 1 then
					local ok, err = pcall(updatePlayer, player, getState(player), dt)
					if not ok then
						warn("[Shadowfall] Act 1 error:", err)
					end
				elseif states[player] and next(states[player].stalkers) and not states[player].finale then
					clearStalkers(states[player]) -- e.g. skipped Act 1 from the Dev menu
				end
			end
		end
	end)
end

function Act1Director.FinishRequested(player: Player)
	finishAct1(player)
end

function Act1Director.Forget(player: Player)
	local state = states[player]
	if state then
		clearStalkers(state)
		clearIntruder(state)
	end
	states[player] = nil
end

return Act1Director
