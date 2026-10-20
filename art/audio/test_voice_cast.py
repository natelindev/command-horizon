"""Regression: renamed/re-delivered speakers must not masquerade as a new cast."""
import copy
import unittest

import numpy as np
from build_battle_audio import clip_source_hash, mechanical, transcript_error
from radio_voice import UNIT_CLASS, radio
from robot_voice import ROBOT_VOICES, robot_voice
from verify_voice_cast import validate_cast
from voice_cast import CAST, MERCENARY_CAST, PROFILES

RATE = 24000


def speechlike(seconds=1.2):
    """Deterministic voiced signal with moving formants and a fricative burst."""
    t = np.arange(int(RATE * seconds)) / RATE
    f0 = 120 + 25 * np.sin(2 * np.pi * 1.5 * t)
    phase = 2 * np.pi * np.cumsum(f0) / RATE
    voice = sum(np.sin(k * phase) / k * (1 + np.sin(2 * np.pi * (k * f0) / (700 + 400 * np.sin(3 * t))))
                for k in range(1, 30))
    voice *= np.clip(np.sin(np.pi * t / seconds) * 3, 0, 1)
    voice[int(.8 * RATE):int(.9 * RATE)] += np.random.default_rng(1).normal(0, .4, int(.1 * RATE))
    return voice / np.max(np.abs(voice)) * .5


class CastRegression(unittest.TestCase):
    def test_announcer_cannot_voice_unit(self):
        profiles = copy.deepcopy(PROFILES)
        profiles['bastion/Infantry'] = profiles['bastion/Command'].copy()
        with self.assertRaises(AssertionError):
            validate_cast(profiles)

    def test_delivery_change_is_not_another_speaker(self):
        profiles = copy.deepcopy(PROFILES)
        profiles['helix/Tank'] = dict(profiles['bastion/Tank'], max_word_error=.1)
        with self.assertRaises(AssertionError):
            validate_cast(profiles)

    def test_robot_cannot_reuse_unit_voice(self):
        profiles = copy.deepcopy(PROFILES)
        profiles['helix/Drone'] = dict(profiles['helix/Infantry'], robot=True)
        with self.assertRaises(AssertionError):
            validate_cast(profiles)

    def test_cast_cache_changes_only_affected_voice(self):
        provenance = {'profiles': copy.deepcopy(PROFILES),
                      'models': {'chatterbox': {'engine': 'chatterbox'}, 'kokoro': {'model_sha256': 'k'}}}

        def key(speaker):
            return clip_source_hash('Ready.', speaker, 0, 'select', 0, 'bastion', provenance)
        speakers = [None, 'bastion/Command', 'bastion/Infantry', 'helix/Tank', 'bastion/Drone']
        before = {speaker: key(speaker) for speaker in speakers}
        provenance['profiles']['bastion/Infantry']['reference_sha256'] = 'recast'
        for speaker, old in before.items():
            self.assertEqual(key(speaker) == old, speaker != 'bastion/Infantry')

    def test_robot_design_change_rerenders_only_that_robot(self):
        provenance = {'profiles': PROFILES, 'models': {'chatterbox': {'engine': 'chatterbox'},
                                                       'kokoro': {'model_sha256': 'k'}}}
        speakers = ['bastion/Drone', 'helix/Drone', 'bastion/Infantry']

        def key(speaker):
            return clip_source_hash('Ready.', speaker, 0, 'select', 0, speaker.split('/')[0], provenance)
        before = {speaker: key(speaker) for speaker in speakers}
        original = ROBOT_VOICES['bastion/Drone']
        ROBOT_VOICES['bastion/Drone'] = dict(original, crush_bits=8)
        try:
            for speaker, old in before.items():
                self.assertEqual(key(speaker) == old, speaker != 'bastion/Drone')
        finally:
            ROBOT_VOICES['bastion/Drone'] = original

    def test_every_crew_role_has_radio_and_mercenaries_one_voice(self):
        # Every crewed role is colored by its own class; a hired mercenary is one person in
        # every army rather than a per-faction recast.
        for faction, roles in CAST.items():
            for role in roles:
                self.assertIn(role, UNIT_CLASS, role)
                self.assertNotIn(role, MERCENARY_CAST, faction)
        for role, (speaker, _) in MERCENARY_CAST.items():
            self.assertIn(role, UNIT_CLASS)
            self.assertEqual(speaker, 'mercenary/' + role)
            self.assertFalse(any(key.endswith('/' + role) and key != speaker for key in PROFILES))

    def test_transcript_error_is_word_level(self):
        self.assertEqual(transcript_error('Rifles up. Engage!', 'rifles up, engage'), 0)
        self.assertGreater(transcript_error('Rocket away!', 'Rocket away. Over and out.'), .3)
        self.assertGreater(transcript_error('Tracks rolling.', 'Tracks.'), .3)
        self.assertEqual(transcript_error("Outrider! Engine's screaming!", 'Outrider, engine screaming.'), 0)
        self.assertGreater(transcript_error("Fine! We'll wait!", 'Fine, we wait.'), .3)
        self.assertEqual(transcript_error('Make them run!', "Make 'em run."), 0)

    def test_transcript_join_does_not_hide_word_errors(self):
        self.assertEqual(transcript_error('Dust storm! Eat it!', 'Duststorm. Eat it!'), 0)
        self.assertGreater(transcript_error('Dust storm! Eat it!', 'Duststorm. Eat!'), .25)
        self.assertGreater(transcript_error('Dust storm! Eat it!', 'Hailstorm. Eat it!'), .25)
        self.assertEqual(transcript_error('Route set! Full speed!', 'Rootset, Full Speed.'), .25)
        self.assertGreater(transcript_error('Route set! Full speed!', 'Root, full speed.'), .25)
        self.assertGreater(transcript_error('Route set! Full speed!', 'Rootset, full.'), .25)
        self.assertGreater(transcript_error('Route set! Full speed!', 'Wrong path! Full speed!'), .25)

    def test_robot_designs_sound_different(self):
        # One voice through every design: each robot must be its own machine, not a
        # loudness/pitch variant, and must keep consonant energy for intelligibility.
        voice = speechlike()

        def profile(audio):
            spectrum = np.abs(np.fft.rfft(audio[:len(voice)], n=8192)) ** 2
            bands = np.add.reduceat(spectrum, np.geomspace(20, 4096, 25).astype(int))
            return np.log10(bands / bands.sum() + 1e-12)
        dry = profile(voice)
        profiles = {}
        for key, design in ROBOT_VOICES.items():
            out = robot_voice(voice, RATE, design)
            self.assertTrue(np.isfinite(out).all(), key)
            self.assertGreater(np.abs(profile(out) - dry).mean(), .15, f'{key} is barely processed')
            profiles[key] = profile(out)
        keys = list(profiles)
        for i, a in enumerate(keys):
            for b in keys[i + 1:]:
                self.assertGreater(np.abs(profiles[a] - profiles[b]).mean(), .1, f'{a} ~ {b}')

    def test_radio_colours_without_muffling(self):
        # Field comms must be audible as comms yet keep consonant energy: a narrow, muffled
        # radio (the original complaint) loses most energy above 4 kHz.
        voice = speechlike()

        def air(audio):
            spectrum = np.abs(np.fft.rfft(audio)) ** 2
            freqs = np.fft.rfftfreq(len(audio), 1 / RATE)
            return spectrum[freqs > 4000].sum() / spectrum.sum()
        for faction in ['bastion', 'helix', 'frontier', 'mercenary']:
            for role in UNIT_CLASS:
                out = radio(voice, RATE, faction, role)
                self.assertTrue(np.isfinite(out).all())
                self.assertGreater(np.abs(out - voice).mean(), .01 * np.abs(voice).mean(), role)
                self.assertGreater(air(out), .35 * air(voice), f'{faction}/{role} is muffled')

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
