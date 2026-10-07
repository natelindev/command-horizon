"""Validate the retained Split Signal environment evidence."""
from pathlib import Path
import hashlib
import json
import struct

P = Path(__file__).resolve().parent
ROOT = P.parents[3]

def read(name):
    return json.loads((P / name).read_text())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

assert read('baseline.json') == read('geometry.json')
geometry = read('geometry.json')
assert len(geometry['blockers']) == 3 and len(geometry['routes']) == 4
for blocker in geometry['blockers']:
    assert blocker['mesh_radius'] <= blocker['radius']
    assert blocker['mesh_height'] <= blocker['sight']
assert read('shipping-delta.json') == {
    'changed': ['source/match/maps/SplitSignalMap.gd', 'source/shaders/3d/split_signal.gdshader'],
    'added': ['source/match/maps/SplitBackdrop.gd'], 'removed': []}
for name, expected in read('source-hashes.json').items():
    assert digest(ROOT / name) == expected, name
    assert digest(P / ('accepted-' + Path(name).name + '.txt')) == expected
for run in read('run-index.json'):
    text = (P / run['log']).read_text()
    if run['classification'] == 'accepted':
        assert 'SCRIPT ERROR' not in text, run['log']
        assert ': 0 failures' in text, run['log']
        for line in text.splitlines():
            if line.startswith('ERROR:'):
                assert 'resources still in use at exit' in line or 'RID allocations' in line, (run['log'], line)
    else:
        assert run['expected_message'] in text, run['log']
results = {}
for name in ['difficulty-0', 'difficulty-1', 'difficulty-2', 'native-veteran']:
    data = read(name + '.json')
    assert data['result'] == 'Victory' and data['errors'] == []
    assert data['control'] >= 120 and data['waves'] <= 6
    results[name] = {key: data[key] for key in ['result', 'time', 'waves', 'human']}
for name in ['shortcut.log', 'recovery-ui.log']:
    assert 'SHORTCUT RECOVERY elapsed=' in (P / name).read_text()
assert (P / 'recovery-ui.log').read_text().count('CAPTURE ORDER right-click') == 1
images = ['after-start', 'after-checkpoint-0', 'after-checkpoint-1', 'after-checkpoint-2',
          'after-station', 'after-boundary', 'after-overview', 'native-veteran-combat',
          'native-veteran-result', 'recovery-ui-found', 'recovery-ui-ordered',
          'recovery-ui-victory', 'recovery-ui-barracks', 'recovery-ui-no-barracks']
for name in images:
    data = (P / (name + '.png')).read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    expected = (1440, 900) if name == 'after-overview' else (1280, 720)
    assert struct.unpack('>II', data[16:24]) == expected
summary = {'status': 'passed', 'classified_runs': len(read('run-index.json')),
           'reviewed_final_images': len(images), 'routes': geometry['routes'], 'matches': results}
(P / 'analysis.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
