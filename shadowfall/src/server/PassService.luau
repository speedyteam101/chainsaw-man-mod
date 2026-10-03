--!nonstrict
-- Tokens, passes and the Power Vault.
--
--   * Essence -> Tokens exchange (one way), with a cheaper newcomer rate.
--   * A welcome gift of Tokens the first time you reach the camp.
--   * Passes bought with Tokens, or optionally as real Roblox game passes (Passes.luau robuxId).
--
-- There is deliberately no way to turn Robux into Essence or Tokens: no developer products and no
-- MarketplaceService.ProcessReceipt handler. Keep it that way.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Passes = require(ReplicatedStorage.Shared.Passes)
local Powers = require(ReplicatedStorage.Shared.Powers)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)

local PassService = {}
PassService.OnOutfitChanged = nil :: ((Player) -> ())? -- set by Main (re-dresses Biscuit)

local E = Passes.Exchange
local SWAP_COOLDOWN = 15 -- seconds between Power Vault swaps

function PassService.Has(player: Player, passId: string): boolean
	local data = PlayerData.Get(player)
	return data ~= nil and data.passes ~= nil and data.passes[passId] == true
end

local function grant(player: Player, passId: string, how: string)
	local data = PlayerData.Get(player)
	local pass = Passes.ById[passId]
	if not data or not pass or data.passes[passId] then
		return
	end
	data.passes[passId] = true
	if passId == "vault" and data.power then
		data.vault[data.power] = true
	end
	Remotes.Notify:FireClient(player, "PassUnlocked", { id = passId, name = pass.name, how = how })
	PlayerData.Sync(player)
	PlayerData.Save(player)
end

-- Essence -> Tokens ------------------------------------------------------------------------

function PassService.Exchange(player: Player, amount)
	local data = PlayerData.Get(player)
	if not data or data.act ~= 2 then
		return { ok = false, message = "You can trade once you reach the camp." }
	end
	-- Reject NaN, infinities and anything too small before doing any arithmetic.
	if type(amount) ~= "number" or not (amount >= E.Step and amount < math.huge) then
		return { ok = false, message = string.format("Trade at least %d Essence.", E.Step) }
	end
	amount = math.min(math.floor(amount), data.essence)
	amount -= amount % E.Step
	if not (amount >= E.Step) then
		return { ok = false, message = string.format("You need at least %d Essence to trade.", E.Step) }
	end
	local tokens = Passes.Quote(amount, data.essenceTraded)
	if tokens <= 0 then
		return { ok = false, message = "That's not enough for a Token." }
	end
	data.essence -= amount
	data.essenceTraded += amount
	data.tokens += tokens
	PlayerData.Sync(player)
	return { ok = true, essence = amount, tokens = tokens }
end

-- The welcome gift. Safe to call any number of times.
function PassService.Welcome(player: Player)
	local data = PlayerData.Get(player)
	if not data or data.act ~= 2 or data.welcomeTokens then
		return
	end
	data.welcomeTokens = true
	data.tokens += E.WelcomeTokens
	Remotes.Notify:FireClient(player, "Toast", {
		text = string.format("Welcome gift: +%d Tokens! Spend them on passes in the Tokens tab [M].", E.WelcomeTokens),
		color = Color3.fromRGB(120, 230, 255),
	})
	PlayerData.Sync(player)
end

-- Passes -----------------------------------------------------------------------------------

function PassService.BuyWithTokens(player: Player, passId)
	local data = PlayerData.Get(player)
	local pass = Passes.ById[passId]
	if not data or not pass then
		return { ok = false }
	end
	if data.passes[passId] then
		return { ok = false, message = "You already own " .. pass.name .. "." }
	end
	if data.tokens < pass.price then
		return { ok = false, message = string.format("You need %d Tokens (you have %d).", pass.price, data.tokens) }
	end
	data.tokens -= pass.price
	grant(player, passId, "tokens")
	return { ok = true, name = pass.name }
end

-- Opens Roblox's own purchase prompt for a pass that has a real game pass id.
function PassService.PromptRobux(player: Player, passId)
	local pass = Passes.ById[passId]
	if not pass or (pass.robuxId or 0) <= 0 then
		return { ok = false, message = "That pass can only be bought with Tokens." }
	end
	if PassService.Has(player, passId) then
		return { ok = false, message = "You already own " .. pass.name .. "." }
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, pass.robuxId)
	end)
	if not ok then
		warn("[Shadowfall] PromptGamePassPurchase failed:", err)
		return { ok = false, message = "The store isn't available right now." }
	end
	return { ok = true }
end

-- Grants every pass the player already bought with Robux (e.g. on another server).
function PassService.CheckRobuxPasses(player: Player)
	for _, pass in Passes.List do
		if (pass.robuxId or 0) > 0 and not PassService.Has(player, pass.id) then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.robuxId)
			end)
			if ok and owns and player.Parent then
				grant(player, pass.id, "robux")
			end
		end
	end
end

-- Pass effects -----------------------------------------------------------------------------

function PassService.RollLuck(player: Player): number
	return PassService.Has(player, "lucky") and Passes.LuckMultiplier or 1
end

function PassService.GatherMultiplier(player: Player): number
	return PassService.Has(player, "belt") and Passes.GatherMultiplier or 1
end

-- Power Vault: remember a power the player has owned.
function PassService.Remember(player: Player, powerId: string?)
	local data = PlayerData.Get(player)
	if data and powerId and Powers.ById[powerId] and data.passes.vault then
		data.vault[powerId] = true
	end
end

function PassService.EquipVaulted(player: Player, powerId)
	local data = PlayerData.Get(player)
	if not data or data.act ~= 2 then
		return { ok = false }
	end
	if not data.passes.vault then
		return { ok = false, message = "You need the Power Vault pass." }
	end
	if type(powerId) ~= "string" or not data.vault[powerId] or not Powers.ById[powerId] then
		return { ok = false, message = "That power isn't in your vault." }
	end
	if data.power == powerId then
		return { ok = false, message = "You're already using it." }
	end
	local state = Combat.GetState(player)
	local now = os.clock()
	if now - (state.lastDamaged or 0) < 5 then
		return { ok = false, message = "You can't swap powers in the middle of a fight." }
	end
	if now < (state.nextVaultSwap or 0) then
		return { ok = false, message = string.format("You can swap again in %d seconds.", math.ceil(state.nextVaultSwap - now)) }
	end
	state.nextVaultSwap = now + SWAP_COOLDOWN
	data.power = powerId
	-- Cooldowns carry over (per slot, whichever is longer), plus a short lockout, so swapping
	-- back and forth never makes a move ready sooner.
	state.cooldowns = state.cooldowns or {}
	for slot = 1, 4 do
		state.cooldowns[slot] = math.max(state.cooldowns[slot] or 0, now + 4)
		Remotes.Notify:FireClient(player, "Cooldown", { slot = slot, duration = state.cooldowns[slot] - now })
	end
	PlayerData.Sync(player)
	return { ok = true, power = powerId }
end

function PassService.SetDuckOutfit(player: Player, index)
	local data = PlayerData.Get(player)
	if not data then
		return { ok = false }
	end
	if not data.passes.wardrobe then
		return { ok = false, message = "You need Biscuit's Wardrobe." }
	end
	if type(index) ~= "number" or not Passes.DuckOutfits[index] then
		return { ok = false }
	end
	data.duckOutfit = math.floor(index)
	if PassService.OnOutfitChanged then
		PassService.OnOutfitChanged(player)
	end
	PlayerData.Sync(player)
	return { ok = true }
end

function PassService.Start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, purchased: boolean)
		if not purchased then
			return
		end
		for _, pass in Passes.List do
			if pass.robuxId == gamePassId then
				grant(player, pass.id, "robux")
			end
		end
	end)
end

function PassService.OnLoaded(player: Player)
	local data = PlayerData.Get(player)
	if data and data.passes.vault and data.power then
		data.vault[data.power] = true
	end
	task.spawn(PassService.CheckRobuxPasses, player)
end

return PassService
