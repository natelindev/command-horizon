# Air combat integration — 2026-10-20

Recovered and continued Claude session
`b6e67fd0-0817-47f3-9949-898a5990ee8e`, which stopped during integration.
The air redesign starts at `94ce9a9d`; the integrated main baseline is
`26ebdcd9`. Verification uses Godot 4.6 stable on an Apple M1 Pro.

## Gameplay and save verification

- Physical bullets, shells, rockets, missiles and bombs use real flight and
  collision. The focused regressions cover lead, misses, blockers, splash,
  destroyed shooters, pause, and save/load. Capture relays block rounds without
  being treated as damageable units.
- Fighters taxi, take off, bank, orbit, return, land and rearm. A dragged flight
  order now keeps its translated action active, preserving subsequent queued
  orders.
- Paid production reserves its four stands across save/load. Returning aircraft
  cannot take a promised stand. Destroying an airfield lets its aircraft find
  another runway, discard the old approach, land, rearm and repair.
- Fixed-wing scenes initialize air movement correctly while exposing parked
  aircraft as ground combat targets. Grounded jets obey terrain and forest
  concealment; fog refreshes on takeoff and landing even without horizontal
  movement.
- Every faction's rocket infantry and mobile AA fire physical rounds at
  aircraft. Helicopters expend 12 rockets, return to a helipad, rearm and resume
  their station. Drones remain on Hold Fire until ordered to make a one-way dive.
- Flight saves preserve cooldowns, partially elapsed rearming, a bomb stick
  already in progress, the previous target position for collision sweeps, and
  rounds whose intended target has died. Natural fixed-wing turns beyond a map
  edge remain valid save positions.
- All 810 supported archived snapshots use version 16. Ordered unit, resource
  and player IDs are preserved. Eight historical version-9 Air Corridor
  envelopes remain historical evidence for a removed operation and are not
  accepted by the game. See [save format documentation](../../SAVE_LOAD.md).
- An elevated ground unit can finish settling even when its planar velocity is
  zero. The original all-faction retreat scenario and a dedicated height and
  restore regression exercise this fix.

## AI difficulty

Optional facilities now wait for an adequately funded army. Extra factories
also require funds for current production, and capped armies rebalance workers
instead of retaining an obsolete purchasing split.

The unchanged difficulty assertions pass for all nine faction/difficulty
combinations. Values are Easy / Normal / Hard:

| Faction | Army value at 420 s | Army value at 600 s | Materials mined |
|---|---|---|---|
| Bastion | 244 / 446 / 568 | 244 / 626 / 798 | 749 / 903 / 1141 |
| Helix | 250 / 478 / 588 | 250 / 724 / 820 | 788 / 919 / 1160 |
| Frontier | 225 / 437 / 549 | 225 / 691 / 821 | 776 / 974 / 1205 |

## Controlled role matchups

`tests/headless/AirRoleMatchups.gd` runs eight pairings for each faction on open
ground, with seed 713 and approximately 180 combined materials/electronics per
side. Aircraft have one carried load and no airfield. Ground units and
projectiles remain active. The diagnostic checks that combat actually occurs;
it records outcomes rather than imposing universal faction win rates.

All 24 engagements completed without script errors. Mobile AA destroyed the
opposing fighter, helicopter and drone groups in all three factions; tanks
destroyed unsupported mobile AA. Fighters damaged helicopters without taking
return fire. Helicopters and bombers damaged tanks while remaining out of their
ground-only firing domain. Frontier's reduced aircraft damage is visible in the
remaining tank value.

These are single-sortie measurements, not a multiplayer balance verdict. They
exclude rearm economics, mixed armies, cover, micro, and whole-match production.
Raw costs, survivors weighted by remaining health, duration and round counts
are in [air-role-matchups.json](air-role-matchups.json).

## Integration failures investigated

The broader suite exposed stale fixtures as well as gameplay defects. Failures
were compared with unchanged main before changing their expectations.

- Broken Foundry now measures repair against elapsed simulation time and waits
  for the original production jobs rather than a fixed number of render frames.
- Contact recovery samples actual approach, loading and waiting phases; paused
  action state and timers round-trip exactly, and cancellation preserves the
  cargo actually carried at the time.
- Queue shortcut and mixed-support tests check the immediately started current
  order plus waiting orders. The old tests assumed all orders stayed pending.
- Load-warning coverage checks the current missing-target fallback instead of
  the removed programmable-unit memory warning.
- Environment tests distinguish authored landmark meshes from runtime selection
  rings and use current navigation fixtures without widening tolerances.
- Resource-balance checks sample terrain height and use authored field IDs and
  sector allocations. Wide deposit arcs no longer split into fictitious fields,
  and small permitted route differences do not change the number of allocated
  fields. All stock, route-length and opponent-exposure tolerances are retained.
  The full check passes all 24 registered maps, including the 16 current
  skirmish battlefields.
- Glacier's mirrored boathouses overlapped resource deposits; moving the
  boathouses clears the approaches while retaining resource positions and IDs.
- Polygon structures no longer add a circular avoidance obstacle beyond their
  outline. The original repair-robot approach exposed this mismatch.
- A crowded-movement failure led to a controlled reproduction of recovery
  selecting a roughly 2 cm side step while a 2 m backward escape was available.
  Recovery now ranks clearance from bodies first. The same trapped setup
  reaches its destination within 10 seconds; the regression preserves normal
  speed and separation constraints. This reproduces the failure mechanism,
  rather than claiming an exact replay of the intermittent original crowd.
- HeroTheater operations now select ambient audio from their authored biome.
- The full-visibility objective panel now follows the height of the resource-bar
  stack instead of overlapping the second player's bar. Eight-player and
  spectator resource stacks scroll within the space above the objective and
  minimap. All 62 headless HUD states pass, including keyboard scrolling and
  the original one/two-player plate sizes.

## Headless workload

The 200-unit/80-structure air-combat workload completed with all 200 units moving
and travelling, 99 firing, and 54 simultaneous physical rounds at peak. The final
run recorded mean headless frame times of 11.04 ms for movement and 14.60 ms for
combat; their 95th percentiles were 22.06 and 27.33 ms.

This is a headless simulation check, not a rendered frame-rate measurement.
No rendering speedup is inferred from it.

## Voices and assets

The catalog contains 759 clips, including 96 added fighter, bomber, mobile-AA
and neutral-mercenary clips. All 663 pre-existing audio files retain their
original hashes. All 462 speech clips passed the encoded-audio transcript audit;
451 matched exactly after normalization. The identity audit covers 54 speakers,
with maximum cross-speaker similarity 0.494; every human crew/mercenary voice
matches its own donor reference best. See the
[audio report](../2026-10-11/audio-enhancement/README.md) for methods and limits.

All 11 new aircraft/mobile-AA models were regenerated through their faction
build entrypoints using the shared vertex-weathering bake. Geometry and node
hierarchies remain unchanged. Headless texture contracts and the model
verification pass.

## Verification coverage

The broad run exercised all 236 regression entrypoints present at its start.
197 passed immediately; 39 required investigation or another run, including
incomplete voice imports and interrupted long-running checks. Every initial
nonzero result was subsequently verified clean after the relevant correction.

A final targeted acceptance pass covered 36 flight, projectile, save, recovery,
navigation, texture, audio, localization and interface regressions. The late
crowd-recovery fix adds a regression that fails on unchanged main and passes
with the correction; the original navigation assertions are retained.
Related movement checks were repeated after that change. The nine AI difficulty
cases were also rerun with the complete audio catalog and no script errors.

Accepted runs have no script or parse errors. Existing Godot shutdown
resource/RID cleanup warnings and a dummy-renderer material diagnostic remain.
Negative settings-persistence tests deliberately exercise failed file writes.

## Rendered follow-up

The user subsequently permitted game launches. Final checks use the same Godot
4.6 stable binary with Metal Forward+ on an Apple M1 Pro:

- All three factions repeat `AirOpsPreview` through taxi, takeoff, banking,
  bomb release, approach, rollout and parking. `ProjectilePreview` fires 78
  rounds, reaches seven simultaneous rounds and verifies that pause freezes
  their positions. Reviewed captures are local ignored artifacts under
  `art/air-combat/review/final/` and `art/air-combat/projectiles/`.
- `WeatheringPreview` now captures individual on/off comparisons for all 11 new
  aircraft and mobile-AA models, alongside the existing base/vehicle views.
  All 34 captures pass framing, asset identity and renderer checks. Visual
  review finds no missing geometry, materials or clipped featured models.
- `TerrainLayersPreview` passes on Desert Frontier, Pinebreak Valley, Coastal
  Foundry and Glacier Narrows, including ground-detail controls. This compiles
  the final terrain shader through Metal.
- Glacier initially exposed four navigation edge warnings, also reproduced on
  unchanged main. Server-created navigation maps had not inherited the
  project's merge-raster precision. Applying the configured setting to both
  owned maps removes false edge collisions between the ford's close vertices.
  The engine's effective scale is 0.01, giving a 3 mm ground raster instead of
  3 cm; it clamps the project's requested 0.001. No geometry or route
  tolerances change. The new regression fails three checks on unchanged main
  and passes after the fix, as do terrain, movement, harvest and projection
  checks. All 24 registered maps also repeat the resource/path balance check
  successfully. Glacier's rendered retry has no navigation warnings.
- The full HUD preview covers ordinary selection/production/menu states for
  all factions in English and Chinese. Adding 42 eight-player and spectator
  captures exposed subtitles covering resource readouts. Captions now reserve
  the tall roster's column while retaining normal one/two-player placement.
  All 42 corrected captures pass automated checks and visual review. A further
  four-player harvest fixture covers short/long caption transitions: wrapping
  now refits width while preserving the 8 px roster gap and 12 px right margin.
  All 66 layout states pass both headlessly and with the Metal renderer. The
  harvest fixture waits for animated resource readouts to settle before
  measuring their width, including at uncapped frame rates. Spectator captures
  allow initial visibility updates before pausing instead of capturing
  uninitialized fog.
- `FramePacingRegression` passes all factions, observing 61–63 rendered
  movement updates between physics ticks per 100 samples. Camera input,
  recoil authority and pause assertions also pass.

The three measured aircraft-heavy runs have a median combat p95 of **58.55 ms**,
so the plan's **33.3 ms target remains unmet**. The common roster's mean combat
frame time increases about 15% against main. Raw measurements and method are in
[the performance report](../../performance/AIR_COMBAT.md). Windows, Linux and
packaged release exports remain unverified. Existing exit-time resource/RID
cleanup warnings remain; accepted previews have no shader or script errors.

## Agent progress

- Implementation, archive conversion, audio/model audits and available
  headless verification are complete.
- Integration commit `ebb398ea` was fast-forwarded into local `main`.
- The rendered follow-up closes the Metal, model, flight and HUD review gaps,
  with navigation and subtitle fixes backed by regressions. Performance and
  remaining platform limits are recorded separately.
