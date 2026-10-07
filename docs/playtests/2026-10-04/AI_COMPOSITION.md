# Observed-composition AI production — 2026-10-04

Skirmish AI now uses currently observed armed opposition to choose faction-appropriate production and to bring forward air-defense construction. The [before-change reproduction](ai-composition-before.log) fails six checks across the two factions: a visible aircraft does not bring forward AA construction or a mobile counter, and worker production incorrectly advances the vehicle roster.

## Behavior

The planner counts completed units and every paid production job, including jobs awaiting a free deployment position. Successful reservations update the count before another producer chooses a job. Workers target six, normal infantry target six, and the first aircraft slot supplies a scout. Only successful vehicle-factory jobs advance the existing saved roster index. Tank chip-fitting charges are included when checking the construction reserve.

Current armed air contacts request up to four walkers. Helix also requests Lancers against heavy armor and increases its infantry screen against infantry; Bastion requests autocannon walkers against infantry and heavy tanks against armor when Coordination is available. Combined reactive walker demand is capped at four. A machinery force of at least three requests repair support, increasing to at most four repair robots. Baseline roster slots also respect owned/queued composition, so an already-reserved counter does not cause a duplicate simply because the next roster slot has the same role. These quotas are initial tuning values, not established balance targets.

Observed aircraft can bring forward the first AA turret after HQ, power and basic production needs. Existing foundation/engineer limits, site access, costs and prerequisites still apply. Hidden units and unarmed scouts do not influence counter decisions. Visibility is evaluated at the decision tick; there is no persistent hidden composition memory. Unit HP, damage, movement speeds, prices, AI reaction delays and attack-wave intervals are unchanged.

## Mechanics and visual verification

The [composition regression](ai-composition-SkirmishCompositionRegression.log) passes for both factions:

- Hidden/unarmed contacts, faction armor/infantry responses, repair support and incomplete technology.
- Multiple factories, existing paid jobs, exact spending/refunds, repeated busy decisions and reserve boundaries, including tank chip-fitting cost.
- Unaffordable AA rejection followed by paid placement and actual engineer construction.
- A partially completed counter job saved to disk while paused, preserving funds, production sequence, remaining time and simulation clock.
- Exactly one paid counter spawning after restoration, then travelling to intercept and damage an aircraft through ordinary combat, including the Helix mode switch.

Staged stationary contacts isolate mechanics. They do not establish contested-fight balance. [Normal-clock rendered verification](ai-composition-rendered.log) repeats the flow at 1280×720 and 150% UI scale. A staged human scout reveals the newly produced enemy counter; selection uses the game API. Both captures were visually reviewed, with visible units, readable controls and a frozen clock during the capture. This is rendered review, not a physical-input acceptance claim.

![Helix counter after production and archive](../../../art/skirmish/ai-composition-helix-counter.png)

![Bastion counter after production and archive](../../../art/skirmish/ai-composition-bastion-counter.png)

Shared [observed-threat defense](ai-composition-SkirmishDefenseRegression.log), [repair support](ai-composition-SkirmishSupportRegression.log), [weapon modes](ai-composition-WeaponModeRegression.log), [save/load](ai-composition-SaveRestoreRegression.log), [Air Corridor](ai-composition-AirCorridorRegression.log), [Industrial AI](ai-composition-IndustrialAIRegression.log) and [Coastal AI](ai-composition-CoastalAIRegression.log) checks pass. Editor import, changed-file format/lint and whitespace checks pass. Existing navigation/rendering and resource-cleanup warnings remain; retained successful runs contain no gameplay script errors.

## Full-match methodology and diagnostic correction

Standard starts use the existing early-commitment ground commander. Advanced starts use a new paid mixed-force reference policy: a ground Guard/repair screen, scout reconnaissance, up to two strike-return aircraft, ground production and the existing expansion/regroup logic. Air raids select only currently observed economic targets and use the ordinary hangar retreat/service contract. This policy is test automation, not a new player-facing autonomous strategist. The AI pays its own production/construction costs and obtains contacts through normal observation.

The [two initial mixed trials](ai-composition-initial-matches.json) both end in defeat, at 12:37.5 and 8:03.4. In each, the AI starts AA construction with an armed aircraft currently observed, at 175.9 and 192.6 seconds respectively. The [four additional diagnostic outcomes](ai-composition-diagnostic-matches.json) retain one victory and three defeats.

Those early cohorts include invalid stationary-air measurements. The mixed commander repeatedly ordered an idle scout to the point it had already reached, and the monitor counted altitude above the ground-click destination as remaining travel. An isolated test confirms that the existing movement code completes the original flight, a flight restored from a paused disk archive, and queued flights for Drone/Helicopter on Desert, Alpine and Industrial maps. [The final air-arrival regression](ai-composition-air-arrival.log) passes without changing production movement code. The commander now leaves arrived scouts idle, and the monitor measures air destinations horizontally. Earlier stationary-air values must not be compared with final ones.

A test-startup dependency mistake was also caught by checking logs and output records; zero-record executions were rejected. The matrix now explicitly fails when expected result records are missing. Those executions are not matches and are excluded from all outcome counts.

## Final complete-match results

The [final eight outcomes](ai-composition-final-matches.json), on the [recorded source](ai-composition-build.json), all reach ordinary victory/defeat: three wins and five losses. The Standard ground policy wins three of four; this mixed-force policy loses all four. Combined with the retained six initial/diagnostic outcomes, fourteen complete matches are recorded. A shared seed does not eliminate asynchronous navigation/avoidance variation, and the cohorts differ in policy/test instrumentation; these are exploratory strategy observations, not a controlled balance comparison.

| Human / map | Start and policy | Outcome / duration | Human aircraft produced | AI waves | Longest stationary travel, human / AI (s) |
|---|---|---|---|---|---|
| Bastion / Desert | Standard ground | L · 10:43.6 | — | 8 | 1.0 / 2.0 |
| Bastion / Desert | Advanced mixed | L · 16:45.3 | 4 | 14 | 1.5 / 3.5 |
| Bastion / Alpine | Standard ground | W · 9:27.8 | — | 5 | 3.0 / 1.5 |
| Bastion / Alpine | Advanced mixed | L · 11:27.8 | 2 | 9 | 1.5 / 37.0 |
| Helix / Desert | Standard ground | W · 9:05.1 | — | 4 | 9.0 / 1.5 |
| Helix / Desert | Advanced mixed | L · 9:01.9 | 3 | 7 | 6.0 / 42.5 |
| Helix / Alpine | Standard ground | W · 9:22.9 | — | 4 | 5.0 / 1.0 |
| Helix / Alpine | Advanced mixed | L · 9:19.2 | 3 | 7 | 1.5 / 15.5 |

All four final mixed runs place their first AA foundation while an armed aircraft is currently observed, before the previous 220-second timing gate. Specialist-order events retain the AI's current visible composition at reservation time. Aircraft production totals include replacements; the policy targets at most two concurrent strike aircraft plus one scout. Detailed samples retain economy allocation, spending, repairs, losses and expansion returns.

The final mixed runs also expose real ground issues. The [Alpine ground archive](ai-composition-alpine-ground-stall.json) and [Desert ground archive](ai-composition-desert-ground-stall.json) retain AI infantry/tanks ordered toward the visible scout above their own buildings, with 37/42.5-second maximum stationary episodes. Offensive target selection currently accepts the first visible non-defense contact without filtering the army's target domains. This merits a separate objective-selection fix and replay; the captures do not establish that objective selection is the only contributor to local avoidance. An [Alpine engineer archive](ai-composition-alpine-worker-stall.json) preserves a separate materials-approach delay. These findings are not hidden by the corrected aircraft metric.

Final durations remain below the ordinary 20–30-minute pacing hypothesis. Counter-production is verified, while mixed-strategy strength, domain-appropriate offensive targets, protected expansion and broader coordination remain follow-up work. Content/novice/release gates remain open; performance work stays deferred.


## Reproduction

Run from the project root with Godot 4.6:

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishCompositionRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/AirArrivalRegression.gd
godot --path . --rendering-method mobile --script tests/rendered/SkirmishCompositionPreview.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishMixedPolicy.gd -- --case=1 --repeats=1 --output=res://tmp/composition-match.json
```

Odd cases 1/3/5/7 cover Advanced Bastion Desert/Alpine and Helix Desert/Alpine. Even cases use `BaseAccessMatches.gd` for the corresponding Standard-start ground policy. The retained final cohort uses seed 4110, Normal AI and one run per case. Source fingerprints are in [the build record](ai-composition-build.json).
