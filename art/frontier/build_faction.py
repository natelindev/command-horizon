"""Rebuild the Free Frontier models, editable catalogue, icons and contact renders.

blender --background --factory-startup --python-exit-code 1 --python art/frontier/build_faction.py
Append -- --motion-only to export the four mobile antenna rigs without studio renders.
"""
import json
import math
from pathlib import Path
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
import weathering  # noqa: E402
import trim_sheet  # noqa: E402
import modeling  # noqa: E402
import export_manifest  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/frontier/v1"
ICONS = ROOT / "assets/ui/frontier"
SOURCE = ROOT / "art/frontier/v1"
for directory in (OUT, ICONS, SOURCE):
    directory.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
bpy.context.preferences.filepaths.save_version = 0
random.seed(42)


def mat(name, color, metallic=.25, roughness=.5, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Emission Color"].default_value = (*color, 1)
    bsdf.inputs["Emission Strength"].default_value = emission
    return m


ARMOR = mat("Frontier_Ceramic", (.27, .32, .18), .15, .42)
PANEL = mat("Frontier_Secondary", (.52, .42, .28), .25, .48)
DARK = mat("Frontier_Graphite", (.025, .043, .050), .6, .4)
STEEL = mat("Frontier_Titanium", (.22, .28, .30), .75, .35)
TEAM = mat("TeamColor_Frontier", (.72, .22, .055), .25, .42)
RUBBER = mat("Frontier_Rubber", (.012, .019, .021), 0, .88)
GLASS = mat("Frontier_Optics", (.62, .80, .56), .25, .22, 1.2)
CANOPY = mat("Frontier_CanopyGlass", (.045, .075, .085), .15, .08)
WHITE = mat("Frontier_Canvas", (.70, .65, .48), 0, .86)
ORANGE = mat("Frontier_Warning", (.95, .23, .025), .1, .5)
CONCRETE = mat("Frontier_Foundation", (.20, .245, .26), 0, .85)
assets = []
current = None
root = None


def begin(name):
    global current, root
    current = bpy.data.collections.new(name)
    scene.collection.children.link(current)
    root = bpy.data.objects.new(name, None)
    current.objects.link(root)
    root["faction"] = "Free Frontier Coalition"
    root["forward"] = "-Z in Godot"
    assets.append((name, current, root))
    print("Building", name, flush=True)
    return root


def attach(obj, name, material, parent=None, bevel=0, smooth=True, sharp_angle=35.0):
    return modeling.finalize_part(
        obj, current.name + "_" + name, current, material, parent or root,
        bevel=bevel, bevel_segments=2 if bevel >= .04 else 1,
        smooth=smooth, sharp_angle=sharp_angle,
    )


def box(name, xyz, size, material=ARMOR, parent=None, bevel=.035, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rot:
        obj.rotation_euler = rot
        if not parent:
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return attach(obj, name, material, parent, bevel)


def cyl(name, xyz, radius, depth, material=DARK, parent=None, axis="Z", vertices=20):
    vertices = max(vertices, 18 if radius >= .15 else 12)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=xyz)
    obj = bpy.context.object
    if axis == "Y":
        obj.rotation_euler.x = math.pi / 2
    if axis == "X":
        obj.rotation_euler.y = math.pi / 2
    return attach(obj, name, material, parent, bevel=0, smooth=True, sharp_angle=35.0)


def rod(name, a, b, radius, material=STEEL, parent=None, vertices=12):
    delta = Vector(b) - Vector(a)
    obj = cyl(name, (Vector(a) + Vector(b)) / 2, radius, delta.length, material, parent, vertices=vertices)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return obj


def shape(name, vertices, faces, material=ARMOR, parent=None, bevel=.02, smooth=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    current.objects.link(obj)
    return attach(obj, name, material, parent, bevel, smooth=smooth)


def loft(name, rings, material=ARMOR, parent=None, bevel=.02, sharp_angle=38.0):
    return modeling.loft_rings(
        current.name + "_" + name, rings, current, material, parent or root,
        closed_caps=True, bevel=bevel, bevel_segments=2 if bevel >= .04 else 1,
        smooth=True, sharp_angle=sharp_angle,
    )


def lathe(name, prof, origin, axis_dir, material=DARK, parent=None, segments=22, sharp_angle=36.0):
    return modeling.lathe_profile(
        current.name + "_" + name, prof, origin, axis_dir, segments,
        current, material, parent or root, smooth=True, sharp_angle=sharp_angle,
    )


def wedge(name, x, y, z, width, length, height, material=ARMOR, parent=None):
    return loft(name, [
        modeling.rounded_rect_ring(width, length, min(width, length) * .12, x, y, z, 2),
        modeling.rounded_rect_ring(width * .88, length * .86, min(width, length) * .10, x, y - length * .04, z + height * .55, 2),
        modeling.rounded_rect_ring(width * .74, length * .68, min(width, length) * .08, x, y - length * .08, z + height, 2),
    ], material, parent, bevel=.025)


def pivot(name, xyz, parent=None):
    obj = bpy.data.objects.new(current.name + "_" + name, None)
    current.objects.link(obj)
    obj.location = xyz
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent or root
    obj.matrix_world = world
    return obj


def beam(name, a, b, width, depth, material=ARMOR, parent=None):
    delta = Vector(b) - Vector(a)
    obj = box(name, (Vector(a) + Vector(b)) / 2, (width, depth, delta.length), material, parent, .03)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return obj


def prism(name, points, z, height, material=ARMOR, parent=None, inset=.85):
    n = len(points)
    cx = sum(p[0] for p in points) / n
    cy = sum(p[1] for p in points) / n
    ring0 = [(x, y, z) for x, y in points]
    ring1 = [(cx + (x - cx) * (.5 + .5 * inset), cy + (y - cy) * (.5 + .5 * inset), z + height * .55) for x, y in points]
    ring2 = [(cx + (x - cx) * inset, cy + (y - cy) * inset, z + height) for x, y in points]
    return loft(name, [ring0, ring1, ring2], material, parent, bevel=.02)


def shell(name, x, y, z, w, l, h, material=ARMOR, parent=None):
    return prism(name, [
        (x - w * .5, y - l * .32), (x - w * .28, y - l * .5), (x + w * .28, y - l * .5),
        (x + w * .5, y - l * .32), (x + w * .5, y + l * .20), (x + w * .24, y + l * .5),
        (x - w * .24, y + l * .5), (x - w * .5, y + l * .20),
    ], z, h, material, parent, inset=.82)


def ring(name, center, radius, thickness, material=ARMOR, parent=None, rotation=None):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=32, minor_segments=10, location=center,
        major_radius=radius, minor_radius=thickness,
    )
    obj = bpy.context.object
    if rotation:
        obj.rotation_euler = rotation
        if not parent:
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return attach(obj, name, material, parent, smooth=True, sharp_angle=50.0)


def lens(x, y, z, width=.45, parent=None):
    modeling.recessed_viewport(
        current.name + "_Optic", (x, y, z), width, max(.09, width * .24), .15,
        (0, 1, 0), current, DARK, GLASS, parent or root,
    )


def vent(x, y, z, width=.8, length=.6, parent=None):
    modeling.louver_grille(
        current.name + "_Vent", (x, y, z), width, length, 5,
        current, DARK, STEEL, parent or root,
    )


def antenna(x, y, z, parent=None):
    cyl("AntennaBase", (x, y, z + .06), .09, .12, DARK, parent, vertices=14)
    mast = pivot("AntennaPivot", (x, y, z), parent) if current.name in {
        "ScrapperRig", "Outrider", "Ironback", "JackalRig", "PatchCrawler",
        "BattleRig", "DemolitionBuggy", "SAMTechnical",
    } else parent
    rod("Antenna", (x, y, z), (x, y, z + .72), .018, STEEL, mast, vertices=10)


def warning(x, y, z, parent=None):
    box("Warning", (x, y, z), (.15, .035, .12), ORANGE, parent, .005)


def plate(name, xyz, size, parent=None, material=PANEL):
    box(name, xyz, size, material, parent, .02)
    x, y, z = xyz
    w, l, h = size
    for side in (-1, 1):
        cyl("PlateBolt", (x + side * w * .35, y, z + h / 2 + .008), .028, .025, STEEL, parent, vertices=8)


def tire(x, y, r, parent=None):
    wheel = pivot("WheelPivot", (x, y, r + .04), parent)
    side = 1 if x > 0 else -1
    modeling.detailed_wheel(
        current.name + f"_Wheel_{x:.2f}_{y:.2f}", (x, y, r + .04),
        r, .34, side, current, RUBBER, STEEL, TEAM, wheel, segments=22, lug_count=12,
    )


def chassis(name, width=2.2, length=3.5, axles=3):
    begin(name)
    for i in range(axles):
        y = (i / (axles - 1) - .5) * length * .72
        rod("Axle", (-width / 2, y, .47), (width / 2, y, .47), .09, STEEL, vertices=14)
        for side in (-1, 1):
            tire(side * width / 2, y, .46)
    box("Frame", (0, 0, .65), (width * .72, length, .22), DARK, bevel=.03)
    loft("Hull", [
        modeling.rounded_rect_ring(width * .88, length * .98, .20, 0, 0, .72, 2),
        modeling.rounded_rect_ring(width * .92, length * .96, .20, 0, 0, .96, 2),
        modeling.rounded_rect_ring(width * .78, length * .82, .18, 0, -.06, 1.18, 2),
    ], ARMOR, bevel=.03)
    for side in (-1, 1):
        for y in (-length * .3, length * .3):
            plate("Fender", (side * width * .48, y, 1.06), (.45, length * .37, .09))
    box("Bumper", (0, length * .53, .74), (width * .94, .14, .18), STEEL, bevel=.035)
    for side in (-1, 1):
        lens(side * width * .3, length * .51, 1.04, .19)
    vent(0, -length * .3, 1.21, .8, .65)
    pivot("DamageSocket", (0, -length * .3, 1.26))


def cage(x, y, z, w, l, h, parent=None):
    # Tubular roll-cage using connected sweep frames
    for sx in (-1, 1):
        modeling.sweep_tube(
            current.name + f"_RollRail_{sx}",
            [(x + sx * w / 2, y - l / 2, z), (x + sx * w / 2, y - l / 2, z + h),
             (x + sx * w / 2, y + l / 2, z + h), (x + sx * w / 2, y + l / 2, z)],
            .036, 10, current, STEEL, parent or root,
        )
    for sy in (-1, 1):
        rod("CageCross", (x - w / 2, y + sy * l / 2, z + h), (x + w / 2, y + sy * l / 2, z + h), .035, STEEL, parent, vertices=10)


def crate(x, y, z, w=.6):
    box("Crate", (x, y, z), (w, w, .5), PANEL, bevel=.03)
    for side in (-1, 1):
        box("CrateBand", (x + side * w * .3, y, z + .26), (.05, w, .035), STEEL, bevel=.01)


def gun(z, length, parent):
    barrel = pivot("BarrelPivot", (0, .35, z), parent)
    box("Mantlet", (0, .46, z), (.48, .6, .38), PANEL, barrel, .06)
    lathe("Barrel", [
        (.095, .75), (.095, 1.05), (.075, 1.08), (.075, .80 + length),
    ], (0, 0, z), (0, 1, 0), STEEL, barrel, segments=18)
    lathe("Brake", [
        (.12, .72 + length), (.12, .96 + length), (.095, .98 + length),
    ], (0, 0, z), (0, 1, 0), DARK, barrel, segments=16)
    pivot("Muzzle", (0, 1.0 + length, z), barrel)


def cab(y=.7):
    wedge("Cab", 0, y, 1.1, 1.42, 1.1, .7, ARMOR)
    box("Windscreen", (0, y + .51, 1.58), (1.03, .035, .32), DARK, bevel=.01)
    box("WindowSplit", (0, y + .54, 1.59), (.055, .05, .34), STEEL, bevel=.01)
    cage(0, y, 1.13, 1.48, 1.16, .83)
    plate("CabRoof", (0, y, 1.98), (1.59, 1.29, .08), material=TEAM)


def engineer():
    chassis("ScrapperRig", 2.2, 3.3)
    cab(.76)
    box("CargoBed", (0, -.9, 1.18), (1.7, 1.1, .11), STEEL, bevel=.025)
    cage(0, -.9, 1.2, 1.69, 1.15, .6)
    crate(-.37, -.86, 1.49)
    crate(.37, -1.02, 1.46, .47)
    arm = pivot("ToolArmRight", (.92, -.12, 1.2))
    cyl("CraneBase", (.92, -.12, 1.22), .16, .18, DARK, arm, vertices=16)
    beam("Crane", (.92, -.12, 1.2), (.9, .4, 2.65), .18, .2, TEAM, arm)
    cyl("CraneJoint", (.9, .4, 2.65), .14, .22, DARK, arm, axis="X", vertices=16)
    beam("Boom", (.9, .4, 2.65), (.9, 1.82, 1.8), .14, .17, STEEL, arm)
    for x in (.78, 1.02):
        rod("Grab", (x, 1.82, 1.8), (x, 2.07, 1.5), .045, DARK, arm, vertices=10)
    antenna(-.72, -.33, 1.52)
    turret = pivot("TurretPivot", (-.17, .72, 2.03))
    cyl("DefenseGunRing", (-.17, .72, 2.05), .28, .13, STEEL, turret, vertices=20)
    box("20mmGunShield", (-.17, .89, 2.2), (.69, .15, .4), ARMOR, turret, .04)
    box("DefenseAmmoBox", (-.51, .55, 2.14), (.3, .42, .26), TEAM, turret, .03)
    barrel = pivot("BarrelPivot", (-.17, .86, 2.22), turret)
    lathe("20mmBarrel", [(.055, .85), (.055, 1.15), (.036, 1.18), (.036, 1.98)], (-.17, 0, 2.22), (0, 1, 0), STEEL, barrel, segments=14)
    cyl("20mmMuzzleBrake", (-.17, 2.02, 2.22), .065, .17, DARK, barrel, axis="Y", vertices=14)
    pivot("Muzzle", (-.17, 2.13, 2.22), barrel)


def ranger():
    begin("RidgeRanger")
    for side in (-1, 1):
        leg = pivot("LegLeft" if side < 0 else "LegRight", (side * .17, 0, 1))
        loft("Trouser", [
            modeling.ellipse_ring(.11, .12, side * .20, 0, .56, 12),
            modeling.ellipse_ring(.13, .13, side * .17, 0, .96, 12),
        ], PANEL, leg)
        loft("Gaiter", [
            modeling.ellipse_ring(.095, .10, side * .21, .03, .18, 12),
            modeling.ellipse_ring(.11, .11, side * .20, 0, .53, 12),
        ], ARMOR, leg)
        loft("Boot", [
            modeling.rounded_rect_ring(.25, .40, .07, side * .21, .08, .01, 2),
            modeling.rounded_rect_ring(.22, .30, .06, side * .21, .05, .16, 2),
        ], DARK, leg, bevel=.02)
    box("Belt", (0, 0, 1.04), (.55, .35, .17), DARK, bevel=.03)
    wedge("FieldVest", 0, 0, 1.12, .65, .4, .48, ARMOR)
    for x in (-.19, .02, .21):
        box("Pouch", (x, .23, 1.3), (.15, .12, .21), PANEL, bevel=.025)
    box("Pack", (0, -.28, 1.42), (.47, .27, .47), PANEL, bevel=.05)
    cyl("Bedroll", (0, -.34, 1.75), .11, .58, WHITE, axis="X", vertices=16)
    for side in (-1, 1):
        loft("Sleeve", [
            modeling.ellipse_ring(.095, .10, side * .37, 0, 1.54, 10),
            modeling.ellipse_ring(.085, .09, side * .42, .16, 1.25, 10),
        ], WHITE)
        loft("Arm", [
            modeling.ellipse_ring(.085, .09, side * .42, .16, 1.25, 10),
            modeling.ellipse_ring(.075, .08, side * .14, .42, 1.28, 10),
        ], ARMOR)
        box("Glove", (side * .14, .42, 1.28), (.15, .16, .15), DARK, bevel=.03)
    cyl("Neck", (0, 0, 1.73), .1, .14, DARK, vertices=14)
    loft("Helmet", [
        modeling.ellipse_ring(.21, .22, 0, 0, 1.75, 16),
        modeling.ellipse_ring(.22, .23, 0, 0, 1.92, 16),
        modeling.ellipse_ring(.16, .17, 0, -.01, 2.05, 16),
    ], ARMOR)
    box("Goggles", (0, .19, 1.9), (.31, .05, .095), GLASS, bevel=.015)
    box("Scarf", (0, .09, 1.76), (.41, .3, .1), WHITE, bevel=.03)
    box("Armband", (-.39, .04, 1.5), (.21, .25, .13), TEAM, bevel=.02)
    box("Carbine", (.1, .48, 1.36), (.14, .56, .14), DARK, bevel=.025)
    box("WoodStock", (.1, .24, 1.34), (.16, .22, .14), PANEL, bevel=.025)
    cyl("Barrel", (.1, .92, 1.38), .032, .36, STEEL, axis="Y", vertices=12)
    pivot("Muzzle", (.1, 1.11, 1.38))
    antenna(.23, -.3, 1.6)


def scrap_armor(width, length):
    for rank in (1, 2):
        group = pivot(f"ScrapRank{rank}", (0, 0, 1.16))
        for side in (-1, 1):
            y = -.45 if rank == 1 else .58
            box(f"SalvagePlate{rank}", (side * width * .46, y, 1.19),
                (.09, .76 if rank == 1 else .58, .38), PANEL if rank == 1 else STEEL,
                group, .025, rot=(0, side * .13, side * .06))
            for bolt_y in (y - .24, y + .24):
                cyl("PlateBolt", (side * width * .49, bolt_y, 1.22), .035, .04, DARK, group, axis="X", vertices=8)
        if rank == 2:
            box("SalvageBow", (0, length * .44, 1.13), (width * .55, .1, .28), PANEL, group, .025)


def armor(heavy=False):
    name = "Ironback" if heavy else "Outrider"
    if not heavy:
        # Sleek 6x6 sloped desert scout car (distinct from Ironback juggernaut)
        chassis(name, 2.1, 3.55, 3)
        loft("ScoutGlacis", [
            modeling.rounded_rect_ring(1.88, 2.20, .24, 0, .35, .95, 2),
            modeling.rounded_rect_ring(1.62, 1.65, .20, 0, .15, 1.35, 2),
        ], PANEL, bevel=.03)
        cyl("Bearing", (0, -.15, 1.36), .58, .18, DARK, vertices=24)
        turret = pivot("TurretPivot", (0, -.15, 1.46))
        loft("ScoutTurret", [
            modeling.rounded_rect_ring(1.28, 1.48, .28, 0, -.15, 1.42, 2),
            modeling.rounded_rect_ring(1.02, 1.18, .22, 0, -.20, 1.86, 2),
        ], ARMOR, turret, bevel=.025)
        plate("TurretPatch", (0, -.32, 1.88), (.64, .58, .04), turret, TEAM)
        modeling.cupola_hatch(current.name + "_Hatch", (-.32, -.28, 1.86), .20, .10, current, PANEL, DARK, GLASS, turret)
        modeling.sensor_pod(current.name + "_Optics", (.36, .28, 1.86), .68, (0, 1, 0), current, DARK, GLASS, STEEL, turret)
        gun(1.65, 1.65, turret)
        antenna(-.46, -.68, 1.88, turret)
        scrap_armor(2.1, 3.55)
        return
    # Ironback: heavy 8x8 armored juggernaut with stepped composite glacis & bustle rack
    chassis("Ironback", 2.60, 4.15, 4)
    cyl("Bearing", (0, -.24, 1.25), .72, .22, DARK, vertices=28)
    turret = pivot("TurretPivot", (0, -.24, 1.39))
    loft("SalvagedTurret", [
        modeling.rounded_rect_ring(1.78, 1.86, .28, 0, -.24, 1.35, 2),
        modeling.rounded_rect_ring(1.64, 1.72, .26, 0, -.28, 1.70, 2),
        modeling.rounded_rect_ring(1.34, 1.38, .22, 0, -.32, 1.98, 2),
    ], ARMOR, turret, bevel=.025)
    plate("TurretPatch", (-.38, -.36, 1.99), (.54, .78, .045), turret, TEAM)
    cage(0, -1.25, 1.36, 1.64, .52, .44, turret)
    cyl("Hatch", (.38, -.43, 1.99), .26, .09, DARK, turret, vertices=20)
    modeling.sensor_pod(current.name + "_FCS", (.45, .36, 1.98), .75, (0, 1, 0), current, DARK, GLASS, STEEL, turret)
    for side in (-1, 1):
        modeling.smoke_dischargers(current.name + f"_Smoke_{side}", (side * .88, .15, 1.72), side, current, DARK, STEEL, turret)
    gun(1.67, 2.65, turret)
    for side in (-1, 1):
        for y in (-1.15, -.55, .05, .65):
            plate("Applique", (side * 1.12, y, 1.31), (.32, .45, .22))
        box("TurretSlat", (side * .96, -.4, 1.68), (.06, 1.48, .52), STEEL, turret, .01)
    cyl("SpareTire", (0, -2.10, 1.2), .40, .22, RUBBER, axis="Y", vertices=20)
    antenna(-.58, -.8, 1.99, turret)
    scrap_armor(2.60, 4.15)


def crawler(repair=False):
    chassis("PatchCrawler" if repair else "JackalRig", 1.8, 2.5, 2)
    if repair:
        box("ToolChest", (0, -.35, 1.39), (1.36, 1.13, .54), TEAM, bevel=.05)
        for y in (-.63, -.3, .03):
            box("Drawer", (0, y, 1.69), (1.12, .035, .025), STEEL, bevel=.005)
        arm = pivot("ToolArmLeft", (-.48, .42, 1.34))
        cyl("ArmBase", (-.48, .42, 1.34), .14, .18, DARK, arm, axis="X", vertices=16)
        beam("RepairArm", (-.48, .42, 1.34), (-.4, 1.12, 2.05), .17, .2, PANEL, arm)
        cyl("ArmElbow", (-.4, 1.12, 2.05), .13, .18, DARK, arm, axis="X", vertices=16)
        beam("Welder", (-.4, 1.12, 2.05), (0, 1.59, 1.29), .12, .16, STEEL, arm)
        lathe("GasBottle", [(.16, -.36), (.16, .24), (.12, .34), (.05, .38), (0, .38)], (.51, .3, 1.63), (0, 0, 1), WHITE, segments=18)
        ring("Hose", (.37, -.49, 1.86), .26, .035, DARK, rotation=(math.pi / 2, 0, 0))
    else:
        turret = pivot("TurretPivot", (0, -.15, 1.38))
        box("GunShield", (0, .19, 1.62), (1.26, .18, .74), ARMOR, turret, .04)
        gun(1.64, 1.36, turret)
        box("AmmoBox", (-.57, -.35, 1.49), (.43, .55, .35), TEAM, turret, .035)
        for x in (.32, .57):
            cyl("AATube", (x, -.18, 1.97), .1, 1.1, DARK, turret, axis="Y", vertices=16)
        antenna(-.56, -.6, 1.61, turret)
    lens(0, 1.15, 1.18, .46)


def rotor(name, x, y, z, r, parent=None):
    p = pivot(name, (x, y, z), parent)
    modeling.pitched_rotor(current.name + "_Fan_" + name, (x, y, z), r, 3, current, STEEL, DARK, p, axis="Z")


def scout():
    begin("LookoutDrone")
    box("BatteryBody", (0, 0, .52), (.62, .83, .28), PANEL, bevel=.05)
    plate("DroneID", (0, 0, .69), (.4, .58, .035), material=TEAM)
    for side in (-1, 1):
        for front in (-1, 1):
            x, y = side * .83, front * .72
            rod("RotorArm", (side * .17, front * .22, .55), (x, y, .55), .045, STEEL, vertices=12)
            ring("RotorGuard", (x, y, .66), .51, .026, ARMOR)
            rotor("Rotor%d" % ((1 if side > 0 else 0) * 2 + (1 if front > 0 else 0)), x, y, .65, .44)
        rod("Skid", (side * .35, -.45, .07), (side * .35, .45, .07), .035, STEEL, vertices=10)
        rod("Leg", (side * .25, 0, .5), (side * .35, 0, .07), .035, STEEL, vertices=10)
    cyl("CameraGimbal", (0, .36, .31), .16, .23, DARK, axis="X", vertices=18)
    lens(0, .46, .29, .17)


def _chined_ring(y, rx, z_bot, z_mid, z_top, deck_ratio=0.58):
    return [
        (-rx * deck_ratio, y, z_top),
        (-rx, y, z_mid),
        (-rx * 0.72, y, z_bot),
        (rx * 0.72, y, z_bot),
        (rx, y, z_mid),
        (rx * deck_ratio, y, z_top),
    ]


def aircraft():
    begin("KestrelGunship")
    # Faceted chined attack-gunship fuselage with armored cockpit cheeks and tapered tail transition.
    loft("Fuselage", [
        _chined_ring(-1.38, .28, .86, 1.04, 1.24, .52),
        _chined_ring(-0.85, .52, .68, 1.02, 1.38, .64),
        _chined_ring(0.10, .64, .56, .94, 1.40, .66),
        _chined_ring(0.88, .58, .58, .92, 1.28, .62),
        _chined_ring(1.48, .40, .66, .88, 1.08, .58),
        _chined_ring(1.92, .18, .72, .84, .95, .52),
    ], ARMOR, bevel=.02)
    # Armored cockpit cheek sponsons (field-bolted avionics/ammo bays).
    for side in (-1, 1):
        loft(f"CheekBay_{side}", [
            modeling.rounded_rect_ring(.26, 1.32, .05, side * .56, .20, .64, 1),
            modeling.rounded_rect_ring(.30, 1.44, .06, side * .58, .22, .84, 1),
            modeling.rounded_rect_ring(.20, 1.18, .04, side * .52, .16, 1.04, 1),
        ], PANEL, bevel=.015)
        box(f"CheekStripe_{side}", (side * .72, .22, .85), (.03, .92, .14), TEAM, bevel=.005)
    # Stepped tandem greenhouse canopy with dark tinted glass and armored frame bows.
    loft("CanopyGlass", [
        _chined_ring(.24, .44, 1.18, 1.32, 1.48, .64),
        _chined_ring(.84, .41, 1.12, 1.28, 1.45, .62),
        _chined_ring(1.42, .30, 1.00, 1.14, 1.24, .56),
        _chined_ring(1.66, .18, .92, 1.00, 1.06, .52),
    ], CANOPY, bevel=.012)
    for y, rx, z_top, z_side in ((.38, .45, 1.50, 1.28), (.88, .42, 1.46, 1.22), (1.36, .31, 1.26, 1.06)):
        rod("CanopyBowL", (0, y, z_top), (-rx, y, z_side), .024, DARK, vertices=8)
        rod("CanopyBowR", (0, y, z_top), (rx, y, z_side), .024, DARK, vertices=8)
    rod("CanopySpine", (0, .28, 1.49), (0, 1.62, 1.05), .026, DARK, vertices=8)
    # Dorsal transmission housing, side turboshaft nacelles, intakes, and exhaust deflectors.
    loft("EngineDeck", [
        modeling.rounded_rect_ring(.78, 1.34, .14, 0, -.32, 1.34, 2),
        modeling.rounded_rect_ring(.62, 1.08, .12, 0, -.36, 1.60, 2),
    ], PANEL, bevel=.02)
    plate("RoofPatch", (0, -.36, 1.62), (.54, .68, .04), material=TEAM)
    for side in (-1, 1):
        lathe(f"Turboshaft_{side}", [
            (.06, -.74), (.19, -.66), (.22, -.28), (.21, .20), (.16, .38), (.08, .44),
        ], (side * .54, -.26, 1.34), (0, 1, 0), PANEL, segments=16)
        cyl(f"IntakeLip_{side}", (side * .54, .18, 1.34), .14, .10, DARK, axis="Y", vertices=14)
        cyl(f"ExhaustStub_{side}", (side * .64, -.86, 1.30), .11, .34, STEEL, axis="Y", vertices=12)
        cyl(f"ExhaustBore_{side}", (side * .64, -1.02, 1.30), .08, .08, DARK, axis="Y", vertices=12)
    # Main rotor mast, swashplate, and 4-blade rotor assembly (keeps single Rotor0 contract).
    cyl("RotorMast", (0, -.22, 1.72), .11, .38, STEEL, vertices=16)
    cyl("Swashplate", (0, -.22, 1.78), .20, .06, DARK, vertices=16)
    rotor("Rotor0", 0, -.22, 1.94, 2.86)
    # Tapered hexagonal tail boom, dorsal spine, tail fin with team marking, stabilator, and tail rotor.
    loft("TailBoom", [
        _chined_ring(-1.18, .30, .86, 1.04, 1.24, .54),
        _chined_ring(-2.40, .18, .98, 1.12, 1.26, .52),
        _chined_ring(-3.55, .10, 1.12, 1.22, 1.34, .48),
    ], ARMOR, bevel=.015)
    shape("TailFin", [
        (-.055, -3.76, 1.16), (-.045, -3.52, 2.26), (-.045, -3.14, 2.22), (-.055, -2.98, 1.22),
        (.055, -3.76, 1.16), (.045, -3.52, 2.26), (.045, -3.14, 2.22), (.055, -2.98, 1.22),
    ], [
        (0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)
    ], ARMOR, bevel=.015)
    box("TailFinBand", (0, -3.38, 1.88), (.115, .44, .22), TEAM, bevel=.005)
    # Side-mounted tail rotor hub & 4 blades (static mesh on boom so Rotor0 remains the sole RotorN).
    cyl("TailRotorHub", (.12, -3.52, 1.92), .07, .16, STEEL, axis="X", vertices=12)
    for angle in (0, math.pi / 2, math.pi, 3 * math.pi / 2):
        blade = box("TailBlade", (.18, -3.52 + math.cos(angle) * .28, 1.92 + math.sin(angle) * .28), (.02, .52, .07), DARK, bevel=.004)
        blade.rotation_euler = (angle, 0, 0)
    # Stub weapon wings, horizontal tailplanes, rocket pods, missiles, and reinforced skids.
    for side in (-1, 1):
        modeling.airfoil_wing(
            current.name + f"_Wing_{side}", (side * .42, -.02), (side * 1.62, -.24),
            .64, .34, 1.00, .92, .16, .08, current, ARMOR, root, bevel=.012,
        )
        box(f"WingStripe_{side}", (side * 1.12, -.14, 1.03), (.38, .22, .02), TEAM, bevel=.004)
        modeling.airfoil_wing(
            current.name + f"_Tailplane_{side}", (side * .08, -3.16), (side * .78, -3.32),
            .38, .20, 1.22, 1.22, .07, .04, current, PANEL, root, bevel=.008,
        )
        # Inner multi-tube rocket pod + outer twin anti-armor missiles.
        box(f"InnerPylon_{side}", (side * 1.02, -.08, .82), (.08, .48, .22), STEEL, bevel=.008)
        cyl(f"RocketPod_{side}", (side * 1.02, -.06, .66), .20, 1.02, DARK, axis="Y", vertices=16)
        cyl(f"RocketPodBand_{side}", (side * 1.02, .14, .66), .208, .12, TEAM, axis="Y", vertices=16)
        for dx, dz in ((0, 0), (.09, .05), (-.09, .05), (.09, -.05), (-.09, -.05), (0, .10), (0, -.10)):
            cyl(f"RocketTip_{side}", (side * 1.02 + dx, .47, .66 + dz), .036, .06, ORANGE, axis="Y", vertices=8)
        box(f"OuterPylon_{side}", (side * 1.46, -.20, .82), (.07, .40, .18), STEEL, bevel=.008)
        for dz in (-.06, .08):
            cyl(f"Missile_{side}", (side * 1.46, -.12, .68 + dz), .045, .96, WHITE, axis="Y", vertices=10)
            cyl(f"MissileHead_{side}", (side * 1.46, .38, .68 + dz), .035, .10, DARK, axis="Y", vertices=10)
        # Reinforced landing skids with angled tubular struts and curved toe tips.
        rod(f"Skid_{side}", (side * .82, -1.24, .14), (side * .82, 1.28, .14), .05, STEEL, vertices=12)
        rod(f"SkidToe_{side}", (side * .82, 1.26, .14), (side * .82, 1.48, .26), .045, STEEL, vertices=10)
        for y in (-.66, .72):
            rod(f"SkidStrut_{side}", (side * .42, y, .68), (side * .82, y, .14), .042, STEEL, vertices=10)
    # Chin FLIR targeting turret + underslung rotary cannon.
    cyl("SensorTurret", (0, 1.72, .88), .18, .20, DARK, vertices=14)
    lens(0, 1.88, .88, .24)
    cyl("ChinMount", (0, 1.24, .50), .18, .24, DARK, vertices=14)
    for dx in (-.05, .05):
        cyl("ChinBarrel", (dx, 1.66, .48), .028, .72, STEEL, axis="Y", vertices=10)
    pivot("Muzzle", (0, 2.04, .48))


def foundation(name, w, l):
    begin(name)
    loft("GravelPad", [
        modeling.rounded_rect_ring(w, l, .14, 0, 0, 0.0, 2),
        modeling.rounded_rect_ring(w * .98, l * .98, .14, 0, 0, .16, 2),
    ], CONCRETE, bevel=.03)
    for side in (-1, 1):
        box("PadEdge", (side * w * .47, 0, .18), (.1, l * .95, .12), STEEL, bevel=.02)


def container(x, y, w=1.6, l=3, h=1.55, material=ARMOR):
    box("Container", (x, y, .22 + h / 2), (w, l, h), material, bevel=.04)
    for side in (-1, 1):
        for i in range(7):
            box("Corrugation", (x + side * (w / 2 + .018), y + (i - 3) * l / 7, .22 + h / 2), (.055, .07, h * .88), STEEL, bevel=.008)
        box("CornerPost", (x + side * w * .47, y + l * .48, .22 + h / 2), (.1, .1, h), STEEL, bevel=.02)
    box("Door", (x, y + l / 2 + .028, .22 + h * .4), (w * .68, .055, h * .75), DARK, bevel=.02)
    box("IDPlate", (x, y + l / 2 + .062, .22 + h * .8), (w * .65, .025, .16), TEAM, bevel=.01)
    vent(x, y, .24 + h, w * .62, l * .38)


def canopy(x, y, z, w, l, h=.6):
    for side in (-1, 1):
        for sy in (-1, 1):
            rod("CanopyPole", (x + side * w / 2, y + sy * l / 2, .2), (x + side * w / 2, y + sy * l / 2, z), .045, STEEL, vertices=12)
    shape("Canvas", [
        (x - w / 2, y - l / 2, z), (x, y - l / 2, z + h), (x + w / 2, y - l / 2, z),
        (x - w / 2, y + l / 2, z), (x, y + l / 2, z + h), (x + w / 2, y + l / 2, z),
    ], [(0, 1, 4, 3), (1, 2, 5, 4)], WHITE, bevel=0, smooth=False)
    for sy in (-1, 1):
        rod("RoofBrace", (x - w / 2, y + sy * l / 2, z), (x, y + sy * l / 2, z + h), .028, STEEL, vertices=10)
        rod("RoofBrace", (x, y + sy * l / 2, z + h), (x + w / 2, y + sy * l / 2, z), .028, STEEL, vertices=10)


def mast(x, y, z=0, h=3):
    for side in (-1, 1):
        beam("MastLeg", (x + side * .32, y, z + .2), (x, y, z + h), .09, .09, STEEL)
    for i in range(5):
        rod("MastRung", (x - .22, y, z + .4 + i * h / 6), (x + .22, y, z + .4 + i * h / 6), .025, STEEL, vertices=10)
    antenna(x, y, z + h)


def quonset(x, y, w=2.2, l=3.4, h=1.8, material=ARMOR):
    """Curved corrugated Quonset hut / Nissen shelter."""
    segs = 10
    ring0, ring1 = [], []
    for i in range(segs + 1):
        a = math.pi * (1.0 - i / segs)
        dx = math.cos(a) * (w / 2)
        dz = .22 + math.sin(a) * h
        ring0.append((x + dx, y - l / 2, dz))
        ring1.append((x + dx, y + l / 2, dz))
    loft("QuonsetArch", [ring0, ring1], material, bevel=.02)
    box("QuonsetBase", (x, y, .32), (w * .98, l * .98, .22), CONCRETE, bevel=.02)
    box("QuonsetFront", (x, y + l / 2 - .03, .22 + h * .42), (w * .74, .08, h * .76), DARK, bevel=.02)
    box("QuonsetID", (x, y + l / 2 + .02, .22 + h * .78), (w * .45, .04, .18), TEAM, bevel=.01)


def command():
    foundation("ConvoyHQ", 6.4, 5.8)
    # 6-wheel heavy mobile command semi-rig parked diagonally/offset on pad
    box("TrailerDeck", (-.25, -.35, 1.02), (3.1, 4.7, .32), DARK, bevel=.04)
    for wx in (-1.65, 1.15):
        for wy in (-2.05, -.95, 1.35):
            cyl("RigWheel", (wx, wy, .58), .44, .34, RUBBER, axis="X", vertices=20)
            cyl("RigHub", (wx + (.12 if wx > 0 else -.12), wy, .58), .22, .12, TEAM, axis="X", vertices=12)
    # Armored forward semi-cab + bridge deck
    box("RigNose", (-.25, 1.72, 1.52), (2.45, 1.15, .86), ARMOR, bevel=.08)
    box("RigCab", (-.25, .95, 1.88), (2.65, 1.25, 1.32), PANEL, bevel=.08)
    for x in (-1.05, -.25, .55):
        modeling.recessed_viewport(current.name + f"_CmdWin_{x}", (x, 1.59, 2.12), .58, .28, .12, (0, 1, 0), current, DARK, GLASS, root)
    # Rear tactical ops bunker on trailer + side camo field awning
    container(-.55, -1.05, 2.25, 2.65, 1.65, ARMOR)
    canopy(1.95, -.55, 2.15, 2.15, 3.3, .38)
    modeling.hvac_fan_unit(current.name + "_OpsHVAC", (-.55, -1.05, 2.02), .85, .85, .28, current, PANEL, DARK, STEEL, root)
    modeling.sensor_pod(current.name + "_CabOptics", (-.25, 1.55, 2.58), .85, (0, 1, 0), current, DARK, GLASS, STEEL, root)
    mast(-1.75, -2.05, .20, 3.45)
    box("CommsArray", (-1.75, -1.85, 1.25), (.62, .48, .72), TEAM, bevel=.04)
    for x in (1.35, 2.15):
        crate(x, .45, .54)


def barracks():
    foundation("RangerCamp", 5.8, 4.5)
    quonset(-1.25, -.15, 2.65, 3.7, 1.75, PANEL)
    # Elevated timber/steel perimeter watchtower on the right
    for sx in (-1, 1):
        for sy in (-1, 1):
            beam("WatchLeg", (1.65 + sx * .72, -.25 + sy * .72, .2), (1.65 + sx * .58, -.25 + sy * .58, 2.55), .10, .11, STEEL)
    box("WatchDeck", (1.65, -.25, 2.62), (1.68, 1.68, .14), DARK, bevel=.025)
    canopy(1.65, -.25, 3.55, 1.75, 1.75, .42)
    box("WatchRail", (1.65, .56, 2.95), (1.64, .10, .54), TEAM, bevel=.015)
    # Front sandbag firing berm
    for i in range(6):
        box("FrontBag", (-2.1 + i * .82, 1.82, .40), (.74, .44, .34), PANEL, bevel=.10)
    crate(1.65, 1.32, .52, .55)
    antenna(1.65, -.25, 4.0)


def garage(repair=False):
    foundation("FieldWorkshop" if repair else "MotorPool", 6.3, 5.6)
    if repair:
        # Left canvas awning shelter + tall A-frame recovery derrick (no Bastion turntable, no twin portals)
        quonset(-1.65, -.45, 2.25, 3.85, 1.58, ARMOR)
        for sx in (-1, 1):
            beam("DerrickLeg", (1.25 + sx * 1.18, -1.55, .22), (1.25, -.15, 3.85), .16, .18, TEAM)
        beam("DerrickStay", (1.25, -2.35, .22), (1.25, -.15, 3.85), .12, .14, STEEL)
        rod("DerrickCable", (1.25, -.15, 3.75), (1.25, -.15, 2.15), .024, DARK, vertices=8)
        ring("DerrickHook", (1.25, -.15, 2.02), .14, .03, STEEL, rotation=(math.pi / 2, 0, 0))
        arm = pivot("RepairArmRight", (2.15, 1.15, .72))
        cyl("ArmBase", (2.15, 1.15, .72), .16, .20, DARK, arm, axis="X", vertices=16)
        beam("ServiceArm", (2.15, 1.15, .72), (1.55, .85, 2.35), .17, .19, TEAM, arm)
        cyl("ArmElbow", (1.55, .85, 2.35), .14, .20, DARK, arm, axis="X", vertices=16)
        beam("ServiceTool", (1.55, .85, 2.35), (.55, .45, 1.15), .12, .15, STEEL, arm)
        for y in (-1.5, -.85):
            lathe("GasBottle", [(.22, -.62), (.22, .45), (.16, .62), (.07, .68), (0, .68)], (-.15, y, .96), (0, 0, 1), WHITE, segments=18)
    else:
        # Left Quonset motor bay + heavy rotating-style yard jib crane + spare tire pile
        quonset(-1.55, -.45, 2.55, 4.15, 2.05, PANEL)
        cyl("CranePedestal", (1.55, -1.25, 1.05), .55, 1.75, ARMOR, vertices=18)
        box("CraneCounter", (1.55, -1.85, 2.08), (.92, .75, .62), DARK, bevel=.04)
        beam("JibBoom", (1.55, -1.15, 2.05), (.35, 1.35, 3.65), .24, .26, TEAM)
        rod("JibCable", (.35, 1.35, 3.55), (.35, 1.35, 2.15), .024, DARK, vertices=8)
        ring("JibHook", (.35, 1.35, 2.02), .14, .03, STEEL, rotation=(math.pi / 2, 0, 0))
        for i in range(3):
            ring("ScrapTire", (1.85 + .06 * i, .95, .34 + i * .24), .36, .15, RUBBER, rotation=(.08 * i, -.08 * i, 0))
        lathe("YardFuel", [(.38, -.82), (.42, -.72), (.42, .72), (.38, .82)], (1.65, 1.85, .64), (1, 0, 0), PANEL, segments=18)
    crate(-2.13, 1.89, .48)
    modeling.hvac_fan_unit(current.name + "_ShopHVAC", (-1.55, -.45, 2.25 if not repair else 1.85), .75, .75, .26, current, ARMOR, DARK, STEEL, root)
    modeling.sensor_pod(current.name + "_YardCam", (1.25 if repair else 1.55, -.15, 3.85 if repair else 2.40), .85, (0, 1, 0), current, DARK, GLASS, STEEL, root)


def airfield():
    foundation("RotorPad", 7, 6.5)
    box("LandingPlate", (0, .47, .21), (4.97, 4.61, .09), DARK, bevel=.025)
    for x in (-.62, .62):
        box("LandingH", (x, .47, .27), (.19, 2.32, .025), ORANGE, bevel=0)
    box("LandingH", (0, .47, .27), (1.24, .19, .025), ORANGE, bevel=0)
    for x in (-2.39, 2.39):
        for y in (-1.74, 2.68):
            cyl("PadLight", (x, y, .29), .085, .08, ORANGE, vertices=14)
    box("PadIDStripe", (0, -1.68, .27), (3.6, .22, .03), TEAM, bevel=.005)
    canopy(-2.25, -2.35, 1.75, 1.8, 1.45, .36)
    box("RefuelBooth", (-2.25, -2.35, .68), (1.05, .92, .88), TEAM, bevel=.04)
    for x in (.21, 1.01, 1.81):
        lathe("FuelTank", [(.32, -.44), (.36, -.36), (.36, .36), (.32, .44)], (x, -2.47, .69), (0, 0, 1), PANEL, segments=20)
    mast(2.84, -2.43, .2, 2.65)


def power():
    foundation("DieselArray", 4.3, 4.1)
    # Huge single V16 diesel generator skid + giant horizontal cylindrical fuel drum on front cradles
    box("GeneratorSkid", (0, -.55, .95), (2.75, 2.15, 1.38), ARMOR, bevel=.08)
    box("RadiatorShroud", (0, -1.62, 1.02), (2.25, .28, 1.18), DARK, bevel=.04)
    vent(0, -.45, 1.68, 1.85, 1.35)
    for x in (-.78, -.26, .26, .78):
        cyl("ExhaustPipe", (x, -1.05, 2.05), .10, 1.05, STEEL, vertices=14)
    box("BreakerBox", (-1.12, .35, .92), (.58, .72, .95), TEAM, bevel=.04)
    lathe("MainFuelTank", [(.58, -1.45), (.66, -1.32), (.66, 1.32), (.58, 1.45)], (0, 1.15, 1.05), (1, 0, 0), PANEL, segments=22)
    for sx in (-1.05, 1.05):
        box("TankCradle", (sx, 1.15, .48), (.22, 1.12, .52), STEEL, bevel=.02)


def signals():
    foundation("RelayWorkshop", 5.5, 4.5)
    # Armored solar-winged comms van on left + tall 4-leg open lattice tower on right
    quonset(-1.42, -.15, 2.15, 3.4, 1.55, PANEL)
    for side in (-1, 1):
        box("SolarWing", (-1.42 + side * 1.45, -.15, 1.75), (.85, 2.15, .06), TEAM, bevel=.01, rot=(0, side * .35, 0))
    # 4-leg tapered open lattice radio tower
    for sx in (-1, 1):
        for sy in (-1, 1):
            beam("LatticeLeg", (1.28 + sx * .92, -.25 + sy * .92, .2), (1.28 + sx * .22, -.25 + sy * .22, 3.85), .09, .10, STEEL)
    for z in (1.2, 2.4):
        s = .92 - (z / 3.85) * .70
        box("LatticeRing", (1.28, -.25, z), (s * 2.0, s * 2.0, .08), DARK, bevel=.01)
    dish = pivot("RadarPivot", (1.28, -.25, 3.92))
    ring("DishRim", (1.28, .05, 4.02), .92, .06, STEEL, dish, rotation=(math.pi / 2, 0, 0))
    for i in range(12):
        a = i * math.tau / 12
        rod("DishSpoke", (1.28, -.25, 4.02), (1.28 + math.cos(a) * .92, .05, 4.02 + math.sin(a) * .92), .024, TEAM, dish, vertices=8)
    rod("Receiver", (1.28, -.25, 4.02), (1.28, .62, 4.02), .04, STEEL, dish, vertices=12)


def sentry(aa=False):
    foundation("WatchtowerAA" if aa else "RoadblockGun", 4.3, 4.0)
    if aa:
        for side in (-1, 1):
            for sy in (-1, 1):
                beam("TowerLeg", (side * 1.3, sy * 1.2, .2), (side * .77, sy * .72, 2.33), .13, .15, STEEL)
            beam("CrossBrace", (side * 1.21, -1.12, .43), (side * .81, .76, 2.18), .065, .07, TEAM)
        box("Platform", (0, 0, 2.35), (2.08, 1.99, .15), PANEL, bevel=.03)
        turret = pivot("TurretPivot", (0, 0, 2.49))
        box("Mount", (0, 0, 2.65), (.66, .81, .55), DARK, turret, .04)
        for side in (-1, 1):
            box("MissilePod", (side * .67, .13, 2.83), (.61, 1.29, .57), ARMOR, turret, .05)
            for dx in (-.15, .15):
                for dz in (-.13, .13):
                    cyl("LaunchTube", (side * .67 + dx, .80, 2.83 + dz), .095, .04, DARK, turret, axis="Y", vertices=14)
        antenna(0, -.51, 2.94, turret)
        pivot("Muzzle", (.67, .84, 2.83), turret)
    else:
        # Curved front sandbag bunker berm + towed field artillery gun on big wheels & split trails
        for i in range(7):
            ang = -1.1 + i * (2.2 / 6)
            box("Sandbag", (math.sin(ang) * 1.65, math.cos(ang) * 1.35 + .15, .44), (.62, .42, .42), PANEL, bevel=.10, rot=(0, 0, -ang))
        turret = pivot("TurretPivot", (0, -.15, .88))
        for side in (-1, 1):
            cyl("GunWheel", (side * 1.05, -.15, .72), .52, .22, RUBBER, turret, axis="X", vertices=20)
            beam("SplitTrail", (side * .28, -.25, .62), (side * .95, -1.65, .28), .14, .14, STEEL, turret)
        box("Shield", (0, .18, 1.28), (1.88, .16, .95), ARMOR, turret, .04)
        plate("ShieldID", (-.51, .22, 1.76), (.48, .22, .06), turret, TEAM)
        gun(1.36, 1.25, turret)
        crate(-1.25, -1.35, .51)


def battle_rig():
    chassis("BattleRig", 2.7, 5.1, 4)
    box("Flatbed", (0, -.65, 1.18), (2.45, 3.3, .25), PANEL, bevel=.04)
    box("ArmoredCab", (0, 1.27, 1.65), (2.25, 1.45, .95), ARMOR, bevel=.10)
    lens(0, 2.03, 1.84, 1.62)
    for side in (-1, 1):
        box("BedRail", (side * 1.18, -.75, 1.67), (.12, 3.35, .65), STEEL, bevel=.025)
        for front in (-1, 1):
            mount = pivot("GarrisonMount_%s_%s" % (side, front), (side * .72, -.7 + front * .9, 1.59))
            cyl("FiringRing", (side * .72, -.7 + front * .9, 1.59), .28, .10, DARK, mount, vertices=18)
            box("MountShield", (side * .91, -.7 + front * .9, 1.95), (.09, .58, .49), ARMOR, mount, .025)
        turret = pivot("TurretPivot" if side < 0 else "AutocannonRight", (side * .65, 1.33, 2.18))
        box("AutocannonBreech", (side * .65, 1.45, 2.18), (.38, .7, .38), TEAM, turret, .04)
        cyl("AutocannonBarrel", (side * .65, 2.2, 2.18), .08, 1.2, STEEL, turret, axis="Y", vertices=16)
        pivot("Muzzle" if side < 0 else "MuzzleRight", (side * .65, 2.83, 2.18), turret)
    antenna(-1.02, -2.02, 1.77)
    scrap_armor(2.7, 5.1)


def demolition_buggy():
    chassis("DemolitionBuggy", 1.65, 2.6, 2)
    for y in (-.64, .05, .74):
        lathe("VolatileDrum", [
            (.35, -.62), (.39, -.56), (.39, .56), (.35, .62),
        ], (0, y, 1.38), (1, 0, 0), ORANGE, segments=20)
        for side in (-1, 1):
            box("Detonator", (side * .62, y, 1.55), (.12, .32, .22), TEAM, bevel=.02)
    cage(0, 0, 1.31, 1.50, 1.92, .55)
    antenna(-.65, -.94, 1.62)


def sam_technical():
    begin("SAMTechnical")
    # Distinct open armored technical pickup: hooded front nose + upright armored cab + flatbed SAM rack
    loft("PickupFrame", [
        modeling.rounded_rect_ring(1.85, 3.65, .20, 0, -.05, .44, 2),
        modeling.rounded_rect_ring(1.98, 3.85, .24, 0, -.05, .78, 2),
    ], DARK, bevel=.03)
    loft("Hood", [
        modeling.rounded_rect_ring(1.82, 1.25, .24, 0, 1.18, .78, 2),
        modeling.rounded_rect_ring(1.66, 1.10, .20, 0, 1.15, 1.18, 2),
    ], ARMOR, bevel=.04)
    loft("CrewCab", [
        modeling.rounded_rect_ring(1.86, 1.15, .20, 0, .22, 1.18, 2),
        modeling.rounded_rect_ring(1.64, .95, .18, 0, .14, 1.76, 2),
    ], ARMOR, bevel=.05)
    lens(0, .74, 1.48, 1.32)
    box("FlatbedDeck", (0, -.95, 1.02), (1.96, 1.85, .24), PANEL, bevel=.04)
    for side in (-1, 1):
        box("BedSide", (side * .94, -.95, 1.26), (.10, 1.82, .32), TEAM, bevel=.02)
        for y in (-1.35, 0.0, 1.25):
            cyl("Wheel", (side * .96, y, .48), .48, .32, RUBBER, axis="X", vertices=22)
            cyl("Hub", (side * 1.10, y, .48), .22, .12, TEAM, axis="X", vertices=12)
    turret = pivot("TurretPivot", (0, -.95, 1.20))
    cyl("Pedestal", (0, -.95, 1.38), .36, .34, DARK, turret, vertices=18)
    for side in (-1, 1):
        box("RocketPod", (side * .56, -.95, 1.88), (.76, 1.55, .64), PANEL, turret, .06)
        for dx in (-.18, .18):
            for z in (1.72, 2.04):
                cyl("UnguidedRocket", (side * .56 + dx, -.16, z), .11, .16, DARK, turret, axis="Y", vertices=14)
    pivot("Muzzle", (.56, -.04, 1.88), turret)
    antenna(-.78, -1.65, 1.55, turret)
    scrap_armor(2.05, 3.65)


damage_only = "--damage-only" in sys.argv
motion_only = "--motion-only" in sys.argv
if "--aircraft-only" in sys.argv:
    aircraft()
elif "--vehicles-only" in sys.argv:
    engineer(); armor(); crawler(True); crawler(); armor(True)
    battle_rig(); demolition_buggy(); sam_technical()
elif "--signature-only" in sys.argv:
    battle_rig(); demolition_buggy(); sam_technical()
elif damage_only:
    engineer(); armor(); crawler(True); crawler(); armor(True)
elif motion_only:
    engineer(); armor(); crawler(); armor(True)
else:
    engineer(); ranger(); armor(); crawler(True); crawler(); armor(True); scout(); aircraft()
    battle_rig(); demolition_buggy(); sam_technical()
    command(); barracks(); garage(); airfield(); power(); signals(); garage(True); sentry(); sentry(True)

manifest = []
for name, collection, asset_root in assets:
    bpy.context.view_layer.update()
    for part in collection.objects:
        trim_sheet.prepare(part)
    deps = bpy.context.evaluated_depsgraph_get()
    copies = {}
    for obj in collection.objects:
        clone = bpy.data.objects.new(
            "export_" + obj.name,
            bpy.data.meshes.new_from_object(obj.evaluated_get(deps), depsgraph=deps) if obj.type == "MESH" else None,
        )
        scene.collection.objects.link(clone)
        clone.matrix_world = obj.matrix_world.copy()
        copies[obj] = clone
    for obj, clone in copies.items():
        if obj.parent in copies:
            matrix = clone.matrix_world.copy()
            clone.parent = copies[obj.parent]
            clone.matrix_world = matrix
    groups = {}
    for obj in copies.values():
        if obj.type == "MESH":
            groups.setdefault(obj.parent, []).append(obj)
    for parent, objects in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        joined = bpy.context.object
        modifier = joined.modifiers.new("Triangulate", "TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bm = bmesh.new()
        bm.from_mesh(joined.data)
        degen = [f for f in bm.faces if f.calc_area() < 1e-8]
        if degen:
            bmesh.ops.delete(bm, geom=degen, context="FACES_ONLY")
            bm.to_mesh(joined.data)
        bm.free()
    live = [obj for obj in scene.collection.objects if obj.name.startswith("export_")]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in live:
        obj.select_set(True)
    triangles = sum(len(obj.data.polygons) for obj in live if obj.type == "MESH")
    weathering.bake(live)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / (name + ".glb")), export_format="GLB", use_selection=True,
        export_animations=False, export_yup=True, export_cameras=False, export_lights=False,
        export_vertex_color="ACTIVE",
    )
    for obj in live:
        bpy.data.objects.remove(obj, do_unlink=True)
    points = [obj.matrix_world @ Vector(p) for obj in collection.objects if obj.type == "MESH" for p in obj.bound_box]
    lo = [min(point[i] for point in points) for i in range(3)]
    hi = [max(point[i] for point in points) for i in range(3)]
    manifest.append({"name": name, "triangles": triangles, "file": name + ".glb", "bounds": {"min": lo, "max": hi}})
    collection.hide_render = True

if any(flag in sys.argv for flag in ["--damage-only", "--motion-only", "--walkers-only", "--vehicles-only"]):
    export_manifest.merge_partial(SOURCE / "manifest.json", manifest)
    export_manifest.merge_partial(SOURCE / "signature-manifest.json", manifest)

if damage_only or motion_only or "--models-only" in sys.argv or "--vehicles-only" in sys.argv:
    print("Frontier motion rigs exported" if motion_only else "Material-ready faction models exported")
    raise SystemExit(0)

world = bpy.data.worlds.new("Frontier studio")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (.22, .27, .34, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = .45
for name, loc, power, color in (("Key", (4, 6, 11), 1800, (1, .88, .72)), ("Fill", (-6, 1, 6), 1500, (.7, .83, 1)), ("Rim", (3, -6, 8), 2100, (1, .92, .78))):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = power
    data.shape = "DISK"
    data.size = 7
    data.color = color
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (Vector((0, 0, 1)) - obj.location).to_track_quat("-Z", "Y").to_euler()
camera_data = bpy.data.cameras.new("Camera")
camera = bpy.data.objects.new("Camera", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = "ORTHO"
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_percentage = 100
scene.render.resolution_x = 256
scene.render.resolution_y = 256
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = True
scene.view_settings.view_transform = "AgX"
for name, collection, asset_root in assets:
    collection.hide_render = False
    points = [obj.matrix_world @ Vector(p) for obj in collection.objects if obj.type == "MESH" for p in obj.bound_box]
    lo = Vector([min(p[i] for p in points) for i in range(3)])
    hi = Vector([max(p[i] for p in points) for i in range(3)])
    center = (lo + hi) / 2
    camera.location = center + Vector((9, 12, 10))
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = max(hi - lo) * 1.60
    scene.render.filepath = str(ICONS / (name + ".png"))
    bpy.ops.render.render(write_still=True)
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.film_transparent = False
    scene.render.filepath = str(SOURCE / (name + ".png"))
    bpy.ops.render.render(write_still=True)
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    scene.render.film_transparent = True
    collection.hide_render = True
    manifest[next(i for i, item in enumerate(manifest) if item["name"] == name)]["bounds"] = {"min": list(lo), "max": list(hi)}

if "--aircraft-only" in sys.argv:
    export_manifest.merge_partial(SOURCE / "manifest.json", manifest)
    raise SystemExit(0)

if "--signature-only" in sys.argv:
    (SOURCE / "signature-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    raise SystemExit(0)

for i, (name, collection, asset_root) in enumerate(assets):
    collection.hide_render = False
    bounds = manifest[i]["bounds"]
    factor = 5.8 / max(b - a for a, b in zip(bounds["min"], bounds["max"]))
    asset_root.scale = Vector((factor,) * 3)
    asset_root.rotation_euler = (math.radians(55), 0, math.radians(145))
    bpy.context.view_layer.update()
    points = [obj.matrix_world @ Vector(p) for obj in collection.objects if obj.type == "MESH" for p in obj.bound_box]
    center = Vector([(min(p[k] for p in points) + max(p[k] for p in points)) / 2 for k in range(3)])
    cell = Vector(((i % 4 - 1.5) * 10, (2 - i // 4) * 10, 0))
    asset_root.location = cell - Vector((center.x, center.y, 0))
    asset_root["review_display_scale"] = factor
    asset_root["source_note"] = "Reset root location, rotation and scale for upright metre-scale editing. GLB already uses native coordinates."
    import re
    text_data = bpy.data.curves.new(name + "_Label", "FONT")
    text_data.body = re.sub(r"(?<=[a-z])(?=[A-Z])", " ", name)
    text_data.align_x = "CENTER"
    text_data.size = .49
    label = bpy.data.objects.new(name + "_Label", text_data)
    scene.collection.objects.link(label)
    label.location = cell + Vector((0, -3.9, 3))
    label_material = mat(name + "_LabelInk", (.85, .9, .95), 0, 1, 1)
    text_data.materials.append(label_material)
for obj in scene.objects:
    if obj.type == "LIGHT":
        obj.location *= 6
        obj.data.energy *= 30
        obj.data.size = 35
        obj.rotation_euler = (-obj.location).to_track_quat("-Z", "Y").to_euler()
camera.location = (0, 0, 85)
camera.rotation_euler = (0, 0, 0)
camera_data.ortho_scale = 52
scene.render.film_transparent = False
scene.render.resolution_x = 1900
scene.render.resolution_y = 2200
scene.cycles.samples = 32
scene.render.filepath = str(SOURCE / "faction-catalogue.png")
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "frontier_faction.blend"))
bpy.ops.render.render(write_still=True)

SIGNATURE_NAMES = {"BattleRig", "DemolitionBuggy", "SAMTechnical"}
base_manifest = [item for item in manifest if item["name"] not in SIGNATURE_NAMES]
sig_manifest = [item for item in manifest if item["name"] in SIGNATURE_NAMES]
(SOURCE / "manifest.json").write_text(json.dumps(base_manifest, indent=2) + "\n")
(SOURCE / "signature-manifest.json").write_text(json.dumps(sig_manifest, indent=2) + "\n")
print("Frontier assets complete:", len(base_manifest), "+", len(sig_manifest))
