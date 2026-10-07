# Own-force battle debrief — 2026-10-06

The skirmish result previously showed only elapsed time and surviving population. It now reports completed force/engineer production, own force/engineer casualties, completed-building and foundation losses, basic-program unlock time and first active program time. The summary calls surviving population “units” because it includes engineers.

## Record contract

`BattleRecord.gd` listens to completed production and destruction events for the human player. Starting units, queued/cancelled production, cancelled construction, enemy events and scene cleanup do not count. Combat/support mobiles are grouped as forces, engineers separately; destroyed foundations are separated from completed structures. The record stops at match end and observes programming milestones only during live simulation. A pending program during tactical pause is not an active program.

The counters describe events, not causes of defeat, resource efficiency or enemy behavior. A first active program can later block or fail; the milestone does not certify its effectiveness. Campaign-specific result summaries remain authored by their missions.

## Saved-history contract

Snapshot version 9 stores the inert record with typed bounded counters and finite milestone times. Capture/restoration retain the record without duplicating startup events. Invalid counters, missing/extra fields and invalid/future timestamps are rejected by the save schema. Existing versions 1–8 remain supported; legacy-construction regression fixtures now remove the new field when deliberately downgrading a current snapshot.

For older saves, counters begin at the restored simulation time and the result says “Battle record begins at …”. Previously unlocked basic programs and the unknown first program time say “Not recorded”. An explicit completeness flag distinguishes even a partial record beginning at 00:00. An unlock genuinely reached after restoring a pre-unlock save can still be observed. The game does not invent historical production or casualties from surviving units.

## Verification

- Three original all-faction assertions reproduce the absent own-force record.
- The final all-faction regression exercises paid production completion, cancellation, enemy exclusion, engineer/combat/structure/foundation deaths, paused pending programs, real activation, end-of-match freezing, exact disk restoration, legacy fallback, resaving partial history without changing its scope, and malformed record fields/counters/timestamps.
- Shared snapshot and restore-edge suites pass. Weapon modes, resource fields, research, ambient life and Frontier gameplay suites verify their deliberately downgraded legacy archives against the new schema.
- Complete and partial-history result panels are rendered at 1280×720 with 150% interface scaling. All four result navigation controls remain present and the panels fit the viewport.

The final automated rendered run passes all three factions, including actual Skirmish setup-button activation and the completed scene transition. Six result captures show complete and partial histories. Twelve changed scripts pass formatting and lint checks.

Physical keyboard input traversed from Play again to Skirmish setup and activated it. The initial native harness checked the new scene too early, before Godot completed its deferred scene change. A subsequent retry expired before input. On the next rebind, computer use selected Godot’s Project Manager instead of the running test window; that retry was stopped. The corrected rendered harness verifies the actual setup-button signal and completed scene transition after waiting for the deferred change. Final physical-keyboard repetition is therefore not claimed. These fixture/input failures remain archived.

An initial fixture also referenced the autoload incorrectly and supplied a null producer to a global production event; corrected final logs must contain no script/parse errors, independently of exit status. Existing navigation-readback and shutdown resource diagnostics remain in the headless logs.

This is debrief and save-continuity verification, not a new full-match balance or novice-acceptance result. Older match archives cannot supply missing historical totals. Broader gameplay/content acceptance remains open, and performance work remains deferred.

## Reproduce

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/BattleDebriefRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/BattleDebriefPreview.gd -- --automated --captures=res://tmp/debrief-review
```

Use a fresh capture prefix. Omit `--automated` for physical keyboard review; the final Frontier result focuses Play again, then waits for Tab, Tab, Enter to Skirmish setup. `--frontier-only` limits this navigation retry to Frontier.
