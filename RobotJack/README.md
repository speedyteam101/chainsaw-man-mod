# Robot Jack — a tModLoader mod for Terraria

A small standalone mod for **tModLoader 1.4.4**: find the **Robot Trigger**, transform into a sci-fi combat robot, and use ability items, headlined by the **Orbital Cannon Strike**.

It lives in this repository next to the Chainsaw Man mod but is a **separate mod**. The Chainsaw Man build ignores this folder.

## Installing (from source)

1. Copy this `RobotJack` folder into your tModLoader `ModSources` folder, so you have `ModSources/RobotJack/build.txt`.
   (On Windows that is usually `Documents/My Games/Terraria/tModLoader/ModSources`.)
2. In tModLoader: **Workshop → Develop Mods → Robot Jack → Build + Reload**.

## Getting the Robot Trigger

It can't be crafted; you have to find it:

- **Underground Gold Chests:** roughly 1 in 4 of them in a **newly generated** world has one, and every new world gets at least one.
- **Enemy drop:** any enemy killed below the surface has a **1 in 150** chance to drop one. Bosses, critters and statue-spawned enemies don't count. This is how you get one in a world that existed before you installed the mod.

## The transformation

Use the Robot Trigger to become Robot Jack; use it again to turn back. The form has no time limit or cooldown and also ends if you right-click the buff or die.

- +25% damage, +20 defense, 10% damage reduction, +30% movement speed
- Higher jumps, no knockback, no fall damage
- **Hover jets:** hold jump while falling to glide down
- Your character is drawn as a robot. It animates with your walking, jumping and aiming, and its visor, chest core and jets glow in the dark.

## Abilities

While transformed, the ability items are put into your inventory automatically (first empty slots, hotbar first). They vanish when you turn back or if you drop them. If your inventory is full you won't get them until you free up slots.

All ability damage grows as you beat bosses: ×1.3 after Skeletron, then +0.4 after the Wall of Flesh, +0.3 after any mechanical boss, +0.4 after Plantera and +0.6 after the Moon Lord, up to **×3**. The form's +25% damage applies on top of that.

| Ability | Base damage | What it does |
| --- | --- | --- |
| **Orbital Cannon Strike** | 60 per hit | Click anywhere on screen. A satellite slides into view high above and a spinning red reticle locks onto the ground below your cursor (about 1.2 s, with a flickering guide laser and speeding-up beeps). Then a huge cyan-white laser slams down from the satellite: screen shake, a shockwave, sparks, smoke and light. The beam lasts about 1.3 s and hits everything in the column and near the impact point every 8 ticks, inflicting Electrified and Hellfire. It passes through blocks without breaking them. **8 second cooldown.** |
| **Plasma Cannon** | 28 | Rapid-fire plasma bolts from your arm cannon (auto-fire, pierces 1 enemy). |
| **Missile Barrage** | 45 each | Fires a fan of 6 micro-missiles that home in on the nearest enemies and explode. |
| **Thruster Dash** | 60 (melee) | Rocket toward the cursor with brief invincibility, burning everything you pass through. |

## Art

All sprites are placeholders drawn by `tools/generate_sprites.py` (needs Pillow: `pip install pillow`; run it from this folder).
Replace any PNG with hand-made art at the same size whenever you like. The robot sheets (`Content/Players/RobotBody*.png`, `RobotLegs*.png`) use the vanilla player sheet layout: 20 frames of 40×56 stacked vertically (0 idle, 1–4 arm aiming up → down, 5 jump, 6–19 walk cycle). The `_Glow` sheets are drawn full-bright on top.

`tools/robot_preview_8x.png` is an enlarged preview of a few robot frames.
