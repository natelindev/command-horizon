#!/usr/bin/env python3
"""Render original, deterministic combat Foley/synthesis; requires Python + NumPy.

All material is generated mathematically here. No samples, models, network access,
text-to-speech, or external sound recordings are used.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import wave

import numpy as np

RATE = 48000
PEAK = 10.0 ** (-3.2 / 20.0)
ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/audio/combat"
HERE = Path(__file__).resolve().parent


def clock(seconds: float) -> np.ndarray:
    return np.arange(round(seconds * RATE), dtype=np.float64) / RATE


def noise(t: np.ndarray, rng: np.random.Generator, low: float, high: float) -> np.ndarray:
    """Smooth-band random material, normalized by RMS, without filter startup clicks."""
    count = len(t)
    frequencies = np.fft.rfftfreq(count, 1.0 / RATE)
    spectrum = np.fft.rfft(rng.standard_normal(count))
    high_pass = 1.0 - np.exp(-((frequencies / max(low, 1.0)) ** 4))
    low_pass = np.exp(-((frequencies / high) ** 4))
    shaped = np.fft.irfft(spectrum * high_pass * low_pass, n=count)
    return shaped / max(float(np.sqrt(np.mean(shaped * shaped))), 1e-8)


def envelope(t: np.ndarray, decay: float, attack: float = 0.001) -> np.ndarray:
    return (1.0 - np.exp(-t / attack)) * np.exp(-t / decay)


def sweep(t: np.ndarray, start: float, end: float, decay: float) -> np.ndarray:
    phase = 2.0 * np.pi * (end * t + (start - end) * decay * (1.0 - np.exp(-t / decay)))
    return np.sin(phase)


def add_at(target: np.ndarray, event: np.ndarray, seconds: float, gain: float = 1.0) -> None:
    offset = round(seconds * RATE)
    count = min(len(event), len(target) - offset)
    if count > 0:
        target[offset : offset + count] += event[:count] * gain


def resonances(t: np.ndarray, frequencies: list[float], decay: float) -> np.ndarray:
    out = np.zeros_like(t)
    for index, frequency in enumerate(frequencies):
        out += np.sin(2 * np.pi * frequency * t + index * 0.47) * np.exp(-t / (decay / (1 + index * 0.3))) / (index + 1)
    return out * (1 - np.exp(-t / 0.0006))


def blast(t: np.ndarray, rng: np.random.Generator, weight: float = 1.0) -> np.ndarray:
    # Broadband attack, descending pressure pulse, and turbulent low-mid tail.
    crack = noise(t, rng, 900, 13000) * envelope(t, 0.008 * weight, 0.00025)
    pressure = sweep(t, 165 / weight, 38 / weight, 0.045 * weight) * envelope(t, 0.10 * weight)
    body = noise(t, rng, 55, 850) * envelope(t, 0.075 * weight, 0.002)
    tail = noise(t, rng, 140, 2300) * envelope(t, 0.13 * weight, 0.009)
    return 0.85 * crack + 0.28 * pressure + 0.85 * body + 0.36 * tail


def synthesize(name: str, duration: float, seed: int) -> np.ndarray:
    t = clock(duration)
    rng = np.random.default_rng(seed)
    out = np.zeros_like(t)
    if name == "rifle_fire":
        out = 0.50 * blast(t, rng, 0.55)
        out += 0.64 * noise(t, rng, 1300, 13500) * envelope(t, 0.0065, 0.0002)
        # Close mechanical bolt and a light casing/receiver tick, not a second shot.
        add_at(out, resonances(t, [1620, 3173, 5907], 0.011), 0.040, 0.10)
    elif name == "autocannon_fire":
        out = blast(t, rng, 0.90)
        out += 0.23 * resonances(t, [190, 477, 1143], 0.032)
        add_at(out, noise(t, rng, 650, 4300) * envelope(t, 0.013), 0.065, 0.13)
    elif name == "cannon_fire":
        out = blast(t, rng, 1.65)
        out += 0.24 * noise(t, rng, 45, 230) * envelope(t, 0.21, 0.012)
        add_at(out, blast(t, rng, 0.72), 0.085, 0.08)
        add_at(out, blast(t, rng, 0.70), 0.170, 0.035)
    elif name == "energy_fire":
        # Electrical snap with irregular fizz and inharmonic, falling discharge.
        carrier = sweep(t, 2200, 390, 0.032)
        jitter = noise(t, rng, 650, 11000)
        out = 0.60 * jitter * envelope(t, 0.014, 0.0002)
        out += 0.26 * carrier * envelope(t, 0.047, 0.001)
        out += 0.19 * resonances(t, [843, 1397, 2369], 0.057)
        out += 0.21 * noise(t, rng, 160, 800) * envelope(t, 0.028)
        out += 0.13 * noise(t, rng, 2800, 12500) * envelope(t, 0.065, 0.008) * (0.45 + 0.55 * np.sin(t * 811) ** 2)
    elif name == "rail_fire":
        # Very fast induction crack, bass concussion, then a short metallic trace.
        out = 0.9 * noise(t, rng, 1400, 16000) * envelope(t, 0.010, 0.0002)
        out += 0.47 * sweep(t, 340, 58, 0.026) * envelope(t, 0.065)
        out += 0.38 * noise(t, rng, 80, 1600) * envelope(t, 0.057, 0.003)
        out += 0.16 * resonances(t, [1193, 2789, 4567], 0.073)
        out += 0.11 * noise(t, rng, 1000, 7600) * envelope(t, 0.12, 0.016)
    elif name == "missile_launch":
        # Ignition thump into a descending, fluttering rocket exhaust.
        out = 0.31 * blast(t, rng, 0.45)
        exhaust = noise(t, rng, 160, 6300)
        exhaust_low = noise(t, rng, 60, 1000)
        ignition = (1 - np.exp(-t / 0.018)) * np.exp(-t / 0.105)
        out += 0.50 * exhaust * ignition * (0.72 + 0.28 * np.sin(2 * np.pi * 61 * t) ** 2)
        out += 0.45 * exhaust_low * envelope(t, 0.17, 0.009)
        out += 0.12 * sweep(t, 290, 90, 0.08) * envelope(t, 0.13, 0.015)
    elif name == "impact_light":
        out = 0.50 * noise(t, rng, 800, 11000) * envelope(t, 0.007, 0.00025)
        out += 0.50 * noise(t, rng, 130, 1700) * envelope(t, 0.019)
        out += 0.12 * resonances(t, [728, 1903, 4177], 0.029)
        out += 0.10 * sweep(t, 280, 110, 0.01) * envelope(t, 0.025)
    elif name == "impact_heavy":
        out = 0.85 * blast(t, rng, 2.25)
        out += 0.42 * noise(t, rng, 35, 440) * envelope(t, 0.38, 0.008)
        out += 0.26 * noise(t, rng, 180, 2900) * envelope(t, 0.22, 0.02)
        for delay, gain in [(0.09, 0.22), (0.19, 0.16), (0.32, 0.12), (0.53, 0.06)]:
            add_at(out, noise(t, rng, 700, 6800) * envelope(t, 0.025), delay, gain)
    elif name == "infantry_fall":
        # Non-vocal cloth/ground thud plus equipment settling; intentionally non-gory.
        out = 0.55 * noise(t, rng, 65, 650) * envelope(t, 0.048, 0.003)
        out += 0.22 * sweep(t, 170, 60, 0.016) * envelope(t, 0.045)
        out += 0.11 * noise(t, rng, 800, 5300) * envelope(t, 0.075, 0.016)
        for delay, gain in [(0.057, 0.18), (0.119, 0.12), (0.197, 0.045)]:
            tap = noise(t, rng, 460, 3700) * envelope(t, 0.012)
            tap += 0.25 * resonances(t, [632, 1371, 2791], 0.016)
            add_at(out, tap, delay, gain)
    elif name == "vehicle_destroy":
        out = 0.95 * blast(t, rng, 2.00)
        out += 0.24 * noise(t, rng, 45, 1200) * envelope(t, 0.32, 0.028)
        for delay, gain, pitch in [(0.072, 0.20, 330), (0.165, 0.15, 220), (0.295, 0.10, 420), (0.441, 0.075, 280), (0.625, 0.036, 610)]:
            debris = 0.45 * noise(t, rng, 400, 4200) * envelope(t, 0.023)
            debris += resonances(t, [pitch, pitch * 2.73, pitch * 4.29], 0.066)
            add_at(out, debris, delay, gain)
        out += 0.08 * noise(t, rng, 2300, 9000) * envelope(t, 0.27, 0.07)
    elif name == "structure_destroy":
        # Multiple broad masonry fractures form a rolling collapse, with falling grit.
        out = 0.66 * blast(t, rng, 1.75)
        out += 0.20 * noise(t, rng, 30, 420) * envelope(t, 0.37, 0.04)
        for delay, gain, size in [(0.085, 0.30, 1.0), (0.181, 0.32, 0.8), (0.312, 0.24, 0.9), (0.472, 0.19, 0.7), (0.656, 0.12, 0.6), (0.873, 0.08, 0.5), (1.089, 0.035, 0.5)]:
            chunk = noise(t, rng, 95, 2800) * envelope(t, 0.053 * size, 0.001)
            chunk += 0.3 * sweep(t, 220, 65, 0.027) * envelope(t, 0.05)
            add_at(out, chunk, delay, gain)
        grit = noise(t, rng, 700, 7700)
        out += 0.14 * grit * envelope(t, 0.31, 0.082) * (0.5 + 0.5 * np.sin(t * 59.7) ** 2)
    else:
        raise ValueError(name)
    # Diffuse, uneven reflections and falling grit give reports an outdoor tail.
    # Never add a second full-volume crack; these are decaying early reflections.
    if name not in ["impact_light", "infantry_fall"]:
        dry = out.copy()
        for delay, gain in [(0.071, 0.15), (0.137, 0.105), (0.233, 0.065), (0.389, 0.038)]:
            add_at(out, dry, delay * rng.uniform(0.88, 1.12), gain)
    if name in ["cannon_fire", "impact_heavy", "vehicle_destroy", "structure_destroy"]:
        out += 0.17 * noise(t, rng, 45, 520) * envelope(t, 0.52, 0.045)
    return finish(out)


def finish(samples: np.ndarray) -> np.ndarray:
    # Remove DC, gently soften rare coincident peaks, and guarantee quiet boundaries.
    samples -= samples.mean()
    samples = np.tanh(samples * 0.72)
    samples -= samples.mean()
    attack_count, tail_count = round(0.00035 * RATE), round(0.015 * RATE)
    samples[:attack_count] *= np.sin(np.linspace(0, math.pi / 2, attack_count)) ** 2
    samples[-tail_count:] *= np.cos(np.linspace(0, math.pi / 2, tail_count)) ** 2
    samples *= PEAK / max(float(np.max(np.abs(samples))), 1e-8)
    return np.rint(samples * 32767).astype("<i2")


SPECS = [
    ("rifle_fire", 0.46, 14021, "Dry rifle crack with a compact mechanical tail"),
    ("autocannon_fire", 0.57, 14022, "Heavier automatic weapon report with a bolt clack"),
    ("cannon_fire", 1.45, 14023, "Bass-heavy cannon concussion with turbulent decay"),
    ("energy_fire", 0.25, 14024, "Electrical snap with fizz and a brief inharmonic discharge"),
    ("rail_fire", 0.39, 14025, "Induction crack, pressure pulse, and metallic trace"),
    ("missile_launch", 0.59, 14026, "Ignition thump followed by fluttering rocket exhaust"),
    ("impact_light", 0.16, 14027, "Short dry material impact"),
    ("impact_heavy", 1.55, 14028, "Explosive pressure wave, low rumble, scattered fragments and outdoor reflections"),
    ("infantry_fall", 0.37, 14029, "Non-vocal ground thud, cloth rustle, and equipment settling"),
    ("vehicle_destroy", 2.1, 14030, "Explosive chassis breakup with irregular metal debris"),
    ("structure_destroy", 2.65, 14031, "Rolling structural collapse with masonry cracks and grit"),
]


def write_wav(path: Path, samples: np.ndarray) -> None:
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(samples.tobytes())


def db(value: float) -> float:
    return round(20 * math.log10(max(value, 1e-12)), 3)


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    segments = [np.zeros(RATE, dtype="<i2")]
    entries = []
    reel_position = RATE
    variants = [(name, name, duration, seed, description) for name, duration, seed, description in SPECS]
    variants += [(f"{name}_{variant}", name, duration, seed + variant * 7919, description)
                 for name, duration, seed, description in SPECS for variant in (2, 3)]
    for name, kind, duration, seed, description in variants:
        pcm = synthesize(kind, duration, seed)
        path = DEST / (name + ".wav")
        write_wav(path, pcm)
        floating = pcm.astype(np.float64) / 32768
        peak = float(np.max(np.abs(floating)))
        rms = float(np.sqrt(np.mean(floating * floating)))
        assert 0.01 < rms and peak <= 10 ** (-3 / 20), (name, rms, peak)
        assert pcm[0] == 0 and pcm[-1] == 0, name
        assert np.isfinite(floating).all(), name
        entry = {
            "name": name, "path": str(path.relative_to(ROOT)), "description": description,
            "seed": seed, "duration_seconds": len(pcm) / RATE, "sample_rate": RATE,
            "channels": 1, "bits_per_sample": 16, "peak_dbfs": db(peak),
            "rms_dbfs": db(rms), "dc_offset": round(float(floating.mean()), 8),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "audition_start_seconds": reel_position / RATE,
            "audition_end_seconds": (reel_position + len(pcm)) / RATE,
        }
        entries.append(entry)
        segments += [pcm, np.zeros(round(RATE * 0.8), dtype="<i2")]
        reel_position += len(pcm) + round(RATE * 0.8)
    reel_path = HERE / "combat-audition.wav"
    write_wav(reel_path, np.concatenate(segments))
    manifest = {
        "generator": "art/audio/build_combat_audio.py", "provenance": "Original mathematical synthesis; no source recordings or third-party samples.",
        "format": "48 kHz mono signed PCM16 little-endian WAV", "peak_ceiling_dbfs": -3.0,
        "audition_path": str(reel_path.relative_to(ROOT)),
        "audition_sha256": hashlib.sha256(reel_path.read_bytes()).hexdigest(),
        "audition_duration_seconds": reel_position / RATE,
        "assets": entries,
    }
    (HERE / "combat-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    for entry in entries:
        print(f"{entry['name']:20} {entry['duration_seconds']:5.2f}s  peak {entry['peak_dbfs']:6.2f} dBFS  RMS {entry['rms_dbfs']:6.2f} dBFS")
    print(f"Wrote {len(entries)} cues and {manifest['audition_duration_seconds']:.2f}s audition reel.")


if __name__ == "__main__":
    main()
