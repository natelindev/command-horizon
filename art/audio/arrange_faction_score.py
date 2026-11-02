"""Original faction arrangements over the licensed score, using pinned CC0 recordings.

Imported by tools/audio/build_music_stems.py. All instrument events are deterministic,
follow the measured beat/chord map, preserve sample counts and expose isolated parts.
"""
import hashlib
import json
from pathlib import Path

import librosa
import numpy as np
import pyloudnorm
import soundfile as sf
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[2]
RATE = 44100


def read(path):
    return json.loads(path.read_text())


def envelope(size, attack=.015, release=.12):
    t = np.arange(size) / RATE
    return np.minimum(1, t / attack) * np.minimum(1, np.maximum(0, (size / RATE - t) / release))


class Arrangement:
    def __init__(self, length):
        self.length = length
        self.parts = {}
        self.events = []
        self.samples = {}
        self.input_rows = {}
        for row in read(ROOT / "art/audio/faction-instruments.json"):
            path = ROOT / row['cache']
            if hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
                raise ValueError("Instrument changed: " + row['id'])
            audio, rate = sf.read(path, always_2d=True)
            audio = audio.mean(axis=1)[round(row['trim_start_seconds'] * rate):]
            audio = librosa.resample(audio, orig_sr=rate, target_sr=RATE)
            self.samples[row['id']] = (audio, row['root_midi'])
            self.input_rows[row['id']] = row

    def sampled(self, family, pitch, seconds, slide=0):
        choices = [(abs(root - pitch), key, audio, root) for key, (audio, root)
                   in self.samples.items() if key.startswith(family)]
        _, identity, audio, root = min(choices, key=lambda item: item[0])
        size = round(seconds * RATE)
        t = np.arange(size) / RATE
        # A continuous pitch trajectory gives the sampled electric string an
        # actual bottleneck-style glissando; it is not a renamed static note.
        bend = slide * np.maximum(0, 1 - t / .23) ** 2
        bend += .09 * np.sin(2*np.pi*5.4*t) * np.minimum(1, np.maximum(0, t-.24)*3)
        positions = np.cumsum(2 ** ((pitch - root + bend) / 12))
        signal = np.interp(positions, np.arange(len(audio)), audio, left=0, right=0)
        signal /= max(np.max(np.abs(signal)), 1e-8)
        if family == 'guitar':
            signal = sosfilt(butter(2, [110, 5200], btype='bandpass', fs=RATE, output='sos'),
                             np.tanh(signal * 3.0))
        elif family == 'harp':
            signal = np.tanh(signal * 1.5) * (1 + .12*np.sin(2*np.pi*5.8*t))
        return signal * envelope(size, .012 if family == 'guitar' else .045), identity

    def synth(self, pitch, seconds, sub=False):
        size = round(seconds*RATE)
        t = np.arange(size)/RATE
        hz = 440 * 2**((pitch-69)/12)
        if sub:
            signal = np.sin(2*np.pi*hz*t) + .12*np.sin(2*np.pi*hz*2*t)
            return signal * envelope(size, .025, .12) * (1-.23*np.exp(-t*8))
        # Band-limited detuned harmonics, decaying cutoff and a repeating
        # sixteenth-note contour make the arpeggio distinct from the source bed.
        phase = 2*np.pi*hz*t
        signal = sum(np.sin(phase*h + .018*h*np.sin(2*np.pi*.17*t))
                     * np.exp(-h*t*3.5) / h for h in range(1, min(30,int(18000/hz))))
        return np.tanh(signal*1.7) * envelope(size, .006, .045) * np.exp(-t*4)

    def add(self, part, signal, seconds, pitch, instrument, pan=0, slide=0):
        start = round(seconds*RATE)
        stop = min(start+len(signal), self.length-int(.5*RATE))
        if start < int(.1*RATE) or stop <= start:
            return
        if part not in self.parts:
            self.parts[part] = np.zeros((self.length,2),dtype=np.float32)
        gains = np.sqrt(np.array([(1-pan)/2,(1+pan)/2]))
        self.parts[part][start:stop] += (signal[:stop-start,None]*gains).astype(np.float32)
        self.events.append(dict(part=part,seconds=round(seconds,6),pitch=pitch,
                                duration=round((stop-start)/RATE,6),instrument=instrument,slide_semitones=slide))

    def note(self, part, family, pitch, at, length, pan=0, slide=0):
        signal, identity = self.sampled(family,pitch,length,slide)
        self.add(part,signal,at,pitch,identity,pan,slide)


def apply(faction, source, stems, evidence):
    plan = read(ROOT / "art/audio/faction-arrangements.json")[faction]
    source_path = ROOT / 'assets/audio/music' / (plan['track']+'.ogg')
    if hashlib.sha256(source_path.read_bytes()).hexdigest() != plan['source_sha256']:
        raise ValueError('Analyze the changed score before arranging: '+faction)
    score = Arrangement(len(source))
    beats = np.array(plan['beat_times'])
    for bar, chord in enumerate(plan['chords']):
        at, end, root, third = chord['seconds'], chord['end'], chord['root'], chord['third']
        beat = (end-at)/4
        if faction == 'bastion' and bar % 4 in (0,2):
            # Low orchestral horns/trombones answer the existing industrial march.
            score.note('dark_brass','trombone',36+root,at,beat*1.45,-.14)
            score.note('dark_brass','horn',48+root,at+beat*.02,beat*1.5,.14)
            if bar % 4 == 2:
                score.note('dark_brass','horn',48+(root+7)%12,at+beat*2,beat*.8,.18)
        elif faction == 'frontier':
            # A sampled hollowbody slide riff alternates with real diatonic
            # blues-harp call/response, leaving room for the source guitar lead.
            if bar % 4 in (0,2):
                score.note('slide_guitar','guitar',55+root,at+beat*.5,beat*1.1,-.24,-5)
                score.note('slide_guitar','guitar',55+root+3,at+beat*2,beat*.7,-.24,-2)
            if bar % 4 == 3:
                for off,interval,length in [(0,7,.7),(1,10,.65),(2,7,.8),(3,0,.85)]:
                    score.note('blues_harp','harp',60+root+interval,at+beat*off,beat*length,.22,-.65)
        elif faction == 'helix':
            # Every beat carries a resolved low root. Sixteenth-note chord
            # arpeggios cycle with a deterministic displaced final step.
            for off in range(4):
                pitch=24+root
                signal=score.synth(pitch,beat*.86,sub=True)
                score.add('deep_sub',signal,at+beat*off,pitch,'original_sine_sub')
            contour=[0,7,12,third,7,12,third,19]
            for off in range(16):
                pitch=60+root+contour[off%8]
                signal=score.synth(pitch,beat*.24)
                score.add('hypnotic_arp',signal,at+beat*off/4,pitch,'original_bandlimited_synth',-.2 if off%2 else .2)
    targets={'dark_brass':-27,'slide_guitar':-27,'blues_harp':-28,'deep_sub':-27,'hypnotic_arp':-28}
    routing={'dark_brass':2,'slide_guitar':2,'blues_harp':1,'deep_sub':2,'hypnotic_arp':1}
    report=dict(faction=faction,bpm=plan['bpm'],source_sha256=plan['source_sha256'],
                grid_sha256=hashlib.sha256((ROOT/'art/audio/faction-arrangements.json').read_bytes()).hexdigest(),
                authored_notes_sha256=hashlib.sha256(json.dumps(score.events,sort_keys=True).encode()).hexdigest(),
                sources={key:row for key,row in score.input_rows.items() if any(e['instrument']==key for e in score.events)},
                events=score.events,parts={})
    evidence.mkdir(parents=True,exist_ok=True)
    for name,audio in score.parts.items():
        lufs=pyloudnorm.Meter(RATE).integrated_loudness(audio.astype(np.float64))
        gain=min(10**((targets[name]-lufs)/20),.45/max(np.abs(audio).max(),1e-8))
        audio*=gain
        sf.write(evidence/(faction+'-'+name+'.flac'),audio,RATE,subtype='PCM_24')
        stems[routing[name]]+=audio
        report['parts'][name]=dict(file=faction+'-'+name+'.flac',
                                                  sha256=hashlib.sha256((evidence/(faction+'-'+name+'.flac')).read_bytes()).hexdigest(),
                                                  stem=routing[name],integrated_lufs=round(pyloudnorm.Meter(RATE).integrated_loudness(audio.astype(np.float64)),3),peak=float(np.abs(audio).max()),events=sum(e['part']==name for e in score.events))
    # One shared gain preserves all dynamic stem relationships with safe headroom.
    peak=max(float(np.abs(sum(stems)).max()),1e-8)
    gain=min(1,.89/peak)
    stems=[audio*gain for audio in stems]
    report['common_gain']=gain
    report['samples']=len(source)
    sf.write(evidence/(faction+'-arranged-audition.flac'),sum(stems),RATE,subtype='PCM_24')
    (evidence/(faction+'-arrangement.json')).write_text(json.dumps(report,indent=2)+'\n')
    return stems
