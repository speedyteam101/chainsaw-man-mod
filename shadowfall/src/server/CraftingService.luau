--!nonstrict
-- Crafting and using consumables. Station recipes need that station built (finished) in your
-- base and you standing inside your barrier; some also need a rescued carpenter or blacksmith.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Townsfolk = require(ReplicatedStorage.Shared.Townsfolk)
local Registry = require(script.Parent.Registry)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local InventoryService = require(script.Parent.InventoryService)
local DuckService = require(script.Parent.DuckService)

local CraftingService = {}

-- Set by Main once BaseService exists: function(player, stationId) -> boolean
CraftingService.HasStationNearby = function(_player: Player, _station: string): boolean
	return false
end
CraftingService.OnCrafted = nil -- function(player) for feats

function CraftingService.Craft(player: Player, recipeId: string)
	local data = PlayerData.Get(player)
	local recipe = Recipes.ById[recipeId]
	if not data or not recipe then
		return { ok = false, message = "Unknown recipe." }
	end
	if data.act ~= 2 then
		return { ok = false, message = "You can't craft yet." }
	end
	if recipe.needs and Townsfolk.Roles(data.rescued)[recipe.needs] == 0 then
		return { ok = false, message = string.format("You need a rescued %s for this.", string.lower(recipe.needs)) }
	end
	if recipe.station and not CraftingService.HasStationNearby(player, recipe.station) then
		return { ok = false, message = string.format("You need to be in your base with a finished %s.", Recipes.StationNames[recipe.station]) }
	end
	if recipe.requiresItem and not InventoryService.HasItem(player, recipe.requiresItem) then
		return { ok = false, message = "You need the " .. Recipes.ById[recipe.requiresItem].name .. " first." }
	end
	if (recipe.kind == "tool" or recipe.kind == "gear") and InventoryService.HasItem(player, recipe.id) then
		return { ok = false, message = "You already have a " .. recipe.name .. "." }
	end
	if not InventoryService.Spend(player, recipe.cost) then
		return { ok = false, message = "You don't have the materials." }
	end
	if recipe.kind == "material" then
		for id, amount in recipe.output do
			InventoryService.Add(player, id, amount, false)
		end
	else
		InventoryService.AddItem(player, recipe.id, 1)
	end
	data.stats.crafted += 1
	if CraftingService.OnCrafted then
		CraftingService.OnCrafted(player)
	end
	local character = player.Character
	Remotes.Fx:FireAllClients("Crafted", { character = character })
	return { ok = true, name = recipe.name }
end

function CraftingService.Use(player: Player, itemId: string)
	local data = PlayerData.Get(player)
	local character, humanoid, root = Combat.GetCharacter(player)
	if not data or data.act ~= 2 or not character then
		return { ok = false }
	end
	local state = Combat.GetState(player)
	state.itemReady = state.itemReady or {}
	local now = os.clock()
	if now < (state.itemReady[itemId] or 0) then
		return { ok = false, message = "Not yet." }
	end
	if itemId == "Bandage" then
		if humanoid.Health >= humanoid.MaxHealth then
			return { ok = false, message = "You're not hurt." }
		end
		if not InventoryService.TakeItem(player, itemId) then
			return { ok = false, message = "You have no bandages." }
		end
		Combat.HealPlayer(player, humanoid.MaxHealth * 0.35)
		Remotes.Fx:FireAllClients("Buff", { character = character, color = Color3.fromRGB(120, 255, 140), duration = 1 })
	elseif itemId == "Tonic" then
		if not InventoryService.TakeItem(player, itemId) then
			return { ok = false, message = "You have no tonics." }
		end
		Registry.SanityChange:Fire(player, 40)
		Remotes.Fx:FireAllClients("Buff", { character = character, color = Color3.fromRGB(150, 200, 255), duration = 1 })
	elseif itemId == "DuckBread" then
		local duck = DuckService.Get(player)
		if not duck or not DuckService.IsNear(player) then
			return { ok = false, message = "Biscuit needs to be right next to you." }
		end
		if not InventoryService.TakeItem(player, itemId) then
			return { ok = false, message = "You have no duck bread." }
		end
		Registry.SanityChange:Fire(player, 35)
		Remotes.Fx:FireAllClients("Hearts", { model = duck.model })
		Remotes.Notify:FireClient(player, "DuckSay", { text = "QUACK QUACK! (Biscuit gobbles the bread and does a happy little dance.)" })
	elseif itemId == "LightBomb" then
		if not InventoryService.TakeItem(player, itemId) then
			return { ok = false, message = "You have no light bombs." }
		end
		local damage = 40 * (Config.LevelDamage[data.level] or 1)
		Remotes.Fx:FireAllClients("Strike", { position = root.Position, radius = 16, color = Color3.fromRGB(255, 250, 220) })
		for _, enemy in Combat.EnemiesInSphere(root.Position, 16) do
			Combat.DamageEnemy(enemy, damage, player, { effects = { stun = 2.5 }, sourcePosition = root.Position, color = Color3.fromRGB(255, 250, 220) })
		end
	else
		return { ok = false }
	end
	state.itemReady[itemId] = now + 2
	return { ok = true }
end

return CraftingService
