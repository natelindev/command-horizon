"""Original deterministic 48 kHz ambience for the three campaign interiors."""
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
RATE = 48000
SECONDS = 8
rng = np.random.default_rng(410811)
t = np.arange(RATE * SECONDS) / RATE

def low_noise(stride):
    knots = rng.normal(0, 1, len(t) // stride + 2)
    return np.interp(np.arange(len(t)), np.arange(len(knots)) * stride, knots)

def save(name, signal):
    # A short equal-power seam keeps looping procedural beds free of clicks.
    seam = RATE // 20
    signal[:seam] = signal[:seam] * np.linspace(0, 1, seam)
    signal[-seam:] *= np.linspace(1, 0, seam)
    signal *= .72 / max(1, np.max(np.abs(signal)))
    stereo = np.stack((signal, np.roll(signal, 37) * .97), axis=1)
    data = np.int16(np.clip(stereo, -1, 1) * 32767)
    path = ROOT / 'assets/audio/environment' / (name + '.wav')
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())
    print(path.relative_to(ROOT))

train = .18 * low_noise(260) + .09 * np.sin(2 * np.pi * 58 * t) + .04 * np.sin(2 * np.pi * 117 * t)
for start in np.arange(.1, SECONDS, .43):
    elapsed = np.maximum(0, t - start)
    envelope = np.where(t >= start, np.exp(-elapsed * 85), 0)
    train += envelope * (.2 * np.sin(2 * np.pi * 420 * elapsed) + .15 * low_noise(4))
save('war-train', train)

nexus = .08 * low_noise(150) + .09 * np.sin(2 * np.pi * 72 * t) + .035 * np.sin(2 * np.pi * 216 * t)
nexus += .025 * np.sin(2 * np.pi * 432 * t) * (.5 + .5 * np.sin(2 * np.pi * .25 * t))
save('nexus-core', nexus)

fire = .07 * low_noise(210) + .025 * low_noise(5)
for start in rng.uniform(0, SECONDS, 95):
    elapsed = np.maximum(0, t - start)
    envelope = np.where(t >= start, np.exp(-elapsed * rng.uniform(90, 220)), 0)
    fire += envelope * rng.uniform(.05, .25) * low_noise(3)
save('outpost-campfire', fire)
