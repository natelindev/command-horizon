"""Validate every exported faction asset through Blender's glTF importer."""
import json
import math
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
manifest = json.loads((ROOT / "art/bastion/demo/manifest.json").read_text())
results = []
for item in manifest:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    path = ROOT / "assets/models/bastion/demo" / item["file"]
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    triangles = sum(sum(len(poly.vertices) - 2 for poly in obj.data.polygons) for obj in meshes)
    assert triangles == item["triangles"], (item["name"], triangles, item["triangles"])
    assert meshes and all(obj.data.materials for obj in meshes)
    assert all(math.isfinite(float(value)) for obj in meshes for vertex in obj.data.vertices for value in vertex.co)
    if item["name"] in ("Tank", "AdvancedTank", "CombatRobot", "AntiGroundTurret", "AntiAirTurret"):
        assert any("TurretPivot" in obj.name for obj in bpy.context.scene.objects), item["name"]
    assert (ROOT / "assets/ui/bastion" / (item["name"] + ".png")).exists()
    results.append({"name": item["name"], "triangles": triangles, "meshes": len(meshes), "valid": True})
report = {"blender": bpy.app.version_string, "asset_count": len(results), "assets": results}
(ROOT / "art/bastion/demo/verification.json").write_text(json.dumps(report, indent=2) + "\n")
print("PASS: all 20 faction GLBs reimport, topology counts, finite vertices, materials, pivots and icons")
