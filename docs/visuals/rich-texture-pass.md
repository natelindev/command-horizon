# Rich texture pass

## Goal

Make battles read as richly textured at normal RTS zoom (size 28, roughly
32–39 screen pixels per ground metre) without changing gameplay, navigation,
fog of war, team colors or the per-biome art direction. Art direction is
stylized-realistic: scanned CC0 ground materials and weathered vehicles over the
existing low-poly silhouettes.

The previous texture pass (`texture-material-pass.md`) added 2 m tiling concrete,
asphalt and armor panels. Those details average out from the battle camera, so
this pass works at the scales that remain visible: 15–80 m aerial ground scans,
height-blended material transitions, macro variation, ground decals and baked
model shading.

## Stages

1. **Terrain texture library.** Download CC0 Poly Haven aerial scans (color,
   OpenGL normal, roughness, height, AO), record URLs/checksums, and generate packed
   roughness/height/AO maps with a reproducible script. Expose biome presets from
   `SurfaceTextures.gd`.
2. **Shared ground detail.** Add `terrain_layers.gdshaderinc`: base/path/accent
   layers, anti-tiling, mean-normalized detail around each shader's authored
   color, height-based mask blending, world-space normals that also work on sloped
   backdrops. Integrate into `battlefield.gdshader` (13 catalog maps) first and
   review renders before rolling out.
3. **Roll out to every ground.** Desert, frontier, alpine, split signal, coastal,
   quarry, supply, foundry, horizon, district (industrial) and the authored/campaign
   terrains, plus their exterior backdrops.
4. **Model weathering.** Bake ambient occlusion and an edge-wear mask into vertex
   colors in the Blender build scripts for all three factions; extend the armor
   shaders to show grime in crevices and worn metal on edges. Team trim inherits
   the occlusion through the shared player material.
5. **Ground decals.** Generated decal atlas (tire tracks, oil stains, cracks,
   debris) placed deterministically per map away from gameplay markings, using
   Godot `Decal` nodes restricted to the ground render layer.
6. **Lighting polish.** Tune per-biome grading/exposure only where the new
   textures need it; keep existing regression contracts.
7. **Verification.** Headless regressions, rendered before/after captures for
   every biome and faction, and a GPU frame-time comparison.

## Agent progress

- Surveyed ground shaders per map, camera density, lighting controller and the
  Blender faction pipeline (no UVs or vertex colors; team material already
  multiplies vertex color).
- Selected Poly Haven aerial candidates and reviewed their diffuse maps.
- Stage 1 done: `tools/textures/build_terrain_textures.py` downloads eight CC0
  Poly Haven scans (grass, ground rock, sand, coast sand, dirt, asphalt, snow,
  concrete) with checksums in `assets/textures/terrain/sources.json`, and packs
  roughness/height/AO into lossless WebP. 28 MB on disk; VRAM-compressed with
  mipmaps (BC5 normals, BC7 data maps).
- Stage 2 done: `terrain_layers.gdshaderinc` (mean-normalized detail, rotated
  second projection, softened height blending, world-space normals) is live in
  `battlefield.gdshader`; `TerrainTextures.gd` holds biome presets. Snow and
  pebble strengths were reduced after render review.
- Stage 3 done: every ground shader (desert, frontier, alpine, split signal,
  coastal, quarry, supply, foundry, horizon, district) and its exterior backdrop
  uses the layers; `Map._enter_tree` configures scene materials by shader. The
  legacy salmon `terrain.material.tres` became a temperate battlefield and
  campaign hero theaters use the battlefield shader per mission biome. The
  training arena grid is intentionally unchanged.
- `tests/rendered/TerrainLayersPreview.gd` captures 25 maps (battle, field,
  overview and detail, with detail-off controls) to `art/terrain-layers/`; all
  batches pass with no shader or runtime errors.
- Stage 4 done: `art/common/weathering.py` bakes hemisphere occlusion (with the
  battlefield plane as an occluder) and inverted bevel-edge wear into COLOR_0 in
  the Bastion unit/structure, Helix and Frontier builders. Large faces and
  triangulated quad halves share one sample, single-sided canopies use their
  open side, and corner samples are inset; these fixed roof darkening and
  diagonal ramps seen in review. GLB triangle manifests and all four Blender
  verifiers are unchanged/passing; icons and `.blend` catalogues were not
  regenerated. Godot imports enable vertex-color albedo, so team trim and plain
  materials get occlusion; armor, Frontier and construction shaders apply grime,
  chipped edges and a lower-hull dust gradient through `weathered()`.
- `tests/rendered/WeatheringPreview.gd` captures each faction's vehicles and base
  with `-weathering-off` controls (white vertex colors) to `art/weathering/`.
- Stage 5 done: `tools/textures/generate_ground_decals.py` writes nine seeded
  decal textures; `GroundDecals.gd` places oil stains, skid marks, cracks and
  repairs along each map's road segments (read from its ground material, kept
  inside the battlefield) and tracks, scuffs and debris across open ground,
  tinted per biome. Decals use Godot `Decal` nodes limited to render layer 11
  ("Ground decals"), which only the terrain joins; placement is seeded by the map
  scene and is identical after save/restore.
- Stage 6 done: the night, rain, mist, golden-hour and biome captures from
  `VisualWorldPreview` show the existing per-biome grading suits the new
  textures; no lighting values were changed.
- Stage 7, performance: A/B against HEAD with `BattleFrameBenchmark`
  (ExpandedDesertFrontier, 1440×900 window at 2304×1296 pixels, M1 Pro, Metal,
  vsync off; GPU timestamps unavailable on Metal; other Godot test sessions were
  running, so absolute values are inflated). The first shader version cost
  +3.9 ms (base) / +3.1 ms (70-unit combat). Exact mask-based layer skipping with
  explicit gradients reduced this to about +2.8 / +1.8 ms (HEAD 9.7 / 12.4 ms;
  rich 12.5 / 14.2 ms mean, combat p95 18.7 vs 16.3 under the same load).
  Decals cost about 0.3 ms. A new **Ground detail** graphics setting (default
  on) turns layers and decals off through the `ground_detail` shader global;
  measured off: 10.35 / 12.8 ms. Combat p95 may exceed the 16.7 ms working budget
  in `docs/performance/GAME_POLISH.md` with the setting on; a quiet-machine
  measurement is still needed.
- Stage 7, verification: new `RichTexturesRegression` (imports, all ground shader
  parsers, weathering on every faction GLB, layered ground and backdrops on 11
  maps, ground-only in-bounds decals, setting toggle, identical decals after
  save/restore) passes. SurfaceTextures, Graphics, Settings, MenuArt,
  ArtDirection, ConstructionStyle and MapStartup regressions pass.
  `TerrainLayersPreview` additionally checks that the setting renders exactly
  the authored ground. All GDScript parses; gdformat, gdlint and
  `git diff --check` are clean.
- Pre-existing failures, reproduced identically on a clean HEAD worktree:
  ArmorPreservationRegression (scripted orders removed in v0.12.0) and
  SaveRestoreRegression (`_retreating` on WaitingForTargets, then watchdog).
  VisualWorldPreview's hidden-base check reads the fog's navy tint (6, 8, 11),
  uniform across unexplored ground, against an older pure-black threshold; no
  base is revealed. Its missing output directory is now created by the harness.
- Final review of all 25 maps: paved catalog presets (urban, coastal) lowered the
  concrete base to 0.32 strength because its stains repeated visibly when it fills
  the view. Campaign maps skip the setting pixel comparison because the briefing
  camera pans between captures. All rendered batches pass.
