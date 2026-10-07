# Make an Anime Power (Roblox)

A Roblox game where you make your own anime power and fight with it.

- **Pick an anime template** (Ki Warrior, Shadow Ninja, Flame Fist, Ice Maker, Thunder Breathing,
  Cursed Sorcerer, Chainsaw Devil, Spirit Gunner, Psychic, Water Swordsman, Earth Titan,
  Poison Assassin) or start from a **Blank Power**.
- **Make the power your own**: name it, pick its element, aura color and aura style, and spread
  20 stat points across Strength, Defense, Speed and Energy.
- **Make your own abilities** (up to 4, on Q / E / R / F): name each attack (your character shouts
  the name when you use it), pick one of 12 ability types and an element, and set its Damage,
  Size and Speed levels. Stronger abilities get longer cooldowns and cost more energy, so any
  combination is allowed and stays fair.
- **Fight** training dummies, roaming arena enemies, and other players (PvP is on everywhere
  except the safe zone around the spawn).
- Up to 6 powers are saved per player with DataStores.

The template names are generic anime archetypes, not characters from real shows.

## Ability types

| Type | What it does | Damage / Size / Speed levels control |
| --- | --- | --- |
| Projectile | Fires a blast toward your aim | Damage / Size / Speed |
| Barrage | Rapid spread of small shots | Damage per shot / Shot count / Speed |
| Beam | Long beam that pierces everyone in its path | Damage / Width / Length |
| Shockwave | Explodes outward from your body | Damage / Radius / Knockback |
| Explosion | The spot you aim at explodes after a warning | Damage / Radius / Range |
| Meteor Rain | Falling blasts around your aim | Damage per meteor / Area / Meteor count |
| Melee Combo | Close-range strike combo | Damage per hit / Reach / Hits |
| Dash Strike | Dash forward, hitting everyone you pass | Damage / Hit width / Distance |
| Teleport | Reappear at your aim with a landing shockwave | Landing damage / Landing radius / Range |
| Barrier | Bubble that blocks damage | Strength / - / Duration |
| Heal | Recover health | Healing / - / - |
| Power Up / Transform | 12 s of extra damage, extra speed and a huge aura | Damage boost / - / Speed boost |

## Elements

Every hit gets its element's side effect: Ki (+10% damage), Fire (burn), Ice (slow),
Lightning (short stun, fast projectiles), Wind (big knockback), Water (knockback and slow),
Earth (+20% damage, slower projectiles), Shadow (20% lifesteal), Light (very fast projectiles),
Poison (long burn), Blood (30% lifesteal), Cursed (+15% damage and a slow).

## Controls

| Action | PC | Phone / tablet |
| --- | --- | --- |
| Open the Power Creator | P, or the **MAKE A POWER** button | **MAKE A POWER** button |
| Abilities 1-4 | Q, E, R, F (aims at your mouse) | Tap the hotbar slots (auto-aims at the closest enemy in front of the camera) |
| Basic attack | Left click | **ATTACK** button |

## Opening it in Roblox Studio

The game is a [Rojo](https://rojo.space) project: the scripts live as files in `src/`, and Rojo
turns them into a Roblox place.

**Quickest: open the included place file**

`MakeAnAnimePower.rbxlx` in this folder is already built from `src/`. Open it in Roblox Studio and
press **Play**. If you change anything in `src/`, rebuild it (Option A) so the file stays up to date.

**Option A: build a place file**

1. Install Rojo 7 (see the Rojo website for install options).
2. In this folder, run: `rojo build -o MakeAnAnimePower.rbxlx`
3. Open `MakeAnAnimePower.rbxlx` in Roblox Studio and press **Play**.

**Option B: live sync while you edit**

1. Install Rojo and the Rojo Studio plugin.
2. Run `rojo serve` in this folder.
3. In Studio, open a new **Baseplate** place, open the Rojo plugin and press **Connect**.

The map (spawn plaza, training dummies, battle arena) is built by `src/server/World.lua` when the
server starts, so there's nothing to build by hand. If the place already has a part named
`Baseplate`, the game uses that instead of making its own ground.

### Saving powers

Saving uses DataStores, which only work in a **published** game:

1. In Studio: File > Publish to Roblox.
2. Game Settings > Security > turn on **Enable Studio Access to API Services** (only needed to test
   saving inside Studio).

Without that, the game still works, but powers are lost when you leave (the game tells you so).

## Project layout

```
default.project.json        Rojo project (where each folder goes in the place)
src/shared/                 ReplicatedStorage.Shared - used by server and client
  Config.lua                all the tuning numbers (budgets, health, energy, spawn counts...)
  Elements.lua              the 12 elements and their side effects
  AbilityTypes.lua          the 12 ability types and their cooldown / energy formulas
  Templates.lua             the anime template list
  PowerValidator.lua        cleans up any power a client sends (anti-cheat)
  Remotes.lua               creates / finds the RemoteEvents and RemoteFunctions
src/server/                 ServerScriptService.Server
  Main.server.lua           starts everything
  World.lua                 builds the map
  PowerService.lua          saving/loading, equip, text filtering, character stats and aura
  CombatService.lua         abilities, projectiles, damage, energy, cooldowns
  Status.lua                burns, slows, stuns, barriers, power-ups
  EnemyService.lua          training dummies and arena enemies
  Visuals.lua               auras and barrier bubbles
src/client/                 StarterPlayerScripts.Client
  Main.client.lua           starts the UI and input
  Creator.lua               the Power Creator window
  HUD.lua                   health/energy bars, hotbar, notifications
  Controls.lua              keys, clicks, touch, aiming
  Fx.lua                    draws the visual effects the server sends
  UIKit.lua                 UI helpers
tests/                      tests for the shared modules (standalone Luau)
```

### How it's built

- **The server decides every hit.** The client only sends "use ability N, aiming here". The server
  checks cooldowns, energy and stuns, runs the ability, and moves projectiles itself.
- **Powers from clients aren't trusted.** Every power is run through `PowerValidator.sanitize`
  (stat budget, level limits, valid types and elements, name length) before it's saved or used.
- **Names are filtered.** Power and ability names are shown to other players (name tags, attack
  shouts, the leaderboard), so the server runs them through Roblox's `TextService` filter when you
  save. If filtering fails, the name is replaced with "Power" / "Ability".
- **Effects are drawn by each client.** The server sends effect events (projectile spawned, beam,
  explosion, damage number...) and every client draws them locally, so they move smoothly.

## Adding your own template

Add an entry to `Templates.List` in `src/shared/Templates.lua`:

```lua
{
	id = "MyTemplate",
	name = "My Template",
	description = "Shown on the template card.",
	power = {
		element = "Fire", -- one of Elements.Order
		color = { 255, 120, 40 }, -- RGB
		aura = "Flames", -- None, Flames, Sparkles, Smoke or Glow
		stats = { strength = 5, defense = 5, speed = 5, energy = 5 }, -- 20 points max
		abilities = {
			ability("Fire Ball", "Projectile", "Fire", 6, 5, 5), -- name, type, element, damage, size, speed
		},
	},
},
```

Then run the tests to check it's valid.

## Tests and formatting

The shared modules (templates, validation, ability formulas) have tests that run in the standalone
[Luau](https://luau.org) command-line tool:

```
python3 tests/run.py path/to/luau
```

Code is formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua) (`stylua src`), using
`stylua.toml`.

## Status

The code builds with Rojo, passes luau-lsp's type check against the Roblox API definitions
(no unknown classes, properties or methods), and the shared-module tests pass. It hasn't been play-tested in Roblox Studio yet, so expect some
tuning (damage numbers, effect sizes, enemy difficulty) once you try it. Most of those numbers are
in `src/shared/Config.lua`, `AbilityTypes.lua` and `EnemyService.lua`.
