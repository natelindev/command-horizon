# Large-battle observation optimization

The observation optimization is effective, but the normal-clock load test still fails the game's 30 FPS/no-backlog target. Earlier fixed-step results measured work throughput and did not establish normal gameplay performance.

## Workload and method

Godot 4.6 editor build, Metal Forward+, Apple M1 Pro, 1920×1080 viewport. The scale scenario runs 200 mobile units (100 per faction), 200 private Lua VMs, 80 structures and 32 resource nodes. Tanks, drones, combat robots, aircraft and repair robots move to assignments and execute legal attacks/repair. HP is elevated to keep the load alive; this is not balance evidence. Camera movement is disabled. No other test workload was run concurrently with the final reference/optimized measurements.

Fixed-step mode renders 600 frames per phase with a forced 1/60 simulation delta. Normal-clock mode measures approximately ten **simulation seconds** per phase with ordinary physics scheduling and records the real duration and number of rendered frames. These are different measurements; their frame times cannot be mixed. The reference query is the pre-change implementation preserved in `ScaleFieldBaseline.gd`, activated only by a benchmark flag. The production game uses the optimized query.

## Results

| Mode / phase | Before mean / p95 (ms) | After mean / p95 (ms) |
| --- | --- | --- |
| Fixed-step movement | 28.88 / 45.15 | 25.05 / 36.49 |
| Fixed-step combat | 34.83 / 55.74 | 26.81 / 38.32 |
| Normal-clock movement | 117.42 / 219.41 | 108.07 / 174.29 |
| Normal-clock combat | 223.48 / 271.29 | 147.89 / 179.00 |

Fixed-step combat p99 improves 62.62→42.71 ms, with 399→70 of 600 frames exceeding 33.33 ms. Normal-clock combat p99 improves 278.77→181.77 ms; every sampled frame still exceeds 33.33 ms. Its reference phase advances 10.07 simulated seconds in 16.98 wall seconds (76 frames); after optimization it advances 10.12 seconds in 11.98 wall seconds (81 frames). This is substantial improvement but unacceptable frame delivery and sustained simulation lag.

All 200 units moved and travelled, all 200 VMs evaluated without faults, and 90–96 units fired in the reported runs. Peak per-VM allocation was about 60 KB. Only 3–13 live projectiles/tracers were sampled; the intended 300-transient-effects load is not covered. These scripts also do not establish large-memory, long-session, input-latency or Windows/Linux performance acceptance.

A separate diagnostic wrapper measured 3,456,072→365,667 `can_observe_point` calls during the combat phase (about 89% fewer). Inclusive `is_observed` duration fell 7.998→1.542 seconds across 600 frames. These nested timings overlap and must not be added; instrumentation itself changes frame cost. The headline comparisons above are uninstrumented runs. [Raw summary](performance-observer-hints.json) retains all measurements, including the initial CLI-profile run and intermediate diagnostic runs.

## Behavior and verification

A bounded per-player table retains a weak reference to the last successful observer. It does not retain a visibility boolean or a negative result. Every use checks current observer ownership and repeats the ordinary live life/construction/range/occlusion predicate. Failed hints fall back to the spatial observer search, which also checks current ownership. Explicit invalidation clears hints; at 512 entries the player table is reset. Hints are not serialized.

Combat regressions change target/observer position, sensor range, observer ownership, observer death, source construction and an enemy building's opacity without advancing a physics frame. They also check an alternate observer, a queued-for-deletion target, shared spotting, direct-fire obstruction, hidden pursuit and real damage. Lua, faction signature, Split Signal and archive restoration regressions exercise callers of the same query. All five suites pass: `CombatRegression.gd`, `LuaProgramRegression.gd`, `SignatureRegression.gd`, `SplitSignalRegression.gd` and `SaveRestoreEdges.gd`. Editor import, changed-code formatting/lint and whitespace checks pass. Existing navigation GPU-readback and shutdown-only resource diagnostics are separate outstanding engine/integration cleanup; they are not presented as passing performance acceptance.

## Reproduction

Use `tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot` from the repository root:

```sh
# Fixed-step reference / optimized (run separately)
Godot --path . --fixed-fps 60 --script tests/headless/ScaleBenchmark.gd -- --lua --baseline-field
Godot --path . --fixed-fps 60 --script tests/headless/ScaleBenchmark.gd -- --lua

# Normal-clock reference / optimized; omit --fixed-fps
Godot --path . --script tests/headless/ScaleBenchmark.gd -- --lua --realtime --baseline-field
Godot --path . --script tests/headless/ScaleBenchmark.gd -- --lua --realtime

# Optional inclusive field timings; not an acceptance measurement
Godot --path . --fixed-fps 60 --script tests/headless/ScaleBenchmark.gd -- --lua --profile-field
```

The next profiling pass must attribute the remaining normal-clock physics, navigation, cosmetic-update and rendering cost. No reduction in supported unit count, Lua cadence, observation correctness or requested animation quality is implied by this optimization.


## Follow-up retained; optimization deferred

User direction on 2026-10-02 moves further optimization to late development and prioritizes the gameplay loop. The completed change uses live X/Z distance to reject out-of-range candidates before full weapon/visibility legality, for idle defense and attack-move. It preserves scene order, per-target shorter AA ranges, current positions and existing final predicates; no position cache, unit-count reduction or animation reduction is introduced.

Two reference and two optimized normal-clock runs (ABBA order) report movement means 130.01/162.40 → 95.31/87.26 ms. Combat means 158.84/163.21 → 165.93/153.18 ms show **no established combat improvement**. All 200 units moved and all VMs ran without faults. The prior diagnostic animation/empty-queue ablations and engine profiler counts are retained with these runs in [raw measurements](performance-target-candidates.json). Those diagnostic switches are test-only.

Candidate regressions cover live movement, exact range boundaries, elevated air targets, shorter AA range, sightless targets, ownership changes, construction occlusion and queued deletion. Existing orders, Lua, weapon-mode and active-shooting archive suites exit successfully; existing shutdown-only resource warnings remain. Reproduce the current reference using `--lua --realtime --baseline-targets`; omit the final flag for the shipping query. Further profiling is deferred.
