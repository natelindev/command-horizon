# Strategic offensive objectives — 2026-10-04

Skirmish attack waves now pressure observed enemy economic targets instead of following the first visible enemy. Two retained mixed-force archives reproduce the original failure: the AI sends its ground tanks to a human scout above its own HQ. [The before-change replay](ai-offense-before.log) fails on both Alpine and Desert. The captured destinations have the scout's aircraft altitude and sit among the AI's buildings, although those tanks cannot attack it.

## Selection contract

The commander still assigns local defense and relay duties first. At the existing attack-wave interval, the remaining force chooses among currently observed, living enemy structures and engineers that it can engage. HQ has first priority, production second, followed by technology, power, repair, other structures and exposed engineers. Equal-priority targets favor the point nearest the wave's center. A Helix Lancer remains eligible for a ground objective while in Interception because its existing mode system can prepare Precision.

Mobile combat units and scouts do not choose the strategic destination. Attack-move still engages legal nearby enemies along the route, and observed raids on the economy still receive suitable defenders. If no economic objective is observed, the wave advances toward the public enemy starting position. Newly chosen destinations use ground-plane coordinates. Hidden movement does not update an existing order; a later wave re-evaluates current observation. Friendly and destroyed targets are rejected.

This changes objective selection, not attack timing, wave-size requirements, defense/relay allocation, weapon damage, costs, unit speeds or save formats. It does not add persistent squads, global task coordination or autonomous economic expansion.

## Archive and mechanics verification

The [final headless regression](ai-offense-regression.log) and [rendered regression](ai-offense-rendered.log) pass. The original Alpine and Desert archives are reused directly. Their observed scout remains present, but the new wave orders point toward the enemy base. All four Alpine and six Desert tanks travel more than eight metres within thirty simulated seconds, including a midpoint paused disk archive and restoration. Position, destination and wave age survive the pause/load. [Four additional Desert replays](ai-offense-repeated-departures.log) also pass; their [small driver](ai-offense-departure-repeat.gd) is retained. The opposing units are held stationary to isolate the departure; friendly harvesting, support and production traffic remain active.

An initial fixture froze every non-tested unit and blocked some departures with stationary base traffic. Restoring ordinary friendly traffic makes every tested departure complete the distance check. This correction belongs to the test setup; it is not evidence of a new movement implementation. Production movement code is unchanged.

Further repeats exposed a separate weakness in the first test deadline: a tank could still be routing through the base after fifteen seconds. The [retained continuous trace](ai-offense-slow-exit.log) and [mid-delay archive](ai-offense-slow-exit.json) show one such tank progressing about 42 m by thirty seconds without replacement orders, a reload or position changes. The final departure check therefore uses a thirty-second bound. A [second delayed exit](ai-offense-slow-exit-stress.json) is also retained. These diagnostics preserve the slower cases rather than selecting only fast runs.

A sampled empty agent path is not sufficient evidence of a disconnected route: the server returned a connected path, and [Godot 4.6 clears the stored result when requesting a repath](https://github.com/godotengine/godot/blob/4.6-stable/scene/3d/navigation/navigation_agent_3d.cpp#L820). No engine or movement workaround was introduced for this transient observation.

The separate [delayed-engineer archive](ai-composition-alpine-worker-stall.json) is replayed with AI scheduling active. The tracked engineer resumes its existing materials order, collects and delivers within sixty seconds, and respects its movement-speed bound. This proves liveness in that replay, not universal pathfinding reliability or a separate engineer-navigation fix.

Both-faction fixtures also verify economic priority independent of contact enumeration, HQ/production/infrastructure/engineer choices, hidden contacts, own structures, destroyed HQs, unarmed forces, mode-switching eligibility, unchanged funds, wave intervals and last-observed destinations. The next scheduled wave returns to the public base objective when the economy has gone out of sight.

Shared defense tests retain independent offensive/relay orders while local troops respond to raids. Their staged enemy economy is close to one staged raid, so the separation assertion now distinguishes the raid point plus formation offsets from a valid nearby economic goal, rather than rejecting every goal within twelve metres of the raid. The original whole-army diversion would still fail that check.

Shared [defense](ai-offense-SkirmishDefenseRegression.log), [composition production](ai-offense-SkirmishCompositionRegression.log), [repair support](ai-offense-SkirmishSupportRegression.log), [weapon modes](ai-offense-WeaponModeRegression.log), [save/load](ai-offense-SaveRestoreRegression.log), [Desert AI](ai-offense-FrontierAIRegression.log), [Industrial AI](ai-offense-IndustrialAIRegression.log) and [Coastal AI](ai-offense-CoastalAIRegression.log) checks pass. Editor import, changed-file formatting/lint and whitespace checks pass. Existing rendering/navigation and shutdown-resource warnings remain; retained successful runs contain no gameplay script errors.

## Rendered review

Both departing formations are reviewed at normal simulation time, 1280×720 and 150% UI scale. A human scout is staged nearby after the movement assertions to reveal the army through ordinary fog; the army's positions and orders are unchanged for the capture. Selection uses the game API. Tactical pause is controlled through the HUD, and the simulation clock stays fixed during each screenshot. These are rendered mechanics/layout checks, not physical-input acceptance.

![Helix force departing on Alpine](../../../art/skirmish/ai-offense-alpine-departure.png)

![Bastion force departing on Desert](../../../art/skirmish/ai-offense-desert-departure.png)

## Complete-match evidence

The [eight complete outcomes](ai-offense-matches.json) all reach ordinary victory or defeat: four wins and four losses. Standard starts use the retained ground policy; Advanced starts use the retained paid mixed-force policy. Both use Normal AI, seed 4110 and the [recorded source](ai-offense-build.json).

| Human / map | Start and policy | Outcome / duration | AI waves | Longest stationary travel, human / AI (s) | Outer cargo return |
|---|---|---|---|---|---|
| Bastion / Desert | Standard ground | W · 8:56.1 | 4 | 1.5 / 1.5 | 6:50.7 |
| Bastion / Desert | Advanced mixed | L · 8:55.0 | 7 | 2.0 / 2.0 | 6:35.2 |
| Bastion / Alpine | Standard ground | W · 8:11.1 | 3 | 6.0 / 1.0 | 6:41.2 |
| Bastion / Alpine | Advanced mixed | L · 8:41.9 | 7 | 2.0 / 1.5 | 6:39.2 |
| Helix / Desert | Standard ground | L · 16:42.2 | 11 | 7.0 / 1.5 | 6:31.7 |
| Helix / Desert | Advanced mixed | L · 5:17.2 | 4 | 2.0 / 1.0 | — |
| Helix / Alpine | Standard ground | W · 9:26.5 | 5 | 7.0 / 1.5 | 6:34.7 |
| Helix / Alpine | Advanced mixed | W · 17:30.9 | 9 | 1.5 / 1.5 | 6:42.2 |

No final match records a stationary-travel episode of fifteen seconds or longer. The maximum is seven seconds for the human side and two seconds for the AI. The previous mixed cohort retained 37/42.5-second ground-wave stalls and a 15.5-second engineer delay. Those archives remain available; this result does not prove every crowd or navigation configuration is safe.

The mixed policy now wins Helix/Alpine and loses the other three cases, versus four defeats in the previous cohort. Identical seeds do not make asynchronous navigation/combat deterministic, so this is not a controlled win-rate or balance result. Match durations range from 5:17.2 to 17:30.9, still below the ordinary 20–30-minute pacing hypothesis. Protected expansion, resource allocation for mixed armies, broader AI coordination and novice/content/release acceptance remain open. Performance optimization stays deferred.

## Reproduction

Run from the project root with Godot 4.6:

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishOffenseRegression.gd
godot --path . --rendering-method mobile --script tests/rendered/SkirmishOffensePreview.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishMixedPolicy.gd -- --case=1 --repeats=1 --output=res://tmp/offense-match.json
```

Odd cases 1/3/5/7 cover Advanced Bastion Desert/Alpine and Helix Desert/Alpine. Even cases use `BaseAccessMatches.gd` for corresponding Standard starts. The wave regression reads the preserved [Alpine](ai-composition-alpine-ground-stall.json) and [Desert](ai-composition-desert-ground-stall.json) archives from the prior composition pass.
