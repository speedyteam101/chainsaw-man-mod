/* Brick Legends: game data (classes, skills, items, equipment, enemies, quests). */
"use strict";

const ID = "brick-legends";
const TILE = 32, VW = 960, VH = 576;
const SAVE_KEY = "brick-legends.save.v1";
const FONT = '"Noto Sans", "DejaVu Sans", sans-serif';

const ELEMENTS = ["fire", "ice", "thunder"];
const EL_COLOR = { fire: "#fb923c", ice: "#67e8f9", thunder: "#facc15" };
const EL_NAME = { fire: "Fire", ice: "Ice", thunder: "Thunder" };

// ------------------------------------------------------------------ party
const CLASSES = {
  hero: {
    title: "Hero",
    base: { hp: 50, mp: 10, atk: 9, def: 6, mag: 4, spd: 7 },
    grow: { hp: 9, mp: 2, atk: 2.3, def: 1.6, mag: 0.8, spd: 1.1 },
    skills: [[1, "power"], [4, "flameblade"], [7, "whirl"], [10, "thunderblade"], [14, "herostrike"]],
    start: { weapon: "twig", armor: "tunic", acc: null },
  },
  nova: {
    title: "Mage", name: "Nova",
    look: { head: "#ffc9a3", torso: "#a855f7", arms: "#ffc9a3", legs: "#1e3a8a", face: "wink", hat: "wizard", shirt: "star", hair: "#facc15", hairLong: false },
    base: { hp: 32, mp: 22, atk: 5, def: 4, mag: 10, spd: 8 },
    grow: { hp: 6, mp: 4, atk: 1, def: 1.1, mag: 2.6, spd: 1.2 },
    skills: [[1, "fire"], [1, "ice"], [1, "thunder"], [5, "lullaby"], [8, "inferno"], [10, "blizzard"], [12, "storm"], [16, "meteor"]],
    start: { weapon: "wand", armor: "tunic", acc: null },
  },
  mira: {
    title: "Healer", name: "Mira",
    look: { head: "#a0693f", torso: "#14b8a6", arms: "#a0693f", legs: "#f2f4f5", face: "smile", hat: "none", shirt: "stripes", hair: "#2b1a10", hairLong: true },
    base: { hp: 38, mp: 18, atk: 6, def: 5, mag: 8, spd: 6 },
    grow: { hp: 7, mp: 3.5, atk: 1.2, def: 1.4, mag: 2.0, spd: 0.9 },
    skills: [[1, "heal"], [1, "cure"], [3, "shield"], [6, "revive"], [8, "healall"], [10, "holy"], [13, "shieldall"], [16, "fullheal"]],
    start: { weapon: "staff", armor: "tunic", acc: null },
  },
};
const MEMBER_COLOR = { hero: "#3b82f6", nova: "#a855f7", mira: "#14b8a6" };

function xpNeed(level) { return Math.round(6 + 7 * Math.pow(level, 1.75)); }

// target: enemy | enemies | ally | allies | ko | self
const SKILLS = {
  power:        { name: "Power Strike", mp: 3, target: "enemy", kind: "phys", power: 1.7, desc: "A heavy blow to one enemy." },
  flameblade:   { name: "Flame Blade", mp: 5, target: "enemy", kind: "phys", power: 1.6, el: "fire", desc: "A burning slash. Fire element." },
  whirl:        { name: "Whirlwind", mp: 7, target: "enemies", kind: "phys", power: 1.0, desc: "Spin and strike every enemy." },
  thunderblade: { name: "Thunder Blade", mp: 8, target: "enemy", kind: "phys", power: 2.0, el: "thunder", desc: "A crackling strike. Thunder element." },
  herostrike:   { name: "Legend Strike", mp: 14, target: "enemy", kind: "phys", power: 3.0, desc: "The hero's mightiest attack." },
  fire:     { name: "Fire", mp: 3, target: "enemy", kind: "mag", power: 2.0, el: "fire", desc: "Burn one enemy." },
  ice:      { name: "Ice", mp: 3, target: "enemy", kind: "mag", power: 2.0, el: "ice", desc: "Freeze one enemy." },
  thunder:  { name: "Thunder", mp: 4, target: "enemy", kind: "mag", power: 2.2, el: "thunder", desc: "Strike one enemy with lightning." },
  lullaby:  { name: "Lullaby", mp: 4, target: "enemies", kind: "status", status: "sleep", chance: 0.6, desc: "May put every enemy to sleep." },
  inferno:  { name: "Inferno", mp: 9, target: "enemies", kind: "mag", power: 1.5, el: "fire", desc: "Fire on all enemies." },
  blizzard: { name: "Blizzard", mp: 9, target: "enemies", kind: "mag", power: 1.5, el: "ice", desc: "Ice on all enemies." },
  storm:    { name: "Storm", mp: 10, target: "enemies", kind: "mag", power: 1.6, el: "thunder", desc: "Thunder on all enemies." },
  meteor:   { name: "Meteor", mp: 20, target: "enemies", kind: "mag", power: 2.4, desc: "Rain bricks on every enemy." },
  heal:     { name: "Heal", mp: 3, target: "ally", kind: "heal", power: 2.4, desc: "Restore HP to one ally." },
  cure:     { name: "Cure", mp: 2, target: "ally", kind: "cure", desc: "Remove poison and sleep." },
  shield:   { name: "Shield", mp: 4, target: "ally", kind: "shield", desc: "Halve damage to one ally for 3 turns." },
  revive:   { name: "Revive", mp: 8, target: "ko", kind: "revive", desc: "Revive a fallen ally with half HP." },
  healall:  { name: "Heal All", mp: 9, target: "allies", kind: "heal", power: 1.6, desc: "Restore HP to the whole party." },
  holy:     { name: "Holy Light", mp: 6, target: "enemy", kind: "mag", power: 2.4, desc: "Blinding light hits one enemy." },
  shieldall:{ name: "Shield All", mp: 10, target: "allies", kind: "shield", desc: "Shield the whole party." },
  fullheal: { name: "Full Heal", mp: 14, target: "ally", kind: "heal", power: 99, desc: "Fully restore one ally." },
};

// ------------------------------------------------------------------ items
// use: heal | mp | cure | revive | elixir | bomb ; key items can't be used
const ITEMS = {
  potion:    { name: "Potion", price: 12, use: "heal", amt: 50, desc: "Restores 50 HP to one ally." },
  hipotion:  { name: "Hi-Potion", price: 45, use: "heal", amt: 150, desc: "Restores 150 HP to one ally." },
  megapotion:{ name: "Mega Potion", price: 120, use: "heal", amt: 400, desc: "Restores 400 HP to one ally." },
  ether:     { name: "Ether", price: 40, use: "mp", amt: 25, desc: "Restores 25 MP to one ally." },
  antidote:  { name: "Antidote", price: 8, use: "cure", status: ["poison"], desc: "Cures poison (battle only)." },
  bell:      { name: "Wake Bell", price: 10, use: "cure", status: ["sleep"], desc: "Wakes a sleeping ally (battle only)." },
  remedy:    { name: "Remedy", price: 30, use: "cure", status: ["poison", "sleep"], desc: "Cures poison and sleep (battle only)." },
  feather:   { name: "Phoenix Feather", price: 150, use: "revive", desc: "Revives a fallen ally with half HP." },
  elixir:    { name: "Elixir", price: 0, use: "elixir", desc: "Fully restores HP and MP of one ally." },
  firebomb:  { name: "Fire Bomb", price: 25, use: "bomb", el: "fire", amt: 35, desc: "Fire damage to all enemies (battle only)." },
  icebomb:   { name: "Ice Bomb", price: 50, use: "bomb", el: "ice", amt: 80, desc: "Ice damage to all enemies (battle only)." },
  boltbomb:  { name: "Thunder Bomb", price: 50, use: "bomb", el: "thunder", amt: 80, desc: "Thunder damage to all enemies (battle only)." },
  glowcap:   { name: "Glowcap", key: true, desc: "A softly glowing mushroom from Whisperwood." },
  pendant:   { name: "Silver Pendant", key: true, desc: "A pendant with a snowflake engraving." },
  crystal_forest: { name: "Forest Crystal", key: true, desc: "A green crystal humming with life." },
  crystal_sun:    { name: "Sun Crystal", key: true, desc: "A golden crystal, warm to the touch." },
  crystal_frost:  { name: "Frost Crystal", key: true, desc: "A pale blue crystal that never melts." },
};

const EQUIP = {
  twig:       { name: "Twig Sword", slot: "weapon", for: ["hero"], atk: 2, price: 0 },
  oaksword:   { name: "Oak Sword", slot: "weapon", for: ["hero"], atk: 6, price: 45 },
  ironsword:  { name: "Iron Sword", slot: "weapon", for: ["hero"], atk: 11, price: 170 },
  steelsword: { name: "Steel Sword", slot: "weapon", for: ["hero"], atk: 18, price: 520 },
  frostbrand: { name: "Frost Brand", slot: "weapon", for: ["hero"], atk: 28, price: 1200 },
  legend:     { name: "Legend Blade", slot: "weapon", for: ["hero"], atk: 40, spd: 6, price: 0 },
  wand:       { name: "Apprentice Wand", slot: "weapon", for: ["nova", "mira"], atk: 1, mag: 3, price: 0 },
  staff:      { name: "Oak Staff", slot: "weapon", for: ["nova", "mira"], atk: 3, mag: 2, price: 0 },
  runestaff:  { name: "Rune Staff", slot: "weapon", for: ["nova", "mira"], atk: 3, mag: 8, price: 160 },
  sunrod:     { name: "Sun Rod", slot: "weapon", for: ["nova", "mira"], atk: 5, mag: 15, price: 480 },
  crystalrod: { name: "Crystal Rod", slot: "weapon", for: ["nova", "mira"], atk: 7, mag: 24, price: 1150 },
  tunic:      { name: "Cloth Tunic", slot: "armor", def: 1, price: 0 },
  leather:    { name: "Leather Vest", slot: "armor", def: 4, price: 50 },
  chain:      { name: "Chain Mail", slot: "armor", for: ["hero"], def: 11, price: 450 },
  silkrobe:   { name: "Silk Robe", slot: "armor", for: ["nova", "mira"], def: 7, mag: 4, price: 400 },
  knightplate:{ name: "Knight Plate", slot: "armor", for: ["hero"], def: 19, price: 1100 },
  sagerobe:   { name: "Sage Robe", slot: "armor", for: ["nova", "mira"], def: 13, mag: 8, price: 1050 },
  swiftring:  { name: "Swift Ring", slot: "acc", spd: 4, price: 120 },
  powerband:  { name: "Power Band", slot: "acc", atk: 6, price: 300 },
  vipercharm: { name: "Viper Charm", slot: "acc", def: 2, immune: ["poison"], price: 320 },
  alertcharm: { name: "Alert Charm", slot: "acc", def: 2, immune: ["sleep"], price: 380 },
  glowring:   { name: "Glow Ring", slot: "acc", mag: 5, mp: 10, price: 0 },
  starpendant:{ name: "Star Pendant", slot: "acc", atk: 4, def: 4, mag: 4, spd: 4, price: 0 },
};
const SLOT_NAME = { weapon: "Weapon", armor: "Armor", acc: "Accessory" };

const SHOPS = {
  brick_items: ["potion", "antidote", "bell", "firebomb"],
  brick_gear: ["oaksword", "ironsword", "runestaff", "leather", "swiftring"],
  sand_items: ["potion", "hipotion", "ether", "antidote", "bell", "feather", "icebomb", "boltbomb"],
  sand_gear: ["steelsword", "sunrod", "chain", "silkrobe", "powerband", "vipercharm"],
  frost_items: ["hipotion", "megapotion", "ether", "remedy", "feather", "firebomb", "boltbomb"],
  frost_gear: ["frostbrand", "crystalrod", "knightplate", "sagerobe", "alertcharm"],
};

// ------------------------------------------------------------------ enemies
// art: drawing routine in art.js; col: palette. big: takes more room in battle.
const ENEMIES = {
  slime:     { name: "Green Slime", art: "slime", col: ["#4ade80", "#15803d"], hp: 16, atk: 5, def: 2, mag: 2, spd: 4, xp: 5, gold: 4, weak: ["fire"], drops: [["potion", 0.12]] },
  bat:       { name: "Buzz Bat", art: "bat", col: ["#7c5cbf", "#3b2a5a"], hp: 12, atk: 5, def: 1, mag: 2, spd: 12, xp: 6, gold: 5, weak: ["thunder"], drops: [["antidote", 0.1]] },
  rat:       { name: "Brick Rat", art: "rat", col: ["#b7791f", "#713f12"], hp: 20, atk: 6, def: 3, mag: 1, spd: 8, xp: 7, gold: 7, weak: ["ice"], drops: [["potion", 0.1]] },
  shroom:    { name: "Shroomling", art: "shroom", col: ["#ef4444", "#fde68a"], hp: 22, atk: 5, def: 4, mag: 6, spd: 3, xp: 9, gold: 7, weak: ["fire"], skills: [["spores", 2]], drops: [["bell", 0.15]] },
  toad:      { name: "Venom Toad", art: "toad", col: ["#84cc16", "#3f6212"], hp: 40, atk: 12, def: 6, mag: 6, spd: 6, xp: 15, gold: 11, weak: ["ice"], skills: [["spit", 2]], drops: [["antidote", 0.2]] },
  wolf:      { name: "Timber Wolf", art: "wolf", col: ["#8a817c", "#44403c"], hp: 46, atk: 13, def: 6, mag: 2, spd: 14, xp: 17, gold: 12, weak: ["fire"], skills: [["bite", 1]], drops: [["potion", 0.15]] },
  sprite:    { name: "Thorn Sprite", art: "sprite", col: ["#22c55e", "#ec4899"], hp: 36, atk: 10, def: 5, mag: 12, spd: 10, xp: 16, gold: 12, weak: ["fire"], resist: ["thunder"], skills: [["leafstorm", 2]], drops: [["ether", 0.06]] },
  scorpion:  { name: "Sand Scorpion", art: "scorpion", col: ["#d97706", "#92400e"], hp: 85, atk: 22, def: 14, mag: 6, spd: 11, xp: 32, gold: 22, weak: ["ice"], skills: [["sting", 2]], drops: [["antidote", 0.2]] },
  cactus:    { name: "Cactus Brute", art: "cactus", col: ["#65a30d", "#365314"], hp: 100, atk: 23, def: 12, mag: 8, spd: 6, xp: 35, gold: 24, weak: ["fire"], skills: [["needles", 2]], drops: [["hipotion", 0.08]] },
  mummy:     { name: "Brick Mummy", art: "mummy", col: ["#e7e5e4", "#a8a29e"], hp: 95, atk: 20, def: 10, mag: 18, spd: 5, xp: 37, gold: 26, weak: ["fire"], resist: ["ice"], skills: [["wrap", 2]], drops: [["bell", 0.2]] },
  magma:     { name: "Magma Slime", art: "slime", col: ["#f97316", "#b91c1c"], hp: 75, atk: 18, def: 10, mag: 22, spd: 8, xp: 31, gold: 28, weak: ["ice"], resist: ["fire"], skills: [["fireball", 2]], drops: [["firebomb", 0.2]] },
  frostslime:{ name: "Frost Slime", art: "slime", col: ["#7dd3fc", "#0369a1"], hp: 125, atk: 31, def: 18, mag: 30, spd: 9, xp: 60, gold: 40, weak: ["fire"], resist: ["ice"], skills: [["iceshard", 2]], drops: [["ether", 0.1]] },
  snowwolf:  { name: "Snow Wolf", art: "wolf", col: ["#f1f5f9", "#64748b"], hp: 145, atk: 39, def: 18, mag: 4, spd: 17, xp: 66, gold: 42, weak: ["fire"], skills: [["bite", 1]], drops: [["hipotion", 0.12]] },
  frostbat:  { name: "Frost Bat", art: "bat", col: ["#38bdf8", "#1e40af"], hp: 105, atk: 35, def: 14, mag: 20, spd: 19, xp: 58, gold: 38, weak: ["thunder"], resist: ["ice"], skills: [["chill", 1]], drops: [["remedy", 0.1]] },
  yeti:      { name: "Yeti", art: "yeti", col: ["#f8fafc", "#60a5fa"], hp: 230, atk: 46, def: 22, mag: 10, spd: 7, xp: 92, gold: 60, weak: ["fire"], resist: ["ice"], big: true, skills: [["avalanche", 1]], drops: [["megapotion", 0.08]] },
  skeleton:  { name: "Skeleton", art: "skeleton", col: ["#f5f5f4", "#a8a29e"], hp: 200, atk: 54, def: 28, mag: 10, spd: 12, xp: 112, gold: 62, weak: ["thunder"], skills: [["bonecrush", 1]], drops: [["hipotion", 0.15]] },
  knight:    { name: "Dark Knight", art: "knight", col: ["#3b4a63", "#111827"], hp: 270, atk: 62, def: 40, mag: 20, spd: 10, xp: 142, gold: 82, weak: ["thunder"], skills: [["darkslash", 1]], drops: [["megapotion", 0.08]] },
  wraith:    { name: "Wraith", art: "wraith", col: ["#6d28d9", "#1e1b4b"], hp: 180, atk: 40, def: 20, mag: 56, spd: 15, xp: 122, gold: 70, weak: ["fire"], resist: ["ice"], skills: [["drain", 2], ["hex", 1]], drops: [["ether", 0.15]] },
  golem:     { name: "Stone Golem", art: "golem", col: ["#8b8580", "#57534e", "#fbbf24"], hp: 350, atk: 64, def: 56, mag: 10, spd: 4, xp: 165, gold: 92, weak: ["ice"], resist: ["fire"], big: true, skills: [["quake", 1]], drops: [["elixir", 0.05]] },
  drake:     { name: "Ember Drake", art: "dragon", col: ["#dc2626", "#7f1d1d", "#fbbf24"], hp: 310, atk: 58, def: 34, mag: 60, spd: 14, xp: 175, gold: 100, weak: ["ice"], resist: ["fire"], big: true, skills: [["firebreath", 1]], drops: [["firebomb", 0.3]] },
  gargoyle:  { name: "Gargoyle", art: "gargoyle", col: ["#7b8798", "#3f4a5c"], hp: 270, atk: 58, def: 44, mag: 30, spd: 13, xp: 155, gold: 90, weak: ["thunder"], resist: ["ice"], skills: [["dive", 1]], drops: [["remedy", 0.15]] },
  // mini-bosses and the final boss
  treant:    { name: "Mossy Treant", art: "treant", col: ["#7c4a1e", "#2f8a3e"], hp: 460, atk: 20, def: 10, mag: 18, spd: 6, xp: 220, gold: 200, weak: ["fire"], resist: ["thunder"], boss: true, ai: "treant", drops: [["ether", 1]] },
  wyrm:      { name: "Sand Wyrm", art: "wyrm", col: ["#d6a756", "#8a5a1b"], hp: 1500, atk: 40, def: 22, mag: 34, spd: 12, xp: 700, gold: 450, weak: ["ice"], resist: ["fire"], boss: true, ai: "wyrm", drops: [["megapotion", 1]] },
  colossus:  { name: "Frost Colossus", art: "golem", col: ["#bae6fd", "#38bdf8", "#e0f2fe"], hp: 2500, atk: 58, def: 34, mag: 46, spd: 8, xp: 1300, gold: 800, weak: ["fire"], resist: ["ice"], boss: true, ai: "colossus", drops: [["elixir", 1]] },
  king:      { name: "The Hollow King", art: "king", col: ["#1e1b4b", "#7c3aed", "#facc15"], hp: 2800, atk: 70, def: 44, mag: 70, spd: 15, xp: 0, gold: 0, weak: [], boss: true, ai: "king" },
  king2:     { name: "Hollow King Unbound", art: "dragon", col: ["#5b21b6", "#2e1065", "#f0abfc"], hp: 3400, atk: 86, def: 46, mag: 82, spd: 18, xp: 3000, gold: 2000, weak: ["thunder"], boss: true, ai: "king2", crown: true },
};

const ESKILLS = {
  spores:     { name: "Sleep Spores", type: "status", status: "sleep", chance: 0.45, fx: "spores" },
  spit:       { name: "Poison Spit", type: "phys", power: 0.8, status: "poison", chance: 0.6 },
  bite:       { name: "Savage Bite", type: "phys", power: 1.4 },
  leafstorm:  { name: "Leaf Storm", type: "mag", power: 0.9, all: true, fx: "leaf" },
  sting:      { name: "Poison Sting", type: "phys", power: 1.0, status: "poison", chance: 0.5 },
  needles:    { name: "Needle Spray", type: "phys", power: 0.7, all: true },
  wrap:       { name: "Curse Wrap", type: "status", status: "sleep", chance: 0.5 },
  fireball:   { name: "Fireball", type: "mag", power: 1.3, el: "fire" },
  iceshard:   { name: "Ice Shard", type: "mag", power: 1.3, el: "ice" },
  chill:      { name: "Chill Bite", type: "phys", power: 1.2, el: "ice" },
  avalanche:  { name: "Avalanche", type: "phys", power: 0.8, all: true },
  bonecrush:  { name: "Bone Crush", type: "phys", power: 1.5 },
  darkslash:  { name: "Dark Slash", type: "phys", power: 1.6 },
  drain:      { name: "Soul Drain", type: "mag", power: 1.0, drain: true },
  hex:        { name: "Hex", type: "status", status: "sleep", chance: 0.4 },
  quake:      { name: "Quake", type: "phys", power: 0.9, all: true },
  firebreath: { name: "Fire Breath", type: "mag", power: 1.0, el: "fire", all: true },
  dive:       { name: "Stone Dive", type: "phys", power: 1.4 },
  rootbind:   { name: "Root Bind", type: "status", status: "sleep", chance: 0.6 },
  sporecloud: { name: "Spore Cloud", type: "status", status: "poison", chance: 0.6, all: true, fx: "spores" },
  photosynth: { name: "Photosynthesis", type: "healself", amt: 0.15 },
  sandstorm:  { name: "Sandstorm", type: "mag", power: 0.9, all: true, fx: "sand" },
  burrow:     { name: "Burrow", type: "shieldself" },
  tailwhip:   { name: "Tail Whip", type: "phys", power: 1.5 },
  frostbreath:{ name: "Blizzard Breath", type: "mag", power: 1.0, el: "ice", all: true },
  frostfist:  { name: "Frost Fist", type: "phys", power: 1.7 },
  freeze:     { name: "Deep Freeze", type: "status", status: "sleep", chance: 0.5 },
  shadowbolt: { name: "Shadow Bolt", type: "mag", power: 1.6, fx: "dark" },
  darkwave:   { name: "Dark Wave", type: "mag", power: 1.0, all: true, fx: "dark" },
  curse:      { name: "Hollow Curse", type: "status", status: "poison", chance: 0.7, all: true, fx: "dark" },
  voidbreath: { name: "Void Breath", type: "mag", power: 1.2, all: true, fx: "dark" },
  crush:      { name: "Crushing Claw", type: "phys", power: 1.9 },
};

// Random encounter pools per region.
const ENCOUNTERS = {
  fields: { pool: ["slime", "slime", "bat", "rat", "shroom"], min: 1, max: 2, max3: 0.15, bg: "fields" },
  forest: { pool: ["toad", "wolf", "sprite", "shroom", "bat"], min: 1, max: 3, bg: "forest" },
  desert: { pool: ["scorpion", "cactus", "mummy", "magma"], min: 1, max: 3, bg: "desert" },
  snow:   { pool: ["frostslime", "snowwolf", "frostbat", "yeti"], min: 1, max: 3, bg: "snow" },
  dark:   { pool: ["skeleton", "knight", "wraith", "golem", "drake"], min: 1, max: 3, bg: "dark" },
  castle: { pool: ["skeleton", "knight", "wraith", "gargoyle", "drake"], min: 2, max: 3, bg: "castle" },
};

const QUESTS = {
  slimes:  { name: "Slime Trouble", giver: "Farmer Bo, Brickhaven", desc: "Defeat 5 Green Slimes in the plains.", type: "kill", target: "slime", need: 5, reward: { gold: 100, items: { potion: 3 } } },
  herbs:   { name: "Glowcap Gathering", giver: "Herbalist Lin, Brickhaven", desc: "Find 3 Glowcaps hidden in Whisperwood.", type: "fetch", item: "glowcap", need: 3, reward: { gold: 60, items: { ether: 2 }, equip: "glowring" } },
  scorpions:{ name: "Scorpion Hunt", giver: "Guard Sid, Sandstone", desc: "Defeat 4 Sand Scorpions in the desert.", type: "kill", target: "scorpion", need: 4, reward: { gold: 300, equip: "vipercharm" } },
  pendant: { name: "The Lost Pendant", giver: "Flurry, Frostpeak", desc: "Find the Silver Pendant in the snowfield west of the pass.", type: "fetch", item: "pendant", need: 1, reward: { gold: 250, equip: "starpendant" } },
};

const BADGES = {
  first_win: ["First Victory", "Win your first battle."],
  miniboss: ["Giant Slayer", "Defeat a mini-boss."],
  ch1: ["Chapter 1 Cleared", "Recover the Forest Crystal."],
  ch2: ["Chapter 2 Cleared", "Recover the Sun and Frost Crystals."],
  final: ["Legend of Blockara", "Defeat the Hollow King."],
  level10: ["Seasoned Hero", "Reach level 10."],
  secret: ["Secret Keeper", "Find the hidden clearing in Whisperwood."],
  helper: ["Helping Hand", "Complete all four side quests."],
};
function badge(id) {
  const b = BADGES[id];
  if (b) Kit.badge(ID, id, b[0], b[1]);
}
