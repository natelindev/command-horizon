# Weapon charge presentation

1. Replace the expanding sphere with a compact corona/core, converging sparks, late-charge vibration, and a distinct tactical lock reticle while preserving diagnostic contracts.
2. Add a synthesized capacitor loop to the bounded combat audio pool, driven by the attack action's existing charge lifecycle and audibility rules.
3. Cover charge presentation/audio cancellation and lifecycle with regression checks, inspect native rendered previews, and run the four requested suites plus relevant audio checks.

## Agent progress

- Inspected preparation ownership, cancellation, deployment/restoration, diagnostic captions, and the shared combat audio pool.
- Existing ray-beam changes in the checkout are outside this task and will be preserved.
- Implemented a camera-facing hot core, contracting segmented capacitor rings, arcing corona, bounded inward spark batches, and high-frequency focus vibration above 75% charge. Rocket infantry use contracting tactical brackets and a lock sweep. Diagnostic captions and deployment feet retain their existing behavior.
- Added a shared synthesized capacitor loop to the 24-voice combat pool. Pitch rises from 0.75 to 1.6 with charge; cancellation/firing stop it synchronously. Existing pause, observation/camera, mix ducking, mute, restoration, and battle-end gates apply.
- Native motion checks caught inherited MultiMesh physics interpolation producing outward motion at spawn; disabled interpolation for explicitly frame-animated charge effects and verified inward travel with the graphical renderer.
- Added headless/native regression coverage for charge/lock visuals, reduced flashes, audio pitch/reuse, paused Stop, movement, target loss, firing, deletion, voice saturation/report priority, actual SAM lock, and paused Lancer mode switching.
- Updated the existing preparation preview to explicitly enable F1 diagnostics and click the current visible command-card Stop, rather than its hidden legacy button; it now passes with 0 failures.
- All four requested headless suites passed at fixed 60 fps with exit code 0 and 0 failures: PreparationRegression, UnitInfoTextRegression, CombatPresentationRegression, and CombatJuiceRegression. ChargePresentationRegression and CombatAudioRegression also passed.
- Native Forward+ ChargeEffectsPreview passed with 0 failures and 16 captures under `art/weapon-charge/`; visually reviewed faction core/corona and rocket-lock captures. Native ChargePresentationRegression verified inward sparks, and PreparationPreview verified paused restoration and real Stop input.
- Godot editor import, changed-script formatting/lint, and whitespace checks passed. Unrelated import metadata changes were discarded. Some headless suites retain the repository's shutdown ObjectDB/resource warnings; graphical charge checks shut down cleanly.
