"""Build the Bastion tank in Blender background mode.

Run from any directory:
  blender --background --factory-startup --python-exit-code 1 --python /path/to/build.py

Outputs are scoped to this asset's versioned source directory and
assets/models/bastion/tank-v1. The editable .blend retains individual components;
the GLB joins rigid parts. Append -- --export-only to skip studio renders.
"""

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "art/common"))
import modeling
import track_rig

EXPORT = ROOT / "assets/models/bastion/tank-v1"
EXPORT.mkdir(parents=True, exist_ok=True)
RENDERS = HERE / "renders"
RENDERS.mkdir(exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    if not collection.objects:
        bpy.data.collections.remove(collection)

scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
source = bpy.data.collections.new("SOURCE — editable components")
scene.collection.children.link(source)
studio = bpy.data.collections.new("STUDIO — excluded from export")
scene.collection.children.link(studio)
parts = {
    "Hull": [],
    "Turret": [],
    "Barrel": [],
    "TrackLeft": [],
    "TrackRight": [],
    "AntennaLeft": [],
    "AntennaRight": [],
}


def material(name, color, metallic=0.25, roughness=0.48, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission:
        shader.inputs["Emission Color"].default_value = (*color, 1)
        shader.inputs["Emission Strength"].default_value = emission
    return mat


armor = material("Armor / olive graphite", (0.065, 0.076, 0.064))
edge = material("Armor / raised panels", (0.105, 0.12, 0.098))
dark = material("Mechanisms / dark steel", (0.025, 0.033, 0.034), 0.65, 0.38)
steel = material("Hardware / brushed steel", (0.285, 0.32, 0.32), 0.8, 0.35)
rubber = material("Tracks / rubber", (0.025, 0.032, 0.032), 0.0, 0.8)
yellow = material("TeamColor / Bastion ochre", (0.65, 0.28, 0.015), 0.2, 0.43)
ivory = material("Markings / ivory", (0.8, 0.79, 0.66), 0.05, 0.62)
glass = material("Optics / ice cyan", (0.12, 0.69, 0.83), 0.35, 0.22, 0.6)
lamp = material("Lamps / warm white", (0.94, 0.85, 0.57), 0.1, 0.22, 1.0)
red = material("Lamps / rear red", (0.58, 0.045, 0.025), 0.05, 0.35, 0.3)


def move_collection(obj, collection):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)


def finish(obj, name, mat, group="Hull", bevel=0.0, smooth=True, sharp_angle=35.0):
    col = source if group else studio
    obj.name = name
    move_collection(obj, col)
    if mat and mat.name not in [m.name for m in obj.data.materials if m]:
        obj.data.materials.append(mat)
    if smooth:
        modeling.apply_smoothing(obj, sharp_angle)
    bevel = bevel if bevel >= 0.02 else 0.0
    if bevel:
        modifier = obj.modifiers.new("Manufactured edge chamfer", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2 if bevel >= 0.04 else 1
        modifier.limit_method = "ANGLE"
        modifier.angle_limit = math.radians(30.0)
        modifier.affect = "EDGES"
    if bevel or smooth:
        normal = obj.modifiers.new("Weighted surface normals", "WEIGHTED_NORMAL")
        normal.keep_sharp = True
        normal.weight = 60
    if group:
        parts[group].append(obj)
    return obj


def box(name, loc, dims, mat, group="Hull", bevel=0.035, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.scale = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        obj.rotation_euler = rotation
    return finish(obj, name, mat, group, bevel)


def mesh(name, verts, faces, mat, group="Hull", bevel=0.0, smooth=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    source.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    return finish(obj, name, mat, group, bevel, smooth)


def cylinder(name, loc, radius, depth, mat, group="Hull", axis="Z", vertices=20, bevel=0.0):
    vertices = max(vertices, 20 if radius >= 0.25 else 14)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    if axis == "X":
        obj.rotation_euler[1] = math.pi / 2
    elif axis == "Y":
        obj.rotation_euler[0] = math.pi / 2
    return finish(obj, name, mat, group, bevel, smooth=True, sharp_angle=35.0)


def footprint(width, length, cut=0.22, cy=0.0, steps=2):
    return [(x, y) for x, y, _ in modeling.rounded_rect_ring(width, length, cut, 0.0, cy, 0.0, steps)]


def layered(name, rings, mat, group="Hull", bevel=0.025):
    verts = [(x, y, z) for z, points in rings for x, y in points]
    n = len(rings[0][1])
    faces = [tuple(reversed(range(n)))]
    for layer in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            faces.append((layer * n + i, layer * n + j, (layer + 1) * n + j, (layer + 1) * n + i))
    faces.append(tuple(range((len(rings) - 1) * n, len(rings) * n)))
    return mesh(name, verts, faces, mat, group, bevel, smooth=True)


def rod(name, start, end, radius, mat, group="Hull", vertices=12):
    delta = Vector(end) - Vector(start)
    obj = cylinder(name, (Vector(start) + Vector(end)) / 2, radius, delta.length, mat, group, vertices=vertices, bevel=0)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return obj


def chevron_side(name, x, y, z, scale=0.5, mat=yellow, group="Hull"):
    yz = [(-.55, .35), (0, -.07), (.55, .35), (.55, .08), (0, -.35), (-.55, .08)]
    return mesh(name, [(x, y + a * scale, z + b * scale) for a, b in yz], [(0, 1, 2, 3, 4, 5)], mat, group, smooth=False)


def track_belt(side):
    x = side * 1.66
    group = "TrackLeft" if side < 0 else "TrackRight"
    steps = 28
    half, radius, height = 2.02, 0.64, 0.73
    perimeter = 4 * half + 2 * math.pi * radius
    verts = []
    for radial in (0.64, 0.51):
        p = 4 * half + 2 * math.pi * radial
        for xx in (x - 0.43, x + 0.43):
            for i in range(steps):
                y, z, _ = track_rig.capsule(p * i / steps, half, radial, height)
                verts.append((xx, y, z))
    faces = []
    for a, b in ((0, 1), (1, 3), (3, 2), (2, 0)):
        for i in range(steps):
            j = (i + 1) % steps
            faces.append((a * steps + i, a * steps + j, b * steps + j, b * steps + i))
    mesh(f"Track {side} / continuous belt", verts, faces, rubber, smooth=True)

    count = 24
    for i in range(count):
        y, z, angle = track_rig.capsule(perimeter * i / count, half, radius, height)
        shoe = box(f"Track {side} / shoe {i:02}", (x, y, z), (0.90, 0.30, 0.10), dark, group=group, bevel=0, rotation=(angle, 0, 0))
        track_rig.encode(shoe, perimeter * i / count, half, radius, height)

    wheel_specs = [(-2.02, 0.45, True), (-1.01, 0.48, False), (0.0, 0.48, False), (1.01, 0.48, False), (2.02, 0.45, True)]
    for i, (y, r, is_sprocket) in enumerate(wheel_specs):
        rim_col = steel if is_sprocket else edge
        s = 1.0 if side > 0 else -1.0
        prof_tire = [
            (r * 0.58, -0.37), (r * 0.88, -0.40), (r, -0.32),
            (r, 0.32), (r * 0.88, 0.40), (r * 0.58, 0.37),
        ]
        obj_t = modeling.lathe_profile(f"Track {side} / wheel tire {i}", prof_tire, (x, y, height), (1, 0, 0), 20, source, rubber, None)
        finish(obj_t, obj_t.name, rubber, group="Hull", smooth=True)
        prof_rim = [
            (0.0, s * 0.25), (r * 0.38, s * 0.28), (r * 0.52, s * 0.39),
            (r * 0.62, s * 0.41), (r * 0.62, -s * 0.36), (0.0, -s * 0.36),
        ]
        obj_r = modeling.lathe_profile(f"Track {side} / wheel rim {i}", prof_rim, (x, y, height), (1, 0, 0), 20, source, rim_col, None)
        finish(obj_r, obj_r.name, rim_col, group="Hull", smooth=True)
        cylinder(f"Track {side} / hub cap {i}", (x + s * 0.40, y, height), r * 0.22, 0.08, dark, "Hull", axis="X", vertices=12)


# Contoured armored hull with sloped glacis beak, driver deck, and recessed grille
layered("Hull / lower armored tub", [
    (0.34, footprint(2.48, 4.65, 0.34)),
    (0.84, footprint(2.98, 5.20, 0.32)),
    (1.12, footprint(3.18, 5.52, 0.28)),
], armor, bevel=0.04)

layered("Hull / sloped upper glacis", [
    (1.04, footprint(3.42, 5.50, 0.24)),
    (1.36, footprint(3.28, 5.05, 0.26, cy=-0.10)),
    (1.51, footprint(3.06, 4.55, 0.28, cy=-0.20)),
], edge, bevel=0.03)

layered("Hull / inset roof deck", [
    (1.49, footprint(2.94, 4.24, 0.26, cy=-0.25)),
    (1.55, footprint(2.82, 4.10, 0.22, cy=-0.25)),
], armor, bevel=0.02)

box("Hull / front nose wedge", (0, 2.66, 0.92), (2.26, 0.42, 0.38), armor, bevel=0.05, rotation=(math.radians(26), 0, 0))
box("Hull / rear engine deck", (0, -2.55, 1.18), (2.35, 0.45, 0.56), armor, bevel=0.04, rotation=(math.radians(-18), 0, 0))

for side in (-1, 1):
    track_belt(side)
    layered(f"Fender {side}", [
        (1.30, [(side * 1.24, -2.74), (side * 2.16, -2.74), (side * 2.16, 2.72), (side * 1.24, 2.72)]),
        (1.48, [(side * 1.24, -2.62), (side * 2.14, -2.62), (side * 2.14, 2.58), (side * 1.24, 2.58)]),
    ], armor, bevel=0.04)

    for i, y in enumerate((-1.85, -0.94, -0.03, 0.88, 1.79)):
        mat_p = yellow if i == 3 else armor
        layered(f"Skirt {side} / panel {i}", [
            (0.68, [(side * 2.00, y - 0.42), (side * 2.15, y - 0.42), (side * 2.15, y + 0.42), (side * 2.00, y + 0.42)]),
            (1.35, [(side * 2.00, y - 0.40), (side * 2.18, y - 0.40), (side * 2.18, y + 0.40), (side * 2.00, y + 0.40)]),
        ], mat_p, bevel=0.035)
        if i == 1:
            chevron_side(f"Skirt {side} / insignia", side * 2.195, y, 1.02, 0.54, ivory)

    box(f"Front fender {side} / bumper", (side * 1.70, 2.66, 1.24), (0.90, 0.24, 0.26), dark, bevel=0.04)
    box(f"Front fender {side} / team panel", (side * 1.71, 2.12, 1.50), (0.74, 0.68, 0.03), yellow, bevel=0.02)

    modeling.recessed_viewport(f"Headlamp {side}", (side * 1.68, 2.76, 1.32), 0.24, 0.11, 0.18, (0, 1, 0), source, dark, lamp, None)
    for obj in list(source.objects):
        if obj.name.startswith(f"Headlamp {side}") and obj not in parts["Hull"]:
            parts["Hull"].append(obj)

    # Rear exhaust louvers & taillights on the sloped rear deck
    for j in range(4):
        box(f"Exhaust {side} / louver {j}", (side * 0.98, -2.58, 1.18 + j * 0.065), (0.62, 0.14, 0.03), dark, bevel=0.01, rotation=(math.radians(20), 0, 0))
    box(f"Exhaust {side} / surround", (side * 0.98, -2.52, 1.28), (0.72, 0.16, 0.28), steel, bevel=0.02)
    box(f"Taillight {side}", (side * 1.72, -2.76, 1.38), (0.20, 0.04, 0.08), red, bevel=0.01)

    for offset in (-0.11, 0.11):
        box(f"Tow lug {side} {offset}", (side * 0.8 + offset, 2.52, 0.72), (0.07, 0.26, 0.10), steel, bevel=0.02)
    rod(f"Tow crossbar {side}", (side * 0.8 - 0.11, 2.63, 0.72), (side * 0.8 + 0.11, 2.63, 0.72), 0.042, steel)

    modeling.louver_grille(f"Engine grille {side}", (side * 0.77, -1.64, 1.545), 0.94, 1.12, 5, source, dark, steel, None)
    for obj in list(source.objects):
        if obj.name.startswith(f"Engine grille {side}") and obj not in parts["Hull"]:
            parts["Hull"].append(obj)
    box(f"Engine hatch {side}", (side * 1.48, -1.66, 1.54), (0.34, 1.12, 0.08), edge, bevel=0.025)

    box(f"Glacis {side} / inset composite panel", (side * 0.67, 2.24, 1.40), (0.84, 0.70, 0.05), armor, bevel=0.025, rotation=(math.radians(-28), 0, 0))
    rail = modeling.sweep_tube(f"Rear handrail {side}", [
        (side * 1.40, -2.22, 1.56), (side * 1.40, -2.22, 1.69),
        (side * 1.40, -1.84, 1.69), (side * 1.40, -1.84, 1.56),
    ], 0.022, 10, source, steel, None)
    finish(rail, rail.name, steel, "Hull", smooth=True)

box("Driver / hatch", (0, 1.60, 1.56), (0.84, 0.62, 0.08), armor, bevel=0.05)
modeling.recessed_viewport("Driver / periscope", (0, 1.92, 1.65), 0.38, 0.09, 0.16, (0, 1, 0), source, dark, glass, None)
for obj in list(source.objects):
    if obj.name.startswith("Driver / periscope") and obj not in parts["Hull"]:
        parts["Hull"].append(obj)

TURRET_PIVOT = Vector((0, 0.10, 1.61))
BARREL_PIVOT = Vector((0, 1.11, 2.04))
MUZZLE = Vector((0, 5.06, 2.04))

cylinder("Turret / bearing ring", (0, 0.10, 1.57), 1.12, 0.18, dark, "Turret", vertices=32)
cylinder("Turret / bearing lip", (0, 0.10, 1.67), 1.17, 0.07, steel, "Turret", vertices=32)

layered("Turret / main casting", [
    (1.66, footprint(2.68, 2.95, 0.56, cy=-0.04, steps=2)),
    (1.94, footprint(2.86, 3.04, 0.58, cy=-0.08, steps=2)),
    (2.20, footprint(2.50, 2.60, 0.52, cy=-0.12, steps=2)),
    (2.33, footprint(2.04, 2.12, 0.42, cy=-0.16, steps=2)),
], armor, "Turret", bevel=0.03)

for side in (-1, 1):
    lower = [(side * 0.46, 1.32), (side * 1.04, 1.06), (side * 1.48, 0.57), (side * 1.40, -0.12), (side * 1.22, -0.38), (side * 0.92, 0.20)]
    mid = [(x * 1.02, y + 0.02) for x, y in lower]
    upper = [(x * 0.90, y - 0.05) for x, y in lower]
    layered(f"Turret {side} / composite cheek", [(1.76, lower), (1.98, mid), (2.22, upper)], edge, "Turret", bevel=0.025)
    box(f"Turret {side} / side module", (side * 1.33, -0.52, 2.01), (0.24, 0.80, 0.38), armor, "Turret", bevel=0.04)
    chevron_side(f"Turret {side} / faction mark", side * 1.465, -0.52, 2.03, 0.44, yellow, "Turret")
    box(f"Turret {side} / rear stowage", (side * 0.84, -1.36, 2.00), (0.78, 0.50, 0.42), edge, "Turret", bevel=0.045)
    box(f"Turret {side} / stowage latch", (side * 0.84, -1.62, 2.02), (0.16, 0.03, 0.16), steel, "Turret", bevel=0.01)
    for j in range(2):
        obj = cylinder(f"Turret {side} / smoke tube {j}", (side * 1.34, 0.08 - j * 0.17, 2.24), 0.065, 0.28, dark, "Turret", vertices=12)
        obj.rotation_euler = (0, side * math.radians(34), 0)
    cylinder(f"Antenna {side} / mount", (side * 0.92, -0.98, 2.31), 0.08, 0.13, dark, "Turret", vertices=12)
    rod(f"Antenna {side} / mast", (side * 0.92, -0.98, 2.36), (side * 0.92, -1.025, 3.21 if side == 1 else 2.93), 0.014, dark, "AntennaLeft" if side < 0 else "AntennaRight", 8)

cylinder("Commander / cupola", (-0.51, -0.33, 2.36), 0.40, 0.15, dark, "Turret", vertices=24)
cylinder("Commander / hatch", (-0.51, -0.33, 2.45), 0.34, 0.055, edge, "Turret", vertices=24)
handle = modeling.sweep_tube("Commander / grab handle", [
    (-0.61, -0.35, 2.48), (-0.61, -0.35, 2.52), (-0.41, -0.35, 2.52), (-0.41, -0.35, 2.48),
], 0.016, 8, source, steel, None)
finish(handle, handle.name, steel, "Turret", smooth=True)

box("Optics / rotating plinth", (0.49, -0.02, 2.37), (0.50, 0.48, 0.12), dark, "Turret", bevel=0.035)
box("Optics / armored head", (0.49, 0.01, 2.59), (0.58, 0.44, 0.34), edge, "Turret", bevel=0.045)
for x, r in ((0.34, 0.085), (0.64, 0.062)):
    cylinder(f"Optics / bezel {x}", (x, 0.245, 2.60), r + 0.032, 0.06, dark, "Turret", axis="Y", vertices=18)
    cylinder(f"Optics / lens {x}", (x, 0.28, 2.60), r, 0.015, glass, "Turret", axis="Y", vertices=18)
box("Turret / retrofit interface", (0.65, -0.78, 2.33), (0.40, 0.37, 0.07), dark, "Turret", bevel=0.025)
box("Turret / removable chip cover", (0.65, -0.78, 2.375), (0.29, 0.28, 0.03), yellow, "Turret", bevel=0.02)
box("Turret / chip status", (0.65, -0.81, 2.395), (0.16, 0.03, 0.01), glass, "Turret", bevel=0.0)

box("Gun / mantlet", (0, 1.19, 2.04), (0.90, 0.58, 0.58), dark, "Barrel", bevel=0.08)
for side in (-1, 1):
    cylinder(f"Gun / trunnion {side}", (side * 0.48, 1.11, 2.04), 0.23, 0.08, steel, "Barrel", axis="X", vertices=20)
    cylinder(f"Gun / cap {side}", (side * 0.53, 1.11, 2.04), 0.17, 0.05, armor, "Barrel", axis="X", vertices=20)
box("Gun / recoil shroud", (0, 1.75, 2.04), (0.48, 0.92, 0.43), edge, "Barrel", bevel=0.06)
box("Gun / team band", (0, 2.00, 2.04), (0.50, 0.22, 0.445), yellow, "Barrel", bevel=0.04)

barrel_prof = [
    (0.155, 2.10), (0.155, 2.32), (0.135, 2.36), (0.135, 2.95),
    (0.175, 3.04), (0.175, 3.45), (0.132, 3.54), (0.132, 3.98),
    (0.160, 4.02), (0.160, 4.14), (0.125, 4.17), (0.125, 4.35),
]
b_obj = modeling.lathe_profile("Gun / lathed barrel", barrel_prof, (0, 0, 2.04), (0, 1, 0), 24, source, dark, None, smooth=True, sharp_angle=35.0)
finish(b_obj, b_obj.name, dark, "Barrel", smooth=True)
box("Gun / upper barrel spine", (0, 3.16, 2.18), (0.13, 1.88, 0.05), armor, "Barrel", bevel=0.015)

outer = [(-.17, -.22), (.17, -.22), (.26, -.13), (.26, .13), (.17, .22), (-.17, .22), (-.26, .13), (-.26, -.13)]
inner = [(x * 0.54, z * 0.54) for x, z in outer]
verts = []
for y, ring in ((4.29, outer), (5.04, outer), (5.045, inner), (4.63, inner)):
    verts += [(x, y, z + 2.04) for x, z in ring]
faces = []
for a, b in ((0, 1), (1, 2), (2, 3)):
    for i in range(8):
        j = (i + 1) % 8
        faces.append((a * 8 + i, a * 8 + j, b * 8 + j, b * 8 + i))
faces += [tuple(range(24, 32)), tuple(reversed(range(8)))]
mesh("Gun / hollow muzzle brake", verts, faces, armor, "Barrel", bevel=0.015, smooth=True)
for side in (-1, 1):
    for j in range(3):
        box(f"Gun / brake port {side} {j}", (side * 0.265, 4.45 + j * 0.17, 2.04), (0.012, 0.09, 0.14), dark, "Barrel", bevel=0)
box("Gun / muzzle team plate", (0, 4.78, 2.268), (0.29, 0.27, 0.02), yellow, "Barrel", bevel=0.01)


def empty(name, loc, collection):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.location = loc
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.25
    return obj


def parent_keep_world(obj, parent):
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world


bpy.context.view_layer.update()
root = empty("BastionTank", (0, 0, 0), source)
root["asset_version"] = "2.0-refit"
root["forward_blender"] = "+Y"
root["forward_godot"] = "-Z"
root["unit"] = "meter"
root["reference"] = "docs/concept-art/bastion/v1/02-ground-unit-designs-v1.png"
turret = empty("TurretPivot", TURRET_PIVOT, source)
barrel = empty("BarrelPivot", BARREL_PIVOT, source)
muzzle = empty("Muzzle", MUZZLE, source)
bpy.context.view_layer.update()
parent_keep_world(turret, root)
parent_keep_world(barrel, turret)
parent_keep_world(muzzle, barrel)
source_groups = [("Hull", root), ("Turret", turret), ("Barrel", barrel)]
for side, label in [(-1, "Left"), (1, "Right")]:
    track = empty("SourceTrackPivot" + label, (0, 0, 0), source)
    parent_keep_world(track, root)
    source_groups.append(("Track" + label, track))
    antenna = empty("SourceAntennaPivot" + label, (side * 0.92, -0.98, 2.36), source)
    parent_keep_world(antenna, turret)
    source_groups.append(("Antenna" + label, antenna))
for group, parent in source_groups:
    for obj in parts[group]:
        parent_keep_world(obj, parent)

export_collection = bpy.data.collections.new("EXPORT — consolidated rigid meshes")
scene.collection.children.link(export_collection)
eroot = empty("BastionTankExport", (0, 0, 0), export_collection)
for key in root.keys():
    eroot[key] = root[key]
et = empty("TurretPivotExport", TURRET_PIVOT, export_collection)
eb = empty("BarrelPivotExport", BARREL_PIVOT, export_collection)
em = empty("MuzzleExport", MUZZLE, export_collection)
bpy.context.view_layer.update()
parent_keep_world(et, eroot)
parent_keep_world(eb, et)
parent_keep_world(em, eb)
depsgraph = bpy.context.evaluated_depsgraph_get()
stats = {}
export_groups = [("Hull", eroot), ("Turret", et), ("Barrel", eb)]
for side, label in [(-1, "Left"), (1, "Right")]:
    track = empty("TrackPivot" + label, (0, 0, 0), export_collection)
    parent_keep_world(track, eroot)
    export_groups.append(("Track" + label, track))
    antenna = empty("AntennaPivot" + label, (side * 0.92, -0.98, 2.36), export_collection)
    parent_keep_world(antenna, et)
    export_groups.append(("Antenna" + label, antenna))
for group, pivot in export_groups:
    duplicates = []
    for obj in parts[group]:
        data = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), depsgraph=depsgraph)
        duplicate = bpy.data.objects.new("export-part", data)
        export_collection.objects.link(duplicate)
        duplicate.matrix_world = obj.matrix_world.copy()
        duplicates.append(duplicate)
    if len(duplicates) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in duplicates:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = duplicates[0]
        bpy.ops.object.join()
        joined = bpy.context.object
    else:
        joined = duplicates[0]
    joined.name = group + "Mesh"
    world = joined.matrix_world.copy()
    joined.data.transform(world)
    joined.matrix_world = Matrix.Identity(4)
    joined.data.transform(Matrix.Translation(-pivot.matrix_world.translation))
    joined.matrix_world = Matrix.Translation(pivot.matrix_world.translation)
    parent_keep_world(joined, pivot)
    triangulate = joined.modifiers.new("Stable game triangulation", "TRIANGULATE")
    bpy.context.view_layer.objects.active = joined
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    bm = bmesh.new()
    bm.from_mesh(joined.data)
    degenerate = [face for face in bm.faces if face.calc_area() <= 1e-10]
    if degenerate:
        bmesh.ops.delete(bm, geom=degenerate, context="FACES_ONLY")
        bm.to_mesh(joined.data)
    bm.free()
    joined.data.update()
    stats[group] = {"triangles": len(joined.data.polygons), "vertices": len(joined.data.vertices), "materials": len(joined.data.materials)}

renames = {root: "Source_BastionTank", turret: "Source_TurretPivot", barrel: "Source_BarrelPivot", muzzle: "Source_Muzzle"}
for obj, name in renames.items():
    obj.name = name
for obj, name in ((eroot, "BastionTank"), (et, "TurretPivot"), (eb, "BarrelPivot"), (em, "Muzzle")):
    obj.name = name
bpy.ops.object.select_all(action="DESELECT")
for obj in export_collection.objects:
    obj.select_set(True)
glb = EXPORT / "bastion_tank_v1.glb"
bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True,
                          export_yup=True, export_extras=True, export_animations=False,
                          export_cameras=False, export_lights=False, export_apply=True)

if "--export-only" in sys.argv:
    points = [obj.matrix_world @ Vector(point) for obj in export_collection.objects if obj.type == "MESH" for point in obj.bound_box]
    low = [min(point[i] for point in points) for i in range(3)]
    high = [max(point[i] for point in points) for i in range(3)]
    report = {"asset": "Bastion tank v2", "blender": bpy.app.version_string,
              "source_components": sum(len(group) for group in parts.values()),
              "rigid_meshes": stats, "triangles": sum(group["triangles"] for group in stats.values()),
              "bounds_blender": {"min": low, "max": high},
              "dimensions_m": [b - a for a, b in zip(low, high)],
              "godot_forward": "-Z", "godot_up": "+Y", "glb": str(glb.relative_to(ROOT))}
    (HERE / "build-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print("Tank triangles:", report["triangles"])
    raise SystemExit(0)

export_collection.hide_render = True
export_collection.hide_viewport = True

ground = material("Studio / warm graphite", (.115, .13, .145), 0, .8)
box("Studio ground", (0, 0, -.07), (200, 200, .1), ground, group=None, bevel=0)
world = bpy.data.worlds.new("Soft studio environment")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (.25, .30, .39, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = .5


def area(name, loc, power, size, color, target=(0, 0, 1)):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = power
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    studio.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


area("Key / broad warm softbox", (3, 6, 11), 1900, 7, (1, .88, .72))
area("Fill / cool softbox", (-6, 1, 5), 1500, 6, (.68, .80, 1))
area("Rim / rear softbox", (3, -6, 7), 2300, 5, (1, .93, .8))
camera_data = bpy.data.cameras.new("Review camera")
camera = bpy.data.objects.new("Review camera", camera_data)
studio.objects.link(camera)
scene.camera = camera
camera_data.type = "ORTHO"
scene.render.engine = "CYCLES"
scene.cycles.samples = 40
scene.cycles.use_denoising = True
scene.cycles.device = "CPU"
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.view_settings.view_transform = "AgX"
scene.render.resolution_x = 1400
scene.render.resolution_y = 1100
bpy.context.preferences.filepaths.save_version = 0


def aim(loc, target, scale):
    camera.location = loc
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = scale


aim((10, 13, 9), (0, .8, 1.05), 11.4)
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
bpy.context.view_layer.objects.active = root
scene.render.filepath = str(RENDERS / "01-front-three-quarter.png")
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "bastion_tank_v1.blend"))
bpy.ops.render.render(write_still=True)
aim((-10, -12, 9), (0, .5, 1), 11.4)
scene.render.filepath = str(RENDERS / "02-rear-three-quarter.png")
bpy.ops.render.render(write_still=True)
aim((8, 11, 14), (0, .7, .8), 11.6)
scene.render.filepath = str(RENDERS / "03-rts-view.png")
bpy.ops.render.render(write_still=True)

bounds = [obj.matrix_world @ Vector(corner) for group in parts.values() for obj in group for corner in obj.bound_box]
minimum = [min(v[i] for v in bounds) for i in range(3)]
maximum = [max(v[i] for v in bounds) for i in range(3)]
report = {"asset": "Bastion tank v2", "blender": bpy.app.version_string,
          "source_components": sum(map(len, parts.values())), "rigid_meshes": stats,
          "triangles": sum(s["triangles"] for s in stats.values()),
          "bounds_blender": {"min": minimum, "max": maximum},
          "dimensions_m": [maximum[i] - minimum[i] for i in range(3)],
          "godot_forward": "-Z", "godot_up": "+Y", "glb": str(glb.relative_to(ROOT))}
(HERE / "build-report.json").write_text(json.dumps(report, indent=2) + "\n")
print("Bastion tank build complete:", json.dumps({"triangles": report["triangles"], "glb": report["glb"]}))
