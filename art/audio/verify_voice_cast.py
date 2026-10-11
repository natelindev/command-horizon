"""Guard real speaker identities, exclusive announcers and machine variations."""
import json
from pathlib import Path

from voice_cast import ANNOUNCERS, ANNOUNCER_TEXT, CAST, MACHINES, MALE_VOICES, PROFILES

ROOT = Path(__file__).resolve().parents[2]


def validate_cast(profiles):
    metadata = json.loads((ROOT / 'art/audio/vctk-speakers.json').read_text())['speakers']
    commands = set(ANNOUNCERS.values())
    roles = {speaker for faction in CAST.values() for speaker, _ in faction.values()}
    assert set(profiles) == commands | roles
    identities = set()
    for key, profile in profiles.items():
        if key in commands:
            assert profile['engine'] == 'kokoro', key
            assert len(profile['voices']) == 1, key
            voice, weight = next(iter(profile['voices'].items()))
            assert voice in MALE_VOICES and weight == 1, key
            identity = ('kokoro', voice)
        else:
            assert profile['engine'] == 'piper', f'{key} borrows a command voice'
            assert metadata[profile['speaker']]['gender'] == 'M', key
            identity = ('piper', profile['voice'], profile['speaker'])
        # Ignore rate and profile name: those do not make a new speaker.
        assert identity not in identities, f'{key} reuses {identity}'
        identities.add(identity)
    return len(identities)


def verify_catalog():
    assert validate_cast(PROFILES) == 34
    catalog = json.loads((ROOT / 'assets/audio/voices/catalog.json').read_text())
    assert catalog['provenance']['profiles'] == PROFILES
    speaker_map = catalog['provenance']['models']['piper']['speaker_ids']
    assert len(speaker_map) == len(set(speaker_map.values())) == 31
    manifest = json.loads((ROOT / 'art/audio/battle-audio-manifest.json').read_text())
    entries = {e['file']: e for e in manifest}
    used = set()
    mechanical_hashes = set()
    # Every unit uses the same text for stop within its faction: unique rendered
    # hashes guard accidental audio duplication despite distinct metadata.
    stop_hashes = set()
    machines = 0
    for faction, bank in catalog['factions'].items():
        assert set(bank['announcer']) == set(ANNOUNCER_TEXT)
        for role, events in [('Command', bank['announcer']), *bank['units'].items()]:
            expected = ANNOUNCERS[faction] if role == 'Command' else (
                CAST[faction][role][0] if role in CAST[faction] else None)
            for event, variants in events.items():
                for clip in variants if isinstance(variants, list) else [variants]:
                    relative = clip['stream'].removeprefix('res://assets/audio/voices/')
                    assert relative.startswith(f'{faction}/{role}/'), relative
                    entry = entries[relative]
                    assert entry['speaker_id'] == expected, relative
                    assert clip['mechanical'] == (expected is None), relative
                    assert clip['speaker_id'] == (expected or f'machine:{faction}/{role}')
                    used.add(relative)
                    if expected and role != 'Command' and event == 'stop':
                        assert entry['sha256'] not in stop_hashes
                        stop_hashes.add(entry['sha256'])
                    if role in MACHINES and expected is None:
                        assert entry['sha256'] not in mechanical_hashes, relative
                        mechanical_hashes.add(entry['sha256'])
            if role in MACHINES and expected is None:
                machines += 1
                for event in ['select', 'move', 'attack']:
                    assert len(events[event]) >= 2
    assert used == set(entries)
    assert len(stop_hashes) == 31 and machines == 11
    assert len(mechanical_hashes) == 121
    print('PASS 31 unique male unit speakers, three exclusive male announcers, 11 machine identities / 121 distinct cues')


if __name__ == '__main__':
    verify_catalog()
