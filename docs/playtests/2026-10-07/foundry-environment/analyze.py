"""Check retained Foundry environment evidence against current source/assets."""
from pathlib import Path
import hashlib
import json
import struct
import re

P = Path(__file__).resolve().parent
ROOT = P.parents[3]

def read(name):
    return json.loads((P / name).read_text())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

for name, expected in read('source-hashes.json').items():
    assert digest(ROOT / name) == expected, name
    assert digest(P / ('accepted-' + Path(name).name + '.txt')) == expected
for name, expected in read('asset-hashes.json').items():
    assert digest(ROOT / name) == expected, name
assert read('shipping-delta.json') == {
    'changed': ['source/match/maps/BrokenFoundryMap.gd', 'source/match/maps/BrokenFoundryMap.tscn'],
    'added': ['source/match/maps/FoundryBackdrop.gd', 'source/shaders/3d/foundry_ground.gdshader'],
    'removed': []}
baseline = read('baseline.json')
geometry = read('geometry.json')
assert len(baseline['blockers']) == len(geometry['blockers']) == 6
assert len(baseline['routes']) == len(geometry['routes']) == 5
for old,new in zip(baseline['blockers'],geometry['blockers']):
    for key in ['radius','sight','mesh_radius','mesh_height']:
        assert abs(old[key]-new[key]) < .0001
    assert old['position'] == new['position']
for old,new in zip(baseline['routes'],geometry['routes']):
    assert abs(old-new) < .01
runs = read('run-index.json')
for run in runs:
    log = (P/run['log']).read_text()
    assert run['exit_code'] == 0
    assert 'SCRIPT ERROR' not in log and ': 0 failures' in log, run['log']
    for line in log.splitlines():
        if line.startswith('ERROR:'):
            assert 'resources still in use at exit' in line or 'RID allocations' in line
assert (P/'verified-geometry.log').read_text().count('FOUNDRY ENVIRONMENT ARCHIVE ') == 2
flights = (P/'aircraft.log').read_text()
assert flights.count('Industrial flight ') == 24
assert flights.count('Industrial flight BrokenFoundryMap.tscn') == 12
matches={}
for name in ['mode-0','mode-1','mode-2','native-veteran']:
    data=read(name+'.json')
    assert data['result'] == 'Victory' and data['hold'] == 30 and not data['errors']
    assert data['resources'] == [136,80] and data['response_done']
    assert all(n['disabled'] and 0 <= n['batches'] <= 3 for n in data['nodes'])
    matches[name]={k:data[k] for k in ['time','human','infantry','nodes']}
images=['final-'+s for s in ['start','enemy-fog','boundary-fog','north','junction','control','overview','rail-yard','utilities','boundary']]
images+=['native-veteran-foundry-'+s for s in ['node-0','node-1','live-result']]
for name in images:
    data=(P/(name+'.png')).read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    assert struct.unpack('>II',data[16:24]) == ((1440,900) if name=='final-overview' else (1280,720))
summary={'status':'passed','classified_runs':len(runs),'reviewed_images':len(images),
         'blockers':len(geometry['blockers']),'route_lengths':geometry['routes'],
         'actual_aircraft_crossings':24,'matches':matches}
(P/'analysis.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
