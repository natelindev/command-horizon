"""Build six neutral battlefield salvage silhouettes with Blender's bundled Python.
Run: Blender --background --python art/resources/build_resources.py
Meshes stay inside the existing 0.6 m navigation radius. No external textures.
"""
import json
import math
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/resources'
OUT.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0


def material(name, color, metal=0.0, rough=.6, glow=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    for key, value in [('Base Color', (*color, 1)), ('Metallic', metal),
                       ('Roughness', rough), ('Emission Color', (*color, 1)),
                       ('Emission Strength', glow)]:
        shader.inputs[key].default_value = value
    return mat


steel = material('Salvage / exposed alloy', (.32, .39, .42), .7, .42)
rust = material('Salvage / oxidized steel', (.23, .095, .044), .35, .85)
dark = material('Salvage / recessed graphite', (.028, .045, .052), .3)
paint = material('Salvage / recovery ochre', (.82, .39, .065), .25)
white = material('Salvage / worn ceramic', (.67, .71, .67), .15)
cyan = material('Salvage / recoverable electronics', (.045, .48, .54), .3, .38, .22)


def finish(obj, name, mat, bevel=0):
    obj.name = name
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new('Machined edges', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def box(name, pos, size, mat, angle=0, bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.z = angle
    return finish(obj, name, mat, bevel)


def cylinder(name, pos, radius, depth, mat, axis='Z', vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                      depth=depth, location=pos)
    obj = bpy.context.object
    if axis == 'Y':
        obj.rotation_euler.x = math.pi / 2
    elif axis == 'X':
        obj.rotation_euler.y = math.pi / 2
    return finish(obj, name, mat)


def ring(name, pos, outer, inner, depth, mat, axis='Z'):
    verts, faces = [], []
    for h in (-depth / 2, depth / 2):
        for radius in (outer, inner):
            for i in range(16):
                x = math.cos(i * math.tau / 16) * radius
                y = math.sin(i * math.tau / 16) * radius
                local = (x, h, y) if axis == 'Y' else (x, y, h)
                verts.append(tuple(a + b for a, b in zip(pos, local)))
    for i in range(16):
        j = (i + 1) % 16
        faces += [(i, j, 32+j, 32+i), (16+i, 48+i, 48+j, 16+j),
                  (i, 16+i, 16+j, j), (32+i, 32+j, 48+j, 48+i)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat)


def skid():
    for x in (-.28, .28):
        box('Recovered support rail', (x, 0, .037), (.09, .68, .074), rust)
    for y in (-.24, .24):
        box('Skid crossbar', (0, y, .077), (.76, .075, .055), steel)


def plate_marks(x, y, z, width=.3):
    box('Recessed inventory panel', (x, y, z), (width, .09, .009), dark, bevel=0)
    for i, length in enumerate((.055, .024, .085)):
        box('Stencilled serial', (x - width*.3 + i*width*.27, y, z+.006),
            (length, .045, .006), white, bevel=0)


def beam_stock():
    skid()
    for i in range(3):
        x = -.26 + i*.25
        for z in (.14, .27):
            box('I-beam flange', (x, 0, z), (.18, .73, .035), steel)
        box('Oxidized web', (x, 0, .2), (.038, .73, .11), rust)
    for i in range(3):
        ring('Open stock tube', (-.22+i*.18, .06, .355), .074, .05,
             .55-i*.07, steel, 'Y')
    box('Loose armor sheet', (.16, -.15, .32), (.3, .37, .045), paint, -.2)
    plate_marks(.17, -.16, .35, .2)
    for y in (-.17, .19):
        box('Steel binding', (-.09, y, .435), (.53, .027, .013), dark)


def armor_wreck():
    box('Sheared undercarriage', (0, 0, .07), (.68, .64, .12), rust, .08)
    box('Salvage armor housing', (0, .035, .23), (.62, .61, .28), paint, bevel=.045)
    box('Exposed engine cavity', (0, .035, .378), (.48, .43, .025), dark, bevel=.018)
    ring('Broken turret bearing', (0, .055, .408), .238, .176, .055, steel)
    cylinder('Exposed shaft', (0, .055, .36), .075, .075, rust)
    for x in (-.33, .33):
        for y in (-.2, 0, .2):
            cylinder('Recovered running gear', (x, y, .16), .105, .07, dark, 'X')
            cylinder('Wheel hub', (x*1.1, y, .16), .04, .016, steel, 'X')
    box('Detached armor', (.2, -.29, .13), (.3, .25, .055), paint, -.28)
    plate_marks(.16, -.28, .163, .2)
    for x in (-.22, .22):
        box('Chipped paint', (x, -.13, .378), (.035, .18, .01), steel, .12, 0)
    for i in range(3):
        box('Broken grille slat', (-.13+i*.105, -.279, .27), (.05, .025, .12), dark)


def steel_coil():
    skid()
    # A broad hollow roll gives this deposit a circular silhouette from tactical zoom.
    ring('Rolled sheet steel', (-.06, .055, .34), .255, .125, .43, steel, 'Y')
    for y in (-.16, .27):
        ring('Oxidized coil edge', (-.06, y, .34), .26, .125, .019, rust, 'Y')
        ring('Exposed fresh cut', (-.06, y*1.015, .34), .238, .23, .021, white, 'Y')
    for x in (-.21, .09):
        box('Coil cradle', (x, .05, .14), (.11, .57, .14), paint)
    for z in (.13, .18, .23):
        box('Stacked armor plate', (.24, -.19, z), (.25, .31, .034), steel, -.1)
    box('Stock tag', (.24, -.19, .257), (.19, .16, .018), paint, -.1)
    plate_marks(.24, -.19, .271, .16)


def server_cache():
    skid()
    box('Weatherproof data cabinet', (-.15, .03, .34), (.38, .39, .5), white, bevel=.025)
    box('Open server bay', (-.15, -.178, .34), (.31, .028, .4), dark)
    for i in range(4):
        z = .19 + i*.09
        box('Recoverable cartridge', (-.15, -.202, z), (.26, .029, .062), steel)
        box('Module identification', (-.21, -.221, z), (.08, .008, .024), cyan, bevel=0)
        box('Release catch', (-.045, -.223, z), (.015, .01, .032), white, bevel=0)
    box('Cabinet ceramic cap', (-.15, .03, .605), (.4, .42, .035), dark)
    box('Cyan recovery band', (-.15, .03, .628), (.2, .33, .013), cyan)
    # Random map rotations must still read as electronics from the rear and sides.
    box('Rear service panel', (-.15, .235, .35), (.3, .02, .34), steel)
    for z in (.23, .28, .33, .38, .43):
        box('Rear ventilation slot', (-.15, .25, z), (.23, .012, .017), dark, bevel=0)
    for x in (-.348, .048):
        box('Side recovery stripe', (x, .03, .49), (.014, .32, .042), cyan, bevel=0)
    box('Detached electronics case', (.22, -.08, .19), (.26, .42, .23), dark, .1)
    box('Case cover', (.22, -.08, .31), (.27, .43, .032), cyan, .1)
    plate_marks(.21, -.08, .33, .2)
    for y in (-.22, .24):
        box('Impact rail', (-.15, y, .35), (.43, .035, .5), steel)
    box('Removed access panel', (.21, .24, .13), (.29, .23, .04), white, .3)


def relay_wreck():
    box('Relay mounting foot', (0, 0, .06), (.64, .6, .1), steel, bevel=.03)
    box('Open transmitter housing', (-.12, .015, .23), (.4, .42, .27), dark)
    box('Recoverable radio module', (-.12, .015, .374), (.32, .35, .018), cyan)
    for x in (-.23, -.13, -.03):
        box('Cooling fin', (x, .015, .405), (.022, .28, .043), steel, bevel=0)
    cylinder('Broken antenna support', (.13, .12, .38), .048, .53, steel)
    # Dish is a faceted hollow bowl, not a generic crystal or a tall obstruction.
    dish = ring('Relay dish rim', (.1, .1, .635), .25, .2, .05, white)
    dish.rotation_euler.x = .27
    cylinder('Reflector center', (.1, .1, .606), .19, .023, dark)
    cylinder('Receiver', (.1, .1, .665), .055, .075, cyan)
    box('Loose circuit board', (.18, -.24, .18), (.32, .22, .025), cyan, -.24)
    box('Shielded processor', (.18, -.24, .202), (.11, .08, .023), dark, -.24)
    for i in range(4):
        box('Circuit connector', (.07+i*.055, -.33, .2), (.025, .026, .02), white, bevel=0)


def capacitor_pack():
    box('Broken power-module tray', (0, 0, .06), (.73, .62, .09), dark)
    for x in (-.21, 0, .21):
        cylinder('Capacitor casing', (x, .075, .3), .09, .39, steel)
        cylinder('Cyan ceramic collar', (x, .075, .48), .095, .065, cyan)
        cylinder('Terminal insulator', (x, .075, .533), .047, .04, dark)
        cylinder('Exposed terminal', (x, .075, .56), .022, .035, white)
    for z in (.19, .38):
        box('Protective cross-strap', (0, -.029, z), (.64, .03, .04), dark)
    box('Control board', (0, -.23, .16), (.56, .18, .045), cyan)
    for x in (-.15, 0, .15):
        box('Control processor', (x, -.23, .199), (.07, .085, .027), dark)
    for x in (-.35, .35):
        box('Broken cage upright', (x, .13, .26), (.035, .32, .39), white)
    box('Torn cover', (.14, .25, .18), (.38, .17, .04), white, .21)


manifest = []
for kind, builders in [('materials', (beam_stock, armor_wreck, steel_coil)),
                       ('electronics', (server_cache, relay_wreck, capacitor_pack))]:
    for variant, builder in enumerate(builders):
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete(use_global=False)
        builder()
        bpy.ops.object.select_all(action='SELECT')
        bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = f'{kind}_{variant}'
        bpy.context.scene.cursor.location = (0, 0, 0)
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        # Check actual vertices, including bevels and rotated parts, not nominal sizes.
        radius = max(math.hypot(v.co.x, v.co.y) for v in obj.data.vertices)
        if radius > .565:
            scale = .565 / radius
            for vertex in obj.data.vertices:
                vertex.co.x *= scale
                vertex.co.y *= scale
        radius = max(math.hypot(v.co.x, v.co.y) for v in obj.data.vertices)
        obj.data.calc_loop_triangles()
        triangles = len(obj.data.loop_triangles)
        assert radius < .6 and triangles < 3000
        path = OUT / f'{kind}_{variant}.glb'
        bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / f'art/resources/{kind}_{variant}.blend'))
        manifest.append(dict(asset=path.name, design=builder.__name__, triangles=triangles,
                             surfaces=len(set(p.material_index for p in obj.data.polygons)),
                             radius=round(radius, 4),
                             height=round(max(v.co.z for v in obj.data.vertices), 4),
                             bytes=path.stat().st_size))
(ROOT / 'art/resources/manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Built six distinct neutral salvage assets; footprint and triangle budgets verified')
