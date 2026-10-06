// Community games: games players made in BlockOS's Create studio and published to this server.
//
// Each game is one HTML page. It's stored in <dataDir>/games/<id>.html, and its details (title,
// author, status, plays, likes, reports) in <dataDir>/community.json.
//
// New and updated games start as "pending": only their author and the server's moderators see
// them until a moderator approves them. Moderators are people who know the server's moderator key
// (see relay.js); the BlockOS app that hosts a server is a moderator of it automatically.
// A game that several players report is hidden again until a moderator looks at it.
"use strict";

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { filterText } = require("./chatfilter.js");

const MAX_CODE = 300000;          // characters of HTML per game
const MAX_GAMES_PER_PLAYER = 10;
const PUBLISH_GAP = 20000;        // ms between publishes from one player
const HIDE_AFTER_REPORTS = 3;     // different players
const GENRES = ["Action", "Adventure", "Arcade", "Board", "Card", "Obby", "Puzzle", "Racing", "RPG", "Science", "Simulator", "Sports", "Strategy", "Word"];
const REPORT_REASONS = ["rude", "scary", "personal", "broken", "copied", "other"];
const COLOR = /^#[0-9a-f]{6}$/i;
const ID = /^[a-z0-9]{8}$/;

// The chat filter works on up to 120 characters at a time, so longer text is filtered in pieces.
function clean(text, max) {
  const words = String(text || "").replace(/\s+/g, " ").trim().slice(0, max).split(" ");
  const parts = [];
  let cur = "";
  for (const w of words) {
    if (cur && (cur + " " + w).length > 110) { parts.push(cur); cur = w; } else cur = cur ? cur + " " + w : w;
  }
  if (cur) parts.push(cur);
  return parts.map(filterText).filter(Boolean).join(" ");
}

function createCommunity(opts) {
  const o = opts || {};
  const dir = o.dataDir;
  const autoApprove = !!o.autoApprove;
  const gamesDir = dir && path.join(dir, "games");
  const indexFile = dir && path.join(dir, "community.json");
  let games = {};
  const codeCache = new Map();          // id -> html, for games stored without a data folder
  const lastPublish = new Map();        // uid -> time

  if (dir) {
    fs.mkdirSync(gamesDir, { recursive: true });
    try { games = JSON.parse(fs.readFileSync(indexFile, "utf8")).games || {}; } catch (_) { games = {}; }
  }

  let saveTimer = null;
  function save() {
    if (!dir || saveTimer) return;
    saveTimer = setTimeout(() => {
      saveTimer = null;
      const tmp = indexFile + ".tmp";
      try {
        fs.writeFileSync(tmp, JSON.stringify({ games }));
        fs.renameSync(tmp, indexFile);
      } catch (e) { console.error("Couldn't save community games:", e.message); }
    }, 500);
  }
  function flush() {
    if (!saveTimer) return;
    clearTimeout(saveTimer);
    saveTimer = null;
    try { fs.writeFileSync(indexFile, JSON.stringify({ games })); } catch (_) {}
  }

  function readCode(id) {
    if (!dir) return codeCache.get(id) || null;
    try { return fs.readFileSync(path.join(gamesDir, id + ".html"), "utf8"); } catch (_) { return null; }
  }
  function writeCode(id, code) {
    if (!dir) return codeCache.set(id, code);
    fs.writeFileSync(path.join(gamesDir, id + ".html"), code);
  }
  function removeCode(id) {
    if (!dir) return codeCache.delete(id);
    try { fs.unlinkSync(path.join(gamesDir, id + ".html")); } catch (_) {}
  }

  // What players see about a game. Moderators also see reports.
  function meta(g, viewerUid, mod) {
    const m = {
      id: g.id, title: g.title, desc: g.desc, genre: g.genre, color: g.color, author: g.author,
      created: g.created, updated: g.updated, status: g.status, plays: g.plays,
      likes: g.likes.length, liked: !!viewerUid && g.likes.includes(viewerUid),
      mine: !!viewerUid && g.authorUid === viewerUid, size: g.size,
    };
    if (mod) m.reports = g.reports.map((r) => ({ reason: r.reason, time: r.time }));
    return m;
  }

  function list(uid, mod) {
    const all = Object.values(games);
    return {
      games: all.filter((g) => g.status === "approved").map((g) => meta(g, uid)),
      mine: uid ? all.filter((g) => g.authorUid === uid).map((g) => meta(g, uid)) : [],
      review: mod ? all.filter((g) => g.status !== "approved" || g.reports.length).map((g) => meta(g, uid, true)) : undefined,
    };
  }

  // Returns { ok, id, status } or { error }.
  function publish(client, m) {
    if (!client.uid) return { error: "You need a friend code to publish. Restart BlockOS and try again." };
    const now = Date.now();
    if (now - (lastPublish.get(client.uid) || 0) < PUBLISH_GAP) return { error: "Wait a few seconds before publishing again." };
    const code = typeof m.code === "string" ? m.code : "";
    if (!code.trim()) return { error: "Your game has no code yet." };
    if (code.length > MAX_CODE) return { error: `Your game is too big to publish (the limit is ${MAX_CODE.toLocaleString("en")} characters).` };
    const title = clean(m.title, 40);
    if (!title || /^#+$/.test(title.replace(/\s/g, ""))) return { error: "Give your game a title." };
    const desc = clean(m.desc, 300);
    const genre = GENRES.includes(m.genre) ? m.genre : "Arcade";
    const color = COLOR.test(m.color) ? m.color : "#3b82f6";

    let g = ID.test(m.id || "") ? games[m.id] : null;
    if (g && g.authorUid !== client.uid) g = null;   // only the author can update a game
    if (!g) {
      const count = Object.values(games).filter((x) => x.authorUid === client.uid).length;
      if (count >= MAX_GAMES_PER_PLAYER) return { error: `You can publish up to ${MAX_GAMES_PER_PLAYER} games on this server. Delete one in My uploads first.` };
      let id;
      do { id = crypto.randomBytes(6).toString("base64").replace(/[^a-z0-9]/gi, "").toLowerCase().slice(0, 8); } while (id.length < 8 || games[id]);
      g = games[id] = { id, created: now, plays: 0, likes: [], reports: [], authorUid: client.uid };
    }
    Object.assign(g, {
      title, desc, genre, color, author: client.name, updated: now, size: code.length,
      status: autoApprove ? "approved" : "pending",
    });
    g.reports = [];
    writeCode(g.id, code);
    lastPublish.set(client.uid, now);
    save();
    return { ok: true, id: g.id, status: g.status };
  }

  // The code of a game, for playing it: approved games for everyone, others for their author and moderators.
  function get(client, id, mod) {
    const g = games[id];
    if (!g) return { error: "That game isn't on this server any more." };
    const own = client.uid && g.authorUid === client.uid;
    if (g.status !== "approved" && !own && !mod) return { error: "That game is waiting to be checked." };
    const code = readCode(id);
    if (code === null) return { error: "That game's file is missing on the server." };
    if (g.status === "approved" && !own) { g.plays++; save(); }
    return { ok: true, code, game: meta(g, client.uid, mod) };
  }

  function like(client, id) {
    const g = games[id];
    if (!g || !client.uid || g.status !== "approved") return null;
    const i = g.likes.indexOf(client.uid);
    if (i >= 0) g.likes.splice(i, 1); else g.likes.push(client.uid);
    save();
    return meta(g, client.uid);
  }

  function report(client, id, reason) {
    const g = games[id];
    if (!g || !client.uid || g.authorUid === client.uid) return false;
    if (g.reports.some((r) => r.uid === client.uid)) return true;
    g.reports.push({ uid: client.uid, reason: REPORT_REASONS.includes(reason) ? reason : "other", time: Date.now() });
    if (g.status === "approved" && g.reports.length >= HIDE_AFTER_REPORTS) g.status = "hidden";
    save();
    return true;
  }

  // Authors can delete their own games; moderators can approve, hide or delete any game.
  function moderate(client, id, action, mod) {
    const g = games[id];
    if (!g) return false;
    const own = client.uid && g.authorUid === client.uid;
    if (action === "delete" && (own || mod)) {
      delete games[id];
      removeCode(id);
    } else if (mod && action === "approve") {
      g.status = "approved";
      g.reports = [];
    } else if (mod && action === "hide") {
      g.status = "hidden";
    } else return false;
    save();
    return true;
  }

  return { list, publish, get, like, report, moderate, flush, MAX_CODE };
}

module.exports = { createCommunity, GENRES, REPORT_REASONS };
