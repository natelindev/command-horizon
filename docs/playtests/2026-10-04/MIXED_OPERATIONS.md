# Reference commander continuity and mixed-force operations

This study improves the playtest commander used to assess the game. It does not change shipping unit statistics, resource rules or skirmish AI. The earlier readiness study found healthy ground forces waiting for a home attack before they would launch. We now separate that policy choice from continuity, staging, early air investment and guard coverage.

## Reproduced commander defect

After reaching an attack-move destination, tanks and infantry install their normal idle-defense action. The reference commander only continued units whose action was null. It therefore left new reinforcements and completed waypoint units behind. This invalidated the first staging experiment as evidence for a competent advancing force.

[The original focused regression](mixed-operations-advance-before.log) reports sixteen failures across both factions. The correction recognizes an idle-defense action only when it is not firing. [The final regression](mixed-operations-advance-final.log) verifies both new units joining an assault and actual travel through two successive destinations; active defensive fire retains its action. [The shared recovery regression](mixed-operations-PolicyRecoveryRegression.log) still verifies that wounded infantry and machinery use matching service facilities and rejoin the advance.

The default historical policy still requires a home attack before assault. Two override hooks allow explicit operation experiments without fabricating an observed attack or changing the existing default. The corrected idle-action handling is shared by all subsequent policy runs.

## Controlled policy variations

All trials use Advanced Desert Frontier starts, Normal skirmish AI, ordinary resource payments and existing combat/program rules. They test a scripted commander, not novice play. Bastion faces Helix and Helix faces Bastion. Seeded starts are recorded; asynchronous navigation and combat still vary between runs with the same seed.

- **Proactive:** remove only the prior-home-attack requirement. Keep nine deployed ground fighters, 80% mean health, no visible home threat and twenty seconds since economic pressure as assault gates. The existing ground-first allocation allows air investment once deployed/queued ground inventory reaches nine.
- **Staged:** add route waypoints about twelve metres apart. Advance when 75% of available attackers are within six metres, or after a twelve-second maximum wait. Retreating units do not count toward the waiting group. This is commander-issued movement, not a new unit ability or rigid formation.
- **Later air investment:** retain staged operations but raise the deployed/queued ground inventory gate for air investment from nine to twelve. Assault readiness remains nine; no unit receives free resources, health or damage. This tests the timing of airfield/aircraft spending, not a price change.
- **Responsive guards:** retain that allocation and explicitly reassign running programmed guards toward currently observed threats to the economy. The commander uses the shared legal-threat assessment, preserves retreat/manual authority, and returns to the original guard point when those threats clear. Guard programs still operate within their existing assigned area; they do not independently select strategic objectives.

The underlying commander uses real production, built-in/manual movement and authored guard programs. The production probe records paid/refused/unaffordable/reserved decisions. Every match records force readiness, phase changes and positions, casualty timelines, economy, repair, coordination and stationary travel.

## Evidence and scope

The four initial diagnostic runs precede the continuity correction and are retained separately. The later operation and allocation records use the corrected commander. The readiness and staging changes are hypotheses rather than shipping balance decisions. A larger air-investment gate produced isolated victories but did not reliably solve the match; early wins must not be interpreted as acceptance.

The corrected-policy trials before the arrival fix produced these results:

| Policy | Bastion | Helix |
| --- | --- | --- |
| Proactive, air gate 9 | Defeat 4:52.5 | Defeat 4:50.9 |
| Staged, air gate 9 | Defeat 5:11.8 | Defeat 4:48.0 |
| Staged, air gate 12 — first run | Victory 6:47.6 | Defeat 5:06.9 |
| Staged, air gate 12 — repeated seed 4110 | Defeat 5:51.9 | Defeat 4:56.1 |
| Staged, air gate 12 — seed 4111 | Defeat 6:13.8 | Victory 6:25.2 |
| Responsive guards, air gate 12 | Victory 15:00.3 | Victory 8:32.0 |

The larger air-investment gate wins only one of three trials per faction. This does not justify adopting a particular threshold or changing unit prices. In the responsive trials, Bastion launches a second assault after recovery and eventually produces two strike aircraft; Helix launches three assaults without aircraft. These are viable scripted lines through one Advanced map, not proof of balanced factions or ordinary/novice pacing.

The long Bastion trial captured a seventeen-second infantry stall at an occupied barracks approach. The exact archive now drives the [crowded Move destination correction](CROWDED_DESTINATION.md), with a reproduced before-failure, bounded arrival, queued disk restoration and rendered treatment checks. The initial sixteen full matches precede that shipping correction. Two further responsive matches on the corrected runtime are recorded separately in the arrival-check ledger; results are not pooled across revisions.

[The eighteen-match manifest](mixed-operations-cohort.json) records each terminal result, seed, phase count, stationary travel, coordination sample count and source/log hash. The two final trials after the arrival fix both finish in victory: Bastion at 13:04.6 with three assaults, Helix at 6:38.0 with two. Their longest sampled stationary-travel episodes are 2.0 / 2.5 seconds respectively. These two outcomes do not prove that all congestion or balance issues are solved.

One earlier Bastion allocation trial at seed 4111 records a tank entering the designed **Blocked** state after five seconds without progress, at 2:43.75. [Its separate archive](mixed-operations-allocation-repeat-bastion-stall.json), entity `unit-23`, and the reason are retained. This is not a script crash, and it is not counted as a clean program route; the reference commander did not reassign or resume it. That route/commander case remains a separate follow-up. The final two trials contain no authored-blocked entries.

[The accepted verification manifest](crowded-destination-verification.json) covers the runtime correction, reference-policy regressions, rendered replay and final full matches. Source/capture hashes and known engine exit warnings are retained. The audit script is available as [audit source](mixed-operations-audit.py.txt).

## Reproduction

The exact temporary wrappers are retained as `mixed-operations-<Name>.gd.txt` beside this report. Copy them to their original `tmp/<Name>.gd` locations to reconstruct the chain; the shared corrected policy and focused regression live under `tests/headless`.

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/PolicyAdvanceRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/PolicyRecoveryRegression.gd
godot --headless --path . --fixed-fps 60 --script tmp/MixedOperationsMatches.gd -- --case=5 --repeats=1 --ground-first --proactive --output=res://tmp/operations.json
godot --headless --path . --fixed-fps 60 --script tmp/MixedResponsiveMatches.gd -- --case=1 --repeats=1 --ground-first --proactive --output=res://tmp/responsive.json
```

Case 1 is Bastion Advanced Desert and case 5 is Helix Advanced Desert. The local engine is Godot 4.6 on the development M1 Pro. This pass does not establish native-device/visual acceptance, other maps/difficulties, Standard openings, faction balance or novice pacing. The wider 20–30-minute ordinary-match hypothesis remains open. Performance optimization remains deferred.


## Follow-up: retained Blocked tank

[Exact replay](BLOCKED_ASSIGNMENTS.md) now identifies the retained authored Blocked case as an assignment inside a friendly aircraft factory. Resume reaches the navigation edge and correctly blocks again; a clear reassignment recovers. Specific feedback and paused guard-boundary persistence are now verified. This follow-up does not alter the cohort's outcomes or erase its recorded Blocked event.
