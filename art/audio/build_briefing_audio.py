"""Build, audit and install narrated motion-comic briefings in the existing hero cast.

No arguments shows cached progress. Build inputs remain under tmp; shipped Oggs need
no synthesis installation. Each mission is paced between 45 and 60 seconds, including
authored paragraph breathing room, without changing the speaker's pitch.
"""
import argparse
import contextlib
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'art/audio/briefing-script.json'
MANIFEST = ROOT / 'art/audio/briefing-audio-manifest.json'
REPORT = ROOT / 'art/audio/briefing-audio-verification.json'
CACHE = ROOT / 'tmp/voice-work/briefings'
OUT = ROOT / 'assets/audio/campaign/briefings'
CATALOG = ROOT / 'assets/audio/campaign/briefings.json'
CAST = {'aegis': ('bastion', 'bastion/Hero'), 'nyx': ('helix', 'helix/Hero'),
        'rook': ('frontier', 'frontier/Hero')}
REVISION = 2
PACING_REVISION = 2


class BuildParser(argparse.ArgumentParser):
    def error(self, message):
        print('error: ' + json.dumps(message)
              + '\nhelp: Run build_briefing_audio.py --help for available commands')
        raise SystemExit(2)


def read(path, fallback):
    return json.loads(path.read_text()) if path.exists() else fallback


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    pending = path.with_suffix('.tmp')
    pending.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
    pending.replace(path)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def script_records(path):
    data = read(path, [])
    missions = data.get('missions', []) if isinstance(data, dict) else data
    seen, segments = set(), set()
    for mission in missions:
        mid = mission['mission_id']
        if not re.fullmatch(r'[a-z0-9_.-]+', mid) or mid in seen or mission['speaker'] not in CAST:
            raise ValueError('Duplicate mission or uncast speaker: ' + mid)
        if mission['faction'] != CAST[mission['speaker']][0]:
            raise ValueError('Speaker does not belong to faction: ' + mid)
        breathing = float(mission.get('paragraph_breath_seconds', 1.0))
        if not .5 <= breathing <= 2.0:
            raise ValueError('Paragraph breathing room must be between .5 and 2 seconds: ' + mid)
        seen.add(mid)
        if not 3 <= len(mission['segments']) <= 5:
            raise ValueError('Briefings require 3–5 natural paragraphs: ' + mid)
        for line in mission['segments']:
            if (not re.fullmatch(r'[a-z0-9_.-]+', line['id']) or line['id'] in segments
                    or not line['en'].strip() or not line['zh'].strip()):
                raise ValueError('Duplicate segment or missing localized text: ' + mid)
            if not 8 <= len(line['en'].split()) <= 40:
                raise ValueError('Keep each spoken paragraph between 8 and 40 words: ' + line['id'])
            segments.add(line['id'])
    return missions


def profiles():
    from voice_cast import PROFILES
    return {speaker: dict(PROFILES[key], max_word_error=.1, min_similarity=.4)
            for speaker, (_, key) in CAST.items()}


def source_hash(mission, line, profile):
    return hashlib.sha256(json.dumps([REVISION, mission['mission_id'], mission['speaker'],
        mission['faction'], line['id'], line['en'], profile], sort_keys=True).encode()).hexdigest()


def render_hash(mission, line, profile):
    pacing_key = str(PACING_REVISION)
    if 'paragraph_breath_seconds' in mission:
        pacing_key += ':breath=' + str(float(mission['paragraph_breath_seconds']))
    return hashlib.sha256((source_hash(mission,line,profile) + ':' + pacing_key).encode()).hexdigest()


def pacing(speech_seconds, paragraphs, mission_id, paragraph_breath_seconds=1.0):
    breaths = paragraphs * paragraph_breath_seconds
    # Tempo filters have a small endpoint latency; keep encoded output inside
    # the requested range rather than exactly on its numerical boundary.
    target = min(59.8, max(45.2, speech_seconds + breaths))
    tempo = speech_seconds / (target - breaths)
    if not .8 <= tempo <= 1.15:
        raise ValueError('Narration needs a script pacing adjustment: ' + mission_id
                         + f' ({speech_seconds:.1f}s speech, required tempo {tempo:.2f})')
    return tempo


def spoken_phrases(text):
    """Preserve authored words while keeping model takes at natural breath marks."""
    phrases = []
    for sentence in re.split(r'(?<=[.!?;])\s+', text.strip()):
        if len(sentence.split()) <= 16:
            phrases.append(sentence)
            continue
        clauses = re.split(r'(?<=,)\s+', sentence)
        pending = ''
        for clause in clauses:
            pending = (pending + ' ' + clause).strip()
            if len(pending.split()) >= 5:
                phrases.append(pending)
                pending = ''
        if pending:
            if phrases:
                phrases[-1] += ' ' + pending
            else:
                phrases.append(pending)
    return phrases


def build(args, missions):
    import numpy as np
    import build_battle_audio as battle
    import build_campaign_audio as campaign
    from verify_battle_audio import decode
    battle.GLOSSARY = campaign.GLOSSARY
    cast = profiles()
    voices = None
    accepted = read(CACHE / 'takes.json', {})
    manifest = {item['id']: item for item in read(MANIFEST, [])}
    for mission in missions:
        if args.mission and mission['mission_id'] not in args.mission.split(','):
            continue
        profile = cast[mission['speaker']]
        cached = True
        for line in mission['segments']:
            record = manifest.get(line['id'], {})
            path = ROOT / record.get('file','missing')
            if (record.get('source_hash') != render_hash(mission,line,profile)
                    or not path.is_file() or record.get('sha256') != digest(path)):
                cached = False
                break
        if cached:
            print('Cached ' + mission['mission_id'], file=sys.stderr, flush=True)
            continue
        staged = []
        for line in mission['segments']:
            key = line['id']
            path = CACHE / (key + '.ogg')
            source = source_hash(mission, line, profile)
            prior = accepted.get(key, {})
            if not path.exists() or prior.get('source_hash') != source or prior.get('sha256') != digest(path):
                if voices is None:
                    with contextlib.redirect_stdout(sys.stderr):
                        voices = battle.Voices(SimpleNamespace(model=ROOT/'tmp/kokoro/kokoro-v1.0.onnx',
                            voices=ROOT/'tmp/kokoro/voices-v1.0.bin', cpu_threads=args.cpu_threads))
                print('Rendering ' + key, file=sys.stderr, flush=True)
                parts, checks = [], []
                for index, phrase in enumerate(spoken_phrases(line['en'])):
                    part = dict(id=line['id'] + '.phrase_%02d' % index, en=phrase)
                    part_path = CACHE/(part['id'] + '.ogg')
                    part_source = source_hash(mission, part, profile)
                    prior_part = accepted.get(part['id'], {})
                    if (not part_path.exists() or prior_part.get('source_hash') != part_source
                            or prior_part.get('sha256') != digest(part_path)):
                        with contextlib.redirect_stdout(sys.stderr):
                            payload, qc = campaign.take(voices, part, profile, mission['faction'])
                        part_path.parent.mkdir(parents=True, exist_ok=True)
                        pending = part_path.with_suffix('.tmp.ogg')
                        pending.write_bytes(payload)
                        pending.replace(part_path)
                        accepted[part['id']] = dict(source_hash=part_source, sha256=digest(part_path), qc=qc)
                        write(CACHE/'takes.json', accepted)
                    parts.extend([decode(part_path), np.zeros(3600)])
                    checks.append(accepted[part['id']]['qc'])
                combined = np.concatenate(parts)
                pending = path.with_suffix('.tmp.ogg')
                battle.encode(pending, battle.master(combined,24000,-16.),24000)
                payload = pending.read_bytes()
                pending.unlink()
                heard = ' '.join(qc['heard'] for qc in checks)
                qc = dict(heard=heard, word_error=campaign.transcript_error(line['en'],heard),
                          reference_similarity=min(check['reference_similarity'] for check in checks),
                          phrases=len(checks))
                if qc['word_error'] > .1:
                    raise ValueError('Narration phrase assembly changed words: ' + key)
                path.parent.mkdir(parents=True, exist_ok=True)
                pending = path.with_suffix('.tmp.ogg')
                pending.write_bytes(payload)
                pending.replace(path)
                accepted[key] = dict(source_hash=source, sha256=digest(path), qc=qc)
                write(CACHE/'takes.json', accepted)
            staged.append(decode(path))
        speech_seconds = sum(len(audio) / 24000 for audio in staged)
        breathing = float(mission.get('paragraph_breath_seconds', 1.0))
        tempo = pacing(speech_seconds, len(staged), mission['mission_id'], breathing)
        OUT.mkdir(parents=True, exist_ok=True)
        for line, audio in zip(mission['segments'], staged):
            if abs(tempo - 1) > .001:
                audio = battle.ffmpeg_filter(audio, 24000, f'atempo={tempo:.8f}')
            audio = np.concatenate([audio, np.zeros(round(24000 * breathing))])
            audio = battle.master(audio, 24000, -16.)
            path = OUT / (line['id'] + '.ogg')
            pending = CACHE/'encoded'/path.name
            pending.parent.mkdir(parents=True, exist_ok=True)
            battle.encode(pending, audio, 24000)
            pending.replace(path)
            manifest[line['id']] = dict(id=line['id'], mission_id=mission['mission_id'],
                speaker=mission['speaker'], speaker_id=CAST[mission['speaker']][1], text=line['en'],
                file=str(path.relative_to(ROOT)), sha256=digest(path),
                source_hash=render_hash(mission, line, profile),
                duration=round(len(decode(path)) / 24000, 4), tempo=round(tempo, 6),
                qc=accepted[line['id']]['qc'])
        write(MANIFEST, list(manifest.values()))
        print('Completed ' + mission['mission_id'], file=sys.stderr, flush=True)
    print(f'segments: {len(manifest)}\nmanifest: {MANIFEST}')


def verify(args, missions):
    import librosa
    import numpy as np
    import torch
    import whisper
    from speechbrain.inference.speaker import EncoderClassifier
    from build_campaign_audio import GLOSSARY, transcript_error
    from verify_battle_audio import decode, loudness
    torch.set_num_threads(args.cpu_threads)
    manifest = {item['id']: item for item in read(MANIFEST, [])}
    cache = read(CACHE/'transcripts.json', {})
    cast = profiles()
    asr = None
    ecapa = EncoderClassifier.from_hparams('speechbrain/spkrec-ecapa-voxceleb',
        savedir=str(ROOT/'tmp/voice-work/ecapa'), run_opts={'device': 'cpu'})

    def embed(audio):
        with torch.inference_mode():
            vector = ecapa.encode_batch(torch.from_numpy(audio)[None]).squeeze().numpy()
        return vector / np.linalg.norm(vector)

    references = {key: embed(librosa.load(ROOT/'tmp/voice-refs'/profile['reference'], sr=16000)[0])
                  for key, profile in cast.items()}
    failures, assets, durations = [], [], {}
    for mission in missions:
        duration = 0.
        for line in mission['segments']:
            record = manifest.get(line['id'], {})
            path = ROOT / record.get('file', 'missing')
            if not path.is_file():
                failures.append('Missing recording: ' + line['id'])
                continue
            sha = digest(path)
            if record.get('sha256') != sha or record.get('source_hash') != render_hash(mission, line, cast[mission['speaker']]):
                failures.append('Stale or changed recording: ' + line['id'])
            audio = decode(path)
            seconds = len(audio) / 24000
            duration += seconds
            peak, level = float(np.max(np.abs(audio))), float(loudness(audio))
            if not np.isfinite(audio).all() or not .5 < seconds < 30 or not .01 < peak < .95 or abs(level + 16) > 1:
                failures.append('Invalid audio signal or mix: ' + line['id'])
            audio16 = librosa.resample(audio, orig_sr=24000, target_sr=16000)
            key = hashlib.sha256((sha + line['en'] + GLOSSARY).encode()).hexdigest()
            if key not in cache:
                if asr is None:
                    asr = whisper.load_model('medium.en', device='cpu')
                cache[key] = asr.transcribe(audio16, language='en', fp16=False, temperature=0,
                    initial_prompt=GLOSSARY)['text'].strip()
                write(CACHE/'transcripts.json', cache)
            error = transcript_error(line['en'], cache[key])
            vector = embed(audio16)
            own = float(vector @ references[mission['speaker']])
            rival = max(float(vector @ ref) for name, ref in references.items() if name != mission['speaker'])
            if error > .1 or own < .4 or own <= rival:
                failures.append('Unclear words or wrong voice: ' + line['id'])
            assets.append(dict(id=line['id'], sha256=sha, seconds=round(seconds,4),
                lufs=round(level,2), peak_dbfs=round(20*np.log10(peak),2), heard=cache[key],
                word_error=round(error,4), own_reference=round(own,4), best_other=round(rival,4)))
            print('Audited ' + line['id'], file=sys.stderr, flush=True)
        durations[mission['mission_id']] = round(duration,4)
        if not 44.95 <= duration <= 60.05:
            failures.append('Briefing outside 45–60 seconds: ' + mission['mission_id'])
    report = dict(missions=len(missions), expected=sum(len(m['segments']) for m in missions),
        segments=len(assets), durations=durations, assets=assets, failures=failures)
    write(args.report, report)
    print(f'missions: {len(missions)}\nsegments: {len(assets)}\nfailures: {len(failures)}\nreport: {args.report}')
    if failures:
        raise ValueError('Briefing verification failed; review ' + str(args.report))


def install(missions, report_path=REPORT):
    manifest = {entry['id']: entry for entry in read(MANIFEST, [])}
    report = read(report_path, {})
    expected = sum(len(m['segments']) for m in missions)
    if report.get('failures', ['missing audit']) or report.get('segments') != expected:
        raise ValueError('A complete passing briefing audit is required before installation')
    verified = {entry['id']: entry['sha256'] for entry in report['assets']}
    result = {}
    for mission in missions:
        segments = []
        for line in mission['segments']:
            record = manifest[line['id']]
            path = ROOT / record['file']
            if record['source_hash'] != render_hash(mission,line,profiles()[mission['speaker']]) or digest(path) != verified[line['id']]:
                raise ValueError('Briefing changed after its audit: ' + line['id'])
            segments.append(dict(id=line['id'], en=line['en'], zh=line['zh'],
                stream='res://' + record['file'], duration=record['duration']))
        result[mission['mission_id']] = dict(segments=segments,
            duration=round(sum(segment['duration'] for segment in segments),4))
    write(CATALOG, result)
    print(f'missions: {len(result)}\ncatalog: {CATALOG}')


def main():
    parser = BuildParser(description=__doc__)
    parser.add_argument('command', nargs='?', choices=['status','build','verify','install'], default='status')
    parser.add_argument('--script', type=Path, default=SCRIPT)
    parser.add_argument('--report', type=Path, default=REPORT,
                        help='Audit report to write or validate before installation')
    parser.add_argument('--mission', help='Build only these comma-separated mission IDs')
    parser.add_argument('--cpu-threads', type=int, default=4)
    args = parser.parse_args()
    if args.cpu_threads < 1:
        raise ValueError('--cpu-threads must be positive')
    missions = script_records(args.script)
    if args.command == 'status':
        print(f'bin: {Path(__file__).resolve()}\ndescription: Build and verify voiced campaign briefings')
        print(f'missions: {len(missions)}\nsegments: {sum(len(m["segments"]) for m in missions)}')
        print(f'rendered: {len(read(MANIFEST, []))}\ninstalled: {len(read(CATALOG, {}))}')
        print('help[2]:\n  - Run build_briefing_audio.py build to render missing recordings\n  - Run build_briefing_audio.py verify to audit encoded speech')
        return
    if not missions:
        raise ValueError('No authored briefings found in ' + str(args.script))
    {'build': lambda: build(args,missions), 'verify': lambda: verify(args,missions),
     'install': lambda: install(missions,args.report)}[args.command]()


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        print('error: ' + json.dumps(str(error)) + '\nhelp: Review the script or cached audio and rerun the command')
        raise SystemExit(1)
    except ImportError:
        print('error: The voice build environment is incomplete\nhelp: Install art/audio/voice-requirements.txt in tmp/voice-venv and rerun the command')
        raise SystemExit(1)
