--!nonstrict
-- Server-simulated projectiles for both players and shadows. Clients draw them from the
-- "Projectile" fx event using the same origin, direction and speed, and remove them on "ProjectileEnd".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Combat = require(script.Parent.Combat)

local Projectiles = {}

local active = {}
local nextId = 0
local mapParams = RaycastParams.new()
mapParams.FilterType = Enum.RaycastFilterType.Include
mapParams.IgnoreWater = true

-- spec: { team = "player"|"enemy", owner = Player?, enemy = enemy?, origin, direction, speed, range,
--         radius, damage, pierce, effects, color, size }
function Projectiles.Fire(spec)
	nextId += 1
	spec.id = nextId
	spec.position = spec.origin
	spec.travelled = 0
	spec.hit = {}
	spec.direction = spec.direction.Unit
	table.insert(active, spec)
	Remotes.Fx:FireAllClients("Projectile", {
		id = spec.id,
		origin = spec.origin,
		direction = spec.direction,
		speed = spec.speed,
		range = spec.range,
		radius = spec.radius,
		color = spec.color,
		team = spec.team,
	})
end

local function finish(spec, position: Vector3)
	spec.done = true
	Remotes.Fx:FireAllClients("ProjectileEnd", { id = spec.id, position = position, color = spec.color, radius = spec.radius })
end

local function step(dt: number)
	if #active == 0 then
		return
	end
	local map = workspace:FindFirstChild("Map")
	if map then
		mapParams.FilterDescendantsInstances = { map, workspace.Terrain }
	end
	for index = #active, 1, -1 do
		local spec = active[index]
		local move = spec.direction * spec.speed * dt
		local wallHit = map and workspace:Raycast(spec.position, move, mapParams)
		local nextPosition = wallHit and wallHit.Position or spec.position + move
		local segmentStart = spec.position
		spec.position = nextPosition
		spec.travelled += move.Magnitude

		if spec.team == "player" then
			for _, enemy in Combat.EnemiesAlongSegment(segmentStart, nextPosition, spec.radius * 2) do
				if not spec.hit[enemy] then
					spec.hit[enemy] = true
					Combat.DamageEnemy(enemy, spec.damage, spec.owner, { effects = spec.effects, sourcePosition = segmentStart, color = spec.color })
					if not spec.pierce then
						finish(spec, enemy.root.Position)
						break
					end
				end
			end
		else
			for _, target in Combat.TargetablePlayers() do
				if not spec.hit[target.player] and Combat.DistanceToSegment(target.root.Position, segmentStart, nextPosition) <= spec.radius + 1.6 then
					spec.hit[target.player] = true
					Combat.DamagePlayer(target.player, spec.damage, { enemy = spec.enemy, position = segmentStart, kind = "projectile" })
					if not spec.pierce then
						finish(spec, target.root.Position)
						break
					end
				end
			end
		end

		if not spec.done and (wallHit or spec.travelled >= spec.range) then
			finish(spec, nextPosition)
		end
		if spec.done then
			table.remove(active, index)
		end
	end
end

function Projectiles.Start()
	RunService.Heartbeat:Connect(step)
end

return Projectiles
