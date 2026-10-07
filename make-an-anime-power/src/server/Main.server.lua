-- Make an Anime Power: server entry point.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
require(ReplicatedStorage.Shared.Remotes) -- creates the remotes before clients look for them

local World = require(script.Parent.World)
local CombatService = require(script.Parent.CombatService)
local PowerService = require(script.Parent.PowerService)
local EnemyService = require(script.Parent.EnemyService)

Players.RespawnTime = Config.RespawnTime

local enemiesFolder = World.build()
CombatService.init(enemiesFolder)
PowerService.init()
EnemyService.init(enemiesFolder)
