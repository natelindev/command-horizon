# Air-defense guidance and screened aircraft opening — 2026-10-05

Battle-plan advice now selects units that can respond to an observed economic raid. It offers existing anti-air cover, an explicit Helix stance change, or affordable construction/prerequisite guidance when no ready mobile counter exists. It does not issue orders, switch weapons, spend resources or reveal unseen enemies. A separate reference-command policy now establishes a ground screen before investing in aircraft.

The original selection defect is reproduced and corrected across all three factions. Native selection and paused Interception input pass at 1280×720 / 150% interface scale. Four complete screened-air matches produce strike aircraft in three cases, with two victories and two defeats. These observations leave matchup balance and broader pacing/novice acceptance open.

## Production behavior

`source/match/SkirmishTactics.gd` classifies currently observed units as economic threats only when their weapons can target an owned engineer or structure within their attack range plus the existing 8 m approach margin. Recent damage from an unseen source retains generic incoming-fire guidance. Remote aircraft, unarmed scouts and AA-only weapons beside ground assets do not invent a relevant economic raid.

For an air raid, advice prefers compatible mobile defenders. A mixed raid selects the union of legal air and ground responders. Without ready mobile anti-air, it offers nearby completed AA batteries, Helix Lancers with an explicit Interception instruction, or the real AA building and missing prerequisite chain. Construction advice retains faction names, exact prices, resource shortages and paid-foundation state. Ground-only threats similarly filter responders, offer Precision when needed, and fall back to actual production or rebuilding.

A Lancer undergoing a stance change is not advertised as ready fire. Ordinary reload or Prism deployment delay does not erase a unit's target role. Existing HQ/engineer recovery still precedes defensive advice. The weapon-mode panel also correctly displays “1 Lancer” for a single selected unit.

No unit prices, weapon statistics, map geometry, research rules or shipping AI strategy were changed in this stage.

## Original scenario and regression

The original paused raid selected `[Infantry, Infantry, Tank, Tank]` against an observed Helicopter, with zero compatible weapons, for each faction. Adding a friendly Helicopter still selected irrelevant ground-only units. The minimal regression recorded 36 repeated expected assertion failures, exit 1; these represent one shared selection defect. Retained sources and the exact minimal test are in [the evidence directory](air-defense/advice-regression-evidence.json).

The maintained [AirDefenseAdviceRegression](../../../tests/headless/AirDefenseAdviceRegression.gd) passes with zero failures and zero script errors. It covers air/mixed/ground selection, both Helix stance directions and real switch timers, undeployed Prism eligibility, distant/unfinished AA, legal paid construction and shortages, prerequisites, strong hidden-contact and unseen-hit scenarios, and recovery priority. Repeated pure advice queries preserve pause/time, resources, health/positions, action objects, queued orders, modes, production queues and selection. See [detailed regression review](air-defense/advice-regression-review.md) and [final log](air-defense/advice-final-after.log).

The construction fixture originally expected an active builder immediately after placing a foundation while paused. That expectation was wrong: the ordinary flow had queued Construct. The corrected test verifies the dormant order, explicitly resumes three physics frames, then checks active-builder advice. Both failed expanded runs and the original fixture are retained. No production change was made to satisfy that mistaken expectation.

## Native acceptance

[AirDefenseAdvicePreview](../../../tests/rendered/AirDefenseAdvicePreview.gd) extends the regression with actual native mouse input. Options are temporarily applied in memory and restored; autosaves are disabled. The fixture uses real faction units and ordinary fog, pauses the match and freezes actors while checking advice. It is a controlled UI fixture, not an earned complete-match archive.

The final native process exits 0 with zero failures and zero script errors. Actual clicks select a Bastion engineer, select the Helix Lancer, request Interception explicitly, and select only the Frontier Jackal rig/Kestrel gunship. Selection preserves resources, paused time, positions, modes and orders. The stance request retains Precision while queuing the complete 2.0-second switch, preserving actions, waiting orders and funds. The separate headless suite verifies completion on the normal clock. Panel rectangles do not overlap the minimap or unit menus; captured text and controls were visually inspected.

- [Bastion engineer and construction menu](air-defense/native-final-bastion-construction.png)
- [Helix Lancer and stance controls](air-defense/native-final-helix-interception.png)
- [Explicit Interception pending while paused](air-defense/native-final-helix-interception-switching.png)
- [Frontier compatible defenders](air-defense/native-final-frontier-mobile.png)
- [Final native log](air-defense/native-final.log)

The first native pass completed all input checks but loaded the older builder fixture and therefore exited 1 with three fixture assertions. Its log and images remain under `native.*` / `native-*.png`; the `native-final` artifacts are the accepted corrected run.

## Screened aircraft observations

The previous `air-first` reference bought its airfield after the lab with only four target infantry and no ground-screen requirement. All four retained Standard/Normal Coastal trials lost before producing a strike aircraft. Those losses therefore did not exercise aircraft combat enough to establish aircraft balance.

The new `--strategy screened-air` reference targets six infantry and requires eight mobile ground combatants at at least 50% health before starting an airfield. A paid foundation or existing airfield keeps aircraft production enabled after casualties. Owning a strike aircraft precedes optional research; replacing the last lost wing also precedes the next project. It uses existing finite resources, actual paid construction/production/fitting, observed-target raids, authored guard/recovery and ordinary research. It changes the test commander, not the shipping AI. [Runner and reproduction instructions](../../../tests/playtest/README.md).

All accepted observations use seed 4110 / recorded repetition 10, Standard starts, Normal AI and Coastal Foundry. The reference faction is listed first. “Aircraft” counts actual produced Helicopter-role strike aircraft, excluding scouts. Missing production/raid fields mean the event never occurred.

| Matchup | Earlier air-first | Screened-air | Strike aircraft | First raid |
| --- | --- | --- | --- | --- |
| Frontier → Bastion | Defeat, 311.0 s | Victory, 1405.8 s | 9 | 455.7 s |
| Frontier → Helix | Defeat, 358.5 s | Defeat, 367.5 s | 0 | — |
| Bastion → Frontier | Defeat, 338.7 s | Victory, 715.7 s | 4 | 365.7 s |
| Helix → Frontier | Defeat, 344.1 s | Defeat, 996.3 s | 1 | 382.7 s |

Frontier versus Bastion bought Coordination at 601.2 s and completed Weapon I, Armor I, Field service and doctrine later in the match. Bastion versus Frontier bought Coordination at 636.7 s. The other two references never bought research. Opposing AIs completed Coordination in all four screened cases; Bastion completed Weapon I in case 0, and Frontier completed Weapon I / Armor I in case 6. [Machine-readable cohort and milestones](air-defense/cohort-summary.json).

Accepted full records: [case 0](air-defense/screened-0.json), [case 2 corrected](air-defense/screened-2-corrected.json), [case 4](air-defense/screened-4.json), [case 6 corrected](air-defense/screened-6-corrected.json), with corresponding `.log` files. Each wrapper exited 0, the match reached a real result, and logs contain zero script errors. Recorded AI coordination violations are empty. Earlier air-first records remain in [paid progression evidence](PAID_PROGRESSION.md).

These are four observations, not a win-rate estimate or controlled proof of superiority. Godot navigation, physics and asynchronous setup are not fully deterministic at a fixed seed. Cases 0/4 started before the advice edit; corrected cases 2/6 loaded the corrected advice. The advice is a pure query and does not control either match commander. Later changes to the Lancer count label and redundant `allocation_policy` telemetry do not change the declared strategy; `army_policy: screened-air` is authoritative in the retained records, whose legacy allocation field still says `ground_first`.

Screened cases 2/6 without the `-corrected` suffix loaded a temporary malformed nested lambda in Tactics. The runner rejected their script errors despite generated records. Those files are retained and excluded. Initial shared `*-after.log` runs likewise contain script errors and are excluded; the helper-based syntax correction was verified by actual Godot loading and the final suites below. This was an implementation mistake, not a gameplay outcome.

## Final checks and remaining work

- AirDefenseAdviceRegression and native-final: exit 0, zero failures, zero script errors.
- BattlePlanRegression, EconomySupplyRegression, WeaponModeRegression: `*-final-fixed.log` runs use `--fixed-fps 60` and exit 0 with zero script errors.
- Python runner: three test groups pass, including screened-air argument forwarding, failure detection and evidence preservation.
- Changed GDScript format/lint and whitespace checks pass. [Final source and artifact hashes](air-defense/air-defense-evidence.json).

Reproduce an individual headless suite with the repository engine and its fixed timestep:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/AirDefenseAdviceRegression.gd
```

Use the corresponding suite filename for BattlePlanRegression, EconomySupplyRegression or WeaponModeRegression. Native input and full-match commands are documented in the runner README.

The first final shared invocation accidentally omitted `--fixed-fps 60`. These established fixtures wait a fixed number of process frames for production, attacks and stance timers. An uncapped headless run does not give those frame counts the intended elapsed simulation time: EconomySupply reported three failures and WeaponMode reported thirteen. Their `*-final.log` files are retained. The corrected command restores the same fixed-60 mode used by the prior passing checks; no test or production code was changed for this correction.

The headless engine still reports existing navigation-mesh and cleanup warnings. Native-final reports the existing navigation-mesh warning. These checks do not claim performance acceptance; performance work remains deferred.

Frontier's early collapse against Helix still prevents the screened airfield, while Helix versus Frontier produces only one strike aircraft and never funds research. These are concrete next strategy observations to investigate without assuming either faction needs stat changes. Matches span roughly 6–23 minutes, so the intended broader pacing, repeated strategy coverage, novice play, final environments and platform acceptance remain unfinished. The overall development goal stays active.
