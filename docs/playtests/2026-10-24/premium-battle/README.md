# Camera, battlefield feedback and four-player queries

## Delivered behavior

The existing prepaid research queue and commander roster were already implemented at the start of this follow-up. Their paid FIFO, dependency/refund, lab-loss, paused disk restore, elimination grace, public identity and bilingual interface contracts pass the focused checks below. Snapshot version stays at v19.

Camera movement now integrates exponential acceleration and damping exactly, giving the same travel at 30, 60, 144 and 240 display updates per second. MMB grabs a world point without rotating; Alt + MMB rotates, and Alt + double MMB resets rotation. Active grabs continue across HUD controls. Release over HUD, focus/modal suspension, minimap teleports and map bounds clear the corresponding motion. The settings pan-speed tooltip explains the mouse controls in English and Simplified Chinese.

Right-drag orders show terrain-following rank ribbons, per-slot facing triangles and a facing arrow. The preview shares the formation layout with order dispatch, avoids its assignment solver and reuses unchanged geometry. It previews the intended formation; ordinary navigation still projects final destinations around obstacles. Press/release retains the existing single-order revision and queue behavior. Accepted commands use depth-tested terrain rings, with a crosshair for attack commands; rejection text remains readable.

Battlefield body queries use shared fine/coarse spatial hashes across owners, filter current ownership in the narrow phase, and retain the movement allowance across cell boundaries. Spawn/topology changes invalidate the current index. Minimap markers rotate through three phases at the 30 Hz simulation cadence (10 Hz per marker); hidden/removed bodies are cleaned up, and restoration seeds the initial complete marker set before returning control.

Muzzle lights reuse a bounded pool of unshadowed local lights, with at most four optional weapon lights inside the existing eight-light aftermath budget. Light and heavy weapons have different flash strengths. Non-explosive hits on mobile armor emit reflected spark fans; the existing spark buffer draws velocity-aligned streaks. Visibility, pause, audio routing and reduced-flash options remain authoritative.

Prewarming now includes terrain-feedback materials and local lighting. It explicitly requests preparation draws and checks cancellation on update ticks, so an idle/unfocused native window cannot leave cancellation waiting for an automatic redraw. Proxies and covers are disposable; live RNG, materials, pools, simulation state and process modes are verified unchanged. A restored match initializes minimap phases once before the caller sees it.

## Verification

- All **20 final headless suites pass**; see [headless-results.json](headless-results.json). Coverage includes new camera and feedback regressions, four-owner spatial oracle checks, settings, research queue, commanders/localization, direct orders, combat/audio, mixed armies, navigation/crowd recovery, sight and save restoration. The new camera, feedback and spatial suites are registered in the desktop release test list.
- Research tiles, economy and feedback also passed the initial audit. Those three audit logs are retained separately.
- `CombatPrewarmRegression.gd` passes both rendered and headless paths. Rendered cases cover option variants, process-mode/resource preservation, paused restore, scene replacement, deleted matches, actual restore cancellation, new-loading handoff/cancellation and application shutdown ownership.
- `ResearchQueuePreview.gd` passes all six faction/language cases at 720p/150%, including actual GUI keyboard purchases, focus, cascading refunds and pause ownership. `HudConsolePreview.gd -- --elimination` passes the three-faction English/Chinese four- and eight-player commander matrix.
- `PremiumBattlePreview.gd` passes six captures across all factions. Geometry spans the Glacier Narrows ramp; rings retain depth testing, and close views exercise armor sparks, shot lighting and paused accessibility changes. Review media is generated under `art/premium-battle/` and `art/hud-console/` and is intentionally ignored by Git.
- Changed GDScript passes formatting/lint; the release build script compiles and `git diff --check` passes. A macOS test PCK exports successfully. These changes have not replaced the previously accepted production packages or run the full native-platform release matrix.

Tests ran in isolated project configurations with private user-data directories. Existing player preferences, campaign progress and saves were not used as test fixtures.

## Query timing

Native **release** engine, Godot 4.7.2 official, Apple M1 Pro. Each sample issues 200 three-metre local queries across four owners; 100 samples follow warm-up. Positions use a fixed seed. Returned-result checksums match the original implementation in both layouts.

| Layout / implementation | Median batch | p95 batch | Mean grid rebuild |
| --- | ---: | ---: | ---: |
| Dispersed baseline | 1.269 ms | 1.355 ms | 0.286 ms |
| Dispersed current, run 1 | 0.431 ms | 0.461 ms | 0.294 ms |
| Dispersed current, run 2 | 0.426 ms | 0.452 ms | 0.295 ms |
| Dense baseline | 1.672 ms | 1.823 ms | 0.274 ms |
| Dense current | 0.783 ms | 0.857 ms | 0.256 ms |

The requested 0.5 ms query budget is met for the dispersed batch. **It is not met for dense clusters, and these batch times exclude grid rebuilding.** This Mac microbenchmark does not reproduce the user's approximately 4.7 ms Windows measurement and must not be presented as that measurement's before/after result.

`FourPlayerQueryBenchmark.gd` is the reproducible source. The retained Node bootstrap runs the same scenario as an exported startup scene, because the hardened native release binary rejects `--main-pack` overrides. The editor's `--script` path is useful for reproduction but has different debug overhead. Raw timing rows and scenario parameters are in [measurements.json](measurements.json).

## Rendered four-player workload

`FourPlayerFrameBenchmark.gd` uses four hostile owners with **200 mobile units and 80 structures**, real movement and weapon effects, high HP to preserve population, a 1920×1080 viewport, 30 Hz simulation and no fixed render FPS. Combat lines are interleaved with legal body spacing so all sides have nearby opponents. Each measured phase advances eight seconds of simulation; the combat sample checks sustained shots and at least 80 firing units. This is a synthetic workload, not a balance or complete-match test.

| Editor run | Movement mean / p95 | Combat mean / p95 | Units that fired |
| --- | ---: | ---: | ---: |
| Pristine HEAD baseline | 35.43 / 45.78 ms | 31.17 / 41.60 ms | 157 |
| Current run 1 | 35.85 / 45.36 ms | 31.89 / 41.88 ms | 157 |
| Current run 2 | 36.91 / 47.26 ms | 32.08 / 42.19 ms | 159 |
| Final source, velocity-aligned sparks | 36.18 / 48.34 ms | 32.96 / 43.52 ms | 157 |

**An end-to-end frame-rate gain has not been established.** The new presentation and query/minimap changes together remain below 60 FPS on this M1 Pro workload. The current combat samples had no frame above 100 ms, but earlier movement samples retained a first-use tail (115–154 ms maximum). The final source run had 55.84 ms movement and 53.49 ms combat maxima; this single warm repeat does not close cold-start acceptance. Metal reported zero GPU time, so those unavailable counters are not treated as measurements. Native Windows four-player timing, longer matches and broader devices remain open acceptance work.

The mixed-army regression also failed on pristine HEAD. Native release verification later captured a worker returning to a navigation corner covered by a settled tank. Ground recovery now rebuilds its path after the detour. The recorded layout fails before the fix and passes afterward; nine follow-up source checks and six exported mixed-army repeats pass. See the [release verification report](../release-v0.17.0/README.md). Final native-platform verification is blocked by GitHub Actions allowance/storage. Existing shutdown resource warnings remain in the logs.

## Reproduction

Use an isolated copy/configuration and the official Godot 4.7.2 engine. Run headless suites with `--headless --fixed-fps 60 --script res://tests/headless/<suite>.gd`. Run the camera/feedback regressions, then the rendered previews without `--headless`.

For performance, run `--script res://tests/rendered/FourPlayerFrameBenchmark.gd` without `--fixed-fps`. For the local-query layout, run `--headless --script res://tests/headless/FourPlayerQueryBenchmark.gd`; append `-- --clustered` for the dense layout. Use an exported startup scene for release timings. Do not run another benchmark or test process at the same time as a timing sample.
