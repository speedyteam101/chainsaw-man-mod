// Dungeon Quest: game data (dungeons, monsters, loot tables, progression). No three.js here.

export const GAME_ID = "dungeon-quest";
export const SAVE_KEY = "dungeon-quest.save.v1";
export const MAX_LEVEL = 30;
export const MAX_UPGRADE = 10;
export const INV_SIZE = 30;

// Small seeded random generator (mulberry32) so every player in a room builds the same dungeon.
export function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export const RARITIES = [
  { name: "Common", color: "#c9d1d9", mult: 1, sell: 1 },
  { name: "Rare", color: "#3b9cff", mult: 1.35, sell: 2.5 },
  { name: "Epic", color: "#b65cff", mult: 1.8, sell: 6 },
  { name: "Legendary", color: "#ffb020", mult: 2.4, sell: 15 },
];

export const DUNGEONS = [
  {
    id: "mossy-crypt", name: "Mossy Crypt", tier: 1, rec: 1, rooms: 4,
    floor: "#3d4834", floor2: "#4d5b41", wall: "#86917c", trim: "#2f3a28", accent: "#84cc16", hazard: "#4d7c0f", gate: "#a3e635", torch: "#bef264",
    sky: "#0b120a", hemiSky: 0xc8e6b4, hemiGround: 0x3a4a30, sun: 0xdcefc4,
    enemies: ["zombie", "bonecaster", "mossbrute"], boss: "rotking",
    blurb: "Shambling zombies and bone casters haunt these damp halls.",
  },
  {
    id: "lava-forge", name: "Lava Forge", tier: 2, rec: 4, rooms: 5,
    floor: "#2e2522", floor2: "#3d312c", wall: "#7a5d52", trim: "#211916", accent: "#f97316", hazard: "#ea580c", gate: "#fb923c", torch: "#fdba74",
    sky: "#170805", hemiSky: 0xffc9a8, hemiGround: 0x5a2a18, sun: 0xffd0a0,
    enemies: ["imp", "pyromancer", "golem"], boss: "forgelord",
    blurb: "Fire imps and magma golems guard the ancient forge.",
  },
  {
    id: "frost-keep", name: "Frost Keep", tier: 3, rec: 8, rooms: 6,
    floor: "#6f86a0", floor2: "#8197b0", wall: "#dbe7f3", trim: "#4f6884", accent: "#38bdf8", hazard: "#7dd3fc", gate: "#67e8f9", torch: "#a5f3fc",
    sky: "#08101c", hemiSky: 0xd6ecff, hemiGround: 0x2a3f5a, sun: 0xe0f0ff,
    enemies: ["ghoul", "frostmage", "yeti"], boss: "frostqueen",
    blurb: "Ice ghouls, frost mages and yetis serve the Frost Queen.",
  },
];

// Role templates: base stats at tier 1.
export const ROLES = {
  rusher: { hp: 34, dmg: 7, speed: 11.5, xp: 10, gold: 3, radius: 1.3, drop: 0.07 },
  caster: { hp: 26, dmg: 9, speed: 9, xp: 13, gold: 4, radius: 1.3, drop: 0.08 },
  brute: { hp: 115, dmg: 16, speed: 7, xp: 28, gold: 9, radius: 2.1, drop: 0.16 },
  boss: { hp: 620, dmg: 18, speed: 8, xp: 220, gold: 120, radius: 4.2, drop: 1 },
};

export const TIER_MULT = {
  hp: [1, 3, 7],
  dmg: [1, 2.3, 4.6],
  xp: [1, 2.6, 5.5],
  gold: [1, 2.5, 5],
};

// look: skin (head + arms), torso, legs, eyes (glowing), extras
export const ENEMIES = {
  zombie: { role: "rusher", name: "Crypt Zombie", skin: "#7fb069", torso: "#4b5d3a", legs: "#3b3f2f", eyes: "#facc15", scale: 1 },
  bonecaster: { role: "caster", name: "Bone Caster", skin: "#e7e2d0", torso: "#cfc8b0", legs: "#bdb59b", eyes: "#84cc16", hood: "#3f4a2c", weapon: "staff", orb: "#a3e635", scale: 1 },
  mossbrute: { role: "brute", name: "Moss Brute", skin: "#5d7a45", torso: "#3d4f2e", legs: "#2f3a24", eyes: "#facc15", weapon: "club", scale: 1.6 },
  rotking: { role: "boss", name: "The Rot King", skin: "#6b8f4e", torso: "#3f6212", legs: "#2b3a1c", eyes: "#facc15", crown: "#eab308", weapon: "club", orb: "#a3e635", scale: 2.7 },

  imp: { role: "rusher", name: "Fire Imp", skin: "#ef4444", torso: "#7f1d1d", legs: "#450a0a", eyes: "#fde047", horns: "#1c1917", scale: 0.9 },
  pyromancer: { role: "caster", name: "Pyromancer", skin: "#f5c6a5", torso: "#9a3412", legs: "#431407", eyes: "#fb923c", hood: "#7c2d12", weapon: "staff", orb: "#fb923c", scale: 1 },
  golem: { role: "brute", name: "Magma Golem", skin: "#44403c", torso: "#292524", legs: "#1c1917", eyes: "#f97316", cracks: "#f97316", scale: 1.75 },
  forgelord: { role: "boss", name: "The Forge Lord", skin: "#292524", torso: "#7c2d12", legs: "#1c1917", eyes: "#fb923c", horns: "#fbbf24", cracks: "#f97316", weapon: "hammer", orb: "#f97316", scale: 2.8 },

  ghoul: { role: "rusher", name: "Ice Ghoul", skin: "#bfdbfe", torso: "#1e3a8a", legs: "#172554", eyes: "#22d3ee", scale: 1 },
  frostmage: { role: "caster", name: "Frost Mage", skin: "#e0f2fe", torso: "#1d4ed8", legs: "#1e3a8a", eyes: "#67e8f9", wizard: "#1e40af", weapon: "staff", orb: "#67e8f9", scale: 1 },
  yeti: { role: "brute", name: "Yeti", skin: "#f1f5f9", torso: "#e2e8f0", legs: "#cbd5e1", eyes: "#0ea5e9", horns: "#94a3b8", scale: 1.85 },
  frostqueen: { role: "boss", name: "The Frost Queen", skin: "#e0f2fe", torso: "#0284c7", legs: "#075985", eyes: "#a5f3fc", crown: "#a5f3fc", weapon: "staff", orb: "#a5f3fc", scale: 2.7 },
};
export const ENEMY_TYPES = Object.keys(ENEMIES);

export function enemyStats(type, tier, players) {
  const d = ENEMIES[type];
  const r = ROLES[d.role];
  const t = tier - 1;
  const crowd = 1 + 0.5 * Math.max(0, (players || 1) - 1);
  return {
    hp: Math.round(r.hp * TIER_MULT.hp[t] * crowd),
    dmg: r.dmg * TIER_MULT.dmg[t],
    speed: r.speed * (d.role === "rusher" && type === "imp" ? 1.12 : 1),
    xp: Math.round(r.xp * TIER_MULT.xp[t]),
    gold: Math.round(r.gold * TIER_MULT.gold[t]),
    radius: r.radius * (d.scale > 1.2 && d.role !== "boss" ? 1 : 1),
    drop: r.drop,
  };
}

// ------------------------------------------------------------------ progression

export function xpToNext(level) { return Math.round(40 * Math.pow(level, 1.6)); }

export const ABILITIES = [
  { key: "KeyQ", label: "Q", name: "Spin", level: 2, cd: 6, color: "#f59e0b", desc: "Whirlwind: hit everything around you for 160% damage." },
  { key: "KeyE", label: "E", name: "Dash", level: 3, cd: 7, color: "#38bdf8", desc: "Dash Strike: dash forward, slicing through enemies for 220% damage." },
  { key: "KeyR", label: "R", name: "Heal", level: 5, cd: 18, color: "#22c55e", desc: "Healing Burst: heal you and nearby allies, and blast enemies back." },
];

export const POTIONS = [
  { key: "Digit1", label: "1", name: "Health Potion", short: "Potion", price: 20, color: "#ef4444", desc: "Restores 45% of your health." },
  { key: "Digit2", label: "2", name: "Strength Tonic", short: "Tonic", price: 45, color: "#a855f7", desc: "+50% damage for 12 seconds." },
];

export function playerStats(save) {
  const w = save.eq.weapon, a = save.eq.armor;
  const kind = WEAPON_KINDS[(w && w.kind) || "sword"];
  const up = (it) => (it ? 1 + 0.1 * (it.upg || 0) : 1);
  const lv = save.lv;
  return {
    atk: Math.round((6 + 2 * (lv - 1) + (w ? w.dmg * up(w) : 0)) * kind.mult),
    hp: Math.round(100 + 14 * (lv - 1) + (a ? a.hp * up(a) : 0)),
    def: Math.round(a ? a.def * up(a) : 0),
    crit: (w && w.crit) || 0,
    swing: kind.speed,
    arc: kind.arc,
    range: kind.range,
    kind: (w && w.kind) || "sword",
  };
}

// ------------------------------------------------------------------ items

export const WEAPON_KINDS = {
  sword: { speed: 0.42, mult: 1, arc: 1.1, range: 7.6, label: "Sword" },
  axe: { speed: 0.55, mult: 1.22, arc: 1.2, range: 7.8, label: "Axe" },
  hammer: { speed: 0.7, mult: 1.5, arc: 1.45, range: 8.6, label: "Hammer" },
};

const THEME = ["Mossy", "Ember", "Frost"];
const WEAPON_BASES = [["Blade", "sword"], ["Saber", "sword"], ["Axe", "axe"], ["Cleaver", "axe"], ["Maul", "hammer"], ["Hammer", "hammer"]];
const ARMOR_BASES = ["Mail", "Plate", "Vest", "Guard", "Cuirass"];
const WORDS = [["Worn", "Plain", "Old", "Simple"], ["Fine", "Keen", "Sturdy", "Polished"], ["Runed", "Savage", "Gleaming", "Shadow"], ["Ancient", "Mythic", "Radiant", "Celestial"]];
const WEAPON_BASE_DMG = [7, 18, 34];
const ARMOR_BASE_HP = [22, 58, 110];
const ARMOR_BASE_DEF = [3, 8, 15];

let idCounter = 0;
function newId() { return Date.now().toString(36) + (idCounter++).toString(36) + Math.floor(Math.random() * 1e4).toString(36); }

export function makeItem(slot, tier, rarity, R) {
  R = R || Math.random;
  const pick = (arr) => arr[Math.floor(R() * arr.length)];
  const r = RARITIES[rarity];
  const roll = () => 0.9 + R() * 0.2;
  const word = pick(WORDS[rarity]);
  if (slot === "weapon") {
    const [base, kind] = pick(WEAPON_BASES);
    return {
      id: newId(), slot, kind, tier, rar: rarity, upg: 0,
      name: `${word} ${THEME[tier - 1]} ${base}`,
      dmg: Math.max(1, Math.round(WEAPON_BASE_DMG[tier - 1] * r.mult * roll())),
      crit: rarity > 0 ? Math.round(3 + rarity * 4 + R() * 4) : 0,
    };
  }
  return {
    id: newId(), slot: "armor", tier, rar: rarity, upg: 0,
    name: `${word} ${THEME[tier - 1]} ${pick(ARMOR_BASES)}`,
    hp: Math.round(ARMOR_BASE_HP[tier - 1] * r.mult * roll()),
    def: Math.max(1, Math.round(ARMOR_BASE_DEF[tier - 1] * r.mult * roll())),
  };
}

export function starterWeapon() { return { id: newId(), slot: "weapon", kind: "sword", tier: 1, rar: 0, upg: 0, name: "Wooden Sword", dmg: 4, crit: 0 }; }
export function starterArmor() { return { id: newId(), slot: "armor", tier: 1, rar: 0, upg: 0, name: "Cloth Tunic", hp: 10, def: 1 }; }

// luck: 0 normal monster, 1 chest, 2 boss
export function rollRarity(luck) {
  const tables = [[64, 26, 8.5, 1.5], [50, 34, 13, 3], [0, 45, 40, 15]];
  const t = tables[luck] || tables[0];
  let x = Math.random() * 100;
  for (let i = 0; i < 4; i++) { if ((x -= t[i]) < 0) return i; }
  return 0;
}

export function sellValue(it) {
  return Math.max(2, Math.round(6 * Math.pow(it.tier, 1.6) * RARITIES[it.rar].sell * (1 + 0.15 * (it.upg || 0))));
}

export function upgradeCost(it) {
  return Math.round(18 * Math.pow(it.tier, 1.5) * (1 + it.rar * 0.6) * Math.pow((it.upg || 0) + 1, 1.45));
}

export function itemStatLine(it) {
  const up = 1 + 0.1 * (it.upg || 0);
  if (it.slot === "weapon") {
    const k = WEAPON_KINDS[it.kind] || WEAPON_KINDS.sword;
    return `${Math.round(it.dmg * up)} damage` + (it.crit ? ` - ${it.crit}% crit` : "") + ` - ${k.label}`;
  }
  return `+${Math.round(it.hp * up)} health - ${Math.round(it.def * up)} armor`;
}

// ------------------------------------------------------------------ badges

export const BADGES = {
  firstKill: ["first-kill", "First Victory", "Defeat your first monster in Dungeon Quest."],
  crypt: ["clear-crypt", "Crypt Cleanser", "Clear the Mossy Crypt by defeating the Rot King."],
  forge: ["clear-forge", "Forge Breaker", "Clear the Lava Forge by defeating the Forge Lord."],
  keep: ["clear-keep", "Keep Conqueror", "Clear the Frost Keep by defeating the Frost Queen."],
  legendary: ["legendary", "Legendary Find", "Find a legendary item."],
  level10: ["level-10", "Seasoned Hero", "Reach level 10."],
  smith: ["master-smith", "Master Smith", "Upgrade a piece of gear to +5 at the blacksmith."],
  coop: ["better-together", "Better Together", "Clear a dungeon room with another player online."],
};
export const BOSS_BADGE = { "mossy-crypt": "crypt", "lava-forge": "forge", "frost-keep": "keep" };
