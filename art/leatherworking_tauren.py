# Leatherworking with a tauren: behind a heavy bench a tauren sews a piece of
# leather, the sinew drawn out in a wide arc twice a loop; a hide on its rack behind.
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Matrix
from lib import *
from figures import rig, attach, ik, target, pose, shaped

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
rack.location = (-0.75, 1.55, 1.05)
rack.rotation_euler = (0, 0, math.radians(12))
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

# --- The work bench in front: a heavy plank on trestles, the leather piece being sewn, tools
BZ = 0.95
plank = wood("BenchPlank", (0.025, 0.012, 0.006), (0.1, 0.05, 0.022), scale=1.2, rim=(0.18, 0.1, 0.05))
setmat(smooth(add("cube", "WBTop", (0, -0.6, BZ - 0.04), (0.85, 0.3, 0.04)), bevel=0.012), plank)
for x in (-0.7, 0.7):
    setmat(smooth(add("cube", "Trestle", (x, -0.6, (BZ - 0.08) / 2), (0.05, 0.26, (BZ - 0.08) / 2)), bevel=0.01), plank)
work = setmat(smooth(add("cube", "Work", (0.0, -0.62, BZ + 0.006), (0.26, 0.13, 0.006)), bevel=0.004),
              painted("WorkLeather", (0.12, 0.05, 0.02), (0.42, 0.22, 0.1), rough=0.55, scale=18, bump=0.5,
                      rim=(0.55, 0.32, 0.16)))
SEAM_Y = -0.56
thread_m = painted("Thread", (0.5, 0.42, 0.3), (0.85, 0.78, 0.6), rough=0.7, scale=40)
for k in range(9):  # the stitches already done, left of the needle
    setmat(add("cube", "Stitch", (-0.2 + 0.03 * k, SEAM_Y, BZ + 0.013), (0.009, 0.0025, 0.002)), thread_m)
for x, y, r in ((0.5, -0.5, 0.06), (0.62, -0.68, 0.045)):  # spools of sinew
    setmat(smooth(add("cyl", "Spool", (x, y, BZ + 0.05), (r, r, 0.05), vertices=20)), thread_m)
setmat(smooth(add("cyl", "Awl", (-0.45, -0.7, BZ + 0.015), (0.012, 0.012, 0.09), (0, math.radians(90), 0.3), vertices=10)),
       handle_m)

# --- The tauren (his own make: a horned bull's head, broad muzzle, a nose ring, a braided mane,
# brown fur, a leather vest), standing behind the bench
TX, TY = 0.0, -0.05
fur_body = fur("TFur", (0.04, 0.014, 0.006), (0.22, 0.09, 0.035))
fur_head = fur("THead", (0.045, 0.016, 0.007), (0.25, 0.1, 0.04))
mane = painted("Mane", (0.015, 0.01, 0.008), (0.1, 0.06, 0.035), rough=0.7, scale=60, detail=12, bump=1.4,
               stretch=(1, 1, 22), rim=(0.35, 0.22, 0.12))
muzzle_m = painted("Muzzle", (0.06, 0.035, 0.03), (0.24, 0.15, 0.12), rough=0.4, scale=12, bump=0.2, rim=(0.45, 0.3, 0.25))
horn_m = painted("Horn", (0.3, 0.25, 0.18), (0.85, 0.8, 0.68), rough=0.4, scale=8, bump=0.3, stretch=(1, 1, 8),
                 rim=(1.0, 0.95, 0.85))
vest = painted("Vest", (0.012, 0.006, 0.003), (0.06, 0.03, 0.014), rough=0.35, scale=25, bump=0.4, rim=(0.5, 0.3, 0.15))
gold = painted("TGold", (0.35, 0.18, 0.03), (0.85, 0.6, 0.18), rough=0.3, metal=1.0, scale=10, rim=(1.0, 0.8, 0.35))
bead = painted("Bead", (0.02, 0.1, 0.12), (0.1, 0.5, 0.55), rough=0.3)
eye_m = painted("TEye", (0.005, 0.004, 0.004), (0.03, 0.02, 0.02), rough=0.08)
J = {
    "pelvis": ((0, 0, 1.05), (0.32, 0.26)), "belly": ((0, -0.03, 1.35), (0.38, 0.3)),
    "chest": ((0, 0, 1.7), (0.5, 0.35)), "neck": ((0, -0.05, 1.98), (0.22, 0.2)), "top": ((0, -0.12, 2.15), (0.12, 0.12)),
}
for sx, sd in ((1, "L"), (-1, "R")):
    J.update({"sh" + sd: ((0.5 * sx, 0, 1.85), (0.22, 0.22)), "el" + sd: ((0.64 * sx, -0.25, 1.48), (0.15, 0.15)),
              "wr" + sd: ((0.32 * sx, -0.5, 1.12), (0.11, 0.11)),
              "hip" + sd: ((0.18 * sx, 0, 1.0), (0.22, 0.22)), "kn" + sd: ((0.22 * sx, -0.05, 0.55), (0.18, 0.18)),
              "an" + sd: ((0.22 * sx, 0.05, 0.15), (0.12, 0.12))})
B = [("spine", "pelvis", "belly", None), ("chest", "belly", "chest", "spine"), ("neck", "chest", "neck", "chest"),
     ("head", "neck", "top", "neck")]
for sd in "LR":
    B += [("clav." + sd, "chest", "sh" + sd, "chest"), ("upper." + sd, "sh" + sd, "el" + sd, "clav." + sd),
          ("fore." + sd, "el" + sd, "wr" + sd, "upper." + sd),
          ("hip." + sd, "pelvis", "hip" + sd, "spine"), ("thigh." + sd, "hip" + sd, "kn" + sd, "hip." + sd),
          ("shin." + sd, "kn" + sd, "an" + sd, "thigh." + sd)]
arm, body = rig("Tauren", J, B, fur_body, loc=(TX, TY, 0))
body.data.materials.append(vest)
for p in body.data.polygons:  # the vest over chest and belly, open down the middle
    c = p.center
    if 1.15 < c.z < 1.95 and abs(c.x - TX) < 0.46 and abs(c.x - TX) > 0.06:
        p.material_index = 1


def T(x, y, z):
    return (TX + x, TY + y, z)


parts = [setmat(smooth(add("sphere", "Skull", T(0, -0.15, 2.22), (0.2, 0.2, 0.19), segments=32, ring_count=16)), fur_head),
         setmat(shaped("Muzzle", T(0, -0.37, 2.1), (0.15, 0.14, 0.11), width=lambda t: 0.85 + 0.15 * t), muzzle_m),
         setmat(smooth(add("sphere", "Brow", T(0, -0.29, 2.3), (0.19, 0.08, 0.06), segments=24, ring_count=12)), fur_head),
         setmat(smooth(add("torus", "NoseRing", T(0, -0.5, 2.05), (1, 1, 1), (math.radians(90), 0, 0), major_radius=0.04,
                           minor_radius=0.009)), gold)]
for sx in (1, -1):
    parts += [setmat(smooth(add("sphere", "Nostril", T(0.05 * sx, -0.505, 2.13), (0.025, 0.012, 0.018), segments=12,
                                ring_count=6)), eye_m),
              setmat(smooth(add("sphere", "Eye", T(0.12 * sx, -0.31, 2.25), (0.026, 0.016, 0.022), segments=12,
                                ring_count=6)), eye_m),
              setmat(shaped("Ear", T(0.27 * sx, -0.12, 2.24), (0.1, 0.04, 0.045), width=lambda t: 1.0,
                            rot=(0, math.radians(-15 * sx), 0)), fur_head)]
    # horns: an arc out and up from the brow, tapering
    for k in range(10):
        t = k / 9
        p = T(sx * (0.15 + 0.3 * t), -0.14 + 0.03 * t, 2.34 + 0.26 * math.sin(t * 1.4) - 0.06 * t)
        r = 0.058 * (1 - 0.82 * t)
        parts.append(setmat(smooth(add("sphere", "Horn", p, (r, r, r), segments=16, ring_count=8)), horn_m))
    parts.append(setmat(smooth(add("torus", "HornBand", T(sx * 0.2, -0.135, 2.39), (1, 1, 1), (0, math.radians(90 - 35 * sx), 0),
                                   major_radius=0.05, minor_radius=0.012)), gold))
    for k in range(5):  # a braid behind each ear, beads at the end
        parts.append(setmat(smooth(add("sphere", "Braid", T(0.23 * sx, -0.04, 2.1 - 0.075 * k), (0.035, 0.035, 0.045),
                                       segments=12, ring_count=8)), mane))
    parts.append(setmat(smooth(add("sphere", "BeadB", T(0.23 * sx, -0.04, 1.7), (0.03, 0.03, 0.03), segments=12,
                                   ring_count=6)), bead))
for k in range(9):  # the mane over the crown and down the back of the neck
    a = (k - 4) * 0.22
    parts.append(setmat(shaped("ManeLock", T(0.12 * math.sin(a), 0.02 + 0.04 * math.cos(a), 2.25 - 0.02 * abs(k - 4)),
                               (0.06, 0.05, 0.2), width=lambda t: 0.4 + 0.6 * (t + 1) / 2, segments=12, rings=10,
                               rot=(math.radians(25), a, 0)), mane))
parts.append(setmat(shaped("ChinTuft", T(0, -0.36, 1.98), (0.05, 0.04, 0.09), width=lambda t: 0.3 + 0.7 * (t + 1) / 2), mane))
for o in parts:
    attach(o, arm, "head")
for sx, sd in ((1, "L"), (-1, "R")):
    wr = Vector(J["wr" + sd][0]) + Vector((TX, TY, 0))
    el = Vector(J["el" + sd][0]) + Vector((TX, TY, 0))
    d = (wr - el).normalized()
    hand = setmat(smooth(add("sphere", "Hand", wr + d * 0.08, (0.09, 0.11, 0.07), segments=20, ring_count=10)), muzzle_m)
    brace = setmat(smooth(add("cyl", "Bracer", el + (wr - el) * 0.7, (0.135, 0.135, 0.09), vertices=20)), vest)
    brace.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    for o in (hand, brace):
        attach(o, arm, "fore." + sd)
    pad = setmat(shaped("Pauldron", T(0.52 * sx, 0, 1.97), (0.22, 0.24, 0.12), width=lambda t: 1.0,
                        rot=(0, math.radians(-25 * sx), 0)), vest)
    attach(pad, arm, "clav." + sd)
belt = setmat(smooth(add("torus", "TBelt", T(0, -0.03, 1.2), (1, 0.82, 1), major_radius=0.39, minor_radius=0.035)), vest)
attach(belt, arm, "spine")
attach(setmat(smooth(add("cube", "TBuckle", T(0, -0.33, 1.2), (0.06, 0.02, 0.05)), bevel=0.01), gold), arm, "spine")

# --- Sewing: the left hand holds the leather; the right pushes the needle down through the seam,
# then draws the sinew up and out in a wide arc. Two stitches a loop.
S0 = Vector((0.04, SEAM_Y, BZ + 0.012))
hold = target("Hold", (-0.16, -0.6, BZ + 0.06))
ik(arm, "fore.L" if False else "fore.R", hold)       # his right hand is the camera's left
pull = target("Pull", S0)
ik(arm, "fore.L", pull)
needle = setmat(smooth(add("cyl", "Needle", (0, 0, -0.03), (0.004, 0.004, 0.06), vertices=8)), steel)
needle.parent = pull
thread = setmat(smooth(add("cyl", "Sinew", (0, 0, 0.5), (0.006, 0.006, 0.5), vertices=8)), thread_m)
OUT = Vector((0.55, -0.42, BZ + 0.55))


def hand_at(ph):
    if ph < 0.25:                    # down onto the seam and through
        t = ph / 0.25
        return S0 + Vector((0.02 * (1 - t), 0, 0.12 * (1 - t) + 0.02)), True
    if ph < 0.65:                    # the long draw up and out
        t = (ph - 0.25) / 0.4
        t = 1 - (1 - t) ** 2
        return S0.lerp(OUT, t) + Vector((0, 0, 0.12 * math.sin(t * math.pi))), True
    t = (ph - 0.65) / 0.35           # back over the seam, the sinew slack
    t = t * t * (3 - 2 * t)
    return OUT.lerp(S0 + Vector((0.02, 0, 0.14)), t), False


for f in range(0, FRAMES + 2):
    ph = (((f - 1) % 20) + 20) % 20 / 20
    p, taut = hand_at(ph)
    key(pull, "location", f, p)
    key(pull, "rotation_euler", f, (math.radians(-20 if taut else 10), 0, 0))
    d = p - S0
    thread.location = S0
    thread.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    thread.scale = (1, 1, max(d.length, 0.001))
    for path in ("location", "rotation_euler", "scale"):
        thread.keyframe_insert(path, frame=f)
    t = (f - 1) / FRAMES
    pose(arm, "chest", f, (math.radians(8 + 1.5 * math.sin(t * 4 * math.pi)), 0, 0))
    pose(arm, "neck", f, (math.radians(14), 0, math.radians(8 * math.sin(t * 4 * math.pi + 1))))
# the thread mesh runs -0.5..0.5 about its origin: shift it to 0..1 so the origin is its start at the seam
for v in thread.data.vertices:
    v.co.z += 0.5

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
light("AREA", (-1.6, -2.4, 3.0), 110, (1.0, 0.8, 0.58), 2.0, target=(0, 0.3, 1.0))   # warm key
light("AREA", (2.2, 1.8, 2.4), 220, (0.45, 0.55, 1.0), 1.5, target=(0, 0.3, 1.1))    # cool rim
light("AREA", (2.0, -2.5, 1.2), 50, (0.6, 0.65, 0.85), 2.5, target=(0, 0.3, 0.9))    # fill
camera((0.55, -3.3, 1.95), (0.0, -0.1, 1.55), lens=38, dof=4.5)

render(out, only, "leatherworking_tauren")
