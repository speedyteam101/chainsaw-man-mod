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
 */
(function () {
  "use strict";

  const held = new Set();
  const keyHandlers = [];
  const GAME_KEYS = new Set(["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"]);

  addEventListener("keydown", (e) => {
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
    function fit() {
      const s = Math.min((innerWidth - 24) / w, (innerHeight - 24) / h);
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
      const dt = Math.min(0.05, (t - last) / 1000 || 0);
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

  window.Kit = {
    stage, pointer, loop, overlay, hud, best, sfx, finish, brick,
    key: (code) => held.has(code),
    onKey: (fn) => keyHandlers.push(fn),
    rand, randInt, pick, clamp,
    colors: {
      red: "#ef4444", orange: "#fb923c", yellow: "#facc15", green: "#22c55e",
      teal: "#14b8a6", blue: "#3b82f6", purple: "#a855f7", pink: "#ec4899",
      white: "#f2f4f5", gray: "#6b7280", dark: "#1f2328", bg: "#0f1113",
    },
  };
})();
