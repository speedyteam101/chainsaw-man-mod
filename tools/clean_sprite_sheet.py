"""Cleans up the Chainsaw Devil sprite sheets and builds the in-game textures.

Usage (from the repository root):
    pip install pillow numpy scipy
    python3 tools/clean_sprite_sheet.py

Sheets:
  chainsaw   art/chainsaw_devil_source.png -> Content/Players/ChainsawDevilSheet.png  (tier 1-2 form)
  hero       art/hero_of_hell_source.png   -> Content/Players/HeroOfHellSheet.png    (tier 3 form)
Each also writes a big labelled preview to art/<name>_preview_4x.png.

What "cleaning" does:
  * cuts every frame out and removes the flat background colour,
  * strips the JPEG-looking fringe and specks,
  * boosts colour/contrast a little and snaps colours to one shared 48-colour palette per sheet,
  * adds a 1px dark outline so the sprite reads clearly against Terraria backgrounds,
  * lines every frame up on the character's feet in a uniform grid, so animations don't jitter.

Rows are written in DevilAnim order (see Content/Players/ChainsawDevilAnimation.cs); a row a sheet
doesn't have is left empty. If you change anything here, update the cell size and frame counts in
ChainsawDevilAnimation.cs (the script prints them).
"""
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance
from scipy import ndimage

OUTLINE = (22, 14, 20)

# Must match the DevilAnim enum order in ChainsawDevilAnimation.cs.
ANIM_ORDER = ["idle", "walk", "run", "jump", "crouch", "attack1", "attack2", "attack3",
              "attack4", "attack5", "airattack1", "airattack2", "airattack3", "damage", "attack6"]


def runs(indices, gap):
    """Groups sorted indices into (start, end) runs separated by more than `gap`."""
    out, s, p = [], indices[0], indices[0]
    for i in indices[1:]:
        if i - p > gap:
            out.append((s, p))
            s = i
        p = i
    out.append((s, p))
    return out


# ---------------------------------------------------------------- frame finding, per sheet

def chainsaw_frames(mask):
    """Sheet 1: rows are found automatically (label rows are the short ones)."""
    rows = ["idle", "walk", "run", "jump", "crouch", "attack1", "attack2", "attack3",
            "attack4", "attack5", "airattack1", "airattack2", "airattack3", "damage"]
    expected = [6, 8, 8, 7, 5, 8, 7, 13, 6, 8, 5, 5, 6, 9]
    mask[450:472, 95:170] = False  # the JUMP label touches its row
    bands = [b for b in runs(np.where(mask.any(1))[0], 3) if b[1] - b[0] > 10]
    frames = {}
    for (y0, y1), name, count in zip(bands, rows, expected):
        cols = runs(np.where(mask[y0:y1 + 1].any(0))[0], 4)
        assert len(cols) == count, f"{name}: found {len(cols)} frames, expected {count}"
        frames[name] = [(x0, y0, x1, y1) for x0, x1 in cols]
    return frames


def hero_frames(mask):
    """Sheet 2 (Hero of Hell): row positions are listed explicitly; the top rows are loose parts, not animations."""
    rows = {  # name: (top, bottom, expected frames)
        "idle": (229, 257, 6), "walk": (310, 338, 7), "run": (373, 398, 7), "crouch": (447, 473, 6),
        "jump": (516, 579, 7), "airattack1": (672, 698, 7), "airattack2": (747, 773, 5),
        "airattack3": (821, 849, 6), "attack1": (969, 997, 7), "attack2": (1031, 1059, 6),
        "attack3": (1121, 1149, 17), "attack6": (1177, 1205, 17), "attack4": (1250, 1287, 6),
        "attack5": (1328, 1363, 8), "damage": (1415, 1451, 15),
    }
    frames = {}
    for name, (y0, y1, count) in rows.items():
        y0, y1 = y0 - 2, y1 + 2
        band = mask[y0:y1 + 1]
        cols = runs(np.where(band.any(0))[0], 4)
        # A detached bit of chain belongs to the frame before it.
        merged = []
        for x0, x1 in cols:
            if merged and x1 - x0 < 12:
                merged[-1] = (merged[-1][0], x1)
            else:
                merged.append((x0, x1))
        # Two jump frames touch; split an over-wide segment at its emptiest column.
        split = []
        for x0, x1 in merged:
            if name == "jump" and x1 - x0 > 60:
                inner = band[:, x0 + 15:x1 - 15].sum(0)
                cut = x0 + 15 + int(np.argmin(inner))
                split += [(x0, cut - 1), (cut + 1, x1)]
            else:
                split.append((x0, x1))
        assert len(split) == count, f"{name}: found {len(split)} frames, expected {count}"
        frames[name] = [(x0, y0, x1, y1) for x0, x1 in split]
    return frames


SHEETS = {
    "chainsaw": dict(source="art/chainsaw_devil_source.png", bg=(254, 202, 145), find=chainsaw_frames,
                     out="Content/Players/ChainsawDevilSheet.png", preview="art/ChainsawDevilSheet_preview_4x.png"),
    "hero": dict(source="art/hero_of_hell_source.png", bg=(52, 130, 31), find=hero_frames,
                 blank=[(76, 515, 94, 523), (76, 1249, 107, 1256)],  # JUMP and ATTACK 4 labels touching frames
                 out="Content/Players/HeroOfHellSheet.png", preview="art/HeroOfHellSheet_preview_4x.png"),
}


# ---------------------------------------------------------------- cleanup

def cut(orig, boosted, bg, box, thr=70):
    x0, y0, x1, y1 = box
    dist = np.abs(orig[y0:y1 + 1, x0:x1 + 1] - bg).sum(2)
    rgb = boosted[y0:y1 + 1, x0:x1 + 1]
    m = dist > thr
    edge = m & ~ndimage.binary_erosion(m)
    m &= ~(edge & (dist < 170))  # background-tinted fringe
    lab, n = ndimage.label(m)
    for i, size in enumerate(ndimage.sum(m, lab, range(1, n + 1))):
        if size < 4:
            m[lab == i + 1] = False
    m = np.pad(m, 1)
    rgb = np.pad(rgb, ((1, 1), (1, 1), (0, 0)))
    rgba = np.zeros(rgb.shape[:2] + (4,), np.uint8)
    rgba[..., :3] = rgb
    rgba[..., 3] = m * 255
    return rgba


def keep_largest(f):
    m = f[..., 3] > 0
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    keep = np.argmax(ndimage.sum(m, lab, range(1, n + 1))) + 1
    f[..., 3][lab != keep] = 0


def foot_x(f):
    m = f[..., 3] > 0
    bottom = np.where(m.any(1))[0].max()
    return int(round(np.where(m[bottom - 3:bottom + 1].any(0))[0].mean()))


def trim_vertical(f):
    """Crops empty rows so frames of a padded band still sit on their feet."""
    ys = np.where((f[..., 3] > 0).any(1))[0]
    return f[:ys.max() + 1]


def build(name, cfg):
    src = Image.open(cfg["source"]).convert("RGB")
    for rect in cfg.get("blank", []):
        ImageDraw.Draw(src).rectangle(rect, fill=cfg["bg"])
    orig = np.asarray(src).astype(int)
    boosted = np.asarray(ImageEnhance.Contrast(ImageEnhance.Color(src).enhance(1.35)).enhance(1.15)).astype(int)
    bg = np.array(cfg["bg"])

    mask = np.abs(orig - bg).sum(2) > 60
    boxes = cfg["find"](mask)
    frames = {n: [cut(orig, boosted, bg, b) for b in bs] for n, bs in boxes.items()}
    if name == "chainsaw":
        for f in frames["jump"]:
            keep_largest(f)  # leftover label underline
    else:
        frames = {n: [trim_vertical(f) for f in fs] for n, fs in frames.items()}

    opaque = np.concatenate([f[f[..., 3] > 0][:, :3] for fs in frames.values() for f in fs])
    side = int(np.ceil(np.sqrt(len(opaque))))
    palette = Image.fromarray(np.resize(opaque, (side * side, 3)).astype(np.uint8).reshape(side, side, 3)) \
        .quantize(colors=48, method=Image.MEDIANCUT)

    def finish(f):
        q = np.asarray(Image.fromarray(f[..., :3]).quantize(palette=palette, dither=Image.Dither.NONE).convert("RGB")).copy()
        m = f[..., 3] > 0
        ring = ndimage.binary_dilation(m, structure=[[0, 1, 0], [1, 1, 1], [0, 1, 0]]) & ~m
        q[ring] = OUTLINE
        return np.dstack([q, (m | ring) * 255]).astype(np.uint8)

    frames = {n: [finish(f) for f in fs] for n, fs in frames.items()}

    rows = [n for n in ANIM_ORDER if n in frames or name == "hero"]
    if name == "chainsaw":
        rows = ANIM_ORDER[:14]  # sheet 1 has no attack6 row
    half = max(max(foot_x(f), f.shape[1] - foot_x(f)) for fs in frames.values() for f in fs)
    cw, ch = 2 * half + 2, max(f.shape[0] for fs in frames.values() for f in fs) + 1
    cols = max(len(fs) for fs in frames.values())
    sheet = Image.new("RGBA", (cols * cw, len(rows) * ch), (0, 0, 0, 0))
    for r, row in enumerate(rows):
        for c, f in enumerate(frames.get(row, [])):
            im = Image.fromarray(f)
            sheet.paste(im, (c * cw + cw // 2 - foot_x(f), r * ch + ch - f.shape[0]), im)
    sheet.save(cfg["out"])
    print(f"{name}: cell {cw} x {ch} | sheet {sheet.size} | frames {[len(frames.get(r, [])) for r in rows]}")

    s = 4
    preview = Image.new("RGBA", (sheet.width * s + 140, sheet.height * s), (48, 52, 64, 255))
    big = sheet.resize((sheet.width * s, sheet.height * s), Image.NEAREST)
    preview.paste(big, (140, 0), big)
    draw = ImageDraw.Draw(preview)
    for r, row in enumerate(rows):
        draw.text((8, r * ch * s + ch * s // 2 - 6), row.upper(), fill=(240, 240, 240, 255))
        draw.line([(0, (r + 1) * ch * s - 1), (preview.width, (r + 1) * ch * s - 1)], fill=(70, 75, 90, 255))
    preview.save(cfg["preview"])


if __name__ == "__main__":
    for sheet_name, config in SHEETS.items():
        build(sheet_name, config)
