# Paid opening infantry guidance — 2026-10-06

The Standard-start battle plan now counts existing defenders and paid infantry jobs before recommending purchases. It requests only the remaining units needed for the existing four-defender opening target, shows the per-unit price and first purchase blocker, and switches to an already-paid message when training covers the shortfall. It advances to vehicle production when those defenders are ready.

## Original failure and change

The old step always said “Train two more infantry,” even after one or two jobs had been purchased. Its paused all-faction regression fails twelve assertions: remaining demand after the first purchase, pending state after the second, updated demand after cancellation, and exact shortage feedback. `opening-infantry/before.log` and `before/` retain this evidence.

`SkirmishOpening.infantry` counts paid infantry across completed owned barracks and uses the existing roster inspection for price, affordability and capacity. It prefers a producer that can accept the recommended job. The full plan retains HQ/worker recovery, observed combat pressure, economic assignments and power priority. It does not queue troops, spend funds, change selection or alter the opening target itself.

The descriptions show exact remaining demand and per-unit cost; one paid job reduces a two-unit recommendation to one. Enough paid jobs select their producers and ask the player to let training finish. Cancellation or producer loss removes the corresponding jobs from that calculation. Unfinished barracks retain the earlier construction step.

## Paid Standard progression

`OpeningInfantryRegression.gd` starts each faction on Coastal Foundry with the normal 60 M / 12 E, four engineers and two infantry. Three engineers gather from normal resource deposits; the fourth uses the shipping placement, payment and construction path. The sequence pays for Barracks, two infantry, VehicleFactory, a conventional tank, CommandLab and that tank's chip retrofit, then runs Guard.

The strategic players are disabled to isolate progression. Existing unit actions, harvesting, navigation, construction, training and installation remain live. No extra resources, structures, units or health are granted along this path. The paused shortage check temporarily reduces and restores the existing balance without a purchase. Later adverse fixtures are separate and excluded from the opening spending ledger.

| Faction | Simulation time at Running Guard | Opening spending M / E | Completed opening force |
| --- | ---: | ---: | --- |
| Bastion | 190.95 s | 151 / 52 | Four infantry, one fitted tank |
| Helix | 186.18 s | 149 / 56 | Four infantry, one fitted tank |
| Frontier | 167.57 s | 145 / 48 | Four infantry, one fitted tank |

These are one final observation per faction, not deterministic pacing or balance comparisons. The lab is not always immediately affordable after the tank: the valid next step can be gathering its remaining budget. The first extended test incorrectly required immediate lab construction; its three expectation failures are retained in `regression.log`. `verified.log` accepts either the actual build or funding step and finishes with zero failures.

## Verification

Final all-faction coverage includes exact purchase/refund accounting, pending demand, pause and selection authority, real training, partially completed paid training through a disk save/load, factory/tank/lab/retrofit/program handoffs, split producer queues, producer loss, reduced defender count and the 100-unit cap. The extra adverse barracks and cap-filling workers are test fixtures, not part of the paid opening.

GroundDefenseAdvice, AirDefenseAdvice, OpeningArmor and BattlePlan regressions also pass. Four changed/new scripts pass formatting and lint checks. Passing logs contain no script/parse errors. Existing navigation-readback warnings and renderer/ObjectDB shutdown diagnostics remain distinct from test results.

## Native input and layout

The native Bastion Standard opening uses actual paid Barracks construction, then Enter to select production, two mouse purchases and Space to finish training. At 1280×720 and 150% UI scale the plan updates from two required, to one plus one queued, to two already paid, then vehicle construction. Both purchases cost the shown 6 M each; paused time remains unchanged. `native.log` records zero failures and four `native-*.png` images retain the transitions.

CUA initially displayed a stale frame, although the game accepted keyboard input. Minimizing and restoring the test window refreshed the displayed state without restarting the app. The previous ground-defense turn's extra manual factory-reselection check was then rerun: real repeated selection keeps the production roster visible, and the subsequent paid Outrider completes. `factory-repeat.log` and its images retain this follow-up; the earlier report's original limitation remains historical evidence.

## Limits and next work

This verifies coherent spending guidance and a paid progression to the game's programming feature. It does not prove that the opening survives Normal AI pressure, teaches novices adequately, or improves match outcomes. The retained opening losses, broader strategy/content acceptance and final release gates remain open. Performance optimization remains deferred.
