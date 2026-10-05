/* BlockOS desktop shell. Plain JavaScript, no build step: everything runs offline. */
(function () {
  "use strict";

  const GAMES = (window.BLOCKOS_GAMES || []).slice();
  const GAME_BY_ID = Object.fromEntries(GAMES.map((g) => [g.id, g]));
  const GENRES = [...new Set(GAMES.map((g) => g.genre))].sort();

  const $ = (sel, root) => (root || document).querySelector(sel);
  const $$ = (sel, root) => [...(root || document).querySelectorAll(sel)];
  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

  // ---------------------------------------------------------------- state

  const STORE_KEY = "blockos.state.v1";
  const DEFAULT_STATE = {
    name: "Player",
    bricks: 50,
    avatar: Object.assign({}, Avatar.DEFAULT),
    owned: [],
    plays: {},
    last: {},
    favs: [],
    bestSeen: {},
    theme: "dark",
    accent: "#3b82f6",
    muted: false,
  };
  const state = loadState();

  function loadState() {
    let saved = {};
    try { saved = JSON.parse(localStorage.getItem(STORE_KEY)) || {}; } catch (_) {}
    return Object.assign({}, DEFAULT_STATE, saved);
  }
  function save() {
    try {
      localStorage.setItem(STORE_KEY, JSON.stringify(state));
      localStorage.setItem("blockos.muted", state.muted ? "1" : "0"); // read by games/kit.js
    } catch (_) {}
  }
  function bestScore(id) {
    try {
      const v = localStorage.getItem("blockos.best." + id);
      return v === null ? null : Number(v);
    } catch (_) { return null; }
  }
  const isFav = (id) => state.favs.includes(id);
  const owns = (kind, item) => item.price === 0 || state.owned.includes(kind + ":" + item.id);

  // ---------------------------------------------------------------- icons

  const ICON = {
    home: '<path d="M3 11 12 4l9 7"/><path d="M5 10v10h5v-6h4v6h5V10"/>',
    discover: '<circle cx="12" cy="12" r="9"/><path d="m15.5 8.5-2 5-5 2 2-5z"/>',
    avatar: '<rect x="8" y="3" width="8" height="7" rx="2"/><path d="M6 21v-8a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v8"/>',
    apps: '<rect x="4" y="4" width="6" height="6" rx="1.5"/><rect x="14" y="4" width="6" height="6" rx="1.5"/><rect x="4" y="14" width="6" height="6" rx="1.5"/><rect x="14" y="14" width="6" height="6" rx="1.5"/>',
    settings: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/>',
    play: '<path d="M7 4.5v15l13-7.5z"/>',
    heart: '<path d="M12 20s-7-4.4-9-9a5 5 0 0 1 9-3 5 5 0 0 1 9 3c-2 4.6-9 9-9 9z"/>',
    close: '<path d="M6 6l12 12M18 6 6 18"/>',
    terminal: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="m7 9 3 3-3 3M13 15h4"/>',
    files: '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
    browser: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18"/>',
    editor: '<path d="M6 3h9l4 4v14H6z"/><path d="M9 12h7M9 16h7M9 8h3"/>',
    taskmanager: '<path d="M3 12h4l3-7 4 14 3-7h4"/>',
    calculator: '<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M8 7h8M8 12h.01M12 12h.01M16 12h.01M8 16h.01M12 16h.01M16 16h.01"/>',
    star: '<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    online: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18"/>',
    badge: '<circle cx="12" cy="9" r="6"/><path d="m8.5 13.5-1.5 7.5 5-3 5 3-1.5-7.5"/>',
  };
  const icon = (name) => `<svg viewBox="0 0 24 24">${ICON[name] || ""}</svg>`;
  const BRICK_SVG = $(".brick-icon").outerHTML;

  // ---------------------------------------------------------------- system API (server.py)

  let sysInfo = null;
  async function api(path, body) {
    const res = await fetch(path, body === undefined ? {} : {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-BlockOS": "1" },
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error((await res.json().catch(() => ({}))).error || res.statusText);
    return res.json();
  }
  async function loadSysInfo() {
    try { sysInfo = await api("/api/info"); } catch (_) { sysInfo = null; }
  }

  const APPS = [
    { id: "terminal", name: "Terminal", color: "#1f2328", desc: "Command line" },
    { id: "files", name: "Files", color: "#f59e0b", desc: "Browse your stuff" },
    { id: "browser", name: "Web Browser", color: "#3b82f6", desc: "Surf the web" },
    { id: "editor", name: "Text Editor", color: "#22c55e", desc: "Write notes" },
    { id: "taskmanager", name: "Task Manager", color: "#a855f7", desc: "What's running" },
    { id: "calculator", name: "Calculator", color: "#ec4899", desc: "Do some math" },
  ];

  async function launch(appId) {
    const app = APPS.find((a) => a.id === appId);
    if (!sysInfo) return toast("Apps open when BlockOS runs on its virtual machine.");
    if (!sysInfo.apps[appId]) return toast(`${app.name} isn't installed.`);
    try {
      await api("/api/launch", { app: appId });
      toast(`Opening ${app.name}...`);
      closeMenu();
    } catch (e) {
      toast(`Couldn't open ${app.name}: ${e.message}`);
    }
  }

  function power(action) {
    const label = action === "reboot" ? "Restart" : "Shut down";
    const inApp = sysInfo && /^(macOS|Windows)/.test(sysInfo.os);   // the Mac/Windows app, not the VM
    const text = action === "reboot" ? "BlockOS will restart." : inApp ? "BlockOS will close." : "BlockOS will turn off.";
    confirmDialog(`${label}?`, text, label, async () => {
      if (!sysInfo) return toast("Power controls work when BlockOS runs on its virtual machine.");
      try { await api("/api/power", { action }); toast(`${label}...`); } catch (e) { toast(e.message); }
    });
  }

  // ---------------------------------------------------------------- toasts & dialogs

  function toast(html, withBrick) {
    const t = document.createElement("div");
    t.className = "toast";
    t.innerHTML = (withBrick ? BRICK_SVG : "") + `<span>${html}</span>`;
    $("#toasts").appendChild(t);
    setTimeout(() => { t.classList.add("out"); setTimeout(() => t.remove(), 300); }, 3200);
  }

  const modal = $("#modal");
  function openModal(html, cls) {
    modal.innerHTML = `<div class="modal-card ${cls || ""}">${html}</div>`;
    modal.hidden = false;
    const focusable = $(".modal-card [autofocus]", modal) || $(".modal-card button", modal);
    if (focusable) focusable.focus();
  }
  function closeModal() { modal.hidden = true; modal.innerHTML = ""; }
  modal.addEventListener("click", (e) => { if (e.target === modal) closeModal(); });

  function confirmDialog(title, text, okLabel, onOk) {
    openModal(`<div class="dialog"><h2>${esc(title)}</h2><p>${esc(text)}</p>
      <div class="btns"><button class="btn" data-dlg="no">Cancel</button><button class="btn green" data-dlg="yes" autofocus>${esc(okLabel)}</button></div></div>`);
    $('[data-dlg="no"]', modal).onclick = closeModal;
    $('[data-dlg="yes"]', modal).onclick = () => { closeModal(); onOk(); };
  }

  // ---------------------------------------------------------------- game tiles

  function fallbackThumb(g) {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 270"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${g.color || "#3b82f6"}"/><stop offset="1" stop-color="#16181b"/></linearGradient></defs>
      <rect width="480" height="270" fill="url(#g)"/><text x="240" y="170" font-size="120" font-family="sans-serif" font-weight="900"
      fill="rgba(255,255,255,.85)" text-anchor="middle">${esc(g.title[0])}</text></svg>`;
    return "data:image/svg+xml," + encodeURIComponent(svg);
  }
  document.addEventListener("error", (e) => {
    const img = e.target;
    if (img.tagName === "IMG" && img.dataset.game && !img.dataset.failed) {
      img.dataset.failed = "1";
      img.src = fallbackThumb(GAME_BY_ID[img.dataset.game]);
    }
  }, true);

  function thumb(g) {
    return `<div class="thumb"><img src="games/${g.id}/thumb.svg" data-game="${g.id}" alt="" loading="lazy">
      ${isFav(g.id) ? `<span class="fav">${icon("heart")}</span>` : ""}</div>`;
  }
  function tile(g) {
    const plays = state.plays[g.id] || 0;
    return `<button class="tile" data-open="${g.id}">${thumb(g)}
      <div class="t-name">${esc(g.title)}</div>
      <div class="t-meta"><span>${esc(g.genre)}</span><span>${plays ? plays + (plays === 1 ? " play" : " plays") : "New"}</span>${g.multiplayer ? '<span class="t-online">Online</span>' : ""}${g.is3d ? '<span class="t-3d">3D</span>' : ""}</div></button>`;
  }
  function row(title, games, seeAll) {
    if (!games.length) return "";
    return `<section class="row"><div class="row-head"><h2>${esc(title)}</h2>
      ${seeAll ? `<button class="see-all" data-see="${esc(seeAll)}">See all</button>` : ""}</div>
      <div class="strip">${games.map(tile).join("")}</div></section>`;
  }

  // Shuffles the same way all day, so "Recommended" doesn't jump around on every render.
  function dailyShuffle(list) {
    let seed = Math.floor(Date.now() / 864e5);
    const rnd = () => ((seed = (seed * 9301 + 49297) % 233280) / 233280);
    const out = list.slice();
    for (let i = out.length - 1; i > 0; i--) {
      const j = Math.floor(rnd() * (i + 1));
      [out[i], out[j]] = [out[j], out[i]];
    }
    return out;
  }
  const recent = () => GAMES.filter((g) => state.last[g.id]).sort((a, b) => state.last[b.id] - state.last[a.id]);
  const favorites = () => GAMES.filter((g) => isFav(g.id));
  function allBadges() {
    try { return JSON.parse(localStorage.getItem("blockos.badges")) || {}; } catch (_) { return {}; }
  }
  const badgesFor = (id) => Object.values(allBadges()).filter((b) => b.game === id);

  // ---------------------------------------------------------------- pages

  const NAV = [
    { id: "home", label: "Home" },
    { id: "discover", label: "Discover" },
    { id: "avatar", label: "Avatar" },
    { id: "online", label: "Play Online" },
    { id: "apps", label: "Apps" },
    { id: "settings", label: "Settings" },
  ];
  const view = { page: "home", genre: "All", sort: "plays", avatarTab: "colors", query: "" };
  const page = $("#page");

  function go(p, opts) {
    Object.assign(view, opts || {}, { page: p });
    if (p !== "search") { view.query = ""; $("#search").value = ""; }
    render();
    page.scrollTop = 0;
  }

  function render() {
    $("#nav").innerHTML = NAV.map((n) =>
      `<button data-page="${n.id}" class="${view.page === n.id ? "active" : ""}">${icon(n.id)}<span>${n.label}</span></button>`).join("");
    $("#meCard").innerHTML = `<div class="headshot">${Avatar.draw(state.avatar, { headshot: true })}</div>
      <div><b>${esc(state.name)}</b><small>View avatar</small></div>`;
    $("#brickCount").textContent = state.bricks.toLocaleString();
    (PAGES[view.page] || PAGES.home)();
  }

  const PAGES = {
    home() {
      const rec = recent().slice(0, 12);
      let html = `<div class="hello"><div class="headshot">${Avatar.draw(state.avatar, { headshot: true })}</div>
        <div><h1>Hello, ${esc(state.name)}!</h1><p>${GAMES.length} games ready to play. Press <b>MENU</b> to see them all.</p></div></div>`;
      html += row("Continue playing", rec);
      html += row("3D experiences", GAMES.filter((g) => g.is3d));
      html += row("Play with friends online", GAMES.filter((g) => g.multiplayer));
      html += row("Your favorites", favorites());
      html += row("Recommended for you", dailyShuffle(GAMES).slice(0, 12), "All");
      for (const genre of GENRES) html += row(genre, GAMES.filter((g) => g.genre === genre), genre);
      page.innerHTML = html;
    },

    discover() {
      let list = GAMES.filter((g) => view.genre === "All" || g.genre === view.genre);
      if (view.sort === "az") list.sort((a, b) => a.title.localeCompare(b.title));
      else list.sort((a, b) => (state.plays[b.id] || 0) - (state.plays[a.id] || 0) || a.title.localeCompare(b.title));
      page.innerHTML = `<h1 class="page-title">Discover</h1>
        <div class="toolbar"><div class="chips">${["All", ...GENRES].map((g) =>
          `<button class="chip ${view.genre === g ? "on" : ""}" data-genre="${esc(g)}">${esc(g)}</button>`).join("")}</div>
        <select id="sort"><option value="plays">Most played</option><option value="az">A to Z</option></select></div>
        <div class="grid">${list.map(tile).join("")}</div>`;
      $("#sort").value = view.sort;
      $("#sort").onchange = (e) => { view.sort = e.target.value; render(); };
    },

    search() {
      const q = view.query.trim().toLowerCase();
      const list = GAMES.filter((g) => (g.title + " " + g.genre + " " + g.description).toLowerCase().includes(q));
      page.innerHTML = `<h1 class="page-title">Results for "${esc(view.query)}"</h1>
        ${list.length ? `<div class="grid">${list.map(tile).join("")}</div>` : `<div class="empty">No games match that. Try another word.</div>`}`;
    },

    avatar() {
      const tabs = [["colors", "Body Colors"], ["face", "Faces"], ["hat", "Hats"], ["shirt", "Shirts"], ["badges", "Badges"]];
      let body = "";
      if (view.avatarTab === "badges") {
        const list = Object.values(allBadges()).sort((a, b) => b.time - a.time);
        body = list.length ? `<div class="badges">${list.map((b) => `<div class="badge-card">${icon("badge")}<div><b>${esc(b.name)}</b>
          <small>${esc((GAME_BY_ID[b.game] || {}).title || b.game)}</small><p>${esc(b.desc)}</p></div></div>`).join("")}</div>`
          : `<div class="empty">No badges yet. Play games to earn them; each badge also gives you 10 Bricks.</div>`;
      } else if (view.avatarTab === "colors") {
        body = [["head", "Head"], ["torso", "Torso"], ["arms", "Arms"], ["legs", "Legs"]].map(([part, label]) =>
          `<div class="part-row"><h3>${label}</h3><div class="swatches">${Avatar.COLORS.map((c) =>
            `<button class="swatch ${state.avatar[part] === c ? "on" : ""}" style="background:${c}" data-part="${part}" data-color="${c}" title="${c}"></button>`).join("")}</div></div>`).join("");
      } else {
        const kind = view.avatarTab;
        body = `<div class="items">${Avatar.ITEMS[kind].map((item) => {
          const have = owns(kind, item);
          const on = state.avatar[kind] === item.id;
          return `<button class="item ${on ? "on" : ""}" data-kind="${kind}" data-item="${item.id}">
            ${Avatar.preview(kind, item.id, state.avatar)}
            <div>${esc(item.name)}</div>
            <div class="price">${on ? '<span class="owned">Wearing</span>' : have ? '<span class="owned">Owned</span>' : BRICK_SVG + item.price}</div></button>`;
        }).join("")}</div>`;
      }
      page.innerHTML = `<h1 class="page-title">Avatar</h1><div class="avatar-layout">
        <div class="avatar-stage">${Avatar.draw(state.avatar)}
          <input id="nameInput" maxlength="20" value="${esc(state.name)}" aria-label="Display name"></div>
        <div><div class="tabs">${tabs.map(([id, label]) => `<button class="${view.avatarTab === id ? "on" : ""}" data-atab="${id}">${label}</button>`).join("")}</div>${body}</div></div>`;
      $("#nameInput").onchange = (e) => {
        state.name = e.target.value.trim().slice(0, 20) || "Player";
        save();
        render();
      };
    },

    online() {
      const addr = serverAddress();
      const hosting = onlineInfo && onlineInfo.hosting;
      const status = hosting
        ? `<b class="ok">You're hosting a server.</b> Friends on the same Wi-Fi join with ${onlineInfo.addresses.length ? onlineInfo.addresses.map((a) => `<code>${esc(a)}</code>`).join(" or ") : "this computer's IP address"}.`
        : addr ? `<b class="ok">Online.</b> Games that support it will put you on the server at <code>${esc(addr)}</code>.`
        : `<b>You're offline.</b> Host a server or join a friend's to play together.`;
      const online = GAMES.filter((g) => g.multiplayer);
      page.innerHTML = `<h1 class="page-title">Play Online</h1>
        <div class="panel"><h2>Status</h2><p>${status}</p>${addr ? '<button class="btn" id="goOffline">Go offline</button>' : ""}</div>
        <div class="panel"><h2>Host a server</h2>
          <p class="hint">Turns this computer into a game server. Your friends join it from their BlockOS using the address shown above.</p>
          ${hosting ? '<button class="btn red" id="stopHost">Stop hosting</button>' : '<button class="btn green" id="startHost">Start hosting</button>'}</div>
        <div class="panel"><h2>Join a server</h2>
          <p class="hint">Type the address your friend sees on their Play Online page, or an internet server address (starting with wss://).</p>
          <div class="join-row"><input type="text" id="joinAddr" placeholder="192.168.1.23 or wss://example.com" value="${hosting ? "" : esc(addr)}" spellcheck="false">
          <button class="btn green" id="joinBtn">Join</button></div></div>
        <div class="panel"><h2>Staying safe</h2><p class="hint">Chat only has ready-made phrases, so nobody can type messages to you. Only play with people you know.</p></div>
        ${row("Games you can play online", online)}`;
      const goOffline = $("#goOffline");
      if (goOffline) goOffline.onclick = async () => { if (hosting) await setHosting(false); setServer(""); render(); };
      const start = $("#startHost");
      if (start) start.onclick = () => setHosting(true);
      const stop = $("#stopHost");
      if (stop) stop.onclick = async () => { await setHosting(false); setServer(""); render(); };
      $("#joinBtn").onclick = () => joinServer($("#joinAddr").value);
      $("#joinAddr").onkeydown = (e) => { if (e.key === "Enter") joinServer(e.target.value); };
    },

    apps() {
      const avail = (id) => !sysInfo || sysInfo.apps[id];
      let html = `<h1 class="page-title">Apps</h1><div class="apps">${APPS.map((a) =>
        `<button class="app ${avail(a.id) ? "" : "off"}" data-launch="${a.id}"><span class="ico" style="background:${a.color}">${icon(a.id)}</span>
          ${esc(a.name)}<small>${avail(a.id) ? esc(a.desc) : "Not installed"}</small></button>`).join("")}</div>`;
      html += systemPanel();
      page.innerHTML = html;
    },

    settings() {
      const accents = ["#3b82f6", "#22c55e", "#ef4444", "#f59e0b", "#a855f7", "#ec4899", "#14b8a6"];
      page.innerHTML = `<h1 class="page-title">Settings</h1>
        <div class="panel"><h2>You</h2>
          <div class="setting"><div><b>Display name</b><p>Shown on your home page.</p></div>
            <input type="text" id="setName" maxlength="20" value="${esc(state.name)}"></div></div>
        <div class="panel"><h2>Look and sound</h2>
          <div class="setting"><div><b>Dark mode</b></div><button class="toggle ${state.theme === "dark" ? "on" : ""}" id="setTheme" aria-label="Dark mode"></button></div>
          <div class="setting"><div><b>Accent color</b></div><div class="accents">${accents.map((c) =>
            `<button style="background:${c}" class="${state.accent === c ? "on" : ""}" data-accent="${c}" aria-label="${c}"></button>`).join("")}</div></div>
          <div class="setting"><div><b>Game sounds</b></div><button class="toggle ${state.muted ? "" : "on"}" id="setSound" aria-label="Game sounds"></button></div></div>
        <div class="panel"><h2>Progress</h2>
          <div class="setting"><div><b>Reset everything</b><p>Clears Bricks, items, favorites and best scores.</p></div>
            <button class="btn red" id="resetAll">Reset</button></div></div>
        ${systemPanel()}
        <div class="panel"><h2>Power</h2><div class="setting"><div><b>Turn off or restart BlockOS</b></div>
          <div class="btns"><button class="btn" data-power="reboot">Restart</button> <button class="btn red" data-power="poweroff">Shut down</button></div></div></div>`;
      $("#setName").onchange = (e) => { state.name = e.target.value.trim().slice(0, 20) || "Player"; save(); render(); };
      $("#setTheme").onclick = () => { state.theme = state.theme === "dark" ? "light" : "dark"; applyTheme(); save(); render(); };
      $("#setSound").onclick = () => { state.muted = !state.muted; save(); render(); };
      $("#resetAll").onclick = () => confirmDialog("Reset everything?", "This can't be undone.", "Reset", () => {
        try {
          Object.keys(localStorage).filter((k) => k.startsWith("blockos.")).forEach((k) => localStorage.removeItem(k));
        } catch (_) {}
        Object.keys(state).forEach((k) => delete state[k]);
        Object.assign(state, JSON.parse(JSON.stringify(DEFAULT_STATE)));
        save();
        applyTheme();
        render();
        toast("Progress reset.");
      });
    },
  };

  function systemPanel() {
    if (!sysInfo) {
      return `<div class="panel"><h2>About BlockOS</h2><p class="empty" style="padding:0">Running in preview mode: system details and apps
        are available when BlockOS runs on its Debian virtual machine.</p></div>`;
    }
    const gb = (b) => (b ? (b / 1073741824).toFixed(1) + " GB" : "?");
    const up = sysInfo.uptime ? Math.floor(sysInfo.uptime / 3600) + "h " + Math.floor((sysInfo.uptime % 3600) / 60) + "m" : "?";
    const rows = [
      ["System", sysInfo.os], ["Debian version", sysInfo.debian], ["Kernel", sysInfo.kernel],
      ["Architecture", sysInfo.arch], ["Computer name", sysInfo.hostname], ["User", sysInfo.user],
      ["Processors", sysInfo.cpus], ["Memory", sysInfo.memory ? `${gb(sysInfo.memory.available)} free of ${gb(sysInfo.memory.total)}` : "?"],
      ["Uptime", up], ["Games installed", GAMES.length],
    ];
    return `<div class="panel"><h2>About BlockOS</h2><dl class="kv">${rows.filter(([, v]) => v !== null && v !== undefined && v !== "?").map(([k, v]) => `<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join("")}</dl></div>`;
  }

  // ---------------------------------------------------------------- online play

  let onlineInfo = null;
  const DEFAULT_GAME_PORT = 8790;
  function serverAddress() {
    try { return localStorage.getItem("blockos.server") || ""; } catch (_) { return ""; }
  }
  function setServer(url) {
    try { url ? localStorage.setItem("blockos.server", url) : localStorage.removeItem("blockos.server"); } catch (_) {}
    updateOnlinePill();
  }
  function updateOnlinePill() {
    $("#onlinePill").hidden = !serverAddress();
  }
  async function loadOnlineInfo() {
    try { onlineInfo = await api("/api/online"); } catch (_) { onlineInfo = null; }
  }
  async function setHosting(on) {
    try {
      onlineInfo = await api("/api/online", { host: on });
      if (on) {
        setServer(`ws://127.0.0.1:${onlineInfo.port}`);
        toast("You're hosting a server. Tell your friends the address on this page.");
      }
    } catch (e) {
      toast(sysInfo ? `Couldn't ${on ? "start" : "stop"} the server: ${esc(e.message)}` : "Hosting works in the BlockOS app and on the BlockOS virtual machine.");
    }
    render();
  }
  function normalizeAddress(text) {
    let a = String(text || "").trim();
    if (!a) return "";
    if (!/^wss?:\/\//i.test(a)) {
      a = a.replace(/^https?:\/\//i, "");
      a = "ws://" + (/:\d+$/.test(a) ? a : `${a}:${DEFAULT_GAME_PORT}`);
    }
    return a;
  }
  function joinServer(text) {
    const url = normalizeAddress(text);
    if (!url) return toast("Type a server address first.");
    let ws;
    try { ws = new WebSocket(url); } catch (_) { return toast("That doesn't look like a server address."); }
    toast("Connecting...");
    const timer = setTimeout(() => { ws.close(); toast("Couldn't reach that server. Check the address and that you're on the same Wi-Fi."); }, 4000);
    ws.onopen = () => {
      clearTimeout(timer);
      ws.close();
      setServer(url);
      toast("Connected! Online games will now put you on this server.");
      render();
    };
    ws.onerror = () => { clearTimeout(timer); toast("Couldn't reach that server. Check the address and that you're on the same Wi-Fi."); };
  }

  function applyTheme() {
    document.documentElement.dataset.theme = state.theme;
    document.documentElement.style.setProperty("--accent", state.accent);
  }

  // ---------------------------------------------------------------- game details & player

  function openGame(id) {
    const g = GAME_BY_ID[id];
    if (!g) return;
    const best = bestScore(id);
    const fmtBest = best === null ? "None yet" : g.lowerIsBetter ? best.toFixed(best % 1 ? 1 : 0) + "s" : best.toLocaleString();
    openModal(`<button class="icon-btn modal-close" data-close>${icon("close")}</button>
      <div class="gd">${thumb(g)}<div class="gd-info">
        <div><span class="gd-genre">${esc(g.genre)}</span></div>
        <h2>${esc(g.title)}</h2>
        <p>${esc(g.description)}</p>
        <div class="gd-controls"><b>Controls:</b> ${esc(g.controls)}</div>
        <div class="gd-stats"><div><small>${esc(g.scoreLabel || "Best")}</small><b>${esc(fmtBest)}</b></div>
          <div><small>Times played</small><b>${state.plays[id] || 0}</b></div>
          <div><small>Badges earned</small><b>${badgesFor(id).length}</b></div>
          <div><small>Online</small><b>${g.multiplayer ? (serverAddress() ? "Ready" : "Supported") : "Solo game"}</b></div></div>
        <div class="play-row">
          <button class="btn green play-btn" data-play="${id}" autofocus aria-label="Play">${icon("play")}</button>
          <button class="btn square-btn ${isFav(id) ? "on" : ""}" data-fav="${id}" title="Favorite">${icon("heart")}</button>
        </div></div></div>`);
  }

  const player = $("#player");
  const frame = $("#playerFrame");
  const pmenu = $("#playerMenu");
  let playing = null;
  let lastAward = {};

  function play(id) {
    const g = GAME_BY_ID[id];
    if (!g) return;
    closeModal();
    closeMenu();
    playing = id;
    state.plays[id] = (state.plays[id] || 0) + 1;
    state.last[id] = Date.now();
    save();
    $("#pmTitle").textContent = g.title;
    pmenu.hidden = true;
    player.hidden = false;
    frame.src = `games/${id}/index.html`;
    frame.onload = () => frame.contentWindow && frame.contentWindow.focus();
  }
  function leaveGame() {
    player.hidden = true;
    pmenu.hidden = true;
    frame.src = "about:blank";
    playing = null;
    render();
  }
  function togglePlayerMenu(show) {
    pmenu.hidden = show === undefined ? !pmenu.hidden : !show;
    if (pmenu.hidden) frame.contentWindow && frame.contentWindow.focus();
    else $('[data-pm="resume"]').focus();
  }
  $("#playerMenuBtn").onclick = () => togglePlayerMenu();
  pmenu.addEventListener("click", (e) => {
    const act = e.target.dataset.pm;
    if (act === "resume") togglePlayerMenu(false);
    if (act === "restart") { pmenu.hidden = true; frame.src = `games/${playing}/index.html`; }
    if (act === "leave") leaveGame();
    if (e.target === pmenu) togglePlayerMenu(false);
  });

  // Games report through Kit.finish(): you earn Bricks for every finished round, more for a new best.
  window.addEventListener("message", (e) => {
    if (e.source !== frame.contentWindow || !e.data || typeof e.data !== "object") return;
    if (e.data.type === "blockos:escape") return togglePlayerMenu();
    if (e.data.type === "blockos:badge" && e.data.game === playing) {
      state.bricks += 10;
      save();
      $("#brickCount").textContent = state.bricks.toLocaleString();
      return toast(`<b>Badge awarded: ${esc(e.data.name)}</b><br><small>${esc(e.data.desc || "")} (+10 Bricks)</small>`, true);
    }
    if (e.data.type !== "blockos:score" || e.data.game !== playing) return;
    const id = playing;
    const now = Date.now();
    if (now - (lastAward[id] || 0) < 8000) return; // no farming by spamming rounds
    lastAward[id] = now;
    let earned = 5;
    const newBest = e.data.best !== null && e.data.best !== undefined && e.data.best !== state.bestSeen[id] && e.data.best === e.data.score;
    if (newBest) {
      earned += 10;
      state.bestSeen[id] = e.data.best;
    }
    state.bricks += earned;
    save();
    $("#brickCount").textContent = state.bricks.toLocaleString();
    toast(`+${earned} Bricks${newBest ? " - new personal best!" : ""}`, true);
  });

  // ---------------------------------------------------------------- the MENU (all games)

  const menu = $("#gameMenu");
  const scrim = $("#scrim");
  const menuBtn = $("#menuBtn");
  let menuCat = "all";

  function menuCats() {
    const cats = [
      ["all", "All games", GAMES.length],
      ["favs", "Favorites", favorites().length],
      ["recent", "Recently played", recent().length],
      null,
      ...GENRES.map((gn) => ["genre:" + gn, gn, GAMES.filter((g) => g.genre === gn).length]),
      null,
      ["apps", "Apps", APPS.length],
    ];
    $("#gmCats").innerHTML = cats.map((c) => c ? `<button class="${menuCat === c[0] ? "on" : ""}" data-cat="${esc(c[0])}">${esc(c[1])}<small>${c[2]}</small></button>` : "<hr>").join("");
  }
  function menuGrid() {
    const q = $("#gmSearch").value.trim().toLowerCase();
    const grid = $("#gmGrid");
    if (menuCat === "apps") {
      $("#gmHeading").textContent = "Apps";
      grid.innerHTML = APPS.filter((a) => a.name.toLowerCase().includes(q)).map((a) =>
        `<button class="tile" data-launch="${a.id}"><div class="gm-app" style="color:#fff;background:${a.color}">${icon(a.id)}</div>
         <div class="t-name">${esc(a.name)}</div></button>`).join("");
      return;
    }
    let list = GAMES;
    let heading = "All games";
    if (menuCat === "favs") { list = favorites(); heading = "Favorites"; }
    else if (menuCat === "recent") { list = recent(); heading = "Recently played"; }
    else if (menuCat.startsWith("genre:")) { heading = menuCat.slice(6); list = GAMES.filter((g) => g.genre === heading); }
    if (q) list = list.filter((g) => (g.title + " " + g.genre).toLowerCase().includes(q));
    $("#gmHeading").textContent = heading;
    grid.innerHTML = list.length ? list.map(tile).join("")
      : `<div class="empty">${menuCat === "favs" && !q ? "Tap the heart on a game to add it here." : "Nothing here yet."}</div>`;
  }
  function openMenu() {
    menuCats();
    menuGrid();
    menu.hidden = false;
    scrim.hidden = false;
    menuBtn.setAttribute("aria-expanded", "true");
    $("#gmSearch").focus();
  }
  function closeMenu() {
    menu.hidden = true;
    scrim.hidden = true;
    menuBtn.setAttribute("aria-expanded", "false");
  }
  const toggleMenu = () => (menu.hidden ? openMenu() : closeMenu());
  menuBtn.onclick = toggleMenu;
  scrim.onclick = closeMenu;
  $("#gmSearch").addEventListener("input", menuGrid);

  // ---------------------------------------------------------------- global events

  document.addEventListener("click", (e) => {
    const t = e.target.closest("button, .me");
    if (!t) return;
    const d = t.dataset;
    if (t.id === "meCard") return go("avatar");
    if (d.page) return go(d.page);
    if (d.open) return openGame(d.open);
    if (d.play) return play(d.play);
    if (d.close !== undefined) return closeModal();
    if (d.launch) return launch(d.launch);
    if (d.power) return power(d.power);
    if (d.cat) { menuCat = d.cat; menuCats(); menuGrid(); return; }
    if (d.see) return go("discover", { genre: d.see });
    if (d.genre) { view.genre = d.genre; return render(); }
    if (d.atab) { view.avatarTab = d.atab; return render(); }
    if (d.accent) { state.accent = d.accent; applyTheme(); save(); return render(); }
    if (d.part) { state.avatar[d.part] = d.color; save(); return render(); }
    if (d.fav) {
      state.favs = isFav(d.fav) ? state.favs.filter((x) => x !== d.fav) : [...state.favs, d.fav];
      save();
      t.classList.toggle("on", isFav(d.fav));
      if (!menu.hidden) menuGrid();
      return render();
    }
    if (d.kind) return chooseItem(d.kind, d.item);
  });
  $("#powerBtn").onclick = () => openPowerMenu();
  $("#bricksBtn").onclick = () => go("avatar", { avatarTab: "hat" });

  function openPowerMenu() {
    openModal(`<div class="dialog"><h2>Power</h2><p>What would you like to do?</p>
      <div class="btns"><button class="btn" data-close>Cancel</button><button class="btn" data-power="reboot">Restart</button>
      <button class="btn red" data-power="poweroff">Shut down</button></div></div>`);
  }

  function chooseItem(kind, id) {
    const item = Avatar.ITEMS[kind].find((i) => i.id === id);
    if (owns(kind, item)) {
      state.avatar[kind] = id;
      save();
      return render();
    }
    if (state.bricks < item.price) {
      return toast(`You need ${item.price - state.bricks} more Bricks. Play games to earn them!`, true);
    }
    confirmDialog(`Buy ${item.name}?`, `It costs ${item.price} Bricks. You have ${state.bricks}.`, "Buy", () => {
      state.bricks -= item.price;
      state.owned.push(kind + ":" + id);
      state.avatar[kind] = id;
      save();
      render();
      toast(`You got ${esc(item.name)}!`);
    });
  }

  $("#search").addEventListener("input", (e) => {
    view.query = e.target.value;
    if (view.query.trim()) { view.page = "search"; render(); }
    else go("home");
  });

  // Super (Windows/Command) key tapped on its own toggles the menu, like a Start button.
  let superAlone = false;
  document.addEventListener("keydown", (e) => {
    if (e.key === "Meta" || e.key === "OS") { superAlone = true; return; }
    superAlone = false;
    if (e.key !== "Escape") return;
    if (!player.hidden) return togglePlayerMenu();
    if (!modal.hidden) return closeModal();
    if (!menu.hidden) return closeMenu();
  });
  document.addEventListener("keyup", (e) => {
    if ((e.key === "Meta" || e.key === "OS") && superAlone && player.hidden) toggleMenu();
    superAlone = false;
  });

  function tick() {
    $("#clock").textContent = new Date().toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  }

  // ---------------------------------------------------------------- start

  applyTheme();
  save();
  render();
  tick();
  setInterval(tick, 10000);
  // Lets the Mac app's server know a BlockOS window is still open (see server.py --idle-exit).
  const ping = () => fetch("/api/ping").catch(() => {});
  ping();
  setInterval(ping, 15000);
  document.addEventListener("visibilitychange", () => { if (!document.hidden) ping(); });
  updateOnlinePill();
  loadOnlineInfo();
  loadSysInfo().then(() => { if (view.page === "apps" || view.page === "settings") render(); });
  setTimeout(() => $("#boot").classList.add("done"), 1300);
  setTimeout(() => $("#boot").remove(), 1900);
})();
