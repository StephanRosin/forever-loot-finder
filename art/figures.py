# Figures for the profession scenes: a body grown from a joint skeleton by the
# Skin modifier (one smooth, organic mesh), rigged with a matching armature and
# automatic weights. Heads, hands, hair and clothes are separate parts
# parented to bones; arms are driven by IK targets on the tools they hold.
import bpy
from mathutils import Vector, Matrix
from lib import link


def rig(name, joints, bones, mat, loc=(0, 0, 0), levels=2):
    """joints: {name: ((x, y, z), (rx, ry))} in the figure's own space (facing -y);
    bones: [(bone, head joint, tail joint, parent bone or None)] -- also the skin's edges.
    The first bone's head joint is the skin root. Returns (armature, body)."""
    off = Vector(loc)
    names = list(joints)
    index = {n: i for i, n in enumerate(names)}
    me = bpy.data.meshes.new(name)
    me.from_pydata([Vector(joints[n][0]) + off for n in names],
                   [(index[h], index[t]) for _, h, t, _ in bones], [])
    body = bpy.data.objects.new(name, me)
    link(body)
    body.modifiers.new("Skin", "SKIN")
    for n in names:
        v = me.skin_vertices[0].data[index[n]]
        v.radius = joints[n][1]
    me.skin_vertices[0].data[index[bones[0][1]]].use_root = True
    sub = body.modifiers.new("Sub", "SUBSURF")
    sub.levels = sub.render_levels = levels
    select_only(body)
    bpy.ops.object.modifier_apply(modifier="Skin")
    bpy.ops.object.modifier_apply(modifier="Sub")
    for p in body.data.polygons:
        p.use_smooth = True
    body.data.materials.append(mat)

    ad = bpy.data.armatures.new(name + "Rig")
    arm = bpy.data.objects.new(name + "Rig", ad)
    link(arm)
    select_only(arm)
    bpy.ops.object.mode_set(mode="EDIT")
    for b, h, t, par in bones:
        eb = ad.edit_bones.new(b)
        eb.head = Vector(joints[h][0]) + off
        eb.tail = Vector(joints[t][0]) + off
        if par:
            eb.parent = ad.edit_bones[par]
            eb.use_connect = (ad.edit_bones[par].tail - eb.head).length < 1e-5
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    bpy.ops.object.select_all(action="DESELECT")
    return arm, body


def select_only(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def attach(o, arm, bone):
    """Parents o to a bone, keeping it where it is (do it while the rig is in rest pose)."""
    bpy.context.view_layer.update()   # o's matrix_world may be stale (just parented to something else)
    mw = o.matrix_world.copy()
    o.parent = arm
    o.parent_type = "BONE"
    o.parent_bone = bone
    bpy.context.view_layer.update()
    o.matrix_world = mw
    return o


def ik(arm, bone, target, chain=2, pole=None, pole_angle=0.0):
    c = arm.pose.bones[bone].constraints.new("IK")
    c.target = target
    c.chain_count = chain
    if pole:
        c.pole_target = pole
        c.pole_angle = pole_angle
    return c


def target(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    link(e)
    e.empty_display_size = 0.05
    e.location = loc
    if parent:  # loc is then in the parent's own space (a grip on a tool), whatever pose it is keyed in
        e.parent = parent
        e.matrix_parent_inverse = Matrix.Identity(4)
    return e


def pose(arm, bone, frame, euler):
    pb = arm.pose.bones[bone]
    pb.rotation_euler = euler
    pb.keyframe_insert("rotation_euler", frame=frame)


def shaped(name, loc, size, width, depth=None, rot=(0, 0, 0), segments=40, rings=32):
    """A sphere reshaped ring by ring: width(t) and depth(t) scale x and y at height
    t (1 top .. -1 bottom). Beards, moustaches, manes: organic forms subsurf would melt."""
    import math
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    o = bpy.context.active_object
    o.name = name
    sx, sy, sz = size
    for v in o.data.vertices:
        t = max(-1.0, min(1.0, v.co.z))
        r = math.hypot(v.co.x, v.co.y)
        if r > 1e-6:  # rings to a capsule first (the sphere's own taper would make every shape an egg)
            k = (1 - abs(t) ** 6) ** 0.5 / r
            v.co.x *= k
            v.co.y *= k
        v.co.x *= sx * width(t)
        v.co.y *= sy * (depth(t) if depth else 1.0)
        v.co.z *= sz
    o.rotation_euler = rot
    for p in o.data.polygons:
        p.use_smooth = True
    return o
