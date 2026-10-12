#!/usr/bin/env python3
"""Synthesize authentic tactical VHF radio key-up and squelch chirps."""
import wave
from pathlib import Path
import numpy as np

RATE = 48000
ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/audio/voices"


def write_wav(path: Path, data: np.ndarray) -> None:
    data = np.clip(data, -0.95, 0.95)
    int_data = (data * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(int_data.tobytes())


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)

    # radio_chirp_in: ~38ms tactical radio key-up
    t_in = np.arange(round(0.038 * RATE)) / RATE
    chirp = np.sin(2 * np.pi * (2100 + 400 * np.exp(-t_in / 0.008)) * t_in) * np.exp(-t_in / 0.012)
    noise = np.random.default_rng(42).standard_normal(len(t_in))
    noise_shaped = noise * np.exp(-t_in / 0.006) * 0.25
    click_in = (0.6 * chirp + 0.4 * noise_shaped) * (1 - np.exp(-t_in / 0.001))
    click_in = click_in / np.max(np.abs(click_in)) * 0.22  # -13 dBFS
    write_wav(DEST / "radio_chirp_in.wav", click_in)

    # radio_chirp_out: ~42ms squelch tail
    t_out = np.arange(round(0.042 * RATE)) / RATE
    rng = np.random.default_rng(84)
    raw_noise = rng.standard_normal(len(t_out))
    squelch = raw_noise * (1.0 - np.exp(-t_out / 0.002)) * np.exp(-t_out / 0.015)
    cutoff_click = np.sin(2 * np.pi * 1400 * t_out) * np.exp(-t_out / 0.005)
    click_out = 0.7 * squelch + 0.3 * cutoff_click
    click_out = click_out / np.max(np.abs(click_out)) * 0.20  # -14 dBFS
    write_wav(DEST / "radio_chirp_out.wav", click_out)

    print("Wrote radio_chirp_in.wav and radio_chirp_out.wav to", DEST)


if __name__ == "__main__":
    main()
