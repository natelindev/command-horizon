# Construction, repair and battle results

## Stage 1 — Construction handoff
Reproduce stopping a builder and assigning another worker through the real right-click path. Fix the failing path and cover progress preservation, approach and completion.

## Stage 2 — Repair activity
Drive service-bay arms and task lighting from actual repair assignments. Verify active service, completion, departure and pause across factions.

## Stage 3 — Battle results
Expand the responsive results screen using the existing faction HUD theme and tactical icons. Present richer recorded and final-state statistics while preserving campaign debriefs, keyboard navigation and all result actions. Verify English/Chinese layouts and smaller viewports with rendered captures.

## Stage 4 — Lancer chokepoints
Exercise six and eight Helix Lancers through Alpine Relay’s cols, corner bypass and alp road. Improve intermediate corner following without relaxing final destinations or collision constraints. Run navigation and crowd regressions.

## Stage 5 — Bottom operations menu
Remove scrolling from the bottom command, selection and production bays. Compact essential actions and move secondary detail to tooltips; review all factions, English/Chinese, mixed armies and queued research.

## Stage 6 — Docked icon submenus
Keep research in the existing bottom console, use unit/building/technology pictures with tooltip details, and navigate through buttons and contextual keys (Build B → Barracks B). Preserve selection, queue payments, pause state, keyboard focus and cancellation. No new floating operation windows.

## Agent progress
- Construction: reproduced missed picks at visible pad corners. Added an input-only construction footprint; real right-click handoff and completion pass for four building types across all three factions, preserving progress and funds.
- Repair: actual service assignments now drive articulated arms, carriage motion and task lighting. Active, healed, departed and disabled-provider checks pass for all factions. Rendered pose pairs reviewed in `art/repair-activity/`.
- Results: expanded faction-themed panel, native tactical icons, four overview counters and 20 detailed metrics. English and Chinese layouts pass at 1920×1080, 1280×720 and 854×480 for all factions; reviewed captures in `art/battle-report/`.
- Movement: intermediate waypoint tolerance now follows the unit radius while final arrival remains precise. Six- and eight-unit groups pass both cols, both directions of the corner bypass, and the alp approach without overlapping. The original battle was not archived; Alpine Relay was identified from the saved skirmish setup.
- Verification complete: ConstructionResume, RepairActivity (including pause), WalkerChokepoint, BattleReportLayout, ConstructionStyle, ConstructionContract, StructureActivity, EndgamePresentation, BattleDebrief, Navigation, GroundCrowdRecovery, MixedArmyMovement, NavigationProjection, and AttackCrowdedArrival regressions pass. The rendered repair and report previews also pass.
- Existing limitation: CrowdedDestinationRegression reports nine failures and a freed-object error from its older archived infantry scenario. Re-running with all six modified production scripts restored to HEAD reproduces the same nine failures; this is not introduced by these changes. Logs: `tmp/task-CrowdedDestinationRegression.log` and `tmp/task-CrowdedDestination-full-baseline.log`.
- Formatting/lint passes for the new tests and other modified scripts. BastionVisuals has an existing declaration-order lint issue at line 91, outside the changed sections. Existing older suites also emit resource cleanup warnings at shutdown; new regression runners use the normal application shutdown path.

- Bottom HUD: build, production, recruitment and research now use picture keys with descriptive tooltips. All 132 faction/language/scale/selection/page combinations fit without scrolling. Large mixed armies expose type portraits and individual paging; production overflow uses a count without dropping paid jobs.
- Submenu navigation: workers start with orders; B opens Build and B again starts Barracks placement. Clicks follow the same tree. Back/Escape, held-key rejection, unavailable purchases, selection changes, and construction cancellation pass across all factions.
- Docked research: global Technology opens inside the existing bottom console and preserves running/paused state and selection. Queued projects use visible picture buttons with exact cancellation/refund behavior. Tab navigates research controls without cycling the army; ordinary subgroup cycling still passes. Pausing and resuming preserves the docked research reference.
- Final HUD checks: OperationsSubmenu, OperationsFit (132 cases), ResearchTiles (6 cases), ResearchQueue, RosterLayout, SelectionRoster, BattleHudProduction (6 sections), DirectOrders, CommandReliability, Behavior, MenuWidth and HudConsole (66 states) pass. Native-rendered HudConsolePreview passes for all factions in English/Chinese; reviewed mixed selection, Build and docked research captures in `art/hud-console/`. ResearchQueuePreview also passes all six faction/language cases at 720p/150% UI, including real keyboard purchases, Tab focus, FIFO order, cascading refunds, pause preservation and fully visible queue controls.
- Formatting/lint and whitespace checks pass for the updated task files. Pre-existing model/shader import edits and UID files remain untouched.
