#!/usr/bin/env python3
"""Run paid skirmish observations and summarize their retained evidence."""
from __future__ import annotations

import argparse
import json
import shlex
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_RESULTS = ROOT / "tmp/paid-progression"
DEFAULT_GODOT = ROOT / "tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot"
FIELDS = ("file", "factions", "result", "seconds")


def scalar(value):
    if isinstance(value, float) and value.is_integer():
        value = int(value)
    return json.dumps(value, ensure_ascii=False, allow_nan=False)


def table(name, rows, fields):
    print(f"{name}[{len(rows)}]{{{','.join(fields)}}}:")
    for row in rows:
        print("  " + ",".join(scalar(row.get(field)) for field in fields))


def identity():
    print("bin: " + scalar(str(Path(__file__).resolve()).replace(str(Path.home()), "~", 1)))
    print('description: "Run paid skirmish matches and inspect their progression evidence."')


def help_view(command):
    identity()
    if command == "run":
        table("flags", [
            {"flag": "--case", "default": "required", "meaning": "0..7; Frontier/Bastion/Helix match pairing"},
            {"flag": "--output", "default": "required", "meaning": "New JSON record path; existing evidence is preserved"},
            {"flag": "--research", "default": "combined", "meaning": "combined or none (original reference behavior)"},
            {"flag": "--repeats", "default": "1", "meaning": "Number of matches with successive recorded seeds"},
            {"flag": "--archive-prefix", "default": "none", "meaning": "Optional new path prefix for earned research and signature archives"},
            {"flag": "--strategy", "default": "ground-first", "meaning": "ground-first, air-first or screened-air"},
            {"flag": "--godot", "default": str(DEFAULT_GODOT), "meaning": "Godot 4.6 executable"},
            {"flag": "--wall-timeout", "default": "1800", "meaning": "Maximum real seconds; records remain bounded to 30 simulation minutes"},
        ], ("flag", "default", "meaning"))
        table("examples", [{"command": "python3 tests/playtest/run_progression.py run --case 4 --output tmp/paid-progression/bastion-frontier.json"},
                           {"command": "python3 tests/playtest/run_progression.py run --case 2 --research none --strategy air-first --output tmp/paid-progression/frontier-helix.json"}], ("command",))
    elif command == "show":
        print('usage: "python3 tests/playtest/run_progression.py show <record.json> [--full]"')
        print('detail: "Default shows outcomes and research events. --full emits the complete retained JSON."')
    else:
        print('usage: "python3 tests/playtest/run_progression.py [list --directory PATH --fields file,factions,result,seconds]"')
        print("default_directory: " + scalar(str(DEFAULT_RESULTS)))
        table("commands", [{"command": "run --help", "purpose": "Run one paid complete match"},
                           {"command": "show <record.json>", "purpose": "Inspect progression and research events"}], ("command", "purpose"))


class UsageError(Exception):
    pass


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise UsageError(message)


def parser():
    result = Parser(add_help=False)
    commands = result.add_subparsers(dest="command")
    listing = commands.add_parser("list", add_help=False)
    listing.add_argument("--directory", type=Path, default=DEFAULT_RESULTS)
    listing.add_argument("--fields", default=",".join(FIELDS))
    show = commands.add_parser("show", add_help=False)
    show.add_argument("file", type=Path)
    show.add_argument("--full", action="store_true")
    run = commands.add_parser("run", add_help=False)
    run.add_argument("--case", type=int, choices=range(8), required=True)
    run.add_argument("--output", type=Path, required=True)
    run.add_argument("--research", choices=("none", "combined"), default="combined")
    run.add_argument("--repeats", type=int, default=1)
    run.add_argument("--archive-prefix", type=Path)
    run.add_argument("--strategy", choices=("ground-first", "air-first", "screened-air"), default="ground-first")
    run.add_argument("--godot", type=Path, default=DEFAULT_GODOT)
    run.add_argument("--wall-timeout", type=int, default=1800)
    return result


def records(path):
    data = json.loads(path.read_text())
    if not isinstance(data, list) or not data or not all(isinstance(row, dict) and all(key in row for key in ("faction", "opponent", "result", "seconds")) for row in data):
        raise ValueError("File has no complete match records")
    return data


def summary(path, row):
    return {"file": str(path), "factions": f"{row['faction']} -> {row['opponent']}",
            "result": row["result"], "seconds": row["seconds"]}


def list_records(args):
    fields = tuple(args.fields.split(","))
    if not fields or any(field not in FIELDS for field in fields):
        raise UsageError("--fields must select file,factions,result,seconds")
    rows = []
    invalid = []
    for path in sorted(args.directory.glob("*.json")):
        try:
            rows.extend(summary(path, row) for row in records(path))
        except (OSError, ValueError, KeyError):
            invalid.append({"file": str(path), "status": "not a complete match record"})
    identity()
    table("matches", rows, fields)
    if not rows:
        print('status: "0 complete match records in this directory"')
    if invalid:
        table("other_files", invalid, ("file", "status"))
    table("help", [{"command": "python3 tests/playtest/run_progression.py run --help"},
                   {"command": "python3 tests/playtest/run_progression.py show <record.json>"}], ("command",))


def show_record(args):
    data = records(args.file)
    table("matches", [summary(args.file, row) for row in data], FIELDS)
    if args.full:
        print("record_json: " + scalar(json.dumps(data, ensure_ascii=False)))
        return
    for index, row in enumerate(data):
        events = []
        for event in row.get("research_events", []):
            for side in event["sides"]:
                events.append({"seconds": round(event["seconds"], 2), "faction": side["faction"],
                               "active": side["active"] or ("coordination" if side["coordination_left"] > 0 else ""),
                               "completed": ",".join((["coordination"] if side["coordination"] else []) + side["completed"])})
        table(f"research_{index}", events, ("seconds", "faction", "active", "completed"))
    raw = json.dumps(data, ensure_ascii=False)
    print("record_preview: " + scalar(raw[:1000]))
    if len(raw) > 1000:
        print("record_characters: " + str(len(raw)))
        print("help: " + scalar("Run " + shlex.join(["python3", "tests/playtest/run_progression.py", "show", str(args.file), "--full"]) + " for the complete record"))


def run_match(args):
    if args.wall_timeout <= 0:
        raise UsageError("--wall-timeout must be positive")
    if args.repeats <= 0:
        raise UsageError("--repeats must be positive")
    if not args.godot.is_file():
        raise UsageError("Executable missing; supply --godot with the Godot 4.6 executable")
    output = args.output.resolve()
    if output.suffix != ".json":
        raise UsageError("--output must name a new .json file")
    log = output.with_suffix(".log")
    if output.exists() or log.exists():
        raise UsageError("Evidence path already exists; choose a new --output filename")
    if args.archive_prefix:
        prefix = args.archive_prefix.resolve()
        if any(prefix.parent.glob(prefix.name + "-*.json")):
            raise UsageError("Archive prefix already has evidence; choose a new --archive-prefix")
        prefix.parent.mkdir(parents=True, exist_ok=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    command = [str(args.godot.resolve()), "--headless", "--path", str(ROOT), "--fixed-fps", "60",
               "--script", "tests/playtest/PaidProgressionMatches.gd", "--", f"--case={args.case}",
               f"--repeats={args.repeats}", "--ground-first", "--proactive", f"--research={args.research}",
               f"--strategy={args.strategy}", f"--output={output}"]
    if args.archive_prefix:
        command.append("--archive-prefix=" + str(prefix))
    with log.open("x") as stream:
        try:
            process = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=args.wall_timeout)
        except subprocess.TimeoutExpired:
            print('error: "Match exceeded its wall-clock bound"')
            print("log: " + scalar(str(log)))
            return 1
    raw = log.read_text(errors="replace")
    if process.returncode != 0 or "SCRIPT ERROR" in raw or "Parse Error" in raw:
        print('error: "Match did not complete its gameplay checks"')
        print("log: " + scalar(str(log)))
        print('help: "Inspect the retained log before running another observation"')
        return 1
    data = records(output)
    table("matches", [summary(output, row) for row in data], FIELDS)
    print("log: " + scalar(str(log)))
    print("help: " + scalar("Run " + shlex.join(["python3", "tests/playtest/run_progression.py", "show", str(output)]) + " to inspect research progression"))
    return 0


def main(argv):
    if "--help" in argv:
        help_view(argv[0] if argv and argv[0] in ("list", "run", "show") else "list")
        return 0
    try:
        args = parser().parse_args(argv or ["list"])
        if args.command == "run":
            return run_match(args)
        if args.command == "show":
            show_record(args)
        else:
            list_records(args)
        return 0
    except UsageError as error:
        print("error: " + scalar(str(error)))
        print('help: "Run python3 tests/playtest/run_progression.py run --help for accepted flags"')
        return 2
    except (OSError, ValueError, KeyError) as error:
        print("error: " + scalar(str(error)))
        print('help: "Check the file path and retained match log"')
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
