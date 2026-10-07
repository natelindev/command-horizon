# Choose clear program assignment points

**Follow-up correction:** the initial filter described here also blocked valid retreat points inside completed compatible service buildings. [Service assignment verification](SERVICE_ASSIGNMENT.md) repairs that regression and supersedes the blanket safe-point restriction below; guard/patrol restrictions remain.

Ground guard, retreat and patrol assignments now reject a point inside an owned living structure or foundation before changing any selected unit's program. The instruction line says **Choose a point outside your buildings for ground units.** Targeting stays active, so the player can choose another point. Existing actions, manual queues, assignments, funds and tactical pause are preserved.

The full selection is validated before any change: a mixed aircraft/ground group is rejected together, while aircraft alone can still receive a point above a building. The check uses only the player's own structures. It does not inspect hidden enemy footprints or navigation geometry to provide this feedback.

A bad second patrol click retains the exact staged first waypoint. If a building appears over that first waypoint between clicks, the route input restarts at the first point with an explanation; the live route is preserved. Signature sectors remain area commands and can include buildings. Chip-service and escort targeting retain their separate rules.

## Cause and implementation

The retained Industrial pressure evidence already contains ground guards blocked by friendly construction. The existing runtime identifies that obstruction and asks for a clear assignment. However, the map assignment UI previously accepted points inside the same known footprints, disabled the previous program and stored the unusable assignment. A player could choose another blocked point while trying to recover.

`SkirmishHUD.gd` now checks point-based ground assignments before program mutation. The existing owned-footprint lookup moves unchanged from `PresetAction.gd` into `UnitPlacementUtils.gd`, so runtime explanations and input validation share precisely the same structure, life/deletion and radius conditions. Only these three shipping scripts change. Movement, arrival, combat, save fields and resource costs retain their previous rules.

This validates known owned footprints, not general path reachability. A distant obstruction, terrain gap, enemy structure or later construction can still block a program. Existing Blocked feedback and explicit reassignment/Resume remain necessary. The change does not automatically move assignments or restart programs.

## Verification

The final `AssignmentFootprintRegression` passes for Bastion, Helix and Frontier. It checks all three assignment kinds, mixed-selection atomicity, air-only targeting, foundations, foreign/dead/deleting structures, two-click route preservation and revalidation, and ordinary sector activation. Rejection preserves a nonempty manual queue and a genuinely running guard, as well as paused Ready programs. A valid assignment still requires explicit Resume.

The corrected assignment and route survive a real paused disk save/load with the exact clock, position and assignment values. The restored footprint rejects another bad retreat point without interrupting the program. The guard then reaches its clear assignment and damages an in-area enemy using actual combat; all other friendly combatants, including the fixture aircraft, are disabled for that assertion.

An isolated project with all 288 preceding shipping scripts runs the identical final regression and fails **84 assertions**, including downstream failures after accepting bad input. These are not 84 independent bugs. There are no script/parse errors in this final negative control.

Seven final headless suites pass:

- AssignmentFootprintRegression
- GuardArrivalRegression
- ProgramIssuesRegression
- DirectOrdersRegression
- SignatureRegression
- LuaProgramRegression
- VisualRulesRegression

These retain the existing foundation/obstruction arrival exclusions, occupied-ally guard formation, earned blocked-program discovery, command authority, signature behavior, Lua and visual-program execution, and saved authoring/factory behavior.

The final rendered Helix run passes **19 engine-injected map clicks** at **1280×720 and 150% UI scale**, including rejected and accepted points, staged patrol recovery, post-load rejection and preservation of a running guard. All **six final captures** were inspected: guard/safe/patrol rejection, corrected assignment, reload and actual defense. Text remains readable within the existing HUD and selection viewport. Selection, arming and Resume are programmatic in this runner; no native OS input acceptance is claimed.

Formatting and lint pass. Final accepted logs have no script or parse errors. Existing navigation GPU-readback warnings and shutdown ObjectDB/resource/RID diagnostics remain.

## Retained development failures

The first fixture incorrectly expected Bastion's Anchor ability without enabling its Coordination prerequisite. That single failure also appears in the earliest original-source control. The fixture now explicitly enables its prerequisite.

The first rendered run then revealed a fixture lifetime error: it tried to revive a structure that had already been freed after a death check. It now creates a separate deletion fixture. The next rendered run exposed exact-vector assertions applied to projected mouse input. The final checks preserve the actual staged first point exactly and allow only 0.01 metres of projection error for the newly clicked second point. Shipping arrival bounds are unchanged.

An intermediate passing combat check could have included the fixture aircraft's damage. The final run disables that aircraft and also checks rejection against an already running guard. Earlier sources, logs and captures remain classified as intermediate or rejected evidence, rather than being counted as final acceptance.

Evidence, source fingerprints, run classifications and SHA-256 inventory are in `assignment-footprints/`. Reproduce the positive regression with:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/AssignmentFootprintRegression.gd
```

Use `tests/rendered/AssignmentFootprintPreview.gd` without `--headless` and pass `-- --captures=res://tmp/assignment-review` for a new rendered capture set.

## Separate departure audit

Before this change, `FrozenDepartureProbe.gd` compared a worker leaving west of HQ for the same remote resource with disabled neighbors versus normally active, idle neighbors. All three disabled-neighbor branches fail to collect or deliver within 60 seconds. Traces show repeated backward recovery followed by the same blocked approach. With active idle neighbors, all three complete real collection/delivery in **30.60 / 26.42 / 28.30 seconds** for Bastion / Helix / Frontier.

Both probes complete normally and retain their 20-second checkpoints in `departure-recovery/`. This does not repair the preceding frozen-army fixture stall or establish general congestion freedom. It shows that the disabled-neighbor case alone does not justify changing normal movement behavior. Movement code is unchanged this turn.

Industrial sustained defense, successful full-match progression and broader content/novice/platform acceptance remain open. Performance remains deferred.
