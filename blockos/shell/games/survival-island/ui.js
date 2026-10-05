// Survival Island: HTML interface (hotbar, food bar, crafting menu, chest, title screen).
import { ITEMS, RECIPES, UNLOCK_HINT, icon } from "./items.js";

const $ = (tag, cls, parent, text) => {
  const el = document.createElement(tag);
  if (cls) el.className = cls;
  if (text !== undefined) el.textContent = text;
  if (parent) parent.appendChild(el);
  return el;
};

export class UI {
  constructor(game) {
    this.game = game;
    this.hotbar = $("div", "si-hotbar", document.body);
    this.slots = [];
    for (let n = 0; n < 9; n++) {
      const s = $("div", "si-slot", this.hotbar);
      $("span", "si-num", s, String(n + 1));
      s.addEventListener("pointerdown", (e) => { e.stopPropagation(); game.select(n); });
      this.slots.push(s);
    }
    this.bars = $("div", "si-bars", document.body);
    this.hpLabel = $("div", "si-hp-label", document.body);
    this.food = $("div", "si-food", document.body);
    this.foodFill = $("i", "", this.food);
    this.foodLabel = $("b", "", this.food);
    this.target = $("div", "si-target", document.body);
    this.held = $("div", "si-held", document.body);
    this.tips = $("div", "si-tips", document.body);
    this.tips.innerHTML = "<b>F</b> / click gather &amp; use &nbsp; <b>C</b> craft &nbsp; <b>E</b> eat &nbsp; <b>R</b> rotate &nbsp; <b>X</b> remove build &nbsp; <b>1-9</b> items";
    this.feed = $("div", "si-feed", document.body);
    this.banner = $("div", "si-banner", document.body);
    this.cross = $("div", "si-cross", document.body);
    this.vignette = $("div", "si-hurt", document.body);
    this.panel = null;
    this.pickedSlot = -1;
  }

  // ---------------------------------------------------------------- hud bits

  renderHotbar() {
    const g = this.game;
    this.slots.forEach((s, n) => {
      const it = g.inv[n];
      s.classList.toggle("sel", n === g.sel);
      let img = s.querySelector("img"), cnt = s.querySelector(".si-cnt");
      if (!it) { if (img) img.remove(); if (cnt) cnt.remove(); s.title = ""; return; }
      if (!img) img = $("img", "", s);
      if (img.dataset.id !== it.id) { img.src = icon(it.id); img.dataset.id = it.id; img.alt = ""; }
      if (!cnt) cnt = $("span", "si-cnt", s);
      cnt.textContent = it.n > 1 ? it.n : "";
      s.title = ITEMS[it.id].name;
    });
    const cur = g.inv[g.sel];
    this.held.textContent = cur ? ITEMS[cur.id].name + (ITEMS[cur.id].kind === "place" ? "  (R to rotate)" : ITEMS[cur.id].kind === "food" ? "  (E to eat)" : "") : "";
    if (this.panel && this.panel.kind === "craft") this.renderCraft();
    if (this.panel && this.panel.kind === "chest") this.renderChest();
  }

  setFood(v) {
    this.foodFill.style.width = Math.max(0, v) + "%";
    this.foodFill.style.background = v > 40 ? "#f59e0b" : v > 15 ? "#f97316" : "#ef4444";
    this.foodLabel.textContent = "Food " + Math.ceil(v);
  }
  setHealth(v) { this.hpLabel.textContent = "Health " + Math.ceil(v); }

  setTarget(text, warn) {
    this.target.textContent = text || "";
    this.target.classList.toggle("warn", !!warn);
    this.target.hidden = !text;
  }

  pickup(text, color) {
    const line = $("div", "", this.feed, text);
    if (color) line.style.borderLeftColor = color;
    while (this.feed.children.length > 5) this.feed.firstChild.remove();
    setTimeout(() => line.classList.add("out"), 2200);
    setTimeout(() => line.remove(), 2800);
  }

  announce(text, sub) {
    this.banner.innerHTML = "";
    $("b", "", this.banner, text);
    if (sub) $("span", "", this.banner, sub);
    this.banner.classList.remove("show");
    void this.banner.offsetWidth;
    this.banner.classList.add("show");
  }

  hurt() {
    this.vignette.classList.remove("on");
    void this.vignette.offsetWidth;
    this.vignette.classList.add("on");
  }

  showCross(on) { this.cross.hidden = !on; }

  // ---------------------------------------------------------------- panels

  close() {
    if (this.panel) this.panel.el.remove();
    this.panel = null;
    this.pickedSlot = -1;
  }
  isOpen(kind) { return this.panel && (!kind || this.panel.kind === kind); }

  openPanel(kind, title) {
    this.close();
    const wrap = $("div", "si-panel", document.body);
    wrap.addEventListener("pointerdown", (e) => e.stopPropagation());
    const head = $("div", "si-panel-head", wrap);
    $("h2", "", head, title);
    const x = $("button", "si-x", head, "Close");
    x.onclick = () => this.close();
    const body = $("div", "si-panel-body", wrap);
    this.panel = { kind, el: wrap, body };
    return body;
  }

  invGrid(parent, onClick) {
    const g = this.game;
    const grid = $("div", "si-inv", parent);
    g.inv.forEach((it, n) => {
      const s = $("div", "si-slot small" + (n < 9 ? " hot" : "") + (n === this.pickedSlot ? " picked" : ""), grid);
      if (n < 9) $("span", "si-num", s, String(n + 1));
      if (it) {
        const img = $("img", "", s); img.src = icon(it.id); img.alt = "";
        if (it.n > 1) $("span", "si-cnt", s, String(it.n));
        s.title = ITEMS[it.id].name;
      }
      s.onclick = () => onClick(n);
    });
    return grid;
  }

  toggleCraft() {
    if (this.isOpen("craft")) this.close();
    else { this.openPanel("craft", "Crafting"); this.renderCraft(); }
  }

  renderCraft() {
    const g = this.game;
    const body = this.panel.body;
    const scroll = body.querySelector(".si-recipes");
    const keep = scroll ? scroll.scrollTop : 0;
    body.innerHTML = "";
    const cols = $("div", "si-cols", body);
    const left = $("div", "si-recipes", cols);
    const stations = g.stationsNear();
    const st = $("div", "si-stations", left);
    st.innerHTML = `Near: <b class="${stations.workbench ? "on" : ""}">Workbench</b> <b class="${stations.campfire ? "on" : ""}">Campfire</b>`;
    for (const cat of ["Tools", "Survival", "Building"]) {
      $("h3", "", left, cat);
      const list = $("div", "si-rlist", left);
      for (const r of RECIPES.filter((x) => x.cat === cat)) {
        const state = g.recipeState(r);
        const card = $("div", "si-recipe" + (state.locked ? " locked" : state.ok ? " ok" : ""), list);
        const img = $("img", "", card); img.src = icon(r.out); img.alt = "";
        const info = $("div", "si-rinfo", card);
        $("b", "", info, ITEMS[r.out].name + (r.n > 1 ? " x" + r.n : ""));
        const cost = $("div", "si-cost", info);
        if (state.locked) cost.textContent = UNLOCK_HINT[r.unlock] || "Locked";
        else {
          for (const [id, n] of Object.entries(r.cost)) {
            const have = g.count(id);
            const c = $("span", have >= n ? "have" : "need", cost, `${ITEMS[id].name} ${Math.min(have, n)}/${n}`);
            c.title = ITEMS[id].name;
          }
          if (r.near) $("span", stations[r.near] ? "have" : "need", cost, "at " + (r.near === "workbench" ? "Workbench" : "Campfire"));
        }
        const btn = $("button", "si-craft", card, "Craft");
        btn.disabled = !state.ok;
        btn.onclick = () => { g.craft(r); };
      }
    }
    left.scrollTop = keep;
    const right = $("div", "si-side", cols);
    $("h3", "", right, "Backpack");
    $("p", "si-hint", right, "Click two slots to swap them. Slots 1-9 are your hotbar.");
    this.invGrid(right, (n) => {
      if (this.pickedSlot < 0) { if (g.inv[n]) this.pickedSlot = n; }
      else { g.swap(this.pickedSlot, n); this.pickedSlot = -1; }
      this.renderCraft();
    });
    const info = $("div", "si-world", right);
    info.innerHTML = g.worldInfo();
    if (g.canResetWorld()) {
      const nb = $("button", "si-new", right, "Start a new island");
      nb.onclick = () => {
        if (nb.dataset.sure) { this.close(); g.newWorld(); }
        else { nb.dataset.sure = "1"; nb.textContent = "Click again: your island and items are lost"; }
      };
    }
  }

  openChest(chest) {
    this.openPanel("chest", "Chest");
    this.panel.chest = chest;
    this.renderChest();
  }

  renderChest() {
    const g = this.game;
    const chest = this.panel.chest;
    if (!g.chestExists(chest)) { this.close(); return; }
    const body = this.panel.body;
    body.innerHTML = "";
    const cols = $("div", "si-cols", body);
    const left = $("div", "si-side", cols);
    $("h3", "", left, "In the chest");
    $("p", "si-hint", left, "Click an item to take it.");
    const grid = $("div", "si-inv", left);
    const entries = Object.entries(chest.items || {}).filter(([, n]) => n > 0);
    if (!entries.length) $("p", "si-hint", grid, "Empty");
    for (const [id, n] of entries) {
      const s = $("div", "si-slot small", grid);
      const img = $("img", "", s); img.src = icon(id); img.alt = "";
      if (n > 1) $("span", "si-cnt", s, String(n));
      s.title = ITEMS[id] ? ITEMS[id].name : id;
      s.onclick = () => { g.chestTake(chest, id); };
    }
    const right = $("div", "si-side", cols);
    $("h3", "", right, "Your backpack");
    $("p", "si-hint", right, "Click an item to store it.");
    this.invGrid(right, (n) => { g.chestPut(chest, n); });
  }

  // ---------------------------------------------------------------- title

  title(opts) {
    return new Promise((resolve) => {
      const o = $("div", "kit-overlay si-title", document.body);
      const panel = $("div", "kit-panel", o);
      $("h1", "", panel, "Survival Island");
      $("p", "", panel, "Gather wood and stone, craft tools, build a shelter and survive the nights on a blocky island. Monsters come out after dark, so light a campfire and stay close to your friends.");
      const info = $("p", "si-tinfo", panel);
      info.textContent = opts.info;
      const ctl = $("div", "si-controls", panel);
      ctl.innerHTML = "<span><b>WASD</b> move</span><span><b>Space</b> jump / swim</span><span><b>F</b> or click gather, attack, use</span><span><b>C</b> crafting</span><span><b>1-9</b> pick item</span><span><b>E</b> eat</span><span><b>R</b> rotate build</span><span><b>X</b> remove your build</span><span><b>Drag</b> turn camera</span><span><b>Shift</b> shift lock</span>";
      const row = $("div", "si-btns", panel);
      const play = $("button", "kit-btn", row, opts.continue ? "Continue" : "Play");
      let fresh = null;
      if (opts.canNew) {
        fresh = $("button", "kit-btn si-alt", row, "New Island");
      }
      const shownAt = performance.now();
      const done = (isNew) => {
        removeEventListener("keydown", onKey, true);
        o.remove();
        if (window.Kit) Kit.sfx("click");
        resolve(isNew);
      };
      const onKey = (e) => {
        if ((e.code === "Enter" || e.code === "Space") && performance.now() - shownAt > 300) { e.preventDefault(); e.stopPropagation(); done(false); }
      };
      play.onclick = () => done(false);
      if (fresh) fresh.onclick = () => {
        if (fresh.dataset.sure) done(true);
        else { fresh.dataset.sure = "1"; fresh.textContent = "Sure? Click again"; }
      };
      addEventListener("keydown", onKey, true);
      play.focus();
      this.titleInfo = info;
    });
  }
}
