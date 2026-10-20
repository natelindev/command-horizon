"""Build the air-combat redesign models: fighters, bombers, rotorcraft and mobile
anti-air for all three factions, plus their roster icons.

Rebuild faction GLBs with art/<faction>/build_aircraft.py. This shared builder
also generates the complete editable catalogue and icons when run directly.

Models follow the faction builders' conventions: Blender Z up, nose toward +Y
(exported as -Z in Godot), faceted low-poly parts on named pivots that the game
animates (RotorM/RotorT/RotorLeft/RotorRight spin, TurretPivot/BarrelPivot aim,
Muzzle syncs the projectile origin). Materials reuse the faction names so armor
textures and team colors apply in game.
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

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/air-combat"
# Faction entrypoints export only their models, preserving shared review assets.
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


def attach(obj, name, material, parent=None, bevel=0):
    obj.name = current.name + "_" + name
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    current.objects.link(obj)
    if material:
        obj.data.materials.append(material)
    if bevel:
        modifier = obj.modifiers.new("Edge chamfer", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        normal = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
        normal.keep_sharp = True
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent or root
    obj.matrix_world = world
    return obj


def box(name, xyz, size, material=None, parent=None, bevel=.04, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rot:
        obj.rotation_euler = rot
    return attach(obj, name, material or P["armor"], parent, bevel)


def cyl(name, xyz, radius, depth, material=None, parent=None, axis="Z", vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=xyz)
    obj = bpy.context.object
    if axis == "Y":
        obj.rotation_euler.x = math.pi / 2
    if axis == "X":
        obj.rotation_euler.y = math.pi / 2
    return attach(obj, name, material or P["dark"], parent)


def cone(name, xyz, radius, depth, material=None, parent=None, vertices=10):
    """Cone pointing toward +Y (a nose, warhead or spinner)."""
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=0, depth=depth, location=xyz)
    obj = bpy.context.object
    obj.rotation_euler.x = -math.pi / 2
    return attach(obj, name, material or P["armor"], parent)


def rod(name, a, b, radius, material=None, parent=None, vertices=8):
    delta = Vector(b) - Vector(a)
    obj = cyl(name, (Vector(a) + Vector(b)) / 2, radius, delta.length, material or P["steel"], parent, vertices=vertices)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return obj


def shape(name, vertices, faces, material=None, parent=None, bevel=.02):
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
    return attach(obj, name, material or P["armor"], parent, bevel)


def slab(name, outline, z, thickness, material=None, parent=None, bevel=.02):
    """Extrude a flat XY outline (counter-clockwise) into a thin plate."""
    count = len(outline)
    vertices = [(x, y, z) for x, y in outline] + [(x, y, z + thickness) for x, y in outline]
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, 2 * count))]
    for i in range(count):
        j = (i + 1) % count
        faces.append((i, j, count + j, count + i))
    return shape(name, vertices, faces, material, parent, bevel)


def wedge(name, x, y, z, width, length, height, material=None, parent=None, taper=(.8, .7)):
    w, l, h = width / 2, length / 2, height
    return shape(name, [(x - w, y - l, z), (x + w, y - l, z), (x + w, y + l, z), (x - w, y + l, z),
                        (x - w * taper[0], y - l * .8, z + h), (x + w * taper[0], y - l * .8, z + h),
                        (x + w * taper[1], y + l * .65, z + h), (x - w * taper[1], y + l * .65, z + h)],
                 [(0, 3, 2, 1), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)],
                 material, parent, .04)


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


def mirrored(function):
    for side in (-1, 1):
        function(side)


def gear(points, height=.5):
    """Tricycle landing gear: struts and wheels for taxiing jets."""
    for x, y in points:
        rod("GearStrut", (x, y, .2), (x, y, height), .045, P["steel"])
        cyl("GearWheel", (x, y, .16), .16, .1, P["rubber"], axis="X", vertices=10)


def rotor(name, xyz, radius, blades, parent=None, axis="Z"):
    """A spinning rotor on a pivot. Blades are built in the hub plane, then the
    pivot is turned so its spin axis (Godot local up) points along `axis`:
    Z for main rotors, X for tail rotors, Y for propellers."""
    hub = pivot(name, xyz, parent)
    cyl("RotorHub", xyz, radius * .09, .14, P["steel"], hub)
    for index in range(blades):
        angle = index * math.tau / blades
        box("Blade", (xyz[0] + math.cos(angle) * radius / 2, xyz[1] + math.sin(angle) * radius / 2, xyz[2]),
            (radius, .16 if axis == "Z" else .12, .035), P["dark"], hub, .008, (0, 0, angle))
    if axis == "X":
        hub.rotation_euler = (0, math.pi / 2, 0)
    elif axis == "Y":
        hub.rotation_euler = (math.pi / 2, 0, 0)
    return hub


def missiles(x, y, z, count=2, length=.95, radius=.085):
    for index in range(count):
        offset = (index - (count - 1) / 2) * radius * 2.6
        cyl("Missile", (x + offset, y, z), radius, length, P["dark"], axis="Y", vertices=8)
        cone("MissileNose", (x + offset, y + length / 2 + .09, z), radius, .2, P["mark"], vertices=8)
        cyl("MissileBand", (x + offset, y + length * .25, z), radius * 1.06, .1, P["team"], axis="Y", vertices=8)


def tracks(width=2.0, length=2.8):
    for side in (-1, 1):
        x = side * width / 2
        box("TrackBelt", (x, 0, .42), (.5, length, .74), P["rubber"], bevel=.18)
        for i in range(5):
            y = -length * .37 + i * length * .185
            cyl("Wheel", (x + side * .26, y, .43), .25, .055, P["panel"], axis="X")
        box("Fender", (x, 0, .89), (.65, length, .13))


def wheels(width=2.1, positions=(-1.0, .2, 1.1), radius=.42):
    for side in (-1, 1):
        for y in positions:
            cyl("Tire", (side * width / 2, y, radius), radius, .34, P["rubber"], axis="X", vertices=14)
            cyl("Rim", (side * (width / 2 + .17), y, radius), radius * .5, .04, P["steel"], axis="X", vertices=10)


# --- Bastion ---------------------------------------------------------------------


def bastion_fighter():
    begin("bastion", "Fighter")
    wedge("Fuselage", 0, 0, .35, .95, 5.0, .62, taper=(.75, .55))
    cone("Nose", (0, 2.95, .62), .36, 1.0, P["armor"], vertices=8)
    wedge("Canopy", 0, 1.35, .95, .55, 1.25, .34, P["glass"], taper=(.6, .4))
    slab("Wing", [(-2.35, -1.55), (-.4, -.6), (-.4, .9), (-2.35, -1.05)], .45, .1, P["panel"])
    slab("Wing", [(.4, -.6), (2.35, -1.55), (2.35, -1.05), (.4, .9)], .45, .1, P["panel"])
    for side in (-1, 1):
        box("WingTeam", (side * 1.9, -1.25, .57), (.46, .32, .03), P["team"])
        shape("TailFin", [(side * .3, -2.4, .9), (side * .55, -2.4, 1.85), (side * .36, -1.45, .95),
                          (side * .42, -2.4, .9), (side * .67, -2.4, 1.85), (side * .48, -1.45, .95)],
              [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)])
        slab("Stabilizer", [(side * .45, -2.55), (side * 1.35, -2.75), (side * 1.35, -2.45), (side * .45, -1.95)]
             if side > 0 else [(side * 1.35, -2.75), (side * .45, -2.55), (side * .45, -1.95), (side * 1.35, -2.45)],
             .55, .07, P["panel"])
        box("Intake", (side * .58, .55, .62), (.32, .9, .42), P["dark"], bevel=.03)
        missiles(side * 1.45, -.75, .3, 2, .9, .075)
    cyl("Exhaust", (0, -2.62, .66), .3, .32, P["dark"], axis="Y", vertices=12)
    cyl("Afterburner", (0, -2.8, .66), .2, .06, P["glass"], axis="Y", vertices=12)
    cyl("Cannon", (.32, 2.2, .55), .05, .55, P["dark"], axis="Y", vertices=6)
    gear([(0, 1.9), (-.75, -.7), (.75, -.7)], .42)
    pivot("Muzzle", (0, 3.45, .6))


def bastion_bomber():
    begin("bastion", "Bomber")
    wedge("Fuselage", 0, 0, .35, 1.35, 6.4, .95, taper=(.8, .7))
    cone("Nose", (0, 3.55, .82), .58, .9, P["glass"], vertices=10)
    wedge("Cockpit", 0, 2.25, 1.28, .9, 1.3, .32, P["glass"], taper=(.6, .45))
    slab("Wing", [(-3.85, -.2), (-.55, -.5), (-.55, .95), (-3.85, .35)], 1.05, .14, P["panel"])
    slab("Wing", [(.55, -.5), (3.85, -.2), (3.85, .35), (.55, .95)], 1.05, .14, P["panel"])
    for side in (-1, 1):
        for x in (1.35, 2.55):
            cyl("Nacelle", (side * x, .35, .92), .27, 1.5, P["armor"], axis="Y", vertices=10)
            cone("Spinner", (side * x, 1.2, .92), .12, .25, P["steel"], vertices=8)
            letter = ("A" if x < 2 else "B") if side < 0 else ("C" if x < 2 else "D")
            rotor("Rotor" + letter, (side * x, 1.26, .92), .62, 3, axis="Y")
        box("WingTeam", (side * 3.35, .1, 1.21), (.6, .36, .03), P["team"])
        slab("Stabilizer", [(side * .5, -3.25), (side * 1.9, -3.4), (side * 1.9, -3.0), (side * .5, -2.55)]
             if side > 0 else [(side * 1.9, -3.4), (side * .5, -3.25), (side * .5, -2.55), (side * 1.9, -3.0)],
             .95, .08, P["panel"])
        shape("TailFin", [(side * 1.75, -3.3, .95), (side * 1.75, -3.35, 2.05), (side * 1.75, -2.6, 1.0),
                          (side * 1.87, -3.3, .95), (side * 1.87, -3.35, 2.05), (side * 1.87, -2.6, 1.0)],
              [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)])
    box("BombBay", (0, -.1, .34), (.85, 1.9, .06), P["dark"], bevel=.01)
    box("TeamStripe", (0, -1.7, 1.31), (.95, .4, .03), P["team"])
    cyl("TailGun", (0, -3.35, .7), .06, .5, P["dark"], axis="Y", vertices=6)
    gear([(0, 2.6), (-1.0, -.3), (1.0, -.3)], .4)
    pivot("Muzzle", (0, -.1, .3))


def bastion_helicopter():
    begin("bastion", "Helicopter")
    # Tandem-seat attack helicopter: narrow armored pod, tail boom, stub wings.
    wedge("Pod", 0, .35, .38, .95, 2.9, .9, taper=(.85, .6))
    wedge("Canopy", 0, 1.05, 1.05, .62, 1.55, .42, P["glass"], taper=(.65, .45))
    rod("TailBoom", (0, -1.05, .95), (0, -3.15, 1.12), .18, P["armor"])
    shape("TailFin", [(-.06, -3.25, .95), (-.06, -3.05, 1.9), (-.06, -2.6, 1.1),
                      (.06, -3.25, .95), (.06, -3.05, 1.9), (.06, -2.6, 1.1)],
          [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)])
    box("Engine", (0, -.35, 1.42), (.75, 1.25, .42), P["panel"], bevel=.05)
    cyl("Mast", (0, .05, 1.78), .09, .4, P["steel"])
    rotor("RotorM", (0, .05, 2.0), 2.45, 4)
    rotor("RotorT", (.14, -3.12, 1.35), .5, 3, axis="X")
    for side in (-1, 1):
        slab("StubWing", [(side * .45, -.2), (side * 1.35, -.35), (side * 1.35, .1), (side * .45, .3)]
             if side > 0 else [(side * 1.35, -.35), (side * .45, -.2), (side * .45, .3), (side * 1.35, .1)],
             .72, .08, P["panel"])
        cyl("RocketPod", (side * 1.15, -.05, .55), .17, .85, P["dark"], axis="Y", vertices=10)
        cyl("PodBand", (side * 1.15, .2, .55), .18, .1, P["team"], axis="Y", vertices=10)
        rod("Skid", (side * .55, -.8, .08), (side * .55, 1.1, .08), .045, P["steel"])
        rod("SkidStrut", (side * .55, .5, .08), (side * .36, .5, .45), .035, P["steel"])
        rod("SkidStrut", (side * .55, -.4, .08), (side * .36, -.4, .45), .035, P["steel"])
    box("TeamStripe", (0, -1.6, 1.12), (.32, .55, .03), P["team"])
    cyl("ChinTurret", (0, 1.55, .33), .17, .2, P["dark"], vertices=10)
    cyl("ChinGun", (0, 1.95, .3), .05, .6, P["dark"], axis="Y", vertices=6)
    pivot("Muzzle", (0, 2.3, .3))


def bastion_flak():
    begin("bastion", "AntiAirVehicle")
    tracks(2.0, 3.0)
    wedge("Hull", 0, 0, .55, 1.75, 3.05, .55)
    box("TeamPlate", (0, -1.1, 1.12), (1.0, .35, .03), P["team"])
    turret = pivot("TurretPivot", (0, -.1, 1.1))
    wedge("Turret", 0, -.1, 1.1, 1.25, 1.45, .6, P["panel"], turret)
    barrel = pivot("BarrelPivot", (0, .2, 1.45), turret, (math.radians(35), 0, 0))
    for side in (-1, 1):
        cyl("Autocannon", (side * .28, 1.05, 1.45), .065, 1.45, P["dark"], barrel, "Y", 8)
        cyl("MuzzleBrake", (side * .28, 1.78, 1.45), .09, .18, P["steel"], barrel, "Y", 8)
        box("AmmoDrum", (side * .62, -.1, 1.4), (.24, .7, .4), P["armor"], turret, .03)
    pivot("Muzzle", (0, 1.9, 1.45), barrel)
    rod("RadarMast", (0, -.75, 1.65), (0, -.75, 2.25), .05, P["steel"], turret)
    radar = pivot("SensorPivot", (0, -.75, 2.3), turret)
    box("RadarDish", (0, -.75, 2.35), (.9, .08, .45), P["panel"], radar, .02)


# --- Helix -----------------------------------------------------------------------


def helix_fighter():
    begin("helix", "TalonInterceptor")
    wedge("Fuselage", 0, 0, .35, .8, 5.2, .5, taper=(.6, .45))
    cone("Nose", (0, 3.0, .55), .3, 1.1, P["armor"], vertices=8)
    wedge("Canopy", 0, 1.3, .82, .42, 1.2, .26, P["glass"], taper=(.5, .35))
    # Forward-swept wings with glowing leading edges.
    slab("Wing", [(-2.5, .55), (-.35, -.9), (-.35, -.2), (-2.5, .95)], .42, .08, P["armor"])
    slab("Wing", [(.35, -.9), (2.5, .55), (2.5, .95), (.35, -.2)], .42, .08, P["armor"])
    for side in (-1, 1):
        rod("LeadingEdge", (side * .4, -.2, .5), (side * 2.45, .95, .5), .03, P["glass"])
        box("WingTeam", (side * 1.9, .55, .51), (.4, .28, .03), P["team"])
        shape("Canard", [(side * .35, 1.9, .55), (side * 1.0, 1.6, .55), (side * .35, 1.45, .55),
                         (side * .35, 1.9, .6), (side * 1.0, 1.6, .6), (side * .35, 1.45, .6)],
              [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], P["panel"])
        shape("TailFin", [(side * .25, -2.5, .8), (side * .7, -2.6, 1.7), (side * .3, -1.7, .82),
                          (side * .35, -2.5, .8), (side * .8, -2.6, 1.7), (side * .4, -1.7, .82)],
              [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], P["panel"])
        missiles(side * 1.2, -.1, .3, 1, .9, .07)
        cyl("Exhaust", (side * .25, -2.7, .55), .17, .25, P["dark"], axis="Y", vertices=10)
        cyl("ExhaustGlow", (side * .25, -2.85, .55), .12, .05, P["glass"], axis="Y", vertices=10)
    gear([(0, 1.8), (-.6, -.8), (.6, -.8)], .4)
    pivot("Muzzle", (0, 3.55, .55))


def helix_bomber():
    begin("helix", "ShrikeBomber")
    # Flying wing: a wide chevron with a raised spine and buried engines.
    outline = [(0, 2.6), (-4.1, -1.4), (-3.6, -2.0), (-1.4, -.9), (0, -1.5), (1.4, -.9), (3.6, -2.0), (4.1, -1.4)]
    slab("Wing", [outline[0]] + list(reversed(outline[1:])), .55, .26, P["armor"])
    wedge("Spine", 0, .35, .78, 1.3, 3.6, .38, P["panel"], taper=(.6, .4))
    wedge("Canopy", 0, 1.55, 1.12, .55, .8, .2, P["glass"], taper=(.5, .3))
    for side in (-1, 1):
        cyl("EngineIntake", (side * .95, .7, .92), .26, .3, P["dark"], axis="Y", vertices=10)
        cyl("EngineGlow", (side * .95, -1.05, .9), .2, .06, P["glass"], axis="Y", vertices=10)
        rod("LeadingEdge", (side * .2, 2.45, .82), (side * 4.0, -1.35, .82), .035, P["glass"])
        box("WingTeam", (side * 2.9, -1.2, .82), (.7, .3, .03), P["team"])
    box("BombBay", (0, .1, .52), (1.0, 1.6, .05), P["dark"], bevel=.01)
    gear([(0, 1.6), (-1.1, -.6), (1.1, -.6)], .52)
    pivot("Muzzle", (0, .1, .5))


def helix_helicopter():
    begin("helix", "WraithTiltrotor")
    # Tilt-rotor gunship: lifting body with wingtip rotor nacelles.
    wedge("Body", 0, .2, .38, 1.15, 3.6, .78, taper=(.7, .5))
    cone("Nose", (0, 2.2, .7), .42, .8, P["armor"], vertices=8)
    wedge("Canopy", 0, 1.25, 1.02, .6, 1.2, .3, P["glass"], taper=(.55, .35))
    slab("Wing", [(-2.1, -.35), (2.1, -.35), (2.1, .3), (-2.1, .3)], 1.0, .1, P["panel"])
    for side in (-1, 1):
        cyl("Nacelle", (side * 2.2, 0, 1.15), .26, .9, P["armor"], vertices=10)
        cyl("NacelleGlow", (side * 2.2, 0, .68), .18, .05, P["glass"], vertices=10)
        rotor("RotorLeft" if side < 0 else "RotorRight", (side * 2.2, 0, 1.68), 1.55, 3)
        cyl("RocketPod", (side * 1.15, .1, .62), .15, .8, P["dark"], axis="Y", vertices=10)
        box("WingTeam", (side * 1.6, -.1, 1.11), (.45, .3, .03), P["team"])
        shape("TailFin", [(side * .3, -1.6, .9), (side * .55, -1.75, 1.55), (side * .35, -1.05, .95),
                          (side * .4, -1.6, .9), (side * .65, -1.75, 1.55), (side * .45, -1.05, .95)],
              [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], P["panel"])
    cyl("ChinGun", (0, 1.8, .32), .05, .55, P["dark"], axis="Y", vertices=6)
    pivot("Muzzle", (0, 2.1, .32))


def helix_aa():
    begin("helix", "HaloSkimmer")
    # Hover skimmer with a stabilized interceptor cell and a halo radar ring.
    wedge("Hull", 0, 0, .3, 1.9, 3.1, .55, taper=(.75, .6))
    for side in (-1, 1):
        box("SkirtGlow", (side * .9, 0, .3), (.08, 2.6, .06), P["glass"], bevel=.01)
        box("Sponson", (side * 1.0, -.2, .45), (.35, 2.0, .35), P["panel"], bevel=.05)
    box("TeamPlate", (0, -1.15, .87), (.9, .3, .03), P["team"])
    turret = pivot("TurretPivot", (0, -.15, .85))
    wedge("Mount", 0, -.15, .85, 1.0, 1.1, .35, P["panel"], turret)
    barrel = pivot("BarrelPivot", (0, 0, 1.25), turret, (math.radians(40), 0, 0))
    for side in (-1, 1):
        box("Launcher", (side * .42, .1, 1.3), (.42, 1.15, .55), P["armor"], barrel, .04)
        for row in range(2):
            for col in range(2):
                cyl("Cell", (side * .42 + (col - .5) * .18, .69, 1.18 + row * .24), .065, .04,
                    P["glass"], barrel, "Y", 8)
    pivot("Muzzle", (0, .8, 1.3), barrel)
    halo = pivot("SensorPivot", (0, -.75, 1.75), turret)
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=4, location=(0, -.75, 1.75),
                                     major_radius=.45, minor_radius=.04)
    attach(bpy.context.object, "HaloRing", P["glass"], halo)
    rod("HaloMast", (0, -.75, 1.2), (0, -.75, 1.72), .04, P["steel"], turret)


# --- Frontier --------------------------------------------------------------------


def frontier_fighter():
    begin("frontier", "HornetFighter")
    # Stubby rebuilt jet: thick fuselage, straight wings, patched panels.
    wedge("Fuselage", 0, 0, .35, 1.05, 4.4, .7, taper=(.85, .6))
    cone("Nose", (0, 2.55, .68), .38, .75, P["panel"], vertices=8)
    wedge("Canopy", 0, 1.15, 1.02, .55, 1.0, .3, P["glass"], taper=(.6, .4))
    slab("Wing", [(-2.2, -.85), (-.5, -.95), (-.5, .35), (-2.2, -.35)], .52, .1, P["armor"])
    slab("Wing", [(.5, -.95), (2.2, -.85), (2.2, -.35), (.5, .35)], .52, .1, P["armor"])
    for side in (-1, 1):
        box("Patch", (side * 1.35, -.5, .63), (.45, .35, .03), P["panel"], bevel=.005)
        box("WingTeam", (side * 1.95, -.6, .63), (.3, .4, .03), P["team"])
        cyl("WingTank", (side * 2.25, -.6, .5), .13, 1.0, P["panel"], axis="Y", vertices=8)
        missiles(side * 1.25, -.55, .32, 1, .8, .07)
    shape("TailFin", [(-.06, -2.2, .95), (-.06, -2.35, 1.85), (-.06, -1.5, 1.0),
                      (.06, -2.2, .95), (.06, -2.35, 1.85), (.06, -1.5, 1.0)],
          [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)])
    slab("Stabilizer", [(-1.1, -2.45), (1.1, -2.45), (1.1, -2.05), (-1.1, -2.05)], .75, .07, P["armor"])
    cyl("Exhaust", (0, -2.35, .7), .28, .3, P["dark"], axis="Y", vertices=10)
    for side in (-1, 1):
        cyl("Gun", (side * .4, 1.9, .45), .05, .6, P["dark"], axis="Y", vertices=6)
    gear([(0, 1.6), (-.7, -.5), (.7, -.5)], .42)
    pivot("Muzzle", (0, 2.95, .65))


def frontier_bomber():
    begin("frontier", "BuzzardBomber")
    # Twin-boom cargo conversion with a bomb cradle and two pusher props.
    wedge("Pod", 0, .7, .45, 1.3, 3.4, .95, taper=(.85, .7))
    cone("Nose", (0, 2.65, .9), .55, .7, P["glass"], vertices=10)
    slab("Wing", [(-3.9, -.45), (3.9, -.45), (3.9, .45), (-3.9, .45)], 1.2, .14, P["armor"])
    for side in (-1, 1):
        rod("Boom", (side * 1.5, .3, 1.0), (side * 1.5, -3.2, 1.05), .16, P["panel"])
        cyl("Engine", (side * 1.5, .1, 1.0), .3, 1.2, P["armor"], axis="Y", vertices=10)
        rotor("RotorLeft" if side < 0 else "RotorRight", (side * 1.5, -.6, 1.0), .7, 3, axis="Y")
        shape("TailFin", [(side * 1.5, -3.25, 1.05), (side * 1.5, -3.3, 2.0), (side * 1.5, -2.55, 1.1),
                          (side * 1.62, -3.25, 1.05), (side * 1.62, -3.3, 2.0), (side * 1.62, -2.55, 1.1)],
              [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)])
        box("WingTeam", (side * 3.3, 0, 1.36), (.7, .5, .03), P["team"])
    slab("Stabilizer", [(-1.6, -3.3), (1.6, -3.3), (1.6, -2.9), (-1.6, -2.9)], 1.7, .07, P["armor"])
    box("BombCradle", (0, .5, .35), (.7, 1.6, .12), P["dark"], bevel=.02)
    for y in (-.1, .45, 1.0):
        cyl("Bomb", (0, y, .26), .11, .42, P["dark"], axis="Y", vertices=8)
    gear([(0, 2.0), (-1.5, .2), (1.5, .2)], .65)
    pivot("Muzzle", (0, .5, .25))


def frontier_aa():
    begin("frontier", "RipsawTruck")
    # Improvised gun truck: cab, flatbed and a ring-mounted twin autocannon.
    wheels(2.0, (-1.15, .05, 1.15), .4)
    box("Chassis", (0, 0, .62), (1.8, 3.4, .28), P["dark"], bevel=.03)
    wedge("Cab", 0, 1.25, .76, 1.75, 1.0, .85, P["armor"], taper=(.9, .75))
    box("Windshield", (0, 1.72, 1.32), (1.4, .05, .38), P["glass"], bevel=.01)
    box("Flatbed", (0, -.55, .82), (1.85, 2.1, .14), P["panel"], bevel=.02)
    for side in (-1, 1):
        box("Sideboard", (side * .9, -.55, 1.0), (.06, 2.1, .32), P["armor"], bevel=.01)
    box("TeamPlate", (0, 1.25, 1.62), (.9, .45, .03), P["team"])
    turret = pivot("TurretPivot", (0, -.65, 1.0))
    cyl("Ring", (0, -.65, 1.05), .55, .12, P["steel"], turret, vertices=14)
    box("GunShield", (0, -.3, 1.4), (.9, .08, .55), P["armor"], turret, .03)
    barrel = pivot("BarrelPivot", (0, -.55, 1.35), turret, (math.radians(30), 0, 0))
    for side in (-1, 1):
        cyl("Autocannon", (side * .18, .3, 1.35), .06, 1.5, P["dark"], barrel, "Y", 8)
    box("Receiver", (0, -.55, 1.35), (.55, .6, .32), P["steel"], barrel, .03)
    pivot("Muzzle", (0, 1.1, 1.35), barrel)


bastion_fighter(); bastion_bomber(); bastion_helicopter(); bastion_flak()
helix_fighter(); helix_bomber(); helix_helicopter(); helix_aa()
frontier_fighter(); frontier_bomber(); frontier_aa()

# Export evaluated copies, joining objects that share a rigid parent (as the
# faction builders do) so pivots stay separate nodes in Godot.
manifest = []
for faction, name, collection, asset_root in assets:
    if BUILD_FACTION is not None and faction != BUILD_FACTION:
        continue
    bpy.context.view_layer.update()
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
    live = [obj for obj in scene.collection.objects if obj.name.startswith("export_")]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in live:
        obj.select_set(True)
    triangles = sum(len(obj.data.polygons) for obj in live if obj.type == "MESH")
    weathering.bake(live)
    models, _icons = OUTPUT[faction]
    bpy.ops.export_scene.gltf(filepath=str(models / (name + ".glb")), export_format="GLB", use_selection=True,
                              export_animations=False, export_yup=True, export_cameras=False, export_lights=False,
                              export_vertex_color="ACTIVE")
    for obj in live:
        bpy.data.objects.remove(obj, do_unlink=True)
    manifest.append({"faction": faction, "name": name, "triangles": triangles})
    collection.hide_render = True

def render_catalogue():
    # Roster icons from the actual geometry, matching the faction icon renders.
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

    # Editable catalogue of every new model.
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
