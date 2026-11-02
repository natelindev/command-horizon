"""Failure handling of the process runner; gameplay is checked by real Godot peers."""
from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "network_runner", ROOT / "tools/tests/run_network_regressions.py")
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class NetworkRunnerTests(unittest.TestCase):
    def test_pack_can_select_an_isolated_runtime_for_external_support(self):
        with tempfile.TemporaryDirectory(prefix="network-pack-") as temporary:
            directory = Path(temporary).resolve()
            pack = directory / "game.pck"
            pack.write_bytes(b"fixture")
            runtime = directory / "runtime"
            runtime.mkdir()
            options = RUNNER.options(["--engine", sys.executable, "--main-pack", str(pack),
                                      "--runtime-dir", str(runtime)])
            self.assertEqual(options.runtime_dir, runtime)
            default = RUNNER.options(["--engine", sys.executable, "--main-pack", str(pack)])
            self.assertEqual(default.runtime_dir, directory)

    def test_completion_markers_and_actual_leaks_are_checked(self):
        with tempfile.TemporaryDirectory(prefix="network-output-") as temporary:
            log = Path(temporary) / "peer.log"
            entry = {"role": "spectator", "log": log,
                     "process": SimpleNamespace(returncode=0)}
            marker = "Network group spectator: 0 failures\n"
            log.write_text(marker + "WARNING: local variable shadows a member\n")
            self.assertEqual(RUNNER.verify("groups", entry)["status"], "passed")
            for message in ["ERROR: invalid owner", "SCRIPT ERROR: invalid property",
                            "WARNING: 2 RIDs of type Shader were leaked.",
                            "WARNING: ObjectDB instances leaked at exit.",
                            "WARNING: 4 ObjectDB instances were leaked at exit (run with `--verbose` for details).",
                            "WARNING: 1 resource still in use at exit."]:
                log.write_text(marker + message)
                self.assertEqual(RUNNER.verify("groups", entry)["status"], "failed")

    def test_missing_engine_is_usage_error(self):
        output = io.StringIO()
        with redirect_stdout(output):
            result = RUNNER.main(["--engine", "/nonexistent/network-engine"])
        self.assertEqual(result, 2)
        self.assertIn("error:", output.getvalue())
        self.assertIn("--engine", output.getvalue())

    def test_help_lists_exported_and_source_targets(self):
        output = io.StringIO()
        with redirect_stdout(output):
            result = RUNNER.main(["--help"])
        self.assertEqual(result, 0)
        self.assertIn("--main-pack", output.getvalue())
        self.assertIn("--project", output.getvalue())

    @unittest.skipIf(os.name == "nt", "Executable fixture uses a POSIX shebang")
    def test_silent_process_is_stopped_at_readiness_deadline(self):
        # A deliberately silent subprocess checks the runner's failure path,
        # without substituting for any networking or gameplay verification.
        with tempfile.TemporaryDirectory(prefix="network runner ") as temporary:
            directory = Path(temporary)
            marker = directory / "child.pid"
            engine = directory / "silent-engine"
            engine.write_text(
                f"#!{sys.executable} -S\nimport os, time\n"
                f"open({str(marker)!r}, 'w').write(str(os.getpid()))\n"
                "time.sleep(60)\n", encoding="utf-8")
            engine.chmod(0o700)
            output = io.StringIO()
            started = time.monotonic()
            with redirect_stdout(output):
                result = RUNNER.main([
                    "--engine", str(engine), "--case", "outcome",
                    "--startup-timeout", "1", "--output", str(directory / "logs")])
            self.assertEqual(result, 1)
            self.assertLess(time.monotonic() - started, 8)
            self.assertIn("readiness deadline", output.getvalue())
            self.assertTrue(marker.is_file())
            with self.assertRaises(ProcessLookupError):
                os.kill(int(marker.read_text()), 0)
            reports = list((directory / "logs").glob("*/results.json"))
            self.assertEqual(len(reports), 1)
            report = json.loads(reports[0].read_text())
            self.assertEqual(len(report["results"]), 2)
            self.assertTrue(all(row["status"] == "failed" for row in report["results"]))


if __name__ == "__main__":
    unittest.main()
