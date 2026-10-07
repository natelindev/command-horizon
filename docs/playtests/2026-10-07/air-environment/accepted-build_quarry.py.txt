"""Original editable Air Corridor quarry kit. Blender Z-up, Godot Y-up.
Playable benches/containers fit existing navigation and sight envelopes.
Tall processing infrastructure is reserved for the non-playable exterior.
"""
import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/environment/quarry"
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


STONE = [material("Quarry shale " + str(i), color) for i, color in enumerate([
    (.20, .245, .255), (.25, .285, .29), (.275, .31, .315),
    (.30, .325, .32), (.235, .265, .28), (.32, .345, .34)])]
DUST = material("Quarry weathered cap", (.32, .345, .34))
CONCRETE = material("Abandoned freight concrete", (.32, .35, .34))
EDGE = material("Fractured concrete", (.46, .49, .47))
IRON = material("Weathered utility green", (.15, .23, .235), .4)
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


begin("QuarryBenchA", 6.5, 3.0)
box("Continuous cut foundation", (0,0,.25), (5.8,11.3,.48), STONE[0], .2)
rock("Cut shale bench", (0, 0, 0), 6.55, 2.83, 13101, stretch=(.89, 1))
rubble(13102, 18, 6.0)
for y in [-2.7, -1.3, .2, 1.5, 2.8]:
    box("Abandoned drill scar", (-4.05,y,1.4), (.035,.09,1.15), DARK, 0)

begin("QuarryBenchB", 6.5, 3.0)
box("Continuous cut foundation", (0,0,.25), (5.8,11.3,.48), STONE[0], .2)
rock("Quarry lower bench", (0, 0, 0), 6.55, 2.2, 13111, stretch=(.9,1))
rock("Broken upper bench", (1.1,.3,1.8), 3.7, 1.05, 13112, stretch=(1,.8))
rubble(13113, 18, 6.0)

begin("QuarryBenchC", 6.5, 3.0)
box("Continuous cut foundation", (0,0,.25), (5.8,11.3,.48), STONE[0], .2)
rock("Slumped shale cutting", (0,0,0), 6.55, 1.7, 13121, stretch=(.87,1))
rock("Angular crown", (-1.4,.3,1.3), 3.4, 1.65, 13122)
rubble(13123, 18, 6.0)

for name, paint in [("QuarryContainerA", IRON), ("QuarryContainerB", OCHRE)]:
    begin(name, 3.0, 3.0)
    box("Freight container", (0,0,.78), (2.9,4.8,1.5), paint,.045)
    box("Inset roof", (0,0,1.56), (2.7,4.6,.09), STEEL,.015)
    for y in [-2.1,-1.4,-.7,0,.7,1.4,2.1]:
        for x in [-1.47,1.47]:
            box("Pressed side rib", (x,y,.8), (.055,.085,1.35), STEEL,.008)
    for x in [-1.2,0,1.2]:
        box("Door vertical seam", (x,-2.415,.8), (.055,.028,1.36), DARK,.005)
    for x in [-.42,.42]:
        beam("Door locking bar", (x,-2.45,.25), (x,-2.45,1.35),.028,STEEL)
    box("Faded freight identity plate", (-.6,-2.45,1.18), (.6,.025,.24), EDGE,.008)
    for x in [-1.3,1.3]:
        for y in [-2.25,2.25]:
            box("Corner casting", (x,y,.1), (.22,.22,.2), RUST,.015)

begin("QuarryCrusher", 10.0, 11.0)
box("Processing pad", (0,0,.12), (12,10,.22), CONCRETE,.1)
for x in [-3.3,3.3]:
    for y in [-2.6,2.6]:
        beam("Crusher steel column", (x,y,.2), (x,y,7.4),.15,IRON)
    beam("Frame diagonal", (x,-2.6,.4), (x,2.6,5.8),.09,RUST)
box("Crusher housing", (0,0,5.7), (6.2,4.8,3.0), IRON,.08)
box("Dust hood", (0,0,7.35), (7.4,5.8,.22), STEEL,.04)
box("Access deck", (0,-3.5,4.1), (8,1.3,.15), RUST,.025)
for x in [-3.8,-2,-.2,1.6,3.8]:
    beam("Deck railing post", (x,-4,4.15), (x,-4,5.25),.04,STEEL)
beam("Deck handrail", (-3.8,-4,5.25), (3.8,-4,5.25),.055,OCHRE)
for z in [i*.4+.4 for i in range(10)]:
    beam("Access ladder rung", (4,-3.9,z), (4,-3.1,z),.04,STEEL)
for y in [-3.9,-3.1]:
    beam("Ladder upright", (4,y,.3), (4,y,4.5),.05,IRON)
cylinder("Cyclone separator", (-4.5,1,4.8), .85,6.4,STEEL)
beam("Dust extraction duct", (-4.5,1,8), (-.5,1,8),.25,RUST)
beam("Exhaust stack", (-4.5,1,8), (-4.5,1,10.2),.22,STEEL)
box("Control cabinet", (3.5,3.4,1.1), (2,1.4,2), OCHRE,.055)
for x in [-2.5,0,2.5]:
    rock("Aggregate discharge pile", (x,1,.12),1.65,1.4,13200+int(x*10))

begin("QuarryConveyor", 12.0, 8.0)
box("Loading pad", (0,0,.1), (17,5,.2), CONCRETE,.08)
box("Feed hopper", (-5,0,2.8), (3.2,3.4,3.1), IRON,.06)
for x in [-6.4,-3.6]:
    for y in [-1.4,1.4]:
        beam("Hopper leg", (x,y,.2), (x,y,2),.10,RUST)
for y in [-.8,.8]:
    beam("Long conveyor truss", (-3.5,y,3.5), (7,y,6.3),.12,IRON)
    for i in range(9):
        x=-3.5+i*1.2; z=3.5+i*.32
        beam("Conveyor lattice", (x,y,z), (x+1.2,y,z+.8),.045,STEEL)
for i in range(20):
    x=-3.5+i*.54; z=3.55+i*.144
    box("Conveyor belt segment", (x,0,z), (.57,1.4,.12), DARK,.01)
for x,z in [(-1,4.3),(3,5.35),(6.5,6.25)]:
    for y in [-.9,.9]:
        beam("Conveyor support", (x,y,.2), (x,y,z),.10,IRON)
    beam("Support cross brace", (x,-.9,.3), (x,.9,z),.06,RUST)
rock("Discharged aggregate", (6.7,0,.2), 2.6,2.6,13199)

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
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/environment/QuarryKit.blend"))
(ROOT / "art/environment/quarry-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest))
