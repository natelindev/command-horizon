#!/usr/bin/env python3
"""Deterministic physical detail maps and cutout masks; no inferred photo normals.

Normals are derivatives of explicitly authored relief, ORM is occlusion,
roughness, metal exposure. The trim atlas has four horizontal bands: plate
(four distinct architectural/armor modules), louver, bolt/rib strap, and tread.
Neutral color multipliers preserve faction paint while delivering crisp cavity
shading, roughness contrast, and exposed metallic edge wear.
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
    return (a * (1 - f[None, :]) + b * f[None, :]) * (1 - f[:, None]) + (c * (1 - f[None, :]) + d * f[None, :]) * f[:, None]


def hard_surfaces():
    # High-definition micro grain: multi-frequency cast metal + directional machining lines + pitting
    size = 512
    fine = periodic_noise(size, 128, 81)
    cast = periodic_noise(size, 32, 82)
    smudge = periodic_noise(size, 8, 83)
    # Brushed anisotropy (periodic horizontally & vertically)
    brush = periodic_noise(size, 16, 84) * 0.4 + np.tile(np.sin(np.arange(size) * math.tau / 16.0)[:, None], (1, size)) * 0.12
    pits = np.clip((fine - 0.86) * 7.0, 0, 1)
    relief = fine * 1.4 + cast * 2.8 + brush * 1.2 - pits * 2.2
    save(SURFACES, "metal_micro_normal.png", normal(relief))
    occ_micro = np.clip(0.84 + cast * 0.16 - pits * 0.25, 0.48, 1.0)
    rough_micro = np.clip(0.28 + smudge * 0.46 + (1.0 - fine) * 0.18 + pits * 0.15, 0.2, 0.95)
    save(SURFACES, "metal_micro_orm.png", np.stack((occ_micro, rough_micro, np.zeros_like(fine)), -1))

    # 2048x2048 Mechanical Trim Atlas (4 rows x 4 columns of 512x512 modules)
    size = 2048
    y, x = np.mgrid[:size, :size]
    row = y // 512
    col = x // 512
    v = y % 512
    u = x % 512

    edge = np.minimum.reduce([u, 511 - u, v, 511 - v]).astype(float)
    panel = 3.8 * np.clip((edge - 9.0) / 8.0, 0.0, 1.0)
    seam = np.exp(-((edge - 8.5) / 3.2) ** 2)

    # Flush hex bolts near corners + midpoints
    bx = np.minimum.reduce([abs(u - 34), abs(u - 477), abs(u - 256)])
    by = np.minimum.reduce([abs(v - 34), abs(v - 477)])
    corner_bolt = np.hypot(np.minimum(abs(u - 34), abs(u - 477)), np.minimum(abs(v - 34), abs(v - 477)))
    mid_bolt = np.hypot(abs(u - 256), by)
    bolt_dist = np.minimum(corner_bolt, mid_bolt)
    bolt = np.clip((10.5 - bolt_dist) / 2.8, 0.0, 1.0)
    bolt_socket = np.clip((4.2 - bolt_dist) / 1.5, 0.0, 1.0) * 1.1

    height = panel + bolt * 3.0 - bolt_socket
    cavity = 1.0 - seam * 0.45 - np.exp(-((bolt_dist - 11.5) / 2.4) ** 2) * 0.28
    exposed = np.clip(bolt * 0.72 + seam * 0.22 + np.clip((16.0 - edge) / 6.0, 0, 1) * np.clip((edge - 10.0) / 4.0, 0, 1) * 0.45, 0, 1)
    tone = np.ones_like(panel)

    # --- ROW 0: FOUR DISTINCT 512x512 ARMOR PANEL MODULES ---
    # Col 0: Service hatch + recessed gasket + grab handles
    c0 = (row == 0) & (col == 0)
    hx = np.maximum(abs(u - 256) - 118, 0.0)
    hy = np.maximum(abs(v - 256) - 96, 0.0)
    hatch_edge = np.hypot(hx, hy)
    hatch_groove = np.exp(-((hatch_edge - 6.0) / 2.8) ** 2)
    hatch_plate = np.clip((6.0 - hatch_edge) / 4.0, 0.0, 1.0) * 2.2
    handle = ((abs(v - 256) < 28) & ((abs(u - 172) < 9) | (abs(u - 340) < 9))).astype(float) * 2.4
    height = np.where(c0, height + hatch_plate - hatch_groove * 3.2 + handle, height)
    cavity = np.where(c0, np.clip(cavity - hatch_groove * 0.48, 0.35, 1.0), cavity)
    tone = np.where(c0, np.where(hatch_edge < 5.0, 0.91, 1.02), tone)
    exposed = np.where(c0, np.clip(exposed + hatch_groove * 0.35 + handle * 0.25, 0, 1), exposed)

    # Col 1: Reinforced blast bulkhead with sculpted structural ribs & chamfers
    c1 = (row == 0) & (col == 1)
    rib_x = np.minimum.reduce([abs(u - 132), abs(u - 256), abs(u - 380)])
    rib = np.clip((16.0 - rib_x) / 6.0, 0.0, 1.0) * ((v > 56) & (v < 456)).astype(float)
    rib_shadow = np.exp(-((rib_x - 18.0) / 3.5) ** 2) * ((v > 52) & (v < 460)).astype(float)
    height = np.where(c1, height + rib * 3.6, height)
    cavity = np.where(c1, np.clip(cavity - rib_shadow * 0.36, 0.35, 1.0), cavity)
    tone = np.where(c1, 0.94 + rib * 0.08, tone)
    exposed = np.where(c1, np.clip(exposed + rib * 0.38, 0, 1), exposed)

    # Col 2: Split twin inspection plates + diagonal chamfer crease
    c2 = (row == 0) & (col == 2)
    split_v = np.exp(-((v - 256.0) / 3.0) ** 2) * ((u > 28) & (u < 484)).astype(float)
    split_u = np.exp(-((u - 310.0) / 3.0) ** 2) * ((v > 28) & (v < 252)).astype(float)
    conduit = ((abs(u - 140) < 26) & (abs(v - 380) < 52)).astype(float)
    conduit_seam = np.exp(-((np.hypot(np.maximum(abs(u - 140) - 26, 0), np.maximum(abs(v - 380) - 52, 0)) - 2.0) / 2.2) ** 2)
    height = np.where(c2, height - (split_v + split_u) * 3.2 + conduit * 1.8 - conduit_seam * 2.5, height)
    cavity = np.where(c2, np.clip(cavity - (split_v + split_u) * 0.45 - conduit_seam * 0.35, 0.35, 1.0), cavity)
    tone = np.where(c2, np.where((v < 256) & (u < 310), 0.91, 1.01), tone)

    # Col 3: Compact recessed louver sub-grid + upper solid cap
    c3 = (row == 0) & (col == 3)
    sub_inner = (u > 68) & (u < 444) & (v > 96) & (v < 416)
    sub_slat = np.clip((np.sin(v * 0.22) + 0.15) * 1.5, 0.0, 1.0)
    sub_frame = np.exp(-((np.hypot(np.maximum(abs(u - 256) - 188, 0), np.maximum(abs(v - 256) - 160, 0)) - 3.0) / 3.0) ** 2)
    height = np.where(c3 & sub_inner, 1.2 + sub_slat * 4.2, height)
    height = np.where(c3, height - sub_frame * 2.6, height)
    cavity = np.where(c3 & sub_inner, 0.42 + sub_slat * 0.56, cavity)
    cavity = np.where(c3, np.clip(cavity - sub_frame * 0.42, 0.32, 1.0), cavity)
    tone = np.where(c3 & sub_inner, 0.72 + sub_slat * 0.28, tone)

    # --- ROW 1: DEEP INDUSTRIAL LOUVERS WITH STRUCTURAL SPAR ---
    vent = row == 1
    slat = np.clip((np.sin(x * 0.11) + 0.2) * 1.5, 0.0, 1.0)
    spar = (abs(v - 256) < 20).astype(float)
    inner = (v > 34) & (v < 478) & (u > 28) & (u < 484)
    height = np.where(vent & inner, np.maximum(slat * 5.6, spar * 4.2), height)
    cavity = np.where(vent & inner, np.maximum(0.36 + slat * 0.62, spar * 0.90), cavity)
    tone = np.where(vent & inner, np.where(spar > 0.5, 0.96, 0.72 + slat * 0.28), tone)
    exposed = np.where(vent & inner, np.clip(slat * 0.28 + spar * 0.25, 0, 1), exposed)

    # --- ROW 2: STRUCTURAL REINFORCEMENT STRAP / GIRDER WITH DOUBLE RIVETS ---
    strap = row == 2
    rivet_y = np.minimum(abs(v - 148), abs(v - 364))
    rivet = np.hypot((x % 96) - 48.0, rivet_y)
    center_rib = np.clip((38.0 - abs(v - 256)) / 10.0, 0.0, 1.0) * 2.6
    strap_height = np.clip((12.0 - rivet) / 3.2, 0.0, 1.0) * 4.2 + center_rib + np.clip((edge - 10.0) / 8.0, 0.0, 1.0) * 2.4
    strap_cav = np.clip(1.0 - np.exp(-((rivet - 13.0) / 2.8) ** 2) * 0.34 - seam * 0.38 - np.exp(-((abs(v - 256) - 42.0) / 3.5) ** 2) * 0.25, 0.35, 1.0)
    height = np.where(strap, strap_height, height)
    cavity = np.where(strap, strap_cav, cavity)
    tone = np.where(strap, 0.92 + np.clip(center_rib / 3.0, 0, 1) * 0.09, tone)
    exposed = np.where(strap, np.clip(np.clip((12.0 - rivet) / 4.0, 0, 1) * 0.8 + center_rib * 0.14, 0, 1), exposed)

    # --- ROW 3: ARTICULATED HEAVY TANK TRACK LINKS ---
    tread = row == 3
    shoe = np.sin((x + abs(v - 256) * 0.45) * math.tau / 112.0)
    guide_horn = np.clip((26.0 - abs(v - 256)) / 6.0, 0.0, 1.0) * np.clip((shoe + 0.35) * 1.4, 0.0, 1.0)
    pin_slot = np.exp(-((np.sin(x * math.tau / 112.0)) / 0.22) ** 2) * 0.35
    tread_h = np.clip((shoe + 0.18) * 2.2, 0.0, 1.0) * 4.5 + guide_horn * 3.0
    tread_c = np.clip(0.45 + np.clip(shoe, 0.0, 1.0) * 0.52 - pin_slot * 0.22, 0.32, 1.0)
    height = np.where(tread, tread_h, height)
    cavity = np.where(tread, tread_c, cavity)
    tone = np.where(tread, 0.68 + np.clip(shoe, 0, 1) * 0.34, tone)
    exposed = np.where(tread, np.clip(guide_horn * 0.78 + np.clip(shoe - 0.55, 0, 1) * 0.9, 0, 1), exposed)

    mottling = periodic_noise(size, 48, 93)
    grime = periodic_noise(size, 24, 94)
    rough = np.clip(0.38 + mottling * 0.24 + (1.0 - cavity) * 0.34 - exposed * 0.22, 0.18, 0.96)
    shade = np.clip(tone * (0.90 + mottling * 0.10 - grime * 0.05) * (0.62 + cavity * 0.42), 0.35, 1.08)

    save(SURFACES, "mechanical_trim_color.png", np.stack([shade] * 3, -1))
    save(SURFACES, "mechanical_trim_normal.png", normal(height))
    save(SURFACES, "mechanical_trim_orm.png", np.stack((np.clip(cavity, 0.42, 1.0), rough, exposed), -1))


def foliage(kind):
    """Authored branch silhouettes, isolated leaves and veins, 2x antialiasing."""
    size = 1024
    rng = random.Random(620 if kind == "leaves" else 621)
    image = Image.new("RGBA", (size, size), (160, 178, 132, 0))
    draw = ImageDraw.Draw(image)
    center = np.array([size * .5, size * .87])
    for branch in range(9 if kind == "leaves" else 15):
        angle = -math.pi / 2 + rng.uniform(-1.05, 1.05)
        end = center + np.array([math.cos(angle), math.sin(angle)]) * rng.uniform(size * .42, size * .79)
        draw.line([tuple(center), tuple(end)], fill=(105, 115, 77, 255), width=5)
        for index in range(3, 14):
            t = index / 15
            p = center * (1 - t) + end * t
            for side in [-1, 1]:
                theta = angle + side * rng.uniform(.5, 1.25)
                length = rng.uniform(36, 76) if kind == "leaves" else rng.uniform(48, 105)
                width = length * (.37 if kind == "leaves" else .09)
                axis = np.array([math.cos(theta), math.sin(theta)])
                across = np.array([-axis[1], axis[0]])
                tip = p + axis * length
                points = [p, p + axis * length * .37 + across * width, p + axis * length * .72 + across * width * .7,
                          tip, p + axis * length * .72 - across * width * .7, p + axis * length * .37 - across * width]
                value = rng.randint(145, 220)
                draw.polygon([tuple(q) for q in points], fill=(value, min(245, value + 13), int(value * .8), 255))
                draw.line([tuple(p), tuple(tip)], fill=(max(0, value - 20), value, int(value * .7), 255), width=2)
    image = image.resize((512, 512), Image.Resampling.LANCZOS)
    pixels = np.array(image)
    y, x = np.mgrid[:512, :512]
    edge = np.minimum.reduce([x, y, 511 - x, 511 - y])
    pixels[:, :, 3] = np.round(pixels[:, :, 3] * np.clip(edge / 12, 0, 1)).astype(np.uint8)
    Image.fromarray(pixels).save(FOLIAGE / f"{kind}_cutout.png")


if __name__ == "__main__":
    FOLIAGE.mkdir(parents=True, exist_ok=True)
    hard_surfaces()
    foliage("leaves")
    foliage("needles")
    print("Generated rich micro maps, 4-module trim maps and foliage cutouts")
