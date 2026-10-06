// Rocket Lab: build a rocket from blocks, fly it to the clouds, to space, into orbit and to the Moon.
import { THREE } from "../kit3d.js";
import {
  PARTS, LIMITS, Flight, stats, cleanDesign, emptyDesign, guideTilt, burnDv, thrustOf, air,
  G0, R_EARTH, KARMAN, MOON_DIST, MOON_G,
} from "./physics.js";
import { Scene3D } from "./scene.js";

const ID = "rocket-lab";
const $ = (id) => document.getElementById(id);
const esc = (v) => String(v).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const me = Kit.player();

// ======================================================================= save data

const SAVE_KEY = "blockos.rocket-lab.v1";
const START_OWNED = { capsule: 1, fins: 1, tankS: 1, engW: 1 };
function loadSave() {
  let s = {};
  try { s = JSON.parse(localStorage.getItem(SAVE_KEY)) || {}; } catch (_) {}
  return {
    coins: Math.max(0, +s.coins || 0),
    owned: Object.assign({}, START_OWNED, s.owned || {}),
    goals: Object.assign({}, s.goals || {}),
    best: Math.max(0, +s.best || 0),
    flights: Math.max(0, +s.flights || 0),
    design: s.design || null,
    facts: Object.assign({}, s.facts || {}),
  };
}
const save = loadSave();
function persist() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(save)); } catch (_) {} }

const GOALS = {
  clouds: { name: "Above the Clouds", text: "fly above 3 km" },
  sky10: { name: "10 km", text: "reach 10 km" },
  space: { name: "Space", text: "reach space (100 km)" },
  orbit: { name: "Orbit", text: "reach orbit" },
  moon: { name: "Moon", text: "land on the Moon" },
};
const BONUS = { clouds: [20, 5], sky10: [40, 10], space: [150, 40], orbit: [400, 100], moon: [1000, 300] };

const BADGES = {
  liftoff: ["Liftoff", "Launch a rocket off the pad."],
  clouds: ["Above the Clouds", "Fly higher than 3 km."],
  space: ["Edge of Space", "Cross the Karman line, 100 km up."],
  orbit: ["Orbit", "Go fast enough sideways to fall around Earth."],
  moon: ["Moon Landing", "Land gently on the Moon."],
  staging: ["Staging Expert", "Reach space after dropping 2 or more stages."],
  feather: ["Featherweight", "Reach space with a rocket under 10 t at launch."],
  racer: ["Space Racer", "Win an online race to space."],
};
function badge(id) { const b = BADGES[id]; Kit.badge(ID, id, b[0], b[1]); }

// ======================================================================= facts (short, true, kid-friendly)

const FACTS = {
  newton: ["Newton's third law", "The engine pushes hot gas down, hard and fast. The gas pushes the rocket up just as hard. Every push has an equal push back the other way!"],
  twr: ["Thrust vs. weight", "To lift off, the engines must push up harder than gravity pulls down. That's why thrust-to-weight has to be more than 1."],
  drag: ["Air pushes back", "Moving fast through thick air makes drag, like wind pushing on your hand out of a car window. A pointy nose cone lets the air slide around."],
  clouds: ["Above the clouds!", "Low, puffy clouds are often only 1 to 3 km up. Most clouds are in the lowest layer of air, below about 12 km."],
  halfair: ["Half the air is below you", "Gravity holds air close to Earth, so it gets thinner as you go up. Air pressure here is only about half what it is on the ground."],
  jets: ["Jet height", "Passenger jets fly about 10 to 12 km up. Above here there's too little air for people to breathe without help."],
  lighter: ["Lighter = faster", "Your rocket has burned a lot of fuel, so it weighs less. The same push on less mass gives more acceleration: a = F / m."],
  sky: ["Why the sky gets dark", "The sky is blue because air scatters blue sunlight all around. With less air above you, there's less blue, so the sky turns dark."],
  noair: ["Almost no air", "More than 99.9% of all the air is below you now. In space there's almost no air, so there's nothing to breathe and almost no drag."],
  karman: ["The Karman line", "100 km up is the Karman line, a common boundary used for where space begins. You're an astronaut now!"],
  staging: ["Staging", "Dropping an empty stage means you stop carrying its heavy tanks and engines. With less mass, the fuel you have left can speed you up much more."],
  boosters: ["Boosters away", "Side boosters give an extra push when the rocket is heaviest, then drop off when they're empty so you don't carry them."],
  fins: ["Fins keep you straight", "Fins work like the feathers on an arrow: air pushes on them and turns the rocket back to point the way it's flying."],
  nofins: ["Wobbly without fins!", "Without fins, the air tries to flip the rocket around. Steer with A and D to balance it, or add fins."],
  turn: ["Tilting over", "Rockets go up first to get out of the thick air, then tilt over to go sideways. Getting to orbit is mostly about going sideways really fast!"],
  orbit: ["Orbit!", "Orbit means falling around Earth! You're going sideways so fast (about 7.8 km/s) that as you fall, Earth's curved surface falls away below you."],
  gravity: ["Gravity is still here", "Gravity gets weaker with distance, but in low orbit it's still about 90% as strong as on the ground. Astronauts float because they're falling around Earth together with their spaceship."],
  moonfar: ["Off to the Moon", "The Moon is about 384,000 km away. That's about 30 Earths lined up in a row! The trip takes about 3 days, and you coast almost all the way."],
  reentry: ["Re-entry", "Coming back, the capsule squeezes the air in front of it so hard that the air gets super hot. The heat shield protects you."],
  chute: ["Parachutes", "A parachute catches lots of air. That big drag slows the capsule down to a gentle landing speed."],
  moonland: ["No air on the Moon", "The Moon has no air, so parachutes can't work there. You have to slow down with your engine. Moon gravity is about 1/6 of Earth's."],
  breakup: ["Too much sideways!", "Flying sideways through thick air puts huge forces on a rocket. The capsule's escape motor pulled you to safety."],
};
let factQueue = [], factUntil = 0;
function fact(id, force) {
  const f = FACTS[id];
  if (!f) return;
  const seen = save.facts[id] || 0;
  if (!force && seen >= 3) return;
  save.facts[id] = seen + 1;
  if (factQueue.some((q) => q[0] === f[0])) return;
  factQueue.push(f);
}
function stepFacts() {
  const now = performance.now();
  const el = $("fact");
  if (now > factUntil) {
    const f = factQueue.shift();
    if (f) {
      el.querySelector("h3").textContent = f[0];
      el.querySelector("p").textContent = f[1];
      el.style.display = "block";
      factUntil = now + Math.max(6500, f[1].length * 60);
    } else el.style.display = "none";
  }
}
function clearFacts() { factQueue = []; factUntil = 0; $("fact").style.display = "none"; }

let bannerTimer = 0;
function banner(text, sub, ms) {
  const b = $("banner");
  b.innerHTML = esc(text) + (sub ? `<small>${esc(sub)}</small>` : "");
  b.style.display = "block";
  clearTimeout(bannerTimer);
  bannerTimer = setTimeout(() => { b.style.display = "none"; }, ms || 2600);
}
let msgTimer = 0;
function msg(text, ms) {
  const m = $("msg");
  m.textContent = text;
  m.style.display = "block";
  clearTimeout(msgTimer);
  msgTimer = setTimeout(() => { m.style.display = "none"; }, ms || 2600);
  Kit.sfx("hit");
}

// ======================================================================= 3D

const view3d = new Scene3D(me.avatar);
let design = cleanDesign(save.design || emptyDesign());
let selStage = design.stages.length - 1;
view3d.setRocket(design);

// ======================================================================= online

const net = Kit.net(ID, { room: "main" });
const slotOf = new Map();
function slotFor(id) {
  if (!slotOf.has(id)) {
    const used = new Set(slotOf.values());
    let s = 1;
    while (used.has(s)) s++;
    slotOf.set(id, s);
  }
  return slotOf.get(id);
}
net.on("leave", (p) => { view3d.removeRemote(p.id); slotOf.delete(p.id); refreshBoard(); });
net.on("join", () => { refreshBoard(); renderLab(); });
net.on("status", () => { refreshBoard(); renderLab(); document.body.classList.toggle("online", net.online); });
net.on("state", (p) => {
  const s = p.state || {};
  let d;
  try { d = cleanDesign(s.d); } catch (_) { return; }
  view3d.remote(p.id, {
    name: p.name, look: p.avatar, design: d, stage: Math.max(0, Math.min(d.stages.length - 1, s.s | 0)),
    capsule: !!s.c, chute: !!s.ch, slot: slotFor(p.id), x: +s.x || 0, alt: Math.max(0, +s.a || 0), tilt: +s.t || 0, flame: !!s.f,
  });
});
net.on("event", (p, e) => {
  if (!e || typeof e !== "object") return;
  if (e.t === "race" && net.players.has(p.id)) startRaceCountdown(e.id, Math.max(3, Math.min(15, +e.n || 10)), p.name);
  if (e.t === "win" && race && e.id === race.id && !race.winner) {
    race.winner = p.name;
    banner(`${p.name} reached space first!`, "Race over", 3500);
    Kit.sfx("score");
  }
});
let lastBoard = 0;
function refreshBoard() {
  const rows = [{ name: me.name, values: [kmText(save.best), save.flights], me: true }];
  for (const p of net.players.values()) {
    const s = p.state || {};
    rows.push({ name: p.name, values: [kmText((+s.b || 0) * 1000), +s.n || 0] });
  }
  rows.sort((a, b) => parseFloat(String(b.values[0]).replace(/,/g, "")) - parseFloat(String(a.values[0]).replace(/,/g, "")));
  Kit.leaderboard(["Best km", "Flights"], rows);
}
function kmText(m) {
  const km = m / 1000;
  return km < 100 ? km.toFixed(1) : Math.round(km).toLocaleString();
}

// ======================================================================= build screen

const SHOP_ORDER = ["nose", "fins", "tankS", "tankL", "tankH", "tankM", "engW", "engS", "engV", "engM", "boost", "stage"];
const ICON = {
  capsule: "linear-gradient(#d1d5db 0 60%, #9ca3af 60%)", nose: "linear-gradient(135deg, transparent 45%, #ef4444 45%)",
  fins: "linear-gradient(90deg, #ef4444 0 30%, #f1f5f9 30% 70%, #ef4444 70%)", tankS: "linear-gradient(#f1f5f9 0 55%, #fb923c 55% 72%, #f1f5f9 72%)",
  tankL: "linear-gradient(#f8fafc 0 60%, #3b82f6 60% 75%, #f8fafc 75%)", tankH: "linear-gradient(90deg, #1f2937 0 50%, #e5e7eb 50%)",
  tankM: "repeating-linear-gradient(90deg, #111827 0 8px, #f8fafc 8px 16px)", engW: "radial-gradient(circle at 50% 100%, #fb923c 0 30%, #4b5563 31%)",
  engS: "radial-gradient(circle at 50% 100%, #facc15 0 40%, #374151 41%)", engV: "radial-gradient(circle at 50% 100%, #93c5fd 0 35%, #9ca3af 36%)",
  engM: "radial-gradient(circle at 50% 100%, #f97316 0 50%, #1f2937 51%)", boost: "linear-gradient(90deg, #f8fafc 0 30%, transparent 30% 70%, #f8fafc 70%)",
  stage: "linear-gradient(#374151 0 40%, #facc15 40% 60%, #374151 60%)",
};
function partStat(k) {
  const p = PARTS[k];
  const t = (n) => (n < 10 ? n.toFixed(2).replace(/0$/, "") : n.toFixed(0)) + " t";
  switch (p.kind) {
    case "tank": return `${t(p.fuel)} fuel, ${t(p.dry)} empty`;
    case "engine": return `${p.tsl} kN on the ground, ${p.tvac} in space, ${t(p.mass)}`;
    case "boost": return `${p.tsl} kN, ${t(p.fuel)} fuel, ${t(p.dry)} empty`;
    default: return `${t(p.mass || 0)}`;
  }
}

function canUse(k) { return !!save.owned[k]; }
function unlocked(k) { const n = PARTS[k].need; return !n || !!save.goals[n]; }

function addPart(k) {
  const p = PARTS[k];
  if (!canUse(k)) return;
  const st = design.stages[selStage] || design.stages[0];
  switch (p.kind) {
    case "tank":
      if (st.tanks.length >= LIMITS.tanks) return msg(`A stage can hold ${LIMITS.tanks} tanks at most.`);
      st.tanks.push(k); break;
    case "engine":
      if (st.eng.length >= LIMITS.engines) return msg(`A stage can have ${LIMITS.engines} engines at most.`);
      st.eng.push(k); break;
    case "fins": st.fins = !st.fins; break;
    case "boost": design.stages[0].boost = !design.stages[0].boost; break;
    case "nose": design.nose = !design.nose; break;
    case "stage":
      if (design.stages.length >= LIMITS.stages) return msg(`${LIMITS.stages} stages is the most this pad can hold.`);
      design.stages.push({ eng: [], tanks: [], fins: false, boost: false });
      selStage = design.stages.length - 1;
      break;
  }
  Kit.sfx("click");
  designChanged();
}

function removePart(si, kind, idx) {
  const st = design.stages[si];
  if (!st) return;
  if (kind === "tank") st.tanks.splice(idx, 1);
  else if (kind === "eng") st.eng.splice(idx, 1);
  else if (kind === "fins") st.fins = false;
  else if (kind === "boost") st.boost = false;
  else if (kind === "nose") design.nose = false;
  else if (kind === "stage" && design.stages.length > 1) {
    design.stages.splice(si, 1);
    if (design.stages[0]) design.stages[0].boost = design.stages[0].boost || false;
    selStage = Math.min(selStage, design.stages.length - 1);
  }
  Kit.sfx("click");
  designChanged();
}

function designChanged() {
  design = cleanDesign(design);
  selStage = Math.max(0, Math.min(selStage, design.stages.length - 1));
  save.design = design;
  persist();
  view3d.setRocket(design);
  renderLab();
  renderShop();
}

function buy(k) {
  const p = PARTS[k];
  if (save.owned[k] || !unlocked(k)) return;
  if (save.coins < p.cost) return msg(`You need ${p.cost - save.coins} more coins.`);
  save.coins -= p.cost;
  save.owned[k] = 1;
  persist();
  Kit.sfx("coin");
  updateCoins();
  addPart(k);
}

function goalTip(s) {
  const g = save.goals;
  if (!g.clouds) return "Goal: fly above the clouds (3 km). Press Space or Launch!";
  if (!g.sky10) return "Goal: reach 10 km. A nose cone cuts drag; a big tank holds more fuel.";
  if (!g.space) return "Goal: reach space, 100 km up! A strong engine and more fuel help. Fly straight up.";
  if (!g.orbit) return "Goal: orbit. You need about 7.8 km/s sideways. Rockets need about 10 km/s of delta-v (speed budget) for that: use stages, and follow the yellow guide marker.";
  if (!g.moon) return "Goal: land on the Moon! From orbit it takes about 3.1 km/s more to reach the Moon and about 2.5 km/s to land: roughly 16 km/s in total. Real Moon rockets were huge, with several stages.";
  return "You've landed on the Moon! Try a lighter rocket, or race your friends to space.";
}

function renderLab() {
  if (mode !== "build" && mode !== "countdown") return;
  const s = stats(design);
  const twrClass = s.twr >= 1.2 ? "good" : s.twr > 1 ? "ok" : "bad";
  const tips = [];
  if (!s.ok) tips.push(["warn", "The bottom stage needs an engine (or boosters)!"]);
  else if (s.twr <= 1) tips.push(["warn", "Too heavy! Thrust is less than weight, so it can't lift off. Remove weight or add engines."]);
  else if (s.twr < 1.2) tips.push(["", "It will lift off slowly. More thrust or less mass gives more acceleration (a = F / m)."]);
  design.stages.forEach((st, i) => { if (i > 0 && !st.eng.length) tips.push(["warn", `Stage ${i + 1} has no engine, so it can't push.`]); });
  design.stages.forEach((st, i) => { if (i > 0 && !st.tanks.length) tips.push(["warn", `Stage ${i + 1} has no fuel tank.`]); });
  if (s.ok && !design.stages[0].fins) tips.push(["", "No fins: it will wobble. Steer with A / D to keep it straight."]);
  tips.push(["", goalTip(s)]);
  const km = (v) => (v / 1000).toFixed(v < 10000 ? 2 : 1);
  const stagesHtml = design.stages.map((st, i) => ({ st, i })).reverse().map(({ st, i }) => {
    const chips = [];
    const group = (list, kind) => {
      const seen = new Map();
      list.forEach((k, j) => { if (!seen.has(k)) seen.set(k, { n: 0, j }); const g = seen.get(k); g.n++; g.j = j; });
      for (const [k, g] of seen) chips.push(`<button class="chip" data-rm="${i}:${kind}:${g.j}" title="Click to remove one">${g.n > 1 ? g.n + " × " : ""}${esc(PARTS[k].name)} −</button>`);
    };
    group(st.eng, "eng");
    group(st.tanks, "tank");
    if (st.fins) chips.push(`<button class="chip" data-rm="${i}:fins:0" title="Click to remove">Fins −</button>`);
    if (st.boost) chips.push(`<button class="chip" data-rm="${i}:boost:0" title="Click to remove">Side boosters −</button>`);
    if (!chips.length) chips.push(`<span class="chip fixed">empty: add parts from the shop</span>`);
    const sd = s.stages[i] || { dv: 0, burn: 0 };
    return `<div class="stage ${i === selStage ? "sel" : ""}" data-sel="${i}">
      <div class="head"><span>Stage ${i + 1}${i === 0 ? " (fires first)" : ""}</span><i>${km(sd.dv)} km/s${design.stages.length > 1 ? ` <button class="xbtn" data-rm="${i}:stage:0" title="Remove stage">x</button>` : ""}</i></div>
      <div class="chips">${chips.join("")}</div></div>`;
  }).join("");
  const topChips = `<span class="chip fixed">Capsule (you)</span>${design.nose ? `<button class="chip" data-rm="0:nose:0" title="Click to remove">Nose cone −</button>` : ""}`;
  const raceBtn = net.online && net.players.size > 0
    ? (net.isHost ? `<button class="kit-btn orange" id="raceBtn" ${race && race.counting ? "disabled" : ""}>Start race</button>` : "")
    : "";
  $("lab").innerHTML = `
    <h2>Your rocket <small>${s.parts} parts</small></h2>
    <div class="stats">
      <span>Mass</span><b>${(s.mass / 1000).toFixed(1)} t</b>
      <span>Weight (mass x 9.8)</span><b>${(s.weight / 1000).toFixed(0)} kN</b>
      <span>Thrust at liftoff</span><b>${(s.thrust / 1000).toFixed(0)} kN</b>
      <span>Thrust / weight</span><b class="${twrClass}">${s.twr.toFixed(2)}</b>
      <span>Fuel</span><b>${(s.fuel / 1000).toFixed(1)} t</b>
      <span>Stage 1 burn time</span><b>${s.burn.toFixed(0)} s</b>
      <span>Delta-v (speed budget)</span><b>${km(s.dv)} km/s</b>
    </div>
    ${tips.map(([c, t]) => `<div class="tip ${c}">${esc(t)}</div>`).join("")}
    <div class="stage" style="cursor:default"><div class="head"><span>Top</span></div><div class="chips">${topChips}</div></div>
    ${stagesHtml}
    <div class="btnrow sticky"><button class="kit-btn" id="launchBtn" ${s.ok ? "" : "disabled"}>Launch!</button>
    <button class="kit-btn blue" id="clearBtn" title="Start over">Clear</button></div>
    ${raceBtn ? `<div class="btnrow">${raceBtn}</div>` : ""}`;
  placePanels();
}

function renderShop() {
  if (mode !== "build" && mode !== "countdown") return;
  const cards = SHOP_ORDER.map((k) => {
    const p = PARTS[k];
    let btn;
    if (save.owned[k]) {
      const toggle = { nose: design.nose, fins: !!(design.stages[selStage] || {}).fins, boost: design.stages[0].boost }[k];
      btn = toggle === undefined ? `<button data-add="${k}">Add</button>` : `<button data-add="${k}" class="${toggle ? "on" : ""}">${toggle ? "On" : "Add"}</button>`;
    } else if (unlocked(k)) {
      btn = `<button class="buy" data-buy="${k}" ${save.coins >= p.cost ? "" : "disabled"}>Buy ${p.cost}</button>`;
    } else {
      btn = `<button disabled>Locked</button>`;
    }
    const sub = !save.owned[k] && !unlocked(k) ? `Unlocks when you ${GOALS[p.need].text}.` : `${partStat(k)}. ${p.info}`;
    return `<div class="card ${save.owned[k] || unlocked(k) ? "" : "locked"}" title="${esc(p.info)}"><i class="ic" style="background:${ICON[k]}"></i><b>${esc(p.name)}</b>${btn}<small>${esc(sub)}</small></div>`;
  }).join("");
  $("shop").innerHTML = `<h2>Parts <small>adds to stage ${selStage + 1}</small></h2>${cards}`;
  placePanels();
}

$("lab").addEventListener("click", (e) => {
  const t = e.target.closest("button, .stage");
  if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
  if (!t) return;
  if (t.dataset.rm) { const [si, kind, idx] = t.dataset.rm.split(":"); removePart(+si, kind, +idx); return; }
  if (t.id === "launchBtn") return launch();
  if (t.id === "clearBtn") { design = emptyDesign(); design.stages[0].tanks = []; design.stages[0].eng = []; design.stages[0].fins = false; selStage = 0; designChanged(); return; }
  if (t.id === "raceBtn") return hostRace();
  if (t.dataset.sel !== undefined) { selStage = +t.dataset.sel; renderLab(); renderShop(); }
});
$("shop").addEventListener("click", (e) => {
  const b = e.target.closest("button");
  if (!b) return;
  b.blur();
  if (b.dataset.add) addPart(b.dataset.add);
  if (b.dataset.buy) buy(b.dataset.buy);
});

// Keep the left panels below the chat box and the right panel below the player list.
function placePanels() {
  const chat = document.querySelector(".kit-chat");
  let top = innerHeight < 560 ? 40 : 60;
  if (chat && !chat.hidden) top = Math.max(top, Math.min(innerHeight * 0.4, chat.getBoundingClientRect().bottom + 6));
  for (const id of ["lab", "fhud"]) { $(id).style.top = top + "px"; $(id).style.maxHeight = `calc(100vh - ${top + 12}px)`; }
  const board = document.querySelector(".kit-board");
  let rtop = innerHeight < 560 ? 40 : 60;
  if (board && !board.hidden) rtop = Math.max(rtop, board.getBoundingClientRect().bottom + 6);
  $("shop").style.top = rtop + "px";
  $("shop").style.maxHeight = `calc(100vh - ${rtop + 12}px)`;
}
addEventListener("resize", placePanels);

function updateCoins() {
  Kit.hud(`Coins ${save.coins.toLocaleString()}<small>Best ${kmText(save.best)} km - ${save.flights} flights</small>`);
}

// ======================================================================= modes

let mode = "build";
let flight = null;
let F = null;          // per-flight bookkeeping
let race = null;       // { id, counting, active, winner }
let autopilot = false; // testing helper (window.game.autopilot)
let countdown = 0;

function showBuildUI(on) {
  $("lab").style.display = on ? "block" : "none";
  $("shop").style.display = on ? "block" : "none";
  $("fhud").style.display = on ? "none" : "block";
  $("ladder").style.display = on ? "none" : "block";
  $("gaugeWrap").style.display = on ? "none" : "block";
  $("hint").style.display = on ? "none" : "block";
}

function launch(fromRace) {
  if (mode !== "build") return;
  const s = stats(design);
  if (!s.ok) return msg("Add an engine to the bottom stage first!");
  mode = "countdown";
  countdown = fromRace ? 0 : 3;
  if (!fromRace) {
    $("count").style.display = "flex";
    Kit.sfx("click");
  } else startFlight();
}

function startFlight() {
  mode = "flight";
  $("count").style.display = "none";
  clearFacts();
  design = cleanDesign(design);
  flight = new Flight(design, (Math.random() * 1e9) | 0);
  F = {
    orbit: false, transfer: false, milestones: {}, launchT: performance.now(), emptySince: 0, autoStageHint: false,
    aStart: null, outOfFuel: false, finishing: false, lastPuff: 0, stagedCount: 0, maxSideways: 0, landingTry: 0,
    lowerT: 0, raceFlight: !!(race && race.active),
  };
  view3d.clearDebris();
  view3d.setRocket(design);
  showBuildUI(false);
  Kit.sfx("jump");
  const s = stats(design);
  if (s.twr <= 1) fact("twr", true);
  if (!design.stages[0].fins) fact("nofins");
}

function hostRace() {
  if (!net.online || !net.isHost) return;
  const id = Math.random().toString(36).slice(2, 8);
  net.event({ t: "race", id, n: 10 });
  startRaceCountdown(id, 10, me.name);
}

function startRaceCountdown(id, n, host) {
  if (mode !== "build" && mode !== "results") {
    Kit.toast("Race starting!", `${host} started a race. Press R to get back to the pad and join it.`, "#f97316");
    race = { id, counting: true, joined: false, until: performance.now() + n * 1000, winner: null };
    return;
  }
  const ov = document.querySelector(".kit-overlay .kit-btn");
  if (ov) ov.click();
  race = { id, counting: true, joined: true, until: performance.now() + n * 1000, winner: null };
  banner("Race to space!", `First to 100 km wins. Get your rocket ready!`, 3000);
  Kit.sfx("score");
  renderLab();
}

function stepRace() {
  if (!race || !race.counting) return;
  const left = (race.until - performance.now()) / 1000;
  const c = $("count");
  if (race.joined && (mode === "build" || mode === "countdown")) {
    c.style.display = "flex";
    c.innerHTML = `${Math.max(1, Math.ceil(left))}<small>Race starts in</small>`;
  }
  if (left <= 0) {
    race.counting = false;
    if (race.joined && (mode === "build" || mode === "countdown")) {
      race.active = true;
      race.start = performance.now();
      c.style.display = "none";
      mode = "build";
      if (stats(design).ok) { launch(true); banner("GO!", "Race to 100 km", 1500); }
      else { msg("Your rocket has no engine, so it can't race!"); race.active = false; }
    }
  }
}

// ======================================================================= flight

function computeWarp() {
  const f = flight, h = f.alt;
  if (!f.lifted) return f.t > 3 ? 10 : 1;
  if (f.capsuleOnly) {
    if (f.chute) return h > 300 ? 40 : 4;
    return h > 30000 ? 10 : h > 8000 ? 5 : 2;
  }
  const thrusting = f.thrustNow > 0;
  if (thrusting) return h < 3000 ? 1 : h < 20000 ? 2 : h < 80000 ? 4 : F.orbit ? 20 : 10;
  if (F.orbit) return 60;
  return h < 3000 ? 1 : h < 20000 ? 3 : h < 150000 ? 12 : 40;
}

function steerInput() {
  let s = 0;
  if (Kit.key("KeyA") || Kit.key("ArrowLeft")) s -= 1;
  if (Kit.key("KeyD") || Kit.key("ArrowRight")) s += 1;
  return s;
}

function flightSpaceKey() {
  const f = flight;
  if (!f || f.landed || f.capsuleOnly) return;
  if (!f.engineOn) {
    const st = f.stage();
    if (st && st.fuel > 0) { f.engineOn = true; banner("Engine on!", F.orbit ? "Point forward (green marker) to speed up" : "", 1600); Kit.sfx("jump"); return; }
  }
  if (f.separate()) handleEvents();
  else if (f.s >= f.stages.length - 1) msg("This is your last stage.");
}

function handleEvents() {
  const f = flight;
  for (const e of f.events.splice(0)) {
    switch (e.type) {
      case "liftoff":
        banner("Liftoff!", "", 1600);
        badge("liftoff");
        fact("newton", save.flights < 2);
        Kit.sfx("score");
        break;
      case "boosters":
        view3d.dropDebris("boosters");
        fact("boosters");
        Kit.sfx("click");
        break;
      case "stage":
        view3d.dropDebris("stage", e.index);
        view3d.setRocket(design, { from: f.s });
        F.stagedCount++;
        F.emptySince = 0;
        banner(`Stage ${e.index + 1} away!`, "", 1400);
        fact("staging");
        Kit.sfx("hit");
        break;
      case "empty":
        if (!e.last) { F.emptySince = performance.now(); }
        else if (!F.outOfFuel) { F.outOfFuel = true; if (!F.orbit) banner("Out of fuel", "Coasting...", 1800); }
        break;
      case "capsule":
        if (view3d.rocket) {
          // the rest of the rocket falls away
          const old = view3d.rocket;
          const g = new THREE.Group();
          view3d.world.scene.add(g);
          old.stageGroups.forEach((sg) => { if (sg && sg.parent === old.group) g.attach(sg); });
          view3d.debris.push({ obj: g, t: 0, spin: 0.4, vy: 0 });
        }
        view3d.setRocket(design, { capsuleOnly: true });
        if (e.reason === "home") banner("Capsule separation", "Heading home", 1600);
        view3d.world.cam.dist = Math.max(view3d.world.cam.dist, 30);
        break;
      case "chute":
        view3d.setRocket(design, { capsuleOnly: true, chute: true });
        banner("Parachutes out!", "", 1500);
        fact("chute");
        Kit.sfx("jump");
        break;
      case "breakup":
        banner("Rocket broke apart!", "Your capsule escaped safely", 2600);
        fact("breakup", true);
        fact("fins");
        Kit.sfx("lose");
        F.shake = 1.2;
        break;
      case "landed":
        endFlight(e.speed);
        return;
    }
  }
}

function milestones() {
  const f = flight, h = f.alt, M = F.milestones;
  const once = (k, fn) => { if (!M[k]) { M[k] = true; fn(); } };
  if (f.lifted && h > 400 && f.speed > 120) once("drag", () => fact("drag"));
  if (h > 3000) once("clouds", () => { banner("Above the clouds!", "3 km", 2000); badge("clouds"); goal("clouds"); fact("clouds"); });
  if (h > 5500) once("halfair", () => fact("halfair"));
  if (h > 10000) once("sky10", () => { banner("10 km!", "Higher than most jets fly", 2000); goal("sky10"); fact("jets"); });
  if (h > 1500 && f.vSide > 60 && !f.capsuleOnly) once("turn", () => fact("turn"));
  if (h > 20000) once("sky", () => fact("sky"));
  if (h > 50000) once("noair", () => fact("noair"));
  if (h > KARMAN) once("space", () => {
    banner("EDGE OF SPACE!", "Karman line, 100 km", 3000);
    badge("space"); goal("space"); fact("karman", true);
    Kit.sfx("win");
    if (flight.launchMass < 10000) badge("feather");
    if (flight.stagesDropped >= 2) badge("staging");
    if (race && race.active && F.raceFlight && !race.winner) {
      race.winner = me.name;
      net.event({ t: "win", id: race.id });
      setTimeout(() => banner("You won the race!", "First to space", 3000), 3100);
      badge("racer");
    }
  });
  // a = F / m: show it once the first stage has burned half its fuel
  const st = f.stage();
  if (st && f.s === 0 && st.fuel0 > 0 && st.fuel / st.fuel0 < 0.5 && f.thrustNow > 0) once("lighter", () => fact("lighter"));
  // orbit: the lowest point of the path is above the air
  if (!F.orbit && h > KARMAN && !f.capsuleOnly) {
    const o = f.orbit();
    if (!o.escape && o.peri > KARMAN) {
      F.orbit = true;
      f.engineOn = false;
      goal("orbit");
      badge("orbit");
      banner("ORBIT!", `${(f.speed / 1000).toFixed(2)} km/s - you're falling around Earth`, 3500);
      fact("orbit", true);
      fact("gravity");
      Kit.sfx("win");
      setTimeout(() => { if (mode === "flight" && F.orbit) msg2("Engines off. Press Space to fire again and head for the Moon, or R to come home."); }, 4000);
    }
  }
  if (F.orbit && !F.transfer && !f.capsuleOnly) {
    const o = f.orbit();
    if (o.escape || o.apo >= MOON_DIST) {
      F.transfer = true;
      f.engineOn = false;
      startTransfer();
    }
  }
}

function msg2(text) {
  const m = $("msg");
  m.textContent = text;
  m.style.display = "block";
  m.style.background = "rgba(37, 99, 235, .92)";
  clearTimeout(msgTimer);
  msgTimer = setTimeout(() => { m.style.display = "none"; m.style.background = ""; }, 5000);
}

function goal(k) {
  if (save.goals[k]) return;
  save.goals[k] = 1;
  persist();
  const newParts = SHOP_ORDER.filter((p) => PARTS[p].need === k).map((p) => PARTS[p].name);
  if (newParts.length) F.unlocks = (F.unlocks || []).concat(newParts);
}

function stepFlight(dt) {
  const f = flight;
  let warp = computeWarp();
  let steer = steerInput();
  if (autopilot && f.lifted && !f.capsuleOnly) {
    const target = guideTilt(f, F.orbit);
    steer = Math.max(-1, Math.min(1, (target - f.tilt) * 4 - f.omega * 2));
  }
  if (autopilot && F.orbit && !f.engineOn && !F.transfer && !f.capsuleOnly) flightSpaceKey();
  if (steer && !autopilot) warp = Math.min(warp, 2);
  if (F.forceWarp) warp = F.forceWarp;
  F.warp = warp;
  const total = dt * warp;
  const steps = Math.min(600, Math.ceil(total / 0.02));
  const sub = total / steps;
  for (let i = 0; i < steps && mode === "flight"; i++) {
    f.step(sub, steer);
    if (f.events.length) handleEvents();
    if (mode !== "flight") return;
    if (autopilot && F.emptySince && f.s < f.stages.length - 1) { f.separate(); handleEvents(); }
    milestones();
    if (mode !== "flight") return;
  }
  // never lifted off and the fuel is gone: the flight is over
  if (!f.lifted && f.t > 1 && f.thrustNow === 0) { endFlight(); return; }
  // auto-stage a few seconds after a stage runs dry
  if (F.emptySince) {
    const st = f.stage();
    if (!st || st.fuel > 0 || f.capsuleOnly) F.emptySince = 0;
    else if (performance.now() - F.emptySince > 4500) { if (f.separate()) { handleEvents(); banner("Auto-staged", "Tip: press Space to stage", 1500); } F.emptySince = 0; }
  }
  // effects
  const st = f.stage();
  const [, pr] = air(f.alt);
  const engOn = f.thrustNow > 0 && !f.capsuleOnly;
  view3d.setFlames(f.s, engOn && st && st.fuel > 0, !!(st && st.boost && st.boost.fuel > 0 && f.engineOn), pr);
  if (engOn && f.alt < 6000 && view3d.rocket) {
    F.lastPuff += dt;
    const rate = f.alt < 30 ? 0.03 : 0.08;
    while (F.lastPuff > rate) {
      F.lastPuff -= rate;
      // smoke at the nozzle, in ground coordinates
      const base = new THREE.Vector3(0, -view3d.rocket.height / 2 - 2, 0);
      view3d.rocketRoot.localToWorld(base);
      view3d.ground.worldToLocal(base);
      const big = f.alt < 30;
      view3d.puff(base, big ? 6 + Math.random() * 6 : 3 + Math.random() * 3, big ? 3.5 : 2.2, big ? "#f1f5f9" : "#e5e7eb");
    }
  }
  const heat = f.capsuleOnly && f.alt < 90000 && f.alt > 15000 ? Math.max(0, Math.min(1, (f.speed - 1500) / 5000)) : 0;
  view3d.setHeat(heat);
  if (heat > 0.15) fact("reentry");
}

function endFlight(landSpeed) {
  if (mode !== "flight") return;
  mode = "results";
  const f = flight;
  const splash = f.downrange > 30000 || f.downrange < -40000;
  if (landSpeed !== undefined) banner(splash ? "Splashdown!" : "Touchdown!", `${landSpeed.toFixed(0)} m/s`, 1800);
  setTimeout(() => showResults({ kind: "earth" }), landSpeed !== undefined ? 1700 : 50);
}

// Ends the flight early (R): you still get coins for how high you got.
function comeHome() {
  if (mode === "flight") {
    if (F.orbit) banner("Coming home", "A small burn slows the capsule and it splashes down", 2000);
    mode = "results";
    setTimeout(() => showResults({ kind: F.orbit ? "orbit" : "earth" }), F.orbit ? 1800 : 50);
  } else if (mode === "landing") {
    mode = "results";
    showResults({ kind: "moonquit" });
  }
}

function showResults(r) {
  const f = flight;
  const maxAlt = r.kind === "moon" || r.kind === "flyby" ? MOON_DIST : f.maxAlt;
  save.flights++;
  const lines = [];
  let coins = Math.round(Math.min(1000, maxAlt / 1000));
  lines.push(`Highest point: ${kmText(maxAlt)} km`);
  lines.push(`Top speed: ${(f.maxSpeed / 1000).toFixed(2)} km/s (${Math.round(f.maxSpeed * 3.6).toLocaleString()} km/h)`);
  const got = [];
  for (const k of Object.keys(BONUS)) {
    const reached = k === "clouds" ? maxAlt > 3000 : k === "sky10" ? maxAlt > 10000 : k === "space" ? maxAlt > KARMAN : k === "orbit" ? F.orbit : r.kind === "moon";
    if (!reached) continue;
    const first = !save.goals["_paid_" + k];
    save.goals["_paid_" + k] = 1;
    const b = BONUS[k][first ? 0 : 1];
    coins += b;
    got.push(`${GOALS[k].name} +${b}${first ? " (first time!)" : ""}`);
  }
  if (r.kind === "flyby") { coins += 150; got.push("Moon flyby +150"); }
  save.coins += coins;
  if (maxAlt > save.best) save.best = maxAlt;
  persist();
  updateCoins();
  refreshBoard();
  Kit.finish(ID, Math.round(save.best / 100) / 10);
  lines.push(`Coins: +${coins}${got.length ? "  (" + got.join(", ") + ")" : ""}`);
  if (F.unlocks && F.unlocks.length) lines.push(`New parts in the shop: ${F.unlocks.join(", ")}!`);
  const title = r.kind === "moon" ? "You landed on the Moon!" : r.kind === "flyby" ? "Moon flyby" : F.orbit ? "Orbit mission complete" : maxAlt > KARMAN ? "You reached space!" : f.lifted ? "Flight complete" : "It didn't lift off";
  if (!f.lifted) lines.push("Thrust was less than weight. Remove some weight or add engines.");
  if (r.note) lines.unshift(r.note);
  Kit.sfx(maxAlt > KARMAN ? "win" : "coin");
  setTimeout(() => {
    Kit.overlay(title, lines.join("\n"), "Back to the lab").then(backToLab);
  }, 200);
}

function backToLab() {
  mode = "build";
  flight = null;
  F = null;
  view3d.clearDebris();
  view3d.setHeat(0);
  view3d.flag.visible = false;
  if (moonKid) { view3d.world.scene.remove(moonKid); moonKid = null; }
  view3d.setRocket(design);
  showBuildUI(true);
  clearFacts();
  $("transfer").style.display = "none";
  renderLab();
  renderShop();
  if (race && race.active) race.active = false;
}

// ======================================================================= Moon: transfer and landing

let transferT = 0, transferDur = 9;
function startTransfer() {
  mode = "transfer";
  transferT = 0;
  banner("Moon transfer!", "Engines off - coasting to the Moon", 2500);
  fact("moonfar", true);
  Kit.sfx("win");
  setTimeout(() => { if (mode === "transfer") $("transfer").style.display = "block"; }, 1200);
}

function drawTransfer(dt) {
  transferT += dt;
  const cv = $("tcanvas");
  const W = cv.width = cv.clientWidth, H = cv.height = cv.clientHeight;
  const g = cv.getContext("2d");
  g.fillStyle = "#02030a";
  g.fillRect(0, 0, W, H);
  let seed = 4;
  const r = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
  g.fillStyle = "#fff";
  for (let i = 0; i < 160; i++) g.fillRect(r() * W, r() * H, 1.5, 1.5);
  const ex = W * 0.16, ey = H * 0.58, mx = W * 0.84, my = H * 0.42;
  const er = Math.min(W, H) * 0.09, mr = er * 0.27;
  // path (not to scale)
  g.strokeStyle = "rgba(250,204,21,.6)";
  g.setLineDash([8, 8]);
  g.lineWidth = 3;
  g.beginPath();
  g.moveTo(ex + er + 10, ey);
  g.quadraticCurveTo(W * 0.5, H * 0.08, mx - mr - 8, my);
  g.stroke();
  g.setLineDash([]);
  // Earth (blocky) and Moon
  g.fillStyle = "#1f63c6"; g.beginPath(); g.arc(ex, ey, er, 0, 7); g.fill();
  g.fillStyle = "#3f9a3a"; g.fillRect(ex - er * 0.5, ey - er * 0.4, er * 0.5, er * 0.45); g.fillRect(ex + er * 0.1, ey + er * 0.1, er * 0.45, er * 0.35);
  g.fillStyle = "#a8a8a8"; g.beginPath(); g.arc(mx, my, mr, 0, 7); g.fill();
  g.fillStyle = "#8c8c8c"; g.fillRect(mx - mr * 0.4, my - mr * 0.3, mr * 0.35, mr * 0.3);
  // the capsule along the path
  const k = Math.min(1, transferT / transferDur);
  const t = k, x0 = ex + er + 10, y0 = ey, cx = W * 0.5, cy = H * 0.08, x1 = mx - mr - 8, y1 = my;
  const px = (1 - t) * (1 - t) * x0 + 2 * (1 - t) * t * cx + t * t * x1;
  const py = (1 - t) * (1 - t) * y0 + 2 * (1 - t) * t * cy + t * t * y1;
  g.fillStyle = "#e5e7eb"; g.fillRect(px - 6, py - 6, 12, 12);
  g.fillStyle = "#ef4444"; g.fillRect(px - 6, py - 10, 12, 4);
  g.fillStyle = "#fff";
  g.font = `800 ${Math.max(16, W / 40)}px "Noto Sans", "DejaVu Sans", sans-serif`;
  g.textAlign = "center";
  g.fillText(`Coasting to the Moon: day ${(k * 3).toFixed(1)} of about 3`, W / 2, H * 0.84);
  g.font = `600 ${Math.max(12, W / 70)}px "Noto Sans", "DejaVu Sans", sans-serif`;
  g.fillStyle = "#cbd5e1";
  g.fillText(`About ${Math.round(k * 384400).toLocaleString()} km of 384,400 km - no engine needed, you just coast. (Picture not to scale.)`, W / 2, H * 0.84 + Math.max(24, W / 45));
  g.fillText("Press Space to skip", W / 2, H * 0.95);
  if (transferT > transferDur + 0.6) arriveAtMoon();
}

let landing = null, moonKid = null;
const BRAKE_DV = 2450;   // about 2.5 km/s to slow down from the transfer for landing
function arriveAtMoon() {
  $("transfer").style.display = "none";
  const f = flight;
  const dvLeft = f.dvLeft();
  if (dvLeft < BRAKE_DV + 60) {
    mode = "results";
    showResults({ kind: "flyby", note: `You reached the Moon but only had ${(dvLeft / 1000).toFixed(2)} km/s of speed change left. Landing takes about 2.5 km/s to slow down, so you swung around the Moon and coasted home.` });
    return;
  }
  burnDv(f, BRAKE_DV);
  view3d.setRocket(design, { from: f.s });
  landing = { h: 1500, v: -55, start: { s: f.s, fuel: f.stages.map((s) => s.fuel) }, done: false, t: 0 };
  F.atMoon = true;
  mode = "landing";
  showBuildUI(false);
  fact("moonland", true);
  banner("Moon landing!", "Hold Space (or W) to fire the engine. Touch down slower than 4 m/s", 4000);
  view3d.world.cam.yaw = 0.35;
}

function stepLanding(dt) {
  const f = flight, L = landing;
  if (L.done) {
    L.t += dt;
    view3d.world.cam.yaw += dt * 0.25;
    if (moonKid) moonKid.userData.animate(dt, 0, false);
    return;
  }
  const burn = Kit.key("Space") || Kit.key("KeyW") || Kit.key("ArrowUp") || (autopilot && autoLand());
  let st = f.stage();
  if (st && st.fuel <= 0 && f.s < f.stages.length - 1) { f.separate(); f.events.length = 0; view3d.setRocket(design, { from: f.s }); st = f.stage(); }
  const steps = Math.ceil(dt / 0.01);
  let thrustOn = false;
  for (let i = 0; i < steps; i++) {
    const d = dt / steps;
    let a = -MOON_G;
    if (burn && st && st.fuel > 0 && st.engines.length) {
      const T = thrustOf(st.engines, 0), md = st.engines.reduce((s, e) => s + e.mdot, 0);
      a += T / f.mass();
      st.fuel = Math.max(0, st.fuel - md * d);
      thrustOn = true;
    }
    L.v += a * d;
    L.h += L.v * d;
    if (L.h <= 0) { L.h = 0; touchdown(-L.v); return; }
  }
  L.thrust = thrustOn;
  view3d.setFlames(f.s, thrustOn, false, 0, 1);
}

function autoLand() {
  // simple test autopilot: brake to keep the speed about a third of the height
  const L = landing, want = -Math.max(1.5, L.h / 12);
  return L.v < want;
}

function touchdown(speed) {
  const L = landing;
  view3d.setFlames(flight.s, false, false, 0);
  if (speed <= 4.5) {
    L.done = true;
    goal("moon");
    badge("moon");
    banner("The rocket has landed!", `Touchdown at ${speed.toFixed(1)} m/s on the Moon`, 4000);
    Kit.sfx("win");
    // step outside and plant a flag
    moonKid = view3d.world.character(me.avatar, me.name);
    view3d.moonGround.add(moonKid);
    moonKid.position.set(7, 0, 6);
    moonKid.rotation.y = Math.PI;
    view3d.flag.position.set(12, 0, 3);
    view3d.flag.visible = true;
    setTimeout(() => { if (mode === "landing") { mode = "results"; showResults({ kind: "moon", note: `Touchdown speed: ${speed.toFixed(1)} m/s. One small step!` }); } }, 6000);
  } else {
    L.tries = (L.tries || 0) + 1;
    banner("Too fast!", `${speed.toFixed(1)} m/s - the lander would tip over`, 2500);
    Kit.sfx("lose");
    setTimeout(() => {
      if (mode !== "landing") return;
      Kit.overlay("Crash landing", `You hit the ground at ${speed.toFixed(1)} m/s. Land slower than 4 m/s.\nTip: start braking early and let go when you're slow. Watch the fuel!`, "Try the landing again").then(() => {
        if (mode !== "landing") return;
        // rewind to the start of the descent
        const f = flight;
        f.s = L.start.s;
        f.stages.forEach((s, i) => { s.fuel = L.start.fuel[i]; });
        view3d.setRocket(design, { from: f.s });
        landing = { h: 1500, v: -55, start: L.start, done: false, t: 0, tries: L.tries };
      });
    }, 1200);
    L.done = true;
    L.crashed = true;
  }
}

// ======================================================================= HUD

function fmtKm(m) {
  if (m < 1000) return `${Math.max(0, m).toFixed(0)} m`;
  if (m < 100000) return `${(m / 1000).toFixed(2)} km`;
  return `${Math.round(m / 1000).toLocaleString()} km`;
}

function updateFlightHud() {
  const f = flight;
  if (mode === "landing") {
    const L = landing, st = f.stage();
    const fuel = st && st.fuel0 > 0 ? st.fuel / st.fuel0 : 0;
    const T = st ? thrustOf(st.engines, 0) : 0;
    $("fhud").innerHTML = `
      <div class="big">${fmtKm(L.h)}<small> above the Moon</small></div>
      <div class="row"><span>Falling speed</span><b class="${-L.v > 10 ? "bad" : -L.v > 4.5 ? "ok" : "good"}">${(-L.v).toFixed(1)} m/s</b></div>
      <div class="row"><span>Mass</span><b>${(f.mass() / 1000).toFixed(2)} t</b></div>
      <div class="row"><span>Thrust ÷ mass</span><b>${(T / f.mass()).toFixed(1)} m/s²</b></div>
      <div class="row"><span>Moon gravity</span><b>${MOON_G} m/s²</b></div>
      <div class="row"><span>Fuel</span><b>${(fuel * 100).toFixed(0)}%</b></div>
      <div class="bar"><i style="width:${(fuel * 100).toFixed(0)}%;background:${fuel > 0.25 ? "#22c55e" : "#ef4444"}"></i></div>`;
    $("hint").innerHTML = `Hold <b>Space</b> or <b>W</b> to fire the engine - land slower than <b>4 m/s</b> - <b>R</b> back to the lab`;
    $("gaugeWrap").style.display = "none";
    Kit.hud(`Coins ${save.coins.toLocaleString()}<small>Time x1</small>`);
    drawLadder(MOON_DIST);
    return;
  }
  const st = f.stage();
  const o = f.orbit();
  const fuel = st && st.fuel0 > 0 ? st.fuel / st.fuel0 : 0;
  const m = f.mass();
  const pushPerMass = f.thrustNow / m;
  let html = `
    <div class="big">${fmtKm(f.alt)}<small> up</small></div>
    <div class="row"><span>Speed</span><b>${f.speed < 1000 ? f.speed.toFixed(0) + " m/s" : (f.speed / 1000).toFixed(2) + " km/s"}</b></div>
    <div class="row"><span>Up / sideways</span><b>${Math.round(f.vUp) || 0} / ${Math.round(f.vSide) || 0} m/s</b></div>
    <div class="row"><span>Mass</span><b>${(m / 1000).toFixed(2)} t</b></div>
    <div class="row"><span>Thrust</span><b>${(f.thrustNow / 1000).toFixed(0)} kN</b></div>
    <div class="row"><span>Thrust ÷ mass</span><b>${pushPerMass.toFixed(1)} m/s²</b></div>
    <div class="row"><span>Gravity here</span><b>${((G0 * R_EARTH * R_EARTH) / (f.r * f.r)).toFixed(2)} m/s²</b></div>`;
  if (!f.capsuleOnly && st) {
    html += `<div class="row"><span>Stage ${f.s + 1} of ${f.stages.length} fuel</span><b>${(fuel * 100).toFixed(0)}%</b></div>
      <div class="bar"><i style="width:${(fuel * 100).toFixed(0)}%;background:${fuel > 0.25 ? "#22c55e" : "#ef4444"}"></i></div>`;
    if (st.boost) html += `<div class="row"><span>Boosters</span><b>${((st.boost.fuel / st.boost.fuel0) * 100).toFixed(0)}%</b></div>`;
  }
  if (f.alt > 20000 && !f.capsuleOnly) {
    const side = Math.max(0, f.vSide), need = Math.sqrt((G0 * R_EARTH * R_EARTH) / f.r);
    html += `<div class="row"><span>Sideways / orbit</span><b>${(side / 1000).toFixed(2)} / ${(need / 1000).toFixed(1)} km/s</b></div>
      <div class="bar side"><i style="width:${Math.min(100, (side / need) * 100).toFixed(0)}%"></i></div>`;
    html += `<div class="row"><span>Path's highest point</span><b>${o.escape ? "escape!" : fmtKm(o.apo)}</b></div>`;
    if (F.orbit) html += `<div class="row"><span>Path's lowest point</span><b>${fmtKm(o.peri)}</b></div>`;
  }
  if (F.orbit) html += `<div class="row"><span>Delta-v left</span><b>${(f.dvLeft() / 1000).toFixed(2)} km/s</b></div>`;
  $("fhud").innerHTML = html;
  let hint;
  if (!f.lifted && f.t > 2) hint = `Not enough thrust to lift off! Press <b>R</b> to rebuild.`;
  else if (F.orbit && !f.engineOn) hint = `In orbit! <b>Space</b> fire engine (Moon: point at the green marker until the path reaches the Moon) - <b>R</b> come home`;
  else if (F.emptySince) hint = `Stage empty! Press <b>Space</b> to drop it`;
  else if (f.capsuleOnly) hint = f.chute ? "Floating down under parachutes..." : "Capsule falling home - parachutes open low down";
  else hint = `<b>A / D</b> tilt - <b>Space</b> drop stage - <b>R</b> back to the lab - drag to look, wheel to zoom`;
  $("hint").innerHTML = hint;
  Kit.hud(`Coins ${save.coins.toLocaleString()}<small>Time x${F.warp || 1}${F.warp > 1 ? " (speeded up)" : ""}</small>`);
  drawGauge();
  drawLadder(f.maxAlt);
}

function drawGauge() {
  const f = flight;
  const cv = $("gauge"), g = cv.getContext("2d");
  const W = cv.width, H = cv.height, cx = W / 2, cy = H / 2, R = H / 2 - 8;
  g.clearRect(0, 0, W, H);
  g.fillStyle = "rgba(18,20,24,.75)";
  g.beginPath(); g.arc(cx, cy, R + 7, 0, Math.PI * 2); g.fill();
  g.strokeStyle = "#475569"; g.lineWidth = 2;
  g.beginPath(); g.arc(cx, cy, R, 0, Math.PI * 2); g.stroke();
  // up / sideways / down ticks
  g.fillStyle = "#94a3b8";
  for (let d = 0; d < 360; d += 45) {
    const a = (d * Math.PI) / 180;
    g.fillRect(cx + Math.sin(a) * (R - 4) - 1.5, cy - Math.cos(a) * (R - 4) - 1.5, 3, 3);
  }
  g.font = "800 9px sans-serif"; g.textAlign = "center"; g.fillStyle = "#cbd5e1";
  g.fillText("UP", cx, cy - R + 13);
  const mark = (a, color, len, w) => {
    g.strokeStyle = color; g.lineWidth = w;
    g.beginPath(); g.moveTo(cx + Math.sin(a) * (R - len), cy - Math.cos(a) * (R - len)); g.lineTo(cx + Math.sin(a) * (R + 6), cy - Math.cos(a) * (R + 6)); g.stroke();
  };
  const pro = f.speed > 20 ? Math.atan2(f.vSide, f.vUp) : 0;
  const guide = guideTilt(f, F.orbit);
  if (f.lifted && !f.capsuleOnly) { mark(guide, "#facc15", 14, 5); mark(pro, "#4ade80", 9, 4); }
  const t = f.tilt;
  g.save();
  g.translate(cx, cy);
  g.rotate(t);
  g.fillStyle = "#f8fafc"; g.fillRect(-4, -20, 8, 34);
  g.fillStyle = "#ef4444"; g.beginPath(); g.moveTo(-4, -20); g.lineTo(0, -29); g.lineTo(4, -20); g.fill();
  g.fillRect(-8, 6, 4, 8); g.fillRect(4, 6, 4, 8);
  g.restore();
  const deg = (r) => Math.round((r * 180) / Math.PI);
  $("gaugeText").innerHTML = f.capsuleOnly ? "" : `Tilt ${deg(t)}° - <b>orbit guide ${deg(guide)}°</b> - <em>flying ${deg(pro)}°</em>`;
}

// Height ladder with milestones and everyone's rockets. Scale: 0-10 km, 10-100 km, 100-1000 km, Moon.
function ladderY(h, top, bot) {
  const km = Math.max(0, h / 1000);
  let f;
  if (km <= 10) f = (km / 10) * 0.3;
  else if (km <= 100) f = 0.3 + ((km - 10) / 90) * 0.35;
  else if (km <= 1000) f = 0.65 + (Math.log10(km / 100)) * 0.2;
  else f = 0.85 + Math.min(1, Math.log10(km / 1000) / Math.log10(384.4)) * 0.15;
  return bot - f * (bot - top);
}
function drawLadder(myBest) {
  const cv = $("ladder"), g = cv.getContext("2d");
  const small = innerHeight < 560;
  if (cv.height !== (small ? 200 : 330)) { cv.height = small ? 200 : 330; cv.width = small ? 84 : 96; }
  const W = cv.width, H = cv.height, top = 14, bot = H - 12, x = small ? 24 : 30;
  g.clearRect(0, 0, W, H);
  g.fillStyle = "rgba(18,20,24,.72)";
  g.beginPath(); g.roundRect(0, 0, W, H, 10); g.fill();
  const grad = g.createLinearGradient(0, bot, 0, top);
  grad.addColorStop(0, "#8fd3ff"); grad.addColorStop(0.3, "#3b78d0"); grad.addColorStop(0.62, "#0d1d4a"); grad.addColorStop(1, "#000");
  g.fillStyle = grad;
  g.fillRect(x - 5, top, 10, bot - top);
  g.font = "700 9px sans-serif";
  g.textAlign = "left";
  const marks = [[3000, "Clouds"], [10000, "10 km"], [KARMAN, "Space"], [1000000, "1,000 km"], [MOON_DIST, "Moon"]];
  for (const [h, label] of marks) {
    const y = ladderY(h, top, bot);
    g.fillStyle = h === KARMAN ? "#facc15" : "#94a3b8";
    g.fillRect(x - 8, y, 16, h === KARMAN ? 2 : 1);
    g.fillText(label, x + 11, y + 3);
  }
  if (F && F.orbit) { g.fillStyle = "#4ade80"; g.fillText("ORBIT", x + 11, ladderY(160000, top, bot) + 3); }
  // others
  for (const p of net.players.values()) {
    const s = p.state || {};
    const y = ladderY(+s.a || 0, top, bot);
    g.fillStyle = (p.avatar && p.avatar.torso) || "#a855f7";
    g.fillRect(x - 14, y - 3, 7, 6);
  }
  // best this flight and me
  g.fillStyle = "rgba(250,204,21,.6)";
  g.fillRect(x - 7, ladderY(myBest, top, bot), 14, 1);
  const myAlt = mode === "landing" || mode === "transfer" ? MOON_DIST : flight ? flight.alt : 0;
  const y = ladderY(myAlt, top, bot);
  g.fillStyle = "#fff";
  g.beginPath(); g.moveTo(x - 6, y); g.lineTo(x - 14, y - 5); g.lineTo(x - 14, y + 5); g.fill();
}

// ======================================================================= keys

Kit.onKey((code) => {
  if (document.querySelector(".kit-overlay")) return;
  if (code === "Space") {
    if (mode === "build") launch();
    else if (mode === "flight") flightSpaceKey();
    else if (mode === "transfer") transferT = transferDur + 1;
  }
  if (code === "KeyR") {
    if (mode === "flight" || mode === "landing") {
      if (race && race.counting && !race.joined) { race.joined = true; mode = "results"; backToLab(); return; }
      comeHome();
    } else if (mode === "countdown") { mode = "build"; $("count").style.display = "none"; }
  }
});

// ======================================================================= main loop

let last = performance.now();
let slow = 0;
function frame(t) {
  requestAnimationFrame(frame);
  const dt = Math.max(0, Math.min(0.1, (t - last) / 1000));
  last = t;
  // lower the resolution on slow computers
  if (dt > 1 / 28) slow += dt; else slow = Math.max(0, slow - dt * 0.5);
  if (slow > 2) {
    slow = 0;
    const r = view3d.renderer;
    if (r.getPixelRatio() > 0.6) { r.setPixelRatio(Math.max(0.5, r.getPixelRatio() - 0.25)); r.setSize(innerWidth, innerHeight); }
    else if (r.shadowMap.enabled) { r.shadowMap.enabled = false; view3d.world.sun.castShadow = false; }
  }
  stepRace();
  let view;
  if (mode === "countdown" && countdown > 0) {
    countdown -= dt;
    const c = $("count");
    c.style.display = "flex";
    c.innerHTML = countdown > 0 ? `${Math.ceil(countdown)}` : "";
    if (countdown <= 0) startFlight();
  }
  if (mode === "flight") {
    stepFlight(dt);
  }
  if (mode === "transfer") drawTransfer(dt);
  if (mode === "landing") stepLanding(dt);
  if (mode === "results" && F && F.atMoon && landing) {
    view = { alt: landing.h, x: 0, tilt: 0, moon: true };
    view3d.world.cam.yaw += dt * 0.15;
  } else if ((mode === "flight" || mode === "results" || mode === "transfer") && flight) {
    view = { alt: Math.max(0, flight.alt), x: flight.downrange, tilt: flight.tilt, phi: flight.phi, shake: F && F.shake ? F.shake : 0 };
    if (F && F.shake) F.shake = Math.max(0, F.shake - dt);
    if (flight.lifted && flight.alt < 200 && flight.thrustNow > 0) view.shake = Math.max(view.shake, 0.5 * (1 - flight.alt / 200));
    if (mode === "flight") updateFlightHud();
  } else if (mode === "landing") {
    view = { alt: landing.h, x: 0, tilt: 0, moon: true };
    updateFlightHud();
  } else {
    view = { alt: 0, x: 0, tilt: 0, phi: 0 };
    view3d.setFlames(-1, false, false, 1);
  }
  if (mode === "build") view3d.world.cam.yaw += dt * 0.05;
  view3d.stepDebris(dt, flight ? Math.min(40, flight.accel) : 0);
  view3d.stepSmoke(dt);
  view3d.render(view, dt);
  stepFacts();
  shareState();
  if (t - lastBoard > 1000) { lastBoard = t; refreshBoard(); placePanels(); }
}

function shareState() {
  if (!net.online) return;
  let s;
  if (flight && (mode === "flight" || mode === "results")) {
    s = { x: Math.round(flight.downrange), a: Math.round(Math.max(0, flight.alt)), t: +flight.tilt.toFixed(2), f: flight.thrustNow > 0 ? 1 : 0, s: flight.s, c: flight.capsuleOnly ? 1 : 0, ch: flight.chute ? 1 : 0 };
  } else if (mode === "landing" || mode === "transfer") {
    s = { x: 0, a: MOON_DIST, t: 0, f: 0, s: flight ? flight.s : 0, c: 0, ch: 0 };
  } else {
    s = { x: 0, a: 0, t: 0, f: 0, s: 0, c: 0, ch: 0 };
  }
  s.d = design;
  s.b = +(save.best / 1000).toFixed(1);
  s.n = save.flights;
  net.state(s);
}

// ======================================================================= start

window.game = {
  get mode() { return mode; }, get flight() { return flight; }, get F() { return F; }, get save() { return save; },
  get design() { return design; }, get landing() { return landing; }, get race() { return race; }, net, view3d,
  setDesign(d) { design = cleanDesign(d); selStage = design.stages.length - 1; designChanged(); },
  launch, stage: flightSpaceKey, comeHome, stats: () => stats(design),
  give(c) { save.coins += c; persist(); updateCoins(); renderShop(); },
  unlockAll() { for (const k of Object.keys(PARTS)) save.owned[k] = 1; persist(); renderShop(); },
  set autopilot(v) { autopilot = !!v; }, get autopilot() { return autopilot; },
  warp(w) { if (F) F.forceWarp = w; },
  hostRace,
};

updateCoins();
showBuildUI(true);
renderLab();
renderShop();
refreshBoard();
requestAnimationFrame(frame);
const firstTime = save.flights === 0;
Kit.overlay("Rocket Lab", firstTime
  ? "Build a rocket from blocks and fly it to the clouds, to space, into orbit and all the way to the Moon!\nClick parts in the shop to add them. Watch thrust / weight: it must be more than 1 to lift off.\nSpace launches and drops empty stages. A / D tilt the rocket. R brings you back to the lab."
  : `Welcome back! Your best flight: ${kmText(save.best)} km.\nSpace launch / stage - A / D tilt - R back to the lab`, firstTime ? "Let's build!" : "To the lab").then(() => { renderLab(); });
