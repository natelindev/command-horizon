# Modeling and battlefield readability

## Stage 1 — Verify the audits

Measure instantiated scenery and faction models, inspect the export/import paths,
and reproduce animation failures. Distinguish asset defects from measurement or
test-timing errors. Keep gameplay collision and navigation authority unchanged.

## Stage 2 — Scenery scale and occlusion

Normalize oversized civilian architecture in its generators. Add depth-tested
occlusion silhouettes for visible mobile units, preserving fog and cloak rules,
articulation, batching and both renderers. Retain the established smooth camera;
validate readability behind buildings and terrain before considering cutaways.

## Stage 3 — Unit assets and presentation

Reduce excessive tank and wheel geometry while preserving pivots, track data,
team colors and weathering. Use one normalization policy for equivalent faction
models. Repair confirmed animation/rig defects and verify material consolidation
and imported LOD behavior before adding new rendering infrastructure.

## Stage 4 — Verification

Add focused regression coverage, run relevant model/animation/rendering suites,
and inspect graphical scenery, occlusion and weathering previews in both renderers.
Record measured changes, remaining limitations and justified audit deviations.

## Agent progress

- Started from the completed ability/world-feedback implementation; those changes
  remain in the working tree.
- Confirmed imported GLBs already request generated LODs, and occluded selection
  already exists. The audit's proposed blanket additions need runtime validation.
- Investigating runtime bounds and render-frame assumptions in animation tests.
- Civilian generators now normalize fourteen buildings to 3.2–4.5 m rooflines;
  fixed temperate roof rotations and baked static world-space transforms so
  diagonal details retain accurate bounds. Map collision footprints are intact.
- Shared faction normalization now covers Bastion mobile models as well. The
  legacy tank measured 3.06 m long at runtime; the shared policy caps it at 1.665 m.
- Tank topology reduced from 12,640 to 3,188 triangles. Frontier vehicles shed
  45–50% of their geometry by removing tiny tread bevels and simplifying wheels.
  Rebuilt missing Siege Colossus / Frontier antenna pivots and SAM scrap ranks.
- Added visibility-owned occlusion silhouettes, including the native pose path.
  Initial pixel assertions pass on Forward+ and Compatibility, covering visible,
  unoccluded and hidden units. The camera angle remains unchanged.
- Imported meshes already have LODs, but native surface merging dropped them.
  The batcher now preserves up to three index-only levels and their pose indices.
- Moved the shared controller into `UnitVisuals.gd`; the old script remains a
  compatibility entry point and established scene-node names remain stable.
- Corrected the animation regression fixture: its camera now opts out of
  interpolation during teleports and corpse settling uses simulation time.
  All original animation assertions and new resting-pose checks pass.
- Final validation caught and fixed the normalizer selecting the legacy Bastion
  helicopter. The current `air-v1` model is retained and a source-asset regression
  now protects all normalized Bastion base models.
- Team-color regression assertions now inspect the visible finish, allowing the
  material copies used by occlusion. The animation-polish fixture uses the normal
  shutdown path, eliminating its previous teardown resource warnings.
- The occlusion previews now cover an actual alpine massif and cliff cluster,
  observed cloaked infantry, fully hidden units, and the unobscured control model
  in both Forward+ and Compatibility. All pixel assertions pass.
- Nineteen focused headless suites pass, including the original animation failures,
  faction rig/damage checks, model/terrain contracts, texture lifecycle and save/
  aircraft continuity. Frame-count-based save tests pass with `--fixed-fps 60`.
- Native batch material parity, weathering previews for all factions, and terrain
  previews for all five affected battlefields pass on Forward+. Reviewed the
  captures in `art/occlusion/`, `art/weathering/`, and `art/terrain-layers/`.
- The broad `Skirmish.gd` fixture still requests a Bastion-only ForwardRefinery for
  other factions and then fails during cleanup. The first failure reproduces on
  unchanged commit `2ce00183`; it is outside the modeling changes. Compatibility
  retains existing BPTC-to-RGBA8 conversion warnings. Full-map Compatibility
  rendering is not certified by the neutral-floor occlusion gallery.
- Audit decisions: retain the existing camera pitch and opaque scenery after
  validating silhouettes through both buildings and terrain. Avoid billboard LODs
  that would discard articulation; preserve the importer's index-only LODs instead.
  Frontier wheel material surfaces fell from four to three without flattening
  rubber/metal finishes or changing team colors. A whole-roster texture-atlas
  rewrite and extra polygons for already-readable walkers were not warranted.
- Added `UnitLodRegression` to measure the native vehicle batches independently
  of map scenery. At camera size 48 with six faction vehicles, automatic LOD
  reduced frame primitives from 65,524 to 49,324 (24.7%). This is a geometry check,
  not a frame-time benchmark. Native pose batching remains Forward+-only;
  Compatibility uses the ordinary imported mesh path.
- Final changed-script formatting/lint and whitespace checks pass. Detailed
  test commands, asset metrics, scope decisions and known limitations are in
  [verification results](../playtests/2026-11-07/modeling-readability/results.json).
