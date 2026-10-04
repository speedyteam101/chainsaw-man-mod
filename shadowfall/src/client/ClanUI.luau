--!nonstrict
-- Shared bits of the clan interface: the spinning name reel when you roll, and clan cards.
-- Used by the character creator (first rolls) and the menu's Clan tab (rerolls).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clans = require(ReplicatedStorage.Shared.Clans)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)

local ClanUI = {}

local T = Ui.Theme
local rng = Random.new()

-- Spins random clan names in `label`, slowing down, and lands on `finalId`.
function ClanUI.Reel(label: TextLabel, finalId: string)
	local delay = 0.03
	for _ = 1, 22 do
		local clan = Clans.List[rng:NextInteger(1, #Clans.List)]
		label.Text = string.upper(clan.name)
		label.TextColor3 = Clans.RarityColors[clan.rarity]
		Audio.Play("RollTick", 0.25, 1.2)
		task.wait(delay)
		delay *= 1.12
	end
	local final = Clans.ById[finalId]
	label.Text = string.upper(final.name) .. "  -  " .. string.upper(final.rarity)
	label.TextColor3 = Clans.RarityColors[final.rarity]
	label.TextSize = (label.TextSize or 20) + 8
	Ui.tween(label, 0.4, { TextSize = label.TextSize - 8 }, Enum.EasingStyle.Back)
	Audio.Play("RollReveal", Clans.RarityRank[final.rarity] >= Clans.RarityRank.Legendary and 1 or 0.6)
end

-- A clickable card for a clan. `selected` draws it highlighted.
function ClanUI.Card(clanId: string, selected: boolean, order: number, parent: Instance, onClick: () -> ())
	local clan = Clans.ById[clanId]
	local color = Clans.RarityColors[clan.rarity]
	local card = Ui.new("TextButton", {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = selected and color:Lerp(Color3.new(0, 0, 0), 0.7) or T.PanelLight,
		LayoutOrder = order,
		Parent = parent,
	}, {
		Ui.corner(8),
		Ui.stroke(color, selected and 2 or 1, selected and 0 or 0.5),
		Ui.label(clan.name, { Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(1, -16, 0, 18), Font = T.Bold, TextSize = 15, TextColor3 = color }),
		Ui.label(clan.rarity .. (clan.mode and "  +  MODE" or ""), { Position = UDim2.new(0, 8, 0, 22), Size = UDim2.new(1, -16, 0, 14), TextSize = 11, TextColor3 = T.Muted }),
	})
	card.MouseButton1Click:Connect(onClick)
	return card
end

-- Perk lines for a clan as one string.
function ClanUI.Perks(clanId: string?): string
	local clan = Clans.ById[clanId or ""]
	if not clan then
		return "Roll to discover your family line."
	end
	local lines = Clans.Describe(clanId)
	return clan.lore .. "\n- " .. table.concat(lines, "\n- ")
end

return ClanUI
