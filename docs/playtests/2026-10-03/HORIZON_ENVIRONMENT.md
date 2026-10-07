# Command Horizon environment pass — 2026-10-03

Command Horizon now uses a reusable, editable six-asset environment kit: a ruined service building, pumping station, electrical substation and three asymmetric cut-rock berms. Worn asphalt, continuous rounded junctions, gravel shoulders, concrete service aprons and restrained soil variation replace the flat industrial slab and separate road boxes. Warm directional lighting and cooler ambient light preserve unit silhouettes. The kit includes ladders, valves, fins, insulators, retaining supports, conduit and rubble inside established solid footprints.

This is the first map environment pass. It improves the playable setting while retaining the current tactical layout; it does not close the game's final environment acceptance gate.

## Gameplay and input fixes

The old aircraft height intersected tall terrain. Horizon now supplies a smooth clearance profile: aircraft climb before landmarks and reach 8 m above their solid footprints, then descend to normal flight height. Their actual world position drives observation, projectile origins, hit areas and selection. Planar steering uses the existing unobstructed rectangular air region without spending horizontal speed on the climb. Other maps retain their prior flight behavior. This changes real airborne sight/fire geometry, so combat was rerun rather than treating the change as cosmetic.

Box selection rebases its ground polygon to each aircraft's actual height. Native testing also reproduced a separate input defect: sampling the viewport cursor position collapsed an injected drag to one point. Both the visible and world-space rectangles now use mouse-event coordinates for press, motion and release. The original native drag now selects the elevated strike aircraft, and forward/reverse event-coordinate regressions pass. Air-to-ground markers scale to actual altitude. The deployment label now uses one title update and a smaller outline; its ordinary combat view is readable.

## Verified

| Check | Evidence |
| --- | --- |
| Asset bounds | Generator checks evaluated mesh vertices; maximum radius 5.48 m and height 6.47 m fit existing 5.6/7 m blockers. |
| Ground routes | Standard north route remains closed; Foundry reward opens the short route. Actual tanks traverse both applicable passages; archives preserve route geometry. |
| Air clearance | Drone and strike aircraft cross the berm, substation, pump and ruin without entering their solid height. A 40 m crossing takes approximately 7.9/9.9 simulated seconds at their ordinary speeds. |
| Economy/construction | All four home/forward resource-kind combinations gather and return cargo. Solid landmarks reject construction; open ground remains valid. |
| Combat/archives | Elevated paused aircraft retain their position through disk reload. Actual air-to-ground damage resolves, while ground fire remains blocked by the berm. Full mission rules and shared active-combat restoration pass. |
| Input/rendering | 1280×720 close, ordinary-fog and active-combat views; 1440×900 wider composition; native deselect/drag-select of the aircraft at 8 m; full finale UI suite passes. |
| Shared movement | Existing obstacle routing, crowded movement, harvesting and factory-egress regression passes. |
| Full playthroughs | Standard south native run: victory at 351.62 simulated seconds. Standard north: 350.83. Lean: 311.72. Reinforced: 218.88. Each reports zero failures. |

Reinforced initially stalled because the test commander repeatedly issued a direct attack on an HQ that had gone out of sight. The commander now attack-moves to the known objective position when sight is lost, then targets the visible HQ; it also sends air/scout support after all four responses have been sent. Lean still pays for its additional repair unit. No mission budgets, enemy damage, capture rules or time limits were weakened to pass the test. These runs demonstrate working scenarios, not novice pacing or all-difficulty balance.

## Reproduce

Use Godot 4.6 from the repository root. Headless checks can use `--headless --fixed-fps 60 --path . --script <script>`:

- `tests/headless/HorizonEnvironmentRegression.gd`
- `tests/headless/CommandHorizonRules.gd`
- `tests/headless/CommandHorizonRegression.gd` with `-- --alternate`, `-- --lean` or `-- --reinforced`
- `tests/headless/NavigationRegression.gd`
- `tests/headless/SaveRestoreCombat.gd`

Rendered runs use `tests/rendered/HorizonEnvironmentPreview.gd` (optional `-- --inspect` leaves a native selection fixture open for 90 seconds) and `tests/rendered/CommandHorizonPlaythrough.gd`. The preview isolates progress and restores display options. Formatting/lint and editor import are checked separately. Known navigation readback warnings and renderer/resource shutdown diagnostics remain; they are not counted as release-performance acceptance.

## Images and remaining work

[Before overview](../../../art/skirmish/environment/before-horizon-overview-720p.png) · [Landmarks](../../../art/skirmish/environment/horizon-pump-and-power.png) · [Ruin detail](../../../art/skirmish/environment/horizon-service-ruin.png) · [Open north cut](../../../art/skirmish/environment/horizon-north-cut.png) · [Wider composition](../../../art/skirmish/environment/horizon-wide-900p.png) · [Flight clearance](../../../art/skirmish/environment/horizon-flight-clearance.png) · [Ordinary fog](../../../art/skirmish/environment/horizon-base-fog.png)

The three landmarks and berm still occupy the original blockout layout. Broader terrain composition, map boundaries/backdrops, vegetation, environmental audio, other maps and final visual acceptance remain open. Clearance currently applies to Horizon's authored landmarks; extending it to other maps and tall constructed structures needs its own geometry and combat checks. Performance optimization remains explicitly deferred.
