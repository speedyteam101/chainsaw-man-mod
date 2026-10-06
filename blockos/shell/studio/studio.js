/* BlockOS Create (write your own games with code) and Community (play games other players published).
 *
 * Your games are saved on this computer (localStorage "blockos.studio"). Publishing sends one to the
 * game server you're online on; the server keeps it, and a moderator (the server's owner) approves
 * it before other players see it on the Community page. Every made-by-a-player game runs inside
 * StudioRunner's sandbox (studio/runner.js), in the editor's preview and when played.
 *
 * app.js creates this with BlockStudio(ctx) and shows createPage / communityPage as pages.
 */
window.BlockStudio = function (ctx) {
  "use strict";

  const { $, $$, esc, icon, toast, openModal, closeModal, confirmDialog } = ctx;
  const GENRES = ["Action", "Adventure", "Arcade", "Board", "Card", "Obby", "Puzzle", "Racing", "RPG", "Science", "Simulator", "Sports", "Strategy", "Word"];
  const COLORS = ["#ef4444", "#f97316", "#f59e0b", "#22c55e", "#14b8a6", "#3b82f6", "#6366f1", "#a855f7", "#ec4899", "#64748b"];
  const MAX_CODE = 300000;
  const STORE = "blockos.studio";
  const REASONS = [
    ["rude", "Rude, mean or swearing"],
    ["scary", "Too scary or violent"],
    ["personal", "Shows someone's personal information"],
    ["broken", "Doesn't work"],
    ["copied", "Copied from someone else"],
    ["other", "Something else"],
  ];

  // ---------------------------------------------------------------- your games

  function loadStore() {
    try { const s = JSON.parse(localStorage.getItem(STORE)); if (s && s.games) return s; } catch (_) {}
    return { games: {} };
  }
  const store = loadStore();
  function saveStore() {
    try { localStorage.setItem(STORE, JSON.stringify(store)); return true; }
    catch (_) { toast("Couldn't save: BlockOS's storage on this computer is full. Save some games to files and delete them here."); return false; }
  }
  const LETTERS = "abcdefghijkmnpqrstuvwxyz23456789";
  const newId = () => Array.from(crypto.getRandomValues(new Uint8Array(8)), (b) => LETTERS[b % 32]).join("");
  const myGames = () => Object.values(store.games).sort((a, b) => b.updated - a.updated);
  function createGame(fields) {
    const now = Date.now();
    const g = Object.assign({ id: newId(), title: "My game", desc: "", genre: "Arcade", color: "#3b82f6", code: "", created: now, updated: now, pub: {} }, fields);
    g.title = String(g.title).slice(0, 40);
    store.games[g.id] = g;
    saveStore();
    return g;
  }
  const thumbSrc = (g) => ctx.fallbackThumb({ title: g.title || "?", color: /^#[0-9a-f]{6}$/i.test(g.color) ? g.color : "#3b82f6" });
  function ago(t) {
    const s = (Date.now() - t) / 1000;
    if (s < 60) return "just now";
    if (s < 3600) return Math.floor(s / 60) + " min ago";
    if (s < 86400) return Math.floor(s / 3600) + " h ago";
    const d = Math.floor(s / 86400);
    return d === 1 ? "yesterday" : d + " days ago";
  }
  const titleFromHtml = (code) => ((code.match(/<title>([^<]{1,60})<\/title>/i) || [])[1] || "").trim();

  // ---------------------------------------------------------------- Create page

  function createPage(page, view) {
    const g = view.studioGame && store.games[view.studioGame];
    if (g) return editorPage(page, g);
    view.studioGame = null;
    const list = myGames();
    page.innerHTML = `<h1 class="page-title">Create</h1>
      <div class="panel create-hero">
        <h2>Make your own games</h2>
        <p class="hint">Write games with code, the same way BlockOS's own games are made. Start from a template, change it, press
          <b>Run</b> to try it, then <b>Publish</b> it so other players can play it on the Community page.</p>
        <div class="btns"><button class="btn green" data-st="new">New game</button>
          <button class="btn" data-st="import">Open a file</button>
          ${hasHelp() ? '<button class="btn" data-st="help">Help guide</button>' : ""}</div>
        <input type="file" id="stFile" accept=".html,.htm,text/html" hidden>
      </div>
      ${list.length ? `<h2 class="sub-title">Your games</h2><div class="grid">${list.map((x) => `
        <button class="tile" data-st-edit="${x.id}"><div class="thumb"><img src="${thumbSrc(x)}" alt=""></div>
          <div class="t-name">${esc(x.title)}</div>
          <div class="t-meta"><span>${esc(x.genre)}</span><span>Edited ${ago(x.updated)}</span></div></button>`).join("")}</div>`
        : `<div class="empty">You haven't made any games yet. Press <b>New game</b> to start from a template.</div>`}`;
    $("#stFile").onchange = (e) => importFile(e.target.files[0]);
  }

  function chooseTemplate() {
    const list = window.STUDIO_TEMPLATES || [];
    openModal(`<button class="icon-btn modal-close" data-close>${icon("close")}</button>
      <div class="st-dialog"><h2>Start a new game</h2><p class="hint">Pick a template to start from. You can change everything.</p>
      <div class="st-templates">${list.map((t) => `
        <button class="st-template" data-st-template="${esc(t.id)}"><span class="st-swatch" style="background:${esc(t.color)}"></span>
          <b>${esc(t.title)}</b><small>${esc(t.description)}</small></button>`).join("")}
        <button class="st-template" data-st-template=""><span class="st-swatch" style="background:#64748b"></span>
          <b>Empty page</b><small>Nothing at all. For when you know what you're doing.</small></button></div></div>`);
  }

  async function startFromTemplate(id) {
    const t = (window.STUDIO_TEMPLATES || []).find((x) => x.id === id);
    let code = EMPTY_PAGE;
    if (t) {
      try {
        const res = await fetch("studio/templates/" + t.file);
        if (!res.ok) throw new Error(res.statusText);
        code = await res.text();
      } catch (_) { return toast("Couldn't load that template."); }
    }
    closeModal();
    const g = createGame({ title: t ? "My " + t.title : "My game", genre: t ? t.genre : "Arcade", color: t ? t.color : "#3b82f6", code });
    ctx.go("create", { studioGame: g.id });
  }
  const EMPTY_PAGE = `<!doctype html>
<html>
<head>
  <title>My game</title>
  <link rel="stylesheet" href="kit.css">
</head>
<body>
  <script src="kit.js"></script>
  <script>
    // Your code goes here. Press Run (Ctrl+Enter) to try it.
  </script>
</body>
</html>
`;

  function importFile(file) {
    if (!file) return;
    if (file.size > MAX_CODE * 3) return toast("That file is too big for a BlockOS game.");
    const r = new FileReader();
    r.onload = () => {
      const code = String(r.result || "");
      if (code.length > MAX_CODE) return toast(`That file is too big (games can have up to ${MAX_CODE.toLocaleString()} characters).`);
      const title = titleFromHtml(code) || file.name.replace(/\.html?$/i, "").slice(0, 40) || "My game";
      const g = createGame({ title, code });
      toast(`Opened <b>${esc(title)}</b>.`);
      ctx.go("create", { studioGame: g.id });
    };
    r.readAsText(file);
  }

  // ---------------------------------------------------------------- the editor

  let ed = null;   // { game, ta, hi, gutter, preview, log, timer }

  function editorPage(page, g) {
    // render() runs often (friend messages, online status...): keep the editor as it is if it's already open.
    if (ed && ed.game === g && page.contains(ed.ta)) return;
    page.innerHTML = `<div class="studio" data-id="${g.id}">
      <div class="st-bar">
        <button class="btn" data-st="back" title="Back to your games">${icon("back")}</button>
        <input id="stTitle" class="st-title" maxlength="40" value="${esc(g.title)}" aria-label="Game title" spellcheck="false">
        <span class="st-saved" id="stSaved">Saved</span>
        <div class="st-actions">
          <button class="btn green" data-st="run" title="Run (Ctrl+Enter)">${icon("play")}<span>Run</span></button>
          <button class="btn" data-st="play" title="Play full screen">${icon("expand")}<span>Play</span></button>
          <button class="btn" data-st="settings" title="Title, description, genre and color">${icon("settings")}<span>Settings</span></button>
          <button class="btn" data-st="export" title="Save a copy to a file">${icon("download")}<span>Save file</span></button>
          ${hasHelp() ? '<button class="btn" data-st="help" title="Help guide">?<span>Help</span></button>' : ""}
          <button class="btn st-publish" data-st="publish">${icon("upload")}<span>Publish</span></button>
        </div>
      </div>
      <div class="st-main">
        <div class="st-editor">
          <div class="st-gutter" id="stGutter" aria-hidden="true"></div>
          <div class="st-code"><pre id="stHi" aria-hidden="true"></pre>
            <textarea id="stCode" spellcheck="false" autocapitalize="off" autocomplete="off" autocorrect="off" wrap="off" aria-label="Code"></textarea></div>
        </div>
        <div class="st-side">
          <div class="st-preview"><iframe id="stPreview" title="Preview" allow="autoplay; fullscreen"></iframe></div>
          <div class="st-out"><div class="st-out-head"><b>Output</b><small id="stCount"></small><button class="btn small" data-st="clear">Clear</button></div>
            <div id="stLog" class="st-log"></div></div>
        </div>
      </div></div>`;
    ed = { game: g, ta: $("#stCode"), hi: $("#stHi"), gutter: $("#stGutter"), preview: $("#stPreview"), log: $("#stLog"), timer: 0, errorLines: new Set(), lines: 0 };
    ed.ta.value = g.code;
    ed.ta.addEventListener("input", onEdit);
    ed.ta.addEventListener("scroll", syncScroll);
    ed.ta.addEventListener("keydown", onKey);
    $("#stTitle").onchange = (e) => { g.title = e.target.value.trim().slice(0, 40) || "My game"; e.target.value = g.title; touch(); };
    paint();
    run();
  }

  function touch() {
    ed.game.updated = Date.now();
    if (saveStore()) $("#stSaved").textContent = "Saved";
  }
  function onEdit() {
    $("#stSaved").textContent = "Saving...";
    if (ed.ta.value.length > MAX_CODE) $("#stSaved").textContent = "Too long to publish!";
    clearTimeout(ed.timer);
    ed.timer = setTimeout(() => { ed.game.code = ed.ta.value; touch(); }, 500);
    ed.errorLines.clear();
    schedulePaint();
  }
  function saveNow() {
    if (!ed) return;
    clearTimeout(ed.timer);
    ed.game.code = ed.ta.value;
    touch();
  }

  // Syntax colors: a simple pass over the text that knows about HTML tags, JavaScript words,
  // strings, numbers and comments. Good enough to read code by; it isn't a full parser.
  const KEYWORDS = new Set(("break case catch class const continue default delete do else export extends false finally for function if " +
    "import in instanceof let new null of return static super switch this throw true try typeof undefined var void while yield async await").split(" "));
  const TOKEN = /(<!--[\s\S]*?(?:-->|$))|(\/\*[\s\S]*?(?:\*\/|$))|(\/\/[^\n]*)|("(?:[^"\\\n]|\\.)*"?|'(?:[^'\\\n]|\\.)*'?|`(?:[^`\\]|\\[\s\S])*`?)|(<\/?[a-zA-Z][\w-]*|\/?>)|(\b\d+(?:\.\d+)?\b)|([A-Za-z_$][\w$]*)/g;
  const escText = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  function highlight(text) {
    if (text.length > 120000) return escText(text);   // very big files: no colors, so typing stays fast
    let out = "", last = 0, m;
    TOKEN.lastIndex = 0;
    while ((m = TOKEN.exec(text))) {
      if (m[0] === "") { TOKEN.lastIndex++; continue; }
      out += escText(text.slice(last, m.index));
      const cls = m[1] || m[2] || m[3] ? "c" : m[4] ? "s" : m[5] ? "t" : m[6] ? "n" : KEYWORDS.has(m[7]) ? "k" : "";
      out += cls ? `<span class="tk-${cls}">${escText(m[0])}</span>` : escText(m[0]);
      last = TOKEN.lastIndex;
    }
    return out + escText(text.slice(last));
  }
  let paintQueued = false;
  function schedulePaint() {
    if (paintQueued) return;
    paintQueued = true;
    requestAnimationFrame(() => { paintQueued = false; if (ed) paint(); });
  }
  function paint() {
    const text = ed.ta.value;
    ed.hi.innerHTML = highlight(text) + "\n";
    const n = text.split("\n").length;
    let nums = "";
    for (let i = 1; i <= n; i++) nums += ed.errorLines.has(i) ? `<b>${i}</b>\n` : i + "\n";
    ed.gutter.innerHTML = nums;
    syncScroll();
  }
  function syncScroll() {
    ed.hi.style.transform = `translate(${-ed.ta.scrollLeft}px, ${-ed.ta.scrollTop}px)`;
    ed.gutter.style.transform = `translateY(${-ed.ta.scrollTop}px)`;
  }

  // Typing helpers: Tab indents, Enter keeps the indent, Ctrl+Enter runs, Ctrl+S saves.
  function insert(text) {
    // execCommand keeps the browser's undo (Ctrl+Z) working; setRangeText is the fallback.
    if (!document.execCommand("insertText", false, text)) {
      const ta = ed.ta;
      ta.setRangeText(text, ta.selectionStart, ta.selectionEnd, "end");
      ta.dispatchEvent(new Event("input"));
    }
  }
  function onKey(e) {
    const ta = ed.ta;
    const mod = e.ctrlKey || e.metaKey;
    if (mod && e.key === "Enter") { e.preventDefault(); return run(); }
    if (mod && (e.key === "s" || e.key === "S")) { e.preventDefault(); saveNow(); return toast("Saved."); }
    if (e.key === "Tab" && !mod && !e.altKey) {
      e.preventDefault();
      const v = ta.value, s = ta.selectionStart, end = ta.selectionEnd;
      if (s === end && !e.shiftKey) return insert("  ");
      const lineStart = v.lastIndexOf("\n", s - 1) + 1;
      const block = v.slice(lineStart, end);
      const changed = e.shiftKey ? block.replace(/^ {1,2}/gm, "") : block.replace(/^/gm, "  ");
      ta.setSelectionRange(lineStart, end);
      insert(changed);
      ta.setSelectionRange(lineStart, lineStart + changed.length);
      return;
    }
    if (e.key === "Enter" && !mod && !e.shiftKey && !e.altKey) {
      const v = ta.value, s = ta.selectionStart;
      const line = v.slice(v.lastIndexOf("\n", s - 1) + 1, s);
      let indent = (line.match(/^\s*/) || [""])[0];
      const before = line.trimEnd().slice(-1);
      const after = v[s] || "";
      if ("{([".includes(before) && before) {
        e.preventDefault();
        const close = { "{": "}", "(": ")", "[": "]" }[before];
        if (after === close) {
          insert("\n" + indent + "  \n" + indent);
          const pos = ta.selectionStart - indent.length - 1;
          ta.setSelectionRange(pos, pos);
        } else insert("\n" + indent + "  ");
        return;
      }
      e.preventDefault();
      insert("\n" + indent);
    }
  }

  function goToLine(n) {
    const lines = ed.ta.value.split("\n");
    let pos = 0;
    for (let i = 0; i < n - 1 && i < lines.length; i++) pos += lines[i].length + 1;
    ed.ta.focus();
    ed.ta.setSelectionRange(pos, pos + (lines[n - 1] || "").length);
    const lh = parseFloat(getComputedStyle(ed.ta).lineHeight) || 20;
    ed.ta.scrollTop = Math.max(0, (n - 4) * lh);
    syncScroll();
  }

  function run() {
    if (!ed) return;
    ed.game.code = ed.ta.value;
    ed.log.innerHTML = "";
    ed.count = 0;
    $("#stCount").textContent = "";
    ed.errorLines.clear();
    paint();
    const data = StudioRunner.loadData("studio-" + ed.game.id);
    StudioRunner.load(ed.preview, ed.ta.value, { id: "studio-" + ed.game.id, server: onlineServer(), data });
  }
  function addLog(level, text, line) {
    if (!ed) return;
    ed.count = (ed.count || 0) + 1;
    if (ed.count > 300) { if (ed.count === 301) addRow("warn", "Too many messages: only the first 300 are shown."); return; }
    if (line && level === "error") { ed.errorLines.add(line); schedulePaint(); }
    addRow(level, text, line);
    const errors = $$(".st-log .error", ed.log.parentNode).length;
    $("#stCount").textContent = errors ? `${errors} error${errors === 1 ? "" : "s"}` : "";
  }
  function addRow(level, text, line) {
    const row = document.createElement("div");
    row.className = "st-row " + level;
    row.innerHTML = (line ? `<button class="st-line" data-st-line="${line}">Line ${line}</button> ` : "") + esc(text);
    ed.log.appendChild(row);
    ed.log.scrollTop = ed.log.scrollHeight;
  }

  function settingsDialog() {
    const g = ed.game;
    openModal(`<button class="icon-btn modal-close" data-close>${icon("close")}</button>
      <div class="st-dialog"><h2>Game settings</h2>
        <label class="st-field"><b>Title</b><input id="sTitle" maxlength="40" value="${esc(g.title)}"></label>
        <label class="st-field"><b>Description</b><small>Tell players what to do. Shown on the Community page.</small>
          <textarea id="sDesc" maxlength="300" rows="3">${esc(g.desc)}</textarea></label>
        <label class="st-field"><b>Genre</b><select id="sGenre">${GENRES.map((x) => `<option ${x === g.genre ? "selected" : ""}>${x}</option>`).join("")}</select></label>
        <div class="st-field"><b>Color</b><div class="accents">${COLORS.map((c) =>
          `<button style="background:${c}" class="${g.color === c ? "on" : ""}" data-st-color="${c}" aria-label="${c}"></button>`).join("")}</div></div>
        <div class="btns st-dialog-btns"><button class="btn red" data-st="delete">Delete game</button><span></span>
          <button class="btn green" data-st="settings-done">Done</button></div></div>`);
  }
  function saveSettings() {
    const g = ed.game;
    g.title = $("#sTitle").value.trim().slice(0, 40) || "My game";
    g.desc = $("#sDesc").value.trim().slice(0, 300);
    g.genre = $("#sGenre").value;
    $("#stTitle").value = g.title;
    touch();
    closeModal();
  }

  function exportFile() {
    saveNow();
    const g = ed.game;
    let code = g.code;
    if (!/<title>/i.test(code)) code = code.replace(/<head>/i, `<head>\n  <title>${esc(g.title)}</title>`);
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([code], { type: "text/html" }));
    a.download = (g.title.replace(/[^\w -]+/g, "").trim().replace(/\s+/g, "-") || "my-game") + ".html";
    document.body.appendChild(a);
    a.click();
    setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
    toast("Saved a copy. Open it again with <b>Open a file</b> on the Create page.");
  }

  // ---------------------------------------------------------------- publishing

  const onlineServer = () => (ctx.lobby.connected ? ctx.lobby.url : "");
  let publishWaiting = null;

  function publishDialog() {
    saveNow();
    const g = ed.game;
    if (!ctx.lobby.connected) {
      return openModal(`<button class="icon-btn modal-close" data-close>${icon("close")}</button>
        <div class="st-dialog"><h2>Publish your game</h2>
        <p>Publishing puts your game on the game server you're online on, so other players there can play it.</p>
        <p class="hint">${ctx.webOnly() ? "Publishing needs the BlockOS app on a Mac or Windows computer, or the BlockOS virtual machine." : "Go online first: open <b>Play Online</b> and join a server (or host your own)."}</p>
        <div class="btns st-dialog-btns"><button class="btn" data-close>Not now</button><span></span>
          ${ctx.webOnly() ? "" : '<button class="btn green" data-page="online">Go to Play Online</button>'}</div></div>`);
    }
    const update = !!g.pub[ctx.lobby.url];
    openModal(`<button class="icon-btn modal-close" data-close>${icon("close")}</button>
      <div class="st-dialog"><h2>${update ? "Publish an update" : "Publish your game"}</h2>
      <div class="st-pub-card"><img src="${thumbSrc(g)}" alt=""><div><b>${esc(g.title)}</b><small>${esc(g.genre)}</small>
        <p>${g.desc ? esc(g.desc) : '<i>No description yet. Add one in Settings so players know what to do.</i>'}</p></div></div>
      <p class="hint">It goes to the server at <code>${esc(ctx.lobby.url)}</code>, published under your name, <b>${esc(ctx.state.name)}</b>.
        The server's owner checks every game before other players can see it${update ? ", and checks updates again" : ""}.</p>
      <div class="st-checks">
        <label><input type="checkbox" class="st-check"> My game is kind: nothing rude, mean or too scary.</label>
        <label><input type="checkbox" class="st-check"> It doesn't show anyone's real name, address, school, phone number or photo.</label>
        <label><input type="checkbox" class="st-check"> I made it, or I say in the description who made the parts I used.</label>
      </div>
      ${g.code.length > MAX_CODE ? `<p class="bad">Your game is too long to publish: ${g.code.length.toLocaleString()} of ${MAX_CODE.toLocaleString()} characters.</p>` : ""}
      <div class="btns st-dialog-btns"><button class="btn" data-st="settings">Edit settings</button><span></span>
        <button class="btn green" data-st="publish-go" disabled>${update ? "Publish update" : "Publish"}</button></div></div>`);
    const checks = $$(".st-check");
    const go = $('[data-st="publish-go"]');
    checks.forEach((c) => { c.onchange = () => { go.disabled = !checks.every((x) => x.checked) || g.code.length > MAX_CODE; }; });
  }
  function publishGo() {
    const g = ed.game;
    const server = ctx.lobby.url;
    publishWaiting = { id: g.id, server };
    ctx.lobby.send({ t: "cpub", id: g.pub[server] || undefined, title: g.title, desc: g.desc, genre: g.genre, color: g.color, code: g.code });
    const btn = $('[data-st="publish-go"]');
    if (btn) { btn.disabled = true; btn.textContent = "Publishing..."; }
  }
  function published(m) {
    const w = publishWaiting;
    publishWaiting = null;
    if (!w) return;
    if (m.error || !/^[a-z0-9]{1,16}$/.test(String(m.id))) {
      toast(esc(str(m.error, 200) || "Couldn't publish."));
      const btn = $('[data-st="publish-go"]');
      if (btn) { btn.disabled = false; btn.textContent = "Publish"; }
      return;
    }
    const g = store.games[w.id];
    if (g) { g.pub[w.server] = m.id; saveStore(); }
    closeModal();
    toast(m.status === "approved" ? "Published! It's on the Community page now."
      : "Sent! Your game shows on the Community page once the server's owner has checked it.");
    requestList();
  }

  // ---------------------------------------------------------------- help guide

  const hasHelp = () => !!(window.STUDIO_DOCS && window.STUDIO_DOCS.length);
  function helpDialog(sectionId) {
    const docs = window.STUDIO_DOCS || [];
    if (!docs.length) return toast("The help guide isn't available.");
    const cur = docs.find((d) => d.id === sectionId) || docs[0];
    openModal(`<button class="icon-btn modal-close" data-close>${icon("close")}</button>
      <div class="st-help"><nav>${docs.map((d) => `<button class="${d === cur ? "on" : ""}" data-st-doc="${esc(d.id)}">${esc(d.title)}</button>`).join("")}</nav>
      <article><h2>${esc(cur.title)}</h2>${cur.html}</article></div>`, "wide");
  }

  // ---------------------------------------------------------------- Community page

  const com = { games: null, mine: [], review: [], mod: false, tab: "games", sort: "popular", q: "", open: null, gets: {} };
  function requestList() { if (ctx.lobby.connected) ctx.lobby.send({ t: "clist" }); }

  function modKeys() { try { return JSON.parse(localStorage.getItem("blockos.modKeys")) || {}; } catch (_) { return {}; } }
  // On joining a server: if this computer hosts it (or you typed its moderator key before), become a moderator.
  let keyTyped = null;
  function onConnected() {
    const info = ctx.onlineInfo();
    const url = ctx.lobby.url;
    com.mod = false;
    com.games = null;
    if (info && info.hosting && info.modKey && url === `ws://127.0.0.1:${info.port}`) ctx.lobby.send({ t: "admin", key: info.modKey });
    else if (modKeys()[url]) ctx.lobby.send({ t: "admin", key: modKeys()[url] });
    if (ctx.view.page === "community") requestList();
  }

  const PAGES_THAT_SHOW_COMMUNITY = ["community"];
  // Whatever a server sends is cleaned up first: a server run by a stranger could send anything.
  const num = (x) => (Number.isFinite(Number(x)) ? Math.max(0, Number(x)) : 0);
  const str = (x, max) => String(x === undefined || x === null ? "" : x).slice(0, max);
  function cleanGame(g) {
    if (!g || typeof g !== "object" || !/^[a-z0-9]{1,16}$/.test(String(g.id))) return null;
    return {
      id: String(g.id), title: str(g.title, 60) || "Untitled", desc: str(g.desc, 400), genre: str(g.genre, 20),
      color: /^#[0-9a-f]{6}$/i.test(g.color) ? g.color : "#3b82f6", author: str(g.author, 30),
      status: ["pending", "approved", "hidden"].includes(g.status) ? g.status : "pending",
      plays: num(g.plays), likes: num(g.likes), liked: !!g.liked, mine: !!g.mine, updated: num(g.updated),
      reports: Array.isArray(g.reports) ? g.reports.slice(0, 50).map((r) => ({ reason: str(r && r.reason, 20) })) : undefined,
    };
  }
  const cleanList = (l) => (Array.isArray(l) ? l.map(cleanGame).filter(Boolean) : []);

  // Messages from the game server about community games. Returns true if it was one.
  function onLobby(m) {
    switch (m.t) {
      case "clist":
        com.games = cleanList(m.games);
        com.mine = cleanList(m.mine);
        com.review = cleanList(m.review);
        com.mod = !!m.mod;
        if (PAGES_THAT_SHOW_COMMUNITY.includes(ctx.view.page) && ctx.playerHidden()) rerender();
        return true;
      case "cchanged":
        if (ctx.view.page === "community") requestList();
        return true;
      case "admin":
        com.mod = !!m.ok;
        if (keyTyped) {
          if (m.ok) {
            const keys = modKeys();
            keys[keyTyped.url] = keyTyped.key;
            try { localStorage.setItem("blockos.modKeys", JSON.stringify(keys)); } catch (_) {}
            toast("You're a moderator on this server now. New games to check are under <b>Review</b>.");
            com.tab = "review";
          } else toast("That moderator key isn't right for this server.");
          keyTyped = null;
        }
        requestList();
        return true;
      case "cpub":
        published(m);
        return true;
      case "cget": {
        const cb = com.gets[m.id];
        delete com.gets[m.id];
        if (!cb) return true;
        if (m.error || typeof m.code !== "string" || !cleanGame(m.game)) toast(esc(str(m.error, 200) || "Couldn't load that game."));
        else cb({ code: m.code, game: cleanGame(m.game) });
        return true;
      }
      case "clike":
        m.game = cleanGame(m.game);
        if (m.game) {
          for (const list of [com.games || [], com.mine, com.review]) {
            const x = list.find((y) => y.id === m.game.id);
            if (x) Object.assign(x, { likes: m.game.likes, liked: m.game.liked });
          }
          if (com.open === m.game.id) openCommunityGame(m.game.id);
        }
        return true;
      case "creport":
        toast(m.ok ? "Thanks for telling us. The server's owner will look at it." : "Couldn't send the report.");
        return true;
      case "cmod":
        if (m.ok === true) toast(m.action === "approve" ? "Approved: everyone can see it now." : m.action === "hide" ? "Hidden from the Community page." : "Deleted.");
        requestList();
        return true;
    }
    return false;
  }
  function rerender() {
    // Keep the search box focused while the list updates.
    const typing = document.activeElement && document.activeElement.id === "comSearch";
    const pos = typing ? document.activeElement.selectionStart : 0;
    ctx.render();
    if (typing) { const s = $("#comSearch"); if (s) { s.focus(); s.setSelectionRange(pos, pos); } }
  }

  function findGame(id) {
    return [...(com.games || []), ...com.mine, ...com.review].find((g) => g.id === id);
  }
  function comTile(g) {
    return `<button class="tile" data-c-open="${g.id}"><div class="thumb"><img src="${thumbSrc(g)}" alt="" loading="lazy"></div>
      <div class="t-name">${esc(g.title)}</div>
      <div class="t-meta"><span>by ${esc(g.author)}</span><span>${g.plays} ${g.plays === 1 ? "play" : "plays"}</span><span>${icon("heart")}${g.likes}</span></div></button>`;
  }
  const STATUS = { pending: ["Waiting to be checked", "pending"], approved: ["Live", "live"], hidden: ["Hidden", "hidden"] };
  function statusPill(g) { const s = STATUS[g.status] || STATUS.pending; return `<span class="st-pill ${s[1]}">${s[0]}</span>`; }

  function communityPage(page, view) {
    const safety = `<div class="panel"><h2>About community games</h2><p class="hint">These games are made by players like you, using
      <b>Create</b>. The server's owner checks each one before it shows here. They run in a safe sandbox: they can't see your
      Bricks, friends or other games, or open websites. If something isn't OK, open it and press <b>Report</b>.</p></div>`;
    if (!ctx.lobby.connected) {
      page.innerHTML = `<h1 class="page-title">Community</h1>
        <div class="panel"><h2>Games made by players</h2>
        <p class="hint">${ctx.webOnly() ? "Community games need the BlockOS app on a Mac or Windows computer, or the BlockOS virtual machine."
          : "Go online to play games other players made and published. Open <b>Play Online</b> and join a server (or host your own)."}</p>
        ${ctx.webOnly() ? "" : '<button class="btn green" data-page="online">Go to Play Online</button>'}</div>${safety}`;
      return;
    }
    if (com.games === null) {
      requestList();
      page.innerHTML = `<h1 class="page-title">Community</h1><div class="empty">Loading games from the server...</div>`;
      return;
    }
    if (com.tab === "review" && !com.mod) com.tab = "games";
    const waiting = com.review.filter((g) => g.status !== "approved" || (g.reports && g.reports.length)).length;
    const tabs = [["games", "Games"], ["mine", `My uploads (${com.mine.length})`]];
    if (com.mod) tabs.push(["review", `Review${waiting ? ` (${waiting})` : ""}`]);
    let body = "";
    if (com.tab === "games") {
      const q = com.q.trim().toLowerCase();
      let list = com.games.filter((g) => !q || (g.title + " " + g.author + " " + g.genre + " " + g.desc).toLowerCase().includes(q));
      if (com.sort === "new") list.sort((a, b) => b.updated - a.updated);
      else if (com.sort === "liked") list.sort((a, b) => b.likes - a.likes || b.plays - a.plays);
      else list.sort((a, b) => b.plays + b.likes * 3 - (a.plays + a.likes * 3) || b.updated - a.updated);
      body = `<div class="toolbar"><div class="chips">${[["popular", "Popular"], ["new", "Newest"], ["liked", "Most liked"]].map(([id, label]) =>
          `<button class="chip ${com.sort === id ? "on" : ""}" data-c-sort="${id}">${label}</button>`).join("")}</div>
          <input type="search" id="comSearch" class="com-search" placeholder="Search community games" value="${esc(com.q)}" spellcheck="false"></div>
        ${list.length ? `<div class="grid">${list.map(comTile).join("")}</div>`
          : `<div class="empty">${com.games.length ? "No games match that." : "No community games on this server yet. Make one in <b>Create</b> and publish it!"}</div>`}`;
    } else {
      const list = com.tab === "mine" ? com.mine : com.review;
      body = list.length ? `<div class="com-list">${list.sort((a, b) => b.updated - a.updated).map((g) => `
        <div class="com-row"><img src="${thumbSrc(g)}" alt=""><div class="com-info"><b>${esc(g.title)}</b>
          <small>${com.tab === "review" ? `by ${esc(g.author)} - ` : ""}${statusPill(g)} ${g.plays} plays - ${g.likes} likes - updated ${ago(g.updated)}</small>
          ${g.reports && g.reports.length ? `<small class="bad">Reported ${g.reports.length} time${g.reports.length === 1 ? "" : "s"}: ${esc([...new Set(g.reports.map((r) => (REASONS.find((x) => x[0] === r.reason) || REASONS[5])[1]))].join(", "))}</small>` : ""}</div>
          <button class="btn" data-c-open="${g.id}">Open</button></div>`).join("")}</div>`
        : `<div class="empty">${com.tab === "mine" ? "You haven't published any games on this server. Make one in <b>Create</b>, then press Publish." : "Nothing to check. Nice!"}</div>`;
    }
    const modPanel = com.mod
      ? `<div class="panel"><h2>Moderator</h2><p class="hint">You're a moderator on this server: you check new games under <b>Review</b> before everyone can see them.
          Play each one first. Approve games that are kind and safe for kids; hide or delete anything else.</p></div>`
      : ctx.webOnly() ? "" : `<div class="panel"><h2>Server owner?</h2><p class="hint">To check and approve new games on a server you run, type its moderator key.
          (If you host the server from this BlockOS, you're a moderator automatically.)</p>
          <div class="join-row"><input type="password" id="modKey" placeholder="Moderator key" autocomplete="off" spellcheck="false">
          <button class="btn" data-c-key>Use key</button></div></div>`;
    page.innerHTML = `<h1 class="page-title">Community</h1>
      <div class="tabs">${tabs.map(([id, label]) => `<button class="${com.tab === id ? "on" : ""}" data-c-tab="${id}">${label}</button>`).join("")}</div>
      ${body}<div class="com-panels">${safety}${modPanel}</div>`;
    const search = $("#comSearch");
    if (search) search.oninput = (e) => { com.q = e.target.value; rerender(); };
  }

  function openCommunityGame(id) {
    const g = findGame(id);
    if (!g) return;
    com.open = id;
    const own = g.mine;
    openModal(`<button class="icon-btn modal-close" data-close>${icon("close")}</button>
      <div class="gd"><div class="thumb"><img src="${thumbSrc(g)}" alt=""></div><div class="gd-info">
        <div><span class="gd-genre">${esc(g.genre)}</span> <span class="gd-genre">Community</span> ${g.status !== "approved" ? statusPill(g) : ""}</div>
        <h2>${esc(g.title)}</h2>
        <small class="muted">by ${esc(g.author)}${own ? " (you)" : ""}</small>
        <p>${g.desc ? esc(g.desc) : "No description."}</p>
        <div class="gd-stats"><div><small>Plays</small><b>${g.plays}</b></div><div><small>Likes</small><b>${g.likes}</b></div></div>
        ${g.reports && g.reports.length ? `<p class="bad">Reports: ${esc(g.reports.map((r) => (REASONS.find((x) => x[0] === r.reason) || REASONS[5])[1]).join(", "))}</p>` : ""}
        <div class="play-row">
          <button class="btn green play-btn" data-c-play="${g.id}" autofocus aria-label="Play">${icon("play")}</button>
          ${g.status === "approved" && !own ? `<button class="btn square-btn ${g.liked ? "on" : ""}" data-c-like="${g.id}" title="Like">${icon("heart")}</button>` : ""}
        </div>
        <div class="btns com-more">
          <button class="btn" data-c-remix="${g.id}" title="Copy this game into Create to see how it works and change it">Remix</button>
          ${own ? "" : `<button class="btn" data-c-report="${g.id}">Report</button>`}
          ${own || com.mod ? `<button class="btn red" data-c-mod="delete" data-id="${g.id}">Delete</button>` : ""}
        </div>
        ${com.mod ? `<div class="btns com-more">${g.status !== "approved" ? `<button class="btn green" data-c-mod="approve" data-id="${g.id}">Approve</button>` : ""}
          ${g.status !== "hidden" ? `<button class="btn" data-c-mod="hide" data-id="${g.id}">Hide</button>` : ""}</div>` : ""}
      </div></div>`);
  }

  function fetchGame(id, cb) {
    if (!ctx.lobby.connected) return toast("You're offline. Join the server again to play this.");
    com.gets[id] = cb;
    ctx.lobby.send({ t: "cget", id });
  }
  function playCommunity(id) {
    fetchGame(id, (m) => {
      closeModal();
      ctx.playSandboxed({ title: m.game.title, code: m.code, dataId: "c-" + id, server: ctx.lobby.url });
    });
  }
  function remix(id) {
    fetchGame(id, (m) => {
      const src = m.game;
      const g = createGame({
        title: ("Remix of " + src.title).slice(0, 40),
        desc: `A remix of "${src.title}" by ${src.author}.`,
        genre: src.genre, color: src.color, code: m.code,
      });
      closeModal();
      toast("Copied into Create. Change anything you like!");
      ctx.go("create", { studioGame: g.id });
    });
  }
  function reportDialog(id) {
    const g = findGame(id);
    openModal(`<div class="st-dialog"><h2>Report ${esc(g ? g.title : "this game")}</h2>
      <p class="hint">What's wrong with it? The server's owner will look at it. Games that several people report are hidden.</p>
      <div class="st-checks">${REASONS.map(([r, label], i) => `<label><input type="radio" name="reason" value="${r}" ${i === 0 ? "checked" : ""}> ${label}</label>`).join("")}</div>
      <div class="btns st-dialog-btns"><button class="btn" data-close>Cancel</button><span></span><button class="btn red" data-c-report-go="${id}">Report</button></div></div>`);
  }

  // ---------------------------------------------------------------- clicks and messages

  document.addEventListener("click", (e) => {
    const t = e.target.closest("button");
    if (!t) return;
    const d = t.dataset;
    if (d.st) {
      switch (d.st) {
        case "new": return chooseTemplate();
        case "import": return $("#stFile").click();
        case "help": return helpDialog();
        case "back": saveNow(); ed = null; return ctx.go("create");
        case "run": return run();
        case "play": saveNow(); return ctx.playSandboxed({ title: ed.game.title, code: ed.game.code, dataId: "studio-" + ed.game.id, server: onlineServer() });
        case "settings": return settingsDialog();
        case "settings-done": return saveSettings();
        case "export": return exportFile();
        case "publish": return publishDialog();
        case "publish-go": return publishGo();
        case "clear": ed.log.innerHTML = ""; ed.count = 0; $("#stCount").textContent = ""; ed.errorLines.clear(); return paint();
        case "delete": {
          const g = ed.game;
          return confirmDialog(`Delete ${g.title}?`, "It's deleted from this computer. Copies you published or saved to a file stay.", "Delete", () => {
            delete store.games[g.id];
            saveStore();
            try { localStorage.removeItem("blockos.studio.data.studio-" + g.id); } catch (_) {}
            ed = null;
            ctx.go("create");
          });
        }
      }
      return;
    }
    if (d.stEdit) return ctx.go("create", { studioGame: d.stEdit });
    if (d.stTemplate !== undefined) return startFromTemplate(d.stTemplate);
    if (d.stLine) return goToLine(+d.stLine);
    if (d.stDoc) return helpDialog(d.stDoc);
    if (d.stColor) {
      ed.game.color = d.stColor;
      $$("[data-st-color]").forEach((b) => b.classList.toggle("on", b === t));
      return touch();
    }
    if (d.cTab) { com.tab = d.cTab; return ctx.render(); }
    if (d.cSort) { com.sort = d.cSort; return ctx.render(); }
    if (d.cOpen) return openCommunityGame(d.cOpen);
    if (d.cPlay) return playCommunity(d.cPlay);
    if (d.cLike) return ctx.lobby.send({ t: "clike", id: d.cLike });
    if (d.cRemix) return remix(d.cRemix);
    if (d.cReport) return reportDialog(d.cReport);
    if (d.cReportGo) {
      const r = $('input[name="reason"]:checked');
      ctx.lobby.send({ t: "creport", id: d.cReportGo, reason: r ? r.value : "other" });
      return closeModal();
    }
    if (d.cMod) {
      const g = findGame(d.id);
      const doIt = () => { ctx.lobby.send({ t: "cmod", id: d.id, action: d.cMod }); closeModal(); };
      if (d.cMod === "delete") return confirmDialog(`Delete ${g ? g.title : "this game"}?`, "It's removed from the server for everyone. This can't be undone.", "Delete", doIt);
      return doIt();
    }
    if (d.cKey !== undefined) {
      const key = $("#modKey").value.trim();
      if (!key) return toast("Type the moderator key first.");
      keyTyped = { url: ctx.lobby.url, key };
      ctx.lobby.send({ t: "admin", key });
    }
  });

  // Messages from the editor's preview.
  window.addEventListener("message", (e) => {
    if (!ed || e.source !== ed.preview.contentWindow || !e.data || typeof e.data !== "object") return;
    const m = e.data;
    if (m.type === "blockos:studio-log") addLog(["error", "warn"].includes(m.level) ? m.level : "log", String(m.text || ""), Number(m.line) || 0);
    else if (m.type === "blockos:studio-save") StudioRunner.onSave("studio-" + ed.game.id, m.data);
    else if (m.type === "blockos:badge") addLog("badge", `Badge awarded: ${String(m.name || "")}. (Badges in made-by-players games don't give Bricks.)`);
    else if (m.type === "blockos:score") addLog("log", `Kit.finish: score ${m.score}${m.best !== null && m.best !== undefined ? `, best ${m.best}` : ""}`);
  });
  // Leaving the editor page saves straight away.
  window.addEventListener("beforeunload", saveNow);

  return {
    createPage, communityPage, onLobby, onConnected, saveNow,
    leaving() { if (ed) { saveNow(); ed = null; } },
  };
};
