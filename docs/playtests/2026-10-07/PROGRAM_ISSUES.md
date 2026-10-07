# Find and recover stopped programs

The battle-plan header now shows **Program issues · N** when owned living units have a Blocked or Error program. Selecting it focuses those units and scrolls their program status into view. It remains available when guidance is collapsed, uses the existing styled controls and keyboard focus, and leaves the current urgent advice visible. Reviewing an issue preserves orders, assignments, program state, funds and tactical pause. Reassignment and Resume remain explicit player actions.

Only `source/match/SkirmishPlan.gd` and `source/match/hud/SkirmishPlanPanel.gd` change in shipping code. The count excludes foreign, dead and queued-for-deletion units, and normal Manual, Waiting, Running and Ready programs. Modal dialogs, the program editor and finished matches prevent the selection action. Deferred scrolling checks that the selected program panel still exists and belongs to the same selection.

## Evidence behind the change

The retained paid Industrial trial in `2026-10-06/construction-safety/control6.json` reports three guard assignments obstructed by friendly structures. Its earned `control6-earned-case6-10-infantry_ready.json` archive at 335.233 seconds contains two genuinely Blocked human tanks. Existing assignment recovery already works; the gap is finding stopped programs while other battle-plan advice has priority. This change exposes that state without replacing economy/defense advice or silently restarting programs.

An isolated baseline restores only the two preceding shipping files and runs the final main fixture. It fails three explicit missing-discovery assertions, one for each faction, with no script errors. The retained earned state is also loaded on the final implementation: both blocked tanks are discovered, their authority/state remain unchanged on selection, and a real disk round trip preserves discovery and paused state.

## Verification

Six headless suites pass:

- ProgramIssuesRegression: real blocked guards and Lua errors in all three factions, correct count and filtering, collapsed/expanded discovery, pause and order authority, visible status/reason, explicit reassignment/Resume and subsequent movement, plus earned-state disk continuity.
- ProgramIssuesEdges: queued-unit cleanup, editor/result guards, selection changing during deferred layout, cleared issues and empty activation.
- BattlePlanRegression, DefenseFocusRegression, SupportDiscoveryRegression and BlockedAssignmentRegression: shared advice, focus, support discovery and preset/Lua/visual assignment recovery remain valid. Defense focus retains fourteen focus checks.

The rendered runner passes at **1280×720, 150% UI scale** using the normal fog/visibility path. Eight shortcut activations alternate four mouse clicks and four Enter presses. All three factions use the actual Assign area / route control, a visible map click and Resume, then their recovered guards reach the new assignment. Pause is preserved while editing. These inputs are injected through Godot's GUI event path, not native OS input.

All **eleven accepted captures** were inspected: collapsed, expanded and recovered states for each faction, plus the earned state before and after disk reload. Program status and its reason are inside the selection viewport; the header, battle plan, selection panel and minimap do not overlap. The earned scene retains urgent economy advice alongside the two-issue shortcut. Mixed selections use the existing mixed-program controls; resolving the error fixture with an explicit manual order leaves the blocked guard available for reassignment.

Formatting and lint pass for both shipping files and all three new test files. Accepted runs have zero assertion failures and no script/parse errors. Existing navigation-readback warnings and shutdown resource/ObjectDB/RID/shader diagnostics remain.

## Retained rejected runs

- `initial-regression.log`: a multiline lambda/dictionary fixture failed Godot parsing despite exit zero. The fixture now constructs its authority snapshot with a plain loop; this run is rejected.
- `regression.log`: three fixture failures required a positive scroll offset even when the headless layout already fit the controls. The final assertion checks the actual status/reason bounds against the scroll viewport, with real-size rendered verification.
- `render.log` and `render-*.png`: six failures came from clicking a map destination behind the selection panel. The final runner moves the camera to expose that destination and verifies it is outside the panel before clicking. Only the fixture changed for this correction; `verified-render.log` and `verified-render-*.png` are the accepted results.

The original logs, rejected fixture sources, preceding/final shipping sources, final test sources, classified results, source fingerprints and SHA256 manifest remain in [program-issues](program-issues/).

## Limits and reproduction

The earned combat archive verifies discovery, authority and restoration; complete movement recovery is verified in the controlled all-faction scenarios. This UI improvement does not establish a better full-match outcome, automatically repair assignments, or close the separate 33-second stationary observation. Industrial defense/progression, broader content and novice/platform acceptance remain open. Performance remains deferred and the overall gameplay goal stays active.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ProgramIssuesRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ProgramIssuesEdges.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/ProgramIssuesPreview.gd -- --captures=res://tmp/new-program-issues
```

Use a fresh capture prefix to preserve existing evidence.
