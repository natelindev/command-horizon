#!/usr/bin/env python3
"""Run actual localhost host/guest/spectator and replay regression processes."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
NATIVE_FLAGS = ["--enable-native-kernels", "--native-unit-state", "--native-crowd-runtime"]
CASES = {
    "session": ("NetworkSessionRegression", ("host", "spectator", "guest"), 90),
    "groups": ("NetworkGroupOrdersRegression", ("host", "spectator", "guest"), 100),
    "outcome": ("NetworkOutcomeRegression", ("host", "guest"), 45),
    "terminal-drop": ("NetworkOutcomeRegression", ("host", "guest"), 45),
    "disconnect": ("NetworkDisconnectRegression", ("host", "guest"), 70),
    "two-vs-two": ("Network2v2Regression", ("host", "guest1", "guest2"), 150),
    "dedicated": ("NetworkDedicatedRegression", ("server", "guest1", "guest2"), 150),
}
MARKERS = {
    "session": "Network session {role}: 0 failures",
    "outcome": "Network lethal HQ {role}: 0 failures",
    "terminal-drop": "Network terminal-drop {role}: 0 failures",
    "disconnect": "Network host-loss expiry {role}: 0 failures",
    "replay": "Replay playback and verifier: 0 failures",
    "groups": "Network group {role}: 0 failures",
    "group-replay": "Network group replay: 0 failures",
    "two-vs-two": "Network 2v2 {role}: 0 failures",
    "dedicated": "Network dedicated {role}: 0 failures",
}
MAX_LOG_BYTES = 16 * 1024 * 1024


class UsageError(Exception):
    pass


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise UsageError(message)


def scalar(value):
    return json.dumps(value, ensure_ascii=False, allow_nan=False)


def table(name, rows, fields):
    print(f"{name}[{len(rows)}]{{{','.join(fields)}}}:")
    for row in rows:
        print("  " + ",".join(scalar(row.get(field)) for field in fields))


def identity():
    print("bin: " + scalar(str(Path(__file__).resolve()).replace(str(Path.home()), "~", 1)))
    print('description: "Run real localhost multiplayer and binary replay regression processes."')


def help_view():
    identity()
    table("flags", [
        {"flag": "--engine PATH", "default": "godot on PATH", "purpose": "Godot executable"},
        {"flag": "--project PATH", "default": str(ROOT), "purpose": "Source project directory"},
        {"flag": "--main-pack PATH", "default": "none", "purpose": "Exported PCK instead of source project"},
        {"flag": "--runtime-dir PATH", "default": "project or pack directory", "purpose": "Runtime cwd containing matching external native support"},
        {"flag": "--output PATH", "default": "tmp/network-regressions", "purpose": "Parent for a new retained run directory"},
        {"flag": "--case NAME", "default": "all", "purpose": "all, session, groups, outcome, terminal-drop, disconnect, two-vs-two or dedicated"},
        {"flag": "--no-native", "default": "false", "purpose": "Explicit scripted fallback run"},
        {"flag": "--startup-timeout SECONDS", "default": "20", "purpose": "Host readiness deadline; range1..60"},
    ], ("flag", "default", "purpose"))
    table("examples", [
        {"command": "python3 tools/tests/run_network_regressions.py --engine /path/to/Godot --output tmp/network"},
        {"command": "python3 tools/tests/run_network_regressions.py --engine /path/to/Godot --main-pack build/game.pck --case session"},
    ], ("command",))


def options(argv):
    parser = Parser(add_help=False, description=__doc__)
    parser.add_argument("--engine", default=shutil.which("godot") or shutil.which("godot4"))
    target = parser.add_mutually_exclusive_group()
    target.add_argument("--project", type=Path)
    target.add_argument("--main-pack", type=Path)
    parser.add_argument("--runtime-dir", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "tmp/network-regressions")
    parser.add_argument("--case", choices=("all", *CASES), default="all")
    parser.add_argument("--no-native", action="store_true")
    parser.add_argument("--startup-timeout", type=float, default=20)
    args = parser.parse_args(argv)
    if not args.engine:
        raise UsageError("Provide --engine /path/to/Godot; no Godot executable was found on PATH")
    engine = shutil.which(args.engine) or args.engine
    args.engine = Path(engine).expanduser().resolve()
    if not args.engine.is_file() or not os.access(args.engine, os.X_OK):
        raise UsageError("--engine must name an executable Godot file")
    args.project = (args.project or ROOT).expanduser().resolve()
    if args.main_pack:
        args.main_pack = args.main_pack.expanduser().resolve()
        if not args.main_pack.is_file():
            raise UsageError("--main-pack must name an existing exported PCK")
    elif not (args.project / "project.godot").is_file():
        raise UsageError("--project must contain project.godot")
    args.runtime_dir = (args.runtime_dir or
                        (args.main_pack.parent if args.main_pack else args.project)).expanduser().resolve()
    if not args.runtime_dir.is_dir():
        raise UsageError("--runtime-dir must name an existing directory")
    if not 1 <= args.startup_timeout <= 60:
        raise UsageError("--startup-timeout must be between 1 and 60 seconds")
    args.output = args.output.expanduser().resolve()
    return args


def read_log(path):
    if not path.exists():
        return ""
    with path.open("rb") as source:
        return source.read(MAX_LOG_BYTES + 1).decode("utf-8", errors="replace")


def free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def stop(process):
    """Bound teardown for only the process group created by this runner."""
    if process.poll() is not None:
        return
    try:
        if os.name == "nt":
            process.terminate()
        else:
            os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        process.wait(timeout=3)
        return
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        if os.name == "nt":
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                           capture_output=True, timeout=5, check=False)
        else:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        process.wait(timeout=3)


def command(args, script, flags):
    # Idle headless peers otherwise spin unbounded process frames and compete
    # with the authority and replica loaders on small CI runners.
    result = [str(args.engine), "--headless", "--max-fps", "60"]
    result += (["--main-pack", str(args.main_pack)] if args.main_pack
               else ["--path", str(args.project)])
    # Real wall time is essential to disconnect expiry; never use --fixed-fps.
    result += ["--script", f"res://tests/headless/{script}.gd", "--"]
    return result + ([] if args.no_native else NATIVE_FLAGS) + flags


def spawn(args, directory, case, role, script, flags):
    path = directory / f"{case}-{role}.log"
    log = path.open("wb")
    try:
        process = subprocess.Popen(
            command(args, script, flags), cwd=args.runtime_dir, stdin=subprocess.DEVNULL,
            stdout=log, stderr=subprocess.STDOUT, start_new_session=os.name != "nt",
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0,
        )
    finally:
        log.close()
    return {"process": process, "log": path, "role": role}


def verify(case, entry, problem=""):
    content = read_log(entry["log"])
    # Session fixture uses the same client completion marker for spectators.
    role = (entry["role"] if case in ("groups", "two-vs-two", "dedicated") else
            "host" if entry["role"] == "host" else "client" if case == "session" else "guest")
    marker = MARKERS[case].format(role=role)
    if not problem and entry["process"].returncode != 0:
        problem = f"process exited with code {entry['process'].returncode}"
    if not problem and marker not in content:
        problem = "expected completion assertion was not reported"
    if not problem and re.search(
            r"SCRIPT ERROR:|\bERROR:|Parse Error:|\bRIDs?\b[^\n]*\bleaked\b|"
            r"\bObjectDB instances (?:were )?leaked\b|\bresources? still in use\b", content, re.IGNORECASE):
        problem = "runtime error or shutdown leak reported; inspect retained log"
    return {"case": case, "role": entry["role"], "status": "failed" if problem else "passed",
            "exit_code": entry["process"].returncode, "log": str(entry["log"]), "error": problem}


def run_case(args, directory, case):
    script, roles, timeout = CASES[case]
    port = free_port()
    shared = [f"--network-port={port}"]
    if case == "terminal-drop":
        shared.append("--terminal-drop-host")
    host_flags = shared + ["--network-host"]
    if case in ("session", "groups"):
        host_flags += ["--network-expect-spectator"]
    entries = []
    problem = ""
    print(f"Running {case}: UDP {port}", file=sys.stderr, flush=True)
    try:
        entries.append(spawn(args, directory, case, roles[0], script, host_flags + [f"--network-role={roles[0]}"]))
        deadline = time.monotonic() + args.startup_timeout
        while f"NETWORK_READY port={port}" not in read_log(entries[0]["log"]):
            if entries[0]["log"].stat().st_size > MAX_LOG_BYTES:
                problem = "bounded 16MiB diagnostic log limit exceeded before host readiness"
                break
            if entries[0]["process"].poll() is not None:
                problem = "host exited before opening its listening socket"
                break
            if time.monotonic() >= deadline:
                problem = "host readiness deadline exceeded"
                break
            time.sleep(.05)
        if not problem:
            for role in roles[1:]:
                flags = shared + (["--network-spectator"] if role == "spectator" else []) + [f"--network-role={role}"]
                entries.append(spawn(args, directory, case, role, script, flags))
            deadline = time.monotonic() + timeout
            while any(entry["process"].poll() is None for entry in entries):
                if any(entry["log"].stat().st_size > MAX_LOG_BYTES for entry in entries):
                    problem = "bounded 16MiB diagnostic log limit exceeded"
                    break
                if any(entry["process"].poll() not in (None, 0) for entry in entries):
                    problem = "a peer failed; remaining processes were stopped"
                    break
                if time.monotonic() >= deadline:
                    problem = f"case exceeded its {timeout}s wall deadline"
                    break
                time.sleep(.05)
    finally:
        for entry in entries:
            stop(entry["process"])
    rows = [verify(case, entry, problem) for entry in entries]
    if len(entries) != len(roles):
        rows.extend({"case": case, "role": role, "status": "failed", "exit_code": None,
                     "log": "", "error": "host did not become ready"} for role in roles[len(entries):])
    recording = ""
    if case in ("session", "groups") and all(row["status"] == "passed" for row in rows):
        match = re.search(r"replay=(user://replays/[^\s]+\.rtsreplay)", read_log(entries[0]["log"]))
        recording = match.group(1) if match else ""
        if not recording:
            rows[0].update(status="failed", error="host did not identify its binary recording")
    return rows, recording


def run_replay(args, directory, recording, case="session"):
    label = "group-replay" if case == "groups" else "replay"
    script = "NetworkGroupOrdersRegression" if case == "groups" else "ReplayPlaybackRegression"
    entry = spawn(args, directory, label, "verifier", script,
                  ["--network-recording=" + recording])
    problem = ""
    try:
        deadline = time.monotonic() + 90
        while entry["process"].poll() is None:
            if entry["log"].stat().st_size > MAX_LOG_BYTES:
                problem = "bounded 16MiB diagnostic log limit exceeded"
                break
            if time.monotonic() >= deadline:
                problem = "replay verification exceeded its 90s wall deadline"
                break
            time.sleep(.05)
    finally:
        stop(entry["process"])
    return verify(label, entry, problem)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if "--help" in argv or "-h" in argv:
        help_view()
        return 0
    if not argv:
        identity()
        table("cases", [{"case": name, "processes": len(data[1]), "status": "ready"}
                        for name, data in CASES.items()], ("case", "processes", "status"))
        print('help: "Run with --engine /path/to/Godot, or --help for all options."')
        return 0
    directory = None
    try:
        args = options(argv)
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        directory = args.output / f"run-{stamp}-{os.getpid()}"
        directory.mkdir(parents=True, exist_ok=False)
        rows = []
        recordings = []
        for case in CASES if args.case == "all" else [args.case]:
            current, recording = run_case(args, directory, case)
            rows.extend(current)
            if recording:
                recordings.append(recording)
                rows.append(run_replay(args, directory, recording, case))
        report = {"engine": str(args.engine), "project": str(args.project),
                  "main_pack": str(args.main_pack) if args.main_pack else None,
                  "runtime_dir": str(args.runtime_dir),
                  "native": not args.no_native, "recordings": recordings, "results": rows}
        report_path = directory / "results.json"
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        identity()
        table("checks", rows, ("case", "role", "status", "log"))
        failed = [row for row in rows if row["status"] != "passed"]
        if failed:
            table("errors", failed, ("case", "role", "error"))
        print(f"passed: {len(rows) - len(failed)}/{len(rows)}")
        print("report: " + scalar(str(report_path)))
        return 1 if failed else 0
    except UsageError as error:
        print("error: " + scalar(str(error)))
        print('help: "Run python3 tools/tests/run_network_regressions.py --help for examples."')
        return 2
    except KeyboardInterrupt:
        print('error: "Interrupted; all launched peer processes were stopped."')
        if directory:
            print("logs: " + scalar(str(directory)))
        return 1
    except (OSError, subprocess.SubprocessError) as error:
        print("error: " + scalar(str(error)))
        if directory:
            print("logs: " + scalar(str(directory)))
        print('help: "Check the engine, project and output paths and retry."')
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
