"""Derive aligned calm / combat stems from the licensed faction recordings.

Requires numpy and ffmpeg. No source download or new recordings are involved.
Run from any directory: python3 tools/audio/build_music_stems.py
The two stems sum to the source before Ogg encoding. A soft median-filter mask
retains 45% of percussion in the calm bed so the arrangement remains musical.
"""

from pathlib import Path
import subprocess
import tempfile

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
MUSIC = ROOT / "assets/audio/music"
TRACKS = ("hold-the-line", "perfect-compliance", "no-shutdown-code")
RATE, WINDOW, HOP = 44100, 2048, 512


def percussion_mask(spectrum):
    magnitude = np.abs(spectrum).astype(np.float32)
    time_pad = np.pad(magnitude, ((15, 15), (0, 0)), mode="edge")
    result = np.empty_like(magnitude)
    for start in range(0, len(magnitude), 128):
        stop = min(start + 128, len(magnitude))
        horizontal = np.median(
            np.lib.stride_tricks.sliding_window_view(time_pad[start:stop + 30], 31, axis=0),
            axis=-1,
        )
        vertical = np.median(
            np.lib.stride_tricks.sliding_window_view(
                np.pad(magnitude[start:stop], ((0, 0), (15, 15)), mode="edge"), 31, axis=1
            ), axis=-1,
        )
        # Conservative separation avoids ringing and preserves sustained bass.
        result[start:stop] = vertical ** 2 / (horizontal ** 2 + vertical ** 2 + 1e-12)
    return result


def split(source):
    window = np.hanning(WINDOW).astype(np.float32)
    padding = WINDOW + (-len(source) % HOP)
    padded = np.pad(source, ((WINDOW, padding), (0, 0)))
    frames = np.lib.stride_tricks.sliding_window_view(padded, WINDOW, axis=0)[::HOP]
    spectrum = np.fft.rfft(frames * window, axis=-1)
    # One shared stereo mask preserves the source's spatial image.
    mask = percussion_mask(spectrum.mean(axis=1))
    output = np.zeros_like(padded)
    weight = np.zeros(len(padded), dtype=np.float32)
    for start in range(0, len(frames), 128):
        stop = min(start + 128, len(frames))
        samples = np.fft.irfft(spectrum[start:stop] * mask[start:stop, None, :], axis=-1)
        for index, sample in enumerate(samples, start):
            at = index * HOP
            output[at:at + WINDOW] += (sample * window).T
            weight[at:at + WINDOW] += window ** 2
    output /= np.maximum(weight[:, None], 1e-8)
    combat = output[WINDOW:WINDOW + len(source)] * .55
    return source - combat, combat


def write(path, samples):
    encoders = subprocess.check_output(["ffmpeg", "-hide_banner", "-encoders"], stderr=subprocess.DEVNULL)
    codec = "libvorbis" if b"libvorbis" in encoders else "vorbis"
    subprocess.run([
        "ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE),
        "-ac", "2", "-i", "pipe:0", "-c:a", codec, "-strict", "-2", "-q:a", "5", str(path),
    ], input=samples.astype("<f4").tobytes(), check=True)
    # Decode every output before installation; an interrupted encoder must
    # never truncate a previously working stream in the game asset directory.
    subprocess.run(["ffmpeg", "-v", "error", "-xerror", "-i", str(path), "-f", "null", "-"], check=True)


def main():
    with tempfile.TemporaryDirectory(prefix="music-stems-") as directory:
        staged = Path(directory)
        for track in TRACKS:
            raw = subprocess.check_output([
                "ffmpeg", "-v", "error", "-i", str(MUSIC / f"{track}.ogg"),
                "-f", "f32le", "-ar", str(RATE), "-ac", "2", "pipe:1",
            ])
            source = np.frombuffer(raw, dtype="<f4").reshape(-1, 2)
            calm, combat = split(source)
            assert np.max(np.abs(calm + combat - source)) < 1e-6
            write(staged / f"{track}-calm.ogg", calm)
            write(staged / f"{track}-combat.ogg", combat)
            print(f"{track}: {len(source) / RATE:.2f}s, aligned stereo pair", flush=True)
        for output in staged.iterdir():
            output.replace(MUSIC / output.name)


if __name__ == "__main__":
    main()
