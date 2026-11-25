"""Rebuild the Helix concept-derived models, editable catalogue, icons and contact renders.

blender --background --factory-startup --python-exit-code 1 --python art/helix/build_faction.py
Append -- --walkers-only to export just the articulated walker GLBs.
Append -- --alignment-only to rebuild the prism pylon and twin-pulse skimmer, including portraits.
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
OUT = ROOT / "assets/models/helix/v1"
ICONS = ROOT / "assets/ui/helix"
SOURCE = ROOT / "art/helix/v1"
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


ARMOR = mat("Helix_Ceramic", (.72, .73, .66), .15, .42)
PANEL = mat("Helix_Secondary", (.42, .48, .46), .25, .48)
DARK = mat("Helix_Graphite", (.025, .043, .050), .6, .4)
STEEL = mat("Helix_Titanium", (.22, .28, .30), .75, .35)
TEAM = mat("TeamColor_Helix", (.015, .23, .25), .25, .42)
RUBBER = mat("Helix_Rubber", (.012, .019, .021), 0, .88)
GLASS = mat("Helix_Optics", (.04, .65, .72), .25, .22, 1.2)
WHITE = ARMOR
ORANGE = mat("Helix_Warning", (.95, .23, .025), .1, .5)
CONCRETE = mat("Helix_Foundation", (.20, .245, .26), 0, .85)
assets = []
current = None
root = None


def begin(name):
    global current, root
    current = bpy.data.collections.new(name)
    scene.collection.children.link(current)
    root = bpy.data.objects.new(name, None)
    current.objects.link(root)
    root["faction"] = "Helix Systems"
    root["forward"] = "-Z in Godot"
    assets.append((name, current, root))
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
    return attach(obj, name, material, parent, bevel)


def cyl(name, xyz, radius, depth, material=DARK, parent=None, axis="Z", vertices=20):
    vertices = max(vertices, 20 if radius >= .15 else 14)
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


def lathe(name, prof, origin, axis_dir, material=DARK, parent=None, segments=24, sharp_angle=36.0):
    return modeling.lathe_profile(
        current.name + "_" + name, prof, origin, axis_dir, segments,
        current, material, parent or root, smooth=True, sharp_angle=sharp_angle,
    )


def wedge(name, x, y, z, width, length, height, material=ARMOR, parent=None):
    return loft(name, [
        modeling.rounded_rect_ring(width, length, min(width, length) * .14, x, y, z, 2),
        modeling.rounded_rect_ring(width * .88, length * .86, min(width, length) * .12, x, y - length * .04, z + height * .55, 2),
        modeling.rounded_rect_ring(width * .72, length * .68, min(width, length) * .10, x, y - length * .08, z + height, 2),
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
    obj = box(name, (Vector(a) + Vector(b)) / 2, (width, depth, delta.length), material, parent, .035)
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
    pts = [
        (x - w * .50, y - l * .30), (x - w * .26, y - l * .50),
        (x + w * .26, y - l * .50), (x + w * .50, y - l * .30),
        (x + w * .50, y + l * .22), (x + w * .24, y + l * .50),
        (x - w * .24, y + l * .50), (x - w * .50, y + l * .22),
    ]
    return prism(name, pts, z, h, material, parent, inset=.82)


def ring(name, center, radius, thickness, material=ARMOR, parent=None, rotation=None):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=32, minor_segments=10, location=center,
        major_radius=radius, minor_radius=thickness,
    )
    obj = bpy.context.object
    if rotation:
        obj.rotation_euler = rotation
    return attach(obj, name, material, parent, smooth=True, sharp_angle=50.0)


def lens(x, y, z, width=.45, parent=None):
    modeling.recessed_viewport(
        current.name + "_Optic", (x, y, z), width, max(.09, width * .24), .16,
        (0, 1, 0), current, DARK, GLASS, parent or root,
    )


def vent(x, y, z, width=.8, length=.6, parent=None):
    modeling.louver_grille(
        current.name + "_Vent", (x, y, z), width, length, 5,
        current, DARK, STEEL, parent or root,
    )


def antenna(x, y, z, parent=None):
    cyl("AntennaBase", (x, y, z + .06), .09, .12, DARK, parent, vertices=14)
    rod("Antenna", (x, y, z), (x, y, z + .72), .018, STEEL, parent, vertices=10)


def warning(x, y, z, parent=None):
    box("Warning", (x, y, z), (.15, .035, .12), ORANGE, parent, .005)


def gun(turret_z, length=2.3, parent=None, rail=False):
    barrel = pivot("BarrelPivot", (0, .45, turret_z), parent)
    if rail:
        for side in (-1, 1):
            shell("AcceleratorRail", side * .25, 1.6, turret_z - .11, .26, 3.3, .29, ARMOR, barrel)
            box("RailInner", (side * .13, 1.6, turret_z + .025), (.025, 2.8, .07), GLASS, barrel, .005)
            box("RailMuzzle", (side * .25, 3.19, turret_z + .02), (.32, .28, .36), DARK, barrel, .025)
        pivot("Muzzle", (0, 3.38, turret_z), barrel)
    else:
        box("GunMantlet", (0, .59, turret_z), (.56, .68, .40), ARMOR, barrel, .07)
        lathe("GunBarrel", [
            (.11, .82), (.11, 1.15), (.08, 1.20), (.08, .85 + length * .65),
            (.065, .88 + length * .65), (.065, .90 + length),
        ], (0, 0, turret_z), (0, 1, 0), STEEL, barrel, segments=20)
        lathe("MuzzleBrake", [
            (.105, .90 + length), (.11, 1.05 + length), (.09, 1.08 + length),
        ], (0, 0, turret_z), (0, 1, 0), DARK, barrel, segments=18)
        pivot("Muzzle", (0, 1.10 + length, turret_z), barrel)
    return barrel


def wheels(width=2.3, length=3.0, r=.48):
    for side in (-1, 1):
        for index, y in enumerate((-length * .38, 0, length * .38)):
            wheel = pivot("Wheel_%s_%s" % (side, index), (side * width * .5, y, r + .02))
            modeling.detailed_wheel(
                current.name + f"_Wheel_{side}_{index}", (side * width * .5, y, r + .02),
                r, .38, side, current, RUBBER, STEEL, TEAM, wheel, segments=22, lug_count=12,
            )
        loft("Fender", [
            modeling.rounded_rect_ring(.48, length * .96, .10, side * width * .5, 0, r * 2 + .04, 2),
            modeling.rounded_rect_ring(.42, length * .90, .08, side * width * .5, 0, r * 2 + .20, 2),
        ], ARMOR, bevel=.025)


def manipulator(x, y, z, side, parent=None):
    arm = pivot("ToolArmLeft" if side < 0 else "ToolArmRight", (x, y, z), parent)
    a = (x, y, z)
    b = (x + side * .24, y + .45, z - .30)
    c = (x + side * .14, y + .95, z - .60)
    cyl("ShoulderJoint", a, .16, .22, DARK, arm, axis="X", vertices=18)
    beam("ToolUpper", a, b, .19, .23, ARMOR, arm)
    beam("ToolForearm", b, c, .13, .17, STEEL, arm)
    cyl("ToolElbow", b, .16, .25, DARK, arm, axis="X", vertices=18)
    cyl("ToolWrist", c, .10, .14, DARK, arm, axis="X", vertices=14)
    for dx in (-.11, .11):
        modeling.sweep_tube(
            current.name + f"_Claw_{side}_{dx:.2f}",
            [(c[0] + dx, c[1], c[2]), (c[0] + dx, c[1] + .16, c[2] - .05), (c[0] + dx * .5, c[1] + .28, c[2] - .16)],
            .034, 8, current, DARK, arm,
        )


def legs(height=2.1, spread=1.6):
    for side in (-1, 1):
        for front in (-1, 1):
            leg = pivot(("LegLeft" if side < 0 else "LegRight") + ("Front" if front > 0 else "Rear"), (side * .64, front * .58, height))
            hip = (side * .64, front * .58, height)
            knee = (side * 1.04, front * .93, height * .58)
            foot = (side * spread, front * 1.23, .20)
            cyl("HipJoint", hip, .20, .28, DARK, leg, axis="X", vertices=20)
            beam("UpperLeg", hip, knee, .30, .28, ARMOR, leg)
            lower = pivot("KneePivot", knee, leg)
            cyl("KneeJoint", knee, .19, .32, DARK, lower, axis="X", vertices=20)
            beam("LowerLeg", knee, foot, .23, .24, ARMOR, lower)
            beam("LegInset", Vector(knee) + Vector((side * .13, 0, -.10)), Vector(foot) + Vector((side * .13, 0, .18)), .04, .13, TEAM, lower)
            rod("Actuator", Vector(knee) + Vector((0, -.14, 0)), Vector(foot) + Vector((0, -.14, .08)), .048, STEEL, lower, vertices=12)
            ankle = pivot("AnklePivot", foot, lower)
            loft("Foot", [
                modeling.rounded_rect_ring(.50, .58, .12, foot[0], foot[1] + .06, .01, 2),
                modeling.rounded_rect_ring(.38, .44, .10, foot[0], foot[1] + .04, .21, 2),
            ], DARK, ankle, bevel=.02)


def operator():
    begin("VectorOperator")
    for side in (-1, 1):
        leg = pivot("LegLeft" if side < 0 else "LegRight", (side * .17, 0, 1.04))
        loft("Thigh", [
            modeling.ellipse_ring(.11, .13, side * .19, .01, .59, 12),
            modeling.ellipse_ring(.13, .14, side * .17, 0, .98, 12),
        ], ARMOR, leg)
        cyl("Knee", (side * .19, .02, .57), .12, .26, DARK, leg, axis="X", vertices=16)
        loft("Shin", [
            modeling.ellipse_ring(.10, .11, side * .21, .04, .18, 12),
            modeling.ellipse_ring(.11, .12, side * .19, 0, .51, 12),
        ], ARMOR, leg)
        box("KneePlate", (side * .19, .17, .58), (.21, .08, .23), TEAM, leg, .03)
        loft("Boot", [
            modeling.rounded_rect_ring(.25, .40, .07, side * .21, .09, .01, 2),
            modeling.rounded_rect_ring(.22, .32, .06, side * .21, .05, .17, 2),
        ], DARK, leg, bevel=.02)
    shell("Pelvis", 0, 0, .97, .52, .33, .22, DARK)
    shell("Vest", 0, 0, 1.17, .72, .43, .49, ARMOR)
    box("ChestInset", (0, .22, 1.44), (.32, .04, .24), TEAM, bevel=.015)
    box("Backpack", (0, -.29, 1.40), (.43, .20, .38), DARK, bevel=.04)
    for side in (-1, 1):
        box("Shoulder", (side * .40, 0, 1.58), (.23, .33, .26), ARMOR, bevel=.06)
        box("ShoulderID", (side * .525, 0, 1.59), (.025, .22, .17), TEAM, bevel=.005)
        loft("UpperArm", [
            modeling.ellipse_ring(.09, .09, side * .40, 0, 1.49, 10),
            modeling.ellipse_ring(.08, .08, side * .41, .18, 1.23, 10),
        ], DARK)
        loft("Forearm", [
            modeling.ellipse_ring(.09, .09, side * .41, .18, 1.23, 10),
            modeling.ellipse_ring(.08, .08, side * .14, .43, 1.26, 10),
        ], ARMOR)
        box("Glove", (side * .14, .43, 1.26), (.15, .15, .15), DARK, bevel=.03)
    cyl("Neck", (0, 0, 1.74), .11, .17, DARK, vertices=14)
    loft("Helmet", [
        modeling.ellipse_ring(.21, .23, 0, 0, 1.76, 16),
        modeling.ellipse_ring(.22, .24, 0, 0, 1.94, 16),
        modeling.ellipse_ring(.18, .19, 0, -.02, 2.10, 16),
    ], ARMOR)
    lens(0, .19, 1.96, .31)
    box("Rifle", (.11, .46, 1.36), (.15, .52, .17), DARK, bevel=.03)
    cyl("RifleBarrel", (.11, .91, 1.38), .033, .47, STEEL, axis="Y", vertices=12)
    pivot("Muzzle", (.11, 1.16, 1.38))
    antenna(-.25, -.25, 1.57)


def mule():
    begin("MuleEngineer")
    for side in (-1, 1):
        for y in (-.97, .97):
            lathe(f"FluxLiftDuct_{side}_{y}", [
                (.32, -.18), (.45, -.16), (.47, 0.0), (.42, .20), (.32, .20),
            ], (side * 1.04, y, .35), (0, 0, 1), DARK, segments=24)
            ring("FluxRepulsorBand", (side * 1.04, y, .15), .40, .045, GLASS)
        loft("FluxPontoon", [
            modeling.rounded_rect_ring(.62, 2.75, .18, side * 1.02, 0, .42, 2),
            modeling.rounded_rect_ring(.68, 2.90, .20, side * 1.02, 0, .62, 2),
            modeling.rounded_rect_ring(.56, 2.60, .16, side * 1.02, 0, .88, 2),
        ], ARMOR, bevel=.025)
        shell("FluxPontoonID", side * 1.02, -.05, .89, .43, 1.6, .035, TEAM)
    shell("Chassis", 0, 0, .62, 2.15, 3.0, .48, DARK)
    shell("Cab", 0, .65, 1.0, 1.7, 1.45, .57)
    for side in (-1, 1):
        shell("ShoulderPanel", side * .84, .43, 1.17, .5, 1.40, .27, TEAM)
        manipulator(side * .59, 1.15, 1.13, side)
    lens(0, 1.29, 1.37, .66)
    box("CargoTray", (0, -.82, 1.12), (1.68, 1.20, .18), STEEL, bevel=.03)
    for x in (-.42, .42):
        box("CargoModule", (x, -.85, 1.48), (.67, 1.03, .57), DARK, bevel=.06)
        for y in (-1.18, -.53):
            box("CargoBand", (x, y, 1.78), (.7, .10, .04), TEAM, bevel=.01)
    antenna(-.74, -1.13, 1.38)


def needle():
    begin("NeedleSkimmer")
    # Sleek twin-pontoon hover tank matching Helix concept art
    for side in (-1, 1):
        for y in (-1.15, 1.20):
            lathe(f"LiftDuct_{side}_{y}", [
                (.38, -.18), (.53, -.16), (.55, 0.0), (.48, .22), (.36, .22),
            ], (side * 1.06, y, .33), (0, 0, 1), DARK, segments=24)
            ring("LiftBand", (side * 1.06, y, .18), .47, .038, GLASS)
        loft("Pontoon", [
            modeling.rounded_rect_ring(1.16, 4.15, .36, side * 1.02, .05, .44, 3),
            modeling.rounded_rect_ring(1.30, 4.45, .40, side * 1.02, .05, .68, 3),
            modeling.rounded_rect_ring(1.12, 4.00, .34, side * 1.02, -.02, .98, 3),
            modeling.rounded_rect_ring(.88, 3.25, .26, side * 1.02, -.10, 1.21, 3),
        ], ARMOR, bevel=.025)
        shell("PontoonID", side * 1.02, -.08, 1.21, .77, 2.75, .035, TEAM)
        lens(side * 1.02, 2.18, .72, .42)
        vent(side * 1.02, -1.25, 1.21, .56, .46)
        modeling.sweep_tube(current.name + f"_FluxTube_{side}", [(side * 1.56, -.95, .72), (side * 1.62, 0.0, .72), (side * 1.56, .95, .72)], .045, 10, current, GLASS, root)
        modeling.era_tile_rack(current.name + f"_PontoonPlate_{side}", (side * 1.66, -1.10, .86), (side * 1.66, .90, .86), (side, 0, .2), 4, (.36, .05, .20), current, PANEL, DARK, root)
    shell("BridgeHull", 0, -.43, .78, 1.26, 2.9, .41, DARK)
    cyl("TurretBearing", (0, -.38, 1.28), .65, .16, STEEL, vertices=28)
    turret = pivot("TurretPivot", (0, -.38, 1.39))
    loft("Turret", [
        modeling.rounded_rect_ring(1.38, 1.56, .34, 0, -.34, 1.35, 3),
        modeling.rounded_rect_ring(1.32, 1.46, .32, 0, -.38, 1.64, 3),
        modeling.rounded_rect_ring(1.04, 1.16, .24, 0, -.42, 1.88, 3),
    ], ARMOR, turret, bevel=.025)
    box("TurretID", (0, -.44, 1.90), (.49, .67, .035), TEAM, turret, .01)
    barrel = pivot("BarrelPivot", (0, .45, 1.66), turret)
    for side in (-1, 1):
        emitter = pivot("PulseEmitterLeft" if side < 0 else "PulseEmitterRight", (side * .36, .9, 1.66), barrel)
        loft("PulseHousing", [
            modeling.rounded_rect_ring(.34, 1.32, .10, side * .36, .90, 1.53, 2),
            modeling.rounded_rect_ring(.36, 1.38, .10, side * .36, .90, 1.67, 2),
            modeling.rounded_rect_ring(.28, 1.24, .08, side * .36, .86, 1.82, 2),
        ], ARMOR, emitter, bevel=.02)
        box("PulseCapacitor", (side * .36, .68, 1.70), (.16, .62, .12), DARK, emitter, .02)
        for y in (.47, .65, .83):
            box("PulseChargeBand", (side * .36, y, 1.78), (.18, .055, .035), GLASS, emitter, .008)
        lathe("EmitterCollar", [
            (.11, -.08), (.145, -.05), (.145, .06), (.115, .09),
        ], (side * .36, 1.58, 1.68), (0, 1, 0), STEEL, emitter, segments=20)
        cyl("PulseLens", (side * .36, 1.67, 1.68), .112, .03, GLASS, emitter, axis="Y", vertices=18)
        pivot("LeftMuzzle" if side < 0 else "RightMuzzle", (side * .36, 1.70, 1.68), emitter)
    lens(0, .49, 1.90, .22, turret)
    modeling.cupola_hatch(current.name + "_Hatch", (-.34, -.32, 1.88), .22, .12, current, PANEL, DARK, GLASS, turret)
    modeling.sensor_pod(current.name + "_FCS", (.42, .20, 1.90), .75, (0, 1, 0), current, DARK, GLASS, STEEL, turret)
    antenna(-.52, -.83, 1.86, turret)


def walker(repair=False):
    begin("MenderRobot" if repair else "LancerWalker")
    h = 1.22 if repair else 2.0
    legs(h, 1.32 if repair else 1.56)
    loft("Body", [
        modeling.rounded_rect_ring(1.56, 1.66, .34, 0, 0, h - .12, 3),
        modeling.rounded_rect_ring(1.66, 1.76, .36, 0, 0, h + .20, 3),
        modeling.rounded_rect_ring(1.36, 1.44, .28, 0, -.04, h + .52, 3),
    ], ARMOR, bevel=.03)
    for side in (-1, 1):
        box("SideID", (side * .79, -.07, h + .24), (.04, .70, .26), TEAM, bevel=.01)
        modeling.era_tile_rack(current.name + f"_FlankArmor_{side}", (side * .82, -.52, h + .22), (side * .82, .42, h + .22), (side, 0, .15), 3, (.26, .06, .24), current, PANEL, DARK, root)
    lens(0, .78, h + .27, .68)
    vent(0, -.34, h + .52)
    modeling.hvac_fan_unit(current.name + "_CoreCooler", (0, -.55, h + .26), .68, .42, .48, current, PANEL, DARK, STEEL, root)
    if repair:
        for side in (-1, 1):
            manipulator(side * .74, .63, h + .18, side)
        box("ServiceChevronA", (-.11, .87, h + .03), (.08, .03, .17), TEAM, rot=(0, -.5, 0))
        box("ServiceChevronB", (.11, .87, h + .03), (.08, .03, .17), TEAM, rot=(0, .5, 0))
    else:
        turret = pivot("TurretPivot", (0, -.14, h + .66))
        loft("GunPod", [
            modeling.rounded_rect_ring(1.24, 1.54, .28, 0, -.09, h + .58, 2),
            modeling.rounded_rect_ring(1.28, 1.59, .28, 0, -.09, h + .84, 2),
            modeling.rounded_rect_ring(1.04, 1.30, .22, 0, -.12, h + 1.08, 2),
        ], ARMOR, turret, bevel=.025)
        gun(h + .85, 1.65, turret)
        antenna(-.48, -.70, h + 1.07, turret)


def kite():
    begin("KiteScout")
    prism("TriangleFrame", [(-1.55, -1.12), (1.55, -1.12), (0, 2.05)], .42, .18, DARK)
    for index, (x, y) in enumerate(((0, 1.02), (-1.0, -.68), (1.0, -.68))):
        modeling.ducted_shroud(
            current.name + f"_Duct_{index}", (x, y, .60), .64, .24, .11,
            current, ARMOR, DARK, STEEL, root, segments=28,
        )
        fan = pivot("Rotor%d" % index, (x, y, .58))
        modeling.pitched_rotor(current.name + f"_Fan_{index}", (x, y, .58), .50, 3, current, TEAM, DARK, fan, axis="Z")
    prism("Spine", [(-.32, -1.02), (.32, -1.02), (.24, .52), (0, 1.99), (-.24, .52)], .68, .14, ARMOR)
    prism("SpineID", [(-.22, -.83), (.22, -.83), (.14, .16), (-.14, .16)], .83, .025, TEAM)
    lens(0, 1.90, .61, .22)
    for side in (-1, 1):
        rod("LandingFoot", (side * .57, -.53, .48), (side * .57, -.53, .05), .045, STEEL)


def wraith():
    begin("WraithStriker")
    shell("Fuselage", 0, .10, .45, 1.2, 4.55, .43)
    for side in (-1, 1):
        modeling.airfoil_wing(
            current.name + "_SweptWing", (side * .42, .10), (side * 3.40, -1.18),
            2.40, .62, .56, .52, .18, .08, current, ARMOR, root, bevel=.015,
        )
        prism("WingID", [(side * .93, .63), (side * 2.97, -.96), (side * 1.65, -.86)], .66, .025, TEAM)
        lathe("Engine", [
            (.24, -.90), (.31, -.80), (.32, .75), (.26, .90),
        ], (side * .68, -.86, .67), (0, 1, 0), DARK, segments=22)
        cyl("Exhaust", (side * .68, -1.80, .67), .245, .10, STEEL, axis="Y", vertices=22)
        cyl("ExhaustCore", (side * .68, -1.86, .67), .16, .025, GLASS, axis="Y", vertices=18)
        shell("EngineCowl", side * .66, -.3, .61, .76, 1.42, .39)
        shape("TailFin", [(side * .75, -.53, .8), (side * 1.22, -1.0, 1.78), (side * 1.45, -1.55, 1.65), (side * 1.03, -.48, .77)],
              [(0, 1, 2, 3)], TEAM, bevel=0, smooth=False)
        for dx in (-.15, .15):
            cyl("Missile", (side * 1.44 + dx, -.36, .32), .11, .98, DARK, axis="Y", vertices=14)
            lathe("MissileTip", [(.09, 0), (.09, .03), (0, .12)], (side * 1.44 + dx, .14, .32), (0, 1, 0), ORANGE, segments=14)
    prism("Canopy", [(-.31, .21), (.31, .21), (.18, 1.31), (0, 1.61), (-.18, 1.31)], .91, .08, TEAM)
    lens(0, 2.06, .56, .27)
    pivot("Muzzle", (0, 2.2, .53))


def prism_artillery():
    begin("PrismArtillery")
    wheels(2.4, 3.6, .52)
    shell("Chassis", 0, 0, .72, 2.50, 3.93, .51)
    for side in (-1, 1):
        shell("SidePod", side * .99, -.44, 1.23, .63, 2.16, .40, TEAM)
        for front in (-1, 1):
            arm = pivot("Stabilizer_%d_%d" % (side, front), (side * 1.05, front * 1.3, 1.15))
            beam("Stabilizer", (side * 1.05, front * 1.3, 1.15), (side * 1.80, front * 1.65, .18), .20, .22, ARMOR, arm)
            box("StabilizerFoot", (side * 1.80, front * 1.65, .11), (.47, .49, .20), DARK, arm, .035)
    cyl("Bearing", (0, -.43, 1.39), .72, .23, DARK, vertices=28)
    turret = pivot("TurretPivot", (0, -.43, 1.53))
    shell("AcceleratorHousing", 0, -.43, 1.47, 1.44, 1.47, .66, ARMOR, turret)
    barrel = gun(1.88, parent=turret, rail=True)
    barrel.rotation_euler.x = math.radians(14)
    modeling.cupola_hatch(current.name + "_Hatch", (-.38, -.45, 2.13), .24, .12, current, PANEL, DARK, GLASS, turret)
    modeling.sensor_pod(current.name + "_Optics", (.48, .12, 2.13), .80, (0, 1, 0), current, DARK, GLASS, STEEL, turret)
    for side in (-1, 1):
        modeling.era_tile_rack(current.name + f"_SideShield_{side}", (side * .76, -.92, 1.78), (side * .76, .08, 1.78), (side, 0, 0), 3, (.28, .06, .28), current, PANEL, DARK, turret)
    lens(0, 1.76, 1.13, .60)
    antenna(-.91, -1.23, 1.60)


def foundation(name, w=5, l=5):
    begin(name)
    shell("Foundation", 0, 0, .02, w, l, .22, CONCRETE)
    shell("Deck", 0, 0, .24, w * .94, l * .94, .12, DARK)
    for side in (-1, 1):
        box("Guide", (side * w * .35, .2, .375), (.06, l * .61, .025), TEAM, bevel=0)


def hexblock(name, x, y, z, r, h, material=ARMOR, parent=None):
    pts = [(x + math.cos(i * math.tau / 6 + math.pi / 6) * r, y + math.sin(i * math.tau / 6 + math.pi / 6) * r) for i in range(6)]
    return prism(name, pts, z, h, material, parent, .85)


def door(x, y, z, w=.9, h=1.0):
    box("PortalFrame", (x, y, z + h * .5), (w + .26, .24, h + .14), STEEL, bevel=.02)
    box("PortalOpening", (x, y + .05, z + h * .46), (w, .16, h), DARK, bevel=.015)
    box("PortalLintle", (x, y + .08, z + h + .04), (w * .85, .10, .10), TEAM, bevel=.01)
    box("PortalGlow", (x, y + .11, z + .10), (w * .75, .04, .06), GLASS, bevel=0)


def curved_pylon(x, y, z, h=4.4, tilt_x=0.0, tilt_y=0.0, scale=1.0):
    """Swept crescent blade-pylon arching smoothly upward."""
    pts0 = [(-.42 * scale, -.48 * scale), (.42 * scale, -.48 * scale), (.36 * scale, .48 * scale), (-.36 * scale, .48 * scale)]
    rings = []
    for t in (0.0, 0.35, 0.72, 1.0):
        s = (1.0 - t * 0.72)
        ox = x + tilt_x * (t ** 1.45)
        oy = y + tilt_y * (t ** 1.45)
        oz = z + h * t
        rings.append([(ox + px * s, oy + py * s, oz) for px, py in pts0])
    loft("CurvedBladePylon", rings, ARMOR, bevel=.02)
    beam("BladeTrim", (x + tilt_x * .25, y + tilt_y * .25 + .22 * scale, z + h * .20),
         (x + tilt_x * .88, y + tilt_y * .88 + .10 * scale, z + h * .88), .14 * scale, .04, TEAM)
    cyl("BladeEmitter", (x + tilt_x, y + tilt_y, z + h + .08), .07 * scale, .16, GLASS, vertices=14)


def nexus():
    # Wide terraced crescent sci-fi citadel with sweeping inward-arching blade wings
    foundation("NexusHQ", 6.8, 6.0)
    loft("TerraceBase", [
        modeling.ellipse_ring(2.95, 2.35, 0, -.10, .36, 12),
        modeling.ellipse_ring(2.55, 2.05, 0, -.15, 1.15, 12),
        modeling.ellipse_ring(2.05, 1.65, 0, -.25, 1.78, 12),
    ], ARMOR, bevel=.025)
    ring("CyanEnergyRing", (0, -.15, 1.20), 2.32, .055, GLASS)
    lathe("CommandDome", [
        (1.48, 1.78), (1.56, 2.05), (1.35, 2.52), (0.95, 2.86), (0.0, 3.00),
    ], (0, -.30, 0), (0, 0, 1), DARK, segments=18, sharp_angle=35.0)
    lathe("DomeCrown", [
        (1.42, 2.48), (1.52, 2.60), (1.10, 2.88), (0.0, 3.04),
    ], (0, -.30, 0), (0, 0, 1), ARMOR, segments=18, sharp_angle=35.0)
    ring("ObservationGlow", (0, -.30, 2.28), 1.48, .06, GLASS)
    for side in (-1, 1):
        # Sweeping splayed wing pods + inward-curving monumental blade pylons
        loft("WingPod", [
            modeling.rounded_rect_ring(1.25, 2.65, .36, side * 2.15, .45, .36, 3),
            modeling.rounded_rect_ring(1.05, 2.25, .30, side * 2.00, .40, 1.05, 3),
        ], PANEL, bevel=.02)
        box("WingGlow", (side * 2.00, .40, 1.08), (.34, 1.45, .04), TEAM, bevel=.01)
        curved_pylon(side * 2.45, -1.05, .36, 4.9, tilt_x=-side * .78, tilt_y=.45, scale=1.08)
    door(0, 1.98, .36, 1.15, 1.38)
    modeling.sensor_pod(current.name + "_GateSensor", (0, 1.78, 1.95), 1.0, (0, 1, 0), current, DARK, GLASS, STEEL, root)
    for side in (-1, 1):
        modeling.hvac_fan_unit(current.name + f"_TerraceVent_{side}", (side * 1.85, -.85, 1.12), .68, .68, .28, current, PANEL, DARK, STEEL, root)
        modeling.sweep_tube(current.name + f"_ArcConduit_{side}", [(side * 1.48, -.30, 1.82), (side * 2.05, -.65, 1.82), (side * 2.45, -1.05, .85)], .07, 10, current, GLASS, root)
    antenna(0, -.30, 3.06)


def operator_hub():
    # V-splayed futuristic barracks wings connected by an elevated glowing skybridge
    foundation("OperatorHub", 6.2, 4.8)
    for side in (-1, 1):
        wing = pivot("Wing" + ("L" if side < 0 else "R"), (side * 1.75, 0, .36))
        wing.rotation_euler.z = side * math.radians(22)
        loft("HabitatWing", [
            modeling.rounded_rect_ring(1.65, 3.55, .42, side * 1.75, 0, .36, 3),
            modeling.rounded_rect_ring(1.50, 3.25, .38, side * 1.75, 0, 1.15, 3),
            modeling.rounded_rect_ring(1.05, 2.55, .28, side * 1.75, -.08, 1.82, 3),
        ], ARMOR, wing, bevel=.025)
        box("WindowBand", (side * 1.75, 1.45, 1.15), (.98, .05, .22), GLASS, wing, .01)
        box("WingStripe", (side * 1.75, -.10, 1.84), (.46, 1.95, .04), TEAM, wing, .01)
        vent(side * 1.75, -.75, 1.84, .85, .85, wing)
    loft("SkyBridge", [
        modeling.rounded_rect_ring(2.85, .82, .20, 0, -.35, 1.52, 2),
        modeling.rounded_rect_ring(2.75, .72, .18, 0, -.35, 1.94, 2),
    ], DARK, bevel=.02)
    box("BridgeGlow", (0, .06, 1.74), (2.25, .04, .12), GLASS, bevel=.005)
    loft("CentralPortal", [
        modeling.rounded_rect_ring(1.45, 1.65, .36, 0, .80, .36, 3),
        modeling.rounded_rect_ring(1.15, 1.30, .28, 0, .75, 1.15, 3),
    ], PANEL, bevel=.02)
    door(0, 1.55, .36, .84, .82)


def foundry():
    # Twin inward-arching parabolic blade-gantries over a circular glowing fabrication ring
    foundation("RoboticsFoundry", 6.6, 5.8)
    cyl("FabPad", (0, .15, .40), 2.05, .14, DARK, vertices=32)
    ring("FabRing", (0, .15, .49), 1.65, .055, GLASS)
    ring("FabOuterRing", (0, .15, .49), 1.95, .04, TEAM)
    for side in (-1, 1):
        curved_pylon(side * 2.55, -.25, .36, 4.85, tilt_x=-side * 1.35, tilt_y=0.0, scale=1.18)
        manipulator(side * .88, -.15, 4.35, side)
    loft("FabCrown", [
        modeling.rounded_rect_ring(2.90, 1.05, .28, 0, -.25, 4.55, 2),
        modeling.rounded_rect_ring(2.50, .85, .22, 0, -.25, 5.10, 2),
    ], DARK, bevel=.02)
    box("CrownGlow", (0, .28, 4.78), (2.20, .06, .12), GLASS, bevel=.01)


def flightdeck():
    foundation("FlightDeck", 7.1, 6.7)
    hexblock("LandingPad", 0, .3, .34, 2.85, .23, DARK)
    ring("LandingRing", (0, .3, .59), 2.04, .045, GLASS)
    for x in (-.4, .4):
        box("LandingMark", (x, .3, .59), (.10, 1.22, .02), ARMOR, bevel=0)
    box("LandingCrossbar", (0, .3, .59), (.90, .10, .02), ARMOR, bevel=0)
    for side in (-1, 1):
        curved_pylon(side * 2.68, -1.68, .36, 2.85, tilt_x=-side * .35, tilt_y=.25, scale=.85)
    lathe("ControlTower", [
        (.72, .36), (.58, 1.55), (.86, 1.72), (.86, 2.18), (.96, 2.24), (.60, 2.42), (0, 2.45),
    ], (0, -2.26, 0), (0, 0, 1), ARMOR, segments=16)
    cyl("ControlGlass", (0, -2.26, 1.95), .87, .36, GLASS, vertices=16)
    antenna(0, -2.26, 2.45)


def flux():
    foundation("FluxGenerator", 5.0, 4.8)
    ring("ManifoldRing", (0, -.15, .58), 1.48, .09, DARK)
    ring("ManifoldGlow", (0, -.15, .64), 1.48, .035, GLASS)
    for idx, (x, y, h) in enumerate(((-1.25, .45, 3.0), (1.25, .45, 3.0), (0, -1.18, 3.85))):
        cyl(f"CoreFoot_{idx}", (x, y, .52), .62, .30, DARK, vertices=24)
        lathe(f"PowerCore_{idx}", [
            (.38, 1.0), (.44, 1.08 + h * .10), (.44, 1.00 + h * .55), (.38, 1.00 + h * .65),
        ], (x, y, 0), (0, 0, 1), GLASS, segments=24)
        for z in (.75, h + .36):
            cyl(f"CoreCollar_{idx}", (x, y, z), .58, .36, ARMOR, vertices=24)
        # 3 radial swept ceramic fin-buttresses per core
        for k in range(3):
            a = k * math.tau / 3.0 + math.pi / 6.0
            cx, cy = x + math.cos(a) * .56, y + math.sin(a) * .56
            curved_pylon(cx, cy, .42, h * .85, tilt_x=-math.cos(a) * .16, tilt_y=-math.sin(a) * .16, scale=.38)
        cyl(f"CoreCap_{idx}", (x, y, h + .63), .44, .16, DARK, vertices=24)
    shell("ControlBox", 0, 1.32, .36, 1.08, 1.05, .82, TEAM)
    lens(0, 1.76, .88, .41)


def signal_lab():
    # Smooth curved dome sanctuary + giant tilted holographic ring interferometer
    foundation("SignalLab", 5.7, 5.3)
    lathe("DomeBase", [
        (2.15, .36), (2.22, .68), (1.92, 1.35), (1.42, 1.82), (0.85, 2.00), (0, 2.02),
    ], (0, .06, 0), (0, 0, 1), ARMOR, segments=24, sharp_angle=38.0)
    ring("DomeGlow", (0, .06, 1.36), 1.92, .045, GLASS)
    door(0, 2.08, .36, .92, 1.13)
    for side in (-1, 1):
        curved_pylon(side * 2.08, -.45, .36, 2.95, tilt_x=-side * .28, tilt_y=.15, scale=.82)
    radar = pivot("SensorPivot", (0, -.15, 2.15))
    ring("SensorRing", (0, -.15, 3.25), 1.38, .11, ARMOR, radar, (math.radians(-38), 0, 0))
    ring("SignalTrace", (0, -.15, 3.25), 1.24, .035, GLASS, radar, (math.radians(-38), 0, 0))
    center = Vector((0, -.15, 3.25))
    for angle in (0, math.tau / 3, math.tau * 2 / 3):
        offset = Vector((math.cos(angle) * 1.30, math.sin(angle) * 1.30 * math.cos(math.radians(38)), -math.sin(angle) * 1.30 * math.sin(math.radians(38))))
        rod("SensorSpoke", center, center + offset, .047, STEEL, radar, vertices=10)
    shape("CenterPrism", [
        (0, -.15, 3.65), (-.22, -.37, 3.25), (.22, -.37, 3.25), (.22, .07, 3.25), (-.22, .07, 3.25), (0, -.15, 2.85),
    ], [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1), (5, 2, 1), (5, 3, 2), (5, 4, 3), (5, 1, 4)], GLASS, radar, smooth=False)
    beam("DishSupport", (0, -.15, 1.95), center, .22, .24, STEEL)


def service():
    # Radial 3-pylon nanite cradle around a circular cyan repair ring (zero rectangular towers)
    foundation("ServiceCradle", 5.8, 5.4)
    cyl("NanitePad", (0, .10, .40), 2.10, .14, DARK, vertices=32)
    ring("NaniteRing", (0, .10, .50), 1.65, .055, GLASS)
    ring("NaniteOuter", (0, .10, .50), 1.98, .04, TEAM)
    for idx, angle in enumerate((math.radians(150), math.radians(30), math.radians(-90))):
        px, py = math.cos(angle) * 2.25, .10 + math.sin(angle) * 2.25
        curved_pylon(px, py, .36, 3.25, tilt_x=-math.cos(angle) * .85, tilt_y=-math.sin(angle) * .85, scale=.92)
        if idx < 2:
            side = -1 if px < 0 else 1
            arm_name = "RepairArmLeft" if side < 0 else "RepairArmRight"
            tip_x, tip_y = px - math.cos(angle) * .72, py - math.sin(angle) * .72
            arm = pivot(arm_name, (tip_x, tip_y, 3.15))
            beam("ServiceUpper", (tip_x, tip_y, 3.15), (tip_x * .52, tip_y * .52, 2.45), .24, .26, ARMOR, arm)
            beam("ServiceForearm", (tip_x * .52, tip_y * .52, 2.45), (tip_x * .30, tip_y * .30, 1.55), .15, .18, STEEL, arm)
            cyl("ServiceElbow", (tip_x * .52, tip_y * .52, 2.45), .20, .30, DARK, arm, axis="X", vertices=18)
            cyl("EmitterTip", (tip_x * .30, tip_y * .30, 1.50), .12, .18, GLASS, arm, vertices=16)


def lance():
    # 4 splayed spider-legs lifting an elevated prism emitter pod
    foundation("LanceSentry", 4.1, 4.1)
    cyl("CentralPillar", (0, 0, 1.28), .44, 1.85, DARK, vertices=24)
    for angle in (math.radians(45), math.radians(135), math.radians(225), math.radians(315)):
        foot = Vector((math.cos(angle) * 1.72, math.sin(angle) * 1.72, .42))
        beam("Outrigger", (math.cos(angle) * .42, math.sin(angle) * .42, 1.85), foot, .30, .34, ARMOR)
        box("OutriggerFoot", foot, (.52, .52, .14), DARK, bevel=.03)
        beam("PowerConduit", (math.cos(angle) * .48, math.sin(angle) * .48, .62),
             (math.cos(angle) * .48, math.sin(angle) * .48, 2.00), .07, .07, GLASS)
    cyl("TurretRing", (0, 0, 2.15), .72, .20, STEEL, vertices=24)
    turret = pivot("TurretPivot", (0, 0, 2.29))
    cyl("PrismCradle", (0, 0, 2.34), .62, .22, ARMOR, turret, vertices=16)
    crystal = pivot("PrismCrystal", (0, 0, 3.02), turret)
    shape("FacetedCrystal", [(0, 0, 3.78), (-.32, -.32, 3.15), (.32, -.32, 3.15),
          (.32, .32, 3.15), (-.32, .32, 3.15), (0, 0, 2.48)],
          [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1), (5, 2, 1), (5, 3, 2), (5, 4, 3), (5, 1, 4)],
          GLASS, crystal, smooth=False)
    for side in (-1, 1):
        beam("CrownArm", (side * .63, -.12, 2.36), (side * .67, -.12, 3.35), .18, .24, ARMOR, turret)
        box("CrownID", (side * .67, .015, 3.02), (.10, .028, .36), TEAM, turret, .008)
        rod("FocusBrace", (side * .67, -.12, 3.35), (side * .35, .45, 3.09), .055, STEEL, turret, vertices=12)
    focus = pivot("PrismFocus", (0, .48, 3.09), turret)
    cyl("FocusCollar", (0, .48, 3.09), .24, .18, DARK, focus, axis="Y", vertices=18)
    cyl("FocusLens", (0, .58, 3.09), .18, .025, GLASS, focus, axis="Y", vertices=18)
    pivot("Muzzle", (0, .61, 3.09), focus)


def skyward():
    foundation("SkywardArray", 4.5, 4.1)
    lathe("Base", [
        (1.75, .36), (1.65, .75), (1.15, 1.02), (0, 1.04),
    ], (0, 0, 0), (0, 0, 1), ARMOR, segments=16)
    cyl("Bearing", (0, 0, 1.08), .84, .18, DARK, vertices=28)
    turret = pivot("TurretPivot", (0, 0, 1.22))
    for side in (-1, 1):
        pod = pivot("MissilePodLeft" if side < 0 else "MissilePodRight", (side * 1.12, 0, 1.75), turret)
        loft("Launcher", [
            modeling.rounded_rect_ring(.86, 1.55, .14, side * 1.12, 0, 1.36, 2),
            modeling.rounded_rect_ring(.76, 1.40, .12, side * 1.12, 0, 2.14, 2),
        ], ARMOR, pod, bevel=.025)
        box("PodID", (side * 1.56, 0, 1.75), (.035, .85, .46), TEAM, pod, .01)
        for x in (-.22, 0, .22):
            for z in (-.20, 0, .20):
                cyl("Tube", (side * 1.12 + x, .76, 1.75 + z), .078, .06, DARK, pod, axis="Y", vertices=12)
                lathe("MissileNose", [(.052, 0), (.052, .03), (0, .08)], (side * 1.12 + x, .78, 1.75 + z), (0, 1, 0), ORANGE, pod, segments=10)
        pod.rotation_euler.x = math.radians(34)
    rod("RadarMast", (0, -.25, 1.15), (0, -.25, 2.25), .11, STEEL, turret, vertices=14)
    hexblock("PhasedRadar", 0, -.22, 1.65, .64, .95, TEAM, turret)
    pivot("Muzzle", (1.12, .79, 2.15), turret)


def prism_skimmer():
    begin("PrismSkimmer")
    # Wide sweeping crescent/trimaran hovercraft (distinct from NeedleSkimmer twin pontoons)
    loft("CrescentHull", [
        [(0, 1.95, .40), (1.35, .65, .40), (1.85, -1.15, .40), (.95, -1.65, .40),
         (0, -1.25, .40), (-.95, -1.65, .40), (-1.85, -1.15, .40), (-1.35, .65, .40)],
        [(0, 1.85, .74), (1.45, .60, .74), (1.92, -1.10, .74), (.98, -1.58, .74),
         (0, -1.18, .74), (-.98, -1.58, .74), (-1.92, -1.10, .74), (-1.45, .60, .74)],
        [(0, 1.45, 1.05), (1.10, .35, 1.05), (1.45, -.95, 1.05), (.72, -1.35, 1.05),
         (0, -1.00, 1.05), (-.72, -1.35, 1.05), (-1.45, -.95, 1.05), (-1.10, .35, 1.05)],
    ], ARMOR, bevel=.025)
    for lx, ly in ((0, 1.15), (-1.22, -.92), (1.22, -.92)):
        cyl("FluxDuct", (lx, ly, .24), .42, .18, DARK, vertices=24)
        ring("RepulsorGlow", (lx, ly, .16), .36, .04, GLASS)
    box("WingDeckTrim", (0, -.35, 1.07), (1.45, .72, .04), TEAM, bevel=.015)
    turret = pivot("TurretPivot", (0, -.15, 1.15))
    cyl("PrismCradle", (0, -.15, 1.18), .66, .20, STEEL, turret, vertices=24)
    shape("CoherentCrystal", [
        (0, -.15, 2.65), (-.36, -.51, 1.85), (.36, -.51, 1.85), (.36, .21, 1.85), (-.36, .21, 1.85), (0, -.15, 1.25),
    ], [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1), (5, 2, 1), (5, 3, 2), (5, 4, 3), (5, 1, 4)], GLASS, turret, smooth=False)
    for side in (-1, 1):
        modeling.sweep_tube(
            current.name + f"_EmitterProng_{side}",
            [(side * .64, -.35, 1.22), (side * .78, .05, 1.85), (side * .38, .62, 2.02)],
            .09, 12, current, ARMOR, turret,
        )
    pivot("Muzzle", (0, .65, 2.02), turret)


def phase_lancer():
    walker()
    name, collection, asset_root = assets.pop()
    collection.name = "PhaseLancer"
    asset_root.name = "PhaseLancer"
    for obj in collection.objects:
        obj.name = obj.name.replace("LancerWalker", "PhaseLancer")
    assets.append(("PhaseLancer", collection, asset_root))
    for side in (-1, 1):
        ring("PhaseCoil", (side * .9, 0, 2.25), .44, .08, GLASS, rotation=(math.pi / 2, 0, 0))


def skyward_interceptor():
    begin("SkywardInterceptor")
    # Diamond/quad-ducted hover cruiser with twin VLS cells and dorsal halo radar
    loft("DiamondHull", [
        [(0, 1.85, .36), (1.32, 0, .36), (0, -1.75, .36), (-1.32, 0, .36)],
        [(0, 1.92, .62), (1.42, 0, .62), (0, -1.82, .62), (-1.42, 0, .62)],
        [(0, 1.45, .94), (1.10, 0, .94), (0, -1.42, .94), (-1.10, 0, .94)],
    ], ARMOR, bevel=.025)
    for side in (-1, 1):
        for front in (-1, 1):
            cyl("CornerDuct", (side * .92, front * .92, .28), .34, .16, DARK, vertices=20)
            ring("LiftGlow", (side * .92, front * .92, .18), .29, .035, GLASS)
    shell("ArrayBody", 0, 0, .94, 1.32, 1.75, .42, TEAM)
    turret = pivot("TurretPivot", (0, 0, 1.38))
    for side in (-1, 1):
        shell("IonPod", side * .60, 0, 1.42, .50, 1.40, .55, ARMOR, turret)
        lens(side * .60, .72, 1.70, .27, turret)
    pivot("Muzzle", (.60, .82, 1.70), turret)
    ring("SensorHalo", (0, -.55, 2.05), .42, .045, GLASS, turret, (math.radians(22), 0, 0))
    rod("HaloMast", (0, -.55, 1.42), (0, -.55, 2.02), .045, STEEL, turret, vertices=12)


walkers_only = "--walkers-only" in sys.argv
alignment_only = "--alignment-only" in sys.argv
if alignment_only:
    needle()
    lance()
elif "--signature-only" in sys.argv:
    prism_skimmer()
    phase_lancer()
    skyward_interceptor()
elif walkers_only:
    walker()
    walker(True)
else:
    operator()
    mule()
    needle()
    walker()
    walker(True)
    kite()
    wraith()
    prism_artillery()
    nexus()
    operator_hub()
    foundry()
    flightdeck()
    flux()
    signal_lab()
    service()
    lance()
    skyward()
    prism_skimmer()
    phase_lancer()
    skyward_interceptor()

manifest = []
for name, collection, asset_root in assets:
    damage_models = ["MuleEngineer", "NeedleSkimmer", "MenderRobot", "LancerWalker", "PrismArtillery"]
    if "--damage-only" in sys.argv and name not in damage_models:
        continue
    if name in damage_models:
        socket = bpy.data.objects.new(name + "_DamageSocket", None)
        collection.objects.link(socket)
        socket.parent = asset_root
        socket.location = {
            "MuleEngineer": (.5, -1.13, 1.8),
            "NeedleSkimmer": (.95, -1.25, 1.3),
            "MenderRobot": (.6, -.4, 1.8),
            "LancerWalker": (.7, -.3, 2.6),
            "PrismArtillery": (.95, -1.2, 1.5),
        }[name]
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

if alignment_only or "--damage-only" in sys.argv or "--motion-only" in sys.argv or "--walkers-only" in sys.argv:
    export_manifest.merge_partial(SOURCE / "manifest.json", manifest)

if walkers_only:
    print("Helix walker rigs exported")
    raise SystemExit(0)

if "--models-only" in sys.argv or "--damage-only" in sys.argv:
    if "--signature-only" in sys.argv:
        export_manifest.merge_partial(SOURCE / "signature-manifest.json", manifest)
    print("Material-ready faction models exported")
    raise SystemExit(0)

world = bpy.data.worlds.new("Helix studio")
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
    camera_data.ortho_scale = max(hi - lo) * 1.45
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

if alignment_only:
    export_manifest.merge_partial(SOURCE / "manifest.json", manifest)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "aligned-defense.blend"))
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
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "helix_faction.blend"))
bpy.ops.render.render(write_still=True)
SIGNATURE_NAMES = {"PrismSkimmer", "PhaseLancer", "SkywardInterceptor"}
base_manifest = [item for item in manifest if item["name"] not in SIGNATURE_NAMES]
sig_manifest = [item for item in manifest if item["name"] in SIGNATURE_NAMES]
(SOURCE / "manifest.json").write_text(json.dumps(base_manifest, indent=2) + "\n")
(SOURCE / "signature-manifest.json").write_text(json.dumps(sig_manifest, indent=2) + "\n")
print("Helix assets complete:", len(base_manifest), "+", len(sig_manifest))
