// Makes the hosted game server reachable from anywhere through a free Cloudflare quick tunnel
// (no account needed). Downloads Cloudflare's "cloudflared" program the first time, runs
//   cloudflared tunnel --url http://127.0.0.1:<port>
// and reads the random https://<words>.trycloudflare.com address it prints. Friends join with
// the same address as wss://... . Cloudflare says these account-less tunnels have no uptime
// guarantee; the address changes every time the tunnel starts.
"use strict";

const { spawn, execFile } = require("child_process");
const fs = require("fs");
const path = require("path");

const RELEASES = "https://github.com/cloudflare/cloudflared/releases/latest/download/";

function assetName() {
  if (process.platform === "darwin") return process.arch === "arm64" ? "cloudflared-darwin-arm64.tgz" : "cloudflared-darwin-amd64.tgz";
  if (process.platform === "win32") return "cloudflared-windows-amd64.exe";   // also runs on Windows on ARM
  return process.arch === "arm64" ? "cloudflared-linux-arm64" : "cloudflared-linux-amd64";
}

function createTunnel({ dir: dirOption, fetch, port }) {
  // dir may be a function, so the app's data folder is looked up only when it's needed.
  const dirOf = () => (typeof dirOption === "function" ? dirOption() : dirOption);
  const exeOf = () => path.join(dirOf(), process.platform === "win32" ? "cloudflared.exe" : "cloudflared");
  let proc = null, url = null, status = "off", error = null, timer = null;

  async function binary() {
    const dir = dirOf();
    const exe = exeOf();
    for (const p of [exe, "/opt/homebrew/bin/cloudflared", "/usr/local/bin/cloudflared", "/usr/bin/cloudflared"]) {
      if (fs.existsSync(p)) return p;
    }
    fs.mkdirSync(dir, { recursive: true });
    const res = await fetch(RELEASES + assetName());
    if (!res.ok) throw new Error(`download failed (${res.status})`);
    const data = Buffer.from(await res.arrayBuffer());
    if (assetName().endsWith(".tgz")) {
      const tgz = path.join(dir, "cloudflared.tgz");
      fs.writeFileSync(tgz, data);
      await new Promise((resolve, reject) => execFile("tar", ["-xzf", tgz, "-C", dir], (e) => (e ? reject(e) : resolve())));
      fs.unlinkSync(tgz);
    } else {
      fs.writeFileSync(exe, data);
    }
    fs.chmodSync(exe, 0o755);
    return exe;
  }

  function fail(message) {
    status = "error";
    error = message;
    url = null;
    if (proc) { const p = proc; proc = null; p.kill(); }
    clearTimeout(timer);
  }

  // Starts in the background; poll info() for the address.
  function start() {
    if (proc || status === "starting") return info();
    status = "starting";
    error = null;
    binary().then((bin) => {
      if (status !== "starting") return;   // stopped while downloading
      proc = spawn(bin, ["tunnel", "--no-autoupdate", "--url", `http://127.0.0.1:${port}`], { windowsHide: true });
      const scan = (chunk) => {
        const m = String(chunk).match(/https:\/\/[a-z0-9-]+\.trycloudflare\.com/);
        if (m && !url) { url = m[0].replace(/^https:/, "wss:"); status = "on"; clearTimeout(timer); }
        if (/provisioning failed|failed to request quick Tunnel/i.test(String(chunk))) fail("Cloudflare couldn't create the connection. Try again in a minute.");
      };
      proc.stdout.on("data", scan);
      proc.stderr.on("data", scan);
      proc.on("error", (e) => fail(`Couldn't start the internet connector: ${e.message}`));
      proc.on("exit", () => { if (status !== "error") { status = "off"; url = null; } proc = null; });
      timer = setTimeout(() => { if (status === "starting") fail("Cloudflare didn't answer. Check your internet connection and try again."); }, 60000);
    }, (e) => fail(`Couldn't download the internet connector: ${e.message}`));
    return info();
  }

  function stop() {
    clearTimeout(timer);
    if (proc) { const p = proc; proc = null; p.kill(); }
    status = "off";
    url = null;
    error = null;
  }

  const info = () => ({ status, url, error });
  return { start, stop, info };
}

module.exports = { createTunnel };
