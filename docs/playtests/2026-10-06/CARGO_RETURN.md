# Explicit engineer cargo delivery — 2026-10-06

Selected engineers now have a **Return cargo** command beside Move. It sends loaded engineers to their nearest completed friendly HQ using the existing delivery action, then waits for the player to choose a resource field. Hold the queue key (Shift by default) to append delivery after a retreat or other order. Enter activates the focused button; Shift+Enter queues it.

Worker-only selections hide the two unusable attack buttons. Mixed selections retain all three combat/movement controls plus Return cargo. Empty engineers and combat units keep their orders. A disabled delivery button explains missing cargo or the need for a completed friendly HQ through its tooltip and accessibility description. Activation rechecks current selection, cargo, HQ availability and modal authority.

This is an explicit delivery convenience. It chooses the nearest HQ by the existing distance rule, does not evaluate route safety, and does not automatically return engineers to a resource field. Cargo, prices, navigation, gathering and archive rules are unchanged.

## Verification

The original command panel fails three missing-control assertions, one per faction, in [minimal-before.log](cargo-return/minimal-before.log). The same test passes after implementation in [minimal-after.log](cargo-return/minimal-after.log). The original production sources and minimal test are retained.

[CargoReturnRegression.gd](../../../tests/headless/CargoReturnRegression.gd) passes all three factions in [final.log](cargo-return/final.log), exit 0 with zero failures and no script errors. It covers:

- Refresh/selection authority, replacement versus queue append, full queues, cancellation of Move targeting only after successful delivery orders, and paused cargo/funds conservation.
- Mixed selections, empty carriers, incomplete or enemy HQ rejection, nearest completed own HQ selection, queued-for-deletion HQ fallback and match-end blocking.
- Shift+Enter and a remapped Ctrl queue key, with no duplicate submission on key repeat or release.
- A disk save during actual delivery movement, paused restoration, arrival through ordinary navigation and an exact 3 M / 1 E deposit.
- No double credit, waiting for reassignment, queued follow-up movement and actual new income after explicit resource-field assignment.

DirectOrdersRegression, ResourceFieldRegression, SelectionRosterRegression and EngineerResponseRegression also exit 0 with zero failures and no script errors. Their logs are retained beside the dedicated checks. Formatting, lint and whitespace checks pass. Existing navigation-readback and headless ObjectDB/renderer cleanup diagnostics remain recorded; these are separate from the assertion and script-error results.

The first expanded fixture preloaded a script before its `Utils` autoload was ready. A second fixture accidentally spawned its purported completed HQ as a foundation; correctly rejecting that HQ produced three failures. Both test revisions/logs are retained. Loading the action after initialization and spawning a completed HQ fixed the fixtures without weakening delivery eligibility.

## Native controls

[CargoReturnPreview.gd](../../../tests/rendered/CargoReturnPreview.gd) exercises controlled 1280×720 fixtures at 150% UI scale. The accepted [native-verified.log](cargo-return/native-verified.log) exits 0 with zero failures and no script errors:

| Faction | Native action | Verified result |
| --- | --- | --- |
| Bastion | Mouse click, then Space | [Exact cargo deposit and waiting state](cargo-return/native-verified-bastion-delivered.png) |
| Helix | Tab, Enter, then Space | [Exact deposit and disabled empty-cargo control](cargo-return/native-verified-helix-delivered.png) |
| Frontier | Tab, Shift+Enter, then Space | [Retreat plus queued delivery](cargo-return/native-verified-frontier-queued.png), then [exact deposit](cargo-return/native-verified-frontier-delivered.png) |

[The mixed-selection capture](cargo-return/native-verified-frontier-mixed.png) confirms all four commands remain within the scrolling panel. Native review covers loaded/queued states, visible keyboard focus and all three delivered states. Other actors are frozen and Coordination/cargo are fixture state; this proves input and delivery behavior, not survival under a live raid or earned progression.

The first native run exposed that modified Enter did not activate the focused button. A second run still failed because physical modifier polling was false even though the incoming key event correctly carried Shift. The retained key probe identifies `Shift+Enter`, `held=false` and a valid accept event. The button now handles modified accept explicitly and reads modifier flags from that event, preserving the player's remapped queue key. The initial run, interim `native-final` run and diagnostic probe were stopped as owned test processes (exit 143); none is accepted completion evidence. The entire three-faction flow then passed. The final source also consolidates the existing key-binding import, with the complete headless suite rerun afterward.

## Roster-audit coverage correction

While checking the same structure fixture API, this pass found that the earlier roster audit spawned its aircraft factory under construction. The updated fixture spawns it completed and requires nonempty purchase buttons for every selected producer. Its first probe flagged Bastion's long aircraft label because the test treated `icon_max_width` as a fixed width. Full-resolution [Bastion evidence](cargo-return/airfield-before-bastion-AircraftFactory.png) shows complete text: Godot shrinks an expanding icon to the available space. The assertion now measures text/padding/separation and remaining icon space, rather than requiring the maximum icon width.

The corrected [rendered roster run](cargo-return/roster-final.log) passes all three factions and all five selected roles, exit 0 with zero failures. Completed-airfield captures for [Bastion](cargo-return/roster-final-bastion-AircraftFactory.png), [Helix](cargo-return/roster-final-helix-AircraftFactory.png) and [Frontier](cargo-return/roster-final-frontier-AircraftFactory.png) were reviewed. No roster tile geometry or text was changed. The earlier fixture and report revisions are preserved with their original manifest digests.

## Reproduction and limits

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/CargoReturnRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/CargoReturnPreview.gd -- --captures=res://tmp/cargo-return/native
```

Use a fresh capture prefix in an existing directory. The native runner requires the indicated inputs and has a five-minute wall deadline. Display preferences are temporary in-memory settings and autosaves are disabled. [Artifact hashes](cargo-return/evidence.json) identify the retained revisions and accepted evidence.

Earlier full-match defeats remain unresolved. This pass does not establish raid survival, faction balance, novice comprehension, all-scale or cross-platform acceptance. Broader gameplay and environment work remains active; performance stays deferred.
