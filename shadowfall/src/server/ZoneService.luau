--!nonstrict
-- Area rules for Act 2: level gates, the camp safe zone, out-of-combat regeneration,
-- falling into the void, and warping between unlocked areas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Areas)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local Registry = require(script.Parent.Registry)

local ZoneService = {}

local TICK = 0.25
local lastWarp: { [Player]: number } = {}

function ZoneService.HubSpawn(): CFrame
	local spawn = Areas.ById.town.spawn
	return CFrame.lookAt(spawn, Vector3.new(0, spawn.Y, 0))
end

local function areaSpawn(area): CFrame
	return CFrame.lookAt(area.spawn, area.spawn + Vector3.new(1, 0, 0))
end

local function update(player: Player)
	local data = PlayerData.Get(player)
	local character, humanoid, root = Combat.GetCharacter(player)
	if not data or data.act ~= 2 or not character then
		return
	end
	local state = Combat.GetState(player)
	local position = root.Position
	local area = Areas.At(position) or Areas.List[1]
	if player:GetAttribute("Area") ~= area.id then
		player:SetAttribute("Area", area.id)
	end

	-- Gates: the client lets you walk through gates you've unlocked; the server double-checks.
	local gateLevel = Areas.GateLevelAt(position)
	if gateLevel > data.level then
		for _, a in Areas.List do
			if a.level == data.level + 1 and a.gateX then
				character:PivotTo(CFrame.new(a.gateX - 10, position.Y + 1, 0) * CFrame.Angles(0, math.pi / 2, 0))
				Remotes.Notify:FireClient(player, "Toast", { text = string.format("The gate to %s needs level %d. Earn a feat and Ascend.", a.name, a.level) })
				break
			end
		end
	end

	-- Fell into the void
	if position.Y < -50 then
		character:PivotTo(areaSpawn(area))
		root.AssemblyLinearVelocity = Vector3.zero
		humanoid.Health -= humanoid.MaxHealth * 0.15
		Remotes.Notify:FireClient(player, "Toast", { text = "The void spat you back out." })
	end

	-- Camp safe zone
	local atCamp = area.id == "town" and Vector2.new(position.X, position.Z).Magnitude < Config.Act2.CampRadius
	local inBarrier = Registry.InBarrier(position)
	local safe = atCamp or inBarrier
	if state.inSafeZone ~= safe then
		state.inSafeZone = safe
		character:SetAttribute("Safe", safe)
	end

	-- Regeneration out of combat (much faster at the fire)
	local now = os.clock()
	if humanoid.Health < humanoid.MaxHealth and (safe or now - state.lastDamaged > Config.Act2.RegenDelay) then
		local rate = atCamp and 0.12 or (inBarrier and 0.06 or Config.Act2.RegenPerSecond)
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * rate * TICK)
	end
end

function ZoneService.Warp(player: Player, areaId: string)
	local data = PlayerData.Get(player)
	local area = Areas.ById[areaId]
	local character = Combat.GetCharacter(player)
	if not data or not area or not character or data.act ~= 2 then
		return { ok = false, message = "You can't warp right now." }
	end
	if area.level > data.level then
		return { ok = false, message = string.format("%s needs level %d.", area.name, area.level) }
	end
	local now = os.clock()
	local state = Combat.GetState(player)
	if now - state.lastDamaged < 5 then
		return { ok = false, message = "You can't warp while in combat." }
	end
	if now - (lastWarp[player] or 0) < 6 then
		return { ok = false, message = "The path between places is still settling. Wait a moment." }
	end
	lastWarp[player] = now
	local target = area.id == "town" and ZoneService.HubSpawn() or areaSpawn(area)
	character:PivotTo(target)
	Remotes.Fx:FireAllClients("Blink", { from = target.Position, to = target.Position })
	return { ok = true }
end

function ZoneService.Forget(player: Player)
	lastWarp[player] = nil
end

function ZoneService.Start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(update, player)
				if not ok then
					warn("[Shadowfall] zone error:", err)
				end
			end
		end
	end)
end

return ZoneService
