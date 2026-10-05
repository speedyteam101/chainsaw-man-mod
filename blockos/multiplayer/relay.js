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
// Friends: each BlockOS install has a random friend code (8 letters/digits). A client
// can ask which of a list of codes are online and what they're playing ("who"), and
// send a friend request / accept / decline to a code ("fr"). The BlockOS desktop keeps
// one connection in the "lobby" game for this while you're online.
"use strict";

const { WebSocketServer } = require("ws");
const { filterText } = require("./chatfilter.js");

const MAX_PER_ROOM = 24;
const MAX_MESSAGE = 4096;        // bytes
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

function start(port, host) {
  const wss = new WebSocketServer({ port, host: host || "0.0.0.0", maxPayload: MAX_MESSAGE });
  const rooms = new Map();   // "game:room" -> Map(id -> client)
  const byCode = new Map();  // friend code -> Set of clients
  let nextId = 1;

  const send = (ws, msg) => { if (ws.readyState === 1) ws.send(JSON.stringify(msg)); };
  const broadcast = (room, msg, except) => {
    const data = JSON.stringify(msg);
    for (const c of room.values()) if (c !== except && c.ws.readyState === 1) c.ws.send(data);
  };
  const info = (c) => ({ id: c.id, name: c.name, avatar: c.avatar, uid: c.uid, s: c.s });

  // What a friend code is doing right now: the game they're in, or "lobby" if they're
  // only on the BlockOS desktop.
  function presence(code) {
    const set = byCode.get(code);
    if (!set || set.size === 0) return null;
    let best = null;
    for (const c of set) if (!best || (best.game === "lobby" && c.game !== "lobby")) best = c;
    return { game: best.game, room: best.room, name: best.name, avatar: best.avatar };
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

      if (!client) {
        if (m.t !== "hello" || !WORD.test(m.game) || (m.room && !WORD.test(m.room))) return ws.close();
        const room = m.room || "main";
        const key = m.game + ":" + room;
        const members = rooms.get(key) || new Map();
        if (m.game !== "lobby" && members.size >= MAX_PER_ROOM) {
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
    close: () => new Promise((resolve) => { for (const c of wss.clients) c.terminate(); wss.close(() => resolve()); }),
    players: () => [...rooms.values()].reduce((n, r) => n + r.size, 0),
    ready: new Promise((resolve, reject) => { wss.once("listening", resolve); wss.once("error", reject); }),
  };
}

module.exports = { start };

if (require.main === module) {
  const i = process.argv.indexOf("--port");
  const port = i > 0 ? Number(process.argv[i + 1]) : Number(process.env.PORT || 8790);
  const server = start(port);
  server.ready.then(
    () => console.log(`BlockOS game server listening on port ${port}`),
    (e) => { console.error(`Couldn't start the game server: ${e.message}`); process.exit(1); },
  );
}
