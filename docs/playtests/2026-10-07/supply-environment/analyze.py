"""Validate the retained Supply Line environment evidence, without launching Godot."""
from pathlib import Path
import hashlib
import json
import struct

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
read = lambda name: json.loads((HERE / name).read_text())
for item in read('headless-runs.json'):
    assert item['exit_code'] == 0, item
    log = (HERE / item['log']).read_text()
    assert '0 failures' in log and 'SCRIPT ERROR' not in log, item
for name in ['before-preview', 'initial-preview', 'final-preview', 'live-combat', 'veteran-preview']:
    log = (HERE / (name + '.log')).read_text()
    assert '0 failures' in log and 'SCRIPT ERROR' not in log, name
assert (HERE / 'geometry.log').read_text().count('ERROR: Environment changed a blocker contract') == 4
before, after = read('baseline.json'), read('final-geometry.json')
assert len(after['blockers']) == 4
for old, new in zip(before['blockers'], after['blockers']):
    assert old['position'] == new['position']
    assert old['radius'] == new['radius'] == 5
    assert old['sight'] == new['sight'] == 3
    assert old['mesh_radius'] > 5 and old['mesh_height'] > 3
    assert new['mesh_radius'] <= 5 and new['mesh_height'] <= 3
assert before['routes'] == after['routes']
for name in ['group-0', 'group-1', 'group-2', 'veteran-preview']:
    data = read(name + '.json')
    assert data['result'] == 'Victory' and not data['errors'], name
    assert all(data['responses']), name
    assert sum(truck['delivered'] for truck in data['trucks']) == 2, name
    assert all(truck['delivered'] or truck['alive'] for truck in data['trucks']), name
log = (HERE / 'veteran-preview.log').read_text()
assert log.count('CONVOY INPUT mouse-advance') == 3
assert log.count('CONVOY INPUT enter-hold') == 3
assert 'paused=false' in (HERE / 'live-combat.log').read_text()
accepted = ['final-start.png', 'final-overview.png', 'live-combat.png']
accepted += [f'final-checkpoint-{i}.png' for i in range(3)]
accepted += [f'veteran-preview-stage-{i}.png' for i in range(3)]
for name in accepted:
    size = struct.unpack('>II', (HERE / name).read_bytes()[16:24])
    assert size == ((1440, 900) if 'overview' in name else (1280, 720)), (name, size)
for name, digest in read('source-hashes.json').items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
assert read('shipping-delta.json') == {
    'changed': ['source/match/maps/SupplyLineMap.gd', 'source/match/maps/SupplyLineMap.tscn'],
    'added': ['source/match/maps/SupplyBackdrop.gd', 'source/shaders/3d/supply_ground.gdshader'],
}
print('Evidence passes: baseline geometry, three difficulties, Veteran controls, archive recovery, nine rendered captures and source scope.')
