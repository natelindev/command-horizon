import os
import shutil
import sys
import tempfile
from pathlib import Path
import build as b

b.RECORDER = b.VerificationLog(b.ROOT / "build/network-diagnostics", False)
with tempfile.TemporaryDirectory(prefix="network-diagnostic-") as temporary:
    work = Path(temporary)
    name = f"Godot_v{b.VERSION}_{b.ENGINE_SUFFIX[b.PLATFORM]}"
    b.download(name + ".zip", work / "engine.zip")
    b.unpack(work / "engine.zip", work)
    engine = work / name
    b.download(f"Godot_v{b.VERSION}_export_templates.tpz", work / "templates.zip")
    b.unpack(work / "templates.zip", work)
    templates = (Path(os.environ["APPDATA"]) / "Godot" if b.PLATFORM == "windows" else Path.home() / ".local/share/godot") / "export_templates" / b.VERSION.replace("-", ".")
    shutil.copytree(work / "templates", templates, dirs_exist_ok=True)
    native = work / "native"
    b.run([sys.executable, b.ROOT / "tools/build_native.py", "--output", native, *(["--download-toolchain"] if b.PLATFORM == "windows" else [])])
    project = b.stage_release_project(work, native)
    b.isolate_review_profile(project, "network-diagnostic")
    b.import_release_project(engine, project)
    executable = work / ("Game.exe" if b.PLATFORM == "windows" else "Game.x86_64")
    b.run([engine, "--headless", "--path", project, "--export-release", "Windows Desktop" if b.PLATFORM == "windows" else "Linux/X11", executable])
    isolated = work / "isolated"
    isolated.mkdir()
    shutil.copytree(native, isolated / "native/bin")
    b.check_rendered_resources(engine, executable, isolated, False)
    for case in ["session", "groups", "two-vs-two"]:
        try:
            b.run([sys.executable, b.ROOT / "tools/tests/run_network_regressions.py", "--engine", engine,
                   "--main-pack", executable, "--runtime-dir", isolated, *([] if b.PLATFORM == "windows" else ["--no-native"]), "--case", case,
                   "--output", b.RECORDER.directory / "peers"], cwd=isolated, timeout=1000)
        except RuntimeError as error:
            print(error)
failed = any(row["status"] != "passed" for row in b.RECORDER.report["checks"])
b.RECORDER.finish("failed" if failed else "passed")
raise SystemExit(1 if failed else 0)
