--!nonstrict
-- Townsfolk trapped in shadow cocoons around the world. Free them and they join your base.
-- Roles: Carpenter unlocks planks and carpentry buildings; Blacksmith unlocks the forge, iron
-- and metal buildings. Every builder also makes deposited materials count for more.
-- Survivors without a trade keep spirits up: each one adds sanity regeneration in your base.

local Townsfolk = {}

Townsfolk.List = {
	{
		id = "hank", name = "Hank Morrow", roles = { "Carpenter" }, area = "town", at = Vector3.new(-100, 0, -52),
		shirt = Color3.fromRGB(120, 70, 40), pants = Color3.fromRGB(50, 50, 60),
		lines = { "I built half the porches on this street. Guess I'll build the walls now.", "Bring me wood and I'll show you how to saw proper planks." },
		guards = { "Shade", "Shade", "Lurker" },
	},
	{
		id = "rosa", name = "Rosa Delgado", roles = { "Blacksmith" }, area = "town", at = Vector3.new(100, 0, 62),
		shirt = Color3.fromRGB(60, 60, 70), pants = Color3.fromRGB(40, 32, 30),
		lines = { "Get me a forge and enough scrap and I'll give you iron.", "Shadows don't like the forge's glow. Neither do I, some days." },
		guards = { "Shade", "Lurker", "Lurker" },
	},
	{
		id = "june", name = "Grandma June", roles = {}, area = "town", at = Vector3.new(-52, 0, 100),
		shirt = Color3.fromRGB(170, 120, 170), pants = Color3.fromRGB(80, 70, 90),
		lines = { "Oh, a duck! Hello, little one.", "Sit down a moment, dear. You look like you haven't slept in a week." },
		guards = { "Shade", "Shade" },
	},
	{
		id = "marcus", name = "Marcus Hale", roles = {}, area = "town", at = Vector3.new(150, 0, -100),
		shirt = Color3.fromRGB(50, 90, 60), pants = Color3.fromRGB(40, 40, 46),
		lines = { "My mother went out to check the noise. She never... I'm glad you found me.", "I'll keep watch. I'm good at not sleeping now." },
		guards = { "Shade", "Shade", "Shade" },
	},
	{
		id = "tomas", name = "Tomas Reyes", roles = { "Carpenter" }, area = "woods", at = Vector3.new(440, 0, 6),
		shirt = Color3.fromRGB(160, 120, 60), pants = Color3.fromRGB(60, 50, 40),
		lines = { "The trees out here grew back wrong. The wood's still good, though.", "Two carpenters build faster than one." },
		guards = { "Shade", "Howler", "Lurker" },
	},
	{
		id = "eli", name = "Eli Fischer", roles = { "Carpenter", "Blacksmith" }, area = "woods", at = Vector3.new(595, 0, 8),
		shirt = Color3.fromRGB(90, 60, 90), pants = Color3.fromRGB(30, 30, 40),
		lines = { "Wood or metal, I can work either. Point me at a job.", "I was fixing the mill when the sky went out." },
		guards = { "Howler", "Howler", "Lurker", "Shade" },
	},
	{
		id = "ivy", name = "Ivy Chen", roles = { "Blacksmith" }, area = "rift", at = Vector3.new(865, 0, 52),
		shirt = Color3.fromRGB(70, 110, 150), pants = Color3.fromRGB(40, 40, 50),
		lines = { "These crystals ring when you strike them. You can forge light out of them.", "I've been floating out here for... I don't know how long." },
		guards = { "Brute", "Howler", "Lurker" },
	},
	{
		id = "gus", name = "Old Gus", roles = { "Carpenter", "Blacksmith" }, area = "cathedral", at = Vector3.new(1250, 0, -42),
		shirt = Color3.fromRGB(110, 100, 80), pants = Color3.fromRGB(50, 44, 40),
		lines = { "Forty years building that cathedral's pews. Now it's underwater.", "I can make anything. Just give me something to make it from." },
		guards = { "Wraith", "Wraith", "Brute" },
	},
}

Townsfolk.ById = {}
for index, person in Townsfolk.List do
	person.order = index
	Townsfolk.ById[person.id] = person
end

-- Which roles a player has unlocked, from their set of rescued ids.
function Townsfolk.Roles(rescued)
	local roles = { Carpenter = 0, Blacksmith = 0, Survivor = 0 }
	for _, person in Townsfolk.List do
		if rescued[person.id] then
			if #person.roles == 0 then
				roles.Survivor += 1
			end
			for _, role in person.roles do
				roles[role] += 1
			end
		end
	end
	return roles
end

function Townsfolk.Count(rescued): number
	local count = 0
	for _, person in Townsfolk.List do
		if rescued[person.id] then
			count += 1
		end
	end
	return count
end

return Townsfolk
