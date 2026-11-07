# Shield, muzzle and rotor effect polish

## Stages

1. Capture shield contact, cannon muzzle pressure and helicopter downwash through their production paths.
2. Localize shield ripples, shape the cannon gas pulse, and distribute rotor dust with altitude-sensitive motion. Preserve bounded effects, pause, visibility and reduced flashes.
3. Check behavior and lifecycle regressions, review native Forward+ and Compatibility captures, and verify shader prewarming.

## Agent progress

- Inspection found whole-hull shield flashes, constant-speed circular muzzle waves and one-sided rotor dust. Prior beam, impact and smoke improvements remain intact.
- Completed all three stages. Shield hits now send a short curved ripple from the contact side, sized from the collider and attached to the vehicle's interpolated pose. The shared shell mesh and maximum of 24 live ripples bound rendering work; expiry, deleted/dead/hidden targets, restoration and reduced flashes remove the effects. Shield absorption no longer reuses the hull damage flash.
- Cannon fire now emits three overlapping gas jets tapering along the bore. Its smaller pressure front expands quickly and softens over 0.18 seconds; native distortion and Compatibility share the same timing envelope. Production and prewarming share the muzzle mesh factory, and prewarming includes the new shield shader.
- Rotor wash now emits five uneven outward dust wisps, samples terrain under each, and smoothly reduces dust opacity, velocity and foliage force with altitude. It retains biome colors and remains visible with reduced flashes. No combat values, camera behavior or faction damage identities changed.
- Six focused headless checks passed: ContactEffectsRegression, CombatPresentationRegression, ImpactEffectsRegression, BattleFeedbackRegression, ShieldComponentRegression and PlasmaShieldsRegression. Coverage includes struck-side orientation, attachment, frame cadence, pause, reduced flashes during pause, limits, visibility, deletion, restore suppression, muzzle direction/taper, radial ground-level wash and altitude falloff.
- Native Forward+ and Compatibility ContactEffectsPreview passed; reviewed the production-path shield, cannon and rotor sequences, including the reduced-flash capture. CombatPrewarmRegression passed with explicit live-shield age/pose/material preservation checks. Compatibility still uses a plain preview floor because of the existing terrain sampler limit documented in the impact-effects plan. Editor import, formatting, lint and whitespace checks passed. Final clip: `art/contact-polish/contact-effects.mp4`; logs: `tmp/contact-polish/`.
- Broader VehicleDamageVisualsRegression reports one missing generated Frontier AntiAirVehicle plate-rank assertion. Reproduced exactly on the unchanged HEAD archive at `tmp/battle-effects/baseline`; generated models were not changed. Forward+ retains the previously reproduced particle-shader/RID shutdown diagnostics after successful checks.
