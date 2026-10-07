# Visual rule authoring and deterministic Lua

Verified 2026-10-02 with Godot 4.6 on macOS arm64. This delivers visual authoring, not the separate battlefield arena, campaign, save/load or LLM assistance.

## Player flow and contract

Select a programmable unit and open **Visual rules**. Five starters cover Hold, Guard & regroup, Scout patrol, Escort and Repair. Edit/reorder up to twelve cards. Conditions cover health, recovery, eligible enemies/allies, missing area and distances to assigned points. Actions cover Hold, assigned-point movement, nearest/weakest attack, repair, escort and patrol. The first matching rule with an available target wins; otherwise the unit holds with normal idle defense. Repair candidates must be inside the assigned six-meter repair area, so a more injured ally outside it cannot block a legal target.

Retreat/recovery thresholds retain hysteresis; recovery must be at least ten percentage points above retreat. Optional named modes are Normal, Regroup, Support and Patrol. Each card can filter the current mode and set the next mode; the transition affects the following evaluation. Resume resets program memory. The Show states switch controls visibility of advanced fields, not execution of existing state rules.

The editor derives role requirements and lists battlefield assignments. Generated Lua is read-only. Sample checks show health and the emitted rule/action reason from eight synthetic snapshots per permitted role. They do not dispatch orders or establish battlefield success. Editing invalidates the displayed trace. Save creates an immutable version; explicit Apply prepares every eligible VM before replacing any order. Missing assignments enter Waiting. Manual orders remain authoritative.

Both editors pause the match and restore the prior pause state. Invalid/unsaved drafts persist for the match. Copy as Lua preserves the visual original and opens a separate unsaved source draft without a simulation tick during the handoff. Arbitrary Lua cannot return to cards. Both script modes require the native runtime; built-in presets remain available independently.

## Persistence

Library schema 3 accepts previous schema-1 presets and schema-2 Lua records, without rewriting on read. Visual records add the strict version-1 rule document to source/API/hash/role metadata and fixed threshold parameter metadata. Loading validates the graph, recompiles it and verifies exact source agreement and canonical hashes. Factory jobs copy the exact full version; later library revisions/deletion cannot change queued jobs. Existing file/record/source caps and corrupt-file preservation remain in force.

Compiler changes after release require explicit versioning/migration that preserves old generated source. Hashes provide consistency checks, not authentication. Per-unit map assignments and live state are not embedded into reusable library versions.

## Verification

- `tests/headless/VisualRulesRegression.gd`: passed graph/source/hash round-trip, tampered graph/source rejection, malformed fields/thresholds/states, rule cap, all supported condition/action combinations through the real Lua VM, nearest/weakest priority, retreat hysteresis, hidden contact loss, repair-area filtering, patrol missing points, named state transitions, clean Resume and rule reordering. It also runs inherited Lua authoring migration/corruption/version/atomic-application tests. Both factions passed live visual Apply, Waiting/Running, retreat, manual override and exact factory inheritance.
- `tests/rendered/VisualRulesPreview.gd`: passed actual viewport clicks/threshold keyboard edits, priority reorder, states, samples, save/Apply, generated-source preview, separate Lua copy, unchanged loaded JSON version, invalid draft preservation and both pause-ownership states at 1280×720. Screenshots reviewed for layout, validation and trace readability.
- `tests/rendered/LuaEditorPreview.gd`: existing source-editor input, saved versions, invalid edits, pause and factory pin flow passed after shared-editor changes.
- `tests/rendered/ProgramPreview.gd`: existing preset/library/assignment/authority/production UI passed at 1280×720 and 1440×900.
- Godot editor import, changed-script formatting/lint and `git diff --check`: passed. No GDScript errors or failed gameplay assertions in final runs.

## Scale measurement

Ran the rendered `tests/headless/ScaleBenchmark.gd -- --visual` workload alone at 1920×1080 on the development M1 Pro, with 200 mobile units, 80 structures and 32 resource nodes. All 200 units travelled and all 200 visual VMs evaluated; 97 weapons fired. Peak observed Lua VM allocation was 67,317 bytes. Mean movement/combat frame times were 27.87/34.15 ms; p95 44.12/54.97 ms. These are one-run measurements, not a performance guarantee. Stable 30/60 FPS remains open, and this workload does not cover twelve-card worst-case programs or every map.

Existing navigation GPU-readback warnings remain. Headless shutdown still reports ObjectDB instances/two resources in use; the scale run also reports shutdown-only ObjectDB leakage. No native sanitizer rerun, exported-package check, other-platform test or first-time-player usability study was performed in this slice.

## Review artifacts

- [Rule cards and sample reasons](../../../art/skirmish/visual-rules-720p.png)
- [Threshold validation](../../../art/skirmish/visual-rules-validation-720p.png)
- [Generated Lua](../../../art/skirmish/visual-generated-lua-720p.png)
- [200-unit workload](../../../art/skirmish/scale-visual.png)

Next: isolated battlefield scenarios with expected outcomes and actual time/intent traces, followed by tutorial and game-state save/load work.
