/*
 * Circuit Builder: circuit solver (nodal analysis).
 *
 * Every grid dot is a node. Every part sits between two nodes (a, b).
 * Each part is turned into a linear element whose current from p to n is
 *     I = G * (Vp - Vn - E)
 * (a resistor has E = 0; a cell has E = 1.5 V and a tiny internal resistance;
 * a lit LED has E = its forward voltage and a small resistance).
 * Kirchhoff's current law at every node gives G * V = rhs, solved by Gaussian
 * elimination. A tiny conductance from every node to "ground" (gmin) keeps
 * unconnected pieces solvable without changing any real reading.
 * LEDs are one-way: they are switched on/off and re-solved until consistent.
 * Then fuses, bulbs and LEDs that carry too much are broken and it re-solves.
 *
 * Works in the browser (window.CircuitSolver) and in Node (module.exports).
 */
(function (root) {
  "use strict";

  const P = {
    cellV: 1.5,       // V per cell
    cellR: 0.001,     // ohm, internal resistance (tiny: toy cell, ideal for readings)
    wireR: 0.0001,    // ohm, a wire / closed switch / fuse
    bulbR: 5,         // ohm (in this game a bulb's resistance does not change as it heats up)
    houseR: 5,        // ohm (a house is a bulb inside a little house)
    buzzerR: 30,      // ohm
    motorR: 4,        // ohm
    ledVf: 2.0,       // V needed to switch an LED on
    ledR: 2,          // ohm, LED resistance once it is on
    ledMax: 0.03,     // A: more than 30 mA burns the LED out
    fuseMax: 2,       // A: more than 2 A melts the fuse
    bulbMaxP: 5,      // W: more than this blows a bulb
    shortI: 5,        // A: a cell giving more than this is short-circuited
    gmin: 1e-9,       // S, tiny leak to ground (numerical only)
    litP: 0.03,       // W: a bulb glows above this power
    ledLitI: 0.002,   // A: an LED glows above 2 mA
    buzzI: 0.04,      // A: a buzzer sounds above this
    motorI: 0.1,      // A: a motor spins above this
  };

  const RES = { wire: () => P.wireR, switch: () => P.wireR, fuse: () => P.wireR, bulb: () => P.bulbR,
    house: () => P.houseR, buzzer: () => P.buzzerR, motor: () => P.motorR, resistor: (p) => p.val || 10 };

  function conducts(p) {
    if (p.broken) return false;
    if (p.type === "switch") return !!p.on;
    return true;
  }

  // Solve once with the given LED states. Returns node voltages and part currents (a -> b).
  function solveOnce(nNodes, parts, ledOn) {
    const used = new Map();
    const idx = (n) => { if (!used.has(n)) used.set(n, used.size); return used.get(n); };
    const els = [];
    parts.forEach((p, i) => {
      if (!conducts(p)) return;
      let pn, nn, G, E = 0, sign = 1;  // sign: +1 if element p->n is a->b
      if (p.type === "cell") {
        // dir +1: the + end is at b. Element p = + end, n = - end.
        const plusAtB = p.dir !== -1;
        pn = plusAtB ? p.b : p.a; nn = plusAtB ? p.a : p.b; sign = plusAtB ? -1 : 1;
        G = 1 / P.cellR; E = P.cellV;
      } else if (p.type === "led") {
        // dir +1: current may flow a -> b (anode at a).
        const anodeA = p.dir !== -1;
        pn = anodeA ? p.a : p.b; nn = anodeA ? p.b : p.a; sign = anodeA ? 1 : -1;
        if (ledOn[i]) { G = 1 / P.ledR; E = P.ledVf; } else { G = 1e-12; E = 0; }
      } else {
        const R = RES[p.type] ? RES[p.type](p) : 1e12;
        pn = p.a; nn = p.b; G = 1 / R;
      }
      els.push({ i, p: idx(pn), n: idx(nn), G, E, sign });
    });
    const N = used.size;
    const A = Array.from({ length: N }, () => new Float64Array(N + 1));
    for (let k = 0; k < N; k++) A[k][k] += P.gmin;
    for (const e of els) {
      A[e.p][e.p] += e.G; A[e.n][e.n] += e.G;
      A[e.p][e.n] -= e.G; A[e.n][e.p] -= e.G;
      A[e.p][N] += e.G * e.E; A[e.n][N] -= e.G * e.E;
    }
    // Gaussian elimination with partial pivoting.
    for (let c = 0; c < N; c++) {
      let best = c;
      for (let r = c + 1; r < N; r++) if (Math.abs(A[r][c]) > Math.abs(A[best][c])) best = r;
      if (best !== c) { const t = A[c]; A[c] = A[best]; A[best] = t; }
      const piv = A[c][c];
      if (Math.abs(piv) < 1e-30) continue;
      for (let r = c + 1; r < N; r++) {
        const f = A[r][c] / piv;
        if (f === 0) continue;
        for (let k = c; k <= N; k++) A[r][k] -= f * A[c][k];
      }
    }
    const x = new Float64Array(N);
    for (let r = N - 1; r >= 0; r--) {
      let s = A[r][N];
      for (let k = r + 1; k < N; k++) s -= A[r][k] * x[k];
      x[r] = Math.abs(A[r][r]) < 1e-30 ? 0 : s / A[r][r];
    }
    const nodeV = new Float64Array(nNodes);
    for (const [n, k] of used) nodeV[n] = x[k];
    const I = new Float64Array(parts.length);
    for (const e of els) I[e.i] = e.sign * e.G * (x[e.p] - x[e.n] - e.E);
    return { nodeV, I };
  }

  // Full simulation. Mutates parts: sets .broken on fuses / bulbs / LEDs that overload.
  // Returns { V (a-b voltage per part), I (a->b current per part), Pw (power per part), events, short }.
  function simulate(nNodes, parts) {
    const events = [];
    let res = null, ledOn = parts.map(() => false);
    for (let round = 0; round < 40; round++) {
      // 1) settle the LEDs
      for (let it = 0; it < 30; it++) {
        res = solveOnce(nNodes, parts, ledOn);
        let changed = false;
        parts.forEach((p, i) => {
          if (p.type !== "led" || !conducts(p)) return;
          const fwdI = (p.dir !== -1 ? 1 : -1) * res.I[i];
          const vab = res.nodeV[p.a] - res.nodeV[p.b];
          const fwdV = (p.dir !== -1 ? 1 : -1) * vab;
          if (ledOn[i] && fwdI <= 0) { ledOn[i] = false; changed = true; }
          else if (!ledOn[i] && fwdV > P.ledVf + 1e-9) { ledOn[i] = true; changed = true; }
        });
        if (!changed) break;
      }
      // 2) fuses go first (that's their job): the worst one melts
      let worst = -1, worstI = P.fuseMax;
      parts.forEach((p, i) => { if (p.type === "fuse" && !p.broken && Math.abs(res.I[i]) > worstI) { worst = i; worstI = Math.abs(res.I[i]); } });
      if (worst >= 0) { parts[worst].broken = true; events.push({ type: "fuse", index: worst, current: worstI }); continue; }
      // 3) then bulbs and LEDs that are overloaded
      let broke = false;
      parts.forEach((p, i) => {
        if (p.broken) return;
        const v = res.nodeV[p.a] - res.nodeV[p.b];
        if ((p.type === "bulb" || p.type === "house") && Math.abs(v * res.I[i]) > P.bulbMaxP) {
          p.broken = true; broke = true; events.push({ type: "bulb", index: i, power: Math.abs(v * res.I[i]) });
        }
        if (p.type === "led" && Math.abs(res.I[i]) > P.ledMax) {
          p.broken = true; broke = true; events.push({ type: "led", index: i, current: Math.abs(res.I[i]) });
        }
      });
      if (!broke) break;
    }
    const V = parts.map((p) => res.nodeV[p.a] - res.nodeV[p.b]);
    const I = Array.from(res.I);
    const Pw = parts.map((p, i) => Math.abs(V[i] * I[i]));
    const short = parts.some((p, i) => p.type === "cell" && Math.abs(I[i]) > P.shortI);
    return { V, I, Pw, nodeV: res.nodeV, events, short };
  }

  // What a part is doing, for drawing and goals.
  function status(p, V, I, Pw) {
    const a = Math.abs(I);
    switch (p.type) {
      case "bulb": case "house": return { on: !p.broken && Pw >= P.litP, level: Pw / 0.45 };
      case "led": return { on: !p.broken && a >= P.ledLitI, level: a / 0.02 };
      case "buzzer": return { on: a >= P.buzzI, level: a / 0.05 };
      case "motor": return { on: a >= P.motorI, level: I / 0.375 };
      default: return { on: a > 1e-4, level: a };
    }
  }

  const api = { P, simulate, status, solveOnce };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.CircuitSolver = api;
})(typeof window !== "undefined" ? window : globalThis);
