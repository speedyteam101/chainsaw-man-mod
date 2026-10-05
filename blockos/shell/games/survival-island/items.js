// Survival Island: items, recipes and the little pixel icons drawn for each item.

export const ITEMS = {
  wood:          { name: "Wood",           kind: "res",  color: "#a0703c" },
  stone:         { name: "Stone",          kind: "res",  color: "#8d9096" },
  iron:          { name: "Iron",           kind: "res",  color: "#d9a066" },
  gold:          { name: "Gold",           kind: "res",  color: "#facc15" },
  crystal:       { name: "Crystal",        kind: "res",  color: "#5eead4" },
  berries:       { name: "Berries",        kind: "food", color: "#e11d48", food: 12, heal: 0 },
  raw_meat:      { name: "Raw Meat",       kind: "food", color: "#f472b6", food: 8, heal: 0 },
  cooked_meat:   { name: "Cooked Meat",    kind: "food", color: "#b45309", food: 35, heal: 10 },
  wood_axe:      { name: "Wood Axe",       kind: "tool", tool: "axe",  tier: 1, dmg: 3, color: "#c08a4e", max: 1 },
  wood_pick:     { name: "Wood Pickaxe",   kind: "tool", tool: "pick", tier: 1, dmg: 3, color: "#c08a4e", max: 1 },
  stone_axe:     { name: "Stone Axe",      kind: "tool", tool: "axe",  tier: 2, dmg: 4, color: "#9ca3af", max: 1 },
  stone_pick:    { name: "Stone Pickaxe",  kind: "tool", tool: "pick", tier: 2, dmg: 4, color: "#9ca3af", max: 1 },
  iron_axe:      { name: "Iron Axe",       kind: "tool", tool: "axe",  tier: 3, dmg: 5, color: "#e5e7eb", max: 1 },
  iron_pick:     { name: "Iron Pickaxe",   kind: "tool", tool: "pick", tier: 3, dmg: 5, color: "#e5e7eb", max: 1 },
  wood_sword:    { name: "Wood Sword",     kind: "weapon", dmg: 4,  color: "#c08a4e", max: 1 },
  stone_sword:   { name: "Stone Sword",    kind: "weapon", dmg: 6,  color: "#9ca3af", max: 1 },
  iron_sword:    { name: "Iron Sword",     kind: "weapon", dmg: 9,  color: "#e5e7eb", max: 1 },
  crystal_sword: { name: "Crystal Sword",  kind: "weapon", dmg: 14, color: "#5eead4", max: 1 },
  iron_armor:    { name: "Iron Armor",     kind: "armor", armor: 0.4, color: "#cbd5e1", max: 1 },
  campfire:      { name: "Campfire",       kind: "place", color: "#fb923c" },
  workbench:     { name: "Workbench",      kind: "place", color: "#b7834a" },
  wood_floor:    { name: "Wood Floor",     kind: "place", color: "#c99a5b" },
  wood_wall:     { name: "Wood Wall",      kind: "place", color: "#a0703c" },
  wood_door:     { name: "Wood Door",      kind: "place", color: "#8b5a2b" },
  stone_wall:    { name: "Stone Wall",     kind: "place", color: "#8d9096" },
  chest:         { name: "Chest",          kind: "place", color: "#b7834a" },
  bed:           { name: "Bed",            kind: "place", color: "#ef4444" },
  torch:         { name: "Torch",          kind: "place", color: "#fbbf24" },
  lamp:          { name: "Crystal Lamp",   kind: "place", color: "#5eead4" },
};

// Build pieces. size = the space the piece takes in its cell (x, y, z); solid = blocks movement.
export const PIECES = {
  wood_floor: { size: [4, 1, 4], solid: true },
  wood_wall:  { size: [4, 3, 4], solid: true },
  stone_wall: { size: [4, 3, 4], solid: true },
  wood_door:  { size: [4, 6, 4], solid: true, door: true },
  campfire:   { size: [4, 1.6, 4], solid: false, light: 1 },
  workbench:  { size: [4, 2.6, 4], solid: true, use: "craft" },
  chest:      { size: [4, 2.4, 4], solid: true, use: "chest" },
  bed:        { size: [4, 1.6, 4], solid: true, use: "bed" },
  torch:      { size: [4, 3.6, 4], solid: false, light: 1 },
  lamp:       { size: [4, 4, 4], solid: false, light: 1 },
};
export const PIECE_LIST = Object.keys(PIECES);

// Recipes. near: needs that station within reach. unlock: needs that item found at least once.
export const RECIPES = [
  { out: "wood_axe",    cost: { wood: 3 },                          cat: "Tools" },
  { out: "wood_pick",   cost: { wood: 4 },                          cat: "Tools" },
  { out: "wood_sword",  cost: { wood: 4 },                          cat: "Tools" },
  { out: "campfire",    cost: { wood: 5 },                          cat: "Survival" },
  { out: "workbench",   cost: { wood: 8 },                          cat: "Survival" },
  { out: "torch", n: 3, cost: { wood: 2, stone: 1 },                cat: "Survival", unlock: "stone" },
  { out: "cooked_meat", cost: { raw_meat: 1 },                      cat: "Survival", near: "campfire", unlock: "raw_meat" },
  { out: "stone_axe",   cost: { wood: 3, stone: 3 },                cat: "Tools", near: "workbench", unlock: "stone" },
  { out: "stone_pick",  cost: { wood: 3, stone: 3 },                cat: "Tools", near: "workbench", unlock: "stone" },
  { out: "stone_sword", cost: { wood: 2, stone: 4 },                cat: "Tools", near: "workbench", unlock: "stone" },
  { out: "wood_floor", n: 2, cost: { wood: 3 },                     cat: "Building", near: "workbench" },
  { out: "wood_wall", n: 2, cost: { wood: 4 },                      cat: "Building", near: "workbench" },
  { out: "wood_door",   cost: { wood: 5 },                          cat: "Building", near: "workbench" },
  { out: "stone_wall", n: 2, cost: { stone: 4 },                    cat: "Building", near: "workbench", unlock: "stone" },
  { out: "chest",       cost: { wood: 8 },                          cat: "Building", near: "workbench" },
  { out: "bed",         cost: { wood: 10, berries: 2 },             cat: "Building", near: "workbench" },
  { out: "iron_axe",    cost: { wood: 2, iron: 3 },                 cat: "Tools", near: "workbench", unlock: "iron" },
  { out: "iron_pick",   cost: { wood: 2, iron: 3 },                 cat: "Tools", near: "workbench", unlock: "iron" },
  { out: "iron_sword",  cost: { wood: 1, iron: 4 },                 cat: "Tools", near: "workbench", unlock: "iron" },
  { out: "iron_armor",  cost: { iron: 8 },                          cat: "Tools", near: "workbench", unlock: "iron" },
  { out: "lamp",        cost: { iron: 1, crystal: 1 },              cat: "Building", near: "workbench", unlock: "crystal" },
  { out: "crystal_sword", cost: { iron: 2, gold: 2, crystal: 3 },   cat: "Tools", near: "workbench", unlock: "crystal" },
];

export const UNLOCK_HINT = {
  stone: "Mine a rock first",
  iron: "Mine iron ore first",
  crystal: "Find a crystal first",
  raw_meat: "Hunt an animal first",
};

// ------------------------------------------------------------------ icons

const iconCache = new Map();

function px(g, x, y, w, h, c) { g.fillStyle = c; g.fillRect(x, y, w, h); }

function shade(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  const f = (v) => Math.max(0, Math.min(255, Math.round(v + amt * 255)));
  return `rgb(${f(n >> 16)},${f((n >> 8) & 255)},${f(n & 255)})`;
}

function cube(g, x, y, s, c) {
  // a little isometric-ish block
  px(g, x, y + s * 0.25, s, s * 0.75, shade(c, -0.12));
  px(g, x, y, s, s * 0.3, shade(c, 0.12));
  px(g, x + s * 0.5, y + s * 0.3, s * 0.5, s * 0.7, shade(c, -0.22));
}

function handle(g, c) {
  g.save(); g.translate(20, 20); g.rotate(Math.PI / 4);
  px(g, -2, -14, 4, 30, c || "#8b5a2b");
  g.restore();
}

const DRAW = {
  wood(g) { px(g, 6, 12, 28, 16, "#8b5a2b"); px(g, 6, 12, 28, 4, "#a0703c"); px(g, 28, 12, 6, 16, "#d6a76a"); px(g, 30, 16, 2, 8, "#a0703c"); },
  stone(g) { cube(g, 7, 9, 26, "#8d9096"); px(g, 12, 18, 4, 4, "#6b6e74"); px(g, 22, 24, 5, 3, "#6b6e74"); },
  iron(g) { px(g, 7, 16, 26, 12, "#b8865a"); px(g, 10, 12, 20, 6, "#e3b07f"); px(g, 12, 13, 8, 2, "#fff3"); },
  gold(g) { px(g, 7, 16, 26, 12, "#ca9a0a"); px(g, 10, 12, 20, 6, "#fde047"); px(g, 12, 13, 8, 2, "#fff8"); },
  crystal(g) { g.fillStyle = "#5eead4"; g.beginPath(); g.moveTo(20, 4); g.lineTo(31, 16); g.lineTo(20, 36); g.lineTo(9, 16); g.fill(); g.fillStyle = "#ccfbf1"; g.beginPath(); g.moveTo(20, 4); g.lineTo(24, 16); g.lineTo(20, 30); g.lineTo(15, 16); g.fill(); },
  berries(g) { for (const [x, y] of [[13, 20], [24, 18], [18, 28], [27, 28]]) { g.fillStyle = "#be123c"; g.beginPath(); g.arc(x, y, 6, 0, 7); g.fill(); g.fillStyle = "#fda4af"; g.fillRect(x - 3, y - 3, 2, 2); } px(g, 18, 6, 4, 10, "#15803d"); px(g, 20, 8, 8, 4, "#22c55e"); },
  raw_meat(g) { g.fillStyle = "#f472b6"; g.beginPath(); g.ellipse(18, 22, 13, 10, -0.4, 0, 7); g.fill(); g.fillStyle = "#fbcfe8"; g.beginPath(); g.ellipse(14, 19, 4, 3, -0.4, 0, 7); g.fill(); px(g, 28, 26, 9, 4, "#f5f5f4"); px(g, 34, 24, 4, 8, "#f5f5f4"); },
  cooked_meat(g) { g.fillStyle = "#92400e"; g.beginPath(); g.ellipse(18, 22, 13, 10, -0.4, 0, 7); g.fill(); g.fillStyle = "#b45309"; g.beginPath(); g.ellipse(15, 19, 6, 4, -0.4, 0, 7); g.fill(); px(g, 28, 26, 9, 4, "#f5f5f4"); px(g, 34, 24, 4, 8, "#f5f5f4"); },
  axe(g, c) { handle(g); g.save(); g.translate(20, 20); g.rotate(Math.PI / 4); px(g, -2, -15, 11, 9, c); px(g, 7, -16, 3, 11, shade(c, -0.15)); g.restore(); },
  pick(g, c) { handle(g); g.save(); g.translate(20, 20); g.rotate(Math.PI / 4); px(g, -13, -15, 26, 5, c); px(g, -15, -13, 4, 5, shade(c, -0.15)); px(g, 11, -13, 4, 5, shade(c, -0.15)); g.restore(); },
  sword(g, c) { g.save(); g.translate(20, 20); g.rotate(Math.PI / 4); px(g, -3, -17, 6, 24, c); px(g, -1, -17, 2, 22, "#fff6"); px(g, -8, 6, 16, 4, "#57534e"); px(g, -2, 9, 4, 8, "#8b5a2b"); g.restore(); },
  iron_armor(g) { px(g, 8, 8, 24, 26, "#cbd5e1"); px(g, 4, 8, 6, 10, "#94a3b8"); px(g, 30, 8, 6, 10, "#94a3b8"); px(g, 15, 8, 10, 6, "#334155"); px(g, 12, 18, 16, 3, "#94a3b8"); },
  campfire(g) { px(g, 6, 28, 28, 5, "#7c4a21"); px(g, 9, 24, 22, 5, "#8b5a2b"); g.fillStyle = "#f97316"; g.beginPath(); g.moveTo(10, 26); g.quadraticCurveTo(12, 8, 20, 4); g.quadraticCurveTo(28, 10, 30, 26); g.fill(); g.fillStyle = "#fde047"; g.beginPath(); g.moveTo(15, 26); g.quadraticCurveTo(18, 14, 20, 12); g.quadraticCurveTo(25, 18, 25, 26); g.fill(); },
  workbench(g) { px(g, 5, 12, 30, 8, "#c99a5b"); px(g, 5, 12, 30, 3, "#e0b77c"); px(g, 7, 20, 5, 14, "#8b5a2b"); px(g, 28, 20, 5, 14, "#8b5a2b"); px(g, 13, 8, 10, 4, "#9ca3af"); },
  wood_floor(g) { px(g, 4, 22, 32, 10, "#a0703c"); px(g, 4, 18, 32, 6, "#d6a76a"); for (let x = 4; x < 36; x += 8) px(g, x, 18, 1, 14, "#8b5a2b"); },
  wood_wall(g) { cube(g, 7, 6, 26, "#a0703c"); px(g, 7, 17, 26, 1, "#7c4a21"); px(g, 7, 25, 26, 1, "#7c4a21"); },
  stone_wall(g) { cube(g, 7, 6, 26, "#8d9096"); px(g, 7, 17, 26, 2, "#6b6e74"); px(g, 7, 26, 26, 2, "#6b6e74"); px(g, 19, 13, 2, 5, "#6b6e74"); px(g, 13, 19, 2, 7, "#6b6e74"); },
  wood_door(g) { px(g, 10, 3, 20, 34, "#8b5a2b"); px(g, 13, 6, 14, 12, "#a0703c"); px(g, 13, 21, 14, 13, "#a0703c"); px(g, 24, 19, 3, 3, "#facc15"); },
  chest(g) { px(g, 5, 14, 30, 20, "#a0703c"); px(g, 5, 10, 30, 8, "#c99a5b"); px(g, 5, 18, 30, 2, "#57534e"); px(g, 17, 16, 6, 7, "#facc15"); },
  bed(g) { px(g, 3, 20, 34, 8, "#ef4444"); px(g, 3, 18, 10, 6, "#f5f5f4"); px(g, 3, 28, 34, 4, "#8b5a2b"); px(g, 3, 30, 3, 6, "#7c4a21"); px(g, 34, 30, 3, 6, "#7c4a21"); },
  torch(g) { g.save(); g.translate(20, 22); g.rotate(0.35); px(g, -2, -6, 5, 22, "#8b5a2b"); px(g, -4, -14, 9, 9, "#f97316"); px(g, -2, -12, 5, 5, "#fde047"); g.restore(); },
  lamp(g) { px(g, 12, 30, 16, 5, "#9ca3af"); px(g, 18, 18, 4, 12, "#9ca3af"); g.fillStyle = "#5eead4"; g.beginPath(); g.moveTo(20, 2); g.lineTo(28, 11); g.lineTo(20, 20); g.lineTo(12, 11); g.fill(); g.fillStyle = "#ccfbf1"; g.fillRect(18, 7, 3, 6); },
};

export function icon(id) {
  if (iconCache.has(id)) return iconCache.get(id);
  const c = document.createElement("canvas");
  c.width = c.height = 40;
  const g = c.getContext("2d");
  const it = ITEMS[id];
  if (it) {
    if (DRAW[id]) DRAW[id](g);
    else if (it.kind === "tool") DRAW[it.tool](g, it.color);
    else if (it.kind === "weapon") DRAW.sword(g, it.color);
    else cube(g, 7, 7, 26, it.color);
  }
  const url = c.toDataURL();
  iconCache.set(id, url);
  return url;
}
