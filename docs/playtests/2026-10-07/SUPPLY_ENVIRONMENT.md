# Supply Line: freight-road environment

Supply Line now has a continuous worn road, numbered concrete checkpoints, layered sandstone cuts, a pump station, a ruined transfer bay, drainage remnants, low sage and surrounding freight-country mesas. Warm directional light and cooler ambient light replace the undifferentiated blockout appearance. Six original assets retain editable Blender collections and a reproducible generator in `art/environment`.

The change also corrects an existing visual/gameplay mismatch: all four former cliff meshes extended to **6.867 m radius and 9.41 m above their obstacle parents**, beyond their **5 m movement / 3 m sight** envelopes. The replacement solids fit those original envelopes. Their evaluated model bounds reach at most **4.584 m radius / 2.923 m height**. Obstacle positions and their existing 0.6 m navigation alignment are preserved; a mesh offset grounds the models.

## Gameplay contracts

Checkpoint locations, response entry positions, truck rules, force budgets, starting units, orders, observation and archives remain unchanged. The only changed existing shipping files are `SupplyLineMap.gd` and its scene; a backdrop script and ground shader are added. Imported exterior vertices lie outside the 192×128 playable rectangle. Low passable roadside meshes stay below 0.32 m including placement. Neither the backdrop nor roadside details adds physics or navigation obstacles.

The geometry regression checks all four blocker contracts, ground-fire obstruction, sight above the envelope, imported bounds, upward ground normals and flush terrain joins. The three convoy navigation lengths exactly match the baseline: **46.000 / 69.971 / 70.000 m**. The baseline images and measurements remain available for comparison.

The earned contested battle from the preceding difficulty pass restores exact unit positions, HP and paused time on the new map. Explicit escort/repair orders still clear the checkpoint in **3.03 seconds**, with all three trucks surviving and the damaged truck improving from 32.1 to 33.6 HP. The same recovery passes with normal-clock rendering; a live frame is captured at 173.083 seconds with pause disabled. Its HUD still carries the pre-existing transient “Battle loaded · paused” notice after resuming; the clock and Pause button correctly indicate live simulation. That unrelated notice is not changed here.

## Complete routes and review

Three focused full matches use the existing reference escort commander, ordinary observed-enemy response/repair orders and three Advance/Hold pairs. They preserve original unit health and finite opposition.

| Difficulty | Outcome | Simulation time |
| --- | --- | --- |
| Story | Victory | 221.73 s |
| Standard | Victory | 225.87 s |
| Veteran | Victory | 229.72 s |

All resolve three responses, extract two trucks and retain the third. These are one practiced route per difficulty, not novice or repeated balance acceptance. Timing differences from the previous environment are not treated as a balance improvement.

The normal-clock Veteran playthrough reaches actual **victory at 226.78 seconds** with three mouse Advance activations and three focused Enter Hold activations. It resolves all responses and loses no trucks. Paused input authority and panel/minimap separation pass at **1280×720 / 150% interface scale**. These inputs are engine-injected, not physical-device acceptance.

The shared Supply Line suite passes repairs, paused commands, disk restoration, held/contested clearance, reinforcement denial, truck-loss outcomes, difficulty budgets, Standard victory and campaign reward migration. Format/lint pass for the two map scripts and three new verification scripts. Blender generation/import complete successfully.

Nine accepted captures are reviewed: [ordinary-fog opening](supply-environment/final-start.png), [three](supply-environment/final-checkpoint-0.png) [checkpoint](supply-environment/final-checkpoint-1.png) [compositions](supply-environment/final-checkpoint-2.png), [900p overview](supply-environment/final-overview.png), [live earned combat](supply-environment/live-combat.png), and the Veteran [first checkpoint](supply-environment/veteran-preview-stage-0.png), [second checkpoint](supply-environment/veteran-preview-stage-1.png) and [victory](supply-environment/veteran-preview-stage-2.png). The checkpoint/overview art frames explicitly reveal terrain and hide most HUD; they are not observation evidence. The opening, live recovery and Veteran route retain ordinary fog. The opening also asserts that unobserved opposition remains hidden. The widest overview exposes the finite exterior edge and does not establish final landscape composition acceptance.

## Evidence and limits

`run-index.json` records thirteen scripted invocations. The first post-change geometry test reports four false contract failures because it compares in-memory position arrays exactly against JSON-round-tripped floating-point values. Its log, measurements and source are retained; the corrected vector comparison uses Godot's approximate comparison. Navigation lengths and serialized blocker values already match in that failed run. Initial road/HUD art-review captures are retained separately from the final set.

The final accepted processes have no script errors. Existing navigation readback and shutdown resource/ObjectDB diagnostics remain documented in the logs. `analyze.py` checks outcomes, dimensions, controls, geometry and source fingerprints; `SHA256SUMS` inventories retained evidence. Generator and editable asset files remain in the main art directory.

This completes the first Supply Line environment pass. Subjective final art, novice play, repeated difficulty trials, other campaign environments and physical-device/platform acceptance remain open. Performance work stays deferred and the overall gameplay goal remains active.
