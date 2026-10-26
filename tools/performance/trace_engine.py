"""Capture one live benchmark phase with an optimized, Tracy-enabled Godot build.

This is diagnostic evidence only. Never use tracing timings to claim gameplay FPS.
The project must be the isolated benchmark project prepared by build_benchmark.py.
"""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

from build_benchmark import source_manifest


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def stop(process):
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=10)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--capture", required=True, type=Path)
    parser.add_argument("--csvexport", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--phase", default="day_combat")
    parser.add_argument("--seconds", default=6, type=int)
    parser.add_argument("--timeout", default=600, type=int)
    parser.add_argument("extra", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not 1 <= args.seconds <= 30:
        parser.error("Capture duration must be between 1 and 30 seconds")
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    project = args.project.resolve()
    engine = args.godot.resolve()
    capture = args.capture.resolve()
    csvexport = args.csvexport.resolve()
    extra = args.extra[1:] if args.extra[:1] == ["--"] else args.extra
    logfile = folder / "engine.log"
    reportfile = folder / "benchmark.json"
    trace = folder / "capture.tracy"
    engine_args = [str(engine), "--log-file", str(logfile),
                   "--", "--output=" + str(reportfile), *extra]
    capture_args = [str(capture), "-a", "127.0.0.1", "-o", str(trace),
                    "-s", str(args.seconds), "-m", "4096"]
    startup = None
    if hasattr(subprocess, "STARTUPINFO"):
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = subprocess.SW_HIDE
    game = recorder = None
    deadline = time.monotonic() + args.timeout
    began = None
    metadata = {
        "diagnostic": True, "production_fps_evidence": False,
        "note": "Custom optimized engine with Tracy overhead. Captured phase only; not FPS acceptance.",
        "phase": args.phase, "seconds_requested": args.seconds,
        "engine_sha256": sha256(engine), "capture_sha256": sha256(capture),
        "csvexport_sha256": sha256(csvexport), "engine_arguments": engine_args,
        "capture_arguments": capture_args,
        "working_directory": str(project),
        "source_manifest": source_manifest(),
        "project_configuration_sha256": sha256(project / "project.godot"),
    }
    try:
        with (folder / "stdout.log").open("w", encoding="utf-8") as stdout, \
                (folder / "capture.log").open("w", encoding="utf-8") as recording:
            game = subprocess.Popen(engine_args, cwd=project, stdout=stdout,
                                    stderr=subprocess.STDOUT)
            print(f"Waiting for {args.phase}; game PID {game.pid}", flush=True)
            while game.poll() is None:
                if time.monotonic() > deadline:
                    raise TimeoutError("Benchmark/trace exceeded its wall-time limit")
                # Release file logging may buffer phase markers until shutdown.
                # Redirected stdout provides the same markers immediately.
                content = (folder / "stdout.log").read_text(encoding="utf-8", errors="replace")
                if recorder is None and "HEAVY_BEGIN " + args.phase + "\n" in content:
                    began = time.time()
                    recorder = subprocess.Popen(capture_args, stdout=recording,
                                                stderr=subprocess.STDOUT, startupinfo=startup)
                    print(f"Capturing {args.seconds}s; recorder PID {recorder.pid}", flush=True)
                if recorder is not None and recorder.poll() not in (None, 0):
                    raise RuntimeError("Tracy capture failed; see capture.log")
                time.sleep(.25)
            metadata["process_exit_code"] = game.returncode
            if recorder is None:
                raise RuntimeError("Benchmark never reached the requested capture phase")
            recorder.wait(timeout=max(1, deadline - time.monotonic()))
            metadata["capture_exit_code"] = recorder.returncode
            metadata["capture_started_unix"] = began
            if recorder.returncode or not trace.exists() or trace.stat().st_size == 0:
                raise RuntimeError("No completed Tracy capture")
        if not reportfile.exists():
            raise RuntimeError("Benchmark did not write its report")
        report = json.loads(reportfile.read_text(encoding="utf-8"))
        report.update(diagnostic=True, goal_workload=False, target_met=False,
                      diagnostic_note=metadata["note"], process_exit_code=game.returncode)
        log_lines = (folder / "stdout.log").read_text(encoding="utf-8", errors="replace").splitlines()
        report["process_log_errors"] = [line for line in log_lines
                                        if line.startswith(("ERROR:", "SCRIPT ERROR:"))]
        report["process_log_warnings"] = [line for line in log_lines if line.startswith("WARNING:")]
        if report["process_log_errors"]:
            report["fixture_status"] = report.get("status")
            report["status"] = "rejected"
        reportfile.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        for name, options in (("zones-self.csv", ["-e"]), ("zones-total.csv", [])):
            with (folder / name).open("w", encoding="utf-8") as stream:
                subprocess.run([str(csvexport), *options, str(trace)], stdout=stream,
                               stderr=subprocess.PIPE, startupinfo=startup, check=True, timeout=120)
        metadata["trace_bytes"] = trace.stat().st_size
        metadata["status"] = "valid" if game.returncode == 0 and report.get("status") == "valid" else "rejected"
        if metadata["source_manifest"] != source_manifest():
            raise RuntimeError("Source changed during the diagnostic capture")
        print(f"Trace: {trace}; benchmark status: {metadata['status']}", flush=True)
    except Exception as error:
        metadata["status"] = "rejected"
        metadata["error"] = str(error)
        raise
    finally:
        stop(recorder)
        stop(game)
        (folder / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    if metadata.get("status") != "valid":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
