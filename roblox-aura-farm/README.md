# Aura Farm (Roblox)

A Roblox game where you earn **aura** by being heroic (or villainous): saying the right lines at the right moment and fighting bosses
and each other in a cool way. Pick a side, **Heroes** or **Villains**, and one of **44 classes** (22 per side), then farm aura in
Good-vs-Evil PvP or against the bosses.
The map, bosses, effects and UI are all made in code, so no uploaded assets are needed.

## Play it

**Easiest:** download [`AuraFarm.rbxlx`](AuraFarm.rbxlx), open it in Roblox Studio and press **Play**.

**With [Rojo](https://rojo.space)** (best if you want to edit the code):

```sh
cd roblox-aura-farm
rojo build default.project.json -o AuraFarm.rbxlx   # rebuild the place file
# or live-sync into an open Studio place:
rojo serve
```

If you edit anything in `src/`, rebuild `AuraFarm.rbxlx` with the command above. The committed copy is only updated when someone rebuilds it.

**Saving aura:** aura is saved with DataStoreService. In Studio this only works after you publish the place and turn on
*Game Settings → Security → Enable Studio Access to API Services*. Without that, the game still runs but prints a warning and doesn't save.
Your class is saved too, so returning players go straight back to their side.

## Sides and classes

When you join you start in the lobby and the class picker opens. Pick **Heroes** or **Villains**, then a class.
Each class has its own health, move speed, slash damage, reach and attack speed, dash cooldown, sometimes a passive
(armor, lifesteal, faster style), and a named ultimate. Change class any time with the **CLASS** button
(not within 8 seconds of being hit by a player). Changing class respawns you at your side's base.

Every ultimate uses one of six types, and the class's power scales its damage or healing:

| Type | What it does |
| --- | --- |
| **Pillar** | Huge hit on one target (the boss, or the nearest enemy player) |
| **Nova** | Blast everything around you |
| **Rush** | Dash through everything in a line, invincible while you go |
| **Drain** | Damage everything around you and heal from it |
| **Mend** | Heal yourself and nearby allies (aura for each ally healed) |
| **Fortify** | Make you and nearby allies invincible for a few seconds (aura for each ally) |

### Heroes (22)

| Class | Role | HP | Speed | Damage | Reach | Extras | Ultimate |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Paladin** | Tank | 160 | 14 | 20 | 9 | 10% armor | Sacred Bulwark (Fortify) |
| **Guardian** | Tank | 180 | 13 | 16 | 9 | 20% armor | Unbreakable Wall (Fortify) |
| **Swordmaster** | Duelist | 100 | 17 | 26 | 9 |  | Heaven Splitter (Pillar) |
| **Lightning Knight** | Speedster | 90 | 22 | 20 | 9 | dash every 0.7s | Thunderclap Rush (Rush) |
| **Sky Lancer** | Duelist | 105 | 17 | 22 | 13 |  | Falling Star Lance (Rush) |
| **Cleric** | Support | 110 | 16 | 15 | 9 |  | Grand Blessing (Mend) |
| **Sun Monk** | Fighter | 110 | 18 | 15 | 7 | attacks every 0.22s | Solar Flare Palm (Nova) |
| **Storm Caller** | Mage | 85 | 16 | 18 | 11 |  | Tempest Crown (Nova) |
| **Star Archer** | Ranged | 85 | 17 | 18 | 15 |  | Starfall Arrow (Pillar) |
| **Iron Fist** | Bruiser | 140 | 15 | 28 | 8 | attacks every 0.50s | Earthshaker (Nova) |
| **Shield Bearer** | Tank | 150 | 14 | 17 | 9 | 30% armor | Phalanx (Fortify) |
| **Dawn Blade** | Duelist | 110 | 17 | 24 | 9 | 10% lifesteal | First Light (Pillar) |
| **Wind Dancer** | Speedster | 90 | 23 | 17 | 9 | dash every 0.9s, +30% style | Gale Waltz (Rush) |
| **Frost Warden** | Bruiser | 130 | 15 | 20 | 9 | 10% armor | Absolute Zero (Nova) |
| **Grove Healer** | Support | 105 | 16 | 14 | 9 |  | Bloom of Life (Mend) |
| **Lionheart** | Bruiser | 135 | 17 | 23 | 9 |  | Pride Charge (Rush) |
| **Spirit Sage** | Support | 100 | 16 | 16 | 11 |  | Ancestral Ward (Fortify) |
| **Crusader** | Fighter | 125 | 16 | 22 | 9 |  | Righteous Verdict (Pillar) |
| **Phoenix Knight** | Fighter | 115 | 17 | 20 | 9 | 15% lifesteal | Rebirth Flame (Nova) |
| **Valkyrie** | Duelist | 115 | 19 | 22 | 11 |  | Winged Descent (Rush) |
| **Comet Striker** | Speedster | 95 | 20 | 23 | 9 | dash every 1.0s | Comet Trail (Rush) |
| **Hero of Legend** | All-rounder | 120 | 17 | 21 | 9 | +25% style | Legendary Strike (Pillar) |

### Villains (22)

| Class | Role | HP | Speed | Damage | Reach | Extras | Ultimate |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Warlord** | Bruiser | 145 | 15 | 25 | 9 |  | Warpath (Nova) |
| **Shadow Assassin** | Assassin | 80 | 22 | 29 | 9 | dash every 0.8s | Thousand Shadows (Rush) |
| **Necromancer** | Mage | 95 | 16 | 18 | 11 |  | Grave Harvest (Drain) |
| **Blood Knight** | Fighter | 120 | 16 | 21 | 9 | 15% lifesteal | Crimson Feast (Drain) |
| **Dread Juggernaut** | Tank | 190 | 12 | 20 | 9 | 20% armor | Cataclysm Stomp (Nova) |
| **Hex Witch** | Mage | 90 | 16 | 18 | 12 |  | Withering Hex (Drain) |
| **Void Reaper** | Duelist | 105 | 16 | 26 | 12 | attacks every 0.42s | Void Sentence (Pillar) |
| **Plague Doctor** | Support | 105 | 16 | 16 | 9 |  | Dark Remedy (Mend) |
| **Inferno Tyrant** | Mage | 90 | 15 | 19 | 10 |  | Hellfire Eruption (Nova) |
| **Bone Colossus** | Tank | 170 | 13 | 17 | 9 | 20% armor | Ossuary Shell (Fortify) |
| **Venom Stalker** | Speedster | 90 | 22 | 19 | 9 | dash every 0.8s | Fang Lunge (Rush) |
| **Doom Knight** | Fighter | 125 | 16 | 22 | 9 |  | Doomfall (Pillar) |
| **Storm Despot** | Mage | 95 | 16 | 18 | 11 |  | Black Thunder (Nova) |
| **Night Hunter** | Ranged | 85 | 17 | 18 | 15 |  | Moonless Shot (Pillar) |
| **Chaos Brawler** | Fighter | 115 | 18 | 16 | 7 | attacks every 0.24s | Pandemonium (Nova) |
| **Iron Tyrant** | Tank | 150 | 14 | 18 | 9 | 30% armor | Iron Dominion (Fortify) |
| **Soul Eater** | Fighter | 110 | 17 | 18 | 9 | 20% lifesteal | Soul Devour (Drain) |
| **Cursed Samurai** | Duelist | 100 | 17 | 27 | 9 |  | Cursed Iaido (Pillar) |
| **Abyss Walker** | Speedster | 95 | 20 | 22 | 9 | dash every 0.9s | Abyssal Step (Rush) |
| **Dark Priest** | Support | 100 | 16 | 16 | 11 |  | Unholy Covenant (Fortify) |
| **Fallen Hero** | All-rounder | 120 | 17 | 21 | 9 | +25% style | Betrayal (Pillar) |
| **Demon Lord** | Bruiser | 150 | 14 | 25 | 9 | 10% armor | Demon King's Wrath (Nova) |

## PvP

PvP is **Good vs Evil only**: heroes can only hurt villains and villains can only hurt heroes. Players who haven't picked a side
can't be hurt by players. Each side's base (and the lobby) has a glowing **safe zone** where nobody can be hurt by players.
Your slash hits enemies in front of you, and your ultimate hits enemy players as well as the boss.

| Source | Aura |
| --- | --- |
| **Defeating an enemy player** (you hit them within the last 10 s) | 40 base × style multiplier |
| GIANT SLAYER: they're a higher aura rank than you | +50% per rank (max +150%) |
| REVENGE: they were the last player to defeat you | +50% |
| CLUTCH / CALLED IT / FINISHER (same as bosses) | +75% / +50% / +50% |
| Defeating the **same** player again within 2 minutes | halved each time (no farming) |
| Being defeated by a player | **−10** |
| Didn't look back after a takedown | +50 |

Hitting a player also counts toward your style meter, and a dash that makes a player's attack miss is a perfect dodge.

## How to farm aura

| Source | Aura |
| --- | --- |
| **Heroic line** said in chat or the SHOUT box (villains: villain line) | 10–30 base |
| ...in a fight (boss fight, or an enemy player within 40 studs) | x2 |
| ...at the right moment (each line has one, see below) | x2 to x4 more |
| Freestyle (your own words with 2+ heroic keywords like *protect*, *never*, *believe*) | up to 16 |
| Repeating the same line within 30 s ("cringe") | **−15** |
| Hitting a boss | 1 per hit × style multiplier |
| **Perfect dodge**: dash out of (or through) an attack at the last moment | 15 × style multiplier |
| **Defeating a boss** | 120 / 350 / 900 base (assists get 60%) |
| **Didn't look back**: walk away from the explosion without facing it | +50 |
| Dying in a boss fight ("took the L") | **−20** |

Boss rewards get bonuses that add together, then everything is multiplied by your **style rank** when the boss dies:

| Bonus | When | Who |
| --- | --- | --- |
| FLAWLESS | You took no damage during the fight | everyone |
| CLUTCH | You landed the killing blow under 25% HP | killer |
| CALLED IT | You said a heroic line within 6 s before the kill | killer |
| FINISHER | The killing blow was your ultimate | killer |

### Lines and their moments

Heroes (and players who haven't picked a side) use heroic lines; villains use villain lines and can't use the heroic ones.
Click **LINES** next to the shout box to see your side's lines in game. Lines match even with small typos or a missing word.
"Enemy" means the boss you're fighting or an enemy player near you.

| Moment | Heroic lines (bonus) | Villain lines (bonus) |
| --- | --- | --- |
| Enemy under 25% HP | *This ends now.* (x4), *Remember my name.* (x3), *Watch closely. This is how it's done.* (x2) | *Kneel.* (x4), *Your hope ends here.* (x3), *Nobody is coming to save you.* (x2), *Your light is fading.* (x2) |
| You under 30% HP | *I won't lose. Not here. Not now.* (x3), *One more round.* (x3), *Even if I fall, I'll get back up.* (x2), *I didn't come this far to quit.* (x2) | *Even broken, I am stronger than you.* (x3), *I don't lose.* (x3) |
| Right after a perfect dodge | *Too slow.* (x4), *It's my turn now.* (x3), *I'm not even trying yet.* (x2) | *Pathetic.* (x4), *Is this the best your heroes can do?* (x3) |
| Right after taking a hit | *Is that all you've got?* (x3), *That barely scratched me.* (x3) | *I let you hit me.* (x3), *Pain only makes me stronger.* (x2) |
| Right after defeating a player | *Stay down.* (x4), *Justice is served.* (x3) | *Who's next?* (x4), *Another one falls.* (x3) |
| Before a fight | *Stand back. I'll handle this.*, *Get behind me.*, *The hero always shows up.* (x2 each) | *Run while you still can.*, *You can't stop what's coming.* (x2 each) |
| Any time | *You picked the wrong hero to fight.*, *My friends are my power!*, *I never back down.*, *Today, I go beyond my limits!*, *You hurt the people I care about. That was your mistake.*, *I fight for everyone who can't.*, *Nothing can stop me.* | *You were never a threat to me.*, *This world will bow to me.*, *I was the hero once.*, *Darkness always wins.*, *Mercy is for the weak.*, *I've already won. You just don't know it yet.*, *Fear me.*, *Bow before your new ruler.* |

### Controls

| Action | PC | Gamepad | Touch |
| --- | --- | --- | --- |
| Slash (hold to keep slashing) | Left click | R2 | SLASH button |
| Dash (brief invincibility) | Q | B | DASH button |
| Ultimate (needs **S** style; spends most of it) | F | Y | ULT button |
| Challenge a boss | Hold E at an altar | | Tap the prompt |
| Change class | CLASS button | | CLASS button |

### Style meter

Hits, perfect dodges and heroic lines during a fight fill your style meter (**D → C → B → A → S → SSS**, x1 to x3).
Getting hit drains it, and it slowly fades if you stop doing cool things.

### Ranks

Heroes: NPC → Background Character (100) → Side Character (500) → Rival (1,500) → Main Character (4,000) → Protagonist (10,000) → Legend (25,000) → Aura God (60,000).

Villains: Minion → Henchman → Enforcer → Nemesis → Main Villain → Overlord → Calamity → Demon King (same aura amounts).
Your rank shows over your head and in the player list, and your aura particles get brighter as you rank up.

## Bosses

Summon one at a time from the three altars in the arena. Every attack is telegraphed with a red zone that fills up before it hits.

| Boss | HP | Attacks | Notes |
| --- | --- | --- | --- |
| **Grand Brute** | 700 | Slam, Charge | |
| **Storm Tyrant** | 1,800 | Slam, Charge, Barrage | Barrage drops a zone under every fighter |
| **The Final Rival** | 3,600 | Slam, Charge, Barrage | Enrages under 50% HP: faster attacks and movement |

A boss leaves if nobody is in the arena for 12 seconds. Each altar has a cooldown after use.

## Tuning

Every number (aura values, lines, bosses, cooldowns, ranks, PvP) is in [`src/shared/Config.lua`](src/shared/Config.lua). Add your own lines there.
Classes and ultimates are in [`src/shared/Classes.lua`](src/shared/Classes.lua). To add a class, copy one and give it a new `Id`.

## Code layout

| Path | Ends up in | What it does |
| --- | --- | --- |
| `src/shared/Config.lua` | ReplicatedStorage.Shared | All tuning |
| `src/shared/Classes.lua` | ReplicatedStorage.Shared | All 44 classes and the six ultimate types |
| `src/shared/HeroicLines.lua` | ReplicatedStorage.Shared | Matches chat to heroic / villain lines and scores them |
| `src/shared/AuraMath.lua` | ReplicatedStorage.Shared | Ranks, style, boss and PvP rewards, attack-zone geometry |
| `src/server/Main.server.lua` | ServerScriptService | Entry point |
| `src/server/World.lua` | | Builds the map, lighting, altars, team bases and safe zones |
| `src/server/AuraService.lua` | | Aura, saving, style meter, armor/lifesteal, line handling |
| `src/server/ClassService.lua` | | Teams, class selection, class health and speed |
| `src/server/PvpService.lua` | | Who can hurt whom, kill credit, PvP rewards |
| `src/server/BossService.lua` | | Boss models, AI, attacks, defeat rewards |
| `src/server/Combat.lua` | | Slash / dash / the six ultimates, against the boss and players |
| `src/server/Effects.lua` | | Telegraphs, slashes, explosions, sword, aura particles, name tags |
| `src/client/Main.client.lua` | StarterPlayerScripts | Input, dash movement, chat forwarding |
| `src/client/Hud.lua` | | The on-screen UI |
| `src/client/ClassPicker.lua` | | The class picker |

### How chat is read

Heroic lines are picked up three ways, and the server ignores a message that arrives twice:
`Player.Chatted` on the server, `TextChatService.SendingMessage` on the client (forwarded through a RemoteEvent),
and the in-game SHOUT box. Roblox has been changing how `Player.Chatted` behaves under TextChatService, so the game doesn't rely on it alone.
Only the game's own line text is ever shown over a player's head, never raw player text, so there's no unfiltered text on display.

## Tests

The pure logic (`src/shared`) has unit tests in `tests/run_tests.lua`. They need a Luau runtime whose global `require(name)`
loads `src/shared/<name>.lua`. The code also passes [Selene](https://github.com/Kampfkarren/selene) with the Roblox standard library (`selene src tests`).

## Not tested in Roblox Studio yet

This was written and checked outside Roblox: the unit tests pass, Selene finds no problems, [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) type-checks it against the Roblox API with no errors, and Rojo builds the place.
Nobody has played it in Studio yet, so movement feel, UI layout on small screens and balance (especially the 44 classes in PvP) will probably need tweaking.
PvP needs at least two players: in Studio, start a local test server with 2 or more players from the Test tab.
