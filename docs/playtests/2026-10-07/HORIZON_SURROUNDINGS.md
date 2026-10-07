# Command Horizon desert perimeter — 2026-10-07

Command Horizon now extends into a continuous desert basin. Ten mesas, a freight shelter, an extraction rig, utilities, a substation and fourteen exterior scrub clusters reuse the existing editable Desert and Industrial Surroundings kits. West/east access roads continue beyond the playable map; utility yards share the ground surface. Worn concrete, restrained sand ripples, road repairs and flush deployment/command markings replace the abrupt edge and raised painted boxes. Existing service structures gain the shared weathered concrete material. Eight low scrub patches add interior detail below 0.3 metres.

The playable area remains 184×132 metres. Existing cliff/service meshes, movement radii, sight heights, aircraft clearance, units, resources and objectives retain their gameplay geometry. The change touches the map script and its ground shader and adds one exterior script. No model, campaign rule, purchase price, response budget or save schema changes.

## Geometry and archives

Both route layouts were measured before editing. Default geometry has fifteen blockers; the Foundry reward removes the same two northern berms, leaving thirteen. Every measured position, radius, sight height and imported mesh bound matches baseline. Actual mesh bounds stay inside the 5.6-metre movement and 7-metre sight envelopes. Ground sight remains blocked and overhead sight open.

| Measured path | Default south layout | Unlocked north layout |
| --- | ---: | ---: |
| Across northern berm | 175.39 m | 30.00 m |
| Across southern passage | 30.00 m | 30.00 m |
| Deployment to command | 129.42 m | 113.44 m |
| Around service ruin | 34.69 m | 34.69 m |
| Around pump station | 34.65 m | 34.65 m |

All ten route lengths match the pre-edit measurements within 0.01 metres. All new exterior mesh vertices remain outside playable space; no new scenery joins physics, navigation obstacles or terrain navigation input. Exterior ground excludes the playable plane's two-metre margin, shares its material/world coordinates and meets it at zero height. Low interior cover stays below 0.3 metres. Initial enemy infantry remains unobserved; dim public exterior scenery does not reveal enemy units.

New typed disk archives from both layouts and the previously earned 407.73-second Veteran save restore unchanged while paused: mission state, time, players, unit positions, HP and paid production. Both route choices restore their exterior. Geometry/save checks preceded the final shader-only cleanup of road repairs and junction paint; all map geometry code remained unchanged during that cleanup.

## Gameplay verification

The shared environment suite passes all four home/forward material/electronics deliveries, rejection of construction on solids and acceptance on open ground. Drones and strike aircraft complete eight actual crossings over the berm and three service structures. The elevated aircraft archive, actual air-to-ground damage, blocked ground fire and event-coordinate drag selection checks pass. Shared mission rules also pass objective/guard restoration, finite difficulty/modifier budgets, progress migration and real tank traversal of both applicable passages with route restoration.

Fresh full fights use ordinary costs, harvesting, production, observed targets and existing programs. The test-only commander explicitly retakes deployment when needed after destroying the HQ; this introduces no shipping automation or free resources.

| Fight | Outcome | Simulated time |
| --- | --- | ---: |
| Story, south | Victory | 151.32 s |
| Standard, south | Victory | 144.10 s |
| Veteran, south | Victory | 239.22 s |
| Veteran, rendered north | Victory | 209.33 s |

All four fresh fights finish with the enemy HQ destroyed, deployment held/secured and four finite responses sent. Southern Veteran begins its explicit retake at 179.73 seconds; rendered northern Veteran begins at 166.20 seconds. The old earned Veteran save also recovers in 35.33 seconds after four ordinary paid infantry replacements. Different timings from earlier runs are observations, not evidence that visual changes caused better balance.

## Visual review and reproduction

Eleven final environment frames were inspected: start HUD, unseen command territory, dim normal-fog boundary, deployment, unlocked north passage, command apron, 1440×900 overview, north edge, west freight access, southern passage and east utility boundary. Other frames are 1280×720 at 150% UI scale. The first three retain ordinary fog. Remaining art views explicitly reveal terrain without changing unit observation; the empty command apron is not evidence of an absent enemy HQ. The earlier before/initial captures are retained separately. Initial square road repairs were softened, and junction center paint was cleaned up before final captures.

Three normal-clock combat/result frames were also reviewed, bringing final visual review to fourteen images. The 720p/150% objective panel clears the minimap and viewport. [Rendered victory](horizon-surroundings/native-north-horizon-live-result.png) confirms the final deployment/command result; its 2/6 campaign count reflects isolated Foundry-plus-finale test progress.

See the [overview](horizon-surroundings/final-overview.png), [deployment junction](horizon-surroundings/final-deployment.png), [north passage](horizon-surroundings/final-north.png) and [normal-fog exterior](horizon-surroundings/final-boundary-fog.png).

Run Godot 4.6 with `--headless --fixed-fps 60 --path . --script tests/headless/HorizonSurroundingsRegression.gd`, adding `-- --alternate` for the unlocked geometry. Retained baselines used `--baseline` before shipping edits. Shared suites are `HorizonEnvironmentRegression.gd` and `CommandHorizonRules.gd` under `tests/headless`.

Full fights use `tests/playtest/HorizonDifficultyMatches.gd -- --difficulty=0|1|2 --retake-deployment --evidence=res://<fresh-prefix>`. The earned continuation uses `HorizonDeploymentRecovery.gd` in the same directory. Native previews use `tests/rendered/HorizonSurroundingsPreview.gd` or `HorizonDifficultyPreview.gd` without headless/fixed-FPS flags. The latter takes `--alternate --difficulty=2 --retake-deployment` and a fresh evidence prefix. Captures refuse overwrites.

All fourteen Godot processes completed with zero assertion failures and are classified in [run-index.json](horizon-surroundings/run-index.json). Four changed/new GDScripts pass format/lint. No script or shader errors occurred; known navigation GPU-readback and shutdown ObjectDB/resource/RID/ParticlesShaderRD diagnostics remain. Source/asset hashes, before/accepted source snapshots, actual archives, logs, images and checksums are retained. `python3 docs/playtests/2026-10-07/horizon-surroundings/analyze.py` verifies the evidence and current source/assets.

These checks establish preserved contracts and viable fights. Novice comprehension, repeated strategy/difficulty/reward balance, subjective final environment quality and broader product/platform acceptance remain open. Performance optimization stays deferred, and the overall development goal remains active.
