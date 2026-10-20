"""Harbour kit for Coastal Foundry (working harbour with a foundry and dry
dock) and Sunken Exchange (flooded canal city): quay cranes, sheds and
ships, harbour buildings, canal houses, the exchange hall, campanile,
bridges and boats.
Blender Z-up, Godot Y-up. Original procedural geometry; no external assets.
Run: blender --background --python art/environment/build_harbour.py
"""
import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/environment/harbour"
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


CRANE_RED = material("Crane red", (.55, .10, .07), .6, .3)
CRANE_BLUE = material("Crane blue", (.12, .26, .42), .6, .3)
STEEL = material("Steel", (.40, .41, .42), .55, .6)
IRON = material("Dark iron", (.14, .14, .15), .6, .6)
RUST = material("Rust", (.36, .17, .08), .85, .3)
BRICK = material("Brick", (.45, .19, .12))
BRICK_DARK = material("Dark brick", (.30, .14, .10))
BRICK_WARM = material("Warm brick", (.58, .30, .18))
PLASTER = [material("Plaster %d" % i, c) for i, c in
           enumerate([(.78, .62, .44), (.70, .42, .30), (.82, .76, .62), (.62, .52, .40), (.74, .56, .36)])]
STONE = material("Limestone", (.72, .68, .60))
STONE_DARK = material("Weathered stone", (.50, .47, .42))
CONCRETE = material("Concrete", (.58, .57, .54))
CONCRETE_DARK = material("Stained concrete", (.38, .38, .37))
ROOF_TILE = material("Roof tiles", (.48, .22, .14))
ROOF_SLATE = material("Slate", (.20, .21, .24))
COPPER = material("Verdigris copper", (.30, .52, .44), .5, .4)
GLASS = material("Glass", (.14, .20, .24), .2)
WHITE = material("White paint", (.86, .86, .82))
HULL = material("Hull black", (.08, .09, .10), .6, .3)
HULL_RED = material("Antifouling red", (.48, .12, .08), .7, .2)
DECK = material("Deck green", (.20, .30, .22), .7, .2)
TIMBER = material("Timber", (.42, .31, .20))
TIMBER_DARK = material("Dark timber", (.24, .18, .13))
YELLOW = material("Safety yellow", (.82, .62, .10), .6, .2)
BLACK = material("Black paint", (.05, .05, .05), .6, .2)
MOSS = material("Moss", (.22, .30, .14))
WATER_LINE = material("Water stain", (.22, .24, .20))
GOLD = material("Gilding", (.70, .55, .20), .4, .6)


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


def beam(a, b, size, mat):
    delta = Vector(b) - Vector(a)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(Vector(a) + Vector(b)) / 2)
    obj = bpy.context.object
    obj.scale = (size, size, delta.length)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return attach(obj, "Beam", mat)


def limb(a, b, radius, mat, taper=1.0, sides=8):
    delta = Vector(b) - Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, radius2=radius * taper,
                                    depth=delta.length, location=(Vector(a) + Vector(b)) / 2)
    obj = bpy.context.object
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return attach(obj, "Member", mat)


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
    return attach(bpy.context.object, name, mat, flat=True)


def dome(name, point, radius, mat, sides=24, squash=1.0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=sides, ring_count=10, radius=radius, location=point)
    obj = bpy.context.object
    for vertex in obj.data.vertices:
        vertex.co.z = max(vertex.co.z, 0.0) * squash
    return attach(obj, name, mat)


def mesh_object(name, verts, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return attach(obj, name, mat, flat=True)


def gable_roof(name, point, width, depth, rise, mat, overhang=.3):
    """A pitched roof whose ridge runs along local X."""
    x, y, z = point
    w = width / 2 + overhang
    d = depth / 2 + overhang
    verts = [(x - d, y - w, z), (x + d, y - w, z), (x + d, y + w, z), (x - d, y + w, z),
             (x - d, y, z + rise), (x + d, y, z + rise)]
    faces = [(0, 1, 5, 4), (3, 4, 5, 2), (0, 4, 3), (1, 2, 5)]
    return mesh_object(name, verts, faces, mat)


def gable_roof_y(name, point, width, depth, rise, mat, overhang=.3):
    """A pitched roof whose ridge runs along local Y (front to back)."""
    x, y, z = point
    w = width / 2 + overhang
    d = depth / 2 + overhang
    verts = [(x - w, y - d, z), (x + w, y - d, z), (x + w, y + d, z), (x - w, y + d, z),
             (x, y - d, z + rise), (x, y + d, z + rise)]
    faces = [(0, 4, 5, 3), (1, 2, 5, 4), (0, 1, 4), (3, 5, 2)]
    return mesh_object(name, verts, faces, mat)


def hip_gable_front(name, point, width, height, mat, step=True):
    """A Dutch stepped or bell gable rising over a house front facing -Y."""
    x, y, z = point
    if step:
        for index, (w, h) in enumerate([(width, 1.2), (width * .72, 1.1), (width * .46, 1.0), (width * .22, .9)]):
            box(name, (x, y, z + sum([1.2, 1.1, 1.0, .9][:index]) + h / 2), (w, .5, h), mat)
    else:
        verts = [(x - width / 2, y, z), (x + width / 2, y, z), (x, y, z + height)]
        mesh_object(name, verts + [(v[0], v[1] + .5, v[2]) for v in verts],
                    [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], mat)


def windows(x0, x1, y, floors, z0, height, mat=GLASS, per=2, facing=-1):
    for floor in range(floors):
        z = z0 + floor * height + height * .55
        for index in range(per):
            x = x0 + (x1 - x0) * (index + .5) / per
            box("Window", (x, y + facing * .03, z), (.9, .06, height * .5), mat)


def truss_jib(a, b, depth, mat, panels=8, size=.14):
    a = Vector(a)
    b = Vector(b)
    for offset in [Vector((0, -depth / 2, 0)), Vector((0, depth / 2, 0)), Vector((0, 0, depth))]:
        beam(a + offset, b + offset, size, mat)
    for index in range(panels):
        p = a.lerp(b, index / panels)
        q = a.lerp(b, (index + 1) / panels)
        beam(p + Vector((0, -depth / 2, 0)), q + Vector((0, 0, depth)), size * .7, mat)
        beam(p + Vector((0, depth / 2, 0)), q + Vector((0, 0, depth)), size * .7, mat)


# ---------------------------------------------------------------- working harbour

def quay_crane(mat):
    """A level-luffing portal crane on quay rails (Hamburg style); the jib
    reaches over the water toward -Y."""
    for x in [-3.0, 3.0]:
        for y in [-3.0, 3.0]:
            beam((x, y, 0), (x * .6, y * .6, 8.0), .45, mat)
        box("Bogie", (x, 0, .45), (1.2, 7.4, .9), IRON)
    box("Portal deck", (0, 0, 8.3), (5.4, 5.4, .6), mat)
    cylinder("Slewing ring", (0, 0, 8.9), 2.2, .6, IRON, 20)
    box("Machine house", (.8, 0, 10.6), (5.0, 3.6, 3.2), mat)
    gable_roof("Machine house roof", (.8, 0, 12.2), 3.6, 5.0, .8, IRON, .15)
    box("Cab", (-2.4, -1.4, 10.2), (1.6, 1.8, 1.8), mat)
    box("Cab glass", (-3.22, -1.4, 10.4), (.04, 1.6, 1.0), GLASS)
    beam((-1.0, 0, 12.2), (-1.0, 0, 18.5), .5, mat)
    truss_jib((-1.0, 0, 18.5), (-1.0, -15.0, 13.0), 1.2, mat, 8, .16)
    beam((-1.0, 0, 18.5), (-1.0, 4.0, 15.0), .3, mat)
    box("Counterweight", (-1.0, 4.4, 14.6), (2.0, 1.4, 1.6), CONCRETE_DARK)
    limb((-1.0, -15.0, 13.0), (-1.0, -15.0, 6.0), .04, STEEL)
    box("Hook", (-1.0, -15.0, 5.8), (.6, .4, .6), YELLOW)


def quay_shed(seed):
    rng = random.Random(seed)
    box("Shed", (0, 0, 4.0), (40.0, 16.0, 8.0), BRICK)
    gable_roof("Shed roof", (0, 0, 8.0), 16.0, 40.0, 3.2, ROOF_SLATE, .5)
    for side in [-1, 1]:
        y = side * 8.03
        for index in range(6):
            x = -16.7 + index * 6.7
            box("Loading door", (x, y, 2.2), (3.4, .06, 4.4), rng.choice([TIMBER_DARK, CRANE_BLUE, IRON]))
            box("Upper window", (x, y, 6.2), (2.2, .06, 1.2), GLASS)
        box("Canopy", (0, side * 9.0, 4.8), (40.0, 2.2, .2), IRON)
    box("Name band", (0, -8.05, 7.2), (14.0, .06, .7), WHITE)
    for x in [-20.03, 20.03]:
        box("Gable door", (x, 0, 3.0), (.06, 6.0, 6.0), TIMBER_DARK)


def cargo_ship(length=44.0):
    """A moored coaster along local X, waterline at the origin."""
    half = length / 2
    verts = []
    for x, beam_half, keel in [(-half, 3.6, -3.2), (-half + 2, 4.6, -3.6), (half - 8, 4.6, -3.6), (half - 2, 2.6, -3.2), (half, 0.2, -2.4)]:
        verts.append((x, -beam_half, 2.2))
        verts.append((x, beam_half, 2.2))
        verts.append((x, -beam_half * .8, keel))
        verts.append((x, beam_half * .8, keel))
    faces = []
    for ring in range(4):
        a = ring * 4
        b = a + 4
        faces += [(a, b, b + 2, a + 2), (a + 1, a + 3, b + 3, b + 1), (a + 2, b + 2, b + 3, a + 3)]
    faces += [(0, 2, 3, 1), (16, 17, 19, 18)]
    mesh_object("Hull", verts, faces, HULL)
    box("Boot topping", (0, 0, -.2), (length * .9, 9.3, .8), HULL_RED)
    box("Main deck", (0, 0, 2.25), (length - 4, 8.6, .1), DECK)
    for index in range(3):
        box("Hatch", (-half + 14 + index * 9, 0, 2.8), (7.0, 6.2, 1.0), CRANE_RED if index % 2 else CRANE_BLUE)
    box("Bridge house", (-half + 5.5, 0, 5.4), (6.0, 7.8, 6.2), WHITE)
    box("Wheelhouse", (-half + 6.5, 0, 9.0), (3.6, 9.0, 1.6), WHITE)
    box("Bridge glass", (-half + 8.33, 0, 9.1), (.06, 8.6, .8), GLASS)
    cylinder("Funnel", (-half + 3.2, 0, 10.0), .9, 3.4, CRANE_RED, 12)
    box("Funnel band", (-half + 3.2, 0, 11.2), (1.85, 1.85, .5), BLACK)
    limb((half - 6, 0, 2.3), (half - 6, 0, 9.0), .18, STEEL)
    limb((half - 6, 0, 8.4), (half - 16, 0, 3.0), .12, STEEL)


def dry_dock_ship():
    """A cargo ship on keel blocks in an empty dry dock (dock floor at 0)."""
    for x in range(-18, 20, 4):
        box("Keel block", (x, 0, .6), (1.4, 2.4, 1.2), TIMBER_DARK)
    for x in [-14, -4, 6, 16]:
        for y in [-4.8, 4.8]:
            beam((x, y * 1.9, 0), (x, y, 6.0), .25, TIMBER)
    bpy.ops.object.select_all(action="DESELECT")
    start = len(collection.objects)
    cargo_ship(42.0)
    for obj in list(collection.objects)[start:]:
        obj.location.z += 4.8
    box("Staging tower", (8.0, -8.6, 6.0), (2.0, 2.0, 12.0), YELLOW)
    for z in [4.0, 8.0]:
        box("Staging deck", (0, -7.8, z), (30.0, 1.2, .15), STEEL)


def dock_gate():
    box("Caisson", (0, 0, 2.0), (3.0, 20.0, 8.0), RUST)
    box("Caisson deck", (0, 0, 6.1), (3.4, 20.4, .3), CONCRETE_DARK)
    for y in [-9.5, 9.5]:
        box("Gate pier", (0, y + (1.4 if y > 0 else -1.4), 2.4), (4.0, 2.4, 8.8), CONCRETE)
    for y in [-6, -2, 2, 6]:
        cylinder("Rail post", (1.6, y, 6.8), .06, 1.2, WHITE, 6)
    box("Handrail", (1.6, 0, 7.35), (.06, 16.0, .06), WHITE)


def lighthouse():
    cylinder("Plinth", (0, 0, .8), 3.4, 1.6, STONE_DARK, 16)
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=2.4, radius2=1.6, depth=16.0, location=(0, 0, 9.6))
    attach(bpy.context.object, "Tower", WHITE)
    for z in [5.0, 11.0]:
        r = 2.4 - (z - 1.6) / 16.0 * .8
        cylinder("Red band", (0, 0, z), r + .03, 2.2, CRANE_RED, 20)
    cylinder("Gallery", (0, 0, 17.7), 2.4, .3, IRON, 20)
    cylinder("Lantern", (0, 0, 18.8), 1.3, 2.0, GLASS, 12)
    cone("Lantern roof", (0, 0, 20.3), 1.5, 1.0, CRANE_RED, 12, .2)


def harbour_office():
    box("Office", (0, 0, 4.5), (14.0, 9.0, 9.0), BRICK_WARM)
    box("Stone base", (0, 0, 1.0), (14.2, 9.2, 2.0), STONE)
    gable_roof("Office roof", (0, 0, 9.0), 9.0, 14.0, 3.0, ROOF_SLATE, .3)
    windows(-6, 6, -4.5, 2, 2.0, 3.4, GLASS, 4)
    box("Clock tower", (4.5, 0, 11.0), (3.4, 3.4, 22.0), BRICK_WARM)
    cylinder("Clock face", (4.5, -1.75, 18.5), .9, .1, WHITE, 16, "y")
    cone("Tower spire", (4.5, 0, 23.6), 2.4, 3.2, COPPER, 4, 0)
    bpy.context.object.rotation_euler.z = math.pi / 4


def bollards():
    for index in range(5):
        x = -8 + index * 4
        cylinder("Bollard", (x, 0, .45), .3, .9, IRON, 10)
        cylinder("Bollard cap", (x, 0, .95), .38, .12, IRON, 10)
    for index in range(4):
        box("Fender", (-6 + index * 4, -.9, -.4), (1.2, .4, 1.6), BLACK)


def fishing_boat(seed):
    rng = random.Random(seed)
    colour = rng.choice([CRANE_BLUE, CRANE_RED, DECK])
    verts = [(-5, -1.6, .9), (-5, 1.6, .9), (4, -1.7, 1.1), (4, 1.7, 1.1), (6, 0, 1.5),
             (-4.6, -1.1, -.8), (-4.6, 1.1, -.8), (3.6, 0, -.9)]
    mesh_object("Hull", verts, [(0, 2, 3, 1), (2, 4, 3), (0, 5, 7, 2), (1, 3, 7, 6), (2, 7, 4), (3, 4, 7), (0, 1, 6, 5), (5, 6, 7)], colour)
    box("Wheelhouse", (-2.2, 0, 2.1), (2.2, 2.0, 2.0), WHITE)
    limb((1.0, 0, 1.0), (1.0, 0, 6.0), .08, TIMBER)
    limb((1.0, 0, 5.0), (4.5, 0, 2.0), .05, TIMBER)


# ---------------------------------------------------------------- canal city

def canal_row(seed, count=4):
    """A terrace of narrow canal houses along local X, fronts facing -Y,
    standing in water to their footing (water line at the origin)."""
    rng = random.Random(seed)
    width = 6.0
    for index in range(count):
        x = -width * count / 2 + width * (index + .5)
        floors = rng.choice([3, 4, 4, 5])
        height = floors * 3.2 + 1.0
        mat = rng.choice(PLASTER + [BRICK, BRICK_WARM])
        box("House", (x, 0, height / 2 - .6), (width - .15, 10.0, height + 1.2), mat)
        box("Water stain", (x, -5.03, -.1), (width - .1, .06, 1.2), WATER_LINE)
        windows(x - width / 2 + .4, x + width / 2 - .4, -5.0, floors, .6, 3.2, GLASS, 2)
        box("Door", (x, -5.04, 1.4), (1.2, .06, 2.4), TIMBER_DARK)
        if rng.random() < .55:
            hip_gable_front("Stepped gable", (x, -5.25, height - .6), width - .2, 3.0, mat, True)
            gable_roof_y("Roof", (x, .2, height - .6), width - .2, 9.6, 3.2, ROOF_TILE, .1)
        else:
            box("Cornice", (x, -5.15, height - .4), (width - .1, .4, .4), WHITE)
            mesh_object("Hip roof", [(x - width / 2 + .1, -5, height - .6), (x + width / 2 - .1, -5, height - .6),
                                     (x + width / 2 - .1, 5, height - .6), (x - width / 2 + .1, 5, height - .6),
                                     (x, -2.5, height + 2.4), (x, 2.5, height + 2.4)],
                        [(0, 1, 4), (1, 2, 5, 4), (2, 3, 5), (3, 0, 4, 5)], ROOF_TILE)
        if rng.random() < .4:
            box("Hoist beam", (x, -5.6, height - 1.4), (.25, 1.4, .25), TIMBER_DARK)
        if rng.random() < .5:
            box("Chimney", (x + 1.4, 2.0, height + 1.8), (.6, .6, 1.8), BRICK_DARK)


def exchange_hall():
    """The domed exchange: arcaded hall, corner tower, gilded lantern."""
    box("Hall", (0, 0, 6.0), (30.0, 20.0, 12.0), STONE)
    box("Plinth", (0, 0, .9), (30.6, 20.6, 1.8), STONE_DARK)
    for side in [-1, 1]:
        for index in range(9):
            x = -13 + index * 3.25
            box("Arch", (x, side * 10.03, 4.0), (2.0, .06, 5.0), GLASS)
            box("Pilaster", (x + 1.6, side * 10.05, 6.0), (.5, .1, 12.0), STONE_DARK)
    box("Cornice", (0, 0, 12.3), (31.0, 21.0, .6), STONE_DARK)
    cylinder("Drum", (0, 0, 14.0), 6.5, 3.4, STONE, 32)
    dome("Dome", (0, 0, 15.7), 6.5, COPPER, 32, .85)
    cylinder("Lantern", (0, 0, 21.8), 1.4, 1.6, STONE, 12)
    cone("Lantern cap", (0, 0, 23.2), 1.6, 1.4, GOLD, 12, .1)
    box("Tower", (12.0, -7.0, 13.0), (5.0, 5.0, 26.0), BRICK_WARM)
    cylinder("Tower clock", (12.0, -9.55, 22.0), 1.4, .1, WHITE, 20, "y")
    cone("Tower roof", (12.0, -7.0, 27.6), 3.8, 3.2, COPPER, 4, .4)
    bpy.context.object.rotation_euler.z = math.pi / 4
    for x in [-6, 0, 6]:
        box("Portico column", (x, -11.2, 4.5), (.9, .9, 7.2), STONE)
    box("Portico pediment", (0, -11.2, 8.6), (15.0, 2.0, 1.0), STONE_DARK)


def campanile():
    box("Shaft", (0, 0, 13.0), (5.0, 5.0, 26.0), BRICK_WARM)
    for z in [8.0, 16.0]:
        box("String course", (0, 0, z), (5.3, 5.3, .3), STONE)
    for side in range(4):
        angle = side * math.pi / 2
        x, y = math.cos(angle) * 2.52, math.sin(angle) * 2.52
        box("Belfry arch", (x, y, 24.0), (.1 if abs(x) > 1 else 1.6, 1.6 if abs(x) > 1 else .1, 3.0), BLACK)
    box("Belfry cornice", (0, 0, 26.3), (5.8, 5.8, .6), STONE)
    cone("Spire", (0, 0, 30.6), 3.4, 8.0, COPPER, 4, 0)
    bpy.context.object.rotation_euler.z = math.pi / 4
    cone("Finial", (0, 0, 35.0), .2, .9, GOLD, 8, 0)


def port_warehouse(seed):
    rng = random.Random(seed)
    box("Warehouse", (0, 0, 8.0), (24.0, 14.0, 16.0), BRICK)
    box("Water stain", (0, -7.03, .4), (24.0, .06, 1.6), WATER_LINE)
    for index in range(5):
        x = -9.6 + index * 4.8
        for floor in range(4):
            box("Shutter", (x, -7.04, 2.4 + floor * 3.6), (1.6, .06, 2.0), rng.choice([CRANE_BLUE, DECK, TIMBER_DARK]))
    for x in [-4.8, 4.8]:
        box("Hoist gable", (x, -7.6, 16.6), (2.4, 1.4, 2.4), BRICK_DARK)
        box("Hoist beam", (x, -8.6, 16.0), (.3, 1.4, .3), TIMBER_DARK)
    gable_roof("Warehouse roof", (0, 0, 16.0), 14.0, 24.0, 4.0, ROOF_SLATE, .3)


def arch_bridge():
    """A humped brick canal bridge along local X: 14 m span, crown 2.2 m."""
    verts = []
    faces = []
    steps = 10
    for index in range(steps + 1):
        t = index / steps
        x = -9.0 + t * 18.0
        rise = 2.2 * math.sin(math.pi * min(max((x + 7.0) / 14.0, 0.0), 1.0))
        for y in [-3.4, 3.4]:
            verts.append((x, y, rise))
            verts.append((x, y, rise - .7 if abs(x) < 7.0 else -.6))
    for index in range(steps):
        a = index * 4
        b = a + 4
        faces += [(a, b, b + 2, a + 2), (a + 1, a + 3, b + 3, b + 1), (a, a + 1, b + 1, b), (a + 2, b + 2, b + 3, a + 3)]
    mesh_object("Bridge deck", verts, faces, BRICK_WARM)
    for y in [-3.5, 3.5]:
        for index in range(steps):
            x0 = -9.0 + index * 1.8
            x1 = x0 + 1.8
            r0 = 2.2 * math.sin(math.pi * min(max((x0 + 7.0) / 14.0, 0.0), 1.0))
            r1 = 2.2 * math.sin(math.pi * min(max((x1 + 7.0) / 14.0, 0.0), 1.0))
            beam((x0, y, r0 + .5), (x1, y, r1 + .5), .3, STONE)


def mooring_poles(seed):
    rng = random.Random(seed)
    for index in range(5):
        x = -6 + index * 3 + rng.uniform(-.4, .4)
        cylinder("Pole", (x, rng.uniform(-.3, .3), .6), .16, 4.0, rng.choice([WHITE, CRANE_BLUE, CRANE_RED]), 8)
        cone("Pole cap", (x, 0, 2.8), .2, .5, GOLD, 8, 0)


def canal_boat(seed):
    rng = random.Random(seed)
    colour = rng.choice([TIMBER, CRANE_BLUE, DECK])
    verts = [(-4, -1.0, .5), (-4, 1.0, .5), (3.5, -1.0, .5), (3.5, 1.0, .5), (4.6, 0, .7),
             (-3.8, -.7, -.4), (-3.8, .7, -.4), (3.4, 0, -.4)]
    mesh_object("Boat", verts, [(0, 2, 3, 1), (2, 4, 3), (0, 5, 7, 2), (1, 3, 7, 6), (2, 7, 4), (3, 4, 7), (0, 1, 6, 5), (5, 6, 7)], colour)
    box("Canopy", (-1.0, 0, 1.0), (3.0, 1.8, .7), WHITE)


def submerged_facade(seed):
    """A gutted house front standing out of the flood, roofless."""
    rng = random.Random(seed)
    mat = rng.choice(PLASTER)
    box("Facade", (0, 0, 4.0), (8.0, .6, 9.0), mat)
    box("Side wall", (-3.7, 2.5, 3.0), (.6, 5.0, 7.0), mat)
    box("Side wall", (3.7, 1.5, 2.0), (.6, 3.0, 5.0), mat)
    for x in [-2.0, 2.0]:
        for z in [2.6, 5.8]:
            box("Empty window", (x, -.32, z), (1.2, .06, 1.8), BLACK)
    box("Water stain", (0, -.33, .5), (8.0, .06, 1.4), WATER_LINE)
    for index in range(4):
        box("Moss", (rng.uniform(-3, 3), -.34, rng.uniform(.6, 1.6)), (rng.uniform(.6, 1.4), .06, .4), MOSS)


def fountain():
    cylinder("Basin", (0, 0, .4), 3.2, .8, STONE, 24)
    cylinder("Water", (0, 0, .75), 2.9, .05, GLASS, 24)
    cylinder("Column", (0, 0, 1.8), .5, 2.4, STONE_DARK, 12)
    cylinder("Bowl", (0, 0, 3.0), 1.2, .3, STONE, 16)
    box("Statue", (0, 0, 3.9), (.6, .6, 1.6), COPPER)


builders = [
    ("QuayCraneRed", 16.5, 20.0, lambda: quay_crane(CRANE_RED)),
    ("QuayCraneBlue", 16.5, 20.0, lambda: quay_crane(CRANE_BLUE)),
    ("QuayShed", 22.6, 11.6, lambda: quay_shed(501)),
    ("CargoShip", 22.6, 12.0, lambda: cargo_ship(44.0)),
    ("DryDockShip", 22.4, 17.0, dry_dock_ship),
    ("DockGate", 12.6, 7.6, dock_gate),
    ("Lighthouse", 3.5, 21.0, lighthouse),
    ("HarbourOffice", 9.0, 25.4, harbour_office),
    ("Bollards", 8.5, 1.1, bollards),
    ("FishingBoat", 6.1, 6.1, lambda: fishing_boat(502)),
    ("CanalRowA", 13.5, 21.0, lambda: canal_row(503)),
    ("CanalRowB", 13.5, 21.0, lambda: canal_row(504)),
    ("CanalRowShort", 10.5, 21.0, lambda: canal_row(505, 3)),
    ("ExchangeHall", 19.0, 29.4, exchange_hall),
    ("Campanile", 4.2, 35.6, campanile),
    ("PortWarehouse", 14.5, 20.2, lambda: port_warehouse(506)),
    ("ArchBridge", 10.0, 3.1, arch_bridge),
    ("MooringPoles", 6.4, 3.1, lambda: mooring_poles(507)),
    ("CanalBoat", 4.8, 1.4, lambda: canal_boat(508)),
    ("SubmergedFacade", 6.6, 8.6, lambda: submerged_facade(509)),
    ("Fountain", 3.3, 4.8, fountain),
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
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/environment/HarbourKit.blend"))
(ROOT / "art/environment/harbour-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest))
