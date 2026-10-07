"""Audit classified relay feedback runs without treating failed commanders as wins."""
from pathlib import Path
import hashlib
import json
import struct

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def read(name):
    return json.loads((HERE / name).read_text())


runs = read('run-index.json')
assert len(runs) == 36 and len({r['name'] for r in runs}) == 36
script_failures = {'final': 18, 'initial-first-orders': 9, 'initial-split-rules': 45,
                   'initial-mode-0': 1, 'initial-mode-1': 1, 'initial-mode-2': 1}
for run in runs:
    log = (HERE / (run['name'] + '.log')).read_text()
    assert log.count('SCRIPT ERROR') == script_failures.get(run['name'], 0), run['name']
    assert run['script_errors'] == script_failures.get(run['name'], 0), run['name']
    if run['classification'] == 'accepted':
        assert run['exit_code'] == 0
        assert '0 failures' in log or 'PASS: First Orders' in log, run['name']
assert 'Relay feedback: 5 failures' in (HERE / 'before.log').read_text()
for name in ['mode-0', 'mode-2']:
    data = read(name + '.json')
    assert not data['result'] and data['waves'] == 6 and len(data['errors']) == 3
    assert data['relays'][0]['contested'] and data['relays'][2]['contested']
    assert (HERE / (name + '-archive.json')).is_file()
for name in ['mode-1', 'clear-0', 'clear-2', 'recovery-0', 'reinforced-2', 'retake-2', 'complete-2', 'rendered-complete']:
    data = read(name + '.json')
    assert data['result'] == 'Victory' and data['control'] >= 120 and not data['errors'], name
for name in ['recovery-2', 'rendered-recovery', 'rendered-reinforced', 'rendered-retake']:
    data = read(name + '.json')
    assert not data['result'] and data['elapsed'] >= 180 and len(data['errors']) == 1, name
    assert data['relays'][0]['owner'] == 'enemy', name
for name in ['reinforced-2', 'retake-2', 'complete-2', 'rendered-reinforced', 'rendered-retake', 'rendered-complete']:
    data = read(name + '.json')
    assert data['paid'] == [88 + 6 * data.get('replacements', 0), 20], name
for name in ['feedback-infantry', 'overview-final']:
    assert '0 failures' in (HERE / (name + '.log')).read_text(), name
log = (HERE / 'preview-infantry.log').read_text()
assert log.count('RELAY FEEDBACK INPUT') == 7
captures = sorted(HERE.glob('preview-infantry-*.png')) + sorted(HERE.glob('rendered-complete-*.png'))
assert len(captures) == 9
for path in captures:
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    assert struct.unpack('>II', data[16:24]) == (1280, 720), path.name
before, after = read('shipping-before.json'), read('shipping-after.json')
assert set(before) == set(after)
assert sorted(k for k in before if before[k] != after[k]) == [
    'source/match/campaign/SplitSignal.gd', 'source/match/campaign/SplitSignalHUD.gd',
    'source/match/hud/RelayOverview.gd', 'source/match/objectives/CaptureRelay.gd']
for name, digest in read('source-hashes.json').items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
print('PASS: 36 classified processes; original five feedback failures; final capture/armor/archives;')
print('all-faction relay overview; complete routes and explicitly retained unresolved branches;')
print('nine final captures, paid production accounting and four-file shipping scope.')
print('No novice, repeated balance, final environment, performance or platform acceptance is inferred.')
