-- Make an Anime Power: client entry point.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Fx = require(script.Parent.Fx)
local HUD = require(script.Parent.HUD)
local Creator = require(script.Parent.Creator)
local Controls = require(script.Parent.Controls)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

Fx.init(Remotes.Fx)

local hudGui = Instance.new("ScreenGui")
hudGui.Name = "AnimePowerHUD"
hudGui.ResetOnSpawn = false
hudGui.DisplayOrder = 1
hudGui.Parent = playerGui

local creatorGui = Instance.new("ScreenGui")
creatorGui.Name = "AnimePowerCreator"
creatorGui.ResetOnSpawn = false
creatorGui.DisplayOrder = 5
creatorGui.Parent = playerGui

local hud = HUD.new(hudGui)

local function call(remote: RemoteFunction, ...)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if ok then
		return result
	end
	return { ok = false, message = "Couldn't reach the server. Try again." }
end

local creator = Creator.new(creatorGui, {
	save = function(index, power)
		return call(Remotes.SavePower, index, power)
	end,
	delete = function(index)
		return call(Remotes.DeletePower, index)
	end,
	equip = function(index)
		return call(Remotes.EquipPower, index)
	end,
	notify = function(text)
		hud:notify(text)
	end,
})

local function applyData(data)
	if type(data) ~= "table" then
		return
	end
	creator:setData(data)
	hud:setPower(data.powers[data.equipped])
end

Remotes.DataChanged.OnClientEvent:Connect(applyData)
Remotes.AbilityResult.OnClientEvent:Connect(function(slot, cooldown)
	hud:startCooldown(slot, cooldown)
end)
Remotes.Notify.OnClientEvent:Connect(function(text)
	hud:notify(text)
end)

local function useAbility(slot: number, aim: Vector3)
	if not hud.power or not hud.power.abilities[slot] or hud:isOnCooldown(slot) then
		return
	end
	Remotes.UseAbility:FireServer(slot, aim)
end

local function basicAttack(aim: Vector3)
	Remotes.BasicAttack:FireServer(aim)
end

hud.onSlotPressed = function(slot)
	useAbility(slot, Controls.aimForButton())
end
hud.onAttackPressed = function()
	basicAttack(Controls.aimForButton())
end
hud.onCreatorPressed = function()
	creator:toggle()
end

Controls.init({
	useAbility = useAbility,
	basicAttack = basicAttack,
	toggleCreator = function()
		creator:toggle()
	end,
}, Fx.getFolder())

-- Load saved powers. New players start in the template list.
local ok, data = pcall(Remotes.GetPowerData.InvokeServer, Remotes.GetPowerData)
if ok and type(data) == "table" then
	applyData(data)
	if #data.powers == 0 then
		creator:open("Templates")
		hud:notify("Welcome! Pick an anime template to make your first power.")
	end
else
	hud:notify("Couldn't load your powers. Press P to make one.")
end
