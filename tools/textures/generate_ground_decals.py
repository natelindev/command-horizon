#!/usr/bin/env python3
"""Generate the procedural ground decal textures.

Usage:
    tmp/texture-venv/bin/python tools/textures/generate_ground_decals.py

Writes RGBA PNGs to assets/textures/decals/. Color is neutral (tinted per biome
by Decal.modulate at runtime) and alpha carries coverage. Output is
deterministic: every decal uses a fixed seed.
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/textures/decals"
SIZE = 512


def grid(size=SIZE):
    axis = (np.arange(size) + 0.5) / size * 2.0 - 1.0
    return np.meshgrid(axis, axis)


def value_noise(rng, size, cells):
    lattice = rng.random((cells + 1, cells + 1))
    t = np.linspace(0, cells, size, endpoint=False)
    i = t.astype(int)
    f = t - i
    f = f * f * (3 - 2 * f)
    a = lattice[np.ix_(i, i)]
    b = lattice[np.ix_(i, i + 1)]
    c = lattice[np.ix_(i + 1, i)]
    d = lattice[np.ix_(i + 1, i + 1)]
    fx = f[None, :]
    fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(rng, size=SIZE, octaves=5, base=4):
    total = np.zeros((size, size))
    amplitude = 1.0
    norm = 0.0
    for octave in range(octaves):
        total += value_noise(rng, size, base * 2**octave) * amplitude
        norm += amplitude
        amplitude *= 0.5
    return total / norm


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def edge_fade(x, y, margin=0.12):
    """Alpha falloff so nothing touches the decal box border."""
    border = np.minimum(1 - np.abs(x), 1 - np.abs(y))
    return smoothstep(0.0, margin, border)


def save(name, shade, alpha):
    shade = np.clip(shade, 0.0, 1.0)
    alpha = np.clip(alpha, 0.0, 1.0)
    rgba = np.stack([shade, shade, shade, alpha], axis=-1)
    Image.fromarray(np.round(rgba * 255).astype(np.uint8), "RGBA").save(OUT / f"{name}.png")


def oil_stain(seed):
    rng = np.random.default_rng(seed)
    x, y = grid()
    warp = fbm(rng, base=3) - 0.5
    radius = np.hypot(x * 1.15, y) + warp * 0.55
    body = 1 - smoothstep(0.35, 0.72, radius)
    core = 1 - smoothstep(0.05, 0.4, radius + (fbm(rng, base=6) - 0.5) * 0.3)
    speckle = smoothstep(0.62, 0.8, fbm(rng, base=24)) * (1 - smoothstep(0.6, 0.95, radius))
    alpha = np.maximum(body * 0.55 + core * 0.3, speckle * 0.35) * edge_fade(x, y)
    shade = 0.08 + (1 - core) * 0.06
    return shade + np.zeros_like(x), alpha


def tire_tracks(seed):
    """Two curved tread bands running along the texture's vertical axis."""
    rng = np.random.default_rng(seed)
    x, y = grid()
    bend = 0.18 * y * y
    alpha = np.zeros_like(x)
    tread = 0.5 + 0.5 * np.sign(np.sin((y * 34.0 + np.abs(x) * 6.0) * np.pi))
    for side in (-1, 1):
        offset = np.abs(x - bend - side * 0.42)
        band = 1 - smoothstep(0.07, 0.11, offset)
        alpha = np.maximum(alpha, band * (0.45 + 0.25 * tread))
    wear = smoothstep(0.25, 0.75, fbm(rng, base=5))
    ends = 1 - smoothstep(0.55, 0.95, np.abs(y))
    alpha *= (0.45 + 0.55 * wear) * ends * edge_fade(x, y, 0.04)
    return 0.16 + 0.08 * tread, alpha


def skid_marks(seed):
    rng = np.random.default_rng(seed)
    x, y = grid()
    bend = 0.1 * np.sin(y * 1.7 + 0.4)
    alpha = np.zeros_like(x)
    streak = fbm(rng, base=4)
    for side in (-1, 1):
        offset = np.abs(x - bend - side * 0.3)
        band = 1 - smoothstep(0.04, 0.09, offset)
        alpha = np.maximum(alpha, band)
    ends = smoothstep(-0.95, -0.4, y) * (1 - smoothstep(0.55, 0.95, y))
    alpha *= (0.35 + 0.5 * smoothstep(0.3, 0.7, streak)) * ends * edge_fade(x, y, 0.04)
    return 0.05 + np.zeros_like(x), alpha


def cracks(seed):
    """Long, mostly straight fractures that branch at shallow angles."""
    rng = np.random.default_rng(seed)
    x, y = grid()
    canvas = np.zeros((SIZE, SIZE))
    heading = rng.uniform(0, np.pi)
    walkers = [(SIZE / 2, SIZE / 2, heading, 2.6, 0), (SIZE / 2, SIZE / 2, heading + np.pi, 2.6, 0)]
    while walkers:
        px, py, angle, width, depth = walkers.pop()
        drift = 0.0
        for step in range(int(rng.uniform(70, 110) / (depth + 1))):
            # Slowly wandering heading with occasional kinks.
            drift = drift * 0.7 + rng.normal(0, 0.03)
            angle += drift + (rng.normal(0, 0.35) if rng.random() < 0.03 else 0.0)
            px += np.cos(angle) * 2.5
            py += np.sin(angle) * 2.5
            if not (10 < px < SIZE - 10 and 10 < py < SIZE - 10):
                break
            radius = max(width * (1 - step / 160), 0.7)
            x0, x1 = int(px - radius - 2), int(px + radius + 3)
            y0, y1 = int(py - radius - 2), int(py + radius + 3)
            yy, xx = np.mgrid[y0:y1, x0:x1]
            stroke = 1 - smoothstep(radius * 0.4, radius + 0.9, np.hypot(xx - px, yy - py))
            canvas[y0:y1, x0:x1] = np.maximum(canvas[y0:y1, x0:x1], stroke)
            if depth < 2 and rng.random() < 0.035:
                branch = angle + rng.choice([-1, 1]) * rng.uniform(0.4, 0.9)
                walkers.append((px, py, branch, width * 0.6, depth + 1))
    alpha = canvas * 0.8 * edge_fade(x, y)
    return 0.06 + np.zeros_like(x), alpha


def repair_patch(seed):
    rng = np.random.default_rng(seed)
    x, y = grid()
    warp = (fbm(rng, base=6) - 0.5) * 0.06
    box = np.maximum(np.abs(x * 1.0 + warp) / 0.62, np.abs(y + warp) / 0.82)
    patch = 1 - smoothstep(0.96, 1.0, box)
    seam = (1 - smoothstep(0.0, 0.035, np.abs(box - 0.99))) * 0.9
    tone = fbm(rng, base=10)
    alpha = np.maximum(patch * (0.42 + 0.18 * tone), seam) * edge_fade(x, y)
    shade = np.where(seam > patch * 0.6, 0.04, 0.11 + 0.05 * tone)
    return shade, alpha


def debris(seed):
    rng = np.random.default_rng(seed)
    x, y = grid()
    shade = np.zeros((SIZE, SIZE))
    alpha = np.zeros((SIZE, SIZE))
    falloff = 1 - smoothstep(0.3, 0.95, np.hypot(x, y))
    for _ in range(220):
        cx, cy = rng.normal(0, 0.35, 2)
        if abs(cx) > 0.85 or abs(cy) > 0.85:
            continue
        radius = rng.uniform(0.006, 0.026) * (1 + 1.5 * rng.random() ** 6)
        stretch = rng.uniform(0.6, 1.4)
        stone = 1 - smoothstep(radius * 0.6, radius, np.hypot((x - cx) * stretch, y - cy))
        value = rng.choice([0.12, 0.2, 0.55, 0.7])
        shade = np.where(stone > alpha, value, shade)
        alpha = np.maximum(alpha, stone * 0.9)
    alpha *= np.maximum(falloff, 0.0) * edge_fade(x, y)
    return shade, alpha


def scuff(seed):
    """Soft disturbed-ground patch, lighter than its surroundings."""
    rng = np.random.default_rng(seed)
    x, y = grid()
    warp = fbm(rng, base=3) - 0.5
    radius = np.hypot(x, y * 1.3) + warp * 0.7
    body = 1 - smoothstep(0.2, 0.85, radius)
    grain = fbm(rng, base=32)
    alpha = body * (0.3 + 0.25 * grain) * edge_fade(x, y)
    return 0.62 + 0.15 * grain, alpha


DECALS = {
    "oil_stain_a": (oil_stain, 11),
    "oil_stain_b": (oil_stain, 12),
    "tire_tracks": (tire_tracks, 21),
    "skid_marks": (skid_marks, 31),
    "cracks_a": (cracks, 41),
    "cracks_b": (cracks, 42),
    "repair_patch": (repair_patch, 51),
    "debris": (debris, 61),
    "scuff": (scuff, 71),
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (make, seed) in DECALS.items():
        save(name, *make(seed))
    print(f"Wrote {len(DECALS)} decals to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
