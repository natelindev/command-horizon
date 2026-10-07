# Keep a stalled arrival check ready

Plain Move and AttackMove no longer restart their two-second arrival observation merely because crowd movement temporarily places the unit outside the existing completion bounds. Once the unit has stopped making meaningful approach progress, arrival stays eligible for checking. Actual progress of at least 0.2 metres toward the reachable endpoint starts a fresh observation. Outward displacement does not replace the previous approach reference, so returning to the same position is not counted as new progress.

Only `source/match/units/actions/Moving.gd` changes in shipping code. AttackMove already uses this shared helper. The existing settled-friendly-unit, short-route, distance and ground-domain requirements remain intact. Active attack combat still clears the observation and retains queued orders. Movement speed, collision/recovery behavior, work contact and save fields are unchanged.

## Captured cause

The preceding turn reproduced intermittent failures in `attack-arrival-audit/late-89136-3.json`. A fresh twenty-replay geometry probe on the preceding shipping code fails **five times** and saves each failed live state. The probe retains every actor and order; player decision loops are disabled while existing movement, combat and work remain live.

One trace shows the infantry about 0.64 metres from a reachable endpoint occupied by a settled ally. At the two-second sample, crowd movement has displaced it to about **0.8456 metres**, just beyond the existing **0.84-metre** completion bound. The old helper immediately restarts the wait and records that farther position. Returning to roughly 0.64 metres then counts as more than 0.2 metres of approach, causing another restart. Legal geometry between those samples is ignored. The unit misses the unchanged six-second deadline even though it repeatedly returns to a valid arrival position.

The final helper caps the elapsed observation at two seconds and keeps checking the original geometry after stalling. It updates the approach reference only after meaningful new progress. This repairs the sampling gap without widening arrival distance or accepting a destination across a long route.

## Save reconstruction

A second issue appeared in the new ready-window test. A restored navigation agent briefly has an empty path before its first navigation update. The first implementation reset the saved observation when it saw that empty path. The trace shows the saved two-second timer becoming zero on the first live frame.

The final implementation preserves the observation while the path rebuilds and returns false until a valid path is available. A controlled boundary test checks an outward displacement, newly legal geometry between samples, and a real disk round trip of the ready state. Pause preserves the exact position, clock, timer and approach reference. After reload and return to legal geometry, the live action settles in **0.033 seconds**, inside the original half-second check. A separate rendered checkpoint captures a genuinely ready window after twelve frames of an earned replay, without fabricating that timer.

The isolated preceding-code project matches every preceding shipping script except the final helper change. It fails **five assertions** in the final window regression: restarting the stalled wait, replacing the approach reference, missing newly legal geometry, failing the expected ready-state round trip and failing prompt live settlement. No script or parse errors occur.

## Verification

The final implementation passes **40/40** replays of the formerly intermittent source archive, with arrivals in approximately **2.08–2.53 seconds** against the unchanged six-second bound. Each of the five newly captured failures also passes three continuations: **15/15**. Speed and location checks remain unchanged. Fourteen previously retained late-state cases pass the existing arrival-progress suite.

Nine relevant headless suites have final passing runs:

- ArrivalWindowRegression
- AttackArrivalProgressRegression and AttackCrowdedArrivalRegression
- CrowdedDestinationRegression and DirectOrdersRegression
- IndustrialPinchRegression and ContactRecoveryRegression
- HarvestTrafficRegression and GuardArrivalRegression

These include queued AttackMove-to-Move handoff before and after disk restoration, real firing without premature arrival, distant-route and enemy-blocker rejection, ordinary Move settlement, manual order authority, actual harvesting/delivery, the recent HQ pinch fix and the earlier captured contact recovery.

Both rendered branches pass at **1280×720, 150% UI scale**. All **five captures** were inspected: two before/after arrival pairs and the intermediate ready-window disk reload. The restored earned branch settles in about 0.383 seconds after its checkpoint; the other rendered branch settles in about 2.017 seconds. Selection and review preserve orders, pending queues, funds and pause. These runners use programmatic selection/pause, not native mouse/keyboard input. The existing HUD remains readable and unobstructed.

Formatting and lint pass for the changed shipping file and three new probe/regression/preview files. Final passing runs have no script or parse errors. Known runtime navigation-readback warnings and shutdown resource/ObjectDB/RID/shader diagnostics remain.

## Retained intermediate evidence

The initial implementation already passed twenty source-archive replays but still lost a ready observation during navigation reconstruction. Its source is retained as `experiment-reset-empty-Moving.gd`. `window-final.log` and `held-trace.log` record that genuine remaining failure. It was fixed in shipping code rather than removed from the final test.

The earliest new fixture also accidentally reused a just-captured late state for the inherited queue test, causing two unrelated queue assertions. The fixture now explicitly restores the queue test's original source archive. Its original source/log remain retained. A temporary one-second investigation bound was reverted to the original half-second bound once the empty-path bug was fixed. No existing behavioral assertion or deadline was weakened.

## Limits and reproduction

This closes the reproduced occupied-arrival sampling and ready-state restoration defects. It does not establish general congestion freedom or stronger full-match strategy. The full harvesting suite passes now, including manual replacement, but the preceding turn's single unreproduced replacement miss has not been independently explained; a passing run is not proof that this fix caused its disappearance. Industrial home defense/programming access and broader content, novice and platform acceptance remain open. Performance remains deferred and the overall gameplay goal stays active.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ArrivalWindowRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/ArrivalRepeatAudit.gd -- --trials=40
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/ArrivalWindowPreview.gd -- --captures=res://tmp/new-arrival-window
```

Use fresh capture names. The [arrival-geometry evidence](arrival-geometry/) retains raw geometry traces, all five failed-state archives, source snapshots, classified results, source fingerprints and SHA256 hashes.
