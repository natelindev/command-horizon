#!/usr/bin/env python3
"""Original, reproducible environment soundscapes. Python + NumPy only.

Periodic noise and integer-cycle modulation produce seamless loops without a
crossfade dip. No recordings, external samples, network services or game RNG.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import wave

import numpy as np

RATE = 32000
ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/audio/environment"
HERE = Path(__file__).resolve().parent


def band(count, rng, low, high):
    frequencies = np.fft.rfftfreq(count, 1 / RATE)
    spectrum = np.fft.rfft(rng.standard_normal(count))
    spectrum *= (1 - np.exp(-(frequencies / low) ** 4)) * np.exp(-(frequencies / high) ** 4)
    samples = np.fft.irfft(spectrum, n=count)
    return samples / np.sqrt(np.mean(samples * samples))


def sine(t, cycles, length, phase=0):
    return np.sin(2 * np.pi * cycles * t / length + phase)


def gust(t, length, phase):
    return .50 + .22 * sine(t, 2, length, phase) + .15 * sine(t, 5, length, phase + .9)


def synthesize(name, seconds, seed, channels):
    count = round(seconds * RATE)
    t = np.arange(count) / RATE
    result = []
    for side in range(channels):
        rng = np.random.default_rng(seed + side * 101)
        swell = gust(t, seconds, side * .7)
        air = band(count, rng, 90, 1200)
        if name == "desert":
            # Open dry wind, rising sand hiss, occasional granular skitter.
            out = .7 * air * swell
            out += .045 * band(count, rng, 1300, 6200) * swell ** 2
            grit = np.maximum(sine(t, 11, seconds, side + .4) - .86, 0) ** 2
            out += .8 * band(count, rng, 2500, 8500) * grit
        elif name == "alpine":
            # Lower valley gusts, breathy conifer needles and a thin ridge whistle.
            out = .65 * band(count, rng, 45, 700) * swell
            out += .07 * band(count, rng, 650, 3800) * (.2 + swell ** 2)
            whistle = sine(t, round(430 * seconds), seconds, .18 * sine(t, 3, seconds))
            out += .025 * whistle * np.maximum(sine(t, 3, seconds, side) - .15, 0) ** 3
        elif name == "industrial":
            # Ventilation, distant fan bearings and a soft mechanical beat.
            out = .08 * air * (.65 + swell * .35)
            for hz, level in [(57, .11), (114, .045), (173, .022), (287, .012)]:
                out += level * sine(t, round(hz * seconds), seconds, side * .2)
            out += .12 * band(count, rng, 170, 520) * (.5 + .5 * sine(t, 73, seconds))
            out += .01 * band(count, rng, 2000, 4200) * np.maximum(sine(t, 4, seconds) - .6, 0)
        elif name == "coastal":
            # Staggered wave sets: low wash followed by bright receding foam.
            waves = (.5 + .5 * sine(t, 5, seconds, side * .75)) ** 2
            foam = (.5 + .5 * sine(t, 5, seconds, side * .75 - 1.0)) ** 3
            out = .19 * air * swell
            out += .62 * band(count, rng, 65, 1200) * (.2 + waves)
            out += .05 * band(count, rng, 1100, 6800) * foam
        elif name == "traffic":
            # Quiet electric service cart: tire hiss, drive harmonics and motor flutter.
            out = .35 * band(count, rng, 180, 2500)
            out += .16 * sine(t, round(94 * seconds), seconds)
            out += .055 * sine(t, round(376 * seconds), seconds)
            out *= .82 + .18 * sine(t, 39, seconds)
        elif name == "tug":
            # Low diesel pulse and water against the hull, without a warning-like horn.
            pulse = .65 + .35 * sine(t, round(13 * seconds), seconds)
            out = .4 * band(count, rng, 40, 450) * pulse
            out += .11 * sine(t, round(63 * seconds), seconds)
            out += .16 * band(count, rng, 400, 2700) * swell
        elif name == "gull":
            # Sparse, short pitched calls; the remaining loop is silent.
            out = np.zeros(count)
            for start, length, base in [(1.2, .62, 1170), (2.05, .48, 1310), (12.1, .72, 1090)]:
                local = np.arange(round(length * RATE)) / RATE
                envelope = np.sin(np.pi * local / length) ** 2
                frequency = base + 240 * np.sin(np.pi * local / length) - 180 * local / length
                phase = 2 * np.pi * np.cumsum(frequency) / RATE
                call = np.sin(phase) + .28 * np.sin(2 * phase) + .08 * np.sin(3 * phase)
                call *= envelope * (.8 + .2 * np.sin(local * 2 * np.pi * 37))
                offset = round(start * RATE)
                out[offset:offset + len(call)] += call
        else:
            raise ValueError(name)
        result.append(out)
    samples = np.stack(result, axis=1)
    samples -= samples.mean(axis=0)
    # Leave headroom for spatial layers and speech; normalize beds by RMS, calls by peak.
    rms = np.sqrt(np.mean(samples * samples))
    target_db = -24 if name in {'desert', 'alpine', 'industrial', 'coastal'} else -20
    samples *= min(10 ** (target_db / 20) / rms, 10 ** (-7 / 20) / np.max(np.abs(samples)))
    return np.rint(samples * 32767).astype("<i2")


SPECS = [
    ("desert", 29, 8401, 2, "Dry wind, sand hiss and granular skitter"),
    ("alpine", 31, 8402, 2, "Valley gusts, conifer rustle and ridge whistle"),
    ("industrial", 27, 8403, 2, "Distant ventilation, fan bearings and machinery"),
    ("coastal", 37, 8404, 2, "Staggered wave sets, receding foam and sea wind"),
    ("traffic", 7, 8405, 1, "Neutral electric cart motor and tire noise"),
    ("tug", 11, 8406, 1, "Neutral harbor tug diesel pulse and hull wash"),
    ("gull", 23, 8407, 1, "Sparse neutral gull calls"),
]


def write_wav(path, samples):
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(samples.shape[1])
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(samples.tobytes())


def db(value):
    return round(20 * math.log10(max(float(value), 1e-12)), 3)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    entries, segments = [], []
    for name, seconds, seed, channels, description in SPECS:
        pcm = synthesize(name, seconds, seed, channels)
        path = DEST / f"{name}.wav"
        write_wav(path, pcm)
        x = pcm.astype(np.float64) / 32768
        jumps = np.abs(np.diff(x, axis=0))
        seam = float(np.max(np.abs(x[0] - x[-1])))
        assert np.isfinite(x).all() and np.max(np.abs(x)) < .45
        # A join may have a normal waveform derivative, never a discontinuity spike.
        assert seam <= float(np.quantile(jumps, .9999)) + 2 / 32768, (name, seam)
        assert np.max(np.abs(x.mean(axis=0))) < 1e-5
        stereo = pcm if channels == 2 else np.repeat(pcm, 2, axis=1)
        preview = stereo[:RATE * 6].astype(np.float64)
        ramp = np.sin(np.linspace(0, np.pi / 2, RATE // 4)) ** 2
        preview[:len(ramp)] *= ramp[:, None]
        preview[-len(ramp):] *= ramp[::-1, None]
        segments += [preview.astype("<i2"), np.zeros((RATE // 2, 2), dtype="<i2")]
        entries.append({"name": name, "description": description, "path": str(path.relative_to(ROOT)),
                        "seconds": seconds, "channels": channels, "sample_rate": RATE, "seed": seed,
                        "peak_dbfs": db(np.max(np.abs(x))), "rms_dbfs": db(np.sqrt(np.mean(x*x))),
                        "seam_step": seam, "max_sample_step": float(jumps.max()),
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        print(name, entries[-1]["peak_dbfs"], entries[-1]["rms_dbfs"])
    audition = np.concatenate(segments)
    write_wav(HERE / "environment-audition.wav", audition)
    # A finite settings sample previews the four regional beds in 12 seconds.
    sample_parts = []
    for index in range(4):
        part = segments[index * 2][:3 * RATE].astype(np.float64)
        ramp = np.linspace(0, 1, RATE // 5)
        part[:len(ramp)] *= ramp[:, None]
        part[-len(ramp):] *= ramp[::-1, None]
        sample_parts.append(part.astype("<i2"))
    write_wav(DEST / "sample.wav", np.concatenate(sample_parts))
    manifest = {"provenance": "Original mathematical synthesis; no source recordings or third-party samples.",
                "generator": str(Path(__file__).relative_to(ROOT)), "assets": entries,
                "audition": "art/audio/environment-audition.wav", "audition_seconds": len(audition) / RATE}
    (HERE / "environment-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
