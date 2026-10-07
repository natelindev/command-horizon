"""Verify retained recovery evidence; run from any working directory."""
from pathlib import Path
import hashlib
import json
import re
import struct

P = Path(__file__).resolve().parent
ROOT = P.parents[3]

def read(name):
    return json.loads((P / name).read_text())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

runs = read('run-index.json')
assert len(runs) == 15
for run in runs:
    text = (P / run['log']).read_text()
    assert 'SCRIPT ERROR' not in text, run['log']
    count = run['expected_failure_count']
    if count is not None:
        assert f': {count} failures' in text, run['log']
    if run['log'] == 'shortcut-before.log':
        assert 'Missing infantry recovery shortcut' in text
    for line in text.splitlines():
        if not line.startswith('ERROR:'):
            continue
        expected = ['resources still in use at exit', 'RID allocations',
                    'Explicit clearance failed to finish earned uplink',
                    'Explicit capture order did not start', 'Missing infantry recovery shortcut',
                    'Follow-through contact missing',
                    'Infantry stranded when its attack target disappeared en route']
        assert any(item in line for item in expected), (run['log'], line)

outcomes = {}
for name in ['headless', 'rendered', 'followthrough', 'followthrough-rendered']:
    data = read(name + '.json')
    assert data['paid'] == [88.0, 20.0] and data['replacements'] == 0
    assert (data['result'] == 'Victory') == (name != 'headless')
    outcomes[name] = {'result': data['result'], 'elapsed': data['elapsed']}
assert abs(read('headless.json')['control'] - 117.45) < .001
rows = read('headless-audit.json')
last = rows[-1]
actor = next(u for u in last['units'] if u['human'] and u['role'] == 'Infantry')
idle = [(row['time'], next((u for u in row['units'] if u['id'] == actor['id']), None))
        for row in rows if row['time'] > 310.89]
assert len(idle) >= 15
for time, unit in idle:
    assert unit and unit['position'] == actor['position'] and unit['hp'] == 22
    assert unit['order'] == 'none' and unit['action']['kind'] == 'WaitingForTargets.gd'
    assert not unit['observed_enemies']
assert last['relays'][0]['owner'] == 'enemy'
assert abs(last['relays'][0]['progress'] - 5.75) < .001
assert any('attack_move' in u.get('pending', [])
           for row in read('followthrough-audit.json') for u in row['units'])
assert 'capture=false' in (P / 'followthrough-before-valid.log').read_text()
assert 'capture=true elapsed=14.' in (P / 'followthrough-verified.log').read_text()
ui = (P / 'ui.log').read_text()
assert ui.count('CAPTURE SHORTCUT INPUT') == 5
assert ui.count('CAPTURE ORDER right-click') == 1
for name, expected in [('shortcut-final.log', 12.85), ('ui.log', 12.8)]:
    elapsed = float(re.search(r'SHORTCUT RECOVERY elapsed=([\d.]+)', (P / name).read_text())[1])
    assert abs(elapsed - expected) < .001
images = ['ui-found', 'ui-ordered', 'ui-victory', 'ui-barracks', 'ui-no-barracks',
          'followthrough-rendered-loaded', 'followthrough-rendered-result']
for name in images:
    data = (P / (name + '.png')).read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    assert struct.unpack('>II', data[16:24]) == (1280, 720)
assert read('shipping-delta.json') == {
    'changed': ['source/match/campaign/SplitSignalHUD.gd'], 'added': [], 'removed': []}
for name, expected in read('source-hashes.json').items():
    assert digest(ROOT / name) == expected, name
    assert digest(P / ('accepted-' + Path(name).name + '.txt')) == expected
summary = {'status': 'passed', 'classified_runs': len(runs), 'reviewed_images': len(images),
           'idle_samples': len(idle), 'idle_time_range': [idle[0][0], idle[-1][0]],
           'branch_outcomes': outcomes, 'shipping_delta': read('shipping-delta.json')}
(P / 'analysis.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
