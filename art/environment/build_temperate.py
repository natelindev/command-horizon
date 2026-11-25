"""Temperate kit for Pinebreak Valley (Pacific Northwest logging valley), Four
Rivers (river-confluence farmland) and Verdant Commons (English village).
Blender Z-up, Godot Y-up. Original procedural geometry; no external assets.
Run: blender --background --python art/environment/build_temperate.py
"""
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
import foliage
import scenery_scale

# Keep the existing navigation footprint while matching military architecture.
BUILDING_HEIGHTS = {
    "Farmhouse": 5.8, "Barn": 6.4, "Sawmill": 6.0, "WaterMill": 6.0,
    "CottageA": 4.8, "CottageB": 4.8, "VillageChurch": 7.2,
    "GrainElevator": 8.2, "MetalSilos": 5.6,
}

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/environment/temperate"
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


BARK = material("Fir bark", (.22, .15, .10))
CEDAR_BARK = material("Cedar bark", (.36, .20, .12))
OAK_BARK = material("Oak bark", (.25, .21, .16))
BIRCH_BARK = material("Birch bark", (.82, .80, .74))
FIR = [material("Fir needles %d" % i, c) for i, c in enumerate([(.07, .17, .09), (.10, .22, .11), (.14, .27, .13)])]
CEDAR = [material("Cedar sprays %d" % i, c) for i, c in enumerate([(.13, .24, .10), (.18, .30, .12)])]
OAK = [material("Oak leaves %d" % i, c) for i, c in enumerate([(.17, .28, .09), (.22, .34, .11), (.28, .39, .14)])]
MAPLE = [material("Maple leaves %d" % i, c) for i, c in enumerate([(.26, .38, .12), (.36, .44, .14)])]
BIRCH = [material("Birch leaves %d" % i, c) for i, c in enumerate([(.38, .50, .18), (.46, .56, .22)])]
WILLOW = [material("Willow leaves %d" % i, c) for i, c in enumerate([(.34, .46, .20), (.42, .52, .25)])]
FERN = [material("Fern %d" % i, c) for i, c in enumerate([(.15, .32, .10), (.21, .38, .12)])]
SALAL = material("Salal", (.12, .26, .10))
BRAMBLE = material("Bramble", (.18, .27, .11))
HEDGE = [material("Hawthorn hedge %d" % i, c) for i, c in enumerate([(.14, .26, .09), (.19, .31, .11)])]
FLOWER = [material("Wildflower %d" % i, c) for i, c in enumerate([(.86, .78, .30), (.78, .40, .55), (.92, .92, .88)])]
MOSS = material("Moss", (.20, .32, .12))
GRANITE = [material("Granite %d" % i, c) for i, c in enumerate([(.46, .46, .44), (.55, .54, .51), (.38, .39, .37)])]
TIMBER = material("Sawn timber", (.52, .40, .27))
TIMBER_DARK = material("Weathered planks", (.30, .24, .18))
LOG = material("Log ends", (.62, .48, .30))
STONE = material("Field stone", (.58, .55, .48))
STONE_DARK = material("Field stone shade", (.44, .42, .37))
LIMESTONE = material("Church limestone", (.74, .70, .60))
SLATE = material("Slate roof", (.22, .23, .26))
THATCH = material("Thatch", (.55, .44, .27))
RED_BARN = material("Barn red", (.48, .14, .10))
WHITE_TRIM = material("White trim", (.86, .85, .80))
TIN = material("Galvanised tin", (.58, .60, .60), .5, .6)
RUST = material("Rusted iron", (.38, .20, .10), .75, .3)
CONCRETE = material("Elevator concrete", (.70, .68, .63))
GLASS = material("Window glass", (.15, .20, .24), .2)
HAY = material("Hay", (.78, .64, .32))
WATER = material("Mill race", (.14, .22, .22), .15)


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
    if not obj.data.materials:
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
    if any(word in mat.name.lower() for word in ("leaves", "salal", "bramble", "hedge")):
        return attach(foliage.cluster(name, center, size, mat, rng), name, mat)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=center)
    obj = bpy.context.object
    for vertex in obj.data.vertices:
        vertex.co *= 1 + rng.uniform(-roughness, roughness)
    obj.scale = size
    obj.rotation_euler.z = rng.uniform(0, math.tau)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return attach(obj, name, mat, flat=True)


def gable_roof(name, point, width, depth, rise, mat, overhang=.3):
    """A pitched roof whose ridge runs along local Y."""
    x, y, z = point
    w = width / 2 + overhang
    d = depth / 2 + overhang
    verts = [(x - w, y - d, z), (x + w, y - d, z), (x + w, y + d, z), (x - w, y + d, z),
             (x, y - d, z + rise), (x, y + d, z + rise)]
    faces = [(0, 4, 5, 3), (1, 2, 5, 4), (0, 1, 4), (3, 5, 2)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return attach(obj, name, mat, flat=True)


# ---------------------------------------------------------------- flora

def conifer(seed, height, mats, bark, spread=1.0):
    rng = random.Random(seed)
    limb((0, 0, 0), (0, 0, height * .96), .26 * spread, bark, .2, 8)
    tiers = 7
    for tier in range(tiers):
        t = tier / tiers
        radius = (1.9 * (1 - t) + .25) * spread
        z = height * (.18 + t * .74)
        center = (rng.uniform(-.1, .1), rng.uniform(-.1, .1), z)
        mat = rng.choice(mats)
        attach(foliage.cluster("Needle tier", center, (radius, radius, height*.1),
                              mat, rng, "needles", 56), "Needle tier", mat)


def broadleaf(seed, height, mats, bark, crown=1.0, trunk=.3):
    rng = random.Random(seed)
    top = Vector((0, 0, height * .45))
    limb((0, 0, 0), top, trunk, bark, .7)
    for branch in range(5):
        angle = branch * math.tau / 5 + rng.uniform(-.3, .3)
        tip = top + Vector((math.cos(angle) * 1.4 * crown, math.sin(angle) * 1.4 * crown, height * .25))
        limb(top, tip, trunk * .4, bark, .5)
        for pad in range(3):
            centre = top.lerp(tip, .6 + pad * .2) + Vector((rng.uniform(-.6, .6), rng.uniform(-.6, .6), rng.uniform(0, .8)))
            size = rng.uniform(1.2, 1.7) * crown
            blob("Leaf crown", centre, (size, size, size * .78), rng.choice(mats), rng, .28)
    blob("Leaf crown", (0, 0, height * .82), (2.1 * crown, 2.1 * crown, 1.5 * crown), rng.choice(mats), rng, .28)


def birch_cluster(seed):
    rng = random.Random(seed)
    for stem in range(3):
        angle = stem * 2.1
        base = Vector((math.cos(angle) * .6, math.sin(angle) * .6, 0))
        top = base + Vector((math.cos(angle) * .4, math.sin(angle) * .4, 6.0 + stem * .5))
        limb(base, top, .12, BIRCH_BARK, .5)
        for pad in range(4):
            blob("Birch crown", top.lerp(base, pad * .14) + Vector((rng.uniform(-.5, .5), rng.uniform(-.5, .5), 0)),
                 (.9, .9, 1.1), rng.choice(BIRCH), rng, .3)


def willow(seed):
    rng = random.Random(seed)
    top = Vector((0, 0, 3.2))
    limb((0, 0, 0), top, .4, OAK_BARK, .7)
    for index in range(14):
        angle = index * math.tau / 14
        hang = top + Vector((math.cos(angle) * 2.6, math.sin(angle) * 2.6, 1.4))
        blob("Willow crown", hang, (1.2, 1.2, 1.0), rng.choice(WILLOW), rng, .3)
        blob("Willow drape", hang + Vector((math.cos(angle) * .5, math.sin(angle) * .5, -1.6)),
             (.7, .7, 1.4), rng.choice(WILLOW), rng, .35, 0)


def fern(seed):
    rng = random.Random(seed)
    for index in range(9):
        angle = index * math.tau / 9 + rng.uniform(-.2, .2)
        tip = (math.cos(angle) * .7, math.sin(angle) * .7, .35)
        limb((0, 0, .05), tip, .1, rng.choice(FERN), .15, 4)


def shrub(seed, mats, radius, height, clumps=7, flowers=None):
    rng = random.Random(seed)
    for clump in range(clumps):
        angle = rng.uniform(0, math.tau)
        r = rng.uniform(0, radius * .55)
        centre = (math.cos(angle) * r, math.sin(angle) * r, height * rng.uniform(.35, .55))
        size = radius * rng.uniform(.35, .55)
        blob("Shrub clump", centre, (size, size, height * .5), rng.choice(mats), rng, .3, 0)
        if flowers and rng.random() < .5:
            blob("Flowers", (centre[0], centre[1], centre[2] + height * .3), (size * .4, size * .4, .08),
                 rng.choice(flowers), rng, .3, 0)


def hedge_segment(seed):
    rng = random.Random(seed)
    for index in range(9):
        x = -3.2 + index * .8
        blob("Hedge mass", (x, rng.uniform(-.15, .15), .85), (.75, .65, .85), rng.choice(HEDGE), rng, .25, 1)
    for index in range(3):
        blob("Hedge blossom", (-2.4 + index * 2.4, .3, 1.5), (.4, .3, .15), FLOWER[2], rng, .3, 0)


def mossy_log():
    limb((-2.6, 0, .35), (2.6, .2, .3), .32, OAK_BARK, .85, 9)
    rng = random.Random(9)
    for index in range(5):
        blob("Moss", (-2 + index, .1, .55), (.45, .3, .12), MOSS, rng, .3, 0)


def stump():
    cylinder("Stump", (0, 0, .35), .55, .7, CEDAR_BARK, 12)
    cylinder("Stump top", (0, 0, .71), .5, .03, LOG, 12)


def boulder(seed, size, index):
    rng = random.Random(seed)
    blob("Granite", (0, 0, size[2] * .45), size, GRANITE[index], rng, .2, 1)
    blob("Moss cap", (0, 0, size[2] * .85), (size[0] * .5, size[1] * .5, size[2] * .15), MOSS, rng, .3, 0)


# ---------------------------------------------------------------- structures

def sawmill():
    box("Mill shed", (0, 0, 2.6), (10, 6, 5.2), TIMBER_DARK)
    gable_roof("Mill roof", (0, 0, 5.2), 6, 10, 2.0, TIN).rotation_euler.z = math.pi / 2
    box("Saw floor", (-6.5, 0, 1.4), (3.0, 4.0, .3), TIMBER)
    for x in [-7.8, -5.2]:
        for y in [-1.8, 1.8]:
            limb((x, y, 0), (x, y, 1.3), .12, TIMBER, 1, 6)
    cylinder("Burner", (4.0, 4.6, 3.5), 1.4, 7.0, RUST, 14)
    cone("Burner cap", (4.0, 4.6, 7.4), 1.5, 1.0, RUST, 14, .6)
    for index in range(4):
        cylinder("Log deck", (-7, -4.5 + index * .9, .45 + (index % 2) * .3), .45, 6.0, LOG, 10, "x")


def log_pile(seed):
    rng = random.Random(seed)
    for row in range(3):
        for index in range(5 - row):
            cylinder("Log", (0, -1.6 + index * .8 + row * .4, .4 + row * .7), .4, 7.0, CEDAR_BARK, 10, "x")
    for side in [-3.6, 3.6]:
        for index in range(4):
            cylinder("Log end", (side, -1.6 + index * .8, .4), .38, .02, LOG, 10, "x")


def log_bridge():
    """Through-log span along local X; the deck top is the origin."""
    for x in [-6, -2, 2, 6]:
        for y in [-2.2, 2.2]:
            limb((x, y, -2.07), (x, y, -.37), .2, TIMBER_DARK, 1, 6)
    for y in [-2.0, -1.0, 0.0, 1.0, 2.0]:
        cylinder("Stringer log", (0, y, -.32), .3, 15.0, CEDAR_BARK, 10, "x")
    box("Deck planks", (0, 0, -.05), (15.0, 4.6, .1), TIMBER)
    for y in [-2.35, 2.35]:
        box("Rail", (0, y, .63), (15.0, .12, .12), TIMBER_DARK)
        for x in range(-7, 8, 2):
            limb((x, y, -.02), (x, y, .63), .06, TIMBER_DARK, 1, 5)


def stone_bridge():
    """Stone arch bridge along local X; the deck top is the origin."""
    for x in [-5.5, 0, 5.5]:
        box("Pier", (x, 0, -1.2), (1.4, 5.0, 2.0), STONE_DARK)
    box("Deck", (0, 0, -.25), (16.0, 5.0, .5), STONE)
    for y in [-2.3, 2.3]:
        box("Parapet", (0, y, .3), (16.0, .4, .7), STONE)
    for x in [-2.75, 2.75]:
        cylinder("Arch shade", (x, 0, -.9), 2.0, 5.02, STONE_DARK, 16, "y")


def farmhouse():
    box("House", (0, 0, 2.6), (8.0, 6.0, 5.2), WHITE_TRIM)
    gable_roof("Roof", (0, 0, 5.2), 6.0, 8.0, 2.6, SLATE).rotation_euler.z = math.pi / 2
    box("Porch", (0, -3.6, 1.4), (6.0, 1.4, .15), TIMBER)
    for x in [-2.6, 0, 2.6]:
        limb((x, -4.1, 0), (x, -4.1, 1.4), .07, WHITE_TRIM, 1, 6)
        box("Window", (x, -3.02, 3.6), (.9, .05, 1.0), GLASS)
    cylinder("Chimney", (2.8, 1.5, 7.2), .35, 2.2, STONE, 8)


def barn():
    box("Barn", (0, 0, 3.0), (10.0, 7.0, 6.0), RED_BARN)
    gable_roof("Barn roof", (0, 0, 6.0), 7.0, 10.0, 3.4, TIN).rotation_euler.z = math.pi / 2
    box("Barn door", (0, -3.52, 2.2), (3.6, .05, 4.4), TIMBER_DARK)
    for angle in [.6, -.6]:
        box("Door brace", (0, -3.56, 2.2), (4.0, .04, .2), WHITE_TRIM, 0, (0, angle))
    box("Hay door", (0, -3.52, 5.5), (1.4, .05, 1.2), WHITE_TRIM)


def grain_elevator():
    for x in [-3.6, -1.2, 1.2, 3.6]:
        cylinder("Silo", (x, 0, 9.0), 1.25, 18.0, CONCRETE, 16)
    box("Headhouse", (0, 0, 20.0), (9.4, 3.0, 4.0), CONCRETE)
    box("Headhouse roof", (0, 0, 22.1), (9.6, 3.2, .2), TIN)
    box("Driveway shed", (6.6, 0, 2.2), (3.0, 4.0, 4.4), TIN)
    limb((5.0, 0, 21.0), (9.0, 0, 3.0), .25, RUST, 1, 6)


def metal_silos():
    for index, x in enumerate([-2.2, 2.2]):
        cylinder("Grain bin", (x, 0, 3.2), 2.0, 6.4, TIN, 18)
        cone("Bin roof", (x, 0, 7.0), 2.1, 1.4, TIN, 18, .3)
    box("Auger", (0, 2.4, 4.0), (6.0, .4, .4), RUST, 0, (0, .4))


def hay_bales(seed):
    rng = random.Random(seed)
    for index in range(7):
        x = -3 + (index % 4) * 2.0
        y = -1 + (index // 4) * 2.2
        bale = cylinder("Round bale", (x, y, .75), .75, 1.2, HAY, 14, "y")
        bale.rotation_euler.z = rng.uniform(-.3, .3)


def stone_wall():
    rng = random.Random(41)
    for index in range(12):
        x = -2.75 + index * .5
        box("Wall stone", (x, rng.uniform(-.05, .05), .5), (.48, .55, 1.0 + rng.uniform(-.08, .08)),
            rng.choice([STONE, STONE_DARK]))
    box("Coping", (0, 0, 1.08), (6.0, .6, .16), STONE_DARK)


def church():
    box("Nave", (0, 2.0, 3.5), (7.0, 13.0, 7.0), LIMESTONE)
    gable_roof("Nave roof", (0, 2.0, 7.0), 7.0, 13.0, 3.6, SLATE)
    box("Tower", (0, -6.2, 6.0), (4.2, 4.2, 12.0), LIMESTONE)
    for x in [-1.9, 1.9]:
        for y in [-8.1, -4.3]:
            box("Pinnacle", (x, y, 12.6), (.5, .5, 1.2), LIMESTONE)
    box("Belfry louvre", (0, -8.32, 10.0), (1.4, .05, 2.0), TIMBER_DARK)
    box("Porch door", (0, -8.32, 1.6), (1.4, .05, 3.0), TIMBER_DARK)
    for y in [-1.5, 2.0, 5.5]:
        for x in [-3.52, 3.52]:
            box("Lancet window", (x, y, 3.8), (.05, .8, 2.4), GLASS)


def cottage(seed, length, mat_roof):
    rng = random.Random(seed)
    box("Cottage", (0, 0, 1.6), (length, 4.6, 3.2), rng.choice([STONE, WHITE_TRIM]))
    gable_roof("Cottage roof", (0, 0, 3.2), 4.6, length, 2.4, mat_roof, .45).rotation_euler.z = math.pi / 2
    cylinder("Chimney", (length / 2 - .4, 0, 5.4), .3, 1.6, STONE_DARK, 8)
    box("Door", (0, -2.32, 1.0), (.9, .05, 2.0), TIMBER_DARK)
    for x in [-length / 4, length / 4]:
        box("Window", (x, -2.32, 1.8), (.8, .05, .8), GLASS)


def water_mill():
    box("Mill house", (0, 0, 3.0), (7.0, 6.0, 6.0), STONE)
    gable_roof("Mill roof", (0, 0, 6.0), 6.0, 7.0, 2.8, SLATE).rotation_euler.z = math.pi / 2
    cylinder("Wheel", (0, 3.6, 2.4), 2.4, .6, TIMBER_DARK, 20, "y")
    for index in range(10):
        angle = index * math.tau / 10
        box("Paddle", (math.cos(angle) * 2.3, 3.6, 2.4 + math.sin(angle) * 2.3), (.7, .7, .1), TIMBER, 0, (0, angle))
    box("Race", (0, 5.0, .2), (8.0, 1.6, .2), WATER)


def picket_fence():
    for index in range(13):
        x = -3 + index * .5
        box("Picket", (x, 0, .55), (.08, .04, 1.1), WHITE_TRIM)
    for z in [.3, .85]:
        box("Rail", (0, 0, z), (6.2, .05, .08), WHITE_TRIM)


def grass_tuft():
    rng = random.Random(913)
    mat = material("Meadow grass", (.28, .35, .12))
    for index in range(24):
        angle = rng.uniform(0, math.tau)
        base = Vector((rng.uniform(-.24, .24), rng.uniform(-.24, .24), 0))
        tip = base + Vector((math.cos(angle)*.18, math.sin(angle)*.18, rng.uniform(.22, .48)))
        across = Vector((-math.sin(angle), math.cos(angle), 0))*.018
        middle = base.lerp(tip, .58)
        mesh = bpy.data.meshes.new("Grass blade")
        mesh.from_pydata([base-across, base+across, middle+across*.7, tip, middle-across*.7], [], [(0,1,2,4),(4,2,3)])
        obj = bpy.data.objects.new("Grass blade", mesh)
        bpy.context.collection.objects.link(obj)
        attach(obj, "Grass blade", mat)


builders = [
    ("MeadowGrass", .6, .5, grass_tuft),
    ("DouglasFir", 2.7, 14.0, lambda: conifer(201, 13.0, FIR, BARK, 1.15)),
    ("WesternRedCedar", 2.6, 10.5, lambda: conifer(202, 9.8, CEDAR, CEDAR_BARK, 1.1)),
    ("YoungSpruce", 1.8, 5.6, lambda: conifer(203, 5.2, FIR, BARK, .75)),
    ("OakTree", 5.6, 10.5, lambda: broadleaf(204, 9.0, OAK, OAK_BARK, 1.3, .45)),
    ("MapleTree", 4.6, 9.5, lambda: broadleaf(205, 8.2, MAPLE, OAK_BARK, 1.05, .3)),
    ("BirchCluster", 2.6, 8.4, lambda: birch_cluster(206)),
    ("RiverWillow", 5.2, 6.8, lambda: willow(207)),
    ("FernClump", 1.0, .6, lambda: fern(208)),
    ("SalalShrub", 1.2, 1.2, lambda: shrub(209, [SALAL], 1.1, 1.0)),
    ("Bramble", 1.4, 1.2, lambda: shrub(210, [BRAMBLE], 1.3, 1.0, 9, FLOWER[2:])),
    ("Wildflowers", 1.0, .5, lambda: shrub(211, [FERN[1]], .9, .35, 6, FLOWER)),
    ("HedgeSegment", 4.0, 1.9, lambda: hedge_segment(212)),
    ("MossyLog", 2.8, .8, mossy_log),
    ("Stump", .7, .8, stump),
    ("GraniteBoulderA", 1.7, 1.4, lambda: boulder(213, (1.1, .9, .8), 0)),
    ("GraniteBoulderB", 1.2, 1.0, lambda: boulder(214, (.75, .6, .55), 1)),
    ("Sawmill", 11.4, 8.2, sawmill),
    ("LogPile", 4.2, 2.4, lambda: log_pile(215)),
    ("LogBridge", 8.0, 1.5, log_bridge),
    ("StoneBridge", 8.5, 1.9, stone_bridge),
    ("Farmhouse", 5.6, 10.0, farmhouse),
    ("Barn", 6.6, 9.6, barn),
    ("GrainElevator", 9.8, 22.3, grain_elevator),
    ("MetalSilos", 4.6, 7.8, metal_silos),
    ("HayBales", 4.4, 1.6, lambda: hay_bales(216)),
    ("StoneWall", 3.2, 1.3, stone_wall),
    ("VillageChurch", 9.8, 13.3, church),
    ("CottageA", 4.9, 6.3, lambda: cottage(217, 7.0, THATCH)),
    ("CottageB", 4.5, 6.3, lambda: cottage(218, 6.0, SLATE)),
    ("WaterMill", 7.2, 9.0, water_mill),
    ("PicketFence", 3.2, 1.2, picket_fence),
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
manifest_path = ROOT / "art/environment/temperate-manifest.json"
if "--buildings-only" in sys.argv:
    manifest = {**json.loads(manifest_path.read_text()), **manifest}
else:
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/environment/TemperateKit.blend"))
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest))
