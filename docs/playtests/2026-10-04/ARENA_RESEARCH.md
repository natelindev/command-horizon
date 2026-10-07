# Research-aware program arena — 2026-10-04

## Problem and behavior

The classic technology layer upgraded live units, but the program arena still spawned baseline units. Its outcomes and saved test notes did not identify a research setup. A program tested with different maximum HP, damage or service rates could give a misleading comparison with the player's army.

The editor now captures completed research and Coordination when launching its isolated arena process. The arena defaults to **Completed battle research** and offers **Unupgraded baseline**. Each fresh scenario applies the selected setup before spawning its units. Running tests keep their setup fixed; changing the selection affects the next run. The opposing target retains baseline stats, and the existing free chip access and scripted fixture events remain explicit arena conveniences.

Only the completed research list and Coordination flag cross the process boundary. Current research, exact payment, remaining time, resources, orders and live unit state remain in the paused battle. The private request and response validate the bounded setup and its prerequisites. Returned scenario results must use either the captured setup or the unupgraded baseline. Successful and failed outcomes identify their research, and the editor preserves it in the displayed evidence and saved program test notes.

## Verification

- `arena-research-before-corrected.log`: the corrected fixture against the preserved old arena session fails 16 assertions for missing armor, weapon/service benefits, Coordination and result/restart context. No script errors. The original first attempt also lowered the repair target below its scenario's initial-health reference; that artificial comparison caused extra failures and was corrected before this baseline run.
- `arena-research-accepted.log`: both factions and both baseline/upgraded setups pass actual maximum HP, weapon hits, service healing, manual takeover, ordinary scenario completion, restart evidence and failure context. Invalid IDs, duplicates, prerequisites, types, extra active-research fields and substituted result setups are rejected.
- Shared `ArenaRegression`, `LuaAuthoringRegression`, `VisualRulesRegression` and `TechnologyRegression` pass in `arena-research-<suite>.log`. These cover all seven existing scenarios, intentionally wrong/faulting/stale programs, all-role manual authority, program/library behavior and live technology effects.
- `arena-research-ui-accepted.log`: native 1280×720, 150% interface-scale checks pass Run, mouse Pause, keyboard Resume, expected outcome/trace, keyboard selection of the baseline, restarted base HP and preserved earlier results. Ready, paused, completed and baseline views are retained and reviewed.
- `arena-research-launch-verified.log`: actual editor → child process → editor flow, captured completed upgrades, an independently pending paid armor project, unchanged live funds/research/orders/clock, result labels, saved evidence, stale-draft rejection and child cancellation. Both child and parent captures assert 1280×720.

The standalone input fixture initially injected events into a native window before its mouse-entry state was established and sent embedded-popup keys to the popup viewport. The corrected fixture brings its test window forward, establishes cursor entry, and routes embedded popup keys through normal input dispatch. The first new label was also added twice; that UI construction error was removed. An earlier child capture inherited the previous window dimensions during macOS fullscreen exit; the revised fixture waits for stable windowed state before fixing the verification resolution. Failed intermediate logs remain available and are not accepted as passes. No production input fallback or automatic retry was added to hide those test failures.

Focused format/lint, editor import and whitespace checks pass. Godot's pre-existing navigation mesh readback and shutdown resource/ObjectDB warnings remain. There is no performance claim. The seven fixture scenarios do not establish doctrine-activation tactics, equal-budget combat balance, ordinary match pacing, novice understanding or native Windows acceptance.

## Files and next work

Implementation is in `ArenaResearch`, `ArenaBridge`, `ArenaSession`, `ArenaWindow` and the shared Lua/visual editor. The existing arena session and authoring flows are reused; there is no new game-save schema or external service.

Source hashes and accepted logs are indexed in `arena-research-source.json` and `arena-research-checks.json`. Screenshots are `art/skirmish/arena-research-*.png`, `arena-child-result-720p.png` and `arena-return-editor-720p.png`. This delivers a research-consistent program-testing flow. The broader gameplay/content goal remains active, including representative strategy/pacing and player acceptance, Free Frontier and release/platform work. Performance optimization remains deferred. No commits, publication or persistent agent-instruction changes were made.
