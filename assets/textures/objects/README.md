# Object surface textures

`source/match/ObjectMaterials.gd` assigns shared, physically lit triplanar finishes
to imported models, generated infantry, civilian actors, resource piles, worker
cargo and scenery batches. UV-less assets receive detail in metres without
swimming when a unit moves. Imported meshes and materials remain immutable.
Shared material caches live in `Globals.cache` through `RuntimeCache`, so they
are released with the application instead of retaining shader scripts at exit.

## Original generated artwork

The following originals were generated with the built-in ImageGen tool:

- `generated/foliage_v1.png`: overlapping broad leaves for tree crowns and shrubs.
- `generated/needles_v1.png`: fine needles for conifers, stretched for grass/sedge.
- `generated/canvas_v1.png`: neutral woven canvas for uniforms, coats and packs.

Exact prompts and tool provenance are in `generated/prompts.json`. These are
albedo images, not measured normal maps. The shader neutralizes their mean color
before applying the existing biome/faction palette. Dynamic lighting and shadows
remain the renderer's responsibility. Normal-mapped bark/stone/concrete use
actual OpenGL normal maps; no normal map is inferred from the generated images.

Imports use mipmaps, VRAM compression and a 1024-pixel runtime size limit.
Generated artwork and scan colors use high-quality compression. Original source
images remain unchanged on disk.

## CC0 scans

`polyhaven/` contains unmodified 1K color, OpenGL normal and roughness maps from
[Bark Brown 02](https://polyhaven.com/a/bark_brown_02) and
[Rock Boulder Cracked](https://polyhaven.com/a/rock_boulder_cracked).
Poly Haven publishes these under [CC0](https://polyhaven.com/license).
Download URLs, file sizes and SHA-256 hashes are recorded in `sources.json`.

Re-fetch or verify with:

```sh
python3 tools/textures/fetch_object_textures.py
```

Concrete, asphalt and armor reuse the documented maps in
`assets/textures/surfaces/`. Biome rock shaders retain their authored strata,
snow, salt stains and colors, adding scanned detail through
`source/shaders/3d/rock_detail.gdshaderinc`.

## Runtime and verification

- `FactionCatalog.prepare_model` finishes the faction geometry before team
  tinting and construction. Construction completion restores the same materials.
- `Match._ready` finishes map geometry after landmarks and living scenery exist.
  `MeshBatch` assigns materials before merging, retaining shared draw calls.
- Ambient actors, depleted resources and carried cargo also apply finishes at
  creation. Emission, glass, water, markings and team trim keep their own shaders.
- Dune grass is built as 60 tapered blades (360 triangles) by
  `art/environment/build_drylands.py`, inside its original footprint/height limits.
- `ObjectMaterialsRegression.gd` audits imported and generated models, protected
  materials, source immutability, primitive MultiMeshes, texture imports, biome
  shaders, small-scenery shadows, construction and save/restore.
- Run `tests/rendered/ObjectMaterialsPreview.gd` without `--headless` for faction,
  infantry, civilian, foliage and rock captures in `art/object-materials/`.
  Paired `-detail-off` captures use identical geometry, lighting and camera.

## Foliage cutouts and meadow grass

`tools/textures/generate_material_details.py` also generates original 512px
`leaves_cutout.png` and `needles_cutout.png` branch/leaf silhouettes with alpha,
veins, antialiased edges and transparent borders. These have no inferred normal
map. `art/common/foliage.py` builds seeded, bounded card clusters with normals
following the canopy volume. `build_temperate.py` uses them for broadleaf trees,
conifer tiers and leafy shrubs; `build_desert.py` uses them for dry sage scrub.
Existing desert trees already use explicit leaf geometry and are retained.

The `[cards:leaves]` / `[cards:needles]` material suffix selects the shared
`foliage_cards.gdshader`: two-sided lighting, alpha scissor, shadow/depth writes
and restrained backlighting. It uses UV0, including through MeshBatch merging.
Card geometry remains inside its authored ellipsoid and the kit exporters
validate radius/height limits. Bark keeps its scanned surface material.

The temperate generator also builds `MeadowGrass.glb`. TerrainDressing places
it on forest ground and roadside verges of forest/farmland/village maps with a
separate deterministic seed, at most 1800 instances in one shadow-casting
MultiMesh. Existing road, base, resource, landmark, ramp and water clearances
are respected. It has no collision or simulation state.
