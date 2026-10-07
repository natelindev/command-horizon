# Mixed-selection roster — 2026-10-04

## Delivered behavior

Mixed own-unit selections now show faction-specific type names and counts, a live damaged total, and individual health percentages/bars beside unit icons. Eight health tiles fit one page; previous/next controls expose the rest without expanding the panel over the battlefield. Type then instance order remains stable while health changes. The 100-mobile/40-structure case has 18 pages and all 17 role counts.

Click or activate a type, health tile or Select damaged to narrow the existing selection. Hold the configured selection modifier to remove those units instead; tooltips reflect remapping. Disabled damaged selection cannot clear a healthy army. Normal single-unit information remains available after narrowing. Mission trucks and rescue VTOLs use text identities because they have no roster icons.

Selection changes only deselect unwanted members. They do not issue commands, alter squads or programs, move the camera, spend resources, cancel production or advance tactical pause. A detached panel cannot issue a stale request. A release that rebuilt its own button is consumed before rebuilding; the menu also discards an abandoned mouse release when a held button disappears after a death.

## Failures and fixes

- [Original information gap](selection-roster-before.log): both faction fixtures failed because the old panel exposed neither type counts nor individual health.
- [Mouse input reproducer](selection-roster-input-diagnostic.log): both type/damaged buttons activated exactly once, but synchronous menu replacement allowed mouse release to reach the battlefield. Both factions ended with an empty selection. Consuming the GUI event before emitting the subset request fixes this; [the diagnostic rerun](selection-roster-input-fixed.log) retains the expected two tanks / one damaged tank.
- [Held-death reproducer](selection-roster-death-diagnostic.log): the dying unit correctly reduced selection from 140 to 139, but releasing its removed tile changed selection to four battlefield units. The menu preserves ownership of that pending release. [The corrected death probe](selection-roster-death-fixed.log) retains all 139 survivors.
- [Interleaved-key reproducer](selection-roster-interleaved-before.log): an early release guard also cleared itself on Enter, so an unrelated key before mouse release revived the fallthrough. The final guard tracks actual roster mouse presses and consumes only that mouse gesture's release. The final rendered test includes the intervening Enter and the next deliberate paging clicks.
- Initial test-fixture errors used a nonexistent player helper, then tried to spawn Bastion campaign vehicles with Helix model substitution. Neither is shipped behavior. The final fixture counts owned units through scene groups and exercises mission-only vehicles with Bastion; it returns below the mobile cap before that separate scenario. Runs containing script errors were rejected even when Godot returned exit 0.

## Verification

[Machine-readable results](selection-roster-final-checks.json) record nine headless suites: SelectionRosterRegression, RosterInfoRegression, OrdersRegression, SquadRegression, ProgramRegression, WeaponModeRegression, SaveRestoreRegression, SubtitleLayoutRegression and CampaignControlsRegression. All pass with exit 0, their passing marker and no script/load error. The release-guard follow-up reruns the focused selection and shared campaign-controls suites plus the rendered workflow; unaffected shared checks are retained. Editor import, format, lint and whitespace checks are also recorded.

SelectionRosterRegression checks both factions, type membership/counts, damaged selection, stable widget identity/order during health updates, one-unit selection, remapping to J, foreign-unit exclusion, empty-damaged disabling, queued movement, active program/action identity, squad membership, paid jobs/resources, camera and pause. An actual disk round trip restores mixed selection, health counts and the paid job. At full own-army capacity it visits every unit exactly once across 18 pages, verifies the four-unit last page and removes a killed unit. The mission-role fixture checks truck and rescue VTOL identities and selection.

SelectionRosterPreview runs the same scenarios through actual Godot mouse/keyboard event dispatch at 1280 × 720 and 150% interface scale. It verifies menu/tile bounds, horizontal fit, type/damaged mouse activation, Enter activation, remapped removal, forward paging, held-click death cleanup with an intervening Enter key and subsequent previous/next mouse input. These are rendered engine-input tests, not physical-device or screen-reader acceptance.

Seven final captures are reviewed:

| Faction | Mixed selection | Full roster | Last page | Mission roles |
| --- | --- | --- | --- | --- |
| Bastion | [Mixed](../../../art/skirmish/selection-roster-bastion-mixed.png) | [140 units](../../../art/skirmish/selection-roster-bastion-full.png) | [137–140](../../../art/skirmish/selection-roster-bastion-last-page.png) | [Truck / VTOL](../../../art/skirmish/selection-roster-bastion-mission.png) |
| Helix | [Mixed](../../../art/skirmish/selection-roster-helix-mixed.png) | [140 units](../../../art/skirmish/selection-roster-helix-full.png) | [137–140](../../../art/skirmish/selection-roster-helix-last-page.png) | Bastion-only campaign roles |

The fixtures deliberately spawn and damage units to isolate control behavior. They are not paid full-match progression, balance or performance benchmarks. The existing navigation readback and shutdown resource warnings remain. Both factions use the fixture's default player color; this is not a faction-color review.

## Reproduction and limits

Run `tests/headless/SelectionRosterRegression.gd` with Godot 4.6 `--headless --path . --fixed-fps 60 --script`; run `tests/rendered/SelectionRosterPreview.gd` with `--path . --script`. The rendered fixture restores options and autosave state on normal completion. A companion verification runner is retained as `selection-roster-verification.py.txt`.

No unit statistics, prices, AI policy or archive schema changed. The prior mixed-force strategy defeats remain unresolved; this slice improves control and visibility and makes no new balance claim. Physical-device and screen-reader testing, broader platform/novice acceptance, remaining content and release acceptance stay open. Performance optimization remains deferred. Overall gameplay development remains active.
