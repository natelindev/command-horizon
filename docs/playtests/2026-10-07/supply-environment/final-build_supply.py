"""Original editable Supply Line freight-road kit. Blender Z-up, Godot Y-up.
Landmarks remain inside the original five-metre navigation footprints.
Low passable details are capped at 0.3 metres.
"""
import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/environment/supply"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
assets = []
collection = None


def material(name, color, metallic=0.0, roughness=0.88):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return mat


STONE = [material("Sandstone bed " + str(i), color) for i, color in enumerate([
    (.36, .23, .145), (.405, .275, .18), (.43, .295, .195),
    (.455, .315, .21), (.39, .26, .17), (.46, .325, .215)])]
DUST = material("Wind polished cap", (.46, .34, .235))
CONCRETE = material("Abandoned freight concrete", (.39, .365, .29))
EDGE = material("Fractured concrete", (.53, .49, .38))
IRON = material("Weathered utility green", (.14, .195, .16), .4)
RUST = material("Oxidized seams", (.34, .135, .055), .25)
STEEL = material("Worn galvanized metal", (.32, .35, .31), .65, .55)
DARK = material("Recesses and rubber", (.055, .055, .046))
OCHRE = material("Faded safety paint", (.60, .38, .085), .1)
LEAF = material("Dry sage canopy", (.24, .275, .17))
TIPS = material("Sunlit scrub tips", (.40, .39, .235))
BARK = material("Dry branches", (.24, .185, .10))


def begin(name, radius, height):
    global collection
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    assets.append((name, collection, radius, height))


def attach(obj, name, mat, bevel=0):
    obj.name = name
    for group in list(obj.users_collection):
        group.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Worn manufactured edges", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        obj.modifiers.new("Weighted face normals", "WEIGHTED_NORMAL")
    return obj


def box(name, point, size, mat=IRON, bevel=.025, angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.z = angle
    return attach(obj, name, mat, bevel)


def cylinder(name, point, radius, depth, mat=STEEL, sides=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth, location=point)
    return attach(bpy.context.object, name, mat, .014)


def beam(name, a, b, radius=.04, mat=STEEL):
    a, b = Vector(a), Vector(b)
    obj = cylinder(name, (a+b)/2, radius, (b-a).length, mat, 8)
    obj.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    return obj


def rock(name, center, radius, height, seed, crown=True, stretch=(1.0, 1.0)):
    rng = random.Random(seed)
    count = 36
    phase = rng.random() * 6.28
    radii = [radius * (.79 + .12 * math.sin(i * .53 + phase) + .05 * math.cos(i * 1.17 + phase) + rng.uniform(-.022, .022))
             for i in range(count)]
    levels = [(0, 1), (.08, .98), (.16, .88), (.32, .87),
              (.39, .895), (.56, .84), (.70, .81), (.90, .79), (1, .75)]
    vertices = []
    for level, (z, scale) in enumerate(levels):
        for i in range(count):
            angle = i * math.tau / count
            radial = radii[i] * scale
            jitter = rng.uniform(-.015, .015) * height if level else 0
            if level == len(levels) - 1:
                jitter = 0  # Flat sedimentary caps avoid radial fan shading.
            vertices.append((center[0] + math.cos(angle) * radial * stretch[0],
                             center[1] + math.sin(angle) * radial * stretch[1],
                             center[2] + .008 + z * height * .97 + jitter))
    vertices.append((center[0] - radius * .10, center[1] + radius * .04,
                     center[2] + .008 + height * .97))
    faces = []
    colors = []
    for level in range(len(levels)-1):
        for i in range(count):
            j = (i+1) % count
            a, b = level*count+i, level*count+j
            faces.extend([(a, b, b+count), (a, b+count, a+count)])
            color = (level + (1 if i % 7 == 0 else 0)) % len(STONE)
            colors.extend([color, color])
    top = (len(levels)-1)*count
    for i in range(count):
        faces.append((top+i, top+(i+1)%count, len(vertices)-1))
        colors.append(len(STONE))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    for mat in STONE + [DUST]:
        mesh.materials.append(mat)
    for polygon, color in zip(mesh.polygons, colors):
        polygon.material_index = color
    return obj


def rubble(seed, count, radius=4.7):
    rng = random.Random(seed)
    for index in range(count):
        angle = rng.random()*math.tau
        radial = radius*(.68 + rng.random()*.32)
        point = (math.cos(angle)*radial, math.sin(angle)*radial, .025)
        rock("Detached sandstone fragment", point, rng.uniform(.14,.40),
             rng.uniform(.07,.22), seed*100+index)


def pad():
    box("Sand buried service pad", (0,0,.13), (6.4,5.0,.24), CONCRETE, .06, -.10)
    for x in [-2.4, 2.2]:
        box("Cracked expansion joint", (x,-.05,.255), (.026,4.65,.016), DARK, 0, -.1)
    for x,y in [(-2.8,-2.6),(3.2,1.4),(-2.1,2.7)]:
        box("Broken apron slab", (x,y,.07), (.65,.47,.12), EDGE,.04,x*.8)


begin("RoadCutA", 5.0, 3.0)
rock("Eroded road cutting", (0, 0, 0), 4.8, 2.68, 1281, stretch=(1, .84))
rock("Fractured cap", (-1.7, .4, 2.1), 1.9, .7, 1282)
rubble(1283, 14, 4.35)

begin("RoadCutB", 5.0, 3.0)
rock("Collapsed quarry face", (0, 0, 0), 4.75, 1.8, 1290, stretch=(.88, 1))
rock("Offset bedrock crown", (1.15, -.7, 1.35), 2.6, 1.6, 1291)
rock("Detached low bench", (-2.2, 1.3, .65), 1.8, .6, 1292)
rubble(1293, 12, 4.3)

begin("RoadPumpStation", 5.0, 3.0)
pad()
box("Concrete service hut", (-.8, .2, 1.2), (3.0, 3.1, 2.0), CONCRETE, .09)
box("Overhanging roof", (-.8, .2, 2.28), (3.4, 3.5, .18), IRON, .035)
for y in [-1.3, -.7, -.1, .5, 1.1, 1.7]:
    box("Standing roof seam", (-.8, y, 2.39), (3.45, .045, .07), RUST, .012)
box("Service door recess", (-.8, -1.365, 1.12), (.8, .04, 1.7), DARK, .015)
for x in [-1.85, .25]:
    box("Dust-dark glazing", (x, -1.37, 1.55), (.55, .04, .62), DARK, .012)
    box("Window sill", (x, -1.44, 1.2), (.65, .2, .08), EDGE, .015)
for y in [-.95, 1.05]:
    cylinder("Banded reservoir", (2.0, y, 1.35), .72, 2.1, IRON)
    for z in [.45, 1.15, 2.12]:
        cylinder("Reservoir reinforcing band", (2.0, y, z), .75, .065, RUST)
    cylinder("Inspection lid", (2.0, y, 2.47), .32, .1, STEEL)
beam("Feeder pipe", (1.1, -1.9, .46), (2.85, -1.9, .46), .11, RUST)
beam("Rising pipe", (2.85, -1.9, .46), (2.85, -1.9, 1.15), .11, RUST)
for z in [.5, .8, 1.1, 1.4, 1.7, 2.0]:
    beam("Access rung", (2.6, .65, z), (2.6, 1.3, z), .025, STEEL)
box("Faded utility plate", (-.8, -1.4, 2.06), (.7, .02, .22), OCHRE, .01)

begin("RuinedTransferBay", 5.0, 3.0)
pad()
for x in [-2.2, 2.2]:
    for y in [-1.65, 1.65]:
        beam("Loading canopy upright", (x, y, .25), (x, y, 2.6), .075, IRON)
    beam("Roof side girder", (x, -1.9, 2.6), (x, 1.9, 2.6), .09, RUST)
for y in [-1.7, -.55, .55, 1.7]:
    beam("Exposed roof truss", (-2.3, y, 2.55), (0, y, 2.88), .05, STEEL)
    beam("Exposed roof truss", (0, y, 2.88), (2.3, y, 2.55), .05, STEEL)
for y in [.8, 1.15, 1.5]:
    box("Remaining corrugated roof", (-.85, y, 2.72), (2.75, .28, .055), IRON, .012)
for x in [-1.4, .2]:
    box("Abandoned freight crate", (x, .5, .7), (1.25, 1.55, .9), IRON, .045)
    for y in [-.15, 1.15]:
        box("Freight straps", (x, y, .71), (1.3, .07, .96), RUST, .008)
box("Collapsed wall", (-.9, -1.9, .48), (2.0, .35, .44), CONCRETE, .05, -.2)
box("Torn roof sheet", (2.6, -1.65, .3), (1.25, 1.0, .055), RUST, .02, .35)

begin("DrainageRemnant", 2.0, .3)
box("Broken drain surround", (0, 0, .065), (2.35, .75, .12), CONCRETE, .045)
box("Drain recess", (0, 0, .132), (1.7, .42, .028), DARK, .008)
for x in [-.75, -.5, -.25, 0, .25, .5, .75]:
    box("Drain crossbar", (x, 0, .165), (.055, .5, .055), STEEL, .008)
for x, y in [(-1.28, .5), (.9, -.5), (.35, .55)]:
    box("Spalled pavement", (x, y, .055), (.32, .28, .1), EDGE, .03, x)

begin("RoadSage", 1.3, .3)
for index in range(7):
    a = index * 2.4
    x, y = math.cos(a) * .55, math.sin(a) * .55
    beam("Dry sage branch", (x, y, .02), (x + .12, y, .21), .018, BARK)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(x + .08, y, .18))
    obj = bpy.context.object
    obj.scale = (.28, .21, .09)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    attach(obj, "Low sage crown", LEAF if index % 2 else TIPS)

manifest = {}
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
    assert radius <= radius_limit and height <= height_limit, (name, radius, height)
    manifest[name] = {"radius": round(radius, 4), "height": round(height, 4),
                      "radius_limit": radius_limit, "height_limit": height_limit}
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + ".glb")), export_format="GLB",
                              use_selection=True, export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/environment/SupplyKit.blend"))
(ROOT / "art/environment/supply-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest))
