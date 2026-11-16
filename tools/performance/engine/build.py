#!/usr/bin/env python3
"""Build and package the pinned Apple Silicon performance runtime."""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
VERSION = "4.7.2-stable"
ARCHIVE_SHA256 = "a18ce0ccec3ecc40b0dd6c4f5132ca934e9fb7c2979717940ff32aee1eb35481"
ARCHIVE_URL = f"https://github.com/godotengine/godot/releases/download/{VERSION}/godot-{VERSION}.tar.xz"
PATCHES = [HERE / f"godot-4.7.2-{part}.patch" for part in
           ("threaded-rendering", "empty-instance-transforms", "runtime-feature")]
DEFAULT_WORK = ROOT / "build/performance-engine"


class UsageError(Exception):
    pass


def scalar(value):
    """TOON primitive output; all command responses are flat objects."""
    if value is None:
        return "null"
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, int):
        return str(value)
    value = str(value)
    quote = (not value or value != value.strip(" \t") or value in ("true", "false", "null")
             or re.fullmatch(r"[+-]?[0-9]+(?:\.[0-9]+)?(?:e[+-]?[0-9]+)?", value, re.I)
             or value.startswith(("-", "#"))
             or any(c in ':"\\[]{},' or ord(c) < 32 for c in value))
    if not quote:
        return value
    escapes = {'\\': '\\\\', '"': '\\"', '\n': '\\n', '\r': '\\r', '\t': '\\t'}
    return '"' + ''.join(escapes.get(c, f"\\u{ord(c):04x}" if ord(c) < 32 else c)
                         for c in value) + '"'


def emit(**values):
    sys.stdout.write("\n".join(f"{key}: {scalar(value)}" for key, value in values.items()))
    sys.stdout.flush()


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise UsageError(message)

    def print_help(self, file=None):
        emit(help=self.format_help().rstrip())


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json(path):
    return json.loads(path.read_text()) if path.is_file() else {}


def record(path, data):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(data, indent=2) + "\n")
    temporary.replace(path)


def run(command, log, cwd=None, timeout=3600):
    print("Running " + str(command[0]), file=sys.stderr, flush=True)
    log.write("\n$ " + repr([str(part) for part in command]) + "\n")
    log.flush()
    subprocess.run([str(part) for part in command], cwd=cwd, stdout=log,
                   stderr=subprocess.STDOUT, timeout=timeout, check=True)


def require_host():
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise UsageError("This runtime supports only Apple Silicon macOS")
    if sys.version_info < (3, 12):
        raise UsageError("Use Python 3.12 or newer for safe archive extraction")


def build(args):
    require_host()
    if not 1 <= args.jobs <= 64:
        raise UsageError("--jobs must be between 1 and 64")
    if args.profile and not args.profile.is_file():
        raise UsageError("--profile must name an existing merged LLVM .profdata file")
    if args.archive and not args.archive.is_file():
        raise UsageError("--archive must name an existing Godot source archive")
    work = args.work_dir.resolve()
    work.mkdir(parents=True, exist_ok=True)
    archive = args.archive.resolve() if args.archive else work / f"godot-{VERSION}.tar.xz"
    if not archive.exists():
        print("Downloading pinned engine source", file=sys.stderr, flush=True)
        temporary = archive.with_suffix(archive.suffix + ".download")
        urllib.request.urlretrieve(ARCHIVE_URL, temporary)
        temporary.replace(archive)
    if sha256(archive) != ARCHIVE_SHA256:
        raise UsageError("Source archive checksum does not match the pinned Godot release")
    recipe = {"recipe_sha256": sha256(__file__), "archive_sha256": ARCHIVE_SHA256,
              "patches": {p.name: sha256(p) for p in PATCHES},
              "profile_sha256": sha256(args.profile) if args.profile else None,
              "platform": "macos-arm64", "cpu": "apple-m1", "scons": "4.11.1"}
    identity = hashlib.sha256(json.dumps(recipe, sort_keys=True).encode()).hexdigest()[:16]
    directory = work / identity
    directory.mkdir(exist_ok=True)
    binary = directory / "godot.macos.template_release.arm64"
    receipt = directory / "build.json"
    previous = read_json(receipt)
    if binary.is_file() and previous.get("binary_sha256") == sha256(binary):
        emit(status="ready", binary=binary, receipt=receipt)
        return
    logpath = directory / "build.log"
    recipe.update(status="building", log=str(logpath), feature="copperfin_optimized_macos")
    record(receipt, recipe)
    with logpath.open("a") as log:
        source = directory / f"godot-{VERSION}"
        if not source.exists():
            with tempfile.TemporaryDirectory(prefix="extract-", dir=directory) as temporary:
                with tarfile.open(archive) as package:
                    package.extractall(temporary, filter="data")
                staged = Path(temporary) / source.name
                for patch in PATCHES:
                    run(["git", "apply", "--check", patch], log, cwd=staged)
                    run(["git", "apply", patch], log, cwd=staged)
                staged.rename(source)
        else:
            # Never silently build a partially applied patch after an interrupted run.
            for patch in PATCHES:
                run(["git", "apply", "--reverse", "--check", patch], log, cwd=source)
        venv = work / "venv"
        python = venv / "bin/python"
        if not python.exists():
            run([sys.executable, "-m", "venv", venv], log)
        run([python, "-m", "pip", "install", "--disable-pip-version-check", "SCons==4.11.1"], log)
        if not (source / "bin/build_deps/accesskit").is_dir():
            run([python, "misc/scripts/install_accesskit.py"], log, cwd=source)
        cflags = "-mcpu=apple-m1"
        linkflags = ""
        if args.profile:
            profile = directory / "training.profdata"
            shutil.copy2(args.profile, profile)
            profile_flag = shlex.quote(f"-fprofile-use={profile}")
            cflags += f" {profile_flag} -Wno-profile-instr-unprofiled -Wno-profile-instr-out-of-date"
            linkflags = profile_flag
        command = [python, "-m", "SCons", "platform=macos", "arch=arm64",
                   "target=template_release", "production=yes", "optimize=speed",
                   "debug_symbols=no", "vulkan=no", "metal=yes", "profiler=none", "lto=thin",
                   "ccflags=" + cflags, "linkflags=" + linkflags, f"-j{args.jobs}"]
        recipe["command"] = [str(part) for part in command]
        record(receipt, recipe)
        run(command, log, cwd=source, timeout=7200)
        shutil.copy2(source / "bin/godot.macos.template_release.arm64", binary)
    recipe.update(status="built", binary=str(binary), binary_sha256=sha256(binary))
    record(receipt, recipe)
    record(work / "latest.json", {"receipt": str(receipt), "binary": str(binary)})
    emit(status="built", binary=binary, receipt=receipt, log=logpath)


def project_digest(source):
    """Hash the files that author the exported game and its native library."""
    digest = hashlib.sha256()
    for entry in ("project.godot", "export_presets.cfg", "icon.svg", "source", "assets",
                  "tests", "native/pose_packer", "tools/build_native.py", "tools/release/build.py"):
        path = source / entry
        files = sorted(p for p in path.rglob("*") if p.is_file()) if path.is_dir() else [path]
        for file in files:
            if file.name.endswith(".pyc") or "__pycache__" in file.parts:
                continue
            digest.update(str(file.relative_to(source)).encode())
            digest.update(bytes.fromhex(sha256(file)))
    return digest.hexdigest()


def set_entry(config, entry, isolated):
    if entry == "game":
        return config
    loop = "FormationStartupMainLoop" if entry == "startup" else "BattlePerformanceMainLoop"
    config, count = re.subn(r'(?m)^run/main_scene="[^"\n]*"$',
                           'run/main_scene="res://tests/headless/FormationStartupBootstrap.tscn"\n'
                           f'run/main_loop_type="{loop}"', config, count=1)
    if count != 1 or config.count("run/main_loop_type=") != 1:
        raise UsageError("Project must use its ordinary game entry point before packaging")
    config = re.sub(r'(?m)^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n', "", config)
    return config.replace('[application]\n', '[application]\nconfig/use_custom_user_dir=true\n'
                          f'config/custom_user_dir_name="{isolated}"\n', 1)


def package(args):
    require_host()
    for label, path in (("--engine", args.engine), ("--editor", args.editor)):
        if not path.is_file():
            raise UsageError(f"{label} must name an existing executable")
    source = args.project.resolve()
    if not (source / "project.godot").is_file():
        raise UsageError("--project must contain project.godot")
    output = args.output.resolve()
    signature = {"recipe_sha256": sha256(__file__),
                 "engine_sha256": sha256(args.engine), "editor_sha256": sha256(args.editor),
                 "source_sha256": project_digest(source), "entry": args.entry}
    previous = read_json(output / "package.json")
    if previous.get("signature") == signature and Path(previous.get("application", "")).is_dir():
        app = Path(previous["application"])
        with (app / "Contents/Info.plist").open("rb") as file:
            executable = app / "Contents/MacOS" / plistlib.load(file)["CFBundleExecutable"]
        packs = list((app / "Contents/Resources").glob("*.pck"))
        archive = Path(previous.get("archive", ""))
        if (sha256(executable) == previous.get("signed_engine_sha256")
                and len(packs) == 1 and sha256(packs[0]) == previous.get("pack_sha256")
                and archive.is_file() and sha256(archive) == previous.get("archive_sha256")):
            emit(status="ready", application=app, receipt=output / "package.json")
            return
    if output.exists() and any(output.iterdir()):
        raise UsageError("--output must be empty or contain this exact completed build; choose a new directory")
    output.mkdir(parents=True, exist_ok=True)
    logpath = output / "package.log"
    spec = importlib.util.spec_from_file_location("release_build", ROOT / "tools/release/build.py")
    release = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(release)
    with logpath.open("w") as log, contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
        # Use the existing signing/import helpers with a single bounded artifact log.
        with tempfile.TemporaryDirectory(prefix="stage-", dir=output) as temporary:
            work = Path(temporary)
            native = work / "native"
            run([sys.executable, ROOT / "tools/build_native.py", "--universal", "--output", native], log)
            staged = release.stage_release_project(work, native, source)
            release.import_release_project(str(args.editor.resolve()), staged)
            config = (staged / "project.godot").read_text()
            isolated = "CommandHorizonBuildValidation/" + output.name
            (staged / "project.godot").write_text(set_entry(config, "startup", isolated))
            exported = work / "startup.zip"
            run([args.editor.resolve(), "--headless", "--path", staged,
                 "--export-release", "macOS", exported], log)
            run(["ditto", "-x", "-k", exported, output], log)
            apps = list(output.glob("*.app"))
            if len(apps) != 1:
                raise UsageError("Export did not produce exactly one application")
            app = apps[0]
            executable = release.application_executable(app)
            shutil.copy2(args.engine, executable)
            release.install_native_support(executable, native, app)
            startup = release.run([executable, "--headless", "--fixed-fps", "60", "--",
                                   "--require-native-solver", "--require-optimized-runtime"], timeout=180)
            if "Formation startup: first200_ms=" not in startup or "failures=0" not in startup:
                raise UsageError("The packaged optimized startup fixture did not complete")
            (staged / "project.godot").write_text(set_entry(config, args.entry, isolated))
            game_pack = work / "game.pck"
            run([args.editor.resolve(), "--headless", "--path", staged,
                 "--export-pack", "macOS", game_pack], log)
            packs = list((app / "Contents/Resources").glob("*.pck"))
            if len(packs) != 1:
                raise UsageError("Exported application has an ambiguous game pack")
            shutil.copy2(game_pack, packs[0])
            release.install_native_support(executable, native, app)
            archive = output / f"CommandHorizon-{args.entry}-optimized-macos-arm64.zip"
            run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, archive], log)
            receipt = {"signature": signature, "application": str(app), "archive": str(archive),
                       "signed_engine_sha256": sha256(executable),
                       "pack_sha256": sha256(packs[0]), "archive_sha256": sha256(archive),
                       "startup": "passed", "performance_qualified": False, "log": str(logpath)}
            record(output / "package.json", receipt)
    emit(status="packaged", application=app, archive=archive, receipt=output / "package.json")


def main():
    parser = Parser(description=__doc__, epilog="Examples: build.py build --jobs 6; build.py package --engine ENGINE --editor EDITOR --output OUTPUT")
    commands = parser.add_subparsers(dest="command", parser_class=Parser)
    status = commands.add_parser("status", help="Show the most recent local engine build")
    status.add_argument("--work-dir", type=Path, default=DEFAULT_WORK)
    build_parser = commands.add_parser("build", help="Verify source, apply patches and compile a release template")
    build_parser.add_argument("--work-dir", type=Path, default=DEFAULT_WORK)
    build_parser.add_argument("--archive", type=Path, help="Use the pinned source archive already on disk")
    build_parser.add_argument("--profile", type=Path, help="Optional merged LLVM training profile; omitted by default")
    build_parser.add_argument("--jobs", type=int, default=6)
    package_parser = commands.add_parser("package", help="Export a playable app or an isolated release fixture")
    package_parser.add_argument("--engine", type=Path, required=True)
    package_parser.add_argument("--editor", type=Path, required=True)
    package_parser.add_argument("--output", type=Path, required=True)
    package_parser.add_argument("--project", type=Path, default=ROOT)
    package_parser.add_argument("--entry", choices=("game", "battle", "startup"), default="game")
    args = parser.parse_args()
    if args.command == "build":
        build(args)
    elif args.command == "package":
        package(args)
    else:
        work = getattr(args, "work_dir", DEFAULT_WORK).resolve()
        latest = read_json(work / "latest.json")
        emit(bin=str(Path(__file__).resolve()).replace(str(Path.home()), "~", 1),
             description=__doc__, status="built" if latest else "No local engine build",
             binary=latest.get("binary"), receipt=latest.get("receipt"),
             help="python3 tools/performance/engine/build.py build --jobs 6" if not latest else
                  "python3 tools/performance/engine/build.py package --engine ENGINE --editor EDITOR --output OUTPUT")


if __name__ == "__main__":
    try:
        main()
    except UsageError as error:
        emit(error=str(error), help="Correct the indicated argument and rerun the same command")
        raise SystemExit(2)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        emit(error="Build or packaging did not complete", detail=str(error)[:600],
             help="Inspect build.log or package.log in the selected output directory before retrying")
        raise SystemExit(1)
