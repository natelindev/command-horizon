"""Drylands kit for the desert battlefields. Blender Z-up, Godot Y-up.
Saltwind Basin (salt flats / potash works), Copper Badlands (open-pit copper
mine), Shattered Oasis (date-palm oasis, mud-brick and caravanserai) and
Desert Frontier (Mojave rail outpost). Original procedural geometry; no
textures or external assets.
Run: blender --background --python art/environment/build_drylands.py
"""
import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/environment/drylands"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
assets = []
collection = None


def material(name, color, roughness=0.9, metallic=0.0, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    if emission:
        shader.inputs["Emission Color"].default_value = (*emission, 1)
        shader.inputs["Emission Strength"].default_value = 1.5
    return mat


# Shared palette.
STEEL = material("Weathered steel", (.40, .41, .40), .55, .6)
RUST = material("Rusted steel", (.38, .19, .09), .75, .35)
DARK = material("Dark machinery", (.11, .11, .11), .6, .5)
YELLOW = material("Mine yellow paint", (.78, .58, .12), .55, .2)
CONCRETE = material("Dusty concrete", (.60, .56, .49))
CORRUGATED = material("Faded corrugated cladding", (.70, .68, .62), .6, .3)
WHITE_SALT = material("Harvested salt", (.93, .92, .88), .85)
TIMBER = material("Bleached timber", (.45, .38, .29))
TIMBER_DARK = material("Creosote timber", (.21, .16, .12))
GLASS = material("Dusty glass", (.18, .22, .24), .25)
RUBBER = material("Tyre rubber", (.06, .06, .06), .85)
CANVAS = material("Sun-faded canvas", (.66, .52, .38))
MUD = material("Mud brick", (.66, .51, .36))
MUD_DARK = material("Mud brick shade", (.52, .39, .27))
PLASTER = material("Lime plaster", (.82, .76, .64))
STONE = material("Dressed sandstone", (.72, .60, .44))
WATER = material("Well water", (.10, .17, .16), .15)
# Vegetation.
SALTBUSH = [material("Saltbush %d" % i, c) for i, c in enumerate([(.47, .51, .42), (.56, .58, .48)])]
GREASEWOOD = [material("Greasewood %d" % i, c) for i, c in enumerate([(.30, .38, .20), (.38, .45, .25)])]
TUMBLE = material("Dry tumbleweed", (.55, .44, .30))
FROND = [material("Date palm frond %d" % i, c) for i, c in enumerate(
    [(.20, .32, .13), (.27, .39, .16), (.34, .45, .20)])]
PALM_TRUNK = material("Palm trunk fibre", (.38, .29, .20))
DATES = material("Date clusters", (.62, .33, .10))
OLEANDER = [material("Oleander %d" % i, c) for i, c in enumerate([(.17, .30, .14), (.22, .36, .18)])]
BLOSSOM = material("Oleander blossom", (.88, .48, .58))
JOSHUA = [material("Joshua tree leaves %d" % i, c) for i, c in enumerate([(.34, .40, .20), (.42, .47, .25)])]
JOSHUA_BARK = material("Joshua tree shag", (.40, .33, .24))
CREOSOTE = [material("Creosote %d" % i, c) for i, c in enumerate([(.30, .36, .17), (.37, .42, .21)])]
CHOLLA = material("Cholla spines", (.62, .64, .44))
GRASS = material("Dune grass", (.68, .62, .40))
ORE = [material("Copper ore %d" % i, c) for i, c in enumerate(
    [(.45, .33, .25), (.36, .45, .38), (.52, .40, .30)])]
GYPSUM = [material("Gypsum %d" % i, c) for i, c in enumerate([(.80, .78, .72), (.70, .67, .60)])]
LAMP = material("Floodlight", (1, .95, .8), .3, 0, (1, .92, .75))


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


def limb(a, b, radius, mat, taper=.6, sides=7):
    delta = Vector(b) - Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, radius2=radius * taper,
                                    depth=delta.length, location=(Vector(a) + Vector(b)) / 2)
    obj = bpy.context.object
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return attach(obj, "Limb", mat)


def box(name, point, size, mat, angle=0.0, tilt=(0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler = (tilt[0], tilt[1], angle)
    return attach(obj, name, mat)


def cylinder(name, point, radius, depth, mat, sides=12, axis=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth, location=point)
    obj = bpy.context.object
    if axis == "x":
        obj.rotation_euler.y = math.pi / 2
    elif axis == "y":
        obj.rotation_euler.x = math.pi / 2
    return attach(obj, name, mat)


def cone(name, point, radius, depth, mat, sides=12, top=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, radius2=top, depth=depth,
                                    location=point)
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


def frond(base, angle, length, droop, mat, width=.32):
    """A palm frond: a drooping, tapered leaf strip with a spine."""
    verts, faces = [], []
    steps = 6
    direction = Vector((math.cos(angle), math.sin(angle), 0))
    side = Vector((-math.sin(angle), math.cos(angle), 0))
    for step in range(steps + 1):
        t = step / steps
        centre = Vector(base) + direction * length * t + Vector((0, 0, length * (.35 * t - droop * t * t)))
        half = width * math.sin(math.pi * min(1, t * 1.15 + .05)) * (1.05 - t * .5)
        verts += [centre - side * half, centre + Vector((0, 0, .04)), centre + side * half]
        if step:
            i = (step - 1) * 3
            faces += [(i, i + 3, i + 4, i + 1), (i + 1, i + 4, i + 5, i + 2)]
    mesh = bpy.data.meshes.new("Frond")
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new("Frond", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return attach(obj, "Frond", mat, flat=True)


def shrub(seed, mats, radius, height, clumps=7, bloom=None):
    rng = random.Random(seed)
    for clump in range(clumps):
        angle = rng.uniform(0, math.tau)
        r = rng.uniform(0, radius * .55)
        centre = (math.cos(angle) * r, math.sin(angle) * r, height * rng.uniform(.35, .55))
        size = radius * rng.uniform(.35, .55)
        blob("Shrub clump", centre, (size, size, height * .5), rng.choice(mats), rng, .3, 0)
        if bloom is not None and rng.random() < .6:
            blob("Blossom", (centre[0], centre[1], centre[2] + height * .3),
                 (size * .5, size * .5, height * .15), bloom, rng, .4, 0)


def dune_grass(seed):
    """Open tufts of bent, tapered blades; keep the original scenery envelope."""
    rng = random.Random(seed)
    vertices, faces = [], []
    for tuft in range(5):
        angle = tuft * math.tau / 5
        root = Vector((math.cos(angle) * .42, math.sin(angle) * .42, .008))
        for blade in range(12):
            heading = blade * math.tau / 12 + rng.uniform(-.3, .3)
            outward = Vector((math.cos(heading), math.sin(heading), 0))
            side = Vector((-outward.y, outward.x, 0))
            base = root + outward * rng.uniform(0, .075)
            height = rng.uniform(.32, .69)
            lean = rng.uniform(.12, .34)
            width = rng.uniform(.018, .032)
            middle = base + outward * lean * .38 + Vector((0, 0, height * .65))
            tip = base + outward * lean + Vector((0, 0, height))
            start = len(vertices)
            vertices += [
                base - side * width, base + Vector((0, 0, .008)), base + side * width,
                middle - side * width * .65, middle + Vector((0, 0, .012)),
                middle + side * width * .65, tip,
            ]
            faces += [tuple(start + i for i in face) for face in [
                (0, 3, 4), (0, 4, 1), (1, 4, 5), (1, 5, 2), (3, 6, 4), (4, 6, 5)
            ]]
    mesh = bpy.data.meshes.new("Dune grass blades")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Dune grass blades", mesh)
    bpy.context.scene.collection.objects.link(obj)
    attach(obj, "Dune grass blades", GRASS, flat=True)


# ---------------------------------------------------------------- salt flats

def tumbleweed():
    rng = random.Random(5)
    for index in range(26):
        a = Vector((rng.uniform(-.4, .4), rng.uniform(-.4, .4), rng.uniform(.05, .75)))
        b = a + Vector((rng.uniform(-.5, .5), rng.uniform(-.5, .5), rng.uniform(-.3, .3)))
        limb(a, b, .015, TUMBLE, 1, 4)


def salt_heap(seed):
    rng = random.Random(seed)
    cone("Salt heap", (0, 0, 1.4), 2.6, 2.8, WHITE_SALT, 16, .2)
    for index in range(5):
        angle = rng.uniform(0, math.tau)
        blob("Salt spill", (math.cos(angle) * 2.5, math.sin(angle) * 2.5, .15),
             (.6, .5, .25), WHITE_SALT, rng, .3, 0)


def brine_pump():
    box("Pump house", (0, 0, 1.0), (2.4, 1.8, 2.0), CORRUGATED)
    box("Pump roof", (0, 0, 2.1), (2.6, 2.0, .12), RUST, 0, (.06, 0))
    cylinder("Brine main", (2.2, 0, .45), .22, 2.4, STEEL, 12, "x")
    cylinder("Valve wheel", (1.4, 0, 1.1), .18, .05, YELLOW, 12, "x")
    box("Pump plinth", (0, 0, .08), (3.2, 2.4, .16), CONCRETE)


def potash_plant():
    box("Drying shed", (-1.5, 0, 2.6), (5.5, 4.2, 5.2), CORRUGATED)
    box("Shed roof", (-1.5, 0, 5.3), (5.8, 4.5, .25), RUST)
    box("Roof monitor", (-1.5, 0, 5.7), (5.0, 1.0, .7), CORRUGATED)
    cylinder("Product silo", (2.6, 1.3, 3.0), 1.1, 6.0, STEEL, 16)
    cone("Silo hopper", (2.6, 1.3, -.1 + .7), 1.1, 1.0, STEEL, 16, .25)
    cylinder("Dust stack", (2.4, -1.6, 4.0), .3, 8.0, DARK, 10)
    limb((1.0, -1.0, 4.5), (4.4, -2.6, 1.0), .25, YELLOW, 1, 6)
    for x in [-3.8, .8]:
        box("Loading door", (x, -2.12, 1.4), (1.6, .05, 2.4), DARK)
    box("Plinth", (-.5, 0, .1), (9.5, 6.0, .2), CONCRETE)


def conveyor_run():
    for x in [-3.5, 0, 3.5]:
        for y in [-.45, .45]:
            limb((x, y, 0), (x, y, 2.4), .07, STEEL, 1, 6)
        box("Bent cap", (x, 0, 2.4), (.25, 1.2, .15), STEEL)
    box("Conveyor deck", (0, 0, 2.6), (8.0, 1.0, .25), YELLOW)
    box("Belt", (0, 0, 2.75), (8.0, .7, .06), RUBBER)
    box("Cover hood", (0, 0, 3.05), (8.0, 1.05, .08), CORRUGATED, 0, (.0, 0))


def pylon():
    height = 13.0
    for corner in [(-1, -1), (1, -1), (1, 1), (-1, 1)]:
        limb((corner[0] * 1.6, corner[1] * 1.6, 0), (corner[0] * .4, corner[1] * .4, height),
             .07, STEEL, .7, 6)
    for level in range(1, 7):
        z = level * height / 7
        r = 1.6 - 1.2 * level / 7
        for edge in range(4):
            a = [(-1, -1), (1, -1), (1, 1), (-1, 1)][edge]
            b = [(-1, -1), (1, -1), (1, 1), (-1, 1)][(edge + 1) % 4]
            limb((a[0] * r, a[1] * r, z), (b[0] * r, b[1] * r, z), .03, STEEL, 1, 5)
    for z, span in [(height - 1.5, 3.4), (height - 3.5, 2.6)]:
        box("Crossarm", (0, 0, z), (span * 2, .2, .2), STEEL)
        for x in [-span, span]:
            cylinder("Insulator string", (x, 0, z - .45), .08, .8, CONCRETE, 8)


# ---------------------------------------------------------------- copper mine

def haul_truck():
    for x in [-2.0, 2.0]:
        for y in [-1.55, 1.55]:
            cylinder("Wheel", (x, y, .95), .95, .75, RUBBER, 16, "y")
    box("Chassis", (0, 0, 1.5), (5.6, 2.6, .6), DARK)
    box("Dump body", (-.6, 0, 2.7), (4.4, 3.4, 1.8), YELLOW, 0, (0, -.08))
    box("Canopy", (1.9, 0, 3.75), (1.6, 3.5, .15), YELLOW)
    box("Cab", (2.3, .9, 2.6), (1.2, 1.1, 1.2), YELLOW)
    box("Cab glass", (2.92, .9, 2.75), (.04, .9, .6), GLASS)
    box("Grille", (2.95, -.4, 2.0), (.15, 1.6, 1.1), DARK)
    box("Ladder", (2.9, -1.3, 1.6), (.08, .5, 1.6), STEEL)


def electric_shovel():
    box("Crawler left", (0, -1.8, .55), (5.5, 1.1, 1.1), DARK)
    box("Crawler right", (0, 1.8, .55), (5.5, 1.1, 1.1), DARK)
    box("Machine house", (-.5, 0, 2.6), (5.0, 3.6, 2.8), YELLOW)
    box("House roof", (-.5, 0, 4.1), (5.2, 3.8, .2), CORRUGATED)
    box("Operator cab", (2.1, -1.2, 3.4), (1.2, 1.2, 1.4), YELLOW)
    box("Cab glass", (2.72, -1.2, 3.5), (.05, 1.0, .9), GLASS)
    limb((2.0, 0, 3.2), (7.0, 0, 9.5), .3, YELLOW, .6, 6)
    limb((-1.0, 0, 4.2), (2.3, 0, 8.2), .18, STEEL, 1, 6)
    limb((2.3, 0, 8.2), (7.0, 0, 9.5), .05, STEEL, 1, 4)
    limb((4.2, 0, 4.0), (6.4, 0, 2.6), .22, YELLOW, 1, 6)
    box("Dipper", (6.6, 0, 2.2), (1.6, 1.8, 1.5), DARK)
    limb((7.0, 0, 9.5), (6.7, 0, 3.0), .04, STEEL, 1, 4)


def crusher():
    box("Crusher building", (0, 0, 3.5), (6.0, 5.0, 7.0), CORRUGATED)
    box("Upper floor", (0, 0, 7.5), (4.0, 3.5, 1.4), CORRUGATED)
    box("Dump pocket", (-3.6, 0, 3.0), (1.4, 4.4, 1.0), CONCRETE)
    box("Ramp wall", (-4.5, 0, 1.5), (1.0, 4.6, 3.0), CONCRETE)
    limb((3.0, 0, 2.0), (7.5, 0, 5.5), .6, YELLOW, 1, 6)
    box("Roof", (0, 0, 7.1), (6.3, 5.3, .2), RUST)
    for y in [-1.5, 1.5]:
        box("Window band", (3.02, y, 5.2), (.05, 1.0, .5), GLASS)


def light_tower():
    box("Trailer", (0, 0, .7), (2.4, 1.3, .9), YELLOW)
    for x in [-.9, .9]:
        cylinder("Wheel", (x, -.75, .35), .35, .25, RUBBER, 10, "y")
    limb((0, 0, 1.1), (0, 0, 8.0), .09, STEEL, .7, 8)
    box("Lamp bar", (0, 0, 8.0), (1.8, .25, .25), DARK)
    for x in [-.6, 0, .6]:
        box("Lamp", (x, -.2, 8.0), (.45, .15, .45), LAMP)


def mine_office():
    for index, x in enumerate([-1.6, 1.6]):
        box("Portable cabin", (x, 0, 1.4), (3.0, 7.0, 2.6), CORRUGATED if index else PLASTER)
        box("Cabin roof", (x, 0, 2.75), (3.1, 7.1, .1), RUST)
        for y in [-2.2, 0, 2.2]:
            box("Cabin window", (x + (1.52 if index else -1.52), y, 1.6), (.04, .9, .6), GLASS)
    box("Steps", (0, -3.7, .3), (1.2, .6, .6), STEEL)
    box("Skid", (0, 0, .1), (6.6, 7.4, .2), CONCRETE)


def ore_boulder(seed, size, index):
    rng = random.Random(seed)
    blob("Ore boulder", (0, 0, size[2] * .45), size, ORE[index], rng, .2, 1)
    blob("Malachite stain", (size[0] * .3, size[1] * .2, size[2] * .75),
         (size[0] * .45, size[1] * .4, size[2] * .3), ORE[1], rng, .3, 0)


# ---------------------------------------------------------------- oasis

def date_palm(seed, height):
    rng = random.Random(seed)
    lean = Vector((rng.uniform(-.6, .6), rng.uniform(-.6, .6), 0))
    previous = Vector((0, 0, 0))
    for segment in range(6):
        t = (segment + 1) / 6
        point = Vector((0, 0, height * t)) + lean * t * t
        limb(previous, point, .26 - .06 * t, PALM_TRUNK, .9, 8)
        previous = point
    crown = previous
    for index in range(16):
        angle = index * math.tau / 16 + rng.uniform(-.1, .1)
        frond(crown, angle, rng.uniform(2.6, 3.4), rng.uniform(.75, 1.05), rng.choice(FROND))
    for index in range(4):
        angle = index * math.tau / 4 + .4
        blob("Date cluster", crown + Vector((math.cos(angle) * .5, math.sin(angle) * .5, -.5)),
             (.28, .28, .4), DATES, rng, .25, 0)


def palm_scrub(seed):
    rng = random.Random(seed)
    for clump in range(4):
        base = Vector((rng.uniform(-.9, .9), rng.uniform(-.9, .9), 0))
        for index in range(7):
            angle = index * math.tau / 7 + clump
            frond(base + Vector((0, 0, .2)), angle, rng.uniform(1.0, 1.6), .45, rng.choice(FROND), .22)


def mud_house(seed, width, depth, height):
    rng = random.Random(seed)
    box("Mud walls", (0, 0, height / 2), (width, depth, height), MUD)
    box("Parapet", (0, 0, height + .2), (width + .1, depth + .1, .4), MUD_DARK)
    box("Roof slab", (0, 0, height + .05), (width - .3, depth - .3, .1), MUD_DARK)
    box("Doorway", (width / 2 + .01, -depth * .2, .95), (.05, .9, 1.9), TIMBER_DARK)
    for y in [depth * .25]:
        box("Window", (width / 2 + .01, y, height * .62), (.05, .5, .5), TIMBER_DARK)
    for index in range(4):
        limb((-width / 2 + .4 + index * width / 4, depth / 2 - .1, height - .3),
             (-width / 2 + .4 + index * width / 4, depth / 2 + .4, height - .3), .07, TIMBER, 1, 5)
    if rng.random() < .7:
        box("Upper room", (-width * .2, -depth * .15, height + .9), (width * .45, depth * .45, 1.6), MUD)


def caravanserai_tower():
    cylinder("Corner tower", (0, 0, 3.2), 2.0, 6.4, MUD, 16)
    cylinder("Tower crown", (0, 0, 6.6), 2.15, .5, MUD_DARK, 16)
    for index in range(8):
        angle = index * math.tau / 8
        box("Merlon", (math.cos(angle) * 1.9, math.sin(angle) * 1.9, 7.1), (.5, .5, .5), MUD)
    box("Wall stub", (2.6, 0, 2.6), (3.4, 1.0, 5.2), MUD)
    box("Wall stub", (0, 2.6, 2.6), (1.0, 3.4, 5.2), MUD)


def caravanserai_gate():
    for x in [-2.6, 2.6]:
        box("Gate pier", (x, 0, 3.3), (2.0, 2.2, 6.6), MUD)
    box("Gate arch top", (0, 0, 5.6), (3.2, 2.2, 2.0), MUD)
    box("Portal shade", (0, -.6, 2.4), (3.2, 1.2, 4.8), MUD_DARK)
    box("Gate leaf", (-1.1, -1.12, 1.8), (1.2, .1, 3.6), TIMBER_DARK, .3)
    for x in [-3.6, 3.6]:
        box("Wall run", (x * 1.7, 0, 2.6), (3.4, 1.0, 5.2), MUD)
    box("Crown", (0, 0, 6.8), (5.6, 2.4, .4), MUD_DARK)


def stone_well():
    cylinder("Well curb", (0, 0, .45), .9, .9, STONE, 16)
    cylinder("Well water", (0, 0, .8), .72, .05, WATER, 16)
    for x in [-.85, .85]:
        limb((x, 0, .9), (x * .9, 0, 2.3), .07, TIMBER, 1, 6)
    limb((-.85, 0, 2.3), (.85, 0, 2.3), .06, TIMBER, 1, 6)
    cylinder("Pulley", (0, 0, 2.2), .15, .1, TIMBER_DARK, 10, "y")
    cylinder("Trough", (1.6, .2, .3), .35, 1.6, STONE, 10, "y")


def tent():
    for x in [-1.8, 0, 1.8]:
        limb((x, 0, 0), (x, 0, 2.0), .05, TIMBER, 1, 5)
    for y in [-1.6, 1.6]:
        box("Tent fall", (0, y * .55, 1.2), (4.2, .06, 2.0), CANVAS, 0, (math.copysign(.62, -y), 0))
    box("Tent ridge", (0, 0, 2.02), (4.3, .4, .06), CANVAS)


# ---------------------------------------------------------------- mojave

def joshua_tree(seed, height):
    rng = random.Random(seed)
    trunk_top = Vector((0, 0, height * .45))
    limb((0, 0, 0), trunk_top, .22, JOSHUA_BARK, .75)
    for branch in range(5):
        angle = branch * math.tau / 5 + rng.uniform(-.3, .3)
        elbow = trunk_top + Vector((math.cos(angle) * .6, math.sin(angle) * .6, height * .18))
        tip = elbow + Vector((math.cos(angle) * .35, math.sin(angle) * .35, height * .25))
        limb(trunk_top, elbow, .13, JOSHUA_BARK, .8)
        limb(elbow, tip, .1, JOSHUA_BARK, .85)
        blob("Leaf rosette", tip + Vector((0, 0, .2)), (.45, .45, .4), rng.choice(JOSHUA), rng, .35, 0)


def cholla(seed):
    rng = random.Random(seed)
    limb((0, 0, 0), (0, 0, .7), .09, CHOLLA, .9)
    for arm in range(6):
        angle = arm * math.tau / 6 + rng.uniform(-.4, .4)
        start = Vector((0, 0, rng.uniform(.4, .7)))
        end = start + Vector((math.cos(angle) * .4, math.sin(angle) * .4, rng.uniform(.2, .5)))
        limb(start, end, .07, CHOLLA, .85)


def water_tower():
    for corner in [(-1, -1), (1, -1), (1, 1), (-1, 1)]:
        limb((corner[0] * 1.6, corner[1] * 1.6, 0), (corner[0] * 1.3, corner[1] * 1.3, 5.0), .14, TIMBER_DARK, 1, 6)
    for z in [1.6, 3.3]:
        for edge in range(4):
            a = [(-1, -1), (1, -1), (1, 1), (-1, 1)][edge]
            b = [(-1, -1), (1, -1), (1, 1), (-1, 1)][(edge + 1) % 4]
            limb((a[0] * 1.5, a[1] * 1.5, z), (b[0] * 1.5, b[1] * 1.5, z + .8), .05, TIMBER_DARK, 1, 5)
    cylinder("Tank staves", (0, 0, 6.6), 1.9, 3.2, TIMBER, 20)
    cone("Tank roof", (0, 0, 8.6), 2.05, .9, RUST, 20, .1)
    for z in [5.4, 6.6, 7.8]:
        cylinder("Hoop", (0, 0, z), 1.93, .06, RUST, 20)
    limb((1.9, 0, 6.0), (3.0, 0, 3.6), .12, STEEL, 1, 6)


def boxcar():
    for x in [-3.4, 3.4]:
        box("Truck frame", (x, 0, .45), (1.8, 1.6, .35), DARK)
        for y in [-.7, .7]:
            cylinder("Wheelset", (x - .5, y, .4), .4, .18, DARK, 10, "y")
            cylinder("Wheelset", (x + .5, y, .4), .4, .18, DARK, 10, "y")
    box("Car body", (0, 0, 2.05), (10.0, 2.9, 2.9), RUST)
    box("Roof walk", (0, 0, 3.55), (10.0, .5, .1), TIMBER)
    box("Sliding door", (0, 1.46, 1.9), (2.0, .06, 2.4), RUST, 0, (0, .02))
    box("Door gap", (1.4, 1.45, 1.9), (.8, .05, 2.3), DARK)


def rail_section():
    for index in range(14):
        box("Tie", (-3.9 + index * .6, 0, .08), (.25, 2.4, .16), TIMBER_DARK)
    for y in [-.72, .72]:
        box("Rail", (0, y, .25), (8.2, .1, .16), RUST)


def signal_post():
    limb((0, 0, 0), (0, 0, 5.0), .1, STEEL, 1, 8)
    box("Signal head", (0, -.15, 4.6), (.5, .3, 1.2), DARK)
    for z in [4.95, 4.6, 4.25]:
        cylinder("Lens", (0, -.32, z), .12, .04, LAMP if z > 4.9 else GLASS, 10, "y")
    box("Relay box", (.4, 0, .6), (.5, .4, 1.0), STEEL)


builders = [
    # Salt flats.
    ("Saltbush", 1.1, 1.0, lambda: shrub(101, SALTBUSH, 1.0, .75)),
    ("Greasewood", 1.4, 1.6, lambda: shrub(102, GREASEWOOD, 1.2, 1.3, 9)),
    ("Tumbleweed", 1.0, 1.1, tumbleweed),
    ("SaltHeap", 3.4, 3.0, lambda: salt_heap(103)),
    ("BrinePumpHouse", 3.8, 2.4, brine_pump),
    ("PotashPlant", 7.0, 9.0, potash_plant),
    ("ConveyorRun", 4.3, 3.2, conveyor_run),
    ("PowerPylon", 3.6, 13.2, pylon),
    ("GypsumBoulderA", 1.6, 1.2, lambda: [blob("Gypsum", (0, 0, .5), (1.0, .8, .65), GYPSUM[0], random.Random(104), .2, 1)]),
    ("GypsumBoulderB", 1.0, .9, lambda: [blob("Gypsum", (0, 0, .35), (.6, .5, .45), GYPSUM[1], random.Random(105), .2, 1)]),
    # Copper mine.
    ("HaulTruck", 3.6, 4.2, haul_truck),
    ("ElectricShovel", 8.0, 10.0, electric_shovel),
    ("PrimaryCrusher", 8.0, 8.4, crusher),
    ("LightTower", 1.6, 8.4, light_tower),
    ("MineOffice", 5.0, 3.0, mine_office),
    ("OreBoulderA", 1.7, 1.4, lambda: ore_boulder(106, (1.1, .9, .8), 0)),
    ("OreBoulderB", 1.2, 1.0, lambda: ore_boulder(107, (.75, .6, .55), 2)),
    # Oasis.
    ("DatePalmA", 4.2, 10.5, lambda: date_palm(108, 7.5)),
    ("DatePalmB", 4.2, 8.5, lambda: date_palm(109, 5.8)),
    ("PalmScrub", 2.6, 1.4, lambda: palm_scrub(110)),
    ("Oleander", 1.4, 1.7, lambda: shrub(111, OLEANDER, 1.2, 1.5, 9, BLOSSOM)),
    ("MudHouseA", 3.8, 4.9, lambda: mud_house(112, 4.4, 4.0, 3.0)),
    ("MudHouseB", 4.4, 4.4, lambda: mud_house(113, 5.4, 3.6, 2.6)),
    ("CaravanseraiTower", 4.6, 7.5, caravanserai_tower),
    ("CaravanseraiGate", 9.2, 7.1, caravanserai_gate),
    ("StoneWell", 2.3, 2.5, stone_well),
    ("BedouinTent", 2.6, 2.2, tent),
    ("DuneGrass", 1.1, .9, lambda: dune_grass(114)),
    # Mojave.
    ("JoshuaTree", 2.0, 6.0, lambda: joshua_tree(115, 5.0)),
    ("Creosote", 1.2, 1.4, lambda: shrub(116, CREOSOTE, 1.1, 1.2, 8)),
    ("Cholla", .8, 1.3, lambda: cholla(117)),
    ("RailWaterTower", 3.4, 9.2, water_tower),
    ("DerelictBoxcar", 5.6, 3.7, boxcar),
    ("RailSection", 4.3, .4, rail_section),
    ("SignalPost", .8, 5.2, signal_post),
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
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/environment/DrylandsKit.blend"))
(ROOT / "art/environment/drylands-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest))
