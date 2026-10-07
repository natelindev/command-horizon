# Global AI task coordination — 2026-10-04

The AI previously allocated economic defense, field guards, relay infantry and attack waves independently. A staged Alpine case produced four simultaneous strategic destinations at every difficulty for both factions. The [original reproduction](ai-coordination-before.log) fails six budget assertions; its [source](ai-coordination-before.gd.txt) is retained.

## Behavior

One persistent task roster now limits Story / Standard / Veteran to one / two / three simultaneous combat tasks. A task is an observed raid response, an assault, a nearby resource-field guard, a relay capture or standalone reconnaissance. Defense claims capacity first and can preempt ordinary tasks. Military recovery remains outside the available roster until its existing health threshold releases the unit. Economic work, cargo return, individual repairs and return-to-HQ orders are not separate combat tasks.

Ordinary tasks retain their destination and core members for up to ninety simulation seconds before a waiting eligible task can replace them. Completed captures release immediately. The rotating selector prevents a single field guard from occupying Story's only slot indefinitely; reconnaissance cannot evict a viable combat/economic task. Assaults still require three available combatants and their existing first-wave/interval gates. Up to three surviving core assault members remain committed; surplus reinforcements remain eligible for bounded guard/capture teams when another task slot opens. Remaining combatants then reinforce the assault. Unassigned military units regroup at HQ.

One field task can protect material/electronics approaches within twelve metres. Guards share the existing two-unit limit and require at least half health. When a guard task retires, matching harvesters preserve their cargo and return through their ordinary harvest action. The task retains its guards until tracked returns finish; higher-priority defense, lost guards or a worker's construction/withdrawal authority can end that commitment sooner. New remote jobs require an active, non-retiring field task and actual nearby guard coverage. This is bounded protection, not a guarantee of a safe route or an invulnerable engineer.

Free scouts follow a nearby active task; they receive an independent reconnaissance task only when no other task is active. Repair robots can follow healthy assigned combatants and still repair wounded eligible units outside the roster. Existing unit stats, prices, repair rates, reaction delays and fog observation rules remain in effect.

A real-fire reproduction found that an existing `AttackMoving` shot prevented a changed strategic destination from being applied. Both factions kept the old goal instead of responding to the newly selected raid. The [failure](ai-coordination-engaged-before.log) and [corrected run](ai-coordination-engaged-after.log) retain that case. Changed destinations now update the current engagement’s later route; unchanged destinations remain stable. Attack-move can still engage nearby enemies, so this does not claim immediate disengagement from every local fight.

The first correction replaced the attack-move action, exposing a separate prepared-weapon problem: changing a defense goal every 0.75 seconds repeatedly cancelled heavy-weapon preparation. [Both factions dealt zero damage](ai-coordination-charge-before.log) during a six-second interval despite firing successfully beforehand. Updating the existing engaged action’s destination preserves its firing child and preparation. [The same reproduction now deals real damage](ai-coordination-charge-after.log); the [final fire regression](ai-coordination-verified-SkirmishCoordinationFireRegression.log) also checks ordinary-task dispatch, exact goal updates and firing-action identity. Its [original source](ai-coordination-charge-repro.gd.txt) is retained.

## Persistence and targeted verification

Battle snapshots retain task kinds, points, member ids, elapsed commitment age, selector position, retirement state and returning-worker ids. Validation bounds task counts and sizes, checks ownership/roles, prevents duplicate members and rejects future task ages. Old archives without these optional fields remain readable and initialize an empty roster at the next decision. The archive format version stays unchanged.

The [targeted regression](ai-coordination-verified-SkirmishCoordinationRegression.log) covers both factions and all three difficulties, stable repeated decisions, actual disk archives and legacy-field removal/restoration. Additional scenarios exercise two simultaneous raids preempting an assault, hidden-contact release, protected recovery and healthy recommitment. Story rotates an overdue task and waits for a loaded worker to deliver exactly its staged three cargo units before launching the waiting assault. The commitment clock and initial cargo are staged explicitly; return movement, delivery and disk restoration are real.

The live Veteran scenarios run the assigned military for sixty simulation seconds, with a disk restore after ten seconds. Both factions advance an assault over thirty metres, damage an actual enemy, capture both relays and repair a staged wounded tank. Initial health and military positions are staged, opposing units/economic actors are frozen and commander decisions are driven by the harness. These are integration checks, not competitive balance trials.

## Interrupted field work resumes

The shared raid test found a further deadlock: returning engineers delivered their cargo but never restarted the remote field. Completed return actions were excluded from pending expansion demand, and an assault retained all surplus combatants even with another task slot free. The [single-field reproduction](ai-coordination-raid-before.log) consumes no new field stock in 120 seconds after defeating the raider; [the trace source](ai-coordination-raid-repro.gd.txt) is retained. The earlier all-map run hits its inherited cumulative simulation timer before printing every assertion; [that timeout](ai-coordination-raid-timeout-before.log) is retained separately.

Completed returns now participate in expansion demand, while still-travelling returns retain their cargo authority. Assaults retain their three-member core and release surplus reinforcements for other available tasks before reclaiming unused reserves. The [same single-field reproduction after the fix](ai-coordination-raid-after.log) resumes new extraction. The [final two-faction/two-map raid suite](ai-coordination-verified-SkirmishExpansionRaid.log) additionally requires delivered income to exceed **all initial carried cargo plus four electronics**, so returning old cargo cannot masquerade as renewed mining. It also checks worker survival, finite-stock conservation and the global task limit. All four scenarios pass, delivering eight to ten electronics within 38.9–44.0 seconds after the raid starts. Its timeout now uses wall-clock time, avoiding the unrelated cumulative six-hundred-simulation-second timer inherited from campaign tests.

## Shared and rendered verification

All [21 final suite exits](ai-coordination-shared.json) are zero: [coordination](ai-coordination-verified-SkirmishCoordinationRegression.log), [coordination metrics](ai-coordination-verified-SkirmishCoordinationMetricsRegression.log), [prepared fire](ai-coordination-verified-SkirmishCoordinationFireRegression.log), [field raids and resumed income](ai-coordination-verified-SkirmishExpansionRaid.log), [expansion](ai-coordination-verified-SkirmishExpansionRegression.log), [defense](ai-coordination-verified-SkirmishDefenseRegression.log), [offense](ai-coordination-verified-SkirmishOffenseRegression.log), [adaptive labor](ai-coordination-verified-SkirmishLaborRegression.log), [budgets](ai-coordination-verified-SkirmishBudgetRegression.log), [composition](ai-coordination-verified-SkirmishCompositionRegression.log), [support](ai-coordination-verified-SkirmishSupportRegression.log), [recovery](ai-coordination-verified-SkirmishRecoveryRegression.log), [orders](ai-coordination-verified-OrdersRegression.log), [combat](ai-coordination-verified-CombatRegression.log), [snapshot validation](ai-coordination-verified-SaveSnapshotRegression.log), [restoration edges](ai-coordination-verified-SaveRestoreEdges.log), [combat restoration](ai-coordination-verified-SaveRestoreCombat.log), [Alpine](ai-coordination-verified-AlpineRegression.log), [Industrial AI](ai-coordination-verified-IndustrialAIRegression.log), [Coastal AI](ai-coordination-verified-CoastalAIRegression.log), [damage/repair metrics](ai-coordination-verified-SkirmishMatrixMetrics.log).

The [normal-clock rendered run](ai-coordination-render-verified.log) passes at 1280×720 with 150% interface scale. Five staged unarmed human scouts reveal the review areas through ordinary vision. All four final captures were inspected; they show the advance after loading and the captured relay area: [Bastion advance](../../../art/skirmish/ai-coordination-bastion-advance.png), [Bastion relays](../../../art/skirmish/ai-coordination-bastion-capture.png), [Helix advance](../../../art/skirmish/ai-coordination-helix-advance.png), [Helix relays](../../../art/skirmish/ai-coordination-helix-capture.png). No native input or new UI behavior is claimed.

The initial [render fixture](ai-coordination-render-initial.log) incorrectly required every nearby actor to be visible and infantry to remain near a completed objective. Ordinary fog and reassignment violated those expectations. Final assertions require visible local advancing actors and a local captured relay, retaining both earlier outcomes and ordinary fog behavior.

A shared ground-defense check initially measured its wait in render frames and ended before the tanks reached weapon range. The [trace](ai-coordination-defense-trace.log) shows continuous travel and eventual real damage. The check now waits on simulation time with a ten-second limit. The [normal-clock correction](ai-coordination-defense-final.log) passes both factions. Final headless invocations explicitly use `--fixed-fps 60`; earlier non-fixed-clock logs and an interrupted partial match are retained separately and excluded from the final cohort.

## Complete-match observations

An [earlier eight-match cohort](ai-coordination-pre-resumption-matches.json), before the field-resumption correction, completed with four human-policy wins and four losses (4:39.7–18:10.9). Its independent task/order metrics report no violations, yet the separate actual-field raid test still fails. Budget metrics therefore do not establish successful economic resumption. Those records, all eight `ai-coordination-pre-resumption-match-*.log` logs and the [source hashes](ai-coordination-pre-resumption-sha256.json) are retained rather than replaced by the final cohort below.

A subsequent [interim run](ai-coordination-pre-charge-matches.json) retains six completed matches and an [interrupted seventh log](ai-coordination-pre-charge-match-6.log) during dispatch refinement. It was deliberately stopped after the prepared-fire reproduction demonstrated another defect; those outcomes are not substituted for final verification.

The independent coordination probe checks both the roster and actual top-level attack-move destinations every half simulation second: group budget, duplicate/foreign members, unassigned attacks and attacks detached from their assigned task. Field checks allow the twelve-metre resource grouping plus five-metre homeward guard offset; other tasks allow formation/retained-order slack. This does not inspect local firing targets or count individual maintenance jobs as combat missions. The [metric regression](ai-coordination-verified-SkirmishCoordinationMetricsRegression.log) deliberately corrupts a destination, removes a membership and duplicates a group to verify that invalid states are detected.

The [eight final complete records](ai-coordination-matches.json) use Standard difficulty (the matrix labels index 1 as Normal), seed 4110, Standard ground reference play in even cases and Advanced mixed reference play in odd cases. All reach a result. Production and measurement sources remain fixed throughout this final cohort. Across **7,998 half-second samples**, every match reaches at most two task groups, with no duplicate/foreign memberships, unassigned attacks or detached attack destinations detected.

| Human faction | Map | Start / policy | Result | Time | AI waves | Peak tasks | Longest stationary travel, human / AI |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Bastion | Desert | Standard ground | Victory | 9:12.6 | 4 | 2 | 1.5 / 3.0 s |
| Bastion | Desert | Advanced mixed | Defeat | 5:54.0 | 4 | 2 | 1.5 / 1.5 s |
| Bastion | Alpine | Standard ground | Victory | 8:19.9 | 3 | 2 | 2.0 / 1.5 s |
| Bastion | Alpine | Advanced mixed | Victory | 13:34.3 | 9 | 2 | 1.5 / 1.5 s |
| Helix | Desert | Standard ground | Victory | 9:55.4 | 5 | 2 | 4.0 / 1.5 s |
| Helix | Desert | Advanced mixed | Defeat | 5:14.4 | 3 | 2 | 4.5 / 1.5 s |
| Helix | Alpine | Standard ground | Victory | 9:46.7 | 4 | 2 | 4.5 / 2.5 s |
| Helix | Alpine | Advanced mixed | Defeat | 4:41.4 | 3 | 2 | 16.5 / 1.5 s |

Raw logs: [0](ai-coordination-match-0.log), [1](ai-coordination-match-1.log), [2](ai-coordination-match-2.log), [3](ai-coordination-match-3.log), [4](ai-coordination-match-4.log), [5](ai-coordination-match-5.log), [6](ai-coordination-match-6.log), [7](ai-coordination-match-7.log).

The reference human policy wins five of eight matches: four Standard wins and one Advanced mixed win. The AI records 78 recovery episodes, with 34 completed returns and 44 losses. Per-minute task samples include assaults, defense and reconnaissance; short-lived guard/capture activity is not established by that coarse trace. Actual field resumption and relay capture are established by the targeted tests above. Navigation/combat scheduling varies even with a reused seed, so these outcomes do not isolate the coordinator’s effect on win rate. Durations of **4:41.4–13:34.3** remain below the ordinary 20–30-minute pacing hypothesis.

## Captured movement episode: still unresolved

Case 7 records a **16.5-second human Helix engineer stall** at the Alpine home materials field. The [first-failure archive](ai-coordination-stall.json) captures exact `unit-0` at simulation time 239.233 seconds, position `(17.255, 0, 33.507)`, trying to approach a materials work slot. The human HQ is already absent, and nearby workers are waiting without a drop-off. The original trace has a current navigation path, nonzero requested velocity and almost-zero avoidance output. This is an ordinary human harvest action, not an AI strategic task or military recovery.

A bounded fifteen-second [crowded replay](ai-coordination-stall-replay-crowded.log) moves only 0.024 m overall and changes to “No drop-off” by the ten-second sample. An [isolated replay](ai-coordination-stall-replay-isolated.log), with other mobile units removed, moves 0.112 m and reaches that waiting state by five seconds. These observations preserve a real failing scene and suggest nearby traffic affects the delay; they do not establish the complete cause or prove equivalence to the earlier Desert engineer / Alpine AI-tank episodes. Both replays exit successfully as observations, not as movement-progress acceptance. Production movement is unchanged.

## Limits and reproduction

Ordinary 20–30-minute pacing, sustained contested mixed-force play, novice/content/release acceptance and the earlier movement delays remain open, with the newly captured engineer scene available for direct investigation. Performance optimization remains deferred. Future match probes continue to capture the first fifteen-second stationary episode for exact replay.

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishCoordinationRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishCoordinationMetricsRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishCoordinationFireRegression.gd
godot --path . --script tests/rendered/SkirmishCoordinationPreview.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/BaseAccessMatches.gd -- --case=0 --repeats=1 --output=res://tmp/coordination-standard.json --archive=res://tmp/coordination-standard-stall.json
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishMixedPolicy.gd -- --case=3 --repeats=1 --output=res://tmp/coordination-mixed.json --archive=res://tmp/coordination-mixed-stall.json
```

The [editor import](ai-coordination-editor-final.log), [format check](ai-coordination-gdformat-verified.log) and [lint](ai-coordination-gdlint-verified.log) pass. The [22-file source manifest](ai-coordination-source-sha256.json) records the final production, persistence, measurement and verification sources. Final successful logs contain no script/assertion failures; existing navigation-bake and shutdown RID/ObjectDB/resource warnings remain.

Exact captured-scene replay:

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishTravelReplay.gd -- --archive=res://docs/playtests/2026-10-04/ai-coordination-stall.json --unit=unit-0 --seconds=15 --full
```
