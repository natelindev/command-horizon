"""Original alpine communications kit, editable Blender Z-up / glTF Y-up.
Playable shelves stay inside existing radius 6.5 m / height 1.15 m blockers.
Tall granite, trees and station buildings are exclusively boundary scenery.
"""
import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/environment/alpine"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
assets = []
collection = None


def material(name, color, metallic=0.0, roughness=0.88):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return mat


GRANITE = [material("Glacial granite " + str(i), color) for i, color in enumerate([
    (.20, .245, .27), (.245, .28, .30), (.28, .31, .32), (.18, .215, .235)])]
SNOW = [material("Settled snow " + str(i), color) for i, color in enumerate([
    (.66, .72, .735), (.53, .615, .65), (.59, .66, .69)])]
CONCRETE = material("Cold cast concrete", (.38, .405, .40))
WHITE = material("Weathered station enamel", (.60, .64, .62), .3)
TEAL = material("Faded communications teal", (.105, .25, .28), .35)
STEEL = material("Galvanized station steel", (.29, .34, .36), .65, .5)
DARK = material("Recesses and glazing", (.04, .075, .09), .3, .4)
ORANGE = material("Faded rescue orange", (.61, .24, .075), .15)
WOOD = material("Winter bark", (.19, .155, .12))
NEEDLES = [material("Alpine needles " + str(i), color) for i, color in enumerate([
    (.07, .15, .145), (.10, .185, .165), (.13, .21, .19)])]
GRASS = material("Winter sedge", (.265, .26, .20))


def begin(name, radius, height):
    global collection
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    assets.append((name, collection, radius, height))


def attach(obj, name, mat, bevel=0):
    obj.name = name
    for group in list(obj.users_collection):
        group.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Worn manufactured edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    return obj


def box(name, point, size, mat, bevel=0, turn=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.z = turn
    return attach(obj, name, mat, bevel)


def cylinder(name, point, radius, height, mat, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=height, location=point)
    return attach(bpy.context.object, name, mat)


def beam(name, a, b, radius, mat):
    a, b = Vector(a), Vector(b)
    obj = cylinder(name, (a+b)/2, radius, (b-a).length, mat, 8)
    obj.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    return obj


def fractured_rock(name, point, size, seed, snow=True):
    """Angular granite with upward snow faces, without a circular layered silhouette."""
    rng = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1, location=point)
    obj = bpy.context.object
    for vertex in obj.data.vertices:
        v = vertex.co
        v.x *= size[0] * (1 + rng.uniform(-.14, .14))
        v.y *= size[1] * (1 + rng.uniform(-.14, .14))
        v.z = (v.z + 1) * .5 * size[2]
        v.x += v.z * .13
        v.y += v.z * .05
    obj.rotation_euler.z = rng.uniform(-.8, .8)
    for group in list(obj.users_collection):
        group.objects.unlink(obj)
    collection.objects.link(obj)
    obj.name = name
    for mat in GRANITE + SNOW:
        obj.data.materials.append(mat)
    obj.data.update()
    for poly in obj.data.polygons:
        poly.material_index = rng.randrange(len(GRANITE))
        patch = math.sin(poly.center.x*.85 + seed*.1) + math.cos(poly.center.y*.9)
        if snow and poly.normal.z > .40 and poly.center.z > size[2] * .42 and patch > .12:
            poly.material_index = len(GRANITE) + rng.randrange(len(SNOW))
    return obj


def snow_drift(name, point, size):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1, location=point)
    obj = bpy.context.object
    for v in obj.data.vertices:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z = max(0, v.co.z) * size[2]
    for face in obj.data.polygons:
        face.use_smooth = True
    return attach(obj, name, SNOW[1])


for index in range(4):
    begin("GlacialShelf" + "ABCD"[index], 6.5, 1.15)
    fractured_rock("Exposed glacial bedrock", (0, 0, .012), (5.35, 4.15, .76), 101 + index*31)
    for part, (x,y,rx,ry,h) in enumerate([
        (-2.3,.8,2.0,1.4,.98), (1.4,1.8,2.5,1.5,1.08),
        (2.4,-1.8,1.8,1.4,.67), (-1.7,-2.7,2.1,1.35,.48)]):
        fractured_rock("Fractured frost slab", (x,y,.012), (rx,ry,h), 500+index*17+part)
    rng = random.Random(980+index)
    for part in range(11):
        angle = part * math.tau / 11
        distance = 5.2 + rng.uniform(-.3,.2)
        fractured_rock("Glacial scree", (distance*math.cos(angle), distance*math.sin(angle), .006),
                       (.32,.24,.18), 1200+index*23+part)
    if index == 1:
        box("Collapsed survey footing", (0,-.25,.81), (2.3,1.4,.14), CONCRETE, .05, .1)
        for x in [-.85,.85]:
            cylinder("Cut survey bolt", (x,-.2,.99), .065,.14,STEEL)
        box("Broken station marker", (0,-.22,.92), (.75,.08,.22),TEAL,.015,.1)
    if index == 3:
        beam("Buried communications conduit", (-2,-.4,.87),(2.5,-.4,.87),.08,STEEL)
        for x in [-1.6,-.6,.4,1.4]:
            box("Conduit bracket", (x,-.4,.82), (.16,.36,.18),TEAL,.025)

def mountain_spire(name, point, radius, height, seed, stretch=(1,1)):
    rng=random.Random(seed)
    count=26
    phase=rng.random()*math.tau
    shape=[.79+.11*math.sin(i*.91+phase)+rng.uniform(-.065,.065) for i in range(count)]
    rings=[(0,1.0),(.16,.87),(.38,.68),(.61,.43),(.83,.20)]
    vertices=[]
    for level,(z,scale) in enumerate(rings):
        for i in range(count):
            angle=i*math.tau/count
            r=radius*shape[i]*scale
            x=point[0]+math.cos(angle)*r*stretch[0] + height*z*.15
            y=point[1]+math.sin(angle)*r*stretch[1] - height*z*.10
            crest=height*z + (rng.uniform(-.045,.045)*height if level else 0)
            vertices.append((x,y,point[2]+max(0,crest)))
    vertices.append((point[0]+height*.15,point[1]-height*.1,point[2]+height))
    faces=[]
    for level in range(len(rings)-1):
        for i in range(count):
            a=level*count+i;b=level*count+(i+1)%count
            faces.extend([(a,b,b+count),(a,b+count,a+count)])
    start=(len(rings)-1)*count
    for i in range(count):faces.append((start+i,start+(i+1)%count,len(vertices)-1))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj)
    for mat in GRANITE+SNOW:mesh.materials.append(mat)
    for face in mesh.polygons:
        face.material_index=(face.index//7+seed)%len(GRANITE)
        lee = face.normal.y < .1 or face.center.z > height*.72
        if face.normal.z>.58 and lee:
            face.material_index=len(GRANITE)+(face.index//13)%len(SNOW)
    return obj


for index in range(2):
    begin("AlpineMassif" + "AB"[index], 13.0, 13.5)
    mountain_spire("Fractured mountain crest",(-1,1,.01),10.4,12.8-index*1.2,2300+index*17,(1,.8))
    mountain_spire("Glacial side peak",(5.1,-2,.01),5.4,7.4+index,2400+index*3,(.85,1.05))
    mountain_spire("Low scree ridge",(-5.4,-3,.01),4.0,4.0,2430+index*3,(1.1,.8))
    for part in range(8):
        angle=part*math.tau/8
        fractured_rock("Mountain scree", (10*math.cos(angle),8*math.sin(angle),.005),
                       (.55,.45,.38), 2560+part+index*13)

begin("SnowPineGrove", 5.4, 8.4)
for tree, (x,y,h) in enumerate([(-2,-.9,6.3),(1.35,.9,8.0),(2.0,-2.2,4.5)]):
    cylinder("Pine trunk", (x,y,h*.46), .115,h*.92,WOOD,9)
    rng=random.Random(2900+tree)
    for level in range(8):
        z=h*(.22+level*.087)
        radius=h*(.21-level*.019)
        count=11
        vertices=[(x,y,z+radius*.82)]
        for tip in range(count):
            angle=tip*math.tau/count + tree*.7 + level*.4
            r=radius*rng.uniform(.77,1.08)
            vertices.append((x+math.cos(angle)*r,y+math.sin(angle)*r,z+rng.uniform(-.11,.09)))
        vertices.append((x,y,z-.12))
        faces=[]
        for tip in range(count):
            a=1+tip;b=1+(tip+1)%count
            faces.extend([(0,a,b),(len(vertices)-1,b,a)])
        mesh=bpy.data.meshes.new("Radial winter branches")
        mesh.from_pydata(vertices,[],faces);mesh.update()
        obj=bpy.data.objects.new("Snow laden pine tier",mesh);collection.objects.link(obj)
        for mat in NEEDLES+SNOW:mesh.materials.append(mat)
        for face in mesh.polygons:
            face.material_index=tree%3
        snow_vertices=[(vertices[0][0],vertices[0][1],vertices[0][2]+.025)]
        for vx,vy,vz in vertices[1:-1]:
            snow_vertices.append((x+(vx-x)*.75,y+(vy-y)*.75,vz+(vertices[0][2]-vz)*.25+.025))
        snow_faces=[(0,1+i,1+(i+1)%count) for i in range(count) if (i+level+tree)%4!=0]
        cap=bpy.data.meshes.new("Broken branch snow cover")
        cap.from_pydata(snow_vertices,[],snow_faces);cap.update()
        snow_obj=bpy.data.objects.new("Snow on winter branches",cap);collection.objects.link(snow_obj)
        cap.materials.append(SNOW[tree%3])
    snow_drift("Pine foot drift", (x,y,.01),(.7,.6,.12))

begin("MountainWeatherStation", 7.4, 10.0)
box("Station foundation", (0,0,.2), (8,6,.4),CONCRETE,.12)
box("Insulated station body", (0,0,1.55),(6.8,4.8,2.7),WHITE,.10)
box("Station lower fascia", (0,-2.44,.6),(6.9,.10,.54),TEAL,.025)
box("Station flat roof", (0,0,2.98),(7.25,5.2,.24),TEAL,.06)
box("Roof snow", (-.1,.13,3.16),(6.65,4.6,.17),SNOW[0],.12)
box("Service door", (-2.15,-2.425,1.48),(1.1,.08,1.96),TEAL,.02)
for x in [-.5,.65,1.8]:
    box("Weather station window", (x,-2.43,1.85),(.85,.09,.70),DARK,.02)
    box("Iced window sill", (x,-2.51,1.47),(1.0,.25,.09),SNOW[1],.02)
cylinder("Radome plinth", (1.0,.5,3.65),1.6,.85,WHITE,20)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1.7,location=(1.0,.5,4.55))
attach(bpy.context.object,"Weather radar radome",SNOW[0])
for x,y in [(-2.5,1.45),(-1.4,1.45)]:
    beam("Radio mast leg",(x,y,3.2),(x+.3,y,8.75),.055,STEEL)
for z in [4.0,5.5,7.0,8.5]:
    beam("Radio mast crossbrace",(-2.5,1.45,z),(-1.4,1.45,z+.5),.035,STEEL)
for z in [6.1,7.4,8.6]:
    box("Antenna panel",(-1.35,1.45,z),(.20,.55,.85),WHITE,.025)
beam("Lightning rod",(-2.05,1.45,8.5),(-2.05,1.45,9.5),.023,STEEL)
for x in [-3.4,3.4]:
    for y in [-2.55,2.55]:
        beam("Roof rail post",(x,y,3.1),(x,y,3.7),.035,STEEL)
    beam("Roof side handrail",(x,-2.55,3.7),(x,2.55,3.7),.035,STEEL)
for x in [-2.7,-1.4,0,1.4,2.7]:
    box("Foundation step", (x,-3.15,.1),(.9,.65,.18),CONCRETE,.035)
box("Emergency power box", (4.3,1,1.1),(1.2,2.2,1.8),TEAL,.07)
for z in [.6,.85,1.1,1.35,1.6]:
    box("Generator vent",(4.92,1,z),(.03,1.55,.08),DARK)

begin("AbandonedCableStation", 7.6, 6.8)
box("Cable shelter foundation",(0,0,.2),(9,6,.4),CONCRETE,.1)
for x in [-3.6,3.6]:
    for y in [-2.2,2.2]:
        box("Concrete cable pier",(x,y,1.9),(.55,.55,3.4),CONCRETE,.06)
    beam("Upper steel tie",(x,-2.4,3.5),(x,2.4,3.5),.13,TEAL)
for y in [-2.2,-.7,.7,2.2]:
    beam("Cable shelter truss",(-3.9,y,3.5),(0,y,4.4),.11,TEAL)
    beam("Cable shelter truss",(0,y,4.4),(3.9,y,3.5),.11,TEAL)
for x in [-2.6,-1.3,0,1.3,2.6]:
    roof=box("Damaged pitched canopy",(x,.6,4.36-abs(x)*.23),(1.12,4.5,.12),TEAL,.025)
    roof.rotation_euler.y = .23 if x>0 else -.23
    cap=box("Canopy snow slab",(x,.75,4.46-abs(x)*.23),(1.02,4.1,.10),SNOW[1],.06)
    cap.rotation_euler.y = roof.rotation_euler.y
cylinder("Abandoned cable drum",(0,-.1,1.6),1.0,1.5,TEAL,20)
for x in [-1.8,1.8]:
    box("Winch foot",(x,0,.85),(.5,2.5,1.3),STEEL,.06)
beam("Unused haul cable",(-1.8,0,1.8),(1.8,0,1.8),.10,DARK)
box("Maintenance cabinet",(-2.6,1.3,1.25),(1.1,1.3,1.7),WHITE,.06)
box("Faded hazard stripe",(-2.6,.625,1.5),(.8,.035,.18),ORANGE)
box("Broken roof panel",(2.4,-2.6,.44),(2.0,1.2,.10),TEAL,.025,.4)

begin("WinterSedge", 1.6, .28)
for patch,(x,y) in enumerate([(-.5,0),(.4,.4),(.5,-.5)]):
    for stem in range(5):
        angle=stem*math.tau/5+patch
        beam("Dry winter stem",(x,y,.01),(x+math.cos(angle)*.15,y+math.sin(angle)*.15,.15+stem*.022),.012,GRASS)
    snow_drift("Sedge snow pocket",(x-.15,y+.08,.005),(.26,.20,.07))

manifest={}
for name,asset,radius_limit,height_limit in assets:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in asset.objects:obj.select_set(True)
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get()
    points=[evaluated.matrix_world @ vertex.co for obj in asset.objects if obj.type=="MESH"
            for evaluated in [obj.evaluated_get(deps)] for vertex in evaluated.data.vertices]
    radius=max(math.hypot(p.x,p.y) for p in points);height=max(p.z for p in points)
    assert radius<=radius_limit and height<=height_limit,(name,radius,height)
    manifest[name]={"radius":round(radius,4),"height":round(height,4),
                    "radius_limit":radius_limit,"height_limit":height_limit,
                    "interior":name.startswith("GlacialShelf")}
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")),export_format="GLB",
                              use_selection=True,export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"art/environment/AlpineKit.blend"))
(ROOT/"art/environment/alpine-manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print(json.dumps(manifest))
