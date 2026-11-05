"""Unexpected engine failures and leaks must fail an otherwise-zero exit code."""
from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("release_build", ROOT / "tools/release/build.py")
BUILD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILD)


class ReleaseOutputTests(unittest.TestCase):
    def test_clean_import_bootstraps_font_then_verifies_original_settings(self):
        original = b'[gui]\ntheme/custom_font="res://font.ttf"\n'
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            config = project / "project.godot"
            config.write_bytes(original)
            seen = []
            with patch.object(BUILD, "run", side_effect=lambda args: seen.append(config.read_bytes())):
                BUILD.import_release_project("godot", project)
            self.assertEqual(seen, [b'[gui]\n', original])
            self.assertEqual(config.read_bytes(), original)

    def test_failed_bootstrap_restores_settings_and_does_not_hide_errors(self):
        original = b'[gui]\ntheme/custom_font="res://font.ttf"\n'
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            config = project / "project.godot"
            config.write_bytes(original)
            with patch.object(BUILD, "run", side_effect=RuntimeError("Import failed")) as run:
                with self.assertRaisesRegex(RuntimeError, "Import failed"):
                    BUILD.import_release_project("godot", project)
            self.assertEqual(run.call_count, 1)
            self.assertEqual(config.read_bytes(), original)

    def test_translations_bootstrap_even_without_a_custom_font(self):
        original = (b'[internationalization]\r\n'
                    b'locale/translations=PackedStringArray("res://ui.en.translation")\r\n')
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            config = project / "project.godot"
            config.write_bytes(original)
            seen = []
            with patch.object(BUILD, "run", side_effect=lambda args: seen.append(config.read_bytes())):
                BUILD.import_release_project("godot", project)
            self.assertEqual(seen, [b'[internationalization]\r\n', original])
            self.assertEqual(config.read_bytes(), original)

    def _run(self, output, code=0):
        result = SimpleNamespace(returncode=code, stdout=output)
        with (patch.object(BUILD.subprocess, "run", return_value=result),
              redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO())):
            BUILD.run(["engine", "--headless"])

    def test_engine_errors_and_actual_leak_warnings_are_fatal(self):
        for output in [
            "ERROR: Invalid navigation RID",
            "SCRIPT ERROR: Invalid assignment",
            "Parse Error: Unexpected token",
            "WARNING: 2 RIDs of type CanvasItem were leaked.",
            "WARNING: 1 RID allocation of type Shader was leaked at exit.",
            "WARNING: ObjectDB instances leaked at exit.",
            "WARNING: 4 ObjectDB instances were leaked at exit (run with `--verbose` for details).",
            "WARNING: 3 resources still in use at exit.",
        ]:
            with self.subTest(output=output), self.assertRaises(RuntimeError):
                self._run(output)

    def test_style_warnings_do_not_fail_release_checks(self):
        self._run('WARNING: The local variable "point" shadows a class member.\n0 failures\n')

    def test_nonzero_exit_remains_fatal(self):
        with self.assertRaises(RuntimeError):
            self._run("", code=1)


if __name__ == "__main__":
    unittest.main()
