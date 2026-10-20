"""Volcanic kit for Cinder Ring (Icelandic/Hawaiian caldera): basalt and
scoria, obsidian, woolly moss and lichen, fumaroles, and the geothermal plant
with its wellheads and steam pipelines.
Blender Z-up, Godot Y-up. Original procedural geometry; no external assets.
Run: blender --background --python art/environment/build_volcanic.py
"""
import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/environment/volcanic"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
assets = []
collection = None


def material(name, color, roughness=0.9, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return mat


BASALT = [material("Basalt %d" % i, c) for i, c in enumerate([(.10, .10, .10), (.15, .14, .13), (.20, .19, .18)])]
SCORIA = [material("Scoria %d" % i, c) for i, c in enumerate([(.30, .12, .08), (.22, .10, .07)])]
OBSIDIAN = material("Obsidian", (.03, .03, .04), .1, .2)
SULPHUR = material("Sulphur crust", (.78, .70, .22))
SINTER = material("Sinter", (.82, .78, .70))
MOSS = [material("Woolly moss %d" % i, c) for i, c in enumerate([(.36, .44, .22), (.44, .50, .28), (.30, .38, .20)])]
LICHEN = material("Lichen", (.62, .64, .48))
OHIA = material("Ohia leaves", (.18, .28, .14))
LEHUA = material("Lehua blooms", (.72, .10, .08))
BARK = material("Ohia bark", (.24, .20, .17))
STEEL = material("Insulated pipe", (.72, .74, .74), .4, .6)
STEEL_DARK = material("Steel", (.36, .37, .38), .5, .6)
CONCRETE = material("Concrete", (.60, .59, .56))
CLADDING = material("Plant cladding", (.82, .83, .80), .5, .2)
ROOF = material("Plant roof", (.24, .38, .52), .5, .3)
GLASS = material("Glass", (.14, .20, .24), .2)
RED = material("Valve red", (.70, .12, .08), .5, .2)
YELLOW = material("Safety yellow", (.82, .62, .10), .6, .2)


def begin(name, radius, height):
    global collection
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    assets.append((name, collection, radius, height))


def attach(obj, name, mat, flat=False):
    obj.name = name
    for group in list(obj.users_collection):
        group.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(mat)
    if flat:
        for polygon in obj.data.polygons:
            polygon.use_smooth = False
    return obj


def limb(a, b, radius, mat, taper=1.0, sides=8):
    delta = Vector(b) - Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, radius2=radius * taper,
                                    depth=delta.length, location=(Vector(a) + Vector(b)) / 2)
    obj = bpy.context.object
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return attach(obj, "Member", mat)


def box(name, point, size, mat, angle=0.0, tilt=(0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler = (tilt[0], tilt[1], angle)
    return attach(obj, name, mat)


def cylinder(name, point, radius, depth, mat, sides=16, axis=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth, location=point)
    obj = bpy.context.object
    if axis == "x":
        obj.rotation_euler.y = math.pi / 2
    elif axis == "y":
        obj.rotation_euler.x = math.pi / 2
    return attach(obj, name, mat)


def cone(name, point, radius, depth, mat, sides=16, top=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, radius2=top, depth=depth, location=point)
    return attach(bpy.context.object, name, mat, flat=True)


def blob(name, center, size, mat, rng, roughness=.22, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=center)
    obj = bpy.context.object
    for vertex in obj.data.vertices:
        vertex.co *= 1 + rng.uniform(-roughness, roughness)
    obj.scale = size
    obj.rotation_euler.z = rng.uniform(0, math.tau)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return attach(obj, name, mat, flat=True)


def lathe(name, profile, mat, sides=24):
    verts = []
    for radius, height in profile:
        for index in range(sides):
            angle = index * math.tau / sides
            verts.append((math.cos(angle) * radius, math.sin(angle) * radius, height))
    faces = []
    for ring in range(len(profile) - 1):
        for index in range(sides):
            a = ring * sides + index
            b = ring * sides + (index + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    attach(obj, name, mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def gable_roof(name, point, width, depth, rise, mat, overhang=.3):
    x, y, z = point
    w = width / 2 + overhang
    d = depth / 2 + overhang
    verts = [(x - d, y - w, z), (x + d, y - w, z), (x + d, y + w, z), (x - d, y + w, z),
             (x - d, y, z + rise), (x + d, y, z + rise)]
    faces = [(0, 1, 5, 4), (3, 4, 5, 2), (0, 4, 3), (1, 2, 5)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return attach(obj, name, mat, flat=True)


# ---------------------------------------------------------------- ground

def basalt_boulder(seed, size, index):
    rng = random.Random(seed)
    blob("Basalt", (0, 0, size[2] * .45), size, BASALT[index], rng, .25, 0)
    if rng.random() < .7:
        blob("Lichen", (size[0] * .2, 0, size[2] * .8), (size[0] * .4, size[1] * .4, size[2] * .12), LICHEN, rng, .3, 0)


def scoria_heap(seed):
    rng = random.Random(seed)
    for index in range(7):
        angle = rng.uniform(0, math.tau)
        r = rng.uniform(0, 1.0)
        size = rng.uniform(.25, .5)
        blob("Scoria", (math.cos(angle) * r, math.sin(angle) * r, size * .4), (size, size * .9, size * .7),
             rng.choice(SCORIA), rng, .35, 1)


def lava_slab(seed):
    """Ropy pahoehoe: a low slab with coiled rope ridges."""
    rng = random.Random(seed)
    blob("Slab", (0, 0, .1), (2.4, 1.6, .35), BASALT[1], rng, .1, 2)
    for index in range(5):
        x = -1.4 + index * .7
        bpy.ops.mesh.primitive_torus_add(major_radius=.5 + index * .05, minor_radius=.08, location=(x, 0, .4),
                                         major_segments=12, minor_segments=5)
        obj = bpy.context.object
        obj.scale = (1.0, 1.6, .5)
        attach(obj, "Rope", BASALT[2])


def obsidian_shards(seed):
    rng = random.Random(seed)
    for index in range(6):
        angle = rng.uniform(0, math.tau)
        r = rng.uniform(.2, .9)
        tip = (math.cos(angle) * (r + .4), math.sin(angle) * (r + .4), rng.uniform(.6, 1.3))
        limb((math.cos(angle) * r, math.sin(angle) * r, 0), tip, rng.uniform(.12, .22), OBSIDIAN, .1, 4)


def moss_hummocks(seed):
    rng = random.Random(seed)
    for index in range(6):
        angle = rng.uniform(0, math.tau)
        r = rng.uniform(0, 1.0)
        size = rng.uniform(.35, .6)
        blob("Moss", (math.cos(angle) * r, math.sin(angle) * r, size * .2), (size, size, size * .55),
             rng.choice(MOSS), rng, .15, 1)


def ohia(seed):
    rng = random.Random(seed)
    top = Vector((rng.uniform(-.3, .3), rng.uniform(-.3, .3), 2.4))
    limb((0, 0, 0), top, .14, BARK, .6, 6)
    for index in range(6):
        centre = top + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-.2, .7)))
        blob("Crown", centre, (.8, .8, .6), OHIA, rng, .3, 0)
        if rng.random() < .6:
            blob("Lehua", centre + Vector((0, 0, .45)), (.25, .25, .15), LEHUA, rng, .3, 0)


def fumarole(seed):
    rng = random.Random(seed)
    cone("Vent cone", (0, 0, .8), 2.2, 1.6, SCORIA[0], 10, .5)
    cone("Sulphur rim", (0, 0, 1.55), .7, .3, SULPHUR, 10, .4)
    for index in range(4):
        angle = rng.uniform(0, math.tau)
        blob("Sulphur crust", (math.cos(angle) * 1.4, math.sin(angle) * 1.4, .5), (.5, .4, .15), SULPHUR, rng, .3, 0)
    for index in range(3):
        blob("Sinter", (rng.uniform(-2, 2), rng.uniform(-2, 2), .05), (.8, .6, .08), SINTER, rng, .2, 0)


# ---------------------------------------------------------------- geothermal

def pipe_run(length, height=1.4):
    """Insulated steam pipe along local X on H-frame supports."""
    cylinder("Steam pipe", (0, 0, height), .45, length, STEEL, 14, "x")
    for index in range(int(length // 4) + 1):
        x = -length / 2 + index * 4
        for y in [-.5, .5]:
            limb((x, y, 0), (x, y, height - .4), .07, STEEL_DARK)
        box("Saddle", (x, 0, height - .45), (.3, 1.2, .12), STEEL_DARK)


def geothermal_plant():
    box("Power house", (0, 0, 4.5), (18.0, 11.0, 9.0), CLADDING)
    gable_roof("Power house roof", (0, 0, 9.0), 11.0, 18.0, 2.2, ROOF)
    for index in range(5):
        box("Window band", (-7 + index * 3.5, -5.53, 6.5), (2.6, .06, 1.2), GLASS)
    for x in [-5.0, 5.0]:
        tower = lathe("Cooling tower", [(4.2, 0), (3.6, 3.0), (3.0, 7.0), (3.2, 10.0)], CONCRETE)
        tower.location = (x, 13.0, 0)
    for x in [-6.0, 0.0, 6.0]:
        cylinder("Separator", (x, -10.0, 2.2), 1.2, 4.4, STEEL, 16)
        cone("Separator cap", (x, -10.0, 4.8), 1.2, .8, STEEL, 16, .3)
    for x in [-6.0, 0.0, 6.0]:
        limb((x, -8.8, 3.2), (x, -5.5, 3.2), .35, STEEL)
    box("Transformer", (11.5, 0, 1.5), (3.0, 4.0, 3.0), STEEL_DARK)
    limb((11.5, 0, 3.0), (11.5, 0, 9.0), .16, STEEL_DARK)
    box("Line arm", (11.5, 0, 9.0), (.3, 5.0, .3), STEEL_DARK)


def wellhead():
    box("Well pad", (0, 0, .15), (6.0, 6.0, .3), CONCRETE)
    cylinder("Casing", (0, 0, .9), .5, 1.2, STEEL_DARK, 12)
    for z in [1.7, 2.4]:
        cylinder("Valve", (0, 0, z), .55, .3, RED, 12)
        cylinder("Wheel", (.7, 0, z), .3, .06, YELLOW, 10, "x")
    cylinder("Master valve", (0, 0, 3.0), .3, .8, STEEL_DARK, 10)
    limb((0, 0, 2.0), (2.6, 0, 2.0), .3, STEEL)
    cylinder("Silencer", (-2.0, -1.6, 2.2), .9, 4.4, CONCRETE, 14)


def pipeline():
    pipe_run(20.0)
    bpy.ops.mesh.primitive_torus_add(major_radius=1.6, minor_radius=.45, location=(0, -1.6, 1.4),
                                     major_segments=16, minor_segments=8)
    attach(bpy.context.object, "Expansion loop", STEEL)


def observatory():
    box("Hut", (0, 0, 1.6), (6.0, 4.0, 3.2), CLADDING)
    gable_roof("Hut roof", (0, 0, 3.2), 4.0, 6.0, 1.0, ROOF)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1.4, location=(4.4, 0, 1.0))
    obj = bpy.context.object
    for vertex in obj.data.vertices:
        vertex.co.z = max(vertex.co.z, 0.0)
    attach(obj, "Seismograph dome", CLADDING)
    limb((-2.2, 1.0, 3.2), (-2.2, 1.0, 9.0), .06, STEEL_DARK)
    box("Antenna", (-2.2, 1.0, 9.0), (1.2, .08, .08), STEEL_DARK)


builders = [
    ("BasaltBoulderA", 1.6, 1.4, lambda: basalt_boulder(601, (1.2, 1.0, .9), 0)),
    ("BasaltBoulderB", 1.1, 1.0, lambda: basalt_boulder(602, (.8, .7, .6), 1)),
    ("BasaltColumn", 1.4, 2.6, lambda: [limb((x, y, 0), (x, y, h), .35, BASALT[0], 1, 6) for x, y, h in
                                        [(0, 0, 2.4), (.6, .3, 1.8), (-.5, .4, 2.0), (.2, -.6, 1.4), (-.4, -.4, 1.1)]]),
    ("ScoriaHeap", 1.6, .9, lambda: scoria_heap(603)),
    ("LavaSlab", 2.8, .7, lambda: lava_slab(604)),
    ("ObsidianShards", 1.6, 1.4, lambda: obsidian_shards(605)),
    ("MossHummocks", 1.7, .7, lambda: moss_hummocks(606)),
    ("Ohia", 2.2, 3.9, lambda: ohia(607)),
    ("Fumarole", 3.0, 1.8, lambda: fumarole(608)),
    ("GeothermalPlant", 18.4, 11.4, geothermal_plant),
    ("Wellhead", 4.4, 4.5, wellhead),
    ("Pipeline", 10.6, 2.0, pipeline),
    ("Observatory", 6.4, 9.2, observatory),
]
for name, radius, height, build in builders:
    begin(name, radius, height)
    build()

manifest = {}
violations = []
for name, asset, radius_limit, height_limit in assets:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in asset.objects:
        obj.select_set(True)
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    points = [evaluated.matrix_world @ vertex.co for obj in asset.objects if obj.type == "MESH"
              for evaluated in [obj.evaluated_get(deps)] for vertex in evaluated.data.vertices]
    radius = max(math.hypot(p.x, p.y) for p in points)
    height = max(p.z for p in points)
    if radius > radius_limit or height > height_limit:
        violations.append((name, round(radius, 2), round(height, 2)))
    manifest[name] = {"radius": round(radius, 4), "height": round(height, 4),
                      "radius_limit": radius_limit, "height_limit": height_limit}
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + ".glb")), export_format="GLB",
                              use_selection=True, export_apply=True)
assert not violations, violations
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/environment/VolcanicKit.blend"))
(ROOT / "art/environment/volcanic-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest))
