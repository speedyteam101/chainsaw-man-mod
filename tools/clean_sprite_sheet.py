"""Cleans up the Chainsaw Devil sprite sheets and builds the in-game textures.

Usage (from the repository root):
    pip install pillow numpy scipy
    python3 tools/clean_sprite_sheet.py

Sheets:
  chainsaw   art/chainsaw_devil_source.png -> Content/Players/ChainsawDevilSheet.png  (tier 1-2 form)
  hero       art/hero_of_hell_source.png   -> Content/Players/HeroOfHellSheet.png    (tier 3 form)
  katana     art/katana_man_source.png     -> Content/Players/HybridKatanaSheet.png  (Katana Man form)
  reze       art/reze_source.png           -> Content/Players/HybridBombSheet.png    (Reze / Bomb form)
  makima     art/makima_source.png         -> Content/NPCs/Makima.png, MakimaKicks.png (+ MakimaHound.png, MakimaGunFiend.png)
Each Chainsaw Devil sheet also writes a big labelled preview to art/<name>_preview_4x.png.

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


def drop_specks(f, fraction=0.12):
    """Removes pieces smaller than `fraction` of the biggest one (keeps detached heads, drops noise)."""
    m = f[..., 3] > 0
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    if n == 0:
        return
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    for i, size in enumerate(sizes):
        if size < sizes.max() * fraction:
            f[..., 3][lab == i + 1] = 0


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


# ---------------------------------------------------------------- Makima boss (vertical NPC strip)
# Frames picked from art/makima_source.png as (x, width, top, bottom). The source has no labels.
MAKIMA_BG = (254, 175, 201)
MAKIMA_ANIMS = [  # (name, frames) in strip order; must match the frame ranges in Content/NPCs/Makima.cs
    ("idle", [(18, 13, 15, 45), (36, 13, 15, 45), (54, 13, 14, 45), (71, 13, 15, 46), (90, 13, 15, 46)]),
    ("walk", [(15, 14, 58, 88), (35, 13, 58, 88), (54, 12, 58, 88), (74, 14, 58, 88), (98, 12, 58, 88), (117, 12, 58, 88)]),
    ("bang", [(13, 18, 140, 171), (41, 23, 140, 171), (74, 22, 140, 171), (105, 26, 140, 171), (139, 15, 139, 171),
              (162, 16, 139, 171), (185, 19, 140, 171)]),
    ("summon", [(284, 21, 190, 218), (313, 13, 184, 218), (333, 13, 183, 218), (355, 13, 184, 218), (374, 26, 187, 218)]),
    ("dissolve", [(76, 13, 101, 130), (97, 23, 106, 130), (130, 24, 112, 131), (164, 29, 121, 130), (203, 27, 121, 130),
                  (237, 24, 112, 131), (265, 19, 103, 130), (286, 20, 96, 130)]),
    ("knockdown", [(228, 17, 15, 44), (251, 20, 14, 44), (274, 28, 24, 43), (304, 32, 31, 45), (338, 30, 34, 45),
                   (370, 33, 37, 46), (407, 22, 26, 45)]),
]
# Melee combos, drawn from a separate texture (MakimaKicks.png) so Makima.png stays under 4096 px tall.
MAKIMA_KICKS = [
    ("kick1", [(17, 13, 253, 283), (34, 17, 253, 283), (52, 23, 253, 283), (77, 18, 254, 283), (96, 19, 254, 283), (116, 19, 254, 283),
               (137, 15, 254, 283), (154, 29, 253, 283), (186, 23, 252, 283), (218, 22, 254, 283), (245, 26, 252, 283),
               (278, 26, 252, 283), (312, 18, 256, 283), (339, 20, 256, 283)]),
    ("kick2", [(37, 12, 341, 371), (53, 18, 342, 371), (76, 28, 343, 371), (109, 18, 342, 371), (135, 16, 342, 371),
               (155, 16, 342, 371), (177, 23, 342, 371), (203, 16, 341, 371), (227, 15, 341, 371), (248, 12, 342, 371),
               (268, 27, 342, 371), (297, 19, 342, 371), (320, 18, 342, 371)]),
]
MAKIMA_HOUND = [(457, 43, 183, 218), (506, 41, 182, 218)]
MAKIMA_GUN_FIEND = [(165, 53, 452, 485)]


def build_makima():
    src = Image.open("art/makima_source.png").convert("RGB")
    orig = np.asarray(src).astype(int)
    boosted = np.asarray(ImageEnhance.Contrast(ImageEnhance.Color(src).enhance(1.25)).enhance(1.1)).astype(int)
    bg = np.array(MAKIMA_BG)

    def grab(boxes):
        out = []
        for x, w, top, bottom in boxes:
            f = cut(orig, boosted, bg, (x - 1, top - 1, x + w, bottom + 1), thr=80)
            # The webp source bleeds pink into the outline; peel off pink-tinted edge pixels twice.
            o = orig[top - 2:bottom + 3, x - 2:x + w + 2]
            pinkish = (o[..., 0] > 190) & (o[..., 2] > 140) & (o[..., 1] < o[..., 0] - 25)
            for _ in range(2):
                m = f[..., 3] > 0
                edge = m & ~ndimage.binary_erosion(m)
                f[..., 3][edge & pinkish[:f.shape[0], :f.shape[1]]] = 0
            drop_specks(f)
            out.append(trim_vertical(f))
        return out

    anims = [(n, grab(b)) for n, b in MAKIMA_ANIMS]
    kicks = [(n, grab(b)) for n, b in MAKIMA_KICKS]
    hound, gun = grab(MAKIMA_HOUND), grab(MAKIMA_GUN_FIEND)
    everything = [f for _, fs in anims + kicks for f in fs] + hound + gun
    opaque = np.concatenate([f[f[..., 3] > 0][:, :3] for f in everything])
    side = int(np.ceil(np.sqrt(len(opaque))))
    palette = Image.fromarray(np.resize(opaque, (side * side, 3)).astype(np.uint8).reshape(side, side, 3)) \
        .quantize(colors=48, method=Image.MEDIANCUT)

    def finish(f):
        q = np.asarray(Image.fromarray(f[..., :3]).quantize(palette=palette, dither=Image.Dither.NONE).convert("RGB")).copy()
        m = f[..., 3] > 0
        ring = ndimage.binary_dilation(m, structure=[[0, 1, 0], [1, 1, 1], [0, 1, 0]]) & ~m
        q[ring] = OUTLINE
        return np.dstack([q, (m | ring) * 255]).astype(np.uint8)

    def cell_size(frames, anchor_feet):
        if anchor_feet:
            cw = 2 * max(max(foot_x(f), f.shape[1] - foot_x(f)) for f in frames) + 2
        else:
            cw = max(f.shape[1] for f in frames) + 2
        return cw, max(f.shape[0] for f in frames) + 2

    def strip(frames, anchor_feet, path, size=None):
        """Stacks frames vertically in equal cells (Terraria NPC/projectile layout), then scales 2x."""
        frames = [finish(f) for f in frames]
        cw, ch = size or cell_size(frames, anchor_feet)
        img = Image.new("RGBA", (cw, ch * len(frames)), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            x = cw // 2 - foot_x(f) if anchor_feet else (cw - f.shape[1]) // 2
            im = Image.fromarray(f)
            img.paste(im, (x, i * ch + ch - f.shape[0]), im)
        img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
        img.save(path)
        return img, cw * 2, ch * 2

    all_frames = [f for _, fs in anims for f in fs]
    kick_frames = [f for _, fs in kicks for f in fs]
    shared = cell_size(all_frames + kick_frames, True)  # same cell size so both textures line up
    img, cw, ch = strip(all_frames, True, "Content/NPCs/Makima.png", shared)
    strip(kick_frames, True, "Content/NPCs/MakimaKicks.png", shared)
    ranges, i = [], 0
    for n, fs in anims:
        ranges.append(f"{n} {i}-{i + len(fs) - 1}")
        i += len(fs)
    print(f"makima: frame {cw} x {ch}, {len(all_frames)} frames | " + ", ".join(ranges))
    print(f"makima kicks: {len(kick_frames)} frames | " + ", ".join(f"{n} {len(fs)}" for n, fs in kicks))

    # Boss map/health-bar icon: the head from the first idle frame, as 32x32.
    first = img.crop((0, 0, cw, ch))
    x0, y0, x1, _ = first.getbbox()
    head = first.crop((x0 - 2, y0 - 2, x1 + 2, y0 + 22))
    side = max(head.size)
    icon = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    icon.paste(head, ((side - head.width) // 2, 0), head)
    icon.resize((32, 32), Image.NEAREST).save("Content/NPCs/Makima_Head_Boss.png")
    _, hw, hh = strip(hound, True, "Content/Projectiles/MakimaHound.png")
    _, gw, gh = strip(gun, False, "Content/Projectiles/MakimaGunFiend.png")
    print(f"hound: frame {hw} x {hh}, 2 frames | gun fiend: {gw} x {gh}")


# ---------------------------------------------------------------- hybrid form sheets with hand-picked frames
# These sources have no labels, so every animation lists its frames as (x, width, top, bottom) in the source.
# Rows are written in DevilAnim order like the Chainsaw Devil sheets; a missing animation leaves its row empty.
# Frame counts and jump/crouch/hurt choices must match the sheet's entry in ChainsawDevilAnimation.cs.

def band(top, bottom, *frames):
    return [(x, w, top, bottom) for x, w in frames]


KATANA = dict(
    source="art/katana_man_source.png", bg=(2, 63, 130), out="Content/Players/HybridKatanaSheet.png",
    preview="art/HybridKatanaSheet_preview_4x.png",
    blank=[(262, 0, 393, 122)],  # the portrait in the top-right corner
    anims={
        "idle": band(43, 65, (10, 34), (55, 33), (102, 34), (148, 34), (191, 33), (233, 29)),
        "walk": band(81, 104, (8, 35), (50, 35), (91, 35), (131, 37), (171, 34), (219, 37)),
        "run": band(81, 104, (8, 35), (50, 35), (91, 35), (131, 37), (171, 34), (219, 37)),
        "jump": band(246, 283, (5, 27), (43, 25), (80, 24), (112, 31), (154, 32), (192, 30)),
        "crouch": band(587, 614, (8, 21), (39, 26)),
        "attack1": band(200, 235, (6, 34), (58, 38), (112, 32), (152, 32), (192, 34), (240, 37), (280, 40), (322, 36)),
        "attack2": band(432, 472, (4, 25), (40, 29), (80, 19), (115, 24), (194, 36), (235, 35), (278, 34), (320, 32)),
        "attack3": band(538, 573, (6, 19), (45, 29), (91, 39), (149, 24)),
        "attack4": band(691, 723, (5, 28), (38, 18), (69, 33), (108, 32), (151, 27), (192, 34), (237, 35), (280, 41)),
        "attack5": band(746, 778, (3, 28), (44, 26), (74, 35), (118, 41), (168, 24), (200, 36), (240, 32), (280, 38), (323, 35)),
        "airattack1": band(339, 379, (8, 23), (43, 23), (80, 32), (123, 30), (165, 18), (195, 19), (224, 24), (253, 32), (293, 29), (326, 29)),
        "airattack2": band(396, 424, (8, 32), (46, 26)),
        # Knocked down and getting up, played backwards so it starts with the hit.
        "damage": band(118, 148, (211, 29), (179, 27), (145, 23), (98, 28), (57, 31), (20, 28)),
        # The dash-cut with speed lines (frames that are only speed lines are skipped).
        "attack6": band(306, 334, (2, 14), (22, 23), (49, 28), (162, 43), (213, 36), (252, 36), (296, 25), (325, 32)),
    },
)

REZE = dict(
    source="art/reze_source.png", bg=(255, 127, 38), out="Content/Players/HybridBombSheet.png",
    preview="art/HybridBombSheet_preview_4x.png",
    anims={
        "idle": band(93, 125, (9, 11), (34, 11), (63, 11)),
        "walk": band(133, 175, (19, 14), (47, 14), (78, 16), (104, 17), (127, 18)),
        "run": band(201, 227, (12, 15), (28, 23), (54, 25), (88, 14), (104, 20), (127, 23)),
        "jump": band(245, 272, (42, 11), (72, 11)) + band(808, 839, (59, 19), (89, 20), (120, 18)),
        "crouch": band(504, 525, (70, 15), (96, 23)),
        "attack1": band(353, 381, (28, 17), (49, 27), (79, 23), (114, 15), (135, 17), (161, 23), (190, 22)),
        "attack2": band(404, 439, (31, 25), (66, 15), (94, 22), (130, 21), (157, 13), (175, 17), (196, 25), (225, 17)),
        "attack3": band(404, 439, (259, 23), (290, 22), (356, 21), (383, 21), (415, 24)),
        "attack4": band(1104, 1135, (33, 11), (54, 16), (78, 18), (104, 21), (133, 26), (169, 29)),
        "attack5": band(1063, 1091, (41, 20), (72, 24), (110, 35), (155, 25)),
        "airattack1": band(762, 794, (67, 24), (97, 25), (127, 18), (148, 25), (180, 22), (211, 23)),
        "airattack2": band(587, 607, (82, 17), (109, 23), (143, 19), (177, 19), (202, 19)),
        "airattack3": band(709, 737, (65, 17), (103, 28), (143, 27)),
        "damage": band(295, 328, (7, 26), (39, 25), (72, 11), (101, 19), (128, 32), (168, 29)),
        "attack6": band(451, 481, (30, 23), (64, 23), (100, 23), (131, 24), (163, 21), (194, 18)),
    },
)


def build_explicit(name, cfg):
    src = Image.open(cfg["source"]).convert("RGB")
    for rect in cfg.get("blank", []):
        ImageDraw.Draw(src).rectangle(rect, fill=cfg["bg"])
    orig = np.asarray(src).astype(int)
    boosted = np.asarray(ImageEnhance.Contrast(ImageEnhance.Color(src).enhance(1.3)).enhance(1.1)).astype(int)
    bg = np.array(cfg["bg"])

    frames = {}
    for anim, boxes in cfg["anims"].items():
        out = []
        for x, w, top, bottom in boxes:
            f = cut(orig, boosted, bg, (x - 1, top - 1, x + w, bottom + 1), thr=90)
            drop_specks(f)
            out.append(trim_vertical(f))
        frames[anim] = out

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
    everything = [f for fs in frames.values() for f in fs]
    half = max(max(foot_x(f), f.shape[1] - foot_x(f)) for f in everything)
    cw, ch = 2 * half + 2, max(f.shape[0] for f in everything) + 1
    cols = max(len(fs) for fs in frames.values())
    sheet = Image.new("RGBA", (cols * cw, len(ANIM_ORDER) * ch), (0, 0, 0, 0))
    for r, row in enumerate(ANIM_ORDER):
        for c, f in enumerate(frames.get(row, [])):
            im = Image.fromarray(f)
            sheet.paste(im, (c * cw + cw // 2 - foot_x(f), r * ch + ch - f.shape[0]), im)
    sheet.save(cfg["out"])
    print(f"{name}: cell {cw} x {ch} | sheet {sheet.size} | frames {[len(frames.get(r, [])) for r in ANIM_ORDER]}")

    s = 4
    preview = Image.new("RGBA", (sheet.width * s + 140, sheet.height * s), (48, 52, 64, 255))
    big = sheet.resize((sheet.width * s, sheet.height * s), Image.NEAREST)
    preview.paste(big, (140, 0), big)
    draw = ImageDraw.Draw(preview)
    for r, row in enumerate(ANIM_ORDER):
        draw.text((8, r * ch * s + ch * s // 2 - 6), row.upper(), fill=(240, 240, 240, 255))
        draw.line([(0, (r + 1) * ch * s - 1), (preview.width, (r + 1) * ch * s - 1)], fill=(70, 75, 90, 255))
    preview.save(cfg["preview"])


if __name__ == "__main__":
    for sheet_name, config in SHEETS.items():
        build(sheet_name, config)
    build_makima()
    build_explicit("katana", KATANA)
    build_explicit("reze", REZE)
