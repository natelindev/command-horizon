"""Verify retained deployment-feedback evidence and current shipping provenance."""
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
changed=['source/match/campaign/CommandHorizon.gd','source/match/campaign/CommandHorizonHUD.gd',
         'source/match/objectives/DeploymentControl.gd']
assert read('shipping-delta.json') == {'changed':changed,'added':[],'removed':[]}
for name in changed:
    assert digest(P/('before-'+Path(name).name+'.txt')) == read('shipping-before.json')[name]
runs=read('run-index.json')
for run in runs:
    log=(P/run['log']).read_text()
    kind=run['classification']
    if kind == 'rejected runtime errors':
        assert 'SCRIPT ERROR' in log, run['log']
        continue
    if kind == 'interrupted invalid-source run':
        assert 'SCRIPT ERROR' in log and 'Command Horizon: 0 failures' not in log
        continue
    assert 'SCRIPT ERROR' not in log, run['log']
    if kind in ['expected old-code failure','superseded baseline fixture']:
        assert 'Horizon control: 19 failures' in log
    elif kind == 'accepted':
        assert run['exit_code'] == 0 and ': 0 failures' in log,run['log']
        for line in log.splitlines():
            if line.startswith('ERROR:'):
                assert any(s in line for s in ['resources still in use at exit','RID allocations','shaders of type ParticlesShaderRD were never freed']),line
    elif kind == 'victory with rejected purchase':
        assert run['exit_code'] == 1
        assert 'Lean force could not pay for second field repair support' in log
    elif kind == 'retained unsuccessful route':
        assert run['exit_code'] != 0
    else:
        raise AssertionError(kind)
recovery={}
for name in ['before-corrected','final-focused','final-native']:
    log=(P/(name+'.log')).read_text()
    securing=float(re.search(r'HORIZON CONTROL SECURING elapsed=([\d.]+)',log)[1])
    returning=float(re.search(r'HORIZON CONTROL RETURN elapsed=([\d.]+)',log)[1])
    assert 30 < securing < 32 and 2 < returning < 4
    recovery[name]={'securing':securing,'return':returning}
assert recovery['before-corrected'] == recovery['final-focused']
log=(P/'final-native.log').read_text()
assert log.count('HORIZON CONTROL Infantry')==2 and log.count('HORIZON CONTROL Deployment')==2
assert log.count('HORIZON CONTROL right-click')==2
matches={}
for name in ['final-north-0','final-north-1','final-north-2','final-north-2-lean','final-north-2-reinforced','native-north']:
    data=read(name+'.json')
    assert data['alternate_route'] and data['waves']==4
    if not data['errors']:
        assert data['result']=='Victory' and data['deployed'] and data['zone_held'] and data['command_destroyed']
    else:
        assert data['errors'] == ['Lean force could not pay for second field repair support']
        assert data['result']=='Victory' and data['deployed'] and data['zone_held'] and data['command_destroyed']
    matches[name]={k:data[k] for k in ['difficulty','challenge','result','time','errors','sides']}
earned={}
for name in ['final-earned-recovery','native-earned']:
    data=read(name+'.json')
    assert not data['errors'] and data['result']=='Victory' and data['zone_held'] and data['command_destroyed']
    log=(P/(name+'.log')).read_text()
    elapsed,paid=re.search(r'HORIZON RECOVERY elapsed=([\d.]+) paid_infantry=(\d+)',log).groups()
    assert 0 < float(elapsed) < 60 and 0 < int(paid) <=6
    earned[name]={'elapsed':float(elapsed),'paid_infantry':int(paid)}
support={}
for name in ['lean-diagnostic','lean-paid-support']:
    data=read(name+'.json')
    assert data['result']=='Victory' and not data['errors'] and data['alternate_route'] and data['waves']==4
    purchase=read(name+'-purchase.json')
    assert purchase['admitted'] and purchase['initially_admitted'] and purchase['wait_seconds']==0
    assert purchase['paid_cost']==purchase['cost']=={'resource_a':16,'resource_b':8}
    assert purchase['funds_after']==[purchase['funds'][0]-16,purchase['funds'][1]-8]
    support[name]={'victory_time':data['time'],'purchase':purchase}
images=['final-native-'+s for s in ['unclaimed','vacant','loaded','contested','recapturing','infantry-needed',
        'ordered-1','guard-ready','guard-absent','command-destroyed','ordered-2','victory']]
images+=['native-earned-'+s for s in ['paused','result']]
images+=['native-north-horizon-'+s for s in ['deployment','pass','live-result']]
for name in images:
    data=(P/(name+'.png')).read_bytes()
    assert data[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',data[16:24])==(1280,720)
summary={'status':'passed','classified_runs':len(runs),'reviewed_images':len(images),'controlled_recovery':recovery,
         'earned_recovery':earned,'north_route_matches':matches,'support_diagnostics':support}
(P/'analysis.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
