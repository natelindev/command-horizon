# Material and scenery fidelity — 2026-10-25

Implemented the material, scenery and trim stages of the approved plan.
Existing height-aware terrain blending, baked vertex weathering and
terrain-conforming foundation aprons were retained and verified.

## Changes

- Shared cast-metal micro normals and roughness, plus a 2K atlas for recessed
  plates, louvers, fasteners and treads. Normal maps derive from authored
  relief; ORM stores cavity, roughness and exposed metal in separate channels.
- Secondary trim UVs generated before joining rigid meshes. All 74 rebuilt
  faction GLBs retain their previous triangle counts, vertex positions and
  node transforms. Team markings, glass, cloth and UV0 remain protected.
- Bounded leaf/needle card clusters with canopy normals, alpha-scissor shadows
  and backlighting for temperate trees/shrubs and desert sage. Existing bark
  scans and detailed desert leaf geometry are retained.
- Deterministic, shadow-casting meadow grass batches along temperate forest
  ground and road verges, excluding existing gameplay clearances and water.
- GPU batching now handles the detail uniforms and source-local projection.
  Restoring ordinary meshes explicitly restores their material overrides,
  fixing an observed loss of surface textures when units left a GPU batch.

## Verification

Godot 4.7.2, macOS/Metal on Apple M1 Pro; Blender 5.2.1 authoring exports.
The optional native module was built locally for GPU/native parity testing.

| Check | Result |
| --- | --- |
| SurfaceTexturesRegression | Pass; all factions, construction, fog memory and save/load |
| ObjectMaterialsRegression | Pass; 345 models, 7349 surfaces |
| RichTexturesRegression | Pass; scanned ground, decals and baked weathering |
| MaterialFidelityRegression | Pass; maps, trim UVs, protected UV2, cutouts, grass determinism/clearances and apron presence |
| Python texture tests | 4 pass; relief normal axes, periodic noise, packing and alpha borders |
| UnitBatchRegression | Pass; all factions, material pixel parity, visibility, rebatching, copies and cleanup |
| WeatheringPreview | Pass; 34 captures, including 11 aircraft/mobile-AA models |
| ObjectMaterialsPreview | Pass; 27 close/tactical/day/night/detail controls |
| TerrainLayersPreview | Pass; Pinebreak Valley, Four Rivers, Verdant Commons, Desert Frontier battlefield and Desert Frontier campaign |

The GPU/native comparison uses matching full-detail geometry to isolate
material differences from the native mesh LODs. First review led to lower
armor contrast and denser needle coverage. Kit export bounds assertions also
passed. `git diff --check` is clean. GDScript lint passes for the changed
material/terrain/test scripts; the two existing batching scripts retain six
pre-existing lint violations (return-count, definition-order and embedded
shader-string line lengths), confirmed against HEAD.

## Review images

- [Armor close-up](../../../../art/weathering/bastion-vehicles.png)
- [Foliage, scrub and grass](../../../../art/object-materials/vegetation.png)
- [Pinebreak battlefield](../../../../art/terrain-layers/pinebreak-valley-map-overview.png)

Generated review images are local artifacts excluded from Git. Verification
logs are retained beside this report. Rebuild instructions and map/channel
contracts are in `assets/textures/surfaces/README.md` and
`assets/textures/objects/README.md`. No saved-game schema or gameplay collision
changes were made. Other biome vegetation and existing model silhouettes
retain their current art direction; this is a material/scenery fidelity pass.
