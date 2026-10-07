-- All RemoteEvents / RemoteFunctions. The server creates them; clients wait
-- for them. Require this module instead of looking remotes up by hand.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFINITIONS = {
	-- client -> server
	GetPowerData = "RemoteFunction", -- () -> data
	SavePower = "RemoteFunction", -- (index?, power) -> result
	DeletePower = "RemoteFunction", -- (index) -> result
	EquipPower = "RemoteFunction", -- (index) -> result
	UseAbility = "RemoteEvent", -- (slot, aimPosition)
	BasicAttack = "RemoteEvent", -- (aimPosition)

	-- server -> client
	DataChanged = "RemoteEvent", -- (data)
	AbilityResult = "RemoteEvent", -- (slot, cooldownSeconds)
	Notify = "RemoteEvent", -- (text)
	Fx = "RemoteEvent", -- (kind, info) visual effects, drawn by every client
}

local Remotes = {}

if RunService:IsServer() then
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for name, className in DEFINITIONS do
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
		Remotes[name] = remote
	end
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for name in DEFINITIONS do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
