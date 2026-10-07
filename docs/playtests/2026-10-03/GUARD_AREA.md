# Guard-area coverage — 2026-10-03

Guard area now acquires currently observed, legally targetable enemies throughout its assigned circle. The old search stopped at weapon range plus two metres even when the player selected a larger area. A tank at the center of a 12 m assignment ignored a visible raider 11 m away: both Bastion and Helix stayed still and dealt zero damage in the retained [before run](guard-area-before.log).

The Guard search now covers the circle from the defender's current position, including when it stands at the opposite edge. The existing sector filter, target priority, domain, allied observation, obstruction and firing-range checks still apply. An enemy leaving the assignment stops pursuit; the defender returns to the center. The selected preset's tooltip states that it engages observed enemies inside the area and returns afterward. This changes the built-in **Guard area** preset; specialist presets and saved Lua source retain their existing behavior.

## Verified behavior

The [both-faction regression](guard-area-regression.log) uses a clear northern route on Desert Frontier. An allied engineer supplies observation of the outer target. After correction, the Bastion/Helix defender travels about 5.50/5.77 m and deals 18 HP damage during the measured engagement window.

It also verifies:

- Acquisition across the full sector from the opposite edge, actual travel and damage.
- No acquisition of hidden targets, targets behind a completed blocking building, or aircraft by a ground-only tank.
- A visible target leaving the sector stops taking damage, and the defender returns to its anchor.
- Manual hold suppresses pursuit; low health prioritizes the assigned retreat point, and recovery returns the defender to its assignment before renewed engagement.
- Tactical pause freezes travel, fire and simulation time. A real disk archive taken during the outer-target approach preserves the paused clock, position, radius, anchor and running program; resumed movement and combat complete successfully.

The obstruction fixture initially used a construction foundation, which correctly did not block fire. The retained run uses a completed barracks and verifies the obstruction itself before checking behavior.

Shared [program](guard-area-ProgramRegression.log), [specialist](guard-area-SpecialistRegression.log), [squad](guard-area-SquadRegression.log) and [order](guard-area-OrdersRegression.log) suites pass. Editor import, changed-file formatting/lint and whitespace checks pass. Existing navigation/rendering and shutdown-resource warnings remain; the retained successful runs contain no gameplay script errors.

## Complete-match follow-up

Four new Advanced-start Normal-AI matches use the same retained economy-screen/repair commander and seed 4110 as the [previous final policy pass](strategy-defense-final.json). All reach ordinary victory and retain five or six engineers at the result. Costs, damage, speeds, production policy and enemy AI were not changed for these trials. Full [match records](guard-area-matches.json) preserve income, expansion, losses, repair and stationary travel.

| Human / map | Previous final pass | Guard-area pass | First assault | Outer cargo return | Final engineers |
|---|---|---|---|---|---|
| Bastion / Desert | W · 6:41.4 | W · 7:47.4 | 5:27.7 | 6:37.7 | 6 |
| Bastion / Alpine | L · 12:51.6 | W · 6:37.0 | 4:16.7 | None | 5 |
| Helix / Desert | L · 6:54.7 | W · 6:41.4 | 4:13.2 | 6:30.7 | 6 |
| Helix / Alpine | L · 10:31.0 | W · 6:56.9 | 4:26.2 | 6:36.2 | 6 |

The isolated regression proves the acquisition fault and correction. The match cohort is exploratory: prior unchanged-policy repetitions also varied substantially, and crowd avoidance/asynchronous navigation are not deterministic from the seed alone. Four wins do not establish faction balance or novice success. The longest sampled stationary trip is 8.5 seconds (human Helix/Desert); no episode reaches the probe's 15-second diagnostic threshold.

Pacing remains below the 20–30-minute hypothesis. Protected expansion, mixed compositions, strategic enemy responses, novice acceptance and the broader content/release gates remain open. Performance work stays deferred.

## Rendered review

The retained normal-clock Metal run at 1280×720 and 150% interface scale checks both factions with ordinary fog, a selected guard, the 12 m assignment, and Ready/Running status. It repeats the movement/combat/archive/boundary scenarios. Selection is driven by the game selection API; this is a rendered state/layout review, not a physical-device input test.

- [Bastion assigned area](../../../art/skirmish/guard-area-bastion-assigned.png) · [engaging the outer target](../../../art/skirmish/guard-area-bastion-engaging.png)
- [Helix assigned area](../../../art/skirmish/guard-area-helix-assigned.png) · [engaging the outer target](../../../art/skirmish/guard-area-helix-engaging.png)
- [Rendered run](guard-area-rendered.log) · [source fingerprints](guard-area-build.json)

## Reproduction

Run from the repository root with Godot 4.6:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script tests/headless/GuardAreaRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/GuardAreaPreview.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script tests/headless/SkirmishDefensePolicy.gd -- --case=5 --repeats=1 --output=res://tmp/guard-followup.json
```

Advanced case IDs: 1 Bastion/Desert, 3 Bastion/Alpine, 5 Helix/Desert, 7 Helix/Alpine. Both ordinary victory and defeat remain valid trial outcomes.
