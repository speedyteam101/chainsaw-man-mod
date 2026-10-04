# Shadowfall: Hollow Creek

A Roblox game. At noon the sky over the town of Hollow Creek went black, and the whole town was pulled into the shadow world.
**Shadows** live there. Every shadow is built on the **default Roblox R6 character**: the same parts, rounded head and joint layout, but pitch black, with smoke pouring off them and thin glowing eyes.
Up close you can see more: smoke tendrils sway behind them, dim cracks of light pulse across their bodies, smoke trails off their hands and drips from their fingers, and a pool of darkness follows their feet.
Their mouths split open when they attack. They glitch out of view for a frame, their heads snap sideways, and stalkers move in a jerky stop-motion.

The whole game is played in **first person**. You can see your own arms when you punch and cast, a small crosshair aims your attacks, and the mouse frees itself whenever a menu or dialogue is open. It starts as a **horror** chapter: you have a flashlight and nothing else. Then you find out you have a power, roll it, and the game turns into a **bandit-beater-style** action game.
The difference from other bandit beaters is that it has **no quests and no XP**. The only way to level up is to earn a feat that qualifies you for the next level.

Everything (map, shadows, UI, effects) is generated from code, so the project needs no uploaded models.

**The map** is built on Roblox Terrain:
* **Hollow Creek:** grass lawns sit on a thick slab of earth with rock cliffs where the town was torn out of the ground. Chunks dangle underneath.
* **Streets:** asphalt roads with dashed centre lines, crosswalks, raised concrete sidewalks, cast-iron street lamps, wooden power poles with sagging wires, hydrants, bins, street signs and manholes.
* **Houses:** siding or brick, corner boards, framed windows with mullions and sills, an open front door, a porch with steps and a light, overhanging gable roofs, chimneys, front walks, mailboxes and hedges. Some have two storeys.
* **Woods and Rift:** the Woods have rolling ground, leaf litter, a muddy track, mossy boulders and fallen logs. The Rift's islands are floating masses of earth and rock.
* **Cathedral and Heart:** the Cathedral is flooded with real (knee-deep) water. The Heart is basalt shot through with cracked lava.

For swaying grass blades, select **Terrain** in Studio's Explorer and tick **Decoration**. Scripts can't turn this on.

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
3. **Sounds.** No audio ships with the project. Paste sound asset ids into `src/shared/Config.luau` (`Config.Sounds`). Any sound left empty is skipped. Horror works much better with sound, so add these first:
   * the ambience, heartbeat, whisper, scream and bell
   * Biscuit's quack
   * shadow breathing

The world is built when the server starts, so in Studio's edit mode the Workspace looks empty. Press **Play** to see it.

---

## Creating your character

The first time you join, before the story starts, you make your character:

* skin tone and eye colour
* hairstyle (short, messy, long, ponytail, spiky, beanie, cap or none) and hair colour
* outfit (T-shirt, hoodie, jacket, overalls or long coat), its colour, and long or short sleeves
* trouser colour

There's a **Random** button, or you can pick **Use my Roblox avatar** instead. A spinning 3D preview shows exactly what you'll look like. Change it any time later from the menu's **Look** tab.

**Realistic characters.** Characters keep the R6 body, because the animations, first-person view and shadows are built on it. On top of that, players and every NPC (camp survivors, rescued townsfolk, people trapped in cocoons, merchants, and your parents in the intro) get detail built from parts (`src/shared/Figure.luau`):

* the rounded R6 head with eyes (whites, coloured irises, pupils and a glint), brows, nose, mouth and ears
* hands showing under long sleeves
* fabric clothes with collars, buttons, pockets, cuffs and belts
* outfit pieces: hood and drawstrings, leather jacket, overalls with straps, a blacksmith's apron, a long coat, a doctor's coat
* leather shoes with rubber soles, and hair

NPCs get a fitting outfit (the mechanic wears overalls, the doctor a white coat, blacksmiths aprons). Anyone without one gets a look generated from their name, so everyone looks different but always the same. In first person, your own face and hair are hidden, but your sleeves and hands show with your arms.

Players who already had a save also see the creator once, the next time they join.

## Act 1: the night it happened (horror)

* **Opening cutscene:** a red clock reads 12:04 PM, and your call duck **Biscuit** is quacking in a panic. You open your eyes and find Mum and Dad lying on the living-room floor. A shadow has Biscuit cornered.
* **Save Biscuit:** hold your flashlight on the shadow until it's driven off. From then on Biscuit follows you for the whole game (see below). Dad's last note is on the table by the door.
* **Flashlight (F):** a beam with a battery that drains while it's on and recharges while it's off. Shadows caught in the beam freeze and shake. Hold the light on one and it's banished (for now).
* **Sprint (Shift):** limited stamina.
* **Stalkers:** they spawn where you aren't looking. When your back is turned they get closer in jumps. If one touches you there's a jumpscare and you lose a third of your health. Your heartbeat speeds up and the screen closes in as they get near.
* **The story:** leave the house → the empty town square → a blinking radio tower (a survivor's broadcast) → the clock tower bell.
* **The finale:** ringing the bell puts out every light in town and brings every shadow at once. You're surrounded, your hands start burning, and **your power awakens**: a full-screen roll reel spins and lands on your power.
* Feat **Unseen:** get to the bell without ever being touched.

## Biscuit, your call duck

Biscuit is built from smooth rounded shapes: a round body and chest, a big round head, a short orange bill whose lower half opens when Biscuit quacks, eyes with a glint, folded wings with grey-tipped feathers, an upturned tail and webbed feet.

Biscuit acts like a real duck:
* waddles, rolling side to side with each step
* bobs their head while walking
* pecks at the ground, preens, looks around
* stretches a wing, shakes their tail and settles down to rest
* flaps in a panic when scared

* Biscuit waddles after you everywhere, including warps and respawns.
* **While you're within about 20 studs of Biscuit you regain sanity and health.**
* You can **pet** Biscuit (E) for a burst of sanity, and you get hearts and a quack.
* Biscuit gives advice in speech bubbles that fits what's happening:
  * where to go next in Act 1
  * to use your light when shadows are near
  * to stay close when you're hurt or panicking
  * to build a base, gather materials, rescue people or Ascend
  * and plenty of just being cute

## Sanity

Sanity runs from 0 to 100, and you'll see its bar in both acts.

* **What drains it:** darkness in Act 1 (less with your flashlight on), being near shadows, being caught by a stalker, and the deeper areas (the Rift, the Cathedral and especially the Heart).
* **What restores it:** Biscuit, the camp fire, your base (more with lamps and rescued survivors), petting Biscuit, Sanity Tonics and rescuing people.
* **What low sanity does:**
  * The screen blurs, loses colour and throbs at the edges, and the camera sways.
  * **Phantom shadows** appear at the edge of your vision and vanish when you look straight at them, and whispers flash on screen.
  * Below 15 the dark starts to hurt you.

## Act 2: the shadow world (action)

You wake up at the survivors' camp in the middle of what's left of Hollow Creek. The bonfire is a safe zone, and you heal fast there. The survivors give you hints, the shrine rerolls your power, and the board shows the Ascension rules.

**A much bigger world.**

* **Hollow Creek** is now about 720 × 760 studs: a 7 × 7 grid of named streets and roughly 150 houses. It's denser in the middle and emptier on the overgrown outskirts. The original was 360 × 360.
* **The Whispering Woods** and **the Sunken Cathedral** stretch about 680 studs north to south. The original was about 300.
* **The Rift** has eight more floating islands to the north and south.
* There are more shadows, rocks and crates to match.
* All the landmarks (camp, bosses, merchants, journal pages, cocoons) are where they were.

**People who live here.** The camp survivors wander around the bonfire. Rescued townsfolk wander inside your base barrier, and merchants stand at their stalls. They're animated on each client:

* a walk cycle that matches their speed, plus breathing
* heads that turn to look at you when you're close
* they stop and turn to face you, and wave the first time you come over
* they gesture while you talk
* survivors warm their hands at the fire, carpenters and blacksmiths hammer, and anyone might look around nervously

They never body-block you.

### Controls

| Action | Keyboard / mouse | Gamepad |
| --- | --- | --- |
| Basic attack (4-hit combo, the 4th hit knocks back) | Left mouse (hold to keep swinging) | R2 |
| Block (hold). Block right as a hit lands to **parry** and stagger the attacker | F | L2 |
| Dodge (i-frames). Dodge through an attack for a **perfect dodge** (+25% damage for a moment) | Q | B |
| Sprint | Shift | L3 |
| Power moves (unlock at levels 1-4) | Z X C V | X, Y, D-pad left/right |
| Awakening + **Ultimate** (level 5) | G | D-pad up |
| Flashlight | L | D-pad down |
| Menu (Ascension, Feats, Power, Tokens, Pack, Build, Base, Journal, Warp, Look) | M | Select |
| Hide / show Biscuit's Tip | H | |
| Build menu / Pack (inventory + crafting) | B / Tab | |
| Use Bandage / Sanity Tonic / Light Bomb | 1 / 2 / 3 | |
| Build mode: place / rotate / stop | Click / R / X | R2 / Y / B |
| Blueprint: add materials / cancel or dismantle | Hold E / hold T | |

On touch devices, ContextActionService adds on-screen buttons for these actions.

### Combat that rewards skill

* **The basic attack is a boxing combo:** a left jab, a right cross, a left hook that sweeps across, and a rising right uppercut that kicks up dust.
  * Each punch snaps out with a streak behind the fist and settles back into a guard.
  * Other players see your torso twist into every punch. Your own view stays steady.
  * Blocking raises a guard, and dodging leans you out of the way.

* **Ultimate.** Activating Awakening (G) now detonates first:
  * everything is pulled in, a pillar of light comes down and the ground erupts
  * 110 damage (scaled by your level and power) to every shadow within 26 studs
  * it carries your power's signature effects plus a big knockback and stun
* **Elemental reactions.** Effects combine with what's already on a shadow:
  * **SHATTER:** burn a frozen or slowed shadow, or freeze a burning one, for a burst of bonus damage
  * **OVERLOAD:** shock a burning shadow (chain or stun) and it explodes, hurting everything around it
  * **CRUSH:** knock back a stunned shadow for bonus damage
* **Flow.** Using a different move than your last one within 4 seconds builds a stack, up to 5 (+6% damage each). Getting hit drops it, and the HUD shows your Flow.

* Every shadow **telegraphs**: its eyes turn red during a wind-up, and big attacks draw a red area on the ground that fills up before it lands.
* Stunning a shadow during its wind-up cancels the attack. Parries stagger it.
* Shadow types: **Shade** (melee), **Lurker** (blinks behind you), **Howler** (keeps its distance and shoots), **Brute** (huge, slams the ground), **Wraith** (fast, lunges).
* Each area has a **boss** with several attack patterns and an enraged second phase at half health: slams, charges, projectile volleys, eruptions under every player, and summoned adds.

### Progression: feats, not XP

There are **no quests and no experience points**. To go from level N to N+1 you need **any one** of that level's qualifying feats. Then you press **Ascend** in the menu.

| To reach | Qualifying feats (earn any one) |
| --- | --- |
| Level 2 | **First Light:** defeat the Hollow Warden · **Untouchable:** defeat 10 shadows in a row without taking damage · **Steady Hand:** parry 5 attacks |
| Level 3 | **Antlers in the Dark:** defeat the Antlered Shade · **Chain Reaction:** defeat 4 shadows within 3 seconds · **Shadowstep:** perfect-dodge 15 attacks · **Good Neighbour:** free 3 townsfolk |
| Level 4 | **Blind Them:** defeat the Many-Eyed · **Giant Slayer:** defeat 3 Brutes without any of their attacks hitting you · **Unbroken:** defeat 40 shadows without dying · **Fortress:** upgrade your base crystal to level 3 |
| Level 5 | **Silence the Choir:** defeat the Choir Below · **Flawless:** defeat any boss without it hitting you · **Last Light:** defeat 100 shadows without dying |

Honours (they don't qualify you for anything): Awakened, Unseen, Duck Parent, Homestead, Full House, Master Builder, Handy, Golden Hour (roll a Legendary), Impossible Dawn (roll a Mythic), Ascendant (reach level 5), Dawn (defeat the Umbral King), Exterminator (500 kills).

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
| Venom | Rare | Basic attacks poison | Toxic Spit, Plague Cloud, Serpent Lunge, Pandemic |
| Blade | Rare | +15% basic damage | Sword Wave, Whirlwind, Phantom Cut, Thousand Swords |
| Storm | Epic | Every 4th hit calls lightning | Chain Lightning, Thunderclap, Tornado, Tempest |
| Hemomancy | Legendary | 8% lifesteal, +10% basic damage | Blood Lance, Crimson Burst, Sanguine Rush, Blood Moon |
| Phantom | Legendary | +10% move speed | Phantom Bolts, Mirror Images (clones fight for you), Blink, Phantom Legion |
| Dawnbringer | Mythic (0.5% shared) | +25% damage, basic attacks heal | Dawn Arrow, Daybreak, Radiant Rush, Second Sun |
| **Necromancer** | Mythic | Fallen shadows have a 25% chance to rise and fight for you | Bone Spear, Raise Dead, Soul Harvest, Army of the Damned |
| Phoenix | Mythic | Rise from a killing blow once every 3 minutes; basic attacks burn | Phoenix Feathers, Flame Wings, Rebirth Flare, Sunfall Dive |
| Void | Mythic | Basic attacks weaken, +15% damage | Void Orb, Phase Shift (invulnerable), Rift Tear, Black Hole |
| **God Speed** | **Transcendent (0.1% shared)** | Move 60% faster, swing 40% faster, afterimages | Flash Step (zip between 5 shadows), Thousand Cuts, Time Blur, Lightspeed Barrage (zip between 14) |
| Chronos | Transcendent | Basic attacks slow time, +20% damage | Time Bolt, Stop (freezes everything), Rewind (back to your health 4 s ago), Time Collapse |
| Celestial | Transcendent | +30% damage | Starfall, Constellation, Nova Star, Supernova |

**Animation and effects.** Every move has a casting animation:
* **Projectiles:** your arm thrusts forward.
* **Novas:** you raise both arms and slam down.
* **Strikes:** you call down with a raised arm.
* **Zones:** both arms go up.
* **Buffs:** your arms spread wide.
* **Summons:** you raise your arms, then slam them down.
* **Dashes:** your arms sweep back.

A charge-up glow flashes in your hand. Each power's element then has its own look:

| Power | Effects |
| --- | --- |
| Fire, Phoenix, Dawnbringer | Embers and flames (Phoenix adds flying feathers) |
| Frost | Ice shards |
| Stone | Rocks that erupt and fly |
| Volt, Storm, God Speed | Forked lightning (God Speed adds afterimages) |
| Radiance, Celestial | Light rays (Celestial adds star bursts) |
| Gravity, Eclipse, Void | Black implosions |
| Venom | Poison clouds |
| Blade, Phantom | Blade slashes |
| Hemomancy | Blood droplets |
| Necromancer | Rising souls and skull projectiles |
| Chronos | Spinning clock rings |

Strikes drop a matching object from the sky: a meteor, a lightning bolt, a sword or a star.

**Rarities:**

| Rarity | Chance |
| --- | --- |
| Common | 42% |
| Uncommon | 30% |
| Rare | 16% |
| Epic | 9% |
| Legendary | 2.4% |
| Mythic | 0.5% |
| Transcendent | 0.1% |

Rolling a Transcendent power gets a rainbow reveal.

Higher rarities also get a flat damage multiplier (x1.0 up to x1.55). All numbers live in `src/shared/` and are meant to be tuned.

---

## The story

The story moves forward as you play. There are still no quests: scenes trigger when you arrive at the camp, ascend, enter a new area, beat a boss or free someone. They play as letterboxed cinematic dialogue with chapter title cards. Nothing can hurt you while a scene is playing.

**Chapters:** The Night Hollow Creek Fell, Embers, Into the Woods, Falling Pieces, The Drowned Choir, The Heart of It, Dawn.

**The mystery.** Three days before noon, Dr. Elias Vance carried a machine called the Lantern into the Whispering Woods. It opened a window onto the shadow world, and something patient and hungry came through. Everyone the shadows touch becomes one of them. Each boss you beat frees a soul and reveals more. The ending is in the Heart of Shadow.

**Journal:** there are 10 journal pages to find across every area: Vance's logs, a postcard from another lost town, and a last note from your parents. They sit on small glowing stands. The **Journal** tab tracks your chapters and pages, and finding every page earns the **Archivist** feat.

## Act 2 is still a horror game

Your power makes you strong, but the shadow world should never feel safe outside the firelight.

* **Darkness.** Outside the camp and your base the world gets much darker and the fog closes in. Set how dark with `Config.Horror.Darkness`, from 0 (off) to 1 (very dark). The camp and your base always keep the normal Act 2 lighting.
* **Flashlight (L).** It lights what you look at, and other players see your head lamp.
* **Fear.** When shadows close in, the edges of the screen darken, your heart pounds and the view trembles.
* **Watchers.** Out in the dark, a figure sometimes stands at the edge of the fog, turning to face you. Look straight at it and it's gone.
* **They come up out of the ground.** New shadows claw their way out of a pool of black ichor, with smoke and a flicker of purple light.
* **The Blackout.** Roughly every 8 to 12 minutes (`Config.Horror.Blackout`):
  * The bell tolls and the street lamps stutter. Then every light dies for 75 seconds and the shadows get faster.
  * Something called **the Hollow** hunts every player who is out in the open. Your powers pass straight through it.
  * It only creeps closer when you look away. Only holding your flashlight on it drives it off.
  * If it reaches you: a jumpscare, 35% of your health and a big sanity hit.
  * The camp and base barriers are safe. It waits at the edge, staring.
  * Spend at least 20 seconds of it out in the open and don't get caught: +60 Essence and the **Lights Out** feat, which qualifies you for level 3. Hiding in the camp the whole time is safe, but earns nothing.

## Realistic effects

Every power keeps its own stylised look, now layered with effects that borrow from how real impacts look (`src/client/VfxKit.luau`):

* **Light:** flashes that light up the surroundings and flicker as they die.
* **Smoke:** smoke lit by the world rather than glowing, which billows, slows and drifts upward. It's dark soot for fire and blasts, and dust the colour of the ground for rock.
* **Debris:** chunks of the actual ground material, thrown up with real physics. Players never collide with them.
* **Sparks and embers:** streaking sparks that fall with gravity, and embers that float up.
* **Marks on the ground:** scorch marks, glowing cracks, frost patches and splatter, which fade after a while.
* **Shockwave dust:** a dust ring that rolls out along the ground.

Shadows bleed black ichor when hit, and come apart into rising ash and smoke when destroyed. Moves you cast give a small camera kick, and big impacts shake the camera by distance.

Performance and quality are set in `Config.Vfx`:

* `Quality` (0.5 halves particles and debris)
* `MaxDebris`
* the particle textures. They default to Roblox's built-in particle textures. I believe those paths exist but haven't confirmed it outside Studio. For even more realistic results, swap in flipbook textures from the Creator Store.

## Merchants

Press E on a merchant to trade Essence for goods:

| Merchant | Where | Sells |
| --- | --- | --- |
| Ollie the Scavenger | Camp | Wood, stone, scrap, cloth, rope, planks, iron bars |
| Doc Mercer | Camp | Bandages, Sanity Tonics, Light Bombs, Duck Bread (feed it to Biscuit for a big sanity boost) |
| The Hooded Stranger | Whispering Woods | Fate Dice (a free reroll), Star Shards (next roll about 3x as likely to be Legendary or better), Light Cores, crystal and umbral shards |

## Tokens and passes

**Tokens** are a second currency. You get them by trading Essence in the menu's **Tokens** tab. The trade is one way: Essence becomes Tokens, never the reverse.

| | Rate |
| --- | --- |
| Newcomer rate (your first 1000 Essence traded) | 2 Essence = 1 Token |
| After that | 4 Essence = 1 Token |
| Welcome gift, the first time you reach the camp | +100 Tokens |

So a new player who trades their first 1000 Essence ends up with 600 Tokens including the gift. That's enough for two or three passes. (These numbers are a first guess and haven't been balance-tested. Change them in `src/shared/Passes.luau`.)

**Passes** are permanent upgrades bought with Tokens. "Suggested Robux" is only a suggestion if you also sell a pass as a Roblox game pass. The real price is whatever you set on the Creator Dashboard.

| Pass | Tokens | Suggested Robux | What it does |
| --- | --- | --- | --- |
| Power Vault | 300 | 349 | **Permanent powers.** Every power you own or roll from then on is kept forever, even ones you replace. Swap between them for free in the Power tab (not mid-fight, once every 15 seconds; move cooldowns carry over). |
| Lucky Star | 400 | 399 | Every roll is 1.5x as likely to be Legendary or better. Stacks with Star Shards. |
| Second Wind | 350 | 249 | Once every 5 minutes, a killing blow leaves you at 30% health with 1.5 s of protection. |
| Fleet Feet | 220 | 149 | Walk and sprint 12% faster in the shadow world. |
| Builder's Belt | 200 | 149 | +50% materials from gathering on average (each hit has a chance of an extra piece). |
| Steady Mind | 180 | 99 | Sanity drains 35% slower. Stacks with the Lantern. |
| Biscuit's Glow | 180 | 99 | Biscuit's sanity/health aura reaches 50% further and works 50% faster. |
| Radiant Aura | 150 | 99 | A light in your power's colour around you, plus sparkles other players see. Looks only, and it can be toggled. |
| Biscuit's Wardrobe | 120 | 79 | Outfits for Biscuit: bow tie, top hat, flower crown, scarf. Looks only. |

There are deliberately no passes that multiply Essence or Tokens, or give merchant discounts. Selling those for Robux would amount to selling the currency.

**Robux.** Essence and Tokens can **never** be bought with Robux. The game has no developer products and no `ProcessReceipt` handler, and nothing sells a currency. Passes are Tokens-only by default. If you also want to sell a pass for Robux:

1. Create a game pass for it on the Creator Dashboard.
2. Paste its id into that pass's `robuxId` in `src/shared/Passes.luau`.

An "or buy with Robux" button then appears. Owning the Roblox game pass unlocks the same in-game pass. Ownership is checked on join with `MarketplaceService:UserOwnsGamePassAsync`, and purchases come in through `PromptGamePassPurchaseFinished`.

## Help for new players

* **Biscuit's Tip** (top-left, H to hide) suggests one useful next thing based on where you are: place your base crystal, Ascend when a feat qualifies you, free townsfolk, trade Essence, spend Tokens. It isn't a quest log and gives no rewards. For your first ten minutes in the camp it also lists the controls.
* **Beginner's Blessing:** you take 30% less damage until you first Ascend to level 2 (`Config.Beginner`).
* The newcomer exchange rate and the welcome Tokens (above).

## Gathering, crafting, building

### Gathering
Hit things with your basic attack to gather from them:

| Source | Material |
| --- | --- |
| Trees | Wood |
| Rocks and rubble | Stone |
| Abandoned cars | Scrap Metal |
| Supply crates | Cloth |
| Rift crystals | Crystal Shards |
| Obsidian in the Heart | Umbral Shards |

Shadows also drop Umbral Shards; bosses drop a lot. Depleted nodes grow back after a minute or two. Crafted tools double or triple what you get.

### Crafting (Pack menu, Tab)
* **Refining:** Planks (needs a Carpenter's Bench and a rescued carpenter), Iron Bars (needs a Forge and a rescued blacksmith), Rope, Light Cores.
* **Tools:** stone and iron axes and pickaxes, and a Salvage Kit.
* **Gear:**
  * Lantern: slower sanity drain
  * Reinforced Coat: 15% less damage taken
  * Shadow Charm: 10% more damage
* **Consumables:** Bandage (heal), Sanity Tonic, Light Bomb (damages and stuns nearby shadows).
* Station recipes need that station **finished in your base** and you standing inside your barrier.

### Your base
1. **Place your Base Crystal** (Build menu, B) **anywhere in any area you've unlocked**: the town, the Woods, the Rift's islands or the Cathedral grounds. Keep it at least 75 studs from the camp and away from boss arenas and area gates.
   * **Houses in the way?** Hold **E** on any house (or Woods cabin) to **demolish** it. It collapses in a cloud of dust and you salvage 12 Wood, 5 Stone and 4 Scrap.
   * Houses you knock down inside or right next to your barrier stay down every time your base loads. Ones demolished elsewhere come back when the server restarts.
   * The crystal raises a **barrier** that:
     * shadows can't stay inside (they're pushed back out)
     * you're safe inside
     * heals you
     * steadies your sanity
2. **Building is only allowed inside your barrier.** **Upgrade the crystal** (Base menu, or press E at the crystal) to grow it:

   | Level | Radius | Upgrade cost |
   | --- | --- | --- |
   | 1 | 24 | Free |
   | 2 | 34 | Wood 30, Stone 30, Scrap 10 |
   | 3 | 46 | Planks 30, Iron 12, Crystal 6 |
   | 4 | 58 | Iron 35, Light Core 3, Umbral 20 |
   | 5 | 72 | Iron 60, Light Core 8, Umbral 50 |

3. **Holographic blueprints:**
   * Pick a structure in the Build menu. A hologram follows your aim, green where it fits and red where it doesn't. It snaps to a grid centred on your crystal, so walls and floors line up.
   * Click to place a blueprint. Placing is free.
   * Walk up and **hold E to pour in materials**. The hologram fills in from the bottom up as you go, and a progress card shows what's still needed.
   * When it's full it becomes a real building. Hold T to cancel a blueprint (full refund) or dismantle a building (half refund).
4. **Structures:**
   * **Walls:** wood, doorway, window, fence, plank (carpenter), stone, metal (blacksmith, crystal level 3)
   * **Floors:** wood and stone floors, ramps
   * **Stations:** Workbench, Carpenter's Bench, Forge
   * **Utility:** Lamp Post (more sanity regen), Campfire (heals), Bed (you respawn at your base)
   * **Defense:** Light Turret (zaps nearby shadows; blacksmith, crystal level 3), Spike Barricade
   * **Decor:** Table, Crate, and a Duck House for Biscuit
5. **Saving:** bases are saved relative to the crystal. If someone has built on your old spot when you come back, place the crystal somewhere new and your whole base moves with it.

### Rescuing townsfolk
Eight people are trapped in **shadow cocoons**, in Hollow Creek, the Woods, the Rift and the Cathedral:

| Person | Role |
| --- | --- |
| Hank Morrow | Carpenter |
| Rosa Delgado | Blacksmith |
| Grandma June | Survivor |
| Marcus Hale | Survivor |
| Tomás Reyes | Carpenter |
| Eli Fischer | Carpenter & Blacksmith |
| Ivy Chen | Blacksmith |
| Old Gus | Carpenter & Blacksmith |

* **Freeing someone:** get close and their guards attack. Defeat them, then hold E to cut the person free.
* **After you free them:** they move into your base, where you can talk to them.
  * Carpenters unlock planks and carpentry buildings.
  * Blacksmiths unlock the forge, iron, metal buildings, turrets and better gear.
  * Every rescued builder makes materials go 10% further in blueprints, up to 30%.
  * Survivors raise sanity regeneration at your base.
* **Feats:**
  * Freeing 3 people earns **Good Neighbour**, a new way to qualify for level 3.
  * Upgrading your crystal to level 3 earns **Fortress**, which qualifies you for level 4.
  * New honours: Duck Parent, Homestead, Full House, Master Builder and Handy.

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
    Materials.luau, Recipes.luau, Structures.luau, Townsfolk.luau
    Passes.luau               Tokens exchange rates and the passes (with optional Robux game pass ids)
    Figure.luau               realistic R6 people: faces, clothes, shoes, hair (players and NPCs)
    Looks.luau                character creator choices, body colours, part-built hairstyles
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
    DuckService.luau          Biscuit: following, petting, nearby bonuses
    SanityService.luau        sanity drain/regen and low-sanity damage
    InventoryService.luau     materials and items
    GatherService.luau        resource nodes
    CraftingService.luau      crafting and consumables
    BaseService.luau          crystal, barrier, blueprints, buildings, saving
    RescueService.luau        cocoons, guards, freeing townsfolk
    PassService.luau          Essence -> Tokens, buying passes, Power Vault, game pass checks
    BlackoutService.luau      the Blackout event and the Hollow
    HouseService.luau         demolishing houses (and keeping your base's plot clear)
    NpcService.luau           survivors, townsfolk and merchants walking around and reacting to you
    LookService.luau          waits for new players to make a character, applies looks
    Projectiles.luau, PlayerData.luau, Registry.luau
  src/client/                 StarterPlayerScripts.Client
    Main.client.luau          entry point
    Horror.luau               flashlight, stamina, heartbeat, subtitles, jumpscares, finale
    RollUI.luau               the roll reel and reveal
    Hud.luau, Menu.luau       Act 2 interface
    CombatInput.luau          controls
    Fx.luau, CameraFx.luau    visual effects
    Atmosphere.luau           lighting per act, flickering lamps, telegraph fills, gates
    ShadowAnimator.luau       procedural animation for shadows (limbs, tendrils, cracks, glitches)
    DuckClient.luau           Biscuit's waddle and advice bubbles
    SanityFx.luau             hallucinations and low-sanity screen effects
    BuildMode.luau            holographic placement
    CharacterCreator.luau     the character creator and its 3D preview
    Guide.luau                Biscuit's Tip and the controls card
    VfxKit.luau               realistic effect building blocks (light, smoke, debris, sparks, marks)
    Dread.luau                Act 2 horror: darkness, flashlight, fear, Watchers, Blackout, jumpscare
    VillagerAnimator.luau     procedural walk/idle/wave/talk/work animation for NPCs
  src/character/Health.server.luau   turns off Roblox's default regen (the server handles it)
```

### Dev tools

In Studio only, the menu has a **Dev** tab: skip Act 1, grant a qualifying feat, +1000 Essence, +500 Tokens, +60 of every material, rescue all townsfolk, reset your data. The server refuses these outside Studio. To remove the tab entirely, set `Config.EnableStudioDevTools = false`.

---

## Status and known limits

* **Not play-tested.** It was written outside Roblox Studio. It passes `luau-lsp` type-checking against the current Roblox API definitions and builds with Rojo, but nobody has run it in Studio yet. Expect some tuning (enemy counts, damage, speeds) and possibly some bugs.
* Shadows walk straight at their target and jump when they get stuck. There's no pathfinding, so they can catch on walls. (In Act 1 that reads as them "phasing" closer when you look away.)
* The wisp particles on shadows use the texture path `rbxasset://textures/particles/smoke_main.dds`. I believe that's one of Roblox's built-in textures but haven't confirmed it. If the wisps don't show up, the classic `Smoke` effect on each shadow still works.
* There's no sound until you add ids in `Config.Sounds`.
* Face features and clothing details are positioned for the default R6 head mesh and body by estimate. If something sits slightly off in Studio, nudge the offsets in `src/shared/Figure.luau`.
* The hairstyles are positioned for the default R6 head (about 1.2 studs across once its mesh is scaled). If a style sits slightly off in Studio, nudge the offsets in `src/shared/Looks.luau`.
* Custom looks spawn with `Player:LoadCharacterWithHumanoidDescriptionAsync`, using only body colours and no clothing assets. I haven't confirmed in Studio that a blank face id gives the default smile. If the face is missing, set `Face` on the description in `LookService.Description`. If the custom spawn fails, the game falls back to the player's normal avatar and prints a warning.
* Robux game passes can't be tested until the place is published and the passes exist. Studio's test purchases should exercise the prompt.
