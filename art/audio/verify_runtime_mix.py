"""Measure and transcribe the real three-faction runtime audio capture.

Keeps lossless audition copies, validates actual event/duck/stem traces and tests
recognition against the captions emitted by the running game. This is an objective
signal/intelligibility audit, not a subjective listening or musical-style review.
"""
import argparse
import hashlib
import json
import math
import subprocess
import sys
from pathlib import Path

import librosa
import numpy as np
import pyloudnorm
import soundfile as sf
from scipy.signal import correlate

from build_battle_audio import GLOSSARY, transcript_error

ROOT = Path(__file__).resolve().parents[2]
BUSES = ('master', 'music', 'voice', 'effects', 'ambience')


def measure(data, rate):
    peak = float(np.abs(data).max())
    rms = float(np.sqrt(np.mean(data * data)))
    return dict(seconds=round(len(data) / rate, 4), channels=data.shape[1],
                sample_rate=rate, peak_dbfs=round(20 * math.log10(max(peak, 1e-12)), 3),
                rms_dbfs=round(20 * math.log10(max(rms, 1e-12)), 3),
                integrated_lufs=round(pyloudnorm.Meter(rate).integrated_loudness(data), 3),
                clipped_samples=int(np.count_nonzero(np.abs(data) >= .99999)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True, help='Runtime capture directory with runtime-mixes.json')
    parser.add_argument('--output', type=Path, required=True, help='Audition and JSON report directory')
    parser.add_argument('--cpu-threads', type=int, default=3)
    parser.add_argument('--require-score-streams', action='store_true',
                        help='Require current live synchronized-stream metadata; omit for historical captures')
    args = parser.parse_args()
    source = args.input
    args.output.mkdir(parents=True, exist_ok=True)
    trace_path = source / 'runtime-mixes.json'
    traces = json.loads(trace_path.read_text())
    # Capture stops on an audio mix-block boundary, which can be a few
    # milliseconds before/after the nominal 26-second process deadline.
    # Audit only the actual common frames; never pad or invent a quiet tail.
    infos = [sf.info(source / f'{faction}-{bus}.wav')
             for faction in ('bastion','helix','frontier') for bus in BUSES]
    if not all(info.samplerate == 44100 and info.frames / info.samplerate >= 25.9 for info in infos):
        raise ValueError('Capture is shorter than the complete 26-second scenario or has an unexpected sample rate')
    common_frames = min(info.frames for info in infos)
    common_seconds = common_frames / 44100
    cache_path = ROOT / 'tmp/voice-work/runtime-mix-transcripts.json'
    cache = json.loads(cache_path.read_text()) if cache_path.exists() else {}
    asr = None
    failures = []
    report = dict(common_seconds=round(common_seconds,9), subjective_listening_performed=False,
                  musical_style_acceptance='Requires listener review of the retained audition artifacts',
                  capture_trace_sha256=hashlib.sha256(trace_path.read_bytes()).hexdigest(), factions={})
    for faction in ('bastion', 'helix', 'frontier'):
        trace = traces[faction]
        live_streams = trace.get('score_streams', [])
        streams_valid = False
        track = {'bastion':'hold-the-line','helix':'perfect-compliance','frontier':'no-shutdown-code'}[faction]
        expected = ['res://assets/audio/music/'+track+'-'+part+'.ogg' for part in ('calm','tension','combat')]
        if live_streams:
            paths = [stream.get('path') for stream in live_streams]
            lengths = [float(stream.get('seconds',0)) for stream in live_streams]
            streams_valid = paths == expected and all(math.isfinite(value) and value>150 for value in lengths) and max(lengths)-min(lengths) < .01
            if not streams_valid:
                failures.append(f'{faction}: incorrect live synchronized score streams')
        elif args.require_score_streams:
            failures.append(f'{faction}: current live score-stream metadata is required')
        buses, measurements = {}, {}
        for bus in BUSES:
            path = source / f'{faction}-{bus}.wav'
            data, rate = sf.read(path, dtype='float64', always_2d=True)
            if rate != 44100 or len(data) < common_frames or not np.isfinite(data).all():
                raise ValueError(f'Invalid or incomplete capture: {path}')
            data = data[:common_frames]
            buses[bus] = data
            measurements[bus] = measure(data, rate)
            if measurements[bus]['clipped_samples']:
                failures.append(f'{faction}/{bus}: clipped samples')
            encoded = args.output / f'{faction}-{bus}.flac'
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(path), '-t', f'{common_seconds:.9f}',
                            '-c:a', 'flac', str(encoded)], check=True)
            measurements[bus]['sha256'] = hashlib.sha256(encoded.read_bytes()).hexdigest()
        samples = trace['samples']
        state = dict(actual_shots=trace['actual_shots'], peak_intensity=max(s['intensity'] for s in samples),
                     final_intensity=samples[-1]['intensity'],
                     minimum_duck_db=min(s['speech_duck_db'] for s in samples),
                     final_duck_db=samples[-1]['speech_duck_db'],
                     stem_peak_db=[max(s['stem_db'][i] for s in samples) for i in range(3)])
        if not (state['actual_shots'] > 0 and state['peak_intensity'] > .7
                and state['final_intensity'] < state['peak_intensity'] and state['minimum_duck_db'] == -3
                and state['final_duck_db'] == 0 and all(v > -3 for v in state['stem_peak_db'])):
            failures.append(f'{faction}: missing expected live intensity/stem/duck behavior')
        speech = []
        for event in (e for e in trace['timeline'] if e['event'] == 'voice'):
            clip, clip_rate = sf.read(ROOT / event['stream'].removeprefix('res://'), always_2d=True)
            reference = librosa.resample(clip.mean(axis=1), orig_sr=clip_rate, target_sr=rate)
            nominal = float(event['seconds'])
            search_start = max(0, int((nominal - .4) * rate))
            search_stop = min(len(buses['voice']), int((nominal + len(reference) / rate + .6) * rate))
            voice_search = buses['voice'][search_start:search_stop].mean(axis=1)
            correlation = correlate(voice_search, reference, mode='valid', method='fft')
            offset = int(np.argmax(correlation))
            actual_start = search_start + offset
            actual_end = actual_start + len(reference)
            delivered = buses['voice'][actual_start:actual_end].mean(axis=1)
            similarity = float(delivered @ reference / max(np.linalg.norm(delivered) * np.linalg.norm(reference), 1e-12))
            segment_start = max(0, actual_start - int(.15 * rate))
            segment_end = min(len(buses['master']), actual_end + int(.25 * rate))
            master = buses['master'][segment_start:segment_end].mean(axis=1)
            key = hashlib.sha256(master.astype('<f4').tobytes() + b'medium.en/runtime-mix-v1').hexdigest()
            heard = cache.get(key)
            if heard is None:
                if asr is None:
                    import torch
                    import whisper
                    torch.set_num_threads(max(1, args.cpu_threads))
                    asr = whisper.load_model('medium.en', device='cpu')
                audio16 = librosa.resample(master.astype(np.float32), orig_sr=rate, target_sr=16000)
                heard = asr.transcribe(audio16, language='en', fp16=False, temperature=0,
                                       initial_prompt=GLOSSARY)['text'].strip()
                cache[key] = heard
                cache_path.write_text(json.dumps(cache, ensure_ascii=False) + '\n')
            error = transcript_error(event['text'], heard)
            voice_window = buses['voice'][actual_start:actual_end]
            background = sum(buses[b][actual_start:actual_end] for b in ('music', 'effects', 'ambience'))
            voice_to_background = 10 * math.log10(max(float(np.mean(voice_window**2)), 1e-12)
                                                 / max(float(np.mean(background**2)), 1e-12))
            item = dict(text=event['text'], heard=heard, word_error=round(error, 4),
                        seconds=round(actual_start / rate, 4), source=event['stream'],
                        source_correlation=round(similarity, 4),
                        voice_to_background_rms_db=round(voice_to_background, 3))
            speech.append(item)
            print(f'{faction}: {heard} (word error {error:.3f}, correlation {similarity:.3f})', file=sys.stderr, flush=True)
            if error > .25:
                failures.append(f'{faction}: {event["text"]!r} recognition below contract')
        if len(speech) != 3:
            failures.append(f'{faction}: expected low-hull, announcement and kill speech')
        report['factions'][faction] = dict(buses=measurements, live_state=state, speech=speech,
                                                  live_score_streams=live_streams,
                                                  live_score_streams_verified=streams_valid)
    report['failures'] = failures
    (args.output / 'runtime-mixes.json').write_bytes(trace_path.read_bytes())
    (args.output / 'verification.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps(dict(factions=len(traces), spoken_events=sum(len(f['speech']) for f in report['factions'].values()),
                          failures=failures, report=str(args.output / 'verification.json'))))
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
