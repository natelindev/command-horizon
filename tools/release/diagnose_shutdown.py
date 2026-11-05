import shutil
import sys
import tempfile
from pathlib import Path
import build as b

logs = b.ROOT / "build/shutdown-diagnostics"
b.RECORDER = b.VerificationLog(logs, True)
with tempfile.TemporaryDirectory(prefix="shutdown-diagnostic-") as temporary:
    work = Path(temporary)
    b.download(f"Godot_v{b.VERSION}_macos.universal.zip", work / "engine.zip")
    b.unpack(work / "engine.zip", work)
    engine = work / "Godot.app/Contents/MacOS/Godot"
    b.download(f"Godot_v{b.VERSION}_export_templates.tpz", work / "templates.zip")
    b.unpack(work / "templates.zip", work)
    templates = Path.home() / "Library/Application Support/Godot/export_templates" / b.VERSION.replace("-", ".")
    shutil.copytree(work / "templates", templates, dirs_exist_ok=True)
    native = work / "native"
    b.run([sys.executable, b.ROOT / "tools/build_native.py", "--output", native, "--universal"])
    project = b.stage_release_project(work, native)
    b.isolate_review_profile(project, "shutdown-diagnostic")
    b.import_release_project(engine, project)
    archive = work / "Game.zip"
    b.run([engine, "--headless", "--path", project, "--export-release", "macOS", archive])
    b.run(["ditto", "-x", "-k", archive, work / "package"])
    app = next((work / "package").glob("*.app"))
    executable = b.application_executable(app)
    pack = next((app / "Contents/Resources").glob("*.pck"))
    b.install_native_support(executable, native, app)
    isolated = work / "isolated"
    isolated.mkdir()
    shutil.copytree(native, isolated / "native/bin")
    commands = [
        [executable, "--headless", "--", "--headless-startup-smoke"],
        [engine, "--headless", "--main-pack", pack, "--fixed-fps", "60", "--script", "res://tests/headless/PlayerRosterRegression.gd"],
        [executable, "--headless", "--verbose", "--", "--headless-startup-smoke"],
        [engine, "--headless", "--verbose", "--main-pack", pack, "--fixed-fps", "60", "--script", "res://tests/headless/PlayerRosterRegression.gd"],
        [engine, "--headless", "--verbose", "--path", project, "--fixed-fps", "60", "--script", "res://tests/headless/PlayerRosterRegression.gd"],
    ]
    commands += [[engine, "--headless", "--main-pack", pack, "--fixed-fps", "60", "--script", "res://tests/headless/PlayerRosterRegression.gd"] for _ in range(8)]
    commands += [[engine, "--headless", "--main-pack", pack, "--fixed-fps", "60", "--script", "res://tests/headless/RuntimeShutdownRegression.gd"]]
    for command in commands:
        try:
            b.run(command, cwd=isolated, timeout=180)
        except RuntimeError as error:
            print(error)
failed = any(row["status"] != "passed" for row in b.RECORDER.report["checks"])
b.RECORDER.finish("failed" if failed else "passed")
raise SystemExit(1 if failed else 0)
