"""Build the optional Windows pose uploader; no system compiler installation.

Pass --zig PATH to use a local Zig compiler, or --download-toolchain to fetch
the pinned official archive and verify its SHA-256 before extraction.
"""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "0.17.0"
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
    parser.add_argument("--output", type=Path, default=ROOT / "native/bin")
    args = parser.parse_args()
    zig = args.zig or shutil.which("zig")
    if zig is None and args.download_toolchain:
        zig = toolchain()
    if zig is None:
        parser.error("Supply --zig PATH or --download-toolchain")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    source = ROOT / "native/pose_packer"
    library = output / "copperfin.windows.x86_64.dll"
    subprocess.run([str(zig), "cc", "-shared", "-O3", "-target", "x86_64-windows-gnu",
                    "-I", str(source), str(source / "pose_packer.c"), "-o", str(library)], check=True)
    (output / "copperfin.gdextension").write_text(
        '[configuration]\nentry_symbol = "copperfin_library_init"\n'
        'compatibility_minimum = "4.4"\n\n[libraries]\n'
        'windows.x86_64 = "copperfin.windows.x86_64.dll"\n', encoding="utf-8")
    print(library)


if __name__ == "__main__":
    main()
