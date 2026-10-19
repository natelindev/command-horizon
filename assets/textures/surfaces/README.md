# Battlefield surface textures

## Downloaded materials

The six original 1K JPEG maps under `polyhaven/` are from Poly Haven and licensed
under [CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/).
Poly Haven permits modification, commercial use, and redistribution of its
downloadable assets: <https://polyhaven.com/license>.

- [Asphalt 03](https://polyhaven.com/a/asphalt_03): Charlotte Baglioni
  (photography), Dario Barresi (processing). Physical tile width: 2 m.
- [Granular Concrete](https://polyhaven.com/a/granular_concrete): Michael Jenkins
  (photography), Dario Barresi (processing). Physical tile width: 2.4 m.

Each set includes diffuse color, OpenGL normal, and roughness. Exact download
URLs, byte counts, and SHA-256 checksums are in `polyhaven/sources.json`. Files
were downloaded on 2026-10-19 without pixel modifications. Only downloadable
material maps are included; website thumbnails and rendered previews are not.

## Generated artwork

`generated/armor_panels_v1.png` is original artwork generated for this project
with the built-in ImageGen tool on 2026-10-19. It is separate from the CC0 assets.
The complete generation prompt is in `generated/prompt.txt`. No input/reference
image was used. The original generated file is retained without pixel edits.

The artwork supplies a grayscale panel/wear mask, not a measured PBR material.
Local-space triplanar projection follows vehicles and articulated parts without
requiring UV changes. Mirrored sampling joins the edges; native periodic tiling
of the generated source is not assumed. The shader preserves faction paint
colors and gives dirty joints a modest roughness increase; no fabricated normal
map is supplied. Team trim, glass, emissive parts, rubber, and infantry are
excluded from the armor pass. Frontier retains its existing dust/fabric finish.

## Integration

- `SurfaceTextures.gd` owns shared maps and finished armor material instances.
- Industrial Crossroads and its surroundings use both downloaded PBR sets while
  retaining the existing road masks, markings, foundations, and rain response.
- The shared industrial building shader uses concrete color/roughness for
  masonry and generated panel artwork for roof/panel materials. This includes
  industrial scenery reused by Command Horizon and Broken Foundry.
- Bastion and Helix armor, plus Frontier ceramic/secondary/titanium surfaces,
  use the generated artwork. Construction shaders carry the same local-space
  detail until the original finished materials are restored.

Imports generate mipmaps, use VRAM compression, and cap the generated artwork at
1024 pixels in the runtime import. Source files remain untouched. Map texture
samplers use anisotropic mip filtering. This adds seven shared source textures,
no new geometry, and no extra material passes.

## Verification

Headless texture regression covers imports, actual material bindings across all
three factions, team colors, construction restoration, fog memory, and repeated
save/restore. Existing construction-style and graphics checks also pass.

After the user authorized direct launches, the rendered preview was reviewed
using Godot 4.6 Forward+ on Metal (Apple M1 Pro). It captures each faction at
battle and armor-detail zoom, industrial roads/buildings in clear weather and
rain, and construction before/after completion. The image detail remains subtle
at battle zoom; panel seams and surface grain become visible up close. No missing
textures or shader/runtime errors were observed during the captures. Rendered
construction-wreck expiry, eviction, and scene teardown checks also pass.

Reproduce the captures with a rendered Godot launch:

```sh
godot --path . --script tests/rendered/SurfaceTexturesPreview.gd
```

Captures go to `art/texture-materials/`. Images ending in `-detail-off` are
controls with texture variation removed while retaining average map colors,
lighting, geometry, and procedural detail; they are not historical screenshots.
The fixture waits for neutral-building visibility updates before pausing and
restores the user's preferences afterward. Optional arguments after `--` select
factions (for example, `-- bastion`).

The harnesses still emit resource/ObjectDB cleanup warnings at engine shutdown;
these are separate from the runtime assertions. GPU frame cost was not benchmarked.
