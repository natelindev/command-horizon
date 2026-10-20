"""Propose voices for uncast roles from the analysed pool, as distinct as possible.

Existing assignments in voice_cast.py (and the campaign's supporting cast) are fixed; only
roles without a voice are proposed, so adding a role never recasts a unit. Prints explicit
assignments for voice_cast.py; casting stays a reviewed, stable table rather than being
recomputed on every build:
  tmp/voice-venv/bin/python art/audio/select_voice_cast.py
"""
import json
from pathlib import Path

import librosa
import numpy as np
import torch
from speechbrain.inference.speaker import EncoderClassifier
from voice_cast import MERCENARY_VOICES, ROBOT_VOICE_REFERENCES, UNIT_VOICES, native_accent

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'tmp/voice-work'
# ECAPA cosine above this is treated as the same person (e.g. one donor's repeat donations).
SAME_PERSON = .4
# Lower first: commanders and heavy armour get the deepest voices, pilots and scouts lighter.
ROLE_REGISTER = ['Hero', 'AdvancedTank', 'Tank', 'AssaultInfantry', 'SniperInfantry',
                 'RocketInfantry', 'Infantry', 'SupplyTruck', 'Helicopter',
                 'Bomber', 'AntiAirVehicle', 'Fighter']
# Mercenaries are neutral hires: one voice per contract, the same in every army.
GROUP_ROLES = {
    'bastion': ROLE_REGISTER,
    'helix': ROLE_REGISTER,
    'frontier': ROLE_REGISTER[:7] + ['Worker'] + ROLE_REGISTER[7:],
    'mercenary': ['MercenaryWarden', 'MercenaryLancer', 'MercenaryRanger'],
}
ROBOTS = ['bastion/Worker', 'bastion/RepairRobot', 'bastion/CombatRobot', 'bastion/Drone',
          'helix/Worker', 'helix/RepairRobot', 'helix/CombatRobot', 'helix/Drone',
          'frontier/RepairRobot', 'frontier/CombatRobot', 'frontier/Drone']
# Each army has one accent family; the mercenaries have their own, used by no army.
GROUP_ACCENTS = {'frontier': ['australia', 'ireland', 'newzealand'], 'bastion': ['us', 'canada'],
                 'helix': ['england'], 'mercenary': ['scotland']}


def announcer_embeddings():
    classifier = EncoderClassifier.from_hparams('speechbrain/spkrec-ecapa-voxceleb',
                                                savedir=str(WORK / 'ecapa'), run_opts={'device': 'cpu'})
    vectors = []
    for faction in ['bastion', 'helix', 'frontier']:
        clips = sorted((ROOT / f'assets/audio/voices/{faction}/Command').glob('*.ogg'))
        audio = np.concatenate([librosa.load(clip, sr=16000)[0] for clip in clips])
        with torch.inference_mode():
            vector = classifier.encode_batch(torch.from_numpy(audio)[None]).squeeze().numpy()
        vectors.append(vector / np.linalg.norm(vector))
    return np.array(vectors)


def farthest(pool, vectors, chosen, count, avoid, strict=True):
    """Greedy max-min selection away from ``avoid`` (the announcers) and earlier picks;
    never two references that are probably one person."""
    picked = []
    while len(picked) < count:
        taken = list(avoid) + [vectors[i] for i in chosen + picked]
        options = [i for i in pool if i not in chosen + picked
                   and max(vectors[i] @ v for v in taken) < SAME_PERSON]
        if not options:
            if not strict:
                return picked
            raise SystemExit(f'Only {len(picked)} of {count} distinct voices available')
        picked.append(min(options, key=lambda i: max(vectors[i] @ v for v in taken)))
    return picked


def campaign_references(report):
    """Supporting campaign characters are their own people; units must not borrow their voices
    (distinctness is measured within the battle cast, as the campaign audit does for its own)."""
    from build_campaign_audio import cast
    by_hash = {info['sha256']: name for name, info in report.items()}
    return [by_hash[profile['reference_sha256']] for profile in cast().values()]


def main():
    report = json.loads((ROOT / 'art/audio/voice-pool.json').read_text())
    data = np.load(WORK / 'pool-embeddings.npz')
    names, vectors = list(data['names']), data['vectors']
    announcers = announcer_embeddings()
    assigned = {**UNIT_VOICES, 'mercenary': MERCENARY_VOICES}
    fixed = [name for roles in assigned.values() for name in roles.values()]
    fixed += ROBOT_VOICE_REFERENCES.values()
    chosen = [names.index(name) for name in fixed]
    taken = set(fixed) | set(campaign_references(report))

    def clean(name):
        info = report[name]
        return (name not in taken and info['english'] >= .9 and info['snr_db'] >= 30
                and info['bandwidth_hz'] >= 5000 and info['peak'] < .99
                and max(announcers @ vectors[names.index(name)]) < SAME_PERSON)

    crew = {names.index(n): native_accent(report[n]) for n in names
            if clean(n) and native_accent(report[n]) and 75 <= (report[n]['f0_median_hz'] or 0) <= 160}
    missing = {group: [role for role in roles if role not in assigned.get(group, {})]
               for group, roles in GROUP_ROLES.items()}
    preferred = {group: [i for i, accent in crew.items() if accent in GROUP_ACCENTS[group]]
                 for group in missing}
    # Each group first takes its own accent family, scarcest family first.
    picks = {}
    for group in sorted(missing, key=lambda g: len(preferred[g]) - len(missing[g])):
        picks[group] = farthest(preferred[group], vectors, chosen, len(missing[group]), announcers,
                                strict=False)
        chosen += picks[group]
    # Short armies top up from other native speakers, English first, never the mercenaries'.
    reserved = set(GROUP_ACCENTS['mercenary'])
    backup = sorted((i for i, accent in crew.items() if accent not in reserved),
                    key=lambda i: crew[i] != 'england')
    for group, roles in missing.items():
        if len(picks[group]) < len(roles):
            extra = farthest(backup, vectors, chosen, len(roles) - len(picks[group]), announcers)
            picks[group] += extra
            chosen += extra
    proposal = {}
    for group, roles in missing.items():
        # Deepest voices lead and drive the heavy armour; lighter voices fly and haul.
        ordered = sorted(picks[group], key=lambda i: report[names[i]]['f0_median_hz'])
        proposal[group] = {role: names[i] for role, i in zip(roles, ordered)}
    missing_robots = [key for key in ROBOTS if key not in ROBOT_VOICE_REFERENCES]
    robots = farthest([names.index(n) for n in names if clean(n)],
                      vectors, chosen, len(missing_robots), announcers)
    chosen += robots
    proposal['robots'] = dict(zip(missing_robots, (names[i] for i in robots)))
    print(json.dumps(proposal, indent=1))
    for group, roles in proposal.items():
        for role, name in roles.items():
            i = names.index(name)
            others = [j for j in chosen if j != i]
            nearest = max(others, key=lambda j: vectors[i] @ vectors[j])
            print(f'{group}/{role}: {name} accent={crew.get(i)} '
                  f"f0={report[name]['f0_median_hz']} nearest={names[nearest]} "
                  f'{float(vectors[i] @ vectors[nearest]):.3f}')
    similarity = vectors[chosen] @ vectors[chosen].T - np.eye(len(chosen)) * 2
    print('native crew candidates', len(crew), 'references', len(chosen),
          'max pairwise cosine', round(float(similarity.max()), 3),
          'max announcer cosine', round(float((announcers @ vectors[chosen].T).max()), 3))


if __name__ == '__main__':
    main()
