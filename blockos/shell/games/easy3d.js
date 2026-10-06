/*
 * Easy 3D: the simplest way to make a 3D game in BlockOS. Give each part a name, then give it
 * powers with one-line commands:
 *
 *   <script src="kit.js"></script>
 *   <script type="module">
 *   import "./easy3d.js";
 *
 *   part("start", 0, 0, 0, 12, 1, 12);
 *   part("lava block", 0, 1, -12);
 *   color("lava block", "red");
 *   killOnTouch("lava block");
 *   </script>
 *
 * The game starts by itself when your code is done. Names can be anything ("part 1", "Big Wall").
 * Command names work in any capitals: killOnTouch, killontouch and KILLONTOUCH are all the same.
 * Positions: x = left/right, y = up, z = forward (more negative = further ahead).
 *
 * Every command, with the default numbers:
 *   part(name, x, y, z, width = 6, height = 1, depth = 6)   make a block (x, y, z is its middle)
 *   color(name, color)            "red", "blue", "green"... or a color code like "#ff8800"
 *   size(name, width, height, depth)   moveTo(name, x, y, z)
 *   glow(name)  glass(name)  wood(name)  smooth(name) (no studs)  ghost(name) (walk through it)
 *   killOnTouch(name)             touching it sends you back to your last checkpoint
 *   checkpoint(name)              touching it saves your place
 *   finish(name)                  touching it wins the game
 *   bounce(name, power = 100)     a trampoline
 *   disappearOnTouch(name)        vanishes a moment after you touch it, then comes back
 *   moveSideToSide(name, distance = 8, speed = 1)   moveUpAndDown(...)   moveForwardAndBack(...)
 *   spin(name, speed = 1)         spins round (spinning parts are ghosts: great for kill bars)
 *   coin(x, y, z) or coin(name)   a coin to collect
 *   hide(name)  show(name)        onTouch(name, function () { ... })
 *   sign(text, x, y, z)           floating words
 *   sky(color)  lava()  spawn(x, y, z)  walkSpeed(16)  jumpPower(52)  message(text)
 *   forever(function (dt) { ... })   runs over and over while the game is running
 */
import { World } from "./kit3d.js";

const COLOR_NAMES = {
  red: "#ef4444", orange: "#f97316", yellow: "#facc15", gold: "#eab308", lime: "#84cc16", green: "#22c55e",
  teal: "#14b8a6", cyan: "#06b6d4", lightblue: "#7dd3fc", sky: "#8fd3ff", blue: "#3b82f6", darkblue: "#1e3a8a",
  purple: "#a855f7", pink: "#ec4899", brown: "#92400e", white: "#f8fafc", gray: "#94a3b8", grey: "#94a3b8",
  darkgray: "#475569", black: "#111827", lava: "#f97316",
};
const colorOf = (c) => COLOR_NAMES[String(c).toLowerCase().replace(/\s+/g, "")] || String(c);

// The game's name, for badges, best times and online play: made from the page's <title>.
const GAME_ID = ((document.title || "easy-3d").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 20)) || "easy-3d";

const world = new World({ sky: "#8fd3ff" });
const specs = new Map();          // name (lower case) -> what you asked for
const meshes = new Map();         // name (lower case) -> the 3D block, once the game starts
const loops = [];
let started = false;
let spawnAt = [0, 0, 0];
let coinsTotal = 0, coinsGot = 0, deaths = 0, time = 0, won = false, clock = 0;
let unnamed = 0;
const settings = { speed: null, jump: null };

const key = (name) => String(name).trim().toLowerCase();
function problem(text) { console.error(text); }

// Finds a part by name, or explains what's wrong (shown in the studio's Output).
function find(name, command) {
  const s = specs.get(key(name));
  if (!s) problem(`${command}("${name}"): there's no part called "${name}". Make it first with part("${name}", x, y, z).`);
  return s;
}

function part(name, x, y, z, width, height, depth) {
  if (typeof name !== "string") return problem('part needs a name first, like part("part 1", 0, 2, -10).');
  const nums = [x, y, z].map((n) => Number(n) || 0);
  const s = {
    name, pos: nums, size: [Number(width) || 6, Number(height) || 1, Number(depth) || 6],
    color: "#a3a2a5", material: "plastic", studs: true, collide: true, kill: false,
    touch: [], motions: [], spin: 0,
  };
  specs.set(key(name), s);
  if (started) build(s);
  return name;
}

// Commands that change how a part looks: only before the game starts (except color).
function beforeStart(command, name, fn) {
  const s = find(name, command);
  if (!s) return;
  if (started) return problem(`${command}("${name}") only works before the game starts (not inside forever or onTouch).`);
  fn(s);
}

function color(name, c) {
  const s = find(name, "color");
  if (!s) return;
  s.color = colorOf(c);
  const m = meshes.get(key(name));
  if (m) {
    // Its own paint, so other parts with the same color don't change too.
    if (!m.userData.ownPaint) { m.material = m.material.map((x) => x.clone()); m.userData.ownPaint = true; }
    m.material.forEach((x) => x.color.set(s.color));
  }
}
const size = (name, w, h, d) => beforeStart("size", name, (s) => { s.size = [Number(w) || 1, Number(h) || 1, Number(d) || 1]; });
const glow = (name) => beforeStart("glow", name, (s) => { s.material = "neon"; });
const glass = (name) => beforeStart("glass", name, (s) => { s.material = "glass"; });
const wood = (name) => beforeStart("wood", name, (s) => { s.material = "wood"; });
const smooth = (name) => beforeStart("smooth", name, (s) => { s.studs = false; });
const ghost = (name) => beforeStart("ghost", name, (s) => { s.collide = false; });

function moveTo(name, x, y, z) {
  const s = find(name, "moveTo");
  if (!s) return;
  s.pos = [x, y, z].map((n) => Number(n) || 0);
  const m = meshes.get(key(name));
  if (m) { m.position.set(...s.pos); m.userData.base = m.position.clone(); world.updateBox(m); }
}

function killOnTouch(name) {
  const s = find(name, "killOnTouch");
  if (!s) return;
  s.kill = true;
  const m = meshes.get(key(name));
  if (m) { m.userData.part.kill = true; if (!world.touchers.includes(m)) world.touchers.push(m); }
}

function onTouch(name, fn) {
  const s = find(name, "onTouch");
  if (!s) return;
  if (typeof fn !== "function") return problem(`onTouch("${name}", ...) needs a function, like onTouch("${name}", function () { message("Hi!"); });`);
  s.touch.push(fn);
  const m = meshes.get(key(name));
  if (m && !world.touchers.includes(m)) world.touchers.push(m);
}

function checkpoint(name) {
  const s = find(name, "checkpoint");
  if (!s) return;
  s.checkpoint = true;
  s.touch.push(() => {
    const m = meshes.get(key(name));
    if (m.userData.reached) return;
    m.userData.reached = true;
    world.checkpoint([m.position.x, m.position.y + s.size[1] / 2 + 0.5, m.position.z]);
    color(name, "green");
    Kit.sfx("score");
    Kit.toast("Checkpoint!", "You'll come back here if you fall.", "#22c55e");
  });
}

function finish(name) {
  const s = find(name, "finish");
  if (!s) return;
  s.touch.push(() => win());
}

function bounce(name, power) {
  const s = find(name, "bounce");
  if (!s) return;
  const p = Number(power) || 100;
  s.touch.push(() => { if (world.player) { world.player.vel.y = p; Kit.sfx("jump"); } });
}

function disappearOnTouch(name) {
  const s = find(name, "disappearOnTouch");
  if (!s) return;
  s.touch.push(() => {
    const m = meshes.get(key(name));
    if (m.userData.fading) return;
    m.userData.fading = true;
    setTimeout(() => hide(name), 600);
    setTimeout(() => { show(name); m.userData.fading = false; }, 3600);
  });
}

function addMotion(command, axis, name, distance, speed) {
  const s = find(name, command);
  if (!s) return;
  s.motions.push({ axis, distance: distance === undefined ? 8 : Number(distance) || 0, speed: speed === undefined ? 1 : Number(speed) || 0 });
}
const moveSideToSide = (name, distance, speed) => addMotion("moveSideToSide", "x", name, distance, speed);
const moveUpAndDown = (name, distance, speed) => addMotion("moveUpAndDown", "y", name, distance, speed);
const moveForwardAndBack = (name, distance, speed) => addMotion("moveForwardAndBack", "z", name, distance, speed);

function spin(name, speed) {
  beforeStart("spin", name, (s) => { s.spin = speed === undefined ? 1 : Number(speed) || 0; s.collide = false; });
}

function hide(name) {
  const m = meshes.get(key(name));
  if (!m) { if (find(name, "hide")) specs.get(key(name)).hidden = true; return; }
  m.visible = false;
  const i = world.solids.indexOf(m);
  if (i >= 0) world.solids.splice(i, 1);
  m.userData.hidden = true;
}
function show(name) {
  const m = meshes.get(key(name));
  if (!m) { if (find(name, "show")) specs.get(key(name)).hidden = false; return; }
  m.visible = true;
  m.userData.hidden = false;
  if (m.userData.part.collide && !world.solids.includes(m)) world.solids.push(m);
}

function coin(a, y, z) {
  let name = a;
  if (typeof a !== "string") {
    name = "coin " + ++unnamed;
    part(name, a, y, z, 1.6, 1.6, 0.5);
    color(name, "gold");
    glow(name);
    smooth(name);
    spin(name, 2);
  } else if (!find(name, "coin")) return;
  const s = specs.get(key(name));
  s.coin = true;
  s.collide = false;
  coinsTotal++;
  s.touch.push(() => {
    const m = meshes.get(key(name));
    if (m.userData.hidden) return;
    hide(name);
    coinsGot++;
    Kit.sfx("coin");
    if (coinsGot === coinsTotal) Kit.badge(GAME_ID, "all-coins", "Coin Collector", "Collected every coin.");
  });
}

function sign(text, x, y, z) {
  const go = () => world.label(String(text), { pos: [Number(x) || 0, Number(y) || 0, Number(z) || 0], height: 2.5 });
  if (started) go(); else loops.push({ once: go });
}

function sky(c) {
  const col = colorOf(c);
  world.scene.background.set(col);
  if (world.scene.fog) world.scene.fog.color.set(col);
}

// A huge sheet of lava far below: fall off and you go back to your checkpoint.
function lava(y) {
  part("lava", 0, Number(y) || -14, -100, 600, 1, 800);
  color("lava", "lava");
  glow("lava");
  smooth("lava");
  killOnTouch("lava");
}

function spawn(x, y, z) { spawnAt = [x, y, z].map((n) => Number(n) || 0); }
function walkSpeed(n) { settings.speed = Number(n) || 16; if (world.player) world.player.speed = settings.speed; }
function jumpPower(n) { settings.jump = Number(n) || 52; if (world.player) world.player.jump = settings.jump; }
function message(text) { Kit.toast(String(text), "", "#3b82f6"); }
function forever(fn) {
  if (typeof fn !== "function") return problem("forever needs a function, like forever(function (dt) { ... });");
  loops.push({ every: fn });
}

// ---------------------------------------------------------------- the game

function build(s) {
  const k = key(s.name);
  if (meshes.has(k)) world.remove(meshes.get(k));
  const moving = s.motions.length > 0 || s.spin !== 0;
  const m = world.part({
    size: s.size, pos: s.pos, color: s.color, material: s.material, studs: s.studs, collide: s.collide,
    kill: s.kill, moving, onTouch: s.touch.length ? () => s.touch.forEach((fn) => {
      try { fn(); } catch (e) { problem(`Something went wrong in onTouch("${s.name}"): ${e.message}`); }
    }) : null,
  });
  m.userData.base = m.position.clone();
  m.userData.spec = s;
  meshes.set(k, m);
  if (s.hidden) hide(s.name);
}

async function win() {
  if (won) return;
  won = true;
  const p = world.player;
  p.frozen = true;
  Kit.sfx("win");
  Kit.badge(GAME_ID, "finished", "Winner", "Reached the finish.");
  if (deaths === 0) Kit.badge(GAME_ID, "no-deaths", "Perfect Run", "Finished without falling once.");
  const t = Math.round(time * 10) / 10;
  const best = Kit.finish(GAME_ID, t, true);
  await Kit.overlay("You win!", `Time: ${t}s   Deaths: ${deaths}${coinsTotal ? `   Coins: ${coinsGot}/${coinsTotal}` : ""}\nBest time: ${best}s`, "Play again");
  // Start over: back to the start, checkpoints and coins reset.
  for (const [k, m] of meshes) {
    const s = specs.get(k);
    if (s.checkpoint && m.userData.reached) { m.userData.reached = false; color(s.name, s.startColor); }
    if (s.coin) show(s.name);
  }
  world.checkpoint([spawnAt[0], spawnAt[1] + 0.5, spawnAt[2]]);
  world.respawn();
  coinsGot = 0; deaths = 0; time = 0; won = false; p.frozen = false;
}

function begin() {
  started = true;
  // Checkpoints keep their own color so they can turn green when reached.
  for (const s of specs.values()) {
    if (s.checkpoint && s.color === "#a3a2a5") s.color = "#94a3b8";
    s.startColor = s.color;
    build(s);
  }
  world.spawnPad(spawnAt);
  const me = world.spawnPlayer({ pos: [spawnAt[0], spawnAt[1] + 1, spawnAt[2]] });
  if (settings.speed) me.speed = settings.speed;
  if (settings.jump) me.jump = settings.jump;
  world.onDeath(() => { deaths++; });
  for (const l of loops) if (l.once) l.once();
  try { world.online(Kit.net(GAME_ID)); } catch (_) {}
  touchButtons();
  world.start((dt) => {
    clock += dt;
    if (!won) time += dt;
    for (const m of meshes.values()) {
      const s = m.userData.spec;
      if (!s.motions.length && !s.spin) continue;
      const b = m.userData.base;
      m.position.copy(b);
      for (const mo of s.motions) m.position[mo.axis] = b[mo.axis] + Math.sin(clock * mo.speed) * mo.distance;
      if (s.spin) m.rotation.y += s.spin * dt;
    }
    for (const l of loops) {
      if (!l.every) continue;
      try { l.every(dt); } catch (e) { problem("Something went wrong in forever: " + e.message); l.every = null; }
    }
    Kit.hud(`Time ${time.toFixed(1)}<small>Deaths ${deaths}${coinsTotal ? ` - Coins ${coinsGot}/${coinsTotal}` : ""}</small>`);
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
  part, color, size, moveTo, glow, glass, wood, smooth, ghost, killOnTouch, onTouch, checkpoint, finish, bounce,
  disappearOnTouch, moveSideToSide, moveUpAndDown, moveForwardAndBack, spin, hide, show, coin, sign, sky, lava,
  spawn, walkSpeed, jumpPower, message, forever,
};
for (const [name, fn] of Object.entries(COMMANDS)) {
  window[name] = fn;
  window[name.toLowerCase()] = fn;
}
window.world = world;

// Your code runs right after this file; the game starts once it's done.
setTimeout(begin, 0);
