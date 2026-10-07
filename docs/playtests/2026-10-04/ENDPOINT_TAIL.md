# Crowded arrival across a short path bend

Plain ground Move can now finish beside a settled ally occupying its final reachable point even when a small navigation-path bend remains. Completion uses the remaining path distance, bounded by the two units' radii plus 0.2 m, as well as the existing proximity and two-second no-progress checks. Longer routes still have to be travelled. This changes three runtime files: movement's endpoint query, the archive field list and archive validation.

## Failure and correction

The previous complete-match pass retained [AI tank `unit-42`](corner-recovery-final-match-2-stall.json) beside the Industrial Command Lab. The requested destination `(107, 0, 49)` is inside the lab, so its path ends at `(106.2, 0.6, 49.8)`. Two settled friendly tanks occupy that reachable endpoint's clearance area. The [original trace](endpoint-tail-before-trace.log) shows only 0.85 m of remaining travel, but the path index stays at 1 of 3 points. The old completion check required the last index and never accepted the already-adjacent position.

The prior thirty-second replay displaced only 0.001 m and remained Moving. Removing other mobile units let it finish, narrowing the failure to traffic rather than a missing static route. The [final regression with archived old movement](endpoint-tail-final-contract-before.log) fails seventeen assertions: three original replays, both fresh faction fixtures and the queued handoff still fail. Current archive handling is retained in that comparison, isolating movement behavior. An earlier [full before run](endpoint-tail-verified-before.log) also exposes the missing archive timer; the initial unaccepted `endpoint-tail-before.log` has a test preload error and is not behavioral evidence.

The corrected query sums travel from the unit through the remaining path points. It retains a living, stationary, same-player mobile ally in the same movement domain, occupancy of the final reachable point and the existing proximity limit. No destination, body radius, speed, collision handling or work-contact rule changes. Recovery's existing short yielding uses the same proximity-only query as before; it does not receive a longer arrival radius.

## Arrival, authority and archives

The [final regression](endpoint-tail-final-regression.log) covers three exact original captures, fresh Bastion/Helix setups, manual replacement/Stop, a queued departure after a paused disk reload, and adverse limits.

| Case | Result |
| --- | --- |
| Original tank, three replays | Move retires after about 2.02 seconds |
| Fresh Bastion and Helix | Move retires after about 4.02 seconds; initial placement adjustment requires a second observation window |
| Queue saved after 0.5 seconds | Preserved timer; handoff after about 1.53 seconds following reload; next destination reached |
| Nearby endpoint across obstacles | Approximately 1.77 m straight-line distance, 7.58 m remaining route; Move remains active |
| Enemy / moving ally / aircraft / distant / unoccupied endpoint | Move remains active |
| Manual replacement and Stop | New destination and manual authority retained; Stop clears movement |

Captured/fresh arrival remains under the per-frame speed limit and does not cross the tested unit/building footprints. The original cases finish within a millimetre of their starting position rather than taking a new route or teleporting. Fresh cases adjust by about two centimetres. Clearance tolerates at most 0.08 m of numerical contact overlap; measured overlap is below 0.00001 m.

Archives now retain plain Move's `_arrival_elapsed` and `_arrival_progress`. They remain frozen with position, simulation time and the queued order through sixty paused frames. Old archives missing both fields still load and begin their observation when resumed. Partial fields, negative/out-of-range/non-finite/non-numeric timers and a running timer without a valid origin are rejected. This is an additive compatibility extension within the existing archive format. MovingToUnit retains its separate contact behavior.

## Shared and rendered verification

The [33-suite execution ledger](endpoint-tail-checks.json) records **32 passes and one failure**, with no script errors. Passing suites cover the new regression, navigation/contact/air movement, both maps, guard and recovery programs, manual/combat orders, snapshot validation, three save/restore suites, AI coordination/recovery, crowded destinations, Frontier crowd flow and Lua/visual behavior. The final new regression was rerun after test-only cleanup and also passes. Lint, formatting, editor import and tracked diff whitespace checks pass.

The failing [CrowdBoundaryRegression](endpoint-tail-check-CrowdBoundaryRegression.log) is retained: its third archived engineer travels 8.02 m at ten seconds but misses the fifteen-second electronics-cargo deadline. The first two replays and both fresh paid harvesting flows pass. Ten additional archived replays with [old movement](endpoint-tail-crowd-repeat-before.log) and ten with [current movement](endpoint-tail-crowd-repeat-after.log) all meet the deadline. The intermittent failure is not erased or converted to a passing suite; further instrumented comparison is recorded below.

A further twenty instrumented replays per runtime also pass: [old movement](endpoint-tail-crowd-instrumented-before.log), [current movement](endpoint-tail-crowd-instrumented-after.log). Across all forty, the changed bounded-arrival branch is never called. Together with the archive containing no plain Move actions, this is evidence that the observed harvesting delay is outside the behavior changed here; it does not explain or fix the deadline miss. Sixty additional replays pass in total. Preserve the original failure and capture its live traffic if it recurs, rather than relaxing the deadline or claiming 33 passing suites.

The [normal-clock rendered run](endpoint-tail-spectator-rendered.log) passes the original and fresh faction arrivals at 1280×720 and 150% interface scale. All four captures were reviewed. These are diagnostic spectator views with full-map presentation enabled, so the captured AI side is visible without advancing the paused battle; the HUD still belongs to the human side. They verify physical arrival, scene presentation and pause consistency, not human command input, normal fog acceptance or a newly authored UI flow. Earlier partial-fog preview attempts remain in their logs and are not accepted screenshots.

| Original scene | Completed arrival | Fresh Bastion | Fresh Helix |
| --- | --- | --- | --- |
| [Before](../../../art/skirmish/endpoint-tail-before.png) | [After](../../../art/skirmish/endpoint-tail-captured.png) | [Settled](../../../art/skirmish/endpoint-tail-fresh-bastion.png) | [Settled](../../../art/skirmish/endpoint-tail-fresh-helix.png) |

## Complete-match follow-through

Four Advanced-start matches against Normal AI finish on the tested runtime, using the established responsive reference commander. All 3,451 AI coordination samples have zero violations. No fifteen-second stationary archive or guard pre-block capture triggers. Longest stationary-travel episodes are 3.5 seconds or less.

| Faction / map | Outcome | Duration | Longest commander / AI stationary episode |
| --- | --- | ---: | ---: |
| [Bastion / Industrial](endpoint-tail-match-0.json) | Victory | 6:56.9 | 3.0 / 1.5 s |
| [Bastion / Coastal](endpoint-tail-match-1.json) | Defeat | 5:27.1 | 1.5 / 1.5 s |
| [Helix / Industrial](endpoint-tail-match-2.json) | Victory | 8:24.4 | 2.5 / 3.5 s |
| [Helix / Coastal](endpoint-tail-match-3.json) | Defeat | 7:57.2 | 3.0 / 1.5 s |

The [artifact audit](endpoint-tail-audit.json) verifies 396 current source hashes, retains 25 code/test/commander snapshots and records the single shared failure alongside passing evidence. The [source fingerprint](endpoint-tail-tested-source.json), [check runner](run_endpoint_tail_checks.py.txt) and [match runner](run_endpoint_tail_matches.py.txt) identify the implementation and exact commands. Godot's existing navigation geometry readback and exit-time resource/shader warnings remain visible in the logs.

The retained Industrial blockage is fixed. This small match sample does not establish universal congestion freedom, faction balance, intended pacing or novice success. Both Coastal trials still lose and all four matches remain below the intended 20–30-minute target; further strategy/pacing work is needed. Wider content, environment quality, physical-device/platform and release acceptance remain open. Performance optimization remains deferred.

## Reproduce

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/EndpointTailRegression.gd
godot --path . --script tests/rendered/EndpointTailPreview.gd
```
