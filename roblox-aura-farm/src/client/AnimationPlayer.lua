-- Plays your animations from Animations.lua on the local player's
-- character. Animations played on your own character replicate to everyone.
--   Movement (Idle / Walk / Run / Jump / Fall): swapped into the
--   character's "Animate" script, which keeps choosing between them.
--   Dashes, slashes and the ultimate: played here when you use them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Animations"))

local AnimationPlayer = {}

local player = Players.LocalPlayer
local settings = Animations.Settings

local tracks: { [string]: AnimationTrack } = {}
local tracksFor: Animator? = nil

local function classAndSide(): (string?, string?)
	return player:GetAttribute("ClassId"), player:GetAttribute("Side")
end

local function animatorOf(character: Model?): Animator?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

-- A loaded (cached) track for an animation ID on the current character.
local function trackFor(id: string): AnimationTrack?
	local animator = animatorOf(player.Character)
	if not animator then
		return nil
	end
	if animator ~= tracksFor then
		table.clear(tracks)
		tracksFor = animator
	end
	local track = tracks[id]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, result = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not ok then
			warn("[AuraFarm] Couldn't load animation", id, result)
			return nil
		end
		track = result
		track.Priority = Enum.AnimationPriority.Action
		tracks[id] = track
	end
	return track
end

local function play(id: any): AnimationTrack?
	if type(id) ~= "string" then
		return nil
	end
	local track = trackFor(id)
	if track then
		track:Play(settings.FadeTime)
	end
	return track
end

-- The character's Animate script slot names for each movement animation.
local ANIMATE_SLOTS = { Idle = "idle", Walk = "walk", Run = "run", Jump = "jump", Fall = "fall" }

-- Swap your movement animations into the character's Animate script, then
-- restart it so it uses them.
function AnimationPlayer.applyMovement(character: Model)
	local animate = character:WaitForChild("Animate", 10)
	if not animate then
		return
	end
	local classId, side = classAndSide()
	local changed = false
	for name, slot in pairs(ANIMATE_SLOTS) do
		local id = Animations.get(name, classId, side)
		local holder = animate:FindFirstChild(slot)
		if type(id) == "string" and holder then
			for _, child in ipairs(holder:GetChildren()) do
				if child:IsA("Animation") then
					child.AnimationId = id
					changed = true
				end
			end
		end
	end
	if changed and animate:IsA("BaseScript") then
		local animator = animatorOf(character)
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop(0)
			end
		end
		animate.Enabled = false
		task.wait()
		animate.Enabled = true
	end
end

-- Dash animation for a dash going (localX, localZ) in the character's own
-- space. Falls back to DashForward if that direction has none.
function AnimationPlayer.playDash(localX: number, localZ: number)
	local classId, side = classAndSide()
	local direction = Animations.dashDirection(localX, localZ)
	local id = Animations.get("Dash" .. direction, classId, side) or Animations.get("DashForward", classId, side)
	local track = play(id)
	if track then
		task.delay(settings.DashHold, function()
			if track.IsPlaying and track.Looped then
				track:Stop(settings.FadeTime)
			end
		end)
	end
end

local comboIndex, lastSlash = 0, -math.huge

-- The next slash in your combo.
function AnimationPlayer.playSlash()
	local classId, side = classAndSide()
	local list = Animations.get("Slash", classId, side)
	if type(list) ~= "table" then
		return
	end
	local now = os.clock()
	if now - lastSlash > settings.ComboReset then
		comboIndex = 0
	end
	lastSlash = now
	comboIndex = comboIndex % #list + 1
	play(list[comboIndex])
end

function AnimationPlayer.playUltimate()
	local classId, side = classAndSide()
	play(Animations.get("Ultimate", classId, side))
end

return AnimationPlayer
