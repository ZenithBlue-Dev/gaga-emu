"""Render the GagaEmu app icon options with Blender Cycles. Original artwork.

Runs headless in a fresh factory scene, so it never touches an open Blender file:

    blender -b --factory-startup -P design/icons/render_icons.py -- <concept> <variant> <res> <samples> <out.png>

concept: one of CONCEPTS. variant: light, dark or tinted.
design/icons/render_all.sh renders every concept and variant at 1024.

The tile fills the whole square with no alpha, because the system applies the corner mask.
Coordinates: the tile spans -1..1 in x and y, +y is up on screen, +z faces the viewer.
"""

import math
import sys

import bpy
import numpy as np

LATHE_SEGMENTS = 256


def lin(hex_value):
    """sRGB hex to linear RGBA, the space shader inputs use."""
    rgb = np.array([(hex_value >> 16) & 255, (hex_value >> 8) & 255, hex_value & 255]) / 255
    linear = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    return (*linear, 1.0)


# Values from Palette in Sources/App/AppTheme.swift. Ink and vermilion sit a shade under #1C1A17 and #E4572E because gloss and light lift them back.
# Tinted is greyscale: the system supplies the hue.
PALETTES = {
    "light": dict(tile=0xF4EFE6, sheet=0xFBF8F2, rule=0xD9D1C2, ink=0x12110F, acc=0xDA4620),
    "dark": dict(tile=0x1A1813, sheet=0xEDE6D8, rule=0x3A352C, ink=0xEDE6D8, acc=0xDA4620),
    "tinted": dict(tile=0x0B0B0B, sheet=0xC4C4C4, rule=0x2C2C2C, ink=0x7C7C7C, acc=0xF2F2F2),
}


# Materials

def principled(name, color=None, rough=0.55, coat=0.0, spec=0.5, transmission=0.0, ior=1.45):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    if color is not None:
        bsdf.inputs["Base Color"].default_value = lin(color)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Coat Weight"].default_value = coat
    bsdf.inputs["Coat Roughness"].default_value = 0.12
    bsdf.inputs["Specular IOR Level"].default_value = spec
    bsdf.inputs["Transmission Weight"].default_value = transmission
    bsdf.inputs["IOR"].default_value = ior
    return mat


def add_paper_grain(mat, strength=0.012):
    """Barely visible fibre. Must stay invisible at 60px and quiet at 1024."""
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 260
    noise.inputs["Detail"].default_value = 6
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    bump.inputs["Distance"].default_value = 0.01
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


def lacquer(name, color):
    return principled(name, color, rough=0.27, coat=0.16, spec=0.26)


def card(name, color):
    mat = principled(name, color, rough=0.62, spec=0.35)
    add_paper_grain(mat)
    return mat


# Geometry

def smoothstep(lo, hi, x):
    t = np.clip((x - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def sd_rrect(x, y, cx, cy, hw, hh, r):
    qx, qy = np.abs(x - cx) - hw + r, np.abs(y - cy) - hh + r
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def pillow(x, y):
    """Cushioned tile: rolls off softly toward the mask edge, no hard rim, so it survives mask changes."""
    inside = -sd_rrect(x, y, 0, 0, 1.0, 1.0, 0.46)
    return -0.042 * (1 - smoothstep(-0.02, 0.18, inside)) ** 2 - 0.008 * (x * x + y * y)


def add_tile(height, color, rough=0.62, grain=0.012, n=1100):
    """Heightfield tile. `color` is a hex, or a function from x, y to linear RGB, smooth at region edges."""
    axis = np.linspace(-1.03, 1.03, n)
    x, y = np.meshgrid(axis, axis)
    z = height(x, y)
    mesh = bpy.data.meshes.new("tile")
    idx = np.arange(n * n).reshape(n, n)
    quads = np.stack([idx[:-1, :-1], idx[:-1, 1:], idx[1:, 1:], idx[1:, :-1]], axis=-1).reshape(-1, 4)
    mesh.vertices.add(n * n)
    mesh.vertices.foreach_set("co", np.stack([x, y, z], axis=-1).ravel().astype(np.float32))
    mesh.loops.add(quads.size)
    mesh.loops.foreach_set("vertex_index", quads.ravel().astype(np.int32))
    mesh.polygons.add(len(quads))
    mesh.polygons.foreach_set("loop_start", (np.arange(len(quads)) * 4).astype(np.int32))
    mesh.update(calc_edges=True)
    mesh.polygons.foreach_set("use_smooth", np.ones(len(quads), dtype=bool))
    mesh.update()

    if callable(color):
        rgb = color(x, y)
        attr = mesh.color_attributes.new("col", "FLOAT_COLOR", "POINT")
        attr.data.foreach_set("color", np.dstack([rgb, np.ones(x.shape)]).ravel().astype(np.float32))
        mat = principled("tile", None, rough=rough, spec=0.35)
        nt = mat.node_tree
        node = nt.nodes.new("ShaderNodeVertexColor")
        node.layer_name = "col"
        nt.links.new(node.outputs["Color"], next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"])
    else:
        mat = principled("tile", color, rough=rough, spec=0.35)
    if grain:
        add_paper_grain(mat, grain)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new("tile", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def fillet(points, radius, steps=16):
    """Round every corner of a closed polygon, convex or concave."""
    pts = [np.array(p, dtype=float) for p in points]
    out = []
    count = len(pts)
    for i, p in enumerate(pts):
        a, b = pts[i - 1] - p, pts[(i + 1) % count] - p
        la, lb = np.linalg.norm(a), np.linalg.norm(b)
        a, b = a / la, b / lb
        half = math.acos(float(np.clip(np.dot(a, b), -1, 1))) / 2
        t = min(radius / math.tan(half), la * 0.49, lb * 0.49)
        r = t * math.tan(half)
        bis = (a + b) / np.linalg.norm(a + b)
        center = p + bis * (r / math.sin(half))
        start, end = p + a * t - center, p + b * t - center
        a0 = math.atan2(start[1], start[0])
        delta = (math.atan2(end[1], end[0]) - a0 + math.pi) % (2 * math.pi) - math.pi
        for s in range(steps + 1):
            ang = a0 + delta * s / steps
            out.append(center + r * np.array([math.cos(ang), math.sin(ang)]))
    return out


def rect(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def rotated(points, degrees, pivot=(0, 0)):
    c, s = math.cos(math.radians(degrees)), math.sin(math.radians(degrees))
    return [(pivot[0] + (x - pivot[0]) * c - (y - pivot[1]) * s,
             pivot[1] + (x - pivot[0]) * s + (y - pivot[1]) * c) for x, y in points]


def add_slab(outline, z0, height, bevel, mat, name="slab"):
    """Extrude a closed outline with a real rounded top edge."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "2D"
    curve.fill_mode = "BOTH"
    curve.extrude = max(height / 2 - bevel, 0)
    curve.bevel_depth = bevel
    curve.bevel_resolution = 8
    curve.offset = -bevel
    curve.resolution_u = 1
    spline = curve.splines.new("POLY")
    spline.points.add(len(outline) - 1)
    for point, (x, y) in zip(spline.points, outline):
        point.co = (x, y, 0, 1)
    spline.use_cyclic_u = True
    spline.use_smooth = True
    curve.materials.append(mat)
    obj = bpy.data.objects.new(name, curve)
    obj.location.z = z0 + height / 2
    bpy.context.scene.collection.objects.link(obj)
    return obj


def add_lathe(profile, cx, cy, mat, name="lathe"):
    """Solid of revolution from (radius, z) pairs, center first. Used for buttons."""
    rings = len(profile)
    seg = LATHE_SEGMENTS
    verts, faces = [], []
    for r, z in profile:
        for s in range(seg):
            ang = 2 * math.pi * s / seg
            verts.append((cx + r * math.cos(ang), cy + r * math.sin(ang), z))
    for i in range(rings - 1):
        for s in range(seg):
            a, b = i * seg + s, i * seg + (s + 1) % seg
            faces.append((a, a + seg, b + seg, b))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.polygons.foreach_set("use_smooth", np.ones(len(faces), dtype=bool))
    mesh.update()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def button_profile(radius, height, base=-0.06, power=3.0, n=64):
    """Domed key: nearly flat crown, tight round shoulder."""
    rs = radius * np.linspace(1e-4, 1, n)
    zs = height * (1 - (rs / radius) ** power) ** (1 / 2.2)
    return [(float(r), float(z + base)) for r, z in zip(rs, zs)] + [(radius, base - 0.1)]


# Concepts. Each takes a palette and builds its scene.

def two_beats(p):
    """Two keys, one per syllable of the name. Ga, ga: press."""
    centers = [(0.31, 0.31), (-0.31, -0.31)]
    radius = 0.325

    def height(x, y):
        z = pillow(x, y)
        for cx, cy in centers:
            d = np.hypot(x - cx, y - cy) - radius
            z = z - 0.05 * (1 - smoothstep(0.0, 0.016, d))
        return z

    def color(x, y):
        seam = np.ones(x.shape)
        for cx, cy in centers:
            seam = seam * smoothstep(radius - 0.002, radius + 0.014, np.hypot(x - cx, y - cy))
        return np.array(lin(p["tile"])[:3]) * (0.12 + 0.88 * seam)[..., None]

    add_tile(height, color, n=1500)
    add_lathe(button_profile(radius - 0.004, 0.115), *centers[0], lacquer("acc", p["acc"]), "key-a")
    add_lathe(button_profile(radius - 0.004, 0.115), *centers[1], lacquer("ink", p["ink"]), "key-b")


def folio(p):
    """A play triangle cut from three stacked sheets, a little loose, like a folio."""
    tri = [(-0.47, 0.63), (0.69, 0.0), (-0.47, -0.63)]
    add_tile(pillow, p["tile"])
    pivot = (-0.47, -0.63)
    add_slab(fillet(rotated(tri, 13, pivot), 0.12), 0.0, 0.05, 0.016, lacquer("ink", p["ink"]), "s1")
    add_slab(fillet(rotated(tri, 6.5, pivot), 0.12), 0.06, 0.05, 0.016, card("sheet", p["sheet"]), "s2")
    add_slab(fillet(tri, 0.12), 0.12, 0.05, 0.016, lacquer("acc", p["acc"]), "s3")


def shelf(p):
    """Four spines on a ledge, the last one leaning. The app's own Library, in one glyph."""
    add_tile(pillow, p["tile"])
    ink, acc = lacquer("ink", p["ink"]), lacquer("acc", p["acc"])
    base, shift, z = -0.47, -0.075, 0.02
    bars = [(-0.62, -0.31, 0.50), (-0.275, -0.075, 0.34), (-0.04, 0.22, 0.60)]
    for x0, x1, top in bars:
        add_slab(fillet(rect(x0 + shift, base, x1 + shift, top), 0.035), z, 0.1, 0.022, ink)
    angle, width, tall = 13, 0.25, 1.06
    px = 0.22 + (0.60 - base) * math.tan(math.radians(angle)) + 0.015 + shift
    lean = rotated(rect(px, base, px + width, base + tall), angle, (px, base))
    add_slab(fillet(lean, 0.035), z, 0.1, 0.022, acc)
    add_slab(fillet(rect(-0.78, base - 0.14, 0.78, base - 0.04), 0.04), z, 0.09, 0.024, ink)


def steps(p):
    """Three pixel stairs and one pixel in the air: a platform game with no characters in it."""
    u = 0.375
    x0, y0 = -1.5 * u, -1.5 * u
    stair = [(x0, y0), (x0 + 3 * u, y0), (x0 + 3 * u, y0 + 3 * u), (x0 + 2 * u, y0 + 3 * u),
             (x0 + 2 * u, y0 + 2 * u), (x0 + u, y0 + 2 * u), (x0 + u, y0 + u), (x0, y0 + u)]
    add_tile(pillow, p["tile"])
    add_slab(fillet(stair, 0.03), 0.0, 0.11, 0.022, lacquer("ink", p["ink"]), "stair")
    gap = 0.012
    add_slab(fillet(rect(x0 + gap, y0 + 2 * u + gap, x0 + u - gap, y0 + 3 * u - gap), 0.03), 0.17, 0.09, 0.022,
             lacquer("acc", p["acc"]), "pixel")


def phosphor(p):
    """One lit pixel on a curved tube, on a vermilion tile. Old screens, landscape, nothing else."""
    tile = p["acc"] if p["tile"] == PALETTES["light"]["tile"] else p["tile"]
    glass = PALETTES["light"]["ink"] if p["ink"] != PALETTES["tinted"]["ink"] else 0x1A1A1A
    hw, hh, r = 0.70, 0.54, 0.2

    def tile_height(x, y):
        return pillow(x, y) - 0.05 * (1 - smoothstep(-0.03, 0.012, sd_rrect(x, y, 0, 0, hw, hh, r)))

    def tube_height(x, y):
        # Smooth product, not a distance field: a distance field creases along its medial axis.
        inside = -sd_rrect(x, y, 0, 0, hw - 0.012, hh - 0.012, r)
        crown = (1 - np.clip(np.abs(x) / hw, 0, 1) ** 4) * (1 - np.clip(np.abs(y) / hh, 0, 1) ** 4)
        return -0.06 + 0.12 * crown ** 0.6 + np.minimum(inside, 0) * 2

    add_tile(tile_height, tile, rough=0.42, grain=0.005)

    def tube_color(x, y):
        warm = np.array(lin(0xE4572E if p["tile"] != PALETTES["tinted"]["tile"] else 0xFFFFFF)[:3])
        glow = 0.34 * np.exp(-(np.hypot(x, y) / 0.27) ** 2)[..., None]
        return np.array(lin(glass)[:3]) * (1 - glow) + warm * glow

    tube = add_tile(tube_height, tube_color, rough=0.3, grain=0)
    tube.name = "tube"
    size = 0.115
    lit = principled("lit", p["sheet"] if p["tile"] == PALETTES["light"]["tile"] else p["acc"], rough=0.3)
    bsdf = next(n for n in lit.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Emission Color"].default_value = lin(0xFFE9D2 if p["tile"] != PALETTES["tinted"]["tile"] else 0xFFFFFF)
    bsdf.inputs["Emission Strength"].default_value = 0.85
    add_slab(fillet(rect(-size, -size, size, size), 0.028), 0.05, 0.026, 0.01, lit, "pixel")


def well(p):
    """Square sheets cut away and turned a little at each step, down to a vermilion floor."""
    sizes = (0.64, 0.47, 0.31)
    twist = 9.0
    zone_colors = [p["tile"], p["tile"], p["rule"], p["acc"]]

    def masks(x, y, edge):
        out = []
        for i, size in enumerate(sizes):
            c, s = math.cos(math.radians(twist * (i + 1))), math.sin(math.radians(twist * (i + 1)))
            out.append(1 - smoothstep(-edge, edge, sd_rrect(c * x + s * y, -s * x + c * y, 0, 0, size, size, 0.05 + size * 0.28)))
        return out

    def height(x, y):
        z = pillow(x, y)
        for m in masks(x, y, 0.009):
            z = z - 0.085 * m
        return z

    def color(x, y):
        out = np.broadcast_to(np.array(lin(zone_colors[0])[:3]), (*x.shape, 3)).copy()
        for m, hex_value in zip(masks(x, y, 0.004), zone_colors[1:]):
            out = out * (1 - m[..., None]) + np.array(lin(hex_value)[:3]) * m[..., None]
        return out

    add_tile(height, color, grain=0.012, n=1500)


CONCEPTS = dict(two_beats=two_beats, folio=folio, shelf=shelf, steps=steps, phosphor=phosphor, well=well)


# Scene

def setup_scene(res, samples, key=330.0, ambient=0.42):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for device in prefs.devices:
            device.use = True
        scene.cycles.device = "GPU"
    except TypeError:
        scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 10
    scene.render.resolution_x = scene.render.resolution_y = res
    scene.render.film_transparent = False
    settings = scene.render.image_settings
    settings.file_format = "PNG"
    settings.color_mode = "RGB"
    settings.color_depth = "8"
    settings.compression = 90
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"

    world = bpy.data.worlds.new("world")
    world.use_nodes = True
    background = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs["Color"].default_value = (1, 1, 1, 1)
    background.inputs["Strength"].default_value = ambient
    scene.world = world

    camera = bpy.data.cameras.new("cam")
    camera.type = "ORTHO"
    camera.ortho_scale = 2.0
    cam = bpy.data.objects.new("cam", camera)
    cam.location = (0, 0, 5)
    scene.collection.objects.link(cam)
    scene.camera = cam

    # Soft top light, as on Apple's system icons: shadows fall toward the bottom of the screen.
    lamp = bpy.data.lights.new("key", "AREA")
    lamp.shape = "DISK"
    lamp.size = 6.0
    lamp.energy = key
    light = bpy.data.objects.new("key", lamp)
    light.location = (0, 3.2, 5.6)
    light.rotation_euler = (-math.atan2(3.2, 5.6), 0, 0)
    scene.collection.objects.link(light)
    return scene


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    concept, variant, res, samples, out = argv[0], argv[1], int(argv[2]), int(argv[3]), argv[4]
    scene = setup_scene(res, samples)
    CONCEPTS[concept](PALETTES[variant])
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)


main()
