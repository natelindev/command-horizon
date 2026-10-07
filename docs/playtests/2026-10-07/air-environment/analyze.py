"""Validate retained quarry geometry, outcomes, captures and source scope."""
from pathlib import Path
import hashlib
import json
import re
import struct

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def read(name):
    return json.loads((HERE / name).read_text())


runs = read('run-index.json')
assert len(runs) == 19 and len({r['name'] for r in runs}) == 19
for run in runs:
    log = (HERE / (run['name'] + '.log')).read_text()
    assert run['exit_code'] == 0 and '0 failures' in log, run['name']
    assert 'SCRIPT ERROR' not in log, run['name']
    for line in log.splitlines():
        if line.startswith('ERROR:'):
            assert re.fullmatch(r'ERROR: [24] resources still in use at exit \(run with --verbose for details\).', line), (run['name'], line)
for name in ['import', 'import-final', 'asset-build', 'asset-final']:
    log = (HERE / (name + '.log')).read_text()
    assert 'SCRIPT ERROR' not in log and 'Traceback' not in log and '\nERROR:' not in log
old, new = read('baseline.json'), read('geometry.json')
assert old['routes'] == new['routes'] and len(new['routes']) == 4
assert len(old['blockers']) == len(new['blockers']) == 13
assert sum(b['mesh_radius'] > b['radius'] for b in old['blockers']) == 5
assert sum(b['mesh_height'] > b['sight'] for b in old['blockers']) == 5
assert old['crossing_root_y'] == 1.5 and new['crossing_root_y'] > 4
for a, b in zip(old['blockers'], new['blockers']):
    assert all(a[k] == b[k] for k in ['position', 'radius', 'sight'])
    assert b['mesh_radius'] <= b['radius'] and b['mesh_height'] <= b['sight']
for name in ['flights', 'flights-final']:
    assert 'QUARRY FLIGHTS crossings=39 saved_altitude=4.099' in (HERE / (name + '.log')).read_text()
assert 'LEGACY FLIGHT (65.74981, 1.5, 51.0)' in (HERE / 'legacy-capture.log').read_text()
assert 'LEGACY RESUME old=1.5 raised=4.099' in (HERE / 'legacy-recovery.log').read_text()
for name, saved in [('mode-0', 3), ('mode-1', 2), ('mode-2', 2), ('veteran-response', 3), ('veteran-preview', 3)]:
    d = read(name + '.json')
    assert d['result'] == 'Victory' and d['rescued'] == saved and not d['errors'], name
    assert all(d['batteries']) and all(f['response_done'] for f in d['flights']), name
log = (HERE / 'veteran-preview.log').read_text()
assert log.count('AIR INPUT launch=') == 3 and log.count('AIR INPUT continue-enter') == 1
captures = sorted(HERE.glob('review-*.png')) + sorted(HERE.glob('veteran-preview-*.png'))
captures += [HERE / 'raised-crossing.png', HERE / 'raised-loaded.png']
assert len(captures) == 15
for p in captures:
    data = p.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    expected = (1440, 900) if p.name == 'review-overview.png' else (1280, 720)
    assert struct.unpack('>II', data[16:24]) == expected, p.name
before, after = read('shipping-before.json'), read('shipping-after.json')
assert sorted(k for k in before.keys() & after.keys() if before[k] != after[k]) == [
    'source/match/maps/AirCorridorMap.gd', 'source/match/maps/AirCorridorMap.tscn']
assert sorted(after.keys() - before.keys()) == [
    'source/match/maps/QuarryBackdrop.gd', 'source/match/maps/QuarryMaterials.gd',
    'source/shaders/3d/quarry_ground.gdshader']
assert not before.keys() - after.keys()
for path, digest in read('source-hashes.json').items():
    assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, path
manifest = json.loads((ROOT / 'art/environment/quarry-manifest.json').read_text())
assert len(manifest) == 7
for d in manifest.values():
    assert d['radius'] <= d['radius_limit'] and d['height'] <= d['height_limit']
print('PASS: 19 successful script runs; 13 preserved blockers; 4 exact routes; 39 final airframe crossings;')
print('raised/legacy archive checks; 5 complete-route outcomes; 15 captures; 7 assets; source scope/hashes.')
print('This audit does not establish novice, repeated balance, final art, performance or platform acceptance.')
