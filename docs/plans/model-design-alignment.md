# Unit model and design alignment

## Stage 1 — Establish production identities
- Trace faction descriptions, weapon profiles, model assignments, equipment, portraits and the Helix showcase.
- Preserve gameplay statistics, save IDs, faction styling and animation contracts.

## Stage 2 — Build matching models
- Replace the Helix cannon pylon with a prism emitter and the Needle cannon with twin pulse emitters, using the faction generator and weathering pipeline.
- Give Helix infantry plasma, twin pulse, ion and thermal weapons; give Frontier assault infantry and the Iron Warden matching shotguns; remove Nyx's overlapping rifle and carry her complete lance together.
- Update grips, muzzle markers and equipment animation; refresh production portraits.
- Make the Helix model showcase use current production models and identities.

## Stage 3 — Verify and review
- Add regression coverage for equipment identity, obsolete weapon removal, muzzle placement and animated attachment integrity.
- Run relevant geometry, animation, material and faction checks.
- Render and inspect the new models and portraits, recording results and any limitations.

## Reproduce
- Godot: `~/.cache/godot/4.7.2/Godot.app/Contents/MacOS/Godot`.
- Helix assets: `/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python art/helix/build_faction.py -- --alignment-only`. Editable source: `art/helix/v1/aligned-defense.blend`.
- Focused regression: `godot --headless --fixed-fps 60 --path . --script tests/headless/ModelDesignRegression.gd`.
- Rendered reviews (sequentially): `tests/rendered/InfantryStudioPreview.gd`, `tests/rendered/HelixPreview.gd`, `tests/rendered/WeatheringPreview.gd -- helix`, `tests/rendered/InfantryRedesignPreview.gd`. Use `--path . --audio-driver Dummy --fixed-fps 60 --script`, without `--headless`.
- Logs: `tmp/model-alignment/`. Captures: `art/infantry/redesign/`, `art/helix/v1/`, and `art/weathering/`.

## Agent progress
- Initial audit confirmed the old cannon pylon, shared assault weapons, conventional Helix specialist weapons, single-barrel Needle and Nyx's overlapping rifle/lance. The Helix showcase also uses legacy assets.
- Working tree was clean before implementation.
- Located Godot 4.7.2 in the user cache and Blender 5.2.1. Rebuilt the pylon and Needle through the Helix generator, including vertex weathering, trim UVs and portraits.
- Added complete carried weapon assemblies for all Helix infantry, Frontier assault and the Iron Warden. Removed overlapping/generic visible weapons, adjusted grips, and made twin emitters alternate their firing origin.
- Initial verification passed: InfantryRedesignRegression (24 models, maximum 10,572 triangles), InfantryDeathGroundRegression (72 falls), and ModelDesignRegression on spawned units.
- Inspected native studio renders for all three factions. Helix showcase now resolves all 24 current roles through production geometry and descriptions; corrected its 720p roster overflow and model/text overlap. Final HelixPreview passes all 24 roles.
- Refreshed all 18 production infantry/mercenary portraits and both Helix vehicle/defense icons. Validated all infantry portraits as nonempty 256×256 RGBA images.
- Nine focused regressions pass: ModelDesign, InfantryRedesign, InfantryMeshBatch, InfantryDeathGround, UnitAnimation, InfantryPoseWorker, RichTextures, ObjectMaterials, and FactionAsymmetry. Added ModelDesignRegression to the release check manifest. Animation checks use the release suite's `--fixed-fps 60`; the initial uncapped invocation hit timing-dependent assertions.
- Extended WeatheringPreview to cover the new Needle and pylon. Native Helix review passes with 18 weathered/control captures, including both updated GLBs; inspected their battlefield renders.
- Battlefield infantry preview exposed stale frozen-fixture orientation and abrupt shutdown. Updated the preview to publish its review transform and use normal shutdown before final capture.
- Final battlefield preview completes cleanly with normal shutdown. Reviewed front-facing aim/stride and battle-scale captures for all three factions. All three implementation stages are complete. GDScript formatting/lint, Python compilation and whitespace checks pass. Verification covers the source project; no distributable game package was rebuilt.
