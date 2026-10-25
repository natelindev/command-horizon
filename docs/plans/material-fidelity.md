# Material and scenery fidelity

## Stage 1 — Materials and ground contact

- Preserve and verify the existing height-aware scan blending and baked weathering.
- Generate deterministic panel/micro normal and material data maps from authored height fields.
- Bind shared maps to armor shaders, preserving faction colors, construction and save restoration.
- Retain and verify the existing terrain-conforming BaseApron dirt/gravel skirts and their structure lifecycle.

## Stage 2 — Scenery

- Replace temperate canopy solids and desert scrub solids with bounded foliage cards.
- Generate alpha-cutout leaf/needle textures and use lit, two-sided foliage shading.
- Add deterministic, batched grass around vegetation without changing navigation.

## Stage 3 — Hard-surface trim pipeline

- Generate a shared neutral PBR trim atlas with faction-specific material responses.
- Assign deterministic per-face trim UVs in faction generators before mesh joining.
- Retain actual bevels, weathering, articulation, ownership markings and material sharing.
- Rebuild faction assets through their authoring scripts.

## Stage 4 — Verification

- Run texture, object-material, scenery and save/construction regressions.
- Run WeatheringPreview and TerrainLayersPreview with the renderer enabled.
- Review close and tactical captures for readable silhouettes, foliage coverage and artifacts.

## Agent progress

- Initial inspection complete. Terrain height blending and armor dust gradients already exist; models already have real chamfers and vertex weathering. BaseApron already provides terrain-conforming dirt/gravel skirts per structure; GroundDecals separately covers roads/open fields.
- Worktree initially clean. Blender and Python texture dependencies available; using Godot from the shared checkout tooling directory.
- Generated deterministic 512px micro normals/ORM, a 2K mechanical trim atlas, and two cutout foliage textures. Added procedural generation tests.
- Rebuilt 74 faction GLBs through their scripts. Verified unchanged triangle counts, unique vertex positions and node transforms against the original assets; all four trim bands are used.
- Rebuilt bounded temperate leaf/needle clusters and desert scrub; added deterministic grass batches only on temperate forest/verge terrain with existing clearances.
- SurfaceTexturesRegression (construction, fog memory, save/load for all factions), RichTexturesRegression, ObjectMaterialsRegression (345 models), MaterialFidelityRegression and four Python texture tests pass.
- First graphical review passed. Reduced armor mottling, thickened needle coverage, preserved small-scenery shadows. Checking the GPU batch shader path and final terrain/weathering captures next.
- Final verification complete: 34 weathering captures, 27 object-material captures and five terrain scenes pass with the graphical renderer. GPU/native material parity passes for all three factions after restoring surface overrides; matched LODs isolate the material comparison.
- Stages 1–4 complete. Rebuild instructions are in the texture READMEs; evidence and remaining platform/lint scope are recorded in `docs/playtests/2026-10-25/material-fidelity/README.md`.
