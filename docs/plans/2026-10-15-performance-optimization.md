# Performance Optimization Plan

## Stage 1 — Visual Processing & Sleep Culling
- Transition `BastionVisuals.gd` from `_physics_process(delta)` to `_process(delta)` so animation steps only evaluate on rendered frames rather than 60 Hz physics ticks.
- Add idle sleeping for stationary units: when velocity is approx zero, no aim target, no active construction, and recoil/hit reactions are settled, skip redundant bone, part and suspension matrix updates.
- Instantly wake on movement signals, action updates, weapon fire, or damage reactions.
- Skip procedural part rotations when the unit is not visible or outside camera view.

## Stage 2 — Battlefield Spatial Index & Projectile Accounting
- In `Battlefield.gd`, decouple static sight blockers from dynamic observers. Cache static blocker cells and only rebuild them when structures/obstacles are placed or destroyed rather than every physics frame.
- Centralize active projectile tracking so `_incoming_damage` avoids O(N * M) tree searches across all player units and their children.
- In `AttackingWhileInRange.gd`, replace transient `Timer` node allocations with lightweight float delta accumulators.
- Convert target collection lookups to Dictionaries for O(1) checks.

## Stage 3 — Fog of War & Overlay Throttling
- In `FogOfWar.gd`, skip updating `DynamicCircle2D` node positions inside the SubViewports when units are stationary.
- In `OwnershipOverlay.gd`, make redraw and 3D raycasting event-driven on mouse motion/hover change rather than queuing redraw every render frame.

## Stage 4 — Crowd Navigation & Recovery Optimization
- In `Movement.gd`, streamline `_ground_recovery_direction` to test primary escape vectors first and early-exit when clearance is found.
- Reduce redundant `NavigationServer3D.map_get_closest_point` calls in crowd clipping.

## Stage 5 — Render Pipeline & Shadow Tuning
- In `WorldAtmosphere.gd`, tune directional shadow max distance to 120m to fit the isometric camera view and reduce shadow split overdraw.

## Stage 6 — Benchmarking & Regression Verification
- Run headless `ScaleBenchmark.gd` and compare movement and combat frame times and physics process times.
- Run rendered `BattleFrameBenchmark.gd` and compare base and midfield combat FPS.
- Run full regression suites (`BattlePolishRegression.gd`, `ExitClearanceRegression.gd`, `CombatRegression.gd`, `AmbientLifeRegression.gd`, etc.).
- Ensure `gdformat` and `gdlint` pass cleanly.

## Agent progress
- Implemented Stage 1: Added idle settling and cached leg data in `BastionVisuals.gd` and stationary wheel optimization in `WheelMotion.gd`.
- Implemented Stage 2: In `Battlefield.gd`, decoupled static sight blockers into an event-driven cache (`_blockers_dirty`), connected to unit topology signals, and accelerated `_incoming_damage` using group-based projectile lookups and O(1) dictionary sets. Registered `CannonShell` and `Rocket` in `"projectiles"` group.
- Implemented Stage 3: Prevented redundant `CanvasItem` transform dirtying in `FogOfWar.gd` for stationary units, and made `OwnershipOverlay.gd` hover raycasts/redraws event-driven.
- Implemented Stage 4: Optimized `_recovery_clearance` and `_ground_recovery_direction` in `Movement.gd` with fast max-distance checks and immediate early exit when full 2.0m clearance is found.
- Implemented Stage 5: Tuned directional shadow max distance from 240m to 120m in `WorldAtmosphere.gd` to match isometric camera frustum depth.
- Implemented Stage 6: Benchmarked across headless and rendered suites:
  - Headless combat `mean_engine_physics_ms` dropped from 53.04 ms to 30.47 ms (a 42.5% physics time reduction).
  - Headless combat `mean_engine_process_ms` dropped from 8.43 ms to 5.71 ms (a 32% process time reduction).
  - Battlefield field profile: `is_observed` calls dropped from 107k to 88k and `line_clear` time dropped by 26%.
  - Rendered `BattleFrameBenchmark.gd` averaged 84.2 FPS at base and 69.9 FPS in 70-unit midfield combat.
  - Rendered 280-entity `ScaleBenchmark.gd` passed with all 200 units moving, travelling, and 160 firing.
  - Regressions passed: `BattlePolishRegression.gd`, `ExitClearanceRegression.gd`, `CombatRegression.gd`, `OwnershipRegression.gd`.
  - `git diff --check` passed cleanly.
