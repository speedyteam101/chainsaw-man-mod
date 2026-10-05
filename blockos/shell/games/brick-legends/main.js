/* Brick Legends: title screen, ending, main loop and test hooks. */
"use strict";

buildMaps();
defineStory();

// ------------------------------------------------------------------ title
let titleMenu = null;
function openTitle() {
  G.scene = "title";
  G.s = null;
  Kit.hud("");
  Music.play("title");
  const save = loadSave();
  const items = [];
  if (save) items.push({ label: "Continue", id: "continue", right: `Lv ${save.party[0].level}  ${fmtTime(save.playTime || 0)}` });
  items.push({ label: "New Game", id: "new" }, { label: "How to Play", id: "help" });
  titleMenu = makeList({
    x: VW / 2 - 170, y: 360, w: 340, rowH: 36, size: 19, items,
    onPick: async (it) => {
      if (it.id === "continue") { closeUI(titleMenu); continueGame(); }
      else if (it.id === "new") { closeUI(titleMenu); newGame(); }
      else {
        await notice("Arrows / WASD: move and choose.   Enter / Space / Z: talk, confirm.   X / Backspace: cancel.");
        await notice("Q (or X while walking): menu with status, items, equipment, quests and saving.   M: world map.   N: music on or off.");
        await notice("Walk outside towns to meet monsters. Find elemental weaknesses (fire, ice, thunder), rest at inns (it saves too) and recover the three crystals!");
      }
    },
  });
  pushUI(titleMenu);
}
function drawTitle(ctx) {
  const T = G.T;
  const g = ctx.createLinearGradient(0, 0, 0, VH);
  g.addColorStop(0, "#1e1b4b"); g.addColorStop(0.55, "#7c3aed"); g.addColorStop(1, "#f472b6");
  ctx.fillStyle = g; ctx.fillRect(0, 0, VW, VH);
  ctx.fillStyle = "rgba(255,255,255,.8)";
  for (let i = 0; i < 50; i++) ctx.fillRect((i * 173) % VW, (i * 97) % 260, 2, 2);
  // castle silhouette
  ctx.fillStyle = "#1a1033";
  ctx.fillRect(620, 170, 220, 160); ctx.fillRect(600, 130, 50, 200); ctx.fillRect(810, 130, 50, 200); ctx.fillRect(700, 100, 60, 230);
  for (let k = 0; k < 4; k++) { ctx.fillRect(600 + k * 14, 118, 8, 14); ctx.fillRect(810 + k * 14, 118, 8, 14); ctx.fillRect(700 + k * 16, 88, 9, 14); }
  ctx.fillStyle = `rgba(192,132,252,${0.6 + 0.3 * Math.sin(T * 2)})`; ctx.fillRect(722, 150, 16, 22);
  // hills
  for (let i = 0; i < 7; i++) Kit.brick(ctx, i * 160 - 40, 300 - (i % 2) * 26, 220, 120, i % 2 ? "#3f8f3c" : "#4a9a44", 30);
  ctx.fillStyle = "#5bb450"; ctx.fillRect(0, 380, VW, VH - 380);
  ctx.fillStyle = "rgba(255,255,255,.08)";
  for (let x = -((T * 60) % 48); x < VW; x += 48) for (let y = 400; y < VH; y += 40) { ctx.beginPath(); ctx.arc(x + (y % 80 ? 24 : 0), y, 7, 0, Math.PI * 2); ctx.fill(); }
  // party marching
  const ph = T * 9;
  drawWalker(ctx, CLASSES.mira.look, 150, 352, "right", ph + 2, 66);
  drawWalker(ctx, CLASSES.nova.look, 230, 352, "right", ph + 1, 66);
  drawWalker(ctx, G.heroLook, 315, 352, "right", ph, 70);
  drawMonster(ctx, "slime", ENEMIES.slime.col, 820, 352, 6, T);
  drawMonster(ctx, "bat", ENEMIES.bat.col, 700, 330, 5, T * 1.1);
  // logo
  const lx = VW / 2, ly = 120;
  ctx.save();
  ctx.translate(lx, ly + Math.sin(T * 1.5) * 4);
  const word = (s, y, size, cols) => {
    ctx.font = `900 ${size}px ${FONT}`;
    const w = ctx.measureText(s).width;
    let x = -w / 2;
    for (let i = 0; i < s.length; i++) {
      const ch = s[i];
      const cw = ctx.measureText(ch).width;
      if (ch !== " ") {
        ctx.fillStyle = "rgba(0,0,0,.45)"; ctx.textAlign = "left"; ctx.fillText(ch, x + 4, y + 6);
        ctx.fillStyle = cols[i % cols.length]; ctx.fillText(ch, x, y);
      }
      x += cw;
    }
  };
  word("BRICK", -10, 74, ["#ef4444", "#facc15", "#3b82f6", "#22c55e", "#fb923c"]);
  word("LEGENDS", 62, 60, ["#fde68a"]);
  ctx.restore();
  txt(ctx, "A blocky quest for the three crystals", VW / 2, 222, { size: 17, align: "center", color: "#e9d5ff" });
  txt(ctx, `Hero: ${G.heroName}`, VW / 2, 340, { size: 15, align: "center", color: "#fde68a" });
}

async function newGame() {
  refreshPlayer();
  G.s = newState();
  placeParty(G.s.x, G.s.y, G.s.dir);
  G.scene = "field";
  G.lastRegion = null;
  Music.play("town");
  G.fade = 1;
  updateHud();
  G.busy = true;
  await fadeIn(600);
  G.banner = { text: "Brickhaven", t: 0 };
  await introScene();
  updateHud();
}
async function continueGame() {
  refreshPlayer();
  const s = loadSave();
  if (!s) return openTitle();
  G.s = s;
  placeParty(s.x, s.y, s.dir);
  G.scene = "field";
  const m = curMap();
  G.lastRegion = m.id === "world" ? regionAt(m, s.x, s.y) : null;
  Music.play(fieldMusic());
  G.fade = 1;
  updateHud();
  await fadeIn(500);
  G.banner = { text: m.id === "world" ? REGION_NAME[G.lastRegion] : m.name, t: 0 };
}

// ------------------------------------------------------------------ ending
async function endingScene() {
  G.busy = true;
  F().cleared = true;
  badge("final");
  Kit.finish(ID, hero().level);
  await fadeOut(800);
  G.scene = "ending";
  G.endT = 0;
  Music.play("ending");
  await fadeIn(800);
  await wait(1500);
  await waitConfirm();
  await fadeOut(600);
  G.s.map = "brickhaven";
  placeParty(25, 7, "up");
  healAll();
  G.scene = "field";
  Music.play("town");
  saveGame();
  await fadeIn(600);
  await say("Elder Mortar", "{hero}! You've returned! The crystals shine again and color is back in every brick of Blockara.");
  await say("Elder Mortar", "Your legend will be told for generations. Rest well... and feel free to keep exploring!");
  G.busy = false;
  updateHud();
}
const CREDITS = [
  "The Hollow King crumbles into a heap of grey bricks.",
  "The three crystals blaze with light,",
  "and color floods back into every corner of Blockara.",
  "",
  "BRICK LEGENDS",
  "",
  "Starring",
  "",
  "Nova the Mage",
  "Mira the Healer",
  "",
  "With",
  "Elder Mortar, Farmer Bo, Herbalist Lin, Grandpa Flint",
  "Chief Dune, Guard Sid, Chief Glacia, Flurry",
  "and every slime who fell along the way",
  "",
  "THE END",
  "",
  "Thanks for playing!",
];
function drawEnding(ctx) {
  const T = G.T;
  const g = ctx.createLinearGradient(0, 0, 0, VH);
  g.addColorStop(0, "#0c4a6e"); g.addColorStop(1, "#fde68a");
  ctx.fillStyle = g; ctx.fillRect(0, 0, VW, VH);
  for (let i = 0; i < 3; i++) {
    const c = ["#4ade80", "#facc15", "#7dd3fc"][i];
    const x = 330 + i * 150, y = 70 + Math.sin(T * 2 + i) * 6;
    ctx.fillStyle = c + "55"; ctx.beginPath(); ctx.arc(x, y, 30, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = c; ctx.beginPath(); ctx.moveTo(x, y - 22); ctx.lineTo(x + 14, y); ctx.lineTo(x, y + 22); ctx.lineTo(x - 14, y); ctx.fill();
  }
  ctx.fillStyle = "#5bb450"; ctx.fillRect(0, 480, VW, VH - 480);
  ctx.fillStyle = "rgba(255,255,255,.08)";
  for (let x = 24; x < VW; x += 48) { ctx.beginPath(); ctx.arc(x, 520, 7, 0, Math.PI * 2); ctx.fill(); }
  G.s.party.forEach((m, i) => drawWalker(ctx, memberLook(m), VW / 2 + (i - (G.s.party.length - 1) / 2) * 110, 556, "down", 0, 74));
  const target = CREDITS.indexOf("THE END");
  const scroll = Math.min(G.endT * 40, 470 + target * 34 - 290);
  const top = 470 - scroll;
  CREDITS.forEach((l, i) => {
    const y = top + i * 34;
    const a = Math.min(1, (y - 120) / 50, (470 - y) / 40);
    if (a <= 0) return;
    ctx.globalAlpha = a;
    const size = l === "BRICK LEGENDS" || l === "THE END" ? 30 : 19;
    txt(ctx, l === "Starring" ? "Starring " + G.heroName : l, VW / 2, y, { size, align: "center", color: size > 20 ? "#fde68a" : "#fff" });
    ctx.globalAlpha = 1;
  });
  if (G.endT * 40 >= 470 + target * 34 - 290) downArrow(ctx, VW / 2, 450, T);
}
function drawGameOver(ctx) {
  ctx.fillStyle = "#0b0812"; ctx.fillRect(0, 0, VW, VH);
  txt(ctx, "Defeated...", VW / 2, VH / 2 - 20, { size: 46, align: "center", color: "#f87171" });
  txt(ctx, "You will wake up at the last inn you rested at, with half your gold.", VW / 2, VH / 2 + 30, { size: 17, align: "center", color: "#cbd5e1" });
  downArrow(ctx, VW / 2, VH / 2 + 80, G.T);
}

// ------------------------------------------------------------------ loop
function drawTransition(ctx) {
  if (!G.trans) return;
  const p = G.trans;
  for (let y = 0; y < VH / 48; y++) for (let x = 0; x < VW / 48; x++) {
    const d = Math.hypot(x - VW / 96, y - VH / 96) / 12;
    const k = Kit.clamp(p * 2 - (1 - d), 0, 1);
    if (k <= 0) continue;
    const s = 48 * k;
    Kit.brick(ctx, x * 48 + (48 - s) / 2, y * 48 + (48 - s) / 2, s, s, "#0b0812", 4);
  }
}
function update(dt) {
  G.T += dt;
  updateAnims(dt);
  if (G.s && (G.scene === "field" || G.scene === "battle")) G.s.playTime += dt;
  if (G.scene === "field") fieldUpdate(dt);
  if (G.scene === "battle") updateBattle(dt);
  if (G.scene === "ending") G.endT = (G.endT || 0) + dt;
  if (G.toast) { G.toast.t += dt; if (G.toast.t > 2.6) G.toast = null; }
}
function draw() {
  G.hits = [];
  drawOwner = G.scene;
  if (G.scene === "title") drawTitle(ctx);
  else if (G.scene === "field") drawField(ctx);
  else if (G.scene === "battle" && B) drawBattle(ctx);
  else if (G.scene === "gameover") drawGameOver(ctx);
  else if (G.scene === "ending") drawEnding(ctx);
  drawOwner = null;
  drawTransition(ctx);
  drawUI(ctx);
  drawCard(ctx);
  if (G.toast) {
    ctx.globalAlpha = Math.min(1, (2.6 - G.toast.t) * 3);
    ctx.font = `bold 16px ${FONT}`;
    const w = ctx.measureText(G.toast.text).width + 40;
    panel(ctx, VW / 2 - w / 2, VH - 230, w, 42, { top: "#14532d", bottom: "#052e16", border: "#86efac" });
    txt(ctx, G.toast.text, VW / 2, VH - 203, { size: 16, align: "center" });
    ctx.globalAlpha = 1;
  }
  if (G.fade > 0) { ctx.fillStyle = `rgba(0,0,0,${G.fade})`; ctx.fillRect(0, 0, VW, VH); }
}
const loop = Kit.loop(update, draw);
loop.start();
openTitle();

// ------------------------------------------------------------------ test hooks
window.game = G;
G.debug = {
  newGame, continueGame, saveGame, loadSave,
  state: () => ({ scene: G.scene, map: G.s && G.s.map, x: G.p && G.p.x, y: G.p && G.p.y, ui: G.ui.length, busy: G.busy, gold: G.s && G.s.gold, party: G.s && G.s.party.map((m) => [m.id, m.level, m.hp, m.mp]) }),
  warp(map, x, y, dir) { G.s.map = map; placeParty(x, y, dir || "down"); G.lastRegion = null; Music.play(fieldMusic()); updateHud(); },
  give(id, n) { if (EQUIP[id]) addGear(id, n || 1); else addItem(id, n || 1); },
  gold(n) { G.s.gold += n; updateHud(); },
  level(n) { for (const m of G.s.party) { m.level = n; m.xp = 0; } healAll(); updateHud(); },
  join(id) { joinParty(id); F()[id] = true; },
  flags(o) { Object.assign(G.s.flags, o); },
  heal: healAll,
  battle(group, o) { return battleFlow(group, o || {}); },
  weaken(hp) { if (B) B.enemies.forEach((e) => { e.hp = Math.min(e.hp, hp || 1); }); },
  noEnc(v) { G.noEncounters = v !== false; },
  closeUI() { G.ui.length = 0; },
};
