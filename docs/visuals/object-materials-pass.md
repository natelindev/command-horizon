# Object materials, lighting and shadows

## Goal

Give units, buildings, people, trees, rocks, grass and bushes material-appropriate
surface detail in normal play and close views. Keep faction colors, gameplay
footprints, visibility, navigation and save compatibility intact.

## Stages

1. Audit material assignments, including generated infantry and batched scenery.
   Acquire reproducible bark/stone scans and original ImageGen foliage/canvas.
2. Apply shared, physically lit object materials at model creation and map
   assembly. Preserve authored specialized shaders, optical materials and team
   colors. Restore shadows on small scenery.
3. Add regressions for coverage, material ownership, batching, construction,
   save/restore and graphics settings. Review actual rendered scenes with all
   factions, vegetation, civilian buildings and people in daylight and at night.
4. Record verification results and remaining limitations.
5. Follow up on shutdown resource retention and invalid benchmark timing; verify
   clean shutdown and actual rendered-frame measurements.

## Agent progress

- Existing terrain and armor textures are present; most other imported materials
  and generated infantry still have flat albedo colors.
- `TerrainDressing` explicitly disables shadows on all batches under 1.2 m.
- Generated original foliage and woven canvas using the built-in ImageGen tool.
  Also generated fine conifer/grass needles. Originals and exact prompts live in
  `assets/textures/objects/generated/`; all are imported with mipmaps and a 1K cap.
- Downloaded six unmodified CC0 bark/stone maps with recorded checksums and a
  reproducible fetcher. Shared asphalt, concrete and armor maps are reused.
- Added object-space triplanar materials for twelve surface families, plus
  asphalt. Original palettes, vertex shading and physical surface properties are
  retained. Protected glass, emission, water, markings and team colors retain
  their own materials.
- Covered ordinary imported meshes, generated infantry and equipment, actor coat
  overrides, merged scenery, primitive MultiMeshes, depleted resources, carried
  cargo and structure task-light housings. Value-keyed caches remain bounded
  through save/restore; source meshes/materials are not modified.
- Added scanned detail and normal maps to the existing desert, alpine, coastal
  and canyon rock shaders while preserving biome-specific layers and snow.
  Fixed coastal material routing that treated pine bark as stone.
- Restored shadows on small dressing batches and landmark vegetation. Reduced
  directional normal bias from 0.65 to 0.35 and raised the shadow atlas to 4096.
  The existing shadow/AO controls still apply.
- Render review exposed DuneGrass using solid shrub geometry. Its generator now
  builds 60 bent/tapered blades (360 triangles), radius 0.718 m and height 0.6885 m
  within the original 1.1 m / 0.9 m limits. Regenerated its GLB, editable kit and
  manifest; gameplay footprints and placement rules are unchanged.
- Completed automated coverage and rendered comparison harnesses. The object
  audit passes for 344 imported models and 7,295 eligible textured surfaces,
  plus generated faction rosters and runtime geometry.
- Passed `SurfaceTexturesRegression`, `RichTexturesRegression`,
  `GraphicsRegression`, construction styles, campaign interiors and airfield
  operations checks. Coverage includes construction completion, depletion,
  batching, source-material immutability and save/restore.
- Reviewed 27 object-material captures, including texture-off and shadow-off
  comparisons, all three factions, infantry, vehicles, bases, civilian people
  and buildings, vegetation, grass and biome rocks. Civilian scenes were checked
  in daylight and at night.
- Existing terrain previews passed across seven map variants; model weathering
  previews passed for all three factions (34 captures). Captures are under
  `art/object-materials/`, `art/terrain-layers/` and `art/weathering/`.
- All 65 changed/new GDScript files pass formatting and lint checks.
  Python compilation and `git diff --check` pass.
- Resolved shutdown retention: object/armor materials, campaign data, battlefield
  layouts and vegetation measurements now use runtime-owned cache buckets.
  Lazy campaign accessors preserve the same data and save identities. The cache
  lifetime regression verifies retained materials are released when cleared.
- Menu Quit and window-close requests stop playback, join outstanding music
  loads and drain audio using wall time before SceneTree teardown. Repeated close
  requests share one shutdown operation. Regression coverage includes pending
  music loads, positional players, pause, zero time scale and `--fixed-fps`.
- The object audit and 27-capture preview now exit without resource/shader leak
  diagnostics, as do surface textures, rich textures, graphics, construction,
  airfield, music, campaign-menu, hero-campaign and interior regressions.
  Verbose Metal logs can report supported texture-format conversions; the
  preview logger correctly distinguishes these warnings from errors.
- Fixed the benchmark: warm up completed renders for at least three seconds,
  measure 240 actual drawn frames per stage, and reject headless/fixed-time runs.
  Both stages pass exact frame-count and real-time simulation checks. On Apple
  M1 Pro / Metal at 2304 × 1296 pixels, Pinebreak Valley measured:
  - Base, 30 units: 12.60 ms mean, 12.90 ms p95, 79.4 FPS.
  - Midfield combat, 70 units: 13.94 ms mean, 14.43 ms p95, 71.8 FPS.
  These are observations from this machine, not a before/after comparison.
  Unsupported GPU timestamps are reported as unavailable. The benchmark exits
  cleanly; detailed verification logs are under `tmp/material-lifecycle/`.
- Follow-up weathering (Bastion aircraft, eight captures) and terrain
  (Pinebreak Valley) previews also pass and exit without leak diagnostics.
