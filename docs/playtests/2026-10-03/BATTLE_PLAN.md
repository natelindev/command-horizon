# Battle-plan guidance and strategic openings — 2026-10-03

The battle plan now uses programming readiness, owned damage and observed threats to guide the next operation. Reaching nine combatants no longer skips the programming step or produces a blanket recommendation to attack. The panel prioritizes economy defense when visible armed enemies approach owned engineers/buildings or those assets have taken enemy fire within six simulation seconds. Economic recovery retains priority.

After programming, badly damaged combat, support and scout units receive recovery advice. A small surviving army gets rebuilding guidance; otherwise the player is prompted to scout unseen opposition or assess currently visible units before choosing a raid or HQ assault. Advice buttons select relevant owned units, with one usable producer for reinforcement. They do not issue movement, attack, repair or spending orders. Manual override preserves the configured-program lesson state.

## Input and selection corrections found during UI review

Two actual input faults appeared in the new controls:

- **Mixed production selection:** the command panel correctly omitted an ambiguous production grid, but its refresh logic interpreted the empty grid as missing controls and recursively rebuilt the same panel. [The original stack excerpt](battle-plan-mixed-selection-before.log) records the failure. Rebuilding production controls now requires a single selected structure; mixed selections remain safe, and the advice shortcut opens one producer with usable buttons.
- **Rapid selection shortcuts:** the old double-click handler inferred intent from all selection signals arriving within 50–600 ms. Rapid UI shortcuts triggered a screen-local type selection during a nine-unit army selection, dropping its distant infantry. [The recorded signal stack](battle-plan-shortcut-before.log) shows that reentrant path. The handler now listens for an actual left-button double-click event on a world unit, preserving the requested selection for panels, control groups and box selection.

## Verification

Both factions pass the retained [guidance regression](battle-plan-regression.log) and [final rendered run](battle-plan-rendered.log):

- Nine combatants still expose the first program setup; configured Manual units do not repeat that lesson.
- Hidden reinforcements do not alter advice; visible threats to engineers and recent enemy fire on owned assets do. Visible field contacts receive assessment advice.
- Damaged armor, repair robots and scouts receive recovery guidance. A depleted force gets one actionable producer.
- Guidance does not move units, replace their actions or advance paused time. A real paused disk save/load preserves the incoming-fire context.
- Mixed producer selection refreshes without recursion. Single world-unit input selects one unit; a double-click event selects matching visible owned units, including after restoration.
- At 1280×720 and 150% interface scale, window-coordinate mouse input selects exactly the advised units, including the distant ninth soldier. Enter collapses/expands the panel. Production from the selected factory pays for a job, and cancellation refunds it exactly while simulation time stays frozen.

The world double-click check dispatches the unit input event; it is not a physical-device gesture acceptance test. The advice/control tests use Godot's window input pipeline. Screens are rendered at normal clock speed with ordinary fog; staged actors are placed to isolate visible/hidden conditions. The first attempted field-contact fixture landed inside a sight-blocking ridge and was moved to the open north route before the retained results.

Shared [economy recovery](battle-plan-economy.log), [repair support](battle-plan-support.log), [key bindings](battle-plan-controls.log), [orders](battle-plan-orders.log), [restoration](battle-plan-restore.log), and the [complete opening UI flow](battle-plan-opening-ui.log) pass. Existing renderer/resource shutdown warnings remain; retained runs have no gameplay script errors.

## Strategy evidence, without a balance claim

The [earlier seed-4110 cohort](base-access-after-matches.json) lost all four Advanced starts under the nine-combatant early-commitment policy. A new paid reference policy assigns shipped Guard presets to the army, uses an economy-screen anchor, waits for observed home pressure to clear, withdraws damaged units for repair, and regroups a depleted assault. It uses owned state/current observation, ordinary resources and the existing unit abilities. Economy, costs, damage, unit speeds and AI difficulty were not retuned for these trials.

An [initial four-match pilot](strategy-initial-pilot.json) guarded too close to HQ and could leave after a brief loss of contact; it won one match and lost three. The revised policy screens the HQ/resource approach and requires twenty quiet simulation seconds after observed threats or damage to owned economic assets. The quiet condition is a decision rule in the diagnostic commander, not a new gameplay timer.

The [first revised pass](strategy-defense-first-pass.json) won three of four; the [final repeated pass](strategy-defense-final.json) won one and lost three. Both remain in the evidence. The latter includes the input corrections above. A shared random seed does not make crowd avoidance, asynchronous navigation updates and their subsequent combat consequences deterministic. These are exploratory policy comparisons, not a controlled estimate of faction strength.

| Human / map, Advanced | Earlier commitment | Revised pass 1 | Revised final pass | Final first assault | Final human repair |
|---|---|---|---|---|---|
| Bastion / Desert | L · 8:07.5 | W · 7:47.3 | W · 6:41.4 | 4:10.2 | 279.2 HP |
| Bastion / Alpine | L · 7:49.3 | W · 9:51.9 | L · 12:51.6 | 4:27.7 | 564.3 HP |
| Helix / Desert | L · 5:59.9 | W · 7:50.7 | L · 6:54.7 | No assault | 308.3 HP |
| Helix / Alpine | L · 6:02.5 | L · 6:58.0 | L · 10:31.0 | No assault | 306.1 HP |

The final Helix/Desert run loses its engineer economy by four minutes despite retaining six tanks. The final Bastion/Alpine run makes an expansion return and regroups, but still loses its HQ after sustained attrition. This supports economy protection, recovery and inspecting enemy roles; a fixed count of armor is not sufficient evidence that a base assault is ready.

All twelve new policy trials reach an ordinary result. Even the longest final match ends at 12:51.6, below the 20–30-minute pacing hypothesis. Human-first-time playtests, broader compositions/counters, protected expansion, strategic AI behavior and ordinary match pacing remain unresolved. No balance values are locked by this pass. Performance optimization remains deferred.

## Rendered examples

- [Programming with nine combatants](../../../art/skirmish/battle-plan-bastion-programs.png) · [scouting](../../../art/skirmish/battle-plan-helix-scout.png)
- [Damaged armor recovery](../../../art/skirmish/battle-plan-bastion-repair.png) · [economy defense](../../../art/skirmish/battle-plan-helix-defend.png)
- [Visible opposition and full army selection](../../../art/skirmish/battle-plan-helix-assess.png) · [usable production shortcut](../../../art/skirmish/battle-plan-helix-reinforce.png)

## Reproduction

[Source fingerprints](battle-plan-build.json). Run from the repository root with Godot 4.6:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script tests/headless/BattlePlanRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/BattlePlanPreview.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/SkirmishLoopPreview.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script tests/headless/SkirmishDefensePolicy.gd -- --case=1 --repeats=1 --output=res://tmp/defense-policy.json
```

Advanced cases are 1 (Bastion/Desert), 3 (Bastion/Alpine), 5 (Helix/Desert), and 7 (Helix/Alpine). The policy starts at seed 4110. Completion checks accept either ordinary victory or defeat and preserve unsuccessful outcomes.
