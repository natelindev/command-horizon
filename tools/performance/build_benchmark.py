"""Export the native Windows heavy-team benchmark without editing project.godot."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]


def source_manifest():
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for folder in ("source", "tests", "native/pose_packer", "native/bin")
            for path in (ROOT / folder).rglob("*")
            if path.is_file() and not path.name.endswith((".import", ".gd.uid"))}


def junction(target, source):
    if target.exists():
        if target.resolve() != source.resolve():
            raise RuntimeError(f"Existing stage directory has a different target: {target}")
        return
    quote = lambda path: "'" + str(path).replace("'", "''") + "'"
    subprocess.run(["powershell.exe", "-NoProfile", "-Command",
                    f"New-Item -ItemType Junction -Path {quote(target)} "
                    f"-Target {quote(source)} | Out-Null"], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("This staging helper currently supports native Windows builds")
    engine = args.godot.resolve()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    stage = ROOT / "tmp/heavy-team-project"
    stage.mkdir(parents=True, exist_ok=True)
    for name in ("assets", "source", "tests", "native", "media", "tools", ".godot"):
        junction(stage / name, ROOT / name)
    for name in ("icon.svg", "icon.svg.import", "export_presets.cfg"):
        shutil.copy2(ROOT / name, stage / name)
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    project = project.replace('run/main_scene="res://source/Main.tscn"',
                              'run/main_scene="res://tests/rendered/HeavyTeamBootstrap.tscn"\n'
                              'run/main_loop_type="HeavyTeamPerformanceMainLoop"')
    project = project.replace('config/name="Open RTS"',
                              'config/name="Copperfin Heavy 2v2 Benchmark"\n'
                              'config/use_custom_user_dir=true\n'
                              'config/custom_user_dir_name="CopperfinHeavy2v2Benchmark"')
    (stage / "project.godot").write_text(project, encoding="utf-8")
    user_data = Path(os.environ["APPDATA"]) / "Godot/app_userdata"
    profile = Path(os.environ["APPDATA"]) / "CopperfinHeavy2v2Benchmark"
    profile.mkdir(parents=True, exist_ok=True)
    original_options = user_data / "Open RTS/options.tres"
    if original_options.exists():
        shutil.copy2(original_options, profile / "options.tres")
    manifest = source_manifest()
    metadata = {"created_unix": time.time(), "stage": str(stage),
                "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "source_files": manifest,
                "source_digest": hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest(),
                "project_sha256": hashlib.sha256(project.encode()).hexdigest(),
                "note": "Only the entry point and isolated user directory differ from the game project."}
    for label, options in (("import", ["--editor", "--quit"]),
                           ("export", ["--export-release", "Windows Desktop", str(output)])):
        logfile = output.with_suffix(f".{label}.log")
        print(f"Benchmark {label}: {logfile}", flush=True)
        with logfile.open("w", encoding="utf-8") as stream:
            result = subprocess.run([str(engine), "--headless", "--path", str(stage), *options],
                                    cwd=stage, stdout=stream, stderr=subprocess.STDOUT, timeout=900)
        log = logfile.read_text(encoding="utf-8", errors="replace")
        if result.returncode or any(message in log for message in ("SCRIPT ERROR:", "Parse Error:", "ERROR: Failed to export")):
            print(log[-12000:])
            raise RuntimeError(f"Benchmark {label} failed: {result.returncode}")
    shutil.copytree(ROOT / "native/bin", output.parent / "native/bin", dirs_exist_ok=True)
    current = source_manifest()
    if current != manifest:
        changed = [name for name in set(current) | set(manifest) if current.get(name) != manifest.get(name)]
        raise RuntimeError("Source changed during benchmark export: " + ", ".join(sorted(changed)[:10]))
    metadata["executable_sha256"] = hashlib.sha256(output.read_bytes()).hexdigest()
    metadata["bytes"] = output.stat().st_size
    output.with_suffix(".metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"Exported benchmark: {output}", flush=True)


if __name__ == "__main__":
    main()
