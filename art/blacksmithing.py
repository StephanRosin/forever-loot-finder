# Blacksmithing: an anvil on a stump, a glowing bar, a hammer striking twice
# a loop with a burst of sparks, the forge glowing at the back left.
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from lib import *

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
light("POINT", (0.08, -0.12, 1.5), 45, (1, 0.45, 0.12), 0.1)

# --- Hammer on a pivot (the smith's wrist, off frame to the left)
pivot = bpy.data.objects.new("Pivot", None)
link(pivot)
pivot.location = (-1.35, -0.03, 1.6)  # handle ends there
handle = setmat(smooth(add("cyl", "Handle", (-0.62, -0.03, 1.6), (0.036, 0.036, 0.62), (0, math.radians(90), 0),
                           vertices=20)), oak)
grip = setmat(smooth(add("cyl", "Grip", (-1.12, -0.03, 1.6), (0.044, 0.044, 0.17), (0, math.radians(90), 0),
                         vertices=20)), leather)
for x in (-1.0, -1.08, -1.16, -1.24):  # wrap
    setmat(smooth(add("torus", "Wrap", (x, -0.03, 1.6), (1, 1, 1), (0, math.radians(90), 0), major_radius=0.046,
                      minor_radius=0.006)), leather)
head = setmat(smooth(add("cube", "Head", (0.08, -0.03, 1.62), (0.07, 0.07, 0.14)), bevel=0.022), steel)
face = setmat(smooth(add("cyl", "HFace", (0.08, -0.03, 1.47), (0.078, 0.078, 0.022), vertices=28), bevel=0.012), steel)
peen = setmat(smooth(add("cube", "Peen", (0.08, -0.03, 1.78), (0.06, 0.02, 0.03)), bevel=0.012), steel)
band = setmat(smooth(add("cyl", "Band", (0.08, -0.03, 1.6), (0.082, 0.082, 0.02), vertices=28)),
              painted("Brass", (0.3, 0.17, 0.04), (0.7, 0.48, 0.15), rough=0.35, metal=1, rim=(0.9, 0.7, 0.3)))
for o in (handle, grip, head, face, peen, band) + tuple(o for o in bpy.data.objects if o.name.startswith("Wrap")):
    parent(o, pivot)

# Two strikes a loop (period 20): wind up slowly, strike fast, bounce.
def swing(base):
    for f, a in ((1, -30), (6, -38), (8, -35), (9, -3), (10, 0), (11, -7), (13, -4), (20, -29)):
        key(pivot, "rotation_euler", base + f, math.radians(a), 1)
swing(0)
swing(20)
key(pivot, "rotation_euler", 41, math.radians(-30), 1)

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
    for f, e in ((9, 0), (10, 380), (12, 110), (15, 0)):
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
light("AREA", (-1.0, -2.8, 4.2), 360, (1.0, 0.85, 0.68), 3.0, target=(0, 0, 1.2))   # warm key, above
light("AREA", (2.6, 2.4, 2.4), 420, (0.4, 0.55, 1.0), 2.0, target=(0, 0, 1.25))    # cool rim
light("AREA", (2.5, -3.2, 1.2), 50, (0.55, 0.6, 0.8), 3.0, target=(0, 0, 1.0))     # fill
camera((0.95, -3.1, 2.75), (0.0, 0.3, 1.42), lens=38, dof=5.0)

render(out, only, "blacksmithing")
