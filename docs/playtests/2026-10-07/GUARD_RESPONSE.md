# Match defensive sectors to a guard's weapons

The default reference commander previously moved every running guard's sector to the highest-ranked home threat. A ground-only tank could therefore follow an aircraft and leave a compatible ground attacker outside its sector. Shipping skirmish tactics already select compatible domains; this defect was in the reference match controller.

`MixedResponsiveMatches` now uses `GuardResponsePolicy` to select the first currently observed threat that the individual unit can target. Existing economic-danger priority is preserved among compatible contacts. A guard without a compatible contact returns to the ordinary defense point. The existing two-metre update tolerance remains, and manual, retreating or otherwise protected units keep their authority. No program is started or replaced, and safe points remain unchanged. All 288 shipping scripts match the preceding electronics-handoff baseline. This is a default reference correctness fix, not a promoted economy or balance experiment.

## Verification

Five final suites pass: GuardResponseRegression, GuardResponseRolesRegression, AuthoredGuardRegression, SkirmishDefenseRegression and AirDefenseAdviceRegression. Formatting and lint pass. Accepted runs have no script or parse errors; existing navigation-readback warnings and shutdown ObjectDB/resource/RID diagnostics remain.

The controlled mixed-raid test covers Bastion, Helix and Frontier in both authored Lua and visual modes. An observed aircraft is ranked first and a ground attacker is placed beyond the wrongly selected sector. The tank chooses the ground contact, approaches and actually damages it within 180 simulation frames. An actual disk save/load preserves the paused position, anchor, safe point, Lua source, target health and clock. Manual Stop, explicit resume, protected orders, air-only fallback and hidden-contact rejection pass.

The original-selection control fails 24 assertions: six incompatible anchors, six failures to damage the ground attacker, six air-only fallback failures and six hidden-contact failures. This control reproduces the old first-threat selection while retaining the test's protected/manual gates; it is not a historical shipping comparison. The six hidden-contact cases directly exercise the helper's defensive contract: the ordinary caller already filters unobserved units.

The role fixture covers all three walkers. Bastion and Frontier keep the first aircraft threat; Helix Precision selects ground, then selects aircraft after an ordinary, completed Interception switch. Protected walkers keep their sector. These are controlled fixtures with basic programming enabled and stationary enemy targets, not paid technology or contested survival evidence.

## Complete paid comparison

Both runs use CautiousRelayMatches, Standard start, Normal difficulty, Industrial Crossroads, Helix versus Frontier, seed 4110, screened-air strategy and combined research. Electronics handoff and HQ-reserve experiments are not enabled. An isolated control project restores the preceding MixedResponsiveMatches source; its shipping hashes match the current project. Both complete with zero unresolved harness checks and no AI coordination violations.

| Measure | Previous reference | Compatible sectors |
| --- | ---: | ---: |
| Basic unlock | 182.23 s | 183.23 s |
| First program | 218.23 s | 377.73 s |
| First assault | 553.73 s | None |
| Defeat | 761.20 s | 472.00 s |
| Harvested M / E | 704 / 168 | 419 / 78 |
| Net spent M / E | 670 / 176 | 465 / 86 |
| Guard reassignments | 142 | 1 |

Opening trajectories differ before either controller has a running guard to reassign. The same seed does not produce identical runtime battle/navigation trajectories. This pair establishes completion and supplies checkpoints; it does not establish a survival improvement or regression caused by guard selection. The corrected run still fails to sustain home defense or launch its main assault. The direct mixed-raid reproduction supports the correctness fix independently of these outcomes.

## Retained development failures and scope

The first positive and negative tests tried to reassign a program before it entered Running and left the ground target within the original sector. Both failed eighteen assertions and are rejected as fixtures. The corrected test waits for Running and places the target outside the wrong sector. The first walker test omitted the basic-programming prerequisite and failed seven assertions; its source and log are retained separately. The final role fixture explicitly enables that prerequisite. `run-index.json` classifies all eleven Godot runs; source snapshots, shipping fingerprints, match metrics and checkpoints remain in `guard-response/` with a SHA-256 inventory.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/GuardResponseRegression.gd
```

Add `-- --original-policy` for the selection negative. Run GuardResponseRolesRegression.gd for walker modes. The complete match runner accepts `-- --case=6 --repeats=1 --research=combined --strategy=screened-air` with fresh output/archive paths; reproduce the control from the retained preceding reference source in an isolated copy.

There is no UI change or rendered-input acceptance claim. This work does not validate clear approach geometry for every reassigned sector, sustained Industrial defense, resource-route protection through later raids, general congestion or broader novice/platform acceptance. The overall goal remains active; performance stays deferred.
