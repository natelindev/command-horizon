# Headquarters delivery around an idle starting roster

The bottom-facing starting structures exposed an engineer approach problem: a
reachable, unoccupied headquarters work face could still sit behind a settled
row of mobile units. Choosing the shortest static navmesh path did not account
for those bodies. Sideways avoidance excursions also repeatedly reset the
near-contact progress check, leaving cargo undelivered.

`MovingToUnit` now checks actual mobile-body clearance when choosing a work face.
It chooses a clear approach at the start of a structure-contact order, before
entering a crowded pocket. Structure targets receive preventive work-face planning. Resource deposits keep
their ordinary field approach when that route is clear of settled mobile bodies;
a frozen or idle row can trigger a preventive detour. Workers already moving away
do not trigger that guard. Actual-contact retries still check all current bodies. If every direct approach is blocked, it selects a
reachable outside waypoint with a clear route to an ordinary contact face.
Waypoints cover nearby space and the advanced base's outer formation. Navigation,
RVO, movement speed and the existing ground-body clipping remain authoritative;
contact range is unchanged. Progress checks retain the best endpoint approach so
an avoidance loop cannot indefinitely count as forward progress. The existing
saved movement destination also preserves a waypoint without new save fields.

## Evidence

The isolated pre-fix source failed both standard and advanced expanded Desert
Frontier frozen-roster cases: materials/electronics were not both delivered
within 80 simulated seconds. The working tree remained untouched during that
comparison.

The final regression passed all 54 fixtures: all three factions, the three
expanded maps, standard/advanced starts, and these three cases for each pairing:

- One original human engineer harvests both resources while the other three
  remain idle. Each delivery respects ordinary per-frame movement speed.
- Two additional human engineers harvest around the frozen original mobile
  roster, including infantry and the advanced army. This preserves the original
  failing body geometry rather than removing the blockers.
- The mirrored enemy headquarters repeats the frozen-roster test, including the
  opposite starting-unit layout, for every faction and map.

The original expanded Desert frozen human cases now deliver both resources in
26.8 seconds (standard) and 31.7 seconds (advanced). The advanced Alpine frozen
cases deliver in 31.3/27.2/30.5 seconds for Bastion/Helix/Frontier.

A further six paused mid-waypoint archive roundtrips pass across all factions
and both starts. The actual outside destination, cargo 4, balance and paused
position survive SaveFile write/read and MatchRestore. Contact observation
counters reset rather than importing stale progress; resuming delivers exactly
4 at ordinary movement speed. MatchSnapshot already stores the authoritative
MovingToUnit destination and Movement state, and ActionRestore rebinds movement
completion and headquarters lifetime signals. No additional save fields were
needed.

A final full field sweep exposed an unnecessary initial deposit endpoint change
on the sequential Frontier Alpine route. The settled-body guard above corrects
that scope. All 24 sequential Alpine field cases now pass, and all 54 HQ fixtures
and six paused archive roundtrips were rerun successfully on the final guard.
See [FIELD_APPROACH.md](FIELD_APPROACH.md) for the preserved failing trace.

NavigationRegression, HarvestContinuity and FoundationRecoveryRegression also
pass. Formatting, lint and diff whitespace checks pass. Raw logs and source
hashes are retained in [hq-delivery/summary.json](hq-delivery/summary.json).
Existing engine exit resource-cleanup warnings are retained in the logs.

Run `HQDeliveryRegression.gd` with the local Godot 4.6 executable, `--headless
--fixed-fps 60 --path . --script tests/headless/HQDeliveryRegression.gd`. Its
standard run covers the 36 human fixtures; add `--enemy-only` for the 18 mirrored
fixtures. Optional `--bastion`, `--helix`, `--frontier`, `--smoke`, `--alpine`,
`--advanced` and `--frozen-only` arguments support focused reproduction.
