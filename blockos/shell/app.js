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
    create: '<path d="m8 8-5 4 5 4M16 8l5 4-5 4M14 4l-4 16"/>',
    community: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><path d="M17.5 14v7M14 17.5h7"/>',
    back: '<path d="M15 5l-7 7 7 7"/>',
    expand: '<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>',
    download: '<path d="M12 4v11M7 10l5 5 5-5M5 20h14"/>',
    upload: '<path d="M12 16V5M7 10l5-5 5 5M5 20h14"/>',
    badge: '<circle cx="12" cy="9" r="6"/><path d="m8.5 13.5-1.5 7.5 5-3 5 3-1.5-7.5"/>',
    friends: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><circle cx="17" cy="9" r="2.5"/><path d="M16 14.5a5 5 0 0 1 6 5"/>',
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
  function closeModal() { modal.hidden = true; modal.innerHTML = ""; if (typeof openDm !== "undefined" && openDm) { openDm = null; render(); } }
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
      <div class="t-meta"><span>${esc(g.genre)}</span><span>${plays ? plays + (plays === 1 ? " play" : " plays") : "New"}</span>${g.multiplayer ? (lobby.stats[g.id] ? `<span class="t-online">${lobby.stats[g.id]} playing</span>` : '<span class="t-online">Online</span>') : ""}${g.is3d ? '<span class="t-3d">3D</span>' : ""}</div></button>`;
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
    { id: "community", label: "Community" },
    { id: "create", label: "Create" },
    { id: "avatar", label: "Avatar" },
    { id: "online", label: "Play Online" },
    { id: "friends", label: "Friends" },
    { id: "apps", label: "Apps" },
    { id: "settings", label: "Settings" },
  ];
  const view = { page: "home", genre: "All", sort: "plays", avatarTab: "colors", query: "" };
  const page = $("#page");

  function go(p, opts) {
    if (view.page === "create" && (p !== "create" || !(opts && opts.studioGame))) Studio.leaving();
    if (!opts || !("studioGame" in opts)) view.studioGame = null;
    Object.assign(view, opts || {}, { page: p });
    if (p !== "search") { view.query = ""; $("#search").value = ""; }
    render();
    page.scrollTop = 0;
  }

  // On the web (iPhone, iPad, any browser) there's no computer to open apps on or turn off.
  const webOnly = () => !sysInfo;
  function render() {
    document.documentElement.classList.toggle("web", webOnly());
    const waiting = Object.keys(Friends.requests()).length + Object.values(Friends.unread()).reduce((a, b) => a + b, 0);
    $("#nav").innerHTML = NAV.filter((n) => !(webOnly() && n.id === "apps")).map((n) =>
      `<button data-page="${n.id}" class="${view.page === n.id ? "active" : ""}">${icon(n.id)}<span>${n.label}</span>${n.id === "friends" && waiting ? `<em class="nav-count">${waiting}</em>` : ""}</button>`).join("");
    $("#meCard").innerHTML = `<div class="headshot">${Avatar.draw(state.avatar, { headshot: true })}</div>
      <div><b>${esc(state.name)}</b><small>View avatar</small></div>`;
    $("#brickCount").textContent = state.bricks.toLocaleString();
    (PAGES[view.page] || PAGES.home)();
  }

  const PAGES = {
    create() { Studio.createPage(page, view); },
    community() { Studio.communityPage(page, view); },

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
      const hostPanel = webOnly()
        ? `<div class="panel"><h2>Host a server</h2><p class="hint">Hosting needs the BlockOS app on a Mac or Windows computer (or the BlockOS virtual machine).
            On the web version you can join servers that have an internet address starting with <code>wss://</code>.</p></div>`
        : `<div class="panel"><h2>Host a server</h2>
            <p class="hint">Turns this computer into a game server. Your friends join it from their BlockOS using the address shown above.</p>
            ${hosting ? '<button class="btn red" id="stopHost">Stop hosting</button>' : '<button class="btn green" id="startHost">Start hosting</button>'}</div>
          ${internetPanel()}`;
      const officialPanel = OFFICIAL ? `<div class="panel"><h2>Official server</h2>
          <p class="hint">BlockOS's always-on server, where everyone can meet. It has many game servers, like Roblox: pick one on a game's page or just press Play.</p>
          ${addr === OFFICIAL ? `<p class="ok"><b>You're on the official server.</b></p>` : '<button class="btn green" id="goOfficial">Join the official server</button>'}</div>` : "";
      page.innerHTML = `<h1 class="page-title">Play Online</h1>
        <div class="panel"><h2>Status</h2><p>${status}</p>${addr ? '<button class="btn" id="goOffline">Go offline</button>' : ""}</div>
        ${officialPanel}
        ${hostPanel}
        <div class="panel"><h2>Join a server</h2>
          <p class="hint">Type the address your friend sees on their Play Online page, or an internet server address (starting with wss://).</p>
          <div class="join-row"><input type="text" id="joinAddr" placeholder="192.168.1.23 or wss://example.com" value="${hosting ? "" : esc(addr)}" spellcheck="false">
          <button class="btn green" id="joinBtn">Join</button></div></div>
        <div class="panel"><h2>Staying safe</h2><p class="hint">Chat is filtered: swear words, phone numbers, emails and links are hidden.
          You can mute anyone from the People list in a game, and choose who can chat with you in Settings. Only play with people you know,
          and never share where you live or your passwords.</p></div>
        ${row("Games you can play online", online)}`;
      const goOffline = $("#goOffline");
      if (goOffline) goOffline.onclick = async () => { if (hosting) await setHosting(false); setServer(""); render(); };
      const start = $("#startHost");
      if (start) start.onclick = () => setHosting(true);
      const stop = $("#stopHost");
      if (stop) stop.onclick = async () => { await setHosting(false); setServer(""); render(); };
      $("#joinBtn").onclick = () => joinServer($("#joinAddr").value);
      const goOfficial = $("#goOfficial");
      if (goOfficial) goOfficial.onclick = () => { setServer(OFFICIAL); toast("Joined the official server."); render(); };
      const goPublic = $("#goPublic");
      if (goPublic) goPublic.onclick = () => setInternet(true);
      const stopPublic = $("#stopPublic");
      if (stopPublic) stopPublic.onclick = () => setInternet(false);
      const copyPublic = $("#copyPublic");
      if (copyPublic) copyPublic.onclick = async () => {
        try { await navigator.clipboard.writeText(onlineInfo.internet.url); toast("Address copied. Send it to your friends."); }
        catch (_) { const r = document.createRange(); r.selectNodeContents($("#publicAddr")); getSelection().removeAllRanges(); getSelection().addRange(r); }
      };
      $("#joinAddr").onkeydown = (e) => { if (e.key === "Enter") joinServer(e.target.value); };
    },

    friends() {
      const list = Object.entries(Friends.list()).sort((a, b) => a[1].name.localeCompare(b[1].name));
      const requests = Object.entries(Friends.requests());
      const online = !!serverAddress() && lobby.connected;
      const status = (code) => {
        const p = lobby.presence[code];
        if (!p) return { text: online ? "Offline" : "", game: null };
        const g = GAME_BY_ID[p.game];
        return g ? { text: `Playing ${g.title}${p.server ? ` (${serverName(p.server)})` : ""}`, game: g.id, server: p.server } : { text: "On BlockOS", game: null };
      };
      const sorted = list.sort((a, b) => (!!lobby.presence[b[0]] - !!lobby.presence[a[0]]));
      page.innerHTML = `<h1 class="page-title">Friends</h1>
        <div class="panel"><h2>Your friend code</h2>
          <p class="hint">Give this code to friends so they can add you.</p>
          <div class="code-row"><span class="friend-code" id="myCode">${esc(Friends.pretty(Friends.code()))}</span>
          <button class="btn" id="copyCode">Copy</button></div></div>
        <div class="panel"><h2>Add a friend</h2>
          ${online ? `<p class="hint">Type your friend's code. They need to be online on the same server to get your request.
            You can also tap People inside an online game and choose Add friend.</p>`
            : `<p class="hint">${webOnly() ? "Friends work in the BlockOS app on a Mac or Windows computer (or the BlockOS virtual machine)."
              : 'Go online first: open <b>Play Online</b> and host or join a server.'}</p>`}
          <div class="join-row"><input type="text" id="addCode" placeholder="ABCD-1234" maxlength="9" spellcheck="false" autocapitalize="characters" ${online ? "" : "disabled"}>
          <button class="btn green" id="addBtn" ${online ? "" : "disabled"}>Send request</button></div></div>
        ${requests.length ? `<div class="panel"><h2>Friend requests</h2>${requests.map(([code, r]) => `
          <div class="friend-row"><div class="headshot">${Avatar.draw(r.avatar, { headshot: true })}</div>
            <div class="friend-info"><b>${esc(r.name)}</b><small>${esc(Friends.pretty(code))}</small></div>
            <button class="btn green" data-fr-accept="${code}">Accept</button><button class="btn" data-fr-decline="${code}">No thanks</button></div>`).join("")}</div>` : ""}
        <div class="panel"><h2>Your friends (${list.length})</h2>
          ${list.length ? sorted.map(([code, f]) => {
            const st = status(code);
            return `<div class="friend-row"><div class="headshot">${Avatar.draw(f.avatar, { headshot: true })}</div>
              <div class="friend-info"><b>${esc(f.name)}</b><small class="${lobby.presence[code] ? "on" : ""}">${esc(st.text || Friends.pretty(code))}</small></div>
              ${st.game ? `<button class="btn green" data-play="${st.game}" data-server="${esc(st.server || "")}">Join</button>` : ""}
              ${chatMode() === "off" ? "" : `<button class="btn" data-dm="${code}">Message${Friends.unread()[code] ? ` <em class="dm-count">${Friends.unread()[code]}</em>` : ""}</button>`}
              <button class="btn" data-fr-remove="${code}">Remove</button></div>`;
          }).join("") : `<div class="empty">No friends yet. Add someone with their code, or from the People list in an online game.</div>`}</div>`;
      $("#copyCode").onclick = async () => {
        try { await navigator.clipboard.writeText(Friends.pretty(Friends.code())); toast("Friend code copied."); }
        catch (_) { const r = document.createRange(); r.selectNodeContents($("#myCode")); getSelection().removeAllRanges(); getSelection().addRange(r); }
      };
      const add = () => {
        const code = $("#addCode").value.toUpperCase().replace(/[^A-Z0-9]/g, "");
        if (!/^[A-HJ-NP-Z2-9]{8}$/.test(code)) return toast("Friend codes have 8 letters and numbers, like ABCD-2345.");
        if (code === Friends.code()) return toast("That's your own code!");
        if (Friends.list()[code]) return toast("You're already friends.");
        lobby.send({ t: "fr", to: code, kind: "request" });
        toast("Friend request sent.");
        $("#addCode").value = "";
      };
      $("#addBtn").onclick = add;
      $("#addCode").onkeydown = (e) => { if (e.key === "Enter") add(); };
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
        <div class="panel"><h2>Chat</h2>
          <div class="setting"><div><b>Who can chat with me</b><p>Applies to typed chat in online games and to private messages.
            Messages are always filtered for swear words and personal details.</p></div>
            <select id="setChat"><option value="all">Everyone</option><option value="friends">Friends only</option><option value="off">Nobody (chat off)</option></select></div></div>
        <div class="panel"><h2>Progress</h2>
          <div class="setting"><div><b>Reset everything</b><p>Clears Bricks, items, favorites and best scores.</p></div>
            <button class="btn red" id="resetAll">Reset</button></div></div>
        ${systemPanel()}
        <div class="panel web-hide"><h2>Power</h2><div class="setting"><div><b>Turn off or restart BlockOS</b></div>
          <div class="btns"><button class="btn" data-power="reboot">Restart</button> <button class="btn red" data-power="poweroff">Shut down</button></div></div></div>`;
      $("#setName").onchange = (e) => { state.name = e.target.value.trim().slice(0, 20) || "Player"; save(); render(); };
      $("#setTheme").onclick = () => { state.theme = state.theme === "dark" ? "light" : "dark"; applyTheme(); save(); render(); };
      $("#setSound").onclick = () => { state.muted = !state.muted; save(); render(); };
      $("#setChat").value = chatMode();
      $("#setChat").onchange = (e) => { try { localStorage.setItem("blockos.chatMode", e.target.value); } catch (_) {} toast("Chat setting saved."); };
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
  const OFFICIAL = ((window.BLOCKOS_CONFIG || {}).officialServer || "").trim();
  function setServer(url) {
    try {
      url ? localStorage.setItem("blockos.server", url) : localStorage.removeItem("blockos.server");
      // Remember that the player went offline on purpose, so the official server isn't rejoined.
      if (OFFICIAL) localStorage.setItem("blockos.offline", url ? "0" : "1");
    } catch (_) {}
    updateOnlinePill();
    lobbyConnect();
  }
  function updateOnlinePill() {
    $("#onlinePill").hidden = !serverAddress();
  }
  async function loadOnlineInfo() {
    try { onlineInfo = await api("/api/online"); } catch (_) { onlineInfo = null; }
  }
  // Friends anywhere in the world: the Mac/Windows app opens a Cloudflare tunnel to your server.
  function internetPanel() {
    const net = onlineInfo && onlineInfo.internet;
    if (!net) return "";   // only the Mac and Windows app can do this
    const note = `<p class="hint">Gives your server an internet address so friends anywhere in the world can join. BlockOS downloads
      a free connector from Cloudflare the first time (about 20 MB). The address changes every time you start it.
      Only send it to people you know.</p>`;
    let body;
    if (net.status === "on") {
      body = `<p>Friends anywhere join by typing this under <b>Join a server</b>:</p>
        <div class="code-row"><code class="public-addr" id="publicAddr">${esc(net.url)}</code><button class="btn" id="copyPublic">Copy</button></div>
        <p class="hint">Keep BlockOS open while people play. Cloudflare's free connections have no uptime guarantee, so if it stops, start it again.</p>
        <button class="btn red" id="stopPublic">Stop internet hosting</button>`;
    } else if (net.status === "starting") {
      body = `${note}<p><b>Connecting to the internet...</b> This can take up to a minute the first time.</p>`;
    } else {
      body = `${note}${net.status === "error" ? `<p class="bad">${esc(net.error || "Something went wrong.")}</p>` : ""}
        <button class="btn green" id="goPublic">${net.status === "error" ? "Try again" : "Let friends anywhere join"}</button>`;
    }
    return `<div class="panel"><h2>Friends anywhere</h2>${body}</div>`;
  }
  let internetPoll = 0;
  async function setInternet(on) {
    try {
      onlineInfo = await api("/api/online", { internet: on });
      if (on) setServer(`ws://127.0.0.1:${onlineInfo.port}`);   // the host plays on their own server
    } catch (e) {
      toast(`Couldn't ${on ? "start" : "stop"} internet hosting: ${esc(e.message)}`);
    }
    render();
    watchInternet();
  }
  // While the connection is starting, check every 2 seconds and update the page.
  function watchInternet() {
    clearInterval(internetPoll);
    if (!onlineInfo || !onlineInfo.internet || onlineInfo.internet.status !== "starting") return;
    internetPoll = setInterval(async () => {
      try { onlineInfo = await api("/api/online"); } catch (_) { return; }
      if (onlineInfo.internet.status !== "starting") {
        clearInterval(internetPoll);
        if (onlineInfo.internet.status === "on") toast("Your server is on the internet! Copy the address and send it to your friends.");
        if (view.page === "online") render();
      }
    }, 2000);
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
    if (/^https:\/\//i.test(a)) return a.replace(/^https:/i, "wss:");
    if (/^wss?:\/\//i.test(a)) return a;
    a = a.replace(/^http:\/\//i, "");
    const host = a.split("/")[0];
    // A local address (192.168.1.23, localhost) uses BlockOS's own game port; an internet name
    // (like happy-blocks.trycloudflare.com) is reached over a secure connection.
    if (/^(localhost|\d{1,3}(\.\d{1,3}){3})(:\d+)?$/i.test(host)) return "ws://" + (/:\d+$/.test(host) ? host : `${host}:${DEFAULT_GAME_PORT}`);
    return "wss://" + host;
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

  // ---------------------------------------------------------------- friends
  // Same storage keys as Kit.friends in games/kit.js, so games and the desktop share one list.

  const Friends = (() => {
    const CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const read = (k) => { try { return JSON.parse(localStorage.getItem(k)) || {}; } catch (_) { return {}; } };
    const write = (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); } catch (_) {} };
    const code = () => {
      let c = null;
      try { c = localStorage.getItem("blockos.uid"); } catch (_) {}
      if (!c || !/^[A-HJ-NP-Z2-9]{8}$/.test(c)) {
        const r = new Uint8Array(8);
        crypto.getRandomValues(r);
        c = [...r].map((x) => CHARS[x % CHARS.length]).join("");
        try { localStorage.setItem("blockos.uid", c); } catch (_) {}
      }
      return c;
    };
    return {
      code, pretty: (c) => c.slice(0, 4) + "-" + c.slice(4),
      list: () => read("blockos.friends"),
      requests: () => read("blockos.requests"),
      add(c, name, avatar) {
        const f = read("blockos.friends");
        f[c] = { name, avatar: avatar || {}, since: (f[c] && f[c].since) || Date.now() };
        write("blockos.friends", f);
        const r = read("blockos.requests"); delete r[c]; write("blockos.requests", r);
      },
      remove(c) { const f = read("blockos.friends"); delete f[c]; write("blockos.friends", f); },
      addRequest(c, name, avatar) { const r = read("blockos.requests"); r[c] = { name, avatar: avatar || {}, time: Date.now() }; write("blockos.requests", r); },
      clearRequest(c) { const r = read("blockos.requests"); delete r[c]; write("blockos.requests", r); },
      // Private messages: { code: [{ me: true|false, text, time }] }, last 60 per friend.
      messages: (c) => read("blockos.dm")[c] || [],
      addMessage(c, me, text) {
        const all = read("blockos.dm");
        all[c] = (all[c] || []).concat({ me, text, time: Date.now() }).slice(-60);
        write("blockos.dm", all);
      },
      unread: () => read("blockos.dmUnread"),
      setUnread(c, n) { const u = read("blockos.dmUnread"); if (n) u[c] = n; else delete u[c]; write("blockos.dmUnread", u); },
    };
  })();
  const chatMode = () => { try { return localStorage.getItem("blockos.chatMode") || "all"; } catch (_) { return "all"; } };

  // While BlockOS is online, the desktop keeps one connection to the server in the "lobby"
  // so it can see which friends are online and receive friend requests.
  const lobby = {
    ws: null, connected: false, presence: {}, url: "", stats: {},
    send(msg) { if (this.ws && this.ws.readyState === 1) this.ws.send(JSON.stringify(msg)); },
  };
  function lobbyConnect() {
    const url = serverAddress();
    if (lobby.ws && lobby.url === url) return;
    if (lobby.ws) { lobby.ws.onclose = null; lobby.ws.close(); lobby.ws = null; lobby.connected = false; lobby.presence = {}; }
    lobby.url = url;
    if (!url) return;
    let ws;
    try { ws = new WebSocket(url); } catch (_) { return; }
    lobby.ws = ws;
    ws.onopen = () => {
      lobby.send({ t: "hello", game: "lobby", name: state.name, avatar: state.avatar, uid: Friends.code() });
    };
    ws.onmessage = (ev) => {
      let m;
      try { m = JSON.parse(ev.data); } catch (_) { return; }
      if (!m || Studio.onLobby(m)) return;   // community games (studio/studio.js)
      if (m.t === "welcome") {
        lobby.connected = true;
        askWho();
        lobby.send({ t: "stats" });
        Studio.onConnected();
        if (view.page === "friends" || view.page === "community") render();
      }
      else if (m.t === "list") {
        serverLists[m.game] = { servers: m.servers || {}, max: m.max || 12, time: Date.now() };
        renderServerList(m.game);
      } else if (m.t === "stats") {
        const changed = JSON.stringify(lobby.stats) !== JSON.stringify(m.games || {});
        lobby.stats = m.games || {};
        if (changed && player.hidden && modal.hidden && ["home", "discover", "online", "search"].includes(view.page)) render();
      }
      else if (m.t === "who") {
        lobby.presence = {};
        for (const [c, p] of Object.entries(m.s || {})) if (p) lobby.presence[c] = p;
        if (view.page === "friends") render();
      } else if (m.t === "fr") friendMessage(m);
      else if (m.t === "dm") {
        if (!Friends.list()[m.from] || chatMode() === "off") return;   // only friends can message you
        Friends.addMessage(m.from, false, String(m.text));
        if (openDm === m.from) renderDm();
        else {
          Friends.setUnread(m.from, (Friends.unread()[m.from] || 0) + 1);
          if (player.hidden) { toast(`<b>${esc(m.name || "A friend")}:</b> ${esc(m.text)}`); render(); }
        }
      } else if (m.t === "dm-sent") {
        Friends.addMessage(m.to, true, String(m.text));
        if (openDm === m.to) renderDm();
      } else if (m.t === "dm-offline") {
        toast("Your friend isn't online right now, so the message wasn't sent.");
      } else if (m.t === "slow") toast("You're sending messages too fast. Wait a moment.");
      else if (m.t === "fr-offline" && m.kind === "request") toast("That friend code isn't online right now. They need to be online on this server to get your request.");
    };
    ws.onclose = () => {
      const was = lobby.connected;
      lobby.connected = false;
      if (was && view.page === "community" && player.hidden) setTimeout(render);
      lobby.presence = {};
      lobby.stats = {};
      if (lobby.ws === ws) { lobby.ws = null; setTimeout(lobbyConnect, 4000); }
    };
  }
  function askWho() {
    const ids = Object.keys(Friends.list());
    if (ids.length) lobby.send({ t: "who", ids });
  }
  setInterval(askWho, 8000);
  setInterval(() => lobby.send({ t: "stats" }), 15000);

  let openDm = null;
  function openMessages(code) {
    const f = Friends.list()[code];
    if (!f) return;
    openDm = code;
    Friends.setUnread(code, 0);
    render();   // clears the unread badge on Friends
    openModal(`<button class="icon-btn modal-close" data-close>${icon("close")}</button>
      <div class="dm"><div class="dm-head"><div class="headshot">${Avatar.draw(f.avatar, { headshot: true })}</div>
        <div><b>${esc(f.name)}</b><small id="dmStatus"></small></div></div>
        <div class="dm-log" id="dmLog"></div>
        <form class="dm-send" id="dmForm"><input type="text" id="dmInput" maxlength="120" placeholder="Message ${esc(f.name)}" autocomplete="off" autofocus>
          <button class="btn green">Send</button></form>
        <p class="dm-note">Messages are filtered: swear words and things like phone numbers, emails and links show as ####.</p></div>`, "dm-card");
    $("#dmForm").onsubmit = (e) => {
      e.preventDefault();
      const text = $("#dmInput").value.trim();
      if (!text) return;
      if (!lobby.connected) return toast("Go online first (Play Online) to send messages.");
      lobby.send({ t: "dm", to: code, text });
      $("#dmInput").value = "";
    };
    renderDm();
  }
  function renderDm() {
    const log = $("#dmLog");
    if (!log || !openDm) return;
    const msgs = Friends.messages(openDm);
    log.innerHTML = msgs.length ? msgs.map((m) => `<div class="dm-msg ${m.me ? "me" : ""}"><span>${esc(m.text)}</span>
      <small>${new Date(m.time).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}</small></div>`).join("")
      : `<div class="empty">No messages yet. Say hi!</div>`;
    log.scrollTop = log.scrollHeight;
    const p = lobby.presence[openDm];
    $("#dmStatus").textContent = p ? (GAME_BY_ID[p.game] ? `Playing ${GAME_BY_ID[p.game].title}` : "Online") : "Offline";
  }

  function friendMessage(m) {
    const name = String(m.name || "Player");
    const inGame = !player.hidden;   // the game shows its own pop-up for requests
    if (m.kind === "request") {
      if (Friends.list()[m.from]) { lobby.send({ t: "fr", to: m.from, kind: "accept" }); return; }
      Friends.addRequest(m.from, name, m.avatar);
      if (!inGame) toast(`<b>${esc(name)}</b> wants to be your friend. Open <b>Friends</b> to answer.`);
    } else if (m.kind === "accept") {
      Friends.add(m.from, name, m.avatar);
      if (!inGame) toast(`You and <b>${esc(name)}</b> are now friends!`);
      askWho();
    } else if (m.kind === "decline") {
      if (!inGame) toast(`${esc(name)} said no thanks to your friend request.`);
    } else if (m.kind === "remove") {
      Friends.remove(m.from);
    }
    if (player.hidden) render();
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
        </div></div></div>
      ${g.multiplayer && lobby.connected ? `<div class="servers"><div class="servers-head"><h3>Servers</h3>
        <button class="btn" data-new-server="${id}">New server</button></div><div id="serverList" class="empty">Looking for servers...</div></div>` : ""}`);
    if (g.multiplayer && lobby.connected) { serverListFor = id; lobby.send({ t: "list", game: id }); }
  }

  // ---------------------------------------------------------------- servers (like Roblox)

  const serverName = (s) => "Server " + String(s).slice(1);
  let serverListFor = null;
  const serverLists = {};   // game -> { servers: { s1: 3 }, max }
  function renderServerList(game) {
    const el = $("#serverList");
    if (!el || serverListFor !== game) return;
    const info = serverLists[game] || { servers: {}, max: 12 };
    // Always show servers 1-3, plus any others with people on them.
    const ids = new Set(["s1", "s2", "s3", ...Object.keys(info.servers)]);
    const friendsOn = {};
    for (const [code, p] of Object.entries(lobby.presence)) {
      const f = Friends.list()[code];
      if (f && p.game === game && p.server) (friendsOn[p.server] = friendsOn[p.server] || []).push(f.name);
    }
    el.className = "server-list";
    el.innerHTML = [...ids].sort((a, b) => +a.slice(1) - +b.slice(1)).map((s) => {
      const n = info.servers[s] || 0;
      const full = n >= info.max;
      return `<div class="server-row"><div><b>${serverName(s)}</b>
        <small>${n}/${info.max} players${friendsOn[s] ? ` - friends: ${friendsOn[s].map(esc).join(", ")}` : ""}</small>
        <i class="server-bar"><i style="width:${Math.min(100, (n / info.max) * 100)}%"></i></i></div>
        <button class="btn ${full ? "" : "green"}" data-play="${game}" data-server="${s}" ${full ? "disabled" : ""}>${full ? "Full" : "Join"}</button></div>`;
    }).join("");
  }
  setInterval(() => { if (serverListFor && !modal.hidden && lobby.connected) lobby.send({ t: "list", game: serverListFor }); }, 4000);

  // The Play button: like Roblox, put you on the busiest server that still has room.
  function quickPlay(id) {
    const g = GAME_BY_ID[id];
    if (!g || !g.multiplayer || !lobby.connected) return play(id);
    const info = serverLists[id];
    const pick = () => {
      const data = serverLists[id] || { servers: {}, max: 12 };
      const open = Object.entries(data.servers).filter(([, n]) => n < data.max).sort((a, b) => b[1] - a[1]);
      if (open.length) return open[0][0];
      for (let i = 1; ; i++) if (!data.servers["s" + i]) return "s" + i;
    };
    if (info && Date.now() - info.time < 5000) return play(id, pick());
    lobby.send({ t: "list", game: id });
    let waited = 0;
    const wait = setInterval(() => {
      waited += 100;
      if ((serverLists[id] && Date.now() - serverLists[id].time < 5000) || waited > 1500) { clearInterval(wait); play(id, pick()); }
    }, 100);
  }
  function newServer(id) {
    const data = serverLists[id] || { servers: {} };
    for (let i = 1; ; i++) if (!data.servers["s" + i]) return play(id, "s" + i);
  }

  const player = $("#player");
  const frame = $("#playerFrame");
  const pmenu = $("#playerMenu");
  let playing = null;
  let lastAward = {};

  function play(id, server) {
    const g = GAME_BY_ID[id];
    if (!g) return;
    if (server && !/^s\d{1,3}$/.test(server)) server = null;
    closeModal();
    closeMenu();
    playing = id;
    state.plays[id] = (state.plays[id] || 0) + 1;
    state.last[id] = Date.now();
    save();
    $("#pmTitle").textContent = g.title;
    pmenu.hidden = true;
    player.hidden = false;
    sandboxed = null;
    frame.removeAttribute("sandbox");
    frame.removeAttribute("srcdoc");
    frame.src = `games/${id}/index.html${server ? `?server=${server}` : ""}`;
    if (server) toast(`Joining ${esc(g.title)}, ${serverName(server)}`);
    frame.onload = () => frame.contentWindow && frame.contentWindow.focus();
  }
  // A game a player made (Create, or Community): runs in the sandbox from studio/runner.js.
  let sandboxed = null;   // { title, code, dataId, server }
  function playSandboxed(game) {
    closeModal();
    closeMenu();
    sandboxed = game;
    playing = "u:" + game.dataId;
    $("#pmTitle").textContent = game.title;
    pmenu.hidden = true;
    player.hidden = false;
    loadSandboxed();
    frame.onload = () => frame.contentWindow && frame.contentWindow.focus();
  }
  function loadSandboxed() {
    StudioRunner.load(frame, sandboxed.code, { id: sandboxed.dataId, server: sandboxed.server, data: StudioRunner.loadData(sandboxed.dataId) });
  }
  function leaveGame() {
    player.hidden = true;
    pmenu.hidden = true;
    frame.removeAttribute("srcdoc");
    frame.src = "about:blank";
    playing = null;
    sandboxed = null;
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
    if (act === "restart") { pmenu.hidden = true; if (sandboxed) loadSandboxed(); else frame.src = frame.src; }
    if (act === "leave") leaveGame();
    if (e.target === pmenu) togglePlayerMenu(false);
  });

  // Games report through Kit.finish(): you earn Bricks for every finished round, more for a new best.
  window.addEventListener("message", (e) => {
    if (e.source !== frame.contentWindow || !e.data || typeof e.data !== "object") return;
    if (e.data.type === "blockos:escape") return togglePlayerMenu();
    if (sandboxed) {
      // Made-by-players games keep their own saves, and don't earn Bricks (anyone could write a game that hands them out).
      if (e.data.type === "blockos:studio-save") StudioRunner.onSave(sandboxed.dataId, e.data.data);
      if (e.data.type === "blockos:badge") toast(`<b>Badge: ${esc(String(e.data.name || ""))}</b><br><small>Badges in community games don't give Bricks.</small>`);
      return;
    }
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
    if (d.play) return d.server ? play(d.play, d.server) : quickPlay(d.play);
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
    if (d.frAccept) {
      const r = Friends.requests()[d.frAccept];
      if (r) { Friends.add(d.frAccept, r.name, r.avatar); lobby.send({ t: "fr", to: d.frAccept, kind: "accept" }); toast(`You and <b>${esc(r.name)}</b> are now friends!`); askWho(); }
      return render();
    }
    if (d.dm) return openMessages(d.dm);
    if (d.newServer) return newServer(d.newServer);
    if (d.frDecline) { Friends.clearRequest(d.frDecline); lobby.send({ t: "fr", to: d.frDecline, kind: "decline" }); return render(); }
    if (d.frRemove) {
      const f = Friends.list()[d.frRemove];
      return confirmDialog(`Remove ${f ? f.name : "this friend"}?`, "You can add each other again later.", "Remove", () => {
        Friends.remove(d.frRemove);
        lobby.send({ t: "fr", to: d.frRemove, kind: "remove" });
        render();
      });
    }
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

  // ---------------------------------------------------------------- Create & Community (studio/studio.js)

  const Studio = window.BlockStudio({
    $, $$, esc, icon, toast, openModal, closeModal, confirmDialog, fallbackThumb, state, lobby, view, go, render, webOnly, playSandboxed,
    onlineInfo: () => onlineInfo,
    playerHidden: () => player.hidden,
  });

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
  try {
    if (OFFICIAL && !serverAddress() && localStorage.getItem("blockos.offline") !== "1") localStorage.setItem("blockos.server", OFFICIAL);
  } catch (_) {}
  updateOnlinePill();
  lobbyConnect();
  loadOnlineInfo().then(() => { watchInternet(); if (lobby.connected) Studio.onConnected(); });
  loadSysInfo().then(() => render());
  setTimeout(() => $("#boot").classList.add("done"), 1300);
  setTimeout(() => $("#boot").remove(), 1900);
})();
