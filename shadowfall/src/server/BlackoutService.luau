--!nonstrict
-- The Blackout: Act 2's recurring horror event.
--
-- Every so often the bell tolls, the lights stutter, and then every light in Hollow Creek dies.
-- For the next minute or so, something called the Hollow hunts each player who is out in the
-- open. Your powers pass straight through it. It only moves when you're not looking at it,
-- creeping closer every time you turn away, and only light (your flashlight, L) can drive it off.
-- If it reaches you: a scream, a lot of damage and a big sanity hit. The camp and base barriers
-- are safe. Make it through without being caught and you're rewarded.
--
-- Clients follow along through workspace attributes: Blackout = "warning" | "active" | nil and
-- BlackoutEnds = server time (workspace:GetServerTimeNow()).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShadowRig = require(ReplicatedStorage.Shared.ShadowRig)
local Registry = require(script.Parent.Registry)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local Act1Director = require(script.Parent.Act1Director)
local StoryService = require(script.Parent.StoryService)

local BlackoutService = {}
BlackoutService.OnSurvived = nil :: ((Player) -> ())? -- set by Main (feat)

local H = Config.Horror
local BO = H.Blackout
local rng = Random.new()
local folder: Folder
local hunts: { [Player]: any } = {} -- per player: { hollow, caught, nextSpawn }
local active = false

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.IgnoreWater = true

local function inSafety(player: Player, root: BasePart): boolean
	return Combat.GetState(player).inSafeZone or Registry.InBarrier(root.Position)
end

-- Act 2 characters get a head lamp too (Act 1 adds its own). Other players see it; your own
-- view uses a local light that follows your camera (Dread.luau).
function BlackoutService.OnCharacter(player: Player, character: Model)
	local data = PlayerData.Get(player)
	if not data or data.act ~= 2 then
		return
	end
	local head = character:WaitForChild("Head", 10)
	if head and not head:FindFirstChild("Flashlight") then
		local light = Instance.new("SpotLight")
		light.Name = "Flashlight"
		light.Face = Enum.NormalId.Front
		light.Angle = 45
		light.Range = H.FlashlightRange
		light.Brightness = 2.5
		light.Color = Color3.fromRGB(255, 244, 220)
		light.Shadows = true
		light.Enabled = false
		light.Parent = head
	end
end

local function removeHollow(hunt, banished: boolean)
	local hollow = hunt.hollow
	hunt.hollow = nil
	if hollow and hollow.model.Parent then
		if banished then
			Remotes.Fx:FireAllClients("Banish", { model = hollow.model })
			task.delay(0.6, function()
				hollow.model:Destroy()
			end)
		else
			hollow.model:Destroy()
		end
	end
end

local function spawnHollow(player: Player, hunt, root: BasePart)
	local view = Act1Director.View(player)
	local look = view.look or root.CFrame.LookVector
	-- Somewhere behind you, out at the edge of the fog.
	local spot
	for _ = 1, 12 do
		local angle = math.atan2(-look.Z, -look.X) + rng:NextNumber(-1.1, 1.1)
		local distance = rng:NextNumber(45, 70)
		local candidate = root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		losParams.FilterDescendantsInstances = { folder, player.Character }
		local hit = workspace:Raycast(candidate + Vector3.new(0, 40, 0), Vector3.new(0, -90, 0), losParams)
		if hit and not Registry.InBarrier(hit.Position) then
			spot = hit.Position
			break
		end
	end
	if not spot then
		return
	end
	local model = ShadowRig.Build({ name = "Hollow", scale = 1.3, armLength = 1.6, eyeColor = Color3.fromRGB(255, 255, 255), smokeRate = 26, tendrils = 6, eyeLight = true })
	model:PivotTo(CFrame.lookAt(spot + Vector3.new(0, 4.6, 0), Vector3.new(root.Position.X, spot.Y + 4.6, root.Position.Z)))
	model:SetAttribute("Owner", player.UserId)
	CollectionService:AddTag(model, "Hollow")
	model.Parent = folder
	pcall(function()
		model.PrimaryPart:SetNetworkOwner(nil)
	end)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.WalkSpeed = BO.StalkerSpeed
	hunt.hollow = { model = model, humanoid = humanoid, root = model.PrimaryPart, lit = 0, lastCreep = os.clock() }
	Remotes.Story:FireClient(player, "Whisper", { position = spot })
end

local function isLit(player: Player, hollow): boolean
	local view = Act1Director.View(player)
	if not view.on or not view.eye or not view.look or os.clock() - (view.lastPacket or 0) > 0.6 then
		return false
	end
	local target = hollow.root.Position + Vector3.new(0, 1, 0)
	local offset = target - view.eye
	if offset.Magnitude > H.FlashlightRange or offset.Unit:Dot(view.look) < 0.9 then
		return false
	end
	losParams.FilterDescendantsInstances = { folder, player.Character }
	return workspace:Raycast(view.eye, offset, losParams) == nil
end

local function update(player: Player, hunt, dt: number)
	local character, humanoid, root = Combat.GetCharacter(player)
	if not character or humanoid.Health <= 0 then
		removeHollow(hunt, false)
		return
	end
	local now = os.clock()
	local hollow = hunt.hollow
	if not hollow then
		if now >= hunt.nextSpawn and not inSafety(player, root) then
			spawnHollow(player, hunt, root)
		end
		return
	end
	if not hollow.model.Parent then
		hunt.hollow = nil
		return
	end
	-- Safe ground: it stops at the edge and waits, staring.
	if inSafety(player, root) then
		hollow.humanoid:MoveTo(hollow.root.Position)
		hollow.humanoid.WalkSpeed = 0
		return
	end
	if isLit(player, hollow) then
		hollow.humanoid.WalkSpeed = 0
		hollow.humanoid:MoveTo(hollow.root.Position)
		hollow.lit += dt
		hollow.model:SetAttribute("Lit", true)
		if hollow.lit >= BO.BurnTime then
			removeHollow(hunt, true)
			hunt.nextSpawn = now + BO.Respawn
			Remotes.Notify:FireClient(player, "Toast", { text = "The Hollow recoils from the light... for now.", color = Color3.fromRGB(255, 240, 200) })
		end
		return
	end
	hollow.model:SetAttribute("Lit", false)
	hollow.lit = math.max(0, hollow.lit - dt * 0.5)
	hollow.humanoid.WalkSpeed = BO.StalkerSpeed
	hollow.humanoid:MoveTo(root.Position)
	local offset = root.Position - hollow.root.Position
	local distance = offset.Magnitude
	local view = Act1Director.View(player)
	local look = view.look or root.CFrame.LookVector
	local watched = look:Dot(-offset.Unit) > 0.5
	-- Turn your back and it's suddenly much closer.
	if not watched and distance > 18 and now - hollow.lastCreep > 3 then
		hollow.lastCreep = now
		local closer = hollow.root.Position + offset.Unit * math.min(14, distance - 10)
		hollow.model:PivotTo(CFrame.lookAt(closer, Vector3.new(root.Position.X, closer.Y, root.Position.Z)))
	end
	if distance < BO.CatchDistance then
		removeHollow(hunt, false)
		hunt.caught = true
		hunt.nextSpawn = now + BO.Respawn
		humanoid:TakeDamage(humanoid.MaxHealth * BO.CatchDamage)
		Registry.SanityChange:Fire(player, -BO.SanityLoss)
		Remotes.Story:FireClient(player, "Jumpscare", {})
	end
end

local function eligible(player: Player): boolean
	local data = PlayerData.Get(player)
	return data ~= nil and data.act == 2
end

local function runBlackout()
	workspace:SetAttribute("Blackout", "warning")
	workspace:SetAttribute("BlackoutEnds", workspace:GetServerTimeNow() + BO.Warning)
	for _, player in Players:GetPlayers() do
		if eligible(player) then
			StoryService.Play(player, "first_blackout")
		end
	end
	task.wait(BO.Warning)
	active = true
	workspace:SetAttribute("Blackout", "active")
	workspace:SetAttribute("BlackoutEnds", workspace:GetServerTimeNow() + BO.Duration)
	for _, player in Players:GetPlayers() do
		if eligible(player) then
			hunts[player] = { caught = false, nextSpawn = os.clock() + rng:NextNumber(4, 10) }
		end
	end
	local started = os.clock()
	local last = os.clock()
	while os.clock() - started < BO.Duration do
		task.wait(0.1)
		local dt = os.clock() - last
		last = os.clock()
		for player, hunt in hunts do
			if not player.Parent then
				removeHollow(hunt, false)
				hunts[player] = nil
			else
				local ok, err = pcall(update, player, hunt, dt)
				if not ok then
					warn("[Shadowfall] blackout error:", err)
				end
			end
		end
	end
	active = false
	workspace:SetAttribute("Blackout", nil)
	workspace:SetAttribute("BlackoutEnds", nil)
	for player, hunt in hunts do
		removeHollow(hunt, false)
		if player.Parent and not hunt.caught then
			local data = PlayerData.Get(player)
			if data then
				data.essence += BO.Reward
				player:SetAttribute("Essence", data.essence)
				Remotes.Notify:FireClient(player, "Toast", { text = string.format("The lights come back. You made it through the dark. +%d Essence", BO.Reward), color = Color3.fromRGB(255, 230, 160) })
				if BlackoutService.OnSurvived then
					BlackoutService.OnSurvived(player)
				end
			end
		elseif player.Parent then
			Remotes.Notify:FireClient(player, "Toast", { text = "The lights come back.", color = Color3.fromRGB(200, 200, 210) })
		end
	end
	hunts = {}
end

function BlackoutService.IsActive(): boolean
	return active
end

function BlackoutService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Hollows"
	folder.Parent = workspace
	if not BO.Enabled then
		return
	end
	task.spawn(function()
		task.wait(BO.FirstDelay)
		while true do
			local anyone = false
			for _, player in Players:GetPlayers() do
				if eligible(player) then
					anyone = true
					break
				end
			end
			if anyone then
				local ok, err = pcall(runBlackout)
				if not ok then
					warn("[Shadowfall] blackout failed:", err)
					active = false
					workspace:SetAttribute("Blackout", nil)
				end
			end
			task.wait(rng:NextNumber(BO.Interval[1], BO.Interval[2]))
		end
	end)
	Registry.PlayerDied:Connect(function(player: Player)
		local hunt = hunts[player]
		if hunt then
			removeHollow(hunt, false)
			hunt.nextSpawn = os.clock() + BO.Respawn
		end
	end)
end

return BlackoutService
