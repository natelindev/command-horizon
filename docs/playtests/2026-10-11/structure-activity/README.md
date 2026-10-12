# Structure activity and production departures — 2026-10-11

[14-second preview](structure-activity.mp4) shows construction, a researching radar, infantry running through sliding doors, a tank driving from the assembly bay, and an aircraft lifting from its pad. PNGs show the three factions. Captured with Godot 4.6 / Metal; video is 30 fps, 1440 × 904.

## Behavior

- Activity is part of the building: scaffolding, small mounted task lights, rotating sensors, assembly machinery, and sliding doors. Warm task lighting fades on/off and stays steady while working; the previous chasing light row is removed. No floating activity text or progress bars were added. Existing health indicators remain unchanged.
- The final 1.1 seconds of infantry training, 1.8 seconds of ground vehicle production, or 2.4 seconds of aircraft production animate the departure. This consumes the existing timer and follows its low-power rate.
- The departing model remains part of the paid queue until completion. The live unit appears at the exact endpoint, receives its programs and rally order, and keeps its population reservation throughout.
- Occupied exits hold the job without losing the unit or its payment. Cancellation removes the departure and refunds its paid cost. Destroying the producer removes its departure model.
- Save version 12 records departure endpoints so a blocked exit restores at the same location while paused. Earlier save versions remain supported.

## Verification

All 13 suites passed:

- StructureActivityRegression: every structure role and producer type across all three factions; no activity labels; rotating research sensors, steady lighting and gradual light shutdown; stationary foundations; visible movement and exact live-unit handoff; blocking/resumption; refund/cleanup; low-power timing; rally handoff; paused blocked-departure restoration; version-11 compatibility.
- InfantryHeroesRegression
- TechnologyRegression
- ResearchFeedbackRegression
- FoundationDurabilityRegression
- UnitMotionRegression
- RallyRetargetRegression
- ProgramRegression
- SaveRestoreRegression
- FoundryBatchRegression
- FrontierProductionAIRegression
- NavigationRegression
- SaveSnapshotRegression

The frozen roster and accelerated factory-batch fixtures now clear the physical doorway between units, matching the new egress behavior. NavigationRegression still verifies all six produced tanks reach their destinations.

Focused GDScript lint and Godot editor import passed. Headless runs continue to report the existing resource/RID cleanup warnings at shutdown; no script errors or failed assertions remain in the successful runs. No new long-match performance benchmark was run.

## Reproduction

```sh
./tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/StructureActivityRegression.gd
./tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/StructureActivityPreview.gd
```

Lighting refinement was checked again with StructureActivityRegression (all factions, zero failures), focused GDScript formatting/lint, and a fresh rendered preview. The 13-suite run above belongs to the preceding complete activity/departure implementation.
