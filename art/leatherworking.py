# Leatherworking: a hide laced into a log stretching frame; a two-handled
# fleshing knife draws down across it twice a loop, shavings fall.
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Matrix
from lib import *

out, only = args()
s = reset()
random.seed(5)
world((0.02, 0.018, 0.02), (0.03, 0.02, 0.012), 0.5)
glow(threshold=1.0, size=6)

# --- Materials
log_m = painted("Log", (0.035, 0.017, 0.008), (0.14, 0.075, 0.035), rough=0.85, scale=4, bump=0.9,
                rim=(0.16, 0.09, 0.04), stretch=(9, 9, 0.6))
plank = wood("Plank", (0.04, 0.02, 0.01), (0.15, 0.075, 0.035), scale=1.2)
rope = painted("Rope", (0.12, 0.08, 0.035), (0.32, 0.23, 0.12), rough=0.9, scale=50, bump=0.8, stretch=(1, 1, 30))
steel = painted("Steel", (0.25, 0.26, 0.29), (0.6, 0.62, 0.66), rough=0.25, metal=1.0, scale=12,
                rim=(0.4, 0.45, 0.6), bump=0.03)
handle_m = wood("Handle", (0.12, 0.05, 0.02), (0.4, 0.2, 0.08), scale=6)
dirt = flagstone("Dirt", (0.025, 0.018, 0.012), (0.08, 0.055, 0.035), scale=3.5, seam=(0.02, 0.012, 0.008), rough=0.95)


def hide_material(name):
    """The flesh side of a hide: tan, blotchy, darker towards the ragged edge."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    N = nt.nodes.new
    tc = N("ShaderNodeTexCoord")
    noise = N("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 5; noise.inputs["Detail"].default_value = 9
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    ramp = N("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.3
    ramp.color_ramp.elements[0].color = (0.2, 0.09, 0.035, 1)
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = (0.62, 0.4, 0.2, 1)
    nt.links.new(noise.outputs["Fac"], ramp.inputs[0])
    ln = N("ShaderNodeVectorMath"); ln.operation = "LENGTH"
    nt.links.new(tc.outputs["Object"], ln.inputs[0])
    edge = N("ShaderNodeMapRange")
    edge.inputs["From Min"].default_value = 0.25
    edge.inputs["From Max"].default_value = 0.52
    nt.links.new(ln.outputs["Value"], edge.inputs["Value"])
    mix = N("ShaderNodeMix"); mix.data_type = "RGBA"; mix.clamp_factor = True
    nt.links.new(edge.outputs["Result"], mix.inputs["Factor"])
    nt.links.new(ramp.outputs[0], mix.inputs[6])
    mix.inputs[7].default_value = (0.12, 0.05, 0.02, 1)
    lw = N("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.3
    rim = N("ShaderNodeMix"); rim.data_type = "RGBA"; rim.blend_type = "SCREEN"
    nt.links.new(lw.outputs["Facing"], rim.inputs["Factor"])
    nt.links.new(mix.outputs[2], rim.inputs[6])
    rim.inputs[7].default_value = (0.18, 0.1, 0.05, 1)
    nt.links.new(rim.outputs[2], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.65
    b = N("ShaderNodeBump"); b.inputs["Strength"].default_value = 0.5
    n2 = N("ShaderNodeTexNoise"); n2.inputs["Scale"].default_value = 40; n2.inputs["Detail"].default_value = 6
    nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
    nt.links.new(n2.outputs["Fac"], b.inputs["Height"])
    nt.links.new(b.outputs["Normal"], p.inputs["Normal"])
    return m


def fur(name, dark, light):
    return painted(name, dark, light, rough=0.95, scale=60, detail=12, bump=1.2, stretch=(1, 1, 6),
                   rim=tuple(min(1, v * 1.5) for v in light))


# --- Room
setmat(add("plane", "Floor", (0, 0, 0), (12, 12, 1)), dirt)
setmat(add("plane", "Wall", (0, 2.2, 3), (12, 1, 3), (math.radians(90), 0, 0)), plank)
for x in range(-6, 7):  # plank seams
    setmat(add("cube", "Seam", (x * 0.32, 2.19, 1.5), (0.008, 0.005, 1.5)), emissive("SeamM", (0, 0, 0), 0))

# --- The rack: everything on it is its child, tilted back a little
rack = bpy.data.objects.new("Rack", None)
link(rack)
rack.location = (0, 0.35, 1.05)
rack.rotation_euler = (math.radians(-10), 0, 0)
bpy.context.view_layer.update()
R = rack.matrix_world


def on_rack(o):
    o.matrix_world = R @ o.matrix_world
    o.parent = rack
    o.matrix_parent_inverse = R.inverted()
    return o


FX, FZ = 0.66, 0.6   # inner half sizes of the frame
for x in (-FX - 0.04, FX + 0.04):  # uprights, longer than the frame (feet)
    on_rack(setmat(smooth(add("cyl", "Post", (x, 0, -0.08), (0.05, 0.05, 0.86), vertices=20), bevel=0.01), log_m))
for z in (-FZ - 0.04, FZ + 0.04):
    on_rack(setmat(smooth(add("cyl", "Bar", (0, 0, z), (0.045, 0.045, 0.82), (0, math.radians(90), 0), vertices=20),
                          bevel=0.01), log_m))
for x in (-FX - 0.04, FX + 0.04):  # lashed corners
    for z in (-FZ - 0.04, FZ + 0.04):
        for k in range(4):
            on_rack(setmat(smooth(add("torus", "Lash", (x, 0, z + (k - 1.5) * 0.022), (1, 1, 1),
                                      (0, 0, math.radians(45 * k)), major_radius=0.058, minor_radius=0.009)), rope))
# Props for the posts at the back (it leans on them)
for x in (-FX - 0.04, FX + 0.04):
    p = setmat(smooth(add("cyl", "Prop", (x, 0.45, 0.45), (0.035, 0.035, 0.55), (math.radians(-30), 0, 0),
                          vertices=14)), log_m)

# The hide: a grid trimmed to a stretched-skin outline, gently bulged
OUTLINE = [(0, 0.5), (0.12, 0.43), (0.21, 0.52), (0.33, 0.47), (0.31, 0.33), (0.47, 0.27), (0.52, 0.08),
           (0.43, -0.1), (0.5, -0.31), (0.37, -0.44), (0.23, -0.37), (0.1, -0.47), (0, -0.41)]
OUTLINE = OUTLINE + [(-x, z) for x, z in reversed(OUTLINE[1:-1])]


def outline_smooth(pts, per=8):
    """Catmull-Rom through the outline: a soft, ragged skin edge."""
    out, n = [], len(pts)
    for i in range(n):
        p0, p1, p2, p3 = (Vector((*pts[(i + k) % n], 0)) for k in (-1, 0, 1, 2))
        for k in range(per):
            t = k / per
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    return out


def hide_mesh(name, sx, sz, bulge):
    """The outline as a thin slab, remeshed to even quads (no fan triangles to
    streak the shading), then bulged like a skin pulled tight."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [bm.verts.new((v.x * sx, 0, v.y * sz)) for v in outline_smooth(OUTLINE)]
    face = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.y += 0.006
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    m = o.modifiers.new("Remesh", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = 0.008
    bpy.ops.object.modifier_apply(modifier=m.name)
    o.select_set(False)
    for v in o.data.vertices:
        r = (v.co.x / sx) ** 2 / 0.3 + (v.co.z / sz) ** 2 / 0.28
        v.co.y -= bulge * max(0.0, 1 - r)
    return smooth(o)


hide = setmat(hide_mesh("Hide", 1.18, 1.12, 0.016), hide_material("HideM"))
fr = setmat(hide_mesh("HideFur", 1.2, 1.14, 0.012), fur("Fur", (0.06, 0.035, 0.02), (0.3, 0.2, 0.11)))
fr.location.y = 0.008
on_rack(hide)
on_rack(fr)
# Lacing: cords from the hide's edge to the nearest frame log
for i, (x, z) in enumerate(OUTLINE):
    if i % 2:
        continue
    a = Vector((x * 1.18 * 0.97, 0, z * 1.12 * 0.97))
    # nearest frame side
    cands = [Vector((-FX, 0, a.z)), Vector((FX, 0, a.z)), Vector((a.x, 0, -FZ)), Vector((a.x, 0, FZ))]
    b = min(cands, key=lambda c: (c - a).length)
    cu = bpy.data.curves.new("Cord", "CURVE"); cu.dimensions = "3D"; cu.bevel_depth = 0.0045
    sp = cu.splines.new("POLY"); sp.points.add(1)
    sp.points[0].co = (*a, 1); sp.points[1].co = (*b, 1)
    co = bpy.data.objects.new("Cord", cu); link(co); co.data.materials.append(rope)
    on_rack(co)
    on_rack(setmat(smooth(add("torus", "Knot", tuple(b), (1, 1, 1), (math.radians(90) if b.z == a.z else 0, 0,
                                                                     math.radians(90) if b.z != a.z else 0),
                              major_radius=0.05, minor_radius=0.01)), rope))

# --- The fleshing knife: a curved blade between two handles
knife = bpy.data.objects.new("Knife", None)
link(knife)
blade_pts = [(-0.2, 0.0), (-0.1, -0.035), (0.0, -0.045), (0.1, -0.035), (0.2, 0.0), (0.2, 0.03), (0.1, 0.0),
             (0.0, -0.01), (-0.1, 0.0), (-0.2, 0.03)]
blade = profile("Blade", blade_pts, 0.006)
setmat(smooth(blade, bevel=0.002), steel)
for sx in (-1, 1):
    h = setmat(smooth(add("cyl", "KHandle", (sx * 0.29, -0.03, 0.04), (0.026, 0.026, 0.1),
                          (0, math.radians(90 + sx * 25), 0), vertices=16)), handle_m)
    ferr = setmat(smooth(add("cyl", "Ferrule", (sx * 0.215, -0.012, 0.025), (0.02, 0.02, 0.015),
                             (0, math.radians(90 + sx * 25), 0), vertices=16)),
                  painted("Brass", (0.3, 0.17, 0.04), (0.7, 0.48, 0.15), rough=0.35, metal=1, rim=(0.9, 0.7, 0.3)))
    h.parent = knife; ferr.parent = knife
blade.parent = knife
knife.parent = rack
knife.scale = (1.45, 1.45, 1.45)

# Two draws a loop (period 20): down along the hide pressing, back up lifted.
def knife_at(f):
    base = 0 if f <= 20 else 20
    ph = (f - 1 - base) / 20.0
    x = -0.14 if base == 0 else 0.16
    if ph < 0.6:                      # the draw: top to bottom, on the surface
        t = ph / 0.6
        t = t * t * (3 - 2 * t)
        return Vector((x, -0.06, 0.4 - 0.75 * t)), math.radians(-35), True
    t = (ph - 0.6) / 0.4              # lifted and back up, to the next column
    t = t * t * (3 - 2 * t)
    nx = 0.16 if base == 0 else -0.14
    lift = math.sin(t * math.pi)
    return Vector((x + (nx - x) * t, -0.06 - 0.16 * lift, -0.35 + 0.75 * t)), math.radians(-35 + 25 * lift), False

contact = []
for f in range(1, FRAMES + 2):
    p, ang, on = knife_at(((f - 1) % FRAMES) + 1)
    key(knife, "location", f, p)
    key(knife, "rotation_euler", f, ang, 0)
    if on:
        contact.append((f, p))

# Shavings: little curls peel off at the edge during the draw and fall.
shave_m = painted("Shaving", (0.45, 0.28, 0.14), (0.8, 0.6, 0.38), rough=0.7, scale=30, bump=0.3)
bpy.context.view_layer.update()
for f, p in contact:
    if f % 2 or f > FRAMES - 8:
        continue
    for n in range(2):
        o = setmat(smooth(add("torus", "Curl", (0, 0, 0), (1, 1, 0.6), major_radius=0.012, minor_radius=0.004,
                              major_segments=12, minor_segments=6)), shave_m)
        start = R @ (p + Vector((random.uniform(-0.12, 0.12), -0.02, -0.03)))
        vx, vy = random.uniform(-0.01, 0.01), random.uniform(-0.03, -0.01)
        key(o, "scale", f - 1, (0, 0, 0))
        for t in range(0, 9):
            q = start + Vector((vx * t, vy * t, -0.004 * t * t))
            q.z = max(q.z, 0.01)
            key(o, "location", f + t, q)
            key(o, "rotation_euler", f + t, (t * 0.6 + n, t * 0.4, 0))
            k = 1.0 if t < 6 else (8 - t) / 2.0
            key(o, "scale", f + t, (k, k, k))
        key(o, "scale", f + 9, (0, 0, 0))

# --- Background: pelts on pegs, a tanning vat, a workbench with tools
for i, (x, c) in enumerate(((-1.55, ((0.05, 0.03, 0.02), (0.28, 0.17, 0.09))), (-0.95, ((0.07, 0.06, 0.055), (0.4, 0.38, 0.36))),
                            (1.0, ((0.08, 0.035, 0.015), (0.45, 0.2, 0.08))), (1.6, ((0.03, 0.025, 0.02), (0.2, 0.16, 0.12))))):
    pelt = setmat(hide_mesh("Pelt%d" % i, 0.55, 0.62, 0.02), fur("PeltM%d" % i, *c))
    pelt.location = (x, 2.12, 1.6)
    pelt.rotation_euler = (0, math.radians(random.uniform(-8, 8)), 0)
    setmat(smooth(add("cyl", "Peg", (x, 2.1, 1.97), (0.02, 0.02, 0.06), (math.radians(90), 0, 0), vertices=10)), handle_m)
vat = setmat(smooth(add("cyl", "Vat", (-1.35, 1.3, 0.38), (0.4, 0.4, 0.38), vertices=28), bevel=0.03), plank)
for z in (0.1, 0.4, 0.68):
    setmat(smooth(add("torus", "Hoop", (-1.35, 1.3, z), (1, 1, 1), major_radius=0.41, minor_radius=0.018)), steel)
setmat(add("cyl", "Tan", (-1.35, 1.3, 0.73), (0.37, 0.37, 0.01), vertices=28),
       painted("TanM", (0.08, 0.035, 0.01), (0.22, 0.1, 0.03), rough=0.1, bump=0.05))
setmat(smooth(add("cube", "Bench", (1.35, 1.2, 0.75), (0.55, 0.3, 0.035)), bevel=0.01), plank)
for x in (0.9, 1.8):
    setmat(smooth(add("cube", "BLeg", (x, 1.2, 0.37), (0.04, 0.25, 0.37)), bevel=0.01), plank)
mallet = setmat(smooth(add("cyl", "Mallet", (1.2, 1.1, 0.86), (0.07, 0.07, 0.09), (0, math.radians(90), 0),
                           vertices=20), bevel=0.01), handle_m)
setmat(smooth(add("cyl", "MHandle", (1.2, 0.95, 0.81), (0.018, 0.018, 0.16), (math.radians(90), 0, 0), vertices=12)),
       handle_m)
for i, c in enumerate(((0.35, 0.16, 0.06), (0.2, 0.09, 0.04))):  # rolled leather
    setmat(smooth(add("cyl", "Roll", (1.6, 1.15 + 0.13 * i, 0.84), (0.055, 0.055, 0.2), (0, math.radians(90), 0),
                      vertices=20)), painted("Roll%d" % i, tuple(v * 0.5 for v in c), c, rough=0.6, scale=20, bump=0.4))

# --- Light and camera
lantern = setmat(smooth(add("cyl", "Lantern", (-0.95, 0.6, 1.95), (0.06, 0.06, 0.1), vertices=6), bevel=0.005),
                 painted("Glass", (0.6, 0.35, 0.1), (1, 0.7, 0.3), rough=0.1, emission=(1, 0.6, 0.2), emit=1.5))
setmat(smooth(add("cyl", "Hook", (-0.95, 0.6, 2.2), (0.006, 0.006, 0.15), vertices=8)), steel)
lamp = light("POINT", (-0.95, 0.45, 1.95), 120, (1, 0.6, 0.26), 0.08)
for f in range(1, FRAMES + 2, 2):
    t = (f - 1) / FRAMES * 2 * math.pi
    key(lamp.data, "energy", f, 120 + 12 * math.sin(4 * t) + 6 * math.sin(11 * t))
light("AREA", (-1.6, -2.4, 3.0), 170, (1.0, 0.8, 0.58), 2.0, target=(0, 0.3, 1.0))   # warm key
light("AREA", (2.2, 1.8, 2.4), 220, (0.45, 0.55, 1.0), 1.5, target=(0, 0.3, 1.1))    # cool rim
light("AREA", (2.0, -2.5, 1.2), 50, (0.6, 0.65, 0.85), 2.5, target=(0, 0.3, 0.9))    # fill
camera((0.6, -2.9, 1.4), (0.0, 0.3, 0.98), lens=36, dof=4.5)

render(out, only, "leatherworking")
