"""Reimport air-combat GLBs and verify geometry, articulation and weathering.

blender --background --factory-startup --python-exit-code 1 --python art/air-combat/verify_aircraft.py
"""
import json
import math
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
manifest = json.loads((ROOT / "art/air-combat/manifest.json").read_text())
ROTORS = {
    ("bastion", "Bomber"): {"RotorA", "RotorB", "RotorC", "RotorD"},
    ("bastion", "Helicopter"): {"RotorM", "RotorT"},
    ("helix", "WraithTiltrotor"): {"RotorLeft", "RotorRight"},
    ("frontier", "BuzzardBomber"): {"RotorLeft", "RotorRight"},
}
ANTI_AIR = {"AntiAirVehicle", "HaloSkimmer", "RipsawTruck"}

for item in manifest:
    faction, name = item["faction"], item["name"]
    directory = "air-v1" if faction == "bastion" else "v1"
    path = ROOT / "assets/models" / faction / directory / (name + ".glb")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = list(bpy.context.scene.objects)
    meshes = [obj for obj in objects if obj.type == "MESH"]
    triangles = sum(len(poly.vertices) - 2 for obj in meshes for poly in obj.data.polygons)
    assert triangles == item["triangles"], (name, triangles, item["triangles"])
    assert meshes and all(obj.data.materials for obj in meshes), name
    assert all(
        math.isfinite(value)
        for obj in meshes
        for vertex in obj.data.vertices
        for value in vertex.co
    ), name
    assert any(
        material.name.startswith("TeamColor")
        for obj in meshes
        for material in obj.data.materials
        if material
    ), (name, "missing team-color material")
    pivots = {obj.name.rsplit("_", 1)[-1]: obj for obj in objects if obj.type == "EMPTY"}
    assert "Muzzle" in pivots, (name, "missing projectile origin")
    expected = ROTORS.get((faction, name), set())
    if name in ANTI_AIR:
        expected = expected | {"TurretPivot", "BarrelPivot"}
    for token in expected:
        assert token in pivots and pivots[token].children, (name, "empty articulation", token)
    darkest = 1.0
    for obj in meshes:
        colors = obj.data.color_attributes.active_color
        assert colors is not None and colors.data, (name, obj.name, "missing weathering")
        for corner in colors.data:
            red, green, blue, alpha = corner.color
            assert .34 <= red <= 1.0, (name, "occlusion range", red)
            assert abs(red - green) < .001 and abs(red - blue) < .001, (name, "tinted occlusion")
            assert 0.0 <= alpha <= 1.0, (name, "wear range", alpha)
            darkest = min(darkest, red)
    assert darkest < .9, (name, "no visible baked occlusion")
    print(f"PASS: {faction}/{name}: {triangles} triangles, articulated, weathered")

print(f"PASS: all {len(manifest)} air-combat GLBs")
