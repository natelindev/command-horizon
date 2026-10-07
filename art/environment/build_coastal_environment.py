"""Original coastal environment extension. Blender Z up; deterministic geometry."""
import bpy
import json
import math
import random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/environment/coastal"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
assets = []


def material(name, color, metal=0, roughness=.75):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = roughness
    return result


concrete = material("Salt-stained concrete", (.43, .46, .43))
yellow = material("Faded harbor ochre", (.66, .43, .12), .25)
steel = material("Galvanized steel", (.37, .44, .46), .7)
rust = material("Weathered edges", (.32, .14, .065), .3)
dark = material("Rubber and recesses", (.032, .049, .058))
glass = material("Blue bridge glazing", (.075, .18, .23), .4, .3)
white = material("Warm white paint", (.76, .78, .72), .15)
red = material("Hull oxide red", (.32, .085, .055), .2)
blue = material("Blue-green hull", (.075, .22, .25), .3)
green = material("Faded green freight", (.18, .30, .23), .2)
lamp = material("Warm beacon glass", (.90, .63, .22), .1, .25)
bark = material("Coastal pine bark", (.23, .17, .11))
needles = material("Pine needles", (.12, .24, .20))
tips = material("Sunlit pine tips", (.22, .33, .24))


def begin(name, radius, height):
    global collection
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    assets.append((name, collection, radius, height))


def attach(obj, name, mat, bevel=0):
    obj.name = name
    for previous in list(obj.users_collection):
        previous.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Weathered edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        obj.modifiers.new("Face normals", "WEIGHTED_NORMAL")
    return obj


def box(name, position, dimensions, mat, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=position)
    obj = bpy.context.object
    obj.scale = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return attach(obj, name, mat, bevel)


def cylinder(name, position, radius, depth, mat=steel, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=position)
    return attach(bpy.context.object, name, mat, .018)


def beam(name, start, end, radius=.07, mat=steel):
    start, end = Vector(start), Vector(end)
    obj = cylinder(name, (start + end) / 2, radius, (end - start).length, mat, 8)
    obj.rotation_euler = (end - start).to_track_quat("Z", "Y").to_euler()
    return obj


def mesh(name, vertices, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    data.materials.append(mat)
    return obj


def sphere(name, position, dimensions, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=1, location=position)
    obj = bpy.context.object
    obj.scale = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return attach(obj, name, mat)


def pivot(name, position, children):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.location = position
    for child in children:
        child.parent = obj
        child.location -= Vector(position)
    return obj


stone = material("Coastal basalt", (.27, .31, .30))
stone_light = material("Coastal weathered strata", (.39, .41, .36))
moss = material("Salt meadow moss", (.27, .31, .17))
wood = material("Bleached timber", (.40, .34, .25))
freight_blue = material("Faded freight blue", (.15, .28, .32), .15)
roof = material("Oxidized green roof", (.18, .29, .27), .25)


def rock(name, center, span, height, seed):
    rng = random.Random(seed)
    count = 11
    angles = [i * math.tau / count for i in range(count)]
    outline = [(math.cos(a) * span[0] * rng.uniform(.82, 1),
                math.sin(a) * span[1] * rng.uniform(.82, 1)) for a in angles]
    vertices = []
    for scale, z, shift in [(1, -.07, 0), (.98, height * .23, .02),
                            (.88, height * .53, -.12), (.59, height * .90, -.22)]:
        for x, y in outline:
            vertices.append((center[0] + x * scale + shift * span[0],
                             center[1] + y * scale,
                             center[2] + z * rng.uniform(.86, 1.10)))
    vertices.append((center[0] - span[0]*.19, center[1], center[2] + height))
    faces = [tuple(range(count - 1, -1, -1))]
    for layer in range(3):
        for i in range(count):
            j = (i + 1) % count
            faces.append((layer*count+i, layer*count+j, (layer+1)*count+j, (layer+1)*count+i))
    for i in range(count):
        faces.append((3*count+i, 3*count+(i+1)%count, 4*count))
    obj = mesh(name, vertices, faces, stone)
    obj.data.materials.append(stone_light)
    obj.data.materials.append(moss)
    for i, polygon in enumerate(obj.data.polygons):
        polygon.material_index = 2 if i > 3*count and seed % 2 else (1 if i % 7 in [2,3] else 0)
    return obj


def container(name, center, mat, turn=0):
    before = set(collection.objects)
    x, y, z = center
    box(name + " body", (x,y,z+1.05), (2.35,5.65,2.10), mat, .07)
    for side in [-1,1]:
        for index in range(12):
            box("Corrugated side", (x+side*1.19,y-2.55+index*.46,z+1.07), (.075,.07,1.85), mat, .012)
        for end in [-1,1]:
            box("Container corner", (x+side*1.16,y+end*2.78,z+1.06), (.12,.13,2.12), rust)
        box("Roof edge", (x+side*1.12,y,z+2.12), (.10,5.55,.09), steel)
        box("Door panel", (x+side*.57,y-2.86,z+1.06), (1.08,.06,1.92), mat)
        beam("Door locking bar", (x+side*.48,y-2.91,z+.22), (x+side*.48,y-2.91,z+1.85), .035, steel)
    box("Freight label", (x+1.24,y-.7,z+1.28), (.012,1.2,.38), white, 0)
    if turn:
        pivot(name + " turn", (x,y,z), list(set(collection.objects)-before)).rotation_euler.z = turn


begin("CoastalPineStand", 3.6, 5.5)
for index,(x,y,h) in enumerate([(-1.2,-.5,4.7),(.95,.7,5.1),(-.7,1.3,3.55)]):
    lean = .30 + index*.08
    beam("Weather bent trunk", (x,y,.05), (x+lean,y-.15,h*.90), .13, bark)
    for branch in range(5):
        angle = branch*2.39+index
        z = h*(.38+branch*.11)
        reach = 1.07-branch*.095
        end = (x+lean+math.cos(angle)*reach,y+math.sin(angle)*reach,z+.25)
        beam("Exposed pine limb", (x+lean*.6,y,z-.2), end, .055, bark)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=end)
        obj=bpy.context.object
        obj.scale=(reach*.78,reach*.73,.40)
        attach(obj,"Wind flattened crown",needles if branch<3 else tips)
for index,(x,y) in enumerate([(-2,1.1),(1.8,-1.3),(-.2,-1.9)]):
    rock("Mossed ground stone",(x,y,0),(.62,.48),.31,40+index)
    for stem in range(4):
        beam("Dry grass",(x+.13*stem,y,.04),(x+.13*stem+.1,y+.12,.23),.012,moss)

begin("CoastalHeadland", 10.5, 7.5)
rock("Basalt headland footing",(0,0,0),(8.8,5.7),3.0,91)
rock("Fractured sea stack",(-2.2,.7,1.3),(4.8,4.1),5.8,42)
rock("Low seaward shelf",(5,-1,0),(4.1,3.9),2.2,32)
for i in range(5):
    rock("Tumbled shore block",(-5+i*2.6,-4.0,.05),(1.2,.9),.7+i*.1,200+i)

begin("HarborBreakwater", 8.5, 2.9)
box("Old sea wall core",(0,0,.75),(14.3,2.4,1.5),concrete,.15)
box("Walkable breakwater cap",(0,0,1.56),(14.6,2.7,.18),stone_light,.07)
for i in range(8):
    x=-6.4+i*1.8
    rock("Wave armor",(x,-1.8,.15),(1.35,1.05),1.10,500+i)
    box("Salt stained coping joint",(x,0,1.66),(.035,2.55,.02),dark,0)
for x in [-5.4,5.4]:
    cylinder("Mooring bollard",(x,.3,1.95),.19,.57,dark,10)
    cylinder("Bollard cap",(x,.3,2.22),.29,.09,steel,10)
for x in [-6.7,-3.4,0,3.4,6.7]:
    beam("Guard rail upright",(x,1,1.67),(x,1,2.44),.035,yellow)
beam("Outer rail",(-6.7,1,2.44),(6.7,1,2.44),.04,yellow)

begin("PortPumpHouse", 7.4, 5.8)
box("Pump station apron",(0,0,.13),(9.5,8.2,.26),concrete,.10)
box("Service house",(-.7,.25,1.75),(5.8,4.9,3.25),concrete,.08)
box("Standing seam roof",(-.7,.25,3.43),(6.2,5.3,.23),roof,.04)
for i in range(11):
    box("Roof seam",(-3.45+i*.55,.25,3.56),(.04,5.18,.045),steel,.008)
for x in [-2.5,-.7,1.1]:
    box("Salt darkened window",(x,-2.23,2.15),(1.15,.06,.75),glass)
    box("Window sill",(x,-2.32,1.76),(1.28,.22,.10),white)
box("Roller door",(-3.64,.35,1.38),(.07,2.1,2.3),blue)
for z in [.5,.8,1.1,1.4,1.7,2.0,2.3]:
    box("Roller door seam",(-3.70,.35,z),(.03,2.0,.028),steel,.004)
for y in [-1,1.2]:
    cylinder("Pump motor",(3.15,y,.76),.62,1.04,blue,16)
    beam("Outflow pipe",(3.15,y,.45),(4.0,y,.45),.18,steel)
    beam("Outflow elbow",(4,y,.45),(4,y,-.1),.18,steel)
beam("Station vent",(-2.7,1.8,3.5),(-2.7,1.8,5.3),.17,rust)
box("Vent hood",(-2.7,1.8,5.32),(.65,.65,.18),steel)
box("Harbor maintenance sign",(-.7,-2.31,3.06),(3.8,.07,.42),blue)
for i in range(7):
    box("Sign stencil",(-2.12+i*.46,-2.36,3.06),(.22,.015,.16),white,0)

begin("PortFreightYard", 9.0, 4.7)
box("Freight pad",(0,0,.08),(12.8,10.5,.16),concrete,.06)
container("Blue freight",(-3,-.8,.16),freight_blue)
container("Green freight",(-.35,-.6,.16),green)
container("Upper red freight",(-2.9,-.75,2.28),red)
container("Retired freight",(3.1,1.2,.16),yellow,.05)
for x in [-5.9,5.9]:
    box("Yard safety edge",(x,0,.17),(.12,9.7,.02),yellow,0)
for i in range(4):
    box("Stored timber",(1.7+i*.33,-3.8,.42),(.23,2.1,.55),wood)

begin("PortUtilities", 8.8, 6.0)
box("Utility plinth",(0,0,.14),(11.5,10.2,.28),concrete,.06)
for x,y in [(-2.5,0),(2.2,1.5)]:
    cylinder("Vertical water tank",(x,y,2.35),1.8,4.3,white,24)
    cylinder("Tank roof",(x,y,4.54),1.84,.16,steel,24)
    for z in [1.1,3.6]:
        cylinder("Weathered tank band",(x,y,z),1.83,.12,rust,24)
    cylinder("Roof vent",(x,y,4.9),.20,.65,steel,12)
    for offset in [-.25,.25]:
        beam("Tank ladder",(x+offset,y-1.86,.3),(x+offset,y-1.86,4.9),.045,steel)
    for step in range(13):
        z=.4+step*.34
        beam("Tank ladder rung",(x-.25,y-1.91,z),(x+.25,y-1.91,z),.035,steel)
beam("Service manifold",(-4,-3,.55),(4,-3,.55),.20,blue)
for x,y in [(-2.5,0),(2.2,1.5)]:
    beam("Tank drain",(x,y-1.8,.55),(x,-3,.55),.18,steel)
box("Utility control cabinet",(4,-2.2,1.15),(1.0,.8,1.9),green,.05)
box("Control face",(4,-2.63,1.4),(.62,.035,.7),dark)

manifest = {}
for name, asset, radius_limit, height_limit in assets:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in asset.objects:
        obj.select_set(True)
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    points = [evaluated.matrix_world @ vertex.co for obj in asset.objects if obj.type == "MESH"
              for evaluated in [obj.evaluated_get(deps)] for vertex in evaluated.data.vertices]
    radius = max(math.hypot(point.x, point.y) for point in points)
    height = max(point.z for point in points)
    assert radius <= radius_limit and height <= height_limit, (name, radius, height)
    manifest[name] = {"radius": round(radius, 3), "height": round(height, 3),
                      "radius_limit": radius_limit, "height_limit": height_limit,
                      "mesh_objects": sum(obj.type == "MESH" for obj in asset.objects)}
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + ".glb")), export_format="GLB",
                               use_selection=True, export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/environment/CoastalEnvironmentKit.blend"))
(ROOT / "art/environment/coastal-environment-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest))
