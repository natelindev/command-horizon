"""Build battle dialogue, robot voices and mechanical/UI effects offline; no runtime TTS.

Run in the voice build environment (see README.md) with ffmpeg installed:
  tmp/voice-venv/bin/python art/audio/build_battle_audio.py --model tmp/kokoro/kokoro-v1.0.onnx --voices tmp/kokoro/voices-v1.0.bin
Models, reference voices and QC models are build inputs only; see assets/audio/voices/LICENSES.md.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
import wave
from difflib import SequenceMatcher
from importlib.metadata import version
from pathlib import Path

import numpy as np
from combat_barks import combat_text
from voice_cast import (ANNOUNCERS, ANNOUNCER_TEXT, CAST, EVENTS, MACHINES, MERCENARY,
                        MERCENARY_CAST, POOL, PROFILES, ROBOT_CAST, STOP_TEXT, STRUCTURES,
                        WORKER_TASKS, delivery)
from verify_voice_cast import validate_cast
from radio_voice import radio
from robot_voice import ROBOT_VOICES, robot_voice

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio/voices'
REFERENCES = ROOT / 'tmp/voice-refs'
RATE = 22050
SPEECH_RATE = 24000
# Bump when synthesis, QC or mastering changes; dialogue/casting changes invalidate per clip.
BUILD_REVISION = 5
SPEECH_LUFS = -16.0
MACHINE_LUFS = -20.0
PEAK_CEILING = 10 ** (-1.5 / 20)
CANDIDATES = 6
# Effort dB + half the pitch rise in semitones; calm reading scores about -12, a fired-up call
# -6 or higher (crew pilot). Reaching it ends the search early.
ENERGY_TARGET = -6.
POOL_F0 = {info['sha256']: info['f0_median_hz'] for info in POOL.values()}
# Names Whisper cannot know; spelling them out keeps transcription QC honest.
GLOSSARY = ('Aegis, Nyx, Rook, Bastion, Helix, Kestrel, Ironback, Outrider, Wraith, Lancer, Kite, '
            'Mender, Jackal, Shrike, Ripsaw.')


def clip_source_hash(text, speaker, identity, event, index, faction, provenance):
    # Only a clip's own cast/model is an input. Recasting one unit must not
    # invalidate every other speaker, machine and building in the bank.
    synthesis = {'mechanical_revision': 4}
    if speaker is not None:
        profile = provenance['profiles'][speaker]
        model = provenance['models'][profile['engine']]
        synthesis = [profile, model, delivery(speaker, event), processing(speaker)]
    return hashlib.sha256(json.dumps(
        [BUILD_REVISION, text, speaker, identity, event, index, faction, synthesis],
        sort_keys=True).encode()).hexdigest()


def processing(speaker):
    """Post-synthesis design that shapes a speaker's clips: robot voice or crew radio."""
    from radio_voice import CHANNELS, GEAR, UNIT_CLASS
    faction, role = speaker.split('/')
    if PROFILES[speaker].get('robot'):
        return ROBOT_VOICES[speaker]
    if role in UNIT_CLASS:
        return [CHANNELS[UNIT_CLASS[role]], GEAR[faction]]
    return None


def write_wave(path, data, rate=RATE):
    data = np.asarray(data)
    data = data / max(1., float(np.max(np.abs(data))) / .65)
    with wave.open(str(path), 'wb') as wav:
        wav.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
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


def mechanical(identity, event, variant, role, faction, duration=None, rate=RATE):
    """Role-specific machinery, with event gestures and faction tuning.

    Workers: piston motor + ratchet; repair bots: servo sweeps + tool taps;
    combat robots: heavy gear + latch; drones: rotor tremolo + telemetry arpeggio.
    Robots speak over this body; buildings retain their short console/motor feedback.
    """
    if role not in MACHINES:
        return structure_console(identity, event, variant)
    seed = int.from_bytes(hashlib.sha256(f'{identity}:{event}:{variant}'.encode()).digest()[:4], 'little')
    rng = np.random.default_rng(seed)
    if duration is None:
        duration = ({'Worker': .78, 'RepairRobot': .65, 'CombatRobot': .9, 'Drone': .7}[role]
                    + {'ready': .28, 'move': .08, 'attack': .12, 'stop': -.08}.get(event, 0))
    t = np.arange(int(rate * duration)) / rate
    env = np.minimum(t / .018, 1) * np.minimum((duration - t) / .1, 1)
    tuning = {'bastion': 1.0, 'helix': 1.32, 'frontier': .81}[faction]
    gesture = {'select': 1., 'move': 1.12, 'attack': 1.26, 'ready': .92,
               'gather': .85, 'construct': 1.05, 'repair': 1.18, 'stop': .75,
               'low_health': .8, 'kill': 1.35}[event]
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


def words(text):
    # A spoken "'s" is barely audible and transcribers drop it; it is not a missing word.
    text = re.sub(r"[’']s\b", '', text.lower().replace('-', ' '))
    # Whisper sometimes joins the homophone "root set" into a non-word. Restore
    # its boundary; "root" still counts as a mismatch against written "route".
    text = re.sub(r'\brootset\b', 'root set', text)
    # "'em" is how "them" is spoken in a shout; transcribers write it either way.
    return ['them' if word == 'em' else word for word in re.sub(r'[^a-z0-9 ]', '', text).split()]


def transcript_error(expected, heard):
    """Word-level mismatch ratio; 0 means every word was heard as written."""
    a, b = words(expected), words(heard)
    # Compound spacing is not audible: "duststorm" and "dust storm" have exactly
    # the same letters. This accepts no added, missing or substituted letters.
    if ''.join(a) == ''.join(b):
        return 0.
    return 1 - SequenceMatcher(None, a, b).ratio() if a or b else 0.


def trim(audio, rate):
    """Cut leading/trailing silence and breaths, keeping a short natural margin."""
    import librosa
    _, (start, end) = librosa.effects.trim(audio, top_db=38, frame_length=512, hop_length=128)
    start = max(0, start - int(.03 * rate))
    end = min(len(audio), end + int(.08 * rate))
    audio = audio[start:end].copy()
    fade = int(.04 * rate)
    audio[-fade:] *= np.linspace(1, 0, fade)
    audio[:int(.004 * rate)] *= np.linspace(0, 1, int(.004 * rate))
    return audio


def master(audio, rate, lufs):
    """Exact per-clip loudness, then a smooth limiter for the true-peak ceiling."""
    import pyloudnorm
    from scipy import ndimage
    meter = pyloudnorm.Meter(rate)
    window = int(.003 * rate)
    # Limiting lowers loudness slightly; a few passes converge on the target.
    for _ in range(4):
        padded = np.pad(audio, (0, max(0, int(.8 * rate) - len(audio))))
        audio = audio * 10 ** ((lufs - meter.integrated_loudness(padded)) / 20)
        gain = np.minimum(1, PEAK_CEILING / np.maximum(np.abs(audio), 1e-9))
        gain = ndimage.uniform_filter1d(ndimage.minimum_filter1d(gain, window * 2), window)
        audio = np.clip(audio * gain, -PEAK_CEILING, PEAK_CEILING)
    return audio


def ffmpeg_filter(audio, rate, filters):
    result = subprocess.run(
        ['ffmpeg', '-v', 'error', '-f', 'f32le', '-ar', str(rate), '-ac', '1', '-i', '-',
         '-af', filters, '-f', 'f32le', '-'],
        input=audio.astype('<f4').tobytes(), capture_output=True, check=True)
    return np.frombuffer(result.stdout, dtype='<f4').astype(np.float64)


def encode(path, audio, rate):
    # ffmpeg's Vorbis encoder can abort on exact digital silence; -100 dB dither is inaudible.
    audio = audio + np.random.default_rng(len(audio)).normal(0, 1e-5, len(audio))
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(rate), '-ac', '1',
                    '-i', '-', '-c:a', 'vorbis', '-strict', '-2', '-ac', '2', '-q:a', '6', str(path)],
                   input=audio.astype('<f4').tobytes(), check=True)


class Rejected(ValueError):
    """No take met the bar; carries the best attempt so a long build can finish and report."""

    def __init__(self, message, best):
        super().__init__(message)
        self.best = best


class Voices:
    """Speech engines plus the transcription and speaker models used to accept takes."""

    def __init__(self, args):
        import torch
        import whisper
        from chatterbox.tts import ChatterboxTTS
        from kokoro_onnx import Kokoro
        from speechbrain.inference.speaker import EncoderClassifier
        self.torch = torch
        torch.set_num_threads(getattr(args, 'cpu_threads', 4))
        cuda = torch.cuda.is_available()
        device = 'cuda' if cuda else 'mps' if torch.backends.mps.is_available() else 'cpu'
        self.kokoro = Kokoro(str(args.model), str(args.voices))
        self.chatterbox = ChatterboxTTS.from_pretrained(device=device)
        self.asr = whisper.load_model('medium.en', device='cuda' if cuda else 'cpu')
        self.ecapa = EncoderClassifier.from_hparams(
            'speechbrain/spkrec-ecapa-voxceleb', savedir=str(ROOT / 'tmp/voice-work/ecapa'),
            run_opts={'device': 'cpu'})
        self.reference_embeddings = {}
        self.models = {
            'kokoro': {'engine': 'kokoro-onnx ' + version('kokoro-onnx'), 'model': args.model.name,
                       'model_sha256': hashlib.sha256(args.model.read_bytes()).hexdigest(),
                       'voices_sha256': hashlib.sha256(args.voices.read_bytes()).hexdigest(),
                       'source': 'https://huggingface.co/hexgrad/Kokoro-82M',
                       'model_license': 'Apache-2.0'},
            'chatterbox': {'engine': 'chatterbox-tts ' + version('chatterbox-tts'),
                           'source': 'https://huggingface.co/ResembleAI/chatterbox',
                           'model_license': 'MIT', 'candidates': CANDIDATES,
                           'qc': 'openai-whisper medium.en transcript; speechbrain ECAPA speaker similarity',
                           'references': 'https://huggingface.co/kyutai/tts-voices (voice-donations, CC0)'},
        }

    def embedding(self, audio, rate):
        import librosa
        audio16 = librosa.resample(np.asarray(audio, dtype=np.float32), orig_sr=rate, target_sr=16000)
        with self.torch.inference_mode():
            vector = self.ecapa.encode_batch(self.torch.from_numpy(audio16)[None]).squeeze().numpy()
        return vector / np.linalg.norm(vector)

    def hear(self, audio, rate):
        import librosa
        audio16 = librosa.resample(np.asarray(audio, dtype=np.float32), orig_sr=rate, target_sr=16000)
        return self.asr.transcribe(audio16, language='en', fp16=False, temperature=0,
                                   initial_prompt=GLOSSARY)['text'].strip()

    def reference(self, profile):
        path = REFERENCES / profile['reference']
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != profile['reference_sha256']:
            raise ValueError(f'Reference voice differs from the cast: {path}')
        if path not in self.reference_embeddings:
            import librosa
            audio, rate = librosa.load(path, sr=None)
            self.reference_embeddings[path] = self.embedding(audio, rate)
        return path

    def kokoro_line(self, text, profile):
        voice = self.kokoro.get_voice_style(next(iter(profile['voices'])))
        samples, rate = self.kokoro.create(text, voice=voice, speed=profile['speed'],
                                           lang=profile['lang'])
        assert rate == SPEECH_RATE
        return trim(np.asarray(samples, dtype=np.float64), rate), {'engine': 'kokoro'}

    def cloned_line(self, text, speaker, event, finish=None):
        """Best of several seeded takes.

        Crew: among takes with the exact words that still sound like the cast voice, the most
        fired-up one wins; a take whose pitch leaps into a screech is rejected. Robots: the
        first exact, clean take wins.
        """
        profile = PROFILES[speaker]
        path = self.reference(profile)
        target = self.reference_embeddings[path]
        settings = delivery(speaker, event)
        robot = profile.get('robot', False)
        resting_f0 = POOL_F0[profile['reference_sha256']]
        seed = int(hashlib.sha256(f'{speaker}:{event}:{text}'.encode()).hexdigest()[:8], 16)
        # A second, slightly calmer pass rescues lines whose intense takes all lost the voice.
        calmer = dict(settings, exaggeration=round(max(.3, settings['exaggeration'] - .2), 2))
        passes = [settings] * CANDIDATES + ([] if robot else [calmer] * (CANDIDATES // 2))
        best = None
        for attempt, settings in enumerate(passes):
            if attempt == CANDIDATES and best is not None and not best[0][0]:
                break
            self.torch.manual_seed(seed + attempt)
            with self.torch.inference_mode():
                wav = self.chatterbox.generate(text, audio_prompt_path=str(path), **settings)
            take = trim(wav.squeeze(0).cpu().numpy().astype(np.float64), SPEECH_RATE)
            # A bloated take is a hallucination even if it ends with the right words.
            expected = .35 + .075 * len(text)
            if len(take) / SPEECH_RATE > 2.2 * expected:
                continue
            similarity = float(self.embedding(take, SPEECH_RATE) @ target)
            effort, f0 = vocal_energy(take, SPEECH_RATE)
            sane = robot or (similarity >= profile.get('min_similarity', .4)
                             and f0 is not None and f0 <= 2.2 * resting_f0)
            rise = 12 * np.log2(f0 / resting_f0) if f0 else 0.
            # Energy: vocal effort (upper-mid vs low spectrum) plus a raised, shouting pitch.
            energy = 0. if robot else effort + .5 * min(max(rise, 0), 10)
            # Transcription is the slow check; skip it for takes that cannot win.
            if best is not None and not best[0][0] and (
                    not sane or (best[0][1] == 0 and -energy >= best[0][2])):
                continue
            final = finish(take) if finish else take
            heard = self.hear(final, SPEECH_RATE)
            error = transcript_error(text, heard)
            score = (not sane, round(error, 2), -energy, -similarity)
            if best is None or score < best[0]:
                best = (score, final, {'engine': 'chatterbox', 'seed': seed + attempt,
                                       'heard': heard, 'word_error': round(error, 3),
                                       'reference_similarity': round(similarity, 3),
                                       'effort_db': round(effort, 1),
                                       'pitch_rise_st': round(float(rise), 1),
                                       'exaggeration': settings['exaggeration']})
            if error == 0 and (robot or (sane and energy >= ENERGY_TARGET)):
                break
        if best is None or best[0][0] or best[2]['word_error'] > profile.get('max_word_error', 0.):
            raise Rejected(f'No acceptable take for {speaker} {event}: {text!r} -> {best and best[2]}',
                           best)
        return best[1], best[2]


def vocal_energy(audio, rate):
    """Vocal effort in dB (1-5 kHz vs 50 Hz-1 kHz) and median pitch; shouting raises both."""
    import librosa
    audio16 = librosa.resample(np.asarray(audio, dtype=np.float32), orig_sr=rate, target_sr=16000)
    spectrum = np.abs(np.fft.rfft(audio16)) ** 2
    freqs = np.fft.rfftfreq(len(audio16), 1 / 16000)
    effort = 10 * np.log10(spectrum[(freqs > 1000) & (freqs < 5000)].sum()
                           / (spectrum[(freqs > 50) & (freqs < 1000)].sum() + 1e-12))
    f0, voiced, _ = librosa.pyin(audio16, fmin=60, fmax=600, sr=16000, frame_length=1024)
    f0 = f0[voiced & np.isfinite(f0)]
    return float(effort), (float(np.median(f0)) if len(f0) else None)


def speech_eq(audio):
    # Natural, close voice: rumble cut, slight mud cut, presence and air for consonants
    # (the synthesis vocoder rolls off above 8 kHz relative to the donated references).
    return ffmpeg_filter(audio, SPEECH_RATE, 'highpass=f=75,equalizer=f=320:t=q:w=1:g=-1.5,'
                                               'equalizer=f=3300:t=q:w=1.1:g=2,highshelf=f=7000:g=3')


def robot_take(audio, speaker, faction, role, event, index):
    design = ROBOT_VOICES[f'{faction}/{role}']
    voice = robot_voice(audio, SPEECH_RATE, design)
    lead = int(.12 * SPEECH_RATE)
    bed = mechanical(0, event, index, role, faction, duration=(len(voice) + lead) / SPEECH_RATE + .1,
                     rate=SPEECH_RATE)
    mix = np.zeros(len(bed))
    mix[lead:lead + len(voice)] = voice / (np.sqrt(np.mean(voice ** 2)) + 1e-9) * .1
    mix += bed / (np.sqrt(np.mean(bed ** 2)) + 1e-9) * .1 * 10 ** (-13 / 20)
    return mix


def publish_facilities(args):
    """Supplement mechanical facility replies without publishing incomplete speech."""
    manifest_path = ROOT / 'art/audio/battle-audio-manifest.json'
    catalog_path = OUT / 'catalog.json'
    catalog = json.loads(catalog_path.read_text())
    records = {entry['file']: entry for entry in json.loads(manifest_path.read_text())}
    provenance = {
        'kokoro': {'model': args.model.name, 'model_sha256': hashlib.sha256(args.model.read_bytes()).hexdigest()},
        'chatterbox': {'engine': 'chatterbox-tts ' + version('chatterbox-tts')},
    }
    texts = {'select': '[Telemetry chirp]', 'move': '[Drive engaged]',
             'attack': '[Targeting pulse]', 'ready': '[Systems online]',
             'gather': '[Extractor engaged]', 'construct': '[Tools engaged]',
             'repair': '[Repair servo engaged]', 'stop': '[Drive disengaged]'}
    generated = 0
    with tempfile.TemporaryDirectory() as work:
        raw = Path(work) / 'facility.wav'
        for faction_index, faction in enumerate(CAST):
            for role_index, role in enumerate(STRUCTURES):
                identity = faction_index * 17 + len(MACHINES) + role_index
                lines = {}
                for event, text in texts.items():
                    variants = []
                    for index in range(2 if event in ['select', 'move', 'attack'] else 1):
                        relative = f'{faction}/{role}/{event}_{index}.ogg'
                        path = OUT / relative
                        source_hash = clip_source_hash(text, None, identity, event, index, faction,
                            {'profiles': PROFILES, 'models': provenance})
                        previous = records.get(relative, {})
                        if not (path.is_file() and previous.get('source_hash') == source_hash
                                and previous.get('sha256') == hashlib.sha256(path.read_bytes()).hexdigest()):
                            path.parent.mkdir(parents=True, exist_ok=True)
                            write_wave(raw, mechanical(identity, event, index, role, faction))
                            band = {'bastion': 'highpass=f=180,lowpass=f=4300',
                                    'helix': 'highpass=f=260,lowpass=f=5100',
                                    'frontier': 'highpass=f=330,lowpass=f=3300'}[faction]
                            subprocess.run(['ffmpeg','-v','error','-y','-i',str(raw),'-af',
                                band + f',loudnorm=I={MACHINE_LUFS}:TP=-3:LRA=7,afade=t=in:d=0.008',
                                '-ar',str(RATE),'-ac','2','-c:a','vorbis','-strict','-2',
                                '-q:a','4',str(path)],check=True)
                            generated += 1
                        records[relative] = dict(file=relative, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                            speaker_id=None, text=text, source_hash=source_hash)
                        variants.append(dict(stream='res://assets/audio/voices/' + relative,
                            text=text, mechanical=True, robotic=False,
                            speaker_id=f'machine:{faction}/{role}'))
                    lines[event] = variants
                catalog['factions'][faction]['units'][role] = lines
    # Both files remain complete: only the deterministic facility bank changes.
    for path, data in [(manifest_path,list(records.values())),(catalog_path,catalog)]:
        pending = path.with_suffix('.tmp')
        pending.write_text(json.dumps(data,indent=2) + '\n')
        pending.replace(path)
    print(f'clips: {len(records)}\nfacilities_generated: {generated}\nspeech_changed: 0')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', type=Path, required=True)
    parser.add_argument('--voices', type=Path, required=True)
    parser.add_argument('--only', help='Rebuild only clips whose path starts with this prefix')
    parser.add_argument('--shard', help='Comma-separated path prefixes: render only their cloned '
                        'speech into the checkpoint (for another machine); no catalog/manifest')
    parser.add_argument('--checkpoint', type=Path, default=ROOT / 'tmp/voice-work/build-checkpoint.json')
    parser.add_argument('--facilities-only', action='store_true',
                        help='Publish deterministic facility replies while speech is still rendering')
    parser.add_argument('--cpu-threads', type=int, default=4,
                        help='CPU quality-check threads per worker (default: 4)')
    args = parser.parse_args()
    if args.cpu_threads < 1:
        parser.error('--cpu-threads must be at least 1')
    for path in [args.model, args.voices]:
        if not path.is_file():
            parser.error(f'Build input does not exist: {path}')
    shard = tuple(args.shard.split(',')) if args.shard else None
    validate_cast(PROFILES)
    OUT.mkdir(parents=True, exist_ok=True)
    if args.facilities_only:
        publish_facilities(args)
        return
    engines = None
    manifest_path = ROOT / 'art/audio/battle-audio-manifest.json'
    previous = {entry['file']: entry for entry in json.loads(manifest_path.read_text())} if manifest_path.exists() else {}
    # Each newly rendered clip is checkpointed, so an interrupted multi-hour build resumes.
    checkpoint_path = args.checkpoint
    checkpoint = json.loads(checkpoint_path.read_text()) if checkpoint_path.exists() else {}
    previous.update(checkpoint)
    catalog = {'factions': {}, 'mercenaries': {},
               'provenance': {'profiles': PROFILES, 'robot_voices': ROBOT_VOICES}}
    audit = []
    rejected = []

    def models():
        nonlocal engines
        if engines is None:
            engines = Voices(args)
        return engines

    model_provenance = {
        'kokoro': {'model': args.model.name, 'model_sha256': hashlib.sha256(args.model.read_bytes()).hexdigest()},
        'chatterbox': {'engine': 'chatterbox-tts ' + version('chatterbox-tts')},
    }
    with tempfile.TemporaryDirectory() as work:
        raw = Path(work) / 'raw.wav'

        def asset(faction, role, event, index, text, speaker=None, identity=0):
            relative = f'{faction}/{role}/{event}_{index}.ogg'
            path = OUT / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            source_hash = clip_source_hash(text, speaker, identity, event, index, faction,
                                           {'profiles': PROFILES, 'models': model_provenance})
            cached = previous.get(relative, {})
            valid_cache = (path.exists() and cached.get('source_hash') == source_hash
                           and cached.get('sha256') == hashlib.sha256(path.read_bytes()).hexdigest()
                           and not cached.get('qc', {}).get('rejected')
                           and not (args.only and relative.startswith(args.only)))
            qc = cached.get('qc') if valid_cache else None
            robotic = speaker is not None and PROFILES[speaker].get('robot', False)
            if shard and not valid_cache and not (
                    relative.startswith(shard) and speaker and PROFILES[speaker]['engine'] == 'chatterbox'):
                return {}
            if not valid_cache:
                if speaker is None:
                    write_wave(raw, mechanical(identity, event, index, role, faction))
                    band = {'bastion': 'highpass=f=180,lowpass=f=4300',
                            'helix': 'highpass=f=260,lowpass=f=5100',
                            'frontier': 'highpass=f=330,lowpass=f=3300'}[faction]
                    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(raw), '-af',
                                    band + f',loudnorm=I={MACHINE_LUFS}:TP=-3:LRA=7,afade=t=in:d=0.008',
                                    '-ar', str(RATE), '-ac', '2', '-c:a', 'vorbis', '-strict', '-2',
                                    '-q:a', '4', str(path)], check=True)
                else:
                    profile = PROFILES[speaker]
                    if profile['engine'] == 'kokoro':
                        audio, qc = models().kokoro_line(text, profile)
                        audio = speech_eq(audio)
                    else:
                        if robotic:
                            finish = lambda take: robot_take(take, speaker, faction, role, event, index)
                        else:
                            # Crew talk over field comms; the radio blend is checked by the
                            # same transcription as the dry take.
                            seed = int(hashlib.sha256(relative.encode()).hexdigest()[:8], 16)
                            finish = lambda take: radio(speech_eq(take), SPEECH_RATE, faction, role, seed)
                        try:
                            audio, qc = models().cloned_line(text, speaker, event, finish=finish)
                        except Rejected as error:
                            # Keep going; the clip is flagged, reported and fails verification.
                            if error.best is None:
                                raise
                            rejected.append(str(error))
                            audio, qc = error.best[1], dict(error.best[2], rejected=True)
                    encode(path, master(audio, SPEECH_RATE, SPEECH_LUFS), SPEECH_RATE)
                print(f'  {relative}', qc or '', flush=True, file=sys.stderr)
            entry = {'file': relative, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                     'speaker_id': speaker, 'text': text, 'source_hash': source_hash}
            if qc:
                entry['qc'] = qc
            audit.append(entry)
            if not valid_cache:
                checkpoint[relative] = entry
                checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
                pending_checkpoint = checkpoint_path.with_suffix('.tmp')
                pending_checkpoint.write_text(json.dumps(checkpoint))
                pending_checkpoint.replace(checkpoint_path)
            return {'stream': 'res://assets/audio/voices/' + relative, 'text': text,
                    'mechanical': speaker is None, 'robotic': robotic,
                    'speaker_id': speaker if speaker else f'machine:{faction}/{role}'}

        for faction_index, (faction, roles) in enumerate(CAST.items()):
            entry = {'announcer': {}, 'units': {}}
            catalog['factions'][faction] = entry
            for event, text in ANNOUNCER_TEXT.items():
                entry['announcer'][event] = asset(faction, 'Command', event, 0, text, ANNOUNCERS[faction])
            for role, (speaker, texts) in {**roles, **ROBOT_CAST[faction]}.items():
                lines = {}
                for event, text in zip(EVENTS, texts['lines'] if isinstance(texts, dict) else texts):
                    variants = lines.setdefault(event, [])
                    variants.append(asset(faction, role, event, len(variants), text, speaker))
                extra = texts.get('tasks', {}) if isinstance(texts, dict) else {}
                if role == 'Worker' and role in roles:
                    extra = WORKER_TASKS
                stop_text = texts['stop'] if isinstance(texts, dict) else STOP_TEXT[faction]
                extra = {**extra, 'stop': stop_text, **combat_text(faction, role)}
                for event, text in extra.items():
                    lines[event] = [asset(faction, role, event, 0, text, speaker)]
                entry['units'][role] = lines
                print(f'{faction}/{role} voiced', flush=True, file=sys.stderr)
            for role_index, role in enumerate(STRUCTURES):
                identity = faction_index * 17 + len(MACHINES) + role_index
                lines = {}
                for event in ['select', 'move', 'attack', 'ready', 'gather', 'construct', 'repair', 'stop']:
                    text = {'select': '[Telemetry chirp]', 'move': '[Drive engaged]',
                            'attack': '[Targeting pulse]', 'ready': '[Systems online]',
                            'gather': '[Extractor engaged]', 'construct': '[Tools engaged]',
                            'repair': '[Repair servo engaged]', 'stop': '[Drive disengaged]'}[event]
                    lines[event] = [asset(faction, role, event, i, text, identity=identity)
                                    for i in range(2 if event in ['select', 'move', 'attack'] else 1)]
                entry['units'][role] = lines
        # Camp mercenaries keep one voice in every army, so they are voiced once.
        for role, (speaker, texts) in MERCENARY_CAST.items():
            lines = {}
            for event, text in zip(EVENTS, texts):
                variants = lines.setdefault(event, [])
                variants.append(asset(MERCENARY, role, event, len(variants), text, speaker))
            lines['stop'] = [asset(MERCENARY, role, 'stop', 0, STOP_TEXT[MERCENARY], speaker)]
            for event, text in combat_text(MERCENARY, role).items():
                lines[event] = [asset(MERCENARY, role, event, 0, text, speaker)]
            catalog['mercenaries'][role] = lines
            print(f'{MERCENARY}/{role} voiced', flush=True, file=sys.stderr)
        if shard:
            print(f'checkpoint: {checkpoint_path}\nclips: {len(checkpoint)}\nrejected: {len(rejected)}',
                  flush=True)
            if rejected:
                raise SystemExit('Rejected:\n' + '\n'.join(rejected))
            return
        ui = ROOT / 'assets/audio/ui'
        ui.mkdir(parents=True, exist_ok=True)
        for kind in ['click', 'select', 'adjust', 'confirm']:
            write_wave(ui / f'{kind}.wav', ui_sound(kind))
    if engines is not None:
        catalog['provenance']['models'] = engines.models
    elif (OUT / 'catalog.json').exists():
        catalog['provenance']['models'] = json.loads((OUT / 'catalog.json').read_text())['provenance'].get('models', {})
    for stale in set(previous) - {entry['file'] for entry in audit}:
        (OUT / stale).unlink(missing_ok=True)
        Path(str(OUT / stale) + '.import').unlink(missing_ok=True)
    (OUT / 'catalog.json').write_text(json.dumps(catalog, indent=2) + '\n')
    manifest_path.write_text(json.dumps(audit, indent=2) + '\n')
    checkpoint_path.unlink(missing_ok=True)
    print(f'clips: {len(audit)}\nui_cues: 4\nrejected: {len(rejected)}', flush=True)
    if rejected:
        raise SystemExit('Lines without an acceptable take (rewrite or recast, then rebuild):\n'
                         + '\n'.join(rejected))


if __name__ == '__main__':
    main()
