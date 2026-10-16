"""Assemble localized campaign scene records; install only complete, verified voice builds."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ALIASES = {'supply_line': 'checkpoint', 'first_orders': 'lab', 'split_signal': 'network',
           'broken_foundry': 'node', 'command_horizon': 'deployment'}
SECOND = {'first_orders': 'relay', 'broken_foundry': 'control', 'command_horizon': 'command'}


def records(script):
    result = {}
    for mission in script['missions']:
        mid = mission['legacy_mission_id'] or mission['id'].replace('.', '_')
        if mission['id'] == 'bastion.cinder_ford':
            mid = 'bastion_cinder_ford'
        for scene in mission['scenes']:
            trigger = scene['trigger']
            if trigger == 'milestone':
                trigger = ALIASES.get(mid, trigger)
            elif trigger == 'stage_2':
                trigger = SECOND.get(mid, trigger)
            lines = []
            for line in scene['lines']:
                actor = script['cast'][line['speaker']]
                lines.append(dict(id=line['id'], speaker={'en': actor['name'], 'zh_CN': actor['zh_CN']},
                                  en=line['en'], zh_CN=line['zh_CN'],
                                  voice='res://assets/audio/campaign/dialogue/'+line['id']+'.ogg',
                                  portrait='res://assets/ui/campaign/'+line['speaker']+'.svg'))
            result[mid+'.'+trigger] = {'dialogue': lines}
    return result


def main():
    script = json.loads((ROOT/'docs/plans/hero-campaign-dialogue.json').read_text())
    manifest = {entry['id']: entry for entry in json.loads((ROOT/'art/audio/campaign-audio-manifest.json').read_text())}
    audit = json.loads((ROOT/'art/audio/campaign-audio-verification.json').read_text())
    expected = sum(len(scene['lines']) for mission in script['missions'] for scene in mission['scenes'])
    assert not audit['failures'] and audit['clips'] == audit['expected'] == expected
    verified = {item['id']: item['sha256'] for item in audit['assets']}
    scenes = records(script)
    for scene in scenes.values():
        for line in scene['dialogue']:
            record = manifest[line['id']]
            assert record['text'] == line['en'] and record['qc']['word_error'] <= .1
            assert (ROOT/record['file']).is_file(), record['file']
            assert hashlib.sha256((ROOT/record['file']).read_bytes()).hexdigest() == verified[line['id']]
            assert (ROOT/line['portrait'].removeprefix('res://')).is_file(), line['portrait']
    (ROOT/'assets/audio/campaign/conversations.json').write_text(json.dumps(scenes,ensure_ascii=False,indent=2)+'\n')
    print('Installed',len(scenes),'complete campaign conversations')


if __name__ == '__main__':
    main()
