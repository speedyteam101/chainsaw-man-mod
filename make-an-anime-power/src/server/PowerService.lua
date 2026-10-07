-- Saved powers: loading/saving with DataStores, the Power Creator remotes,
-- and applying the equipped power to the player's character.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PowerValidator = require(Shared.PowerValidator)
local Remotes = require(Shared.Remotes)
local Status = require(script.Parent.Status)
local Visuals = require(script.Parent.Visuals)
local CombatService = require(script.Parent.CombatService)

local PowerService = {}

local AUTOSAVE_INTERVAL = 90
local REQUEST_COOLDOWN = 0.4 -- per player, for the creator remotes

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[PowerService] DataStores unavailable, powers won't be saved:", result)
	end
end

-- [Player] = { powers = {...}, equipped = number, loaded = bool, canSave = bool, dirty = bool, lastRequest = number }
local sessions = {}

----------------------------------------------------------------------
-- Text filtering (required by Roblox for text other players can see)
----------------------------------------------------------------------

local function filterText(text: string, userId: number): string?
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, userId)
	end)
	if not ok then
		return nil
	end
	local ok2, filtered = pcall(function()
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok2 then
		return nil
	end
	return filtered
end

-- Filters every name in a power. If filtering fails, the name is replaced
-- with a safe default rather than shown unfiltered.
local function filterPower(power, userId: number)
	power.name = filterText(power.name, userId) or "Power"
	for _, ability in power.abilities do
		ability.name = filterText(ability.name, userId) or "Ability"
	end
	return power
end

----------------------------------------------------------------------
-- Data
----------------------------------------------------------------------

local function publicData(session)
	return {
		powers = session.powers,
		equipped = session.equipped,
		canSave = session.canSave,
	}
end

local function sendData(player: Player)
	local session = sessions[player]
	if session then
		Remotes.DataChanged:FireClient(player, publicData(session))
	end
end

local function load(player: Player)
	local session = {
		powers = {},
		equipped = 0,
		loaded = false,
		canSave = false,
		dirty = false,
		lastRequest = 0,
	}
	sessions[player] = session

	if store then
		local ok, saved = pcall(function()
			return store:GetAsync("u_" .. player.UserId)
		end)
		if ok then
			session.canSave = true
			if type(saved) == "table" and type(saved.powers) == "table" then
				for _, raw in saved.powers do
					local power = PowerValidator.sanitize(raw)
					if power and #session.powers < Config.MaxSavedPowers then
						table.insert(session.powers, power)
					end
				end
				if type(saved.equipped) == "number" and session.powers[saved.equipped] then
					session.equipped = saved.equipped
				end
			end
		else
			-- Don't save over data we failed to read
			warn("[PowerService] Failed to load data for", player.Name, saved)
		end
	end

	session.loaded = true
	return session
end

local function save(player: Player)
	local session = sessions[player]
	if not session or not store or not session.canSave or not session.dirty then
		return
	end
	session.dirty = false
	local ok, err = pcall(function()
		store:SetAsync("u_" .. player.UserId, {
			version = 1,
			powers = session.powers,
			equipped = session.equipped,
		}, { player.UserId })
	end)
	if not ok then
		session.dirty = true
		warn("[PowerService] Failed to save data for", player.Name, err)
	end
end

----------------------------------------------------------------------
-- Character
----------------------------------------------------------------------

local function equippedPower(player: Player)
	local session = sessions[player]
	return session and session.powers[session.equipped] or nil
end

local function clearPowerVisuals(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant.Name == "PowerAura" or descendant.Name == "PowerAuraLight" or descendant.Name == "PowerTag" then
			descendant:Destroy()
		end
	end
end

local function makeNameTag(head: BasePart, power, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PowerTag"
	gui.Size = UDim2.fromOffset(200, 26)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 120
	gui.AlwaysOnTop = false

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = power.name
	label.Parent = gui

	gui.Parent = head
end

local function applyToCharacter(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end

	local power = equippedPower(player)
	local stats = power and power.stats or { strength = 0, defense = 0, speed = 0, energy = 0 }

	-- Keep the same health percentage, so equipping can't be used to heal
	local ratio = humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth or 1
	humanoid.MaxHealth = Config.BaseHealth + stats.defense * Config.HealthPerDefense
	humanoid.Health = humanoid.MaxHealth * ratio
	Status.setBaseSpeed(humanoid, Config.BaseWalkSpeed + stats.speed * Config.WalkSpeedPerSpeed)

	clearPowerVisuals(character)
	if power then
		local color = PowerValidator.colorOf(power)
		Visuals.makeAura(root, power.aura, color)
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			makeNameTag(head, power, color)
		end
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local powerValue = leaderstats and leaderstats:FindFirstChild("Power")
	if powerValue and powerValue:IsA("StringValue") then
		powerValue.Value = power and power.name or "None"
	end

	CombatService.setPower(player, power)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or character.Parent == nil then
		return
	end
	Status.reset(humanoid :: Humanoid)
	applyToCharacter(player)
	CombatService.onCharacterSpawned(player)
end

----------------------------------------------------------------------
-- Remotes
----------------------------------------------------------------------

local function checkRequest(player: Player)
	local session = sessions[player]
	if not session or not session.loaded then
		return nil, "Still loading, try again in a moment."
	end
	local now = os.clock()
	if now - session.lastRequest < REQUEST_COOLDOWN then
		return nil, "Slow down!"
	end
	session.lastRequest = now
	return session, nil
end

local function onSavePower(player: Player, index: any, raw: any)
	local session, err = checkRequest(player)
	if not session then
		return { ok = false, message = err }
	end

	local power = PowerValidator.sanitize(raw)
	if not power then
		return { ok = false, message = "That power couldn't be read." }
	end
	if #power.abilities == 0 then
		return { ok = false, message = "Give your power at least one ability." }
	end
	filterPower(power, player.UserId)

	local slot
	if type(index) == "number" and session.powers[index] then
		slot = index
	elseif #session.powers < Config.MaxSavedPowers then
		slot = #session.powers + 1
	else
		return { ok = false, message = "You can save up to " .. Config.MaxSavedPowers .. " powers. Delete one first." }
	end

	session.powers[slot] = power
	session.equipped = slot
	session.dirty = true
	applyToCharacter(player)
	sendData(player)

	local message = "Saved and equipped " .. power.name .. "!"
	if not session.canSave then
		message ..= " (Saving is off here, so it will be lost when you leave.)"
	end
	return { ok = true, index = slot, message = message }
end

local function onDeletePower(player: Player, index: any)
	local session, err = checkRequest(player)
	if not session then
		return { ok = false, message = err }
	end
	if type(index) ~= "number" or not session.powers[index] then
		return { ok = false, message = "That power doesn't exist." }
	end

	table.remove(session.powers, index)
	if session.equipped == index then
		session.equipped = 0
	elseif session.equipped > index then
		session.equipped -= 1
	end
	session.dirty = true
	applyToCharacter(player)
	sendData(player)
	return { ok = true, message = "Power deleted." }
end

local function onEquipPower(player: Player, index: any)
	local session, err = checkRequest(player)
	if not session then
		return { ok = false, message = err }
	end
	if type(index) ~= "number" or (index ~= 0 and not session.powers[index]) then
		return { ok = false, message = "That power doesn't exist." }
	end
	session.equipped = index
	session.dirty = true
	applyToCharacter(player)
	sendData(player)
	return {
		ok = true,
		message = index == 0 and "Power unequipped." or ("Equipped " .. session.powers[index].name .. "!"),
	}
end

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local kos = Instance.new("IntValue")
	kos.Name = "KOs"
	kos.Parent = leaderstats
	local powerName = Instance.new("StringValue")
	powerName.Name = "Power"
	powerName.Value = "None"
	powerName.Parent = leaderstats
	leaderstats.Parent = player

	load(player)
	if player.Parent == nil then
		return -- left while loading
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	sendData(player)
end

function PowerService.init()
	Remotes.GetPowerData.OnServerInvoke = function(player)
		local session = sessions[player]
		while not session or not session.loaded do
			task.wait(0.2)
			if player.Parent == nil then
				return nil
			end
			session = sessions[player]
		end
		return publicData(session)
	end
	Remotes.SavePower.OnServerInvoke = onSavePower
	Remotes.DeletePower.OnServerInvoke = onDeletePower
	Remotes.EquipPower.OnServerInvoke = onEquipPower

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		sessions[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(save, player)
		end
		task.wait(3)
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)
end

return PowerService
