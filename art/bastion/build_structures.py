"""Bastion v2: nine fortified-industrial silhouettes with contoured hard-surface detail.

blender --background --factory-startup --python-exit-code 1 --python art/bastion/build_structures.py
All dimensions are Blender metres; game scene scales preserve existing footprints.
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
import markings  # noqa: E402
import modeling  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/bastion/structures-v2"
ICONS = ROOT / "assets/ui/bastion/structures-v2"
SOURCE = ROOT / "art/bastion/structures-v2"
for directory in (OUT, ICONS, SOURCE):
    directory.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
bpy.context.preferences.filepaths.save_version = 0
scene.unit_settings.system = "METRIC"
assets = []
current = None
root = None


def mat(name, color, metallic=.3, roughness=.55, emission=0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    for key, value in {
        "Base Color": (*color, 1),
        "Metallic": metallic,
        "Roughness": roughness,
        "Emission Color": (*color, 1),
        "Emission Strength": emission,
    }.items():
        bsdf.inputs[key].default_value = value
    return material


ARMOR = mat("Bastion_FortressOlive", (.17, .20, .155))
PANEL = mat("Bastion_CastArmor", (.30, .33, .25))
DARK = mat("Bastion_InnerSteel", (.033, .046, .048), .65)
STEEL = mat("Bastion_MachinedSteel", (.33, .39, .40), .8, .32)
TEAM = mat("TeamColor_Bastion", (.65, .28, .015))
CONCRETE = mat("Bastion_Precast", (.29, .30, .26), 0, .85)
WHITE = mat("Bastion_Stencil", (.84, .82, .62), 0)
GLASS = mat("Bastion_Optics", (.12, .62, .72), .4, .25, .6)
HEAT = mat("Bastion_Core", (.98, .29, .04), .2, .4, 1.5)


def begin(name):
    global current, root
    current = bpy.data.collections.new(name)
    scene.collection.children.link(current)
    root = bpy.data.objects.new(name, None)
    current.objects.link(root)
    root["faction"] = "Bastion"
    root["forward"] = "-Z in Godot"
    assets.append((name, current, root))


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
    vertices = max(vertices, 18 if radius >= .15 else 12)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=xyz)
    obj = bpy.context.object
    if axis == "Y":
        obj.rotation_euler.x = math.pi / 2
    elif axis == "X":
        obj.rotation_euler.y = math.pi / 2
    return attach(obj, name, material, parent, bevel=0, smooth=True, sharp_angle=35.0)


def rod(name, a, b, radius=.055, material=STEEL, parent=None, vertices=12):
    delta = Vector(b) - Vector(a)
    obj = cyl(name, (Vector(a) + Vector(b)) / 2, radius, delta.length, material, parent, vertices=vertices)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return obj


def shape(name, vertices, faces, material=ARMOR, parent=None, bevel=0.0, smooth=True):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    current.objects.link(obj)
    return attach(obj, name, material, parent, bevel=bevel, smooth=smooth)


def loft(name, rings, material=ARMOR, parent=None, bevel=.025, sharp_angle=36.0):
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


def octagon(name, xyz, width, depth, height, material=ARMOR, taper=1.0, parent=None, bevel=.025):
    x, y, z = xyz
    r0 = modeling.rounded_rect_ring(width, depth, min(width, depth) * .18, x, y, z, 3)
    r1 = modeling.rounded_rect_ring(width * taper, depth * taper, min(width, depth) * .18 * taper, x, y, z + height, 3)
    return loft(name, [r0, r1], material, parent, bevel=bevel)


def pivot(name, xyz, parent=None):
    obj = bpy.data.objects.new(current.name + "_" + name, None)
    current.objects.link(obj)
    obj.location = xyz
    bpy.context.view_layer.update()
    matrix = obj.matrix_world.copy()
    obj.parent = parent or root
    obj.matrix_world = matrix
    return obj


def base(width, depth):
    octagon("Footing", (0, 0, 0), width, depth, .18, CONCRETE, .98, bevel=.02)
    octagon("Foundation", (0, 0, .18), width * .95, depth * .95, .16, DARK, .97, bevel=.02)


def vent(x, y, z, width, count=5):
    modeling.louver_grille(current.name + "_Vent", (x, y, z), width, .54, count, current, DARK, STEEL, root)


def stencil(text, xyz, size=.4, rot=None, parent=None):
    data = bpy.data.curves.new("Stencil", "FONT")
    data.body = text
    data.align_x = "CENTER"
    data.size = size
    data.extrude = .002
    obj = bpy.data.objects.new("Stencil", data)
    current.objects.link(obj)
    obj.location = xyz
    obj.rotation_euler = rot or (0, 0, math.pi)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj.select_set(False)
    attach(obj, "Stencil", WHITE, parent, smooth=False)


def arch(name, x, y, z, radius, length, material, parent=None):
    vertices = []
    steps = 20
    for dy in [-length / 2, length / 2]:
        for r in [radius, radius - .16]:
            vertices += [(x + r * math.cos(i * math.pi / steps), y + dy, z + r * math.sin(i * math.pi / steps))
                         for i in range(steps + 1)]
    n = steps + 1
    faces = []
    for i in range(steps):
        faces += [(i, i + 1, 2 * n + i + 1, 2 * n + i),
                  (n + i, 3 * n + i, 3 * n + i + 1, n + i + 1),
                  (i, n + i, n + i + 1, i + 1),
                  (2 * n + i, 2 * n + i + 1, 3 * n + i + 1, 3 * n + i)]
    faces += [(0, 2 * n, 3 * n, n), (n - 1, 2 * n - 1, 4 * n - 1, 3 * n - 1)]
    return shape(name, vertices, faces, material, parent, bevel=.015, smooth=True)


def hq():
    begin("CommandCenter")
    base(5.7, 5.7)
    octagon("BatteredCurtainWall", (0, 0, .34), 5.0, 4.8, 1.65, ARMOR, .78, bevel=.04)
    octagon("Crown", (0, -.12, 1.99), 4.05, 3.85, .26, PANEL, .96, bevel=.03)
    octagon("CommandKeep", (0, -.45, 2.25), 2.55, 2.55, 1.54, ARMOR, .86, bevel=.04)
    octagon("ObservationBand", (0, -.45, 3.79), 2.30, 2.30, .25, GLASS, 1.0, bevel=.01)
    octagon("BattlementCap", (0, -.45, 4.04), 2.74, 2.74, .36, PANEL, .86, bevel=.03)
    for side in [-1, 1]:
        for y in [-1.65, 1.60]:
            octagon("CornerBastion", (side * 1.9, y, .34), 1.18, 1.25, 2.25, PANEL, .74, bevel=.035)
            box("RecognitionPanel", (side * 1.9, y + .44, 1.85), (.58, .06, .64), TEAM, bevel=.015)
        box("RoofStripe", (side * 1.42, 0, 2.28), (.23, 2.48, .05), TEAM, bevel=.01)
    # Recessed blast gate frame & twin doors
    box("GateFrame", (0, 2.15, 1.00), (1.46, .24, 1.36), DARK, bevel=.03)
    for x in [-.32, .32]:
        box("BlastDoor", (x, 2.22, .97), (.58, .08, 1.12), STEEL, bevel=.025)
    box("GateLintel", (0, 2.28, 1.65), (1.56, .22, .18), TEAM, bevel=.03)
    loft("EntranceRamp", [
        modeling.rounded_rect_ring(1.65, .86, .08, 0, 2.42, .18, 2),
        modeling.rounded_rect_ring(1.46, .70, .06, 0, 2.36, .35, 2),
    ], CONCRETE, bevel=.02)
    cyl("CommsPedestal", (-.55, -.60, 4.53), .16, .30, STEEL, vertices=18)
    box("CommsPanelHousing", (-.55, -.60, 4.93), (.64, .22, .62), PANEL, bevel=.04)
    box("CommsPanelFace", (-.55, -.476, 4.93), (.50, .025, .48), DARK, bevel=.015)
    for x in [-.70, -.55, -.40]:
        box("CommsArrayElement", (x, -.454, 4.93), (.055, .02, .32), STEEL, bevel=.008)
    lathe("Beacon", [(.12, 0), (.12, .14), (.08, .22), (0, .24)], (.65, -.45, 4.42), (0, 0, 1), GLASS, segments=18)
    modeling.cupola_hatch(current.name + "_RoofHatch", (.65, -.95, 4.40), .34, .18, current, PANEL, DARK, GLASS, root)
    modeling.sensor_pod(current.name + "_Optics", (0, .65, 4.18), 1.0, (0, 1, 0), current, DARK, GLASS, STEEL, root)
    for side in (-1, 1):
        modeling.hvac_fan_unit(current.name + f"_HVAC_{side}", (side * 1.45, -.85, 2.38), .72, .72, .26, current, PANEL, DARK, STEEL, root)
        modeling.era_tile_rack(current.name + f"_SideERA_{side}", (side * 2.28, -.95, 1.05), (side * 2.28, .95, 1.05), (side, 0, .25), 5, (.32, .10, .38), current, PANEL, DARK, root)
        modeling.sweep_tube(current.name + f"_Conduit_{side}", [(side * 1.15, -.45, 3.35), (side * 1.55, -.45, 3.35), (side * 1.55, -.45, 2.22)], .065, 10, current, STEEL, root)
    stencil("01", (0, 2.29, 1.90), .43, (math.pi / 2, 0, math.pi))


def barracks():
    begin("Barracks")
    base(4.75, 4.75)
    for x in [-1.12, 1.12]:
        loft("BunkerPlinth", [
            modeling.rounded_rect_ring(1.98, 3.42, .12, x, -.25, .34, 2),
            modeling.rounded_rect_ring(1.88, 3.32, .12, x, -.25, 1.03, 2),
        ], CONCRETE, bevel=.025)
        arch("ArmoredVault", x, -.25, 1.03, 1.0, 3.35, ARMOR)
        for y in [-1.85, -.85, .15, 1.35]:
            arch("VaultRib", x, y, 1.03, 1.06, .14, PANEL)
        box("Portal", (x, 1.39, .96), (1.35, .12, 1.25), DARK, bevel=.03)
        box("Door", (x, 1.45, .84), (.92, .08, .95), STEEL, bevel=.025)
        box("UnitPanel", (x, 1.50, 1.40), (.88, .09, .16), TEAM, bevel=.02)
        vent(x, -.40, 2.06, .62)
    box("EntryApron", (0, 1.85, .28), (3.8, .70, .17), CONCRETE, bevel=.03)
    for side in (-1, 1):
        modeling.sensor_pod(current.name + f"_GateCam_{side}", (side * 1.12, 1.48, 1.66), .7, (0, 1, 0), current, DARK, GLASS, STEEL, root)
        modeling.era_tile_rack(current.name + f"_WallERA_{side}", (side * 2.10, -1.35, .72), (side * 2.10, .85, .72), (side, 0, 0), 5, (.36, .10, .34), current, PANEL, DARK, root)
    modeling.sweep_tube(current.name + "_BridgePipe", [(-1.12, -.95, 2.08), (-1.12, -.95, 2.38), (1.12, -.95, 2.38), (1.12, -.95, 2.08)], .065, 10, current, STEEL, root)
    rod("Flagpole", (0, -.50, .35), (0, -.50, 3.15), .030, STEEL, vertices=12)
    box("Banner", (.34, -.50, 2.79), (.65, .025, .62), TEAM, bevel=0)
    stencil("02", (-1.12, .20, 2.098), .4)


def factory():
    begin("VehicleFactory")
    base(6.1, 6.1)
    box("AssemblyFloor", (0, 0, .38), (4.6, 5.5, .18), STEEL, bevel=.03)
    for x in [-2.12, 2.12]:
        octagon("ArmoredMachineBank", (x, -.05, .40), 1.35, 4.9, 1.65, ARMOR, .86, bevel=.035)
        for y in [-1.9, -.75, .4, 1.55]:
            vent(x, y, 2.065, .75)
        box("SafetyStripe", (x, 2.25, 1.42), (.85, .10, .42), TEAM, bevel=.02)
        for y in [-1.8, 1.45]:
            box("GantryLeg", (x, y, 2.50), (.26, .35, 2.05), PANEL, bevel=.035)
            rod("GantryBrace", (x, y, 1.80), (x * .6, y, 3.40), .08, STEEL, vertices=12)
        box("CraneRail", (x, -.18, 3.51), (.28, 4.15, .24), TEAM, bevel=.03)
    box("OverheadCrane", (0, -.45, 3.57), (4.65, .55, .28), PANEL, bevel=.04)
    box("HoistCarriage", (.45, -.45, 3.36), (.60, .68, .25), TEAM, bevel=.03)
    rod("HoistCable", (.45, -.45, 3.30), (.45, -.45, 2.43), .025, DARK, vertices=10)
    rod("HoistHook", (.45, -.45, 2.43), (.65, -.45, 2.58), .055, STEEL, vertices=10)
    octagon("UnfinishedHull", (0, -.60, .59), 1.65, 2.40, .65, PANEL, .75, bevel=.03)
    for x in [-.95, .95]:
        box("AssemblyTrack", (x, -.60, .64), (.26, 2.45, .30), DARK, bevel=.03)
    for y in [-2.15, -1.6, -1.05, -.5, .05, .6, 1.15, 1.7, 2.25]:
        cyl("Roller", (0, y, .52), .08, 2.45, DARK, axis="X", vertices=14)
    for side in (-1, 1):
        modeling.hvac_fan_unit(current.name + f"_HVAC_{side}", (side * 2.12, -1.15, 2.18), .85, .85, .28, current, PANEL, DARK, STEEL, root)
        modeling.era_tile_rack(current.name + f"_BankERA_{side}", (side * 2.74, -1.85, 1.12), (side * 2.74, 1.65, 1.12), (side, 0, .18), 6, (.45, .10, .42), current, PANEL, DARK, root)
    modeling.sensor_pod(current.name + "_CraneCam", (.45, -.10, 3.36), .85, (0, 1, -.25), current, DARK, GLASS, STEEL, root)
    stencil("03", (0, 1.47, .491), .5)


def airfield():
    begin("AircraftFactory")
    base(6.1, 6.1)
    octagon("RaisedFlightDeck", (.3, .3, .34), 5.25, 5.25, .62, ARMOR, .94, bevel=.03)
    octagon("DeckRim", (.3, .3, .96), 5.25, 5.25, .13, PANEL, .99, bevel=.02)
    cyl("LandingCircle", (.55, .65, 1.101), 1.63, .014, WHITE, vertices=48)
    cyl("LandingInset", (.55, .65, 1.115), 1.48, .014, DARK, vertices=48)
    for x in [-.05, 1.15]:
        box("HelipadMark", (x, .65, 1.131), (.20, 1.8, .018), WHITE, bevel=0)
    box("HelipadCross", (.55, .65, 1.131), (1.3, .22, .018), WHITE, bevel=0)
    octagon("TowerStem", (-1.95, -1.7, .34), 1.05, 1.1, 3.12, ARMOR, .77, bevel=.035)
    octagon("TowerCab", (-1.95, -1.7, 3.46), 1.65, 1.65, .54, GLASS, 1.1, bevel=.015)
    octagon("TowerRoof", (-1.95, -1.7, 4), 1.92, 1.92, .19, PANEL, .87, bevel=.03)
    rod("ControlMast", (-1.95, -1.7, 4.18), (-1.95, -1.7, 5.30), .03, STEEL, vertices=10)
    lathe("Beacon", [(.10, 0), (.10, .14), (.06, .20), (0, .22)], (-1.95, -1.7, 5.22), (0, 0, 1), GLASS, segments=16)
    for y in [-1.65, -.65, .35, 1.35, 2.35]:
        for x in [-2.27, 2.77]:
            cyl("DeckLight", (x, y, 1.2), .065, .15, GLASS, vertices=14)
    for x in [-.2, .8, 1.8]:
        box("DeckHazard", (x, -2.19, 1.12), (.5, .28, .025), TEAM, bevel=0)
    modeling.hvac_fan_unit(current.name + "_TowerHVAC", (-1.95, -2.55, .72), .85, .65, .75, current, PANEL, DARK, STEEL, root)
    modeling.sensor_pod(current.name + "_TowerOptics", (-1.95, -.86, 3.92), 1.0, (0, 1, 0), current, DARK, GLASS, STEEL, root)
    modeling.sweep_tube(current.name + "_FuelPipe", [(-1.95, -2.55, 1.10), (-1.45, -2.55, 1.10), (-1.45, -2.05, 1.10)], .06, 10, current, STEEL, root)
    stencil("04", (.5, -1.72, 1.12), .42)


def reactor():
    begin("PowerPlant")
    base(4.65, 4.65)
    cyl("ReactorSump", (0, 0, .57), 1.45, .48, DARK, vertices=28)
    lathe("ContainmentVessel", [
        (1.02, .75), (1.06, 1.15), (0.98, 1.50), (1.05, 1.95), (1.00, 2.45), (0.92, 2.70),
    ], (0, 0, 0), (0, 0, 1), STEEL, segments=28)
    for z in [.80, 1.25, 1.70, 2.15, 2.60]:
        cyl("ReactorCollar", (0, 0, z), 1.17, .18, ARMOR, vertices=28)
    for angle in range(0, 360, 60):
        a = math.radians(angle)
        x, y = math.cos(a), math.sin(a)
        rod("ThermalConduit", (x, y, .90), (x, y, 2.50), .075, HEAT, vertices=14)
        octagon("CoolingButtress", (x * 1.62, y * 1.62, .34), .68, .68, 1.55, PANEL, .72, bevel=.03)
        rod("ExternalFeed", (x * 1.62, y * 1.62, 1.75), (x, y, 2.10), .11, DARK, vertices=14)
    cyl("TopShield", (0, 0, 2.92), 1.35, .40, ARMOR, vertices=24)
    cyl("TurbineWell", (0, 0, 3.135), .85, .05, DARK, vertices=24)
    for x in [-.5, -.25, 0, .25, .5]:
        box("TurbineGrille", (x, 0, 3.18), (.08, 1.16, .10), STEEL, bevel=.01)
    for x in [-1.42, 1.42]:
        cyl("ExhaustStack", (x, -1.15, 2.72), .26, 1.65, DARK, vertices=20)
        cyl("StackLip", (x, -1.15, 3.55), .33, .13, TEAM, vertices=20)
    stencil("05", (0, 1.83, .36), .4)


def lab():
    begin("CommandLab")
    base(4.85, 4.85)
    octagon("CommsBunker", (0, 0, .34), 4.2, 3.7, 1.15, ARMOR, .82, bevel=.04)
    octagon("ReinforcedRoof", (0, 0, 1.49), 3.65, 3.2, .19, PANEL, .98, bevel=.03)
    cyl("DishTurntable", (0, -.40, 1.91), .73, .46, DARK, vertices=24)
    sensor = pivot("SensorPivot", (0, -.40, 2.0))
    rod("DishSupport", (-.5, -.4, 1.96), (-.5, -.4, 2.80), .13, STEEL, sensor, vertices=14)
    rod("DishSupport", (.5, -.4, 1.96), (.5, -.4, 2.80), .13, STEEL, sensor, vertices=14)
    center = Vector((0, -.4, 2.78))
    axis = Vector((0, .68, .73))
    across = Vector((1, 0, 0))
    up = axis.cross(across)
    vertices = []
    rings, segments, radius = 6, 32, 1.65
    for j in range(rings + 1):
        r = max(.001, radius * j / rings)
        for i in range(segments):
            angle = TAU * i / segments
            point = center + across * (r * math.cos(angle)) + up * (r * math.sin(angle)) + axis * (.30 * r * r)
            vertices.append(tuple(point))
    faces = []
    for j in range(rings):
        for i in range(segments):
            faces.append((j * segments + i, j * segments + (i + 1) % segments,
                          (j + 1) * segments + (i + 1) % segments, (j + 1) * segments + i))
    bowl = shape("RadarReflector", vertices, faces, PANEL, sensor, smooth=True)
    solidify = bowl.modifiers.new("Reflector thickness", "SOLIDIFY")
    solidify.thickness = .065
    for i in range(segments):
        rod("DishRim", vertices[-segments + i], vertices[-segments + (i + 1) % segments], .035, STEEL, sensor, vertices=10)
    focus = center + axis * 1.28
    for i in [2, 13, 23]:
        rod("FeedStrut", vertices[-segments + i], focus, .025, DARK, sensor, vertices=10)
    cyl("Receiver", focus, .13, .20, GLASS, sensor, vertices=16)
    for x in [-1.33, 1.33]:
        modeling.recessed_viewport(current.name + f"_DataWindow_{x}", (x, 1.47, 1.09), .50, .20, .14, (0, 1, 0), current, DARK, GLASS, root)
    box("CommsID", (0, 1.49, 1.05), (.65, .06, .58), TEAM, bevel=.02)
    stencil("06", (0, 1.526, .95), .34, (math.pi / 2, 0, math.pi))


def depot():
    begin("RepairDepot")
    base(5.4, 5.4)
    # Fortified armored recovery turntable + corner crane turret (distinct from VehicleFactory)
    cyl("RecoveryTurntable", (0, .45, .42), 1.85, .16, STEEL, vertices=32)
    cyl("TurntableRing", (0, .45, .51), 1.55, .04, TEAM, vertices=32)
    for ang in range(0, 360, 45):
        a = math.radians(ang)
        box("PadTread", (math.cos(a) * 1.15, .45 + math.sin(a) * 1.15, .52), (.36, .14, .03), DARK, bevel=0, rot=(0, 0, a))
    octagon("PartsBunker", (0, -1.65, .34), 4.4, 1.45, 1.55, ARMOR, .85, bevel=.04)
    vent(0, -1.65, 1.90, 1.8, 6)
    box("BunkerDoor", (-.9, -.90, .95), (1.1, .08, 1.1), DARK, bevel=.02)
    # Single heavy corner armored recovery crane turret
    octagon("CraneBastion", (-1.85, .95, .34), 1.15, 1.15, 1.35, PANEL, .82, bevel=.035)
    arm = pivot("RepairArmLeft", (-1.85, .95, 1.70))
    cyl("CraneTurret", (-1.85, .95, 1.72), .48, .34, TEAM, arm, vertices=20)
    rod("ServiceBoom", (-1.85, .95, 1.80), (-.65, .60, 2.95), .15, PANEL, arm, vertices=14)
    rod("LiftPiston", (-1.65, .85, 1.72), (-1.05, .72, 2.55), .06, STEEL, arm, vertices=12)
    cyl("ToolJoint", (-.65, .60, 2.95), .20, .28, DARK, arm, axis="Y", vertices=18)
    rod("ServiceForearm", (-.65, .60, 2.95), (-.10, .45, 2.05), .10, TEAM, arm, vertices=14)
    rod("ToolTip", (-.10, .45, 2.05), (0, .45, 1.65), .045, STEEL, arm, vertices=12)
    vertices, faces = markings.service_gear(1.15, -.88, 1.15, size=.78)
    shape("ServiceGear", vertices, faces, WHITE, smooth=False)
    box("WorkLight", (1.85, 1.85, .50), (.32, .32, .32), GLASS, bevel=.04)
    stencil("07", (0, 2.25, .352), .45)


def defense(air=False):
    begin("AntiAirTurret" if air else "AntiGroundTurret")
    base(2.9, 2.9)
    for angle in [0, math.pi / 2, math.pi, math.pi * 1.5]:
        x, y = math.cos(angle), math.sin(angle)
        octagon("Anchor", (x * 1.05, y * 1.05, .34), .64, .64, .48, PANEL, .80, bevel=.025)
    cyl("ArmoredBarbette", (0, 0, .77), .95, .86, ARMOR, vertices=24)
    cyl("TraverseRing", (0, 0, 1.23), 1.02, .16, STEEL, vertices=28)
    turret = pivot("TurretPivot", (0, 0, 1.32))
    octagon("TurretShell", (0, -.15, 1.30), 1.78, 1.45, .53, ARMOR, .74, turret, bevel=.03)
    barrel = pivot("BarrelPivot", (0, .20, 1.70), turret)
    if air:
        for x in [-.75, .75]:
            box("MissileCradle", (x, .02, 2.14), (.70, 1.48, .84), TEAM, barrel, .06, (-.24, 0, 0))
            for dx in [-.17, .17]:
                for z in [1.94, 2.28]:
                    cyl("LaunchTube", (x + dx, .80, z), .14, .19, DARK, barrel, axis="Y", vertices=18)
                    lathe("MissileNose", [(.075, 0), (.075, .04), (0, .11)], (x + dx, .87, z), (0, 1, 0), WHITE, barrel, segments=14)
        rod("RadarMast", (0, -.40, 1.80), (0, -.40, 2.80), .06, STEEL, turret, vertices=12)
        box("SearchArray", (0, -.40, 2.91), (1.08, .16, .39), PANEL, turret, .03)
        box("SearchSensor", (0, -.30, 2.91), (.81, .03, .18), GLASS, turret, .01)
        pivot("Muzzle", (.58, 1.03, 2.30), barrel)
    else:
        box("Mantlet", (0, .35, 1.70), (.90, .55, .57), PANEL, barrel, .05)
        lathe("Cannon", [
            (.22, .60), (.22, 1.25), (.16, 1.30), (.16, 1.55),
            (.11, 1.58), (.11, 1.95),
        ], (0, 0, 1.70), (0, 1, 0), STEEL, barrel, segments=24)
        box("MuzzleBrake", (0, 1.99, 1.70), (.34, .24, .26), DARK, barrel, .04)
        box("Bore", (0, 2.12, 1.70), (.15, .012, .12), DARK, barrel, 0)
        pivot("Muzzle", (0, 2.13, 1.70), barrel)
        box("TurretID", (0, -.20, 1.85), (.50, .48, .025), TEAM, turret, .01)
        modeling.sensor_pod(current.name + "_Rangefinder", (.66, .44, 1.75), .9, (0, 1, 0), current, DARK, GLASS, STEEL, turret)
        modeling.cupola_hatch(current.name + "_Hatch", (-.45, -.35, 1.84), .28, .15, current, PANEL, DARK, GLASS, turret)
        for side in (-1, 1):
            modeling.smoke_dischargers(current.name + f"_Smoke_{side}", (side * .78, .25, 1.56), side, current, DARK, STEEL, turret)
            modeling.era_tile_rack(current.name + f"_Cheek_{side}", (side * .78, -.45, 1.55), (side * .78, .25, 1.55), (side, 0, .2), 3, (.20, .07, .22), current, PANEL, DARK, turret)


TAU = math.tau
hq()
barracks()
factory()
airfield()
reactor()
lab()
depot()
defense()
defense(True)

manifest = []
for name, collection, asset_root in assets:
    bpy.context.view_layer.update()
    for part in collection.objects:
        trim_sheet.prepare(part)
    deps = bpy.context.evaluated_depsgraph_get()
    copies = {}
    for obj in collection.objects:
        mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(deps), depsgraph=deps) if obj.type == "MESH" else None
        clone = bpy.data.objects.new("export_" + obj.name, mesh)
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
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / (name + ".glb")), export_format="GLB", use_selection=True,
        export_animations=False, export_yup=True, export_cameras=False, export_lights=False,
        export_vertex_color="ACTIVE",
    )
    for obj in live:
        bpy.data.objects.remove(obj, do_unlink=True)
    points = [obj.matrix_world @ Vector(p) for obj in collection.objects if obj.type == "MESH" for p in obj.bound_box]
    lo = Vector([min(p[i] for p in points) for i in range(3)])
    hi = Vector([max(p[i] for p in points) for i in range(3)])
    manifest.append({"name": name, "triangles": triangles, "file": name + ".glb",
                     "bounds": {"min": list(lo), "max": list(hi)}})
    collection.hide_render = True

if "--models-only" in sys.argv:
    print("Material-ready structures exported")
    raise SystemExit(0)

world = bpy.data.worlds.new("Bastion studio")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (.19, .23, .29, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = .5
for name, loc, power, color in [
    ("Key", (4, 6, 11), 2100, (1, .89, .73)),
    ("Fill", (-6, 1, 6), 1700, (.70, .83, 1)),
    ("Rim", (3, -6, 8), 2400, (1, .92, .78)),
]:
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.shape, data.size, data.color = power, "DISK", 7, color
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
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_percentage = 100
scene.render.resolution_x = scene.render.resolution_y = 320
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = True
scene.view_settings.view_transform = "AgX"
for index, (name, collection, asset_root) in enumerate(assets):
    collection.hide_render = False
    lo, hi = Vector(manifest[index]["bounds"]["min"]), Vector(manifest[index]["bounds"]["max"])
    center = (lo + hi) / 2
    camera.location = center + Vector((9, 12, 10))
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = max(hi - lo) * 1.5
    scene.render.filepath = str(ICONS / (name + ".png"))
    bpy.ops.render.render(write_still=True)
    collection.hide_render = True

for i, (name, collection, asset_root) in enumerate(assets):
    collection.hide_render = False
    asset_root.location = Vector(((i % 3 - 1) * 9, (i // 3 - 1) * 10, 0))
camera.location = (28, 36, 43)
camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.ortho_scale = 39
scene.render.film_transparent = False
scene.render.resolution_x, scene.render.resolution_y = 1600, 1400
scene.render.filepath = str(SOURCE / "catalogue.png")
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "bastion_structures.blend"))
bpy.ops.render.render(write_still=True)
(SOURCE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("Bastion structures complete:", len(manifest))
