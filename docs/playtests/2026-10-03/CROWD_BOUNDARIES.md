# Crowded base movement — 2026-10-03

The previous full-match review retained an engineer stuck against a navigation boundary near its HQ. This pass corrects the movement/avoidance feedback responsible for that saved case, while retaining broader full-match failures as separate evidence. Performance optimization remains deferred.

## Original failure and correction

The [original archive](skirmish-stationary-battle.json) contains a Bastion engineer with a valid route to electronics, nearby returning traffic and active combat. Before the change, its position stays within 0.001 m of the starting point for over ten seconds in the failing regression replay. Removing other mobile units lets it travel and harvest, so the route itself is usable. Avoidance requests a lateral step into space excluded by the navigation mesh; movement projects the agent back onto the walkable surface. The avoidance simulation continues predicting a velocity that never actually occurred.

Ground movement now compares the avoidance velocity with the applied displacement divided by the physics step. When projection/speed limiting changes it by more than 0.1 m/s, the agent reports the actual velocity back to avoidance. Ordinary unconstrained steps do not reset that state. Neighboring agents can then react to the constrained unit's real movement. Facing and passive-motion signals also use the applied motion. Unit radii, maximum speed, collision footprints, path destinations, manual orders, harvesting rules and archive format stay unchanged.

The implementation uses Godot's documented [internal avoidance velocity reset](https://docs.godotengine.org/en/4.6/classes/class_navigationagent3d.html#class-navigationagent3d-method-set-velocity-forced). The engine documentation cautions against frequent forced resets; the change is conditional on actual movement correction and is checked against crowded movement and harvesting. Increasing all agent radii was explored only in a temporary probe and was not applied because it could conflict with infantry spacing.

## Verification

`CrowdBoundaryRegression.gd` restores the actual archive three times with all units/buildings and existing combat retained. Only commander decisions are disabled for the measured comparison. It requires travel beyond eight metres within ten seconds, actual electronics pickup within fifteen seconds, no step above the unit's normal speed bound, and no movement/time advance during tactical pause. The [clean before-fix run](crowd-boundary-before-v3.log) failed travel and pickup in its first replay; the other two recovered spontaneously. This scheduling-sensitive case is retained rather than described as exactly deterministic. After the correction [all three pass](crowd-boundary-archive.log), travelling 14.84–14.98 m at ten seconds with actual cargo pickup.

Both factions also run opposing engineering traffic around the same three-building arrangement. A real disk save/load halfway through the sixty-second run preserves exact paused position, cargo and the harvest order; both resources continue returning afterward. Each faction delivers 24 M / 12 E in this fixture, including four M initially loaded on the returning engineer. The fixture isolates access/continuity; it is not an economic balance measurement.

Shared checks pass for twelve-tank group arrival, six-worker harvesting and factory egress; both-faction 2.0/2.5/3.0/3.5-metre resource gaps, four-sided approaches, depletion and archives; four alternating-faction runs through three 16-tank advance/retreat routes with moving restoration; combat, queued orders, Lua actions, live combat restoration and all sixteen mobile/faction motion roles. These are behavior checks, not frame-rate benchmarks.

A [normal-clock Metal preview](crowd-boundary-rendered-final.log) passes the original battle and both-faction traffic with the same pause/archive assertions at 1280×720. The archived engineer travels 15.0 m by ten seconds; both factions again deliver 24 M / 12 E across the midpoint save/load. Captures show the owned engineers at the base and field with readable status/cargo and ordinary fog. The enemy engineer leaves human vision in the full archived battle, so that after-image alone does not demonstrate its travel; the measured replay and owned-worker fixtures provide that evidence. This is scripted normal-clock rendering, not a direct physical-device input test.

- Bastion: [base traffic](../../../art/skirmish/crowd-bastion-before.png) · [collecting after restoration](../../../art/skirmish/crowd-bastion-after.png)
- Helix: [base traffic](../../../art/skirmish/crowd-helix-before.png) · [returning cargo after restoration](../../../art/skirmish/crowd-helix-after.png)
- Archived battle: [loaded base](../../../art/skirmish/crowd-archive-before.png) · [battle after resuming](../../../art/skirmish/crowd-archive-after.png)

## Full-match follow-up

The three [Desert matches](crowd-desert-matches.json) and three [Alpine matches](crowd-alpine-matches.json) use the same paid Standard Helix commander against Normal Bastion AI. All six reach Victory. Desert durations are 9:39.7, 11:27.9 and 16:05.2; Alpine durations are 8:42.6, 8:47.6 and 9:11.3. The original 24-match cohort is preserved unchanged in [the prior report](SKIRMISH_MATRIX.md); these six are targeted follow-up evidence rather than a replacement balance cohort.

Five runs have longest stationary-travel intervals below seven seconds. The remaining Desert run contains an AI engineer stationary for 548 seconds at `(109.6819, 0, 65.25753)`, with no usable path to its assigned electronics field. This differs from the saved boundary case's intact path. [The retained trace](crowd-empty-path-trace.log) records the unresolved state. Six [additional Desert matches](crowd-additional-desert-matches.json), using repetitions/seeds 0–5, all reach Victory without reproducing it; their longest stationary interval is 4.5 seconds. These are a separate diagnostic cohort, not six extra repetitions of each balance combination. The empty-path case remains unresolved and is not attributed to a specific root cause. Completion of a match does not establish that every unit remained functional.

The diagnostic logger now records a fresh server path query, nearest navigable point, movement-processing/synchronization flags and nearby static footprints, and can save the first prolonged stationary state. This will distinguish a genuinely disconnected surface from stale agent state at the next occurrence. A loaded-archive logger check verifies those queries and serialization. The replay driver also stops cleanly if combat destroys its tracked engineer and has a bounded wall-clock timeout.

## Reproduction

```sh
godot --headless --fixed-fps 60 --path . --script tests/headless/CrowdBoundaryRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/NavigationRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/ResourceNavigationRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/FrontierCrowdRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/OrdersRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/CombatRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/LuaProgramRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/SaveRestoreCombat.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/UnitMotionRegression.gd
godot --path . --script tests/rendered/CrowdBoundaryPreview.gd
```

Run `SkirmishTravelProbe.gd -- --case=4 --repeats=3 --output=res://tmp/desert.json --archive=res://tmp/stationary.json` to record a fresh Desert cohort and preserve the first prolonged stationary state. Case 6 selects Alpine. Headless runs use `--fixed-fps 60`. [Source fingerprint](crowd-boundary-build.json).

Editor import, changed-file format/lint, whitespace and local evidence-link checks pass. Existing navigation GPU-readback and shutdown-only shader/RID/resource warnings remain.

## Remaining work

Resolve the additional full-match no-path case, expand strategic/retreat policies and evaluate the 20–30-minute pacing target. Five novice players, broader faction/content/environmental-audio work and release/platform acceptance remain open. The overall game-polish goal stays active; performance remains deferred.

## Follow-up: AI construction access

The [base-access investigation](BASE_ACCESS.md) subsequently captures a similar empty-path recurrence near the same location. A turret placement closes the engineer into a small navigation island. The new AI placement rule prevents that construction choice; the archived before/after regression and eight follow-up matches are retained separately. This does not rewrite the historical twelve-match results above.
