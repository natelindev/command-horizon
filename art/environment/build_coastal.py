"""Original editable coastal kit. Blender Z up; vessels and birds face -Y."""
import bpy
import json
import math
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


begin("HarborCrane", 7, 8.2)
box("Crane foundation", (0, 0, .18), (5.4, 5.6, .36), concrete, .12)
for x in [-1.9, 1.9]:
    for y in [-2.1, 2.1]:
        box("Gantry foot", (x, y, .6), (.8, .8, .65), steel)
        beam("Gantry upright", (x, y, .6), (x * .75, y * .8, 5.0), .17, yellow)
    beam("Side cross brace", (x, -2.1, 1.1), (x * .75, 1.68, 4.6), .10, rust)
    beam("Side cross brace", (x, 2.1, 1.1), (x * .75, -1.68, 4.6), .10, rust)
box("Operator platform", (0, 0, 5.03), (4.6, 4.6, .28), steel)
cylinder("Turntable", (0, 0, 5.36), 1.35, .42, dark, 20)
box("Crane machinery", (-1.5, .3, 5.95), (2.0, 2.4, .95), yellow, .09)
box("Cab glazing", (.7, -1.0, 6.15), (1.55, 1.45, 1.25), glass, .09)
box("Cab roof", (.7, -1, 6.84), (1.75, 1.65, .16), yellow)
for x in [.05, 1.35]:
    box("Cab pillar", (x, -1.72, 6.15), (.085, .09, 1.26), steel)
for y in [-.43, .43]:
    beam("Lattice boom lower", (-3.6, y, 6.3), (6.0, y, 6.8), .13, yellow)
    beam("Lattice boom upper", (-3.6, y, 7.6), (6.0, y, 7.45), .11, yellow)
    for index in range(6):
        x = -3.6 + index * 1.6
        beam("Boom diagonal", (x, y, 6.3 + (x + 3.6) * .052),
             (x + 1.6, y, 7.6 - (x + 5.2) * .016), .055, rust)
box("Counterweight", (-3.3, 0, 6.5), (1.3, 1.6, 1.6), concrete)
for y in [-.2, .2]:
    beam("Hoist cable", (5.7, y, 6.85), (5.7, y, 2.4), .025, dark)
box("Hook block", (5.7, 0, 2.25), (.4, .6, .4), yellow)
beam("Hook shank", (5.7, 0, 2.1), (5.7, 0, 1.8), .08, steel)
beam("Hook crook", (5.7, 0, 1.8), (5.45, 0, 1.85), .08, steel)
for y in [-2.18, 2.18]:
    for x in [-2, 0, 2]:
        beam("Platform railing post", (x, y, 5.15), (x, y, 5.85), .035, yellow)
    beam("Platform handrail", (-2, y, 5.85), (2, y, 5.85), .04, yellow)
for x in [-2.25, -1.8]:
    beam("Access ladder rail", (x, 2.3, .45), (x, 2.3, 5.25), .045, steel)
for index in range(14):
    beam("Access ladder rung", (-2.25, 2.3, .6 + index * .32), (-1.8, 2.3, .6 + index * .32), .03)

begin("HarborBeacon", 3, 7.5)
cylinder("Beacon footing", (0, 0, .22), 2.65, .44, concrete, 16)
cylinder("Stone tower", (0, 0, 2.5), 1.35, 4.5, concrete, 12)
for z in [.65, 2.45, 4.65]:
    cylinder("Tower band", (0, 0, z), 1.39, .18, white, 12)
box("Service door", (0, -1.36, 1.25), (.72, .07, 1.65), blue)
for z in [2.9, 3.9]:
    box("Tower window", (0, -1.37, z), (.45, .065, .48), glass)
cylinder("Gallery", (0, 0, 4.85), 2.0, .18, steel, 16)
cylinder("Lantern glazing", (0, 0, 5.67), .83, 1.3, lamp, 12)
for index in range(8):
    angle = index * math.tau / 8
    x, y = math.cos(angle), math.sin(angle)
    beam("Lantern mullion", (.85 * x, .85 * y, 5), (.85 * x, .85 * y, 6.3), .04, blue)
    beam("Gallery post", (1.83 * x, 1.83 * y, 4.95), (1.83 * x, 1.83 * y, 5.6), .035, steel)
    nxt = angle + math.tau / 8
    beam("Gallery railing", (1.83 * x, 1.83 * y, 5.6),
         (1.83 * math.cos(nxt), 1.83 * math.sin(nxt), 5.6), .035, steel)
bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=1.13, radius2=.2, depth=.6, location=(0, 0, 6.6))
attach(bpy.context.object, "Lantern roof", blue)
beam("Weather mast", (0, 0, 6.7), (0, 0, 7.3), .045)


def hull(length, width, height, name):
    outline = [(-width * .48, length * .46), (width * .48, length * .46),
               (width * .5, -length * .22), (width * .33, -length * .43),
               (0, -length * .5), (-width * .33, -length * .43), (-width * .5, -length * .22)]
    vertices = [(x * .75, y * .9, -.45) for x, y in outline]
    vertices += [(x, y, height) for x, y in outline]
    count = len(outline)
    faces = [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    faces += [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    mesh(name, vertices, [tuple(reversed(face)) for face in faces], blue)
    for index in range(count):
        a, b = outline[index], outline[(index + 1) % count]
        beam("Gunwale", (*a, height + .06), (*b, height + .06), .06, dark)


begin("CargoBarge", 7, 4.4)
hull(12.0, 3.6, .55, "Cargo hull")
box("Weather deck", (0, .1, .61), (3.15, 9.6, .12), steel)
for y in [-2.7, .0]:
    box("Freight container", (0, y, 1.35), (2.7, 2.3, 1.38), green if y < 0 else red, .04)
    for x in [-1.36, 1.36]:
        for step in range(7):
            box("Container corrugation", (x, y - .95 + step * .31, 1.35), (.055, .04, 1.3), steel, .008)
box("Bridge cabin", (0, 3.5, 1.6), (2.75, 2.6, 1.8), white, .08)
box("Bridge front windows", (0, 2.17, 2.0), (2.45, .05, .62), glass)
for x in [-1.39, 1.39]:
    box("Bridge side windows", (x, 3.2, 2.0), (.05, 1.55, .62), glass)
box("Bridge roof", (0, 3.5, 2.55), (2.95, 2.8, .15), white)
cylinder("Exhaust stack", (.7, 4.2, 3.1), .27, 1.05, red)
beam("Navigation mast", (-.55, 3.3, 2.6), (-.55, 3.3, 4.1), .06)
beam("Radar crossbar", (-1.1, 3.3, 3.7), (0, 3.3, 3.7), .065)
for x in [-1.76, 1.76]:
    for y in [-3, 0, 3]:
        sphere("Side fender", (x, y, .25), (.16, .33, .28), dark)

begin("HarborTug", 2.5, 1.4)
hull(4.5, 1.6, .24, "Launch hull")
box("Launch deck", (0, .2, .31), (1.28, 3.1, .13), white)
box("Small wheelhouse", (0, .5, .73), (1.0, 1.15, .70), glass, .08)
box("Ochre cabin roof", (0, .5, 1.12), (1.2, 1.35, .12), yellow, .05)
for x in [-.46, .46]:
    box("Launch window pillar", (x, -.08, .76), (.08, .06, .65), white)
box("Engine cover", (0, 1.4, .5), (.9, .58, .30), blue)
sphere("Bow lamp", (0, -1.6, .48), (.09, .10, .10), lamp)
for x in [-.78, .78]:
    for y in [-.8, .9]:
        sphere("Launch fender", (x, y, .15), (.11, .21, .15), dark)

begin("CoastalGull", 1.1, .6)
sphere("Gull body", (0, 0, .20), (.13, .28, .12), white)
sphere("Gull head", (0, -.25, .24), (.115, .13, .12), white)
box("Beak", (0, -.39, .23), (.055, .16, .055), yellow, .01)
for x in [-.10, .10]:
    sphere("Eye", (x, -.3, .28), (.017, .017, .017), dark)
for side, sign in [("Left", -1), ("Right", 1)]:
    vertices = [(sign * .08, -.10, .24), (sign * .55, -.03, .24),
                (sign * .91, .24, .18), (sign * .72, .35, .18),
                (sign * .35, .23, .24), (sign * .08, .16, .24)]
    wing = mesh(side + " flight feathers", vertices, [(0, 1, 2, 3, 4, 5), (5, 4, 3, 2, 1, 0)], white)
    tip = mesh(side + " black feather tips", [vertices[1], vertices[2], vertices[3], vertices[4]],
               [(0, 1, 2, 3), (3, 2, 1, 0)], dark)
    pivot(side + "Wing", (sign * .08, .03, .24), [wing, tip])
mesh("Tail feathers", [(-.1, .15, .2), (.1, .15, .2), (.13, .41, .2), (-.13, .41, .2)],
     [(0, 1, 2, 3), (3, 2, 1, 0)], white)

begin("ShorePines", 3.6, 5.5)
for index, (x, y, height) in enumerate([(-1.25, -.7, 4.7), (1.25, .6, 5.25), (-.4, 1.1, 3.4)]):
    cylinder("Pine trunk", (x, y, height * .43), .16, height * .86, bark, 8)
    for level in range(3):
        z = height * (.38 + level * .19)
        radius = (1.32 - level * .27) * height / 5.25
        bpy.ops.mesh.primitive_cone_add(vertices=9, radius1=radius, radius2=.03,
                                        depth=height * .42, location=(x, y, z))
        attach(bpy.context.object, "Wind-shaped pine crown", needles if level < 2 else tips)
for x, y in [(-2, 1), (1.8, -1), (0, -1.8)]:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=.5, location=(x, y, .28))
    obj = bpy.context.object
    obj.scale.z = .45
    attach(obj, "Coastal scrub", tips)

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
                      "radius_limit": radius_limit, "height_limit": height_limit}
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + ".glb")), export_format="GLB",
                               use_selection=True, export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/environment/CoastalKit.blend"))
(ROOT / "art/environment/coastal-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest))
