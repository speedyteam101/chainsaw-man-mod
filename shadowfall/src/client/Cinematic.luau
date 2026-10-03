--!nonstrict
-- Story presentation: chapter title cards, letterboxed dialogue scenes, subtitle-style
-- narration, and the paper panel for journal pages.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Story = require(ReplicatedStorage.Shared.Story)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)
local ClientState = require(script.Parent.ClientState)

local Cinematic = {}

local T = Ui.Theme
local gui, topBar, bottomBar, chapterLabel, chapterTitle, box, speakerLabel, lineLabel, hintLabel
local pagePanel, pageTitle, pageBody
local queue = {}
local running = false
local advance = false

local function chapterInfo(id: number)
	for _, chapter in Story.Chapters do
		if chapter.id == id then
			return chapter
		end
	end
	return nil
end

local function showChapter(id: number)
	local chapter = chapterInfo(id)
	if not chapter then
		return
	end
	chapterLabel.Text = "CHAPTER " .. id
	chapterTitle.Text = string.upper(chapter.title)
	chapterLabel.TextTransparency = 1
	chapterTitle.TextTransparency = 1
	Ui.tween(chapterLabel, 0.8, { TextTransparency = 0.2 })
	Ui.tween(chapterTitle, 0.8, { TextTransparency = 0 })
	task.wait(2.6)
	Ui.tween(chapterLabel, 0.6, { TextTransparency = 1 })
	Ui.tween(chapterTitle, 0.6, { TextTransparency = 1 })
	task.wait(0.6)
end

local function playScene(scene)
	local blocking = scene.blocking == true
	if blocking then
		ClientState.InCutscene = true
		ClientState.DialogueOpen = true
		Ui.tween(topBar, 0.5, { Size = UDim2.new(1, 0, 0.11, 0) })
		Ui.tween(bottomBar, 0.5, { Size = UDim2.new(1, 0, 0.11, 0) })
		task.wait(0.5)
	end
	if scene.chapter then
		showChapter(scene.chapter)
	end
	box.Visible = true
	box.Position = blocking and UDim2.new(0.5, 0, 0.86, 0) or UDim2.new(0.5, 0, 0.78, 0)
	box.BackgroundTransparency = blocking and 1 or 0.35
	hintLabel.Visible = blocking
	for _, line in scene.lines do
		local speaker = line.speaker or ""
		speakerLabel.Text = speaker == "" and "" or string.upper(speaker)
		speakerLabel.TextColor3 = Story.Speakers[speaker] or T.Gold
		lineLabel.Font = speaker == "" and T.Title or T.Body
		lineLabel.TextColor3 = speaker == "" and Color3.fromRGB(215, 210, 200) or T.Text
		if speaker == "Biscuit" then
			Audio.Play("Quack", 0.7, 1.2)
		end
		advance = false
		task.spawn(Ui.typewrite, lineLabel, line.text, 0.022)
		local hold = math.clamp(#line.text * 0.045, 2.2, 6.5) + 0.5
		local started = os.clock()
		while os.clock() - started < hold and not (blocking and advance) do
			task.wait()
		end
	end
	box.Visible = false
	if blocking then
		Ui.tween(topBar, 0.5, { Size = UDim2.new(1, 0, 0, 0) })
		Ui.tween(bottomBar, 0.5, { Size = UDim2.new(1, 0, 0, 0) })
		task.wait(0.5)
		ClientState.InCutscene = false
		ClientState.DialogueOpen = false
	end
end

local function pump()
	if running then
		return
	end
	running = true
	while #queue > 0 do
		local scene = table.remove(queue, 1)
		local ok, err = pcall(playScene, scene)
		if not ok then
			warn("[Shadowfall] scene error", err)
			ClientState.InCutscene = false
			ClientState.DialogueOpen = false
		end
	end
	running = false
end

function Cinematic.ShowPage(page)
	pageTitle.Text = page.title
	pageBody.Text = page.text
	pagePanel.Visible = true
	ClientState.DialogueOpen = true
end

local function closePage()
	pagePanel.Visible = false
	ClientState.DialogueOpen = false
end

function Cinematic.Start()
	gui = Ui.screen("Cinematic", 25)
	topBar = Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui })
	bottomBar = Ui.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui })
	chapterLabel = Ui.label("", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(0.8, 0, 0, 28), Font = T.Bold, TextSize = 20, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, Parent = gui })
	chapterTitle = Ui.label("", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.new(0.9, 0, 0, 60), Font = T.Title, TextSize = 52, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, TextStrokeTransparency = 0.6, Parent = gui })

	box = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.new(0.75, 0, 0, 96),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(10), Ui.padding(10) })
	box.MouseButton1Click:Connect(function()
		advance = true
	end)
	speakerLabel = Ui.label("", { Size = UDim2.new(1, 0, 0, 20), Font = T.Bold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Parent = box })
	lineLabel = Ui.label("", { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 1, -40), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, TextStrokeTransparency = 0.5, Parent = box })
	hintLabel = Ui.label("click or press Space to continue", { Position = UDim2.new(0, 0, 1, -14), Size = UDim2.new(1, 0, 0, 14), TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = box })

	pagePanel = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 470, 0, 440),
		BackgroundColor3 = Color3.fromRGB(234, 226, 202),
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(3), Ui.padding(26), Ui.new("UISizeConstraint", { MaxSize = Vector2.new(470, 440) }) })
	pageTitle = Ui.label("", { Size = UDim2.new(1, 0, 0, 28), Font = T.Title, TextSize = 24, TextColor3 = Color3.fromRGB(60, 40, 30), Parent = pagePanel })
	pageBody = Ui.label("", { Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, 0, 1, -60), Font = T.Title, TextSize = 18, TextColor3 = Color3.fromRGB(45, 36, 30), TextYAlignment = Enum.TextYAlignment.Top, Parent = pagePanel })
	Ui.label("(click to put it in your journal)", { Position = UDim2.new(0, 0, 1, -16), Size = UDim2.new(1, 0, 0, 16), TextSize = 12, TextColor3 = Color3.fromRGB(110, 100, 90), TextXAlignment = Enum.TextXAlignment.Center, Parent = pagePanel })
	pagePanel.MouseButton1Click:Connect(closePage)

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			advance = true
		end
	end)

	Remotes.Notify.OnClientEvent:Connect(function(kind, data)
		if kind == "Scene" then
			table.insert(queue, data)
			task.spawn(pump)
		elseif kind == "JournalPage" then
			Cinematic.ShowPage(data)
		end
	end)
end

return Cinematic
