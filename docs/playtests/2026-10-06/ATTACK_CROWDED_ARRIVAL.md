# Crowded AttackMove arrival

AttackMove now completes beside a settled friendly unit occupying its final reachable point, using the same bounded arrival rule as ordinary Move. It preserves active combat and lets queued orders continue. The original earned battle now passes intact headless and native replays. A separate recovery probe confirms that the unresolved army's wounded infantry can heal with existing Barracks service; correcting their reference commander's handoff remains next work.

## Original failure and shipping change

The [engineer reassignment investigation](ENGINEER_REASSIGNMENT.md) retained a sixteen-second stall in `reassigned-2-stationary.json`, infantry `unit-16`. Another settled infantry occupies the reachable endpoint at (18.6, 0, 41.1). Intact replay kept pushing for twenty seconds, while isolated replay arrived within five seconds.

The new capture-only regression fails before the change in all three intact runs: AttackMove remains active and movement retains its destination after six seconds, giving six assertions in `before.log`. Neighboring actors and geometry remain intact; strategic player processes are disabled to isolate existing orders. No actor is frozen or removed for these arrival assertions.

The gap was action-specific. `Moving.gd` already observed two-second intervals, required less than 0.2 m displacement, and asked `Movement.has_occupied_endpoint()` whether a settled friendly mobile unit blocked the nearby end of a short remaining path. AttackMove did not use that rule. The existing observer is now a shared static helper in `Moving.gd`, called by both actions. The navigation, collision, contact-task and endpoint-distance rules are unchanged.

AttackMove resets its observation while actively firing. Combat time therefore cannot be mistaken for stalled travel. Enemy blockers, distant points and endpoints across long detours remain outside the shared friendly-arrival rule. No wider arrival tolerance or teleport is introduced.

`MatchSnapshot.gd` now captures AttackMove's elapsed observation and position origin. `SnapshotSchema.gd` accepts older records without both fields and validates the new pair together, including timer bounds and a valid origin for active observation. Loading remains paused and does not run combat or advance the observation.

## Verification

| Check | Evidence | Outcome |
| --- | --- | --- |
| Original intact archive, three runs | `before.log` | Six expected arrival assertions fail |
| Same archive after fix | `after-initial.log`, `expanded.log` | Arrives in approximately 2.017–4.033 s; displacement stays below 1 m and per-frame steps stay within normal movement speed |
| Queued Move after paused disk restoration | `expanded.log` | Exact observation/position/queue preserved; handoff 1.283 s after restoring a 0.733 s observation |
| Legacy/corrupt AttackMove state | `expanded.log` | Legacy accepted; partial fields, negative/oversized/nonfinite/non-numeric timers rejected |
| Distant occupied point | `expanded.log` | AttackMove remains active |
| Active combat at a crowded endpoint | `expanded.log` | Real firing, 145.5 total fixture damage; original AttackMove and queued Move preserved, observation cleared |
| All-faction structure/dynamic-blocker arrival | `attack-arrival.log` | Bastion, Helix and Frontier pass queued handoff, pause and disk load |
| Existing ordinary Move crowd rules | `crowded-move.log`, `endpoint-tail.log` | Pass captured arrival, distant/enemy exclusions, path bends, long detours, disk queue and corrupt/legacy checks |
| General orders | `orders.log` | Pass both-faction routes, authority, queue cap, pause, fog/target loss and action handoffs |
| Snapshot suite | `snapshot.log` | Pass exact typed state, paid queues/runtime/contact/projectile preservation and corruption rejection, including its 200-mobile fixture |
| Intact twenty-second replay | `intact-replay.log` | WaitingForTargets by the five-second sample and no return to AttackMove during the observation |

All after-change commands exit zero without script/parse errors. Known navigation-readback and renderer/ObjectDB shutdown diagnostics remain in logs. The initial three-run after check preceded the expanded archive/combat scenarios; it is retained separately. `--capture-only` now selects that original regression subset. The original before run used the same three capture checks before additional scenarios were added.

## Native earned battle

`AttackCrowdedArrivalPreview.gd` restores the original stationary archive at 1280×720 / 150% interface scale and normal fog. It selects the original infantry while paused and verifies unchanged clock, position, action, funds and queue. Native Space resumes the live enemy AI and existing battle orders for six seconds. The test reference commander is not reconstructed.

The selected infantry arrives after 2.000 seconds, displaces 0.396 m, and enters WaitingForTargets with no active destination. Selection does not alter the earned state. Both full-resolution captures were reviewed; the busy base, selected soldier and controls remain readable. `native.log` exits zero with zero failures. This verifies the captured gameplay defect, not the completion of the previously unresolved thirty-minute match.

## Conventional infantry recovery diagnosis

`EarnedInfantryRecoveryProbe.gd` loads `reassigned-2-unresolved.json` twice. It disables strategic player processes in both runs while other actors retain normal processing. It does not grant health, resources, positions or new units. This isolates the service handoff rather than replaying a complete strategy.

The four infantry begin at 14.84%, 32.87%, 21.84% and 4.47% health. Their saved orders leave all four at exactly those values after sixty seconds. Issuing the existing `RecoveringAtService` action toward their completed Barracks instead brings all four to 100% over the same interval. Treatment finishes at its normal threshold and the nearby idle soldiers continue receiving ordinary service afterward. The probe exits zero.

This supports a correction to the reference commander's conventional recovery orders. It does not justify buffing healing or faction statistics, nor prove that a revised commander wins the full match. The next step is to preserve conventional treatment through recovery and verify subsequent return to combat from the earned army state and paid matches. The separately observed weak Helix defensive opening remains strategy work.

## Reproduce

Use a fresh capture prefix. Raw logs, before shipping sources and captures are in [attack-crowded-arrival](attack-crowded-arrival/); `SHA256SUMS` records this pass's artifacts and current changed sources.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/AttackCrowdedArrivalRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/EarnedInfantryRecoveryProbe.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/AttackCrowdedArrivalPreview.gd -- --captures=res://tmp/attack-crowd-native
```

The native review requires one Space input. Eight changed GDScript files pass formatting/lint and repository whitespace checks. Broader gameplay, strategy/pacing, environment, novice/platform and release acceptance remain open. Performance optimization stays deferred; the overall goal remains active.
