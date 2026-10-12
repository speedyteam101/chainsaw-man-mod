-- Dash afterimages made from a copy of the player's own avatar (body
-- parts, accessories, face and clothing meshes), fading out behind them.
-- Drawn by every client, for every player who dashes.

local TweenService = game:GetService("TweenService")

local Afterimages = {}

local folder = Instance.new("Folder")
folder.Name = "AuraFarmAfterimages"
folder.Parent = workspace

local function keepsLook(child: Instance): boolean
	-- Meshes, the face and PBR textures; everything else (joints, welds,
	-- attachments, sounds, scripts) is dropped from the copy.
	return child:IsA("DataModelMesh") or child:IsA("Decal") or child:IsA("SurfaceAppearance")
end

-- One frozen, fading copy of the character where it stands right now.
function Afterimages.snapshot(character: Model, duration: number)
	local ghost = Instance.new("Model")
	ghost.Name = "Afterimage"
	local fadeInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 0.95 then
			local copy = part:Clone() -- nil if the part isn't Archivable
			if copy then
				for _, child in ipairs(copy:GetChildren()) do
					if not keepsLook(child) then
						child:Destroy()
					end
				end
				copy.Anchored = true
				copy.CanCollide = false
				copy.CanQuery = false
				copy.CanTouch = false
				copy.CastShadow = false
				copy.Massless = true
				copy.CFrame = part.CFrame
				copy.Transparency = math.max(part.Transparency, 0.45)
				copy.Parent = ghost
				TweenService:Create(copy, fadeInfo, { Transparency = 1 }):Play()
				for _, decal in ipairs(copy:GetChildren()) do
					if decal:IsA("Decal") then
						TweenService:Create(decal, fadeInfo, { Transparency = 1 }):Play()
					end
				end
			end
		end
	end
	ghost.Parent = folder
	task.delay(duration + 0.05, function()
		ghost:Destroy()
	end)
end

-- A trail of snapshots over `length` seconds.
function Afterimages.trail(character: Model, length: number)
	task.spawn(function()
		local elapsed = 0
		while elapsed < length and character.Parent do
			Afterimages.snapshot(character, 0.3)
			task.wait(0.05)
			elapsed += 0.05
		end
	end)
end

return Afterimages
