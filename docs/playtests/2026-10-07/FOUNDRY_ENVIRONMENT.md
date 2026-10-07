# Broken Foundry industrial environment — 2026-10-07

Broken Foundry now sits in a continuous rail-served industrial district. Exterior loading sheds, freight wagons, utilities, a substation and birch scrub reuse the existing editable industrial kit. Weathered roofs, cracked concrete, asphalt repairs and flush striped working aprons replace the clean blockout surfaces and raised factory pads. Eight low scrub clusters soften unused ground; taller new scenery remains outside the 160×116 playable rectangle. Warmer map-owned light and restrained exterior visibility connect the setting while ordinary enemy observation stays intact.

This adapts existing models and Blender sources; it does not add new imported assets. The existing four warehouses and two furnaces retain their positions, meshes, movement radii, sight heights and aircraft-clearance behavior. Mission production, budgets, units, resources, objective locations and scoring are unchanged.

## Geometry, continuity and archives

The measured warehouse radii remain 8 metres and furnace radii 5 metres, with the same 6.9-metre sight envelope. Actual mesh vertices stay inside those envelopes. Ground sight is blocked and overhead sight remains open. Five navigation paths match the pre-edit baseline within 0.01 metres: 37.00, 37.00, 55.54, 58.68 and 32.35 metres. The last crosses a warehouse's obstructed line and verifies the actual bypass route.

All exterior mesh vertices remain outside playable space. Exterior terrain excludes the original ground plane's two-metre margin and joins it at zero height, using the same material instance and world-space road coordinates. Exterior models add no physics or navigation obstacles; new scenery does not enter the terrain navigation input group. Low scrub stays below 0.3 metres. The player still cannot observe the initial opposing infantry.

A newly written typed disk archive and the previous pass's actual late-production save both restore exactly while paused: mission state, simulation time, player economy, and each unit's position, HP and paid production remain unchanged. Both restore the new exterior. No archive schema or save migration is needed.

## Visual review

Ten final scene views were inspected: starting HUD, unseen enemy territory, dim exterior under normal fog, northern production apron, warehouse junction, foundry control yard, rail siding, south utilities, east boundary and a 1440×900 overview. Other views use 1280×720 with 150% interface scale. The first three retain ordinary fog; the other seven explicitly reveal terrain for art inspection, without claiming enemy-unit observation. The control objective stays legible and roads remain clear of tall new props.

See the [district overview](foundry-environment/final-overview.png), [warehouse junction](foundry-environment/final-junction.png), [control yard](foundry-environment/final-control.png) and [ordinary exterior fog](foundry-environment/final-boundary-fog.png). The original views and initial revised views are retained separately. Final captures follow a shader cleanup and add the normal-fog edge checks.

## Combat, aircraft and shared rules

All three headless difficulty routes and a normal-clock Veteran route reach ordinary victory:

| Route | Victory time | Human survivors | Remaining infantry |
| --- | ---: | ---: | ---: |
| Story | 131.88 s | 19 | 7 |
| Standard | 127.65 s | 16 | 6 |
| Veteran | 147.88 s | 14 | 4 |
| Veteran, normal clock | 141.23 s | 14 | 5 |

Each run destroys both production nodes after one/two admitted batches, resolves the finite response and completes the actual infantry capture/securing objective. The reference commander pays 24 materials for four replacement infantry; final funds are 136 materials / 80 electronics. No extra funds, units or HP changes are injected. Results vary from earlier runs and do not establish repeated balance or causal timing effects from the environment.

The full shared Broken Foundry suite passes warehouse traversal/sight, artillery threat, bounded Guard pursuit, non-stacking repair, finite ordinary production, archive continuity, capture/hold/entry denial, difficulty response budgets, HQ defeat and reward/progress migration. Its separate Standard fight wins at 133.85 seconds. The shared industrial flight suite completes 24 actual Drone/Helicopter crossings across both industrial maps, including twelve over Broken Foundry's six landmarks, and preserves aircraft root altitude on restoration.

Three normal-clock combat/result captures were also inspected, bringing final visual review to thirteen images. [Native victory](foundry-environment/native-veteran-foundry-live-result.png) verifies the final UI state. These routes do not exhaust the late production budget; the preceding [production audit](FOUNDRY_PRODUCTION.md) covers full nine-unit Veteran production and a delayed assault.

## Reproduction and limits

Use Godot 4.6 with `--path . --headless --fixed-fps 60 --script tests/headless/FoundryEnvironmentRegression.gd` for geometry, observation and current/previous typed save checks. The retained baseline was recorded using `-- --baseline` before shipping edits. Shared mission and flight suites are `tests/headless/BrokenFoundryRegression.gd` and `tests/headless/IndustrialEnvironmentRegression.gd`.

Full difficulty routes use `tests/playtest/FoundryDifficultyMatches.gd -- --difficulty=0|1|2 --evidence=res://<fresh-prefix>`. Native scene inspection uses `tests/rendered/FoundryEnvironmentPreview.gd -- --evidence=res://<fresh-prefix>` without headless/fixed-FPS flags; native combat uses `FoundryDifficultyPreview.gd` with a difficulty and fresh prefix. Image capture refuses overwrites.

All twelve Godot processes completed successfully and are classified in [run-index.json](foundry-environment/run-index.json). Four changed/new GDScripts pass format and lint. No script or shader errors occurred; known navigation GPU-readback and shutdown ObjectDB/resource diagnostics remain. Source snapshots, existing asset hashes, actual archives, timelines, logs, an analyzer and SHA256 checksums are retained. Run `python3 docs/playtests/2026-10-07/foundry-environment/analyze.py` to check the evidence against current source/assets.

Final subjective environment quality, novice comprehension, repeated strategy/difficulty/reward balance and broader product/platform acceptance remain open. Performance stays deferred. The overall development goal remains active.
