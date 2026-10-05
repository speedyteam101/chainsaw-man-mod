/*
 * BlockOS 3D kit: Roblox-style 3D worlds for BlockOS games. ES module; needs kit.js loaded first.
 *
 *   <link rel="stylesheet" href="../kit.css">
 *   <script src="../kit.js"></script>
 *   <script type="module">
 *     import { World, THREE } from "../kit3d.js";
 *     const world = new World({ sky: "#8fd3ff" });
 *     world.baseplate(256);
 *     world.part({ size: [8, 1, 8], pos: [0, 6, -20], color: "#ef4444" });
 *     const me = world.spawnPlayer({ pos: [0, 3, 0] });
 *     world.start((dt) => { ... your game logic ... });
 *   </script>
 *
 * Units are studs. The player is 5.2 studs tall, walks at 16 studs/s and jumps 7 studs high.
 * Controls: WASD / Up-Down to walk, Space to jump, Left-Right arrows or drag the mouse to turn
 * the camera, mouse wheel (or I / O) to zoom, Shift to toggle shift lock (camera follows the mouse).
 *
 * world.part(opts) -> THREE.Mesh. opts:
 *   size [x,y,z], pos [x,y,z] (center), color, rot [x,y,z] radians, material "plastic" | "neon" | "glass" | "wood",
 *   collide (default true), kill (touching it kills), studs (default true; studs on top),
 *   moving (set true if you move it each frame; players standing on it ride along),
 *   onTouch(player, part) called once each time the player starts touching it.
 * world.remove(part), world.touching(part) -> bool
 * world.spawnPlayer({ pos, look, name }) -> player { pos, vel, onGround, yaw, health, alive, group }
 * world.checkpoint([x,y,z]) sets where you respawn.  world.kill() kills the player (respawns in 2 s).
 * world.damage(n) / world.heal(n) with a health bar when World({ health: true }).
 * world.character(look, name) -> a standalone avatar model (for NPCs); call model.userData.animate(dt, speed, inAir).
 * world.online(net) shows other players (from Kit.net) as avatars with name tags and chat bubbles,
 *   and shares your own position. world.bubble(model, text) shows a chat bubble over any model.
 * world.label(text, opts) -> a sprite with text (signs, floating labels).
 * world.start(update) starts the game loop; update(dt) runs every frame before physics.
 * world.onDeath(fn), world.onRespawn(fn)
 * world.camera, world.scene, world.renderer are the three.js objects if you need more.
 */
import * as THREE from "./lib/three.min.js";

export { THREE };

const GRAVITY = 196.2;
const WALK_SPEED = 16;
const JUMP_VELOCITY = 52;
const HALF = new THREE.Vector3(0.95, 2.6, 0.95);   // player half-size (box around the character)
const STEP_UP = 1.1;   // walk up 1-stud steps without jumping

// ------------------------------------------------------------------ textures & materials

function studTexture() {
  const c = document.createElement("canvas");
  c.width = c.height = 64;
  const g = c.getContext("2d");
  g.fillStyle = "#ffffff";
  g.fillRect(0, 0, 64, 64);
  const grad = g.createRadialGradient(28, 28, 4, 32, 32, 20);
  grad.addColorStop(0, "#ffffff");
  grad.addColorStop(1, "#d4d4d4");
  g.fillStyle = "rgba(0,0,0,.12)";
  g.beginPath(); g.arc(33, 34, 19, 0, Math.PI * 2); g.fill();
  g.fillStyle = grad;
  g.beginPath(); g.arc(32, 32, 18, 0, Math.PI * 2); g.fill();
  g.strokeStyle = "rgba(0,0,0,.08)";
  g.lineWidth = 2;
  g.strokeRect(0, 0, 64, 64);
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  return t;
}

function woodTexture() {
  const c = document.createElement("canvas");
  c.width = c.height = 64;
  const g = c.getContext("2d");
  g.fillStyle = "#ffffff";
  g.fillRect(0, 0, 64, 64);
  g.strokeStyle = "rgba(0,0,0,.12)";
  for (let y = 4; y < 64; y += 9) { g.beginPath(); g.moveTo(0, y); g.bezierCurveTo(20, y + 3, 40, y - 3, 64, y + 1); g.stroke(); }
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

let STUDS = null, WOOD = null;
const materialCache = new Map();

function materialsFor(color, kind, studs) {
  const key = color + "|" + kind + "|" + studs;
  if (materialCache.has(key)) return materialCache.get(key);
  STUDS = STUDS || studTexture();
  WOOD = WOOD || woodTexture();
  let side, top;
  if (kind === "neon") {
    side = top = new THREE.MeshBasicMaterial({ color });
  } else if (kind === "glass") {
    side = top = new THREE.MeshLambertMaterial({ color, transparent: true, opacity: 0.4 });
  } else if (kind === "wood") {
    side = top = new THREE.MeshLambertMaterial({ color, map: WOOD });
  } else {
    side = new THREE.MeshLambertMaterial({ color });
    top = studs ? new THREE.MeshLambertMaterial({ color, map: STUDS }) : side;
  }
  // BoxGeometry face order: +x, -x, +y (top), -y, +z, -z
  const mats = [side, side, top, side, side, side];
  materialCache.set(key, mats);
  return mats;
}

// Box with UVs scaled so textures repeat once per stud instead of stretching.
function boxGeometry(sx, sy, sz) {
  const geo = new THREE.BoxGeometry(sx, sy, sz);
  const uv = geo.attributes.uv;
  const dims = [[sz, sy], [sz, sy], [sx, sz], [sx, sz], [sx, sy], [sx, sy]];
  for (let face = 0; face < 6; face++) {
    for (let i = 0; i < 4; i++) {
      const idx = face * 4 + i;
      uv.setXY(idx, uv.getX(idx) * dims[face][0], uv.getY(idx) * dims[face][1]);
    }
  }
  return geo;
}

// ------------------------------------------------------------------ characters

const FACE_ART = {
  smile(g) { eyes(g); g.beginPath(); g.arc(64, 70, 22, 0.15 * Math.PI, 0.85 * Math.PI); g.stroke(); },
  grin(g) { eyes(g); g.fillStyle = "#111"; g.beginPath(); g.moveTo(34, 70); g.lineTo(94, 70); g.quadraticCurveTo(64, 108, 34, 70); g.fill(); g.fillStyle = "#fff"; g.fillRect(40, 72, 48, 6); },
  wink(g) { g.fillRect(40, 40, 12, 18); g.fillRect(74, 48, 20, 6); g.beginPath(); g.arc(64, 70, 22, 0.15 * Math.PI, 0.85 * Math.PI); g.stroke(); },
  wow(g) { g.beginPath(); g.arc(46, 48, 10, 0, 7); g.arc(82, 48, 10, 0, 7); g.fill(); g.beginPath(); g.ellipse(64, 86, 10, 13, 0, 0, 7); g.fill(); },
  cool(g) { g.fillRect(26, 38, 76, 22); g.beginPath(); g.arc(64, 72, 20, 0.2 * Math.PI, 0.8 * Math.PI); g.stroke(); },
  determined(g) { g.beginPath(); g.moveTo(32, 34); g.lineTo(54, 42); g.moveTo(96, 34); g.lineTo(74, 42); g.stroke(); g.fillRect(40, 46, 12, 14); g.fillRect(76, 46, 12, 14); g.fillRect(44, 84, 40, 7); },
  robot(g) { g.fillStyle = "#0f172a"; g.fillRect(24, 36, 80, 28); g.fillStyle = "#22d3ee"; g.fillRect(30, 42, 68, 14); g.fillStyle = "#0f172a"; g.fillRect(40, 80, 48, 12); },
};
function eyes(g) { g.fillRect(40, 40, 12, 18); g.fillRect(76, 40, 12, 18); }

function faceTexture(look) {
  const c = document.createElement("canvas");
  c.width = c.height = 128;
  const g = c.getContext("2d");
  g.fillStyle = look.head;
  g.fillRect(0, 0, 128, 128);
  g.fillStyle = "#111";
  g.strokeStyle = "#111";
  g.lineWidth = 7;
  g.lineCap = "round";
  (FACE_ART[look.face] || FACE_ART.smile)(g);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

function shirtTexture(look) {
  if (!look.shirt || look.shirt === "plain") return null;
  const c = document.createElement("canvas");
  c.width = c.height = 128;
  const g = c.getContext("2d");
  g.fillStyle = look.torso;
  g.fillRect(0, 0, 128, 128);
  const star = (cx, cy, r, color) => {
    g.fillStyle = color;
    g.beginPath();
    for (let i = 0; i < 10; i++) {
      const a = -Math.PI / 2 + (i * Math.PI) / 5, rr = i % 2 ? r * 0.45 : r;
      g.lineTo(cx + Math.cos(a) * rr, cy + Math.sin(a) * rr);
    }
    g.fill();
  };
  switch (look.shirt) {
    case "stripes": g.fillStyle = "rgba(255,255,255,.3)"; for (let y = 10; y < 128; y += 28) g.fillRect(0, y, 128, 12); break;
    case "star": star(64, 64, 40, "#facc15"); break;
    case "brick": [["#ef4444", 30, 30], ["#facc15", 66, 30], ["#3b82f6", 30, 66], ["#22c55e", 66, 66]].forEach(([col, x, y]) => { g.fillStyle = col; g.fillRect(x, y, 32, 32); }); break;
    case "bolt": g.fillStyle = "#facc15"; g.beginPath(); g.moveTo(74, 8); g.lineTo(34, 70); g.lineTo(62, 70); g.lineTo(50, 120); g.lineTo(96, 52); g.lineTo(68, 52); g.fill(); break;
    case "suit": g.fillStyle = "#1f2328"; g.fillRect(0, 0, 128, 128); g.fillStyle = "#fff"; g.beginPath(); g.moveTo(44, 0); g.lineTo(84, 0); g.lineTo(64, 40); g.fill(); g.fillStyle = "#ef4444"; g.fillRect(59, 18, 10, 60); break;
  }
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

function hatModel(kind) {
  const grp = new THREE.Group();
  const add = (geo, color, x, y, z, rx) => {
    const m = new THREE.Mesh(geo, new THREE.MeshLambertMaterial({ color }));
    m.position.set(x, y, z);
    if (rx) m.rotation.x = rx;
    m.castShadow = true;
    grp.add(m);
    return m;
  };
  switch (kind) {
    case "cap": add(new THREE.BoxGeometry(1.3, 0.45, 1.3), "#2563eb", 0, 0.2, 0); add(new THREE.BoxGeometry(1.2, 0.12, 0.7), "#1d4ed8", 0, 0.02, -0.9); break;
    case "tophat": add(new THREE.CylinderGeometry(0.55, 0.55, 1.2, 16), "#1f2328", 0, 0.6, 0); add(new THREE.CylinderGeometry(0.9, 0.9, 0.1, 16), "#111111", 0, 0.05, 0); add(new THREE.CylinderGeometry(0.56, 0.56, 0.2, 16), "#ef4444", 0, 0.25, 0); break;
    case "crown": for (let i = 0; i < 5; i++) { const a = (i / 5) * Math.PI * 2; add(new THREE.ConeGeometry(0.18, 0.5, 4), "#facc15", Math.cos(a) * 0.5, 0.35, Math.sin(a) * 0.5); } add(new THREE.CylinderGeometry(0.65, 0.65, 0.25, 16), "#facc15", 0, 0.12, 0); break;
    case "cone": add(new THREE.ConeGeometry(0.62, 1.5, 16), "#fb923c", 0, 0.75, 0); add(new THREE.CylinderGeometry(0.38, 0.45, 0.2, 16), "#ffffff", 0, 0.75, 0); add(new THREE.BoxGeometry(1.4, 0.12, 1.4), "#ea580c", 0, 0.03, 0); break;
    case "wizard": add(new THREE.ConeGeometry(0.75, 2, 16), "#7c3aed", 0, 1, 0); add(new THREE.CylinderGeometry(1.0, 1.0, 0.1, 16), "#5b21b6", 0, 0.03, 0); break;
    case "headphones": add(new THREE.TorusGeometry(0.72, 0.09, 8, 20, Math.PI), "#1f2328", 0, -0.45, 0); add(new THREE.BoxGeometry(0.25, 0.55, 0.55), "#ef4444", -0.72, -0.5, 0); add(new THREE.BoxGeometry(0.25, 0.55, 0.55), "#ef4444", 0.72, -0.5, 0); break;
    default: return null;
  }
  return grp;
}

function textSprite(text, opts) {
  const o = opts || {};
  const size = o.size || 48;
  const c = document.createElement("canvas");
  const g = c.getContext("2d");
  const font = `800 ${size}px "Noto Sans", "DejaVu Sans", sans-serif`;
  g.font = font;
  const w = Math.ceil(g.measureText(text).width) + size;
  c.width = w;
  c.height = Math.ceil(size * 1.6);
  g.font = font;
  if (o.bg) {
    g.fillStyle = o.bg;
    g.beginPath();
    g.roundRect(0, 0, c.width, c.height, size * 0.4);
    g.fill();
  }
  g.textAlign = "center";
  g.textBaseline = "middle";
  g.lineWidth = size / 6;
  g.strokeStyle = o.outline || "rgba(0,0,0,.65)";
  if (!o.bg) g.strokeText(text, c.width / 2, c.height / 2);
  g.fillStyle = o.color || "#ffffff";
  g.fillText(text, c.width / 2, c.height / 2);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: t, depthTest: o.depthTest !== false, transparent: true }));
  const h = o.height || 0.9;
  s.scale.set((h * c.width) / c.height, h, 1);
  return s;
}

// Builds the classic 6-part character. Origin at the feet, facing -Z (the face and shirt are on the -Z side).
export function createCharacter(look, name) {
  const a = Object.assign({}, (window.Kit && Kit.DEFAULT_LOOK) || {}, look || {});
  const root = new THREE.Group();
  const mat = (color) => new THREE.MeshLambertMaterial({ color });
  const box = (w, h, d, m) => {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m);
    mesh.castShadow = true;
    return mesh;
  };
  const limb = (w, h, color, x, y) => {
    const pivot = new THREE.Group();
    pivot.position.set(x, y, 0);
    const m = box(w, h, 1, mat(color));
    m.position.y = -h / 2;
    pivot.add(m);
    root.add(pivot);
    return pivot;
  };
  const legL = limb(0.98, 2, a.legs, -0.5, 2);
  const legR = limb(0.98, 2, a.legs, 0.5, 2);
  const armL = limb(0.98, 2, a.arms, -1.5, 4);
  const armR = limb(0.98, 2, a.arms, 1.5, 4);
  const shirt = shirtTexture(a);
  const torsoMat = mat(a.torso);
  const torsoFront = shirt ? new THREE.MeshLambertMaterial({ map: shirt }) : torsoMat;
  const torso = new THREE.Mesh(new THREE.BoxGeometry(2, 2, 1), [torsoMat, torsoMat, torsoMat, torsoMat, torsoMat, torsoFront]);
  torso.castShadow = true;
  torso.position.y = 3;
  root.add(torso);
  const head = new THREE.Group();
  head.position.y = 4.6;
  const headMat = mat(a.head);
  const faceMat = new THREE.MeshLambertMaterial({ map: faceTexture(a) });
  const headMesh = new THREE.Mesh(new THREE.BoxGeometry(1.2, 1.2, 1.2), [headMat, headMat, headMat, headMat, headMat, faceMat]);
  headMesh.castShadow = true;
  head.add(headMesh);
  const hat = hatModel(a.hat);
  if (hat) { hat.position.y = 0.6; head.add(hat); }
  root.add(head);
  if (name) {
    const tag = textSprite(name, { height: 0.8 });
    tag.position.y = 6.2;
    root.add(tag);
    root.userData.nameTag = tag;
  }
  let phase = 0;
  root.userData.limbs = { legL, legR, armL, armR };
  root.userData.animate = (dt, speed, inAir) => {
    if (inAir) {
      legL.rotation.x = 0.3; legR.rotation.x = -0.3;
      armL.rotation.x = armR.rotation.x = Math.PI * 0.85;   // arms up, like the classic jump pose
      return;
    }
    if (speed > 0.5) phase += dt * speed * 0.6;
    else phase *= 0.85;
    const s = Math.sin(phase) * Math.min(1, speed / WALK_SPEED) * 0.9;
    legL.rotation.x = s; legR.rotation.x = -s;
    armL.rotation.x = -s; armR.rotation.x = s;
  };
  return root;
}

// ------------------------------------------------------------------ the world

export class World {
  constructor(opts) {
    const o = opts || {};
    this.opts = o;
    this.parts = [];
    this.solids = [];
    this.movers = [];
    this.touchers = [];
    this.player = null;
    this.spawn = new THREE.Vector3(0, 3, 0);
    this.voidY = o.voidY ?? -60;
    this.deathHandlers = [];
    this.respawnHandlers = [];
    this.remotes = new Map();
    this.bubbles = [];

    let renderer;
    try {
      renderer = new THREE.WebGLRenderer({ antialias: true });
    } catch (e) {
      if (window.Kit) Kit.overlay("3D isn't available", "This computer couldn't start 3D graphics, so this game can't run here.\nTry turning on 3D acceleration in your virtual machine's display settings.", "OK");
      throw e;
    }
    renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
    renderer.setSize(innerWidth, innerHeight);
    renderer.shadowMap.enabled = o.shadows !== false;
    renderer.shadowMap.type = THREE.PCFShadowMap;
    renderer.domElement.className = "kit-3d";
    document.body.appendChild(renderer.domElement);
    this.renderer = renderer;
    this.pixelRatio = renderer.getPixelRatio();

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(o.sky || "#8fd3ff");
    if (o.fog !== false) scene.fog = new THREE.Fog(o.fogColor || o.sky || "#8fd3ff", o.fogNear || 250, o.fogFar || 700);
    this.scene = scene;

    const hemi = new THREE.HemisphereLight(0xffffff, 0x8a7a66, o.dark ? 0.5 : 1.15);
    scene.add(hemi);
    const sun = new THREE.DirectionalLight(0xffffff, o.dark ? 0.6 : 1.6);
    sun.position.set(60, 120, 40);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    const sc = sun.shadow.camera;
    sc.left = sc.bottom = -90;
    sc.right = sc.top = 90;
    sc.near = 10;
    sc.far = 400;
    scene.add(sun, sun.target);
    this.sun = sun;
    this.hemi = hemi;

    const camera = new THREE.PerspectiveCamera(70, innerWidth / innerHeight, 0.1, 2000);
    this.camera = camera;
    this.cam = { yaw: 0, pitch: 0.35, dist: o.cameraDistance || 16, shiftLock: false };

    addEventListener("resize", () => {
      renderer.setSize(innerWidth, innerHeight);
      camera.aspect = innerWidth / innerHeight;
      camera.updateProjectionMatrix();
    });
    this.setupInput();
    if (o.health) this.healthBar();
  }

  // ---------------------------------------------------------------- building

  part(opts) {
    const o = Object.assign({ size: [4, 1, 2], pos: [0, 0, 0], color: "#a3a2a5", material: "plastic", collide: true, studs: true }, opts);
    const [sx, sy, sz] = o.size;
    const mesh = new THREE.Mesh(boxGeometry(sx, sy, sz), materialsFor(o.color, o.material, o.studs));
    mesh.position.set(o.pos[0], o.pos[1], o.pos[2]);
    if (o.rot) mesh.rotation.set(o.rot[0], o.rot[1], o.rot[2]);
    mesh.castShadow = o.material !== "glass" && o.shadow !== false;
    mesh.receiveShadow = true;
    const info = {
      size: new THREE.Vector3(sx, sy, sz), collide: o.collide, kill: !!o.kill, moving: !!o.moving,
      onTouch: o.onTouch || null, touching: false, box: new THREE.Box3(), last: mesh.position.clone(), delta: new THREE.Vector3(),
      tag: o.tag,
    };
    mesh.userData.part = info;
    this.updateBox(mesh);
    this.scene.add(mesh);
    this.parts.push(mesh);
    if (info.collide) this.solids.push(mesh);
    if (info.moving) this.movers.push(mesh);
    if (info.kill || info.onTouch) this.touchers.push(mesh);
    return mesh;
  }

  remove(mesh) {
    this.scene.remove(mesh);
    for (const list of [this.parts, this.solids, this.movers, this.touchers]) {
      const i = list.indexOf(mesh);
      if (i >= 0) list.splice(i, 1);
    }
  }

  updateBox(mesh) {
    const info = mesh.userData.part;
    if (mesh.rotation.x || mesh.rotation.y || mesh.rotation.z) info.box.setFromObject(mesh);
    else info.box.setFromCenterAndSize(mesh.position, info.size);
  }

  baseplate(size, color) {
    return this.part({ size: [size, 2, size], pos: [0, -1, 0], color: color || "#4b9b3f" });
  }

  spawnPad(pos) {
    this.part({ size: [6, 1, 6], pos: [pos[0], pos[1] - 0.5, pos[2]], color: "#2b2f35" });
    this.part({ size: [4, 0.2, 4], pos: [pos[0], pos[1] + 0.1, pos[2]], color: "#facc15", material: "neon", collide: false, studs: false });
    this.checkpoint([pos[0], pos[1] + 0.5, pos[2]]);
  }

  label(text, opts) {
    const s = textSprite(text, opts);
    if (opts && opts.pos) s.position.set(...opts.pos);
    this.scene.add(s);
    return s;
  }

  character(look, name) {
    const c = createCharacter(look, name);
    c.traverse((m) => { if (m.isMesh) m.castShadow = true; });
    this.scene.add(c);
    return c;
  }

  bubble(model, text) {
    if (model.userData.bubble) model.remove(model.userData.bubble);
    const s = textSprite(text, { bg: "rgba(255,255,255,.95)", color: "#111", height: 1.1, size: 40 });
    s.position.y = 7.4;
    model.add(s);
    model.userData.bubble = s;
    setTimeout(() => { if (model.userData.bubble === s) { model.remove(s); model.userData.bubble = null; } }, 5000);
  }

  // ---------------------------------------------------------------- player

  spawnPlayer(opts) {
    const o = opts || {};
    const me = window.Kit ? Kit.player() : { name: "Player", avatar: {} };
    const group = this.character(o.look || me.avatar, o.showName ? o.name || me.name : null);
    if (o.pos) this.spawn.set(...o.pos);
    this.player = {
      group, name: o.name || me.name, look: o.look || me.avatar,
      pos: this.spawn.clone(), vel: new THREE.Vector3(), yaw: 0, onGround: false, standingOn: null,
      health: 100, maxHealth: 100, alive: true, speed: o.speed || WALK_SPEED, jump: o.jump || JUMP_VELOCITY,
      frozen: false,
    };
    this.cam.yaw = o.yaw || 0;
    this.player.yaw = this.cam.yaw;
    this.syncPlayer();
    return this.player;
  }

  checkpoint(pos) { this.spawn.set(pos[0], pos[1], pos[2]); }
  onDeath(fn) { this.deathHandlers.push(fn); }
  onRespawn(fn) { this.respawnHandlers.push(fn); }

  kill() {
    const p = this.player;
    if (!p || !p.alive) return;
    p.alive = false;
    p.health = 0;
    this.updateHealthBar();
    if (window.Kit) Kit.sfx("lose");
    // Fall apart into pieces, the classic way.
    const pieces = [];
    p.group.updateMatrixWorld(true);
    p.group.traverse((m) => {
      if (!m.isMesh) return;
      const wp = new THREE.Vector3(); m.getWorldPosition(wp);
      const clone = new THREE.Mesh(m.geometry, m.material);
      clone.position.copy(wp);
      m.getWorldQuaternion(clone.quaternion);
      clone.castShadow = true;
      clone.userData.v = new THREE.Vector3((Math.random() - 0.5) * 22, Math.random() * 18 + 6, (Math.random() - 0.5) * 22);
      clone.userData.spin = new THREE.Vector3(Math.random() * 6, Math.random() * 6, Math.random() * 6);
      this.scene.add(clone);
      pieces.push(clone);
    });
    p.group.visible = false;
    this.debris = pieces;
    this.deathHandlers.forEach((fn) => fn(p));
    setTimeout(() => this.respawn(), 2000);
  }

  respawn() {
    const p = this.player;
    (this.debris || []).forEach((m) => this.scene.remove(m));
    this.debris = null;
    p.pos.copy(this.spawn);
    p.vel.set(0, 0, 0);
    p.health = p.maxHealth;
    p.alive = true;
    p.group.visible = true;
    this.updateHealthBar();
    this.respawnHandlers.forEach((fn) => fn(p));
  }

  damage(n) {
    const p = this.player;
    if (!p || !p.alive) return;
    p.health = Math.max(0, p.health - n);
    this.updateHealthBar();
    if (p.health <= 0) this.kill();
  }

  heal(n) {
    const p = this.player;
    if (!p || !p.alive) return;
    p.health = Math.min(p.maxHealth, p.health + n);
    this.updateHealthBar();
  }

  healthBar() {
    const el = document.createElement("div");
    el.className = "kit-health";
    el.innerHTML = "<i></i>";
    document.body.appendChild(el);
    this.healthEl = el;
  }

  updateHealthBar() {
    if (!this.healthEl || !this.player) return;
    const f = this.player.health / this.player.maxHealth;
    const bar = this.healthEl.firstChild;
    bar.style.width = f * 100 + "%";
    bar.style.background = f > 0.5 ? "#22c55e" : f > 0.25 ? "#facc15" : "#ef4444";
  }

  touching(mesh) {
    const p = this.player;
    if (!p || !p.alive) return false;
    const info = mesh.userData.part;
    const center = new THREE.Vector3(p.pos.x, p.pos.y + HALF.y, p.pos.z);
    if (!(mesh.rotation.x || mesh.rotation.y || mesh.rotation.z)) {
      const b = info ? info.box : new THREE.Box3().setFromObject(mesh);
      const e = 0.12;   // standing on or leaning against a part counts as touching it
      return center.x + HALF.x > b.min.x - e && center.x - HALF.x < b.max.x + e &&
        center.y + HALF.y > b.min.y - e && center.y - HALF.y < b.max.y + e &&
        center.z + HALF.z > b.min.z - e && center.z - HALF.z < b.max.z + e;
    }
    // Rotated part: test in the part's own space (good for spinning bars).
    const local = mesh.worldToLocal(center.clone());
    const s = info ? info.size : new THREE.Vector3(1, 1, 1);
    return Math.abs(local.x) < s.x / 2 + HALF.x * 0.8 && Math.abs(local.y) < s.y / 2 + HALF.y * 0.8 && Math.abs(local.z) < s.z / 2 + HALF.z * 0.8;
  }

  // ---------------------------------------------------------------- input & camera

  setupInput() {
    const el = this.renderer.domElement;
    let dragging = false, lastX = 0, lastY = 0;
    el.addEventListener("contextmenu", (e) => e.preventDefault());
    el.addEventListener("pointerdown", (e) => {
      if (this.opts.cameraButton === "right" && e.button !== 2) return;
      dragging = true; lastX = e.clientX; lastY = e.clientY;
      el.setPointerCapture(e.pointerId);
    });
    el.addEventListener("pointermove", (e) => {
      if (this.cam.shiftLock && document.pointerLockElement === el) {
        this.cam.yaw -= e.movementX * 0.005;
        this.cam.pitch = Math.max(-0.3, Math.min(1.35, this.cam.pitch + e.movementY * 0.005));
        return;
      }
      if (!dragging) return;
      this.cam.yaw -= (e.clientX - lastX) * 0.006;
      this.cam.pitch = Math.max(-0.3, Math.min(1.35, this.cam.pitch + (e.clientY - lastY) * 0.006));
      lastX = e.clientX; lastY = e.clientY;
    });
    el.addEventListener("pointerup", () => { dragging = false; });
    el.addEventListener("wheel", (e) => {
      e.preventDefault();
      this.cam.dist = Math.max(4, Math.min(60, this.cam.dist * (e.deltaY > 0 ? 1.12 : 0.89)));
    }, { passive: false });
    if (window.Kit) {
      Kit.onKey((code) => {
        if (code === "KeyI") this.cam.dist = Math.max(4, this.cam.dist * 0.85);
        if (code === "KeyO") this.cam.dist = Math.min(60, this.cam.dist * 1.15);
        if ((code === "ShiftLeft" || code === "ShiftRight") && this.opts.shiftLock !== false) {
          this.cam.shiftLock = !this.cam.shiftLock;
          if (this.cam.shiftLock) el.requestPointerLock?.();
          else if (document.pointerLockElement) document.exitPointerLock();
        }
      });
    }
  }

  key(code) { return window.Kit ? Kit.key(code) : false; }

  // ---------------------------------------------------------------- physics

  collide(p, axis) {
    const min = new THREE.Vector3(p.pos.x - HALF.x, p.pos.y, p.pos.z - HALF.z);
    const max = new THREE.Vector3(p.pos.x + HALF.x, p.pos.y + HALF.y * 2, p.pos.z + HALF.z);
    let hit = null;
    for (const mesh of this.solids) {
      const b = mesh.userData.part.box;
      if (max.x <= b.min.x || min.x >= b.max.x || max.y <= b.min.y || min.y >= b.max.y || max.z <= b.min.z || min.z >= b.max.z) continue;
      if (axis === "y") {
        if (p.vel.y > 0) {
          p.pos.y = b.min.y - HALF.y * 2;   // bumped your head
        } else {
          p.pos.y = b.max.y;                // landed on top
          p.onGround = true;
          p.standingOn = mesh;
        }
        hit = mesh;
        p.vel.y = 0;
        min.y = p.pos.y; max.y = p.pos.y + HALF.y * 2;
      } else {
        // Small ledges: step up instead of stopping.
        const rise = b.max.y - p.pos.y;
        if (rise > 0 && rise <= STEP_UP && p.onGround && !this.blockedAbove(p, b.max.y)) {
          p.pos.y = b.max.y;
          min.y = p.pos.y; max.y = p.pos.y + HALF.y * 2;
          continue;
        }
        if (axis === "x") {
          p.pos.x = p.pos.x > (b.min.x + b.max.x) / 2 ? b.max.x + HALF.x + 0.001 : b.min.x - HALF.x - 0.001;
          min.x = p.pos.x - HALF.x; max.x = p.pos.x + HALF.x;
        } else {
          p.pos.z = p.pos.z > (b.min.z + b.max.z) / 2 ? b.max.z + HALF.z + 0.001 : b.min.z - HALF.z - 0.001;
          min.z = p.pos.z - HALF.z; max.z = p.pos.z + HALF.z;
        }
        hit = mesh;
      }
    }
    return hit;
  }

  blockedAbove(p, y) {
    for (const mesh of this.solids) {
      const b = mesh.userData.part.box;
      if (p.pos.x + HALF.x > b.min.x && p.pos.x - HALF.x < b.max.x && p.pos.z + HALF.z > b.min.z && p.pos.z - HALF.z < b.max.z &&
        y + HALF.y * 2 > b.min.y && y < b.max.y - 0.01 && b.min.y > p.pos.y) return true;
    }
    return false;
  }

  stepPlayer(dt) {
    const p = this.player;
    if (!p || !p.alive) return;
    // Ride moving platforms.
    if (p.onGround && p.standingOn && p.standingOn.userData.part.moving) p.pos.add(p.standingOn.userData.part.delta);

    let fx = 0, fz = 0;
    if (!p.frozen) {
      if (this.key("KeyW") || this.key("ArrowUp")) fz -= 1;
      if (this.key("KeyS") || this.key("ArrowDown")) fz += 1;
      if (this.key("KeyA")) fx -= 1;
      if (this.key("KeyD")) fx += 1;
    }
    if (this.key("ArrowLeft")) this.cam.yaw += dt * 2.6;
    if (this.key("ArrowRight")) this.cam.yaw -= dt * 2.6;
    const len = Math.hypot(fx, fz);
    let mx = 0, mz = 0;
    if (len > 0) {
      const s = Math.sin(this.cam.yaw), c = Math.cos(this.cam.yaw);
      mx = (fx * c + fz * s) / len;
      mz = (-fx * s + fz * c) / len;
    }
    p.vel.x = mx * p.speed;
    p.vel.z = mz * p.speed;
    if (this.cam.shiftLock) p.yaw = this.cam.yaw;
    else if (len > 0) {
      const target = Math.atan2(-mx, -mz);
      let d = target - p.yaw;
      d = Math.atan2(Math.sin(d), Math.cos(d));
      p.yaw += d * Math.min(1, dt * 14);
    }
    if (!p.frozen && this.key("Space") && p.onGround) {
      p.vel.y = p.jump;
      p.onGround = false;
      if (window.Kit) Kit.sfx("jump");
    }
    p.vel.y -= GRAVITY * dt;
    if (p.vel.y < -160) p.vel.y = -160;

    p.pos.x += p.vel.x * dt; this.collide(p, "x");
    p.pos.z += p.vel.z * dt; this.collide(p, "z");
    const wasGround = p.onGround;
    p.onGround = false;
    p.standingOn = null;
    p.pos.y += p.vel.y * dt; this.collide(p, "y");
    if (!p.onGround && wasGround && p.vel.y <= 0) {
      // Snap down small steps so walking down stairs doesn't bounce.
      const y0 = p.pos.y;
      p.pos.y -= STEP_UP; p.vel.y = -1;
      this.collide(p, "y");
      if (!p.onGround) { p.pos.y = y0; p.vel.y = Math.min(p.vel.y, 0); }
    }

    if (p.pos.y < this.voidY) this.kill();
    for (const mesh of this.touchers) {
      const info = mesh.userData.part;
      const now = this.touching(mesh);
      if (now && !info.touching) {
        if (info.kill) { this.kill(); break; }
        if (info.onTouch) info.onTouch(p, mesh);
      }
      info.touching = now;
    }
  }

  syncPlayer(dt) {
    const p = this.player;
    if (!p) return;
    p.group.position.copy(p.pos);
    p.group.rotation.y = p.yaw;
    if (dt) p.group.userData.animate(dt, Math.hypot(p.vel.x, p.vel.z), !p.onGround);
  }

  updateCamera() {
    const p = this.player;
    const target = p ? new THREE.Vector3(p.pos.x, p.pos.y + 4.5, p.pos.z) : new THREE.Vector3();
    const { yaw, pitch, dist } = this.cam;
    const offset = new THREE.Vector3(Math.sin(yaw) * Math.cos(pitch), Math.sin(pitch), Math.cos(yaw) * Math.cos(pitch)).multiplyScalar(dist);
    if (this.cam.shiftLock) target.add(new THREE.Vector3(Math.cos(yaw), 0, -Math.sin(yaw)).multiplyScalar(1.6));
    this.camera.position.copy(target).add(offset);
    this.camera.lookAt(target);
    // Shadows follow the player.
    this.sun.position.set(target.x + 60, target.y + 120, target.z + 40);
    this.sun.target.position.copy(target);
  }

  // ---------------------------------------------------------------- online

  online(net) {
    this.net = net;
    const add = (pl) => {
      if (this.remotes.has(pl.id)) return;
      const model = this.character(pl.avatar, pl.name);
      model.visible = false;
      this.remotes.set(pl.id, { model, target: new THREE.Vector3(), yaw: 0, speed: 0, air: false, seen: false });
      if (pl.state) this.applyRemote(pl);
    };
    net.on("join", add);
    net.on("leave", (pl) => {
      const r = this.remotes.get(pl.id);
      if (r) { this.scene.remove(r.model); this.remotes.delete(pl.id); }
    });
    net.on("state", (pl) => { add(pl); this.applyRemote(pl); });
    net.on("chat", (pl, text) => {
      if (pl.id === net.me.id || pl === net.me) { if (this.player) this.bubble(this.player.group, text); return; }
      const r = this.remotes.get(pl.id);
      if (r) this.bubble(r.model, text);
    });
  }

  applyRemote(pl) {
    const r = this.remotes.get(pl.id);
    const s = pl.state;
    if (!r || !s || !Array.isArray(s.p)) return;
    r.target.set(+s.p[0] || 0, +s.p[1] || 0, +s.p[2] || 0);
    r.yaw = +s.y || 0;
    r.speed = +s.m || 0;
    r.air = !!s.a;
    r.model.visible = s.dead ? false : true;
    if (!r.seen) { r.model.position.copy(r.target); r.seen = true; }
  }

  stepRemotes(dt) {
    for (const r of this.remotes.values()) {
      r.model.position.lerp(r.target, Math.min(1, dt * 12));
      let d = r.yaw - r.model.rotation.y;
      d = Math.atan2(Math.sin(d), Math.cos(d));
      r.model.rotation.y += d * Math.min(1, dt * 12);
      r.model.userData.animate(dt, r.speed, r.air);
    }
    const p = this.player;
    if (this.net && this.net.online && p) {
      this.net.state({
        p: [+p.pos.x.toFixed(2), +p.pos.y.toFixed(2), +p.pos.z.toFixed(2)], y: +p.yaw.toFixed(2),
        m: +Math.hypot(p.vel.x, p.vel.z).toFixed(1), a: !p.onGround, dead: !p.alive,
      });
    }
  }

  // ---------------------------------------------------------------- loop

  start(update) {
    let last = performance.now();
    let slow = 0;
    const frame = (t) => {
      requestAnimationFrame(frame);
      const dt = Math.max(0, Math.min(0.05, (t - last) / 1000));
      last = t;
      // Lower the resolution if the computer can't keep up (common in virtual machines).
      if (dt > 1 / 32) slow += dt; else slow = Math.max(0, slow - dt * 0.5);
      if (slow > 2 && this.pixelRatio > 0.5) {
        this.pixelRatio = Math.max(0.5, this.pixelRatio - 0.25);
        this.renderer.setPixelRatio(this.pixelRatio);
        this.renderer.setSize(innerWidth, innerHeight);
        slow = 0;
      }
      for (const mesh of this.movers) {
        const info = mesh.userData.part;
        info.last.copy(mesh.position);
      }
      if (update) update(dt);
      for (const mesh of this.movers) {
        const info = mesh.userData.part;
        info.delta.subVectors(mesh.position, info.last);
        this.updateBox(mesh);
      }
      // Physics in small steps so fast falls don't pass through thin parts.
      const steps = Math.ceil(dt / (1 / 120));
      for (let i = 0; i < steps; i++) {
        if (i > 0) for (const mesh of this.movers) mesh.userData.part.delta.set(0, 0, 0);
        this.stepPlayer(dt / steps);
      }
      if (this.debris) {
        for (const m of this.debris) {
          m.userData.v.y -= GRAVITY * 0.35 * dt;
          m.position.addScaledVector(m.userData.v, dt);
          m.rotation.x += m.userData.spin.x * dt;
          m.rotation.y += m.userData.spin.y * dt;
        }
      }
      this.syncPlayer(dt);
      this.stepRemotes(dt);
      this.updateCamera();
      this.renderer.render(this.scene, this.camera);
    };
    requestAnimationFrame(frame);
  }
}
