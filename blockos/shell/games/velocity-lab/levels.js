/*
 * Velocity Lab levels. Two kinds:
 *   drive: you drive; tick(s, m, dt) is called every physics step and returns { stars, msg } to end the run
 *          (stars 0 = not passed). s = { t, x, v, a, gas, brake }, m = memory for this run.
 *   quiz:  a question with three answers.
 */
(function () {
  "use strict";
  const f1 = (n) => n.toFixed(1);

  // Stop with the front bumper at lineX. tol = [3 stars, 2 stars, 1 star] in metres.
  function stopAt(lineX, tol) {
    return (s, m) => {
      if (s.v === 0 && s.t > 0.5 && s.x > 1 && (!m.need || m.need(m))) {
        let gap = lineX - s.x;
        if (gap > -0.05) gap = Math.max(0, gap);   // within 5 cm counts as on the line
        if (gap < 0) return { stars: 0, msg: `You stopped ${f1(-gap)} m past the line. Brake a bit earlier!`, gap };
        const stars = gap <= tol[0] ? 3 : gap <= tol[1] ? 2 : gap <= tol[2] ? 1 : 0;
        if (!stars) return { stars, msg: `You stopped ${f1(gap)} m before the line - too early. Get closer!`, gap };
        return { stars, msg: `You stopped ${gap < 0.05 ? "right on" : f1(gap) + " m before"} the line.`, gap };
      }
      if (s.x > lineX + 25) return { stars: 0, msg: "You flew past the line! Brake earlier: braking distance = v^2 / (2a)." };
      return null;
    };
  }
  function graphMatch(target, band, T) {
    return (s, m) => {
      m.n = m.n || 0; m.in = m.in || 0;
      if (!m.next) m.next = 0;
      while (s.t >= m.next && m.next <= T) {
        const want = targetAt(target, m.next);
        m.n++; if (Math.abs(s.v - want) <= band) m.in++;
        m.next += 0.1;
      }
      if (s.t >= T) {
        const pc = m.in / Math.max(1, m.n);
        const stars = pc >= 0.85 ? 3 : pc >= 0.7 ? 2 : pc >= 0.5 ? 1 : 0;
        return { stars, msg: `Your graph stayed inside the target band ${Math.round(pc * 100)}% of the time.${stars ? "" : " You need at least 50%."}` };
      }
      return null;
    };
  }
  function targetAt(pts, t) {
    for (let i = 1; i < pts.length; i++) {
      if (t <= pts[i][0]) { const [t0, v0] = pts[i - 1], [t1, v1] = pts[i]; return v0 + (v1 - v0) * (t - t0) / (t1 - t0); }
    }
    return pts[pts.length - 1][1];
  }

  const LEVELS = [
    {
      type: "drive", title: "Get Rolling",
      goal: "Press GAS and reach a speed of 5 m/s.",
      intro: "Speed tells you how far you travel each second.\n5 m/s means 5 metres every second.\n\nTo change m/s into km/h, multiply by 3.6:\n5 m/s x 3.6 = 18 km/h.",
      done: "Speed = distance / time.\nOn the v-t graph (velocity against time) your line went UP while you sped up.",
      tMax: 30, graph: { t: 10, v: 10 },
      tick: (s) => (s.v >= 5 ? { stars: 3, msg: `You reached 5 m/s after ${s.t.toFixed(1)} s.` } : null),
    },
    {
      type: "drive", title: "Speed Camera",
      goal: "Pass the speed camera at 100 m going as close to 10 m/s as you can.",
      intro: "A speed camera measures how fast you are going as you pass it.\nWatch your speed on the dashboard and ease off the gas to hold about 10 m/s.\n\nTip: short taps on the gas give gentle pushes.",
      done: "10 m/s is 36 km/h - about as fast as a racing cyclist.\nA camera works out speed = distance / time from two quick measurements.",
      tMax: 60, graph: { t: 20, v: 20 }, markers: [{ x: 100, kind: "camera" }], length: 120,
      tick: (s) => {
        if (s.x < 100) return null;
        const err = Math.abs(s.v - 10);
        const stars = err <= 0.5 ? 3 : err <= 1 ? 2 : err <= 2 ? 1 : 0;
        return { stars, msg: `The camera clocked you at ${s.v.toFixed(1)} m/s (${(s.v * 3.6).toFixed(0)} km/h).${stars ? "" : " You need to be within 2 m/s of 10 m/s."}` };
      },
    },
    {
      type: "drive", title: "Steady Cruise",
      goal: "Keep your speed between 10.5 and 13.5 m/s for 6 seconds in a row.",
      intro: "Constant speed means your velocity is not changing, so your acceleration is 0.\nThen the forces balance: the engine's push equals friction plus air resistance.\n\nOn a v-t graph, constant speed is a FLAT line.",
      done: "A flat v-t graph = constant velocity = zero acceleration.\nThe engine wasn't switched off: it was pushing just enough to match friction and air resistance.",
      tMax: 60, graph: { t: 30, v: 20 }, band: [10.5, 13.5],
      tick: (s, m) => {
        if (s.v >= 10.5 && s.v <= 13.5) {
          if (m.start === undefined) { m.start = s.t; m.lo = 99; m.hi = 0; }
          m.held = s.t - m.start;
          if (m.held >= 1) { m.lo = Math.min(m.lo, s.v); m.hi = Math.max(m.hi, s.v); }   // first second = settling in
          if (m.held >= 6) {
            const range = m.hi - m.lo;
            const stars = range <= 1.2 ? 3 : range <= 2 ? 2 : 1;
            return { stars, msg: `For 6 s your speed stayed between ${m.lo.toFixed(1)} and ${m.hi.toFixed(1)} m/s.\nA range of ${range.toFixed(1)} m/s${stars < 3 ? " (1.2 m/s or less for 3 stars)" : " - super smooth!"}`, badge: stars === 3 ? "smooth" : null };
          }
        } else { m.start = undefined; m.held = 0; }
        return null;
      },
      status: (s, m) => (m.held ? `Holding steady: ${m.held.toFixed(1)} / 6 s` : "Get into the green band (10.5 - 13.5 m/s)"),
    },
    {
      type: "quiz", title: "Quiz: Acceleration",
      q: "A bike speeds up from 0 m/s to 6 m/s in 3 seconds. What is its acceleration?",
      graph: { t: 5, v: 8, pts: [[0, 0], [3, 6], [5, 6]] },
      options: ["2 m/s^2", "18 m/s^2", "3 m/s"], answer: 0,
      explain: "Acceleration = change in velocity / time taken = (6 - 0) / 3 = 2 m/s^2.\nEvery second the bike goes 2 m/s faster.\nThe unit is m/s^2 (metres per second, per second).",
    },
    {
      type: "drive", title: "Full Throttle",
      goal: "Speed up from 0 to 20 m/s as quickly as you can.",
      intro: "Acceleration is how quickly your velocity changes:\na = (v - u) / t\nwhere u is the starting velocity and v is the final velocity.\n\nHold the GAS all the way and watch the acceleration on the dashboard.",
      done: "Your acceleration got smaller as you went faster, because air resistance grows with speed. That's why the v-t line curves and gets less steep.\nIf you kept going, you'd reach a top speed where the forces balance.",
      tMax: 40, graph: { t: 15, v: 25 },
      tick: (s) => {
        if (s.v < 20) return null;
        const t = Math.round(s.t * 10) / 10;
        const stars = t <= 9.3 ? 3 : t <= 10.5 ? 2 : 1;
        return { stars, msg: `0 to 20 m/s in ${t.toFixed(1)} s.\nAverage acceleration = change in velocity / time = 20 / ${t.toFixed(1)} = about ${(20 / t).toFixed(1)} m/s^2.` };
      },
    },
    {
      type: "drive", title: "Brake Test",
      goal: "You start at 20 m/s. Brake and stop before the barrier at 60 m.",
      intro: "Deceleration is negative acceleration: your velocity gets smaller.\nOur car's brakes give a steady -5 m/s^2: you lose 5 m/s every second.\n\nFrom 20 m/s that takes 20 / 5 = 4 seconds.",
      done: "While braking, the dashboard showed a = -5 m/s^2 and the v-t line sloped DOWN in a straight line.\nA downward slope on a v-t graph means slowing down.",
      startV: 20, tMax: 30, graph: { t: 8, v: 25 }, markers: [{ x: 60, kind: "barrier" }], length: 80,
      tick: (s) => {
        if (s.x >= 60) return { stars: 0, msg: "Crash into the barrier! Brake sooner." };
        if (s.v === 0 && s.t > 0.3) {
          const stars = s.x <= 45 ? 3 : s.x <= 52 ? 2 : 1;
          return { stars, msg: `You stopped after ${s.x.toFixed(1)} m. Braking at 5 m/s^2 from 20 m/s takes 40 m, so brake straight away for 3 stars.` };
        }
        return null;
      },
    },
    {
      type: "drive", title: "Coasting",
      goal: "You start at 20 m/s. Don't touch the pedals: coast until you slow to 10 m/s.",
      intro: "Even with no pedals pressed, a moving car slows down.\nFriction in the tyres and air resistance push backwards on it.\n\nWatch how quickly you slow down at high speed and at lower speed.",
      done: "Air resistance gets much bigger as you go faster, so you slowed down quickly at first, then more gently.\nThat's why the v-t line was steep at first and then flatter.",
      startV: 20, tMax: 60, graph: { t: 20, v: 25 },
      tick: (s, m) => {
        if (s.gas || s.brake) m.used = true;
        if (s.v > 10) return null;
        return { stars: m.used ? 1 : 3, msg: `Friction and air resistance slowed you from 20 to 10 m/s in ${s.t.toFixed(1)} s, over ${s.x.toFixed(0)} m.${m.used ? "\n(You pressed a pedal, so only 1 star.)" : ""}` };
      },
    },
    {
      type: "drive", title: "Perfect Stop",
      goal: "You start at 15 m/s. Stop with your front bumper as close to the line as you can (at 60 m).",
      intro: "Braking distance = v^2 / (2a)\nFrom 15 m/s, braking at 5 m/s^2:\n15 x 15 / (2 x 5) = 225 / 10 = 22.5 m.\n\nThe dashboard shows your braking distance live. Brake when it matches the distance to the line!",
      done: "You used physics to stop on the spot: braking distance = v^2 / (2a).\nReal drivers also travel a 'thinking distance' while they react, before the brakes even start working.",
      startV: 15, tMax: 40, graph: { t: 10, v: 20 }, markers: [{ x: 60, kind: "line" }], length: 80, lineX: 60, showStop: true,
      tick: stopAt(60, [0.5, 1.5, 3]),
    },
    {
      type: "drive", title: "Faster, Further",
      goal: "Now from 25 m/s! Stop as close to the line at 100 m as you can.",
      intro: "Speed makes a BIG difference to braking distance.\nFrom 25 m/s: 25 x 25 / (2 x 5) = 62.5 m.\nThat's almost 3 times as far as from 15 m/s!\n\nBraking distance goes with speed SQUARED.",
      done: "Double the speed means 4 times the braking distance (2 x 2 = 4).\nThat's why speed limits are lower near schools and homes: a faster car needs far more room to stop.",
      startV: 25, tMax: 40, graph: { t: 10, v: 30 }, markers: [{ x: 100, kind: "line" }], length: 120, lineX: 100, showStop: true,
      tick: stopAt(100, [0.5, 1.5, 3]),
    },
    {
      type: "quiz", title: "Quiz: Stopping",
      q: "A car braking at 5 m/s^2 stops in 10 m from 10 m/s. With the same brakes, how far does it need from 20 m/s?",
      options: ["20 m", "40 m", "80 m"], answer: 1,
      explain: "Braking distance = v^2 / (2a) = 20 x 20 / (2 x 5) = 400 / 10 = 40 m.\nDouble the speed = 4 times the braking distance.",
    },
    {
      type: "drive", title: "Graph Match: Up, Flat, Down",
      goal: "Drive so your v-t line stays inside the green band: speed up, hold 10 m/s, then stop.",
      intro: "The shape of a v-t graph tells the story of a journey:\nUpward slope = speeding up\nFlat line = constant speed\nDownward slope = slowing down\n\nFollow the green band for 16 seconds.",
      done: "The steeper the slope, the bigger the acceleration.\nThe slope of a v-t graph IS the acceleration.",
      tMax: 17, graph: { t: 16, v: 15 }, target: [[0, 0], [5, 10], [12, 10], [14, 0], [16, 0]], tband: 2,
      tick: graphMatch([[0, 0], [5, 10], [12, 10], [14, 0], [16, 0]], 2, 16),
    },
    {
      type: "drive", title: "Graph Match: Two Hills",
      goal: "Follow the green band for 20 seconds.",
      intro: "A trickier journey: speed up, cruise, slow down to 4 m/s, cruise, then speed up again.\n\nRead the slopes: steep down = brake hard, gentle up = gentle gas.",
      done: "You can read a whole journey from a v-t graph: when it sped up, how fast it went and when it slowed down.",
      tMax: 21, graph: { t: 20, v: 15 }, target: [[0, 0], [6, 12], [9, 12], [11, 4], [14, 4], [17, 10], [20, 10]], tband: 2,
      tick: graphMatch([[0, 0], [6, 12], [9, 12], [11, 4], [14, 4], [17, 10], [20, 10]], 2, 20),
    },
    {
      type: "drive", title: "Area = Distance",
      goal: "Be exactly 60 m along the road when the clock reaches 8 s.",
      intro: "The AREA under a v-t graph equals the distance travelled.\nDrive at 10 m/s for 6 s: the area is a rectangle, 10 x 6 = 60 m.\nSpeeding up from 0 makes a triangle: area = 1/2 x base x height.\n\nWatch the shaded area grow!",
      done: "The shaded area under your v-t line was the distance you travelled.\nScientists use this to work out distance from a speed record.",
      tMax: 8, graph: { t: 8, v: 20 }, area: true, markers: [{ x: 60, kind: "flag" }], length: 90,
      tick: (s) => {
        if (s.t < 8 - 1e-9) return null;
        const err = Math.abs(s.x - 60);
        const stars = err <= 1 ? 3 : err <= 3 ? 2 : err <= 6 ? 1 : 0;
        return { stars, msg: `At 8 s you had travelled ${s.x.toFixed(1)} m (the shaded area).${stars ? "" : " You need to be within 6 m of 60 m."}` };
      },
    },
    {
      type: "quiz", title: "Quiz: Area",
      q: "This car speeds up from 0 to 10 m/s in 4 s, then keeps going at 10 m/s until 10 s. How far does it travel?",
      graph: { t: 10, v: 12, pts: [[0, 0], [4, 10], [10, 10]], area: true },
      options: ["60 m", "80 m", "100 m"], answer: 1,
      explain: "Area under the graph = distance.\nTriangle: 1/2 x 4 x 10 = 20 m\nRectangle: 6 x 10 = 60 m\nTotal: 20 + 60 = 80 m.",
    },
    {
      type: "drive", title: "Heavy Hauler",
      goal: "Drive the TRUCK up to 10 m/s, then stop it at the line at 110 m.",
      intro: "Acceleration = force / mass (a = F / m).\nThe truck has the same engine force as the car (3000 N) but 3 times the mass (3000 kg instead of 1000 kg).\nSo it gets only a third of the acceleration: 1 m/s^2 instead of 3 m/s^2 (a bit less with friction).\nIts brakes give 3 m/s^2.",
      done: "Same force, more mass = less acceleration.\nThe grey line on the graph shows the car with the same force: it got to 10 m/s much sooner.\nA heavy truck also needs more force to stop.",
      vehicle: "truck", tMax: 60, graph: { t: 25, v: 15 }, markers: [{ x: 110, kind: "line" }], length: 130, lineX: 110, showStop: true, ghost: true,
      tick: (s, m) => {
        if (s.v >= 10) m.reached = true;
        if (s.v === 0 && s.t > 0.5 && s.x > 1 && !m.reached) return { stars: 0, msg: "You need to reach 10 m/s before stopping." };
        return stopAt(110, [0.5, 1.5, 3])(s, m);
      },
      status: (s, m) => (m.reached ? "10 m/s reached: now stop!" : "Reach 10 m/s first"),
    },
    {
      type: "drive", title: "Ice Rink",
      goal: "You start at 10 m/s on ICE. Stop at the line at 70 m.",
      intro: "Ice has very little friction (grip).\nTyres can only push or brake as hard as the grip allows. On this ice that's only about 1 m/s^2 (0.98 m/s^2).\n\nOn a dry road, braking from 10 m/s takes 10 m. On ice: 10 x 10 / (2 x 0.98) = about 51 m!",
      done: "Less friction = smaller deceleration = much longer braking distance.\nThat's why drivers slow down a lot in icy weather.",
      startV: 10, surface: [[-100, 1000]], tMax: 40, graph: { t: 15, v: 12 }, markers: [{ x: 70, kind: "line" }], length: 90, lineX: 70, showStop: true,
      tick: stopAt(70, [0.5, 1.5, 3]),
    },
    {
      type: "drive", title: "Black Ice",
      goal: "Reach 12 m/s on the road, then stop at the line at 160 m - which is on ice!",
      intro: "The road turns to ice at 70 m.\nOn ice you can only brake at about 1 m/s^2, so you'll need to start braking MUCH earlier.\n\nThe braking distance on the dashboard changes when you reach the ice.",
      done: "From 12 m/s on ice: 12 x 12 / (2 x 0.98) = about 73 m of braking. On the road it would be only 14.4 m.",
      surface: [[70, 1000]], tMax: 60, graph: { t: 30, v: 15 }, markers: [{ x: 70, kind: "icesign" }, { x: 160, kind: "line" }], length: 180, lineX: 160, showStop: true,
      tick: (s, m) => {
        if (s.v >= 12) m.reached = true;
        if (s.v === 0 && s.t > 0.5 && s.x > 1 && !m.reached) return { stars: 0, msg: "You need to reach 12 m/s first." };
        return stopAt(160, [1, 3, 6])(s, m);
      },
      status: (s, m) => (m.reached ? "12 m/s reached: now stop!" : "Reach 12 m/s"),
    },
    {
      type: "quiz", title: "Quiz: Velocity",
      q: "Car A drives east at 15 m/s. Car B drives west at 15 m/s. Which is true?",
      options: ["Same speed, different velocity", "Same velocity, different speed", "Same speed and same velocity"], answer: 0,
      explain: "Speed is just how fast you go.\nVelocity is speed in a direction.\nBoth go 15 m/s, but in opposite directions: if east is +15 m/s, then west is -15 m/s.",
    },
    {
      type: "drive", title: "Physics Driving Test",
      goal: "Pass all 4 checks in under 75 s: camera, steady zone, school zone, stop line.",
      intro: "Your final test!\n1) Speed camera at 80 m: pass at 13 - 17 m/s.\n2) Steady zone 120 - 220 m: keep 13 - 17 m/s.\n3) School zone 260 - 340 m: no faster than 8 m/s.\n4) Stop line at 420 m: stop within 4 m before it.\nYou start with 100 points. Score 50 or more to pass.",
      done: "You understand speed, velocity, acceleration and deceleration - and how they keep people safe on the road.",
      tMax: 75, graph: { t: 60, v: 20 }, length: 440, lineX: 420, showStop: true, final: true,
      markers: [{ x: 80, kind: "camera" }, { x: 120, to: 220, kind: "zone", label: "13-17 m/s" }, { x: 260, to: 340, kind: "school", label: "8 m/s max" }, { x: 420, kind: "line" }],
      tick: (s, m, dt) => {
        if (m.score === undefined) { m.score = 100; m.notes = []; m.zoneOut = 0; }
        if (!m.cam && s.x >= 80) {
          m.cam = true;
          if (s.v < 13 || s.v > 17) { m.score -= 20; m.notes.push(`Camera: ${s.v.toFixed(1)} m/s (needed 13 - 17): -20`); } else m.notes.push(`Camera: ${s.v.toFixed(1)} m/s - good`);
        }
        if (s.x >= 120 && s.x <= 220 && (s.v < 13 || s.v > 17)) m.zoneOut += dt;
        if (s.x >= 260 && s.x <= 340 && s.v > 8.05 && !m.school) { m.school = true; m.score -= 20; m.notes.push("School zone: over 8 m/s: -20"); }
        if (s.v === 0 && s.t > 0.5 && s.x < 415) return s.t >= 75 ? { stars: 0, msg: "Time's up! You have 75 s for the whole test." } : null;
        const r = stopAt(420, [1, 2, 4])(s, m);
        if (s.t >= 75 && !r) return { stars: 0, msg: "Time's up! You have 75 s for the whole test." };
        if (!r) return null;
        if (!r.stars) return r;
        const zp = Math.round(m.zoneOut * 5);
        if (zp) m.notes.push(`Steady zone: ${m.zoneOut.toFixed(1)} s outside 13 - 17 m/s: -${zp}`); else m.notes.push("Steady zone: perfect");
        if (!m.school) m.notes.push("School zone: safe");
        const sp = r.gap <= 1 ? 0 : r.gap <= 2 ? 5 : 15;
        m.notes.push(`Stop: ${r.gap.toFixed(1)} m before the line${sp ? ": -" + sp : " - great"}`);
        const score = Math.max(0, m.score - zp - sp);
        const stars = score >= 90 ? 3 : score >= 70 ? 2 : score >= 50 ? 1 : 0;
        return { stars, msg: `Score: ${score} / 100 in ${s.t.toFixed(0)} s.\n` + m.notes.join("\n") + (stars ? "\nYou passed!" : "\nYou need 50 to pass."), badge: stars ? "licensed" : null };
      },
      status: (s, m) => (m.score === undefined ? "" : s.x < 80 ? "Camera at 80 m: 13 - 17 m/s" : s.x < 220 ? "Steady zone: keep 13 - 17 m/s" : s.x < 340 ? "School zone: 8 m/s max" : "Stop at the line at 420 m"),
    },
  ];
  window.VL_LEVELS = LEVELS;
  window.VL_targetAt = targetAt;
})();
