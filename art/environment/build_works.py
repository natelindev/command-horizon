"""Works kit for Emberworks (Ruhr/Pittsburgh steelworks) and Railspire
Junction (Chicago/Ruhr rail yard): furnace plant, mill sheds, stacks and gas
holders, rail track, rolling stock and yard structures, slag and stockpiles,
and the ruderal growth that takes over idle works.
Blender Z-up, Godot Y-up. Original procedural geometry; no external assets.
Run: blender --background --python art/environment/build_works.py
"""
import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/environment/works"
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


RUST = material("Rust", (.36, .17, .08), .85, .3)
RUST_LIGHT = material("Light rust", (.50, .26, .12), .85, .2)
IRON = material("Dark iron", (.16, .16, .17), .6, .6)
STEEL = material("Weathered steel", (.40, .41, .42), .55, .6)
BRICK = material("Brick", (.42, .17, .11))
BRICK_DARK = material("Sooty brick", (.24, .12, .09))
CONCRETE = material("Concrete", (.56, .55, .52))
CONCRETE_DARK = material("Stained concrete", (.36, .36, .35))
CLADDING = material("Corrugated cladding", (.36, .40, .43), .7, .4)
CLADDING_RUST = material("Rusting cladding", (.40, .27, .18), .8, .3)
ROOF = material("Shed roof", (.22, .23, .24), .7, .3)
GLASS = material("Grimy glass", (.18, .22, .22), .3)
BROKEN = material("Broken panes", (.05, .05, .05))
REFRACTORY = material("Refractory", (.47, .33, .24))
YELLOW = material("Safety yellow", (.82, .62, .10), .6, .2)
BLACK = material("Black paint", (.06, .06, .06), .6, .2)
COKE = material("Coke", (.08, .08, .08))
ORE = material("Iron ore", (.36, .16, .10))
SLAG = material("Slag", (.18, .17, .17), .95)
SLAG_LIGHT = material("Weathered slag", (.33, .31, .29), .95)
BALLAST = material("Ballast", (.33, .31, .29))
SLEEPER = material("Sleepers", (.20, .15, .11))
RAIL = material("Rail steel", (.45, .40, .36), .4, .8)
WEED = [material("Ruderal %d" % i, c) for i, c in enumerate([(.24, .32, .12), (.32, .36, .14), (.40, .40, .18)])]
BUDDLEIA = material("Buddleia blooms", (.40, .24, .48))
BIRCH_BARK = material("Birch bark", (.78, .76, .70))
BIRCH = [material("Birch leaves %d" % i, c) for i, c in enumerate([(.30, .42, .14), (.38, .48, .18)])]
CONTAINER = [material("Container %d" % i, c, .7, .3) for i, c in
             enumerate([(.55, .14, .10), (.12, .28, .45), (.20, .36, .22), (.62, .42, .12), (.42, .43, .44)])]
WAGON = material("Wagon brown", (.30, .16, .10), .8, .3)
SIGNAL_RED = material("Signal red", (.80, .08, .05), .4)
SIGNAL_GREEN = material("Signal green", (.10, .70, .25), .4)
WATER_TANK = material("Tank green", (.20, .28, .22), .7, .4)


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


def beam(a, b, size, mat):
    """A square section member between two points."""
    delta = Vector(b) - Vector(a)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(Vector(a) + Vector(b)) / 2)
    obj = bpy.context.object
    obj.scale = (size, size, delta.length)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return attach(obj, "Beam", mat)


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
    return attach(bpy.context.object, name, mat)


def dome(name, point, radius, mat, sides=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=sides, ring_count=8, radius=radius, location=point)
    obj = bpy.context.object
    for vertex in obj.data.vertices:
        vertex.co.z = max(vertex.co.z, 0.0)
    return attach(obj, name, mat)


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


def lathe(name, profile, mat, sides=24):
    """Surface of revolution about Z from (radius, height) pairs."""
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
    obj = mesh_object(name, verts, faces, mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def gable_roof(name, point, width, depth, rise, mat, overhang=.3):
    """A pitched roof whose ridge runs along local X."""
    x, y, z = point
    w = width / 2 + overhang
    d = depth / 2 + overhang
    verts = [(x - d, y - w, z), (x + d, y - w, z), (x + d, y + w, z), (x - d, y + w, z),
             (x - d, y, z + rise), (x + d, y, z + rise)]
    faces = [(0, 1, 5, 4), (3, 4, 5, 2), (0, 4, 3), (1, 2, 5)]
    return mesh_object(name, verts, faces, mat)


def truss(a, b, depth, mat, panels=6, size=.18):
    """A flat Warren truss between a and b, `depth` tall, in the vertical plane."""
    a = Vector(a)
    b = Vector(b)
    up = Vector((0, 0, depth))
    for point in [a, a + up]:
        beam(point, point + (b - a), size, mat)
    for index in range(panels):
        p = a.lerp(b, index / panels)
        q = a.lerp(b, (index + 1) / panels)
        beam(p, q + up if index % 2 == 0 else q, size * .7, mat)
        beam(p + up if index % 2 else p, q if index % 2 else q + up, size * .7, mat)


# ---------------------------------------------------------------- furnace plant

def blast_furnace():
    cylinder("Furnace hearth", (0, 0, 2.5), 4.6, 5.0, REFRACTORY, 20)
    lathe("Furnace shaft", [(4.4, 5.0), (4.8, 9.0), (3.6, 19.0), (2.4, 21.5)], RUST)
    cylinder("Bustle pipe", (0, 0, 8.0), 5.6, .9, IRON, 24)
    for index in range(10):
        angle = index * math.tau / 10
        limb((math.cos(angle) * 5.4, math.sin(angle) * 5.4, 7.6),
             (math.cos(angle) * 4.6, math.sin(angle) * 4.6, 5.6), .22, IRON)
    cylinder("Throat", (0, 0, 22.4), 2.4, 1.8, IRON, 16)
    for angle in [0, math.pi / 2, math.pi, 3 * math.pi / 2]:
        start = Vector((math.cos(angle) * 1.6, math.sin(angle) * 1.6, 23.0))
        limb(start, (math.cos(angle) * 1.2, math.sin(angle) * 1.2, 25.5), .45, RUST)
    limb((0, 0, 25.6), (8.5, 0, 13.0), .9, RUST)
    cylinder("Dust catcher", (9.5, 0, 8.0), 2.6, 9.0, RUST_LIGHT, 18)
    cone("Dust cone", (9.5, 0, 2.6), 2.6, 2.0, RUST_LIGHT, 18, .6)
    for leg in range(4):
        angle = leg * math.pi / 2 + math.pi / 4
        limb((9.5 + math.cos(angle) * 2.0, math.sin(angle) * 2.0, 0),
             (9.5 + math.cos(angle) * 2.0, math.sin(angle) * 2.0, 3.6), .2, IRON)
    for index in range(3):
        x = -5.0 + index * 5.0
        cylinder("Hot blast stove", (x, -9.5, 9.0), 2.5, 18.0, RUST, 18)
        dome("Stove dome", (x, -9.5, 18.0), 2.5, RUST)
    limb((-6, -9.5, 15.0), (5, -9.5, 15.0), .55, IRON)
    limb((0, -9.5, 15.0), (0, -4.6, 8.4), .55, IRON)
    box("Cast house", (-9.0, 4.0, 3.5), (10.0, 9.0, 7.0), CLADDING_RUST)
    gable_roof("Cast house roof", (-9.0, 4.0, 7.0), 9.0, 10.0, 2.0, ROOF)
    # Skip incline from the stock bins at the cast house end up to the throat.
    beam((-14, 0, 0.4), (-2.6, 0, 21.0), .9, STEEL)
    truss((-14, -.8, .6), (-3, -.8, 20.6), 1.6, STEEL, 6, .14)
    for x in [-12.0, -9.0, -6.0]:
        limb((x, 0, 0), (x, 0, .4 + (x + 14) / 11.4 * 20.6), .22, STEEL)


def mill_shed(length, seed):
    rng = random.Random(seed)
    width = 14.0
    box("Shed walls", (0, 0, 5.0), (length, width, 10.0), CLADDING)
    gable_roof("Shed roof", (0, 0, 10.0), width, length, 2.6, ROOF)
    box("Monitor", (0, 0, 13.0), (length * .9, 3.0, 1.4), CLADDING)
    box("Monitor glazing", (0, 1.52, 13.0), (length * .88, .06, .9), GLASS)
    box("Monitor glazing", (0, -1.52, 13.0), (length * .88, .06, .9), GLASS)
    gable_roof("Monitor roof", (0, 0, 13.7), 3.0, length * .9, .6, ROOF, .2)
    # Rust bleeds down the lower walls; a band of clerestory windows runs above.
    for side in [-1, 1]:
        y = side * (width / 2 + .03)
        box("Rust band", (0, y, 1.6), (length, .06, 3.2), CLADDING_RUST)
        box("Clerestory", (0, y, 8.2), (length * .92, .06, 1.2), GLASS)
        for index in range(int(length // 6)):
            x = -length / 2 + 3 + index * 6
            box("Column", (x, y * 1.004, 5.0), (.35, .1, 10.0), STEEL)
            if rng.random() < .3:
                box("Broken panel", (x + 1.5, y * 1.006, 8.2), (2.2, .06, 1.1), BROKEN)
            if rng.random() < .25:
                box("Downpipe", (x + .6, y * 1.008, 4.0), (.18, .18, 8.0), RUST)
    for end in [-1, 1]:
        x = end * (length / 2 + .03)
        box("Bay door", (x, 0, 3.8), (.06, 6.0, 7.6), RUST if rng.random() < .5 else STEEL)
        box("Door header", (x * 1.001, 0, 7.8), (.08, 6.6, .4), IRON)


def chimney():
    lathe("Stack", [(2.3, 0), (2.2, 2.0), (1.6, 26.0), (1.55, 28.0)], BRICK)
    for z in [8.0, 16.0, 24.0]:
        r = 2.2 - (z - 2.0) / 24.0 * .6
        cylinder("Iron band", (0, 0, z), r + .06, .3, IRON, 20)
    cylinder("Crown", (0, 0, 28.3), 1.75, .6, BRICK_DARK, 20)
    box("Plinth", (0, 0, .8), (5.4, 5.4, 1.6), BRICK_DARK)


def gasometer():
    cylinder("Gas holder", (0, 0, 5.5), 8.0, 11.0, RUST_LIGHT, 32)
    cylinder("Holder crown", (0, 0, 11.1), 8.0, .3, IRON, 32)
    for index in range(12):
        angle = index * math.tau / 12
        x, y = math.cos(angle) * 8.6, math.sin(angle) * 8.6
        limb((x, y, 0), (x, y, 15.5), .22, STEEL)
    for z in [5.0, 10.0, 15.4]:
        bpy.ops.mesh.primitive_torus_add(major_radius=8.6, minor_radius=.12, location=(0, 0, z),
                                         major_segments=36, minor_segments=6)
        attach(bpy.context.object, "Guide ring", STEEL)
    for index in range(12):
        a = index * math.tau / 12
        b = (index + 1) * math.tau / 12
        limb((math.cos(a) * 8.6, math.sin(a) * 8.6, 5.0), (math.cos(b) * 8.6, math.sin(b) * 8.6, 10.0), .08, STEEL)


def cooling_tower():
    lathe("Shell", [(9.5, 0), (8.6, 4.0), (6.4, 13.0), (6.2, 16.0), (6.8, 21.0)], CONCRETE)
    lathe("Shell inside", [(6.6, 21.0), (6.0, 16.0), (6.2, 13.0)], CONCRETE_DARK)
    for index in range(24):
        angle = index * math.tau / 24
        a = (math.cos(angle) * 9.8, math.sin(angle) * 9.8, 0)
        b = (math.cos(angle + .26) * 9.1, math.sin(angle + .26) * 9.1, 2.4)
        limb(a, b, .22, CONCRETE_DARK, 1, 6)


def conveyor_gallery():
    a = Vector((-11, 0, 1.0))
    b = Vector((11, 0, 9.5))
    for y in [-1.1, 1.1]:
        truss(a + Vector((0, y, 0)), b + Vector((0, y, 0)), 1.6, RUST, 9, .14)
    box("Gallery deck", ((a + b) / 2).to_tuple(), (23.4, 2.4, .2), CLADDING, 0, (0, -math.atan2(8.5, 22)))
    for x, height in [(-4, 3.6), (4, 6.6)]:
        for y in [-1.0, 1.0]:
            limb((x, y, 0), (x, y, height), .2, STEEL)
    box("Transfer tower", (12.0, 0, 5.5), (3.4, 3.4, 11.0), CLADDING_RUST)
    box("Tail house", (-12.0, 0, 1.0), (2.4, 3.0, 2.0), CONCRETE_DARK)


def pipe_rack():
    for x in [-5.0, 0.0, 5.0]:
        for y in [-1.2, 1.2]:
            limb((x, y, 0), (x, y, 5.0), .16, STEEL)
        box("Rack beam", (x, 0, 5.0), (.3, 2.8, .3), STEEL)
    for y, radius, mat in [(-.8, .45, RUST), (0.1, .32, IRON), (.9, .38, STEEL)]:
        cylinder("Pipe", (0, y, 5.0 + radius + .15), radius, 12.0, mat, 12, "x")
    bpy.ops.mesh.primitive_torus_add(major_radius=1.2, minor_radius=.32, location=(5.6, .1, 5.5),
                                     major_segments=16, minor_segments=8)
    obj = bpy.context.object
    obj.rotation_euler.x = math.pi / 2
    attach(obj, "Expansion loop", IRON)


def gantry_crane():
    for x in [-10.5, 10.5]:
        for y in [-2.5, 2.5]:
            limb((x, y, 0), (x * .96, y * .4, 11.0), .3, YELLOW)
        box("Sill", (x, 0, .3), (1.2, 6.0, .6), YELLOW)
    box("Girder", (0, -.6, 11.2), (24.0, .9, 1.4), YELLOW)
    box("Girder", (0, .6, 11.2), (24.0, .9, 1.4), YELLOW)
    box("Trolley", (3.0, 0, 12.2), (2.6, 2.6, 1.2), IRON)
    limb((3.0, 0, 11.6), (3.0, 0, 5.0), .05, STEEL)
    box("Hook block", (3.0, 0, 4.8), (.7, .5, .9), BLACK)
    box("Cab", (-8.5, -1.6, 9.8), (1.8, 1.6, 1.8), YELLOW)


def ore_pile(seed, mat, radius=4.4, height=2.8):
    rng = random.Random(seed)
    for index in range(5):
        angle = rng.uniform(0, math.tau)
        r = rng.uniform(0, radius * .4)
        size = rng.uniform(.55, .8) * radius
        blob("Stockpile", (math.cos(angle) * r, math.sin(angle) * r, 0), (size, size * .8, height), mat, rng, .1, 2)


def slag_rock(seed, size):
    rng = random.Random(seed)
    blob("Slag", (0, 0, size[2] * .4), size, rng.choice([SLAG, SLAG_LIGHT]), rng, .3, 1)


def scrap_pile(seed):
    rng = random.Random(seed)
    for index in range(10):
        angle = rng.uniform(0, math.tau)
        r = rng.uniform(0, 2.0)
        point = (math.cos(angle) * r, math.sin(angle) * r, rng.uniform(.2, 1.0))
        if rng.random() < .5:
            box("Scrap plate", point, (rng.uniform(.8, 2.0), rng.uniform(.3, 1.2), .12), rng.choice([RUST, RUST_LIGHT, IRON]),
                rng.uniform(0, math.tau), (rng.uniform(-.6, .6), rng.uniform(-.6, .6)))
        else:
            obj = cylinder("Scrap pipe", point, rng.uniform(.12, .3), rng.uniform(1.0, 2.6), rng.choice([RUST, IRON]), 8, "x")
            obj.rotation_euler.z = rng.uniform(0, math.tau)


def headframe():
    """A colliery winding tower: A-frame over the shaft, sheaves on top, a
    back-stay leaning to the winding house, and the shaft-top building."""
    for sx in [-1, 1]:
        for sy in [-1, 1]:
            beam((sx * 2.6, sy * 2.2, 0), (sx * 1.2, sy * 1.2, 18.0), .45, RUST)
    for z in [4.5, 9.0, 13.5]:
        s = 2.6 - z / 18.0 * 1.4
        for a, b in [((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))]:
            beam((a[0] * s, a[1] * s * .85, z), (b[0] * s, b[1] * s * .85, z), .2, RUST)
    for sy in [-1, 1]:
        beam((sy * 0, sy * 1.2, 18.0), (-9.0, sy * 1.6, 0), .5, RUST)
    box("Sheave deck", (0, 0, 18.3), (3.4, 3.0, .4), RUST)
    for x in [-.8, .8]:
        cylinder("Sheave", (x, 0, 19.8), 1.7, .25, IRON, 20, "y")
    box("Shaft house", (0, 0, 2.5), (8.0, 7.0, 5.0), BRICK)
    gable_roof("Shaft house roof", (0, 0, 5.0), 7.0, 8.0, 1.8, ROOF)
    box("Winding house", (-12.5, 0, 3.5), (7.0, 9.0, 7.0), BRICK)
    gable_roof("Winding house roof", (-12.5, 0, 7.0), 9.0, 7.0, 2.2, ROOF)
    for y in [-4.53, 4.53]:
        for x in [-14.5, -10.5]:
            box("Arched window", (x, y, 4.0), (1.4, .06, 3.2), GLASS)


# ---------------------------------------------------------------- rail

def rail_track():
    """A 6 m straight along local X; segments butt end to end."""
    box("Ballast", (0, 0, .12), (6.0, 3.2, .24), BALLAST)
    for index in range(10):
        box("Sleeper", (-2.7 + index * .6, 0, .3), (.26, 2.6, .14), SLEEPER)
    for y in [-.72, .72]:
        box("Rail", (0, y, .44), (6.0, .08, .16), RAIL)


def bogie(x):
    for y in [-.72, .72]:
        for dx in [-.9, .9]:
            cylinder("Wheel", (x + dx, y, .48), .46, .12, IRON, 12, "y")
    box("Bogie frame", (x, 0, .7), (2.6, 1.8, .3), IRON)


def torpedo_car():
    for x in [-4.2, 4.2]:
        bogie(x)
        box("Bolster", (x, 0, 1.2), (1.2, 2.4, .5), IRON)
    lathe_obj = lathe("Torpedo vessel", [(.3, -5.6), (1.4, -4.6), (1.75, -2.5), (1.8, 0), (1.75, 2.5), (1.4, 4.6), (.3, 5.6)], RUST)
    lathe_obj.rotation_euler.y = math.pi / 2
    lathe_obj.location.z = 2.6
    box("Pouring mouth", (0, 0, 4.3), (1.4, 1.2, .6), REFRACTORY)


def locomotive():
    for x in [-3.0, 3.0]:
        bogie(x)
    box("Frame", (0, 0, 1.25), (9.6, 2.7, .4), BLACK)
    box("Long hood", (-1.2, 0, 2.5), (6.0, 2.1, 2.1), YELLOW)
    box("Cab", (3.2, 0, 2.9), (2.4, 2.7, 2.9), YELLOW)
    box("Cab roof", (3.2, 0, 4.4), (2.6, 2.9, .15), BLACK)
    for y in [-1.37, 1.37]:
        box("Cab window", (3.4, y, 3.4), (1.4, .05, .8), GLASS)
    for index in range(5):
        box("Hazard stripe", (4.82, -1.0 + index * .5, 1.25), (.06, .25, .4), BLACK if index % 2 else YELLOW, 0, (.6, 0))
    box("Exhaust", (-2.5, 0, 3.75), (.4, .4, .4), BLACK)


def hopper_wagon(seed, load):
    for x in [-3.2, 3.2]:
        bogie(x)
    mesh_object("Hopper", [(-4.4, -1.4, 3.6), (4.4, -1.4, 3.6), (4.4, 1.4, 3.6), (-4.4, 1.4, 3.6),
                           (-3.0, -.9, 1.1), (3.0, -.9, 1.1), (3.0, .9, 1.1), (-3.0, .9, 1.1)],
                [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)], WAGON)
    if load is not None:
        rng = random.Random(seed)
        box("Load", (0, 0, 3.55), (8.4, 2.6, .3), load)
        for x in [-2.6, 0.0, 2.6]:
            blob("Heap", (x, 0, 3.6), (1.3, 1.3, .5), load, rng, .15, 1)


def boxcar(seed):
    rng = random.Random(seed)
    for x in [-3.6, 3.6]:
        bogie(x)
    box("Boxcar body", (0, 0, 2.6), (10.0, 2.8, 2.9), rng.choice([WAGON, CONTAINER[0], CONTAINER[1]]))
    box("Boxcar roof", (0, 0, 4.12), (10.1, 2.9, .14), STEEL)
    for y in [-1.42, 1.42]:
        box("Sliding door", (0, y, 2.4), (2.6, .05, 2.4), RUST)


def tank_wagon():
    for x in [-3.4, 3.4]:
        bogie(x)
    box("Underframe", (0, 0, 1.25), (9.0, 2.2, .3), BLACK)
    obj = cylinder("Tank barrel", (0, 0, 2.6), 1.35, 8.6, BLACK, 20, "x")
    cylinder("Dome", (0, 0, 4.0), .45, .5, BLACK, 12)
    box("Hazard plate", (0, -1.37, 2.6), (.8, .04, .6), YELLOW)


def signal_gantry():
    for x in [-8.0, 8.0]:
        beam((x, 0, 0), (x, 0, 7.0), .4, STEEL)
    truss((-8.2, 0, 6.6), (8.2, 0, 6.6), 1.0, STEEL, 8, .12)
    for x in [-6.0, -2.0, 2.0, 6.0]:
        box("Signal head", (x, -.3, 6.0), (.5, .4, 1.4), BLACK)
        box("Aspect", (x, -.52, 6.4), (.22, .04, .22), SIGNAL_RED if x < 0 else SIGNAL_GREEN)


def engine_shed():
    box("Shed", (0, 0, 4.0), (26.0, 18.0, 8.0), BRICK)
    for index in range(3):
        y = -6.0 + index * 6.0
        box("Arch door", (13.04, y, 3.0), (.06, 4.4, 6.0), BRICK_DARK)
        box("Door leaf", (13.06, y, 2.6), (.06, 4.0, 5.2), WAGON)
    # Sawtooth roof: glazed north lights over each bay.
    for index in range(5):
        x = -10.4 + index * 5.2
        mesh_object("Sawtooth", [(x - 2.6, -9.2, 8.0), (x + 2.6, -9.2, 8.0), (x + 2.6, 9.2, 8.0), (x - 2.6, 9.2, 8.0),
                                 (x + 2.6, -9.2, 10.4), (x + 2.6, 9.2, 10.4)],
                    [(0, 1, 4), (3, 5, 2), (0, 4, 5, 3), (1, 2, 5, 4)], ROOF)
        box("North light", (x + 2.62, 0, 9.2), (.06, 18.0, 2.2), GLASS)
    for y in [-9.03, 9.03]:
        for index in range(6):
            box("Window", (-10 + index * 4, y, 4.8), (1.8, .06, 2.6), GLASS)
    cylinder("Shed chimney", (-11.0, 7.0, 11.0), .6, 6.0, BRICK_DARK, 10)


def water_tower():
    for sx in [-1, 1]:
        for sy in [-1, 1]:
            limb((sx * 2.6, sy * 2.6, 0), (sx * 2.0, sy * 2.0, 9.0), .2, STEEL)
    for z in [3.0, 6.0]:
        for a, b in [((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))]:
            s = 2.6 - z / 9.0 * .6
            limb((a[0] * s, a[1] * s, z), (b[0] * s, b[1] * s, z), .08, STEEL)
    cylinder("Tank", (0, 0, 11.0), 3.4, 4.0, WATER_TANK, 24)
    cone("Tank roof", (0, 0, 13.6), 3.5, 1.2, WATER_TANK, 24, .3)
    limb((3.2, 0, 10.0), (5.6, 0, 6.0), .25, IRON)
    limb((5.6, 0, 6.0), (5.6, 0, 4.4), .25, IRON)


def container_stack(seed):
    rng = random.Random(seed)
    for row in range(3):
        for level in range(2 if row != 1 else 3):
            if level == 2 and rng.random() < .5:
                continue
            box("Container", (0, -2.6 + row * 2.6, 1.3 + level * 2.6), (12.0, 2.44, 2.59), rng.choice(CONTAINER))


def girder_bridge():
    """Through-girder bridge along local X; the deck top is the origin."""
    box("Deck", (0, 0, -.25), (20.0, 7.0, .5), CONCRETE)
    for y in [-3.2, 3.2]:
        box("Girder", (0, y, -1.05), (20.0, .5, 1.4), RUST)
        box("Parapet", (0, y, .4), (20.0, .25, .8), CONCRETE_DARK)
    for x in [-10.6, 10.6]:
        box("Abutment", (x, 0, -1.75), (1.4, 8.0, 3.0), CONCRETE_DARK)


def overpass_span():
    """A 12 m road span at 3 m over a gap between embankments, along local X."""
    box("Span deck", (0, 0, 3.0), (12.0, 8.0, .5), CONCRETE)
    box("Lane", (0, 0, 3.27), (12.0, 6.4, .04), BALLAST)
    for y in [-3.4, 3.4]:
        box("Girder", (0, y, 2.2), (12.0, .6, 1.2), RUST)
        box("Parapet", (0, y * 1.08, 3.65), (12.0, .3, .8), CONCRETE_DARK)
    for x in [-5.6, 5.6]:
        box("Bearing shelf", (x, 0, 1.4), (.8, 8.0, 2.8), CONCRETE_DARK)


def canal_bridge():
    """Through-truss road bridge along local X; the deck top is the origin."""
    box("Deck", (0, 0, -.25), (24.0, 7.0, .5), CONCRETE_DARK)
    box("Lane", (0, 0, .02), (24.0, 5.6, .04), BALLAST)
    for y in [-3.4, 3.4]:
        truss((-11.5, y, .1), (11.5, y, .1), 3.2, RUST_LIGHT, 8, .22)
        box("Kerb", (0, y * .93, .2), (24.0, .3, .4), CONCRETE)
    for x in [-11.5, 11.5]:
        box("Portal", (x, 0, 3.4), (.4, 7.2, .4), RUST_LIGHT)
        box("Abutment", (x + (1.2 if x > 0 else -1.2), 0, -1.4), (2.4, 8.0, 2.4), CONCRETE_DARK)


def canal_lock():
    """Lock gates across a canal running along local Y (10 m between walls)."""
    for y in [-9.0, 9.0]:
        for side in [-1, 1]:
            # Mitre gates meet at an angle pointing upstream.
            gate = box("Mitre gate", (side * 2.6, y - (.9 if y > 0 else -.9), -.4), (5.6, .5, 2.4), RUST, 0)
            gate.rotation_euler.z = side * (.32 if y > 0 else -.32)
        box("Gate walkway", (0, y, .95), (11.0, .8, .12), STEEL)
        for side in [-1, 1]:
            box("Balance beam", (side * 7.2, y, 1.2), (4.0, .35, .35), IRON, side * .2)
    for x in [-5.6, 5.6]:
        box("Lock wall", (x, 0, -.6), (1.2, 26.0, 1.6), CONCRETE)
        for y in [-11.0, -3.0, 3.0, 11.0]:
            cylinder("Bollard", (x + (.3 if x > 0 else -.3), y, .45), .18, .5, IRON, 10)


def buffer_stop():
    box("Buffer frame", (0, 0, .7), (.6, 2.6, 1.4), IRON)
    for y in [-.8, .8]:
        cylinder("Buffer", (.45, y, 1.0), .22, .5, BLACK, 10, "x")
    beam((-1.6, -.9, 0), (0, -.9, 1.3), .2, IRON)
    beam((-1.6, .9, 0), (0, .9, 1.3), .2, IRON)
    box("Lamp", (0, 0, 1.55), (.3, .3, .3), SIGNAL_RED)


# ---------------------------------------------------------------- growth

def buddleia(seed):
    rng = random.Random(seed)
    for index in range(7):
        angle = rng.uniform(0, math.tau)
        r = rng.uniform(0, .6)
        centre = (math.cos(angle) * r, math.sin(angle) * r, rng.uniform(.6, 1.2))
        blob("Leaves", centre, (.6, .6, .6), rng.choice(WEED), rng, .3, 0)
        tip = (centre[0] * 1.6, centre[1] * 1.6, centre[2] + .6)
        limb(centre, tip, .12, BUDDLEIA, .2, 5)


def ruderal(seed):
    rng = random.Random(seed)
    for index in range(14):
        angle = index * math.tau / 14 + rng.uniform(-.2, .2)
        reach = rng.uniform(.25, .55)
        limb((0, 0, 0), (math.cos(angle) * reach, math.sin(angle) * reach, rng.uniform(.3, .6)), .05,
             rng.choice(WEED), .15, 4)


def scrub_birch(seed):
    rng = random.Random(seed)
    for stem in range(2):
        angle = stem * 2.6
        base = Vector((math.cos(angle) * .4, math.sin(angle) * .4, 0))
        top = base + Vector((math.cos(angle) * .5, math.sin(angle) * .5, 4.6 + stem))
        limb(base, top, .1, BIRCH_BARK, .5, 6)
        for pad in range(3):
            blob("Birch crown", top.lerp(base, pad * .18) + Vector((rng.uniform(-.4, .4), rng.uniform(-.4, .4), 0)),
                 (.8, .8, 1.0), rng.choice(BIRCH), rng, .3, 0)


builders = [
    ("BlastFurnace", 17.0, 26.5, blast_furnace),
    ("MillShedLong", 21.5, 14.5, lambda: mill_shed(36.0, 401)),
    ("MillShedShort", 13.5, 14.5, lambda: mill_shed(20.0, 402)),
    ("Chimney", 4.0, 29.0, chimney),
    ("Headframe", 17.2, 21.6, headframe),
    ("Gasometer", 9.0, 16.0, gasometer),
    ("CoolingTower", 10.2, 21.5, cooling_tower),
    ("ConveyorGallery", 14.5, 12.0, conveyor_gallery),
    ("PipeRack", 7.2, 7.2, pipe_rack),
    ("GantryCrane", 13.0, 13.0, gantry_crane),
    ("OrePile", 6.0, 3.2, lambda: ore_pile(403, ORE)),
    ("CokePile", 6.0, 3.2, lambda: ore_pile(404, COKE)),
    ("SlagRockA", 1.8, 1.4, lambda: slag_rock(405, (1.2, 1.0, .9))),
    ("SlagRockB", 1.2, 0.9, lambda: slag_rock(406, (.8, .7, .6))),
    ("ScrapPile", 3.4, 2.4, lambda: scrap_pile(407)),
    ("RailTrack", 3.5, .6, rail_track),
    ("TorpedoCar", 6.5, 4.8, torpedo_car),
    ("Locomotive", 5.6, 4.6, locomotive),
    ("HopperWagon", 5.0, 4.2, lambda: hopper_wagon(408, ORE)),
    ("HopperEmpty", 5.0, 4.0, lambda: hopper_wagon(409, None)),
    ("Boxcar", 5.6, 4.3, lambda: boxcar(410)),
    ("TankWagon", 5.0, 4.3, tank_wagon),
    ("SignalGantry", 8.6, 7.8, signal_gantry),
    ("EngineShed", 16.0, 14.2, engine_shed),
    ("WaterTower", 6.0, 14.4, water_tower),
    ("ContainerStack", 7.2, 7.9, lambda: container_stack(411)),
    ("GirderBridge", 12.2, 4.1, girder_bridge),
    ("CanalBridge", 14.6, 3.8, canal_bridge),
    ("OverpassSpan", 7.6, 4.1, overpass_span),
    ("CanalLock", 14.6, 3.9, canal_lock),
    ("BufferStop", 2.0, 1.8, buffer_stop),
    ("Buddleia", 1.6, 2.2, lambda: buddleia(412)),
    ("Ruderal", .7, .7, lambda: ruderal(413)),
    ("ScrubBirch", 2.0, 6.8, lambda: scrub_birch(414)),
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
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/environment/WorksKit.blend"))
(ROOT / "art/environment/works-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest))
