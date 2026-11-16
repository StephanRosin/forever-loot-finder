# Enchanting: a stone altar with glowing rune bands and a turning rune circle;
# a crystal shard floats and turns above it, an enchanting rod circles it with
# a trail of sparkles, arcane motes spiral up.
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from lib import *

out, only = args()
s = reset()
random.seed(3)
world((0.012, 0.01, 0.03), (0.02, 0.012, 0.03), 0.5)
glow(threshold=1.4, size=5)
TAU = 2 * math.pi

# --- Materials
stone = flagstone("Stone", (0.03, 0.028, 0.04), (0.11, 0.1, 0.13), scale=3.0, seam=(0.01, 0.008, 0.015))
altar_m = painted("Altar", (0.02, 0.018, 0.03), (0.075, 0.065, 0.095), rough=0.8, scale=4, bump=0.6,
                  rim=(0.16, 0.08, 0.3), wear=(0.17, 0.15, 0.21))
gold = painted("Gold", (0.35, 0.18, 0.03), (0.85, 0.6, 0.18), rough=0.3, metal=1.0, scale=10,
               rim=(1.0, 0.8, 0.35), bump=0.05)
rune_m = emissive("Rune", (0.7, 0.3, 1.0), 6)
rune_soft = emissive("RuneSoft", (0.55, 0.25, 1.0), 2)
mote_m = emissive("Mote", (0.85, 0.55, 1.0), 40)
tip_m = emissive("Tip", (1.0, 0.6, 1.0), 60)
wood_m = wood("Shelf", (0.04, 0.018, 0.01), (0.15, 0.07, 0.03))


def crystal_material():
    m = bpy.data.materials.new("Crystal")
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.55, 0.25, 0.9, 1)
    p.inputs["Roughness"].default_value = 0.08
    p.inputs["Transmission Weight"].default_value = 0.85
    p.inputs["IOR"].default_value = 1.6
    p.inputs["Emission Color"].default_value = (0.6, 0.2, 1.0, 1)
    p.inputs["Emission Strength"].default_value = 2.5
    p.inputs["Coat Weight"].default_value = 0.5
    return m


# --- Room: floor with a faint rune circle, back wall
setmat(add("plane", "Floor", (0, 0, 0), (12, 12, 1)), stone)
setmat(add("plane", "Wall", (0, 2.4, 3), (12, 1, 3), (math.radians(90), 0, 0)),
       flagstone("Wall", (0.025, 0.022, 0.035), (0.09, 0.08, 0.11), scale=2.4, seam=(0.01, 0.008, 0.015)))
setmat(add("torus", "FloorRing", (0, 0, 0.003), (1, 1, 0.05), major_radius=1.15, minor_radius=0.012), rune_soft)
setmat(add("torus", "FloorRing2", (0, 0, 0.003), (1, 1, 0.05), major_radius=1.0, minor_radius=0.006), rune_soft)

# --- Altar: an octagonal pillar with a wider base and top, gold rims, rune bands
setmat(smooth(add("cyl", "Base", (0, 0, 0.1), (0.62, 0.62, 0.1), vertices=8), bevel=0.02), altar_m)
setmat(smooth(add("cyl", "Step", (0, 0, 0.24), (0.52, 0.52, 0.05), vertices=8), bevel=0.015), altar_m)
setmat(smooth(add("cyl", "Pillar", (0, 0, 0.62), (0.36, 0.36, 0.34), vertices=8), bevel=0.02), altar_m)
setmat(smooth(add("cyl", "Top", (0, 0, 1.0), (0.55, 0.55, 0.05), vertices=8), bevel=0.02), altar_m)
for z, r in ((1.05, 0.555), (0.95, 0.555), (0.3, 0.525)):
    setmat(smooth(add("torus", "GoldRim", (0, 0, z), (1, 1, 1), (0, 0, math.radians(22.5)), major_radius=r,
                      minor_radius=0.012, major_segments=8, minor_segments=8)), gold)
for i in range(8):  # a rune on each face of the pillar
    a = (i + 0.5) * TAU / 8
    d = Vector((math.cos(a), math.sin(a), 0))
    for k, (dz, w, h) in enumerate(((0.08, 0.05, 0.008), (0.0, 0.008, 0.07), (-0.07, 0.035, 0.008))):
        o = setmat(add("cube", "PRune", d * 0.335 + Vector((0, 0, 0.62 + dz)), (w, 0.004, h)), rune_m)
        o.rotation_euler = (0, 0, a + math.pi / 2)

# --- The rune circle on the altar top, turning one rune step a loop
circle = bpy.data.objects.new("Circle", None)
link(circle)
circle.location = (0, 0, 1.06)
parts = [setmat(add("torus", "R1", (0, 0, 1.06), (1, 1, 0.1), major_radius=0.45, minor_radius=0.008), rune_m),
         setmat(add("torus", "R2", (0, 0, 1.06), (1, 1, 0.1), major_radius=0.36, minor_radius=0.005), rune_m)]
RUNES = 12
for i in range(RUNES):
    a = i * TAU / RUNES
    c = Vector((math.cos(a), math.sin(a), 0)) * 0.405
    for dx, dy, w, h in ((0, 0, 0.004, 0.025), (0.012, 0.01, 0.012, 0.003), (-0.01, -0.012, 0.01, 0.003)):
        o = setmat(add("cube", "Glyph", c + Vector((dx, dy, 1.062)), (w, h, 0.002)), rune_m)
        o.rotation_euler = (0, 0, a)
        parts.append(o)
for i in range(6):  # a hexagram inside
    a1, a2 = i * TAU / 6, (i + 2) * TAU / 6
    p1, p2 = Vector((math.cos(a1), math.sin(a1), 0)) * 0.34, Vector((math.cos(a2), math.sin(a2), 0)) * 0.34
    mid = (p1 + p2) / 2
    o = setmat(add("cube", "Hex", (mid.x, mid.y, 1.061), ((p2 - p1).length / 2, 0.003, 0.002)), rune_m)
    o.rotation_euler = (0, 0, math.atan2(p2.y - p1.y, p2.x - p1.x))
    parts.append(o)
for o in parts:
    parent(o, circle)
for f in (1, FRAMES + 1):
    key(circle, "rotation_euler", f, (f - 1) / FRAMES * TAU / RUNES, 2)
for fc in fcurves(circle.animation_data.action):
    for k in fc.keyframe_points:
        k.interpolation = "LINEAR"

# --- The crystal: two pyramids (a long octahedron), floating, turning
shard = bpy.data.objects.new("Shard", None)
link(shard)
cm = crystal_material()
up = setmat(add("cone", "CUp", (0, 0, 0.2), (0.14, 0.14, 0.4), vertices=6, radius1=1, radius2=0, depth=1), cm)
dn = setmat(add("cone", "CDn", (0, 0, -0.1), (0.14, 0.14, 0.2), (math.pi, 0, 0), vertices=6, radius1=1, radius2=0,
                depth=1), cm)
core = setmat(add("ico", "Core", (0, 0, 0.05), (0.05, 0.05, 0.12), subdivisions=2), emissive("CoreM", (0.8, 0.45, 1), 25))
for o in (up, dn, core):
    o.parent = shard
inner = light("POINT", (0, 0, 0), 40, (0.7, 0.35, 1.0), 0.05)
inner.parent = shard
small = []
for i in range(3):  # little shards orbiting
    o = setmat(add("cone", "Sm", (0, 0, 0), (0.035, 0.035, 0.09), vertices=5, radius1=1, radius2=0, depth=1), cm)
    small.append(o)
for f in range(1, FRAMES + 2):
    t = (f - 1) / FRAMES
    key(shard, "location", f, (0, 0, 1.55 + 0.05 * math.sin(t * TAU)))
    key(shard, "rotation_euler", f, t * TAU / 2, 2)   # a half turn shows the same hexagonal faces
    for i, o in enumerate(small):
        a = t * TAU + i * TAU / 3
        key(o, "location", f, (0.34 * math.cos(a), 0.34 * math.sin(a), 1.5 + 0.06 * math.sin(2 * a + i)))
        key(o, "rotation_euler", f, (0.3, 0.2, a * 2))

# --- The enchanting rod circling the shard, tip glowing, a trail behind
rod = bpy.data.objects.new("Rod", None)
link(rod)
shaft = setmat(smooth(add("cyl", "Shaft", (0, 0, -0.2), (0.014, 0.014, 0.2), vertices=12)), gold)
for z in (-0.05, -0.32):
    setmat(smooth(add("torus", "Band", (0, 0, z), (1, 1, 1), major_radius=0.019, minor_radius=0.006)), gold).parent = rod
gem = setmat(add("ico", "Gem", (0, 0, 0.02), (0.026, 0.026, 0.035), subdivisions=1), tip_m)
prongs = []
for i in range(3):
    a = i * TAU / 3
    p = setmat(smooth(add("cyl", "Prong", (0.022 * math.cos(a), 0.022 * math.sin(a), 0.0), (0.004, 0.004, 0.03),
                          (0.3 * math.sin(a), -0.3 * math.cos(a), 0), vertices=6)), gold)
    prongs.append(p)
for o in [shaft, gem] + prongs:
    o.parent = rod
tip_light = light("POINT", (0, 0, 0.03), 15, (1, 0.5, 1), 0.03)
tip_light.parent = rod


def rod_at(t):
    a = t * TAU
    return Vector((0.42 * math.cos(a), 0.42 * math.sin(a) * 0.6 - 0.15, 1.6 + 0.12 * math.sin(a)))


for f in range(1, FRAMES + 2):
    t = (f - 1) / FRAMES
    p = rod_at(t)
    key(rod, "location", f, p)
    # tilted, the tip leaning towards the shard
    to = Vector((0, 0, 1.55)) - p
    rot = (-to).to_track_quat("-Z", "Y").to_euler()
    key(rod, "rotation_euler", f, (rot.x * 0.5 + 0.4, rot.y * 0.5, rot.z))
# The trail: sparkles left at the tip's path, shrinking (the trail loops with the rod)
for i in range(70):
    o = setmat(add("ico", "Trail", (0, 0, 0), (0.008, 0.008, 0.008), subdivisions=1), mote_m)
    birth = random.random()
    jitter = Vector((random.uniform(-0.02, 0.02), random.uniform(-0.02, 0.02), random.uniform(-0.02, 0.02)))
    for f in range(1, FRAMES + 2):
        t = (f - 1) / FRAMES
        age = (t - birth) % 1.0          # 0 just left, grows
        p = rod_at(birth) + jitter + Vector((0, 0, -0.15 * age))
        k = max(0.0, 1 - age * 4) * (1.2 if i % 5 == 0 else 1.0)
        key(o, "location", f, p)
        key(o, "scale", f, (k, k, k))

# --- Motes spiralling up from the circle
for i in range(40):
    o = setmat(add("ico", "Mote", (0, 0, 0), (0.007, 0.007, 0.007), subdivisions=1), mote_m)
    ph, r0, turns = random.random(), random.uniform(0.15, 0.42), random.choice((1, 2))
    for f in range(1, FRAMES + 2):
        t = ((f - 1) / FRAMES + ph) % 1.0
        a = t * TAU * turns + ph * TAU
        r = r0 * (1 - 0.5 * t)
        key(o, "location", f, (r * math.cos(a), r * math.sin(a), 1.08 + t * 0.95))
        k = math.sin(t * math.pi)
        key(o, "scale", f, (k, k, k))

# --- Candles on stands and a bookshelf behind
wax = painted("Wax", (0.55, 0.48, 0.38), (0.85, 0.8, 0.68), rough=0.5, scale=8, bump=0.2)
flame_m = emissive("Flame", (1.0, 0.55, 0.2), 30)
for x, y, h in ((-1.15, 0.6, 0.9), (1.2, 0.7, 1.05), (-0.85, 1.4, 1.2)):
    setmat(smooth(add("cyl", "Stand", (x, y, h / 2), (0.03, 0.03, h / 2), vertices=10)), gold)
    setmat(smooth(add("cyl", "Dish", (x, y, h), (0.09, 0.09, 0.01), vertices=16)), gold)
    for dx in (-0.035, 0.035):
        ch = random.uniform(0.1, 0.18)
        setmat(smooth(add("cyl", "Candle", (x + dx, y, h + ch / 2), (0.022, 0.022, ch / 2), vertices=14)), wax)
        fl = setmat(add("sphere", "Flame", (x + dx, y, h + ch + 0.025), (0.011, 0.011, 0.025), segments=10, ring_count=6),
                    flame_m)
        for f in range(1, FRAMES + 2, 2):
            t = (f - 1) / FRAMES * TAU
            k = 1 + 0.12 * math.sin(5 * t + dx * 50) + 0.06 * math.sin(13 * t)
            key(fl, "scale", f, (1, 1, k))
    light("POINT", (x, y, h + 0.2), 18, (1, 0.6, 0.3), 0.05)
setmat(smooth(add("cube", "Bookcase", (0.6, 2.2, 1.3), (0.9, 0.18, 1.3)), bevel=0.02), wood_m)
book_cols = [(0.35, 0.05, 0.05), (0.08, 0.15, 0.4), (0.3, 0.2, 0.05), (0.18, 0.06, 0.28), (0.06, 0.22, 0.1)]
for row, z in enumerate((0.55, 1.05, 1.55, 2.05)):
    setmat(smooth(add("cube", "Board", (0.6, 2.05, z - 0.02), (0.85, 0.16, 0.015)), bevel=0.005), wood_m)
    x = -0.2
    while x < 1.4:
        w = random.uniform(0.03, 0.06)
        h = random.uniform(0.25, 0.36)
        c = random.choice(book_cols)
        c = tuple(v * 0.55 for v in c)
        b = setmat(smooth(add("cube", "Book", (x + w / 2, 2.0, z + h / 2), (w / 2, 0.12, h / 2)), bevel=0.004),
                   painted("B%d" % random.randint(0, 99999), tuple(v * 0.5 for v in c), c, rough=0.7, scale=20, bump=0.2))
        if random.random() < 0.15:
            b.rotation_euler = (0, math.radians(12), 0)
        x += w + 0.004

# --- Light and camera
light("AREA", (0, 0, 2.6), 70, (0.65, 0.4, 1.0), 1.0, target=(0, 0, 1.0))           # magic from above
light("AREA", (-2.0, -2.2, 2.4), 70, (1.0, 0.8, 0.6), 1.5, target=(0, 0, 1.0))       # warm key
light("AREA", (1.6, 1.2, 2.2), 200, (0.35, 0.5, 1.0), 1.0, target=(0, 0, 1.3))       # cool rim
camera((0.35, -2.45, 1.75), (0.0, 0.2, 1.28), lens=38, dof=2.2)

render(out, only, "enchanting")
