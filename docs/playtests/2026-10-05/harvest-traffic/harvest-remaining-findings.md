# Remaining Helix harvesting traffic diagnosis

Read-only replay of `tmp/harvest-traffic-after-helix.json` using current production Movement.gd with the committed-recovery exit refresh. Replayed 3,600 physics frames at fixed 60 Hz; process exited 0 with `REVIEW COMPLETE`. Every original actor remained, including settled RepairRobot at (110, 0, 61). Only diagnostic files were authored.

Primary cause still present: worker child index 18, cargo 4, returning to HQ, command revision 39, navigation path index 5. Its next waypoint stays (109.972, 0, 61.34933), 0.350 m from the robot center, versus summed worker/robot radii 1.30 m and worker path tolerance 0.20 m. Waypoint acceptance is physically impossible. From replay t=48.52 through t=59.92, ordinary RVO moves the worker around the robot but Movement recovery stays 0 because each one-second net displacement exceeds 0.2 m. MovingToUnit does not revise the route because the worker is far from its HQ contact region.

Approximate 0.966-second progress-window samples (actual logged positions):

| t | Displacement | Gain toward same waypoint |
|---|---:|---:|
| 50.32 | 0.475 | -0.121 |
| 51.32 | 1.263 | -0.205 |
| 52.32 | 0.762 | 0.036 |
| 53.32 | 0.993 | -0.015 |
| 54.32 | 0.859 | 0.135 |
| 55.32 | 0.853 | -0.129 |

At t=56.52 the worker has reached (108.8364, 0, 61.53463), already beyond the robot on the north side, but requested velocity continues toward the interior waypoint. It then visits (109.7495, 0, 62.26575) at t=57.52, (110.6755, 0, 62.09391) at 58.52, and (111.2829, 0, 61.0848) at 59.52: a clear orbit rather than route progress. Other workers do trigger committed recovery and eventually finish these legs. Some waiting-at-HQ time is ordinary two-slot harvest reservation, amplified by long incoming travel; no assignment or cargo loss was observed.

A narrowly guarded periodic refresh of an impossible intermediate waypoint, using the same destination and current RVO-diverted position, directly addresses this cause. Restrict to settled local mobile blockers and actual intermediate points; preserve existing occupied-final-point, speed, contact, navigation and order semantics. This does not require broad classification of all lateral motion as stagnation.

Artifacts: `tmp/harvest-remaining-replay.gd`, `tmp/harvest-remaining-replay.log`.

## Subsequent regression extension and unresolved findings

`tests/headless/HarvestTrafficRegression.gd` now preserves the original Bastion/Helix/manual case order, then adds residual capture traffic. It verifies actual cargo deposits/contact, conservation, movement speed/clearance, immutable support position, harvest action/field/queue preservation, and a provisional 12-second maximum loaded-return duration over 60 seconds. The optional `--residual-only` flag runs that archive with a fresh navigation-agent lifetime. Formatting/lint pass. **This assertion is currently a failing target, not accepted green coverage. Do not raise its deadline to hide the behavior.**

An isolated first-fix project at `tmp/harvest-remaining-first-fix-project` uses current source/tests with only Movement.gd replaced by retained `Movement-first-fix.gd.txt`. Fresh-process repeats show organic traffic variation: first-fix longest returns 10.90, 12.13, 19.47 seconds; current second-fix 12.73, 8.38, 14.05 seconds. Therefore this scenario is not guaranteed to fail on every first-fix execution and current behavior does not yet meet the proposed 12-second bound.

One current trace (`tmp/harvest-remaining-return-probe.log`) found worker child index 6 / unit-18 returning cargo for approximately 24.5 seconds (t20.48–44.98). Most delay was around x107–109,z60–62, far from HQ. At t29.98–30.98 its position was almost fixed at (107.271,61.810) while next waypoint (107.6755,61.7867) was about0.405 m away. At t32.98–33.98 it was fixed at (107.381,61.206), next (107.8328,61.4142). Repeated recoveries escaped then returned. Those waypoints are outside the RepairRobot contact disc; the new impossible-waypoint helper does not apply. Hypothesis (not proven): full-speed steering toward a short reachable corner makes RVO predict travel beyond it into the robot before the route would actually turn. Three subsequent deeper replays did not reproduce >10-second midroute returns, so only the original position/path trace proves this occurrence; no exact snapshot was obtained.

Another current replay (`tmp/harvest-remaining-deep-probe.log`) found a 15.38-second return blocked at HQ by two empty workers waiting for work slots. Loaded worker at (110.42,66.21), idle workers at (109.343,66.955) and (111.404,67.055), HQ at(110,70). Requested velocity about(-1.82,3.38), actual/safe velocity about(.016,.022); navigation waypoint projected exactly onto itself. Open-face change and an outward recovery eventually delivered. Full scene captured in `tmp/harvest-remaining-hq-return-capture.json`. Later deep logs `tmp/harvest-remaining-midroute-{1,2,3}.log` cover all nearby static structures/mobile actors, safe/requested/actual velocities, and next-point projection; their longest returns were9.25,13.30(HQ),7.23 seconds.

Moving the residual case before the original manual case produced one manual goal assertion failure without geometric diagnostics. A corrected reproduction with full nearby actors (`tmp/harvest-remaining-manual-probe-corrected.log`) reached the unoccupied goal at (108.023,58.122), action null, with cargo retained. The earlier manual failure is not diagnosed; original ordering is preserved and no assertion was loosened.

All diagnostic process handles are terminal. Production files were never changed by this reviewer.


## Final candidate review

The failing-current observations above describe the now-replaced two-custom-patch candidate. The final production source comparison found exactly five lines added to stage-original Movement.gd: terrain-only NavigationAgent3D path simplification in `_ready`, enabled with epsilon0.01. Both custom refresh patches were removed. Godot4.6 documents simplification as a Ramer-Douglas-Peucker variant intended to mitigate steering/open-field avoidance problems: https://docs.godotengine.org/en/4.6/classes/class_navigationagent3d.html#class-navigationagent3d-property-simplify-path

Geometric review: a one-centimetre simplification can shortcut very shallow concave corners, so actual physical clearance tests remain necessary. It is small relative to the0.3m navigation cell,0.2m worker waypoint reach, and0.9m baked maximum agent radius. Navigation projection, RVO and ground contact clipping remain unchanged. Current production has no NavigationLink/waypoint signal consumers; only remaining-route-length and MovingToUnit corner-progress calculations consume the waypoint array. Both accept fewer points. Initialization applies to new and restored ground agents before movement physics; it does not replace a command, alter cargo/contact distances or reset action authority.

An exact stage-original isolated run of the final full HarvestTrafficRegression completed with four failures: Helix unit30 never collected or delivered over40seconds, and residual longest loaded return26.30seconds exceeded the unchanged12second bound. Physical clearance/speed/conservation/order checks passed. See `harvest-remaining-original-final-test.log`; the isolated source is `tmp/harvest-remaining-original-project`, with Movement.gd byte-equal to archived `Movement-before.gd.txt`. This supplies direct failing baseline evidence without altering the final test.
