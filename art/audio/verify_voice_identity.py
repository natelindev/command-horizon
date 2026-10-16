"""Verify the shipped speech itself: words are heard as written and every voice is distinct.

Decodes each spoken Ogg, transcribes it with Whisper and embeds each speaker's full set of
lines with ECAPA. Writes voice-identity-verification.json:
  cd art/audio && ../../tmp/voice-venv/bin/python verify_voice_identity.py
"""
import json
from collections import defaultdict
from pathlib import Path

import librosa
import numpy as np
import torch
import whisper
from build_battle_audio import GLOSSARY, transcript_error
from speechbrain.inference.speaker import EncoderClassifier
from verify_battle_audio import decode
from voice_cast import ANNOUNCERS, PROFILES

ROOT = Path(__file__).resolve().parents[2]
REFERENCES = ROOT / 'tmp/voice-refs'
# ECAPA cosine: one person's lines typically score well above .5 against each other.
MAX_CROSS_SIMILARITY = .5


def main():
    manifest = json.loads((ROOT / 'art/audio/battle-audio-manifest.json').read_text())
    asr = whisper.load_model('medium.en', device='cpu')
    ecapa = EncoderClassifier.from_hparams('speechbrain/spkrec-ecapa-voxceleb',
                                           savedir=str(ROOT / 'tmp/voice-work/ecapa'),
                                           run_opts={'device': 'cpu'})

    def embed(audio16):
        with torch.inference_mode():
            vector = ecapa.encode_batch(torch.from_numpy(audio16)[None]).squeeze().numpy()
        return vector / np.linalg.norm(vector)

    lines, failures = defaultdict(list), []
    errors = {}
    for entry in manifest:
        speaker = entry['speaker_id']
        if speaker is None:
            continue
        audio16 = librosa.resample(decode(ROOT / 'assets/audio/voices' / entry['file']),
                                   orig_sr=24000, target_sr=16000)
        heard = asr.transcribe(audio16, language='en', fp16=False, temperature=0,
                               initial_prompt=GLOSSARY)['text'].strip()
        error = transcript_error(entry['text'], heard)
        errors[entry['file']] = {'text': entry['text'], 'heard': heard, 'word_error': round(error, 3)}
        limit = PROFILES[speaker].get('max_word_error', .25)
        if error > limit:
            failures.append(f"{entry['file']}: {entry['text']!r} heard as {heard!r}")
        lines[speaker].append(audio16)
        silence = np.zeros(1600, dtype=np.float32)
        lines[speaker].append(silence)
    speakers = sorted(lines)
    vectors = np.array([embed(np.concatenate(lines[s])) for s in speakers])
    similarity = vectors @ vectors.T
    np.fill_diagonal(similarity, -1)
    closest = {s: (speakers[int(similarity[i].argmax())], round(float(similarity[i].max()), 3))
               for i, s in enumerate(speakers)}
    for speaker, (other, value) in closest.items():
        if value >= MAX_CROSS_SIMILARITY:
            failures.append(f'{speaker} sounds like {other} ({value})')
    # Cloned crew must sound like their own donor more than any other cast reference.
    cast = [s for s in speakers if s not in ANNOUNCERS.values() and not PROFILES[s].get('robot')]
    reference = {}
    for s in cast:
        path = REFERENCES / PROFILES[s]['reference']
        reference[s] = embed(librosa.load(path, sr=16000)[0])
    identity = {}
    for s in cast:
        own = float(vectors[speakers.index(s)] @ reference[s])
        rival = max((float(vectors[speakers.index(s)] @ reference[o]), o) for o in cast if o != s)
        identity[s] = {'own_reference': round(own, 3), 'best_other': [round(rival[0], 3), rival[1]]}
        if own <= rival[0]:
            failures.append(f'{s} resembles {rival[1]} reference more than its own')
    word_errors = [item['word_error'] for item in errors.values()]
    summary = {
        'spoken_clips': len(errors), 'speakers': len(speakers),
        'exact_transcripts': sum(e == 0 for e in word_errors),
        'mean_word_error': round(float(np.mean(word_errors)), 4),
        'max_cross_speaker_similarity': max(v for _, v in closest.values()),
        'closest_pairs': closest, 'cast_identity': identity,
        'inexact_transcripts': {f: e for f, e in errors.items() if e['word_error'] > 0},
        'failures': failures,
    }
    (ROOT / 'art/audio/voice-identity-verification.json').write_text(
        json.dumps(summary, indent=1, ensure_ascii=False) + '\n')
    print(json.dumps({k: summary[k] for k in ['spoken_clips', 'speakers', 'exact_transcripts',
                                              'mean_word_error', 'max_cross_speaker_similarity']}))
    assert not failures, '\n'.join(failures)
    print('PASS every spoken clip intelligible; every voice distinct')


if __name__ == '__main__':
    main()
