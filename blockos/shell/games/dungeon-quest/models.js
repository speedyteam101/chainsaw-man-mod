// Dungeon Quest: 3D models and effects built from shared geometry and cached materials (cheap to draw).
import { THREE } from "../kit3d.js";

export const BOX = new THREE.BoxGeometry(1, 1, 1);
const mats = new Map();
export function mat(color, neon) {
  const key = color + (neon ? "|n" : "|l");
  let m = mats.get(key);
  if (!m) {
    m = neon ? new THREE.MeshBasicMaterial({ color }) : new THREE.MeshLambertMaterial({ color });
    mats.set(key, m);
  }
  return m;
}
export const FLASH = new THREE.MeshBasicMaterial({ color: 0xffffff });

function box(parent, w, h, d, color, x, y, z, neon) {
  const m = new THREE.Mesh(BOX, mat(color, neon));
  m.scale.set(w, h, d);
  m.position.set(x, y, z);
  m.castShadow = !neon;
  parent.add(m);
  return m;
}

// ------------------------------------------------------------------ weapons

// Grip at the origin, blade pointing along -Z (forward when the arm hangs down).
export function makeWeapon(kind, color) {
  const g = new THREE.Group();
  const handle = "#5b3a1e";
  if (kind === "axe") {
    box(g, 0.32, 0.32, 3.6, handle, 0, 0, -1.2);
    box(g, 0.2, 1.7, 1.2, color, 0, 0.55, -2.6);
    box(g, 0.24, 0.5, 0.5, "#9ca3af", 0, 0, -2.6);
  } else if (kind === "hammer") {
    box(g, 0.34, 0.34, 3.8, handle, 0, 0, -1.3);
    box(g, 1.2, 1.2, 1.9, color, 0, 0, -3.3);
    box(g, 1.3, 0.3, 0.3, "#9ca3af", 0, 0, -2.5);
  } else {
    box(g, 0.28, 0.28, 1.1, handle, 0, 0, 0.1);
    box(g, 1.2, 0.3, 0.3, "#9ca3af", 0, 0, -0.55);
    box(g, 0.32, 0.14, 3.6, color, 0, 0, -2.5);
    box(g, 0.16, 0.16, 0.4, color, 0, 0, -4.4);
  }
  return g;
}

// ------------------------------------------------------------------ monsters

const HP_BG = new THREE.SpriteMaterial({ color: 0x111111, depthWrite: false });
const HP_FILL = new THREE.SpriteMaterial({ color: 0xef4444, depthWrite: false });
const HP_W = 2.6;

// Classic blocky humanoid monster. Origin at the feet, facing -Z.
export function makeMonster(d) {
  const root = new THREE.Group();
  const body = new THREE.Group();
  body.scale.setScalar(d.scale || 1);
  root.add(body);
  const meshes = [];
  const add = (m) => { meshes.push(m); return m; };
  const limb = (w, h, color, x, y) => {
    const pivot = new THREE.Group();
    pivot.position.set(x, y, 0);
    add(box(pivot, w, h, 1, color, 0, -h / 2, 0));
    body.add(pivot);
    return pivot;
  };
  const legL = limb(0.98, 2, d.legs, -0.5, 2);
  const legR = limb(0.98, 2, d.legs, 0.5, 2);
  const armL = limb(0.98, 2, d.skin, -1.5, 4);
  const armR = limb(0.98, 2, d.skin, 1.5, 4);
  add(box(body, 2, 2, 1, d.torso, 0, 3, 0));
  add(box(body, 1.2, 1.2, 1.2, d.skin, 0, 4.6, 0));
  // glowing eyes
  box(body, 0.28, 0.2, 0.08, d.eyes, -0.27, 4.72, -0.62, true);
  box(body, 0.28, 0.2, 0.08, d.eyes, 0.27, 4.72, -0.62, true);
  if (d.cracks) {
    box(body, 0.2, 1.4, 0.06, d.cracks, -0.4, 3.1, -0.52, true);
    box(body, 0.9, 0.18, 0.06, d.cracks, 0.2, 2.6, -0.52, true);
  }
  if (d.hood) {
    add(box(body, 1.45, 1.3, 1.3, d.hood, 0, 4.75, 0.12));
  }
  if (d.wizard) {
    const hat = new THREE.Mesh(CONE, mat(d.wizard));
    hat.position.set(0, 5.9, 0);
    hat.scale.set(0.85, 1.7, 0.85);
    hat.castShadow = true;
    body.add(add(hat));
  }
  if (d.horns) {
    const h1 = add(box(body, 0.25, 0.8, 0.25, d.horns, -0.5, 5.4, 0));
    h1.rotation.z = 0.35;
    const h2 = add(box(body, 0.25, 0.8, 0.25, d.horns, 0.5, 5.4, 0));
    h2.rotation.z = -0.35;
  }
  if (d.crown) {
    add(box(body, 1.4, 0.3, 1.4, d.crown, 0, 5.3, 0));
    for (const [x, z] of [[-0.55, -0.55], [0.55, -0.55], [-0.55, 0.55], [0.55, 0.55], [0, -0.62]]) add(box(body, 0.25, 0.45, 0.25, d.crown, x, 5.6, z));
  }
  let orb = null;
  if (d.weapon === "staff") {
    add(box(armR, 0.22, 4.4, 0.22, "#5b3a1e", 0, -1.6, -0.7));
    orb = box(armR, 0.6, 0.6, 0.6, d.orb || "#ffffff", 0, 0.85, -0.7, true);
  } else if (d.weapon === "club") {
    add(box(armR, 0.4, 0.4, 2.2, "#6b4423", 0, -1.9, -0.9));
    add(box(armR, 0.9, 0.9, 1.6, "#4a2f17", 0, -1.9, -2.4));
  } else if (d.weapon === "hammer") {
    add(box(armR, 0.35, 0.35, 3.2, "#3f3f46", 0, -1.9, -1.2));
    add(box(armR, 1.3, 1.3, 1.8, "#57534e", 0, -1.9, -3));
    box(armR, 1.32, 0.25, 0.25, d.orb || "#f97316", 0, -1.9, -2.5, true);
  }
  // health bar (bosses use the big bar at the top of the screen instead)
  let hpFill = null, hpGroup = null;
  if (d.role !== "boss") {
    hpGroup = new THREE.Group();
    hpGroup.position.y = 6.4 * (d.scale || 1) + 0.6;
    const bg = new THREE.Sprite(HP_BG);
    bg.scale.set(HP_W + 0.16, 0.38, 1);
    bg.renderOrder = 1;
    hpFill = new THREE.Sprite(HP_FILL);
    hpFill.scale.set(HP_W, 0.26, 1);
    hpFill.renderOrder = 2;
    hpGroup.add(bg, hpFill);
    hpGroup.visible = false;
    root.add(hpGroup);
  }
  return { root, body, meshes, limbs: { legL, legR, armL, armR }, hpFill, hpGroup, orb, phase: 0 };
}

export function setHealthBar(m, f) {
  if (!m.hpFill) return;
  f = Math.max(0.01, Math.min(1, f));
  m.hpFill.scale.x = HP_W * f;
  m.hpFill.center.x = 0.5 / f;     // keep the bar's left edge fixed (sprites face the camera)
  m.hpGroup.visible = f < 0.999;
}

export function flashModel(m, on) {
  for (const mesh of m.meshes) {
    if (on) { if (!mesh.userData.base) mesh.userData.base = mesh.material; mesh.material = FLASH; }
    else if (mesh.userData.base) { mesh.material = mesh.userData.base; mesh.userData.base = null; }
  }
}

// pose: "walk" | "windup" | "strike" | "cast"
export function animateMonster(m, dt, speed, pose, k) {
  const { legL, legR, armL, armR } = m.limbs;
  if (speed > 0.5) m.phase += dt * speed * 0.7; else m.phase *= 0.85;
  const s = Math.sin(m.phase) * Math.min(1, speed / 10) * 0.9;
  legL.rotation.x = s; legR.rotation.x = -s;
  if (pose === "windup") {
    armL.rotation.x = armR.rotation.x = 2.6 * k;
  } else if (pose === "strike") {
    armL.rotation.x = armR.rotation.x = 2.6 - 2.9 * k;
  } else if (pose === "cast") {
    armL.rotation.x = -s * 0.5;
    armR.rotation.x = 0.5 + 1.1 * k;
  } else {
    armL.rotation.x = -s + (m.reach || 0);
    armR.rotation.x = s + (m.reach || 0);
  }
  if (m.orb) m.orb.rotation.y += dt * 3;
}

export function disposeGroup(g) {
  const own = g.userData && g.userData.ownMats;
  g.traverse((o) => {
    if (o.isSprite && o.material && o.material.map) { o.material.map.dispose(); o.material.dispose(); }
    if (own && o.isMesh) {
      o.geometry.dispose();
      for (const m of Array.isArray(o.material) ? o.material : [o.material]) { if (m.map) m.map.dispose(); m.dispose(); }
    }
  });
}

const CONE = new THREE.ConeGeometry(0.75, 1, 8);

// ------------------------------------------------------------------ effects

const tmp = new THREE.Vector3();

export class Effects {
  constructor(scene) {
    this.scene = scene;
    this.parts = [];
    this.free = [];
    this.tele = [];
    this.waves = [];
    // swing arc
    const arcGeo = new THREE.RingGeometry(2.2, 7.5, 20, 1, Math.PI / 2 - 1.1, 2.2);
    arcGeo.rotateX(-Math.PI / 2);
    this.arcMat = new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0, depthWrite: false, side: THREE.DoubleSide });
    this.arc = new THREE.Mesh(arcGeo, this.arcMat);
    this.arc.visible = false;
    scene.add(this.arc);
    this.arcT = 0;
    this.circleGeo = new THREE.CircleGeometry(1, 36).rotateX(-Math.PI / 2);
    this.ringGeo = new THREE.RingGeometry(0.93, 1, 40).rotateX(-Math.PI / 2);
    this.planeGeo = new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2).translate(0, 0, -0.5);
    this.coneGeos = new Map();
    this.teleMats = new Map();
  }

  // ---- particles (little cubes)
  burst(pos, color, n, speed, size) {
    for (let i = 0; i < n; i++) {
      let m = this.free.pop();
      if (!m) { m = new THREE.Mesh(BOX, mat(color)); this.scene.add(m); }
      m.material = mat(color);
      m.visible = true;
      const s = (size || 0.5) * (0.6 + Math.random() * 0.8);
      m.scale.set(s, s, s);
      m.position.copy(pos);
      m.userData.v = new THREE.Vector3((Math.random() - 0.5) * speed, Math.random() * speed * 0.9 + speed * 0.3, (Math.random() - 0.5) * speed);
      m.userData.life = 0.6 + Math.random() * 0.4;
      this.parts.push(m);
    }
  }

  // ---- swing arc
  swing(pos, yaw, color, wide) {
    this.arc.position.set(pos.x, pos.y + 2.4, pos.z);
    this.arc.rotation.y = yaw;
    this.arc.scale.set(wide ? 1.2 : 1, 1, wide ? 1.2 : 1);
    this.arcMat.color.set(color);
    this.arc.visible = true;
    this.arcT = 0.18;
  }

  // ---- expanding ground ring (heal burst, slam impact)
  wave(pos, color, radius, time) {
    const m = new THREE.Mesh(this.ringGeo, new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.8, depthWrite: false }));
    m.position.set(pos.x, pos.y + 0.25, pos.z);
    m.scale.setScalar(0.5);
    this.scene.add(m);
    this.waves.push({ m, r: radius, t: 0, T: time || 0.45 });
  }

  // ---- telegraphs: a faint full shape plus a filling inner shape
  teleMat(color, op) {
    const key = color + op;
    let m = this.teleMats.get(key);
    if (!m) { m = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: op, depthWrite: false, side: THREE.DoubleSide }); this.teleMats.set(key, m); }
    return m;
  }
  coneGeo(arc) {
    const k = Math.round(arc * 100);
    let g = this.coneGeos.get(k);
    if (!g) {
      // centered on -Z (forward)
      g = new THREE.CircleGeometry(1, 24, Math.PI / 2 - arc, arc * 2).rotateX(-Math.PI / 2);
      this.coneGeos.set(k, g);
    }
    return g;
  }
  telegraph(a, y) {
    let geo;
    if (a.s === "circle") geo = this.circleGeo;
    else if (a.s === "cone") geo = this.coneGeo(a.a);
    else geo = this.planeGeo;
    const color = a.c || "#ef4444";
    const outer = new THREE.Mesh(geo, this.teleMat(color, 0.22));
    const inner = new THREE.Mesh(geo, this.teleMat(color, 0.4));
    const g = new THREE.Group();
    g.add(outer, inner);
    g.position.set(a.x, (y || 0) + 0.12, a.z);
    g.rotation.y = a.y || 0;
    if (a.s === "line") { outer.scale.set(a.wd, 1, a.l); inner.scale.set(a.wd, 1, 0.01); }
    else { outer.scale.set(a.r, 1, a.r); inner.scale.set(0.01, 1, 0.01); }
    this.scene.add(g);
    const t = { g, inner, a, t: 0, T: a.w };
    this.tele.push(t);
    return t;
  }

  update(dt) {
    for (let i = this.parts.length - 1; i >= 0; i--) {
      const m = this.parts[i];
      m.userData.life -= dt;
      if (m.userData.life <= 0) { m.visible = false; this.parts.splice(i, 1); this.free.push(m); continue; }
      m.userData.v.y -= 50 * dt;
      m.position.addScaledVector(m.userData.v, dt);
      if (m.position.y < 0.2) { m.position.y = 0.2; m.userData.v.multiplyScalar(0.5); m.userData.v.y = Math.abs(m.userData.v.y) * 0.3; }
      m.rotation.x += dt * 6; m.rotation.y += dt * 5;
      const s = Math.max(0.05, m.scale.x - dt * 0.4);
      m.scale.setScalar(s);
    }
    if (this.arcT > 0) {
      this.arcT -= dt;
      this.arcMat.opacity = Math.max(0, this.arcT / 0.18) * 0.65;
      if (this.arcT <= 0) this.arc.visible = false;
    }
    for (let i = this.waves.length - 1; i >= 0; i--) {
      const w = this.waves[i];
      w.t += dt;
      const k = w.t / w.T;
      w.m.scale.setScalar(0.5 + (w.r - 0.5) * k);
      w.m.material.opacity = 0.8 * (1 - k);
      if (k >= 1) { this.scene.remove(w.m); w.m.material.dispose(); this.waves.splice(i, 1); }
    }
    for (let i = this.tele.length - 1; i >= 0; i--) {
      const t = this.tele[i];
      t.t += dt;
      const k = Math.min(1, t.t / t.T);
      if (t.a.s === "line") t.inner.scale.set(t.a.wd, 1, Math.max(0.01, t.a.l * k));
      else t.inner.scale.set(Math.max(0.01, t.a.r * k), 1, Math.max(0.01, t.a.r * k));
      if (t.t >= t.T + 0.08) { this.scene.remove(t.g); this.tele.splice(i, 1); }
    }
  }

  clear() {
    for (const t of this.tele) this.scene.remove(t.g);
    this.tele.length = 0;
    for (const w of this.waves) { this.scene.remove(w.m); w.m.material.dispose(); }
    this.waves.length = 0;
    for (const m of this.parts) { m.visible = false; this.free.push(m); }
    this.parts.length = 0;
  }
}

// ------------------------------------------------------------------ projectiles

const ORB = new THREE.OctahedronGeometry(0.75, 0);
export function makeOrb(color) {
  const g = new THREE.Group();
  const core = new THREE.Mesh(ORB, mat(color, true));
  const shell = new THREE.Mesh(BOX, mat("#ffffff", true));
  shell.scale.setScalar(0.45);
  g.add(core, shell);
  return g;
}

// ------------------------------------------------------------------ loot

export function makeDrop(color) {
  const g = new THREE.Group();
  const cube = box(g, 1.1, 1.1, 1.1, color, 0, 1.2, 0, true);
  cube.rotation.set(0.6, 0.6, 0);
  const beam = new THREE.Mesh(BOX, new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.35, depthWrite: false }));
  beam.scale.set(0.5, 14, 0.5);
  beam.position.y = 7;
  g.add(beam);
  g.userData.cube = cube;
  g.userData.beam = beam;
  return g;
}

export function makeChest(boss) {
  const g = new THREE.Group();
  const wood = boss ? "#7c3aed" : "#8b5a2b";
  const trim = "#facc15";
  box(g, 3.2, 1.8, 2.2, wood, 0, 0.9, 0);
  box(g, 3.3, 0.3, 2.3, trim, 0, 1.0, 0);
  const lid = new THREE.Group();
  lid.position.set(0, 1.8, 1.1);
  box(lid, 3.2, 0.8, 2.2, wood, 0, 0.4, -1.1);
  box(lid, 0.5, 0.6, 0.2, trim, 0, 0.1, -2.25);
  g.add(lid);
  g.userData.lid = lid;
  return g;
}

export function projectToScreen(v, camera, out) {
  tmp.copy(v).project(camera);
  out.x = (tmp.x + 1) / 2 * innerWidth;
  out.y = (1 - tmp.y) / 2 * innerHeight;
  out.vis = tmp.z < 1 && tmp.z > -1;
  return out;
}
