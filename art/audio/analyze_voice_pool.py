"""Profile the reference voices available for unit casting.

Writes per-voice language, accent, pitch and recording-quality metrics to voice-pool.json
and ECAPA speaker embeddings (build input only) to tmp/voice-work/pool-embeddings.npz:
  tmp/voice-venv/bin/python art/audio/analyze_voice_pool.py
References come from https://huggingface.co/kyutai/tts-voices: voice-donations/ (CC0) and
vctk/ (CC BY 4.0; speaker accent metadata from the corpus' speaker-info.txt).
"""
import hashlib
import json
from pathlib import Path

import librosa
import numpy as np
import torch
import whisper
from speechbrain.inference.speaker import EncoderClassifier

ROOT = Path(__file__).resolve().parents[2]
POOLS = {'donations': 'voice-donations', 'vctk': 'vctk'}
REFERENCES = ROOT / 'tmp/voice-refs'
WORK = ROOT / 'tmp/voice-work'


def recording_quality(audio, rate):
    frames = librosa.feature.rms(y=audio, frame_length=1024, hop_length=256)[0]
    level = 20 * np.log10(np.maximum(frames, 1e-6))
    spectrum = np.abs(librosa.stft(audio, n_fft=2048)) ** 2
    energy = np.cumsum(spectrum.sum(axis=1))
    freqs = librosa.fft_frequencies(sr=rate, n_fft=2048)
    return {
        'snr_db': round(float(np.percentile(level, 95) - np.percentile(level, 10)), 1),
        'bandwidth_hz': int(freqs[np.searchsorted(energy, energy[-1] * .995)]),
        'peak': round(float(np.max(np.abs(audio))), 3),
    }


def embed(classifier, audio16):
    with torch.inference_mode():
        vector = classifier.encode_batch(torch.from_numpy(audio16)[None]).squeeze().numpy()
    return vector / np.linalg.norm(vector)


def vctk_speakers():
    header, *rows = (REFERENCES / 'vctk/speaker-info.txt').read_text().splitlines()
    columns = header.split()
    gender, accent = columns.index('GENDER'), columns.index('ACCENTS')
    return {row.split()[0]: {'gender': row.split()[gender], 'corpus_accent': row.split()[accent]}
            for row in rows if row.strip()}


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    asr = whisper.load_model('small', device='cpu')
    classifier = EncoderClassifier.from_hparams(
        'speechbrain/spkrec-ecapa-voxceleb', savedir=str(WORK / 'ecapa'), run_opts={'device': 'cpu'})
    accents = EncoderClassifier.from_hparams(
        'Jzuluaga/accent-id-commonaccent_ecapa', savedir=str(WORK / 'accent'), run_opts={'device': 'cpu'})
    labels = [accents.hparams.label_encoder.decode_ndim(i) for i in range(len(accents.hparams.label_encoder))]
    corpus = vctk_speakers()
    report, names, vectors = {}, [], []
    for folder, remote in POOLS.items():
        for path in sorted((REFERENCES / folder).glob('*_enhanced.wav')):
            name = path.name.removesuffix('_enhanced.wav')
            key = name if folder == 'donations' else 'vctk/' + name.split('_')[0]
            audio, rate = librosa.load(path, sr=None, mono=True)
            audio16 = librosa.resample(audio, orig_sr=rate, target_sr=16000)
            mel = whisper.log_mel_spectrogram(whisper.pad_or_trim(audio16.astype(np.float32)))
            _, languages = asr.detect_language(mel)
            f0, voiced, _ = librosa.pyin(audio16, fmin=55, fmax=320, sr=16000, frame_length=1024)
            f0 = f0[voiced & np.isfinite(f0)]
            with torch.inference_mode():
                # Independent per-accent scores (not a distribution). Only native English varieties
                # are classes, so a non-native speaker is not reliably flagged by a low score.
                scores = accents.classify_batch(torch.from_numpy(audio16)[None])[0].squeeze().numpy()
            top = scores.argsort()[::-1][:3]
            report[key] = {
                'file': f'{remote}/{path.name}', 'folder': folder,
                'license': 'CC0-1.0' if folder == 'donations' else 'CC-BY-4.0',
                'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                'seconds': round(len(audio) / rate, 2),
                'english': round(float(languages.get('en', 0)), 3),
                'accent': labels[int(top[0])],
                'accent_scores': {labels[int(i)]: round(float(scores[i]), 2) for i in top},
                **(corpus.get(name.split('_')[0], {}) if folder == 'vctk' else {}),
                'f0_median_hz': round(float(np.median(f0)), 1) if len(f0) else None,
                'f0_spread_st': round(float(12 * np.log2(np.percentile(f0, 90) / np.percentile(f0, 10))), 1)
                if len(f0) else None,
                **recording_quality(audio, rate),
            }
            names.append(key)
            vectors.append(embed(classifier, audio16))
            print(key, report[key], flush=True)
    np.savez(WORK / 'pool-embeddings.npz', names=np.array(names), vectors=np.array(vectors))
    (ROOT / 'art/audio/voice-pool.json').write_text(json.dumps(report, indent=1, ensure_ascii=False) + '\n')


if __name__ == '__main__':
    main()
