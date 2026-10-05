// Survival Island: seeded island generator (pure data, no rendering).
// The island is a grid of N x N columns, CELL studs wide. Every column has an integer top height.
// Caves are columns with a low floor and a "roof" slab above (roofB..roofT).

export const CELL = 4;
export const N = 72;
export const OFF = (N * CELL) / 2;      // world x/z go from -OFF to +OFF
export const WATER_Y = 0.5;             // water surface; columns with top <= 0 are under water
export const FLOOR_MIN = -16;

// Ground kinds
export const SEABED = 0, SAND = 1, GRASS = 2, FOREST = 3, ROCK = 4, CAVE = 5;

export function mulberry(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function hash(ix, iz, s) {
  let h = (Math.imul(ix, 374761393) + Math.imul(iz, 668265263) + Math.imul(s, 1274126177)) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}
const smooth = (t) => t * t * (3 - 2 * t);
function vnoise(x, z, s) {
  const ix = Math.floor(x), iz = Math.floor(z);
  const fx = smooth(x - ix), fz = smooth(z - iz);
  const a = hash(ix, iz, s), b = hash(ix + 1, iz, s), c = hash(ix, iz + 1, s), d = hash(ix + 1, iz + 1, s);
  return a + (b - a) * fx + (c - a) * fz + (a - b - c + d) * fx * fz;
}
function fbm(x, z, s, oct) {
  let v = 0, amp = 0.5, f = 1, tot = 0;
  for (let o = 0; o < oct; o++) { v += vnoise(x * f, z * f, s + o * 101) * amp; tot += amp; amp *= 0.5; f *= 2; }
  return v / tot;
}
function smoothstep(a, b, x) { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); }

// Resource kinds and how they behave.
export const RES = {
  tree:    { name: "Tree",         hp: 8,  drop: ["wood", 3],    tool: "axe",  tier: 0, respawn: 300, solid: [1.8, 10, 1.8], pick: [5.5, 12.5, 5.5] },
  palm:    { name: "Palm Tree",    hp: 6,  drop: ["wood", 2],    tool: "axe",  tier: 0, respawn: 300, solid: [1.4, 10, 1.4], pick: [4, 11, 4] },
  bush:    { name: "Berry Bush",   hp: 2,  drop: ["berries", 3], tool: null,   tier: 0, respawn: 180, solid: null,           pick: [3.6, 2.8, 3.6] },
  rock:    { name: "Rock",         hp: 10, drop: ["stone", 3],   tool: "pick", tier: 1, respawn: 360, solid: [3.4, 2.6, 3.0], pick: [3.8, 3.2, 3.6] },
  iron:    { name: "Iron Ore",     hp: 14, drop: ["iron", 2],    tool: "pick", tier: 2, respawn: 480, solid: [3.4, 2.8, 3.2], pick: [3.8, 3.4, 3.6] },
  gold:    { name: "Gold Ore",     hp: 16, drop: ["gold", 2],    tool: "pick", tier: 3, respawn: 540, solid: [3.4, 2.8, 3.2], pick: [3.8, 3.4, 3.6] },
  crystal: { name: "Crystal",      hp: 18, drop: ["crystal", 1], tool: "pick", tier: 3, respawn: 600, solid: [2.4, 4, 2.4],   pick: [3, 4.4, 3] },
};

export function idx(i, k) { return k * N + i; }

export function generate(seed) {
  const R = mulberry(seed);
  const s = seed % 1000003;
  const H = new Int16Array(N * N);
  const K = new Uint8Array(N * N);
  const roofB = new Int16Array(N * N).fill(-999);
  const roofT = new Int16Array(N * N).fill(-999);
  const c = N / 2;
  const forest = new Float32Array(N * N);

  for (let k = 0; k < N; k++) for (let i = 0; i < N; i++) {
    const x = i - c + 0.5, z = k - c + 0.5;
    let d = Math.hypot(x, z) / (N * 0.43);
    d += (fbm(i * 0.07, k * 0.07, s + 7, 3) - 0.5) * 0.5;
    const mask = 1 - smoothstep(0.5, 1.0, d);
    const hill = fbm(i * 0.05, k * 0.05, s + 13, 4);
    const mount = Math.max(0, hill - 0.42) / 0.58;
    let h = -14 + mask * 17.2 + mask * mask * (mount * mount * 34 + fbm(i * 0.13, k * 0.13, s + 3, 2) * 3);
    h = Math.max(-14, Math.min(40, Math.round(h)));
    const id = idx(i, k);
    H[id] = h;
    forest[id] = fbm(i * 0.09, k * 0.09, s + 29, 3);
    const rocky = fbm(i * 0.1, k * 0.1, s + 41, 3);
    if (h <= 0) K[id] = SEABED;
    else if (h <= 2) K[id] = SAND;
    else if (h >= 16 || (rocky > 0.69 && h >= 4)) K[id] = ROCK;
    else K[id] = forest[id] > 0.47 ? FOREST : GRASS;
  }
  // Cliffs look rocky.
  for (let k = 1; k < N - 1; k++) for (let i = 1; i < N - 1; i++) {
    const id = idx(i, k), h = H[id];
    if (h < 4) continue;
    const m = Math.max(h - H[id - 1], h - H[id + 1], h - H[id - N], h - H[id + N]);
    if (m >= 4) K[id] = ROCK;
  }

  // Spawn: a flat grass column near the middle-south of the island.
  let spawn = null, bestScore = 1e9;
  for (let k = 2; k < N - 2; k++) for (let i = 2; i < N - 2; i++) {
    const id = idx(i, k), h = H[id];
    if (h < 3 || h > 8 || (K[id] !== GRASS && K[id] !== FOREST)) continue;
    let flat = true;
    for (let dk = -1; dk <= 1 && flat; dk++) for (let di = -1; di <= 1; di++) if (Math.abs(H[idx(i + di, k + dk)] - h) > 1) { flat = false; break; }
    if (!flat) continue;
    const score = Math.hypot(i - c, k - (c + 9));
    if (score < bestScore) { bestScore = score; spawn = { i, k }; }
  }
  if (!spawn) { spawn = { i: c, k: c }; H[idx(c, c)] = Math.max(3, H[idx(c, c)]); K[idx(c, c)] = GRASS; }

  // Caves: a rocky mound with a tunnel and a chamber at the back.
  const caves = [];
  const DIRS = [[1, 0], [-1, 0], [0, 1], [0, -1]];
  for (let attempt = 0; attempt < 400 && caves.length < 2; attempt++) {
    const ci = Math.floor(c - 18 + R() * 36), ck = Math.floor(c - 18 + R() * 36);
    const [dx, dz] = DIRS[Math.floor(R() * 4)];
    const px = -dz, pz = dx;
    if (Math.hypot(ci - spawn.i, ck - spawn.k) < 12) continue;
    if (caves.some((cv) => Math.hypot(cv.i - ci, cv.k - ck) < 16)) continue;
    const cell = (t, p) => [ci + dx * t + px * p, ck + dz * t + pz * p];
    let ok = true, g = 99;
    for (let t = -2; t <= 8 && ok; t++) for (let p = -2; p <= 2; p++) {
      const [i, k] = cell(t, p);
      if (i < 2 || k < 2 || i >= N - 2 || k >= N - 2) { ok = false; break; }
      const h = H[idx(i, k)];
      if (h < 3) { ok = false; break; }
      if (t >= 0) g = Math.min(g, h);
    }
    if (!ok) continue;
    const front = H[idx(...cell(-1, 0))];
    if (front > g + 3) continue;
    const top = g + 9;
    const chamber = [];
    for (let t = 0; t <= 8; t++) for (let p = -2; p <= 2; p++) {
      const [i, k] = cell(t, p);
      const id = idx(i, k);
      const inside = (t <= 4 && p === 0) || (t >= 5 && t <= 7 && Math.abs(p) <= 1);
      if (inside) {
        H[id] = g; K[id] = CAVE; roofB[id] = g + 7; roofT[id] = top;
        if (t >= 5) chamber.push({ i, k, t, p });
      } else {
        H[id] = Math.max(H[id], top - (t === 8 || Math.abs(p) === 2 ? 1 : 0)); K[id] = ROCK;
      }
    }
    // Make the way in walkable.
    for (let t = -2; t <= -1; t++) {
      const id = idx(...cell(t, 0));
      if (H[id] > g) H[id] = g;
      if (H[id] < g - 1) H[id] = g - 1;
    }
    caves.push({ i: ci, k: ck, dx, dz, px, pz, g, chamber });
  }

  // Resources.
  const res = [];
  const used = new Uint8Array(N * N);
  const near = (i, k) => {
    for (const [di, dk] of [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const ii = i + di, kk = k + dk;
      if (ii < 0 || kk < 0 || ii >= N || kk >= N || used[idx(ii, kk)]) return true;
    }
    return false;
  };
  const add = (type, i, k, jitter) => {
    const j = jitter === false ? 0 : 1.2;
    const id = idx(i, k);
    used[id] = 1;
    res.push({
      id: res.length, type, i, k,
      x: (i + 0.5) * CELL - OFF + (R() - 0.5) * j,
      z: (k + 0.5) * CELL - OFF + (R() - 0.5) * j,
      y: H[id], rot: R() * Math.PI * 2, s: 0.85 + R() * 0.3,
    });
  };
  for (let dk = -2; dk <= 2; dk++) for (let di = -2; di <= 2; di++) used[idx(spawn.i + di, spawn.k + dk)] = 1;
  for (const cv of caves) {
    for (let t = -2; t <= 8; t++) for (let p = -2; p <= 2; p++) used[idx(cv.i + cv.dx * t + cv.px * p, cv.k + cv.dz * t + cv.pz * p)] = 1;
    for (const ch of cv.chamber) {
      if (ch.t === 7) add(ch.p === 0 ? "gold" : "crystal", ch.i, ch.k, false);
      else if (ch.t === 5 && ch.p !== 0) add("iron", ch.i, ch.k, false);
    }
  }
  const order = [];
  for (let id = 0; id < N * N; id++) order.push(id);
  for (let a = order.length - 1; a > 0; a--) { const b = Math.floor(R() * (a + 1)); [order[a], order[b]] = [order[b], order[a]]; }
  const count = { tree: 0, palm: 0, bush: 0, rock: 0, iron: 0, gold: 0, crystal: 0 };
  const CAP = { tree: 120, palm: 18, bush: 40, rock: 55, iron: 18, gold: 9, crystal: 3 };
  const tryAdd = (type, i, k) => { if (count[type] >= CAP[type]) return false; add(type, i, k); count[type]++; return true; };
  for (const id of order) {
    const i = id % N, k = Math.floor(id / N);
    if (i < 1 || k < 1 || i >= N - 1 || k >= N - 1 || near(i, k)) continue;
    const h = H[id], kind = K[id], r = R();
    const dc = Math.hypot(i - c, k - c) / (N * 0.43);
    if (kind === SAND) {
      if (r < 0.22) tryAdd("palm", i, k);
      else if (r < 0.27) tryAdd("rock", i, k);
    } else if (kind === GRASS || kind === FOREST) {
      const treeP = kind === FOREST ? 0.34 : 0.05;
      if (r < treeP) tryAdd("tree", i, k);
      else if (r < treeP + 0.05) tryAdd("bush", i, k);
      else if (r < treeP + 0.08) tryAdd("rock", i, k);
      else if (r < treeP + 0.095 && h >= 6 && dc < 0.6) tryAdd("iron", i, k);
    } else if (kind === ROCK) {
      if (r < 0.2) tryAdd("rock", i, k);
      else if (r < 0.3 && h >= 5) tryAdd("iron", i, k);
      else if (r < 0.36 && h >= 8) tryAdd("gold", i, k);
      else if (r < 0.375 && h >= 14) tryAdd("crystal", i, k);
    }
  }
  // Make sure there is always enough of everything.
  const MIN = { tree: 70, bush: 20, rock: 30, iron: 12, gold: 6, crystal: 1 };
  for (const type of Object.keys(MIN)) {
    for (const id of order) {
      if (count[type] >= MIN[type]) break;
      const i = id % N, k = Math.floor(id / N);
      if (i < 1 || k < 1 || i >= N - 1 || k >= N - 1 || near(i, k)) continue;
      const h = H[id], kind = K[id];
      const inland = Math.hypot(i - c, k - c) < N * 0.3;
      const fits = type === "tree" || type === "bush" ? kind === GRASS || kind === FOREST
        : type === "rock" ? h >= 1
        : inland && h >= (type === "iron" ? 4 : 6) && kind !== SEABED;
      if (fits) { add(type, i, k); count[type]++; }
    }
  }
  return { seed, H, K, roofB, roofT, spawn, caves, res, count };
}

// Top of the solid ground in a column (world coordinates).
export function cellOf(v) { return Math.floor((v + OFF) / CELL); }
export function cellCenter(i) { return (i + 0.5) * CELL - OFF; }
