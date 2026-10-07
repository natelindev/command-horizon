# Industrial salvage, power HUD and progression follow-up

## Resource-art refinement

The second pass replaces similar mesh variations with six distinct designs: beam stock, armor wreck, steel coil, server cache, relay wreck and capacitor pack. The existing GLB paths retain integration into both factions' matches and all maps. Materials share worn steel/ochre; electronics share ceramic/graphite/cyan. Matching vector economy icons and a separate lightning symbol improve the top HUD. Power now explicitly reads used / supply, warns when reserves fall to 10% or less, and distinguishes no generation from exact capacity. HUD rebinding disconnects the previous player's signal.

Verification of this refinement:

- Blender rebuild passed; generated manifest records 564–1,136 triangles per asset, four/five material surfaces, maximum radius 0.5425 m and height 0.7294 m. No new runtime animation or resource physics logic.
- Godot editor import passed. Rendered `ResourcePowerPreview.gd` passed: vertex bounds of all six imported models, existing resource obstacle radii, supply/demand, near capacity, exact capacity without slowdown, deficit, recovery, zero generation with/without demand, pause, faction rebinding and 720p header bounds. Actual gameplay and the six-design gallery were visually inspected.
- `NavigationRegression.gd` passed obstacle routing, crowded movement, harvesting, construction access and factory egress with the rebuilt models. It retains the existing shutdown-only dummy shader/resource leak diagnostics and navigation GPU-readback warning; the rendered test has no script errors.
- Changed GDScript passes gdformat/gdlint; `git diff --check` passes. This refinement did not repeat unrelated program/combat suites, full 200-unit performance benchmarks or exported-platform checks.

Review: [all six designs](../../../art/skirmish/resource-six-designs.png), [gameplay HUD](../../../art/skirmish/resource-power-gameplay.png), [exact capacity](../../../art/skirmish/resource-power-capacity.png), [low power at 720p](../../../art/skirmish/resource-power-shortage-720p.png). The gallery hides the HUD and reveals terrain for asset inspection; gameplay captures retain normal fog and HUD.

## Delivered

- Six shared neutral resource meshes: three materials piles and three electronics caches. Beveled industrial components replace the generic crystals and slabs. Deterministic variant/rotation selection preserves gameplay randomness. GLB assets are statically referenced for exported builds.
- Reproducible Blender source: `art/resources/build_resources.py`; six editable `.blend` files and triangle/surface counts in `art/resources/manifest.json`. No per-frame resource animation or extra navigation obstacles.
- Persistent compact top HUD: separate material/electronics/population values, power demand/capacity meter, spare amount, at-capacity instruction, and shortage deficit plus 35% operating speed. Zero-supply states remain visible. Fits above objectives at 720p.
- Completed the preceding in-progress slice: Coordination research, long-range prerequisite, power/pause/refund/lab-loss behavior, factory exact-version dropdown and immutable job snapshots, safe Hold fallback, manual rally precedence and AI idle preset handling.

## Verification

- `ResourcePowerPreview.gd`: rendered healthy/deficit/recovered/zero-supply power, tactical pause, one model per resource, unchanged resource radius (approximate floating-point comparison), 1440×900 and 1280×720. Passed; images visually inspected.
- `NavigationRegression.gd`: obstacle routing, crowded movement, harvesting, construction access and factory egress. Passed with the new meshes.
- `Skirmish.gd`: faction pairings/random setup, full roster production with Coordination, construction, AA, pause/results/restart and AI economy/attacks. Passed.
- `CoordinationRegression.gd`: both factions; exact costs/refunds, duplicate/unaffordable requests, low power, pause, lost/rebuilt labs, production gates, version pinning and queue isolation, deleted/corrupt/duplicate library fallback, rally authority, AI scout/repair orders. Passed.
- `ProgramRegression.gd`: fitting, fees, saved versions, authority, assignments, observation bounds, retreat, support and blocked recovery. Passed.
- `ProgramPreview.gd`: prior rendered assignment/library/manual/pause flow plus factory version dropdown and research/cancel buttons at 720p. Passed and images inspected.
- New scripts pass gdformat/gdlint; `git diff --check` passes.

Some headless suites retain the previously documented navigation mesh GPU-readback warning and shutdown-only resource/RID leak diagnostics. No gameplay assertion or script errors remain in these runs. This pass did not repeat the 200-unit performance benchmark or validate novice usability, final balance, Windows rendering or full exported packages.

## Review images

- [Salvage close view](../../../art/skirmish/resource-salvage.png)
- [Normal gameplay and power](../../../art/skirmish/resource-power-gameplay.png)
- [Low power at 720p](../../../art/skirmish/resource-power-shortage-720p.png)
- [Factory version assignment](../../../art/skirmish/program-factory.png)
- [Coordination research](../../../art/skirmish/coordination-research-720p.png)
