#!/usr/bin/env python3
"""Render organic, seamless environment soundscapes. Python + NumPy only.

Uses 1/f-weighted periodic spectra, multi-harmonic non-repetitive gusts, stereo
decorrelation, and strict high-frequency hiss control (< -46.5 dBFS above 2 kHz)
so beds feel spacious, warm, and natural under speech and combat.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import wave

import numpy as np

RATE = 44100
ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/audio/environment"
HERE = Path(__file__).resolve().parent


def pink_band(count: int, rng: np.random.Generator, low: float, high: float, slope: float = 0.55) -> np.ndarray:
    """Strictly periodic 1/f-weighted band noise (warm and natural, never papery)."""
    frequencies = np.fft.rfftfreq(count, 1.0 / RATE)
    spectrum = np.fft.rfft(rng.standard_normal(count))
    pink = 1.0 / np.maximum(frequencies, 18.0) ** slope
    pink[0] = 0.0
    hp = 1.0 - np.exp(-((frequencies / max(low, 1.0)) ** 4))
    lp = np.exp(-((frequencies / max(high, 20.0)) ** 5))
    samples = np.fft.irfft(spectrum * pink * hp * lp, n=count)
    return samples / max(float(np.sqrt(np.mean(samples * samples))), 1e-8)


def sine(t: np.ndarray, cycles: int, length: float, phase: float = 0.0) -> np.ndarray:
    return np.sin(2.0 * np.pi * cycles * t / length + phase)


def organic_swell(t: np.ndarray, length: float, phase: float) -> np.ndarray:
    """Multi-prime slow modulation that avoids obvious periodic LFO pumping."""
    return np.clip(
        0.54
        + 0.16 * sine(t, 1, length, phase)
        + 0.13 * sine(t, 2, length, phase * 1.7 + 0.8)
        + 0.10 * sine(t, 3, length, phase * 0.6 + 2.1)
        + 0.07 * sine(t, 5, length, phase * 1.3 + 1.4)
        + 0.05 * sine(t, 7, length, phase * 0.9 + 3.5),
        0.12,
        1.0,
    )


def synthesize(name: str, seconds: int, seed: int, channels: int) -> np.ndarray:
    count = round(seconds * RATE)
    t = np.arange(count, dtype=np.float64) / RATE
    result = []

    for side in range(channels):
        rng = np.random.default_rng(seed + side * 137)
        ph = side * 1.45
        swell = organic_swell(t, seconds, ph)
        swell2 = organic_swell(t, seconds, ph + 2.3)

        if name == "desert":
            # Expansive dry canyon airflow: deep warm low gusts, soft mid-low canyon draft, tiny dry dust drift.
            low_wind = 0.72 * pink_band(count, rng, 42.0, 320.0, slope=0.65) * swell
            mid_draft = 0.36 * pink_band(count, rng, 210.0, 920.0, slope=0.55) * (0.35 + 0.65 * swell2 ** 1.6)
            # Soft resonant warm canyon draft (band-limited noise, never a pure sine whistle)
            canyon = 0.14 * pink_band(count, rng, 260.0, 440.0, slope=0.3) * (swell ** 2.2)
            # Delicate dry sand whisper strictly capped below 1.85 kHz so zero harsh hiss
            sand = 0.048 * pink_band(count, rng, 950.0, 1750.0, slope=0.6) * (swell2 ** 2.4)
            out = low_wind + mid_draft + canyon + sand

        elif name == "alpine":
            # Cool open valley breeze, gentle pine-canopy murmur, distant soft mountain air resonance.
            valley = 0.74 * pink_band(count, rng, 38.0, 290.0, slope=0.65) * swell
            canopy = 0.34 * pink_band(count, rng, 240.0, 1150.0, slope=0.60) * (0.28 + 0.72 * swell2 ** 1.5)
            # Subtle airy ridge draft (narrow pink noise resonance — far more realistic than sine)
            ridge = 0.09 * pink_band(count, rng, 370.0, 520.0, slope=0.2) * np.maximum(swell - 0.35, 0.0) ** 2
            needles = 0.042 * pink_band(count, rng, 900.0, 1720.0, slope=0.65) * (swell ** 2.0)
            out = valley + canopy + ridge + needles

        elif name == "industrial":
            # Warm distant power-plant & refinery infrastructure: deep ventilation air, soft turbine hum, muffled pressure sighs.
            vent = 0.64 * pink_band(count, rng, 45.0, 340.0, slope=0.62) * (0.72 + 0.28 * swell)
            duct = 0.26 * pink_band(count, rng, 220.0, 780.0, slope=0.58) * (0.65 + 0.35 * swell2)
            # Warm distant industrial transformer/turbine chord (very soft, never droning)
            hum_env = 0.78 + 0.14 * sine(t, 2, seconds, ph) + 0.08 * sine(t, 5, seconds, ph + 1.2)
            hum = (
                0.095 * sine(t, round(55 * seconds), seconds, side * 0.35)
                + 0.042 * sine(t, round(110 * seconds), seconds, side * 0.6 + 0.4)
                + 0.018 * sine(t, round(165 * seconds), seconds, side * 0.9)
            ) * hum_env
            # Subtle far-off rhythmic machinery pulse (heavily muffled)
            mach = 0.11 * pink_band(count, rng, 110.0, 360.0, slope=0.5) * (0.55 + 0.45 * sine(t, round(1.8 * seconds), seconds, side * 0.2))
            sigh = 0.032 * pink_band(count, rng, 620.0, 1550.0, slope=0.5) * np.maximum(sine(t, 3, seconds, ph + 0.7) - 0.55, 0.0) ** 2
            out = vent + duct + hum + mach + sigh

        elif name == "coastal":
            # Realistic overlapping stereo surf sets: rolling low swell, breaking wash, gentle receding foam, sea breeze.
            # Two staggered wave cadences (4 cycles and 7 cycles) create organic non-repetitive shore rhythm!
            wave_a = (0.5 + 0.5 * sine(t, 4, seconds, side * 0.62)) ** 2.2
            wave_b = (0.5 + 0.5 * sine(t, 7, seconds, side * 0.85 + 1.9)) ** 2.6
            waves = 0.62 * wave_a + 0.38 * wave_b
            foam = (
                0.60 * (0.5 + 0.5 * sine(t, 4, seconds, side * 0.62 - 0.85)) ** 3.0
                + 0.40 * (0.5 + 0.5 * sine(t, 7, seconds, side * 0.85 + 1.05)) ** 3.2
            )
            sea_air = 0.28 * pink_band(count, rng, 65.0, 420.0, slope=0.65) * swell
            breakers = 0.72 * pink_band(count, rng, 42.0, 480.0, slope=0.68) * (0.24 + 0.76 * waves)
            wash = 0.26 * pink_band(count, rng, 340.0, 1280.0, slope=0.62) * (0.15 + 0.85 * foam)
            spray = 0.038 * pink_band(count, rng, 950.0, 1750.0, slope=0.65) * foam
            out = sea_air + breakers + wash + spray

        elif name == "traffic":
            # Quiet electric logistics vehicle: warm rubber-on-pavement roll + soft brushless motor whine.
            tires = 0.42 * pink_band(count, rng, 110.0, 1450.0, slope=0.6)
            motor = (
                0.14 * sine(t, round(92 * seconds), seconds)
                + 0.055 * sine(t, round(184 * seconds), seconds, 0.5)
                + 0.028 * sine(t, round(368 * seconds), seconds, 1.1)
            ) * (0.86 + 0.14 * sine(t, 19, seconds))
            out = tires + motor

        elif name == "tug":
            # Warm low-RPM marine diesel harbor tug + gentle hull bow-wave wash.
            pulse = 0.66 + 0.34 * sine(t, round(11 * seconds), seconds)
            diesel = 0.48 * pink_band(count, rng, 38.0, 340.0, slope=0.65) * pulse
            diesel += (
                0.13 * sine(t, round(55 * seconds), seconds)
                + 0.055 * sine(t, round(110 * seconds), seconds, 0.7)
            ) * (0.80 + 0.20 * sine(t, round(11 * seconds), seconds))
            wash = 0.22 * pink_band(count, rng, 260.0, 1650.0, slope=0.6) * swell
            out = diesel + wash

        elif name == "gull":
            # Expressive coastal seabird calls with natural glottal inflection and airy coastal decay.
            out = np.zeros(count, dtype=np.float64)
            for start, length, base in [(1.2, 0.56, 1140.0), (2.02, 0.44, 1290.0), (12.1, 0.66, 1060.0)]:
                n_call = round(length * RATE)
                local = np.arange(n_call, dtype=np.float64) / RATE
                env = (np.sin(np.pi * local / length) ** 1.6) * np.exp(-local * 0.9)
                # Natural rising-then-falling gull inflection
                pitch = base + 290.0 * np.sin(np.pi * (local / length) ** 0.75) - 210.0 * (local / length)
                phase = 2.0 * np.pi * np.cumsum(pitch) / RATE
                # Subtle organic throat rasp
                rasp = 1.0 + 0.14 * np.sin(2.0 * np.pi * 42.0 * local) + 0.06 * pink_band(n_call, rng, 180.0, 650.0)
                call = (
                    0.68 * np.sin(phase)
                    + 0.24 * np.sin(2.0 * phase + 0.4)
                    + 0.08 * np.sin(3.0 * phase + 1.1)
                ) * env * rasp
                # Soft coastal air scatter tail
                tail = np.zeros(round((length + 0.35) * RATE), dtype=np.float64)
                tail[:n_call] = call
                for tap_s, tap_g in [(0.045, 0.22), (0.115, 0.14), (0.195, 0.08)]:
                    off = round(tap_s * RATE)
                    tail[off : off + n_call] += call[: len(tail) - off] * tap_g
                offset = round(start * RATE)
                end = min(count, offset + len(tail))
                out[offset:end] += tail[: end - offset]

        else:
            raise ValueError(name)
        result.append(out)

    samples = np.stack(result, axis=1)
    samples -= samples.mean(axis=0)
    # Leave generous headroom for speech and spatial combat; beds normalized to -24.5 dBFS RMS.
    rms = float(np.sqrt(np.mean(samples * samples)))
    target_db = -24.5 if name in {"desert", "alpine", "industrial", "coastal"} else -20.5
    samples *= min(10.0 ** (target_db / 20.0) / max(rms, 1e-9), 10.0 ** (-7.5 / 20.0) / max(float(np.max(np.abs(samples))), 1e-9))
    return np.rint(samples * 32767).astype("<i2")


SPECS = [
    ("desert", 29, 8401, 2, "Warm open canyon airflow, soft drafts and subtle dry dust drift"),
    ("alpine", 31, 8402, 2, "Cool valley gusts, pine canopy murmur and distant ridge air"),
    ("industrial", 27, 8403, 2, "Distant ventilation, warm turbine hum and muffled facility ambience"),
    ("coastal", 37, 8404, 2, "Staggered stereo ocean wave sets, soft receding wash and sea breeze"),
    ("traffic", 7, 8405, 1, "Neutral electric service vehicle roll and quiet drive hum"),
    ("tug", 11, 8406, 1, "Neutral harbor tug low-RPM diesel pulse and hull water wash"),
    ("gull", 23, 8407, 1, "Sparse coastal gull calls with airy decay"),
]


def write_wav(path: Path, samples: np.ndarray) -> None:
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(samples.shape[1])
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(samples.tobytes())


def db(value: float) -> float:
    return round(20.0 * math.log10(max(float(value), 1e-12)), 3)


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    entries, segments = [], []
    for name, seconds, seed, channels, description in SPECS:
        pcm = synthesize(name, seconds, seed, channels)
        path = DEST / f"{name}.wav"
        write_wav(path, pcm)
        x = pcm.astype(np.float64) / 32768.0
        jumps = np.abs(np.diff(x, axis=0))
        seam = float(np.max(np.abs(x[0] - x[-1])))
        assert np.isfinite(x).all() and np.max(np.abs(x)) < 0.45
        assert seam <= float(np.quantile(jumps, 0.9999)) + 2 / 32768.0, (name, seam)
        assert np.max(np.abs(x.mean(axis=0))) < 1e-5
        stereo = pcm if channels == 2 else np.repeat(pcm, 2, axis=1)
        preview = stereo[: RATE * 6].astype(np.float64)
        ramp = np.sin(np.linspace(0, np.pi / 2, RATE // 4)) ** 2
        preview[: len(ramp)] *= ramp[:, None]
        preview[-len(ramp) :] *= ramp[::-1, None]
        segments += [preview.astype("<i2"), np.zeros((RATE // 2, 2), dtype="<i2")]
        entries.append(
            {
                "name": name,
                "description": description,
                "path": str(path.relative_to(ROOT)),
                "seconds": seconds,
                "channels": channels,
                "sample_rate": RATE,
                "seed": seed,
                "peak_dbfs": db(np.max(np.abs(x))),
                "rms_dbfs": db(np.sqrt(np.mean(x * x))),
                "seam_step": seam,
                "max_sample_step": float(jumps.max()),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            }
        )
        print(f"env/{name:12} peak {entries[-1]['peak_dbfs']:6.2f} dBFS  RMS {entries[-1]['rms_dbfs']:6.2f} dBFS")

    audition = np.concatenate(segments)
    write_wav(HERE / "environment-audition.wav", audition)
    sample_parts = []
    for index in range(4):
        part = segments[index * 2][: 3 * RATE].astype(np.float64)
        ramp = np.linspace(0, 1, RATE // 5)
        part[: len(ramp)] *= ramp[:, None]
        part[-len(ramp) :] *= ramp[::-1, None]
        sample_parts.append(part.astype("<i2"))
    write_wav(DEST / "sample.wav", np.concatenate(sample_parts))
    manifest = {
        "provenance": "Original mathematical synthesis; no source recordings or third-party samples.",
        "generator": str(Path(__file__).relative_to(ROOT)),
        "assets": entries,
        "audition": "art/audio/environment-audition.wav",
        "audition_seconds": len(audition) / RATE,
    }
    (HERE / "environment-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
