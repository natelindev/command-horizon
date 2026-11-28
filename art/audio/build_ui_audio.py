#!/usr/bin/env python3
"""Render tactile, studio-grade 48 kHz UI console audio cues into assets/audio/ui/.

Designs restrained, tactile hardware micro-switches, damped anodized chassis
resonances, and warm filtered harmonic chimes with subtle studio room air —
eliminating bare sine beeps and harsh keypad tones.
"""

from __future__ import annotations

import math
from pathlib import Path
import wave

import numpy as np

RATE = 48000
PEAK = 10.0 ** (-4.5 / 20.0)
ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/audio/ui"


def _clock(seconds: float) -> np.ndarray:
    return np.arange(round(seconds * RATE), dtype=np.float64) / RATE


def _band_noise(n: int, seed: int, low: float, high: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    freqs = np.fft.rfftfreq(n, 1.0 / RATE)
    spec = np.fft.rfft(rng.standard_normal(n))
    pink = 1.0 / np.maximum(freqs, 30.0) ** 0.5
    pink[0] = 0.0
    hp = 1.0 - np.exp(-((freqs / max(low, 1.0)) ** 4))
    lp = np.exp(-((freqs / max(high, 20.0)) ** 4))
    sig = np.fft.irfft(spec * pink * hp * lp, n=n)
    return sig / max(float(np.sqrt(np.mean(sig * sig))), 1e-8)


def _env(t: np.ndarray, decay: float, attack: float = 0.0005) -> np.ndarray:
    return (1.0 - np.exp(-t / max(attack, 1e-5))) * np.exp(-t / max(decay, 1e-5))


def _add(target: np.ndarray, sig: np.ndarray, delay_s: float, gain: float = 1.0) -> None:
    offset = round(delay_s * RATE)
    count = min(len(sig), len(target) - offset)
    if count > 0:
        target[offset : offset + count] += sig[:count] * gain


def _modal(t: np.ndarray, modes: list[tuple[float, float, float]], attack: float = 0.0006) -> np.ndarray:
    out = np.zeros_like(t)
    for idx, (freq, amp, decay) in enumerate(modes):
        out += amp * np.sin(2.0 * np.pi * freq * t + idx * 0.52) * _env(t, decay, attack)
    return out


def _warm_chime(t: np.ndarray, freq: float, decay: float, attack: float = 0.003) -> np.ndarray:
    """Muted, silky glass/marimba-like harmonic tone with gentle upper-partial rolloff."""
    # Soft pitch settle on attack gives organic instrument warmth instead of sterile sine
    phase = 2.0 * np.pi * (freq * t + (freq * 0.012) * 0.006 * (1.0 - np.exp(-t / 0.006)))
    return (
        0.62 * np.sin(phase) * _env(t, decay, attack)
        + 0.24 * np.sin(phase * 2.0 + 0.4) * _env(t, decay * 0.52, attack)
        + 0.09 * np.sin(phase * 3.0 + 1.1) * _env(t, decay * 0.28, attack * 0.8)
    )


def _studio_room(dry: np.ndarray, seed: int, wet: float = 0.14, decay: float = 0.055) -> np.ndarray:
    """Ultra-subtle damped console studio air so UI sounds feel physical, not dry/clinical."""
    n = len(dry)
    ir_len = min(n, round(max(decay * 4.5, 0.06) * RATE))
    t_ir = np.arange(ir_len, dtype=np.float64) / RATE
    rng = np.random.default_rng(seed)
    freqs = np.fft.rfftfreq(ir_len, 1.0 / RATE)
    spec = np.fft.rfft(rng.standard_normal(ir_len))
    lp = np.exp(-((freqs / 2600.0) ** 3))
    hp = 1.0 - np.exp(-((freqs / 240.0) ** 3))
    ir = np.fft.irfft(spec * lp * hp, n=ir_len) * np.exp(-t_ir / decay)
    pre = min(ir_len - 1, round(0.004 * RATE))
    ir[:pre] = 0.0
    norm = float(np.sqrt(np.sum(ir * ir)))
    if norm > 1e-9:
        ir /= norm
    fft_n = 1 << (n + ir_len - 1).bit_length()
    conv = np.fft.irfft(np.fft.rfft(dry, n=fft_n) * np.fft.rfft(ir, n=fft_n), n=fft_n)[:n]
    return dry + conv * wet


def _finish(samples: np.ndarray) -> np.ndarray:
    samples = samples - samples.mean()
    samples = np.tanh(samples * 0.85)
    samples = samples - samples.mean()
    fade_in = round(0.0003 * RATE)
    fade_out = round(0.010 * RATE)
    samples[:fade_in] *= np.sin(np.linspace(0, math.pi / 2, fade_in)) ** 2
    samples[-fade_out:] *= np.cos(np.linspace(0, math.pi / 2, fade_out)) ** 2
    samples *= PEAK / max(float(np.max(np.abs(samples))), 1e-8)
    pcm = np.rint(samples * 32767).astype("<i2")
    pcm[0] = 0
    pcm[-1] = 0
    return pcm


def synthesize_ui(kind: str) -> np.ndarray:
    if kind == "click":
        # Precision machined micro-switch: ultra-crisp 1.8ms snap + warm damped aluminum body.
        t = _clock(0.052)
        snap = _band_noise(len(t), 3101, 2400, 10500) * _env(t, 0.0020, 0.00010)
        thump = _modal(t, [(195.0, 0.60, 0.0085), (560.0, 0.28, 0.0055), (1640.0, 0.14, 0.0032)], 0.00025)
        out = 0.52 * snap + 0.78 * thump
        out = _studio_room(out, 4101, wet=0.09, decay=0.025)
        return _finish(out)

    if kind == "select":
        # Restrained tactile switch detent flowing into a silky, low-profile warm fifth lock-in.
        t = _clock(0.110)
        detent = (
            0.44 * _band_noise(len(t), 3102, 2000, 9200) * _env(t, 0.0022, 0.00012)
            + 0.52 * _modal(t, [(220.0, 0.58, 0.008), (740.0, 0.24, 0.0055)], 0.00025)
        )
        # Warm muted D4 + A4 harmonic glow (never shrill or toy-like)
        tone = 0.55 * _warm_chime(t, 392.0, 0.030, 0.002) + 0.42 * _warm_chime(t, 587.33, 0.026, 0.003)
        out = detent.copy()
        _add(out, tone, 0.007, 0.72)
        out = _studio_room(out, 4102, wet=0.14, decay=0.042)
        return _finish(out)

    if kind == "adjust":
        # Weighted anodized rotary encoder tick: compact, silky, zero harshness.
        t = _clock(0.046)
        tick = _band_noise(len(t), 3103, 1500, 7200) * _env(t, 0.0021, 0.00012)
        body = _modal(t, [(172.0, 0.64, 0.009), (470.0, 0.30, 0.0055), (1280.0, 0.12, 0.003)], 0.00025)
        out = 0.44 * tick + 0.80 * body
        out = _studio_room(out, 4103, wet=0.08, decay=0.020)
        return _finish(out)

    if kind == "confirm":
        # Authoritative, warm military-sci-fi lock-in: damped mechanical latch + velvety fifth bloom.
        t = _clock(0.195)
        latch = (
            0.42 * _band_noise(len(t), 3104, 1700, 9200) * _env(t, 0.0028, 0.00012)
            + 0.58 * _modal(t, [(180.0, 0.66, 0.013), (520.0, 0.28, 0.009)], 0.0003)
        )
        # Restrained warm chord: D4 -> A4+E5 (softened attack, zero phone-keypad pierce)
        note1 = _warm_chime(t, 293.66, 0.048, 0.0035) + 0.38 * _warm_chime(t, 440.0, 0.040, 0.004)
        note2 = (
            0.62 * _warm_chime(t, 440.0, 0.072, 0.004)
            + 0.48 * _warm_chime(t, 659.25, 0.064, 0.005)
            + 0.18 * _warm_chime(t, 880.0, 0.042, 0.006)
        )
        out = latch.copy()
        _add(out, note1, 0.005, 0.62)
        _add(out, note2, 0.036, 0.78)
        out = _studio_room(out, 4104, wet=0.18, decay=0.065)
        return _finish(out)

    raise ValueError(kind)


def write_wav(path: Path, samples: np.ndarray) -> None:
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(samples.tobytes())


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    for kind in ("click", "select", "adjust", "confirm"):
        pcm = synthesize_ui(kind)
        out_path = DEST / f"{kind}.wav"
        write_wav(out_path, pcm)
        floating = pcm.astype(np.float64) / 32768.0
        rms = float(np.sqrt(np.mean(floating * floating)))
        peak = float(np.max(np.abs(floating)))
        print(f"ui/{kind:8} {len(pcm) / RATE:5.3f}s  peak {20*math.log10(peak):6.2f} dBFS  RMS {20*math.log10(rms):6.2f} dBFS")


if __name__ == "__main__":
    main()
