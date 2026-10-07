"""The runner must retain failures even when Godot returns exit zero."""
import contextlib
import importlib.util
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("runner", Path(__file__).with_name("run_progression.py"))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class RunnerTest(unittest.TestCase):
    def invoke(self, argv):
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            status = runner.main(argv)
        return status, stream.getvalue()

    def test_empty_and_usage(self):
        with tempfile.TemporaryDirectory() as directory:
            code, text = self.invoke(["list", "--directory", directory])
            self.assertEqual(code, 0)
            self.assertIn("0 complete match records", text)
        for args in (["run"], ["list", "--fields", "unknown"], ["run", "--case", "9"]):
            code, text = self.invoke(args)
            self.assertEqual(code, 2)
            self.assertIn("error:", text)

    def test_complete_failure_and_evidence_preservation(self):
        for mode in ("complete", "script_error", "missing_record", "timeout"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix="match space ") as directory:
                output = Path(directory) / "record $(literal).json"
                executable = Path(directory) / "godot"
                executable.touch()
                args = ["run", "--case", "0", "--strategy", "screened-air", "--output", str(output), "--godot", str(executable)]
                def run(command, **kwargs):
                    self.assertIn("--output=" + str(output.resolve()), command)
                    self.assertIn("--strategy=screened-air", command)
                    self.assertNotIn("shell", kwargs)
                    if mode == "timeout":
                        raise subprocess.TimeoutExpired(command, 1)
                    if mode != "missing_record":
                        output.write_text(json.dumps([{"faction": "frontier", "opponent": "bastion", "seconds": 100, "result": "Victory"}]))
                    if mode == "script_error":
                        kwargs["stdout"].write("SCRIPT ERROR: failed before completion\n")
                    return subprocess.CompletedProcess(command, 0)
                with patch.object(runner.subprocess, "run", side_effect=run) as process:
                    code, text = self.invoke(args)
                    self.assertEqual(code, 0 if mode == "complete" else 1)
                    self.assertTrue(output.with_suffix(".log").exists())
                    if mode != "complete":
                        self.assertIn("error:", text)
                    before = output.with_suffix(".log").read_bytes()
                    second, _ = self.invoke(args)
                    self.assertEqual(second, 2)
                    self.assertEqual(process.call_count, 1)
                    self.assertEqual(output.with_suffix(".log").read_bytes(), before)

    def test_malformed_record_and_help(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "partial.json"
            path.write_text('[{"result": "Victory", "seconds": 20}]')
            code, text = self.invoke(["show", str(path)])
            self.assertEqual(code, 1)
            self.assertIn("no complete match records", text)
        for command in ([], ["run"], ["show"], ["list"]):
            code, text = self.invoke(command + ["--help"])
            self.assertEqual(code, 0)
            self.assertIn("description:", text)


if __name__ == "__main__":
    unittest.main()
