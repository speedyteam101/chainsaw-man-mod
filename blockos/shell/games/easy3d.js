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
let timeLimit = 0, surviveFor = 0;
let maxLives = 0, livesLeft = 0, shieldUntil = 0, cycle = 0;
const counters = new Map();       // counter name -> number (shown at the top)
const game = { speed: WALK, jump: JUMP, gravity: 1, fly: false, doubleJump: false, airJumped: false, gravityFor: 0, flyFor: 0 };

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
function soundOnTouch(name, soundName) {
  if (!SOUNDS.includes(soundName) && !soundNames().includes(soundName)) return badSound("soundOnTouch", soundName);
  power(name, "soundOnTouch", { type: "sound", sound: soundName });
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
    case "sound": sound(p.sound); break;
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
    case "color": paint(meshes.get(k), p.color); s.color = p.color; break;
    case "lose": lose(p.text); break;
    case "addtime": if (!s.rt.used) { s.rt.used = true; addTime(p.seconds); message(`+${p.seconds} seconds!`); } break;
    case "lowgravity": game.gravity = 0.4; game.gravityFor = clock + p.seconds; Kit.sfx("score"); break;
    case "fly": game.flyFor = clock + p.seconds; Kit.sfx("score"); message("You can fly! Hold Jump."); break;
    case "shield": invincible(p.seconds); Kit.sfx("score"); message(`Shield for ${p.seconds} seconds!`); break;
    case "hide": hide(p.target); break;
    case "show": show(p.target); break;
    case "losepoints": if (!s.rt.scored) { s.rt.scored = true; addPoints(-p.n); Kit.sfx("hit"); } break;
    case "counter": if (!s.rt.counted) { s.rt.counted = true; addCounter(p.counter, p.n); Kit.sfx("coin"); } break;
    case "music": music(p.sound); break;
    case "say": say(p.text); break;
    case "restart": restart(); break;
    case "life": if (!s.rt.used && maxLives) { s.rt.used = true; livesLeft++; Kit.sfx("win"); message("+1 life!"); } break;
  }
}

// ================================================================= more building

const bridge = (name, x, y, z, length) => part(name, x, y, num(z, 0) - num(length, 30) / 2, 4, 1, num(length, 30));
const pillar = (name, x, y, z, height) => part(name, x, num(y, 0) + num(height, 10) / 2, z, 2, num(height, 10), 2);
function pyramid(name, x, y, z, levels) {
  const n = Math.max(1, Math.min(30, Math.round(num(levels, 5))));
  for (let i = 1; i <= n; i++) { const w = (n - i + 1) * 4; part(`${name} ${i}`, num(x, 0), num(y, 0) + i - 0.5, num(z, 0), w, 1, w); }
  return name;
}
function spiralStairs(name, x, y, z, steps) {
  const n = Math.max(1, Math.min(200, Math.round(num(steps, 16))));
  for (let i = 1; i <= n; i++) {
    const a = i * 0.5;
    part(`${name} ${i}`, num(x, 0) + Math.cos(a) * 7, num(y, 0) + i, num(z, 0) + Math.sin(a) * 7, 4, 1, 4);
  }
  return name;
}
function ring(name, x, y, z, count, radius) {
  const n = Math.max(1, Math.min(100, Math.round(num(count, 8)))), r = num(radius, 12);
  for (let i = 1; i <= n; i++) {
    const a = (i / n) * Math.PI * 2;
    part(`${name} ${i}`, num(x, 0) + Math.cos(a) * r, num(y, 0), num(z, 0) + Math.sin(a) * r, 4, 1, 4);
  }
  return name;
}
function grid(name, x, y, z, rows, cols, gap) {
  const R = Math.max(1, Math.min(30, Math.round(num(rows, 4)))), C = Math.max(1, Math.min(30, Math.round(num(cols, 4)))), g = num(gap, 6);
  let i = 0;
  for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) {
    part(`${name} ${++i}`, num(x, 0) + (c - (C - 1) / 2) * g, num(y, 0), num(z, 0) - r * g, 4, 1, 4);
    if ((r + c) % 2) color(`${name} ${i}`, "white");
  }
  return name;
}
function fence(name, x, y, z, length) {
  part(name, x, num(y, 0) + 1.5, z, num(length, 20), 3, 0.5);
  color(name, "brown"); wood(name);
  return name;
}
function room(name, x, y, z, roomSize) {
  const [hx, hy, hz] = [num(x, 0), num(y, 0), num(z, 0)], w = num(roomSize, 16);
  part(`${name} floor`, hx, hy - 0.5, hz, w, 1, w);
  part(`${name} back`, hx, hy + 4, hz - w / 2 + 0.5, w, 8, 1);
  part(`${name} front`, hx, hy + 4, hz + w / 2 - 0.5, w, 8, 1);
  part(`${name} left`, hx - w / 2 + 0.5, hy + 4, hz, 1, 8, w - 2);
  part(`${name} right`, hx + w / 2 - 0.5, hy + 4, hz, 1, 8, w - 2);
  part(`${name} roof`, hx, hy + 8.5, hz, w, 1, w);
  color(name, "gray");
  return name;
}
function deco(kind, pieces) {
  const n = `${kind} ${++unnamed}`;
  pieces.forEach((p, i) => {
    const pn = `${n} ${i + 1}`;
    part(pn, p[0], p[1], p[2], p[3], p[4], p[5]);
    color(pn, p[6]);
    if (p[7]) p[7].forEach((cmd) => COMMANDS[cmd](pn));
  });
  return n;
}
const bush = (x, y, z) => deco("bush", [[num(x, 0), num(y, 0) + 1.2, num(z, 0), 3, 2.4, 3, "green", ["smooth"]]]);
const flower = (x, y, z) => deco("flower", [
  [num(x, 0), num(y, 0) + 0.75, num(z, 0), 0.3, 1.5, 0.3, "darkgreen", ["smooth", "ghost"]],
  [num(x, 0), num(y, 0) + 1.7, num(z, 0), 1, 0.6, 1, RAINBOW[unnamed % RAINBOW.length], ["smooth", "ghost"]],
]);
const rock = (x, y, z) => deco("rock", [[num(x, 0), num(y, 0) + 1, num(z, 0), 3, 2, 2.5, "darkgray", ["smooth"]]]);
const lamp = (x, y, z) => deco("lamp", [
  [num(x, 0), num(y, 0) + 3, num(z, 0), 0.5, 6, 0.5, "black", ["smooth"]],
  [num(x, 0), num(y, 0) + 6.4, num(z, 0), 1.4, 1, 1.4, "yellow", ["glow", "smooth"]],
]);
function mountain(x, y, z, height) {
  const h = Math.max(5, num(height, 30)), n = `mountain ${++unnamed}`, levels = 5;
  for (let i = 0; i < levels; i++) {
    const w = h * 2 * (1 - i / levels);
    part(`${n} ${i + 1}`, num(x, 0), num(y, 0) + (i + 0.5) * (h / levels), num(z, 0), w, h / levels, w);
    color(`${n} ${i + 1}`, i === levels - 1 ? "white" : "darkgray");
  }
  smooth(n);
  return n;
}
function island(x, y, z) {
  const n = `island ${++unnamed}`;
  part(`${n} sand`, x, num(y, 0) - 1, z, 24, 2, 24); color(`${n} sand`, "sand");
  part(`${n} grass`, x, num(y, 0) - 0.25, z, 18, 0.5, 18); color(`${n} grass`, "green");
  tree(num(x, 0) + 4, num(y, 0), num(z, 0) - 3);
  return n;
}
function castle(name, x, y, z) {
  const [cx, cy, cz] = [num(x, 0), num(y, 0), num(z, 0)];
  part(`${name} floor`, cx, cy - 0.5, cz, 30, 1, 30);
  part(`${name} back`, cx, cy + 5, cz - 14, 30, 10, 2);
  part(`${name} left`, cx - 14, cy + 5, cz, 2, 10, 26);
  part(`${name} right`, cx + 14, cy + 5, cz, 2, 10, 26);
  part(`${name} front left`, cx - 9.5, cy + 5, cz + 14, 11, 10, 2);
  part(`${name} front right`, cx + 9.5, cy + 5, cz + 14, 11, 10, 2);
  [[-14, -14], [14, -14], [-14, 14], [14, 14]].forEach(([dx, dz], i) => part(`${name} tower ${i + 1}`, cx + dx, cy + 8, cz + dz, 6, 16, 6));
  color(name, "gray");
  return name;
}
function stars(count) {
  const n = Math.max(1, Math.min(300, Math.round(num(count, 80))));
  for (let i = 1; i <= n; i++) {
    const a = Math.random() * Math.PI * 2, d = 150 + Math.random() * 200;
    part(`star ${i}`, Math.cos(a) * d, 60 + Math.random() * 120, Math.sin(a) * d - 50, 1.2, 1.2, 1.2);
  }
  color("star", "white"); glow("star"); smooth("star"); ghost("star");
  return "star";
}
function scatter(kind, count, spread) {
  const makers = { tree, rock, flower, bush, cloud, coin, lamp };
  const kindName = String(kind).toLowerCase();
  const make = makers[kindName];
  if (!make) return problem(`scatter: you can scatter ${Object.keys(makers).map((x) => `"${x}"`).join(", ")}.`);
  const n = Math.max(1, Math.min(200, Math.round(num(count, 10)))), r = num(spread, 60);
  for (let i = 0; i < n; i++) {
    const x = (Math.random() * 2 - 1) * r, z = (Math.random() * 2 - 1) * r - r / 2;
    if (kindName === "cloud") make(x, 30 + Math.random() * 20, z);
    else if (kindName === "coin") make(x, 1.5, z);
    else make(x, 0, z);
  }
}

// ================================================================= more looks

function fadeOut(name, seconds) {
  for (const s of find(name, "fadeOut")) s.rt.fade = { from: 1, to: 0, t: 0, dur: Math.max(0.1, num(seconds, 1)) };
}
function fadeIn(name, seconds) {
  for (const s of find(name, "fadeIn")) { show(s.name); s.rt.fade = { from: 0, to: s.opacity, t: 0, dur: Math.max(0.1, num(seconds, 1)) }; }
}
function flash(name, c) {
  for (const s of find(name, "flash")) {
    const m = meshes.get(key(s.name));
    if (!m) continue;
    paint(m, colorOf(c || "white"));
    later(0.25, () => paint(m, s.color));
  }
}
const pulseColors = (name, c1, c2) => change(name, "pulseColors", (s) => { s.pulse = [colorOf(c1 || "red"), colorOf(c2 || "yellow")]; });
const shake = (name) => change(name, "shake", (s) => { s.shake = true; });
const bob = (name) => change(name, "bob", (s) => s.motions.push({ axis: 1, distance: 0.6, speed: 2 }));
const colorOnTouch = (name, c) => power(name, "colorOnTouch", { type: "color", color: colorOf(c || "green") });

// ================================================================= more movement

const rise = (name, speed) => change(name, "rise", (s) => { s.drift = [0, num(speed, 1), 0]; });
const sink = (name, speed) => change(name, "sink", (s) => { s.drift = [0, -num(speed, 1), 0]; });
const drift = (name, sx, sy, sz) => change(name, "drift", (s) => { s.drift = [num(sx, 0), num(sy, 0), num(sz, 0)]; });
const moveBetween = (name, x, y, z, speed) => change(name, "moveBetween", (s) => { s.between = { to: [num(x, s.pos[0]), num(y, s.pos[1]), num(z, s.pos[2])], speed: num(speed, 1) }; });
const elevator = (name, height, speed) => change(name, "elevator", (s) => { s.between = { to: [s.pos[0], s.pos[1] + num(height, 10), s.pos[2]], speed: num(speed, 0.6) }; });
const orbit = (name, center, radius, speed) => change(name, "orbit", (s) => { s.orbit = { center, r: num(radius, 8), speed: num(speed, 1) }; });
const flee = (name, speed) => change(name, "flee", (s) => { s.flee = num(speed, 6); });
const wander = (name, speed) => change(name, "wander", (s) => { s.wander = num(speed, 4); });

// ================================================================= more touch powers

const loseOnTouch = (name, text) => power(name, "loseOnTouch", { type: "lose", text: text === undefined ? "You touched " + name + "!" : String(text) });
const addTimeOnTouch = (name, seconds) => power(name, "addTimeOnTouch", { type: "addtime", seconds: num(seconds, 10) });
const slowOnTouch = (name, speed, seconds) => power(name, "slowOnTouch", { type: "speed", speed: num(speed, 6), seconds: num(seconds, 3) });
const lowGravityOnTouch = (name, seconds) => power(name, "lowGravityOnTouch", { type: "lowgravity", seconds: num(seconds, 5) });
const flyOnTouch = (name, seconds) => power(name, "flyOnTouch", { type: "fly", seconds: num(seconds, 5) });
const shieldOnTouch = (name, seconds) => power(name, "shieldOnTouch", { type: "shield", seconds: num(seconds, 5) });
const hideOnTouch = (name, target) => power(name, "hideOnTouch", { type: "hide", target });
const showOnTouch = (name, target) => power(name, "showOnTouch", { type: "show", target });
const losePointsOnTouch = (name, n) => { usePoints = true; power(name, "losePointsOnTouch", { type: "losepoints", n: num(n, 1) }); };
const counterOnTouch = (name, counterName, n) => power(name, "counterOnTouch", { type: "counter", counter: String(counterName || "Score"), n: num(n, 1) });
const musicOnTouch = (name, sound) => power(name, "musicOnTouch", { type: "music", sound: String(sound) });
const sayOnTouch = (name, text) => power(name, "sayOnTouch", { type: "say", text: String(text) });
const restartOnTouch = (name) => power(name, "restartOnTouch", { type: "restart" });
const lifeOnTouch = (name) => power(name, "lifeOnTouch", { type: "life" });

// ================================================================= more for the player

function lives(n) { maxLives = livesLeft = Math.max(1, Math.round(num(n, 3))); }
function health(n) {
  healthOn();
  game.health = Math.max(1, num(n, 100));
  if (world.player) { world.player.maxHealth = world.player.health = game.health; world.updateHealthBar(); }
}
function setHealth(n) {
  healthOn();
  const p = world.player;
  if (!p) return;
  p.health = Math.max(0, Math.min(p.maxHealth, num(n, p.maxHealth)));
  world.updateHealthBar();
  if (p.health <= 0) world.kill();
}
const getHealth = () => (world.player ? world.player.health : 100);
function jump() { const p = world.player; if (p && p.alive && p.onGround) { p.vel.y = p.jump; p.onGround = false; Kit.sfx("jump"); } }
function shiftLock(on) { world.cam.shiftLock = on !== false; }
function turnCamera(degrees) { world.cam.yaw += (num(degrees, 90) * Math.PI) / 180; }
const playerName = () => Kit.player().name;
const isOnGround = () => !!(world.player && world.player.onGround);
function invincible(seconds) { shieldUntil = clock + Math.max(0, num(seconds, 5)); }
function resetSpeed() { const p = world.player; if (p) { p.speed = game.speed; p.jump = game.jump; } }
function say(text) { if (world.player) world.bubble(world.player.group, String(text)); }

// ================================================================= more for the game

const KEY_NAMES = { space: "Space", enter: "Enter", shift: "ShiftLeft", up: "ArrowUp", down: "ArrowDown", left: "ArrowLeft", right: "ArrowRight", tab: "Tab" };
const keyFns = [];
function onKey(k, fn) {
  if (typeof fn !== "function") return problem('onKey needs a key and a function, like onKey("E", function () { ... });');
  const t = String(k).trim();
  const code = /^[a-z]$/i.test(t) ? "Key" + t.toUpperCase() : /^[0-9]$/.test(t) ? "Digit" + t : KEY_NAMES[t.toLowerCase()] || t;
  keyFns.push({ code, fn });
}
const startCounters = new Map();
function counter(name, start) { counters.set(String(name), num(start, 0)); if (!started) startCounters.set(String(name), num(start, 0)); }
function addCounter(name, n) { const k = String(name); counters.set(k, (counters.get(k) || 0) + num(n, 1)); }
const getCounter = (name) => counters.get(String(name)) || 0;
let textEl = null;
function showText(text) {
  if (!textEl) {
    textEl = document.createElement("div");
    textEl.style.cssText = "position:fixed;top:64px;left:50%;transform:translateX(-50%);z-index:5;background:rgba(0,0,0,.6);color:#fff;" +
      "padding:8px 16px;border-radius:10px;font:800 18px system-ui,sans-serif;pointer-events:none;text-align:center;max-width:80vw";
    document.body.appendChild(textEl);
  }
  textEl.textContent = String(text);
  textEl.style.display = "";
}
function hideText() { if (textEl) textEl.style.display = "none"; }
const chance = (percent) => Math.random() * 100 < num(percent, 50);
function repeat(n, fn) {
  if (typeof fn !== "function") return problem("repeat needs a number and a function, like repeat(5, function (i) { ... });");
  const times = Math.max(0, Math.min(1000, Math.round(num(n, 1))));
  for (let i = 1; i <= times; i++) fn(i);
}
function badge(badgeName) {
  const b = String(badgeName || "Winner");
  Kit.badge(GAME_ID, b.toLowerCase().replace(/[^a-z0-9]+/g, "-").slice(0, 30), b, "Earned in " + document.title);
}
function addTime(seconds) { if (timeLimit) timeLimit += num(seconds, 10); }
function stopTimer() { timeLimit = 0; }
function winAfter(seconds) { surviveFor = Math.max(1, num(seconds, 60)); }
function countdown() {
  const p = world.player;
  if (!p) return later(0, countdown);
  p.frozen = true;
  ["3", "2", "1"].forEach((t, i) => later(i, () => { showText(t); Kit.sfx("click"); }));
  later(3, () => { showText("Go!"); Kit.sfx("score"); p.frozen = false; time = 0; });
  later(4, hideText);
}
function soundNames() { return Kit.soundNames ? Kit.soundNames() : []; }
function badSound(command, name) {
  const mine = soundNames();
  problem(`${command}("${name}"): there's no sound called "${name}". Built-in sounds: ${SOUNDS.join(", ")}.` +
    (mine.length ? ` Your sounds: ${mine.join(", ")}.` : " Add your own with the Sounds button."));
}
function sound(name) { if (!Kit.sound(String(name))) badSound("sound", name); }
function music(name) { if (!Kit.music(String(name))) badSound("music", name); }
function stopMusic() { Kit.stopMusic(); }
function volume(n) { Kit.volume(num(n, 1)); }

// ================================================================= more sky and light

let brightnessLevel = 1;
function brightness(n) {
  brightnessLevel = Math.max(0, num(n, 1));
  world.hemi.intensity = 1.15 * brightnessLevel;
  world.sun.intensity = 1.6 * brightnessLevel;
}
function sunColor(c) { world.sun.color.set(colorOf(c)); }
function dayNightCycle(seconds) { cycle = Math.max(5, num(seconds, 60)); }
function mix(a, b, f) {
  const ca = parseInt(a.slice(1), 16), cb = parseInt(b.slice(1), 16);
  const ch = (sh) => Math.round(((ca >> sh) & 255) * (1 - f) + ((cb >> sh) & 255) * f);
  return "#" + ((ch(16) << 16) | (ch(8) << 8) | ch(0)).toString(16).padStart(6, "0");
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
function playSound(name) { if (!Kit.sound(String(name))) badSound("playSound", name); }
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
  if (s.drift) {
    const d = s.rt.drift || (s.rt.drift = [0, 0, 0]);
    for (let i = 0; i < 3; i++) d[i] += s.drift[i] * dt;
    x += d[0]; y += d[1]; z += d[2];
  }
  if (s.between) {
    const f = (1 - Math.cos(clock * s.between.speed)) / 2;
    x += (s.between.to[0] - s.pos[0]) * f; y += (s.between.to[1] - s.pos[1]) * f; z += (s.between.to[2] - s.pos[2]) * f;
  }
  if (s.orbit) {
    const c = meshes.get(key(s.orbit.center));
    if (c) { x = c.position.x + Math.cos(clock * s.orbit.speed) * s.orbit.r; z = c.position.z + Math.sin(clock * s.orbit.speed) * s.orbit.r; }
  }
  if ((s.flee || s.wander) && p) {
    const at = s.rt.at || (s.rt.at = [x, z]);
    let dx = 0, dz = 0, speed = 0;
    if (s.flee && Math.hypot(at[0] - p.pos.x, at[1] - p.pos.z) < 30) { dx = at[0] - p.pos.x; dz = at[1] - p.pos.z; speed = s.flee; }
    else if (s.wander) {
      if (!s.rt.dir || clock > s.rt.dirUntil) { const a = Math.random() * Math.PI * 2; s.rt.dir = [Math.cos(a), Math.sin(a)]; s.rt.dirUntil = clock + 1 + Math.random() * 2; }
      // Stay within 25 studs of where it started.
      if (Math.hypot(at[0] - s.pos[0], at[1] - s.pos[2]) > 25) s.rt.dir = [s.pos[0] - at[0], s.pos[2] - at[1]];
      [dx, dz] = s.rt.dir; speed = s.wander;
    }
    const d = Math.hypot(dx, dz);
    if (d > 0.01) { at[0] += (dx / d) * speed * dt; at[1] += (dz / d) * speed * dt; }
    x = at[0]; z = at[1];
  }
  if (s.shake) { x += Math.sin(clock * 47) * 0.12; z += Math.cos(clock * 53) * 0.12; }
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
  if (s.pulse) paint(m, s.pulse[Math.floor(clock * 2) % 2]);
  if (s.rt.fade) {
    const f = s.rt.fade;
    f.t = Math.min(f.dur, f.t + dt);
    const o = f.from + (f.to - f.from) * (f.t / f.dur);
    if (!m.userData.ownPaint) { m.material = m.material.map((x2) => x2.clone()); m.userData.ownPaint = true; }
    m.material.forEach((mat) => { mat.transparent = true; mat.opacity = o; });
    if (f.t >= f.dur) { s.rt.fade = null; if (f.to === 0) hide(s.name); }
  }
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
  livesLeft = maxLives; shieldUntil = 0; game.flyFor = 0; game.gravityFor = 0;
  if (game.health) { world.player.maxHealth = world.player.health = game.health; world.updateHealthBar(); }
  for (const k of counters.keys()) counters.set(k, startCounters.get(k) || 0);
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
  if (game.health) me.maxHealth = me.health = game.health;
  // invincible(): touching kill parts does nothing; falling off the world still sends you back.
  const realKill = world.kill.bind(world);
  world.kill = () => {
    if (clock < shieldUntil) { if (me.pos.y < world.voidY) { world.respawn(); } return; }
    realKill();
  };
  world.onDeath(() => {
    deaths++;
    if (maxLives) {
      livesLeft--;
      if (livesLeft <= 0) later(0.5, () => lose("Out of lives!"));
    }
    deathFns.forEach((fn) => { try { fn(); } catch (e) { problem("Something went wrong in onDeath: " + e.message); } });
  });
  Kit.onKey((code) => {
    if (!won && !over) for (const k of keyFns) if (k.code === code) { try { k.fn(); } catch (e) { problem("Something went wrong in onKey: " + e.message); } }
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
      if (game.gravityFor && clock > game.gravityFor) { game.gravityFor = 0; game.gravity = 1; }
      if (game.gravity !== 1) me.vel.y += GRAVITY * (1 - game.gravity) * dt;
      if ((game.fly || clock < game.flyFor) && !me.frozen && Kit.key("Space")) me.vel.y = Math.max(me.vel.y, 30);
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
    if (surviveFor && !won && !over && time >= surviveFor) win();
    if (cycle) {
      const f = (1 - Math.cos((clock / cycle) * Math.PI * 2)) / 2;   // 0 = day, 1 = night
      sky(mix("#8fd3ff", "#0b1026", f));
      world.hemi.intensity = (1.15 - 0.7 * f) * brightnessLevel;
      world.sun.intensity = (1.6 - 1.25 * f) * brightnessLevel;
    }

    const left = timeLimit ? Math.max(0, Math.ceil(timeLimit - time)) : surviveFor ? Math.max(0, Math.ceil(surviveFor - time)) : null;
    const extra = [maxLives ? `Lives ${livesLeft}` : `Deaths ${deaths}`];
    for (const [cn, cv] of counters) extra.push(`${cn} ${cv}`);
    if (coinsTotal) extra.push(`Coins ${coinsGot}/${coinsTotal}`);
    if (usePoints) extra.push(`Points ${points}${pointsToWin ? "/" + pointsToWin : ""}`);
    Kit.hud(`${left !== null ? `${surviveFor && !timeLimit ? "Survive" : "Time left"} ${left}` : `Time ${time.toFixed(1)}`}<small>${extra.join(" - ")}</small>`);
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
  // ----- added later -----
  bridge, pillar, pyramid, spiralStairs, ring, grid, fence, room, bush, flower, rock, lamp, mountain, island, castle, stars, scatter,
  fadeOut, fadeIn, flash, pulseColors, shake, bob, colorOnTouch,
  rise, sink, drift, moveBetween, elevator, orbit, flee, wander,
  loseOnTouch, addTimeOnTouch, slowOnTouch, lowGravityOnTouch, flyOnTouch, shieldOnTouch, hideOnTouch, showOnTouch,
  losePointsOnTouch, counterOnTouch, musicOnTouch, sayOnTouch, restartOnTouch, lifeOnTouch,
  lives, health, setHealth, getHealth, jump, shiftLock, turnCamera, playerName, isOnGround, invincible, resetSpeed, say,
  onKey, counter, addCounter, getCounter, showText, hideText, chance, repeat, badge, addTime, stopTimer, winAfter, countdown,
  sound, music, stopMusic, volume,
  brightness, sunColor, dayNightCycle,
};
// defineProperty also replaces names the browser already uses on window (like "fence").
for (const [name, fn] of Object.entries(COMMANDS)) {
  for (const n of new Set([name, name.toLowerCase()])) {
    try { Object.defineProperty(window, n, { value: fn, writable: true, configurable: true }); }
    catch (_) { problem(`The command ${n}() isn't available in this browser.`); }
  }
}
window.world = world;
window.EASY3D_COMMANDS = Object.keys(COMMANDS);
window.EASY3D_CLOCK = () => clock;   // game time in seconds (used by tests)

// Your code runs right after this file; the game starts once it's done.
setTimeout(begin, 0);
