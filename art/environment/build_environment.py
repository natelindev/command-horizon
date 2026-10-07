"""Build the editable Horizon environment kit. Run with Blender --background --python.
Coordinates are metres, Blender Z up. Every asset fits the existing 5.6 m blocker.
"""
import json
import math
import random
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/environment'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0

def material(name, color, metal=0, rough=.85):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    return m

STONE = [material('Basalt '+str(i), c) for i,c in enumerate([
    (.12,.145,.14), (.17,.185,.17), (.205,.205,.175), (.105,.12,.12)])]
CONCRETE = material('Weathered limestone concrete', (.32,.30,.24))
EDGE = material('Chipped concrete edges', (.44,.405,.32))
STEEL = material('Oxidized painted steel', (.105,.165,.16), .45)
RUST = material('Oxide seams', (.24,.105,.047), .2)
DARK = material('Recesses and rubber', (.025,.038,.038))
METAL = material('Galvanized steel', (.29,.33,.31), .7, .4)
PAINT = material('Faded ochre identification', (.49,.31,.065))
CERAMIC = material('Porcelain insulators', (.32,.40,.38), .1,.35)
assets=[]
collection=None

def attach(obj, name, mat, bevel=0):
    obj.name=name
    for c in list(obj.users_collection): c.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(mat)
    if bevel:
        mod=obj.modifiers.new('Worn edges','BEVEL'); mod.width=bevel; mod.segments=1
        obj.modifiers.new('Face normals','WEIGHTED_NORMAL')
    return obj

def box(name, pos, size, mat=CONCRETE, bevel=.04, rot=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj=bpy.context.object; obj.scale=size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.z=rot
    return attach(obj,name,mat,bevel)

def cyl(name, pos, radius, depth, mat=STEEL, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    return attach(bpy.context.object,name,mat,.025)

def beam(name,a,b,r=.07,mat=METAL):
    a,b=Vector(a),Vector(b)
    obj=cyl(name,(a+b)/2,r,(b-a).length,mat,8)
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return obj

def begin(name):
    global collection
    collection=bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    assets.append((name,collection))

def foundation():
    verts=[(-3.1,-3.7), (3.1,-3.7), (4.1,-2.7), (4.1,2.7), (3.1,3.7), (-3.1,3.7), (-4.1,2.7), (-4.1,-2.7)]
    mesh=bpy.data.meshes.new('Chamfered service pad')
    mesh.from_pydata([(x,y,z) for z in [.01,.23] for x,y in verts], [], [tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)])
    mesh.update()
    obj=bpy.data.objects.new('Service foundation',mesh); collection.objects.link(obj); obj.data.materials.append(CONCRETE)
    for x in [-3.4,3.4]:
        box('Drainage slot',(x,0,.33),(.35,4.6,.06),DARK,0)
        for y in range(-2,3): box('Drain grate',(x,y,.37),(.44,.07,.05),METAL,0)

def ladder(x,y,h):
    for dx in [-.3,.3]: beam('Ladder rail',(x+dx,y,.4),(x+dx,y,h))
    for i in range(int(h/.36)): beam('Ladder rung',(x-.3,y,.5+i*.36),(x+.3,y,.5+i*.36),.045)

def railing(a,b,z):
    for i in range(5):
        t=i/4; x=a[0]+(b[0]-a[0])*t; y=a[1]+(b[1]-a[1])*t
        beam('Railing post',(x,y,z),(x,y,z+.85),.045,PAINT)
    for h in [.4,.85]: beam('Railing',(a[0],a[1],z+h),(b[0],b[1],z+h),.045,PAINT)

begin('PumpStation')
foundation()
cyl('Water reservoir',(-1,0,2.25),2.05,3.8)
cyl('Tank lid',(-1,0,4.2),2.16,.18,METAL)
for z in [.6,1.8,3.25,4.1]: cyl('Tank band',(-1,0,z),2.1,.12,RUST)
cyl('Inspection hatch',(-1,0,4.38),.53,.2,DARK)
box('Pump housing',(2.1,.2,1.2),(1.8,2.5,1.65),STEEL,.13)
for x in [1.6,1.85,2.1,2.35,2.6]: box('Cooling ribs',(x,-1.08,1.3),(.07,.14,1.05),DARK,.01)
for y in [-1.6,1.6]:
    beam('Feed pipe',(.8,y,.85),(3.6,y,.85),.27,RUST)
    beam('Pipe riser',(3.6,y,.85),(3.6,y,2.7),.27,RUST)
    cyl('Valve flange',(3.6,y,2.75),.42,.16,METAL)
ladder(-1,-2.15,4.4)
railing((-2.5,1.4),(.5,1.4),4.3)
box('Station number panel',(-1,-2.07,2.65),(1.1,.07,.7),PAINT)

begin('ServiceRuin')
foundation()
box('Rear fractured wall',(0,2.2,2),(6.2,.48,3.5))
box('West wall',(-2.9,.1,1.65),(.48,4.1,2.8))
box('East pier',(2.9,1.25,2),(.5,1.65,3.6))
for x in [-2.65,0,2.65]:
    box('Steel upright',(x,2,2.7),(.17,.22,4.7),RUST)
    beam('Roof truss',(x,2,4.7),(x,-1.8,4.1),.12,RUST)
box('Surviving roof panel',(0,1.6,4.65),(5.8,1.6,.14),STEEL,rot=.04)
box('Door lintel',(-.4,-1.9,2.6),(3.8,.42,.55),EDGE,rot=-.09)
box('Broken column',(-2.1,-1.9,1.4),(.55,.5,2.6))
box('Low broken column',(1.4,-1.9,.7),(.55,.5,1.2))
for x in [-2.5,-1.7,-.9,0,.8,1.6,2.4]:
    box('Wall weather seam',(x,1.94,1.8),(.04,.025,2.9),RUST,0)
rng=random.Random(118)
for i in range(20):
    x,y=rng.uniform(-2.7,2.7),rng.uniform(-2.8,.7)
    box('Collapsed masonry',(x,y,.5),(rng.uniform(.3,.8),rng.uniform(.25,.7),rng.uniform(.2,.45)),EDGE,rot=rng.random()*3)
box('Burned floor',(0,0,.34),(4,3,.025),DARK,0)
beam('Fallen beam',(-2.5,-2,.7),(2.5,.9,.9),.17,RUST)

begin('RelaySubstation')
foundation()
for x in [-1.8,1.8]:
    box('Transformer plinth',(x,0,.6),(2.4,3.9,.5),EDGE)
    box('Transformer',(x,0,1.9),(1.6,2.7,2.2),STEEL,.14)
    for side in [-1,1]:
        for y in [-1,-.65,-.3,.05,.4,.75,1.1]:
            box('Radiator fin',(x+side*.95,y,1.7),(.45,.09,1.8),METAL,.015)
    for y in [-.8,0,.8]:
        beam('Bushing',(x,y,3),(x,y,4.1),.12,DARK)
        for z in [3.2,3.45,3.7,3.95]: cyl('Insulator',(x,y,z),.25,.1,CERAMIC)
for x in [-3.3,3.3]: beam('Gantry column',(x,2,.3),(x,2,5.8),.16,STEEL)
beam('Gantry crossbar',(-3.3,2,5.6),(3.3,2,5.6),.16,STEEL)
for x in [-1.8,1.8]: beam('Busbar',(x,0,4.15),(x,2,5.4),.07,RUST)
box('Switch cabinet',(0,-3.5,1.15),(2.4,.8,1.6),STEEL)
for x in [-.65,.65]: box('Warning plate',(x,-3.92,1.3),(.45,.03,.55),PAINT)

for variant in range(3):
    begin('CutBerm'+str(variant+1))
    rng=random.Random(51+variant)
    n=14
    angles=[i*2*math.pi/n for i in range(n)]
    radii=[rng.uniform(4.85,5.48) for _ in angles]
    vertices=[]
    peak_x=rng.uniform(-1.0,1.0)
    peak_y=rng.uniform(-1.0,1.0)
    heights=[rng.uniform(3.1,6.5) for _ in angles]
    # Jagged outcrop, with independently broken layers and an off-centre summit.
    for ring,(scale,fraction) in enumerate([(1,0),(.96,.22),(.84,.53),(.64,.80),(.28,1)]):
        for i,(a,r) in enumerate(zip(angles,radii)):
            jitter=1.0 if ring==0 else rng.uniform(.8,1.12)
            vertices.append((math.cos(a)*r*scale*jitter+peak_x*fraction,math.sin(a)*r*scale*jitter+peak_y*fraction,.025+heights[i]*fraction))
    faces=[]
    for ring in range(4):
        for i in range(n): faces.append((ring*n+i,ring*n+(i+1)%n,(ring+1)*n+(i+1)%n,(ring+1)*n+i))
    faces.append(tuple(range(4*n,5*n)))
    vertices=[(x*min(1,5.48/max(.001,math.hypot(x,y))),y*min(1,5.48/max(.001,math.hypot(x,y))),z) for x,y,z in vertices]
    mesh=bpy.data.meshes.new('Stratified rock'); mesh.from_pydata(vertices,[],faces); mesh.update()
    obj=bpy.data.objects.new('Cut basalt strata',mesh); collection.objects.link(obj)
    for m in STONE: mesh.materials.append(m)
    for poly in mesh.polygons: poly.material_index=(poly.index//n+variant+(1 if rng.random()<.22 else 0))%len(STONE)
    for y in [-2.7,0,2.7]:
        box('Retaining buttress',(-3.85,y,1.1),(.6,.65,2.2),CONCRETE,.09)
    beam('Old conduit',(-4,-2.6,1.7),(-4,2.6,1.7),.13,RUST)
    for i in range(7):
        a=rng.random()*math.tau; r=rng.uniform(3.6,4.6)
        box('Scree',(math.cos(a)*r,math.sin(a)*r,.2),(.55,.6,.35),STONE[2],.06,rng.random()*3)

manifest={}
for name,col in assets:
    bpy.ops.object.select_all(action='DESELECT')
    for obj in col.objects: obj.select_set(True)
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get()
    points=[o.matrix_world@Vector(c) for ob in col.objects for o in [ob.evaluated_get(deps)] for c in o.bound_box]
    radius=max(math.hypot(p.x,p.y) for p in points)
    # Bounding boxes of round meshes overestimate radius; check evaluated vertices exactly.
    points=[o.matrix_world@v.co for ob in col.objects for o in [ob.evaluated_get(deps)] for v in o.data.vertices]
    radius=max(math.hypot(p.x,p.y) for p in points)
    height=max(p.z for p in points)
    assert radius<=5.6 and height<=7, (name,radius,height)
    manifest[name]={'radius':round(radius,3),'height':round(height,3),'objects':len(col.objects)}
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True)
# Keep independent collections at their local origins for editing and rebuilding.
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/environment/HorizonKit.blend'))
(ROOT/'art/environment/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest))
