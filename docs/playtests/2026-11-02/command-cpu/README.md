# Synchronous command work reuse

The final change reuses one synchronous radius/origin capture for formation slots and Hungarian assignment, reuses the funnel's radius, and calculates a crowd AABB in one pass. The input controller reuses its raw heading only for a homogeneous movement domain. Mixed ground/air selections retain each domain's own pivot, and explicit drag headings retain their normalization. ManualOrders checks the current action's immutable full script path instead of extracting its filename and basename. Both eligibility evaluations around feedback remain live. Stop, cancellation, feedback, network gates, activation batches, v22 state and animation cadence retain their existing behavior. No models, materials or visual style changed.

The [six-file freeze](freeze.json) and [before/after provenance](provenance.json) identify exact bytes. Each source/test has retained before/after text and a patch in this directory. Native code and the ARM64 library remain unchanged (`b4ad2c825feeb8347267c4ec4b802e5ec2921d8e4c6c69c3507b26f852cadc27`).

## Correctness qualification

[Qualification](qualification.json) records **10/10 focused checks passing**, all launched with `--headless`. Each log has its corresponding exact command JSON:

| Check | Native | Scripted fallback |
| --- | --- | --- |
| Formation planning | [log](FormationPlanningRegression-native-final.log) | [log](FormationPlanningRegression-fallback-final.log) |
| Order activation/save/replica | [log](OrderActivationRegression-native-final.log) | [log](OrderActivationRegression-fallback-final.log) |
| Immediate point orders | [log](ImmediatePointOrderRegression-native-final.log) | [log](ImmediatePointOrderRegression-fallback-final.log) |
| Network protocol/gates | [log](NetworkFoundationRegression-native-final.log) | [log](NetworkFoundationRegression-fallback-final.log) |
| Tactical functionality | [log](TacticalFormationsRegression-native-final.log) | [log](TacticalFormationsRegression-fallback-final.log) |

Planning checks cover all factions, all four postures, custom spacing, heterogeneous radii, captured origins, boundary packing and changed live radius/origin/selection order. Captured and uncaptured assignment/slot output match exactly, and the radius getter runs once per member instead of repeated geometry scans. The actual controller's automatic and explicit headings match independent per-domain planning, including a real mixed Tank/Infantry/Worker/RepairRobot/Drone cohort. Existing NavigationServer final-owner route, spacing and unchanged-live-order assertions remain.

Activation retains 200 immediately admitted intents, immediate feedback and Stop/replacement/deletion/Shift/drag handling. All 197 noncancelled members start within three 30Hz ticks (100 ms), with at most 96 starts per tick; actual moving/arrived counts are checked. Full and partially started paused disk saves and replica no-local-activation checks remain. New actual feedback listeners change the current domain or action, proving the second eligibility evaluation does not reuse a stale decision. No new save fields or scheduling rules were added.

## Original 200-unit command and CPU diagnostics

The [retained headless fixture](HeadlessCommandAudit.gd) invokes the existing real TacticalFormations terrain handler on the same 200 selected tanks, then records eleven repeated commands without intervening simulation. It requires 200 independent authoritative tokens, complete cohorts and pending activation for every member. [Native](native-comparison.json) and [fallback](fallback-comparison.json) output matches the original recorded endpoint/order serialization. The final fixture also compares actual Vector3 values directly against the retained pre-change planner and utility, with **exact original endpoint equality in both modes**; binary signature bytes are retained in the final JSON. The utility oracle changes only its Planner dependency path to the retained original Planner.

| Diagnostic | Before | Final |
| --- | ---: | ---: |
| Native initial complete profiled dispatch, ms | 13.584 | 12.957 |
| Fallback initial complete profiled dispatch, ms | 14.872 | 14.924 |
| Native repeated caller-thread CPU median, ms | 10.934 | 11.744 |
| Fallback repeated caller-thread CPU median, ms | 12.425 | 13.050 |

These separate headless editor runs **do not establish a whole-command speedup**. Wall and caller-thread timings varied; unchanged resolve, assignment and domain-getter scopes also became slower in the final samples. Raw [native before](before-native.log)/[final](after-native.log), [fallback before](before-fallback.log)/[final](after-fallback.log), exact command JSON, all samples and the [call-tree comparison](calltree-comparison.json) remain available. No observer cost is subtracted and no graphical frame result is inferred.

The call tree nevertheless verifies the specific work reduction: derived radius reads drop **1,400 → 200** for the real command. Native `positions` falls 0.663 → 0.126 ms, the two AABB calls (0.289 ms) become one (0.078 ms), and current-action eligibility falls 0.336 → 0.256 ms while retaining all 400 evaluations. Fallback shows the same call-count reduction and corresponding geometry/type-path reductions. Movement-domain reads remain at 1,000 because the optional cache was rejected.

## Rejected Movement cache

Both lazy and eager cache experiments and their varied timing outputs remain under `lazy-cache-*` / `eager-cache-*`. A bounded extra real-Node probe found that renaming an already-added IncomingMovement child to Movement, after the old cached child had been renamed away, does not emit the parent child-order signal. The [raw two-failure reproduction](cache-rename-probe.log) is preserved. Tracking every child rename would add machinery for a small measured getter cost, so **the entire Movement cache and its lifecycle hooks were removed**. The final ManualOrders delta contains only full-action-path membership and one current-script read; its original Movement lookup/stop/cancel path is preserved. Cache-only tests were removed with that discarded feature; the live reentrant domain/action regressions remain.

Formatting passes for all six files. Lint passes for the planner, utility, ManualOrders and both regressions; UnitActionsController retains its two pre-existing duplicate-load findings. Independent read-only review found no concrete issue in the final cache-free change. All owned engines exited before the freeze. The package agent will qualify the frozen source through the full headless candidate; no broad suite or multiplayer transport run is claimed here.

**Strict MI12 remains open.** Normal/graphical launches became prohibited again before this stage, so all new verification is headless. No strict frame, full-frame gain, visual acceptance or new rendering claim is made. Graphical comparison is deferred by the user.
