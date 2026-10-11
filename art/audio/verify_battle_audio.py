"""Decode every shipped battle clip; write a measurement report and listening reel."""
import concurrent.futures
import hashlib
import json
import subprocess
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'docs/playtests/2026-10-11/audio-enhancement'
RATE = 22050


def decode(path):
    result = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le',
                             '-ac', '1', '-ar', str(RATE), '-'], check=True, capture_output=True)
    return np.frombuffer(result.stdout, dtype='<f4')


def inspect(entry):
    path = ROOT / 'assets/audio/voices' / entry['file']
    data = decode(path)
    peak = float(np.max(np.abs(data)))
    rms = float(np.sqrt(np.mean(data * data)))
    assert np.isfinite(data).all() and .03 < len(data) / RATE < 8, path
    assert .01 < peak < .95 and rms > .002, (path, peak, rms)
    assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], path
    return {'file': entry['file'], 'seconds': round(len(data) / RATE, 3),
            'peak_dbfs': round(20 * np.log10(peak), 2),
            'rms_dbfs': round(20 * np.log10(rms), 2)}


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((ROOT / 'art/audio/battle-audio-manifest.json').read_text())
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        report = list(pool.map(inspect, manifest))
    speakers = {entry['speaker_id'] for entry in manifest if entry['speaker_id'] is not None}
    from voice_cast import PROFILES, MALE_VOICES
    assert speakers == set(PROFILES)
    for profile in PROFILES.values():
        assert set(profile['voices']) <= MALE_VOICES
        assert abs(sum(profile['voices'].values()) - 1) < 1e-6
    summary = {'clips': len(report), 'distinct_male_style_profiles': len(speakers),
               'total_seconds': round(sum(item['seconds'] for item in report), 2),
               'highest_peak_dbfs': max(item['peak_dbfs'] for item in report), 'assets': report}
    (ROOT / 'art/audio/battle-audio-verification.json').write_text(json.dumps(summary, indent=2) + '\n')
    reel = []
    cue_sheet = []
    offset = 0.
    for faction in ['bastion', 'helix', 'frontier']:
        for part in ['Command/MATCH_STARTED_0', 'Command/BASE_UNDER_ATTACK_0',
                     'Infantry/select_0', 'Hero/select_0', 'Tank/attack_0',
                     'Worker/select_0', 'CombatRobot/ready_0', 'Drone/select_0',
                     'Command/RESEARCH_COMPLETED_0']:
            relative = f'{faction}/{part}.ogg'
            clip = decode(ROOT / 'assets/audio/voices' / relative)
            entry = next(item for item in manifest if item['file'] == relative)
            cue_sheet.append({'seconds': round(offset, 2), 'clip': relative, 'text': entry['text']})
            reel.extend([clip, np.zeros(int(.45 * RATE), dtype='<f4')])
            offset += len(clip) / RATE + .45
        reel.append(np.zeros(RATE, dtype='<f4'))
        offset += 1
    (DEST / 'audition-cues.json').write_text(json.dumps(cue_sheet, indent=2) + '\n')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1',
                    '-i', '-', '-ac', '2', '-c:a', 'vorbis', '-strict', '-2', '-q:a', '5',
                    str(DEST / 'faction-voice-audition.ogg')], input=np.concatenate(reel).astype('<f4').tobytes(), check=True)
    print(json.dumps({key: value for key, value in summary.items() if key != 'assets'}, indent=2))


if __name__ == '__main__':
    main()
