"""Original neutral traffic, resident and fox assets. Blender Z up; forward -Y."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/environment/ambient'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
assets=[]
def mat(name,color,metal=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=.42 if metal else .72
    return m
paint=mat('Faded civilian jade',(.22,.46,.39),.2)
cream=mat('Warm ivory roof',(.73,.66,.48))
dark=mat('Rubber and seams',(.025,.034,.039))
glass=mat('Blue smoked glazing',(.055,.12,.16),.4)
chrome=mat('Bumpers and hubs',(.4,.43,.4),.7)
light=mat('Headlamps',(.93,.8,.46)); red=mat('Tail lamps',(.5,.06,.025))
coat=mat('Ochre work coat',(.62,.34,.09)); trousers=mat('Slate trousers',(.11,.18,.23)); skin=mat('Skin',(.55,.33,.19)); hair=mat('Hair',(.07,.046,.023))
fur=mat('Red fox coat',(.62,.23,.075)); white=mat('Cream fur',(.79,.7,.51))
def begin(name):
    global col
    col=bpy.data.collections.new(name); bpy.context.scene.collection.children.link(col); assets.append((name,col))
def attach(o,name,m):
    o.name=name
    for c in list(o.users_collection): c.objects.unlink(o)
    col.objects.link(o); o.data.materials.append(m); return o

def box(name,pos,size,m,bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos); o=bpy.context.object; o.scale=size; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    attach(o,name,m)
    if bevel:
        b=o.modifiers.new('Soft edges','BEVEL'); b.width=bevel; b.segments=2
        o.modifiers.new('Face normals','WEIGHTED_NORMAL')
    return o

def sphere(name,pos,size,m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=1,location=pos); o=bpy.context.object; o.scale=size; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for polygon in o.data.polygons: polygon.use_smooth=True
    return attach(o,name,m)
def pivot(name,pos,objects):
    o=bpy.data.objects.new(name,None); col.objects.link(o); o.location=pos
    for child in objects:
        child.parent=o; child.location-=Vector(pos)
    return o
def profile(name, sections, m, bevel=.04):
    # A longitudinal loft gives vehicles real sloping glazing and tapered panels.
    vertices=[]
    for y, width, bottom, top in sections:
        vertices.extend([(-width,y,bottom),(width,y,bottom),(width,y,top),(-width,y,top)])
    faces=[(3,2,1,0)]
    for i in range(len(sections)-1):
        for j in range(4):faces.append((i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j))
    faces.append(tuple(range(len(vertices)-4,len(vertices))))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);col.objects.link(obj);obj.data.materials.append(m)
    modifier=obj.modifiers.new('Pressed panel edges','BEVEL');modifier.width=bevel;modifier.segments=3
    obj.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    return obj

def beam(name,a,b,width,m):
    a,b=Vector(a),Vector(b)
    obj=box(name,(a+b)/2,(width,width,(b-a).length),m,width*.22)
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return obj

begin('ResidentCar')
profile('Lower body',[(-1.3,.59,.29,.53),(-1.1,.68,.27,.65),(-.45,.69,.27,.72),(.68,.68,.27,.70),(1.25,.60,.31,.61)],paint,.09)
profile('Cabin glass',[(-.66,.59,.64,.70),(-.32,.54,.65,1.12),(.59,.54,.65,1.12),(.98,.59,.65,.75)],glass,.045)
box('Ivory roof',(0,.14,1.13),(1.12,.96,.075),cream,.05)
for x in [-1,1]:
    beam('Windshield pillar',(x*.6,-.65,.68),(x*.54,-.32,1.1),.07,paint)
    beam('Rear pillar',(x*.59,.97,.73),(x*.54,.59,1.1),.08,paint)
    beam('Window divider',(x*.58,.22,.68),(x*.54,.22,1.11),.055,paint)
    box('Door sill',(x*.665,.1,.42),(.045,1.8,.075),dark,.012)
    beam('Door shutline',(x*.691,.3,.39),(x*.691,.3,.67),.018,dark)
    box('Door handle',(x*.684,.43,.63),(.035,.18,.038),chrome,.01)
    box('Mirror',(x*.73,-.45,.81),(.17,.17,.10),paint,.04)
    box('Mirror glass',(x*.735,-.375,.815),(.13,.02,.065),glass,.01)
    box('Front turn signal',(x*.635,-1.22,.53),(.045,.17,.07),coat,.018)
box('Hood panel',(0,-.97,.647),(1.15,.52,.045),paint,.035)
for y in [-1.3,1.25]:
    box('Bumper',(0,y,.34),(1.18,.13,.13),chrome,.04)
    for x in [-.47,.47]:box('Lamp',(x,y,.54),(.25,.055,.14),light if y<0 else red,.035)
box('Front grille',(0,-1.335,.47),(.59,.035,.15),dark,.02)
for x in [-.22,-.11,0,.11,.22]:box('Grille bar',(x,-1.358,.47),(.025,.016,.105),chrome,.005)
box('Front plate',(0,-1.383,.32),(.34,.015,.10),cream,.008)
box('Exhaust',(.43,1.35,.24),(.11,.15,.09),dark,.025)
for side,x in [('Left',-.69),('Right',.69)]:
    for end,y in [('Front',-.82),('Rear',.81)]:
        parts=[]
        bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.285,depth=.18,location=(x,y,.285),rotation=(0,math.pi/2,0))
        tire=attach(bpy.context.object,'Tire',dark);parts.append(tire)
        bevel=tire.modifiers.new('Rounded tire shoulder','BEVEL');bevel.width=.025;bevel.segments=2
        tire.modifiers.new('Tire normals','WEIGHTED_NORMAL')
        outer=x+(.101 if x>0 else -.101)
        bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=.18,depth=.015,location=(outer,y,.285),rotation=(0,math.pi/2,0))
        parts.append(attach(bpy.context.object,'Wheel rim',chrome))
        for step in range(5):
            a=step*math.tau/5
            parts.append(beam('Rim spoke',(outer,y,.285),(outer,y+math.cos(a)*.15,.285+math.sin(a)*.15),.035,dark))
        for step in range(12):
            a=step*math.tau/12
            tread=box('Tread groove',(x,y+math.cos(a)*.283,.285+math.sin(a)*.283),(.15,.035,.012),dark,.003)
            tread.rotation_euler.x=a-math.pi/2;parts.append(tread)
        pivot(side+end+'Wheel',(x,y,.285),parts)
begin('Resident')
box('Coat',(0,0,.91),(.37,.26,.48),coat,.085)
box('Coat hem',(0,0,.66),(.39,.27,.11),coat,.025)
box('Shirt',(0,-.138,1.07),(.13,.025,.16),cream,.015)
for x in [-.073,.073]:
    lapel=box('Coat lapel',(x,-.15,1.04),(.065,.035,.2),coat,.015);lapel.rotation_euler.y=x*2
for z in [.76,.87,.98]:sphere('Coat button',(.018,-.153,z),(.015,.012,.015),dark)
box('Belt',(0,-.01,.67),(.37,.27,.035),dark,.015)
sphere('Neck',(0,0,1.17),(.065,.065,.09),skin)
head=[sphere('Head',(0,-.01,1.32),(.13,.12,.17),skin),sphere('Hair',(0,.025,1.425),(.135,.12,.09),hair)]
head.append(sphere('Nose',(0,-.133,1.32),(.026,.029,.033),skin))
for x in [-.135,.135]:head.append(sphere('Ear',(x,0,1.31),(.025,.035,.045),skin))
for x in [-.052,.052]:
    head.append(sphere('Eye',(x,-.119,1.357),(.017,.012,.012),dark))
pivot('HeadPivot',(0,0,1.17),head)
box('Satchel',(.24,.055,.78),(.15,.24,.25),cream,.035)
box('Satchel clasp',(.325,.015,.81),(.018,.06,.05),chrome,.008)
for side,x in [('Left',-.105),('Right',.105)]:
    upper=box('Trouser thigh',(x,0,.5),(.145,.165,.28),trousers,.04)
    lower=box('Trouser calf',(x,.015,.25),(.13,.15,.28),trousers,.035)
    shoe=box('Shoe',(x,-.055,.08),(.16,.28,.12),dark,.035)
    sole=box('Shoe sole',(x,-.065,.033),(.17,.29,.035),trousers,.012)
    knee=pivot(side+'Knee',(x,0,.38),[lower,shoe,sole])
    pivot(side+'Leg',(x,0,.63),[upper,knee])
for side,x in [('Left',-.25),('Right',.25)]:
    upper=box('Sleeve',(x,0,.97),(.125,.18,.25),coat,.045)
    lower=box('Cuff',(x,-.015,.765),(.115,.155,.2),coat,.04)
    hand=sphere('Hand',(x,-.028,.63),(.06,.067,.085),skin)
    elbow=pivot(side+'Elbow',(x,0,.85),[lower,hand])
    pivot(side+'Arm',(x,0,1.07),[upper,elbow])
begin('Fox')
sphere('Body',(0,0,.49),(.21,.44,.23),fur)
sphere('Chest',(0,-.29,.51),(.19,.19,.23),white)
sphere('Head',(0,-.43,.68),(.18,.21,.17),fur)
sphere('Muzzle',(0,-.61,.62),(.1,.17,.08),white)
sphere('Nose',(0,-.75,.64),(.044,.035,.034),dark)
sphere('Brow',(0,-.46,.79),(.13,.12,.05),fur)
for x in [-.12,.12]:
    bpy.ops.mesh.primitive_cone_add(vertices=4,radius1=.11,radius2=.01,depth=.23,location=(x,-.4,.89)); attach(bpy.context.object,'Ear',fur)
    sphere('Eye',(x,-.57,.72),(.021,.019,.023),dark)
    sphere('Eye glint',(x*.99,-.588,.729),(.007,.006,.007),white)
for side,x in [('Left',-.14),('Right',.14)]:
    for end,y in [('Front',-.27),('Back',.29)]:
        limb=[box('Leg fur',(x,y,.24),(.105,.12,.33),fur),box('Paw',(x,y-.035,.07),(.11,.18,.1),dark)]
        pivot(side+end+'Leg',(x,y,.41),limb)
tail=sphere('Brush',(0,.62,.43),(.16,.4,.15),fur)
tip=sphere('White tail tip',(0,.91,.42),(.135,.14,.12),white)
pivot('Tail',(0,.34,.43),[tail,tip])
manifest={}
for name,c in assets:
    bpy.ops.object.select_all(action='DESELECT')
    for o in c.objects:o.select_set(True)
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get()
    verts=[e.matrix_world@v.co for o in c.objects if o.type=='MESH' for e in [o.evaluated_get(deps)] for v in e.data.vertices]
    manifest[name]={'height':round(max(v.z for v in verts),3),'radius':round(max(math.hypot(v.x,v.y) for v in verts),3)}
    assert manifest[name]['height']<=1.52
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/environment/AmbientKit.blend'))
(ROOT/'art/environment/ambient-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
