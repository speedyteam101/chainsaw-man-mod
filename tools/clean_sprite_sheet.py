"""Cleans up the Chainsaw Devil sprite sheet and builds the in-game texture.

Usage (from the repository root):
    pip install pillow numpy scipy
    python3 tools/clean_sprite_sheet.py

Input:  art/chainsaw_devil_source.png  (the original sheet: peach background, labelled rows)
Output: Content/Players/ChainsawDevilSheet.png      (used by the mod)
        art/ChainsawDevilSheet_preview_4x.png       (big labelled preview for humans)

What "cleaning" does:
  * cuts every frame out and removes the peach background,
  * strips the JPEG-looking fringe and specks,
  * boosts colour/contrast a little and snaps colours to one shared 48-colour palette,
  * adds a 1px dark outline so the sprite reads clearly against Terraria backgrounds,
  * lines every frame up on the character's feet in a uniform grid, so animations don't jitter.

If you change the row order or frame counts, update Content/Players/ChainsawDevilAnimation.cs to match
(the script prints the cell size and frame counts).
"""
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance
from scipy import ndimage

SOURCE = "art/chainsaw_devil_source.png"
SHEET_OUT = "Content/Players/ChainsawDevilSheet.png"
PREVIEW_OUT = "art/ChainsawDevilSheet_preview_4x.png"

BG = np.array([254, 202, 145])
OUTLINE = (22, 14, 20)
ROWS = ["idle", "walk", "run", "jump", "crouch", "attack1", "attack2", "attack3",
        "attack4", "attack5", "airattack1", "airattack2", "airattack3", "damage"]
EXPECTED = [6, 8, 8, 7, 5, 8, 7, 13, 6, 8, 5, 5, 6, 9]


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


def find_frames(orig):
    mask = np.abs(orig - BG).sum(2) > 60
    mask[450:472, 95:170] = False  # the JUMP label touches its row
    bands = [b for b in runs(np.where(mask.any(1))[0], 3) if b[1] - b[0] > 10]  # skip label rows
    frames = {}
    for (y0, y1), name, expected in zip(bands, ROWS, EXPECTED):
        cols = runs(np.where(mask[y0:y1 + 1].any(0))[0], 4)
        assert len(cols) == expected, f"{name}: found {len(cols)} frames, expected {expected}"
        frames[name] = [(x0, y0, x1, y1) for x0, x1 in cols]
    return frames


def cut(orig, boosted, box, thr=70):
    x0, y0, x1, y1 = box
    dist = np.abs(orig[y0:y1 + 1, x0:x1 + 1] - BG).sum(2)
    rgb = boosted[y0:y1 + 1, x0:x1 + 1]
    m = dist > thr
    edge = m & ~ndimage.binary_erosion(m)
    m &= ~(edge & (dist < 170))  # peach-tinted fringe
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


def main():
    src = Image.open(SOURCE).convert("RGB")
    orig = np.asarray(src).astype(int)
    boosted = np.asarray(ImageEnhance.Contrast(ImageEnhance.Color(src).enhance(1.35)).enhance(1.15)).astype(int)

    frames = {n: [cut(orig, boosted, b) for b in boxes] for n, boxes in find_frames(orig).items()}
    for f in frames["jump"]:
        keep_largest(f)  # leftover label underline

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

    half = max(max(foot_x(f), f.shape[1] - foot_x(f)) for fs in frames.values() for f in fs)
    cw, ch = 2 * half + 2, max(f.shape[0] for fs in frames.values() for f in fs) + 1
    cols = max(len(fs) for fs in frames.values())
    sheet = Image.new("RGBA", (cols * cw, len(frames) * ch), (0, 0, 0, 0))
    for r, fs in enumerate(frames.values()):
        for c, f in enumerate(fs):
            im = Image.fromarray(f)
            sheet.paste(im, (c * cw + cw // 2 - foot_x(f), r * ch + ch - f.shape[0]), im)
    sheet.save(SHEET_OUT)
    print("cell", cw, "x", ch, "| sheet", sheet.size, "| frames", [len(fs) for fs in frames.values()])

    s = 4
    preview = Image.new("RGBA", (sheet.width * s + 140, sheet.height * s), (48, 52, 64, 255))
    big = sheet.resize((sheet.width * s, sheet.height * s), Image.NEAREST)
    preview.paste(big, (140, 0), big)
    draw = ImageDraw.Draw(preview)
    for r, name in enumerate(frames):
        draw.text((8, r * ch * s + ch * s // 2 - 6), name.upper(), fill=(240, 240, 240, 255))
        draw.line([(0, (r + 1) * ch * s - 1), (preview.width, (r + 1) * ch * s - 1)], fill=(70, 75, 90, 255))
    preview.save(PREVIEW_OUT)


if __name__ == "__main__":
    main()
