"""Build the Bastion tank in Blender background mode.

Run from any directory:
  blender --background --factory-startup --python-exit-code 1 --python /path/to/build.py

Outputs are deliberately scoped to this asset's versioned source directory and
assets/models/bastion/tank-v1. Re-running rebuilds this generated version.
The editable .blend retains individual components; the GLB joins rigid parts.
Append -- --export-only to rebuild the articulated source GLB without studio renders.
"""

import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "art/common"))
import track_rig

EXPORT = ROOT / "assets/models/bastion/tank-v1"
EXPORT.mkdir(parents=True, exist_ok=True)
RENDERS = HERE / "renders"
RENDERS.mkdir(exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    if not collection.objects:
        bpy.data.collections.remove(collection)

scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
source = bpy.data.collections.new("SOURCE — editable components")
scene.collection.children.link(source)
studio = bpy.data.collections.new("STUDIO — excluded from export")
scene.collection.children.link(studio)
parts = {"Hull": [], "Turret": [], "Barrel": [], "TrackLeft": [], "TrackRight": [], "AntennaLeft": [], "AntennaRight": []}


def material(name, color, metallic=0.25, roughness=0.48, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission:
        shader.inputs["Emission Color"].default_value = (*color, 1)
        shader.inputs["Emission Strength"].default_value = emission
    return mat


armor = material("Armor / olive graphite", (0.065, 0.076, 0.064))
edge = material("Armor / raised panels", (0.105, 0.12, 0.098))
dark = material("Mechanisms / dark steel", (0.025, 0.033, 0.034), 0.65, 0.38)
steel = material("Hardware / brushed steel", (0.285, 0.32, 0.32), 0.8, 0.35)
rubber = material("Tracks / rubber", (0.025, 0.032, 0.032), 0.0, 0.8)
yellow = material("TeamColor / Bastion ochre", (0.65, 0.28, 0.015), 0.2, 0.43)
ivory = material("Markings / ivory", (0.8, 0.79, 0.66), 0.05, 0.62)
glass = material("Optics / ice cyan", (0.12, 0.69, 0.83), 0.35, 0.22, 0.6)
lamp = material("Lamps / warm white", (0.94, 0.85, 0.57), 0.1, 0.22, 1.0)
red = material("Lamps / rear red", (0.58, 0.045, 0.025), 0.05, 0.35, 0.3)


def move_collection(obj, collection):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)


def finish(obj, name, mat, group="Hull", bevel=0.0, smooth=False):
    obj.name = name
    move_collection(obj, source if group else studio)
    if mat:
        obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Manufactured edge chamfer", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        modifier.affect = "EDGES"
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    if bevel or smooth:
        normal = obj.modifiers.new("Weighted surface normals", "WEIGHTED_NORMAL")
        normal.keep_sharp = True
        normal.weight = 50
    if group:
        parts[group].append(obj)
    return obj


def box(name, loc, dims, mat, group="Hull", bevel=0.025, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.scale = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        obj.rotation_euler = rotation
    return finish(obj, name, mat, group, bevel)


def mesh(name, verts, faces, mat, group="Hull", bevel=0.0):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    source.objects.link(obj)
    # Recalculate outward normals for arbitrary ring and profile topology.
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    return finish(obj, name, mat, group, bevel)


def cylinder(name, loc, radius, depth, mat, group="Hull", axis="Z", vertices=16, bevel=0.015):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    if axis == "X":
        obj.rotation_euler[1] = math.pi / 2
    elif axis == "Y":
        obj.rotation_euler[0] = math.pi / 2
    return finish(obj, name, mat, group, bevel)


def footprint(width, length, cut=0.22, cy=0.0):
    x, y = width / 2, length / 2
    return [(-x + cut, -y + cy), (x - cut, -y + cy),
            (x, -y + cut + cy), (x, y - cut + cy),
            (x - cut, y + cy), (-x + cut, y + cy),
            (-x, y - cut + cy), (-x, -y + cut + cy)]


def layered(name, rings, mat, group="Hull", bevel=0.02):
    verts = [(x, y, z) for z, points in rings for x, y in points]
    n = len(rings[0][1])
    faces = [tuple(reversed(range(n)))]
    for layer in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            faces.append((layer*n+i, layer*n+j, (layer+1)*n+j, (layer+1)*n+i))
    faces.append(tuple(range((len(rings)-1)*n, len(rings)*n)))
    return mesh(name, verts, faces, mat, group, bevel)


def rod(name, start, end, radius, mat, group="Hull", vertices=8):
    delta = Vector(end) - Vector(start)
    obj = cylinder(name, (Vector(start) + Vector(end))/2, radius, delta.length,
                   mat, group, vertices=vertices, bevel=0)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return obj


def chevron_side(name, x, y, z, scale=0.5, mat=yellow, group="Hull"):
    # Filled V-shaped marking in the side plane, facing outwards.
    yz = [(-.55, .35), (0, -.07), (.55, .35), (.55, .08), (0, -.35), (-.55, .08)]
    return mesh(name, [(x, y+a*scale, z+b*scale) for a,b in yz],
                [(0,1,2,3,4,5)], mat, group)


def capsule(distance, radius=0.64, half=2.02, center_z=0.73):
    """Point and tangent on a vertical track loop, with equal-distance sampling."""
    straight = 2 * half
    arc = math.pi * radius
    perimeter = 2 * straight + 2 * arc
    s = distance % perimeter
    if s < straight:
        return -half+s, center_z+radius, 1.0, 0.0
    s -= straight
    if s < arc:
        a = math.pi/2-s/radius
        return half+radius*math.cos(a), center_z+radius*math.sin(a), math.sin(a), -math.cos(a)
    s -= arc
    if s < straight:
        return half-s, center_z-radius, -1.0, 0.0
    s -= straight
    a = -math.pi/2-s/radius
    return -half+radius*math.cos(a), center_z+radius*math.sin(a), math.sin(a), -math.cos(a)


def track_belt(side):
    x = side * 1.66
    group = "TrackLeft" if side < 0 else "TrackRight"
    steps = 64
    perimeter = 8.08 + 2*math.pi*.64
    verts = []
    # Cross-section ring edges: outer/inner surfaces at both X ends.
    for radial in (0.64, 0.52):
        p = 8.08 + 2*math.pi*radial
        for xx in (x-.42, x+.42):
            for i in range(steps):
                y,z,_,_ = capsule(p*i/steps, radius=radial)
                verts.append((xx,y,z))
    faces=[]
    for a,b in ((0,1),(1,3),(3,2),(2,0)):
        for i in range(steps):
            j=(i+1)%steps
            faces.append((a*steps+i,a*steps+j,b*steps+j,b*steps+i))
    mesh(f"Track {side} / continuous belt", verts, faces, rubber)
    count=52
    for i in range(count):
        y,z,ty,tz=capsule(perimeter*i/count)
        angle=math.atan2(tz,ty)
        # Local Z is outward when following the loop clockwise in Y/Z.
        shoe = box(f"Track {side} / shoe {i:02}", (x,y,z), (.9,.205,.11), dark,
            group=group, bevel=0, rotation=(angle,0,0))
        track_rig.encode(shoe, perimeter*i/count, 2.02, .64, .73)
        normal=Vector((0,-tz,ty))
        pos=Vector((x,y,z))+normal*.065
        pad = box(f"Track {side} / traction pad {i:02}", pos, (.62,.145,.035), rubber,
            group=group, bevel=0, rotation=(angle,0,0))
        track_rig.encode(pad, perimeter*i/count, 2.02, .64, .73)
    for i,y in enumerate((-2.02,-1.34,-.67,0,.67,1.34,2.02)):
        radius=.47 if i in (0,6) else .43
        cylinder(f"Track {side} / road wheel {i}",(x,y,.73),radius,.7,rubber,axis="X",vertices=16,bevel=0)
        cylinder(f"Track {side} / wheel face {i}",(x+side*.365,y,.73),radius*.77,.065,edge,axis="X",vertices=12,bevel=0)
        cylinder(f"Track {side} / hub {i}",(x+side*.41,y,.73),.125,.085,steel,axis="X",vertices=8,bevel=0)


# Hull: a deliberately broad, sloping chassis rather than stacked cubes.
layered("Hull / lower armored tub", [(.36,footprint(2.55,4.75,.35)),
        (.88,footprint(3.02,5.22,.34)),(1.10,footprint(3.18,5.48,.3))],armor)
layered("Hull / sloped upper glacis",[(1.02,footprint(3.44,5.48,.25)),
        (1.49,footprint(3.12,4.65,.28,cy=-.18))],edge)
layered("Hull / inset roof armor",[(1.485,footprint(2.98,4.28,.27,cy=-.25)),
        (1.54,footprint(2.86,4.16,.24,cy=-.25))],armor,bevel=.015)

for side in (-1,1):
    track_belt(side)
    box(f"Fender {side}",(side*1.70,-.03,1.42),(.94,5.46,.16),armor,bevel=.065)
    # Layered segmented side skirts leave road wheels and the curved track ends visible.
    for i,y in enumerate((-1.85,-.94,-.03,.88,1.79)):
        plate=box(f"Skirt {side} / panel {i}",(side*2.08,y,1.02),(.17,.86,.66),
                  yellow if i==3 else armor,bevel=.05)
        for zz in (.79,1.25):
            cylinder(f"Skirt {side} / latch {i} {zz}",(side*2.175,y-.26,zz),.04,.025,steel,axis="X",vertices=6,bevel=0)
        if i==1:
            chevron_side(f"Skirt {side} / insignia",side*2.171,y,1.02,.55,ivory)
    box(f"Front fender {side} / bumper",(side*1.7,2.62,1.25),(.92,.20,.28),dark,bevel=.05)
    box(f"Front fender {side} / team panel",(side*1.71,2.12,1.515),(.75,.69,.025),yellow,bevel=.025)
    box(f"Headlamp {side} / armored housing",(side*1.68,2.77,1.29),(.4,.2,.24),dark,bevel=.035)
    box(f"Headlamp {side} / lens",(side*1.68,2.877,1.30),(.25,.02,.105),lamp,bevel=.012)
    # Rear exhausts and taillights.
    box(f"Exhaust {side} / housing",(side*.98,-2.43,1.27),(.72,.22,.27),dark,bevel=.025)
    for j in range(4):
        box(f"Exhaust {side} / fin {j}",(side*.98,-2.557,1.18+j*.06),(.62,.045,.024),steel,bevel=0)
    box(f"Taillight {side}",(side*1.72,-2.783,1.4),(.2,.035,.075),red,bevel=.012)
    # Forward tow loops in three solid pieces.
    for offset in (-.11,.11):
        box(f"Tow lug {side} {offset}",(side*.8+offset,2.47,.73),(.07,.28,.10),steel,bevel=.02)
    rod(f"Tow crossbar {side}",(side*.8-.11,2.58,.73),(side*.8+.11,2.58,.73),.045,steel)

# Rear engine bay, cooling grilles, maintenance lids and front driver periscope.
for side in (-1,1):
    box(f"Engine grille {side} / recess",(side*.77,-1.64,1.558),(.95,1.12,.045),dark,bevel=.025)
    for i in range(9):
        box(f"Engine grille {side} / slat {i}",(side*.77,-2.08+i*.11,1.591),(.82,.036,.045),steel,bevel=.005)
    box(f"Engine hatch {side}",(side*1.49,-1.66,1.535),(.32,1.13,.085),edge,bevel=.02)
    for yy in (-2.08,-1.2):
        box(f"Engine hinge {side} {yy}",(side*1.49,yy,1.598),(.25,.09,.035),steel,bevel=.005)
box("Driver / hatch",(0,1.6,1.565),(.85,.62,.08),armor,bevel=.08)
box("Driver / periscope",(0,1.87,1.654),(.52,.16,.17),dark,bevel=.018)
box("Driver / glass",(0,1.96,1.668),(.38,.022,.085),glass,bevel=.01)
for side in (-1,1):
    box(f"Glacis {side} / inset composite panel",(side*.67,2.26,1.40),(.84,.72,.045),
        armor,bevel=.025,rotation=(math.radians(-35),0,0))
for side in (-1,1):
    rod(f"Rear handrail {side} A",(side*1.40,-2.21,1.55),(side*1.40,-2.21,1.69),.022,steel)
    rod(f"Rear handrail {side} B",(side*1.40,-1.85,1.55),(side*1.40,-1.85,1.69),.022,steel)
    rod(f"Rear handrail {side} C",(side*1.40,-2.21,1.69),(side*1.40,-1.85,1.69),.022,steel)

# Turret yaw pivot at the center of the ring; barrel elevation at the mantlet.
TURRET_PIVOT = Vector((0,.1,1.61))
BARREL_PIVOT = Vector((0,1.11,2.04))
MUZZLE = Vector((0,5.06,2.04))
cylinder("Turret / bearing ring",(0,.1,1.57),1.10,.19,dark,"Turret",vertices=32)
cylinder("Turret / bearing lip",(0,.1,1.675),1.15,.07,steel,"Turret",vertices=32)
layered("Turret / main casting",[(1.66,footprint(2.75,2.83,.55,cy=.02)),
        (2.19,footprint(2.55,2.59,.53,cy=-.07)),
        (2.31,footprint(2.08,2.13,.42,cy=-.12))],armor,"Turret",.035)
for side in (-1,1):
    # Cheek armor follows the front wedge and avoids a uniformly box-like turret.
    lower=[(side*.48,1.29),(side*1.03,1.04),(side*1.46,.57),(side*1.39,-.10),
           (side*1.22,-.36),(side*.95,.22)]
    upper=[(x*.93,y-.035) for x,y in lower]
    layered(f"Turret {side} / composite cheek",[(1.79,lower),(2.19,upper)],edge,"Turret",.025)
    box(f"Turret {side} / side module",(side*1.31,-.49,2.01),(.24,.78,.38),armor,"Turret",.04)
    chevron_side(f"Turret {side} / faction mark",side*1.442,-.49,2.03,.45,yellow,"Turret")
    box(f"Turret {side} / rear stowage",(side*.82,-1.31,2.01),(.79,.49,.44),edge,"Turret",.05)
    box(f"Turret {side} / stowage latch",(side*.82,-1.571,2.03),(.15,.025,.17),steel,"Turret",.015)
    # Discrete smoke-launcher cluster.
    for j in range(3):
        obj=cylinder(f"Turret {side} / smoke tube {j}",(side*1.32,.08-j*.17,2.24),.065,.27,dark,"Turret",vertices=8,bevel=.01)
        obj.rotation_euler=(0,side*math.radians(34),0)
    cylinder(f"Antenna {side} / mount",(side*.92,-.98,2.31),.08,.13,dark,"Turret",vertices=8)
    rod(f"Antenna {side} / mast",(side*.92,-.98,2.36),(side*.92,-1.025,3.21 if side==1 else 2.93),.012,dark,"AntennaLeft" if side < 0 else "AntennaRight",6)

cylinder("Commander / cupola",(-.51,-.33,2.35),.39,.15,dark,"Turret",vertices=16)
cylinder("Commander / hatch",(-.51,-.33,2.445),.33,.055,edge,"Turret",vertices=16)
box("Commander / grab handle",(-.51,-.35,2.493),(.2,.035,.045),steel,"Turret",.01)
box("Optics / rotating plinth",(.49,-.02,2.36),(.50,.48,.13),dark,"Turret",.04)
box("Optics / armored head",(.49,.01,2.58),(.57,.43,.33),edge,"Turret",.055)
for x,r in ((.34,.09),(.64,.066)):
    cylinder(f"Optics / bezel {x}",(x,.242,2.60),r+.032,.055,dark,"Turret",axis="Y",vertices=12)
    cylinder(f"Optics / lens {x}",(x,.276,2.60),r,.012,glass,"Turret",axis="Y",vertices=12,bevel=0)
box("Turret / retrofit interface",(.65,-.78,2.32),(.40,.37,.07),dark,"Turret",.025)
box("Turret / removable chip cover",(.65,-.78,2.365),(.29,.28,.025),yellow,"Turret",.02)
box("Turret / chip status",(.65,-.81,2.383),(.16,.025,.009),glass,"Turret",.003)

# Gun base and visible trunnions, all below the elevation pivot.
box("Gun / mantlet",(0,1.19,2.04),(.88,.56,.57),dark,"Barrel",.10)
for side in (-1,1):
    cylinder(f"Gun / trunnion {side}",(side*.47,1.11,2.04),.23,.075,steel,"Barrel",axis="X",vertices=12)
    cylinder(f"Gun / cap {side}",(side*.52,1.11,2.04),.17,.045,armor,"Barrel",axis="X",vertices=12)
box("Gun / recoil shroud",(0,1.75,2.04),(.48,.92,.43),edge,"Barrel",.065)
box("Gun / team band",(0,2.00,2.04),(.491,.20,.441),yellow,"Barrel",.045)
cylinder("Gun / barrel",(0,3.26,2.04),.132,2.30,dark,"Barrel",axis="Y",vertices=12,bevel=.01)
for y in (2.31,3.20,4.04):
    cylinder(f"Gun / sleeve {y}",(0,y,2.04),.158,.15,steel,"Barrel",axis="Y",vertices=12)
box("Gun / upper barrel spine",(0,3.16,2.172),(.14,1.92,.052),armor,"Barrel",.016)

# Hollow polygonal muzzle brake: a real opening, not a capped primitive.
outer=[(-.17,-.22),(.17,-.22),(.26,-.13),(.26,.13),(.17,.22),(-.17,.22),(-.26,.13),(-.26,-.13)]
inner=[(x*.54,z*.54) for x,z in outer]
verts=[]
for y,ring in ((4.29,outer),(5.04,outer),(5.045,inner),(4.63,inner)):
    verts += [(x,y,z+2.04) for x,z in ring]
faces=[]
for a,b in ((0,1),(1,2),(2,3)):
    for i in range(8):
        j=(i+1)%8
        faces.append((a*8+i,a*8+j,b*8+j,b*8+i))
faces += [tuple(range(24,32)),tuple(reversed(range(8)))]
mesh("Gun / hollow muzzle brake",verts,faces,armor,"Barrel",.008)
for side in (-1,1):
    for j in range(3):
        box(f"Gun / brake port {side} {j}",(side*.265,4.45+j*.17,2.04),(.007,.09,.14),dark,"Barrel",.008)
box("Gun / muzzle team plate",(0,4.78,2.267),(.29,.27,.014),yellow,"Barrel",.012)

# Preserve the component-level model and add animation-ready pivots.
def empty(name, loc, collection):
    obj=bpy.data.objects.new(name,None)
    collection.objects.link(obj)
    obj.location=loc
    obj.empty_display_type="PLAIN_AXES"
    obj.empty_display_size=.25
    return obj


def parent_keep_world(obj,parent):
    world=obj.matrix_world.copy()
    obj.parent=parent
    obj.matrix_world=world


bpy.context.view_layer.update()
root=empty("BastionTank",(0,0,0),source)
root["asset_version"]="1.0-review"
root["forward_blender"]="+Y"
root["forward_godot"]="-Z"
root["unit"]="meter"
root["reference"]="docs/concept-art/bastion/v1/02-ground-unit-designs-v1.png"
turret=empty("TurretPivot",TURRET_PIVOT,source)
barrel=empty("BarrelPivot",BARREL_PIVOT,source)
muzzle=empty("Muzzle",MUZZLE,source)
bpy.context.view_layer.update()
parent_keep_world(turret,root)
parent_keep_world(barrel,turret)
parent_keep_world(muzzle,barrel)
source_groups = [("Hull",root),("Turret",turret),("Barrel",barrel)]
for side, label in [(-1,"Left"),(1,"Right")]:
    track = empty("SourceTrackPivot"+label,(0,0,0),source)
    parent_keep_world(track,root)
    source_groups.append(("Track"+label,track))
    antenna = empty("SourceAntennaPivot"+label,(side*.92,-.98,2.36),source)
    parent_keep_world(antenna,turret)
    source_groups.append(("Antenna"+label,antenna))
for group,parent in source_groups:
    for obj in parts[group]:
        parent_keep_world(obj,parent)

# Export an evaluated and consolidated duplicate, preserving the source parts.
export_collection=bpy.data.collections.new("EXPORT — consolidated rigid meshes")
scene.collection.children.link(export_collection)
eroot=empty("BastionTankExport",(0,0,0),export_collection)
for key in root.keys():
    eroot[key]=root[key]
et=empty("TurretPivotExport",TURRET_PIVOT,export_collection)
eb=empty("BarrelPivotExport",BARREL_PIVOT,export_collection)
em=empty("MuzzleExport",MUZZLE,export_collection)
bpy.context.view_layer.update()
parent_keep_world(et,eroot)
parent_keep_world(eb,et)
parent_keep_world(em,eb)
depsgraph=bpy.context.evaluated_depsgraph_get()
stats={}
export_groups = [("Hull",eroot),("Turret",et),("Barrel",eb)]
for side, label in [(-1,"Left"),(1,"Right")]:
    track = empty("TrackPivot"+label,(0,0,0),export_collection)
    parent_keep_world(track,eroot)
    export_groups.append(("Track"+label,track))
    antenna = empty("AntennaPivot"+label,(side*.92,-.98,2.36),export_collection)
    parent_keep_world(antenna,et)
    export_groups.append(("Antenna"+label,antenna))
for group,pivot in export_groups:
    duplicates=[]
    for obj in parts[group]:
        data=bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph),depsgraph=depsgraph)
        duplicate=bpy.data.objects.new("export-part",data)
        export_collection.objects.link(duplicate)
        duplicate.matrix_world=obj.matrix_world.copy()
        duplicates.append(duplicate)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in duplicates:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=duplicates[0]
    bpy.ops.object.join()
    joined=bpy.context.object
    joined.name=group+"Mesh"
    world=joined.matrix_world.copy()
    joined.data.transform(world)
    joined.matrix_world=Matrix.Identity(4)
    # Place mesh origin on the corresponding articulation pivot.
    joined.data.transform(Matrix.Translation(-pivot.matrix_world.translation))
    joined.matrix_world=Matrix.Translation(pivot.matrix_world.translation)
    parent_keep_world(joined,pivot)
    triangulate=joined.modifiers.new("Stable game triangulation","TRIANGULATE")
    bpy.context.view_layer.objects.active=joined
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    # Thin beveled details can create zero-area triangles after triangulation.
    # Remove them before export rather than relying on an engine to discard them.
    bm=bmesh.new()
    bm.from_mesh(joined.data)
    degenerate=[face for face in bm.faces if face.calc_area() <= 1e-10]
    bmesh.ops.delete(bm,geom=degenerate,context="FACES_ONLY")
    bm.to_mesh(joined.data)
    bm.free()
    joined.data.update()
    stats[group]={"triangles":len(joined.data.polygons),"vertices":len(joined.data.vertices),
                  "materials":len(joined.data.materials)}

# Temporarily give export objects clean names, then restore source names.
renames={root:"Source_BastionTank",turret:"Source_TurretPivot",barrel:"Source_BarrelPivot",muzzle:"Source_Muzzle"}
for obj,name in renames.items():
    obj.name=name
for obj,name in ((eroot,"BastionTank"),(et,"TurretPivot"),(eb,"BarrelPivot"),(em,"Muzzle")):
    obj.name=name
bpy.ops.object.select_all(action="DESELECT")
for obj in export_collection.objects:
    obj.select_set(True)
glb=EXPORT/"bastion_tank_v1.glb"
bpy.ops.export_scene.gltf(filepath=str(glb),export_format="GLB",use_selection=True,
                         export_yup=True,export_extras=True,export_animations=False,
                         export_cameras=False,export_lights=False,export_apply=True)

if "--export-only" in sys.argv:
    raise SystemExit(0)

export_collection.hide_render=True
export_collection.hide_viewport=True

# Studio is independent of the export hierarchy.
ground=material("Studio / warm graphite",(.115,.13,.145),0,.8)
box("Studio ground",(0,0,-.07),(200,200,.1),ground,group=None,bevel=0)
world=bpy.data.worlds.new("Soft studio environment")
scene.world=world
world.use_nodes=True
world.node_tree.nodes["Background"].inputs[0].default_value=(.25,.30,.39,1)
world.node_tree.nodes["Background"].inputs[1].default_value=.5


def area(name,loc,power,size,color,target=(0,0,1)):
    data=bpy.data.lights.new(name,"AREA")
    data.energy=power
    data.shape="DISK"
    data.size=size
    data.color=color
    obj=bpy.data.objects.new(name,data)
    studio.objects.link(obj)
    obj.location=loc
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()


area("Key / broad warm softbox",(3,6,11),1900,7,(1,.88,.72))
area("Fill / cool softbox",(-6,1,5),1500,6,(.68,.80,1))
area("Rim / rear softbox",(3,-6,7),2300,5,(1,.93,.8))
camera_data=bpy.data.cameras.new("Review camera")
camera=bpy.data.objects.new("Review camera",camera_data)
studio.objects.link(camera)
scene.camera=camera
camera_data.type="ORTHO"
scene.render.engine="CYCLES"
scene.cycles.samples=40
scene.cycles.use_denoising=True
scene.cycles.device="CPU"
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.render.film_transparent=False
scene.view_settings.view_transform="AgX"
scene.render.resolution_x=1400
scene.render.resolution_y=1100
bpy.context.preferences.filepaths.save_version=0


def aim(loc,target,scale):
    camera.location=loc
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat("-Z","Y").to_euler()
    camera_data.ortho_scale=scale


aim((10,13,9),(0,.8,1.05),11.4)
# Set source collection's objects selected for an easy first Blender inspection.
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
bpy.context.view_layer.objects.active=root
scene.render.filepath=str(RENDERS/"01-front-three-quarter.png")
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/"bastion_tank_v1.blend"))
bpy.ops.render.render(write_still=True)
aim((-10,-12,9),(0,.5,1),11.4)
scene.render.filepath=str(RENDERS/"02-rear-three-quarter.png")
bpy.ops.render.render(write_still=True)
aim((8,11,14),(0,.7,.8),11.6)
scene.render.filepath=str(RENDERS/"03-rts-view.png")
bpy.ops.render.render(write_still=True)

aim((8,11,14),(0,.7,.8),40)
scene.render.resolution_x=1024
scene.render.resolution_y=768
scene.render.filepath=str(RENDERS/"05-rts-scale.png")
bpy.ops.render.render(write_still=True)
scene.render.resolution_x=1400
scene.render.resolution_y=1100

# Articulation preview demonstrates the actual source pivots.
turret.rotation_euler.z=math.radians(32)
barrel.rotation_euler.x=math.radians(12)
bpy.context.view_layer.update()
aim((10,13,9),(0,.5,1.1),11.4)
scene.render.filepath=str(RENDERS/"04-articulation.png")
bpy.ops.render.render(write_still=True)
turret.rotation_euler.z=0
barrel.rotation_euler.x=0
bpy.context.view_layer.update()

bounds=[obj.matrix_world@Vector(corner) for group in parts.values() for obj in group for corner in obj.bound_box]
minimum=[min(v[i] for v in bounds) for i in range(3)]
maximum=[max(v[i] for v in bounds) for i in range(3)]
report={"asset":"Bastion tank v1", "blender":bpy.app.version_string,
        "source_components":sum(map(len,parts.values())),"rigid_meshes":stats,
        "triangles":sum(s["triangles"] for s in stats.values()),
        "bounds_blender":{"min":minimum,"max":maximum},
        "dimensions_m":[maximum[i]-minimum[i] for i in range(3)],
        "godot_forward":"-Z", "godot_up":"+Y", "glb":str(glb.relative_to(ROOT)),
        "notes":["Review asset: no movement/track animation or collision included.",
                 "Solid PBR materials; no texture atlas or authored UV layout.",
                 "Separate yaw/elevation pivots and muzzle marker exported.",
                 "Source components retained; GLB joins meshes by rigid articulation."]}
(HERE/"build-report.json").write_text(json.dumps(report,indent=2)+"\n")
print("Bastion tank build complete:",json.dumps({"triangles":report["triangles"],"glb":report["glb"]}))
