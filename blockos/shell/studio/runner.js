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

  // allow-forms lets the kit's chat box use its submit event; the policy's form-action 'none'
  // still stops any form from sending data anywhere.
  const SANDBOX = "allow-scripts allow-pointer-lock allow-forms";
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

  function policy(server, inline) {
    const g = GAMES_URL + (inline ? " data:" : "");
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
    return `<!doctype html><html><head><base href="${attr(GAMES_URL)}"><meta http-equiv="Content-Security-Policy" content="${attr(policy(seed.server, !!o.kit))}"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><script>${shimSrc}</script>` + (o.kit || "") + String(code || "");
  }

  // On the web version (BlockOS in a browser, not the app or the VM) the host doesn't let the
  // sandbox load the kit's files, so BlockOS fetches them itself and hands them over as data: URLs:
  // kit.js and kit.css as tags at the very start, and the 3D kit through an import map so
  // import "./kit3d.js" and import "./easy3d.js" still work. Everything goes on line 1, so error
  // line numbers still match the editor. The game's own kit.js / kit.css tags are taken out.
  const LOCAL = location.protocol === "blockos:" || /^(127\.0\.0\.1|localhost|\[::1\])$/.test(location.hostname);
  const files = {};
  const text = (f) => files[f] || (files[f] = fetch(GAMES_URL + f).then((r) => { if (!r.ok) throw new Error(f); return r.text(); }));
  const dataUrl = (s, type) => `data:${type};base64,` + btoa(unescape(encodeURIComponent(s)));
  async function inlineKit(code) {
    const [kit, css, touch] = await Promise.all([text("kit.js"), text("kit.css"), text("touch.js")]);
    const js = (s) => dataUrl(s, "text/javascript");
    let head = `<link rel="stylesheet" href="${css ? dataUrl(css, "text/css") : ""}">` +
      `<script>window.BLOCKOS_TOUCH_URL=${JSON.stringify(js(touch))};</script><script src="${js(kit)}"></script>`;
    if (/kit3d|easy3d/.test(code)) {
      const [three, kit3d, easy] = await Promise.all([text("lib/three.min.js"), text("kit3d.js"), text("easy3d.js")]);
      const t3 = js(three);
      const k3 = js(kit3d.replace(/from\s+["']\.\/lib\/three\.min\.js["']/g, 'from "blockos-three"'));
      const imports = {
        "blockos-three": t3, [GAMES_URL + "lib/three.min.js"]: t3,
        [GAMES_URL + "kit3d.js"]: k3,
        [GAMES_URL + "easy3d.js"]: js(easy.replace(/from\s+["']\.\/kit3d\.js["']/g, `from ${JSON.stringify(GAMES_URL + "kit3d.js")}`)),
      };
      head = `<script type="importmap">${JSON.stringify({ imports }).replace(/</g, "\\u003c")}</script>` + head;
    }
    const kitFile = String.raw`(?:\.\.?\/)?kit\.(?:js|css)`;
    const stripped = code
      .replace(new RegExp(String.raw`<script\s+src=["']${kitFile}["']\s*>\s*</script>`, "gi"), "")
      .replace(new RegExp(String.raw`<link[^>\n]*href=["']${kitFile}["'][^>\n]*>`, "gi"), "");
    return { head, code: stripped };
  }

  // Put a game into an iframe (made sandboxed first: the sandbox flags apply from the next page load).
  function load(frame, code, opts) {
    frame.setAttribute("sandbox", SANDBOX);
    frame.removeAttribute("src");
    const run = (frame.blockosRun = (frame.blockosRun || 0) + 1);
    if (LOCAL && !api.forceInline) { frame.srcdoc = build(code, opts); return; }
    inlineKit(String(code || "")).then(
      (r) => { if (frame.blockosRun === run) frame.srcdoc = build(r.code, Object.assign({}, opts, { kit: r.head })); },
      () => { if (frame.blockosRun === run) frame.srcdoc = build(code, opts); },
    );
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

  const api = { SANDBOX, build, load, loadData, onSave, policy, forceInline: false };
  return api;
})();
