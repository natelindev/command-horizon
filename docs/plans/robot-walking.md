# Robot walking

## Stage 1 — Inspect
Capture the current combat and repair robots. Check model articulation, ground
contact, stopping, and gait timing across render and physics rates.

## Stage 2 — Articulate and animate
Add knee and ankle pivots to the Bastion combat walker and Helix walkers through
their model generators. Solve each leg to a planted or lifted foot target, with
deliberate servo steps and level soles. Keep gait timing tied to travel and retain
the stride between simulation updates. Keep changes within visual geometry.

## Stage 3 — Verify
Test actual foot contact, joint movement, frame cadence, stopping, bracing, and
gameplay invariance. Render and inspect the affected robots and run relevant
animation and asset regressions.

## Agent progress
- Stage 1 complete: before captures are in `art/animation/robot-before/`.
  Confirmed rigid legs and stride resets between physics ticks.
- Stage 2 complete: rebuilt Bastion CombatRobot and Helix LancerWalker/MenderRobot
  through their generators, with separate hip, knee and ankle pivots. Feet now
  lift, transfer and plant with level soles; chassis height respects joint reach.
  Turning and reversing preserve planted ankle positions. Factory departures
  animate and transfer the same gait state to the spawned unit.
- Stage 3 complete: UnitAnimationRegression, UnitMotionRegression,
  StructureActivityRegression (including both robot roles in all factions),
  RichTexturesRegression, and CombatJuiceRegression pass. GDScript lint,
  formatting, Python compilation and diff whitespace checks pass.
- Regression coverage includes actual ankle contact and joint reach, knee
  articulation, support pairs, slow/full-speed travel, curved and pivot turns,
  reversing, five mid-stride stopping points, bracing, 30–1000 Hz render cadence,
  and departure handoff. Existing animation checks cover gameplay invariance.
- Reviewed rendered close-up contact sheets for all three walkers. Reproduce
  with `tests/rendered/RobotGaitPreview.gd` without `--headless`, using
  `--fixed-fps 60`. Frames and sheets are in `art/animation/robot-gait/`; the
  combined motion preview is `art/animation/robot-gait/robot-walking.mp4`.
- Limitations: contact uses the unit's ground plane rather than per-foot terrain
  raycasts. Abrupt displacements outside joint reach remain clamped. Several
  existing game-fixture suites emit resource/ObjectDB warnings at shutdown even
  with zero assertion failures; the texture suite and final preview exit cleanly.
