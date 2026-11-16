# Shared Blender helpers for the profession animations (Blender 5.x, run headless:
#   blender -b --factory-startup -P art/<scene>.py -- <outdir> [frame]).
# Everything is modelled and textured here from primitives and procedural
# shaders: no outside art. The look aims at WoW's: chunky shapes, saturated
# painted colours, warm key light, cool rim light, glow.
import bpy, math, sys, os, random
from mathutils import Vector

FRAMES = 40            # one loop; the addon plays it at 15 frames a second
W, H = 512, 384        # one frame; 20 frames to a 2048 x 2048 sheet


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = a[0] if a else "/tmp/claude-1000/art"
    only = int(a[1]) if len(a) > 1 else None
    return out, only


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.frame_start, s.frame_end = 1, FRAMES
    s.render.fps = 15
    s.render.resolution_x, s.render.resolution_y, s.render.resolution_percentage = W, H, 100
    s.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "HIP"
    prefs.get_devices()
    for d in prefs.devices:
        d.use = d.type == "HIP"
    s.cycles.device = "GPU"
    s.cycles.samples = 160
    s.cycles.use_denoising = True
    s.cycles.max_bounces = 6
    s.render.use_motion_blur = True
    s.render.motion_blur_shutter = 0.45
    s.view_settings.view_transform = "AgX"
    for look in ("AgX - Punchy", "Punchy"):
        try:
            s.view_settings.look = look
            break
        except TypeError:
            pass
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGB"
    s.render.film_transparent = False
    return s


def world(top, bottom, strength=1.0):
    w = bpy.data.worlds.new("World")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes["Background"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*bottom, 1)
    ramp.color_ramp.elements[1].color = (*top, 1)
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength


def glow(threshold=0.9, size=7, mix=0.0):
    """Bloom over the render: the WoW glow on fire, sparks and magic."""
    s = bpy.context.scene
    tree = bpy.data.node_groups.new("Compositing", "CompositorNodeTree")
    s.compositing_node_group = tree
    tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    rl = tree.nodes.new("CompositorNodeRLayers")
    gl = tree.nodes.new("CompositorNodeGlare")
    out = tree.nodes.new("NodeGroupOutput")
    gl.inputs["Type"].default_value = "Bloom"
    gl.inputs["Quality"].default_value = "High"
    gl.inputs["Threshold"].default_value = threshold
    gl.inputs["Size"].default_value = min(1.0, size / 9.0)
    gl.inputs["Strength"].default_value = 0.8
    tree.links.new(rl.outputs["Image"], gl.inputs["Image"])
    tree.links.new(gl.outputs["Image"], out.inputs[0])


def camera(loc, target, lens=50, dof=None):
    cam = bpy.data.cameras.new("Cam")
    cam.lens = lens
    o = bpy.data.objects.new("Cam", cam)
    bpy.context.scene.collection.objects.link(o)
    bpy.context.scene.camera = o
    o.location = loc
    look(o, target)
    if dof:
        cam.dof.use_dof = True
        cam.dof.focus_distance = (Vector(target) - Vector(loc)).length
        cam.dof.aperture_fstop = dof
    return o


def look(o, target):
    d = Vector(target) - o.location
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def light(kind, loc, energy, color=(1, 1, 1), size=1.0, target=None, spot=None):
    l = bpy.data.lights.new(kind + "L", kind)
    l.energy = energy
    l.color = color
    if kind == "AREA":
        l.size = size
    elif kind in ("POINT", "SPOT"):
        l.shadow_soft_size = size
    if spot and kind == "SPOT":
        l.spot_size = spot
        l.spot_blend = 0.6
    o = bpy.data.objects.new(kind + "L", l)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    if target:
        look(o, target)
    return o


def link(o):
    bpy.context.scene.collection.objects.link(o)
    return o


def smooth(o, bevel=None, segments=3, subsurf=0, angle=40):
    if bevel:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = segments
        m.limit_method = "ANGLE"
    if subsurf:
        m = o.modifiers.new("Sub", "SUBSURF")
        m.levels = m.render_levels = subsurf
    for p in o.data.polygons:
        p.use_smooth = True
    try:
        o.modifiers.new("Smooth", "SMOOTH_BY_ANGLE")
    except Exception:
        pass
    return o


def add(kind, name, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), **kw):
    ops = {"cube": bpy.ops.mesh.primitive_cube_add, "cyl": bpy.ops.mesh.primitive_cylinder_add,
           "cone": bpy.ops.mesh.primitive_cone_add, "sphere": bpy.ops.mesh.primitive_uv_sphere_add,
           "ico": bpy.ops.mesh.primitive_ico_sphere_add, "torus": bpy.ops.mesh.primitive_torus_add,
           "plane": bpy.ops.mesh.primitive_plane_add}
    ops[kind](location=loc, rotation=rot, **kw)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o


def parent(child, par):
    child.parent = par
    child.matrix_parent_inverse = par.matrix_world.inverted()


# --- Materials -------------------------------------------------------------

def _principled(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    return m, nt, p


def painted(name, dark, light, rough=0.6, metal=0.0, scale=6.0, detail=8.0, rim=None, wear=None, bump=0.25,
            emission=None, emit=0.0, coat=0.0, stretch=None, radial=False):
    """A hand-painted look: two tones broken up by noise, a lighter rim at
    grazing angles (the painted highlight WoW textures carry) and a bump."""
    m, nt, p = _principled(name)
    N = nt.nodes.new
    tc = N("ShaderNodeTexCoord")
    noise = N("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = detail
    noise.inputs["Roughness"].default_value = 0.62
    vec = tc.outputs["Object"]
    if radial:  # turned metal: the pattern depends only on the distance from the y axis, so spinning parts loop
        sep = N("ShaderNodeSeparateXYZ")
        nt.links.new(vec, sep.inputs[0])
        xz = N("ShaderNodeCombineXYZ")
        nt.links.new(sep.outputs["X"], xz.inputs["X"])
        nt.links.new(sep.outputs["Z"], xz.inputs["Z"])
        ln = N("ShaderNodeVectorMath"); ln.operation = "LENGTH"
        nt.links.new(xz.outputs[0], ln.inputs[0])
        rv = N("ShaderNodeCombineXYZ")
        nt.links.new(ln.outputs["Value"], rv.inputs["X"])
        nt.links.new(sep.outputs["Y"], rv.inputs["Y"])
        vec = rv.outputs[0]
    if stretch:  # streaks: bark ridges, brushed metal
        mp = N("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = stretch
        nt.links.new(vec, mp.inputs["Vector"])
        vec = mp.outputs["Vector"]
    nt.links.new(vec, noise.inputs["Vector"])
    ramp = N("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].position = 0.68
    ramp.color_ramp.elements[1].color = (*light, 1)
    nt.links.new(noise.outputs["Fac"], ramp.inputs[0])
    col = ramp.outputs[0]
    if rim:
        lw = N("ShaderNodeLayerWeight")
        lw.inputs["Blend"].default_value = 0.35
        mix = N("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "SCREEN"
        nt.links.new(lw.outputs["Facing"], mix.inputs["Factor"])
        nt.links.new(col, mix.inputs[6])
        mix.inputs[7].default_value = (*rim, 1)
        col = mix.outputs[2]
    if wear:
        # Lighter worn edges where the surface turns (via a fine second noise on the normal).
        ao = N("ShaderNodeAmbientOcclusion")
        ao.inside = True
        ao.inputs["Distance"].default_value = 0.04
        inv = N("ShaderNodeMath"); inv.operation = "SUBTRACT"; inv.inputs[0].default_value = 1.0
        nt.links.new(ao.outputs["AO"], inv.inputs[1])
        pw = N("ShaderNodeMath"); pw.operation = "MULTIPLY"; pw.inputs[1].default_value = 3.0
        nt.links.new(inv.outputs[0], pw.inputs[0])
        mix2 = N("ShaderNodeMix"); mix2.data_type = "RGBA"; mix2.clamp_factor = True
        nt.links.new(pw.outputs[0], mix2.inputs["Factor"])
        nt.links.new(col, mix2.inputs[6])
        mix2.inputs[7].default_value = (*wear, 1)
        col = mix2.outputs[2]
    nt.links.new(col, p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if coat:
        p.inputs["Coat Weight"].default_value = coat
    if bump:
        b = N("ShaderNodeBump")
        b.inputs["Strength"].default_value = bump
        n2 = N("ShaderNodeTexNoise")
        n2.inputs["Scale"].default_value = scale * 4
        n2.inputs["Detail"].default_value = 6
        nt.links.new(vec, n2.inputs["Vector"])
        nt.links.new(n2.outputs["Fac"], b.inputs["Height"])
        nt.links.new(b.outputs["Normal"], p.inputs["Normal"])
    if emission:
        p.inputs["Emission Color"].default_value = (*emission, 1)
        p.inputs["Emission Strength"].default_value = emit
    return m


def wood(name, dark=(0.12, 0.05, 0.02), light=(0.42, 0.2, 0.08), scale=3.0, rim=(0.55, 0.32, 0.15)):
    """Painted wood: stretched grain rings, a warm rim."""
    m, nt, p = _principled(name)
    N = nt.nodes.new
    tc = N("ShaderNodeTexCoord")
    mp = N("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0, 1.0, 9.0)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    wave = N("ShaderNodeTexWave")
    wave.wave_type = "RINGS"
    wave.inputs["Scale"].default_value = scale
    wave.inputs["Distortion"].default_value = 6
    wave.inputs["Detail"].default_value = 4
    nt.links.new(mp.outputs["Vector"], wave.inputs["Vector"])
    ramp = N("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*light, 1)
    nt.links.new(wave.outputs["Fac"], ramp.inputs[0])
    lw = N("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.3
    mix = N("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "SCREEN"
    nt.links.new(lw.outputs["Facing"], mix.inputs["Factor"])
    nt.links.new(ramp.outputs[0], mix.inputs[6])
    mix.inputs[7].default_value = (*rim, 1)
    nt.links.new(mix.outputs[2], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.7
    b = N("ShaderNodeBump"); b.inputs["Strength"].default_value = 0.3
    nt.links.new(wave.outputs["Fac"], b.inputs["Height"])
    nt.links.new(b.outputs["Normal"], p.inputs["Normal"])
    return m


def emissive(name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (*color, 1)
    e.inputs["Strength"].default_value = strength
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs[0], o.inputs["Surface"])
    return m


def setmat(o, m):
    o.data.materials.clear()
    o.data.materials.append(m)
    return o


# --- Animation ------------------------------------------------------------

def key(o, path, frame, value, index=-1):
    setattr(o, path, value) if index < 0 else getattr(o, path).__setitem__(index, value)
    o.keyframe_insert(path, frame=frame, index=index)


def cyclic(o, linear=False):
    """Makes every curve of o repeat (the loop has no seam)."""
    ad = o.animation_data
    if not ad or not ad.action:
        return
    for fc in fcurves(ad.action):
        if not any(m.type == "CYCLES" for m in fc.modifiers):
            fc.modifiers.new("CYCLES")
        if linear:
            for k in fc.keyframe_points:
                k.interpolation = "LINEAR"


def fcurves(action):
    """F-curves of an action (Blender 5 keeps them in layers and slots)."""
    if hasattr(action, "fcurves") and len(getattr(action, "fcurves", [])):
        return list(action.fcurves)
    out = []
    for layer in getattr(action, "layers", []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                out.extend(bag.fcurves)
    return out


def render(out, only=None, name="frame"):
    os.makedirs(out, exist_ok=True)
    s = bpy.context.scene
    frames = [only] if only else range(1, FRAMES + 1)
    for f in frames:
        s.frame_set(f)
        s.render.filepath = os.path.join(out, "%s_%02d.png" % (name, f))
        bpy.ops.render.render(write_still=True)


def flagstone(name, dark, light, scale=1.6, seam=(0.01, 0.008, 0.006), rough=0.85):
    """Irregular stone slabs: Voronoi cells, each its own tone, dark seams."""
    m, nt, p = _principled(name)
    N = nt.nodes.new
    tc = N("ShaderNodeTexCoord")
    vor = N("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = scale
    vor.inputs["Randomness"].default_value = 0.75
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    edge = N("ShaderNodeTexVoronoi")
    edge.feature = "DISTANCE_TO_EDGE"
    edge.inputs["Scale"].default_value = scale
    edge.inputs["Randomness"].default_value = 0.75
    nt.links.new(tc.outputs["Object"], edge.inputs["Vector"])
    noise = N("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale * 6
    noise.inputs["Detail"].default_value = 8
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    tone = N("ShaderNodeMath"); tone.operation = "MULTIPLY_ADD"
    sepc = N("ShaderNodeSeparateColor")
    nt.links.new(vor.outputs["Color"], sepc.inputs[0])
    nt.links.new(sepc.outputs[0], tone.inputs[0])
    tone.inputs[1].default_value = 0.55
    nt.links.new(noise.outputs["Fac"], tone.inputs[2])
    ramp = N("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.45
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (*light, 1)
    nt.links.new(tone.outputs[0], ramp.inputs[0])
    sm = N("ShaderNodeMapRange")
    sm.inputs["From Min"].default_value = 0.0
    sm.inputs["From Max"].default_value = 0.035
    nt.links.new(edge.outputs["Distance"], sm.inputs["Value"])
    mix = N("ShaderNodeMix"); mix.data_type = "RGBA"; mix.clamp_factor = True
    nt.links.new(sm.outputs["Result"], mix.inputs["Factor"])
    mix.inputs[6].default_value = (*seam, 1)
    nt.links.new(ramp.outputs[0], mix.inputs[7])
    nt.links.new(mix.outputs[2], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = rough
    b = N("ShaderNodeBump"); b.inputs["Strength"].default_value = 0.6
    hm = N("ShaderNodeMath"); hm.operation = "ADD"
    nt.links.new(sm.outputs["Result"], hm.inputs[0])
    sc = N("ShaderNodeMath"); sc.operation = "MULTIPLY"; sc.inputs[1].default_value = 0.3
    nt.links.new(noise.outputs["Fac"], sc.inputs[0])
    nt.links.new(sc.outputs[0], hm.inputs[1])
    nt.links.new(hm.outputs[0], b.inputs["Height"])
    nt.links.new(b.outputs["Normal"], p.inputs["Normal"])
    return m


def profile(name, pts, depth, loc=(0, 0, 0)):
    """A side profile (x, z points) extruded along y: anvils, frames, blades."""
    import bmesh
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    front = [bm.verts.new((x, -depth / 2, z)) for x, z in pts]
    face = bm.faces.new(front)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.y += depth
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    link(o)
    o.location = loc
    return o
