"""Audit shipped campaign Oggs: text, signal, cast identity and source provenance.

Transcripts are cached by file and script hash, so an interrupted audit resumes safely.
"""
import hashlib
import json
from collections import defaultdict
from pathlib import Path

import librosa
import numpy as np
import torch
import whisper
from speechbrain.inference.speaker import EncoderClassifier

from build_campaign_audio import ROOT, SCRIPT, MANIFEST, REVISION, GLOSSARY, cast, transcript_error
from verify_battle_audio import decode, loudness

REPORT = ROOT / 'art/audio/campaign-audio-verification.json'
CACHE = ROOT / 'tmp/hero-campaign/transcripts.json'


def main():
    profiles = cast()
    script = json.loads(SCRIPT.read_text())
    authored = {line['id']: line for mission in script['missions']
                for scene in mission['scenes'] for line in scene['lines']}
    manifest = {line['id']: line for line in json.loads(MANIFEST.read_text())}
    cache = json.loads(CACHE.read_text()) if CACHE.exists() else {}
    failures, assets = [], []
    speakers = defaultdict(list)
    asr = None
    for index, (key, line) in enumerate(authored.items()):
        record = manifest.get(key, {})
        path = ROOT / record.get('file', 'missing')
        if not path.is_file():
            failures.append('Missing voice: ' + key)
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        source = hashlib.sha256(json.dumps([REVISION, line, profiles[line['speaker']]],
                                           sort_keys=True).encode()).hexdigest()
        if record.get('source_hash') != source or record.get('sha256') != digest:
            failures.append('Stale source or changed voice: ' + key)
        audio = decode(path)
        seconds = len(audio) / 24000
        peak = float(np.max(np.abs(audio)))
        lufs = float(loudness(audio))
        if not np.isfinite(audio).all() or not .5 < seconds < 30:
            failures.append('Invalid signal/duration: ' + key)
        if not .01 < peak < .95 or abs(lufs + 16) > 1:
            failures.append(f'Invalid loudness/peak: {key} {lufs:.2f} LUFS {peak:.3f}')
        audio16 = librosa.resample(audio, orig_sr=24000, target_sr=16000)
        cache_key = hashlib.sha256((digest + line['en']).encode()).hexdigest()
        if cache_key not in cache:
            if asr is None:
                asr = whisper.load_model('medium.en', device='cpu')
            heard = asr.transcribe(audio16, language='en', fp16=False, temperature=0,
                initial_prompt=GLOSSARY)['text'].strip()
            cache[cache_key] = heard
            CACHE.parent.mkdir(parents=True, exist_ok=True)
            CACHE.write_text(json.dumps(cache, indent=2) + '\n')
        heard = cache[cache_key]
        error = transcript_error(line['en'], heard)
        if error > .1:
            failures.append(f'Unclear words: {key}: {heard!r} ({error:.3f})')
        assets.append(dict(id=key, speaker=line['speaker'], sha256=digest,
            seconds=round(seconds, 3), lufs=round(lufs, 2), peak_dbfs=round(20*np.log10(peak), 2),
            heard=heard, word_error=round(error, 4)))
        speakers[line['speaker']].extend([audio16, np.zeros(1600, dtype=np.float32)])
        print(f'[{index+1}/{len(authored)}] {key}: WER {error:.3f}', flush=True)
    ecapa = EncoderClassifier.from_hparams('speechbrain/spkrec-ecapa-voxceleb',
        savedir=str(ROOT / 'tmp/voice-work/ecapa'), run_opts={'device': 'cpu'})

    def embed(audio):
        with torch.inference_mode():
            value = ecapa.encode_batch(torch.from_numpy(audio)[None]).squeeze().numpy()
        return value / np.linalg.norm(value)

    vectors = {speaker: embed(np.concatenate(clips)) for speaker, clips in speakers.items()}
    references = {speaker: embed(librosa.load(ROOT/'tmp/voice-refs'/profile['reference'], sr=16000)[0])
                  for speaker, profile in profiles.items()}
    closest, identities = {}, {}
    for speaker, vector in vectors.items():
        rival = max((float(vector @ other), name) for name, other in vectors.items() if name != speaker)
        closest[speaker] = dict(speaker=rival[1], similarity=round(rival[0], 4))
        if rival[0] >= .5:
            failures.append(f'Cast voices too similar: {speaker}/{rival[1]} ({rival[0]:.3f})')
        own = float(vector @ references[speaker])
        other = max((float(vector @ ref), name) for name, ref in references.items() if name != speaker)
        identities[speaker] = dict(own=round(own,4), best_other=[round(other[0],4), other[1]])
        if not profiles[speaker].get('processing') and own <= other[0]:
            failures.append(f'Cast reference mismatch: {speaker} resembles {other[1]}')
    report = dict(clips=len(assets), expected=len(authored), speakers=len(vectors),
                  closest=closest, identities=identities, assets=assets, failures=failures)
    REPORT.write_text(json.dumps(report, indent=2, ensure_ascii=False)+'\n')
    if failures:
        raise SystemExit('\n'.join(failures))
    print(f'PASS {len(assets)} shipped campaign lines; {len(vectors)} distinct characters')


if __name__ == '__main__':
    main()
