--!nonstrict
-- Brings the people of Hollow Creek to life. Camp survivors wander around the bonfire, rescued
-- townsfolk wander inside their rescuer's base barrier, and merchants stay at their stalls. All
-- of them stop to face you when you come close, and do little things when idle: warm their hands
-- at the fire, hammer (carpenters and blacksmiths), look around, wave.
--
-- The server only moves them (Humanoid:MoveTo) and sets an "Activity" attribute; the animation
-- itself is done on each client by VillagerAnimator.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local NpcService = {}

type Npc = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	home: Vector3,
	radius: number,
	minRadius: number,
	stay: boolean,
	role: string,
	state: string,
	target: Vector3?,
	startedAt: number,
	nextMove: number,
	greeted: { [Player]: number },
}

local npcs: { [Model]: Npc } = {}
local rng = Random.new()
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.IgnoreWater = true

local TICK = 0.35
local TALK_RANGE = 10

local function groundAt(position: Vector3): Vector3?
	local map = workspace:FindFirstChild("Map")
	groundParams.FilterDescendantsInstances = map and { map, workspace.Terrain } or { workspace.Terrain }
	local hit = workspace:Raycast(position + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), groundParams)
	return hit and hit.Position or nil
end

local function nearestPlayer(npc: Npc): (Player?, number)
	local best, bestDistance = nil, math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (root.Position - npc.root.Position).Magnitude
			if d < bestDistance then
				best, bestDistance = player, d
			end
		end
	end
	return best, bestDistance
end

local IDLE_ACTIVITIES = {
	survivor = { "", "", "lookaround", "warm", "warm" },
	carpenter = { "", "work", "work", "lookaround" },
	blacksmith = { "", "work", "work", "lookaround" },
	townsfolk = { "", "", "lookaround" },
	merchant = { "", "lookaround", "" },
}

local function setActivity(npc: Npc, activity: string)
	if npc.model:GetAttribute("Activity") ~= activity then
		npc.model:SetAttribute("Activity", activity)
	end
end

local function faceTowards(npc: Npc, position: Vector3)
	local from = npc.root.Position
	local flat = Vector3.new(position.X, from.Y, position.Z)
	if (flat - from).Magnitude > 0.5 then
		npc.root.CFrame = npc.root.CFrame:Lerp(CFrame.lookAt(from, flat), 0.5)
	end
end

local function pickTarget(npc: Npc): Vector3?
	for _ = 1, 6 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = npc.minRadius + math.sqrt(rng:NextNumber()) * math.max(1, npc.radius - npc.minRadius)
		local spot = npc.home + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		local ground = groundAt(spot)
		if ground and math.abs(ground.Y - npc.home.Y) < 6 then
			return ground
		end
	end
	return nil
end

local function think(npc: Npc, now: number)
	local player, distance = nearestPlayer(npc)
	-- Someone came over: stop, turn to them, and wave the first time.
	if player and distance < TALK_RANGE then
		if npc.state == "walk" then
			npc.humanoid:MoveTo(npc.root.Position)
		end
		npc.state = "talk"
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			faceTowards(npc, root.Position)
		end
		if now - (npc.greeted[player] or 0) > 60 then
			npc.greeted[player] = now
			setActivity(npc, "wave")
			task.delay(1.6, function()
				if npc.model:GetAttribute("Activity") == "wave" then
					setActivity(npc, "talk")
				end
			end)
		elseif npc.model:GetAttribute("Activity") ~= "wave" then
			setActivity(npc, "talk")
		end
		npc.nextMove = now + rng:NextNumber(2, 4)
		return
	end
	if npc.state == "talk" then
		npc.state = "idle"
		setActivity(npc, "")
	end

	if npc.state == "walk" then
		local target = npc.target
		local flat = target and Vector2.new(target.X - npc.root.Position.X, target.Z - npc.root.Position.Z).Magnitude or 0
		if not target or flat < 2.5 or now - npc.startedAt > 12 then
			npc.state = "idle"
			npc.nextMove = now + rng:NextNumber(4, 10)
			local options = IDLE_ACTIVITIES[npc.role] or IDLE_ACTIVITIES.townsfolk
			local activity = options[rng:NextInteger(1, #options)]
			if activity == "warm" and npc.role == "survivor" then
				faceTowards(npc, npc.home) -- the bonfire is at the middle of the camp
			end
			setActivity(npc, activity)
		else
			npc.humanoid:MoveTo(target) -- MoveTo times out after ~8s; keep re-issuing
		end
		return
	end

	-- Idle: wander somewhere else when it's time.
	if not npc.stay and now >= npc.nextMove then
		local target = pickTarget(npc)
		if target then
			npc.target = target
			npc.state = "walk"
			npc.startedAt = now
			setActivity(npc, "")
			npc.humanoid:MoveTo(target)
		else
			npc.nextMove = now + 3
		end
	end
end

-- opts: { home = Vector3 (centre of where they wander), radius = number, minRadius = number,
--         role = string,
--         stay = boolean (merchants: never wander) }
function NpcService.Register(model: Model, opts)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	if not humanoid or not root then
		return
	end
	-- People never body-block players (same collision group as Biscuit).
	if PhysicsService:IsCollisionGroupRegistered("Ducks") then
		root.CollisionGroup = "Ducks"
	end
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	if opts.stay then
		root.Anchored = true
	end
	npcs[model] = {
		model = model,
		humanoid = humanoid,
		root = root,
		home = opts.home or root.Position,
		radius = opts.radius or 20,
		minRadius = opts.minRadius or 6, -- keep clear of the bonfire / crystal in the middle
		stay = opts.stay == true,
		role = opts.role or "townsfolk",
		state = "idle",
		target = nil,
		startedAt = 0,
		nextMove = os.clock() + rng:NextNumber(1, 8),
		greeted = {},
	}
	model:SetAttribute("Activity", "")
end

-- Rescued townsfolk follow their rescuer's barrier as it grows.
function NpcService.SetArea(model: Model, home: Vector3, radius: number)
	local npc = npcs[model]
	if npc then
		npc.home = home
		npc.radius = radius
	end
end

function NpcService.Start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = os.clock()
			for model, npc in npcs do
				if not model.Parent then
					npcs[model] = nil
				else
					local ok, err = pcall(think, npc, now)
					if not ok then
						warn("[Shadowfall] npc error:", err)
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, npc in npcs do
			npc.greeted[player] = nil
		end
	end)
end

return NpcService
