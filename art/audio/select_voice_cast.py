"""Propose a maximally distinct cast from the analysed voice pool.

Prints explicit assignments for voice_cast.py; casting stays a reviewed, stable table rather
than being recomputed on every build:
  tmp/voice-venv/bin/python art/audio/select_voice_cast.py
"""
import json
from pathlib import Path

import librosa
import numpy as np
import torch
from speechbrain.inference.speaker import EncoderClassifier
from voice_cast import native_accent

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'tmp/voice-work'
# ECAPA cosine above this is treated as the same person (e.g. one donor's repeat donations).
SAME_PERSON = .4
# Lower first: commanders and heavy armour get the deepest voices, pilots and scouts lighter.
ROLE_REGISTER = ['Hero', 'AdvancedTank', 'Tank', 'AssaultInfantry', 'SniperInfantry',
                 'RocketInfantry', 'Infantry', 'SupplyTruck', 'EvacTransport', 'Helicopter']
FACTION_ROLES = {
    'bastion': ROLE_REGISTER,
    'helix': ROLE_REGISTER,
    'frontier': ROLE_REGISTER[:7] + ['Worker'] + ROLE_REGISTER[7:],
}
ROBOTS = ['bastion/Worker', 'bastion/RepairRobot', 'bastion/CombatRobot', 'bastion/Drone',
          'helix/Worker', 'helix/RepairRobot', 'helix/CombatRobot', 'helix/Drone',
          'frontier/RepairRobot', 'frontier/CombatRobot', 'frontier/Drone']


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


# Each army has one accent family; scarcest family is cast first.
FACTION_ACCENTS = {'frontier': ['australia', 'ireland', 'newzealand'], 'bastion': ['us', 'canada'],
                   'helix': ['england']}


def main():
    report = json.loads((ROOT / 'art/audio/voice-pool.json').read_text())
    data = np.load(WORK / 'pool-embeddings.npz')
    names, vectors = list(data['names']), data['vectors']
    announcers = announcer_embeddings()

    def clean(name):
        info = report[name]
        return (info['snr_db'] >= 30 and info['bandwidth_hz'] >= 5000 and info['peak'] < .99
                and max(announcers @ vectors[names.index(name)]) < SAME_PERSON)

    crew = {names.index(n): native_accent(report[n]) for n in names
            if clean(n) and native_accent(report[n]) and 75 <= (report[n]['f0_median_hz'] or 0) <= 160}
    cast, chosen = {}, []
    # Scarcest accent family first; top up from other native speakers, English first.
    for faction in FACTION_ACCENTS:
        count = len(FACTION_ROLES[faction])
        preferred = [i for i, accent in crew.items() if accent in FACTION_ACCENTS[faction]]
        picked = farthest(preferred, vectors, chosen, count, announcers, strict=False)
        if len(picked) < count:
            backup = sorted(crew, key=lambda i: crew[i] != 'england')
            picked += farthest(backup, vectors, chosen + picked, count - len(picked), announcers)
        chosen += picked
        # Deepest voices lead and drive the heavy armour; lighter voices fly and haul.
        ordered = sorted(picked, key=lambda i: report[names[i]]['f0_median_hz'])
        cast[faction] = {role: names[i] for role, i in zip(FACTION_ROLES[faction], ordered)}
    robots = farthest([names.index(n) for n in names if clean(n) and report[n]['english'] >= .9],
                      vectors, chosen, len(ROBOTS), announcers)
    print(json.dumps({'units': cast, 'robots': dict(zip(ROBOTS, (names[i] for i in robots)))}, indent=1))
    for faction, roles in cast.items():
        print(faction, sorted(crew[names.index(n)] for n in roles.values()))
    everyone = chosen + robots
    similarity = vectors[everyone] @ vectors[everyone].T - np.eye(len(everyone)) * 2
    print('native crew candidates', len(crew), 'max pairwise cosine', round(float(similarity.max()), 3),
          'max announcer cosine', round(float((announcers @ vectors[everyone].T).max()), 3))

if __name__ == '__main__':
    main()
