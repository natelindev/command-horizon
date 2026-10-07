# Blocked assignments and saved guard boundaries

The tank in the retained mixed-operation match had an inaccessible assignment, not a new movement deadlock. Its guard point `(18.5, 0, 34.5)` lies inside the friendly aircraft factory centered at `(18, 0, 33)` with radius 2.3 m. The captured tank at `(19.2635, 0, 36.0483)` reaches the navigation boundary near `(18.7703, 0, 36.1216)`, outside the one-metre guard-point arrival distance. Resume repeats the same failure. The existing five-second no-progress Blocked rule is correct; the reference commander never replaced this assignment.

The [original archive](mixed-operations-allocation-repeat-bastion-stall.json) and [twelve-second resumed trace](blocked-guard-probe.log) retain that evidence. This resolves the specific unexplained route case from [the mixed-operation study](MIXED_OPERATIONS.md), without changing its match outcomes or establishing wider movement/balance acceptance.

## Changes

- A stalled ground program whose assigned point is inside a living friendly structure now says: **“Assigned point is inside a friendly structure. Choose a clear point.”** The diagnostic checks only owned structure footprints and actual anchor/safe/route destinations. Combat approaches, aircraft, enemy structures and dead structures retain ordinary bounded retry feedback. Movement, arrival distances, five-second stall handling and idle defense are unchanged.
- New battle snapshots retain a Lua action's last guard intent, so the selected assignment circle remains visible immediately after loading a blocked guard while paused. Previously this flag defaulted to false and the permanently blocked action never reevaluated it.
- The added `_guarding_area` state field is an optional, strictly boolean compatibility extension to snapshot version 6. Existing archives remain readable. If absent, it defaults to false until the next program evaluation; loading does not execute Lua or invent the missing intent. Existing visual-rule records can independently show their authored guard boundary. New snapshots preserve both true and false values through ordinary action restoration.

## Verification

[Accepted checks and hashes](blocked-assignment-verification.json) cover the following:

| Check | Evidence |
| --- | --- |
| Captured Bastion Lua, built-in and visual guards | Resume reaches Blocked with the specific reason; a paused disk round trip retains the assignment boundary, position and program state; clear reassignment reaches normal guarding; manual Stop retains priority. |
| Fresh Helix equivalents | Actual Helix tank/factory fixtures verify the same three program forms using their native faction properties. |
| Archive behavior | Paused restored Lua checkpoints remain unchanged. Invalid non-boolean flags are rejected; absent legacy flags are accepted. The original pre-extension archive is actually restored in each captured replay. |
| Feedback limits | Real zero-speed no-progress route still blocks; focused diagnostic checks cover unrelated combat destinations, air domain, enemy ownership and destroyed structures. |
| Rendered recovery | Normal-clock Metal, 1280×720 at 150% interface scale; both factions load a blocked guard, show its boundary and specific reason, then accept mouse press/release on Assign area, clear ground and Resume. Selection and paused time remain intact; resumed guards reach the new point. |
| Shared behavior | ProgramRegression, LuaProgramRegression, AuthoredGuardRegression, AuthoredRecoveryRegression, SaveSnapshotRegression, SaveRestoreRegression, SaveRestoreEdges, SaveRestoreCombat and OrdersRegression pass. |
| Static checks | Godot editor import, focused formatting/lint and whitespace checks pass. |

All six rendered captures were visually reviewed for readable feedback and controls. The restored blocked circle is visible around the factory. The assigned point moves with the new order once the Lua guard evaluates again.

| Faction | Loaded Blocked | Queued Resume | Recovered |
| --- | --- | --- | --- |
| Bastion | [Capture](../../../art/skirmish/blocked-assignment-bastion-blocked.png) | [Capture](../../../art/skirmish/blocked-assignment-bastion-ready.png) | [Capture](../../../art/skirmish/blocked-assignment-bastion-recovered.png) |
| Helix | [Capture](../../../art/skirmish/blocked-assignment-helix-blocked.png) | [Capture](../../../art/skirmish/blocked-assignment-helix-ready.png) | [Capture](../../../art/skirmish/blocked-assignment-helix-recovered.png) |

## Retained failures and limits

The [initial regression](blocked-assignment-before.log) reported nine failures: six relevant Bastion diagnostic/boundary failures and three invalid Helix fixture loads. The initial fixture incorrectly changed an archived faction without rebuilding its faction-specific health, weapon and deployment state. The final Helix fixture creates real Helix actors instead. [The first implementation run](blocked-assignment-after.log) cleared the six product failures and retained the three fixture failures; [the corrected fixture run](blocked-assignment-final.log) passed.

[The added edge run](blocked-assignment-edges.log) then found one test-fixture failure: assigning the unit's getter-backed domain did not change its Movement domain. The corrected test temporarily changes the underlying domain only during the synchronous diagnostic check, restores it immediately and passes in [final acceptance](blocked-assignment-acceptance.log). No shipping behavior changed after the first implementation. Original source copies are retained as `blocked-assignment-before-*.gd.txt`.

Known navigation-mesh readback and exit-time RID/ObjectDB/resource/shader warnings remain visible in raw logs. Accepted runs have no script/load errors. Engine-dispatched mouse input and rendered inspection do not substitute for physical-device, screen-reader or novice acceptance. No new full matches were run for these feedback/persistence changes; the earlier cohort remains historical evidence. The reference commander still needs to choose a clear assignment if a future building covers its anchor. Broader strategy/pacing, other content and release acceptance remain open; performance work stays deferred.

## Reproduction

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/BlockedAssignmentRegression.gd
godot --path . --script tests/rendered/BlockedAssignmentPreview.gd
```

The shared runner is retained as [Python source](blocked-assignment-verify.py.txt). The capture probe is retained as [GDScript source](blocked-guard-probe.gd.txt). Tests used the local Godot 4.6 build on the development M1 Pro.
