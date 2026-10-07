# Air Corridor: difficulty routes and flight recovery

A stopped evacuation transport now displays **Holding**, with a tooltip and mission guidance pointing to **Continue flight**. Travelling and extracted flights return to **In flight** and **Safe**, clearing the holding tooltip. Continue explicitly describes replacing the transport's orders with a route to extraction. Two-safe/all-safe guidance is shorter and accurate for completed operations.

The evacuation panel now shrinks to its content after text reflow. Compact guidance and slightly tighter row spacing keep it clear of the minimap at 1280×720 and 150% interface scale. Separately, restored battles say **Battle loaded.** and retain any restore warning. The pause button and clock own the current pause state; the transient notice no longer incorrectly says the battle is paused after the player resumes.

Only `AirCorridorHUD.gd` and `MatchRestore.gd` change among shipping scripts. Flight rules, unit HP, budgets, navigation, response counts, archive schema, paid production and command authority are unchanged. The explicit response helper described below is test-only; no new autonomous commands are added to the game.

## Full difficulty routes

The existing commander clears both static batteries with ordinary ground orders, moves its screen forward, assigns shipped strike-return and service-area presets, then launches three flights. Seed 13001 uses the existing starting force and does not grant the optional prior-mission network reward. No unit health, funds or enemies are edited during these full matches.

| Difficulty / commander | Outcome | Flights safe | Simulation time |
| --- | --- | --- | --- |
| Story, existing commander | Victory | 3 | 212.45 s |
| Standard, existing commander | Victory | 3 | 211.38 s |
| Veteran, existing commander | Defeat | 1 | 197.27 s |
| Veteran, explicit observed response | Victory | 3 | 212.02 s |

The Veteran baseline clears both batteries and extracts the first transport, but loses the second and third as the screen is depleted. Its final telemetry records fourteen enemies and four friendly mobile units remaining. An opt-in reference helper issues ordinary target attacks with surviving ground troops against currently observed enemies near the screen, prioritizing aircraft for walkers. It also assigns ordinary ground repair orders. Existing strike-return aircraft behavior is retained; the helper cannot order attacks on hidden enemies and does not change the transport's orders.

The fresh explicit-response route saves all three flights. This establishes one viable response route, not a repeatability or balance claim. The initial normal-clock Veteran run with the original commander separately saves two flights and loses the third, reaching victory at 206.25 seconds. Its differing outcome reinforces that these few runs are not controlled win-rate evidence.

## Earned held-flight recovery

The rendered commander clears both batteries in real combat, launches the first flight through the HUD, then gives the transport an ordinary Hold while tactically paused. Its disk archive retains the 77.90-second battlefield, surviving units and ten-second pending response. This deliberately ordered hold is an earned tactical state, not a fabricated victory or a pathfinding failure.

The preceding HUD says **In flight** despite the lack of a movement destination. Three explanatory-status assertions fail against it. The corrected regression restores every unit's exact position and HP, retains the paused clock and response countdown, then verifies that Continue issues travel without advancing either clock while paused. After resuming, the real response arrives and the transport reaches safety in **45.03 seconds**. The final normal-clock recovery takes 45.12 seconds and exercises focused Enter on Continue.

The separate original convoy archive reproduces the misleading loaded-pause notice: twelve assertions fail, including repeated observations after live combat resumes. The first notice fixtures also access a freed HUD during cleanup and are rejected despite their earlier assertions. After adding an instance-validity guard, a fresh preceding-code run reproduces all twelve failures without script errors and the current-code run passes. Bastion and Helix repeated-restore tests also verify program-memory warnings remain visible after resuming, alongside paid-job, cargo, cooldown, missing-target, chip-refund and program-fault continuity. One early warning fixture wrongly expected the word “reset”; the shipping message is “Invalid program memory discarded.” That fixture failure and its correction are retained.

## Rendered controls and layout

The final normal-clock Veteran run saves **all three flights at 212.10 seconds**. It uses two mouse Launch activations, one focused Enter Launch activation and one focused Enter Continue activation. All commands preserve paused simulation time; the full screen/escort combat remains live between commands. The run finishes with zero assertions, and all nine final route/recovery captures are inspected.

The first rendered run reveals a panel/minimap overlap when the two-safe guidance wraps. Later recovery captures expose the related retained-height issue and a long default guidance line. Each failed layout run remains in the evidence directory. An intermediate shortened-text run also saves all three flights at 210.10 seconds and passes its captures, but it predates the final restored-panel fix. The final panel reflows to its minimum height, uses concise status text and leaves a measured **26-pixel gap** in the restored held/moving states. The two-safe frame is explicitly captured in the final full route.

Accepted 720p/150% captures show [held recovery](air-difficulties/verified-recovery-held.png), [live resumed recovery](air-difficulties/verified-recovery-live.png), [safe arrival](air-difficulties/verified-recovery-safe.png), [north battery](air-difficulties/verified-preview-air-corridor-battery-0.png), [south battery](air-difficulties/verified-preview-air-corridor-battery-1.png), [fresh held flight](air-difficulties/verified-preview-held.png), [live escort](air-difficulties/verified-preview-air-corridor-live-escort.png), [two safe flights](air-difficulties/verified-preview-two-safe.png) and [actual result](air-difficulties/verified-preview-result.png). Ordinary fog remains enabled. Inputs are engine-injected mouse/key events; physical-device acceptance remains separate.

The shared Air Corridor suite passes actual quarry ground/air traversal, paused launch and disk restoration, response timers and denial, stationary aircraft service, flight-loss defeat, population limits, HQ recovery, unescorted damage, Standard combat victory and campaign reward migration. Format/lint pass for all ten affected shipping/test scripts.

## Evidence and limits

`run-index.json` classifies all twenty-one scripted invocations, including the Veteran defeat, old-code failures, invalid warning expectation and superseded layout runs. `analyze.py` checks the retained outcomes, diagnostics, source scope, exact recovery evidence, input counts and nine image dimensions. Source snapshots, shipping fingerprints, the earned archive, telemetry and `SHA256SUMS` support reproduction. Existing navigation-readback and shutdown resource/ObjectDB/RID diagnostics remain; accepted runs have no script errors.

This completes the current Air Corridor feedback and difficulty-route pass. It does not establish novice comprehension, repeated difficulty balance, optional-reward combinations or final environment/platform acceptance. Those broader requirements remain open, and performance remains deferred.
