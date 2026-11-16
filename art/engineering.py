# Engineering: a gnomish workbench. A gear train turns on the back wall, a
# copper boiler pumps its piston, the pressure gauge twitches and the whistle
# puffs steam; in front a torch welds a plate in a shower of blue-white sparks.
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from lib import *

out, only = args()
s = reset()
random.seed(11)
world((0.015, 0.02, 0.03), (0.03, 0.022, 0.015), 0.5)
glow(threshold=1.0, size=6)
TAU = 2 * math.pi


def phase(f):
    """0..1 through the loop. Keys run 0..41: motion blur samples a little before frame 1 and after 40."""
    return ((f - 1) / FRAMES) % 1.0


# --- Materials
brass = painted("Brass", (0.3, 0.17, 0.04), (0.78, 0.55, 0.2), rough=0.32, metal=1.0, scale=10,
                rim=(0.9, 0.7, 0.35), wear=(0.15, 0.09, 0.03), bump=0.06)
copper = painted("Copper", (0.3, 0.09, 0.03), (0.75, 0.33, 0.15), rough=0.35, metal=1.0, scale=8,
                 rim=(0.95, 0.55, 0.35), wear=(0.12, 0.2, 0.15), bump=0.08)
iron = painted("Iron", (0.05, 0.05, 0.055), (0.22, 0.22, 0.24), rough=0.55, metal=0.9, scale=9,
               rim=(0.35, 0.4, 0.5), bump=0.15)
bench_m = wood("Bench", (0.03, 0.013, 0.006), (0.12, 0.058, 0.026), scale=1.6)
wall_m = flagstone("Wall", (0.015, 0.015, 0.018), (0.055, 0.05, 0.05), scale=4.5, seam=(0.012, 0.01, 0.01))
floor_m = flagstone("Floor", (0.025, 0.022, 0.02), (0.09, 0.075, 0.06), scale=3.0)
glass_m = painted("GaugeFace", (0.75, 0.7, 0.55), (0.95, 0.9, 0.75), rough=0.4, scale=20, bump=0.05)
black = painted("Ink", (0.01, 0.01, 0.01), (0.03, 0.03, 0.03), rough=0.5)
red = painted("RedNeedle", (0.4, 0.02, 0.01), (0.8, 0.05, 0.02), rough=0.4)
flame_m = emissive("Torch", (0.35, 0.6, 1.0), 40)
spark_m = emissive("Spark", (0.75, 0.85, 1.0), 60)
hot_m = emissive("HotSeam", (1.0, 0.45, 0.12), 12)
bulb_m = emissive("Bulb", (1.0, 0.75, 0.35), 18)


g_iron = painted("GIron", (0.05, 0.05, 0.055), (0.22, 0.22, 0.24), rough=0.55, metal=0.9, scale=9,
                 rim=(0.35, 0.4, 0.5), bump=0.15, radial=True)
hole_m = painted("HoleShadow", (0.01, 0.008, 0.006), (0.03, 0.02, 0.015), rough=0.9, radial=True)


def gear(name, teeth, r, depth, loc, mat, holes=0):
    """A spur gear facing the camera (axis along y); teeth trapezoids."""
    pts = []
    tooth = TAU / teeth
    for i in range(teeth):
        a = i * tooth
        for da, rr in ((0.0, r - 0.06 * r), (0.18, r - 0.06 * r), (0.3, r + 0.08 * r), (0.62, r + 0.08 * r),
                       (0.74, r - 0.06 * r), (1.0, r - 0.06 * r)):
            if da == 1.0:
                continue
            aa = a + da * tooth
            pts.append((rr * math.cos(aa), rr * math.sin(aa)))
    g = profile(name, pts, depth)
    # A fan from the centre: the same triangles under every tooth. Left to Blender, the
    # big n-gon is split unevenly and its shading turns with the gear (a jump at the loop seam).
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(g.data)
    bmesh.ops.poke(bm, faces=[f for f in bm.faces if len(f.verts) > 8])
    bm.to_mesh(g.data)
    bm.free()
    g = setmat(smooth(g, bevel=0.004, angle=30), mat)
    for p in g.data.polygons:  # the flat faces flat: smoothing across the fan draws rays
        if abs(p.normal.y) > 0.9:
            p.use_smooth = False
    g.location = loc
    setmat(smooth(add("cyl", name + "Hub", (0, 0, 0), (0.22 * r, 0.22 * r, depth * 0.9), (math.radians(90), 0, 0),
                      vertices=24), bevel=0.004), g_iron).parent = g
    for k in range(holes):
        a = k * TAU / holes
        setmat(add("cyl", name + "Hole", (0.58 * r * math.cos(a), -0.002, 0.58 * r * math.sin(a)),
                   (0.18 * r, 0.18 * r, depth * 0.52), (math.radians(90), 0, 0), vertices=20),
               hole_m).parent = g
    return g


def spin(g, turns_in_teeth, teeth, offset=0.0):
    """Turns g by a whole number of teeth over the loop, so the loop is seamless."""
    for f in range(0, FRAMES + 2):
        a = offset + (f - 1) / FRAMES * turns_in_teeth * TAU / teeth
        key(g, "rotation_euler", f, a, 1)
    for fc in fcurves(g.animation_data.action):
        for k in fc.keyframe_points:
            k.interpolation = "LINEAR"


# --- Room
setmat(add("plane", "Floor", (0, 0, 0), (12, 12, 1)), floor_m)
setmat(add("plane", "Wall", (0, 1.5, 3), (12, 3, 1), (math.radians(90), 0, 0)), wall_m)

# --- Gear train on the wall: 24 -> 12 -> 18 teeth (pitch radii share one module)
M = 0.034
G = [(24, (-0.55, 1.44, 1.85), 4), (12, (-0.55 + M * 18, 1.44, 1.85), 0), (18, (0.0, 1.44, 1.85 - M * 15 - 0.0), 3)]
# third gear meshes with the 12-tooth one: place it on a circle around that one
c2 = Vector(G[1][1])
a3 = math.radians(-60)
c3 = c2 + Vector((math.cos(a3), 0, math.sin(a3))) * M * 15
G[2] = (18, tuple(c3), 3)
gears = []
# Spinning parts take the radial ("turned") texture: object-space noise would turn with them and jump at the seam.
g_brass = painted("GBrass", (0.3, 0.17, 0.04), (0.78, 0.55, 0.2), rough=0.32, metal=1.0, scale=10,
                  rim=(0.9, 0.7, 0.35), wear=(0.15, 0.09, 0.03), bump=0.06, radial=True)
g_copper = painted("GCopper", (0.3, 0.09, 0.03), (0.75, 0.33, 0.15), rough=0.35, metal=1.0, scale=8,
                   rim=(0.95, 0.55, 0.35), wear=(0.12, 0.2, 0.15), bump=0.08, radial=True)
mats = (g_brass, g_copper, g_brass)
for (n, loc, holes), mat in zip(G, mats):
    gears.append(gear("Gear%d" % n, n, M * n / 2, 0.05, loc, mat, holes))
# 6 teeth a loop: a quarter turn of the 24 (4 holes), a third of the 18 (3 holes),
# half of the 12 -- every wheel ends where its teeth AND holes look the same.
spin(gears[0], 6, 24)
spin(gears[1], -6, 12, offset=math.pi / 12)
spin(gears[2], 6, 18, offset=math.pi / 18 + 0.1)
for (n, loc, _) in G:  # axles into the wall
    setmat(smooth(add("cyl", "Axle", (loc[0], 1.47, loc[2]), (0.02, 0.02, 0.05), (math.radians(90), 0, 0),
                      vertices=12)), iron)
# A mounting plate with rivets behind the train
plate = setmat(smooth(add("cube", "Plate", (-0.25, 1.49, 1.75), (0.75, 0.01, 0.42)), bevel=0.01), iron)
for x in (-0.95, 0.45):
    for z in (1.38, 2.12):
        setmat(smooth(add("sphere", "Rivet", (x, 1.475, z), (0.018, 0.012, 0.018), segments=12, ring_count=6)), brass)

# --- The bench
setmat(smooth(add("cube", "Top", (0, 0.1, 0.88), (1.25, 0.45, 0.05)), bevel=0.012), bench_m)
for x in (-1.1, 1.1):
    for y in (-0.25, 0.45):
        setmat(smooth(add("cube", "Leg", (x, y, 0.42), (0.05, 0.05, 0.42)), bevel=0.01), bench_m)
setmat(smooth(add("cube", "Shelf", (0, 0.15, 0.25), (1.1, 0.35, 0.02)), bevel=0.006), bench_m)
TOP = 0.93

# --- Boiler on the right: copper drum with brass bands, gauge, piston, whistle
BX, BY = 0.6, 0.12
setmat(smooth(add("cyl", "Boiler", (BX, BY, TOP + 0.3), (0.24, 0.24, 0.28), vertices=40), bevel=0.02), copper)
setmat(smooth(add("sphere", "Dome", (BX, BY, TOP + 0.58), (0.24, 0.24, 0.12), segments=40, ring_count=16)), copper)
for z in (TOP + 0.06, TOP + 0.3, TOP + 0.54):
    setmat(smooth(add("torus", "Band", (BX, BY, z), (1, 1, 1), major_radius=0.245, minor_radius=0.012)), brass)
    for k in range(16):
        a = k * TAU / 16
        setmat(add("sphere", "BRivet", (BX + 0.255 * math.cos(a), BY + 0.255 * math.sin(a), z), (0.008, 0.008, 0.008),
                   segments=8, ring_count=4), brass)
for x in (BX - 0.15, BX + 0.15):  # feet
    setmat(smooth(add("cube", "Foot", (x, BY, TOP + 0.015), (0.04, 0.2, 0.015)), bevel=0.004), iron)
# Fire box door with a glow
setmat(smooth(add("cyl", "Door", (BX, BY - 0.235, TOP + 0.16), (0.07, 0.07, 0.012), (math.radians(90), 0, 0),
                  vertices=24), bevel=0.003), iron)
grate = emissive("Grate", (1.0, 0.35, 0.08), 6)
for k in range(3):
    setmat(add("cube", "Slot", (BX - 0.03 + 0.03 * k, BY - 0.249, TOP + 0.16), (0.008, 0.002, 0.04)), grate)
fire_light = light("POINT", (BX, BY - 0.33, TOP + 0.16), 6, (1, 0.45, 0.15), 0.05)
# Gauge
GZ = TOP + 0.38
gauge = setmat(smooth(add("cyl", "Gauge", (BX - 0.08, BY - 0.27, GZ), (0.075, 0.075, 0.02), (math.radians(90), 0, 0),
                          vertices=32)), brass)
setmat(add("cyl", "Face", (BX - 0.08, BY - 0.292, GZ), (0.064, 0.064, 0.002), (math.radians(90), 0, 0), vertices=32),
       glass_m)
for k in range(9):  # tick marks over a 240 degree arc
    a = math.radians(210 - k * 30)
    o = setmat(add("cube", "Tick", (BX - 0.08 + 0.052 * math.cos(a), BY - 0.295, GZ + 0.052 * math.sin(a)),
                   (0.007 if k % 2 == 0 else 0.004, 0.001, 0.0015)), black)
    o.rotation_euler = (0, -a, 0)
setmat(add("cube", "Red", (BX - 0.08 + 0.05 * math.cos(math.radians(-15)), BY - 0.295,
                           GZ + 0.05 * math.sin(math.radians(-15))), (0.01, 0.001, 0.003), (0, math.radians(15), 0)),
       red)
needle = bpy.data.objects.new("Needle", None)
link(needle)
needle.location = (BX - 0.08, BY - 0.298, GZ)
nd = setmat(add("cube", "NeedleBar", (0.024, 0, 0), (0.026, 0.001, 0.002)), red)
nd.parent = needle
setmat(add("cyl", "Pin", (0, 0, 0), (0.007, 0.007, 0.003), (math.radians(90), 0, 0), vertices=12), brass).parent = needle
for f in range(0, FRAMES + 2):
    t = phase(f)
    a = math.radians(40 + 22 * math.sin(2 * TAU * t) + 6 * math.sin(7 * TAU * t))
    key(needle, "rotation_euler", f, -a, 1)
# Piston: a cylinder on the dome, its rod and a crank wheel (two strokes a loop)
setmat(smooth(add("cyl", "PCyl", (BX + 0.08, BY, TOP + 0.75), (0.05, 0.05, 0.1), vertices=24), bevel=0.006), brass)
rod = setmat(smooth(add("cyl", "Rod", (0, 0, 0), (0.014, 0.014, 0.12), vertices=12)), iron)
cap = setmat(smooth(add("cube", "Cross", (0, 0, 0.12), (0.04, 0.02, 0.012)), bevel=0.003), brass)
cap.parent = rod
for f in range(0, FRAMES + 2):
    t = phase(f)
    key(rod, "location", f, (BX + 0.08, BY, TOP + 0.9 + 0.05 * math.sin(2 * TAU * t)))
# Whistle pipe and steam
setmat(smooth(add("cyl", "Pipe", (BX - 0.1, BY + 0.02, TOP + 0.74), (0.015, 0.015, 0.1), vertices=12)), copper)
setmat(smooth(add("cyl", "Whistle", (BX - 0.1, BY + 0.02, TOP + 0.88), (0.028, 0.028, 0.05), vertices=16), bevel=0.004),
       brass)


def steam_material(i):
    m = bpy.data.materials.new("Steam%d" % i)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = (0.9, 0.9, 0.95, 1)
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 3
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
    nt.links.new(noise.outputs["Fac"], mul.inputs[0])
    nt.links.new(mul.outputs[0], vol.inputs["Density"])
    nt.links.new(vol.outputs[0], nt.nodes["Material Output"].inputs["Volume"])
    return m, mul.inputs[1]


for i in range(10):
    o = add("ico", "Puff", (0, 0, 0), (0.05, 0.05, 0.05), subdivisions=3)
    m, dens = steam_material(i)
    setmat(smooth(o), m)
    ph = i / 10
    drift = Vector((random.uniform(-0.05, 0.08), random.uniform(-0.03, 0.03), 0))
    for f in range(0, FRAMES + 2):
        age = (phase(f) + ph) % 1.0
        p = Vector((BX - 0.1, BY + 0.02, TOP + 0.95)) + drift * age * 4 + Vector((0, 0, 0.55 * age))
        key(o, "location", f, p)
        k = 0.4 + 2.2 * age
        key(o, "scale", f, (k, k, k))
        key(dens, "default_value", f, 2.0 * (1 - age) ** 1.5 * min(1, age * 8))

# --- Welding on the left: a plate in a vice, a torch on a stand, sparks
VX = -0.45
setmat(smooth(add("cube", "Vice", (VX, 0.05, TOP + 0.06), (0.12, 0.08, 0.06)), bevel=0.008), iron)
setmat(smooth(add("cube", "Jaw", (VX, 0.05, TOP + 0.15), (0.13, 0.03, 0.03)), bevel=0.005), iron)
work = setmat(smooth(add("cube", "Work", (VX, 0.05, TOP + 0.26), (0.18, 0.008, 0.1)), bevel=0.003), iron)
setmat(add("cube", "Seam", (VX, 0.04, TOP + 0.26), (0.11, 0.002, 0.004)), hot_m)
# A half-built mechanical chicken (a gnome's pride) beside it
ch = Vector((-0.82, 0.15, TOP))
setmat(smooth(add("sphere", "Body", ch + Vector((0, 0, 0.17)), (0.12, 0.09, 0.1), segments=24, ring_count=12)), brass)
setmat(smooth(add("sphere", "Head", ch + Vector((0.1, 0, 0.32)), (0.05, 0.045, 0.05), segments=16, ring_count=8)), brass)
setmat(smooth(add("cone", "Beak", ch + Vector((0.16, 0, 0.32)), (0.02, 0.015, 0.03), (0, math.radians(90), 0),
                  vertices=8, radius1=1, radius2=0, depth=1)), copper)
setmat(smooth(add("cyl", "Neck", ch + Vector((0.07, 0, 0.25)), (0.015, 0.015, 0.06), (0, math.radians(30), 0),
                  vertices=8)), iron)
setmat(add("sphere", "Eye", ch + Vector((0.13, -0.04, 0.34)), (0.012, 0.006, 0.012), segments=8, ring_count=4),
       emissive("Eye", (0.3, 1.0, 0.4), 10))
for dx in (-0.03, 0.03):
    setmat(smooth(add("cyl", "CLeg", ch + Vector((dx, 0, 0.04)), (0.008, 0.008, 0.05), vertices=8)), iron)
crank = gear("Wind", 10, 0.035, 0.012, tuple(ch + Vector((-0.08, -0.1, 0.18))), g_copper)
spin(crank, 5, 10)
# Torch nozzle pointing at the seam, flame flickering
torch = bpy.data.objects.new("Torch", None)
link(torch)
torch.location = (VX + 0.02, -0.18, TOP + 0.3)
torch.rotation_euler = (math.radians(-70), 0, 0)
setmat(smooth(add("cyl", "Nozzle", (0, 0, -0.12), (0.012, 0.012, 0.12), vertices=12)), brass).parent = torch
setmat(smooth(add("cyl", "Grip", (0, 0, -0.3), (0.03, 0.03, 0.08), vertices=16)), iron).parent = torch
flame = setmat(add("cone", "Flame", (0, 0, 0.05), (0.014, 0.014, 0.1), vertices=12, radius1=1, radius2=0, depth=1),
               flame_m)
flame.parent = torch
for f in range(0, FRAMES + 2):
    t = phase(f)
    k = 1 + 0.15 * math.sin(6 * TAU * t) + 0.08 * math.sin(17 * TAU * t)
    key(flame, "scale", f, (1, 1, k))
setmat(smooth(add("cyl", "Hose", (VX + 0.02, -0.45, TOP + 0.03), (0.012, 0.012, 0.25), (0, math.radians(90), 0),
                  vertices=8)), black)
weld = light("POINT", (VX, -0.05, TOP + 0.27), 30, (0.55, 0.7, 1.0), 0.03)
for f in range(0, FRAMES + 2):
    t = phase(f)
    key(weld.data, "energy", f, 30 + 14 * math.sin(9 * TAU * t) + 8 * math.sin(23 * TAU * t + 1))

# Sparks: a steady shower, each with its own phase so the loop has no seam.
hit = Vector((VX, 0.035, TOP + 0.26))
LIFE = 7
for i in range(130):
    o = setmat(add("ico", "Spark", (0, 0, 0), (0.009, 0.009, 0.009), subdivisions=1), spark_m)
    born = random.randrange(FRAMES)
    v = Vector((random.uniform(-1, 1), random.uniform(-1.4, -0.2), random.uniform(-0.2, 1.2))).normalized()
    speed = random.uniform(0.025, 0.07)
    path = []
    for a in range(LIFE + 1):
        p = hit + v * speed * a + Vector((0, 0, -0.006 * a * a))
        p.z = max(p.z, TOP + 0.005)
        path.append(p)
    for f in range(0, FRAMES + 2):
        age = (f - 1 - born) % FRAMES
        if age <= LIFE:
            key(o, "location", f, path[age])
            k = 1.0 - (age / (LIFE + 1)) ** 2
        else:
            key(o, "location", f, path[0] if age == FRAMES - 1 else path[-1])
            k = 0.0
        key(o, "scale", f, (k, k, k))

# --- Clutter: wrench rack, a bulb on a cord, bolts on the bench
for k, x in enumerate((0.95, 1.05, 1.15, 1.25)):
    w = setmat(smooth(add("cube", "Wrench", (x, 1.47, 1.55), (0.012, 0.006, 0.14 + 0.03 * k)), bevel=0.003), iron)
    setmat(smooth(add("torus", "WHead", (x, 1.47, 1.55 + 0.15 + 0.03 * k), (1, 0.5, 1), (math.radians(90), 0, 0),
                      major_radius=0.025, minor_radius=0.008)), iron)
setmat(smooth(add("cube", "Rack", (1.1, 1.48, 1.78), (0.22, 0.01, 0.015)), bevel=0.003), bench_m)
for i in range(14):
    setmat(smooth(add("cyl", "Bolt", (random.uniform(-0.2, 0.25), random.uniform(-0.25, 0.3), TOP + 0.008),
                      (0.012, 0.012, 0.008), vertices=6)), iron)
bulb = setmat(smooth(add("sphere", "Bulb", (0.15, 0.2, 2.25), (0.045, 0.045, 0.06), segments=16, ring_count=8)), bulb_m)
setmat(smooth(add("cyl", "Cord", (0.15, 0.2, 2.6), (0.004, 0.004, 0.3), vertices=6)), black)
setmat(smooth(add("cone", "Shade", (0.15, 0.2, 2.33), (0.12, 0.12, 0.06), vertices=24, radius1=1, radius2=0.25, depth=1)),
       copper)
bl = light("POINT", (0.15, 0.2, 2.2), 70, (1, 0.72, 0.38), 0.06)
for f in range(0, FRAMES + 2):
    t = phase(f)
    key(bl.data, "energy", f, 70 + 5 * math.sin(3 * TAU * t))

# --- Light and camera
light("AREA", (-1.8, -2.4, 3.0), 105, (1.0, 0.82, 0.62), 2.0, target=(0, 0.2, 1.2))   # warm key
light("AREA", (2.2, 1.0, 2.6), 220, (0.45, 0.55, 1.0), 1.5, target=(0, 0.3, 1.3))     # cool rim
light("AREA", (1.8, -2.6, 1.3), 40, (0.6, 0.65, 0.85), 2.5, target=(0, 0.2, 1.0))     # fill
camera((0.35, -2.25, 1.8), (-0.05, 0.3, 1.42), lens=36, dof=3.5)

render(out, only, "engineering")
