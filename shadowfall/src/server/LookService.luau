--!nonstrict
-- Character customisation. A brand-new player doesn't get a character until they've finished the
-- character creator (the "NeedsLook" attribute tells their client to show it). After that, the
-- saved look is applied every time they spawn, and it can be changed any time from the menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Looks = require(ReplicatedStorage.Shared.Looks)
local Figure = require(ReplicatedStorage.Shared.Figure)
local PlayerData = require(script.Parent.PlayerData)

local LookService = {}

-- How long to wait for a new player to finish the creator before spawning them anyway with the
-- default look (so nobody is ever stuck on a blank screen if their UI fails to load).
local CREATOR_TIMEOUT = 600

local waiting: { [Player]: thread } = {}
local lastSave: { [Player]: number } = {}
local SAVE_COOLDOWN = 3

function LookService.Description(look): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	local colors = Looks.Colors(look)
	description.HeadColor = colors.Head
	description.TorsoColor = colors.Torso
	description.LeftArmColor = colors["Left Arm"]
	description.RightArmColor = colors["Right Arm"]
	description.LeftLegColor = colors["Left Leg"]
	description.RightLegColor = colors["Right Leg"]
	return description
end

-- Adds the realistic details (face, hair, clothes, shoes) to a character wearing a custom look.
local function dress(character: Model, look)
	local old = character:FindFirstChild("LookDetails")
	if old then
		old:Destroy()
	end
	if look.avatar then
		return
	end
	for _, name in { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		if not character:WaitForChild(name, 10) then
			return
		end
	end
	Figure.Dress(character, Figure.FromLook(look))
end

-- Called for every new character.
function LookService.OnCharacter(player: Player, character: Model)
	local data = PlayerData.Get(player)
	if data and data.look then
		dress(character, Looks.Sanitize(data.look))
	end
end

-- Spawns `player` wearing their saved look. Returns false if the caller should spawn normally.
function LookService.Spawn(player: Player): boolean
	local data = PlayerData.Get(player)
	if not data or not data.look then
		return false
	end
	local look = Looks.Sanitize(data.look)
	if look.avatar then
		return false
	end
	local ok, err = pcall(function()
		player:LoadCharacterWithHumanoidDescriptionAsync(LookService.Description(look))
	end)
	if not ok then
		warn("[Shadowfall] Couldn't spawn with the custom look, using the avatar instead:", err)
	end
	return ok
end

-- Blocks until a brand-new player has picked a look (or the timeout passes).
-- Returns true if the player went through the creator just now (a brand-new character).
function LookService.WaitForLook(player: Player): boolean
	local data = PlayerData.Get(player)
	if not data or data.look or not player.Parent then
		return false -- (no Parent: they left while their data was loading)
	end
	player:SetAttribute("NeedsLook", true)
	local me = coroutine.running()
	waiting[player] = me
	task.delay(CREATOR_TIMEOUT, function()
		if waiting[player] == me then
			waiting[player] = nil
			data.look = Looks.Default()
			task.defer(me)
		end
	end)
	coroutine.yield()
	if player.Parent then
		player:SetAttribute("NeedsLook", nil)
	end
	return true
end

function LookService.Save(player: Player, raw)
	local data = PlayerData.Get(player)
	if not data then
		return { ok = false }
	end
	local look = Looks.Sanitize(raw)

	local thread = waiting[player]
	if thread then
		-- First time: the spawn code was waiting for this.
		data.look = look
		PlayerData.Sync(player)
		waiting[player] = nil
		task.defer(thread)
		return { ok = true }
	end

	-- Changing an existing character in place. Throttled: applying a description (and fetching
	-- your Roblox avatar) is expensive.
	local now = os.clock()
	if now - (lastSave[player] or -math.huge) < SAVE_COOLDOWN then
		return { ok = false, message = "Give it a moment before changing again." }
	end
	lastSave[player] = now
	data.look = look
	PlayerData.Sync(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid and humanoid.Health > 0 then
		task.spawn(function()
			local ok, err = pcall(function()
				local description = if look.avatar
					then Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
					else LookService.Description(look)
				humanoid:ApplyDescriptionAsync(description)
			end)
			if not ok then
				warn("[Shadowfall] Couldn't apply the new look:", err)
			end
			if character.Parent then
				dress(character, look)
			end
		end)
	end
	return { ok = true }
end

function LookService.Forget(player: Player)
	lastSave[player] = nil
	local thread = waiting[player]
	waiting[player] = nil
	if thread then
		task.defer(thread) -- let the spawn code finish (it checks player.Parent)
	end
end

return LookService
