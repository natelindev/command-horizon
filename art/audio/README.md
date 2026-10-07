# Original combat audio

These eleven game cues are original procedural sound design, built entirely from
seeded random noise, smooth frequency shaping, short descending pressure pulses,
inharmonic resonances, and irregular debris events. They contain no third-party
samples, recordings, synthesized voices, or text-to-speech. Their source is
`build_combat_audio.py`; the generated files belong to this project under the same
terms as its source. Infantry destruction uses a ground/equipment fall, with no
vocal or graphic bodily effects.

Run from the project root with Python 3 and NumPy:

```sh
python3 art/audio/build_combat_audio.py
```

The generator writes the game assets to `assets/audio/combat/`, then updates
`combat-manifest.json` and `combat-audition.wav` here. Seeds are fixed. A rerun was
verified to produce identical SHA-256 hashes for all eleven cues, the reel, and the
manifest in the development environment (NumPy 2.4.3). NumPy/FFT implementation
changes on other platforms may change least-significant sample bits.

Each game file is mono PCM16 WAV at 48 kHz, with zero-valued boundaries, short
attack/end fades, DC removal, and a -3.2 dBFS measured peak. The manifest records
duration, peak and RMS level, DC offset, deterministic seed, and SHA-256 for each
asset. None is silent or clipped. Cue envelopes and spectra differ; gunfire has
compact attacks, missiles have sustained exhaust, and destruction adds irregular
secondary events. Gain, rate limiting, world position, fog visibility, and the
Effects volume setting are handled by the game playback system.

## Audition reel

`combat-audition.wav` is 15.95 seconds long, with one second of initial silence and
0.8 seconds between cues. Labels are listed below rather than spoken into the
audio. The reel has no normalization beyond the individual cue normalization.

| Start–end (seconds) | File | Character |
| --- | --- | --- |
| 1.00–1.19 | `rifle_fire.wav` | Sharp dry crack, short bolt tick |
| 1.99–2.27 | `autocannon_fire.wav` | Weightier report, mechanical clack |
| 3.07–3.75 | `cannon_fire.wav` | Bass concussion, turbulent tail |
| 4.55–4.80 | `energy_fire.wav` | Electrical snap, fizz, inharmonic discharge |
| 5.60–5.99 | `rail_fire.wav` | Induction crack, pressure, metallic trace |
| 6.79–7.38 | `missile_launch.wav` | Ignition thump and fluttering exhaust |
| 8.18–8.34 | `impact_light.wav` | Short dry material strike |
| 9.14–9.49 | `impact_heavy.wav` | Armor/material strike and fragments |
| 10.29–10.66 | `infantry_fall.wav` | Ground thud, cloth, equipment settling |
| 11.46–12.70 | `vehicle_destroy.wav` | Chassis explosion and metal debris |
| 13.50–15.15 | `structure_destroy.wav` | Rolling collapse, fractures, grit |

Verification covered deterministic regeneration, container format, sample
duration, peak/RMS bounds, near-zero DC, and click-free zero boundaries. No audio
listening/analysis tool was available during asset generation; subjective listening
and in-game mix review remain necessary, especially at high simultaneous unit
counts. The audition reel supports that review independently of game playback.


## Runtime verification

`combat-runtime.wav` captures measured Master-bus sections from a normal-clock
rendered game: Bastion actual attacks/hits/deaths, left/right cannon cues, the
Settings sample, 24 overlapping destruction cues with speech, then Helix actual
combat. `combat-runtime.json` stores per-section peaks and stereo energy. This is
separate from the isolated asset reel above. The rendered checks pass nonzero
output, direction, pause/Settings freeze/resume, observation loss, voice ducking
and output ceilings. See [combat verification](../../docs/playtests/2026-10-03/COMBAT_AUDIO.md)
for reproduction and the remaining subjective-listening acceptance.
