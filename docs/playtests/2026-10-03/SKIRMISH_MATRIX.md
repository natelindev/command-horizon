# Repeated skirmishes and AI support — 2026-10-03

This pass exercises the repeatability gate across Bastion/Helix, Desert Frontier/Alpine Relay and Standard/Advanced starts against Normal AI. It also fixes AI repair assignment, large-building repair reach and attack-move completion problems found during complete-match review. Performance optimization remains deferred.

## AI repair correction

Previously, the skirmish commander ordered each idle repair robot to follow `soldiers[0]`. Starting infantry normally occupied that position. The repair service correctly rejects infantry for mobile repair, so the robot followed an unrepairable target indefinitely while damaged armor received no support. The focused before-fix test failed both target choice and actual healing for each faction.

The commander now filters through the shared repair eligibility rules. It keeps an unfinished legal repair, prioritizes a wounded machine or completed structure over a healthy escort, and assigns distinct targets to its support robots. With no damaged target, a robot can accompany healthy ground combat armor. Infantry, aircraft, self-repair and unfinished structures remain ineligible. Invalid, lost or absent targets release their old travel orders. Choices use only the AI's own units; enemy visibility and spending remain unchanged. Repair rates, combat suppression and stacking retain the shared rules.

`SkirmishSupportRegression.gd` verifies the original mixed infantry/tank case, actual health restoration, two distinct repair channels, priority for a damaged engineer, aircraft rejection, tactical pause, target loss, replacement of an existing invalid order, a real disk archive during travel, restored arrival/healing and no-target cleanup for both factions. The focused test, shared combat/order/Lua regressions and normal-clock Metal support preview pass. The preview shows actual visible combat and frozen repair/travel during pause at 1280×720.

## Structure repair and attack-move completion

The longer review also reproduced two shared control problems. A robot ordered to repair a headquarters reached the navigation boundary 3.0055 m from its center and remained in Repairing without restoring any health. Preset/Lua repair approached even closer, which the building footprint also prevented. Mobile repair now measures its three-metre reach from a completed structure's footprint; mobile targets retain center-to-center distance. Manual repair, built-in service programs, Lua repair intents and actual repair allocation use the same distance function. The focused test covers HQ and airfield footprints, the inside/outside range boundary, actual travel/healing through all three control paths and tactical pause in both factions. Infantry/aircraft/self/unfinished-building restrictions, service rates, power effects and non-stacking rules remain intact.

A travel trace found infantry stationary for 45 seconds while repeatedly attack-moving toward a point inside a friendly structure. Navigation had already reached the accessible edge, but AttackMoving tested only distance to the original point. It now accepts the movement system's completion event, including after restoration, and releases the next queued order. Both factions pass an occupied HQ destination, queued movement onward, an airfield placed over a destination while the unit is travelling, a real disk save/load and paused restoration. Shared combat-order tests still verify firing and later queue handoff.

Selection details now explain the mobile repair reach and show infantry/aircraft recovery slots and range. Those two facility rows were previously unreachable branches beneath the generic structure condition. Actual 720p robot, barracks and airfield selections are reviewed for both factions, including normal-clock repair of a large airfield.

## Controlled commander and measurements

`SkirmishMatrix.gd` uses the actual human player's paid placement/production/order APIs against the unmodified live Normal opponent. Standard and Advanced starts use their shipped funds, units and technology. The fixture never supplies resources, changes HP/damage, disables the opponent or reveals the map. Both sides retain normal harvesting, construction, power, production, combat and Command defeat.

The reference policy trains six engineers, assigns materials/electronics, builds infantry/factory/lab, uses a Guard preset on its first programmable combat unit, adds repair support and gives direct attack-move orders when it has nine combatants. Before the first assault it responds to currently observed enemies near its HQ. At six minutes, if enough engineers survive, it explicitly assigns one engineer to the authored outer electronics field. Ground destinations use public starting areas; contact queries still obey current observation. Once the assault starts, the policy commits reinforcements and may leave its base exposed. This deliberate, limited policy is a repeatable experiment rather than a substitute for a human playtest or an optimal strategy.

Each match has a 30-simulation-minute observation window. Victory, Defeat and Draw are valid outcomes; an unfinished match is recorded and fails the completion check. The test does not require the commander to win. Three repetitions use fixed initial seeds 4100–4102; navigation/avoidance scheduling can still vary, so the seeds do not promise exact deterministic replay.

Measurements include first observed enemy, basic unlock, first running preset, first direct assault, expansion order and first returned outer electronics, both sides' casualties, actual damage/repair HP, and stationary travel. Every minute records funds, unit counts, engineer assignments/work states, and surviving mobile military base-price value in separate materials/electronics amounts. The value includes support/scouts but excludes workers, structures, queued jobs and chip fees; fitted basic-tank counts are listed separately. Human income is reconstructed from paid expenditure plus remaining stockpiles minus starting funds; there are no test refunds or injected purchases.

“Stationary travel” is a diagnostic: less than 0.05 m displacement over a half-second sample while movement still has a destination more than 1 m away. The report counts time after five consecutive seconds and retains the longest interval. It can include legitimate crowd/combat interactions and is not, by itself, proof of a pathfinding bug. Fixed-step simulation is used to exercise gameplay; these runs are not frame-rate measurements.

The metric regression exercises real construction, weapon damage, mobile repair and destruction. It confirms that construction HP is excluded from repair, accepted damage and healing are measured exactly, and casualties are counted before the dying unit loses its owner. Earlier exploratory fixture errors were corrected before the retained matrix.

## Results

All **24/24 matches reached an ordinary result**, with three unique repetitions per faction/map/start combination, nonnegative recorded stockpiles and consistent worker totals. The final process exited 0 with zero unresolved completion checks and no script errors. This passes the matrix execution check; it does not close the whole repeatability/scale gate or prove tuning is ready to lock. [Machine-readable observations](skirmish-matrix.json) retain every per-minute sample and loss, including the unsuccessful openings.

| Faction | Map | Start | Results | Duration | First contact | First preset | Outer cargo returned |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Bastion | Desert | Standard | 3 W / 0 L | 8:43.1–9:29.0 | 2:21.2–2:21.3 | 2:54.8–2:57.2 | 3/3 · 6:37.2–6:42.2 |
| Bastion | Desert | Advanced | 0 W / 3 L | 7:01.8–8:06.5 | 1:40.7–1:41.7 | 0:00.8–0:00.8 | 0/3 |
| Bastion | Alpine | Standard | 2 W / 1 L | 5:22.2–9:27.7 | 2:08.7–2:08.7 | 2:52.3–3:08.8 (2/3) | 2/3 · 6:37.7–6:47.7 |
| Bastion | Alpine | Advanced | 0 W / 3 L | 5:59.8–6:24.2 | 1:27.7–1:28.2 | 0:00.8–0:00.8 | 0/3 |
| Helix | Desert | Standard | 3 W / 0 L | 9:10.4–12:25.3 | 2:25.3–2:25.8 | 2:41.3–2:49.8 | 3/3 · 6:32.2–6:41.7 |
| Helix | Desert | Advanced | 0 W / 3 L | 5:45.1–5:50.5 | 1:36.2–1:37.2 | 0:00.8–0:00.8 | 0/3 |
| Helix | Alpine | Standard | 3 W / 0 L | 8:12.9–9:09.7 | 2:10.2–2:10.2 | 2:42.8–2:47.8 | 3/3 · 6:33.7–6:41.2 |
| Helix | Alpine | Advanced | 0 W / 3 L | 6:03.3–6:33.4 | 1:25.7–1:25.7 | 0:00.8–0:00.8 | 0/3 |

Times are simulation minutes:seconds; ranges include only events that actually happened. Advanced technology is available at spawn, so the 0:00.8 program reading is the first observation sample, not a research duration.

**Opening and loss review.** Eleven of twelve Standard matches won. Their outer-field return preceded completion in all eleven; one Bastion/Alpine opening lost at 5:22.2 before its first programmable unit or assault. At 2:00 it had 24 M / 0 E of surviving infantry versus 80 M / 20 E of enemy infantry/tanks; by 4:00 it had lost its workers, factory and lab. Its recorded funds were only 1 M / 32 E at that point. The policy keeps replacing infantry/workers before buying its first chipped tank, making this opening vulnerable to material starvation under early pressure. This is a strategy weakness to examine, not evidence to discard the run.

All twelve Advanced matches lost. The same nine-combatant trigger commits the initial army at 1:17.2, before or shortly before first observed contact. At 3:00 every Advanced run has less surviving army base-price value in both currencies than its opponent. The policy continues reinforcing that attack and does not implement a retreat/rebuild strategy. All twelve fail to return an outer electronics load. These observations support testing different commitment, retreat and spending policies before drawing faction-strength conclusions.

**Timing and support.** Standard basic unlock ranges from 2:15.8 to 2:43.3. Completed Standard matches range from 5:22.2 to 12:25.3; Advanced matches from 5:45.1 to 8:06.5. Every match is shorter than the intended ordinary 20–30-minute range. Across the 24 runs, human/AI actual healing totals 919.1/2,103.8 HP, and recorded casualties total 636/565 units and structures. Individual AI repair totals can be zero when support never operates before defeat. Detailed composition, received damage, losses, M/E income/spending, worker allocation and army value remain in JSON. The controlled opening does not establish subjective pacing or all-strategy balance.

The retained [eight opening-policy pilot matches](skirmish-matrix-opening-pilot.json) preceded the final shared repair/movement corrections. All four Standard openings won in 8:10–10:31 and all four Advanced openings lost in 5:45–7:11. Source/fixture work continued around those exploratory runs, so they are diagnostic history, not a strict causal before/after cohort.

The first exploratory policy guarded only its home resource approach and lost to an attack on its base before launching an assault. Its HP/loss instrumentation was also incomplete, so it is excluded from the retained comparison. The current policy adds a base screen and reacts only to observed contacts. No opponent nerf or economic tuning was made to turn that loss into a win.

### Crowd-avoidance failure retained by this review

Two final matrix runs report long AI stationary-travel intervals: 111 seconds in Helix/Alpine/Standard repetition 0, and 60.5 seconds in Helix/Desert/Standard repetition 1. Three extra Alpine diagnostics did not reproduce the first interval. Six extra Desert diagnostics exposed infantry/tanks stuck at their home base; a subsequent archive capture caught an AI engineer at `(108.9, 0, 67.14993)` with an intact path toward electronics. These diagnostic runs are separate from the 24-run cohort.

The [captured battle archive](skirmish-stationary-battle.json) reproduces the engineer remaining within 0.001 m of its starting point for roughly 20 seconds. Removing the other mobile units while preserving structures lets it move 13.6 m in the first five seconds and harvest within ten seconds. Avoidance supplies a velocity pointing outside the walkable boundary, while navigation projection clamps the unit back. This supports a crowd/boundary interaction as the next movement investigation; the precise two original AI intervals are not individually proven to have the same cause. An experimental choice of recovery side was inconclusive and is not applied to production.

`SkirmishTravelReplay.gd` replays the retained state with commanders disabled so their decisions do not change the comparison. Existing unit combat remains active in the full replay; `--isolated` removes the other mobile units as a diagnostic intervention. The replay reports behavior and is **not a passing no-stall regression**. [Full replay trace](skirmish-travel-replay.log) and [isolated trace](skirmish-travel-replay-isolated.log) preserve the remaining failure. The occupied-destination fix above solves a separate arrival problem.

The subsequent [crowded-base movement pass](CROWD_BOUNDARIES.md) corrects the captured intact-path failure and adds a passing archive regression. A different empty-path stall remains open in its follow-up matches. The observations and original replay traces above remain unchanged as before-fix evidence.

### Normal-clock review

A separate rendered Bastion/Desert/Standard match used the same policy and final source at normal simulation speed on Metal. It reached Victory at **9:47.5**, with first observed contact/basic unlock at 2:21.7, first running preset at 2:46.7, first returned outer electronics at 6:44.2 and first direct assault at 6:46.2. The opponent launched five attacks. Human/AI actual repair totalled 56.3/29.6 HP, and their longest stationary-travel intervals were 2.0/3.0 seconds. The human side harvested 495 M / 144 E and spent 473 M / 150 E, including its starting funds. See [the full normal-clock observations](skirmish-normal-clock.json).

Opening, contact, first program, expansion return, first assault and the actual result were captured at 1280×720 with ordinary fog. Layout and the result screen are visually reviewed. This verifies one complete rendered match using the scripted commander; direct physical-device input and subjective human pacing remain separate acceptance work. [The source fingerprint](skirmish-matrix-build.json) identifies the eight changed production scripts and both matrix drivers used by the retained final runs.

## Reproduction

```sh
godot --headless --fixed-fps 60 --path . --script tests/headless/SkirmishMatrixMetrics.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/SkirmishSupportRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/StructureRepairRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/AttackMoveArrivalRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/SkirmishMatrix.gd -- --output=res://docs/playtests/2026-10-03/skirmish-matrix.json
godot --headless --fixed-fps 60 --path . --script tests/headless/CombatRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/OrdersRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/LuaProgramRegression.gd
godot --path . --script tests/rendered/SkirmishSupportPreview.gd
godot --path . --script tests/rendered/SkirmishMatrixPreview.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/SkirmishTravelReplay.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/SkirmishTravelReplay.gd -- --isolated
```

For stationary-travel diagnosis, run `tests/headless/SkirmishTravelProbe.gd` with the same arguments; it logs actor, role, action, path, target, velocity and HP for intervals of at least 15 seconds. Add `--archive=res://tmp/stationary-battle.json` to preserve the first such state without advancing the simulation while saving.

For an individual scenario, add `--case=0 --repeats=1` after `--`. Cases 0–3 are Bastion and 4–7 are Helix; within each faction the order is Desert Standard, Desert Advanced, Alpine Standard, Alpine Advanced. An alternate `--output=res://tmp/…json` preserves the checked-in observations.

## Rendered evidence

- [Bastion repair](../../../art/skirmish/ai-support-repair-bastion.png) · [Helix repair](../../../art/skirmish/ai-support-repair-helix.png)
- [Bastion combat support](../../../art/skirmish/ai-support-combat-bastion.png) · [Helix combat support](../../../art/skirmish/ai-support-combat-helix.png)
- [Paused Bastion support](../../../art/skirmish/ai-support-paused-bastion.png) · [paused Helix support](../../../art/skirmish/ai-support-paused-helix.png)

These support images and associated checks isolate repair targeting with visible real units. The separate complete normal-clock match is linked below.

- [Repair selection](../../../art/skirmish/service-ui-robot-bastion.png) · [airfield selection](../../../art/skirmish/service-ui-airfield-helix.png) · [barracks selection](../../../art/skirmish/service-ui-barracks-bastion.png)

- Full match: [opening](../../../art/skirmish/matrix-normal-opening.png) · [contact](../../../art/skirmish/matrix-normal-first_contact.png) · [preset running](../../../art/skirmish/matrix-normal-first_program.png)
- Full match: [outer cargo returned](../../../art/skirmish/matrix-normal-expansion_return.png) · [first assault](../../../art/skirmish/matrix-normal-first_assault.png) · [victory](../../../art/skirmish/matrix-normal-result.png)

## Remaining acceptance

The subsequent [movement follow-up](CROWD_BOUNDARIES.md) fixes the captured crowd/boundary failure but retains another empty-path stall. The five-first-time-player preset/usability gate remains open, as do broader strategic matchup tests, long-term economy/retreat policies, subjective pacing, third-faction content and release/platform performance. The design's ordinary 20–30-minute match target remains a tuning hypothesis, not a finding from this commander. Existing navigation GPU-readback and shutdown resource warnings remain. The overall game-polish goal stays active.
