"""Validate every exported faction asset through Blender's glTF importer."""
import json
import math
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
manifest = json.loads((ROOT / "art/bastion/structures-v2/manifest.json").read_text())
results = []
for item in manifest:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    path = ROOT / "assets/models/bastion/structures-v2" / item["file"]
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    triangles = sum(sum(len(poly.vertices) - 2 for poly in obj.data.polygons) for obj in meshes)
    assert triangles == item["triangles"], (item["name"], triangles, item["triangles"])
    assert meshes and all(obj.data.materials for obj in meshes)
    assert all(math.isfinite(float(value)) for obj in meshes for vertex in obj.data.vertices for value in vertex.co)
    if item["name"] in ("Tank", "AdvancedTank", "CombatRobot", "AntiGroundTurret", "AntiAirTurret"):
        assert any("TurretPivot" in obj.name for obj in bpy.context.scene.objects), item["name"]
    assert (ROOT / "assets/ui/bastion/structures-v2" / (item["name"] + ".png")).exists()
    envelope = {
        "CommandCenter": (.52, 2.2, 3.0), "Barracks": (.52, 1.8, 1.7),
        "VehicleFactory": (.5, 2.3, 2.0), "AircraftFactory": (.5, 2.3, 2.8),
        "PowerPlant": (.5, 1.7, 2.0), "CommandLab": (.5, 1.8, 2.4),
        "RepairDepot": (.5, 2.0, 1.9), "AntiGroundTurret": (.48, 1.1, 1.3),
        "AntiAirTurret": (.48, 1.1, 1.6)}[item["name"]]
    scale, radius, height = envelope
    points = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
    assert max(p.z for p in points) * scale <= height, item["name"] + " exceeds target height"
    assert max(math.hypot(p.x, p.y) for p in points) * scale <= radius + .04, item["name"] + " exceeds footprint"
    if "Turret" in item["name"]:
        for joint in ["TurretPivot", "BarrelPivot", "Muzzle"]:
            assert any(obj.name.endswith(joint) for obj in bpy.context.scene.objects), joint
    assert any(m.name.startswith("TeamColor") for obj in meshes for m in obj.data.materials)
    results.append({"name": item["name"], "triangles": triangles, "meshes": len(meshes), "valid": True})
report = {"blender": bpy.app.version_string, "asset_count": len(results), "assets": results}
(ROOT / "art/bastion/structures-v2/verification.json").write_text(json.dumps(report, indent=2) + "\n")
print("PASS: all 9 Bastion structure GLBs reimport, topology counts, finite vertices, materials, pivots and icons")
