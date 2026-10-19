# Texture material pass

## Scope

Use CC0 Poly Haven materials for industrial roads and concrete, and original
ImageGen surface artwork for faction armor. Preserve team colors, silhouette,
navigation, weather, construction, and fog-of-war behavior. Start with shared
industrial ground/building materials and faction vehicles/structures.

## Stages

1. Acquire modest-resolution matching material maps, record sources/licenses,
   and generate an original neutral armor surface with the built-in ImageGen tool.
2. Integrate textures into existing materials, preserving authored map masks and
   gameplay. Reuse texture/material resources and use mipmapped sampling.
3. Verify imports, actual material assignments, construction restoration, and
   map startup using headless Godot only. Inspect source images separately.
4. With the user's subsequent authorization, launch the renderer, review terrain,
   all three factions and construction at battle/detail zoom, and fix visual issues.

## Verification authorization

Initial implementation was restricted to headless launches. The user subsequently
authorized launching the game directly. Rendered verification is complete;
the earlier headless checks also cover material and gameplay contracts.

## Agent progress

- Inspected current materials: industrial terrain uses procedural masks;
  faction meshes primarily use named, solid-color materials.
- Confirmed Poly Haven's CC0 license and matching color/normal/roughness downloads.
- Acquired six unmodified 1K Poly Haven maps (asphalt and concrete color,
  OpenGL normal, and roughness); recorded URLs, license, authors, and checksums.
- Generated original neutral panel artwork with the built-in ImageGen tool;
  saved its exact prompt and original output under `assets/textures/surfaces/`.
- Integrated downloaded maps into Industrial Crossroads and its surrounding
  ground, concrete detail into the shared industrial building material, and
  generated panels into industrial roofs and armor across all three factions.
- Preserved team trim, optical/emissive surfaces, Frontier fabric/dust, weather,
  road markings, construction appearance/restoration, and fog-memory copies.
- Imports use mipmaps and VRAM compression, with a 1024-pixel runtime size cap.
  Seven source images total 7,684,651 bytes. Shared material cache uses value keys
  so repeated save restores do not retain new copies of source materials.
- Headless texture lifecycle regression passes for Bastion, Helix, and Frontier:
  imports, shader parsing, actual tank/HQ/power-plant assignments, player colors,
  immutable source materials, industrial ground/building bindings, construction
  completion, fog memory, and match save/restore.
- Existing headless ConstructionStyleRegression and GraphicsRegression pass;
  changed GDScript passes gdformat/gdlint and `git diff --check`.
- Godot's headless harnesses emit ObjectDB/resource warnings at shutdown despite
  passing assertions. These are recorded rather than treated as clean stderr.
- After direct launches were authorized, reviewed all three factions at battle
  and armor-detail zoom plus industrial buildings/roads in clear weather and rain
  using Godot 4.6 Forward+ on Metal (Apple M1 Pro).
- Added `tests/rendered/SurfaceTexturesPreview.gd`, which captures 23 views and
  detail-off controls under `art/texture-materials/`. Corrected fixture timing so
  neutral-building visibility refreshes before pausing; visibility is asserted.
- Rendered captures passed with no shader/runtime errors. Generated seams/wear
  and downloaded surface grain are visible up close without overwhelming battle
  readability. Construction keeps the surface detail through completion.
- Rendered ConstructionWreckRegression passes for all three factions: wreck
  expiry, pool eviction, shared living materials, and scene teardown.
- Shutdown resource/ObjectDB warnings remain in the harness logs. GPU frame cost
  has not been benchmarked; no performance claim is made for this pass.
