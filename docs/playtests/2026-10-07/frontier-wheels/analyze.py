"""Check wheel motion evidence and ensure model edits only rename wheel nodes."""
from pathlib import Path
import hashlib,json,math,re,struct,subprocess
P=Path(__file__).resolve().parent
ROOT=P.parents[3]
def read(name):return json.loads((P/name).read_text())
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def glb(blob):
    size,kind=struct.unpack_from('<II',blob,12)
    assert kind==0x4e4f534a
    return json.loads(blob[20:20+size]),blob[20+size:]
for name,expected in read('source-hashes.json').items():
    assert digest(ROOT/name)==expected,name
    assert digest(P/('accepted-'+Path(name).name+'.txt'))==expected
for name,expected in read('asset-hashes.json').items():assert digest(ROOT/name)==expected,name
renames=read('asset-renames.json')
assert sum(len(r['renames']) for r in renames)==28
for entry in renames:
    target=ROOT/entry['asset'];old=(P/('before-'+target.name+'.bin')).read_bytes();new=target.read_bytes()
    assert hashlib.sha256(old).hexdigest()==entry['before_sha256']
    assert hashlib.sha256(new).hexdigest()==entry['after_sha256']
    before,old_payload=glb(old);after,new_payload=glb(new)
    assert old_payload==new_payload
    for node in before['nodes']:
        if re.search(r'_Wheel(?:\.\d+)?$',node.get('name','')):node['name']=node['name'].replace('_Wheel','_WheelPivot')
    assert before==after,'Non-name GLB content changed'
assert len(read('blend-rename.json')['renamed'])==28
v=json.loads((ROOT/'art/frontier/v1/verification.json').read_text())
assert v['asset_count']==17 and sum(a['wheels'] for a in v['assets'])==28
baseline=read('baseline.json');verified=read('verified.json')
expected={'Worker':6,'Tank':6,'RepairRobot':4,'CombatRobot':4,'AdvancedTank':8}
assert len(baseline)==len(verified)==5
for row in baseline:assert row['distance']>1 and row['animated_wheels']==0
for row in verified:assert row['distance']>1 and row['animated_wheels']==expected[row['role']]
log=(P/'corrected-baseline.log').read_text()
assert 'Frontier wheels: 5 failures' in log and 'SCRIPT ERROR' not in log
log=(P/'final-regression.log').read_text()
assert log.count('WHEEL CONTROL ')==5 and 'WHEEL ARCHIVE exact paused state and resumed articulation' in log
runs=read('run-index.json')
assert {r['log'] for r in runs}=={f.name for f in P.glob('*.log')}
for row in runs:
    if row['exit_code']!=0:continue
    log=(P/row['log']).read_text()
    assert 'SCRIPT ERROR' not in log and 'SHADER ERROR' not in log,row
    for line in log.splitlines():
        if line.startswith('ERROR:'):
            assert 'resources still in use at exit' in line or 'RID allocations' in line,line
for name in ['final-regression','final-gameplay','final-combat','review']:
    assert ': 0 failures' in (P/(name+'.log')).read_text()
samples=read('review-samples.json')
assert len(samples)==225
stages={phase:[r for r in samples if r['stage']==phase] for phase in ['normal','paused','quarter-speed-detail']}
assert [len(r) for r in stages.values()]==[90,15,120]
assert len({str(r['angles']) for r in stages['paused']})==1
assert len({r['time'] for r in stages['paused']})==1
assert all(math.isfinite(a) and abs(a)<=math.pi for r in samples for a in r['angles'])
for phase in ['normal','quarter-speed-detail']:assert len({str(r['angles']) for r in stages[phase]})>20
video=json.loads(subprocess.check_output(['/opt/homebrew/bin/ffprobe','-v','error','-show_entries','stream=width,height,nb_frames,r_frame_rate','-show_entries','format=duration','-of','json',str(P/'wheel-motion.mp4')]))
assert video['streams'][0]['nb_frames']=='225' and video['format']['duration']=='7.500000'
for name in ['review-lineup','review-detail-paused','review-detail-moving']:
    data=(P/(name+'.png')).read_bytes();assert struct.unpack('>II',data[16:24])==(1280,720)
summary={'status':'passed','classified_runs':len(runs),'godot_runs':sum(r['tool']=='Godot' for r in runs),'wheels':28,'roles':5,'models_reimported':17,'video_frames':225,'video_seconds':7.5,'verified_travel':verified}
(P/'analysis.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
