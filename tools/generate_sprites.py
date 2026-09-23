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


def starter_cord():
    # 11x14 -> 22x28
    img, d = canvas(11, 14)
    d.rectangle([2, 0, 8, 2], fill=ORANGE)           # T-handle
    d.line([2, 2, 8, 2], fill=ORANGE_D)
    pts = [(5, 3), (5, 5), (4, 7), (6, 9), (5, 11), (5, 13)]
    d.line(pts, fill=BLACK)
    save(img, "Content/Items/StarterCord.png")


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


def icon_cord_cooldown(d):
    d.rectangle([4, 2, 11, 4], fill=ORANGE_D)
    d.line([7, 5, 7, 13], fill=STEEL_D)
    d.line([3, 13, 12, 3], fill=RED)


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


if __name__ == "__main__":
    chainsaw_arm_item()
    chainsaw_arm_projectile()
    pochitas_heart()
    starter_cord()
    pochita_pet()
    pochita_doll()
    buff_icon("Content/Buffs/ChainsawDevilForm.png", icon_devil)
    buff_icon("Content/Buffs/StarterCordCooldown.png", icon_cord_cooldown)
    buff_icon("Content/Buffs/PochitasContractCooldown.png", icon_contract)
    buff_icon("Content/Pets/PochitaPetBuff.png", icon_pet)
    mod_icon()
