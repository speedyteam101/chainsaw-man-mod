/*
 * Circuit Builder levels. The board has 11 x 7 dots (x 0-10, y 0-6).
 * A part sits on the edge between two neighbouring dots:
 *   "h3,2" = horizontal edge from dot (3,2) to (4,2);  "v3,2" = vertical edge from (3,2) to (3,3).
 * Cells: dir 1 puts the + end at the right / bottom dot, dir -1 at the left / top dot.
 * LEDs: dir 1 lets current through from left to right / top to bottom.
 * lock: the part can't be erased or replaced (you can still tap it with the Hand).
 */
(function () {
  "use strict";
  // Wires along a straight run of dots.
  function run(x1, y1, x2, y2, opts) {
    const out = [];
    if (y1 === y2) for (let x = Math.min(x1, x2); x < Math.max(x1, x2); x++) out.push(["h" + x + "," + y1, "wire", opts || { lock: 1 }]);
    else for (let y = Math.min(y1, y2); y < Math.max(y1, y2); y++) out.push(["v" + x1 + "," + y, "wire", opts || { lock: 1 }]);
    return out;
  }
  const L = { lock: 1 };
  const all = (arr, f) => arr.length > 0 && arr.every(f);

  const LEVELS = [
    {
      title: "First Light",
      goal: "Join the bottom gap with wires to light the bulb.",
      intro: "Electricity needs a complete loop, called a circuit.\nCurrent flows out of the + end of the cell, through the bulb and back into the - end.\n\nPick the Wire tool and drag from dot to dot to close the gap.",
      hint: "Drag along the bottom row of dots from the bottom of the cell to the bottom of the bulb.",
      done: "The loop is complete, so current flows and the bulb lights.\nThe moving dots show the current going from + to - round the loop. (Tiny particles called electrons really drift the other way!)\nOne 1.5 V cell pushes 0.3 A through this 5 ohm bulb: I = V / R = 1.5 / 5 = 0.3 A.",
      inv: { wire: 12 },
      parts: [["v2,2", "cell", { dir: -1, lock: 1 }], ["v8,2", "bulb", L], ...run(2, 2, 8, 2)],
      check: (S) => S.of("bulb").some((b) => b.on),
    },
    {
      title: "Build It Yourself",
      goal: "Place a cell and a bulb, then wire them into a loop.",
      intro: "Now build a whole circuit on your own.\nPick the Cell, tap a gap between two dots to place it, do the same with the Bulb, then join them with wires.\n\nTip: the + end of a cell has the little bump.",
      hint: "Put the cell and the bulb on two different edges, then make one loop of wire that goes through both.",
      done: "You built a complete circuit!\nIf there is a gap anywhere in the loop, no current can flow at all - not even a little bit.",
      inv: { cell: 1, bulb: 1, wire: 24 },
      parts: [],
      check: (S) => S.of("bulb").some((b) => b.on),
    },
    {
      title: "Switch On",
      goal: "Put a switch in the gap. Turn the bulb ON, then OFF.",
      intro: "A switch makes or breaks the loop.\nClosed switch = complete loop = current flows.\nOpen switch = a gap = no current.\n\nPlace the switch in the gap, then tap it with the Hand to open and close it.",
      hint: "Place the switch on the gap in the bottom wire. Then pick the Hand and tap the switch.",
      done: "A switch works by opening a gap in the circuit.\nOpen: the loop is broken, so no current flows anywhere in it.\nClosed: the loop is complete again.",
      inv: { switch: 1 },
      parts: [["v2,2", "cell", { dir: -1, lock: 1 }], ["v8,2", "bulb", L], ...run(2, 2, 8, 2), ...run(2, 3, 5, 3), ...run(6, 3, 8, 3)],
      check: (S, m) => {
        const sw = S.of("switch")[0], b = S.of("bulb")[0];
        if (!sw || !b) return false;
        if (sw.part.on && b.on) m.on = true;
        if (m.on && !sw.part.on && !b.on) return true;
        return false;
      },
    },
    {
      title: "Bulbs in a Row",
      goal: "Light BOTH bulbs using one single loop (series).",
      intro: "In a series circuit the parts are joined one after another in ONE loop.\nThe same current goes through every part.\n\nPlace both bulbs in the same loop with the cell.",
      hint: "Make one big loop: cell, bulb, bulb, back to the cell. No branches.",
      done: "Series: the two bulbs share the cell's 1.5 V, so each gets 0.75 V.\nTotal resistance = 5 + 5 = 10 ohm, so I = 1.5 / 10 = 0.15 A - half as much current.\nEach bulb gets a quarter of the power (0.11 W instead of 0.45 W), so they are much dimmer.\nTry the Meter tool on each bulb!",
      inv: { bulb: 2, wire: 30 },
      parts: [["v1,2", "cell", { dir: -1, lock: 1 }]],
      check: (S) => {
        const b = S.of("bulb");
        return b.length === 2 && all(b, (x) => x.on && Math.abs(Math.abs(x.V) - 0.75) < 0.05) && Math.abs(Math.abs(b[0].I) - Math.abs(b[1].I)) < 0.005;
      },
    },
    {
      title: "Parallel Power",
      goal: "Light both bulbs at FULL brightness (1.5 V each).",
      intro: "In a parallel circuit each bulb has its own branch (its own path) back to the cell.\n\nGive each bulb its own loop to the cell and they will both be bright.",
      hint: "Connect both ends of the first bulb to the cell. Then connect both ends of the second bulb to the same two cell wires, like a ladder.",
      done: "Parallel: each bulb gets the full 1.5 V, so both stay bright.\nEach branch takes 0.3 A, so the cell gives 0.3 + 0.3 = 0.6 A in total.\nMore current means the cell gets used up faster.",
      inv: { bulb: 2, wire: 36 },
      parts: [["v1,2", "cell", { dir: -1, lock: 1 }]],
      check: (S) => { const b = S.of("bulb"); return b.length === 2 && all(b, (x) => x.on && Math.abs(x.V) >= 1.45); },
      badge: ["parallel-pro", "Parallel Pro", "Light two bulbs in parallel at full brightness."],
    },
    {
      title: "A Switch Each",
      goal: "Give each bulb its own switch. Show: only the first bulb on, only the second on, then both on.",
      intro: "Lights in a house are wired in parallel, so each light can have its own switch.\n\nBuild two parallel branches, each with a bulb AND a switch.",
      hint: "Each branch: switch + bulb in a row. Both branches join the same two cell wires.",
      done: "In parallel, opening one branch doesn't stop the current in the other branch.\nThat is why turning off your bedroom light doesn't switch off the kitchen light.",
      inv: { bulb: 2, switch: 2, wire: 40 },
      parts: [["v1,2", "cell", { dir: -1, lock: 1 }]],
      check: (S, m) => {
        const b = S.of("bulb");
        if (b.length !== 2) return false;
        const pat = b.map((x) => (x.on ? 1 : 0)).join("");
        m[pat] = true;
        return m["10"] && m["01"] && m["11"];
      },
    },
    {
      title: "Stack the Cells",
      goal: "Give the bulb about 3 V using two cells.",
      intro: "Cells joined + to - in a row (in series) add up their voltages:\n1.5 V + 1.5 V = 3 V.\n\nA battery is really several cells joined like this.",
      hint: "Put the two cells end to end on neighbouring edges, both with their + ends pointing the same way.",
      done: "Two cells in series: 1.5 V + 1.5 V = 3 V.\nTwice the voltage pushes twice the current through the bulb (I = 3 / 5 = 0.6 A), so the bulb is 4 times as powerful (P = 3 x 0.6 = 1.8 W). Very bright!",
      inv: { cell: 2, bulb: 1, wire: 30 },
      parts: [],
      check: (S) => S.of("bulb").some((b) => b.on && Math.abs(Math.abs(b.V) - 3) < 0.1),
    },
    {
      title: "Back to Front",
      goal: "One cell is the wrong way round. Fix it so the bulb gets 3 V.",
      intro: "The bulb is dark even though the loop is complete!\nOne cell faces the wrong way, so its push cancels the other one: 1.5 V - 1.5 V = 0 V.\n\nTap a cell with the Hand to turn it round.",
      hint: "Look at the bumps (+ ends). Both should point the same way. Tap the lower cell with the Hand.",
      done: "Cells only add up when they all face the same way (+ to -).\nIf one is backwards, it pushes against the others.",
      inv: {},
      parts: [["v2,1", "cell", { dir: -1, lock: 1 }], ["v2,2", "cell", { dir: 1, lock: 1 }], ...run(2, 1, 8, 1), ["v8,1", "bulb", L], ...run(8, 2, 8, 3), ...run(2, 3, 8, 3)],
      check: (S) => S.of("bulb").some((b) => b.on && Math.abs(Math.abs(b.V) - 3) < 0.1),
    },
    {
      title: "Dim the Light",
      goal: "Add a resistor so the bulb still glows but takes less than 0.2 A.",
      intro: "A resistor resists (slows) the current.\nMore resistance means less current: I = V / R.\n\nTap a resistor with the Hand to change its value (10, 47 or 100 ohm).",
      hint: "Put the resistor in the gap. Try 10 ohm: 1.5 / (5 + 10) = 0.1 A.",
      done: "With 10 ohm added, the total is 5 + 10 = 15 ohm, so I = 1.5 / 15 = 0.1 A.\nLess current, so the bulb is dimmer. With 47 or 100 ohm the current is too small to make it glow.",
      inv: { resistor: 1 },
      resVal: 10,
      parts: [["v2,2", "cell", { dir: -1, lock: 1 }], ["v8,2", "bulb", L], ...run(2, 2, 8, 2), ...run(2, 3, 5, 3), ...run(6, 3, 8, 3)],
      check: (S) => {
        const b = S.of("bulb")[0], r = S.of("resistor")[0];
        return b && r && b.on && Math.abs(b.I) < 0.2 && Math.abs(r.I) > 0.05;
      },
    },
    {
      title: "Fuse Lab",
      goal: "Make a short circuit with ONE wire (top to bottom, skipping the bulb). Then fix it and light the bulb again.",
      intro: "A short circuit is a path with almost no resistance from + to -.\nThe current gets huge and wires and batteries get very hot.\nA fuse is a thin wire that melts and breaks the loop when the current is too big (here, over 2 A).\n\nIn this game it is safe: try it!",
      hint: "Place one wire straight down from the top wire to the bottom wire. After the fuse blows, erase that wire, then tap the fuse with the Hand to fit a new one.",
      done: "The fuse melted and broke the loop before anything got dangerously hot.\nNEVER short-circuit real batteries: they can get very hot, leak or even catch fire.\nHomes have fuses or circuit breakers to protect the wiring in the same way.",
      inv: { wire: 3 },
      parts: [["v0,2", "cell", { dir: -1, lock: 1 }], ["h0,2", "fuse", L], ...run(1, 2, 8, 2), ["v8,2", "bulb", L], ...run(0, 3, 8, 3)],
      check: (S, m) => {
        if (S.events.some((e) => e.type === "fuse")) m.blown = true;
        const f = S.of("fuse")[0], b = S.of("bulb")[0];
        return m.blown && f && !f.part.broken && b && b.on;
      },
    },
    {
      title: "LED Lights",
      goal: "Light the LED without burning it out.",
      intro: "LED means light-emitting diode. It only lets current through ONE way: the arrow on it shows which way.\nIt needs about 2 V to light, so use both cells (3 V).\nToo much current burns it out, so an LED needs a resistor in its loop.",
      hint: "Loop: cells, resistor, LED. The LED arrow must point the same way the current flows (from the + end round to the - end). Tap the LED with the Hand to flip it.",
      done: "The resistor keeps the current small: I = (3 - 2) / (47 + 2) = about 0.02 A (20 mA).\nWithout it the current would be far too big and the LED would burn out.",
      inv: { led: 1, resistor: 1, wire: 30 },
      resVal: 47,
      parts: [["v1,2", "cell", { dir: -1, lock: 1 }], ["v1,3", "cell", { dir: -1, lock: 1 }]],
      check: (S) => S.of("led").some((l) => l.on && !l.part.broken),
    },
    {
      title: "One Way Only",
      goal: "Make the GREEN LED light and the RED LED go out.",
      intro: "These two LEDs point opposite ways.\nCurrent can only go through an LED in the direction of its arrow, so only one of them lights.\n\nTap things with the Hand to turn them round.",
      hint: "Turn round BOTH cells, or turn round both LEDs.",
      done: "An LED is a one-way valve for current.\nTurning the cells round reverses the current, so the other LED lights.\nThat's how some lights show which way current flows.",
      inv: {},
      resVal: 47,
      parts: [["v2,2", "cell", { dir: -1, lock: 1 }], ["v2,3", "cell", { dir: -1, lock: 1 }], ["h2,2", "resistor", { lock: 1, val: 47 }], ...run(3, 2, 8, 2),
        ["v6,2", "led", { dir: 1, lock: 1, color: "red" }], ...run(6, 3, 6, 4), ["v8,2", "led", { dir: -1, lock: 1, color: "green" }], ...run(8, 3, 8, 4), ...run(2, 4, 8, 4)],
      check: (S) => {
        const l = S.of("led"), g = l.find((x) => x.part.color === "green"), r = l.find((x) => x.part.color === "red");
        return g && r && g.on && !r.on;
      },
      badge: ["led-master", "LED Master", "Light an LED safely and make current choose the right way."],
    },
    {
      title: "Motor Spin",
      goal: "Make the motor spin one way, then the other way.",
      intro: "A motor turns electrical energy into movement (kinetic energy).\nWhich way it spins depends on which way the current goes through it.\n\nTap the cell with the Hand to turn it round.",
      hint: "Tap the cell with the Hand.",
      done: "Swapping the cell round reverses the current, and the motor spins the other way.\nToy cars use this to drive forwards and backwards.",
      inv: {},
      parts: [["v2,2", "cell", { dir: -1, lock: 1 }], ...run(2, 2, 8, 2), ["v8,2", "motor", L], ...run(2, 3, 8, 3)],
      check: (S, m) => {
        const mo = S.of("motor")[0];
        if (mo && mo.on) m[mo.I > 0 ? "f" : "b"] = true;
        return m.f && m.b;
      },
    },
    {
      title: "Door Alarm",
      goal: "One switch must turn the buzzer AND a bright bulb on together, then off together.",
      intro: "A buzzer turns electrical energy into sound.\nBuild an alarm: when the switch closes, the buzzer sounds and the light comes on at full brightness.",
      hint: "Put the switch next to the cell, then split into two parallel branches: one with the buzzer, one with the bulb.",
      done: "The switch is in the main wire, which both branches share, so it controls both.\nThe buzzer and the bulb are in parallel, so each gets the full 1.5 V.",
      inv: { switch: 1, buzzer: 1, bulb: 1, wire: 36 },
      parts: [["v1,2", "cell", { dir: -1, lock: 1 }]],
      check: (S, m) => {
        const sw = S.of("switch")[0], bz = S.of("buzzer")[0], b = S.of("bulb")[0];
        if (!sw || !bz || !b) return false;
        if (sw.part.on && bz.on && b.on && Math.abs(b.V) >= 1.45) m.on = true;
        return m.on && !sw.part.on && !bz.on && !b.on;
      },
    },
    {
      title: "Power a House",
      goal: "Wire the cell to the house so its lights come on.",
      intro: "Welcome to Brick Town! Each house has a light inside.\nRun wires from the cell all the way to the house and back.",
      hint: "Two wires are needed: one from each end of the cell to each side of the house.",
      done: "The house is lit!\nReal homes use mains electricity of about 230 V (or 120 V in some countries). That is very dangerous: never touch wall sockets or mains wires.",
      inv: { wire: 40 },
      parts: [["v1,4", "cell", { dir: -1, lock: 1 }], ["v8,1", "house", L]],
      check: (S) => S.of("house").some((h) => h.on),
    },
    {
      title: "Street Lights",
      goal: "Light all three houses at full brightness (about 1.5 V each).",
      intro: "Three houses, one cell.\nIf you connect them in series they share the voltage and get dim.\nHow can each house get the full 1.5 V?",
      hint: "Parallel! Run a top wire and a bottom wire along the street and connect each house between them.",
      done: "In parallel every house gets the full 1.5 V.\nThat is how real streets are wired: each home is connected across the supply, not one after another.",
      inv: { wire: 46 },
      parts: [["v1,3", "cell", { dir: -1, lock: 1 }], ["v3,1", "house", L], ["v6,1", "house", L], ["v9,1", "house", L]],
      check: (S) => { const h = S.of("house"); return h.length === 3 && all(h, (x) => Math.abs(x.V) >= 1.45); },
    },
    {
      title: "Safe Street",
      goal: "Light all houses fully with a main fuse and a main switch. Then switch the street off.",
      intro: "A real supply has a main fuse and a main switch that protect and control everything.\nPut the fuse and switch in the wire next to the cell, where ALL the current passes.",
      hint: "Cell, then fuse, then switch, then split into the three house branches.",
      done: "All the current for the street passes through the main fuse (3 x 0.3 = 0.9 A), so it can protect every house.\nThe main switch turns everything off at once.",
      inv: { wire: 46, fuse: 1, switch: 1 },
      parts: [["v1,3", "cell", { dir: -1, lock: 1 }], ["v3,1", "house", L], ["v6,1", "house", L], ["v9,1", "house", L]],
      check: (S, m) => {
        const h = S.of("house"), f = S.of("fuse")[0], sw = S.of("switch")[0];
        if (h.length !== 3 || !f || !sw || f.part.broken) return false;
        if (sw.part.on && all(h, (x) => Math.abs(x.V) >= 1.45) && Math.abs(f.I) >= 0.85 && Math.abs(sw.I) >= 0.85) m.on = true;
        return m.on && !sw.part.on && all(h, (x) => !x.on);
      },
    },
    {
      title: "Power Station",
      goal: "Light all 4 houses at about 1.5 V each from the 3 V supply - without blowing the 2 A fuse.",
      intro: "Two cells give 3 V, which is too much for one house.\nBut if all 4 houses are in parallel, the 3 V supply would push 4 x 0.6 = 2.4 A and melt the fuse!\nCan you share the voltage cleverly?",
      hint: "Put the houses in pairs. Two houses in series share 3 V: 1.5 V each. Then connect the two pairs in parallel.",
      done: "Brilliant engineering! Each pair in series shares 3 V, so each house gets 1.5 V.\nEach pair takes 3 / 10 = 0.3 A, so the fuse carries only 0.6 A.",
      inv: { wire: 50, house: 4 },
      parts: [["v1,2", "cell", { dir: -1, lock: 1 }], ["v1,3", "cell", { dir: -1, lock: 1 }], ["h1,2", "fuse", L]],
      check: (S) => {
        const h = S.of("house"), f = S.of("fuse")[0];
        return h.length === 4 && f && !f.part.broken && Math.abs(f.I) > 0.5 && all(h, (x) => Math.abs(Math.abs(x.V) - 1.5) <= 0.1);
      },
    },
  ];

  const TOWN = [14, 15, 16, 17];  // indexes of the Brick Town levels
  window.CB_LEVELS = LEVELS;
  window.CB_TOWN = TOWN;
})();
