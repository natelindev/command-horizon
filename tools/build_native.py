"""Build the optional native pose and simulation kernels.

Pass --zig PATH to use a local Zig compiler, or --download-toolchain to fetch
the pinned official archive and verify its SHA-256 before extraction.
"""
import argparse
import hashlib
import json
import platform
import sys
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "0.17.1"
ARCHIVE = f"zig-x86_64-windows-{VERSION}.zip"
URL = f"https://ziglang.org/download/{VERSION}/{ARCHIVE}"
SHA256 = "b5663f69581dcf391293fbf16c06cb80d81d806545ce618b4d0bab7f0eb8c428"


def toolchain():
    cache = Path(tempfile.gettempdir()) / "copperfin-native-toolchain"
    cache.mkdir(exist_ok=True)
    archive = cache / ARCHIVE
    if not archive.exists():
        urllib.request.urlretrieve(URL, archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        raise RuntimeError("Zig archive SHA-256 does not match the pinned official release")
    executable = cache / f"zig-x86_64-windows-{VERSION}" / "zig.exe"
    if not executable.exists():
        with zipfile.ZipFile(archive) as package:
            for member in package.infolist():
                if not (cache / member.filename).resolve().is_relative_to(cache.resolve()):
                    raise RuntimeError("Unsafe toolchain archive path")
            package.extractall(cache)
    return executable


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zig", type=Path)
    parser.add_argument("--download-toolchain", action="store_true")
    parser.add_argument("--cc", help="Host C compiler (default: cc on macOS/Linux)")
    parser.add_argument("--universal", action="store_true",
                        help="Build both macOS arm64 and x86-64 slices into one library")
    parser.add_argument("--output", type=Path, default=ROOT / "native/bin")
    args = parser.parse_args()
    host = platform.system()
    architecture = {"aarch64": "arm64", "AMD64": "x86_64"}.get(platform.machine(), platform.machine())
    if host not in ("Windows", "Darwin", "Linux") or architecture not in ("arm64", "x86_64"):
        parser.error("Supported hosts: Windows x86-64, macOS/Linux arm64 or x86-64")
    if args.universal and host != "Darwin":
        parser.error("--universal requires a macOS host with Apple Command Line Tools")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    source = ROOT / "native/pose_packer"
    if host == "Windows":
        if architecture != "x86_64":
            parser.error("Windows requires x86-64")
        zig = args.zig or shutil.which("zig")
        if zig is None and args.download_toolchain:
            zig = toolchain()
        if zig is None:
            parser.error("Supply --zig PATH or --download-toolchain")
        compiler = [str(zig), "cc", "-shared", "-target", "x86_64-windows-gnu"]
        feature, extension = "windows.x86_64", "dll"
    else:
        if args.zig or args.download_toolchain:
            parser.error("Use --cc PATH for host builds on macOS/Linux")
        cc = args.cc or shutil.which("cc")
        if cc is None:
            parser.error("No host compiler found; supply --cc PATH")
        compiler = [str(cc), "-dynamiclib" if host == "Darwin" else "-shared", "-fPIC"]
        feature = ("macos" if host == "Darwin" else "linux") + "." + architecture
        extension = "dylib" if host == "Darwin" else "so"
    features = [feature]
    library = output / f"copperfin.{feature}.{extension}"
    if args.universal:
        lipo = shutil.which("lipo")
        if lipo is None:
            parser.error("--universal requires Apple's lipo; install the Command Line Tools")
        library = output / "copperfin.macos.universal.dylib"
        features = ["macos.arm64", "macos.x86_64"]
        with tempfile.TemporaryDirectory(prefix="copperfin-universal-") as temporary:
            slices = []
            for target, minimum in [("arm64", "11.0"), ("x86_64", "10.13")]:
                thin = Path(temporary) / f"{target}.dylib"
                compile_library(compiler + ["-arch", target, f"-mmacosx-version-min={minimum}",
                                            "-Wl,-install_name,@rpath/" + library.name],
                                source, thin)
                slices.append(str(thin))
            run_native_tool([lipo, "-create", *slices, "-output", str(library)])
        for target in ["arm64", "x86_64"]:
            run_native_tool([lipo, str(library), "-verify_arch", target])
    else:
        compile_library(compiler, source, library)
    config = output / "copperfin.gdextension"
    entries = {}
    if config.exists():
        section = config.read_text(encoding="utf-8").split("[libraries]", 1)
        if len(section) == 2:
            for line in section[1].splitlines():
                if "=" in line:
                    key, value = line.split("=", 1)
                    entries[key.strip()] = value.strip()
    for target in features:
        entries[target] = f'"{library.name}"'
    config.write_text(
        '[configuration]\nentry_symbol = "copperfin_library_init"\n'
        'compatibility_minimum = "4.4"\n\n[libraries]\n' +
        "".join(f"{key} = {value}\n" for key, value in sorted(entries.items())), encoding="utf-8")
    print("library: " + json.dumps(str(library)))


def compile_library(compiler, source, library):
    run_native_tool(compiler + ["-O3", "-ffp-contract=off", "-I", str(source),
                               str(source / "pose_packer.c"), "-o", str(library), "-lm"])


def run_native_tool(command):
    try:
        result = subprocess.run(command, stdout=sys.stderr, stderr=sys.stderr)
    except OSError as error:
        print(f"error: {error}")
        print("help: Check the compiler/Command Line Tools path and retry")
        raise SystemExit(1) from None
    if result.returncode:
        print("error: Native build tool failed")
        print("help: Check compiler diagnostics on stderr and rerun with --cc or --zig")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
