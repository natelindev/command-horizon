# Authored area defense — 4 October 2026

New **Guard & regroup** starters in Lua and visual rules defend the assigned six-metre area. They hold a legal firing position, approach observed enemies within the area, and return when those enemies leave. Retreat and recovery thresholds remain script decisions. The visual action **Defend assigned area** can be combined with other ordered rules and states; Lua exposes the same bounded `guard` intent.

Saved programs retain their original source and behavior. The [legacy visual record](../../../tests/fixtures/legacy-visual-guard.json) still validates against its original generated source and hash. Existing `attack` intents retain their range-only behavior. Scripts cannot supply a guard target, arbitrary point or radius. The player chooses the anchor; weapon range, domain, obstruction, observation, cadence and manual authority remain enforced by the engine.

## Reproduction

The old starters moved toward a two-metre center before checking whether they could fire. Eight defenders crowded that point even when they could already engage. In a 30-second stationary-target probe, the original visual starter dealt 738/828 damage for Bastion/Helix, compared with 1,728/1,755 for the corresponding built-in guard. The target has extra fixture health to measure sustained fire; unit weapons, movement, service and economy values are unchanged.

The [original probe](authored-defense-probe.log) and [final probe](authored-defense-probe-final.log) use the [same fixture](authored-guard-AuthoredDefenseProbe.gd.txt). The new visual starter matches the built-in damage in that trial: 1,728/1,755. This controlled result does not establish army balance.

The [focused original-starter test](authored-guard-before-final-fixture.log) fails twelve checks across both factions and both authoring modes: defenders abandon a legal firing position, fire outside the assigned sector, and fail to return to the normal anchor-arrival distance after the target leaves. Its [exact fixture](authored-guard-focused-before-test.gd.txt) is retained. The original [Lua starter](authored-guard-before-guard.lua.txt) and [visual rules](authored-guard-before-VisualRules.gd.txt) are retained as well.

## Verification

- [Guard regression](authored-guard-delivery-AuthoredGuardRegression.log): actual firing, approach, sector exit, hidden/obstructed/unsupported targets, absent assignment, manual movement, explicit Resume, recovery hysteresis and renewed engagement. A real disk save during approach preserves paused time, position, source, record and Lua memory.
- [Role regression](authored-guard-delivery-AuthoredGuardRolesRegression.log): all four armed roles × both factions × Lua/visual starters physically fire from legal positions. Visual requirements exclude unarmed units; a custom Lua guard request on a drone or repair robot waits without moving.
- [Twenty checks](authored-guard-final-shared.json): guards, programs, specialists, Lua sandbox/application/authoring, legacy visual compilation, real facility recovery, orders, squads, signatures, battle arena, snapshot/restoration variants, provider context and caption/panel layout. Network fixture results use normal clock timing.
- [Rendered workflows](authored-guard-final-rendered.json): both factions and authoring modes at 1280×720/150%; Lua and visual editor mouse/keyboard, save/apply, explicit area assignment, ordering, source-copy isolation, invalid edits and pause ownership; arena run/pause/resume/restart and results.

The HUD now labels its conventional controls **Preset draft** and explains that Apply replaces the selected programs. Guard boundaries use the existing neutral dashed circle. Visual records can show their declared area while suspended; free Lua shows the circle while its live intent is `guard`, and rebuilds that transient indicator after resumed evaluation. Guides describe the six-metre action. Changing an assignment deliberately suspends the program; feedback now distinguishes Resume from applying a preset draft.

## Full-match observations

[Five complete trials](authored-guard-matches.json) retain [process exits](authored-guard-match-exits.json), economy/army values, recovery, travel and AI task metrics. Normal AI and seed 4110 match the earlier reference-policy setup; asynchronous navigation can still vary between trials. Advanced trials use the same mixed-force commander and new converted Lua/visual guard starters, with 40% retreat and 85% recovery. Standard uses the unchanged ground-defense commander.

| Faction | Map / start | Result | Time | First assault | Authored returns / entries |
| --- | --- | --- | --- | --- | --- |
| Bastion | Desert / Advanced Lua | Defeat | 4:44.4 | None | 5 / 9 |
| Bastion | Alpine / Advanced visual | Defeat | 4:30.1 | None | 3 / 5 |
| Helix | Desert / Advanced Lua | Defeat | 4:45.1 | None | 4 / 8 |
| Helix | Alpine / Advanced visual | Defeat | 4:32.5 | None | 1 / 5 |
| Helix | Desert / Standard built-in | Victory | 14:14.8 | 12:14.2 | — |

The authored cohort records 27 recovery entries, 13 returns and 14 losses, with no authored Blocked state. All five trials record 3,934 AI coordination samples without task/order violations; longest sampled stationary travel is 2.5 seconds. No unresolved archive or fifteen-second travel capture was required.

Readiness snapshots distinguish simulation behavior from the reference commander's choices. Each Advanced trial has eight ground combatants before contact, below its nine-unit assault threshold. In the Standard trial, samples from 8:00 through 11:00 show a sufficiently large, healthy army still held by visible home threats and the twenty-second quiet requirement. It attacks once all gates open. This does not explain the earlier uncaptured 25:42 loss; that long outcome did not repeat here. Costs and difficulty were not tuned to force wins. Sustained mixed-force strategy and pacing remain open.

The [Advanced wrapper](authored-guard-AuthoredGuardMatches.gd.txt), [authored commander](authored-guard-AuthoredRecoveryMatches.gd.txt), [unresolved-save hook](authored-guard-PresetRecoveryMatches.gd.txt), [Standard wrapper](authored-guard-GuardStandardMatches.gd.txt) and [readiness sampler](authored-guard-PolicyReadiness.gd.txt) are retained for reproduction.

## Captures and limits

Final reviewed guard captures: [Bastion Lua firing](../../../art/skirmish/authored-guard-bastion-lua-engaging.png) / [approach](../../../art/skirmish/authored-guard-bastion-lua-approaching.png), [Bastion visual firing](../../../art/skirmish/authored-guard-bastion-visual-engaging.png) / [approach](../../../art/skirmish/authored-guard-bastion-visual-approaching.png), [Helix Lua firing](../../../art/skirmish/authored-guard-helix-lua-engaging.png) / [approach](../../../art/skirmish/authored-guard-helix-lua-approaching.png), [Helix visual firing](../../../art/skirmish/authored-guard-helix-visual-engaging.png) / [approach](../../../art/skirmish/authored-guard-helix-visual-approaching.png). The [final audit](authored-guard-final-audit.json) lists all eighteen reviewed captures, checks and file hashes. Full-match gameplay predates the final HUD boundary/draft-label and assignment-feedback changes; those later changes have focused shared and rendered coverage.

Input tests inject Godot window events. Physical-device, cross-platform and novice acceptance remain separate. Initial fixture failures are retained: [range placement](authored-guard-fixture-range.log), [pending action/noncanonical health](authored-guard-expanded.log), [projectile settling/arrival tolerance](authored-guard-sector-diagnostic.log), [editor gesture/window setup](authored-guard-visual-editor.log) and [old Lua Running expectation](authored-guard-final-LuaEditorPreview.log) and [missing explicit Resume in the assignment fixture](authored-guard-lua-assignment-trace.log). The [accelerated provider run](authored-guard-final-LLMProviderRegression.log) failed to accept a loopback connection and then dereferenced the missing peer; its [normal-clock run](authored-guard-provider-normal-clock.log) passes. These failures are excluded from passing evidence. Existing navigation-bake and shutdown resource warnings remain.

Reproduce the focused checks with Godot 4.6:

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/AuthoredGuardRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/AuthoredGuardRolesRegression.gd
godot --path . --script tests/rendered/AuthoredGuardPreview.gd
godot --path . --script tests/rendered/VisualRulesPreview.gd
godot --path . --script tests/rendered/LuaEditorPreview.gd
```

Broader balance, ordinary pacing, earlier uncaptured movement cases, content/mixing, novice and release gates remain open. Performance optimization stays deferred; the scale fixture was adapted to the new starter shape without running a performance benchmark.
