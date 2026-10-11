# Battle impact upgrade

## Stage 1 — Combat presentation
Completed: layered muzzle discharge, directional sparks, turbulent smoke, radial dust jets, brief ignition, missile trails aligned with their trajectory, burning wrecks and damage smoke. Cosmetic randomness remains separate from combat authority. Rocket infantry now receives explosive impact visuals and audio. Destructible cars, tugs and buildings use the same explosion layers.

## Stage 2 — Battlefield aftermath and audio
Completed: Godot `RigidBody3D` fragments with gravity, angular momentum, continuous collision detection, friction and restitution. Bodies collide with the existing terrain only; collision layer zero excludes them from unit selection and gameplay collision queries. The body transform is never manually integrated or scaled.

Debris stays sparse: 2–5 fragments per explosion, at most 32 live fragments, removed within 2.8 seconds. There are at most 96 ground scars, 24 wrecks and eight brief blast lights. Nearby repeated hits reuse a scar. Scars fade after 85 seconds and expire at 100 seconds; they are visual overlays, not terrain deformation. They are transient and are not saved.

Reworked the original synthesized audio with stronger noise-based concussion, longer low-frequency tails, scattered impact fragments and irregular outdoor reflections. Every cue has three deterministic sample variants, selected without immediate repetition. The 24-voice limit, observation filtering, mute controls and speech ducking remain active. Pausing also suspends pending audio physics ticks. Reduced Flashes suppresses fire/spark/flash emissions and blast lights.

## Stage 3 — Verification
Completed:
- `tests/headless/CombatRegression.gd`: passed combat authority, projectile flight/pause, armor, targeting and repair scenarios.
- `tests/headless/CombatAudioRegression.gd`: zero failures, including nonrepeating takes, rocket impacts, observation, pause/mute, saturation, destruction priority and save/restore.
- `tests/headless/BattleAftermathRegression.gd`: zero failures; real rigid-body flight, ground collision, settling, pause, sparse debris budget, air-impact ground-scar exclusion, repeated-hit merging, expiry and Reduced Flashes.
- `tests/headless/NeutralWorldRegression.gd`: zero failures.
- `tests/rendered/CombatPreview.gd`: actual mixed battle produced 115 shots, 109 impacts and 11 deaths; pause and bounded pools passed. Inspected battle and controlled impact/aftermath captures.
- `tests/rendered/CombatAudioPreview.gd`: zero failures; measured stereo direction, pause/settings/resume, visibility loss, speech ducking and peak-limited 24-voice mix. Music is muted in this measurement fixture to isolate the combat bus.
- GDScript lint for changed combat/effects/test scripts and `git diff --check`: passed.

Review artifacts: `art/skirmish/combat-preview.mp4`, `art/skirmish/combat-{120,240,360}.png`, `art/skirmish/impact-{6,35,170}.png`, and the audio audition/runtime WAVs and JSON reports in `art/audio/`.

Limitations: ground damage does not deform terrain or change navigation. Physics is applied to sparse fragments; gameplay units and wreck settling retain their existing authoritative/animated motion. The rendered audio harness reports null-material warnings during match teardown, also reproduced with the previous combat-effects implementation; some existing match tests report resource/ObjectDB shutdown warnings. No battle-time script or shader failures were observed.

## Agent progress
- All three stages completed.
- Incorporated user direction to reduce debris and use Godot physics.
- Removed unrelated importer metadata churn.

### Smoke readability follow-up
- Reduced smoke lifetime from 4.8 to 1.8 seconds and growth from 1.65 to 1.15. Explosions emit two smaller, lighter smoke wisps instead of six.
- Wreck smoke stops after four seconds, emits less often, and uses smaller, more transparent puffs. Damage smoke starts below 30% health and emits every 0.8 seconds. Destructible scenery smoke is similarly reduced.
- Re-rendered and visually inspected the mixed battle: 111 shots, 105 impacts, 11 deaths; pause and bounded-pool checks passed. Refreshed preview video and stills. Effects/animation lint and diff whitespace checks passed; NeutralTarget retains its pre-existing declaration-order lint warning.
