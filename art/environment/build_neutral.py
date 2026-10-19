"""Neutral capturable facilities kit. Blender Z-up, Godot Y-up.
OilRefinery: a compact field refinery that stays inside the 2.2 m navigation
footprint of its site (low pad edges reach 2.45 m). Faction-neutral weathered
palette; surfaces using the "Ownership band" material are recoloured in game
to the capturing player's colour. The nodding pump is animated in Godot
(RefineryMachinery.gd) and stands on the pad's open corner.
"""
import json
import math
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/environment/neutral"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
assets = []
collection = None


def material(name, color, metallic=0.0, roughness=0.85, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission:
        shader.inputs["Emission Color"].default_value = (*emission, 1)
        shader.inputs["Emission Strength"].default_value = 2.0
    return mat


CONCRETE = material("Refinery pad concrete", (.42, .40, .36))
CONCRETE_EDGE = material("Pad kerb", (.52, .50, .45))
STAIN = material("Oil stains", (.22, .21, .19), 0.0, .4)
TANK = material("Weathered tank paint", (.72, .71, .66), .15, .6)
TANK_SHADE = material("Tank roof", (.55, .55, .52), .2, .55)
RUST = material("Rust streaks", (.38, .16, .07), .2, .8)
STEEL = material("Galvanized pipe", (.36, .38, .37), .7, .45)
DARK = material("Dark steel", (.10, .11, .11), .6, .5)
RAIL = material("Safety yellow rail", (.78, .58, .10), .2, .5)
RED = material("Flare red", (.62, .10, .07), .1, .6)
WHITE = material("Flare white", (.86, .85, .82), .1, .6)
SHED = material("Control shed siding", (.30, .36, .33), .3, .7)
GLASS = material("Shed windows", (.12, .18, .22), .3, .15)
OWNER = material("Ownership band", (.82, .73, .63), .2, .5)
BEACON = material("Aviation beacon", (.9, .15, .1), 0, .4, (1.0, .1, .05))
FLAME = material("Flare flame", (1.0, .55, .12), 0, .5, (1.0, .45, .08))


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
        mod = obj.modifiers.new("Worn edges", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        obj.modifiers.new("Weighted face normals", "WEIGHTED_NORMAL")
    return obj


def box(name, point, size, mat, bevel=.02, angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.z = angle
    return attach(obj, name, mat, bevel)


def cylinder(name, point, radius, depth, mat, sides=20, bevel=0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth,
                                        location=point)
    obj = bpy.context.object
    bpy.ops.object.shade_smooth()
    return attach(obj, name, mat, bevel)


def dome(name, point, radius, height, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=8, radius=1, location=point)
    obj = bpy.context.object
    obj.scale = (radius, radius, height)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.shade_smooth()
    return attach(obj, name, mat)


def beam(name, a, b, radius=.035, mat=STEEL, sides=8):
    dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=length,
                                        location=((a[0] + b[0]) / 2, (a[1] + b[1]) / 2,
                                                  (a[2] + b[2]) / 2))
    obj = bpy.context.object
    obj.rotation_euler = (0, math.acos(max(-1, min(1, dz / length))), math.atan2(dy, dx))
    bpy.ops.object.shade_smooth()
    return attach(obj, name, mat)


def ring(name, point, radius, thickness, mat):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=thickness,
                                     major_segments=24, minor_segments=6, location=point)
    return attach(bpy.context.object, name, mat)


def railing(cx, cy, z, radius, posts=8):
    ring("Platform handrail", (cx, cy, z + .45), radius, .018, RAIL)
    ring("Platform midrail", (cx, cy, z + .23), radius, .012, RAIL)
    for index in range(posts):
        a = index * math.tau / posts
        x, y = cx + math.cos(a) * radius, cy + math.sin(a) * radius
        beam("Handrail post", (x, y, z), (x, y, z + .45), .016, RAIL, 6)


def ladder(x, y, bottom, top, facing):
    side = (-math.sin(facing) * .17, math.cos(facing) * .17)
    for sx, sy in [side, (-side[0], -side[1])]:
        beam("Ladder stile", (x + sx, y + sy, bottom), (x + sx, y + sy, top), .015, RAIL, 6)
    rung = bottom + .2
    while rung < top:
        beam("Ladder rung", (x + side[0], y + side[1], rung),
             (x - side[0], y - side[1], rung), .01, RAIL, 6)
        rung += .3


def storage_tank(name, cx, cy, radius, height):
    cylinder(name + " shell", (cx, cy, .12 + height / 2), radius, height, TANK, 28, .02)
    dome(name + " roof", (cx, cy, .12 + height), radius * 1.01, .22, TANK_SHADE)
    # The capturing faction's colour wraps each tank as a painted band.
    cylinder(name + " ownership band", (cx, cy, .12 + height * .62), radius + .012, .2,
             OWNER, 28)
    for index, length in enumerate([.55, .35, .45]):
        a = index * 2.2 + cx
        x, y = cx + math.cos(a) * (radius + .003), cy + math.sin(a) * (radius + .003)
        box("Rust streak", (x, y, .12 + height * (1 - length / 2) - .1),
            (.03, .03, height * length), RUST, 0, a)
    ring("Tank base ring", (cx, cy, .16), radius + .02, .035, DARK)
    ladder(cx + radius + .05, cy, .12, .12 + height, 0)


begin("OilRefinery", 2.45, 4.6)
# Pad, kerb and wear.
box("Refinery pad", (0, 0, .06), (4.5, 4.5, .12), CONCRETE, .04)
for x, y, sx, sy in [(0, 2.25, 4.6, .14), (0, -2.25, 4.6, .14), (2.25, 0, .14, 4.6),
                     (-2.25, 0, .14, 4.6)]:
    box("Pad kerb", (x, y, .1), (sx, sy, .12), CONCRETE_EDGE, .03)
for x, y, s, a in [(.25, -.35, .45, .4), (-1.25, -1.15, .3, 1.2), (.95, -1.45, .25, .2)]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=1, depth=.004,
                                        location=(x, y, .122))
    stain = bpy.context.object
    stain.scale = (s, s * .65, 1)
    stain.rotation_euler.z = a
    attach(stain, "Oil stain", STAIN)

# Distillation column with platforms, ladder and aviation beacon.
column = (-.95, .85)
cylinder("Distillation column", (*column, 2.25), .38, 4.3, TANK, 24, .02)
cylinder("Column skirt", (*column, .35), .46, .5, DARK, 24)
for z in [1.55, 2.85]:
    cylinder("Column platform", (*column, z), .66, .05, STEEL, 24)
    railing(*column, z + .03, .64)
cylinder("Column cap", (*column, 4.43), .3, .08, TANK_SHADE, 24)
cylinder("Aviation beacon", (*column, 4.53), .07, .12, BEACON, 10)
ladder(column[0] + .44, column[1], .12, 4.2, 0)
for z in [.9, 2.2, 3.5]:
    cylinder("Column ownership band" if z == 2.2 else "Column weld band", (*column, z),
             .392, .14 if z == 2.2 else .04, OWNER if z == 2.2 else DARK, 24)

# Storage tanks.
storage_tank("East storage tank", 1.15, .95, .78, 1.45)
storage_tank("South storage tank", 1.35, -.9, .55, 1.05)

# Fired heater beside the column.
box("Fired heater", (-1.45, -.55, .7), (.8, .62, 1.15), SHED, .03)
cylinder("Heater stack", (-1.45, -.55, 1.75), .1, 1.0, DARK, 12)
box("Heater burner hatch", (-1.05, -.55, .45), (.02, .3, .3), DARK, .005)

# Pipe rack linking column, heater and tanks.
for x in [-.3, .45]:
    for y in [-.15, .25]:
        beam("Pipe rack upright", (x, y, .12), (x, y, 1.9), .03, DARK, 6)
    beam("Pipe rack crossbeam", (x, -.2, 1.85), (x, .3, 1.85), .03, DARK, 6)
for offset, radius, mat in [(-.08, .06, STEEL), (.1, .045, RUST), (.24, .04, STEEL)]:
    beam("Process pipe", (column[0] + .3, offset + .05, 1.9 + offset * .3),
         (.75, offset + .05, 1.9 + offset * .3), radius, mat, 10)
beam("Tank feed line", (.75, .1, 1.95), (1.05, .5, 1.5), .05, STEEL, 10)
beam("Tank feed line", (.75, -.05, 1.8), (1.25, -.55, 1.15), .045, STEEL, 10)
beam("Heater feed", (-1.45, -.25, 1.0), (column[0], column[1] - .4, 1.0), .05, STEEL, 10)
# Ground manifold with gate valves; hand wheels sit level on their bonnets.
beam("Ground manifold", (-1.0, -.95, .3), (.95, -.95, .3), .06, STEEL, 10)
for x in [-.35, .35]:
    box("Gate valve body", (x, -.95, .3), (.16, .2, .2), DARK, .01)
    beam("Valve bonnet", (x, -.95, .4), (x, -.95, .62), .025, STEEL, 6)
    ring("Valve hand wheel", (x, -.95, .63), .1, .014, RED)

# Flare stack in the open corner, striped and lit.
flare = (1.5, -1.6)
for index in range(8):
    z0 = .12 + index * .5
    cylinder("Flare stack band", (*flare, z0 + .25), .1, .5, RED if index % 2 else WHITE, 12)
cylinder("Flare tip", (*flare, 4.2), .14, .12, DARK, 12)
bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=.12, radius2=0, depth=.32,
                                location=(*flare, 4.42))
attach(bpy.context.object, "Flare flame", FLAME)
for a in [.4, 2.5, 4.6]:
    beam("Flare guy wire", (flare[0] + math.cos(a) * .45, flare[1] + math.sin(a) * .45, .12),
         (*flare, 3.0), .008, STEEL, 4)

# Control shed and small yard clutter.
box("Control shed", (.05, -1.65, .55), (1.1, .78, .86), SHED, .03)
box("Shed roof", (.05, -1.65, 1.02), (1.22, .9, .07), DARK, .02)
box("Shed window", (.05, -2.045, .65), (.55, .02, .28), GLASS, .005)
box("Shed door", (.52, -1.65, .45), (.02, .38, .66), DARK, .005)
for x, y in [(-1.65, 1.6), (-1.35, 1.78), (-1.85, 1.3)]:
    cylinder("Oil drum", (x, y, .37), .14, .44, RUST if x < -1.6 else TANK_SHADE, 12)

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
    assert radius <= radius_limit * 1.42 and height <= height_limit, (name, radius, height)
    manifest[name] = {"radius": round(radius, 4), "height": round(height, 4),
                      "radius_limit": radius_limit, "height_limit": height_limit}
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + ".glb")), export_format="GLB",
                              use_selection=True, export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/environment/NeutralKit.blend"))
(ROOT / "art/environment/neutral-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest))
