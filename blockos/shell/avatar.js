/* BlockOS avatar: a blocky character drawn as SVG, plus the items you can buy for it. */
(function () {
  "use strict";

  const COLORS = [
    "#f5cd30", "#ffc9a3", "#d9a066", "#a0693f", "#6b4426", "#f2f4f5",
    "#ef4444", "#fb923c", "#facc15", "#22c55e", "#14b8a6", "#3b82f6",
    "#1e3a8a", "#a855f7", "#ec4899", "#6b7280", "#1f2328", "#7c2d12",
  ];

  // price 0 = everyone owns it from the start.
  const ITEMS = {
    face: [
      { id: "smile", name: "Classic Smile", price: 0 },
      { id: "grin", name: "Big Grin", price: 0 },
      { id: "wink", name: "Wink", price: 20 },
      { id: "wow", name: "Wow", price: 20 },
      { id: "cool", name: "Cool Shades", price: 40 },
      { id: "determined", name: "Determined", price: 60 },
      { id: "robot", name: "Robot Visor", price: 120 },
    ],
    hat: [
      { id: "none", name: "No Hat", price: 0 },
      { id: "cap", name: "Blue Cap", price: 0 },
      { id: "cone", name: "Traffic Cone", price: 30 },
      { id: "tophat", name: "Top Hat", price: 50 },
      { id: "headphones", name: "Headphones", price: 80 },
      { id: "wizard", name: "Wizard Hat", price: 120 },
      { id: "crown", name: "Golden Crown", price: 250 },
    ],
    shirt: [
      { id: "plain", name: "Plain", price: 0 },
      { id: "stripes", name: "Stripes", price: 25 },
      { id: "star", name: "Star", price: 40 },
      { id: "brick", name: "Brick Logo", price: 60 },
      { id: "bolt", name: "Lightning", price: 90 },
      { id: "suit", name: "Fancy Suit", price: 150 },
    ],
  };

  const DEFAULT = {
    head: "#f5cd30", torso: "#3b82f6", arms: "#f5cd30", legs: "#22c55e",
    face: "smile", hat: "none", shirt: "plain",
  };

  function shade(hex, amt) {
    const n = parseInt(hex.slice(1), 16);
    const f = (c) => Math.max(0, Math.min(255, Math.round(c + amt * 255)));
    const r = f(n >> 16), g = f((n >> 8) & 255), b = f(n & 255);
    return "#" + ((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1);
  }

  // Shapes are in a 200 x 260 box. The head spans x 70..130, y 22..78.
  const FACES = {
    smile: `<rect x="85" y="40" width="7" height="10" rx="3" fill="#111"/><rect x="108" y="40" width="7" height="10" rx="3" fill="#111"/>
            <path d="M86 58 Q100 70 114 58" stroke="#111" stroke-width="3.5" fill="none"/>`,
    grin: `<rect x="85" y="38" width="8" height="11" rx="3" fill="#111"/><rect x="107" y="38" width="8" height="11" rx="3" fill="#111"/>
           <path d="M83 55 H117 Q114 70 100 70 Q86 70 83 55 Z" fill="#111"/><path d="M87 57 H113 V60 H87Z" fill="#fff"/>`,
    wink: `<rect x="85" y="40" width="7" height="10" rx="3" fill="#111"/><path d="M106 46 H117" stroke="#111" stroke-width="3.5"/>
           <path d="M88 59 Q101 69 114 57" stroke="#111" stroke-width="3.5" fill="none"/>`,
    wow: `<circle cx="88" cy="44" r="6" fill="#fff" stroke="#111" stroke-width="2.5"/><circle cx="112" cy="44" r="6" fill="#fff" stroke="#111" stroke-width="2.5"/>
          <circle cx="88" cy="45" r="2.6" fill="#111"/><circle cx="112" cy="45" r="2.6" fill="#111"/><ellipse cx="100" cy="64" rx="6" ry="7" fill="#111"/>`,
    cool: `<path d="M78 38 H122 V44 Q122 54 112 54 H106 Q102 54 100 46 Q98 54 94 54 H88 Q78 54 78 44Z" fill="#111"/>
           <path d="M82 41 H92" stroke="#6b7280" stroke-width="2.5"/><path d="M106 41 H116" stroke="#6b7280" stroke-width="2.5"/>
           <path d="M90 62 Q102 69 112 60" stroke="#111" stroke-width="3.5" fill="none"/>`,
    determined: `<path d="M82 36 L94 41" stroke="#111" stroke-width="3.5"/><path d="M118 36 L106 41" stroke="#111" stroke-width="3.5"/>
                 <rect x="86" y="43" width="7" height="8" rx="2" fill="#111"/><rect x="107" y="43" width="7" height="8" rx="2" fill="#111"/>
                 <path d="M89 63 H111" stroke="#111" stroke-width="4"/>`,
    robot: `<rect x="76" y="36" width="48" height="16" rx="5" fill="#0f172a"/><rect x="80" y="40" width="40" height="8" rx="3" fill="#22d3ee"/>
            <rect x="88" y="60" width="24" height="6" rx="2" fill="#0f172a"/><path d="M92 60 V66 M98 60 V66 M104 60 V66 M110 60 V66" stroke="#64748b" stroke-width="1.5"/>`,
  };

  const HATS = {
    none: "",
    cap: `<path d="M68 34 Q70 6 100 6 Q130 6 132 34Z" fill="#2563eb"/><path d="M60 34 H146 Q148 40 140 40 H68 Q60 40 60 34Z" fill="#1d4ed8"/>
          <rect x="96" y="4" width="8" height="5" rx="2" fill="#1e40af"/>`,
    cone: `<path d="M100 -28 L122 30 H78Z" fill="#fb923c"/><path d="M89 2 H111 L114 10 H86Z M82 20 H118 L121 28 H79Z" fill="#fff"/>
           <rect x="68" y="28" width="64" height="9" rx="3" fill="#ea580c"/>`,
    tophat: `<rect x="78" y="-22" width="44" height="50" rx="4" fill="#1f2328"/><rect x="78" y="14" width="44" height="8" fill="#ef4444"/>
             <rect x="64" y="26" width="72" height="9" rx="4" fill="#111"/>`,
    headphones: `<path d="M66 50 Q66 8 100 8 Q134 8 134 50" stroke="#1f2328" stroke-width="7" fill="none"/>
                 <rect x="58" y="38" width="16" height="28" rx="6" fill="#ef4444"/><rect x="126" y="38" width="16" height="28" rx="6" fill="#ef4444"/>`,
    wizard: `<path d="M100 -40 Q118 -6 132 30 H68 Q84 -6 100 -40Z" fill="#7c3aed"/><rect x="62" y="26" width="76" height="10" rx="5" fill="#5b21b6"/>
             <path d="M96 -4 l3 6 6 1 -5 4 1 6 -5 -3 -5 3 1 -6 -5 -4 6 -1Z" fill="#facc15"/>`,
    crown: `<path d="M70 32 L72 4 L86 18 L100 -2 L114 18 L128 4 L130 32Z" fill="#facc15" stroke="#ca8a04" stroke-width="2"/>
            <circle cx="100" cy="20" r="4.5" fill="#ef4444"/><circle cx="83" cy="25" r="3.5" fill="#3b82f6"/><circle cx="117" cy="25" r="3.5" fill="#22c55e"/>`,
  };

  function shirtArt(id, torso) {
    switch (id) {
      case "stripes":
        return [96, 112, 128, 144].map((y) => `<rect x="60" y="${y}" width="80" height="7" fill="${shade(torso, 0.18)}"/>`).join("");
      case "star":
        return `<path d="M100 98 l7.6 15.4 17 2.5 -12.3 12 2.9 16.9 -15.2 -8 -15.2 8 2.9 -16.9 -12.3 -12 17 -2.5Z" fill="#facc15" stroke="#ca8a04" stroke-width="2"/>`;
      case "brick":
        return `<rect x="80" y="104" width="18" height="18" rx="3" fill="#ef4444"/><rect x="102" y="104" width="18" height="18" rx="3" fill="#facc15"/>
                <rect x="80" y="126" width="18" height="18" rx="3" fill="#3b82f6"/><rect x="102" y="126" width="18" height="18" rx="3" fill="#22c55e"/>`;
      case "bolt":
        return `<path d="M106 92 L84 128 H100 L94 154 L118 114 H102Z" fill="#facc15" stroke="#ca8a04" stroke-width="2"/>`;
      case "suit":
        return `<path d="M60 84 H86 L100 120 L114 84 H140 V162 H60Z" fill="#1f2328"/><path d="M92 84 H108 L100 104Z" fill="#fff"/>
                <path d="M96 100 L100 96 L104 100 L100 130Z" fill="#ef4444"/>`;
      default:
        return "";
    }
  }

  function draw(look, opts) {
    const a = Object.assign({}, DEFAULT, look || {});
    const o = opts || {};
    const viewBox = o.headshot ? "52 -8 96 96" : "0 -44 200 304";
    const part = (x, y, w, h, c) =>
      `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="7" fill="${c}"/>` +
      `<rect x="${x + 4}" y="${y + h - 8}" width="${w - 8}" height="6" rx="3" fill="${shade(c, -0.14)}"/>`;
    return `<svg viewBox="${viewBox}" xmlns="http://www.w3.org/2000/svg" style="fill:initial;stroke:none">
      ${o.headshot ? "" : `<ellipse cx="100" cy="252" rx="78" ry="9" fill="rgba(0,0,0,.25)"/>`}
      ${part(60, 166, 38, 82, a.legs)}${part(102, 166, 38, 82, a.legs)}
      ${part(22, 84, 34, 80, a.arms)}${part(144, 84, 34, 80, a.arms)}
      ${part(60, 84, 80, 80, a.torso)}
      ${shirtArt(a.shirt, a.torso)}
      <rect x="88" y="74" width="24" height="14" fill="${shade(a.head, -0.1)}"/>
      <rect x="70" y="22" width="60" height="56" rx="16" fill="${a.head}"/>
      <rect x="76" y="26" width="48" height="6" rx="3" fill="${shade(a.head, 0.12)}"/>
      ${FACES[a.face] || ""}
      ${HATS[a.hat] || ""}
    </svg>`;
  }

  // Small preview of a single item for the shop grid.
  function preview(kind, id, look) {
    const a = Object.assign({}, DEFAULT, look || {}, { [kind]: id });
    if (kind === "shirt") {
      return `<svg class="preview" viewBox="10 70 180 100" style="fill:initial;stroke:none">
        <rect x="22" y="84" width="34" height="80" rx="7" fill="${a.arms}"/><rect x="144" y="84" width="34" height="80" rx="7" fill="${a.arms}"/>
        <rect x="60" y="84" width="80" height="80" rx="7" fill="${a.torso}"/>${shirtArt(id, a.torso)}</svg>`;
    }
    return draw(a, { headshot: true }).replace("<svg ", '<svg class="preview" ').replace('viewBox="52 -8 96 96"', 'viewBox="52 -42 96 124"');
  }

  window.Avatar = { COLORS, ITEMS, DEFAULT, draw, preview };
})();
