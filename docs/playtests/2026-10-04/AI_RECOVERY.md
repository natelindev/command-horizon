# AI recovery and recommitment — 2026-10-04

The commander previously sent critically damaged units into another scheduled wave even when their matching repair facilities existed. Repair robots already supported ground armor, but aircraft and infantry had no dependable return-to-service task. The [original reproduction](ai-recovery-before.log) fails ten expectations: Tank, Infantry, RepairRobot, Helicopter and Drone for each faction.

## Behavior

A military mobile unit below 30% health now chooses the nearest reachable, completed, friendly facility of its service class: barracks for infantry, aircraft factory for aircraft, and repair depot for ground machines. Currently observed enemies capable of threatening that unit exclude unsafe service areas. Hidden contacts and unarmed reconnaissance do not affect the decision. Selection tests a navigation route ending within service range; this is not proof that the whole route is safe under fire.

The `RecoveringAtService` action travels by ordinary movement, stops within 4.5 metres and lets the existing repair service perform all healing. It retains the task until at least 80% health, preventing oscillation around the 30% entry threshold. Recovering units are excluded from economic defense, expansion guard, relay capture, attack waves, reconnaissance and repair-escort reassignment. Healthy reserves keep their ordinary duties. Recovered units become eligible for the next relevant duty; attack wave timers and minimum force size remain in effect. Engineers retain their separate cargo/construction/withdrawal authority.

The commander can redirect recovery to another safe compatible facility if the first becomes unsafe or disappears. If none remains, an established recovery task holds and waits instead of sending the half-healed unit back to an attack. Five seconds without travel progress stops movement; the same service cannot be retried for ten simulation seconds, while a reachable alternative can be chosen sooner. A new recovery is not invented when no suitable service exists, so that unit retains its ordinary command. Direct action replacement cancels recovery through the existing order arbiter.

Recovery changes neither health values nor repair rates, facility slot limits, low-power penalties, resource costs, combat damage or movement speed. It does not purchase missing facilities, coordinate an army-wide disengagement, or guarantee that a retreating unit survives incoming fire.

## Real travel, service and persistence

The [targeted regression](ai-recovery-regression.log) stages five damaged roles and three service facilities in Desert Frontier for each faction. Initial health is deliberately set to 25%; thereafter units travel and heal through actual movement and service processing. Three healthy reserves can still launch a scheduled wave. Each of the five roles reaches at least 80%, then receives its appropriate combat, reconnaissance or repair-support duty. Resource stocks remain unchanged. This proves use of the existing free service channel; the staged initial damage is separate from the full-match combat records below.

Real disk archives are taken during return travel, during partial healing and during a deliberately blocked approach. Paused restores preserve health, position, service references, recovery state and retry duration. Resume completes treatment and allows the bounded retry. Archive validation rejects an excessive retry duration, an enemy provider and an incompatible provider. Recovery is an additional allowlisted action in the existing snapshot format; legacy archive checks are retained.

Other staged contracts cover exact 30%/80% boundaries, hysteresis at 50%, unfinished/wrong service classes, hidden versus revealed danger, an unsafe provider followed by actual alternate-provider deletion, direct replacement and five-second blocked travel. The movement trait is deliberately disabled only in the blocked-retry fixture, then restored. Separate Alpine cases prove that half-healed infantry keep recovery while healthy infantry receives a relay task, and that recovered infantry can resume relay duties. A nearby real enemy contact exercises defense priority without stealing central recovery assignments.

## Shared and rendered checks

All fifteen shared suites pass: [defense](ai-recovery-SkirmishDefenseRegression.log), [composition](ai-recovery-SkirmishCompositionRegression.log), [support](ai-recovery-SkirmishSupportRegression.log), [offense](ai-recovery-SkirmishOffenseRegression.log), [budgets](ai-recovery-SkirmishBudgetRegression.log), [adaptive labor](ai-recovery-SkirmishLaborRegression.log), [field expansion and raids](ai-recovery-SkirmishExpansionRaid.log), [combat](ai-recovery-CombatRegression.log), [orders](ai-recovery-OrdersRegression.log), [restoration edges](ai-recovery-SaveRestoreEdges.log), [combat restoration](ai-recovery-SaveRestoreCombat.log), [snapshot validation](ai-recovery-SaveSnapshotRegression.log), [Desert AI](ai-recovery-FrontierAIRegression.log), [Industrial AI](ai-recovery-IndustrialAIRegression.log) and [Coastal AI](ai-recovery-CoastalAIRegression.log).

The [normal-clock rendered run](ai-recovery-rendered.log) passes the Desert return/healing/retry/archive scenarios at 1280×720 and 150% interface scale. All four final captures were inspected: [Bastion healing](../../../art/skirmish/ai-recovery-bastion-service.png), [Bastion ready](../../../art/skirmish/ai-recovery-bastion-ready.png), [Helix healing](../../../art/skirmish/ai-recovery-helix-service.png) and [Helix ready](../../../art/skirmish/ai-recovery-helix-ready.png). Three staged unarmed human scouts reveal the service areas through normal observation; the first review's single scout was blocked by facility silhouettes, so its four visibility assertions correctly failed. The final review uses separate clear sight lines without changing the AI recovery orders or positions. The images show ordinary health bars and facilities; no native-input claim is made.

The [editor import](ai-recovery-editor.log), format and lint checks pass. Successful retained logs contain no script/assertion errors; existing navigation-bake and shutdown RID/ObjectDB/resource warnings remain.

## Complete-match observations

The new recovery probe samples actual recovery actions every half simulation second, distinguishing recovered, interrupted, lost, removed and still-active episodes, plus sampled service arrival and blocked time. Its [regression](ai-recovery-metrics.log) checks all five roles, healthy release, actual destruction, interruption and a blocked interval. The reference commanders themselves are unchanged.

The [eight complete records](ai-recovery-matches.json) use Normal difficulty, seed 4110 and unchanged reference commanders: Standard ground for even cases and Advanced mixed for odd cases. Every match reaches a result; none remains unresolved. Results are from the human reference policy's perspective. Recovery counts describe the opposing AI, and episodes can include repeated returns by the same unit.

| Human faction | Map | Start / policy | Result | Time | AI waves | Recovery: completed / lost / active | Longest stationary travel, human / AI |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Bastion | Desert | Standard ground | Victory | 10:16.8 | 5 | 4 / 3 / 0 | 8.0 / 1.5 s |
| Bastion | Desert | Advanced mixed | Defeat | 7:07.0 | 5 | 4 / 3 / 1 | 1.0 / 2.0 s |
| Bastion | Alpine | Standard ground | Victory | 7:33.9 | 4 | 5 / 3 / 0 | 1.5 / 1.0 s |
| Bastion | Alpine | Advanced mixed | Defeat | 11:57.3 | 10 | 5 / 11 / 1 | 1.5 / 21.0 s |
| Helix | Desert | Standard ground | Defeat | 5:42.3 | 2 | 0 / 3 / 1 | 1.0 / 1.5 s |
| Helix | Desert | Advanced mixed | Defeat | 5:31.3 | 4 | 2 / 4 / 0 | 41.5 / 3.0 s |
| Helix | Alpine | Standard ground | Defeat | 12:16.4 | 10 | 9 / 8 / 0 | 4.0 / 8.5 s |
| Helix | Alpine | Advanced mixed | Defeat | 5:57.8 | 4 | 7 / 5 / 0 | 1.5 / 1.0 s |

Raw logs: [0](ai-recovery-match-0.log), [1](ai-recovery-match-1.log), [2](ai-recovery-match-2.log), [3](ai-recovery-match-3.log), [4](ai-recovery-match-4.log), [5](ai-recovery-match-5.log), [6](ai-recovery-match-6.log), [7](ai-recovery-match-7.log).

The cohort records 79 actual recovery episodes: 36 complete, 40 units lost during recovery and three still recovering when the match ends. All 36 completed episodes include a sampled stationary arrival within service range and end at or above 80% health. Completed roles are 22 infantry, nine tanks, three repair robots and two combat robots. This cohort does not establish aircraft recovery in full combat; aircraft are covered by the targeted travel/service/archive tests. Three infantry episodes each spend nine sampled seconds blocked and later recover. The probe does not distinguish an unsafe provider from blocked navigation, or attribute each health point to an individual repair source.

The human policy wins two of eight matches (Standard 2/4, Advanced mixed 0/4). Navigation/combat scheduling varies between runs with the same seed, so these outcomes cannot isolate recovery's effect on win rate. Durations of 5:31.3–12:16.4 remain below the ordinary 20–30-minute pacing hypothesis. No balance acceptance is claimed.

## Stationary-travel follow-up: unresolved

Two original matches contain long stationary-travel episodes. In case 3, an AI tank holds an ordinary `AttackMoving` order for a maximum of 21 seconds near its Alpine factory/lab area. In case 5, a human engineer holds its materials-approach task for 41.5 seconds near the Desert home field. Both traces retain navigation paths, synchronized maps, nonzero requested velocity and current avoidance callbacks. Neither unit is executing recovery. This observation does not rule out an indirect effect from surrounding traffic, and the available trace does not establish the cause.

The original cohort did not enable the optional archive capture, so its exact failing scene cannot be replayed. Four additional full matches enable capture at the first fifteen-second stationary episode; none reaches that threshold and no archive is produced. All four trials are retained, without replacing the original outcomes:

| Diagnostic | Result | Time | Maximum stationary travel, human / AI | Evidence |
| --- | --- | --- | --- | --- |
| Case 3, repeat 1 | Defeat | 11:55.7 | 1.0 / 3.5 s | [Record](ai-recovery-diagnostic-3-0.json), [log](ai-recovery-diagnostic-3-0.log) |
| Case 3, repeat 2 | Victory | 19:15.4 | 2.0 / 6.5 s | [Record](ai-recovery-diagnostic-3-1.json), [log](ai-recovery-diagnostic-3-1.log) |
| Case 5, repeat 1 | Defeat | 7:02.7 | 1.0 / 1.5 s | [Record](ai-recovery-diagnostic-5-0.json), [log](ai-recovery-diagnostic-5-0.log) |
| Case 5, repeat 2 | Defeat | 8:11.0 | 3.5 / 2.5 s | [Record](ai-recovery-diagnostic-5-1.json), [log](ai-recovery-diagnostic-5-1.log) |

These are bounded negative reproductions, not a movement fix. The original stationary episodes remain an open gameplay reliability issue. Future complete-match runs should keep `--archive` enabled to retain the first live failure before changing movement. Broader army coordination, sustained contested mixed-force strategy, ordinary pacing and novice/content/release acceptance also remain open. Performance optimization stays deferred.

## Reproduction

With a Godot 4 executable available as `godot`:

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishRecoveryRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishRecoveryMetricsRegression.gd
godot --path . --rendering-method mobile --script tests/rendered/SkirmishRecoveryPreview.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/BaseAccessMatches.gd -- --case=0 --repeats=1 --output=res://tmp/recovery-standard.json --archive=res://tmp/recovery-standard-stall.json
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishMixedPolicy.gd -- --case=3 --repeats=1 --output=res://tmp/recovery-mixed.json --archive=res://tmp/recovery-mixed-stall.json
```

The [21-file source manifest](ai-recovery-source-sha256.json) records production, persistence, probes and policy/test scripts. Production and measurement code stayed fixed throughout the final cohort. The targeted regression gained separate Alpine relay assertions and a lint-only load consolidation during that cohort; its final headless run passes. The rendered run covers the Desert scenarios, not the later Alpine assertions.


Follow-up: [the movement investigation](MOVEMENT_DIAGNOSTICS.md) retains four more complete matches, 32 final local trials and improved capture/replay. The original two delays remain unresolved; production movement was not changed.
