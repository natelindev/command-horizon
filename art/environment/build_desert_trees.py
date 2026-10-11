"""Build four original desert tree meshes; no textures or external assets required.
Run: blender --background --python art/environment/build_desert_trees.py
"""
import math
import random
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/environment/desert'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Roughness'].default_value = .93
    return mat


bark = material('Rough desert bark', (.18, .135, .085))
leaves = [material('Desert foliage %d' % i, color) for i, color in enumerate([
    (.16, .20, .105), (.21, .25, .135), (.28, .30, .17), (.32, .32, .19)])]


def branch(a, b, radius):
    delta = Vector(b) - Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=radius, radius2=radius*.55,
        depth=delta.length, location=(Vector(a)+Vector(b))/2)
    obj = bpy.context.object
    obj.rotation_euler = delta.to_track_quat('Z', 'Y').to_euler()
    obj.data.materials.append(bark)
    return obj


for variant, name in enumerate(['DesertAcacia', 'DesertMesquite', 'DesertJuniper', 'DesertWindswept']):
    rng = random.Random(4200+variant)
    objects = []
    verts, faces, colors = [], [], []
    height = [3.5, 3.1, 4.1, 3.6][variant]
    lean = [.25, -.35, .08, .9][variant]
    stem = Vector((lean*.25, 0, height*.4))
    fork = Vector((lean*.65, .08, height*.65))
    objects += [branch((0, 0, 0), stem, .15), branch(stem, fork, .10)]
    for root_index in range(5):
        angle = root_index*math.tau/5
        objects.append(branch((math.cos(angle)*.35, math.sin(angle)*.35, .02), (0,0,.4), .055))
    for limb in range(10 if variant != 3 else 8):
        angle = limb*2.399 + rng.uniform(-.2, .2)
        if variant == 2:
            level = .3 + limb*.065
            radius = (1-level)*1.8
            end = Vector((math.cos(angle)*radius, math.sin(angle)*radius, height*level))
        else:
            radius = rng.uniform(.85, 1.65) * (1.15 if variant == 0 else 1)
            end = Vector((lean+math.cos(angle)*radius, math.sin(angle)*radius,
                          height+rng.uniform(-.55,.15)))
        start = stem if limb%3 == 0 else fork
        elbow = start.lerp(end, .55) + Vector((0,0,-.15))
        objects += [branch(start, elbow, .065), branch(elbow, end, .035)]
        for twig in range(4):
            tip = end + Vector((rng.uniform(-.48,.48),rng.uniform(-.48,.48),rng.uniform(-.1,.3)))
            objects.append(branch(elbow.lerp(end,.65),tip,.015))
            count = 35 if variant == 3 else 65
            for leaf in range(count):
                # Small folded leaf sprays create broken silhouettes and dappled shadows.
                theta = rng.random()*math.tau
                r = math.sqrt(rng.random())*.56
                center = tip + Vector((math.cos(theta)*r,math.sin(theta)*r,rng.uniform(-.22,.26)))
                axis = Vector((math.cos(theta),math.sin(theta),rng.uniform(-.6,.6))) * rng.uniform(.08,.16)
                cross = Vector((-math.sin(theta),math.cos(theta),.15)) * rng.uniform(.035,.065)
                index = len(verts)
                verts.extend([center-axis,center+cross,center+Vector((0,0,.035)),center-cross,center+axis])
                faces.extend([(index,index+1,index+2),(index,index+2,index+3),
                              (index+4,index+2,index+1),(index+4,index+3,index+2)])
                colors.extend([rng.randrange(4)]*4)
    mesh = bpy.data.meshes.new(name+'Leaves')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    foliage = bpy.data.objects.new(name+'Leaves',mesh)
    bpy.context.collection.objects.link(foliage)
    for mat in leaves:
        mesh.materials.append(mat)
    for face, color in zip(mesh.polygons,colors):
        face.material_index=color
    objects.append(foliage)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=foliage
    bpy.ops.object.join()
    foliage.name=name
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',
        use_selection=True,export_yup=True)
    foliage.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/environment/DesertTrees.blend'))
