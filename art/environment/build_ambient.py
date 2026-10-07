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
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=.65
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
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=1,location=pos); o=bpy.context.object; o.scale=size; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); return attach(o,name,m)
def pivot(name,pos,objects):
    o=bpy.data.objects.new(name,None); col.objects.link(o); o.location=pos
    for child in objects:
        child.parent=o; child.location-=Vector(pos)
    return o
begin('ResidentCar')
box('Lower body',(0,0,.42),(1.38,2.6,.5),paint,.12)
box('Cabin glass',(0,.12,.8),(1.16,1.4,.6),glass,.13)
box('Ivory roof',(0,.18,1.09),(1.2,1.25,.09),cream,.05)
for x in [-.62,.62]:
    box('Door sill',(x,.08,.5),(.09,1.6,.18),cream)
    for y in [-.47,.68]: box('Window pillar',(x,y,.87),(.08,.07,.42),paint)
    box('Door handle',(x,.42,.62),(.04,.15,.04),chrome,.01)
    box('Mirror',(x*1.15,-.45,.81),(.18,.16,.1),paint)
for y in [-1.3,1.3]:
    box('Bumper',(0,y,.3),(1.26,.14,.13),chrome)
    for x in [-.48,.48]: box('Lamp',(x,y,.53),(.25,.06,.14),light if y<0 else red)
box('Front grille',(0,-1.318,.45),(.56,.03,.16),dark,.01)
for x in [-.7,.7]:
    for y in [-.83,.84]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.28,depth=.16,location=(x,y,.28),rotation=(0,math.pi/2,0)); attach(bpy.context.object,'Wheel',dark)
        sphere('Hub',(x*1.08,y,.28),(.035,.12,.12),chrome)
begin('Resident')
box('Coat',(0,0,.9),(.38,.26,.5),coat,.07)
box('Coat hem',(0,0,.65),(.42,.27,.1),coat)
sphere('Head',(0,-.01,1.31),(.14,.13,.18),skin)
sphere('Hair',(0,.01,1.4),(.145,.13,.11),hair)
box('Satchel',(.25,.06,.76),(.17,.23,.24),cream,.035)
for side,x in [('Left',-.11),('Right',.11)]:
    limb=[box('Trouser',(x,0,.37),(.15,.17,.53),trousers),box('Shoe',(x,-.07,.085),(.17,.31,.13),dark)]
    pivot(side+'Leg',(x,0,.63),limb)
for side,x in [('Left',-.255),('Right',.255)]:
    limb=[box('Sleeve',(x,0,.86),(.13,.19,.36),coat,.045),sphere('Hand',(x,-.02,.63),(.065,.075,.09),skin)]
    pivot(side+'Arm',(x,0,1.05),limb)
begin('Fox')
sphere('Body',(0,0,.49),(.21,.44,.23),fur)
sphere('Chest',(0,-.29,.51),(.19,.19,.23),white)
sphere('Head',(0,-.43,.68),(.18,.21,.17),fur)
sphere('Muzzle',(0,-.61,.62),(.1,.17,.08),white)
sphere('Nose',(0,-.75,.64),(.055,.045,.04),dark)
for x in [-.12,.12]:
    bpy.ops.mesh.primitive_cone_add(vertices=4,radius1=.11,radius2=.01,depth=.23,location=(x,-.4,.89)); attach(bpy.context.object,'Ear',fur)
    sphere('Eye',(x,-.57,.72),(.025,.022,.024),dark)
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
