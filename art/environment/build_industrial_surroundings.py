"""Original editable industrial perimeter kit. Blender Z up, metres."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/environment/industrial-surroundings'; OUT.mkdir(parents=True,exist_ok=True)
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


begin('RailServiceBay',12)
box('Loading apron',(0,0,.14),(18,12,.28),concrete,.12)
box('Brick shed',(0,1,2.35),(16,8,4.4),brick)
for x in [-5,0,5]:loading_door(x,-3.04)
roof_profile('Pitched seam roof',-8.3,8.3,[-3.4,1,5.4],[4.6,5.9,4.6])
for x in range(-8,9,2):
 beam('Roof seam',(x,-3.4,4.68),(x,1,5.98),.035,steel)
 beam('Roof seam',(x,1,5.98),(x,5.4,4.68),.035,steel)
for x in [-8,8]:beam('Gutter drain',(x,-3.3,.35),(x,-3.3,4.6),.10,rust)
box('Freight platform',(0,-4.8,.55),(16,1.6,.8),concrete)
for x in [-7,-3,3,7]:box('Platform edge paint',(x,-5.62,.96),(1.5,.05,.08),paint,0)

begin('RailWagon',11)
box('Steel chassis',(0,0,1),(18,3.1,.35),dark)
for x in [-6,6]:
 for y in [-1.4,1.4]:
  o=cyl('Wheel',(x,y,.6),.52,.22,dark);o.rotation_euler.x=math.pi/2
box('Freight box',(0,0,2.55),(17,2.8,2.8),ochre)
box('Freight roof',(0,0,4.01),(17.2,2.95,.15),roof)
for x in range(-8,9):
 for y in [-1.42,1.42]:box('Wagon rib',(x,y,2.6),(.08,.08,2.6),rust,0)
for x in [-9.2,9.2]:box('Coupler',(x,0,.93),(.7,.3,.2),steel)
for y in [-1.49,1.49]:box('Sliding door',(0,y,2.55),(3.0,.07,2.6),blue)

begin('DistrictUtilities',10)
box('Utility foundation',(0,0,.14),(13,12,.28),concrete,.12)
for x,y in [(-3,0),(2.5,2)]:
 cyl('Water storage',(x,y,2.8),2.15,5.2,rim,24)
 cyl('Tank cap',(x,y,5.43),2.2,.18,steel,24)
 for z in [.6,2.7,4.8]:cyl('Tank strap',(x,y,z),2.19,.1,rust,24)
 ladder(x,y-2.23,5.7)
 cyl('Tank vent',(x,y,5.8),.3,.6,steel)
beam('Drain manifold',(-5,-4,.7),(5,-4,.7),.25,rust)
for x in [-3,2.5]:beam('Tank drain',(x,-1,.7),(x,-4,.7),.2,steel)
box('Pump cabinet',(4,-2,1.2),(2,2,2),blue)

begin('Substation',10)
box('Substation pad',(0,0,.15),(13,12,.3),concrete)
for x in [-3,3]:
 box('Transformer',(x,0,1.9),(3.2,4,3.5),blue,.12)
 for y in [-1.6,-1.1,-.6,-.1,.4,.9,1.4]:box('Cooling fin',(x,y,1.7),(3.65,.1,2.7),steel,0)
 for dx in [-.9,.9]:
  beam('Insulator core',(x+dx,0,3.7),(x+dx,0,5.0),.12,dark)
  for z in [3.9,4.15,4.4,4.65]:cyl('Ceramic disc',(x+dx,0,z),.27,.08,rim)
for x in [-5.5,5.5]:
 for y in [-4.5,4.5]:beam('Gantries',(x,y,.3),(x,y,6.1),.10,steel)
 beam('Gantry crossbar',(x,-4.5,6.1),(x,4.5,6.1),.1,steel)
for y in [-4.5,4.5]:beam('Power bar',(-5.5,y,6.1),(5.5,y,6.1),.065,rust)
box('Control hut',(0,4.5,1.15),(3,1.8,2),ochre)

begin('BirchScrub',4.6)
leaf=mat('Dusty birch leaves',(.24,.29,.12)); bark=mat('Birch pale bark',(.57,.54,.42))
for x,y,h in [(-1.2,-.8,4.7),(1.3,.8,5.8),(-.5,1.8,3.6)]:
 beam('Birch trunk',(x,y,0),(x+.2,y,h),.10,bark)
 for z in [1,1.8,2.6,3.2]:box('Bark scar',(x,y-.1,z),(.16,.04,.09),dark,0)
 for dx,dy,dz in [(-.8,0,-.9),(.7,.5,-.3),(0,-.4,.3)]:
  beam('Branch',(x,y,h-2),(x+dx,y+dy,h+dz),.055,bark)
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(x+dx,y+dy,h+dz))
  o=bpy.context.object;o.scale=(1.1,.95,1.45);attach(o,'Birch crown',leaf,0)
for x,y in [(-2,1),(2,-1),(0,-2)]:
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.65,location=(x,y,.4));attach(bpy.context.object,'Ground scrub',vegetation,0)

manifest={}
for name,c,radius_limit in assets:
 bpy.ops.object.select_all(action='DESELECT')
 for o in c.objects:o.select_set(True)
 bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
 points=[e.matrix_world@v.co for o in c.objects if o.type=='MESH' for e in [o.evaluated_get(deps)] for v in e.data.vertices]
 radius=max(math.hypot(v.x,v.y) for v in points);height=max(v.z for v in points)
 assert radius<=radius_limit and height<=8,(name,radius,height)
 manifest[name]={'radius':round(radius,3),'height':round(height,3),'radius_limit':radius_limit,'height_limit':8}
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/environment/IndustrialSurroundingsKit.blend'))
(ROOT/'art/environment/industrial-surroundings-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest))
