# Adaptive AI labor and production budgets — 2026-10-04

The previous complete-match samples exposed electronics shortages alongside material surpluses, and the old production loop bought a cheaper tank before an airfield could spend the first-wing budget. The [original regression](ai-economy-budget-before.log) reproduces the latter for both factions: ten failed expectations across an exact aircraft budget, saving toward an unfunded aircraft, and the unchanged ground-production sequence. Active gatherers previously retained their fixed resource assignment indefinitely.

## Decisions and boundaries

`SkirmishProduction` derives requests from completed factories, owned and paid queued units, faction costs and currently observed armed opposition. Recovery workers have first priority, followed by needed counters, baseline infantry, repair support, reconnaissance, strike aircraft and the ordinary ground roster. Jobs at each producer remain bounded to one next purchase. Planned requests account for one another when filling quotas. A purchase the current stock cannot cover reserves its material/electronics cost before lower-priority jobs are considered. Building savings remain protected, while recovery workers can use them. A paid foundation does not reserve its construction price again. Optional Coordination research protects these higher-priority jobs; unavailable technology does not create a production request, and fitted-tank requests include the four-electronics hardware price.

`SkirmishLabor` forecasts the next construction and production cycle, including one future job at a busy producer. It compares those costs with current stocks and weights electronics twice to reflect the existing work-slot collection time. When both resources remain useful, a multi-worker economy retains at least one gatherer for each. Cargo already in transit is not counted as banked funds. This is a bounded shortage response, not an income-rate optimizer or a guarantee against contested-route delays.

An idle worker can take its planned assignment immediately. An active gatherer keeps its cargo and receives a queued change only near its HQ while returning; the existing harvest action delivers before the new resource order begins. At most one active handoff is scheduled per AI decision, and already queued handoffs count toward the intended split. Builders and unrelated commands retain authority. Construction and observed-threat retreat clear old mining queues. A newly observed threat at a queued destination or its screened approach cancels that pending assignment.

Remote material and electronics approaches share the existing two-guard budget: two guards for one approach, one each for two. Active fields take precedence over future handoffs. Admission still requires a healthy nearby ground guard, current known danger is screened, immediate defense retains precedence, and ordinary waves use remaining units. Hidden enemies do not enter the resource or production calculations. Actual navigation determines travel; the straight-corridor screen does not prove every detour safe.

No costs, mining rates, worker target, unit stats, attack intervals or save schema changed.

## Targeted verification

The [budget regression](ai-economy-budget.log) passes both factions: exact first-wing payment, saving when only a cheaper tank is affordable, visible-air counters, duplicate airfields, unavailable fitted tanks, hardware costs, protected/funded research, paid foundations, lost-worker recovery and construction overriding a mining handoff. These are staged decision boundaries; actual income and completion are checked separately.

The [labor regression](ai-economy-labor.log) begins with six real material gatherers and a staged 200 M / 0 E shortage. They schedule electronics work while carrying four materials, survive a real paused disk save/load with cargo and queue intact, deliver those materials, and earn enough electronics from finite deposits for a tank and helicopter. Both paid units then finish production. Bastion earns 28 E and spends 56 M / 26 E; Helix earns 36 E and spends 50 M / 34 E. The material starting stock is staged; the electronics are actually collected. A subsequent staged 0 M / 200 E shortage moves at least four workers back to materials and returns four materials for Bastion and eight for Helix in the final headless run. Deposit loss equals warehouse gain plus carried electronics.

The first labor fixture froze combat troops across the home traffic route. Helix returned only 24 E before its deadline. Parking those frozen troops behind the base, while retaining the same collection deadline and ordinary worker navigation, makes the isolated economy scenario pass. This fixture correction does not establish crowded-base performance or change movement code.

The [expanded field regression](ai-economy-expansion.log) retains the four Desert/Alpine guard-arrival and archive scenarios, both cargo-retreat archives and wave/defense separation. New both-faction cases exhaust both home resources, keep all gatherers waiting for two separate guard approaches, then return at least four materials and four electronics through ordinary navigation. Finite-stock assertions now include all workers' in-transit cargo, rather than assuming one electronics gatherer.

The [strengthened raid regression](ai-economy-raids.log) passes all four faction/map cases. Each established guard defeats a real infantry raider, all gatherers survive, at least four new electronics leave the deposit and further income reaches the HQ. Accounting includes the difference in cargo already in transit at raid start. Bastion Desert/Alpine clear the raider after 2.55 / 1.53 seconds and satisfy continued mining/return after 18.87 / 21.60 seconds; Helix takes 2.73 / 1.90 and 18.48 / 17.97 seconds. These are small staged raids, not global contested-economy acceptance.

## Shared and rendered verification

All eleven shared runs pass: [composition](ai-economy-SkirmishCompositionRegression.log), [offense](ai-economy-SkirmishOffenseRegression.log), [defense](ai-economy-SkirmishDefenseRegression.log), [support](ai-economy-SkirmishSupportRegression.log), [finite fields](ai-economy-ResourceFieldRegression.log), [orders](ai-economy-OrdersRegression.log), [save restoration](ai-economy-SaveRestoreEdges.log), [Coordination](ai-economy-CoordinationRegression.log), [Desert AI](ai-economy-FrontierAIRegression.log), [Industrial AI](ai-economy-IndustrialAIRegression.log) and [Coastal AI](ai-economy-CoastalAIRegression.log). The [editor import](ai-economy-editor.log), formatting and lint checks pass. No successful retained run contains script errors. Existing navigation-bake and shutdown shader/RID/ObjectDB/resource warnings remain.

The [final rendered run](ai-economy-rendered.log) repeats the actual labor/archive/paid-completion scenarios at normal simulation speed, 1280×720 and 150% interface scale. All six captures were inspected: [Bastion electronics](../../../art/skirmish/ai-economy-bastion-electronics.png), [mixed completion](../../../art/skirmish/ai-economy-bastion-mixed.png), [materials](../../../art/skirmish/ai-economy-bastion-materials.png), [Helix electronics](../../../art/skirmish/ai-economy-helix-electronics.png), [mixed completion](../../../art/skirmish/ai-economy-helix-mixed.png), [materials](../../../art/skirmish/ai-economy-helix-materials.png). Staged human reconnaissance reveals the opponent's ordinary workers, base and newly completed units. Brief normal-clock refreshes precede the paused captures. Initial troops are parked/frozen for economy isolation; newly produced armed units remain live and can attack the staged scouts. Human HUD stock is not the AI's stock. This verifies scene rendering and the underlying tests, not native input or unrestricted live-match strategy.

## Eight complete matches

All [eight records](ai-economy-matches.json) use Normal difficulty and seed 4110 with the unchanged Standard ground and Advanced mixed reference commanders. All finish with zero unresolved checks. Results below are from the human reference commander's perspective.

| Human faction | Map | Start/policy | Result | Duration | AI waves | Longest stationary travel, human / AI |
| --- | --- | --- | --- | ---: | ---: | ---: |
| Bastion | Desert | Standard ground | Defeat | 6:40.9 | 5 | 1.0 / 2.0 s |
| Bastion | Desert | Advanced mixed | Defeat | 12:31.2 | 10 | 3.0 / 3.0 s |
| Bastion | Alpine | Standard ground | Victory | 7:51.3 | 4 | 2.0 / 1.0 s |
| Bastion | Alpine | Advanced mixed | Victory | 18:37.5 | 9 | 1.5 / 3.0 s |
| Helix | Desert | Standard ground | Defeat | 5:34.4 | 4 | 1.0 / 1.5 s |
| Helix | Desert | Advanced mixed | Defeat | 5:20.4 | 4 | 2.0 / 1.5 s |
| Helix | Alpine | Standard ground | Victory | 8:58.7 | 5 | 2.0 / 1.5 s |
| Helix | Alpine | Advanced mixed | Defeat | 12:01.3 | 10 | 2.0 / 1.5 s |

Raw logs: [0](ai-economy-match-0.log), [1](ai-economy-match-1.log), [2](ai-economy-match-2.log), [3](ai-economy-match-3.log), [4](ai-economy-match-4.log), [5](ai-economy-match-5.log), [6](ai-economy-match-6.log), [7](ai-economy-match-7.log).

There are three wins and five losses: Standard 2/4 wins, Advanced mixed 1/4. Samples show actual allocation changes: in Bastion/Desert Advanced, the opposing Helix economy moves from 1 M / 5 E at 121 seconds to 5 M / 1 E at 601 seconds, then 2 M / 4 E at 721 seconds. A strike aircraft is present in the AI's sampled forces in four cases (0, 1, 3, 7); the other cases do not establish sustained air production. These records show integration and changing allocations. They do not isolate the effect on win rate: asynchronous navigation/combat varies even with the same seed.

No stationary-travel episode reaches fifteen seconds; the maximum on either side is three seconds. The human reference policy returns outer-field cargo in five cases. Cases 4 and 5 end before its 360-second expansion gate; case 0 never reaches an expansion order. These human-policy observations are distinct from the targeted AI guard/expansion tests. Durations remain below the ordinary 20–30-minute pacing hypothesis. Sustained contested mixed-force strategy, broader coordination, ordinary pacing and novice/content/release acceptance remain open. Performance work remains deferred.

## Reproduction

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishBudgetRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishLaborRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishExpansionRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishExpansionRaid.gd
godot --path . --rendering-method mobile --script tests/rendered/SkirmishLaborPreview.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishMixedPolicy.gd -- --case=1 --repeats=1 --output=res://tmp/economy-match.json
```

The [source hashes](ai-economy-source-sha256.json) retain the implementation, targeted tests and reference policy scripts. Production code stayed fixed throughout shared verification and the final complete-match cohort. Only the independent raid accounting and review fixture changed during that cohort.
