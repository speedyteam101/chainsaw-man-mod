--!nonstrict
-- One place for every remote. The server creates them, clients wait for them.
--
--   Action      (client -> server) combat input: "M1", "Block", "Dodge", "Move", "Awaken", "Sprint"
--   Flashlight  (client -> server, unreliable) Act 1 flashlight state and aim
--   Request     (client -> server, RemoteFunction) menu actions: "Ascend", "Reroll", "KeepRoll", "Warp", "State", "Dev"
--   Fx          (server -> all clients) visual effects
--   Story       (server -> one client) Act 1 objectives, subtitles, finale, power roll
--   Notify      (server -> one client) toasts, feat unlocks, full state snapshots

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local DEFINITIONS = {
	Action = "RemoteEvent",
	Flashlight = "UnreliableRemoteEvent",
	Request = "RemoteFunction",
	Fx = "RemoteEvent",
	Story = "RemoteEvent",
	Notify = "RemoteEvent",
}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for name, className in DEFINITIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

for name in DEFINITIONS do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
