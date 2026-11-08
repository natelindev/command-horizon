"""Build and verify a desktop release with downloaded or locally installed tools."""

import argparse
from contextlib import ExitStack
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import signal
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
PLATFORM = os.environ.get("RTS_RELEASE_PLATFORM", {
    "win32": "windows", "darwin": "macos",
}.get(sys.platform, "linux"))
VERSION = "4.7.2-stable"
PRESETS = {"linux": "Linux/X11", "windows": "Windows Desktop", "macos": "macOS"}
ENGINE_SUFFIX = {"linux": "linux.x86_64", "windows": "win64.exe", "macos": "macos.universal"}
TESTS = [
    "NativeKernelStartupRegression", "GroundContactFilteringRegression",
    "BehaviorRegression", "UnitAnimationRegression",
    "ChassisSpringRegression", "ParallelPoseRegression",
    "InfantryPoseWorkerRegression", "DecoupledPoseRegression",
    "UnitRegistryRegression", "PlayerRosterRegression", "VisibilityRefreshRegression",
    "InfantryRedesignRegression", "InfantryMeshBatchRegression", "ModelDesignRegression",
    "InfantryDeathGroundRegression", "InfantryMotionRegression",
    "TerrainGroundingRegression", "CombatRegression", "AntiAirPriorityRegression",
    "TechnologyRegression", "TechnologyAIRegression", "WeaponModeRegression",
    "ResearchTilesRegression", "ResearchQueueRegression", "StructureActivityRegression",
    "PersistentCaptureRegression",
    "CampaignInteriorRegression", "HeroCampaignRegression", "SkirmishPickerRegression",
    "WorkerDistributionRegression", "CargoReturnRegression", "ResourceFieldRegression",
    "GarrisonCombatExitRegression", "PointOfInterestRegression",
    "MapMetricsRegression", "GlacierHarvestRegression", "TerrainSightRegression",
    "CliffMeshRegression", "AuthoredRelayRegression",
    "AuthoredGarrisonRegression",
    "SaveNavigationTimingRegression",
    "ContactApproachRegression", "NavigationRegression", "NavigationProjectionRegression", "MapPlayabilityRegression",
    "MapPreviewRegression", "MusicRegression",
    "SelectionBatchRegression",
    "ProjectileSystemRegression", "ProjectilePhysicsRegression",
    "FixedWingFlightRegression", "FixedWingSaveRegression",
    "AirSaveContinuityRegression", "RotorcraftCombatRegression", "FrontierCombatRegression",
    "AirfieldOperationsRegression", "GroundHeightAlignmentRegression", "GroundCrowdRecoveryRegression",
    "SkirmishBuildReadinessRegression",
    "SkirmishCompositionRegression", "SkirmishDepositSelectionRegression",
    "UnitAbilitiesRegression", "AlliedDefenseStatisticsRegression",
    "PresentationFeaturesRegression", "SettingsRegression", "UnitInfoTextRegression",
    "BattleHudProductionRegression", "ProductionBatchRegression", "BattleAftermathRegression",
    "MapPassageRegression", "ObjectMaterialsRegression", "RuntimeShutdownRegression",
    "EnvironmentEffectsRegression", "WaterFlowRegression", "WaterHybridRegression",
    "StrategicPolishRegression", "MicroControlsRegression",
    "CameraFeelRegression", "BattleFeedbackRegression", "OwnershipRegression", "SpatialQueryRegression",
    "GroundVehicleMotionRegression", "MixedArmyMovementRegression",
    "CombatPresentationRegression", "AttackPhaseRegression", "ChargeGeometryRegression", "ManualParticlesRegression",
    "CombatAudioRegression",
    "VehicleDamageVisualsRegression", "VehicleDamageAudioRegression",
    "EndgamePresentationRegression", "CommanderEliminationRegression",
    "OpeningGuidanceRegression", "PlacementFeedbackRegression",
    "DirectOrdersRegression", "HudRecoveryRoutesRegression", "CommandCardRefreshRegression", "AbilityTrayRegression",
    "KeyBindingsRegression", "SelectionRosterRegression",
    "RallyRetargetRegression", "RallyControlsRegression", "LocalizationRegression",
    "ShieldComponentRegression", "AutonomousAssemblyRegression",
    "MobileGarrisonRegression", "PassengerHudRegression", "BunkerSaveRegression",
    "BattlefieldSalvageRegression", "OpticalCloakRegression",
    "FactionAsymmetryRegression", "FactionStrategyRegression", "FactionLocalizationRegression",
    "BastionFortificationRegression", "FrontierAirContractsRegression",
    "MacroEconomyRegression", "PowerGridRegression", "PowerSupportScalingRegression",
    "EconomicSitesRegression", "EconomicAIRegression", "EconomyPersistenceRegression",
    "FluxResearchRegression", "HelixPartialCargoRegression", "HelixPhaseArrivalRegression",
    "LegacyHomeFieldsSaveRegression", "LegacyHomeNavigationRegression",
    "HoverNavigationRegression", "NavigationConnectivityRegression",
    "TacticalFormationsRegression", "ImmediatePointOrderRegression",
    "OrderActivationRegression", "FormationStartupRegression", "FormationPlanningRegression",
    "GroundTravelBudgetRegression",
    "FormationOverviewSaveRegression", "SelectionHealthRegression",
    "CampaignHubRegression", "CampaignHubLoopRegression", "CampaignHubSalvageRegression",
    "CampaignBriefingRegression", "CombatVoiceRegression",
    "StructureCollapseRegression", "ScorchLifetimeRegression",
    "NetworkFoundationRegression", "AuthoritativeFrameRegression", "StateHashRegression",
    "ScenarioEditorRegression",
]
SOURCE_TESTS = ["RichTexturesRegression"]
TEST_ARGUMENTS = {
    # Timing gates need an actual renderer and an isolated performance run.
    "TacticalFormationsRegression": ["--functional-only"],
    "CampaignBriefingRegression": ["--require-complete"],
}
# Whether a dummy-server pass is meaningful before the actual GPU check.
RENDERED_TESTS = {
    "SceneResourceLifetimeRegression": ("gl_compatibility", True),
    "ChargeSparkRegression": ("gl_compatibility", False),
    "SelectionShaderRegression": ("gl_compatibility", False),
    "EmptyMeshTransformRegression": ("gl_compatibility", False),
    "PosePaletteRegression": ("forward_plus", False),
}
NATIVE_FLAGS = ["--enable-native-kernels", "--native-unit-state", "--native-crowd-runtime"]
MAX_LOG_BYTES = 16 * 1024 * 1024
RECORDER = None


def output_error(output, code):
    fatal = ("SCRIPT ERROR:", "ERROR:", "Parse Error:")
    leaks = re.search(
        r"\bRIDs?\b[^\n]*\bleaked\b|\bObjectDB instances (?:were )?leaked\b|\bresources? still in use\b",
        output, re.IGNORECASE)
    if code:
        return f"Process exited with code {code}"
    if any(message in output for message in fatal) or leaks:
        return "Engine error or shutdown leak reported"
    return ""


class VerificationLog:
    """Keep bounded evidence and checkpoint every check, including failures."""
    def __init__(self, directory, headless_only=False):
        self.directory = Path(directory)
        self.engine_paths = set()
        self.directory.mkdir(parents=True, exist_ok=False)
        self.report = {"status": "running", "headless_only": headless_only,
                       "started_utc": datetime.now(timezone.utc).isoformat(),
                       "deferred": (["graphical_resource_lifetime", "visual_review", "strict_performance"]
                                    if headless_only else ["visual_review", "independent_strict_performance"]),
                       "checks": []}
        self.save()

    def save(self):
        temporary = self.directory / "report.json.tmp"
        temporary.write_text(json.dumps(self.report, ensure_ascii=False, indent=2) + "\n",
                             encoding="utf-8")
        temporary.replace(self.directory / "report.json")

    def finish(self, status):
        for check in self.report["checks"]:
            if check["status"] == "running":
                check.update(status="interrupted", error="Workflow stopped before completion")
        self.report.update(status=status, completed_utc=datetime.now(timezone.utc).isoformat())
        self.save()

    def run(self, args, cwd, timeout):
        args = [str(arg) for arg in args]
        engine = (str(Path(args[0]).resolve()) in self.engine_paths
                  or Path(args[0]).name.lower().startswith("godot"))
        if self.report["headless_only"] and (
            Path(args[0]).name.lower().startswith("xvfb")
            or (engine and "--headless" not in args and "--version" not in args)
        ):
            raise RuntimeError("Headless-only verification blocked a graphical engine command")
        label = (Path(args[args.index("--script") + 1]).stem if "--script" in args else
                 "export" if "--export-release" in args else
                 "import" if "--editor" in args else Path(args[0]).stem)
        path = self.directory / f"{len(self.report['checks']) + 1:03d}-{label}.log"
        row = {"name": label, "argv": args, "cwd": str(cwd), "status": "running",
               "started_utc": datetime.now(timezone.utc).isoformat(), "log": str(path),
               "timeout_seconds": timeout, "timed_out": False, "output_limit_exceeded": False}
        self.report["checks"].append(row)
        self.save()
        started = time.monotonic()
        problem = ""
        process = None
        print(f"Checking {label}; log={path}", file=sys.stderr, flush=True)
        try:
            with path.open("wb") as stream:
                process = subprocess.Popen(args, cwd=cwd, stdin=subprocess.DEVNULL, stdout=stream,
                                           stderr=subprocess.STDOUT, start_new_session=os.name != "nt",
                                           creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0)
                while process.poll() is None:
                    if path.stat().st_size > MAX_LOG_BYTES:
                        row["output_limit_exceeded"] = True
                        problem = "Diagnostic output exceeded the16MiB limit"
                        break
                    if time.monotonic() - started >= timeout:
                        row["timed_out"] = True
                        problem = f"Timed out after {timeout}s"
                        break
                    time.sleep(.05)
        except OSError as error:
            problem = str(error)
        finally:
            if process is not None and process.poll() is None:
                stop_process(process)
        if path.stat().st_size > MAX_LOG_BYTES:
            row["output_limit_exceeded"] = True
            problem = problem or "Diagnostic output exceeded the16MiB limit"
            with path.open("r+b") as stream:
                stream.truncate(MAX_LOG_BYTES)
        output = path.read_text(encoding="utf-8", errors="replace")
        code = process.returncode if process is not None else None
        problem = problem or output_error(output, code)
        row.update(status="failed" if problem else "passed", exit_code=code,
                   duration_seconds=round(time.monotonic() - started, 3), error=problem)
        self.save()
        if problem:
            print(output[-8192:], file=sys.stderr, flush=True)
            raise RuntimeError(f"{label}: {problem}; see {path}")
        return output


def stop_process(process):
    """Only stop the process family this check created."""
    if process.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                       capture_output=True, timeout=10, check=False)
    else:
        # Python's network runner handles Ctrl-C by draining its private peer
        # groups. Give it enough time before terminating our own process group.
        try:
            os.killpg(process.pid, signal.SIGINT)
        except ProcessLookupError:
            process.wait(timeout=3)
            return
        try:
            process.wait(timeout=30)
            return
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        if os.name != "nt":
            os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=3)


def run(args, cwd=ROOT, timeout=900):
    if RECORDER is not None:
        return RECORDER.run(args, cwd, timeout)
    print(f"Running: {subprocess.list2cmdline([str(arg) for arg in args])}",
          file=sys.stderr, flush=True)
    result = subprocess.run([str(arg) for arg in args], cwd=cwd, timeout=timeout,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            encoding="utf-8", errors="replace")
    print(result.stdout, file=sys.stderr, flush=True)
    if output_error(result.stdout, result.returncode):
        raise RuntimeError(f"Command failed ({result.returncode}): {args}")
    return result.stdout


def unpack(archive, destination):
    with zipfile.ZipFile(archive) as package:
        package.extractall(destination)
        if os.name != "nt":
            for entry in package.infolist():
                mode = entry.external_attr >> 16
                if stat.S_ISREG(mode):
                    (destination / entry.filename).chmod(mode & 0o777)


def download(name, destination):
    url = f"https://github.com/godotengine/godot/releases/download/{VERSION}/{name}"
    urllib.request.urlretrieve(url, destination)


def link_directory(source, target):
    if os.name == "nt":
        quote = lambda path: "'" + str(path).replace("'", "''") + "'"
        subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
                        f"New-Item -ItemType Junction -Path {quote(target)} "
                        f"-Target {quote(source)} | Out-Null"], check=True, timeout=30)
    else:
        target.symlink_to(source, target_is_directory=True)


def copy_directory(source, target, ignore=None):
    # APFS clones have independent inodes and copy-on-write contents. Importing
    # or concurrent source edits cannot mutate the frozen copy.
    if sys.platform == "darwin" and ignore is None:
        result = subprocess.run(["/bin/cp", "-cRpL", str(source), str(target)], capture_output=True)
        if result.returncode == 0:
            return
        shutil.rmtree(target, ignore_errors=True)
    shutil.copytree(source, target, ignore=ignore)


def stage_release_project(work, native_build, source_root=None):
    """Keep mutable workspace source and ignored kernels out of export provenance."""
    source_root = source_root or ROOT
    stage = work / "release-project"
    stage.mkdir()
    for path in source_root.iterdir():
        if path.name in (".git", ".godot", "native", "build", "tmp", "__pycache__", ".DS_Store"):
            continue
        if path.is_dir():
            copy_directory(path, stage / path.name)
        else:
            shutil.copy2(path, stage / path.name)
    cache = source_root / ".godot"
    if cache.is_dir():
        shutil.copytree(cache, stage / ".godot",
                        ignore=shutil.ignore_patterns("editor", "shader_cache", "exported"))
    shutil.copytree(native_build, stage / "native/bin")
    return stage


def stage_archive_validation(work, project=None, source_root=None):
    """Use copied archives and a unique user profile; source/assets stay shared."""
    project = project or ROOT
    source_root = source_root or ROOT
    stage = work / "archive-project"
    stage.mkdir()
    for name in ("source", "assets", "native", ".godot"):
        source = project / name
        if not source.exists():
            continue
        target = stage / name
        link_directory(source, target)
    for folder in ("docs/playtests", "tests/fixtures"):
        for path in (source_root / folder).rglob("*"):
            if path.is_file() and (path.suffix == ".json" or path.name == "SHA256SUMS"):
                destination = stage / path.relative_to(source_root)
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, destination)
    script = Path("tests/headless/ArchivedSnapshotRegression.gd")
    (stage / script).parent.mkdir(parents=True)
    shutil.copy2(source_root / script, stage / script)
    for name in ("icon.svg", "icon.svg.import"):
        if (source_root / name).is_file():
            shutil.copy2(source_root / name, stage / name)
    directory = "OpenRTSReleaseArchive/" + work.name
    config = (project / "project.godot").read_text(encoding="utf-8")
    config = re.sub(r'(?m)^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n', "", config)
    config, count = re.subn(
        r'(?m)^config/name="[^"\n]*"$',
        'config/name="Open RTS Archive Verification"\nconfig/use_custom_user_dir=true\n'
        f'config/custom_user_dir_name="{directory}"', config, count=1)
    if count != 1:
        raise RuntimeError("Could not isolate the archive-validation user profile")
    (stage / "project.godot").write_text(config, encoding="utf-8")
    app_data = (Path(os.environ["APPDATA"]) if sys.platform == "win32" else
                Path.home() / "Library/Application Support" if sys.platform == "darwin" else
                Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share"))
    profile = app_data / directory
    if profile.exists():
        raise RuntimeError("Archive-validation profile already exists; refusing to reuse user state")
    return stage, profile


def import_release_project(engine, project):
    """Import startup resources before loading the original staged settings."""
    config = project / "project.godot"
    original = config.read_bytes()
    bootstrap, count = re.subn(
        rb'(?m)^(?:theme/custom_font|locale/translations)=[^\r\n]*\r?\n', b'', original)
    command = [engine, "--headless", "--path", project, "--editor", "--quit"]
    if count:
        # Godot loads the font and generated translations before its importer.
        # A checkout has import remaps and CSVs but no generated resources yet.
        # Only the private staging copy uses default startup resources during
        # this first pass; all diagnostics remain fatal.
        # Godot 4.7.2's parallel CSV importer can race when generating several
        # translation resources on a clean checkout. Serialize this first pass.
        bootstrap += b'\n[editor]\nimport/use_multiple_threads=false\n'
        try:
            config.write_bytes(bootstrap)
            run(command)
        finally:
            config.write_bytes(original)
    run(command)


def check_rendered_resources(engine, pack, isolated, headless_only=False, flags=None):
    """Exercise GPU allocations and pose compute, plus supported dummy-server checks."""
    for test, (renderer, supports_headless) in RENDERED_TESTS.items():
        script = f"res://tests/rendered/{test}.gd"
        if supports_headless:
            run([engine, "--headless", "--main-pack", pack, "--fixed-fps", "60",
                 "--script", script, *(["--", *flags] if flags else [])], cwd=isolated, timeout=120)
        if headless_only:
            continue
        # This gate checks real GPU allocations. Hosted runners have no audio
        # device, so select silent audio explicitly instead of logging a driver error.
        command = [engine, "--audio-driver", "Dummy", "--main-pack", pack, "--rendering-method", renderer,
                   "--fixed-fps", "60", "--script", script, "--", "--require-renderer", *(flags or [])]
        if PLATFORM == "linux" and not os.environ.get("DISPLAY"):
            display = shutil.which("xvfb-run")
            if display is None:
                raise RuntimeError("Rendered release checks require Xvfb/Mesa or a working DISPLAY")
            command = [display, "-a", "-s", "-screen 0 1280x720x24", *command]
        run(command, cwd=isolated, timeout=120)


def install_native_support(executable, native_build, app=None):
    """Install the solver at the exact adjacent path used by match startup."""
    native_target = executable.parent / "native/bin"
    if RECORDER is not None:
        RECORDER.engine_paths.add(str(executable.resolve()))
    if native_target.exists():
        shutil.rmtree(native_target)
    shutil.copytree(native_build, native_target)
    if app is not None:
        for library in native_target.glob("*.dylib"):
            run(["codesign", "--force", "--sign", "-", library])
        run(["codesign", "--force", "--deep", "--sign", "-",
             "--preserve-metadata=entitlements,requirements,flags", app])
        run(["codesign", "--verify", "--deep", "--strict", app])


def application_executable(app):
    with (app / "Contents/Info.plist").open("rb") as metadata:
        name = plistlib.load(metadata)["CFBundleExecutable"]
    if Path(name).name != name:
        raise RuntimeError("Exported application has an invalid executable name")
    executable = app / "Contents/MacOS" / name
    if not executable.is_file():
        raise RuntimeError("Exported application's declared executable is missing")
    return executable


def check_packaged_solver(engine, project, preset, native_build, work):
    """Release templates ignore --script; export a real fixture entry point."""
    directory = work / "formation-startup-package"
    directory.mkdir()
    filename = {"linux": "FormationStartup.x86_64", "windows": "FormationStartup.exe",
                "macos": "FormationStartup.zip"}[PLATFORM]
    exported = directory / filename
    config = project / "project.godot"
    original = config.read_text(encoding="utf-8")
    modified, count = re.subn(
        r'(?m)^run/main_scene="[^"\n]*"$',
        'run/main_scene="res://tests/headless/FormationStartupBootstrap.tscn"\n'
        'run/main_loop_type="FormationStartupMainLoop"', original, count=1)
    if count != 1 or 'run/main_loop_type=' in original:
        raise RuntimeError("Could not isolate the native startup qualification entry point")
    try:
        config.write_text(modified, encoding="utf-8")
        run([engine, "--headless", "--path", project, "--export-release", preset, exported])
    finally:
        config.write_text(original, encoding="utf-8")
    app = None
    if PLATFORM == "macos":
        run(["ditto", "-x", "-k", exported, directory])
        app = next(directory.glob("*.app"))
        executable = application_executable(app)
    else:
        executable = exported
    install_native_support(executable, native_build, app)
    isolated = directory / "empty-cwd"
    isolated.mkdir()
    output = run([executable, "--headless", "--fixed-fps", "60", "--",
                  "--require-native-solver"], cwd=isolated, timeout=120)
    if not re.search(r"Formation startup: first200_ms=.* failures=0", output):
        raise RuntimeError("Actual release template did not complete its native startup fixture")


def check_packaged_startup(executable, directory):
    # Engine --quit-after bypasses the game's audio/resource shutdown path.
    # The ordinary menu supplies this headless-only readiness/cleanup probe.
    output = run([executable, "--headless", "--", "--headless-startup-smoke"],
                 cwd=directory, timeout=60)
    if "Headless startup smoke: ordinary_menu_ready frames=120" not in output:
        raise RuntimeError("Actual release template did not complete ordinary menu startup")


def input_manifest(project, destination):
    files = {}
    for name in ("source", "assets", "tests", "tools", "native/pose_packer"):
        for path in sorted((project / name).rglob("*")):
            if path.is_file() and "__pycache__" not in path.parts:
                files[str(path.relative_to(project))] = hashlib.sha256(path.read_bytes()).hexdigest()
    for name in ("project.godot", "export_presets.cfg"):
        files[name] = hashlib.sha256((project / name).read_bytes()).hexdigest()
    digest = hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()
    destination.write_text(json.dumps({"sha256": digest, "files": files}, indent=2) + "\n",
                           encoding="utf-8")
    return digest


def check_standalone_manifest(engine, pack, isolated, flags=None, tests=None):
    failed = []
    for test in TESTS if tests is None else tests:
        arguments = (flags or []) + TEST_ARGUMENTS.get(test, [])
        try:
            run([engine, "--headless", "--main-pack", pack, "--fixed-fps", "60",
                 "--script", f"res://tests/headless/{test}.gd",
                 *(["--", *arguments] if arguments else [])], cwd=isolated, timeout=300)
        except RuntimeError as error:
            failed.append(str(error))
    return failed


def check_source_contracts(engine, project, flags=None):
    """Validate authoring import settings before export strips their metadata."""
    failed = []
    for test in SOURCE_TESTS:
        try:
            run([engine, "--headless", "--path", project, "--fixed-fps", "60",
                 "--script", f"res://tests/headless/{test}.gd",
                 *(["--", *flags] if flags else [])], cwd=project, timeout=300)
        except RuntimeError as error:
            failed.append(str(error))
    return failed


def isolate_review_profile(project, stamp):
    config_path = project / "project.godot"
    config = config_path.read_text(encoding="utf-8")
    config = re.sub(r'(?m)^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n', "", config)
    directory = "OpenRTSHeadlessReview/" + stamp
    config, count = re.subn(r'(?m)^config/name="[^"\n]*"$',
                            'config/name="Open RTS Headless Review"\n'
                            'config/use_custom_user_dir=true\n'
                            f'config/custom_user_dir_name="{directory}"', config, count=1)
    if count != 1:
        raise RuntimeError("Could not isolate the headless verification user profile")
    base = (Path(os.environ["APPDATA"]) if sys.platform == "win32" else
            Path.home() / "Library/Application Support" if sys.platform == "darwin" else
            Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share"))
    profile = base / directory
    if profile.exists():
        raise RuntimeError("Headless verification profile already exists; refusing to reuse it")
    config_path.write_text(config, encoding="utf-8")
    return profile


def retain_review_evidence(profile, verification):
    failed = RECORDER is not None and RECORDER.report["status"] not in ("headless_checks_passed", "verified")
    if failed and profile.is_dir():
        destination = verification / "failed-user-profile"
        copy_directory(profile, destination)
        RECORDER.report["retained_failure_profile"] = str(destination)
        RECORDER.save()
        shutil.rmtree(profile, ignore_errors=True)
        return
    for name in ("test-artifacts", "replays"):
        folder = profile / name
        if folder.is_dir():
            shutil.copytree(folder, verification / "user-evidence" / name)
    shutil.rmtree(profile, ignore_errors=True)


def release_directories(headless_only, stamp):
    if headless_only:
        review = ROOT / "build/headless-review" / PLATFORM / stamp
        return review / "package", review / "headless-review-artifacts"
    return ROOT / "build" / PLATFORM, ROOT / "build/release-assets"


def main():
    global RECORDER
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path,
                        help="Use a local Godot executable and already installed export templates")
    parser.add_argument("--zig", type=Path, help="Use a local Zig compiler for Windows")
    parser.add_argument("--headless-only", action="store_true",
                        help="Run headless checks only; defer graphical/performance approval and keep review packages out of release-assets")
    parser.add_argument("--native-backend", action="store_true",
                        help="Test native kernels, unit state and crowd without changing shipping defaults")
    parser.add_argument("--source-root", type=Path,
                        help="Use an immutable project snapshot instead of the working tree")
    parser.add_argument("--verification-output", type=Path,
                        help="New directory for retained bounded logs and checkpoint report")
    args = parser.parse_args()
    source_root = (args.source_root or ROOT).resolve()
    if not (source_root / "project.godot").is_file():
        parser.error("--source-root must contain project.godot")
    if args.zig and PLATFORM != "windows":
        parser.error("--zig is only supported for Windows builds")
    engine = args.godot.resolve() if args.godot else None
    if engine:
        if not engine.is_file():
            parser.error(f"Godot executable not found: {engine}")
        engine_version = subprocess.check_output([str(engine), "--headless", "--version"],
                                                 encoding="utf-8", errors="replace").strip()
        if not engine_version.startswith(VERSION.replace("-", ".") + "."):
            parser.error(f"Expected Godot {VERSION}, found {engine_version}")
    zig = args.zig.resolve() if args.zig else None
    if zig and not zig.is_file():
        parser.error(f"Zig executable not found: {zig}")
    preset = PRESETS[PLATFORM]
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + f"-{os.getpid()}"
    verification = (args.verification_output or ROOT / "build/verification" / PLATFORM / stamp).resolve()
    RECORDER = VerificationLog(verification, args.headless_only)
    RECORDER.report.update(source_root=str(source_root), native_backend=args.native_backend,
                           standalone_manifest=TESTS,
                           source_contract_manifest=SOURCE_TESTS,
                           runner_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    RECORDER.report["input_sha256"] = input_manifest(source_root, verification / "input-manifest.json")
    RECORDER.save()
    output, artifacts = release_directories(args.headless_only, stamp)
    output.mkdir(parents=True, exist_ok=True)
    artifacts.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="rts-release-") as temporary, ExitStack() as cleanup:
        work = Path(temporary)
        if engine is None:
            engine_archive = work / "engine.zip"
            engine_name = f"Godot_v{VERSION}_{ENGINE_SUFFIX[PLATFORM]}"
            download(engine_name + ".zip", engine_archive)
            unpack(engine_archive, work)
            engine = (work / "Godot.app/Contents/MacOS/Godot" if PLATFORM == "macos"
                      else work / engine_name)
            if os.name != "nt":
                engine.chmod(0o755)
            template_archive = work / "templates.tpz"
            download(f"Godot_v{VERSION}_export_templates.tpz", template_archive)
            unpack(template_archive, work)
            template_root = {
                "linux": Path.home() / ".local/share/godot",
                "macos": Path.home() / "Library/Application Support/Godot",
                "windows": Path(os.environ.get("APPDATA", str(Path.home()))) / "Godot",
            }[PLATFORM] / "export_templates" / VERSION.replace("-", ".")
            shutil.copytree(work / "templates", template_root, dirs_exist_ok=True)
        native_build = work / "native-shipping"
        RECORDER.engine_paths.add(str(engine.resolve()))
        RECORDER.report["engine"] = {
            "path": str(engine),
            "version": run([engine, "--headless", "--version"]).strip(),
            "sha256": hashlib.sha256(engine.read_bytes()).hexdigest(),
        }
        RECORDER.save()
        compiler_args = ((["--zig", zig] if zig else ["--download-toolchain"])
                         if PLATFORM == "windows" else ["--universal"] if PLATFORM == "macos" else [])
        run([sys.executable, source_root / "tools/build_native.py", "--output", native_build, *compiler_args])
        RECORDER.report["native_sha256"] = {
            path.name: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in native_build.iterdir() if path.is_file()}
        RECORDER.save()
        project = stage_release_project(work, native_build, source_root)
        if args.headless_only:
            profile = isolate_review_profile(project, stamp)
            RECORDER.report["isolated_user_profile"] = str(profile)
            RECORDER.save()
            cleanup.callback(retain_review_evidence, profile, verification)
        import_release_project(engine, project)
        failed = []
        flags = NATIVE_FLAGS if args.native_backend else []
        failed.extend(check_source_contracts(engine, project, flags))
        archive_project, archive_profile = stage_archive_validation(work, project, source_root)
        try:
            run([engine, "--headless", "--path", archive_project,
                 "--script", "res://tests/headless/ArchivedSnapshotRegression.gd"],
                cwd=archive_project, timeout=300)
        except RuntimeError as error:
            failed.append(str(error))
            if archive_profile.is_dir():
                copy_directory(archive_profile, verification / "failed-archive-profile")
        finally:
            shutil.rmtree(archive_profile, ignore_errors=True)
        try:
            run([engine, "--headless", "--path", project,
                 "--script", "res://tests/headless/NativeCPUProfileRegression.gd",
                 "--", "--enable-native-kernels"])
        except RuntimeError as error:
            failed.append(str(error))
        if PLATFORM in ("windows", "macos"):
            for test in ("NativePoseRegression", "NativeContactRegression", "SpatialQueryRegression", "NativeTerrainSightRegression", "FogPackingRegression", "NativePoseRebaseRegression", "NativeInfantryPoseRegression", "NativeChassisRegression", "NativePoseRigRegression", "NativePresentationRegression", "NativeCrowdMovementRegression", "NativeCrowdProjectionRegression", "NativeNavigationSurfaceRegression"):
                run([engine, "--headless", "--path", project, "--fixed-fps", "60",
                     "--script", f"res://tests/headless/{test}.gd"])
            for test in ("NativeCrowdMovementRegression", "NativeCrowdProjectionRegression"):
                run([engine, "--headless", "--path", project, "--fixed-fps", "60",
                     "--script", f"res://tests/headless/{test}.gd", "--", "--native-nearest-surface"])
            run([engine, "--headless", "--path", project, "--fixed-fps", "60",
                 "--script", "res://tests/headless/NativeVisibilityRegression.gd",
                 "--", "--native-visibility-runtime"])
            run([engine, "--headless", "--path", project, "--fixed-fps", "60",
                 "--script", "res://tests/headless/NativeExplorationRegression.gd",
                 "--", "--native-visibility-runtime", "--native-unit-state", "--native-exploration"])
            run([engine, "--headless", "--path", project, "--fixed-fps", "60",
                 "--script", "res://tests/headless/NativeCombatQueryRegression.gd",
                 "--", "--native-visibility-runtime", "--native-unit-state", "--native-combat-queries"])
            for test in ("NativeBattlefieldIndexRegression", "SpatialQueryRegression", "NativeCombatQueryRegression"):
                run([engine, "--headless", "--path", project, "--fixed-fps", "60",
                     "--script", f"res://tests/headless/{test}.gd", "--",
                     "--native-visibility-runtime", "--native-unit-state",
                     "--native-combat-queries", "--native-battlefield-index"])
            run([engine, "--headless", "--path", project, "--fixed-fps", "60",
                 "--script", "res://tests/headless/DecoupledPoseRegression.gd",
                 "--", "--native-pose-rigs"])
            run([engine, "--headless", "--path", project, "--fixed-fps", "60",
                 "--script", "res://tests/headless/NativeUnitStateRegression.gd",
                 "--", "--native-unit-state", "--native-crowd-runtime",
                 "--native-visibility-runtime", "--native-nearest-surface"])
        filename = {"linux": "Open_RTS_Linux.x86_64", "windows": "Open_RTS_Windows.exe",
                    "macos": "Open_RTS_macOS.zip"}[PLATFORM]
        exported = output / filename
        run([engine, "--headless", "--path", project, "--export-release", preset, exported])
        if PLATFORM == "macos":
            for old in output.glob("*.app"):
                shutil.rmtree(old)
            run(["ditto", "-x", "-k", exported, output])
            app = next(output.glob("*.app"))
            pack = next((app / "Contents/Resources").glob("*.pck"))
            executable = application_executable(app)
        else:
            pack = executable = exported
        install_native_support(executable, native_build, app if PLATFORM == "macos" else None)
        RECORDER.report.update(platform=PLATFORM, pack=str(pack), executable=str(executable),
                               runtime_support=str(executable.parent / "native/bin"),
                               pack_sha256=hashlib.sha256(pack.read_bytes()).hexdigest(),
                               executable_sha256=hashlib.sha256(executable.read_bytes()).hexdigest())
        RECORDER.report["installed_native_sha256"] = {
            path.name: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in (executable.parent / "native/bin").iterdir() if path.is_file()}
        RECORDER.save()
        try:
            check_packaged_startup(executable, output)
        except RuntimeError as error:
            failed.append(str(error))
        isolated = work / "isolated"
        isolated.mkdir(parents=True)
        # The editor used for --main-pack lives outside the shipped bundle.
        # Resolve that pack's external descriptor against this fresh runtime.
        shutil.copytree(native_build, isolated / "native/bin")
        try:
            check_packaged_solver(engine, project, preset, native_build, work)
        except RuntimeError as error:
            failed.append(str(error))
        failed.extend(check_standalone_manifest(engine, pack, isolated, flags))
        try:
            check_rendered_resources(engine, pack, isolated, args.headless_only, flags)
        except RuntimeError as error:
            failed.append(str(error))
        layout_output = verification / "briefing-layout"
        layout_output.mkdir()
        try:
            run([engine, "--headless", "--main-pack", pack, "--fixed-fps", "60",
                 "--script", "res://tests/rendered/CampaignBriefingCatalogPreview.gd", "--",
                 "--layout-only", "--layout-matrix", f"--output-dir={layout_output}", *flags],
                cwd=isolated, timeout=300)
        except RuntimeError as error:
            failed.append(str(error))
        # The runner creates its own recording before replay verification; a
        # clean build must not depend on recordings from a user's prior match.
        try:
            run([sys.executable, source_root / "tools/tests/run_network_regressions.py",
                 "--engine", engine, "--main-pack", pack,
                 "--runtime-dir", isolated,
                 "--output", verification / "network-regressions",
                 *([] if PLATFORM == "windows" or args.native_backend else ["--no-native"])],
                cwd=isolated, timeout=1000)
        except RuntimeError as error:
            failed.append(str(error))
        RECORDER.report["pack_sha256"] = hashlib.sha256(pack.read_bytes()).hexdigest()
        RECORDER.save()
        if failed:
            raise RuntimeError(f"{len(failed)} verification checks failed; see {verification / 'report.json'}")
        if PLATFORM == "macos":
            exported.unlink()
            run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, exported])
            shutil.copy2(exported, artifacts / filename)
        elif PLATFORM == "linux":
            with tarfile.open(artifacts / "Open_RTS_Linux.tar.gz", "w:gz") as package:
                for path in output.iterdir():
                    package.add(path, arcname=path.name)
        else:
            shutil.make_archive(str(artifacts / "Open_RTS_Windows"), "zip", output)
        print("platform: " + json.dumps(PLATFORM))
        print("artifacts: " + json.dumps(str(artifacts)))
        print("standalone: " + str(len(TESTS)))
        status = "headless_checks_passed" if args.headless_only else "verified"
        RECORDER.report["artifacts"] = str(artifacts)
        RECORDER.report["artifacts_sha256"] = {
            path.name: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in artifacts.iterdir() if path.is_file()}
        RECORDER.finish(status)
        print("status: " + json.dumps(status))
        print("report: " + json.dumps(str(verification / "report.json")))
        if args.headless_only:
            print('deferred[3]: graphical_resource_lifetime,visual_review,strict_performance')


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        if RECORDER is not None:
            RECORDER.finish("interrupted")
        print('error: "Interrupted; the active owned process family was stopped"')
        raise SystemExit(1) from None
    except (OSError, RuntimeError, subprocess.TimeoutExpired, ValueError) as error:
        if RECORDER is not None:
            RECORDER.report["error"] = str(error)
            RECORDER.finish("failed")
        print("error: " + json.dumps(str(error)))
        print('help: "Review stderr diagnostics, fix the reported check and rerun tools/release/build.py"')
        raise SystemExit(1) from None
