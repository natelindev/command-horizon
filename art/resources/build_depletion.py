"""Build distinct opened, scattered, and remnant salvage models (not scaled copies).
Run: Blender --background --factory-startup --python-exit-code 1 --python art/resources/build_depletion.py
Uses the full deposits' palette and primitive helpers; all geometry fits the 0.6 m footprint.
"""
import json
import math
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_resources import ROOT, OUT, box, cylinder, ring, skid, plate_marks
from build_resources import steel, rust, dark, paint, white, cyan


def materials_opened():
    skid()
    # The intact equipment has been stripped down to unbound beam stock and plates.
    for i in range(3):
        x = -.22 + i * .21
        for z in (.13, .29):
            box('Unbound beam flange', (x, .02, z), (.17, .62, .035), steel)
        box('Exposed beam web', (x, .02, .21), (.035, .62, .14), rust)
    ring('Loose hollow tube', (-.1, .03, .395), .085, .055, .47, steel, 'Y')
    for i in range(3):
        box('Separated armor plate', (.17, -.14, .33 + i * .038), (.3, .33, .028),
            paint if i == 2 else steel, -.18 + i * .07)
    plate_marks(.17, -.14, .425, .2)
    box('Cut retaining strap', (-.29, -.28, .06), (.12, .3, .025), dark, -.4)


def materials_scattered():
    # No intact machine or pallet: a low fan of loose plates and a short stock tube.
    for i, angle in enumerate((-.32, -.05, .22)):
        box('Loose metal plate', (-.06 + i * .055, -.05, .035 + i * .035),
            (.43, .37, .03), paint if i == 2 else steel, angle)
    ring('Short pipe offcut', (.21, .17, .1), .095, .06, .24, rust, 'Y')
    box('Sheared beam', (-.25, .17, .055), (.08, .28, .09), steel, -.28)
    plate_marks(.05, -.04, .13, .2)


def materials_remnants():
    box('Final armor offcut', (-.04, -.025, .025), (.26, .23, .045), paint, -.3)
    box('Bare metal edge', (-.04, -.025, .051), (.18, .035, .008), steel, -.3, 0)
    box('Last bent strip', (.15, .065, .025), (.055, .19, .035), steel, .5)
    cylinder('Last stock fragment', (-.13, .15, .04), .035, .1, rust, 'Y', 8)


def board(name, x, y, z, angle=0):
    box(name, (x, y, z), (.27, .21, .025), cyan, angle)
    box('Recoverable processor', (x, y, z + .03), (.09, .085, .035), dark, angle)
    for i in range(4):
        box('Board edge contact', (x - .09 + i * .055, y - .09, z + .017),
            (.025, .025, .01), white, angle, 0)


def electronics_opened():
    # Cabinet walls remain, but the roof and most cartridges have been removed.
    box('Opened cabinet base', (0, .04, .055), (.64, .5, .09), dark)
    for x in (-.29, .29):
        box('Stripped cabinet side', (x, .07, .25), (.045, .44, .38), white)
        box('Remaining recovery stripe', (x, .07, .36), (.05, .31, .04), cyan)
    box('Open cabinet back', (0, .27, .25), (.57, .035, .38), steel)
    box('Empty cartridge shelf', (0, .05, .24), (.54, .38, .025), dark)
    board('Exposed circuit tray', -.09, -.055, .12)
    cylinder('Remaining capacitor', (.17, .11, .16), .065, .16, steel)
    cylinder('Capacitor collar', (.17, .11, .25), .068, .035, cyan)
    board('Removed circuit tray', .08, -.3, .045, -.12)


def electronics_scattered():
    box('Discarded chassis floor', (0, .035, .03), (.56, .43, .04), dark, -.1)
    board('Loose circuit board', -.15, .08, .07, -.18)
    board('Loose processor card', .12, -.13, .065, .22)
    for x in (.12, .24):
        cylinder('Recovered capacitor', (x, .19, .1), .045, .15, steel)
        cylinder('Cyan collar', (x, .19, .18), .047, .025, cyan)
    box('Detached socket rail', (-.23, -.21, .045), (.12, .1, .04), white, -.3)


def electronics_remnants():
    board('Last recoverable board', -.025, -.025, .025, -.15)
    cylinder('Last capacitor', (.17, .12, .045), .035, .075, steel)
    cylinder('Last ceramic cap', (.17, .12, .09), .037, .02, cyan)


manifest = []
for kind, builders in [('materials', (materials_remnants, materials_scattered, materials_opened)),
                       ('electronics', (electronics_remnants, electronics_scattered, electronics_opened))]:
    for stage, builder in enumerate(builders):
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete(use_global=False)
        builder()
        bpy.ops.object.select_all(action='SELECT')
        bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = f'{kind}_depleted_{stage}'
        bpy.context.scene.cursor.location = (0, 0, 0)
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        radius = max(math.hypot(v.co.x, v.co.y) for v in obj.data.vertices)
        obj.data.calc_loop_triangles()
        triangles = len(obj.data.loop_triangles)
        assert radius < .6 and triangles < 2000, (obj.name, radius, triangles)
        path = OUT / f'{obj.name}.glb'
        bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True)
        manifest.append(dict(asset=path.name, design=builder.__name__, triangles=triangles,
                             radius=round(radius, 4),
                             height=round(max(v.co.z for v in obj.data.vertices), 4)))
(ROOT / 'art/resources/depletion_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Built six distinct depletion models; footprint and triangle budgets verified')
