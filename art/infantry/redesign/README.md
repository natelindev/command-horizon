# Infantry redesign

The visual target was generated with the built-in imagegen tool. The exact prompt is in `prompt.txt`; the local reference is `target-v1.png`. Review media under `art/` is intentionally ignored by this repository.

The production interpretation follows the reference's adult proportions, subdued faction palettes, layered plate carriers, cloth uniforms, eye protection, compact weapons and small identification tabs. It remains a stylized RTS model at close range; the reference has higher facial and fabric detail.

## Production implementation

- `source/match/units/traits/InfantryModel.gd` authors shared contoured ArrayMeshes for the body, tailored sleeves/trousers, helmet, face, soft packs and pouches. These are the actual battle models, including heroes and mercenaries; the legacy infantry GLBs are not used by `FactionCatalog.prepare_model`.
- `InfantryEquipment.gd` adds fitted class armor, launcher, precision rifle, shields and command equipment.
- `source/shaders/3d/infantry_fabric.gdshader` gives uniforms and canvas restrained fading, fine irregular fibers and matte relief, filtered at battle distance. Other finishes keep the existing object-material pipeline.
- `InfantryMotion.gd` solves shoulders/elbows/wrists separately from the weapon. Grip markers drive both hands through low ready, shoulder raise, recoil and death. Existing travel-driven leg IK, recovery steps, kneeling, role differences and gameplay transforms are preserved.
- Death poses buckle first and extend at rest. Axis-angle falls reach a horizontal resting body, with the weapon relaxing along it. `CombatEffects.gd` resolves infantry ground contact from cached mesh vertices before the existing delayed sinking, avoiding both penetration and the excess clearance of rotated bounding boxes.
- `InfantryMeshBatch.gd` consolidates compatible decorative meshes after material classification. Articulated pivots, projectile origins, protected inspection nodes and team marks remain addressable. Base rifleman mesh instances fall from 109 to 58 without removing triangles.
- Portrait renderers now pose the same production rig at low ready before capturing all 15 faction and 3 mercenary portraits.

## Reproduce

Use Godot 4.7.2. This checkout's engine is `tmp/tooling/godot-4.7.2/Godot.app/Contents/MacOS/Godot`; substitute it for `godot` below.

```sh
# Production portraits; graphical renderer required.
godot --path . --script art/infantry/render_portraits.gd
godot --path . --script tools/ui/render_mercenary_portraits.gd
godot --headless --editor --path . --import

# Neutral studio, actual battlefield, and continuous animation review.
godot --path . --script tests/rendered/InfantryStudioPreview.gd
godot --path . --fixed-fps 60 --script tests/rendered/InfantryRedesignPreview.gd
godot --path . --fixed-fps 30 --script tests/rendered/InfantryAnimationPreview.gd
ffmpeg -y -framerate 30 -i tmp/infantry-animation-frames/%04d.png -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart art/infantry/redesign/animation.mp4

# Geometry, all faction/role rigs, grips, death poses and batching contracts.
godot --headless --path . --script tests/headless/InfantryRedesignRegression.gd
godot --headless --path . --script tests/headless/InfantryMeshBatchRegression.gd
godot --headless --path . --script tests/headless/InfantryDeathGroundRegression.gd
```

Run graphical previews sequentially on macOS. Concurrent native Godot windows can stop one preview's `frame_post_draw` capture loop when occluded.

## Review artifacts

- `target-v1.png`: generated design target; `before-bastion.png`: previous game model.
- `studio-<faction>-detail.png` and `studio-<faction>-aim-detail.png`: neutral close-up materials and poses.
- `<faction>-lineup.png`, `<faction>-aim.png`, `<faction>-stride.png`, `<faction>-battle-scale.png`: production models on the industrial battlefield.
- `animation.mp4`: continuous idle, travel, stop, aim, recoil and collapse using production motion/effects.

## Verification

Final checks and any limitations are recorded in `docs/plans/infantry-visual-redesign.md`. Full run logs are local under `tmp/infantry-review/`.
