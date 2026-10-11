"""Bastion v2: nine distinct fortified-industrial silhouettes.

blender --background --factory-startup --python-exit-code 1 --python art/bastion/build_structures.py
All dimensions are Blender metres; game scene scales preserve existing footprints.
The original demo catalogue remains available for civilian scenery.
"""
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

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
    for key, value in {"Base Color": (*color, 1), "Metallic": metallic,
                       "Roughness": roughness, "Emission Color": (*color, 1),
                       "Emission Strength": emission}.items():
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


def attach(obj, name, material, parent=None, bevel=0):
    obj.name = current.name + "_" + name
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    current.objects.link(obj)
    if material:
        obj.data.materials.append(material)
    if bevel:
        modifier = obj.modifiers.new("Cast edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent or root
    obj.matrix_world = world
    return obj


def box(name, xyz, size, material=ARMOR, parent=None, bevel=.04, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rot:
        obj.rotation_euler = rot
    return attach(obj, name, material, parent, bevel)


def cyl(name, xyz, radius, depth, material=DARK, parent=None, axis="Z", vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=xyz)
    obj = bpy.context.object
    if axis == "Y":
        obj.rotation_euler.x = math.pi / 2
    elif axis == "X":
        obj.rotation_euler.y = math.pi / 2
    return attach(obj, name, material, parent)


def rod(name, a, b, radius=.055, material=STEEL, parent=None):
    delta = Vector(b) - Vector(a)
    obj = cyl(name, (Vector(a) + Vector(b)) / 2, radius, delta.length, material, parent, vertices=8)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return obj


def shape(name, vertices, faces, material=ARMOR, parent=None):
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
    return attach(obj, name, material, parent)


def octagon(name, xyz, width, depth, height, material=ARMOR, taper=1, parent=None):
    x, y, z = xyz
    w, d = width / 2, depth / 2
    ring = [(-w*.65, -d), (w*.65, -d), (w, -d*.65), (w, d*.65),
            (w*.65, d), (-w*.65, d), (-w, d*.65), (-w, -d*.65)]
    vertices = [(x+a, y+b, z) for a, b in ring]
    vertices += [(x+a*taper, y+b*taper, z+height) for a, b in ring]
    faces = [tuple(reversed(range(8))), tuple(range(8, 16))]
    faces += [(i, (i+1) % 8, (i+1) % 8+8, i+8) for i in range(8)]
    return shape(name, vertices, faces, material, parent)


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
    octagon("Footing", (0, 0, 0), width, depth, .18, CONCRETE)
    octagon("Foundation", (0, 0, .18), width*.95, depth*.95, .16, DARK)


def vent(x, y, z, width, count=5):
    box("VentRecess", (x, y, z), (width, .52, .035), DARK, bevel=0)
    for i in range(count):
        box("CoolingFin", (x-width*.43+i*width*.86/(count-1), y, z+.045),
            (.055, .46, .06), STEEL, bevel=0)


def stencil(text, xyz, size=.4, rot=None, parent=None):
    data = bpy.data.curves.new("Stencil", "FONT")
    data.body = text
    data.align_x = "CENTER"
    data.size = size
    data.extrude = .001
    obj = bpy.data.objects.new("Stencil", data)
    current.objects.link(obj)
    obj.location = xyz
    obj.rotation_euler = rot or (0, 0, math.pi)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj.select_set(False)
    attach(obj, "Stencil", WHITE, parent)


def arch(name, x, y, z, radius, length, material, parent=None):
    # A hollow, ribbed vault, deliberately not a rectangular warehouse.
    vertices = []
    steps = 12
    for dy in [-length/2, length/2]:
        for r in [radius, radius-.16]:
            vertices += [(x+r*math.cos(i*math.pi/steps), y+dy, z+r*math.sin(i*math.pi/steps))
                         for i in range(steps+1)]
    n = steps+1
    faces = []
    for i in range(steps):
        faces += [(i, i+1, 2*n+i+1, 2*n+i),
                  (n+i, 3*n+i, 3*n+i+1, n+i+1),
                  (i, n+i, n+i+1, i+1),
                  (2*n+i, 2*n+i+1, 3*n+i+1, 3*n+i)]
    faces += [(0, 2*n, 3*n, n), (n-1, 2*n-1, 4*n-1, 3*n-1)]
    return shape(name, vertices, faces, material, parent)


def hq():
    begin("CommandCenter")
    base(5.7, 5.7)
    octagon("BatteredCurtainWall", (0, 0, .34), 5.0, 4.8, 1.65, ARMOR, .77)
    octagon("Crown", (0, -.12, 1.99), 4.05, 3.85, .25, PANEL)
    octagon("CommandKeep", (0, -.45, 2.24), 2.55, 2.55, 1.55, ARMOR, .86)
    octagon("ObservationBand", (0, -.45, 3.79), 2.3, 2.3, .25, GLASS)
    octagon("BattlementCap", (0, -.45, 4.04), 2.7, 2.7, .35, PANEL, .86)
    for side in [-1, 1]:
        for y in [-1.65, 1.6]:
            octagon("CornerBastion", (side*1.9, y, .34), 1.15, 1.25, 2.25, PANEL, .73)
            box("RecognitionPanel", (side*1.9, y+.45, 1.85), (.58, .05, .65), TEAM)
        box("RoofStripe", (side*1.42, 0, 2.28), (.23, 2.5, .05), TEAM)
    box("GateShadow", (0, 2.13, .97), (1.28, .12, 1.22), DARK)
    for x in [-.32, .32]:
        box("BlastDoor", (x, 2.21, .97), (.59, .08, 1.12), STEEL)
    box("GateLintel", (0, 2.27, 1.64), (1.55, .22, .18), TEAM)
    box("EntranceRamp", (0, 2.43, .29), (1.45, .75, .17), CONCRETE)
    rod("Aerial", (-.55, -.6, 4.38), (-.55, -.6, 5.5), .035)
    rod("AerialCross", (-1, -.6, 5.1), (-.1, -.6, 5.1), .025)
    cyl("Beacon", (.65, -.45, 4.53), .11, .2, GLASS)
    stencil("01", (0, 2.281, 1.9), .43, (math.pi/2, 0, math.pi))


def barracks():
    begin("Barracks")
    base(4.75, 4.75)
    for x in [-1.12, 1.12]:
        box("BunkerPlinth", (x, -.25, .68), (1.95, 3.4, .7), CONCRETE)
        arch("ArmoredVault", x, -.25, 1.03, 1.0, 3.35, ARMOR)
        for y in [-1.85, -.85, .15, 1.35]:
            arch("VaultRib", x, y, 1.03, 1.05, .13, PANEL)
        box("Portal", (x, 1.39, .96), (1.35, .10, 1.25), DARK)
        box("Door", (x, 1.45, .84), (.92, .08, .95), STEEL)
        box("UnitPanel", (x, 1.5, 1.4), (.88, .09, .16), TEAM)
        vent(x, -.4, 2.07, .6)
    box("EntryApron", (0, 1.85, .28), (3.8, .7, .17), CONCRETE)
    rod("Flagpole", (0, -.5, .35), (0, -.5, 3.15), .028)
    box("Banner", (.34, -.5, 2.79), (.65, .025, .62), TEAM, bevel=0)
    stencil("02", (-1.12, .2, 2.098), .4)


def factory():
    begin("VehicleFactory")
    base(6.1, 6.1)
    box("AssemblyFloor", (0, 0, .38), (4.6, 5.5, .18), STEEL)
    for x in [-2.12, 2.12]:
        octagon("ArmoredMachineBank", (x, -.05, .4), 1.35, 4.9, 1.65, ARMOR, .86)
        for y in [-1.9, -.75, .4, 1.55]:
            vent(x, y, 2.065, .75)
        box("SafetyStripe", (x, 2.25, 1.42), (.85, .1, .42), TEAM)
        for y in [-1.8, 1.45]:
            box("GantryLeg", (x, y, 2.5), (.26, .35, 2.05), PANEL)
            rod("GantryBrace", (x, y, 1.8), (x*.6, y, 3.4), .08)
        box("CraneRail", (x, -.18, 3.51), (.28, 4.15, .24), TEAM)
    box("OverheadCrane", (0, -.45, 3.57), (4.65, .55, .28), PANEL)
    box("HoistCarriage", (.45, -.45, 3.36), (.6, .68, .25), TEAM)
    rod("HoistCable", (.45, -.45, 3.3), (.45, -.45, 2.43), .025, DARK)
    rod("HoistHook", (.45, -.45, 2.43), (.65, -.45, 2.58), .055)
    octagon("UnfinishedHull", (0, -.6, .59), 1.65, 2.4, .65, PANEL, .75)
    for x in [-.95, .95]:
        box("AssemblyTrack", (x, -.6, .64), (.26, 2.45, .30), DARK)
    for y in [-2.15, -1.6, -1.05, -.5, .05, .6, 1.15, 1.7, 2.25]:
        cyl("Roller", (0, y, .52), .08, 2.45, DARK, axis="X")
    stencil("03", (0, 1.47, .491), .5)


def airfield():
    begin("AircraftFactory")
    base(6.1, 6.1)
    octagon("RaisedFlightDeck", (.3, .3, .34), 5.25, 5.25, .62, ARMOR, .94)
    octagon("DeckRim", (.3, .3, .96), 5.25, 5.25, .13, PANEL)
    cyl("LandingCircle", (.55, .65, 1.101), 1.63, .014, WHITE, vertices=48)
    cyl("LandingInset", (.55, .65, 1.115), 1.48, .014, DARK, vertices=48)
    for x in [-.05, 1.15]:
        box("HelipadMark", (x, .65, 1.131), (.20, 1.8, .018), WHITE, bevel=0)
    box("HelipadCross", (.55, .65, 1.131), (1.3, .22, .018), WHITE, bevel=0)
    octagon("TowerStem", (-1.95, -1.7, .34), 1.05, 1.1, 3.12, ARMOR, .77)
    octagon("TowerCab", (-1.95, -1.7, 3.46), 1.65, 1.65, .54, GLASS, 1.1)
    octagon("TowerRoof", (-1.95, -1.7, 4), 1.92, 1.92, .19, PANEL, .87)
    rod("ControlMast", (-1.95, -1.7, 4.18), (-1.95, -1.7, 5.3), .03)
    cyl("Beacon", (-1.95, -1.7, 5.25), .10, .18, GLASS)
    for y in [-1.65, -.65, .35, 1.35, 2.35]:
        for x in [-2.27, 2.77]:
            cyl("DeckLight", (x, y, 1.2), .065, .15, GLASS, vertices=8)
    for x in [-.2, .8, 1.8]:
        box("DeckHazard", (x, -2.19, 1.12), (.5, .28, .025), TEAM, bevel=0)
    stencil("04", (.5, -1.72, 1.12), .42)


def reactor():
    begin("PowerPlant")
    base(4.65, 4.65)
    cyl("ReactorSump", (0, 0, .57), 1.45, .48, DARK, vertices=16)
    cyl("ContainmentVessel", (0, 0, 1.7), 1.0, 1.9, STEEL, vertices=16)
    for z in [.8, 1.25, 1.7, 2.15, 2.6]:
        cyl("ReactorCollar", (0, 0, z), 1.17, .18, ARMOR, vertices=16)
    for angle in range(0, 360, 60):
        a = math.radians(angle)
        x, y = math.cos(a), math.sin(a)
        rod("ThermalConduit", (x, y, .9), (x, y, 2.5), .075, HEAT)
        octagon("CoolingButtress", (x*1.62, y*1.62, .34), .68, .68, 1.55, PANEL, .72)
        rod("ExternalFeed", (x*1.62, y*1.62, 1.75), (x, y, 2.1), .11, DARK)
    cyl("TopShield", (0, 0, 2.92), 1.35, .4, ARMOR, vertices=12)
    cyl("TurbineWell", (0, 0, 3.135), .85, .05, DARK, vertices=16)
    for x in [-.5, -.25, 0, .25, .5]:
        box("TurbineGrille", (x, 0, 3.18), (.08, 1.16, .1), STEEL)
    for x in [-1.42, 1.42]:
        cyl("ExhaustStack", (x, -1.15, 2.72), .26, 1.65, DARK)
        cyl("StackLip", (x, -1.15, 3.55), .33, .13, TEAM)
    stencil("05", (0, 1.83, .36), .4)


def lab():
    begin("CommandLab")
    base(4.85, 4.85)
    octagon("CommsBunker", (0, 0, .34), 4.2, 3.7, 1.15, ARMOR, .82)
    octagon("ReinforcedRoof", (0, 0, 1.49), 3.65, 3.2, .19, PANEL)
    cyl("DishTurntable", (0, -.4, 1.91), .73, .46, DARK)
    sensor = pivot("SensorPivot", (0, -.4, 2.0))
    rod("DishSupport", (-.5, -.4, 1.96), (-.5, -.4, 2.8), .13, STEEL, sensor)
    rod("DishSupport", (.5, -.4, 1.96), (.5, -.4, 2.8), .13, STEEL, sensor)
    # Concave paraboloid angled up/front. Real bowl with rim and feed arm.
    center = Vector((0, -.4, 2.78))
    axis = Vector((0, .68, .73))
    across = Vector((1, 0, 0))
    up = axis.cross(across)
    vertices = []
    rings, segments, radius = 6, 32, 1.65
    for j in range(rings+1):
        r = max(.001, radius*j/rings)
        for i in range(segments):
            angle = TAU*i/segments
            point = center + across*(r*math.cos(angle)) + up*(r*math.sin(angle)) + axis*(.30*r*r)
            vertices.append(tuple(point))
    faces = []
    for j in range(rings):
        for i in range(segments):
            faces.append((j*segments+i, j*segments+(i+1)%segments,
                          (j+1)*segments+(i+1)%segments, (j+1)*segments+i))
    bowl = shape("RadarReflector", vertices, faces, PANEL, sensor)
    solidify = bowl.modifiers.new("Reflector thickness", "SOLIDIFY")
    solidify.thickness = .065
    for i in range(segments):
        rod("DishRim", vertices[-segments+i], vertices[-segments+(i+1)%segments], .035, STEEL, sensor)
    focus = center + axis*1.28
    for i in [2, 13, 23]:
        rod("FeedStrut", vertices[-segments+i], focus, .025, DARK, sensor)
    cyl("Receiver", focus, .13, .20, GLASS, sensor)
    for x in [-1.33, 1.33]:
        box("DataWindow", (x, 1.47, 1.09), (.55, .04, .23), GLASS)
    box("CommsID", (0, 1.49, 1.05), (.65, .06, .58), TEAM)
    stencil("06", (0, 1.526, .95), .34, (math.pi/2, 0, math.pi))


def depot():
    begin("RepairDepot")
    base(5.4, 5.4)
    for x in [-1.1, 1.1]:
        box("ServiceRamp", (x, .25, .41), (.55, 4.3, .26), STEEL)
        for y in [-1.5, -.75, 0, .75, 1.5]:
            box("RampGrip", (x, y, .553), (.49, .1, .02), DARK, bevel=0)
    octagon("ToolBank", (0, -1.9, .34), 4.5, 1.1, 1.15, ARMOR, .9)
    for side in [-1, 1]:
        box("LiftColumn", (side*2.0, -.25, 1.68), (.40, .55, 2.68), TEAM)
        rod("LiftPiston", (side*1.84, -.01, .52), (side*1.84, -.01, 2.8), .07)
        arm = pivot("RepairArm"+str(side), (side*1.97, -.05, 1.45))
        rod("ServiceBoom", (side*1.97, -.05, 1.45), (side*1.22, .50, 2.25), .13, PANEL, arm)
        cyl("ToolJoint", (side*1.22, .50, 2.25), .22, .30, DARK, arm, axis="Y")
        rod("ServiceForearm", (side*1.22, .50, 2.25), (side*.70, .8, 1.65), .10, TEAM, arm)
        rod("ToolTip", (side*.70, .8, 1.65), (side*.5, .82, 1.43), .045, STEEL, arm)
    box("ServiceLintel", (0, -.25, 3.15), (4.5, .75, .36), ARMOR)
    box("RepairMarkA", (0, .15, 3.15), (.9, .04, .17), WHITE)
    box("RepairMarkB", (0, .16, 3.15), (.17, .04, .45), WHITE)
    for x in [-1.55, 1.55]:
        box("WorkLight", (x, .17, 3.17), (.32, .04, .11), GLASS)
    stencil("07", (0, 1.15, .352), .47)


def defense(air=False):
    begin("AntiAirTurret" if air else "AntiGroundTurret")
    base(2.9, 2.9)
    for angle in [0, math.pi/2, math.pi, math.pi*1.5]:
        x, y = math.cos(angle), math.sin(angle)
        octagon("Anchor", (x*1.05, y*1.05, .34), .64, .64, .48, PANEL, .8)
    cyl("ArmoredBarbette", (0, 0, .77), .95, .86, ARMOR, vertices=12)
    cyl("TraverseRing", (0, 0, 1.23), 1.02, .16, STEEL, vertices=16)
    turret = pivot("TurretPivot", (0, 0, 1.32))
    octagon("TurretShell", (0, -.15, 1.30), 1.78, 1.45, .53, ARMOR, .74, turret)
    barrel = pivot("BarrelPivot", (0, .20, 1.7), turret)
    if air:
        for x in [-.75, .75]:
            box("MissileCradle", (x, .02, 2.14), (.7, 1.48, .84), TEAM, barrel, .06,
                (-.24, 0, 0))
            for dx in [-.17, .17]:
                for z in [1.94, 2.28]:
                    cyl("LaunchTube", (x+dx, .80, z), .14, .19, DARK, barrel, axis="Y")
                    cyl("MissileNose", (x+dx, .91, z), .065, .05, WHITE, barrel, axis="Y")
        rod("RadarMast", (0, -.4, 1.8), (0, -.4, 2.8), .06, STEEL, turret)
        box("SearchArray", (0, -.4, 2.91), (1.08, .16, .39), PANEL, turret)
        box("SearchSensor", (0, -.3, 2.91), (.81, .03, .18), GLASS, turret)
        pivot("Muzzle", (.58, 1.03, 2.3), barrel)
    else:
        box("Mantlet", (0, .35, 1.70), (.9, .55, .57), PANEL, barrel)
        cyl("CannonSleeve", (0, .94, 1.70), .20, .75, ARMOR, barrel, axis="Y")
        cyl("CannonBarrel", (0, 1.60, 1.70), .11, .72, STEEL, barrel, axis="Y")
        box("MuzzleBrake", (0, 1.99, 1.7), (.34, .24, .26), DARK, barrel)
        box("Bore", (0, 2.12, 1.7), (.15, .012, .12), DARK, barrel, 0)
        pivot("Muzzle", (0, 2.13, 1.7), barrel)
        box("TurretID", (0, -.20, 1.85), (.5, .48, .025), TEAM, turret)
        box("Rangefinder", (.66, .44, 1.75), (.24, .23, .16), GLASS, turret)


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

# Export evaluated meshes merged by rigid parent; joints remain independent.
manifest = []
for name, collection, asset_root in assets:
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    copies = {}
    for obj in collection.objects:
        mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(deps), depsgraph=deps) if obj.type == "MESH" else None
        clone = bpy.data.objects.new("export_"+obj.name, mesh)
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
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_area() < 1e-10], context="FACES_ONLY")
        bm.to_mesh(joined.data)
        bm.free()
    live = [obj for obj in scene.collection.objects if obj.name.startswith("export_")]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in live:
        obj.select_set(True)
    triangles = sum(len(obj.data.polygons) for obj in live if obj.type == "MESH")
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")), export_format="GLB", use_selection=True,
                             export_animations=False, export_yup=True, export_cameras=False, export_lights=False)
    for obj in live:
        bpy.data.objects.remove(obj, do_unlink=True)
    points = [obj.matrix_world@Vector(p) for obj in collection.objects if obj.type == "MESH" for p in obj.bound_box]
    lo = Vector([min(p[i] for p in points) for i in range(3)])
    hi = Vector([max(p[i] for p in points) for i in range(3)])
    manifest.append({"name": name, "triangles": triangles, "file": name+".glb",
                     "bounds": {"min": list(lo), "max": list(hi)}})
    collection.hide_render = True

world = bpy.data.worlds.new("Bastion studio")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (.19, .23, .29, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = .5
for name, loc, power, color in [("Key", (4, 6, 11), 2100, (1, .89, .73)),
                                ("Fill", (-6, 1, 6), 1700, (.70, .83, 1)),
                                ("Rim", (3, -6, 8), 2400, (1, .92, .78))]:
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.shape, data.size, data.color = power, "DISK", 7, color
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (Vector((0, 0, 1))-obj.location).to_track_quat("-Z", "Y").to_euler()
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
    center = (lo+hi)/2
    camera.location = center + Vector((9, 12, 10))
    camera.rotation_euler = (center-camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = max(hi-lo)*1.5
    scene.render.filepath = str(ICONS/(name+".png"))
    bpy.ops.render.render(write_still=True)
    collection.hide_render = True

# Keep the editable objects; the icon montage is assembled without altering pixels.
for i, (name, collection, asset_root) in enumerate(assets):
    collection.hide_render = False
    asset_root.location = Vector(((i%3-1)*9, (i//3-1)*10, 0))
camera.location = (28, 36, 43)
camera.rotation_euler = (Vector((0, 0, 0))-camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.ortho_scale = 39
scene.render.film_transparent = False
scene.render.resolution_x, scene.render.resolution_y = 1600, 1400
scene.render.filepath = str(SOURCE/"catalogue.png")
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"bastion_structures.blend"))
bpy.ops.render.render(write_still=True)
(SOURCE/"manifest.json").write_text(json.dumps(manifest, indent=2)+"\n")
print("Bastion structures complete:", len(manifest))
