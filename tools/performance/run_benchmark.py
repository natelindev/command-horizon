"""Run a rendered Windows benchmark serially and retain build provenance."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

TARGET_FPS = 60


def goal_workload(report):
    phases = {phase["phase"]: phase for phase in report.get("phases", [])}
    cycling = phases.get("cycling_weather_combat", {})
    required = {"day_movement", "day_combat", "night_combat", "night_base", "cycling_weather_combat"}
    return (
        not report.get("diagnostic", False)
        and report.get("resolution") == [3840, 2160]
        and report.get("scale_3d") == 1.0
        and report.get("mobile_per_player") == 100
        and report.get("structures_per_player") == 40
        and report.get("physics_ticks_per_second") == 30
        and report.get("teams") == [0, 0, 1, 1]
        and report.get("release") is True
        and report.get("live_commander_ai") is True
        and required <= phases.keys()
        and cycling.get("day_cycle") is True
        and cycling.get("weather_option") == 3
        and cycling.get("end_hour") != cycling.get("start_hour")
        and all(phase.get("counts", {}).get("mobile", 0) >= 400
                and phase.get("counts", {}).get("structures", 0) >= 160
                and phase.get("pixels") == [3840, 2160]
                for phase in phases.values())
    )


def meets_target(report):
    return (
        report.get("process_exit_code") == 0
        and report.get("status") == "valid"
        and not report.get("process_log_errors")
        and goal_workload(report)
        and report.get("target_fps") == TARGET_FPS
        and all(
            phase["mean_fps"] >= TARGET_FPS
            and phase["frame_ms"]["p95"] <= 1000 / TARGET_FPS
            and phase.get("real_time_ratio", phase["simulation_seconds"] / phase["wall_seconds"]) >= .98
            for phase in report["phases"]
        )
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("extra", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    executable = args.executable.resolve()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    metadata = json.loads(executable.with_suffix(".metadata.json").read_text(encoding="utf-8"))
    if hashlib.sha256(executable.read_bytes()).hexdigest() != metadata["executable_sha256"]:
        raise RuntimeError("Benchmark executable does not match its build metadata")
    previous_stamp = output.stat().st_mtime_ns if output.exists() else None
    extra = args.extra[1:] if args.extra[:1] == ["--"] else args.extra
    logfile = output.with_suffix(".log")
    result = subprocess.run(
        [str(executable), "--log-file", str(logfile), "--", "--output=" + str(output), *extra],
        cwd=executable.parent, timeout=600, check=False,
    )
    if not output.exists():
        raise RuntimeError(f"Benchmark produced no report; exit {result.returncode}: {logfile}")
    if output.stat().st_mtime_ns == previous_stamp:
        raise RuntimeError(f"Benchmark did not replace its previous report; exit {result.returncode}")
    report = json.loads(output.read_text(encoding="utf-8"))
    report["build"] = {key: metadata[key] for key in (
        "source_commit", "source_digest", "project_sha256", "executable_sha256")}
    report["arguments"] = extra
    report["process_exit_code"] = result.returncode
    # The fixture logger is removed before teardown. Retain diagnostics from
    # the whole process as well, so a clean sampling interval cannot hide a
    # script/extension error or shutdown failure later in the log.
    log_lines = logfile.read_text(encoding="utf-8", errors="replace").splitlines()
    report["process_log_errors"] = [line for line in log_lines
                                    if line.startswith(("ERROR:", "SCRIPT ERROR:"))]
    report["process_log_warnings"] = [line for line in log_lines if line.startswith("WARNING:")]
    if report["process_log_errors"]:
        report["fixture_status"] = report.get("status")
        report["status"] = "rejected"
    report["goal_workload"] = goal_workload(report)
    report["target_met"] = meets_target(report)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for phase in report["phases"]:
        print(f'{phase["phase"]}: {phase["mean_fps"]:.1f} fps, '
              f'p95 {phase["frame_ms"]["p95"]:.2f} ms, GPU {phase["gpu_ms"]["mean"]:.2f} ms')
    print(f'Fixture: {report.get("status")}; {TARGET_FPS} fps target met: {report["target_met"]}')
    if result.returncode or report.get("status") != "valid":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
