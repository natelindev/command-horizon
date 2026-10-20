"""Build and verify a desktop release on its native GitHub Actions runner."""

import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
PLATFORM = os.environ["RTS_RELEASE_PLATFORM"]
VERSION = "4.7.2-stable"
PRESETS = {"linux": "Linux/X11", "windows": "Windows Desktop", "macos": "macOS"}
ENGINE_SUFFIX = {"linux": "linux.x86_64", "windows": "win64.exe", "macos": "macos.universal"}
TESTS = [
    "BehaviorRegression", "UnitAnimationRegression",
    "PersistentCaptureRegression",
    "CampaignInteriorRegression", "HeroCampaignRegression", "SkirmishPickerRegression",
    "WorkerDistributionRegression", "CargoReturnRegression", "ResourceFieldRegression",
    "GarrisonCombatExitRegression", "PointOfInterestRegression",
    "MapMetricsRegression", "GlacierHarvestRegression", "TerrainSightRegression",
    "CliffMeshRegression", "AuthoredRelayRegression",
    "AuthoredGarrisonRegression",
    "SaveNavigationTimingRegression",
    "ContactApproachRegression", "NavigationRegression", "MapPlayabilityRegression",
    "MapPreviewRegression", "MusicRegression",
    "SelectionBatchRegression",
    "ProjectileSystemRegression", "ProjectilePhysicsRegression",
    "FixedWingFlightRegression", "FixedWingSaveRegression",
    "AirSaveContinuityRegression", "RotorcraftCombatRegression", "FrontierCombatRegression",
    "AirfieldOperationsRegression", "GroundHeightAlignmentRegression", "GroundCrowdRecoveryRegression",
    "SkirmishBuildReadinessRegression",
    "PresentationFeaturesRegression", "SettingsRegression",
    "BattleHudProductionRegression", "BattleAftermathRegression",
    "MapPassageRegression", "ObjectMaterialsRegression", "RuntimeShutdownRegression",
    "EnvironmentEffectsRegression", "WaterFlowRegression", "WaterHybridRegression",
]


def run(args, cwd=ROOT, timeout=900):
    result = subprocess.run([str(arg) for arg in args], cwd=cwd, timeout=timeout,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print(result.stdout, flush=True)
    fatal = ("SCRIPT ERROR:", "Parse Error:", "ERROR: GDExtension",
             "ERROR: Can't open GDExtension", "ERROR: Error loading extension",
             "ERROR: Failed to export")
    if result.returncode or any(message in result.stdout for message in fatal):
        raise RuntimeError(f"Command failed ({result.returncode}): {args}")


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


def main():
    preset = PRESETS[PLATFORM]
    output = ROOT / "build" / PLATFORM
    output.mkdir(parents=True, exist_ok=True)
    artifacts = ROOT / "build" / "release-assets"
    artifacts.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="rts-release-") as temporary:
        work = Path(temporary)
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
        run([engine, "--headless", "--path", ROOT, "--editor", "--quit"])
        filename = {"linux": "Open_RTS_Linux.x86_64", "windows": "Open_RTS_Windows.exe",
                    "macos": "Open_RTS_macOS.zip"}[PLATFORM]
        exported = output / filename
        run([engine, "--headless", "--path", ROOT, "--export-release", preset, exported])
        if PLATFORM == "macos":
            unpack(exported, output)
            app = next(output.glob("*.app"))
            pack = next((app / "Contents/Resources").glob("*.pck"))
            executable = next((app / "Contents/MacOS").iterdir())
        else:
            pack = executable = exported
        run([executable, "--headless", "--quit-after", "120"], cwd=output)
        isolated = work / "isolated"
        isolated.mkdir(parents=True)
        for test in TESTS:
            run([engine, "--headless", "--main-pack", pack, "--fixed-fps", "60",
                 "--script", f"res://tests/headless/{test}.gd"], cwd=isolated, timeout=300)
        if PLATFORM == "macos":
            shutil.copy2(exported, artifacts / filename)
        elif PLATFORM == "linux":
            with tarfile.open(artifacts / "Open_RTS_Linux.tar.gz", "w:gz") as package:
                for path in output.iterdir():
                    package.add(path, arcname=path.name)
        else:
            shutil.make_archive(str(artifacts / "Open_RTS_Windows"), "zip", output)


if __name__ == "__main__":
    main()
