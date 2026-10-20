# Pathfinding and order responsiveness

## Findings (baseline, BastionDesert, 14 engineers, 90 s)

Measured with `tests/headless/MiningTrafficRegression.gd` (originally a print-only benchmark).

- Mining: 57 deliveries in 90 s (~22 s per round trip against ~13 s of travel
  and loading). Workers were stalled for 29% of travel ticks, with up to 10
  stalled at once.
- `MovingToUnit` work-face searches ran during ~60% of travel ticks: 127
  episodes, mean ~4 s, p90 ~8 s, max ~12 s. The worker is stopped for the
  whole search (4,867 stopped worker-ticks), so it becomes a "settled blocker"
  that makes nearby searches fail and restart. This feedback loop is the clump.
- Re-ordering a busy worker took up to 74 ticks (2.5 s) to start moving: the
  initial work-face search stops the unit and waits for the shared budget.
- Group orders: the pipeline is ~2 physics ticks (ManualOrders starts the
  action on its next tick; Movement picks it up the tick after). Ground
  right-click orders fire on mouse release, so the click-hold time also counts.
- Group destinations near walls/edges are handed out in selection order, so
  units cross through each other (tank at z=19 sent to z=4 while a tank at
  z=11 went to z=24). Heading formations use a per-unit greedy assignment
  that also crosses.

## Decisions

- Workers on a harvest run (to the pile, collecting, returning cargo) ghost
  through ground units, as in StarCraft II: no RVO avoidance and no body
  clipping in either direction. They collide normally once they stop
  harvesting (waiting for a slot, idle, or any other order).
- Ground right-click orders fire on press. A drag past the threshold revises
  the same order with formation and facing on release, without a second
  acknowledgement or queue entry.

## Stages

1. Measurement harness: `MiningTrafficRegression.gd` with traffic, search
   episodes and order-to-motion latency.
2. Harvest ghosting: `Movement.ghosted` (avoidance layer/mask that ignores
   units but keeps static obstacles; skipped by body contact, exit clearance
   and occupied-endpoint checks), driven by the
   harvest state. `MovingToUnit` ignores ghosts as blockers, skips the
   upfront work-face search for ghosted harvesters, and never stops a unit
   while a search runs.
3. Order latency: `ManualOrders` starts an order synchronously when nothing
   is active. Terrain right-click fires on press; drag revises by token.
4. Group destinations: heading (drag) formations assign slots with a minimum
   total-distance assignment (no crossings) instead of a per-unit greedy pass.
   Plain moves keep their existing slot resolution (see Agent progress).
5. Verification: benchmark before/after, relevant headless regressions,
   update tests that encoded the old non-overlap rule for harvesters, add
   regression checks.

## Agent progress

- [x] Stage 1: benchmark written; baseline recorded above.
- [x] Stage 2: harvest ghosting. 14 engineers: 57 -> ~101 deliveries, stalled
  30% -> 2.6%, search-stopped ticks 4,867 -> 0, busy re-order 74 -> 2 ticks.
- [x] Stage 3: order latency. Group velocity on tick 1 (was 2); open-ground
  median 4 ticks to move toward the goal (was 5-6), max 6 (was 11-13).
- [x] Stage 4: formation slot assignment (Hungarian <= 40, greedy above):
  9-tank drag formation 14 crossings -> 0. Reassigning displaced fallback
  slots for plain moves (map edge / cliff clicks) removed crossings too, but
  exposed a crowd-arrival deadlock in NavigationRegression (one tank stuck
  behind settled tanks at a path corner), so plain moves keep the original
  selection-order fallback. Follow-up: fix that arrival deadlock, then
  reassign displaced slots by intended position.
- Tactical pause keeps orders queued (existing contract); synchronous start
  applies only while unpaused.
- [x] Stage 5: verification. 71 headless tests run against an untouched
  baseline worktree. Now passing that failed before: HarvestTraffic,
  HQTraffic, HQDeliveryRestore (plus the flaky AttackArrivalProgress). New:
  MiningTrafficRegression, GroundOrderResponseRegression. No test that passed
  on baseline fails now. Still failing exactly as on baseline: BaseAccess,
  CornerRecovery, CrowdedDestination, EngineerResponse, HarvestContinuity,
  HQDelivery (speed bound divides by 60 at 30 ticks/s), ResourcePile,
  ResourceMapEconomy (campaign workers never start moving in that fixture),
  SaveRestore, SaveSnapshot, SkirmishLabor and other pre-existing failures.
