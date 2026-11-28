#!/usr/bin/env python3
"""Render lush, seamless 48 kHz stereo ambience for the three campaign command hub interiors."""
from __future__ import annotations

import math
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/audio/environment"
RATE = 48000
SECONDS = 16


def periodic_pink(count: int, rng: np.random.Generator, low: float, high: float) -> np.ndarray:
    """Strictly periodic 1/f-weighted noise with zero loop seam."""
    freqs = np.fft.rfftfreq(count, 1.0 / RATE)
    spec = np.fft.rfft(rng.standard_normal(count))
    pink = 1.0 / np.maximum(freqs, 18.0) ** 0.58
    pink[0] = 0.0
    hp = 1.0 - np.exp(-((freqs / max(low, 1.0)) ** 4))
    lp = np.exp(-((freqs / max(high, 30.0)) ** 4))
    sig = np.fft.irfft(spec * pink * hp * lp, n=count)
    return sig / max(float(np.sqrt(np.mean(sig * sig))), 1e-8)


def cyc(t: np.ndarray, cycles: int, phase: float = 0.0) -> np.ndarray:
    """Integer-cycle sinusoid over SECONDS so loop endpoints match perfectly."""
    return np.sin(2.0 * np.pi * cycles * t / SECONDS + phase)


def add_wrap(buf: np.ndarray, event: np.ndarray, start_s: float, gain_l: float, gain_r: float) -> None:
    """Wrap-around additive placement into a stereo seamless loop buffer."""
    n = len(buf)
    offset = round(start_s * RATE) % n
    m = len(event)
    idx = (offset + np.arange(m)) % n
    buf[idx, 0] += event * gain_l
    buf[idx, 1] += event * gain_r


def save(name: str, stereo: np.ndarray, target_rms_db: float = -21.0) -> None:
    stereo = stereo - stereo.mean(axis=0)
    rms = float(np.sqrt(np.mean(stereo * stereo)))
    peak = float(np.max(np.abs(stereo)))
    gain = min(10.0 ** (target_rms_db / 20.0) / max(rms, 1e-9), 0.55 / max(peak, 1e-9))
    stereo = np.tanh(stereo * gain * 1.05) / 1.05
    stereo = stereo - stereo.mean(axis=0)
    data = np.rint(np.clip(stereo, -0.95, 0.95) * 32767).astype("<i2")
    path = DEST / f"{name}.wav"
    with wave.open(str(path), "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())
    rms_out = 20 * math.log10(max(float(np.sqrt(np.mean((data / 32768.0) ** 2))), 1e-9))
    peak_out = 20 * math.log10(max(float(np.max(np.abs(data / 32768.0))), 1e-9))
    print(f"hub/{name:18} {SECONDS:2d}s  peak {peak_out:6.2f} dBFS  RMS {rms_out:6.2f} dBFS")


def build_war_train() -> np.ndarray:
    """Bastion armored war-train interior: deep diesel-electric rumble, muffled steel bogie track joints, desert air."""
    count = RATE * SECONDS
    t = np.arange(count, dtype=np.float64) / RATE
    rng = np.random.default_rng(410811)
    stereo = np.zeros((count, 2), dtype=np.float64)

    for ch in range(2):
        # Warm armored hull diesel-electric rumble (strictly low-mid, zero harsh buzz)
        sway = 0.84 + 0.09 * cyc(t, 2, ch * 0.8) + 0.07 * cyc(t, 5, ch * 1.4 + 0.6)
        rumble = periodic_pink(count, rng, 28.0, 145.0) * sway
        # Subtle muted exterior desert slipstream rushing past thick steel plates
        air = periodic_pink(count, rng, 150.0, 820.0) * (0.72 + 0.18 * cyc(t, 3, ch * 1.1) + 0.10 * cyc(t, 7, ch * 0.5))
        # Distant warm generator harmonic (soft, low, deeply blended)
        gen = (
            0.14 * cyc(t, round(48 * SECONDS), ch * 0.3)
            + 0.06 * cyc(t, round(96 * SECONDS), ch * 0.7)
        ) * (0.85 + 0.15 * cyc(t, 11, ch * 0.4))
        stereo[:, ch] = 0.74 * rumble + 0.24 * air + gen

    # Heavy muffled steel bogies crossing rail joints: authentic double-tap "da-dum ... da-dum"
    # Lowpass-filtered below 260 Hz so it feels like 200 tons of armor rolling over track, never a woodblock!
    joint_n = round(0.32 * RATE)
    tj = np.arange(joint_n, dtype=np.float64) / RATE
    num_joints = 10  # Every 1.6 seconds
    for k in range(num_joints):
        base_s = k * (SECONDS / num_joints)
        # Front axle + rear axle double-tap (0.0s and 0.19s)
        for sub_off, amp in [(0.0, 1.0), (0.195, 0.82)]:
            thump_noise = periodic_pink(joint_n, rng, 34.0, 230.0)
            thump_env = (1.0 - np.exp(-tj / 0.006)) * np.exp(-tj / 0.048)
            thump_sub = np.sin(2.0 * np.pi * (56.0 * np.exp(-tj / 0.05) + 32.0) * tj) * np.exp(-tj / 0.055)
            # Subtle dull steel rail clunk (heavily damped, low-mid)
            clunk = periodic_pink(joint_n, rng, 180.0, 560.0) * (1.0 - np.exp(-tj / 0.003)) * np.exp(-tj / 0.022)
            event = (0.58 * thump_noise * thump_env + 0.42 * thump_sub + 0.14 * clunk) * amp * 0.44
            pan = rng.uniform(-0.18, 0.18)
            add_wrap(stereo, event, base_s + sub_off + rng.uniform(-0.008, 0.008), 1.0 - pan * 0.4, 1.0 + pan * 0.4)

    return stereo


def build_nexus_core() -> np.ndarray:
    """Helix harmonic spire interior: lush breathing crystalline energy chamber & clean-room air."""
    count = RATE * SECONDS
    t = np.arange(count, dtype=np.float64) / RATE
    rng = np.random.default_rng(410812)
    stereo = np.zeros((count, 2), dtype=np.float64)

    # D-minor9 / open fifth harmonic glass pad (55/110/165/220/330/495 Hz) — slow breathing stereo wash
    for ch in range(2):
        # Quiet clean-room ventilation air
        air = periodic_pink(count, rng, 110.0, 1100.0) * (0.76 + 0.14 * cyc(t, 2, ch * 1.3) + 0.10 * cyc(t, 3, ch * 0.5))
        # Warm sub-harmonic core anchor (deep & velvety)
        sub_breath = 0.72 + 0.18 * cyc(t, 1, ch * 0.6) + 0.10 * cyc(t, 3, ch * 1.7)
        sub = (
            0.34 * cyc(t, round(55 * SECONDS), ch * 0.25)
            + 0.20 * cyc(t, round(110 * SECONDS), ch * 0.5 + 0.3)
        ) * sub_breath
        # Evolving crystalline harmonic fifths & ninths with gentle stereo phase drift
        pad = np.zeros(count, dtype=np.float64)
        for hz, amp, rate_cyc, ph in [
            (165.0, 0.13, 2, 0.2),
            (220.0, 0.11, 3, 1.1),
            (330.0, 0.065, 4, 2.3),
            (495.0, 0.032, 5, 0.8),
            (660.0, 0.016, 3, 2.9),
        ]:
            # Subtle pitch chorus via tiny periodic phase modulation
            drift = 0.28 * cyc(t, rate_cyc, ph + ch * 1.4)
            swell = 0.45 + 0.35 * cyc(t, rate_cyc, ph + ch * 1.1) + 0.20 * cyc(t, 1, ph * 0.7)
            pad += amp * np.sin(2.0 * np.pi * round(hz * SECONDS) * t / SECONDS + drift) * swell
        # Silky filtered harmonic shimmer bed
        shimmer = periodic_pink(count, rng, 900.0, 2600.0) * (0.04 + 0.03 * cyc(t, 2, ch * 1.8))
        stereo[:, ch] = 0.42 * air + sub + pad + shimmer

    return stereo


def build_outpost_campfire() -> np.ndarray:
    """Frontier desert outpost campfire: warm undulating flame roar, organic wood crackles, night wind."""
    count = RATE * SECONDS
    t = np.arange(count, dtype=np.float64) / RATE
    rng = np.random.default_rng(410813)
    stereo = np.zeros((count, 2), dtype=np.float64)

    for ch in range(2):
        # Gentle open desert night breeze
        breeze = periodic_pink(count, rng, 75.0, 720.0) * (
            0.55 + 0.22 * cyc(t, 2, ch * 0.9) + 0.15 * cyc(t, 5, ch * 1.7) + 0.08 * cyc(t, 7, ch * 0.4)
        )
        # Warm undulating campfire flame body (low-mid flutter, cozy & organic)
        flame_mod = (
            0.60
            + 0.16 * cyc(t, 9, ch * 0.7)
            + 0.14 * cyc(t, 17, ch * 1.3 + 0.4)
            + 0.10 * cyc(t, 29, ch * 2.1)
        )
        flame = periodic_pink(count, rng, 48.0, 290.0) * flame_mod
        # Soft gentle coal-bed warmth
        coals = periodic_pink(count, rng, 280.0, 1200.0) * (0.45 + 0.25 * cyc(t, 13, ch * 1.1))
        stereo[:, ch] = 0.36 * breeze + 0.68 * flame + 0.18 * coals

    # Organic wood-ember snaps & warm crackles (band-limited wooden pops, varied size & stereo width)
    pop_n = round(0.045 * RATE)
    tp = np.arange(pop_n, dtype=np.float64) / RATE
    for _ in range(92):
        start_s = float(rng.uniform(0.0, SECONDS))
        # Vary between tiny ember ticks and occasional warm dry-twig snaps
        big = rng.random() < 0.18
        low_hz = float(rng.uniform(600.0, 1200.0) if big else rng.uniform(1100.0, 2100.0))
        high_hz = float(rng.uniform(2600.0, 4200.0) if big else rng.uniform(3200.0, 5400.0))
        decay = float(rng.uniform(0.0045, 0.0095) if big else rng.uniform(0.0018, 0.0045))
        grain = periodic_pink(pop_n, rng, low_hz, high_hz)
        # Add subtle wooden resonant pop mode
        wood_f = float(rng.uniform(850.0, 2400.0))
        pop = (0.72 * grain + 0.28 * np.sin(2.0 * np.pi * wood_f * tp)) * (1.0 - np.exp(-tp / 0.00025)) * np.exp(-tp / decay)
        amp = float(rng.uniform(0.18, 0.40) if big else rng.uniform(0.06, 0.18))
        pan = float(rng.uniform(-0.55, 0.55))
        add_wrap(stereo, pop * amp, start_s, math.sqrt((1.0 - pan) * 0.5), math.sqrt((1.0 + pan) * 0.5))

    return stereo


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    save("war-train", build_war_train(), target_rms_db=-21.0)
    save("nexus-core", build_nexus_core(), target_rms_db=-21.5)
    save("outpost-campfire", build_outpost_campfire(), target_rms_db=-21.0)


if __name__ == "__main__":
    main()
