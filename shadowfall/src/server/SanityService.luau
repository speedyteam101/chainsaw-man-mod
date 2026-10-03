--!nonstrict
-- Sanity (0-100). The dark and the shadows wear it down; Biscuit, light, the camp fire and your
-- base build it back up. Low sanity brings hallucinations (client) and, near zero, real damage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Areas)
local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(script.Parent.Registry)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local InventoryService = require(script.Parent.InventoryService)
local DuckService = require(script.Parent.DuckService)
local Act1Director = require(script.Parent.Act1Director)

local SanityService = {}

local S = Config.Sanity
local TICK = 0.25
local sanity: { [Player]: number } = {}

-- Set by Main once BaseService exists (avoids a require cycle).
SanityService.BaseBonus = function(_player: Player): number
	return 0
end

function SanityService.Get(player: Player): number
	return sanity[player] or S.Max
end

function SanityService.Change(player: Player, delta: number)
	local value = math.clamp(SanityService.Get(player) + delta, 0, S.Max)
	sanity[player] = value
	local shown = math.floor(value + 0.5)
	if player:GetAttribute("Sanity") ~= shown then
		player:SetAttribute("Sanity", shown)
	end
end

local function nearestShadow(player: Player, root: BasePart, act: number): number
	if act == 1 then
		return Act1Director.NearestStalkerDistance(player)
	end
	local best = math.huge
	for _, enemy in Registry.Enemies do
		if not enemy.dead then
			best = math.min(best, (enemy.root.Position - root.Position).Magnitude)
		end
	end
	return best
end

local function update(player: Player)
	local data = PlayerData.Get(player)
	local character, humanoid, root = Combat.GetCharacter(player)
	if not data or not character then
		return
	end
	local delta = 0
	local drainMult = InventoryService.HasItem(player, "Lantern") and 0.6 or 1
	local area = Areas.At(root.Position)

	-- Drains
	if data.act == 1 then
		delta -= (Act1Director.IsFlashlightOn(player) and S.Act1FlashlightDrain or S.Act1Drain) * drainMult
	elseif area then
		delta -= (S.AreaDrain[area.id] or 0) * drainMult
	end
	if nearestShadow(player, root, data.act) <= S.NearShadowRange then
		delta -= S.NearShadowDrain * drainMult
	end

	-- Comforts
	local nearDuck = DuckService.IsNear(player)
	if nearDuck then
		delta += S.DuckRegen
	end
	if data.act == 2 then
		if area and area.id == "town" and Vector2.new(root.Position.X, root.Position.Z).Magnitude < Config.Act2.CampRadius then
			delta += S.CampRegen
		end
		local ownBase = SanityService.BaseBonus(player)
		if ownBase > 0 then
			delta += ownBase
		elseif Registry.InBarrier(root.Position) then
			delta += S.AnyBarrierRegen
		end
	end
	SanityService.Change(player, delta * TICK)

	-- Biscuit's company heals, too.
	if nearDuck and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + S.DuckHealthRegen * TICK)
	end

	-- At the bottom, the dark starts to hurt.
	local value = SanityService.Get(player)
	if value < S.DamageBelow then
		local severity = value <= 0 and 2 or 1
		humanoid.Health -= humanoid.MaxHealth * S.DamagePerSecond * severity * TICK
	end
end

function SanityService.OnCharacter(player: Player)
	-- Coming back from the brink leaves you shaken, but never below RespawnValue.
	local current = sanity[player]
	sanity[player] = current and math.max(current, S.RespawnValue) or S.Max
	player:SetAttribute("Sanity", math.floor(sanity[player] + 0.5))
end

function SanityService.Start()
	Registry.SanityChange:Connect(SanityService.Change)
	Players.PlayerRemoving:Connect(function(player)
		sanity[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(update, player)
				if not ok then
					warn("[Shadowfall] sanity error:", err)
				end
			end
		end
	end)
end

return SanityService
