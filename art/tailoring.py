# Tailoring: an ornate sewing machine on a work table; the needle bobs, the
# hand wheel and the spool turn, purple runecloth with gold embroidery feeds
# under the needle. Five stitches a loop.
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from lib import *

out, only = args()
s = reset()
random.seed(11)
world((0.02, 0.02, 0.04), (0.03, 0.02, 0.02), 0.5)
glow(threshold=1.0, size=6)

STITCHES = 5
STITCH = 0.05                 # cloth moved per stitch (m)
PERIOD = FRAMES // STITCHES   # frames per stitch

# --- Materials
oak = wood("Oak", (0.08, 0.035, 0.014), (0.3, 0.14, 0.055))
dark_oak = wood("DarkOak", (0.04, 0.018, 0.008), (0.16, 0.075, 0.03))
lacquer = painted("Lacquer", (0.008, 0.02, 0.016), (0.03, 0.07, 0.055), rough=0.25, metal=0.2, scale=3,
                  rim=(0.05, 0.25, 0.2), coat=0.8, bump=0.03)
gold = painted("Gold", (0.35, 0.18, 0.03), (0.85, 0.6, 0.18), rough=0.3, metal=1.0, scale=10,
               rim=(1.0, 0.8, 0.35), bump=0.05)
steel = painted("Steel", (0.3, 0.31, 0.34), (0.62, 0.63, 0.66), rough=0.25, metal=1.0, scale=12, bump=0.02)
wall_m = flagstone("Wall", (0.05, 0.04, 0.035), (0.14, 0.11, 0.09), scale=2.4)
floor_m = wood("Floor", (0.05, 0.022, 0.01), (0.18, 0.085, 0.035), scale=1.5)


def cloth(name, base, light, thread, offset):
    """Runecloth: a woven base, gold embroidery bands and the stitch line, all
    moving with `offset` (the mapping's x location, keyed over the loop)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    N = nt.nodes.new
    tc = N("ShaderNodeTexCoord")
    mp = N("ShaderNodeMapping")
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    m["mapping"] = mp.name
    sep = N("ShaderNodeSeparateXYZ")
    nt.links.new(mp.outputs["Vector"], sep.inputs[0])
    # Weave: fine checker of threads.
    weave = N("ShaderNodeTexChecker")
    weave.inputs["Scale"].default_value = 260
    weave.inputs["Color1"].default_value = (*base, 1)
    weave.inputs["Color2"].default_value = (*light, 1)
    nt.links.new(mp.outputs["Vector"], weave.inputs["Vector"])
    # Embroidery: a gold zigzag band repeating every STITCHES * STITCH along x.
    zig = N("ShaderNodeTexWave")
    zig.wave_type = "BANDS"
    zig.bands_direction = "X"
    zig.wave_profile = "TRI"
    zig.inputs["Scale"].default_value = 1.0 / (STITCH * STITCHES) / 1.0
    nt.links.new(mp.outputs["Vector"], zig.inputs["Vector"])
    # band where |y - y0 - 0.02*zig| < width
    def band(y0, width):
        a = N("ShaderNodeMath"); a.operation = "MULTIPLY"; a.inputs[1].default_value = 0.05
        nt.links.new(zig.outputs["Fac"], a.inputs[0])
        b = N("ShaderNodeMath"); b.operation = "SUBTRACT"
        nt.links.new(sep.outputs["Y"], b.inputs[0])
        nt.links.new(a.outputs[0], b.inputs[1])
        c = N("ShaderNodeMath"); c.operation = "SUBTRACT"; c.inputs[1].default_value = y0
        nt.links.new(b.outputs[0], c.inputs[0])
        d = N("ShaderNodeMath"); d.operation = "ABSOLUTE"
        nt.links.new(c.outputs[0], d.inputs[0])
        e = N("ShaderNodeMath"); e.operation = "LESS_THAN"; e.inputs[1].default_value = width
        nt.links.new(d.outputs[0], e.inputs[0])
        return e.outputs[0]
    b1, b2 = band(0.1, 0.006), band(-0.1, 0.006)
    both = N("ShaderNodeMath"); both.operation = "MAXIMUM"
    nt.links.new(b1, both.inputs[0]); nt.links.new(b2, both.inputs[1])
    # The stitch line along y = 0: dashes, one per stitch.
    dash = N("ShaderNodeTexWave")
    dash.wave_type = "BANDS"; dash.bands_direction = "X"; dash.wave_profile = "SAW"
    dash.inputs["Scale"].default_value = 1.0 / STITCH
    nt.links.new(mp.outputs["Vector"], dash.inputs["Vector"])
    dgt = N("ShaderNodeMath"); dgt.operation = "GREATER_THAN"; dgt.inputs[1].default_value = 0.3
    nt.links.new(dash.outputs["Fac"], dgt.inputs[0])
    ay = N("ShaderNodeMath"); ay.operation = "ABSOLUTE"
    nt.links.new(sep.outputs["Y"], ay.inputs[0])
    on = N("ShaderNodeMath"); on.operation = "LESS_THAN"; on.inputs[1].default_value = 0.004
    nt.links.new(ay.outputs[0], on.inputs[0])
    st = N("ShaderNodeMath"); st.operation = "MULTIPLY"
    nt.links.new(dgt.outputs[0], st.inputs[0]); nt.links.new(on.outputs[0], st.inputs[1])
    g = N("ShaderNodeMix"); g.data_type = "RGBA"
    nt.links.new(both.outputs[0], g.inputs["Factor"])
    nt.links.new(weave.outputs["Color"], g.inputs[6])
    g.inputs[7].default_value = (0.9, 0.62, 0.18, 1)
    t = N("ShaderNodeMix"); t.data_type = "RGBA"
    nt.links.new(st.outputs[0], t.inputs["Factor"])
    nt.links.new(g.outputs[2], t.inputs[6])
    t.inputs[7].default_value = (*thread, 1)
    lw = N("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.15
    sheen = N("ShaderNodeMix"); sheen.data_type = "RGBA"; sheen.blend_type = "SCREEN"
    nt.links.new(lw.outputs["Facing"], sheen.inputs["Factor"])
    nt.links.new(t.outputs[2], sheen.inputs[6])
    sheen.inputs[7].default_value = (0.12, 0.05, 0.2, 1)
    nt.links.new(sheen.outputs[2], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.8
    p.inputs["Sheen Weight"].default_value = 0.0
    p.inputs["Metallic"].default_value = 0.0
    # gold shines
    gm = N("ShaderNodeMath"); gm.operation = "MULTIPLY"; gm.inputs[1].default_value = 0.8
    nt.links.new(both.outputs[0], gm.inputs[0])
    nt.links.new(gm.outputs[0], p.inputs["Metallic"])
    return m, mp


# --- Room
setmat(add("plane", "Floor", (0, 0, 0), (12, 12, 1)), floor_m)
setmat(add("plane", "Wall", (0, 1.6, 3), (12, 1, 3), (math.radians(90), 0, 0)), wall_m)

# --- Table
TZ = 0.92
setmat(smooth(add("cube", "Top", (0, 0.1, TZ - 0.04), (1.25, 0.6, 0.04)), bevel=0.015), oak)
for x in (-1.1, 1.1):
    for y in (-0.38, 0.55):
        setmat(smooth(add("cube", "Leg", (x, y, TZ / 2 - 0.04), (0.05, 0.05, TZ / 2 - 0.04)), bevel=0.01), dark_oak)
setmat(smooth(add("cube", "Apron", (0, -0.45, TZ - 0.13), (1.15, 0.02, 0.06)), bevel=0.01), dark_oak)
# Gold inlay on the apron
setmat(add("cube", "Inlay", (0, -0.472, TZ - 0.13), (1.0, 0.003, 0.008)), gold)

# --- The cloth on the table, feeding left
fab = add("plane", "Cloth", (0.0, 0.0, TZ + 0.009), (0.95, 0.15, 1))
fab_m, fab_map = cloth("Runecloth", (0.05, 0.01, 0.11), (0.09, 0.022, 0.17), (0.95, 0.85, 0.55), 0)
setmat(fab, fab_m)
# Fold over the front edge
for f in range(1, FRAMES + 2):
    # the cloth steps while the needle is up, rests while it pierces
    k = (f - 1) // PERIOD
    ph = ((f - 1) % PERIOD) / PERIOD
    step = 0 if ph < 0.5 else (ph - 0.5) * 2
    fab_map.inputs["Location"].default_value[0] = (k + step) * STITCH
    fab_map.inputs["Location"].keyframe_insert("default_value", index=0, frame=f)

# --- The machine, its bed sunk flush into the table top (lacquer with gold trim)
M = TZ - 0.065
BX, BY = 0.15, 0.1
setmat(smooth(add("cube", "Bed", (BX, BY, M + 0.035), (0.42, 0.2, 0.035)), bevel=0.012), lacquer)
setmat(add("cube", "Plate", (BX - 0.2, BY - 0.1, M + 0.071), (0.07, 0.05, 0.002)), steel)
setmat(add("cube", "BedTrim", (BX, BY - 0.2, M + 0.035), (0.4, 0.002, 0.005)), gold)
setmat(smooth(add("cube", "Pillar", (BX + 0.3, BY + 0.02, M + 0.2), (0.07, 0.085, 0.14)), bevel=0.025), lacquer)
arm = add("cyl", "Arm", (BX + 0.02, BY + 0.02, M + 0.32), (0.075, 0.075, 0.33), (0, math.radians(90), 0),
          vertices=32)
setmat(smooth(arm, bevel=0.01), lacquer)
setmat(smooth(add("sphere", "Shoulder", (BX + 0.32, BY + 0.02, M + 0.33), (0.1, 0.095, 0.08), segments=32,
                  ring_count=16)), lacquer)
HX = BX - 0.24
setmat(smooth(add("cube", "Head", (HX, BY + 0.0, M + 0.27), (0.065, 0.075, 0.11)), bevel=0.025), lacquer)
for z in (0.2, 0.3):
    setmat(add("cube", "HeadTrim", (HX - 0.066, BY, M + z), (0.002, 0.06, 0.004)), gold)
for x in (-0.15, 0.05, 0.25):  # gold scroll medallions on the arm
    setmat(smooth(add("torus", "Scroll", (BX + x, BY - 0.074, M + 0.32), (1, 1, 1), (math.radians(90), 0, 0),
                      major_radius=0.03, minor_radius=0.005)), gold)
    setmat(smooth(add("sphere", "Boss", (BX + x, BY - 0.072, M + 0.32), (0.012, 0.006, 0.012))), gold)
# Needle bar, needle, presser foot
needle_root = bpy.data.objects.new("NeedleBar", None)
link(needle_root)
needle_root.location = (HX, BY - 0.1, M + 0.16)
nb = setmat(smooth(add("cyl", "Rod", (HX, BY - 0.1, M + 0.2), (0.012, 0.012, 0.06), vertices=16)), steel)
nd = setmat(smooth(add("cone", "Needle", (HX, BY - 0.1, M + 0.115), (0.004, 0.004, 0.03), (math.radians(180), 0, 0),
                       vertices=10, radius1=1, radius2=0.2, depth=1)), steel)
clamp = setmat(smooth(add("cube", "Clamp", (HX, BY - 0.1, M + 0.148), (0.016, 0.016, 0.01)), bevel=0.004), gold)
for o in (nb, nd, clamp):
    parent(o, needle_root)
setmat(smooth(add("cube", "Foot", (HX + 0.01, BY - 0.1, M + 0.078), (0.025, 0.02, 0.004)), bevel=0.003), steel)
setmat(smooth(add("cyl", "FootBar", (HX + 0.02, BY - 0.085, M + 0.15), (0.006, 0.006, 0.07), vertices=10)), steel)
for f in range(1, FRAMES + 2):
    ph = ((f - 1) % PERIOD) / PERIOD
    z = M + 0.16 - 0.05 * (0.5 + 0.5 * math.cos(ph * 2 * math.pi))  # lowest at ph 0 (pierce)
    key(needle_root, "location", f, (HX, BY - 0.1, z + 0.015))
# Hand wheel at the right, spokes, turning once per stitch
wheel = bpy.data.objects.new("Wheel", None)
link(wheel)
wheel.location = (BX + 0.4, BY + 0.02, M + 0.3)
rim = setmat(smooth(add("torus", "Rim", (BX + 0.4, BY + 0.02, M + 0.3), (1, 1, 1), (0, math.radians(90), 0),
                        major_radius=0.1, minor_radius=0.013)), gold)
hub = setmat(smooth(add("cyl", "Hub", (BX + 0.4, BY + 0.02, M + 0.3), (0.025, 0.025, 0.02), (0, math.radians(90), 0),
                        vertices=20)), gold)
parts = [rim, hub]
for i in range(6):
    a = i * math.pi / 3
    sp = setmat(smooth(add("cyl", "Spoke", (BX + 0.4, BY + 0.02 + 0.05 * math.cos(a), M + 0.3 + 0.05 * math.sin(a)),
                           (0.006, 0.006, 0.05), (a + math.pi / 2, 0, 0), vertices=8)), gold)
    parts.append(sp)
for o in parts:
    parent(o, wheel)
for f in (1, FRAMES + 1):
    key(wheel, "rotation_euler", f, -(f - 1) / PERIOD * 2 * math.pi, 0)
for fc in fcurves(wheel.animation_data.action):
    for k in fc.keyframe_points:
        k.interpolation = "LINEAR"
# Spool on its pin, turning; the thread down to the needle
spool = bpy.data.objects.new("SpoolRot", None)
link(spool)
spool.location = (BX + 0.12, BY + 0.02, M + 0.43)
setmat(smooth(add("cyl", "Pin", (BX + 0.12, BY + 0.02, M + 0.42), (0.005, 0.005, 0.06), vertices=8)), steel)
thread_m = painted("Thread", (0.5, 0.42, 0.25), (0.95, 0.88, 0.6), rough=0.6, scale=60, bump=0.6, stretch=(1, 1, 40))
core = setmat(smooth(add("cyl", "Spool", (BX + 0.12, BY + 0.02, M + 0.43), (0.028, 0.028, 0.03), vertices=24)),
              thread_m)
for z in (0.398, 0.462):
    setmat(smooth(add("cyl", "Flange", (BX + 0.12, BY + 0.02, M + z), (0.036, 0.036, 0.004), vertices=24)), dark_oak)
parent(core, spool)
for f in (1, FRAMES + 1):
    key(spool, "rotation_euler", f, (f - 1) / FRAMES * 2 * math.pi * 3, 2)
for fc in fcurves(spool.animation_data.action):
    for k in fc.keyframe_points:
        k.interpolation = "LINEAR"
curve = bpy.data.curves.new("ThreadPath", "CURVE")
curve.dimensions = "3D"
curve.bevel_depth = 0.0012
sp = curve.splines.new("BEZIER")
pts = [(BX + 0.09, BY + 0.0, M + 0.43), (BX - 0.05, BY - 0.07, M + 0.41), (HX + 0.02, BY - 0.085, M + 0.36),
       (HX, BY - 0.1, M + 0.24)]
sp.bezier_points.add(len(pts) - 1)
for bp, p in zip(sp.bezier_points, pts):
    bp.co = p
    bp.handle_left_type = bp.handle_right_type = "AUTO"
tob = bpy.data.objects.new("Thread", curve)
link(tob)
tob.data.materials.append(thread_m)

# --- Props on the table: spools, scissors, a pincushion
for i, (x, y, c) in enumerate(((0.75, 0.42, (0.6, 0.05, 0.05)), (0.86, 0.36, (0.05, 0.25, 0.6)),
                               (0.95, 0.46, (0.85, 0.6, 0.1)), (-0.8, 0.45, (0.1, 0.45, 0.15)))):
    core = painted("Spool%d" % i, tuple(v * 0.4 for v in c), c, rough=0.6, scale=60, bump=0.6, stretch=(1, 1, 40))
    setmat(smooth(add("cyl", "Sp", (x, y, TZ + 0.04), (0.032, 0.032, 0.035), vertices=24)), core)
    for z in (0.003, 0.077):
        setmat(smooth(add("cyl", "Fl", (x, y, TZ + z), (0.04, 0.04, 0.004), vertices=24)), dark_oak)
cush = setmat(smooth(add("sphere", "Cushion", (-0.72, 0.18, TZ + 0.04), (0.075, 0.075, 0.05), segments=32,
                         ring_count=16)), painted("Velvet", (0.25, 0.01, 0.02), (0.6, 0.05, 0.07), rough=0.9,
                                                    scale=30, bump=0.4, rim=(0.9, 0.3, 0.3)))
for i in range(7):
    a = i * 2 * math.pi / 7
    d = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.8)).normalized()
    base = Vector((-0.72, 0.18, TZ + 0.04)) + Vector((d.x * 0.06, d.y * 0.06, d.z * 0.04))
    setmat(add("cyl", "Pin", base + d * 0.02, (0.002, 0.002, 0.022), d.to_track_quat("Z", "Y").to_euler(),
               vertices=6), steel)
    setmat(add("sphere", "PinHead", base + d * 0.042, (0.008, 0.008, 0.008), segments=12, ring_count=6),
           [gold, painted("PH", (0.5, 0.0, 0.0), (0.9, 0.1, 0.1), rough=0.3)][i % 2])
for sgn in (-1, 1):  # scissors: two blades and gold rings
    b = setmat(smooth(add("cube", "Blade", (-0.48, -0.25, TZ + 0.008 + 0.004 * (sgn + 1)), (0.11, 0.008, 0.002)),
                      bevel=0.002), steel)
    b.rotation_euler = (0, 0, math.radians(sgn * 12 - 20))
    setmat(smooth(add("torus", "Ring", (-0.6 + 0.012 * sgn, -0.21 - 0.03 * sgn, TZ + 0.01), (1, 1, 1),
                      major_radius=0.025, minor_radius=0.005)), gold)

# --- Background: shelves with bolts of cloth lying on them, a moonlit window
for z in (1.38, 1.86):
    setmat(smooth(add("cube", "Shelf", (-0.5, 1.45, z), (1.2, 0.14, 0.022)), bevel=0.01), dark_oak)
    for x in (-1.6, 0.6):
        setmat(smooth(add("cube", "Bracket", (x, 1.5, z - 0.08), (0.02, 0.08, 0.06)), bevel=0.005), dark_oak)
cols = [(0.5, 0.05, 0.06), (0.1, 0.2, 0.55), (0.6, 0.45, 0.1), (0.2, 0.08, 0.35), (0.1, 0.35, 0.15), (0.55, 0.2, 0.05)]
for row, z in enumerate((1.38, 1.86)):
    x = -1.6
    for i in range(5):
        c = cols[(i + row * 3) % len(cols)]
        r_ = 0.075 + 0.02 * ((i + row) % 3)
        length = 0.32 + 0.06 * (i % 2)
        bolt = add("cyl", "Bolt", (x + length / 2, 1.42, z + 0.022 + r_), (r_, r_, length / 2), (0, math.radians(90), 0),
                   vertices=28)
        setmat(smooth(bolt), painted("Bolt%d%d" % (row, i), tuple(v * 0.4 for v in c), c, rough=0.8, scale=30,
                                     bump=0.4, stretch=(1, 40, 40)))
        x += length + 0.06
win = setmat(add("plane", "Window", (1.3, 1.58, 1.75), (0.35, 1, 0.5), (math.radians(90), 0, 0)),
             emissive("Moon", (0.35, 0.5, 1.0), 1.4))
setmat(add("cube", "Mullion", (1.3, 1.56, 1.75), (0.018, 0.02, 0.51)), dark_oak)
setmat(add("cube", "Transom", (1.3, 1.56, 1.75), (0.36, 0.02, 0.018)), dark_oak)
# A lantern on the table, left: the warm key
setmat(smooth(add("cyl", "Lantern", (-0.95, 0.35, TZ + 0.12), (0.06, 0.06, 0.12), vertices=6), bevel=0.005),
       painted("Glass", (0.6, 0.35, 0.1), (1, 0.7, 0.3), rough=0.1, emission=(1, 0.6, 0.2), emit=4))
setmat(smooth(add("cone", "LanternTop", (-0.95, 0.35, TZ + 0.28), (0.075, 0.075, 0.05), vertices=6)), gold)
lamp = light("POINT", (-0.95, 0.35, TZ + 0.14), 45, (1, 0.62, 0.28), 0.06)
for f in range(1, FRAMES + 2, 2):
    t = (f - 1) / FRAMES * 2 * math.pi
    key(lamp.data, "energy", f, 45 + 5 * math.sin(4 * t) + 3 * math.sin(9 * t))

light("AREA", (-1.5, -2.0, 2.8), 230, (1.0, 0.8, 0.6), 2.5, target=(0.0, 0.1, TZ + 0.2))   # warm key
light("AREA", (1.8, 2.2, 2.2), 300, (0.45, 0.55, 1.0), 1.5, target=(0.0, 0.1, TZ + 0.2))   # moon rim
light("AREA", (1.5, -2.0, 1.4), 40, (0.6, 0.65, 0.85), 2.5, target=(0.0, 0.0, TZ))        # fill
camera((0.35, -1.35, TZ + 0.62), (-0.02, 0.12, TZ + 0.18), lens=40, dof=3.2)

render(out, only, "tailoring")
