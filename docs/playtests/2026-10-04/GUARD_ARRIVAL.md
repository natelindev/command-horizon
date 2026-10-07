# Guard formation arrival

Ground guards now settle beside a stationary friendly unit at the assigned point, or beside an already settled guard of the same area. This prevents a group from repeatedly pushing every member into the same one-metre center. Arrival remains inside the original circle and requires an unobstructed connection to the neighbor. Enemies, moving allies, aircraft, different assignments and anchors inside owned structures cannot extend a formation. Combat acquisition still takes priority; movement speed, damage, assignment coordinates and manual authority are unchanged.

## Evidence and correction

Five instrumented Coastal Advanced Bastion matches on the previous runtime retain valid navigation paths, stable navigation-map versions and requested versus avoidance velocities before Blocked. Runs 0–2 did not reproduce the problem; runs 3–4 captured seven units before their five-second no-progress timeout. In the first case, `guard-travel-3-0.json`, walker `unit-13` remained around `(19.6, 38.6)` while trying to reach `(18.5, 40)`. A stationary infantry defender occupied the approach beside the command lab and aircraft factory. Requested travel was about 3.2 m/s while avoidance allowed very little movement. The live match subsequently reached Blocked.

[The live-traffic replay before correction](guard-arrival-live-before.log) fails. [The final regression](guard-arrival-verified.log) restores all seven pre-block captures and passes without manually restarting the focal guard. Later snapshots already contain teammates blocked by the previous runtime; those teammates receive explicit Resume, recorded in the log. The fix does not automatically restart saved Blocked programs.

Formation membership is derived from actively watching the current assigned area. Moving, firing or changing the anchor invalidates that membership. It is rebuilt after archive restoration without changing the save format. The shared guard action covers preset, Lua `guard`, and visual Defend assigned area behavior; saved custom movement scripts retain their own behavior. Preset Guard returns from recovery through the same arrival check.

## Verification

- Both factions, eight tanks and an occupied center: preset, Lua and visual guards settle without active movement, preserve their six-metre assignment, survive paused disk restoration, damage an in-area enemy and accept manual departure.
- Both-faction adverse cases reject enemies, moving allies, stale/different assignments, out-of-circle positions, opaque barriers, unfinished buildings and airborne neighbors.
- All [17 shared suites](guard-arrival-checks.json) pass, covering guard targeting, assignment diagnostics, recovery, specialists, programs, orders, Lua/visual rules, squads, combat and restoration.
- [Normal-clock rendered play](guard-arrival-rendered.log) passes at 1280×720 / 150% UI scale for both factions with preset and visual guards. Twelve captures were reviewed: settled, restored and combat states. Selection, program status and the assigned circle remain readable. Examples: [Bastion restored](../../../art/skirmish/guard-arrival-bastion-preset-restored.png), [Helix visual restored](../../../art/skirmish/guard-arrival-helix-visual-restored.png).
- Import, four-file formatting and lint pass. Engine mesh-readback and exit leak warnings remain in logs; script/load errors are checked separately.

The initial frozen-traffic fixture did not reproduce the cause because disabled actors no longer supplied the original physical avoidance. It is excluded from acceptance. Two adverse-case failures used a resource deposit as an opaque barrier, although deposits deliberately allow direct fire; the corrected fixture uses a power plant. A subsequent six-second manual-departure assertion failed once while program mode correctly remained Manual. The final headless check allows up to fifteen seconds and records the actual departure position; all six groups leave the circle. Rendered play passed its original six-second check; its earlier base fixture is retained in `guard-arrival-rendered-base.gd.txt`. These diagnostics remain available rather than being counted as passes.

## Full matches and remaining work

Follow-up: [task-handoff and corner investigation](COORDINATION_HANDOFF.md) fixes a separately reproduced regrouping branch and narrows the corner interference. It does not retrospectively prove the cause of run 1 below.

Four Coastal Advanced matches use the same final runtime and unchanged reference commander, two per faction. All reach terminal outcomes; run 1 fails its AI coordination acceptance check and is retained as a failed check.

| Run | Faction | Result | Duration | Longest stationary travel, human / AI | AI coordination violations |
| --- | --- | --- | --- | --- | --- |
| [0](guard-arrival-match-0.json) | Bastion | Defeat | 6:07.0 | 1.5 / 1.5 s | 0 |
| [1](guard-arrival-match-1.json) | Bastion | Defeat | 9:34.0 | 8.5 / 2.0 s | 3 unassigned attack orders |
| [2](guard-arrival-match-2.json) | Helix | Defeat | 5:25.3 | 1.5 / 2.5 s | 0 |
| [3](guard-arrival-match-3.json) | Helix | Victory | 15:46.5 | 3.5 / 1.5 s | 0 |

Across 4,426 coordinator samples, run 1 records three `unassigned_attack_order` observations. The log does not identify the individual actors or exact frames; a live capture at that condition is the next diagnostic step. The [runner results](guard-arrival-match-execution.json) preserve exit 1 rather than treating a terminal result as a passing match.

The movement probe retains three additional pre-block archives. [Run 1 walker](guard-travel-after-1-0-trace.json) is outside its moving guard assignment, remains Running through the follow-up and later moves toward safety. [Run 3 later tank](guard-travel-after-3-1-trace.json) is also outside its assigned circle and remains Running. [Run 3 opening tank](guard-travel-after-3-0-trace.json), however, reaches Blocked at 42.23 seconds: it is around `(21.27, 37.23)`, with a settled tank around `(18.50, 39.20)`, a repair robot around `(19.63, 37.72)` and infantry/structures around the approach. It cannot use the new arrival rule because no qualifying settled guard is adjacent. This distinct building-corner/traffic case remains unresolved, with its [pre-block archive](guard-travel-after-3-0.json) retained for replay. The general no-progress safeguard remains necessary.

The older regional post-block archives and the uncaptured 9.5-second Industrial delay are not retrospectively declared fixed. This change establishes bounded guard arrival, not general crowd navigation or balance acceptance. Ordinary pacing, strategic variety, first-time-player testing and release gates remain open. Performance optimization stays deferred.

## Reproduction

Run with Godot 4.6 from the repository root:

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/GuardArrivalRegression.gd
godot --path . --script tests/rendered/GuardArrivalPreview.gd
```

The original runtime fingerprint and its two changed-file snapshots are retained under `guard-arrival-before-source.json`, `guard-arrival-PresetAction-before.gd.txt` and `guard-arrival-ProgramLibrary-before.gd.txt`. Only those two shipping files differ. `guard-arrival-final-source.json` records the final source and full policy inheritance chain. Archived probe/runner files reproduce full matches with the prior regional commander, Normal AI and seed 4110; cases 3 and 7 are the two Coastal Advanced factions. Fixed seed values do not make navigation scheduling deterministic. The evidence audit verifies source/artifact hashes, logs and links, while preserving failing full-match checks as unresolved evidence.
