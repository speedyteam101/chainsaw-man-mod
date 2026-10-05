// Survival Island: main game (player, gathering, crafting, building, survival, day/night, saving, co-op).
import { World, THREE } from "../kit3d.js";
import { Island } from "./island.js";
import { CELL, N, OFF, WATER_Y, FLOOR_MIN, GRASS, FOREST, cellOf, cellCenter } from "./gen.js";
import { ITEMS, PIECES, PIECE_LIST, RECIPES } from "./items.js";
import { Builds, boxNormal } from "./builds.js";
import { Mob, MOBS, MOB_TYPES } from "./mobs.js";
import { UI } from "./ui.js";

const GAME = "survival-island";
const DAY = 480;                      // seconds for a whole day + night
const NIGHT_START = 0.69, NIGHT_END = 0.965;
const START_CLOCK = DAY * 0.04;
const REACH = 12;
const SWING = 0.32;
const SAVE_KEY = "survival-island.save.v1";
const V3 = THREE.Vector3;
const r1 = (v) => Math.round(v * 10) / 10;
const r2 = (v) => Math.round(v * 100) / 100;
const TIER_NAME = { axe: ["", "Wood Axe", "Stone Axe", "Iron Axe"], pick: ["", "Wood Pickaxe", "Stone Pickaxe", "Iron Pickaxe"] };

// ------------------------------------------------------------------ setup

// Real-time shadows and point lights are too slow for software rendering: terrain uses baked lighting,
// lights are glowing decals and characters get soft blob shadows.
const world = new World({ sky: "#8fd3ff", health: true, fogNear: 170, fogFar: 460, shadows: false });
world.camera.far = 1500;
world.camera.updateProjectionMatrix();

function loadSave() {
  try { return JSON.parse(localStorage.getItem(SAVE_KEY)) || {}; } catch (_) { return {}; }
}
const SAVE = loadSave();
if (!SAVE.uid) SAVE.uid = Math.random().toString(36).slice(2, 10);
if (!SAVE.stats) SAVE.stats = { placed: 0, kills: 0 };
const UID = SAVE.uid;

const G = {
  mode: "own",           // "own" = my island (solo or hosting), "guest" = someone else's island
  synced: true,          // false while waiting for the host's island
  seed: 0, clock: START_CLOCK, started: false,
  inv: new Array(27).fill(null), sel: 0, hunger: 100,
  days: 0, found: {}, bedId: null, rot: 0,
  gone: new Map(),       // resource id -> world clock when it grows back
  nightAlive: false, wasNight: false,
  coolUntil: 0, swingT: 0, showTool: null, showToolT: 0,
  place: null, target: null, extra: {}, hostName: "",
  starve: 0, regen: 0, warnT: 0,
};
window.game = { G, SAVE };
window.world = world;

let island = null, builds = null;
const ui = new UI({
  get inv() { return G.inv; }, get sel() { return G.sel; },
  select: (n) => select(n), count: (id) => count(id), swap: (a, b) => swap(a, b),
  craft: (r) => craft(r), recipeState: (r) => recipeState(r), stationsNear: () => stationsNear(),
  chestTake: (c, id) => chestTake(c, id), chestPut: (c, n) => chestPut(c, n), chestExists: (c) => builds && builds.byId.get(c.id) === c,
  worldInfo: () => worldInfo(), canResetWorld: () => G.mode === "own", newWorld: () => newWorld(true),
});

const me = world.spawnPlayer({ pos: [0, 40, 0] });
me.frozen = true;

// Invisible walls around the edge of the map.
for (const [sx, sz, x, z] of [[2, 2 * OFF + 8, OFF + 1, 0], [2, 2 * OFF + 8, -OFF - 1, 0], [2 * OFF + 8, 2, 0, OFF + 1], [2 * OFF + 8, 2, 0, -OFF - 1]]) {
  const wall = world.part({ size: [sx, 300, sz], pos: [x, 100, z], color: "#000000", studs: false, shadow: false });
  wall.visible = false;
}

// Stars and moon for the night sky.
const stars = (() => {
  const pts = [];
  for (let n = 0; n < 500; n++) {
    const a = Math.random() * Math.PI * 2, e = Math.acos(Math.random() * 0.95);
    pts.push(Math.cos(a) * Math.sin(e) * 900, Math.cos(e) * 900, Math.sin(a) * Math.sin(e) * 900);
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute("position", new THREE.Float32BufferAttribute(pts, 3));
  const s = new THREE.Points(geo, new THREE.PointsMaterial({ color: "#ffffff", size: 2, sizeAttenuation: false, transparent: true, opacity: 0, fog: false, depthWrite: false }));
  world.scene.add(s);
  return s;
})();
const moon = new THREE.Mesh(new THREE.BoxGeometry(40, 40, 40), new THREE.MeshBasicMaterial({ color: "#f1f5ff", fog: false, transparent: true, opacity: 0 }));
world.scene.add(moon);

// Soft round textures for glows and blob shadows.
function radialTexture(inner, outer) {
  const c = document.createElement("canvas");
  c.width = c.height = 64;
  const g = c.getContext("2d");
  const grad = g.createRadialGradient(32, 32, 0, 32, 32, 32);
  grad.addColorStop(0, inner); grad.addColorStop(1, outer);
  g.fillStyle = grad; g.fillRect(0, 0, 64, 64);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}
const GLOW_TEX = radialTexture("rgba(255,255,255,1)", "rgba(255,255,255,0)");
const SHADOW_TEX = radialTexture("rgba(0,0,0,0.42)", "rgba(0,0,0,0)");
const flatGeo = new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2);
const shadowMat = new THREE.MeshBasicMaterial({ map: SHADOW_TEX, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2 });
function blob(size) {
  const m = new THREE.Mesh(flatGeo, shadowMat);
  m.scale.set(size, 1, size);
  m.renderOrder = 1;
  return m;
}
shadowMat.userData.shared = true;
Mob.blob = (size) => { const m = blob(size); m.position.y = 0.06; return m; };
const myShadow = blob(3.2);
world.scene.add(myShadow);
const torchGlow = new THREE.Mesh(flatGeo, new THREE.MeshBasicMaterial({ map: GLOW_TEX, color: "#ff9a40", transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0 }));
torchGlow.scale.set(26, 1, 26);
world.scene.add(torchGlow);

// Highlight box around the thing you're aiming at, and the build ghost.
const selBox = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(1, 1, 1)), new THREE.LineBasicMaterial({ color: "#ffffff", transparent: true, opacity: 0.85 }));
selBox.visible = false;
world.scene.add(selBox);
const ghost = new THREE.Mesh(new THREE.BoxGeometry(1, 1, 1), new THREE.MeshBasicMaterial({ color: "#22c55e", transparent: true, opacity: 0.35, depthWrite: false }));
const ghostEdges = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(1, 1, 1)), new THREE.LineBasicMaterial({ color: "#ffffff" }));
ghost.add(ghostEdges);
const ghostArrow = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.06, 0.5), new THREE.MeshBasicMaterial({ color: "#ffffff" }));
ghostArrow.position.set(0, 0.5, -0.38);
ghost.add(ghostArrow);
ghost.visible = false;
ghost.renderOrder = 3;
world.scene.add(ghost);

// ------------------------------------------------------------------ particles

const PCOUNT = 160;
const pMesh = new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1), new THREE.MeshLambertMaterial({ color: "#ffffff" }), PCOUNT);
pMesh.frustumCulled = false;
const particles = [];
{
  const zero = new THREE.Matrix4().makeScale(0, 0, 0);
  for (let n = 0; n < PCOUNT; n++) { particles.push({ life: 0, max: 1, p: new V3(), v: new V3(), s: 0.4 }); pMesh.setMatrixAt(n, zero); pMesh.setColorAt(n, new THREE.Color("#fff")); }
}
world.scene.add(pMesh);
let pNext = 0;
function pop(x, y, z, color, n, speed, size) {
  const c = new THREE.Color(color);
  for (let k = 0; k < n; k++) {
    const q = particles[pNext];
    q.life = q.max = 0.5 + Math.random() * 0.4;
    q.p.set(x + (Math.random() - 0.5), y + (Math.random() - 0.5), z + (Math.random() - 0.5));
    q.v.set((Math.random() - 0.5) * speed, Math.random() * speed * 0.9 + speed * 0.3, (Math.random() - 0.5) * speed);
    q.s = (size || 0.45) * (0.6 + Math.random() * 0.6);
    pMesh.setColorAt(pNext, c);
    pNext = (pNext + 1) % PCOUNT;
  }
  pMesh.instanceColor.needsUpdate = true;
}
function stepParticles(dt) {
  const m = new THREE.Matrix4(), q = new THREE.Quaternion(), s = new V3();
  let any = false;
  particles.forEach((p, n) => {
    if (p.life <= 0) return;
    any = true;
    p.life -= dt;
    p.v.y -= 45 * dt;
    p.p.addScaledVector(p.v, dt);
    const f = Math.max(0, p.life / p.max);
    s.setScalar(p.life > 0 ? p.s * (0.3 + 0.7 * f) : 0);
    q.setFromAxisAngle(new V3(1, 1, 0).normalize(), p.life * 8);
    m.compose(p.p, q, s);
    pMesh.setMatrixAt(n, m);
  });
  if (any) pMesh.instanceMatrix.needsUpdate = true;
}

// ------------------------------------------------------------------ held item in the right hand

const hand = new THREE.Group();
hand.position.set(0, -1.85, 0);
me.group.userData.limbs.armR.add(hand);
const heldCache = new Map();
let heldId = null;
function heldModel(id) {
  if (heldCache.has(id)) return heldCache.get(id);
  const g = new THREE.Group();
  const it = ITEMS[id];
  const add = (sx, sy, sz, x, y, z, color, glow) => {
    const m = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, sz), glow ? new THREE.MeshBasicMaterial({ color }) : new THREE.MeshLambertMaterial({ color }));
    m.position.set(x, y, z);
    m.castShadow = true;
    g.add(m);
  };
  if (it.kind === "tool") {
    add(0.22, 0.22, 2.6, 0, 0, -0.9, "#8b5a2b");
    if (it.tool === "axe") add(0.18, 0.95, 0.8, 0, 0.35, -1.9, it.color);
    else add(0.2, 0.25, 0.25, 0, 0, -2.1, it.color), add(0.22, 1.9, 0.3, 0, 0, -2.15, it.color);
  } else if (it.kind === "weapon") {
    add(0.22, 0.22, 0.7, 0, 0, -0.1, "#5b3a1d");
    add(1.0, 0.22, 0.22, 0, 0, -0.5, "#57534e");
    add(0.14, 0.5, 2.6, 0, 0, -1.9, it.color, id === "crystal_sword");
  } else if (id === "torch") {
    add(0.22, 0.22, 1.6, 0, 0, -0.6, "#8b5a2b");
    add(0.45, 0.45, 0.5, 0, 0, -1.5, "#fb923c", true);
  } else if (it.kind !== "armor") {
    add(0.7, 0.7, 0.7, 0, 0, -0.3, it.color);
  }
  g.rotation.x = -0.25;
  heldCache.set(id, g);
  return g;
}
function updateHeld() {
  const cur = G.inv[G.sel];
  const id = G.showToolT > 0 && G.showTool ? G.showTool : cur ? cur.id : null;
  if (id === heldId) return;
  heldId = id;
  hand.clear();
  if (id) hand.add(heldModel(id));
}

// After the kit animates the character: swing the arm, then keep the camera out of hills and walls.
const kitUpdateCamera = world.updateCamera.bind(world);
world.updateCamera = () => {
  const L = me.group.userData.limbs;
  if (G.swingT > 0) {
    const f = 1 - G.swingT / SWING;
    L.armR.rotation.x = 0.3 + Math.sin(f * Math.PI) * 1.9;
  } else if (heldId && me.onGround) {
    L.armR.rotation.x = 0.3 + L.armR.rotation.x * 0.3;
  }
  kitUpdateCamera();
  if (!island) return;
  const target = new V3(me.pos.x, me.pos.y + 4.5, me.pos.z);
  const cam = world.camera.position;
  const dir = cam.clone().sub(target);
  const dist = dir.length();
  if (dist < 0.01) return;
  dir.divideScalar(dist);
  const near = island.resourcesNear(target.x + dir.x * dist * 0.5, target.z + dir.z * dist * 0.5, dist * 0.5 + 8);
  const boxes = near.map((r) => island.pickBox(r, new THREE.Box3()).expandByScalar(0.4));
  const pt = new V3();
  for (let t = 0.6; t <= dist; t += 0.4) {
    const x = target.x + dir.x * t, y = target.y + dir.y * t, z = target.z + dir.z * t;
    pt.set(x, y, z);
    if (island.solidAt(x, y, z) || buildSolidAt(x, y, z) || boxes.some((bx) => bx.containsPoint(pt))) {
      cam.copy(target).addScaledVector(dir, Math.max(1, t - 0.7));
      world.camera.lookAt(target);
      break;
    }
  }
};
function buildSolidAt(x, y, z) {
  for (const b of builds.inCell(cellOf(x), cellOf(z))) if (builds.isSolid(b) && y >= b.y && y < b.top && PIECES[b.type].size[1] >= 2.4 && !PIECES[b.type].door) return true;
  for (const b of builds.inCell(cellOf(x), cellOf(z))) if (b.type === "wood_floor" && y >= b.y && y < b.top) return true;
  return false;
}

// ------------------------------------------------------------------ inventory

function maxStack(id) { return ITEMS[id].max || 99; }
function count(id) { let n = 0; for (const s of G.inv) if (s && s.id === id) n += s.n; return n; }
function space(id, n) {
  for (const s of G.inv) { if (!s) n -= maxStack(id); else if (s.id === id) n -= maxStack(id) - s.n; if (n <= 0) return true; }
  return n <= 0;
}
function give(id, n, quiet) {
  if (!ITEMS[id]) return n;
  const firstTime = !G.found[id];
  G.found[id] = true;
  for (const s of G.inv) if (s && s.id === id && s.n < maxStack(id)) { const k = Math.min(n, maxStack(id) - s.n); s.n += k; n -= k; if (!n) break; }
  for (let i = 0; i < G.inv.length && n > 0; i++) if (!G.inv[i]) { const k = Math.min(n, maxStack(id)); G.inv[i] = { id, n: k }; n -= k; }
  if (n > 0 && !quiet) ui.pickup("Backpack full!", "#ef4444");
  if (firstTime && ["stone", "iron", "crystal", "raw_meat"].includes(id)) ui.pickup("New recipes unlocked (C)", "#22c55e");
  ui.renderHotbar();
  return n;
}
function take(id, n) {
  for (let i = G.inv.length - 1; i >= 0 && n > 0; i--) {
    const s = G.inv[i];
    if (!s || s.id !== id) continue;
    const k = Math.min(n, s.n);
    s.n -= k; n -= k;
    if (!s.n) G.inv[i] = null;
  }
  ui.renderHotbar();
}
function takeSlot(i, n) {
  const s = G.inv[i];
  if (!s) return;
  s.n -= n;
  if (s.n <= 0) G.inv[i] = null;
  ui.renderHotbar();
}
function swap(a, b) { [G.inv[a], G.inv[b]] = [G.inv[b], G.inv[a]]; ui.renderHotbar(); }
function select(n) { G.sel = n; ui.renderHotbar(); }
function bestTool(kind) {
  let best = null;
  for (const s of G.inv) if (s && ITEMS[s.id].tool === kind && (!best || ITEMS[s.id].tier > ITEMS[best].tier)) best = s.id;
  return best;
}
function bestWeapon() {
  let best = null, dmg = 2;
  for (const s of G.inv) if (s && ITEMS[s.id].dmg && ITEMS[s.id].dmg > dmg) { dmg = ITEMS[s.id].dmg; best = s.id; }
  return { id: best, dmg };
}
const armor = () => (count("iron_armor") ? ITEMS.iron_armor.armor : 0);

// ------------------------------------------------------------------ world loading & saving

function serialize(b) { return builds.serialize(b, PIECE_LIST.indexOf(b.type)); }
function addBuildArr(a) {
  if (!Array.isArray(a) || typeof a[0] !== "string" || !PIECE_LIST[a[1]]) return null;
  const i = a[2] | 0, k = a[3] | 0;
  if (i < 0 || k < 0 || i >= N || k >= N) return null;
  return builds.add({ id: a[0], type: PIECE_LIST[a[1]], i, k, y: +a[4] || 0, rot: (a[5] | 0) & 3, owner: String(a[6] || ""), open: !!a[7], items: a[8] && typeof a[8] === "object" ? a[8] : null });
}

function loadWorld(w, mode) {
  for (const m of [...mobs.values()]) removeMob(m);
  if (builds) builds.clear();
  if (island) island.dispose();
  island = new Island(world, w.seed);
  builds = new Builds(world, island);
  G.mode = mode;
  G.seed = w.seed;
  G.clock = typeof w.clock === "number" ? w.clock : START_CLOCK;
  G.wasNight = isNight();
  G.gone = new Map();
  for (const [rid, at] of w.gone || []) {
    const r = island.map.res[rid];
    if (r) { island.setResource(r, false); G.gone.set(rid, at); }
  }
  for (const a of w.builds || []) addBuildArr(a);
  window.game.island = island;
  window.game.builds = builds;
}

function defaultSpawn() {
  const sp = island.map.spawn;
  return [cellCenter(sp.i), island.top(sp.i, sp.k) + 0.05, cellCenter(sp.k)];
}
function spawnPoint() {
  const bed = G.bedId && builds.byId.get(G.bedId);
  if (bed) return [bed.x, bed.top + 0.05, bed.z];
  return defaultSpawn();
}
function teleport(pos) {
  me.pos.set(pos[0], pos[1], pos[2]);
  me.vel.set(0, 0, 0);
  island.updateColliders(me.pos.x, me.pos.z, true);
}

function applyPlayer(pd) {
  const d = pd || {};
  G.inv = new Array(27).fill(null);
  if (Array.isArray(d.inv)) d.inv.slice(0, 27).forEach((s, n) => { if (s && ITEMS[s.id] && s.n > 0) G.inv[n] = { id: s.id, n: Math.min(maxStack(s.id), s.n | 0) }; });
  G.sel = d.sel | 0;
  G.hunger = typeof d.hunger === "number" ? Math.max(20, d.hunger) : 100;
  G.days = d.days | 0;
  G.found = d.found || {};
  G.bedId = d.bedId || null;
  me.health = typeof d.health === "number" && d.health > 0 ? Math.max(30, d.health) : me.maxHealth;
  world.updateHealthBar();
  world.checkpoint(spawnPoint());
  const pos = Array.isArray(d.pos) && d.pos.every((v) => typeof v === "number" && isFinite(v)) ? d.pos : spawnPoint();
  // never start inside the ground
  pos[1] = Math.max(pos[1], island.topAt(pos[0], pos[2]) + 0.05);
  teleport(pos);
  ui.renderHotbar();
}

function playerData() {
  return { inv: G.inv, sel: G.sel, hunger: r1(G.hunger), health: me.alive ? me.health : me.maxHealth, days: G.days, found: G.found, bedId: G.bedId, pos: me.alive ? [r1(me.pos.x), r1(me.pos.y), r1(me.pos.z)] : null };
}
function worldData() {
  return { seed: G.seed, clock: r1(G.clock), builds: [...builds.byId.values()].map(serialize), gone: [...G.gone.entries()].map(([k, v]) => [k, r1(v)]) };
}
function saveNow() {
  if (!island) return;
  if (G.mode === "own") SAVE.solo = Object.assign(worldData(), { player: playerData() });
  else SAVE.guest = { player: playerData() };
  try { localStorage.setItem(SAVE_KEY, JSON.stringify(SAVE)); } catch (_) {}
}

function newSeed() { return 1 + Math.floor(Math.random() * 999999); }
function newWorld(announce) {
  const seed = newSeed();
  loadWorld({ seed, clock: START_CLOCK, builds: [], gone: [] }, "own");
  applyPlayer({});
  G.nightAlive = false;
  saveNow();
  if (net && net.online && net.isHost) send({ t: "newworld", seed, clock: G.clock });
  if (announce) ui.announce("A new island!", "Gather wood from trees to get started.");
}

function worldInfo() {
  const who = G.mode === "guest" ? `You're visiting ${G.hostName || "a friend"}'s island.` : net && net.online && net.players.size ? "You're hosting this island online." : "Your own island.";
  return `<b>Island #${G.seed}</b> · Day ${dayNum()}<br>${who}<br>Builds placed: ${SAVE.stats.placed} · Monsters defeated: ${SAVE.stats.kills}`;
}

// ------------------------------------------------------------------ time of day

const phase = () => ((G.clock % DAY) + DAY) % DAY / DAY;
const dayNum = () => Math.floor(G.clock / DAY + (1 - NIGHT_END)) + 1;   // a new day starts at dawn
const isNight = () => { const p = phase(); return p >= NIGHT_START && p < NIGHT_END; };
const SKY = [
  [0.00, "#ffc996", "#ffe2bf", 1.0, 0.8, "#e8c7a8"],
  [0.07, "#8fd3ff", "#ffffff", 1.6, 1.15, "#ffffff"],
  [0.57, "#8fd3ff", "#ffffff", 1.6, 1.15, "#ffffff"],
  [0.64, "#f0915f", "#ffb27a", 0.95, 0.78, "#e0ad8c"],
  [0.71, "#0c1533", "#8ea2ff", 0.22, 0.34, "#46527e"],
  [0.94, "#0c1533", "#8ea2ff", 0.22, 0.34, "#46527e"],
  [1.00, "#ffc996", "#ffe2bf", 1.0, 0.8, "#e8c7a8"],
];
const cA = new THREE.Color(), cB = new THREE.Color(), cC = new THREE.Color(), cD = new THREE.Color(), cE = new THREE.Color();
let darkness = 0;
function updateSky() {
  const p = phase();
  let a = SKY[0], b = SKY[1];
  for (let n = 0; n < SKY.length - 1; n++) if (p >= SKY[n][0] && p <= SKY[n + 1][0]) { a = SKY[n]; b = SKY[n + 1]; break; }
  const f = (p - a[0]) / Math.max(1e-6, b[0] - a[0]);
  cA.set(a[1]).lerp(cB.set(b[1]), f);
  world.scene.background.copy(cA);
  if (world.scene.fog) world.scene.fog.color.copy(cA);
  cC.set(a[2]).lerp(cD.set(b[2]), f);
  world.sun.color.copy(cC);
  world.sun.intensity = a[3] + (b[3] - a[3]) * f;
  world.hemi.intensity = a[4] + (b[4] - a[4]) * f;
  darkness = Math.max(0, Math.min(1, (1.15 - world.hemi.intensity) / 0.8));
  cE.set(a[5]).lerp(cD.set(b[5]), f);
  island.setLight(cE);
  stars.material.opacity = Math.max(0, darkness - 0.55) * 2.2;
  stars.position.copy(world.camera.position);
  moon.material.opacity = Math.max(0, darkness - 0.4) * 1.6;
  moon.position.set(world.camera.position.x - 500, world.camera.position.y + 420, world.camera.position.z - 600);
}

function updateLights() {
  builds.setGlow(0.12 + 0.88 * darkness);
  const holdingTorch = G.inv[G.sel] && G.inv[G.sel].id === "torch" && me.alive;
  torchGlow.visible = holdingTorch;
  if (holdingTorch) {
    torchGlow.material.opacity = (0.1 + 0.6 * darkness) * (0.92 + Math.sin(performance.now() / 90) * 0.08);
    torchGlow.position.set(me.pos.x, builds.groundAt(me.pos.x, me.pos.z, me.pos.y + 0.5) + 0.12, me.pos.z);
  }
  myShadow.visible = me.alive;
  myShadow.position.set(me.pos.x, builds.groundAt(me.pos.x, me.pos.z, me.pos.y + 0.5) + 0.06, me.pos.z);
  const lift = Math.max(0, me.pos.y - myShadow.position.y);
  myShadow.scale.setScalar(3.2 / (1 + lift * 0.08));
  myShadow.scale.y = 1;
}

// ------------------------------------------------------------------ aiming

const raycaster = new THREE.Raycaster();
const pointer = { x: innerWidth / 2, y: innerHeight / 2 };
let mouseDown = null;
const canvas = world.renderer.domElement;
canvas.addEventListener("pointerdown", (e) => {
  if (e.button === 0) mouseDown = { x: e.clientX, y: e.clientY, t: performance.now(), moved: false };
});
addEventListener("pointermove", (e) => {
  pointer.x = e.clientX; pointer.y = e.clientY;
  if (mouseDown && Math.hypot(e.clientX - mouseDown.x, e.clientY - mouseDown.y) > 6) mouseDown.moved = true;
});
addEventListener("pointerup", (e) => {
  if (mouseDown && !mouseDown.moved && e.button === 0 && performance.now() - mouseDown.t < 350) onAct(false);
  mouseDown = null;
});

function marchTerrain(ray, maxT) {
  const o = ray.origin, d = ray.direction;
  let px = o.x, py = o.y, pz = o.z;
  for (let t = 0.3; t < maxT; t += 0.25) {
    const x = o.x + d.x * t, y = o.y + d.y * t, z = o.z + d.z * t;
    if (island.solidAt(x, y, z)) {
      const ci = cellOf(x), ck = cellOf(z), pi = cellOf(px), pk = cellOf(pz);
      const n = new V3(0, 1, 0);
      const pt = new V3(x, y, z);
      if (pi !== ci) { n.set(pi < ci ? -1 : 1, 0, 0); pt.x = (pi < ci ? ci : ci + 1) * CELL - OFF; }
      else if (pk !== ck) { n.set(0, 0, pk < ck ? -1 : 1); pt.z = (pk < ck ? ck : ck + 1) * CELL - OFF; }
      else if (py < y) n.set(0, -1, 0);
      else { const rf = island.roof(ci, ck); pt.y = rf && y >= rf[0] ? rf[1] : island.top(ci, ck); }
      return { t, point: pt, normal: n };
    }
    px = x; py = y; pz = z;
  }
  return null;
}

function mobBox(m, out) {
  const w = m.type === "shade" ? 1.4 : m.type === "chicken" ? 1.0 : 1.6;
  out.min.set(m.x - w, m.y, m.z - w);
  out.max.set(m.x + w, m.y + m.def.h + 0.3, m.z + w);
  return out;
}

const b3 = new THREE.Box3();
function pickPointer() {
  const ndc = new THREE.Vector2();
  if (world.cam.shiftLock) ndc.set(0, 0);
  else ndc.set((pointer.x / innerWidth) * 2 - 1, -(pointer.y / innerHeight) * 2 + 1);
  raycaster.setFromCamera(ndc, world.camera);
  const ray = raycaster.ray;
  let best = null;
  const hit = new V3();
  for (const r of island.resourcesNear(me.pos.x, me.pos.z, 40)) {
    if (!ray.intersectBox(island.pickBox(r, b3), hit)) continue;
    const t = hit.distanceTo(ray.origin);
    if (!best || t < best.t) best = { kind: "res", r, t, point: hit.clone(), normal: boxNormal(b3, hit), dist: island.pickBox(r, b3).distanceToPoint(chestPos()) };
  }
  for (const m of mobs.values()) {
    if (!ray.intersectBox(mobBox(m, b3), hit)) continue;
    const t = hit.distanceTo(ray.origin);
    if (!best || t < best.t) best = { kind: "mob", m, t, point: hit.clone(), dist: b3.distanceToPoint(chestPos()) };
  }
  const bh = builds.raycast(ray, best ? best.t : 80);
  if (bh && (!best || bh.t < best.t)) best = { kind: "build", b: bh.b, t: bh.t, point: bh.point, normal: bh.normal, dist: builds.pickBox(bh.b, b3).distanceToPoint(chestPos()) };
  const th = marchTerrain(ray, best ? best.t : 80);
  if (th) best = { kind: "ground", t: th.t, point: th.point, normal: th.normal, dist: th.point.distanceTo(chestPos()) };
  return best;
}
function chestPos() { return new V3(me.pos.x, me.pos.y + 2.6, me.pos.z); }

// The nearest useful thing in front of the player (for F without aiming).
function frontTarget(withBuilds) {
  const fx = -Math.sin(me.yaw), fz = -Math.cos(me.yaw);
  let best = null, score = 1e9;
  const consider = (t, x, z, radius, max) => {
    const dx = x - me.pos.x, dz = z - me.pos.z, d = Math.hypot(dx, dz);
    const gap = d - radius;
    if (gap > max) return;
    const dot = d > 0.01 ? (dx * fx + dz * fz) / d : 1;
    if (dot < 0.3 && gap > 1) return;
    const s = gap - dot * 3;
    if (s < score) { score = s; best = t; }
  };
  for (const r of island.resourcesNear(me.pos.x, me.pos.z, 14)) {
    if (Math.abs(r.y - me.pos.y) > 6) continue;
    consider({ kind: "res", r }, r.x, r.z, (r.def.pick[0] * r.s) / 2, 6);
  }
  for (const m of mobs.values()) if (Math.abs(m.y - me.pos.y) < 5) consider({ kind: "mob", m }, m.x, m.z, 1.4, 7);
  if (withBuilds !== false) {
    for (let dk = -2; dk <= 2; dk++) for (let di = -2; di <= 2; di++) {
      for (const b of builds.inCell(cellOf(me.pos.x) + di, cellOf(me.pos.z) + dk)) {
        if (withBuilds !== "all" && !PIECES[b.type].use && !PIECES[b.type].door) continue;
        if (b.top < me.pos.y - 1.5 || b.y > me.pos.y + 5) continue;
        consider({ kind: "build", b }, b.x, b.z, 1.8, 6.5);
      }
    }
  }
  return best;
}

function resolveTarget() {
  const pk = pickPointer();
  G.pointerHit = pk;
  if (pk && pk.kind !== "ground" && pk.dist <= REACH) return pk;
  return frontTarget();
}

function targetBox(t, out) {
  if (t.kind === "res") return island.pickBox(t.r, out);
  if (t.kind === "mob") return mobBox(t.m, out);
  return builds.pickBox(t.b, out);
}

function describe(t) {
  if (!t) return ["", false];
  if (t.kind === "res") {
    const d = t.r.def;
    if (d.tool) {
      const tool = bestTool(d.tool);
      const tier = tool ? ITEMS[tool].tier : 0;
      if (tier < d.tier) return [`${d.name} - needs a ${TIER_NAME[d.tool][d.tier]}`, true];
    }
    return [`${d.name}  [F]`, false];
  }
  if (t.kind === "mob") return [`${t.m.def.name}  [F] attack`, t.m.def.monster];
  const b = t.b, name = ITEMS[b.type].name;
  const mine = b.owner === UID;
  const use = PIECES[b.type].door ? (b.open ? "close" : "open") : b.type === "chest" ? "open" : b.type === "bed" ? "set spawn" : b.type === "workbench" || b.type === "campfire" ? "craft" : "";
  return [`${name}${use ? `  [F] ${use}` : ""}${mine ? "  [X] remove" : ""}`, false];
}

// ------------------------------------------------------------------ building

function updateGhost() {
  const it = G.inv[G.sel];
  G.place = null;
  if (!it || ITEMS[it.id].kind !== "place" || ui.isOpen() || !me.alive || !G.started) { ghost.visible = false; return; }
  const pk = G.pointerHit;
  let pl = null;
  if (pk && (pk.kind === "ground" || pk.kind === "build") && pk.dist < 18) pl = builds.placement(it.id, G.rot, pk.point, pk.normal);
  else {
    const fx = -Math.sin(me.yaw), fz = -Math.cos(me.yaw);
    pl = builds.placement(it.id, G.rot, new V3(me.pos.x + fx * 5, me.pos.y + 1.2, me.pos.z + fz * 5), new V3(0, 1, 0));
  }
  if (pl.i < 0 || pl.k < 0 || pl.i >= N || pl.k >= N) pl.ok = false;
  const res = island.resByCell.get(pl.i + pl.k * N);
  if (res && res.alive && pl.y < res.y + res.def.pick[1]) pl.ok = false;
  if (PIECES[pl.type].solid && pl.ok) {
    const overlaps = (x, y, z) => x + 0.95 > pl.x - 2 && x - 0.95 < pl.x + 2 && z + 0.95 > pl.z - 2 && z - 0.95 < pl.z + 2 && y + 5.2 > pl.y && y < pl.y + pl.h - 0.05;
    if (overlaps(me.pos.x, me.pos.y, me.pos.z)) pl.ok = false;
    if (net && net.online) for (const p of net.players.values()) if (p.state && Array.isArray(p.state.p) && overlaps(+p.state.p[0], +p.state.p[1], +p.state.p[2])) pl.ok = false;
    for (const m of mobs.values()) if (overlaps(m.x, m.y, m.z)) pl.ok = false;
  }
  G.place = pl;
  const s = PIECES[pl.type].size;
  ghost.visible = true;
  ghost.scale.set(s[0], s[1], s[2]);
  ghost.rotation.y = (pl.rot * Math.PI) / 2;
  ghost.position.set(pl.x, pl.y + s[1] / 2, pl.z);
  ghost.material.color.set(pl.ok ? "#22c55e" : "#ef4444");
  ghostArrow.scale.set(1, 1 / s[1], 1);
}

function placeBuild() {
  const pl = G.place;
  if (!pl || !pl.ok) return false;
  const slot = G.inv[G.sel];
  if (!slot || slot.id !== pl.type) return false;
  takeSlot(G.sel, 1);
  const b = builds.add({ id: Math.random().toString(36).slice(2, 9), type: pl.type, i: pl.i, k: pl.k, y: pl.y, rot: pl.rot, owner: UID });
  if (!b) return false;
  send({ t: "b", b: serialize(b) });
  SAVE.stats.placed++;
  pop(b.x, b.y + 1, b.z, ITEMS[b.type].color, 8, 10, 0.35);
  Kit.sfx("click");
  if (SAVE.stats.placed >= 20) Kit.badge(GAME, "house", "Home Builder", "Place 20 builds on the island.");
  if (b.type === "bed") { G.bedId = b.id; world.checkpoint(spawnPoint()); ui.pickup("Spawn point set at your bed", "#ef4444"); }
  island.lastCell = -1;
  G.coolUntil = performance.now() + 180;
  return true;
}

function removeBuild(t) {
  let b = t && t.kind === "build" ? t.b : null;
  if (!b) { const ft = frontTarget("all"); b = ft && ft.kind === "build" ? ft.b : null; }
  if (!b) return;
  if (b.owner !== UID) { ui.pickup("You can only remove your own builds", "#ef4444"); return; }
  builds.remove(b.id);
  give(b.type, 1, true);
  if (b.items) for (const [id, n] of Object.entries(b.items)) if (n > 0) give(id, n, true);
  if (G.bedId === b.id) { G.bedId = null; world.checkpoint(spawnPoint()); }
  send({ t: "x", id: b.id });
  pop(b.x, b.y + 1, b.z, ITEMS[b.type].color, 10, 12, 0.4);
  Kit.sfx("hit");
  if (ui.isOpen("chest")) ui.close();
}

function useBuild(b) {
  const def = PIECES[b.type];
  if (def.door) {
    builds.setDoor(b, !b.open);
    send({ t: "door", id: b.id, o: b.open ? 1 : 0 });
    Kit.sfx("click");
  } else if (b.type === "chest") ui.openChest(b);
  else if (b.type === "workbench" || b.type === "campfire") { if (!ui.isOpen("craft")) ui.toggleCraft(); }
  else if (b.type === "bed") {
    G.bedId = b.id;
    world.checkpoint(spawnPoint());
    ui.pickup("Spawn point set at this bed", "#ef4444");
    Kit.sfx("coin");
  }
}

// ------------------------------------------------------------------ gathering & fighting

function swingArm() { G.swingT = SWING; }

function gather(r) {
  const def = r.def;
  let tier = 0, tool = null;
  if (def.tool) { tool = bestTool(def.tool); tier = tool ? ITEMS[tool].tier : 0; }
  if (tool) { G.showTool = tool; G.showToolT = 0.8; }
  swingArm();
  if (tier < def.tier) {
    island.shake(r);
    Kit.sfx("hit");
    if (G.warnT <= 0) { ui.pickup(`You need a ${TIER_NAME[def.tool][def.tier]} for ${def.name}`, "#ef4444"); G.warnT = 2; }
    return;
  }
  const dmg = def.tool ? [1, 2, 3, 5][tier] : 1;
  r.hp -= dmg;
  island.shake(r);
  const col = r.type === "tree" || r.type === "palm" ? "#7a5230" : r.type === "bush" ? "#2e7d32" : r.type === "crystal" ? "#5eead4" : r.type === "gold" ? "#facc15" : "#8d9096";
  pop(r.x, r.y + Math.min(4, def.pick[1] * 0.5), r.z, col, 5, 10, 0.4);
  if (r.type === "tree") pop(r.x, r.y + 9, r.z, "#3f9a3a", 3, 8, 0.5);
  Kit.sfx("hit");
  send({ t: "h", r: r.id });
  if (r.hp > 0) return;
  island.setResource(r, false);
  const at = G.clock + def.respawn;
  G.gone.set(r.id, at);
  send({ t: "r", r: r.id, at: r1(at) });
  pop(r.x, r.y + 2, r.z, col, 14, 16, 0.6);
  const [id, n] = def.drop;
  give(id, n);
  ui.pickup(`+${n} ${ITEMS[id].name}`, ITEMS[id].color);
  Kit.sfx("coin");
  if (r.type === "crystal") Kit.badge(GAME, "crystal", "Crystal Seeker", "Mine a glowing crystal.");
}

function attack(m) {
  const w = bestWeapon();
  if (w.id) { G.showTool = w.id; G.showToolT = 0.8; }
  swingArm();
  m.flash();
  pop(m.x, m.y + m.def.h * 0.6, m.z, m.def.monster ? "#4c3766" : "#f4a6b8", 5, 9, 0.35);
  Kit.sfx("hit");
  if (isHost()) hitMob(m, w.dmg, "me", me.pos.x, me.pos.z);
  else send({ t: "hit", m: m.id, d: w.dmg, x: r1(me.pos.x), z: r1(me.pos.z) });
}

function onAct(fromHold) {
  if (!G.started || !me.alive || performance.now() < G.coolUntil || ui.isOpen()) return;
  const t = G.target;
  if (!fromHold && G.place && G.place.ok && !(t && (t.kind === "res" || t.kind === "mob") && t.dist !== undefined && t.dist < 6)) {
    if (placeBuild()) return;
  }
  G.coolUntil = performance.now() + 360;
  if (!t) { if (!fromHold) swingArm(); return; }
  if (t.kind === "res") gather(t.r);
  else if (t.kind === "mob") attack(t.m);
  else if (t.kind === "build" && !fromHold) { swingArm(); useBuild(t.b); }
}

function eat() {
  let slot = G.inv[G.sel] && ITEMS[G.inv[G.sel].id].kind === "food" ? G.sel : -1;
  if (slot < 0) {
    let best = 0;
    G.inv.forEach((s, n) => { if (s && ITEMS[s.id].kind === "food" && ITEMS[s.id].food > best) { best = ITEMS[s.id].food; slot = n; } });
  }
  if (slot < 0) { ui.pickup("Nothing to eat. Pick berries or cook meat.", "#f59e0b"); return; }
  if (G.hunger > 97) { ui.pickup("You're full", "#f59e0b"); return; }
  const it = ITEMS[G.inv[slot].id];
  G.hunger = Math.min(100, G.hunger + it.food);
  if (it.heal) world.heal(it.heal);
  ui.pickup(`Ate ${it.name}`, it.color);
  takeSlot(slot, 1);
  Kit.sfx("coin");
}

// ------------------------------------------------------------------ crafting

function stationsNear() {
  const out = { workbench: false, campfire: false };
  if (!builds) return out;
  for (const b of builds.byId.values()) {
    if ((b.type === "workbench" || b.type === "campfire") && Math.hypot(b.x - me.pos.x, b.z - me.pos.z) < 16 && Math.abs(b.y - me.pos.y) < 8) out[b.type] = true;
  }
  return out;
}
function recipeState(r) {
  const locked = !!(r.unlock && !G.found[r.unlock]);
  if (locked) return { locked, ok: false };
  for (const [id, n] of Object.entries(r.cost)) if (count(id) < n) return { ok: false };
  if (r.near && !stationsNear()[r.near]) return { ok: false };
  return { ok: true };
}
function craft(r) {
  const st = recipeState(r);
  if (!st.ok) return;
  for (const [id, n] of Object.entries(r.cost)) take(id, n);
  const left = give(r.out, r.n || 1);
  if (left === (r.n || 1)) { for (const [id, n] of Object.entries(r.cost)) give(id, n, true); return; }
  ui.pickup(`Crafted ${ITEMS[r.out].name}${r.n > 1 ? " x" + r.n : ""}`, "#22c55e");
  Kit.sfx("score");
  const k = ITEMS[r.out].kind;
  if (k === "tool" || k === "weapon") Kit.badge(GAME, "first_tool", "First Tool", "Craft your very first tool.");
  if (r.out.startsWith("iron_")) Kit.badge(GAME, "iron", "Ironclad", "Craft iron gear.");
  if (r.out === "cooked_meat") Kit.badge(GAME, "chef", "Camp Cook", "Cook meat on a campfire.");
  // put a freshly made tool or build piece in your hand if the hotbar has room
  if (k !== "res" && k !== "food") {
    const n = G.inv.findIndex((s) => s && s.id === r.out);
    if (n >= 9) { const free = G.inv.findIndex((s, i) => i < 9 && !s); if (free >= 0) swap(n, free); }
    const h = G.inv.findIndex((s, i) => i < 9 && s && s.id === r.out);
    if (h >= 0 && ITEMS[r.out].kind === "place") select(h);
  }
}

// ------------------------------------------------------------------ chests

function chestTake(c, id) {
  const n = (c.items && c.items[id]) | 0;
  if (!n) return;
  const left = give(id, n);
  const moved = n - left;
  if (!moved) return;
  c.items[id] = left;
  if (!left) delete c.items[id];
  send({ t: "chest", id: c.id, it: id, n: -moved });
  Kit.sfx("click");
  ui.renderChest();
}
function chestPut(c, slot) {
  const s = G.inv[slot];
  if (!s) return;
  c.items[s.id] = (c.items[s.id] || 0) + s.n;
  send({ t: "chest", id: c.id, it: s.id, n: s.n });
  G.inv[slot] = null;
  Kit.sfx("click");
  ui.renderHotbar();
}

// ------------------------------------------------------------------ mobs (simulated by the host)

const mobs = new Map();
let mobSpawnT = 2;
let nextMobId = Math.floor(Math.random() * 1e6);
window.game.mobs = mobs;

function isHost() { return !net || !net.online || net.isHost; }

function removeMob(m) {
  world.scene.remove(m.model);
  m.model.traverse((o) => { if (o.isMesh) { const mats = Array.isArray(o.material) ? o.material : [o.material]; mats.forEach((x) => { if (!x.userData.shared) x.dispose(); }); } });
  mobs.delete(m.id);
}

function playersList() {
  const out = [];
  if (me.alive && G.started) out.push({ id: "me", x: me.pos.x, y: me.pos.y, z: me.pos.z });
  if (net && net.online) for (const p of net.players.values()) {
    const s = p.state;
    if (s && Array.isArray(s.p) && !s.dead) out.push({ id: p.id, x: +s.p[0], y: +s.p[1], z: +s.p[2] });
  }
  return out;
}
function nearLight(x, z, r) { return builds.lights.some((b) => Math.hypot(b.x - x, b.z - z) < r); }

function spawnMob(type, x, y, z) {
  const id = nextMobId++;
  const m = new Mob(world, id, type, x, y, z);
  mobs.set(id, m);
  return m;
}

function trySpawn(type, pls, rmin, rmax) {
  const monster = MOBS[type].monster;
  const pl = pls[Math.floor(Math.random() * pls.length)];
  for (let a = 0; a < 10; a++) {
    const ang = Math.random() * Math.PI * 2, d = rmin + Math.random() * (rmax - rmin);
    const x = pl.x + Math.cos(ang) * d, z = pl.z + Math.sin(ang) * d;
    const i = cellOf(x), k = cellOf(z);
    if (i < 1 || k < 1 || i >= N - 1 || k >= N - 1) continue;
    const h = island.top(i, k);
    if (h < 1 || island.roof(i, k) || builds.inCell(i, k).length) continue;
    if (island.resByCell.get(i + k * N) && island.resByCell.get(i + k * N).alive) continue;
    if (monster && nearLight(x, z, 20)) continue;
    if (!monster && island.kindAt(x, z) !== GRASS && island.kindAt(x, z) !== FOREST) continue;
    if (pls.some((q) => Math.hypot(q.x - x, q.z - z) < rmin * 0.8)) continue;
    const m = spawnMob(type, x, h, z);
    if (monster) pop(x, h + 2, z, "#2b1d3a", 10, 8, 0.6);
    return m;
  }
  return null;
}

function spawnTick(dt, pls) {
  mobSpawnT -= dt;
  if (mobSpawnT > 0 || !pls.length) return;
  mobSpawnT = 2.5;
  let monsters = 0, animals = 0;
  for (const m of mobs.values()) if (m.def.monster) monsters++; else animals++;
  if (isNight()) {
    const cap = Math.min(12, 5 + 2 * (pls.length - 1));
    if (monsters < cap) trySpawn(Math.random() < 0.3 ? "crawler" : "shade", pls, 28, 44);
  } else if (phase() < NIGHT_START - 0.03) {
    if (animals < Math.min(10, 5 + pls.length)) trySpawn(Math.random() < 0.55 ? "pig" : "chicken", pls, 30, 60);
  }
}

// Monsters fear light: they won't step into the glow of a campfire, torch or lamp.
function inLight(x, z) {
  for (const b of builds.lights) if (Math.hypot(b.x - x, b.z - z) < b.light.range * 0.32) return true;
  return false;
}
function tryMove(m, x, z) {
  if (m.def.monster && isNight() && inLight(x, z) && !inLight(m.x, m.z)) return false;
  const g = builds.groundAt(x, z, m.y + 1.6);
  if (g > m.y + 1.6 || g < -1.5) return false;
  if (builds.blocked(x, z, g + 0.05, g + Math.min(4.5, m.def.h))) return false;
  m.x = x; m.z = z;
  m.y = g >= m.y ? g : Math.max(g, m.y - 0.9);
  return true;
}
function moveMob(m, dx, dz, speed, dt) {
  const len = Math.hypot(dx, dz);
  if (len < 1e-4) { m.speed = 0; return true; }
  const vx = (dx / len) * speed * dt, vz = (dz / len) * speed * dt;
  let ok = tryMove(m, m.x + vx, m.z + vz) || tryMove(m, m.x + vx, m.z) || tryMove(m, m.x, m.z + vz);
  m.speed = ok ? speed : 0;
  let d = Math.atan2(-dx, -dz) - m.yaw;
  d = Math.atan2(Math.sin(d), Math.cos(d));
  m.yaw += d * Math.min(1, dt * 8);
  return ok;
}

function simMobs(dt) {
  const pls = playersList();
  spawnTick(dt, pls);
  const day = !isNight();
  for (const m of [...mobs.values()]) {
    const d = m.def;
    // the morning sun burns monsters away
    if (d.monster && day) {
      m.hp -= 5 * dt;
      if (Math.random() < dt * 6) pop(m.x, m.y + d.h * 0.6, m.z, "#fb923c", 1, 6, 0.4);
      if (m.hp <= 0) { killMob(m, null); continue; }
    }
    let tgt = null, td = 1e9;
    for (const q of pls) { const dd = Math.hypot(q.x - m.x, q.z - m.z); if (dd < td) { td = dd; tgt = q; } }
    if (!tgt || td > 140) { removeMob(m); continue; }
    m.atk -= dt;
    if (d.monster && td < 70) {
      const dx = tgt.x - m.x, dz = tgt.z - m.z;
      if (m.stuck > 0) {
        m.stuck -= dt;
        moveMob(m, Math.cos(m.wdir), Math.sin(m.wdir), d.speed * 0.8, dt);
      } else if (td > d.reach * 0.7) {
        if (!moveMob(m, dx, dz, d.speed, dt)) { m.stuck = 0.8 + Math.random(); m.wdir = Math.atan2(dz, dx) + (Math.random() < 0.5 ? 1.6 : -1.6); }
      } else {
        m.speed = 0;
        let a = Math.atan2(-dx, -dz) - m.yaw; a = Math.atan2(Math.sin(a), Math.cos(a)); m.yaw += a * Math.min(1, dt * 10);
      }
      if (td < d.reach && Math.abs(tgt.y - m.y) < 4 && m.atk <= 0) {
        m.atk = d.cd;
        if (tgt.id === "me") hurtMe(d.dmg);
        else send({ t: "bite", to: tgt.id, d: d.dmg });
      }
    } else if (!d.monster && m.flee > 0) {
      m.flee -= dt;
      moveMob(m, m.x - m.fx, m.z - m.fz, d.flee, dt);
    } else {
      m.wander -= dt;
      if (m.wander <= 0) { m.wander = 2 + Math.random() * 3; m.wdir = Math.random() * Math.PI * 2; m.walking = Math.random() < 0.6; }
      if (m.walking) { if (!moveMob(m, Math.cos(m.wdir), Math.sin(m.wdir), d.speed, dt)) m.wander = 0; }
      else m.speed = 0;
    }
  }
}

function hitMob(m, dmg, by, fromX, fromZ) {
  if (!mobs.has(m.id)) return;
  m.hp -= dmg;
  m.flash();
  // knock back
  const dx = m.x - fromX, dz = m.z - fromZ, len = Math.hypot(dx, dz) || 1;
  for (let n = 0; n < 5; n++) tryMove(m, m.x + (dx / len) * 0.5, m.z + (dz / len) * 0.5);
  if (!m.def.monster) { m.flee = 3.5; m.fx = fromX; m.fz = fromZ; }
  if (m.hp <= 0) killMob(m, by);
}

function killMob(m, by) {
  removeMob(m);
  mobPop(m);
  if (by === "me") reward(m.type);
  if (net && net.online) send({ t: "kill", m: m.id, by: by === "me" ? net.me.id : by, ty: MOB_TYPES.indexOf(m.type), x: r1(m.x), y: r1(m.y), z: r1(m.z) });
}
function mobPop(m) {
  const col = m.type === "shade" ? "#55733a" : m.type === "crawler" ? "#3b2a4f" : m.type === "pig" ? "#f4a6b8" : "#f8fafc";
  pop(m.x, m.y + m.def.h * 0.5, m.z, col, 16, 14, 0.55);
}
function reward(type) {
  const d = MOBS[type];
  if (d.drop) { give(d.drop[0], d.drop[1]); ui.pickup(`+${d.drop[1]} ${ITEMS[d.drop[0]].name}`, ITEMS[d.drop[0]].color); Kit.sfx("coin"); }
  if (d.monster) {
    SAVE.stats.kills++;
    Kit.sfx("score");
    if (SAVE.stats.kills >= 25) Kit.badge(GAME, "hunter", "Monster Hunter", "Defeat 25 monsters.");
  }
}

function hurtMe(dmg) {
  if (!me.alive) return;
  const d = Math.max(1, Math.round(dmg * (1 - armor())));
  world.damage(d);
  ui.hurt();
  Kit.sfx("hit");
}

function applyMobSnap(list) {
  if (!Array.isArray(list)) return;
  const seen = new Set();
  for (const e of list) {
    if (!Array.isArray(e)) continue;
    const [id, ti, x, y, z, yaw] = e;
    const type = MOB_TYPES[ti];
    if (!type) continue;
    seen.add(id);
    let m = mobs.get(id);
    if (!m) { m = new Mob(world, id, type, +x, +y, +z); mobs.set(id, m); }
    m.tx = +x; m.ty = +y; m.tz = +z; m.tyaw = +yaw;
  }
  for (const m of [...mobs.values()]) if (!seen.has(m.id)) removeMob(m);
}

// ------------------------------------------------------------------ online co-op

let net = null;
const outbox = [];
let sendTokens = 10;
function send(e) { if (net && net.online) outbox.push(e); }
function flushOutbox(dt) {
  sendTokens = Math.min(16, sendTokens + dt * 16);
  while (outbox.length && sendTokens >= 1) { net.event(outbox.shift()); sendTokens--; }
}

function sendWorld(to) {
  const w = worldData();
  send({ t: "world", to, seed: w.seed, clock: w.clock, name: Kit.player().name });
  let chunk = [], size = 0;
  for (const b of w.builds) {
    const len = JSON.stringify(b).length;
    if (size + len > 2600 && chunk.length) { send({ t: "wb", to, l: chunk }); chunk = []; size = 0; }
    chunk.push(b); size += len + 1;
  }
  if (chunk.length) send({ t: "wb", to, l: chunk });
  for (let a = 0; a < w.gone.length; a += 150) send({ t: "wg", to, l: w.gone.slice(a, a + 150) });
  send({ t: "wend", to });
}

let needT = 0;
function requestWorld() {
  G.synced = false;
  G.sync = { data: null, buffer: [] };
  needT = 0.1;
}

function finishSync(from) {
  const data = G.sync.data;
  const buffer = G.sync.buffer;
  if (G.mode === "own") saveNow();
  G.hostName = data.name || (from && from.name) || "";
  loadWorld(data, "guest");
  applyPlayer(SAVE.guest && SAVE.guest.player ? Object.assign({}, SAVE.guest.player, { pos: null }) : {});
  G.synced = true;
  G.sync = null;
  for (const [pl, e] of buffer) applyLive(pl, e);
  ui.announce(`Welcome to ${G.hostName || "your friend"}'s island!`, "Everyone here plays on the same island.");
  ui.renderHotbar();
}

function onEvent(pl, e) {
  if (!e || typeof e !== "object") return;
  const toMe = e.to === net.me.id;
  switch (e.t) {
    case "need": if (net.isHost && G.synced) sendWorld(pl.id); return;
    case "world": if (toMe && !net.isHost && G.sync) { G.sync.data = { seed: e.seed | 0, clock: +e.clock || 0, name: String(e.name || pl.name || ""), builds: [], gone: [] }; } return;
    case "wb": if (toMe && G.sync && G.sync.data && Array.isArray(e.l)) G.sync.data.builds.push(...e.l); return;
    case "wg": if (toMe && G.sync && G.sync.data && Array.isArray(e.l)) G.sync.data.gone.push(...e.l); return;
    case "wend": if (toMe && G.sync && G.sync.data) finishSync(pl); return;
  }
  if (!G.synced) { if (G.sync && ["b", "x", "r", "door", "chest"].includes(e.t)) G.sync.buffer.push([pl, e]); else applyLive(pl, e, true); return; }
  applyLive(pl, e);
}

function applyLive(pl, e, worldless) {
  switch (e.t) {
    case "b": if (!worldless && Array.isArray(e.b)) { const b = addBuildArr(e.b); if (b) { pop(b.x, b.y + 1, b.z, ITEMS[b.type].color, 6, 8, 0.3); island.lastCell = -1; } } break;
    case "x": if (!worldless) { const b = builds.remove(String(e.id)); if (b) { pop(b.x, b.y + 1, b.z, ITEMS[b.type].color, 8, 10, 0.4); island.lastCell = -1; if (G.bedId === b.id) { G.bedId = null; world.checkpoint(spawnPoint()); } } } break;
    case "r": if (!worldless) {
      const r = island.map.res[e.r | 0];
      if (r) { if (r.alive) { island.setResource(r, false); pop(r.x, r.y + 2, r.z, "#8d9096", 8, 12, 0.5); } G.gone.set(r.id, +e.at || G.clock + r.def.respawn); }
    } break;
    case "h": if (!worldless) { const r = island.map.res[e.r | 0]; if (r && r.alive) { island.shake(r); pop(r.x, r.y + 2, r.z, r.type === "tree" ? "#7a5230" : "#8d9096", 3, 8, 0.35); } } break;
    case "door": if (!worldless) { const b = builds.byId.get(String(e.id)); if (b && PIECES[b.type].door) builds.setDoor(b, !!e.o); } break;
    case "chest": if (!worldless) {
      const b = builds.byId.get(String(e.id));
      if (b && b.items && ITEMS[e.it]) { b.items[e.it] = Math.max(0, (b.items[e.it] || 0) + (e.n | 0)); if (!b.items[e.it]) delete b.items[e.it]; if (ui.isOpen("chest")) ui.renderChest(); }
    } break;
    case "hit": if (isHost()) { const m = mobs.get(e.m); if (m) hitMob(m, Math.min(20, +e.d || 1), pl.id, +e.x || m.x, +e.z || m.z); } break;
    case "kill": {
      const m = mobs.get(e.m);
      const fake = { x: +e.x || 0, y: +e.y || 0, z: +e.z || 0, type: MOB_TYPES[e.ty] || "shade" };
      fake.def = MOBS[fake.type];
      if (m) removeMob(m);
      mobPop(fake);
      if (e.by === net.me.id) reward(fake.type);
    } break;
    case "bite": if (e.to === net.me.id) hurtMe(Math.min(30, +e.d || 0)); break;
    case "newworld": if (G.mode === "guest" && !net.isHost) {
      loadWorld({ seed: e.seed | 0, clock: +e.clock || START_CLOCK, builds: [], gone: [] }, "guest");
      teleport(spawnPoint());
      world.checkpoint(spawnPoint());
      ui.announce("The host started a new island!", "");
    } break;
  }
}

function onState(pl) {
  const s = pl.state;
  if (!s || net.isHost) return;
  if (typeof s.w === "number" && G.synced) {
    if (Math.abs(s.w - G.clock) > 3) G.clock = s.w; else G.clock += (s.w - G.clock) * 0.2;
  }
  if (s.mb) applyMobSnap(s.mb);
}

function setupNet() {
  net = Kit.net(GAME, { room: "main" });
  window.net = net;
  world.online(net);
  const rawState = net.state;
  net.state = (o) => rawState(Object.assign(o, G.extra));
  net.on("status", (on) => {
    if (on && !net.isHost) requestWorld();
    else if (on) ui.pickup("You're online: friends who join will play on your island", "#3b82f6");
  });
  net.on("event", onEvent);
  net.on("state", onState);
  net.on("leave", () => { if (net.isHost && G.sync) { G.synced = true; G.sync = null; } });
}

function updateExtra() {
  const e = { d: G.days, bu: SAVE.stats.placed };
  if (isHost() && G.synced) {
    e.w = r1(G.clock);
    e.mb = [...mobs.values()].slice(0, 20).map((m) => [m.id, MOB_TYPES.indexOf(m.type), r1(m.x), r1(m.y), r1(m.z), r2(m.yaw)]);
  }
  G.extra = e;
}

// ------------------------------------------------------------------ input

Kit.onKey((code) => {
  if (!G.started) return;
  if (code.startsWith("Digit") && code.length === 6) { const n = +code[5]; if (n >= 1 && n <= 9) select(n - 1); return; }
  switch (code) {
    case "KeyC": ui.toggleCraft(); break;
    case "KeyF": onAct(false); G.fHeld = performance.now(); break;
    case "KeyE": if (me.alive) eat(); break;
    case "KeyR": G.rot = (G.rot + 1) % 4; break;
    case "KeyX": if (me.alive && !ui.isOpen()) removeBuild(G.target); break;
  }
});

// ------------------------------------------------------------------ main loop

let saveT = 5, hudT = 0, boardT = 0, extraT = 0, respawnT = 0, clockT = 0;
let wasHost = true;

function survival(dt) {
  if (!me.alive) return;
  G.hunger = Math.max(0, G.hunger - dt * 0.2);
  if (G.hunger <= 0) {
    G.starve += dt;
    if (G.starve > 2) { G.starve = 0; world.damage(3); ui.hurt(); if (G.warnT <= 0) { ui.pickup("You're starving! Eat something (E)", "#ef4444"); G.warnT = 4; } }
  } else if (G.hunger > 45 && me.health < me.maxHealth) {
    G.regen += dt;
    if (G.regen > 2.5) { G.regen = 0; world.heal(1); }
  }
  // swimming in deep water
  const top = island.topAt(me.pos.x, me.pos.z);
  const deep = top < WATER_Y - 4.2;
  if (deep && me.pos.y < WATER_Y - 2.2) {
    const want = WATER_Y - 3.9 - me.pos.y;
    me.vel.y = Math.max(-6, Math.min(6, want * 4)) + 196.2 * dt;
    if (Kit.key("Space")) me.vel.y = want > -0.6 ? 34 : 10 + 196.2 * dt;
    me.speed = 10;
  } else me.speed = 16;
  // never get stuck inside the ground
  if (me.pos.y < top - 1.2 && !island.roof(cellOf(me.pos.x), cellOf(me.pos.z))) { me.pos.y = top; me.vel.y = 0; }
}

function dayNight() {
  const night = isNight();
  if (night && !G.wasNight) {
    G.nightAlive = me.alive;
    ui.announce("Night is falling", "Monsters are coming out. They fear light: stay near a fire or build a shelter!");
    Kit.sfx("lose");
  }
  if (!night && G.wasNight && phase() >= NIGHT_END - 0.01) {
    if (G.nightAlive && me.alive && G.started) {
      G.days++;
      Kit.badge(GAME, "first_night", "Night Survivor", "Survive your first night on the island.");
      if (G.days >= 7) Kit.badge(GAME, "week", "Island Veteran", "Survive 7 days in a row.");
      ui.announce(`Day ${dayNum()}`, `You survived the night! Days survived: ${G.days}`);
      Kit.sfx("win");
    } else ui.announce(`Day ${dayNum()}`, "The sun is up. Monsters are burning away.");
    G.nightAlive = false;
  }
  G.wasNight = night;
}

function respawnResources() {
  for (const [rid, at] of G.gone) {
    if (G.clock < at) continue;
    const r = island.map.res[rid];
    if (!r) { G.gone.delete(rid); continue; }
    if (builds.inCell(r.i, r.k).length || Math.hypot(me.pos.x - r.x, me.pos.z - r.z) < 4) { G.gone.set(rid, G.clock + 60); continue; }
    G.gone.delete(rid);
    island.setResource(r, true, true);
  }
}

function updateHud() {
  const p = phase();
  const left = isNight() ? (NIGHT_END - p) * DAY : ((p < NIGHT_START ? NIGHT_START : 1 + NIGHT_START) - p) * DAY;
  const mm = Math.floor(left / 60), ss = String(Math.floor(left % 60)).padStart(2, "0");
  const label = isNight() ? "Night" : p >= NIGHT_END || p < 0.25 ? "Morning" : p < 0.58 ? "Afternoon" : "Evening";
  Kit.hud(`Day ${dayNum()}<small>${label} · ${isNight() ? "dawn" : "night"} in ${mm}:${ss}</small>`);
  ui.setFood(G.hunger);
  ui.setHealth(me.health);
  ui.setGoal(goal());
}

function goal() {
  const has = (id) => count(id) > 0;
  const placed = (t) => [...builds.byId.values()].some((b) => b.type === t && b.owner === UID);
  if (!has("wood_axe") && !has("wood_pick") && count("wood") < 3) return "Hit a tree (F or click) to collect wood";
  if (!has("wood_pick") && !has("stone_pick") && !has("iron_pick")) return "Press C and craft a Wood Pickaxe";
  if (!placed("workbench")) return count("wood") < 8 ? "Collect 8 wood for a Workbench" : "Craft a Workbench (C), then place it";
  if (!has("stone_pick") && !has("iron_pick")) return "Mine rocks and craft a Stone Pickaxe at your Workbench";
  if (!placed("campfire") && !placed("torch")) return "Build a Campfire before night comes";
  if (!G.found.iron) return "Find iron ore inland and mine it";
  if (!has("iron_pick")) return "Craft an Iron Pickaxe at your Workbench";
  if (!G.found.crystal) return "Explore the caves and find a glowing crystal";
  if (!has("crystal_sword")) return "Craft the Crystal Sword";
  return `Survive as many nights as you can (${G.days} so far)`;
}

function updateBoard() {
  const rows = [{ name: Kit.player().name, values: [G.days, SAVE.stats.placed], me: true }];
  if (net && net.online) for (const p of net.players.values()) {
    const s = p.state || {};
    rows.push({ name: p.name, values: [s.d | 0, s.bu | 0] });
  }
  Kit.leaderboard(["Days", "Builds"], rows);
}

const clockStart = performance.now();
world.start((dt) => {
  if (!island) return;
  const now = performance.now();
  if (G.started) {
    if (isHost() && G.synced) G.clock += dt;
    else if (G.synced) G.clock += dt;   // guests tick too, the host's clock keeps them in step
    survival(dt);
    dayNight();
  }
  if (net && net.online) {
    if (wasHost !== net.isHost && net.isHost) { G.synced = true; G.sync = null; }
    wasHost = net.isHost;
    if (G.sync && !net.isHost) {
      needT -= dt;
      if (needT <= 0) { needT = 4; net.event({ t: "need" }); }
    }
  }
  if (isHost() && G.synced && G.started) simMobs(dt);
  for (const m of mobs.values()) m.draw(dt, !(isHost() && G.synced));

  G.swingT = Math.max(0, G.swingT - dt); G.showToolT -= dt; G.warnT -= dt;
  island.updateColliders(me.pos.x, me.pos.z);

  // aiming, highlight and ghost
  if (G.started && me.alive) {
    G.target = resolveTarget();
    const [text, warn] = describe(G.target);
    if (G.target) { targetBox(G.target, b3); selBox.visible = true; b3.getCenter(selBox.position); b3.getSize(selBox.scale).addScalar(0.15); }
    else selBox.visible = false;
    ui.setTarget(ui.isOpen() ? "" : text, warn);
    updateGhost();
    if (ghost.visible) selBox.visible = false;
    // holding the mouse button or F keeps swinging at resources and monsters
    const holding = (mouseDown && !mouseDown.moved && now - mouseDown.t > 350) || (Kit.key("KeyF") && G.fHeld && now - G.fHeld > 350);
    if (holding && G.target && (G.target.kind === "res" || G.target.kind === "mob")) onAct(true);
  } else { selBox.visible = false; ghost.visible = false; ui.setTarget(""); }
  ui.showCross(world.cam.shiftLock);
  updateHeld();

  stepParticles(dt);
  island.animate(dt);
  builds.animate(now / 1000);
  island.water.position.y = WATER_Y + Math.sin(now / 1400) * 0.06;
  updateSky();
  updateLights();

  clockT -= dt;
  if (clockT <= 0) { clockT = 1; respawnResources(); }
  hudT -= dt;
  if (hudT <= 0) { hudT = 0.25; updateHud(); }
  boardT -= dt;
  if (boardT <= 0) { boardT = 1; updateBoard(); }
  extraT -= dt;
  if (extraT <= 0) { extraT = 0.1; updateExtra(); }
  saveT -= dt;
  if (saveT <= 0 && G.started) { saveT = 10; saveNow(); }
  if (net && net.online) flushOutbox(dt);
  else outbox.length = 0;
});

world.onDeath(() => {
  Kit.finish(GAME, G.days);
  const d = G.days;
  G.days = 0;
  G.nightAlive = false;
  ui.announce("You were defeated!", d ? `You survived ${d} day${d === 1 ? "" : "s"}. Your items are safe.` : "Your items are safe. Try again!");
  ui.close();
});
world.onRespawn(() => {
  G.hunger = Math.max(G.hunger, 60);
  island.updateColliders(me.pos.x, me.pos.z, true);
});
addEventListener("pagehide", () => { if (G.started) { Kit.finish(GAME, G.days); saveNow(); } });

// ------------------------------------------------------------------ start

const saved = SAVE.solo;
if (saved && saved.seed) {
  loadWorld(saved, "own");
  applyPlayer(saved.player);
} else {
  loadWorld({ seed: newSeed(), clock: START_CLOCK, builds: [], gone: [] }, "own");
  applyPlayer({});
}
// look toward the middle of the island
world.cam.yaw = Math.atan2(me.pos.x, me.pos.z);
me.yaw = world.cam.yaw;
setupNet();
updateHud();
updateBoard();
ui.renderHotbar();

ui.title({
  info: saved && saved.seed ? `Your island #${G.seed} · Day ${dayNum()}` : `A brand new island #${G.seed}`,
  continue: !!(saved && saved.seed),
  canNew: !!(saved && saved.seed),
}).then((isNew) => {
  if (isNew && G.mode === "own") newWorld(false);
  G.started = true;
  me.frozen = false;
  G.wasNight = isNight();
  G.nightAlive = isNight() && me.alive;
  canvas.focus();
  if (!count("wood") && !G.inv.some(Boolean)) ui.announce("Welcome to Survival Island", "Hit trees to collect wood, then press C to craft.");
  saveNow();
});
window.game.api = { give, gather, attack, newWorld, craft: (id) => craft(RECIPES.find((r) => r.out === id)), setPhase: (p) => { G.clock = Math.floor(G.clock / DAY) * DAY + p * DAY; }, count, teleport, spawnMob, saveNow, recipeState, placeBuild, eat, isHost, pickPointer };
