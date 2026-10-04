--!nonstrict
local Areas = require(script.Parent.Areas)
-- The story of Shadowfall: chapters, scenes and journal pages.
--
-- Scenes play as cinematic dialogue when something happens (arriving at camp, ascending, a boss
-- falling, entering an area for the first time, freeing someone). `blocking` scenes get the
-- letterboxed cinematic treatment; the rest play as subtitles so they don't interrupt a fight.
--
-- The mystery: three days before the town fell, Dr. Elias Vance carried a machine called the
-- Lantern into the Whispering Woods. It opened a window onto the shadow world, and something on
-- the other side came through. Everyone the shadows touch becomes one of them.

local Story = {}

Story.Chapters = {
	{ id = 1, title = "The Night Hollow Creek Fell" },
	{ id = 2, title = "Embers" },
	{ id = 3, title = "Into the Woods" },
	{ id = 4, title = "Falling Pieces" },
	{ id = 5, title = "The Drowned Choir" },
	{ id = 6, title = "The Heart of It" },
	{ id = 7, title = "Dawn" },
}

-- Speaker colours for the dialogue box.
Story.Speakers = {
	Mara = Color3.fromRGB(255, 190, 120),
	Tobias = Color3.fromRGB(220, 200, 160),
	Dex = Color3.fromRGB(140, 180, 255),
	Agnes = Color3.fromRGB(230, 220, 255),
	Jun = Color3.fromRGB(255, 150, 140),
	Biscuit = Color3.fromRGB(255, 230, 140),
	["Dr. Vance (recording)"] = Color3.fromRGB(140, 255, 170),
	["Dr. Vance"] = Color3.fromRGB(140, 255, 170),
	["The Umbral King"] = Color3.fromRGB(255, 70, 90),
	["The Choir"] = Color3.fromRGB(120, 180, 255),
	["Mum"] = Color3.fromRGB(255, 200, 220),
	["Dad"] = Color3.fromRGB(200, 220, 255),
	[""] = Color3.fromRGB(200, 200, 200),
}

local function lines(...)
	local result = {}
	for _, pair in { ... } do
		table.insert(result, { speaker = pair[1], text = pair[2] })
	end
	return result
end

Story.Beats = {
	camp_arrival = {
		chapter = 2,
		blocking = true,
		lines = lines(
			{ "Mara", "Easy. Easy. You rang the bell. We heard it all the way from the garage." },
			{ "Mara", "And you're... glowing. I've never seen anyone push the dark back like that." },
			{ "Tobias", "So it's true. Some of us come out of it changed." },
			{ "Mara", "Listen. The people the shadows touch don't die. They become shadows. Mrs. Hale. The postman. Your..." },
			{ "Mara", "...I'm sorry. I'm so sorry." },
			{ "Biscuit", "Quack... (Biscuit presses against your leg.)" },
			{ "Tobias", "Three days before noon, Dr. Elias Vance walked into the Whispering Woods carrying a machine he called the Lantern. Nobody saw him come back." },
			{ "Mara", "If anyone knows how this happened, it's him. Get stronger. Find out what he did. We'll keep the fire lit." }
		),
	},
	first_blackout = {
		lines = lines(
			{ "Mara", "Hear that bell? Get inside the firelight, or get your torch out. NOW." },
			{ "Tobias", "When the lights die, the Hollow walks. You can't fight it. Keep your light on it and it can't move." }
		),
	},
	first_rescue = {
		lines = lines(
			{ "Mara", "You brought someone back alive. Every person we save is one more light the dark can't have." }
		),
	},
	boss_Warden = {
		blocking = true,
		lines = lines(
			{ "", "As the Warden comes apart, something falls out of the smoke: a tarnished sheriff's badge." },
			{ "Dex", "That's Sheriff Cole's. He went out looking for Vance on the first night." },
			{ "Agnes", "Look. Light. Something left him when he fell, and it went up, not down." },
			{ "Mara", "So they can be freed. Every one of them we put down goes somewhere better than this." }
		),
	},
	ascend_2 = {
		chapter = 3,
		blocking = true,
		lines = lines(
			{ "Tobias", "The east gate will open for you now. The Woods are where Vance went." },
			{ "Tobias", "Mind yourself out there. The trees grew back wrong." }
		),
	},
	area_woods = {
		lines = lines(
			{ "", "The trees here grew back out of the dark. Their bark is warm to the touch." },
			{ "", "Somewhere ahead, a radio crackles." }
		),
	},
	boss_Stag = {
		blocking = true,
		lines = lines(
			{ "", "The Antlered Shade collapses beside a ruined camp: a tent, a generator, and a cracked brass device covered in dials." },
			{ "Dr. Vance (recording)", "Log forty-one. The Lantern works. It opens a window onto the other side, a world made entirely of shadow." },
			{ "Dr. Vance (recording)", "There's something over there. It has been watching the window. It is very... patient." },
			{ "Mara", "He opened a door. And something came through it." }
		),
	},
	ascend_3 = {
		chapter = 4,
		blocking = true,
		lines = lines(
			{ "Tobias", "The Rift. Pieces of other towns, falling forever." },
			{ "Tobias", "Hollow Creek isn't the first place this has happened. Just the first place somebody fought back." }
		),
	},
	area_rift = {
		lines = lines(
			{ "", "Street signs from towns you've never heard of drift past. Somebody else's mailbox. Somebody else's swing set." }
		),
	},
	boss_Eyes = {
		blocking = true,
		lines = lines(
			{ "", "As the Many-Eyed dies, every one of its eyes turns the same way: deeper, toward a cathedral that shouldn't be here." },
			{ "Dr. Vance (recording)", "Log fifty-eight. I understand now what it wants. Not our town. Our light. Every soul is a candle to it." }
		),
	},
	ascend_4 = {
		chapter = 5,
		blocking = true,
		lines = lines(
			{ "Agnes", "The cathedral. The bells I've been hearing every night." },
			{ "Agnes", "Whoever is down there singing... give them peace, if you can." }
		),
	},
	area_cathedral = {
		lines = lines(
			{ "", "Knee-deep black water. Pews stacked like driftwood. And under it all, singing." }
		),
	},
	boss_Choir = {
		blocking = true,
		lines = lines(
			{ "", "As the Choir falls silent, the last note hangs in the air. It's a name." },
			{ "The Choir", "...E...li...as..." },
			{ "Mara", "Vance. They were singing Vance's name." }
		),
	},
	ascend_5 = {
		chapter = 6,
		blocking = true,
		lines = lines(
			{ "Mara", "You're the strongest of us now. Whatever is in the Heart, it's the reason for all of this." },
			{ "Biscuit", "Quack. (I'm coming with you.)" }
		),
	},
	area_heart = {
		lines = lines(
			{ "", "The ground is warm and black, and it beats. Above you hangs a heart the size of a house." },
			{ "Mum", "...we're so proud of you..." },
			{ "Dad", "...keep going, kiddo..." }
		),
	},
	boss_King = {
		chapter = 7,
		blocking = true,
		lines = lines(
			{ "The Umbral King", "I only... wanted... to bring light... to the dark..." },
			{ "", "The crown cracks. Under the shadow is a tired man in a lab coat: Dr. Elias Vance." },
			{ "Dr. Vance", "The Lantern is inside me. It's what's keeping the window open. Please..." },
			{ "", "Light pours out of him, out of all of them, and rises." },
			{ "Mum", "Look after Biscuit for us." },
			{ "Dad", "We love you. We always will." },
			{ "Biscuit", "QUACK!" },
			{ "Mara", "...the sky... it's getting lighter. It's getting LIGHTER!" },
			{ "", "For the first time since noon, the sun rises over Hollow Creek." },
			{ "", "The shadows are still out there. But so are you." }
		),
	},
}

-- Journal pages hidden around the world. Find them all to piece the story together.
Story.Pages = {
	{ id = "p1", area = "town", at = Vector3.new(14, 0, -110), title = "Missing Person Notice", text = "MISSING: Dr. Elias Vance, 52.\n\nLast seen walking east toward the Whispering Woods, carrying a large brass case.\n\nIf you have any information, contact Sheriff Cole.\n\n(Someone has scrawled underneath: HE WAS TALKING TO SOMETHING.)" },
	{ id = "p2", area = "town", at = Vector3.new(100, 0, -40), title = "Radio Station Memo", text = "To all staff:\n\nDo NOT touch the device in Studio B. Dr. Vance says it is 'calibrating'.\n\nIt was humming all night. The lights in the building dimmed every time it did.\n\n- Management" },
	{ id = "p3", area = "town", at = Vector3.new(-100, 0, 40), title = "A Child's Drawing", text = "A crayon drawing: a little house, a black sky, and a white duck standing in front of a family.\n\nUnderneath, in careful letters:\n\nTHE LITTLE DUCK KEEPS THE BAD THINGS AWAY" },
	{ id = "p4", area = "woods", at = Vector3.new(520, 0, 8), title = "Vance: Log 12", text = "The Lantern focuses light the way a lens does, but backwards. Point it at a shadow and it shows you what the shadow is cast FROM.\n\nTonight I pointed it at the dark between the trees.\n\nSomething pointed back." },
	{ id = "p5", area = "woods", at = Vector3.new(610, 0, -6), title = "Vance: Log 29", text = "I can hear it now even when the Lantern is off. It is very old and very lonely, and it is so, so hungry.\n\nIt says it has been in the dark forever and only wants to see the light.\n\nI want to help it. Is that so wrong?" },
	{ id = "p6", area = "rift", at = Vector3.new(855, 0, -40), title = "A Postcard", text = "Greetings from Millbrook!\n\nThe postmark is from a town that doesn't exist on any map. On the back:\n\n'The sky went out at noon here too. If anyone finds this, we tried.'" },
	{ id = "p7", area = "rift", at = Vector3.new(918, 0, 86), title = "Vance: Log 44", text = "Other towns. Dozens. The thing has done this before, through other people like me. Other windows.\n\nIt takes a town, drinks its light, and lets the pieces fall.\n\nI have to close it. I have to get the Lantern back." },
	{ id = "p8", area = "cathedral", at = Vector3.new(1290, 0, 30), title = "Hymn Sheet", text = "A soaked hymn sheet. The words have been crossed out and rewritten again and again in the same shaking hand:\n\nELIAS ELIAS ELIAS COME HOME" },
	{ id = "p9", area = "cathedral", at = Vector3.new(1440, 0, 0), title = "Vance: Log 60", text = "I am inside the Heart. It wants a body to wear, and a light to hold the window open.\n\nI am both.\n\nIf someone finds this: I'm sorry. The Lantern is inside me now. Break the crown and you break the window." },
	{ id = "p10", area = "heart", at = Vector3.new(1700, 0, 30), title = "A Note in Mum's Handwriting", text = "If you ever read this, sweetheart: we are not afraid.\n\nWhatever happens, you were the best thing we ever did. Look after Biscuit. Look after each other.\n\nAll our love, always.\nMum & Dad" },
}

Story.PagesById = {}
for _, page in Story.Pages do
	Story.PagesById[page.id] = page
end

-- Positions above were written for the original layout; move each with its area (Areas.shift).
for _, entry in Story.Pages do
	local area = Areas.ById[entry.area]
	if area and area.shift ~= 0 then
		entry.at += Vector3.new(area.shift, 0, 0)
	end
end

return Story
