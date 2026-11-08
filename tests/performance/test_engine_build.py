"""Packaging contracts for the optional macOS engine."""

import argparse
from contextlib import redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("engine_build", ROOT / "tools/performance/engine/build.py")
BUILD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILD)


class EnginePackageTests(unittest.TestCase):
    def test_fixture_entry_is_isolated_and_game_entry_preserved(self):
        config = '[application]\nrun/main_scene="res://source/Main.tscn"\n[rendering]\nfoo=1\n'
        self.assertEqual(BUILD.set_entry(config, "game", "private"), config)
        result = BUILD.set_entry(config, "battle", "private")
        self.assertIn('run/main_loop_type="BattlePerformanceMainLoop"', result)
        self.assertIn('config/custom_user_dir_name="private"', result)
        self.assertIn('[rendering]\nfoo=1', result)
        with self.assertRaises(BUILD.UsageError):
            BUILD.set_entry(result, "startup", "second")

    def test_signed_app_is_idempotent_but_modified_artifacts_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            project = root / "project"
            project.mkdir()
            (project / "project.godot").write_text("test")
            engine = root / "engine"
            engine.write_bytes(b"unsigned engine")
            editor = root / "editor"
            editor.write_bytes(b"editor")
            output = root / "output"
            app = output / "Game.app"
            executable = app / "Contents/MacOS/Game"
            executable.parent.mkdir(parents=True)
            # A sibling directory must not be mistaken for the executable.
            (executable.parent / "native").mkdir()
            executable.write_bytes(b"signed engine differs from input")
            (app / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": "Game"}))
            pack = app / "Contents/Resources/Game.pck"
            pack.parent.mkdir()
            pack.write_bytes(b"game pack")
            archive = output / "Game.zip"
            archive.write_bytes(b"archive")
            receipt = {
                "signature": {"recipe_sha256": BUILD.sha256(BUILD.__file__),
                              "engine_sha256": BUILD.sha256(engine), "editor_sha256": BUILD.sha256(editor),
                              "source_sha256": "source", "entry": "game"},
                "application": str(app), "archive": str(archive),
                "signed_engine_sha256": BUILD.sha256(executable),
                "pack_sha256": BUILD.sha256(pack), "archive_sha256": BUILD.sha256(archive),
            }
            (output / "package.json").write_text(json.dumps(receipt))
            args = argparse.Namespace(engine=engine, editor=editor, project=project,
                                      output=output, entry="game")
            with patch.object(BUILD, "require_host"), patch.object(BUILD, "project_digest", return_value="source"):
                stdout = io.StringIO()
                with redirect_stdout(stdout):
                    BUILD.package(args)
                self.assertIn("status: ready", stdout.getvalue())
                for artifact in (executable, pack, archive):
                    original = artifact.read_bytes()
                    artifact.write_bytes(b"changed")
                    with self.assertRaisesRegex(BUILD.UsageError, "choose a new directory"):
                        BUILD.package(args)
                    artifact.write_bytes(original)

    def test_usage_errors_are_structured_and_noninteractive(self):
        with patch("sys.argv", ["build.py", "package", "--engine", "absent"]):
            with self.assertRaises(BUILD.UsageError):
                BUILD.main()
        with patch("sys.argv", ["build.py", "--help"]), redirect_stdout(io.StringIO()) as output:
            with self.assertRaises(SystemExit) as result:
                BUILD.main()
        self.assertEqual(result.exception.code, 0)
        self.assertTrue(output.getvalue().startswith('help: "'))
        self.assertNotIn("\nusage:", output.getvalue())


if __name__ == "__main__":
    unittest.main()
