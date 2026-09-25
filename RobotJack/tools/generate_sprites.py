"""Generates the placeholder pixel-art sprites for Robot Jack.

Run from the RobotJack folder:  python3 tools/generate_sprites.py
Requires Pillow (pip install pillow). Pixel-art sprites are drawn at half size and
scaled 2x with nearest-neighbour, which matches Terraria's pixel style. The beam
textures are drawn at full size so they stay smooth when stretched.
Replace any PNG with hand-made art at the same size whenever you like.
"""
import math
from PIL import Image, ImageDraw

CLEAR = (0, 0, 0, 0)
OUTLINE = (20, 22, 30, 255)
STEEL_D = (60, 68, 84, 255)
STEEL = (110, 122, 145, 255)
STEEL_L = (175, 188, 210, 255)
NAVY = (40, 60, 110, 255)
BLUE = (60, 110, 190, 255)
BLUE_L = (110, 165, 235, 255)
CYAN = (90, 240, 255, 255)
CYAN_D = (30, 150, 200, 255)
WHITE = (250, 255, 255, 255)
ORANGE = (255, 150, 40, 255)
ORANGE_L = (255, 220, 120, 255)
RED = (230, 40, 50, 255)
RED_D = (140, 20, 30, 255)
GOLD = (240, 200, 60, 255)

FRAME_W, FRAME_H = 20, 28  # half size of a vanilla player frame (40x56)
FRAMES = 20


def canvas(w, h):
    img = Image.new("RGBA", (w, h), CLEAR)
    return img, ImageDraw.Draw(img)


def save(img, path, scale=2):
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(path)
    print("wrote", path, img.width, "x", img.height)


def thick_line(d, p0, p1, color, width):
    d.line([p0, p1], fill=color, width=width)


# ---------------------------------------------------------------- player sheets
# Frame layout follows the vanilla player sheet, so the game's own bodyFrame/legFrame pick the pose:
# 0 = idle, 1-4 = arm pointing up / up-forward / forward / down-forward (item use), 5 = jump, 6-19 = walk cycle.

ARM_ANGLES = {1: -90, 2: -45, 3: 0, 4: 45}  # degrees, 0 = forward (right), positive = down


def walk_phase(frame):
    return (frame - 6) / 14 * math.tau


def draw_arm(d, ox, oy, frame, back):
    shoulder = (ox + (8 if back else 11), oy + 12)
    if frame in ARM_ANGLES:
        a = math.radians(ARM_ANGLES[frame])
        length = 7
        hand = (shoulder[0] + round(math.cos(a) * length), shoulder[1] + round(math.sin(a) * length))
    else:
        swing = 0
        if 6 <= frame <= 19:
            swing = round(2 * math.sin(walk_phase(frame)) * (-1 if back else 1))
        elif frame == 5:
            swing = -2 if back else 2
        hand = (shoulder[0] + swing, shoulder[1] + 6)
    col = STEEL_D if back else STEEL
    thick_line(d, shoulder, hand, OUTLINE, 4)
    thick_line(d, shoulder, hand, col, 2)
    # Shoulder plate and cannon hand
    d.rectangle([shoulder[0] - 1, shoulder[1] - 1, shoulder[0] + 1, shoulder[1] + 1], fill=NAVY if back else BLUE)
    d.rectangle([hand[0] - 1, hand[1] - 1, hand[0] + 1, hand[1] + 1], fill=OUTLINE)
    d.point(hand, fill=CYAN_D if back else CYAN)
    return hand


def draw_body_frame(d, g, ox, oy, frame):
    bob = 0
    if 6 <= frame <= 19 and abs(math.sin(walk_phase(frame))) > 0.7:
        bob = 1  # dip down; moving up would spill into the frame above
    y = oy + bob
    draw_arm(d, ox, y, frame, back=True)
    # Thruster pack
    d.rectangle([ox + 3, y + 11, ox + 5, y + 17], fill=OUTLINE)
    d.rectangle([ox + 4, y + 12, ox + 5, y + 16], fill=STEEL_D)
    d.point((ox + 4, y + 17), fill=ORANGE)
    g.point((ox + 4, y + 17), fill=ORANGE_L)
    # Torso
    d.rectangle([ox + 5, y + 10, ox + 14, y + 18], fill=OUTLINE)
    d.rectangle([ox + 6, y + 11, ox + 13, y + 17], fill=BLUE)
    d.line([ox + 6, y + 11, ox + 13, y + 11], fill=BLUE_L)
    d.line([ox + 6, y + 17, ox + 13, y + 17], fill=NAVY)
    d.rectangle([ox + 7, y + 16, ox + 12, y + 17], fill=STEEL_D)  # belt
    # Chest core
    d.rectangle([ox + 9, y + 12, ox + 11, y + 14], fill=OUTLINE)
    d.point((ox + 10, y + 13), fill=CYAN)
    g.point((ox + 10, y + 13), fill=WHITE)
    g.point((ox + 9, y + 13), fill=(90, 240, 255, 120))
    g.point((ox + 11, y + 13), fill=(90, 240, 255, 120))
    # Neck + head
    d.rectangle([ox + 8, y + 9, ox + 11, y + 10], fill=STEEL_D)
    d.rectangle([ox + 5, y + 3, ox + 14, y + 9], fill=OUTLINE)
    d.rectangle([ox + 6, y + 4, ox + 13, y + 8], fill=STEEL)
    d.line([ox + 6, y + 4, ox + 13, y + 4], fill=STEEL_L)
    d.line([ox + 6, y + 8, ox + 13, y + 8], fill=STEEL_D)
    # Visor (facing right)
    d.rectangle([ox + 9, y + 5, ox + 13, y + 6], fill=CYAN_D)
    d.line([ox + 10, y + 5, ox + 13, y + 5], fill=CYAN)
    g.line([ox + 10, y + 5, ox + 13, y + 5], fill=WHITE)
    g.line([ox + 9, y + 6, ox + 13, y + 6], fill=(90, 240, 255, 150))
    # Antenna
    d.line([ox + 7, y + 1, ox + 7, y + 2], fill=STEEL_D)
    d.point((ox + 7, y + 0), fill=RED)
    g.point((ox + 7, y + 0), fill=(255, 90, 90, 255))
    # Ear bolt
    d.point((ox + 7, y + 6), fill=GOLD)
    draw_arm(d, ox, y, frame, back=False)


def draw_leg(d, hip, foot, color):
    knee = ((hip[0] + foot[0]) // 2 + 1, (hip[1] + foot[1]) // 2)
    thick_line(d, hip, knee, OUTLINE, 4)
    thick_line(d, knee, foot, OUTLINE, 4)
    thick_line(d, hip, knee, color, 2)
    thick_line(d, knee, foot, color, 2)
    d.rectangle([knee[0] - 1, knee[1], knee[0], knee[1] + 1], fill=BLUE)
    d.rectangle([foot[0] - 1, foot[1] - 1, foot[0] + 2, foot[1]], fill=OUTLINE)
    d.line([foot[0] - 1, foot[1] - 1, foot[0] + 2, foot[1] - 1], fill=STEEL_D)


def draw_legs_frame(d, g, ox, oy, frame):
    hip_y = oy + 18
    ground = oy + 25
    back_hip = (ox + 8, hip_y)
    front_hip = (ox + 11, hip_y)
    if frame == 5:
        back_foot = (ox + 6, ground - 2)
        front_foot = (ox + 13, ground - 3)
    elif 6 <= frame <= 19:
        s = math.sin(walk_phase(frame))
        lift_front = 1 if s > 0.3 else 0
        lift_back = 1 if s < -0.3 else 0
        front_foot = (ox + 11 + round(3 * s), ground - lift_front)
        back_foot = (ox + 8 - round(3 * s), ground - lift_back)
    else:
        back_foot = (ox + 8, ground)
        front_foot = (ox + 11, ground)
    draw_leg(d, back_hip, back_foot, STEEL_D)
    draw_leg(d, front_hip, front_foot, STEEL)
    # Hip plate
    d.rectangle([ox + 6, hip_y - 1, ox + 13, hip_y], fill=NAVY)
    # Tiny glowing boot jets
    for foot in (back_foot, front_foot):
        g.point((foot[0], foot[1]), fill=(255, 160, 60, 110))


def robot_sheets():
    body, bd = canvas(FRAME_W, FRAME_H * FRAMES)
    body_glow, bg = canvas(FRAME_W, FRAME_H * FRAMES)
    legs, ld = canvas(FRAME_W, FRAME_H * FRAMES)
    legs_glow, lg = canvas(FRAME_W, FRAME_H * FRAMES)
    for f in range(FRAMES):
        draw_body_frame(bd, bg, 0, f * FRAME_H, f)
        draw_legs_frame(ld, lg, 0, f * FRAME_H, f)
    save(body, "Content/Players/RobotBody.png")
    save(body_glow, "Content/Players/RobotBody_Glow.png")
    save(legs, "Content/Players/RobotLegs.png")
    save(legs_glow, "Content/Players/RobotLegs_Glow.png")
    # Big preview of a few frames for the README / checking by eye.
    preview = Image.new("RGBA", (FRAME_W * 7, FRAME_H), (35, 40, 55, 255))
    for i, f in enumerate([0, 1, 2, 3, 4, 5, 9]):
        cell = legs.crop((0, f * FRAME_H, FRAME_W, (f + 1) * FRAME_H))
        preview.alpha_composite(cell, (i * FRAME_W, 0))
        cell = body.crop((0, f * FRAME_H, FRAME_W, (f + 1) * FRAME_H))
        preview.alpha_composite(cell, (i * FRAME_W, 0))
    save(preview, "tools/robot_preview_8x.png", scale=8)


# ---------------------------------------------------------------- items and buffs

def robot_trigger():
    img, d = canvas(14, 16)
    d.rounded_rectangle([3, 5, 10, 15], radius=2, fill=OUTLINE)
    d.rounded_rectangle([4, 6, 9, 14], radius=1, fill=STEEL)
    d.line([4, 6, 4, 14], fill=STEEL_L)
    d.rectangle([5, 0, 8, 5], fill=OUTLINE)       # big button housing
    d.rectangle([6, 1, 7, 4], fill=RED)
    d.point((6, 1), fill=(255, 140, 140, 255))
    d.rectangle([5, 8, 8, 9], fill=CYAN_D)       # screen
    d.point((6, 8), fill=CYAN)
    d.point((6, 11), fill=GOLD); d.point((7, 12), fill=GOLD)
    save(img, "Content/Items/RobotTrigger.png")


def orbital_icon():
    img, d = canvas(16, 16)
    d.rectangle([0, 1, 4, 3], fill=BLUE); d.rectangle([11, 1, 15, 3], fill=BLUE)
    d.line([0, 2, 15, 2], fill=NAVY)
    d.rectangle([5, 0, 10, 4], fill=OUTLINE); d.rectangle([6, 1, 9, 3], fill=STEEL_L)
    d.rectangle([6, 5, 9, 15], fill=CYAN_D)
    d.rectangle([7, 5, 8, 15], fill=WHITE)
    d.line([4, 15, 11, 15], fill=CYAN)
    save(img, "Content/Abilities/OrbitalCannonStrike.png")


def plasma_icon():
    img, d = canvas(16, 12)
    d.rounded_rectangle([0, 2, 10, 9], radius=2, fill=OUTLINE)
    d.rounded_rectangle([1, 3, 9, 8], radius=1, fill=STEEL)
    d.line([1, 3, 9, 3], fill=STEEL_L)
    d.rectangle([10, 4, 14, 7], fill=OUTLINE); d.rectangle([10, 5, 13, 6], fill=STEEL_D)
    d.point((15, 5), fill=CYAN); d.point((15, 6), fill=CYAN)
    d.rectangle([3, 5, 6, 6], fill=CYAN_D); d.point((4, 5), fill=CYAN)
    save(img, "Content/Abilities/PlasmaCannon.png")


def missile(d, x, y):
    d.rectangle([x, y + 1, x + 2, y + 7], fill=OUTLINE)
    d.point((x + 1, y), fill=RED)
    d.line([x + 1, y + 1, x + 1, y + 6], fill=STEEL_L)
    d.point((x, y + 7), fill=RED_D); d.point((x + 2, y + 7), fill=RED_D)
    d.point((x + 1, y + 8), fill=ORANGE)


def missiles_icon():
    img, d = canvas(16, 16)
    missile(d, 1, 6); missile(d, 6, 1); missile(d, 11, 5)
    d.point((7, 11), fill=ORANGE_L); d.point((2, 15), fill=ORANGE_L); d.point((12, 14), fill=ORANGE_L)
    save(img, "Content/Abilities/MissileBarrage.png")


def thruster_icon():
    img, d = canvas(16, 16)
    d.rectangle([9, 3, 15, 12], fill=OUTLINE); d.rectangle([10, 4, 14, 11], fill=STEEL)
    d.line([10, 4, 14, 4], fill=STEEL_L)
    d.polygon([(9, 5), (0, 7), (0, 8), (9, 10)], fill=ORANGE)
    d.polygon([(9, 6), (3, 7), (3, 8), (9, 9)], fill=ORANGE_L)
    d.point((11, 7), fill=CYAN); d.point((12, 7), fill=CYAN)
    save(img, "Content/Abilities/ThrusterDash.png")


def buff_icon(path, inner):
    img, d = canvas(16, 16)
    d.rectangle([0, 0, 15, 15], fill=OUTLINE)
    d.rectangle([1, 1, 14, 14], fill=NAVY)
    inner(d)
    save(img, path)


def robot_form_buff():
    def inner(d):
        d.rectangle([3, 3, 12, 11], fill=STEEL)
        d.rectangle([5, 6, 11, 7], fill=CYAN)
        d.line([4, 1, 4, 3], fill=STEEL_D); d.point((4, 1), fill=RED)
        d.rectangle([5, 12, 10, 13], fill=STEEL_D)
    buff_icon("Content/Buffs/RobotForm.png", inner)


def orbital_cooldown_buff():
    def inner(d):
        d.rectangle([4, 2, 11, 5], fill=STEEL_D)
        d.rectangle([2, 3, 3, 4], fill=BLUE); d.rectangle([12, 3, 13, 4], fill=BLUE)
        d.rectangle([7, 6, 8, 13], fill=RED_D)
        d.ellipse([4, 8, 11, 14], outline=RED)
    buff_icon("Content/Buffs/OrbitalCannonCooldown.png", inner)


# ---------------------------------------------------------------- projectiles

def plasma_bolt():
    img, d = canvas(10, 5)
    d.ellipse([0, 0, 9, 4], fill=(40, 170, 255, 170))
    d.ellipse([2, 1, 9, 3], fill=CYAN)
    d.line([4, 2, 8, 2], fill=WHITE)
    save(img, "Content/Projectiles/PlasmaBolt.png")


def homing_missile():
    # Points up; the projectile adds PiOver2 to its rotation.
    img, d = canvas(5, 11)
    d.rectangle([1, 1, 3, 8], fill=OUTLINE)
    d.point((2, 0), fill=RED)
    d.line([2, 1, 2, 7], fill=STEEL_L)
    d.point((1, 2), fill=RED); d.point((3, 2), fill=RED)
    d.rectangle([0, 7, 0, 9], fill=RED_D); d.rectangle([4, 7, 4, 9], fill=RED_D)
    d.point((2, 9), fill=ORANGE); d.point((2, 10), fill=ORANGE_L)
    save(img, "Content/Projectiles/HomingMissile.png")


def invisible(path):
    img, _ = canvas(1, 1)
    save(img, path, scale=1)


def reticle():
    # Orbital lock-on reticle (also the OrbitalStrike projectile's own texture). Drawn white, tinted in code.
    img, d = canvas(40, 40)
    c = 19.5
    d.ellipse([3, 3, 36, 36], outline=WHITE, width=2)
    d.ellipse([12, 12, 27, 27], outline=(255, 255, 255, 170), width=1)
    for a in range(0, 360, 90):
        r = math.radians(a)
        x0, y0 = c + math.cos(r) * 11, c + math.sin(r) * 11
        x1, y1 = c + math.cos(r) * 20, c + math.sin(r) * 20
        d.line([x0, y0, x1, y1], fill=WHITE, width=2)
    for a in range(45, 360, 90):
        r = math.radians(a)
        x, y = c + math.cos(r) * 17, c + math.sin(r) * 17
        d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=WHITE)
    d.rectangle([19, 19, 20, 20], fill=WHITE)
    save(img, "Content/Projectiles/OrbitalStrike.png")


def satellite():
    img, d = canvas(48, 28)
    # Solar panels
    for x0 in (0, 31):
        d.rectangle([x0, 6, x0 + 16, 14], fill=OUTLINE)
        d.rectangle([x0 + 1, 7, x0 + 15, 13], fill=NAVY)
        for x in range(x0 + 1, x0 + 16, 4):
            d.line([x, 7, x, 13], fill=BLUE)
        d.line([x0 + 1, 10, x0 + 15, 10], fill=BLUE)
        d.point((x0 + 3, 8), fill=BLUE_L)
    d.line([16, 10, 31, 10], fill=STEEL_D, width=2)
    # Body
    d.rectangle([17, 2, 30, 17], fill=OUTLINE)
    d.rectangle([18, 3, 29, 16], fill=STEEL)
    d.line([18, 3, 29, 3], fill=STEEL_L)
    d.rectangle([20, 6, 27, 8], fill=GOLD)
    d.point((21, 12), fill=RED); d.point((26, 12), fill=CYAN)
    # Antenna
    d.line([23, 0, 23, 2], fill=STEEL_D); d.point((24, 0), fill=RED)
    # Downward cannon
    d.rectangle([20, 18, 27, 21], fill=OUTLINE); d.rectangle([21, 18, 26, 20], fill=STEEL_D)
    d.rectangle([21, 22, 26, 25], fill=OUTLINE); d.rectangle([22, 22, 25, 24], fill=STEEL)
    d.rectangle([22, 26, 25, 27], fill=CYAN_D); d.line([23, 27, 24, 27], fill=CYAN)
    save(img, "Content/Projectiles/OrbitalSatellite.png")


def beam_strip():
    # Horizontal cross-section of the beam: white, soft edges. Stretched vertically in code.
    w, h = 64, 4
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    for x in range(w):
        t = abs((x + 0.5) / w * 2 - 1)  # 0 at centre, 1 at edges
        a = max(0.0, 1 - t) ** 1.6
        for y in range(h):
            px[x, y] = (255, 255, 255, int(255 * a))
    save(img, "Content/Projectiles/OrbitalBeam.png", scale=1)


def radial_glow():
    s = 96
    img = Image.new("RGBA", (s, s), CLEAR)
    px = img.load()
    c = (s - 1) / 2
    for y in range(s):
        for x in range(s):
            r = math.hypot(x - c, y - c) / c
            a = max(0.0, 1 - r) ** 2
            px[x, y] = (255, 255, 255, int(255 * a))
    save(img, "Content/Projectiles/OrbitalGlow.png", scale=1)


def shock_ring():
    s = 128
    img = Image.new("RGBA", (s, s), CLEAR)
    px = img.load()
    c = (s - 1) / 2
    for y in range(s):
        for x in range(s):
            r = math.hypot(x - c, y - c) / c
            a = max(0.0, 1 - abs(r - 0.85) / 0.15)
            px[x, y] = (255, 255, 255, int(255 * a ** 1.5))
    save(img, "Content/Projectiles/OrbitalRing.png", scale=1)


def mod_icon():
    img, d = canvas(40, 40)
    d.rectangle([0, 0, 39, 39], fill=(18, 24, 44, 255))
    for i in range(0, 40, 5):
        d.point((i * 7 % 40, i), fill=(200, 220, 255, 255))
    d.rectangle([17, 0, 22, 39], fill=(60, 200, 255, 90))
    d.rectangle([19, 0, 20, 39], fill=(220, 250, 255, 200))
    d.rectangle([7, 12, 32, 33], fill=OUTLINE)
    d.rectangle([9, 14, 30, 31], fill=STEEL)
    d.line([9, 14, 30, 14], fill=STEEL_L)
    d.rectangle([12, 19, 28, 23], fill=CYAN_D)
    d.line([13, 20, 27, 20], fill=CYAN)
    d.rectangle([13, 27, 26, 28], fill=STEEL_D)
    d.line([12, 7, 12, 11], fill=STEEL_D); d.rectangle([11, 5, 13, 7], fill=RED)
    save(img, "icon.png")


if __name__ == "__main__":
    robot_sheets()
    robot_trigger()
    orbital_icon(); plasma_icon(); missiles_icon(); thruster_icon()
    robot_form_buff(); orbital_cooldown_buff()
    plasma_bolt(); homing_missile(); invisible("Content/Projectiles/ThrusterHitbox.png")
    reticle(); satellite(); beam_strip(); radial_glow(); shock_ring()
    mod_icon()
