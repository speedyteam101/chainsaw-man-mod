--!nonstrict
-- Biscuit on the client: waddling, head bobs, wing flaps, trembling when scared, and speech
-- bubbles with advice that fits what's happening. Every duck is animated; only your own duck
-- talks to you.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)
local ClientState = require(script.Parent.ClientState)

local DuckClient = {}

local player = Players.LocalPlayer
local ducks = {} -- [Model] = { waddle, neck, wingL, wingR, phase }
local bubble: BillboardGui?
local bubbleToken = 0
local nextAdvice = os.clock() + 25
local lastSanityWarn, lastHealthWarn = 0, 0

local CUTE = {
	"*happy quack*",
	"Quack. (I love you.)",
	"(Biscuit preens a feather very proudly.)",
	"(Biscuit found a shiny pebble and gives it to you.)",
	"Quack quack! (We make a good team!)",
	"(Biscuit does a tiny victory waddle.)",
	"Quack? (Are we there yet?)",
	"(Biscuit tucks their head under a wing for exactly one second.)",
}

local function register(model: Model)
	local function motor(name)
		local m = model:FindFirstChild(name, true)
		return m and m:IsA("Motor6D") and { motor = m, base = m.C0 } or nil
	end
	ducks[model] = {
		waddle = motor("Waddle"),
		neck = motor("Neck"),
		jaw = motor("Jaw"),
		tail = motor("TailJoint"),
		wingL = motor("WingL"),
		wingR = motor("WingR"),
		phase = math.random() * 6,
		idle = nil, -- current idle behaviour
		idleStarted = 0,
		nextIdle = os.clock() + math.random(2, 5),
		quackUntil = 0,
	}
end

local function myDuck(): Model?
	for model in ducks do
		if model.Parent and model:GetAttribute("Owner") == player.UserId then
			return model
		end
	end
	return nil
end

function DuckClient.Say(text: string, duration: number?)
	local duck = myDuck()
	local head = duck and duck:FindFirstChild("Head")
	if not head then
		return
	end
	bubbleToken += 1
	local token = bubbleToken
	if bubble then
		bubble:Destroy()
	end
	bubble = Ui.new("BillboardGui", {
		Name = "DuckBubble",
		Size = UDim2.fromOffset(240, 70),
		StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0),
		MaxDistance = 80,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Adornee = head,
		Parent = head,
	})
	local frame = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(255, 250, 235),
		Parent = bubble,
	}, {
		Ui.corner(12),
		Ui.stroke(Color3.fromRGB(255, 190, 90), 2),
		Ui.padding(8),
		Ui.label(text, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Ui.Theme.Bold, TextSize = 14, TextColor3 = Color3.fromRGB(80, 60, 40), TextXAlignment = Enum.TextXAlignment.Center }),
	})
	frame.Size = UDim2.new(0.6, 0, 0, 0)
	Ui.tween(frame, 0.25, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Back)
	Audio.Play("Quack", 0.7, 1.1 + math.random() * 0.4, head.Position)
	if ducks[duck] then
		ducks[duck].quackUntil = os.clock() + 0.6
	end
	task.delay(duration or 6, function()
		if token == bubbleToken and bubble then
			bubble:Destroy()
			bubble = nil
		end
	end)
end

-- Picks a piece of advice that fits the moment.
local function advice(): string
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local sanity = player:GetAttribute("Sanity") or 100
	local act = player:GetAttribute("Act")
	if humanoid and humanoid.Health < humanoid.MaxHealth * 0.4 then
		return "Quack! (You're hurt. Stay close to me, I'll help you feel better!)"
	end
	if sanity < 40 then
		return "Quack quack... (It's okay. Breathe. I'm right here with you.)"
	end
	if act == 1 then
		local stage = player:GetAttribute("Act1Stage") or 0
		local tips = {
			[1] = "Quack! (The front door is that way. We can't stay here.)",
			[2] = "Quack? (The town square... maybe someone's there?)",
			[3] = "QUACK! (The blinking red light! Somebody's at the radio station!)",
			[4] = "Quack quack! (The clock tower! Ring the bell so they find us!)",
		}
		if math.random() < 0.6 and tips[stage] then
			return tips[stage]
		end
		return math.random() < 0.5 and "Quack. (They hate the light. Keep your flashlight ready.)" or "Quack... (Don't let your battery run all the way out.)"
	end
	local tips = {}
	if not player:GetAttribute("BasePlaced") then
		table.insert(tips, "Quack? (We should make a home. Open the Build menu with B and place a base crystal!)")
	else
		table.insert(tips, "Quack! (Blueprints need materials. Hit trees, rocks and old cars to gather them!)")
		table.insert(tips, "Quack quack! (Upgrade the crystal to make our barrier bigger!)")
		table.insert(tips, "Quack. (A bed in our base means you wake up at home.)")
	end
	local rescuedCount = 0
	for _ in pairs(ClientState.rescued) do
		rescuedCount += 1
	end
	if rescuedCount < 8 then
		table.insert(tips, "Quack...? (I heard someone calling for help. People are trapped in shadow cocoons out there.)")
	end
	if rescuedCount == 0 then
		table.insert(tips, "Quack! (A carpenter could teach us planks. A blacksmith could make iron!)")
	end
	if player:GetAttribute("CanAscend") then
		table.insert(tips, "QUACK! (You earned a feat! Press M and Ascend!)")
	end
	table.insert(tips, "Quack. (Watch their eyes. Red means they're about to strike.)")
	table.insert(tips, "Quack! (Craft tools in the Pack menu. A better axe chops faster!)")
	table.insert(tips, "Quack quack. (The deeper we go, the darker it gets. Bring a Sanity Tonic.)")
	if math.random() < 0.4 then
		return CUTE[math.random(1, #CUTE)]
	end
	return tips[math.random(1, #tips)]
end

function DuckClient.Start()
	for _, model in CollectionService:GetTagged("Duck") do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal("Duck"):Connect(function(model)
		task.defer(register, model)
	end)
	CollectionService:GetInstanceRemovedSignal("Duck"):Connect(function(model)
		ducks[model] = nil
	end)

	Remotes.Notify.OnClientEvent:Connect(function(kind, data)
		if kind == "DuckSay" then
			DuckClient.Say(data.text, 5)
		elseif kind == "Rescued" then
			task.delay(2, DuckClient.Say, "QUACK! (A new friend! They'll be waiting at our base.)", 5)
		end
	end)
	Remotes.Story.OnClientEvent:Connect(function(kind)
		if kind == "DuckSaved" then
			task.delay(1, DuckClient.Say, "QUACK! (Biscuit waddles over as fast as tiny legs allow and presses against your leg.)", 7)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		for model, duck in ducks do
			local root = model.PrimaryPart
			if not model.Parent or not root then
				ducks[model] = nil
				continue
			end
			local velocity = root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local scared = model:GetAttribute("Scared") == true
			local walking = speed > 1.5
			duck.phase += dt * (scared and 30 or (walking and math.clamp(speed, 4, 30) * 0.9 or 1.2))

			-- Pick a new idle behaviour now and then: peck, preen, look around, stretch, shake.
			if walking or scared then
				duck.idle = nil
			elseif now >= duck.nextIdle then
				local options = { "peck", "preen", "look", "stretch", "shake", "rest" }
				duck.idle = options[math.random(1, #options)]
				duck.idleStarted = now
				duck.nextIdle = now + math.random(3, 7)
			end
			local idle = duck.idle
			local t = now - duck.idleStarted

			-- Body: a waddle that rolls side to side with each step, a little hop, gentle breathing.
			local roll, hop, pitch = 0, 0, 0
			if scared then
				roll = math.sin(duck.phase) * 0.06
			elseif walking then
				roll = math.sin(duck.phase) * math.clamp(speed / 12, 0.3, 1) * 0.22
				hop = math.abs(math.sin(duck.phase)) * math.clamp(speed / 20, 0, 1) * 0.18
				pitch = -0.08
			else
				hop = math.sin(now * 2.2) * 0.02
				if idle == "shake" and t < 0.6 then
					roll = math.sin(t * 50) * 0.25
				elseif idle == "rest" and t < 3 then
					hop = -0.15
				end
			end
			if duck.waddle then
				duck.waddle.motor.C0 = duck.waddle.base * CFrame.new(0, hop, 0) * CFrame.Angles(pitch, 0, roll)
			end

			-- Head: bobs forward with each step; otherwise pecks, preens or looks around.
			local nod, turn, tilt, lift = 0, 0, 0, 0
			if scared then
				nod, lift = -0.3, -0.2
				turn = math.sin(now * 9) * 0.3
			elseif walking then
				nod = math.sin(duck.phase * 2) * 0.14
			elseif idle == "peck" and t < 1.4 then
				nod = math.max(0, math.sin(t * 9)) * -0.9
				lift = math.max(0, math.sin(t * 9)) * -0.25
			elseif idle == "preen" and t < 2 then
				turn = 2.2 * math.min(1, t * 3) * (t < 1.7 and 1 or 0)
				nod = -0.5 * math.min(1, t * 3)
				tilt = math.sin(t * 14) * 0.15
			elseif idle == "look" and t < 2.4 then
				turn = math.sin(t * 2.6) * 0.9
				tilt = math.sin(t * 2.6) * 0.25
			else
				nod = math.sin(now * 1.3) * 0.04
			end
			if duck.neck then
				duck.neck.motor.C0 = duck.neck.base * CFrame.new(0, lift, 0) * CFrame.Angles(nod, turn, tilt)
			end

			-- Bill opens when Biscuit quacks.
			if duck.jaw then
				local open = now < duck.quackUntil and math.abs(math.sin((duck.quackUntil - now) * 16)) * 0.45 or 0
				duck.jaw.motor.C0 = duck.jaw.base * CFrame.Angles(-open, 0, 0)
			end

			-- Tail wags when happy (idle) and flicks with each step.
			if duck.tail then
				local wag = (idle == "shake" and t < 0.8) and math.sin(t * 40) * 0.5 or (walking and math.sin(duck.phase) * 0.15 or math.sin(now * 3) * 0.06)
				duck.tail.motor.C0 = duck.tail.base * CFrame.Angles(0, wag, 0)
			end

			-- Wings: flap when scared or running hard; a big stretch now and then.
			local flap = (scared or speed > 18) and math.max(0, math.sin(now * 28)) * 0.9 or 0
			local stretchL, stretchR = 0, 0
			if idle == "stretch" and t < 1.5 then
				local amount = math.sin(math.min(t / 1.5, 1) * math.pi)
				stretchR = amount * 1.2
			end
			if duck.wingL then
				duck.wingL.motor.C0 = duck.wingL.base * CFrame.Angles(0, 0, -flap - stretchL - 0.04)
			end
			if duck.wingR then
				duck.wingR.motor.C0 = duck.wingR.base * CFrame.Angles(0, 0, flap + stretchR + 0.04)
			end
		end

		-- Advice from your own duck.
		local mine = myDuck()
		if not mine or mine:GetAttribute("Scared") or ClientState.InCutscene then
			return
		end
		local sanity = player:GetAttribute("Sanity") or 100
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if sanity < 30 and now - lastSanityWarn > 45 then
			lastSanityWarn = now
			DuckClient.Say("Quack quack! (Hey. Hey. Look at me. Stay close, it'll pass.)", 6)
			nextAdvice = now + 30
		elseif humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth * 0.3 and now - lastHealthWarn > 40 then
			lastHealthWarn = now
			DuckClient.Say("QUACK! (Get back! Stay near me, I'll keep you going!)", 6)
			nextAdvice = now + 30
		elseif now >= nextAdvice then
			nextAdvice = now + math.random(45, 80)
			DuckClient.Say(advice(), 7)
		end
	end)
end

return DuckClient
