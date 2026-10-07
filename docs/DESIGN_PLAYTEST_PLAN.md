# Design review and playtest plan

## Stage 1 — Establish what can be tested

Review the living design and current implementation. Separate the playable Bastion demo, Helix asset viewer, and unimplemented programming systems. Inspect current costs, timings, combat and enemy behavior.

## Stage 2 — Exercise the prototype

Use the running game to inspect selection, orders, economy, production, repair, scouting and combat. Collect a reproducible scenario report for measurable behavior. Review Helix silhouettes and roles, without claiming faction combat tests before integration.

## Stage 3 — Resolve design gaps

Turn observations into a coherent next-slice specification covering resource acquisition, chip progression, direct-order arbitration, faction roles/counters, objectives, enemy fairness, map requirements, program authoring and persistence. Distinguish recommended rules and tuning hypotheses from implemented behavior.

## Stage 4 — Reconcile and validate

Update the living design's stale open questions, document evidence and limitations, and define acceptance gates for the next playable milestone. Check links and any added diagnostic script.

## Agent progress

- Completed: inspected costs, timings, combat, repair, harvesting, victory and AI; separated implemented features from asset/design-only work.
- Completed: native Bastion session exercised paused selection/orders, production, group movement and an enemy-base approach. Recorded paused minimap and group-health gaps; did not claim a full-match or Helix balance test.
- Completed: a 60-second normal-time economy probe measured +20 M / +12 E with two workers; isolated repair updates confirmed provider stacking. Saved raw JSON and the reproducible probe.
- Completed: wrote `CORE_GAMEPLAY_SPEC.md`, updated living design to version 0.3, reconciled superseded open proposals and linked the evidence from README.
- Completed: probe exited with code 0; formatting/lint and whitespace checks pass. Known navigation and shutdown diagnostics are recorded in the review.
- Scope boundary: recommendations are documented, not implemented. Next work is baseline reliability/combat, Helix match integration, then the programmable mission and real faction/user/performance tests.
