/* Brick Legends: the story - NPCs, treasure, bosses, chapters and objectives. */
"use strict";

const SKIN = ["#f5cd30", "#ffc9a3", "#d9a066", "#a0693f", "#6b4426"];
function look(skin, torso, legs, o) {
  const s = SKIN[skin] || skin;
  return Object.assign({ head: s, arms: s, torso, legs, face: "smile", hat: "none", shirt: "plain" }, o || {});
}
function npc(map, d) {
  (NPCS[map] = NPCS[map] || []).push(Object.assign({ fx: d.x, fy: d.y, t: 1, dir: "down", home: [d.x, d.y], wander: 0 }, d));
}
function obj(map, d) { (OBJS[map] = OBJS[map] || []).push(d); }
const F = () => G.s.flags;

function newState() {
  return {
    v: 1, party: [newMember("hero", 1)], gold: 60, items: { potion: 3, antidote: 1 }, gear: {},
    flags: {}, quests: {}, known: {}, kills: {}, opened: {},
    map: "brickhaven", x: 25, y: 7, dir: "up", lastInn: { map: "brickhaven", x: 5, y: 7 },
    enc: 18, playTime: 0, wins: 0,
  };
}

function joinParty(id) {
  if (G.s.party.some((m) => m.id === id)) return;
  const lvl = Math.max(hero().level, id === "nova" ? 2 : 6);
  G.s.party.push(newMember(id, lvl));
  syncFollowers();
  Music.sfx("level");
}

// The next story goal, with map pins.
function objective() {
  const f = G.s.flags;
  if (!f.met_elder) return { text: "Talk to Elder Mortar in Brickhaven.", map: "brickhaven", x: 25, y: 6 };
  if (!f.nova) return { text: "Find the mage Nova where the road meets Whisperwood, west of Brickhaven.", map: "world", x: 35, y: 43 };
  if (!f.ch1) return { text: "Defeat the Mossy Treant deep in Whisperwood and recover the Forest Crystal.", map: "world", x: 10, y: 28 };
  if (!f.mira) return { text: "Cross the east bridge and visit the desert town of Sandstone.", map: G.s.map === "sandstone" ? "sandstone" : "world", x: G.s.map === "sandstone" ? 18 : 74, y: G.s.map === "sandstone" ? 12 : 54 };
  if (!f.wyrm) return { text: "Defeat the Sand Wyrm in the ruins east of Sandstone.", map: "world", x: 84, y: 37 };
  if (!f.ch2) return { text: "Take the north pass to Frostpeak, then defeat the Frost Colossus on the summit.", map: "world", x: 84, y: 8 };
  if (!f.cleared) {
    if (G.s.map === "castle") return { text: "Climb to the throne room and defeat the Hollow King.", map: "castle", x: 16, y: 5 };
    return { text: "Cross the north bridge into the Hollow Wastes and storm the Hollow King's castle.", map: "world", x: 27, y: 9 };
  }
  return { text: "Blockara is saved! Finish side quests, find secrets, or keep training.", map: "world", x: 46, y: 58 };
}

// ------------------------------------------------------------------ Brickhaven
function shopkeeper(map, x, y, name, lk, title, stock, hello) {
  npc(map, { x, y, name, look: lk, counter: true, fixedDir: true, talk: async () => { await say(name, hello); await openShop(title, SHOPS[stock]); } });
}
function innkeeper(map, name, lk, price) {
  npc(map, { x: 6, y: 6, name, look: lk, talk: () => innScript(name, price, [5, 7]) });
}

function defineStory() {
  // --- Brickhaven
  npc("brickhaven", {
    x: 25, y: 6, name: "Elder Mortar", look: look(1, "#7c3aed", "#4b5563", { hat: "tophat", hair: "#e5e7eb" }),
    talk: async () => {
      const f = F();
      if (!f.met_elder) return elderIntro();
      if (!f.ch1) return say("Elder Mortar", f.nova ? "Nova is with you? Splendid! The Treant guards the Forest Crystal deep in the northwest of Whisperwood." : "Find Nova at the edge of Whisperwood, west along the road. Rest at the inn if you're hurt!");
      if (!f.ch2) return say("Elder Mortar", "The Forest Crystal's light crumbled the cursed boulder on the east bridge. Seek the other crystals beyond the desert!");
      if (!f.cleared) return say("Elder Mortar", "All three crystals... the shadow on the north bridge is gone. The Hollow King waits in his castle. Be brave, {hero}!");
      return say("Elder Mortar", "Peace has returned to Blockara, all thanks to you, {hero}. The whole village is proud!");
    },
  });
  innkeeper("brickhaven", "Innkeeper Pebble", look(0, "#f97316", "#7c2d12"), 10);
  shopkeeper("brickhaven", 25, 11, "Grocer Tilly", look(1, "#22c55e", "#14532d", { hair: "#7c2d12" }), "Item Shop", "brick_items", "Potions and supplies! Everything an adventurer needs.");
  shopkeeper("brickhaven", 25, 16, "Smith Anvil", look(3, "#57534e", "#292524", { face: "determined" }), "Smithy", "brick_gear", "Fresh from the forge. Have a look!");
  npc("brickhaven", {
    x: 11, y: 16, name: "Farmer Bo", look: look(2, "#ca8a04", "#1e3a8a", { hat: "cap" }), wander: 2,
    talk: async () => {
      const st = G.s.quests.slimes;
      if (!st) {
        await say("Farmer Bo", "Those pesky Green Slimes keep eating my carrots! Could you squash 5 of them out in the plains?");
        startQuest("slimes");
      } else if (questReady("slimes")) {
        await say("Farmer Bo", "You did it! My carrots are safe. Here, take this for your trouble.");
        await completeQuest("slimes");
      } else if (st.state === "done") await say("Farmer Bo", "Not a single slime in my garden since. You're a hero, {hero}!");
      else await say("Farmer Bo", `Squashed ${st.count || 0} of 5 slimes so far. Keep at it!`);
    },
  });
  npc("brickhaven", {
    x: 20, y: 9, name: "Herbalist Lin", look: look(1, "#14b8a6", "#f2f4f5", { hair: "#1f2328", hairLong: true }), wander: 1,
    talk: async () => {
      const st = G.s.quests.herbs;
      if (!st) {
        await say("Herbalist Lin", "I'm brewing a remedy, but I need 3 Glowcaps. They glow blue in the dark corners of Whisperwood. Would you gather some?");
        startQuest("herbs");
      } else if (questReady("herbs")) {
        await say("Herbalist Lin", "Three perfect Glowcaps! This ring was my mentor's. It will sharpen your magic.");
        await completeQuest("herbs");
      } else if (st.state === "done") await say("Herbalist Lin", "My remedy is bubbling nicely. Thank you again!");
      else await say("Herbalist Lin", `You have ${itemCount("glowcap")} of 3 Glowcaps. Look for the blue glow among the trees!`);
    },
  });
  npc("brickhaven", {
    x: 12, y: 7, name: "Grandpa Flint", look: look(1, "#78716c", "#57534e", { hair: "#f8fafc" }),
    talk: () => talk([["Grandpa Flint", "When I was a lad I found a hidden clearing in the far southwest of Whisperwood."],
      ["Grandpa Flint", "One of the trees there was... not a tree at all. Heh heh. Walk right through it, I did!"]]),
  });
  npc("brickhaven", {
    x: 18, y: 15, name: "Little Dot", look: look(0, "#ec4899", "#3b82f6", { face: "grin" }), wander: 3,
    talk: () => say("Little Dot", Kit.pick(["I saw a slime eat a whole brick yesterday!", "Press M to look at the map. That's what Mom says!", "When I grow up I'm gonna be a Legend, just like you!"])),
  });
  npc("brickhaven", {
    x: 17, y: 21, name: "Guard Rocco", look: look(2, "#1e40af", "#1f2328", { hat: "cap", face: "determined" }),
    talk: () => say("Guard Rocco", F().nova ? "Fire works wonders on plant monsters. Ice is good against rats and toads!" : "The plains are fairly safe. But don't head deep into Whisperwood without a friend."),
  });
  // --- Nova at the edge of the forest
  npc("world", {
    x: 35, y: 43, name: "Nova", look: CLASSES.nova.look, cond: () => !F().nova,
    talk: async () => {
      await talk([["Nova", "Hey, you there! Are you from Brickhaven? Did the Elder send you?"],
        ["Nova", "{hero}, is it? I'm Nova, a mage in training. The Forest Crystal is guarded by a huge Mossy Treant deep in these woods."],
        ["Nova", "My spells alone can't take it down... but together we might! Let's team up!"]]);
      joinParty("nova");
      F().nova = true;
      await notice("Nova joined the party!");
      await say("Nova", "Tip: plant monsters hate fire. Pick my Fire spell from the Skills menu in battle. The weakness shows up once you find it!");
    },
  });
  obj("world", { type: "sign", x: 47, y: 56, use: () => notice("North: the Hollow Wastes.  West: Whisperwood.  East: the desert bridge.  South: Brickhaven.") });
  obj("world", { type: "sign", x: 45, y: 23, cond: () => !F().ch2, use: () => notice("A wall of shadow seals the north bridge. Only the light of three crystals could break it.") });

  // treasure
  const chest = (map, id, x, y, extra) => obj(map, Object.assign({ type: "chest", id, x, y, use: openChest }, extra));
  chest("world", "c_fields", 41, 27, { item: "potion", n: 3 });
  chest("world", "c_forest", 24, 40, { gold: 120 });
  chest("world", "c_desert", 89, 60, { item: "hipotion", n: 2 });
  chest("world", "c_snow", 62, 12, { item: "ether", n: 3 });
  chest("world", "c_dark", 10, 8, { item: "feather", n: 2 });
  chest("world", "c_secret", 7, 58, { gear: "legend", after: async () => { badge("secret"); await notice("A legendary blade, hidden for an age. Your hero can equip it from the menu."); } });
  chest("castle", "c_castle1", 5, 21, { item: "megapotion", n: 2 });
  chest("castle", "c_castle2", 27, 21, { item: "elixir", n: 1 });
  const pickup = (map, id, x, y, item, text) => obj(map, {
    type: "pickup", id, x, y, item,
    take: async () => { G.s.opened[id] = true; addItem(item); Kit.sfx("score"); await notice(text()); },
  });
  pickup("world", "g1", 14, 50, "glowcap", () => `Found a Glowcap! (${itemCount("glowcap")}/3)`);
  pickup("world", "g2", 22, 37, "glowcap", () => `Found a Glowcap! (${itemCount("glowcap")}/3)`);
  pickup("world", "g3", 27, 60, "glowcap", () => `Found a Glowcap! (${itemCount("glowcap")}/3)`);
  pickup("world", "pendant", 60, 25, "pendant", () => "Found a Silver Pendant half buried in the snow!");

  // --- mini-bosses
  obj("world", { type: "crystal", x: 10, y: 26, col: "#4ade80", glow: "74,222,128", cond: () => !F().ch1 });
  obj("world", {
    type: "boss", enemy: "treant", x: 10, y: 28, scale: 4.2, cond: () => !F().ch1,
    use: async () => {
      if (!F().nova) { await say(G.heroName, "A giant walking tree, guarding a glowing crystal... I'd better not face it alone."); return; }
      await talk([["Mossy Treant", "Hrrrm... Who disturbs the crystal's slumber? Leave, little bricks, or become mulch!"], ["Nova", "Here we go, {hero}! Fire, fire, fire!"]]);
      const r = await battleFlow(["treant"], { boss: true, bg: "forest" });
      if (r !== "win") return;
      F().ch1 = true;
      addItem("crystal_forest");
      badge("miniboss"); badge("ch1");
      await notice("You recovered the Forest Crystal!");
      await say("Nova", "Look how it glows! Far to the east, I heard something crumble... the cursed boulder on the desert bridge!");
      await chapterCard("Chapter 2", "Sands and Snow");
      await say("Nova", "Let's cross the east bridge and find the town of Sandstone. They say a healer lives there.");
    },
  });
  obj("world", { type: "crystal", x: 84, y: 36, col: "#facc15", glow: "250,204,21", cond: () => !F().wyrm });
  obj("world", {
    type: "boss", enemy: "wyrm", x: 84, y: 37, scale: 4.2, cond: () => !F().wyrm,
    use: async () => {
      await talk([["Sand Wyrm", "SSSSS... The sun crystal is MINE. Your bones will join the sand!"]]);
      const r = await battleFlow(["wyrm"], { boss: true, bg: "desert" });
      if (r !== "win") return;
      F().wyrm = true;
      addItem("crystal_sun");
      badge("miniboss");
      await notice("You recovered the Sun Crystal!");
      await say("Nova", "It's so warm! I bet it melted the ice wall in the north pass. Onward to the peaks!");
    },
  });
  obj("world", { type: "crystal", x: 84, y: 7, col: "#7dd3fc", glow: "125,211,252", cond: () => !F().ch2 });
  obj("world", {
    type: "boss", enemy: "colossus", x: 84, y: 8, scale: 4.4, cond: () => !F().ch2,
    use: async () => {
      await talk([["Frost Colossus", "...INTRUDERS. THE SUMMIT IS SILENT. YOU WILL BE SILENT TOO."], ["Mira", "Stay close, everyone. I'll keep you standing!"]]);
      const r = await battleFlow(["colossus"], { boss: true, bg: "snow" });
      if (r !== "win") return;
      F().golem = true; F().ch2 = true;
      addItem("crystal_frost");
      badge("miniboss"); badge("ch2");
      await notice("You recovered the Frost Crystal! All three crystals shine together...");
      await notice("Far to the west, the wall of shadow on the north bridge shatters!");
      await chapterCard("Chapter 3", "The Hollow King");
      await say("Mira", "The Hollow King's castle lies beyond the north bridge. Let's rest and get ready first.");
    },
  });

  // --- Sandstone
  npc("sandstone", {
    x: 25, y: 6, name: "Chief Dune", look: look(3, "#ea580c", "#7c2d12", { hat: "crown" }),
    talk: () => say("Chief Dune", F().wyrm ? "The Sun Crystal! Our desert breathes easier. Frostpeak lies beyond the north pass." : "Travelers from the west? The Sand Wyrm hoards the Sun Crystal in the ruins east of town. Ice is the only thing it fears."),
  });
  innkeeper("sandstone", "Innkeeper Sahra", look(3, "#0ea5e9", "#f2f4f5", { hair: "#1f2328", hairLong: true }), 25);
  shopkeeper("sandstone", 25, 11, "Trader Kai", look(2, "#facc15", "#1e3a8a", { hat: "cap" }), "Item Shop", "sand_items", "Cool drinks and hot deals!");
  shopkeeper("sandstone", 25, 16, "Smith Rook", look(4, "#57534e", "#1f2328", { face: "determined" }), "Smithy", "sand_gear", "Desert steel. Light, but strong.");
  npc("sandstone", {
    x: 18, y: 12, name: "Mira", look: CLASSES.mira.look, cond: () => !F().mira,
    talk: async () => {
      await talk([["Mira", "You carry the Forest Crystal? Then you must be the heroes the stars spoke of."],
        ["Mira", "I'm Mira, a healer. You'll need someone to patch you up out there. Mind if I come along?"],
        ["Nova", "A healer! Yes, please! {hero} keeps getting knocked flat."]]);
      joinParty("mira");
      F().mira = true;
      await notice("Mira joined the party!");
      await say("Mira", "I can heal, cure poison and sleep, and shield the party. The Sand Wyrm waits in the ruins to the east.");
    },
  });
  npc("sandstone", {
    x: 13, y: 17, name: "Guard Sid", look: look(3, "#b45309", "#1f2328", { hat: "cap", face: "determined" }),
    talk: async () => {
      const st = G.s.quests.scorpions;
      if (!st) { await say("Guard Sid", "Sand Scorpions keep stinging our traders. Defeat 4 of them and I'll reward you well."); startQuest("scorpions"); }
      else if (questReady("scorpions")) { await say("Guard Sid", "The roads are safer already! Take this charm. Poison won't touch you."); await completeQuest("scorpions"); }
      else if (st.state === "done") await say("Guard Sid", "The traders sing songs about you now.");
      else await say("Guard Sid", `${st.count || 0} of 4 scorpions defeated. Watch out for their stingers!`);
    },
  });
  npc("sandstone", { x: 11, y: 9, name: "Old Sandy", look: look(2, "#a16207", "#f2f4f5", { hair: "#f8fafc" }), wander: 2,
    talk: () => say("Old Sandy", "Magma Slimes? Douse them with ice! Fire just makes them stronger.") });
  npc("sandstone", { x: 20, y: 18, name: "Merchant Juno", look: look(1, "#a855f7", "#1f2328", { hat: "tophat" }), wander: 1,
    talk: () => say("Merchant Juno", F().wyrm ? "The ice wall up north melted overnight! Business is booming." : "A wall of ice blocks the north pass. Some say only the Sun Crystal could melt it.") });

  // --- Frostpeak
  npc("frostpeak", {
    x: 25, y: 6, name: "Chief Glacia", look: look(1, "#60a5fa", "#e2e8f0", { hat: "crown", hair: "#f8fafc", hairLong: true }),
    talk: () => say("Chief Glacia", F().ch2 ? "The summit is quiet at last. Go now, heroes, and end the Hollow King's shadow." : "The Frost Colossus guards the last crystal on the summit east of town. Its icy body fears fire."),
  });
  innkeeper("frostpeak", "Innkeeper Bram", look(3, "#dc2626", "#1f2328", { hat: "headphones" }), 50);
  shopkeeper("frostpeak", 25, 11, "Trader Nell", look(1, "#f472b6", "#1e3a8a", { hair: "#facc15", hairLong: true }), "Item Shop", "frost_items", "Warm up with something from my shelf!");
  shopkeeper("frostpeak", 25, 16, "Smith Hale", look(2, "#334155", "#111827", { face: "cool" }), "Smithy", "frost_gear", "The finest gear in Blockara. You'll need it where you're going.");
  npc("frostpeak", {
    x: 12, y: 14, name: "Flurry", look: look(1, "#38bdf8", "#f2f4f5", { hair: "#7c2d12", hairLong: true, face: "wow" }),
    talk: async () => {
      const st = G.s.quests.pendant;
      if (!st) {
        if (itemCount("pendant")) { await say("Flurry", "That's... my grandma's pendant! You found it already? Oh, thank you!"); startQuest("pendant"); await completeQuest("pendant"); return; }
        await say("Flurry", "I lost my grandma's silver pendant in the snowfield west of the pass. Could you look for it?"); startQuest("pendant");
      } else if (questReady("pendant")) { await say("Flurry", "My grandma's pendant! Please, take this star charm. It always brought her luck."); await completeQuest("pendant"); }
      else if (st.state === "done") await say("Flurry", "Grandma cried happy tears. Thank you so much!");
      else await say("Flurry", "It should be somewhere in the snowfield west of the north pass...");
    },
  });
  npc("frostpeak", { x: 19, y: 15, name: "Snowy", look: look(0, "#f8fafc", "#3b82f6", { hat: "cone", face: "grin" }), wander: 3,
    talk: () => say("Snowy", "The Colossus is made of ice. Fire melts ice, right? Right?!") });
  npc("frostpeak", { x: 11, y: 8, name: "Old Hobb", look: look(4, "#4b5563", "#1f2328", { hair: "#e5e7eb" }),
    talk: () => say("Old Hobb", "Thunder rattles bones and armor alike. Remember that in the Hollow King's castle.") });

  // --- the castle
  obj("castle", {
    type: "boss", enemy: "king", x: 16, y: 5, scale: 4.6, cond: () => !F().cleared,
    use: async () => {
      await talk([["The Hollow King", "So, the little brick hero has come at last. And you brought friends. How sweet."],
        ["The Hollow King", "Your shiny crystals mean nothing before the Hollow Crown. I will empty this land of every color!"],
        [G.heroName, "Not while we're standing!"]]);
      const r = await battleFlow(["king"], { boss: true, bg: "castle", final: true });
      if (r === "win") await endingScene();
    },
  });
  MAPS.castle.onEnter = async () => {
    if (!F().castle_seen) { F().castle_seen = true; await say("Nova", "This place gives me the shivers... There's a glowing spring ahead. Let's heal before we face him."); }
  };
}

async function elderIntro() {
  await talk([
    ["Elder Mortar", "Ah, {hero}, you're awake. Something terrible happened last night."],
    ["Elder Mortar", "The Hollow King's shadow swept over Blockara and scattered the three Brick Crystals that keep our land bright."],
    ["Elder Mortar", "Without them, the monsters grow wilder by the hour. The Forest Crystal fell somewhere in Whisperwood, west of here."],
    ["Elder Mortar", "The young mage Nova went ahead to investigate. Please find her and bring back that crystal!"],
    ["Elder Mortar", "Take these potions. Grocer Tilly and Smith Anvil can help you prepare, and the inn will patch you up."],
  ]);
  addItem("potion", 2);
  F().met_elder = true;
  await notice("Received 2 Potions! Press Q (or X) for the menu and M for the map.");
  await chapterCard("Chapter 1", "The Whispering Wood");
}

async function introScene() {
  G.busy = true;
  await notice("Long ago, three Brick Crystals kept the land of Blockara bright and colorful...");
  await notice("But last night, the Hollow King rose from his dark castle and stole their light.");
  await say("Elder Mortar", "{hero}! Over here, please. We must talk.");
  await elderIntro();
  G.busy = false;
}
