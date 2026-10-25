#!/usr/bin/env python3
"""Deterministic physical detail maps and cutout masks; no inferred photo normals.

Normals are derivatives of explicitly authored relief, ORM is occlusion,
roughness, metal exposure. The trim atlas has four horizontal bands: plate,
louver, bolt strip, tread. Neutral color multipliers preserve faction paint.
Run with the dependencies in tools/textures/requirements.txt.
"""
from pathlib import Path
import math
import random

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SURFACES = ROOT / "assets/textures/surfaces/generated"
FOLIAGE = ROOT / "assets/textures/objects/generated"


def save(directory, name, data):
    directory.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.round(np.clip(data, 0, 1) * 255).astype(np.uint8)).save(directory / name)


def normal(height):
    # Central differences and periodic boundaries: +Y in an OpenGL normal is
    # upward in the image, opposite the row index. Height is in texel units.
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * .5
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * .5
    n = np.stack((-dx, dy, np.ones_like(height)), -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * .5 + .5


def periodic_noise(size, cells, seed):
    rng = np.random.default_rng(seed)
    lattice = rng.random((cells, cells))
    p = np.arange(size) / size * cells
    i = p.astype(int)
    f = p - i
    f = f * f * (3 - 2 * f)
    a = lattice[np.ix_(i % cells, i % cells)]
    b = lattice[np.ix_(i % cells, (i + 1) % cells)]
    c = lattice[np.ix_((i + 1) % cells, i % cells)]
    d = lattice[np.ix_((i + 1) % cells, (i + 1) % cells)]
    return (a * (1-f[None, :]) + b*f[None, :]) * (1-f[:, None]) + (c*(1-f[None, :])+d*f[None, :])*f[:, None]


def hard_surfaces():
    size = 512
    grain = periodic_noise(size, 96, 81)
    cast = periodic_noise(size, 32, 82)
    smudge = periodic_noise(size, 8, 83)
    relief = grain * .8 + cast * 1.8
    save(SURFACES, "metal_micro_normal.png", normal(relief))
    save(SURFACES, "metal_micro_orm.png", np.stack((.9 + cast*.1, .35 + smudge*.4 + grain*.12, np.zeros_like(grain)), -1))

    size = 2048
    y, x = np.mgrid[:size, :size]
    row = y // 512
    v = y % 512
    u = x % 512
    # Raised paint over recessed joints; the plateau stays almost perfectly flat.
    edge = np.minimum.reduce([u, 511-u, v, 511-v]).astype(float)
    panel = 2.5 * np.clip((edge - 11) / 9, 0, 1)
    seam = np.exp(-((edge - 10) / 3)**2)
    # Flush fasteners in the four corners of each panel.
    bolt_distance = np.hypot(np.minimum(abs(u-36), abs(u-475)), np.minimum(abs(v-36), abs(v-475)))
    bolt = np.clip((10-bolt_distance)/3, 0, 1)
    height = panel + bolt * 2.2
    cavity = 1 - seam*.28 - np.exp(-((bolt_distance-11)/2)**2)*.2
    # Grilles run across their strip, with broad border rails.
    vent = row == 1
    slat = np.clip((np.sin(x*.098) + .25)*1.4, 0, 1)
    inner = (v > 32) & (v < 480)
    height = np.where(vent & inner, slat*5, height)
    cavity = np.where(vent & inner, .53 + slat*.47, cavity)
    # Bolt/strap strip with brushed center and fastener line.
    strap = row == 2
    rivet = np.hypot(x % 128 - 64, v - 256)
    height = np.where(strap, np.clip((14-rivet)/4, 0, 1)*4 + np.clip((edge-12)/8, 0, 1)*1.5, height)
    cavity = np.where(strap, 1 - np.exp(-((rivet-16)/3)**2)*.25 - seam*.18, cavity)
    # Interlocking track links with diagonally raised cleats.
    tread = row == 3
    groove = np.sin((x + abs(v-256)*.4)*math.tau/128)
    height = np.where(tread, np.clip((groove+.2)*2, 0, 1)*4, height)
    cavity = np.where(tread, .72 + np.clip(groove, 0, 1)*.28, cavity)
    mottling = periodic_noise(size, 48, 93)
    rough = .52 + mottling*.15
    exposed = np.clip(bolt*.65 + seam*.12, 0, 1)
    shade = .97 + mottling*.03
    shade *= .8 + cavity*.2
    save(SURFACES, "mechanical_trim_color.png", np.stack([shade]*3, -1))
    save(SURFACES, "mechanical_trim_normal.png", normal(height))
    save(SURFACES, "mechanical_trim_orm.png", np.stack((cavity, rough, exposed), -1))


def foliage(kind):
    """Authored branch silhouettes, isolated leaves and veins, 2x antialiasing."""
    size = 1024
    rng = random.Random(620 if kind == "leaves" else 621)
    image = Image.new("RGBA", (size, size), (160, 178, 132, 0))
    draw = ImageDraw.Draw(image)
    center = np.array([size*.5, size*.87])
    for branch in range(9 if kind == "leaves" else 15):
        angle = -math.pi/2 + rng.uniform(-1.05, 1.05)
        end = center + np.array([math.cos(angle), math.sin(angle)]) * rng.uniform(size*.42, size*.79)
        draw.line([tuple(center), tuple(end)], fill=(105, 115, 77, 255), width=5)
        for index in range(3, 14):
            t = index/15
            p = center*(1-t) + end*t
            for side in [-1, 1]:
                theta = angle + side*rng.uniform(.5, 1.25)
                length = rng.uniform(36, 76) if kind == "leaves" else rng.uniform(48, 105)
                width = length * (.37 if kind == "leaves" else .09)
                axis = np.array([math.cos(theta), math.sin(theta)])
                across = np.array([-axis[1], axis[0]])
                tip = p + axis*length
                points = [p, p+axis*length*.37+across*width, p+axis*length*.72+across*width*.7,
                          tip, p+axis*length*.72-across*width*.7, p+axis*length*.37-across*width]
                value = rng.randint(145, 220)
                draw.polygon([tuple(q) for q in points], fill=(value, min(245, value+13), int(value*.8), 255))
                draw.line([tuple(p), tuple(tip)], fill=(max(0,value-20), value, int(value*.7), 255), width=2)
    image = image.resize((512, 512), Image.Resampling.LANCZOS)
    pixels = np.array(image)
    y, x = np.mgrid[:512, :512]
    edge = np.minimum.reduce([x, y, 511-x, 511-y])
    pixels[:, :, 3] = np.round(pixels[:, :, 3] * np.clip(edge / 12, 0, 1)).astype(np.uint8)
    Image.fromarray(pixels).save(FOLIAGE / f"{kind}_cutout.png")


if __name__ == "__main__":
    FOLIAGE.mkdir(parents=True, exist_ok=True)
    hard_surfaces()
    foliage("leaves")
    foliage("needles")
    print("Generated two micro maps, three trim maps and two foliage cutouts")
