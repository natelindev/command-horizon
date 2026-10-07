"""Original editable industrial district kit. Blender Z up, metres."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/environment/industrial'; OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
assets=[]
def mat(name,color,metal=0,rough=.8):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    return m
concrete=mat('Aged pale concrete',(.39,.39,.34)); rim=mat('Concrete caps',(.53,.51,.43))
blue=mat('Faded slate wall panels',(.19,.29,.31),.15); ochre=mat('Weathered ochre panels',(.44,.29,.13),.15)
roof=mat('Oxidized standing seam roof',(.14,.23,.22),.35); rust=mat('Rust on edges',(.31,.13,.057),.2)
dark=mat('Deep recesses',(.034,.055,.06)); glass=mat('Muted industrial glazing',(.105,.2,.22),.3,.4)
steel=mat('Galvanized hardware',(.36,.41,.41),.7,.45); paint=mat('Safety paint',(.68,.49,.17))
brick=mat('Warm brickwork',(.33,.19,.125)); vegetation=mat('Volunteer scrub',(.15,.23,.12))

def begin(name,radius=8):
 global col
 col=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(col);assets.append((name,col,radius))
def attach(o,name,m,bevel=.03):
 o.name=name
 for c in list(o.users_collection):c.objects.unlink(o)
 col.objects.link(o);o.data.materials.append(m)
 if bevel:
  b=o.modifiers.new('Worn edges','BEVEL');b.width=bevel;b.segments=1;o.modifiers.new('Face normals','WEIGHTED_NORMAL')
 return o

def box(name,pos,size,m=concrete,bevel=.03,rot=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.rotation_euler.z=rot;return attach(o,name,m,bevel)
def cyl(name,pos,r,depth,m=steel,vertices=16):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=pos);return attach(bpy.context.object,name,m)
def beam(name,a,b,r=.07,m=steel):
 a,b=Vector(a),Vector(b);o=cyl(name,(a+b)/2,r,(b-a).length,m,8);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def foundation():
 box('Service apron',(0,0,.12),(11.1,10.6,.24),concrete,.16)
 for x in [-5.35,5.35]:
  box('Drain channel',(x,0,.26),(.15,8.7,.05),dark,0)
  for y in range(-4,5):box('Drain crossbar',(x,y,.30),(.25,.06,.045),steel,0)
 for x in [-4,4]:
  box('Dock bollard',(x,-4.95,.55),(.18,.18,.7),paint)

def loading_door(x,y,z=1.65):
 box('Roll-up loading door',(x,y,z),(2.5,.06,2.6),dark)
 for i in range(10):box('Door slat',(x,y-.05,.45+i*.255),(2.35,.045,.055),steel,.01)
 box('Door lintel',(x,y-.08,3.06),(2.85,.20,.20),rim)
 for dx in [-1.36,1.36]:box('Door jamb',(x+dx,y-.06,1.62),(.16,.20,2.9),rim)
 box('Bay number',(x,y-.06,3.65),(.8,.05,.45),paint)

def ladder(x,y,height):
 for dx in [-.3,.3]:beam('Ladder rail',(x+dx,y,.35),(x+dx,y,height))
 for i in range(int(height/.35)):beam('Ladder rung',(x-.3,y,.45+i*.35),(x+.3,y,.45+i*.35),.04)

def wall_seams(width,height,y):
 for i in range(int(width)):
  box('Panel seam',(-width/2+i,y,height/2),(.035,.025,height-.25),rust,0)

def roof_profile(name,x0,x1,ys,zs):
 verts=[(x,y,z) for x in [x0,x1] for y,z in zip(ys,zs)];n=len(ys)
 faces=[(i,i+n,i+1+n,i+1) for i in range(n-1)]
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);col.objects.link(o);o.data.materials.append(roof)
 solid=o.modifiers.new('Roof thickness','SOLIDIFY');solid.thickness=.1
 return o

begin('SawtoothWorkshop')
foundation();box('Workshop walls',(0,0,2.18),(10.5,9.4,4.12),blue)
for x in [-3,3]:loading_door(x,-4.73)
wall_seams(10,4,-4.72)
# Three north-light bays produce a distinct sawtooth skyline.
for y in [-3.1,0,3.1]:
 roof_profile('Sawtooth roof',-5.35,5.35,[y-1.55,y+1.15,y+1.55],[4.35,5.7,4.35])
 box('North-light glass',(0,y+1.16,5.05),(10.15,.065,1.05),glass)
 box('Clerestory cap',(0,y+1.15,5.78),(10.7,.12,.10),steel)
 for x in [-4.8,-3.6,-2.4,-1.2,0,1.2,2.4,3.6,4.8]:beam('Standing seam',(x,y-1.5,4.43),(x,y+1.10,5.73),.025,steel)
 for x in [-4,-2,0,2,4]:box('Clerestory mullion',(x,y+1.12,5.04),(.055,.08,1.2),steel,0)
 for x in [-5.2,5.2]:beam('Roof edge',(x,y-1.55,4.43),(x,y+1.15,5.78),.075,rust)
ladder(4.5,4.86,5.3)
for x in [-4.8,4.8]:beam('Downpipe',(x,4.8,.35),(x,4.8,4.4),.09,rust)

begin('CoolingHall')
foundation();box('Brick plinth',(0,0,.65),(10.5,9.4,1.15),brick);box('Corrugated hall',(0,0,2.85),(10.5,9.4,3.4),ochre)
loading_door(-2.8,-4.74)
box('Roof parapet',(0,0,4.66),(10.7,9.6,.28),rim)
box('Dark roof membrane',(0,0,4.83),(10.3,9.2,.07),dark)
for x in [-2.8,2.8]:
 box('Ventilation unit',(x,.8,5.48),(3.3,3.6,1.25),steel,.10)
 for y in [-.4,1.8]:
  cyl('Fan recess',(x,y,6.12),1.15,.07,dark)
  cyl('Fan hub',(x,y,6.19),.20,.12,steel)
  for a in [0,math.pi/2]:box('Fan blade',(x,y,6.2),(1.9,.16,.06),steel,rot=a)
 for z in [5.05,5.25,5.45,5.65,5.85]:box('Intake louver',(x,-1.03,z),(2.9,.12,.07),dark)
for x in [2,3,4]:
 beam('External feed pipe',(x,-4.9,.4),(x,-4.9,3.9),.16,rust)
 beam('Roof pipe',(x,-4.9,3.9),(x,-3.8,5.0),.16,rust)
wall_seams(10,4,-4.72)
ladder(-4.7,4.86,5.2)

begin('ServiceOffice')
foundation();box('Office brickwork',(0,.1,2.7),(10.5,9.1,5.2),brick)
for z in [.4,2.7,5.15]:box('Concrete band',(0,.1,z),(10.7,9.3,.22),rim)
box('Flat roof',(0,.1,5.4),(10.8,9.5,.22),roof)
for x in [-4,-2,0,2,4]:
 for z in [1.65,3.85]:
  box('Window surround',(x,-4.48,z),(1.45,.13,1.15),rim)
  box('Window glazing',(x,-4.57,z),(1.25,.035,.95),glass)
  box('Window mullion',(x,-4.61,z),(.065,.04,.95),steel,0)
for x in [-5.28,5.28]:
 for y in [-2,0,2]:
  for z in [1.65,3.85]:box('Side window',(x,y,z),(.05,1.25,1),glass)
box('Entrance recess',(0,-4.58,1.15),(1.6,.12,1.8),dark)
box('Entrance canopy',(0,-4.85,2.43),(3.5,.8,.14),steel)
box('Solar array',(1,.3,5.76),(4.8,4.2,.20),glass)
for x in [-1,0,1,2,3]:box('Solar mullion',(x,.3,5.9),(.04,4,.035),steel,0)
box('Roof access',(-3,2.5,5.85),(1.6,1.8,.7),concrete)
cyl('Exhaust',(-3,-1,5.93),.32,.85,steel)

begin('DamagedWarehouse')
foundation();box('Retained west wall',(-5.1,0,2.25),(.35,9.4,4.1),concrete);box('Rear wall',(0,4.5,2.25),(10.3,.4,4.1),concrete)
box('East corner',(5.1,2.8,2.15),(.35,3.8,3.9),blue)
box('Low front wall',(-3.2,-4.5,.8),(4.1,.4,1.1),brick)
for x in [-4.8,-1.6,1.6,4.8]:
 for y in [-4.4,4.4]:box('Steel column',(x,y,2.8),(.17,.17,5.1),rust)
 beam('Exposed truss',(x,-4.5,5.1),(x,0,6.3),.12,rust)
 beam('Exposed truss',(x,0,6.3),(x,4.5,5.1),.12,rust)
 beam('Tie beam',(x,-4.4,4.95),(x,4.4,4.95),.09,steel)
roof_profile('Surviving roof panels',-5.3,-.9,[-4.65,0,4.65],[5.1,6.35,5.1])
for x,y,z in [(1,-2,.35),(3,-3,.25),(4,1,.32),(2,3,.3),(0,1,.26),(-3,-3,.32)]:
 box('Fallen concrete',(x,y,z),(1.4,.85,.5),concrete,.14,rot=x*.45)
for x,y in [(3,2),(2,-1),(-2,3)]:
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.65,location=(x,y,.55));attach(bpy.context.object,'Volunteer scrub',vegetation,0)
box('Abandoned pallet',(2.5,.6,.35),(1.6,2.0,.20),ochre)
for x in [2,2.3,2.6,2.9]:box('Pallet slat',(x,.6,.49),(.15,1.9,.10),rim)

begin('FurnaceBlock',5)
box('Furnace apron',(0,0,.15),(6.7,6.5,.3),concrete,.2)
for x in [-1.8,1.8]:
 cyl('Smelter shell',(x,0,2.3),1.4,4.1,rust)
 for z in [.65,2.1,3.6,4.35]:cyl('Steel retaining band',(x,0,z),1.46,.14,steel)
 cyl('Chimney',(x,0,5.25),.72,1.85,dark)
 cyl('Stack collar',(x,0,6.2),.83,.25,steel)
 box('Service hatch',(x,-1.44,1.8),(.9,.1,1.1),dark)
 beam('Heat pipe',(x,1.4,3),(x,3.3,3),.28,rust)
 beam('Heat pipe drop',(x,3.3,3),(x,3.3,.5),.28,rust)
box('Catwalk',(0,-1.9,3.4),(6.4,1,.18),steel)
for x in [-3,-1,1,3]:beam('Safety post',(x,-2.4,3.5),(x,-2.4,4.3),.045,paint)
beam('Safety rail',(-3,-2.4,4.3),(3,-2.4,4.3),.045,paint)
ladder(0,-2.5,3.6)
manifest={}
for name,c,radius_limit in assets:
 bpy.ops.object.select_all(action='DESELECT')
 for o in c.objects:o.select_set(True)
 bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
 points=[e.matrix_world@v.co for o in c.objects if o.type=='MESH' for e in [o.evaluated_get(deps)] for v in e.data.vertices]
 radius=max(math.hypot(v.x,v.y) for v in points);height=max(v.z for v in points)
 assert radius<=radius_limit and height<=6.9,(name,radius,height)
 manifest[name]={'radius':round(radius,3),'height':round(height,3),'radius_limit':radius_limit,'height_limit':6.9}
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/environment/IndustrialKit.blend'))
(ROOT/'art/environment/industrial-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest))
