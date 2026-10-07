"""Rebuild the Helix concept-derived models, editable catalogue, icons and contact renders.

blender --background --factory-startup --python-exit-code 1 --python art/helix/build_faction.py
"""
import json
import math
from pathlib import Path
import random

import bmesh
import bpy
from mathutils import Vector

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


ARMOR = mat("Helix_Ceramic", (.72,.73,.66), .15,.42)
PANEL = mat("Helix_Secondary", (.42,.48,.46), .25,.48)
DARK = mat("Helix_Graphite", (.025,.043,.050), .6,.4)
STEEL = mat("Helix_Titanium", (.22,.28,.30), .75,.35)
TEAM = mat("TeamColor_Helix", (.015,.23,.25), .25,.42)
RUBBER = mat("Helix_Rubber", (.012,.019,.021), 0,.88)
GLASS = mat("Helix_Optics", (.04,.65,.72), .25,.22,1.2)
WHITE = ARMOR
ORANGE = mat("Helix_Warning", (.95,.23,.025), .1,.5)
CONCRETE = mat("Helix_Foundation", (.20,.245,.26), 0,.85)
assets = []
current = None
root = None


def begin(name):
    global current, root
    current = bpy.data.collections.new(name)
    scene.collection.children.link(current)
    root = bpy.data.objects.new(name,None)
    current.objects.link(root)
    root["faction"] = "Helix Systems"
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


# All shapes below were built after inspecting the three Helix imagegen sheets.
# Source components remain editable; evaluated rigid groups are merged only for GLB export.

def beam(name,a,b,width,depth,material=ARMOR,parent=None):
    delta=Vector(b)-Vector(a)
    obj=box(name,(Vector(a)+Vector(b))/2,(width,depth,delta.length),material,parent,.035)
    obj.rotation_euler=delta.to_track_quat("Z","Y").to_euler()
    return obj


def prism(name,points,z,height,material=ARMOR,parent=None,inset=.85):
    n=len(points); cx=sum(p[0] for p in points)/n; cy=sum(p[1] for p in points)/n
    vertices=[(x,y,z) for x,y in points]+[(cx+(x-cx)*inset,cy+(y-cy)*inset,z+height) for x,y in points]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return shape(name,vertices,faces,material,parent,.025)


def shell(name,x,y,z,w,l,h,material=ARMOR,parent=None):
    return prism(name,[(x-w*.5,y-l*.32),(x-w*.28,y-l*.5),(x+w*.28,y-l*.5),
        (x+w*.5,y-l*.32),(x+w*.5,y+l*.20),(x+w*.24,y+l*.5),(x-w*.24,y+l*.5),(x-w*.5,y+l*.20)],z,h,material,parent)


def ring(name,center,radius,thickness,material=ARMOR,parent=None,rotation=None):
    bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=6,location=center,
        major_radius=radius,minor_radius=thickness)
    obj=bpy.context.object
    if rotation: obj.rotation_euler=rotation
    return attach(obj,name,material,parent)


def lens(x,y,z,width=.45,parent=None):
    box("SensorWell",(x,y,z),(width+.13,.16,.22),DARK,parent,.025)
    box("Optic",(x,y+.09,z),(width,.025,.10),GLASS,parent,.008)


def vent(x,y,z,width=.8,length=.6):
    box("VentInset",(x,y,z),(width,length,.06),DARK,bevel=.01)
    for i in range(5): box("VentFin",(x-width*.38+i*width*.19,y,z+.035),(.045,length*.85,.04),STEEL,bevel=0)


def antenna(x,y,z,parent=None):
    cyl("AntennaBase",(x,y,z+.06),.09,.12,DARK,parent)
    rod("Antenna",(x,y,z),(x,y,z+.72),.018,STEEL,parent)


def warning(x,y,z,parent=None):
    box("Warning",(x,y,z),(.15,.035,.12),ORANGE,parent,.005)


def gun(turret_z,length=2.3,parent=None,rail=False):
    barrel=pivot("BarrelPivot",(0,.45,turret_z),parent)
    if rail:
        for side in (-1,1):
            shell("AcceleratorRail",side*.25,1.6,turret_z-.11,.26,3.3,.29,ARMOR,barrel)
            box("RailInner",(side*.13,1.6,turret_z+.025),(.025,2.8,.07),GLASS,barrel,.005)
            box("RailMuzzle",(side*.25,3.19,turret_z+.02),(.32,.28,.36),DARK,barrel,.02)
        pivot("Muzzle",(0,3.38,turret_z),barrel)
    else:
        box("GunMantlet",(0,.59,turret_z),(.56,.68,.40),ARMOR,barrel,.08)
        cyl("GunBarrel",(0,.9+length*.5,turret_z),.065,length,STEEL,barrel,axis="Y")
        cyl("MuzzleBrake",(0,.92+length,turret_z),.105,.28,DARK,barrel,axis="Y")
        pivot("Muzzle",(0,1.1+length,turret_z),barrel)
    return barrel


def wheels(width=2.3,length=3.0,r=.48):
    for side in (-1,1):
        for index,y in enumerate((-length*.38,0,length*.38)):
            wheel=pivot("Wheel_%s_%s"%(side,index),(side*width*.5,y,r+.02))
            cyl("Tire",(side*width*.5,y,r+.02),r,.38,RUBBER,wheel,axis="X",vertices=16)
            cyl("Rim",(side*(width*.5+.205),y,r+.02),r*.67,.06,STEEL,wheel,axis="X",vertices=12)
            cyl("Hub",(side*(width*.5+.245),y,r+.02),r*.25,.06,TEAM,wheel,axis="X")
            for i in range(12):
                angle=i*math.tau/12
                obj=box("Tread",(side*width*.5,y+math.sin(angle)*r,r+.02+math.cos(angle)*r),(.40,.15,.09),DARK,wheel,.01)
                obj.rotation_euler.x=-angle
        box("Fender",(side*width*.5,0,r*2+.13),(.48,length*.94,.16),ARMOR)


def manipulator(x,y,z,side,parent=None):
    arm=pivot("ToolArmLeft" if side<0 else "ToolArmRight",(x,y,z),parent)
    a=(x,y,z); b=(x+side*.24,y+.45,z-.3); c=(x+side*.14,y+.95,z-.6)
    beam("ToolUpper",a,b,.19,.23,ARMOR,arm); beam("ToolForearm",b,c,.13,.17,STEEL,arm)
    cyl("ToolElbow",b,.16,.25,DARK,arm,axis="X")
    for dx in (-.11,.11): beam("Claw",(c[0]+dx,c[1],c[2]),(c[0]+dx,c[1]+.26,c[2]-.14),.05,.07,DARK,arm)


def legs(height=2.1,spread=1.6):
    for side in (-1,1):
        for front in (-1,1):
            leg=pivot(("LegLeft" if side<0 else "LegRight")+("Front" if front>0 else "Rear"),(side*.64,front*.58,height))
            hip=(side*.64,front*.58,height); knee=(side*1.04,front*.93,height*.58); foot=(side*spread,front*1.23,.20)
            cyl("HipJoint",hip,.19,.26,DARK,leg,axis="X")
            beam("UpperLeg",hip,knee,.30,.27,ARMOR,leg)
            cyl("KneeJoint",knee,.18,.32,DARK,leg,axis="X")
            beam("LowerLeg",knee,foot,.23,.24,ARMOR,leg)
            beam("LegInset",Vector(knee)+Vector((side*.13,0,-.10)),Vector(foot)+Vector((side*.13,0,.18)),.035,.13,TEAM,leg)
            rod("Actuator",Vector(knee)+Vector((0,-.14,0)),Vector(foot)+Vector((0,-.14,.08)),.047,STEEL,leg)
            box("Foot",(foot[0],foot[1]+.06,.11),(.47,.55,.20),DARK,leg,.04)


def operator():
    begin("VectorOperator")
    for side in (-1,1):
        leg=pivot("LegLeft" if side<0 else "LegRight",(side*.17,0,1.04))
        beam("Thigh",(side*.17,0,.98),(side*.19,.01,.59),.23,.27,ARMOR,leg)
        cyl("Knee",(side*.19,.02,.57),.12,.27,DARK,leg,axis="X")
        beam("Shin",(side*.19,0,.51),(side*.21,.04,.18),.19,.22,ARMOR,leg)
        box("KneePlate",(side*.19,.17,.58),(.21,.08,.23),TEAM,leg,.025)
        box("Boot",(side*.21,.09,.085),(.25,.40,.15),DARK,leg,.025)
    shell("Pelvis",0,0,.97,.52,.33,.22,DARK)
    shell("Vest",0,0,1.17,.72,.43,.49,ARMOR)
    box("ChestInset",(0,.22,1.44),(.32,.035,.24),TEAM)
    box("Backpack",(0,-.29,1.40),(.43,.20,.38),DARK)
    for side in (-1,1):
        box("Shoulder",(side*.40,0,1.58),(.23,.33,.26),ARMOR,bevel=.07)
        box("ShoulderID",(side*.525,0,1.59),(.025,.22,.17),TEAM,bevel=.005)
        beam("UpperArm",(side*.40,0,1.49),(side*.41,.18,1.23),.17,.18,DARK)
        beam("Forearm",(side*.41,.18,1.23),(side*.14,.43,1.26),.18,.18,ARMOR)
        box("Glove",(side*.14,.43,1.26),(.15,.15,.15),DARK)
    cyl("Neck",(0,0,1.74),.11,.17,DARK)
    shell("Helmet",0,0,1.76,.44,.41,.34,ARMOR)
    lens(0,.18,1.96,.31)
    box("Rifle",(.11,.46,1.36),(.15,.52,.17),DARK)
    cyl("RifleBarrel",(.11,.91,1.38),.033,.47,STEEL,axis="Y",vertices=8)
    pivot("Muzzle",(.11,1.16,1.38)); antenna(-.25,-.25,1.57)


def mule():
    begin("MuleEngineer"); wheels(2.2,2.8,.46)
    shell("Chassis",0,0,.62,2.15,3.0,.48,DARK)
    shell("Cab",0,.65,1.0,1.7,1.45,.57)
    for side in (-1,1):
        shell("ShoulderPanel",side*.84,.43,1.17,.5,1.40,.27,TEAM)
        manipulator(side*.59,1.15,1.13,side)
    lens(0,1.29,1.37,.66)
    box("CargoTray",(0,-.82,1.12),(1.68,1.20,.18),STEEL)
    for x in (-.42,.42):
        box("CargoModule",(x,-.85,1.48),(.67,1.03,.57),DARK,bevel=.07)
        for y in (-1.18,-.53):box("CargoBand",(x,y,1.78),(.7,.10,.04),TEAM)
    antenna(-.74,-1.13,1.38)


def needle():
    begin("NeedleSkimmer")
    for side in (-1,1):
        for y in (-1.15,1.2):
            cyl("LiftDuct",(side*1.06,y,.33),.53,.40,DARK,vertices=20)
            ring("LiftBand",(side*1.06,y,.18),.47,.035,GLASS)
        shell("Pontoon",side*1.02,.05,.52,1.25,4.35,.69)
        shell("PontoonID",side*1.02,-.08,1.21,.77,2.75,.035,TEAM)
        lens(side*1.02,1.96,.81,.43)
        vent(side*1.02,-1.25,1.20,.56,.46)
    shell("BridgeHull",0,-.43,.78,1.26,2.9,.41,DARK)
    cyl("TurretBearing",(0,-.38,1.28),.65,.16,STEEL,vertices=24)
    turret=pivot("TurretPivot",(0,-.38,1.39))
    shell("Turret",0,-.34,1.35,1.39,1.55,.51,ARMOR,turret)
    box("TurretID",(0,-.44,1.89),(.49,.67,.035),TEAM,turret)
    gun(1.66,2.05,turret); lens(.43,.26,1.72,.16,turret); antenna(-.45,-.83,1.86,turret)


def walker(repair=False):
    begin("MenderRobot" if repair else "LancerWalker")
    h=1.22 if repair else 2.0
    legs(h,1.32 if repair else 1.56)
    shell("Body",0,0,h-.12,1.64,1.74,.62)
    for side in (-1,1):box("SideID",(side*.79,-.07,h+.24),(.035,.70,.26),TEAM)
    lens(0,.76,h+.27,.68)
    vent(0,-.34,h+.52)
    if repair:
        for side in (-1,1):manipulator(side*.74,.63,h+.18,side)
        box("ServiceChevronA",(-.11,.87,h+.03),(.08,.03,.17),TEAM,rot=(0,-.5,0))
        box("ServiceChevronB",(.11,.87,h+.03),(.08,.03,.17),TEAM,rot=(0,.5,0))
    else:
        turret=pivot("TurretPivot",(0,-.14,h+.66))
        shell("GunPod",0,-.09,h+.58,1.28,1.59,.50,ARMOR,turret)
        gun(h+.85,1.65,turret); antenna(-.48,-.7,h+1.07,turret)


def kite():
    begin("KiteScout")
    prism("TriangleFrame",[(-1.55,-1.12),(1.55,-1.12),(0,2.05)],.42,.18,DARK)
    for index,(x,y) in enumerate(((0,1.02),(-1.0,-.68),(1.0,-.68))):
        ring("DuctShell",(x,y,.60),.61,.13,ARMOR)
        ring("DuctLip",(x,y,.65),.50,.025,STEEL)
        fan=pivot("Rotor%d"%index,(x,y,.55))
        cyl("FanHub",(x,y,.57),.12,.12,TEAM,fan)
        for angle in (0,math.pi/3,math.pi*2/3):
            box("FanBlade",(x,y,.54),(1.04,.095,.035),DARK,fan,.005,rot=(0,0,angle))
    prism("Spine",[(-.32,-1.02),(.32,-1.02),(.24,.52),(0,1.99),(-.24,.52)],.68,.12,ARMOR)
    prism("SpineID",[(-.22,-.83),(.22,-.83),(.14,.16),(-.14,.16)],.82,.025,TEAM)
    lens(0,1.90,.61,.22)
    for side in (-1,1):rod("LandingFoot",(side*.57,-.53,.48),(side*.57,-.53,.05),.045,STEEL)


def wraith():
    begin("WraithStriker")
    shell("Fuselage",0,.10,.45,1.2,4.55,.43)
    for side in (-1,1):
        pts=[(side*.39,1.34),(side*3.35,-.89),(side*3.47,-1.49),(side*1.49,-1.20),(side*.50,-1.66)]
        prism("SweptWing",pts,.51,.17,ARMOR)
        prism("WingID",[(side*.93,.63),(side*2.97,-.96),(side*1.65,-.86)],.705,.022,TEAM)
        cyl("Engine",(side*.68,-.86,.67),.31,1.78,DARK,axis="Y",vertices=16)
        cyl("Exhaust",(side*.68,-1.80,.67),.245,.10,STEEL,axis="Y")
        cyl("ExhaustCore",(side*.68,-1.86,.67),.16,.02,GLASS,axis="Y")
        shell("EngineCowl",side*.66,-.3,.61,.76,1.42,.39)
        shape("TailFin",[(side*.75,-.53,.8),(side*1.22,-1.0,1.78),(side*1.45,-1.55,1.65),(side*1.03,-1.48,.77)],[(0,1,2,3)],TEAM,bevel=0)
        for dx in (-.15,.15):
            cyl("Missile",(side*1.44+dx,-.36,.32),.11,.98,DARK,axis="Y")
            cyl("MissileTip",(side*1.44+dx,.16,.32),.09,.08,ORANGE,axis="Y")
    prism("Canopy",[(-.31,.21),(.31,.21),(.18,1.31),(0,1.61),(-.18,1.31)],.91,.06,TEAM)
    lens(0,2.06,.56,.27); pivot("Muzzle",(0,2.2,.53))


def prism_artillery():
    begin("PrismArtillery"); wheels(2.4,3.6,.52)
    shell("Chassis",0,0,.72,2.50,3.93,.51)
    for side in (-1,1):
        shell("SidePod",side*.99,-.44,1.23,.63,2.16,.40,TEAM)
        for front in (-1,1):
            arm=pivot("Stabilizer_%d_%d"%(side,front),(side*1.05,front*1.3,1.15))
            beam("Stabilizer",(side*1.05,front*1.3,1.15),(side*1.80,front*1.65,.18),.20,.22,ARMOR,arm)
            box("StabilizerFoot",(side*1.80,front*1.65,.11),(.47,.49,.20),DARK,arm)
    cyl("Bearing",(0,-.43,1.39),.72,.23,DARK,vertices=20)
    turret=pivot("TurretPivot",(0,-.43,1.53))
    shell("AcceleratorHousing",0,-.43,1.47,1.44,1.47,.66,ARMOR,turret)
    barrel=gun(1.88,parent=turret,rail=True)
    barrel.rotation_euler.x=math.radians(14)
    lens(0,1.76,1.13,.60); antenna(-.91,-1.23,1.60)


def foundation(name,w=5,l=5):
    begin(name)
    shell("Foundation",0,0,.02,w,l,.22,CONCRETE)
    shell("Deck",0,0,.24,w*.94,l*.94,.12,DARK)
    for side in (-1,1): box("Guide",(side*w*.35,.2,.375),(.06,l*.61,.025),TEAM,bevel=0)


def hexblock(name,x,y,z,r,h,material=ARMOR,parent=None):
    pts=[(x+math.cos(i*math.tau/6+math.pi/6)*r,y+math.sin(i*math.tau/6+math.pi/6)*r) for i in range(6)]
    return prism(name,pts,z,h,material,parent,.85)


def pylon(x,y,z,h=4):
    # Swept, tapering ceramic buttress: width and offset change along height.
    shape("SweptPylon",[(x-.42,y-.42,z),(x+.42,y-.42,z),(x+.42,y+.42,z),(x-.42,y+.42,z),
          (x-.15,y-.63,z+h),(x+.15,y-.63,z+h),(x+.15,y-.21,z+h),(x-.15,y-.21,z+h)],
          [(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)],ARMOR)
    beam("PylonID",(x,y+.43,z+.5),(x,y-.18,z+h-.35),.21,.045,TEAM)
    antenna(x,y-.42,z+h)


def door(x,y,z,w=1,h=1.4):
    box("EntryFrame",(x,y-.16,z+h/2),(w+.22,.35,h+.12),ARMOR,bevel=.04)
    box("Door",(x,y,z+h/2),(w,.04,h),DARK,bevel=.01)
    box("DoorLight",(x,y+.025,z+h*.91),(w*.71,.025,.075),GLASS,bevel=.005)
    for step in range(3):box("EntryStep",(x,y+.21+step*.17,.39-step*.06),(w+.15,.24,.12),CONCRETE,bevel=.015)


def nexus():
    foundation("NexusHQ",6.4,5.8)
    hexblock("CommandShell",0,-.2,.36,2.16,1.85)
    hexblock("UpperLevel",0,-.4,2.12,1.34,.92,DARK)
    hexblock("Crown",0,-.4,3.03,1.48,.26)
    for x in (-.68,0,.68): box("Window",(x,.67,2.60),(.48,.05,.48),GLASS,bevel=.01)
    for side in (-1,1):
        shell("SideOffice",side*2.06,.52,.35,1.23,2.45,.96)
        box("OfficeID",(side*2.06,.52,1.34),(.52,1.2,.04),TEAM)
        pylon(side*2.05,-1.44,.35,4.7)
    door(0,2.04,.36,1.05,1.43); antenna(0,-.4,3.31)
    box("CommandID",(0,1.6,1.94),(.73,.06,.24),TEAM)


def operator_hub():
    foundation("OperatorHub",5.8,4.2)
    for side in (-1,1):
        shell("HabitatWing",side*1.63,0,.36,2.02,3.62,1.54)
        box("WindowBand",(side*1.63,1.55,1.37),(1.26,.035,.25),TEAM)
        vent(side*1.63,-.40,1.93,1.1,1.7)
        antenna(side*1.63,-1.1,1.93)
    box("Bridge",(0,-.60,1.77),(2.09,.71,.35),DARK)
    box("BridgeLight",(0,-.235,1.8),(1.49,.03,.10),GLASS)
    shell("Entrance",0,.6,.36,1.22,1.75,.9)
    door(0,1.49,.36,.77,.76)


def foundry():
    foundation("RoboticsFoundry",6.5,5.8)
    for side in (-1,1):
        pylon(side*2.43,-.47,.36,4.95)
        shell("ServiceCabinet",side*2.36,1.40,.36,1.13,1.66,1.04)
        vent(side*2.36,1.45,1.43,.6,.8)
        beam("UpperGantry",(side*2.2,-1.18,4.34),(side*.18,-1.18,4.34),.36,.43,DARK)
        manipulator(side*.84,-1.06,4.18,side)
    box("BackBrace",(0,-2.1,2.58),(4.3,.35,.30),STEEL)
    box("HeaderLight",(0,-.91,4.33),(3.1,.06,.09),GLASS)
    for y in (-1.1,-.65,-.2,.25,.7):box("ConveyorSlat",(0,y,.43),(2.9,.12,.10),STEEL,bevel=.01)


def flightdeck():
    foundation("FlightDeck",7.1,6.7)
    hexblock("LandingPad",0,.3,.34,2.85,.23,DARK)
    ring("LandingRing",(0,.3,.59),2.04,.035,TEAM)
    for x in (-.4,.4):box("LandingMark",(x,.3,.59),(.10,1.22,.02),ARMOR,bevel=0)
    box("LandingCrossbar",(0,.3,.59),(.90,.10,.02),ARMOR,bevel=0)
    for side in (-1,1):pylon(side*2.68,-1.68,.36,2.63)
    hexblock("ControlTower",0,-2.26,.36,.72,1.38)
    hexblock("ControlGlass",0,-2.26,1.74,.83,.48,TEAM)
    hexblock("ControlRoof",0,-2.26,2.22,.95,.18)
    antenna(0,-2.26,2.41)


def flux():
    foundation("FluxGenerator",4.8,4.6)
    for x,y,h in ((-1.15,.30,2.9),(1.15,.30,2.9),(0,-1.08,3.55)):
        cyl("CoreFoot",(x,y,.52),.61,.29,DARK,vertices=16)
        cyl("PowerCore",(x,y,1.00+h*.33),.41,h*.65,GLASS,vertices=16)
        for z in (.75,h+.36):
            cyl("CoreCollar",(x,y,z),.57,.37,ARMOR,vertices=12)
        for side in (-1,1):beam("CoreFrame",(x+side*.50,y,.7),(x+side*.50,y,h+.36),.15,.23,ARMOR)
        cyl("CoreCap",(x,y,h+.63),.43,.14,DARK,vertices=16)
        beam("CoreBrace",(x,y,h*.8),(x*1.45,y*1.45,.42),.12,.16,STEEL)
    shell("ControlBox",0,1.18,.36,1.08,1.14,.86)
    lens(0,1.67,.91,.41)


def signal_lab():
    foundation("SignalLab",5.7,5.3)
    hexblock("ServerBlock",0,.06,.36,1.89,1.47)
    hexblock("ServerCap",0,.06,1.83,1.67,.22,DARK)
    door(0,1.96,.36,.92,1.13)
    for side in (-1,1):pylon(side*2.08,-.59,.36,2.8)
    radar=pivot("SensorPivot",(0,-.2,2.13))
    ring("SensorRing",(0,-.2,3.2),1.30,.105,ARMOR,radar,(math.radians(-38),0,0))
    ring("SignalTrace",(0,-.2,3.2),1.18,.025,GLASS,radar,(math.radians(-38),0,0))
    center=Vector((0,-.2,3.2))
    for angle in (0,math.tau/3,math.tau*2/3):
        offset=Vector((math.cos(angle)*1.25,math.sin(angle)*1.25*math.cos(math.radians(38)),-math.sin(angle)*1.25*math.sin(math.radians(38))))
        rod("SensorSpoke",center,center+offset,.047,STEEL,radar)
    cyl("SensorHub",center,.20,.30,TEAM,radar)
    beam("DishSupport",(0,-.2,1.98),center,.21,.24,STEEL)


def service():
    foundation("ServiceCradle",5.8,5.4)
    for side in (-1,1):
        pylon(side*2.22,-.50,.36,2.95)
        arm=pivot("RepairArmLeft" if side<0 else "RepairArmRight",(side*2.2,-.3,3.12))
        beam("ServiceUpper",(side*2.2,-.3,3.12),(side*1.21,.1,2.5),.30,.33,ARMOR,arm)
        beam("ServiceForearm",(side*1.21,.1,2.5),(side*.64,.56,1.55),.17,.21,STEEL,arm)
        cyl("ServiceElbow",(side*1.21,.1,2.5),.25,.36,DARK,arm,axis="X")
        for dx in (-.13,.13):rod("Tool",(side*.64+dx,.56,1.55),(side*.64+dx,.68,1.15),.045,DARK,arm)
        shell("ToolCabinet",side*2.11,1.3,.36,.75,1.18,.65,TEAM)
    for y in (-1.7,1.7):box("EntryGuide",(0,y,.40),(3.55,.11,.04),ARMOR,bevel=0)


def lance():
    foundation("LanceSentry",3.9,3.9)
    cyl("CentralPillar",(0,0,.89),.65,1.12,DARK,vertices=12)
    for angle in (math.pi/2,math.pi*7/6,math.pi*11/6):
        foot=Vector((math.cos(angle)*1.63,math.sin(angle)*1.63,.42))
        beam("Outrigger",(math.cos(angle)*.48,math.sin(angle)*.48,1.23),foot,.34,.38,ARMOR)
        box("OutriggerFoot",foot,(.51,.51,.12),DARK)
    cyl("TurretRing",(0,0,1.48),.69,.20,STEEL,vertices=20)
    turret=pivot("TurretPivot",(0,0,1.61))
    shell("SentryHead",0,0,1.59,1.38,1.61,.56,ARMOR,turret)
    box("SideMark",(.67,0,1.91),(.04,.57,.26),TEAM,turret)
    gun(1.91,1.21,turret); lens(-.43,.63,1.96,.19,turret)


def skyward():
    foundation("SkywardArray",4.5,4.1)
    hexblock("Base",0,0,.36,1.63,.62)
    cyl("Bearing",(0,0,1.04),.84,.17,DARK,vertices=20)
    turret=pivot("TurretPivot",(0,0,1.18))
    for side in (-1,1):
        pod=pivot("MissilePodLeft" if side<0 else "MissilePodRight",(side*1.04,0,1.67),turret)
        box("Launcher",(side*1.04,0,1.67),(.87,1.5,.78),ARMOR,pod,.07)
        box("PodID",(side*1.50,0,1.67),(.035,.85,.46),TEAM,pod)
        for x in (-.23,0,.23):
            for z in (-.20,.20):
                cyl("Tube",(side*1.04+x,.76,1.67+z),.093,.06,DARK,pod,axis="Y")
                cyl("MissileNose",(side*1.04+x,.81,1.67+z),.060,.06,ORANGE,pod,axis="Y")
        pod.rotation_euler.x=math.radians(29)
    rod("RadarMast",(0,-.30,1.13),(0,-.30,2.18),.10,STEEL,turret)
    shell("Radar",0,-.27,1.97,1.08,.21,.90,TEAM,turret)
    pivot("Muzzle",(1.04,.79,2.06),turret)


operator(); mule(); needle(); walker(); walker(True); kite(); wraith(); prism_artillery()
nexus(); operator_hub(); foundry(); flightdeck(); flux(); signal_lab(); service(); lance(); skyward()

# Export evaluated copies, joining objects that share a rigid parent.
manifest=[]
for name,collection,asset_root in assets:
    bpy.context.view_layer.update()
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
        modifier=joined.modifiers.new("Triangulate","TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bm=bmesh.new(); bm.from_mesh(joined.data)
        bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.calc_area()<1e-10],context="FACES_ONLY")
        bm.to_mesh(joined.data); bm.free()
    live=[obj for obj in scene.collection.objects if obj.name.startswith("export_")]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in live: obj.select_set(True)
    triangles=sum(len(obj.data.polygons) for obj in live if obj.type=="MESH")
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")),export_format="GLB",use_selection=True,
        export_animations=False,export_yup=True,export_cameras=False,export_lights=False)
    for obj in live: bpy.data.objects.remove(obj,do_unlink=True)
    manifest.append({"name":name,"triangles":triangles,"file":name+".glb"})
    collection.hide_render=True

# Render actual geometry for roster icons.
world=bpy.data.worlds.new("Helix studio"); scene.world=world; world.use_nodes=True
world.node_tree.nodes["Background"].inputs[0].default_value=(.22,.27,.34,1)
world.node_tree.nodes["Background"].inputs[1].default_value=.45
for name,loc,power,color in (("Key",(4,6,11),1800,(1,.88,.72)),("Fill",(-6,1,6),1500,(.7,.83,1)),("Rim",(3,-6,8),2100,(1,.92,.78))):
    data=bpy.data.lights.new(name,"AREA"); data.energy=power; data.shape="DISK"; data.size=7; data.color=color
    obj=bpy.data.objects.new(name,data); scene.collection.objects.link(obj); obj.location=loc
    obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat("-Z","Y").to_euler()
camera_data=bpy.data.cameras.new("Camera"); camera=bpy.data.objects.new("Camera",camera_data)
scene.collection.objects.link(camera); scene.camera=camera; camera_data.type="ORTHO"
scene.render.engine="CYCLES"; scene.cycles.samples=24; scene.cycles.use_denoising=True
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
    scene.render.resolution_x=768; scene.render.resolution_y=768
    scene.render.film_transparent=False
    scene.render.filepath=str(SOURCE/(name+".png")); bpy.ops.render.render(write_still=True)
    scene.render.resolution_x=256; scene.render.resolution_y=256
    scene.render.film_transparent=True
    collection.hide_render=True
    manifest[next(i for i,item in enumerate(manifest) if item["name"]==name)]["bounds"]={"min":list(lo),"max":list(hi)}

# Catalogue display transforms normalize each subject for readable review.
# Exported models above retain their native metre scale and upright orientation.
for i,(name,collection,asset_root) in enumerate(assets):
    collection.hide_render=False
    bounds=manifest[i]["bounds"]
    factor=5.8/max(b-a for a,b in zip(bounds["min"],bounds["max"]))
    asset_root.scale=Vector((factor,)*3)
    asset_root.rotation_euler=(math.radians(55),0,math.radians(145))
    bpy.context.view_layer.update()
    points=[obj.matrix_world@Vector(p) for obj in collection.objects if obj.type=="MESH" for p in obj.bound_box]
    center=Vector([(min(p[k] for p in points)+max(p[k] for p in points))/2 for k in range(3)])
    cell=Vector(((i%4-1.5)*10,(2-i//4)*10,0))
    asset_root.location=cell-Vector((center.x,center.y,0))
    asset_root["review_display_scale"]=factor
    asset_root["source_note"]="Reset root location, rotation and scale for upright metre-scale editing. GLB already uses native coordinates."
    import re
    text_data=bpy.data.curves.new(name+"_Label","FONT")
    text_data.body=re.sub(r"(?<=[a-z])(?=[A-Z])", " ", name)
    text_data.align_x="CENTER"; text_data.size=.49
    label=bpy.data.objects.new(name+"_Label",text_data); scene.collection.objects.link(label)
    label.location=cell+Vector((0,-3.9,3))
    label_material=mat(name+"_LabelInk",(.85,.9,.95),0,1,1)
    text_data.materials.append(label_material)
for obj in scene.objects:
    if obj.type=="LIGHT":
        obj.location*=6; obj.data.energy*=30; obj.data.size=35
        obj.rotation_euler=(-obj.location).to_track_quat("-Z","Y").to_euler()
camera.location=(0,0,85); camera.rotation_euler=(0,0,0)
camera_data.ortho_scale=52
scene.render.film_transparent=False
scene.render.resolution_x=1900; scene.render.resolution_y=2200
scene.cycles.samples=32
scene.render.filepath=str(SOURCE/"faction-catalogue.png")
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"helix_faction.blend"))
bpy.ops.render.render(write_still=True)
(SOURCE/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("Helix assets complete:",len(manifest))
