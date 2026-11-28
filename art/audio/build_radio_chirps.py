#!/usr/bin/env python3
"""Synthesize authentic, band-limited tactical VHF/UHF radio PTT key-up and squelch chirps."""
import math
import wave
from pathlib import Path

import numpy as np

RATE = 48000
ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/audio/voices"


def band_limit(sig: np.ndarray, low: float, high: float) -> np.ndarray:
    n = len(sig)
    freqs = np.fft.rfftfreq(n, 1.0 / RATE)
    spec = np.fft.rfft(sig)
    hp = 1.0 - np.exp(-((freqs / max(low, 1.0)) ** 4))
    lp = np.exp(-((freqs / max(high, 20.0)) ** 4))
    return np.fft.irfft(spec * hp * lp, n=n)


def write_wav(path: Path, data: np.ndarray) -> None:
    data = data - data.mean()
    fade_in = round(0.0005 * RATE)
    fade_out = round(0.004 * RATE)
    data[:fade_in] *= np.sin(np.linspace(0, math.pi / 2, fade_in)) ** 2
    data[-fade_out:] *= np.cos(np.linspace(0, math.pi / 2, fade_out)) ** 2
    int_data = np.rint(np.clip(data, -0.95, 0.95) * 32767).astype("<i2")
    int_data[0] = 0
    int_data[-1] = 0
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(int_data.tobytes())


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)

    # radio_chirp_in: ~28ms authentic tactical PTT mic switch + soft warm carrier lock.
    # Band-limited to handset voice range (450-3200 Hz) so it never pierces or buzzes.
    t_in = np.arange(round(0.028 * RATE), dtype=np.float64) / RATE
    rng_in = np.random.default_rng(42)
    # Soft mechanical PTT button actuation click
    switch_click = (
        band_limit(rng_in.standard_normal(len(t_in)), 750.0, 3100.0)
        * (1.0 - np.exp(-t_in / 0.0003))
        * np.exp(-t_in / 0.0028)
    )
    # Warm damped carrier-lock thump (no high-pitched mosquito beep)
    carrier_phase = 2.0 * np.pi * (620.0 * t_in + 360.0 * 0.005 * (1.0 - np.exp(-t_in / 0.005)))
    carrier = (
        0.55 * np.sin(carrier_phase)
        + 0.25 * np.sin(carrier_phase * 1.5 + 0.4)
    ) * (1.0 - np.exp(-t_in / 0.0012)) * np.exp(-t_in / 0.0065)
    # Brief band-limited analog breath
    breath = (
        band_limit(rng_in.standard_normal(len(t_in)), 550.0, 2900.0)
        * (1.0 - np.exp(-t_in / 0.002))
        * np.exp(-t_in / 0.009)
    )
    click_in = band_limit(0.65 * switch_click + 0.55 * carrier + 0.28 * breath, 420.0, 3300.0)
    click_in = np.tanh(click_in * 1.4)
    click_in = click_in / max(float(np.max(np.abs(click_in))), 1e-8) * 0.18  # -14.9 dBFS
    write_wav(DEST / "radio_chirp_in.wav", click_in)

    # radio_chirp_out: ~34ms soft band-limited analog squelch tail + muted relay drop.
    t_out = np.arange(round(0.034 * RATE), dtype=np.float64) / RATE
    rng_out = np.random.default_rng(84)
    squelch = (
        band_limit(rng_out.standard_normal(len(t_out)), 620.0, 2850.0)
        * (1.0 - np.exp(-t_out / 0.0025))
        * np.exp(-t_out / 0.010)
    )
    # Muted downward carrier-drop detent
    drop_phase = 2.0 * np.pi * (520.0 * t_out + 280.0 * 0.006 * (1.0 - np.exp(-t_out / 0.006)))
    drop = np.sin(drop_phase) * (1.0 - np.exp(-t_out / 0.0008)) * np.exp(-t_out / 0.0055)
    click_out = band_limit(0.62 * squelch + 0.42 * drop, 450.0, 3000.0)
    click_out = np.tanh(click_out * 1.2)
    click_out = click_out / max(float(np.max(np.abs(click_out))), 1e-8) * 0.16  # -15.9 dBFS
    write_wav(DEST / "radio_chirp_out.wav", click_out)

    print("Wrote refined radio_chirp_in.wav and radio_chirp_out.wav to", DEST)


if __name__ == "__main__":
    main()
