"""Compare two valid heavy-2v2 runs of the same production executable."""

import argparse
import json
from pathlib import Path


def compare(control, candidate):
    for report in (control, candidate):
        if (report.get("status") != "valid" or not report.get("goal_workload")
                or report.get("process_exit_code") != 0 or report.get("engine_errors")):
            raise ValueError("Both reports must be valid, complete production workloads")
    identity = control["build"]["executable_sha256"]
    if candidate["build"]["executable_sha256"] != identity:
        raise ValueError("A paired comparison requires the same executable")
    before = {phase["phase"]: phase for phase in control["phases"]}
    after = {phase["phase"]: phase for phase in candidate["phases"]}
    if before.keys() != after.keys():
        raise ValueError("Phase sets differ")
    result = {
        "note": "One paired run, not a statistical confidence interval. Changes in catch-up ticks and gameplay trajectories interact; subsystem gains are not independent multipliers.",
        "build": control["build"],
        "control_arguments": control["arguments"],
        "candidate_arguments": candidate["arguments"],
        "control_target_met": control["target_met"],
        "candidate_target_met": candidate["target_met"],
        "phases": [],
    }
    for name, base in before.items():
        changed = after[name]
        result["phases"].append({
            "phase": name,
            "control_fps": base["mean_fps"],
            "candidate_fps": changed["mean_fps"],
            "fps_change_percent": (changed["mean_fps"] / base["mean_fps"] - 1) * 100,
            "control_frame_ms": base["frame_ms"],
            "candidate_frame_ms": changed["frame_ms"],
            "control_cpu_usage": base.get("cpu_usage"),
            "candidate_cpu_usage": changed.get("cpu_usage"),
            "control_gpu_ms": base["gpu_ms"],
            "candidate_gpu_ms": changed["gpu_ms"],
            "control_real_time_ratio": base["real_time_ratio"],
            "candidate_real_time_ratio": changed["real_time_ratio"],
            "control_counts": base["counts"],
            "candidate_counts": changed["counts"],
        })
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("control", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = compare(
            json.loads(args.control.read_text(encoding="utf-8")),
            json.loads(args.candidate.read_text(encoding="utf-8")),
        )
    except (KeyError, ValueError) as error:
        parser.error(str(error))
    result["control_report"] = args.control.name
    result["candidate_report"] = args.candidate.name
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    for phase in result["phases"]:
        print(f'{phase["phase"]}: {phase["control_fps"]:.2f} -> '
              f'{phase["candidate_fps"]:.2f} fps '
              f'({phase["fps_change_percent"]:+.1f}%)')


if __name__ == "__main__":
    main()
