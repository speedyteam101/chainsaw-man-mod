/* Brick Legends: maps (overworld, towns, castle) and the tile renderer. */
"use strict";

function hash2(x, y, s) {
  let h = (x * 374761393 + y * 668265263 + (s || 0) * 982451653) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}
function vnoise(x, y, sc, s) {
  const fx = x / sc, fy = y / sc, x0 = Math.floor(fx), y0 = Math.floor(fy);
  const sm = (t) => t * t * (3 - 2 * t);
  const u = sm(fx - x0), v = sm(fy - y0);
  const a = hash2(x0, y0, s), b = hash2(x0 + 1, y0, s), c = hash2(x0, y0 + 1, s), d = hash2(x0 + 1, y0 + 1, s);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function shadeHex(hex, amt) {
  const n = parseInt(String(hex).slice(1), 16) || 0;
  const f = (c) => Math.max(0, Math.min(255, Math.round(c + amt * 255)));
  return `rgb(${f(n >> 16)},${f((n >> 8) & 255)},${f(n & 255)})`;
}

const GROUND = { fields: ".", forest: "f", desert: "s", snow: "*", dark: "d" };
const REGION_NAME = { fields: "Brickfield Plains", forest: "Whisperwood", desert: "Sunscorch Desert", snow: "Frostfang Peaks", dark: "Hollow Wastes" };
const PATH_COLOR = { fields: "#c9a36b", forest: "#9c7a4f", desert: "#c79a52", snow: "#c3d0dc", dark: "#5b5066", town: "#b8aa94", castle: "#4a4458" };
// Tiles you can't walk through (b, v, g are handled in tileAt once the story clears them).
const SOLID = new Set("TPcrSMD~#HRFAkOWQIZtLqlnbvg".split(""));
// Tiles drawn on top of the ground.
const OVER = new Set("TPcrSMDXLbvg123KQIZh,".split(""));

const TOWN_THEMES = {
  brickhaven: { ground: "grass", groundC: "#5bb450", wall: "hedge", roof: "#d9483b", roof2: "#a8322a", house: "#f3e6cf", tree: "T", awning: ["#ef4444", "#fff7ed"], deco: "," },
  sandstone:  { ground: "sand", groundC: "#e9c46a", wall: "sandstone", roof: "#d08c4a", roof2: "#9a5f2a", house: "#f0d9a8", tree: "L", awning: ["#0ea5e9", "#fef3c7"], deco: "c" },
  frostpeak:  { ground: "snow", groundC: "#eef3f8", wall: "snowstone", roof: "#3b82f6", roof2: "#1e40af", house: "#e2e8f0", tree: "S", awning: ["#a855f7", "#f5f3ff"], deco: "r" },
};
const TOWN_ICON = { "1": "brickhaven", "2": "sandstone", "3": "frostpeak" };

function makeMap(id, name, w, h, fill) {
  return {
    id, name, w, h,
    t: Array.from({ length: h }, () => Array(w).fill(fill)),
    reg: null, theme: null, warps: {}, npcs: [], objs: [], labels: [],
  };
}
function setT(m, x, y, c) { if (x >= 0 && y >= 0 && x < m.w && y < m.h) m.t[y][x] = c; }
function rectT(m, x0, y0, x1, y1, c) { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) setT(m, x, y, c); }

// Effective tile, after story flags have removed barriers.
function tileAt(m, x, y) {
  if (x < 0 || y < 0 || x >= m.w || y >= m.h) return m.id === "world" ? "~" : "#";
  const c = m.t[y][x];
  const f = (typeof G !== "undefined" && G.s) ? G.s.flags : {};
  if (c === "b" && f.ch1) return "_";
  if (c === "v" && f.wyrm) return "_";
  if (c === "g" && f.ch2) return "_";
  return c;
}
function regionAt(m, x, y) {
  if (m.reg) return m.reg[Math.max(0, Math.min(m.h - 1, y))][Math.max(0, Math.min(m.w - 1, x))];
  return m.region || "town";
}
function groundChar(m, x, y) {
  if (m.id === "world") return GROUND[regionAt(m, x, y)];
  if (m.id === "castle") return "o";
  return "e";
}

// ------------------------------------------------------------------ overworld
function buildWorld() {
  const W = 96, H = 72;
  const m = makeMap("world", "Blockara", W, H, "~");
  m.reg = Array.from({ length: H }, () => Array(W).fill("fields"));
  const rng = mulberry32(20240611);
  const regionFor = (x, y) => {
    const j = (vnoise(x, y, 4, 7) - 0.5) * 5;
    if (y < 20 && x < 52) return "dark";
    if (x >= 52 && y < 33) return "snow";
    if (x >= 58 && y >= 33) return "desert";
    if (x < 34 + j) return "forest";
    return "fields";
  };
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const margin = 2 + vnoise(x, y, 5, 1) * 3.5;
    const land = x >= margin && y >= margin && x < W - 1 - margin && y < H - 1 - margin;
    const r = regionFor(x, y);
    m.reg[y][x] = r;
    if (land) m.t[y][x] = GROUND[r];
  }
  const isLand = (x, y) => m.t[y][x] !== "~";
  // rivers, ridges, ponds
  for (let x = 0; x < 53; x++) { setT(m, x, 20, "~"); setT(m, x, 21, "~"); }
  for (let y = 0; y <= 32; y++) for (let x = 51; x <= 53; x++) if (isLand(x, y)) setT(m, x, y, "M");
  for (let x = 51; x < W; x++) for (let y = 31; y <= 32; y++) if (isLand(x, y)) setT(m, x, y, "M");
  for (let y = 33; y < H; y++) { setT(m, 58, y, "~"); setT(m, 59, y, "~"); }
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (!isLand(x, y)) continue;
    const dp = Math.hypot(x - 40, (y - 36) * 1.2), dq = Math.hypot(x - 67, y - 61);
    if (dp < 3.3 || dq < 2.2) setT(m, x, y, "~");
    const r = m.reg[y][x];
    const c = m.t[y][x];
    if (c === "M" || c === "~") continue;
    if ((Math.abs(x - 52) <= 2 && y < 33 || Math.abs(y - 31.5) <= 2 && x > 50) && vnoise(x, y, 2, 5) > 0.62) { setT(m, x, y, "M"); continue; }
    if (r === "snow" && vnoise(x, y, 3, 9) > 0.7) { setT(m, x, y, "M"); continue; }
    if (r === "dark" && vnoise(x, y, 3, 11) > 0.75) { setT(m, x, y, "l"); continue; }
    const q = rng();
    if (r === "fields") { if (q < 0.035) setT(m, x, y, "T"); else if (q < 0.09) setT(m, x, y, ","); else if (q < 0.1) setT(m, x, y, "r"); }
    else if (r === "forest") { if (q < 0.26) setT(m, x, y, "T"); else if (q < 0.34) setT(m, x, y, "P"); else if (q < 0.37) setT(m, x, y, ","); }
    else if (r === "desert") { if (q < 0.05) setT(m, x, y, "c"); else if (q < 0.07) setT(m, x, y, "r"); }
    else if (r === "snow") { if (q < 0.16) setT(m, x, y, "S"); else if (q < 0.19) setT(m, x, y, "r"); else if (q < 0.23) setT(m, x, y, "i"); }
    else if (r === "dark") { if (q < 0.07) setT(m, x, y, "D"); else if (q < 0.1) setT(m, x, y, "r"); }
  }
  // oasis palms
  [[64, 60], [70, 62], [66, 64], [69, 58]].forEach(([x, y]) => setT(m, x, y, "L"));

  const carve = (pts, mode) => {
    for (let i = 1; i < pts.length; i++) {
      let [x, y] = pts[i - 1];
      const [tx, ty] = pts[i];
      const put = () => {
        const c = m.t[y][x];
        if (mode === "path") setT(m, x, y, c === "~" ? "=" : "_");
        else if (SOLID.has(c) || c === "~") setT(m, x, y, c === "~" ? "=" : GROUND[m.reg[y][x]]);
      };
      put();
      while (x !== tx) { x += Math.sign(tx - x); put(); }
      while (y !== ty) { y += Math.sign(ty - y); put(); }
    }
  };
  const ground = (x0, y0, x1, y1) => { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) setT(m, x, y, GROUND[m.reg[y][x]]); };

  // arenas and special areas first, then paths
  ground(7, 25, 12, 31);      // treant glade
  ground(80, 4, 88, 10);      // summit
  ground(80, 34, 88, 41);     // ruins yard
  ground(44, 55, 48, 60);     // around Brickhaven
  ground(72, 52, 76, 56);     // around Sandstone
  ground(66, 12, 70, 16);     // around Frostpeak
  // the hidden clearing
  rectT(m, 4, 55, 10, 61, "T");
  ground(6, 56, 8, 60);
  setT(m, 9, 58, "X");
  carve([[14, 50], [14, 58], [10, 58]], "clear");

  carve([[46, 57], [46, 44], [30, 44], [30, 32], [18, 32], [18, 28], [11, 28]], "path");
  carve([[46, 50], [74, 50], [74, 53]], "path");
  carve([[74, 50], [74, 46], [84, 46], [84, 38]], "path");
  carve([[74, 46], [75, 46], [75, 18], [68, 18], [68, 15]], "path");
  carve([[75, 18], [75, 10], [84, 10], [84, 9]], "path");
  carve([[46, 44], [46, 28], [44, 28], [44, 12], [27, 12], [27, 10]], "path");
  // detours to treasure and quest items
  carve([[45, 27], [41, 27]], "clear");
  carve([[30, 40], [24, 40]], "clear");
  carve([[30, 44], [30, 50], [14, 50]], "clear");
  carve([[22, 32], [22, 37]], "clear");
  carve([[30, 50], [30, 60], [27, 60]], "clear");
  carve([[75, 50], [89, 50], [89, 60]], "clear");
  carve([[68, 18], [62, 18], [62, 12]], "clear");
  carve([[75, 25], [60, 25]], "clear");
  carve([[27, 12], [10, 12], [10, 8]], "clear");

  // ruins of the Sand Wyrm
  for (let x = 81; x <= 87; x++) { setT(m, x, 35, "q"); setT(m, x, 39, "q"); }
  for (let y = 35; y <= 39; y++) { setT(m, 81, y, "q"); setT(m, 87, y, "q"); }
  rectT(m, 82, 36, 86, 38, "s");
  setT(m, 84, 39, "_"); setT(m, 84, 38, "_");
  [[82, 36], [86, 36]].forEach(([x, y]) => setT(m, x, y, "q"));
  // barriers
  setT(m, 57, 50, "b");
  setT(m, 75, 32, "v");
  setT(m, 44, 22, "g");
  // castle
  rectT(m, 23, 5, 31, 9, "Q");
  setT(m, 27, 9, "K");
  // towns
  setT(m, 46, 58, "1");
  setT(m, 74, 54, "2");
  setT(m, 68, 14, "3");
  m.warps["46,58"] = { map: "brickhaven", x: 15, y: 22, dir: "up" };
  m.warps["74,54"] = { map: "sandstone", x: 15, y: 22, dir: "up" };
  m.warps["68,14"] = { map: "frostpeak", x: 15, y: 22, dir: "up" };
  m.warps["27,9"] = { map: "castle", x: 16, y: 40, dir: "up" };
  m.music = "field";
  return m;
}

// ------------------------------------------------------------------ towns
function building(m, x, y, w, h, doorX) {
  rectT(m, x, y, x + w - 1, y + h - 3, "R");
  rectT(m, x, y + h - 2, x + w - 1, y + h - 1, "H");
  setT(m, doorX, y + h - 1, "n");
}
function stall(m, x, y) {
  rectT(m, x, y, x + 4, y, "A");
  setT(m, x, y + 1, "k"); setT(m, x + 4, y + 1, "k");
  rectT(m, x + 1, y + 1, x + 3, y + 1, "C");
  rectT(m, x, y + 2, x + 4, y + 2, "k");
}
function buildTown(id, name, themeId, exitTo) {
  const W = 32, H = 24;
  const m = makeMap(id, name, W, H, "e");
  const th = TOWN_THEMES[themeId];
  m.theme = th;
  m.region = "town";
  m.music = "town";
  m.town = true;
  rectT(m, 0, 0, W - 1, 0, "W"); rectT(m, 0, H - 1, W - 1, H - 1, "W");
  rectT(m, 0, 0, 0, H - 1, "W"); rectT(m, W - 1, 0, W - 1, H - 1, "W");
  rectT(m, 9, 9, 28, 19, "C");
  rectT(m, 2, 6, 29, 8, "C");
  rectT(m, 15, 9, 16, 22, "C");
  rectT(m, 15, 11, 16, 12, "O");
  building(m, 2, 1, 7, 5, 5);
  building(m, 23, 1, 7, 5, 26);
  building(m, 2, 10, 6, 5, 4);
  building(m, 2, 17, 6, 5, 5);
  stall(m, 23, 10);
  stall(m, 23, 15);
  setT(m, 15, 23, "x"); setT(m, 16, 23, "x");
  m.warps["15,23"] = exitTo; m.warps["16,23"] = exitTo;
  const trees = [[11, 2], [13, 3], [19, 2], [21, 3], [17, 1], [10, 21], [12, 20], [20, 21], [22, 20], [26, 21], [29, 20], [8, 16], [30, 12], [30, 15]];
  trees.forEach(([x, y]) => { if (m.t[y][x] === "e") setT(m, x, y, th.tree); });
  const rng = mulberry32(id.length * 977);
  for (let y = 1; y < H - 1; y++) for (let x = 1; x < W - 1; x++)
    if (m.t[y][x] === "e" && rng() < 0.12) {
      if (th.ground === "snow") { if (rng() < 0.25) setT(m, x, y, "r"); }
      else setT(m, x, y, th.deco === "," ? "," : (rng() < 0.4 ? th.deco : ","));
    }
  m.labels.push({ x: 5.5, y: 3.6, text: "INN" }, { x: 25.5, y: 10.5, text: "ITEMS", small: true }, { x: 25.5, y: 15.5, text: "GEAR", small: true });
  return m;
}

// ------------------------------------------------------------------ castle
function buildCastle() {
  const W = 33, H = 42;
  const m = makeMap("castle", "Hollow Castle", W, H, "#");
  m.region = "castle";
  m.music = "castle";
  rectT(m, 14, 31, 18, 40, "o");
  rectT(m, 4, 20, 28, 30, "o");
  rectT(m, 7, 22, 12, 28, "l");
  rectT(m, 20, 22, 25, 28, "l");
  rectT(m, 11, 13, 21, 18, "o");
  setT(m, 16, 19, "o");
  rectT(m, 7, 2, 25, 11, "o");
  setT(m, 16, 12, "o");
  for (let y = 4; y <= 40; y++) if (m.t[y][16] === "o") setT(m, 16, y, "u");
  setT(m, 16, 41, "x");
  [[15, 3], [16, 3], [17, 3]].forEach(([x, y]) => setT(m, x, y, "Z"));
  [[9, 4], [23, 4], [9, 8], [23, 8], [5, 25], [27, 25], [14, 22], [18, 22], [14, 28], [18, 28]].forEach(([x, y]) => setT(m, x, y, "I"));
  [[13, 33], [19, 33], [13, 37], [19, 37], [3, 24], [29, 24], [10, 12], [22, 12], [11, 1], [21, 1], [10, 19], [22, 19]].forEach(([x, y]) => setT(m, x, y, "t"));
  setT(m, 12, 15, "h");
  m.warps["16,41"] = { map: "world", x: 27, y: 10, dir: "down" };
  return m;
}

const MAPS = {};
function buildMaps() {
  MAPS.world = buildWorld();
  MAPS.brickhaven = buildTown("brickhaven", "Brickhaven", "brickhaven", { map: "world", x: 46, y: 57, dir: "up" });
  MAPS.sandstone = buildTown("sandstone", "Sandstone", "sandstone", { map: "world", x: 74, y: 53, dir: "up" });
  MAPS.frostpeak = buildTown("frostpeak", "Frostpeak", "frostpeak", { map: "world", x: 68, y: 15, dir: "down" });
  MAPS.castle = buildCastle();
}

// ------------------------------------------------------------------ tile drawing
function stud(ctx, sx, sy, col) {
  ctx.fillStyle = col;
  ctx.beginPath();
  ctx.arc(sx + 16, sy + 16, 5.5, 0, Math.PI * 2);
  ctx.fill();
}
function groundColor(c, m, x, y) {
  switch (c) {
    case ".": return "#5bb450";
    case "f": return "#2f7a3a";
    case "s": return "#e9c46a";
    case "*": return "#eef3f8";
    case "d": return "#3d3548";
    case "o": return "#433d52";
    case "e": return m.theme ? m.theme.groundC : "#5bb450";
  }
  return "#5bb450";
}
function drawGround(ctx, c, m, x, y, sx, sy, h) {
  const base = groundColor(c, m, x, y);
  ctx.fillStyle = base;
  ctx.fillRect(sx, sy, TILE, TILE);
  if (h > 0.5) { ctx.fillStyle = "rgba(0,0,0,.035)"; ctx.fillRect(sx, sy, TILE, TILE); }
  if (c === "o") {
    ctx.fillStyle = "rgba(0,0,0,.25)";
    ctx.fillRect(sx, sy + 31, 32, 1); ctx.fillRect(sx + 31, sy, 1, 32);
    ctx.fillStyle = "rgba(255,255,255,.04)"; ctx.fillRect(sx + 2, sy + 2, 28, 3);
    return;
  }
  const snowy = c === "*" || (c === "e" && m.theme && m.theme.ground === "snow");
  stud(ctx, sx, sy, snowy ? "rgba(140,170,200,.22)" : "rgba(255,255,255,.08)");
  if ((c === "." || c === "f" || (c === "e" && m.theme && m.theme.ground === "grass")) && h < 0.3) {
    ctx.fillStyle = "rgba(0,0,0,.12)";
    ctx.fillRect(sx + 4 + h * 60, sy + 24, 2, 4); ctx.fillRect(sx + 8 + h * 40, sy + 6, 2, 4);
  }
  if (c === "s" && h < 0.25) { ctx.fillStyle = "rgba(160,110,40,.25)"; ctx.fillRect(sx + 3, sy + 25, 10, 2); }
}

function drawTree(ctx, sx, sy, dark, h) {
  ctx.fillStyle = "rgba(0,0,0,.18)"; ctx.fillRect(sx + 6, sy + 26, 22, 5);
  Kit.brick(ctx, sx + 13, sy + 18, 7, 12, "#7c4a1e", 2);
  const c = dark ? (h > 0.5 ? "#1f6b33" : "#246f37") : (h > 0.5 ? "#2e9444" : "#33a04b");
  Kit.brick(ctx, sx + 3, sy + 4, 26, 18, c, 5);
  Kit.brick(ctx, sx + 8, sy - 4, 16, 12, shadeHex(dark ? "#2a7a3e" : "#3fb35a", 0.04), 4);
}
function drawPine(ctx, sx, sy, snow, h) {
  ctx.fillStyle = "rgba(0,0,0,.18)"; ctx.fillRect(sx + 7, sy + 27, 18, 4);
  Kit.brick(ctx, sx + 13, sy + 22, 6, 9, "#6b3f1d", 2);
  const c = snow ? "#2f6b55" : (h > 0.5 ? "#1d5e35" : "#22683b");
  Kit.brick(ctx, sx + 4, sy + 15, 24, 10, c, 3);
  Kit.brick(ctx, sx + 7, sy + 6, 18, 10, c, 3);
  Kit.brick(ctx, sx + 11, sy - 2, 10, 9, c, 3);
  if (snow) {
    ctx.fillStyle = "#f8fafc";
    ctx.fillRect(sx + 5, sy + 15, 22, 3); ctx.fillRect(sx + 8, sy + 6, 16, 3); ctx.fillRect(sx + 12, sy - 2, 8, 3);
  }
}
function drawRock(ctx, sx, sy, col) {
  ctx.fillStyle = "rgba(0,0,0,.2)"; ctx.fillRect(sx + 4, sy + 25, 24, 5);
  Kit.brick(ctx, sx + 5, sy + 12, 22, 16, col || "#8b8f96", 4);
  Kit.brick(ctx, sx + 9, sy + 6, 12, 9, shadeHex(col || "#8b8f96", 0.08), 3);
}
function drawMountain(ctx, sx, sy, snowy, h) {
  const c = h > 0.5 ? "#7c6f64" : "#857868";
  Kit.brick(ctx, sx, sy + 18, 32, 14, shadeHex(c, -0.06), 3);
  Kit.brick(ctx, sx + 4, sy + 8, 24, 12, c, 3);
  Kit.brick(ctx, sx + 9, sy - 2, 14, 12, shadeHex(c, 0.06), 3);
  ctx.fillStyle = snowy ? "#f8fafc" : "#a8a29e";
  ctx.fillRect(sx + 10, sy - 2, 12, 5);
  if (snowy) ctx.fillRect(sx + 5, sy + 8, 6, 3);
}
function drawHouse(ctx, sx, sy, roof, wall, s) {
  s = s || 1;
  Kit.brick(ctx, sx + 2 * s, sy + 14 * s, 13 * s, 12 * s, wall, 2);
  ctx.fillStyle = roof; ctx.beginPath(); ctx.moveTo(sx, sy + 15 * s); ctx.lineTo(sx + 8.5 * s, sy + 5 * s); ctx.lineTo(sx + 17 * s, sy + 15 * s); ctx.fill();
  ctx.fillStyle = "#5b3a1e"; ctx.fillRect(sx + 7 * s, sy + 19 * s, 4 * s, 7 * s);
}

function drawTile(ctx, m, x, y, sx, sy, T) {
  const c = tileAt(m, x, y);
  const h = hash2(x, y, 3);
  const reg = regionAt(m, x, y);
  if (OVER.has(c)) drawGround(ctx, groundChar(m, x, y), m, x, y, sx, sy, h);
  switch (c) {
    case ".": case "f": case "s": case "*": case "d": case "o": case "e":
      drawGround(ctx, c, m, x, y, sx, sy, h); break;
    case ",": {
      const cols = ["#f472b6", "#facc15", "#ffffff", "#a78bfa", "#fb923c"];
      for (let i = 0; i < 3; i++) {
        const fx = sx + 5 + ((h * 97 * (i + 1)) % 1) * 20, fy = sy + 5 + ((h * 53 * (i + 2)) % 1) * 20;
        ctx.fillStyle = "#2f7a3a"; ctx.fillRect(fx + 1, fy + 3, 2, 4);
        ctx.fillStyle = cols[Math.floor(h * 5 + i) % 5]; ctx.fillRect(fx, fy, 4, 4);
      }
      break;
    }
    case "_": case "x": {
      ctx.fillStyle = c === "x" || m.town ? (m.theme && m.theme.ground === "snow" ? "#cbd5e1" : "#b8aa94") : PATH_COLOR[reg] || "#c9a36b";
      if (m.id === "castle") ctx.fillStyle = "#4a4458";
      ctx.fillRect(sx, sy, TILE, TILE);
      stud(ctx, sx, sy, "rgba(255,255,255,.1)");
      ctx.fillStyle = "rgba(0,0,0,.08)";
      ctx.fillRect(sx + 3 + h * 10, sy + 4, 4, 3); ctx.fillRect(sx + 20 - h * 8, sy + 22, 5, 3);
      break;
    }
    case "~": case "=": {
      ctx.fillStyle = "#2f7fd6"; ctx.fillRect(sx, sy, TILE, TILE);
      ctx.fillStyle = "rgba(255,255,255,.22)";
      const o = (T * 14 + h * 32) % 32;
      ctx.fillRect(sx + o * 0.8, sy + 9 + h * 6, 9, 2);
      ctx.fillRect(sx + ((o + 16) % 32) * 0.8, sy + 22 - h * 4, 7, 2);
      const up = tileAt(m, x, y - 1);
      if (up !== "~" && up !== "=") { ctx.fillStyle = "rgba(255,255,255,.45)"; ctx.fillRect(sx, sy, 32, 3); }
      if (c === "=") {
        const vertical = ["~", "="].includes(tileAt(m, x - 1, y)) && ["~", "="].includes(tileAt(m, x + 1, y));
        ctx.fillStyle = "#8b5a2b";
        if (vertical) {
          ctx.fillRect(sx + 3, sy, 26, 32);
          ctx.fillStyle = "#a86f38";
          for (let i = 0; i < 4; i++) ctx.fillRect(sx + 4, sy + i * 8 + 1, 24, 6);
          ctx.fillStyle = "#5b3a1e"; ctx.fillRect(sx + 2, sy, 3, 32); ctx.fillRect(sx + 27, sy, 3, 32);
        } else {
          ctx.fillRect(sx, sy + 3, 32, 26);
          ctx.fillStyle = "#a86f38";
          for (let i = 0; i < 4; i++) ctx.fillRect(sx + i * 8 + 1, sy + 4, 6, 24);
          ctx.fillStyle = "#5b3a1e"; ctx.fillRect(sx, sy + 2, 32, 3); ctx.fillRect(sx, sy + 27, 32, 3);
        }
      }
      break;
    }
    case "l": {
      ctx.fillStyle = "#c2410c"; ctx.fillRect(sx, sy, TILE, TILE);
      const p = Math.sin(T * 2 + h * 6) * 0.5 + 0.5;
      ctx.fillStyle = `rgba(251,191,36,${0.35 + p * 0.4})`;
      ctx.fillRect(sx + 4 + h * 8, sy + 6, 10, 6); ctx.fillRect(sx + 16 - h * 6, sy + 18, 12, 6);
      ctx.fillStyle = "rgba(0,0,0,.18)"; ctx.fillRect(sx, sy + 29, 32, 3);
      break;
    }
    case "i": {
      ctx.fillStyle = "#bfe3f5"; ctx.fillRect(sx, sy, TILE, TILE);
      ctx.fillStyle = "rgba(255,255,255,.6)"; ctx.fillRect(sx + 5, sy + 6, 10, 2); ctx.fillRect(sx + 16, sy + 20, 8, 2);
      break;
    }
    case "T": case "X": drawTree(ctx, sx, sy, reg === "forest" || c === "X", h); break;
    case "P": drawPine(ctx, sx, sy, false, h); break;
    case "S": drawPine(ctx, sx, sy, true, h); break;
    case "c": {
      ctx.fillStyle = "rgba(0,0,0,.15)"; ctx.fillRect(sx + 8, sy + 27, 16, 4);
      Kit.brick(ctx, sx + 12, sy + 4, 8, 26, "#3f9a3a", 3);
      Kit.brick(ctx, sx + 4, sy + 14, 9, 5, "#3f9a3a", 2); Kit.brick(ctx, sx + 4, sy + 8, 5, 10, "#3f9a3a", 2);
      Kit.brick(ctx, sx + 19, sy + 11, 9, 5, "#3f9a3a", 2); Kit.brick(ctx, sx + 23, sy + 4, 5, 11, "#3f9a3a", 2);
      break;
    }
    case "r": drawRock(ctx, sx, sy, reg === "snow" ? "#94a3b8" : reg === "dark" ? "#57506a" : reg === "desert" ? "#b08a5a" : "#8b8f96"); break;
    case "M": drawMountain(ctx, sx, sy, reg === "snow" || y < 33 && x > 49, h); break;
    case "D": {
      ctx.fillStyle = "rgba(0,0,0,.2)"; ctx.fillRect(sx + 8, sy + 27, 16, 4);
      ctx.fillStyle = "#4b3f57";
      ctx.fillRect(sx + 14, sy + 6, 5, 24); ctx.fillRect(sx + 6, sy + 10, 9, 3); ctx.fillRect(sx + 6, sy + 4, 3, 8);
      ctx.fillRect(sx + 18, sy + 14, 9, 3); ctx.fillRect(sx + 24, sy + 7, 3, 9);
      break;
    }
    case "L": {
      ctx.fillStyle = "rgba(0,0,0,.15)"; ctx.fillRect(sx + 6, sy + 27, 20, 4);
      ctx.fillStyle = "#9a6a3a";
      for (let i = 0; i < 5; i++) ctx.fillRect(sx + 13 + i * 0.8, sy + 8 + i * 4.5, 6, 5);
      ctx.fillStyle = "#2f9a4a";
      ctx.fillRect(sx + 2, sy + 6, 14, 4); ctx.fillRect(sx + 17, sy + 6, 13, 4); ctx.fillRect(sx + 4, sy + 9, 4, 6); ctx.fillRect(sx + 25, sy + 9, 4, 6);
      ctx.fillRect(sx + 9, sy + 1, 14, 5);
      break;
    }
    case "q": {
      ctx.fillStyle = "#c9a15a"; ctx.fillRect(sx, sy, 32, 32);
      ctx.fillStyle = "#a57d3d";
      for (let r = 0; r < 4; r++) { ctx.fillRect(sx, sy + r * 8 + 7, 32, 1); ctx.fillRect(sx + (r % 2 ? 8 : 20), sy + r * 8, 1, 8); }
      ctx.fillStyle = "rgba(255,255,255,.15)"; ctx.fillRect(sx, sy, 32, 2);
      break;
    }
    case "Q": case "K": {
      ctx.fillStyle = "#2b2838"; ctx.fillRect(sx, sy, 32, 32);
      ctx.fillStyle = "#3a3549";
      for (let r = 0; r < 4; r++) for (let k = 0; k < 2; k++) ctx.fillRect(sx + 1 + k * 16 + (r % 2) * 8 - (r % 2 && k ? 16 : 0), sy + r * 8 + 1, 14, 6);
      if (tileAt(m, x, y - 1) !== "Q") {
        ctx.fillStyle = "#3a3549";
        for (let k = 0; k < 3; k++) ctx.fillRect(sx + 2 + k * 11, sy - 6, 7, 7);
      }
      if (c === "Q" && h > 0.75) { ctx.fillStyle = `rgba(192,132,252,${0.5 + 0.3 * Math.sin(T * 3 + h * 9)})`; ctx.fillRect(sx + 13, sy + 10, 6, 9); }
      if (c === "K") {
        ctx.fillStyle = "#120a1f"; ctx.beginPath(); ctx.roundRect(sx + 5, sy + 6, 22, 26, [11, 11, 0, 0]); ctx.fill();
        ctx.fillStyle = `rgba(168,85,247,${0.35 + 0.2 * Math.sin(T * 3)})`; ctx.fillRect(sx + 9, sy + 14, 14, 18);
      }
      break;
    }
    case "1": case "2": case "3": {
      const th = TOWN_THEMES[TOWN_ICON[c]];
      ctx.fillStyle = "rgba(0,0,0,.18)"; ctx.beginPath(); ctx.ellipse(sx + 16, sy + 28, 26, 7, 0, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = "#b8aa94"; ctx.fillRect(sx + 4, sy + 24, 24, 8);
      drawHouse(ctx, sx - 10, sy - 8, th.roof, th.house, 1.35);
      drawHouse(ctx, sx + 14, sy - 2, th.roof2, th.house, 1.1);
      ctx.fillStyle = "#5b3a1e"; ctx.fillRect(sx + 8, sy - 18, 2, 14);
      ctx.fillStyle = th.awning[0]; ctx.fillRect(sx + 10, sy - 18, 10, 6);
      break;
    }
    case "b": {
      ctx.fillStyle = "#c9a36b"; ctx.fillRect(sx, sy, 32, 32);
      Kit.brick(ctx, sx + 1, sy + 4, 30, 26, "#6b5a4a", 8);
      Kit.brick(ctx, sx + 6, sy - 2, 18, 12, "#7a6857", 5);
      ctx.fillStyle = `rgba(168,85,247,${0.45 + 0.25 * Math.sin(T * 4)})`;
      ctx.fillRect(sx + 9, sy + 12, 3, 12); ctx.fillRect(sx + 18, sy + 8, 3, 14); ctx.fillRect(sx + 12, sy + 18, 8, 3);
      break;
    }
    case "v": {
      ctx.fillStyle = "#c3d0dc"; ctx.fillRect(sx, sy, 32, 32);
      Kit.brick(ctx, sx + 1, sy - 6, 30, 36, "#7dd3fc", 4);
      ctx.fillStyle = "rgba(255,255,255,.55)"; ctx.fillRect(sx + 6, sy - 2, 4, 22); ctx.fillRect(sx + 14, sy + 2, 3, 12);
      break;
    }
    case "g": {
      ctx.fillStyle = "#c9a36b"; ctx.fillRect(sx, sy, 32, 32);
      for (let i = 0; i < 5; i++) {
        const a = T * 2 + i * 1.3;
        ctx.fillStyle = `rgba(${90 + i * 20},40,${160 + i * 15},.55)`;
        ctx.fillRect(sx + 16 + Math.cos(a) * 10 - 6, sy + 16 + Math.sin(a * 1.3) * 10 - 10, 12, 20);
      }
      ctx.fillStyle = "rgba(20,0,40,.45)"; ctx.fillRect(sx, sy - 10, 32, 42);
      break;
    }
    // ----- town tiles
    case "C": {
      ctx.fillStyle = m.theme && m.theme.ground === "sand" ? "#d6c2a0" : m.theme && m.theme.ground === "snow" ? "#cbd5e1" : "#b0a89c";
      ctx.fillRect(sx, sy, 32, 32);
      ctx.fillStyle = "rgba(0,0,0,.12)";
      ctx.fillRect(sx, sy + 15, 32, 2); ctx.fillRect(sx + (y % 2 ? 8 : 22), sy, 2, 15); ctx.fillRect(sx + (y % 2 ? 22 : 8), sy + 17, 2, 15);
      ctx.fillStyle = "rgba(255,255,255,.08)"; ctx.fillRect(sx, sy, 32, 2);
      break;
    }
    case "W": {
      const th = m.theme || TOWN_THEMES.brickhaven;
      if (th.wall === "hedge") {
        drawGround(ctx, "e", m, x, y, sx, sy, h);
        Kit.brick(ctx, sx + 1, sy + 2, 30, 28, h > 0.5 ? "#2b8a3e" : "#2f9444", 6);
        ctx.fillStyle = "rgba(255,255,255,.12)"; ctx.fillRect(sx + 6, sy + 8, 4, 4); ctx.fillRect(sx + 19, sy + 15, 4, 4);
      } else {
        const col = th.wall === "sandstone" ? "#c9a15a" : "#94a3b8";
        ctx.fillStyle = col; ctx.fillRect(sx, sy, 32, 32);
        ctx.fillStyle = "rgba(0,0,0,.18)";
        for (let r = 0; r < 4; r++) { ctx.fillRect(sx, sy + r * 8 + 7, 32, 1); ctx.fillRect(sx + (r % 2 ? 8 : 24), sy + r * 8, 1, 8); }
        if (th.wall === "snowstone") { ctx.fillStyle = "#f8fafc"; ctx.fillRect(sx, sy, 32, 6); }
      }
      break;
    }
    case "R": {
      const th = m.theme;
      const top = tileAt(m, x, y - 1) !== "R";
      ctx.fillStyle = th.roof; ctx.fillRect(sx, sy, 32, 32);
      ctx.fillStyle = th.roof2;
      for (let r = 0; r < 4; r++) ctx.fillRect(sx, sy + r * 8 + 6, 32, 2);
      for (let r = 0; r < 4; r++) ctx.fillRect(sx + ((r + y) % 2 ? 6 : 22), sy + r * 8, 2, 6);
      if (top) { ctx.fillStyle = shadeHex(th.roof, 0.12); ctx.fillRect(sx, sy, 32, 4); }
      if (tileAt(m, x - 1, y) !== "R") { ctx.fillStyle = "rgba(0,0,0,.2)"; ctx.fillRect(sx, sy, 3, 32); }
      if (tileAt(m, x + 1, y) !== "R") { ctx.fillStyle = "rgba(0,0,0,.2)"; ctx.fillRect(sx + 29, sy, 3, 32); }
      if (th.ground === "snow" && top) { ctx.fillStyle = "#f8fafc"; ctx.fillRect(sx, sy, 32, 7); }
      break;
    }
    case "H": case "n": {
      const th = m.theme;
      ctx.fillStyle = th.house; ctx.fillRect(sx, sy, 32, 32);
      ctx.fillStyle = "rgba(0,0,0,.08)"; ctx.fillRect(sx, sy + 15, 32, 1);
      if (tileAt(m, x, y - 1) === "R") { ctx.fillStyle = "rgba(0,0,0,.25)"; ctx.fillRect(sx, sy, 32, 5); }
      if (c === "n") {
        Kit.brick(ctx, sx + 7, sy + 6, 18, 26, "#7c4a1e", 3);
        ctx.fillStyle = "#facc15"; ctx.fillRect(sx + 20, sy + 19, 3, 3);
      } else if (tileAt(m, x, y + 1) !== "H" && h > 0.35) {
        ctx.fillStyle = "#5b3a1e"; ctx.fillRect(sx + 7, sy + 7, 18, 16);
        ctx.fillStyle = "#93c5fd"; ctx.fillRect(sx + 9, sy + 9, 14, 12);
        ctx.fillStyle = "#5b3a1e"; ctx.fillRect(sx + 15, sy + 9, 2, 12);
      }
      break;
    }
    case "A": {
      const th = m.theme;
      drawGround(ctx, "C", m, x, y, sx, sy, h);
      ctx.fillStyle = "#b0a89c"; ctx.fillRect(sx, sy, 32, 32);
      for (let i = 0; i < 4; i++) { ctx.fillStyle = th.awning[i % 2]; ctx.fillRect(sx + i * 8, sy + 4, 8, 22); }
      ctx.fillStyle = th.awning[0];
      for (let i = 0; i < 4; i++) { ctx.beginPath(); ctx.arc(sx + i * 8 + 4, sy + 26, 4, 0, Math.PI); ctx.fill(); }
      ctx.fillStyle = "rgba(255,255,255,.2)"; ctx.fillRect(sx, sy + 4, 32, 3);
      break;
    }
    case "k": {
      ctx.fillStyle = m.theme && m.theme.ground === "sand" ? "#d6c2a0" : "#b0a89c"; ctx.fillRect(sx, sy, 32, 32);
      Kit.brick(ctx, sx, sy + 6, 32, 24, "#9a6a3a", 3);
      ctx.fillStyle = "#c08a50"; ctx.fillRect(sx, sy + 6, 32, 5);
      break;
    }
    case "O": {
      ctx.fillStyle = "#b0a89c"; ctx.fillRect(sx, sy, 32, 32);
      const L = tileAt(m, x - 1, y) !== "O", Tp = tileAt(m, x, y - 1) !== "O";
      ctx.fillStyle = "#94a3b8"; ctx.fillRect(sx, sy, 32, 32);
      ctx.fillStyle = "#3b8fe0"; ctx.fillRect(sx + (L ? 5 : 0), sy + (Tp ? 5 : 0), 32 - 5, 32 - 5);
      ctx.fillStyle = "rgba(255,255,255,.5)";
      const o = (T * 10 + h * 20) % 20;
      ctx.fillRect(sx + 6 + o * 0.6, sy + 12, 6, 2);
      if (!L && !Tp) { // spout in the middle of the 2x2
        ctx.fillStyle = "#cbd5e1"; ctx.fillRect(sx - 4, sy - 10, 8, 14);
        ctx.fillStyle = `rgba(191,227,255,${0.6 + 0.3 * Math.sin(T * 8)})`; ctx.fillRect(sx - 2, sy - 18, 4, 9);
      }
      break;
    }
    case "F": {
      drawGround(ctx, "e", m, x, y, sx, sy, h);
      ctx.fillStyle = "#a86f38"; ctx.fillRect(sx, sy + 12, 32, 4); ctx.fillRect(sx, sy + 22, 32, 4);
      ctx.fillRect(sx + 4, sy + 8, 4, 22); ctx.fillRect(sx + 24, sy + 8, 4, 22);
      break;
    }
    // ----- castle tiles
    case "#": case "t": {
      ctx.fillStyle = "#211d2b"; ctx.fillRect(sx, sy, 32, 32);
      ctx.fillStyle = "#2d2839";
      for (let r = 0; r < 4; r++) for (let bx = -((r % 2) * 8); bx < 32; bx += 16) {
        const a = Math.max(0, bx + 1), b = Math.min(32, bx + 15);
        if (b > a) ctx.fillRect(sx + a, sy + r * 8 + 1, b - a, 6);
      }
      if (tileAt(m, x, y + 1) !== "#" && tileAt(m, x, y + 1) !== "t") { ctx.fillStyle = "rgba(0,0,0,.35)"; ctx.fillRect(sx, sy + 28, 32, 4); }
      if (c === "t") {
        ctx.fillStyle = "#57534e"; ctx.fillRect(sx + 13, sy + 14, 6, 12);
        const f = Math.sin(T * 12 + h * 7) * 2;
        ctx.fillStyle = "#fb923c"; ctx.fillRect(sx + 11, sy + 4 - f, 10, 11 + f);
        ctx.fillStyle = "#fde047"; ctx.fillRect(sx + 14, sy + 8 - f * 0.5, 4, 6);
        ctx.fillStyle = "rgba(251,146,60,.08)"; ctx.beginPath(); ctx.arc(sx + 16, sy + 12, 30, 0, Math.PI * 2); ctx.fill();
      }
      break;
    }
    case "u": {
      drawGround(ctx, "o", m, x, y, sx, sy, h);
      ctx.fillStyle = "#9f1239"; ctx.fillRect(sx + 3, sy, 26, 32);
      ctx.fillStyle = "#facc15"; ctx.fillRect(sx + 3, sy, 2, 32); ctx.fillRect(sx + 27, sy, 2, 32);
      break;
    }
    case "I": {
      ctx.fillStyle = "rgba(0,0,0,.3)"; ctx.fillRect(sx + 4, sy + 26, 26, 6);
      Kit.brick(ctx, sx + 6, sy - 14, 20, 44, "#4b4560", 3);
      ctx.fillStyle = "#5c5574"; ctx.fillRect(sx + 3, sy - 16, 26, 6); ctx.fillRect(sx + 3, sy + 24, 26, 6);
      break;
    }
    case "Z": {
      if (x === 16) {
        Kit.brick(ctx, sx + 2, sy - 22, 28, 52, "#4c1d95", 5);
        Kit.brick(ctx, sx + 6, sy - 16, 20, 30, "#6d28d9", 4);
        ctx.fillStyle = "#facc15"; ctx.fillRect(sx + 4, sy - 26, 4, 6); ctx.fillRect(sx + 14, sy - 30, 4, 8); ctx.fillRect(sx + 24, sy - 26, 4, 6);
      } else {
        Kit.brick(ctx, sx + (x < 16 ? 10 : 0), sy + 4, 22, 24, "#4c1d95", 4);
      }
      break;
    }
    case "h": {
      const p = Math.sin(T * 3) * 0.5 + 0.5;
      ctx.fillStyle = "#94a3b8"; ctx.beginPath(); ctx.ellipse(sx + 16, sy + 18, 15, 10, 0, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = `rgba(103,232,249,${0.55 + p * 0.35})`;
      ctx.beginPath(); ctx.ellipse(sx + 16, sy + 18, 12, 7, 0, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = `rgba(103,232,249,${0.12 + p * 0.1})`; ctx.beginPath(); ctx.arc(sx + 16, sy + 16, 26, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = "#e0f2fe";
      for (let i = 0; i < 3; i++) { const k = (T * 0.8 + i / 3) % 1; ctx.fillRect(sx + 8 + i * 7, sy + 18 - k * 22, 3, 3); }
      break;
    }
    default:
      drawGround(ctx, groundChar(m, x, y), m, x, y, sx, sy, h);
  }
}

// Colour of a tile on the M map.
function miniColor(m, x, y) {
  const c = tileAt(m, x, y);
  const reg = regionAt(m, x, y);
  switch (c) {
    case "~": return "#2f7fd6";
    case "=": return "#a86f38";
    case "_": case "x": return m.town ? "#cbbfa8" : "#d9b77d";
    case "T": case "X": case "P": return reg === "forest" ? "#1c5a2b" : "#2d8a3e";
    case "S": return "#2f6b55";
    case "M": return reg === "snow" ? "#cbd5e1" : "#7c6f64";
    case "c": return "#3f9a3a";
    case "D": case "r": return "#6b6478";
    case "l": return "#ea580c";
    case "q": return "#b8904a";
    case "Q": case "K": return "#120a1f";
    case "1": case "2": case "3": return "#ef4444";
    case "b": case "g": return "#a855f7";
    case "v": return "#7dd3fc";
    case "#": case "t": return "#211d2b";
    case "W": return "#2b8a3e";
    case "R": return m.theme ? m.theme.roof : "#d9483b";
    case "H": case "n": return m.theme ? m.theme.house : "#eee";
    case "A": case "k": return "#9a6a3a";
    case "O": return "#3b8fe0";
    case "C": return "#b0a89c";
    case "u": return "#9f1239";
    case "I": case "Z": return "#4c1d95";
    case "h": return "#67e8f9";
    case "i": return "#bfe3f5";
  }
  if (c === "e" || c === ",") return m.theme ? m.theme.groundC : "#5bb450";
  return groundColor(groundChar(m, x, y) === c ? c : c, m, x, y);
}
