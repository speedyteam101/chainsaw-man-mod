// Survival Island: monsters (night) and animals (day). The host simulates them; everyone else draws
// what the host shares.
import { THREE } from "../kit3d.js";

export const MOBS = {
  shade:   { name: "Shade",   monster: true, hp: 14, speed: 8.5, dmg: 12, cd: 1.2, h: 5.2, reach: 3.4 },
  crawler: { name: "Crawler", monster: true, hp: 8,  speed: 12,  dmg: 7,  cd: 0.9, h: 1.8, reach: 3.0 },
  pig:     { name: "Pig",     monster: false, hp: 6, speed: 4.5, flee: 11, h: 2.6, drop: ["raw_meat", 2] },
  chicken: { name: "Chicken", monster: false, hp: 3, speed: 4,   flee: 10, h: 2.0, drop: ["raw_meat", 1] },
};
export const MOB_TYPES = Object.keys(MOBS);

function boxMesh(group, sx, sy, sz, x, y, z, color, glow) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, sz), glow ? new THREE.MeshBasicMaterial({ color }) : new THREE.MeshLambertMaterial({ color }));
  m.position.set(x, y, z);
  m.castShadow = !glow;
  group.add(m);
  return m;
}
function leg(group, sx, sy, sz, x, y, z, color) {
  const pivot = new THREE.Group();
  pivot.position.set(x, y, z);
  const m = boxMesh(pivot, sx, sy, sz, 0, -sy / 2, 0, color);
  m.castShadow = true;
  group.add(pivot);
  return pivot;
}

export function mobModel(world, type) {
  let root;
  if (type === "shade") {
    root = world.character({ head: "#55733a", torso: "#2b3645", arms: "#55733a", legs: "#1d2430", face: "determined", hat: "none", shirt: "plain" });
    const head = root.children.find((c) => c.isGroup && c.position.y > 4);
    if (head) { boxMesh(head, 0.28, 0.2, 0.05, -0.28, 0.12, -0.62, "#ff2a2a", true); boxMesh(head, 0.28, 0.2, 0.05, 0.28, 0.12, -0.62, "#ff2a2a", true); }
    // arms forward like a classic monster
    const a = root.userData.animate;
    root.userData.animate = (dt, speed, air) => { a(dt, speed, air); root.userData.limbs.armL.rotation.x = 1.4 + Math.sin(performance.now() / 300) * 0.1; root.userData.limbs.armR.rotation.x = 1.4 - Math.sin(performance.now() / 300) * 0.1; };
    return root;
  }
  root = new THREE.Group();
  world.scene.add(root);
  const legs = [];
  if (type === "crawler") {
    boxMesh(root, 2.6, 1.1, 3.0, 0, 1.3, 0.2, "#3b2a4f");
    boxMesh(root, 1.6, 1.0, 1.3, 0, 1.4, -1.7, "#4c3766");
    boxMesh(root, 0.3, 0.25, 0.05, -0.4, 1.55, -2.37, "#ff2a2a", true);
    boxMesh(root, 0.3, 0.25, 0.05, 0.4, 1.55, -2.37, "#ff2a2a", true);
    for (let s of [-1, 1]) for (let n = 0; n < 3; n++) {
      const l = leg(root, 0.35, 1.6, 0.35, s * 1.35, 1.5, -0.7 + n * 1.0, "#2a1d3a");
      l.rotation.z = s * 0.9;
      legs.push(l);
    }
  } else if (type === "pig") {
    boxMesh(root, 2.2, 1.6, 3.2, 0, 1.9, 0, "#f4a6b8");
    boxMesh(root, 1.6, 1.4, 1.3, 0, 2.3, -2.1, "#f4a6b8");
    boxMesh(root, 0.8, 0.5, 0.3, 0, 2.05, -2.85, "#e3879c");
    boxMesh(root, 0.2, 0.2, 0.05, -0.4, 2.65, -2.77, "#111111", true);
    boxMesh(root, 0.2, 0.2, 0.05, 0.4, 2.65, -2.77, "#111111", true);
    for (const [x, z] of [[-0.6, -1], [0.6, -1], [-0.6, 1], [0.6, 1]]) legs.push(leg(root, 0.6, 1.1, 0.6, x, 1.1, z, "#e893a8"));
  } else {
    boxMesh(root, 1.2, 1.1, 1.6, 0, 1.55, 0, "#f8fafc");
    boxMesh(root, 0.8, 0.9, 0.8, 0, 2.4, -0.7, "#f8fafc");
    boxMesh(root, 0.35, 0.25, 0.4, 0, 2.35, -1.25, "#f59e0b");
    boxMesh(root, 0.2, 0.35, 0.5, 0, 2.95, -0.7, "#dc2626");
    boxMesh(root, 0.15, 0.15, 0.05, -0.25, 2.55, -1.11, "#111111", true);
    boxMesh(root, 0.15, 0.15, 0.05, 0.25, 2.55, -1.11, "#111111", true);
    for (const x of [-0.3, 0.3]) legs.push(leg(root, 0.2, 1.0, 0.2, x, 1.0, 0, "#f59e0b"));
  }
  let phase = 0;
  root.userData.animate = (dt, speed) => {
    if (speed > 0.3) phase += dt * speed * 1.2; else phase *= 0.9;
    legs.forEach((l, n) => { l.rotation.x = Math.sin(phase + (n % 2) * Math.PI + (type === "crawler" ? n : 0)) * 0.7; });
  };
  return root;
}

function setFlash(model, on) {
  model.traverse((m) => {
    if (!m.isMesh || !m.material || !m.material.emissive) return;
    const mats = Array.isArray(m.material) ? m.material : [m.material];
    for (const mat of mats) if (mat.emissive) mat.emissive.setHex(on ? 0x992222 : 0x000000);
  });
}

export class Mob {
  constructor(world, id, type, x, y, z) {
    this.id = id;
    this.type = type;
    this.def = MOBS[type];
    this.x = x; this.y = y; this.z = z; this.yaw = Math.random() * 6.28;
    this.tx = x; this.ty = y; this.tz = z; this.tyaw = this.yaw;
    this.hp = this.def.hp;
    this.atk = 0;
    this.wander = 0;
    this.wdir = Math.random() * 6.28;
    this.flee = 0;
    this.hurt = 0;
    this.speed = 0;
    this.stuck = 0;
    this.model = mobModel(world, type);
    if (Mob.blob) this.model.add(Mob.blob(type === "shade" ? 3 : type === "chicken" ? 1.8 : 3.4));
    this.model.position.set(x, y, z);
    // materials are shared by mobs of the same kind; give each its own so hit flashes stay local
    this.model.traverse((m) => { if (m.isMesh && m.material && !Array.isArray(m.material) && m.material.emissive) m.material = m.material.clone(); else if (m.isMesh && Array.isArray(m.material)) m.material = m.material.map((x) => x.clone()); });
  }
  flash() { this.hurt = 0.18; setFlash(this.model, true); }
  draw(dt, remote) {
    if (remote) {
      const f = Math.min(1, dt * 10);
      const ox = this.x, oz = this.z;
      this.x += (this.tx - this.x) * f; this.y += (this.ty - this.y) * f; this.z += (this.tz - this.z) * f;
      let d = this.tyaw - this.yaw; d = Math.atan2(Math.sin(d), Math.cos(d)); this.yaw += d * f;
      this.speed = dt > 0 ? Math.hypot(this.x - ox, this.z - oz) / dt : 0;
    }
    this.model.position.set(this.x, this.y, this.z);
    this.model.rotation.y = this.yaw;
    this.model.userData.animate(dt, this.speed, false);
    if (this.hurt > 0) { this.hurt -= dt; if (this.hurt <= 0) setFlash(this.model, false); }
  }
}
