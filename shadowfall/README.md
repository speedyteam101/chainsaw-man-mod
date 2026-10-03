# Shadowfall: Hollow Creek

A Roblox game. At noon the sky over the town of Hollow Creek went black, and the whole town was pulled into the shadow world.
**Shadows** live there: pitch-black, blocky, R6-shaped figures with smoke pouring off them and thin glowing eyes.

The game starts as a first-person **horror** chapter: you have a flashlight and nothing else. Then you find out you have a power, roll it, and the game turns into a **bandit-beater-style** action game.
The difference from other bandit beaters is that it has **no quests and no XP**. The only way to level up is to earn a feat that qualifies you for the next level.

Everything (map, shadows, UI, effects) is generated from code, so the project needs no uploaded models.

---

## How to open it

You need [Rojo](https://rojo.space) 7.x.

```bash
cd shadowfall
rojo build -o Shadowfall.rbxlx     # then open Shadowfall.rbxlx in Roblox Studio
# or, for live syncing while you edit:
rojo serve                          # and connect with the Rojo Studio plugin
```

The GitHub Actions workflow `.github/workflows/shadowfall.yml` also type-checks the code and builds `Shadowfall.rbxlx` as a downloadable artifact on every push that touches `shadowfall/`.

**Studio settings to check:**

1. **R6 avatars.** The project sets `StarterPlayer.GameSettingsAvatar = R6`, but I couldn't confirm that Roblox honours this property when it comes from a file. After publishing, also set **Game Settings → Avatar → Avatar Type → R6**. The game still works with R15 avatars, but the punch arm-swing animation only plays on R6.
2. **Saving.** To test DataStore saving in Studio, turn on **Game Settings → Security → Enable Studio Access to API Services**. Without it the game still runs; it just prints a warning and doesn't save.
3. **Sounds.** No audio ships with the project. Paste sound asset ids into `src/shared/Config.luau` (`Config.Sounds`). Any sound left empty is skipped. Horror works much better with sound, so the ambience, heartbeat, whisper, scream and bell are worth adding first.

The world is built when the server starts, so in Studio's edit mode the Workspace looks empty. Press **Play** to see it.

---

## Act 1: the night it happened (horror)

* You wake up inside your house, in first person, at 12:04 PM, and the sky is pitch black. There's a note from your dad on the table.
* **Flashlight (F):** a beam with a battery that drains while it's on and recharges while it's off. Shadows caught in the beam freeze and shake. Hold the light on one and it's banished (for now).
* **Sprint (Shift):** limited stamina.
* **Stalkers:** they spawn where you aren't looking. When your back is turned they get closer in jumps. If one touches you there's a jumpscare and you lose a third of your health. Your heartbeat speeds up and the screen closes in as they get near.
* **The story:** leave the house → the empty town square → a blinking radio tower (a survivor's broadcast) → the clock tower bell.
* **The finale:** ringing the bell puts out every light in town and brings every shadow at once. You're surrounded, your hands start burning, and **your power awakens**: a full-screen roll reel spins and lands on your power.
* Feat **Unseen:** get to the bell without ever being touched.

## Act 2: the shadow world (action)

You wake up at the survivors' camp in the middle of what's left of Hollow Creek. The bonfire is a safe zone, and you heal fast there. The survivors give you hints, the shrine rerolls your power, and the board shows the Ascension rules.

### Controls

| Action | Keyboard / mouse | Gamepad |
| --- | --- | --- |
| Basic attack (4-hit combo, the 4th hit knocks back) | Left mouse (hold to keep swinging) | R2 |
| Block (hold). Block right as a hit lands to **parry** and stagger the attacker | F | L2 |
| Dodge (i-frames). Dodge through an attack for a **perfect dodge** (+25% damage for a moment) | Q | B |
| Sprint | Shift | L3 |
| Power moves (unlock at levels 1-4) | Z X C V | X, Y, D-pad left/right |
| Awakening (level 5) | G | D-pad up |
| Menu (Ascension, Feats, Power, Warp) | M | Select |

On touch devices, ContextActionService adds on-screen buttons for these actions.

### Combat that rewards skill

* Every shadow **telegraphs**: its eyes turn red during a wind-up, and big attacks draw a red area on the ground that fills up before it lands.
* Stunning a shadow during its wind-up cancels the attack. Parries stagger it.
* Shadow types: **Shade** (melee), **Lurker** (blinks behind you), **Howler** (keeps its distance and shoots), **Brute** (huge, slams the ground), **Wraith** (fast, lunges).
* Each area has a **boss** with several attack patterns and an enraged second phase at half health: slams, charges, projectile volleys, eruptions under every player, and summoned adds.

### Progression: feats, not XP

There are **no quests and no experience points**. To go from level N to N+1 you need **any one** of that level's qualifying feats. Then you press **Ascend** in the menu.

| To reach | Qualifying feats (earn any one) |
| --- | --- |
| Level 2 | **First Light:** defeat the Hollow Warden · **Untouchable:** defeat 10 shadows in a row without taking damage · **Steady Hand:** parry 5 attacks |
| Level 3 | **Antlers in the Dark:** defeat the Antlered Shade · **Chain Reaction:** defeat 4 shadows within 3 seconds · **Shadowstep:** perfect-dodge 15 attacks |
| Level 4 | **Blind Them:** defeat the Many-Eyed · **Giant Slayer:** defeat 3 Brutes without any of their attacks hitting you · **Unbroken:** defeat 40 shadows without dying |
| Level 5 | **Silence the Choir:** defeat the Choir Below · **Flawless:** defeat any boss without it hitting you · **Last Light:** defeat 100 shadows without dying |

Honours (they don't qualify you for anything): Awakened, Unseen, Golden Hour (roll a Legendary), Impossible Dawn (roll a Mythic), Ascendant (reach level 5), Dawn (defeat the Umbral King), Exterminator (500 kills).

Each level unlocks:

| Level | Unlocks |
| --- | --- |
| 1 | Your first move (Z), Hollow Creek |
| 2 | Second move (X), **Whispering Woods** |
| 3 | Third move (C), **The Rift** (floating islands over the void) |
| 4 | Fourth move (V), **Sunken Cathedral** |
| 5 | **Awakening** (G: 1.5x damage, half cooldowns, 18 s), **Heart of Shadow** (final boss: the Umbral King) |

Every level also raises damage (x1.0 → x4.3) and max health (+30 per level). The areas get harder in step, so new places stay dangerous.

The areas are connected by bridges over the void. Each bridge ends in a gate that opens only at the right level (the client opens it, and the server also checks). Once you've unlocked an area you can **warp** to it from the menu.

### Powers

The first roll is free (the awakening). After that you can reroll at the shrine for **150 Essence**. Shadows drop Essence. After a reroll you choose: **take the new power or keep your current one**. A pity counter guarantees **Legendary or better within 50 rolls**.

| Power | Rarity (chance) | Passive | Moves (Z / X / C / V) |
| --- | --- | --- | --- |
| Ember | Common (42% shared) | Basic attacks burn | Fireball, Flame Ring, Blaze Dash, Inferno Meteor |
| Gale | Common | +12% move speed | Wind Blade, Gust, Tailwind, Cyclone |
| Frost | Uncommon (30% shared) | Basic attacks slow | Ice Shards, Frost Nova, Glacier Lance, Blizzard |
| Stone | Uncommon | Take 12% less damage | Boulder, Quake, Earthen Charge, Monolith Fall |
| Volt | Rare (16%) | Every 4th hit chains lightning | Spark Bolt, Discharge, Lightning Step, Thunder Judgment |
| Radiance | Epic (9% shared) | +20% basic damage, basic attacks weaken | Light Lance, Solar Flare, Halo, Sunrise |
| Gravity | Epic | Basic attacks pull | Gravity Orb, Repulse, Singularity, Collapse |
| Eclipse | Legendary (2.5%) | 10% lifesteal | Umbral Spear, Devour, Shadow Step, Total Eclipse |
| Dawnbringer | Mythic (0.5%) | +25% damage, basic attacks heal | Dawn Arrow, Daybreak, Radiant Rush, Second Sun |

Higher rarities also get a flat damage multiplier (x1.0 up to x1.55). All numbers live in `src/shared/` and are meant to be tuned.

---

## Project layout

```
shadowfall/
  default.project.json        Rojo project
  src/shared/                 ReplicatedStorage.Shared: data + helpers used by both sides
    Config.luau               tuning, sound ids, DataStore name
    Powers.luau               powers, rarities, roll logic
    Achievements.luau         feats and which level each one qualifies for
    Areas.luau                world layout and area stats
    Enemies.luau              shadow types and bosses
    ShadowRig.luau            builds the blocky R6 shadow model (black neon + smoke)
    Remotes.luau, Signal.luau
  src/server/                 ServerScriptService.Server
    Main.server.luau          entry point: world, services, spawning, remotes
    World/                    procedural world (towns, woods, rift, cathedral, heart)
    Act1Director.luau         horror chapter: story beats, stalkers, finale
    Combat.luau               combos, block/parry, dodge, damage, status effects
    EnemyService.luau         shadow + boss AI
    PowerService.luau         rolling and power moves
    AchievementService.luau   feats and Ascension
    ZoneService.luau          gates, safe zone, regen, void, warp
    Projectiles.luau, PlayerData.luau, Registry.luau
  src/client/                 StarterPlayerScripts.Client
    Main.client.luau          entry point
    Horror.luau               flashlight, stamina, heartbeat, subtitles, jumpscares, finale
    RollUI.luau               the roll reel and reveal
    Hud.luau, Menu.luau       Act 2 interface
    CombatInput.luau          controls
    Fx.luau, CameraFx.luau    visual effects
    Atmosphere.luau           lighting per act, flickering lamps, telegraph fills, gates
    ShadowAnimator.luau       procedural limb animation for shadows
  src/character/Health.server.luau   turns off Roblox's default regen (the server handles it)
```

### Dev tools

In Studio only, the menu has a **Dev** tab: skip Act 1, grant a qualifying feat, +1000 Essence, reset your data. The server refuses these outside Studio. To remove the tab entirely, set `Config.EnableStudioDevTools = false`.

---

## Status and known limits

* **Not play-tested.** It was written outside Roblox Studio. It passes `luau-lsp` type-checking against the current Roblox API definitions and builds with Rojo, but nobody has run it in Studio yet. Expect some tuning (enemy counts, damage, speeds) and possibly some bugs.
* Shadows walk straight at their target and jump when they get stuck. There's no pathfinding, so they can catch on walls. (In Act 1 that reads as them "phasing" closer when you look away.)
* The wisp particles on shadows use the texture path `rbxasset://textures/particles/smoke_main.dds`. I believe that's one of Roblox's built-in textures but haven't confirmed it. If the wisps don't show up, the classic `Smoke` effect on each shadow still works.
* There's no sound until you add ids in `Config.Sounds`.
