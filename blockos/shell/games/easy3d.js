/*
 * Easy 3D: the simplest way to make a 3D game in BlockOS. Give each part a name, then give it
 * powers with one-line commands:
 *
 *   <script src="kit.js"></script>
 *   <script type="module">
 *   import "./easy3d.js";
 *
 *   part("lava block", 0, 1, -12);
 *   color("lava block", "red");
 *   killOnTouch("lava block");
 *   </script>
 *
 * The game starts by itself when your code is done. Names can be anything ("part 1", "Big Wall").
 * A group name works too: killOnTouch("stairs") changes "stairs 1", "stairs 2"...
 * Command names work in any capitals: killOnTouch, killontouch and KILLONTOUCH are the same.
 * Positions: x = left/right, y = up, z = forward (more negative = further ahead).
 * The full list of commands, with examples, is in the Create studio's Help guide (Easy 3D).
 */
import { World } from "./kit3d.js";

const COLOR_NAMES = {
  red: "#ef4444", orange: "#f97316", yellow: "#facc15", gold: "#eab308", lime: "#84cc16", green: "#22c55e",
  darkgreen: "#15803d", teal: "#14b8a6", cyan: "#06b6d4", lightblue: "#7dd3fc", sky: "#8fd3ff", blue: "#3b82f6",
  darkblue: "#1e3a8a", purple: "#a855f7", pink: "#ec4899", brown: "#92400e", white: "#f8fafc", gray: "#94a3b8",
  grey: "#94a3b8", darkgray: "#475569", black: "#111827", lava: "#f97316", sand: "#e7c98a",
};
const colorOf = (c) => COLOR_NAMES[String(c).toLowerCase().replace(/\s+/g, "")] || String(c);
const RAINBOW = ["#ef4444", "#f97316", "#facc15", "#22c55e", "#3b82f6", "#a855f7", "#ec4899"];
const SOUNDS = ["click", "score", "hit", "jump", "lose", "win", "coin"];
const GRAVITY = 196.2, WALK = 16, JUMP = 52;

// The game's name, for badges, best times and online play: made from the page's <title>.
const GAME_ID = ((document.title || "easy-3d").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 20)) || "easy-3d";

const world = new World({ sky: "#8fd3ff" });
const specs = new Map();          // name (lower case) -> what you asked for
const meshes = new Map();         // name (lower case) -> the 3D block, once the game starts
const npcs = new Map();           // name (lower case) -> character model
const signs = [];
const repeaters = [];             // forever / every / wait
const winFns = [], deathFns = [];
const dirty = new Set();          // parts to rebuild next frame
let started = false, won = false, over = false;
let spawnAt = [0, 0, 0];
let unnamed = 0, clock = 0, time = 0, deaths = 0;
let coinsTotal = 0, coinsGot = 0, points = 0, usePoints = false, pointsToWin = 0;
let timeLimit = 0;
const game = { speed: WALK, jump: JUMP, gravity: 1, fly: false, doubleJump: false, airJumped: false };

const key = (name) => String(name).trim().toLowerCase();
const num = (v, d) => (v === undefined || v === null || v === "" || isNaN(Number(v)) ? d : Number(v));
function problem(text) { console.error(text); }

// The parts a name means: the part with that name, or else every part in that group
// ("stairs" -> "stairs 1", "stairs 2"...). Explains in the Output panel if there are none.
function find(name, command) {
  const k = key(name);
  if (specs.has(k)) return [specs.get(k)];
  const group = [...specs.values()].filter((s) => key(s.name).startsWith(k + " "));
  if (!group.length) problem(`${command}("${name}"): there's no part called "${name}". Make it first with part("${name}", x, y, z).`);
  return group;
}
// Change some parts; once the game has started they're rebuilt in the next frame.
function change(name, command, fn) {
  for (const s of find(name, command)) { fn(s); if (started) dirty.add(key(s.name)); }
}
// Give some parts a power that works when you touch them.
function power(name, command, p) { change(name, command, (s) => s.powers.push(p)); }

// ================================================================= building

function part(name, x, y, z, width, height, depth) {
  if (typeof name !== "string") return problem('part needs a name first, like part("part 1", 0, 2, -10).');
  const s = {
    name, pos: [num(x, 0), num(y, 0), num(z, 0)], size: [num(width, 6), num(height, 1), num(depth, 6)],
    color: "#a3a2a5", material: "plastic", studs: true, collide: true, kill: false, rot: 0,
    opacity: 1, invisible: false, rainbow: false, blink: 0, hidden: false,
    powers: [], motions: [], spin: 0, circle: null, follow: 0, conveyor: 0, label: null,
    rt: {},
  };
  specs.set(key(name), s);
  if (started) build(s);
  return name;
}

function copy(from, newName, x, y, z) {
  const src = find(from, "copy")[0];
  if (!src) return;
  if (typeof newName !== "string") return problem(`copy("${from}", ...) needs a new name, like copy("${from}", "${from} copy", 0, 0, -10).`);
  const s = Object.assign({}, src, {
    name: newName, pos: [num(x, src.pos[0]), num(y, src.pos[1]), num(z, src.pos[2])], size: src.size.slice(),
    powers: src.powers.slice(), motions: src.motions.map((m) => Object.assign({}, m)),
    circle: src.circle && Object.assign({}, src.circle), rt: {},
  });
  specs.set(key(newName), s);
  if (started) build(s);
  return newName;
}

function remove(name) {
  for (const s of find(name, "remove")) {
    const k = key(s.name);
    if (meshes.has(k)) world.remove(meshes.get(k));
    if (npcs.has(k)) world.scene.remove(npcs.get(k));
    meshes.delete(k); npcs.delete(k); specs.delete(k);
  }
}

const floor = (name, x, y, z, width, depth) => part(name, x, y, z, num(width, 20), 1, num(depth, 20));
const wall = (name, x, y, z, width, height) => part(name, x, num(y, 0) + num(height, 8) / 2, z, num(width, 12), num(height, 8), 1);
const tower = (name, x, y, z, height) => part(name, x, num(y, 0) + num(height, 20) / 2, z, 6, num(height, 20), 6);

function stairs(name, x, y, z, steps) {
  const n = Math.max(1, Math.min(100, Math.round(num(steps, 8))));
  for (let i = 1; i <= n; i++) part(`${name} ${i}`, num(x, 0), num(y, 0) + i, num(z, 0) - i * 2, 6, 1, 2);
  return name;
}
function row(name, x, y, z, count, gap) {
  const n = Math.max(1, Math.min(100, Math.round(num(count, 5))));
  for (let i = 1; i <= n; i++) part(`${name} ${i}`, num(x, 0), num(y, 0), num(z, 0) - (i - 1) * num(gap, 9), 5, 1, 5);
  return name;
}
function tree(x, y, z) {
  const n = "tree " + ++unnamed;
  part(n + " trunk", x, num(y, 0) + 3, z, 1.5, 6, 1.5);
  color(n + " trunk", "brown"); wood(n + " trunk");
  part(n + " leaves", x, num(y, 0) + 8, z, 6, 5, 6);
  color(n + " leaves", "darkgreen"); smooth(n + " leaves");
  return n;
}
function cloud(x, y, z) {
  const n = "cloud " + ++unnamed;
  const at = [num(x, 0), num(y, 30), num(z, 0)];
  [[0, 0, 0, 10, 3, 6], [-5, -0.5, 1, 6, 2.5, 5], [5, -0.5, -1, 7, 2.5, 5], [1, 1.5, 0, 6, 2, 4]].forEach((c, i) => {
    part(`${n} ${i + 1}`, at[0] + c[0], at[1] + c[1], at[2] + c[2], c[3], c[4], c[5]);
  });
  color(n, "white"); smooth(n); ghost(n);
  return n;
}
function house(name, x, y, z) {
  const [hx, hy, hz] = [num(x, 0), num(y, 0), num(z, 0)];
  part(`${name} floor`, hx, hy - 0.5, hz, 14, 1, 14);
  part(`${name} back`, hx, hy + 4, hz - 6.5, 14, 8, 1);
  part(`${name} left`, hx - 6.5, hy + 4, hz, 1, 8, 12);
  part(`${name} right`, hx + 6.5, hy + 4, hz, 1, 8, 12);
  part(`${name} front left`, hx - 4.5, hy + 4, hz + 6.5, 5, 8, 1);
  part(`${name} front right`, hx + 4.5, hy + 4, hz + 6.5, 5, 8, 1);
  part(`${name} roof`, hx, hy + 8.5, hz, 16, 1, 16);
  color(name, "sand"); color(`${name} roof`, "red"); color(`${name} floor`, "brown"); wood(`${name} floor`);
  return name;
}
function baseplate(c) {
  part("baseplate", 0, -1, 0, 256, 2, 256);
  color("baseplate", c || "#4b9b3f");
  return "baseplate";
}
// A huge sheet of lava far below: fall off and you go back to your checkpoint.
function lava(y) {
  part("lava", 0, num(y, -14), -100, 600, 1, 800);
  color("lava", "lava"); glow("lava"); smooth("lava"); killOnTouch("lava");
  return "lava";
}
function sign(text, x, y, z) {
  const sp = { text: String(text), pos: [num(x, 0), num(y, 0), num(z, 0)] };
  signs.push(sp);
  if (started) sp.sprite = world.label(sp.text, { pos: sp.pos, height: 2.5 });
}
function npc(name, x, y, z) {
  part(name, x, num(y, 0) + 2.6, z, 3, 5.2, 3);
  change(name, "npc", (s) => { s.npc = true; s.collide = false; });
  return name;
}

// ================================================================= looks

function color(name, c) {
  for (const s of find(name, "color")) {
    s.color = colorOf(c);
    const m = meshes.get(key(s.name));
    if (m) paint(m, s.color);
  }
}
function paint(m, col) {
  // Its own paint, so other parts with the same color don't change too.
  if (!m.userData.ownPaint) { m.material = m.material.map((x) => x.clone()); m.userData.ownPaint = true; }
  m.material.forEach((x) => x.color.set(col));
}
const randomColor = (name) => { for (const s of find(name, "randomColor")) color(s.name, RAINBOW[Math.floor(Math.random() * RAINBOW.length)]); };
const size = (name, w, h, d) => change(name, "size", (s) => { s.size = [num(w, s.size[0]), num(h, s.size[1]), num(d, s.size[2])]; });
const scale = (name, n) => change(name, "scale", (s) => { s.size = s.size.map((v) => v * num(n, 1)); });
const glow = (name) => change(name, "glow", (s) => { s.material = "neon"; });
const glass = (name) => change(name, "glass", (s) => { s.material = "glass"; });
const wood = (name) => change(name, "wood", (s) => { s.material = "wood"; });
const smooth = (name) => change(name, "smooth", (s) => { s.studs = false; });
const ghost = (name) => change(name, "ghost", (s) => { s.collide = false; });
const solid = (name) => change(name, "solid", (s) => { s.collide = true; });
const rotate = (name, degrees) => change(name, "rotate", (s) => { s.rot = num(degrees, 45); });
const transparent = (name, amount) => change(name, "transparent", (s) => { s.opacity = 1 - Math.max(0, Math.min(1, num(amount, 0.5))); });
const invisible = (name) => change(name, "invisible", (s) => { s.invisible = true; });
const rainbow = (name) => change(name, "rainbow", (s) => { s.rainbow = true; });
const blink = (name, seconds) => change(name, "blink", (s) => { s.blink = Math.max(0.2, num(seconds, 1)); });
const label = (name, text) => change(name, "label", (s) => { s.label = String(text); });

function moveTo(name, x, y, z) {
  for (const s of find(name, "moveTo")) {
    s.pos = [num(x, s.pos[0]), num(y, s.pos[1]), num(z, s.pos[2])];
    s.rt.slide = null;
  }
}

// ================================================================= movement

function addMotion(command, axis, name, distance, speed) {
  change(name, command, (s) => s.motions.push({ axis, distance: num(distance, 8), speed: num(speed, 1) }));
}
const moveSideToSide = (name, distance, speed) => addMotion("moveSideToSide", 0, name, distance, speed);
const moveUpAndDown = (name, distance, speed) => addMotion("moveUpAndDown", 1, name, distance, speed);
const moveForwardAndBack = (name, distance, speed) => addMotion("moveForwardAndBack", 2, name, distance, speed);
const moveInCircle = (name, radius, speed) => change(name, "moveInCircle", (s) => { s.circle = { r: num(radius, 6), speed: num(speed, 1) }; });
const spin = (name, speed) => change(name, "spin", (s) => { s.spin = num(speed, 1); s.collide = false; });
const follow = (name, speed) => change(name, "follow", (s) => { s.follow = num(speed, 6); });
const conveyor = (name, speed) => change(name, "conveyor", (s) => { s.conveyor = num(speed, 10); });
const fallOnTouch = (name) => power(name, "fallOnTouch", { type: "fall" });
function stopMoving(name) {
  for (const s of find(name, "stopMoving")) {
    const m = meshes.get(key(s.name));
    if (m) s.pos = [m.position.x, m.position.y, m.position.z];
    s.motions = []; s.spin = 0; s.circle = null; s.follow = 0; s.rt.slide = null; s.rt.followAt = null;
  }
}
function slideTo(name, x, y, z, seconds) {
  for (const s of find(name, "slideTo")) {
    const m = meshes.get(key(s.name));
    const from = m ? [m.position.x, m.position.y, m.position.z] : s.pos.slice();
    s.rt.slide = { from, to: [num(x, from[0]), num(y, from[1]), num(z, from[2])], t: 0, dur: Math.max(0.1, num(seconds, 2)) };
  }
}

// ================================================================= touch powers

const killOnTouch = (name) => change(name, "killOnTouch", (s) => { s.kill = true; });
function onTouch(name, fn) {
  if (typeof fn !== "function") return problem(`onTouch("${name}", ...) needs a function, like onTouch("${name}", function () { message("Hi!"); });`);
  power(name, "onTouch", { type: "custom", fn });
}
const checkpoint = (name) => power(name, "checkpoint", { type: "checkpoint" });
const finish = (name) => power(name, "finish", { type: "finish" });
const bounce = (name, p) => power(name, "bounce", { type: "bounce", power: num(p, 100) });
const disappearOnTouch = (name) => power(name, "disappearOnTouch", { type: "disappear" });
function teleport(name, x, y, z) {
  power(name, "teleport", typeof x === "string" ? { type: "teleport", target: x } : { type: "teleport", to: [num(x, 0), num(y, 0), num(z, 0)] });
}
const speedBoost = (name, speed, seconds) => power(name, "speedBoost", { type: "speed", speed: num(speed, 40), seconds: num(seconds, 3) });
const superJump = (name, p, seconds) => power(name, "superJump", { type: "superjump", jump: num(p, 90), seconds: num(seconds, 5) });
const damage = (name, amount) => { healthOn(); power(name, "damage", { type: "damage", amount: num(amount, 25) }); };
const heal = (name, amount) => { healthOn(); power(name, "heal", { type: "heal", amount: num(amount, 50) }); };
const pointsOnTouch = (name, n) => { usePoints = true; power(name, "pointsOnTouch", { type: "points", n: num(n, 1) }); };
const messageOnTouch = (name, text) => power(name, "messageOnTouch", { type: "message", text: String(text) });
function soundOnTouch(name, sound) {
  if (!SOUNDS.includes(sound)) return problem(`soundOnTouch: sounds are ${SOUNDS.map((x) => `"${x}"`).join(", ")}.`);
  power(name, "soundOnTouch", { type: "sound", sound });
}
const badgeOnTouch = (name, badgeName) => power(name, "badgeOnTouch", { type: "badge", badge: String(badgeName || "Explorer") });
const keyFor = (keyName, door) => power(keyName, "keyFor", { type: "key", door });
const toggle = (button, target) => power(button, "toggle", { type: "toggle", target });
const talk = (name, text) => power(name, "talk", { type: "talk", text: String(text) });
const coinDoor = (door, coins) => change(door, "coinDoor", (s) => { s.coinDoor = Math.max(1, num(coins, 1)); });

function coin(a, y, z) {
  let name = a;
  if (typeof a !== "string") {
    name = "coin " + ++unnamed;
    part(name, a, y, z, 1.6, 1.6, 0.5);
    color(name, "gold"); glow(name); smooth(name); spin(name, 2);
  }
  change(name, "coin", (s) => { s.collide = false; s.powers.push({ type: "coin" }); coinsTotal++; });
  return name;
}

// What happens when you touch a part with powers.
function touched(s, p) {
  const k = key(s.name);
  const pl = world.player;
  switch (p.type) {
    case "custom": try { p.fn(); } catch (e) { problem(`Something went wrong in onTouch("${s.name}"): ${e.message}`); } break;
    case "checkpoint": {
      if (s.rt.reached) break;
      s.rt.reached = true;
      const m = meshes.get(k);
      world.checkpoint([m.position.x, m.position.y + s.size[1] / 2 + 0.5, m.position.z]);
      paint(m, "#22c55e");
      Kit.sfx("score");
      Kit.toast("Checkpoint!", "You'll come back here if you fall.", "#22c55e");
      break;
    }
    case "finish": win(); break;
    case "fall": if (!s.rt.falling) s.rt.falling = { t: 0, v: 0, y: 0 }; break;
    case "bounce": pl.vel.y = p.power; Kit.sfx("jump"); break;
    case "disappear":
      if (s.rt.fading) break;
      s.rt.fading = true;
      later(0.6, () => hide(s.name));
      later(3.6, () => { show(s.name); s.rt.fading = false; });
      break;
    case "coin":
      if (s.rt.hidden) break;
      hide(s.name);
      coinsGot++;
      Kit.sfx("coin");
      if (coinsGot === coinsTotal) Kit.badge(GAME_ID, "all-coins", "Coin Collector", "Collected every coin.");
      break;
    case "teleport": {
      let to = p.to;
      if (p.target) {
        const t = specs.get(key(p.target));
        if (!t) { problem(`teleport: there's no part called "${p.target}".`); break; }
        const m = meshes.get(key(t.name));
        to = [m.position.x, m.position.y + t.size[1] / 2 + 0.5, m.position.z];
      }
      pl.pos.set(to[0], to[1], to[2]); pl.vel.set(0, 0, 0);
      Kit.sfx("click");
      break;
    }
    case "speed": pl.speed = p.speed; Kit.sfx("score"); later(p.seconds, () => { pl.speed = game.speed; }); break;
    case "superjump": pl.jump = p.jump; Kit.sfx("score"); later(p.seconds, () => { pl.jump = game.jump; }); break;
    case "damage": world.damage(p.amount); Kit.sfx("hit"); break;
    case "heal": world.heal(p.amount); Kit.sfx("coin"); break;
    case "points": if (!s.rt.scored) { s.rt.scored = true; addPoints(p.n); } break;
    case "message": message(p.text); break;
    case "sound": Kit.sfx(p.sound); break;
    case "badge": Kit.badge(GAME_ID, p.badge.toLowerCase().replace(/[^a-z0-9]+/g, "-").slice(0, 30), p.badge, "Found in " + document.title); break;
    case "key":
      if (s.rt.hidden) break;
      hide(s.name);
      for (const d of find(p.door, "keyFor")) hide(d.name);
      Kit.sfx("win");
      message("You unlocked " + p.door + "!");
      break;
    case "toggle":
      for (const t of find(p.target, "toggle")) (t.rt.hidden ? show : hide)(t.name);
      Kit.sfx("click");
      break;
    case "talk": {
      const model = npcs.get(k);
      if (model) world.bubble(model, p.text);
      break;
    }
  }
}

// ================================================================= showing and hiding

function hide(name) {
  for (const s of find(name, "hide")) {
    s.rt.hidden = true;
    const m = meshes.get(key(s.name));
    if (!m) { s.hidden = true; continue; }
    m.visible = false;
    const i = world.solids.indexOf(m);
    if (i >= 0) world.solids.splice(i, 1);
    const model = npcs.get(key(s.name));
    if (model) model.visible = false;
  }
}
function show(name) {
  for (const s of find(name, "show")) {
    s.rt.hidden = false;
    const m = meshes.get(key(s.name));
    if (!m) { s.hidden = false; continue; }
    m.visible = !s.invisible;
    if (s.collide && !world.solids.includes(m)) world.solids.push(m);
    const model = npcs.get(key(s.name));
    if (model) model.visible = true;
  }
}

// ================================================================= the player

function spawn(x, y, z) { spawnAt = [num(x, 0), num(y, 0), num(z, 0)]; }
function walkSpeed(n) { game.speed = num(n, WALK); if (world.player) world.player.speed = game.speed; }
function jumpPower(n) { game.jump = num(n, JUMP); if (world.player) world.player.jump = game.jump; }
function gravity(n) { game.gravity = Math.max(0, num(n, 1)); }
function fly() { game.fly = true; }
function doubleJump() { game.doubleJump = true; }
function zoom(n) { world.cam.dist = Math.max(4, Math.min(60, num(n, 16))); }
function teleportPlayer(x, y, z) { if (world.player) { world.player.pos.set(num(x, 0), num(y, 0), num(z, 0)); world.player.vel.set(0, 0, 0); } }
function killPlayer() { world.kill(); }
function freeze() { if (world.player) world.player.frozen = true; }
function unfreeze() { if (world.player) world.player.frozen = false; }
function playerPosition() {
  const p = world.player;
  return p ? { x: p.pos.x, y: p.pos.y, z: p.pos.z } : { x: spawnAt[0], y: spawnAt[1], z: spawnAt[2] };
}
function distanceTo(name) {
  const m = meshes.get(key(name));
  if (!m) { find(name, "distanceTo"); return Infinity; }
  const p = playerPosition();
  return Math.hypot(m.position.x - p.x, m.position.y - p.y, m.position.z - p.z);
}
function touching(name) {
  const m = meshes.get(key(name));
  if (!m) { find(name, "touching"); return false; }
  return world.touching(m);
}
function healthOn() { if (!world.healthEl) { world.healthBar(); world.updateHealthBar(); } }

// ================================================================= the game

function addPoints(n) {
  usePoints = true;
  points += num(n, 1);
  if (pointsToWin && points >= pointsToWin) win();
}
function setPoints(n) { usePoints = true; points = num(n, 0); }
function getPoints() { return points; }
function winAtPoints(n) { usePoints = true; pointsToWin = num(n, 10); }
function timer(seconds) { timeLimit = Math.max(1, num(seconds, 60)); }
function onWin(fn) { if (typeof fn === "function") winFns.push(fn); }
function onDeath(fn) { if (typeof fn === "function") deathFns.push(fn); }
function forever(fn) {
  if (typeof fn !== "function") return problem("forever needs a function, like forever(function (dt) { ... });");
  repeaters.push({ fn, every: 0 });
}
function every(seconds, fn) {
  if (typeof fn !== "function") return problem("every needs a number and a function, like every(2, function () { ... });");
  repeaters.push({ fn, every: Math.max(0.05, num(seconds, 1)), next: Math.max(0.05, num(seconds, 1)) });
}
function wait(seconds, fn) {
  if (typeof fn !== "function") return problem("wait needs a number and a function, like wait(3, function () { ... });");
  later(num(seconds, 1), fn);
}
// Runs fn after some seconds of game time (stops when the game restarts).
const timers = [];
function later(seconds, fn) { timers.push({ at: clock + Math.max(0, seconds), fn }); }

function message(text) { Kit.toast(String(text), "", "#3b82f6"); }
function popup(title, text) { return Kit.overlay(String(title), text === undefined ? "" : String(text), "OK"); }
function playSound(sound) {
  if (!SOUNDS.includes(sound)) return problem(`playSound: sounds are ${SOUNDS.map((x) => `"${x}"`).join(", ")}.`);
  Kit.sfx(sound);
}
function random(a, b) {
  const lo = Math.ceil(Math.min(num(a, 1), num(b, 10))), hi = Math.floor(Math.max(num(a, 1), num(b, 10)));
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

// ================================================================= sky and light

function sky(c) {
  const col = colorOf(c);
  world.scene.background.set(col);
  if (world.scene.fog) world.scene.fog.color.set(col);
}
function light(hemi, sun, sunColor) {
  world.hemi.intensity = hemi;
  world.sun.intensity = sun;
  world.sun.color.set(sunColor);
}
function night() { sky("#0b1026"); light(0.45, 0.35, "#9db4ff"); }
function day() { sky("#8fd3ff"); light(1.15, 1.6, "#ffffff"); }
function sunset() { sky("#fb923c"); light(0.9, 1.2, "#ffb36b"); }
function fog(amount) {
  const a = Math.max(0, num(amount, 5));
  if (!world.scene.fog) return;
  world.scene.fog.near = a ? 250 / a : 250;
  world.scene.fog.far = a ? 700 / (a / 2 + 0.5) : 700;
}

// ================================================================= building the world

function build(s) {
  const k = key(s.name);
  if (meshes.has(k)) world.remove(meshes.get(k));
  if (npcs.has(k)) { world.scene.remove(npcs.get(k)); npcs.delete(k); }
  const m = world.part({
    size: s.size, pos: s.pos, color: s.color, material: s.material, studs: s.studs, collide: s.collide,
    kill: s.kill, moving: true, rot: s.rot ? [0, (s.rot * Math.PI) / 180, 0] : undefined,
    onTouch: s.powers.length ? () => s.powers.forEach((p) => touched(s, p)) : null,
  });
  if (s.opacity < 1) {
    m.material = m.material.map((x) => { const c = x.clone(); c.transparent = true; c.opacity = s.opacity; return c; });
    m.userData.ownPaint = true;
  }
  if (s.invisible || s.npc) m.visible = false;
  if (s.label) {
    const sp = world.label(s.label, { height: 1.6 });
    world.scene.remove(sp);
    sp.position.set(0, s.size[1] / 2 + 2, 0);
    m.add(sp);
  }
  if (s.npc) {
    const model = world.character({ head: "#f5cd30", torso: RAINBOW[s.name.length % RAINBOW.length], arms: "#f5cd30", legs: "#1e3a8a", face: "smile", hat: "none", shirt: "plain" }, s.name);
    model.position.set(s.pos[0], s.pos[1] - s.size[1] / 2, s.pos[2]);
    npcs.set(k, model);
  }
  m.userData.spec = s;
  meshes.set(k, m);
  if (s.rt.hidden || s.hidden) { s.rt.hidden = false; hide(s.name); }
  if (s.rt.reached) paint(m, "#22c55e");
}

// Where a part should be this frame.
function animate(s, m, dt) {
  const p = world.player;
  let [x, y, z] = s.pos;
  if (s.rt.slide) {
    const sl = s.rt.slide;
    sl.t = Math.min(sl.dur, sl.t + dt);
    const f = sl.t / sl.dur, e = f * f * (3 - 2 * f);
    [x, y, z] = sl.from.map((v, i) => v + (sl.to[i] - v) * e);
    if (sl.t >= sl.dur) { s.pos = sl.to.slice(); s.rt.slide = null; }
  }
  if (s.follow && p && p.alive) {
    const at = s.rt.followAt || (s.rt.followAt = [x, z]);
    const dx = p.pos.x - at[0], dz = p.pos.z - at[1], d = Math.hypot(dx, dz);
    if (d > 0.5) { at[0] += (dx / d) * Math.min(d, s.follow * dt); at[1] += (dz / d) * Math.min(d, s.follow * dt); }
    x = at[0]; z = at[1];
  }
  for (const mo of s.motions) {
    const v = Math.sin(clock * mo.speed) * mo.distance;
    if (mo.axis === 0) x += v; else if (mo.axis === 1) y += v; else z += v;
  }
  if (s.circle) { x += Math.cos(clock * s.circle.speed) * s.circle.r; z += Math.sin(clock * s.circle.speed) * s.circle.r; }
  if (s.rt.falling) {
    const f = s.rt.falling;
    f.t += dt;
    if (f.t < 0.5) x += Math.sin(f.t * 60) * 0.15;     // shake first
    else { f.v += 60 * dt; f.y -= f.v * dt; }
    y += f.y;
    if (f.t > 2.5 && !s.rt.hidden) hide(s.name);
    if (f.t > 5) { s.rt.falling = null; show(s.name); }
  }
  m.position.set(x, y, z);
  if (s.spin) m.rotation.y += s.spin * dt;
  if (s.rainbow) paint(m, RAINBOW[Math.floor(clock * 3 + s.name.length) % RAINBOW.length]);
  if (s.blink) {
    const on = Math.floor(clock / s.blink) % 2 === 0;
    if (on && s.rt.blinkHid) { s.rt.blinkHid = false; show(s.name); }
    else if (!on && !s.rt.hidden) { s.rt.blinkHid = true; hide(s.name); }
  }
  if (s.npc) {
    const model = npcs.get(key(s.name));
    if (model) {
      model.position.set(x, y - s.size[1] / 2, z);
      if (p) model.rotation.y = Math.atan2(x - p.pos.x, z - p.pos.z);   // face the player
    }
  }
}

async function win() {
  if (won || over) return;
  won = true;
  const p = world.player;
  p.frozen = true;
  Kit.sfx("win");
  Kit.badge(GAME_ID, "finished", "Winner", "Won the game.");
  if (deaths === 0) Kit.badge(GAME_ID, "no-deaths", "Perfect Run", "Won without falling once.");
  winFns.forEach((fn) => { try { fn(); } catch (e) { problem("Something went wrong in onWin: " + e.message); } });
  const t = Math.round(time * 10) / 10;
  const best = Kit.finish(GAME_ID, t, true);
  await Kit.overlay("You win!", `Time: ${t}s   Deaths: ${deaths}${coinsTotal ? `   Coins: ${coinsGot}/${coinsTotal}` : ""}${usePoints ? `   Points: ${points}` : ""}\nBest time: ${best}s`, "Play again");
  restart();
}
async function lose(text) {
  if (won || over) return;
  over = true;
  world.player.frozen = true;
  Kit.sfx("lose");
  await Kit.overlay("Game over", text ? String(text) : "Try again!", "Play again");
  restart();
}

// Back to the very start: every part as it was, points, coins and the timer reset.
function restart() {
  timers.length = 0;
  for (const s of specs.values()) { s.rt = {}; build(s); }
  world.checkpoint([spawnAt[0], spawnAt[1] + 0.5, spawnAt[2]]);
  world.respawn();
  Object.assign(world.player, { speed: game.speed, jump: game.jump, frozen: false });
  if (world.healthEl) world.heal(1000);
  coinsGot = 0; points = 0; deaths = 0; time = 0; won = false; over = false;
  for (const r of repeaters) if (r.every) r.next = clock + r.every;
}

function begin() {
  started = true;
  for (const s of specs.values()) build(s);
  for (const sp of signs) sp.sprite = world.label(sp.text, { pos: sp.pos, height: 2.5 });
  world.spawnPad(spawnAt);
  const me = world.spawnPlayer({ pos: [spawnAt[0], spawnAt[1] + 1, spawnAt[2]] });
  me.speed = game.speed;
  me.jump = game.jump;
  world.onDeath(() => {
    deaths++;
    deathFns.forEach((fn) => { try { fn(); } catch (e) { problem("Something went wrong in onDeath: " + e.message); } });
  });
  Kit.onKey((code) => {
    if (code !== "Space" || !game.doubleJump || !me.alive || me.frozen || me.onGround || game.airJumped) return;
    game.airJumped = true;
    me.vel.y = me.jump;
    Kit.sfx("jump");
  });
  try { world.online(Kit.net(GAME_ID)); } catch (_) {}
  touchButtons();
  for (const r of repeaters) if (r.every) r.next = r.every;
  world.start((dt) => {
    clock += dt;
    if (!won && !over) time += dt;
    for (const k of dirty) { const s = specs.get(k); if (s) build(s); }
    dirty.clear();
    for (const [k, m] of meshes) { const s = specs.get(k); if (s) animate(s, m, dt); }

    if (me.alive) {
      // Conveyor belts push you along; gravity() and fly() change how you fall.
      const on = me.onGround && me.standingOn && me.standingOn.userData.spec;
      if (on && on.conveyor) me.pos.z -= on.conveyor * dt;
      if (game.gravity !== 1) me.vel.y += GRAVITY * (1 - game.gravity) * dt;
      if (game.fly && !me.frozen && Kit.key("Space")) me.vel.y = Math.max(me.vel.y, 30);
      if (me.onGround) game.airJumped = false;
    }
    for (const s of specs.values()) {
      if (s.coinDoor && !s.rt.opened && coinsGot >= s.coinDoor) { s.rt.opened = true; hide(s.name); message(`${s.name} opened!`); Kit.sfx("win"); }
    }
    for (let i = timers.length - 1; i >= 0; i--) {
      if (clock >= timers[i].at) {
        const t = timers.splice(i, 1)[0];
        try { t.fn(); } catch (e) { problem("Something went wrong in wait: " + e.message); }
      }
    }
    for (const r of repeaters) {
      if (!r.fn) continue;
      if (r.every && clock < r.next) continue;
      if (r.every) r.next = clock + r.every;
      try { r.fn(dt); } catch (e) { problem("Something went wrong in forever/every: " + e.message); r.fn = null; }
    }
    if (timeLimit && !won && !over && time >= timeLimit) lose("Time's up!");

    const left = timeLimit ? Math.max(0, Math.ceil(timeLimit - time)) : null;
    const extra = [`Deaths ${deaths}`];
    if (coinsTotal) extra.push(`Coins ${coinsGot}/${coinsTotal}`);
    if (usePoints) extra.push(`Points ${points}${pointsToWin ? "/" + pointsToWin : ""}`);
    Kit.hud(`${left !== null ? `Time left ${left}` : `Time ${time.toFixed(1)}`}<small>${extra.join(" - ")}</small>`);
  });
}

// On-screen buttons for phones and tablets (drag on the game to turn the camera).
function touchButtons() {
  if (!(navigator.maxTouchPoints > 0)) return;
  const box = document.createElement("div");
  box.className = "tc";
  box.innerHTML = `<div class="tc-left"><div class="tc-pad">
      <button class="tc-btn tc-d-up" data-key="KeyW">^</button><button class="tc-btn tc-d-left" data-key="KeyA">&lt;</button>
      <button class="tc-btn tc-d-right" data-key="KeyD">&gt;</button><button class="tc-btn tc-d-down" data-key="KeyS">v</button></div></div>
    <div class="tc-right"><button class="tc-btn" data-key="Space">Jump</button></div>`;
  document.body.appendChild(box);
  box.querySelectorAll("[data-key]").forEach((btn) => {
    const send = (type) => document.body.dispatchEvent(new KeyboardEvent(type, { code: btn.dataset.key, bubbles: true }));
    let downAt = 0;
    btn.addEventListener("pointerdown", (e) => { e.preventDefault(); try { btn.setPointerCapture(e.pointerId); } catch (_) {} btn.classList.add("on"); downAt = Date.now(); send("keydown"); });
    const up = () => { if (btn.classList.contains("on")) { btn.classList.remove("on"); setTimeout(() => send("keyup"), Math.max(0, 100 - (Date.now() - downAt))); } };
    btn.addEventListener("pointerup", up);
    btn.addEventListener("lostpointercapture", up);
  });
}

// Every command, under its own name and in lower case (killOnTouch and killontouch both work).
const COMMANDS = {
  // building
  part, copy, remove, floor, wall, tower, stairs, row, tree, cloud, house, baseplate, lava, sign, npc,
  // looks
  color, randomColor, size, scale, glow, glass, wood, smooth, ghost, solid, rotate, transparent, invisible, rainbow, blink, label,
  hide, show,
  // movement
  moveTo, slideTo, moveSideToSide, moveUpAndDown, moveForwardAndBack, moveInCircle, spin, follow, conveyor, fallOnTouch, stopMoving,
  // touch powers
  killOnTouch, onTouch, checkpoint, finish, bounce, disappearOnTouch, coin, coinDoor, teleport, speedBoost, superJump, damage, heal,
  pointsOnTouch, messageOnTouch, soundOnTouch, badgeOnTouch, keyFor, toggle, talk,
  // the player
  spawn, walkSpeed, jumpPower, gravity, fly, doubleJump, zoom, teleportPlayer, killPlayer, freeze, unfreeze,
  playerPosition, distanceTo, touching,
  // the game
  win, lose, restart, timer, addPoints, setPoints, getPoints, winAtPoints, onWin, onDeath, forever, every, wait,
  message, popup, playSound, random,
  // sky and light
  sky, night, day, sunset, fog,
};
for (const [name, fn] of Object.entries(COMMANDS)) {
  window[name] = fn;
  window[name.toLowerCase()] = fn;
}
window.world = world;
window.EASY3D_COMMANDS = Object.keys(COMMANDS);

// Your code runs right after this file; the game starts once it's done.
setTimeout(begin, 0);
