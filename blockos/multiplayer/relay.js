#!/usr/bin/env node
// BlockOS game server: relays messages between players in the same game room.
//
//   node relay.js [--port 8790]
//
// Every player runs the game on their own computer; this server only passes along
// what each player shares (position, events, quick-chat phrases) to the others in
// the same room. There is no free-text chat: players can only send phrases from a
// fixed list, by number. Names and avatars are cleaned up before they're passed on.
"use strict";

const { WebSocketServer } = require("ws");

const MAX_PER_ROOM = 24;
const MAX_MESSAGE = 4096;        // bytes
const MAX_RATE = 40;             // messages per second per player
const QUICK_CHAT_COUNT = 12;     // Kit.QUICK_CHAT has 12 phrases

const COLOR = /^#[0-9a-f]{6}$/i;
const WORD = /^[a-z0-9-]{1,20}$/i;

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
  let nextId = 1;

  const send = (ws, msg) => { if (ws.readyState === 1) ws.send(JSON.stringify(msg)); };
  const broadcast = (room, msg, except) => {
    const data = JSON.stringify(msg);
    for (const c of room.values()) if (c !== except && c.ws.readyState === 1) c.ws.send(data);
  };

  wss.on("connection", (ws) => {
    let client = null;
    let tokens = MAX_RATE;
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
        if (m.t !== "hello" || !WORD.test(m.game) || (m.room && !/^[a-z0-9-]{1,20}$/i.test(m.room))) return ws.close();
        const key = m.game + ":" + (m.room || "main");
        const room = rooms.get(key) || new Map();
        if (room.size >= MAX_PER_ROOM) {
          send(ws, { t: "err", m: "This server is full." });
          return ws.close();
        }
        client = { id: nextId++, ws, key, name: cleanName(m.name), avatar: cleanAvatar(m.avatar), s: null };
        rooms.set(key, room);
        send(ws, {
          t: "welcome",
          id: client.id,
          players: [...room.values()].map((c) => ({ id: c.id, name: c.name, avatar: c.avatar, s: c.s })),
        });
        broadcast(room, { t: "join", p: { id: client.id, name: client.name, avatar: client.avatar } });
        room.set(client.id, client);
        return;
      }

      const room = rooms.get(client.key);
      if (!room) return;
      if (m.t === "s" && m.s && typeof m.s === "object") {
        client.s = m.s;
        broadcast(room, { t: "s", id: client.id, s: m.s }, client);
      } else if (m.t === "e" && m.e !== undefined) {
        broadcast(room, { t: "e", id: client.id, e: m.e }, client);
      } else if (m.t === "c" && Number.isInteger(m.i) && m.i >= 0 && m.i < QUICK_CHAT_COUNT) {
        broadcast(room, { t: "c", id: client.id, i: m.i }, client);
      }
    });

    ws.on("close", () => {
      if (!client) return;
      const room = rooms.get(client.key);
      if (!room) return;
      room.delete(client.id);
      if (room.size === 0) rooms.delete(client.key);
      else broadcast(room, { t: "leave", id: client.id });
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
