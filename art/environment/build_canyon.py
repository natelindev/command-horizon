"""Canyon-country kit for Redrock Divide (Utah/Arizona). Blender Z-up, Godot Y-up.
Flora: Utah juniper (two forms), pinyon pine, Fremont cottonwood, sagebrush,
rabbitbrush and yucca. Rock: sandstone boulders and a talus cluster. Props: a
collapsed timber rail trestle (standing bent and fallen debris), a windmill
with stock tank, a stone ranch ruin, a fence run and a telegraph pole.
Original procedural geometry; no textures or external assets.
Run: blender --background --python art/environment/build_canyon.py
"""
import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/environment/canyon"
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


BARK = material("Juniper shreddy bark", (.21, .15, .10))
PALE_BARK = material("Cottonwood furrowed bark", (.33, .30, .25))
JUNIPER = [material("Juniper scale foliage %d" % i, c) for i, c in enumerate(
    [(.13, .19, .14), (.17, .24, .17), (.22, .29, .20)])]
PINYON = [material("Pinyon needles %d" % i, c) for i, c in enumerate(
    [(.10, .18, .10), (.14, .23, .12), (.19, .28, .15)])]
COTTONWOOD = [material("Cottonwood leaves %d" % i, c) for i, c in enumerate(
    [(.26, .36, .12), (.34, .44, .16), (.44, .52, .20)])]
SAGE = [material("Sagebrush %d" % i, c) for i, c in enumerate(
    [(.36, .40, .32), (.44, .48, .39)])]
RABBIT = material("Rabbitbrush stems", (.38, .42, .26))
BLOOM = material("Rabbitbrush bloom", (.78, .64, .16))
YUCCA = material("Yucca blades", (.30, .38, .24))
STALK = material("Yucca flower stalk", (.55, .48, .33))
SANDSTONE = [material("Boulder sandstone %d" % i, c) for i, c in enumerate(
    [(.55, .26, .14), (.63, .33, .19), (.70, .45, .30), (.48, .24, .14)])]
TIMBER = material("Weathered creosote timber", (.20, .15, .11))
TIMBER_PALE = material("Sun-bleached timber", (.42, .36, .28))
RAIL = material("Rusted rail", (.30, .16, .09), .7, .4)
GALV = material("Weathered galvanized steel", (.45, .46, .44), .55, .6)
WATER = material("Stock tank water", (.12, .19, .17), .15)
STONE = material("Ranch stone masonry", (.56, .44, .33))
STONE_DARK = material("Ranch stone shadowed", (.42, .32, .24))
ROOF = material("Rusted corrugated roof", (.36, .20, .11), .75, .3)
WIRE = material("Fence wire", (.25, .24, .22), .6, .4)


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


def limb(a, b, radius, mat=BARK, taper=.6):
    delta = Vector(b) - Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=radius, radius2=radius * taper,
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


def cylinder(name, point, radius, depth, mat, sides=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth,
                                        location=point)
    return attach(bpy.context.object, name, mat)


def blob(name, center, size, mat, rng, roughness=.22, subdivisions=1):
    """A faceted, irregular clump: foliage pads and boulders."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=center)
    obj = bpy.context.object
    for vertex in obj.data.vertices:
        vertex.co *= 1 + rng.uniform(-roughness, roughness)
    obj.scale = size
    obj.rotation_euler.z = rng.uniform(0, math.tau)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return attach(obj, name, mat, flat=True)


def juniper(seed, height):
    rng = random.Random(seed)
    lean = rng.uniform(-.35, .35)
    base = Vector((0, 0, 0))
    fork = Vector((lean * .4, rng.uniform(-.15, .15), height * .32))
    limb(base, fork, .2, BARK, .7)
    # Gnarled multi-stem habit: several twisting leaders.
    for stem in range(4):
        angle = stem * math.tau / 4 + rng.uniform(-.4, .4)
        mid = fork + Vector((math.cos(angle) * .45, math.sin(angle) * .45, height * .22))
        top = mid + Vector((math.cos(angle) * .35, math.sin(angle) * .35, height * .3))
        limb(fork, mid, .11, BARK, .75)
        limb(mid, top, .07, BARK, .6)
        for pad in range(5):
            centre = mid.lerp(top, rng.uniform(.2, 1.05)) + Vector(
                (rng.uniform(-.55, .55), rng.uniform(-.55, .55), rng.uniform(-.2, .35)))
            size = rng.uniform(.5, .85)
            blob("Juniper foliage pad", centre, (size, size, size * .78),
                 rng.choice(JUNIPER), rng)


def pinyon(seed, height):
    rng = random.Random(seed)
    limb((0, 0, 0), (0, 0, height * .55), .2, BARK, .55)
    tiers = 5
    for tier in range(tiers):
        level = .22 + tier * .15
        radius = 1.35 * (1 - level * .7)
        for pad in range(6 - tier):
            angle = pad * math.tau / (6 - tier) + rng.uniform(-.3, .3) + tier
            centre = Vector((math.cos(angle) * radius * .55, math.sin(angle) * radius * .55,
                             height * level))
            size = radius * rng.uniform(.55, .75)
            blob("Pinyon crown", centre, (size, size, size * .65), rng.choice(PINYON), rng)
    blob("Pinyon crown", (0, 0, height * .93), (.45, .45, .5), PINYON[1], rng)


def cottonwood(seed, height):
    rng = random.Random(seed)
    trunk_top = Vector((0, 0, height * .38))
    limb((0, 0, 0), trunk_top, .42, PALE_BARK, .7)
    for root in range(5):
        angle = root * math.tau / 5
        limb((math.cos(angle) * .7, math.sin(angle) * .7, .05), (0, 0, .7), .14, PALE_BARK, .5)
    for branch in range(5):
        angle = branch * math.tau / 5 + rng.uniform(-.3, .3)
        elbow = trunk_top + Vector((math.cos(angle) * 1.4, math.sin(angle) * 1.4, height * .2))
        tip = elbow + Vector((math.cos(angle) * 1.3, math.sin(angle) * 1.3, height * .25))
        limb(trunk_top, elbow, .2, PALE_BARK, .7)
        limb(elbow, tip, .12, PALE_BARK, .55)
        for crown in range(5):
            centre = elbow.lerp(tip, .35 + crown * .2) + Vector(
                (rng.uniform(-.7, .7), rng.uniform(-.7, .7), rng.uniform(-.2, .7)))
            size = rng.uniform(1.25, 1.75)
            blob("Cottonwood crown", centre, (size, size, size * .8),
                 rng.choice(COTTONWOOD), rng, .28)
    for centre in [(0, 0, height * .86), (.8, .6, height * .74), (-.8, -.5, height * .76)]:
        blob("Cottonwood crown", centre, (1.8, 1.8, 1.3), rng.choice(COTTONWOOD), rng, .28)


def shrub(seed, mats, radius, height, flowers=False):
    rng = random.Random(seed)
    for clump in range(7):
        angle = rng.uniform(0, math.tau)
        r = rng.uniform(0, radius * .55)
        centre = (math.cos(angle) * r, math.sin(angle) * r, height * rng.uniform(.35, .55))
        size = radius * rng.uniform(.35, .55)
        blob("Shrub clump", centre, (size, size, height * .5), rng.choice(mats), rng, .3)
        if flowers:
            blob("Bloom", (centre[0], centre[1], centre[2] + height * .35),
                 (size * .7, size * .7, height * .18), BLOOM, rng, .35)


def yucca(seed):
    rng = random.Random(seed)
    for blade in range(18):
        angle = blade * 2.4
        rise = rng.uniform(.4, .95)
        tip = (math.cos(angle) * .55 * (1.1 - rise), math.sin(angle) * .55 * (1.1 - rise),
               .25 + rise * .6)
        limb((0, 0, .12), tip, .035, YUCCA, .15)
    limb((0, 0, .5), (.05, .03, 2.2), .03, STALK, .5)
    for pod in range(6):
        cylinder("Seed pod", (.05, .03, 1.6 + pod * .1), .05, .08, STALK, 6)


def boulder(seed, size, mat_index):
    rng = random.Random(seed)
    blob("Boulder", (0, 0, size[2] * .45), size, SANDSTONE[mat_index], rng, .18, 2)
    for chip in range(3):
        angle = rng.uniform(0, math.tau)
        r = max(size[0], size[1]) * 1.05
        blob("Spall", (math.cos(angle) * r, math.sin(angle) * r, .12),
             (.25, .2, .14), SANDSTONE[(mat_index + 1) % 4], rng, .25)


def talus(seed):
    rng = random.Random(seed)
    for stone in range(14):
        angle = rng.uniform(0, math.tau)
        r = rng.uniform(0, 2.2)
        s = rng.uniform(.2, .75) * (1.2 - r / 2.4)
        blob("Talus block", (math.cos(angle) * r, math.sin(angle) * r, s * .35),
             (s, s * rng.uniform(.6, 1.0), s * .6), rng.choice(SANDSTONE), rng, .2)


def trestle_bent(seed, height):
    """One standing timber bent of a collapsed rail trestle, rails hanging off."""
    rng = random.Random(seed)
    for x in [-1.3, -.45, .45, 1.3]:
        lean = .12 if abs(x) > 1 else 0
        limb((x * 1.15, 0, 0), (x, 0, height), .13, TIMBER, .9)
    for z in [height * .3, height * .65]:
        box("Brace", (0, 0, z), (3.0, .16, .16), TIMBER_PALE)
        for side in [-1, 1]:
            limb((-1.3, 0, z - height * .3 + .2), (1.3, 0, z + .4 * side), .07, TIMBER_PALE, 1)
    box("Cap", (0, 0, height + .12), (3.3, .5, .25), TIMBER)
    for y in range(6):
        box("Tie", (0, -1.25 + y * .5, height + .32), (2.6, .22, .14), TIMBER)
    for x in [-.72, .72]:
        box("Rail", (x, .2, height + .45), (.1, 3.4, .12), RAIL, 0, (rng.uniform(-.08, .08), 0))
    # Torn rails sag over the gap.
    for x in [-.72, .72]:
        limb((x, 1.9, height + .45), (x + .2, 3.4, height - 1.4), .05, RAIL, 1)


def trestle_debris(seed):
    rng = random.Random(seed)
    for beam in range(16):
        angle = rng.uniform(0, math.tau)
        length = rng.uniform(1.5, 3.5)
        centre = Vector((rng.uniform(-3, 3), rng.uniform(-2, 2), .15 + rng.uniform(0, .4)))
        direction = Vector((math.cos(angle), math.sin(angle), rng.uniform(-.25, .25)))
        limb(centre - direction * length / 2, centre + direction * length / 2,
             rng.uniform(.08, .14), rng.choice([TIMBER, TIMBER_PALE]), 1)
    for x in [-.72, .72]:
        limb((x - 2.5, -1.2, .12), (x + 2.6, 1.0, .35), .05, RAIL, 1)


def windmill():
    rng = random.Random(77)
    height = 7.5
    for corner in [(-1, -1), (1, -1), (1, 1), (-1, 1)]:
        limb((corner[0] * .9, corner[1] * .9, 0), (corner[0] * .18, corner[1] * .18, height),
             .045, GALV, .7)
    for level in range(1, 6):
        z = level * height / 6
        r = .9 - (.72 * level / 6)
        for edge in range(4):
            a = [(-1, -1), (1, -1), (1, 1), (-1, 1)][edge]
            b = [(-1, -1), (1, -1), (1, 1), (-1, 1)][(edge + 1) % 4]
            limb((a[0] * r, a[1] * r, z), (b[0] * r, b[1] * r, z), .02, GALV, 1)
    box("Platform", (0, 0, height - .1), (.7, .7, .06), TIMBER_PALE)
    box("Gearbox", (0, .15, height + .25), (.3, .55, .3), GALV)
    box("Tail vane", (0, 1.4, height + .35), (.04, 1.2, .55), GALV)
    for blade in range(16):
        angle = blade * math.tau / 16
        limb((0, -.25, height + .3), (math.cos(angle) * 1.25, -.3, height + .3 + math.sin(angle) * 1.25),
             .05, GALV, 1.6)
    limb((0, 0, height - .2), (0, 0, .3), .02, GALV, 1)
    cylinder("Stock tank", (2.6, .3, .32), 1.25, .64, GALV, 24)
    cylinder("Stock tank water", (2.6, .3, .6), 1.18, .04, WATER, 24)
    limb((.3, 0, .55), (1.5, .2, .62), .04, GALV, 1)


def ranch_ruin():
    rng = random.Random(91)
    walls = [((0, -2.5), (5, .45, 2.4)), ((0, 2.5), (5, .45, 1.6)), ((-2.3, 0), (.45, 5, 2.2))]
    for (x, y), size in walls:
        box("Stone wall", (x, y, size[2] / 2), size, rng.choice([STONE, STONE_DARK]))
    box("Broken gable", (2.3, -1.2, .9), (.45, 2.6, 1.8), STONE)
    box("Fallen stones", (2.6, 1.4, .2), (.9, 1.6, .4), STONE_DARK, .4)
    box("Collapsed roof", (.3, .4, 1.1), (4.6, 3.4, .06), ROOF, .1, (.25, -.1))
    box("Roof beam", (-.4, 0, 1.7), (4.8, .18, .18), TIMBER, 0, (0, -.15))
    box("Door lintel", (-2.3, .8, 1.9), (.5, 1.2, .2), TIMBER)
    for index in range(5):
        boulder_size = rng.uniform(.25, .45)
        blob("Rubble", (rng.uniform(-3, 3), rng.uniform(-3.4, -2.8), .15),
             (boulder_size, boulder_size, boulder_size * .7), STONE, rng, .2)


def fence_run():
    for post in range(5):
        x = -4 + post * 2
        limb((x, 0, 0), (x + .03, 0, 1.25), .06, TIMBER_PALE, .9)
    for z in [.45, .8, 1.12]:
        limb((-4, 0, z), (4, 0, z - .05), .008, WIRE, 1)


def telegraph_pole():
    limb((0, 0, 0), (0, 0, 7.0), .13, TIMBER, .75)
    box("Crossarm", (0, 0, 6.5), (1.9, .12, .12), TIMBER_PALE)
    for x in [-.8, -.3, .3, .8]:
        cylinder("Insulator", (x, 0, 6.65), .05, .14, STONE, 8)


builders = [
    ("UtahJuniperA", 2.2, 4.2, lambda: juniper(11, 3.6)),
    ("UtahJuniperB", 2.2, 3.6, lambda: juniper(23, 3.0)),
    ("PinyonPine", 2.0, 5.2, lambda: pinyon(31, 4.8)),
    ("FremontCottonwood", 5.4, 9.8, lambda: cottonwood(41, 8.6)),
    ("Sagebrush", 1.0, 1.0, lambda: shrub(51, SAGE, 1.1, .8)),
    ("Rabbitbrush", 1.0, 1.1, lambda: shrub(61, [RABBIT], 1.0, .85, True)),
    ("Yucca", 1.0, 2.4, lambda: yucca(71)),
    ("BoulderA", 1.8, 1.4, lambda: boulder(81, (1.1, .8, .75), 0)),
    ("BoulderB", 2.3, 1.9, lambda: boulder(82, (1.5, 1.1, 1.0), 1)),
    ("BoulderC", 1.2, 1.0, lambda: boulder(83, (.7, .55, .55), 2)),
    ("TalusCluster", 3.0, 1.0, lambda: talus(84)),
    ("TrestleBent", 3.6, 7.0, lambda: trestle_bent(85, 6.0)),
    ("TrestleDebris", 4.6, 1.3, lambda: trestle_debris(86)),
    ("Windmill", 4.2, 9.2, windmill),
    ("RanchRuin", 4.4, 2.8, ranch_ruin),
    ("FenceRun", 4.2, 1.4, fence_run),
    ("TelegraphPole", 1.1, 7.2, telegraph_pole),
]
for name, radius, height, build in builders:
    begin(name, radius, height)
    build()

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
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/environment/CanyonKit.blend"))
(ROOT / "art/environment/canyon-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest))
