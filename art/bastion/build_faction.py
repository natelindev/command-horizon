"""Rebuild the Bastion demo models, editable catalogue, icons and contact renders.

blender --background --factory-startup --python-exit-code 1 --python art/bastion/build_faction.py
Append -- --walkers-only to export just the articulated walker GLB.
Append -- --motion-only to export the four tracked units without studio renders.
"""
import json
import math
from pathlib import Path
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
import weathering  # noqa: E402
import trim_sheet  # noqa: E402
import markings  # noqa: E402
import modeling  # noqa: E402
import track_rig
import export_manifest

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/bastion/demo"
ICONS = ROOT / "assets/ui/bastion"
SOURCE = ROOT / "art/bastion/demo"
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


ARMOR = mat("Bastion_Armor", (.065, .076, .064))
PANEL = mat("Bastion_Panels", (.14, .155, .13))
DARK = mat("Bastion_Mechanisms", (.025, .033, .034), .55)
STEEL = mat("Bastion_Steel", (.28, .32, .32), .7)
TEAM = mat("TeamColor_Bastion", (.65, .28, .015))
RUBBER = mat("Bastion_Rubber", (.016, .023, .025), 0, .85)
GLASS = mat("Bastion_Optics", (.10, .53, .66), .25, .25, .35)
WHITE = mat("Bastion_Markings", (.75, .75, .62), .1)
CONCRETE = mat("Bastion_Concrete", (.22, .245, .24), 0, .85)
ROCK = mat("Desert_Rock", (.38, .21, .105), 0, .9)
ORE = mat("Materials_Ore", (.32, .38, .42), .55, .65)
CRYSTAL = mat("Electronics_Silicon", (.06, .39, .51), .4, .4, .1)
assets = []
current = None
root = None


def begin(name):
    global current, root
    current = bpy.data.collections.new(name)
    scene.collection.children.link(current)
    root = bpy.data.objects.new(name, None)
    current.objects.link(root)
    root["faction"] = "Bastion"
    root["forward"] = "-Z in Godot"
    assets.append((name, current, root))
    return root


def attach(obj, name, material, parent=None, bevel=0, smooth=True, sharp_angle=35.0):
    return modeling.finalize_part(
        obj,
        current.name + "_" + name,
        current,
        material,
        parent or root,
        bevel=bevel,
        bevel_segments=2 if bevel >= .04 else 1,
        smooth=smooth,
        sharp_angle=sharp_angle,
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


def sweep(name, pts, radius, material=STEEL, parent=None, segments=10):
    return modeling.sweep_tube(
        current.name + "_" + name, pts, radius, segments, current, material, parent or root,
    )


def wedge(name, x, y, z, width, length, height, material=ARMOR, parent=None):
    return loft(name, [
        modeling.rounded_rect_ring(width, length, min(width, length) * .12, x, y, z, 2),
        modeling.rounded_rect_ring(width * .92, length * .88, min(width, length) * .12, x, y - length * .04, z + height * .55, 2),
        modeling.rounded_rect_ring(width * .76, length * .70, min(width, length) * .10, x, y - length * .07, z + height, 2),
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


def badge(x, y, z, scale=.5, parent=None):
    pts = [(-.55, .34), (0, -.05), (.55, .34), (.55, .08), (0, -.34), (-.55, .08)]
    shape("Chevron", [(x + a * scale, y, z + b * scale) for a, b in pts], [(0, 1, 2, 3, 4, 5)], TEAM, parent, 0, smooth=False)


def tracks(width=2.0, length=2.8):
    half, radius, height = length * .38, .35, .43
    perimeter = 4 * half + 2 * math.pi * radius
    for side in (-1, 1):
        x = side * width / 2
        # Continuous capsule rubber track loop
        steps = 24
        verts = []
        for rad in (radius, radius - .09):
            p = 4 * half + 2 * math.pi * rad
            for xx in (x - .25, x + .25):
                for i in range(steps):
                    ty, tz, _ = track_rig.capsule(p * i / steps, half, rad, height)
                    verts.append((xx, ty, tz))
        faces = []
        for a, b in ((0, 1), (1, 3), (3, 2), (2, 0)):
            for i in range(steps):
                j = (i + 1) % steps
                faces.append((a * steps + i, a * steps + j, b * steps + j, b * steps + i))
        shape("TrackBelt", verts, faces, RUBBER, bevel=0, smooth=True)

        s = 1.0 if side > 0 else -1.0
        for i in range(5):
            y = -length * .37 + i * length * .185
            r = .24 if i in (0, 4) else .26
            rim_col = STEEL if i in (0, 4) else PANEL
            lathe(f"Wheel_{side}_{i}", [
                (0.0, s * .14), (r * .55, s * .18), (r * .85, s * .25), (r * .85, s * .28), (0.0, s * .28),
            ], (x, y, height), (1, 0, 0), rim_col, segments=18)
            cyl(f"Hub_{side}_{i}", (x + s * .29, y, height), r * .28, .05, DARK, axis="X", vertices=12)

        track = pivot("TrackPivot" + ("Left" if side < 0 else "Right"), (0, 0, 0))
        for i in range(28):
            distance = perimeter * i / 28
            y, z, angle = track_rig.capsule(distance, half, radius, height)
            shoe = box("Tread", (x, y, z), (.55, .12, .055), DARK, track, bevel=0, rot=(angle, 0, 0))
            track_rig.encode(shoe, distance, half, radius, height)

        # Contoured armored fender with sloped front/rear mudguards
        loft("Fender", [
            [(x - .33, -length * .50, .82), (x + .33, -length * .50, .82), (x + .33, length * .50, .82), (x - .33, length * .50, .82)],
            [(x - .33, -length * .45, .94), (x + .33, -length * .45, .94), (x + .33, length * .45, .94), (x - .33, length * .45, .94)],
        ], ARMOR, bevel=.03)


def lens(x, y, z, width=.25, parent=None, facing=(0, 1, 0)):
    modeling.recessed_viewport(
        current.name + "_Optic", (x, y, z), width, max(.10, width * .34), .16,
        facing, current, DARK, GLASS, parent or root,
    )


def grille(x, y, z, width=.75, length=.65, count=5, parent=None):
    modeling.louver_grille(
        current.name + "_Grille", (x, y, z), width, length, count,
        current, DARK, STEEL, parent or root,
    )


def infantry():
    begin("Infantry")
    for side, name in ((-1, "LegLeft"), (1, "LegRight")):
        leg = pivot(name, (side * .19, 0, 1.0))
        loft("Thigh", [
            modeling.ellipse_ring(.13, .14, side * .19, 0, .58, 12),
            modeling.ellipse_ring(.16, .17, side * .19, 0, .82, 12),
            modeling.ellipse_ring(.15, .16, side * .19, 0, 1.00, 12),
        ], ARMOR, leg, bevel=.01)
        box("Knee", (side * .19, .14, .56), (.22, .12, .19), TEAM, leg, .04)
        loft("Shin", [
            modeling.ellipse_ring(.11, .12, side * .19, -.01, .18, 12),
            modeling.ellipse_ring(.13, .14, side * .19, 0, .38, 12),
            modeling.ellipse_ring(.13, .14, side * .19, 0, .55, 12),
        ], PANEL, leg, bevel=.01)
        loft("Boot", [
            modeling.rounded_rect_ring(.28, .46, .08, side * .19, .10, .02, 2),
            modeling.rounded_rect_ring(.25, .36, .07, side * .19, .05, .19, 2),
        ], DARK, leg, bevel=.025)
    loft("Pelvis", [
        modeling.rounded_rect_ring(.56, .34, .09, 0, 0, .94, 2),
        modeling.rounded_rect_ring(.62, .38, .10, 0, 0, 1.16, 2),
    ], DARK, bevel=.025)
    loft("Torso", [
        modeling.rounded_rect_ring(.64, .39, .10, 0, 0, 1.12, 2),
        modeling.rounded_rect_ring(.78, .46, .12, 0, 0, 1.44, 2),
        modeling.rounded_rect_ring(.68, .40, .10, 0, 0, 1.73, 2),
    ], PANEL, bevel=.03)
    box("ChestPlate", (0, .25, 1.44), (.54, .12, .36), ARMOR, bevel=.04)
    badge(0, .325, 1.46, .32)
    box("Backpack", (0, -.33, 1.43), (.48, .26, .48), DARK, bevel=.05)
    for side in (-1, 1):
        box("Shoulder", (side * .46, 0, 1.60), (.28, .40, .26), TEAM, bevel=.08)
        loft("UpperArm", [
            modeling.ellipse_ring(.11, .11, side * .48, 0, 1.54, 10),
            modeling.ellipse_ring(.10, .10, side * .49, .22, 1.22, 10),
        ], ARMOR)
        loft("Forearm", [
            modeling.ellipse_ring(.10, .10, side * .49, .22, 1.22, 10),
            modeling.ellipse_ring(.08, .08, side * .20, .54, 1.26, 10),
        ], PANEL)
        box("Glove", (side * .20, .55, 1.25), (.15, .19, .15), DARK, bevel=.04)
    cyl("Neck", (0, 0, 1.80), .12, .16, DARK, vertices=14)
    loft("Helmet", [
        modeling.ellipse_ring(.24, .26, 0, 0, 1.80, 16),
        modeling.ellipse_ring(.26, .27, 0, -.01, 1.98, 16),
        modeling.ellipse_ring(.22, .23, 0, -.02, 2.16, 16),
        modeling.ellipse_ring(.11, .12, 0, -.02, 2.22, 16),
    ], ARMOR)
    box("Visor", (0, .235, 2.00), (.36, .07, .12), GLASS, bevel=.03)
    box("HelmetStripe", (0, -.02, 2.225), (.10, .28, .02), TEAM, bevel=.005)
    box("RifleBody", (.10, .54, 1.37), (.16, .60, .18), DARK, bevel=.03)
    lathe("RifleBarrel", [(.045, 0), (.045, .36), (.035, .38), (.035, .58)], (.10, .82, 1.40), (0, 1, 0), STEEL, segments=12)
    box("Magazine", (.10, .59, 1.20), (.11, .15, .22), ARMOR, bevel=.02)
    pivot("Muzzle", (.10, 1.42, 1.40))


def rover(name, repair=False):
    begin(name)
    tracks(1.65, 2.65)
    loft("Hull", [
        modeling.rounded_rect_ring(1.88, 2.52, .22, 0, 0, .54, 2),
        modeling.rounded_rect_ring(1.94, 2.46, .22, 0, -.02, .86, 2),
        modeling.rounded_rect_ring(1.70, 2.18, .20, 0, -.06, 1.14, 2),
    ], ARMOR, bevel=.03)
    box("Deck", (0, -.20, 1.17), (1.56, 1.48, .10), PANEL, bevel=.03)
    box("TeamPlate", (0, .92, 1.14), (1.26, .30, .05), TEAM, bevel=.02)
    lens(0, 1.16, .92, .48)
    if repair:
        # Low-profile engineering turret/sensor mast matching Bastion concept art
        box("SensorMastBase", (0, .25, 1.32), (.72, .68, .26), PANEL, bevel=.04)
        lens(0, .59, 1.36, .42)
        for side in (-1, 1):
            arm = pivot("ServiceArm" + str(side), (side * .63, -.20, 1.22))
            cyl("ShoulderCollar", (side * .63, -.20, 1.22), .15, .20, DARK, arm, axis="X", vertices=16)
            rod("ArmLower", (side * .63, -.20, 1.22), (side * .82, .05, 1.93), .105, TEAM, arm, vertices=14)
            rod("ArmPiston", (side * .63, -.32, 1.22), (side * .78, -.08, 1.72), .045, STEEL, arm, vertices=10)
            cyl("Elbow", (side * .82, .05, 1.93), .16, .22, DARK, arm, axis="X", vertices=18)
            rod("ArmUpper", (side * .82, .05, 1.93), (side * .58, .78, 1.50), .085, STEEL, arm, vertices=14)
            cyl("Wrist", (side * .58, .78, 1.50), .10, .14, DARK, arm, axis="X", vertices=14)
            for dx in (-.09, .09):
                sweep("Gripper", [
                    (side * .58 + dx, .78, 1.50),
                    (side * .58 + dx, .92, 1.44),
                    (side * .58 + dx * .5, 1.00, 1.30),
                ], .028, DARK, arm, segments=8)
        loft("ToolCabinet", [
            modeling.rounded_rect_ring(1.24, .68, .10, 0, -.70, 1.20, 2),
            modeling.rounded_rect_ring(1.14, .58, .10, 0, -.70, 1.66, 2),
        ], ARMOR, bevel=.03)
        grille(0, -.70, 1.67, .76, .40, 4)
        modeling.sensor_pod(current.name + "_Optics", (0, .62, 1.44), .85, (0, 1, 0), current, DARK, GLASS, STEEL, root)
        for side in (-1, 1):
            modeling.era_tile_rack(current.name + f"_HullERA_{side}", (side * .97, -.75, .86), (side * .97, .65, .86), (side, 0, .2), 4, (.30, .06, .22), current, PANEL, DARK, root)
        vertices, faces = markings.service_gear(0, -1.045, 1.44, size=.78)
        shape("ServiceGear", vertices, faces, WHITE, bevel=0, smooth=False)
    else:
        loft("Cab", [
            modeling.rounded_rect_ring(1.30, .98, .14, 0, .15, 1.18, 2),
            modeling.rounded_rect_ring(1.22, .88, .14, 0, .12, 1.48, 2),
            modeling.rounded_rect_ring(1.06, .74, .12, 0, .08, 1.70, 2),
        ], PANEL, bevel=.03)
        lens(0, .59, 1.48, .86)
        modeling.cupola_hatch(current.name + "_Hatch", (-.22, .05, 1.70), .24, .12, current, ARMOR, DARK, GLASS, root)
        modeling.era_tile_rack(current.name + "_BowBumper", (-.68, 1.26, .66), (.68, 1.26, .66), (0, 1, 0), 4, (.30, .08, .22), current, PANEL, STEEL, root)
        box("CargoBed", (0, -.85, 1.25), (1.46, .74, .20), DARK, bevel=.03)
        for x in (-.42, 0, .42):
            box("Cargo", (x, -.85, 1.45), (.30, .50, .24), ORE, bevel=.04)
        cyl("CraneTurntable", (.70, -.85, 1.28), .16, .14, DARK, vertices=16)
        sweep("CraneArm", [(.70, -.85, 1.32), (.70, -.85, 2.02), (.70, .58, 1.80)], .068, TEAM, segments=12)
    antenna = pivot("AntennaPivot", (-.60, -.85, 1.40))
    rod("Antenna", (-.60, -.85, 1.40), (-.60, -.85, 2.35), .015, DARK, antenna, vertices=8)


def combat_robot():
    begin("CombatRobot")
    # Quadruped heavy combat walker matching Bastion concept art
    loft("Body", [
        modeling.rounded_rect_ring(1.90, 2.05, .28, 0, 0, .96, 2),
        modeling.rounded_rect_ring(2.14, 2.24, .32, 0, 0, 1.26, 2),
        modeling.rounded_rect_ring(1.94, 2.00, .28, 0, -.04, 1.58, 2),
        modeling.rounded_rect_ring(1.56, 1.60, .24, 0, -.08, 1.74, 2),
    ], ARMOR, bevel=.035)
    grille(0, -.58, 1.75, .90, .52, 4)
    for side in (-1, 1):
        box("ShoulderBlock", (side * .92, 0, 1.34), (.36, 1.45, .44), PANEL, bevel=.05)
        for front in (-1, 1):
            name = ("LegLeft" if side < 0 else "LegRight") + ("Front" if front > 0 else "Rear")
            hip_pt = (side * .84, front * .62, 1.28)
            knee_pt = (side * 1.20, front * .94, .78)
            ankle_pt = (side * 1.38, front * 1.14, .22)
            leg = pivot(name, hip_pt)
            cyl("HipDrum", hip_pt, .22, .26, DARK, leg, axis="X", vertices=18)
            # Contoured upper leg armor casing
            rod("UpperCore", hip_pt, knee_pt, .15, DARK, leg, vertices=14)
            box("UpperArmor", ((hip_pt[0] + knee_pt[0]) * .5, (hip_pt[1] + knee_pt[1]) * .5, (hip_pt[2] + knee_pt[2]) * .5),
                (.32, .34, .68), PANEL, leg, .05, rot=(front * math.radians(34), side * math.radians(-26), 0))
            knee = pivot("KneePivot" + name.removeprefix("Leg"), knee_pt, leg)
            cyl("Joint", knee_pt, .23, .28, DARK, knee, axis="X", vertices=20)
            rod("ShinCore", knee_pt, ankle_pt, .12, DARK, knee, vertices=14)
            rod("Hydraulic", (knee_pt[0] - side * .12, knee_pt[1] - front * .12, knee_pt[2]),
                (ankle_pt[0] - side * .12, ankle_pt[1] - front * .12, ankle_pt[2] + .08), .045, STEEL, knee, vertices=10)
            box("ShinArmor", ((knee_pt[0] + ankle_pt[0]) * .5, (knee_pt[1] + ankle_pt[1]) * .5, (knee_pt[2] + ankle_pt[2]) * .5),
                (.26, .28, .54), TEAM, knee, .04, rot=(front * math.radians(16), side * math.radians(-14), 0))
            ankle = pivot("AnklePivot" + name.removeprefix("Leg"), ankle_pt, knee)
            loft("Foot", [
                modeling.rounded_rect_ring(.52, .72, .12, ankle_pt[0], ankle_pt[1], .01, 2),
                modeling.rounded_rect_ring(.42, .56, .10, ankle_pt[0], ankle_pt[1], .16, 2),
                modeling.rounded_rect_ring(.30, .38, .08, ankle_pt[0], ankle_pt[1], .24, 2),
            ], DARK, ankle, bevel=.02)
    lens(0, 1.07, 1.38, .58)
    turret = pivot("TurretPivot", (0, 0, 1.72))
    cyl("TurretRing", (0, 0, 1.69), .60, .14, DARK, turret, vertices=24)
    loft("Turret", [
        modeling.rounded_rect_ring(1.42, 1.32, .22, 0, 0, 1.73, 2),
        modeling.rounded_rect_ring(1.30, 1.20, .20, 0, -.04, 2.02, 2),
        modeling.rounded_rect_ring(1.06, .98, .16, 0, -.08, 2.20, 2),
    ], PANEL, turret, bevel=.03)
    box("TeamMark", (0, -.25, 2.21), (.78, .38, .035), TEAM, turret, .015)
    modeling.cupola_hatch(current.name + "_Hatch", (-.34, -.12, 2.20), .22, .12, current, ARMOR, DARK, GLASS, turret)
    modeling.sensor_pod(current.name + "_FCS", (.42, .42, 2.16), .75, (0, 1, 0), current, DARK, GLASS, STEEL, turret)
    for side in (-1, 1):
        modeling.smoke_dischargers(current.name + f"_Smoke_{side}", (side * .64, .10, 1.98), side, current, DARK, STEEL, turret)
        modeling.era_tile_rack(current.name + f"_ShoulderERA_{side}", (side * 1.12, -.55, 1.36), (side * 1.12, .55, 1.36), (side, 0, 0), 3, (.32, .06, .28), current, ARMOR, DARK, root)
    barrel = pivot("BarrelPivot", (0, .59, 1.94), turret)
    lathe("Cannon", [
        (.14, 0.0), (.14, .35), (.11, .38), (.11, 1.15), (.145, 1.18), (.145, 1.48), (.105, 1.50), (.105, 1.62),
    ], (0, .58, 1.94), (0, 1, 0), DARK, barrel, segments=20)
    box("MuzzleBrake", (0, 2.16, 1.94), (.30, .36, .28), PANEL, barrel, .05)
    pivot("Muzzle", (0, 2.38, 1.94), barrel)


def drone():
    begin("Drone")
    # Recon ducted-fan drone matching Bastion concept art
    loft("Body", [
        modeling.rounded_rect_ring(.94, 1.46, .22, 0, 0, .06, 2),
        modeling.rounded_rect_ring(1.08, 1.64, .24, 0, .02, .34, 2),
        modeling.rounded_rect_ring(.84, 1.34, .18, 0, -.04, .64, 2),
    ], ARMOR, bevel=.03)
    box("TeamRoof", (0, -.10, .66), (.60, .60, .04), TEAM, bevel=.015)
    lens(0, .78, .34, .44)
    cyl("Gimbal", (0, .48, .04), .22, .20, DARK, vertices=18)
    for side, label in ((-1, "Left"), (1, "Right")):
        box("WingArm", (side * .62, 0, .36), (.60, .36, .16), STEEL, bevel=.04)
        modeling.ducted_shroud(
            current.name + "_Duct" + label, (side * 1.31, 0, .39), .68, .28, .12,
            current, ARMOR, DARK, STEEL, root, segments=28,
        )
        rotor = pivot("Rotor" + label, (side * 1.31, 0, .39))
        modeling.pitched_rotor(current.name + "_Fan" + label, (side * 1.31, 0, .39), .53, 4, current, PANEL, DARK, rotor, axis="Z")


def aircraft():
    begin("Helicopter")
    loft("Fuselage", [
        modeling.rounded_rect_ring(1.24, 4.20, .34, 0, 0, .10, 2),
        modeling.rounded_rect_ring(1.48, 4.70, .38, 0, .05, .45, 2),
        modeling.rounded_rect_ring(1.10, 3.80, .30, 0, -.15, .82, 2),
    ], ARMOR, bevel=.03)
    loft("Canopy", [
        modeling.rounded_rect_ring(.86, 1.55, .24, 0, .95, .78, 2),
        modeling.rounded_rect_ring(.62, 1.15, .18, 0, .82, 1.12, 2),
    ], GLASS, bevel=.025)
    for side in (-1, 1):
        modeling.airfoil_wing(
            current.name + "_Wing", (side * .50, -.30), (side * 2.85, -1.05),
            1.60, .58, .54, .44, .18, .08, current, PANEL, root, bevel=.015,
        )
        box("WingTeam", (side * 2.15, -1.00, .53), (.56, .38, .035), TEAM, bevel=.01)
        lathe("Engine", [
            (.28, -.82), (.36, -.74), (.38, .40), (.34, .80), (.26, .84),
        ], (side * .94, -1.08, .88), (0, 1, 0), ARMOR, segments=20)
        cyl("Exhaust", (side * .94, -1.94, .88), .27, .08, DARK, axis="Y", vertices=20)
        cyl("Intake", (side * .94, -.22, .88), .28, .06, DARK, axis="Y", vertices=20)
        for y in (-.90, -.40):
            cyl("VTOLFan", (side * 1.47, y, .60), .30, .09, DARK, vertices=20)
        for x in (1.62, 2.15):
            cyl("Missile", (side * x, -.45, .23), .085, 1.02, DARK, axis="Y", vertices=12)
            cyl("MissileBand", (side * x, -.15, .23), .092, .12, TEAM, axis="Y", vertices=12)
    shape("TailFin", [(-.07, -2.0, .55), (-.07, -2.0, 1.94), (-.07, -.91, .70),
                      (.07, -2.0, .55), (.07, -2.0, 1.94), (.07, -.91, .70)],
          [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], ARMOR, bevel=.02)
    cyl("NoseGun", (0, 2.22, .35), .07, .62, DARK, axis="Y", vertices=12)
    pivot("Muzzle", (0, 2.55, .35))


def import_tank(name, advanced=False):
    begin(name)
    root.name = name + "_Container"
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/models/bastion/tank-v1/bastion_tank_v1.glb"))
    imported = set(bpy.data.objects) - before
    imported_root = next(obj for obj in imported if obj.parent is None)
    imported_root.parent = root
    for obj in imported:
        original = obj.name.split(".")[0]
        obj.name = name + "_" + original
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        current.objects.link(obj)
    if advanced:
        barrel = next(obj for obj in imported if "BarrelPivot" in obj.name)
        old = next(obj for obj in imported if "BarrelMesh" in obj.name)
        imported.remove(old)
        bpy.data.objects.remove(old, do_unlink=True)
        # Contoured dual-rail electromagnetic cannon matching Bastion concept art
        loft("RailHousing", [
            modeling.rounded_rect_ring(.82, 1.85, .14, 0, 2.02, 1.74, 2),
            modeling.rounded_rect_ring(.78, 1.80, .14, 0, 2.02, 2.34, 2),
        ], PANEL, barrel, bevel=.04)
        for side in (-1, 1):
            loft("Rail", [
                modeling.rounded_rect_ring(.18, 2.65, .04, side * .25, 3.85, 1.82, 2),
                modeling.rounded_rect_ring(.18, 2.65, .04, side * .25, 3.85, 2.26, 2),
            ], DARK, barrel, bevel=.025)
            box("Conductor", (side * .25, 3.85, 2.275), (.085, 2.32, .035), GLASS, barrel, .01)
            for y in (2.8, 3.3, 3.8, 4.3, 4.7):
                box("RailRib", (side * .35, y, 2.04), (.04, .12, .30), STEEL, barrel, .01)
        loft("Accelerator", [
            modeling.rounded_rect_ring(.84, .52, .12, 0, 5.02, 1.72, 2),
            modeling.rounded_rect_ring(.84, .52, .12, 0, 5.02, 2.36, 2),
        ], TEAM, barrel, bevel=.04)
        box("MuzzleInset", (0, 5.27, 2.04), (.43, .04, .30), DARK, barrel, .02)
        muzzle = next(obj for obj in imported if "Muzzle" in obj.name)
        muzzle.location.y = 4.20


def base_building(name, w=5, l=5):
    begin(name)
    loft("Foundation", [
        modeling.rounded_rect_ring(w + .65, l + .65, .35, 0, 0, 0.0, 2),
        modeling.rounded_rect_ring(w + .48, l + .48, .32, 0, 0, .30, 2),
    ], CONCRETE, bevel=.04)
    box("Floor", (0, 0, .33), (w, l, .14), DARK, bevel=.02)


def facade(w, l, h=2.3):
    loft("Core", [
        modeling.rounded_rect_ring(w, l, .25, 0, 0, .36, 2),
        modeling.rounded_rect_ring(w * .94, l * .94, .22, 0, 0, .36 + h, 2),
    ], ARMOR, bevel=.05)
    box("Roof", (0, 0, h + .46), (w + .16, l + .16, .22), PANEL, bevel=.06)
    for side in (-1, 1):
        for y in (-l / 2 + .25, l / 2 - .25):
            box("Buttress", (side * (w / 2 - .17), y, h / 2 + .4), (.42, .46, h + .2), CONCRETE, bevel=.05)
    box("DoorRecess", (0, l / 2 + .02, 1.1), (1.4, .06, 1.5), DARK, bevel=.02)
    box("DoorTopLight", (0, l / 2 + .05, 1.9), (1.2, .04, .10), GLASS, bevel=.01)
    badge(0, l / 2 + .065, h - .15, .8)


def headquarters():
    base_building("CommandCenter", 5.2, 4.8)
    facade(5.2, 4.8, 2.15)
    box("CommandTower", (0, -.35, 3.10), (2.8, 2.55, 1.4), CONCRETE, bevel=.10)
    box("ObservationGlass", (0, .95, 3.35), (2.35, .04, .47), GLASS, bevel=.01)
    for side in (-1, 1):
        box("ObservationGlass", (side * 1.41, -.35, 3.35), (.03, 2.0, .47), GLASS, bevel=.01)
    box("TowerRoof", (0, -.35, 3.92), (3.3, 3.0, .23), ARMOR, bevel=.05)
    box("TeamRoof", (0, -.35, 4.06), (1.0, 2.7, .045), TEAM, bevel=.01)
    for x in (-.9, .9):
        rod("Aerial", (x, -.9, 4), (x, -.9, 5.35), .035, DARK, vertices=10)
    cyl("RadarBase", (.65, .12, 4.25), .26, .30, DARK, vertices=20)
    box("RadarPanel", (.65, .12, 4.69), (1.05, .14, .55), PANEL, bevel=.03)


def factory(name, air=False):
    base_building(name, 6, 5.5)
    for side in (-1, 1):
        box("HangarWall", (side * 2.55, 0, 1.64), (.9, 5.35, 2.55), ARMOR, bevel=.08)
        for y in (-2, 0, 2):
            box("Pillar", (side * 2.89, y, 1.77), (.23, .4, 2.8), CONCRETE, bevel=.04)
        box("TeamFascia", (side * 2.54, 2.73, 2.0), (.65, .07, 1.95), TEAM, bevel=.02)
    box("RearWall", (0, -2.4, 1.62), (4.9, .55, 2.5), DARK, bevel=.04)
    box("Roof", (0, 0, 3.03), (6.1, 5.6, .34), PANEL, bevel=.08)
    box("FrontLintel", (0, 2.58, 2.8), (4.3, .42, .55), ARMOR, bevel=.05)
    box("DoorLight", (0, 2.81, 2.66), (3.4, .04, .08), GLASS, bevel=.01)
    for x in (-1.6, -.8, 0, .8, 1.6):
        box("RoofRib", (x, 0, 3.25), (.18, 5.1, .18), DARK, bevel=.03)
    for side in (-1, 1):
        box("Lane", (side * 1.4, 0, .425), (.10, 4.9, .015), TEAM, bevel=0)
    if air:
        box("FlightControl", (2.0, -1.0, 3.85), (1.8, 2.1, 1.18), ARMOR, bevel=.06)
        box("ControlWindow", (2, .06, 3.96), (1.48, .04, .44), GLASS, bevel=.01)
        rod("RadarPole", (2, -1, 4.5), (2, -1, 5.2), .06, STEEL, vertices=12)
        box("Radar", (2, -1, 5.24), (1.3, .20, .47), TEAM, bevel=.03)
    else:
        for x in (-1.75, 1.75):
            cyl("Vent", (x, -1.2, 3.55), .40, .6, DARK, vertices=20)
            cyl("VentCap", (x, -1.2, 3.87), .48, .06, STEEL, vertices=20)
        box("CraneBeam", (0, .4, 2.39), (3.9, .24, .24), TEAM, bevel=.03)


def barracks():
    base_building("Barracks", 4.1, 4.4)
    facade(4.1, 4.4, 1.9)
    for x in (-1.35, 1.35):
        box("RoofStripe", (x, 0, 2.49), (.35, 4.2, .045), TEAM, bevel=.01)
        for y in (-1.2, 0, 1.2):
            box("SideWindow", (x / abs(x) * 2.06, y, 1.63), (.03, .58, .34), GLASS, bevel=.01)
    grille(0, -.9, 2.52, 1.2, 1.0, 5)


def generator():
    base_building("PowerPlant", 3.8, 4.0)
    for x in (-.87, .87):
        cyl("Generator", (x, 0, 1.61), .68, 2.45, ARMOR, vertices=24)
        for z in (.65, 1.1, 2.0, 2.6):
            cyl("CoolingBand", (x, 0, z), .76, .14, STEEL, vertices=24)
        cyl("PowerCap", (x, 0, 2.9), .69, .18, TEAM, vertices=24)
        cyl("Stack", (x, -.65, 3.27), .23, .7, DARK, vertices=16)
    box("ControlCabinet", (0, 1.46, 1.02), (2.6, .72, 1.3), PANEL, bevel=.05)
    box("StatusDisplay", (0, 1.83, 1.27), (.82, .03, .28), GLASS, bevel=.01)
    badge(0, 1.84, .81, .48)


def lab():
    base_building("CommandLab", 4.2, 4.3)
    facade(4.2, 4.3, 2.1)
    for side in (-1, 1):
        box("ServerPod", (side * 1.56, -.1, 2.95), (.87, 2.35, 1.02), DARK, bevel=.05)
        for y in (-.85, -.2, .45):
            box("ServerBand", (side * 1.56, y, 3.49), (.71, .12, .025), GLASS, bevel=.005)
    box("ComputeCore", (0, -.1, 2.82), (1.38, 1.75, .8), TEAM, bevel=.04)
    box("ChipTop", (0, -.1, 3.25), (.91, 1.27, .08), DARK, bevel=.02)
    rod("DishMast", (0, -1.38, 2.4), (0, -1.38, 3.7), .07, STEEL, vertices=14)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1, location=(0, -1.38, 3.95))
    obj = bpy.context.object
    obj.scale = (.78, .20, .60)
    attach(obj, "SignalDish", PANEL, smooth=True)


def depot():
    base_building("RepairDepot", 5.0, 4.7)
    for side in (-1, 1):
        box("ServiceTower", (side * 2.05, 0, 1.62), (.75, 4.3, 2.5), ARMOR, bevel=.06)
        rod("CraneLeg", (side * 1.55, -.8, .45), (side * 1.55, -.8, 3.2), .11, STEEL, vertices=14)
        vertices, faces = markings.service_gear(side * 2.05, 2.18, 1.7, size=1.2)
        shape("ServiceGear", vertices, faces, WHITE, bevel=0, smooth=False)
        box("ServiceStrip", (side * 1.3, .1, .44), (.17, 3.95, .02), TEAM, bevel=0)
    box("OverheadCrane", (0, -.8, 3.25), (3.7, .46, .44), TEAM, bevel=.04)
    rod("SuspendedTool", (.55, -.8, 3.05), (.55, -.8, 1.9), .05, DARK, vertices=10)
    box("BackTools", (0, -2.01, 1.16), (3.4, .43, 1.35), PANEL, bevel=.04)


def defense(name, aa=False):
    base_building(name, 2.8, 2.8)
    wedge("Plinth", 0, 0, .32, 2.8, 2.8, .7)
    cyl("Ring", (0, 0, 1.05), 1.0, .18, DARK, vertices=28)
    turret = pivot("TurretPivot", (0, 0, 1.15))
    wedge("Turret", 0, 0, 1.12, 2.15, 1.94, .62, PANEL, turret)
    badge(0, 1.0, 1.48, .7, turret)
    if aa:
        for side in (-1, 1):
            box("MissilePod", (side * 1.05, .12, 1.89), (.67, 1.7, .64), ARMOR, turret, .08, (-.27, 0, 0))
            for x in (-.15, .15):
                for z in (-.15, .15):
                    cyl("Tube", (side * 1.05 + x, .97, 1.89 + z), .09, .04, DARK, turret, axis="Y", vertices=12)
        rod("RadarMast", (0, -.5, 1.7), (0, -.5, 2.45), .055, STEEL, turret)
        box("Radar", (0, -.5, 2.49), (1.05, .15, .38), TEAM, turret, .03)
        pivot("Muzzle", (1.05, 1.05, 1.9), turret)
    else:
        barrel = pivot("BarrelPivot", (0, .8, 1.55), turret)
        for side in (-1, 1):
            cyl("Cannon", (side * .28, 1.5, 1.55), .11, 1.55, DARK, barrel, axis="Y", vertices=18)
            box("Tip", (side * .28, 2.20, 1.55), (.27, .32, .27), ARMOR, barrel, .04)
        pivot("Muzzle", (0, 2.4, 1.55), barrel)


def resources(name, electronics=False):
    begin(name)
    for i in range(7):
        x, y = random.uniform(-.85, .85), random.uniform(-.7, .7)
        z = random.uniform(.28, .65)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(x, y, z * .6))
        obj = bpy.context.object
        obj.scale = (.55, .48, z)
        attach(obj, "Mineral", CRYSTAL if electronics else ORE, smooth=False)
    box("Pallet", (0, 0, .12), (2.5, 2, .2), DARK, bevel=.03)
    for side in (-1, 1):
        box("Bracket", (side * 1.05, 0, .29), (.16, 1.8, .17), TEAM if not electronics else GLASS, bevel=.02)


def cliff():
    begin("CliffCluster")
    # Stratified angular desert rock formations instead of raw icospheres
    for idx, (cx, cy, cz, r, h) in enumerate(((0, 0, 0, 2.4, 3.2), (1.8, .3, 0, 1.5, 2.0), (-1.6, .3, 0, 1.4, 1.7), (.1, 1.6, 0, 1.3, 1.5))):
        rings = []
        rng = random.Random(100 + idx)
        for step, (zf, rf) in enumerate(((0.0, 1.0), (0.35, 0.88), (0.68, 0.68), (0.92, 0.44), (1.0, 0.25))):
            ring = []
            for k in range(10):
                ang = k * math.tau / 10 + idx * 0.4
                rad = r * rf * rng.uniform(.78, 1.15)
                ring.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad * .80, cz + h * zf))
            rings.append(ring)
        modeling.loft_rings(f"CliffCluster_Strata_{idx}", rings, current, ROCK, root, closed_caps=True, bevel=0.0, smooth=False)


def siege_colossus():
    begin("SiegeColossus")
    tracks(3.0, 4.6)
    loft("SiegeHull", [
        modeling.rounded_rect_ring(3.15, 4.55, .36, 0, 0, .68, 2),
        modeling.rounded_rect_ring(3.38, 4.70, .38, 0, 0, 1.02, 2),
        modeling.rounded_rect_ring(3.02, 4.20, .32, 0, -.12, 1.38, 2),
    ], ARMOR, bevel=.04)
    lens(0, 2.30, 1.08, 1.1)
    for side in (-1, 1):
        for front in (-1, 1):
            arm = pivot("Stabilizer_%d_%d" % (side, front), (side * 1.4, front * 1.6, 1.0))
            cyl("Mount", (side * 1.4, front * 1.6, 1.0), .18, .22, DARK, arm, axis="Y", vertices=16)
            rod("HydraulicRam", (side * 1.4, front * 1.6, 1.0), (side * 2.05, front * 2.10, .24), .13, STEEL, arm, vertices=14)
            rod("HydraulicSleeve", (side * 1.4, front * 1.6, 1.0), (side * 1.72, front * 1.85, .62), .17, ARMOR, arm, vertices=14)
            loft("AnchorSpade", [
                modeling.rounded_rect_ring(.78, .64, .12, side * 2.05, front * 2.10, .02, 2),
                modeling.rounded_rect_ring(.62, .48, .10, side * 2.05, front * 2.10, .28, 2),
            ], PANEL, arm, bevel=.025)
        loft("CompositePlate", [
            modeling.rounded_rect_ring(.52, 2.75, .10, side * 1.42, 0, 1.08, 2),
            modeling.rounded_rect_ring(.42, 2.55, .08, side * 1.40, 0, 1.42, 2),
        ], PANEL, bevel=.03)
    cyl("TurretBearing", (0, -.35, 1.40), 1.05, .14, DARK, vertices=28)
    turret = pivot("TurretPivot", (0, -.35, 1.44))
    loft("SiegeTurret", [
        modeling.rounded_rect_ring(2.38, 2.20, .34, 0, -.35, 1.44, 2),
        modeling.rounded_rect_ring(2.48, 2.25, .36, 0, -.38, 1.78, 2),
        modeling.rounded_rect_ring(2.05, 1.90, .28, 0, -.45, 2.12, 2),
    ], PANEL, turret, bevel=.04)
    grille(0, -1.05, 2.13, 1.25, .58, 4, turret)
    barrel = pivot("BarrelPivot", (0, .65, 1.96), turret)
    box("Mantlet", (0, .72, 1.96), (.84, .56, .52), DARK, barrel, .07)
    for side in (-1, 1):
        cyl("Recuperator", (side * .28, 1.25, 1.78), .10, 1.15, DARK, barrel, axis="Y", vertices=16)
    lathe("155mmBarrel", [
        (.22, .65), (.22, 1.25), (.185, 1.30), (.185, 2.15),
        (.22, 2.22), (.22, 2.65), (.175, 2.72), (.175, 3.28),
    ], (0, 0, 1.96), (0, 1, 0), STEEL, barrel, segments=24)
    box("MuzzleBrake", (0, 3.42, 1.96), (.58, .48, .44), DARK, barrel, .06)
    pivot("Muzzle", (0, 3.68, 1.96), barrel)
    box("TeamStripe", (0, -.55, 2.14), (1.20, .78, .035), TEAM, turret, .015)
    modeling.cupola_hatch(current.name + "_Hatch", (-.55, -.25, 2.12), .34, .16, current, ARMOR, DARK, GLASS, turret)
    modeling.sensor_pod(current.name + "_FCS", (.58, .35, 2.14), .95, (0, 1, 0), current, DARK, GLASS, STEEL, turret)
    for side in (-1, 1):
        modeling.smoke_dischargers(current.name + f"_Smoke_{side}", (side * 1.18, -.05, 1.82), side, current, DARK, STEEL, turret)
        modeling.era_tile_rack(current.name + f"_TurretERA_{side}", (side * 1.24, -.95, 1.76), (side * 1.24, .35, 1.76), (side, 0, .15), 4, (.30, .08, .28), current, ARMOR, DARK, turret)
    modeling.era_tile_rack(current.name + "_GlacisERA", (-1.10, 2.25, 1.06), (1.10, 2.25, 1.06), (0, 1, .35), 5, (.36, .08, .24), current, PANEL, DARK, root)
    antenna = pivot("AntennaPivot", (-.85, -1.05, 2.0), turret)
    rod("RadioAntenna", (-.85, -1.05, 2.0), (-.85, -1.05, 2.85), .024, STEEL, antenna, vertices=8)


def bulwark_walker():
    begin("BulwarkWalker")
    for side in (-1, 1):
        hip = pivot("LegLeft" if side < 0 else "LegRight", (side * .64, 0, 1.35))
        cyl("HipDrum", (side * .64, 0, 1.35), .24, .26, DARK, hip, axis="X", vertices=18)
        rod("HydraulicThigh", (side * .64, 0, 1.35), (side * .75, -.25, .65), .19, DARK, hip, vertices=16)
        box("ThighArmor", (side * .70, -.12, 1.00), (.38, .42, .62), PANEL, hip, .06, rot=(math.radians(-18), 0, 0))
        knee = pivot("KneePivot", (side * .75, -.25, .65), hip)
        cyl("KneeJoint", (side * .75, -.25, .65), .21, .28, DARK, knee, axis="X", vertices=18)
        rod("ArmoredShin", (side * .75, -.25, .65), (side * .80, .18, .18), .18, ARMOR, knee, vertices=16)
        box("ShinGuard", (side * .80, .06, .42), (.34, .26, .46), PANEL, knee, .05, rot=(math.radians(38), 0, 0))
        ankle = pivot("AnklePivot", (side * .80, .18, .18), knee)
        loft("Foot", [
            modeling.rounded_rect_ring(.68, .92, .14, side * .80, .20, .01, 2),
            modeling.rounded_rect_ring(.52, .72, .12, side * .80, .16, .24, 2),
        ], DARK, ankle, bevel=.025)
    loft("Torso", [
        modeling.rounded_rect_ring(1.56, 1.72, .26, 0, 0, 1.28, 2),
        modeling.rounded_rect_ring(1.74, 1.88, .28, 0, 0, 1.72, 2),
        modeling.rounded_rect_ring(1.42, 1.54, .22, 0, -.06, 2.22, 2),
    ], ARMOR, bevel=.04)
    grille(0, -.52, 2.23, .84, .46, 4)
    turret = pivot("TurretPivot", (0, .1, 2.28))
    box("GunMount", (.65, .15, 2.29), (.36, .62, .34), PANEL, turret, .05)
    lathe("Autocannon", [
        (.12, .35), (.12, .85), (.095, .88), (.095, 1.65), (.125, 1.68), (.125, 1.82),
    ], (.70, 0, 2.29), (0, 1, 0), STEEL, turret, segments=18)
    pivot("Muzzle", (.70, 1.85, 2.29), turret)
    shield = pivot("DirectionalShield", (0, 1.0, 1.44))
    # Contoured multi-faceted riot shield with beveled wings
    loft("KineticShield", [
        [(-1.26, .84, .28), (-.70, 1.08, .28), (.70, 1.08, .28), (1.26, .84, .28),
         (1.26, .64, .28), (.65, .86, .28), (-.65, .86, .28), (-1.26, .64, .28)],
        [(-1.26, .84, 2.58), (-.70, 1.08, 2.58), (.70, 1.08, 2.58), (1.26, .84, 2.58),
         (1.26, .64, 2.58), (.65, .86, 2.58), (-.65, .86, 2.58), (-1.26, .64, 2.58)],
    ], PANEL, shield, bevel=.04)
    box("ShieldInsignia", (0, 1.09, 1.54), (.36, .035, 1.18), TEAM, shield, .01)
    lens(0, 1.08, 2.38, .62, shield)
    for side in (-1, 1):
        modeling.era_tile_rack(current.name + f"_ShieldERA_{side}", (side * .92, .96, .85), (side * .92, .96, 2.05), (side * .35, 1, 0), 4, (.24, .07, .34), current, ARMOR, DARK, shield)
    modeling.cupola_hatch(current.name + "_Hatch", (-.35, -.18, 2.22), .26, .14, current, PANEL, DARK, GLASS, root)
    modeling.sensor_pod(current.name + "_Optics", (.36, .48, 2.24), .85, (0, 1, 0), current, DARK, GLASS, STEEL, turret)


def flak_halftrack():
    begin("FlakHalftrack")
    tracks(2.5, 2.5)
    loft("HalftrackHull", [
        modeling.rounded_rect_ring(2.58, 4.05, .28, 0, .55, .62, 2),
        modeling.rounded_rect_ring(2.68, 4.12, .28, 0, .55, .94, 2),
        modeling.rounded_rect_ring(2.44, 3.85, .24, 0, .50, 1.22, 2),
    ], ARMOR, bevel=.035)
    for side in (-1, 1):
        modeling.detailed_wheel(
            current.name + f"_FrontWheel_{side}", (side * 1.24, 1.65, .50),
            .48, .34, side, current, RUBBER, STEEL, TEAM, root, segments=22, lug_count=12,
        )
    loft("ArmoredCab", [
        modeling.rounded_rect_ring(2.14, 1.36, .20, 0, 1.20, 1.18, 2),
        modeling.rounded_rect_ring(1.96, 1.22, .18, 0, 1.14, 1.64, 2),
        modeling.rounded_rect_ring(1.76, 1.04, .16, 0, 1.08, 1.88, 2),
    ], PANEL, bevel=.03)
    box("CabStripe", (0, 1.08, 1.90), (1.24, .54, .035), TEAM, bevel=.01)
    lens(0, 1.84, 1.56, 1.24)
    modeling.cupola_hatch(current.name + "_Hatch", (-.45, 1.10, 1.88), .25, .12, current, ARMOR, DARK, GLASS, root)
    for side in (-1, 1):
        modeling.era_tile_rack(current.name + f"_HullERA_{side}", (side * 1.34, -.65, .96), (side * 1.34, .85, .96), (side, 0, 0), 4, (.32, .06, .24), current, PANEL, DARK, root)
    cyl("TurretRing", (0, -.75, 1.28), .85, .14, DARK, vertices=24)
    turret = pivot("TurretPivot", (0, -.75, 1.51))
    modeling.sensor_pod(current.name + "_FLIR", (.45, -.42, 2.38), .85, (0, 1, 0), current, DARK, GLASS, STEEL, turret)
    loft("FlakShield", [
        [(-.96, -.28, 1.42), (.96, -.28, 1.42), (.88, -.06, 2.46), (-.88, -.06, 2.46)],
        [(-.96, -.12, 1.42), (.96, -.12, 1.42), (.88, .10, 2.46), (-.88, .10, 2.46)],
    ], ARMOR, turret, bevel=.03)
    for side in (-1, 1):
        lathe(f"FlakBarrel_{side}", [
            (.11, -.25), (.11, .35), (.085, .38), (.085, 1.42), (.115, 1.45), (.115, 1.62),
        ], (side * .50, 0, 2.00), (0, 1, 0), STEEL, turret, segments=18)
        cyl(f"DrumMag_{side}", (side * .78, -.45, 1.88), .22, .22, DARK, turret, axis="X", vertices=18)
    pivot("Muzzle", (-.50, 1.65, 2.00), turret)


walkers_only = "--walkers-only" in sys.argv
motion_only = "--motion-only" in sys.argv
if "--signature-only" in sys.argv:
    siege_colossus()
    bulwark_walker()
    flak_halftrack()
elif motion_only:
    rover("Worker")
    rover("RepairRobot", True)
    import_tank("Tank")
    import_tank("AdvancedTank", True)
elif walkers_only:
    combat_robot()
else:
    infantry()
    rover("Worker")
    import_tank("Tank")
    import_tank("AdvancedTank", True)
    rover("RepairRobot", True)
    combat_robot()
    drone()
    aircraft()
    headquarters()
    barracks()
    factory("VehicleFactory")
    factory("AircraftFactory", True)
    generator()
    lab()
    depot()
    defense("AntiGroundTurret")
    defense("AntiAirTurret", True)
    resources("ResourceA")
    resources("ResourceB", True)
    cliff()
    siege_colossus()
    bulwark_walker()
    flak_halftrack()

manifest = []
for name, collection, asset_root in assets:
    damage_models = ["Worker", "Tank", "AdvancedTank", "RepairRobot", "CombatRobot"]
    if "--damage-only" in sys.argv and name not in damage_models:
        continue
    if name in damage_models:
        socket = bpy.data.objects.new(name + "_DamageSocket", None)
        collection.objects.link(socket)
        socket.parent = asset_root
        socket.location = {
            "Worker": (.7, -.85, 1.7),
            "Tank": (0, -1.5, 1.6),
            "AdvancedTank": (0, -2.0, 1.7),
            "RepairRobot": (.4, -.7, 1.9),
            "CombatRobot": (.65, -.75, 1.75),
        }[name]
    bpy.context.view_layer.update()
    for part in collection.objects:
        if not (part.parent and "TrackPivot" in part.parent.name):
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
        if parent and "TrackPivot" in parent.name:
            joined.data.transform(joined.matrix_world)
            joined.matrix_world.identity()
        modifier = joined.modifiers.new("Triangulate", "TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bm = bmesh.new()
        bm.from_mesh(joined.data)
        degen = [f for f in bm.faces if f.calc_area() < 1e-10]
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
    manifest.append({"name": name, "triangles": triangles, "file": name + ".glb"})
    collection.hide_render = True

if walkers_only or motion_only or "--signature-only" in sys.argv or "--damage-only" in sys.argv:
    export_manifest.merge_partial(SOURCE / "manifest.json", manifest)
    export_manifest.merge_partial(SOURCE / "signature-manifest.json", manifest)

if walkers_only or motion_only:
    print("Bastion motion rigs exported" if motion_only else "Bastion walker rig exported")
    raise SystemExit(0)

if "--models-only" in sys.argv or "--damage-only" in sys.argv:
    print("Material-ready faction models exported")
    raise SystemExit(0)

world = bpy.data.worlds.new("Bastion studio")
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
scene.cycles.samples = 16
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
    collection.hide_render = True
    manifest[next(i for i, item in enumerate(manifest) if item["name"] == name)]["bounds"] = {"min": list(lo), "max": list(hi)}

if "--signature-only" in sys.argv:
    (SOURCE / "signature-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    raise SystemExit(0)

for i, (name, collection, asset_root) in enumerate(assets):
    collection.hide_render = False
    asset_root.location = Vector(((i % 5 - 2) * 9, (i // 5 - 1.5) * 10, 0))
camera.location = (38, 45, 48)
camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.ortho_scale = 62
scene.render.film_transparent = False
scene.render.resolution_x = 1800
scene.render.resolution_y = 1500
scene.cycles.samples = 32
scene.render.filepath = str(SOURCE / "faction-catalogue.png")
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "bastion_faction.blend"))
bpy.ops.render.render(write_still=True)
(SOURCE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("Bastion assets complete:", len(manifest))
