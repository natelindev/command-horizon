# Split Signal alpine communications environment — 2026-10-07

Split Signal now uses a continuous alpine snowfield with plowed access roads, wheel tracks, granular snow/gravel, weathered octagonal relay aprons and flush service hatches. The three objective sites remain readable from the normal gameplay camera. Exterior granite, pine groves, a weather station and abandoned cable stations replace the abrupt rectangular black boundary. Twelve low sedge patches add ground detail without occupying route or building footprints.

This map reuses the existing editable alpine kit from `art/environment/build_alpine.py` and `assets/models/environment/alpine/`; it does not introduce another parallel asset collection. Its exterior layout and ground shader are authored for the 108×88-metre mission. Tall scenery stays outside playable space. Mission shelf models, their positions, blockers, resource deposits, relays and response entries retain their original gameplay geometry.

## Geometry and presentation evidence

The three shelf envelopes remain radius 6.5 m / sight height 1.15 m. Imported mesh radii are 5.65–5.83 m and maximum mesh height is 1.092 m. Ground-level sight is blocked; overhead sight remains clear. Four ground-navigation route lengths match the baseline exactly at 38.6365 / 34.4264 / 30.4178 / 30.2662 m.

Every imported exterior mesh vertex stays outside playable space. Exterior nodes add neither collision objects nor navigation obstacles; surrounding ground joins the existing terrain at zero elevation. The opening observation check still hides the enemy infantry. The reveal used for art-review frames is explicit and is excluded from gameplay/observation claims.

Seven environment captures have been visually reviewed: the [normal opening](split-environment/after-start.png), [North](split-environment/after-checkpoint-0.png), [East](split-environment/after-checkpoint-1.png), [South](split-environment/after-checkpoint-2.png), [wide composition](split-environment/after-overview.png), [weather station](split-environment/after-station.png) and [western boundary](split-environment/after-boundary.png). They use 1280×720 at 150% UI scale, with a 1440×900 wide view. Compare the original [bare-map overview](split-environment/baseline-overview.png).

## Verification status

The shared Split Signal suite passes actual three-route travel/capture, optional network scoring, capture/contest/pause, disk restoration, finite response budgets, progress migration and defeat. Shared relay-feedback checks also pass. The previous earned stalled archive retains exact paused unit positions/HP and recovers through ordinary selection plus a move in **12.85 seconds headless / 12.80 seconds rendered**. The rendered continuation uses real mouse/Enter and right-click input; idle/busy selection, barracks fallback and absent infrastructure remain usable at 720p/150%.

| Full route | Result | Simulation time | Responses sent | Human survivors |
| --- | --- | ---: | ---: | ---: |
| Story, headless | Victory | 136.52 s | 4 | 23 |
| Standard, headless | Victory | 198.67 s | 6 | 19 |
| Veteran, headless | Victory | 136.52 s | 4 | 24 |
| Veteran, normal-clock | Victory | 136.67 s | 4 | 24 |

These use the existing reference commander's Guard/Service assignments, explicit infantry moves and observed-target clearance. Standard activates the clearance helper after six responses, issuing 50 ordinary targeted attacks with queued relay follow-through. The other three routes win before that helper activates. No unit/resource grants or finish shortcuts occur in these full routes. Results demonstrate viable routes, not a causal effect of environment art or repeated difficulty balance.

Fourteen final captures were visually reviewed: seven environment views, [normal-clock mid-battle](split-environment/native-veteran-combat.png) and [victory](split-environment/native-veteran-result.png), plus five recovery/control views. The [queued recovery move](split-environment/recovery-ui-ordered.png) and [earned result](split-environment/recovery-ui-victory.png) retain normal fog of war.

All fifteen Godot processes are classified in `split-environment/run-index.json`, including the three rejected fixture attempts below. Five changed/new GDScripts pass format and lint. Final shader compilation has no errors. Known navigation GPU-readback warnings and shutdown resource/ObjectDB diagnostics remain. Source hashes restrict this pass's shipping changes to `SplitSignalMap.gd`, `split_signal.gdshader` and the new `SplitBackdrop.gd`; capture, combat, budgets and archive schemas are unchanged.

## Reproduction

Use the project's Godot 4.6 executable with `--path .`. The geometry check is `--headless --fixed-fps 60 --script tests/headless/SplitEnvironmentRegression.gd`. For a full route use `tests/playtest/SplitDifficultyMatches.gd -- --difficulty=0|1|2 --clear-contests --evidence=res://<fresh-prefix>` with the same headless flags. Use `tests/rendered/SplitEnvironmentMatch.gd` without headless/fixed-FPS flags for a normal-clock route. `SplitEnvironmentPreview.gd` produces art-review frames; `SplitCaptureShortcutPreview.gd` verifies the retained earned archive and live recovery input. Supply a fresh `--evidence` prefix for each rendered run; captures refuse overwriting.

The evidence folder contains exact baseline/final geometry, immutable source snapshots, model provenance hashes, match timelines, classified logs, an evidence analyzer and SHA256 checksums. Run `python3 docs/playtests/2026-10-07/split-environment/analyze.py` to verify the retained results against current source.

## Fixture corrections and limits

The first baseline script lacked its route-length helper and did not execute. The first rendered fixture incorrectly assumed the opening enemy force contained a tank; it stopped after the opening capture and was explicitly terminated. The corrected fixture checks the authored infantry. The first geometry comparison incorrectly used exact dictionary equality against JSON-rounded floating-point values; both serialized geometry reports are identical, and the corrected comparison uses numerical tolerance. All these logs are retained and classified separately from passing verification.

The environment does not establish novice comprehension, repeated strategic balance, final subjective art acceptance or platform/performance readiness. The wider development goal remains active and performance work remains deferred.
