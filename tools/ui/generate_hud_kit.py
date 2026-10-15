"""Generate the battle-console texture kits, one per faction.

Every faction shares a futuristic console language (asymmetric chamfers, thin
luminous edge lines with brighter corner ticks, glass screens with fine grids,
slim keys with a soft light strip) and carries its own material and accent:

    bastion   armoured gunmetal, flush bolts, amber accent, chevron stripes
    helix     graphite-blue glass, hex micro-pattern, cyan accent, data dashes
    frontier  salvaged warm metal, rivets, diamond plate, orange accent, hazard

Textures are authored at 2x logical resolution and drawn at half scale by
`source/match/hud/HudStyle.gd`; slice sizes in `BattleTheme.gd` are logical.
State changes (hover, pressed, selected) are fills and glows, never coloured
borders. Accent lines are decorative and identical across states.

Usage:
    python tools/ui/generate_hud_kit.py [output_dir]

Requires Pillow and NumPy. Output defaults to assets/ui/hud/. Each faction gets
a subfolder; state overlays (glow, focus, bar cells) are shared and white so the
theme can tint them. Noise seeds are fixed, so output is reproducible.
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SUPERSAMPLE = 4
LIGHT = np.array([-0.55, -0.83])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
RIM = np.array([5, 7, 9], np.float32)


def rgb(hex_value):
    return np.array([int(hex_value[i : i + 2], 16) for i in (0, 2, 4)], np.float32)


PROFILES = {
    "bastion": {
        "frame_top": rgb("4a5157"),
        "frame_bottom": rgb("2a2f33"),
        "field_top": rgb("1a2025"),
        "field_bottom": rgb("12171b"),
        "screen": rgb("0a1013"),
        "accent": rgb("e8b04a"),
        "glass": 0.92,
        "edge": 0.7,
        "cut": 1.2,
        "frame": 0.9,
        "bolts": "bolt",
        "frame_pattern": "brushed",
        "field_pattern": "grid",
        "stripe": "chevron",
        "key_top": rgb("3f464c"),
        "key_bottom": rgb("262b30"),
        "paint_top": rgb("e9b450"),
        "paint_bottom": rgb("b9842c"),
        "seed": 11,
    },
    "helix": {
        "frame_top": rgb("33404a"),
        "frame_bottom": rgb("1b242c"),
        "field_top": rgb("0f1d26"),
        "field_bottom": rgb("0a141b"),
        "screen": rgb("06121a"),
        "accent": rgb("54d6e6"),
        "glass": 0.86,
        "edge": 0.95,
        "cut": 1.45,
        "frame": 0.6,
        "bolts": None,
        "frame_pattern": "smooth",
        "field_pattern": "hex",
        "stripe": "dashes",
        "key_top": rgb("2c3a45"),
        "key_bottom": rgb("18222a"),
        "paint_top": rgb("6fe2ef"),
        "paint_bottom": rgb("2ea9bd"),
        "seed": 23,
    },
    "frontier": {
        "frame_top": rgb("57493a"),
        "frame_bottom": rgb("2f2720"),
        "field_top": rgb("201c17"),
        "field_bottom": rgb("161310"),
        "screen": rgb("0b110c"),
        "accent": rgb("ef8a3c"),
        "glass": 0.95,
        "edge": 0.62,
        "cut": 0.9,
        "frame": 1.1,
        "bolts": "rivet",
        "frame_pattern": "diamond",
        "field_pattern": "scan",
        "stripe": "hazard",
        "key_top": rgb("4a3f33"),
        "key_bottom": rgb("2a231c"),
        "paint_top": rgb("f19a4c"),
        "paint_bottom": rgb("c06526"),
        "seed": 37,
    },
}

RNG = np.random.default_rng(7)


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
    """Asymmetric sci-fi silhouette: large cuts top-left and bottom-right."""
    c = cut * profile["cut"]
    return (c, c * 0.35, c, c * 0.35)


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
    return gaussian(distance[1:-1, 1:-1], 0.8).astype(np.float32)


def bevel(coverage, width, raised=True, open_edges=()):
    distance = inside_distance(coverage, width + 2, open_edges)
    gy, gx = np.gradient(distance)
    length = np.sqrt(gx * gx + gy * gy) + 1e-6
    nx, ny = -gx / length, -gy / length
    if not raised:
        nx, ny = -nx, -ny
    facing = nx * LIGHT[0] + ny * LIGHT[1]
    band = np.clip(1.0 - (distance - 1.0) / width, 0.0, 1.0) ** 0.8
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
    return (streaks * 0.5 + grain * 0.25 + broad * 0.5) * strength


def pattern(kind, w, h, rng):
    """Surface detail in -1..1, added to a material's brightness."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    if kind == "brushed":
        return noise(w, h, rng, 0.9)
    if kind == "smooth":
        return noise(w, h, rng, 0.35, 40.0)
    if kind == "diamond":
        # Raised diamond tread plate, lit from the top-left.
        u = (xx + yy) / 14.0
        v = (xx - yy) / 14.0
        bump = np.cos(u * math.pi * 2) * np.cos(v * math.pi * 2)
        ridge = np.clip((bump - 0.55) * 4, 0, 1)
        shade = np.roll(ridge, 1, axis=0) - np.roll(ridge, -1, axis=0)
        return ridge * 0.6 + shade * 0.8 + noise(w, h, rng, 0.8, 6.0)
    if kind == "grid":
        lines = ((xx % 16) < 1) | ((yy % 16) < 1)
        return lines.astype(np.float32) * 1.0 + noise(w, h, rng, 0.3)
    if kind == "hex":
        s = 9.0
        q = xx / (s * 1.732)
        r = yy / (s * 1.5)
        row = np.floor(r)
        q = q - (row % 2) * 0.5
        fx = q - np.floor(q) - 0.5
        fy = r - row - 0.5
        edge = np.maximum(np.abs(fx) * 1.732, np.abs(fy) * 2.0 + np.abs(fx) * 0.577)
        return np.clip((edge - 0.86) * 9, 0, 1) * 1.2 + noise(w, h, rng, 0.2)
    if kind == "scan":
        return ((yy // 2) % 2 == 0).astype(np.float32) * 0.8 + noise(w, h, rng, 0.5, 4.0)
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


def corner_ticks(w, h, cuts, inset, reach):
    """Brighter accent segments around the two large cuts."""
    line = edge_line(w, h, cuts, inset, 2.0)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    near_tl = np.clip(1 - (xx + yy) / (cuts[0] + reach), 0, 1) > 0
    near_br = np.clip(1 - ((w - xx) + (h - yy)) / (cuts[2] + reach), 0, 1) > 0
    return line * (near_tl | near_br)


def fasteners(colour, alpha, w, h, offset, radius, kind):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    for cx, cy in [(offset, offset), (w - offset, offset), (w - offset, h - offset), (offset, h - offset)]:
        dx, dy = xx - cx, yy - cy
        r = np.sqrt(dx * dx + dy * dy)
        head = np.clip(radius + 0.5 - r, 0, 1)
        shadow = np.clip(radius + 1.8 - np.sqrt((dx - 1.2) ** 2 + (dy - 1.6) ** 2), 0, 1)
        colour = colour * (1 - shadow[..., None] * 0.5)
        facing = np.clip((dx * LIGHT[0] + dy * LIGHT[1]) / radius, -1, 1)
        tone = 64 + 52 * facing
        face = np.stack([tone * 1.02, tone, tone * 0.95], -1)
        if kind == "bolt":
            hexagon = np.zeros_like(r)
            for k in range(6):
                a = math.pi / 3 * k + math.pi / 6
                hexagon = np.maximum(hexagon, dx * math.cos(a) + dy * math.sin(a))
            face = face * (1 - np.clip(radius * 0.45 - hexagon, 0, 1)[..., None] * 0.7)
        colour = blend(colour, face, head)
        alpha = np.maximum(alpha, head)
    return colour, alpha


# --- assets -------------------------------------------------------------------


def plate(p, rng, w, h, cut, frame, bevel_width, fastener=0.0, glass=True):
    """A framed console plate: lit frame material around a glass field."""
    cuts = tech_cuts(cut, p)
    coverage = mask(w, h, cuts)
    body = mask(w, h, cuts, 2)
    colour = gradient(h, p["frame_top"], p["frame_bottom"])
    colour = colour + (pattern(p["frame_pattern"], w, h, rng) * 7.0)[..., None]
    light = bevel(body, max(3, bevel_width - 2))
    colour = colour + np.where(light > 0, light * 58.0, light * 42.0)[..., None]
    # A crisp machined hairline where the face meets the top-left bevel.
    hairline = edge_line(w, h, cuts, 2, 1.0) * (light > 0.2)
    colour = colour + (hairline * 40.0)[..., None]
    colour = blend(colour, RIM, np.clip(coverage - body, 0, 1))
    alpha = coverage.copy()
    frame_px = frame * p["frame"]
    if frame_px > 0:
        field = mask(w, h, cuts, frame_px)
        field_colour = gradient(h, p["field_top"], p["field_bottom"])
        field_colour = field_colour + (pattern(p["field_pattern"], w, h, rng) * 3.2)[..., None]
        step = bevel(field, 4, raised=False)
        field_colour = field_colour + np.where(step > 0, step * 26.0, step * 12.0)[..., None]
        distance = inside_distance(field, 10)
        yy = np.arange(h, dtype=np.float32)[:, None]
        cast = np.clip(1.0 - distance / 10.0, 0, 1) ** 1.5 * np.clip(1.3 - yy / h, 0.3, 1.0)
        field_colour = field_colour * (1 - cast[..., None] * 0.5)
        colour = blend(colour, field_colour, field)
        if glass:
            alpha = alpha * (1 - field * (1 - p["glass"]))
        accent_inset = frame_px - 2.5
    else:
        accent_inset = 5.0
    # Decorative luminous edge, brighter at the large cuts.
    line = edge_line(w, h, cuts, accent_inset) * p["edge"] * 0.45
    reach = min(w, h) * 0.5 - cuts[0] - 6
    ticks = corner_ticks(w, h, cuts, accent_inset, max(10, reach)) * p["edge"]
    lit = np.clip(np.maximum(line, ticks), 0, 1)
    halo = gaussian(lit, 2.0) * 0.9
    colour = blend(colour, p["accent"], np.clip(lit + halo * 0.5, 0, 1))
    if fastener and p["bolts"]:
        offset = cuts[1] * 0.4 + fastener + 4
        colour, alpha = fasteners(colour, alpha, w, h, offset, fastener, p["bolts"])
    return compose(colour, alpha)


def socket(p, rng, w, h, cut, depth=9, centre=True):
    cuts = tech_cuts(cut, p)
    coverage = mask(w, h, cuts)
    colour = np.broadcast_to(p["screen"], (h, w, 3)).astype(np.float32).copy()
    grid = pattern("grid" if p["field_pattern"] != "scan" else "scan", w, h, rng)
    colour = colour + (grid * 2.5)[..., None]
    shade = bevel(coverage, depth, raised=False)
    colour = colour + np.where(shade > 0, shade * 34.0, shade * 8.0)[..., None]
    distance = inside_distance(coverage, depth + 6)
    inner = np.clip(1.0 - distance / (depth + 6), 0, 1) ** 1.6
    yy = np.arange(h, dtype=np.float32)[:, None]
    colour = colour * (1 - (inner * np.clip(1.25 - yy / (h * 0.55), 0.35, 1.0))[..., None] * 0.65)
    # A faint lit hairline along the lower lip of the screen.
    lip = edge_line(w, h, cuts, 1.5, 1.2) * (yy > h * 0.5)
    colour = blend(colour, p["accent"], lip * p["edge"] * 0.45)
    alpha = coverage.copy()
    if not centre:
        alpha = coverage * np.clip(1.0 - distance / (depth + 4), 0, 1) ** 0.9 * 0.92
        colour = colour * 0.6
    return compose(colour, alpha)


def key(p, rng, w, h, cut, state):
    """A slim console key. States change the face fill and glow; the light strip is constant."""
    cuts = tech_cuts(cut, p)
    coverage = mask(w, h, cuts)
    pressed = state in ("pressed", "primary_pressed")
    lip = 2 if pressed else 5
    face = np.pad(mask(w, h - lip, cuts), ((0, lip), (0, 0)))
    if pressed:
        face = np.roll(face, 2, axis=0)
    primary = state.startswith("primary")
    top, bottom = (p["paint_top"], p["paint_bottom"]) if primary else (p["key_top"], p["key_bottom"])
    if state in ("hover", "primary_hover"):
        top, bottom = top * 1.14, bottom * 1.12
    elif pressed:
        top, bottom = top * 0.82, bottom * 0.84
    elif state == "disabled":
        top, bottom = top * 0.66, bottom * 0.72
    colour = gradient(h, bottom * 0.4, bottom * 0.28)
    face_colour = gradient(h, top, bottom) + (pattern(p["frame_pattern"], w, h, rng) * 4.0)[..., None]
    light = bevel(face, 5)
    face_colour = face_colour + np.where(light > 0, light * (22 if state == "disabled" else 52), light * 26)[..., None]
    yy = np.arange(h, dtype=np.float32)[:, None]
    if state in ("hover", "pressed") and not primary:
        rise = np.clip((yy - h * 0.25) / (h * 0.75), 0, 1) ** 1.6
        face_colour = face_colour + p["accent"][None, None, :] * rise[..., None] * (0.3 if state == "hover" else 0.42)
    if not primary and state != "disabled":
        # Decorative light strip just above the key's lower edge.
        strip_y = (h - lip - 7) + (2 if pressed else 0)
        strip = (np.abs(yy - strip_y) < 0.9).astype(np.float32) * np.ones((1, w), np.float32)
        strip = strip * mask(w, h, cuts, 9)
        face_colour = blend(face_colour, p["accent"], strip * 0.35)
    face_colour = face_colour * (1 - np.clip(face - mask(w, h, cuts, 2) * face, 0, 1)[..., None] * 0.5)
    colour = blend(colour, face_colour, face)
    colour = blend(colour, RIM, np.clip(coverage - mask(w, h, cuts, 1), 0, 1) * 0.8)
    return compose(colour, coverage)


def tab(p, rng, w, h, state):
    cuts = (12 * p["cut"], 4 * p["cut"], 0, 0)
    coverage = mask(w, h + 12, cuts)[:h]
    body = mask(w, h + 12, cuts, 2)[:h]
    top, bottom = {
        "selected": (p["frame_top"] * 0.95, p["field_top"] * 1.25),
        "hover": (p["key_top"] * 0.95, p["key_bottom"]),
        "unselected": (p["key_bottom"] * 0.95, p["key_bottom"] * 0.7),
    }[state]
    colour = gradient(h, top, bottom) + (pattern(p["frame_pattern"], w, h, rng) * 4.0)[..., None]
    light = bevel(body, 4, open_edges=("bottom",))
    colour = colour + np.where(light > 0, light * 48.0, light * 24.0)[..., None]
    if state != "selected":
        yy = np.arange(h, dtype=np.float32)[:, None]
        colour = colour * (1 - np.clip((yy - h * 0.55) / (h * 0.45), 0, 1)[..., None] * 0.4)
    rim = np.clip(coverage - body, 0, 1)
    rim[-4:] = 0
    colour = blend(colour, RIM, rim)
    return compose(colour, coverage)


def rail(p, rng, w, h):
    colour = gradient(h, p["frame_top"] * 0.9, p["frame_bottom"] * 0.8)
    colour = colour + (pattern(p["frame_pattern"], w, h, rng) * 6.0)[..., None]
    yy = np.arange(h, dtype=np.float32)[:, None]
    colour = colour + (np.clip(1 - (yy - 2) / 4.0, 0, 1) * 36.0)[..., None]
    colour = colour - (np.clip((yy - (h - 6)) / 4.0, 0, 1) * 24.0)[..., None]
    colour[0:2] = RIM
    colour[h - 2 :] = RIM
    # A recessed channel with a light segment in the middle of each tile.
    mid = h // 2
    colour[mid - 1 : mid + 2] = colour[mid - 1 : mid + 2] * 0.45
    xx = np.arange(w, dtype=np.float32)[None, :]
    segment = (np.abs(xx - w / 2) < w * 0.18).astype(np.float32) * (np.abs(yy - mid) < 1.0)
    glow = gaussian(segment, 1.4)
    colour = blend(colour, p["accent"], np.clip(segment * p["edge"] + glow * 0.5, 0, 1))
    alpha = np.ones((h, w), np.float32)
    if p["bolts"]:
        colour, alpha = fasteners(colour, alpha, w, h, h / 2, h * 0.16, p["bolts"])
    return compose(colour, alpha)


def stripe(p, rng, w, h):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dark = rgb("141618")
    if p["stripe"] == "hazard":
        band = ((xx + yy) // 16) % 2 == 0
        colour = np.where(band[..., None], rgb("d9a33a"), dark)
    elif p["stripe"] == "chevron":
        band = ((np.abs(yy - h / 2) + xx) // 12) % 2 == 0
        colour = np.where(band[..., None], p["accent"] * 0.95, dark)
    else:
        band = ((xx // 10) % 2 == 0) & (np.abs(yy - h / 2) < h * 0.22)
        colour = np.where(band[..., None], p["accent"], dark)
        colour = colour + (gaussian(band.astype(np.float32), 1.5) * 60)[..., None] * (p["accent"] / 255.0)
    colour = colour + (noise(w, h, rng, 4.0, 3.0))[..., None]
    colour[0:2] = RIM
    colour[h - 2 :] = RIM
    return compose(colour, np.ones((h, w), np.float32))


def nameplate(p, rng, w, h):
    cuts = (6 * p["cut"], 0, 6 * p["cut"], 0)
    coverage = mask(w, h, cuts)
    colour = gradient(h, p["field_bottom"] * 0.95, p["field_bottom"] * 0.75)
    colour = colour + (pattern(p["field_pattern"], w, h, rng) * 2.0)[..., None]
    shade = bevel(coverage, 4, raised=False)
    colour = colour + np.where(shade > 0, shade * 26.0, shade * 10.0)[..., None]
    notch = np.zeros((h, w), np.float32)
    notch[6 : h - 6, 6:12] = 1.0
    colour = blend(colour, p["accent"], notch + gaussian(notch, 1.5) * 0.4 * (1 - notch))
    return compose(colour, coverage)


def segment(w, h, gap):
    alpha = np.zeros((h, w), np.float32)
    alpha[2 : h - 2, : w - gap] = 1.0
    yy = np.arange(h, dtype=np.float32)[:, None]
    tone = 255 - np.clip(yy / h, 0, 1) * 70.0
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
    alpha = (np.clip(1.0 - distance / reach, 0, 1) ** 2.0 * 0.8 + 0.12) * coverage
    return compose(np.full((h, w, 3), 255, np.float32), alpha)


def faction_kit(p):
    rng = np.random.default_rng(p["seed"])
    return {
        # Console housings (minimap, deck): 24 px logical slices.
        "plate_heavy": plate(p, rng, 192, 192, 26, 20, 6, fastener=4.5),
        # Floating briefings, dialogs: 16 px logical slices.
        "plate_panel": plate(p, rng, 128, 128, 16, 11, 5, fastener=3.2),
        # Frameless strips hanging from the top rail.
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
        "bar_segment": segment(16, 24, 4),
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
