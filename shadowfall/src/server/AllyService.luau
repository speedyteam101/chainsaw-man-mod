--!nonstrict
-- Allies summoned by powers (Necromancer skeletons, Phantom clones). They follow their owner,
-- hunt the nearest shadow, and fade away when their time runs out. Shadows don't target them.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Powers = require(ReplicatedStorage.Shared.Powers)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShadowRig = require(ReplicatedStorage.Shared.ShadowRig)
local Registry = require(script.Parent.Registry)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)

local AllyService = {}

local MAX_ALLIES = 10
local allies = {} -- list of ally objects
local folder: Folder
local rng = Random.new()

local STYLES = {
	Skeleton = { bodyColor = Color3.fromRGB(226, 218, 196), eyeColor = Color3.fromRGB(110, 255, 150), material = Enum.Material.SmoothPlastic, speed = 20 },
	Clone = { eyeColor = Color3.new(1, 1, 1), material = Enum.Material.ForceField, transparency = 0.2, speed = 26 },
}

local function countFor(player: Player): number
	local n = 0
	for _, ally in allies do
		if ally.owner == player and not ally.gone then
			n += 1
		end
	end
	return n
end

local function remove(ally)
	if ally.gone then
		return
	end
	ally.gone = true
	Remotes.Fx:FireAllClients("Dissolve", { model = ally.model })
	task.delay(0.9, function()
		ally.model:Destroy()
	end)
end

function AllyService.Summon(player: Player, kind: string, count: number, duration: number, damage: number, at: Vector3?)
	local _, _, root = Combat.GetCharacter(player)
	if not root then
		return
	end
	local style = STYLES[kind] or STYLES.Skeleton
	local data = PlayerData.Get(player)
	local power = data and data.power and Powers.ById[data.power]
	local color = kind == "Clone" and (power and power.color or Color3.new(1, 1, 1)) or style.bodyColor
	for i = 1, count do
		if countFor(player) >= MAX_ALLIES then
			-- Replace the oldest one.
			for _, ally in allies do
				if ally.owner == player and not ally.gone then
					remove(ally)
					break
				end
			end
		end
		local angle = i / count * math.pi * 2
		local spot = (at or root.Position) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 5
		local model = ShadowRig.Build({
			name = kind,
			eyeColor = style.eyeColor,
			bodyColor = color,
			bodyMaterial = style.material,
			bodyTransparency = style.transparency,
			noSmoke = true,
			tendrils = 0,
		})
		model:PivotTo(CFrame.new(spot + Vector3.new(0, 1, 0)))
		model:SetAttribute("Owner", player.UserId)
		model:SetAttribute("AllyKind", kind)
		CollectionService:AddTag(model, "Ally")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		humanoid.WalkSpeed = style.speed
		model.Parent = folder
		pcall(function()
			model.PrimaryPart:SetNetworkOwner(nil)
		end)
		table.insert(allies, {
			owner = player,
			model = model,
			humanoid = humanoid,
			root = model.PrimaryPart,
			expires = os.clock() + duration,
			damage = damage,
			nextAttack = 0,
		})
		Remotes.Fx:FireAllClients("Rise", { position = spot, color = kind == "Skeleton" and Color3.fromRGB(110, 255, 150) or color })
	end
end

local function think(ally)
	local now = os.clock()
	local _, _, ownerRoot = Combat.GetCharacter(ally.owner)
	if not ally.owner.Parent or not ownerRoot or now > ally.expires or ally.owner:GetAttribute("Act") ~= 2 then
		remove(ally)
		return
	end
	local root = ally.root
	if (root.Position - ownerRoot.Position).Magnitude > 90 or root.Position.Y < -60 then
		ally.model:PivotTo(ownerRoot.CFrame * CFrame.new(rng:NextNumber(-4, 4), 0, 4))
	end
	-- Hunt the nearest shadow near the owner.
	local best, bestDistance = nil, 50
	for _, enemy in Registry.Enemies do
		if not enemy.dead then
			local d = (enemy.root.Position - root.Position).Magnitude
			if d < bestDistance and (enemy.root.Position - ownerRoot.Position).Magnitude < 70 then
				best, bestDistance = enemy, d
			end
		end
	end
	if best then
		ally.humanoid:MoveTo(best.root.Position)
		local reach = 4.5 + 1.4 * (best.scale or 1)
		if bestDistance <= reach and now >= ally.nextAttack then
			ally.nextAttack = now + 0.9
			ally.model:SetAttribute("Attacking", true)
			task.delay(0.25, function()
				if ally.model.Parent then
					ally.model:SetAttribute("Attacking", false)
				end
			end)
			Remotes.Fx:FireAllClients("Claw", { model = ally.model, color = Color3.fromRGB(180, 255, 200) })
			Combat.DamageEnemy(best, ally.damage * Combat.DamageMultiplier(ally.owner), ally.owner, { color = Color3.fromRGB(180, 255, 200) })
		end
	else
		local follow = ownerRoot.CFrame * CFrame.new(rng:NextNumber(-6, 6), 0, 6)
		if (root.Position - follow.Position).Magnitude > 6 then
			ally.humanoid:MoveTo(follow.Position)
		end
	end
end

function AllyService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Allies"
	folder.Parent = workspace

	-- Necromancer (and anything else with raiseChance): fallen shadows rise for you.
	Registry.EnemyKilled:Connect(function(enemy, killer: Player?)
		if not killer or not killer.Parent then
			return
		end
		local data = PlayerData.Get(killer)
		local power = data and data.power and Powers.ById[data.power]
		local chance = power and power.passiveEffect.raiseChance
		if chance and not enemy.isBoss and rng:NextNumber() < chance then
			task.delay(0.6, function()
				AllyService.Summon(killer, "Skeleton", 1, 20, 16, enemy.root.Position)
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, ally in allies do
			if ally.owner == player then
				remove(ally)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.15)
			for index = #allies, 1, -1 do
				local ally = allies[index]
				if ally.gone then
					table.remove(allies, index)
				else
					local ok, err = pcall(think, ally)
					if not ok then
						warn("[Shadowfall] ally error:", err)
					end
				end
			end
		end
	end)
end

return AllyService
