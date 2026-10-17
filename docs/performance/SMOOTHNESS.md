# Frame pacing and worker distribution

Measured 2026-10-17 with Godot 4.6 stable, Metal Forward+, Apple M1 Pro.
These results compare the current working tree before and after this follow-up;
they do not include the much larger earlier gain from retiring Lua controllers.

## Rendered performance

The full-resolution stress scene contains 200 mobile units, 80 structures, and
62 resource deposits. Measurements use 1920×1080, 3D scale 1.0, VSync disabled,
30 Hz physics with interpolation, and unrestricted rendering. Each phase runs
for ten simulation seconds after warm-up. Both final runs advance simulation
in real time, move all 200 units, and have 100–105 combatants fire.

| Phase | Before mean | After means (two runs) | Before p95 | After p95 | Frames over 33 ms, before → after |
| --- | ---: | ---: | ---: | ---: | --- |
| Movement | 25.34 ms | 23.19 / 23.20 ms | 34.30 ms | 32.01 / 31.82 ms | 33/396 → 8/432 / 10/432 |
| Combat | 32.03 ms | 28.62 / 28.74 ms | 36.62 ms | 33.56 / 33.74 ms | 105/312 → 22/349 / 23/348 |

Mean frame time improves about 8.5% during movement and 10.5% during combat.
The fraction of combat frames over 33 ms drops from 33.7% to 6.3–6.6%.
Combat p99 improves from 38.06 ms to 35.76 / 35.13 ms. Movement p99 improves
from 37.83 ms to 33.95 / 36.15 ms.

The smaller 70-unit battle is effectively unchanged: 11.91 → 11.96 ms average,
16.63 → 16.50 ms p95, approximately 84 FPS at 2304×1296 actual pixels. Its
30-unit base phase is 9.04 → 9.05 ms. This follow-up primarily benefits larger
armies and reduces long frames; it does not establish a locked 60 FPS at maximum
population. The stress case still averages approximately 43 FPS moving and
35 FPS fighting on this machine. Windows, other GPUs, and release exports have
not been measured. GPU timestamp readings are zero on this backend, so they
cannot be used to infer GPU cost.

### Changes

- Reuse identical scenery box meshes with the same dimensions and material.
  This preserves geometry and shader coordinates while allowing renderer
  instancing. An isolated comparison reduced initial draw calls from 6,099 to
  5,205; scene objects and primitives remained approximately 17,700 and
  1.54 million respectively.
- Bound spatial visibility searches by actual per-tick movement instead of
  an extra twelve-metre ring. Retain live ownership, range, life, construction,
  and line-of-sight checks.
- Reduce temporary allocations and repeated dictionary/property lookups in
  spatial queries, movement contact checks, animation, and minimap updates.
- Avoid unchanged navigation-server property writes, negligible collision
  checks, and occupied-endpoint searches when a unit is too far away to arrive.

No graphics options, simulation frequency, roster sizes, or combat rules were
reduced for these measurements. Raw benchmark rows are in
[smoothness-measurements.json](smoothness-measurements.json).

## Automatic worker distribution

A gather order still anchors a ten-metre field around the selected deposit and
retains its resource type. Each worker chooses a reachable deposit using path
travel time plus a congestion penalty for existing reservations. The penalty is
one full loading cycle per assigned worker, favoring free nearby piles while
allowing a second worker when avoiding a long detour is more useful. The existing
two-worker capacity remains authoritative.

Assignments reserve space while travelling and mining, release it during cargo
return, and reconsider it on the next resource trip or target loss. Workers keep
their current trip stable. Full or temporarily unreachable fields retry after
the existing half-second interval. Active harvesting actions have their own
SceneTree group, replacing repeated scans through every unit in the army.

This is a local travel/congestion heuristic, not a global throughput optimizer.
It preserves partial cargo, delivery rules, pause, save restoration, queued
orders, and the boundary between separate resource fields.

## Verification

`WorkerDistributionRegression.gd` exercises the real gather-order queue for all
three factions and both resource types. Four workers assigned to one pile choose
four nearby piles, retain those assignments through pause/save/load, and each
mine and deliver real cargo. It also checks wrong-type and remote deposits,
unreachable candidates, and recovery when a reachable deposit appears. Against
the original implementation the distribution/save assertions fail in all six
cases (12 failures); the updated implementation passes.

`SpatialQueryRegression.gd` compares indexed visibility and nearby-unit queries
against brute-force live results at positive and negative grid boundaries,
including movement across cells after the index was built, player filters, and
deleted units. Existing navigation, resource-field, cargo, combat, ownership,
graphics, movement, animation, behavior, and garrison regressions are recorded in
[smoothness-verification.json](smoothness-verification.json). Existing shutdown
ObjectDB/resource warnings are recorded separately from script/test errors.

All 14 targeted headless scripts and the six rendered worker cases pass without
script errors. Log review also caught an existing resource-site exception in
legacy spectator matches, which lack the skirmish `finished` property. The guard
now checks for that property; ownership and facility regressions pass afterward.

Reproduce the rendered stress benchmark without `--fixed-fps`:

```sh
godot --path . --script tests/rendered/ScaleFrameBenchmark.gd -- --behaviors --realtime --no-capture
godot --path . --script tests/rendered/BattleFrameBenchmark.gd
```

Run the new regressions and rendered worker captures:

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/SpatialQueryRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/WorkerDistributionRegression.gd
godot --path . --fixed-fps 60 --script tests/rendered/WorkerDistributionPreview.gd
```

The worker preview writes captures under `art/worker-distribution/`.
