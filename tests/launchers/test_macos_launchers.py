"""Run with python3 -m unittest discover -s tests/launchers -v."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
ENGINE = Path("tmp/tooling/godot-4.7.2/Godot.app/Contents/MacOS/Godot")
LAUNCHERS = {
    "play-skirmish.command": "res://source/main-menu/Play.tscn",
    "play-bastion.command": "res://source/match/BastionDemo.tscn",
}


@unittest.skipUnless(shutil.which("zsh") and shutil.which("git"), "Requires zsh and git")
class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="rts launcher ")
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name).resolve()
        self.main = self.folder / "main checkout"
        self.worktree = self.folder / "linked checkout"
        self.main.mkdir()
        self.log = self.folder / "engine.log"
        self.env = dict(os.environ, HOME=str(self.folder), ENGINE_LOG=str(self.log))
        self.git("init", str(self.main))
        for launcher in LAUNCHERS:
            shutil.copy2(ROOT / launcher, self.main / launcher)
        self.git("-C", str(self.main), "add", ".")
        self.git("-C", str(self.main), "-c", "user.name=Test", "-c",
                 "user.email=test@example.invalid", "-c", "commit.gpgsign=false",
                 "commit", "-m", "Launcher fixture")
        self.git("-C", str(self.main), "worktree", "add", "-b", "fixture", str(self.worktree))
        self.engine(self.main)

    def git(self, *args):
        subprocess.run(["git", *args], check=True, capture_output=True, env=self.env)

    def engine(self, checkout, version="4.7.2.stable.official.fixture"):
        engine = checkout / ENGINE
        engine.parent.mkdir(parents=True, exist_ok=True)
        engine.write_text(
            '#!/bin/sh\n'
            f'if [ "$1" = "--version" ]; then echo "{version}"; exit 0; fi\n'
            'printf "%s\\n" "$0" "$@" >> "$ENGINE_LOG"\n'
            'if [ "$1" = "--headless" ]; then exit "${IMPORT_EXIT:-0}"; fi\n'
        )
        engine.chmod(0o755)

    def launch(self, checkout, expected_engine, import_exit=0):
        for launcher, scene in LAUNCHERS.items():
            with self.subTest(launcher=launcher):
                self.log.unlink(missing_ok=True)
                result = subprocess.run(
                    ["zsh", str(checkout / launcher)], cwd=self.folder,
                    env=dict(self.env, IMPORT_EXIT=str(import_exit)),
                    capture_output=True, text=True, timeout=10,
                )
                self.assertEqual(result.returncode, import_exit, result.stdout + result.stderr)
                expected = [str(expected_engine / ENGINE), "--headless", "--editor",
                            "--path", str(checkout), "--import"]
                if not import_exit:
                    expected += [str(expected_engine / ENGINE), "--path", str(checkout), scene]
                self.assertEqual(self.log.read_text().splitlines(), expected)

    def test_linked_worktree_uses_main_engine_and_current_project(self):
        self.launch(self.worktree, self.main)

    def test_main_checkout_still_launches(self):
        self.launch(self.main, self.main)

    def test_local_engine_takes_priority(self):
        self.engine(self.worktree)
        self.launch(self.worktree, self.worktree)

    def test_wrong_local_version_is_skipped(self):
        self.engine(self.worktree, "4.6.stable.official.fixture")
        self.launch(self.worktree, self.main)

    def test_import_failure_does_not_start_game(self):
        self.launch(self.worktree, self.main, import_exit=7)


if __name__ == "__main__":
    unittest.main()
