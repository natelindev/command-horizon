# Industrial and Coastal contested matches

Both factions now have complete contested-match observations on Industrial Crossroads and Coastal Foundry with Standard and Advanced starts. This study also corrects the **reference playtest commander**: it no longer sends wounded vehicles to an HQ center when no matching repair facility exists, and can explicitly reassign a retreat point that later becomes occupied. Shipping combat, economy, navigation, programs and map content are unchanged.

## Reproduced command errors

The original Coastal Standard archives retain a Bastion walker and Helix tank trying to retreat into their own HQ. Their authored program correctly reports an inaccessible assignment. The HQ is not a repair provider. [The original regression](regional-fallback-before.log) fails six checks across those exact captures. The corrected policy chooses a reachable point near the HQ, outside living owned footprints and current friendly mobile occupancy. It keeps that point stable while approaching, invalidates it if a new owned structure occupies it, and prefers a matching completed facility when available. With no facility, arrival grants no healing, health, resources or production.

The first full rerun exposed a second case: a repair robot later occupied the selected waiting point. [The retained archive](regional-final-case-0-stall.json), entity `unit-12`, contains the blocked walker and the repair robot at its destination. [The diagnostic regression](regional-occupied-fallback-before.log) fails to reassign and resume. The final commander checks mobile occupancy again after Blocked, chooses another clear point, and explicitly resumes only after changing the safe assignment. This is a commander decision; automatic retry was not added to player programs. The original no-progress and manual-authority rules remain intact.

[The final fallback regression](regional-reviewed-PolicyFallbackRegression.log) covers both original faction archives, actual arrival, conserved HP/resources, stable points, new construction, matching providers and the captured occupied-point reassignment while paused. [Existing recovery](regional-reviewed-PolicyRecoveryRegression.log) and [advance](regional-reviewed-PolicyAdvanceRegression.log) regressions retain matched infantry/vehicle service and onward assault behavior.

## Complete outcomes

All trials use Normal AI, seed 4110, ordinary paid harvesting/building/production and the same responsive mixed-force commander. It uses a nine-member/80%-health assault gate, a twelve-ground-unit air-investment gate, bounded route stages, and shipped authored Guard/retreat behavior. Initial and corrected revisions are kept separate. Navigation and combat scheduling remain nondeterministic; repeated seed values do not make policy changes a paired causal experiment.

| Faction | Map | Start | Original | Clear fallback | Reassignment |
| --- | --- | --- | --- | --- | --- |
| Bastion | Industrial Crossroads | Standard | Victory 12:04.2 | Victory 21:03.2 | Defeat 9:42.9 |
| Bastion | Industrial Crossroads | Advanced | Victory 6:04.6 | Victory 17:02.1 | Defeat 10:57.7 |
| Bastion | Coastal Foundry | Standard | Defeat 19:14.1 | Defeat 5:14.1 | Defeat 7:51.3 |
| Bastion | Coastal Foundry | Advanced | Defeat 7:51.4 | Victory 8:41.8 | Victory 12:52.2 |
| Helix | Industrial Crossroads | Standard | Defeat 4:52.0 | Defeat 8:46.3 | Defeat 8:55.2 |
| Helix | Industrial Crossroads | Advanced | Defeat 6:35.8 | Victory 11:58.8 | Victory 8:42.7 |
| Helix | Coastal Foundry | Standard | Defeat 6:01.0 | Defeat 7:24.7 | Defeat 5:47.9 |
| Helix | Coastal Foundry | Advanced | Defeat 5:16.2 | Victory 7:44.5 | Defeat 5:34.7 |

The [24-match cohort](regional-cohort.json) links every complete log/record and its source fingerprint. It retains losses, program Blocked events and sampled stationary movement; reaching a result is not a balance or congestion pass. Full records also contain minute-by-minute economy/force samples, casualties, repair, production decisions, operation transitions and AI task observations.

## Final-revision observations

| Case | Contact | Basic unlock | Expansion cargo returned | Longest stationary travel, human / AI | Authored Blocked events |
| --- | --- | --- | --- | --- | --- |
| 0 | 2:19.7 | 2:07.2 | 6:48.7 | 3.5 / 2.0 s | 0 |
| 1 | 1:58.2 | 0:00.7 | 6:42.7 | 5.0 / 3.5 s | 0 |
| 2 | 2:25.2 | 2:14.7 | — | 3.5 / 1.5 s | 0 |
| 3 | 2:09.2 | 0:00.7 | 8:09.2 | 5.0 / 2.0 s | 2 |
| 4 | 2:23.2 | 2:00.2 | 6:36.7 | 1.5 / 1.5 s | 0 |
| 5 | 2:02.2 | 0:00.7 | 6:36.2 | 9.5 / 4.0 s | 0 |
| 6 | 2:26.2 | 2:54.2 | — | 4.5 / 1.5 s | 0 |
| 7 | 1:59.2 | 0:00.7 | — | 1.5 / 1.5 s | 0 |

Across the final revision, the AI coordinator records 8,448 samples; violations: 0. Advanced basic unlock is already available at startup. Missing expansion returns mean the policy did not complete that trip before the result, not that map access passed or failed.

## Remaining limits

Follow-up: [guard-arrival evidence](GUARD_ARRIVAL.md) captures and corrects occupied-center crowd arrival, while retaining a new corner blockage and an AI coordination failure. It does not retroactively establish the cause of the two older post-block snapshots below.

The original Advanced Coastal Bastion tank (`regional-case-3-stall.json`, `unit-12`) blocked near its initial guard assignment at 46.7 seconds. [Exact post-block replay](regional-blocked-replay.log) reaches the guard point after Resume, while a [fresh 65-second opening probe](regional-opening-probe.log) does not reproduce the original stop. Its transient cause remains unproven. The later occupied-retreat correction does not establish that this guard case is fixed.

The final Advanced Coastal Bastion archive (`regional-reviewed-case-3-stall.json`, `unit-14`) records a different tank blocked during Guard at 399.2 seconds, with its authored retreat state false. [Its post-block replay](regional-reviewed-guard-replay.log) reaches the guard point within ten simulation seconds after Resume, then continues under crowd movement. The original transient stop remains unexplained and is retained for follow-up. This is separate from the verified occupied retreat-point defect.

The final Helix Advanced Industrial match also samples a 9.5-second stationary-travel episode. The automatic full-state trigger is fifteen seconds, so this shorter episode has metrics but no dedicated stall capture; its cause is not diagnosed here. The final cohort has two victories and six defeats and runs from 5:34.7 to 12:52.2, below the ordinary 20–30-minute hypothesis.

These are controlled headless matches with a scripted commander, not novice or physical-input sessions, a normal-clock performance test, or balanced faction acceptance. One seed per revision/combination does not supply three repeated trials on an identical final policy. Short matches and early unlocks remain pacing evidence, not grounds for an artificial delay. Five first-time players, broader strategies/difficulties and the release/performance gate remain open; performance work stays deferred.

## Reproduction and integrity

The permanent matrix now has an overridable map selector; its Desert/Alpine default is unchanged. `regional-*.gd.txt` retains the temporary responsive-policy chain. Copy those files to their named `tmp/*.gd` locations and use [the reviewed runner](regional-reviewed-runner.py.txt), or run one case:

```sh
godot --headless --path . --fixed-fps 60 --script tmp/RegionalSkirmishMatches.gd -- --case=2 --repeats=1 --ground-first --proactive --output=res://tmp/regional.json
```

Cases 0–3 are Bastion and 4–7 Helix; within each faction, Industrial Standard/Advanced precede Coastal Standard/Advanced. The existing policy offsets repetition by ten, yielding seed 4110. The engine is Godot 4.6 on the development Mac. Source snapshots retain the original and intermediate policy bytes, so changed commander results are not pooled as one revision.

The first replay probe had a missing cleanup-method parse error; that log is retained as a diagnostic and excluded from checks. An early occupied-point candidate also expected immediate Running during tactical pause; the final regression correctly allows Ready until the next simulation tick, and verifies that no movement occurs while paused. Known navigation mesh-readback and engine-exit leak warnings remain in logs. [The audit](regional-audit.py.txt) rejects script/load errors and missing success markers, checks every result and source hash, and verifies the report links.
