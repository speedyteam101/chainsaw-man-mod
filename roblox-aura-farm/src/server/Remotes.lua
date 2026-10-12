-- Creates the RemoteEvents the client and server talk through.
--   Action (client -> server): "Slash" | "Dash" | "Ultimate"
--   Shout  (client -> server): a chat message / heroic line to score
--   ChooseClass (client -> server): a class Id from Classes.lua
--   Notify (server -> client): a table with a Kind field (see Hud.lua)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "AuraFarmRemotes"

local function event(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local Remotes = {
	Action = event("Action"),
	Shout = event("Shout"),
	ChooseClass = event("ChooseClass"),
	Notify = event("Notify"),
}

folder.Parent = ReplicatedStorage

return Remotes
