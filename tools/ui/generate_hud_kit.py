"""Generate the battle-console texture kits, one per faction.

Every faction shares a sculpted sci-fi console language (asymmetric 45-degree
chamfers, high-contrast machined bevels, recessed dark glass screens with lower-lip
catchlights, corner armor gussets, luminous edge filaments, and 3D physical keycaps)
and carries its own material and accent:

    bastion   armoured gunmetal, hex bolts, warm gold-amber accent, chevron stripes
    helix     anodized sapphire-titanium, hex glass, ice-cyan accent, data dashes
    frontier  weathered olive-iron, copper rivets, diamond tread, orange accent, hazard

Textures are authored at 2x logical resolution and drawn at half scale by
`source/match/hud/HudStyle.gd`; slice sizes in `BattleTheme.gd` are logical.
State changes (hover, pressed, selected) are fills, specular lifts and glows.

Usage:
    python tools/ui/generate_hud_kit.py [output_dir]
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SUPERSAMPLE = 4
LIGHT = np.array([-0.55, -0.83])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
RIM = np.array([4, 6, 8], np.float32)


def rgb(hex_value):
    return np.array([int(hex_value[i : i + 2], 16) for i in (0, 2, 4)], np.float32)


PROFILES = {
    "bastion": {
        "frame_top": rgb("5c6670"),
        "frame_bottom": rgb("262c33"),
        "field_top": rgb("12181e"),
        "field_bottom": rgb("0a0e12"),
        "screen": rgb("060a0e"),
        "accent": rgb("e8b04a"),
        "spec": rgb("dde5ed"),
        "glass": 0.94,
        "edge": 0.62,
        "bevel_light": 0.95,
        "cut": 1.15,
        "frame": 0.95,
        "bolts": "bolt",
        "frame_pattern": "brushed",
        "field_pattern": "grid",
        "stripe": "chevron",
        "key_top": rgb("454f59"),
        "key_bottom": rgb("21272d"),
        "paint_top": rgb("a86314"),
        "paint_bottom": rgb("5c2f07"),
        "seed": 11,
    },
    "helix": {
        "frame_top": rgb("3b5163"),
        "frame_bottom": rgb("17222d"),
        "field_top": rgb("0a1721"),
        "field_bottom": rgb("050c12"),
        "screen": rgb("040a10"),
        "accent": rgb("5fd8e8"),
        "spec": rgb("cff3ff"),
        "glass": 0.90,
        "edge": 0.72,
        "bevel_light": 0.90,
        "cut": 1.35,
        "frame": 0.75,
        "bolts": None,
        "frame_pattern": "smooth",
        "field_pattern": "hex",
        "stripe": "dashes",
        "key_top": rgb("2f4252"),
        "key_bottom": rgb("14202b"),
        "paint_top": rgb("19788f"),
        "paint_bottom": rgb("0a3c4f"),
        "seed": 23,
    },
    "frontier": {
        "frame_top": rgb("665645"),
        "frame_bottom": rgb("2c241c"),
        "field_top": rgb("16120e"),
        "field_bottom": rgb("0c0a07"),
        "screen": rgb("080a07"),
        "accent": rgb("f08c3e"),
        "spec": rgb("f0dfc8"),
        "glass": 0.95,
        "edge": 0.58,
        "bevel_light": 0.98,
        "cut": 0.92,
        "frame": 1.05,
        "bolts": "rivet",
        "frame_pattern": "diamond",
        "field_pattern": "scan",
        "stripe": "hazard",
        "key_top": rgb("504437"),
        "key_bottom": rgb("262019"),
        "paint_top": rgb("a84c14"),
        "paint_bottom": rgb("5c2307"),
        "seed": 37,
    },
}


# --- geometry -----------------------------------------------------------------


def gaussian(array, sigma):
    """Separable Gaussian blur for float arrays (Pillow cannot blur mode F)."""
    radius = max(1, int(math.ceil(sigma * 3)))
    x = np.arange(-radius, radius + 1, dtype=np.float32)
    kernel = np.exp(-(x * x) / (2 * sigma * sigma))
    kernel /= kernel.sum()
    padded = np.pad(array, radius, mode="edge")
    rows = np.apply_along_axis(lambda r: np.convolve(r, kernel, mode="valid"), 1, padded)
    return np.apply_along_axis(lambda c: np.convolve(c, kernel, mode="valid"), 0, rows)


def outline(w, h, cuts, inset=0.0):
    """Polygon with 45 degree cuts; `cuts` = (top-left, top-right, bottom-right, bottom-left)."""
    i = inset
    tl, tr, br, bl = [max(0.0, c - inset * 0.41) for c in cuts]
    points = []
    points += [(i, i + tl), (i + tl, i)] if tl > 0 else [(i, i)]
    points += [(w - i - tr, i), (w - i, i + tr)] if tr > 0 else [(w - i, i)]
    points += [(w - i, h - i - br), (w - i - br, h - i)] if br > 0 else [(w - i, h - i)]
    points += [(i + bl, h - i), (i, h - i - bl)] if bl > 0 else [(i, h - i)]
    return points


def mask(w, h, cuts, inset=0.0):
    s = SUPERSAMPLE
    image = Image.new("L", (w * s, h * s), 0)
    ImageDraw.Draw(image).polygon([(x * s, y * s) for x, y in outline(w, h, cuts, inset)], fill=255)
    return np.asarray(image.resize((w, h), Image.LANCZOS), np.float32) / 255.0


def tech_cuts(cut, profile):
    """Asymmetric sci-fi silhouette: prominent cuts top-left and bottom-right."""
    c = cut * profile["cut"]
    return (c, c * 0.38, c, c * 0.38)


def inside_distance(coverage, limit, open_edges=()):
    solid = (coverage > 0.5).astype(np.uint8) * 255
    padded = np.pad(solid, 1, mode="constant")
    if "bottom" in open_edges:
        padded[-1:] = padded[-2]
    current = Image.fromarray(padded)
    distance = np.zeros(padded.shape, np.float32)
    for _ in range(limit):
        distance += np.asarray(current, np.float32) / 255.0
        current = current.filter(ImageFilter.MinFilter(3))
    return gaussian(distance[1:-1, 1:-1], 0.7).astype(np.float32)


def bevel(coverage, width, raised=True, open_edges=()):
    distance = inside_distance(coverage, width + 2, open_edges)
    gy, gx = np.gradient(distance)
    length = np.sqrt(gx * gx + gy * gy) + 1e-6
    nx, ny = -gx / length, -gy / length
    if not raised:
        nx, ny = -nx, -ny
    facing = nx * LIGHT[0] + ny * LIGHT[1]
    band = np.clip(1.0 - (distance - 1.0) / width, 0.0, 1.0) ** 0.72
    return facing * band * (distance > 0)


# --- materials ----------------------------------------------------------------


def noise(w, h, rng, strength=1.0, streak=18.0):
    base = rng.normal(0.0, 1.0, (h, w)).astype(np.float32)
    streaks = np.asarray(
        Image.fromarray(base, mode="F")
        .resize((max(1, int(w / streak)), h), Image.BILINEAR)
        .resize((w, h), Image.BICUBIC),
        np.float32,
    )
    grain = gaussian(base, 0.6)
    broad = rng.normal(0.0, 1.0, (max(2, h // 24), max(2, w // 24))).astype(np.float32)
    broad = np.asarray(Image.fromarray(broad, mode="F").resize((w, h), Image.BICUBIC), np.float32)
    return (streaks * 0.52 + grain * 0.22 + broad * 0.48) * strength


def pattern(kind, w, h, rng):
    """Surface detail in -1..1, added to a material's brightness."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    if kind == "brushed":
        return noise(w, h, rng, 0.95, 22.0)
    if kind == "smooth":
        return noise(w, h, rng, 0.35, 42.0)
    if kind == "diamond":
        u = (xx + yy) / 14.0
        v = (xx - yy) / 14.0
        bump = np.cos(u * math.pi * 2) * np.cos(v * math.pi * 2)
        ridge = np.clip((bump - 0.55) * 4, 0, 1)
        shade = np.roll(ridge, 1, axis=0) - np.roll(ridge, -1, axis=0)
        return ridge * 0.55 + shade * 0.75 + noise(w, h, rng, 0.75, 6.0)
    if kind == "grid":
        lines = ((xx % 16) < 1) | ((yy % 16) < 1)
        return lines.astype(np.float32) * 0.65 + noise(w, h, rng, 0.25)
    if kind == "hex":
        s = 9.0
        q = xx / (s * 1.732)
        r = yy / (s * 1.5)
        row = np.floor(r)
        q = q - (row % 2) * 0.5
        fx = q - np.floor(q) - 0.5
        fy = r - row - 0.5
        edge = np.maximum(np.abs(fx) * 1.732, np.abs(fy) * 2.0 + np.abs(fx) * 0.577)
        return np.clip((edge - 0.87) * 9, 0, 1) * 0.85 + noise(w, h, rng, 0.18)
    if kind == "scan":
        return ((yy // 2) % 2 == 0).astype(np.float32) * 0.65 + noise(w, h, rng, 0.45, 4.0)
    return np.zeros((h, w), np.float32)


def gradient(h, top, bottom):
    t = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None, None]
    return top[None, None, :] * (1 - t) + bottom[None, None, :] * t


def blend(base, colour, amount):
    return base * (1 - amount[..., None]) + colour * amount[..., None]


def compose(colour, alpha):
    return Image.fromarray(
        np.dstack(
            [np.clip(colour, 0, 255).astype(np.uint8), np.clip(alpha * 255, 0, 255).astype(np.uint8)]
        ),
        "RGBA",
    )


def edge_line(w, h, cuts, inset, width=1.6):
    return np.clip(mask(w, h, cuts, inset) - mask(w, h, cuts, inset + width), 0, 1)


def corner_ticks(w, h, cuts, inset, reach, width=2.2):
    """Brighter accent segments around all four corners, stronger on major cuts."""
    line = edge_line(w, h, cuts, inset, width)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    near_tl = np.clip(1 - (xx + yy) / (cuts[0] + reach), 0, 1) > 0
    near_br = np.clip(1 - ((w - xx) + (h - yy)) / (cuts[2] + reach), 0, 1) > 0
    near_tr = np.clip(1 - ((w - xx) + yy) / (cuts[1] + reach * 0.65), 0, 1) > 0
    near_bl = np.clip(1 - (xx + (h - yy)) / (cuts[3] + reach * 0.65), 0, 1) > 0
    return line * np.maximum(near_tl | near_br, (near_tr | near_bl) * 0.55)


def fasteners(colour, alpha, w, h, offset, radius, kind, cuts=None):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    if cuts is not None:
        tl_off = max(offset, cuts[0] * 0.55 + radius + 3.5)
        br_off = max(offset, cuts[2] * 0.55 + radius + 3.5)
        points = [
            (tl_off * 0.72 + 4.0, tl_off * 0.72 + 4.0),
            (w - offset, offset),
            (w - br_off * 0.72 - 4.0, h - br_off * 0.72 - 4.0),
            (offset, h - offset),
        ]
    else:
        points = [(offset, offset), (w - offset, offset), (w - offset, h - offset), (offset, h - offset)]
    for cx, cy in points:
        dx, dy = xx - cx, yy - cy
        r = np.sqrt(dx * dx + dy * dy)
        head = np.clip(radius + 0.5 - r, 0, 1)
        shadow = np.clip(radius + 2.0 - np.sqrt((dx - 1.2) ** 2 + (dy - 1.6) ** 2), 0, 1)
        colour = colour * (1 - shadow[..., None] * 0.62)
        facing = np.clip((dx * LIGHT[0] + dy * LIGHT[1]) / radius, -1, 1)
        tone = 78 + 64 * facing
        face = np.stack([tone * 1.03, tone, tone * 0.94], -1)
        if kind == "bolt":
            hexagon = np.zeros_like(r)
            for k in range(6):
                a = math.pi / 3 * k + math.pi / 6
                hexagon = np.maximum(hexagon, dx * math.cos(a) + dy * math.sin(a))
            face = face * (1 - np.clip(radius * 0.45 - hexagon, 0, 1)[..., None] * 0.72)
        colour = blend(colour, face, head)
        alpha = np.maximum(alpha, head)
    return colour, alpha


# --- assets -------------------------------------------------------------------


def plate(p, rng, w, h, cut, frame, bevel_width, fastener=0.0, glass=True):
    """A sculpted console plate: machined metallic frame around a deep recessed cavity."""
    cuts = tech_cuts(cut, p)
    coverage = mask(w, h, cuts)
    body = mask(w, h, cuts, 2.0)
    colour = gradient(h, p["frame_top"], p["frame_bottom"])
    colour = colour + (pattern(p["frame_pattern"], w, h, rng) * 7.5)[..., None]

    # Machined armor bevel with crisp upper specular catchlight & dark lower drop.
    light = bevel(body, max(4, bevel_width))
    colour = colour + np.where(light > 0, light * 74.0, light * 54.0)[..., None] * p["bevel_light"]

    # Crisp specular ridge right inside the outer rim on lit edges.
    ridge = edge_line(w, h, cuts, 2.0, 1.5) * np.clip(light + 0.15, 0, 1)
    colour = blend(colour, p["spec"], ridge * 0.42 * p["bevel_light"])

    # Corner armor gussets (kept strictly within corner slice regions).
    frame_px = frame * p["frame"]
    if frame_px >= 10:
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        gusset_r = min(frame_px * 1.15, min(w, h) * 0.22)
        in_corner = (
            ((xx < gusset_r) & (yy < gusset_r))
            | ((xx > w - gusset_r) & (yy < gusset_r))
            | ((xx > w - gusset_r) & (yy > h - gusset_r))
            | ((xx < gusset_r) & (yy > h - gusset_r))
        ).astype(np.float32)
        gusset_seam = edge_line(w, h, cuts, frame_px * 0.42, 1.4) * in_corner
        colour = colour * (1.0 - gusset_seam[..., None] * 0.35)
        colour = blend(colour, p["frame_top"] * 1.12, in_corner * body * 0.16)

    # Outer dark outline.
    colour = blend(colour, RIM, np.clip(coverage - body, 0, 1))
    alpha = coverage.copy()

    if frame_px > 0:
        field = mask(w, h, cuts, frame_px)
        field_colour = gradient(h, p["field_top"], p["field_bottom"])
        field_colour = field_colour + (pattern(p["field_pattern"], w, h, rng) * 2.8)[..., None]

        # Subtle upper ambient accent tint inside the dark glass cavity.
        yy = np.arange(h, dtype=np.float32)[:, None]
        top_wash = np.exp(-np.maximum(0.0, yy - frame_px) / max(10.0, h * 0.18)) * 0.10
        field_colour = blend(field_colour, p["accent"], top_wash)

        # Deep sunken cavity bevel + bottom-right inner catchlight lip.
        step = bevel(field, 5, raised=False)
        field_colour = field_colour + np.where(step > 0, step * 34.0, step * 18.0)[..., None]
        distance = inside_distance(field, 14)
        cast = np.clip(1.0 - distance / 14.0, 0, 1) ** 1.4 * np.clip(1.35 - yy / h, 0.25, 1.0)
        field_colour = field_colour * (1 - cast[..., None] * 0.68)

        # Crisp lower-right inner metallic rim around the sunken cavity.
        inner_rim = edge_line(w, h, cuts, frame_px - 1.5, 1.6)
        field_rim_lit = inner_rim * np.clip(step + 0.35, 0.0, 1.0)
        colour = blend(colour, field_colour, field)
        colour = blend(colour, p["spec"], field_rim_lit * 0.24)

        if glass:
            alpha = alpha * (1 - field * (1 - p["glass"]))
        accent_inset = frame_px - 3.0
    else:
        accent_inset = 5.0

    # Luminous optical edge line + corner glow ticks.
    line = edge_line(w, h, cuts, accent_inset, 1.5) * p["edge"] * 0.36
    reach = min(w, h) * 0.45 - cuts[0] - 4
    ticks = corner_ticks(w, h, cuts, accent_inset, max(10, reach), 2.2) * p["edge"]
    lit = np.clip(np.maximum(line, ticks), 0, 1)
    halo = gaussian(lit, 2.2) * 0.85
    colour = blend(colour, p["accent"], np.clip(lit * 0.85 + halo * 0.48, 0, 1))

    if fastener and p["bolts"]:
        offset = max(cuts[1] * 0.5 + fastener + 4, frame_px * 0.48 if frame_px > 0 else fastener + 7)
        colour, alpha = fasteners(colour, alpha, w, h, offset, fastener, p["bolts"], cuts)
    return compose(colour, alpha)


def socket(p, rng, w, h, cut, depth=10, centre=True):
    cuts = tech_cuts(cut, p)
    coverage = mask(w, h, cuts)
    colour = np.broadcast_to(p["screen"], (h, w, 3)).astype(np.float32).copy()
    grid = pattern("grid" if p["field_pattern"] != "scan" else "scan", w, h, rng)
    colour = colour + (grid * 2.2)[..., None]

    # Deep recessed monitor well with crisp top/left shadow and lit lower-right bezel lip.
    shade = bevel(coverage, depth, raised=False)
    colour = colour + np.where(shade > 0, shade * 40.0, shade * 12.0)[..., None]
    distance = inside_distance(coverage, depth + 7)
    inner = np.clip(1.0 - distance / (depth + 7), 0, 1) ** 1.5
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    colour = colour * (1 - (inner * np.clip(1.3 - yy / (h * 0.55), 0.35, 1.0))[..., None] * 0.72)

    # Diagonal subtle monitor glass reflection in upper half.
    glare = np.clip(1.0 - (xx * 0.65 + yy) / (min(w, h) * 0.72), 0.0, 1.0) ** 2.0 * 0.06
    colour = blend(colour, p["spec"], glare * coverage)

    # Crisp corner ticks and bottom luminous lip.
    lip = edge_line(w, h, cuts, 1.5, 1.4) * (yy > h * 0.55)
    ticks = corner_ticks(w, h, cuts, 1.5, min(w, h) * 0.24, 1.8)
    colour = blend(colour, p["accent"], np.maximum(lip * p["edge"] * 0.55, ticks * p["edge"] * 0.7))

    alpha = coverage.copy()
    if not centre:
        # Bezel overlay over live viewport/minimap: crisp metallic inner edge + corner ticks.
        ring = np.clip(1.0 - distance / (depth + 3), 0, 1) ** 1.15
        alpha = coverage * np.maximum(ring * 0.94, ticks * 0.85)
        colour = colour * 0.75
        colour = blend(colour, p["accent"], ticks * p["edge"] * 0.85)
    return compose(colour, alpha)


def key(p, rng, w, h, cut, state):
    """A sculpted tactile console switch with 3D physical lip, specular edge, and radiant hover."""
    cuts = tech_cuts(cut, p)
    coverage = mask(w, h, cuts)
    pressed = state in ("pressed", "primary_pressed")
    hover = state in ("hover", "primary_hover")
    disabled = state == "disabled"
    primary = state.startswith("primary")

    lip = 2 if pressed else 5
    face = np.pad(mask(w, h - lip, cuts), ((0, lip), (0, 0)))
    if pressed:
        face = np.roll(face, 2, axis=0)

    top, bottom = (p["paint_top"], p["paint_bottom"]) if primary else (p["key_top"], p["key_bottom"])
    if hover:
        top, bottom = top * 1.18, bottom * 1.15
    elif pressed:
        top, bottom = top * 0.80, bottom * 0.85
    elif disabled:
        top, bottom = top * 0.60, bottom * 0.66

    # Recessed key well / lower physical switch lip.
    colour = gradient(h, bottom * 0.36, bottom * 0.22)
    face_colour = gradient(h, top, bottom) + (pattern(p["frame_pattern"], w, h, rng) * 4.5)[..., None]

    # Sharp sculpted bevels + top specular edge catchlight.
    light = bevel(face, 6)
    face_colour = face_colour + np.where(
        light > 0, light * (24 if disabled else 68), light * 34
    )[..., None]

    yy = np.arange(h, dtype=np.float32)[:, None]
    # Inner bright specular hairline along upper face edge.
    upper_mask = np.clip(1.0 - (yy - (4 if pressed else 2)) / 12.0, 0.0, 1.0)
    top_edge = np.clip(face - np.roll(face, 2, axis=0), 0.0, 1.0) * upper_mask
    face_colour = blend(face_colour, p["spec"], top_edge * (0.18 if disabled else 0.45))

    # Primary & hover luminous accent radiance.
    if primary:
        rim = edge_line(w, h, cuts, 2.5, 2.0) * face
        face_colour = blend(face_colour, p["accent"] * 1.15, rim * (0.75 if hover else 0.55))
        rise = np.clip(1.0 - yy / (h * 0.65), 0.0, 1.0) ** 1.4
        face_colour = face_colour + p["accent"][None, None, :] * rise[..., None] * (0.22 if hover else 0.10)
    elif hover or pressed:
        rim = edge_line(w, h, cuts, 2.5, 1.8) * face
        face_colour = blend(face_colour, p["accent"], rim * (0.65 if hover else 0.80))
        rise = np.clip((yy - h * 0.2) / (h * 0.8), 0, 1) ** 1.5
        face_colour = face_colour + p["accent"][None, None, :] * rise[..., None] * (0.28 if hover else 0.38)

    if not primary and not disabled:
        # Crisp glowing LED bar just above the key's lower edge.
        strip_y = (h - lip - 7) + (2 if pressed else 0)
        strip = (np.abs(yy - strip_y) < 1.0).astype(np.float32) * np.ones((1, w), np.float32)
        strip = strip * mask(w, h, cuts, 10)
        glow_strip = gaussian(strip, 1.6)
        strength = 0.78 if (hover or pressed) else 0.42
        face_colour = blend(face_colour, p["accent"], np.clip(strip * strength + glow_strip * strength * 0.5, 0, 1))

    # Crisp dark bevel border around face, then outer housing rim.
    face_colour = face_colour * (1 - np.clip(face - mask(w, h, cuts, 2.5) * face, 0, 1)[..., None] * 0.55)
    colour = blend(colour, face_colour, face)
    colour = blend(colour, RIM, np.clip(coverage - mask(w, h, cuts, 1.5), 0, 1) * 0.88)
    return compose(colour, coverage)


def tab(p, rng, w, h, state):
    cuts = (12 * p["cut"], 5 * p["cut"], 0, 0)
    coverage = mask(w, h + 12, cuts)[:h]
    body = mask(w, h + 12, cuts, 2)[:h]
    top, bottom = {
        "selected": (p["frame_top"] * 1.02, p["field_top"] * 1.35),
        "hover": (p["key_top"] * 1.0, p["key_bottom"]),
        "unselected": (p["key_bottom"] * 0.9, p["key_bottom"] * 0.62),
    }[state]
    colour = gradient(h, top, bottom) + (pattern(p["frame_pattern"], w, h, rng) * 4.0)[..., None]
    light = bevel(body, 4, open_edges=("bottom",))
    colour = colour + np.where(light > 0, light * 56.0, light * 28.0)[..., None]

    yy = np.arange(h, dtype=np.float32)[:, None]
    if state == "selected":
        # Bright glowing faction crown along the top bevel of the active tab.
        top_bar = np.clip(1.0 - np.abs(yy - 3.5) / 2.0, 0.0, 1.0) * body
        wash = np.exp(-np.maximum(0.0, yy - 3.5) / 14.0) * 0.25 * body
        colour = blend(colour, p["accent"], np.clip(top_bar * 0.92 + wash, 0.0, 1.0))
    else:
        colour = colour * (1 - np.clip((yy - h * 0.50) / (h * 0.50), 0, 1)[..., None] * 0.45)

    rim = np.clip(coverage - body, 0, 1)
    rim[-4:] = 0
    colour = blend(colour, RIM, rim)
    return compose(colour, coverage)


def rail(p, rng, w, h):
    colour = gradient(h, p["frame_top"] * 0.95, p["frame_bottom"] * 0.78)
    colour = colour + (pattern(p["frame_pattern"], w, h, rng) * 6.5)[..., None]
    yy = np.arange(h, dtype=np.float32)[:, None]
    colour = colour + (np.clip(1 - (yy - 2) / 4.5, 0, 1) * 48.0)[..., None]
    colour = colour - (np.clip((yy - (h - 6)) / 4.5, 0, 1) * 28.0)[..., None]
    colour[0:2] = RIM
    colour[h - 2 :] = RIM
    mid = h // 2
    colour[mid - 2 : mid + 2] = colour[mid - 2 : mid + 2] * 0.42
    xx = np.arange(w, dtype=np.float32)[None, :]
    segment = (np.abs(xx - w / 2) < w * 0.22).astype(np.float32) * (np.abs(yy - mid) < 1.1)
    glow = gaussian(segment, 1.6)
    colour = blend(colour, p["accent"], np.clip(segment * p["edge"] * 0.9 + glow * 0.55, 0, 1))
    alpha = np.ones((h, w), np.float32)
    if p["bolts"]:
        colour, alpha = fasteners(colour, alpha, w, h, h / 2, h * 0.16, p["bolts"])
    return compose(colour, alpha)


def stripe(p, rng, w, h):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dark = rgb("111417")
    if p["stripe"] == "hazard":
        band = ((xx + yy) // 16) % 2 == 0
        colour = np.where(band[..., None], rgb("d9a33a"), dark)
    elif p["stripe"] == "chevron":
        band = ((np.abs(yy - h / 2) + xx) // 12) % 2 == 0
        colour = np.where(band[..., None], p["accent"] * 0.95, dark)
    else:
        band = ((xx // 10) % 2 == 0) & (np.abs(yy - h / 2) < h * 0.22)
        colour = np.where(band[..., None], p["accent"], dark)
        colour = colour + (gaussian(band.astype(np.float32), 1.5) * 64)[..., None] * (p["accent"] / 255.0)
    colour = colour + (noise(w, h, rng, 3.5, 3.0))[..., None]
    colour[0:2] = RIM
    colour[h - 2 :] = RIM
    return compose(colour, np.ones((h, w), np.float32))


def nameplate(p, rng, w, h):
    cuts = (6 * p["cut"], 0, 6 * p["cut"], 0)
    coverage = mask(w, h, cuts)
    colour = gradient(h, p["field_top"] * 0.95, p["field_bottom"] * 0.78)
    colour = colour + (pattern(p["field_pattern"], w, h, rng) * 2.0)[..., None]
    shade = bevel(coverage, 4, raised=False)
    colour = colour + np.where(shade > 0, shade * 30.0, shade * 12.0)[..., None]
    notch = np.zeros((h, w), np.float32)
    notch[6 : h - 6, 6:11] = 1.0
    colour = blend(colour, p["accent"], notch + gaussian(notch, 1.8) * 0.5 * (1 - notch))
    lip = edge_line(w, h, cuts, 1.2, 1.2)
    colour = blend(colour, p["accent"], lip * 0.25)
    return compose(colour, coverage)


def segment(w, h, gap):
    alpha = np.zeros((h, w), np.float32)
    alpha[2 : h - 2, : w - gap] = 1.0
    yy = np.arange(h, dtype=np.float32)[:, None]
    # Crisp bright upper highlight + gentle shade so health/power cells read like LEDs.
    tone = 255 - np.clip((yy - 2) / max(1, h - 4), 0, 1) * 78.0
    tone[2:4, :] = 255.0
    return compose(np.broadcast_to(np.minimum(tone, 255)[..., None], (h, w, 3)).astype(np.float32), alpha)


def brackets(w, h, length, thickness):
    alpha = np.zeros((h, w), np.float32)
    t, n = thickness, length
    for ys, xs in [
        (slice(0, t), slice(0, n)), (slice(0, n), slice(0, t)),
        (slice(0, t), slice(w - n, w)), (slice(0, n), slice(w - t, w)),
        (slice(h - t, h), slice(0, n)), (slice(h - n, h), slice(0, t)),
        (slice(h - t, h), slice(w - n, w)), (slice(h - n, h), slice(w - t, w)),
    ]:
        alpha[ys, xs] = 1.0
    return compose(np.full((h, w, 3), 255, np.float32), alpha)


def glow(w, h, cut, reach=16):
    coverage = mask(w, h, (cut, cut * 0.35, cut, cut * 0.35))
    distance = inside_distance(coverage, reach)
    alpha = (np.clip(1.0 - distance / reach, 0, 1) ** 1.85 * 0.85 + 0.14) * coverage
    return compose(np.full((h, w, 3), 255, np.float32), alpha)


def faction_kit(p):
    rng = np.random.default_rng(p["seed"])
    return {
        "plate_heavy": plate(p, rng, 192, 192, 26, 20, 6, fastener=4.5),
        "plate_panel": plate(p, rng, 128, 128, 16, 11, 5, fastener=3.2),
        "plate_strip": plate(p, rng, 128, 128, 16, 0, 5, fastener=3.2, glass=False),
        "plate_card": plate(p, rng, 96, 96, 10, 4, 3),
        "socket": socket(p, rng, 96, 96, 10),
        "socket_frame": socket(p, rng, 96, 96, 10, centre=False),
        "nameplate": nameplate(p, rng, 128, 48),
        "key_normal": key(p, rng, 96, 96, 10, "normal"),
        "key_hover": key(p, rng, 96, 96, 10, "hover"),
        "key_pressed": key(p, rng, 96, 96, 10, "pressed"),
        "key_disabled": key(p, rng, 96, 96, 10, "disabled"),
        "key_primary": key(p, rng, 96, 96, 10, "primary"),
        "key_primary_hover": key(p, rng, 96, 96, 10, "primary_hover"),
        "key_primary_pressed": key(p, rng, 96, 96, 10, "primary_pressed"),
        "tab_selected": tab(p, rng, 96, 64, "selected"),
        "tab_hover": tab(p, rng, 96, 64, "hover"),
        "tab_unselected": tab(p, rng, 96, 64, "unselected"),
        "rail": rail(p, rng, 128, 28),
        "stripe": stripe(p, rng, 64, 32),
    }


def build(out):
    out.mkdir(parents=True, exist_ok=True)
    shared = {
        "bar_segment": segment(16, 24, 3),
        "focus": brackets(64, 64, 16, 3),
        "glow": glow(96, 96, 14),
    }
    for name, image in shared.items():
        image.save(out / f"{name}.png", optimize=True)
    for faction, profile in PROFILES.items():
        folder = out / faction
        folder.mkdir(exist_ok=True)
        for name, image in faction_kit(profile).items():
            image.save(folder / f"{name}.png", optimize=True)


if __name__ == "__main__":
    default = Path(__file__).resolve().parents[2] / "assets/ui/hud"
    build(Path(sys.argv[1]) if len(sys.argv) > 1 else default)
    print("Wrote HUD kits")
