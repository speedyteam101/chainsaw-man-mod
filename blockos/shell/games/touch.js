/*
 * BlockOS touch controls: lets the keyboard-and-mouse games be played on phones and tablets.
 * Loaded by kit.js on touch screens only. It:
 *   - shows on-screen controls (a D-pad or joystick and buttons) that press the game's keys,
 *   - turns finger taps and drags on a game's canvas into mouse clicks and drags
 *     (a long press is a right-click),
 *   - offers the phone's keyboard for typing games,
 *   - asks you to turn the phone sideways in portrait.
 * Each game's layout is in LAYOUTS below, keyed by the game's folder name.
 */
(function () {
  "use strict";

  const A = "arrows", W = "wasd", LR = "lr";
  // pad: arrows | wasd | lr | stick (3D joystick on WASD) | {up,down,left,right codes}
  // buttons: [label, code] or [label, code, "left"] to put it on the left side
  const LAYOUTS = {
    "battle-tanks": { pad: A, buttons: [["Fire", "Space"]] },
    "blob-rush": { pad: W, buttons: [["Dash", "Space"]] },
    "block-bowling": { pad: A, buttons: [["Go", "Space"]] },
    "block-drop": { pad: A, buttons: [["Drop", "Space"], ["Hold", "KeyC"]] },
    "brick-2048": { pad: A },
    "brick-defense": { buttons: [["Wave", "Space"], ["Upgrade", "KeyU"], ["Sell", "KeyS"], ["Speed", "KeyF"]] },
    "brick-legends": { pad: A, buttons: [["OK", "Enter"], ["Back", "KeyX"], ["Menu", "KeyQ"], ["Map", "KeyM"]] },
    "brick-pinball": { buttons: [["Flip", "ArrowLeft", "left"], ["Launch", "Space"], ["Flip", "ArrowRight"]] },
    "brick-plaza": { pad: "stick", buttons: [["Jump", "Space"], ["Use", "KeyE"], ["Wave", "Digit1"], ["Dance", "Digit2"], ["Cheer", "Digit3"], ["Sit", "Digit4"]] },
    "brick-snake": { pad: A },
    "bubble-pop": { buttons: [["Swap", "KeyX"]] },
    "color-sort": { buttons: [["Undo", "KeyZ"], ["+Tube", "KeyT"]] },
    "cops-chase": { pad: A },
    "disaster-island": { pad: LR, buttons: [["Jump", "Space"]] },
    "dungeon-quest": { pad: "stick", buttons: [["Attack", "KeyF"], ["Jump", "Space"], ["Q", "KeyQ"], ["E", "KeyE"], ["R", "KeyR"], ["Potion", "Digit1"], ["Bag", "KeyI"]] },
    "fishing-frenzy": { buttons: [["Bucket", "KeyB"], ["Shop", "KeyU"], ["Journal", "KeyJ"]] },
    "jump-tower": { pad: LR },
    "kart-dash": { pad: A, buttons: [["Item", "Space"]] },
    "lava-floor": { pad: A, buttons: [["Hop", "Space"]] },
    "lights-out": { buttons: [["Hint", "KeyH"]] },
    "math-blitz": { keyboard: true },
    "maze-escape": { pad: A },
    "mega-obby": { pad: "stick", buttons: [["Jump", "Space"], ["Reset", "KeyR"]] },
    "mining-sim": { pad: A, buttons: [["Surface", "KeyR"], ["Shop", "KeyE"]] },
    "ninja-run": { buttons: [["Slide", "ArrowDown", "left"], ["Jump", "Space"]] },
    "obby-run": { pad: A, buttons: [["Jump", "Space"]] },
    "pipe-connect": { buttons: [["Flow", "KeyF"]] },
    "road-hopper": { pad: A },
    "solitaire": { buttons: [["Draw", "Space"], ["Undo", "KeyU"], ["Hint", "KeyH"]] },
    "space-blaster": { pad: A, buttons: [["Fire", "Space"]] },
    "sudoku": { keyboard: true, buttons: [["Notes", "KeyN"], ["Undo", "KeyU"]] },
    "survival-island": { pad: "stick", buttons: [["Use", "KeyF"], ["Jump", "Space"], ["Craft", "KeyC"], ["Eat", "KeyE"], ["Rotate", "KeyR"], ["Remove", "KeyX"]] },
    "sword-arena": { pad: "stick", buttons: [["Slash", "KeyF"], ["Jump", "Space"]] },
    "sword-duel": { pad: { up: "KeyW", down: "KeyS", left: "KeyA", right: "KeyD" }, buttons: [["Slash", "KeyJ"], ["Lunge", "KeyK"]] },
    "tower-climb": { pad: A, buttons: [["Jump", "Space"]] },
    "tower-rush": { pad: "stick", buttons: [["Jump", "Space"], ["Reset", "KeyR"]] },
    "turbo-lanes": { buttons: [["Brake", "ArrowDown", "left"], ["Boost", "Space"]] },
    "typing-racer": { keyboard: true },
    "_example3d": { pad: "stick", buttons: [["Jump", "Space"]] },
  };

  const id = (location.pathname.match(/games\/([^/]+)\//) || [])[1] || "";
  const layout = LAYOUTS[id] || {};

  // ---------------------------------------------------------------- keys

  const KEY_NAMES = { Space: " ", Enter: "Enter", Backspace: "Backspace", Tab: "Tab", ShiftLeft: "Shift" };
  function keyFor(code) {
    if (KEY_NAMES[code]) return KEY_NAMES[code];
    if (code.startsWith("Key")) return code.slice(3).toLowerCase();
    if (code.startsWith("Digit")) return code.slice(5);
    return code;  // ArrowLeft etc.
  }
  function keyEvent(type, code, key) {
    const target = document.activeElement && document.activeElement !== document.body ? document.activeElement : document.body;
    target.dispatchEvent(new KeyboardEvent(type, { code, key: key || keyFor(code), bubbles: true, cancelable: true }));
  }
  const press = (code) => keyEvent("keydown", code);
  const release = (code) => keyEvent("keyup", code);

  // A control that holds its key down while touched.
  function holdButton(el, code) {
    let down = false;
    const on = (e) => { e.preventDefault(); if (!down) { down = true; el.classList.add("on"); press(code); } };
    const off = (e) => { e.preventDefault(); if (down) { down = false; el.classList.remove("on"); release(code); } };
    el.addEventListener("pointerdown", (e) => { try { el.setPointerCapture(e.pointerId); } catch (_) {} on(e); });
    el.addEventListener("pointerup", off);
    el.addEventListener("pointercancel", off);
    el.addEventListener("lostpointercapture", off);
  }

  function button(label, code, cls) {
    const b = document.createElement("button");
    b.className = "tc-btn " + (cls || "");
    b.textContent = label;
    holdButton(b, code);
    return b;
  }

  // ---------------------------------------------------------------- D-pad and joystick

  function dpad(codes) {
    const pad = document.createElement("div");
    pad.className = "tc-pad" + (codes.up ? "" : " lr");
    const dirs = [["up", "▲"], ["left", "◀"], ["right", "▶"], ["down", "▼"]];
    for (const [dir, arrow] of dirs) {
      if (!codes[dir]) continue;
      const b = button(arrow, codes[dir], "tc-d-" + dir);
      pad.appendChild(b);
    }
    return pad;
  }

  // Joystick for the 3D games: presses W/A/S/D depending on the direction you push.
  function joystick() {
    const base = document.createElement("div");
    base.className = "tc-stick";
    const knob = document.createElement("i");
    base.appendChild(knob);
    const held = new Set();
    let active = null, cx = 0, cy = 0;
    const R = 50;
    function set(dx, dy) {
      const want = new Set();
      const len = Math.hypot(dx, dy);
      if (len > R * 0.3) {
        const a = Math.atan2(dy, dx);
        if (Math.cos(a) > 0.38) want.add("KeyD");
        if (Math.cos(a) < -0.38) want.add("KeyA");
        if (Math.sin(a) > 0.38) want.add("KeyS");
        if (Math.sin(a) < -0.38) want.add("KeyW");
      }
      for (const c of held) if (!want.has(c)) { release(c); held.delete(c); }
      for (const c of want) if (!held.has(c)) { press(c); held.add(c); }
      const k = Math.min(1, R / (len || 1));
      knob.style.transform = `translate(${dx * k}px, ${dy * k}px)`;
    }
    base.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      active = e.pointerId;
      try { base.setPointerCapture(e.pointerId); } catch (_) {}
      const r = base.getBoundingClientRect();
      cx = r.left + r.width / 2;
      cy = r.top + r.height / 2;
      set(e.clientX - cx, e.clientY - cy);
    });
    base.addEventListener("pointermove", (e) => { if (e.pointerId === active) set(e.clientX - cx, e.clientY - cy); });
    const end = (e) => { if (e.pointerId === active) { active = null; set(0, 0); } };
    base.addEventListener("pointerup", end);
    base.addEventListener("pointercancel", end);
    return base;
  }

  // ---------------------------------------------------------------- phone keyboard

  function keyboardButton() {
    const input = document.createElement("input");
    input.className = "tc-input";
    input.setAttribute("autocapitalize", "off");
    input.setAttribute("autocomplete", "off");
    input.setAttribute("autocorrect", "off");
    input.setAttribute("spellcheck", "false");
    input.setAttribute("enterkeyhint", "go");
    input.addEventListener("beforeinput", (e) => {
      e.preventDefault();
      if (e.inputType === "deleteContentBackward") { press("Backspace"); release("Backspace"); return; }
      if (e.inputType === "insertLineBreak") { press("Enter"); release("Enter"); return; }
      for (const ch of e.data || "") {
        let code = "";
        if (/[a-z]/i.test(ch)) code = "Key" + ch.toUpperCase();
        else if (/[0-9]/.test(ch)) code = "Digit" + ch;
        else if (ch === " ") code = "Space";
        else if (ch === "." ) code = "Period";
        else if (ch === ",") code = "Comma";
        else if (ch === "-") code = "Minus";
        else if (ch === "'") code = "Quote";
        keyEvent("keydown", code, ch);
        keyEvent("keyup", code, ch);
      }
    });
    input.addEventListener("keydown", (e) => {
      // Some phone keyboards send real key events for Enter/Backspace; pass them on once.
      if (e.isTrusted && (e.key === "Enter" || e.key === "Backspace")) { e.preventDefault(); press(e.key); release(e.key); }
    });
    const b = document.createElement("button");
    b.className = "tc-btn tc-kbd";
    b.textContent = "Keyboard";
    b.addEventListener("click", () => { input.focus(); });
    document.body.appendChild(input);
    return b;
  }

  // ---------------------------------------------------------------- taps and drags on the canvas

  function mouse(type, t, button, target) {
    target.dispatchEvent(new MouseEvent(type, {
      bubbles: true, cancelable: true, clientX: t.clientX, clientY: t.clientY,
      button, buttons: type === "mouseup" || type === "click" ? 0 : button === 2 ? 2 : 1, view: window,
    }));
  }
  let touchStart = null, longTimer = 0, longFired = false;
  document.addEventListener("touchstart", (e) => {
    const target = e.target;
    if (target.tagName !== "CANVAS" || e.touches.length > 1) return;
    const t = e.changedTouches[0];
    const is3d = target.classList.contains("kit-3d");
    touchStart = { x: t.clientX, y: t.clientY, time: Date.now(), target, is3d, moved: false };
    longFired = false;
    if (!is3d) {
      e.preventDefault();   // no scrolling, zooming or delayed fake mouse events
      mouse("mousemove", t, 0, target);
      mouse("mousedown", t, 0, target);
    }
    clearTimeout(longTimer);
    longTimer = setTimeout(() => {
      // Long press = right-click (flags, marks, swaps...).
      if (!touchStart || touchStart.moved || is3d) return;
      longFired = true;
      mouse("mouseup", t, 0, target);
      mouse("mousedown", t, 2, target);
      target.dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: t.clientX, clientY: t.clientY, button: 2 }));
      mouse("mouseup", t, 2, target);
      if (navigator.vibrate) navigator.vibrate(15);
    }, 450);
  }, { passive: false });
  document.addEventListener("touchmove", (e) => {
    if (!touchStart) return;
    const t = e.changedTouches[0];
    if (Math.hypot(t.clientX - touchStart.x, t.clientY - touchStart.y) > 10) touchStart.moved = true;
    if (!touchStart.is3d) { e.preventDefault(); mouse("mousemove", t, 0, touchStart.target); }
  }, { passive: false });
  document.addEventListener("touchend", (e) => {
    if (!touchStart) return;
    clearTimeout(longTimer);
    const t = e.changedTouches[0];
    const s = touchStart;
    touchStart = null;
    if (longFired) return;
    if (s.is3d) {
      // In 3D, a quick tap is a click (attack, use); drags only turn the camera.
      if (!s.moved && Date.now() - s.time < 350) {
        mouse("mousedown", t, 0, s.target);
        mouse("mouseup", t, 0, s.target);
        mouse("click", t, 0, s.target);
      }
      return;
    }
    e.preventDefault();
    mouse("mouseup", t, 0, s.target);
    if (!s.moved) mouse("click", t, 0, s.target);
  }, { passive: false });

  // ---------------------------------------------------------------- build the controls

  function codesFor(pad) {
    if (pad === "arrows") return { up: "ArrowUp", down: "ArrowDown", left: "ArrowLeft", right: "ArrowRight" };
    if (pad === "wasd") return { up: "KeyW", down: "KeyS", left: "KeyA", right: "KeyD" };
    if (pad === "lr") return { left: "ArrowLeft", right: "ArrowRight" };
    return pad;
  }

  function build() {
    const wrap = document.createElement("div");
    wrap.className = "tc";
    const left = document.createElement("div");
    left.className = "tc-left";
    const right = document.createElement("div");
    right.className = "tc-right";
    if (layout.pad === "stick") left.appendChild(joystick());
    else if (layout.pad) left.appendChild(dpad(codesFor(layout.pad)));
    for (const [label, code, side] of layout.buttons || []) (side === "left" ? left : right).appendChild(button(label, code));
    if (layout.keyboard) right.appendChild(keyboardButton());
    wrap.append(left, right);
    document.body.appendChild(wrap);

    // Show/hide toggle, for games where the controls would be in the way.
    if (layout.pad || (layout.buttons && layout.buttons.length) || layout.keyboard) {
      const toggle = document.createElement("button");
      toggle.className = "tc-toggle";
      toggle.textContent = "Controls";
      toggle.addEventListener("click", () => wrap.classList.toggle("hidden"));
      document.body.appendChild(toggle);
    }

    const turn = document.createElement("div");
    turn.className = "tc-turn";
    turn.textContent = "Turn your phone sideways for a bigger game";
    document.body.appendChild(turn);
  }

  document.documentElement.classList.add("touch");
  if (document.body) build();
  else addEventListener("DOMContentLoaded", build);
})();
