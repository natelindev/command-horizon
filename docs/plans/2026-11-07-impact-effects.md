# Impact and atmospheric effect polish

## Stages

1. Inspect and capture the current explosion, fragmentation, smoke and grenade-flight behavior, preserving the completed beam/charge changes.
2. Give blasts a readable ignition-to-smoke sequence, separate fragmentation from heavy warheads, improve smoke expansion, and use a smooth ballistic grenade arc. Keep cosmetic work bounded and retain pause, visibility and reduced-flash behavior across renderers.
3. Add focused behavior checks, review native effect sequences, and run relevant combat/particle regressions.

## Agent progress

- Inspection found simultaneous fire/smoke emission, constant-rate smoke expansion, grenade reuse of the heavy-warhead effect (including possible duplicate shockwaves), and a sine-shaped grenade arc.
- Completed: explosions now ignite before two bounded stages of rising smoke; fragmentation has a compact radial dirt/spark burst and one pressure ring; airbursts disperse into three floating wisps. Smoke/dust expand quickly then coast, with soft births and shaded lobes shared by GPU and Compatibility particles. GPU particles receive their correct birth size immediately. Grenades follow a distance-scaled parabola, and grenade poses, pressure rings and hit flashes advance per rendered frame while respecting pause. Pressure rings expand quickly, soften and dissipate.
- Verification passed: `ImpactEffectsRegression`, `GrenadeFlightPresentationRegression`, `ManualParticlesRegression`, `CombatPresentationRegression`, `BattleAftermathRegression`, `ProjectileVisualRegression` and `BattleFeedbackRegression`. Checked staged smoke timing, slow frames, pause, bounded tails, restored grenade trajectory, independent gameplay fuse, reduced flashes and projectile trails. Updated stale projectile fixtures to match the current battlefield/shot and terrain contracts.
- Native verification passed: Forward+ `ImpactEffectsPreview`, Compatibility `ImpactEffectsPreview`, native Compatibility `ManualParticlesRegression`, Forward+ `ProjectilePolishPreview` and `CombatPrewarmRegression`. Reviewed ignition, smoke, fragmentation and airburst captures, plus continuous missile exhaust and its cooling wake. Captures are in `art/impact-polish/` and `art/projectile-polish/`; `art/impact-polish/impact-effects.mp4` shows the final sequence. Formatting, lint, editor import and `git diff --check` passed.
- Existing renderer limits: the full Industrial Crossroads terrain exceeds this Mac's OpenGL fragment sampler limit (17–18 used, 16 supported). The Compatibility effect gallery uses a plain floor material before first draw to isolate the changed effects; production terrain is unchanged. Some Forward+ runs retain the previously reproduced particle-shader/RID shutdown diagnostics, after all checks pass. The updated standalone exhaust preview exits cleanly.
