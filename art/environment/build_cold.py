"""Cold kit for Glacier Narrows (Norwegian fjord head with a hydro dam),
Frostbound Crown (polar plateau research station) and Alpine Relay (Swiss
alpine communications pass). Blender Z-up, Godot Y-up. Original procedural
geometry; no external assets.
Run: blender --background --python art/environment/build_cold.py
"""
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
import scenery_scale

BUILDING_HEIGHTS = {
    "FjordHouseRed": 5.4, "FjordHouseOchre": 5.4, "MountainHut": 5.8,
    "Boathouse": 4.8, "FjordChapel": 7.2,
}

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/environment/cold"
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


SPRUCE = [material("Spruce needles %d" % i, c) for i, c in enumerate([(.05, .13, .09), (.07, .16, .11), (.09, .19, .12)])]
SNOW = material("Snow", (.90, .93, .95), .8)
SNOW_SHADE = material("Shaded snow", (.76, .82, .88), .8)
BARK = material("Spruce bark", (.20, .15, .11))
BIRCH_BARK = material("Birch bark", (.80, .78, .73))
BIRCH = [material("Birch autumn %d" % i, c) for i, c in enumerate([(.62, .46, .10), (.72, .56, .16), (.52, .40, .12)])]
JUNIPER = [material("Juniper %d" % i, c) for i, c in enumerate([(.10, .20, .14), (.14, .24, .16)])]
HEATHER = [material("Heather %d" % i, c) for i, c in enumerate([(.20, .15, .15), (.22, .18, .13), (.24, .16, .18)])]
TUSSOCK = [material("Tussock %d" % i, c) for i, c in enumerate([(.62, .56, .38), (.52, .48, .33)])]
LICHEN = material("Lichen", (.55, .58, .30))
GNEISS = [material("Gneiss %d" % i, c) for i, c in enumerate([(.38, .39, .40), (.48, .48, .47), (.31, .32, .34)])]
ICE = material("Glacier ice", (.56, .78, .88), .22)
ICE_DEEP = material("Deep ice", (.34, .60, .76), .2)
CONCRETE = material("Dam concrete", (.62, .62, .60))
CONCRETE_DARK = material("Wet concrete", (.42, .43, .43))
STEEL = material("Painted steel", (.44, .46, .48), .5, .6)
GATE = material("Gate blue", (.18, .32, .46), .5, .4)
RUST = material("Rust", (.38, .21, .11), .75, .3)
RED = material("Falu red", (.46, .11, .08))
OCHRE = material("Ochre cladding", (.68, .48, .16))
WHITE = material("White paint", (.86, .86, .82))
ROOF = material("Dark roof", (.15, .16, .17))
GLASS = material("Window glass", (.14, .19, .24), .2)
TIMBER = material("Timber", (.50, .38, .25))
TIMBER_DARK = material("Weathered timber", (.27, .21, .16))
STONE = material("Hut stone", (.47, .46, .43))
STATION_BLUE = material("Station blue", (.16, .32, .54), .5, .2)
STATION_RED = material("Station red", (.68, .15, .11), .5, .2)
STATION_GREY = material("Station grey", (.56, .59, .62), .5, .3)
ORANGE = material("Signal orange", (.86, .40, .08))
FUEL = material("Fuel tank green", (.22, .30, .21), .6, .3)
YELLOW = material("Hazard yellow", (.86, .68, .12))
RADOME = material("Radome", (.92, .93, .92), .5)
BLACK = material("Rubber", (.06, .06, .07))
SOLAR = material("Solar cells", (.07, .11, .22), .2, .3)
WATER = material("Spill water", (.72, .84, .86), .1)


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


def mesh_object(name, verts, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return attach(obj, name, mat, flat=True)


def gable_roof(name, point, width, depth, rise, mat, overhang=.3):
    """A pitched roof whose ridge runs along local Y."""
    x, y, z = point
    w = width / 2 + overhang
    d = depth / 2 + overhang
    verts = [(x - w, y - d, z), (x + w, y - d, z), (x + w, y + d, z), (x - w, y + d, z),
             (x, y - d, z + rise), (x, y + d, z + rise)]
    faces = [(0, 4, 5, 3), (1, 2, 5, 4), (0, 1, 4), (3, 5, 2)]
    return mesh_object(name, verts, faces, mat)


def snowy_roof(name, point, width, depth, rise, overhang=.3, turn=0.0):
    """A dark roof with a snow blanket that leaves the eaves showing; `turn`
    rotates both about the roof's own centre."""
    lift = (point[0], point[1], point[2] + .08 + rise * .12)
    for part in [gable_roof(name, point, width, depth, rise, ROOF, overhang),
                 gable_roof(name + " snow", lift, width * .84, depth, rise * .9, SNOW, overhang * .6)]:
        if turn:
            for vertex in part.data.vertices:
                local = vertex.co - Vector(point)
                vertex.co = Vector(point) + Vector((local.x * math.cos(turn) - local.y * math.sin(turn),
                                                    local.x * math.sin(turn) + local.y * math.cos(turn), local.z))


def window(point, size, facing="y"):
    x, y, z = point
    w, h = size
    if facing == "y":
        box("Window frame", (x, y, z), (w + .16, .06, h + .16), WHITE)
        box("Window", (x, y + (.02 if y > 0 else -.02), z), (w, .06, h), GLASS)
    else:
        box("Window frame", (x, y, z), (.06, w + .16, h + .16), WHITE)
        box("Window", (x + (.02 if x > 0 else -.02), y, z), (.06, w, h), GLASS)


# ---------------------------------------------------------------- flora

def snowy_spruce(seed, height, spread=1.0):
    rng = random.Random(seed)
    limb((0, 0, 0), (0, 0, height * .96), .22 * spread, BARK, .2, 8)
    tiers = 11
    for tier in range(tiers):
        t = tier / (tiers - 1)
        # Norway spruce: a narrow spire over drooping, uneven lower whorls.
        radius = (1.6 * (1 - t) ** 1.2 + .18) * spread * rng.uniform(.88, 1.1)
        z = height * (.12 + t * .8)
        depth = height * .16
        offset = Vector((rng.uniform(-.08, .08), rng.uniform(-.08, .08), 0))
        whorl = cone("Spruce whorl", (offset.x, offset.y, z), radius, depth, rng.choice(SPRUCE), 8, radius * .2)
        whorl.rotation_euler = (rng.uniform(-.06, .06), rng.uniform(-.06, .06), rng.uniform(0, math.tau))
        # Snow settles in uneven caps on most whorls; green shows around them.
        if rng.random() < .65:
            angle = rng.uniform(0, math.tau)
            shift = Vector((math.cos(angle), math.sin(angle), 0)) * radius * .12
            cap = radius * rng.uniform(.78, .95)
            load = cone("Snow load", (offset.x + shift.x, offset.y + shift.y, z + depth * .16), cap, depth * .62,
                        SNOW if rng.random() < .75 else SNOW_SHADE, 7, cap * .1)
            load.rotation_euler.z = rng.uniform(0, math.tau)
    cone("Snow tip", (0, 0, height * .95), .2 * spread, height * .07, SNOW, 7)


def mountain_birch(seed):
    rng = random.Random(seed)
    for stem in range(3):
        angle = stem * 2.2 + rng.uniform(-.3, .3)
        base = Vector((math.cos(angle) * .3, math.sin(angle) * .3, 0))
        knee = base + Vector((math.cos(angle) * .9, math.sin(angle) * .9, 2.2 + stem * .3))
        top = knee + Vector((math.cos(angle + .6) * .6, math.sin(angle + .6) * .6, 2.0))
        limb(base, knee, .14, BIRCH_BARK, .7)
        limb(knee, top, .1, BIRCH_BARK, .5)
        for pad in range(4):
            centre = knee.lerp(top, .3 + pad * .22) + Vector((rng.uniform(-.6, .6), rng.uniform(-.6, .6), rng.uniform(-.2, .4)))
            size = rng.uniform(.6, .95)
            blob("Birch crown", centre, (size, size, size * .8), rng.choice(BIRCH), rng, .32, 0)


def shrub(seed, mats, radius, height, clumps=7, snow=0.0):
    rng = random.Random(seed)
    for clump in range(clumps):
        angle = rng.uniform(0, math.tau)
        r = rng.uniform(0, radius * .55)
        centre = (math.cos(angle) * r, math.sin(angle) * r, height * rng.uniform(.35, .5))
        size = radius * rng.uniform(.35, .55)
        blob("Shrub clump", centre, (size, size, height * .5), rng.choice(mats), rng, .3, 0)
        if rng.random() < snow:
            blob("Snow patch", (centre[0], centre[1], centre[2] + height * .35), (size * .7, size * .7, height * .14),
                 SNOW, rng, .25, 0)


def tussock(seed):
    rng = random.Random(seed)
    for index in range(16):
        angle = index * math.tau / 16 + rng.uniform(-.2, .2)
        reach = rng.uniform(.25, .45)
        tip = (math.cos(angle) * reach, math.sin(angle) * reach, rng.uniform(.35, .5))
        limb((math.cos(angle) * .05, math.sin(angle) * .05, 0), tip, .05, rng.choice(TUSSOCK), .1, 4)


def boulder(seed, size, index, snow=True):
    rng = random.Random(seed)
    blob("Gneiss", (0, 0, size[2] * .45), size, GNEISS[index], rng, .2, 1)
    blob("Lichen", (size[0] * .3, 0, size[2] * .55), (size[0] * .3, size[1] * .3, size[2] * .2), LICHEN, rng, .3, 0)
    if snow:
        blob("Snow cap", (0, 0, size[2] * .86), (size[0] * .62, size[1] * .62, size[2] * .16), SNOW, rng, .25, 0)


def erratic():
    rng = random.Random(77)
    blob("Erratic", (0, 0, 1.3), (2.2, 1.7, 1.5), GNEISS[0], rng, .18, 1)
    blob("Erratic shoulder", (1.4, .6, .6), (1.1, .9, .7), GNEISS[2], rng, .22, 1)
    for index in range(3):
        blob("Lichen", (rng.uniform(-1, 1), -1.2, rng.uniform(.8, 2.0)), (.4, .2, .3), LICHEN, rng, .3, 0)
    blob("Snow cap", (-.2, 0, 2.55), (1.4, 1.1, .3), SNOW, rng, .2, 1)


def scree(seed):
    rng = random.Random(seed)
    for index in range(8):
        angle = rng.uniform(0, math.tau)
        r = rng.uniform(0, .9)
        size = rng.uniform(.18, .4)
        blob("Scree", (math.cos(angle) * r, math.sin(angle) * r, size * .4), (size, size * .8, size * .6),
             rng.choice(GNEISS), rng, .3, 0)


def ice_block(seed, size):
    rng = random.Random(seed)
    blob("Ice", (0, 0, size[2] * .45), size, ICE, rng, .25, 0)
    blob("Ice core", (size[0] * .2, 0, size[2] * .3), (size[0] * .6, size[1] * .6, size[2] * .4), ICE_DEEP, rng, .25, 0)
    blob("Snow cap", (0, 0, size[2] * .85), (size[0] * .6, size[1] * .5, size[2] * .15), SNOW, rng, .2, 0)


def sastrugi(seed):
    rng = random.Random(seed)
    for index in range(4):
        y = -1.0 + index * .65 + rng.uniform(-.1, .1)
        blob("Sastrugi", (rng.uniform(-.4, .4), y, .12), (rng.uniform(1.4, 2.0), .32, .26), SNOW, rng, .15, 1)


def snow_drift(seed):
    rng = random.Random(seed)
    blob("Drift", (0, 0, .1), (2.6, 1.5, .6), SNOW, rng, .08, 2)
    blob("Drift lee", (1.2, .4, .05), (1.2, .9, .35), SNOW_SHADE, rng, .1, 1)


# ---------------------------------------------------------------- fjord head

def hydro_dam():
    """Gravity dam along local X; the reservoir lies toward -Y, the gorge +Y.
    The crest road sits at the bridge deck (origin)."""
    box("Crest road", (0, 0, -.2), (30.0, 7.0, .5), CONCRETE)
    box("Lane line", (0, 0, .06), (28.0, .14, .01), WHITE)
    for y in [-3.3, 3.3]:
        box("Parapet", (0, y, .55), (30.0, .4, 1.0), CONCRETE)
    box("Upstream face", (0, -3.7, -2.4), (30.0, .6, 5.0), CONCRETE_DARK)
    # Downstream face slopes into the gorge.
    mesh_object("Downstream face",
                [(-15, 3.5, .05), (15, 3.5, .05), (15, 9.5, -5.2), (-15, 9.5, -5.2)],
                [(0, 1, 2, 3)], CONCRETE)
    for x in [-15, 15]:
        box("Abutment", (x, 3.2, -1.6), (1.2, 13.0, 3.6), CONCRETE_DARK)
    # Spillway bays: piers carry radial gates; water sheets down the chute.
    for index in range(5):
        x = -8 + index * 4
        box("Spillway pier", (x, 5.2, -1.0), (.8, 3.4, 2.4), CONCRETE, 0, (-.6, 0))
    for index in range(4):
        x = -6 + index * 4
        box("Radial gate", (x, 4.4, -.4), (3.1, .25, 1.6), GATE, 0, (-.5, 0))
        box("Spill sheet", (x, 7.3, -3.2), (3.0, .1, 4.2), WATER, 0, (-.85, 0))
    # Hoist gantry over the gates.
    for x in [-10, 10]:
        for y in [2.8, 3.8]:
            limb((x, y, .05), (x, y, 4.2), .2, STEEL, 1, 6)
    box("Gantry beam", (0, 3.3, 4.2), (21.0, 1.4, .5), STEEL)
    for index in range(4):
        box("Hoist", (-6 + index * 4, 3.3, 3.7), (1.0, .9, .6), YELLOW)
    for x in [-12, -4, 4, 12]:
        limb((x, -3.3, 1.05), (x, -3.3, 3.2), .06, STEEL, 1, 5)
        box("Lamp", (x, -3.1, 3.25), (.5, .3, .15), STEEL)
    # Intake tower in the reservoir with its access bridge.
    cylinder("Intake tower", (-9, -7.0, -1.0), 1.7, 6.2, CONCRETE, 16)
    box("Intake deck", (-9, -7.0, 2.2), (4.2, 4.2, .3), CONCRETE_DARK)
    box("Intake house", (-9, -7.0, 3.0), (2.4, 2.4, 1.6), STATION_GREY)
    box("Intake bridge", (-9, -4.8, 1.8), (1.4, 2.4, .2), STEEL)


def powerhouse():
    box("Hall", (0, 0, 4.0), (16.0, 9.0, 8.0), CONCRETE)
    box("Roof", (0, 0, 8.1), (16.6, 9.6, .3), CONCRETE_DARK)
    for x in [-6, -3, 0, 3, 6]:
        window((x, 4.52, 4.6), (1.4, 5.0))
        window((x, -4.52, 4.6), (1.4, 5.0))
    box("Bay door", (7.0, 4.53, 2.2), (2.6, .05, 4.2), STEEL)
    box("Tailrace", (0, 6.5, -.2), (12.0, 4.0, .4), CONCRETE_DARK)
    box("Tailrace water", (0, 6.5, .05), (11.0, 3.2, .05), WATER)
    # Penstocks come down the slope behind into the turbine hall.
    for x in [-3.0, 3.0]:
        limb((x, -4.5, 5.4), (x, -11.5, 10.2), .75, RUST, 1, 14)
        box("Anchor block", (x, -11.0, 9.2), (2.2, 2.0, 2.0), CONCRETE_DARK)
    # Switchyard: transformers and a line portal.
    for index in range(3):
        x = -11.5
        y = -2.5 + index * 2.6
        box("Transformer", (x, y, 1.1), (2.0, 1.6, 2.2), STATION_GREY)
        for fin in range(4):
            box("Radiator", (x - 1.1, y - .6 + fin * .4, 1.1), (.2, .08, 1.8), STEEL)
    for y in [-3.5, 3.5]:
        limb((-14, y, 0), (-14, y, 8.0), .18, STEEL, .8, 6)
    box("Portal beam", (-14, 0, 8.0), (.4, 7.6, .4), STEEL)


def fjord_house(seed, cladding):
    rng = random.Random(seed)
    box("House", (0, 0, 2.6), (7.0, 5.0, 5.2), cladding)
    for x in [-3.48, 3.48]:
        for y in [-2.48, 2.48]:
            box("Corner board", (x, y, 2.6), (.14, .14, 5.2), WHITE)
    for x in [-2.0, 0.0, 2.0]:
        window((x, -2.52, 1.6), (.8, 1.1))
        window((x, -2.52, 3.9), (.8, 1.0))
    window((-3.52, 0, 3.9), (.8, 1.0), "x")
    box("Door", (2.6, 2.52, 1.1), (.9, .06, 2.1), WHITE)
    box("Step", (2.6, 2.9, .2), (1.4, .8, .4), STONE)
    snowy_roof("Roof", (0, 0, 5.2), 5.0, 7.0, 2.4, turn=math.pi / 2)
    cylinder("Chimney", (1.6, .6, 7.2), .32, 2.0, STONE, 8)
    if rng.random() < .6:
        box("Woodpile", (-3.0, 3.0, .5), (2.0, .7, 1.0), TIMBER)


def boathouse():
    box("Naust", (0, 0, 1.6), (8.0, 4.8, 3.2), RED)
    snowy_roof("Naust roof", (0, 0, 3.2), 4.8, 8.0, 1.9, turn=math.pi / 2)
    box("Boat doors", (4.02, 0, 1.4), (.06, 3.2, 2.8), TIMBER_DARK)
    box("Door trim", (4.04, 0, 2.85), (.06, 3.4, .12), WHITE)
    box("Jetty", (6.8, 0, .25), (5.6, 2.0, .2), TIMBER)
    for x in [5.0, 7.0, 9.0]:
        for y in [-.9, .9]:
            limb((x, y, -1.2), (x, y, .35), .12, TIMBER_DARK, 1, 6)


def chapel():
    box("Nave", (0, 1.6, 2.6), (6.0, 9.0, 5.2), WHITE)
    snowy_roof("Nave roof", (0, 1.6, 5.2), 6.0, 9.0, 3.2)
    for y in [-1.0, 1.6, 4.2]:
        for x in [-3.02, 3.02]:
            window((x, y, 2.8), (.7, 1.8), "x")
    box("Tower", (0, -4.0, 4.0), (3.0, 3.0, 8.0), WHITE)
    box("Belfry", (0, -4.0, 8.6), (2.6, 2.6, 1.2), TIMBER_DARK)
    cone("Spire", (0, -4.0, 11.2), 2.0, 4.2, ROOF, 4, 0)
    bpy.context.object.rotation_euler.z = math.pi / 4
    box("Door", (0, -5.52, 1.2), (1.1, .06, 2.4), RED)


# ---------------------------------------------------------------- polar station

def radar_dome():
    box("Equipment hall", (0, 0, 2.0), (10.0, 10.0, 4.0), STATION_GREY)
    box("Hall roof", (0, 0, 4.1), (10.4, 10.4, .2), STATION_BLUE)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=5.0, location=(0, 0, 8.4))
    attach(bpy.context.object, "Radome", RADOME, flat=True)
    cylinder("Radome ring", (0, 0, 4.3), 5.3, .3, STATION_BLUE, 24)
    for index in range(3):
        window((-3 + index * 3, -5.02, 2.4), (1.2, .9))
    box("Door", (3.6, -5.03, 1.2), (1.1, .06, 2.2), ORANGE)
    box("Stair", (-6.4, 2.0, 2.0), (1.2, 4.6, .2), STEEL, 0, (.7, 0))
    limb((4.0, 4.0, 4.2), (4.0, 4.0, 12.8), .08, STEEL, 1, 5)
    box("Beacon", (4.0, 4.0, 12.9), (.3, .3, .3), STATION_RED)


def research_station():
    """Modules on hydraulic legs with ski feet, linked by sealed walkways."""
    def module(x, length, height, mat):
        z = 3.0 + height / 2
        box("Module", (x, 0, z), (length, 5.0, height), mat)
        box("Module roof", (x, 0, 3.0 + height + .08), (length + .2, 5.2, .16), STATION_GREY)
        for index in range(int(length // 2)):
            window((x - length / 2 + 1.2 + index * 2.0, -2.52, z + .3), (.9, .7))
        for dx in [-length / 2 + .8, length / 2 - .8]:
            for y in [-1.9, 1.9]:
                limb((x + dx, y, .4), (x + dx, y, 3.0), .16, STEEL, 1, 6)
                box("Ski", (x + dx, y, .2), (1.6, .5, .2), STEEL)
    module(-8.5, 6.0, 3.2, STATION_BLUE)
    module(0.0, 7.0, 5.0, STATION_RED)
    module(8.5, 6.0, 3.2, STATION_BLUE)
    for x in [-4.75, 4.75]:
        box("Link", (x, 0, 4.4), (2.0, 2.2, 2.2), STATION_GREY)
    box("Stair tower", (0, 3.5, 2.6), (2.0, 2.0, 5.2), STATION_GREY)
    box("Roof deck", (0, 0, 8.25), (3.0, 3.0, .1), STEEL)
    limb((0, 0, 8.3), (0, 0, 10.0), .06, STEEL, 1, 5)
    box("Anemometer", (0, 0, 10.0), (.8, .1, .1), STEEL)


def fuel_tanks():
    for index, y in enumerate([-2.6, 0.0, 2.6]):
        box("Sledge", (0, y, .25), (6.6, 1.8, .3), STEEL)
        cylinder("Fuel tank", (0, y, 1.45), 1.05, 6.0, FUEL, 16, "x")
        for x in [-2.2, 2.2]:
            cylinder("Hazard band", (x, y, 1.45), 1.07, .3, YELLOW, 16, "x")
    limb((3.4, -2.6, 2.4), (3.4, 2.6, 2.4), .08, STEEL, 1, 5)


def antenna_mast():
    legs = [(math.cos(a) * .7, math.sin(a) * .7) for a in [0, math.tau / 3, 2 * math.tau / 3]]
    for x, y in legs:
        limb((x, y, 0), (x * .35, y * .35, 18.0), .07, STEEL, .7, 5)
    for level in range(9):
        z = level * 2.0
        shrink = 1 - z / 18.0 * .65
        for index in range(3):
            a = legs[index]
            b = legs[(index + 1) % 3]
            limb((a[0] * shrink, a[1] * shrink, z), (b[0] * shrink, b[1] * shrink, z + 2.0), .03, STEEL, 1, 4)
    cone("Dish", (.9, 0, 12.0), 1.0, .5, RADOME, 16, .2)
    bpy.context.object.rotation_euler.y = math.pi / 2
    box("Aviation light", (0, 0, 18.15), (.3, .3, .3), STATION_RED)
    for index in range(3):
        angle = index * math.tau / 3 + .5
        anchor = (math.cos(angle) * 7.0, math.sin(angle) * 7.0, .2)
        limb((0, 0, 12.0), anchor, .025, STEEL, 1, 4)
        box("Guy anchor", anchor, (.6, .6, .4), CONCRETE_DARK)


def weatherhaven():
    cylinder("Shelter", (0, 0, 0), 2.2, 6.0, ORANGE, 16, "x")
    box("Floor", (0, 0, .1), (6.2, 4.6, .2), TIMBER_DARK)
    box("End wall", (-3.0, 0, 1.0), (.1, 3.2, 2.0), STATION_GREY)
    box("Door", (-3.06, 0, .9), (.06, 1.0, 1.8), ORANGE)
    blob("Drift", (0, 2.4, .2), (3.0, .9, .5), SNOW, random.Random(5), .1, 1)


def snowcat():
    for y in [-1.0, 1.0]:
        box("Track", (0, y, .45), (4.6, .8, .9), BLACK)
    box("Hull", (0, 0, 1.25), (4.0, 2.0, .9), STATION_RED)
    box("Cab", (.6, 0, 2.25), (2.2, 1.9, 1.2), STATION_RED)
    box("Windscreen", (1.72, 0, 2.35), (.06, 1.7, .8), GLASS)
    for y in [-.96, .96]:
        box("Side window", (.5, y, 2.4), (1.6, .06, .6), GLASS)
    box("Blade", (2.7, 0, .7), (.3, 2.8, 1.0), YELLOW, 0, (0, .3))
    box("Light bar", (.6, 0, 2.95), (.4, 1.6, .15), BLACK)


def supply_crates():
    rng = random.Random(51)
    for index in range(6):
        x = -1.8 + (index % 3) * 1.3
        y = -.7 + (index // 3) * 1.4
        box("Crate", (x, y, .5), (1.1, 1.1, 1.0), rng.choice([TIMBER, ORANGE, STATION_GREY]), rng.uniform(-.2, .2))
    box("Crate", (-1.2, 0, 1.45), (1.1, 1.1, .9), TIMBER)
    for index in range(4):
        cylinder("Drum", (2.4, -1.2 + index * .8, .45), .32, .9, rng.choice([FUEL, STATION_BLUE]), 12)


# ---------------------------------------------------------------- alpine pass

def snow_fence():
    for index in range(5):
        x = -3 + index * 1.5
        limb((x, .4, 0), (x, -.4, 2.5), .07, TIMBER_DARK, 1, 5)
        limb((x, .4, 0), (x, 1.3, 1.4), .05, TIMBER_DARK, 1, 5)
    for index in range(6):
        z = .45 + index * .36
        box("Slat", (0, .35 - z * .32, z), (6.4, .05, .16), TIMBER, 0, (-.31, 0))
    blob("Drift", (0, -1.2, .1), (3.4, 1.0, .5), SNOW, random.Random(8), .1, 1)


def cable_pylon():
    for sx in [-1, 1]:
        for sy in [-1, 1]:
            limb((sx * 1.6, sy * 1.6, 0), (sx * .55, sy * .55, 13.0), .1, STEEL, .7, 5)
    for level in range(6):
        z = 1.0 + level * 2.1
        shrink = 1.6 - (z / 13.0) * 1.05
        for a, b in [((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))]:
            limb((a[0] * shrink, a[1] * shrink, z), (b[0] * shrink, b[1] * shrink, z + 1.6), .04, STEEL, 1, 4)
    box("Crossarm", (0, 0, 13.3), (7.4, .8, .6), STEEL)
    for x in [-3.2, 3.2]:
        for y in [-.5, .5]:
            cylinder("Sheave", (x, y, 13.75), .35, .12, BLACK, 12, "y")
    box("Maintenance platform", (0, 0, 12.8), (2.4, 2.4, .1), STEEL)
    for sx in [-1, 1]:
        for sy in [-1, 1]:
            box("Footing", (sx * 1.6, sy * 1.6, .25), (1.0, 1.0, .5), CONCRETE_DARK)


def mountain_hut():
    box("Stone storey", (0, 0, 1.6), (10.0, 7.0, 3.2), STONE)
    box("Timber storey", (0, 0, 4.5), (10.0, 7.0, 2.6), TIMBER_DARK)
    for x in [-3.5, -1.2, 1.2, 3.5]:
        window((x, -3.52, 1.8), (.8, .9))
        window((x, -3.52, 4.6), (.8, .9))
        box("Shutter", (x - .65, -3.56, 4.6), (.4, .06, 1.0), STATION_RED)
        box("Shutter", (x + .65, -3.56, 4.6), (.4, .06, 1.0), STATION_RED)
    snowy_roof("Hut roof", (0, 0, 5.8), 7.0, 10.0, 1.6, .5, turn=math.pi / 2)
    box("Terrace", (0, -4.6, .4), (8.0, 2.2, .8), STONE)
    box("Solar panels", (-3.0, 4.6, 1.2), (3.6, .1, 1.6), SOLAR, 0, (.8, 0))
    limb((4.8, -5.4, .8), (4.8, -5.4, 8.6), .05, STEEL, 1, 5)
    box("Flag", (5.4, -5.4, 8.0), (1.2, .04, .8), STATION_RED)


builders = [
    ("NorwaySpruce", 2.3, 11.0, lambda: snowy_spruce(301, 10.5, 1.1)),
    ("SpruceSapling", 1.4, 5.0, lambda: snowy_spruce(302, 4.6, .65)),
    ("MountainBirch", 3.2, 6.4, lambda: mountain_birch(303)),
    ("DwarfJuniper", 1.3, .8, lambda: shrub(304, JUNIPER, 1.2, .6, 8, .4)),
    ("Heather", .9, .5, lambda: shrub(305, HEATHER, .8, .35, 7)),
    ("Tussock", .6, .6, lambda: tussock(306)),
    ("GneissBoulderA", 1.7, 1.5, lambda: boulder(307, (1.1, .9, .85), 0)),
    ("GneissBoulderB", 1.2, 1.1, lambda: boulder(308, (.75, .6, .6), 1)),
    ("BareBoulder", 1.3, 1.1, lambda: boulder(309, (.8, .7, .6), 2, False)),
    ("ErraticBoulder", 3.2, 3.2, erratic),
    ("Scree", 1.4, .6, lambda: scree(310)),
    ("IceBlockA", 2.2, 1.9, lambda: ice_block(311, (1.4, 1.1, 1.0))),
    ("IceBlockB", 1.4, 1.2, lambda: ice_block(312, (.9, .7, .65))),
    ("Sastrugi", 2.4, .5, lambda: sastrugi(313)),
    ("SnowDrift", 3.2, .8, lambda: snow_drift(314)),
    ("HydroDam", 18.6, 4.8, hydro_dam),
    ("Powerhouse", 15.0, 11.0, powerhouse),
    ("FjordHouseRed", 5.4, 8.4, lambda: fjord_house(315, RED)),
    ("FjordHouseOchre", 5.4, 8.4, lambda: fjord_house(316, OCHRE)),
    ("Boathouse", 9.8, 5.4, boathouse),
    ("FjordChapel", 7.4, 13.4, chapel),
    ("RadarDome", 8.2, 13.5, radar_dome),
    ("ResearchStation", 12.6, 10.6, research_station),
    ("FuelTanks", 5.0, 2.7, fuel_tanks),
    ("AntennaMast", 7.6, 18.4, antenna_mast),
    ("Weatherhaven", 4.2, 2.3, weatherhaven),
    ("Snowcat", 3.4, 3.1, snowcat),
    ("SupplyCrates", 3.2, 2.0, supply_crates),
    ("SnowFence", 4.4, 2.6, snow_fence),
    ("CablePylon", 3.8, 14.2, cable_pylon),
    ("MountainHut", 8.2, 8.8, mountain_hut),
]
for name, radius, height, build in builders:
    if "--buildings-only" in sys.argv and name not in BUILDING_HEIGHTS:
        continue
    height = BUILDING_HEIGHTS.get(name, height)
    begin(name, radius, height)
    build()
    if name in BUILDING_HEIGHTS:
        scenery_scale.fit_height(collection, height)

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
    if radius > radius_limit + .001 or height > height_limit + .001:
        violations.append((name, round(radius, 2), round(height, 2)))
    manifest[name] = {"radius": round(radius, 4), "height": round(height, 4),
                      "radius_limit": radius_limit, "height_limit": height_limit}
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + ".glb")), export_format="GLB",
                              use_selection=True, export_apply=True)
assert not violations, violations
manifest_path = ROOT / "art/environment/cold-manifest.json"
if "--buildings-only" in sys.argv:
    manifest = {**json.loads(manifest_path.read_text()), **manifest}
else:
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/environment/ColdKit.blend"))
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest))
