"""Regression: renamed/rate-shifted speakers must not masquerade as a new cast."""
import copy
import unittest

from build_battle_audio import clip_source_hash, mechanical
from verify_voice_cast import validate_cast
from voice_cast import PROFILES
import numpy as np


class CastRegression(unittest.TestCase):
    def test_announcer_blend_cannot_voice_unit(self):
        profiles = copy.deepcopy(PROFILES)
        profiles['bastion/Infantry'] = profiles['bastion/Command'].copy()
        with self.assertRaises(AssertionError):
            validate_cast(profiles)

    def test_rate_change_is_not_another_speaker(self):
        profiles = copy.deepcopy(PROFILES)
        profiles['helix/Tank'] = dict(profiles['bastion/Tank'], length_scale=.9)
        with self.assertRaises(AssertionError):
            validate_cast(profiles)

    def test_cast_cache_changes_only_affected_voice(self):
        provenance = {'profiles': copy.deepcopy(PROFILES),
                      'models': {'piper': {'model_sha256': 'piper',
                                          'speaker_ids': {'p311': 38, 'p326': 71, 'p270': 12}},
                                 'kokoro': {'model_sha256': 'kokoro'}}}
        def key(speaker):
            return clip_source_hash('Ready.', speaker, 0, 'select', 0, 'bastion', provenance)
        before = {speaker: key(speaker) for speaker in [None, 'bastion/Command', 'bastion/Infantry', 'helix/Tank']}
        provenance['profiles']['bastion/Infantry']['speaker'] = 'p326'
        del provenance['models']['piper']['speaker_ids']['p311']
        for speaker, old in before.items():
            self.assertEqual(key(speaker) == old, speaker != 'bastion/Infantry')

    def test_machine_designs_have_different_bodies(self):
        # Normalize pitch out of consideration: duration/envelope and timbre are
        # designed separately for each role, not one waveform transposed four ways.
        signals = [mechanical(0, 'select', 0, role, 'bastion')
                   for role in ['Worker', 'RepairRobot', 'CombatRobot', 'Drone']]
        self.assertEqual(len({len(s) for s in signals}), 4)
        for signal in signals:
            self.assertTrue(np.isfinite(signal).all())
            self.assertGreater(np.sqrt(np.mean(signal ** 2)), .02)
        # Heavy combat mechanisms retain low-end energy; drones have high telemetry.
        def low_fraction(signal):
            energy = abs(np.fft.rfft(signal)) ** 2
            return energy[np.fft.rfftfreq(len(signal), 1 / 22050) < 250].sum() / energy.sum()
        self.assertGreater(low_fraction(signals[2]), .5)
        self.assertLess(low_fraction(signals[3]), .1)


if __name__ == '__main__':
    unittest.main()
