# Player recovery orders — 2026-10-06

Added **Recover health** for selected wounded mobile units. Each eligible unit receives an ordinary manual order to its nearest completed owned service facility: infantry use Barracks, aircraft use AircraftFactory, and ground machinery/engineers use RepairDepot. The command waits for full health, then continues waiting orders or holds position; the existing optional Auto-resume program setting also works. AI recovery retains its existing 80% threshold.

The button rechecks selection, health and facilities on activation. Healthy units and units without compatible service retain their work. Immediate activation overrides a program; Shift or the remapped queue modifier appends through the existing bounded queue. Mouse, Enter and modified Enter share the same command. Tactical pause, map-target cancellation, full-queue rejection and match-end gates remain effective. The button's tooltip explains service domains and unavailable states. Recovery status reports travel, healing percentage and a blocked-path Skip/reissue option.

## Queue restoration defect found and fixed

A saved armed unit with waiting orders but no current order still has its idle-defense action. Restoration previously assigned that action to `ManualOrders._active` whenever `_engaged` was true. Because idle defense does not complete, the waiting queue never started. Restoration now attaches the action only when a persisted current order exists. The all-faction pending-recovery round trip reproduced six failures before this correction (three tanks never healed and their programs never resumed), then passed after it. Active recovery and its following move also survive an actual disk round trip.

## Verification

| Check | Result | Evidence |
| --- | --- | --- |
| Missing command, original sources | 3 expected failures, one per faction | `recovery-orders/before.log` |
| Recovery controls and live healing | 0 failures, Bastion/Helix/Frontier | `recovery-orders/verified.log` |
| Pending queue restoration, old restore code | 6 expected failures | `recovery-orders/final-regression.log` |
| Existing cargo return | 0 failures | `recovery-orders/cargo.log` |
| Existing direct commands | 0 failures | `recovery-orders/direct.log` |
| Shared order lifecycle | PASS | `recovery-orders/orders.log` |
| Snapshot schema/scale checks | PASS | `recovery-orders/saves.log` |
| Restore edges and actual resume | PASS after restore fix | `recovery-orders/restore-edges.log` |
| Shipping AI recovery | 0 failures | `recovery-orders/ai-recovery.log` |
| Reference infantry recovery policy | 0 failures | `recovery-orders/conventional.log` |
| Native 1080p mouse/Enter/Shift+Enter | 0 failures, all factions heal to full | `recovery-orders/native.log` |
| Native 720p, 150% interface scale | 0 failures, all factions; mixed roster and expanded squad controls inspected | `recovery-orders/native720.log` and ten `native720-*.png` files |
| Formatting and lint | Nine changed/new scripts pass | `recovery-orders/validation.json` |

The focused regression covers immediate and appended recovery, manual/program authority, remapped Ctrl+Enter, repeat/release suppression, queue capacity, healthy mixed members, missing/unfinished/dying facilities, nearest-service choice, pause, spent resources, actual movement and full healing, all three service domains, following orders, program resumption, blocked status/Skip and active target loss. It validates active and pending archives, rejects invalid full-health flags and wrong-domain queued targets, and accepts legacy recovery state without the new optional flag. Legacy actions default to the original 80% behavior.

The final native capture shows Frontier infantry at **19/19 HP**, recovery disabled and **Orders complete · holding position**. All 720p PNGs are exactly 1280×720. The first native pass rendered at 1920×1080 because sizing occurred before scene setup; those captures are retained and are not used as 720p evidence. `Preview1080.gd.txt` preserves that harness version.

Rejected development runs are retained: `fixture-error.log` used an unsupported infantry program fixture; `idle-assertion.log` incorrectly expected Skip to leave no idle-defense action; `fixed-restore.log` preloaded an action before the `Utils` autoload was available. None is counted as successful verification. Successful logs contain no script/parse errors. Some headless runs retain existing navigation GPU-readback warnings and renderer/ObjectDB shutdown leak diagnostics; an exit code alone was not accepted as proof.

## Scope and limits

Nearest means geometric distance to a completed compatible owned facility. The command does not assess enemy danger, reserve service slots, choose a different facility around an unreachable route, or retry blocked movement automatically. A blocked order remains visible until Skip or a new command; losing its facility releases the queue. Healing still uses existing power-scaled, two-slot service rules, including combat suppression. This work does not change faction statistics, service rates, costs or balance, and does not establish broader full-match consistency.

The focused fixtures disable strategic AI and retain ordinary actors/navigation/service processing; the native fixtures also disable strategic decision-making. Earlier paid full-match observations remain separate evidence. Weak defensive openings, broader strategy acceptance and overall gameplay polish remain open. Performance optimization stays deferred.

## Reproduction

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/RecoveryOrdersRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/RecoveryOrdersPreview.gd -- --captures=<fresh-existing-directory>/recovery
```

The native harness requires real input: activate Recover health, then Space for each faction; use Shift+Enter for Frontier's queued case. It restores in-memory display options and has a five-minute deadline. Before-source copies and `SHA256SUMS` are retained in `recovery-orders/`.
