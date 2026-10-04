--!nonstrict
-- Client entry point.

local StarterGui = game:GetService("StarterGui")

local Client = script.Parent

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

for _, name in { "CameraFx", "FirstPerson", "CharacterCreator", "Atmosphere", "ShadowAnimator", "VillagerAnimator", "Fx", "Horror", "SanityFx", "DuckClient", "Hud", "Guide", "Dread", "Cinematic", "ShopUI", "BuildMode", "Menu", "CombatInput" } do
	local ok, err = pcall(function()
		require(Client:WaitForChild(name)).Start()
	end)
	if not ok then
		warn("[Shadowfall] failed to start", name, err)
	end
end

-- Messages from build mode and item use show up as HUD toasts.
local Hud = require(Client.Hud)
require(Client.BuildMode).OnMessage = function(text, color)
	Hud.Toast(text, color, 3)
end
require(Client.CombatInput).OnMessage = function(text)
	Hud.Toast(text, nil, 2)
end
