"""Verify retained Horizon surroundings evidence and source/asset identity."""
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


for name, expected in read('source-hashes.json').items():
    assert digest(ROOT / name) == expected, name
    assert digest(P / ('accepted-' + Path(name).name + '.txt')) == expected
for group in ['asset-hashes.json', 'fixture-hashes.json']:
    for name, expected in read(group).items():
        assert digest(ROOT / name) == expected, name
assert read('shipping-delta.json') == {
    'changed': ['source/match/maps/CommandHorizonMap.gd',
                'source/shaders/3d/horizon_ground.gdshader'],
    'added': ['source/match/maps/HorizonBackdrop.gd'], 'removed': []}
geometry = {}
for route, count in [('south', 15), ('north', 13)]:
    old = read('baseline-' + route + '.json')
    new = read('geometry-' + route + '.json')
    assert len(old['blockers']) == len(new['blockers']) == count
    assert len(old['routes']) == len(new['routes']) == 5
    for a, b in zip(old['blockers'], new['blockers']):
        assert a['position'] == b['position']
        for key in ['radius', 'sight', 'mesh_radius', 'mesh_height']:
            assert abs(a[key] - b[key]) < .0001
        assert b['mesh_radius'] <= b['radius'] and b['mesh_height'] <= b['sight']
    assert all(abs(a-b) < .01 for a, b in zip(old['routes'], new['routes']))
    assert (new['routes'][0] > 140 if route == 'south' else new['routes'][0] < 40)
    assert (P/('geometry-' + route + '.log')).read_text().count('HORIZON ENVIRONMENT ARCHIVE ') == 2
    geometry[route] = {'blockers': count, 'route_lengths': new['routes']}
runs = read('run-index.json')
assert {p.name for p in P.glob('*.log')} == {r['log'] for r in runs}
for run in runs:
    log = (P/run['log']).read_text()
    assert run['exit_code'] == 0 and ': 0 failures' in log, run
    assert 'SCRIPT ERROR' not in log and 'SHADER ERROR' not in log, run
    for line in log.splitlines():
        if line.startswith('ERROR:'):
            assert any(text in line for text in [
                'resources still in use at exit', 'RID allocations',
                'shaders of type ParticlesShaderRD were never freed']), line
assert (P/'environment-rules.log').read_text().count('Flight ') == 8
matches = {}
for name in ['south-0', 'south-1', 'south-2', 'native-north', 'earned-recovery']:
    result = read(name + '.json')
    assert result['result'] == 'Victory' and not result['errors'], name
    assert result['waves'] == 4 and result['deployed'] and result['command_destroyed'] and result['zone_held']
    assert result['alternate_route'] == (name == 'native-north')
    matches[name] = {key: result[key] for key in ['time', 'difficulty', 'alternate_route', 'sides']}
images = ['final-' + name for name in [
    'start', 'enemy-fog', 'boundary-fog', 'deployment', 'north', 'command',
    'overview', 'north-edge', 'west', 'south', 'boundary']]
images += ['native-north-horizon-' + name for name in ['deployment', 'pass', 'live-result']]
for name in images:
    png = (P/(name+'.png')).read_bytes()
    assert png[:8] == b'\x89PNG\r\n\x1a\n'
    assert struct.unpack('>II', png[16:24]) == ((1440,900) if name == 'final-overview' else (1280,720))
summary = {'status': 'passed', 'classified_runs': len(runs), 'reviewed_images': len(images),
           'geometry': geometry, 'aircraft_crossings': 8, 'matches': matches}
(P/'analysis.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
