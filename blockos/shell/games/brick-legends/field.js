/* Brick Legends: exploring the field - movement, NPCs, objects, menus, shops, the inn, saving. */
"use strict";

const STEP_TIME = 0.17;
const DIRS = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] };
const NPCS = {};   // map id -> npc list (filled by story.js)
const OBJS = {};   // map id -> object list

function curMap() { return MAPS[G.s.map]; }
function npcsHere() { return (NPCS[G.s.map] || []).filter((n) => !n.cond || n.cond()); }
function objsHere() { return (OBJS[G.s.map] || []).filter((o) => !o.cond || o.cond()); }

function placeParty(x, y, dir) {
  G.p = { x, y, fx: x, fy: y, t: 1, dir: dir || "down", phase: 0, moving: false };
  G.fol = G.s.party.slice(1).map(() => ({ x, y, fx: x, fy: y, dir: dir || "down" }));
}
function syncFollowers() {
  while (G.fol.length < G.s.party.length - 1) G.fol.push({ x: G.p.x, y: G.p.y, fx: G.p.x, fy: G.p.y, dir: G.p.dir });
}
function objBlocks(o) { return o.type === "chest" || o.type === "boss" || o.type === "sign" || o.type === "crystal"; }
function walkable(m, x, y, self) {
  if (x < 0 || y < 0 || x >= m.w || y >= m.h) return false;
  if (SOLID.has(tileAt(m, x, y))) return false;
  if (npcsHere().some((n) => n !== self && n.x === x && n.y === y)) return false;
  if (objsHere().some((o) => objBlocks(o) && o.x === x && o.y === y)) return false;
  if (self && G.p && ((G.p.x === x && G.p.y === y) || (G.p.fx === x && G.p.fy === y))) return false;
  return true;
}
function canControl() { return G.scene === "field" && !G.ui.length && !G.busy && G.fade === 0; }

function tryStep(d) {
  const p = G.p, m = curMap();
  p.dir = d;
  const nx = p.x + DIRS[d][0], ny = p.y + DIRS[d][1];
  if (!walkable(m, nx, ny)) return false;
  syncFollowers();
  for (let i = G.fol.length - 1; i >= 0; i--) {
    const f = G.fol[i];
    const lead = i === 0 ? { x: p.x, y: p.y } : { x: G.fol[i - 1].x, y: G.fol[i - 1].y };
    f.fx = f.x; f.fy = f.y;
    if (f.x !== lead.x || f.y !== lead.y) {
      f.dir = lead.x > f.x ? "right" : lead.x < f.x ? "left" : lead.y > f.y ? "down" : "up";
    }
    f.x = lead.x; f.y = lead.y;
  }
  p.fx = p.x; p.fy = p.y; p.x = nx; p.y = ny; p.t = 0; p.moving = true;
  return true;
}

function fieldUpdate(dt) {
  const p = G.p;
  if (!p) return;
  if (p.moving) {
    p.t += dt / STEP_TIME;
    p.phase += dt * 13;
    if (p.t >= 1) { p.t = 1; p.moving = false; G.fol.forEach((f) => { f.fx = f.x; f.fy = f.y; }); arrive(); }
  }
  if (!p.moving && canControl()) {
    const d = heldDir();
    if (d) { if (!tryStep(d)) p.phase = 0; } else p.phase = 0;
  }
  // NPC wandering
  for (const n of npcsHere()) {
    if (n.t < 1) { n.t = Math.min(1, n.t + dt / 0.35); n.phase = (n.phase || 0) + dt * 10; if (n.t >= 1) n.phase = 0; continue; }
    if (!n.wander || G.talking === n) continue;
    n.wt = (n.wt || Math.random() * 3) - dt;
    if (n.wt > 0) continue;
    n.wt = 1.5 + Math.random() * 3;
    const d = Kit.pick(Object.keys(DIRS));
    n.dir = d;
    const nx = n.x + DIRS[d][0], ny = n.y + DIRS[d][1];
    if (Math.abs(nx - n.home[0]) + Math.abs(ny - n.home[1]) <= n.wander && walkable(curMap(), nx, ny, n) && tileAt(curMap(), nx, ny) !== "x") {
      n.fx = n.x; n.fy = n.y; n.x = nx; n.y = ny; n.t = 0;
    }
  }
  if (G.banner) { G.banner.t += dt; if (G.banner.t > 3) G.banner = null; }
}

async function arrive() {
  const m = curMap(), p = G.p;
  const key = p.x + "," + p.y;
  if (m.warps[key]) { const w = m.warps[key]; await warpTo(w.map, w.x, w.y, w.dir); return; }
  const c = tileAt(m, p.x, p.y);
  if (c === "h") {
    G.busy = true;
    healAll(); Music.sfx("heal");
    await notice("The glowing spring washes over the party. HP and MP fully restored!");
    G.busy = false;
    return;
  }
  for (const o of objsHere()) {
    if (o.type === "pickup" && o.x === p.x && o.y === p.y && !G.s.opened[o.id]) { G.busy = true; await o.take(); G.busy = false; return; }
  }
  if (m.id === "world") {
    const reg = regionAt(m, p.x, p.y);
    if (reg !== G.lastRegion) {
      G.lastRegion = reg;
      G.banner = { text: REGION_NAME[reg], t: 0 };
      Music.play(reg === "dark" ? "castle" : "field");
    }
  }
  // random encounters
  const reg = m.id === "world" ? regionAt(m, p.x, p.y) : m.id === "castle" && p.y >= 20 ? "castle" : null;
  if (reg && !G.noEncounters) {
    G.s.enc -= c === "_" || c === "=" ? 0.6 : 1;
    if (G.s.enc <= 0) {
      G.s.enc = Kit.randInt(14, 26);
      await randomBattle(reg);
    }
  }
}

async function randomBattle(reg) {
  const E = ENCOUNTERS[reg];
  let n = Kit.randInt(E.min, E.max);
  if (E.max3 && Math.random() < E.max3) n = 3;
  const group = [];
  for (let i = 0; i < n; i++) {
    let k = Kit.pick(E.pool);
    if (ENEMIES[k].big && group.some((g) => ENEMIES[g].big)) k = E.pool[0];
    group.push(k);
  }
  if (group.some((g) => ENEMIES[g].big) && group.length > 2) group.length = 2;
  return battleFlow(group, { bg: E.bg });
}

// Runs a whole battle from the field and returns its result.
async function battleFlow(group, o) {
  G.busy = true;
  Kit.sfx("jump");
  G.trans = 0;
  await anim(550, (p) => { G.trans = p; });
  const pr = startBattle(group, o || {});
  G.trans = 0;
  const r = await pr;
  if (r === "lose") { await defeatFlow(); G.busy = false; return r; }
  G.scene = "field";
  Music.play(fieldMusic());
  G.fade = 1;
  await fadeIn(300);
  G.busy = false;
  updateHud();
  return r;
}
function fieldMusic() {
  const m = curMap();
  if (m.id === "world") return regionAt(m, G.p.x, G.p.y) === "dark" ? "castle" : "field";
  return m.music;
}

async function defeatFlow() {
  G.scene = "gameover";
  Music.play("castle");
  await wait(600);
  await waitConfirm();
  G.s.gold = Math.floor(G.s.gold / 2);
  const inn = G.s.lastInn;
  healAll();
  G.s.map = inn.map;
  placeParty(inn.x, inn.y, "down");
  G.scene = "field";
  G.lastRegion = null;
  Music.play(fieldMusic());
  G.fade = 1;
  await fadeIn(500);
  await notice("You wake up at the inn, bruised but alive. Half of your gold was lost...");
  updateHud();
}

async function warpTo(map, x, y, dir) {
  G.busy = true;
  await fadeOut(250);
  G.s.map = map;
  placeParty(x, y, dir);
  const m = curMap();
  G.lastRegion = m.id === "world" ? regionAt(m, x, y) : null;
  G.banner = { text: m.id === "world" ? REGION_NAME[G.lastRegion] : m.name, t: 0 };
  Music.play(fieldMusic());
  await fadeIn(250);
  G.busy = false;
  if (m.onEnter) await m.onEnter();
}

// ------------------------------------------------------------------ interaction
function facing() {
  const p = G.p, d = DIRS[p.dir];
  return [p.x + d[0], p.y + d[1]];
}
function thingAt(x, y) {
  const n = npcsHere().find((n) => n.x === x && n.y === y);
  if (n) return { npc: n };
  const o = objsHere().find((o) => o.x === x && o.y === y && (objBlocks(o)));
  if (o) return { obj: o };
  return null;
}
function interactTarget() {
  const [fx, fy] = facing();
  const m = curMap();
  let t = thingAt(fx, fy);
  if (t) return t;
  if (tileAt(m, fx, fy) === "k") {
    const d = DIRS[G.p.dir];
    t = thingAt(fx + d[0], fy + d[1]);
    if (t) return t;
    const n = npcsHere().find((n) => n.counter && Math.abs(n.x - fx) <= 2 && Math.abs(n.y - fy) <= 1);
    if (n) return { npc: n };
  }
  const tc = tileAt(m, fx, fy);
  if (tc === "n") return { door: true };
  if (tc === "b" || tc === "v" || tc === "g") return { barrier: tc };
  return null;
}
async function interact() {
  const t = interactTarget();
  if (!t) return;
  G.busy = true;
  try {
    if (t.npc) {
      const n = t.npc;
      const old = n.dir;
      const p = G.p;
      if (!n.counter) n.dir = p.x > n.x ? "right" : p.x < n.x ? "left" : p.y > n.y ? "down" : "up";
      G.talking = n;
      await n.talk(n);
      G.talking = null;
      if (n.fixedDir) n.dir = old;
    } else if (t.obj) {
      await t.obj.use(t.obj);
    } else if (t.barrier) {
      await notice({ b: "A cursed boulder blocks the bridge. Dark energy pulses inside it... Maybe a crystal's light could break the curse.",
        v: "A thick wall of magic ice seals the pass. It would take the warmth of the sun to melt it.",
        g: "A wall of living shadow seals the bridge. Only the light of all three crystals could break it." }[t.barrier]);
    } else if (t.door) {
      await notice("The door is locked. Nobody seems to be home.");
    }
  } catch (e) { console.error(e); }
  G.busy = false;
  updateHud();
}
function fieldKey(k) {
  if (!canControl() || G.p.moving) return;
  if (k === "ok") interact();
  else if (k === "menu" || k === "back") openMenu();
  else if (k === "map") openMap();
}

// ------------------------------------------------------------------ drawing
function camera() {
  const m = curMap(), p = G.p;
  const px = (p.fx + (p.x - p.fx) * p.t) * TILE, py = (p.fy + (p.y - p.fy) * p.t) * TILE;
  const cam = (pos, size, view) => size * TILE <= view ? Math.round((size * TILE - view) / 2) : Math.round(Kit.clamp(pos + 16 - view / 2, 0, size * TILE - view));
  return { x: cam(px, m.w, VW), y: cam(py, m.h, VH), px, py };
}
function drawField(ctx) {
  const m = curMap();
  const cam = camera();
  ctx.fillStyle = m.id === "world" ? "#2f7fd6" : "#0b0812";
  ctx.fillRect(0, 0, VW, VH);
  const x0 = Math.floor(cam.x / TILE) - 1, y0 = Math.floor(cam.y / TILE) - 1;
  const x1 = x0 + VW / TILE + 3, y1 = y0 + VH / TILE + 3;
  for (let y = Math.max(0, y0); y < Math.min(m.h, y1); y++)
    for (let x = Math.max(0, x0); x < Math.min(m.w, x1); x++)
      drawTile(ctx, m, x, y, x * TILE - cam.x, y * TILE - cam.y, G.T);
  for (const l of m.labels) {
    ctx.font = `bold ${l.small ? 11 : 14}px ${FONT}`;
    const w = ctx.measureText(l.text).width + 12;
    const lx = l.x * TILE - cam.x, ly = l.y * TILE - cam.y;
    ctx.fillStyle = "#5b3a1e"; ctx.beginPath(); ctx.roundRect(lx - w / 2, ly - 10, w, 20, 4); ctx.fill();
    txt(ctx, l.text, lx, ly + 5, { size: l.small ? 11 : 14, align: "center", color: "#fde68a", shadow: false });
  }
  // sprites sorted by y
  const sprites = [];
  for (const o of objsHere()) sprites.push({ y: o.y, draw: () => drawObj(ctx, o, o.x * TILE - cam.x, o.y * TILE - cam.y) });
  for (const n of npcsHere()) {
    const nx = (n.fx + (n.x - n.fx) * n.t) * TILE - cam.x, ny = (n.fy + (n.y - n.fy) * n.t) * TILE - cam.y;
    sprites.push({ y: n.fy + (n.y - n.fy) * n.t, draw: () => drawNpc(ctx, n, nx + 16, ny + 29) });
  }
  const p = G.p;
  G.fol.forEach((f, i) => {
    const m2 = G.s.party[i + 1];
    if (!m2) return;
    const fx = (f.fx + (f.x - f.fx) * p.t) * TILE - cam.x, fy = (f.fy + (f.y - f.fy) * p.t) * TILE - cam.y;
    const still = f.fx === f.x && f.fy === f.y;
    sprites.push({ y: f.fy + (f.y - f.fy) * p.t - 0.01 * (i + 1), draw: () => drawWalker(ctx, memberLook(m2), fx + 16, fy + 29, f.dir, still ? 0 : p.phase, 34) });
  });
  sprites.push({ y: p.fy + (p.y - p.fy) * p.t + 0.001, draw: () => drawWalker(ctx, G.heroLook, cam.px - cam.x + 16, cam.py - cam.y + 29, p.dir, p.moving ? p.phase : 0, 34) });
  sprites.sort((a, b) => a.y - b.y).forEach((s) => s.draw());
  // interaction hint
  if (canControl() && !p.moving) {
    const t = interactTarget();
    if (t && (t.npc || t.obj)) {
      const tx = t.npc ? t.npc.x : t.obj.x, ty = t.npc ? t.npc.y : t.obj.y;
      const bx = tx * TILE - cam.x + 16, by = ty * TILE - cam.y - 22 + Math.sin(G.T * 5) * 2;
      ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.roundRect(bx - 14, by - 14, 28, 20, 6); ctx.fill();
      ctx.beginPath(); ctx.moveTo(bx - 4, by + 6); ctx.lineTo(bx + 4, by + 6); ctx.lineTo(bx, by + 11); ctx.fill();
      txt(ctx, "...", bx, by + 1, { size: 15, align: "center", color: "#111", shadow: false });
    }
  }
  // tints
  const reg = m.id === "world" ? regionAt(m, p.x, p.y) : m.region;
  if (reg === "dark" || reg === "castle") { ctx.fillStyle = "rgba(40,10,70,.18)"; ctx.fillRect(0, 0, VW, VH); }
  if (reg === "snow") { ctx.fillStyle = "rgba(255,255,255,.7)"; for (let i = 0; i < 30; i++) ctx.fillRect((i * 131 + G.T * 25) % VW, (i * 71 + G.T * 45) % VH, 3, 3); }
  // banner
  if (G.banner) {
    const a = Math.min(1, G.banner.t * 3, (3 - G.banner.t) * 2);
    ctx.globalAlpha = Math.max(0, a);
    ctx.font = `bold 20px ${FONT}`;
    const w = ctx.measureText(G.banner.text).width + 60;
    panel(ctx, VW / 2 - w / 2, 18, w, 44, { top: "#0f172a", bottom: "#0b1220", border: "#fde68a" });
    txt(ctx, G.banner.text, VW / 2, 47, { size: 20, align: "center", color: "#fde68a" });
    ctx.globalAlpha = 1;
  }
  // buttons
  if (!G.ui.length) {
    const btn = (x, label, fn) => {
      Kit.brick(ctx, x, VH - 40, 104, 30, "rgba(15,23,42,.82)", 8);
      txt(ctx, label, x + 52, VH - 20, { size: 14, align: "center" });
      hit(x, VH - 40, 104, 30, () => { if (canControl() && !G.p.moving) fn(); });
    };
    drawOwner = "field";
    btn(VW - 228, "Menu (Q)", openMenu);
    btn(VW - 116, "Map (M)", openMap);
    drawOwner = null;
  }
}
function drawNpc(ctx, n, x, y) {
  if (n.art) { drawMonster(ctx, n.art, n.col, x, y + 2, n.scale || 3, G.T); return; }
  drawWalker(ctx, n.look, x, y, n.dir, n.t < 1 ? n.phase : 0, n.h || 34);
}
function drawObj(ctx, o, sx, sy) {
  const T = G.T;
  if (o.type === "chest") {
    const open = G.s.opened[o.id];
    ctx.fillStyle = "rgba(0,0,0,.25)"; ctx.fillRect(sx + 4, sy + 24, 24, 6);
    Kit.brick(ctx, sx + 4, sy + 12, 24, 16, "#a0522d", 3);
    if (open) { ctx.fillStyle = "#3b1d0e"; ctx.fillRect(sx + 6, sy + 10, 20, 5); Kit.brick(ctx, sx + 4, sy + 2, 24, 8, "#b8662f", 2); }
    else { Kit.brick(ctx, sx + 3, sy + 6, 26, 10, "#b8662f", 3); ctx.fillStyle = "#facc15"; ctx.fillRect(sx + 14, sy + 12, 5, 7); }
  } else if (o.type === "pickup") {
    if (G.s.opened[o.id]) return;
    const b = Math.sin(T * 4 + o.x) * 2;
    ctx.fillStyle = "rgba(0,0,0,.2)"; ctx.beginPath(); ctx.ellipse(sx + 16, sy + 26, 7, 3, 0, 0, Math.PI * 2); ctx.fill();
    if (o.item === "glowcap") { Kit.brick(ctx, sx + 13, sy + 14 + b, 6, 10, "#fef3c7", 2); Kit.brick(ctx, sx + 8, sy + 8 + b, 16, 8, "#67e8f9", 4); }
    else { ctx.fillStyle = "#e2e8f0"; ctx.beginPath(); ctx.arc(sx + 16, sy + 16 + b, 6, 0, Math.PI * 2); ctx.fill(); ctx.fillStyle = "#93c5fd"; ctx.fillRect(sx + 14, sy + 14 + b, 4, 4); }
    const a = (Math.sin(T * 6 + o.y) + 1) / 2;
    ctx.fillStyle = `rgba(255,255,255,${a})`; ctx.fillRect(sx + 22, sy + 4 + b, 3, 9); ctx.fillRect(sx + 19, sy + 7 + b, 9, 3);
  } else if (o.type === "sign") {
    ctx.fillStyle = "#6b3f1d"; ctx.fillRect(sx + 14, sy + 14, 4, 16);
    Kit.brick(ctx, sx + 4, sy + 4, 24, 14, "#b8864f", 3);
    ctx.fillStyle = "#5b3a1e"; ctx.fillRect(sx + 8, sy + 9, 16, 2); ctx.fillRect(sx + 8, sy + 13, 12, 2);
  } else if (o.type === "boss") {
    drawMonster(ctx, ENEMIES[o.enemy].art, ENEMIES[o.enemy].col, sx + 16, sy + 30, o.scale || 3.4, T, { boss: true });
  } else if (o.type === "crystal") {
    const b = Math.sin(T * 3) * 3;
    ctx.fillStyle = `rgba(${o.glow},${0.25 + 0.15 * Math.sin(T * 4)})`; ctx.beginPath(); ctx.arc(sx + 16, sy + 12 + b, 18, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = o.col; ctx.beginPath(); ctx.moveTo(sx + 16, sy - 4 + b); ctx.lineTo(sx + 26, sy + 12 + b); ctx.lineTo(sx + 16, sy + 28 + b); ctx.lineTo(sx + 6, sy + 12 + b); ctx.fill();
    ctx.fillStyle = "rgba(255,255,255,.6)"; ctx.fillRect(sx + 12, sy + 6 + b, 3, 10);
  }
}

// ------------------------------------------------------------------ HUD
function updateHud() {
  if (!G.s) { Kit.hud(""); return; }
  const loc = curMap().id === "world" && G.p ? REGION_NAME[regionAt(curMap(), G.p.x, G.p.y)] : curMap().name;
  Kit.hud(`${G.heroName} - Lv ${hero().level}<small>${G.s.gold} gold - ${loc}</small>`);
}

// ------------------------------------------------------------------ the M map
function openMap() {
  Kit.sfx("click");
  const w = {
    key(k) { if (k === "back" || k === "map" || k === "ok" || k === "menu") { Kit.sfx("click"); closeUI(w); } },
    draw(ctx) {
      const m = curMap();
      ctx.fillStyle = "rgba(5,8,20,.85)"; ctx.fillRect(0, 0, VW, VH);
      const sc = Math.floor(Math.min((VW - 80) / m.w, (VH - 110) / m.h));
      const ox = Math.round((VW - m.w * sc) / 2), oy = 70 + Math.round((VH - 100 - m.h * sc) / 2);
      panel(ctx, ox - 14, oy - 14, m.w * sc + 28, m.h * sc + 28, { top: "#3b2a1a", bottom: "#2a1d10", border: "#d6b37a" });
      for (let y = 0; y < m.h; y++) for (let x = 0; x < m.w; x++) { ctx.fillStyle = miniColor(m, x, y); ctx.fillRect(ox + x * sc, oy + y * sc, sc, sc); }
      txt(ctx, m.id === "world" ? "Map of Blockara" : m.name, VW / 2, 44, { size: 24, align: "center", color: "#fde68a" });
      if (m.id === "world") {
        [["Brickhaven", 46, 58], ["Sandstone", 74, 54], ["Frostpeak", 68, 14], ["Hollow Castle", 27, 5]].forEach(([n, x, y]) =>
          txt(ctx, n, ox + x * sc + sc / 2, oy + y * sc - 6, { size: 13, align: "center" }));
      }
      const obj = objective();
      if (obj && obj.map === m.id) {
        const s = 6 + Math.sin(G.T * 6) * 2;
        ctx.fillStyle = "#facc15"; ctx.strokeStyle = "#78350f"; ctx.lineWidth = 2;
        const cx = ox + obj.x * sc + sc / 2, cy = oy + obj.y * sc + sc / 2;
        ctx.beginPath();
        for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + i * Math.PI / 5, r = i % 2 ? s * 0.45 : s * 1.4; ctx.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r); }
        ctx.closePath(); ctx.fill(); ctx.stroke();
      }
      if (Math.floor(G.T * 3) % 2 === 0) {
        ctx.fillStyle = "#fff"; ctx.strokeStyle = "#ef4444"; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(ox + G.p.x * sc + sc / 2, oy + G.p.y * sc + sc / 2, Math.max(4, sc * 0.8), 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      }
      txt(ctx, obj ? "Goal: " + obj.text : "", VW / 2, VH - 14, { size: 15, align: "center", color: "#fde68a" });
      hit(0, 0, VW, VH, () => w.key("back"));
    },
  };
  pushUI(w);
}

// ------------------------------------------------------------------ menus
const MENU_X = 16, MENU_Y = 16, MENU_W = 704, MENU_H = 544;
function drawPartyOverview(ctx) {
  panel(ctx, MENU_X, MENU_Y, MENU_W, MENU_H);
  G.s.party.forEach((m, i) => {
    const y = MENU_Y + 20 + i * 130;
    const st = stats(m);
    ctx.fillStyle = "rgba(255,255,255,.05)"; ctx.beginPath(); ctx.roundRect(MENU_X + 16, y, MENU_W - 32, 118, 10); ctx.fill();
    drawWalker(ctx, memberLook(m), MENU_X + 70, y + 104, "down", 0, 80);
    txt(ctx, memberName(m), MENU_X + 130, y + 32, { size: 22 });
    txt(ctx, `${CLASSES[m.id].title}   Lv ${m.level}`, MENU_X + 130, y + 56, { size: 15, color: "#cbd5e1" });
    txt(ctx, `XP to next: ${xpNeed(m.level) - m.xp}`, MENU_X + 130, y + 80, { size: 14, color: "#94a3b8" });
    txt(ctx, "HP", MENU_X + 360, y + 38, { size: 14, color: "#94a3b8" });
    bar(ctx, MENU_X + 392, y + 26, 200, 14, m.hp, st.maxHp, hpColor(m.hp, st.maxHp));
    txt(ctx, `${m.hp} / ${st.maxHp}`, MENU_X + 670, y + 40, { size: 15, align: "right" });
    txt(ctx, "MP", MENU_X + 360, y + 72, { size: 14, color: "#94a3b8" });
    bar(ctx, MENU_X + 392, y + 60, 200, 14, m.mp, st.maxMp, "#3b82f6");
    txt(ctx, `${m.mp} / ${st.maxMp}`, MENU_X + 670, y + 74, { size: 15, align: "right" });
    bar(ctx, MENU_X + 130, y + 92, 200, 6, m.xp, xpNeed(m.level), "#facc15");
  });
  if (G.s.party.length < 3) txt(ctx, "More companions may join your journey...", MENU_X + MENU_W / 2, MENU_Y + 20 + G.s.party.length * 130 + 60, { size: 16, align: "center", color: "#64748b" });
}
function fmtTime(sec) { const h = Math.floor(sec / 3600), m = Math.floor(sec / 60) % 60; return `${h}:${String(m).padStart(2, "0")}`; }

function openMenu() {
  if (!canControl()) return;
  Kit.sfx("click");
  const items = [
    { label: "Status", id: "status" }, { label: "Items", id: "items" }, { label: "Equip", id: "equip" },
    { label: "Quests", id: "quests" }, { label: "Map", id: "map" }, { label: "Save", id: "save" }, { label: "Close", id: "close" },
  ];
  const bg = { key() {}, draw(ctx) { drawPartyOverview(ctx); } };
  pushUI(bg);
  const w = makeList({
    x: 736, y: 16, w: 208, items, rowH: 34, size: 18,
    onCancel: () => { closeUI(w); closeUI(bg); },
    onMenu: () => { closeUI(w); closeUI(bg); },
    onPick: async (it) => {
      if (it.id === "close") { closeUI(w); closeUI(bg); }
      else if (it.id === "status") openStatus(0);
      else if (it.id === "items") openItems();
      else if (it.id === "equip") pickMember("Equip whom?", (m) => openEquip(m));
      else if (it.id === "quests") openQuests();
      else if (it.id === "map") openMap();
      else if (it.id === "save") {
        const ok = saveGame();
        await notice(ok ? "Your journey has been saved." : "Saving failed: storage is not available.");
      }
    },
    after(ctx) {
      panel(ctx, 736, 290, 208, 130);
      txt(ctx, "Gold", 756, 322, { size: 14, color: "#94a3b8" });
      txt(ctx, String(G.s.gold), 924, 322, { size: 18, align: "right", color: "#fde68a" });
      txt(ctx, "Time", 756, 352, { size: 14, color: "#94a3b8" });
      txt(ctx, fmtTime(G.s.playTime), 924, 352, { size: 16, align: "right" });
      txt(ctx, "Crystals", 756, 382, { size: 14, color: "#94a3b8" });
      [["crystal_forest", "#4ade80"], ["crystal_sun", "#facc15"], ["crystal_frost", "#7dd3fc"]].forEach(([id, c], i) => {
        const x = 870 + i * 20, y = 377;
        ctx.globalAlpha = itemCount(id) ? 1 : 0.2;
        ctx.fillStyle = c; ctx.beginPath(); ctx.moveTo(x, y - 9); ctx.lineTo(x + 6, y); ctx.lineTo(x, y + 9); ctx.lineTo(x - 6, y); ctx.fill();
        ctx.globalAlpha = 1;
      });
      txt(ctx, "N: music on/off", 756, 408, { size: 12, color: "#64748b" });
    },
  });
  pushUI(w);
}

function pickMember(title, fn, filter) {
  const w = makeList({
    x: MENU_X + 180, y: 150, w: 340, title, rowH: 40,
    items: () => G.s.party.map((m) => {
      const st = stats(m);
      return { label: memberName(m), right: `HP ${m.hp}/${st.maxHp}  MP ${m.mp}/${st.maxMp}`, data: m, disabled: filter ? !filter(m) : false };
    }),
    size: 16,
    onCancel: () => closeUI(w),
    onPick: (it) => fn(it.data, w),
  });
  pushUI(w);
  return w;
}

function openStatus(i) {
  let idx = i;
  const w = {
    key(k) {
      if (k === "left") { idx = (idx + G.s.party.length - 1) % G.s.party.length; Kit.sfx("click"); }
      else if (k === "right") { idx = (idx + 1) % G.s.party.length; Kit.sfx("click"); }
      else if (k === "back" || k === "ok") { Kit.sfx("click"); closeUI(w); }
    },
    draw(ctx) {
      const m = G.s.party[idx], st = stats(m);
      panel(ctx, MENU_X, MENU_Y, MENU_W, MENU_H);
      drawWalker(ctx, memberLook(m), MENU_X + 100, MENU_Y + 210, "down", 0, 150);
      txt(ctx, memberName(m), MENU_X + 200, MENU_Y + 60, { size: 30 });
      txt(ctx, `${CLASSES[m.id].title}  -  Level ${m.level}`, MENU_X + 200, MENU_Y + 90, { size: 17, color: "#cbd5e1" });
      txt(ctx, `HP ${m.hp} / ${st.maxHp}     MP ${m.mp} / ${st.maxMp}`, MENU_X + 200, MENU_Y + 122, { size: 17 });
      txt(ctx, `XP ${m.xp} / ${xpNeed(m.level)}  (next level in ${xpNeed(m.level) - m.xp})`, MENU_X + 200, MENU_Y + 150, { size: 15, color: "#94a3b8" });
      const rows = [["Attack", st.atk], ["Defense", st.def], ["Magic", st.mag], ["Speed", st.spd]];
      rows.forEach(([n, v], k) => {
        txt(ctx, n, MENU_X + 200 + (k % 2) * 200, MENU_Y + 190 + Math.floor(k / 2) * 30, { size: 16, color: "#cbd5e1" });
        txt(ctx, String(v), MENU_X + 360 + (k % 2) * 200, MENU_Y + 190 + Math.floor(k / 2) * 30, { size: 16, align: "right" });
      });
      txt(ctx, "Equipment", MENU_X + 30, MENU_Y + 270, { size: 17, color: "#fde68a" });
      ["weapon", "armor", "acc"].forEach((s, k) => {
        txt(ctx, SLOT_NAME[s], MENU_X + 30, MENU_Y + 300 + k * 26, { size: 15, color: "#94a3b8" });
        txt(ctx, m.equip[s] ? EQUIP[m.equip[s]].name : "-", MENU_X + 140, MENU_Y + 300 + k * 26, { size: 15 });
      });
      txt(ctx, "Skills", MENU_X + 380, MENU_Y + 270, { size: 17, color: "#fde68a" });
      const sk = skillsOf(m);
      sk.forEach((s, k) => {
        const S = SKILLS[s];
        txt(ctx, S.name, MENU_X + 380, MENU_Y + 300 + k * 24, { size: 15 });
        txt(ctx, S.mp + " MP", MENU_X + 560, MENU_Y + 300 + k * 24, { size: 14, color: "#93c5fd" });
        if (S.el) elIcon(ctx, S.el, MENU_X + 620, MENU_Y + 295 + k * 24, 6);
      });
      const next = CLASSES[m.id].skills.find(([l]) => l > m.level);
      if (next) txt(ctx, `Next skill at level ${next[0]}: ${SKILLS[next[1]].name}`, MENU_X + 30, MENU_Y + 400, { size: 14, color: "#94a3b8" });
      txt(ctx, G.s.party.length > 1 ? "Left / Right: switch member     X: back" : "X: back", MENU_X + MENU_W / 2, MENU_Y + MENU_H - 20, { size: 14, align: "center", color: "#64748b" });
      hit(MENU_X, MENU_Y, MENU_W, MENU_H, () => w.key("right"));
    },
  };
  pushUI(w);
}

function fieldUseItem(id, m) {
  const it = ITEMS[id], st = stats(m);
  if (it.use === "revive") {
    if (m.hp > 0) return "It has no effect.";
    m.hp = Math.floor(st.maxHp / 2); takeItem(id); return `${memberName(m)} is back on their feet!`;
  }
  if (m.hp <= 0) return `${memberName(m)} is knocked out. Use a Phoenix Feather first.`;
  if (it.use === "heal") { if (m.hp >= st.maxHp) return "HP is already full."; const b = m.hp; m.hp = Math.min(st.maxHp, m.hp + it.amt); takeItem(id); return `${memberName(m)} recovered ${m.hp - b} HP.`; }
  if (it.use === "mp") { if (m.mp >= st.maxMp) return "MP is already full."; const b = m.mp; m.mp = Math.min(st.maxMp, m.mp + it.amt); takeItem(id); return `${memberName(m)} recovered ${m.mp - b} MP.`; }
  if (it.use === "elixir") { m.hp = st.maxHp; m.mp = st.maxMp; takeItem(id); return `${memberName(m)} is fully restored!`; }
  return "That can only be used in battle.";
}
function openItems() {
  const items = () => {
    const ids = Object.keys(G.s.items).filter((id) => itemCount(id) > 0 && ITEMS[id]);
    ids.sort((a, b) => (ITEMS[a].key ? 1 : 0) - (ITEMS[b].key ? 1 : 0));
    return ids.map((id) => ({ label: ITEMS[id].name, right: ITEMS[id].key ? "key item" : "x" + itemCount(id), data: id, color: ITEMS[id].key ? "#fde68a" : undefined }));
  };
  const w = makeList({
    x: MENU_X, y: MENU_Y, w: MENU_W, h: MENU_H - 56, rows: 14, title: "Items", items, empty: "You have no items.",
    help: (it) => it && ITEMS[it.data].desc, helpY: MENU_Y + MENU_H - 50, helpX: MENU_X, helpW: MENU_W,
    onCancel: () => closeUI(w),
    onPick: (it) => {
      const I = ITEMS[it.data];
      if (I.key || ["cure", "bomb"].includes(I.use)) { Music.sfx("buzz"); toast(I.key ? "Key items are used automatically." : "That can only be used in battle."); return; }
      pickMember(`Use ${I.name} on...`, (m, pw) => {
        const r = fieldUseItem(it.data, m);
        if (/recovered|restored|back on/.test(r)) Music.sfx("heal"); else Music.sfx("buzz");
        toast(r);
        if (!itemCount(it.data)) closeUI(pw);
      });
    },
  });
  pushUI(w);
}

function statLine(e) {
  return ["atk", "def", "mag", "spd", "mp"].filter((k) => e[k]).map((k) => `${k.toUpperCase()} +${e[k]}`).join("  ") + (e.immune ? "  Blocks " + e.immune.join(", ") : "");
}
function openEquip(m) {
  const slots = ["weapon", "armor", "acc"];
  const w = makeList({
    x: MENU_X + 20, y: 80, w: 460, title: `${memberName(m)}'s equipment`, rowH: 36,
    items: () => slots.map((s) => ({ label: SLOT_NAME[s], right: m.equip[s] ? EQUIP[m.equip[s]].name : "-", data: s })),
    onCancel: () => closeUI(w),
    onPick: (it) => {
      const slot = it.data;
      const opts = () => {
        const list = Object.keys(G.s.gear).filter((id) => EQUIP[id].slot === slot && canEquip(m, id) && gearCount(id) > 0)
          .map((id) => ({ label: EQUIP[id].name, right: "x" + gearCount(id), data: id }));
        if (m.equip[slot] && slot !== "weapon") list.push({ label: "(Remove)", data: null });
        return list;
      };
      let hover = null;
      const gw = makeList({
        x: MENU_X + 20, y: 250, w: 460, rows: 6, title: `Choose ${SLOT_NAME[slot].toLowerCase()}`, items: opts, empty: "Nothing to equip here.",
        onMove: (it2) => { hover = it2; },
        onCancel: () => closeUI(gw),
        onPick: (it2) => {
          const old = m.equip[slot];
          if (it2.data) takeGear(it2.data);
          if (old) addGear(old);
          m.equip[slot] = it2.data;
          clampMember(m);
          Kit.sfx("coin");
          closeUI(gw);
        },
        after(ctx) {
          const cur = gw.items()[gw.sel];
          const preview = cur ? cur.data : undefined;
          drawEquipCompare(ctx, m, slot, preview);
        },
      });
      pushUI(gw);
    },
    after(ctx) { if (G.ui[G.ui.length - 1] === w) drawEquipCompare(ctx, m, null); },
  });
  const bgw = { key() {}, draw(ctx) { panel(ctx, MENU_X, MENU_Y, MENU_W, MENU_H); drawWalker(ctx, memberLook(m), MENU_X + 600, MENU_Y + 200, "down", 0, 120); } };
  pushUI(bgw);
  const origCancel = w.o.onCancel;
  w.o.onCancel = () => { origCancel(); closeUI(bgw); };
  pushUI(w);
}
function drawEquipCompare(ctx, m, slot, preview) {
  const x = MENU_X + 500, y = MENU_Y + 240;
  panel(ctx, x, y, 190, 190, { top: "#0f172a", bottom: "#0b1220" });
  const cur = stats(m);
  let nxt = null;
  if (slot && preview !== undefined) {
    const copy = { ...m, equip: { ...m.equip, [slot]: preview } };
    nxt = stats(copy);
  }
  [["ATK", "atk"], ["DEF", "def"], ["MAG", "mag"], ["SPD", "spd"], ["MAX MP", "maxMp"]].forEach(([n, k], i) => {
    const yy = y + 32 + i * 30;
    txt(ctx, n, x + 16, yy, { size: 14, color: "#94a3b8" });
    txt(ctx, String(cur[k]), x + 110, yy, { size: 15, align: "right" });
    if (nxt) {
      const d = nxt[k] - cur[k];
      txt(ctx, String(nxt[k]), x + 172, yy, { size: 15, align: "right", color: d > 0 ? "#4ade80" : d < 0 ? "#f87171" : "#e2e8f0" });
    }
  });
  if (slot && preview) txt(ctx, statLine(EQUIP[preview]), MENU_X + 30, MENU_Y + MENU_H - 24, { size: 14, color: "#cbd5e1" });
}

function questLines() {
  const out = [];
  for (const id in QUESTS) {
    const Q = QUESTS[id], st = G.s.quests[id];
    if (!st) continue;
    let prog = "";
    if (st.state === "done") prog = "Complete";
    else if (Q.type === "kill") prog = `${st.count || 0} / ${Q.need}`;
    else prog = `${Math.min(Q.need, itemCount(Q.item))} / ${Q.need}`;
    out.push({ Q, st, prog });
  }
  return out;
}
function openQuests() {
  const w = {
    key(k) { if (k === "back" || k === "ok") { Kit.sfx("click"); closeUI(w); } },
    draw(ctx) {
      panel(ctx, MENU_X, MENU_Y, MENU_W, MENU_H);
      txt(ctx, "Quest Log", MENU_X + 24, MENU_Y + 40, { size: 24, color: "#fde68a" });
      const obj = objective();
      txt(ctx, "Main story" + (G.s.flags.ch2 ? " - Chapter 3" : G.s.flags.ch1 ? " - Chapter 2" : " - Chapter 1"), MENU_X + 24, MENU_Y + 80, { size: 17, color: "#93c5fd" });
      wrapText(ctx, obj ? obj.text : "", MENU_W - 60, 16).forEach((l, i) => txt(ctx, l, MENU_X + 40, MENU_Y + 108 + i * 22, { size: 16 }));
      txt(ctx, "Side quests", MENU_X + 24, MENU_Y + 180, { size: 17, color: "#93c5fd" });
      const qs = questLines();
      if (!qs.length) txt(ctx, "No side quests yet. Talk to people in town!", MENU_X + 40, MENU_Y + 210, { size: 15, color: "#94a3b8" });
      qs.forEach(({ Q, st, prog }, i) => {
        const y = MENU_Y + 196 + i * 76;
        ctx.fillStyle = "rgba(255,255,255,.05)"; ctx.beginPath(); ctx.roundRect(MENU_X + 24, y, MENU_W - 48, 68, 8); ctx.fill();
        txt(ctx, Q.name, MENU_X + 40, y + 26, { size: 17, color: st.state === "done" ? "#86efac" : "#fff" });
        txt(ctx, prog, MENU_X + MENU_W - 40, y + 26, { size: 16, align: "right", color: st.state === "done" ? "#86efac" : "#fde68a" });
        txt(ctx, Q.desc + "  (" + Q.giver + ")", MENU_X + 40, y + 52, { size: 14, color: "#cbd5e1" });
      });
      hit(MENU_X, MENU_Y, MENU_W, MENU_H, () => w.key("back"));
    },
  };
  pushUI(w);
}

// ------------------------------------------------------------------ shops and inn
function openShop(title, stock) {
  return new Promise((resolve) => {
    const top = makeList({
      x: 40, y: 40, w: 220, title, rowH: 34,
      items: [{ label: "Buy", id: "buy" }, { label: "Sell", id: "sell" }, { label: "Leave", id: "leave" }],
      onCancel: () => { closeUI(top); resolve(); },
      onPick: (it) => {
        if (it.id === "leave") { closeUI(top); resolve(); }
        else if (it.id === "buy") openBuy(stock);
        else openSell();
      },
      after(ctx) {
        panel(ctx, 40, 200, 220, 56);
        txt(ctx, "Gold", 60, 234, { size: 15, color: "#94a3b8" });
        txt(ctx, String(G.s.gold), 240, 234, { size: 18, align: "right", color: "#fde68a" });
      },
    });
    pushUI(top);
  });
}
function gearNote(id) {
  const e = EQUIP[id];
  const parts = [];
  for (const m of G.s.party) {
    if (!canEquip(m, id)) continue;
    const cur = stats(m);
    const nxt = stats({ ...m, equip: { ...m.equip, [e.slot]: id } });
    const ds = ["atk", "def", "mag", "spd"].map((k) => [k, nxt[k] - cur[k]]).filter(([, d]) => d !== 0).map(([k, d]) => `${k.toUpperCase()} ${d > 0 ? "+" : ""}${d}`);
    parts.push(`${memberName(m)}: ${ds.length ? ds.join(" ") : "same"}`);
  }
  return parts.length ? parts.join("   ") : "Nobody in your party can use this.";
}
function openBuy(stock) {
  const w = makeList({
    x: 280, y: 40, w: 420, title: "Buy", rows: 8, rowH: 32,
    items: () => stock.map((id) => {
      const isGear = !!EQUIP[id];
      const def = isGear ? EQUIP[id] : ITEMS[id];
      const own = isGear ? gearCount(id) + equippedCount(id) : itemCount(id);
      return { label: def.name, right: def.price + " G", data: id, disabled: G.s.gold < def.price, own };
    }),
    help: (it) => it && (EQUIP[it.data] ? gearNote(it.data) : ITEMS[it.data].desc) + `   (own ${it.own})`,
    helpX: 40, helpY: 500, helpW: VW - 80,
    onCancel: () => closeUI(w),
    onPick: (it) => {
      const id = it.data, isGear = !!EQUIP[id];
      const price = (isGear ? EQUIP[id] : ITEMS[id]).price;
      if (G.s.gold < price) { Music.sfx("buzz"); return; }
      G.s.gold -= price;
      if (isGear) addGear(id); else addItem(id);
      Kit.sfx("coin");
      toast(`Bought ${thingName(id)}.` + (isGear ? " Equip it from the menu (Q)." : ""));
      updateHud();
    },
  });
  pushUI(w);
}
function openSell() {
  const w = makeList({
    x: 280, y: 40, w: 420, title: "Sell", rows: 8, rowH: 32, empty: "Nothing to sell.",
    items: () => {
      const out = [];
      for (const id of Object.keys(G.s.items)) if (ITEMS[id] && !ITEMS[id].key && ITEMS[id].price > 0) out.push({ label: ITEMS[id].name + " x" + itemCount(id), right: Math.floor(ITEMS[id].price / 2) + " G", data: id });
      for (const id of Object.keys(G.s.gear)) if (EQUIP[id].price > 0) out.push({ label: EQUIP[id].name + " x" + gearCount(id), right: Math.floor(EQUIP[id].price / 2) + " G", data: id, gear: true });
      return out;
    },
    onCancel: () => closeUI(w),
    onPick: (it) => {
      const def = it.gear ? EQUIP[it.data] : ITEMS[it.data];
      G.s.gold += Math.floor(def.price / 2);
      if (it.gear) takeGear(it.data); else takeItem(it.data);
      Kit.sfx("coin");
      updateHud();
    },
  });
  pushUI(w);
}
async function innScript(name, price, spot) {
  const c = await ask(name, `Welcome, traveler! A good night's rest costs ${price} gold. It also saves your journey. Will you stay?`, ["Stay", "No thanks"]);
  if (c !== 0) { await say(name, "Come back any time!"); return; }
  if (G.s.gold < price) { await say(name, "Oh dear, you don't have enough gold."); return; }
  G.s.gold -= price;
  await fadeOut(500);
  Music.stop();
  Music.sfx("heal");
  healAll();
  G.s.lastInn = { map: G.s.map, x: spot[0], y: spot[1] };
  await wait(900);
  Music.play(fieldMusic());
  await fadeIn(500);
  const ok = saveGame();
  updateHud();
  await say(name, ok ? "Good morning! You look well rested. (Your game was saved.)" : "Good morning! You look well rested.");
}

// ------------------------------------------------------------------ chests, quests, rewards
async function openChest(o) {
  if (G.s.opened[o.id]) { await notice("The chest is empty."); return; }
  G.s.opened[o.id] = true;
  Kit.sfx("coin");
  if (o.gold) { G.s.gold += o.gold; await notice(`Found ${o.gold} gold!`); }
  if (o.item) { addItem(o.item, o.n || 1); await notice(`Found ${thingName(o.item)}${(o.n || 1) > 1 ? " x" + o.n : ""}!`); }
  if (o.gear) { addGear(o.gear); await notice(`Found the ${thingName(o.gear)}! Equip it from the menu (Q).`); }
  if (o.after) await o.after();
}
async function giveReward(r) {
  if (r.gold) G.s.gold += r.gold;
  const got = [];
  if (r.gold) got.push(`${r.gold} gold`);
  for (const k in r.items || {}) { addItem(k, r.items[k]); got.push(`${thingName(k)} x${r.items[k]}`); }
  if (r.equip) { addGear(r.equip); got.push(thingName(r.equip)); }
  Kit.sfx("coin");
  await notice("Received " + got.join(", ") + "!");
  updateHud();
}
function startQuest(id) { if (!G.s.quests[id]) { G.s.quests[id] = { state: "active", count: 0 }; Music.sfx("chime"); toast(`New quest: ${QUESTS[id].name}`); } }
function questReady(id) {
  const Q = QUESTS[id], st = G.s.quests[id];
  if (!st || st.state !== "active") return false;
  return Q.type === "kill" ? (st.count || 0) >= Q.need : itemCount(Q.item) >= Q.need;
}
async function completeQuest(id) {
  const Q = QUESTS[id];
  if (Q.type === "fetch") takeItem(Q.item, Q.need);
  G.s.quests[id].state = "done";
  Music.sfx("level");
  await giveReward(Q.reward);
  if (Object.keys(QUESTS).every((q) => G.s.quests[q] && G.s.quests[q].state === "done")) badge("helper");
}

// ------------------------------------------------------------------ save / load
function saveGame() {
  try {
    G.s.x = G.p.x; G.s.y = G.p.y; G.s.dir = G.p.dir;
    G.s.savedAt = Date.now();
    localStorage.setItem(SAVE_KEY, JSON.stringify(G.s));
    Kit.finish(ID, hero().level);
    return true;
  } catch (e) { return false; }
}
function loadSave() {
  try {
    const s = JSON.parse(localStorage.getItem(SAVE_KEY));
    if (s && s.v === 1 && Array.isArray(s.party) && MAPS[s.map]) return s;
  } catch (_) {}
  return null;
}
