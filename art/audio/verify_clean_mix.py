"""Regression checks for male casting and quiet, low-hiss ambience assets."""
import json
from pathlib import Path

import numpy as np
import soundfile as sf

from voice_cast import CAST, ANNOUNCERS, PROFILES, MALE_VOICES

ROOT = Path(__file__).resolve().parents[2]


def main():
    profiles = list(ANNOUNCERS.values()) + [speaker for roles in CAST.values()
                                           for speaker, _ in roles.values()]
    assert len(profiles) == len(set(profiles)) == 34
    assert set(profiles) == set(PROFILES)
    signatures = set()
    for key, profile in PROFILES.items():
        assert set(profile['voices']) <= MALE_VOICES, key
        assert all(name.startswith(('am_', 'bm_')) for name in profile['voices']), key
        assert abs(sum(profile['voices'].values()) - 1) < 1e-6, key
        signatures.add(json.dumps(profile, sort_keys=True))
    assert len(signatures) == 34
    catalog = json.loads((ROOT / 'assets/audio/voices/catalog.json').read_text())
    assert catalog['provenance']['profiles'] == PROFILES
    speech_count = 0
    for faction in catalog['factions'].values():
        clips = list(faction['announcer'].values())
        clips += [line for role in faction['units'].values() for variants in role.values()
                  for line in variants]
        for line in clips:
            if not line['mechanical']:
                info = sf.info(ROOT / line['stream'].removeprefix('res://'))
                assert info.samplerate == 24000, line
                speech_count += 1
    assert speech_count == 302
    for region in ['desert', 'alpine', 'industrial', 'coastal']:
        data, rate = sf.read(ROOT / f'assets/audio/environment/{region}.wav')
        rms_db = 10 * np.log10(np.mean(data * data))
        spectrum = np.fft.rfft(data, axis=0)
        spectrum[np.fft.rfftfreq(len(data), 1 / rate) < 2000] = 0
        hiss = np.fft.irfft(spectrum, n=len(data), axis=0)
        hiss_db = 10 * np.log10(np.mean(hiss * hiss))
        assert rms_db <= -23.9, (region, rms_db)
        assert hiss_db <= -46.5, (region, hiss_db)
    print('PASS 34 distinct male-only profiles, 302 full-band speech clips, four quiet low-hiss beds')


if __name__ == '__main__':
    main()
