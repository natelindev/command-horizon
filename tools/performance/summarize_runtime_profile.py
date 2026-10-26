"""Summarize optional production runtime timings without double-counting children."""

import argparse
import json
from pathlib import Path


STAGES = {
    "movement": ("body_index", "steering", "velocity_callbacks", "server_projection"),
    "poses": ("physics_roots", "prepare", "chassis_solve", "finish", "infantry_solve", "publish", "upload"),
    "visibility": ("blocker_configuration", "observed", "point", "line", "fire"),
    "nearest_surface": ("native_projection",),
    "scene_wall": ("physics_dispatch", "process_dispatch"),
    "scene_cpu": ("physics_dispatch", "process_dispatch"),
}
CHILDREN = {("movement", "server_projection"), ("visibility", "blocker_configuration"),
            ("nearest_surface", "native_projection")}
AGGREGATES = {("scene_wall", "physics_dispatch"), ("scene_wall", "process_dispatch"),
              ("scene_cpu", "physics_dispatch"), ("scene_cpu", "process_dispatch")}


def summarize(report):
    result = {
        "status": report.get("status"),
        "release": report.get("release"),
        "diagnostic": report.get("diagnostic", False),
        "build": report.get("build"),
        "note": "Elapsed main-thread scopes include synchronous waits. Projection is nested in movement; blocker configuration may be nested in visibility. Unattributed wall time includes engine work, uninstrumented scripts, GPU waits and other waits; it is not a CPU utilization measurement.",
        "phases": [],
    }
    for phase in report["phases"]:
        frames = phase["samples"]
        if frames <= 0:
            raise ValueError("No sampled frames")
        scopes = {}
        total = 0.0
        for system, labels in STAGES.items():
            values = phase.get("runtime_profile_us", {}).get(system, [])
            if not values:
                continue
            if len(values) != len(labels) * 2 or any(n < 0 for n in values):
                raise ValueError("Unexpected timer/counter schema: " + system)
            for index, label in enumerate(labels):
                elapsed, calls = values[index], values[index + len(labels)]
                nested = (system, label) in CHILDREN
                aggregate = (system, label) in AGGREGATES
                ms_frame = elapsed / 1000.0 / frames
                scopes[system + "." + label] = {
                    "elapsed_ms_per_frame": ms_frame,
                    "elapsed_us_per_call": elapsed / calls if calls else None,
                    "calls": calls,
                    "nested_scope": nested,
                    "aggregate_scope": aggregate,
                }
                if not nested and not aggregate:
                    total += ms_frame
        if not scopes:
            raise ValueError("Run with --profile-runtime to capture timings")
        result["phases"].append({
            "phase": phase["phase"],
            "mean_fps": phase["mean_fps"],
            "frames": frames,
            "wall_ms_per_frame": phase["frame_ms"]["mean"],
            "timed_nonchild_ms_per_frame": total,
            "unattributed_wall_ms_per_frame": phase["frame_ms"]["mean"] - total,
            "scopes": scopes,
            "cpu_usage": phase.get("cpu_usage", {"available": False}),
        })
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        summary = summarize(json.loads(args.report.read_text(encoding="utf-8")))
    except (KeyError, ValueError) as error:
        parser.error(str(error))
    if args.output:
        args.output.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    for phase in summary["phases"]:
        print(f'{phase["phase"]}: {phase["mean_fps"]:.2f} fps; '
              f'{phase["wall_ms_per_frame"]:.2f} ms/frame')
        for name, scope in phase["scopes"].items():
            nested = " (aggregate)" if scope["aggregate_scope"] else (" (nested)" if scope["nested_scope"] else "")
            print(f'  {name}: {scope["elapsed_ms_per_frame"]:.3f} ms/frame{nested}')
        print(f'  Unattributed wall time: {phase["unattributed_wall_ms_per_frame"]:.3f} ms/frame')


if __name__ == "__main__":
    main()
