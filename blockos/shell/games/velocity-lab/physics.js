/*
 * Velocity Lab physics (1D, along the road). Works in the browser (window.VelocityPhysics) and Node.
 *
 * Each step:  a = (engine force - air resistance - rolling friction) / m     (gas / coasting)
 *             a = -brake deceleration (a steady value, limited by tyre grip)  (braking)
 *             v = u + a t        x = x + u t + 1/2 a t^2   (exact for the constant a inside a step)
 * Tyres can only push or brake as hard as the grip allows: at most mu * g.
 */
(function (root) {
  "use strict";
  const G = 9.8;          // m/s^2
  const ROLL = 0.015;     // rolling friction coefficient (tyres on the road)
  const SURFACES = {
    road: { name: "Road", mu: 0.7 },   // dry road: grip up to about 6.9 m/s^2
    ice: { name: "Ice", mu: 0.1 },     // ice: grip up to 0.98 m/s^2 (about 1 m/s^2)
  };
  const VEHICLES = {
    car: { name: "Car", mass: 1000, force: 3000, brake: 5, drag: 3 },
    truck: { name: "Truck", mass: 3000, force: 3000, brake: 3, drag: 4 },
  };

  // Acceleration for the current state and controls.
  function accel(v, p, brake, veh, surface) {
    const grip = SURFACES[surface].mu * G;
    if (brake && v > 0) return -Math.min(veh.brake, grip);
    const drive = Math.min((p * veh.force) / veh.mass, grip);
    const resist = (veh.drag * v * v) / veh.mass + (v > 0 ? ROLL * G : 0);
    let a = drive - resist;
    if (v <= 0 && a < 0) a = 0;   // a stopped car doesn't roll backwards
    return a;
  }

  // Advance state s = { x, v, t, p } by dt seconds. input = { gas, brake }.
  // p is the gas pedal (0..1); it moves smoothly so short taps give gentle pushes.
  function step(s, input, veh, surface, dt) {
    if (input.gas && !input.brake) s.p = Math.min(1, s.p + dt / 0.25);
    else s.p = Math.max(0, s.p - dt / 0.15);
    const a = accel(s.v, s.p, !!input.brake, veh, surface);
    if (a < 0 && s.v + a * dt <= 0) {
      // comes to rest inside this step: stops exactly after u^2 / (2|a|)
      s.x += (s.v * s.v) / (2 * -a);
      s.v = 0;
    } else {
      s.x += s.v * dt + 0.5 * a * dt * dt;
      s.v += a * dt;
    }
    s.t += dt;
    s.a = a;
    return s;
  }

  const brakingDistance = (v, a) => (v * v) / (2 * a);
  const brakeDecel = (veh, surface) => Math.min(veh.brake, SURFACES[surface].mu * G);

  const api = { G, ROLL, SURFACES, VEHICLES, accel, step, brakingDistance, brakeDecel };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.VelocityPhysics = api;
})(typeof window !== "undefined" ? window : globalThis);
