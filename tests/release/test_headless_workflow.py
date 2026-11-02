"""Headless admission, evidence retention and independent-check continuation."""
from contextlib import redirect_stderr
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
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("headless_build", ROOT / "tools/release/build.py")
BUILD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILD)


class HeadlessWorkflowTests(unittest.TestCase):
    def test_failure_retains_diagnostics_written_directly_in_fresh_profile(self):
        with tempfile.TemporaryDirectory(prefix="headless-profile-") as temporary:
            directory = Path(temporary)
            profile = directory / "profile"
            profile.mkdir()
            (profile / "navigation-original.json").write_text('{"failure":"preserved"}')
            recorder = BUILD.VerificationLog(directory / "logs", True)
            with patch.object(BUILD, "RECORDER", recorder):
                BUILD.retain_review_evidence(profile, recorder.directory)
            retained = Path(recorder.report["retained_failure_profile"])
            self.assertEqual((retained / "navigation-original.json").read_text(), '{"failure":"preserved"}')
            self.assertFalse(profile.exists())

    def test_review_archive_is_outside_package_and_normal_release_assets(self):
        package, artifacts = BUILD.release_directories(True, "unique-review")
        self.assertFalse(artifacts.is_relative_to(package))
        self.assertFalse(artifacts.is_relative_to(ROOT / "build/release-assets"))
        self.assertEqual(BUILD.release_directories(False, "ignored")[1], ROOT / "build/release-assets")

    def test_headless_resource_gate_never_constructs_graphical_or_xvfb_call(self):
        with patch.object(BUILD, "run") as run:
            BUILD.check_rendered_resources("godot", "game.pck", ROOT, True, BUILD.NATIVE_FLAGS)
        self.assertEqual(run.call_count, len(BUILD.RENDERED_TESTS))
        for call in run.call_args_list:
            self.assertIn("--headless", call.args[0])
            self.assertNotIn("--require-renderer", call.args[0])

    def test_normal_resource_gate_retains_actual_rendering_requirement(self):
        with patch.object(BUILD, "PLATFORM", "macos"), patch.object(BUILD, "run") as run:
            BUILD.check_rendered_resources("godot", "game.pck", ROOT)
        self.assertEqual(run.call_count, len(BUILD.RENDERED_TESTS) * 2)
        self.assertNotIn("--headless", run.call_args_list[-1].args[0])
        self.assertIn("--require-renderer", run.call_args_list[-1].args[0])

    def test_headless_guard_blocks_engine_and_xvfb_before_launch(self):
        with tempfile.TemporaryDirectory(prefix="headless-guard-") as temporary:
            recorder = BUILD.VerificationLog(Path(temporary) / "logs", True)
            with patch.object(BUILD.subprocess, "Popen") as spawn:
                for command in [["godot", "--script", "test.gd"], ["xvfb-run", "godot", "--headless"]]:
                    with self.assertRaisesRegex(RuntimeError, "blocked"):
                        recorder.run(command, ROOT, 1)
                spawn.assert_not_called()

    def test_python_network_wrapper_main_pack_is_not_misidentified_as_engine(self):
        with tempfile.TemporaryDirectory(prefix="headless-wrapper-") as temporary:
            recorder = BUILD.VerificationLog(Path(temporary) / "logs", True)
            process = SimpleNamespace(poll=lambda: 0, returncode=0)
            with (patch.object(BUILD.subprocess, "Popen", return_value=process) as spawn,
                  redirect_stderr(io.StringIO())):
                recorder.run([sys.executable, "run_network_regressions.py", "--main-pack", "game.pck"],
                             ROOT, 1)
            spawn.assert_called_once()
            self.assertEqual(recorder.report["checks"][0]["status"], "passed")

    def test_standalone_failure_does_not_skip_independent_remaining_checks(self):
        with patch.object(BUILD, "run", side_effect=[RuntimeError("first failed"), "ok"]) as run:
            failures = BUILD.check_standalone_manifest("godot", "pack", ROOT,
                                                      tests=["BehaviorRegression", "CombatRegression"])
        self.assertEqual(run.call_count, 2)
        self.assertEqual(failures, ["first failed"])

    def test_authoring_contract_uses_headless_source_without_package_remaps(self):
        with patch.object(BUILD, "run") as run:
            failures = BUILD.check_source_contracts("godot", ROOT, BUILD.NATIVE_FLAGS)
        self.assertEqual(failures, [])
        self.assertEqual(run.call_count, len(BUILD.SOURCE_TESTS))
        for call in run.call_args_list:
            command = call.args[0]
            self.assertIn("--headless", command)
            self.assertNotIn("--main-pack", command)
            self.assertEqual(command[command.index("--path") + 1], ROOT)
            self.assertEqual(call.kwargs["cwd"], ROOT)
            self.assertTrue(all(flag in command for flag in BUILD.NATIVE_FLAGS))

    def test_source_failure_keeps_independent_contracts_and_failure_evidence(self):
        with (patch.object(BUILD, "SOURCE_TESTS", ["RichTexturesRegression", "AnotherContract"]),
              patch.object(BUILD, "run", side_effect=[RuntimeError("Authoring failure"), "ok"]) as run):
            failures = BUILD.check_source_contracts("godot", ROOT)
        self.assertEqual(run.call_count, 2)
        self.assertEqual(failures, ["Authoring failure"])

    def test_packaged_startup_requires_ordinary_ready_menu_and_production_exit(self):
        with patch.object(BUILD, "run", return_value="") as run:
            with self.assertRaisesRegex(RuntimeError, "ordinary menu startup"):
                BUILD.check_packaged_startup("application", ROOT)
        command = run.call_args.args[0]
        self.assertIn("--headless", command)
        self.assertIn("--headless-startup-smoke", command)
        self.assertNotIn("--quit-after", command)
        with patch.object(BUILD, "run", return_value="Headless startup smoke: ordinary_menu_ready frames=120"):
            BUILD.check_packaged_startup("application", ROOT)

    def test_independent_diagnostic_and_startup_failures_still_reach_standalone_sweep(self):
        with tempfile.TemporaryDirectory(prefix="headless-pipeline-") as temporary:
            directory = Path(temporary)
            source = directory / "source-project"
            source.mkdir()
            (source / "project.godot").write_text('[application]\nconfig/name="Fixture"\n')
            engine = directory / "Godot"
            engine.write_bytes(b"fixture-engine")
            exported = []
            commands = []

            def command(args, **_kwargs):
                args = [str(value) for value in args]
                commands.append(args)
                if "--output" in args:
                    native = Path(args[args.index("--output") + 1])
                    native.mkdir()
                    (native / "solver.so").write_bytes(b"compiled-native")
                    (native / "copperfin.gdextension").write_text("fixture-descriptor")
                if "--export-release" in args:
                    path = Path(args[-1])
                    path.write_bytes(b"fixture-pack-and-executable")
                    exported.append(path)
                if any(value.endswith("/NativeCPUProfileRegression.gd") for value in args):
                    raise RuntimeError("CPU diagnostic failed")
                if any(value.endswith("/RichTexturesRegression.gd") for value in args):
                    raise RuntimeError("Authoring texture contract failed")
                if "--headless-startup-smoke" in args:
                    raise RuntimeError("Ordinary startup failed")
                return "4.7.2.stable.fixture"

            def archive_stage(work, *_args):
                project = work / "archive-project"
                project.mkdir()
                return project, directory / "archive-profile"

            argv = ["build.py", "--headless-only", "--godot", str(engine),
                    "--source-root", str(source), "--verification-output", str(directory / "logs")]
            with (patch.object(BUILD, "ROOT", source), patch.object(BUILD, "PLATFORM", "linux"),
                  patch.object(BUILD, "RECORDER", None), patch.object(sys, "argv", argv),
                  patch.object(BUILD.subprocess, "check_output", return_value="4.7.2.stable.fixture"),
                  patch.object(BUILD, "input_manifest", return_value="input-hash"),
                  patch.object(BUILD, "run", side_effect=command),
                  patch.object(BUILD, "stage_archive_validation", side_effect=archive_stage),
                  patch.object(BUILD, "isolate_review_profile", return_value=directory / "fresh-profile"),
                  patch.object(BUILD, "check_packaged_solver", side_effect=RuntimeError("Solver startup failed")),
                  patch.object(BUILD, "check_rendered_resources"),
                  patch.object(BUILD, "check_standalone_manifest", return_value=[]) as sweep,
                  self.assertRaisesRegex(RuntimeError, "4 verification checks failed")):
                BUILD.main()
            self.assertEqual(len(exported), 1)
            sweep.assert_called_once()
            authoring_index = next(index for index, args in enumerate(commands)
                                   if any(value.endswith("/RichTexturesRegression.gd") for value in args))
            export_index = next(index for index, args in enumerate(commands) if "--export-release" in args)
            self.assertLess(authoring_index, export_index)

    def test_fast_oversized_output_is_bounded_and_checkpointed_as_failure(self):
        with tempfile.TemporaryDirectory(prefix="bounded-output-") as temporary:
            recorder = BUILD.VerificationLog(Path(temporary) / "logs", True)
            with patch.object(BUILD, "MAX_LOG_BYTES", 1024), redirect_stderr(io.StringIO()):
                with self.assertRaisesRegex(RuntimeError, "limit"):
                    recorder.run([sys.executable, "-c", "print('x'*16384)"], ROOT, 3)
            row = json.loads((recorder.directory / "report.json").read_text())["checks"][0]
            self.assertEqual(row["status"], "failed")
            self.assertLessEqual(Path(row["log"]).stat().st_size, 1024)

    @unittest.skipIf(os.name == "nt", "POSIX PID-liveness assertion")
    def test_timeout_keeps_output_and_stops_its_real_child(self):
        with tempfile.TemporaryDirectory(prefix="bounded-timeout-") as temporary:
            directory = Path(temporary)
            pidfile = directory / "pid"
            recorder = BUILD.VerificationLog(directory / "logs", True)
            code = f"import os,time;open({str(pidfile)!r},'w').write(str(os.getpid()));print('started',flush=True);time.sleep(60)"
            started = time.monotonic()
            with redirect_stderr(io.StringIO()), self.assertRaisesRegex(RuntimeError, "Timed out"):
                recorder.run([sys.executable, "-c", code], ROOT, .2)
            self.assertLess(time.monotonic() - started, 4)
            row = recorder.report["checks"][0]
            self.assertIn("started", Path(row["log"]).read_text())
            self.assertEqual(row["status"], "failed")
            with self.assertRaises(ProcessLookupError):
                os.kill(int(pidfile.read_text()), 0)


if __name__ == "__main__":
    unittest.main()
