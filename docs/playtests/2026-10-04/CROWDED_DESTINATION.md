# Crowded Move destinations

A plain ground Move order now finishes beside a stationary friendly unit occupying its final reachable point, once the mover has made less than 0.2 m of progress over two seconds. Completion is limited to the last navigation-path segment and a distance no greater than the two units' combined radii plus 0.2 m. It stops the current Move and permits normal idle behavior or the next queued order.

The rule uses only owned mobile units in the same movement domain. Enemy units, moving allies, distant endpoints and earlier path segments do not authorize this completion. Unit-contact actions retain their own gathering, construction and approach checks. Movement speed, collision avoidance, work range, healing slots/rates and combat rules are unchanged.

## Original failure

The [mixed-operation study](MIXED_OPERATIONS.md) produced a fifteen-minute Bastion match and captured a seventeen-second stationary-travel episode. Injured infantry was moving toward its barracks center. The navigation endpoint was beside the building, but an idle friendly infantry unit occupied that endpoint. The mover kept trying to close the final half metre and could not receive barracks treatment, which requires being stationary.

The exact [battle archive](mixed-operations-responsive-bastion-stall.json), entity `unit-13`, is retained. In [the original thirty-second replay](mixed-operations-recovery-replay.log), it travelled only about 0.007 m during the first fifteen seconds and remained in Move. The [focused before-test](crowded-destination-before.log) fails six assertions across three restorations: movement remains active and HP stays at 3.204. The [original Moving action](crowded-destination-before-Moving.gd.txt) is retained.

## Verification

The focused regression restores the original crowded state three times. Within four seconds the Move finishes near its original position and ordinary healing increases HP from 3.204 to 4.847. Maximum movement per physics step remains within the unit's speed limit. It also verifies:

- A distant destination remains active even when its endpoint is occupied.
- An enemy blocker does not satisfy the friendly-arrival rule.
- A real disk round trip preserves the Move and queued follow-up while paused, without movement or healing.
- After resuming, the first order hands off in about 2.02 seconds. Once the ally clears the narrow exit, the queued Move reaches its own destination normally.

The initial queue fixture left the same infantry blocking the only exit and correctly failed to reach the second destination; [that failure](crowded-destination-edges.log) is retained. The corrected fixture orders the blocker out after the first order hands off. The second route still has to traverse the real navigation mesh; its deadline is unchanged.

[Nineteen accepted checks](crowded-destination-verification.json) cover direct commands, queued orders, ordinary navigation/harvesting/factory exits, action and combat restoration, exact contact approaches, conserved harvesting, reference-policy advance/recovery, Supply Line convoy travel and AI coordination. They also include two complete responsive-commander matches, editor import, formatting, lint and whitespace checks. [The runner](crowded-destination-verify.py.txt) records each process exit and expected result marker. The [original final-run ledger](crowded-destination-final-checks.json) retains two test-line-length lint findings; formatting-only edits resolve them in [the final static ledger](crowded-destination-static-checks.json). No runtime behavior changed after the passing gameplay checks.

[The normal-clock rendered workflow](crowded-destination-preview.log) restores the same archive at 1280×720 / 150%, verifies movement completion and actual HP gain, and captures the unit before and during treatment. Both captures were reviewed. The rendered value changes from 3.204 to 5.081 HP; the HUD rounds up to 4/22 and 6/22.

| Before | Treatment after arrival |
| --- | --- |
| [Blocked final point](../../../art/skirmish/crowded-destination-before.png) | [Healing beside the barracks](../../../art/skirmish/crowded-destination-healing.png) |

The two final complete matches end in victory at 13:04.6 for Bastion and 6:38.0 for Helix. Their longest sampled stationary-travel episodes are 2.0 and 2.5 seconds; this is a bounded final check, not a congestion or balance guarantee.

## Reproduction and limits

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/CrowdedDestinationRegression.gd
godot --path . --script tests/rendered/CrowdedDestinationPreview.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SkirmishTravelReplay.gd -- --archive=res://docs/playtests/2026-10-04/mixed-operations-responsive-bastion-stall.json --unit=unit-13 --seconds=30 --full
```

Godot 4.6 on the development M1 Pro; headless simulation uses 60 fixed steps per second and the rendered workflow uses Metal with the normal clock. The battle archive schema is unchanged; the short arrival observation restarts after restoration. Existing navigation-geometry readback and exit-time shader/resource warnings remain recorded. This fixes the captured plain-Move endpoint case, not every possible congestion pattern. Strategy, wider-map/difficulty and novice pacing, physical-device/platform and release acceptance remain open. Performance optimization remains deferred.
