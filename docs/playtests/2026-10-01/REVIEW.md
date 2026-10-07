# Prototype design review — 2026-10-01

## Scope and method

Tested the current Bastion Desert Frontier demo in Godot 4.6 on the development Mac using native mouse/keyboard interaction. Separately ran a 60-second headless economy probe at ordinary time scale with enemy processing disabled, then explicit isolated repair updates. Inspected relevant gameplay source and the previously validated Helix roster/model set. This is a formative design review by one evaluator, not a faction balance study or novice usability study.

Helix is not integrated into combat. Lua, a visual editor, LLM authoring, armor multipliers and campaign missions are not implemented. No claims about their actual playability follow from this session.

## Native session observations

1. Opened the Bastion demo, paused, selected the vehicle factory, and queued a tank, repair robot and railgun tank through the visible UI.
2. Box-selected a six-unit mixed force while paused, issued a move and resumed. The force moved; the three queued reinforcements appeared and population rose from 10 to 13. This supports the basic orders/production loop, not its final pacing.
3. The selected group panel showed “6 units selected” and “22 / 22 HP,” matching a single infantry unit. This is misleading for mixed forces and inadequate for deciding which vehicles need repair.
4. Clicking the minimap during tactical pause did not move the camera and cleared selection. Repeating the same minimap navigation while running moved it to the intended region. This confirms a paused-control gap. Source inspection also shows the selection-group handler inherits ordinary pausable processing; group operations during pause need explicit verification/fixing.
5. Assigned a group while running, moved the camera to unexplored enemy territory, recalled the group and ordered a blind move into it. On the subsequent inspection, the enemy base had been revealed and player population had fallen from 13 to 7, with no new production ordered. The operation incurred six losses. The engagement was not continuously observed, so this does not establish which weapons killed the units or a faction balance result. It does illustrate why attack-move, retreat intent, contact alerts and casualty summaries matter.
6. Paused the session at the end. No match victory or complete campaign was tested. The generous all-roster opening is unsuitable for testing the lab unlock or a normal economic build order.

## Controlled measurements

Reproduce from the repository root:

```sh
godot --headless --path . --script tests/headless/DesignProbe.gd
```

Use normal time scale; do not use accelerated fixed-FPS execution to infer combat timings while wall-clock weapon scheduling remains. The probe disables the enemy's processing, does not order production, preserves the two default automatic harvesters, and records stockpile/cargo snapshots. It then repositions one tank and healers to isolate direct repair updates. The report is [design-probe.json](design-probe.json); the [probe source](../../../tests/headless/DesignProbe.gd) documents the exact setup.

| Simulation time | Materials | Electronics | Interpretation |
| --- | --- | --- | --- |
| Start | 120 | 70 | Art-demo stockpile. |
| 30 seconds | 128 | 78 | Delivered cargo only; four materials were still carried by a worker. |
| 60 seconds | 140 | 82 | Net delivered +20 M / +12 E; another four of each remained in transit. |

This is one measured opening on one map with two workers. It is not a universal steady-state income rate, a saturation study or a prediction for four/eight workers. The new economy seeds need tests that vary travel distance, worker count and builder downtime.

| Isolated update, 0.51 seconds passed to each healer | HP restored |
| --- | --- |
| One repair robot | 3 |
| Two repair robots | 6 |
| One robot plus depot | 7 |

The nominal 0.5-second cadence yields approximately 6, 12 and 14 HP/s if processing can maintain it. The current tank deals 9 damage every 1.2 seconds: nominal 7.5 DPS before movement or targeting interruptions. These are a measured per-update repair result and an arithmetic DPS comparison, **not a simulated supported-tank duel**. Healing was free in the tested implementation. A cap and combat repair penalty should precede tuning faction health/damage.

## Source-inspection findings

| Finding | Evidence | Design consequence |
| --- | --- | --- |
| Infantry/tank damage has no armor profile at impact. | `source/match/units/projectiles/CannonShell.gd` subtracts attack damage directly. | Expensive machines lack the intended cheap-infantry/armor counter relationship; implement profiles before judging roster value. |
| Cannon damage is immediate; visual shell effects do not test blockers. | Same source; range checks in `AttackingWhileInRange.gd`. | Navigation obstacles alone do not establish cover or line-of-fire blocking. |
| Weapon readiness uses wall time. | `AttackingWhileInRange.gd` uses `Time.get_ticks_msec()` alongside pausable timers. | Pause/retarget/save behavior needs a simulation-clock regression test. This inspection flags risk; the exact exploit was not reproduced here. |
| Harvesters can search nearby deposits without preserving a field assignment/type constraint. | `CollectingResourcesSequentially.gd` calls the generic closest-resource helper after depletion. | Define type-preserving assigned fields and exhaustion feedback. Depletion behavior was inspected, not exercised in the 60-second run. |
| Repair stacks across independent providers. | Probe plus `RepairRobot.gd`, `RepairDepot.gd`. | Strongest-channel rule; retreat gains value when full repair requires leaving combat. |
| Default victory counts every surviving owned unit. | `handlers/MatchEndHandler.gd`. | Use a command-infrastructure objective to avoid unarmed-survivor cleanup. |
| AI includes privileged enemy state and a narrow offense roster. | `simple-clairvoyant-ai/IntelligenceController.gd`, `OffenseController.gd`. | Current AI cannot validate scouting fairness or the new counters; replace for product tests. |
| Constructors build at a shared 0.3 progress/s; tanks take six seconds to produce. | `MatchConstants.gd`. | Existing timings are asset-demo timings, not a validated 20–30-minute RTS economy. |
| Both factions lack a complete differentiated mobile-AA design. | Bastion catalog and Helix section 17 roster. | Assign explicit mobile air-defense roles without generating more unit models. |

## Decisions derived from the review

The detailed rules and tuning seeds are in [Core gameplay specification](../../CORE_GAMEPLAY_SPEC.md). The highest-priority changes are:

- Establish a normal start, with early chip access and observable economic choices, alongside the art demo.
- Make manual overrides and paused controls consistent before relying on automated retreat.
- Add armor/domain/obstruction rules, bounded repair and mobile AA before faction matchup tests.
- Give Bastion a holding/repair-rotation identity and Helix a scouting/commit-withdraw identity.
- Use campaign objectives and recoverable HQ defeat instead of mandatory elimination of every object.
- Define presets, assignment bounds, state ownership, error fallback and program versioning before building the Lua/LLM interface.

## Verification and limits

The probe exited with code 0 and wrote valid JSON. It reports current behavior rather than asserting that these values are desirable. Godot emitted the existing navigation mesh runtime-parsing warning and shader/ObjectDB/resource cleanup diagnostics at exit; this was not a clean diagnostic log. Those remain technical follow-ups. This task changes design documents and adds an observational probe; it does not implement the recommended gameplay rules or fix the observed UI gaps.

Next evidence needed: real Helix matches, controlled equal-budget fights, repair-under-fire trials, Standard-start timings, two map layouts, novice preset/editor sessions, pause/retarget regression and a 200-unit performance run. A stronger balance conclusion requires those experiments.
