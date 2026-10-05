// Dungeon Quest: main game (town, dungeons, combat, RPG systems, online co-op).
import { THREE } from "../kit3d.js";
import * as D from "./data.js";
import * as M from "./models.js";
import { Zone, buildTown, buildDungeon, planDungeon, portal, CELL } from "./level.js";

const $ = (id) => document.getElementById(id);
const esc = (v) => String(v).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const num = (v, d) => (typeof v === "number" && isFinite(v) ? v : d === undefined ? 0 : d);
const r1 = (v) => Math.round(v * 10) / 10;
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const yawTo = (dx, dz) => Math.atan2(-dx, -dz);
const angDiff = (a, b) => Math.atan2(Math.sin(a - b), Math.cos(a - b));

export function boot(World) {
  const world = new World({ sky: "#8fd3ff", health: true, cameraButton: "right", cameraDistance: 24 });
  world.cam.pitch = 0.62;
  const scene = world.scene;
  const fx = new M.Effects(scene);
  window.world = world;

  // ================================================================ save

  function freshSave() {
    return { v: 1, lv: 1, xp: 0, gold: 40, earned: 0, inv: [], eq: { weapon: D.starterWeapon(), armor: D.starterArmor() }, pots: [3, 1], cleared: {}, kills: 0, runs: 0 };
  }
  function loadSave() {
    try {
      const s = JSON.parse(localStorage.getItem(D.SAVE_KEY));
      if (s && s.v === 1 && s.eq) return Object.assign(freshSave(), s);
    } catch (_) {}
    return freshSave();
  }
  let save = loadSave();
  let dirty = false;
  const markDirty = () => { dirty = true; };
  function persist() {
    dirty = false;
    try { localStorage.setItem(D.SAVE_KEY, JSON.stringify(save)); } catch (_) {}
  }
  setInterval(() => { if (dirty) persist(); }, 1500);
  addEventListener("pagehide", () => { if (dirty) persist(); });

  let stats = D.playerStats(save);

  // ================================================================ sounds (small synth; respects the BlockOS mute setting)

  let actx = null;
  function tone(freq, len, type, vol, to) {
    try { if (localStorage.getItem("blockos.muted") === "1") return; } catch (_) {}
    try {
      actx = actx || new (window.AudioContext || window.webkitAudioContext)();
      const t = actx.currentTime;
      const o = actx.createOscillator(), g = actx.createGain();
      o.type = type;
      o.frequency.setValueAtTime(freq, t);
      if (to) o.frequency.exponentialRampToValueAtTime(to, t + len);
      g.gain.setValueAtTime(vol, t);
      g.gain.exponentialRampToValueAtTime(0.001, t + len);
      o.connect(g).connect(actx.destination);
      o.start(t);
      o.stop(t + len);
    } catch (_) {}
  }
  const sfx = {
    swing: () => tone(520, 0.09, "triangle", 0.04, 180),
    hit: () => tone(200, 0.08, "square", 0.05, 90),
    crit: () => { tone(300, 0.08, "square", 0.06, 120); tone(900, 0.1, "triangle", 0.04, 1400); },
    hurt: () => tone(160, 0.18, "sawtooth", 0.07, 70),
    shoot: () => tone(700, 0.18, "sine", 0.03, 300),
    slam: () => tone(90, 0.35, "sawtooth", 0.09, 40),
    roar: () => { tone(70, 0.8, "sawtooth", 0.1, 45); tone(110, 0.6, "square", 0.04, 60); },
    dash: () => tone(260, 0.18, "sawtooth", 0.04, 900),
    spin: () => tone(300, 0.3, "triangle", 0.05, 800),
    heal: () => { tone(523, 0.15, "sine", 0.06); setTimeout(() => tone(784, 0.25, "sine", 0.06), 120); },
    gate: () => tone(180, 0.4, "square", 0.05, 600),
    drink: () => tone(400, 0.2, "sine", 0.05, 900),
  };

  // ================================================================ player

  const me = world.spawnPlayer({ pos: [0, 1, 40] });
  me.frozen = true;
  let weaponModel = null;
  function refreshWeapon() {
    const armR = me.group.userData.limbs.armR;
    if (weaponModel) armR.remove(weaponModel);
    const w = save.eq.weapon;
    weaponModel = M.makeWeapon(w ? w.kind : "sword", w ? D.RARITIES[w.rar].color : "#9ca3af");
    weaponModel.position.set(0, -1.95, -0.1);
    armR.add(weaponModel);
  }
  refreshWeapon();

  let swingT = 1, spinT = 0, swingCount = 0;
  function poseArms(group, swingK, spinK, air) {
    const { armR, armL } = group.userData.limbs;
    if (spinK > 0) {
      armR.rotation.x = 1.5; armL.rotation.x = 1.5; armR.rotation.z = 0;
      group.rotation.y += (1 - spinK) * Math.PI * 4;
    } else if (swingK < 1) {
      const e = 1 - Math.pow(1 - swingK, 2.2);
      armR.rotation.x = 2.7 - 3.1 * e;
      armR.rotation.z = 0.45 - 0.75 * e;
    } else if (!air) {
      armR.rotation.x = 0.45 + armR.rotation.x * 0.25;
      armR.rotation.z = 0;
    } else armR.rotation.z = 0;
  }
  const baseAnimate = me.group.userData.animate;
  me.group.userData.animate = (dt, speed, air) => { baseAnimate(dt, speed, air); poseArms(me.group, swingT, spinT, air); };

  function refreshStats() {
    stats = D.playerStats(save);
    const f = me.maxHealth ? me.health / me.maxHealth : 1;
    me.maxHealth = stats.hp;
    if (me.alive) me.health = Math.max(1, Math.min(stats.hp, Math.round(f * stats.hp)));
    world.updateHealthBar();
  }
  me.maxHealth = stats.hp;
  me.health = stats.hp;

  // Keep the camera from looking through dungeon walls.
  const baseCamera = world.updateCamera.bind(world);
  const ray = new THREE.Ray(), hitP = new THREE.Vector3(), camTarget = new THREE.Vector3();
  world.updateCamera = () => {
    baseCamera();
    if (!zone || !zone.walls.length) return;
    camTarget.set(me.pos.x, me.pos.y + 4.5, me.pos.z);
    const cam = world.camera.position;
    ray.origin.copy(camTarget);
    ray.direction.subVectors(cam, camTarget);
    const len = ray.direction.length();
    if (len < 0.01) return;
    ray.direction.divideScalar(len);
    let best = len;
    for (const w of zone.walls) {
      if (!w.visible) continue;
      const b = w.userData.part.box;
      if (ray.intersectBox(b, hitP)) {
        const d = hitP.distanceTo(camTarget);
        if (d < best) best = d;
      }
    }
    if (best < len) cam.copy(camTarget).addScaledVector(ray.direction, Math.max(2.5, best - 0.8));
  };

  // ================================================================ online

  let net = null;
  let awaitingInit = null;
  const hasServer = () => { try { return !!localStorage.getItem("blockos.server"); } catch (_) { return false; } };
  const online = () => !!(net && net.online);
  const isHost = () => !net || !net.online || net.isHost;
  const othersHere = () => (online() ? net.players.size : 0);

  function connect(room) {
    if (net) { try { net.close(); } catch (_) {} }
    document.querySelectorAll(".kit-chat").forEach((e) => e.remove());
    for (const r of world.remotes.values()) world.scene.remove(r.model);
    world.remotes.clear();
    const n = Kit.net(D.GAME_ID, { room });
    const sendState = n.state;
    n.state = (o) => {
      const w = save.eq.weapon;
      o.lv = save.lv; o.g = save.gold; o.sw = swingCount; o.wk = w ? w.kind : "sword"; o.wr = w ? w.rar : 0;
      o.hp = me.maxHealth ? Math.round((me.health / me.maxHealth) * 100) : 100;
      sendState(o);
    };
    world.online(n);
    n.on("event", (pl, ev) => { if (n === net && ev && typeof ev === "object") onEvent(pl, ev); });
    net = n;
    window.net = n;
    return n;
  }
  // Everything we tell the room goes out in small batches (the server allows about 40 messages a second).
  let outbox = [], flushT = 0;
  const send = (ev) => { if (online() && net.players.size) outbox.push(ev); };
  function flush(dt) {
    flushT -= dt;
    if (flushT > 0) return;
    flushT = 0.1;
    if (pendingHits.length) { send({ k: "hit", h: pendingHits.slice(0, 40) }); pendingHits = []; }
    if (!outbox.length) return;
    if (!online() || !net.players.size) { outbox = []; return; }
    let chunk = [], size = 0;
    for (const ev of outbox) {
      const n = JSON.stringify(ev).length;
      if (chunk.length && size + n > 3300) { net.event({ k: "b", l: chunk }); chunk = []; size = 0; }
      chunk.push(ev);
      size += n + 1;
    }
    if (chunk.length) net.event({ k: "b", l: chunk });
    outbox = [];
  }

  function waitUntil(fn, ms) {
    return new Promise((res) => {
      const t0 = performance.now();
      const iv = setInterval(() => { if (fn() || performance.now() - t0 > ms) { clearInterval(iv); res(fn()); } }, 50);
    });
  }

  // ================================================================ zones

  let zone = null;
  let busy = false;
  const enemies = new Map();
  const deadIds = new Set();
  let nextId = 1, maxSeenId = 0, wasHost = true;
  const strikes = [];
  const shots = [];
  const drops = [];
  const chests = [];
  let pendingHits = [];

  function shadowSize(n) {
    const sh = world.sun.shadow;
    if (sh.mapSize.x === n) return;
    sh.mapSize.set(n, n);
    if (sh.map) { sh.map.dispose(); sh.map = null; }
  }
  function setLighting(kind, def) {
    shadowSize(kind === "town" ? 2048 : 1024);
    if (kind === "town") {
      scene.background.set("#8fd3ff");
      scene.fog.color.set("#8fd3ff"); scene.fog.near = 220; scene.fog.far = 600;
      world.hemi.color.set(0xffffff); world.hemi.groundColor.set(0x8a7a66); world.hemi.intensity = 1.15;
      world.sun.color.set(0xffffff); world.sun.intensity = 1.6;
    } else {
      scene.background.set(def.sky);
      scene.fog.color.set(def.sky); scene.fog.near = 45; scene.fog.far = 135;
      world.hemi.color.set(def.hemiSky); world.hemi.groundColor.set(def.hemiGround); world.hemi.intensity = 1.05;
      world.sun.color.set(def.sun); world.sun.intensity = 1.0;
    }
  }

  function teardown() {
    if (zone) zone.destroy();
    zone = null;
    for (const e of enemies.values()) { scene.remove(e.model.root); }
    enemies.clear();
    deadIds.clear();
    for (const s of shots) scene.remove(s.m);
    shots.length = 0;
    strikes.length = 0;
    for (const d of drops) scene.remove(d.g);
    drops.length = 0;
    for (const c of chests) scene.remove(c.g);
    chests.length = 0;
    pendingHits = [];
    fx.clear();
    $("boss").hidden = true;
    nextId = 1; maxSeenId = 0;
  }

  function fade(on, text) {
    const f = $("fade");
    f.querySelector("span").textContent = text || "";
    f.classList.toggle("on", on);
    return new Promise((res) => setTimeout(res, on ? 320 : 10));
  }

  function placeMe(spawn, yaw) {
    world.checkpoint(spawn);
    if (!me.alive) world.respawn();
    me.pos.set(spawn[0], spawn[1], spawn[2]);
    me.vel.set(0, 0, 0);
    me.yaw = yaw;
    world.cam.yaw = yaw;
    me.health = me.maxHealth;
    world.updateHealthBar();
  }

  async function enterTown(fromDungeon) {
    busy = true;
    closePanel();
    await fade(true, "Returning to town...");
    teardown();
    connect("town");
    setLighting("town");
    zone = new Zone(world, "town");
    const t = buildTown(zone, {
      dungeons: D.DUNGEONS,
      unlocked: (i) => i === 0 || !!save.cleared[D.DUNGEONS[i - 1].id],
      onSmith: () => openPanel("smith"),
      onShop: () => openPanel("shop"),
      onPortal: (i) => openPanel("portal", i),
    });
    for (const o of zone.objs) if (o.isGroup) o.userData.ownMats = true;
    outbox = [];
    placeMe(t.spawn, t.yaw);
    world.sun.castShadow = true;
    await fade(false);
    busy = false;
    setObjective(save.lv === 1 && !save.kills ? "Step into the Mossy Crypt portal to start your quest" : "Upgrade gear, buy potions, then pick a dungeon portal");
    if (fromDungeon) Kit.finish(D.GAME_ID, save.earned);
    updateHud(true);
  }

  async function enterDungeon(di) {
    const def = D.DUNGEONS[di];
    busy = true;
    closePanel();
    await fade(true, "Entering " + def.name + "...");
    teardown();
    connect(def.id);
    let init = null;
    if (hasServer()) {
      await waitUntil(() => net.online, 2500);
      if (net.online && net.players.size > 0) {
        $("fade").querySelector("span").textContent = "Joining your party in " + def.name + "...";
        init = await new Promise((res) => {
          awaitingInit = res;
          net.event({ k: "req" });
          setTimeout(() => res(null), 3000);
        });
        awaitingInit = null;
      }
    }
    const seed = init ? num(init.seed) >>> 0 : (Math.random() * 2147483647) | 0;
    setLighting("dungeon", def);
    zone = new Zone(world, "dungeon");
    zone.def = def;
    zone.di = di;
    zone.seed = seed;
    const hooks = { onExit: () => openPanel("leave") };
    const plan = planDungeon(def, seed);
    const b = buildDungeon(zone, plan, def, hooks);
    zone.plan = plan;
    zone.state = plan.rooms.map((r) => (r.kind === "entrance" ? 2 : 0));
    zone.wave = plan.rooms.map(() => 0);
    zone.waveDelay = plan.rooms.map(() => 0);
    zone.far = plan.rooms.map(() => 0);
    zone.bossDead = false;
    zone.spawn = b.spawn;
    // map bounds
    let x0 = 1e9, x1 = -1e9, z0 = 1e9, z1 = -1e9;
    for (const r of plan.rooms) { x0 = Math.min(x0, r.x - r.size / 2); x1 = Math.max(x1, r.x + r.size / 2); z0 = Math.min(z0, r.z - r.size / 2); z1 = Math.max(z1, r.z + r.size / 2); }
    zone.bounds = { x0, x1, z0, z1 };
    if (init && Array.isArray(init.rs)) {
      init.rs.forEach((s, i) => { if (s === 2 && zone.state[i] !== 2) { zone.state[i] = 2; openGate(i, true); } else if (s === 1) zone.state[i] = 1; });
      if (init.bd) { zone.bossDead = true; victoryPortal(); }
    }
    placeMe(b.spawn, b.yaw);
    wasHost = isHost();
    save.runs++;
    markDirty();
    await fade(false);
    busy = false;
    banner(def.name, "Defeat " + D.ENEMIES[def.boss].name.replace(/^The /, "the ") + "!");
    updateObjective();
    updateHud(true);
  }

  // ================================================================ rooms (host decides, everyone shows)

  function roomOf(x, z, margin) {
    if (!zone || !zone.plan) return -1;
    for (const r of zone.plan.rooms) {
      const q = r.size / 2 - (margin || 0);
      if (Math.abs(x - r.x) < q && Math.abs(z - r.z) < q) return r.i;
    }
    return -1;
  }

  function targets() {
    const list = [];
    if (me.alive) list.push({ id: 0, x: me.pos.x, z: me.pos.z });
    if (online()) {
      for (const pl of net.players.values()) {
        const s = pl.state;
        if (s && Array.isArray(s.p) && !s.dead) list.push({ id: pl.id, x: num(s.p[0]), z: num(s.p[2]) });
      }
    }
    return list;
  }

  function activateRoom(r) {
    zone.state[r.i] = 1;
    zone.wave[r.i] = 0;
    send({ k: "room", i: r.i, s: 1 });
    roomStarted(r.i);
    if (r.kind === "boss") {
      zone.waveDelay[r.i] = 1.6;
    } else spawnWave(r);
  }

  function spawnWave(r) {
    const list = r.waves[zone.wave[r.i]] || [];
    zone.wave[r.i]++;
    const tg = targets();
    for (const type of list) {
      let x = r.x, z = r.z;
      for (let k = 0; k < 12; k++) {
        const q = r.size / 2 - 5;
        x = r.x + (Math.random() * 2 - 1) * q;
        z = r.z + (Math.random() * 2 - 1) * q;
        const far = tg.every((t) => Math.hypot(t.x - x, t.z - z) > 11);
        const free = r.solids.every((s) => x < s.x0 - 2 || x > s.x1 + 2 || z < s.z0 - 2 || z > s.z1 + 2);
        const dry = zone.hazards.every((h) => Math.abs(x - h.x) > h.h + 1 || Math.abs(z - h.z) > h.h + 1);
        if (far && free && dry) break;
      }
      createEnemy(nextId++, type, r.i, x, z);
    }
  }

  function spawnBoss(r) {
    const e = createEnemy(nextId++, zone.def.boss, r.i, r.x, r.z);
    e.cd = 2.5;
    sfx.roar();
    return e;
  }

  function roomStarted(i) {
    const r = zone.plan.rooms[i];
    if (r.kind === "boss") {
      banner(D.ENEMIES[zone.def.boss].name, "The boss awakens!");
      sfx.roar();
    }
    updateObjective();
  }

  function clearRoom(r) {
    zone.state[r.i] = 2;
    send({ k: "room", i: r.i, s: 2 });
    roomCleared(r.i);
  }

  function roomCleared(i) {
    const r = zone.plan.rooms[i];
    zone.state[i] = 2;
    if (r.kind === "combat") {
      openGate(i);
      banner("Room cleared!", "The gate is open");
      spawnChest(r, false);
      const sp = safeSpot(r);
      world.checkpoint([sp[0], 1, sp[1]]);
      if (online() && net.players.size > 0) badge("coop");
    }
    updateObjective();
  }

  function safeSpot(r) {
    const d = r.exit ? DIRV[r.exit] : [0, 0];
    const k = r.kind === "boss" ? 0 : r.size / 2 - 7;
    return [r.x + d[0] * k + (d[1] ? 4 : 0), r.z + d[1] * k + (d[0] ? 4 : 0)];
  }

  function openGate(i, quiet) {
    const parts = zone.gates[i];
    if (!parts) return;
    for (const p of parts) zone.removePart(p);
    zone.gates[i] = null;
    if (!quiet) sfx.gate();
  }

  const DIRV = { N: [0, -1], S: [0, 1], E: [1, 0], W: [-1, 0] };

  function victory(fromEvent) {
    if (zone.bossDead) return;
    zone.bossDead = true;
    const def = zone.def;
    const r = zone.plan.rooms[zone.plan.rooms.length - 1];
    zone.state[r.i] = 2;
    save.cleared[def.id] = true;
    badge(D.BOSS_BADGE[def.id]);
    banner("Dungeon cleared!", def.name + " is safe again. Open the chest, then take the portal home.");
    Kit.sfx("win");
    // the boss's helpers crumble away
    for (const e of [...enemies.values()]) {
      if (e.room !== r.i) continue;
      deadIds.add(e.id);
      fx.burst(new THREE.Vector3(e.pos.x, 2.5, e.pos.z), e.def.torso, 8, 12, 0.6);
      removeEnemy(e);
    }
    spawnChest(r, true);
    victoryPortal();
    world.checkpoint([r.x, 1, r.z + 6]);
    markDirty();
    updateObjective();
  }

  function victoryPortal() {
    const r = zone.plan.rooms[zone.plan.rooms.length - 1];
    const d = DIRV[r.entry];
    const along = d[0] !== 0;
    const px = r.x - d[0] * 11, pz = r.z - d[1] * 11;
    portal(zone, px, pz, along ? Math.PI / 2 : 0, "#facc15", zone.def.trim, () => { if (!busy) enterTown(true); }, r.i);
    zone.label("Portal home", { pos: [px, 17, pz], height: 1.4, color: "#fde68a" }, r.i);
  }

  // ================================================================ enemies

  function createEnemy(id, type, room, x, z, hp, maxHp) {
    const def = D.ENEMIES[type];
    const st = D.enemyStats(type, zone.def.tier, 1 + othersHere());
    const model = M.makeMonster(def);
    model.root.position.set(x, -5, z);
    scene.add(model.root);
    const e = {
      id, type, def, role: def.role, st, room, model, pos: model.root.position,
      yaw: Math.random() * 6.28, netYaw: 0, hp: hp === undefined ? st.hp : hp, maxHp: maxHp || st.hp, alive: true,
      target: new THREE.Vector3(x, 0, z), kb: new THREE.Vector3(), flash: 0, cd: 0.8 + Math.random() * 1.2, stun: 0,
      act: 0, anim: null, animT: 0, animW: 0.4, spawnT: 0.7, speedNow: 0, strafe: Math.random() < 0.5 ? 1 : -1, strafeT: 0,
      shots: [], charge: null, summons: 0, seen: performance.now(), far: 0,
    };
    e.pos.y = -5;
    enemies.set(id, e);
    maxSeenId = Math.max(maxSeenId, id);
    if (e.role === "boss") showBoss(e);
    fx.burst(new THREE.Vector3(x, 0.5, z), zone.def.accent, 6, 10, 0.5);
    return e;
  }

  function removeEnemy(e) {
    scene.remove(e.model.root);
    enemies.delete(e.id);
  }

  function startAttack(e, a) {
    a.k = "atk";
    a.i = e.id;
    e.act = (a.w || 0.4) + (a.rec || 0.35);
    send(a);
    strike(a);
  }

  // Everyone runs this: plays the wind-up, shows the danger zone and later checks if it hits *you*.
  function strike(a) {
    const e = enemies.get(a.i);
    const w = clamp(num(a.w, 0.4), 0.05, 3);
    if (e) { e.anim = a.an || "melee"; e.animT = 0; e.animW = w; }
    if (!a.s || a.s === "none") return;
    const s = { s: a.s, x: num(a.x), z: num(a.z), y: num(a.y), r: clamp(num(a.r, 5), 0, 40), a: clamp(num(a.a, 1), 0, 3.2), l: clamp(num(a.l, 10), 0, 60), wd: clamp(num(a.wd, 5), 0, 20), w, d: clamp(num(a.d), 0, 5000), kb: clamp(num(a.kb), 0, 60), c: typeof a.c === "string" ? a.c.slice(0, 9) : "#ef4444" };
    if (a.tele) fx.telegraph(s, 0);
    strikes.push({ s, t: w, an: a.an });
  }

  function inShape(s, x, z) {
    const dx = x - s.x, dz = z - s.z;
    if (s.s === "circle") return dx * dx + dz * dz < (s.r + 0.9) * (s.r + 0.9);
    if (s.s === "cone") {
      const d = Math.hypot(dx, dz);
      if (d > s.r + 0.9) return false;
      if (d < 1.6) return true;
      return Math.abs(angDiff(yawTo(dx, dz), s.y)) < s.a + 0.12;
    }
    if (s.s === "line") {
      const fx2 = -Math.sin(s.y), fz2 = -Math.cos(s.y);
      const along = dx * fx2 + dz * fz2;
      const side = dx * fz2 - dz * fx2;
      return along > -1.5 && along < s.l + 1 && Math.abs(side) < s.wd / 2 + 0.9;
    }
    return false;
  }

  function stepStrikes(dt) {
    for (let i = strikes.length - 1; i >= 0; i--) {
      const k = strikes[i];
      k.t -= dt;
      if (k.t > 0) continue;
      strikes.splice(i, 1);
      const s = k.s;
      if (s.s === "circle" || k.an === "slam") {
        fx.wave({ x: s.x, y: 0, z: s.z }, s.c, s.s === "circle" ? s.r : s.r * 0.8, 0.35);
        if (s.s === "circle") fx.burst(new THREE.Vector3(s.x, 0.5, s.z), zone ? zone.def.wall : "#888", 10, 16, 0.7);
        sfx.slam();
      }
      if (me.alive && inShape(s, me.pos.x, me.pos.z) && me.pos.y < 6) hurt(s.d, s.x, s.z, s.kb);
    }
  }

  function fire(e, sh) {
    const tg = nearestTarget(e, 80);
    let base = sh.base;
    if (sh.aimed) base = tg ? yawTo(tg.x - e.pos.x, tg.z - e.pos.z) : e.yaw;
    const fwdX = -Math.sin(base), fwdZ = -Math.cos(base);
    const off = e.st.radius + 0.5;
    const ev = { k: "shot", x: r1(e.pos.x + fwdX * off), z: r1(e.pos.z + fwdZ * off), h: r1(sh.h || 3.5), y: +base.toFixed(3), n: sh.n, sp: sh.spread, v: sh.v, d: Math.round(sh.d), c: sh.c };
    send(ev);
    shoot(ev);
  }

  // Everyone simulates every projectile, but only checks it against their own player.
  const orbGeoCache = {};
  function shoot(ev) {
    const n = clamp(Math.round(num(ev.n, 1)), 1, 24);
    const sp = num(ev.sp, 0.3), v = clamp(num(ev.v, 15), 4, 40);
    const color = typeof ev.c === "string" ? ev.c.slice(0, 9) : "#ffffff";
    for (let k = 0; k < n; k++) {
      const a = num(ev.y) + (n >= 10 ? k * sp : (k - (n - 1) / 2) * sp);
      const m = M.makeOrb(color);
      m.position.set(num(ev.x), num(ev.h, 3.5), num(ev.z));
      scene.add(m);
      shots.push({ m, vx: -Math.sin(a) * v, vz: -Math.cos(a) * v, life: 4.5, d: clamp(num(ev.d), 0, 5000) });
    }
    if (shots.length > 90) { const old = shots.shift(); scene.remove(old.m); }
    sfx.shoot();
  }

  function stepShots(dt) {
    for (let i = shots.length - 1; i >= 0; i--) {
      const s = shots[i];
      s.life -= dt;
      const p = s.m.position;
      p.x += s.vx * dt;
      p.z += s.vz * dt;
      s.m.rotation.y += dt * 5;
      s.m.rotation.x += dt * 3;
      let dead = s.life <= 0;
      if (!dead && me.alive && Math.hypot(p.x - me.pos.x, p.z - me.pos.z) < 1.7 && p.y > me.pos.y - 0.5 && p.y < me.pos.y + 5.6) {
        hurt(s.d, p.x - s.vx, p.z - s.vz, 8);
        dead = true;
      }
      if (!dead && zone && zone.plan) {
        const ri = roomOf(p.x, p.z, 0);
        if (ri >= 0) for (const so of zone.plan.rooms[ri].solids) if (p.x > so.x0 && p.x < so.x1 && p.z > so.z0 && p.z < so.z1 && p.y < so.y1) { dead = true; break; }
      }
      if (!dead && zone) {
        for (const w of zone.walls) {
          const b = w.userData.part.box;
          if (p.x > b.min.x && p.x < b.max.x && p.z > b.min.z && p.z < b.max.z && p.y < b.max.y) { dead = true; break; }
        }
      }
      if (dead) {
        fx.burst(p, "#ffffff", 3, 6, 0.3);
        scene.remove(s.m);
        shots.splice(i, 1);
      }
    }
  }

  function nearestTarget(e, range) {
    let best = null, bd = range;
    for (const t of targets()) {
      const d = Math.hypot(t.x - e.pos.x, t.z - e.pos.z);
      if (d < bd) { bd = d; best = t; }
    }
    if (best) best.d = bd;
    return best;
  }

  // ---------------------------------------------------------------- host AI

  function aiStep(e, dt) {
    if (e.spawnT > 0) return;
    const st = e.st;
    e.cd -= dt;
    e.stun -= dt;
    e.act -= dt;
    // queued projectiles
    for (let i = e.shots.length - 1; i >= 0; i--) {
      const sh = e.shots[i];
      sh.t -= dt;
      if (sh.t <= 0) { e.shots.splice(i, 1); fire(e, sh); }
    }
    let mx = 0, mz = 0, speed = 0;
    const tg = nearestTarget(e, e.role === "boss" ? 90 : 60);
    if (e.charge) {
      e.charge.t -= dt;
      mx = e.charge.vx; mz = e.charge.vz; speed = 1;
      if (e.charge.t <= 0) e.charge = null;
    } else if (tg && e.act <= 0 && e.stun <= 0) {
      const dx = tg.x - e.pos.x, dz = tg.z - e.pos.z, dist = tg.d;
      const face = yawTo(dx, dz);
      e.yaw += angDiff(face, e.yaw) * Math.min(1, dt * 8);
      const ux = dx / (dist || 1), uz = dz / (dist || 1);
      const reach = e.st.radius;
      if (e.role === "rusher") {
        if (dist > 3.2 + reach) { mx = ux; mz = uz; speed = st.speed; }
        else if (e.cd <= 0) {
          startAttack(e, { s: "cone", x: r1(e.pos.x), z: r1(e.pos.z), y: +face.toFixed(2), r: 4.6 + reach, a: 1.15, w: 0.42, d: Math.round(st.dmg), kb: 10, an: "melee" });
          e.cd = 1.15 + Math.random() * 0.5;
        }
      } else if (e.role === "caster") {
        e.strafeT -= dt;
        if (e.strafeT <= 0) { e.strafe = -e.strafe; e.strafeT = 1.5 + Math.random() * 1.5; }
        if (dist < 12) { mx = -ux; mz = -uz; speed = st.speed; }
        else if (dist > 24) { mx = ux; mz = uz; speed = st.speed; }
        else { mx = -uz * e.strafe; mz = ux * e.strafe; speed = st.speed * 0.5; }
        if (e.cd <= 0 && dist < 34) {
          startAttack(e, { s: "none", w: 0.6, an: "cast", rec: 0.2 });
          const tier = zone.def.tier;
          e.shots.push({ t: 0.6, aimed: true, n: tier >= 2 ? 3 : 1, spread: 0.3, v: 15 + tier * 1.5, d: st.dmg, c: e.def.orb });
          e.cd = 2.3 + Math.random() * 0.9;
        }
      } else if (e.role === "brute") {
        if (dist > 4 + reach) { mx = ux; mz = uz; speed = st.speed; }
        if (dist < 6.5 + reach && e.cd <= 0) {
          startAttack(e, { s: "cone", x: r1(e.pos.x), z: r1(e.pos.z), y: +face.toFixed(2), r: 6.5 + reach, a: 1.0, w: 0.85, d: Math.round(st.dmg), kb: 24, tele: 1, an: "slam", rec: 0.5 });
          e.cd = 2.4 + Math.random() * 0.8;
        }
      } else if (e.role === "boss") {
        bossThink(e, tg, dist, face, ux, uz);
        if (e.act <= 0 && !e.charge && dist > 8 + reach * 0.5) { mx = ux; mz = uz; speed = st.speed; }
      }
    } else if (!tg) {
      // nobody nearby: drift back to the room
      const r = zone.plan.rooms[e.room];
      const dx = r.x - e.pos.x, dz = r.z - e.pos.z, d = Math.hypot(dx, dz);
      if (d > 8) { mx = dx / d; mz = dz / d; speed = st.speed * 0.5; }
    }
    const sp = e.charge ? 1 : speed;
    let vx = mx * sp + e.kb.x, vz = mz * sp + e.kb.z;
    e.pos.x += vx * dt;
    e.pos.z += vz * dt;
    e.kb.multiplyScalar(Math.max(0, 1 - dt * 7));
    e.speedNow = Math.hypot(mx * sp, mz * sp);
    if (e.charge || speed > 0) { const want = e.charge ? yawTo(e.charge.vx, e.charge.vz) : yawTo(mx, mz); if (e.role !== "caster" || dist2(e, tg) > 24) e.yaw += angDiff(want, e.yaw) * Math.min(1, dt * 6); }
    collideEnemy(e);
  }
  const dist2 = (e, t) => (t ? Math.hypot(t.x - e.pos.x, t.z - e.pos.z) : 99);

  function collideEnemy(e) {
    const r = zone.plan.rooms[e.room];
    const rad = e.st.radius;
    const q = r.size / 2 - rad - 0.3;
    e.pos.x = clamp(e.pos.x, r.x - q, r.x + q);
    e.pos.z = clamp(e.pos.z, r.z - q, r.z + q);
    for (const s of r.solids) {
      const cx = clamp(e.pos.x, s.x0, s.x1), cz = clamp(e.pos.z, s.z0, s.z1);
      const dx = e.pos.x - cx, dz = e.pos.z - cz, d = Math.hypot(dx, dz);
      if (d < rad) {
        if (d > 0.001) { e.pos.x = cx + (dx / d) * rad; e.pos.z = cz + (dz / d) * rad; }
        else e.pos.x = s.x0 - rad;
      }
    }
    for (const o of enemies.values()) {
      if (o === e || !o.alive) continue;
      const dx = e.pos.x - o.pos.x, dz = e.pos.z - o.pos.z, d = Math.hypot(dx, dz), min = rad + o.st.radius;
      if (d < min && d > 0.001) {
        const push = (min - d) * (o.role === "boss" ? 1 : 0.5);
        e.pos.x += (dx / d) * push; e.pos.z += (dz / d) * push;
      }
    }
  }

  function bossThink(e, tg, dist, face, ux, uz) {
    const st = e.st, tier = zone.def.tier;
    const phase2 = e.hp < e.maxHp * 0.5;
    if (e.summons < 2 && e.hp < e.maxHp * (e.summons === 0 ? 0.66 : 0.33)) {
      e.summons++;
      const r = zone.plan.rooms[e.room];
      for (let k = 0; k < 1 + tier; k++) {
        const a = Math.random() * 6.28;
        createEnemy(nextId++, zone.def.enemies[k % 2 === 0 ? 0 : 1], e.room, clamp(e.pos.x + Math.cos(a) * 9, r.x - 20, r.x + 20), clamp(e.pos.z + Math.sin(a) * 9, r.z - 20, r.z + 20));
      }
      send({ k: "msg", t: "The boss calls for help!" });
      banner("", "The boss calls for help!");
    }
    if (e.cd > 0 || e.act > 0) return;
    const roll = Math.random();
    let pat;
    if (dist < 11) pat = roll < 0.55 ? "slam" : roll < 0.8 ? "nova" : "charge";
    else pat = roll < 0.4 ? "charge" : roll < 0.75 ? "nova" : tier >= 2 ? "barrage" : "slam";
    if (pat === e.lastPat && pat !== "slam" && Math.random() < 0.6) pat = dist < 11 ? "slam" : "nova";
    e.lastPat = pat;
    const color = e.def.orb || "#ef4444";
    let w = 0;
    if (pat === "slam") {
      w = phase2 ? 0.85 : 1.05;
      startAttack(e, { s: "circle", x: r1(e.pos.x), z: r1(e.pos.z), r: 11 + tier, w, d: Math.round(st.dmg * 1.5), kb: 30, tele: 1, an: "slam", rec: 0.6, c: "#ef4444" });
    } else if (pat === "nova") {
      w = 0.7;
      startAttack(e, { s: "none", w, an: "cast", rec: 0.3 });
      const n = 12 + tier * 2, waves = phase2 ? 4 : 3, base = Math.random() * 6.28;
      for (let k = 0; k < waves; k++) e.shots.push({ t: w + k * 0.5, aimed: false, base: base + (k % 2) * (Math.PI / n), n, spread: (Math.PI * 2) / n, v: 13 + tier, d: st.dmg * 0.7, c: color, h: 3 });
    } else if (pat === "charge") {
      const r = zone.plan.rooms[e.room];
      const q = r.size / 2 - 5;
      let len = clamp(dist + 5, 12, 36);
      let ex = clamp(e.pos.x - Math.sin(face) * len, r.x - q, r.x + q), ez = clamp(e.pos.z - Math.cos(face) * len, r.z - q, r.z + q);
      len = Math.hypot(ex - e.pos.x, ez - e.pos.z);
      const y = yawTo(ex - e.pos.x, ez - e.pos.z);
      w = phase2 ? 0.75 : 0.9;
      startAttack(e, { s: "line", x: r1(e.pos.x), z: r1(e.pos.z), y: +y.toFixed(3), l: r1(len), wd: 7, w, d: Math.round(st.dmg * 1.3), kb: 28, tele: 1, an: "windup", rec: 0.45, c: "#ef4444" });
      e.chargeAt = { t: w, vx: (ex - e.pos.x) / 0.35, vz: (ez - e.pos.z) / 0.35 };
    } else {
      w = 0.5;
      startAttack(e, { s: "none", w, an: "cast", rec: 0.3 });
      for (let k = 0; k < 3; k++) e.shots.push({ t: w + k * 0.35, aimed: true, n: 5, spread: 0.2, v: 19, d: st.dmg * 0.6, c: color, h: 3.5 });
    }
    e.cd = (phase2 ? 1.3 : 2.0) + w;
  }

  // Shared per-frame enemy update (positions, animation, health bars).
  function stepEnemies(dt, host) {
    const now = performance.now();
    for (const e of [...enemies.values()]) {
      if (e.spawnT > 0) {
        e.spawnT -= dt;
        e.pos.y = -5 * Math.max(0, e.spawnT / 0.7);
      } else e.pos.y = 0;
      if (host) {
        if (e.chargeAt) { e.chargeAt.t -= dt; if (e.chargeAt.t <= 0) { e.charge = { t: 0.35, vx: e.chargeAt.vx, vz: e.chargeAt.vz }; e.chargeAt = null; } }
        aiStep(e, dt);
      } else {
        const ox = e.pos.x, oz = e.pos.z;
        e.pos.x += (e.target.x - e.pos.x) * Math.min(1, dt * 10) + e.kb.x * dt;
        e.pos.z += (e.target.z - e.pos.z) * Math.min(1, dt * 10) + e.kb.z * dt;
        e.kb.multiplyScalar(Math.max(0, 1 - dt * 7));
        e.yaw += angDiff(e.netYaw, e.yaw) * Math.min(1, dt * 10);
        e.speedNow = Math.hypot(e.pos.x - ox, e.pos.z - oz) / Math.max(dt, 0.001);
        if (now - e.seen > 1600) { removeEnemy(e); continue; }
      }
      e.model.root.rotation.y = e.yaw;
      if (e.flash > 0) { e.flash -= dt; if (e.flash <= 0) M.flashModel(e.model, false); }
      let pose = "walk", k = 0;
      if (e.anim) {
        e.animT += dt;
        if (e.animT < e.animW) { pose = e.anim === "cast" ? "cast" : "windup"; k = e.animT / e.animW; }
        else if (e.animT < e.animW + 0.2) { pose = e.anim === "cast" ? "cast" : "strike"; k = e.anim === "cast" ? 1 : (e.animT - e.animW) / 0.2; }
        else e.anim = null;
      }
      M.animateMonster(e.model, dt, Math.min(e.speedNow, 20), pose, k);
      M.setHealthBar(e.model, e.hp / e.maxHp);
      if (e.role === "boss") updateBossBar(e);
    }
  }

  // ---------------------------------------------------------------- host: rooms, waves, sync

  let snapT = 0;
  function hostStep(dt) {
    const tg = targets();
    for (const r of zone.plan.rooms) {
      const i = r.i;
      if (zone.state[i] === 0) {
        if (tg.some((t) => Math.abs(t.x - r.x) < r.size / 2 - 3 && Math.abs(t.z - r.z) < r.size / 2 - 3)) activateRoom(r);
      } else if (zone.state[i] === 1) {
        let alive = 0;
        for (const e of enemies.values()) if (e.alive && e.room === i) alive++;
        if (r.kind === "boss") {
          if (!zone.bossDead && !alive) { zone.waveDelay[i] -= dt; if (zone.waveDelay[i] <= 0) spawnBoss(r); }
        } else if (alive === 0) {
          if (zone.wave[i] < r.waves.length) {
            zone.waveDelay[i] += dt;
            if (zone.waveDelay[i] > 1.2 && enemies.size < 14) { zone.waveDelay[i] = 0; spawnWave(r); banner("", "More monsters!"); send({ k: "msg", t: "More monsters!" }); }
          } else clearRoom(r);
        }
      }
    }
    // A fight everyone walked far away from goes back to sleep (its monsters despawn) until someone returns.
    for (const r of zone.plan.rooms) {
      if (zone.state[r.i] !== 1 || r.kind !== "combat") { zone.far[r.i] = 0; continue; }
      const near = tg.some((t) => Math.hypot(t.x - r.x, t.z - r.z) < r.size / 2 + 70);
      zone.far[r.i] = near ? 0 : zone.far[r.i] + dt;
      if (zone.far[r.i] > 10) {
        for (const e of [...enemies.values()]) if (e.room === r.i) { removeEnemy(e); }
        zone.state[r.i] = 0;
        zone.wave[r.i] = 0;
        send({ k: "room", i: r.i, s: 0 });
      }
    }
    snapT -= dt;
    if (snapT <= 0 && online() && net.players.size) {
      snapT = 0.2;
      const list = [];
      for (const e of enemies.values()) if (e.alive) list.push([e.id, D.ENEMY_TYPES.indexOf(e.type), r1(e.pos.x), r1(e.pos.z), Math.max(1, Math.ceil(e.hp)), e.maxHp, e.room, +e.yaw.toFixed(2)]);
      send({ k: "es", e: list });
    }
  }

  function applySnapshot(list) {
    if (!Array.isArray(list) || !zone || zone.kind !== "dungeon") return;
    const now = performance.now();
    for (const a of list.slice(0, 40)) {
      if (!Array.isArray(a)) continue;
      const id = num(a[0]);
      if (deadIds.has(id)) continue;
      const type = D.ENEMY_TYPES[num(a[1], -1)];
      const room = num(a[6]);
      if (!type || !zone.plan.rooms[room]) continue;
      let e = enemies.get(id);
      if (!e) e = createEnemy(id, type, room, num(a[2]), num(a[3]), num(a[4], 1), num(a[5], 1));
      e.target.set(num(a[2]), 0, num(a[3]));
      e.hp = Math.min(e.hp, num(a[4], e.hp));
      e.maxHp = Math.max(1, num(a[5], e.maxHp));
      e.room = room;
      e.netYaw = num(a[7]);
      e.seen = now;
    }
  }

  function becomeHost() {
    // The old host left: take over the monsters from where we last saw them.
    nextId = maxSeenId + 1;
    for (const e of enemies.values()) { e.pos.x = e.target.x; e.pos.z = e.target.z; e.cd = 1; e.act = 0; }
  }

  // ================================================================ combat (you)

  let lastHurtT = 99, lastHitT = 99;
  let swingCd = 0, invulnT = 0, tonicT = 0, potionCd = 0, dashT = 0, hazardT = 0;
  const abilityCd = [0, 0, 0];
  const push = new THREE.Vector3();
  const dashDir = new THREE.Vector3();
  let dashHit = new Set();
  let mouseHeld = false;

  const fwdOf = (yaw) => [-Math.sin(yaw), -Math.cos(yaw)];

  function autoFace(range) {
    let best = null, bd = range;
    for (const e of enemies.values()) {
      if (!e.alive || e.spawnT > 0) continue;
      const d = Math.hypot(e.pos.x - me.pos.x, e.pos.z - me.pos.z) - e.st.radius;
      if (d < bd) { bd = d; best = e; }
    }
    if (best) me.yaw = yawTo(best.pos.x - me.pos.x, best.pos.z - me.pos.z);
    return best;
  }

  function canAct() { return zone && !busy && !panelOpen && me.alive && !titleOpen; }

  function swing() {
    if (!canAct() || swingCd > 0 || dashT > 0) return;
    swingCd = stats.swing;
    swingT = 0;
    swingCount++;
    if (zone.kind === "dungeon") autoFace(stats.range + 4);
    const w = save.eq.weapon;
    fx.swing(me.pos, me.yaw, w ? D.RARITIES[w.rar].color : "#ffffff", stats.kind === "hammer");
    sfx.swing();
    const [fx2, fz2] = fwdOf(me.yaw);
    let hits = 0;
    for (const e of enemies.values()) {
      if (!e.alive || e.spawnT > 0) continue;
      const dx = e.pos.x - me.pos.x, dz = e.pos.z - me.pos.z, d = Math.hypot(dx, dz);
      if (d > stats.range + e.st.radius) continue;
      if (d > 1.5 + e.st.radius && Math.abs(angDiff(yawTo(dx, dz), me.yaw)) > stats.arc) continue;
      hitEnemy(e, 1, d > 0.01 ? dx / d : fx2, d > 0.01 ? dz / d : fz2, 9);
      hits++;
    }
  }

  function hitEnemy(e, mult, kx, kz, force, stun) {
    const crit = Math.random() * 100 < stats.crit;
    let n = stats.atk * mult * (0.9 + Math.random() * 0.2) * (tonicT > 0 ? 1.5 : 1) * (crit ? 1.8 : 1);
    n = Math.max(1, Math.round(n));
    e.flash = 0.11;
    M.flashModel(e.model, true);
    floatText(e.pos.x, e.pos.y + 6.5 * (e.def.scale || 1) * 0.8, e.pos.z, String(n), crit ? "#facc15" : "#ffffff", crit);
    crit ? sfx.crit() : sfx.hit();
    const resist = e.role === "boss" ? 0 : e.role === "brute" ? 0.35 : 1;
    const kbx = kx * force * resist, kbz = kz * force * resist;
    fx.burst(new THREE.Vector3(e.pos.x, 3, e.pos.z), crit ? "#facc15" : "#ffffff", 3, 8, 0.3);
    lastHitT = 0;
    if (isHost()) applyHit(e, n, kbx, kbz, stun);
    else {
      e.hp = Math.max(1, e.hp - n);
      e.kb.x += kbx; e.kb.z += kbz;
      pendingHits.push([e.id, n, r1(kbx), r1(kbz), stun ? 1 : 0]);
    }
  }

  function applyHit(e, n, kbx, kbz, stun) {
    if (!e.alive) return;
    e.hp -= n;
    e.kb.x += kbx; e.kb.z += kbz;
    if (stun) e.stun = Math.max(e.stun, stun);
    if (e.hp <= 0) killEnemy(e);
  }

  function killEnemy(e) {
    send({ k: "die", i: e.id, t: D.ENEMY_TYPES.indexOf(e.type), x: r1(e.pos.x), z: r1(e.pos.z) });
    enemyDied(e.id, e.type, e.pos.x, e.pos.z);
  }

  // Everyone gets the XP and their own loot for every monster defeated in the room.
  function enemyDied(id, type, x, z) {
    if (deadIds.has(id)) return;
    deadIds.add(id);
    const e = enemies.get(id);
    if (e) {
      e.alive = false;
      fx.burst(new THREE.Vector3(e.pos.x, 2.5, e.pos.z), e.def.torso, 10, 14, 0.7 * (e.def.scale || 1));
      fx.burst(new THREE.Vector3(e.pos.x, 3.5, e.pos.z), e.def.skin, 6, 12, 0.5 * (e.def.scale || 1));
      removeEnemy(e);
    }
    if (!zone || zone.kind !== "dungeon" || !D.ENEMIES[type]) return;
    const st = D.enemyStats(type, zone.def.tier, 1);
    save.kills++;
    badge("firstKill");
    gainXp(st.xp);
    const gold = Math.max(1, Math.round(st.gold * (0.8 + Math.random() * 0.45)));
    addGold(gold);
    floatText(x, 4, z, "+" + gold + " gold", "#facc15");
    const role = D.ENEMIES[type].role;
    if (role === "boss") {
      victory();
      return;
    }
    if (Math.random() < st.drop) spawnDrop(x, z, D.makeItem(Math.random() < 0.55 ? "weapon" : "armor", zone.def.tier, D.rollRarity(0)));
    if (Math.random() < 0.05 && save.pots[0] < 20) { save.pots[0]++; floatText(x, 5.5, z, "+1 Health Potion", "#f87171"); }
    markDirty();
  }

  function hurt(raw, fromX, fromZ, kb) {
    if (!me.alive || invulnT > 0 || !zone || zone.kind !== "dungeon") return;
    const red = stats.def / (stats.def + 40);
    const n = Math.max(1, Math.round(raw * (1 - red)));
    invulnT = 0.3;
    lastHurtT = 0;
    floatText(me.pos.x, me.pos.y + 6, me.pos.z, "-" + n, "#f87171");
    sfx.hurt();
    const v = $("vignette");
    v.classList.remove("on"); void v.offsetWidth; v.classList.add("on");
    if (kb) {
      const dx = me.pos.x - fromX, dz = me.pos.z - fromZ, d = Math.hypot(dx, dz) || 1;
      push.x += (dx / d) * kb; push.z += (dz / d) * kb;
    }
    world.damage(n);
  }

  function moveMe(dx, dz) {
    const steps = Math.ceil(Math.max(Math.abs(dx), Math.abs(dz)) / 0.4);
    for (let i = 0; i < steps; i++) {
      me.pos.x += dx / steps; world.collide(me, "x");
      me.pos.z += dz / steps; world.collide(me, "z");
    }
  }

  function useAbility(i) {
    const ab = D.ABILITIES[i];
    if (!canAct()) return;
    if (zone.kind !== "dungeon") { toast(ab.name, "Save your abilities for the dungeons!", ab.color); return; }
    if (save.lv < ab.level) { toast(ab.name + " is locked", "Unlocks at level " + ab.level + ".", "#9ca3af"); return; }
    if (abilityCd[i] > 0) return;
    abilityCd[i] = ab.cd;
    if (i === 0) {
      spinT = 1;
      sfx.spin();
      fx.wave(me.pos, ab.color, stats.range + 2, 0.3);
      fx.swing(me.pos, me.yaw, ab.color, true);
      for (const e of enemies.values()) {
        if (!e.alive || e.spawnT > 0) continue;
        const dx = e.pos.x - me.pos.x, dz = e.pos.z - me.pos.z, d = Math.hypot(dx, dz) || 1;
        if (d < stats.range + 1.5 + e.st.radius) hitEnemy(e, 1.6, dx / d, dz / d, 16);
      }
    } else if (i === 1) {
      autoFace(20);
      const [fx2, fz2] = fwdOf(me.yaw);
      dashDir.set(fx2, 0, fz2);
      dashT = 0.24;
      dashHit = new Set();
      swingT = 0;
      swingCount++;
      invulnT = Math.max(invulnT, 0.4);
      sfx.dash();
    } else {
      const heal = Math.round(stats.hp * 0.35);
      world.heal(heal);
      floatText(me.pos.x, me.pos.y + 6, me.pos.z, "+" + heal, "#4ade80");
      fx.wave(me.pos, ab.color, 14, 0.5);
      fx.burst(new THREE.Vector3(me.pos.x, 2, me.pos.z), "#4ade80", 12, 12, 0.4);
      sfx.heal();
      send({ k: "heal", x: r1(me.pos.x), z: r1(me.pos.z), f: 0.35 });
      for (const e of enemies.values()) {
        if (!e.alive || e.spawnT > 0) continue;
        const dx = e.pos.x - me.pos.x, dz = e.pos.z - me.pos.z, d = Math.hypot(dx, dz) || 1;
        if (d < 11 + e.st.radius) {
          hitEnemy(e, 0.5, dx / d, dz / d, 26, 0.9);
        }
      }
    }
  }

  function drinkPotion(i) {
    if (!canAct() || potionCd > 0) return;
    if (save.pots[i] <= 0) { toast("No " + D.POTIONS[i].name + "s", "Buy more at the potion shop in town.", D.POTIONS[i].color); return; }
    if (i === 0 && me.health >= me.maxHealth) { toast("Health is full", "Save that potion for later!", "#ef4444"); return; }
    save.pots[i]--;
    potionCd = 1;
    sfx.drink();
    if (i === 0) {
      const n = Math.round(stats.hp * 0.45);
      world.heal(n);
      floatText(me.pos.x, me.pos.y + 6, me.pos.z, "+" + n, "#4ade80");
    } else {
      tonicT = 12;
      floatText(me.pos.x, me.pos.y + 6, me.pos.z, "STRENGTH UP", "#c084fc", true);
    }
    markDirty();
  }

  // ================================================================ progression & loot

  function gainXp(n) {
    if (save.lv >= D.MAX_LEVEL) return;
    save.xp += n;
    let up = false;
    while (save.lv < D.MAX_LEVEL && save.xp >= D.xpToNext(save.lv)) {
      save.xp -= D.xpToNext(save.lv);
      save.lv++;
      up = true;
      const ab = D.ABILITIES.find((a) => a.level === save.lv);
      if (ab) toast("New ability: " + ab.name + " (" + ab.label + ")", ab.desc, ab.color);
    }
    if (up) {
      refreshStats();
      if (me.alive) { me.health = me.maxHealth; world.updateHealthBar(); }
      banner("Level up!", "You are now level " + save.lv);
      Kit.sfx("win");
      fx.wave(me.pos, "#facc15", 8, 0.6);
      if (save.lv >= 10) badge("level10");
    }
    markDirty();
  }

  function addGold(n) {
    save.gold += n;
    save.earned += n;
    Kit.sfx("coin");
    markDirty();
  }

  function addItem(it) {
    if (save.inv.length >= D.INV_SIZE) return false;
    save.inv.push(it);
    const r = D.RARITIES[it.rar];
    toast(r.name + " " + (it.slot === "weapon" ? "weapon" : "armor"), it.name + " - " + D.itemStatLine(it), r.color);
    if (it.rar === 3) badge("legendary");
    markDirty();
    return true;
  }

  function spawnDrop(x, z, it) {
    const g = M.makeDrop(D.RARITIES[it.rar].color);
    g.position.set(x, 0, z);
    scene.add(g);
    drops.push({ g, it, t: 0, x, z });
  }

  let fullWarnT = 0;
  function stepDrops(dt) {
    fullWarnT -= dt;
    for (let i = drops.length - 1; i >= 0; i--) {
      const d = drops[i];
      d.t += dt;
      d.g.userData.cube.rotation.y += dt * 2;
      d.g.userData.cube.position.y = 1.2 + Math.sin(d.t * 3) * 0.3;
      if (me.alive && Math.hypot(me.pos.x - d.x, me.pos.z - d.z) < 3.2) {
        if (addItem(d.it)) {
          scene.remove(d.g);
          drops.splice(i, 1);
          Kit.sfx("score");
        } else if (fullWarnT <= 0) {
          fullWarnT = 4;
          toast("Inventory full", "Press I to sell or equip items, then grab this.", "#ef4444");
        }
      }
    }
  }

  function spawnChest(r, boss) {
    const sp = r.kind === "boss" ? [r.x, r.z] : safeSpot(r);
    const g = M.makeChest(boss);
    const y = r.template === "altar" && Math.abs(sp[0] - r.x) < 7 && Math.abs(sp[1] - r.z) < 7 ? 1 : 0;
    g.position.set(sp[0], y, sp[1]);
    if (r.exit) g.rotation.y = yawTo(-DIRV[r.exit][0], -DIRV[r.exit][1]);
    scene.add(g);
    chests.push({ g, boss, open: false, t: 0, x: sp[0], z: sp[1] });
  }

  function stepChests(dt) {
    for (const c of chests) {
      if (c.open) {
        c.t += dt;
        c.g.userData.lid.rotation.x = -Math.min(1.9, c.t * 6);
        continue;
      }
      if (me.alive && Math.hypot(me.pos.x - c.x, me.pos.z - c.z) < 3.8) {
        c.open = true;
        const t = zone.def.tier;
        const gold = Math.round((c.boss ? 90 : 14) * D.TIER_MULT.gold[t - 1] * (0.85 + Math.random() * 0.3));
        addGold(gold);
        floatText(c.x, 4, c.z, "+" + gold + " gold", "#facc15", true);
        fx.burst(new THREE.Vector3(c.x, 2, c.z), "#facc15", 14, 12, 0.4);
        const items = c.boss ? 2 : Math.random() < 0.4 ? 1 : 0;
        for (let k = 0; k < items; k++) {
          const a = (k - (items - 1) / 2) * 1.2 + me.yaw + Math.PI;
          spawnDrop(c.x - Math.sin(a) * 4, c.z - Math.cos(a) * 4, D.makeItem(Math.random() < 0.5 ? "weapon" : "armor", t, D.rollRarity(c.boss ? 2 : 1)));
        }
        if (c.boss) { save.pots[0] = Math.min(20, save.pots[0] + 2); toast("Boss chest", "+2 Health Potions", "#ef4444"); }
        Kit.sfx("score");
        markDirty();
      }
    }
  }

  function badge(key) {
    const b = D.BADGES[key];
    if (b) Kit.badge(D.GAME_ID, b[0], b[1], b[2]);
  }

  // ================================================================ network events

  function onEvent(pl, ev) {
    const inDungeon = zone && zone.kind === "dungeon";
    switch (ev.k) {
      case "req":
        if (inDungeon && isHost() && !busy) send({ k: "init", seed: zone.seed, rs: zone.state, bd: zone.bossDead ? 1 : 0 });
        break;
      case "init":
        if (awaitingInit) awaitingInit(ev);
        break;
      case "es":
        if (inDungeon && !isHost() && !busy) applySnapshot(ev.e);
        break;
      case "die":
        if (inDungeon && !busy) {
          const type = D.ENEMY_TYPES[num(ev.t, -1)];
          if (type) enemyDied(num(ev.i), type, num(ev.x), num(ev.z));
        }
        break;
      case "hit":
        if (inDungeon && isHost() && Array.isArray(ev.h)) {
          for (const h of ev.h.slice(0, 30)) {
            if (!Array.isArray(h)) continue;
            const e = enemies.get(num(h[0]));
            if (!e || !e.alive) continue;
            e.flash = 0.11;
            M.flashModel(e.model, true);
            applyHit(e, clamp(num(h[1]), 0, 100000), clamp(num(h[2]), -40, 40), clamp(num(h[3]), -40, 40), num(h[4]) ? 0.9 : 0);
          }
        }
        break;
      case "atk":
        if (inDungeon && !busy) strike(ev);
        break;
      case "shot":
        if (inDungeon && !busy) shoot(ev);
        break;
      case "room":
        if (inDungeon && !busy && zone.plan.rooms[num(ev.i, -1)]) {
          const i = num(ev.i);
          if (ev.s === 2 && zone.state[i] !== 2) roomCleared(i);
          else if (ev.s === 1 && zone.state[i] === 0) { zone.state[i] = 1; roomStarted(i); }
          else if (ev.s === 0 && zone.state[i] === 1) { zone.state[i] = 0; for (const e of [...enemies.values()]) if (e.room === i) removeEnemy(e); updateObjective(); }
        }
        break;
      case "heal":
        if (inDungeon && me.alive && Math.hypot(num(ev.x) - me.pos.x, num(ev.z) - me.pos.z) < 16) {
          const n = Math.round(stats.hp * clamp(num(ev.f), 0, 0.5));
          world.heal(n);
          floatText(me.pos.x, me.pos.y + 6, me.pos.z, "+" + n, "#4ade80");
          fx.wave(me.pos, "#22c55e", 5, 0.4);
          toast("Healed", pl.name + " healed you!", "#22c55e");
        }
        break;
      case "b":
        if (Array.isArray(ev.l)) for (const sub of ev.l.slice(0, 80)) if (sub && typeof sub === "object" && sub.k !== "b") onEvent(pl, sub);
        break;
      case "msg":
        if (inDungeon && typeof ev.t === "string") banner("", ev.t.slice(0, 40));
        break;
    }
  }

  // ================================================================ UI: hud, hotbar, panels, banners, numbers, minimap

  let titleOpen = true, panelOpen = null, panelArg = null, selected = null, confirmReset = false;

  function toast(title, text, color) { Kit.toast(title, text, color); }

  let bannerT = 0;
  function banner(title, sub) {
    const b = $("banner");
    b.querySelector("b").textContent = title || "";
    b.querySelector("span").textContent = sub || "";
    b.classList.remove("on"); void b.offsetWidth; b.classList.add("on");
    bannerT = 2.8;
  }

  function setObjective(t) { $("obj").textContent = t; }
  function updateObjective() {
    if (!zone || zone.kind !== "dungeon") return;
    const rooms = zone.plan.rooms;
    const total = rooms.length - 2;
    const cleared = rooms.filter((r) => r.kind === "combat" && zone.state[r.i] === 2).length;
    if (zone.bossDead) setObjective("Dungeon cleared! Take the portal home");
    else if (cleared >= total) setObjective("Find and defeat " + D.ENEMIES[zone.def.boss].name.replace(/^The /, "the "));
    else {
      const active = rooms.find((r) => zone.state[r.i] === 1);
      setObjective(active ? "Defeat the monsters to open the gate - rooms " + cleared + "/" + total : "Explore the dungeon - rooms cleared " + cleared + "/" + total);
    }
  }

  let bossShown = null;
  function showBoss(e) { bossShown = e; $("boss").hidden = false; $("boss").querySelector("b").textContent = e.def.name; }
  function updateBossBar(e) {
    if (bossShown !== e) showBoss(e);
    $("bossfill").style.width = Math.max(0, (e.hp / e.maxHp) * 100) + "%";
    $("bosshp").textContent = Math.max(0, Math.ceil(e.hp)) + " / " + e.maxHp;
  }

  let hudKey = "";
  function updateHud(force) {
    const where = !zone ? "" : zone.kind === "town" ? "Town" : zone.def.name + (online() && net.players.size ? " - party of " + (net.players.size + 1) : "");
    const key = save.lv + "|" + save.gold + "|" + where;
    if (key !== hudKey || force) {
      hudKey = key;
      Kit.hud(`<b>Level ${save.lv}</b> <span class="gold">${save.gold.toLocaleString()} gold</span><small>${esc(where)}</small>`);
    }
    const need = D.xpToNext(save.lv);
    $("xpfill").style.width = (save.lv >= D.MAX_LEVEL ? 100 : (save.xp / need) * 100) + "%";
    $("xptext").textContent = save.lv >= D.MAX_LEVEL ? "Max level" : "XP " + save.xp + " / " + need;
    $("hptext").textContent = Math.ceil(me.health) + " / " + me.maxHealth;
  }

  const slotEls = [];
  function buildHotbar() {
    const hb = $("hotbar");
    const mk = (key, name, color, act) => {
      const el = document.createElement("div");
      el.className = "slot";
      el.style.setProperty("--c", color);
      el.innerHTML = `<i class="cd"></i><b>${key}</b><span>${name}</span><em></em><u></u>`;
      el.addEventListener("pointerdown", (ev) => { ev.preventDefault(); ev.stopPropagation(); act(); });
      hb.appendChild(el);
      slotEls.push(el);
      return el;
    };
    mk("Click", "Attack", "#e5e7eb", swing);
    D.ABILITIES.forEach((a, i) => mk(a.label, a.name, a.color, () => useAbility(i)));
    D.POTIONS.forEach((p, i) => mk(p.label, p.short, p.color, () => drinkPotion(i)));
    mk("I", "Items", "#facc15", () => togglePanel("inv"));
  }
  function updateHotbar() {
    const cds = [[swingCd, stats.swing], ...D.ABILITIES.map((a, i) => [abilityCd[i], a.cd]), [potionCd, 1], [potionCd, 1], [0, 1]];
    slotEls.forEach((el, i) => {
      const [t, T] = cds[i];
      const cd = el.firstChild;
      const h = t > 0 ? Math.min(100, (t / T) * 100) : 0;
      if (cd._h !== h) { cd._h = h; cd.style.height = h + "%"; }
      let em = "", u = "";
      if (i >= 1 && i <= 3) {
        const a = D.ABILITIES[i - 1];
        if (save.lv < a.level) em = "Lv " + a.level;
        else if (t > 0) em = Math.ceil(t) + "s";
      } else if (i === 4 || i === 5) {
        u = "x" + save.pots[i - 4];
        if (i === 5 && tonicT > 0) em = Math.ceil(tonicT) + "s";
      }
      const emEl = el.children[3], uEl = el.children[4];
      if (emEl.textContent !== em) emEl.textContent = em;
      if (uEl.textContent !== u) uEl.textContent = u;
      el.classList.toggle("locked", i >= 1 && i <= 3 && save.lv < D.ABILITIES[i - 1].level);
    });
  }

  // ---- floating numbers
  const floats = [];
  const fxLayer = $("fx");
  const scr = { x: 0, y: 0, vis: false };
  const fpos = new THREE.Vector3();
  function floatText(x, y, z, text, color, big) {
    let f = floats.find((o) => o.life <= 0);
    if (!f) {
      if (floats.length > 40) f = floats[0];
      else { f = { el: document.createElement("div") }; fxLayer.appendChild(f.el); floats.push(f); }
    }
    f.el.textContent = text;
    f.el.style.color = color;
    f.el.className = big ? "big" : "";
    f.x = x + (Math.random() - 0.5) * 1.2; f.y = y; f.z = z + (Math.random() - 0.5) * 1.2;
    f.life = 1;
    f.el.style.display = "block";
  }
  function stepFloats(dt) {
    for (const f of floats) {
      if (f.life <= 0) continue;
      f.life -= dt * 1.1;
      f.y += dt * 3;
      if (f.life <= 0) { f.el.style.display = "none"; continue; }
      fpos.set(f.x, f.y, f.z);
      M.projectToScreen(fpos, world.camera, scr);
      if (!scr.vis) { f.el.style.opacity = 0; continue; }
      f.el.style.opacity = Math.min(1, f.life * 2.5);
      f.el.style.transform = `translate(${scr.x.toFixed(1)}px, ${scr.y.toFixed(1)}px) translate(-50%, -50%)`;
    }
  }

  // ---- minimap
  const map = $("map"), mctx = map.getContext("2d");
  function drawMap() {
    if (!zone || zone.kind !== "dungeon") { map.hidden = true; return; }
    map.hidden = false;
    const W = map.width, H = map.height, b = zone.bounds;
    const s = Math.min((W - 16) / (b.x1 - b.x0), (H - 16) / (b.z1 - b.z0));
    const ox = (W - (b.x1 - b.x0) * s) / 2, oz = (H - (b.z1 - b.z0) * s) / 2;
    const X = (x) => ox + (x - b.x0) * s, Z = (z) => oz + (z - b.z0) * s;
    mctx.clearRect(0, 0, W, H);
    mctx.strokeStyle = "rgba(255,255,255,.35)";
    mctx.lineWidth = Math.max(2, 10 * s);
    mctx.beginPath();
    zone.plan.rooms.forEach((r, i) => { if (i === 0) mctx.moveTo(X(r.x), Z(r.z)); else mctx.lineTo(X(r.x), Z(r.z)); });
    mctx.stroke();
    for (const r of zone.plan.rooms) {
      const st = zone.state[r.i];
      mctx.fillStyle = r.kind === "boss" ? (zone.bossDead ? "#4c1d95" : "#7e22ce") : st === 2 ? "#3f6b48" : st === 1 ? "#b91c1c" : "#374151";
      mctx.fillRect(X(r.x - r.size / 2), Z(r.z - r.size / 2), r.size * s, r.size * s);
    }
    mctx.fillStyle = "#f87171";
    for (const e of enemies.values()) { mctx.fillRect(X(e.pos.x) - 1.5, Z(e.pos.z) - 1.5, 3, 3); }
    mctx.fillStyle = "#ffffff";
    if (online()) for (const pl of net.players.values()) { const st = pl.state; if (st && Array.isArray(st.p)) { mctx.beginPath(); mctx.arc(X(num(st.p[0])), Z(num(st.p[2])), 3, 0, 7); mctx.fill(); } }
    mctx.fillStyle = "#facc15";
    mctx.beginPath(); mctx.arc(X(me.pos.x), Z(me.pos.z), 4, 0, 7); mctx.fill();
  }

  // ---- leaderboard
  function updateBoard() {
    const rows = [{ name: me.name, values: [save.lv, save.gold], me: true }];
    if (online()) for (const pl of net.players.values()) { const s = pl.state || {}; rows.push({ name: pl.name, values: [num(s.lv, 1), num(s.g, 0)] }); }
    rows.sort((a, b) => b.values[0] - a.values[0] || b.values[1] - a.values[1]);
    Kit.leaderboard(["Level", "Gold"], rows);
  }

  // ---- remote players carry their weapons and swing them
  function decorateRemotes(dt) {
    if (!net) return;
    for (const [id, r] of world.remotes) {
      const m = r.model;
      const pl = net.players.get(id);
      const s = pl && pl.state;
      if (!m.userData.dq) {
        const base = m.userData.animate;
        const dq = { sw: s ? s.sw : 0, t: 1, wkey: "", weapon: null };
        m.userData.dq = dq;
        m.userData.animate = (dt2, sp, air) => { base(dt2, sp, air); poseArms(m, dq.t, 0, air); };
      }
      const dq = m.userData.dq;
      if (s) {
        if (s.sw !== dq.sw) {
          dq.sw = s.sw; dq.t = 0;
          if (zone && zone.kind === "dungeon" && m.visible) fx.burst(new THREE.Vector3(m.position.x - Math.sin(m.rotation.y) * 3, 3, m.position.z - Math.cos(m.rotation.y) * 3), "#ffffff", 2, 6, 0.3);
        }
        const kind = D.WEAPON_KINDS[s.wk] ? s.wk : "sword";
        const rar = clamp(Math.round(num(s.wr)), 0, 3);
        const wkey = kind + rar;
        if (wkey !== dq.wkey) {
          dq.wkey = wkey;
          const armR = m.userData.limbs.armR;
          if (dq.weapon) armR.remove(dq.weapon);
          dq.weapon = M.makeWeapon(kind, D.RARITIES[rar].color);
          dq.weapon.position.set(0, -1.95, -0.1);
          armR.add(dq.weapon);
        }
      }
      dq.t = Math.min(1, dq.t + dt / 0.22);
    }
  }

  // ---- panels
  const panel = $("panel");
  function closePanel() {
    panel.hidden = true;
    panelOpen = null;
    selected = null;
    confirmReset = false;
  }
  function togglePanel(kind) {
    if (titleOpen || busy) return;
    if (panelOpen === kind) closePanel(); else openPanel(kind);
  }
  function openPanel(kind, arg) {
    if (titleOpen || busy || !zone) return;
    if (panelOpen !== kind) { selected = null; confirmReset = false; }
    panelOpen = kind;
    panelArg = arg;
    renderPanel();
    panel.hidden = false;
  }

  const rarCol = (it) => D.RARITIES[it.rar].color;
  const itemName = (it) => esc(it.name) + (it.upg ? " +" + it.upg : "");
  function card(it, cls, label) {
    if (!it) return `<div class="card empty"><small>${label}</small><span>Nothing equipped</span></div>`;
    return `<div class="card ${cls || ""}" style="--rc:${rarCol(it)}" data-act="sel" data-id="${it.id}">${label ? `<small>${label}</small>` : ""}<b>${itemName(it)}</b><span>${D.itemStatLine(it)}</span><em>${D.RARITIES[it.rar].name} - tier ${it.tier}</em></div>`;
  }

  function compare(it) {
    const cur = save.eq[it.slot];
    const s0 = D.playerStats(save);
    const tmpSave = Object.assign({}, save, { eq: Object.assign({}, save.eq, { [it.slot]: it }) });
    const s1 = D.playerStats(tmpSave);
    const diff = (a, b, label) => { const d = b - a; return d ? `<span class="${d > 0 ? "up" : "down"}">${d > 0 ? "+" : ""}${d} ${label}</span>` : ""; };
    const parts = [diff(s0.atk, s1.atk, "attack"), diff(s0.hp, s1.hp, "health"), diff(s0.def, s1.def, "armor"), diff(s0.crit, s1.crit, "% crit")].filter(Boolean);
    void cur;
    return parts.length ? parts.join(" ") : `<span>Same stats as your current gear</span>`;
  }

  function renderPanel() {
    let h = "";
    const close = `<button class="x" data-act="close" title="Close">Close</button>`;
    if (panelOpen === "inv") {
      const s = stats;
      const sel = selected && save.inv.find((i) => i.id === selected);
      h = `<div class="ph"><h2>Inventory</h2>${close}</div>
      <div class="inv">
        <div class="col">
          <div class="stats">
            <div><small>Level</small><b>${save.lv}</b></div><div><small>Attack</small><b>${s.atk}</b></div>
            <div><small>Max health</small><b>${s.hp}</b></div><div><small>Armor</small><b>${s.def}</b></div>
            <div><small>Crit chance</small><b>${s.crit}%</b></div><div><small>Gold</small><b class="gold">${save.gold}</b></div>
          </div>
          ${card(save.eq.weapon, "eq", "Weapon")}
          ${card(save.eq.armor, "eq", "Armor")}
          <p class="muted">Potions: ${save.pots[0]} health, ${save.pots[1]} strength. Monsters defeated: ${save.kills}.</p>
        </div>
        <div class="col wide">
          <div class="grid">${save.inv.map((it) => `<div class="cell${it.id === selected ? " sel" : ""}" style="--rc:${rarCol(it)}" data-act="sel" data-id="${it.id}"><b>${itemName(it)}</b><span>${it.slot === "weapon" ? Math.round(it.dmg * (1 + 0.1 * it.upg)) + " dmg" : "+" + Math.round(it.hp * (1 + 0.1 * it.upg)) + " hp"}</span></div>`).join("")}
          ${Array.from({ length: Math.max(0, D.INV_SIZE - save.inv.length) }, () => `<div class="cell none"></div>`).join("")}</div>
          <div class="detail">${sel ? `<b style="color:${rarCol(sel)}">${itemName(sel)}</b> <em>${D.RARITIES[sel.rar].name} ${sel.slot}</em><div>${D.itemStatLine(sel)}</div><div class="cmp">${compare(sel)}</div>
            <div class="row"><button class="btn" data-act="equip" data-primary>Equip</button> <button class="btn red" data-act="sell">Sell for ${D.sellValue(sel)} gold</button></div>` : `<span class="muted">${save.inv.length}/${D.INV_SIZE} items. Click an item to compare, equip or sell it.</span>`}</div>
          <div class="foot"><button class="btn small" data-act="sellcommon">Sell all common items</button>
          ${confirmReset ? `<span class="warn">Erase all progress?</span> <button class="btn small red" data-act="reset2">Yes, start over</button> <button class="btn small" data-act="reset0">No</button>` : `<button class="btn small ghost" data-act="reset1">Start over</button>`}</div>
        </div>
      </div>`;
    } else if (panelOpen === "smith") {
      const row = (it, label) => {
        if (!it) return "";
        const max = it.upg >= D.MAX_UPGRADE;
        const cost = D.upgradeCost(it);
        const next = Object.assign({}, it, { upg: it.upg + 1 });
        return `<div class="shoprow"><div>${card(it, "eq", label)}</div><div class="buy">${max ? `<b>Fully upgraded!</b>` : `<small>Next: ${D.itemStatLine(next)}</small><button class="btn" data-act="upg" data-slot="${it.slot}" ${save.gold < cost ? "disabled" : ""}>Upgrade for ${cost} gold</button>`}</div></div>`;
      };
      h = `<div class="ph"><h2>Blacksmith</h2>${close}</div>
      <p class="muted">"Bring me gold and I'll hammer your gear into shape! Each upgrade adds 10% to an item's stats, up to +${D.MAX_UPGRADE}." You have <b class="gold">${save.gold} gold</b>.</p>
      ${row(save.eq.weapon, "Weapon")}${row(save.eq.armor, "Armor")}
      <p class="muted">Upgrade the gear you have equipped. Swap gear in your inventory (I).</p>`;
    } else if (panelOpen === "shop") {
      h = `<div class="ph"><h2>Potion Shop</h2>${close}</div>
      <p class="muted">"Fresh potions, brewed today!" You have <b class="gold">${save.gold} gold</b>.</p>
      ${D.POTIONS.map((p, i) => `<div class="shoprow"><div class="card" style="--rc:${p.color}"><b>${p.name}</b><span>${p.desc}</span><em>Key ${p.label} - you have ${save.pots[i]}</em></div>
        <div class="buy"><button class="btn" data-act="buy" data-i="${i}" data-n="1" ${save.gold < p.price || save.pots[i] >= 20 ? "disabled" : ""}>Buy 1 for ${p.price} gold</button>
        <button class="btn" data-act="buy" data-i="${i}" data-n="5" ${save.gold < p.price * 5 || save.pots[i] > 15 ? "disabled" : ""}>Buy 5 for ${p.price * 5} gold</button></div></div>`).join("")}
      <p class="muted">You can carry up to 20 of each.</p>`;
    } else if (panelOpen === "portal") {
      const d = D.DUNGEONS[panelArg];
      const locked = panelArg > 0 && !save.cleared[D.DUNGEONS[panelArg - 1].id];
      h = `<div class="ph"><h2 style="color:${d.torch}">${d.name}</h2>${close}</div>
      <p>${d.blurb}</p>
      <p>Recommended level <b>${d.rec}+</b> - you are level <b>${save.lv}</b>. Boss: <b>${D.ENEMIES[d.boss].name}</b>.${save.cleared[d.id] ? " <span class='up'>Cleared before!</span>" : ""}</p>
      ${locked ? `<p class="warn">Locked. Defeat ${D.ENEMIES[D.DUNGEONS[panelArg - 1].boss].name.replace(/^The /, "the ")} in the ${D.DUNGEONS[panelArg - 1].name} first.</p><button class="btn" data-act="close" data-primary>OK</button>`
        : `<p class="muted">Room code: <b>${d.id}</b>. When you play online, everyone who enters this dungeon joins the same party.</p>
      <button class="btn big" data-act="enter" data-primary>Enter dungeon</button> <button class="btn ghost" data-act="close">Not yet</button>`}`;
    } else if (panelOpen === "leave") {
      h = `<div class="ph"><h2>Leave the dungeon?</h2>${close}</div>
      <p>You keep all your XP, gold and loot. The dungeon will be different next time.</p>
      <button class="btn big" data-act="leave" data-primary>Return to town</button> <button class="btn ghost" data-act="close">Stay</button>`;
    }
    panel.innerHTML = h;
  }

  panel.addEventListener("click", (ev) => {
    const t = ev.target.closest("[data-act]");
    if (!t || t.disabled) return;
    const act = t.dataset.act;
    Kit.sfx("click");
    if (act === "close") return closePanel();
    if (act === "sel") { selected = t.dataset.id; if (save.eq.weapon && save.eq.weapon.id === selected || save.eq.armor && save.eq.armor.id === selected) selected = null; }
    if (act === "equip") {
      const it = save.inv.find((i) => i.id === selected);
      if (it) {
        save.inv.splice(save.inv.indexOf(it), 1);
        if (save.eq[it.slot]) save.inv.push(save.eq[it.slot]);
        save.eq[it.slot] = it;
        selected = null;
        refreshStats();
        refreshWeapon();
        markDirty();
      }
    }
    if (act === "sell") {
      const it = save.inv.find((i) => i.id === selected);
      if (it) { save.inv.splice(save.inv.indexOf(it), 1); addGold(D.sellValue(it)); selected = null; }
    }
    if (act === "sellcommon") {
      const commons = save.inv.filter((i) => i.rar === 0);
      if (commons.length) {
        const g = commons.reduce((s, i) => s + D.sellValue(i), 0);
        save.inv = save.inv.filter((i) => i.rar !== 0);
        addGold(g);
        toast("Sold " + commons.length + " items", "+" + g + " gold", "#facc15");
      }
    }
    if (act === "upg") {
      const it = save.eq[t.dataset.slot];
      const cost = it && D.upgradeCost(it);
      if (it && save.gold >= cost && it.upg < D.MAX_UPGRADE) {
        save.gold -= cost;
        it.upg++;
        refreshStats();
        Kit.sfx("score");
        fx.burst(new THREE.Vector3(-35, 3, -4), "#f97316", 12, 10, 0.4);
        toast("Upgraded!", it.name + " is now +" + it.upg, "#f97316");
        if (it.upg >= 5) badge("smith");
        markDirty();
      }
    }
    if (act === "buy") {
      const i = +t.dataset.i, n = +t.dataset.n, p = D.POTIONS[i];
      if (save.gold >= p.price * n && save.pots[i] + n <= 20) { save.gold -= p.price * n; save.pots[i] += n; Kit.sfx("coin"); markDirty(); }
    }
    if (act === "enter") { const i = panelArg; closePanel(); enterDungeon(i); return; }
    if (act === "leave") { closePanel(); enterTown(true); return; }
    if (act === "reset1") confirmReset = true;
    if (act === "reset0") confirmReset = false;
    if (act === "reset2") { resetSave(); return; }
    if (panelOpen) renderPanel();
    updateHud();
  });

  function resetSave() {
    save = freshSave();
    persist();
    refreshStats();
    me.health = me.maxHealth;
    refreshWeapon();
    closePanel();
    toast("Fresh start", "Your adventure begins again!", "#22c55e");
    enterTown(false);
  }

  // ================================================================ title screen

  function showTitle() {
    const t = $("title");
    const has = save.kills > 0 || save.lv > 1;
    t.querySelector(".save").innerHTML = has
      ? `Your hero: <b>level ${save.lv}</b>, <b class="gold">${save.gold} gold</b>, ${Object.keys(save.cleared).length}/3 dungeons cleared`
      : "A new hero is ready for adventure!";
    t.querySelector("[data-act=play]").textContent = has ? "Continue" : "Play";
    t.querySelector("[data-act=newgame]").hidden = !has;
    t.hidden = false;
  }
  $("title").addEventListener("click", (ev) => {
    const b = ev.target.closest("[data-act]");
    if (!b) return;
    if (b.dataset.act === "play") startGame();
    if (b.dataset.act === "newgame") {
      if (b.dataset.sure) { save = freshSave(); persist(); refreshStats(); refreshWeapon(); startGame(); }
      else { b.dataset.sure = "1"; b.textContent = "Really erase your hero? Click again"; }
    }
  });
  function startGame() {
    if (!titleOpen) return;
    titleOpen = false;
    $("title").hidden = true;
    Kit.sfx("click");
    refreshStats();
    me.health = me.maxHealth;
    enterTown(false);
  }

  // ================================================================ input

  world.renderer.domElement.addEventListener("pointerdown", (e) => {
    if (e.button === 0) { mouseHeld = true; swing(); }
  });
  addEventListener("pointerup", (e) => { if (e.button === 0) mouseHeld = false; });
  addEventListener("blur", () => { mouseHeld = false; });

  // The BlockOS menu (Escape) takes focus away from the game: solo play pauses until you come back.
  let paused = false;
  addEventListener("blur", () => { paused = true; mouseHeld = false; });
  addEventListener("focus", () => { paused = false; });
  addEventListener("pointerdown", () => { paused = false; }, true);
  addEventListener("keydown", () => { paused = false; }, true);

  let camDistPrev = world.cam.dist;
  Kit.onKey((code, e) => {
    if (code === "KeyI") world.cam.dist = camDistPrev;    // the kit zooms on I; here I opens the inventory
    if (code === "Tab") e.preventDefault();
    if (titleOpen) { if (code === "Enter" || code === "Space") startGame(); return; }
    if (code === "Enter" && panelOpen) { const p = panel.querySelector("[data-primary]"); if (p && !p.disabled) p.click(); return; }
    if (code === "KeyI" || code === "Tab") { togglePanel("inv"); return; }
    if (panelOpen) return;
    if (code === "KeyF") swing();
    else if (code === "KeyQ") useAbility(0);
    else if (code === "KeyE") useAbility(1);
    else if (code === "KeyR") useAbility(2);
    else if (code === "Digit1") drinkPotion(0);
    else if (code === "Digit2") drinkPotion(1);
  });

  world.onDeath(() => {
    banner("You were defeated!", zone && zone.kind === "dungeon" ? "Back on your feet in a moment..." : "");
    push.set(0, 0, 0);
    dashT = 0;
  });
  world.onRespawn(() => {
    invulnT = 2;
    refreshStats();
    me.health = me.maxHealth;
    world.updateHealthBar();
  });

  // ================================================================ main loop

  let slowT = 0, boardT = 0, cullT = 0, regenAcc = 0;
  world.start((dt) => {
    camDistPrev = world.cam.dist;
    const hold = paused && !online();
    me.frozen = titleOpen || busy || !!panelOpen || dashT > 0 || hold;
    bannerT -= dt;
    if (!zone || busy || hold) { stepFloats(dt); return; }
    const host = isHost();
    if (zone.kind === "dungeon" && host && !wasHost) becomeHost();
    wasHost = host;

    swingCd = Math.max(0, swingCd - dt);
    lastHurtT += dt; lastHitT += dt;
    // slowly heal when out of danger
    if (me.alive && lastHurtT > 5 && me.health < me.maxHealth) { regenAcc += me.maxHealth * (zone.kind === "town" ? 0.2 : 0.02) * dt; if (regenAcc >= 1) { const n = Math.floor(regenAcc); regenAcc -= n; world.heal(n); } }
    invulnT = Math.max(0, invulnT - dt);
    tonicT = Math.max(0, tonicT - dt);
    potionCd = Math.max(0, potionCd - dt);
    for (let i = 0; i < 3; i++) abilityCd[i] = Math.max(0, abilityCd[i] - dt);
    if (swingT < 1) swingT = Math.min(1, swingT + dt / 0.22);
    if (spinT > 0) spinT = Math.max(0, spinT - dt / 0.45);
    if ((mouseHeld || Kit.key("KeyF")) && swingCd <= 0 && !panelOpen) swing();

    // dash strike and knockback move you with collisions
    if (dashT > 0 && me.alive) {
      dashT -= dt;
      const d = 75 * dt;
      moveMe(dashDir.x * d, dashDir.z * d);
      for (const e of enemies.values()) {
        if (!e.alive || dashHit.has(e.id) || e.spawnT > 0) continue;
        if (Math.hypot(e.pos.x - me.pos.x, e.pos.z - me.pos.z) < 3.4 + e.st.radius) { dashHit.add(e.id); hitEnemy(e, 2.2, dashDir.x, dashDir.z, 16); }
      }
      if (Math.random() < 0.6) fx.burst(new THREE.Vector3(me.pos.x, 2, me.pos.z), "#38bdf8", 1, 3, 0.4);
    }
    if (push.lengthSq() > 0.01 && me.alive) {
      moveMe(push.x * dt, push.z * dt);
      push.multiplyScalar(Math.max(0, 1 - dt * 6));
    } else push.set(0, 0, 0);

    if (zone.kind === "dungeon") {
      if (host) hostStep(dt);
      stepEnemies(dt, host);
      stepStrikes(dt);
      stepShots(dt);
      stepDrops(dt);
      stepChests(dt);
      // hazard pools
      hazardT -= dt;
      for (const hz of zone.hazards) {
        if (me.alive && me.pos.y < 1 && Math.abs(me.pos.x - hz.x) < hz.h && Math.abs(me.pos.z - hz.z) < hz.h && hazardT <= 0) {
          hazardT = 0.5;
          const n = Math.max(1, Math.round(stats.hp * 0.04));
          world.damage(n);
          floatText(me.pos.x, me.pos.y + 6, me.pos.z, "-" + n, "#a3e635");
        }
      }
      if (!online()) pendingHits = [];
      cullT -= dt;
      if (cullT <= 0) { cullT = 0.25; zone.cull(me.pos.x, me.pos.z, 120); }
      zone.hideNear(world.camera.position);
      // boss bar visibility
      const boss = [...enemies.values()].find((e) => e.role === "boss");
      if (!boss && !$("boss").hidden) { $("boss").hidden = true; bossShown = null; }
    }
    flush(dt);
    fx.update(dt);
    stepFloats(dt);
    decorateRemotes(dt);
    updateHotbar();
    updateHud();
    slowT -= dt;
    if (slowT <= 0) { slowT = 0.1; drawMap(); }
    boardT -= dt;
    if (boardT <= 0) { boardT = 1; updateBoard(); }
  });

  // ================================================================ start

  buildHotbar();
  // a quiet town backdrop behind the title screen
  setLighting("town");
  showTitle();
  (async () => {
    zone = new Zone(world, "town");
    const t = buildTown(zone, { dungeons: D.DUNGEONS, unlocked: (i) => i === 0 || !!save.cleared[D.DUNGEONS[i - 1].id], onSmith() {}, onShop() {}, onPortal() {} });
    placeMe(t.spawn, t.yaw);
    world.cam.yaw = 0.5;
    updateHud(true);
    setObjective("");
  })();

  // ================================================================ test hooks

  window.game = {
    get save() { return save; },
    get zone() { return zone; },
    get stats() { return stats; },
    get net() { return net; },
    enemies, shots, drops, chests,
    me,
    enterDungeon, enterTown, openPanel, closePanel, swing, useAbility, drinkPotion, startGame,
    teleport(x, z, y) { me.pos.set(x, y === undefined ? 1 : y, z); me.vel.set(0, 0, 0); },
    gotoRoom(i, dx, dz) { const r = zone.plan.rooms[i]; me.pos.set(r.x + (dx || 0), 1, r.z + (dz || 0)); me.vel.set(0, 0, 0); },
    spawn(type, x, z, room) { const r = room === undefined ? Math.max(0, roomOf(x, z)) : room; return createEnemy(nextId++, type, r, x, z); },
    killAll(room) { for (const e of [...enemies.values()]) if (room === undefined || e.room === room) applyHit(e, 1e9, 0, 0); },
    killBoss() { for (const e of [...enemies.values()]) if (e.role === "boss") applyHit(e, 1e9, 0, 0); },
    hurtBoss(f) { for (const e of enemies.values()) if (e.role === "boss") applyHit(e, e.maxHp * f, 0, 0); },
    clearRoom(i) { const r = zone.plan.rooms[i]; for (const e of [...enemies.values()]) if (e.room === i) applyHit(e, 1e9, 0, 0); zone.wave[i] = r.waves.length; if (zone.state[i] !== 2) clearRoom(r); },
    giveXp: gainXp,
    giveGold(n) { addGold(n); updateHud(true); },
    giveItem(slot, tier, rar) { return addItem(D.makeItem(slot, tier || 1, rar || 0)); },
    drop(slot, tier, rar) { spawnDrop(me.pos.x + 6, me.pos.z, D.makeItem(slot, tier || 1, rar || 0)); },
    isHost,
    persist,
    roomOf,
    info() {
      return { zone: zone && zone.kind, dungeon: zone && zone.def && zone.def.id, lv: save.lv, xp: save.xp, gold: save.gold, hp: me.health, maxHp: me.maxHealth, alive: me.alive, pos: [r1(me.pos.x), r1(me.pos.y), r1(me.pos.z)], enemies: [...enemies.values()].map((e) => [e.id, e.type, r1(e.pos.x), r1(e.pos.z), Math.ceil(e.hp), e.room]), rooms: zone && zone.state, host: isHost(), online: online(), others: othersHere(), inv: save.inv.length, shots: shots.length, panel: panelOpen, bossDead: zone && zone.bossDead };
    },
  };
}
