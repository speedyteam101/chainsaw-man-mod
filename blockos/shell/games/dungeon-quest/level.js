// Dungeon Quest: building the town hub and the generated brick dungeons.
import { THREE } from "../kit3d.js";
import { rng } from "./data.js";
import { disposeGroup } from "./models.js";

export const CELL = 64;     // distance between room centers
export const WALL_H = 8;
const DOOR = 10;

// Everything one area adds to the world, so it can be torn down when you leave.
export class Zone {
  constructor(world, kind) {
    this.world = world;
    this.kind = kind;
    this.parts = [];
    this.objs = [];
    this.walls = [];          // parts the camera should not look through
    this.roomParts = [];      // per room, for distance culling
    this.rooms = [];
    this.hazards = [];
    this.gates = [];
  }

  part(o, room) {
    const m = this.world.part(o);
    // One material per part = one draw call (kit parts use 6 face materials).
    if (Array.isArray(m.material)) m.material = m.material[2];
    if (o.wall) this.walls.push(m);
    this.track(m, room);
    this.parts.push(m);
    return m;
  }

  obj(o, room) {
    this.world.scene.add(o);
    this.objs.push(o);
    this.track(o, room);
    return o;
  }

  track(o, room) {
    if (room === undefined || room === null) return;
    (this.roomParts[room] = this.roomParts[room] || []).push(o);
  }

  removePart(m) {
    this.world.remove(m);
    m.geometry.dispose();
    const i = this.parts.indexOf(m);
    if (i >= 0) this.parts.splice(i, 1);
    const j = this.walls.indexOf(m);
    if (j >= 0) this.walls.splice(j, 1);
  }

  label(text, opts, room) {
    const s = this.world.label(text, opts);
    this.objs.push(s);
    this.track(s, room);
    return s;
  }

  cull(x, z, range) {
    for (let i = 0; i < this.roomParts.length; i++) {
      const list = this.roomParts[i];
      const r = this.rooms[i];
      if (!list || !r) continue;
      const vis = Math.hypot(r.x - x, r.z - z) < range + r.size / 2;
      if (list.vis === vis) continue;
      list.vis = vis;
      for (const o of list) o.visible = vis;
    }
  }

  destroy() {
    for (const m of this.parts) { this.world.remove(m); m.geometry.dispose(); }
    for (const o of this.objs) { this.world.scene.remove(o); disposeGroup(o); }
    this.parts.length = this.objs.length = this.walls.length = 0;
  }
}

// A portal arch with a glowing panel you walk into.
export function portal(zone, x, z, yaw, color, frame, onTouch, room, locked) {
  const along = Math.abs(Math.sin(yaw)) > 0.5;   // arch spans along z when facing +-x
  const P = (size, pos, o) => zone.part(Object.assign({ size: along ? [size[2], size[1], size[0]] : size, pos: along ? [x + pos[2], pos[1], z + pos[0]] : [x + pos[0], pos[1], z + pos[2]], color: frame, studs: false }, o || {}), room);
  P([14, 1, 8], [0, 0.5, 0], { studs: true });
  P([2, 13, 2], [-5, 7, 0]);
  P([2, 13, 2], [5, 7, 0]);
  P([12.5, 2, 2.4], [0, 14, 0]);
  const panel = P([8, 12, 0.6], [0, 7, 0], { color: locked ? "#4b5563" : color, material: locked ? "glass" : "neon", collide: false, onTouch });
  return panel;
}

// ------------------------------------------------------------------ town

export function buildTown(zone, o) {
  const P = (opts) => zone.part(opts);
  const W = { studs: false };
  P({ size: [340, 2, 340], pos: [0, -1, 0], color: "#4b9b3f", shadow: false });
  // plaza and paths
  P(Object.assign({ size: [74, 0.2, 76], pos: [0, 0.1, -8], color: "#b6ada4", collide: false, shadow: false }, {}));
  P({ size: [12, 0.2, 40], pos: [0, 0.1, 48], color: "#b6ada4", collide: false, shadow: false });
  // fountain
  P({ size: [13, 1.6, 13], pos: [0, 0.8, 0], color: "#94a3b8" });
  P({ size: [10.5, 0.3, 10.5], pos: [0, 1.65, 0], color: "#38bdf8", material: "neon", collide: false, studs: false });
  P(Object.assign({ size: [2, 5, 2], pos: [0, 3, 0], color: "#94a3b8" }, W));
  P({ size: [4, 0.6, 4], pos: [0, 5.6, 0], color: "#7dd3fc", material: "neon", collide: false, studs: false });

  // blacksmith (west, facing east)
  const bx = -34, bz = -6;
  P({ size: [18, 0.6, 16], pos: [bx, 0.3, bz], color: "#78716c" });
  P(Object.assign({ size: [1.4, 11, 16], pos: [bx - 8.3, 5.5, bz], color: "#8b5e3c", material: "wood" }, W));
  P(Object.assign({ size: [18, 11, 1.4], pos: [bx, 5.5, bz - 7.3], color: "#8b5e3c", material: "wood" }, W));
  P(Object.assign({ size: [18, 11, 1.4], pos: [bx, 5.5, bz + 7.3], color: "#8b5e3c", material: "wood" }, W));
  P(Object.assign({ size: [21, 1.2, 19], pos: [bx, 11.6, bz], color: "#b91c1c" }, W));
  P(Object.assign({ size: [5, 4, 5], pos: [bx - 5, 2.6, bz - 3.6], color: "#57534e" }, W));       // forge
  P({ size: [3.2, 1.6, 0.4], pos: [bx - 5, 2, bz - 1.05], color: "#f97316", material: "neon", collide: false, studs: false });
  P(Object.assign({ size: [1.6, 1.4, 1.2], pos: [bx - 1, 1.3, bz + 2], color: "#3f3f46" }, W));      // anvil
  P(Object.assign({ size: [3.2, 0.8, 1.6], pos: [bx - 1, 2.4, bz + 2], color: "#52525b" }, W));
  zone.label("Blacksmith", { pos: [bx, 14.2, bz], height: 2.2 });
  const smith = zone.world.character({ head: "#d6a77a", arms: "#d6a77a", torso: "#78350f", legs: "#3f3f46", face: "determined", hat: "none" }, "Smith Brick");
  smith.position.set(bx - 3.5, 0.6, bz + 4.5);
  smith.rotation.y = -Math.PI / 2;
  zone.objs.push(smith);
  P({ size: [6, 0.3, 6], pos: [bx + 12.5, 0.2, bz], color: "#fbbf24", material: "neon", collide: false, studs: false, onTouch: o.onSmith });
  zone.label("Upgrade gear", { pos: [bx + 12.5, 3, bz], height: 1.1, color: "#fde68a" });

  // potion shop (east, facing west)
  const sx = 34, sz = -6;
  P({ size: [18, 0.6, 16], pos: [sx, 0.3, sz], color: "#a8a29e" });
  P(Object.assign({ size: [1.4, 11, 16], pos: [sx + 8.3, 5.5, sz], color: "#6d28d9" }, W));
  P(Object.assign({ size: [18, 11, 1.4], pos: [sx, 5.5, sz - 7.3], color: "#7c3aed" }, W));
  P(Object.assign({ size: [18, 11, 1.4], pos: [sx, 5.5, sz + 7.3], color: "#7c3aed" }, W));
  P(Object.assign({ size: [21, 1.2, 19], pos: [sx, 11.6, sz], color: "#f472b6" }, W));
  P({ size: [2.2, 3, 12], pos: [sx - 3, 1.5, sz], color: "#8b5a2b", material: "wood" });   // counter
  P(Object.assign({ size: [1.4, 0.4, 12], pos: [sx + 7, 5, sz], color: "#8b5a2b" }, W));    // shelf
  ["#ef4444", "#a855f7", "#22c55e", "#3b82f6", "#ef4444", "#facc15"].forEach((c, i) => {
    P({ size: [0.8, 1.2, 0.8], pos: [sx + 7, 5.8, sz - 5 + i * 2], color: c, material: "neon", collide: false, studs: false });
  });
  P(Object.assign({ size: [3, 2, 3], pos: [sx + 3, 1.6, sz - 4], color: "#1f2937" }, W));       // cauldron
  P({ size: [2.4, 0.2, 2.4], pos: [sx + 3, 2.65, sz - 4], color: "#4ade80", material: "neon", collide: false, studs: false });
  zone.label("Potion Shop", { pos: [sx, 14.2, sz], height: 2.2 });
  const alch = zone.world.character({ head: "#f1c27d", arms: "#f1c27d", torso: "#7c3aed", legs: "#312e81", face: "smile", hat: "wizard" }, "Alchemist Ada");
  alch.position.set(sx + 2, 0.6, sz + 2);
  alch.rotation.y = Math.PI / 2;
  zone.objs.push(alch);
  P({ size: [6, 0.3, 6], pos: [sx - 12.5, 0.2, sz], color: "#c084fc", material: "neon", collide: false, studs: false, onTouch: o.onShop });
  zone.label("Buy potions", { pos: [sx - 12.5, 3, sz], height: 1.1, color: "#f5d0fe" });

  // portals (north)
  o.dungeons.forEach((d, i) => {
    const x = (i - 1) * 26, z = -52;
    const locked = !o.unlocked(i);
    portal(zone, x, z, 0, d.accent, d.wall, () => o.onPortal(i), undefined, locked);
    zone.label(d.name, { pos: [x, 18, z], height: 2 });
    zone.label(locked ? "Locked" : "Level " + d.rec + "+", { pos: [x, 16.2, z], height: 1.2, color: locked ? "#9ca3af" : "#fde68a" });
  });
  zone.label("DUNGEON QUEST", { pos: [0, 26, -60], height: 4.2, color: "#facc15" });

  // trees and lamps
  const R = rng(42);
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * Math.PI * 2 + 0.2;
    const x = Math.cos(a) * 62, z = Math.sin(a) * 62 - 6;
    if (z < -40 && Math.abs(x) < 50) continue;
    P(Object.assign({ size: [2, 7, 2], pos: [x, 3.5, z], color: "#7c4a26", material: "wood" }, W));
    P({ size: [7 + R() * 2, 6, 7 + R() * 2], pos: [x, 9, z], color: R() < 0.5 ? "#2f8f3a" : "#3fa34d" });
  }
  for (const [x, z] of [[-14, 18], [14, 18], [-14, -30], [14, -30]]) {
    P(Object.assign({ size: [0.7, 8, 0.7], pos: [x, 4, z], color: "#1f2937" }, W));
    P({ size: [1.4, 1.4, 1.4], pos: [x, 8.6, z], color: "#fde68a", material: "neon", collide: false, studs: false });
  }
  zone.rooms = [{ x: 0, z: 0, size: 300 }];
  return { spawn: [0, 0.5, 40], yaw: 0 };
}

// ------------------------------------------------------------------ dungeon plan

const DIRS = { N: [0, -1], S: [0, 1], E: [1, 0], W: [-1, 0] };
const TEMPLATES = ["pillars", "pool", "crates", "altar", "ruins"];

export function planDungeon(def, seed) {
  for (let attempt = 0; attempt < 60; attempt++) {
    const R = rng(seed + attempt * 7919);
    const n = def.rooms + 2;
    const cells = [[0, 0]];
    const used = new Set(["0,0"]);
    let ok = true;
    for (let i = 1; i < n; i++) {
      const [cx, cz] = cells[i - 1];
      const opts = [];
      for (const [dx, dz, w] of [[0, -1, 3], [1, 0, 1.5], [-1, 0, 1.5]]) {
        const nx = cx + dx, nz = cz + dz;
        if (used.has(nx + "," + nz)) continue;
        let touch = false;
        for (const [ax, az] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const k = nx + ax + "," + (nz + az);
          if (k !== cx + "," + cz && used.has(k)) touch = true;
        }
        if (!touch) opts.push([dx, dz, w]);
      }
      if (!opts.length) { ok = false; break; }
      let x = R() * opts.reduce((s, q) => s + q[2], 0);
      let pick = opts[0];
      for (const q of opts) { if ((x -= q[2]) < 0) { pick = q; break; } }
      cells.push([cx + pick[0], cz + pick[1]]);
      used.add(cx + pick[0] + "," + (cz + pick[1]));
    }
    if (!ok) continue;
    const templ = TEMPLATES.slice().sort(() => R() - 0.5);
    const rooms = cells.map(([cx, cz], i) => {
      const kind = i === 0 ? "entrance" : i === n - 1 ? "boss" : "combat";
      const size = kind === "entrance" ? 30 : kind === "boss" ? 56 : [34, 38, 42][Math.floor(R() * 3)];
      return { i, cx, cz, x: cx * CELL, z: cz * CELL, size, kind, template: kind === "combat" ? templ[(i - 1) % templ.length] : kind, doors: {}, waves: [], solids: [] };
    });
    for (let i = 0; i < n - 1; i++) {
      const a = rooms[i], b = rooms[i + 1];
      const dx = b.cx - a.cx, dz = b.cz - a.cz;
      const out = Object.keys(DIRS).find((k) => DIRS[k][0] === dx && DIRS[k][1] === dz);
      const back = Object.keys(DIRS).find((k) => DIRS[k][0] === -dx && DIRS[k][1] === -dz);
      a.doors[out] = "out";
      b.doors[back] = "in";
      a.exit = out;
      b.entry = back;
    }
    // monster waves
    const [rusher, caster, brute] = def.enemies;
    for (const r of rooms) {
      if (r.kind !== "combat") continue;
      const count = 3 + def.tier + Math.floor(r.i * 0.6);
      const list = [];
      const brutes = r.i >= 2 ? 1 + (def.tier >= 2 && r.i >= 4 ? 1 : 0) : 0;
      for (let k = 0; k < brutes; k++) list.push(brute);
      const casters = Math.max(1, Math.round((count - brutes) * 0.32));
      for (let k = 0; k < casters; k++) list.push(caster);
      while (list.length < count) list.push(rusher);
      list.sort(() => R() - 0.5);
      if (list.length > 5) {
        const cut = Math.ceil(list.length * 0.55);
        r.waves = [list.slice(0, cut), list.slice(cut)];
      } else r.waves = [list];
    }
    return { seed, rooms, R };
  }
  throw new Error("could not plan dungeon");
}

// ------------------------------------------------------------------ dungeon build

export function buildDungeon(zone, plan, def, hooks) {
  const R = rng(plan.seed ^ 0x5bd1e995);
  zone.rooms = plan.rooms;
  const H = WALL_H;
  const wallPart = (size, pos, room, color) => zone.part({ size, pos, color: color || def.wall, studs: false, wall: true }, room);

  for (const r of plan.rooms) {
    const s = r.size, q = s / 2, i = r.i;
    zone.part({ size: [s, 2, s], pos: [r.x, -1, r.z], color: def.floor, shadow: false }, i);
    zone.part({ size: [s - 8, 0.1, s - 8], pos: [r.x, 0.05, r.z], color: def.floor2, collide: false, shadow: false }, i);
    // walls with door gaps
    for (const side of ["N", "S", "E", "W"]) {
      const [dx, dz] = DIRS[side];
      const door = !!r.doors[side];
      const len = s + 4;
      if (dz !== 0) {
        const zc = r.z + dz * (q + 1);
        if (!door) wallPart([len, H, 2], [r.x, H / 2, zc], i);
        else {
          const seg = (len - DOOR) / 2;
          wallPart([seg, H, 2], [r.x - DOOR / 2 - seg / 2, H / 2, zc], i);
          wallPart([seg, H, 2], [r.x + DOOR / 2 + seg / 2, H / 2, zc], i);
        }
      } else {
        const xc = r.x + dx * (q + 1);
        if (!door) wallPart([2, H, len], [xc, H / 2, r.z], i);
        else {
          const seg = (len - DOOR) / 2;
          wallPart([2, H, seg], [xc, H / 2, r.z - DOOR / 2 - seg / 2], i);
          wallPart([2, H, seg], [xc, H / 2, r.z + DOOR / 2 + seg / 2], i);
        }
      }
      // a torch on each wall, off to one side of the door
      const off = q * 0.55;
      const tx = dz !== 0 ? r.x + off : r.x + dx * (q - 0.2);
      const tz = dz !== 0 ? r.z + dz * (q - 0.2) : r.z - off;
      zone.part({ size: [0.9, 1.4, 0.9], pos: [tx, 5.2, tz], color: def.torch, material: "neon", collide: false, studs: false }, i);
      zone.part({ size: [0.5, 1.2, 0.5], pos: [tx, 4.1, tz], color: def.trim, collide: false, studs: false, shadow: false }, i);
    }
    decorate(zone, r, def, R, hooks);
  }
  // corridors between consecutive rooms, and gates on the exit doors
  for (let i = 0; i < plan.rooms.length - 1; i++) {
    const a = plan.rooms[i], b = plan.rooms[i + 1];
    const [dx, dz] = DIRS[a.exit];
    if (dz !== 0) {
      const z0 = a.z + dz * (a.size / 2 + 2), z1 = b.z - dz * (b.size / 2 + 2);
      const len = Math.abs(z1 - z0), zm = (z0 + z1) / 2;
      zone.part({ size: [DOOR, 2, len + 4], pos: [a.x, -1, zm], color: def.floor2, shadow: false }, i);
      wallPart([2, H, len], [a.x - DOOR / 2 - 1, H / 2, zm], i, def.trim);
      wallPart([2, H, len], [a.x + DOOR / 2 + 1, H / 2, zm], i, def.trim);
    } else {
      const x0 = a.x + dx * (a.size / 2 + 2), x1 = b.x - dx * (b.size / 2 + 2);
      const len = Math.abs(x1 - x0), xm = (x0 + x1) / 2;
      zone.part({ size: [len + 4, 2, DOOR], pos: [xm, -1, a.z], color: def.floor2, shadow: false }, i);
      wallPart([len, H, 2], [xm, H / 2, a.z - DOOR / 2 - 1], i, def.trim);
      wallPart([len, H, 2], [xm, H / 2, a.z + DOOR / 2 + 1], i, def.trim);
    }
    if (i > 0) {
      const gx = a.x + dx * (a.size / 2 + 1), gz = a.z + dz * (a.size / 2 + 1);
      const sz = dz !== 0 ? [DOOR, H, 1.2] : [1.2, H, DOOR];
      const parts = [zone.part({ size: sz, pos: [gx, H / 2, gz], color: def.gate, material: "glass", studs: false, wall: true }, i)];
      for (const k of [-3, 0, 3]) {
        const bsz = dz !== 0 ? [0.5, H, 0.5] : [0.5, H, 0.5];
        parts.push(zone.part({ size: bsz, pos: [gx + (dz !== 0 ? k : 0), H / 2, gz + (dz !== 0 ? 0 : k)], color: def.gate, material: "neon", collide: false, studs: false }, i));
      }
      zone.gates[i] = parts;
    }
  }
  const e = plan.rooms[0];
  const [ex, ez] = DIRS[e.exit];
  return { spawn: [e.x - ex * 4, 0.5, e.z - ez * 4], yaw: Math.atan2(-ex, -ez) };
}

function decorate(zone, r, def, R, hooks) {
  const q = r.size / 2, i = r.i;
  const solid = (size, pos, color, o) => {
    const m = zone.part(Object.assign({ size, pos: [r.x + pos[0], pos[1], r.z + pos[2]], color, studs: false }, o || {}), i);
    if (!o || o.collide !== false) r.solids.push({ x0: r.x + pos[0] - size[0] / 2, x1: r.x + pos[0] + size[0] / 2, z0: r.z + pos[2] - size[2] / 2, z1: r.z + pos[2] + size[2] / 2, y1: pos[1] + size[1] / 2 });
    return m;
  };
  const quad = (min) => {
    // a random spot away from the door lanes through the middle
    const u = (R() < 0.5 ? -1 : 1) * (min + R() * (q - min - 4));
    const v = (R() < 0.5 ? -1 : 1) * (min + R() * (q - min - 4));
    return [u, v];
  };
  switch (r.template) {
    case "entrance": {
      const back = Object.keys(DIRS).find((k) => DIRS[k][0] === -DIRS[r.exit][0] && DIRS[k][1] === -DIRS[r.exit][1]);
      const [bx, bz] = DIRS[back];
      const px = r.x + bx * (q - 5), pz = r.z + bz * (q - 5);
      const yaw = Math.atan2(bx, bz);
      hooks.entrancePortal = portal(zone, px, pz, yaw, "#facc15", def.trim, hooks.onExit, i);
      zone.label("Back to town", { pos: [px, 17, pz], height: 1.4, color: "#fde68a" }, i);
      zone.label(def.name, { pos: [r.x, 12, r.z], height: 2.6, color: def.torch }, i);
      break;
    }
    case "pillars":
      for (const [u, v] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) solid([3.4, WALL_H + 2, 3.4], [u * q * 0.45, (WALL_H + 2) / 2, v * q * 0.45], def.trim);
      for (const [u, v] of [[-1, -1], [1, 1]]) zone.part({ size: [1, 1, 1], pos: [r.x + u * q * 0.45, WALL_H + 2.6, r.z + v * q * 0.45], color: def.torch, material: "neon", collide: false, studs: false }, i);
      break;
    case "pool": {
      zone.part({ size: [12, 0.3, 12], pos: [r.x, 0.15, r.z], color: def.hazard, material: "neon", collide: false, studs: false, shadow: false }, i);
      zone.hazards.push({ x: r.x, z: r.z, h: 6, room: i });
      for (const [u, v] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) solid([2, 1.2, 2], [u * 7.5, 0.6, v * 7.5], def.trim);
      break;
    }
    case "crates": {
      const n = 5 + Math.floor(R() * 3);
      for (let k = 0; k < n; k++) {
        const [u, v] = quad(7);
        solid([3, 3, 3], [u, 1.5, v], "#8b5a2b", { material: "wood" });
        if (R() < 0.4) zone.part({ size: [2.2, 2.2, 2.2], pos: [r.x + u, 4.1, r.z + v], color: "#a16207", material: "wood", studs: false }, i);
      }
      break;
    }
    case "altar":
      solid([14, 1, 14], [0, 0.5, 0], def.trim, { studs: true });
      for (const [u, v] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
        zone.part({ size: [1.4, 2, 1.4], pos: [r.x + u * 5.6, 2, r.z + v * 5.6], color: def.wall, studs: false }, i);
        zone.part({ size: [1, 0.9, 1], pos: [r.x + u * 5.6, 3.45, r.z + v * 5.6], color: def.torch, material: "neon", collide: false, studs: false }, i);
      }
      r.solids.length = 0;   // the dais is walkable for monsters too
      break;
    case "ruins": {
      for (let k = 0; k < 4; k++) {
        const [u, v] = quad(8);
        const along = R() < 0.5;
        solid(along ? [7, 3, 1.6] : [1.6, 3, 7], [u, 1.5, v], def.wall);
      }
      break;
    }
    case "boss": {
      for (const [u, v] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
        solid([4.5, WALL_H + 5, 4.5], [u * q * 0.62, (WALL_H + 5) / 2, v * q * 0.62], def.trim);
        zone.part({ size: [1.6, 1.6, 1.6], pos: [r.x + u * q * 0.62, WALL_H + 6, r.z + v * q * 0.62], color: def.torch, material: "neon", collide: false, studs: false }, i);
      }
      const [ex, ez] = DIRS[r.entry];
      const tx = -ex * (q - 3), tz = -ez * (q - 3);
      const along = ex !== 0;
      zone.part({ size: along ? [4, 9, 9] : [9, 9, 4], pos: [r.x + tx, 4.5, r.z + tz], color: def.accent, studs: false }, i);
      zone.part({ size: along ? [6, 1, 12] : [12, 1, 6], pos: [r.x + tx * 0.93, 0.5, r.z + tz * 0.93], color: def.trim }, i);
      zone.part({ size: [26, 0.12, 26], pos: [r.x, 0.12, r.z], color: def.trim, collide: false, shadow: false, studs: false }, i);
      break;
    }
  }
}
