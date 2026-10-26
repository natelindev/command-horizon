# Native crowd runtime: architecture prototypes

The initial full native-4K workload ran about 3 fps; the latest experimental
movement/visibility/surface/rig/unit-state/presentation combination runs about
8–15 fps.
The user revised the target to **60 fps** after pass 26. Historical measurements
below retain their original 120 fps acceptance context. Reaching the current
target requires a different hot-path architecture, with 16.67 ms frames, rather than more local
getter/query optimizations. The goal remains active.

## Evidence

`tests/rendered/RadicalCrowdDiagnostics.gd` performs cumulative ablations on the
same 400-mobile / 160-structure battle and retains its geometry and materials.
The second editor diagnostic completed without engine errors and kept focus.
These disabled-system/frozen measurements cannot establish gameplay FPS.

| Cumulative diagnostic stage | Mean fps |
| --- | ---: |
| Live combat | 2.5 |
| Commander decisions stopped | 2.6 |
| Movement and avoidance stopped | 7.7 |
| Unit actions/traits and commander support stopped | 24.2 |
| Match processing stopped, poses still evaluated | 33.5 |
| Pose evaluation/uploads stopped too | 150.2 |
| HUD hidden and auxiliary viewport redraw stopped | 160.9 |
| Frozen nighttime world | 160.9 |

The frozen world costs about 4.3 ms of GPU time at 3840×2160. Its p95 frame time
is still around 12–14 ms. Some children explicitly process ALWAYS, so disabling
the match parent alone does not freeze every script. This diagnostic records
the remaining active script nodes. The stages interact and change catch-up
behavior; their frame-time differences are not independent subsystem timings.

The important conclusion is that commander strategy is currently a small part
of this overload. Movement, per-unit gameplay work and CPU posing require bulk
replacement. The existing renderer can draw the full art above 120 mean fps in
the frozen diagnostic, but CPU tails still need work.

## The order of attack

1. Replace the per-unit script runtime on the common movement/perception paths
   with a resident native unit-data core. This is the largest architectural
   change, and the highest priority. Porting individual arithmetic helpers while
   retaining repeated object property traffic is insufficient.
2. Share route work for units with the same destination: formation/squad routes
   and cached flow-field tiles, with a local spatial grid for contact/steering.
   Keep specialized air, platform and garrison transitions explicit. Benchmark
   route-query cost after step 1 before selecting the routing replacement.
3. Keep articulation state and pose palettes native or on the GPU. Separate root
   interpolation from articulation; materialize CPU sockets only for actual shots.
4. Publish one world snapshot to visibility, minimap and overlays. Make UI totals
   event-driven. These systems must stop rediscovering the same facts through
   independent node walks.

These changes are intended to remove whole classes of work. Their gains have not
been measured and must not be multiplied together into a promised 40–60x speedup.
The current target is a 16.67 ms frame; subsystem budgets below are go/no-go criteria for
the prototypes, rather than predictions.

## Prototype 1: a native unit-data core

- Store hot unit state in contiguous arrays indexed by stable runtime handles:
  position/orientation, velocity, radius/domain, team, derived combat facts,
  command and current target. Avoid dictionary and SceneTree property traversal
  inside candidate loops.
- Run movement/contact and perception batches once per existing 30 Hz simulation
  tick. Keep collision ordering, terrain projection, garrison rules and immediate
  firing validation explicit. Use the existing native NavigationServer until
  measurements justify replacing routing itself.
- Keep nodes as selection/event/save facades; publish transforms in batches and
  emit meaningful changes. High-level commander code can continue issuing orders.
- Feed dirty stat/ownership/ability changes into the native state. No silent
  cross-tick combat cache or delayed weapon authority.
- Introduce behind an experimental command-line flag. First prove native/script
  trajectory, contact, target and saved-state parity, then measure live 4K combat.

Provisional CPU budget: at most 3 ms for a complete simulation tick, including
movement and perception. Shared formation routes/flow fields are a later option
if routing remains costly after removing per-agent script overhead.

### First movement implementation boundary

Use the public GDExtension ABI already built by this project. One match-owned
native runtime owns stable slot/generation handles and contiguous movement state.
Unit nodes retain their existing identity, orders and event interface.

- Bind each ordinary terrain NavigationAgent once: unit/agent object IDs,
  navigation RID, radius, initial command state and rotation-filter history.
- Replace its two script hot loops (`_physics_process` and
  `_on_velocity_computed`) together. The manager supplies one batch step; the
  existing `velocity_computed` signal can call a native registered method with a
  bound stable handle, avoiding custom/private engine callbacks.
- Retain NavigationServer routing and avoidance initially. Cache authored
  triangle/height data in the runtime, validate triangle hints in native code,
  and use server projection only when the hint fails. Keep live sequential body
  positions in a native spatial grid; publish one root transform per moved unit.
- Commands, ownership, ability/suppression/stat changes, teleports and rebakes
  explicitly dirty inputs. Do not cache arbitrary script getters across ticks
  without these invalidations. Platform and garrison transitions either have an
  exact native implementation or remain on the existing path until covered.
- Preserve saved IDs, command revisions, recovery state and current snapshot
  version. The initial compatibility bridge mirrors the existing public
  movement fields; later replace unnecessary per-tick field copies with an
  explicit capture/restore bridge once measurements justify it.

Start behind `--native-crowd-runtime`, with fallback for unsupported movement
types. Compare trajectories, occupied arrivals, recovery, rebakes, narrow
passages, platforms, garrisons and save/restore before the complete 4K benchmark.

### Implemented movement prototype

`source/match/NativeCrowdRuntime.gd` and `native/pose_packer/crowd_runtime.h` now
implement the experimental ground runtime. It retains routing/RVO in Godot and
replaces both script hot loops with a native batch and native signal handler.
Slots have generation-checked handles; native cell-ordered body arrays, polygon
data/hints and an owned height lattice serve the inner loops. Only moved unit
roots are published. Ground projection, sliding, recovery, vehicle acceleration,
occupied endpoints, platforms, facing and passive movement remain covered.
Aircraft retain their existing specialized movement.

The facade bridge still samples source speed/command facts and mirrors public
movement state for existing actions and serialization. It does not yet replace
perception or remove unit nodes. Ownership re-entry reconnects native callbacks;
base-speed, ghost and ability changes refresh contact facts. Projection indexing
is invalidated for pending rebakes and checked against server publication.

Verification so far: 750 complete steering/contact comparisons against the
existing script; 21,600 native projection comparisons across flat/elevated,
pending and rebaked maps; explicit paused/garrisoned callbacks and stale handles;
native-enabled obstacle/group navigation, alpine grounding, platform alignment,
crowd recovery, abilities, garrison exits, archived contact approaches,
save/resume and mixed-army advances/retreats. These are correctness checks using
fixed simulation delivery, not FPS measurements. The production benchmark now
rejects a requested runtime that did not activate/execute. The full native-4K
production results follow; the prototype remains off by default.

The first same-executable production comparison is complete at native 4K with
400 mobile units / 160 structures, live AI, real combat and all five phases.
Both runs are valid with zero runtime errors. The runtime handles 360 ground
movers; the 40 aircraft retain their specialized script implementation.

| Phase | Control fps | Native movement fps | Change |
| --- | ---: | ---: | ---: |
| Day movement | 3.10 | 4.70 | +52% |
| Day combat | 3.07 | 3.42 | +11% |
| Night combat | 2.81 | 3.24 | +15% |
| Night base | 3.22 | 4.32 | +34% |
| Cycling weather combat | 2.91 | 3.50 | +20% |

Native p95 frames remain 329–483 ms and simulation/wall ratios 0.86–0.97.
This is a useful architectural gain, far short of the 120 fps/8.33 ms/real-time
requirements. Retain the prototype for further work; next prioritize complete
native perception and pose/presentation state. Detailed values and executable
identity: `docs/playtests/2026-10-26/2v2-performance/native-crowd-experiment.json`.
The later deferred ability-hook fix for newly produced units is not in this
measured executable and needs the next export/measurement.
That fix passes the native-enabled ability regression. Rendered frame pacing,
catch-up and muzzle checks also pass across all three factions with the ground
runtime enabled. The save regression emits the same eight-resource cleanup
diagnostic with the runtime both enabled and disabled; its gameplay assertions
and process exits pass. This does not establish that the cleanup issue is fixed.

Mobile Geometry roots already use `top_level = true` in the existing
`BastionVisuals.gd`. Do not introduce a redundant independent-model-root flag;
further posing work must target the remaining script coordination, articulation
and palette traffic.

### Native visibility and obstruction prototype

`native/pose_packer/visibility_runtime.h` adds an opt-in
`CopperfinVisibilityRuntime`, selected with `--native-visibility-runtime`.
It moves observer-cell traversal, successful-witness revalidation, footprint
closest-point geometry, terrain/high-ground rules and cylinder obstruction loops
into native code. Native blockers retain geometry until the existing topology
invalidation; health, construction, ownership, garrisons, aircraft state, ranges
and terrain arrays are read live. The existing script path remains the oracle
and fallback. This is still an adapter around unit objects, not the resident
packed combat-data core described above.

`NativeVisibilityRegression.gd` compares 19,200 complete native/script queries
over plateau/ramp/forest/formation locations, mobile/footprinted structures,
parked/airborne aircraft, a generic vision source, neutral radius bonuses and
same-tick life/ownership/range/construction changes. All comparisons pass.
Terrain sight, combat, anti-air priority, weapon modes, projectile physics,
garrison combat/exits and authored garrisons also pass with both native backends.
Visibility-refresh and spatial-query regressions pass as well. These fixed-frame
functional checks do not measure FPS.

Pass 17 uses the same release executable for both runs, with native ground
movement enabled in both. The candidate ran first. Both full native-4K fixtures
are valid, exit normally, retain 400 mobile / 160 structures and report no engine
errors. This is one paired experiment, not a statistical confidence interval.

| Phase | Native movement control fps | Plus native visibility fps | Change |
| --- | ---: | ---: | ---: |
| Day movement | 4.78 | 4.70 | -1.7% |
| Day combat | 3.52 | 4.02 | +14.2% |
| Night combat | 3.15 | 3.60 | +14.1% |
| Night base | 4.40 | 4.92 | +11.9% |
| Cycling weather combat | 3.55 | 3.82 | +7.6% |

The candidate executes 226,554 observed queries, 585,336 point queries and
224,131 obstruction queries across the run. P95 frames remain 344–419 ms;
real-time ratios are 0.926–0.997. It remains experimental and off by default.
Detailed values and build identity are in
`docs/playtests/2026-10-26/2v2-performance/native-visibility-experiment.json`.
The later generic-observer registry assertion extends the test only; it does
not change the measured game code.

The next step needs to remove the object boundary itself: resident movement and
combat facts with explicit dirty updates, and articulation state that writes
directly into the pose palette. Merely moving more arithmetic behind calls that
sample and mirror script properties is not enough for the remaining 25–33x gap.

### Live timing evidence and the next navigation boundary

Pass 18 adds optional monotonic elapsed scopes to native movement/visibility and
the pose coordinator. The complete rendered production workload passes with
400 mobile units / 160 structures, native 4K, live AI, zero engine errors and
normal process exit. FPS is 4.77 / 3.96 / 3.43 / 5.07 / 4.13 with profiling enabled;
this is timing evidence, not an optimization gain or an achieved FPS target.

The native movement boundary costs approximately 52–76 ms per displayed frame.
Its server-projection child scope alone costs **29–43 ms/frame**, over thousands
of fallback queries in each eight-second phase. Pose stages cost approximately
15–32 ms/frame. Infantry solver math is only about 0–2 ms/frame; porting more
isolated gait arithmetic is therefore lower priority than resident state and
publication. Considerable wall time remains unattributed, including engine work
and waits. GPU timings remain around 55–57 ms in combat; the earlier frozen
diagnostic must not be treated as proof that live GPU work already meets 8.33 ms.

See `docs/playtests/2026-10-26/2v2-performance/runtime-profile-summary.json`.
The summary keeps nested projection time separate and never adds it twice.

The live debug function diagnostic also completes with zero runtime errors.
Compiler warnings are recorded separately. The first run was rejected because
the logger classified warnings as errors; it remains archived as rejected.
The second run is valid diagnostic evidence. Sampled game-function self time
identifies repeated speed, ownership and combat-fact reads, outcome checks,
exploration and AI queries. Test coroutines and accumulated coroutine times are
excluded: their frame waits make them unsuitable for ranking gameplay work.
This diagnostic is explicitly excluded from production FPS qualification.
The engine implementation confirms that GDScript function profiling is a debug
facility, while the local debugger emits sampled and accumulated records:
[GDScript profiler](https://github.com/godotengine/godot/blob/4.7-stable/modules/gdscript/gdscript.cpp),
[local debugger](https://github.com/godotengine/godot/blob/4.7-stable/core/debugger/local_debugger.cpp).

Batch metadata in this diagnostic shows 560 registered units sharing 88 model
meshes, 265 active spatial groups, 133 groups with multiple instances and a
largest group of eight. Batching is operating; a claim that every unit has a
unique mesh would be incorrect. Draw calls, material grouping and dynamic
shadow/presentation costs still warrant measurement.

The next concrete prototype should replace global nearest-surface scans with a
native hierarchy over the **complete published convex navigation polygons**.
The existing horizontal/slope containment fast paths stay intact. Snapshot the
current region's world-space vertices/polygons only after synchronization and
associate the hierarchy with its map iteration; pending/stale rebakes must use
the server. Include every polygon, not only the filtered projection cells.

Godot 4.7's closest-point query visits convex polygons in order and projects onto
their planes/edges; it does not simply find the nearest triangulated face:
[navigation query implementation](https://github.com/godotengine/godot/blob/4.7-stable/modules/navigation_3d/3d/nav_mesh_queries_3d.cpp).
Preserve polygon winding, order/ties, plane/edge float behavior and near-zero
interior handling. Bounds must remain conservative for slightly nonplanar
polygons, including projected corners. Unsupported map/region configurations
fall back to the server. Compare against current script/server behavior across
all maps, boundary/hole/plateau/ramp points, rebakes, platform exits, crowd
recovery and save restoration, then measure a same-executable production pair.
Do not replace this with an approximate height-map snap or implement flow fields
before addressing the measured nearest-surface cost.

### Implemented native nearest-surface hierarchy

`native/pose_packer/navigation_surface.h` now owns world-space convex polygon
data, cached normals and a spatial hierarchy. It keeps original polygon order
for ties and rechecks the near-point candidates in that order for the server's
near-zero interior exit. Bounds include raw edges and projected corners. Queries
allocate no engine arrays and do not traverse script objects.

The ground runtime uses this snapshot after its existing containment shortcuts
when `--native-nearest-surface` is requested. `NativeCrowdRuntime.gd` only builds
it from a synchronized, single-region terrain map and ties it to publication
iteration. Pending/stale geometry and unsupported layouts retain server queries.
Direct `project_point` calls also check the current map iteration. Failed
replacement clears the old snapshot. The prototype remains off by default.

Correctness evidence:

- **57,672 direct server comparisons across all 24 maps**, with containment
  shortcuts absent, a 0.0001 m tolerance and finite results required. Includes
  vertices/edges, near-zero plane points, owned input mutation, unpublished
  queries and failed replacement fallback. The native hierarchy executes 57,624
  queries; the intentionally unavailable/failed cases use the server. Polygon
  tests are substantially pruned on every map.
- The combined projection path passes 21,600 native/script cases, including
  pending and completed rebakes. Complete native steering/contact comparisons
  pass for 750 cases with the new surface backend.
- Native-enabled navigation (with explicit activation/execution assertions),
  grounding, platform height alignment, crowd recovery, abilities, garrison
  exits, archived contact approaches, save/restore and mixed-army routes pass
  their gameplay assertions. The height/save tests retain four/eight-resource
  shutdown diagnostics; the four-resource diagnostic also reproduces without
  this new surface backend. These cleanup issues are not claimed fixed.
- Rendered frame-pacing, catch-up and muzzle tests pass for all three factions.
  These fixed-frame checks establish behavior, not gameplay FPS.

Pass 19 compares the same release executable with native movement, native
visibility and profiling in both runs. The control ran first. Both complete
native-4K workloads are valid, retain 400 mobile / 160 structures and live AI,
exit normally and report zero engine errors or warnings.

| Phase | Control fps | Native surface fps | Change |
| --- | ---: | ---: | ---: |
| Day movement | 4.67 | 7.29 | +56.0% |
| Day combat | 3.77 | 5.32 | +41.3% |
| Night combat | 3.42 | 5.04 | +47.1% |
| Night base | 5.20 | 9.61 | +84.8% |
| Cycling weather combat | 3.83 | 7.09 | +85.2% |

The native snapshot contains 4,976 polygons in the dense fixture. All fallback
projections during measured intervals use the hierarchy, with zero server
projection calls. That scope falls from 28–41 ms/frame in the control to
**0.18–0.30 ms/frame**, about 1.6–1.7 microseconds per native query. Overall
movement scopes fall from 53–76 to 14–26 ms/frame, partly because improved FPS
also reduces catch-up ticks per displayed frame. This is one paired experiment;
the overall gains must not be presented as a statistical confidence interval.

Candidate p95 frames remain **211–354 ms**, simulation/wall ratios 0.975–1.013,
and FPS **5.0–9.6**. The 120 fps goal remains active and unmet. Detailed build
identity and phase/cost data are in
`docs/playtests/2026-10-26/2v2-performance/native-surface-experiment.json`, with
the independent oracle report in `native-surface-correctness.json`.

Next, instrument complete scene physics/process phases so that remaining engine
work and waits are not confused with script-function self time. Considerable
wall time is still outside current scopes. Posing still costs 14–28 ms/frame in
this candidate; a resident native articulated rig is a concrete next boundary:
contiguous local/parent/world transforms, native part views in place of script
transform proxies, direct palette output and CPU sockets materialized on demand.
This would remove scene articulation updates and proxy/property traffic together,
rather than porting more isolated gait math. Preserve reflected/scaled rigs,
tracks, all faction motions, hit pulses, paused/catch-up frames, sockets and
explicit geometry materialization for cloning/wrecks. Measure the complete game
after behavioral and visual parity; no expected speedup is an achieved result.

### Complete callback and CPU accounting

Pass 20 adds begin/end probes around the SceneTree physics/process callback
dispatches and Windows process/main-thread CPU accounting. The complete live
release workload is valid, exits normally and reports zero engine errors.
Frames still take 101–195 ms; main-thread CPU consumes 100–190 ms per frame.
Physics callback dispatch spans 43–89 ms/frame and process dispatch 34–64 ms.
Roughly 24–46 ms remains outside those dispatch spans. This confirms that CPU
execution dominates the current frame, including engine work outside callbacks;
it does not infer CPU utilization from elapsed timers or thread cycle counts.
Process CPU includes other threads and can exceed elapsed wall time. Timing
granularity makes short individual thread-CPU spans approximate.

The raw report is `pass20-phase-profile.json`; normalized fine/aggregate scopes
and CPU samples are in `phase-profile-summary.json` in the performance archive.
The largest remaining structural boundaries are resident unit facts, bulk pose
coordination and repeated gameplay scans. Live GPU times still exceed 8.33 ms
in combat; the frozen-scene result is not proof of a sufficient live GPU budget.

### Resident articulated rig implementation

The opt-in `--native-pose-rigs` prototype owns parent-indexed local/world arrays
and dirty revisions per rig. Native part views expose the existing transform
interface; views retain the rig while the rig holds only weak view identities.
The existing gait/turret/worker code writes these views, with no per-joint
SceneTree publication. Disjoint worker jobs resolve worlds, and the palette
packer reads native worlds directly rather than building Variant transform
arrays. CPU muzzle transforms and explicit wreck/fog clone materialization keep
the current interface. This is a bridge to bulk native animation state, not yet
that complete solver: script animation and property crossings remain.

An 800-step independent hierarchy/local-transform/reflection/lifetime/direct-pack
regression passes, followed by all-faction, 15-role direct scene-pose/socket
comparisons. Rendered checks and complete production A/B measurement are required
before any performance claim or default activation.

Pass 21 is now complete: one release executable, both runs using native movement,
visibility, nearest surface and profiling; the candidate adds native rigs.
Both full native-4K workloads are valid, with normal exits and zero engine
errors/warnings. All 560 units use resident rigs and native direct packing.

| Phase | Control fps | Resident rigs fps | Change |
| --- | ---: | ---: | ---: |
| Day movement | 7.04 | 8.02 | +14.0% |
| Day combat | 5.77 | 6.07 | +5.1% |
| Night combat | 5.11 | 5.56 | +8.7% |
| Night base | 9.92 | 10.96 | +10.4% |
| Cycling weather combat | 6.77 | 7.91 | +16.8% |

P95 remains 179–345 ms. This is useful but modest, and still far from 120 fps.
The gait kernel and publication become cheaper, while the upload/coordinator
boundary remains 5–6 ms/frame and script finish/prepare work remains substantial.
The complete pair and identity are in `native-rig-experiment.json`, with normalized
scopes in `native-rig-profile-summary.json`. Rendered material/bounds/cloning and
interpolation/catch-up/pause/socket regressions pass for all factions.

An additional geometry-parking idea was inspected and discarded: mobile models
already have transform inheritance disabled in `BastionVisuals._ready`. Repeating
that switch cannot remove the remaining work and is not a separate optimization.

### Owner/type indexes for repeated roster queries

The next opt-in `--indexed-player-rosters` experiment retains stable membership
and immutable Unit roles, rebuilding only on child membership/order changes.
Completion, queued deletion, ownership, generic mutable roles and Helix power
overdrive remain live reads. Headquarters survival checks can skip an army scan
when a completed live headquarters already proves that a unit remains. This is
one concrete part of publishing shared world facts rather than rediscovering
them; it is not yet the full native unit-data core. All-faction mutation/parity
and commander elimination checks pass. Production measurements below determine
whether this is worth adopting.

Pass 22 adds a full production pair plus a repeat control because the first
night-base control was anomalously slow. All three workloads are valid, retain
the full population and exit normally with zero engine errors/warnings. The
candidate actually executes indexed queries during every measured phase.

| Phase | Initial control fps | Candidate fps | Repeat control fps |
| --- | ---: | ---: | ---: |
| Day movement | 7.56 | 8.96 | 8.06 |
| Day combat | 5.72 | 6.22 | 5.80 |
| Night combat | 5.20 | 5.59 | 5.43 |
| Night base | 4.95 | 9.59 | 10.19 |
| Cycling weather combat | 6.31 | 7.13 | 7.77 |

The apparent 94% base-view gain in the first pair does **not** survive the repeat.
There is no established overall gain: movement and early combat look modestly
better, while the base/cycling result overlaps or trails the repeat control.
This remains an experiment, off by default, rather than an adopted solution.
The reports and both comparisons are archived as `pass22-*.json` and
`indexed-roster-*-experiment.json`. All-faction roster mutation, commander
elimination, technology AI, production batches, build readiness and Helix support
regressions pass with the prototype. Subsequent source cleanup removes extra
parent/deletion checks from the disabled/default path; that cleanup is not in
the measured executable and makes no additional speed claim.

## Next vertical slice: resident authoritative unit facts

Implement a match-owned native unit store with stable generation handles and
compact state, using the same public-ABI/lifetime discipline as the resident
rigs. Unit nodes keep their current order, selection, signal and save interfaces.
The native store must become authoritative for ported scalar facts rather than
copying the entire object graph into an adapter every tick. Preserve double
precision for HP/damage; retain current float transform semantics and snapshot
IDs/version. Native query kernels should resolve a unit handle once and read
resident facts directly, avoiding GDScript getters inside candidate loops.

Start with health/raw weapon facts and immutable role/type data, then movement
modifiers and target legality/ranking as a complete acquisition boundary. Wire
same-tick writes at existing setters/events before using any cached fact: health,
construction, capture/reparenting, suppression bands, ability toggles/expiry,
signature windows, research, veterancy, scrap and garrison transitions. Keep
unported facts live and generic non-Unit objects on the existing fallback. Do not
silently cache mutable arrays or metadata across a tick. Positions can be sampled
through native Node3D access until their authoritative movement store is shared.

Preserve shot authority and command latency: native selection/visibility must
observe intervening damage and status changes, with final firing validation at
the existing time. Bulk scheduling must not introduce an extra input tick or
grant shots from a stale perception snapshot. Compare full native/script target
results, same-tick mutations, ordinary and forced attacks, aircraft/garrisons,
weapon modes and saves before a new production A/B. A tiny arithmetic kernel or
a copied-data microbenchmark cannot establish this architecture's success.

### First resident unit-state slice implemented

`--native-unit-state` creates a match-owned `CopperfinUnitStore`, with contiguous
slots, generation handles and native state views. Unit setters publish health,
raw weapon inputs, sight, construction, domains, veterancy and scrap changes
before gameplay signals. Team changes publish immediately as well. The current
script backing values remain available as a compatibility oracle and for the
unchanged save contract; the native consumers do not rebuild those facts from
objects each tick.

Movement, observation and target-legality kernels now share the resident facts.
Complete movement modifiers and weapon modifiers are evaluated natively, with
live ability/signature/suppression state and research. Target eligibility retains
forced attacks, projectile facts, current ownership, garrisons, construction,
aircraft ground phases and specialized script hooks. Geometry/positions and
unported behavior retain their current live path. No command or shot cadence
changes, and no snapshot version/ID changes, are part of this slice.

`NativeUnitStateRegression.gd` passes 26,772 independent native/script comparisons
across three factions, 16 roles and custom domain/damage/alliance overrides. It
covers same-tick mutations, shared and replaced domain arrays, nullable weapon
inputs, immediate health publication, queued deletion, generation reuse and
ownership lifetime. Native visibility's 19,200 full-query comparisons also pass.
Abilities, weapon modes, aircraft flight, air-save continuity, garrison combat,
combat, AA priority, all three full research trees, Helix support and suppression
pass gameplay assertions with the backend enabled. The affected save tests now
await the production `Globals.quit_game` audio drain instead of immediately
quitting the SceneTree. Their final runs pass and exit without warnings/errors;
verbose diagnostics of the earlier leaks identified synchronized music playback,
not native store/view ownership. This does not prove every previously observed
engine shutdown access violation is resolved. Rendered batch/material/bounds/
cloning and interpolation/catch-up/pause/socket checks pass across all factions.
The 16 final clean results and the failed-test history are archived in
`native-unit-state-correctness.json` and `native-unit-state-checks/` alongside the
production reports.

The movement oracle initially failed because enabling the match-wide backend
disabled its script reference callback. It now explicitly detaches the actors
from that backend and uses its own candidate runtime; all 750 complete steering/
contact comparisons pass with resident state enabled. An early API lookup issue
was corrected as well: probing unrelated objects must pass null callbacks to
`object_get_instance_binding`, so misses do not create empty engine bindings.
Only actual unit binding uses the creation callback.

Production reports now require all batched units to have resident records and
eligibility, speed and direct native reads to execute during each measured
interval. The runner also checks the complete process log, including teardown
after the fixture logger is removed. The new backend remains experimental/off
by default until rendered and complete production comparisons establish its
benefit; correctness counts alone do not establish progress toward 120 fps.

Pass 23 completes the same-executable native-4K comparison, with native movement,
visibility, surface queries, resident rigs and profiling enabled in both runs.
Control FPS is **7.73 / 5.96 / 5.45 / 8.54 / 6.14**, versus
**10.44 / 7.81 / 7.37 / 11.85 / 8.41** with resident unit facts: **31–39%** higher.
Both full workloads are valid, exit normally and have zero errors/warnings in
both sampling and complete process logs. All 560 units retain resident state;
direct scalar/speed reads and eligibility queries execute in every interval.
P95 is still **195–256 ms**. The goal remains unmet and the flag stays
experimental. Detailed results are in `native-unit-state-experiment.json` and
`native-unit-state-profile-summary.json`.

The improved combat phases still spend about 47–57 ms/frame in physics callback
dispatch and 44–48 ms in process dispatch. Pose preparation/finish/publication/
uploads together take about 17–21 ms/frame; native movement and visibility also
remain above their eventual budgets. Those aggregate callback spans include
subsystem scopes, so they must not be added together. A new live script profile
is the next gate for choosing a complete bulk acquisition/presentation slice.

The new live debug profile samples seven combat frames. Repeated speed and
legality getters no longer lead the script ranking; outcome/roster scans,
exploration and root capture now do. These instrumented timings are not
production FPS. A further same-executable roster run measures
**11.07 / 8.35 / 6.93 / 13.87 / 10.83 fps**, compared with the resident-unit-state
control's **10.44 / 7.81 / 7.37 / 11.85 / 8.41**. Night combat regresses and tails
remain noisy; the roster index stays experimental. This mixed single run does
not establish a uniform benefit. See `unit-state-script-profile-summary.json`
and `native-unit-state-roster-experiment.json`.

## Prototype 2: animation without per-bone scene updates

- Capture each faction/model's rig, rest matrices and motion configuration once.
- Evaluate animation over compact state in a native bulk solver; write directly
  into the existing GPU pose palette. Preserve exact gait/IK behavior first.
- Decouple unit-root interpolation from local articulation. Root motion stays
  smooth at display rate while independent local pose work can be scheduled.
- Evaluate authoritative weapon sockets on demand for shots. Avoid GPU readbacks
  in gameplay; the CPU and GPU consume the same animation state.
- If a native solver still exceeds budget, prototype GPU compute pose evaluation
  or animation atlases, with explicit visual and socket-error checks.

Provisional CPU budget: 0.5 ms per displayed frame for pose coordination/uploads.
All three factions, worker activity, recoil, damage motion, paused frames,
catch-up frames, muzzles and current save contracts must remain covered.

### First implemented experiment

`native/pose_packer/infantry_pose.h` now evaluates the complete existing infantry
gait, stopping/recovery steps, suppression/prone posture and arm/leg IK over a
compact working set. Immutable rig data is captured once. The experimental
`--native-infantry-poses` path uses a node-free infantry hierarchy and retains the
script fallback. It remains disabled by default.

Native/script state and local-transform comparisons pass for all three factions
and five roles over 160 mixed-duration steps, including 1/120 s and 0.35 s steps,
start/stop transitions, aiming, immediate shots, reflected head scale, leaning,
flinch and suppression. Rendered material/bounds/cloning and frame-pacing/muzzle
checks pass for all factions with the flag enabled.

The initial editor/headless solver-only microbenchmark (100 infantry, 200 timed
iterations after warmup) measured 0.609 ms native, 0.866 ms threaded script and
1.467 ms serial script. This is only about 1.4x over the existing threaded solver,
and says nothing about gameplay FPS. The adapter still samples/publishes script
objects at the batch boundary. A resident packed state and direct palette output
are therefore part of the necessary architecture, not an optional final polish.
Full-load production comparisons must decide whether this adapter is worth
enabling before that larger rewrite.

The same-executable native-4K comparison is now complete. All five phases retained
400 mobile units / 160 structures, live AI and combat, with zero engine errors
and native fallbacks. Native versus control FPS changed by -2.0%, +3.6%, +0.4%,
+0.9% and +4.4%. Both runs remain around 3 fps, with p95 frames hundreds of ms.
This single paired run demonstrates no substantial whole-frame gain; the
adapter stays disabled by default. Detailed values and executable identity are
in `docs/playtests/2026-10-26/2v2-performance/native-infantry-experiment.json`.
The next prototype should implement the resident movement/perception data path,
with explicit dirty inputs, rather than port more isolated math helpers.

## Prototype 3: one presentation snapshot

- Models, minimap markers and selection/ownership overlays consume the same unit
  state buffer instead of independently walking nodes and recalculating contacts.
- Render markers and repetitive effects as instance batches. Update resource and
  production text from changes rather than repeated full-tree scans.
- Give cosmetic work explicit frame budgets and phases; keep simulation and
  weapon rules at their original cadence.

Provisional budgets: 2 ms CPU for render submission/UI and 6 ms GPU at native 4K.
CPU/GPU overlap, simulation-tick frames and p95 tails must be measured separately;
the budgets are targets, not achieved results.

### Resident presentation coordination implemented

The experimental `--native-presentation` path implies resident rigs and adds a
match-renderer-owned `CopperfinPresentationBatch`. Stable generation handles
retain rig data and weak scene IDs. One native capture loop retains the
penultimate physics root and elapsed pose duration, including catch-up ticks
and immediate shot flushes. One native publication loop revalidates visibility,
packs articulated transforms, rebases the previous palette and resets teleports.
Script code handles changed spatial groups/ownership and texture submission on
this boundary. Body animation preparation/finish is still script-based; this
slice does not claim that all pose evaluation has become native.

Hit-flash material values remain live, optional scene geometry for tracks/scrap
still follows its unit, and renderer invalidation preserves ordinary rendering.
The native batch holds rigs strongly and scene objects weakly. Unsupported
bindings disable this prototype and retain the previous renderer. Benchmark
activation/record counts and per-interval capture/publication counters must pass.

The independent current/previous palette oracle passes **1,600 comparisons** over
800 varied steps, including reflections, multiple captures per display frame,
paused frames, teleports, cell/altitude changes, capture/rebinding, visibility,
hit flashes, stale handles, freed nodes and rig lifetime. An uninitialized Variant
return in the initial native material getter caused a crash and was corrected
before this passing result. Rendered integration checks now pass across all
three factions, including actual palette hit/fog values, material pixels, bounds,
cloning, part replacement, interpolation and sockets. Rendered live-combat and
repeated save/reload assertions also pass with clean exits. These five final
results are retained in `native-presentation-correctness.json` and its linked
text logs. Production A/B now passes with clean exits and valid full workloads.
The same-executable control runs at **10.41 / 7.71 / 7.19 / 9.60 / 8.79 fps**;
the candidate reaches **13.07 / 9.61 / 7.90 / 14.62 / 9.56 fps** in day movement,
day combat, night combat, night base and cycling-weather combat respectively.
This is one pair, not a confidence interval; the base view has shown substantial
variance before. All 560 candidate bindings are active and native capture and
publication execute during every sample. P95 still spans **127–241 ms**. The
prototype stays off by default and the overall target remains unmet. See
`native-presentation-experiment.json` for exact executable/source identities.

The measured batch reduces root capture from **1.43–2.28 ms/frame to
0.047–0.084 ms**, and palette publication from **5.05–5.62 ms to 0.82–0.98 ms**.
Direct RenderingDevice palette uploads are consequently deprioritized: the
entire remaining publication scope is already below one millisecond. The current
`ImageTexture.update` path creates Images and emits resource/property-list change
notifications on every upload, as shown in the exact
[Godot 4.7.2 implementation](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/resources/image_texture.cpp#L91).
Owned GPU input textures could avoid that wrapper boundary while retaining the
same interpolation shader. This is only a candidate, not an implemented gain;
measure CPU/GPU time and fence/lifetime behavior before adopting it. Generated
batch meshes also currently drop source mesh LODs; restoring conservative LOD
indices is a separate candidate if GPU cost persists after CPU submission work.

### Native exploration disk scan

The fresh post-presentation debug profile records seven sampled combat frames.
Exploration still ranks near the top: 4.67 ms self time per sampled frame across
two calls. Roster, outcome, defense and economy scans also remain prominent;
these instrumented values rank candidates and are not production frame costs.
See `presentation-script-profile-summary.json` and the diagnostic report.

The experimental `--native-exploration` flag moves each observer's complete grid
scan into the native visibility runtime. Known cells are skipped there, while
new cells retain current map-height calls and complete point visibility. The
script boundary calculates the observer's live reach and publishes results to
allies before advancing to the next observer. This preserves ordered exploration
ledgers, custom observer reach, garrison bonuses, changing alliances and the
existing half-second cadence; it does not grant current targeting visibility.

An independent script-scan/script-visibility comparison passes **480 ordered
player ledgers** over moving observers, repeated visits, terrain/forest/cliffs,
map boundaries, aircraft phases, construction, death, garrisons and alliance
changes. The existing **19,200** complete visibility comparisons, commander
call-ins and all-faction gameplay-depth save/restore tests also pass with clean
exits. The production pair is valid and exits cleanly: control **12.31 / 8.41 /
7.94 / 14.71 / 9.61 fps**, candidate **13.18 / 8.23 / 8.33 / 16.24 / 10.82 fps**.
Four phases improve **5–13%**, but day combat declines **2%** and combat p95
remains **208–298 ms**. This one pair does not establish an across-the-board
improvement. The flag stays off by default. The subsequent debug profile drops
exploration self time from 4.67 to 0.77 ms per sampled frame (different sampled
calls/frames, not a controlled production timing). It is no longer among the
top twenty sampled functions. Full provenance is in
`native-exploration-experiment.json`.

### Fresh cumulative ablation of the resident core

The old frozen-scene result is now repeated with the resident movement,
visibility, surface, unit facts, rigs, presentation and exploration paths active.
The editor diagnostic completes with zero errors and a normal exit. Its logger
records one warning that MultiMesh interpolation was triggered outside physics
processing; this remains recorded and is not treated as a clean warning-free
run. Neither pass-25 production run emitted this warning.
Native activity checks remain mandatory in the production benchmark. Only the
ablation subclass relaxes interval activity for systems explicitly stopped;
binding, population, focus and rendering checks remain active. The diagnostic
also verifies that movement callbacks and unit processing were disabled at
their corresponding stages.

| Cumulative diagnostic stage | Mean fps | Mean GPU ms |
| --- | ---: | ---: |
| Live combat | 5.54 | 36.20 |
| Commander decisions stopped | 6.00 | 15.72 |
| Movement and avoidance stopped | 15.06 | 10.31 |
| Unit actions/traits and commander support stopped | 42.60 | 6.74 |
| Match processing stopped, poses still evaluated | 77.85 | 4.33 |
| Pose evaluation/uploads/interpolation stopped | 158.37 | 4.20 |
| HUD and auxiliary viewport redraw stopped | 168.68 | 4.20 |
| Frozen nighttime world | 169.60 | 4.22 |

These are **not playable or production FPS**, and stage differences are not
additive budgets. Movement affects gameplay, pose work and catch-up frequency.
The live main thread consumes 174 ms per displayed frame, including 76 ms in
physics callback dispatch and 59 ms in process callbacks. Stopping movement
reduces the latter scopes to 23/30 ms; stopping unit logic reduces total main
thread time to 22 ms/frame. Frozen p95 remains 10.6–11.7 ms, above the target.
See `resident-core-ablations.json` and its profile summary.

The next substantial boundary is still the complete per-unit simulation and
body-animation state, not another small query helper. Native steering currently
still imports/publishes agent properties, while unit actions and traits retain
individual script callbacks. Presentation coordination is native, but pose
preparation/finish/publication still crosses hundreds of script objects. Both
boundaries must be reduced while preserving weapon authority and existing
gameplay cadence. Shader/geometry quality reduction is not justified by this
diagnostic: frozen full geometry remains around 4.2 ms on the GPU.

## Focused movement diagnostic

The separate `MovementPipelineDiagnostics.gd` experiment keeps commanders and
combat live while isolating presentation and avoidance. With the resident core,
live combat measures **5.59 fps**; stopping pose publication gives **9.98**;
bypassing avoidance while publishing 96,400 requested-velocity callbacks gives
**11.54**, with 287 units still moving. Stopping movement then gives **32.19**.
This is an editor diagnostic, not playable FPS or a production speedup. It
retains one MultiMesh interpolation warning and exits normally without errors.
The first attempt was rejected because its final stage label accidentally
activated the production movement requirement; that rejected report is retained.

Avoidance alone does not explain the movement cost. The next investigation uses
an optimized engine with Tracy zones to expose native engine work absent from
the script profiler. See `movement-pipeline-ablations.json` and
`movement-pipeline-profile-summary.json`. Tracing results cannot qualify the
120 fps target because instrumentation changes timing.

## Optimized native engine trace

A Godot 4.7.2 release-template build with Tracy captures 6.12 seconds of live
day combat, including 13,871,990 zones. The full 4K fixture completes with all
560 units, normal exit and no process errors or warnings. It is diagnostic
evidence only: custom compiler and instrumentation overhead preclude FPS claims.
Build options, source/tool hashes, CSV exports and process output are retained
under `native-engine-trace/`; the raw 39 MB trace remains in ignored `tmp/`.

The capture contains 42 complete engine iterations and 183 complete physics
steps. Inclusive elapsed scopes show **2,753 ms** in simulation callbacks and
**2,478 ms** in process callbacks. Navigation processing accounts for **453 ms**,
render submission **303 ms**, and 3D physics **50 ms**. Renderer synchronization
and the frame limiter are negligible here. Nested scopes overlap; these are not
independent budgets or uninstrumented CPU measurements.

Body-pose advancement accounts for **923 ms** inclusive. Observation queries
account for **766 ms**, charging/attack callbacks **733 ms**, and projectile
processing **596 ms**; observation is nested inside other gameplay paths.
There are **658,036** unit-player getter calls in this short capture despite
resident movement and unit facts. The three highest source groups for self time
are Battlefield, Unit and BastionVisuals (native calls from a source are included
in that source's labels). There is no single hidden physics/GPU wait explaining
the remaining gap.

The next boundary should be complete combat/perception queries over resident
records and complete pose preparation/finish over resident animation state.
Native arithmetic adapters that repeatedly read script properties leave the
dominant dispatch pattern intact. Preserve live visibility and ordered damage
authority; do not substitute stale per-frame visibility answers. A shared native
observer/body index can serve the combat batch and presentation queries without
reconstructing nested script dictionaries. See `native-engine-trace-summary.json`.

## Complete firing-query prototype (pass 26)

`--native-combat-queries` combines resident target eligibility, live effective
range, footprint distance, observation and line of fire in one native query.
It preserves aircraft range caps, elevation bonuses/penalties, garrison reach,
forced-target legality, custom domain methods and current ability modifiers.
Unsupported objects retain the script path. It does not replace action scheduling,
projectile simulation or the shared index, and stays off by default.

The independent script oracle passes **7,299** comparisons (**352** successful
shots), covering all three factions, role pairs, same-tick changes and exact
range boundaries. Native visibility (19,200 comparisons), terrain sight, combat,
projectile persistence and all-faction save/restore checks also pass, with no
errors or warnings. The release preflight includes the new oracle. A pre-existing
indentation error at its exploration check was corrected and Python compilation
verified.

The same production executable measures:

| Phase | Control fps | Native firing fps | Change |
| --- | ---: | ---: | ---: |
| Day movement | 11.85 | 11.36 | -4.1% |
| Day combat | 9.97 | 9.45 | -5.2% |
| Night combat | 7.18 | 8.11 | +13.0% |
| Night base | 15.43 | 14.55 | -5.7% |
| Cycling weather combat | 11.05 | 9.34 | -15.4% |

Both full native-4K workloads are valid, exit normally and have no process
errors/warnings. The requested native firing path executes in every sample.
**This pair does not establish an overall performance improvement.** Candidate
p95 is 144–295 ms; the 120 fps target remains unmet. See
`native-combat-experiment.json` and `native-combat-correctness.json`.

A second optimized-engine trace captures 11.34 million zones over six seconds.
The firing wrapper takes 563 ms inclusive, of which 493 ms is its index refresh;
the native query beneath it takes 68 ms across 6,071 requests. The shared observer
index is rebuilt 167 times and takes 492 ms inclusive (235 ms self), about 3 ms
per simulation tick in this instrumented run. These scopes overlap and cannot
be converted directly to production gains. Pose advancement still takes 847 ms.
The index and pose-state boundaries remain the next priorities: replacing one
query chain while reconstructing script dictionaries and importing live node
facts leaves the larger cost intact. See `native-combat-trace-summary.json` and
the complete exports under `native-combat-engine-trace/`.

## Acceptance

Use the full production-template benchmark with live commanders, real weapons,
400 mobile units, 160 structures, native 4K, normal graphics, day/night and cycling
weather. Require 60 mean fps, p95 at most 1000/60 ms and real-time simulation ratio
at least 0.98. Diagnostic freezes, smaller armies and reduced resolution cannot
qualify. Preserve current snapshot IDs and format; bridge native internal state
to the existing serializer before considering any schema change.

References: [Godot server APIs](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html),
[Godot MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html),
[NVIDIA animated crowd rendering](https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-2-animated-crowd-rendering),
[flow field tiles](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter23_Crowd_Pathfinding_and_Steering_Using_Flow_Field_Tiles.pdf).
