"""Derive aligned ambient / tension / combat stems from licensed recordings.

Requires tools/audio/music-stems-requirements.txt and ffmpeg. Source downloads are
separate; pinned CC0 instrument recordings support the original faction overlays.
Run from any directory: python3 tools/audio/build_music_stems.py
Three complementary masks retain the source arrangement at full intensity:
ambient carries sustained textures, tension carries transients and rhythm,
and combat carries the upper harmonic lead. All stems are sample-aligned.
"""

from pathlib import Path
import argparse
import importlib.util
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


def split(source, lead_cutoff=500.0):
    window = np.hanning(WINDOW).astype(np.float32)
    padding = WINDOW + (-len(source) % HOP)
    padded = np.pad(source, ((WINDOW, padding), (0, 0)))
    frames = np.lib.stride_tricks.sliding_window_view(padded, WINDOW, axis=0)[::HOP]
    spectrum = np.fft.rfft(frames * window, axis=-1)
    # One shared stereo mask preserves the source's spatial image.
    mask = percussion_mask(spectrum.mean(axis=1))
    percussion = np.zeros_like(padded)
    lead = np.zeros_like(padded)
    frequency = np.fft.rfftfreq(WINDOW, 1.0 / RATE)
    lead_mask = frequency ** 2 / (frequency ** 2 + lead_cutoff ** 2)
    weight = np.zeros(len(padded), dtype=np.float32)
    for start in range(0, len(frames), 128):
        stop = min(start + 128, len(frames))
        samples = np.fft.irfft(spectrum[start:stop] * mask[start:stop, None, :], axis=-1)
        leads = np.fft.irfft(
            spectrum[start:stop] * (1.0 - mask[start:stop, None, :]) * lead_mask,
            axis=-1,
        )
        for index, (sample, harmonic) in enumerate(zip(samples, leads), start):
            at = index * HOP
            percussion[at:at + WINDOW] += (sample * window).T
            lead[at:at + WINDOW] += (harmonic * window).T
            weight[at:at + WINDOW] += window ** 2
    percussion /= np.maximum(weight[:, None], 1e-8)
    lead /= np.maximum(weight[:, None], 1e-8)
    percussion = percussion[WINDOW:WINDOW + len(source)]
    lead = lead[WINDOW:WINDOW + len(source)]
    tension = percussion * .8 + lead * .1
    combat = lead * .55
    return source - tension - combat, tension, combat


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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=MUSIC, help='Staged output directory; default installs into game assets')
    parser.add_argument('--evidence', type=Path, default=ROOT/'tmp/music/arrangements', help='Isolated instrument auditions and event reports')
    parser.add_argument('--base-only', action='store_true', help='Reconstruct the original source-derived stems without new instrument arrangements')
    args = parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    arrangement = None
    if not args.base_only:
        spec = importlib.util.spec_from_file_location('faction_arrangements', ROOT/'art/audio/arrange_faction_score.py')
        arrangement = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(arrangement)
    with tempfile.TemporaryDirectory(prefix="music-stems-") as directory:
        staged = Path(directory)
        for track in TRACKS:
            raw = subprocess.check_output([
                "ffmpeg", "-v", "error", "-i", str(MUSIC / f"{track}.ogg"),
                "-f", "f32le", "-ar", str(RATE), "-ac", "2", "pipe:1",
            ])
            source = np.frombuffer(raw, dtype="<f4").reshape(-1, 2)
            cutoff = {"hold-the-line": 450.0, "perfect-compliance": 650.0,
                      "no-shutdown-code": 380.0}[track]
            calm, tension, combat = split(source, cutoff)
            assert np.max(np.abs(calm + tension + combat - source)) < 1e-6
            if arrangement is not None:
                faction = {'hold-the-line':'bastion','perfect-compliance':'helix','no-shutdown-code':'frontier'}[track]
                calm,tension,combat = arrangement.apply(faction,source,[calm,tension,combat],args.evidence)
            write(staged / f"{track}-calm.ogg", calm)
            write(staged / f"{track}-tension.ogg", tension)
            write(staged / f"{track}-combat.ogg", combat)
            print(f"{track}: {len(source) / RATE:.2f}s, three aligned stereo stems", flush=True)
        for output in staged.iterdir():
            output.replace(args.output / output.name)


if __name__ == "__main__":
    main()
