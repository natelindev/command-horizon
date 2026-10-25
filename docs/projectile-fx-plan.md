# Projectile and exhaust polish

1. Replace flight boxes with lightweight, vertex-colored meshes for each projectile kind; preserve batching, pooling, interpolation, and nose alignment.
2. Sample burning flight segments by distance and add overlapping exhaust with a hot core cooling into expanding smoke.
3. Add regression coverage for geometry, transforms, pooling, and trail continuity; inspect rendered output and run the five requested suites plus whitespace checks.

## Agent progress

- Inspected projectile simulation, renderer, particle shaders, and existing previews/tests.
- Preserved the existing uncommitted beam/charge changes.

- Completed six lightweight indexed flight meshes with solid fins/shrouds, smooth radial normals, vertex-controlled emission, and correct local-axis scaling. Retained 384-slot MultiMesh pools and interpolation.
- Replaced timer-based smoke with 0.4 m sampling and a spatial remainder across ticks; covered partial burnout, turns, visibility, and collision clipping. Added separate bounded smoke/exhaust buffers and a short hot-to-cool core.
- Added disposable loading-screen preparation for the projectile shader; the native CombatPrewarmRegression passed with 0 failures, including state preservation and cancellation.
- Added ProjectileVisualRegression covering winding, mesh budgets, emission masks, diagonal/vertical nose alignment, hidden geometry, slot saturation/reuse, continuous 35 m/s trails, burnout, ground impact, pause, and reduced flashes. Passed with 0 failures.
- Ran all five requested headless suites with --fixed-fps 60 after the final changes: ProjectileSystemRegression, CombatPresentationRegression, PreparationRegression, CombatJuiceRegression, and BattleFeedbackRegression. All exited 0 with no test failures.
- Reviewed native Forward+ captures from ProjectilePolishPreview: geometry.png, continuous-exhaust.png, and cooling-smoke.png under art/projectile-polish/. Preview exited 0 with 0 failures, including pixel checks against a baseline to reject empty exhaust/smoke captures. Forced draws advance GPU particle time even when the native window loses focus.
- GDScript format/lint and git diff --check passed. Some broad suites retain the shutdown ObjectDB/resource diagnostics already present in prior logs; the focused visual test and native previews exit cleanly.
