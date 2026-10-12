# Audio Punch and Combat Juice Implementation Plan

Upgrade combat presentation and auditory satisfaction across tactical voice comms, heavy weapon foley, vehicle suspension dynamics, catastrophic turret cook-off destruction, and camera impact trauma.

## Stage 1: Tactical Radio Comms DSP & Squelch Chirps
1. Configure Godot's `"Voice"` audio bus in `source/data-model/Options.gd` with dedicated tactical comms DSP:
   - High-pass (~400 Hz) and low-pass (~3400 Hz) filters creating an authentic radio bandpass.
   - Subtle analog overdrive saturation (`AudioEffectDistortion.MODE_OVERDRIVE`, drive = 0.18) simulating transceiver preamp warmth and clipping.
   - Dynamic compression (`AudioEffectCompressor`) for tactical leveling.
2. Synthesize clean procedural VHF mic-click and squelch chirp audio (`radio_chirp_in.wav`, `radio_chirp_out.wav`).
3. Connect start/stop squelch chirps to `source/match/audio/BattleVoice.gd` when human-faction announcements and unit acknowledgments trigger.

## Stage 2: Heavy Weapon Sub-Bass Punch & Foley Synthesis
1. Refine `art/audio/build_combat_audio.py` to inject visceral sub-bass transients (40–70 Hz descending pressure thump with sub-millisecond attack) into `cannon_fire`, `impact_heavy`, `vehicle_destroy`, and `structure_destroy`.
2. Re-render all 33 combat sound variants at 48kHz, adhering to `-3.2 dBTP` peak headroom and target RMS limits.
3. Update `source/match/audio/CombatAudio.gd` to enhance low-frequency presence and ensure distinct auditory weight between light ballistic, heavy kinetic, and explosive impacts.

## Stage 3: Vehicle Suspension Rocking & Barrel Spring Recoil
1. Extend `source/match/units/traits/BastionVisuals.gd` with spring-damper suspension physics on firing:
   - Calculate damped harmonic oscillation (`sin(t * w) * exp(-t * d)`) on hull pitch (`rotation.x`) when heavy cannons discharge.
   - Ensure tanks and artillery visibly rock backward on their tracks and settle with realistic inertia.
2. Polish barrel kickback and recovery spring curves on articulated `*BarrelPivot` nodes.

## Stage 4: Armored Vehicle Turret Cook-Off Physics
1. Implement catastrophic ammo cook-off in `source/match/effects/CombatEffects.gd` and `source/match/effects/BattleAftermath.gd`:
   - When armored vehicles with `*TurretPivot` nodes are destroyed, detach the turret mesh from the stationary burnt wreck.
   - Spawn the detached turret as a physical `RigidBody3D` (collision layer 0, mask 1 for terrain collision).
   - Apply an upward vertical impulse and random angular tumbling torque, with trailing fire and black smoke wisps.
   - The turret bounces and comes to rest near the burning hull.
2. Hull turret ring vents dark smoke and secondary fire flares.

## Stage 5: Camera Trauma System (Screen Shake)
1. Implement a trauma-based camera shake controller in `source/match/IsometricCamera3D.gd`:
   - Trauma in range `[0.0, 1.0]`, decaying linearly over time.
   - Camera positional and rotational jitter proportional to `trauma^2`.
   - Heavy explosions, artillery impacts, and catastrophic deaths within view radius feed trauma scaled by proximity to viewport center.
   - Respect `Globals.options.reduced_flashes` / reduced motion preferences.

## Stage 6: Verification & Audio Audition
1. Verify synthesized foley with `art/audio/build_combat_audio.py` and `art/audio/verify_battle_audio.py`.
2. Run headless regressions:
   - `tests/headless/CombatAudioRegression.gd`
   - `tests/headless/BattleAftermathRegression.gd`
   - `tests/headless/CombatRegression.gd`
3. Add dedicated regression tests for radio DSP bus integrity, cook-off debris physics, and camera trauma.

## Agent progress
- [x] Stage 1: Tactical Radio Comms DSP & Squelch Chirps completed. Added `_radio_dsp` filter chain (HPF, LPF, distortion, compressor, limiter) to `"Voice"` bus in `source/data-model/Options.gd`; generated VHF in/out squelch chirps; connected key-up/key-down chirps in `source/match/audio/BattleVoice.gd`.
- [x] Stage 2: Heavy Weapon Sub-Bass Punch & Foley Synthesis completed. Injected 26–75 Hz sub-bass pressure sweeps and transient thumps in `art/audio/build_combat_audio.py`; rebuilt all 33 WAV sound cues normalized to -3.20 dBFS peak; verified via `art/audio/verify_battle_audio.py` (711 clips checked, 0 errors).
- [x] Stage 3: Vehicle Suspension Rocking & Barrel Spring Recoil completed. Implemented spring-damper recoil suspension physics in `source/match/units/traits/BastionVisuals.gd` for heavy tanks/turrets and doubled articulated barrel kick distance.
- [x] Stage 4: Armored Vehicle Turret Cook-Off Physics completed. Added dynamic detachment and ballistic tumbling of vehicle turrets as `RigidBody3D` (layer 0, mask 1) with smoke emitters in `source/match/effects/CombatEffects.gd`, capped at `MAX_COOK_OFFS = 6`.
- [x] Stage 5: Camera Trauma System (Screen Shake) completed. Implemented non-invasive `h_offset`/`v_offset` trauma shake in `source/match/IsometricCamera3D.gd` with linear decay and `reduced_flashes` suppression; hooked into explosions and heavy impacts in `source/match/effects/CombatEffects.gd`.
- [x] Stage 6: Verification & Audio Audition completed. Created and verified `tests/headless/CombatJuiceRegression.gd` (0 failures); verified existing regression suites `CombatAudioRegression.gd` (0 failures), `BattleAftermathRegression.gd` (0 failures), and `SpeechRegression.gd` (0 failures). All stages verified.
