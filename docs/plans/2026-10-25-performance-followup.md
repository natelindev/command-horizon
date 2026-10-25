# Performance follow-up

Preserve graphics, animation, weapon timing, collision behavior and the 30 Hz
simulation while removing redundant work. Compare equivalent workloads; do not
claim frame-rate gains from headless correctness tests.

## Stages

1. Cache match group membership with lifecycle invalidation; migrate frequent
   consumers and make the existing avoidance default explicit.
2. Calculate articulated world transforms in parent-indexed worker-owned state,
   pack those values directly, synchronize weapon sockets on demand, and restore
   posed geometry for cloning and ordinary rendering.
3. Extend native spatial queries with live owner masks and contact clipping,
   retaining ordered results, same-tick movement/capture and script fallbacks.
4. Verify numerical/lifecycle equivalence, movement and combat regressions,
   rendered interpolation/cloning, and available performance comparisons.

## Agent progress

- Implemented cached membership snapshots, lifecycle invalidation and hot-path
  consumers; enabled the global avoidance setting.
- Implemented native four-lane contact clipping, live owner bitmasks, portable
  host builds and ordered/numerical equivalence tests.
- Implemented parent-indexed pose jobs, direct array packing, immediate weapon
  sockets and clone/fallback restoration, including research sensor animation.
- Verified native/script poses, deletion callbacks, movement, combat, capture,
  saves, aircraft, shutdown, rendered interpolation and batch lifecycle.
- Compared the original and completed pipelines with the same rendered 280-unit
  fixture. The contact kernel is about twice as fast in isolation; total frame
  time did not materially improve on the available Mac. Keep decoupled poses
  opt-in (`--enable-decoupled-poses`) because they added about 1–2% in the final
  comparison. Windows release performance remains unverified.
- Results and reproduction instructions: `docs/performance/CPU_PIPELINE_FOLLOWUP.md`.
