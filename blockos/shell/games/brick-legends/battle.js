/* Brick Legends: side-view turn-based battles. */
"use strict";

let B = null;

const PARTY_POS = [[770, 300], [835, 342], [900, 384]];
function enemySlots(n) {
  return [
    [[250, 345]],
    [[320, 305], [170, 360]],
    [[340, 290], [185, 305], [300, 378]],
    [[350, 282], [205, 288], [330, 380], [175, 384]],
  ][Math.min(4, n) - 1];
}

function ust(u) { return u.isEnemy ? u : stats(u.m); }
function alive(u) { return u.isEnemy ? !u.dead && u.hp > 0 : u.m.hp > 0; }
function maxHpOf(u) { return u.isEnemy ? u.maxHp : stats(u.m).maxHp; }
function maxMpOf(u) { return u.isEnemy ? 999 : stats(u.m).maxMp; }
function unitH(u) { return u.isEnemy ? (ART_H[u.d.art] || 8) * u.s : 74; }

function makeEnemy(kind) {
  const d = ENEMIES[kind];
  return {
    isEnemy: true, kind, d, name: d.name, hp: d.hp, maxHp: d.hp,
    atk: d.atk, def: d.def, mag: d.mag, spd: d.spd,
    st: {}, ox: 0, oy: 0, flash: 0, alpha: 1, dead: false, turns: 0,
    s: d.boss ? (kind === "king" ? 15 : kind === "king2" ? 17 : 13.5) : d.big ? 9.5 : 8,
  };
}
function makePartyUnit(m, i) {
  return {
    isEnemy: false, m, st: {}, ox: 0, oy: 0, flash: 0, alpha: 1, swing: 0,
    x: PARTY_POS[i][0], y: PARTY_POS[i][1],
    get name() { return memberName(m); },
    get hp() { return m.hp; }, set hp(v) { m.hp = v; },
    get mp() { return m.mp; }, set mp(v) { m.mp = v; },
  };
}

// Starts a battle and resolves with "win", "lose" or "run".
function startBattle(group, o) {
  o = o || {};
  const enemies = group.map(makeEnemy);
  const counts = {};
  enemies.forEach((e) => (counts[e.name] = (counts[e.name] || 0) + 1));
  const seen = {};
  enemies.forEach((e) => { if (counts[e.name] > 1) { seen[e.name] = (seen[e.name] || 0) + 1; e.name += " " + "ABCD"[seen[e.name] - 1]; } });
  const slots = o.boss ? [[240, 380]] : enemySlots(enemies.length);
  enemies.forEach((e, i) => { e.x = slots[i][0]; e.y = slots[i][1]; });
  B = {
    enemies, party: G.s.party.map(makePartyUnit), round: 0, queue: [], active: null,
    msg: "", nums: [], fx: [], shake: 0, flashScreen: 0, bg: o.bg || "fields", boss: !!o.boss, o,
    targeting: null, results: null, result: null, intro: 1,
  };
  G.scene = "battle";
  Music.play(o.boss ? "boss" : "battle");
  return runBattle();
}

function bmsg(text, ms) { B.msg = fmt(text); return wait(ms === undefined ? 750 : ms); }

async function runBattle() {
  await anim(450, (p) => { B.intro = 1 - p; });
  const names = B.enemies.map((e) => e.name);
  await bmsg(B.boss ? `${names[0]} blocks the way!` : names.length === 1 ? `${names[0]} appears!` : `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]} appear!`, 900);
  for (;;) {
    B.round++;
    B.queue = turnOrder(true);
    while (B.queue.length) {
      const u = B.queue.shift();
      if (!alive(u)) continue;
      await doTurn(u);
      if (B.transform) await transformBoss();
      const r = outcome();
      if (r) return finish(r);
      if (B.result === "run") return finish("run");
    }
  }
}
function turnOrder(random) {
  return [...B.party, ...B.enemies].filter(alive)
    .map((u) => ({ u, k: ust(u).spd * (random ? 0.85 + Math.random() * 0.3 : 1) + (u.isEnemy ? 0 : 0.01) }))
    .sort((a, b) => b.k - a.k).map((o) => o.u);
}
function outcome() {
  if (B.enemies.every((e) => !alive(e))) return "win";
  if (B.party.every((u) => !alive(u))) return "lose";
  return null;
}

async function doTurn(u) {
  B.active = u;
  u.defending = false;
  if (u.st.sleep) {
    u.st.sleep--;
    if (u.st.sleep <= 0) { delete u.st.sleep; await bmsg(`${u.name} wakes up!`, 600); }
    else { await bmsg(`${u.name} is fast asleep...`, 650); await endOfTurn(u); B.active = null; return; }
  }
  if (u.isEnemy) {
    u.turns++;
    await performEnemy(u, enemyAI(u));
    if (u.d.ai === "king2" && alive(u) && u.hp < u.maxHp * 0.3 && outcome() === null) {
      await bmsg("The Hollow King moves again in a frenzy!", 650);
      await performEnemy(u, enemyAI(u));
    }
  } else {
    B.msg = `${u.name}'s turn`;
    const act = await playerChoose(u);
    await performParty(u, act);
  }
  await endOfTurn(u);
  B.active = null;
}

async function endOfTurn(u) {
  if (!alive(u)) return;
  if (u.st.poison) {
    const d = Math.max(1, Math.floor(maxHpOf(u) * (u.isEnemy && u.d.boss ? 0.03 : 0.07)));
    addFx("poison", u);
    await damage(u, d, { color: "#c084fc" });
    await bmsg(`${u.name} takes ${d} poison damage.`, 550);
    u.st.poison--;
    if (u.st.poison <= 0) delete u.st.poison;
  }
  if (u.st.shield) { u.st.shield--; if (u.st.shield <= 0) delete u.st.shield; }
}

// ------------------------------------------------------------------ player input
function playerChoose(u) {
  return new Promise((resolve) => {
    const wins = [];
    const open = (w) => { wins.push(w); pushUI(w); return w; };
    const done = (act) => { wins.forEach(closeUI); B.targeting = null; resolve(act); };
    const back = (w) => { closeUI(w); wins.splice(wins.indexOf(w), 1); };
    const cmds = [
      { label: "Attack", id: "attack" },
      { label: "Skills", id: "skills" },
      { label: "Items", id: "items" },
      { label: "Defend", id: "defend" },
      { label: "Run", id: "run", disabled: B.boss },
    ];
    open(makeList({
      x: 14, y: 410, w: 190, rowH: 29, size: 17, items: cmds,
      onPick: async (it) => {
        if (it.id === "attack") {
          const t = await chooseTarget("enemy", u);
          if (t) done({ type: "attack", targets: t });
        } else if (it.id === "defend") done({ type: "defend" });
        else if (it.id === "run") done({ type: "run" });
        else if (it.id === "skills") {
          const list = skillsOf(u.m).map((id) => {
            const sk = SKILLS[id];
            return { label: sk.name, right: sk.mp + " MP", disabled: u.m.mp < sk.mp, data: id, el: sk.el };
          });
          const w = open(makeList({
            x: 214, y: 150, w: 360, rows: Math.min(8, list.length), items: list, title: `${u.name}'s skills  (MP ${u.m.mp})`,
            help: (it) => it && SKILLS[it.data].desc, helpY: 102, helpX: 214, helpW: 520,
            onCancel: (w) => back(w),
            onPick: async (it) => {
              const sk = SKILLS[it.data];
              const t = await chooseTarget(sk.target, u);
              if (t) done({ type: "skill", id: it.data, targets: t });
            },
          }));
          w.o.after = (ctx) => list.slice(w.scroll, w.scroll + w.rows()).forEach((it, i) => { if (it.el) elIcon(ctx, it.el, 214 + 360 - 92, 150 + 38 + i * 30 + 15, 7); });
        } else if (it.id === "items") {
          const items = () => Object.keys(G.s.items).filter((id) => ITEMS[id] && !ITEMS[id].key && itemCount(id) > 0)
            .map((id) => ({ label: ITEMS[id].name, right: "x" + itemCount(id), data: id }));
          open(makeList({
            x: 214, y: 150, w: 360, rows: 8, items, title: "Items", empty: "No items",
            help: (it) => it && ITEMS[it.data].desc, helpY: 102, helpX: 214, helpW: 520,
            onCancel: (w) => back(w),
            onPick: async (it) => {
              const use = ITEMS[it.data].use;
              const kind = use === "bomb" ? "enemies" : use === "revive" ? "ko" : "ally";
              const t = await chooseTarget(kind, u);
              if (t) done({ type: "item", id: it.data, targets: t });
            },
          }));
        }
      },
    }));
  });
}

// kind: enemy | enemies | ally | allies | ko | self
function chooseTarget(kind, u) {
  return new Promise((resolve) => {
    let list;
    if (kind === "self") return resolve([u]);
    if (kind === "enemy" || kind === "enemies") list = B.enemies.filter(alive);
    else if (kind === "ko") list = B.party.filter((p) => !alive(p));
    else list = B.party.filter(alive);
    if (!list.length) { Music.sfx("buzz"); bmsg(kind === "ko" ? "Nobody needs reviving." : "No target.", 0); return resolve(null); }
    const all = kind === "enemies" || kind === "allies";
    const t = { list, sel: kind === "ally" ? Math.max(0, list.indexOf(u)) : 0, all };
    B.targeting = t;
    const w = {
      key(k) {
        if (k === "ok") { Kit.sfx("click"); end(all ? list : [list[t.sel]]); }
        else if (k === "back") { Kit.sfx("click"); end(null); }
        else if (!all && ["up", "down", "left", "right"].includes(k)) {
          const d = k === "up" || k === "left" ? -1 : 1;
          t.sel = (t.sel + d + list.length) % list.length;
          Kit.sfx("click");
        }
      },
      draw(ctx) {
        list.forEach((v, i) => {
          const h = unitH(v);
          hit(v.x - 50, v.y - h - 10, 100, h + 20, () => { t.sel = i; w.key("ok"); }, () => { t.sel = i; });
        });
        txt(ctx, all ? "Confirm: Enter   Back: X" : "Choose a target   Back: X", 214 + 20, 396, { size: 13, color: "#cbd5e1" });
      },
    };
    function end(v) { closeUI(w); B.targeting = null; resolve(v); }
    pushUI(w);
  });
}

// ------------------------------------------------------------------ actions
function retarget(targets, enemySide) {
  const pool = enemySide ? B.enemies : B.party;
  const live = targets.filter(alive);
  if (live.length) return live;
  const any = pool.filter(alive);
  return any.length ? [Kit.pick(any)] : [];
}
function elMult(t, el) {
  if (!el || !t.isEnemy) return 1;
  const kn = (G.s.known[t.kind] = G.s.known[t.kind] || {});
  if (t.d.weak.includes(el)) { kn[el] = "weak"; return 1.75; }
  if ((t.d.resist || []).includes(el)) { kn[el] = "resist"; return 0.5; }
  kn[el] = "normal";
  return 1;
}
function calcDamage(a, t, power, kind, el) {
  const A = ust(a), D = ust(t);
  let d;
  if (kind === "phys") d = A.atk * power * 60 / (60 + D.def);
  else {
    const mdef = t.isEnemy ? D.def * 0.6 + D.mag * 0.2 : (D.def + D.mag) * 0.5;
    d = A.mag * power * 60 / (60 + mdef);
  }
  d *= 0.9 + Math.random() * 0.2;
  let crit = false;
  if (kind === "phys" && Math.random() < 0.07) { d *= 1.5; crit = true; }
  const em = elMult(t, el);
  d *= em;
  if (t.defending) d *= 0.5;
  if (t.st.shield) d *= 0.5;
  return { d: Math.max(1, Math.round(d)), crit, weak: em > 1, resist: em < 1 };
}
function addNum(u, text, color, big) {
  B.nums.push({ x: u.x + u.ox + (Math.random() * 20 - 10), y: u.y - unitH(u) * 0.6, text: String(text), color, t: 0, big });
}
function addFx(kind, u, extra) {
  B.fx.push(Object.assign({ kind, x: u.x + u.ox, y: u.y, h: unitH(u), t: 0, d: 0.6, seed: Math.random() * 1000 }, extra || {}));
}
async function damage(t, d, o) {
  o = o || {};
  t.hp = Math.max(0, t.hp - d);
  addNum(t, d, o.color || (t.isEnemy ? "#fff" : "#fca5a5"), o.crit || o.weak);
  if (o.weak) addNum(t, "WEAK!", EL_COLOR[o.el] || "#facc15");
  if (o.resist) addNum(t, "resist", "#94a3b8");
  t.flash = 0.3;
  if (t.st.sleep && Math.random() < 0.5) { delete t.st.sleep; addNum(t, "awake", "#93c5fd"); }
  if (t.hp <= 0) await knockOut(t);
}
async function knockOut(t) {
  t.st = {};
  if (t.isEnemy) {
    if (t.d.ai === "king") { t.hp = 1; B.transform = t; return; }
    t.dead = true;
    addFx("burst", t, { col: t.d.col[0], d: 0.8 });
    Kit.sfx("score");
    anim(450, (p) => { t.alpha = 1 - p; });
    G.s.kills[t.kind] = (G.s.kills[t.kind] || 0) + 1;
    for (const q in QUESTS) {
      const Q = QUESTS[q], st = G.s.quests[q];
      if (Q.type === "kill" && Q.target === t.kind && st && st.state === "active") st.count = Math.min(Q.need, (st.count || 0) + 1);
    }
  } else {
    Kit.sfx("lose");
    B.msgKO = `${t.name} is knocked out!`;
  }
}
function heal(t, amt, color) {
  const max = maxHpOf(t);
  const before = t.hp;
  t.hp = Math.min(max, t.hp + amt);
  addNum(t, "+" + (t.hp - before), color || "#4ade80");
}
async function lunge(u, target) {
  const dir = u.isEnemy ? 1 : -1;
  const dist = u.isEnemy ? 90 : 120;
  await anim(150, (p) => { u.ox = dir * dist * p; u.swing = p * 1.6; });
  addFx("slash", target);
  Kit.sfx("hit");
  B.shake = 0.15;
}
async function lungeBack(u) {
  const o = u.ox;
  await anim(170, (p) => { u.ox = o * (1 - p); u.swing = 1.6 * (1 - p); });
  u.ox = 0; u.swing = 0;
}
async function castGlow(u, col) {
  u.glow = col;
  Music.sfx("magic");
  await anim(300, (p) => { u.oy = -Math.sin(p * Math.PI) * 10; });
  u.glow = null;
}
function fxFor(el, fallback) { return el || fallback; }

async function performParty(u, act) {
  if (act.type === "defend") { u.defending = true; addFx("shield", u, { col: "#94a3b8" }); await bmsg(`${u.name} is defending.`, 550); return; }
  if (act.type === "run") {
    const ps = Math.max(...B.party.filter(alive).map((p) => ust(p).spd));
    const es = Math.max(...B.enemies.filter(alive).map((e) => e.spd));
    const chance = Kit.clamp(0.55 + (ps - es) * 0.03, 0.25, 0.95);
    if (Math.random() < chance) { Kit.sfx("jump"); B.result = "run"; await bmsg("Got away safely!", 700); }
    else await bmsg("Couldn't get away!", 650);
    return;
  }
  if (act.type === "attack") {
    const [t] = retarget(act.targets, true);
    if (!t) return;
    B.msg = `${u.name} attacks!`;
    await lunge(u, t);
    const r = calcDamage(u, t, 1, "phys");
    await damage(t, r.d, { crit: r.crit });
    if (r.crit) await bmsg("A critical hit!", 350);
    await lungeBack(u);
    await wait(250);
    return;
  }
  if (act.type === "item") {
    const it = ITEMS[act.id];
    takeItem(act.id);
    B.msg = `${u.name} uses ${it.name}.`;
    Music.sfx("heal");
    await castGlow(u, "#fde68a");
    if (it.use === "bomb") {
      const ts = B.enemies.filter(alive);
      ts.forEach((t) => addFx(it.el, t));
      await wait(250);
      for (const t of ts) {
        const em = elMult(t, it.el);
        await damage(t, Math.max(1, Math.round(it.amt * em * (0.9 + Math.random() * 0.2))), { weak: em > 1, resist: em < 1, el: it.el });
      }
    } else {
      const t = act.targets[0];
      if (it.use === "revive") {
        if (alive(t)) { await bmsg("It has no effect.", 500); return; }
        t.hp = 1; heal(t, Math.floor(maxHpOf(t) / 2)); addFx("heal", t);
      } else if (!alive(t)) { await bmsg("It has no effect.", 500); return; }
      else if (it.use === "heal") { heal(t, it.amt); addFx("heal", t); }
      else if (it.use === "mp") { const b = t.mp; t.mp = Math.min(maxMpOf(t), t.mp + it.amt); addNum(t, "+" + (t.mp - b) + " MP", "#60a5fa"); addFx("heal", t, { col: "#60a5fa" }); }
      else if (it.use === "elixir") { heal(t, 9999); t.mp = maxMpOf(t); addFx("heal", t); }
      else if (it.use === "cure") { it.status.forEach((s) => delete t.st[s]); addNum(t, "cured", "#a7f3d0"); addFx("heal", t, { col: "#a7f3d0" }); }
    }
    await wait(500);
    return;
  }
  if (act.type === "skill") {
    const sk = SKILLS[act.id];
    if (u.m.mp < sk.mp) { await bmsg("Not enough MP!", 500); return; }
    u.m.mp -= sk.mp;
    B.msg = `${u.name}: ${sk.name}!`;
    if (sk.kind === "phys") {
      const ts = retarget(act.targets, true);
      if (sk.target === "enemies") {
        await castGlow(u, sk.el ? EL_COLOR[sk.el] : "#fff");
        for (const t of ts) {
          addFx(fxFor(sk.el, "slash"), t);
          Kit.sfx("hit");
          const r = calcDamage(u, t, sk.power, "phys", sk.el);
          await damage(t, r.d, { crit: r.crit, weak: r.weak, resist: r.resist, el: sk.el });
          await wait(120);
        }
      } else {
        const t = ts[0];
        if (!t) return;
        await lunge(u, t);
        if (sk.el) addFx(sk.el, t);
        const r = calcDamage(u, t, sk.power, "phys", sk.el);
        await damage(t, r.d, { crit: r.crit, weak: r.weak, resist: r.resist, el: sk.el });
        await lungeBack(u);
      }
      B.shake = 0.2;
      await wait(300);
    } else if (sk.kind === "mag") {
      const ts = sk.target === "enemies" ? B.enemies.filter(alive) : retarget(act.targets, true);
      await castGlow(u, sk.el ? EL_COLOR[sk.el] : "#e9d5ff");
      ts.forEach((t) => addFx(fxFor(sk.el, act.id === "meteor" ? "meteor" : "holy"), t));
      if (sk.el === "thunder") { Music.sfx("thunder"); B.flashScreen = 0.25; }
      await wait(350);
      for (const t of ts) {
        const r = calcDamage(u, t, sk.power, "mag", sk.el);
        await damage(t, r.d, { weak: r.weak, resist: r.resist, el: sk.el });
      }
      B.shake = 0.2;
      await wait(400);
    } else if (sk.kind === "status") {
      await castGlow(u, "#93c5fd");
      const ts = B.enemies.filter(alive);
      for (const t of ts) {
        addFx("spores", t, { col: "#93c5fd" });
        if (!t.d.boss && Math.random() < sk.chance) { t.st.sleep = Kit.randInt(2, 3); addNum(t, "sleep", "#93c5fd"); }
        else addNum(t, "miss", "#94a3b8");
      }
      await wait(600);
    } else if (sk.kind === "heal") {
      await castGlow(u, "#4ade80");
      const ts = sk.target === "allies" ? B.party.filter(alive) : act.targets.filter(alive);
      Music.sfx("heal");
      for (const t of ts) { addFx("heal", t); heal(t, Math.round(ust(u).mag * sk.power + 10)); }
      await wait(600);
    } else if (sk.kind === "cure") {
      await castGlow(u, "#a7f3d0");
      const t = act.targets[0];
      delete t.st.poison; delete t.st.sleep;
      addFx("heal", t, { col: "#a7f3d0" }); addNum(t, "cured", "#a7f3d0");
      await wait(500);
    } else if (sk.kind === "shield") {
      await castGlow(u, "#38bdf8");
      const ts = sk.target === "allies" ? B.party.filter(alive) : act.targets;
      for (const t of ts) { t.st.shield = 3; addFx("shield", t); addNum(t, "shield", "#7dd3fc"); }
      await wait(600);
    } else if (sk.kind === "revive") {
      await castGlow(u, "#fde68a");
      const t = act.targets[0];
      if (alive(t)) { await bmsg("It has no effect.", 500); return; }
      t.hp = 1; heal(t, Math.floor(maxHpOf(t) / 2)); addFx("heal", t);
      Music.sfx("heal");
      await wait(600);
    }
  }
}

// ------------------------------------------------------------------ enemies
const BOSS_AI = {
  treant(u) {
    if (u.hp < u.maxHp * 0.5 && !u.healed) { u.healed = true; return "photosynth"; }
    const r = Math.random();
    return r < 0.2 ? "rootbind" : r < 0.42 ? "sporecloud" : "attack";
  },
  wyrm(u) {
    if (u.turns % 4 === 0 && !u.st.shield) return "burrow";
    const r = Math.random();
    return r < 0.35 ? "sandstorm" : r < 0.65 ? "tailwhip" : "attack";
  },
  colossus(u) {
    const r = Math.random();
    return r < 0.3 ? "frostbreath" : r < 0.6 ? "frostfist" : r < 0.75 ? "freeze" : "attack";
  },
  king(u) {
    const r = Math.random();
    const poisoned = B.party.some((p) => p.st.poison);
    if (r < 0.15 && !poisoned) return "curse";
    return r < 0.5 ? "shadowbolt" : r < 0.8 ? "darkwave" : "attack";
  },
  king2(u) {
    const r = Math.random();
    return r < 0.35 ? "voidbreath" : r < 0.65 ? "crush" : r < 0.8 ? "darkwave" : "attack";
  },
};
function enemyAI(u) {
  if (u.d.ai) return BOSS_AI[u.d.ai](u);
  const sk = u.d.skills || [];
  let total = 2;
  sk.forEach(([, w]) => (total += w));
  let r = Math.random() * total;
  for (const [id, w] of sk) { r -= w; if (r < 0) return id; }
  return "attack";
}
function pickTarget() {
  const live = B.party.filter(alive);
  // Slightly prefer the hero up front.
  return Math.random() < 0.15 ? live[0] : Kit.pick(live);
}
async function tryStatus(t, status, chance) {
  const imm = !t.isEnemy && stats(t.m).immune.includes(status);
  if (imm) { addNum(t, "immune", "#e2e8f0"); return; }
  if (Math.random() < chance) {
    if (status === "sleep") { t.st.sleep = Kit.randInt(2, 3); addNum(t, "sleep", "#93c5fd"); }
    else if (status === "poison") { t.st.poison = 5; addNum(t, "poison", "#c084fc"); }
  } else addNum(t, "miss", "#94a3b8");
}
async function performEnemy(u, id) {
  if (!B.party.some(alive)) return;
  if (id === "attack") {
    const t = pickTarget();
    B.msg = `${u.name} attacks!`;
    await lunge(u, t);
    const r = calcDamage(u, t, 1, "phys");
    await damage(t, r.d, { crit: r.crit });
    await lungeBack(u);
    await afterKO();
    await wait(200);
    return;
  }
  const sk = ESKILLS[id];
  B.msg = `${u.name}: ${sk.name}!`;
  if (sk.type === "healself") {
    await castGlow(u, "#4ade80");
    addFx("heal", u);
    const before = u.hp;
    u.hp = Math.min(u.maxHp, u.hp + Math.round(u.maxHp * sk.amt));
    addNum(u, "+" + (u.hp - before), "#4ade80");
    await wait(600);
    return;
  }
  if (sk.type === "shieldself") {
    await castGlow(u, "#e9c46a");
    u.st.shield = 2;
    addFx("shield", u, { col: "#e9c46a" });
    await bmsg(`${u.name} hides under the sand. Damage is halved!`, 800);
    return;
  }
  const targets = sk.all ? B.party.filter(alive) : [pickTarget()];
  if (sk.type === "phys") {
    if (sk.all) {
      await castGlow(u, "#fca5a5");
      B.shake = 0.3;
      for (const t of targets) {
        addFx(sk.el || "slash", t);
        const r = calcDamage(u, t, sk.power, "phys", sk.el);
        await damage(t, r.d, { crit: r.crit });
        if (sk.status && alive(t)) await tryStatus(t, sk.status, sk.chance);
        await wait(100);
      }
    } else {
      const t = targets[0];
      await lunge(u, t);
      if (sk.el) addFx(sk.el, t);
      const r = calcDamage(u, t, sk.power, "phys", sk.el);
      await damage(t, r.d, { crit: r.crit });
      if (sk.status && alive(t)) await tryStatus(t, sk.status, sk.chance);
      await lungeBack(u);
    }
  } else if (sk.type === "mag") {
    await castGlow(u, sk.el ? EL_COLOR[sk.el] : "#c084fc");
    targets.forEach((t) => addFx(sk.fx || sk.el || "dark", t));
    await wait(350);
    for (const t of targets) {
      const r = calcDamage(u, t, sk.power, "mag", sk.el);
      await damage(t, r.d, {});
      if (sk.drain) { const b = u.hp; u.hp = Math.min(u.maxHp, u.hp + Math.round(r.d / 2)); addNum(u, "+" + (u.hp - b), "#4ade80"); }
    }
    B.shake = 0.25;
  } else if (sk.type === "status") {
    await castGlow(u, sk.status === "sleep" ? "#93c5fd" : "#c084fc");
    for (const t of targets) { addFx(sk.fx || (sk.status === "sleep" ? "spores" : "poison"), t, { col: sk.status === "sleep" ? "#93c5fd" : "#c084fc" }); await tryStatus(t, sk.status, sk.chance); }
  }
  await afterKO();
  await wait(450);
}
async function afterKO() {
  if (B.msgKO) { const m = B.msgKO; B.msgKO = null; await bmsg(m, 650); }
}

async function transformBoss() {
  const u = B.transform;
  B.transform = null;
  B.transforming = true;
  await bmsg("The Hollow King: Enough! You will face my true form!", 1400);
  Music.sfx("thunder");
  await anim(700, (p) => { B.flashScreen = p; u.alpha = 1 - p; });
  const d = ENEMIES.king2;
  Object.assign(u, { kind: "king2", d, name: d.name, hp: d.hp, maxHp: d.hp, atk: d.atk, def: d.def, mag: d.mag, spd: d.spd, st: {}, s: 17, turns: 0 });
  await anim(700, (p) => { B.flashScreen = 1 - p; u.alpha = p; });
  B.transforming = false;
  B.flashScreen = 0;
  B.shake = 0.6;
  await bmsg("The Hollow King Unbound rises, wreathed in shadow!", 1200);
}

// ------------------------------------------------------------------ end of battle
async function finish(r) {
  B.active = null;
  B.party.forEach((p) => { p.st = {}; p.defending = false; });
  B.msg = "";
  if (r === "win") {
    Music.stop();
    Kit.sfx("win");
    let xp = 0, gold = 0;
    const found = [];
    for (const e of B.enemies) {
      xp += e.d.xp; gold += e.d.gold;
      for (const [id, ch] of e.d.drops || []) if (Math.random() < ch) { addItem(id); found.push(ITEMS[id].name); }
    }
    G.s.gold += gold;
    G.s.wins = (G.s.wins || 0) + 1;
    const lines = [`Gained ${xp} XP and ${gold} gold.`];
    if (found.length) lines.push("Found: " + found.join(", ") + ".");
    const ups = [];
    for (const u of B.party) {
      if (u.m.hp <= 0) u.m.hp = 1;
      ups.push(...gainXp(u.m, xp));
    }
    for (const up of ups) {
      lines.push(`${up.name} reached level ${up.level}!` + (up.learned.length ? ` Learned ${up.learned.join(", ")}.` : ""));
    }
    B.results = { title: "Victory!", lines };
    await wait(300);
    if (ups.length) Music.sfx("level");
    await waitConfirm();
    B.results = null;
    badge("first_win");
    if (hero().level >= 10) badge("level10");
  } else if (r === "lose") {
    Music.stop();
    await bmsg("The party has fallen...", 1300);
  }
  const res = r;
  B = null;
  return res;
}
function waitConfirm() {
  return new Promise((resolve) => {
    const opened = performance.now();
    const w = {
      key(k) { if ((k === "ok" || k === "back") && performance.now() - opened > 400 / G.fast) { Kit.sfx("click"); closeUI(w); resolve(); } },
      draw() { hit(0, 0, VW, VH, () => w.key("ok")); },
    };
    pushUI(w);
  });
}

// ------------------------------------------------------------------ drawing
function drawBattleBg(ctx, bg) {
  const T = G.T;
  const sky = {
    fields: ["#60a5fa", "#dbeafe"], forest: ["#14532d", "#4d7c0f"], desert: ["#f97316", "#fde68a"],
    snow: ["#93c5fd", "#f1f5f9"], dark: ["#2e1065", "#7e22ce"], castle: ["#0f0a1a", "#2a2238"],
  }[bg] || ["#60a5fa", "#dbeafe"];
  const g = ctx.createLinearGradient(0, 0, 0, 260);
  g.addColorStop(0, sky[0]); g.addColorStop(1, sky[1]);
  ctx.fillStyle = g; ctx.fillRect(0, 0, VW, 260);
  const groundC = { fields: "#5bb450", forest: "#2f7a3a", desert: "#e9c46a", snow: "#eef3f8", dark: "#3d3548", castle: "#433d52" }[bg];
  if (bg === "fields") {
    ctx.fillStyle = "#fff"; [[120, 60], [520, 40], [800, 80]].forEach(([x, y], i) => { const xx = (x + T * 6 * (i + 1)) % 1060 - 100; Kit.brick(ctx, xx, y, 90, 22, "rgba(255,255,255,.9)", 10); Kit.brick(ctx, xx + 20, y - 14, 50, 20, "rgba(255,255,255,.9)", 10); });
    ctx.fillStyle = "#4a9a44"; for (let i = 0; i < 6; i++) Kit.brick(ctx, i * 180 - 40, 190 - (i % 2) * 30, 220, 90, i % 2 ? "#4a9a44" : "#3f8f3c", 30);
  } else if (bg === "forest") {
    for (let i = 0; i < 14; i++) { const x = i * 72 + (i % 3) * 12; ctx.fillStyle = "#0f3d1e"; ctx.fillRect(x, 0, 26, 260); Kit.brick(ctx, x - 30, 40 + (i % 4) * 20, 86, 70, i % 2 ? "#14532d" : "#166534", 12); }
    ctx.fillStyle = "rgba(250,250,210,.12)"; for (let i = 0; i < 4; i++) { ctx.beginPath(); ctx.moveTo(150 + i * 220, 0); ctx.lineTo(210 + i * 220, 0); ctx.lineTo(260 + i * 220, 260); ctx.lineTo(180 + i * 220, 260); ctx.fill(); }
  } else if (bg === "desert") {
    ctx.fillStyle = "#fef3c7"; ctx.beginPath(); ctx.arc(760, 70, 40, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#e0a54a"; for (let i = 0; i < 5; i++) Kit.brick(ctx, i * 230 - 60, 200 - (i % 2) * 24, 300, 80, i % 2 ? "#e0a54a" : "#d4943c", 40);
    ctx.fillStyle = "#b8904a"; Kit.brick(ctx, 380, 120, 120, 110, "#c9a15a", 4); Kit.brick(ctx, 405, 95, 70, 30, "#c9a15a", 4);
  } else if (bg === "snow") {
    for (let i = 0; i < 6; i++) { const x = i * 190 - 40; ctx.fillStyle = "#94a3b8"; ctx.beginPath(); ctx.moveTo(x, 250); ctx.lineTo(x + 110, 70 + (i % 2) * 40); ctx.lineTo(x + 220, 250); ctx.fill(); ctx.fillStyle = "#f8fafc"; ctx.beginPath(); ctx.moveTo(x + 80, 120 + (i % 2) * 30); ctx.lineTo(x + 110, 70 + (i % 2) * 40); ctx.lineTo(x + 140, 120 + (i % 2) * 30); ctx.fill(); }
    ctx.fillStyle = "rgba(255,255,255,.8)"; for (let i = 0; i < 40; i++) { const x = (i * 97 + T * 20) % VW, y = (i * 53 + T * 40) % 400; ctx.fillRect(x, y, 3, 3); }
  } else if (bg === "dark") {
    ctx.fillStyle = "#e9d5ff"; ctx.beginPath(); ctx.arc(160, 70, 32, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#1e0b3a"; for (let i = 0; i < 9; i++) { const x = i * 120 - 30; ctx.beginPath(); ctx.moveTo(x, 260); ctx.lineTo(x + 40, 120 + (i % 3) * 30); ctx.lineTo(x + 70, 160); ctx.lineTo(x + 110, 100 + (i % 2) * 40); ctx.lineTo(x + 150, 260); ctx.fill(); }
  } else if (bg === "castle") {
    ctx.fillStyle = "#211d2b"; ctx.fillRect(0, 0, VW, 260);
    ctx.fillStyle = "#2d2839"; for (let r = 0; r < 13; r++) for (let k = -1; k < 31; k++) ctx.fillRect(k * 32 + (r % 2) * 16 + 1, r * 20 + 1, 30, 18);
    for (let i = 0; i < 5; i++) { const x = 60 + i * 210; Kit.brick(ctx, x, 20, 50, 240, "#4b4560", 4); const f = Math.sin(T * 10 + i) * 3; ctx.fillStyle = "#fb923c"; ctx.fillRect(x + 100, 90 - f, 14, 22 + f); ctx.fillStyle = "#fde047"; ctx.fillRect(x + 104, 98, 6, 10); }
    if (B && B.boss) { ctx.fillStyle = `rgba(124,58,237,${0.15 + 0.08 * Math.sin(T * 2)})`; ctx.fillRect(0, 0, VW, 400); }
  }
  // ground
  ctx.fillStyle = groundC; ctx.fillRect(0, 240, VW, 165);
  ctx.fillStyle = "rgba(0,0,0,.12)"; ctx.fillRect(0, 240, VW, 6);
  const snowy = bg === "snow";
  for (let r = 0; r < 5; r++) {
    const y = 262 + r * 30, sz = 4 + r * 1.2;
    ctx.fillStyle = snowy ? "rgba(140,170,200,.25)" : "rgba(255,255,255,.08)";
    for (let x = (r % 2) * 24; x < VW; x += 48) { ctx.beginPath(); ctx.ellipse(x, y, sz * 1.6, sz * 0.7, 0, 0, Math.PI * 2); ctx.fill(); }
  }
  if (bg === "castle") { ctx.fillStyle = "#9f1239"; ctx.fillRect(0, 300, VW, 60); ctx.fillStyle = "#facc15"; ctx.fillRect(0, 300, VW, 3); ctx.fillRect(0, 357, VW, 3); }
}

function drawFx(ctx, f) {
  const p = f.t / f.d;
  const top = f.y - f.h;
  const rnd = (i) => { const v = Math.sin(f.seed + i * 12.9898) * 43758.5453; return v - Math.floor(v); };
  ctx.save();
  switch (f.kind) {
    case "slash": {
      ctx.strokeStyle = `rgba(255,255,255,${1 - p})`; ctx.lineWidth = 5;
      ctx.beginPath(); ctx.moveTo(f.x - 30 + p * 10, top + 10); ctx.lineTo(f.x + 30 - p * 10, f.y - 10); ctx.stroke();
      ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(f.x + 25, top + 15); ctx.lineTo(f.x - 20, f.y - 20); ctx.stroke();
      break;
    }
    case "fire": {
      for (let i = 0; i < 14; i++) {
        const x = f.x + (rnd(i) - 0.5) * 60, y = f.y - p * (40 + rnd(i + 3) * f.h);
        const s = 12 * (1 - p) + 4;
        ctx.fillStyle = i % 3 ? "#fb923c" : "#fde047"; ctx.globalAlpha = 1 - p * 0.8;
        ctx.fillRect(x - s / 2, y - s / 2, s, s);
      }
      break;
    }
    case "ice": {
      for (let i = 0; i < 8; i++) {
        const x = f.x + (rnd(i) - 0.5) * 70, y = top + (f.h) * Math.min(1, p * 1.6) * rnd(i + 5);
        ctx.fillStyle = i % 2 ? "#67e8f9" : "#e0f2fe"; ctx.globalAlpha = 1 - Math.max(0, p - 0.6) * 2.5;
        ctx.beginPath(); ctx.moveTo(x, y - 14); ctx.lineTo(x + 7, y); ctx.lineTo(x, y + 14); ctx.lineTo(x - 7, y); ctx.fill();
      }
      break;
    }
    case "thunder": {
      ctx.strokeStyle = p < 0.5 || Math.floor(p * 20) % 2 ? "#fde047" : "#fff"; ctx.lineWidth = 6; ctx.globalAlpha = 1 - p;
      ctx.beginPath(); let x = f.x + 10, y = 0; ctx.moveTo(x, y);
      for (let i = 1; i <= 7; i++) { x = f.x + (rnd(i) - 0.5) * 50; y = (f.y - f.h * 0.4) * i / 7; ctx.lineTo(x, y); }
      ctx.stroke();
      ctx.fillStyle = "rgba(253,224,71,.5)"; ctx.beginPath(); ctx.arc(f.x, f.y - f.h * 0.4, 30 * (1 - p) + 10, 0, Math.PI * 2); ctx.fill();
      break;
    }
    case "heal": {
      ctx.globalAlpha = 1 - p;
      for (let i = 0; i < 10; i++) {
        const x = f.x + (rnd(i) - 0.5) * 60, y = f.y - p * 80 - rnd(i + 2) * f.h * 0.8;
        ctx.fillStyle = f.col || "#4ade80"; ctx.fillRect(x - 2, y - 6, 4, 12); ctx.fillRect(x - 6, y - 2, 12, 4);
      }
      break;
    }
    case "shield": {
      ctx.strokeStyle = f.col || "#38bdf8"; ctx.lineWidth = 4; ctx.globalAlpha = 1 - p;
      ctx.beginPath(); ctx.ellipse(f.x, f.y - f.h / 2, 30 + p * 20, f.h / 2 + 10 + p * 20, 0, 0, Math.PI * 2); ctx.stroke();
      break;
    }
    case "poison": case "spores": case "leaf": case "sand": case "dark": {
      const col = f.col || { poison: "#c084fc", spores: "#fde68a", leaf: "#4ade80", sand: "#e9c46a", dark: "#7c3aed" }[f.kind];
      ctx.fillStyle = col; ctx.globalAlpha = 1 - p;
      for (let i = 0; i < 12; i++) {
        const a = rnd(i) * Math.PI * 2 + p * 3, r = 10 + p * 40 * rnd(i + 1);
        const x = f.x + Math.cos(a) * r, y = f.y - f.h / 2 + Math.sin(a) * r - p * 20;
        const s = f.kind === "dark" ? 10 : 7;
        ctx.fillRect(x - s / 2, y - s / 2, s, s);
      }
      break;
    }
    case "holy": {
      ctx.globalAlpha = 1 - p;
      ctx.fillStyle = "#fef9c3";
      ctx.fillRect(f.x - 16 + p * 8, 0, 32 - p * 16, f.y);
      ctx.fillStyle = "rgba(255,255,255,.6)"; ctx.beginPath(); ctx.arc(f.x, f.y - f.h / 2, 40 * p + 10, 0, Math.PI * 2); ctx.fill();
      break;
    }
    case "meteor": {
      for (let i = 0; i < 6; i++) {
        const q = Math.min(1, p * 1.8 - rnd(i) * 0.6);
        if (q <= 0) continue;
        const x = f.x + (rnd(i + 9) - 0.5) * 80 - (1 - q) * 120, y = f.y - f.h * 0.3 - (1 - q) * 300;
        Kit.brick(ctx, x - 12, y - 12, 24, 24, ["#ef4444", "#facc15", "#3b82f6", "#22c55e"][i % 4], 5);
      }
      break;
    }
    case "burst": {
      for (let i = 0; i < 16; i++) {
        const a = rnd(i) * Math.PI * 2, r = p * (50 + rnd(i + 4) * 50);
        ctx.globalAlpha = 1 - p;
        Kit.brick(ctx, f.x + Math.cos(a) * r - 6, f.y - f.h / 2 + Math.sin(a) * r - 6 + p * p * 40, 12, 12, i % 2 ? f.col : "#fff", 3);
      }
      break;
    }
  }
  ctx.restore();
}

function drawTurnBar(ctx) {
  panel(ctx, 8, 6, VW - 16, 40, { top: "#0f172a", bottom: "#0b1220" });
  txt(ctx, "TURN", 22, 32, { size: 13, color: "#94a3b8" });
  const cur = B.active && alive(B.active) ? [B.active] : [];
  const now = cur.concat(B.queue.filter(alive));
  const next = turnOrder(false);
  let x = 70;
  const chip = (u, highlight, faded) => {
    ctx.font = `bold 13px ${FONT}`;
    let name = u.name;
    while (ctx.measureText(name).width > 92 && name.length > 3) name = name.slice(0, -1);
    if (name !== u.name) name = name.trim() + ".";
    const w = Math.max(56, ctx.measureText(name).width + 16);
    if (x + w > VW - 20) return false;
    ctx.globalAlpha = faded ? 0.5 : 1;
    ctx.fillStyle = u.isEnemy ? "#7f1d1d" : MEMBER_COLOR[u.m.id];
    ctx.beginPath(); ctx.roundRect(x, 14, w, 24, 6); ctx.fill();
    if (highlight) { ctx.strokeStyle = "#facc15"; ctx.lineWidth = 3; ctx.stroke(); }
    txt(ctx, name, x + w / 2, 31, { size: 13, align: "center" });
    ctx.globalAlpha = 1;
    x += w + 6;
    return true;
  };
  for (let i = 0; i < now.length; i++) if (!chip(now[i], i === 0 && cur.length, false)) return;
  if (x < VW - 120) { txt(ctx, "next", x + 4, 31, { size: 12, color: "#94a3b8" }); x += 38; }
  for (const u of next) if (!chip(u, false, true)) return;
}

function drawBattle(ctx) {
  ctx.save();
  if (B.shake > 0) ctx.translate((Math.random() - 0.5) * 12 * B.shake / 0.3, (Math.random() - 0.5) * 8 * B.shake / 0.3);
  drawBattleBg(ctx, B.bg);
  const T = G.T;
  // enemies (back to front)
  const es = B.enemies.slice().sort((a, b) => a.y - b.y);
  for (const e of es) {
    if (e.alpha <= 0.01) continue;
    ctx.save();
    ctx.globalAlpha = e.alpha;
    if (e.glow) { ctx.shadowColor = e.glow; ctx.shadowBlur = 30; }
    if (e.flash > 0 && Math.floor(e.flash * 30) % 2 === 0) ctx.filter = "brightness(3)";
    drawMonster(ctx, e.d.art, e.d.col, e.x + e.ox + (e.flash > 0 ? Math.sin(e.flash * 80) * 4 : 0), e.y + e.oy, e.s, T + e.x, { boss: e.d.boss, crown: e.d.crown });
    ctx.restore();
    if (!alive(e)) continue;
    const h = unitH(e);
    // status + known weaknesses above the head
    let sx = e.x - 34;
    for (const st of ["poison", "sleep", "shield"]) if (e.st[st]) { statusIcon(ctx, st, sx, e.y - h - 30); sx += 38; }
    const kn = G.s.known[e.kind] || {};
    let wx = e.x - 8;
    for (const el of ELEMENTS) if (kn[el] === "weak") { elIcon(ctx, el, wx, e.y + 14, 7); wx += 18; }
    if (e.st.sleep) txt(ctx, "z Z", e.x + 30, e.y - h + Math.sin(T * 3) * 4, { size: 18, color: "#bfdbfe" });
  }
  // party
  B.party.forEach((u, i) => {
    const isActive = B.active === u && !u.isEnemy;
    const x = u.x + u.ox - (isActive ? 26 : 0), y = u.y + u.oy;
    ctx.save();
    if (u.glow) { ctx.shadowColor = u.glow; ctx.shadowBlur = 25; }
    if (u.flash > 0 && Math.floor(u.flash * 30) % 2 === 0) ctx.filter = "brightness(2.5)";
    const id = u.m.id;
    drawFighter(ctx, memberLook(u.m), x + (u.flash > 0 ? Math.sin(u.flash * 80) * 4 : 0), y, 74, {
      ko: !alive(u), weapon: id === "hero" ? "sword" : "staff", orb: id === "nova" ? "#c084fc" : "#86efac", swing: u.swing,
      walk: isActive ? Math.sin(T * 6) * 0.25 : 0,
    });
    ctx.restore();
    if (u.defending) statusIcon(ctx, "defend", x - 17, y - 104);
    if (u.st.shield) { ctx.strokeStyle = `rgba(56,189,248,${0.5 + 0.2 * Math.sin(T * 4)})`; ctx.lineWidth = 3; ctx.beginPath(); ctx.ellipse(x, y - 38, 34, 50, 0, 0, Math.PI * 2); ctx.stroke(); }
    if (u.st.sleep && alive(u)) txt(ctx, "z Z", x - 30, y - 82 + Math.sin(T * 3) * 4, { size: 18, color: "#bfdbfe" });
    if (u.st.poison && alive(u)) { ctx.fillStyle = "#c084fc"; for (let k = 0; k < 3; k++) ctx.fillRect(x - 12 + k * 10, y - 90 - ((T * 30 + k * 10) % 20), 5, 5); }
    if (isActive && !B.targeting) downArrow(ctx, x, y - 92, T, "#fde047");
  });
  // targeting cursor
  if (B.targeting) {
    const t = B.targeting;
    const list = t.all ? t.list : [t.list[t.sel]];
    for (const v of list) downArrow(ctx, v.x + v.ox, v.y - unitH(v) - 12, T);
    const v = t.list[t.sel];
    if (v && v.isEnemy && !t.all) drawEnemyInfo(ctx, v);
  }
  B.fx.forEach((f) => drawFx(ctx, f));
  for (const n of B.nums) {
    const a = n.t < 0.7 ? 1 : 1 - (n.t - 0.7) / 0.3;
    ctx.globalAlpha = Math.max(0, a);
    const bounce = n.t < 0.2 ? -Math.sin(n.t / 0.2 * Math.PI) * 14 : 0;
    txt(ctx, n.text, n.x, n.y - n.t * 30 + bounce, { size: n.big ? 30 : 24, align: "center", color: n.color });
    ctx.globalAlpha = 1;
  }
  ctx.restore();
  if (B.flashScreen > 0) { ctx.fillStyle = `rgba(255,255,255,${Math.min(1, B.flashScreen)})`; ctx.fillRect(0, 0, VW, VH); }
  drawTurnBar(ctx);
  if (B.msg) {
    ctx.font = `bold 17px ${FONT}`;
    const w = Math.min(VW - 40, ctx.measureText(B.msg).width + 50);
    panel(ctx, VW / 2 - w / 2, 54, w, 40, { top: "#0f172a", bottom: "#0b1220", border: "#94a3b8" });
    txt(ctx, B.msg, VW / 2, 80, { size: 17, align: "center" });
  }
  // bottom panels
  panel(ctx, 8, 402, 202, 168);
  if (!G.ui.length || !B.active || B.active.isEnemy) {
    const a = B.active;
    txt(ctx, a ? (a.isEnemy ? "Enemy turn" : a.name) : "...", 28, 440, { size: 16, color: "#cbd5e1" });
    txt(ctx, `Round ${B.round || 1}`, 28, 468, { size: 14, color: "#94a3b8" });
  }
  panel(ctx, 216, 402, VW - 224, 168);
  B.party.forEach((u, i) => {
    const y = 414 + i * 50;
    const st = stats(u.m);
    if (B.active === u) { ctx.fillStyle = "rgba(250,204,21,.16)"; ctx.beginPath(); ctx.roundRect(226, y, VW - 244, 46, 6); ctx.fill(); }
    txt(ctx, u.name, 240, y + 22, { size: 17, color: alive(u) ? "#fff" : "#f87171" });
    txt(ctx, `Lv ${u.m.level}`, 240, y + 41, { size: 13, color: "#94a3b8" });
    txt(ctx, "HP", 420, y + 20, { size: 13, color: "#94a3b8" });
    bar(ctx, 446, y + 8, 170, 14, u.m.hp, st.maxHp, hpColor(u.m.hp, st.maxHp));
    txt(ctx, `${u.m.hp}/${st.maxHp}`, 616, y + 40, { size: 14, align: "right" });
    txt(ctx, "MP", 640, y + 20, { size: 13, color: "#94a3b8" });
    bar(ctx, 666, y + 8, 110, 14, u.m.mp, st.maxMp, "#3b82f6");
    txt(ctx, `${u.m.mp}/${st.maxMp}`, 776, y + 40, { size: 14, align: "right" });
    let sx = 792;
    if (!alive(u)) { txt(ctx, "KO", sx, y + 28, { size: 15, color: "#f87171" }); }
    else for (const s of ["poison", "sleep", "shield"]) if (u.st[s]) { statusIcon(ctx, s, sx, y + 15); sx += 38; }
    if (u.defending) statusIcon(ctx, "defend", sx, y + 15);
  });
  if (B.results) {
    const r = B.results;
    const h = 90 + r.lines.length * 28;
    panel(ctx, VW / 2 - 300, 120, 600, h, { top: "#713f12", bottom: "#422006", border: "#fde68a" });
    txt(ctx, r.title, VW / 2, 162, { size: 30, align: "center", color: "#fde68a" });
    r.lines.forEach((l, i) => txt(ctx, l, VW / 2, 200 + i * 28, { size: 17, align: "center" }));
    downArrow(ctx, VW / 2 + 280, 120 + h - 12, G.T);
  }
  if (B.intro > 0) {
    ctx.fillStyle = "#000";
    const k = B.intro;
    ctx.fillRect(0, 0, VW, VH / 2 * k); ctx.fillRect(0, VH - VH / 2 * k, VW, VH / 2 * k);
  }
}
function drawEnemyInfo(ctx, e) {
  const x = 14, y = 102, w = 330, h = 74;
  panel(ctx, x, y, w, h, { top: "#3f0d0d", bottom: "#1f0606", border: "#fca5a5" });
  txt(ctx, e.name, x + 16, y + 26, { size: 16 });
  bar(ctx, x + 16, y + 36, 180, 10, e.hp, e.maxHp, hpColor(e.hp, e.maxHp));
  txt(ctx, "Weak:", x + 16, y + 64, { size: 13, color: "#fca5a5" });
  const kn = G.s.known[e.kind] || {};
  let wx = x + 70;
  let any = false;
  for (const el of ELEMENTS) {
    if (kn[el] === "weak") { elIcon(ctx, el, wx + 6, y + 59, 7); txt(ctx, EL_NAME[el], wx + 16, y + 64, { size: 13 }); wx += 76; any = true; }
  }
  if (!any) txt(ctx, Object.keys(kn).length >= 3 ? "none" : "???", wx, y + 64, { size: 13, color: "#94a3b8" });
  const res = ELEMENTS.filter((el) => kn[el] === "resist");
  if (res.length) { txt(ctx, "Resists:", x + 210, y + 26, { size: 12, color: "#94a3b8" }); res.forEach((el, i) => elIcon(ctx, el, x + 270 + i * 18, y + 21, 6)); }
}

function updateBattle(dt) {
  if (!B) return;
  if (B.shake > 0) B.shake = Math.max(0, B.shake - dt);
  if (B.flashScreen > 0 && !B.transforming) B.flashScreen = Math.max(0, B.flashScreen - dt * 2);
  for (const u of [...B.enemies, ...B.party]) if (u.flash > 0) u.flash = Math.max(0, u.flash - dt);
  B.nums.forEach((n) => (n.t += dt * G.fast));
  B.nums = B.nums.filter((n) => n.t < 1);
  B.fx.forEach((f) => (f.t += dt * G.fast));
  B.fx = B.fx.filter((f) => f.t < f.d);
}
