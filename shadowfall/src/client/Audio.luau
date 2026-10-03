--!nonstrict
-- Plays the sounds listed in Config.Sounds. Missing ids are skipped silently, so the game
-- works (quietly) until you add your own sound assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Audio = {}
local loops: { [string]: Sound } = {}

local function make(name: string, parent: Instance?): Sound?
	local id = Config.Sounds[name]
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Parent = parent or SoundService
	return sound
end

function Audio.Play(name: string, volume: number?, pitch: number?, at: Vector3?)
	local holder
	if at then
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.one * 0.1
		p.CFrame = CFrame.new(at)
		p.Parent = workspace
		holder = p
	end
	local sound = make(name, holder)
	if not sound then
		if holder then
			holder:Destroy()
		end
		return
	end
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = pitch or 1
	if at then
		sound.RollOffMaxDistance = 120
	end
	sound:Play()
	sound.Ended:Connect(function()
		(holder or sound):Destroy()
	end)
end

function Audio.Loop(name: string, volume: number?)
	if loops[name] then
		loops[name].Volume = volume or loops[name].Volume
		return loops[name]
	end
	local sound = make(name)
	if not sound then
		return nil
	end
	sound.Looped = true
	sound.Volume = volume or 0.4
	sound:Play()
	loops[name] = sound
	return sound
end

function Audio.StopLoop(name: string)
	if loops[name] then
		loops[name]:Destroy()
		loops[name] = nil
	end
end

function Audio.GetLoop(name: string): Sound?
	return loops[name]
end

return Audio
