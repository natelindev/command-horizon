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


ARMOR = mat("Frontier_Ceramic", (.27,.32,.18), .15,.42)
PANEL = mat("Frontier_Secondary", (.52,.42,.28), .25,.48)
DARK = mat("Frontier_Graphite", (.025,.043,.050), .6,.4)
STEEL = mat("Frontier_Titanium", (.22,.28,.30), .75,.35)
TEAM = mat("TeamColor_Frontier", (.72,.22,.055), .25,.42)
RUBBER = mat("Frontier_Rubber", (.012,.019,.021), 0,.88)
GLASS = mat("Frontier_Optics", (.62,.80,.56), .25,.22,1.2)
WHITE = mat("Frontier_Canvas", (.70,.65,.48), 0,.86)
ORANGE = mat("Frontier_Warning", (.95,.23,.025), .1,.5)
CONCRETE = mat("Frontier_Foundation", (.20,.245,.26), 0,.85)
assets = []
current = None
root = None


def begin(name):
    global current, root
    current = bpy.data.collections.new(name)
    scene.collection.children.link(current)
    root = bpy.data.objects.new(name,None)
    current.objects.link(root)
    root["faction"] = "Free Frontier Coalition"
    root["forward"] = "-Z in Godot"
    assets.append((name,current,root))
    print("Building", name, flush=True)
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
    mast = pivot("AntennaPivot",(x,y,z),parent) if current.name in {"ScrapperRig", "Outrider", "Ironback", "JackalRig"} else parent
    rod("Antenna",(x,y,z),(x,y,z+.72),.018,STEEL,mast)


def warning(x,y,z,parent=None):
    box("Warning",(x,y,z),(.15,.035,.12),ORANGE,parent,.005)


# Independently authored Frontier subjects; +Y Blender forward becomes -Z in Godot.
def plate(name, xyz, size, parent=None, material=PANEL):
    box(name, xyz, size, material, parent, .018)
    x,y,z=xyz; w,l,h=size
    for side in (-1,1):
        cyl("PlateBolt",(x+side*w*.35,y,z+h/2+.008),.028,.025,STEEL,parent,vertices=6)


def tire(x,y,r,parent=None):
    wheel=pivot("WheelPivot",(x,y,r+.04),parent)
    cyl("Tire",(x,y,r+.04),r,.32,RUBBER,wheel,axis="X",vertices=16)
    side=1 if x>0 else -1
    cyl("Rim",(x+side*.17,y,r+.04),r*.62,.04,STEEL,wheel,axis="X")
    cyl("Hub",(x+side*.21,y,r+.04),r*.25,.07,TEAM,wheel,axis="X")
    for i in range(12):
        a=i*math.tau/12
        box("Tread",(x,y+math.sin(a)*r,r+.04+math.cos(a)*r),(.35,.13,.065),DARK,wheel,.005,rot=(-a,0,0))


def chassis(name, width=2.2,length=3.5,axles=3):
    begin(name)
    for i in range(axles):
        y=(i/(axles-1)-.5)*length*.72
        rod("Axle",(-width/2,y,.47),(width/2,y,.47),.09,STEEL)
        for side in (-1,1): tire(side*width/2,y,.46)
    box("Frame",(0,0,.65),(width*.72,length,.22),DARK)
    wedge("Hull",0,0,.74,width*.91,length,.44,ARMOR)
    for side in (-1,1):
        for y in (-length*.3,length*.3):
            plate("Fender",(side*width*.48,y,1.06),(.45,length*.37,.09))
    box("Bumper",(0,length*.53,.74),(width*.94,.14,.18),STEEL)
    for side in (-1,1): lens(side*width*.3,length*.51,1.04,.19)
    vent(0,-length*.3,1.21,.8,.65)


def cage(x,y,z,w,l,h,parent=None):
    for sx in (-1,1):
        for sy in (-1,1): rod("CagePost",(x+sx*w/2,y+sy*l/2,z),(x+sx*w/2,y+sy*l/2,z+h),.035,STEEL,parent)
        rod("CageRail",(x+sx*w/2,y-l/2,z+h),(x+sx*w/2,y+l/2,z+h),.035,STEEL,parent)
    for sy in (-1,1): rod("CageCross",(x-w/2,y+sy*l/2,z+h),(x+w/2,y+sy*l/2,z+h),.035,STEEL,parent)


def crate(x,y,z,w=.6):
    box("Crate",(x,y,z),(w,w,.5),PANEL)
    for side in (-1,1): box("CrateBand",(x+side*w*.3,y,z+.26),(.05,w,.035),STEEL)


def gun(z,length,parent):
    barrel=pivot("BarrelPivot",(0,.35,z),parent)
    box("Mantlet",(0,.46,z),(.48,.6,.38),PANEL,barrel)
    cyl("Barrel",(0,.8+length/2,z),.075,length,STEEL,barrel,axis="Y")
    cyl("Brake",(0,.84+length,z),.12,.27,DARK,barrel,axis="Y")
    pivot("Muzzle",(0,1+length,z),barrel)


def cab(y=.7):
    wedge("Cab",0,y,1.1,1.42,1.1,.7,ARMOR)
    box("Windscreen",(0,y+.51,1.58),(1.03,.035,.32),DARK)
    box("WindowSplit",(0,y+.54,1.59),(.055,.05,.34),STEEL)
    cage(0,y,1.13,1.48,1.16,.83)
    plate("CabRoof",(0,y,1.98),(1.59,1.29,.08),material=TEAM)


def engineer():
    chassis("ScrapperRig",2.2,3.3); cab(.76)
    box("CargoBed",(0,-.9,1.18),(1.7,1.1,.11),STEEL)
    cage(0,-.9,1.2,1.69,1.15,.6)
    crate(-.37,-.86,1.49); crate(.37,-1.02,1.46,.47)
    arm=pivot("ToolArmRight",(.92,-.12,1.2))
    beam("Crane",(.92,-.12,1.2),(.9,.4,2.65),.18,.2,TEAM,arm)
    beam("Boom",(.9,.4,2.65),(.9,1.82,1.8),.14,.17,STEEL,arm)
    for x in (.78,1.02): rod("Grab",(x,1.82,1.8),(x,2.07,1.5),.045,DARK,arm)
    antenna(-.72,-.33,1.52)


def ranger():
    begin("RidgeRanger")
    for side in (-1,1):
        leg=pivot("LegLeft" if side<0 else "LegRight",(side*.17,0,1))
        beam("Trouser",(side*.17,0,.96),(side*.2,0,.56),.23,.24,PANEL,leg)
        beam("Gaiter",(side*.2,0,.53),(side*.21,.03,.18),.19,.21,ARMOR,leg)
        box("Boot",(side*.21,.08,.085),(.26,.4,.16),DARK,leg)
    box("Belt",(0,0,1.04),(.55,.35,.17),DARK)
    wedge("FieldVest",0,0,1.12,.65,.4,.48,ARMOR)
    for x in (-.19,.02,.21): box("Pouch",(x,.23,1.3),(.15,.12,.21),PANEL)
    box("Pack",(0,-.28,1.42),(.47,.27,.47),PANEL)
    cyl("Bedroll",(0,-.34,1.75),.11,.58,WHITE,axis="X")
    for side in (-1,1):
        beam("Sleeve",(side*.37,0,1.54),(side*.42,.16,1.25),.18,.2,WHITE)
        beam("Arm",(side*.42,.16,1.25),(side*.14,.42,1.28),.15,.17,ARMOR)
        box("Glove",(side*.14,.42,1.28),(.15,.16,.15),DARK)
    cyl("Neck",(0,0,1.73),.1,.14,DARK)
    shell("Helmet",0,0,1.75,.43,.4,.28,ARMOR)
    box("Goggles",(0,.19,1.9),(.31,.05,.095),GLASS)
    box("Scarf",(0,.09,1.76),(.41,.3,.1),WHITE)
    box("Armband",(-.39,.04,1.5),(.21,.25,.13),TEAM)
    box("Carbine",(.1,.48,1.36),(.14,.56,.14),DARK)
    box("WoodStock",(.1,.24,1.34),(.16,.22,.14),PANEL)
    cyl("Barrel",(.1,.92,1.38),.032,.36,STEEL,axis="Y",vertices=8)
    pivot("Muzzle",(.1,1.11,1.38)); antenna(.23,-.3,1.6)


def armor(heavy=False):
    chassis("Ironback" if heavy else "Outrider",2.55 if heavy else 2.2,4 if heavy else 3.4,4 if heavy else 3)
    cyl("Bearing",(0,-.24,1.25),.65,.2,DARK,vertices=20)
    turret=pivot("TurretPivot",(0,-.24,1.39))
    wedge("SalvagedTurret",0,-.24,1.35,1.6,1.64,.58,ARMOR,turret)
    plate("TurretPatch",(-.38,-.36,1.95),(.51,.77,.045),turret,TEAM)
    cage(0,-1.17,1.36,1.52,.47,.4,turret)
    cyl("Hatch",(.38,-.43,1.95),.25,.09,DARK,turret)
    gun(1.65,2.55 if heavy else 1.6,turret)
    if heavy:
        for side in (-1,1):
            for y in (-1.15,-.55,.05,.65): plate("Applique",(side*1.1,y,1.31),(.3,.45,.2))
            box("TurretSlat",(side*.91,-.4,1.66),(.06,1.4,.5),STEEL,turret)
        cyl("SpareTire",(0,-2.04,1.2),.38,.21,RUBBER,axis="Y")
    antenna(-.58,-.8,1.96,turret)


def crawler(repair=False):
    chassis("PatchCrawler" if repair else "JackalRig",1.8,2.5,2)
    if repair:
        box("ToolChest",(0,-.35,1.39),(1.36,1.13,.54),TEAM)
        for y in (-.63,-.3,.03): box("Drawer",(0,y,1.69),(1.12,.035,.025),STEEL)
        arm=pivot("ToolArmLeft",(-.48,.42,1.34))
        beam("RepairArm",(-.48,.42,1.34),(-.4,1.12,2.05),.17,.2,PANEL,arm)
        beam("Welder",(-.4,1.12,2.05),(0,1.59,1.29),.12,.16,STEEL,arm)
        cyl("GasBottle",(.51,.3,1.63),.16,.77,WHITE)
        ring("Hose",(.37,-.49,1.86),.26,.035,DARK,rotation=(math.pi/2,0,0))
    else:
        turret=pivot("TurretPivot",(0,-.15,1.38))
        box("GunShield",(0,.19,1.62),(1.26,.18,.74),ARMOR,turret)
        gun(1.64,1.36,turret)
        box("AmmoBox",(-.57,-.35,1.49),(.43,.55,.35),TEAM,turret)
        for x in (.32,.57): cyl("AATube",(x,-.18,1.97),.1,1.1,DARK,turret,axis="Y")
        antenna(-.56,-.6,1.61,turret)
    lens(0,1.15,1.18,.46)


def rotor(name,x,y,z,r,parent=None):
    p=pivot(name,(x,y,z),parent)
    cyl("Hub",(x,y,z),.1,.18,STEEL,p)
    for a in (0,math.pi/2): box("Blade",(x,y,z+.04),(r*2,.10,.035),DARK,p,.004,rot=(0,0,a))


def scout():
    begin("LookoutDrone")
    box("BatteryBody",(0,0,.52),(.62,.83,.28),PANEL)
    plate("DroneID",(0,0,.69),(.4,.58,.035),material=TEAM)
    for side in (-1,1):
        for front in (-1,1):
            x,y=side*.83,front*.72
            rod("RotorArm",(side*.17,front*.22,.55),(x,y,.55),.045,STEEL)
            ring("RotorGuard",(x,y,.66),.51,.022,ARMOR)
            rotor("Rotor%d" % ((1 if side > 0 else 0)*2 + (1 if front > 0 else 0)),x,y,.65,.44)
        rod("Skid",(side*.35,-.45,.07),(side*.35,.45,.07),.035,STEEL)
        rod("Leg",(side*.25,0,.5),(side*.35,0,.07),.035,STEEL)
    cyl("CameraGimbal",(0,.36,.31),.16,.23,DARK,axis="X")
    lens(0,.46,.29,.17)


def aircraft():
    begin("KestrelGunship")
    shell("Fuselage",0,.1,.57,1.22,3.46,.78,ARMOR)
    shell("Canopy",0,1.05,1.05,1.03,1.27,.34,DARK)
    plate("RoofPatch",(0,-.29,1.4),(.78,.71,.06),material=TEAM)
    beam("TailBoom",(0,-1.15,1.06),(0,-3.6,1.38),.22,.22,STEEL)
    shape("TailFin",[(-.07,-3.7,1.25),(-.07,-3.55,2.29),(-.07,-3.04,1.33),(.07,-3.7,1.25),(.07,-3.55,2.29),(.07,-3.04,1.33)],[(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)],TEAM)
    rotor("Rotor0",0,-.25,1.91,2.72)
    for side in (-1,1):
        beam("Wing",(0,-.11,.91),(side*1.42,-.18,.84),.36,.16,ARMOR)
        cyl("RocketPod",(side*1.24,-.11,.66),.25,1.05,DARK,axis="Y")
        for dx in (-.09,.09): cyl("RocketNose",(side*1.24+dx,.44,.66),.06,.04,ORANGE,axis="Y")
        rod("Skid",(side*.79,-1.3,.15),(side*.79,1.4,.15),.055,STEEL)
        for y in (-.69,.73): rod("SkidStrut",(side*.4,y,.73),(side*.79,y,.15),.045,STEEL)
    lens(0,1.7,.87,.34); pivot("Muzzle",(0,1.83,.67))


def foundation(name,w,l):
    begin(name)
    box("GravelPad",(0,0,.08),(w,l,.16),CONCRETE,bevel=.07)
    for side in (-1,1): box("PadEdge",(side*w*.47,0,.18),(.1,l*.95,.12),STEEL)


def container(x,y,w=1.6,l=3,h=1.55,material=ARMOR):
    box("Container",(x,y,.22+h/2),(w,l,h),material)
    for side in (-1,1):
        for i in range(7): box("Corrugation",(x+side*(w/2+.018),y+(i-3)*l/7,.22+h/2),(.055,.07,h*.88),STEEL,bevel=.005)
        box("CornerPost",(x+side*w*.47,y+l*.48,.22+h/2),(.1,.1,h),STEEL)
    box("Door",(x,y+l/2+.028,.22+h*.4),(w*.68,.055,h*.75),DARK)
    box("IDPlate",(x,y+l/2+.062,.22+h*.8),(w*.65,.025,.16),TEAM)
    vent(x,y,.24+h,w*.62,l*.38)


def canopy(x,y,z,w,l,h=.6):
    for side in (-1,1):
        for sy in (-1,1): rod("CanopyPole",(x+side*w/2,y+sy*l/2,.2),(x+side*w/2,y+sy*l/2,z),.045,STEEL)
    shape("Canvas",[(x-w/2,y-l/2,z),(x,y-l/2,z+h),(x+w/2,y-l/2,z),(x-w/2,y+l/2,z),(x,y+l/2,z+h),(x+w/2,y+l/2,z)],[(0,1,4,3),(1,2,5,4)],WHITE,bevel=0)
    for sy in (-1,1):
        rod("RoofBrace",(x-w/2,y+sy*l/2,z),(x,y+sy*l/2,z+h),.028,STEEL)
        rod("RoofBrace",(x,y+sy*l/2,z+h),(x+w/2,y+sy*l/2,z),.028,STEEL)


def mast(x,y,z=0,h=3):
    for side in (-1,1): beam("MastLeg",(x+side*.32,y,z+.2),(x,y,z+h),.09,.09,STEEL)
    for i in range(5): rod("MastRung",(x-.22,y,z+.4+i*h/6),(x+.22,y,z+.4+i*h/6),.025,STEEL)
    antenna(x,y,z+h)


def command():
    foundation("ConvoyHQ",6.3,5.6)
    container(-1.6,-.55,1.9,3.9,1.82)
    container(1.31,-1.15,2.65,2.2,2.5,PANEL)
    for x in (.5,1.3,2.1): box("CommandWindow",(x,-.02,2.07),(.55,.035,.37),DARK)
    canopy(.28,1.25,2.0,2.8,2.25,.43)
    mast(-2.46,-2.1,.2,4.05)
    box("Radio",(-2.34,-1.8,1.43),(.52,.38,.67),TEAM)
    for x in (-.63,.21,1.07): crate(x,1.54,.52)


def barracks():
    foundation("RangerCamp",5.8,4.5)
    for x in (-1.47,1.47):
        canopy(x,-.25,1.55,2.33,3.7,.76)
        box("TentEnd",(x,-2.06,.88),(2.2,.045,1.35),WHITE)
        box("TentFlap",(x,1.58,.91),(1.04,.035,1.45),DARK)
        box("CampID",(x,1.63,1.5),(.59,.025,.19),TEAM)
    crate(-2.12,1.92,.48,.53); crate(2.12,1.92,.48,.53)
    antenna(0,-1.25,.45)


def garage(repair=False):
    foundation("FieldWorkshop" if repair else "MotorPool",6.3,5.6)
    container(-2.18,-.55,1.28,3.9,1.7,PANEL)
    if not repair: container(2.18,-1,1.28,3,1.45)
    for side in (-1,1):
        beam("GantryPost",(side*1.57,-.77,.22),(side*1.57,-.77,3.72),.18,.22,STEEL)
        box("Rail",(side*1.2,.28,.25),(.16,4.35,.075),STEEL)
    box("Gantry",(0,-.77,3.72),(3.46,.39,.38),TEAM)
    cyl("Winch",(.44,-.77,3.41),.23,.51,DARK,axis="X")
    rod("Cable",(.44,-.77,3.27),(.44,-.77,2.24),.018,DARK)
    ring("Hook",(.44,-.77,2.13),.12,.028,STEEL,rotation=(math.pi/2,0,0))
    if repair:
        arm=pivot("RepairArmRight",(2.05,.26,.73))
        beam("ServiceArm",(2.05,.26,.73),(1.77,.27,2.51),.18,.2,TEAM,arm)
        beam("ServiceTool",(1.77,.27,2.51),(.63,.82,1.19),.12,.16,STEEL,arm)
        for y in (-1.6,-.9): cyl("GasBottle",(2.16,y,.96),.22,1.37,WHITE)
    else: canopy(0,-.73,3.85,4.92,2.32,.36)
    crate(-2.13,1.89,.48)


def airfield():
    foundation("RotorPad",7,6.5)
    box("LandingPlate",(0,.47,.21),(4.97,4.61,.09),DARK)
    for x in (-.62,.62): box("LandingH",(x,.47,.27),(.19,2.32,.025),WHITE,bevel=0)
    box("LandingH",(0,.47,.27),(1.24,.19,.025),WHITE,bevel=0)
    for x in (-2.39,2.39):
        for y in (-1.74,2.68): cyl("PadLight",(x,y,.29),.075,.07,GLASS)
    container(-2.39,-2.45,1.24,1.08,1.68)
    for x in (.21,1.01,1.81): cyl("FuelTank",(x,-2.47,.69),.35,.89,PANEL)
    mast(2.84,-2.43,.2,2.65)


def power():
    foundation("DieselArray",4.3,4.1)
    for x in (-.94,.94):
        box("Engine",(x,0,.89),(1.42,2.56,1.19),ARMOR)
        vent(x,.22,1.51,1.08,1.28)
        cyl("Exhaust",(x,-.99,2.07),.10,1.26,DARK)
        box("AccessPanel",(x,1.31,.94),(.78,.045,.7),TEAM)
    cyl("DayTank",(0,-1.59,.8),.38,2.45,PANEL,axis="X")
    rod("FuelLine",(-1.18,-1.31,.44),(1.18,-1.31,.44),.055,STEEL)


def signals():
    foundation("RelayWorkshop",5.5,4.5)
    container(-1.36,-.16,2.14,3.7,1.89,PANEL)
    container(1.45,.67,1.6,1.87,1.1)
    mast(1.05,-1.31,.2,3.86)
    dish=pivot("RadarPivot",(1.05,-1.3,3.6))
    ring("DishRim",(1.05,-1.02,3.7),.87,.055,STEEL,dish,rotation=(math.pi/2,0,0))
    for i in range(12):
        a=i*math.tau/12
        rod("DishSpoke",(1.05,-1.31,3.7),(1.05+math.cos(a)*.87,-1.02,3.7+math.sin(a)*.87),.024,TEAM,dish)
    rod("Receiver",(1.05,-1.31,3.7),(1.05,-.46,3.7),.04,STEEL,dish)
    canopy(-1.28,.18,2.33,2.49,2.05,.29)


def sentry(aa=False):
    foundation("WatchtowerAA" if aa else "RoadblockGun",4.3,4.0)
    if aa:
        for side in (-1,1):
            for sy in (-1,1): beam("TowerLeg",(side*1.3,sy*1.2,.2),(side*.77,sy*.72,2.33),.13,.15,STEEL)
            beam("CrossBrace",(side*1.21,-1.12,.43),(side*.81,.76,2.18),.065,.07,TEAM)
        box("Platform",(0,0,2.35),(2.08,1.99,.15),PANEL)
        turret=pivot("TurretPivot",(0,0,2.49))
        box("Mount",(0,0,2.65),(.66,.81,.55),DARK,turret)
        for side in (-1,1):
            box("MissilePod",(side*.67,.13,2.83),(.61,1.29,.57),ARMOR,turret)
            for dx in (-.15,.15):
                for dz in (-.13,.13): cyl("LaunchTube",(side*.67+dx,.80,2.83+dz),.095,.035,DARK,turret,axis="Y")
        antenna(0,-.51,2.94,turret); pivot("Muzzle",(.67,.84,2.83),turret)
    else:
        for side in (-1,1):
            for i in range(4): box("Sandbag",(side*1.61,(i-1.5)*.71,.4),(.53,.64,.35),PANEL,bevel=.12)
        cyl("Pedestal",(0,-.21,.64),.55,.89,DARK)
        turret=pivot("TurretPivot",(0,-.21,1.14))
        box("Shield",(0,.13,1.47),(1.91,.21,.86),ARMOR,turret)
        plate("ShieldID",(-.51,.15,1.93),(.48,.27,.06),turret,TEAM)
        gun(1.46,1.43,turret)
        crate(-.9,-1.34,.51)


motion_only = "--motion-only" in sys.argv
if motion_only:
    engineer(); armor(); crawler(); armor(True)
else:
    engineer(); ranger(); armor(); crawler(True); crawler(); armor(True); scout(); aircraft()
    command(); barracks(); garage(); airfield(); power(); signals(); garage(True); sentry(); sentry(True)

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
        bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.calc_area()<1e-8],context="FACES_ONLY")
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

if motion_only:
    print("Frontier motion rigs exported")
    raise SystemExit(0)

# Render actual geometry for roster icons.
world=bpy.data.worlds.new("Frontier studio"); scene.world=world; world.use_nodes=True
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
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"frontier_faction.blend"))
bpy.ops.render.render(write_still=True)
(SOURCE/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("Frontier assets complete:",len(manifest))
