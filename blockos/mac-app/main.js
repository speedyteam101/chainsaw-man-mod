// BlockOS as a Mac and Windows app: the BlockOS desktop in its own window, built with Electron.
// The desktop's files are served from a private "blockos://" address so saves
// (Bricks, avatar, best scores) persist, and the small /api/* that server.py
// provides on the VM is answered here instead.
"use strict";

const { app, BrowserWindow, protocol, net, shell } = require("electron");
const { execFile } = require("child_process");
const os = require("os");
const path = require("path");
const { pathToFileURL } = require("url");

// Packaged: the desktop is copied next to this file. Running from the repo: use ../shell.
const SHELL_DIR = app.isPackaged ? path.join(__dirname, "shell") : path.join(__dirname, "..", "shell");
const relay = require(app.isPackaged ? "./relay.js" : "../multiplayer/relay.js");
const { createTunnel } = require("./tunnel.js");

// "Host a server" on the Play Online page runs the game server inside the app.
const GAME_PORT = 8790;
let gameServer = null;

function lanAddresses() {
  return Object.values(os.networkInterfaces()).flat()
    .filter((i) => i && i.family === "IPv4" && !i.internal).map((i) => i.address);
}

// "Let friends anywhere join": a Cloudflare quick tunnel to the game server (see tunnel.js).
const tunnel = createTunnel({ dir: () => path.join(app.getPath("userData"), "bin"), fetch: (u) => net.fetch(u), port: GAME_PORT });

function onlineInfo() {
  return { hosting: !!gameServer, port: GAME_PORT, addresses: gameServer ? lanAddresses() : [], internet: tunnel.info() };
}

async function setHosting(on) {
  if (on && !gameServer) {
    const server = relay.start(GAME_PORT);
    await server.ready;   // throws if the port is busy
    gameServer = server;
  } else if (!on && gameServer) {
    tunnel.stop();
    await gameServer.close();
    gameServer = null;
  }
  return onlineInfo();
}

async function setInternet(on) {
  if (on) {
    await setHosting(true);
    tunnel.start();
  } else {
    tunnel.stop();
  }
  return onlineInfo();
}

// The Apps page opens the matching apps of the computer BlockOS runs on: [program, args].
const IS_WINDOWS = process.platform === "win32";
const NATIVE_APPS = IS_WINDOWS
  ? {
      terminal: ["cmd.exe", ["/c", "start", "", "powershell.exe"]],
      files: ["explorer.exe", [os.homedir()]],
      browser: ["cmd.exe", ["/c", "start", "", "msedge"]],
      editor: ["notepad.exe", []],
      taskmanager: ["taskmgr.exe", []],
      calculator: ["calc.exe", []],
    }
  : {
      terminal: ["open", ["-a", "Terminal"]],
      files: ["open", [os.homedir()]],
      browser: ["open", ["-a", "Safari"]],
      editor: ["open", ["-a", "TextEdit"]],
      taskmanager: ["open", ["-a", "Activity Monitor"]],
      calculator: ["open", ["-a", "Calculator"]],
    };

protocol.registerSchemesAsPrivileged([
  { scheme: "blockos", privileges: { standard: true, secure: true, supportFetchAPI: true, stream: true } },
]);

const json = (status, body) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

function systemInfo() {
  return {
    hostname: os.hostname(),
    os: (IS_WINDOWS ? "Windows " : "macOS ") + process.getSystemVersion(),
    debian: null,
    kernel: os.release(),
    arch: os.arch(),
    cpus: os.cpus().length,
    memory: { total: os.totalmem(), available: os.freemem() },
    uptime: os.uptime(),
    user: os.userInfo().username,
    apps: Object.fromEntries(Object.keys(NATIVE_APPS).map((k) => [k, true])),
  };
}

async function handleApi(request, pathname) {
  if (pathname === "/api/info") return json(200, systemInfo());
  if (pathname === "/api/ping") return json(200, { ok: true });
  if (pathname === "/api/online" && request.method !== "POST") return json(200, onlineInfo());
  if (request.method !== "POST") return json(404, { error: "not found" });

  let data = {};
  try { data = await request.json(); } catch (_) { return json(400, { error: "bad json" }); }

  if (pathname === "/api/online") {
    try {
      if ("internet" in data) return json(200, await setInternet(!!data.internet));
      return json(200, await setHosting(!!data.host));
    } catch (e) { return json(500, { error: e.message }); }
  }
  if (pathname === "/api/launch") {
    const cmd = NATIVE_APPS[data.app];
    if (!cmd) return json(404, { error: "app not installed" });
    execFile(cmd[0], cmd[1], { windowsHide: true }, () => {});
    return json(200, { ok: true });
  }
  if (pathname === "/api/power") {
    // In the app, "Shut down" closes BlockOS and "Restart" restarts BlockOS (not the computer).
    if (data.action === "poweroff") setTimeout(() => app.quit(), 300);
    else if (data.action === "reboot") setTimeout(() => { app.relaunch(); app.quit(); }, 300);
    else return json(400, { error: "unknown action" });
    return json(200, { ok: true });
  }
  return json(404, { error: "not found" });
}

function serveFiles() {
  protocol.handle("blockos", (request) => {
    const url = new URL(request.url);
    const pathname = decodeURIComponent(url.pathname);
    if (pathname.startsWith("/api/")) return handleApi(request, pathname);

    const file = path.normalize(path.join(SHELL_DIR, pathname === "/" ? "index.html" : pathname));
    if (!file.startsWith(SHELL_DIR + path.sep)) return new Response("forbidden", { status: 403 });
    return net.fetch(pathToFileURL(file).toString());
  });
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 800,
    minHeight: 560,
    title: "BlockOS",
    backgroundColor: "#16181b",
    autoHideMenuBar: true,   // Windows: no File/Edit/View bar over the desktop (Alt shows it)
    show: false,
    webPreferences: { contextIsolation: true, sandbox: true },
  });
  win.once("ready-to-show", () => win.show());
  // Links to real websites open in the normal browser instead of inside BlockOS.
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith("https:") || url.startsWith("http:")) shell.openExternal(url);
    return { action: "deny" };
  });
  win.webContents.on("will-navigate", (event, url) => {
    if (!url.startsWith("blockos://")) event.preventDefault();
  });
  win.loadURL("blockos://app/");
}

app.setName("BlockOS");
app.whenReady().then(() => {
  serveFiles();
  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});
app.on("window-all-closed", () => app.quit());
app.on("before-quit", () => tunnel.stop());
