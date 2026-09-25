"""Generates the placeholder pixel-art sprites for the mod.

Run from the repository root:  python3 tools/generate_sprites.py
Requires Pillow (pip install pillow). Sprites are drawn at half size and
scaled 2x with nearest-neighbour, which matches Terraria's pixel style.
Replace any PNG with hand-made art at the same size whenever you like.
"""
from PIL import Image, ImageDraw

ORANGE = (240, 120, 30, 255)
ORANGE_D = (180, 80, 20, 255)
ORANGE_L = (255, 170, 80, 255)
STEEL = (170, 175, 185, 255)
STEEL_D = (100, 105, 115, 255)
STEEL_L = (225, 230, 235, 255)
BLACK = (25, 20, 20, 255)
RED = (190, 25, 35, 255)
RED_D = (120, 10, 20, 255)
RED_L = (240, 80, 80, 255)
WHITE = (250, 250, 250, 255)
BROWN = (120, 80, 45, 255)
GOLD = (240, 200, 60, 255)
GOLD_D = (170, 130, 30, 255)
CLEAR = (0, 0, 0, 0)


def canvas(w, h):
    img = Image.new("RGBA", (w, h), CLEAR)
    return img, ImageDraw.Draw(img)


def save(img, path):
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(path)
    print("wrote", path, img.width * 2, "x", img.height * 2)


def chainsaw_blade(d, x0, y0, length, teeth_up=True):
    """Horizontal chainsaw bar starting at (x0, y0), 5 px tall."""
    d.rectangle([x0, y0, x0 + length, y0 + 4], fill=STEEL)
    d.line([x0, y0 + 1, x0 + length, y0 + 1], fill=STEEL_L)
    d.line([x0, y0 + 4, x0 + length, y0 + 4], fill=STEEL_D)
    d.ellipse([x0 + length - 2, y0, x0 + length + 2, y0 + 4], fill=STEEL)
    for x in range(x0, x0 + length + 1, 2):
        d.point((x, y0 - 1), fill=STEEL_D)
        d.point((x + 1, y0 + 5), fill=STEEL_D)


def chainsaw_arm_item():
    # 20x12 -> 40x24
    img, d = canvas(20, 12)
    d.rectangle([0, 3, 6, 10], fill=ORANGE)          # engine housing
    d.rectangle([0, 3, 6, 4], fill=ORANGE_L)
    d.rectangle([0, 9, 6, 10], fill=ORANGE_D)
    d.rectangle([2, 5, 4, 7], fill=BLACK)            # starter
    d.point((1, 2), fill=BLACK); d.point((0, 1), fill=BLACK)  # cord
    chainsaw_blade(d, 7, 4, 11)
    save(img, "Content/Items/ChainsawArm.png")


def chainsaw_arm_projectile():
    # Held projectile, pointing up (rotation adds PiOver2). 11x20 -> 22x40
    img, d = canvas(11, 20)
    d.rectangle([2, 13, 8, 19], fill=ORANGE)
    d.rectangle([2, 13, 3, 19], fill=ORANGE_L)
    d.rectangle([7, 13, 8, 19], fill=ORANGE_D)
    d.rectangle([4, 15, 6, 17], fill=BLACK)
    d.rectangle([3, 2, 7, 12], fill=STEEL)
    d.line([4, 2, 4, 12], fill=STEEL_L)
    d.line([7, 2, 7, 12], fill=STEEL_D)
    d.ellipse([3, 0, 7, 4], fill=STEEL)
    for y in range(1, 13, 2):
        d.point((2, y), fill=STEEL_D)
        d.point((8, y + 1), fill=STEEL_D)
    save(img, "Content/Projectiles/ChainsawArmProjectile.png")


def pochitas_heart():
    # 13x13 -> 26x26
    img, d = canvas(13, 13)
    d.ellipse([1, 2, 6, 7], fill=RED)
    d.ellipse([6, 2, 11, 7], fill=RED)
    d.polygon([(1, 5), (11, 5), (6, 11)], fill=RED)
    d.point((3, 3), fill=RED_L); d.point((4, 3), fill=RED_L); d.point((3, 4), fill=RED_L)
    d.line([6, 7, 6, 10], fill=RED_D)
    # Pochita's starter cord sticking out
    d.line([6, 0, 6, 3], fill=BLACK)
    d.rectangle([5, 0, 7, 0], fill=ORANGE)
    save(img, "Content/Items/PochitasHeart.png")


def starter_cord(path, handle, handle_d, cord, spark=None):
    # 11x14 -> 22x28
    img, d = canvas(11, 14)
    d.rectangle([2, 0, 8, 2], fill=handle)           # T-handle
    d.line([2, 2, 8, 2], fill=handle_d)
    pts = [(5, 3), (5, 5), (4, 7), (6, 9), (5, 11), (5, 13)]
    d.line(pts, fill=cord)
    if spark:
        for p in [(1, 5), (9, 6), (2, 10), (8, 11), (0, 1), (10, 1)]:
            d.point(p, fill=spark)
    save(img, path)


def pochita(d, ox, oy, frame):
    """Pochita, 16x16, facing right, at offset (ox, oy)."""
    bob = (0, 1, 0, -1)[frame]
    y = oy + 3 + bob
    d.ellipse([ox + 1, y + 2, ox + 12, y + 11], fill=ORANGE)        # body/head
    d.ellipse([ox + 2, y + 3, ox + 6, y + 6], fill=ORANGE_L)
    d.polygon([(ox + 2, y + 3), (ox + 0, y + 0), (ox + 4, y + 2)], fill=ORANGE_D)   # ears
    d.polygon([(ox + 9, y + 2), (ox + 12, y + 0), (ox + 11, y + 4)], fill=ORANGE_D)
    d.point((ox + 5, y + 6), fill=BLACK); d.point((ox + 9, y + 6), fill=BLACK)   # eyes
    d.line([ox + 6, y + 8, ox + 8, y + 8], fill=BLACK)                  # mouth
    d.point((ox + 7, y + 9), fill=RED)                                  # tongue
    # chainsaw sticking out of the head
    d.rectangle([ox + 6, y - 2, ox + 8, y + 2], fill=STEEL)
    d.point((ox + 5, y - 1 + (frame % 2)), fill=STEEL_D)
    d.point((ox + 9, y + (frame % 2)), fill=STEEL_D)
    # tail: the pull cord
    tail_y = y + 8 + (frame % 2)
    d.line([ox + 12, y + 8, ox + 14, tail_y], fill=BLACK)
    d.point((ox + 15, tail_y), fill=ORANGE)
    # stubby legs
    d.point((ox + 3, y + 11), fill=ORANGE_D); d.point((ox + 10, y + 11), fill=ORANGE_D)


def pochita_pet():
    # 4 vertical frames of 16x16 -> 32x128
    img, d = canvas(16, 16 * 4)
    for f in range(4):
        pochita(d, 0, f * 16, f)
    save(img, "Content/Pets/PochitaPetProjectile.png")


def pochita_doll():
    # 16x16 -> 32x32
    img, d = canvas(16, 16)
    pochita(d, 0, 0, 0)
    save(img, "Content/Pets/PochitaDoll.png")


def buff_icon(path, draw_fn):
    # 16x16 -> 32x32, framed
    img, d = canvas(16, 16)
    d.rectangle([0, 0, 15, 15], fill=(40, 30, 30, 255), outline=BLACK)
    draw_fn(d)
    save(img, path)


def icon_devil(d):
    d.ellipse([3, 5, 12, 14], fill=ORANGE)
    d.point((6, 9), fill=WHITE); d.point((9, 9), fill=WHITE)
    d.rectangle([7, 1, 8, 6], fill=STEEL)   # head chainsaw
    d.rectangle([1, 8, 3, 9], fill=STEEL)   # arm chainsaws
    d.rectangle([12, 8, 14, 9], fill=STEEL)
    d.line([5, 12, 10, 12], fill=RED)


def icon_contract(d):
    d.ellipse([3, 4, 8, 9], fill=RED_D)
    d.ellipse([7, 4, 12, 9], fill=RED_D)
    d.polygon([(3, 7), (12, 7), (7, 13)], fill=RED_D)
    d.line([7, 5, 7, 12], fill=BLACK)


def icon_pet(d):
    pochita(d, 0, 0, 0)


def mod_icon():
    # 40x40 -> 80x80
    img, d = canvas(40, 40)
    d.rectangle([0, 0, 39, 39], fill=(30, 20, 20, 255))
    d.ellipse([8, 12, 32, 36], fill=ORANGE)
    d.ellipse([10, 14, 18, 22], fill=ORANGE_L)
    d.polygon([(10, 15), (5, 8), (14, 12)], fill=ORANGE_D)
    d.polygon([(30, 15), (35, 8), (26, 12)], fill=ORANGE_D)
    d.rectangle([17, 22, 18, 24], fill=BLACK); d.rectangle([24, 22, 25, 24], fill=BLACK)
    d.line([18, 29, 24, 29], fill=BLACK)
    d.rectangle([20, 30, 22, 31], fill=RED)
    d.rectangle([18, 2, 23, 13], fill=STEEL)
    d.line([19, 2, 19, 13], fill=STEEL_L)
    for yy in range(2, 13, 2):
        d.point((17, yy), fill=STEEL_D); d.point((24, yy + 1), fill=STEEL_D)
    save(img, "icon.png")


# ---------------------------------------------------------------- devils
# NPC sprites face LEFT (Terraria flips them when they turn right).
SKIN_Z = (150, 160, 130, 255)
SKIN_ZD = (100, 110, 85, 255)
FLESH = (150, 40, 55, 255)
FLESH_D = (95, 20, 35, 255)
FLESH_L = (200, 80, 90, 255)
BAT = (70, 25, 35, 255)
BAT_D = (40, 12, 20, 255)
BAT_L = (120, 45, 55, 255)
YELLOW = (250, 220, 90, 255)


def zombie_minion():
    # 3 frames of 17x24 -> 34x144 (frame 34x48), same layout as a vanilla zombie
    img, d = canvas(17, 24 * 3)
    for f in range(3):
        oy = f * 24
        leg = (0, 2, -2)[f]
        d.rectangle([6, oy + 3, 11, 8 + oy], fill=SKIN_Z)                 # head
        d.point((6, oy + 5), fill=RED); d.point((8, oy + 5), fill=RED)      # eyes
        d.line([5, oy + 8, 8, oy + 8], fill=RED_D)                          # mouth
        d.rectangle([6, oy + 9, 11, 16 + oy], fill=(90, 90, 110, 255))     # torn shirt
        d.point((8, oy + 12), fill=RED); d.point((10, oy + 14), fill=RED)   # blood
        d.line([6, oy + 10, 1, oy + 11], fill=SKIN_Z)                       # arms reaching left
        d.line([6, oy + 12, 1, oy + 13], fill=SKIN_ZD)
        d.line([8, oy + 17, 8 + leg // 2, oy + 23], fill=(50, 45, 55, 255))  # legs
        d.line([10, oy + 17, 10 - leg // 2, oy + 23], fill=(35, 30, 40, 255))
    save(img, "Content/NPCs/ZombieDevilMinion.png")


def devil_bat():
    # 4 frames of 20x16 -> 40x128
    img, d = canvas(20, 16 * 4)
    for f in range(4):
        oy = f * 16
        wing = (0, 3, 6, 3)[f]
        d.polygon([(9, oy + 7), (1, oy + 2 + wing), (4, oy + 9), (8, oy + 10)], fill=BAT)
        d.polygon([(11, oy + 7), (19, oy + 2 + wing), (16, oy + 9), (12, oy + 10)], fill=BAT)
        d.ellipse([7, oy + 5, 13, oy + 12], fill=BAT_L)
        d.polygon([(7, oy + 6), (7, oy + 3), (9, oy + 5)], fill=BAT_D)      # ears
        d.polygon([(13, oy + 6), (13, oy + 3), (11, oy + 5)], fill=BAT_D)
        d.point((8, oy + 8), fill=YELLOW); d.point((11, oy + 8), fill=YELLOW)
        d.point((9, oy + 10), fill=WHITE); d.point((10, oy + 10), fill=WHITE)  # fangs
    save(img, "Content/NPCs/DevilBat.png")


def zombie_devil_frame(d, oy, f):
    """Hulking rotten devil, 60x80, facing left."""
    step = (0, 3, 0, -3)[f]
    # legs
    d.rectangle([20 + step, oy + 60, 28 + step, oy + 78], fill=FLESH_D)
    d.rectangle([34 - step, oy + 60, 42 - step, oy + 78], fill=FLESH_D)
    d.rectangle([17 + step, oy + 76, 29 + step, oy + 79], fill=BLACK)
    d.rectangle([33 - step, oy + 76, 45 - step, oy + 79], fill=BLACK)
    # body
    d.ellipse([10, oy + 22, 52, oy + 66], fill=FLESH)
    d.ellipse([14, oy + 26, 30, oy + 44], fill=FLESH_L)
    for (x, y) in [(38, 40), (24, 52), (44, 56), (18, 34)]:              # extra eyes on the body
        d.ellipse([x - 2, oy + y - 2, x + 2, oy + y + 2], fill=YELLOW)
        d.point((x, oy + y), fill=BLACK)
    # head with a huge mouth
    d.ellipse([4, oy + 2, 36, oy + 30], fill=FLESH)
    d.ellipse([4, oy + 14, 26, oy + 28], fill=BLACK)                    # mouth
    for x in range(6, 26, 4):
        d.polygon([(x, oy + 15), (x + 2, oy + 15), (x + 1, oy + 19)], fill=WHITE)
        d.polygon([(x, oy + 27), (x + 2, oy + 27), (x + 1, oy + 23)], fill=WHITE)
    d.ellipse([12, oy + 5, 18, oy + 11], fill=YELLOW); d.point((14, oy + 8), fill=BLACK)
    d.ellipse([24, oy + 4, 30, oy + 10], fill=YELLOW); d.point((26, oy + 7), fill=BLACK)
    # arms reaching forward (left)
    arm = (0, 2, 0, -2)[f]
    d.polygon([(12, oy + 34), (0, oy + 44 + arm), (4, oy + 48 + arm), (16, oy + 40)], fill=FLESH_D)
    d.polygon([(48, oy + 34), (58, oy + 50 - arm), (54, oy + 54 - arm), (44, oy + 42)], fill=FLESH_D)
    d.point((1, oy + 47 + arm), fill=WHITE); d.point((3, oy + 49 + arm), fill=WHITE)  # claws


def zombie_devil():
    img, d = canvas(60, 80 * 4)
    for f in range(4):
        zombie_devil_frame(d, f * 80, f)
    save(img, "Content/NPCs/ZombieDevil.png")
    head, hd = canvas(16, 16)
    hd.ellipse([0, 0, 15, 15], fill=FLESH)
    hd.ellipse([2, 8, 11, 14], fill=BLACK)
    for x in (3, 6, 9):
        hd.point((x, 9), fill=WHITE); hd.point((x, 13), fill=WHITE)
    hd.point((5, 4), fill=YELLOW); hd.point((10, 3), fill=YELLOW)
    save(head, "Content/NPCs/ZombieDevil_Head_Boss.png")


def bat_devil():
    # 4 frames of 80x56 -> 160x448
    img, d = canvas(80, 56 * 4)
    for f in range(4):
        oy = f * 56
        wing = (0, 8, 16, 8)[f]
        for side in (-1, 1):
            cx = 40
            tip = (cx + side * 39, oy + 6 + wing)
            d.polygon([(cx + side * 10, oy + 22), tip, (cx + side * 30, oy + 30 + wing // 2),
                       (cx + side * 24, oy + 26 + wing // 3), (cx + side * 16, oy + 34)], fill=BAT)
            d.line([(cx + side * 10, oy + 22), tip], fill=BAT_D, width=1)
        d.ellipse([26, oy + 14, 54, oy + 46], fill=BAT_L)                   # body
        d.ellipse([29, oy + 10, 51, oy + 30], fill=BAT)                     # head
        d.polygon([(30, oy + 14), (27, oy + 1), (36, oy + 11)], fill=BAT_D)  # ears
        d.polygon([(50, oy + 14), (53, oy + 1), (44, oy + 11)], fill=BAT_D)
        d.ellipse([33, oy + 16, 37, oy + 20], fill=YELLOW); d.point((35, oy + 18), fill=RED_D)
        d.ellipse([43, oy + 16, 47, oy + 20], fill=YELLOW); d.point((45, oy + 18), fill=RED_D)
        d.rectangle([35, oy + 24, 45, oy + 27], fill=BLACK)                # mouth
        for x in (36, 39, 42, 44):
            d.point((x, oy + 25), fill=WHITE)
        d.line([38, oy + 28, 38, oy + 31], fill=RED); d.line([42, oy + 28, 42, oy + 33], fill=RED)  # dripping blood
        d.line([34, oy + 46, 32, oy + 53], fill=BAT_D); d.line([46, oy + 46, 48, oy + 53], fill=BAT_D)  # feet
    save(img, "Content/NPCs/BatDevil.png")
    head, hd = canvas(16, 16)
    hd.polygon([(0, 6), (5, 4), (4, 10)], fill=BAT); hd.polygon([(15, 6), (10, 4), (11, 10)], fill=BAT)
    hd.ellipse([3, 3, 12, 13], fill=BAT_L)
    hd.polygon([(4, 5), (3, 0), (7, 4)], fill=BAT_D); hd.polygon([(11, 5), (12, 0), (8, 4)], fill=BAT_D)
    hd.point((5, 7), fill=YELLOW); hd.point((10, 7), fill=YELLOW)
    hd.line([6, 10, 9, 10], fill=BLACK)
    save(head, "Content/NPCs/BatDevil_Head_Boss.png")


def devil_items():
    img, d = canvas(12, 12)                                               # Devil Flesh
    d.ellipse([1, 2, 11, 11], fill=FLESH)
    d.ellipse([3, 3, 7, 6], fill=FLESH_L)
    d.point((8, 7), fill=YELLOW); d.point((5, 9), fill=FLESH_D)
    save(img, "Content/Items/DevilFlesh.png")

    img, d = canvas(14, 14)                                               # Rotting Offering
    d.rectangle([1, 9, 12, 13], fill=BROWN)                               # plate
    d.ellipse([3, 3, 11, 11], fill=FLESH)
    d.ellipse([5, 5, 7, 7], fill=YELLOW); d.point((6, 6), fill=BLACK)
    d.point((9, 4), fill=SKIN_ZD); d.point((4, 10), fill=RED)
    save(img, "Content/Items/Consumables/RottingOffering.png")

    img, d = canvas(10, 14)                                               # Bloody Bat Fang
    d.polygon([(2, 0), (8, 0), (5, 13)], fill=WHITE)
    d.line([3, 1, 5, 11], fill=(210, 210, 200, 255))
    d.polygon([(4, 7), (6, 7), (5, 13)], fill=RED)
    save(img, "Content/Items/Consumables/BloodyBatFang.png")

    img, d = canvas(7, 7)                                                 # Blood Bolt
    d.ellipse([0, 0, 6, 6], fill=RED)
    d.ellipse([1, 1, 3, 3], fill=RED_L)
    save(img, "Content/Projectiles/BloodBolt.png")


# ---------------------------------------------------------------- more devils
GHOST = (215, 225, 240, 255)
GHOST_D = (150, 165, 190, 255)
SPIDER = (60, 45, 70, 255)
SPIDER_L = (100, 80, 115, 255)
FIRE = (255, 140, 30, 255)
FIRE_L = (255, 220, 90, 255)
FIRE_D = (200, 60, 20, 255)
GUNMETAL = (70, 75, 85, 255)
GUNMETAL_L = (130, 135, 150, 255)


def ghost_devil():
    # 4 frames of 16x22 -> 32x176
    img, d = canvas(16, 22 * 4)
    for f in range(4):
        oy = f * 22 + (0, 1, 2, 1)[f]
        d.ellipse([2, oy + 1, 13, oy + 12], fill=GHOST)
        d.rectangle([2, oy + 7, 13, oy + 16], fill=GHOST)
        for x in range(2, 14, 3):                                        # wavy tail
            d.polygon([(x, oy + 16), (x + 3, oy + 16), (x + 1 + (f % 2), oy + 19)], fill=GHOST)
        d.ellipse([4, oy + 5, 6, oy + 8], fill=BLACK); d.ellipse([9, oy + 5, 11, oy + 8], fill=BLACK)
        d.ellipse([6, oy + 10, 9, oy + 13], fill=GHOST_D)                # open mouth
        d.line([1, oy + 9, 0, oy + 13], fill=GHOST_D)                    # long arms
        d.line([14, oy + 9, 15, oy + 13], fill=GHOST_D)
    save(img, "Content/NPCs/GhostDevil.png")


def spider_devil():
    # 4 frames of 20x13 -> 40x104
    img, d = canvas(20, 13 * 4)
    for f in range(4):
        oy = f * 13
        for i, x in enumerate((5, 8, 11, 14)):                           # legs, alternating
            up = ((i + f) % 2) * 2
            d.line([x, oy + 6, x - 3, oy + 12 - up], fill=SPIDER)
            d.line([x, oy + 6, x + 3, oy + 12 - (2 - up)], fill=SPIDER)
        d.ellipse([7, oy + 2, 18, oy + 9], fill=SPIDER)                  # abdomen
        d.ellipse([9, oy + 3, 13, oy + 5], fill=SPIDER_L)
        d.ellipse([2, oy + 3, 8, oy + 8], fill=SPIDER_L)                 # head (facing left)
        for x in (3, 5):
            d.point((x, oy + 5), fill=RED)
        d.point((4, oy + 4), fill=RED)
        d.point((2, oy + 8), fill=WHITE)                                 # fang
    save(img, "Content/NPCs/SpiderDevil.png")


def fire_devil():
    # 4 frames of 16x18 -> 32x144
    img, d = canvas(16, 18 * 4)
    for f in range(4):
        oy = f * 18
        flick = (0, 1, 0, -1)[f]
        d.polygon([(8, oy + 0 + flick), (14, oy + 10), (12, oy + 17), (4, oy + 17), (2, oy + 10)], fill=FIRE_D)
        d.polygon([(8, oy + 3 - flick), (12, oy + 10), (10, oy + 16), (6, oy + 16), (4, oy + 10)], fill=FIRE)
        d.polygon([(8, oy + 7), (10, oy + 12), (8, oy + 15), (6, oy + 12)], fill=FIRE_L)
        d.point((6, oy + 9), fill=BLACK); d.point((9, oy + 9), fill=BLACK)
        d.polygon([(3, oy + 6), (1, oy + 1), (5, oy + 5)], fill=FIRE_D)  # horns
        d.polygon([(13, oy + 6), (15, oy + 1), (11, oy + 5)], fill=FIRE_D)
    save(img, "Content/NPCs/FireDevil.png")


def gun_devil_spawn():
    # 4 frames of 18x18 -> 36x144
    img, d = canvas(18, 18 * 4)
    for f in range(4):
        oy = f * 18 + (0, 1, 0, -1)[f] + 1
        d.ellipse([3, oy + 3, 14, oy + 14], fill=FLESH)
        d.ellipse([5, oy + 5, 8, oy + 8], fill=FLESH_L)
        for (x0, y0, x1, y1) in [(0, 6, 5, 7), (13, 4, 17, 5), (7, 0, 8, 4), (11, 13, 12, 16), (1, 11, 4, 12)]:
            d.rectangle([x0, oy + y0, x1, oy + y1], fill=GUNMETAL)      # barrels sticking out
        d.point((9, oy + 9), fill=YELLOW)
    save(img, "Content/NPCs/GunDevilSpawn.png")


def eternity_fleshling():
    # 4 frames of 14x14 -> 28x112
    img, d = canvas(14, 14 * 4)
    for f in range(4):
        oy = f * 14
        squish = (0, 1, 0, -1)[f]
        d.ellipse([1 - squish, oy + 2 + squish, 12 + squish, oy + 12 - squish], fill=FLESH)
        d.ellipse([4, oy + 4, 9, oy + 9], fill=YELLOW)
        d.ellipse([6, oy + 6, 7, oy + 7], fill=BLACK)
        d.point((2, oy + 10), fill=FLESH_D); d.point((11, oy + 4), fill=FLESH_D)
    save(img, "Content/NPCs/EternityFleshling.png")


def eternity_devil():
    # 4 frames of 90x90 -> 180x720
    img, d = canvas(90, 90 * 4)
    eyes = [(30, 28, 6), (58, 24, 5), (44, 46, 9), (24, 58, 4), (66, 54, 6), (48, 72, 4), (70, 36, 3), (16, 40, 3)]
    for f in range(4):
        oy = f * 90
        pulse = (0, 2, 3, 2)[f]
        d.ellipse([4 - pulse, oy + 6 - pulse, 86 + pulse, oy + 86 + pulse], fill=FLESH_D)
        d.ellipse([8, oy + 10, 82, oy + 82], fill=FLESH)
        for (x, y, r) in [(20, 22, 10), (64, 66, 12), (70, 20, 8)]:        # lumps
            d.ellipse([x - r, oy + y - r, x + r, oy + y + r], fill=FLESH_L)
        for i, (x, y, r) in enumerate(eyes):
            blink = (i + f) % 5 == 0
            if blink:
                d.line([x - r, oy + y, x + r, oy + y], fill=BLACK)
            else:
                d.ellipse([x - r, oy + y - r, x + r, oy + y + r], fill=YELLOW)
                d.ellipse([x - r // 2, oy + y - r // 2, x + r // 2, oy + y + r // 2], fill=BLACK)
        d.ellipse([34, oy + 58, 56, oy + 70], fill=BLACK)                  # mouth
        for x in range(36, 56, 4):
            d.polygon([(x, oy + 59), (x + 2, oy + 59), (x + 1, oy + 63)], fill=WHITE)
    save(img, "Content/NPCs/EternityDevil.png")
    head, hd = canvas(16, 16)
    hd.ellipse([0, 0, 15, 15], fill=FLESH)
    for (x, y) in [(4, 5), (10, 4), (7, 9), (12, 10)]:
        hd.point((x, y), fill=YELLOW)
    hd.line([5, 12, 9, 12], fill=BLACK)
    save(head, "Content/NPCs/EternityDevil_Head_Boss.png")


def gun_devil():
    # 4 frames of 70x70 -> 140x560
    img, d = canvas(70, 70 * 4)
    barrels = [(-1, -0.2), (-0.8, -0.8), (-0.2, -1), (0.6, -0.9), (1, -0.3), (0.9, 0.5), (0.3, 1), (-0.5, 0.9), (-1, 0.4)]
    for f in range(4):
        oy = f * 70
        cx, cy = 35, oy + 35
        for i, (bx, by) in enumerate(barrels):
            recoil = 3 if (i + f) % 3 == 0 else 0
            x1, y1 = cx + bx * (33 - recoil), cy + by * (33 - recoil)
            d.line([cx, cy, x1, y1], fill=GUNMETAL, width=4)
            d.line([cx, cy, x1, y1], fill=GUNMETAL_L, width=1)
            d.ellipse([x1 - 2, y1 - 2, x1 + 2, y1 + 2], fill=BLACK)         # muzzle
            if recoil:
                d.ellipse([x1 - 3, y1 - 3, x1 + 3, y1 + 3], outline=FIRE_L)  # muzzle flash
        d.ellipse([cx - 20, cy - 20, cx + 20, cy + 20], fill=FLESH)
        d.ellipse([cx - 14, cy - 16, cx - 2, cy - 4], fill=FLESH_L)
        d.ellipse([cx - 9, cy - 6, cx + 9, cy + 8], fill=BLACK)
        for x in range(cx - 7, cx + 8, 3):
            d.point((x, cy - 4), fill=WHITE); d.point((x + 1, cy + 6), fill=WHITE)
        d.ellipse([cx + 6, cy - 16, cx + 12, cy - 10], fill=YELLOW); d.point((cx + 9, cy - 13), fill=BLACK)
    save(img, "Content/NPCs/GunDevil.png")
    head, hd = canvas(16, 16)
    hd.line([8, 8, 0, 3], fill=GUNMETAL, width=2); hd.line([8, 8, 15, 4], fill=GUNMETAL, width=2)
    hd.line([8, 8, 3, 15], fill=GUNMETAL, width=2); hd.line([8, 8, 14, 14], fill=GUNMETAL, width=2)
    hd.ellipse([3, 3, 12, 12], fill=FLESH)
    hd.line([6, 9, 10, 9], fill=BLACK); hd.point((10, 5), fill=YELLOW)
    save(head, "Content/NPCs/GunDevil_Head_Boss.png")


def more_devil_items():
    img, d = canvas(11, 11)                                               # Gun Devil Fragment
    d.ellipse([1, 2, 9, 10], fill=FLESH)
    d.rectangle([6, 0, 7, 4], fill=GUNMETAL); d.rectangle([0, 6, 3, 7], fill=GUNMETAL)
    d.point((4, 5), fill=FLESH_L)
    save(img, "Content/Items/GunDevilFragment.png")

    img, d = canvas(11, 14)                                               # Cursed Hotel Key
    d.ellipse([2, 0, 8, 6], outline=GOLD)
    d.ellipse([3, 1, 7, 5], outline=GOLD_D)
    d.line([5, 6, 5, 13], fill=GOLD)
    d.line([5, 10, 7, 10], fill=GOLD); d.line([5, 12, 8, 12], fill=GOLD)
    d.point((4, 3), fill=RED); d.point((6, 8), fill=RED)
    save(img, "Content/Items/Consumables/CursedHotelKey.png")

    img, d = canvas(14, 14)                                               # Gun Devil's Trigger
    d.rectangle([1, 3, 12, 6], fill=GUNMETAL)
    d.line([1, 4, 12, 4], fill=GUNMETAL_L)
    d.polygon([(8, 6), (12, 6), (11, 13), (8, 13)], fill=FLESH)           # fleshy grip
    d.arc([4, 5, 9, 10], 0, 180, fill=GUNMETAL_L)                         # trigger guard
    d.line([6, 6, 6, 8], fill=BLACK)
    save(img, "Content/Items/Consumables/GunDevilsTrigger.png")

    img, d = canvas(7, 7)                                                 # Fire Bolt
    d.ellipse([0, 0, 6, 6], fill=FIRE)
    d.ellipse([1, 1, 4, 4], fill=FIRE_L)
    save(img, "Content/Projectiles/FireBolt.png")

    img, d = canvas(4, 4)                                                 # Devil Bullet (points right)
    d.rectangle([0, 1, 3, 2], fill=GUNMETAL_L)
    d.point((3, 1), fill=FIRE_L); d.point((3, 2), fill=FIRE_L)
    save(img, "Content/Projectiles/DevilBullet.png")


# ---------------------------------------------------------------- Chainsaw Devil abilities
def ability_sprites():
    img, d = canvas(24, 24)                                               # Chainsaw Slash (diagonal blade)
    d.polygon([(3, 21), (19, 3), (22, 6), (6, 24)], fill=STEEL)
    d.line([(4, 20), (19, 4)], fill=STEEL_L)
    for i in range(0, 17, 2):
        d.point((5 + i, 22 - i), fill=STEEL_D)
        d.point((2 + i, 19 - i + 1), fill=STEEL_D)
    d.rectangle([0, 19, 5, 23], fill=ORANGE)
    d.point((20, 5), fill=RED); d.point((14, 10), fill=RED)
    save(img, "Content/Abilities/ChainsawSlash.png")

    img, d = canvas(14, 14)                                               # Rev Dash (speed lines + saw)
    for y in (3, 7, 11):
        d.line([0, y, 6, y], fill=ORANGE_L)
    d.rectangle([6, 5, 13, 9], fill=STEEL)
    d.line([6, 6, 13, 6], fill=STEEL_L)
    for x in range(6, 14, 2):
        d.point((x, 4), fill=STEEL_D); d.point((x + 1, 10), fill=STEEL_D)
    save(img, "Content/Abilities/RevDash.png")

    img, d = canvas(10, 14)                                               # Blood Drink (vial)
    d.rectangle([3, 0, 6, 2], fill=BROWN)
    d.rectangle([2, 3, 7, 13], fill=(200, 220, 230, 255))
    d.rectangle([3, 6, 6, 12], fill=RED)
    d.point((4, 7), fill=RED_L)
    save(img, "Content/Abilities/BloodDrink.png")

    img, d = canvas(14, 14)                                               # Chain Hook
    for i in range(4):
        d.ellipse([i * 3, 10 - i * 3, i * 3 + 3, 13 - i * 3], outline=STEEL)
    d.polygon([(10, 0), (13, 3), (10, 5), (9, 2)], fill=STEEL_L)
    save(img, "Content/Abilities/ChainHook.png")

    img, d = canvas(14, 14)                                               # Chainsaw Storm (ring of saws)
    d.ellipse([1, 1, 12, 12], outline=ORANGE)
    for (x, y) in [(6, 0), (12, 6), (6, 12), (0, 6)]:
        d.ellipse([x - 1, y - 1, x + 2, y + 2], fill=STEEL)
    d.ellipse([4, 4, 9, 9], fill=RED)
    save(img, "Content/Abilities/ChainsawStorm.png")

    img, d = canvas(1, 1)                                                 # Rev Dash hitbox (never drawn)
    save(img, "Content/Projectiles/RevDashHitbox.png")
    save(img, "Content/Projectiles/MakimaKickHitbox.png")              # Makima kick hitbox (never drawn)

    img, d = canvas(7, 7)                                                 # Chain Hook head (points right)
    d.polygon([(0, 1), (6, 3), (0, 5)], fill=STEEL)
    d.line([0, 3, 5, 3], fill=STEEL_L)
    save(img, "Content/Projectiles/ChainHookProjectile.png")

    img, d = canvas(3, 5)                                                 # one chain link (vertical)
    d.rectangle([0, 0, 2, 4], outline=STEEL)
    d.point((1, 2), fill=STEEL_D)
    save(img, "Content/Projectiles/ChainHookChain.png")

    img, d = canvas(20, 20)                                               # Storm Blade (circular saw)
    d.ellipse([1, 1, 18, 18], fill=STEEL)
    d.ellipse([5, 5, 14, 14], fill=STEEL_L)
    d.ellipse([8, 8, 11, 11], fill=ORANGE)
    for (x, y) in [(9, 0), (19, 9), (10, 19), (0, 10), (3, 3), (16, 3), (16, 16), (3, 16)]:
        d.point((x, y), fill=STEEL_D)
    save(img, "Content/Projectiles/StormBlade.png")

    buff_icon("Content/Buffs/BloodDrinkCooldown.png", icon_blood_cooldown)

    img, d = canvas(14, 14)                                               # Makima's Contract (paper with a blood seal)
    d.polygon([(2, 1), (11, 0), (12, 12), (3, 13)], fill=(235, 225, 200, 255))
    for y in (3, 5, 7):
        d.line([4, y, 10, y - 1], fill=(120, 110, 100, 255))
    d.ellipse([7, 8, 11, 12], fill=RED)
    d.point((9, 10), fill=RED_L)
    save(img, "Content/Items/Consumables/MakimasContract.png")


def icon_blood_cooldown(d):
    d.rectangle([6, 2, 9, 3], fill=BROWN)
    d.rectangle([5, 4, 10, 13], fill=(200, 220, 230, 255))
    d.rectangle([6, 10, 9, 12], fill=RED)
    d.line([3, 13, 12, 3], fill=RED)


# ---------------------------------------------------------------- hybrid forms (placeholder sheets)
# Same row layout as the Chainsaw Devil sheets (DevilAnim order); cells are 48x52 with the feet at bottom centre.
# Sprites face RIGHT, like the real sheets. Frame counts must match ChainsawDevilAnimation.Placeholder().
import math

HYB_CELL_W, HYB_CELL_H = 48, 52
HYB_ROWS = [("idle", 4), ("walk", 6), ("run", 6), ("jump", 4), ("crouch", 2), ("attack1", 4), ("attack2", 4),
            ("attack3", 0), ("attack4", 0), ("attack5", 0), ("airattack1", 4), ("airattack2", 0), ("airattack3", 0),
            ("damage", 3), ("attack6", 0)]
SHIRT = (235, 235, 240, 255)
SHIRT_D = (180, 180, 195, 255)
PANTS = (35, 32, 40, 255)
SKIN = (235, 190, 160, 255)
DARK = (45, 40, 50, 255)


def limb(d, x0, y0, length, angle_deg, color, width=2):
    a = math.radians(angle_deg)
    x1, y1 = x0 + math.cos(a) * length, y0 + math.sin(a) * length
    d.line([x0, y0, x1, y1], fill=color, width=width)
    return x1, y1


def pose_for(row, f, n):
    """Returns (front_leg, back_leg, front_arm, back_arm, crouch, lean, attack) angles in degrees (0 = right, 90 = down)."""
    t = f / max(n, 1) * 2 * math.pi
    if row == "idle":
        return 95, 85, 100 + 4 * math.sin(t), 80, 1 if f % 2 else 0, 0, 0
    if row in ("walk", "run"):
        swing = 25 if row == "walk" else 40
        return 90 + swing * math.sin(t), 90 - swing * math.sin(t), 90 - swing * math.sin(t), 90 + swing * math.sin(t), 0, (8 if row == "run" else 0), 0
    if row == "jump":
        return [(70, 110, -60, -120, 0, 0, 0), (60, 120, -40, -140, 0, 0, 0), (45, 135, 0, 180, 3, 0, 0), (80, 100, 120, 60, 0, 0, 0)][f]
    if row == "crouch":
        return 45, 135, 60, 110, 7 + f * 2, 10, 0
    if row in ("attack1", "airattack1"):
        return 75, 110, [-60, -20, 10, 30][f], 120, 0, [0, 4, 10, 6][f], [0, 1, 2, 1][f]
    if row == "attack2":
        return 70, 115, [150, 60, 0, -10][f], 100, 0, [-4, 6, 12, 8][f], [0, 1, 2, 2][f]
    if row == "damage":
        return 100, 80, [200, 220, 230][f], [-30, -40, -45][f], 0, [-12, -18, -22][f], 0
    return 90, 90, 90, 90, 0, 0, 0


def draw_hybrid_figure(d, ox, oy, row, f, n, head_fn, weapon_fn, accent):
    front_leg, back_leg, front_arm, back_arm, crouch, lean, attack = pose_for(row, f, n)
    fx = ox + HYB_CELL_W // 2
    feet_y = oy + HYB_CELL_H - 4  # room for line thickness + outline
    hip = (fx, feet_y - 12 + crouch)
    if row == "jump":
        hip = (fx, feet_y - 14)
    # legs (back first). On the ground, each leg's length is chosen so the foot lands exactly on the floor.
    def leg_length(angle):
        if row == "jump":
            return 12
        down = math.sin(math.radians(angle))
        return max(6, min(14, (feet_y - hip[1]) / down)) if down > 0.2 else 12
    limb(d, hip[0], hip[1], leg_length(back_leg), back_leg, DARK, 3)
    limb(d, hip[0], hip[1], leg_length(front_leg), front_leg, PANTS, 3)
    # torso, leaning
    shoulder = (hip[0] + lean * 0.4, hip[1] - 11)
    d.polygon([(hip[0] - 3, hip[1]), (hip[0] + 3, hip[1]), (shoulder[0] + 4, shoulder[1]), (shoulder[0] - 4, shoulder[1])], fill=SHIRT)
    d.line([hip[0] - 3, hip[1] - 1, hip[0] + 3, hip[1] - 1], fill=PANTS, width=2)  # belt
    d.line([shoulder[0], shoulder[1] + 1, hip[0], hip[1] - 3], fill=accent)          # tie
    # back arm, head, front arm (+ weapon)
    limb(d, shoulder[0] - 1, shoulder[1] + 1, 9, back_arm, SHIRT_D, 2)
    head_fn(d, shoulder[0] + 1, shoulder[1] - 1, f)
    hx, hy = limb(d, shoulder[0] + 1, shoulder[1] + 1, 9, front_arm, SHIRT, 2)
    weapon_fn(d, hx, hy, front_arm, attack)


def head_round(color, detail):
    def fn(d, x, y, f):
        d.ellipse([x - 5, y - 10, x + 5, y], fill=color)
        detail(d, x, y, f)
    return fn


def bomb_detail(d, x, y, f):
    d.line([x, y - 10, x + 2, y - 14], fill=DARK)                      # fuse
    d.point((x + 2 + f % 2, y - 15), fill=(255, 220, 90, 255))        # spark
    d.ellipse([x - 1, y - 8, x + 3, y - 4], outline=(200, 200, 60, 255))  # pin ring
    d.point((x + 3, y - 6), fill=(255, 80, 40, 255))


def katana_detail(d, x, y, f):
    d.polygon([(x - 1, y - 10), (x + 1, y - 10), (x + 3, y - 20), (x + 1, y - 19)], fill=(210, 215, 225, 255))
    d.point((x + 2, y - 5), fill=(255, 60, 60, 255))


def bow_detail(d, x, y, f):
    d.arc([x - 7, y - 18, x + 7, y - 4], 180, 360, fill=(150, 100, 60, 255), width=2)
    d.line([x - 7, y - 11, x + 7, y - 11], fill=(230, 230, 230, 255))
    d.point((x + 2, y - 5), fill=(255, 60, 60, 255))


def flame_detail(d, x, y, f):
    d.rectangle([x - 2, y - 14, x + 2, y - 9], fill=(110, 110, 120, 255))  # nozzle
    flick = f % 2
    d.polygon([(x - 3, y - 14), (x + 3, y - 14), (x + flick, y - 20)], fill=(255, 140, 30, 255))
    d.point((x, y - 16), fill=(255, 230, 100, 255))


def sword_detail(d, x, y, f):
    d.polygon([(x - 3, y - 9), (x + 3, y - 9), (x + 1, y - 21), (x - 1, y - 21)], fill=(200, 205, 215, 255))
    d.line([x - 4, y - 9, x + 4, y - 9], fill=(170, 140, 60, 255))    # guard
    d.point((x + 2, y - 5), fill=(255, 60, 60, 255))


def spear_detail(d, x, y, f):
    d.line([x, y - 10, x, y - 17], fill=(150, 110, 70, 255))
    d.polygon([(x - 2, y - 17), (x + 2, y - 17), (x, y - 21)], fill=(210, 215, 225, 255))
    d.point((x + 2, y - 5), fill=(255, 60, 60, 255))


def whip_detail(d, x, y, f):
    for i in range(4):
        d.arc([x - 4 - i, y - 14 - i, x + 4 + i, y - 6 + i], 200 + f * 20, 340 + f * 20, fill=(120, 40, 40, 255))
    d.point((x + 2, y - 5), fill=(255, 60, 60, 255))


def weapon_blade(color, length):
    def fn(d, x, y, angle, attack):
        a = math.radians(angle - 90 + attack * 20)
        d.line([x, y, x + math.cos(a) * length, y + math.sin(a) * length], fill=color, width=2)
    return fn


def weapon_none(d, x, y, angle, attack):
    d.point((x, y), fill=SKIN)
    if attack:
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(255, 150, 40, 255))  # blast / flame


def weapon_bow(d, x, y, angle, attack):
    d.arc([x - 4, y - 7, x + 4, y + 7], 270, 90, fill=(150, 100, 60, 255), width=2)
    if attack:
        d.line([x - 2, y, x + 8, y], fill=(230, 230, 230, 255))


def weapon_whip(d, x, y, angle, attack):
    length = 5 + attack * 4
    pts = [(x + i * length / 4, y + math.sin(i + attack) * 2) for i in range(5)]
    d.line(pts, fill=(120, 40, 40, 255), width=1)


HYBRID_LOOKS = {
    # name: (head colour, head detail, weapon, accent)
    # Bomb (Reze) and Katana now use real sheets built by tools/clean_sprite_sheet.py, so they aren't drawn here.
    "Bow": ((80, 60, 55, 255), bow_detail, weapon_bow, (120, 40, 40, 255)),
    "Flamethrower": ((90, 90, 100, 255), flame_detail, weapon_none, (230, 90, 30, 255)),
    "Sword": ((75, 75, 85, 255), sword_detail, weapon_blade((200, 205, 215, 255), 11), (60, 60, 100, 255)),
    "Spear": ((70, 65, 60, 255), spear_detail, weapon_blade((170, 130, 80, 255), 12), (60, 90, 60, 255)),
    "Whip": ((85, 45, 50, 255), whip_detail, weapon_whip, (150, 40, 40, 255)),
}


def outline(img, color=(22, 14, 20, 255)):
    """1px dark outline around everything opaque (same style as the cleaned sheets)."""
    src = img.load()
    out = img.copy()
    dst = out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                        dst[x, y] = color
                        break
    return out


def hybrid_sheets():
    cols = max(n for _, n in HYB_ROWS)
    for name, (head_col, detail, weapon, accent) in HYBRID_LOOKS.items():
        img = Image.new("RGBA", (cols * HYB_CELL_W, len(HYB_ROWS) * HYB_CELL_H), CLEAR)
        for r, (row, n) in enumerate(HYB_ROWS):
            for f in range(n):
                # Each frame is drawn on its own canvas, so nothing can spill into a neighbouring cell.
                cell = Image.new("RGBA", (HYB_CELL_W, HYB_CELL_H), CLEAR)
                draw_hybrid_figure(ImageDraw.Draw(cell), 0, 0, row, f, n, head_round(head_col, detail), weapon, accent)
                cell = outline(cell)
                img.paste(cell, (f * HYB_CELL_W, r * HYB_CELL_H), cell)
        img.save(f"Content/Players/Hybrid{name}Sheet.png")  # 1x: drawn scaled up in game like the real sheets
        print("wrote", f"Content/Players/Hybrid{name}Sheet.png", img.size)


def hybrid_icons():
    """Transform items (a heart / pin per form), ability icons, projectiles and the form buff icon."""
    def heart(path, blade):
        img, d = canvas(12, 12)
        d.ellipse([1, 3, 6, 8], fill=RED); d.ellipse([5, 3, 10, 8], fill=RED)
        d.polygon([(1, 6), (10, 6), (5, 11)], fill=RED)
        blade(d)
        save(img, path)

    img, d = canvas(12, 12)                                               # Grenade Pin
    d.ellipse([1, 4, 8, 11], outline=GOLD, width=2)
    d.line([7, 5, 11, 1], fill=STEEL, width=2)
    save(img, "Content/Hybrids/GrenadePin.png")
    heart("Content/Hybrids/KatanaHeart.png", lambda d: d.line([5, 0, 5, 5], fill=STEEL_L, width=1))
    heart("Content/Hybrids/BowHeart.png", lambda d: d.arc([2, 0, 9, 7], 180, 360, fill=BROWN))
    heart("Content/Hybrids/FlamethrowerHeart.png", lambda d: d.polygon([(4, 3), (7, 3), (5, 0)], fill=ORANGE))
    heart("Content/Hybrids/SwordHeart.png", lambda d: d.polygon([(4, 4), (6, 4), (5, 0)], fill=STEEL_L))
    heart("Content/Hybrids/SpearHeart.png", lambda d: (d.line([5, 1, 5, 5], fill=BROWN), d.point((5, 0), fill=STEEL_L)))
    heart("Content/Hybrids/WhipHeart.png", lambda d: d.arc([2, 0, 9, 6], 200, 340, fill=RED_D))

    def icon(path, draw):
        img, d = canvas(14, 14)
        draw(d)
        save(img, "Content/Abilities/Hybrids/" + path)

    icon("BombBlast.png", lambda d: (d.ellipse([2, 2, 11, 11], fill=ORANGE), d.ellipse([4, 4, 9, 9], fill=GOLD)))
    icon("ExplosivePunch.png", lambda d: (d.rectangle([2, 5, 7, 9], fill=SKIN), d.ellipse([7, 3, 13, 11], fill=ORANGE)))
    icon("TorpedoDash.png", lambda d: (d.polygon([(1, 7), (9, 4), (13, 7), (9, 10)], fill=DARK), d.line([0, 5, 3, 5], fill=ORANGE)))
    icon("KatanaSlash.png", lambda d: (d.line([1, 12, 12, 1], fill=STEEL_L, width=2), d.line([1, 12, 3, 10], fill=DARK, width=2)))
    icon("QuickDraw.png", lambda d: (d.line([0, 7, 13, 7], fill=STEEL_L, width=2), d.line([0, 4, 6, 4], fill=STEEL_D)))
    icon("SlashWave.png", lambda d: d.arc([1, 1, 12, 12], 290, 70, fill=STEEL_L, width=2))
    icon("ArrowBarrage.png", lambda d: [d.line([1, 12 - i * 3, 12, 6 - i], fill=STEEL_L) for i in range(3)])
    icon("PiercingShot.png", lambda d: (d.line([0, 7, 12, 7], fill=BROWN, width=1), d.polygon([(10, 5), (13, 7), (10, 9)], fill=STEEL_L)))
    icon("FlameBreath.png", lambda d: (d.polygon([(1, 7), (12, 2), (12, 12)], fill=ORANGE), d.polygon([(4, 7), (12, 5), (12, 9)], fill=GOLD)))
    icon("FireWall.png", lambda d: [d.polygon([(x, 13), (x + 3, 13), (x + 1, 3 + x % 3)], fill=ORANGE) for x in (1, 5, 9)])
    icon("SwordSlash.png", lambda d: (d.polygon([(2, 11), (11, 2), (13, 3), (4, 12)], fill=STEEL_L), d.line([1, 10, 4, 13], fill=GOLD)))
    icon("BladeEruption.png", lambda d: [d.polygon([(x, 13), (x + 2, 13), (x + 1, 2 + (x % 4))], fill=STEEL_L) for x in (1, 5, 9)])
    icon("SpearThrust.png", lambda d: (d.line([0, 12, 10, 2], fill=BROWN, width=1), d.polygon([(9, 1), (13, 0), (12, 4)], fill=STEEL_L)))
    icon("SpearRain.png", lambda d: [d.line([x, 0, x, 9], fill=STEEL_L) for x in (2, 6, 10)])
    icon("WhipCrack.png", lambda d: d.line([(1, 12), (4, 6), (8, 8), (12, 2)], fill=RED_D, width=1))
    icon("WhipGrab.png", lambda d: (d.line([(1, 12), (5, 5), (10, 7)], fill=RED_D), d.ellipse([9, 5, 13, 9], outline=GOLD)))

    def proj(path, w, h, draw):
        img, d = canvas(w, h)
        draw(d)
        save(img, "Content/Projectiles/Hybrids/" + path)

    proj("DevilArrow.png", 8, 3, lambda d: (d.line([0, 1, 5, 1], fill=BROWN), d.polygon([(5, 0), (7, 1), (5, 2)], fill=STEEL_L)))
    proj("PiercingArrow.png", 12, 4, lambda d: (d.line([0, 1, 8, 1], fill=STEEL_L, width=2), d.polygon([(8, 0), (11, 2), (8, 3)], fill=WHITE)))
    proj("FlameBolt.png", 1, 1, lambda d: None)
    proj("KatanaWave.png", 10, 20, lambda d: (d.arc([-10, 0, 9, 19], 300, 60, fill=STEEL_L, width=2), d.arc([-8, 2, 7, 17], 300, 60, fill=WHITE)))
    proj("DevilSpear.png", 20, 4, lambda d: (d.line([0, 1, 15, 1], fill=BROWN, width=2), d.polygon([(15, 0), (19, 2), (15, 3)], fill=STEEL_L)))
    proj("ExplosiveFist.png", 8, 8, lambda d: (d.ellipse([0, 0, 7, 7], fill=ORANGE), d.ellipse([2, 2, 5, 5], fill=GOLD)))
    proj("BombExplosion.png", 1, 1, lambda d: None)
    proj("HybridDashHitbox.png", 1, 1, lambda d: None)
    proj("FlamePillar.png", 1, 1, lambda d: None)
    proj("SwordEruption.png", 30, 50, lambda d: [d.polygon([(x, 49), (x + 5, 49), (x + 2, 6 + (x * 7) % 18)], fill=STEEL_L) for x in (1, 8, 15, 22)])
    proj("WhipLash.png", 5, 5, lambda d: d.polygon([(0, 4), (2, 0), (4, 4)], fill=RED_D))
    proj("WhipSegment.png", 2, 4, lambda d: d.rectangle([0, 0, 1, 3], fill=(120, 40, 40, 255)))

    buff_icon("Content/Buffs/HybridFormBuff.png", lambda d: (d.ellipse([4, 3, 11, 10], fill=(80, 70, 90, 255)),
                                                           d.line([7, 3, 9, 0], fill=STEEL_L), d.rectangle([5, 10, 10, 14], fill=SHIRT)))


if __name__ == "__main__":
    chainsaw_arm_item()
    chainsaw_arm_projectile()
    pochitas_heart()
    starter_cord("Content/Items/StarterCord.png", ORANGE, ORANGE_D, BLACK)
    starter_cord("Content/Items/RevvedStarterCord.png", GOLD, GOLD_D, STEEL_D, spark=STEEL_L)
    starter_cord("Content/Items/HeroOfHellsCord.png", RED, RED_D, BLACK, spark=ORANGE_L)
    pochita_pet()
    pochita_doll()
    buff_icon("Content/Buffs/ChainsawDevilForm.png", icon_devil)
    buff_icon("Content/Buffs/PochitasContractCooldown.png", icon_contract)
    buff_icon("Content/Pets/PochitaPetBuff.png", icon_pet)
    mod_icon()
    zombie_minion()
    devil_bat()
    zombie_devil()
    bat_devil()
    devil_items()
    ghost_devil()
    spider_devil()
    fire_devil()
    gun_devil_spawn()
    eternity_fleshling()
    eternity_devil()
    gun_devil()
    more_devil_items()
    ability_sprites()
    hybrid_sheets()
    hybrid_icons()
