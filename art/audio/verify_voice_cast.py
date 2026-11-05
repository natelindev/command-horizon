"""Guard real speaker identities, exclusive announcers and robot voice designs."""
import json
from pathlib import Path
from combat_barks import COMBAT_BARKS, combat_text

from robot_voice import ROBOT_VOICES
from voice_cast import (ANNOUNCERS, ANNOUNCER_TEXT, CAST, MALE_VOICES, MERCENARY, MERCENARY_CAST, POOL,
                        PROFILES, ROBOT_CAST, native_accent)

ROOT = Path(__file__).resolve().parents[2]
UNIT_ROLES = sum(len(roles) for roles in CAST.values()) + len(MERCENARY_CAST)
ROBOT_ROLES = sum(len(roles) for roles in ROBOT_CAST.values())


def validate_cast(profiles):
    commands = set(ANNOUNCERS.values())
    units = {speaker for faction in [*CAST.values(), MERCENARY_CAST] for speaker, _ in faction.values()}
    robots = {speaker for faction in ROBOT_CAST.values() for speaker, _ in faction.values()}
    assert set(profiles) == commands | units | robots
    references = {info['sha256']: info for info in POOL.values()}
    identities = set()
    for key, profile in profiles.items():
        if key in commands:
            assert profile['engine'] == 'kokoro', key
            assert len(profile['voices']) == 1, key
            voice, weight = next(iter(profile['voices'].items()))
            assert voice in MALE_VOICES and weight == 1, key
            identity = ('kokoro', voice)
        else:
            assert profile['engine'] == 'chatterbox', f'{key} borrows a command voice'
            assert profile.get('robot', False) == (key in robots), key
            info = references[profile['reference_sha256']]
            assert info['english'] >= .9 and info['snr_db'] >= 30, key
            if key in units:
                # Native crew: reported/classified accent and the reference's median pitch.
                assert native_accent(info), f'{key} is not a native English speaker'
                if key == 'helix/Hero':
                    assert info.get('gender') == 'F', 'Nyx requires a female reference voice'
                if info.get('gender') == 'F':
                    assert 160 <= info['f0_median_hz'] <= 260, key
                else:
                    assert 75 <= info['f0_median_hz'] <= 160, key
            else:
                assert key in ROBOT_VOICES, f'{key} has no robot voice design'
            identity = ('reference', profile['reference_sha256'])
        # Ignore delivery and profile name: those do not make a new speaker.
        assert identity not in identities, f'{key} reuses {identity}'
        identities.add(identity)
    designs = [json.dumps(ROBOT_VOICES[key], sort_keys=True) for key in robots]
    assert len(set(designs)) == len(designs), 'Two robots share one voice design'
    return len(identities)


def verify_catalog():
    assert validate_cast(PROFILES) == len(ANNOUNCERS) + UNIT_ROLES + ROBOT_ROLES == 54
    catalog = json.loads((ROOT / 'assets/audio/voices/catalog.json').read_text())
    assert catalog['provenance']['profiles'] == PROFILES
    assert catalog['provenance']['robot_voices'] == json.loads(json.dumps(ROBOT_VOICES))
    manifest = json.loads((ROOT / 'art/audio/battle-audio-manifest.json').read_text())
    entries = {e['file']: e for e in manifest}
    used = set()
    # Units share their faction's stop text: unique rendered hashes guard accidental audio
    # duplication despite distinct metadata.
    stop_hashes = set()
    robots = 0
    # Mercenaries are voiced once, never per army: the same hire keeps one identity.
    assert set(catalog['mercenaries']) == set(MERCENARY_CAST)
    banks = [(faction, bank['announcer'], bank['units']) for faction, bank in catalog['factions'].items()]
    for faction, announcer, units in banks + [(MERCENARY, None, catalog['mercenaries'])]:
        if announcer is None:
            speakers = {role: speaker for role, (speaker, _) in MERCENARY_CAST.items()}
            sections = []
        else:
            assert set(announcer) == set(ANNOUNCER_TEXT)
            assert not set(units) & set(MERCENARY_CAST), f'{faction} recasts a mercenary'
            speakers = {role: speaker for role, (speaker, _)
                        in {**CAST[faction], **ROBOT_CAST[faction]}.items()}
            sections = [('Command', announcer)]
        for role, events in [*sections, *units.items()]:
            expected = ANNOUNCERS[faction] if role == 'Command' else speakers.get(role)
            robotic = role in ROBOT_CAST.get(faction, {})
            for event, variants in events.items():
                for clip in variants if isinstance(variants, list) else [variants]:
                    relative = clip['stream'].removeprefix('res://assets/audio/voices/')
                    assert relative.startswith(f'{faction}/{role}/'), relative
                    entry = entries[relative]
                    assert entry['speaker_id'] == expected, relative
                    assert clip['mechanical'] == (expected is None), relative
                    assert clip['robotic'] == robotic, relative
                    assert clip['speaker_id'] == (expected or f'machine:{faction}/{role}')
                    if expected in ANNOUNCERS.values():
                        assert entry['qc']['engine'] == 'kokoro', relative
                    elif expected:
                        assert not clip['text'].startswith('['), relative
                        assert not entry['qc'].get('rejected'), relative
                        assert entry['qc']['word_error'] <= PROFILES[expected]['max_word_error'], relative
                    used.add(relative)
                    if expected and role != 'Command' and event == 'stop':
                        assert entry['sha256'] not in stop_hashes
                        stop_hashes.add(entry['sha256'])
            if robotic:
                robots += 1
                for event in ['select', 'move', 'attack']:
                    assert len(events[event]) >= 2
    assert used == set(entries)
    combat_hashes = set()
    existing_hashes = {entry['sha256'] for path, entry in entries.items()
                       if Path(path).stem.rsplit('_', 1)[0] not in {'low_health', 'kill'}}
    for faction, roles in COMBAT_BARKS.items():
        bank = catalog['mercenaries'] if faction == MERCENARY else catalog['factions'][faction]['units']
        for role in roles:
            for event, text in combat_text(faction, role).items():
                clips = bank[role][event]
                assert len(clips) == 1 and clips[0]['text'] == text, (faction, role, event)
                entry = entries[f'{faction}/{role}/{event}_0.ogg']
                assert entry['sha256'] not in combat_hashes, (faction, role, event)
                assert entry['sha256'] not in existing_hashes, (faction, role, event, 'borrowed recording')
                combat_hashes.add(entry['sha256'])
    assert len(combat_hashes) == 80
    assert len(stop_hashes) == UNIT_ROLES + ROBOT_ROLES and robots == ROBOT_ROLES
    print(f'PASS {UNIT_ROLES} distinct unit voices ({len(MERCENARY_CAST)} shared mercenaries), '
          f'{ROBOT_ROLES} distinct robot voices, three exclusive announcers, '
          f'every spoken clip transcription-checked')


if __name__ == '__main__':
    verify_catalog()
