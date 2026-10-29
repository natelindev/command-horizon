"""Campaign content and transcript-normalization contracts, without synthesis."""
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

from xml.etree import ElementTree

from build_campaign_audio import ROOT, SCRIPT, cast, transcript_error
from install_campaign_dialogue import records


class CampaignAudioTests(unittest.TestCase):
    def test_equivalent_spoken_spellings(self):
        self.assertEqual(transcript_error('Cease fire. All guns.', 'Ceasefire, all guns.'), 0)
        self.assertEqual(transcript_error('Drivers have names, Marshal.', 'Drivers have names, Marshall.'), 0)
        self.assertEqual(transcript_error('District nine. After twenty years.',
                                          'District 9. After 20 years.'), 0)
        self.assertGreater(transcript_error('District nine.', 'District 8.'), .1)
        self.assertEqual(transcript_error('Forty people.', '40 people.'), 0)
        self.assertEqual(transcript_error('Wren was still inside.', 'Ren was still inside.'), 0)
        self.assertEqual(transcript_error('Wren, take the wheel.', 'Renn, take the wheel.'), 0)
        self.assertGreater(transcript_error('Wren was still inside.', 'Was still inside.'), .1)
        self.assertEqual(transcript_error('Stop apologizing.', 'Stop apologising.'), 0)
        self.assertGreater(transcript_error('Drivers have names, Marshal. Try asking one.',
                                           'Drivers, try asking.'), .1)

    def test_complete_localized_scene_catalog(self):
        script = json.loads(SCRIPT.read_text())
        scenes = records(script)
        self.assertEqual(len(script['missions']), 16)
        self.assertEqual(len(scenes), 96)
        lines = [line for scene in scenes.values() for line in scene['dialogue']]
        self.assertEqual(len(lines), 160)
        self.assertEqual(len({line['id'] for line in lines}), len(lines))
        for line in lines:
            self.assertTrue(line['en'] and line['zh_CN'])
            self.assertTrue(line['speaker']['en'] and line['speaker']['zh_CN'])
            self.assertTrue(line['voice'].endswith(line['id'] + '.ogg'))
            ElementTree.parse(ROOT / line['portrait'].removeprefix('res://'))
        self.assertIn('bastion_cinder_ford.intro', scenes)
        self.assertNotIn('air_corridor.intro', scenes)
        self.assertIn('first_orders.lab', scenes)
        self.assertIn('command_horizon.command', scenes)

    def test_distinct_reference_cast(self):
        profiles = cast()
        self.assertEqual(len(profiles), 13)
        self.assertEqual(len({p['reference_sha256'] for p in profiles.values()}), 13)
        self.assertTrue(profiles['cantor']['processing']['vocoder_hz'])


if __name__ == '__main__':
    unittest.main()
