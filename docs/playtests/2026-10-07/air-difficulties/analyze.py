"""Check retained flight outcomes, regression failures, captures and source scope."""
from pathlib import Path
import hashlib
import json
import struct

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
read = lambda name: json.loads((HERE / name).read_text())
expected = {'mode-0': ('Victory', 3), 'mode-1': ('Victory', 3), 'mode-2': ('Defeat', 1),
            'response': ('Victory', 3), 'preview': ('Victory', 2),
            'final-preview': ('Victory', 3), 'accepted-preview': ('Victory', 3),
            'verified-preview': ('Victory', 3)}
for name, outcome in expected.items():
    data = read(name + '.json')
    assert (data['result'], data['rescued']) == outcome, (name, data)
    assert all(data['batteries']) and all(f['response_done'] for f in data['flights']), name
    if name not in ['mode-2', 'preview', 'final-preview']:
        assert not data['errors'], (name, data['errors'])
failures = {'notice-before-valid': ('Loaded confirmation makes a transient pause claim', 1),
            'holding-before': ('Air holding: 3 failures', 1),
            'warnings': ('ERROR: Restore warning was hidden after resuming', 2),
            'preview': ('ERROR: Air objectives overlap minimap at 150%', 1),
            'final-preview': ('ERROR: Air objectives overlap minimap at 150%', 1),
            'recovery-preview': ('ERROR: Held guidance overlaps minimap', 3),
            'recovery-final': ('ERROR: Held guidance overlaps minimap', 2)}
for name, (message, count) in failures.items():
    assert (HERE / (name + '.log')).read_text().count(message) == count, name
assert 'Supply contest: 12 failures' in (HERE / 'notice-before-valid.log').read_text()
for name in ['notice-verified', 'holding-final', 'rules-final', 'rules-accepted',
             'verified-recovery', 'verified-preview']:
    assert '0 failures' in (HERE / (name + '.log')).read_text(), name
warnings = (HERE / 'warnings-final.log').read_text()
assert 'PASS: bastion' in warnings and 'PASS: helix' in warnings
assert 'ERROR: Restore warning' not in warnings
for item in read('run-index.json'):
    log = (HERE / (item['name'] + '.log')).read_text()
    if item['name'] in ['notice-before', 'notice-final']:
        assert "previously freed" in log and 'SCRIPT ERROR' in log
    else:
        assert 'SCRIPT ERROR' not in log, item['name']
    assert item['exit_code'] in [0, 1], item
assert len(read('run-index.json')) == 21
log = (HERE / 'verified-preview.log').read_text()
assert log.count('AIR INPUT launch=') == 3
assert log.count('AIR INPUT continue-enter') == 1
log = (HERE / 'verified-recovery.log').read_text()
assert 'HELD INPUT continue-enter=1' in log
assert log.count('bottom=471.0 minimap=497.0') == 3
assert 'state=extracted' in log
images = ['verified-recovery-' + name for name in ['held', 'live', 'safe']]
images += ['verified-preview-' + name for name in [
    'air-corridor-battery-0', 'air-corridor-battery-1', 'held',
    'air-corridor-live-escort', 'two-safe', 'result']]
for name in images:
    assert struct.unpack('>II', (HERE / (name + '.png')).read_bytes()[16:24]) == (1280, 720), name
for name, digest in read('source-hashes.json').items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
assert set(read('shipping-delta.json')['changed']) == {
    'source/match/saves/MatchRestore.gd', 'source/match/campaign/AirCorridorHUD.gd'}
assert not read('shipping-delta.json')['added']
print('Air evidence passes: twenty-one runs, complete outcomes, original failures, earned recovery, controls, nine captures and source scope.')
