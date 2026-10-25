# Rail and Prism beam overhaul

1. Add an additive beam shader with a brief optical core, expanding ionized sheath, and Prism dispersion.
2. Integrate crossed ribbons, faction styling, endpoint bursts, bounded pooling, and loading-screen shader preparation.
3. Cover lifecycle and resource reuse with regression checks, review rendered faction/lifecycle captures, and run the five requested suites.

## Agent progress

- Inspected the instant-rail path, effect pools, particle emitters, and combat preparation.
- Completed additive core/sheath shader, Prism dispersion, crossed ribbons, fixed firing lines, endpoint flashes/ions, 0.24-second lifetimes, and disposable loading-screen preparation.
- Added regression coverage for simultaneous faction beams, geometry alignment, pause/reduced flashes, hidden targets, pool saturation/reuse, zero-length shots, hit-flash cleanup, and release of every pooled material plus the shared mesh.
- All five requested headless suites passed with exit code 0: CombatPresentation, Preparation, ProjectileSystem, CombatJuice, and BattleFeedback.
- Native Forward+ preview passed with 0 failures and 12 captures under `art/ray-beams/`, including optical-core brightness, core extinction before sheath extinction, full expiry, and a lower camera angle for both factions.
- GDScript lint/format, shader formatting, and `git diff --check` passed.
- Some broader suites still report shutdown ObjectDB/resource warnings. The unchanged CombatJuice baseline reproduced these warnings; the focused beam regression and rendered preview shut down cleanly.
