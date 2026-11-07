# Performance audit follow-up

Improve the measured HUD and network hot paths without changing gameplay,
graphics quality, simulation cadence, save format or network hash semantics.
Investigate the reported campaign retention before changing resource lifetimes.

## Stages

1. Reproduce the HUD selection, network capture and campaign teardown diagnostics
   on the available Mac and identify the work responsible for the costs.
2. Remove redundant synchronous HUD work while keeping individual unit state,
   cooldowns, immediate selection feedback and action-time validation correct.
3. Accelerate canonical state hashing, preserving exact hashes and the portable
   fallback. Verify detached worker execution and malformed input handling.
4. Fix confirmed lifecycle defects, run focused regressions and repeat the same
   benchmarks. Record measured gains and remaining frame-budget limitations.

## Agent progress

- Read the supplied audit and current implementations. HUD layouts already retain
  controls, and per-refresh order eligibility is partly shared. The hash currently
  deep-copies, recursively canonicalizes, tags and JSON-serializes every snapshot.
- Reproduced the HUD and network costs on the clean starting revision. Captured
  baseline and final timing data with the same workloads.
- Implemented refresh-scoped presence queries, cheap cargo/health filtering,
  single availability validation per tray member and dirty-only health totals.
  Healthy 200-unit button refreshes are about 25–30% faster; fully wounded refreshes
  remain approximately unchanged because recovery decisions still read each unit.
- Implemented byte-compatible native hashing, a fused portable encoder, bounded
  native scratch data and main-thread backend preparation for worker jobs. Native
  hashing fell from 63.96 to 10.21 ms; combined diagnostic pipeline p50 fell from
  105.30 to 51.47 ms. Hash parity and malformed/concurrent-worker tests pass.
- Investigated 32 sequential campaign loads. Node count returns to 14 each time;
  most memory growth occurs during the first cache warm-up. No reported exit leak
  reproduced, so no speculative production cleanup was introduced.
- Focused gameplay, selection, hash, shutdown, multiplayer and replay checks pass.
  Reviewed all faction HUD captures; two shield-shimmer assertions also reproduce
  on the original revision. Full rendered FPS and Windows runtime remain unverified.
- Evidence, reproduction commands and limitations are recorded in
  `docs/performance/2026-11-07-audit-followup.md` and its companion JSON.
