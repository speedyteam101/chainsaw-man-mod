/* Runs a game made in the Create studio (or downloaded from Community) in a locked sandbox.
 *
 * The game's HTML goes into an <iframe sandbox="allow-scripts allow-pointer-lock" srcdoc="...">.
 * Without "allow-same-origin" the game gets its own blank origin, so it can't read BlockOS's
 * saved data (Bricks, friends, other games), open pop-ups, leave the page or download files.
 * A Content-Security-Policy put in front of the game's code also stops it loading anything from
 * the internet: it can only use the BlockOS game kit (games/kit.js, kit3d.js...), pictures and
 * sounds written into the code itself, and the game server you're playing on.
 *
 * Games still get a localStorage (kept per game by BlockOS, see onSave) and can read your name,
 * avatar and settings, so Kit.player(), Kit.best() and Kit.net() work as in BlockOS's own games.
 */
window.StudioRunner = (function () {
  "use strict";

  const SANDBOX = "allow-scripts allow-pointer-lock";
  const GAMES_URL = new URL("games/", location.href).href;
  const MAX_DATA = 200000;   // characters of saved data per game

  // Settings a game may read (never write) from BlockOS.
  const READONLY_KEYS = ["blockos.muted", "blockos.chatMode", "blockos.uid", "blockos.friends", "blockos.mutedPlayers"];

  function readonlyData() {
    const out = {};
    try {
      for (const k of READONLY_KEYS) { const v = localStorage.getItem(k); if (v !== null) out[k] = v; }
      const st = JSON.parse(localStorage.getItem("blockos.state.v1")) || {};
      out["blockos.state.v1"] = JSON.stringify({ name: st.name, avatar: st.avatar });
    } catch (_) {}
    return out;
  }

  // ws://192.168.1.5:8790 -> "ws://192.168.1.5:8790"; anything odd -> null.
  function serverSource(server) {
    try {
      const u = new URL(server);
      if (u.protocol !== "ws:" && u.protocol !== "wss:") return null;
      return `${u.protocol}//${u.host}`;
    } catch (_) { return null; }
  }

  function policy(server) {
    const g = GAMES_URL;
    return [
      "default-src 'none'",
      `script-src 'unsafe-inline' ${g}`,
      `style-src 'unsafe-inline' ${g}`,
      `img-src data: blob: ${g}`,
      `font-src data: ${g}`,
      "media-src data: blob:",
      `connect-src ${serverSource(server) || "'none'"}`,
      "base-uri 'none'",
      "form-action 'none'",
      "frame-src 'none'",
      "worker-src 'none'",
      "object-src 'none'",
      "manifest-src 'none'",
    ].join("; ");
  }

  // Runs inside the game before its own code. Kept on one line (see build) so line numbers in
  // error messages match the lines in the editor.
  function shim(seed) {
    var data = seed.data || {}, ro = seed.readonly || {}, mem = {};
    var has = function (o, k) { return Object.prototype.hasOwnProperty.call(o, k); };
    var timer = 0;
    var save = function () {
      clearTimeout(timer);
      timer = setTimeout(function () { try { parent.postMessage({ type: "blockos:studio-save", data: data }, "*"); } catch (e) {} }, 250);
    };
    var makeStore = function (get, persist) {
      return {
        getItem: function (k) { k = String(k); var d = get(); return has(d, k) ? d[k] : (persist && has(ro, k) ? ro[k] : null); },
        setItem: function (k, v) { get()[String(k)] = String(v); if (persist) save(); },
        removeItem: function (k) { delete get()[String(k)]; if (persist) save(); },
        clear: function () { var d = get(); Object.keys(d).forEach(function (k) { delete d[k]; }); if (persist) save(); },
        key: function (i) { var ks = Object.keys(get()); return i >= 0 && i < ks.length ? ks[i] : null; },
        get length() { return Object.keys(get()).length; },
      };
    };
    try { Object.defineProperty(window, "localStorage", { value: makeStore(function () { return data; }, true), configurable: true }); } catch (e) {}
    try { Object.defineProperty(window, "sessionStorage", { value: makeStore(function () { return mem; }, false), configurable: true }); } catch (e) {}
    window.BLOCKOS_SERVER = seed.server || "";
    window.BLOCKOS_STUDIO = { id: seed.id };
    var post = function (level, parts, line) {
      var text = parts.map(function (p) {
        if (typeof p === "string") return p;
        if (p instanceof Error) return p.name + ": " + p.message;
        try { return JSON.stringify(p); } catch (e) { return String(p); }
      }).join(" ").slice(0, 2000);
      try { parent.postMessage({ type: "blockos:studio-log", level: level, text: text, line: line || 0 }, "*"); } catch (e) {}
    };
    ["log", "info", "warn", "error"].forEach(function (level) {
      var orig = console[level];
      console[level] = function () { post(level, [].slice.call(arguments)); if (orig) orig.apply(console, arguments); };
    });
    window.addEventListener("error", function (e) {
      if (e.message) post("error", [e.message.replace(/^Uncaught /, "")], e.lineno);
      else if (e.target && e.target.src) post("error", ["Couldn't load " + e.target.src]);
    }, true);
    window.addEventListener("unhandledrejection", function (e) { post("error", [e.reason instanceof Error ? e.reason : String(e.reason)]); });
    document.addEventListener("securitypolicyviolation", function (e) {
      post("warn", ["Blocked " + (e.blockedURI || "a resource") + ": games can only use the BlockOS kit, pictures and sounds inside their own code, and the game server."]);
    });
  }

  // The full page for the sandbox. `code` is what the person wrote: a whole HTML page or just a
  // piece of one. Our part comes first, so its policy and <base> apply before any of their code
  // runs; the browser ignores their own <!doctype>, <html> and <head> tags after ours.
  function build(code, opts) {
    const o = opts || {};
    const seed = {
      id: String(o.id || "draft"),
      server: serverSource(o.server) ? o.server : "",
      data: o.data || {},
      readonly: readonlyData(),
    };
    const json = JSON.stringify(seed).replace(/</g, "\\u003c").replace(/\u2028/g, "\\u2028").replace(/\u2029/g, "\\u2029");
    const attr = (s) => s.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
    const shimSrc = "(" + shim.toString().replace(/\n\s*/g, " ") + ")(" + json + ");";
    return `<!doctype html><html><head><base href="${attr(GAMES_URL)}"><meta http-equiv="Content-Security-Policy" content="${attr(policy(seed.server))}"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><script>${shimSrc}</script>` + String(code || "");
  }

  // Put a game into an iframe (made sandboxed first: the sandbox flags apply from the next page load).
  function load(frame, code, opts) {
    frame.setAttribute("sandbox", SANDBOX);
    frame.removeAttribute("src");
    frame.srcdoc = build(code, opts);
  }

  // Saved data for a game: localStorage key "blockos.studio.data.<id>".
  function loadData(id) {
    try { return JSON.parse(localStorage.getItem("blockos.studio.data." + id)) || {}; } catch (_) { return {}; }
  }
  function onSave(id, data) {
    if (!data || typeof data !== "object") return;
    const clean = {};
    for (const [k, v] of Object.entries(data)) if (typeof v === "string" && !READONLY_KEYS.includes(k) && k !== "blockos.state.v1") clean[k] = v;
    const text = JSON.stringify(clean);
    if (text.length > MAX_DATA) return;
    try { localStorage.setItem("blockos.studio.data." + id, text); } catch (_) {}
  }

  return { SANDBOX, build, load, loadData, onSave, policy };
})();
