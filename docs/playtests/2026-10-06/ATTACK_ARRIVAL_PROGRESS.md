# Occupied attack arrival progress — 2026-10-06

Move and AttackMove now measure progress toward their reachable navigation endpoint during the existing two-second arrival observation. Sideways or backward crowd recovery no longer masquerades as forward progress. Completion still requires a nearby settled friendly ground unit occupying that endpoint and a sufficiently short remaining route. Active attack combat retains its order and queued follow-up.

## Evidence and cause

The earlier [HQ traffic audit](HQ_TRAFFIC.md) retained an intermittent six-second attack-arrival miss. Four separate processes replayed the same earned infantry order twelve times each with player decisions disabled, existing actors and unit actions preserved. Seven of 48 orders exceeded six seconds; the slowest settled after 18.17 seconds. All eventually settled within the diagnostic's twenty-second observation; its zero-failure exit does **not** mean the six-second acceptance bound passed.

The [slowest trace](attack-arrival-audit/audit-89136.json) shows the unit moving sideways around the ally at the endpoint. Its distance to that point barely improves, but its displacement repeatedly exceeds the old 0.2 m progress threshold. Recovery can also move it temporarily outside the arrival radius. The old check interprets these excursions as progress and starts another two-second wait. Seven untouched late states were saved at six seconds for independent replay.

The only shipping change is in `Moving.occupied_arrival`, shared by Move and AttackMove: compare the old and current distances to the current path endpoint instead of displacement between observation positions. The existing two-second window, 0.2 m minimum progress, short-route/body-spacing bounds, settled-friendly check and combat exclusion remain. No snapshot fields or movement speed/contact/navmesh rules change.

## Verification

An isolated project using the pre-change `Moving.gd` and otherwise identical shipping sources produces [twelve regression assertions](attack-arrival-audit/baseline-progress.log): two directional-observation failures and five late live orders that each fail arrival and stopped-movement checks. The test directly exercises sideways, approaching and retreating observations against a real synchronized occupied endpoint; its synthetic observation positions are distinct from the untouched live archive replays.

The [fixed regression](attack-arrival-audit/progress-regression.log) passes all three directional checks and fourteen live replays, two per retained late state. Every late order settles in 2.083 seconds after restoration, with less than 0.51 m displacement and steps bounded by ordinary speed. Four further processes replay the original earned state 48 times: every order settles in 2.033 seconds, with no six-second misses. These are bounded repeated observations, not a claim of deterministic crowd behavior in arbitrary battles.

The [existing attack suite](attack-arrival-audit/attack-regression.log) passes three original-state arrivals, paused disk restoration, queued Move handoff, corrupt/legacy observation validation, distant endpoint exclusion and active real weapon damage without losing the attack order or its queue. Handoff takes 1.283 seconds after restoring the partial observation.

Ten additional shared suites pass: CrowdedDestination, EndpointTail, AttackMoveArrival, AirArrival, GuardEndpoint, HQTraffic, HQTrafficFactions, HarvestTraffic, CornerRecovery and SaveRestoreEdges. Together with the two attack suites above, that is twelve passing headless suites. EndpointTail includes a route detour and moving/enemy/air/distant/empty neighbor exclusions; HQ traffic still delivers cargo and all three factions clear the fresh corridor. All final runs exit zero without script/parse errors. Formatting and lint pass. [Shared exit codes](attack-arrival-audit/shared-results.json) and [classified logs](attack-arrival-audit/run-results.json) retain the details.

Known engine diagnostics remain: navigation-readback warnings, shutdown resource/RID/shader messages, and the dummy renderer's null-material message in AirArrival (also present in the preceding HQ traffic run). These are not reported as a clean engine log.

Four [rendered states](attack-arrival-audit/render.log) pass at 1280×720 and 150% interface scale: original before/arrived and the slowest late archive before/arrived. Arrival takes 2.017 / 2.083 seconds respectively. All four captures were visually inspected; selection, paused clock, queue and resources remain intact during review. Selection and resume are programmatic, not native or injected GUI input. See [original before](attack-arrival-audit/render-0-before.png) and [late state arrived](attack-arrival-audit/render-1-arrived.png).

## Limits and reproducibility

This closes the retained sideways-recovery arrival defect. It does not establish general crowd, strategic balance, novice, content or platform acceptance. Home defense and late recovery/production deadlock remain open. No full-match balance claim is made from these focused replays. Performance stays deferred.

The folder retains all baseline and changed-code logs, original six-second snapshots, detailed per-process traces, source snapshots, source fingerprints, classified outcomes and [artifact hashes](attack-arrival-audit/SHA256.json). Existing navigation-readback and shutdown resource/RID diagnostics are recorded separately from assertion and script failures.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/AttackArrivalProgressRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/AttackArrivalAudit.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/AttackArrivalProgressPreview.gd -- --captures=docs/playtests/2026-10-06/attack-arrival-audit/new-review
```

Use a fresh capture prefix to preserve prior evidence. Diagnostic trace filenames include the process ID and reject existing output.
