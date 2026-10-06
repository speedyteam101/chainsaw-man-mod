/*
 * Element Crafter data: the elements in the atom tray and every recipe in the Discovery Book.
 *
 * Every recipe's atom counts are worked out from its formula (see parseFormula), so the
 * recipe and the formula can never disagree. Structures are 2D ball-and-stick layouts
 * (1 unit = one bond length; angles in degrees, 0 = right, 90 = down).
 */
(function () {
  "use strict";

  // ---------------------------------------------------------------- elements
  // bonds: how many bonds the atom usually makes (shown as stubs). charge: the ion a metal usually forms.
  // row/col: position in the periodic table. unlock: discoveries needed (0 = from the start).
  const ELEMENTS = {
    H:  { n: 1,  name: "Hydrogen",   row: 1, col: 1,  bonds: 1, unlock: 0,  color: "#f4f4f5", ink: "#111", size: 0.24,
          fact: "The lightest element and the most common one in the universe. Stars are mostly hydrogen." },
    He: { n: 2,  name: "Helium",     row: 1, col: 18, bonds: 0, unlock: 2,  color: "#67e8f9", ink: "#111", size: 0.3, noble: true,
          fact: "A noble gas: its outer electron shell is already full, so it doesn't bond with other atoms." },
    C:  { n: 6,  name: "Carbon",     row: 2, col: 14, bonds: 4, unlock: 0,  color: "#3f3f46", ink: "#fff", size: 0.32,
          fact: "Found in every living thing. Diamond and pencil graphite are both pure carbon." },
    N:  { n: 7,  name: "Nitrogen",   row: 2, col: 15, bonds: 3, unlock: 0,  color: "#3b82f6", ink: "#fff", size: 0.32,
          fact: "About 78% of the air around you is nitrogen gas." },
    O:  { n: 8,  name: "Oxygen",     row: 2, col: 16, bonds: 2, unlock: 0,  color: "#ef4444", ink: "#fff", size: 0.32,
          fact: "About 21% of the air is oxygen gas. Your body needs it to release energy from food." },
    F:  { n: 9,  name: "Fluorine",   row: 2, col: 17, bonds: 1, unlock: 21, color: "#bef264", ink: "#111", size: 0.3,
          fact: "The most reactive element of all. Fluoride compounds in toothpaste help protect teeth." },
    Na: { n: 11, name: "Sodium",     row: 3, col: 1,  charge: 1, unlock: 0,  color: "#8b5cf6", ink: "#fff", size: 0.36,
          fact: "A soft metal you could cut with a butter knife. It fizzes and reacts strongly with water." },
    Mg: { n: 12, name: "Magnesium",  row: 3, col: 2,  charge: 2, unlock: 9,  color: "#2dd4bf", ink: "#111", size: 0.34,
          fact: "Burns with a dazzling white light, so it's used in flares and fireworks." },
    Al: { n: 13, name: "Aluminum",   row: 3, col: 13, charge: 3, unlock: 27, color: "#cbd5e1", ink: "#111", size: 0.32,
          fact: "Also spelled aluminium. The most common metal in Earth's crust, used for cans and foil." },
    Si: { n: 14, name: "Silicon",    row: 3, col: 14, bonds: 4, unlock: 24, color: "#d4a373", ink: "#111", size: 0.36,
          fact: "Computer chips are made from silicon. Sand is mostly silicon joined to oxygen." },
    P:  { n: 15, name: "Phosphorus", row: 3, col: 15, bonds: 3, flex: "3 or 5", unlock: 18, color: "#fb923c", ink: "#111", size: 0.36,
          fact: "Found in your bones, your teeth and your DNA." },
    S:  { n: 16, name: "Sulfur",     row: 3, col: 16, bonds: 2, flex: "2, 4 or 6", unlock: 4, color: "#facc15", ink: "#111", size: 0.36,
          fact: "A bright yellow solid found near volcanoes." },
    Cl: { n: 17, name: "Chlorine",   row: 3, col: 17, bonds: 1, unlock: 0,  color: "#22c55e", ink: "#111", size: 0.36,
          fact: "A yellow-green, poisonous gas. Its compounds keep pool and tap water free of germs." },
    K:  { n: 19, name: "Potassium",  row: 4, col: 1,  charge: 1, unlock: 12, color: "#d946ef", ink: "#fff", size: 0.4,
          fact: "Bananas are a good source of potassium. The pure metal reacts with water even faster than sodium." },
    Ca: { n: 20, name: "Calcium",    row: 4, col: 2,  charge: 2, unlock: 6,  color: "#94a3b8", ink: "#111", size: 0.38,
          fact: "Your bones and teeth contain lots of calcium. The pure element is a shiny metal." },
    Fe: { n: 26, name: "Iron",       row: 4, col: 8,  charge: 3, chargeText: "2+/3+", unlock: 15, color: "#c2410c", ink: "#fff", size: 0.34,
          fact: "Earth's core is mostly iron. Iron in your blood helps carry oxygen around your body." },
    Cu: { n: 29, name: "Copper",     row: 4, col: 11, charge: 2, chargeText: "2+", unlock: 30, color: "#b45309", ink: "#fff", size: 0.34,
          fact: "Used in electric wires. Old copper roofs and statues slowly turn green." },
  };
  const ELEMENT_ORDER = ["H", "C", "N", "O", "Na", "Cl", "He", "S", "Ca", "Mg", "K", "Fe", "P", "F", "Si", "Al", "Cu"];

  // The first four rows of the periodic table, for the picker (symbol per [row][col], 1-based).
  const TABLE = [
    [1, 1, "H"], [1, 18, "He"],
    [2, 1, "Li"], [2, 2, "Be"], [2, 13, "B"], [2, 14, "C"], [2, 15, "N"], [2, 16, "O"], [2, 17, "F"], [2, 18, "Ne"],
    [3, 1, "Na"], [3, 2, "Mg"], [3, 13, "Al"], [3, 14, "Si"], [3, 15, "P"], [3, 16, "S"], [3, 17, "Cl"], [3, 18, "Ar"],
    [4, 1, "K"], [4, 2, "Ca"], [4, 3, "Sc"], [4, 4, "Ti"], [4, 5, "V"], [4, 6, "Cr"], [4, 7, "Mn"], [4, 8, "Fe"], [4, 9, "Co"],
    [4, 10, "Ni"], [4, 11, "Cu"], [4, 12, "Zn"], [4, 13, "Ga"], [4, 14, "Ge"], [4, 15, "As"], [4, 16, "Se"], [4, 17, "Br"], [4, 18, "Kr"],
  ];
  const TABLE_NUMBERS = { H: 1, He: 2, Li: 3, Be: 4, B: 5, C: 6, N: 7, O: 8, F: 9, Ne: 10, Na: 11, Mg: 12, Al: 13, Si: 14, P: 15, S: 16, Cl: 17, Ar: 18,
    K: 19, Ca: 20, Sc: 21, Ti: 22, V: 23, Cr: 24, Mn: 25, Fe: 26, Co: 27, Ni: 28, Cu: 29, Zn: 30, Ga: 31, Ge: 32, As: 33, Se: 34, Br: 35, Kr: 36 };

  // ---------------------------------------------------------------- formulas

  // "Ca3(PO4)2" -> { Ca: 3, P: 2, O: 8 }
  function parseFormula(f) {
    let i = 0;
    function group() {
      const out = {};
      while (i < f.length && f[i] !== ")") {
        let part;
        if (f[i] === "(") { i++; part = group(); i++; }
        else {
          let sym = f[i++];
          while (i < f.length && /[a-z]/.test(f[i])) sym += f[i++];
          part = { [sym]: 1 };
        }
        let num = "";
        while (i < f.length && /[0-9]/.test(f[i])) num += f[i++];
        const k = num ? Number(num) : 1;
        for (const s in part) out[s] = (out[s] || 0) + part[s] * k;
      }
      return out;
    }
    return group();
  }

  // ---------------------------------------------------------------- structure builder

  function M() {
    const atoms = [], bonds = [];
    const api = {
      atoms, bonds,
      a(el, x, y, q) { atoms.push({ el, x, y, q: q || 0 }); return atoms.length - 1; },
      // attach a new atom to atom i, in direction deg
      t(i, el, deg, order, q, len) {
        const L = len || (el === "H" || atoms[i].el === "H" ? 0.8 : 1);
        const r = (deg * Math.PI) / 180;
        const j = api.a(el, atoms[i].x + Math.cos(r) * L, atoms[i].y + Math.sin(r) * L, q);
        bonds.push([i, j, order || 1]);
        return j;
      },
      // a dashed bond leading off the picture (the network carries on)
      ghost(i, deg) {
        const r = (deg * Math.PI) / 180;
        atoms.push({ el: null, x: atoms[i].x + Math.cos(r) * 0.75, y: atoms[i].y + Math.sin(r) * 0.75, q: 0 });
        bonds.push([i, atoms.length - 1, 0]);
      },
      b(i, j, o) { bonds.push([i, j, o || 1]); },
    };
    return api;
  }
  const H3 = (m, c, a, b, d) => { m.t(c, "H", a); m.t(c, "H", b); m.t(c, "H", d); };

  function carbonate(m, x, y) {          // CO3 2-: one C=O and two C-O(-)
    const c = m.a("C", x, y);
    m.t(c, "O", 270, 2); m.t(c, "O", 150, 1, -1); m.t(c, "O", 30, 1, -1);
    return c;
  }
  function sulfate(m, x, y) {            // SO4 2-: two S=O and two S-O(-)
    const s = m.a("S", x, y);
    m.t(s, "O", 225, 2); m.t(s, "O", 315, 2); m.t(s, "O", 135, 1, -1); m.t(s, "O", 45, 1, -1);
    return s;
  }
  function phosphate(m, x, y) {          // PO4 3-: one P=O and three P-O(-)
    const p = m.a("P", x, y);
    m.t(p, "O", 270, 2); m.t(p, "O", 180, 1, -1); m.t(p, "O", 90, 1, -1); m.t(p, "O", 0, 1, -1);
    return p;
  }
  function chain(m, n) {                 // straight alkane chain CnH(2n+2)
    const cs = [];
    for (let i = 0; i < n; i++) {
      const c = m.a("C", i, 0);
      if (i) m.b(cs[i - 1], c);
      cs.push(c);
      m.t(c, "H", 270); m.t(c, "H", 90);
    }
    m.t(cs[0], "H", 180); m.t(cs[n - 1], "H", 0);
  }

  // ---------------------------------------------------------------- recipes
  // kind: element | molecule | ionic | network
  const KIND_TEXT = {
    element: "Element: made of only one kind of atom",
    molecule: "Molecular compound: atoms share electrons in bonds",
    ionic: "Ionic compound: + and − ions held together by their charges",
    network: "Giant network: a huge lattice of bonded atoms",
  };

  const R = [];
  function add(formula, name, kind, fact, where, build, note) {
    const m = M();
    build(m);
    R.push({ id: formula, formula, name, kind, fact, where, note: note || "", atoms: m.atoms, bonds: m.bonds });
  }

  // --- starting elements: H C N O Na Cl
  add("H2", "Hydrogen gas", "element",
    "Hydrogen is the lightest gas. Stars like our Sun shine by squeezing hydrogen into helium.",
    "The Sun and stars. Some buses and rockets use hydrogen as fuel.",
    (m) => { const h = m.a("H", 0, 0); m.t(h, "H", 0); });
  add("O2", "Oxygen gas", "element",
    "About 21% of the air is oxygen gas. Your cells use it to release energy from food.",
    "The air you breathe. Plants give it off in sunlight.",
    (m) => { const o = m.a("O", 0, 0); m.t(o, "O", 0, 2); },
    "The two oxygen atoms share a double bond.");
  add("H2O", "Water", "molecule",
    "Water is one of the few things found naturally on Earth as a solid, a liquid and a gas. Ice floats because it is less dense than liquid water.",
    "Oceans, rain, clouds, and about 60% of your body.",
    (m) => { const o = m.a("O", 0, 0); m.t(o, "H", 142); m.t(o, "H", 38); },
    "Water is bent, not straight: the angle between the two bonds is about 104.5 degrees.");
  add("N2", "Nitrogen gas", "element",
    "About 78% of the air is nitrogen gas. Its two atoms share a super-strong triple bond, so it hardly reacts with anything.",
    "The air. Bags of chips are often filled with nitrogen to keep the chips fresh.",
    (m) => { const n = m.a("N", 0, 0); m.t(n, "N", 0, 3); });
  add("Cl2", "Chlorine gas", "element",
    "Chlorine gas is yellow-green and poisonous, but chlorine is used to make lots of useful things, like PVC pipes.",
    "Water treatment plants use chlorine to kill germs in drinking water.",
    (m) => { const c = m.a("Cl", 0, 0); m.t(c, "Cl", 0); });
  add("HCl", "Hydrogen chloride", "molecule",
    "Dissolved in water it is called hydrochloric acid. Your stomach makes hydrochloric acid to help digest food and kill germs.",
    "Your stomach, and factories that clean rust off steel.",
    (m) => { const h = m.a("H", 0, 0); m.t(h, "Cl", 0); });
  add("NaCl", "Sodium chloride (table salt)", "ionic",
    "Sodium is a metal that reacts with water, and chlorine is a poisonous gas, but together they make the salt you eat!",
    "Salt shakers, seawater and salt mines.",
    (m) => { m.a("Na", -0.8, 0, 1); m.a("Cl", 0.8, 0, -1); },
    "Sodium gives one electron to chlorine, making a Na⁺ ion and a Cl⁻ ion. In a salt crystal, huge numbers of them stack into tiny cubes.");
  add("CO2", "Carbon dioxide", "molecule",
    "You breathe out carbon dioxide, and plants take it in to make their food by photosynthesis.",
    "Your breath, the bubbles in fizzy drinks, and dry ice (frozen CO₂).",
    (m) => { const c = m.a("C", 0, 0); m.t(c, "O", 180, 2); m.t(c, "O", 0, 2); },
    "Carbon makes two double bonds, one to each oxygen. The molecule is straight.");
  add("CO", "Carbon monoxide", "molecule",
    "Carbon monoxide has no color and no smell, but it is poisonous. That's why homes have CO alarms.",
    "Car exhaust and smoke from burning fuel.",
    (m) => { const c = m.a("C", 0, 0); m.t(c, "O", 0, 3); },
    "A rule-breaker: carbon and oxygen share a triple bond here, so carbon makes only 3 bonds.");
  add("NH3", "Ammonia", "molecule",
    "Ammonia has a very sharp smell. Most of the ammonia made in factories is turned into fertilizer that helps grow food.",
    "Fertilizer, and some glass cleaners.",
    (m) => { const n = m.a("N", 0, 0); m.t(n, "H", 90); m.t(n, "H", 210); m.t(n, "H", 330); },
    "In 3D, ammonia is shaped like a short pyramid with nitrogen on top.");
  add("CH4", "Methane", "molecule",
    "Methane is the main gas in natural gas. Cows burp out lots of methane while they digest grass.",
    "Gas stoves and heaters, swamps, and cow burps.",
    (m) => { const c = m.a("C", 0, 0); for (const d of [0, 90, 180, 270]) m.t(c, "H", d); },
    "Drawn flat here. In 3D the four hydrogens point to the corners of a shape called a tetrahedron.");
  add("O3", "Ozone", "element",
    "High in the sky, the ozone layer absorbs much of the Sun's harmful ultraviolet (UV) light.",
    "The ozone layer, and the sharp smell in the air after a lightning storm.",
    (m) => { const o = m.a("O", 0, 0); m.t(o, "O", 150, 2); m.t(o, "O", 30); },
    "A rule-breaker: the middle oxygen makes 3 bonds. Ozone is bent, like water.");
  add("H2O2", "Hydrogen peroxide", "molecule",
    "Hydrogen peroxide slowly breaks down into water and oxygen gas. It fizzes on a cut because a substance in your body speeds that up.",
    "First-aid kits and hair bleach.",
    (m) => { const o1 = m.a("O", 0, 0); const o2 = m.t(o1, "O", 0); m.t(o1, "H", 220); m.t(o2, "H", 40); });
  add("NaOH", "Sodium hydroxide (lye)", "ionic",
    "Sodium hydroxide is a strong base. Mixed with fats and oils, it makes soap.",
    "Soap making and drain cleaners.",
    (m) => { m.a("Na", -0.9, 0, 1); const o = m.a("O", 0.7, 0, -1); m.t(o, "H", 0); },
    "Made of Na⁺ ions and hydroxide (OH⁻) ions. Inside the hydroxide ion, O and H share a bond.");
  add("NaClO", "Sodium hypochlorite (bleach)", "ionic",
    "Household bleach is sodium hypochlorite dissolved in water. It kills germs. Never mix bleach with other cleaners: that can make poisonous gases.",
    "Bleach and swimming pool cleaners.",
    (m) => { m.a("Na", -1.1, 0, 1); const o = m.a("O", 0.45, 0, -1); m.t(o, "Cl", 0); },
    "Made of Na⁺ ions and hypochlorite (ClO⁻) ions.");
  add("CH3OH", "Methanol", "molecule",
    "Methanol is the simplest alcohol. It is poisonous to drink.",
    "Windshield washer fluid and some fuels.",
    (m) => { const c = m.a("C", 0, 0); H3(m, c, 180, 270, 90); const o = m.t(c, "O", 0); m.t(o, "H", 40); });
  add("H2CO3", "Carbonic acid", "molecule",
    "When carbon dioxide dissolves in water, a little of it turns into carbonic acid. It gives fizzy water its slightly sour bite.",
    "Fizzy drinks, rainwater and your blood.",
    (m) => { const c = m.a("C", 0, 0); m.t(c, "O", 270, 2); const a = m.t(c, "O", 150); m.t(a, "H", 90); const b = m.t(c, "O", 30); m.t(b, "H", 90); });
  add("HCOOH", "Formic acid", "molecule",
    "Formic acid is part of what makes some ant stings hurt. Its name comes from 'formica', the Latin word for ant.",
    "Ants and stinging nettles.",
    (m) => { const c = m.a("C", 0, 0); m.t(c, "H", 180); m.t(c, "O", 300, 2); const o = m.t(c, "O", 60); m.t(o, "H", 0); });
  add("C2H2", "Ethyne (acetylene)", "molecule",
    "Ethyne burns with oxygen in a flame hotter than 3000 degrees C, hot enough to cut and weld steel.",
    "Welding torches.",
    (m) => { const h = m.a("H", 0, 0); const c1 = m.t(h, "C", 0); const c2 = m.t(c1, "C", 0, 3); m.t(c2, "H", 0); },
    "The two carbons share a triple bond, so the molecule is a straight line.");
  add("C2H4", "Ethene (ethylene)", "molecule",
    "Fruits give off ethene gas as they ripen. Put a ripe banana in a bag with other fruit and they ripen faster!",
    "Ripening fruit. Factories use it to make polyethylene plastic bags.",
    (m) => { const c1 = m.a("C", 0, 0); const c2 = m.t(c1, "C", 0, 2); m.t(c1, "H", 150); m.t(c1, "H", 210); m.t(c2, "H", 30); m.t(c2, "H", 330); },
    "The two carbons share a double bond.");
  add("NaHCO3", "Sodium bicarbonate (baking soda)", "ionic",
    "Baking soda reacts with acids like vinegar to make carbon dioxide bubbles. Those bubbles help cakes rise.",
    "Kitchen cupboards, some toothpastes, and science fair volcanoes.",
    (m) => { m.a("Na", -1.9, 0.3, 1); const c = m.a("C", 0.3, 0); m.t(c, "O", 270, 2); m.t(c, "O", 150, 1, -1); const o = m.t(c, "O", 30); m.t(o, "H", 0); },
    "Made of Na⁺ ions and bicarbonate (HCO₃⁻) ions.");
  add("Na2CO3", "Sodium carbonate (washing soda)", "ionic",
    "Washing soda softens hard water so soap works better. It's also used to make glass.",
    "Laundry boosters and glass factories.",
    (m) => { carbonate(m, 0, 0); m.a("Na", -1.9, 1.2, 1); m.a("Na", 1.9, 1.2, 1); },
    "Two Na⁺ ions balance one carbonate (CO₃²⁻) ion.");
  add("C2H6", "Ethane", "molecule",
    "Ethane is one of the gases in natural gas. Factories turn it into ethene to make plastic.",
    "Natural gas.",
    (m) => chain(m, 2));
  add("C2H5OH", "Ethanol", "molecule",
    "Yeast makes ethanol and carbon dioxide when it feeds on sugar. The carbon dioxide bubbles make bread dough rise.",
    "Hand sanitizer, and fuel mixed into gasoline.",
    (m) => { const c1 = m.a("C", 0, 0); H3(m, c1, 180, 270, 90); const c2 = m.t(c1, "C", 0); m.t(c2, "H", 270); m.t(c2, "H", 90); const o = m.t(c2, "O", 0); m.t(o, "H", 40); });
  add("CO(NH2)2", "Urea", "molecule",
    "Your body gets rid of extra nitrogen as urea. In 1828 a chemist made urea in a lab, showing that chemicals from living things can be made from non-living ones.",
    "Urine, and fertilizer for farms.",
    (m) => { const c = m.a("C", 0, 0); m.t(c, "O", 270, 2); const a = m.t(c, "N", 150); m.t(a, "H", 210); m.t(a, "H", 90); const b = m.t(c, "N", 30); m.t(b, "H", 330); m.t(b, "H", 90); });
  add("CH3COOH", "Acetic acid", "molecule",
    "Vinegar is mostly water with about 5% acetic acid. That's what gives vinegar its sour taste and sharp smell.",
    "Vinegar, pickles and salad dressing.",
    (m) => { const c1 = m.a("C", 0, 0); H3(m, c1, 180, 270, 90); const c2 = m.t(c1, "C", 0); m.t(c2, "O", 300, 2); const o = m.t(c2, "O", 60); m.t(o, "H", 0); });
  add("CH3COCH3", "Acetone", "molecule",
    "Acetone dissolves nail polish and many glues. Your body makes tiny amounts of it too.",
    "Nail polish remover.",
    (m) => { const c = m.a("C", 0, 0); m.t(c, "O", 270, 2); const a = m.t(c, "C", 150); H3(m, a, 90, 150, 210); const b = m.t(c, "C", 30); H3(m, b, 90, 30, 330); });
  add("NH2CH2COOH", "Glycine", "molecule",
    "Glycine is the smallest amino acid. Your body links amino acids into long chains to build proteins.",
    "The proteins in your body and your food. It has even been found in dust from a comet!",
    (m) => { const n = m.a("N", 0, 0); m.t(n, "H", 210); m.t(n, "H", 150); const c1 = m.t(n, "C", 0); m.t(c1, "H", 270); m.t(c1, "H", 90); const c2 = m.t(c1, "C", 0); m.t(c2, "O", 300, 2); const o = m.t(c2, "O", 60); m.t(o, "H", 0); });
  add("C3H8", "Propane", "molecule",
    "Propane turns into a liquid when it's squeezed into a tank, so lots of fuel fits inside.",
    "Barbecue grills and camping stoves.",
    (m) => chain(m, 3));
  add("C4H10", "Butane", "molecule",
    "Butane is the fuel in many lighters. In a see-through lighter you can see it sloshing around as a liquid.",
    "Lighters and camping gas canisters.",
    (m) => chain(m, 4));
  add("C6H12O6", "Glucose", "molecule",
    "Plants make glucose from sunlight, water and carbon dioxide. Your cells break it down to release the energy you need to live.",
    "Fruit, honey, and your blood.",
    (m) => {
      const cs = [];
      for (let i = 0; i < 6; i++) { const c = m.a("C", i, 0); if (i) m.b(cs[i - 1], c); cs.push(c); }
      m.t(cs[0], "O", 270, 2); m.t(cs[0], "H", 180);
      for (let i = 1; i <= 4; i++) {
        const up = i % 2 === 0;
        const o = m.t(cs[i], "O", up ? 270 : 90); m.t(o, "H", up ? 270 : 90); m.t(cs[i], "H", up ? 90 : 270);
      }
      m.t(cs[5], "H", 270); m.t(cs[5], "H", 90); const o = m.t(cs[5], "O", 0); m.t(o, "H", 0);
    },
    "Drawn here as a chain. In water, most glucose curls up into a ring shape.");

  // --- He (2 discoveries)
  add("He", "Helium", "element",
    "Helium is a noble gas: its outer electron shell is full, so its atoms stay single and don't bond. It's lighter than air, so helium balloons float.",
    "Party balloons, airships, and the super-cold magnets inside MRI scanners.",
    (m) => { m.a("He", 0, 0); },
    "Just one atom! Noble gases are made of single atoms.");

  // --- S (4 discoveries)
  add("H2S", "Hydrogen sulfide", "molecule",
    "Hydrogen sulfide smells like rotten eggs. Your nose can smell even tiny amounts of it.",
    "Rotten eggs, volcanoes and swamps.",
    (m) => { const s = m.a("S", 0, 0); m.t(s, "H", 136); m.t(s, "H", 44); });
  add("SO2", "Sulfur dioxide", "molecule",
    "Volcanoes give off sulfur dioxide. Tiny amounts are used to stop dried fruit from turning brown.",
    "Volcanoes, and dried apricots.",
    (m) => { const s = m.a("S", 0, 0); m.t(s, "O", 210, 2); m.t(s, "O", 330, 2); },
    "Sulfur can make more than 2 bonds. Here it makes 4.");
  add("H2SO4", "Sulfuric acid", "molecule",
    "Sulfuric acid is one of the most-made chemicals in the world. It is very corrosive, so only experts handle it.",
    "Car batteries, and factories that make fertilizer.",
    (m) => { const s = m.a("S", 0, 0); m.t(s, "O", 270, 2); m.t(s, "O", 90, 2); const a = m.t(s, "O", 180); m.t(a, "H", 220); const b = m.t(s, "O", 0); m.t(b, "H", 320); },
    "Sulfur can make more than 2 bonds. In this common drawing it makes 6.");

  // --- Ca (6 discoveries)
  add("CaO", "Calcium oxide (quicklime)", "ionic",
    "Quicklime gets very hot when you add water to it. It's made by heating limestone in a hot oven called a kiln.",
    "Making cement and mortar.",
    (m) => { m.a("Ca", -0.85, 0, 2); m.a("O", 0.85, 0, -2); },
    "Calcium gives two electrons to oxygen: Ca²⁺ and O²⁻.");
  add("CaCl2", "Calcium chloride", "ionic",
    "Calcium chloride melts ice, and it even gives off heat as it dissolves.",
    "Road salt for icy winter roads.",
    (m) => { m.a("Cl", -1.7, 0, -1); m.a("Ca", 0, 0, 2); m.a("Cl", 1.7, 0, -1); },
    "One Ca²⁺ ion balances two Cl⁻ ions.");
  add("CaCO3", "Calcium carbonate", "ionic",
    "Chalk, limestone, marble, eggshells and seashells are all mostly calcium carbonate.",
    "Eggshells, seashells, chalk and antacid tablets.",
    (m) => { carbonate(m, 0, 0); m.a("Ca", 0, 1.75, 2); },
    "Made of Ca²⁺ ions and carbonate (CO₃²⁻) ions.");

  // --- Mg (9 discoveries)
  add("MgO", "Magnesium oxide", "ionic",
    "When magnesium burns, it gives a dazzling white light and leaves behind white magnesium oxide powder.",
    "Some antacid tablets, and heat-proof linings inside furnaces.",
    (m) => { m.a("Mg", -0.8, 0, 2); m.a("O", 0.8, 0, -2); });
  add("MgCl2", "Magnesium chloride", "ionic",
    "Seawater has lots of magnesium chloride in it. In Japan it is called nigari and is used to make tofu.",
    "Seawater, tofu making, and de-icing roads.",
    (m) => { m.a("Cl", -1.6, 0, -1); m.a("Mg", 0, 0, 2); m.a("Cl", 1.6, 0, -1); });
  add("MgCO3", "Magnesium carbonate", "ionic",
    "Gymnasts and rock climbers rub magnesium carbonate 'chalk' on their hands to keep them dry for a better grip.",
    "Gym chalk.",
    (m) => { carbonate(m, 0, 0); m.a("Mg", 0, 1.7, 2); });

  // --- K (12 discoveries)
  add("KCl", "Potassium chloride", "ionic",
    "Potassium chloride tastes salty, so it's used in 'low-sodium' salt substitutes.",
    "Salt substitutes and plant fertilizer.",
    (m) => { m.a("K", -0.85, 0, 1); m.a("Cl", 0.85, 0, -1); });
  add("KOH", "Potassium hydroxide", "ionic",
    "Potassium hydroxide is a strong base used to make soft and liquid soaps.",
    "Liquid soap, and inside alkaline batteries.",
    (m) => { m.a("K", -0.95, 0, 1); const o = m.a("O", 0.7, 0, -1); m.t(o, "H", 0); });

  // --- Fe (15 discoveries)
  add("Fe2O3", "Iron(III) oxide (rust)", "ionic",
    "Rust is mostly iron(III) oxide. Planet Mars looks red because its dust is full of iron oxide.",
    "Rusty bikes and nails, red rocks, and Mars.",
    (m) => { m.a("O", -2, 0.5, -2); m.a("Fe", -1, -0.4, 3); m.a("O", 0, 0.5, -2); m.a("Fe", 1, -0.4, 3); m.a("O", 2, 0.5, -2); },
    "Two Fe³⁺ ions (6+ in total) balance three O²⁻ ions (6− in total).");
  add("FeS2", "Pyrite (fool's gold)", "ionic",
    "Pyrite is shiny and golden, so it's nicknamed 'fool's gold'. Strike it against steel and it can make sparks.",
    "Rocks and mineral collections.",
    (m) => { m.a("Fe", -1.2, 0, 2); const s = m.a("S", 0.4, 0, -1); m.t(s, "S", 0, 1, -1); },
    "Iron disulfide: an Fe²⁺ ion with a pair of bonded sulfur atoms (S₂²⁻).");
  add("Fe3O4", "Magnetite", "ionic",
    "Magnetite is the most magnetic natural mineral. Lumps of it, called lodestones, were used to make the first compasses.",
    "Black beach sand and iron ore.",
    (m) => {
      m.a("Fe", -1.5, -0.6, 3); m.a("Fe", 0, -0.6, 2); m.a("Fe", 1.5, -0.6, 3);
      for (const x of [-2.25, -0.75, 0.75, 2.25]) m.a("O", x, 0.7, -2);
    },
    "Iron(II,III) oxide: one Fe²⁺ and two Fe³⁺ ions (8+ in total) balance four O²⁻ ions (8− in total).");

  // --- P (18 discoveries)
  add("H3PO4", "Phosphoric acid", "molecule",
    "Phosphoric acid gives some cola drinks their tangy taste. It can also remove rust.",
    "Cola drinks, rust removers, and fertilizer factories.",
    (m) => { const p = m.a("P", 0, 0); m.t(p, "O", 270, 2); const a = m.t(p, "O", 180); m.t(a, "H", 220); const b = m.t(p, "O", 0); m.t(b, "H", 320); const c = m.t(p, "O", 90); m.t(c, "H", 50); },
    "Phosphorus makes 5 bonds here.");
  add("Ca3(PO4)2", "Calcium phosphate", "ionic",
    "The hard part of your bones and teeth is made of a calcium phosphate mineral. It makes them strong.",
    "Bones and teeth, and rocks used to make fertilizer.",
    (m) => { phosphate(m, -2.2, 0); phosphate(m, 2.2, 0); m.a("Ca", 0, -1.25, 2); m.a("Ca", 0, 0, 2); m.a("Ca", 0, 1.25, 2); },
    "Three Ca²⁺ ions (6+ in total) balance two phosphate (PO₄³⁻) ions (6− in total).");

  // --- F (21 discoveries)
  add("F2", "Fluorine gas", "element",
    "Fluorine is the most reactive element of all. It reacts with almost every other element.",
    "Too reactive to be found on its own in nature. Its compounds are in minerals and toothpaste.",
    (m) => { const f = m.a("F", 0, 0); m.t(f, "F", 0); });
  add("HF", "Hydrogen fluoride", "molecule",
    "Dissolved in water it is called hydrofluoric acid. It can eat into glass, so it's used to etch designs on glass.",
    "Glass-etching factories.",
    (m) => { const h = m.a("H", 0, 0); m.t(h, "F", 0); });
  add("NaF", "Sodium fluoride", "ionic",
    "A tiny amount of sodium fluoride in toothpaste helps make your tooth enamel stronger.",
    "Toothpaste.",
    (m) => { m.a("Na", -0.8, 0, 1); m.a("F", 0.8, 0, -1); });
  add("CaF2", "Calcium fluoride (fluorite)", "ionic",
    "Some fluorite crystals glow under ultraviolet light. The word 'fluorescence' comes from fluorite!",
    "Mineral collections and special camera lenses.",
    (m) => { m.a("F", -1.6, 0, -1); m.a("Ca", 0, 0, 2); m.a("F", 1.6, 0, -1); });

  // --- Si (24 discoveries)
  add("SiO2", "Silicon dioxide", "network",
    "Sand, quartz and glass are mostly silicon dioxide.",
    "Beach sand, windows and quartz crystals.",
    (m) => {
      const si = [[0, 0], [2, 0], [0, 2], [2, 2]].map(([x, y]) => m.a("Si", x, y));
      const mid = [[1, 0, 0, 1], [0, 1, 0, 2], [2, 1, 1, 3], [1, 2, 2, 3]];
      for (const [x, y, a, b] of mid) { const o = m.a("O", x, y); m.b(si[a], o); m.b(si[b], o); }
      const outer = [[0, 180], [0, 270], [1, 270], [1, 0], [2, 180], [2, 90], [3, 0], [3, 90]];
      for (const [s, d] of outer) { const o = m.t(si[s], "O", d); m.ghost(o, d); }
    },
    "This is just a tiny piece of the network. Every Si bonds to 4 O and every O bonds to 2 Si, so overall there are 2 O for every Si.");

  // --- Al (27 discoveries)
  add("Al2O3", "Aluminum oxide", "ionic",
    "Rubies and sapphires are crystals of aluminum oxide. Tiny bits of other metals give them their colors.",
    "Gemstones, sandpaper, and the thin protective skin on aluminum foil.",
    (m) => { m.a("O", -2, 0.5, -2); m.a("Al", -1, -0.4, 3); m.a("O", 0, 0.5, -2); m.a("Al", 1, -0.4, 3); m.a("O", 2, 0.5, -2); },
    "Two Al³⁺ ions (6+ in total) balance three O²⁻ ions (6− in total).");

  // sulfates need S and a metal, so they come after their metal
  add("CaSO4", "Calcium sulfate", "ionic",
    "Gypsum, a soft mineral used to make plaster, is calcium sulfate with water locked inside its crystals.",
    "Plaster casts, drywall, and some tofu.",
    (m) => { sulfate(m, 0, 0); m.a("Ca", 0, 1.75, 2); },
    "Made of Ca²⁺ ions and sulfate (SO₄²⁻) ions.");
  add("MgSO4", "Magnesium sulfate", "ionic",
    "Epsom salt is magnesium sulfate with water locked inside its crystals. People add it to bath water.",
    "Bath salts and garden fertilizer.",
    (m) => { sulfate(m, 0, 0); m.a("Mg", 0, 1.7, 2); },
    "Made of Mg²⁺ ions and sulfate (SO₄²⁻) ions.");

  // --- Cu (30 discoveries)
  add("CuO", "Copper(II) oxide", "ionic",
    "Copper(II) oxide is a black powder. Potters use it to give glazes blue and green colors.",
    "Pottery glazes.",
    (m) => { m.a("Cu", -0.8, 0, 2); m.a("O", 0.8, 0, -2); });
  add("CuSO4", "Copper(II) sulfate", "ionic",
    "Dry copper sulfate is a white powder, but add water and it turns bright blue!",
    "School science labs, and pond treatments that stop algae.",
    (m) => { sulfate(m, 0, 0); m.a("Cu", 0, 1.7, 2); },
    "Made of Cu²⁺ ions and sulfate (SO₄²⁻) ions.");

  // ---------------------------------------------------------------- derived fields

  const RARITY = [
    { name: "Common", color: "#9ca3af", min: 1 },
    { name: "Uncommon", color: "#22c55e", min: 4 },
    { name: "Rare", color: "#3b82f6", min: 6 },
    { name: "Epic", color: "#a855f7", min: 9 },
    { name: "Legendary", color: "#f59e0b", min: 13 },
  ];
  for (const r of R) {
    r.counts = parseFormula(r.formula);
    r.total = Object.values(r.counts).reduce((a, b) => a + b, 0);
    r.rarity = RARITY.filter((t) => r.total >= t.min).length - 1;
    r.unlock = Math.max(...Object.keys(r.counts).map((s) => ELEMENTS[s].unlock));
    r.key = countKey(r.counts);
  }
  function countKey(counts) {
    return Object.keys(counts).filter((s) => counts[s] > 0).sort().map((s) => s + counts[s]).join(" ");
  }
  // Book order: in the order elements unlock, then by size.
  R.sort((a, b) => a.unlock - b.unlock || a.total - b.total);

  window.EC_DATA = { ELEMENTS, ELEMENT_ORDER, TABLE, TABLE_NUMBERS, RECIPES: R, RARITY, KIND_TEXT, parseFormula, countKey };
})();
