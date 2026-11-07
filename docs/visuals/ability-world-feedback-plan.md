# Ability and world feedback

## Stage 1 — Abilities and shield lifecycle

Implement observed phase-shift endpoints, bounded shield break/recharge shells,
friendly/observed cloak transitions, persistent Flux Resonance and Industrial
Overhaul cues, and floating guidance chaff. Read authoritative state for persistent
effects so restored matches reconstruct presentation without replaying activations.

## Stage 2 — Locomotion and vehicle identity

Cover wheeled ground vehicles with tire wear, exclude hovercraft from contact
marks, use radial repulsor wash, and synchronize Frontier exhaust backfire with
acceleration stress. Preserve faction damage profiles and cosmetic RNG isolation.

## Stage 3 — Placement, completion and water

Add scanned holographic blueprints and terrain-conforming footprint/grid guidance,
faction completion bursts, and heavy water geysers. Respect pause, visibility,
reduced flashes, bounded effect pools, and Compatibility rendering throughout.

## Verification

Add focused regression coverage for lifecycle, visibility, restoration, budgets,
and locomotion classification. Run relevant existing gameplay/effect tests, format
and lint changed scripts, and inspect graphical previews in Forward+ and
Compatibility. Record actual results and limitations below.

## Agent progress

- Inspected the effect pools, shield signals, ability persistence, construction
  lifecycle, placement validation, and vehicle presentation hooks. Working tree
  was clean at the start.
- Stage 1 complete: successful phase shifts emit independently observed origin
  and arrival effects; shields have break, recharge and restored contours; cloak
  surfaces fade while preserving the original materials and fog authority.
  Flux Resonance, Industrial Overhaul and guidance chaff derive their persistent
  cues from authoritative state and reconstruct after save/load. Their pools are
  bounded and animation respects pause and reduced flashes.
- Stage 2 complete: wheeled roles leave closely spaced tire contact marks;
  Helix skimmers leave radial dust wash without tread marks. Frontier backfire
  visuals and audio now share acceleration/damage stress and a cooldown.
- Stage 3 complete: placement uses scanned holograms, terrain-conforming grids
  and production-exit arrows. Completion emits faction-specific bursts and
  audio. Heavy water impacts produce a vertical foam plume and collapsing mist
  instead of ground debris and fire.
- Verified and fixed two presentation regressions: a concealed sniper loaded
  while paused appeared opaque; and the multiplicative wear overlay darkened
  untouched terrain in Compatibility. The cloak now initializes from saved
  state while paused, and wear uses transparent black attenuation. Focused
  integration and image assertions cover both scenarios.
- Validation on Godot 4.7.2 / Apple M1 Pro: 16 headless suites clean; new
  `WorldFeedbackRegression` and `AbilityFeedbackIntegration` both pass. All 25
  changed/new GDScript files pass formatting and lint; editor import and
  `git diff --check` pass.
- All five graphical checks pass: world-feedback galleries in Forward+ and
  Compatibility, `CombatPrewarmRegression`, `UnitBatchRegression` with native
  kernels, and `TerrainLayersPreview` on Industrial Crossroads and Redrock
  Divide. Reviewed captures in `art/world-feedback/` and `art/terrain-layers/`.
  The effect gallery uses a neutral floor with scene weather/grading disabled
  to isolate the effects; it does not certify full-map Compatibility rendering.
- Broader checks retain baseline issues: missing Frontier anti-air scrap-plate
  ranks, four animation/corpse assertions, four antenna/inertia assertions, and
  teardown warnings in the animation/foundry tests. Reproduced these on unchanged
  commit `2ce00183`. Compatibility also reports existing BPTC-to-RGBA8 texture
  conversion warnings. Detailed commands and outcomes are in
  [verification results](../playtests/2026-11-07/ability-world-feedback/results.json).
