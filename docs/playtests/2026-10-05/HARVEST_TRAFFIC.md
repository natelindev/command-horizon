# Harvesting routes and delivery-boundary handoffs — 2026-10-05

This stage addresses engineers repeatedly steering back into a settled repair robot while carrying out ordinary resource orders. The original base, workers, support unit, two work slots, finite resource stock and 100-second labor-test funding deadline remain in place. No unit price, speed, collision radius, map geometry or save schema changes.

## Cause and final change

Ground navigation returned numerous nearly collinear points along triangle boundaries. Each was treated as a precise waypoint. When local avoidance took an engineer around a settled repair robot, it could keep steering back toward an unnecessary intermediate point, including points inside the robot's occupied footprint. Visible sideways movement did not necessarily advance the route.

The movement change is five lines in `Movement._ready()`: enable Godot's path simplification for ground units with a 0.01 m threshold. This removes redundant intermediate points while keeping meaningful path bends. The original recovery implementation is retained. Arrival/contact tolerances, avoidance settings, clipping, order revision, manual queues and destination coordinates are unchanged. Aircraft keep their existing navigation behavior.

Godot documents path simplification as a way to address path-following problems with steering and avoidance; the setting uses a curve-point reduction algorithm. The threshold here is deliberately small compared with the existing 0.2 m waypoint tolerance. Actual passage, collision, delivery and archive tests below establish the behavior in this project. [Godot 4.6 NavigationAgent3D documentation](https://docs.godotengine.org/en/4.6/classes/class_navigationagent3d.html#class-navigationagent3d-property-simplify-path).

The south advanced base is rotated. The settled support unit is the RepairRobot at (110, 61), not the Barracks at (110, 76). The earlier Barracks-relocation probe changed route geometry and could not establish which obstacle caused the delay. The previous Frontier AI report has been corrected.

## Delivery-boundary scheduling

A later full labor repeat funded both production lines but failed to move four Bastion engineers back onto materials within the existing 100-second rebalance window. Four focused repetitions did not repeat that failure. A separate deterministic real-movement fixture then exposed a scheduling defect: the old AI only queued a new job during a loaded return within HQ radius + 4 m. An engineer at 6.282 m was just outside that boundary; by the next 1.5-second decision it had delivered four electronics and begun another electronics trip. Both decisions missed the entire eligible interval. This proves the timing defect, without retrospectively proving it caused the untraced repeat.

The AI now queues a needed next assignment during any loaded return to HQ. The harvest action still credits actual cargo at physical HQ contact before retiring and starting that queued job. The planner retains one new handoff per decision, stable queued assignments, safe approaches, protected expansion, observed threats and manual authority. It does not change prices, cargo, delivery contact or decision frequency. The isolated candidate queues at 10 m, preserves the current action and four cargo, then delivers exactly four electronics before switching to materials.

## Evidence and iteration

The [original labor failure](harvest-traffic/labor-before.log), [scene capture](harvest-traffic/capture.log) and retained archives reproduce the traffic. A replay shows an engineer moving two metres sideways, then reversing toward a waypoint only 1.03 m from the robot, inside its 1.28 m physical separation limit. Another loaded engineer circles a waypoint only 0.35 m from the robot while moving enough to avoid the stationary threshold. [Original replay](harvest-traffic/replay-before.log) · [Residual trace](harvest-traffic/residual-replay.log).

Two custom route-refresh patches were tested and then removed. They improved specific captures and passed three complete labor runs, but additional trials still found long returns. The retained deep traces distinguish intermediate-waypoint loops from empty engineers waiting near HQ. One discarded-candidate trace included a 24.5-second loaded trip; a separate 15.38-second trip was delayed near the HQ. Those failures remain in the evidence directory and are not counted as acceptance.

An isolated comparison then used the original pre-stage movement implementation with only path simplification enabled at runtime. Three fresh residual trials pass with longest loaded returns of 6.83 / 6.62 / 9.37 seconds and 40 / 36 / 32 E actually delivered. The complete archived traffic/manual-order suite and original labor scenario also pass. This supports replacing both custom patches with the smaller engine-supported change. [Isolated full traffic](harvest-traffic/simplified-only-full.log) · [Isolated labor](harvest-traffic/simplified-only-labor.log). Final verification below uses the actual production initialization, not the runtime override.

Fixed simulation steps do not make local avoidance trajectories identical across fresh processes or different scene-loading sequences. Earlier candidates sometimes passed the same deadline. All repeats and failed diagnostic runs remain available; these are bounded functional and regression observations, not proof of universal congestion freedom.

## Final verification

The shipping path initialization passes the full archived traffic/manual suite and three fresh residual-only processes. The residual suite times every observed loaded electronics return, including unfinished trips, against the unchanged 12-second bound; it also requires at least five real deliveries. It checks finite resources, cargo/orders, a stationary support unit, pauses and physical step/footprint bounds.

| Check | Result / retained evidence |
|---|---|
| Original movement with final traffic test | Four failures, including a 26.30-second loaded return and an engineer that never collects/delivers. [Baseline](harvest-traffic/harvest-remaining-original-final-test.log) |
| Full archived traffic with shipping simplification | Pass; watched Helix pickups 7.02 / 7.82 s; residual maximum 6.85 s, 32 E actually delivered. [Log](harvest-traffic/accepted-full.log) |
| Three fresh residual processes | Pass; longest returns 6.83 / 6.18 / 7.08 s, actual income 36 / 32 / 32 E. [1](harvest-traffic/accepted-residual-1.log) · [2](harvest-traffic/accepted-residual-2.log) · [3](harvest-traffic/accepted-residual-3.log) |
| Native normal-clock 1280×720, 150% interface scale | Pass; manual replacement, pause, cargo and collision assertions hold; residual maximum 6.20 s with 32 E delivered. Twelve captures retained. [Log](harvest-traffic/native-simplified-preview.log) · [Loaded return](harvest-traffic/helix-residual-returning.png) · [Manual arrival](harvest-traffic/manual-arrived.png) |
| Three final original labor runs | Pass for both factions: original 100-second funding and rebalance bounds, finite stock, saved cargo handoff, exact paid tank/aircraft production. Printed mixed elapsed time includes the earlier materials handoff and 30 seconds of production. [1](harvest-traffic/final-labor-1.log) · [2](harvest-traffic/final-labor-2.log) · [3](harvest-traffic/final-labor-3.log) |
| Maintained handoff regression | Old policy fails ten queue/next-field assertions; the final policy passes. Actual cargo is credited within the 90-frame decision interval; deferred retirement starts the queued action within the following three physics ticks. Separate disk return and manual cancellation cases preserve cargo and stock. [Before](harvest-traffic/harvest-remaining-maintained-handoff-final-before.log) · [After](harvest-traffic/harvest-remaining-maintained-handoff-final-after.log) |
| Scheduling follow-up | FrontierSalvageAI, SkirmishExpansion, SkirmishRecovery, SkirmishBudget, HarvestContinuity and Orders all pass after the handoff change; logs use the `final-` prefix. The maintained handoff regression separately verifies the exact decision interval, archived return and manual replacement. |

Seventeen shared movement/economy/geometry suites pass after the two fixture corrections below: CornerRecovery, EndpointTail, BaseAccess, ResourceNavigation, ResourceField, HarvestContinuity, FrontierSalvageAI, SkirmishRecovery, Orders, GuardArrival, Navigation, CrowdBoundary, ContactApproach, BlockedAssignment, Industrial, Coastal and Alpine. Logs named `accepted-<suite>.log` are the first simplification candidate cohort, not a claim that every file passed. Its original CornerRecovery and EndpointTail failures are retained; the corrected final logs are linked below. Later `final-*` AI/economy logs verify the scheduling change separately.

- EndpointTail expected redundant intermediate points to survive. Normal simplified routes passed every arrival, queue and physical assertion. The test now also explicitly disables simplification for an additional captured route, preserving the old short-tail coverage and its bend assertion. The genuine long-detour and adverse-neighbor exclusions remain. [Both route forms](harvest-traffic/endpoint-simplified-and-legacy.log).
- CornerRecovery allowed an arrived guard to rejoin under live engineer traffic, but still required it to be inside the circle at an arbitrary final frame. A captured failure had already settled within 20 s, was actively returning to its unchanged anchor, and re-entered on continuation. The test retains the original first-settling deadline and strict final settling for fresh stationary formations; it now checks the radius of every sampled settled guard and requires a displaced live guard to return inside within 10 s. Physical bounds apply throughout. A dedicated archive starts outside the circle and returns in 0.30 s; the final live run exercises a 4.05-second re-entry. Maximum excursion from the starting corner was 12.44 m in that live run, so this is not a hard movement fence. [Captured continuation](harvest-traffic/simplified-corner-probe-2.log) · [Final formation and return checks](harvest-traffic/corner-final-including-transit.log).

The first maintained handoff fixture incorrectly required synchronous action retirement at the delivery boundary. Its trace shows cargo already credited and the old action queued for deletion; the final regression checks actual delivery and deferred queue activation separately. This test correction does not alter the 1.5-second AI decision interval.

Initial isolated corner runs lacked their required archive and produced script errors; they are diagnostic setup failures, not baseline evidence. The corrected unchanged-source run passes. Old custom-patch native captures remain in `two-patch-native/` and are not used for final visual acceptance. Existing navigation-bake and shutdown resource warnings remain visible in raw logs; these checks do not constitute leak or performance acceptance.

All nine changed GDScript files pass formatting and lint. Headless editor import completes without script/parse errors and generates the new test/preview UIDs. [Editor log](harvest-traffic/editor-import-final.log) · [Stage code diff](harvest-traffic/harvesting-stage.diff) · [Source/archive/capture hashes](harvest-traffic/final-files.sha256).

## Scope and remaining work

These results concern the captured traffic failures and the stated regression coverage. They do not establish universal congestion freedom, human/novice pacing or faction balance. Repeated paid progression and different army strategies remain gameplay follow-up work. The overall development goal remains active; performance optimization remains deferred.

## Reproduce

Run the repository Godot 4.6 executable with `--headless --fixed-fps 60 --path . --script res://tests/headless/HarvestTrafficRegression.gd`. The test uses immutable original and residual archives retained alongside this report, checks actual cargo pickup/delivery and finite-stock conservation, preserves the settled support unit and verifies paused/manual authority, speed and footprint bounds.

Run `tests/headless/LaborHandoffRegression.gd` for the missed-decision cadence, paused disk archive and manual replacement. Run `tests/headless/SkirmishLaborRegression.gd` through the same command for the original full adaptive labor/paid production scenario. Run `tests/rendered/HarvestTrafficPreview.gd` without `--headless` or `--fixed-fps` for normal-clock native 1280×720 review. The preview changes only spectator presentation, captures actual loaded/recovery/collection/delivery states and restores in-memory display options.
