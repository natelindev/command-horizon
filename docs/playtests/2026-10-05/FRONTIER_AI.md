# Free Frontier AI and complete matches — 2026-10-05

This follow-up fixes three omissions exposed after the initial Frontier integration. Unit statistics, technology prices and map geometry are unchanged. Performance work remains deferred.

## Changes

- Frontier AI workshops fit conventional tanks once a completed Relay workshop permits programming. Forecasts include the canonical chip price before reserving/spending funds. The actual fitted tank costs 20 M / 6 E and takes 23 s; loss of the lab falls back to ordinary production. Earlier factions retain their existing fitting choice.
- Frontier uses Maneuver while following a movement destination with an observed enemy nearby, including retreat and regroup routes. Stationary shooters retain their cooldown. Activation preserves the current manual/program order, research/chip eligibility and cohort rules.
- A productive Frontier materials engineer can queue a preferred, observed, safe home wreck outside the current field at a delivery boundary. Existing cargo arrives first; electronics assignments continue. Pending orders are not duplicated. Wreck selection rejects targets without a navigable collection face, including a later building placed over a nonblocking wreck. Ordinary deposits retain their existing selection rules.
- The reference commander uses the faction's chip cost and harvest eligibility. Matrix records explicitly identify both factions; its original eight cases retain their meanings. A separate wrapper samples Frontier purchases, salvage cargo, research and Maneuver during paid Coastal Foundry matches.

## Regression evidence

All accepted evidence is retained in [frontier-fullmatch](../2026-10-04/frontier-fullmatch). Before logs and superseded fixture runs deliberately contain failures. Changed-code format/lint checks pass for all eleven files, and the [editor import](../2026-10-04/frontier-fullmatch/editor-import.log) finishes without script errors. Existing navigation-readback and shutdown-only resource warnings remain visible in logs. Initial wrapper parse failures and an invalid early salvage fixture are not accepted verification.

| Check | Result / evidence |
| --- | --- |
| Paid conventional fitting, exact funds, insufficient chip budget, actual completion, lab-loss fallback and earlier factions | Original implementation 6 failures; final [production regression](../2026-10-04/frontier-fullmatch/FrontierProductionAIRegression-final.log) passes |
| Stationary real shooting, hidden contacts, manual/program travel and actual recovery route | Identical final fixture 3 failures before, [0 afterward](../2026-10-04/frontier-fullmatch/FrontierManeuverAIRegression-final.log) |
| Productive-field salvage and adverse targets | Identical valid fixture [11 failures before](../2026-10-04/frontier-fullmatch/frontier-salvage-ai-final-before.log), [0 afterward](../2026-10-04/frontier-fullmatch/frontier-salvage-ai-final-after.log); real HQ income is 4 M original cargo + 4 M wreck + 4 M resumed mining, with +4 E continuing independently |
| Gameplay and salvage/archive edge cases | [Gameplay](../2026-10-04/frontier-fullmatch/frontier-salvage-gameplay.log) and [salvage edges](../2026-10-04/frontier-fullmatch/FrontierSalvageEdges-final.log) pass |
| Shared budget and matrix accounting | [Budget](../2026-10-04/frontier-fullmatch/SkirmishBudgetRegression-final.log), [metrics](../2026-10-04/frontier-fullmatch/metrics.log) pass |
| Earlier signatures, recovery, coordination, prepared fire, coordination metrics, handoff restoration | [Signatures](../2026-10-04/frontier-fullmatch/frontier-maneuver-SignatureRegression.log), [recovery](../2026-10-04/frontier-fullmatch/frontier-maneuver-SkirmishRecoveryRegression.log), [coordination](../2026-10-04/frontier-fullmatch/frontier-maneuver-SkirmishCoordinationRegression-fixed.log), [fire](../2026-10-04/frontier-fullmatch/frontier-maneuver-SkirmishCoordinationFireRegression-fixed.log), [metrics](../2026-10-04/frontier-fullmatch/frontier-maneuver-SkirmishCoordinationMetricsRegression-fixed.log), [handoff](../2026-10-04/frontier-fullmatch/frontier-maneuver-SkirmishHandoffRegression-projected.log) pass after the fixture corrections below |

Two shared fixtures were invalid independently of these production changes. Coordination froze unused starting engineers in a wall across the authored cargo actor's route; it now removes those unused mobile actors before creating its scenario. Handoff teleported a tank inside a completed lab; it now projects the arrival onto the existing navigation map and verifies that it still lies within the original regroup threshold. Delivery quantities, order/archive checks and movement tolerances are retained. The first salvage probe likewise overlapped an advanced-start building; the final positive fixture checks actual structure clearance and navigation projection, and uses a separate world from adverse mutations. The covered-wreck case remains an explicit negative test.

## Complete-match observations

All six final runs reached an actual result, each with one complete record, zero unresolved harness checks and no script errors. They use Normal AI, Coastal Foundry, ordinary paid resources and the existing scripted reference commander. Results below are from the reference commander's perspective; the arrow points to the live AI opponent. Fitting counts are orders paid during the run, not necessarily surviving/completed tanks. Salvage is delivered Frontier cargo; the adjacent count is observed wrecks within 30 m of its HQ.

| Start | Reference → AI | Result / simulation time | Frontier fitted orders | Delivered / home wrecks | Maneuver groups | Record |
| --- | --- | --- | ---: | ---: | ---: | --- |
| Standard | Frontier → Bastion | Defeat / 343.0 s | 0 | 22 M / 17 | 0 | [Case 0](../2026-10-04/frontier-fullmatch/final-0.json) |
| Standard | Frontier → Helix | Victory / 732.2 s | 10 | 28 M / 15 | 0 | [Case 2](../2026-10-04/frontier-fullmatch/final-2.json) |
| Standard | Bastion → Frontier | Defeat / 550.3 s | 3 | 0 M / 0 | 3 | [Case 4](../2026-10-04/frontier-fullmatch/final-4.json) |
| Standard | Helix → Frontier | Defeat / 325.0 s | 1 | 0 M / 0 | 0 | [Case 6](../2026-10-04/frontier-fullmatch/final-6.json) |
| Advanced | Bastion → Frontier | Defeat / 660.3 s | 6 | 4 M / 2 | 32 | [Case 5](../2026-10-04/frontier-fullmatch/final-5.json) |
| Advanced | Helix → Frontier | Defeat / 734.4 s | 5 | 20 M / 7 | 31 | [Case 7](../2026-10-04/frontier-fullmatch/final-7.json) |

The Frontier AI's Advanced matches completed Coordination at 31.52 s, subsequently completed Weapon systems I and Combat armor I, and delivered 4 M / 20 M of salvage. Standard Frontier AI against Bastion completed Coordination at 460.73 s and used three Maneuver cohorts. These demonstrate that the corrected mechanics participate in actual matches. One of the 32 groups in case 5 had already stopped by the first per-frame observation; this telemetry is sampled after activation, so the targeted synchronous movement/retreat regression is the evidence for activation eligibility.

The human-side reference policy does not buy Coordination. Therefore zero Frontier activations in cases 0/2 is not an ability failure. Cases 4/6 had no observed home wrecks, so their zero salvage is not a missed home opportunity. The cargo counters infer origin from actual harvest targets and cargo changes; the exact delivery/conservation regression remains the stronger accounting test.

Four earlier Standard observations are retained in `baseline-*.json` and [baseline summary](../2026-10-04/frontier-fullmatch/baseline-summary.json). They already include the chip/Maneuver fixes but precede the productive salvage handoff. The same nominal seed does not produce identical matches: final case 0 loses at 343.0 s versus 670.1 s earlier, while case 2 wins at 732.2 s versus 881.1 s. This small sample cannot attribute outcome changes to salvage or establish faction win rates. Frontier's early loss against Bastion and late research in Standard starts remain progression/strategy observations, not accepted balance. Advanced starts are separate coverage, not substitutes for Standard progression or novice testing.

## Harvesting traffic observed at this stage

At the end of this Frontier AI stage, the original `SkirmishLaborRegression` fails its 100-second funding deadline for Bastion and Helix, followed by dependent queue/payment assertions. It is not a clean suite. The unchanged final run records 24 E versus 26 required and 28 E versus 34 required. [Final failure log](../2026-10-04/frontier-fullmatch/frontier-salvage-labor.log).

A diagnostic using the original geometry reaches full funding at 133.58 s / 127.85 s, then passes conservation, paid mixed production and rebalancing. A separate probe relocating the Barracks funds the route at 90.10 s. The subsequent traffic investigation corrected the initial geometry interpretation: the south base is rotated, the Barracks is at (110, 76), and a settled RepairRobot at (110, 61) is the direct contact obstacle. Moving the Barracks changes the route but does not isolate the cause. Five electronics workers share two work slots; an approaching worker loses roughly 70–80 seconds near that support unit. A retained scene replay shows recovery sidesteps followed by steering back toward stale waypoints inside the robot's collision footprint. These results identify real movement congestion plus a fragile deadline, rather than missing funds or permanent deadlock. Neither the production navigation code nor the suite's deadline was changed. [Original-route probe](../2026-10-04/frontier-fullmatch/labor-eventual-probe.log) · [Clear-route probe](../2026-10-04/frontier-fullmatch/labor-clear-route-probe.log).

The subsequent [harvesting route and handoff stage](HARVEST_TRAFFIC.md) addresses the original scenario: all three final two-faction labor repetitions pass the unchanged funding/rebalance bounds and paid production. That report retains the original failed traces, corrected navigation, separate AI decision-cadence defect and regression limits. Next gameplay work should examine Frontier's paid research/army progression across repeated strategies. Competitive balance, novice pacing, final content/platform acceptance and the overall development goal remain open.

## Reproduce

Use the repository Godot 4.6 binary with `--headless --fixed-fps 60 --path . --script res://tests/headless/FrontierProductionAIRegression.gd`; substitute the other named regressions as needed. Fixed simulation steps are necessary for these frame-counted tests.

For the full matches, use `res://tmp/FrontierCompleteMatches.gd` with `-- --case=N --repeats=1 --ground-first --proactive --output=res://tmp/frontier-N.json`. Cases 0/2 are Frontier against Bastion/Helix, 4/6 reverse those sides, and 5/7 use Advanced starts with Frontier as AI. All use Normal difficulty and Coastal Foundry. The [source manifest](../2026-10-04/frontier-fullmatch/final-source-manifest.json) retains SHA256 and complete text snapshots of the wrapper, its inherited reference policy, changed AI and targeted regressions. Restore snapshot paths by removing the `.txt` suffix if the temporary policy chain is absent.
