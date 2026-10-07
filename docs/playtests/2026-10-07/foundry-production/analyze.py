"""Verify retained Foundry production evidence and source provenance."""
from pathlib import Path
from collections import Counter
import hashlib
import json
import struct

P = Path(__file__).resolve().parent
ROOT = P.parents[3]

def read(name):
    return json.loads((P / name).read_text())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

for name, expected in read('source-hashes.json').items():
    assert digest(ROOT / name) == expected, name
    assert digest(P / ('accepted-' + Path(name).name + '.txt')) == expected
assert read('shipping-delta.json') == {
    'changed': ['source/match/campaign/BrokenFoundry.gd',
                'source/match/campaign/BrokenFoundryHUD.gd'], 'added': [], 'removed': []}
legacy = read('legacy.json')
assert len(legacy['errors']) == 3
old = legacy['reports'][0]
assert old['mission_source_sha256'] == digest(P / 'original-mission.gd')
assert digest(P / 'original-mission.gd') == digest(P / 'before-BrokenFoundry.gd.txt')
assert old['paid'] == old['completed'] == [8, 8]
assert old['funds'] == [248, 76] and old['peak'] == [5, 5]
after = read('after.json')
assert not after['errors']
for report in after['reports']:
    count = 3 * (report['difficulty'] + 1)
    assert report['paid'] == report['completed'] == [count, count]
    assert report['funds'] == [600 - 2 * count * 22, 300 - 2 * count * 14]
    assert max(report['peak']) <= 5
verified = read('verified-budget.json')
assert not verified['errors']
new = verified['reports'][0]
assert new['mission_source_sha256'] == digest(ROOT / 'source/match/campaign/BrokenFoundry.gd')
assert new['paid'] == new['completed'] == [9, 9]
assert new['funds'] == [204, 48] and new['peak'] == [5, 5]
batches = Counter((e['node'], e['time']) for e in new['events'] if e['kind'] == 'paid')
assert len(batches) == 6 and set(batches.values()) == {3}
restores = read('restores.json')
assert not restores['errors']
assert [(r['tanks'],r['funds']) for r in restores['reports']] == [(18,[248,76]),(20,[204,48])]
runs = read('run-index.json')
for run in runs:
    log = (P / run['log']).read_text()
    kind = run['classification']
    if kind == 'rejected parse fixture':
        assert 'SCRIPT ERROR: Parse Error' in log
        continue
    assert 'SCRIPT ERROR' not in log, run['log']
    if kind == 'expected old-code failure':
        assert ': 3 failures' in log
    elif kind in ['accepted', 'superseded tooltip fixture']:
        assert ': 0 failures' in log, run['log']
        for line in log.splitlines():
            if line.startswith('ERROR:'):
                assert 'resources still in use at exit' in line or 'RID allocations' in line
    else:
        assert kind in ['interrupted baseline', 'retained unsuccessful route']
hover = (P/'hover.log').read_text()
assert hover.count('FOUNDRY BATCH UI ') == 6
matches = {}
for name in ['native-veteran','delayed-veteran']:
    data=read(name+'.json')
    if not data['errors']:
        assert data['result'] == 'Victory' and data['hold'] == 30
        assert data['resources'] == [136,80] and data['response_done']
        assert all(n['disabled'] for n in data['nodes'])
    else:
        assert (P/(name+'-archive.json')).exists()
    if name == 'delayed-veteran':
        assert all(n['batches'] == 3 for n in data['nodes'])
    matches[name] = {k:data[k] for k in ['result','time','human','infantry','nodes','errors']}
images = ['hover-'+s for s in ['queue-wait','loaded','resumed','funds-needed','lab-required','unit-limit']]
images += ['native-veteran-foundry-'+s for s in ['node-0','node-1','live-result']]
for name in images:
    data=(P/(name+'.png')).read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    assert struct.unpack('>II',data[16:24]) == (1280,720)
summary={'status':'passed','classified_runs':len(runs),'reviewed_images':len(images),
         'old_completed':old['completed'],'new_completed':new['completed'],
         'current_source_sha256':new['mission_source_sha256'],'matches':matches}
(P/'analysis.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
