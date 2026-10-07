# Intermittent movement — investigation, 2026-10-04

The [AI recovery cohort](AI_RECOVERY.md) recorded a 21-second Alpine AI tank delay and a 41.5-second Desert human engineer delay. Both had active ordinary orders and nonempty navigation paths. This investigation improves capture/replay and tests the recorded approaches; **the original two causes remain unresolved, and production movement is unchanged**.

## Additional complete matches

The same Advanced mixed reference commander ran cases 3 and 5 at seeds 4110 and 4111, Normal difficulty, with first-failure archive capture enabled. All four matches reach a result; none reaches the fifteen-second stationary threshold, so no failing-scene archive is generated. These are additional outcomes, not replacements for the original cohort or its four earlier negative diagnostic runs.

| Case / human faction / map | Seed | Human result | Time | Maximum stationary travel, human / AI |
| --- | --- | --- | --- | --- |
| 3 / Bastion / AlpineRelay | 4110 | Defeat | 7:04.0 | 1.5 / 1.5 s |
| 3 / Bastion / AlpineRelay | 4111 | Defeat | 10:24.1 | 1.5 / 1.5 s |
| 5 / Helix / DesertFrontier | 4110 | Defeat | 4:58.2 | 1.0 / 2.0 s |
| 5 / Helix / DesertFrontier | 4111 | Defeat | 5:17.1 | 2.0 / 1.0 s |

Evidence: [case 3 records](movement-followup-3.json), [case 3 log](movement-followup-3.log), [case 5 records](movement-followup-5.json), [case 5 log](movement-followup-5.log). Navigation/combat scheduling still varies across runs, including repeated seeds. These short matches do not establish ordinary pacing or balance.

## Recorded approaches and diagnostic fixture limits

The [initial probe](MovementApproachProbe.gd.txt) stages the recorded Alpine factory/lab/turret positions and Desert resource approach. Each faction's single tank clears the Alpine approach; each single worker finishes the short Desert move at the nearest reachable boundary. Six moving tanks and six gathering workers also make progress in the [trace](movement-approach-probe.log). This only establishes that the local route can work; it does not recreate the unknown surrounding traffic of the original delays.

A seeded [crowd sweep](MovementCrowdProbe.gd.txt) completes 16 Alpine and two Desert trials, then reaches the inherited 600-simulation-second test timer. Its [timeout log](movement-crowd-probe.log) is retained as an incomplete run. The later probes remove that inherited campaign timer; they were observed through live process handles until terminal exit.

The first [counterflow probe](MovementCounterflowProbe.gd.txt) captures a ten-second delay in Bastion Alpine trial 3. Three returning tanks share the same requested destination inside the HQ footprint; their routes terminate at the same reachable edge. The [archive](movement-crowd-stall.json) and [trace](movement-counterflow-probe.log) retain `unit-7` for diagnostic replay. These early fixtures also place the probe's units beside an opposing HQ, so restored idle units can attack it. Neither the shared terminal nor that ownership reproduces the original recovery-cohort scene. This failure is retained as a crowded-terminal diagnostic, not accepted as the original bug or used to justify a movement patch.

The [next version](MovementCounterflowDistinctProbe.gd.txt) separates the return destinations and completes 32 trials ([log](movement-counterflow-distinct-probe.log)). Final review corrects Alpine ownership so the staged structures and tested tanks belong to the existing local HQ owner, while testing the requested faction. The [final probe](MovementApproachFinalProbe.gd.txt) again completes all 32 trials using six real units per trial: eight seeds × two factions × two maps. Alpine alternates outward and returning tank orders to separated destinations; Desert workers actually gather and return cargo. Every trial runs for 30 simulation seconds after assignment.

| Final diagnostic group | Trials | Largest sampled stationary interval |
| --- | --- | --- |
| Helix / Desert | 8 | 1.5 s |
| Helix / Alpine | 8 | 0.5 s |
| Bastion / Desert | 8 | 1.5 s |
| Bastion / Alpine | 8 | 1.0 s |

The [final trace](movement-approach-final-probe.log) monitors all six units and would capture/terminate at ten seconds of active travel without 0.15 m displacement from the last progress point. Its diagnostic threshold differs from the full-match half-second travel metric. These are staged local probes, not completed matches, proof of every unit's arrival, or a reproduction of the original delays.

## Capture and replay improvements

`SkirmishTravelProbe` now retains the last actual avoidance callback velocity, nearby mobile agents' positions/radii/orders/destinations/velocities, and the movement sidestep state. A successfully captured archive prints the exact saved unit identifier. Existing first-failure behavior keeps the first archive instead of replacing it with subsequent samples. This extra information is test instrumentation and does not issue gameplay orders.

The [diagnostic regression](movement-diagnostics-regression.log) observes live movement callbacks and a nearby engineer, writes a real disk archive, checks that the printed identifier selects exactly the captured position, confirms later capture requests leave the first file intact, restores the exact unit/clock, and resumes its movement. The capture helper is invoked explicitly in this regression; its fixture does not pretend to be a naturally stalled unit.

`SkirmishTravelReplay` accepts an archive and its saved unit identifier, with a bounded simulation duration, optional removal of other mobile units and optional complete path/velocity output. A new archive requires an explicit unit id, so it cannot silently replay a guessed engineer. The no-argument behavior retains the original crowded-engineer archive and selector. AI strategic decisions remain disabled during replay; ordinary orders, local combat and other scene behavior continue. A zero exit means the requested observation completed (or the tracked unit died/match finished), **not** that navigation passed. The reported status distinguishes those cases.

The replay's compact summaries follow [TOON scalar/table syntax](https://github.com/toon-format/spec/blob/main/SPEC.md); `--full` adds full paths and requested/avoidance velocities. Godot's own startup/navigation/shutdown diagnostics remain outside that summary. Help and nine adverse argument/archive cases have their expected exit codes: [check results](movement-replay-cli-checks.json). Usage errors return 2, unreadable archives or invalid unit selection return 1, and help/observations return 0. No interactive prompt or session hook is added.

Actual ten-second replay evidence:

- [Legacy engineer](movement-replay-legacy.log): 14.821 m net travel and actual electronics collection after restore.
- [Crowded-terminal unit-7](movement-replay-crowded.log): 0.057 m net travel, still holding its move order.
- [Same unit with other mobile units removed](movement-replay-isolated.log): 0.811 m net travel, move order finishes and ordinary local attack takes over. This separates local crowd effects in the staged archive; it does not identify either original full-match delay.

Editor import, three-script formatting/lint and whitespace checks pass. Retained successful runs contain no script/assertion errors. Existing navigation-bake and shutdown-only resource/RID/ObjectDB diagnostics remain.

## Reproduction and next work

With Godot 4 available as `godot`:

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishTravelDiagnostics.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishTravelReplay.gd -- --seconds=10
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishTravelReplay.gd -- --archive=res://docs/playtests/2026-10-04/movement-crowd-stall.json --unit=unit-7 --seconds=10 --full
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishTravelReplay.gd -- --archive=res://docs/playtests/2026-10-04/movement-crowd-stall.json --unit=unit-7 --seconds=10 --isolated
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishMixedPolicy.gd -- --case=3 --repeats=1 --output=res://tmp/next-match.json --archive=res://tmp/next-stall.json
```

The [source manifest](movement-diagnostics-source-sha256.json) identifies the current replay/capture test code, unchanged production movement and all staged probe versions. Keep archive capture enabled in subsequent full matches; use the recorded unit id directly if a new failure occurs. This bounded investigation leaves movement correction pending until there is a valid original-scenario reproduction. Continue the broader gameplay goal with global AI coordination, then ordinary pacing and novice/content/release acceptance. Performance optimization remains deferred.


Follow-up: the [global coordination cohort](AI_COORDINATION.md) captures a live 16.5-second human Helix engineer delay at the Alpine home materials field after HQ loss. The [exact archive](ai-coordination-stall.json), unit id `unit-0`, [crowded replay](ai-coordination-stall-replay-crowded.log) and [isolated replay](ai-coordination-stall-replay-isolated.log) are retained. Both eventually enter the no-drop-off waiting state; nearby traffic changes the observed delay, but the complete cause and equivalence to the two earlier episodes are not established. Production movement is unchanged. This provides the next concrete investigation scene without replacing the earlier outcomes.
