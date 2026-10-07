"""Verify the exported GLB by parsing it and reimporting it into Blender.

blender --background --factory-startup --python-exit-code 1 --python /path/to/verify.py
"""

import json
import math
from pathlib import Path
import struct

import bpy
from mathutils import Vector


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ASSET = ROOT / "assets/models/bastion/tank-v1/bastion_tank_v1.glb"
build = json.loads((HERE / "build-report.json").read_text())
data = ASSET.read_bytes()
magic, version, length = struct.unpack_from("<4sII", data)
assert magic == b"glTF" and version == 2 and length == len(data)
chunk_length, chunk_type = struct.unpack_from("<II", data, 12)
assert chunk_type == 0x4E4F534A
gltf = json.loads(data[20:20 + chunk_length])
assert len(gltf["meshes"]) == 3, "Expected three rigid meshes"
assert not gltf.get("images"), "Asset must not depend on external textures"
assert not gltf.get("cameras") and not gltf.get("animations")
assert all("uri" not in buffer for buffer in gltf.get("buffers", []))
nodes = {node["name"]: (i, node) for i, node in enumerate(gltf["nodes"])}
for name in ("BastionTank", "TurretPivot", "BarrelPivot", "Muzzle", "HullMesh", "TurretMesh", "BarrelMesh"):
    assert name in nodes, name
for parent, child in (("BastionTank", "TurretPivot"), ("TurretPivot", "BarrelPivot"),
                      ("BarrelPivot", "Muzzle"), ("BastionTank", "HullMesh"),
                      ("TurretPivot", "TurretMesh"), ("BarrelPivot", "BarrelMesh")):
    assert nodes[child][0] in nodes[parent][1].get("children", []), (parent, child)

primitive_count = sum(len(mesh["primitives"]) for mesh in gltf["meshes"])
triangles = sum(gltf["accessors"][primitive["indices"]]["count"] // 3
                for mesh in gltf["meshes"] for primitive in mesh["primitives"])
assert triangles == build["triangles"]

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ASSET))
bpy.context.view_layer.update()
mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
assert len(mesh_objects) == 3
for obj in mesh_objects:
    assert all(math.isfinite(value) for v in obj.data.vertices for value in v.co)
    obj.data.calc_loop_triangles()
    assert all(tri.area > 1e-10 for tri in obj.data.loop_triangles), obj.name

points = [obj.matrix_world @ Vector(corner) for obj in mesh_objects for corner in obj.bound_box]
actual_min = [min(point[i] for point in points) for i in range(3)]
actual_max = [max(point[i] for point in points) for i in range(3)]
for actual, expected in ((actual_min, build["bounds_blender"]["min"]),
                          (actual_max, build["bounds_blender"]["max"])):
    assert max(abs(a-b) for a,b in zip(actual,expected)) < .035, (actual, expected)

turret = bpy.data.objects["TurretPivot"]
barrel = bpy.data.objects["BarrelPivot"]
muzzle = bpy.data.objects["Muzzle"]
hull = bpy.data.objects["HullMesh"]
# The glTF importer uses quaternion rotation mode. Switch before testing Euler
# controls; otherwise assigning rotation_euler leaves the active rotation intact.
turret.rotation_mode = "XYZ"
barrel.rotation_mode = "XYZ"
turret_rotation = turret.rotation_euler.copy()
barrel_rotation = barrel.rotation_euler.copy()
hull_world = hull.matrix_world.copy()
turret_center = turret.matrix_world.translation.copy()
muzzle_initial = muzzle.matrix_world.translation.copy()
reach = (muzzle_initial - barrel.matrix_world.translation).length
assert reach > 3
assert muzzle_initial.y > actual_max[1] - .10, "Muzzle should be at the forward cannon tip"
turret.rotation_euler.z += math.radians(45)
bpy.context.view_layer.update()
assert (muzzle.matrix_world.translation - muzzle_initial).length > 1
assert (turret.matrix_world.translation - turret_center).length < 1e-5
barrel.rotation_euler.x += math.radians(15)
bpy.context.view_layer.update()
assert abs((muzzle.matrix_world.translation-barrel.matrix_world.translation).length-reach) < 1e-4
assert muzzle.matrix_world.translation.z > muzzle_initial.z + .5
assert max(abs(hull.matrix_world[i][j]-hull_world[i][j]) for i in range(4) for j in range(4)) < 1e-6

# Render the reimported asset with the same studio as the source to expose
# material, normal, hierarchy, or coordinate conversion problems visually.
turret.rotation_euler = turret_rotation
barrel.rotation_euler = barrel_rotation
with bpy.data.libraries.load(str(HERE / "bastion_tank_v1.blend"), link=False) as (available, loaded):
    loaded.collections = [name for name in available.collections if name.startswith("STUDIO")]
    loaded.worlds = ["Soft studio environment"]
for collection in loaded.collections:
    bpy.context.scene.collection.children.link(collection)
scene = bpy.context.scene
scene.camera = next(obj for obj in scene.objects if obj.type == "CAMERA")
scene.world = loaded.worlds[0]
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 1400
scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "AgX"
scene.render.filepath = str(HERE / "renders/06-export-roundtrip.png")
bpy.ops.render.render(write_still=True)

report = {
    "status": "passed",
    "glb_bytes": len(data),
    "triangles": triangles,
    "rigid_meshes": len(mesh_objects),
    "material_primitives": primitive_count,
    "checks": ["GLB container and self-contained buffers", "three rigid meshes",
               "named hierarchy and muzzle attachment", "triangle counts",
               "finite geometry and nonzero triangle area", "round-trip bounds",
               "turret yaw moves muzzle around fixed pivot", "barrel elevation preserves reach",
               "hull remains stationary during articulation", "reimported GLB preview rendered"],
    "godot_import": "Not run: no Godot executable found in PATH or installed applications.",
}
(HERE / "verification.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
