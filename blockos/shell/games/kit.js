/*
 * BlockOS game kit: small helpers shared by every game in games/<id>/index.html.
 *
 *   Kit.stage(w, h)              -> { canvas, ctx, W, H }  (canvas scaled to fit the window)
 *   Kit.key(code)                -> true while KeyboardEvent.code is held ("ArrowLeft", "Space", "KeyA"...)
 *   Kit.onKey(fn)                -> fn(code, event) on every keydown (no auto-repeat)
 *   Kit.loop(update, draw)       -> { start(), stop() }; update(dt) gets seconds, clamped to 0.05
 *   Kit.overlay(title, text, btn)-> Promise, resolves when the button, Enter or Space is pressed
 *   Kit.hud(html)                -> sets the top-right HUD text
 *   Kit.best(id, score, lower)   -> stores and returns the best score (lower=true when smaller wins)
 *   Kit.sfx(name)                -> "click" | "score" | "hit" | "jump" | "lose" | "win" | "coin"
 *   Kit.finish(id, score)        -> records the best score and reports it to the BlockOS shell
 *   Kit.rand(a, b), Kit.randInt(a, b), Kit.pick(arr), Kit.clamp(v, a, b)
 *   Kit.colors                   -> brick palette
 *
 * Roblox-style extras:
 *   Kit.player()                 -> { name, avatar } of the person playing (from their BlockOS Avatar page)
 *   Kit.drawAvatar(ctx, x, y, h, opts) -> draws a blocky character standing at (x, y) = feet, h px tall.
 *                                   opts: { look (avatar, default yours), facing: 1 | -1, walk (phase, radians),
 *                                   air (true while jumping), name (shown above the head) }
 *   Kit.badge(gameId, badgeId, name, description) -> awards a badge once; BlockOS shows a pop-up
 *   Kit.leaderboard(columns, rows)-> Roblox-style player list, top right. columns: ["Level", "Gold"],
 *                                   rows: [{ name, values: [3, 120], me: true }]. Pass null to hide it.
 *   Kit.net(gameId, opts)        -> online play (see the comment above function net below)
 *   Kit.QUICK_CHAT               -> the phrases players can send (there is no free-text chat)
 *   Kit.friends                  -> friend code and friends list (shared with the BlockOS desktop)
 */
(function () {
  "use strict";

  // Phones and tablets: load the on-screen controls (touch.js, next to this file).
  const IS_TOUCH = matchMedia("(pointer: coarse)").matches || navigator.maxTouchPoints > 0 && !matchMedia("(pointer: fine)").matches;
  if (IS_TOUCH && document.currentScript) {
    const s = document.createElement("script");
    // Games made by players on the web version get touch.js handed to them (studio/runner.js).
    s.src = window.BLOCKOS_TOUCH_URL || new URL("touch.js", document.currentScript.src).href;
    document.head.appendChild(s);
  }

  const held = new Set();
  const keyHandlers = [];
  const GAME_KEYS = new Set(["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"]);

  const typing = (e) => e.target && (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA");
  // Keys typed into a text box (like the chat box) belong to the box: this runs before any
  // game's own key listeners and stops them from seeing (or blocking) those keys.
  for (const type of ["keydown", "keyup", "keypress"]) {
    addEventListener(type, (e) => { if (typing(e)) e.stopImmediatePropagation(); }, true);
  }
  addEventListener("keydown", (e) => {
    if (typing(e)) return;   // typing in a chat box isn't playing the game
    if (GAME_KEYS.has(e.code)) e.preventDefault();
    if (e.code === "Escape") {
      // The shell owns Escape (it opens the in-game menu).
      try { parent.postMessage({ type: "blockos:escape" }, "*"); } catch (_) {}
      return;
    }
    if (!e.repeat) keyHandlers.forEach((fn) => fn(e.code, e));
    held.add(e.code);
  });
  addEventListener("keyup", (e) => held.delete(e.code));
  addEventListener("blur", () => held.clear());

  function stage(w, h) {
    const wrap = document.createElement("div");
    wrap.className = "kit-stage";
    const canvas = document.createElement("canvas");
    canvas.width = w;
    canvas.height = h;
    wrap.appendChild(canvas);
    document.body.appendChild(wrap);
    // Leave a band at the top for the HUD (top right) and the shell's menu button (top left);
    // a smaller one on short screens like phones held sideways.
    function fit() {
      const TOP = innerHeight < 500 ? 34 : 58;
      wrap.style.top = TOP + "px";
      const s = Math.min((innerWidth - 24) / w, (innerHeight - TOP - 12) / h);
      canvas.style.width = Math.max(50, w * s) + "px";
      canvas.style.height = Math.max(50, h * s) + "px";
    }
    addEventListener("resize", fit);
    fit();
    canvas.tabIndex = 0;
    return { canvas, ctx: canvas.getContext("2d"), W: w, H: h };
  }

  // Converts a mouse/pointer event into canvas pixel coordinates.
  function pointer(canvas, e) {
    const r = canvas.getBoundingClientRect();
    return {
      x: ((e.clientX - r.left) / r.width) * canvas.width,
      y: ((e.clientY - r.top) / r.height) * canvas.height,
    };
  }

  function loop(update, draw) {
    let running = false, last = 0, id = 0;
    function frame(t) {
      if (!running) return;
      const dt = Math.max(0, Math.min(0.05, (t - last) / 1000 || 0));
      last = t;
      update(dt);
      draw();
      id = requestAnimationFrame(frame);
    }
    return {
      start() {
        if (running) return;
        running = true;
        last = performance.now();
        id = requestAnimationFrame(frame);
      },
      stop() { running = false; cancelAnimationFrame(id); },
      get running() { return running; },
    };
  }

  function overlay(title, text, button) {
    return new Promise((resolve) => {
      const o = document.createElement("div");
      o.className = "kit-overlay";
      const panel = document.createElement("div");
      panel.className = "kit-panel";
      const h = document.createElement("h1");
      h.textContent = title;
      const p = document.createElement("p");
      p.textContent = text || "";
      const b = document.createElement("button");
      b.className = "kit-btn";
      b.textContent = button || "Play";
      panel.append(h, p, b);
      o.appendChild(panel);
      document.body.appendChild(o);
      const shownAt = performance.now();
      function done() {
        removeEventListener("keydown", onKey, true);
        o.remove();
        sfx("click");
        resolve();
      }
      function onKey(e) {
        // Ignore keys for a moment so a held key doesn't skip the screen.
        if ((e.code === "Enter" || e.code === "Space") && performance.now() - shownAt > 350) {
          e.preventDefault();
          e.stopPropagation();
          done();
        }
      }
      b.addEventListener("click", done);
      addEventListener("keydown", onKey, true);
      b.focus();
    });
  }

  let hudEl = null;
  function hud(html) {
    if (!hudEl) {
      hudEl = document.createElement("div");
      hudEl.className = "kit-hud";
      document.body.appendChild(hudEl);
    }
    hudEl.innerHTML = html;
  }

  function best(id, score, lowerIsBetter) {
    const key = "blockos.best." + id;
    let cur = null;
    try { const v = localStorage.getItem(key); cur = v === null ? null : Number(v); } catch (_) {}
    if (typeof score === "number" && isFinite(score)) {
      const better = cur === null || (lowerIsBetter ? score < cur : score > cur);
      if (better) {
        cur = score;
        try { localStorage.setItem(key, String(score)); } catch (_) {}
      }
    }
    return cur;
  }

  let audio = null;
  const SOUNDS = {
    click: [[660, 0.05, "square"]],
    score: [[880, 0.06, "square"], [1320, 0.08, "square"]],
    coin: [[988, 0.05, "square"], [1319, 0.12, "square"]],
    hit: [[180, 0.1, "sawtooth"]],
    jump: [[420, 0.05, "triangle"], [640, 0.07, "triangle"]],
    lose: [[392, 0.12, "sawtooth"], [311, 0.12, "sawtooth"], [233, 0.25, "sawtooth"]],
    win: [[523, 0.1, "square"], [659, 0.1, "square"], [784, 0.1, "square"], [1047, 0.25, "square"]],
  };
  function sfx(name) {
    const notes = SOUNDS[name];
    if (!notes) return;
    try {
      if (localStorage.getItem("blockos.muted") === "1") return;
    } catch (_) {}
    try {
      audio = audio || new (window.AudioContext || window.webkitAudioContext)();
      let t = audio.currentTime;
      for (const [freq, len, type] of notes) {
        const o = audio.createOscillator();
        const g = audio.createGain();
        o.type = type;
        o.frequency.value = freq;
        g.gain.setValueAtTime(0.08, t);
        g.gain.exponentialRampToValueAtTime(0.001, t + len);
        o.connect(g).connect(audio.destination);
        o.start(t);
        o.stop(t + len);
        t += len * 0.9;
      }
    } catch (_) {}
  }

  function finish(id, score, lowerIsBetter) {
    const b = best(id, score, lowerIsBetter);
    try { parent.postMessage({ type: "blockos:score", game: id, score, best: b }, "*"); } catch (_) {}
    return b;
  }

  const rand = (a, b) => a + Math.random() * (b - a);
  const randInt = (a, b) => Math.floor(rand(a, b + 1));
  const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // Draws a "brick": a rounded block with a lighter top edge and darker bottom edge.
  function brick(ctx, x, y, w, h, color, r) {
    r = r === undefined ? Math.min(6, w / 4, h / 4) : r;
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, r);
    ctx.fill();
    ctx.fillStyle = "rgba(255,255,255,.18)";
    ctx.fillRect(x + r / 2, y + 2, w - r, Math.max(2, h * 0.12));
    ctx.fillStyle = "rgba(0,0,0,.22)";
    ctx.fillRect(x + r / 2, y + h - Math.max(2, h * 0.12) - 1, w - r, Math.max(2, h * 0.12));
  }


  // ------------------------------------------------------------------ player & avatar

  const DEFAULT_LOOK = {
    head: "#f5cd30", torso: "#3b82f6", arms: "#f5cd30", legs: "#22c55e",
    face: "smile", hat: "none", shirt: "plain",
  };

  function player() {
    let saved = {};
    try { saved = JSON.parse(localStorage.getItem("blockos.state.v1")) || {}; } catch (_) {}
    return {
      name: typeof saved.name === "string" && saved.name ? saved.name : "Player",
      avatar: Object.assign({}, DEFAULT_LOOK, saved.avatar || {}),
    };
  }

  function shade(hex, amt) {
    const n = parseInt(String(hex).slice(1), 16) || 0;
    const f = (c) => Math.max(0, Math.min(255, Math.round(c + amt * 255)));
    return `rgb(${f(n >> 16)},${f((n >> 8) & 255)},${f(n & 255)})`;
  }

  // Side view of a classic 6-part blocky character. Proportions: legs 2, torso 2, head 1.2 units.
  function drawAvatar(ctx, x, y, h, opts) {
    const o = opts || {};
    const a = Object.assign({}, DEFAULT_LOOK, o.look || player().avatar);
    const u = h / 5.2;               // one "stud"
    const dir = o.facing === -1 ? -1 : 1;
    const swing = o.air ? 0.6 : Math.sin(o.walk || 0) * 0.7;
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(dir, 1);
    const limb = (px, py, w, len, angle, color) => {
      ctx.save();
      ctx.translate(px, py);
      ctx.rotate(angle);
      ctx.fillStyle = color;
      ctx.fillRect(-w / 2, 0, w, len);
      ctx.fillStyle = "rgba(0,0,0,.15)";
      ctx.fillRect(-w / 2, len - u * 0.25, w, u * 0.25);
      ctx.restore();
    };
    // back limbs (darker), body, front limbs
    limb(0, -2 * u, u * 0.9, 2 * u, -swing, shade(a.legs, -0.12));
    limb(0, -4 * u, u * 0.8, 1.9 * u, swing, shade(a.arms, -0.12));
    ctx.fillStyle = a.torso;
    ctx.fillRect(-u * 0.6, -4 * u, u * 1.2, 2 * u);
    if (a.shirt && a.shirt !== "plain") {
      ctx.fillStyle = a.shirt === "suit" ? "#1f2328" : a.shirt === "stripes" ? shade(a.torso, 0.18) : "#facc15";
      if (a.shirt === "stripes") for (let i = 0; i < 3; i++) ctx.fillRect(-u * 0.6, -3.8 * u + i * 0.6 * u, u * 1.2, u * 0.22);
      else ctx.fillRect(-u * 0.25, -3.6 * u, u * 0.5, u * 0.7);
    }
    limb(0, -2 * u, u * 0.9, 2 * u, swing, a.legs);
    // head
    ctx.fillStyle = a.head;
    ctx.beginPath();
    ctx.roundRect(-u * 0.6, -5.25 * u, u * 1.2, u * 1.2, u * 0.3);
    ctx.fill();
    // face (side view: one eye and the mouth near the front)
    ctx.fillStyle = "#111";
    if (a.face === "cool" || a.face === "robot") {
      ctx.fillStyle = a.face === "robot" ? "#22d3ee" : "#111";
      ctx.fillRect(u * 0.05, -4.95 * u, u * 0.55, u * 0.25);
    } else {
      ctx.fillRect(u * 0.2, -4.95 * u, u * 0.16, u * 0.26);
    }
    ctx.fillStyle = "#111";
    ctx.fillRect(u * 0.15, -4.45 * u, u * 0.4, u * 0.1);
    // hat
    ctx.save();
    switch (a.hat) {
      case "cap": ctx.fillStyle = "#2563eb"; ctx.fillRect(-u * 0.65, -5.5 * u, u * 1.3, u * 0.4); ctx.fillRect(0, -5.2 * u, u * 1.05, u * 0.15); break;
      case "tophat": ctx.fillStyle = "#1f2328"; ctx.fillRect(-u * 0.5, -6.4 * u, u, u * 1.2); ctx.fillRect(-u * 0.8, -5.3 * u, u * 1.6, u * 0.15); ctx.fillStyle = "#ef4444"; ctx.fillRect(-u * 0.5, -5.55 * u, u, u * 0.2); break;
      case "crown": ctx.fillStyle = "#facc15"; ctx.beginPath(); ctx.moveTo(-u * 0.6, -5.2 * u); ctx.lineTo(-u * 0.6, -5.9 * u); ctx.lineTo(-u * 0.3, -5.5 * u); ctx.lineTo(0, -6 * u); ctx.lineTo(u * 0.3, -5.5 * u); ctx.lineTo(u * 0.6, -5.9 * u); ctx.lineTo(u * 0.6, -5.2 * u); ctx.fill(); break;
      case "cone": ctx.fillStyle = "#fb923c"; ctx.beginPath(); ctx.moveTo(-u * 0.6, -5.2 * u); ctx.lineTo(0, -6.6 * u); ctx.lineTo(u * 0.6, -5.2 * u); ctx.fill(); ctx.fillStyle = "#fff"; ctx.fillRect(-u * 0.32, -5.8 * u, u * 0.64, u * 0.15); break;
      case "wizard": ctx.fillStyle = "#7c3aed"; ctx.beginPath(); ctx.moveTo(-u * 0.8, -5.2 * u); ctx.lineTo(-u * 0.1, -6.9 * u); ctx.lineTo(u * 0.8, -5.2 * u); ctx.fill(); break;
      case "headphones": ctx.strokeStyle = "#1f2328"; ctx.lineWidth = u * 0.18; ctx.beginPath(); ctx.arc(0, -4.7 * u, u * 0.72, Math.PI, 0); ctx.stroke(); ctx.fillStyle = "#ef4444"; ctx.fillRect(-u * 0.25, -4.85 * u, u * 0.5, u * 0.55); break;
    }
    ctx.restore();
    limb(0, -4 * u, u * 0.8, 1.9 * u, -swing, a.arms);
    ctx.restore();
    if (o.name) {
      ctx.save();
      ctx.font = `bold ${Math.max(10, u * 0.75)}px "Noto Sans", "DejaVu Sans", sans-serif`;
      ctx.textAlign = "center";
      ctx.fillStyle = "rgba(0,0,0,.6)";
      ctx.fillText(o.name, x + 1, y - h * 1.12 + 1);
      ctx.fillStyle = "#fff";
      ctx.fillText(o.name, x, y - h * 1.12);
      ctx.restore();
    }
  }

  // ------------------------------------------------------------------ badges

  let toastBox = null;
  function gameToast(title, text, color) {
    if (!toastBox) {
      toastBox = document.createElement("div");
      toastBox.className = "kit-toasts";
      document.body.appendChild(toastBox);
    }
    const t = document.createElement("div");
    t.className = "kit-toast";
    t.style.borderLeftColor = color || "#facc15";
    const b = document.createElement("b");
    b.textContent = title;
    const span = document.createElement("span");
    span.textContent = text || "";
    t.append(b, span);
    toastBox.appendChild(t);
    setTimeout(() => { t.classList.add("out"); setTimeout(() => t.remove(), 400); }, 3500);
  }

  function badge(gameId, badgeId, name, description) {
    const key = gameId + ":" + badgeId;
    let all = {};
    try { all = JSON.parse(localStorage.getItem("blockos.badges")) || {}; } catch (_) {}
    if (all[key]) return false;
    all[key] = { game: gameId, name: String(name), desc: String(description || ""), time: Date.now() };
    try { localStorage.setItem("blockos.badges", JSON.stringify(all)); } catch (_) {}
    sfx("win");
    // Inside BlockOS the shell shows the pop-up; when a game is opened on its own, show it here.
    if (parent !== window) {
      try { parent.postMessage({ type: "blockos:badge", game: gameId, badge: badgeId, name: String(name), desc: String(description || "") }, "*"); } catch (_) {}
    } else {
      gameToast("Badge awarded: " + name, description);
    }
    return true;
  }

  // ------------------------------------------------------------------ leaderboard (player list)

  let boardEl = null;
  function leaderboard(columns, rows) {
    if (!columns) { if (boardEl) boardEl.hidden = true; return; }
    if (!boardEl) {
      boardEl = document.createElement("div");
      boardEl.className = "kit-board";
      document.body.appendChild(boardEl);
    }
    boardEl.hidden = false;
    const esc = (v) => String(v).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
    const fmt = (v) => (typeof v === "number" ? Math.round(v).toLocaleString() : esc(v));
    boardEl.innerHTML = `<table><thead><tr><th>People</th>${columns.map((c) => `<th>${esc(c)}</th>`).join("")}</tr></thead><tbody>${
      rows.map((r) => `<tr class="${r.me ? "me" : ""}"><td>${esc(r.name)}</td>${(r.values || []).map((v) => `<td>${fmt(v)}</td>`).join("")}</tr>`).join("")
    }</tbody></table>`;
  }

  // Chat settings (set on the BlockOS Settings page): "all" | "friends" | "off", and muted players.
  const chatMode = () => { try { return localStorage.getItem("blockos.chatMode") || "all"; } catch (_) { return "all"; } };
  const muted = () => readJSON("blockos.mutedPlayers");
  function setMuted(code, on) { const m = muted(); if (on) m[code] = 1; else delete m[code]; writeJSON("blockos.mutedPlayers", m); }
  function canSee(p) {
    if (p.uid && p.uid === friends.code()) return true;
    const mode = chatMode();
    if (mode === "off") return false;
    if (p.uid && muted()[p.uid]) return false;
    return mode === "all" || !!(p.uid && friends.isFriend(p.uid));
  }

  // ------------------------------------------------------------------ online play
  //
  // const net = Kit.net("my-game", { room: "main", chat: true });
  //   net.online      true when BlockOS is connected to a server (Settings > Play online)
  //   net.server      which numbered server this is ("s1", "s2", ...), chosen in BlockOS's server list
  //   net.me          { id, name, avatar }
  //   net.players     Map of everyone else: id -> { id, name, avatar, state }
  //   net.isHost      true for the player who's been in the room longest; let them run shared things (NPCs, timers)
  //   net.state(obj)  share your own state (position etc.); sent at most 10 times a second
  //   net.event(obj)  send a one-off event to everyone else in the room (hits, pick-ups, round start...)
  //   net.chat(i)     send quick-chat phrase Kit.QUICK_CHAT[i]
  //   net.friendRequest(code, kind) send a friend request ("request") / "accept" / "decline" to a friend code
  //   net.on(type, fn) types: "join" (player), "leave" (player), "state" (player), "event" (player, data),
  //                   "chat" (player, text), "status" (online: boolean)
  // When BlockOS isn't online, net.online stays false and the game simply plays solo.

  // Quick chat: phrases only, sent by number, so nobody can type messages to anyone.
  // Keep the order: other players' BlockOS look phrases up by their position. Add new ones at the end.
  const QUICK_CHAT = [
    "Hi!", "Hello everyone!", "Good game!", "Follow me!", "Help!", "Nice!", "Let's go!", "Wait for me!", "Oops!", "Thanks!", "Ready?", "Bye!",
    // 12+
    "Hey friend!", "Welcome!", "How are you?", "I'm good!", "Want to play together?", "Let's be friends!",
    "Over here!", "Come back!", "Go go go!", "Almost there!", "Watch out!", "Behind you!", "Jump!", "This way!",
    "Let's team up!", "I'll help you!", "Thank you so much!", "No problem!", "Wait here", "Stay together!",
    "Wow!", "Cool!", "Awesome!", "Haha!", "So close!", "I did it!", "Yay!", "Oh no!", "That was fun!", "Too easy!",
    "Where are you?", "What should we do?", "Want to race?", "One more round?", "Which way?", "Are you ready?",
    "See you later!", "Gotta go!", "Be right back", "Good night!", "Play again soon!",
    "Yes", "No", "Maybe", "OK!", "Sorry!",
  ];
  // Tabs in the chat menu: [name, phrase numbers].
  const QUICK_CHAT_TABS = [
    ["Hi", [0, 1, 12, 13, 14, 15, 16, 17, 9, 16]],
    ["Game", [3, 6, 7, 18, 19, 20, 21, 22, 23, 24, 25, 4]],
    ["Team", [26, 27, 28, 29, 30, 31, 10, 6, 3, 4]],
    ["Feelings", [5, 2, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 8]],
    ["Ask", [42, 43, 44, 45, 46, 47, 14, 16]],
    ["Bye", [11, 48, 49, 50, 51, 52, 2]],
    ["Quick", [53, 54, 55, 56, 57, 9]],
  ].map(([name, ids]) => [name, [...new Set(ids)].filter((i) => QUICK_CHAT[i])]);

  function serverAddress() {
    // Games made by players run in BlockOS's sandbox (studio/runner.js), which passes the address in BLOCKOS_SERVER.
    if (typeof window.BLOCKOS_SERVER === "string") return window.BLOCKOS_SERVER;
    try { return localStorage.getItem("blockos.server") || ""; } catch (_) { return ""; }
  }

  // ------------------------------------------------------------------ friends
  // Shared with the BlockOS desktop (same keys in app.js):
  //   blockos.uid       this install's friend code (8 characters)
  //   blockos.friends   { code: { name, avatar, since } }
  //   blockos.requests  { code: { name, avatar, time } } friend requests waiting for an answer

  const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  function readJSON(key) { try { return JSON.parse(localStorage.getItem(key)) || {}; } catch (_) { return {}; } }
  function writeJSON(key, v) { try { localStorage.setItem(key, JSON.stringify(v)); } catch (_) {} }
  function myCode() {
    let c = null;
    try { c = localStorage.getItem("blockos.uid"); } catch (_) {}
    if (!c || !/^[A-HJ-NP-Z2-9]{8}$/.test(c)) {
      const r = new Uint8Array(8);
      crypto.getRandomValues(r);
      c = [...r].map((x) => CODE_CHARS[x % CODE_CHARS.length]).join("");
      try { localStorage.setItem("blockos.uid", c); } catch (_) {}
    }
    return c;
  }
  const friends = {
    code: myCode,
    pretty: (c) => (c ? c.slice(0, 4) + "-" + c.slice(4) : ""),
    list: () => readJSON("blockos.friends"),
    isFriend: (code) => !!readJSON("blockos.friends")[code],
    add(code, name, avatar) {
      const f = readJSON("blockos.friends");
      f[code] = { name, avatar: avatar || {}, since: (f[code] && f[code].since) || Date.now() };
      writeJSON("blockos.friends", f);
      friends.clearRequest(code);
    },
    remove(code) { const f = readJSON("blockos.friends"); delete f[code]; writeJSON("blockos.friends", f); },
    requests: () => readJSON("blockos.requests"),
    addRequest(code, name, avatar) { const r = readJSON("blockos.requests"); r[code] = { name, avatar: avatar || {}, time: Date.now() }; writeJSON("blockos.requests", r); },
    clearRequest(code) { const r = readJSON("blockos.requests"); delete r[code]; writeJSON("blockos.requests", r); },
  };

  // ------------------------------------------------------------------ online play

  // Which server of this game to play on ("s1", "s2", ...). BlockOS opens games with
  // ?server=s2 from the server list; the room name gets the server added, e.g. "main-s2".
  const SERVER = (() => {
    const s = new URLSearchParams(location.search).get("server");
    return /^s\d{1,3}$/.test(s || "") ? s : "s1";
  })();
  const roomName = (room) => `${String(room || "main").slice(0, 16)}-${SERVER}`;

  function net(gameId, opts) {
    const o = opts || {};
    const me = player();
    const handlers = {};
    const api = {
      online: false,
      me: { id: null, name: me.name, avatar: me.avatar, uid: friends.code() },
      server: SERVER,
      players: new Map(),
      isHost: true,
      on(type, fn) { (handlers[type] = handlers[type] || []).push(fn); return api; },
      state(obj) { pendingState = obj; },
      event(obj) { send({ t: "e", e: obj }); },
      chat(i) {
        if (!QUICK_CHAT[i]) return;
        send({ t: "c", i });
        emit("chat", api.me, QUICK_CHAT[i]);
      },
      // Typed message to everyone in the game. The server filters it and sends it back to everyone.
      say(text) { const t = String(text || "").trim().slice(0, 120); if (t && chatMode() !== "off") send({ t: "say", text: t }); },
      friendRequest(code, kind) { send({ t: "fr", to: code, kind: kind || "request" }); },
      close() { closed = true; if (ws) ws.close(); },
    };
    const emit = (type, ...args) => (handlers[type] || []).forEach((fn) => { try { fn(...args); } catch (e) { console.error(e); } });
    let ws = null, closed = false, pendingState = null;
    const order = [];  // ids in join order, to pick the host

    function send(msg) {
      if (ws && ws.readyState === 1) ws.send(JSON.stringify(msg));
    }
    function updateHost() {
      api.isHost = !api.online || order.length === 0 || order[0] === api.me.id;
    }
    setInterval(() => {
      if (pendingState) { send({ t: "s", s: pendingState }); pendingState = null; }
    }, 100);

    const toPlayer = (p) => ({ id: p.id, name: p.name, avatar: p.avatar, uid: p.uid || null, state: p.s || null });

    function connect() {
      const url = serverAddress();
      if (!url || closed) return;
      try { ws = new WebSocket(url); } catch (_) { return; }
      ws.onopen = () => send({ t: "hello", game: gameId, room: roomName(o.room), name: me.name, avatar: me.avatar, uid: api.me.uid });
      ws.onmessage = (ev) => {
        let m;
        try { m = JSON.parse(ev.data); } catch (_) { return; }
        if (m.t === "welcome") {
          api.online = true;
          api.me.id = m.id;
          order.length = 0;
          api.players.clear();
          for (const p of m.players) {
            api.players.set(p.id, toPlayer(p));
            order.push(p.id);
          }
          order.push(m.id);
          updateHost();
          emit("status", true);
          for (const p of api.players.values()) emit("join", p);
        } else if (m.t === "join") {
          const p = toPlayer(m.p);
          api.players.set(p.id, p);
          order.push(p.id);
          updateHost();
          emit("join", p);
          if (o.chat !== false) chatLine(null, `${p.name}${p.uid && friends.isFriend(p.uid) ? " (your friend)" : ""} joined the game`);
        } else if (m.t === "leave") {
          const p = api.players.get(m.id);
          api.players.delete(m.id);
          const i = order.indexOf(m.id);
          if (i >= 0) order.splice(i, 1);
          updateHost();
          if (p) {
            emit("leave", p);
            if (o.chat !== false) chatLine(null, `${p.name} left the game`);
          }
        } else if (m.t === "s") {
          const p = api.players.get(m.id);
          if (p) { p.state = m.s; emit("state", p); }
        } else if (m.t === "e") {
          const p = api.players.get(m.id);
          if (p) emit("event", p, m.e);
        } else if (m.t === "c") {
          const p = api.players.get(m.id);
          if (p && QUICK_CHAT[m.i] && canSee(p)) emit("chat", p, QUICK_CHAT[m.i]);
        } else if (m.t === "say") {
          const p = m.id === api.me.id ? api.me : api.players.get(m.id);
          if (p && canSee(p)) emit("chat", p, String(m.text));
        } else if (m.t === "slow") {
          chatLine(null, "You're sending messages too fast. Wait a moment.");
        } else if (m.t === "dm") {
          // Private message from a friend: the desktop keeps the history; show a pop-up here.
          if (friends.isFriend(m.from) && chatMode() !== "off" && !muted()[m.from]) {
            gameToast(`Message from ${String(m.name || "a friend")}`, String(m.text), "#3b82f6");
            sfx("click");
          }
        } else if (m.t === "fr") {
          handleFriendMessage(api, m);
        } else if (m.t === "err") {
          closed = true;   // e.g. the server is full: don't keep retrying
          gameToast("Can't join this server", String(m.m || ""), "#ef4444");
        }
      };
      ws.onclose = () => {
        const was = api.online;
        api.online = false;
        api.players.forEach((p) => emit("leave", p));
        api.players.clear();
        order.length = 0;
        updateHost();
        if (was) emit("status", false);
        if (!closed) setTimeout(connect, 3000);  // try again
      };
    }
    connect();
    if (o.chat !== false) chatUI(api);
    return api;
  }

  function handleFriendMessage(api, m) {
    const name = String(m.name || "Player");
    if (m.kind === "request") {
      if (friends.isFriend(m.from)) { api.friendRequest(m.from, "accept"); return; }  // already friends: just confirm
      friends.addRequest(m.from, name, m.avatar);
      friendPrompt(api, m.from, name, m.avatar);
    } else if (m.kind === "accept") {
      friends.add(m.from, name, m.avatar);
      gameToast("New friend!", `You and ${name} are now friends.`, "#22c55e");
      sfx("coin");
    } else if (m.kind === "decline") {
      gameToast("Friend request", `${name} said no thanks.`, "#6b7280");
    } else if (m.kind === "remove") {
      friends.remove(m.from);
    }
    refreshPeople();
  }

  function friendPrompt(api, code, name, avatar) {
    const box = document.createElement("div");
    box.className = "kit-friend-prompt";
    const text = document.createElement("div");
    const b = document.createElement("b");
    b.textContent = name;
    text.append(b, document.createTextNode(" wants to be your friend"));
    const yes = document.createElement("button");
    yes.className = "kit-btn";
    yes.textContent = "Accept";
    const no = document.createElement("button");
    no.className = "kit-btn grey";
    no.textContent = "No thanks";
    yes.onclick = () => { friends.add(code, name, avatar); api.friendRequest(code, "accept"); box.remove(); gameToast("New friend!", `You and ${name} are now friends.`, "#22c55e"); refreshPeople(); };
    no.onclick = () => { friends.clearRequest(code); api.friendRequest(code, "decline"); box.remove(); };
    box.append(text, yes, no);
    document.body.appendChild(box);
    sfx("score");
  }

  // Roblox-style chat: a log in the top-left corner, a quick-chat menu (press / or click Chat)
  // and a People list with Add friend buttons.
  let chatLog = null;
  let refreshPeople = () => {};
  function chatLine(p, text) {
    if (!chatLog) return;
    const line = document.createElement("div");
    if (p) {
      const b = document.createElement("b");
      b.textContent = p.name + ": ";
      b.style.color = (p.avatar && p.avatar.torso) || "#facc15";
      line.appendChild(b);
    } else {
      line.className = "sys";
    }
    line.appendChild(document.createTextNode(text));
    chatLog.appendChild(line);
    while (chatLog.children.length > 8) chatLog.firstChild.remove();
    setTimeout(() => line.classList.add("old"), 12000);
  }
  function chatUI(api) {
    const wrap = document.createElement("div");
    wrap.className = "kit-chat";
    chatLog = document.createElement("div");
    chatLog.className = "kit-chat-log";
    const bar = document.createElement("div");
    bar.className = "kit-chat-bar";
    const chatBtn = document.createElement("button");
    chatBtn.className = "kit-chat-btn";
    chatBtn.title = "Chat (/)";
    chatBtn.textContent = "Chat";
    const peopleBtn = document.createElement("button");
    peopleBtn.className = "kit-chat-btn";
    peopleBtn.textContent = "People";
    bar.append(chatBtn, peopleBtn);

    // Type a message: Enter sends, an empty Enter (or the Chat button) closes the box.
    const box = document.createElement("form");
    box.className = "kit-chat-input";
    box.hidden = true;
    const input = document.createElement("input");
    input.type = "text";
    input.maxLength = 120;
    input.placeholder = "Say something (Enter to send)";
    input.autocomplete = "off";
    input.setAttribute("enterkeyhint", "send");
    const sendBtn = document.createElement("button");
    sendBtn.className = "kit-chat-btn";
    sendBtn.textContent = "Send";
    box.append(input, sendBtn);
    const closeBox = () => { box.hidden = true; input.blur(); };
    box.addEventListener("submit", (e) => {
      e.preventDefault();
      if (!input.value.trim()) return closeBox();
      api.say(input.value);
      input.value = "";
    });
    // Keep the game from reacting to the letters you type.
    for (const type of ["keydown", "keyup", "keypress"]) input.addEventListener(type, (e) => e.stopPropagation());

    // People in this game.
    const people = document.createElement("div");
    people.className = "kit-chat-panel kit-people";
    people.hidden = true;
    refreshPeople = () => {
      people.textContent = "";
      const head = document.createElement("div");
      head.className = "kit-people-head";
      head.textContent = `In this game - your friend code: ${friends.pretty(friends.code())}`;
      people.appendChild(head);
      if (api.players.size === 0) {
        const empty = document.createElement("div");
        empty.className = "kit-people-empty";
        empty.textContent = "Nobody else is here yet.";
        people.appendChild(empty);
      }
      const pending = friends.requests();
      const mutedNow = muted();
      for (const p of api.players.values()) {
        const row = document.createElement("div");
        row.className = "kit-people-row";
        const n = document.createElement("span");
        n.textContent = p.name;
        n.style.color = (p.avatar && p.avatar.torso) || "#fff";
        row.appendChild(n);
        const act = document.createElement("button");
        act.className = "kit-chat-btn";
        if (!p.uid) { act.textContent = "-"; act.disabled = true; }
        else if (friends.isFriend(p.uid)) { act.textContent = "Friends"; act.disabled = true; }
        else if (pending[p.uid]) {
          act.textContent = "Accept";
          act.onclick = () => { friends.add(p.uid, p.name, p.avatar); api.friendRequest(p.uid, "accept"); gameToast("New friend!", `You and ${p.name} are now friends.`, "#22c55e"); document.querySelectorAll(".kit-friend-prompt").forEach((x) => x.remove()); refreshPeople(); };
        } else {
          act.textContent = p.sent ? "Sent" : "Add friend";
          act.disabled = !!p.sent;
          act.onclick = () => { api.friendRequest(p.uid, "request"); p.sent = true; refreshPeople(); };
        }
        row.appendChild(act);
        if (p.uid) {
          const mute = document.createElement("button");
          mute.className = "kit-chat-btn";
          mute.textContent = mutedNow[p.uid] ? "Unmute" : "Mute";
          mute.onclick = () => { setMuted(p.uid, !mutedNow[p.uid]); refreshPeople(); };
          row.appendChild(mute);
        }
        people.appendChild(row);
      }
    };

    const openChat = () => {
      if (chatMode() === "off") { chatLine(null, "Chat is turned off in BlockOS Settings."); return; }
      people.hidden = true;
      box.hidden = false;
      input.focus();
    };
    chatBtn.onclick = () => (box.hidden ? openChat() : closeBox());
    peopleBtn.onclick = () => { closeBox(); people.hidden = !people.hidden; if (!people.hidden) refreshPeople(); };
    wrap.append(chatLog, bar, box, people);
    document.body.appendChild(wrap);
    wrap.hidden = true;
    api.on("status", (on) => {
      wrap.hidden = !on;
      if (on) chatLine(null, `You're playing online. ${api.players.size} other ${api.players.size === 1 ? "person is" : "people are"} here. Press / to chat.`);
    });
    api.on("join", () => { if (!people.hidden) refreshPeople(); });
    api.on("leave", () => { if (!people.hidden) refreshPeople(); });
    api.on("chat", (p, text) => chatLine(p, text));
    keyHandlers.push((code, e) => {
      if (code === "Slash" && api.online && box.hidden) { e.preventDefault(); openChat(); }
    });
  }

  window.Kit = {
    stage, pointer, loop, overlay, hud, best, sfx, finish, brick,
    key: (code) => held.has(code),
    onKey: (fn) => keyHandlers.push(fn),
    rand, randInt, pick, clamp,
    player, drawAvatar, badge, leaderboard, net, toast: gameToast,
    QUICK_CHAT, QUICK_CHAT_TABS, DEFAULT_LOOK, friends,
    colors: {
      red: "#ef4444", orange: "#fb923c", yellow: "#facc15", green: "#22c55e",
      teal: "#14b8a6", blue: "#3b82f6", purple: "#a855f7", pink: "#ec4899",
      white: "#f2f4f5", gray: "#6b7280", dark: "#1f2328", bg: "#0f1113",
    },
  };
})();
