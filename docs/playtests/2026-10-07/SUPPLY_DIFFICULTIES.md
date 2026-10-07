# Supply Line: difficulty routes and contested clearance

Stopped trucks now display **Contested · 9/12 s** when enemy ground units prevent checkpoint clearance. The tooltip explains the ten-metre contest area, retained progress and the need to clear it with escorts. Travelling trucks retain **Hold to clear**; cleared checkpoints remove both the contested text and tooltip. This feedback also appears immediately in paused saved battles.

The HUD and mission use one shared contest query with the preceding mission's exact predicate. Only `SupplyLine.gd` and `SupplyLineHUD.gd` change among 289 shipping scripts. Clearance time, contest radius, force budgets, prices, movement, command execution and archive format are unchanged. Escorts still require player orders; the new feedback does not move or attack with them.

## Complete routes

The existing conventional commander clears each checkpoint, brings trucks forward and explicitly stops arriving trucks. A second commander uses only the mission's **Advance convoy** and **Hold convoy** actions for the trucks: one of each per checkpoint. Both keep ordinary escort attack-move orders, finite enemy responses, original HP and starting forces. No funds, health or enemies are edited in these playthroughs.

| Difficulty | Individual arrival stops | Group Advance/Hold |
| --- | --- | --- |
| Story | Victory, 223.73 s | Victory, 224.83 s |
| Standard | Victory, 224.73 s | Victory, 228.65 s |
| Veteran | Victory, 230.23 s | Victory, 233.08 s |

All six focused headless routes resolve all three responses, extract two trucks and leave the third alive. These are single practiced-command trials with seed 12801, not repeatability or novice balance evidence. Survivor differences are not treated as a monotonic difficulty or timing comparison.

## Failure found with rendered controls

The first normal-clock Veteran playthrough successfully activates Advance with the mouse and Hold with Enter, but stalls at the first checkpoint. All trucks remain stationary with **9.8 seconds** of accumulated clearance. One surviving enemy contests and fires from outside the idle escort's weapon reach. The third truck falls to **32.1 / 180 HP**, while the HUD still displays only **9/12 s**. At the 172.82-second test deadline the mission is unfinished, not defeated. Its complete world archive, telemetry, log and screenshot are retained.

This is a tactical response requirement obscured by incomplete feedback, not a reason to change automatic engagement or checkpoint rules. A test-only optional response explicitly orders escorts toward a currently observed nearby enemy and assigns one repair robot to a damaged truck. It does not inspect hidden enemies for attack orders or modify opposition.

The earned archive restores exact positions, HP and a frozen clock. Ordinary attack-move and repair orders clear the checkpoint in **3.03 seconds** headless and **3.02 seconds** with normal-clock rendering; all three trucks survive and the damaged truck recovers to 33.6 HP. The preceding shipping HUD fails three explanatory-status assertions while the same combat recovery already works. The final regression adds tooltip lifecycle, paused Advance/Hold priority and clearance checks and reports zero failures.

## Final rendered playthrough

The fresh Veteran route with explicit observed responses wins at **229.80 simulated seconds**. It uses **three mouse Advance activations and three focused Enter Hold activations**, retaining the group-control route and ordinary combat. Two trucks extract and the third remains alive. The result is an actual combat victory, not an injected result fixture.

At **1280×720 and 150% interface scale**, the retained-state review additionally verifies the checkpoint locator with Enter and escort selection with the mouse. The contested rows fit in their existing panel and clear the minimap and unit controls. Five screenshots were inspected: [contested earned state](supply-difficulties/contest-contested.png), [recovered state](supply-difficulties/contest-cleared.png), [first checkpoint](supply-difficulties/final-preview-stage-0.png), [second checkpoint](supply-difficulties/final-preview-stage-1.png), [actual victory](supply-difficulties/final-preview-stage-2.png). These are engine-injected input checks; physical-device acceptance is separate.

The shared `SupplyLineRegression.gd` suite passes actual repair, paused commands and disk restoration, held/contested clearance, reinforcement denial, truck-loss outcomes, Story/Veteran budgets, Standard combat victory and campaign-reward migration. Format/lint pass for all eight changed/new scripts.

## Evidence and limits

The evidence directory indexes **15 scripted test invocations**. Three early group fixtures have a syntax error and return exit 0 despite a parse diagnostic; they are rejected and rerun after correction. The first rendered run also produces a 1920×1080 capture instead of the requested 720p size; that image is retained as failure evidence, not accepted layout verification. The final fixture waits for display settings to settle and reapplies the requested size before controls/captures. Native inspection after the failed game ended reached the project manager; that incidental window was closed and does not establish native gameplay acceptance.

`run-index.json`, source snapshots, shipping fingerprints, JSON timelines, the earned archive and logs distinguish those failures from the accepted runs. `analyze.py` verifies outcomes, source scope, image sizes, input counts and expected diagnostics; `SHA256SUMS` inventories the retained files. Existing navigation-readback and shutdown resource/ObjectDB diagnostics remain. No runtime script errors occur in the accepted runs.

Example group-control Veteran run with explicit observed responses:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/SupplyConvoyControls.gd -- --difficulty=2 --respond-to-contest
```

This establishes playable convoy routes across the three difficulties and makes a real stalled objective understandable. Repeated difficulty balance, novice comprehension, the other campaign difficulty combinations, final environments and platform acceptance remain open. The current convoy map is still a simple gameplay environment. Performance remains deferred and the overall goal stays active.
