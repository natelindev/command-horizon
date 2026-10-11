"""Build original male dialogue and mechanical/UI effects; no runtime TTS.

Run with kokoro-onnx, piper-tts, soundfile, numpy and ffmpeg installed:
  python art/audio/build_battle_audio.py --model tmp/kokoro/kokoro-v1.0.onnx --voices tmp/kokoro/voices-v1.0.bin --unit-model tmp/piper/en_GB-vctk-medium.onnx
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
from piper import PiperVoice, SynthesisConfig
import soundfile as sf
from voice_cast import CAST, ANNOUNCERS, ANNOUNCER_TEXT, MACHINES, STRUCTURES, EVENTS, PROFILES
from verify_voice_cast import validate_cast

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio/voices'
RATE = 22050
# Bump when synthesis or filtering changes; dialogue/casting changes invalidate per clip.
BUILD_REVISION = 3


def clip_source_hash(text, speaker, identity, event, index, faction, provenance):
    # Only a clip's own cast/model is an input. Recasting one unit must not
    # invalidate every other speaker, machine and building in the bank.
    synthesis = {'mechanical_revision': 4}
    if speaker is not None:
        profile = provenance['profiles'][speaker]
        model = provenance['models'][profile['engine']].copy()
        speaker_ids = model.pop('speaker_ids', {})
        synthesis = [profile, model, speaker_ids.get(profile.get('speaker'))]
    return hashlib.sha256(json.dumps(
        [BUILD_REVISION, text, speaker, identity, event, index, faction, synthesis],
        sort_keys=True).encode()).hexdigest()


def write_wave(path, data):
    data = np.asarray(data)
    data = data / max(1., float(np.max(np.abs(data))) / .65)
    with wave.open(str(path), 'wb') as wav:
        wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes((data * 32767).astype('<i2').tobytes())


def structure_console(identity, event, variant):
    """Existing structure console feedback, preserved independently of autonomous units."""
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


def mechanical(identity, event, variant, role, faction):
    """Role-specific machinery, with event gestures and faction tuning.

    Workers: piston motor + ratchet; repair bots: servo sweeps + tool taps;
    combat robots: heavy gear + latch; drones: rotor tremolo + telemetry arpeggio.
    Buildings retain their short console/motor feedback.
    """
    if role not in MACHINES:
        return structure_console(identity, event, variant)
    seed = int.from_bytes(hashlib.sha256(f'{identity}:{event}:{variant}'.encode()).digest()[:4], 'little')
    rng = np.random.default_rng(seed)
    duration = ({'Worker': .78, 'RepairRobot': .65, 'CombatRobot': .9, 'Drone': .7}[role]
                + {'ready': .28, 'move': .08, 'attack': .12, 'stop': -.08}.get(event, 0))
    t = np.arange(int(RATE * duration)) / RATE
    env = np.minimum(t / .018, 1) * np.minimum((duration - t) / .1, 1)
    tuning = {'bastion': 1.0, 'helix': 1.32, 'frontier': .81}[faction]
    gesture = {'select': 1., 'move': 1.12, 'attack': 1.26, 'ready': .92,
               'gather': .85, 'construct': 1.05, 'repair': 1.18, 'stop': .75}[event]
    base = tuning * gesture * (1 + .07 * variant)
    noise = rng.normal(0, 1, len(t))

    def tone(freq, sweep=0):
        return np.sin(2 * np.pi * (freq * t + sweep * t * t))

    def pulse(at, decay):
        return (t >= at) * np.exp(-np.maximum(t - at, 0) * decay)

    if role == 'Worker':
        motor = tone(92 * base, 13 * base) + .35 * tone(184 * base)
        body = .17 * motor * (.55 + .45 * tone(19 * base))
        for at in np.arange(.05, duration - .1, .12 + variant * .018):
            body += pulse(at, 55) * (.1 * noise + .12 * tone(720 * base))
    elif role == 'RepairRobot':
        body = .11 * tone(540 * base, 460 * base) * (.7 + .3 * tone(7))
        body += .06 * tone(1080 * base, -240 * base)
        for at in [.06, .19, .38 + variant * .05]:
            body += pulse(at, 48) * (.2 * tone(2100 * base) + .025 * noise)
    elif role == 'CombatRobot':
        body = .2 * (tone(66 * base, -8 * base) + .45 * tone(132 * base))
        body *= .7 + .3 * tone(11 * base)
        for at in [.04, duration * (.55 + variant * .08)]:
            body += pulse(at, 25) * (.22 * noise + .24 * tone(310 * base))
        body += .07 * tone(430 * base, 110 * base)
    elif role == 'Drone':
        body = .1 * (tone(340 * base, 100) + .4 * tone(680 * base))
        body *= .5 + .5 * tone(48 * base)
        for i, ratio in enumerate([1., 1.5, 2., 1.25]):
            at = .06 + i * duration / 5
            body += .16 * tone(1600 * base * ratio) * pulse(at, 32)
    # Shared faction engineering character without replacing the role's body.
    if faction == 'helix':
        body += .035 * tone(2400 * base) * (.5 + .5 * tone(9))
    elif faction == 'frontier':
        body += .025 * noise * (.5 + .5 * tone(27))
    if event == 'stop':
        body *= np.exp(-t * 3)
    elif event in ['ready', 'construct', 'repair', 'gather']:
        body *= .65 + .35 * np.square(tone(3 if event == 'ready' else 6))
    return body * env


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
    parser.add_argument('--unit-model', type=Path, required=True)
    args = parser.parse_args()
    validate_cast(PROFILES)
    OUT.mkdir(parents=True, exist_ok=True)
    voice = Kokoro(str(args.model), str(args.voices))
    unit_voice = PiperVoice.load(str(args.unit_model))
    unit_config = Path(str(args.unit_model) + '.json')
    speaker_ids = json.loads(unit_config.read_text())['speaker_id_map']
    styles = {key: sum(voice.get_voice_style(name) * weight for name, weight in profile['voices'].items())
              for key, profile in PROFILES.items() if profile['engine'] == 'kokoro'}
    catalog = {'factions': {}, 'provenance': {'profiles': PROFILES, 'models': {'kokoro': {
        'engine': 'kokoro-onnx ' + version('kokoro-onnx'), 'model': args.model.name,
        'model_sha256': hashlib.sha256(args.model.read_bytes()).hexdigest(),
        'voices_sha256': hashlib.sha256(args.voices.read_bytes()).hexdigest(),
        'source': 'https://huggingface.co/hexgrad/Kokoro-82M',
        'model_license': 'Apache-2.0',
    }, 'piper': {
        'engine': 'piper-tts ' + version('piper-tts'), 'model': args.unit_model.name,
        'model_sha256': hashlib.sha256(args.unit_model.read_bytes()).hexdigest(),
        'config_sha256': hashlib.sha256(unit_config.read_bytes()).hexdigest(),
        'source': 'https://huggingface.co/rhasspy/piper-voices/tree/main/en/en_GB/vctk/medium',
        'dataset': 'https://doi.org/10.7488/ds/2645', 'dataset_license': 'CC-BY-4.0',
        'speaker_ids': {p['speaker']: speaker_ids[p['speaker']] for p in PROFILES.values()
                        if p['engine'] == 'piper'},
    }}}}
    audit = []
    manifest_path = ROOT / 'art/audio/battle-audio-manifest.json'
    previous = {entry['file']: entry for entry in json.loads(manifest_path.read_text())} if manifest_path.exists() else {}
    with tempfile.TemporaryDirectory() as work:
        raw = Path(work) / 'raw.wav'
        def asset(faction, role, event, index, text, speaker=None, identity=0):
            relative = f'{faction}/{role}/{event}_{index}.ogg'
            path = OUT / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            source_hash = clip_source_hash(text, speaker, identity, event, index,
                                           faction, catalog['provenance'])
            cached = previous.get(relative, {})
            valid_cache = (path.exists() and cached.get('source_hash') == source_hash
                           and cached.get('sha256') == hashlib.sha256(path.read_bytes()).hexdigest())
            if not valid_cache:
                if speaker is None:
                    write_wave(raw, mechanical(identity, event, index, role, faction))
                else:
                    profile = PROFILES[speaker]
                    if profile['engine'] == 'kokoro':
                        samples, sample_rate = voice.create(text, voice=styles[speaker],
                            speed=profile['speed'], lang=profile['lang'])
                        sf.write(str(raw), samples, sample_rate)
                    else:
                        config = SynthesisConfig(speaker_id=speaker_ids[profile['speaker']],
                            length_scale=profile['length_scale'], normalize_audio=False)
                        with wave.open(str(raw), 'wb') as wav:
                            unit_voice.synthesize_wav(text, wav, syn_config=config)
                # Structures keep their original band; machines retain their distinct low/high bodies.
                band = {'bastion': 'highpass=f=180,lowpass=f=4300',
                        'helix': 'highpass=f=260,lowpass=f=5100',
                        'frontier': 'highpass=f=330,lowpass=f=3300'}[faction]
                if speaker is None and role in MACHINES:
                    band = 'highpass=f=50,lowpass=f=7000'
                filters = (band + ',loudnorm=I=-20:TP=-3:LRA=7' if speaker is None else
                           'highpass=f=70,equalizer=f=280:t=q:w=0.8:g=-2,'
                           'equalizer=f=2800:t=q:w=0.7:g=1.5,loudnorm=I=-18:TP=-3:LRA=7')
                filters += ',afade=t=in:d=0.008'
                subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(raw), '-af', filters,
                                '-ar', str(RATE if speaker is None else 24000), '-ac', '2', '-c:a', 'vorbis', '-strict', '-2', '-q:a', '4', str(path)], check=True)
            audit.append({'file': relative, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                          'speaker_id': speaker, 'text': text, 'source_hash': source_hash})
            return {'stream': 'res://assets/audio/voices/' + relative, 'text': text,
                    'mechanical': speaker is None,
                    'speaker_id': speaker if speaker else f'machine:{faction}/{role}'}
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
