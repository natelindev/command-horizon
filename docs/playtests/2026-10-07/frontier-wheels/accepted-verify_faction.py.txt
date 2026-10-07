"""Reimport Frontier GLBs and verify the actual exported geometry and articulations."""
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/frontier/v1"
manifest = json.loads((SOURCE / "manifest.json").read_text())
roster = json.loads((ROOT / "art/frontier/roster.json").read_text())
assert len(manifest) == len(roster) == 17
assert {item["name"] for item in manifest} == set(roster.values())
results = []
for item in manifest:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/models/frontier/v1" / item["file"]))
    objects = list(bpy.context.scene.objects)
    meshes = [obj for obj in objects if obj.type == "MESH"]
    triangles = sum(sum(len(poly.vertices) - 2 for poly in obj.data.polygons) for obj in meshes)
    assert 0 < triangles == item["triangles"] < 25000, (item["name"], triangles)
    assert meshes and all(obj.data.materials for obj in meshes)
    assert all(poly.area > 1e-10 for obj in meshes for poly in obj.data.polygons)
    assert all(math.isfinite(float(value)) for obj in meshes for vertex in obj.data.vertices for value in vertex.co)
    assert any(m.name.startswith("TeamColor") for obj in meshes for m in obj.data.materials if m)
    points = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
    lo = [min(p[i] for p in points) for i in range(3)]
    hi = [max(p[i] for p in points) for i in range(3)]
    # Modifier-evaluated export can differ from editable bevel bounding boxes by millimetres.
    assert all(abs(a-b) < .08 for a,b in zip(lo, item["bounds"]["min"])), (item["name"], lo)
    assert all(abs(a-b) < .08 for a,b in zip(hi, item["bounds"]["max"])), (item["name"], hi)
    for token in ("TurretPivot", "BarrelPivot", "ToolArm", "RepairArm", "LegLeft", "LegRight"):
        for obj in objects:
            if token in obj.name and obj.type == "EMPTY":
                assert obj.children, (item["name"], "Empty articulation", obj.name)
    role = next(role for role,name in roster.items() if name == item["name"])
    if role in ("Tank", "AdvancedTank", "CombatRobot", "AntiGroundTurret", "AntiAirTurret"):
        assert any(obj.name.endswith("TurretPivot") for obj in objects), role
    if role in ("Infantry", "Tank", "AdvancedTank", "CombatRobot", "Helicopter", "AntiGroundTurret", "AntiAirTurret"):
        muzzle = next(obj for obj in objects if obj.name.endswith("Muzzle"))
        assert muzzle.matrix_world.translation.y > 0, (role, "Muzzle faces backward")
    wheels = [obj for obj in objects if obj.type == "EMPTY" and "_WheelPivot" in obj.name]
    assert len(wheels) == {"Worker": 6, "Tank": 6, "RepairRobot": 4, "CombatRobot": 4, "AdvancedTank": 8}.get(role, 0), role
    assert all(wheel.children for wheel in wheels), (role, "Empty wheel articulation")
    expected_rotors = {"Drone": 4, "Helicopter": 1}.get(role, 0)
    rotors = [obj for obj in objects if obj.type == "EMPTY" and obj.name[-6:-1] == "Rotor" and obj.name[-1].isdigit()]
    assert len(rotors) == expected_rotors, (role, [obj.name for obj in rotors])
    for rotor in rotors:
        assert rotor.children, (role, "Empty rotor")
    icon = bpy.data.images.load(str(ROOT / "assets/ui/frontier" / (item["name"] + ".png")), check_existing=False)
    assert tuple(icon.size) == (256, 256) and icon.channels == 4
    alpha = list(icon.pixels)[3::4]
    occupied = [(i % 256, i // 256) for i,a in enumerate(alpha) if a > .05]
    assert len(occupied) > 800, (role, "Empty/tiny icon")
    assert min(x for x,y in occupied) > 0 and max(x for x,y in occupied) < 255, (role, "Icon clipped horizontally")
    assert min(y for x,y in occupied) > 0 and max(y for x,y in occupied) < 255, (role, "Icon clipped vertically")
    bpy.data.images.remove(icon)
    results.append({"role":role,"name":item["name"],"triangles":triangles,"meshes":len(meshes),"rotors":len(rotors),"wheels":len(wheels),"valid":True})
report = {"blender":bpy.app.version_string,"asset_count":len(results),"assets":results}
(SOURCE / "verification.json").write_text(json.dumps(report, indent=2) + "\n")
print("PASS: all 17 Frontier GLBs, topology, bounds, materials, articulation, forward muzzles and unclipped icons")
