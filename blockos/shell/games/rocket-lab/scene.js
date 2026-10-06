// Rocket Lab 3D: the launch site (near scene, in studs, from the kit's World) and space
// (far scene, in kilometers, drawn first): Earth, its glowing air, stars, the Sun and the Moon.
import { World, THREE, createCharacter } from "../kit3d.js";
import { PARTS, R_EARTH, STUDS_PER_M } from "./physics.js";

const S = STUDS_PER_M;
export const PAD_TOP = 3;                       // studs: the top of a launch pad
export const SLOT_X = [0, 70, -70, 140, -140, 210, -210, 280, -280];

// ------------------------------------------------------------------ small helpers

const matCache = new Map();
function lam(color, extra) {
  const key = color + (extra ? JSON.stringify(extra) : "");
  if (!matCache.has(key)) matCache.set(key, new THREE.MeshLambertMaterial(Object.assign({ color }, extra || {})));
  return matCache.get(key);
}
function basic(color, extra) {
  const key = "b" + color + (extra ? JSON.stringify(extra) : "");
  if (!matCache.has(key)) matCache.set(key, new THREE.MeshBasicMaterial(Object.assign({ color }, extra || {})));
  return matCache.get(key);
}
function boxMesh(w, h, d, material, x, y, z) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
  m.position.set(x || 0, y || 0, z || 0);
  m.castShadow = true;
  m.receiveShadow = true;
  return m;
}
const lerp = (a, b, t) => a + (b - a) * t;
const clamp01 = (t) => Math.max(0, Math.min(1, t));

// Sky color by altitude (m): blue near the ground, deep blue, then black in space.
const SKY = [[0, [143, 211, 255]], [8000, [100, 170, 240]], [18000, [58, 115, 205]], [32000, [28, 60, 140]], [50000, [12, 26, 70]], [75000, [4, 8, 26]], [110000, [1, 2, 8]]];
export function skyColor(h) {
  let i = 0;
  while (i < SKY.length - 2 && SKY[i + 1][0] <= h) i++;
  const a = SKY[i], b = SKY[i + 1];
  const t = clamp01((h - a[0]) / (b[0] - a[0]));
  const c = a[1].map((v, k) => Math.round(lerp(v, b[1][k], t)));
  return new THREE.Color(`rgb(${c[0]},${c[1]},${c[2]})`);
}

// ------------------------------------------------------------------ textures

function earthTexture() {
  const W = 1024, H = 512;
  const c = document.createElement("canvas");
  c.width = W; c.height = H;
  const g = c.getContext("2d");
  g.scale(2, 2);
  g.fillStyle = "#1f63c6";
  g.fillRect(0, 0, W, H);
  let seed = 7;
  const r = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
  const blob = (cx, cy, n, spread, colors) => {
    for (let i = 0; i < n; i++) {
      const x = Math.round(cx + (r() - 0.5) * spread * 2), y = Math.round(cy + (r() - 0.5) * spread);
      g.fillStyle = colors[Math.floor(r() * colors.length)];
      g.fillRect(x, y, 3 + Math.floor(r() * 6), 3 + Math.floor(r() * 5));
    }
  };
  const land = ["#3f9a3a", "#4caf45", "#5b8f32", "#8a7a45", "#3f9a3a"];
  // The launch site is at u = 0.75 on the equator; east is toward smaller u. Land to the west, sea to the east.
  const Wd = W, Hd = H;
  { const W = Wd / 2, H = Hd / 2;
  blob(W * 0.80, H * 0.5, 260, 22, land);
  blob(W * 0.80, H * 0.36, 160, 18, land);
  g.fillStyle = "#3f9a3a";
  g.fillRect(W * 0.75 - 1, H * 0.5 - 6, 30, 12);
  blob(W * 0.40, H * 0.38, 220, 26, land);
  blob(W * 0.46, H * 0.62, 180, 20, land);
  blob(W * 0.15, H * 0.42, 160, 22, land);
  blob(W * 0.60, H * 0.70, 90, 14, ["#c2a35a", "#d6b56b", "#8a7a45"]);
  blob(W * 0.95, H * 0.65, 90, 12, land);
  g.fillStyle = "#f1f5f9";
  g.fillRect(0, 0, W, 14); g.fillRect(0, H - 14, W, 14);
  blob(W * 0.5, 16, 200, 260, ["#f1f5f9", "#e2e8f0"]);
  blob(W * 0.5, H - 16, 200, 260, ["#f1f5f9", "#e2e8f0"]);
  // clouds
  g.globalAlpha = 0.7;
  for (let i = 0; i < 70; i++) blob(r() * W, 30 + r() * (H - 60), 14, 10, ["#ffffff", "#f1f5f9"]);
  g.globalAlpha = 1;
  }
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.magFilter = THREE.NearestFilter;
  t.minFilter = THREE.NearestFilter;
  t.generateMipmaps = false;
  return t;
}

function moonTexture() {
  const W = 256, H = 128;
  const c = document.createElement("canvas");
  c.width = W; c.height = H;
  const g = c.getContext("2d");
  g.fillStyle = "#a8a8a8";
  g.fillRect(0, 0, W, H);
  let seed = 3;
  const r = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
  for (let i = 0; i < 40; i++) { g.fillStyle = r() < 0.5 ? "#8c8c8c" : "#979797"; g.fillRect(r() * W, r() * H, 6 + r() * 30, 4 + r() * 16); }
  for (let i = 0; i < 90; i++) {
    const x = r() * W, y = r() * H, s = 2 + r() * 6;
    g.fillStyle = "#7d7d7d"; g.fillRect(x, y, s, s);
    g.fillStyle = "#c4c4c4"; g.fillRect(x + s, y, 1, s);
  }
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.magFilter = THREE.NearestFilter;
  t.minFilter = THREE.NearestFilter;
  t.generateMipmaps = false;
  return t;
}

// ------------------------------------------------------------------ rocket model

const TANK_LOOK = {
  tankS: ["#f1f5f9", "#fb923c"],
  tankL: ["#f8fafc", "#3b82f6"],
  tankH: ["#e5e7eb", "#1f2937"],
  tankM: ["#f8fafc", "#111827"],
};
const ENGINE_LOOK = {
  engW: { r: 0.7, color: "#4b5563" },
  engS: { r: 0.95, color: "#374151" },
  engV: { r: 0.85, color: "#9ca3af" },
  engM: { r: 1.5, color: "#1f2937" },
};

function enginePositions(n, W) {
  const q = W / 4;
  switch (n) {
    case 1: return [[0, 0]];
    case 2: return [[-q, 0], [q, 0]];
    case 3: return [[0, -q], [-q, q * 0.8], [q, q * 0.8]];
    case 4: return [[-q, -q], [q, -q], [-q, q], [q, q]];
    case 5: return [[0, 0], [-q * 1.2, -q * 1.2], [q * 1.2, -q * 1.2], [-q * 1.2, q * 1.2], [q * 1.2, q * 1.2]];
    default: return [[-q * 1.2, -q], [0, -q], [q * 1.2, -q], [-q * 1.2, q], [0, q], [q * 1.2, q]];
  }
}

function flameMesh(r) {
  const grp = new THREE.Group();
  const outer = new THREE.Mesh(new THREE.ConeGeometry(r * 0.95, r * 6, 10, 1, true), basic("#fb923c", { transparent: true, opacity: 0.8, depthWrite: false, side: THREE.DoubleSide }));
  outer.rotation.x = Math.PI;
  outer.position.y = -r * 3;
  const inner = new THREE.Mesh(new THREE.ConeGeometry(r * 0.6, r * 3.6, 10, 1, true), basic("#fde68a", { transparent: true, opacity: 0.95, depthWrite: false, side: THREE.DoubleSide }));
  inner.rotation.x = Math.PI;
  inner.position.y = -r * 1.8;
  grp.add(outer, inner);
  grp.visible = false;
  return grp;
}

function addEngine(parent, key, x, y, z, r) {
  const look = ENGINE_LOOK[key];
  const h = PARTS[key].h;
  const bell = new THREE.Mesh(new THREE.CylinderGeometry(r * 0.5, r, h, 10), lam(look.color));
  bell.position.set(x, y + h / 2, z);
  bell.castShadow = true;
  parent.add(bell);
  const flame = flameMesh(r);
  flame.position.set(x, y, z);
  parent.add(flame);
  return flame;
}

function pyramid(w, h, color) {
  const m = new THREE.Mesh(new THREE.ConeGeometry((w / 2) * Math.SQRT2, h, 4), lam(color, { flatShading: true }));
  m.rotation.y = Math.PI / 4;
  m.castShadow = true;
  return m;
}

function capsuleModel(look, nose, chute) {
  const g = new THREE.Group();
  const W = 4, H = PARTS.capsule.h;
  const wall = lam("#d1d5db");
  const glass = new THREE.MeshLambertMaterial({ color: "#bfe3ff", transparent: true, opacity: 0.28, depthWrite: false });
  const shell = new THREE.Mesh(new THREE.BoxGeometry(W, H, W), [wall, wall, wall, wall, glass, wall]);
  shell.position.y = H / 2;
  shell.castShadow = true;
  g.add(shell);
  const inside = new THREE.Mesh(new THREE.BoxGeometry(W - 0.3, H - 0.3, W - 0.3), lam("#475569", { side: THREE.BackSide }));
  inside.position.y = H / 2;
  g.add(inside);
  const frame = lam("#9ca3af");
  g.add(boxMesh(W + 0.1, 0.35, W + 0.1, frame, 0, 0.17, 0));
  g.add(boxMesh(W + 0.1, 0.35, W + 0.1, frame, 0, H - 0.17, 0));
  const kid = createCharacter(look);
  kid.scale.setScalar(0.52);
  kid.rotation.y = Math.PI;      // face the camera (+z)
  kid.position.set(0, 0.45, 0.2);
  g.add(kid);
  if (nose) {
    const n = pyramid(W, PARTS.nose.h, "#ef4444");
    n.position.y = H + PARTS.nose.h / 2;
    g.add(n);
  } else {
    g.add(boxMesh(1.6, 0.5, 1.6, lam("#9ca3af"), 0, H + 0.25, 0));
  }
  if (chute) {
    const dome = new THREE.Mesh(new THREE.SphereGeometry(9, 8, 4, 0, Math.PI * 2, 0, Math.PI / 2), [lam("#f97316", { flatShading: true, side: THREE.DoubleSide })]);
    dome.geometry.clearGroups();
    dome.position.y = H + 16;
    dome.scale.y = 0.6;
    g.add(dome);
    const stripe = new THREE.Mesh(new THREE.SphereGeometry(9.05, 8, 4, 0, Math.PI / 2, 0, Math.PI / 2), lam("#ffffff", { flatShading: true, side: THREE.DoubleSide }));
    stripe.position.y = H + 16;
    stripe.scale.y = 0.6;
    g.add(stripe);
    for (const [x, z] of [[-6, -6], [6, -6], [-6, 6], [6, 6]]) {
      const line = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 1, 4), lam("#e5e7eb"));
      const top = new THREE.Vector3(x, H + 16, z), bot = new THREE.Vector3(0, H, 0);
      line.position.copy(top).add(bot).multiplyScalar(0.5);
      line.scale.y = top.distanceTo(bot);
      line.lookAt(bot);
      line.rotateX(Math.PI / 2);
      g.add(line);
    }
  }
  return { group: g, height: chute ? H + 21 : H + (nose ? PARTS.nose.h : 0.5) };
}

// Builds a rocket (or what's left of it from stage `from`). Origin at the bottom center.
// Returns { group, height, flames: [{ stage, booster, mesh }], stageGroups, boosterGroup }.
export function buildRocket(design, look, opts) {
  const o = opts || {};
  const from = o.from || 0;
  const root = new THREE.Group();
  const flames = [];
  const stageGroups = [];
  let boosterGroup = null;
  let y = 0;
  if (!o.capsuleOnly) {
    design.stages.forEach((st, i) => {
      if (i < from) return;
      const sg = new THREE.Group();
      sg.position.y = y;
      root.add(sg);
      stageGroups[i] = sg;
      let W = 4;
      for (const k of st.tanks) W = Math.max(W, PARTS[k].w || 4);
      let ly = 0;
      // engines
      if (st.eng.length) {
        const eh = Math.max(...st.eng.map((k) => PARTS[k].h));
        const pos = enginePositions(st.eng.length, W);
        const cols = st.eng.length <= 1 ? 1 : st.eng.length <= 4 ? 2 : 3;
        st.eng.forEach((k, j) => {
          const r = Math.min(ENGINE_LOOK[k].r, (W / cols) * 0.45);
          const f = addEngine(sg, k, pos[j][0], ly + eh - PARTS[k].h, pos[j][1], r);
          flames.push({ stage: i, booster: false, mesh: f, r });
        });
        sg.add(boxMesh(W * 0.92, 0.5, W * 0.92, lam("#4b5563"), 0, ly + eh - 0.25, 0));
        ly += eh;
      } else {
        sg.add(boxMesh(W * 0.92, 0.5, W * 0.92, lam("#4b5563"), 0, 0.25, 0));
        ly += 0.5;
      }
      const tanksStart = ly;
      // tanks
      for (const k of st.tanks) {
        const p = PARTS[k];
        const w = p.w || 4;
        const [body, band] = TANK_LOOK[k];
        sg.add(boxMesh(w, p.h, w, lam(body), 0, ly + p.h / 2, 0));
        sg.add(boxMesh(w + 0.12, Math.min(1, p.h * 0.18), w + 0.12, lam(band), 0, ly + p.h * 0.72, 0));
        if (k === "tankH" || k === "tankM") {
          // checker "roll pattern" blocks
          const s = w / 2;
          sg.add(boxMesh(s + 0.06, p.h * 0.25, s + 0.06, lam(band), -s / 2, ly + p.h * 0.25, -s / 2));
          sg.add(boxMesh(s + 0.06, p.h * 0.25, s + 0.06, lam(band), s / 2, ly + p.h * 0.25, s / 2));
        }
        ly += p.h;
      }
      if (!st.tanks.length) { sg.add(boxMesh(W * 0.8, 1, W * 0.8, lam("#9ca3af"), 0, ly + 0.5, 0)); ly += 1; }
      // fins at the bottom of the stage
      if (st.fins) {
        const fh = Math.min(5, Math.max(3, (ly - tanksStart) * 0.5));
        const fm = lam("#ef4444");
        const fo = W / 2 + 1;
        const fy = tanksStart + fh / 2 - 0.4;
        sg.add(boxMesh(2, fh, 0.4, fm, fo, fy, 0), boxMesh(2, fh, 0.4, fm, -fo, fy, 0), boxMesh(0.4, fh, 2, fm, 0, fy, fo), boxMesh(0.4, fh, 2, fm, 0, fy, -fo));
      }
      // side boosters
      if (st.boost && i === 0) {
        boosterGroup = new THREE.Group();
        sg.add(boosterGroup);
        const bh = PARTS.boost.h;
        for (const side of [-1, 1]) {
          const bx = side * (W / 2 + 1.3);
          boosterGroup.add(boxMesh(2.4, bh, 2.4, lam("#f8fafc"), bx, 2 + bh / 2, 0));
          boosterGroup.add(boxMesh(2.5, 0.8, 2.5, lam("#ef4444"), bx, 2 + bh * 0.8, 0));
          const n = pyramid(2.4, 2.4, "#ef4444");
          n.position.set(bx, 2 + bh + 1.2, 0);
          boosterGroup.add(n);
          const f = addEngine(boosterGroup, "engW", bx, 0, 0, 0.8);
          flames.push({ stage: i, booster: true, mesh: f, r: 0.8 });
        }
      }
      // decoupler
      if (i < design.stages.length - 1) {
        sg.add(boxMesh(W + 0.2, PARTS.stage.h, W + 0.2, lam("#374151"), 0, ly + PARTS.stage.h / 2, 0));
        sg.add(boxMesh(W + 0.3, 0.25, W + 0.3, lam("#facc15"), 0, ly + PARTS.stage.h / 2, 0));
        ly += PARTS.stage.h;
      }
      sg.userData.height = ly;
      sg.userData.width = W;
      y += ly;
    });
  }
  const cap = capsuleModel(look, design.nose && !o.capsuleOnly, !!o.chute);
  cap.group.position.y = y;
  if (o.capsuleOnly) {
    root.add(boxMesh(4.4, 0.6, 4.4, lam("#78350f"), 0, -0.3, 0));   // heat shield
  }
  root.add(cap.group);
  const height = y + cap.height;
  return { group: root, height, flames, stageGroups, boosterGroup, capsule: cap.group };
}

// ------------------------------------------------------------------ the 3D scene

export class Scene3D {
  constructor(look) {
    this.look = look;
    const world = new World({ sky: "#8fd3ff", fogNear: 600, fogFar: 9000, shiftLock: false, cameraDistance: 26 });
    this.world = world;
    world.scene.background = null;
    world.cam.pitch = 0.2;
    world.cam.yaw = 0;
    world.camera.far = 400000;
    world.camera.updateProjectionMatrix();
    this.renderer = world.renderer;
    this.renderer.autoClear = false;
    this.ground = new THREE.Group();
    world.scene.add(this.ground);
    this.moonGround = new THREE.Group();
    this.moonGround.visible = false;
    world.scene.add(this.moonGround);
    this.rocketRoot = new THREE.Group();
    world.scene.add(this.rocketRoot);
    this.rocket = null;
    this.debris = [];
    this.smoke = [];
    this.remotes = new Map();
    this.time = 0;
    this.buildGround();
    this.buildMoonGround();
    this.buildFar();
  }

  part(o) {
    const m = this.world.part(o);
    return m;
  }

  // ---------------------------------------------------------------- the launch site
  buildGround() {
    const G = this.ground;
    const add = (o) => { const m = this.world.part(o); G.add(m); return m; };
    // land: from 40 km west of the pad to 30 km east, then sea
    const plane = (w, d, sx, sz, color) => {
      const geo = new THREE.PlaneGeometry(w, d, sx, sz);
      geo.rotateX(-Math.PI / 2);
      const m = new THREE.Mesh(geo, lam(color));
      m.receiveShadow = true;
      return m;
    };
    // land from 40 km west of the pad to 30 km east; sea all around it (no overlap, so no flicker)
    const land = plane(140000, 60000, 70, 30, "#4b9b3f");
    land.position.set(-10000, 0, 0);
    G.add(land);
    const SEA = 1200000, sea = "#1e6fd0";
    for (const [w, d, x, z] of [
      [SEA, SEA * 2, 60000 + SEA / 2, 0], [SEA, SEA * 2, -80000 - SEA / 2, 0],
      [140000, SEA, -10000, 30000 + SEA / 2], [140000, SEA, -10000, -30000 - SEA / 2]]) {
      const m = plane(w, d, Math.max(2, Math.round(w / 20000)), Math.max(2, Math.round(d / 20000)), sea);
      m.position.set(x, 0, z);
      G.add(m);
    }
    add({ size: [900, 1, 300], pos: [0, 0.4, -40], color: "#9aa3ad" });   // concrete apron
    add({ size: [900, 0.2, 10], pos: [0, 0.95, 60], color: "#3f444c", studs: false });  // road
    for (let i = 0; i < SLOT_X.length; i++) this.buildPad(SLOT_X[i], i);
    // control building and fuel tanks
    add({ size: [40, 14, 24], pos: [-40, 7, -120], color: "#e5e7eb" });
    add({ size: [40, 3, 1], pos: [-40, 10, -107.9], color: "#60a5fa", material: "glass", studs: false });
    add({ size: [42, 1, 26], pos: [-40, 14.5, -120], color: "#9ca3af" });
    add({ size: [6, 10, 6], pos: [-12, 19, -120], color: "#9ca3af" });   // radar mast
    add({ size: [12, 1, 12], pos: [-12, 24.5, -120], color: "#e5e7eb", rot: [0.4, 0, 0] });
    for (const [x, c] of [[60, "#f1f5f9"], [80, "#f1f5f9"], [100, "#facc15"]]) {
      const s = new THREE.Mesh(new THREE.SphereGeometry(7, 10, 8), lam(c));
      s.position.set(x, 8, -110);
      s.castShadow = true;
      G.add(s);
      add({ size: [2, 4, 2], pos: [x, 2, -110], color: "#6b7280" });
    }
    // trees
    let seed = 11;
    const r = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
    for (let i = 0; i < 60; i++) {
      const x = (r() - 0.5) * 1400, z = -200 - r() * 600;
      const h = 6 + r() * 6;
      add({ size: [1.6, h, 1.6], pos: [x, h / 2, z], color: "#7c4a21", studs: false, shadow: false });
      add({ size: [7, 6, 7], pos: [x, h + 2, z], color: r() < 0.5 ? "#2f8a3a" : "#3fa046", shadow: false });
    }
    // clouds: blocky puffs between about 1.5 and 3 km up (3000-6000 studs)
    const cm = lam("#ffffff", { emissive: "#9ca3af" });
    this.clouds = new THREE.Group();
    for (let i = 0; i < 90; i++) {
      const cx = (r() - 0.5) * 9000, cz = i < 14 ? (r() - 0.5) * 60 : -150 - r() * 3500, cy = 3000 + r() * 2600;
      const n = 3 + Math.floor(r() * 4);
      for (let k = 0; k < n; k++) {
        const w = 40 + r() * 90;
        const b = boxMesh(w, 14 + r() * 26, w * (0.6 + r() * 0.6), cm, cx + (r() - 0.5) * 120, cy + (r() - 0.5) * 18, cz + (r() - 0.5) * 60);
        b.castShadow = false;
        b.receiveShadow = false;
        this.clouds.add(b);
      }
    }
    G.add(this.clouds);
  }

  buildPad(x, i) {
    const G = this.ground;
    const add = (o) => { const m = this.world.part(o); G.add(m); return m; };
    add({ size: [18, PAD_TOP, 18], pos: [x, PAD_TOP / 2, 0], color: "#6b7280" });
    add({ size: [6, 0.2, 6], pos: [x, PAD_TOP + 0.05, 0], color: "#facc15", material: "neon", studs: false, collide: false });
    add({ size: [6, 0.4, 3], pos: [x, 0.2, -10.5], color: "#374151", studs: false });   // flame trench exit
    // tower (lattice)
    const tx = x + 12, H = 70;
    for (const [dx, dz] of [[-2, -2], [2, -2], [-2, 2], [2, 2]]) add({ size: [0.8, H, 0.8], pos: [tx + dx, H / 2, dz], color: "#dc2626", studs: false });
    for (let y = 6; y < H; y += 7) {
      add({ size: [4.8, 0.6, 0.6], pos: [tx, y, -2], color: "#ef4444", studs: false, shadow: false });
      add({ size: [4.8, 0.6, 0.6], pos: [tx, y, 2], color: "#ef4444", studs: false, shadow: false });
      add({ size: [0.6, 0.6, 4.8], pos: [tx - 2, y, 0], color: "#ef4444", studs: false, shadow: false });
      add({ size: [0.6, 0.6, 4.8], pos: [tx + 2, y, 0], color: "#ef4444", studs: false, shadow: false });
    }
    add({ size: [6, 1, 6], pos: [tx, H + 0.5, 0], color: "#9ca3af" });
    add({ size: [0.3, 8, 0.3], pos: [tx, H + 5, 0], color: "#d1d5db", studs: false });
    add({ size: [8, 1, 1.4], pos: [tx - 6, 18, 0], color: "#9ca3af", studs: false });   // service arm
    const sign = this.world.label(`Pad ${i + 1}`, { height: 2.2, pos: [x - 6, PAD_TOP + 1.4, 9.3] });
    G.add(sign);
  }

  buildMoonGround() {
    const G = this.moonGround;
    const add = (o) => { const m = this.world.part(o); G.add(m); return m; };
    const geo = new THREE.PlaneGeometry(40000, 40000, 40, 40);
    geo.rotateX(-Math.PI / 2);
    const plain = new THREE.Mesh(geo, lam("#8f9196"));
    plain.receiveShadow = true;
    G.add(plain);
    add({ size: [300, 1, 300], pos: [0, -0.4, 0], color: "#a1a3a8" });
    let seed = 5;
    const r = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
    for (let i = 0; i < 40; i++) {
      const x = (r() - 0.5) * 900, z = -40 - r() * 900, s = 10 + r() * 40;
      add({ size: [s, 0.6, s], pos: [x, 0.1, z], color: "#77797e", studs: false, shadow: false });
      add({ size: [s + 4, 1.6, 2], pos: [x, 0.8, z - s / 2 - 1], color: "#a7a9ae", studs: false, shadow: false });
      add({ size: [s + 4, 1.6, 2], pos: [x, 0.8, z + s / 2 + 1], color: "#a7a9ae", studs: false, shadow: false });
      add({ size: [2, 1.6, s], pos: [x - s / 2 - 1, 0.8, z], color: "#a7a9ae", studs: false, shadow: false });
      add({ size: [2, 1.6, s], pos: [x + s / 2 + 1, 0.8, z], color: "#a7a9ae", studs: false, shadow: false });
    }
    for (let i = 0; i < 60; i++) {
      const s = 1 + r() * 4;
      add({ size: [s, s * 0.7, s], pos: [(r() - 0.5) * 600, s * 0.35, (r() - 0.5) * 600], color: "#6b6d72", studs: false });
    }
    // a flag (shown after landing)
    this.flag = new THREE.Group();
    this.flag.add(boxMesh(0.25, 9, 0.25, lam("#e5e7eb"), 0, 4.5, 0));
    this.flag.add(boxMesh(5, 3, 0.15, lam("#3b82f6"), 2.5, 7.4, 0));
    this.flag.add(boxMesh(1.6, 1.6, 0.2, lam("#facc15"), 2.5, 7.4, 0));
    this.flag.visible = false;
    G.add(this.flag);
  }

  // ---------------------------------------------------------------- space (km units, rocket at the origin)
  buildFar() {
    const far = new THREE.Scene();
    this.far = far;
    this.farCam = new THREE.PerspectiveCamera(70, innerWidth / innerHeight, 0.01, 2000000);
    addEventListener("resize", () => { this.farCam.aspect = innerWidth / innerHeight; this.farCam.updateProjectionMatrix(); });
    far.add(new THREE.AmbientLight(0xffffff, 0.35));
    this.farSun = new THREE.DirectionalLight(0xffffff, 1.8);
    far.add(this.farSun, this.farSun.target);
    this.sunDir = new THREE.Vector3(0.55, 0.62, 0.56).normalize();   // inertial frame

    this.sky = new THREE.Group();   // stars and the Sun: very far away, turn with the view
    far.add(this.sky);
    const n = 1400, pos = new Float32Array(n * 3);
    let seed = 9;
    const r = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
    for (let i = 0; i < n; i++) {
      const u = r() * 2 - 1, a = r() * Math.PI * 2, s = Math.sqrt(1 - u * u);
      pos.set([Math.cos(a) * s * 90000, u * 90000, Math.sin(a) * s * 90000], i * 3);
    }
    const sg = new THREE.BufferGeometry();
    sg.setAttribute("position", new THREE.BufferAttribute(pos, 3));
    this.starMat = new THREE.PointsMaterial({ color: 0xffffff, size: 2, sizeAttenuation: false, transparent: true, opacity: 0, depthWrite: false });
    const stars = new THREE.Points(sg, this.starMat);
    stars.renderOrder = -2;
    this.sky.add(stars);
    this.sunDisk = new THREE.Mesh(new THREE.CircleGeometry(1400, 24), new THREE.MeshBasicMaterial({ color: 0xfff7d6, transparent: true, opacity: 1, depthWrite: false }));
    this.sunDisk.position.copy(this.sunDir).multiplyScalar(80000);
    this.sunDisk.lookAt(0, 0, 0);
    this.sunDisk.renderOrder = -1;
    this.sky.add(this.sunDisk);

    this.earthGroup = new THREE.Group();
    far.add(this.earthGroup);
    const eg = new THREE.SphereGeometry(R_EARTH / 1000, 128, 64);
    eg.rotateX(Math.PI / 2);   // poles along z, so the equator is the flight plane
    this.earth = new THREE.Mesh(eg, new THREE.MeshLambertMaterial({ map: earthTexture() }));
    this.earthGroup.add(this.earth);
    this.halo = new THREE.Mesh(new THREE.SphereGeometry(R_EARTH / 1000 + 60, 96, 48),
      new THREE.MeshBasicMaterial({ color: 0x66b6ff, transparent: true, opacity: 0.3, side: THREE.BackSide, depthWrite: false }));
    this.earthGroup.add(this.halo);
    // the Karman line, 100 km up: the usual boundary of space
    this.karman = new THREE.Mesh(new THREE.TorusGeometry(R_EARTH / 1000 + 100, 0.12, 4, 720),
      new THREE.MeshBasicMaterial({ color: 0xfacc15, transparent: true, opacity: 0.75 }));
    this.karman.visible = false;
    this.earthGroup.add(this.karman);
    this.moonDir = new THREE.Vector3(-0.55, 0.78, -0.3).normalize();
    this.moon = new THREE.Mesh(new THREE.SphereGeometry(1737, 48, 24), new THREE.MeshLambertMaterial({ map: moonTexture() }));
    this.moon.position.copy(this.moonDir).multiplyScalar(384400);
    this.earthGroup.add(this.moon);
    // the big Moon we land on (moon mode)
    this.bigMoon = new THREE.Mesh(new THREE.SphereGeometry(1737, 128, 64), new THREE.MeshLambertMaterial({ map: moonTexture() }));
    this.bigMoon.visible = false;
    far.add(this.bigMoon);
  }

  // ---------------------------------------------------------------- rockets

  setRocket(design, opts) {
    if (this.rocket) this.rocketRoot.remove(this.rocket.group);
    this.rocket = buildRocket(design, this.look, opts);
    this.rocket.group.position.y = -this.rocket.height / 2;
    this.rocketRoot.add(this.rocket.group);
    this.design = design;
    this.rocketOpts = opts || {};
    return this.rocket;
  }

  // Detach the bottom stage (or the boosters) as falling debris.
  dropDebris(kind, index) {
    if (!this.rocket) return;
    const grp = kind === "boosters" ? this.rocket.boosterGroup : this.rocket.stageGroups[index];
    if (!grp) return;
    this.world.scene.attach(grp);
    this.debris.push({ obj: grp, t: 0, side: kind === "boosters" ? 0 : 1, spin: (Math.random() - 0.5) * 0.6, vy: 0 });
    if (kind === "boosters") {
      // split into two
      const kids = [...grp.children];
      const left = new THREE.Group(), right = new THREE.Group();
      grp.updateMatrixWorld(true);
      this.world.scene.add(left, right);
      for (const k of kids) { (k.getWorldPosition(new THREE.Vector3()).x < grp.getWorldPosition(new THREE.Vector3()).x ? left : right).attach(k); }
      this.world.scene.remove(grp);
      this.debris.pop();
      this.debris.push({ obj: left, t: 0, dir: -1, spin: 0.6, vy: 0 }, { obj: right, t: 0, dir: 1, spin: -0.6, vy: 0 });
    }
  }

  stepDebris(dt, accel) {
    for (const d of this.debris) {
      d.t += dt;
      d.vy += (accel + 5) * dt;
      d.obj.position.y -= d.vy * dt * S;
      if (d.dir) d.obj.position.x += d.dir * dt * 6;
      d.obj.rotation.z += d.spin * dt;
      for (const f of d.obj.children) if (f.isGroup && f.children.length === 2) f.visible = false;  // flames off
    }
    this.debris = this.debris.filter((d) => {
      if (d.t > 7) { this.world.scene.remove(d.obj); return false; }
      return true;
    });
  }

  clearDebris() {
    for (const d of this.debris) this.world.scene.remove(d.obj);
    this.debris = [];
    for (const p of this.smoke) this.ground.remove(p.mesh);
    this.smoke = [];
  }

  // Flames on for the current stage; size grows as the air thins (exhaust spreads out in vacuum).
  setFlames(stage, on, boostOn, airRatio, throttle) {
    if (!this.rocket) return;
    const spread = 1 + (1 - airRatio) * 1.6;
    for (const f of this.rocket.flames) {
      const lit = f.stage === stage && (f.booster ? boostOn : on);
      f.mesh.visible = lit;
      if (lit) {
        const k = (0.85 + Math.random() * 0.3) * (throttle ?? 1);
        f.mesh.scale.set(spread, k * (1 + (1 - airRatio) * 0.4), spread);
      }
    }
  }

  // Re-entry glow under the capsule (0..1).
  setHeat(k) {
    if (!this.heat) {
      this.heat = new THREE.Mesh(new THREE.SphereGeometry(4, 10, 6, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2),
        new THREE.MeshBasicMaterial({ color: 0xff7a1a, transparent: true, opacity: 0.8, depthWrite: false }));
      this.rocketRoot.add(this.heat);
    }
    this.heat.visible = k > 0.02;
    if (this.rocket) this.heat.position.y = -this.rocket.height / 2 - 0.3;
    this.heat.scale.set(1 + k * 0.6, 1 + k * 3 * (0.9 + Math.random() * 0.2), 1 + k * 0.6);
    this.heat.material.opacity = 0.35 + k * 0.55;
  }

  puff(worldPos, size, life, color) {
    let p = this.smoke.find((s) => s.t >= s.life);
    if (!p) {
      if (this.smoke.length > 120) return;
      const mesh = new THREE.Mesh(new THREE.BoxGeometry(1, 1, 1), new THREE.MeshLambertMaterial({ color: 0xdddddd, emissive: 0x555555, transparent: true, opacity: 0.5, depthWrite: false }));
      p = { mesh, t: 0, life: 1 };
      this.smoke.push(p);
      this.ground.add(mesh);
    }
    p.mesh.material.color.set(color || "#e5e7eb");
    p.mesh.position.copy(worldPos);
    p.mesh.rotation.set(Math.random() * 3, Math.random() * 3, 0);
    p.t = 0;
    p.life = life;
    p.size = size;
    p.vx = (Math.random() - 0.5) * 6;
    p.vz = (Math.random() - 0.5) * 6;
    p.mesh.visible = true;
  }

  stepSmoke(dt) {
    for (const p of this.smoke) {
      if (p.t >= p.life) { p.mesh.visible = false; continue; }
      p.t += dt;
      const k = p.t / p.life;
      const s = p.size * (0.6 + k * 2.2);
      p.mesh.scale.setScalar(s);
      p.mesh.position.x += p.vx * dt;
      p.mesh.position.z += p.vz * dt;
      p.mesh.material.opacity = 0.5 * (1 - k) * (1 - k);
    }
  }

  // Other players' rockets standing on their own pads.
  remote(id, info) {
    let r = this.remotes.get(id);
    if (!r) {
      r = { group: new THREE.Group(), key: "", model: null, label: null };
      this.ground.add(r.group);
      this.remotes.set(id, r);
    }
    const key = JSON.stringify([info.design, info.stage, info.capsule, info.chute]);
    if (key !== r.key) {
      r.key = key;
      if (r.model) r.group.remove(r.model.group);
      r.model = buildRocket(info.design, info.look, { from: info.stage, capsuleOnly: info.capsule, chute: info.chute });
      r.model.group.position.y = -r.model.height / 2;
      r.group.add(r.model.group);
      if (r.label) r.group.remove(r.label);
      r.label = this.world.label(info.name, { height: 2.6 });
      r.group.add(r.label);
    }
    r.label.position.y = r.model.height / 2 + 4;
    r.slot = info.slot;
    r.target = info;
    return r;
  }

  removeRemote(id) {
    const r = this.remotes.get(id);
    if (r) { this.ground.remove(r.group); this.remotes.delete(id); }
  }

  // ---------------------------------------------------------------- per-frame view
  // view: { alt (m), x (m downrange, ground-relative), tilt (rad), phi (rad), moon: bool, camScale }
  render(view, dt) {
    this.time += dt;
    const world = this.world;
    const h = view.alt;
    const L = this.rocket ? this.rocket.height : 10;
    // rocket at the origin (its middle); everything else moves around it
    this.rocketRoot.rotation.z = -view.tilt;
    if (view.moon) this.moonGround.position.set(-view.x * S, -(h * S + L / 2), 0);
    else this.ground.position.set(-view.x * S, -(h * S + L / 2 + PAD_TOP), 0);
    this.ground.visible = !view.moon && h < 9000;
    this.clouds.visible = h < 9000;
    this.karman.visible = !view.moon && h > 50000 && h < 250000;
    this.moonGround.visible = !!view.moon && h < 30000;

    // remote rockets
    for (const r of this.remotes.values()) {
      const t = r.target;
      if (!t) continue;
      const px = SLOT_X[t.slot % SLOT_X.length] + t.x * S, py = t.alt * S + PAD_TOP + r.model.height / 2;
      r.group.position.set(px, py, 0);
      r.group.rotation.z = -t.tilt;
      r.group.visible = !view.moon && Math.abs(t.alt - h) < 12000;
      for (const f of r.model.flames) f.mesh.visible = !!t.flame && f.stage === t.stage;
      if (t.flame) for (const f of r.model.flames) if (f.mesh.visible) f.mesh.scale.y = 0.85 + Math.random() * 0.3;
    }

    // sky, fog and light
    const sky = view.moon ? new THREE.Color("#020308") : skyColor(h);
    const scene = world.scene;
    scene.fog.color.copy(sky);
    scene.fog.near = 1500 + h * S * 2;
    scene.fog.far = 16000 + h * S * 10;
    if (view.moon) { scene.fog.near = 1e8; scene.fog.far = 1e9; }
    const dark = view.moon ? 1 : clamp01((h - 15000) / 60000);
    world.hemi.intensity = lerp(1.15, 0.45, dark);
    world.hemi.groundColor.set(view.moon ? "#555555" : "#8a7a66");
    world.sun.intensity = lerp(1.6, 2.2, dark);

    // camera
    const cam = this.world.cam;
    const dist = cam.dist * Math.max(1, (view.camScale || (L + 8) / 22));
    const target = new THREE.Vector3(0, 0, 0);
    const off = new THREE.Vector3(Math.sin(cam.yaw) * Math.cos(cam.pitch), Math.sin(cam.pitch), Math.cos(cam.yaw) * Math.cos(cam.pitch)).multiplyScalar(dist);
    if (view.shake) off.add(new THREE.Vector3((Math.random() - 0.5) * view.shake, (Math.random() - 0.5) * view.shake, 0));
    world.camera.position.copy(target).add(off);
    world.camera.lookAt(target);
    world.camera.near = Math.max(0.5, dist * 0.06);
    world.camera.updateProjectionMatrix();
    world.sun.position.set(60, 120, 40);
    world.sun.target.position.set(0, 0, 0);

    // far scene
    const km = 1 / 1000;
    const fc = this.farCam;
    fc.fov = world.camera.fov;
    fc.quaternion.copy(world.camera.quaternion);
    fc.position.copy(world.camera.position).multiplyScalar(km / S);
    fc.near = Math.max(0.01, (h * km) * 0.02);
    fc.updateProjectionMatrix();
    const turn = view.phi || 0;
    if (view.moon) {
      this.bigMoon.visible = true;
      this.bigMoon.position.set(0, -(1737 + h * km), 0);
      this.bigMoon.rotation.z = (view.x * km) / 1737;
      this.earthGroup.position.set(0, 0, 0);
      this.earthGroup.rotation.set(0, 0, 0);
      this.earth.position.set(0, 0, 0);
      this.earthGroup.position.set(-140000, 300000, -200000);
      this.halo.visible = true;
      this.moon.visible = false;
    } else {
      this.bigMoon.visible = false;
      this.moon.visible = true;
      this.earthGroup.position.set(0, -(R_EARTH + h) * km, 0);
      this.earthGroup.rotation.set(0, 0, turn);
      this.halo.visible = h > 62000;
    }
    this.sky.rotation.set(0, 0, turn);
    const sd = this.sunDir.clone().applyAxisAngle(new THREE.Vector3(0, 0, 1), turn);
    this.farSun.position.copy(sd).multiplyScalar(100);
    this.farSun.target.position.set(0, 0, 0);
    this.starMat.opacity = view.moon ? 1 : clamp01((h - 25000) / 45000);
    this.sunDisk.material.opacity = view.moon ? 1 : clamp01((h - 20000) / 40000);

    const r = this.renderer;
    r.setClearColor(sky, 1);
    r.clear(true, true, true);
    r.render(this.far, fc);
    r.clearDepth();
    r.render(scene, world.camera);
  }
}
