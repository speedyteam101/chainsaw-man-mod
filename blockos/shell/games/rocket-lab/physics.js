// Rocket Lab physics: parts, rocket stats and the flight simulation.
// Plain ES module with no browser code, so it can also be tested in Node.
//
// The flight is simulated in 2D (one plane through the middle of a round Earth): position and
// velocity are measured from Earth's center in meters, and gravity follows the inverse-square law
// (g = 9.8 m/s^2 on the ground, about 9.5 m/s^2 at 100 km, about 8.7 m/s^2 at 400 km).
// Air density and pressure come from the US Standard Atmosphere (1976) table below; air pressure
// halves about every 5.5 km near the ground. Drag is 1/2 * rho * v^2 * Cd * A.
// Engines push along the rocket's axis; fuel burns at thrust / exhaust speed kg per second.

export const G0 = 9.8;                 // m/s^2 at the surface
export const R_EARTH = 6371000;        // m
export const MU = G0 * R_EARTH * R_EARTH;
export const KARMAN = 100000;          // m, the usual "edge of space"
export const MOON_DIST = 384400000;    // m, average Earth-Moon distance
export const MOON_G = 1.62;            // m/s^2
// altitude (km), air density (kg/m^3), pressure (fraction of sea level)
const ATMO = [
  [0, 1.225, 1], [5, 0.7364, 0.5332], [10, 0.4135, 0.2615], [15, 0.1948, 0.1195], [20, 0.08891, 0.05457],
  [25, 0.04008, 0.02516], [30, 0.01841, 0.01181], [40, 0.003996, 0.002834], [50, 0.001027, 0.0007874],
  [60, 0.0003097, 0.0002167], [70, 0.00008283, 0.00004998], [80, 0.00001846, 0.00001036], [90, 0.000003416, 0.000001817],
  [100, 0.00000056, 0.00000032], [120, 0.0000000222, 0.0000000252], [140, 0.0000000038, 0.0000000072],
];
// Returns [density kg/m^3, pressure ratio] at altitude h (m). Zero above 140 km.
export function air(h) {
  const km = Math.max(0, h) / 1000;
  if (km >= 140) return [0, 0];
  let i = 0;
  while (i < ATMO.length - 2 && ATMO[i + 1][0] <= km) i++;
  const a = ATMO[i], b = ATMO[i + 1];
  const f = (km - a[0]) / (b[0] - a[0]);
  return [a[1] * Math.pow(b[1] / a[1], f), a[2] * Math.pow(b[2] / a[2], f)];
}
export const STUDS_PER_M = 2;          // drawing scale: a part 4 studs wide is 2 m wide

// mass in tonnes, thrust in kN (sea level / vacuum), ve = exhaust speed in vacuum (m/s), h = height in studs
export const PARTS = {
  capsule: { name: "Capsule", kind: "capsule", mass: 2.0, h: 4, cost: 0,
    info: "Your seat, with a heat shield and a parachute for coming home." },
  nose: { name: "Nose cone", kind: "nose", mass: 0.2, h: 3, cost: 15,
    info: "Pointy top: the air slides around it, so there's less drag." },
  fins: { name: "Fins", kind: "fins", mass: 0.3, h: 0, cost: 0,
    info: "Like feathers on an arrow: they keep the rocket pointing straight." },
  tankS: { name: "Small tank", kind: "tank", dry: 0.15, fuel: 1.6, h: 3, cost: 0,
    info: "1.6 t of fuel." },
  tankL: { name: "Big tank", kind: "tank", dry: 0.3, fuel: 4.5, h: 6, cost: 40,
    info: "4.5 t of fuel." },
  tankH: { name: "Giant tank", kind: "tank", dry: 0.8, fuel: 13, h: 11, w: 6, cost: 350, need: "space",
    info: "13 t of fuel." },
  tankM: { name: "Mega tank", kind: "tank", dry: 1.6, fuel: 30, h: 16, w: 8, cost: 700, need: "orbit",
    info: "30 t of fuel, for Moon rockets." },
  engW: { name: "Small engine", kind: "engine", mass: 0.4, tsl: 70, tvac: 77, ve: 2900, h: 2, cost: 0,
    info: "Gentle push, sips fuel." },
  engS: { name: "Strong engine", kind: "engine", mass: 1.0, tsl: 240, tvac: 262, ve: 3200, h: 2.4, cost: 80, need: "clouds",
    info: "Big push, gulps fuel." },
  engV: { name: "Space engine", kind: "engine", mass: 0.3, tsl: 35, tvac: 100, ve: 4400, h: 2.4, cost: 300, need: "space",
    info: "Very fuel-efficient but weak, and weaker still in thick air. Best for upper stages." },
  engM: { name: "Mega engine", kind: "engine", mass: 2.5, tsl: 900, tvac: 990, ve: 3300, h: 3, cost: 600, need: "orbit",
    info: "Huge push for huge rockets." },
  boost: { name: "Side boosters", kind: "boost", dry: 0.8, fuel: 7, tsl: 300, tvac: 330, ve: 2500, h: 10, cost: 200, need: "sky10",
    info: "A pair of solid boosters: extra push at liftoff, then they drop off when empty." },
  stage: { name: "Decoupler (new stage)", kind: "stage", mass: 0.2, h: 0.8, cost: 120, need: "sky10",
    info: "Starts a new stage on top. Press Space in flight to drop the stage below." },
};

export const LIMITS = { stages: 4, engines: 6, tanks: 8 };

export function emptyDesign() {
  return { nose: false, stages: [{ eng: ["engW"], tanks: ["tankS"], fins: true, boost: false }] };
}

export function cleanDesign(d) {
  const out = { nose: !!(d && d.nose), stages: [] };
  const src = d && Array.isArray(d.stages) ? d.stages : [];
  for (const s of src.slice(0, LIMITS.stages)) {
    out.stages.push({
      eng: (Array.isArray(s.eng) ? s.eng : []).filter((k) => PARTS[k] && PARTS[k].kind === "engine").slice(0, LIMITS.engines),
      tanks: (Array.isArray(s.tanks) ? s.tanks : []).filter((k) => PARTS[k] && PARTS[k].kind === "tank").slice(0, LIMITS.tanks),
      fins: !!s.fins,
      boost: !!s.boost && out.stages.length === 0,
    });
  }
  if (!out.stages.length) out.stages.push({ eng: [], tanks: [], fins: false, boost: false });
  return out;
}

// Parts list for drawing/counting.
export function partCount(d) {
  let n = 1 + (d.nose ? 1 : 0);
  d.stages.forEach((s, i) => { n += s.eng.length + s.tanks.length + (s.fins ? 1 : 0) + (s.boost ? 1 : 0) + (i > 0 ? 1 : 0); });
  return n;
}

// Turns a design into physics stages (bottom stage first).
export function buildStages(d) {
  return d.stages.map((s, i) => {
    let dry = 0, fuel = 0, h = 0;
    const engines = s.eng.map((k) => {
      const p = PARTS[k];
      dry += p.mass;
      return { key: k, tsl: p.tsl * 1000, tvac: p.tvac * 1000, mdot: (p.tvac * 1000) / p.ve };
    });
    if (engines.length) h += Math.max(...s.eng.map((k) => PARTS[k].h));
    let w = 4;
    for (const k of s.tanks) { dry += PARTS[k].dry; fuel += PARTS[k].fuel; h += PARTS[k].h; w = Math.max(w, PARTS[k].w || 4); }
    if (s.fins) dry += PARTS.fins.mass;
    if (i < d.stages.length - 1) { dry += PARTS.stage.mass; h += PARTS.stage.h; }
    let boost = null;
    if (s.boost) {
      const b = PARTS.boost;
      boost = { dry: b.dry * 1000, fuel: b.fuel * 1000, fuel0: b.fuel * 1000, tsl: b.tsl * 1000, tvac: b.tvac * 1000, mdot: (b.tvac * 1000) / b.ve };
    }
    return { dry: dry * 1000, fuel: fuel * 1000, fuel0: fuel * 1000, engines, fins: s.fins, boost, h, w };
  });
}

const topMass = (d) => (PARTS.capsule.mass + (d.nose ? PARTS.nose.mass : 0)) * 1000;

// Thrust (N) of a list of engines at a given air-pressure ratio (1 = ground, 0 = space).
function thrustOf(engines, pr) {
  let t = 0;
  for (const e of engines) t += e.tvac - (e.tvac - e.tsl) * pr;
  return t;
}

// Numbers for the build screen.
export function stats(design) {
  const d = cleanDesign(design);
  const st = buildStages(d);
  const top = topMass(d);
  let mass = top;
  for (const s of st) mass += s.dry + s.fuel + (s.boost ? s.boost.dry + s.boost.fuel : 0);
  const s0 = st[0];
  const thrust = thrustOf(s0.engines, 1) + (s0.boost ? s0.boost.tsl : 0);
  const weight = mass * G0;
  // Burn time of the first stage's own fuel, and delta-v (ideal speed change, vacuum) of every stage.
  const mdot0 = s0.engines.reduce((a, e) => a + e.mdot, 0);
  const burn = mdot0 > 0 ? s0.fuel / mdot0 : 0;
  let above = top, dv = 0;
  const stageInfo = [];
  for (let i = st.length - 1; i >= 0; i--) {
    const s = st[i];
    const m0 = above + s.dry + s.fuel + (s.boost ? s.boost.dry + s.boost.fuel : 0);
    const md = s.engines.reduce((a, e) => a + e.mdot, 0);
    const tv = thrustOf(s.engines, 0);
    let sdv = 0;
    if (md > 0 && s.fuel > 0) {
      const ve = tv / md;
      // boosters burn together with the core; approximate their part separately
      let m = m0;
      if (s.boost) {
        const bt = s.boost.fuel / s.boost.mdot;
        const coreUsed = Math.min(s.fuel, md * bt);
        const vemix = (tv + s.boost.tvac) / (md + s.boost.mdot);
        const m1 = m - s.boost.fuel - coreUsed;
        sdv += vemix * Math.log(m / m1);
        m = m1 - s.boost.dry;
        sdv += ve * Math.log(m / (m - (s.fuel - coreUsed)));
      } else {
        sdv = ve * Math.log(m0 / (m0 - s.fuel));
      }
    }
    stageInfo.unshift({ mass: m0, dv: sdv, burn: md > 0 ? s.fuel / md : 0, twrVac: tv / (m0 * G0) });
    dv += sdv;
    above = m0;
  }
  return {
    mass, thrust, weight, twr: thrust / weight, fuel: st.reduce((a, s) => a + s.fuel + (s.boost ? s.boost.fuel : 0), 0),
    burn, dv, stages: stageInfo, parts: partCount(d),
    ok: s0.engines.length > 0 || !!s0.boost,
  };
}

const wrap = (a) => Math.atan2(Math.sin(a), Math.cos(a));

// Simple pseudo-random noise for gusts (deterministic per flight).
function rng(seed) {
  let s = seed >>> 0 || 1;
  return () => { s ^= s << 13; s ^= s >>> 17; s ^= s << 5; return ((s >>> 0) / 4294967296) * 2 - 1; };
}

export class Flight {
  constructor(design, seed) {
    this.design = cleanDesign(design);
    this.stages = buildStages(this.design);
    this.top = topMass(this.design);
    this.px = 0; this.py = R_EARTH; this.vx = 0; this.vy = 0;
    this.psi = 0;          // rocket axis angle from the launch site's "up", radians (positive = toward east)
    this.omega = 0;        // turn rate
    this.t = 0;
    this.s = 0;            // index of the bottom stage still attached
    this.engineOn = true;
    this.lifted = false;
    this.capsuleOnly = false;
    this.chute = false;
    this.landed = false;
    this.broken = false;
    this.maxAlt = 0; this.maxSpeed = 0; this.maxQ = 0;
    this.stagesDropped = 0;
    this.boostersDropped = false;
    this.events = [];      // messages for the game: { type, ... }
    this.badAoA = 0;
    this.gust = 0;
    this.rand = rng(seed || 12345);
    this.launchMass = this.mass();
    this.thrustNow = 0; this.accel = 0; this.q = 0; this.aoa = 0;
  }

  get r() { return Math.hypot(this.px, this.py); }
  get alt() { return this.r - R_EARTH; }
  get speed() { return Math.hypot(this.vx, this.vy); }
  // downrange angle around Earth from the pad
  get phi() { return Math.atan2(this.px, this.py); }
  // tilt from the local vertical (what the player sees), radians
  get tilt() { return wrap(this.psi - this.phi); }
  get vUp() { return (this.px * this.vx + this.py * this.vy) / this.r; }
  get vSide() { return (this.py * this.vx - this.px * this.vy) / this.r; }
  get downrange() { return this.phi * R_EARTH; }

  mass() {
    if (this.capsuleOnly) return PARTS.capsule.mass * 1000;
    let m = this.top;
    for (let i = this.s; i < this.stages.length; i++) {
      const st = this.stages[i];
      m += st.dry + st.fuel + (st.boost ? st.boost.dry + st.boost.fuel : 0);
    }
    return m;
  }
  stage() { return this.capsuleOnly ? null : this.stages[this.s] || null; }
  stagesLeft() { return this.capsuleOnly ? 0 : this.stages.length - this.s; }
  hasFins() { const st = this.stage(); return !!(st && st.fins); }

  fuelFraction() {
    const st = this.stage();
    if (!st || st.fuel0 <= 0) return 0;
    return st.fuel / st.fuel0;
  }

  // Remaining ideal delta-v in vacuum (m/s) of everything still attached.
  dvLeft() {
    if (this.capsuleOnly) return 0;
    let above = this.top, dv = 0;
    for (let i = this.stages.length - 1; i >= this.s; i--) {
      const st = this.stages[i];
      const m0 = above + st.dry + st.fuel + (st.boost ? st.boost.dry + st.boost.fuel : 0);
      const md = st.engines.reduce((a, e) => a + e.mdot, 0);
      if (md > 0 && st.fuel > 0) dv += (thrustOf(st.engines, 0) / md) * Math.log(m0 / (m0 - st.fuel));
      above = m0;
    }
    return dv;
  }

  orbit() {
    const r = this.r, v2 = this.vx * this.vx + this.vy * this.vy;
    const eps = v2 / 2 - MU / r;
    const h = this.px * this.vy - this.py * this.vx;
    if (eps >= 0) return { escape: true, peri: NaN, apo: Infinity };
    const a = -MU / (2 * eps);
    const e = Math.sqrt(Math.max(0, 1 + (2 * eps * h * h) / (MU * MU)));
    return { escape: false, peri: a * (1 - e) - R_EARTH, apo: a * (1 + e) - R_EARTH, a, e };
  }

  // Drop the bottom stage. Returns true if something separated.
  separate() {
    if (this.capsuleOnly || this.landed) return false;
    if (this.s < this.stages.length - 1) {
      this.events.push({ type: "stage", index: this.s, fuelLeft: this.stages[this.s].fuel });
      this.s++;
      this.stagesDropped++;
      this.engineOn = true;
      return true;
    }
    return false;
  }

  // The capsule leaves the rest of the rocket (for coming home, or after a breakup).
  capsuleSeparate(reason) {
    if (this.capsuleOnly) return;
    this.capsuleOnly = true;
    this.engineOn = false;
    this.events.push({ type: "capsule", reason });
  }

  step(dt, steer) {
    if (this.landed) return;
    this.t += dt;
    const r = this.r, h = r - R_EARTH;
    const ux = this.px / r, uy = this.py / r;              // local up
    const [rho, pr] = air(h);
    const g = MU / (r * r);
    let m = this.mass();

    // ---- thrust
    let thrust = 0, mdot = 0, bmdot = 0;
    const st = this.stage();
    if (st && this.engineOn) {
      if (st.fuel > 0 && st.engines.length) { thrust += thrustOf(st.engines, pr); mdot = st.engines.reduce((a, e) => a + e.mdot, 0); }
      if (st.boost && st.boost.fuel > 0) { thrust += st.boost.tvac - (st.boost.tvac - st.boost.tsl) * pr; bmdot = st.boost.mdot; }
    }
    if (st && st.boost && st.boost.fuel <= 0 && this.lifted) {
      // empty boosters fall away by themselves
      this.events.push({ type: "boosters" });
      st.boost = null;
      this.boostersDropped = true;
      m = this.mass();
    }
    if (st && this.engineOn && st.fuel <= 0 && !(st.boost && st.boost.fuel > 0) && !st.outEvent) {
      st.outEvent = true;
      this.events.push({ type: "empty", last: this.s >= this.stages.length - 1 });
    }
    this.thrustNow = thrust;

    // ---- orientation
    const ax = Math.sin(this.psi), ay = Math.cos(this.psi);
    const v = this.speed;
    const q = 0.5 * rho * v * v;
    this.q = q;
    if (q > this.maxQ) this.maxQ = q;
    let aoa = 0;
    if (v > 5) aoa = wrap(this.psi - Math.atan2(this.vx, this.vy));
    this.aoa = aoa;
    if (!this.lifted) {
      this.omega = 0;
    } else if (this.capsuleOnly) {
      // A blunt capsule falls heat-shield first and stays that way; just show it pointing up.
      this.psi = this.phi;
      this.omega = 0;
    } else {
      const control = (thrust > 0 ? 0.6 : 0.35) * (steer || 0);
      const qn = q / 20000;
      let aero = 0;
      if (this.hasFins()) aero = -3.0 * qn * Math.sin(aoa);
      else aero = 1.4 * qn * Math.sin(aoa);              // no fins: the air tries to flip the rocket
      this.gust += (this.rand() * 2.2 - this.gust * 0.8) * dt;
      const gust = this.gust * qn * (this.hasFins() ? 0.15 : 0.9);
      this.omega += (control + aero + gust - this.omega * 2.0) * dt;
      this.psi = wrap(this.psi + this.omega * dt);
      // Flying sideways through thick air breaks a rocket apart.
      if (thrust > 0 && this.vUp > 0 && q > 9000 && Math.abs(aoa) > 0.4) this.badAoA += dt; else this.badAoA = Math.max(0, this.badAoA - dt);
      if (this.badAoA > 0.6) {
        this.broken = true;
        this.events.push({ type: "breakup", q });
        this.capsuleSeparate("breakup");
        // the escape motor pulls the capsule up and away
        this.vx += ux * 60; this.vy += uy * 60;
      }
    }

    // ---- drag
    let cdA;
    if (this.capsuleOnly) {
      cdA = 0.9 * 3.14 + (this.chute ? 600 : 0);
    } else {
      const lenM = this.lengthM(), wM = this.widthM();
      cdA = (this.design.nose ? 0.35 : 0.75) * wM * wM + (this.hasFins() ? 0.15 : 0);
      if (st && st.boost) cdA += 0.5 * 2 * 1.0;
      cdA += 1.0 * Math.abs(Math.sin(aoa)) * lenM * wM;   // side-on drag
    }
    const dragF = 0.5 * rho * v * cdA * v;   // newtons
    let fx = thrust * ax, fy = thrust * ay;
    if (v > 0) { fx -= (dragF * this.vx) / v; fy -= (dragF * this.vy) / v; }
    let axc = fx / m - g * ux, ayc = fy / m - g * uy;

    // ---- on the pad: the ground holds the rocket up until thrust beats weight
    if (!this.lifted) {
      const up = axc * ux + ayc * uy;
      if (up <= 0) { axc = 0; ayc = 0; this.vx = 0; this.vy = 0; }
      else { this.lifted = true; this.events.push({ type: "liftoff" }); }
    }
    this.accel = Math.hypot(fx / m, fy / m);
    this.vx += axc * dt; this.vy += ayc * dt;
    this.px += this.vx * dt; this.py += this.vy * dt;

    // ---- fuel
    if (st) {
      if (mdot > 0) st.fuel = Math.max(0, st.fuel - mdot * dt);
      if (bmdot > 0 && st.boost) st.boost.fuel = Math.max(0, st.boost.fuel - bmdot * dt);
    }

    // ---- coming home: capsule separates when falling back, parachute opens low down
    const hh = this.alt, vUp = this.vUp;
    if (this.lifted && !this.capsuleOnly && vUp < -40 && hh < 25000 && (thrust === 0 || hh < 3000)) this.capsuleSeparate("home");
    if (this.capsuleOnly && !this.chute && vUp < 0 && hh < 2500 && this.speed < 300) { this.chute = true; this.events.push({ type: "chute" }); }
    if (hh > this.maxAlt) this.maxAlt = hh;
    if (this.lifted && v > this.maxSpeed) this.maxSpeed = v;
    if (this.lifted && hh <= 0 && vUp < 0) {
      const sp = this.speed;
      // put it back on the surface
      const k = R_EARTH / this.r;
      this.px *= k; this.py *= k;
      this.vx = 0; this.vy = 0;
      this.landed = true;
      this.events.push({ type: "landed", speed: sp });
    }
  }

  // widest part still attached (m)
  widthM() {
    let w = 4;
    for (let i = this.s; i < this.stages.length; i++) w = Math.max(w, this.stages[i].w);
    return w / STUDS_PER_M;
  }

  lengthM() {
    let hs = PARTS.capsule.h + (this.design.nose ? PARTS.nose.h : 0);
    for (let i = this.s; i < this.stages.length; i++) hs += this.stages[i].h;
    return hs / STUDS_PER_M;
  }
}

// Suggested tilt (radians from straight up) for flying to orbit, shown as the yellow guide marker:
// go straight up, then tilt slowly (never far from the direction you're flying while the air is
// thick), then point sideways once the highest point of your path (apoapsis) reaches 140 km,
// pitching up a little if you start to fall. In orbit it points forward (prograde).
export function guideTilt(f, inOrbit) {
  const h = f.alt;
  const prograde = Math.atan2(f.vSide, f.vUp);
  if (inOrbit) return prograde;
  if (h < 1000) return 0;
  const o = f.orbit();
  let t;
  if (o.apo < 140000 && !(o.peri > 0)) {
    t = Math.min((Math.PI / 2) * Math.sqrt((h - 1000) / 70000), (75 * Math.PI) / 180);
  } else {
    t = Math.PI / 2 - Math.max(0, Math.min(0.6, -f.vUp / 400 + (100000 - h) / 100000));
  }
  const lim = f.q > 1000 ? 0.16 : f.q > 200 ? 0.3 : 9;
  return Math.max(prograde - lim, Math.min(prograde + lim, t));
}

// Fuel (kg) used to change speed by dv (m/s) through the remaining stages, staging as needed.
// Returns { ok, flight-state changes applied } for the Moon descent shortcut.
export function burnDv(flight, dv) {
  let need = dv;
  while (need > 0 && !flight.capsuleOnly) {
    const st = flight.stage();
    if (!st) break;
    const md = st.engines.reduce((a, e) => a + e.mdot, 0);
    if (md > 0 && st.fuel > 0) {
      const ve = thrustOf(st.engines, 0) / md;
      const m0 = flight.mass();
      const canDv = ve * Math.log(m0 / (m0 - st.fuel));
      if (canDv >= need) {
        const m1 = m0 / Math.exp(need / ve);
        st.fuel -= m0 - m1;
        need = 0;
        break;
      }
      need -= canDv;
      st.fuel = 0;
    }
    if (flight.s < flight.stages.length - 1) { flight.s++; flight.stagesDropped++; } else break;
  }
  return need <= 0.001;
}

export { thrustOf, wrap };
