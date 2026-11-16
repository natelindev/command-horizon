"""Original instrumental RTS score. No samples, recordings, or external composition.

uv run --with numpy --with scipy python art/audio/compose_score.py
Requires ffmpeg for the final Vorbis files. Deterministic score and synthesizers.
"""
import json
import math
from pathlib import Path
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tmp/music/procedural-legacy"
OUT.mkdir(parents=True, exist_ok=True)
RATE = 32000
RNG = np.random.default_rng(3407)
TAU = 2 * np.pi


def lowpass(signal, cutoff, order=2):
    return sosfilt(butter(order, cutoff, fs=RATE, output="sos"), signal).astype(np.float32)


def envelope(n, attack, release, decay=0):
    t = np.arange(n) / RATE
    sustain = max(.001, n / RATE - release)
    env = np.minimum(1, t / max(attack, .001))
    env *= np.minimum(1, np.maximum(0, (n / RATE - t) / max(release, .001)))
    if decay:
        env *= np.exp(-decay * np.maximum(0, t - attack))
    return env.astype(np.float32)


def tone(note, seconds, kind, velocity=1):
    n = int(seconds * RATE)
    t = np.arange(n, dtype=np.float32) / RATE
    f = 440 * 2 ** ((note - 69) / 12)
    signal = np.zeros(n, dtype=np.float32)
    if kind == "pad":
        for detune, phase in [(-.0018, .2), (.0015, 2.3), (0, 4.1)]:
            for harmonic in [1, 2, 3, 4, 5, 7]:
                signal += np.sin(TAU*f*(1+detune)*harmonic*t + phase) / harmonic**1.65
        signal *= envelope(n, .8, 1.7) * .12
        signal = lowpass(signal, 1700)
    elif kind == "horn":
        vibrato = .005 * np.sin(TAU*4.1*t) * np.minimum(t, .7)
        for harmonic in range(1, 9):
            signal += np.sin(TAU*f*harmonic*t + vibrato*harmonic) / harmonic**1.35
        signal = lowpass(signal, 1500) * envelope(n, .15, .38) * .32
    elif kind == "piano":
        for harmonic, amplitude, decay in [(1, 1, .75), (2, .45, 1.3), (3, .16, 2.0), (4, .08, 2.7)]:
            signal += amplitude*np.sin(TAU*f*harmonic*t)*np.exp(-decay*t)
        signal *= envelope(n, .006, .5)*.45
    elif kind == "pluck":
        signal = np.sin(TAU*f*t + 1.8*np.sin(TAU*f*2*t)*np.exp(-t*12))
        signal += .22*np.sin(TAU*f*2*t)
        signal = lowpass(signal, 3100) * envelope(n, .004, .12, 4.0) * .38
    elif kind == "bass":
        signal = np.sin(TAU*f*t) + .26*np.sin(TAU*f*2*t) + .13*np.sin(TAU*f*3*t)
        signal *= envelope(n, .018, .13, .45)*.65
    elif kind == "guitar":
        # Deterministic plucked-string resonator, warm and slightly saturated.
        period = max(2, round(RATE/f))
        burst = RNG.normal(0, .6, period).astype(np.float32)
        signal[:period] = burst
        # Vectorized delay repetitions with progressive spectral damping.
        cycle = burst
        for start in range(period, n, period):
            cycle = (cycle + np.roll(cycle, 1))*.493
            count = min(period, n-start)
            signal[start:start+count] = cycle[:count]
        signal = np.tanh(signal*2.0)*envelope(n, .003, .12)*.65
    else:
        raise ValueError(kind)
    return signal * velocity


def drum(kind, strength=1):
    duration = {"kick": .55, "snare": .30, "hat": .10, "tom": .65, "ride": .8}[kind]
    t = np.arange(int(RATE*duration), dtype=np.float32)/RATE
    noise = RNG.normal(0, 1, len(t)).astype(np.float32)
    if kind == "kick":
        phase = TAU*(46*t + 50*.018*(1-np.exp(-t/.018)))
        signal = np.sin(phase)*np.exp(-t*8) + lowpass(noise, 1500)*np.exp(-t*90)*.12
    elif kind == "snare":
        high = noise-lowpass(noise, 900)
        signal = high*np.exp(-t*21)*.38 + np.sin(TAU*175*t)*np.exp(-t*19)*.24
    elif kind == "hat":
        signal = (noise-lowpass(noise, 6500))*np.exp(-t*62)*.13
    elif kind == "ride":
        signal = (noise-lowpass(noise, 4700))*np.exp(-t*6)*.08
    else:
        signal = np.sin(TAU*(88*t + 27*.1*(1-np.exp(-t/.1))))*np.exp(-t*8)*.65
    signal[:80] *= np.linspace(0, 1, 80)
    signal[-160:] *= np.linspace(1, 0, 160)
    return signal*strength


class Score:
    def __init__(self, name, bpm, bars, title, description):
        self.name, self.bpm, self.bars = name, bpm, bars
        self.title, self.description = title, description
        self.beat = 60/bpm
        self.seconds = self.beat*bars*4
        self.audio = np.zeros((round(self.seconds*RATE), 2), dtype=np.float32)
        self.events = 0

    def add(self, signal, beat, gain=1, pan=0):
        start = round(beat*self.beat*RATE) % len(self.audio)
        left = math.cos((pan+1)*math.pi/4)*gain
        right = math.sin((pan+1)*math.pi/4)*gain
        stereo = signal[:, None]*np.array([left, right], dtype=np.float32)
        first = min(len(stereo), len(self.audio)-start)
        self.audio[start:start+first] += stereo[:first]
        if first < len(stereo):
            # Note tails wrap into the next cycle instead of being cut off.
            self.audio[:len(stereo)-first] += stereo[first:]
        self.events += 1

    def note(self, pitch, beat, length, voice, gain=.2, pan=0):
        self.add(tone(pitch, self.beat*length, voice), beat, gain, pan)

    def hit(self, kind, beat, gain=1, pan=0):
        self.add(drum(kind), beat, gain, pan)

    def finish(self):
        dry = self.audio.copy()
        # Circular multitap room/delay retains the exact loop duration.
        for delay, gain in [(.137, .08), (.293, .055), (.419, .045), (.613, .035), (.887, .025)]:
            self.audio += np.roll(dry[:, ::-1], round(delay*RATE), axis=0)*gain
        self.audio = np.tanh(self.audio*1.1)
        peak = np.abs(self.audio).max()
        self.audio *= .88/max(peak, .001)
        pcm = (self.audio*32767).astype('<i2')
        with tempfile.TemporaryDirectory() as temporary:
            wav = Path(temporary)/"score.wav"
            with wave.open(str(wav), 'wb') as output:
                output.setnchannels(2)
                output.setsampwidth(2)
                output.setframerate(RATE)
                output.writeframes(pcm.tobytes())
            subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav),
                            "-af", ("loudnorm=I=-19:TP=-2:LRA=10,afade=t=in:st=0.012:d=0.02,"
                                    + f"afade=t=out:st={self.seconds-.032:.6f}:d=0.02"),
                            "-ar", str(RATE),
                            "-c:a", "vorbis", "-strict", "-2", "-q:a", "5", "-metadata", "title="+self.title,
                            "-metadata", "artist=Command Horizon Original Score", str(OUT/(self.name+".ogg"))], check=True)
        return {"file": self.name+".ogg", "title": self.title, "bpm": self.bpm,
                "bars": self.bars, "seconds": self.seconds, "events": self.events,
                "description": self.description, "sample_rate": RATE}


# D-minor common motif, rephrased for each side. A shared world, different convictions.
CHORDS = [(38, [50, 57, 62, 65]), (34, [50, 53, 58, 62]),
          (41, [53, 57, 60, 65]), (36, [48, 55, 60, 64]),
          (38, [50, 57, 62, 65]), (34, [50, 53, 58, 65]),
          (31, [50, 55, 58, 62]), (33, [49, 57, 61, 64])]
MELODY = [[(69, 0, 1.5), (65, 2, 1), (62, 3, 2.5)],
          [(65, 1, 1), (67, 2, 1), (69, 3, 3)],
          [(72, 0, 2.5), (69, 3, 1), (67, 4, 2)],
          [(65, 0, 1.5), (64, 2, 1.5), (62, 4, 3)]]


def compose_menu():
    score = Score("after-the-silence", 80, 32, "After the Silence",
                  "Menu: spacious minor-key piano, warm strings and a restrained pulse; hope after the blackout.")
    for bar in range(32):
        bass, chord = CHORDS[(bar//2)%8]
        if bar%2 == 0:
            for index, note in enumerate(chord):
                score.note(note, bar*4, 10, "pad", .22, (index-1.5)*.36)
            score.note(bass, bar*4, 7.9, "bass", .15)
        for index, offset in enumerate([0, 1.5, 2.5, 3.5]):
            note = chord[[0, 2, 1, 3][index]]+12
            score.note(note, bar*4+offset, 3.2, "piano", .19 if index == 0 else .13, -.28+index*.17)
        if 8 <= bar < 24:
            score.hit("kick", bar*4, .22)
            score.hit("tom", bar*4+2.5, .09, -.3)
        if bar >= 16 and bar%2 == 0:
            for note, offset, length in MELODY[(bar//2)%4]:
                score.note(note, bar*4+offset, length, "horn", .15, .12)
    return score.finish()


def compose_bastion():
    score = Score("hold-the-line", 104, 40, "Hold the Line",
                  "Bastion: steady marching drums, low brass and resilient string chords.")
    for bar in range(40):
        bass, chord = CHORDS[(bar//2)%8]
        section = bar//8
        for index, pitch in enumerate(chord):
            if bar%2 == 0:
                score.note(pitch, bar*4, 9.8, "pad", .18, (index-1.5)*.4)
        for beat in [0, 1.5, 2, 3.5]:
            score.note(bass if beat < 2 else bass+7, bar*4+beat, .7, "bass", .21)
        for beat in [0, 2]:
            score.hit("kick", bar*4+beat, .4)
        if section != 4:
            for beat in [1, 3]:
                score.hit("snare", bar*4+beat, .22)
            for beat in [.5, 1.5, 2.5, 3.5]:
                score.hit("hat", bar*4+beat, .45, .35)
        for beat, index in [(0, 0), (.75, 1), (1.5, 2), (2.5, 1), (3.25, 3)]:
            score.note(chord[index], bar*4+beat, .8, "pluck", .14, -.4)
        if section in [1, 2, 3] and bar%2 == 0:
            for pitch, beat, length in MELODY[(bar//2)%4]:
                score.note(pitch-12, bar*4+beat, length, "horn", .24, .10)
                if section == 3:
                    score.note(pitch, bar*4+beat+.04, length, "piano", .12, -.2)
        if bar%8 == 7:
            for beat in [2.75, 3.25, 3.5]:
                score.hit("tom", bar*4+beat, .22, -.25)
    return score.finish()


def compose_helix():
    score = Score("perfect-compliance", 112, 40, "Perfect Compliance",
                  "Helix: cold clockwork sequences, rigid electronic percussion and a descending control motif.")
    helix = [(38, [50, 57, 62, 65]), (38, [50, 56, 62, 65]),
             (34, [50, 53, 58, 62]), (33, [49, 57, 61, 64])]
    for bar in range(40):
        bass, chord = helix[(bar//2)%4]
        for index, pitch in enumerate(chord):
            if bar%2 == 0:
                score.note(pitch, bar*4, 9.5, "pad", .13, (index-1.5)*.4)
        for step in range(8):
            note = chord[[0, 2, 1, 3, 0, 2, 3, 1][step]]+12
            gain = .18 if step%3 == 0 else .10
            score.note(note, bar*4+step*.5, .8, "pluck", gain, -.5 if step%2 else .5)
        for beat in [0, 1, 2, 3]:
            score.note(bass, bar*4+beat, .65, "bass", .22)
            score.hit("kick", bar*4+beat, .30 if bar//8 != 3 else .12)
        if 8 <= bar < 32:
            for beat in [1, 3]:
                score.hit("snare", bar*4+beat, .15, -.1)
            for beat in [.5, 1.5, 2.5, 3.5]:
                score.hit("hat", bar*4+beat, .5, .4)
        if 16 <= bar < 32 and bar%2 == 0:
            for pitch, beat in [(77, 0), (76, 1.5), (73, 3), (69, 5)]:
                score.note(pitch, bar*4+beat, 2.3, "piano", .17, .1)
    return score.finish()


def compose_frontier():
    score = Score("no-shutdown-code", 120, 40, "No Shutdown Code",
                  "Frontier: syncopated plucked strings, rough bass and restless breakbeat drums.")
    for bar in range(40):
        bass, chord = CHORDS[(bar//2)%8]
        if bar%2 == 0:
            for index, pitch in enumerate(chord):
                score.note(pitch, bar*4, 10, "pad", .12, (index-1.5)*.4)
        for beat, octave in [(0, 0), (.75, 0), (1.5, 12), (2.5, 0), (3.25, 7)]:
            score.note(bass+octave, bar*4+beat, .65, "bass", .20)
        for beat in [0, 1.75, 2.5]:
            score.hit("kick", bar*4+beat, .33)
        if bar//8 != 3:
            for beat in [1, 3]:
                score.hit("snare", bar*4+beat, .27)
            for step in range(8):
                score.hit("hat", bar*4+step*.5, .4 if step%2 else .23, .45)
        for step, degree in enumerate([0, 2, 3, 1, 2, 3]):
            score.note(chord[degree]+12, bar*4+[0, .75, 1.5, 2.25, 2.75, 3.5][step],
                       1.6, "guitar", .43, -.35)
        if bar >= 8 and bar%2 == 0:
            for pitch, beat, length in MELODY[(bar//2)%4]:
                score.note(pitch, bar*4+beat, length, "piano", .2, .25)
        if bar%8 == 7:
            for beat in [2.75, 3.5, 3.75]:
                score.hit("tom", bar*4+beat, .20, -.4)
    return score.finish()


tracks = [compose_menu(), compose_bastion(), compose_helix(), compose_frontier()]
(ROOT / "art/audio/score-manifest.json").write_text(json.dumps(tracks, indent=2)+"\n")
print("Composed 4 original, cyclic stereo cues:", round(sum(track["seconds"] for track in tracks)), "seconds")
