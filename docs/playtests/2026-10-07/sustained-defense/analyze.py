"""Validate completed policy trials and retain bounded descriptive observations."""
from pathlib import Path
import hashlib
import json
import statistics

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BRANCHES = {
    'control': (False, False),
    'response': (True, False),
    'handoff': (False, True),
    'combined': (True, True),
}
rows = []
aggregates = {}
for name, enabled in BRANCHES.items():
    result = json.loads((HERE / (name + '-result.json')).read_text())
    assert result['exit_code'] == 0, result
    log = (HERE / (name + '.log')).read_text()
    assert 'Skirmish matrix: 3 records, 0 unresolved checks' in log, name
    assert 'SCRIPT ERROR' not in log and 'Parse Error' not in log, name
    records = json.loads((HERE / (name + '.json')).read_text())
    assert len(records) == 3, name
    assert {r['seed'] for r in records} == {4110, 4111, 4112}, name
    batch = []
    for r in records:
        assert r['result'] in ['Victory', 'Defeat', 'Draw'], r['result']
        assert not r['ai_coordination']['violations'], name
        assert r['map'] == 'IndustrialCrossroads' and r['faction'] == 'helix'
        assert r['opponent'] == 'frontier' and not r['advanced']
        assert r['difficulty'] == 'Normal' and r['army_policy'] == 'screened-air'
        assert r['research_policy'] == 'combined'
        assert (r['final']['home_response_enabled'], r['final']['electronics_handoff_enabled']) == enabled
        handoffs = r.get('electronics_handoffs', [])
        assert enabled[0] or r.get('home_response_orders', 0) == 0
        assert enabled[1] or not handoffs
        samples = [s for s in r['samples'] if s['seconds'] >= 120 and s['sides'][0]['units'].get('CommandCenter', 0)]
        latest = samples[-1] if samples else r['samples'][-1]
        row = {
            'branch': name,
            'seed': r['seed'],
            'outcome': r['result'],
            'seconds': r['seconds'],
            'basic_unlock': r['basic_unlock'],
            'first_program': r['first_program'],
            'first_assault': r['first_assault'],
            'assaults': r.get('policy_assaults', 0),
            'harvested': r['harvested'],
            'net_spent': r['spent'],
            'worker_losses': r['losses'][0].get('Worker', 0),
            'first_home_response': r.get('first_home_response'),
            'home_response_orders': r.get('home_response_orders', 0),
            'first_handoff': handoffs[0]['seconds'] if handoffs else None,
            'handoffs': len(handoffs),
            'samples_without_electronics_assignment': sum(s['sides'][0]['workers'].get('electronics', 0) == 0 for s in samples),
            'economy_samples': len(samples),
            'latest_hq_sample': {
                'seconds': latest['seconds'],
                'human_units': latest['sides'][0]['units'],
                'enemy_units': latest['sides'][1]['units'],
                'policy': latest['policy'],
            },
            'coordination_samples': r['ai_coordination']['samples'],
            'max_stationary_travel': r['longest_stationary_travel'],
        }
        batch.append(row)
    rows.extend(batch)
    program_times = [r['first_program'] for r in batch if r['first_program'] is not None]
    aggregates[name] = {
        'outcomes': {outcome: sum(r['outcome'] == outcome for r in batch) for outcome in ['Victory', 'Defeat', 'Draw']},
        'assault_matches': sum(r['first_assault'] is not None for r in batch),
        'median_seconds': statistics.median(r['seconds'] for r in batch),
        'median_first_program': statistics.median(program_times) if program_times else None,
        'median_harvested': [statistics.median(r['harvested'][i] for r in batch) for i in range(2)],
        'median_worker_losses': statistics.median(r['worker_losses'] for r in batch),
    }
before = json.loads((HERE / 'before-source-fingerprint.json').read_text())['current']
current = {str(f.relative_to(ROOT)): hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted((ROOT / 'source').rglob('*.gd'))}
assert before == current, 'Shipping changed during the comparison'
report = {
    'scope': '12 paid Standard/Normal Industrial Helix-versus-Frontier matches; one reference strategy family',
    'caveats': [
        'Three seeds per variant are descriptive evidence, not a statistical balance conclusion.',
        'Navigation and battle trajectories can differ before an experimental order, even at the same seed.',
        'Electronics assignment counts are sparse 60-second samples, not measured income downtime.',
        'Defeat is a valid recorded outcome, not gameplay acceptance.',
    ],
    'rows': rows,
    'aggregate': aggregates,
    'shipping_script_count': len(current),
    'shipping_differences': [],
}
(HERE / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(aggregates, indent=2))
