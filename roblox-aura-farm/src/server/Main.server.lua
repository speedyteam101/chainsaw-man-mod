-- Aura Farm server entry point: builds the map and wires everything up.

local Players = game:GetService("Players")

local Remotes = require(script.Parent.Remotes)
local World = require(script.Parent.World)
local AuraService = require(script.Parent.AuraService)
local BossService = require(script.Parent.BossService)
local Combat = require(script.Parent.Combat)

local altars = World.build()
AuraService.setContextProvider(BossService.contextFor)
AuraService.start()
BossService.start(altars)

Remotes.Action.OnServerEvent:Connect(Combat.handle)
Remotes.Shout.OnServerEvent:Connect(AuraService.handleMessage)

local function onPlayerAdded(player: Player)
	AuraService.setupPlayer(player)

	local function onCharacter(character: Model)
		task.spawn(AuraService.setupCharacter, player, character)
		task.spawn(BossService.watchCharacter, player, character)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	-- Player.Chatted may not fire for every message under TextChatService,
	-- so the client also forwards what it sends (duplicates are ignored).
	player.Chatted:Connect(function(message)
		AuraService.handleMessage(player, message)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(AuraService.removePlayer)
