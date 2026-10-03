--!nonstrict
-- Client entry point.

local StarterGui = game:GetService("StarterGui")

local Client = script.Parent

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

for _, name in { "CameraFx", "Atmosphere", "ShadowAnimator", "Fx", "Horror", "Hud", "Menu", "CombatInput" } do
	local ok, err = pcall(function()
		require(Client:WaitForChild(name)).Start()
	end)
	if not ok then
		warn("[Shadowfall] failed to start", name, err)
	end
end
