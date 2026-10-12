# Aura Farm (Roblox)

A Roblox game where you earn **aura** by being heroic: saying heroic lines and fighting bosses in a cool way.
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

## How to farm aura

| Source | Aura |
| --- | --- |
| **Heroic line** said in chat or the SHOUT box | 10–30 base |
| ...during a boss fight | x2 |
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

### Heroic lines and their moments

Click **LINES** next to the shout box to see them all in game. Lines match even with small typos or a missing word.

| Moment | Lines (bonus) |
| --- | --- |
| Boss under 25% HP | *This ends now.* (x4), *Remember my name.* (x3), *Watch closely. This is how it's done.* (x2) |
| You under 30% HP | *I won't lose. Not here. Not now.* (x3), *One more round.* (x3), *Even if I fall, I'll get back up.* (x2), *I didn't come this far to quit.* (x2) |
| Right after a perfect dodge | *Too slow.* (x4), *It's my turn now.* (x3), *I'm not even trying yet.* (x2) |
| Right after taking a hit | *Is that all you've got?* (x3), *That barely scratched me.* (x3) |
| Before a fight | *Stand back. I'll handle this.*, *Get behind me.*, *The hero always shows up.* (x2 each) |
| Any time | *You picked the wrong hero to fight.*, *My friends are my power!*, *I never back down.*, *Today, I go beyond my limits!*, *You hurt the people I care about. That was your mistake.*, *I fight for everyone who can't.*, *Nothing can stop me.* |

### Controls

| Action | PC | Gamepad | Touch |
| --- | --- | --- | --- |
| Slash (hold to keep slashing) | Left click | R2 | SLASH button |
| Dash (brief invincibility) | Q | B | DASH button |
| Ultimate (needs **S** style; spends most of it) | F | Y | ULT button |
| Challenge a boss | Hold E at an altar | | Tap the prompt |

### Style meter

Hits, perfect dodges and heroic lines during a fight fill your style meter (**D → C → B → A → S → SSS**, x1 to x3).
Getting hit drains it, and it slowly fades if you stop doing cool things.

### Ranks

NPC → Background Character (100) → Side Character (500) → Rival (1,500) → Main Character (4,000) → Protagonist (10,000) → Legend (25,000) → Aura God (60,000).
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

Every number (aura values, lines, bosses, cooldowns, ranks) is in [`src/shared/Config.lua`](src/shared/Config.lua). Add your own heroic lines there.

## Code layout

| Path | Ends up in | What it does |
| --- | --- | --- |
| `src/shared/Config.lua` | ReplicatedStorage.Shared | All tuning |
| `src/shared/HeroicLines.lua` | ReplicatedStorage.Shared | Matches chat to heroic lines and scores them |
| `src/shared/AuraMath.lua` | ReplicatedStorage.Shared | Ranks, style, boss rewards, attack-zone geometry |
| `src/server/Main.server.lua` | ServerScriptService | Entry point |
| `src/server/World.lua` | | Builds the map, lighting and altars |
| `src/server/AuraService.lua` | | Aura, saving, style meter, heroic line handling |
| `src/server/BossService.lua` | | Boss models, AI, attacks, defeat rewards |
| `src/server/Combat.lua` | | Validates slash / dash / ultimate |
| `src/server/Effects.lua` | | Telegraphs, slashes, explosions, sword, aura particles, name tags |
| `src/client/Main.client.lua` | StarterPlayerScripts | Input, dash movement, chat forwarding |
| `src/client/Hud.lua` | | The on-screen UI |

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
Nobody has played it in Studio yet, so movement feel, UI layout on small screens and balance will probably need tweaking.
