#!/usr/bin/env node
// BlockOS game server: relays messages between players in the same game room,
// and lets friends see each other and send friend requests.
//
//   node relay.js [--port 8790]
//
// Every player runs the game on their own computer; this server only passes along
// what each player shares (position, events, chat) to the others in the same room.
// Typed chat ("say") and private messages between friends ("dm") go through a filter
// (chatfilter.js) that hides swear words and personal details such as phone numbers,
// email addresses and links. Names and avatars are cleaned up before they're passed on.
//
// Servers: like Roblox, each game has numbered servers ("s1", "s2", ...). A game's room names end
// in the server, e.g. "main-s2" or "mossy-crypt-s2", and all rooms of one server share its player
// limit (MAX_PER_SERVER). "list" returns how many people are on each server of a game, and
// "stats" how many are playing each game, for the server list and the "playing" counts.
//
// Friends: each BlockOS install has a random friend code (8 letters/digits). A client
// can ask which of a list of codes are online and what they're playing ("who"), and
// send a friend request / accept / decline to a code ("fr"). The BlockOS desktop keeps
// one connection in the "lobby" game for this while you're online.
//
// Community games: players can publish games they made in the Create studio to this server
// (see community.js). New games wait for a moderator to approve them. A moderator is anyone who
// knows the server's moderator key: --mod-key / BLOCKOS_MOD_KEY, or else a random key saved in
// <data folder>/moderator-key.txt the first time the server starts. Games are kept in the data
// folder: --data DIR / BLOCKOS_DATA (default: a "data" folder next to this file).
"use strict";

const fs = require("fs");
const path = require("path");
const http = require("http");
const crypto = require("crypto");
const { WebSocketServer } = require("ws");
const { filterText } = require("./chatfilter.js");
const { createCommunity } = require("./community.js");

const MAX_PER_SERVER = 12;      // players on one server of one game
const MAX_MESSAGE = 4096;        // bytes
const MAX_UPLOAD = 1024 * 1024;  // bytes, for publishing a community game
const MAX_RATE = 40;             // messages per second per player
const QUICK_CHAT_COUNT = 64;     // indexes into Kit.QUICK_CHAT
const MAX_WHO = 200;             // friend codes per "who" question
const CHAT_GAP = 700;            // ms between typed messages from one player

const COLOR = /^#[0-9a-f]{6}$/i;
const WORD = /^[a-z0-9-]{1,20}$/i;
const CODE = /^[A-HJ-NP-Z2-9]{8}$/;   // friend code: no 0/O or 1/I to mix up

function cleanName(name) {
  const n = String(name || "").replace(/[^A-Za-z0-9 _.-]/g, "").trim().slice(0, 20);
  return n || "Player";
}

function cleanAvatar(a) {
  const out = {};
  if (!a || typeof a !== "object") return out;
  for (const k of ["head", "torso", "arms", "legs"]) if (COLOR.test(a[k])) out[k] = a[k];
  for (const k of ["face", "hat", "shirt"]) if (WORD.test(a[k])) out[k] = a[k];
  return out;
}

// "main-s2" -> "s2"; rooms without a server suffix count as server "s1".
const serverOf = (room) => (room.match(/-(s\d{1,3})$/) || [])[1] || "s1";

// The moderator key: given, or read from (or else created in) the data folder.
function moderatorKey(given, dataDir) {
  if (given) return String(given);
  if (!dataDir) return null;
  const file = path.join(dataDir, "moderator-key.txt");
  try { return fs.readFileSync(file, "utf8").trim(); } catch (_) {}
  const key = crypto.randomBytes(12).toString("hex");
  fs.mkdirSync(dataDir, { recursive: true });
  fs.writeFileSync(file, key + "\n", { mode: 0o600 });
  return key;
}
const sameKey = (a, b) => {
  const x = Buffer.from(String(a || "")), y = Buffer.from(String(b || ""));
  return x.length === y.length && x.length > 0 && crypto.timingSafeEqual(x, y);
};

// opts: { dataDir, modKey, autoApprove } (all optional; without a dataDir community games
// are only kept until the server stops).
function start(port, host, opts) {
  const o = opts || {};
  const modKey = moderatorKey(o.modKey, o.dataDir);
  const community = createCommunity({ dataDir: o.dataDir, autoApprove: o.autoApprove });
  // Plain web requests get a short answer, so hosting services' health checks see the server is up.
  const web = http.createServer((req, res) => {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("BlockOS game server\n");
  });
  const wss = new WebSocketServer({ server: web, maxPayload: MAX_UPLOAD });
  web.listen(port, host || "0.0.0.0");
  const rooms = new Map();   // "game:room" -> Map(id -> client)
  const byCode = new Map();  // friend code -> Set of clients
  let nextId = 1;

  const send = (ws, msg) => { if (ws.readyState === 1) ws.send(JSON.stringify(msg)); };
  const broadcast = (room, msg, except) => {
    const data = JSON.stringify(msg);
    for (const c of room.values()) if (c !== except && c.ws.readyState === 1) c.ws.send(data);
  };
  // Players on one server of one game, across all its rooms.
  function serverCount(game, server) {
    let n = 0;
    for (const [key, members] of rooms) {
      const [g, room] = key.split(":");
      if (g === game && serverOf(room) === server) n += members.size;
    }
    return n;
  }
  function serverList(game) {
    const counts = {};
    for (const [key, members] of rooms) {
      const [g, room] = key.split(":");
      if (g !== game || members.size === 0) continue;
      const s = serverOf(room);
      counts[s] = (counts[s] || 0) + members.size;
    }
    return counts;
  }
  function gameStats() {
    const counts = {};
    for (const [key, members] of rooms) {
      const g = key.split(":")[0];
      if (g !== "lobby" && members.size) counts[g] = (counts[g] || 0) + members.size;
    }
    return counts;
  }
  // Tell moderators (or everyone on the desktop) that the community games changed.
  function communityChanged(modsOnly) {
    for (const c of wss.clients) if (c.client && (c.client.mod || (!modsOnly && c.client.game === "lobby"))) send(c, { t: "cchanged" });
  }
  const info = (c) => ({ id: c.id, name: c.name, avatar: c.avatar, uid: c.uid, s: c.s });

  // What a friend code is doing right now: the game they're in, or "lobby" if they're
  // only on the BlockOS desktop.
  function presence(code) {
    const set = byCode.get(code);
    if (!set || set.size === 0) return null;
    let best = null;
    for (const c of set) if (!best || (best.game === "lobby" && c.game !== "lobby")) best = c;
    return { game: best.game, room: best.room, server: serverOf(best.room), name: best.name, avatar: best.avatar };
  }

  wss.on("connection", (ws) => {
    let client = null;
    let tokens = MAX_RATE;
    let lastChat = 0;
    let last = Date.now();

    ws.on("message", (raw) => {
      // Simple rate limit: a bucket that refills MAX_RATE tokens per second.
      const now = Date.now();
      tokens = Math.min(MAX_RATE, tokens + ((now - last) / 1000) * MAX_RATE);
      last = now;
      if (tokens < 1) return;
      tokens -= 1;

      let m;
      try { m = JSON.parse(raw); } catch (_) { return; }
      if (!m || typeof m !== "object") return;
      if (raw.length > MAX_MESSAGE && !(client && m.t === "cpub")) return;   // only uploads may be big

      if (!client) {
        if (m.t !== "hello" || !WORD.test(m.game) || (m.room && !WORD.test(m.room))) return ws.close();
        const room = m.room || "main";
        const key = m.game + ":" + room;
        const members = rooms.get(key) || new Map();
        if (m.game !== "lobby" && serverCount(m.game, serverOf(room)) >= MAX_PER_SERVER) {
          send(ws, { t: "err", m: "This server is full." });
          return ws.close();
        }
        client = {
          id: nextId++, ws, key, game: m.game, room,
          name: cleanName(m.name), avatar: cleanAvatar(m.avatar),
          uid: CODE.test(m.uid) ? m.uid : null, s: null,
        };
        if (client.uid) {
          if (!byCode.has(client.uid)) byCode.set(client.uid, new Set());
          byCode.get(client.uid).add(client);
        }
        ws.client = client;
        rooms.set(key, members);
        if (m.game === "lobby") {
          // The desktop's friends connection: nobody else in the lobby needs to know about it.
          send(ws, { t: "welcome", id: client.id, players: [] });
        } else {
          send(ws, { t: "welcome", id: client.id, players: [...members.values()].map(info) });
          broadcast(members, { t: "join", p: info(client) });
        }
        members.set(client.id, client);
        return;
      }

      // Community games.
      if (m.t === "admin") {
        client.mod = !!modKey && sameKey(m.key, modKey);
        return send(ws, { t: "admin", ok: client.mod });
      }
      if (m.t === "clist") return send(ws, Object.assign({ t: "clist", mod: !!client.mod, max: community.MAX_CODE }, community.list(client.uid, client.mod)));
      if (m.t === "cpub") {
        const r = community.publish(client, m);
        send(ws, Object.assign({ t: "cpub" }, r));
        if (r.ok) communityChanged(r.status !== "approved");
        return;
      }
      if (m.t === "cget" && typeof m.id === "string") return send(ws, Object.assign({ t: "cget", id: m.id }, community.get(client, m.id, client.mod)));
      if (m.t === "clike" && typeof m.id === "string") return send(ws, { t: "clike", game: community.like(client, m.id) });
      if (m.t === "creport" && typeof m.id === "string") {
        const ok = community.report(client, m.id, m.reason);
        send(ws, { t: "creport", ok });
        if (ok) communityChanged(true);
        return;
      }
      if (m.t === "cmod" && typeof m.id === "string") {
        const ok = community.moderate(client, m.id, m.action, client.mod);
        send(ws, { t: "cmod", ok, id: m.id, action: m.action });
        if (ok) communityChanged(false);
        return;
      }

      if (m.t === "list" && WORD.test(m.game)) return send(ws, { t: "list", game: m.game, servers: serverList(m.game), max: MAX_PER_SERVER });
      if (m.t === "stats") return send(ws, { t: "stats", games: gameStats() });
      if (m.t === "who" && Array.isArray(m.ids)) {
        const s = {};
        for (const code of m.ids.slice(0, MAX_WHO)) if (CODE.test(code)) s[code] = presence(code);
        return send(ws, { t: "who", s });
      }
      if (m.t === "fr" && CODE.test(m.to) && ["request", "accept", "decline", "remove"].includes(m.kind)) {
        if (!client.uid || m.to === client.uid) return;
        const targets = byCode.get(m.to);
        if (!targets || targets.size === 0) return send(ws, { t: "fr-offline", to: m.to, kind: m.kind });
        for (const c of targets) send(c.ws, { t: "fr", from: client.uid, name: client.name, avatar: client.avatar, kind: m.kind });
        return;
      }

      if ((m.t === "say" || m.t === "dm") && typeof m.text === "string") {
        if (now - lastChat < CHAT_GAP) return send(ws, { t: "slow" });
        lastChat = now;
        const text = filterText(m.text);
        if (!text) return;
        if (m.t === "dm") {
          if (!client.uid || !CODE.test(m.to) || m.to === client.uid) return;
          const targets = byCode.get(m.to);
          if (!targets || targets.size === 0) return send(ws, { t: "dm-offline", to: m.to });
          for (const c of targets) send(c.ws, { t: "dm", from: client.uid, name: client.name, avatar: client.avatar, text });
          return send(ws, { t: "dm-sent", to: m.to, text });   // the filtered version, for the sender's history
        }
        if (client.game === "lobby") return;
        const members = rooms.get(client.key);
        if (members) broadcast(members, { t: "say", id: client.id, text });
        return;
      }

      if (client.game === "lobby") return;
      const members = rooms.get(client.key);
      if (!members) return;
      if (m.t === "s" && m.s && typeof m.s === "object") {
        client.s = m.s;
        broadcast(members, { t: "s", id: client.id, s: m.s }, client);
      } else if (m.t === "e" && m.e !== undefined) {
        broadcast(members, { t: "e", id: client.id, e: m.e }, client);
      } else if (m.t === "c" && Number.isInteger(m.i) && m.i >= 0 && m.i < QUICK_CHAT_COUNT) {
        broadcast(members, { t: "c", id: client.id, i: m.i }, client);
      }
    });

    ws.on("close", () => {
      if (!client) return;
      if (client.uid && byCode.has(client.uid)) {
        byCode.get(client.uid).delete(client);
        if (byCode.get(client.uid).size === 0) byCode.delete(client.uid);
      }
      const members = rooms.get(client.key);
      if (!members) return;
      members.delete(client.id);
      if (members.size === 0) rooms.delete(client.key);
      else if (client.game !== "lobby") broadcast(members, { t: "leave", id: client.id });
    });
    ws.on("error", () => {});
  });

  return {
    close: () => new Promise((resolve) => { community.flush(); for (const c of wss.clients) c.terminate(); wss.close(() => web.close(() => resolve())); }),
    modKey,
    players: () => [...rooms.values()].reduce((n, r) => n + r.size, 0),
    ready: new Promise((resolve, reject) => { web.once("listening", resolve); web.once("error", reject); }),
  };
}

module.exports = { start };

if (require.main === module) {
  const arg = (name) => { const i = process.argv.indexOf(name); return i > 0 ? process.argv[i + 1] : undefined; };
  const port = Number(arg("--port") || process.env.PORT || 8790);
  const dataDir = path.resolve(arg("--data") || process.env.BLOCKOS_DATA || path.join(__dirname, "data"));
  const server = start(port, undefined, {
    dataDir,
    modKey: arg("--mod-key") || process.env.BLOCKOS_MOD_KEY,
    autoApprove: process.argv.includes("--auto-approve") || process.env.BLOCKOS_AUTO_APPROVE === "1",
  });
  const stop = () => server.close().then(() => process.exit(0));
  process.on("SIGTERM", stop);
  process.on("SIGINT", stop);
  server.ready.then(
    () => {
      console.log(`BlockOS game server listening on port ${port}`);
      console.log(`Community games are saved in ${dataDir}`);
      if (!arg("--mod-key") && !process.env.BLOCKOS_MOD_KEY) console.log(`Moderator key (type it in BlockOS > Community > "Server owner?" to approve games): see ${path.join(dataDir, "moderator-key.txt")}`);
    },
    (e) => { console.error(`Couldn't start the game server: ${e.message}`); process.exit(1); },
  );
}
