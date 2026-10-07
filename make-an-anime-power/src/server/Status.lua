-- Status effects on any Humanoid (players, enemies, dummies):
-- walk speed (base speed, slows, stuns, power-up boosts), burns (damage over
-- time) and barriers (absorb damage).

local RunService = game:GetService("RunService")

local Status = {}

-- Set by CombatService so burns go through the normal damage rules.
-- Signature: (attackerModel, targetModel, amount, element)
Status.burnDamage = nil :: ((Model?, Model, number, string) -> ())?

local states = {}

local function newState(humanoid: Humanoid)
	return {
		humanoid = humanoid,
		baseSpeed = humanoid.WalkSpeed,
		baseJumpPower = humanoid.JumpPower,
		baseJumpHeight = humanoid.JumpHeight,
		slowMultiplier = 1,
		slowUntil = 0,
		stunUntil = 0,
		boostSpeed = 0,
		boostDamage = 1,
		boostUntil = 0,
		shield = 0,
		shieldUntil = 0,
		shieldPart = nil :: BasePart?,
		burns = {},
		wasStunned = false,
	}
end

function Status.get(humanoid: Humanoid)
	local state = states[humanoid]
	if not state then
		state = newState(humanoid)
		states[humanoid] = state
	end
	return state
end

function Status.setBaseSpeed(humanoid: Humanoid, speed: number)
	Status.get(humanoid).baseSpeed = speed
end

function Status.slow(humanoid: Humanoid, multiplier: number, duration: number)
	local state = Status.get(humanoid)
	local now = os.clock()
	-- Keep the strongest slow
	if state.slowUntil < now or multiplier < state.slowMultiplier then
		state.slowMultiplier = multiplier
	end
	state.slowUntil = math.max(state.slowUntil, now + duration)
end

function Status.stun(humanoid: Humanoid, duration: number)
	local state = Status.get(humanoid)
	state.stunUntil = math.max(state.stunUntil, os.clock() + duration)
end

function Status.isStunned(humanoid: Humanoid): boolean
	local state = states[humanoid]
	return state ~= nil and state.stunUntil > os.clock()
end

function Status.burn(humanoid: Humanoid, attacker: Model?, damagePerSecond: number, duration: number, element: string)
	local state = Status.get(humanoid)
	local now = os.clock()
	-- One burn per element: re-applying refreshes it instead of stacking
	state.burns[element] = {
		attacker = attacker,
		damagePerTick = damagePerSecond * 0.5,
		untilTime = now + duration,
		nextTick = now + 0.5,
	}
end

function Status.powerUp(humanoid: Humanoid, damageMultiplier: number, speedBonus: number, duration: number)
	local state = Status.get(humanoid)
	state.boostDamage = damageMultiplier
	state.boostSpeed = speedBonus
	state.boostUntil = os.clock() + duration
end

function Status.damageMultiplier(humanoid: Humanoid): number
	local state = states[humanoid]
	if state and state.boostUntil > os.clock() then
		return state.boostDamage
	end
	return 1
end

function Status.addShield(humanoid: Humanoid, absorb: number, duration: number, part: BasePart?)
	local state = Status.get(humanoid)
	if state.shieldPart then
		state.shieldPart:Destroy()
	end
	state.shield = absorb
	state.shieldUntil = os.clock() + duration
	state.shieldPart = part
end

local function removeShield(state)
	state.shield = 0
	state.shieldUntil = 0
	if state.shieldPart then
		state.shieldPart:Destroy()
		state.shieldPart = nil
	end
end

-- Takes damage out of the barrier first. Returns the damage left over.
function Status.absorb(humanoid: Humanoid, amount: number): number
	local state = states[humanoid]
	if not state or state.shield <= 0 or state.shieldUntil < os.clock() then
		return amount
	end
	local blocked = math.min(state.shield, amount)
	state.shield -= blocked
	if state.shield <= 0 then
		removeShield(state)
	end
	return amount - blocked
end

-- Clears everything (used when a character respawns or changes power).
function Status.reset(humanoid: Humanoid)
	local state = states[humanoid]
	if state then
		removeShield(state)
		states[humanoid] = nil
	end
end

local function update()
	local now = os.clock()
	local ticks = {} -- burn damage is applied after the loop, so damage code can't change `states` mid-loop
	for humanoid, state in states do
		if humanoid.Parent == nil or humanoid.Health <= 0 then
			removeShield(state)
			states[humanoid] = nil
			continue
		end

		-- Movement
		local stunned = state.stunUntil > now
		local speed = state.baseSpeed
		if state.boostUntil > now then
			speed += state.boostSpeed
		end
		if state.slowUntil > now then
			speed *= state.slowMultiplier
		end
		if stunned then
			speed = 0
		end
		if math.abs(humanoid.WalkSpeed - speed) > 0.01 then
			humanoid.WalkSpeed = speed
		end
		if stunned ~= state.wasStunned then
			state.wasStunned = stunned
			humanoid.JumpPower = stunned and 0 or state.baseJumpPower
			humanoid.JumpHeight = stunned and 0 or state.baseJumpHeight
		end

		-- Barrier timeout
		if state.shieldPart and state.shieldUntil < now then
			removeShield(state)
		end

		-- Burns
		for element, burn in state.burns do
			if burn.untilTime < now then
				state.burns[element] = nil
			elseif burn.nextTick <= now then
				burn.nextTick += 0.5
				local model = humanoid.Parent
				if model and model:IsA("Model") then
					table.insert(ticks, { burn.attacker, model, burn.damagePerTick, element })
				end
			end
		end
	end

	if Status.burnDamage then
		for _, entry in ticks do
			Status.burnDamage(entry[1], entry[2], entry[3], entry[4])
		end
	end
end

RunService.Heartbeat:Connect(update)

return Status
