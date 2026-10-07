# Real battlefield program test arena

Verified 2026-10-02 with Godot 4.6 on macOS arm64. This delivers the first real scenario arena for custom Lua and visual rules. Campaign, save/load, optional LLM drafting, remaining faction/map depth and performance acceptance remain open.

## Player flow

Open **Battle arena** from either paused program editor. A valid unsaved draft can be tested. The arena opens a separate desktop window, retaining the live match's pause, units, orders, resources and draft. Choose a supported role and scenario, then Run. Pause/Resume freezes both arena simulation and Lua; Restart creates a new match, unit and VM memory. The grid and assignment labels make distances/positions readable. Test targets are passive except for scripted movement; real units, weapons, repair, observation and navigation perform the behavior.

Each scenario states its expected behavior and a suitable starter. The outcome lists each passed/failed assertion, followed by a bounded time/position/HP/state/intent/event trace. A passing scenario is evidence for that stated situation, not approval of every possible behavior. Different intended behavior may legitimately fail a scenario; failure does not prevent saving a valid program. Return or Escape brings completed results back to the editor. Returning mid-test discards that incomplete case. At most 32 completed cases are retained per arena visit.

The editor binds returned results to the exact draft content hash. Changed source/roles/rules/name cannot receive an earlier draft's result. Save version includes a bounded scenario/faction/role/result summary in test notes; it never automatically applies a program. Match-local draft caching retains the corresponding arena results. Copy as Lua still creates a separate draft. Closing the editor also closes its owned arena process.

## Initial scenarios

| Scenario | Actual fixture and expected outcome |
| --- | --- |
| Retreat & recovery | Start at 20% HP; reach a safe point 6 m away by 4 s. Restore 50% health until 6 s and stay safe; restore full health and return to the area by 12 s. The expectation matches the 30/80 starter; custom thresholds may intentionally differ. |
| Escort | Approach the assigned ally, then follow its real 5 m move issued at 3 s; finish within 3.8 m at 9 s. |
| Lost enemy contact | Request an attack and damage a visible passive tank; relocate it out of allied sight at 3 s. After a 0.5 s evaluation grace period, no stale attack requests are accepted as correct behavior. The engine still independently rejects illegal targets. |
| Missing assignment | No point assignment for 3 s: wait without moving. Then assign an area 4 m away and reach it by 9 s. |
| Manual override | Run any functioning program; issue a direct move at 2 s. Reach the manual destination and perform no subsequent script evaluations through 8 s. |
| Unreachable destination | A sealed pen built from actual navigation collision geometry encloses the destination. The unit must report Blocked after no progress; at 10 s accept a direct move away and reach it by 13 s. Aircraft cannot select this ground-only case. |
| Destroyed repair target | A repair robot heals a real damaged friendly tank. Destroy that target at 3 s; after the evaluation grace period the program must stop requesting its repair. |

Fixtures supply basic technology and chips. They deliberately do not verify economy/unlock timing, combat balance or mission success. Only roles allowed by the current record are selectable; weapon/repair/ground requirements additionally gate scenarios.

## Isolation and limits

The live project uses process-wide groups and match signals. Running a second live match in its tree would risk cross-match interactions, so the arena uses a separate instance of the same desktop executable. The normal startup scene recognizes the arena request before playing the logo sequence. No library writes or live-match command interface exist in the test window.

A private random workspace contains the copied request and atomic return report. Reads validate record integrity, run identity, exact draft identity, result shapes and file limits (256 KiB request, 2 MiB report). Startup has a 30-second wall-clock readiness timeout. Process failure/cancellation retains the editor draft and orders; closing the editor kills only its own child. Normal return/cancellation removes the workspace. A force-killed/crashed parent can leave a temporary workspace or orphaned window; crash recovery/automatic stale-workspace collection remains a limitation.

The arena uses the existing bounded Lua interpreter, local observation and command authority. A new evaluation signal exposes the snapshot/result to host-side diagnostics; Lua receives no additional capabilities. Each case keeps at most 180 trace entries, and saved test notes remain limited to 1,000 characters. Test events run on simulation time; pause does not advance them.

## Verification

- `tests/headless/ArenaRegression.gd`: all seven cases passed with appropriate visual programs for Bastion and Helix. All six programmable roles passed manual takeover. Hold intentionally fails retreat; a stale-target script fails lost-contact behavior; an infinite loop produces a budget fault while manual takeover still works. Missing/corrupt/wrong-run/wrong-draft reports are rejected. Passed.
- `tests/rendered/ArenaPreview.gd`: real viewport clicks verify Run, Pause/Resume, frozen position/time/evaluation count, successful retreat, readable outcome/trace, fresh Restart and 1280×720 bounds. Passed.
- `tests/rendered/ArenaLaunchPreview.gd`, with `ArenaTestBridge.gd` and `ArenaChildDriver.gd`: an actual OS child process runs the normal startup scene; its test driver clicks Run/Return through the viewport. Returned results match the draft, save into notes and are rejected after editing. Live time, orders and source stay unchanged. Closing the editor cancels the next child and clears its workspace. Final process inventory contained no remaining test Godot processes. Passed.
- Existing `VisualRulesRegression.gd` (including inherited Lua-authoring checks), `VisualRulesPreview.gd` and `LuaEditorPreview.gd`: passed after shared editor/runtime changes, including saved versions, explicit Apply, visual-to-Lua copying and both prior pause states.
- Changed GDScript formatting/lint, editor import and `git diff --check`: passed.

Initial verification caught a test watchdog shorter than the expanded suite's total simulated duration, and a test that queried an already-reaped child PID (Godot emitted ECHILD). The harness now allows the full scenario duration and checks cancellation through lifecycle/workspace state plus a process inventory. These were test harness issues; final runs have no GDScript errors or failed assertions. Existing navigation GPU-readback warnings and shutdown-only ObjectDB/resource warnings remain in some runs.

This slice did not rerun the native sanitizer corpus or 200-unit performance benchmark. Desktop export packages, Windows/Linux process launching and novice usability remain unverified. The separate-process launcher is not a web/mobile implementation. UI interaction was verified by runtime input tests; the native computer-use tool could not reliably distinguish the two same-bundle Godot processes.

## Review artifacts

- [Arena result and battlefield](../../../art/skirmish/arena-result-720p.png)
- [Paused test](../../../art/skirmish/arena-paused-720p.png)
- [Result returned to the editor](../../../art/skirmish/arena-return-editor-720p.png)
- [Actual child-window result](../../../art/skirmish/arena-child-result-720p.png)

Next: First Orders tutorial mission and game-state save/load, while retaining the broader faction/map/LLM and performance roadmap.
