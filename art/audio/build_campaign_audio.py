"""Build and audit the authored English campaign conversations using the battle voice cast."""
import argparse
import hashlib
import json
import re
import tempfile
from pathlib import Path
from types import SimpleNamespace

import numpy as np
import build_battle_audio as battle
from radio_voice import radio
from robot_voice import robot_voice
from voice_cast import PROFILES, cloned
from verify_battle_audio import decode

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'docs/plans/hero-campaign-dialogue.json'
OUT = ROOT / 'assets/audio/campaign/dialogue'
CAST_PATH = ROOT / 'art/audio/campaign-cast.json'
MANIFEST = ROOT / 'art/audio/campaign-audio-manifest.json'
REVISION = 1
GLOSSARY = ('Meridian, Cinder Ford, Aegis, Nyx, Rook, Voss, Kerrigan, Elias, '
            'CANTOR, Arden, Ren, Ilan, Wren, Hask, Jory.')
NUMBER_WORDS = dict(zip(
    'zero one two three four five six seven eight nine ten eleven twelve thirteen '
    'fourteen fifteen sixteen seventeen eighteen nineteen twenty'.split(),
    map(str, range(21))))
NUMBER_WORDS.update(zip('thirty forty fifty sixty seventy eighty ninety'.split(),
                        map(str, range(30, 100, 10))))


def cast():
    existing = {'aegis': 'bastion/Hero', 'nyx': 'helix/Hero', 'rook': 'frontier/Hero'}
    supporting = {'voss': 'vctk/p294', 'kerrigan': 'Allen', 'elias': 'vctk/p302',
                  'cantor': 'vctk/p270', 'arden': 'vctk/p256', 'ren': 'vctk/p259',
                  'ilan': 'Haku', 'wren': 'vctk/p266', 'hask': 'vctk/p316', 'jory': 'Jeffrey'}
    result = {name: dict(PROFILES[key], battle_voice=key) for name, key in existing.items()}
    result.update({name: cloned(reference, max_word_error=.1, min_similarity=.4)
                   for name, reference in supporting.items()})
    result["cantor"]["processing"] = {"vocoder_hz": [98, 196], "vocoder_mix": .55,
        "comb_ms": 2.8, "comb_fb": .3, "band": (100, 9000)}
    return result


def transcript_error(expected, heard):
    # Equivalent spellings of the same spoken compound must not trigger regeneration.
    def normalize(text):
        text = re.sub(r'\bcease[ -]?fire\b', 'cease fire', text, flags=re.I)
        text = re.sub(r'\bmarshall\b', 'marshal', text, flags=re.I)
        text = re.sub(r'\b(?:wren|renn)\b', 'ren', text, flags=re.I)
        text = re.sub(r'\btellylan\b', 'tell ilan', text, flags=re.I)
        text = re.sub(r'\bfocus beams\b', 'focused beams', text, flags=re.I)
        text = re.sub(r'\bapologis', 'apologiz', text, flags=re.I)
        return re.sub(r'\b[a-z]+\b', lambda word: NUMBER_WORDS.get(
            word[0].lower(), word[0]), text, flags=re.I)
    return battle.transcript_error(normalize(expected), normalize(heard))


def take(voices, line, profile, faction):
    reference = voices.reference(profile)
    target = voices.reference_embeddings[reference]
    seed = int(hashlib.sha256(line['id'].encode()).hexdigest()[:8], 16)
    best = None
    for attempt in range(6):
        voices.torch.manual_seed(seed + attempt)
        with voices.torch.inference_mode():
            wav = voices.chatterbox.generate(line['en'], audio_prompt_path=str(reference),
                                             exaggeration=.5 if attempt < 3 else .35,
                                             cfg_weight=.5, temperature=.75)
        audio = battle.trim(wav.squeeze(0).cpu().numpy().astype(np.float64), 24000)
        if len(audio) / 24000 > 2.2 * (.35 + .075 * len(line['en'])):
            continue
        similarity = float(voices.embedding(audio, 24000) @ target)
        audio = battle.speech_eq(audio)
        if profile.get("processing"):
            audio = robot_voice(audio, 24000, profile["processing"])
        audio = radio(audio, 24000, faction, 'Hero')
        audio = battle.master(audio, 24000, -16.0)
        # Judge the delivered codec output, using the same vocabulary as the
        # independent shipped-file audit. Keep those exact bytes if accepted.
        with tempfile.TemporaryDirectory(prefix='campaign-voice-') as folder:
            encoded = Path(folder) / 'take.ogg'
            battle.encode(encoded, audio, 24000)
            payload = encoded.read_bytes()
            heard = voices.hear(decode(encoded), 24000)
        error = transcript_error(line['en'], heard)
        print(f'  take {attempt + 1}: word error {error:.3f}, identity {similarity:.3f}', flush=True)
        if error:
            print('    heard:', heard, flush=True)
        score = (similarity < .4, error, -similarity)
        if best is None or score < best[0]:
            best = (score, payload, {'heard': heard, 'word_error': error,
                                  'reference_similarity': similarity, 'seed': seed + attempt})
        if error == 0 and similarity >= .4:
            break
    if best is None or best[0][0] or best[0][1] > .1:
        raise ValueError(f"No acceptable take for {line['id']}: {best and best[2]}")
    return best[1:]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--limit', type=int, default=0)
    args = parser.parse_args()
    script = json.loads(SCRIPT.read_text())
    profiles = cast()
    assert len({p['reference_sha256'] for p in profiles.values()}) == len(profiles)
    CAST_PATH.write_text(json.dumps(profiles, indent=2) + '\n')
    OUT.mkdir(parents=True, exist_ok=True)
    previous = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else []
    saved = {entry['id']: entry for entry in previous}
    voices = None
    failures = []
    all_lines = [(mission, line) for mission in script['missions']
                 for scene in mission['scenes'] for line in scene['lines']]
    if args.limit:
        all_lines = all_lines[:args.limit]
    for index, (mission, line) in enumerate(all_lines):
        profile = profiles[line['speaker']]
        digest = hashlib.sha256(json.dumps([REVISION, line, profile], sort_keys=True).encode()).hexdigest()
        path = OUT / (line['id'] + '.ogg')
        if saved.get(line['id'], {}).get('source_hash') == digest and path.exists():
            actual_hash = hashlib.sha256(path.read_bytes()).hexdigest()
            if saved[line['id']].get('sha256') == actual_hash:
                continue
        if voices is None:
            battle.GLOSSARY = GLOSSARY
            voices = battle.Voices(SimpleNamespace(model=ROOT/'tmp/kokoro/kokoro-v1.0.onnx',
                                                  voices=ROOT/'tmp/kokoro/voices-v1.0.bin'))
        print(f"[{index+1}/{len(all_lines)}] {line['id']} ({line['speaker']})", flush=True)
        try:
            payload, qc = take(voices, line, profile, mission['faction'])
            temporary = path.with_suffix(".tmp.ogg")
            temporary.write_bytes(payload)
            temporary.replace(path)
            saved[line['id']] = dict(id=line['id'], speaker=line['speaker'], text=line['en'],
                                    file=path.relative_to(ROOT).as_posix(), source_hash=digest, qc=qc,
                                    sha256=hashlib.sha256(path.read_bytes()).hexdigest())
            MANIFEST.write_text(json.dumps(list(saved.values()), indent=2, ensure_ascii=False)+'\n')
            print('  accepted', json.dumps(qc), flush=True)
        except ValueError as error:
            failures.append(str(error))
            print('  rejected', str(error), flush=True)
    (ROOT/'art/audio/campaign-audio-failures.json').write_text(json.dumps(failures, indent=2)+'\n')
    if failures:
        raise SystemExit(f'{len(failures)} lines rejected; accepted clips retained for the next run')
    print(f'PASS {len(all_lines)} authored lines cached or rendered', flush=True)


if __name__ == '__main__':
    main()
