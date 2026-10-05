/* Brick Legends: character, monster and UI drawing. */
"use strict";

// ------------------------------------------------------------------ text & panels
function txt(ctx, s, x, y, o) {
  o = o || {};
  ctx.font = `${o.bold === false ? "" : "bold "}${o.size || 16}px ${FONT}`;
  ctx.textAlign = o.align || "left";
  ctx.textBaseline = o.base || "alphabetic";
  if (o.shadow !== false) {
    ctx.fillStyle = "rgba(0,0,0,.55)";
    ctx.fillText(s, x + 1, y + 2);
  }
  ctx.fillStyle = o.color || "#f8fafc";
  ctx.fillText(s, x, y);
}
function wrapText(ctx, s, w, size) {
  ctx.font = `bold ${size || 16}px ${FONT}`;
  const out = [];
  for (const para of String(s).split("\n")) {
    let line = "";
    for (const word of para.split(" ")) {
      const t = line ? line + " " + word : word;
      if (ctx.measureText(t).width > w && line) { out.push(line); line = word; } else line = t;
    }
    out.push(line);
  }
  return out;
}
function panel(ctx, x, y, w, h, o) {
  o = o || {};
  ctx.fillStyle = "rgba(0,0,0,.35)";
  ctx.beginPath(); ctx.roundRect(x + 3, y + 5, w, h, 10); ctx.fill();
  const g = ctx.createLinearGradient(0, y, 0, y + h);
  g.addColorStop(0, o.top || "#1e3a8a");
  g.addColorStop(1, o.bottom || "#172554");
  ctx.fillStyle = g;
  ctx.beginPath(); ctx.roundRect(x, y, w, h, 10); ctx.fill();
  ctx.strokeStyle = o.border || "#e2e8f0";
  ctx.lineWidth = 3;
  ctx.beginPath(); ctx.roundRect(x + 1.5, y + 1.5, w - 3, h - 3, 9); ctx.stroke();
  ctx.strokeStyle = "rgba(255,255,255,.12)";
  ctx.lineWidth = 1;
  ctx.beginPath(); ctx.roundRect(x + 5.5, y + 5.5, w - 11, h - 11, 6); ctx.stroke();
}
function bar(ctx, x, y, w, h, v, max, col) {
  ctx.fillStyle = "rgba(0,0,0,.5)";
  ctx.fillRect(x, y, w, h);
  const f = max > 0 ? Math.max(0, Math.min(1, v / max)) : 0;
  ctx.fillStyle = col;
  ctx.fillRect(x + 1, y + 1, (w - 2) * f, h - 2);
  ctx.fillStyle = "rgba(255,255,255,.25)";
  ctx.fillRect(x + 1, y + 1, (w - 2) * f, Math.max(1, (h - 2) / 3));
}
function hpColor(hp, max) { const f = hp / max; return f > 0.5 ? "#22c55e" : f > 0.25 ? "#facc15" : "#ef4444"; }
function cursor(ctx, x, y, T) {
  const o = Math.sin((T || 0) * 8) * 2;
  ctx.fillStyle = "#facc15";
  ctx.beginPath(); ctx.moveTo(x + o, y - 7); ctx.lineTo(x + 10 + o, y); ctx.lineTo(x + o, y + 7); ctx.fill();
  ctx.strokeStyle = "#78350f"; ctx.lineWidth = 1.5; ctx.stroke();
}
function downArrow(ctx, x, y, T, col) {
  const o = Math.sin((T || 0) * 8) * 3;
  ctx.fillStyle = col || "#facc15";
  ctx.beginPath(); ctx.moveTo(x - 9, y - 12 + o); ctx.lineTo(x + 9, y - 12 + o); ctx.lineTo(x, y + o); ctx.fill();
  ctx.strokeStyle = "#78350f"; ctx.lineWidth = 2; ctx.stroke();
}
// Element icons: fire = flame, ice = crystal, thunder = bolt.
function elIcon(ctx, el, x, y, s, dim) {
  s = s || 8;
  ctx.save();
  ctx.globalAlpha = dim ? 0.35 : 1;
  ctx.fillStyle = EL_COLOR[el] || "#ccc";
  ctx.strokeStyle = "rgba(0,0,0,.6)";
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  if (el === "fire") {
    ctx.moveTo(x, y - s); ctx.quadraticCurveTo(x + s, y - s * 0.1, x + s * 0.6, y + s * 0.8);
    ctx.lineTo(x - s * 0.6, y + s * 0.8); ctx.quadraticCurveTo(x - s, y, x, y - s);
  } else if (el === "ice") {
    ctx.moveTo(x, y - s); ctx.lineTo(x + s * 0.7, y); ctx.lineTo(x, y + s); ctx.lineTo(x - s * 0.7, y); ctx.closePath();
  } else {
    ctx.moveTo(x + s * 0.3, y - s); ctx.lineTo(x - s * 0.6, y + s * 0.15); ctx.lineTo(x, y + s * 0.15);
    ctx.lineTo(x - s * 0.3, y + s); ctx.lineTo(x + s * 0.6, y - s * 0.15); ctx.lineTo(x, y - s * 0.15); ctx.closePath();
  }
  ctx.fill(); ctx.stroke();
  ctx.restore();
}
function statusIcon(ctx, st, x, y) {
  const col = { poison: "#a855f7", sleep: "#60a5fa", shield: "#38bdf8", defend: "#94a3b8" }[st];
  const label = { poison: "PSN", sleep: "SLP", shield: "SHD", defend: "DEF" }[st];
  ctx.fillStyle = col;
  ctx.beginPath(); ctx.roundRect(x, y, 34, 15, 4); ctx.fill();
  txt(ctx, label, x + 17, y + 12, { size: 11, align: "center", shadow: false, color: "#0b1020" });
}

// ------------------------------------------------------------------ characters
// Looks are Kit avatar looks; companions add hair / hairLong.
function hairSide(ctx, x, y, h, look, dir) {
  if (!look.hair) return;
  const u = h / 5.2;
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(dir, 1);
  ctx.fillStyle = look.hair;
  if (look.hat !== "wizard") ctx.fillRect(-u * 0.66, -5.36 * u, u * 1.3, u * 0.34);
  ctx.fillRect(-u * 0.68, -5.3 * u, u * 0.5, look.hairLong ? u * 2.0 : u * 1.0);
  ctx.restore();
}
// Front (down) or back (up) view in the same 6-part style as Kit.drawAvatar.
function drawFrontBack(ctx, x, y, h, a, back, phase) {
  const u = h / 5.2;
  const sw = Math.sin(phase || 0);
  const R = (px, py, w, hh, c) => { ctx.fillStyle = c; ctx.fillRect(x + px * u, y + py * u, w * u, hh * u); };
  const lift = (v) => Math.max(0, v) * 0.35;
  // legs
  R(-0.62, -2 - 0, 0.6, 2 - lift(sw), a.legs);
  R(0.02, -2, 0.6, 2 - lift(-sw), a.legs);
  R(-0.62, -0.25 - lift(sw), 0.6, 0.25, shadeHex(a.legs, -0.15));
  R(0.02, -0.25 - lift(-sw), 0.6, 0.25, shadeHex(a.legs, -0.15));
  // arms
  R(-1.08, -3.95 + sw * 0.12, 0.44, 1.85, back ? shadeHex(a.arms, -0.08) : a.arms);
  R(0.64, -3.95 - sw * 0.12, 0.44, 1.85, back ? shadeHex(a.arms, -0.08) : a.arms);
  // torso
  R(-0.65, -4.02, 1.3, 2.05, a.torso);
  if (!back && a.shirt && a.shirt !== "plain") {
    if (a.shirt === "stripes") for (let i = 0; i < 3; i++) R(-0.65, -3.8 + i * 0.6, 1.3, 0.2, shadeHex(a.torso, 0.18));
    else if (a.shirt === "suit") { R(-0.65, -4.02, 0.45, 2.05, "#1f2328"); R(0.2, -4.02, 0.45, 2.05, "#1f2328"); R(-0.08, -3.9, 0.16, 1, "#ef4444"); }
    else if (a.shirt === "brick") { R(-0.4, -3.7, 0.36, 0.36, "#ef4444"); R(0.04, -3.7, 0.36, 0.36, "#facc15"); R(-0.4, -3.28, 0.36, 0.36, "#3b82f6"); R(0.04, -3.28, 0.36, 0.36, "#22c55e"); }
    else R(-0.28, -3.6, 0.56, 0.6, "#facc15");
  }
  if (back && a.hairLong && a.hair) R(-0.62, -4.2, 1.24, 1.0, a.hair);
  // head
  ctx.fillStyle = a.head;
  ctx.beginPath(); ctx.roundRect(x - 0.6 * u, y - 5.25 * u, 1.2 * u, 1.2 * u, u * 0.3); ctx.fill();
  if (a.hair) {
    if (back) { if (a.hat !== "wizard") R(-0.62, -5.36, 1.24, 1.05, a.hair); else R(-0.62, -4.9, 1.24, 0.7, a.hair); }
    else {
      if (a.hat !== "wizard") R(-0.64, -5.38, 1.28, 0.32, a.hair);
      R(-0.66, -5.2, 0.2, a.hairLong ? 1.9 : 0.8, a.hair); R(0.46, -5.2, 0.2, a.hairLong ? 1.9 : 0.8, a.hair);
    }
  }
  if (!back) {
    const k = "#111";
    switch (a.face) {
      case "cool": R(-0.5, -4.98, 1.0, 0.26, k); break;
      case "robot": R(-0.5, -5.0, 1.0, 0.3, "#0f172a"); R(-0.42, -4.95, 0.84, 0.16, "#22d3ee"); break;
      case "wink": R(-0.34, -4.95, 0.16, 0.26, k); R(0.12, -4.86, 0.26, 0.08, k); break;
      case "wow": R(-0.36, -4.98, 0.2, 0.3, k); R(0.16, -4.98, 0.2, 0.3, k); R(-0.1, -4.5, 0.2, 0.22, k); break;
      case "determined": R(-0.4, -5.05, 0.28, 0.07, k); R(0.12, -5.05, 0.28, 0.07, k); R(-0.34, -4.95, 0.16, 0.22, k); R(0.18, -4.95, 0.16, 0.22, k); break;
      default: R(-0.34, -4.95, 0.16, 0.26, k); R(0.18, -4.95, 0.16, 0.26, k);
    }
    if (a.face === "grin") { R(-0.3, -4.55, 0.6, 0.2, k); R(-0.24, -4.55, 0.48, 0.07, "#fff"); }
    else if (a.face !== "wow" && a.face !== "robot") { R(-0.24, -4.48, 0.48, 0.09, k); R(-0.3, -4.55, 0.08, 0.09, k); R(0.22, -4.55, 0.08, 0.09, k); }
  }
  // hats
  switch (a.hat) {
    case "cap": R(-0.65, -5.5, 1.3, 0.42, "#2563eb"); if (!back) R(-0.55, -5.14, 1.1, 0.14, "#1d4ed8"); break;
    case "tophat": R(-0.5, -6.4, 1.0, 1.2, "#1f2328"); R(-0.8, -5.3, 1.6, 0.15, "#111"); R(-0.5, -5.55, 1.0, 0.2, "#ef4444"); break;
    case "crown":
      ctx.fillStyle = "#facc15"; ctx.beginPath();
      ctx.moveTo(x - 0.6 * u, y - 5.2 * u); ctx.lineTo(x - 0.6 * u, y - 5.9 * u); ctx.lineTo(x - 0.3 * u, y - 5.5 * u); ctx.lineTo(x, y - 6 * u);
      ctx.lineTo(x + 0.3 * u, y - 5.5 * u); ctx.lineTo(x + 0.6 * u, y - 5.9 * u); ctx.lineTo(x + 0.6 * u, y - 5.2 * u); ctx.fill(); break;
    case "cone":
      ctx.fillStyle = "#fb923c"; ctx.beginPath(); ctx.moveTo(x - 0.6 * u, y - 5.2 * u); ctx.lineTo(x, y - 6.6 * u); ctx.lineTo(x + 0.6 * u, y - 5.2 * u); ctx.fill();
      R(-0.32, -5.8, 0.64, 0.15, "#fff"); break;
    case "wizard":
      ctx.fillStyle = "#7c3aed"; ctx.beginPath(); ctx.moveTo(x - 0.8 * u, y - 5.15 * u); ctx.lineTo(x, y - 6.9 * u); ctx.lineTo(x + 0.8 * u, y - 5.15 * u); ctx.fill();
      R(-0.8, -5.3, 1.6, 0.18, "#5b21b6"); if (!back) R(-0.1, -6.0, 0.2, 0.2, "#facc15"); break;
    case "headphones":
      ctx.strokeStyle = "#1f2328"; ctx.lineWidth = u * 0.18; ctx.beginPath(); ctx.arc(x, y - 4.7 * u, u * 0.72, Math.PI, 0); ctx.stroke();
      R(-0.82, -4.95, 0.3, 0.55, "#ef4444"); R(0.52, -4.95, 0.3, 0.55, "#ef4444"); break;
  }
}
// One walker on the map. dir: up/down/left/right.
function drawWalker(ctx, look, x, y, dir, phase, h) {
  h = h || 30;
  ctx.fillStyle = "rgba(0,0,0,.25)";
  ctx.beginPath(); ctx.ellipse(x, y, h * 0.32, h * 0.1, 0, 0, Math.PI * 2); ctx.fill();
  if (dir === "left" || dir === "right") {
    const f = dir === "right" ? 1 : -1;
    Kit.drawAvatar(ctx, x, y, h, { look, facing: f, walk: phase });
    hairSide(ctx, x, y, h, look, f);
  } else {
    drawFrontBack(ctx, x, y, h, look, dir === "up", phase);
  }
}
// Battle pose (side view facing left). ko: lying down.
function drawFighter(ctx, look, x, y, h, o) {
  o = o || {};
  ctx.fillStyle = "rgba(0,0,0,.28)";
  ctx.beginPath(); ctx.ellipse(x, y, h * 0.36, h * 0.09, 0, 0, Math.PI * 2); ctx.fill();
  if (o.ko) {
    ctx.save();
    ctx.translate(x, y - h * 0.08);
    ctx.rotate(-Math.PI / 2);
    ctx.globalAlpha = 0.75;
    Kit.drawAvatar(ctx, 0, h * 0.5, h, { look, facing: -1 });
    hairSide(ctx, 0, h * 0.5, h, look, -1);
    ctx.restore();
    return;
  }
  Kit.drawAvatar(ctx, x, y, h, { look, facing: -1, walk: o.walk || 0 });
  hairSide(ctx, x, y, h, look, -1);
  // weapon
  const u = h / 5.2;
  if (o.weapon === "sword") {
    ctx.save(); ctx.translate(x - u * 0.2, y - 2.3 * u); ctx.rotate(-0.6 + (o.swing || 0));
    ctx.fillStyle = "#cbd5e1"; ctx.fillRect(-u * 0.12, -u * 2.4, u * 0.24, u * 2.2);
    ctx.fillStyle = "#a16207"; ctx.fillRect(-u * 0.4, -u * 0.25, u * 0.8, u * 0.2); ctx.fillRect(-u * 0.1, -u * 0.1, u * 0.2, u * 0.5);
    ctx.restore();
  } else if (o.weapon === "staff") {
    ctx.fillStyle = "#8b5a2b"; ctx.fillRect(x - u * 0.6, y - 4.6 * u, u * 0.2, u * 4.4);
    ctx.fillStyle = o.orb || "#67e8f9"; ctx.beginPath(); ctx.arc(x - u * 0.5, y - 4.75 * u, u * 0.32, 0, Math.PI * 2); ctx.fill();
  }
}

// ------------------------------------------------------------------ monsters
// Coordinates in "units": x across (monsters face right), y up from the ground.
function monsterPen(ctx, ox, oy, s) {
  return {
    b(x, y, w, h, c, r) { Kit.brick(ctx, ox + x * s, oy - (y + h) * s, w * s, h * s, c, r); },
    r(x, y, w, h, c) { ctx.fillStyle = c; ctx.fillRect(ox + x * s, oy - (y + h) * s, w * s, h * s); },
    poly(pts, c) { ctx.fillStyle = c; ctx.beginPath(); pts.forEach(([x, y], i) => i ? ctx.lineTo(ox + x * s, oy - y * s) : ctx.moveTo(ox + x * s, oy - y * s)); ctx.fill(); },
  };
}
// Height of each art in units (for HP bars and cursors).
const ART_H = { slime: 6.5, bat: 7.5, rat: 4, shroom: 7.6, toad: 5, wolf: 7, sprite: 9, scorpion: 7, cactus: 8.6, mummy: 9, yeti: 10, skeleton: 8.5, knight: 10.2, wraith: 9.5, golem: 10, dragon: 10, gargoyle: 7.5, treant: 12, wyrm: 11.5, king: 10.6 };

function drawMonster(ctx, art, col, x, y, s, T, o) {
  o = o || {};
  const [c1, c2, c3] = col;
  ctx.fillStyle = "rgba(0,0,0,.25)";
  const shW = { yeti: 5, golem: 6, dragon: 6, treant: 6, wyrm: 5, king: 4 }[art] || 4;
  ctx.beginPath(); ctx.ellipse(x, y, shW * s, s * 0.9, 0, 0, Math.PI * 2); ctx.fill();
  let p = monsterPen(ctx, x, y, s);
  const bob = Math.sin(T * 3);
  switch (art) {
    case "slime": {
      ctx.save(); ctx.translate(x, y); ctx.scale(1 + bob * 0.04, 1 - bob * 0.05); p = monsterPen(ctx, 0, 0, s);
      p.b(-4, 0, 8, 3.2, c1, 6); p.b(-3.2, 2.8, 6.4, 2.3, c1, 5); p.b(-2, 4.8, 4, 1.5, c1, 4);
      p.r(-2.8, 4.2, 0.9, 0.9, "rgba(255,255,255,.55)");
      p.r(0.4, 3.0, 1.2, 1.5, "#fff"); p.r(2.1, 3.0, 1.2, 1.5, "#fff");
      p.r(0.9, 3.2, 0.6, 0.8, "#111"); p.r(2.6, 3.2, 0.6, 0.8, "#111");
      p.r(1.0, 1.9, 1.8, 0.35, c2);
      ctx.restore(); break;
    }
    case "bat": {
      const hy = 3 + Math.sin(T * 5) * 0.6, f = Math.sin(T * 14);
      p.r(-5, hy + 2.3 + f * 0.9, 3.6, 1, c2); p.r(-4.3, hy + 1.4 + f * 0.6, 2.8, 1, c2); p.r(-3.4, hy + 0.6 + f * 0.3, 2, 0.9, c2);
      p.r(1.4, hy + 2.3 + f * 0.9, 3.6, 1, c2); p.r(1.5, hy + 1.4 + f * 0.6, 2.8, 1, c2); p.r(1.4, hy + 0.6 + f * 0.3, 2, 0.9, c2);
      p.b(-1.6, hy, 3.2, 3.2, c1, 4);
      p.r(-1.4, hy + 3.1, 0.7, 1, c1); p.r(0.7, hy + 3.1, 0.7, 1, c1);
      p.r(0, hy + 1.9, 0.6, 0.6, "#ef4444"); p.r(0.9, hy + 1.9, 0.6, 0.6, "#ef4444");
      p.r(0.2, hy + 0.8, 0.25, 0.45, "#fff"); p.r(1.0, hy + 0.8, 0.25, 0.45, "#fff");
      break;
    }
    case "rat": {
      p.r(-6.2, 1.2, 2.4, 0.4, "#f9a8d4");
      p.b(-4, 0.5, 6, 3, c1, 5);
      p.b(1.5, 0.9, 3.2, 2.5, c1, 4);
      p.r(2, 3.1, 1, 1, c2); p.r(2.2, 3.3, 0.6, 0.6, "#f9a8d4");
      p.r(3.5, 2.3, 0.5, 0.5, "#111"); p.r(4.6, 1.6, 0.45, 0.45, "#f472b6");
      p.r(-3, 0, 0.9, 0.7, c2); p.r(0.6, 0, 0.9, 0.7, c2);
      break;
    }
    case "shroom": {
      const sq = bob * 0.15;
      p.r(-1.8, 0, 1.2, 0.6, "#a16207"); p.r(0.6, 0, 1.2, 0.6, "#a16207");
      p.b(-1.6, 0.4, 3.2, 3.6, c2, 3);
      p.b(-4, 3.6 + sq, 8, 2.8, c1, 5); p.b(-2.8, 6.1 + sq, 5.6, 1.5, c1, 4);
      p.r(-2.6, 4.6 + sq, 1, 1, "#fff"); p.r(0.4, 5.6 + sq, 1.2, 1, "#fff"); p.r(2.4, 4.3 + sq, 0.9, 0.9, "#fff");
      p.r(-0.3, 1.9, 0.5, 0.8, "#111"); p.r(0.9, 1.9, 0.5, 0.8, "#111");
      break;
    }
    case "toad": {
      p.b(-4.6, 0, 2.2, 1.2, c2, 2); p.b(2.6, 0, 2.2, 1.2, c2, 2);
      p.b(-4, 0.3, 8, 3.6 + bob * 0.15, c1, 6);
      p.b(-0.6, 3.2, 2, 1.7, c1, 3); p.b(2.1, 3.2, 2, 1.7, c1, 3);
      p.r(-0.1, 3.9, 1, 0.9, "#fde047"); p.r(2.6, 3.9, 1, 0.9, "#fde047");
      p.r(0.3, 4.0, 0.4, 0.6, "#111"); p.r(3.0, 4.0, 0.4, 0.6, "#111");
      p.r(0.8, 1.8, 3.2, 0.35, c2);
      p.r(-3, 2.4, 1, 0.8, c2); p.r(-1.6, 1.2, 0.8, 0.7, c2);
      break;
    }
    case "wolf": {
      const lg = Math.sin(T * 6) * 0.3;
      p.r(-3.5, 0, 0.9, 2.3 + lg, c2); p.r(-1.9, 0, 0.9, 2.3 - lg, c2); p.r(0.6, 0, 0.9, 2.3 - lg, c2); p.r(2, 0, 0.9, 2.3 + lg, c2);
      p.poly([[-4, 4.4], [-6.2, 5.8 + bob * 0.3], [-5.8, 4.2], [-4, 3.4]], c1);
      p.b(-4, 2, 6.6, 3, c1, 4);
      p.b(1.8, 3.4, 3, 2.7, c1, 3);
      p.b(4.4, 3.5, 1.7, 1.3, c1, 2);
      p.r(2, 5.9, 0.8, 1.2, c2); p.r(3.3, 5.9, 0.8, 1.2, c2);
      p.r(3.6, 4.8, 0.6, 0.5, "#facc15"); p.r(5.7, 4.3, 0.45, 0.45, "#111");
      p.r(4.6, 3.5, 1.3, 0.3, "#fff");
      break;
    }
    case "sprite": {
      const sw = Math.sin(T * 2) * 0.2;
      p.b(-1, 0, 2, 5.2, "#15803d", 2);
      p.b(-3.6, 3 + sw, 2.8, 1, c1, 2); p.b(0.9, 3.6 - sw, 2.8, 1, c1, 2);
      p.r(-1.5, 1.5, 0.5, 0.3, "#14532d"); p.r(1, 2.5, 0.5, 0.3, "#14532d");
      p.b(-2.3, 5, 4.6, 3.8, c2, 6);
      p.b(-1.2, 5.8, 2.4, 2.1, "#facc15", 3);
      p.r(-0.6, 6.8, 0.45, 0.6, "#111"); p.r(0.35, 6.8, 0.45, 0.6, "#111");
      break;
    }
    case "scorpion": {
      const tw = Math.sin(T * 3) * 0.3;
      p.r(-2.5, 0, 0.4, 0.7, c2); p.r(-1.2, 0, 0.4, 0.7, c2); p.r(0.1, 0, 0.4, 0.7, c2);
      p.b(-3, 0.5, 5, 2, c1, 3);
      p.b(1.8, 0.6, 2, 1.9, c1, 3);
      p.b(3.6, 1.7 + tw * 0.5, 1.9, 1.1, c2, 2); p.b(3.6, 0.2, 1.9, 1.1, c2, 2);
      p.b(-4.6, 1.6, 1.5, 1.5, c1, 2); p.b(-5.3, 3, 1.5, 1.5, c1, 2); p.b(-4.9 + tw, 4.4, 1.5, 1.5, c1, 2); p.b(-3.6 + tw, 5.4, 1.5, 1.3, c1, 2);
      p.r(-2.3 + tw, 5.1, 1, 0.6, "#7f1d1d");
      p.r(3.0, 2.0, 0.45, 0.45, "#111");
      break;
    }
    case "cactus": {
      p.b(-1.8, 0, 3.6, 8, c1, 4);
      p.b(-4, 3, 2.4, 1.2, c1, 2); p.b(-4, 3, 1.2, 3.6 + bob * 0.2, c1, 2);
      p.b(1.6, 4, 2.4, 1.2, c1, 2); p.b(2.8, 4, 1.2, 3.1 - bob * 0.2, c1, 2);
      p.r(-0.9, 5.6, 0.6, 0.7, "#111"); p.r(0.5, 5.6, 0.6, 0.7, "#111");
      p.r(-1.1, 6.5, 1, 0.25, "#111"); p.r(0.4, 6.5, 1, 0.25, "#111");
      p.r(-0.7, 4.4, 1.5, 0.3, "#111");
      [[-1.5, 2], [1.2, 1.4], [-1.4, 7], [1.3, 7.4], [-3.8, 6.4], [3.6, 6.9]].forEach(([a, b]) => p.r(a, b, 0.3, 0.3, "#fef9c3"));
      p.r(-0.5, 8, 1, 0.6, "#f472b6");
      break;
    }
    case "mummy": {
      p.b(-1.6, 0, 1.4, 3, c1, 2); p.b(0.2, 0, 1.4, 3, c1, 2);
      p.b(-2, 3, 4, 3.5, c1, 3);
      p.b(1.6, 5 + bob * 0.15, 3.2, 1, c1, 2);
      p.b(-1.4, 6.4, 2.8, 2.6, c1, 4);
      for (let i = 0; i < 6; i++) p.r(-2, 0.6 + i * 1.4, 4, 0.25, c2);
      p.r(-1.4, 7.4, 2.8, 0.25, c2);
      p.r(0.2, 7.6, 0.6, 0.45, "#facc15"); p.r(1.0, 7.6, 0.4, 0.45, "#facc15");
      break;
    }
    case "yeti": {
      p.b(-2.6, 0, 2, 2.6, c1, 3); p.b(0.6, 0, 2, 2.6, c1, 3);
      p.b(-5, 2.6 + bob * 0.2, 1.8, 4.3, c1, 3); p.b(3.2, 2.6 - bob * 0.2, 1.8, 4.3, c1, 3);
      p.b(-3.6, 2.3, 7.2, 5.2, c1, 5);
      p.b(-1.8, 7.2, 3.6, 2.8, c1, 4);
      p.b(-0.9, 7.5, 2.6, 1.9, c2, 3);
      p.r(-0.2, 8.5, 0.5, 0.5, "#111"); p.r(0.9, 8.5, 0.5, 0.5, "#111");
      p.r(-0.1, 7.8, 1.4, 0.3, "#111");
      p.r(-3, 5, 1, 0.3, "#cbd5e1"); p.r(1.8, 3.5, 1, 0.3, "#cbd5e1");
      break;
    }
    case "skeleton": {
      const bn = c1;
      p.r(-1.2, 0, 0.6, 3, bn); p.r(0.6, 0, 0.6, 3, bn);
      p.r(-1.2, 3, 2.4, 0.6, bn); p.r(-0.3, 3.4, 0.6, 2.6, bn);
      for (let i = 0; i < 3; i++) p.r(-1.4, 4 + i * 0.8, 2.8, 0.4, bn);
      p.r(-1.9, 4, 0.5, 2.4, bn); p.r(1.4, 4 + bob * 0.2, 0.5, 2.4, bn);
      p.r(1.65, 3.8 + bob * 0.2, 0.3, 4.4, "#cbd5e1"); p.r(1.2, 4.2 + bob * 0.2, 1.2, 0.3, "#a16207");
      p.b(-1.3, 6.2, 2.6, 2.3, bn, 4);
      p.r(-0.7, 7.1, 0.6, 0.6, "#111"); p.r(0.4, 7.1, 0.6, 0.6, "#111");
      p.r(-0.4, 6.3, 1.4, 0.3, "#111");
      break;
    }
    case "knight": {
      p.b(-1.5, 0, 1.3, 3, c2, 2); p.b(0.2, 0, 1.3, 3, c2, 2);
      p.r(-2.6, 4 + bob * 0.2, 0.4, 5, "#cbd5e1"); p.r(-3, 4.2 + bob * 0.2, 1.2, 0.3, "#a16207");
      p.b(-2, 3, 4, 3.6, c1, 3);
      p.b(-2.4, 5.8, 1.2, 1, c2, 2); p.b(1.2, 5.8, 1.2, 1, c2, 2);
      p.b(-1.4, 6.6, 2.8, 2.6, c1, 3);
      p.r(0.1, 7.6, 1.3, 0.4, "#ef4444");
      p.r(-0.6, 9.2, 1.2, 1, "#7f1d1d");
      p.b(1.6, 2.4, 1.6, 3.2, "#475569", 2); p.r(2.1, 3.7, 0.6, 0.6, "#a855f7");
      break;
    }
    case "wraith": {
      const fy = 1.2 + Math.sin(T * 2.5) * 0.4;
      ctx.globalAlpha = 0.92;
      for (let i = 0; i < 5; i++) p.r(-2.6 + i * 1.05, fy - 0.6 * ((i + Math.floor(T * 4)) % 2), 1, 1, c1);
      p.b(-2.6, fy, 5.2, 2.2, c1, 2); p.b(-2.2, fy + 2, 4.4, 3, c1, 3);
      p.b(2, fy + 3.2, 1.8, 0.6, c2, 1);
      p.b(-1.8, fy + 5, 3.6, 2.8, c1, 4);
      p.r(-1, fy + 5.4, 2.4, 1.8, "#0b0617");
      p.r(-0.4, fy + 6.2, 0.6, 0.5, "#a3e635"); p.r(0.6, fy + 6.2, 0.6, 0.5, "#a3e635");
      ctx.globalAlpha = 1;
      break;
    }
    case "golem": {
      p.b(-3, 0, 2.4, 3, c2, 3); p.b(0.6, 0, 2.4, 3, c2, 3);
      p.b(-6, 2 + bob * 0.2, 2.2, 5, c2, 3); p.b(3.8, 2 - bob * 0.2, 2.2, 5, c2, 3);
      p.b(-4, 2.8, 8, 5, c1, 5);
      p.b(-1.6, 7.6, 3.2, 2.4, c1, 4);
      p.r(0, 8.6, 0.6, 0.5, c3); p.r(0.9, 8.6, 0.6, 0.5, c3);
      p.r(-2, 5, 2, 0.3, c3); p.r(-0.4, 4.2, 0.3, 1.1, c3); p.r(1, 6, 1.6, 0.3, c3);
      if (o.boss) { p.poly([[-4, 7.8], [-3.4, 9.6], [-2.6, 7.8]], "#e0f2fe"); p.poly([[2.6, 7.8], [3.4, 9.8], [4, 7.8]], "#e0f2fe"); }
      break;
    }
    case "dragon": {
      const fl = Math.sin(T * 4);
      p.b(-3, 5.4 + fl * 0.5, 4, 1, c2, 1); p.b(-4.4, 6.4 + fl * 0.8, 4, 1, c2, 1); p.b(-5.6, 7.4 + fl * 1.1, 3.4, 1, c2, 1);
      p.b(-7, 1.6, 1.8, 0.9, c1, 1); p.b(-5.6, 2.2, 2.8, 1.1, c1, 2);
      p.b(-2.6, 0, 1.3, 2.4, c2, 2); p.b(1, 0, 1.3, 2.4, c2, 2);
      p.b(-3, 2, 6, 3.6, c1, 4);
      p.r(-1.8, 2.2, 4, 0.9, o.belly || shadeHex(c1, 0.15));
      p.b(2.2, 4.4, 1.6, 3, c1, 2);
      p.b(3, 7 + bob * 0.15, 3.4, 2, c1, 3);
      p.b(3.6, 6.2 + bob * 0.15, 2.8, 0.9, c2, 2);
      p.r(3.2, 9 + bob * 0.15, 0.6, 1, c3);
      p.r(5, 8.2 + bob * 0.15, 0.5, 0.5, c3);
      if (o.crown) { p.r(3.4, 9 + bob * 0.15, 2.6, 0.5, "#facc15"); p.r(3.4, 9.4 + bob * 0.15, 0.5, 0.7, "#facc15"); p.r(4.5, 9.4 + bob * 0.15, 0.5, 0.9, "#facc15"); p.r(5.5, 9.4 + bob * 0.15, 0.5, 0.7, "#facc15"); }
      break;
    }
    case "gargoyle": {
      const fl = Math.sin(T * 3) * 0.3;
      p.b(-5, 3 + fl, 2.8, 3.2, c2, 2); p.b(-5.8, 5 + fl, 2, 2, c2, 2);
      p.b(-1.8, 0, 1.4, 1.8, c2, 2); p.b(0.4, 0, 1.4, 1.8, c2, 2);
      p.b(-2.2, 1.6, 4.4, 3.6, c1, 3);
      p.b(1.8, 2.6, 1.6, 1, c2, 1);
      p.b(-1.4, 5, 2.8, 2.2, c1, 3);
      p.r(-1.2, 7.1, 0.5, 1, c2); p.r(0.8, 7.1, 0.5, 1, c2);
      p.r(0.2, 6, 0.6, 0.4, "#f59e0b"); p.r(1.0, 6, 0.4, 0.4, "#f59e0b");
      break;
    }
    case "treant": {
      const sw = Math.sin(T * 1.5) * 0.25;
      p.r(-3.6, 0, 1.4, 0.8, c1); p.r(2.2, 0, 1.4, 0.8, c1);
      p.b(-2.5, 0, 5, 7.2, c1, 3);
      p.r(-1.8, 1, 0.3, 4, shadeHex(c1, -0.1)); p.r(1.2, 2, 0.3, 3, shadeHex(c1, -0.1));
      p.b(-5.6, 4 + sw, 3.2, 1, c1, 2); p.b(-6, 4 + sw, 1, 2.6, c1, 2);
      p.b(2.4, 4.6 - sw, 3.2, 1, c1, 2); p.b(4.9, 4.6 - sw, 1, 2.6, c1, 2);
      p.r(-1.3, 4.6, 1, 1, "#1a0f05"); p.r(0.5, 4.6, 1, 1, "#1a0f05");
      p.r(-1.0, 4.8, 0.5, 0.5, "#facc15"); p.r(0.8, 4.8, 0.5, 0.5, "#facc15");
      p.r(-1, 2.8, 2.2, 0.6, "#1a0f05");
      p.b(-4.6, 7, 9.2, 3, c2, 5); p.b(-3.6, 9.6, 7.2, 2.2, c2, 5);
      p.r(-3, 8, 1.4, 0.8, "#4ade80"); p.r(1.6, 9.8, 1.2, 0.8, "#4ade80"); p.r(-0.4, 7.4, 1, 0.6, "#86efac");
      break;
    }
    case "wyrm": {
      const sw = Math.sin(T * 2) * 0.4;
      p.b(-2.5, 0, 5, 2.2, c2, 3);
      p.b(-2.2 + sw * 0.3, 2, 4.4, 2.2, c1, 3);
      p.b(-1.6 + sw * 0.6, 4, 4.4, 2.2, c2, 3);
      p.b(-0.8 + sw, 6, 4.4, 2.2, c1, 3);
      p.b(0 + sw, 8, 5, 3, c1, 4);
      p.r(3.4 + sw, 8.3, 1.8, 1.7, "#3b0a0a");
      [8.3, 9.0, 9.6].forEach((yy) => p.r(3.4 + sw, yy, 0.4, 0.35, "#fff"));
      p.r(4.7 + sw, 9.6, 0.4, 0.4, "#fff");
      p.r(2.2 + sw, 10, 0.7, 0.6, "#ef4444");
      p.b(-5, 0, 10, 1, "#e9c46a", 3);
      break;
    }
    case "king": {
      const fl = Math.sin(T * 2) * 0.2;
      p.b(-3.8, 0, 1.6, 7.2, c2, 2);
      p.b(-2.6, 0, 5.2, 6.6, c1, 3);
      p.r(-2.6, 0, 5.2, 0.5, c3); p.r(-0.25, 0.5, 0.5, 6, c3);
      p.r(3.7, 0, 0.4, 9, "#78716c");
      p.b(2.2, 3.6 + fl, 1.8, 1.2, c1, 2);
      p.b(3.2, 8.8, 1.3, 1.3, c2, 5);
      ctx.fillStyle = "rgba(192,132,252,.35)"; ctx.beginPath(); ctx.arc(x + 3.85 * s, y - 9.4 * s, 1.4 * s + Math.sin(T * 5) * 2, 0, Math.PI * 2); ctx.fill();
      p.b(-1.3, 6.4, 2.6, 2.6, "#0b0617", 4);
      p.r(-0.4, 7.4, 0.6, 0.6, "#c084fc"); p.r(0.6, 7.4, 0.6, 0.6, "#c084fc");
      p.r(-1.4, 9, 2.8, 0.7, c3); p.r(-1.4, 9.6, 0.5, 0.7, c3); p.r(-0.25, 9.6, 0.5, 0.9, c3); p.r(0.9, 9.6, 0.5, 0.7, c3);
      break;
    }
  }
}
