"""Check retained Foundry feedback evidence against current source."""
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

for name, expected in read('source-hashes.json').items():
    assert digest(ROOT / name) == expected, name
    assert digest(P / ('accepted-' + Path(name).name + '.txt')) == expected
assert read('shipping-delta.json') == {
    'changed': ['source/match/campaign/BrokenFoundry.gd',
                'source/match/campaign/BrokenFoundryHUD.gd',
                'source/match/objectives/FoundryControl.gd'], 'added': [], 'removed': []}
for run in read('run-index.json'):
    text = (P / run['log']).read_text()
    assert 'SCRIPT ERROR' not in text, run['log']
    if run['classification'] == 'accepted':
        assert ': 0 failures' in text, run['log']
        for line in text.splitlines():
            if line.startswith('ERROR:'):
                assert 'resources still in use at exit' in line or 'RID allocations' in line
    elif run['classification'] == 'expected old-code failure':
        assert ': 10 failures' in text
    else:
        assert run['classification'] == 'interrupted fixture'
        assert ': 0 failures' not in text
matches = {}
for name in ['baseline-veteran', 'mode-0', 'mode-1', 'mode-2', 'final-veteran']:
    data = read(name + '.json')
    assert data['result'] == 'Victory' and data['hold'] == 30 and not data['errors']
    assert data['resources'] == [136, 80] and data['response_done']
    assert all(n['disabled'] and n['batches'] <= 3 for n in data['nodes'])
    matches[name] = {k: data[k] for k in ['time', 'human', 'infantry', 'nodes']}
recovery = {}
for name in ['before-focused', 'after-focused', 'verified-focused', 'final-ui']:
    text = (P / (name + '.log')).read_text()
    elapsed = float(re.search(r'FOUNDRY FEEDBACK RECOVERY elapsed=([\d.]+)', text)[1])
    assert 30 < elapsed < 32
    recovery[name] = elapsed
assert recovery['before-focused'] == recovery['verified-focused']
text = (P / 'final-ui.log').read_text()
assert text.count('FOUNDRY CONTROL ') == 3
assert 'FOUNDRY CONTROL right-click' in text
images = ['final-ui-' + state for state in ['locked', 'vacant', 'loaded', 'contested',
          'recapturing', 'infantry-needed', 'ordered', 'victory']]
images += ['final-veteran-foundry-' + state for state in ['node-0', 'node-1', 'live-result']]
for name in images:
    data = (P / (name + '.png')).read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    assert struct.unpack('>II', data[16:24]) == (1280, 720)
summary = {'status': 'passed', 'classified_runs': len(read('run-index.json')),
           'reviewed_images': len(images), 'matches': matches, 'controlled_recovery_seconds': recovery}
(P / 'analysis.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
