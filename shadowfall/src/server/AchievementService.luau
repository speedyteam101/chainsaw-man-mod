--!nonstrict
-- Tracks feats and handles Ascension (levelling up). There is no XP: the only way to reach the
-- next level is to earn a feat that qualifies for it, then choose to Ascend.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(ReplicatedStorage.Shared.Achievements)
local Areas = require(ReplicatedStorage.Shared.Areas)
local Config = require(ReplicatedStorage.Shared.Config)
local Powers = require(ReplicatedStorage.Shared.Powers)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)

local AchievementService = {}

function AchievementService.Grant(player: Player, id: string)
	local data = PlayerData.Get(player)
	local achievement = Achievements.ById[id]
	if not data or not achievement or data.achievements[id] then
		return false
	end
	data.achievements[id] = os.time()
	local qualifiesNow = achievement.qualifies ~= nil and achievement.qualifies == data.level + 1
	Remotes.Notify:FireClient(player, "Achievement", {
		id = id,
		name = achievement.name,
		desc = achievement.desc,
		qualifies = achievement.qualifies,
		canAscendNow = qualifiesNow,
	})
	PlayerData.Sync(player)
	return true
end

local function checkGoal(player: Player, id: string, value: number)
	local achievement = Achievements.ById[id]
	if achievement.goal and value >= achievement.goal then
		AchievementService.Grant(player, id)
	end
end

function AchievementService.Ascend(player: Player)
	local data = PlayerData.Get(player)
	if not data or data.act ~= 2 then
		return { ok = false, message = "You haven't awakened yet." }
	end
	if data.level >= Config.MaxLevel then
		return { ok = false, message = "You have already reached the highest level." }
	end
	local nextLevel = data.level + 1
	if not Achievements.IsQualified(data.achievements, nextLevel) then
		return { ok = false, message = "Earn a feat that qualifies you for level " .. nextLevel .. " first." }
	end
	data.level = nextLevel
	local _, humanoid = Combat.GetCharacter(player)
	if humanoid then
		humanoid.MaxHealth = Combat.MaxHealthFor(data)
		humanoid.Health = humanoid.MaxHealth
	end

	local unlocks = {}
	local power = data.power and Powers.ById[data.power]
	if power and power.moves[nextLevel] then
		local move = power.moves[nextLevel]
		table.insert(unlocks, string.format("New move: %s [%s]", move.name, move.key))
	end
	if nextLevel == 5 then
		table.insert(unlocks, "Awakening [G]: a burst of overwhelming power")
	end
	for _, area in Areas.List do
		if area.level == nextLevel then
			table.insert(unlocks, "New area: " .. area.name)
		end
	end
	table.insert(unlocks, string.format("Damage x%.1f, Max health %d", Config.LevelDamage[nextLevel], Config.Act2.BaseMaxHealth + (nextLevel - 1) * Config.Act2.HealthPerLevel))

	local character = player.Character
	Remotes.Fx:FireAllClients("Ascend", { character = character, color = power and power.color or Color3.new(1, 1, 1) })
	Registry.Ascended:Fire(player, nextLevel)
	if nextLevel == Config.MaxLevel then
		AchievementService.Grant(player, "ascendant")
	end
	PlayerData.Sync(player)
	PlayerData.Save(player)
	return { ok = true, level = nextLevel, unlocks = unlocks }
end

function AchievementService.Start()
	Registry.EnemyKilled:Connect(function(enemy, killer: Player?, damagers)
		-- Bosses: everyone who dealt real damage gets the feat.
		if enemy.isBoss then
			for player, dealt in damagers do
				if player.Parent and dealt >= enemy.maxHp * 0.05 then
					AchievementService.Grant(player, enemy.def.achievement)
					if not enemy.hitPlayers[player] then
						AchievementService.Grant(player, "flawless")
					end
				end
			end
		end
		if not killer or not killer.Parent then
			return
		end
		local data = PlayerData.Get(killer)
		if not data then
			return
		end
		local session = Combat.GetState(killer).session
		local now = os.clock()
		data.stats.kills += 1
		session.noDamageStreak += 1
		session.noDeathStreak += 1
		table.insert(session.killTimes, now)
		while #session.killTimes > 0 and now - session.killTimes[1] > 3 do
			table.remove(session.killTimes, 1)
		end
		if #session.killTimes >= 4 then
			AchievementService.Grant(killer, "chain_reaction")
		end
		checkGoal(killer, "untouchable", session.noDamageStreak)
		checkGoal(killer, "unbroken", session.noDeathStreak)
		checkGoal(killer, "last_light", session.noDeathStreak)
		checkGoal(killer, "hundred", data.stats.kills)
		if enemy.def.behaviour == "brute" and not enemy.hitPlayers[killer] then
			data.stats.bruteClean += 1
			checkGoal(killer, "giant_slayer", data.stats.bruteClean)
		end
		PlayerData.Sync(killer)
	end)

	Registry.PlayerDamaged:Connect(function(player: Player, _, source)
		local session = Combat.GetState(player).session
		session.noDamageStreak = 0
		if source and source.enemy then
			source.enemy.hitPlayers[player] = true
		end
	end)

	Registry.Parried:Connect(function(player: Player)
		local data = PlayerData.Get(player)
		if data then
			data.stats.parries += 1
			checkGoal(player, "steady_hand", data.stats.parries)
			PlayerData.Sync(player)
		end
	end)

	Registry.PerfectDodge:Connect(function(player: Player)
		local data = PlayerData.Get(player)
		if data then
			data.stats.perfectDodges += 1
			checkGoal(player, "shadowstep", data.stats.perfectDodges)
			PlayerData.Sync(player)
		end
	end)

	Registry.PlayerDied:Connect(function(player: Player)
		local session = Combat.GetState(player).session
		session.noDeathStreak = 0
		session.noDamageStreak = 0
	end)

	Registry.PowerRolled:Connect(function(player: Player, powerId: string)
		local power = Powers.ById[powerId]
		if power.rarity == "Legendary" or power.rarity == "Mythic" or power.rarity == "Transcendent" then
			AchievementService.Grant(player, "lucky")
		end
		if power.rarity == "Mythic" or power.rarity == "Transcendent" then
			AchievementService.Grant(player, "mythic")
		end
		if power.rarity == "Transcendent" then
			AchievementService.Grant(player, "transcendent")
		end
	end)
end

return AchievementService
