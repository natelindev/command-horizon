# Sustained recovery and ground-screen spending — 2026-10-06

This audit returns to complete paid Standard-start matches against Normal AI on Coastal Foundry. It adds service-coverage observations and two opt-in reference-commander experiments. Shipping AI, player automation, unit statistics, costs and map geometry are unchanged.

## Recovery findings

`SustainPressureMatches.gd` extends the existing paid two-tank/retrofit commander. Every ten simulation seconds it records funds, power, buildings/foundations and wounded combat/support units, including their current program reason and nearby/owned facility support. The `workers` field counts engineers available to the reference economy after its safety policy excludes protected retreat/delivery orders; it is not the total living engineer count. Wound snapshots omit healthy units and therefore cannot establish army composition by themselves.

The original policy completes three new matches. Frontier wins at 400.3 seconds. Helix loses at 566.7 and 624.5 seconds. In the first Helix run, the depot is first sampled complete at 196.2 seconds and authored recovery records ten returns from thirteen entries. The two opening tanks are lost at 161.0 and 166.3 seconds, before that support completes. In the second Helix run, the depot is first sampled complete only at 476.7 seconds. These observations separate actual healing from the ability to retain a defense and economy; having repair support does not establish a sustainable strategy.

## Spending failure and experiments

The second baseline Helix match records 170 half-second decisions from 253.75 to 338.25 seconds in which a fitted tank is affordable but blocked by an optional airfield reserve of 45 M / 20 E. Full army censuses at 240.8 and 300.8 seconds show six infantry plus two tanks. The reference commander admits optional air investment at eight ready ground units, but requires nine units before considering an assault.

An initial two-armor-screen experiment (`SustainedScreenMatches.gd`) tests a different, narrower failure: infantry-only forces admitting air reservations. Its all-faction fixture passes paid replacement armor and health/death/queue boundaries, but both full Helix trials lose. It does not resolve the observed six-infantry/two-tank condition. It is retained as an experimental comparison, not promoted as the fix for that condition.

`AssaultScreenMatches.gd` instead requires nine ready ground units before starting optional air investment under the screened-air policy, matching the existing minimum ground-force size for an assault. It keeps the existing 50%-health readiness definition. An already paid airfield or foundation remains supported, and other strategy modes retain their prior behavior. This is an opt-in reference policy, not a new rule imposed on players or shipping AI.

The exact eight-unit fixture—six infantry, two tanks and sufficient resources for a fitted replacement tank—fails six assertions under the original reservation rule across all three factions. The revised regression checks the actual debit and live completion of the ninth unit, exclusion of queued/badly damaged/dying reinforcement, the 50% readiness boundary and preservation of an existing air foundation. Its units and stockpiles are controlled test fixtures; complete-match spending uses ordinary harvesting and paid construction/production.

## Complete observations

All times are simulation seconds; “—” means the milestone was not observed.

| Policy | Faction / seed | Outcome | Basic unlock | First program | First assault | Depot complete* |
|---|---|---|---:|---:|---:|---:|
| Baseline | Frontier / 4110 | Victory at 400.3 | 153.7 | 169.2 | 222.7 | 206.2 |
| Baseline | Helix / 4110 | Defeat at 566.7 | 155.2 | 181.7 | — | 196.2 |
| Baseline | Helix / 4111 | Defeat at 624.5 | 151.3 | 176.8 | — | 476.7 |
| Two armor | Helix / 4110 | Defeat at 386.8 | 155.2 | — | — | — |
| Two armor | Helix / 4111 | Defeat at 666.6 | 150.3 | 175.8 | — | 236.3 |
| Nine ground | Helix / 4110 | Defeat at 391.7 | 185.7 | — | — | — |
| Nine ground | Helix / 4111 | Defeat at 361.5 | 174.8 | — | — | — |

*First ten-second snapshot showing completion.

All seven runs reach a resolved outcome with no recorded AI coordination violations. Both nine-ground trials lose before activating a program or completing a depot. Removing the isolated reservation conflict therefore provides no evidence of a stronger opening; the variant remains experimental.

Seeds identify trials, not deterministic causal pairs: asynchronous navigation and scheduling can change the trajectories. Small sample sizes, a single map and one reference commander do not establish faction balance or a superior strategy. A valid match outcome also does not imply that every intended progression milestone was reached.

## Verification and limits

Both all-faction regression suites reproduce six original failures and finish with zero failures after their respective experimental policy changes. They exercise actual paid production and live completion. Formatting and lint checks pass for all five new scripts; final match/regression logs contain no script or parse errors. Known navigation readback warnings and shutdown ObjectDB/resource-leak messages remain in the headless logs.

The retained JSON/logs contain full outcomes, paid spending, losses, production decisions, worker/retrofit authority checks, authored recovery events and AI coordination checks. Service snapshots are spaced roughly ten seconds apart; foundation/complete timestamps are first observations, not precise construction events. No new native UI behavior is introduced by these reference scripts.

The next gameplay experiment should address conventional armor preservation before chip fitting and the timing of support investment, while retaining paid costs and explicit commander authority. Broader content, novice and balance acceptance remain open. Performance work remains deferred.

## Reproduce

Use fresh output and archive prefixes:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/AssaultScreenMatches.gd -- --case=6 --repeats=2 --research=combined --strategy=screened-air --output=res://tmp/assault-screen.json --archive=res://tmp/assault-screen-stall.json --archive-prefix=res://tmp/assault-screen-earned
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/AssaultScreenRegression.gd
```

Use `SustainPressureMatches.gd` for the unmodified policy and `SustainedScreenMatches.gd` for the preliminary two-armor variant. Case 2 is Frontier→Helix; case 6 is Helix→Frontier.
