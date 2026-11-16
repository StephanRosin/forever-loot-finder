# Blacksmithing with a smith: a stout dwarf behind the anvil strikes the glowing
# bar twice a loop, holding it with tongs; sparks fly, the forge glows behind.
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from lib import *
from figures import rig, attach, ik, target, pose, shaped

out, only = args()
s = reset()
random.seed(7)
world((0.012, 0.014, 0.022), (0.03, 0.018, 0.012), 0.5)
glow(threshold=0.95, size=7)

# --- Materials
iron = painted("Iron", (0.018, 0.02, 0.028), (0.05, 0.055, 0.07), rough=0.55, metal=0.7, scale=4,
               rim=(0.12, 0.17, 0.3), wear=(0.2, 0.21, 0.25), bump=0.2)
steel = painted("Steel", (0.12, 0.13, 0.15), (0.3, 0.31, 0.34), rough=0.35, metal=1.0, scale=9,
                rim=(0.25, 0.3, 0.42), wear=(0.6, 0.6, 0.62), bump=0.08)
oak = wood("Oak", (0.07, 0.03, 0.012), (0.26, 0.12, 0.05))
bark = painted("Bark", (0.03, 0.015, 0.008), (0.14, 0.075, 0.035), rough=0.9, scale=5, bump=1.0,
               rim=(0.22, 0.12, 0.05), stretch=(9, 9, 0.7))
floor_m = flagstone("Flags", (0.035, 0.032, 0.03), (0.11, 0.095, 0.085), scale=1.7)
wall_m = flagstone("Wall", (0.03, 0.027, 0.027), (0.1, 0.085, 0.08), scale=2.6)
hot = painted("Hot", (1.0, 0.22, 0.02), (1.0, 0.7, 0.2), rough=0.4, scale=14, bump=0.1,
              emission=(1.0, 0.36, 0.05), emit=16)
spark_m = emissive("Spark", (1.0, 0.65, 0.2), 80)
coal_m = painted("Coal", (0.02, 0.01, 0.01), (1.0, 0.2, 0.01), rough=0.9, scale=18, bump=0.4,
                 emission=(1.0, 0.25, 0.03), emit=5)
fire_m = painted("Fire", (0.4, 0.05, 0.01), (1.0, 0.45, 0.06), rough=1, scale=7, bump=0,
                 emission=(1.0, 0.3, 0.04), emit=2.5)
leather = painted("Leather", (0.06, 0.025, 0.01), (0.22, 0.1, 0.04), rough=0.7, scale=25, bump=0.5)

# --- Room: floor and back wall
setmat(add("plane", "Floor", (0, 0, 0), (14, 14, 1)), floor_m)
setmat(add("plane", "Wall", (0, 4.2, 3), (14, 1, 3), (math.radians(90), 0, 0)), wall_m)

# --- Stump
stump = smooth(add("cyl", "Stump", (0, 0, 0.42), (0.6, 0.6, 0.42), vertices=32), bevel=0.04)
setmat(stump, bark)
setmat(smooth(add("cyl", "StumpTop", (0, 0, 0.845), (0.585, 0.585, 0.01), vertices=32)),
       wood("Rings", (0.2, 0.1, 0.04), (0.45, 0.25, 0.11), scale=9))

# --- Anvil: a profile with feet, waist and face, a tapering horn to the right
pts = [(-0.62, 0.86), (0.6, 0.86), (0.54, 0.95), (0.24, 1.0), (0.17, 1.12), (0.2, 1.2), (0.46, 1.25),
       (0.58, 1.3), (0.58, 1.4), (-0.62, 1.4), (-0.66, 1.33), (-0.6, 1.27), (-0.34, 1.22), (-0.2, 1.14),
       (-0.24, 1.0), (-0.56, 0.95)]
anvil = smooth(profile("Anvil", pts, 0.4), bevel=0.025, segments=3)
setmat(anvil, iron)
horn = add("cone", "Horn", (0.74, 0, 1.345), (0.19, 0.17, 0.34), (0, math.radians(90), 0), vertices=40,
           radius1=1, radius2=0.06, depth=1)
setmat(smooth(horn, bevel=0.01), iron)
for x in (-0.45, -0.33):  # hardy and pritchel holes
    setmat(add("cube", "Hole", (x, 0.07, 1.401), (0.024, 0.024, 0.002)), emissive("HoleM", (0, 0, 0), 0))

# --- The glowing bar, held at its cold end
bar = setmat(smooth(add("cube", "Bar", (0.08, -0.03, 1.428), (0.3, 0.032, 0.026)), bevel=0.012), hot)
cold = setmat(smooth(add("cube", "BarCold", (-0.42, -0.03, 1.428), (0.22, 0.03, 0.024)), bevel=0.01), iron)
light("POINT", (0.08, -0.12, 1.5), 25, (1, 0.45, 0.12), 0.1)

# --- The dwarf (his own make: stout, bald, a braided red beard, leather apron)
DX, DY = 0.05, 0.95
skin = painted("Skin", (0.22, 0.08, 0.035), (0.56, 0.27, 0.15), rough=0.55, scale=7, bump=0.12,
               rim=(0.8, 0.4, 0.25))
hair = painted("Beard", (0.035, 0.007, 0.002), (0.26, 0.065, 0.015), rough=0.7, scale=60, detail=12, bump=1.6,
               stretch=(1, 1, 22), rim=(0.85, 0.38, 0.12))
hair2 = painted("Beard2", (0.05, 0.01, 0.003), (0.36, 0.1, 0.025), rough=0.65, scale=70, detail=12, bump=1.4,
                stretch=(1, 1, 25), rim=(0.9, 0.45, 0.15))
cloth = painted("Shirt", (0.025, 0.03, 0.05), (0.08, 0.09, 0.14), rough=0.85, scale=30, bump=0.4)
pants = painted("Pants", (0.06, 0.04, 0.03), (0.2, 0.14, 0.09), rough=0.9, scale=30, bump=0.4)
boot_m = painted("Boot", (0.025, 0.012, 0.006), (0.12, 0.06, 0.03), rough=0.5, scale=20, bump=0.3,
                 rim=(0.3, 0.18, 0.1))
gold = painted("Gold", (0.35, 0.18, 0.03), (0.85, 0.6, 0.18), rough=0.3, metal=1.0, scale=10, rim=(1.0, 0.8, 0.35))
eye_m = painted("Eye", (0.005, 0.004, 0.004), (0.03, 0.02, 0.02), rough=0.08)

J = {
    "pelvis": ((0, 0, 0.95), (0.3, 0.26)), "belly": ((0, -0.04, 1.25), (0.42, 0.36)),
    "chest": ((0, 0, 1.58), (0.46, 0.34)), "neck": ((0, 0, 1.82), (0.17, 0.17)),
    "top": ((0, -0.02, 2.02), (0.1, 0.1)),
}
for sx, side in ((1, "L"), (-1, "R")):
    J.update({
        "sh" + side: ((0.44 * sx, 0, 1.72), (0.2, 0.2)), "el" + side: ((0.56 * sx, -0.22, 1.48), (0.14, 0.14)),
        "wr" + side: ((0.32 * sx, -0.45, 1.55), (0.1, 0.1)),
        "hip" + side: ((0.16 * sx, 0, 0.9), (0.2, 0.2)), "kn" + side: ((0.22 * sx, -0.04, 0.5), (0.17, 0.17)),
        "an" + side: ((0.22 * sx, 0, 0.14), (0.13, 0.13)),
    })
B = [("spine", "pelvis", "belly", None), ("chest", "belly", "chest", "spine"), ("neck", "chest", "neck", "chest"),
     ("head", "neck", "top", "neck")]
for side in "LR":
    B += [("clav." + side, "chest", "sh" + side, "chest"), ("upper." + side, "sh" + side, "el" + side, "clav." + side),
          ("fore." + side, "el" + side, "wr" + side, "upper." + side),
          ("hip." + side, "pelvis", "hip" + side, "spine"), ("thigh." + side, "hip" + side, "kn" + side, "hip." + side),
          ("shin." + side, "kn" + side, "an" + side, "thigh." + side)]
arm, body = rig("Dwarf", J, B, skin, loc=(DX, DY, 0))
body.data.materials.append(pants)
body.data.materials.append(cloth)
for p in body.data.polygons:
    c = p.center
    if c.z < 0.93:
        p.material_index = 1
    elif c.z < 1.86 and abs(c.x - DX) < 0.37:
        p.material_index = 2


def W(x, y, z):
    return (DX + x, DY + y, z)


def rod(name, a, b, r, mat, verts=12):
    a, b = Vector(a), Vector(b)
    o = add("cyl", name, (a + b) / 2, (r, r, (b - a).length / 2), vertices=verts)
    o.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return setmat(smooth(o), mat)


# Head: a big round skull, a heavy nose, small deep eyes, bushy brows, ears
parts = [setmat(smooth(add("sphere", "Skull", W(0, -0.06, 2.0), (0.21, 0.2, 0.23), segments=32, ring_count=16)), skin),
         setmat(smooth(add("sphere", "Nose", W(0, -0.27, 1.97), (0.065, 0.07, 0.075), segments=20, ring_count=10)), skin),
         setmat(smooth(add("sphere", "Cheeks", W(0, -0.17, 1.93), (0.17, 0.1, 0.09), segments=24, ring_count=12)), skin)]
for sx in (1, -1):
    parts += [setmat(smooth(add("sphere", "Eye", W(0.078 * sx, -0.24, 2.03), (0.028, 0.016, 0.026), segments=12,
                                ring_count=6)), eye_m),
              setmat(smooth(add("cube", "Brow", W(0.09 * sx, -0.235, 2.08), (0.07, 0.03, 0.022),
                                (0, math.radians(-14 * sx), 0)), bevel=0.012, subsurf=1), hair),
              setmat(smooth(add("sphere", "Ear", W(0.205 * sx, -0.05, 1.99), (0.035, 0.05, 0.07), segments=16,
                                ring_count=8)), skin),
              setmat(shaped("Moustache", W(0.085 * sx, -0.3, 1.86), (0.1, 0.05, 0.05),
                            width=lambda t: 0.8 + 0.2 * t, rot=(0, math.radians(32 * sx), 0)), hair)]
# A fringe of hair round the back of the bald head, from ear to ear
for k in range(9):
    a = math.radians(-20 + k * 27.5)   # behind the head, 0 = his left
    parts.append(setmat(shaped("Fringe", W(0.19 * math.cos(a), -0.05 + 0.17 * math.sin(a), 1.95), (0.06, 0.05, 0.08),
                               width=lambda t: 0.7 + 0.3 * t, segments=12, rings=10,
                               rot=(0, 0, a + math.pi / 2)), hair if k % 2 else hair2))
# The beard: a wide wedge from the cheeks down over the chest, two braids with gold rings
# wide at the jaw, falling to the belt, a point at the bottom
beard = shaped("Beard", W(0, -0.4, 1.5), (0.27, 0.15, 0.4),
               width=lambda t: 0.35 + 0.65 * ((t + 1) / 2) ** 0.6,       # a point at the bottom
               depth=lambda t: 0.6 + 0.4 * ((t + 1) / 2), rot=(math.radians(14), 0, 0))
parts.append(setmat(beard, hair))
# Locks over the beard's front, converging to its point; two tones so they read as strands.
BW = lambda t: 0.35 + 0.65 * ((t + 1) / 2) ** 0.6
BD = lambda t: 0.6 + 0.4 * ((t + 1) / 2)
for row, t in enumerate((0.75, 0.45, 0.15, -0.15, -0.45, -0.72)):
    cap = (1 - abs(t) ** 6) ** 0.5
    hw, fd = 0.27 * BW(t) * cap, 0.15 * BD(t) * cap
    n = max(2, int(9 * BW(t)))
    for k in range(n):
        u = (k + 0.5) / n * 2 - 1 + random.uniform(-0.04, 0.04)
        x = u * hw * 0.85
        lock = shaped("Lock", (x, -fd * (0.95 - 0.35 * u * u), 0.4 * t - 0.03), (0.042, 0.03, 0.12 + 0.03 * random.random()),
                      width=lambda tt: 0.45 + 0.55 * (tt + 1) / 2, segments=12, rings=10,
                      rot=(math.radians(-8), -u * 0.35, 0))
        setmat(lock, hair if (k + row) % 2 else hair2)
        lock.parent = beard
        parts.append(lock)
for sx in (1, -1):
    for k in range(4):
        z = 1.1 - k * 0.07
        parts.append(setmat(smooth(add("sphere", "Braid", W(0.06 * sx, -0.58, z), (0.035, 0.035, 0.045),
                                       segments=12, ring_count=8)), hair))
    parts.append(setmat(smooth(add("torus", "Ring", W(0.06 * sx, -0.57, 1.15), (1, 1, 1), major_radius=0.036,
                                   minor_radius=0.011)), gold))
for o in parts:
    attach(o, arm, "head")
# Hands (mittens with a thumb), leather bracers
for sx, side in ((1, "L"), (-1, "R")):
    wr, el = Vector(J["wr" + side][0]) + Vector((DX, DY, 0)), Vector(J["el" + side][0]) + Vector((DX, DY, 0))
    d = (wr - el).normalized()
    hand = setmat(smooth(add("sphere", "Hand", wr + d * 0.06, (0.075, 0.09, 0.07), segments=20, ring_count=10)), skin)
    thumb = setmat(smooth(add("sphere", "Thumb", wr + d * 0.03 + Vector((-0.05 * sx, 0, 0.05)), (0.03, 0.04, 0.03),
                              segments=12, ring_count=6)), skin)
    brace = rod("Bracer", el + (wr - el) * 0.45, el + (wr - el) * 0.95, 0.115, boot_m, verts=20)
    for o in (hand, thumb, brace):
        attach(o, arm, "fore." + side)
    boot = setmat(smooth(add("cube", "Boot", W(0.22 * sx, -0.07, 0.08), (0.13, 0.19, 0.085)), bevel=0.05, subsurf=1),
                  boot_m)
    attach(boot, arm, "shin." + side)
# Leather pauldrons, studded, on both shoulders
for sx, side in ((1, "L"), (-1, "R")):
    pad = setmat(shaped("Pauldron", W(0.46 * sx, 0.0, 1.8), (0.2, 0.22, 0.12), width=lambda t: 1.0,
                        depth=lambda t: 1.0, rot=(0, math.radians(-25 * sx), 0)), boot_m)
    attach(pad, arm, "clav." + side)
    for k in range(3):
        stud = setmat(smooth(add("sphere", "Stud", W((0.38 + 0.08 * k) * sx, -0.2, 1.86 - 0.04 * k), (0.02, 0.02, 0.02),
                                 segments=10, ring_count=5)), gold)
        attach(stud, arm, "clav." + side)
# Apron and belt
apron = setmat(smooth(add("cube", "Apron", W(0, -0.44, 0.95), (0.36, 0.025, 0.5)), bevel=0.02), leather)
belt = setmat(smooth(add("torus", "Belt", W(0, -0.04, 1.08), (1, 0.85, 1), major_radius=0.43, minor_radius=0.035)), boot_m)
buckle = setmat(smooth(add("cube", "Buckle", W(0, -0.42, 1.08), (0.06, 0.02, 0.05)), bevel=0.01), gold)
for o in (apron, belt, buckle):
    attach(o, arm, "spine")

# --- Hammer in his left hand (the camera's right): grip at the object's origin,
# handle along -y, the face pointing down when it lies level.
hammer = bpy.data.objects.new("Hammer", None)
link(hammer)
hparts = [setmat(smooth(add("cyl", "Handle", (0, -0.25, 0), (0.026, 0.026, 0.27), (math.radians(90), 0, 0),
                            vertices=16)), oak),
          setmat(smooth(add("cube", "HHead", (0, -0.52, 0.0), (0.055, 0.06, 0.1)), bevel=0.016), steel),
          setmat(smooth(add("cyl", "HFace", (0, -0.52, -0.1), (0.062, 0.062, 0.016), vertices=24), bevel=0.008), steel),
          setmat(smooth(add("cube", "Peen", (0, -0.52, 0.12), (0.045, 0.02, 0.03)), bevel=0.01), steel),
          setmat(smooth(add("cyl", "Wrap", (0, -0.02, 0), (0.034, 0.034, 0.08), (math.radians(90), 0, 0),
                            vertices=16)), leather)]
for o in hparts:
    o.parent = hammer
YAW = math.radians(-35)
STRIKE = Vector((0.08 + 0.52 * math.sin(-YAW), -0.03 + 0.52 * math.cos(YAW), 1.454 + 0.116))
RAISED = Vector((0.5, 0.75, 2.05))
for base in (0, 20):
    for f, t, a in ((1, 0.75, -80), (6, 1.0, -108), (8, 0.92, -98), (9, 0.18, -26), (10, 0.0, 0.0), (11, 0.07, -10),
                    (13, 0.05, -6), (20, 0.7, -74)):
        key(hammer, "location", base + f, STRIKE.lerp(RAISED, t))
        key(hammer, "rotation_euler", base + f, (math.radians(a), 0, YAW))
key(hammer, "location", 41, STRIKE.lerp(RAISED, 0.75))
key(hammer, "rotation_euler", 41, (math.radians(-80), 0, YAW))
key(hammer, "location", 0, STRIKE.lerp(RAISED, 0.7))
key(hammer, "rotation_euler", 0, (math.radians(-74), 0, YAW))
ik(arm, "fore.L", target("GripL", (0, 0, 0), hammer))
hammer.matrix_world  # noqa
# Tongs in the right hand, holding the bar's cold end
TONG_TIP, TONG_HAND = Vector((-0.5, -0.03, 1.43)), Vector((-0.38, 0.5, 1.52))
for dz in (-0.012, 0.012):
    rod("Tong", TONG_TIP + Vector((0, 0, dz)), TONG_HAND + Vector((0, 0, dz * 2)), 0.011, iron, verts=8)
ik(arm, "fore.R", target("GripR", TONG_HAND))
# He leans into each blow
for base in (0, 20):
    for f, a in ((1, 0), (6, -4), (10, 6), (13, 4), (20, 0)):
        pose(arm, "chest", base + f, (math.radians(a), 0, 0))
        pose(arm, "neck", base + f, (math.radians(-a * 0.6), 0, 0))
pose(arm, "chest", 41, (0, 0, 0))
pose(arm, "neck", 41, (0, 0, 0))

# --- Sparks at each impact (life ends before the next strike: the loop has no seam)
def sparks(at, n=60):
    for i in range(n):
        o = setmat(add("ico", "Spark", (0, 0, 0), (0.014, 0.014, 0.014), subdivisions=1), spark_m)
        v = Vector((random.uniform(-1, 1), random.uniform(-1.2, 0.6), random.uniform(0.25, 1.4))).normalized()
        speed = random.uniform(0.07, 0.22)
        life = random.randint(5, 9)
        start = Vector((0.08 + random.uniform(-0.06, 0.06), -0.03 + random.uniform(-0.03, 0.03), 1.46))
        o.location = start
        key(o, "scale", at - 1, (0, 0, 0))
        for t in range(0, life + 1):
            p = start + v * speed * t + Vector((0, 0, -0.011 * t * t))
            p.z = max(p.z, 1.425 if abs(p.x) < 0.58 and abs(p.y) < 0.2 else 0.01)
            key(o, "location", at + t, p)
            k = 1.0 - (t / life) ** 2
            key(o, "scale", at + t, (k, k, k))
        key(o, "scale", at + life + 1, (0, 0, 0))
sparks(10)
sparks(30)

flash = light("POINT", (0.1, -0.15, 1.6), 0, (1, 0.62, 0.28), 0.05)
for base in (0, 20):
    for f, e in ((9, 0), (10, 170), (12, 60), (15, 0)):
        key(flash.data, "energy", base + f, e)

# --- The forge at the back left: stone hearth, glowing mouth, coals, a hood
forge = setmat(smooth(add("cube", "Forge", (-2.2, 2.9, 0.65), (1.0, 0.75, 0.65)), bevel=0.06), wall_m)
setmat(add("cube", "Mouth", (-2.2, 2.14, 0.8), (0.6, 0.02, 0.26)), fire_m)
hood = setmat(smooth(add("cone", "Hood", (-2.2, 2.95, 2.1), (1.25, 0.95, 0.75), vertices=4, radius1=1,
                         radius2=0.3, depth=1)), wall_m)
hood.rotation_euler = (0, 0, math.radians(45))
for i in range(40):
    setmat(add("ico", "Coal", (-2.2 + random.uniform(-0.55, 0.55), 2.18 + random.uniform(-0.04, 0.06),
                                0.58 + random.uniform(0, 0.1)), (0.06, 0.05, 0.045), subdivisions=1), coal_m)
forge_light = light("AREA", (-2.2, 1.8, 0.95), 300, (1, 0.38, 0.09), 1.4, target=(0, 0, 1.2))
for f in range(1, FRAMES + 2, 2):  # flicker; frame 41 matches frame 1
    t = (f - 1) / FRAMES * 2 * math.pi
    key(forge_light.data, "energy", f, 300 + 60 * math.sin(3 * t) + 35 * math.sin(7 * t + 1))

ember_m = emissive("Ember", (1, 0.42, 0.08), 30)
for i in range(22):
    o = setmat(add("ico", "Ember", (0, 0, 0), (0.009, 0.009, 0.009), subdivisions=1), ember_m)
    x0, ph = -2.2 + random.uniform(-0.55, 0.55), random.random()
    for f in range(1, FRAMES + 2):
        t = ((f - 1) / FRAMES + ph) % 1.0
        key(o, "location", f, (x0 + 0.1 * math.sin(t * 9 + ph * 6), 2.05 - t * 0.35, 1.0 + t * 1.7))
        k = math.sin(t * math.pi)
        key(o, "scale", f, (k, k, k))

# --- Props: a quench barrel at the back right, tongs and horseshoes
setmat(smooth(add("cyl", "Barrel", (1.7, 1.6, 0.45), (0.38, 0.38, 0.45), vertices=28), bevel=0.03), oak)
for z in (0.1, 0.45, 0.8):
    setmat(smooth(add("torus", "Hoop", (1.7, 1.6, z), (1, 1, 1), major_radius=0.39, minor_radius=0.02)), iron)
setmat(add("cyl", "Water", (1.7, 1.6, 0.86), (0.35, 0.35, 0.01), vertices=28),
       painted("WaterM", (0.01, 0.03, 0.04), (0.03, 0.07, 0.09), rough=0.04, bump=0.05))
# A tool board on the wall: a plank, pegs, two hammers and tongs hanging.
setmat(smooth(add("cube", "Board", (0.3, 4.12, 1.95), (0.9, 0.04, 0.16)), bevel=0.02), oak)
for i, x in enumerate((-0.35, 0.1, 0.55, 0.95)):
    setmat(smooth(add("cyl", "Peg", (x, 4.05, 1.92), (0.02, 0.02, 0.06), (math.radians(90), 0, 0), vertices=10)), oak)
    if i < 3:
        setmat(smooth(add("cyl", "THandle", (x, 4.0, 1.58), (0.03, 0.03, 0.32), vertices=12)), oak)
        setmat(smooth(add("cube", "THead", (x, 4.0, 1.24), (0.15 - 0.03 * i, 0.06, 0.06)), bevel=0.015), steel)
for dx in (-0.04, 0.04):
    t = setmat(smooth(add("cube", "Tong", (0.95 + dx, 4.02, 1.55), (0.012, 0.012, 0.36)), bevel=0.005), iron)
    t.rotation_euler = (0, math.radians(6 if dx > 0 else -6), 0)
# A chain down from the hood.
for i in range(9):
    setmat(smooth(add("torus", "Link", (-1.35, 2.35, 2.3 - i * 0.075), (1, 1, 1),
                      (math.radians(90), 0, math.radians(90 * (i % 2))), major_radius=0.03, minor_radius=0.008)), iron)

# --- Light and camera
light("AREA", (-1.0, -2.8, 4.2), 240, (1.0, 0.85, 0.68), 3.0, target=(0, 0, 1.2))   # warm key, above
light("AREA", (2.6, 2.4, 2.4), 420, (0.4, 0.55, 1.0), 2.0, target=(0, 0, 1.25))    # cool rim
light("AREA", (2.5, -3.2, 1.2), 50, (0.55, 0.6, 0.8), 3.0, target=(0, 0, 1.0))     # fill
camera((0.75, -2.75, 2.2), (0.05, 0.55, 1.62), lens=38, dof=4.0)

render(out, only, "blacksmithing_dwarf")
