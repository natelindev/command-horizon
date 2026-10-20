# Battlefield ground layers

Eight CC0 scans from [Poly Haven](https://polyhaven.com/license) give every
battlefield ground visible detail at RTS zoom. They are licensed under
[CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/).

| Layer | Poly Haven asset | Tile width | Color/normal size |
| --- | --- | --- | --- |
| `grass` | [aerial_grass_rock](https://polyhaven.com/a/aerial_grass_rock) | 15 m | 1K |
| `ground_rock` | [aerial_ground_rock](https://polyhaven.com/a/aerial_ground_rock) | 20 m | 1K |
| `sand` | [aerial_sand](https://polyhaven.com/a/aerial_sand) | 15 m | 1K |
| `coast_sand` | [coast_sand_01](https://polyhaven.com/a/coast_sand_01) | 15 m | 1K |
| `dirt` | [dirt_aerial_03](https://polyhaven.com/a/dirt_aerial_03) | 25 m | 2K |
| `asphalt` | [aerial_asphalt_01](https://polyhaven.com/a/aerial_asphalt_01) | 30 m | 2K |
| `snow` | [snow_field_aerial](https://polyhaven.com/a/snow_field_aerial) | 80 m | 2K |
| `concrete` | [concrete_floor_damaged_01](https://polyhaven.com/a/concrete_floor_damaged_01) | 7.5 m (scanned at 5 m) | 1K |

`*_color.jpg` and `*_normal.jpg` (OpenGL) are stored exactly as downloaded.
`*_data.webp` is derived: red is roughness, green is displacement stretched to its
1st–99th percentile, blue is ambient occlusion (all from the 1K maps).
`sources.json` lists every downloaded URL, byte count and SHA-256.

Rebuild with:

```sh
python3 -m venv tmp/texture-venv
tmp/texture-venv/bin/pip install -r tools/textures/requirements.txt
tmp/texture-venv/bin/python tools/textures/build_terrain_textures.py
```

The script refuses to overwrite assets if a recorded checksum no longer matches.
Imports use VRAM compression with mipmaps: BC5/RGTC for normals and BC7/ASTC
for the packed data maps.

## Runtime

`source/match/TerrainTextures.gd` assigns layers per biome (catalog
battlefields, hero theaters) or per ground shader (scripted maps and their
backdrops). `source/shaders/3d/terrain_layers.gdshaderinc` modulates each
shader's authored colors by the scan's mean-normalized detail, so palettes,
grading and minimap tones keep their averages. Base fills the field, path follows
roads and tracks, accent carries the biome feature (bare patches, salt, snow,
exposed rock or paving).

The **Ground detail** graphics setting (`ground_detail` shader global) turns the
layers and decals off; the ground then renders as the authored procedural shader.
