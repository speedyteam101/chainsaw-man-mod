/* Brick Legends: engine core - state, party math, input, UI windows, dialogue, music. */
"use strict";

const { canvas, ctx } = Kit.stage(VW, VH);
const G = {
  scene: "title", T: 0, s: null, fast: 1,
  ui: [], anims: [], hits: [], mouse: { x: -1, y: -1 },
  busy: false, fade: 0, banner: null, card: null, toast: null,
  heroName: "Player", heroLook: Kit.DEFAULT_LOOK,
};
function refreshPlayer() {
  const p = Kit.player();
  G.heroName = String(p.name || "Player").slice(0, 14);
  G.heroLook = p.avatar;
}
refreshPlayer();

// ------------------------------------------------------------------ party math
function baseStat(m, k) { const c = CLASSES[m.id]; return Math.floor(c.base[k] + c.grow[k] * (m.level - 1)); }
function stats(m) {
  const o = { immune: [] };
  for (const k of ["hp", "mp", "atk", "def", "mag", "spd"]) o[k] = baseStat(m, k);
  for (const slot of ["weapon", "armor", "acc"]) {
    const e = EQUIP[m.equip[slot]];
    if (!e) continue;
    for (const k of ["hp", "mp", "atk", "def", "mag", "spd"]) o[k] += e[k] || 0;
    if (e.immune) o.immune.push(...e.immune);
  }
  o.maxHp = o.hp; o.maxMp = o.mp;
  return o;
}
function newMember(id, level) {
  const m = { id, level: Math.max(1, level || 1), xp: 0, hp: 1, mp: 0, equip: Object.assign({}, CLASSES[id].start) };
  const st = stats(m);
  m.hp = st.maxHp; m.mp = st.maxMp;
  return m;
}
function memberName(m) { return m.id === "hero" ? G.heroName : CLASSES[m.id].name; }
function memberLook(m) { return m.id === "hero" ? G.heroLook : CLASSES[m.id].look; }
function skillsOf(m) { return CLASSES[m.id].skills.filter(([l]) => l <= m.level).map(([, s]) => s); }
function canEquip(m, id) { const e = EQUIP[id]; return !!e && (!e.for || e.for.includes(m.id)); }
function hero() { return G.s.party[0]; }
function healAll() {
  for (const m of G.s.party) { const st = stats(m); m.hp = st.maxHp; m.mp = st.maxMp; }
}
function clampMember(m) { const st = stats(m); m.hp = Math.min(m.hp, st.maxHp); m.mp = Math.min(m.mp, st.maxMp); }
// Returns a list of { name, level, learned[] } for every level gained.
function gainXp(m, xp) {
  const out = [];
  m.xp += xp;
  while (m.xp >= xpNeed(m.level) && m.level < 50) {
    const before = stats(m);
    const oldSkills = skillsOf(m);
    m.xp -= xpNeed(m.level);
    m.level++;
    const after = stats(m);
    if (m.hp > 0) m.hp += after.maxHp - before.maxHp;
    m.mp += after.maxMp - before.maxMp;
    const learned = skillsOf(m).filter((s) => !oldSkills.includes(s)).map((s) => SKILLS[s].name);
    out.push({ name: memberName(m), level: m.level, learned });
  }
  return out;
}
function addItem(id, n) { G.s.items[id] = (G.s.items[id] || 0) + (n || 1); }
function itemCount(id) { return G.s.items[id] || 0; }
function takeItem(id, n) { G.s.items[id] = Math.max(0, itemCount(id) - (n || 1)); if (!G.s.items[id]) delete G.s.items[id]; }
function addGear(id, n) { G.s.gear[id] = (G.s.gear[id] || 0) + (n || 1); }
function takeGear(id) { G.s.gear[id] = (G.s.gear[id] || 0) - 1; if (G.s.gear[id] <= 0) delete G.s.gear[id]; }
function gearCount(id) { return G.s.gear[id] || 0; }
function equippedCount(id) { return G.s.party.filter((m) => Object.values(m.equip).includes(id)).length; }
function thingName(id) { return (ITEMS[id] || EQUIP[id] || { name: id }).name; }

// ------------------------------------------------------------------ timing helpers
function wait(ms) { return new Promise((r) => setTimeout(r, ms / G.fast)); }
function anim(ms, fn) {
  return new Promise((res) => G.anims.push({ t: 0, d: Math.max(0.001, ms / 1000), fn, res }));
}
function updateAnims(dt) {
  const list = G.anims.slice();
  for (const a of list) {
    a.t += dt * G.fast;
    const p = Math.min(1, a.t / a.d);
    try { a.fn(p); } catch (e) { console.error(e); }
    if (p >= 1) { G.anims.splice(G.anims.indexOf(a), 1); a.res(); }
  }
}
async function fadeOut(ms) { await anim(ms || 300, (p) => { G.fade = Math.max(G.fade, p); }); G.fade = 1; }
async function fadeIn(ms) { const f = G.fade; await anim(ms || 300, (p) => { G.fade = f * (1 - p); }); G.fade = 0; }

// ------------------------------------------------------------------ input
const KEYMAP = {
  ArrowUp: "up", KeyW: "up", ArrowDown: "down", KeyS: "down", ArrowLeft: "left", KeyA: "left", ArrowRight: "right", KeyD: "right",
  Enter: "ok", NumpadEnter: "ok", Space: "ok", KeyZ: "ok", KeyX: "back", Backspace: "back",
  KeyQ: "menu", Tab: "menu", KeyM: "map", KeyN: "music",
};
const DIR_KEYS = { up: ["ArrowUp", "KeyW"], down: ["ArrowDown", "KeyS"], left: ["ArrowLeft", "KeyA"], right: ["ArrowRight", "KeyD"] };
addEventListener("keydown", (e) => { if (e.code === "Tab" || e.code === "Backspace") e.preventDefault(); });
let lastDirKey = null;
Kit.onKey((code) => {
  Music.unlock();
  const k = KEYMAP[code];
  if (!k) return;
  if (["up", "down", "left", "right"].includes(k)) lastDirKey = k;
  if (k === "music") { Music.toggle(); return; }
  const top = G.ui[G.ui.length - 1];
  if (top) { top.key(k); return; }
  if (G.scene === "field" && typeof fieldKey === "function") fieldKey(k);
});
function heldDir() {
  if (lastDirKey && DIR_KEYS[lastDirKey].some((c) => Kit.key(c))) return lastDirKey;
  for (const d of ["up", "down", "left", "right"]) if (DIR_KEYS[d].some((c) => Kit.key(c))) return d;
  return null;
}
// Mouse: draw code registers hit boxes; only the top-most window's boxes respond.
let drawOwner = null;
function hit(x, y, w, h, click, hover) { G.hits.push({ x, y, w, h, click, hover, owner: drawOwner }); }
function topOwner() { return G.ui.length ? G.ui[G.ui.length - 1] : G.scene; }
function hitsAt(p) {
  const o = topOwner();
  return G.hits.filter((h) => h.owner === o && p.x >= h.x && p.y >= h.y && p.x < h.x + h.w && p.y < h.y + h.h);
}
canvas.addEventListener("mousemove", (e) => {
  const p = Kit.pointer(canvas, e);
  G.mouse = p;
  const hs = hitsAt(p);
  const h = hs[hs.length - 1];
  if (h && h.hover) h.hover();
  canvas.style.cursor = hs.length ? "pointer" : "default";
});
canvas.addEventListener("mousedown", (e) => {
  if (e.button !== 0) return;
  Music.unlock();
  canvas.focus();
  const p = Kit.pointer(canvas, e);
  const hs = hitsAt(p);
  const h = hs[hs.length - 1];
  if (h && h.click) { e.preventDefault(); h.click(); }
});
canvas.addEventListener("contextmenu", (e) => e.preventDefault());

// ------------------------------------------------------------------ UI windows
function pushUI(w) { G.ui.push(w); return w; }
function closeUI(w) { const i = G.ui.indexOf(w); if (i >= 0) G.ui.splice(i, 1); }
function drawUI(ctx) {
  for (const w of G.ui) { drawOwner = w; w.draw(ctx); }
  drawOwner = null;
}

// Generic list window. items: [{ label, right, disabled, color, data }] or a function returning them.
function makeList(o) {
  const w = {
    o, sel: o.sel || 0, scroll: 0,
    items() { return typeof o.items === "function" ? o.items() : o.items; },
    rowH: o.rowH || 30,
    rows() { return o.rows || Math.max(1, this.items().length); },
    height() { return (o.title ? 38 : 12) + this.rows() * this.rowH + 12; },
    move(d) {
      const n = this.items().length;
      if (!n) return;
      this.sel = (this.sel + d + n) % n;
      Kit.sfx("click");
      if (o.onMove) o.onMove(this.items()[this.sel], this.sel);
    },
    pick() {
      const it = this.items()[this.sel];
      if (!it) return;
      if (it.disabled) { Music.sfx("buzz"); return; }
      Kit.sfx("click");
      o.onPick && o.onPick(it, this.sel, w);
    },
    key(k) {
      if (k === "up") this.move(-(o.cols || 1));
      else if (k === "down") this.move(o.cols || 1);
      else if (k === "left" && o.onLeft) o.onLeft();
      else if (k === "right" && o.onRight) o.onRight();
      else if (k === "left" && o.cols) this.move(-1);
      else if (k === "right" && o.cols) this.move(1);
      else if (k === "ok") this.pick();
      else if (k === "back" && o.onCancel) { Kit.sfx("click"); o.onCancel(w); }
      else if (k === "menu" && o.onMenu) o.onMenu();
    },
    draw(ctx) {
      const items = this.items();
      if (this.sel >= items.length) this.sel = Math.max(0, items.length - 1);
      const rows = this.rows();
      if (this.sel < this.scroll) this.scroll = this.sel;
      if (this.sel >= this.scroll + rows) this.scroll = this.sel - rows + 1;
      const h = o.h || this.height();
      const x = o.x, y = o.y, wd = o.w;
      if (!o.noPanel) panel(ctx, x, y, wd, h, o.panel);
      let yy = y + 12;
      if (o.title) { txt(ctx, o.title, x + 16, y + 28, { size: 16, color: "#fde68a" }); yy = y + 38; }
      if (!items.length) txt(ctx, o.empty || "(nothing)", x + 34, yy + 21, { size: 15, color: "#94a3b8" });
      for (let i = this.scroll; i < Math.min(items.length, this.scroll + rows); i++) {
        const it = items[i];
        const ry = yy + (i - this.scroll) * this.rowH;
        const active = i === this.sel && G.ui[G.ui.length - 1] === w;
        if (i === this.sel) {
          ctx.fillStyle = active ? "rgba(250,204,21,.18)" : "rgba(255,255,255,.07)";
          ctx.beginPath(); ctx.roundRect(x + 10, ry + 2, wd - 20, this.rowH - 4, 6); ctx.fill();
        }
        if (it.draw) it.draw(ctx, x + 30, ry, wd - 44, i === this.sel);
        else {
          const col = it.disabled ? "#64748b" : it.color || "#f8fafc";
          txt(ctx, it.label, x + 32, ry + this.rowH / 2 + 6, { size: o.size || 17, color: col });
          if (it.right !== undefined) txt(ctx, String(it.right), x + wd - 18, ry + this.rowH / 2 + 6, { size: o.size ? o.size - 1 : 16, color: it.disabled ? "#64748b" : "#cbd5e1", align: "right" });
        }
        if (active) cursor(ctx, x + 12, ry + this.rowH / 2, G.T);
        hit(x + 8, ry, wd - 16, this.rowH, () => { this.sel = i; this.pick(); }, () => { if (this.sel !== i) { this.sel = i; if (o.onMove) o.onMove(it, i); } });
      }
      if (this.scroll > 0) downArrowUp(ctx, x + wd - 26, yy + 2);
      if (this.scroll + rows < items.length) downArrow(ctx, x + wd - 26, y + h - 8, G.T, "#cbd5e1");
      if (o.help) {
        const it = items[this.sel];
        const s = typeof o.help === "function" ? o.help(it) : o.help;
        if (s) {
          const hy = o.helpY || (y + h + 6);
          panel(ctx, o.helpX || x, hy, o.helpW || wd, 44, { top: "#0f172a", bottom: "#0b1220" });
          txt(ctx, s, (o.helpX || x) + 16, hy + 28, { size: 14, color: "#e2e8f0" });
        }
      }
      if (o.after) o.after(ctx, w);
    },
  };
  return w;
}
function downArrowUp(ctx, x, y) {
  ctx.fillStyle = "#cbd5e1";
  ctx.beginPath(); ctx.moveTo(x - 7, y + 8); ctx.lineTo(x + 7, y + 8); ctx.lineTo(x, y); ctx.fill();
}

// ------------------------------------------------------------------ dialogue
function fmt(s) { return String(s).replace(/\{hero\}/g, G.heroName); }
function say(name, text, o) {
  o = o || {};
  return new Promise((resolve) => {
    const lines = wrapText(ctx, fmt(text), 780, 19);
    const full = lines.join("\n");
    const w = {
      name: name ? fmt(name) : "", lines, shown: 0, choices: o.choices || null, sel: 0, opened: performance.now(),
      key(k) {
        if (performance.now() - this.opened < 120) return;
        const done = this.shown >= full.length;
        if (this.choices && done) {
          if (k === "up") { this.sel = (this.sel + this.choices.length - 1) % this.choices.length; Kit.sfx("click"); }
          else if (k === "down") { this.sel = (this.sel + 1) % this.choices.length; Kit.sfx("click"); }
          else if (k === "ok") this.finish(this.sel);
          else if (k === "back") this.finish(this.choices.length - 1);
          return;
        }
        if (k === "ok" || k === "back") {
          if (!done) this.shown = full.length;
          else this.finish(0);
        }
      },
      finish(v) { Kit.sfx("click"); closeUI(w); resolve(v); },
      draw(ctx) {
        hit(0, 0, VW, VH, () => this.key("ok"));
        if (this.shown < full.length) {
          this.shown = Math.min(full.length, this.shown + (G.fast > 1 ? 999 : 1.6));
        }
        const bx = 40, by = VH - 168, bw = VW - 80, bh = 150;
        panel(ctx, bx, by, bw, bh);
        if (this.name) {
          ctx.font = `bold 16px ${FONT}`;
          const nw = ctx.measureText(this.name).width + 30;
          panel(ctx, bx + 18, by - 26, nw, 34, { top: "#b45309", bottom: "#78350f" });
          txt(ctx, this.name, bx + 33, by - 3, { size: 16 });
        }
        let n = Math.floor(this.shown);
        lines.forEach((ln, i) => {
          const part = ln.slice(0, Math.max(0, n));
          n -= ln.length + 1;
          txt(ctx, part, bx + 28, by + 42 + i * 28, { size: 19 });
        });
        const done = this.shown >= full.length;
        if (done && this.choices) {
          const cw = 190, ch = this.choices.length * 32 + 20;
          const cx = bx + bw - cw - 10, cy = by - ch - 8;
          panel(ctx, cx, cy, cw, ch);
          this.choices.forEach((c, i) => {
            const ry = cy + 12 + i * 32;
            if (i === this.sel) { ctx.fillStyle = "rgba(250,204,21,.18)"; ctx.beginPath(); ctx.roundRect(cx + 8, ry, cw - 16, 30, 6); ctx.fill(); cursor(ctx, cx + 14, ry + 15, G.T); }
            txt(ctx, c, cx + 34, ry + 22, { size: 17 });
            hit(cx + 6, ry, cw - 12, 30, () => this.finish(i), () => { this.sel = i; });
          });
        } else if (done) downArrow(ctx, bx + bw - 30, by + bh - 14, G.T);
      },
    };
    pushUI(w);
  });
}
async function talk(lines) { for (const l of lines) await say(l[0], l[1]); }
function ask(name, text, choices) { return say(name, text, { choices }); }
function notice(text) { return say("", text); }
function toast(text) { G.toast = { text: fmt(text), t: 0 }; }

// Chapter title card.
async function chapterCard(title, sub) {
  G.card = { title, sub, a: 0 };
  Music.sfx("chime");
  await anim(500, (p) => { G.card.a = p; });
  await wait(1800);
  await anim(500, (p) => { G.card.a = 1 - p; });
  G.card = null;
}
function drawCard(ctx) {
  if (!G.card) return;
  ctx.save();
  ctx.globalAlpha = G.card.a;
  ctx.fillStyle = "rgba(5,8,20,.82)";
  ctx.fillRect(0, VH / 2 - 80, VW, 160);
  ctx.fillStyle = "#facc15"; ctx.fillRect(0, VH / 2 - 80, VW, 4); ctx.fillRect(0, VH / 2 + 76, VW, 4);
  txt(ctx, G.card.title.toUpperCase(), VW / 2, VH / 2 - 18, { size: 22, align: "center", color: "#fde68a" });
  txt(ctx, G.card.sub, VW / 2, VH / 2 + 30, { size: 38, align: "center" });
  ctx.restore();
}

// ------------------------------------------------------------------ music (tiny WebAudio sequencer)
const SONGS = {
  title: { bpm: 92, mel: "E5 - G5 - C6 - B5 A5 G5 - E5 - F5 - D5 - E5 - C5 - D5 - G4 - A4 B4 C5 D5 E5 - G5 - A5 - G5 F5 E5 - D5 - C5 - - - . . . .",
           bass: "C3 . G3 . C3 . G3 . A2 . E3 . A2 . E3 . F2 . C3 . F2 . C3 . G2 . D3 . G2 . B2 ." },
  field: { bpm: 120, mel: "G4 - B4 D5 G5 - F#5 E5 D5 - B4 - C5 - A4 - B4 - G4 B4 D5 - E5 D5 C5 - E5 - D5 - . . G4 - B4 D5 G5 - A5 B5 C6 - B5 A5 G5 - E5 - F#5 - D5 E5 F#5 - A5 - G5 - - - . .",
           bass: "G2 . D3 . G2 . D3 . C3 . G3 . C3 . G3 . E2 . B2 . E2 . B2 . D3 . A2 . D3 . F#3 ." },
  town:  { bpm: 100, mel: "A4 - C5 - F5 - E5 D5 C5 - A4 - A#4 - D5 - C5 - A4 - G4 - A4 - C5 - D5 C5 A4 - F4 - G4 - A4 - G4 - - - . .",
           bass: "F2 . C3 . F2 . C3 . A#2 . F3 . A#2 . F3 . F2 . C3 . F2 . C3 . C3 . G2 . C3 . E3 ." },
  battle:{ bpm: 150, mel: "A4 C5 E5 A5 G5 E5 C5 E5 F5 A5 C6 A5 G5 E5 D5 E5 A4 C5 E5 A5 B5 G5 E5 G5 A5 G5 F5 E5 D5 C5 B4 G#4",
           bass: "A2 A3 A2 A3 A2 A3 A2 A3 F2 F3 F2 F3 F2 F3 F2 F3 G2 G3 G2 G3 G2 G3 G2 G3 E2 E3 E2 E3 E2 E3 G#2 G#3" },
  boss:  { bpm: 160, mel: "D5 . D5 F5 A5 - G#5 - A5 . A5 C6 D6 - C6 A#5 A5 - F5 - G5 - E5 - D5 . D5 F5 E5 D5 C#5 E5",
           bass: "D2 D2 D3 D2 D2 D3 D2 C3 A#1 A#1 A#2 A#1 A#1 A#2 A#1 C2 G1 G1 G2 G1 A1 A1 A2 A1 D2 D2 D3 D2 A1 A2 C#2 C#3" },
  castle:{ bpm: 84, mel: "D4 - F4 - G#4 - A4 - . . F4 - E4 - D4 - C#4 - - - . . D4 - F4 - A4 - D5 - C#5 - A4 - G#4 - - - . .",
           bass: "D2 - - - - - - - A#1 - - - - - - - G1 - - - - - - - A1 - - - - - - -" },
  ending:{ bpm: 88, mel: "C5 - E5 - G5 - C6 - B5 - G5 - A5 - - - F5 - A5 - C6 - D6 - C6 - B5 - C6 - - - - - . .",
           bass: "C3 . G3 . E3 . G3 . F2 . C3 . A2 . C3 . F2 . C3 . A2 . C3 . G2 . D3 . G2 . B2 ." },
};
function noteFreq(n) {
  const m = /^([A-G])(#?)(\d)$/.exec(n);
  if (!m) return 0;
  const semi = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 }[m[1]] + (m[2] ? 1 : 0);
  const midi = 12 * (Number(m[3]) + 1) + semi;
  return 440 * Math.pow(2, (midi - 69) / 12);
}
function parseTrack(s) {
  const toks = s.trim().split(/\s+/);
  const out = toks.map(() => null);
  for (let i = 0; i < toks.length; i++) {
    if (toks[i] === "-" || toks[i] === ".") continue;
    let len = 1;
    while (toks[i + len] === "-") len++;
    out[i] = { f: noteFreq(toks[i]), len };
  }
  return out;
}
for (const k in SONGS) { SONGS[k].m = parseTrack(SONGS[k].mel); SONGS[k].b = parseTrack(SONGS[k].bass); }

const Music = {
  ac: null, out: null, name: null, step: 0, next: 0, timer: null, off: false,
  muted() {
    if (this.off) return true;
    try { return localStorage.getItem("blockos.muted") === "1"; } catch (_) { return false; }
  },
  unlock() {
    try {
      if (!this.ac) {
        this.ac = new (window.AudioContext || window.webkitAudioContext)();
        this.out = this.ac.createGain();
        this.out.gain.value = 0.9;
        this.out.connect(this.ac.destination);
      }
      if (this.ac.state === "suspended") this.ac.resume();
    } catch (_) {}
  },
  toggle() { this.off = !this.off; toast(this.off ? "Music off (N)" : "Music on (N)"); },
  play(name) {
    if (this.name === name) return;
    this.name = name; this.step = 0;
    if (this.ac) this.next = this.ac.currentTime + 0.08;
    if (!this.timer) this.timer = setInterval(() => this.tick(), 50);
  },
  stop() { this.name = null; },
  tone(f, t, len, type, vol) {
    const o = this.ac.createOscillator(), g = this.ac.createGain();
    o.type = type; o.frequency.value = f;
    g.gain.setValueAtTime(0.0001, t);
    g.gain.linearRampToValueAtTime(vol, t + 0.015);
    g.gain.exponentialRampToValueAtTime(0.0001, t + len);
    o.connect(g).connect(this.out);
    o.start(t); o.stop(t + len + 0.02);
  },
  tick() {
    if (!this.ac || !this.name || this.ac.state !== "running") return;
    const song = SONGS[this.name];
    const sd = 60 / song.bpm / 2;
    if (this.next < this.ac.currentTime) this.next = this.ac.currentTime + 0.02;
    while (this.next < this.ac.currentTime + 0.25) {
      if (!this.muted()) {
        const mn = song.m[this.step % song.m.length], bn = song.b[this.step % song.b.length];
        if (mn && mn.f) this.tone(mn.f, this.next, mn.len * sd * 0.95, "square", 0.022);
        if (bn && bn.f) this.tone(bn.f, this.next, bn.len * sd * 0.9, "triangle", 0.05);
      }
      this.step++;
      this.next += sd;
    }
  },
  sfx(kind) {
    if (!this.ac || this.muted()) return;
    const t = this.ac.currentTime;
    const seq = {
      magic: [[523, 0.06], [784, 0.06], [1047, 0.1]],
      heal: [[784, 0.08], [988, 0.08], [1319, 0.14]],
      buzz: [[140, 0.12]],
      chime: [[659, 0.15], [988, 0.3]],
      level: [[523, 0.08], [659, 0.08], [784, 0.08], [1047, 0.08], [1319, 0.25]],
      thunder: [[90, 0.25]],
      step: [[200, 0.03]],
    }[kind];
    if (!seq) return;
    let tt = t;
    for (const [f, len] of seq) {
      this.tone(f, tt, len, kind === "buzz" || kind === "thunder" ? "sawtooth" : "triangle", 0.07);
      tt += len * 0.85;
    }
  },
};
