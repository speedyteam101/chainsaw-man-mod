--!nonstrict
-- Materials and items. Everything goes through here so the client snapshot stays in sync.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Materials = require(ReplicatedStorage.Shared.Materials)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local InventoryService = {}

local pendingSync: { [Player]: boolean } = {}

-- Batches several changes in one frame into a single snapshot.
function InventoryService.Changed(player: Player)
	if pendingSync[player] then
		return
	end
	pendingSync[player] = true
	task.defer(function()
		pendingSync[player] = nil
		if player.Parent then
			PlayerData.Sync(player)
		end
	end)
end

function InventoryService.Count(player: Player, id: string): number
	local data = PlayerData.Get(player)
	return data and (data.inventory[id] or 0) or 0
end

function InventoryService.Add(player: Player, id: string, amount: number, showToast: boolean?)
	local data = PlayerData.Get(player)
	if not data or amount <= 0 or not Materials.ById[id] then
		return
	end
	data.inventory[id] = (data.inventory[id] or 0) + amount
	if showToast ~= false then
		Remotes.Notify:FireClient(player, "Gathered", { id = id, amount = amount })
	end
	InventoryService.Changed(player)
end

function InventoryService.Has(player: Player, cost): boolean
	local data = PlayerData.Get(player)
	if not data then
		return false
	end
	for id, amount in cost do
		if (data.inventory[id] or 0) < amount then
			return false
		end
	end
	return true
end

-- Removes the whole cost or nothing. Returns true on success.
function InventoryService.Spend(player: Player, cost): boolean
	if not InventoryService.Has(player, cost) then
		return false
	end
	local data = PlayerData.Get(player)
	for id, amount in cost do
		data.inventory[id] -= amount
	end
	InventoryService.Changed(player)
	return true
end

function InventoryService.HasItem(player: Player, id: string): boolean
	local data = PlayerData.Get(player)
	return data ~= nil and (data.items[id] or 0) > 0
end

function InventoryService.AddItem(player: Player, id: string, amount: number)
	local data = PlayerData.Get(player)
	if data then
		data.items[id] = (data.items[id] or 0) + amount
		InventoryService.Changed(player)
	end
end

function InventoryService.TakeItem(player: Player, id: string): boolean
	local data = PlayerData.Get(player)
	if not data or (data.items[id] or 0) <= 0 then
		return false
	end
	data.items[id] -= 1
	InventoryService.Changed(player)
	return true
end

return InventoryService
