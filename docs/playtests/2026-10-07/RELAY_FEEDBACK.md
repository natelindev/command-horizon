# Relay capture feedback and Split Signal recovery — 2026-10-07

Relays now distinguish advancing capture, active recapture, enemy capture, a contested standstill retained progress while vacant, and friendly armor that needs infantry to change ownership. Split Signal also distinguishes “Recapture in progress” from “Clear contested relays” when fewer than two relays are scoring. The shared skirmish overview retains its ownership line and gives the same status plus a detailed tooltip. View buttons expose the status/help through their accessibility description.

## Reproduced problem and implementation

A relay's `contested` flag describes ownership contention for scoring. It can be true while a sole opposing infantry force is actively recapturing. The old Split Signal row and world label prioritized that flag, hiding real capture progress. The same flag also stays true when friendly armor occupies an enemy-owned point without infantry; that case now says “Infantry needed,” and the uplink asks the player to move infantry to the relay. Vacant partial captures could also disappear behind the old ownership label.

The original shipping code fails five focused checks: active friendly recapture in the mission row and world marker, recapture after a paused disk reload, retained vacant progress and enemy takeover. The fixture first acquires the relay through actual enemy infantry capture, then moves friendly infantry into range, adds/removes a defender, leaves the point vacant and completes recapture through ordinary objective physics. Units are deliberately positioned and their combat processing disabled to isolate this contract; this is separate from the earned battle evidence below.

`CaptureRelay` now shares its original ground-combatant/infantry presence query between objective physics and presentation. Activity is derived from current occupancy, including paused restoration; no new serialized state is needed. The ownership, ten-second capture, three-metre radius, contest, cumulative uplink and response rules are unchanged. Help explains retained progress and current ownership. An advancing friendly recapture does not ask for unnecessary clearance. The armor-only case preserves the contest and retained partial timer, but explains the missing capture unit instead of asking for more combat.

The first implementation queried the battlefield before map initialization finished. Godot returned script errors even though assertions later reported zero failures. That version and its associated runs are rejected. A null-safe initial presence query fixes the issue; accepted logs are checked for script errors, not just process status. A separate initial difficulty-fixture lambda formatting error is also retained and classified.

## Complete encounters and earned recovery

The existing reference commander uses Guard armor, Service area support and periodic ordinary infantry recapture orders. Full encounters exposed a further practical limitation: surviving armor could retreat while enemy ground units continued contesting both relays. Waiting for the uplink did not finish the operation.

| Route | Outcome | Uplink / simulation time |
| --- | --- | --- |
| Story, existing commander | Unfinished; both outer relays contested | 103.27 / 120 s at archived 268.40 s |
| Standard, existing commander | Victory, four responses | 136.52 s |
| Veteran, existing commander | Unfinished; both outer relays contested | 117.45 / 120 s at archived 268.40 s |
| Story, explicit final-response clearance | Victory, six responses | 214.72 s |
| Veteran, fresh repeat with clearance available | Victory, four responses | 136.68 s |
| Shared Split Signal regression with explicit clearance | Victory, six responses | 199.27 s |
| Earned Story archive, explicit clearance | Victory | 37.60 s after loading |
| Earned Veteran archive, clearance alone | Unfinished | 180.50 s after loading; northern relay lost |
| Earned Veteran archive, paid reinforcements and clearance | Victory | 22.98 s after loading |
| Earned Veteran archive, paid force plus explicit retake (headless) | Victory | 25.60 s after loading |
| Veteran, first paid normal-clock branch | Unfinished | 180.20 s after loading |
| Veteran, first explicit-retake normal-clock branch | Unfinished | 180.17 s after loading |
| Veteran, final paid normal-clock branch | Victory | 47.78 s after loading |

The fresh Veteran repeat finished before the helper's six-response activation threshold. Its win cannot be attributed to that helper. These seeded runs still vary with runtime timing and do not establish repeated balance or a causal improvement in win rate.

The clearance helper is test-only. After all six finite responses, while fewer than two relays score, it issues ordinary targeted attacks against currently observed enemies within the public northern/southern capture circles. It never edits health, positions, enemy orders or mission counters. The shared reference regression now includes this explicit tactical response instead of assuming the initial assignments always suffice.

The optional paid recovery queues four infantry, two tanks and one repair robot for **88 materials / 20 electronics** from the battle's existing stockpile. Newly produced units receive ordinary northern attack-move orders; the repair robot receives the shipped Service area preset. The headless victory occurs after three reinforcements have emerged; remaining paid jobs are still queued at victory. Neither the new reference helper nor production is shipping automation.

Original Story and Veteran saves are retained. Recovery verifies exact unit positions/HP and frozen saved time before resuming. Clearance alone also fails to finish the Veteran save in the normal-clock rendered branch, corroborating that the earlier failure is not just a headless assertion. The first paid normal-clock branch also stalled: the northern relay was enemy-owned, all friendly infantry had died, and surviving armor/support could not complete capture. An explicit retake revision still stalled under the same missing-infantry condition. These failures exposed the additional shipping guidance defect described above. The final recovery script permits up to two additional paid infantry only when no friendly infantry survives and the barracks queue is empty; it also issues ordinary recapture orders when an outer relay is lost. The final normal-clock branch wins after 47.78 seconds for the original 88 M / 20 E, with six reinforcements dispatched. Its extra replacement-infantry fallback did not activate, so this does not verify that fallback under combat or establish why this timing-sensitive branch won.

## UI and regression verification

The final focused fixture passes capture, contest, vacancy, armor-only occupation, enemy takeover, completion, paused disk restoration of both row and world marker, and guidance checks. The all-faction Alpine/Industrial relay-overview suite passes, including capture, contest, disk recovery, hidden/public objective status and locator authority. First Orders capture/preset-victory/defeat/progress checks pass. The corrected Split Signal suite passes rules, archives, three-route optional control, finite response budgets, explicit-clearance victory and progress migration.

The seven final 1280×720 captures use 150% interface scaling. View alternates actual viewport mouse and Enter activation while the battle is paused; time and progress remain frozen. Rows/buttons stay within the objective panel, whose bottom is at y=473, above the minimap. The seven states are [recapture](relay-feedback/preview-infantry-recapturing.png), [paused loaded recapture](relay-feedback/preview-infantry-loaded.png), [contested](relay-feedback/preview-infantry-contested.png), [vacant progress](relay-feedback/preview-infantry-vacant.png), [armor-only occupation](relay-feedback/preview-infantry-infantry-needed.png), [secured](relay-feedback/preview-infantry-secured.png) and [enemy capture](relay-feedback/preview-infantry-enemy.png). Earlier `preview` and `preview-final` images are retained as development iterations; the latter revealed the overly broad clearance wording.

The [paused earned battle](relay-feedback/rendered-complete-loaded.png) and [normal-clock victory](relay-feedback/rendered-complete-result.png) bring the final reviewed set to nine captures. The [run index](relay-feedback/run-index.json) classifies all 36 script processes, including rejected initialization/parser attempts and failed commander branches. Thirteen changed/new GDScript files pass format/lint. Shipping scope is four files: CaptureRelay, SplitSignal, SplitSignalHUD and RelayOverview. No balance data, map geometry, enemy budget, archive schema or automatic player command path changed. The evidence folder contains source snapshots/hashes, classified process runs, battle timelines, earned archives, screenshots and logs. Known navigation readback and shutdown resource/ObjectDB/RID diagnostics remain.

Use `tests/headless/RelayFeedbackRegression.gd` with Godot `--headless --fixed-fps 60` for the focused scenario. `tests/playtest/SplitDifficultyMatches.gd` accepts `--difficulty=0/1/2`, optional `--clear-contests` and a fresh `--evidence=res://...` prefix. `SplitClearanceRecovery.gd` accepts an earned `--archive=...`, fresh evidence prefix and optional `--reinforce`. Rendered counterparts run without headless/fixed-fps and refuse capture overwrites.

This proves clearer state feedback and specific viable/recovery routes. It does not establish novice comprehension, repeated strategy balance, full optional-reward combinations, final environment quality or platform acceptance. Performance work remains deferred; the overall development goal stays active.
