// Survival Island: draws the generated island (terrain, water, resources) and keeps a small pool of
// invisible kit parts around the player so the kit's physics can walk on the heightmap.
import { THREE } from "../kit3d.js";
import { CELL, N, OFF, WATER_Y, FLOOR_MIN, SEABED, SAND, GRASS, FOREST, ROCK, CAVE, RES, idx, cellOf, cellCenter, generate, hash } from "./gen.js";

let STUD = null;
function studTexture() {
  if (STUD) return STUD;
  const c = document.createElement("canvas");
  c.width = c.height = 32;
  const g = c.getContext("2d");
  g.fillStyle = "#fff"; g.fillRect(0, 0, 32, 32);
  g.fillStyle = "rgba(0,0,0,.13)"; g.beginPath(); g.arc(16.5, 17, 9.5, 0, 7); g.fill();
  const grad = g.createRadialGradient(14, 14, 2, 16, 16, 10);
  grad.addColorStop(0, "#ffffff"); grad.addColorStop(1, "#d6d6d6");
  g.fillStyle = grad; g.beginPath(); g.arc(16, 16, 9, 0, 7); g.fill();
  g.strokeStyle = "rgba(0,0,0,.07)"; g.lineWidth = 1; g.strokeRect(0, 0, 32, 32);
  STUD = new THREE.CanvasTexture(c);
  STUD.wrapS = STUD.wrapT = THREE.RepeatWrapping;
  STUD.colorSpace = THREE.SRGBColorSpace;
  return STUD;
}

const TOP_COL = { [SEABED]: "#c9b27a", [SAND]: "#ead38f", [GRASS]: "#5cab45", [FOREST]: "#43923a", [ROCK]: "#8e9298", [CAVE]: "#62656c" };
const SIDE_COL = { [SEABED]: "#b89e66", [SAND]: "#d4b978", [GRASS]: "#8a6239", [FOREST]: "#7c5733", [ROCK]: "#767a80", [CAVE]: "#55585e" };
const DEEP = new THREE.Color("#1f5876");

class GeoBuf {
  constructor(uv) { this.p = []; this.n = []; this.c = []; this.u = uv ? [] : null; }
  // v = 4 corners; n = outward normal; uvs optional 4 pairs
  quad(v, n, col, uvs) {
    let a = v[0], b = v[1], c = v[2], d = v[3];
    let ua = uvs && uvs[0], ub = uvs && uvs[1], uc = uvs && uvs[2], ud = uvs && uvs[3];
    const e1 = [b[0] - a[0], b[1] - a[1], b[2] - a[2]], e2 = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
    const cr = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]];
    if (cr[0] * n[0] + cr[1] * n[1] + cr[2] * n[2] < 0) { [b, d] = [d, b]; [ub, ud] = [ud, ub]; }
    for (const [vv, uu] of [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]) {
      this.p.push(vv[0], vv[1], vv[2]);
      this.n.push(n[0], n[1], n[2]);
      this.c.push(col.r, col.g, col.b);
      if (this.u) this.u.push(uu ? uu[0] : 0, uu ? uu[1] : 0);
    }
  }
  geometry() {
    const g = new THREE.BufferGeometry();
    g.setAttribute("position", new THREE.Float32BufferAttribute(this.p, 3));
    g.setAttribute("normal", new THREE.Float32BufferAttribute(this.n, 3));
    g.setAttribute("color", new THREE.Float32BufferAttribute(this.c, 3));
    if (this.u) g.setAttribute("uv", new THREE.Float32BufferAttribute(this.u, 2));
    return g;
  }
}

// Each resource is drawn as a few boxes of one big InstancedMesh.
function components(r) {
  const out = [];
  const add = (x, y, z, sx, sy, sz, color, glow, ry, tx, tz) => out.push({ x, y, z, sx, sy, sz, color, glow: !!glow, ry: ry || 0, tx: tx || 0, tz: tz || 0 });
  const v = hash(r.i, r.k, 77);
  const leaf = new THREE.Color("#3f9a3a").offsetHSL((v - 0.5) * 0.05, 0, (v - 0.5) * 0.08);
  switch (r.type) {
    case "tree":
      add(0, 4, 0, 1.6, 8, 1.6, "#7a5230");
      add(0, 9, 0, 6.6, 4, 6.6, "#" + leaf.getHexString());
      add(0, 11.9, 0, 4.2, 2.6, 4.2, "#" + leaf.clone().offsetHSL(0, 0, 0.06).getHexString());
      break;
    case "palm":
      add(0, 4.6, 0, 1.1, 9.2, 1.1, "#a8814f", false, 0, 0.06, 0);
      add(0.4, 9.4, 0, 8.5, 0.5, 1.8, "#4caf50", false, 0, 0, 0.18);
      add(0.4, 9.4, 0, 1.8, 0.5, 8.5, "#43a047", false, 0, 0.18, 0);
      add(0.4, 9.1, 0, 1.6, 1, 1.6, "#6d4c2f");
      break;
    case "bush":
      add(0, 1.2, 0, 3.4, 2.4, 3.4, "#2e7d32");
      add(0, 2.5, 0, 2.2, 0.6, 2.2, "#388e3c");
      add(1.75, 1.6, 0.6, 0.6, 0.6, 0.6, "#e11d48");
      add(-0.7, 1.3, 1.75, 0.6, 0.6, 0.6, "#e11d48");
      add(-1.75, 1.9, -0.5, 0.6, 0.6, 0.6, "#be123c");
      add(0.5, 2.85, -0.4, 0.6, 0.6, 0.6, "#e11d48");
      break;
    case "rock":
      add(0, 1.2, 0, 3.4, 2.4, 3.0, "#8d9096");
      add(0.5, 2.6, 0.3, 2.0, 1.2, 1.8, "#9ea2a8");
      break;
    case "iron": case "gold": {
      const nug = r.type === "iron" ? "#d9a066" : "#facc15";
      add(0, 1.3, 0, 3.4, 2.6, 3.2, "#666a71");
      add(0.3, 2.8, 0.2, 2.0, 1.0, 1.8, "#71757c");
      add(1.6, 1.6, 0.5, 0.9, 0.9, 0.9, nug, r.type === "gold");
      add(-0.6, 2.0, 1.55, 0.9, 0.9, 0.9, nug, r.type === "gold");
      add(-1.6, 1.0, -0.8, 0.9, 0.9, 0.9, nug, r.type === "gold");
      add(0.6, 3.3, -0.3, 0.7, 0.7, 0.7, nug, r.type === "gold");
      break;
    }
    case "crystal":
      add(0, 0.4, 0, 2.6, 0.8, 2.6, "#4b4f57");
      add(0, 2.0, 0, 0.9, 3.4, 0.9, "#5eead4", true, 0.3, 0.12, 0.05);
      add(0.8, 1.5, 0.4, 0.7, 2.4, 0.7, "#67e8f9", true, 0.9, -0.1, 0.3);
      add(-0.7, 1.3, -0.3, 0.6, 2.0, 0.6, "#99f6e4", true, 0.5, 0.3, -0.25);
      break;
  }
  return out;
}

export class Island {
  constructor(world, seed) {
    this.world = world;
    this.map = generate(seed);
    this.seed = seed;
    this.group = new THREE.Group();
    world.scene.add(this.group);
    this.pools = {};
    this.shaking = [];
    this.growing = [];
    this.buildTerrain();
    this.buildWater();
    this.buildResources();
    this.lastCell = -1;
  }

  dispose() {
    this.world.scene.remove(this.group);
    this.group.traverse((o) => { if (o.geometry) o.geometry.dispose(); });
    for (const list of Object.values(this.pools)) for (const p of list) this.world.remove(p);
    this.pools = {};
  }

  // ---------------------------------------------------------------- queries

  top(i, k) {
    if (i < 0 || k < 0 || i >= N || k >= N) return FLOOR_MIN;
    return this.map.H[idx(i, k)];
  }
  topAt(x, z) { return this.top(cellOf(x), cellOf(z)); }
  kindAt(x, z) {
    const i = cellOf(x), k = cellOf(z);
    if (i < 0 || k < 0 || i >= N || k >= N) return SEABED;
    return this.map.K[idx(i, k)];
  }
  roof(i, k) {
    if (i < 0 || k < 0 || i >= N || k >= N) return null;
    const id = idx(i, k);
    return this.map.roofB[id] > -999 ? [this.map.roofB[id], this.map.roofT[id]] : null;
  }
  // true if the point is inside terrain or a cave roof
  solidAt(x, y, z) {
    const i = cellOf(x), k = cellOf(z);
    if (y < this.top(i, k)) return true;
    const r = this.roof(i, k);
    return !!(r && y >= r[0] && y < r[1]);
  }

  // ---------------------------------------------------------------- terrain mesh

  buildTerrain() {
    const { H, K } = this.map;
    const tops = new GeoBuf(true), sides = new GeoBuf(false), roofs = new GeoBuf(true);
    const col = new THREE.Color();
    const side = new THREE.Color();
    const lip = new THREE.Color();
    const DIR = [[1, 0], [-1, 0], [0, 1], [0, -1]];
    for (let k = 0; k < N; k++) for (let i = 0; i < N; i++) {
      const id = idx(i, k), h = H[id], kind = K[id];
      const x0 = i * CELL - OFF, x1 = x0 + CELL, z0 = k * CELL - OFF, z1 = z0 + CELL;
      const v = hash(i, k, 5) - 0.5;
      col.set(TOP_COL[kind]).offsetHSL(0, 0, v * 0.05);
      if (kind === SEABED) col.lerp(DEEP, Math.min(1, Math.max(0, -h / 9)));
      if ((kind === GRASS || kind === FOREST) && h >= 11) col.offsetHSL(0.02, -0.05, 0.05);
      tops.quad([[x0, h, z0], [x1, h, z0], [x1, h, z1], [x0, h, z1]], [0, 1, 0], col, [[0, 0], [4, 0], [4, 4], [0, 4]]);
      side.set(SIDE_COL[kind]).offsetHSL(0, 0, v * 0.04);
      if (kind === SEABED) side.lerp(DEEP, Math.min(1, Math.max(0, -h / 9)));
      lip.copy(col).offsetHSL(0, 0, -0.04);
      for (const [dx, dz] of DIR) {
        const nh = this.top(i + dx, k + dz);
        if (nh >= h) continue;
        const lo = Math.max(nh, FLOOR_MIN);
        const ex = dx === 1 ? x1 : dx === -1 ? x0 : null;
        const ez = dz === 1 ? z1 : dz === -1 ? z0 : null;
        const face = (y0, y1, c) => {
          if (ex !== null) sides.quad([[ex, y0, z0], [ex, y0, z1], [ex, y1, z1], [ex, y1, z0]], [dx, 0, 0], c);
          else sides.quad([[x0, y0, ez], [x1, y0, ez], [x1, y1, ez], [x0, y1, ez]], [0, 0, dz], c);
        };
        if ((kind === GRASS || kind === FOREST) && h - lo > 0.6) { face(h - 0.45, h, lip); face(lo, h - 0.45, side); }
        else face(lo, h, side);
      }
      // cave roof slab
      const rf = this.roof(i, k);
      if (rf) {
        const [b, t] = rf;
        col.set(TOP_COL[ROCK]).offsetHSL(0, 0, v * 0.05);
        roofs.quad([[x0, t, z0], [x1, t, z0], [x1, t, z1], [x0, t, z1]], [0, 1, 0], col, [[0, 0], [4, 0], [4, 4], [0, 4]]);
        side.set(SIDE_COL[ROCK]).offsetHSL(0, 0, -0.08);
        roofs.quad([[x0, b, z0], [x1, b, z0], [x1, b, z1], [x0, b, z1]], [0, -1, 0], side);
        for (const [dx, dz] of DIR) {
          if (this.roof(i + dx, k + dz)) continue;
          const nh = this.top(i + dx, k + dz);
          if (nh >= t) continue;
          const y0 = Math.max(b, nh);
          const ex = dx === 1 ? x1 : dx === -1 ? x0 : null;
          const ez = dz === 1 ? z1 : dz === -1 ? z0 : null;
          if (ex !== null) roofs.quad([[ex, y0, z0], [ex, y0, z1], [ex, t, z1], [ex, t, z0]], [dx, 0, 0], side);
          else roofs.quad([[x0, y0, ez], [x1, y0, ez], [x1, t, ez], [x0, t, ez]], [0, 0, dz], side);
        }
      }
    }
    const tex = studTexture();
    const topMesh = new THREE.Mesh(tops.geometry(), new THREE.MeshLambertMaterial({ vertexColors: true, map: tex }));
    const sideMesh = new THREE.Mesh(sides.geometry(), new THREE.MeshLambertMaterial({ vertexColors: true }));
    topMesh.receiveShadow = sideMesh.receiveShadow = true;
    this.group.add(topMesh, sideMesh);
    if (roofs.p.length) {
      const roofMesh = new THREE.Mesh(roofs.geometry(), new THREE.MeshLambertMaterial({ vertexColors: true, map: tex }));
      roofMesh.castShadow = roofMesh.receiveShadow = true;
      this.group.add(roofMesh);
    }
    this.terrainMeshes = [topMesh, sideMesh];
  }

  buildWater() {
    const water = new THREE.Mesh(new THREE.PlaneGeometry(2400, 2400), new THREE.MeshLambertMaterial({ color: "#2f8fd6", transparent: true, opacity: 0.62, depthWrite: false }));
    water.rotation.x = -Math.PI / 2;
    water.position.y = WATER_Y;
    water.renderOrder = 2;
    const floor = new THREE.Mesh(new THREE.PlaneGeometry(2400, 2400), new THREE.MeshBasicMaterial({ color: "#1b4f6b" }));
    floor.rotation.x = -Math.PI / 2;
    floor.position.y = FLOOR_MIN + 1.5;
    this.water = water;
    this.group.add(water, floor);
  }

  // ---------------------------------------------------------------- resources

  buildResources() {
    const list = this.map.res;
    const solid = [], glow = [];
    for (const r of list) {
      const def = RES[r.type];
      r.def = def; r.hp = def.hp; r.alive = true; r.comps = [];
      for (const c of components(r)) (c.glow ? glow : solid).push([r, c]);
    }
    const box = new THREE.BoxGeometry(1, 1, 1);
    const make = (items, mat) => {
      const mesh = new THREE.InstancedMesh(box, mat, Math.max(1, items.length));
      const m = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(), p = new THREE.Vector3(), s = new THREE.Vector3(), color = new THREE.Color();
      items.forEach(([r, c], n) => {
        const cos = Math.cos(r.rot), sin = Math.sin(r.rot);
        const sc = r.s;
        p.set(r.x + (c.x * cos + c.z * sin) * sc, r.y + c.y * sc, r.z + (-c.x * sin + c.z * cos) * sc);
        e.set(c.tx, r.rot + c.ry, c.tz);
        q.setFromEuler(e);
        s.set(c.sx * sc, c.sy * sc, c.sz * sc);
        m.compose(p, q, s);
        mesh.setMatrixAt(n, m);
        mesh.setColorAt(n, color.set(c.color));
        r.comps.push({ mesh, n, base: m.clone() });
      });
      mesh.count = items.length;
      mesh.castShadow = mat.type !== "MeshBasicMaterial";
      mesh.receiveShadow = true;
      mesh.instanceMatrix.needsUpdate = true;
      if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
      this.group.add(mesh);
      return mesh;
    };
    this.resSolid = make(solid, new THREE.MeshLambertMaterial({ color: "#ffffff" }));
    this.resGlow = make(glow, new THREE.MeshBasicMaterial({ color: "#ffffff" }));
    this.resByCell = new Map();
    for (const r of list) this.resByCell.set(idx(r.i, r.k), r);
  }

  setResource(r, alive, grow) {
    r.alive = alive;
    r.hp = r.def.hp;
    const zero = new THREE.Matrix4().makeScale(0, 0, 0);
    for (const c of r.comps) { c.mesh.setMatrixAt(c.n, alive && !grow ? c.base : zero); c.mesh.instanceMatrix.needsUpdate = true; }
    if (alive && grow) this.growing.push({ r, t: 0 });
    this.lastCell = -1;  // colliders need a refresh
  }

  shake(r) { if (!this.shaking.find((s) => s.r === r)) this.shaking.push({ r, t: 0 }); else this.shaking.find((s) => s.r === r).t = 0; }

  animate(dt) {
    const m = new THREE.Matrix4(), off = new THREE.Matrix4(), sc = new THREE.Matrix4();
    for (let j = this.shaking.length - 1; j >= 0; j--) {
      const s = this.shaking[j];
      s.t += dt;
      const done = s.t > 0.3 || !s.r.alive;
      const a = done ? 0 : Math.sin(s.t * 60) * 0.35 * (1 - s.t / 0.3);
      if (s.r.alive) for (const c of s.r.comps) {
        off.makeTranslation(a * Math.cos(s.r.rot), 0, a * Math.sin(s.r.rot));
        m.multiplyMatrices(off, c.base);
        c.mesh.setMatrixAt(c.n, m);
        c.mesh.instanceMatrix.needsUpdate = true;
      }
      if (done) this.shaking.splice(j, 1);
    }
    for (let j = this.growing.length - 1; j >= 0; j--) {
      const g = this.growing[j];
      g.t += dt * 2;
      const f = Math.min(1, g.t);
      const ease = 1 - Math.pow(1 - f, 3);
      for (const c of g.r.comps) {
        // grow from the ground up around the resource's base
        const bx = g.r.x, by = g.r.y, bz = g.r.z;
        off.makeTranslation(bx, by, bz);
        sc.makeScale(ease, ease, ease);
        m.makeTranslation(-bx, -by, -bz);
        const out = new THREE.Matrix4().multiplyMatrices(off, sc).multiply(m).multiply(c.base);
        c.mesh.setMatrixAt(c.n, g.r.alive ? out : new THREE.Matrix4().makeScale(0, 0, 0));
        c.mesh.instanceMatrix.needsUpdate = true;
      }
      if (f >= 1 || !g.r.alive) this.growing.splice(j, 1);
    }
  }

  // Box used for clicking a resource.
  pickBox(r, out) {
    const [sx, sy, sz] = r.def.pick;
    const s = r.s;
    out.min.set(r.x - (sx * s) / 2, r.y, r.z - (sz * s) / 2);
    out.max.set(r.x + (sx * s) / 2, r.y + sy * s, r.z + (sz * s) / 2);
    return out;
  }

  resourcesNear(x, z, radius) {
    const out = [];
    const r = Math.ceil(radius / CELL);
    const ci = cellOf(x), ck = cellOf(z);
    for (let dk = -r; dk <= r; dk++) for (let di = -r; di <= r; di++) {
      const res = this.resByCell.get(idx(ci + di, ck + dk));
      if (res && res.alive && Math.hypot(res.x - x, res.z - z) <= radius) out.push(res);
    }
    return out;
  }

  // ---------------------------------------------------------------- colliders for the kit physics

  poolPart(name, size, n) {
    const pool = this.pools[name] || (this.pools[name] = []);
    while (pool.length <= n) {
      const part = this.world.part({ size, pos: [0, -500, 0], color: "#000000", studs: false, shadow: false });
      part.visible = false;
      pool.push(part);
    }
    return pool[n];
  }

  updateColliders(x, z, force) {
    const ci = cellOf(x), ck = cellOf(z);
    const key = ci * 1000 + ck;
    if (!force && key === this.lastCell) return;
    this.lastCell = key;
    const used = {};
    const put = (name, size, px, py, pz) => {
      const n = used[name] || 0;
      used[name] = n + 1;
      const part = this.poolPart(name, size, n);
      part.position.set(px, py, pz);
      this.world.updateBox(part);
    };
    for (let dk = -3; dk <= 3; dk++) for (let di = -3; di <= 3; di++) {
      const i = ci + di, k = ck + dk;
      const t = this.top(i, k);
      put("ground", [CELL, 40, CELL], cellCenter(i), t - 20, cellCenter(k));
      const rf = this.roof(i, k);
      if (rf) put("roof", [CELL, 2, CELL], cellCenter(i), rf[0] + 1, cellCenter(k));
    }
    for (const r of this.resourcesNear(x, z, 18)) {
      if (!r.def.solid) continue;
      const [sx, sy, sz] = r.def.solid;
      put("res-" + r.type, [sx, sy, sz], r.x, r.y + sy / 2, r.z);
    }
    for (const [name, pool] of Object.entries(this.pools)) {
      for (let n = used[name] || 0; n < pool.length; n++) {
        if (pool[n].position.y === -500) continue;
        pool[n].position.set(0, -500, 0);
        this.world.updateBox(pool[n]);
      }
    }
  }
}

export { CELL, N, OFF, WATER_Y, FLOOR_MIN, RES, idx, cellOf, cellCenter };
