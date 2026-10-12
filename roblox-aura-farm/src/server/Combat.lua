-- Validates the player's Slash / Dash / Ultimate requests. The client moves
-- itself for the dash; the server owns cooldowns, i-frames and damage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AuraService = require(script.Parent.AuraService)
local BossService = require(script.Parent.BossService)
local Effects = require(script.Parent.Effects)

local Combat = {}

local SLASH_COLOR = Color3.fromRGB(210, 235, 255)

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function slash(player: Player, root: BasePart, state)
	local now = os.clock()
	if now - state.lastSlash < Config.Combat.SlashCooldown then
		return
	end
	state.lastSlash = now
	Effects.slash(root.CFrame, SLASH_COLOR)

	local distance = BossService.distanceTo(root.Position)
	if not distance or distance > Config.Combat.SlashRange then
		return
	end
	if BossService.damage(player, Config.Combat.SlashDamage, "Slash") then
		AuraService.addStyle(player, Config.Style.PerHit)
		local styleRank = AuraService.styleRank(player)
		local aura = math.floor(Config.Combat.AuraPerHit * styleRank.Multiplier + 0.5)
		AuraService.addAura(player, aura, nil, nil, true)
	end
end

local function dash(_player: Player, root: BasePart, state)
	local now = os.clock()
	-- A little slack for network jitter versus the client's own cooldown.
	if now - state.lastDash < Config.Combat.DashCooldown - 0.15 then
		return
	end
	state.lastDash = now
	state.dashStartPos = root.Position
	state.invulnerableUntil = now + Config.Combat.DashInvulnerability
end

local function ultimate(player: Player, root: BasePart, state)
	local now = os.clock()
	if now - state.lastUltimate < Config.Combat.UltimateCooldown then
		return
	end
	if state.style < Config.Combat.UltimateStyleCost then
		AuraService.notify(player, { Kind = "Message", Text = "Reach S style rank to unleash your ultimate!" })
		return
	end
	local boss = BossService.getActive()
	local distance = BossService.distanceTo(root.Position)
	if not boss or not distance or distance > Config.Combat.UltimateRange then
		AuraService.notify(player, { Kind = "Message", Text = "Get closer to the boss first!" })
		return
	end
	state.lastUltimate = now

	local target = boss.model:GetPivot().Position
	Effects.pillar(Vector3.new(target.X, root.Position.Y - 3, target.Z), Effects.color(boss.def.EyeColor):Lerp(Color3.new(1, 1, 1), 0.6))
	local damage = boss.maxHealth * Config.Combat.UltimateDamageFraction + Config.Combat.UltimateFlatDamage
	-- Damage first: a finishing ultimate is paid out at your full style rank.
	BossService.damage(player, damage, "Ultimate")
	AuraService.addStyle(player, -Config.Combat.UltimateStyleCost)
end

local HANDLERS = { Slash = slash, Dash = dash, Ultimate = ultimate }

function Combat.handle(player: Player, action: any)
	local handler = type(action) == "string" and HANDLERS[action]
	if not handler then
		return
	end
	local state = AuraService.get(player)
	local root = aliveRoot(player)
	if state and root then
		handler(player, root, state)
	end
end

return Combat
