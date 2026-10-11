"""Build original male dialogue and mechanical/UI effects; no runtime TTS.

Run with the kokoro-onnx, soundfile and numpy packages and ffmpeg installed:
  python art/audio/build_battle_audio.py --model tmp/kokoro/kokoro-v1.0.onnx --voices tmp/kokoro/voices-v1.0.bin
The upstream model/config are build inputs only; see assets/audio/voices/LICENSES.md.
"""
import argparse
import hashlib
import json
from importlib.metadata import version
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np
from kokoro_onnx import Kokoro
import soundfile as sf
from voice_cast import CAST, ANNOUNCERS, ANNOUNCER_TEXT, MACHINES, STRUCTURES, EVENTS, PROFILES

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio/voices'
RATE = 22050
# Bump when synthesis or filtering changes; dialogue/casting changes invalidate per clip.
BUILD_REVISION = 2


def write_wave(path, data):
    data = np.asarray(data)
    data = data / max(1., float(np.max(np.abs(data))) / .65)
    with wave.open(str(path), 'wb') as wav:
        wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes((data * 32767).astype('<i2').tobytes())


def mechanical(identity, event, variant):
    """Per-role motor/servo body plus a compact ascending/descending telemetry phrase."""
    seed = int.from_bytes(hashlib.sha256(f'{identity}:{event}:{variant}'.encode()).digest()[:4], 'little')
    rng = np.random.default_rng(seed)
    base = 95 + (identity * 37) % 300
    duration = .42 if event == 'select' else (.8 if event == 'ready' else .55)
    t = np.arange(int(RATE * duration)) / RATE
    env = np.minimum(t / .015, 1) * np.minimum((duration - t) / .09, 1)
    gear = np.sin(2 * np.pi * (base * t + 24 * t * t))
    whine = np.sin(2 * np.pi * base * 3.03 * t + .9 * np.sin(2 * np.pi * 23 * t))
    noise = rng.normal(0, .06, len(t))
    body = (gear * .13 + whine * .055 + noise) * env
    for i, ratio in enumerate([1., 1.25, 1.5] if event != 'attack' else [1.5, 1., .75]):
        start = .06 + i * duration / 4
        age = np.maximum(t - start, 0)
        pulse = (t >= start) * np.exp(-age * 38)
        body += .18 * np.sin(2 * np.pi * (base * 3 + variant * 43) * ratio * age) * pulse
    return body


def ui_sound(kind):
    duration = {'click': .055, 'select': .075, 'adjust': .035, 'confirm': .14}[kind]
    t = np.arange(int(RATE * duration)) / RATE
    freq = {'click': 710, 'select': 980, 'adjust': 550, 'confirm': 850}[kind]
    env = np.minimum(t / .004, 1) * np.exp(-t * 45) * np.minimum((duration - t) / .009, 1)
    return .28 * env * (np.sin(2 * np.pi * freq * t) + .2 * np.sin(2 * np.pi * freq * 2 * t))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', type=Path, required=True)
    parser.add_argument('--voices', type=Path, required=True)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    voice = Kokoro(str(args.model), str(args.voices))
    styles = {key: sum(voice.get_voice_style(name) * weight for name, weight in profile['voices'].items())
              for key, profile in PROFILES.items()}
    catalog = {'factions': {}, 'provenance': {
        'engine': 'kokoro-onnx ' + version('kokoro-onnx'), 'model': args.model.name,
        'model_sha256': hashlib.sha256(args.model.read_bytes()).hexdigest(),
        'voices_sha256': hashlib.sha256(args.voices.read_bytes()).hexdigest(),
        'source': 'https://huggingface.co/hexgrad/Kokoro-82M',
        'model_license': 'Apache-2.0', 'profiles': PROFILES,
    }}
    audit = []
    manifest_path = ROOT / 'art/audio/battle-audio-manifest.json'
    previous = {entry['file']: entry for entry in json.loads(manifest_path.read_text())} if manifest_path.exists() else {}
    with tempfile.TemporaryDirectory() as work:
        raw = Path(work) / 'raw.wav'
        def asset(faction, role, event, index, text, speaker=None, identity=0):
            relative = f'{faction}/{role}/{event}_{index}.ogg'
            path = OUT / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            source_hash = hashlib.sha256(json.dumps([BUILD_REVISION, text, speaker, identity,
                event, index, faction, catalog['provenance']], sort_keys=True).encode()).hexdigest()
            cached = previous.get(relative, {})
            valid_cache = (path.exists() and cached.get('source_hash') == source_hash
                           and cached.get('sha256') == hashlib.sha256(path.read_bytes()).hexdigest())
            if not valid_cache:
                if speaker is None:
                    write_wave(raw, mechanical(identity, event, index))
                else:
                    profile = PROFILES[speaker]
                    samples, sample_rate = voice.create(text, voice=styles[speaker],
                        speed=profile['speed'], lang=profile['lang'])
                    sf.write(str(raw), samples, sample_rate)
                # Mechanical telemetry keeps its original treatment; speech stays full-band.
                band = {'bastion': 'highpass=f=180,lowpass=f=4300',
                        'helix': 'highpass=f=260,lowpass=f=5100',
                        'frontier': 'highpass=f=330,lowpass=f=3300'}[faction]
                filters = (band + ',loudnorm=I=-20:TP=-3:LRA=7' if speaker is None else
                           'highpass=f=70,equalizer=f=280:t=q:w=0.8:g=-2,'
                           'equalizer=f=2800:t=q:w=0.7:g=1.5,loudnorm=I=-18:TP=-3:LRA=7')
                filters += ',afade=t=in:d=0.008'
                subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(raw), '-af', filters,
                                '-ar', str(RATE if speaker is None else 24000), '-ac', '2', '-c:a', 'vorbis', '-strict', '-2', '-q:a', '4', str(path)], check=True)
            audit.append({'file': relative, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                          'speaker_id': speaker, 'text': text, 'source_hash': source_hash})
            return {'stream': 'res://assets/audio/voices/' + relative, 'text': text,
                    'mechanical': speaker is None}
        for faction_index, (faction, roles) in enumerate(CAST.items()):
            entry = {'announcer': {}, 'units': {}}
            catalog['factions'][faction] = entry
            for event, text in ANNOUNCER_TEXT.items():
                entry['announcer'][event] = asset(faction, 'Command', event, 0, text, ANNOUNCERS[faction])
            for role, (speaker, texts) in roles.items():
                lines = {}
                for event, text in zip(EVENTS, texts):
                    variants = lines.setdefault(event, [])
                    variants.append(asset(faction, role, event, len(variants), text, speaker))
                stop_text = {'bastion': 'Holding position.', 'helix': 'Position locked.', 'frontier': 'Holding here.'}[faction]
                lines['stop'] = [asset(faction, role, 'stop', 0, stop_text, speaker)]
                if role == 'Worker':
                    for event, text in {'gather': 'Let us see what we can salvage.',
                                        'construct': 'Tools out. Let us build.',
                                        'repair': 'I can patch that up.'}.items():
                        lines[event] = [asset(faction, role, event, 0, text, speaker)]
                entry['units'][role] = lines
                print(f'{faction}/{role} voiced', flush=True)
            for role_index, role in enumerate(MACHINES + STRUCTURES):
                if role in roles:
                    continue
                identity = faction_index * 17 + role_index
                lines = {}
                for event in ['select', 'move', 'attack', 'ready', 'gather', 'construct', 'repair', 'stop']:
                    text = {'select': '[Telemetry chirp]', 'move': '[Drive engaged]',
                            'attack': '[Targeting pulse]', 'ready': '[Systems online]',
                            'gather': '[Extractor engaged]', 'construct': '[Tools engaged]',
                            'repair': '[Repair servo engaged]', 'stop': '[Drive disengaged]'}[event]
                    lines[event] = [asset(faction, role, event, i, text, identity=identity)
                                    for i in range(2 if event in ['select', 'move', 'attack'] else 1)]
                entry['units'][role] = lines
        ui = ROOT / 'assets/audio/ui'
        ui.mkdir(parents=True, exist_ok=True)
        for kind in ['click', 'select', 'adjust', 'confirm']:
            write_wave(ui / f'{kind}.wav', ui_sound(kind))
    (OUT / 'catalog.json').write_text(json.dumps(catalog, indent=2) + '\n')
    (ROOT / 'art/audio/battle-audio-manifest.json').write_text(json.dumps(audit, indent=2) + '\n')
    print(f'Built {len(audit)} battle clips and 4 UI cues.', flush=True)


if __name__ == '__main__':
    main()
