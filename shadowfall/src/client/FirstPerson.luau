--!nonstrict
-- The whole game is played in first person. This keeps your own arms visible (so you can see
-- your punches and casts), draws a small crosshair, and frees the mouse whenever a menu or
-- dialogue is open.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Ui)
local ClientState = require(script.Parent.ClientState)

local FirstPerson = {}

local player = Players.LocalPlayer
local VISIBLE = { ["Left Arm"] = true, ["Right Arm"] = true, LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true }

function FirstPerson.Start()
	local gui = Ui.screen("Crosshair", 3)
	local dot = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25,
		Parent = gui,
	}, { Ui.corner(3), Ui.stroke(Color3.new(0, 0, 0), 1, 0.4) })

	-- An invisible modal button: while it's visible, the mouse is free even in first person.
	local freeMouse = Ui.new("TextButton", {
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Text = "",
		Modal = true,
		Visible = false,
		Parent = gui,
	})

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		if character then
			for _, child in character:GetChildren() do
				if child:IsA("BasePart") and VISIBLE[child.Name] then
					child.LocalTransparencyModifier = 0
				end
			end
			-- Your own Radiant Aura sparkles would fill the screen; other players still see them.
			local torso = character:FindFirstChild("Torso")
			local sparkles = torso and torso:FindFirstChild("RadiantAura")
			if sparkles and sparkles:IsA("Sparkles") and sparkles.Enabled then
				sparkles.Enabled = false
			end
			-- Your own hair (from the character creator) would block the view from inside your head.
			local hair = character:FindFirstChild("LookHair")
			local head = character:FindFirstChild("Head")
			if hair and head then
				local inside = (workspace.CurrentCamera.CFrame.Position - head.Position).Magnitude < 2
				for _, part in hair:GetChildren() do
					if part:IsA("BasePart") then
						part.LocalTransparencyModifier = inside and 1 or 0
					end
				end
			end
		end
		local needsMouse = ClientState.MenuOpen or ClientState.DialogueOpen or ClientState.CreatorOpen or false
		freeMouse.Visible = needsMouse
		dot.Visible = not needsMouse and not ClientState.InCutscene and player:GetAttribute("Act") == 2
		dot.BackgroundColor3 = ClientState.BuildMode and Color3.fromRGB(140, 220, 255) or Color3.new(1, 1, 1)
		if needsMouse then
			UserInputService.MouseIconEnabled = true
		end
	end)
end

return FirstPerson
