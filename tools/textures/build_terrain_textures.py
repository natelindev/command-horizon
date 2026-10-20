#!/usr/bin/env python3
"""Download CC0 Poly Haven aerial ground scans and pack their data maps.

Usage:
    python3 -m venv tmp/texture-venv
    tmp/texture-venv/bin/pip install -r tools/textures/requirements.txt
    tmp/texture-venv/bin/python tools/textures/build_terrain_textures.py

Color and OpenGL normal maps are stored exactly as downloaded. Roughness,
displacement and AO are packed into one lossless `<name>_data.webp`
(R roughness, G normalized height, B occlusion) so each ground layer needs only
three samplers. Downloads are cached under tmp/ and verified against
assets/textures/terrain/sources.json when that file already lists them.
"""

import hashlib
import json
import sys
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/textures/terrain"
CACHE = ROOT / "tmp/texture-cache"
API = "https://api.polyhaven.com/files/{asset}"

# name: (Poly Haven asset, color/normal resolution, physical tile width in metres)
# Larger tiles use 2K so close zoom keeps roughly 30+ texels per metre.
LAYERS = {
    "grass": ("aerial_grass_rock", "1k", 15.0),
    "ground_rock": ("aerial_ground_rock", "1k", 20.0),
    "sand": ("aerial_sand", "1k", 15.0),
    "coast_sand": ("coast_sand_01", "1k", 15.0),
    "dirt": ("dirt_aerial_03", "2k", 25.0),
    "asphalt": ("aerial_asphalt_01", "2k", 30.0),
    "snow": ("snow_field_aerial", "2k", 80.0),
    "concrete": ("concrete_floor_damaged_01", "1k", 5.0),
}
DATA_RES = "1k"
_listings = {}


def download(url):
    request = urllib.request.Request(url, headers={"User-Agent": "open-rts-texture-build/1.0"})
    with urllib.request.urlopen(request) as response:
        return response.read()


def listing(asset):
    if asset not in _listings:
        _listings[asset] = json.loads(download(API.format(asset=asset)))
    return _listings[asset]


def fetch(asset, kind, res, recorded):
    url = listing(asset)[kind][res]["jpg"]["url"]
    path = CACHE / Path(url).name
    if not path.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        path.write_bytes(download(url))
    payload = path.read_bytes()
    digest = hashlib.sha256(payload).hexdigest()
    expected = recorded.get(path.name)
    if expected and expected["sha256"] != digest:
        sys.exit(f"Checksum mismatch for {path.name}; refusing to update assets")
    return path, {"file": path.name, "url": url, "sha256": digest, "bytes": len(payload)}


def gray(path):
    return np.asarray(Image.open(path).convert("L"), dtype=np.float32) / 255.0


def pack(name, rough, height, occlusion):
    r, h, ao = gray(rough), gray(height), gray(occlusion)
    # Stretch the useful height range; blend thresholds then behave alike per layer.
    low, high = np.percentile(h, [1, 99])
    h = np.clip((h - low) / max(high - low, 1e-4), 0.0, 1.0)
    packed = np.stack([r, h, ao], axis=-1)
    image = Image.fromarray(np.round(packed * 255.0).astype(np.uint8), "RGB")
    image.save(OUT / f"{name}_data.webp", lossless=True, quality=100, method=6)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / "sources.json"
    recorded = {}
    if manifest_path.exists():
        for entry in json.loads(manifest_path.read_text())["files"]:
            recorded[entry["file"]] = entry
    files = []
    layers = {}
    for name, (asset, res, width) in LAYERS.items():
        for kind, suffix in (("Diffuse", "color"), ("nor_gl", "normal")):
            path, entry = fetch(asset, kind, res, recorded)
            (OUT / f"{name}_{suffix}.jpg").write_bytes(path.read_bytes())
            files.append(entry)
        data = {}
        for kind in ("Rough", "Displacement", "AO"):
            data[kind], entry = fetch(asset, kind, DATA_RES, recorded)
            files.append(entry)
        pack(name, data["Rough"], data["Displacement"], data["AO"])
        layers[name] = {
            "asset": asset,
            "page": f"https://polyhaven.com/a/{asset}",
            "resolution": res,
            "tile_metres": width,
        }
    manifest = {
        "license": "CC0-1.0",
        "license_url": "https://polyhaven.com/license",
        "layers": layers,
        "files": files,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Wrote {len(layers)} layers to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
