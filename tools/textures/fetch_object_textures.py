#!/usr/bin/env python3
"""Fetch unmodified CC0 bark and rock maps; verify recorded SHA-256 hashes."""

import hashlib
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/textures/objects/polyhaven"
ASSETS = {"bark": "bark_brown_02", "stone": "rock_boulder_cracked"}
MAPS = {"Diffuse": "color", "nor_gl": "normal", "Rough": "roughness"}


def download(url):
    request = urllib.request.Request(url, headers={"User-Agent": "open-rts-texture-build/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT.parent / "sources.json"
    previous = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    recorded = {entry["file"]: entry for entry in previous.get("files", [])}
    files = []
    for name, asset in ASSETS.items():
        listing = json.loads(download(f"https://api.polyhaven.com/files/{asset}"))
        for kind, suffix in MAPS.items():
            path = OUT / f"{name}_{suffix}.jpg"
            url = listing[kind]["1k"]["jpg"]["url"]
            payload = path.read_bytes() if path.exists() else download(url)
            digest = hashlib.sha256(payload).hexdigest()
            if path.name in recorded and recorded[path.name]["sha256"] != digest:
                raise ValueError(f"Checksum mismatch: {path.name}")
            path.write_bytes(payload)
            files.append({
                "file": path.name, "asset": asset, "page": f"https://polyhaven.com/a/{asset}",
                "url": url, "sha256": digest, "bytes": len(payload),
            })
    manifest_path.write_text(json.dumps({
        "license": "CC0-1.0", "license_url": "https://polyhaven.com/license", "files": files,
    }, indent=2) + "\n")
    print(f"Verified {len(files)} object texture maps")


if __name__ == "__main__":
    main()
