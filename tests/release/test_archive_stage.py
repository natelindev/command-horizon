"""Check copied archive staging without launching or changing the game project."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("release_build", ROOT / "tools/release/build.py")
BUILD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILD)


class ArchiveStageTests(unittest.TestCase):
    def test_startup_export_failure_restores_distribution_entry_point(self):
        with tempfile.TemporaryDirectory(prefix="release-startup-") as temporary:
            work = Path(temporary)
            project = work / "project"
            project.mkdir()
            original = '[application]\nrun/main_scene="res://source/Main.tscn"\n'
            (project / "project.godot").write_text(original)
            with patch.object(BUILD, "run", side_effect=RuntimeError("export failed")):
                with self.assertRaisesRegex(RuntimeError, "export failed"):
                    BUILD.check_packaged_solver("engine", project, "test", work / "native", work)
            self.assertEqual((project / "project.godot").read_text(), original)

    def test_startup_requires_fixture_completion_from_actual_template(self):
        with tempfile.TemporaryDirectory(prefix="release-startup-") as temporary:
            work = Path(temporary)
            project = work / "project"
            project.mkdir()
            original = '[application]\nrun/main_scene="res://source/Main.tscn"\n'
            (project / "project.godot").write_text(original)
            native = work / "native"
            native.mkdir()
            (native / "solver.so").write_bytes(b"fresh")
            with patch.object(BUILD, "PLATFORM", "linux"), patch.object(BUILD, "run", return_value=""):
                with self.assertRaisesRegex(RuntimeError, "did not complete"):
                    BUILD.check_packaged_solver("engine", project, "test", native, work)
            self.assertEqual((project / "project.godot").read_text(), original)

    def test_release_uses_fresh_native_and_private_cache(self):
        with tempfile.TemporaryDirectory(prefix="release-stage-") as temporary:
            work = Path(temporary)
            project = work / "source-project"
            (project / "source").mkdir(parents=True)
            (project / "source/unit.gd").write_text("original source")
            (project / "native/bin").mkdir(parents=True)
            (project / "native/bin/stale.dylib").write_bytes(b"stale")
            (project / ".godot/imported").mkdir(parents=True)
            (project / ".godot/imported/cached").write_bytes(b"cache")
            (project / "project.godot").write_text('[application]\nconfig/name="Original"\n')
            native = work / "fresh-native"
            native.mkdir()
            (native / "universal.dylib").write_bytes(b"fresh")
            with patch.object(BUILD, "ROOT", project):
                stage = BUILD.stage_release_project(work, native)
            self.assertFalse((stage / "source").is_symlink())
            (project / "source/unit.gd").write_text("concurrent edit")
            self.assertEqual((stage / "source/unit.gd").read_text(), "original source")
            self.assertEqual([p.name for p in (stage / "native/bin").iterdir()], ["universal.dylib"])
            self.assertEqual((project / "native/bin/stale.dylib").read_bytes(), b"stale")
            (stage / ".godot/imported/cached").write_bytes(b"changed")
            self.assertEqual((project / ".godot/imported/cached").read_bytes(), b"cache")

    def test_source_manifest_is_complete_and_unique(self):
        self.assertEqual(len(BUILD.TESTS), len(set(BUILD.TESTS)))
        self.assertIn("OwnershipRegression", BUILD.TESTS)
        self.assertIn("RichTexturesRegression", BUILD.SOURCE_TESTS)
        self.assertNotIn("RichTexturesRegression", BUILD.TESTS)
        for name in BUILD.TESTS + BUILD.SOURCE_TESTS:
            self.assertTrue((ROOT / "tests/headless" / (name + ".gd")).is_file(), name)
        for name in BUILD.RENDERED_TESTS:
            self.assertTrue((ROOT / "tests/rendered" / (name + ".gd")).is_file(), name)

    def test_private_staging_discards_derived_export_cache_and_preserves_imports(self):
        with tempfile.TemporaryDirectory(prefix="export-cache-stage-") as temporary:
            work = Path(temporary)
            project = work / "project"
            cache = project / ".godot"
            (cache / "exported").mkdir(parents=True)
            (cache / "imported").mkdir()
            (cache / "exported/roster.res").write_bytes(b"stale-script-defaults")
            (cache / "imported/terrain.ctex").write_bytes(b"valid-import")
            native = work / "native"
            native.mkdir()
            stage = BUILD.stage_release_project(work, native, project)
            self.assertFalse((stage / ".godot/exported").exists())
            self.assertEqual((stage / ".godot/imported/terrain.ctex").read_bytes(), b"valid-import")
            self.assertEqual((cache / "exported/roster.res").read_bytes(), b"stale-script-defaults")

    def test_corpus_is_copied_and_user_profile_is_unique(self):
        with tempfile.TemporaryDirectory(prefix="archive-stage-") as temporary:
            work = Path(temporary)
            project = work / "source-project"
            project.mkdir()
            for folder in ["source", "assets", "native", ".godot", "tests/headless",
                           "tests/fixtures", "docs/playtests/example"]:
                (project / folder).mkdir(parents=True, exist_ok=True)
            original = ('[application]\nconfig/name="Original"\n'
                        'config/use_custom_user_dir=true\n'
                        'config/custom_user_dir_name="ExistingProfile"\n')
            (project / "project.godot").write_text(original)
            (project / "tests/headless/ArchivedSnapshotRegression.gd").write_text("extends SceneTree\n")
            corpus = project / "docs/playtests/example/example.json"
            corpus.write_bytes(b'{"preserved": "payload"}\n')
            (corpus.parent / "SHA256SUMS").write_text("retained checksum\n")
            (project / "tests/fixtures/archive.json").write_text("{}\n")
            with patch.object(BUILD, "ROOT", project):
                stage, profile = BUILD.stage_archive_validation(work)
            staged_corpus = stage / "docs/playtests/example/example.json"
            self.assertEqual(staged_corpus.read_bytes(), corpus.read_bytes())
            self.assertFalse(staged_corpus.is_symlink())
            self.assertNotEqual(staged_corpus.stat().st_ino, corpus.stat().st_ino)
            self.assertTrue((stage / "docs/playtests/example/SHA256SUMS").is_file())
            self.assertEqual((stage / "source").resolve(), (project / "source").resolve())
            config = (stage / "project.godot").read_text()
            self.assertIn("OpenRTSReleaseArchive/" + work.name, config)
            self.assertEqual(config.count("config/use_custom_user_dir="), 1)
            self.assertNotIn("ExistingProfile", config)
            self.assertFalse(profile.exists())
            self.assertEqual((project / "project.godot").read_text(), original)


if __name__ == "__main__":
    unittest.main()
