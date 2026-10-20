"""Rebuild Bastion air-combat GLBs, including baked vertex weathering.

blender --background --factory-startup --python-exit-code 1 --python art/bastion/build_aircraft.py
"""
from pathlib import Path
import runpy

runpy.run_path(
    str(Path(__file__).resolve().parents[1] / "air-combat/build_aircraft.py"),
    init_globals={"BUILD_FACTION": "bastion"},
    run_name="__main__",
)
