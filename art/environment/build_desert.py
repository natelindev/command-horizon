"""Original editable desert kit. Blender Z-up, glTF/Godot Y-up.
Interior shelves preserve the shipped 5.8 m / 1.15 m gameplay envelopes.
Tall mesas and extraction infrastructure are exclusively exterior scenery.
"""
import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/environment/desert"
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


begin("SandstoneShelfA", 5.8, 1.15)
rock("West eroded shelf", (0,0,0), 5.67, 1.09, 81)
rock("Split western cap", (-2.8,.7,.75), 1.45, .29, 24)
rubble(130, 11, 5.2)

begin("SandstoneShelfB", 5.8, 1.15)
rock("Quarried low bench", (0,0,0), 5.65, .72, 204)
# Low remnants preserve the same sight/air clearance as the old sandstone shelf.
box("Ruined weigh-house floor", (0,.25,.76), (4.1,2.5,.13), CONCRETE,.05,-.13)
for x in [-1.75,1.75]:
    box("Collapsed portal upright", (x,.25,.93), (.23,2.6,.28), EDGE,.035,-.13)
for x in [-1.1,-.4,.3,1]:
    box("Exposed floor rail", (x,.2,.85), (.08,2.1,.08), RUST,.015,-.13)
box("Bent loading ramp", (1.2,-1.8,.63), (2.1,.85,.11), IRON,.025,.4)
for x in [-.7,0,.7]:
    box("Faded loading stripe", (x,-.6,.834), (.34,.10,.01), OCHRE,0,-.13)
rubble(222, 10, 5.2)

begin("SandstoneShelfC", 5.8, 1.15)
rock("Fractured dry island", (0,0,0), 5.68, .92, 392)
rock("Stepped eastern crown", (1.5,.2,.68), 2.7,.42,58)
rock("Weathered rim", (-2.9,-1,.47),1.65,.41,83)
rubble(437, 12, 5.2)

begin("SandstoneShelfD", 5.8, 1.15)
rock("Abandoned utility bench", (0,0,0), 5.66, .74, 579)
for x in [-1.5,1.5]:
    cylinder("Buried valve base", (x,.5,.88), .42,.22,IRON)
    cylinder("Rusted valve cap", (x,.5,1.015),.48,.06,RUST)
beam("Old utility pipe", (-2.8,-.7,.9),(2.7,-.7,.9),.16,RUST)
for x in [-2,-.8,.4,1.6]:
    cylinder("Pipe anchor", (x,-.7,.75),.22,.12,CONCRETE)
box("Collapsed maintenance cover", (0,1.4,.91),(2.2,.8,.1),IRON,.04,.22)
rubble(547, 10, 5.2)

for index in range(3):
    begin("CanyonMesa"+str(index+1), 11.0, 10.0)
    rock("Wind cut canyon face", (0,0,0), 10.1, [7.3,9.0,6.1][index], 911+index*137, False,
         [(1.04,.62),(.78,1.06),(1.02,.78)][index])
    rock("Stepped sandstone spur", (5.0,-1,.01), 3.9, 2.9, 82+index)
    for chip in range(7):
        angle = chip*.9
        rock("Canyon scree", (8.0*math.cos(angle),8.0*math.sin(angle),.01),
             .45 + (chip%3)*.23,.35+(chip%2)*.25,701+chip)

begin("DryScrub", 1.8, .65)
for index,(x,y,height) in enumerate([(-.6,-.2,.36),(.55,.3,.53),(.2,-.7,.28)]):
    beam("Dry shrub stem",(x,y,.015),(x+.06,y,height*.7),.026,BARK)
    for tip in range(4):
        angle = tip*math.tau/4+index
        end=(x+math.cos(angle)*.31,y+math.sin(angle)*.31,height)
        beam("Dry shrub branch",(x,y,height*.42),end,.018,BARK)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=end)
        obj=bpy.context.object
        obj.scale=(.22,.19,.11)
        attach(obj,"Drought sage crown",LEAF if tip%2 else TIPS)

begin("FrontierExtractionRig", 6.0, 9.2)
pad()
for x in [-1.1,1.1]:
    for y in [-1.1,1.1]:
        beam("Tapered extraction tower",(x,y,.25),(x*.54,y*.54,7.9),.11,IRON)
for z in [1.4,3.3,5.2,7.1]:
    width=1.1-z*.058
    for y in [-width,width]:
        beam("Tower cross tie",(-width,y,z),(width,y,z),.075,IRON)
        beam("Tower diagonal",(-width,y,z-1.2),(width,y,z+.3),.055,RUST)
    for x in [-width,width]:
        beam("Tower side tie",(x,-width,z),(x,width,z),.075,IRON)
box("Hoist head",(0,0,8.08),(1.85,1.4,.5),IRON,.07)
beam("Hoist cable",(0,0,7.8),(0,0,.6),.026,DARK)
for x in [-.85,.85]:
    beam("Tower ladder rail",(x,-1.2,.35),(x*.7,-.8,7.6),.032,STEEL)
for index in range(20):
    z=.5+index*.35
    w=.85-z*.035
    y=-1.2+z*.052
    beam("Tower ladder rung",(-w,y,z),(w,y,z),.023,STEEL)
cylinder("Old extraction tank",(2.4,.9,1.1),.85,1.75,IRON)
cylinder("Tank rim",(2.4,.9,2.02),.90,.12,RUST)
box("Compressor",(-2.4,.2,.87),(1.2,2.25,1.2),IRON,.09)
for y in [-.7,-.35,0,.35,.7]:
    box("Compressor vent",(-3.015,y,.9),(.05,.1,.65),DARK,.01)
beam("Buried feeder",(-2,-1.6,.34),(2.6,-1.6,.34),.14,RUST)
box("Numbered rig plate",(0,-.78,6.6),(.8,.04,.62),OCHRE,.01)

begin("AbandonedFreightBay", 6.0, 3.2)
pad()
for x in [-2.4,2.4]:
    for y in [-1.8,1.8]:
        beam("Loading canopy post",(x,y,.25),(x,y,2.7),.08,IRON)
    beam("Canopy roof bearer",(x,-1.9,2.7),(x,1.9,2.7),.10,RUST)
for y in [-1.8,-.6,.6,1.8]:
    beam("Exposed canopy rafter",(-2.5,y,2.7),(2.5,y,2.7),.085,IRON)
for y in [.65,1.0,1.35,1.7]:
    box("Remaining corrugated roof",(0,y,2.77),(5.1,.27,.065),IRON,.015)
box("Salvaged machine crate",(-1,.5,.73),(1.5,1.6,.92),DARK,.08)
for x in [-1.65,-.35]:
    box("Crate steel strap",(x,.5,.75),(.09,1.69,1.0),RUST,.015)
box("Collapsed roof sheet",(1.8,-1.9,.35),(1.7,1.15,.08),IRON,.025,.35)

manifest = {}
for name, asset, radius_limit, height_limit in assets:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in asset.objects:
        obj.select_set(True)
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    points = [evaluated.matrix_world @ vertex.co for obj in asset.objects if obj.type=="MESH"
              for evaluated in [obj.evaluated_get(deps)] for vertex in evaluated.data.vertices]
    radius = max(math.hypot(p.x,p.y) for p in points)
    height = max(p.z for p in points)
    assert radius <= radius_limit and height <= height_limit, (name,radius,height)
    manifest[name] = {"radius":round(radius,4),"height":round(height,4),
                      "radius_limit":radius_limit,"height_limit":height_limit,
                      "interior":name.startswith("SandstoneShelf")}
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")),export_format="GLB",
                              use_selection=True,export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"art/environment/DesertKit.blend"))
(ROOT/"art/environment/desert-manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print(json.dumps(manifest))
