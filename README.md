# Chainsaw Man — a tModLoader mod for Terraria

An unofficial, fan-made Chainsaw Man mod for **tModLoader 1.4.4**.

The wiki site lives in [`docs/`](docs/index.html) (plain HTML, ready for GitHub Pages).

This repo also contains **Shadowfall: Hollow Creek**, a Roblox horror/action game, in [`shadowfall/`](shadowfall/README.md).

## Content

| Item | What it does | Recipe |
| --- | --- | --- |
| **Pochita's Heart** (accessory) | +8% melee damage. Melee hits heal you a little (drinking blood). Once every 5 minutes, Pochita saves you from a lethal hit and brings you back at half health. | Life Crystal, 5 Chain, Shackle @ Demon/Crimson Altar |
| **Starter Cord** | Use while wearing Pochita's Heart to become the **Chainsaw Devil**; use again to turn back. Every form also gives higher jumps and immunity to knockback and fall damage. The form never runs out and has no cooldown (it also ends if you right-click the buff or die). Tier 1 form: +70% melee damage, +30% melee speed, +10% melee crit, +25 defense, 15% damage reduction, +6 HP/s regen, +40% move speed, much stronger blood healing. | 10 Rope, 3 Iron/Lead Bar @ Anvil |
| **Revved Starter Cord** (upgrade) | Tier 2 form: +120% melee damage, +45% melee speed, +20% melee crit, +50 defense, 25% damage reduction, +12 HP/s regen, +60% move speed, stronger healing. | Starter Cord, 10 Hallowed Bar, 5 each Soul of Might/Fright/Sight @ Mythril/Orichalcum Anvil |
| **Hero of Hell's Cord** (upgrade) | Tier 3 form: +200% melee damage, +60% melee speed, +30% melee crit, +80 defense, 35% damage reduction, +20 HP/s regen, +80% move speed, strongest healing. Uses the Hero of Hell sprite. | Revved Starter Cord, 10 Luminite Bar, 15 Solar Fragment @ Ancient Manipulator |
| **Chainsaw Arm** | Held chainsaw: 45 base damage, 16% crit, hits each enemy up to 15 times a second, 175% axe power. Inflicts Ichor (lower defense) and On Fire. Gains +15 / +30 / +30 / +40 / +80 base damage after Skeletron / Wall of Flesh / any mechanical boss / Plantera / Moon Lord, and deals 2x / 3.5x / 5x damage in Chainsaw Devil form (by cord tier). | 12 Iron/Lead Bar, 10 Chain @ Anvil |
| **Pochita Doll** | Summons Pochita as a flying pet. | 10 Silk, 2 Chain @ Loom |

## Hybrid forms

Seven more devil hybrid forms, each with its own transform item (use to transform, use again to turn back; no time limit or cooldown).
Transforming into one ends any other form, Chainsaw Man included. Each has a single form that grows stronger as you beat bosses
(Skeletron, Wall of Flesh, any mechanical boss, Plantera, Moon Lord): **+40% to +140% damage, +10 to +60 defense, 5-25% damage
reduction, 2-17 HP/s regen, +20-60% move speed**, plus knockback and fall damage immunity and a perk of its own.
Reze and Katana Man use real sprite sheets (cleaned from `art/reze_source.png` and `art/katana_man_source.png` by `tools/clean_sprite_sheet.py`). The other five still use script-drawn placeholders (`Content/Players/Hybrid<Name>Sheet.png`), ready to be replaced.

| Form | Transform item (all @ Anvil) | Perk | Abilities |
| --- | --- | --- | --- |
| **Reze** (Bomb) | Grenade Pin: 15 Devil Flesh, 10 Grenades | Immune to fire, much higher jumps | Bomb Blast, Explosive Punch, Torpedo Dash |
| **Katana Man** | Katana Devil's Heart: 15 Devil Flesh, 12 Iron/Lead Bar, 5 Silk | +25% melee speed, +15% crit | Katana Slash, Quick Draw, Slash Wave |
| **Quanxi** (Bow) | Bow Devil's Heart: 15 Devil Flesh, 100 Wooden Arrows, 5 Iron/Lead Bar | +25% crit | Arrow Barrage, Piercing Shot |
| **Barem Bridge** (Flamethrower) | Flamethrower Devil's Heart: 15 Devil Flesh, 10 Hellstone | Immune to fire and lava | Flame Breath, Fire Wall |
| **Miri Sugo** (Sword) | Sword Devil's Heart: 15 Devil Flesh, 15 Iron/Lead Bar | +15 defense, +15% melee speed | Sword Slash, Blade Eruption |
| **Spear Hybrid** | Spear Devil's Heart: 15 Devil Flesh, 10 Iron/Lead Bar, 20 Wood | +15% crit, +20 armor penetration | Spear Thrust, Spear Rain |
| **Whip Hybrid** | Whip Devil's Heart: 15 Devil Flesh, 10 Chain, 5 Leather | +25% move speed, +15% attack speed | Whip Crack, Whip Grab |

## Chainsaw Devil abilities

While you're transformed, ability items are put into your inventory automatically (first empty slots, hotbar first).
They disappear when you turn back, if you switch to a lower-tier cord, or if you drop them.
Damaging abilities scale like the Chainsaw Arm (progression bonus x form multiplier).

| Ability | Cord tier | What it does |
| --- | --- | --- |
| **Chainsaw Slash** | 1+ | Huge, fast melee swings (55 base damage). Lowers enemy defense. |
| **Rev Dash** | 1+ | Dash toward the cursor, damaging everything you pass through (70 base damage). Brief invincibility, no fall damage. |
| **Blood Drink** | 1+ | Heal 30% of max health. 20 second cooldown. |
| **Chain Hook** | 2+ | Fire a chain (60 base damage) that pulls you to the enemy or block it hits. |
| **Chainsaw Storm** | 3 | 4 chainsaw blades orbit you for 6 seconds (50 base damage each). |

If your inventory is full, you won't get the abilities until you free up slots.

## Devils

| Enemy / Boss | Where / how | Drops |
| --- | --- | --- |
| **Zombie Devil Minion** | Surface at night, any time. Also raised by the Zombie Devil. | Devil Flesh (50%) |
| **Devil Bat** | Surface at night in Hardmode. Also called by the Bat Devil. | Devil Flesh (50%) |
| **Zombie Devil** (pre-Hardmode boss, 3,500 HP) | Use a **Rotting Offering** (8 Devil Flesh @ Demon/Crimson Altar). Walks at you, leaps and slams the ground to spray blood bolts, and raises Zombie Devil Minions. Faster below 50% HP. | 15-25 Devil Flesh, Chainsaw Arm (33%), Pochita's Heart (25%) |
| **Bat Devil** (Hardmode boss, 28,000 HP) | Use a **Bloody Bat Fang** (15 Devil Flesh, 5 Soul of Night @ Mythril/Orichalcum Anvil). Flies above you firing spreads of blood bolts, then winds up and dashes. Below 50% HP: wider spreads, double dashes and Devil Bat swarms. | 20-30 Devil Flesh, 15-25 Soul of Flight, Revved Starter Cord (25%) |
| **Ghost Devil** | Caverns. Drifts through walls and fades in and out. | Devil Flesh (50%) |
| **Spider Devil** | Caverns. Scuttles along the ground; its bite poisons. | Devil Flesh (50%), Cobwebs |
| **Fire Devil** | Underworld. Hovers nearby and throws fireballs that set you on fire. | Devil Flesh (50%), Hellstone (50%) |
| **Gun Devil Spawn** | Surface in Hardmode. Keeps its distance and fires 3-bullet bursts. Also called by the Gun Devil. | Gun Devil Fragment (33%), Devil Flesh (50%) |
| **Eternity Fleshling** | Only spawned by the Eternity Devil. | Devil Flesh (33%) |
| **Eternity Devil** (Hardmode boss, 40,000 HP) | Use a **Cursed Hotel Key** (20 Devil Flesh, 8 Soul of Night, Golden Key @ Mythril/Orichalcum Anvil). A giant drifting mass of flesh that fires rings of blood and spits out Eternity Fleshlings. **It regenerates while any Fleshlings are alive.** | 25-40 Devil Flesh, 10-20 Soul of Night, 10-20 Soul of Light |
| **Gun Devil** (post-Plantera boss, 55,000 HP) | Use a **Gun Devil's Trigger** (15 Gun Devil Fragment, 10 Devil Flesh @ Mythril/Orichalcum Anvil). Circles you with rapid gunfire, stops to fire a bullet spiral, then charges 3 times. Below 50% HP it is faster and calls Gun Devil Spawn. | 20-35 Gun Devil Fragment, 30-50 Devil Flesh, 15-25 Chlorophyte Bar |
| **Snake Devil** | Jungle. Slithers along the ground; its bite poisons. | Devil Flesh (50%) |
| **Shark Devil** | Beach. Swims through sand, water and air, circling you and lunging. | Devil Flesh (50%), Shark Fin (33%) |
| **Fox Devil** | Snow. Fast runner; its bite gives frostburn. | Devil Flesh (50%) |
| **Violence Fiend** | Surface at night in Hardmode. Slow, heavy brute that confuses on hit. | 3-6 Devil Flesh |
| **Angel Devil** | Hallow in Hardmode. Flies above you throwing feathers; feathers and touch slow you. | 2-5 Devil Flesh, Soul of Light (50%) |
| **Curse Devil** | Dungeon in Hardmode. Floats through walls firing nails that curse you (no item use). | 2-5 Devil Flesh, Ectoplasm (33%) |
| **Typhoon Devil** (Hardmode boss, 32,000 HP) | Use a **Typhoon Charm** (20 Devil Flesh, 10 Feather, 5 Soul of Flight @ Mythril/Orichalcum Anvil). Circles you firing spirals of wind, becomes a vortex that drags you in, then charges. Faster and denser below 50% HP. | 20-35 Devil Flesh, 20-30 Soul of Flight |
| **Darkness Devil** (post-Moon Lord boss, 120,000 HP) | Use a **Darkness Shard** (10 Luminite Bar, 30 Devil Flesh, 10 Soul of Night @ Ancient Manipulator). Keeps you in darkness while it's near. Hands of darkness rise under you (watch for black smoke), rings of shadow bolts, and it vanishes to reappear behind you and lunge. Faster below 50% HP. | 15-25 Luminite Bar, 40-60 Devil Flesh, 20-30 Soul of Night |
| **Makima** (post-Moon Lord boss, 150,000 HP) | Use **Makima's Contract** (10 Luminite Bar, 10 Gun Devil Fragment, 20 Devil Flesh @ Ancient Manipulator). Walks toward you and cycles through: finger-gun **Bang** shots, white **hounds** that burst from the ground under you (watch for bubbling blood), floating **gun fiends** that spray bullets, a **contract** that calls other devils, and a blood-melt **teleport**. If you get close she lunges in with one of two **kick combos**. **She takes half damage while any of her devils are alive.** At half health she's knocked down, gets back up, and everything gets faster. | Hero of Hell's Cord (33%), 20-30 Luminite Bar, 40-60 Devil Flesh, 20-30 Gun Devil Fragment |

## More devils

A second wave built on shared templates (`DevilEnemyBase`, `DevilBossBase`), so each one is a short list of numbers.
All art is script-drawn placeholders.

**Enemies**

| Enemy | Where / behaviour |
| --- | --- |
| Leech Devil | Caverns. A fat leech that clings and poisons. |
| Rat Devil | Surface, daytime. A mangy rat the size of a dog. |
| Crow Devil | Surface, daytime. Circles overhead and dives at you. |
| Mosquito Devil | Jungle. A fast, bloodsucking pest. |
| Cockroach Devil | Underground desert. Armoured and very hard to squash. |
| Sand Devil | Desert. Swims through sand and bursts out to bite. |
| Ice Devil | Snow. A floating chunk of ice that throws frozen shards. |
| Mud Devil | Underground. Swims through the dirt beneath your feet. |
| Bone Devil | Dungeon. Rattling bones held together by fear alone. |
| Mold Devil | Corruption and Crimson. A walking heap of rot. |
| Lava Devil | Underworld. Molten rock in the shape of a man. |
| Octopus Devil | Beach. Squirts blinding ink from below. |
| Mushroom Devil | Glowing mushroom caves. Its spores leave you confused. |
| Grave Devil | Graveyards. Climbs out of old graves after dark thoughts. |
| Lightning Devil | Surface during rain, Hardmode. Strikes with fast bolts of lightning. |
| Needle Devil | Caverns, Hardmode. A ball of needles that fires them in bursts. |
| Plague Devil | Hardmode Corruption and Crimson. Its touch rots your armour. |
| Mirror Devil | Hardmode Hallow. Throws shards of glass that leave you confused. |
| Tooth Devil | Caverns, Hardmode. A mouth full of teeth on legs. |
| Wind Devil | Sky, Hardmode. Rides the high winds and blasts you with gusts. |

**Bosses** (each summoned by its own item; all drop Devil Flesh)

| Boss | HP | Summon | Unlocks | Moves | Attacks |
| --- | --- | --- | --- | --- | --- |
| Leech Devil Queen | 2,800 | Leech Bait | any time | Walk | Spread, Summon, Charge, Spread |
| Spider Devil Queen | 4,500 | Silk Cocoon | after Eater of Worlds / Brain of Cthulhu | Walk | Spikes, Spread, Summon, Charge |
| Frost Devil | 6,000 | Frozen Heart | after Skeletron | Hover | Ring, Spiral, Summon, Rain |
| Sand Devil Colossus | 25,000 | Desert Seal | Hardmode | Walk | Spikes, Rain, Charge, Summon |
| Kraken Devil | 30,000 | Kraken Ink | Hardmode | Hover | Spread, Ring, Summon, Charge |
| Future Devil | 40,000 | Future Clock | after a mechanical boss | Circle | Teleport, Spread, Spiral, Charge |
| War Devil | 60,000 | War Banner | after Plantera | Walk | Rain, Spikes, Charge, Summon, Spread |
| Famine Devil | 70,000 | Empty Bowl | after Golem | Hover | Ring, Summon, Spiral, Teleport |
| Falling Devil | 110,000 | Falling Star Shard | after Moon Lord | Hover | Rain, Spiral, Ring, Teleport, Rain |
| Death Devil | 200,000 | Deaths Contract | after Makima | Circle | Spread, Ring, Spiral, Rain, Spikes, Summon, Teleport, Charge |

## Chainsaw Devil sprite

While transformed, your character is drawn as an animated Chainsaw Devil sprite instead of the normal player body.
It switches between idle, walk, run, jump, crouch, hurt and 8 different attack animations (5 on the ground, 3 in the air),
picking a random attack each swing. Held items, wings, mounts and debuff effects are still drawn on top.

With the **Hero of Hell's Cord** (tier 3) you turn into the Hero of Hell form instead, which has its own sprite sheet
(including an extra chain attack animation).

- `Content/Players/ChainsawDevilSheet.png` / `HeroOfHellSheet.png`: the cleaned in-game sprite sheets
- `art/ChainsawDevilSheet_preview_4x.png` / `art/HeroOfHellSheet_preview_4x.png`: big labelled previews of every frame
- `art/chainsaw_devil_source.png` / `art/hero_of_hell_source.png`: the original sheets they were made from
- `tools/clean_sprite_sheet.py`: regenerates both sheets, plus Makima's boss sprites from `art/makima_source.png` (`pip install pillow numpy scipy`, then `python3 tools/clean_sprite_sheet.py`)

To make the sprite bigger or smaller, change `SpriteScale` in `Content/Players/ChainsawDevilDrawLayer.cs`.

## Installing / building

You need Terraria with tModLoader 1.4.4 (free on Steam).

1. Launch tModLoader once so it creates its `ModSources` folder:
   - Windows: `Documents\My Games\Terraria\tModLoader\ModSources`
   - Linux: `~/.local/share/Terraria/tModLoader/ModSources`
   - macOS: `~/Library/Application Support/Terraria/tModLoader/ModSources`
2. Clone this repo into that folder **as `ChainsawManMod`** (the folder name must match the mod name):
   ```
   git clone https://github.com/speedyteam101/chainsaw-man-mod.git ChainsawManMod
   ```
3. In tModLoader: **Workshop → Develop Mods → ChainsawManMod → Build + Reload**.
4. Enable the mod and play.

### Troubleshooting

**"Namespace and Folder name do not match. The top level namespace must match the folder name."**
The folder inside `ModSources` has the wrong name. It must be exactly `ChainsawManMod` (same capitals).
Rename it, then **Build + Reload** again.

## Art

Apart from the Chainsaw Devil sprite sheet, all sprites are simple placeholders generated by `tools/generate_sprites.py`
(`pip install pillow`, then `python3 tools/generate_sprites.py` from the repo root).
Replace any PNG with your own art at the same size.

## Disclaimer

The Chainsaw Devil, Hero of Hell, Makima, Katana Man and Reze sprite sheets were supplied by the project owner; their original artists aren't recorded here. Get the artist's permission and credit them before publishing this mod (for example on the Steam Workshop).


Chainsaw Man is created by Tatsuki Fujimoto. This is a non-commercial fan project and is not affiliated with or endorsed by the rights holders.
