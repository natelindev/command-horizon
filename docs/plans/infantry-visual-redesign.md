# Infantry visual and animation redesign

## Stage 1 — Inspect and establish the target
- Review production infantry construction, equipment, motion, and rendered evidence.
- Generate a grounded three-faction infantry reference with the built-in imagegen tool; retain image and exact prompt in `art/infantry/redesign/`.

## Stage 2 — Implement the production models and movement
- Replace primitive toy-like anatomy with shaped human silhouettes, fitted equipment, restrained faction markings, and distinct material finishes.
- Preserve faction/class identity, projectile origins, ownership colors, gameplay dimensions, and existing locomotion contracts.
- Improve upper-body articulation and verify walking, stopping, aiming, recoil, and death.
- Regenerate production portraits from the updated models.

## Stage 3 — Verify and review
- Add focused regression coverage for model and animation changes.
- Run relevant headless regressions and graphical previews of all factions and classes, including close and battle-camera views.
- Inspect captures against the target and record results and limitations.

## Agent progress
- Inspected the runtime models and existing motion regression tests. Infantry use `InfantryModel.gd`, not the legacy faction GLBs. The existing IK foot planting will be retained.
- Working tree was clean before starting.
- Stage 1 complete: generated the three-faction target with built-in imagegen, saved `art/infantry/redesign/target-v1.png` and its exact `prompt.txt`, and retained a before capture.
- Stage 2 complete: rebuilt the production rig with contoured anatomy, layered uniforms/kit, matte cloth, compact weapons, and shoulder/elbow/wrist articulation. Integrated material-aware mesh batching (base rifleman 109 → 58 mesh instances), and regenerated all 18 faction/mercenary portraits.
- Reviewed all three factions in neutral studio and actual battlefield views, at close and battle-camera distances. Captured a continuous production-motion clip covering idle, travel, stop, aim, recoil and collapse. Review media stays local under the repository's existing `art/` ignore rules.
- Focused checks passed: InfantryRedesignRegression (24 faction/role models, maximum 9,908 triangles), InfantryMeshBatchRegression, InfantryMotionRegression, InfantryHeroesRegression, ObjectMaterialsRegression (344 models / 7,323 textured surfaces), and RichTexturesRegression.
- Death review found ground penetration, then excess clearance from rotated bounds. Replaced bounds-only contact with cached actual mesh vertices and added InfantryDeathGroundRegression (72 faction/role/fall scenarios). Axis-angle falls now reach a horizontal rest in diagonal directions, and the final carry pose keeps the launcher optic from propping up the body.
- Stage 3 complete: the final rendered clip was inspected through collapse. InfantryDeathGroundRegression passes all 72 scenarios, including diagonal fall directions and a focused rocket-trooper body/optic contact check; InfantryRedesignRegression and UnitAnimationRegression also pass after the final pose adjustment.
- UnitAnimationRegression now checks knee buckling during the fall and leg relaxation at rest, alongside its existing gameplay/sinking contracts (hips reach 0.360 during buckle and 0.490 at rest).
- Verification limitation: the broader VisualPolishRegression rendered suite cannot compile because of existing RosterLayoutRegression resolution and missing-await errors in its `_select()` calls. Portraits were independently rendered, inspected, and checked as 18 nonempty 256×256 RGBA images. Full-match motion/animation suites reported shutdown resource warnings despite zero assertion failures.
- Fidelity limitation: the game models follow the reference's proportions, palette and equipment design, with stylized RTS geometry; they do not reproduce the reference's photoreal facial/fabric detail.
