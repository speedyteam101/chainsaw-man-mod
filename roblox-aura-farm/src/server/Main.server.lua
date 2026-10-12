-- Aura Farm server entry point: builds the map and wires everything up.

local Players = game:GetService("Players")

local Remotes = require(script.Parent.Remotes)
local World = require(script.Parent.World)
local AuraService = require(script.Parent.AuraService)
local BossService = require(script.Parent.BossService)
local PvpService = require(script.Parent.PvpService)
local ClassService = require(script.Parent.ClassService)
local Combat = require(script.Parent.Combat)

local altars = World.build()
ClassService.start()

-- "In a fight" for heroic lines: a boss fight or an enemy player nearby.
AuraService.setContextProvider(function(player: Player)
	local boss = BossService.contextFor(player)
	local pvp = PvpService.contextFor(player)
	local foe = boss.foeHealthFraction
	if pvp.foeHealthFraction and (foe == nil or pvp.foeHealthFraction < foe) then
		foe = pvp.foeHealthFraction
	end
	return { inFight = boss.inFight or pvp.inFight, foeHealthFraction = foe }
end)
AuraService.start()
BossService.start(altars)

Remotes.Action.OnServerEvent:Connect(Combat.handle)
Remotes.Shout.OnServerEvent:Connect(AuraService.handleMessage)
Remotes.ChooseClass.OnServerEvent:Connect(ClassService.request)

local function onPlayerAdded(player: Player)
	ClassService.setupPlayer(player)
	AuraService.setupPlayer(player, function(savedClassId)
		ClassService.onLoaded(player, savedClassId)
	end)

	local function onCharacter(character: Model)
		task.spawn(AuraService.setupCharacter, player, character)
		task.spawn(ClassService.applyCharacter, player, character)
		task.spawn(PvpService.watchCharacter, player, character)
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
