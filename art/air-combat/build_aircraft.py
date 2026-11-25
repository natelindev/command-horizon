"""Build the air-combat redesign models: fighters, bombers, rotorcraft and mobile
anti-air for all three factions, plus their roster icons.

Rebuild faction GLBs with art/<faction>/build_aircraft.py. This shared builder
also generates the complete editable catalogue and icons when run directly.
"""
import json
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
import weathering  # noqa: E402
import trim_sheet  # noqa: E402
import modeling  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/air-combat"
BUILD_FACTION = globals().get("BUILD_FACTION")
OUTPUT = {
    "bastion": (ROOT / "assets/models/bastion/air-v1", ROOT / "assets/ui/bastion"),
    "helix": (ROOT / "assets/models/helix/v1", ROOT / "assets/ui/helix"),
    "frontier": (ROOT / "assets/models/frontier/v1", ROOT / "assets/ui/frontier"),
}
for models, icons in OUTPUT.values():
    models.mkdir(parents=True, exist_ok=True)
    icons.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
bpy.context.preferences.filepaths.save_version = 0


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


PALETTES = {
    "bastion": {
        "armor": mat("Bastion_Armor", (.065, .076, .064)),
        "panel": mat("Bastion_Panels", (.14, .155, .13)),
        "dark": mat("Bastion_Mechanisms", (.025, .033, .034), .55),
        "steel": mat("Bastion_Steel", (.28, .32, .32), .7),
        "team": mat("TeamColor_Bastion", (.65, .28, .015)),
        "rubber": mat("Bastion_Rubber", (.016, .023, .025), 0, .85),
        "glass": mat("Bastion_Optics", (.10, .53, .66), .25, .25, .35),
        "mark": mat("Bastion_Markings", (.75, .75, .62), .1),
    },
    "helix": {
        "armor": mat("Helix_Ceramic", (.72, .73, .66), .15, .42),
        "panel": mat("Helix_Secondary", (.42, .48, .46), .25, .48),
        "dark": mat("Helix_Graphite", (.025, .043, .050), .6, .4),
        "steel": mat("Helix_Titanium", (.22, .28, .30), .75, .35),
        "team": mat("TeamColor_Helix", (.015, .23, .25), .25, .42),
        "rubber": mat("Helix_Rubber", (.012, .019, .021), 0, .88),
        "glass": mat("Helix_Optics", (.04, .65, .72), .25, .22, 1.2),
        "mark": mat("Helix_Warning", (.95, .23, .025), .1, .5),
    },
    "frontier": {
        "armor": mat("Frontier_Ceramic", (.27, .32, .18), .15, .42),
        "panel": mat("Frontier_Secondary", (.52, .42, .28), .25, .48),
        "dark": mat("Frontier_Graphite", (.025, .043, .050), .6, .4),
        "steel": mat("Frontier_Titanium", (.22, .28, .30), .75, .35),
        "team": mat("TeamColor_Frontier", (.72, .22, .055), .25, .42),
        "rubber": mat("Frontier_Rubber", (.012, .019, .021), 0, .88),
        "glass": mat("Frontier_Optics", (.62, .80, .56), .25, .22, 1.2),
        "mark": mat("Frontier_Canvas", (.70, .65, .48), 0, .86),
    },
}
P = PALETTES["bastion"]
assets = []
current = None
root = None


def begin(faction, name):
    global current, root, P
    P = PALETTES[faction]
    current = bpy.data.collections.new(faction + "_" + name)
    scene.collection.children.link(current)
    root = bpy.data.objects.new(name, None)
    current.objects.link(root)
    root["faction"] = faction
    root["forward"] = "-Z in Godot"
    assets.append((faction, name, current, root))
    return root


def attach(obj, name, material, parent=None, bevel=0, smooth=True, sharp_angle=35.0):
    return modeling.finalize_part(
        obj, current.name + "_" + name, current, material, parent or root,
        bevel=bevel, bevel_segments=2 if bevel >= .04 else 1,
        smooth=smooth, sharp_angle=sharp_angle,
    )


def box(name, xyz, size, material=None, parent=None, bevel=.035, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rot:
        obj.rotation_euler = rot
    return attach(obj, name, material or P["armor"], parent, bevel)


def cyl(name, xyz, radius, depth, material=None, parent=None, axis="Z", vertices=20):
    vertices = max(vertices, 18 if radius >= .12 else 12)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=xyz)
    obj = bpy.context.object
    if axis == "Y":
        obj.rotation_euler.x = math.pi / 2
    if axis == "X":
        obj.rotation_euler.y = math.pi / 2
    return attach(obj, name, material or P["dark"], parent, bevel=0, smooth=True, sharp_angle=35.0)


def cone(name, xyz, radius, depth, material=None, parent=None, vertices=20):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=0, depth=depth, location=xyz)
    obj = bpy.context.object
    obj.rotation_euler.x = -math.pi / 2
    return attach(obj, name, material or P["armor"], parent, smooth=True, sharp_angle=45.0)


def rod(name, a, b, radius, material=None, parent=None, vertices=12):
    delta = Vector(b) - Vector(a)
    obj = cyl(name, (Vector(a) + Vector(b)) / 2, radius, delta.length, material or P["steel"], parent, vertices=vertices)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return obj


def shape(name, vertices, faces, material=None, parent=None, bevel=.02, smooth=True):
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
    return attach(obj, name, material or P["armor"], parent, bevel, smooth=smooth)


def loft(name, rings, material=None, parent=None, bevel=.02, sharp_angle=38.0):
    return modeling.loft_rings(
        current.name + "_" + name, rings, current, material or P["armor"], parent or root,
        closed_caps=True, bevel=bevel, bevel_segments=2 if bevel >= .04 else 1,
        smooth=True, sharp_angle=sharp_angle,
    )


def lathe(name, prof, origin, axis_dir, material=None, parent=None, segments=24, sharp_angle=36.0):
    return modeling.lathe_profile(
        current.name + "_" + name, prof, origin, axis_dir, segments,
        current, material or P["armor"], parent or root, smooth=True, sharp_angle=sharp_angle,
    )


def slab(name, outline, z, thickness, material=None, parent=None, bevel=.02):
    count = len(outline)
    vertices = [(x, y, z) for x, y in outline] + [(x, y, z + thickness) for x, y in outline]
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, 2 * count))]
    for i in range(count):
        j = (i + 1) % count
        faces.append((i, j, count + j, count + i))
    return shape(name, vertices, faces, material, parent, bevel, smooth=True)


def wedge(name, x, y, z, width, length, height, material=None, parent=None, taper=(.8, .7)):
    return loft(name, [
        modeling.rounded_rect_ring(width, length, min(width, length) * .14, x, y, z, 2),
        modeling.rounded_rect_ring(width * ((1 + taper[0]) * .5), length * .9, min(width, length) * .12, x, y - length * .04, z + height * .55, 2),
        modeling.rounded_rect_ring(width * taper[0], length * taper[1], min(width, length) * .10, x, y - length * .08, z + height, 2),
    ], material, parent, bevel=.02)


def pivot(name, xyz, parent=None, rot=None):
    obj = bpy.data.objects.new(current.name + "_" + name, None)
    current.objects.link(obj)
    obj.location = xyz
    if rot:
        obj.rotation_euler = rot
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent or root
    obj.matrix_world = world
    return obj


def gear(points, height=.5):
    for x, y in points:
        rod("GearStrut", (x, y, .2), (x, y, height), .045, P["steel"], vertices=10)
        modeling.detailed_wheel(
            current.name + f"_GearWheel_{x:.2f}_{y:.2f}", (x, y, .16),
            .16, .11, 1 if x >= 0 else -1, current, P["rubber"], P["steel"], P["steel"], root, segments=16, lug_count=0,
        )


def rotor(name, xyz, radius, blades, parent=None, axis="Z"):
    hub = pivot(name, xyz, parent)
    modeling.pitched_rotor(current.name + "_Fan_" + name, xyz, radius, blades, current, P["steel"], P["dark"], hub, axis=axis)
    return hub


def missiles(x, y, z, count=2, length=.95, radius=.085):
    for index in range(count):
        offset = (index - (count - 1) / 2) * radius * 2.6
        cyl("Missile", (x + offset, y, z), radius, length, P["dark"], axis="Y", vertices=14)
        lathe("MissileNose", [
            (radius, 0.0), (radius * .85, .08), (0.0, .20),
        ], (x + offset, y + length / 2, z), (0, 1, 0), P["mark"], segments=14)
        cyl("MissileBand", (x + offset, y + length * .25, z), radius * 1.06, .1, P["team"], axis="Y", vertices=14)


def tracks(width=2.0, length=2.8):
    for side in (-1, 1):
        x = side * width / 2
        loft("TrackBelt", [
            modeling.rounded_rect_ring(.50, length, .20, x, 0, .06, 2),
            modeling.rounded_rect_ring(.52, length * 1.02, .22, x, 0, .42, 2),
            modeling.rounded_rect_ring(.50, length, .20, x, 0, .78, 2),
        ], P["rubber"], bevel=0)
        for i in range(5):
            y = -length * .37 + i * length * .185
            cyl("Wheel", (x + side * .26, y, .43), .25, .06, P["panel"], axis="X", vertices=18)
        box("Fender", (x, 0, .89), (.65, length, .13), bevel=.03)


def wheels(width=2.1, positions=(-1.0, .2, 1.1), radius=.42):
    for side in (-1, 1):
        for y in positions:
            modeling.detailed_wheel(
                current.name + f"_Wheel_{side}_{y:.2f}", (side * width / 2, y, radius),
                radius, .34, side, current, P["rubber"], P["steel"], P["team"], root, segments=20, lug_count=10,
            )


def fuselage_loft(name, stations, mat_override=None, parent=None):
    """Build a smooth multi-station aircraft fuselage from (y, z_center, rx, rz) tuples."""
    rings = [modeling.ellipse_ring(rx, rz, 0, y, zc, segments=18) for y, zc, rx, rz in stations]
    # Note: ellipse_ring operates in XY; swap axes to XZ cross-sections along Y fuselage
    rings_xz = [[(x, y, zc + dy) for x, dy, _ in [(math.cos(a) * rx, math.sin(a) * rz, 0)
                 for a in (k * math.tau / 18 for k in range(18))]]
                for y, zc, rx, rz in stations]
    return loft(name, rings_xz, mat_override or P["armor"], parent, bevel=0.0, sharp_angle=45.0)


# --- Bastion ---------------------------------------------------------------------

def bastion_fighter():
    begin("bastion", "Fighter")
    # Aerodynamic twin-tail strike jet matching Bastion concept art
    fuselage_loft("Fuselage", [
        (-2.55, .64, .34, .28),
        (-1.40, .66, .46, .34),
        (0.20, .66, .52, .38),
        (1.60, .64, .44, .34),
        (2.45, .62, .34, .26),
        (3.35, .60, .12, .10),
        (3.60, .59, .02, .02),
    ])
    fuselage_loft("Canopy", [
        (0.65, .94, .24, .14),
        (1.25, 1.00, .27, .22),
        (1.75, .92, .20, .14),
        (2.10, .82, .08, .06),
    ], P["glass"])
    for side in (-1, 1):
        modeling.airfoil_wing(
            current.name + f"_Wing_{side}", (side * .42, .12), (side * 2.40, -1.28),
            1.65, .56, .50, .48, .15, .07, current, P["panel"], root, bevel=.015,
        )
        box("WingTeam", (side * 1.9, -1.25, .56), (.46, .32, .03), P["team"], bevel=.01)
        shape("TailFin", [
            (side * .30, -2.4, .88), (side * .56, -2.4, 1.85), (side * .36, -1.45, .92),
            (side * .40, -2.4, .88), (side * .66, -2.4, 1.85), (side * .46, -1.45, .92),
        ], [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], bevel=.015)
        modeling.airfoil_wing(
            current.name + f"_Stabilizer_{side}", (side * .42, -2.25), (side * 1.38, -2.60),
            .65, .32, .56, .56, .09, .05, current, P["panel"], root, bevel=.01,
        )
        loft("Intake", [
            modeling.rounded_rect_ring(.34, .92, .08, side * .58, .55, .42, 2),
            modeling.rounded_rect_ring(.30, .84, .07, side * .58, .55, .82, 2),
        ], P["dark"], bevel=.02)
        missiles(side * 1.45, -.75, .30, 2, .9, .075)
    lathe("Exhaust", [
        (.32, -2.48), (.30, -2.76), (.22, -2.78),
    ], (0, 0, .64), (0, 1, 0), P["dark"], segments=20)
    cyl("Afterburner", (0, -2.80, .64), .20, .06, P["glass"], axis="Y", vertices=18)
    cyl("Cannon", (.32, 2.20, .55), .05, .55, P["dark"], axis="Y", vertices=12)
    modeling.sensor_pod(current.name + "_ChinFLIR", (0, 2.55, .42), .65, (0, 1, 0), current, P["dark"], P["glass"], P["steel"], root)
    gear([(0, 1.9), (-.75, -.7), (.75, -.7)], .42)
    pivot("Muzzle", (0, 3.55, .60))


def bastion_bomber():
    begin("bastion", "Bomber")
    fuselage_loft("Fuselage", [
        (-3.20, .72, .54, .40),
        (-1.60, .80, .68, .48),
        (1.20, .82, .68, .48),
        (2.85, .80, .58, .42),
        (3.65, .78, .32, .26),
        (3.95, .78, .08, .08),
    ])
    fuselage_loft("Cockpit", [
        (1.50, 1.18, .42, .18),
        (2.25, 1.24, .44, .22),
        (2.90, 1.12, .32, .14),
    ], P["glass"])
    for side in (-1, 1):
        modeling.airfoil_wing(
            current.name + f"_Wing_{side}", (side * .55, .25), (side * 3.85, .05),
            1.65, .62, 1.12, 1.10, .20, .09, current, P["panel"], root, bevel=.015,
        )
        for x in (1.35, 2.55):
            lathe("Nacelle", [
                (.20, -.75), (.28, -.65), (.28, .65), (.22, .75),
            ], (side * x, .35, .92), (0, 1, 0), P["armor"], segments=18)
            letter = ("A" if x < 2 else "B") if side < 0 else ("C" if x < 2 else "D")
            rotor("Rotor" + letter, (side * x, 1.24, .92), .62, 3, axis="Y")
        box("WingTeam", (side * 3.35, .10, 1.22), (.6, .36, .03), P["team"], bevel=.01)
        modeling.airfoil_wing(
            current.name + f"_Stabilizer_{side}", (side * .48, -2.90), (side * 1.90, -3.20),
            .75, .40, .96, .96, .10, .06, current, P["panel"], root, bevel=.01,
        )
        shape("TailFin", [
            (side * 1.75, -3.3, .95), (side * 1.75, -3.35, 2.05), (side * 1.75, -2.6, 1.0),
            (side * 1.87, -3.3, .95), (side * 1.87, -3.35, 2.05), (side * 1.87, -2.6, 1.0),
        ], [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], bevel=.015)
    box("BombBay", (0, -.1, .34), (.85, 1.9, .06), P["dark"], bevel=.015)
    box("TeamStripe", (0, -1.7, 1.28), (.95, .4, .03), P["team"], bevel=.01)
    cyl("TailGun", (0, -3.35, .70), .06, .50, P["dark"], axis="Y", vertices=12)
    gear([(0, 2.6), (-1.0, -.3), (1.0, -.3)], .40)
    pivot("Muzzle", (0, -.1, .30))


def bastion_helicopter():
    begin("bastion", "Helicopter")
    fuselage_loft("Pod", [
        (-1.15, .82, .38, .38),
        (0.20, .84, .52, .46),
        (1.45, .76, .40, .38),
        (2.05, .66, .20, .20),
    ])
    fuselage_loft("Canopy", [
        (0.25, 1.15, .30, .20),
        (1.05, 1.18, .32, .22),
        (1.75, .96, .22, .14),
    ], P["glass"])
    rod("TailBoom", (0, -1.05, .95), (0, -3.15, 1.12), .18, P["armor"], vertices=16)
    shape("TailFin", [
        (-.06, -3.25, .95), (-.06, -3.05, 1.9), (-.06, -2.6, 1.1),
        (.06, -3.25, .95), (.06, -3.05, 1.9), (.06, -2.6, 1.1),
    ], [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], bevel=.015)
    box("Engine", (0, -.35, 1.42), (.75, 1.25, .42), P["panel"], bevel=.06)
    cyl("Mast", (0, .05, 1.78), .09, .4, P["steel"], vertices=16)
    rotor("RotorM", (0, .05, 2.0), 2.45, 4)
    rotor("RotorT", (.14, -3.12, 1.35), .50, 3, axis="X")
    for side in (-1, 1):
        modeling.airfoil_wing(
            current.name + f"_StubWing_{side}", (side * .45, .05), (side * 1.35, -.12),
            .55, .40, .74, .74, .10, .07, current, P["panel"], root, bevel=.01,
        )
        cyl("RocketPod", (side * 1.15, -.05, .55), .17, .85, P["dark"], axis="Y", vertices=16)
        cyl("PodBand", (side * 1.15, .20, .55), .18, .10, P["team"], axis="Y", vertices=16)
        rod("Skid", (side * .55, -.8, .08), (side * .55, 1.1, .08), .045, P["steel"], vertices=10)
        rod("SkidStrut", (side * .55, .5, .08), (side * .36, .5, .45), .035, P["steel"], vertices=10)
        rod("SkidStrut", (side * .55, -.4, .08), (side * .36, -.4, .45), .035, P["steel"], vertices=10)
    box("TeamStripe", (0, -1.6, 1.12), (.32, .55, .03), P["team"], bevel=.01)
    cyl("ChinTurret", (0, 1.55, .33), .17, .20, P["dark"], vertices=16)
    cyl("ChinGun", (0, 1.95, .30), .05, .60, P["dark"], axis="Y", vertices=12)
    modeling.sensor_pod(current.name + "_NoseTADS", (0, 1.85, .58), .70, (0, 1, 0), current, P["dark"], P["glass"], P["steel"], root)
    pivot("Muzzle", (0, 2.3, .30))


def bastion_flak():
    begin("bastion", "AntiAirVehicle")
    tracks(2.0, 3.0)
    wedge("Hull", 0, 0, .55, 1.75, 3.05, .55)
    box("TeamPlate", (0, -1.1, 1.12), (1.0, .35, .03), P["team"], bevel=.01)
    turret = pivot("TurretPivot", (0, -.1, 1.1))
    wedge("Turret", 0, -.1, 1.1, 1.25, 1.45, .6, P["panel"], turret)
    barrel = pivot("BarrelPivot", (0, .2, 1.45), turret, (math.radians(35), 0, 0))
    for side in (-1, 1):
        lathe("Autocannon", [
            (.09, .30), (.09, .75), (.065, .78), (.065, 1.72),
        ], (side * .28, 0, 1.45), (0, 1, 0), P["dark"], barrel, segments=16)
        cyl("MuzzleBrake", (side * .28, 1.78, 1.45), .09, .18, P["steel"], barrel, "Y", 16)
        box("AmmoDrum", (side * .62, -.1, 1.4), (.24, .7, .4), P["armor"], turret, .04)
    pivot("Muzzle", (0, 1.9, 1.45), barrel)
    rod("RadarMast", (0, -.75, 1.65), (0, -.75, 2.25), .05, P["steel"], turret, vertices=12)
    radar = pivot("SensorPivot", (0, -.75, 2.3), turret)
    box("RadarDish", (0, -.75, 2.35), (.9, .08, .45), P["panel"], radar, .025)
    modeling.sensor_pod(current.name + "_FCS", (.36, .45, 1.62), .75, (0, 1, 0), current, P["dark"], P["glass"], P["steel"], turret)
    for side in (-1, 1):
        modeling.era_tile_rack(current.name + f"_HullERA_{side}", (side * .92, -.95, .85), (side * .92, .95, .85), (side, 0, .2), 4, (.36, .06, .22), current, P["panel"], P["dark"], root)


# --- Helix -----------------------------------------------------------------------

def helix_fighter():
    begin("helix", "TalonInterceptor")
    fuselage_loft("Fuselage", [
        (-2.65, .55, .28, .22),
        (-1.20, .56, .38, .26),
        (0.50, .56, .42, .28),
        (2.00, .55, .32, .22),
        (3.45, .55, .06, .06),
    ])
    fuselage_loft("Canopy", [
        (0.75, .78, .20, .12),
        (1.30, .82, .21, .16),
        (1.85, .74, .14, .10),
    ], P["glass"])
    for side in (-1, 1):
        modeling.airfoil_wing(
            current.name + f"_Wing_{side}", (side * .34, -.52), (side * 2.52, .75),
            .80, .42, .45, .45, .11, .06, current, P["armor"], root, bevel=.01,
        )
        rod("LeadingEdge", (side * .4, -.2, .5), (side * 2.45, .95, .5), .03, P["glass"], vertices=10)
        box("WingTeam", (side * 1.9, .55, .51), (.4, .28, .03), P["team"], bevel=.01)
        modeling.airfoil_wing(
            current.name + f"_Canard_{side}", (side * .34, 1.68), (side * 1.02, 1.60),
            .45, .18, .55, .55, .07, .04, current, P["panel"], root, bevel=.01,
        )
        shape("TailFin", [
            (side * .25, -2.5, .8), (side * .7, -2.6, 1.7), (side * .3, -1.7, .82),
            (side * .35, -2.5, .8), (side * .8, -2.6, 1.7), (side * .4, -1.7, .82),
        ], [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], P["panel"], bevel=.015)
        missiles(side * 1.2, -.1, .3, 1, .9, .07)
        cyl("Exhaust", (side * .25, -2.7, .55), .17, .25, P["dark"], axis="Y", vertices=18)
        cyl("ExhaustGlow", (side * .25, -2.85, .55), .12, .05, P["glass"], axis="Y", vertices=16)
    gear([(0, 1.8), (-.6, -.8), (.6, -.8)], .4)
    pivot("Muzzle", (0, 3.55, .55))


def helix_bomber():
    begin("helix", "ShrikeBomber")
    outline = [(0, 2.6), (-4.1, -1.4), (-3.6, -2.0), (-1.4, -.9), (0, -1.5), (1.4, -.9), (3.6, -2.0), (4.1, -1.4)]
    slab("Wing", [outline[0]] + list(reversed(outline[1:])), .55, .26, P["armor"], bevel=.03)
    wedge("Spine", 0, .35, .78, 1.3, 3.6, .38, P["panel"], taper=(.6, .4))
    wedge("Canopy", 0, 1.55, 1.12, .55, .8, .2, P["glass"], taper=(.5, .3))
    for side in (-1, 1):
        cyl("EngineIntake", (side * .95, .7, .92), .26, .3, P["dark"], axis="Y", vertices=20)
        cyl("EngineGlow", (side * .95, -1.05, .9), .2, .06, P["glass"], axis="Y", vertices=18)
        rod("LeadingEdge", (side * .2, 2.45, .82), (side * 4.0, -1.35, .82), .035, P["glass"], vertices=10)
        box("WingTeam", (side * 2.9, -1.2, .82), (.7, .3, .03), P["team"], bevel=.01)
    box("BombBay", (0, .1, .52), (1.0, 1.6, .05), P["dark"], bevel=.015)
    gear([(0, 1.6), (-1.1, -.6), (1.1, -.6)], .52)
    pivot("Muzzle", (0, .1, .5))


def helix_helicopter():
    begin("helix", "WraithTiltrotor")
    fuselage_loft("Body", [
        (-1.60, .74, .42, .34),
        (-0.20, .78, .58, .42),
        (1.20, .74, .46, .34),
        (2.40, .68, .12, .12),
    ])
    fuselage_loft("Canopy", [
        (0.65, 1.04, .28, .15),
        (1.25, 1.08, .28, .18),
        (1.80, .96, .18, .12),
    ], P["glass"])
    modeling.airfoil_wing(
        current.name + "_WingL", (0, -.02), (-2.15, -.02),
        .68, .56, 1.04, 1.04, .12, .10, current, P["panel"], root, bevel=.015,
    )
    modeling.airfoil_wing(
        current.name + "_WingR", (0, -.02), (2.15, -.02),
        .68, .56, 1.04, 1.04, .12, .10, current, P["panel"], root, bevel=.015,
    )
    for side in (-1, 1):
        lathe("Nacelle", [
            (.20, -.45), (.28, -.35), (.28, .35), (.22, .45),
        ], (side * 2.2, 0, 1.15), (0, 0, 1), P["armor"], segments=20)
        cyl("NacelleGlow", (side * 2.2, 0, .68), .18, .05, P["glass"], vertices=18)
        rotor("RotorLeft" if side < 0 else "RotorRight", (side * 2.2, 0, 1.68), 1.55, 3)
        cyl("RocketPod", (side * 1.15, .1, .62), .15, .8, P["dark"], axis="Y", vertices=16)
        box("WingTeam", (side * 1.6, -.1, 1.12), (.45, .3, .03), P["team"], bevel=.01)
        shape("TailFin", [
            (side * .3, -1.6, .9), (side * .55, -1.75, 1.55), (side * .35, -1.05, .95),
            (side * .4, -1.6, .9), (side * .65, -1.75, 1.55), (side * .45, -1.05, .95),
        ], [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], P["panel"], bevel=.015)
    cyl("ChinGun", (0, 1.8, .32), .05, .55, P["dark"], axis="Y", vertices=12)
    pivot("Muzzle", (0, 2.1, .32))


def helix_aa():
    begin("helix", "HaloSkimmer")
    loft("Hull", [
        modeling.rounded_rect_ring(1.85, 3.05, .34, 0, 0, .30, 3),
        modeling.rounded_rect_ring(1.94, 3.16, .36, 0, 0, .56, 3),
        modeling.rounded_rect_ring(1.52, 2.65, .28, 0, -.06, .86, 3),
    ], P["armor"], bevel=.025)
    for side in (-1, 1):
        box("SkirtGlow", (side * .9, 0, .3), (.08, 2.6, .06), P["glass"], bevel=.01)
        box("Sponson", (side * 1.0, -.2, .45), (.35, 2.0, .35), P["panel"], bevel=.05)
    box("TeamPlate", (0, -1.15, .87), (.9, .3, .03), P["team"], bevel=.01)
    modeling.sensor_pod(current.name + "_BowOptic", (0, 1.56, .66), .75, (0, 1, 0), current, P["dark"], P["glass"], P["steel"], root)
    turret = pivot("TurretPivot", (0, -.15, .85))
    wedge("Mount", 0, -.15, .85, 1.0, 1.1, .35, P["panel"], turret)
    barrel = pivot("BarrelPivot", (0, 0, 1.25), turret, (math.radians(40), 0, 0))
    for side in (-1, 1):
        box("Launcher", (side * .42, .1, 1.3), (.42, 1.15, .55), P["armor"], barrel, .05)
        for row in range(2):
            for col in range(2):
                cyl("Cell", (side * .42 + (col - .5) * .18, .69, 1.18 + row * .24), .065, .04, P["glass"], barrel, "Y", 14)
    pivot("Muzzle", (0, .8, 1.3), barrel)
    halo = pivot("SensorPivot", (0, -.75, 1.75), turret)
    bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=8, location=(0, -.75, 1.75),
                                     major_radius=.45, minor_radius=.04)
    attach(bpy.context.object, "HaloRing", P["glass"], halo, smooth=True, sharp_angle=50.0)
    rod("HaloMast", (0, -.75, 1.2), (0, -.75, 1.72), .04, P["steel"], turret, vertices=12)


# --- Frontier --------------------------------------------------------------------

def frontier_fighter():
    begin("frontier", "HornetFighter")
    fuselage_loft("Fuselage", [
        (-2.25, .66, .34, .30),
        (-0.80, .68, .48, .38),
        (1.00, .68, .50, .38),
        (2.25, .68, .36, .28),
        (2.85, .68, .08, .08),
    ])
    fuselage_loft("Canopy", [
        (0.65, .98, .26, .14),
        (1.15, 1.06, .27, .20),
        (1.65, .98, .18, .12),
    ], P["glass"])
    for side in (-1, 1):
        modeling.airfoil_wing(
            current.name + f"_Wing_{side}", (side * .46, -.30), (side * 2.22, -.60),
            1.30, .54, .56, .56, .14, .08, current, P["armor"], root, bevel=.015,
        )
        box("Patch", (side * 1.35, -.5, .64), (.45, .35, .03), P["panel"], bevel=.008)
        box("WingTeam", (side * 1.95, -.6, .64), (.3, .4, .03), P["team"], bevel=.008)
        lathe("WingTank", [
            (.06, -.52), (.13, -.42), (.13, .42), (.06, .52),
        ], (side * 2.25, -.6, .5), (0, 1, 0), P["panel"], segments=16)
        missiles(side * 1.25, -.55, .32, 1, .8, .07)
    shape("TailFin", [
        (-.06, -2.2, .95), (-.06, -2.35, 1.85), (-.06, -1.5, 1.0),
        (.06, -2.2, .95), (.06, -2.35, 1.85), (.06, -1.5, 1.0),
    ], [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], bevel=.015)
    modeling.airfoil_wing(
        current.name + "_StabL", (0, -2.25), (-1.12, -2.25), .45, .34, .78, .78, .08, .06, current, P["armor"], root, bevel=.01,
    )
    modeling.airfoil_wing(
        current.name + "_StabR", (0, -2.25), (1.12, -2.25), .45, .34, .78, .78, .08, .06, current, P["armor"], root, bevel=.01,
    )
    cyl("Exhaust", (0, -2.35, .70), .28, .3, P["dark"], axis="Y", vertices=20)
    for side in (-1, 1):
        cyl("Gun", (side * .4, 1.9, .45), .05, .6, P["dark"], axis="Y", vertices=12)
    gear([(0, 1.6), (-.7, -.5), (.7, -.5)], .42)
    pivot("Muzzle", (0, 2.95, .65))


def frontier_bomber():
    begin("frontier", "BuzzardBomber")
    fuselage_loft("Pod", [
        (-1.05, .85, .52, .42),
        (0.70, .90, .64, .48),
        (2.35, .88, .50, .40),
        (2.95, .88, .22, .20),
    ])
    fuselage_loft("Nose", [
        (2.35, .90, .48, .38),
        (2.85, .88, .34, .28),
        (3.05, .88, .08, .08),
    ], P["glass"])
    modeling.airfoil_wing(
        current.name + "_WingL", (0, 0), (-3.9, 0), .92, .76, 1.26, 1.26, .18, .12, current, P["armor"], root, bevel=.015,
    )
    modeling.airfoil_wing(
        current.name + "_WingR", (0, 0), (3.9, 0), .92, .76, 1.26, 1.26, .18, .12, current, P["armor"], root, bevel=.015,
    )
    for side in (-1, 1):
        rod("Boom", (side * 1.5, .3, 1.0), (side * 1.5, -3.2, 1.05), .16, P["panel"], vertices=14)
        lathe("Engine", [
            (.22, -.60), (.30, -.48), (.30, .48), (.24, .60),
        ], (side * 1.5, .1, 1.0), (0, 1, 0), P["armor"], segments=18)
        rotor("RotorLeft" if side < 0 else "RotorRight", (side * 1.5, -.6, 1.0), .7, 3, axis="Y")
        shape("TailFin", [
            (side * 1.5, -3.25, 1.05), (side * 1.5, -3.3, 2.0), (side * 1.5, -2.55, 1.1),
            (side * 1.62, -3.25, 1.05), (side * 1.62, -3.3, 2.0), (side * 1.62, -2.55, 1.1),
        ], [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], bevel=.015)
        box("WingTeam", (side * 3.3, 0, 1.36), (.7, .5, .03), P["team"], bevel=.01)
    slab("Stabilizer", [(-1.6, -3.3), (1.6, -3.3), (1.6, -2.9), (-1.6, -2.9)], 1.7, .07, P["armor"], bevel=.015)
    box("BombCradle", (0, .5, .35), (.7, 1.6, .12), P["dark"], bevel=.025)
    for y in (-.1, .45, 1.0):
        cyl("Bomb", (0, y, .26), .11, .42, P["dark"], axis="Y", vertices=14)
    gear([(0, 2.0), (-1.5, .2), (1.5, .2)], .65)
    pivot("Muzzle", (0, .5, .25))


def frontier_aa():
    begin("frontier", "RipsawTruck")
    wheels(2.0, (-1.15, .05, 1.15), .4)
    box("Chassis", (0, 0, .62), (1.8, 3.4, .28), P["dark"], bevel=.035)
    wedge("Cab", 0, 1.25, .76, 1.75, 1.0, .85, P["armor"], taper=(.9, .75))
    box("Windshield", (0, 1.72, 1.32), (1.4, .05, .38), P["glass"], bevel=.01)
    box("Flatbed", (0, -.55, .82), (1.85, 2.1, .14), P["panel"], bevel=.025)
    for side in (-1, 1):
        box("Sideboard", (side * .9, -.55, 1.0), (.06, 2.1, .32), P["armor"], bevel=.015)
    box("TeamPlate", (0, 1.25, 1.62), (.9, .45, .03), P["team"], bevel=.01)
    modeling.sensor_pod(current.name + "_CabOptics", (.42, 1.55, 1.66), .70, (0, 1, 0), current, P["dark"], P["glass"], P["steel"], root)
    modeling.era_tile_rack(current.name + "_GrillArmor", (-.58, 1.80, .86), (.58, 1.80, .86), (0, 1, 0), 3, (.32, .06, .22), current, P["panel"], P["dark"], root)
    turret = pivot("TurretPivot", (0, -.65, 1.0))
    cyl("Ring", (0, -.65, 1.05), .55, .12, P["steel"], turret, vertices=24)
    box("GunShield", (0, -.3, 1.4), (.9, .08, .55), P["armor"], turret, .035)
    barrel = pivot("BarrelPivot", (0, -.55, 1.35), turret, (math.radians(30), 0, 0))
    for side in (-1, 1):
        lathe("Autocannon", [
            (.08, -.35), (.08, .15), (.06, .18), (.06, 1.05),
        ], (side * .18, 0, 1.35), (0, 1, 0), P["dark"], barrel, segments=16)
    box("Receiver", (0, -.55, 1.35), (.55, .6, .32), P["steel"], barrel, .035)
    pivot("Muzzle", (0, 1.1, 1.35), barrel)
    pivot("DamageSocket", (.65, 1.35, 1.3))
    for rank in (1, 2):
        group = pivot(f"ScrapRank{rank}", (0, 0, 1.0))
        y = -.6 if rank == 1 else 1.1
        for side in (-1, 1):
            box(f"SalvagePlate{rank}", (side * .97, y, 1.05), (.08, .7, .36),
                P["panel"] if rank == 1 else P["steel"], group, .025)
        if rank == 2:
            box("SalvageBumper", (0, 1.8, .92), (1.3, .1, .3), P["panel"], group, .025)


bastion_fighter()
bastion_bomber()
bastion_helicopter()
bastion_flak()
helix_fighter()
helix_bomber()
helix_helicopter()
helix_aa()
frontier_fighter()
frontier_bomber()
frontier_aa()

manifest = []
for faction, name, collection, asset_root in assets:
    if BUILD_FACTION is not None and faction != BUILD_FACTION:
        continue
    if "--damage-only" in sys.argv and name not in {"RipsawTruck", "HaloSkimmer", "AntiAirVehicle"}:
        continue
    if name in {"HaloSkimmer", "AntiAirVehicle"}:
        socket = bpy.data.objects.new(name + "_DamageSocket", None)
        collection.objects.link(socket)
        socket.parent = asset_root
        socket.location = (.45, -.6, 1.0)
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
    models, _icons = OUTPUT[faction]
    bpy.ops.export_scene.gltf(
        filepath=str(models / (name + ".glb")), export_format="GLB", use_selection=True,
        export_animations=False, export_yup=True, export_cameras=False, export_lights=False,
        export_vertex_color="ACTIVE",
    )
    for obj in live:
        bpy.data.objects.remove(obj, do_unlink=True)
    manifest.append({"faction": faction, "name": name, "triangles": triangles})
    collection.hide_render = True


def render_catalogue():
    world = bpy.data.worlds.new("Studio")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.22, .27, .34, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .45
    for light_name, loc, power, color in (("Key", (4, 6, 11), 1800, (1, .88, .72)),
                                          ("Fill", (-6, 1, 6), 1500, (.7, .83, 1)),
                                          ("Rim", (3, -6, 8), 2100, (1, .92, .78))):
        data = bpy.data.lights.new(light_name, "AREA")
        data.energy = power
        data.shape = "DISK"
        data.size = 7
        data.color = color
        obj = bpy.data.objects.new(light_name, data)
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
    for faction, name, collection, asset_root in assets:
        collection.hide_render = False
        points = [obj.matrix_world @ Vector(p) for obj in collection.objects if obj.type == "MESH" for p in obj.bound_box]
        lo = Vector([min(p[i] for p in points) for i in range(3)])
        hi = Vector([max(p[i] for p in points) for i in range(3)])
        center = (lo + hi) / 2
        camera.location = center + Vector((9, 12, 10))
        camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
        camera_data.ortho_scale = max(hi - lo) * 1.45
        _models, icons = OUTPUT[faction]
        scene.render.filepath = str(icons / (name + ".png"))
        bpy.ops.render.render(write_still=True)
        collection.hide_render = True

    for index, (faction, name, collection, asset_root) in enumerate(assets):
        collection.hide_render = False
        asset_root.location = Vector(((index % 4 - 1.5) * 10, (index // 4 - 1) * 10, 0))
    camera.location = (30, 38, 40)
    camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = 46
    scene.render.film_transparent = False
    scene.render.resolution_x = 1800
    scene.render.resolution_y = 1400
    scene.cycles.samples = 32
    SOURCE.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(SOURCE / "aircraft-catalogue.png")
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "aircraft.blend"))
    bpy.ops.render.render(write_still=True)
    (SOURCE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("Air-combat assets complete:", len(manifest))


if BUILD_FACTION is None:
    render_catalogue()
else:
    print(f"Air-combat models complete: {BUILD_FACTION}, {len(manifest)} assets")
