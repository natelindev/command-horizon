import shutil
import sys
import tempfile
from pathlib import Path
import build as b

b.RECORDER = b.VerificationLog(b.ROOT / "build/network-diagnostics", True)
with tempfile.TemporaryDirectory(prefix="network-diagnostic-") as temporary:
    work = Path(temporary)
    name = f"Godot_v{b.VERSION}_linux.x86_64"
    b.download(name + ".zip", work / "engine.zip")
    b.unpack(work / "engine.zip", work)
    engine = work / name
    b.download(f"Godot_v{b.VERSION}_export_templates.tpz", work / "templates.zip")
    b.unpack(work / "templates.zip", work)
    templates = Path.home() / ".local/share/godot/export_templates" / b.VERSION.replace("-", ".")
    shutil.copytree(work / "templates", templates, dirs_exist_ok=True)
    native = work / "native"
    b.run([sys.executable, b.ROOT / "tools/build_native.py", "--output", native])
    project = b.stage_release_project(work, native)
    b.isolate_review_profile(project, "network-diagnostic")
    b.import_release_project(engine, project)
    executable = work / "Game.x86_64"
    b.run([engine, "--headless", "--path", project, "--export-release", "Linux/X11", executable])
    isolated = work / "isolated"
    isolated.mkdir()
    shutil.copytree(native, isolated / "native/bin")
    for case in ["two-vs-two", "dedicated"]:
        try:
            b.run([sys.executable, b.ROOT / "tools/tests/run_network_regressions.py", "--engine", engine,
                   "--main-pack", executable, "--runtime-dir", isolated, "--no-native", "--case", case,
                   "--output", b.RECORDER.directory / "peers"], cwd=isolated, timeout=200)
        except RuntimeError as error:
            print(error)
failed = any(row["status"] != "passed" for row in b.RECORDER.report["checks"])
b.RECORDER.finish("failed" if failed else "passed")
raise SystemExit(1 if failed else 0)
