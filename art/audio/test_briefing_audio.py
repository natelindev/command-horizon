"""Briefing cache, script identity and natural narration pacing contracts."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from build_briefing_audio import pacing, render_hash, script_records, source_hash, spoken_phrases


class BriefingAudioRegression(unittest.TestCase):
    def fixture(self):
        return dict(mission_id='test_operation', faction='bastion', speaker='aegis',
            segments=[dict(id='test_%d'%i,en=' '.join(['Advance']*25),zh='向前推进。') for i in range(4)])

    def validate(self, missions):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'script.json'
            path.write_text(json.dumps(missions))
            return script_records(path)

    def test_bilingual_script_and_stable_commander(self):
        missions=[self.fixture()]
        self.assertEqual(self.validate(missions),missions)
        missions[0]['speaker']='nyx'
        with self.assertRaises(ValueError):self.validate(missions)

    def test_captions_do_not_rerender_accepted_english_audio(self):
        mission=self.fixture();line=mission['segments'][0];profile={'reference_sha256':'original'}
        original=source_hash(mission,line,profile)
        line['zh']='修订后的中文字幕。'
        self.assertEqual(source_hash(mission,line,profile),original)
        line['en']='A different route requires a different recording.'
        self.assertNotEqual(source_hash(mission,line,profile),original)
        line=mission['segments'][1]
        before=source_hash(mission,line,profile)
        profile['reference_sha256']='recast'
        self.assertNotEqual(source_hash(mission,line,profile),before)

    def test_duplicate_and_unsafe_segment_ids_are_rejected(self):
        for bad_id in ['test_0','../outside','/absolute']:
            mission=self.fixture();mission['segments'][1]['id']=bad_id
            with self.assertRaises(ValueError):self.validate([mission])

    def test_missing_caption_and_overlong_paragraph_are_rejected(self):
        for field,value in [('zh',''),('en',' '.join(['Advance']*41))]:
            mission=self.fixture();mission['segments'][0][field]=value
            with self.assertRaises(ValueError):self.validate([mission])

    def test_duplicate_mission_is_rejected(self):
        mission=self.fixture()
        with self.assertRaises(ValueError):self.validate([mission,copy.deepcopy(mission)])

    def test_normal_performance_preserves_original_tempo(self):
        self.assertEqual(pacing(48.,4,'normal'),1.)

    def test_mild_pacing_keeps_the_entire_script_within_the_duration(self):
        for seconds in [35.,40.,57.,63.]:
            tempo=pacing(seconds,4,'paced')
            self.assertGreaterEqual(tempo,.8);self.assertLessEqual(tempo,1.15)
            self.assertGreaterEqual(seconds/tempo+4,45.)
            self.assertLessEqual(seconds/tempo+4,60.)

    def test_short_complete_performance_can_use_authored_paragraph_rests(self):
        with self.assertRaises(ValueError):pacing(32.2,4,'short')
        tempo=pacing(32.2,4,'short',1.25)
        self.assertGreaterEqual(tempo,.8)
        self.assertGreaterEqual(32.2/tempo+5,45.)
        self.assertLessEqual(32.2/tempo+5,60.)
        mission=self.fixture();line=mission['segments'][0];profile={}
        speech=source_hash(mission,line,profile);encoded=render_hash(mission,line,profile)
        mission['paragraph_breath_seconds']=1.25
        self.assertEqual(source_hash(mission,line,profile),speech)
        self.assertNotEqual(render_hash(mission,line,profile),encoded)
        self.assertEqual(self.validate([mission]),[mission])
        mission['paragraph_breath_seconds']=5
        with self.assertRaises(ValueError):self.validate([mission])

    def test_extreme_retiming_requires_a_script_adjustment(self):
        for seconds in [20.,75.]:
            with self.assertRaises(ValueError):pacing(seconds,4,'rewrite')

    def test_phrase_takes_preserve_every_authored_word_and_punctuation(self):
        text=('Escort the relief vehicles along the marked road. Clear each ambush before '
              'the drivers advance, and keep repair crews close enough to reach damaged armor.')
        phrases=spoken_phrases(text)
        self.assertEqual(' '.join(phrases),text)
        self.assertEqual(len(phrases),3)
        self.assertTrue(all(5 <= len(phrase.split()) <= 16 for phrase in phrases))

    def test_pacing_changes_reuse_the_accepted_voice_takes(self):
        mission=self.fixture();line=mission['segments'][0];profile={'reference_sha256':'original'}
        speech=source_hash(mission,line,profile);encoded=render_hash(mission,line,profile)
        with patch('build_briefing_audio.PACING_REVISION',99):
            self.assertEqual(source_hash(mission,line,profile),speech)
            self.assertNotEqual(render_hash(mission,line,profile),encoded)


if __name__=='__main__':unittest.main()
