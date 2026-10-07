# AI regrouping handoff and corner-traffic diagnosis

An AI defender already at its regroup point now retires an obsolete attack-move when its former task ends. Previously, a stopped movement agent could retain that attack route after the coordinator removed the unit's group. This left an attack order with no task membership and could resume the old destination after an engagement.

Only `SkirmishCoordination.gd` changes shipping behavior. The correction checks the existing action as well as the movement destination when a unit has arrived. Distant units still receive the ordinary move home; repeated valid approaches and idle stances are preserved. Units assigned to an active task retain their attack-move. Recovery eligibility, task budgets, strategic choices and prepared-fire retargeting keep their existing contracts.

## Reproduction and verification

[The original focused probe](coordination-arrival-probe-before.log) fails for both factions. It places an expiring defender within 0.5 m of its regroup point, with its old attack-move stopped, and runs the normal coordinator with no remaining threat. The old code produces zero groups while retaining `AttackMoving`; the metrics correctly report `unassigned_attack_order`. [The corrected probe](coordination-arrival-probe-after.log) leaves the unit in its ordinary idle stance with no membership violation.

[The permanent regression](coordination-handoff-verified.log) passes both factions at all three difficulties. It covers stopped and still-active old routes near the regroup point, distant travel home, repeated-command stability, active mission ownership, paused disk restoration and three seconds of resumed play without returning to the old route. [Nine shared suites](coordination-handoff-checks.json) pass: coordination, prepared fire, coordination metrics, defense, recovery, offense, support, combat restoration and orders.

[Normal-clock rendered verification](coordination-handoff-rendered.log) passes for both factions at 1280×720 / 150% UI scale. The restored defenders remain near home after task retirement; current allied drone vision exposes the enemy formations. Both [Bastion](../../../art/skirmish/coordination-handoff-bastion.png) and [Helix](../../../art/skirmish/coordination-handoff-helix.png) captures were reviewed. There are no UI changes in this pass. Import, formatting, lint and whitespace checks pass.

The earlier match's three membership violations remain a separately observed condition. Six instrumented original-runtime repeats did not reproduce them, so there is no actor-level capture linking that particular match to this handoff defect. The focused failing scenario and source branch establish the correction; the old match is not retrospectively declared explained.

## Complete-match evidence

Six original-runtime Bastion repeats and four corrected-runtime trials (two per faction) finish on Coastal Foundry Advanced against Normal AI. The unchanged regional reference commander uses paid economy/production, authored guard/recovery and seed 4110. The six earlier repeats all lack the original membership violation; results therefore cannot establish a match-level causal improvement. Scheduling is nondeterministic, and the two cohorts have different faction coverage.

| Runtime / run | Faction | Outcome / duration | Longest stationary travel, human / AI | Coordination samples / violations | Evidence |
| --- | --- | --- | --- | --- | --- |
| Before 0 | Bastion | Defeat 6:32.3 | 2.5 / 3.0 s | 785 / 0 | [record](coordination-handoff-match-0.json) |
| Before 1 | Bastion | Defeat 5:22.0 | 1.5 / 6.5 s | 644 / 0 | [record](coordination-handoff-match-1.json) |
| Before 2 | Bastion | Defeat 7:50.0 | 2.0 / 6.5 s | 940 / 0 | [record](coordination-handoff-match-2.json) |
| Before 3 | Bastion | Defeat 7:33.9 | 28.0 / 7.5 s | 908 / 0 | [record](coordination-handoff-match-3.json) |
| Before 4 | Bastion | Defeat 12:15.1 | 2.5 / 2.0 s | 1470 / 0 | [record](coordination-handoff-match-4.json) |
| Before 5 | Bastion | Victory 16:09.2 | 17.5 / 2.5 s | 1938 / 0 | [record](coordination-handoff-match-5.json) |
| After 0 | Bastion | Defeat 7:44.1 | 3.5 / 1.5 s | 928 / 0 | [record](coordination-handoff-final-match-0.json) |
| After 1 | Bastion | Victory 14:54.8 | 3.0 / 2.5 s | 1790 / 0 | [record](coordination-handoff-final-match-1.json) |
| After 2 | Helix | Victory 12:44.7 | 8.0 / 1.5 s | 1529 / 0 | [record](coordination-handoff-final-match-2.json) |
| After 3 | Helix | Defeat 6:49.3 | 4.0 / 1.5 s | 819 / 0 | [record](coordination-handoff-final-match-3.json) |

The corrected cohort contains 5,066 coordination samples with zero violations; the original-repeat cohort contains 6,685 with zero violations too. Longer stationary episodes (28.0 and 17.5 seconds in the original repeats) remain recorded in the travel logs. This probe prioritized AI membership captures; its optional travel-archive argument was not supplied, so those episodes have diagnostic samples but no full-state archive. They are unresolved navigation evidence, not passes. The four final records and [execution results](coordination-handoff-final-execution.json) retain every outcome. These controlled headless trials do not establish novice, balance or normal-clock performance acceptance.


The capture probe records the preceding eight seconds of actor, group, action and movement state when a coordination violation occurs. No such captures were triggered in the six original-runtime repeats. Two initial probe processes were terminated after an invalid reference lookup before snapshot initialization; those error logs are excluded. The corrected probe uses runtime IDs and maps them to archive IDs only after capture. The first permanent-test attempts also exposed early preload/autoload and dynamic-type fixture errors; final fixtures load action scripts after startup and use `is_instance_of`. These error logs are retained and are not counted as passes.

## The remaining Coastal corner blockage

The [retained pre-block archive](guard-travel-after-3-0.json), Helix tank `unit-13`, reproduces three times with live traffic and disabled high-level commanders. [The replay](guard-corner-replay-before.log) preserves the existing stall timer: the tank remains near `(21.3, 37.2)`, trying to reach `(18.5, 40)`, then reaches Blocked at about 42.2 seconds. Its route exists; the assigned center is outside the buildings.

Directional diagnostics keep the same scene and ordinary speed/avoidance. Reversing the short sidestep, biasing west/east, or requesting strictly east does not free the tank. Some diagnostic variants reset only the test's stall timer to provide a fresh five-second observation window; they still fail and are not acceptance checks. Initial clearance queries ran before navigation synchronization and are excluded; synchronized queries show the factory/lab clearance constraints.

[Controlled neighbor removal](guard-corner-neighbors.log) narrows the interference: removing the nearby repair robot at `(19.634, 37.719)` lets the focal tank move and remain Running; removing the three nearby infantry alone does not. Removing both, or all nearby mobile neighbors, also releases it. These are counterfactual diagnostics, not a gameplay correction. No actors are removed by shipping code. The original intact scene remains blocked, and collision-aware yielding or another bounded route needs further investigation.

The broader goal remains active: general congestion, ordinary pacing, strategic variety, first-time-player/content/accessibility/platform and release acceptance are not complete. Performance optimization stays deferred.

## Reproduction and integrity

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishHandoffRegression.gd
godot --path . --script tests/rendered/SkirmishHandoffPreview.gd
```

`coordination-handoff-before-source.json` fingerprints the original shipping sources; the three original AI modules are retained as text snapshots. `coordination-handoff-final-source.json` fingerprints final shipping code, the permanent tests and the full reference-policy inheritance chain. Probe, runners and corner diagnostics are retained as `.gd.txt` / `.py.txt` files in this directory. Godot 4.6 ran on the development Mac. Known navigation mesh-readback and engine-exit resource warnings remain in logs; script/load errors are rejected separately. The audit checks source hashes, success markers, every terminal record, artifacts and report links without treating the unresolved corner as a pass.
