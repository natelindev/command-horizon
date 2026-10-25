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
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
import weathering  # noqa: E402
import trim_sheet  # noqa: E402
import markings  # noqa: E402
import track_rig

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


ARMOR = mat("Bastion_Armor", (.065,.076,.064))
PANEL = mat("Bastion_Panels", (.14,.155,.13))
DARK = mat("Bastion_Mechanisms", (.025,.033,.034), .55)
STEEL = mat("Bastion_Steel", (.28,.32,.32), .7)
TEAM = mat("TeamColor_Bastion", (.65,.28,.015))
RUBBER = mat("Bastion_Rubber", (.016,.023,.025), 0,.85)
GLASS = mat("Bastion_Optics", (.10,.53,.66), .25,.25,.35)
WHITE = mat("Bastion_Markings", (.75,.75,.62), .1)
CONCRETE = mat("Bastion_Concrete", (.22,.245,.24), 0,.85)
ROCK = mat("Desert_Rock", (.38,.21,.105), 0,.9)
ORE = mat("Materials_Ore", (.32,.38,.42), .55,.65)
CRYSTAL = mat("Electronics_Silicon", (.06,.39,.51), .4,.4,.1)
assets = []
current = None
root = None


def begin(name):
    global current, root
    current = bpy.data.collections.new(name)
    scene.collection.children.link(current)
    root = bpy.data.objects.new(name,None)
    current.objects.link(root)
    root["faction"] = "Bastion"
    root["forward"] = "-Z in Godot"
    assets.append((name,current,root))
    return root


def attach(obj, name, material, parent=None, bevel=0):
    obj.name = current.name + "_" + name
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    current.objects.link(obj)
    if material:
        obj.data.materials.append(material)
    if bevel:
        modifier = obj.modifiers.new("Edge chamfer","BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        normal = obj.modifiers.new("Weighted normals","WEIGHTED_NORMAL")
        normal.keep_sharp = True
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent or root
    obj.matrix_world = world
    return obj


def box(name, xyz, size, material=ARMOR, parent=None, bevel=.04, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if rot:
        obj.rotation_euler = rot
    return attach(obj,name,material,parent,bevel)


def cyl(name, xyz, radius, depth, material=DARK, parent=None, axis="Z", vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=xyz)
    obj = bpy.context.object
    if axis=="Y": obj.rotation_euler.x=math.pi/2
    if axis=="X": obj.rotation_euler.y=math.pi/2
    return attach(obj,name,material,parent)


def rod(name, a, b, radius, material=STEEL, parent=None, vertices=8):
    delta=Vector(b)-Vector(a)
    obj=cyl(name,(Vector(a)+Vector(b))/2,radius,delta.length,material,parent,vertices=vertices)
    obj.rotation_euler=delta.to_track_quat("Z","Y").to_euler()
    return obj


def shape(name, vertices, faces, material=ARMOR, parent=None, bevel=.02):
    data=bpy.data.meshes.new(name)
    data.from_pydata(vertices,[],faces)
    data.update()
    bm=bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(data); bm.free()
    obj=bpy.data.objects.new(name,data); current.objects.link(obj)
    return attach(obj,name,material,parent,bevel)


def wedge(name, x, y, z, width, length, height, material=ARMOR, parent=None):
    w,l,h=width/2,length/2,height
    return shape(name,[(x-w,y-l,z),(x+w,y-l,z),(x+w,y+l,z),(x-w,y+l,z),
                      (x-w*.8,y-l*.8,z+h),(x+w*.8,y-l*.8,z+h),
                      (x+w*.7,y+l*.65,z+h),(x-w*.7,y+l*.65,z+h)],
                 [(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)],material,parent,.04)


def pivot(name, xyz, parent=None):
    obj=bpy.data.objects.new(current.name+"_"+name,None)
    current.objects.link(obj); obj.location=xyz
    bpy.context.view_layer.update()
    world=obj.matrix_world.copy(); obj.parent=parent or root; obj.matrix_world=world
    return obj


def badge(x,y,z,scale=.5,parent=None):
    pts=[(-.55,.34),(0,-.05),(.55,.34),(.55,.08),(0,-.34),(-.55,.08)]
    shape("Chevron",[(x+a*scale,y,z+b*scale) for a,b in pts],[(0,1,2,3,4,5)],TEAM,parent,0)


def tracks(width=2.0,length=2.8):
    for side in (-1,1):
        x=side*width/2
        box("TrackBelt",(x,0,.42),(.5,length,.74),RUBBER,bevel=.18)
        for i in range(5):
            y=-length*.37+i*length*.185
            cyl("Wheel",(x+side*.26,y,.43),.25,.055,PANEL,axis="X")
            cyl("Hub",(x+side*.30,y,.43),.075,.04,STEEL,axis="X",vertices=8)
        track = pivot("TrackPivot" + ("Left" if side < 0 else "Right"), (0,0,0))
        half, radius, height = length*.38, .35, .43
        perimeter = 4*half+2*math.pi*radius
        for i in range(28):
            distance = perimeter*i/28
            y,z,angle = track_rig.capsule(distance,half,radius,height)
            shoe = box("Tread",(x,y,z),(.55,.12,.055),DARK,track,bevel=0,rot=(angle,0,0))
            track_rig.encode(shoe,distance,half,radius,height)
        box("Fender",(x,0,.89),(.65,length,.13),ARMOR)


def lens(x,y,z,width=.25,parent=None):
    box("SensorHousing",(x,y,z),(width+.14,.23,.22),DARK,parent,.025)
    box("Sensor",(x,y+.13,z),(width,.025,.105),GLASS,parent,.005)


def infantry():
    begin("Infantry")
    # Separate leg pivots support a modest procedural walking cycle.
    for side,name in ((-1,"LegLeft"),(1,"LegRight")):
        leg=pivot(name,(side*.19,0,1.0))
        box("Thigh",(side*.19,0,.78),(.29,.32,.47),ARMOR,leg,.065)
        box("Knee",(side*.19,.13,.56),(.31,.16,.22),TEAM,leg,.035)
        box("Shin",(side*.19,-.015,.34),(.25,.29,.36),PANEL,leg,.045)
        box("Boot",(side*.19,.10,.12),(.31,.5,.22),DARK,leg,.035)
    box("Pelvis",(0,0,1.03),(.61,.36,.24),DARK)
    wedge("Torso",0,0,1.08,.83,.47,.64,PANEL)
    box("ChestPlate",(0,.275,1.43),(.59,.12,.35),ARMOR)
    badge(0,.342,1.46,.35)
    box("Backpack",(0,-.35,1.43),(.51,.28,.51),DARK)
    for side in (-1,1):
        box("Shoulder",(side*.47,0,1.62),(.31,.44,.28),TEAM,bevel=.07)
        rod("UpperArm",(side*.49,0,1.52),(side*.5,.23,1.21),.13,ARMOR)
        rod("Forearm",(side*.5,.23,1.21),(side*.20,.56,1.25),.115,PANEL)
        box("Glove",(side*.2,.56,1.25),(.16,.22,.16),DARK)
    cyl("Neck",(0,0,1.8),.13,.16,DARK)
    box("Helmet",(0,0,1.98),(.51,.48,.42),ARMOR,bevel=.12)
    box("Visor",(0,.242,2.015),(.4,.045,.14),GLASS,bevel=.025)
    box("HelmetStripe",(0,-.03,2.201),(.12,.31,.012),TEAM,bevel=0)
    box("RifleBody",(.1,.54,1.37),(.18,.61,.2),DARK,bevel=.02)
    cyl("RifleBarrel",(.1,1.03,1.4),.038,.54,STEEL,axis="Y",vertices=8)
    box("Magazine",(.1,.59,1.20),(.12,.16,.22),ARMOR,bevel=.01)
    pivot("Muzzle",(.1,1.32,1.4))


def rover(name,repair=False):
    begin(name); tracks(1.65,2.65)
    wedge("Hull",0,0,.55,1.9,2.5,.59)
    box("Deck",(0,-.2,1.17),(1.6,1.5,.12),PANEL)
    box("TeamPlate",(0,.92,1.13),(1.3,.32,.06),TEAM)
    lens(0,1.19,1.04,.5)
    if repair:
        for side in (-1,1):
            arm=pivot("ServiceArm"+str(side),(side*.63,-.24,1.2))
            rod("ArmLower",(side*.63,-.24,1.2),(side*.81,.0,1.93),.12,TEAM,arm)
            cyl("Elbow",(side*.81,.0,1.93),.18,.21,DARK,arm,axis="X")
            rod("ArmUpper",(side*.81,0,1.93),(side*.59,.75,1.5),.095,STEEL,arm)
            for dx in (-.10,.10):
                rod("Gripper",(side*.59+dx,.75,1.5),(side*.59+dx,.97,1.32),.035,DARK,arm)
        box("ToolCabinet",(0,-.70,1.43),(1.2,.65,.45),ARMOR)
        vertices, faces = markings.service_gear(0, -1.05, 1.45, size=.8)
        shape("ServiceGear", vertices, faces, WHITE, bevel=0)
    else:
        box("Cab",(0,.15,1.43),(1.25,.92,.52),PANEL,bevel=.09)
        lens(0,.63,1.48,.91)
        box("CargoBed",(0,-.85,1.25),(1.45,.7,.22),DARK)
        for x in (-.4,0,.4): box("Cargo",(x,-.85,1.44),(.3,.49,.24),ORE)
        rod("CraneMast",(.72,-.85,1.3),(.72,-.85,2.0),.07,TEAM)
        rod("CraneBoom",(.72,-.85,2),(.72,.6,1.78),.07,TEAM)
    antenna=pivot("AntennaPivot",(-.6,-.85,1.4))
    rod("Antenna",(-.6,-.85,1.4),(-.6,-.85,2.35),.012,DARK,antenna)


def combat_robot():
    begin("CombatRobot")
    wedge("Body",0,0,1.04,2.05,2.15,.59)
    for side in (-1,1):
        for front in (-1,1):
            name=("LegLeft" if side<0 else "LegRight")+("Front" if front>0 else "Rear")
            leg=pivot(name,(side*.81,front*.61,1.28))
            rod("UpperLeg",(side*.81,front*.61,1.28),(side*1.18,front*.92,.77),.19,PANEL,leg)
            knee=pivot("KneePivot"+name.removeprefix("Leg"),(side*1.18,front*.92,.77),leg)
            cyl("Joint",(side*1.18,front*.92,.77),.24,.27,DARK,knee,axis="X")
            rod("Shin",(side*1.18,front*.92,.77),(side*1.35,front*1.12,.22),.14,TEAM,knee)
            ankle=pivot("AnklePivot"+name.removeprefix("Leg"),(side*1.35,front*1.12,.22),knee)
            box("Foot",(side*1.35,front*1.12,.13),(.47,.66,.24),DARK,ankle,.05)
    lens(0,1.07,1.39,.58)
    turret=pivot("TurretPivot",(0,0,1.69))
    cyl("TurretRing",(0,0,1.65),.61,.12,DARK,turret)
    wedge("Turret",0,0,1.7,1.44,1.34,.46,PANEL,turret)
    box("TeamMark",(0,-.25,2.18),(.82,.41,.035),TEAM,turret)
    barrel=pivot("BarrelPivot",(0,.59,1.92),turret)
    cyl("Cannon",(0,1.37,1.92),.115,1.6,DARK,barrel,axis="Y")
    box("MuzzleBrake",(0,2.11,1.92),(.32,.41,.3),PANEL,barrel)
    pivot("Muzzle",(0,2.34,1.92),barrel)


def drone():
    begin("Drone")
    wedge("Body",0,0,.05,1.05,1.58,.60)
    box("TeamRoof",(0,-.1,.66),(.63,.62,.04),TEAM)
    lens(0,.80,.33,.46)
    cyl("Gimbal",(0,.48,.05),.22,.22,DARK,vertices=12)
    for side,label in ((-1,"Left"),(1,"Right")):
        rod("WingStrut",(side*.42,0,.35),(side*1.35,0,.35),.1,STEEL)
        bpy.ops.mesh.primitive_torus_add(major_segments=20,minor_segments=4,location=(side*1.31,0,.40),major_radius=.64,minor_radius=.13)
        attach(bpy.context.object,"Duct"+label,ARMOR)
        rotor=pivot("Rotor"+label,(side*1.31,0,.4))
        cyl("FanHub",(side*1.31,0,.4),.14,.16,PANEL,rotor)
        for angle in (0,math.pi/2):
            box("FanBlade",(side*1.31,0,.4),(1.05,.1,.035),DARK,rotor,.008,(0,0,angle))


def aircraft():
    begin("Helicopter")
    # A lift-capable strike aircraft: nacelle fans explain hovering in the RTS flight model.
    wedge("Fuselage",0,0,.08,1.45,4.6,.73)
    wedge("Canopy",0,.95,.78,.89,1.58,.42,GLASS)
    for side in (-1,1):
        verts=[(side*.45,-1.45,.53),(side*2.8,-1.30,.44),(side*2.9,-.78,.44),
               (side*.57,.64,.62)]
        shape("Wing",verts+[(x,y,z-.13) for x,y,z in verts],
              [(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],PANEL)
        box("WingTeam",(side*2.21,-1.0,.52),(.56,.4,.035),TEAM)
        cyl("Engine",(side*.94,-1.09,.88),.38,1.65,ARMOR,axis="Y",vertices=12)
        cyl("Exhaust",(side*.94,-1.94,.88),.28,.06,DARK,axis="Y",vertices=12)
        cyl("Intake",(side*.94,-.23,.88),.29,.035,DARK,axis="Y",vertices=12)
        for y in (-.9,-.4):
            cyl("VTOLFan",(side*1.47,y,.61),.30,.08,DARK,vertices=16)
        for x in (1.62,2.15):
            cyl("Missile",(side*x,-.45,.23),.09,1.04,DARK,axis="Y",vertices=8)
            cyl("MissileBand",(side*x,-.15,.23),.096,.13,TEAM,axis="Y",vertices=8)
    shape("TailFin",[(-.07,-2,.55),(-.07,-2,1.94),(-.07,-.91,.7),
                     (.07,-2,.55),(.07,-2,1.94),(.07,-.91,.7)],
          [(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)],ARMOR)
    cyl("NoseGun",(0,2.22,.35),.075,.62,DARK,axis="Y",vertices=8)
    pivot("Muzzle",(0,2.55,.35))


def import_tank(name,advanced=False):
    begin(name)
    root.name=name+"_Container"
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/"assets/models/bastion/tank-v1/bastion_tank_v1.glb"))
    imported=set(bpy.data.objects)-before
    imported_root=next(obj for obj in imported if obj.parent is None)
    imported_root.parent=root
    for obj in imported:
        original=obj.name.split(".")[0]
        obj.name=name+"_"+original
        for collection in list(obj.users_collection): collection.objects.unlink(obj)
        current.objects.link(obj)
    if advanced:
        barrel=next(obj for obj in imported if "BarrelPivot" in obj.name)
        old=next(obj for obj in imported if "BarrelMesh" in obj.name)
        imported.remove(old)
        bpy.data.objects.remove(old,do_unlink=True)
        box("RailHousing",(0,2.05,2.04),(.75,1.8,.55),PANEL,barrel,.075)
        for side in (-1,1):
            box("Rail",(side*.24,3.85,2.04),(.17,2.5,.42),DARK,barrel,.035)
            box("Conductor",(side*.24,3.85,2.265),(.09,2.30,.035),GLASS,barrel,.01)
        box("Accelerator",(0,5.0,2.04),(.8,.45,.62),TEAM,barrel,.09)
        box("MuzzleInset",(0,5.236,2.04),(.43,.015,.3),DARK,barrel,.025)
        muzzle=next(obj for obj in imported if "Muzzle" in obj.name)
        muzzle.location.y=4.15


def base_building(name,w=5,l=5):
    begin(name)
    box("Foundation",(0,0,.15),(w+.6,l+.6,.3),CONCRETE,bevel=.12)
    box("Floor",(0,0,.33),(w,l,.15),DARK)


def facade(w,l,h=2.3):
    box("Core",(0,0,h/2+.36),(w,l,h),ARMOR,bevel=.16)
    box("Roof",(0,0,h+.45),(w+.2,l+.2,.24),PANEL,bevel=.08)
    for side in (-1,1):
        for y in (-l/2+.25,l/2-.25):
            box("Buttress",(side*(w/2-.17),y,h/2+.4),(.42,.46,h+.2),CONCRETE)
    box("DoorRecess",(0,l/2+.025,1.1),(1.4,.05,1.5),DARK)
    box("DoorTopLight",(0,l/2+.06,1.9),(1.2,.04,.10),GLASS)
    badge(0,l/2+.065,h-.15,.8)


def headquarters():
    base_building("CommandCenter",5.2,4.8); facade(5.2,4.8,2.15)
    box("CommandTower",(0,-.35,3.10),(2.8,2.55,1.4),CONCRETE,bevel=.16)
    box("ObservationGlass",(0,1.0,3.35),(2.35,.035,.47),GLASS)
    for side in (-1,1): box("ObservationGlass",(side*1.425,-.35,3.35),(.025,2,.47),GLASS)
    box("TowerRoof",(0,-.35,3.92),(3.3,3.0,.23),ARMOR)
    box("TeamRoof",(0,-.35,4.06),(1.0,2.7,.045),TEAM)
    for x in (-.9,.9): rod("Aerial",(x,-.9,4),(x,-.9,5.35),.035,DARK)
    cyl("RadarBase",(.65,.12,4.25),.26,.3,DARK)
    box("RadarPanel",(.65,.12,4.69),(1.05,.14,.55),PANEL)


def factory(name,air=False):
    base_building(name,6,5.5)
    for side in (-1,1):
        box("HangarWall",(side*2.55,0,1.64),(.9,5.35,2.55),ARMOR,bevel=.14)
        for y in (-2,0,2): box("Pillar",(side*2.89,y,1.77),(.23,.4,2.8),CONCRETE)
        box("TeamFascia",(side*2.54,2.73,2.0),(.65,.07,1.95),TEAM)
    box("RearWall",(0,-2.4,1.62),(4.9,.55,2.5),DARK)
    box("Roof",(0,0,3.03),(6.1,5.6,.34),PANEL,bevel=.15)
    box("FrontLintel",(0,2.58,2.8),(4.3,.42,.55),ARMOR)
    box("DoorLight",(0,2.82,2.66),(3.4,.035,.08),GLASS)
    for x in (-1.6,-.8,0,.8,1.6): box("RoofRib",(x,0,3.25),(.18,5.1,.18),DARK)
    for side in (-1,1):
        box("Lane",(side*1.4,0,.425),(.10,4.9,.012),TEAM,bevel=0)
    if air:
        box("FlightControl",(2.0,-1.0,3.85),(1.8,2.1,1.18),ARMOR)
        box("ControlWindow",(2,.08,3.96),(1.48,.04,.44),GLASS)
        rod("RadarPole",(2,-1,4.5),(2,-1,5.2),.06,STEEL)
        box("Radar",(2,-1,5.24),(1.3,.20,.47),TEAM)
    else:
        for x in (-1.75,1.75):
            cyl("Vent",(x,-1.2,3.55),.40,.6,DARK)
            cyl("VentCap",(x,-1.2,3.87),.48,.06,STEEL)
        box("CraneBeam",(0,.4,2.39),(3.9,.24,.24),TEAM)


def barracks():
    base_building("Barracks",4.1,4.4); facade(4.1,4.4,1.9)
    for x in (-1.35,1.35):
        box("RoofStripe",(x,0,2.49),(.35,4.2,.045),TEAM)
        for y in (-1.2,0,1.2): box("SideWindow",(x/abs(x)*2.075,y,1.63),(.025,.58,.34),GLASS)
    box("RoofVent",(0,-.9,2.70),(1.3,1.1,.4),DARK)
    for i in range(5): box("VentSlat",(-.48+i*.24,-.9,2.92),(.07,.91,.035),STEEL,bevel=0)


def generator():
    base_building("PowerPlant",3.8,4.0)
    for x in (-.87,.87):
        cyl("Generator",(x,0,1.61),.68,2.45,ARMOR,vertices=16)
        for z in (.65,1.1,2.0,2.6): cyl("CoolingBand",(x,0,z),.76,.14,STEEL,vertices=16)
        cyl("PowerCap",(x,0,2.9),.69,.18,TEAM,vertices=16)
        cyl("Stack",(x,-.65,3.27),.23,.7,DARK)
    box("ControlCabinet",(0,1.46,1.02),(2.6,.72,1.3),PANEL)
    box("StatusDisplay",(0,1.84,1.27),(.82,.03,.28),GLASS)
    badge(0,1.85,.81,.48)


def lab():
    base_building("CommandLab",4.2,4.3); facade(4.2,4.3,2.1)
    for side in (-1,1):
        box("ServerPod",(side*1.56,-.1,2.95),(.87,2.35,1.02),DARK)
        for y in (-.85,-.2,.45): box("ServerBand",(side*1.56,y,3.49),(.71,.12,.025),GLASS)
    box("ComputeCore",(0,-.1,2.82),(1.38,1.75,.8),TEAM)
    box("ChipTop",(0,-.1,3.25),(.91,1.27,.08),DARK)
    rod("DishMast",(0,-1.38,2.4),(0,-1.38,3.7),.07,STEEL)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=1,location=(0,-1.38,3.95))
    obj=bpy.context.object; obj.scale=(.78,.20,.60)
    attach(obj,"SignalDish",PANEL)


def depot():
    base_building("RepairDepot",5.0,4.7)
    for side in (-1,1):
        box("ServiceTower",(side*2.05,0,1.62),(.75,4.3,2.5),ARMOR)
        rod("CraneLeg",(side*1.55,-.8,.45),(side*1.55,-.8,3.2),.11,STEEL)
        vertices, faces = markings.service_gear(side*2.05, 2.20, 1.7, size=1.2)
        shape("ServiceGear", vertices, faces, WHITE, bevel=0)
        box("ServiceStrip",(side*1.3,.1,.44),(.17,3.95,.02),TEAM,bevel=0)
    box("OverheadCrane",(0,-.8,3.25),(3.7,.46,.44),TEAM)
    rod("SuspendedTool",(.55,-.8,3.05),(.55,-.8,1.9),.05,DARK)
    box("BackTools",(0,-2.01,1.16),(3.4,.43,1.35),PANEL)


def defense(name,aa=False):
    base_building(name,2.8,2.8)
    wedge("Plinth",0,0,.32,2.8,2.8,.7,CONCRETE)
    cyl("Ring",(0,0,1.05),1.0,.18,DARK,vertices=20)
    turret=pivot("TurretPivot",(0,0,1.15))
    wedge("Turret",0,0,1.12,2.15,1.94,.62,PANEL,turret)
    badge(0,1.0,1.48,.7,turret)
    if aa:
        for side in (-1,1):
            box("MissilePod",(side*1.05,.12,1.89),(.67,1.7,.64),ARMOR,turret,.10,(-.27,0,0))
            for x in (-.15,.15):
                for z in (-.15,.15): cyl("Tube",(side*1.05+x,.97,1.89+z),.09,.025,DARK,turret,axis="Y",vertices=8)
        rod("RadarMast",(0,-.5,1.7),(0,-.5,2.45),.055,STEEL,turret)
        box("Radar",(0,-.5,2.49),(1.05,.15,.38),TEAM,turret)
        pivot("Muzzle",(1.05,1.05,1.9),turret)
    else:
        barrel=pivot("BarrelPivot",(0,.8,1.55),turret)
        for side in (-1,1):
            cyl("Cannon",(side*.28,1.5,1.55),.11,1.55,DARK,barrel,axis="Y")
            box("Tip",(side*.28,2.20,1.55),(.27,.32,.27),ARMOR,barrel)
        pivot("Muzzle",(0,2.4,1.55),barrel)


def resources(name,electronics=False):
    begin(name)
    for i in range(7):
        x,y=random.uniform(-.85,.85),random.uniform(-.7,.7)
        z=random.uniform(.28,.65)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x,y,z*.6))
        obj=bpy.context.object; obj.scale=(.55,.48,z)
        attach(obj,"Mineral",CRYSTAL if electronics else ORE)
    box("Pallet",(0,0,.12),(2.5,2,.2),DARK)
    for side in (-1,1): box("Bracket",(side*1.05,0,.29),(.16,1.8,.17),TEAM if not electronics else GLASS)


def cliff():
    begin("CliffCluster")
    for x,y,z,r in ((0,0,1.6,2.7),(1.9,.3,1.0,1.7),(-1.7,.3,.8,1.6),(.1,1.7,.7,1.5)):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=r,location=(x,y,z))
        obj=bpy.context.object; obj.scale=(1,.78,1.15)
        attach(obj,"Sandstone",ROCK)


# Fast, reproducible rig-only export; full catalogue builds remain the default.
walkers_only = "--walkers-only" in sys.argv
motion_only = "--motion-only" in sys.argv
if motion_only:
    rover("Worker"); rover("RepairRobot",True); import_tank("Tank"); import_tank("AdvancedTank",True)
elif walkers_only:
    combat_robot()
else:
    infantry(); rover("Worker"); import_tank("Tank"); import_tank("AdvancedTank",True)
    rover("RepairRobot",True); combat_robot(); drone(); aircraft()
    headquarters(); barracks(); factory("VehicleFactory"); factory("AircraftFactory",True)
    generator(); lab(); depot(); defense("AntiGroundTurret"); defense("AntiAirTurret",True)
    resources("ResourceA"); resources("ResourceB",True); cliff()

# Export evaluated copies, joining objects that share a rigid parent.
manifest=[]
for name,collection,asset_root in assets:
    bpy.context.view_layer.update()
    for part in collection.objects:
        # Both UV channels encode tread travel/profile, including imported belts.
        if not (part.parent and "TrackPivot" in part.parent.name):
            trim_sheet.prepare(part)
    deps=bpy.context.evaluated_depsgraph_get()
    copies={}
    for obj in collection.objects:
        clone=bpy.data.objects.new("export_"+obj.name,
            bpy.data.meshes.new_from_object(obj.evaluated_get(deps),depsgraph=deps) if obj.type=="MESH" else None)
        scene.collection.objects.link(clone); clone.matrix_world=obj.matrix_world.copy()
        copies[obj]=clone
    for obj,clone in copies.items():
        if obj.parent in copies:
            matrix=clone.matrix_world.copy(); clone.parent=copies[obj.parent]; clone.matrix_world=matrix
    groups={}
    for obj in copies.values():
        if obj.type=="MESH": groups.setdefault(obj.parent,[]).append(obj)
    for parent,objects in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
        joined=bpy.context.object
        if parent and "TrackPivot" in parent.name:
            # Runtime capsule coordinates are in model space (+Y becomes -Z).
            joined.data.transform(joined.matrix_world)
            joined.matrix_world.identity()
        modifier=joined.modifiers.new("Triangulate","TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bm=bmesh.new(); bm.from_mesh(joined.data)
        bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.calc_area()<1e-10],context="FACES_ONLY")
        bm.to_mesh(joined.data); bm.free()
    live=[obj for obj in scene.collection.objects if obj.name.startswith("export_")]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in live: obj.select_set(True)
    triangles=sum(len(obj.data.polygons) for obj in live if obj.type=="MESH")
    weathering.bake(live)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")),export_format="GLB",use_selection=True,
        export_animations=False,export_yup=True,export_cameras=False,export_lights=False,
        export_vertex_color="ACTIVE")
    for obj in live: bpy.data.objects.remove(obj,do_unlink=True)
    manifest.append({"name":name,"triangles":triangles,"file":name+".glb"})
    collection.hide_render=True

if walkers_only or motion_only:
    print("Bastion motion rigs exported" if motion_only else "Bastion walker rig exported")
    raise SystemExit(0)

if "--models-only" in sys.argv:
    print("Material-ready faction models exported")
    raise SystemExit(0)

# Render actual geometry for roster icons.
world=bpy.data.worlds.new("Bastion studio"); scene.world=world; world.use_nodes=True
world.node_tree.nodes["Background"].inputs[0].default_value=(.22,.27,.34,1)
world.node_tree.nodes["Background"].inputs[1].default_value=.45
for name,loc,power,color in (("Key",(4,6,11),1800,(1,.88,.72)),("Fill",(-6,1,6),1500,(.7,.83,1)),("Rim",(3,-6,8),2100,(1,.92,.78))):
    data=bpy.data.lights.new(name,"AREA"); data.energy=power; data.shape="DISK"; data.size=7; data.color=color
    obj=bpy.data.objects.new(name,data); scene.collection.objects.link(obj); obj.location=loc
    obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat("-Z","Y").to_euler()
camera_data=bpy.data.cameras.new("Camera"); camera=bpy.data.objects.new("Camera",camera_data)
scene.collection.objects.link(camera); scene.camera=camera; camera_data.type="ORTHO"
scene.render.engine="CYCLES"; scene.cycles.samples=16; scene.cycles.use_denoising=True
scene.render.resolution_percentage=100; scene.render.resolution_x=256; scene.render.resolution_y=256
scene.render.image_settings.file_format="PNG"; scene.render.film_transparent=True
scene.view_settings.view_transform="AgX"
for name,collection,asset_root in assets:
    collection.hide_render=False
    points=[obj.matrix_world@Vector(p) for obj in collection.objects if obj.type=="MESH" for p in obj.bound_box]
    lo=Vector([min(p[i] for p in points) for i in range(3)])
    hi=Vector([max(p[i] for p in points) for i in range(3)])
    center=(lo+hi)/2
    camera.location=center+Vector((9,12,10))
    camera.rotation_euler=(center-camera.location).to_track_quat("-Z","Y").to_euler()
    camera_data.ortho_scale=max(hi-lo)*1.45
    scene.render.filepath=str(ICONS/(name+".png")); bpy.ops.render.render(write_still=True)
    collection.hide_render=True
    manifest[next(i for i,item in enumerate(manifest) if item["name"]==name)]["bounds"]={"min":list(lo),"max":list(hi)}

# Editable catalogue: all source components retained, neatly spaced on a grid.
for i,(name,collection,asset_root) in enumerate(assets):
    collection.hide_render=False
    asset_root.location=Vector(((i%5-2)*9,(i//5-1.5)*10,0))
camera.location=(38,45,48)
camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat("-Z","Y").to_euler()
camera_data.ortho_scale=62
scene.render.film_transparent=False
scene.render.resolution_x=1800; scene.render.resolution_y=1500
scene.cycles.samples=32
scene.render.filepath=str(SOURCE/"faction-catalogue.png")
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"bastion_faction.blend"))
bpy.ops.render.render(write_still=True)
(SOURCE/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("Bastion assets complete:",len(manifest))
