// Survival Island: things players build on the grid (walls, floors, doors, campfires...).
import { THREE } from "../kit3d.js";
import { PIECES } from "./items.js";
import { CELL, idx, cellOf, cellCenter } from "./gen.js";

const matCache = new Map();
function lambert(color) {
  const key = "l" + color;
  if (!matCache.has(key)) matCache.set(key, new THREE.MeshLambertMaterial({ color }));
  return matCache.get(key);
}
function basic(color) {
  const key = "b" + color;
  if (!matCache.has(key)) matCache.set(key, new THREE.MeshBasicMaterial({ color }));
  return matCache.get(key);
}
const BOX = new THREE.BoxGeometry(1, 1, 1);
const FLAT = new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2);
let GLOW_TEX = null;
function glowTexture() {
  if (GLOW_TEX) return GLOW_TEX;
  const c = document.createElement("canvas");
  c.width = c.height = 64;
  const g = c.getContext("2d");
  const grad = g.createRadialGradient(32, 32, 0, 32, 32, 32);
  grad.addColorStop(0, "rgba(255,255,255,1)"); grad.addColorStop(0.45, "rgba(255,255,255,.45)"); grad.addColorStop(1, "rgba(255,255,255,0)");
  g.fillStyle = grad; g.fillRect(0, 0, 64, 64);
  GLOW_TEX = new THREE.CanvasTexture(c);
  GLOW_TEX.colorSpace = THREE.SRGBColorSpace;
  return GLOW_TEX;
}
const glowMats = new Map();
function glowMat(color) {
  if (!glowMats.has(color)) glowMats.set(color, new THREE.MeshBasicMaterial({ map: glowTexture(), color, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0.2 }));
  return glowMats.get(color);
}
function box(group, sx, sy, sz, x, y, z, mat, shadow) {
  const m = new THREE.Mesh(BOX, mat);
  m.scale.set(sx, sy, sz);
  m.position.set(x, y, z);
  m.castShadow = shadow !== false;
  m.receiveShadow = true;
  group.add(m);
  return m;
}

// Size of a piece after rotation (x and z swap for odd rotations).
export function rotatedSize(type, rot) {
  const s = PIECES[type].size;
  return rot % 2 ? [s[2], s[1], s[0]] : s.slice();
}

const PICK = { torch: [1.4, 3.6, 1.4], lamp: [2, 4, 2], campfire: [3.6, 1.6, 3.6], chest: [3.4, 2.4, 3.4], bed: [3.8, 1.6, 3.8], workbench: [3.8, 2.6, 3.8] };

export class Builds {
  constructor(world, island) {
    this.world = world;
    this.island = island;
    this.byId = new Map();
    this.byCell = new Map();
    this.lights = [];
    this.flames = [];
  }

  clear() {
    for (const b of [...this.byId.values()]) this.remove(b.id);
  }

  inCell(i, k) { return this.byCell.get(idx(i, k)) || []; }

  // Highest surface (terrain or solid build top) at or below y in the column under x, z.
  groundAt(x, z, y, solidOnly) {
    const i = cellOf(x), k = cellOf(z);
    let best = this.island.top(i, k);
    for (const b of this.inCell(i, k)) {
      if ((solidOnly !== false && !this.isSolid(b)) || b.top > y + 0.01) continue;
      if (b.top > best) best = b.top;
    }
    return best;
  }

  isSolid(b) { return PIECES[b.type].solid && !(PIECES[b.type].door && b.open); }

  // Is anything solid in this column between y0 and y1? (used to stop monsters walking through walls)
  blocked(x, z, y0, y1) {
    const i = cellOf(x), k = cellOf(z);
    if (this.island.top(i, k) > y0) return true;
    const rf = this.island.roof(i, k);
    if (rf && rf[0] < y1 && rf[1] > y0) return true;
    for (const b of this.inCell(i, k)) if (this.isSolid(b) && b.y < y1 && b.top > y0) return true;
    return false;
  }

  // Where would a piece go if the player aims at point p with surface normal n?
  placement(type, rot, p, n) {
    const qx = p.x + n.x * 0.6, qy = p.y + n.y * 0.6, qz = p.z + n.z * 0.6;
    const i = cellOf(qx), k = cellOf(qz);
    const y = this.groundAt(qx, qz, qy + 0.3, true);
    const h = PIECES[type].size[1];
    let ok = y < 80 && y > -15;
    for (const b of this.inCell(i, k)) if (b.y < y + h - 0.01 && y < b.top - 0.01) ok = false;
    const rf = this.island.roof(i, k);
    if (rf && rf[0] < y + h && rf[1] > y) ok = false;
    if (this.byId.size >= 900) ok = false;
    return { type, i, k, y, rot, ok, x: cellCenter(i), z: cellCenter(k), h };
  }

  // Ray against build boxes. Returns { t, b, normal } or null.
  raycast(ray, maxT) {
    let best = null;
    const box3 = new THREE.Box3(), hit = new THREE.Vector3();
    for (const b of this.byId.values()) {
      this.pickBox(b, box3);
      if (!ray.intersectBox(box3, hit)) continue;
      const t = hit.distanceTo(ray.origin);
      if (t > maxT || (best && t >= best.t)) continue;
      best = { t, b, point: hit.clone(), normal: boxNormal(box3, hit) };
    }
    return best;
  }

  pickBox(b, out) {
    const ps = PICK[b.type];
    if (ps) {
      const [sx, sy, sz] = b.rot % 2 ? [ps[2], ps[1], ps[0]] : ps;
      out.min.set(b.x - sx / 2, b.y, b.z - sz / 2);
      out.max.set(b.x + sx / 2, b.y + sy, b.z + sz / 2);
    } else {
      out.min.set(b.x - CELL / 2, b.y, b.z - CELL / 2);
      out.max.set(b.x + CELL / 2, b.top, b.z + CELL / 2);
    }
    if (PIECES[b.type].door) {
      const t = 0.5;
      if (b.rot % 2) { out.min.x = b.x - t; out.max.x = b.x + t; } else { out.min.z = b.z - t; out.max.z = b.z + t; }
      if (b.open) {
        // open door swings to the side
        if (b.rot % 2) { out.min.x = b.x - t; out.max.x = b.x + CELL / 2; out.min.z = b.z - CELL / 2; out.max.z = b.z - CELL / 2 + 1; }
        else { out.min.x = b.x - CELL / 2; out.max.x = b.x - CELL / 2 + 1; out.min.z = b.z - t; out.max.z = b.z + CELL / 2; }
      }
    }
    return out;
  }

  // b = { id, type, i, k, y, rot, owner, open, items }
  add(data) {
    if (this.byId.has(data.id) || !PIECES[data.type]) return null;
    const def = PIECES[data.type];
    const b = Object.assign({ open: false, items: null }, data);
    b.x = cellCenter(b.i); b.z = cellCenter(b.k);
    b.top = b.y + def.size[1];
    if (b.type === "chest" && !b.items) b.items = {};
    const w = this.world;
    const [sx, sy, sz] = rotatedSize(b.type, b.rot);
    const cy = b.y + sy / 2;
    const ry = (b.rot * Math.PI) / 2;
    b.parts = [];
    const solidPart = (size, pos, visible) => {
      const p = w.part({ size, pos, color: "#000000", studs: false, shadow: false });
      p.visible = !!visible;
      b.parts.push(p);
      return p;
    };
    const g = new THREE.Group();
    g.position.set(b.x, b.y, b.z);
    g.rotation.y = ry;
    switch (b.type) {
      case "wood_floor":
        b.parts.push(w.part({ size: [sx, sy, sz], pos: [b.x, cy, b.z], color: "#c99a5b", material: "wood" }));
        break;
      case "wood_wall":
        b.parts.push(w.part({ size: [sx, sy, sz], pos: [b.x, cy, b.z], color: "#a0703c", material: "wood" }));
        break;
      case "stone_wall":
        b.parts.push(w.part({ size: [sx, sy, sz], pos: [b.x, cy, b.z], color: "#8d9096" }));
        break;
      case "workbench": {
        box(g, 3.8, 0.6, 3.8, 0, 2.3, 0, lambert("#c99a5b"));
        for (const [lx, lz] of [[-1.5, -1.5], [1.5, -1.5], [-1.5, 1.5], [1.5, 1.5]]) box(g, 0.6, 2, 0.6, lx, 1, lz, lambert("#8b5a2b"));
        box(g, 3.2, 0.3, 3.2, 0, 0.8, 0, lambert("#8b5a2b"));
        box(g, 1.1, 0.7, 0.8, -0.9, 2.95, -0.8, lambert("#6b7280"));
        box(g, 1.6, 0.15, 0.5, 0.8, 2.68, 0.7, lambert("#d1d5db"));
        box(g, 0.3, 0.3, 1.2, 1.2, 2.75, -0.6, lambert("#7c4a21"));
        solidPart([3.8, 2.6, 3.8], [b.x, b.y + 1.3, b.z]);
        break;
      }
      case "chest":
        box(g, 3.2, 1.7, 2.4, 0, 0.85, 0, lambert("#a0703c"));
        box(g, 3.3, 0.6, 2.5, 0, 2.0, 0, lambert("#c99a5b"));
        box(g, 3.32, 0.2, 2.52, 0, 1.7, 0, lambert("#57534e"));
        box(g, 0.6, 0.7, 0.2, 0, 1.6, -1.3, lambert("#facc15"));
        solidPart(b.rot % 2 ? [2.4, 2.3, 3.2] : [3.2, 2.3, 2.4], [b.x, b.y + 1.15, b.z]);
        break;
      case "bed":
        box(g, 3.6, 0.7, 3.8, 0, 0.35, 0, lambert("#8b5a2b"));
        box(g, 3.4, 0.5, 3.6, 0, 0.95, 0, lambert("#f5f5f4"));
        box(g, 3.5, 0.55, 2.4, 0, 1.05, 0.65, lambert("#dc2626"));
        box(g, 2.4, 0.4, 0.9, 0, 1.35, -1.25, lambert("#ffffff"));
        box(g, 3.6, 1.4, 0.4, 0, 0.9, -1.9, lambert("#7c4a21"));
        solidPart(b.rot % 2 ? [3.8, 1.3, 3.6] : [3.6, 1.3, 3.8], [b.x, b.y + 0.65, b.z]);
        break;
      case "wood_door": {
        const hinge = new THREE.Group();
        hinge.position.set(-2, 0, 0);
        const panel = box(hinge, 4, 6, 0.6, 2, 3, 0, lambert("#8b5a2b"));
        box(hinge, 3.2, 2.2, 0.7, 2, 4.2, 0, lambert("#a0703c"), false);
        box(hinge, 3.2, 2.2, 0.7, 2, 1.6, 0, lambert("#a0703c"), false);
        box(hinge, 0.4, 0.4, 1, 3.4, 3, 0, lambert("#facc15"), false);
        panel.userData.door = true;
        g.add(hinge);
        b.hinge = hinge;
        b.doorPart = solidPart(b.rot % 2 ? [0.6, 6, 4] : [4, 6, 0.6], [b.x, b.y + 3, b.z]);
        break;
      }
      case "campfire": {
        box(g, 3.2, 0.5, 0.7, 0, 0.3, 0, lambert("#7c4a21"));
        box(g, 0.7, 0.5, 3.2, 0, 0.55, 0, lambert("#8b5a2b"));
        for (let a = 0; a < 7; a++) { const an = (a / 7) * Math.PI * 2; box(g, 0.8, 0.6, 0.8, Math.cos(an) * 1.7, 0.3, Math.sin(an) * 1.7, lambert("#6b7280")); }
        const f1 = box(g, 1.2, 1.4, 1.2, 0, 1.3, 0, basic("#f97316"), false);
        const f2 = box(g, 0.7, 1.0, 0.7, 0.1, 1.5, 0.1, basic("#fde047"), false);
        this.flames.push(f1, f2);
        b.flames = [f1, f2];
        b.light = { glow: "#ff8a30", range: 30 };
        break;
      }
      case "torch": {
        box(g, 0.45, 2.6, 0.45, 0, 1.3, 0, lambert("#8b5a2b"));
        const f = box(g, 0.75, 0.8, 0.75, 0, 2.95, 0, basic("#fb923c"), false);
        const f2 = box(g, 0.4, 0.5, 0.4, 0, 3.15, 0, basic("#fde047"), false);
        this.flames.push(f, f2);
        b.flames = [f, f2];
        b.light = { glow: "#ff9a40", range: 20 };
        break;
      }
      case "lamp": {
        box(g, 1.6, 0.4, 1.6, 0, 0.2, 0, lambert("#9ca3af"));
        box(g, 0.4, 2.4, 0.4, 0, 1.6, 0, lambert("#9ca3af"));
        const c = box(g, 1.0, 1.4, 1.0, 0, 3.3, 0, basic("#5eead4"), false);
        c.rotation.y = Math.PI / 4;
        b.light = { glow: "#5eead4", range: 36 };
        break;
      }
    }
    if (b.light) {
      // light shows as a soft glow on the ground (no real-time lights: too slow in software rendering)
      const glow = new THREE.Mesh(FLAT, glowMat(b.light.glow));
      glow.scale.set(b.light.range, 1, b.light.range);
      glow.position.set(0, 0.12, 0);
      glow.renderOrder = 2;
      g.add(glow);
    }
    if (g.children.length) { this.world.scene.add(g); b.group = g; }
    if (b.light) this.lights.push(b);
    this.byId.set(b.id, b);
    const key = idx(b.i, b.k);
    if (!this.byCell.has(key)) this.byCell.set(key, []);
    this.byCell.get(key).push(b);
    if (b.open) this.setDoor(b, true);
    return b;
  }

  remove(id) {
    const b = this.byId.get(id);
    if (!b) return null;
    for (const p of b.parts) this.world.remove(p);
    if (b.group) this.world.scene.remove(b.group);
    if (b.flames) this.flames = this.flames.filter((f) => !b.flames.includes(f));
    this.lights = this.lights.filter((l) => l !== b);
    this.byId.delete(id);
    const list = this.byCell.get(idx(b.i, b.k));
    if (list) { list.splice(list.indexOf(b), 1); if (!list.length) this.byCell.delete(idx(b.i, b.k)); }
    return b;
  }

  setDoor(b, open) {
    b.open = !!open;
    if (b.hinge) b.hinge.rotation.y = open ? -Math.PI / 2 : 0;
    const solids = this.world.solids;
    const i = solids.indexOf(b.doorPart);
    if (open && i >= 0) solids.splice(i, 1);
    if (!open && i < 0) solids.push(b.doorPart);
  }

  setGlow(level) {
    for (const m of glowMats.values()) m.opacity = level * 0.75;
  }

  animate(t) {
    this.flames.forEach((f, n) => {
      if (!f.userData.base) f.userData.base = f.scale.y;
      f.scale.y = f.userData.base * (1 + Math.sin(t * 13 + n * 1.7) * 0.14 + Math.sin(t * 7.3 + n) * 0.08);
    });
  }

  // Compact form for saving / sending: [id, typeIndex, i, k, y, rot, owner, open, items]
  serialize(b, typeIndex) {
    const out = [b.id, typeIndex, b.i, b.k, b.y, b.rot, b.owner];
    if (b.open || (b.items && Object.keys(b.items).length)) out.push(b.open ? 1 : 0);
    if (b.items && Object.keys(b.items).length) out.push(b.items);
    return out;
  }
}

function boxNormal(box3, p) {
  const e = 0.02;
  if (Math.abs(p.y - box3.max.y) < e) return new THREE.Vector3(0, 1, 0);
  if (Math.abs(p.y - box3.min.y) < e) return new THREE.Vector3(0, -1, 0);
  if (Math.abs(p.x - box3.max.x) < e) return new THREE.Vector3(1, 0, 0);
  if (Math.abs(p.x - box3.min.x) < e) return new THREE.Vector3(-1, 0, 0);
  if (Math.abs(p.z - box3.max.z) < e) return new THREE.Vector3(0, 0, 1);
  return new THREE.Vector3(0, 0, -1);
}
export { boxNormal };
