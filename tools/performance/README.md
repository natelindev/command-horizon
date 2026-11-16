# Heavy 2v2 benchmark

The basic native pose batching, spatial index and contact kernels now activate
automatically on macOS as well as Windows when a compatible library is installed.
`--disable-native-kernels` forces the portable fallback. Missing libraries fall
back quietly. The additional experimental runtime flags documented below remain
opt-in; basic kernel activation does not enable them.

This Windows benchmark exports the actual release template with a dedicated
SceneTree entry point. Godot release templates do not implement `--script`.
The stage uses junctions to the current project and an isolated user directory;
the ordinary game entry point and user options are preserved.

```powershell
python tools/performance/build_benchmark.py --godot PATH_TO_GODOT_CONSOLE.exe --output tmp/heavy-2v2/Command_Horizon_Heavy2v2.exe
python tools/performance/run_benchmark.py --executable tmp/heavy-2v2/Command_Horizon_Heavy2v2.exe --output docs/playtests/2026-10-26/2v2-performance/result.json
```

Keep the exported game focused and run it alone. Do not edit sources during
export. The builder rejects changes to its source manifest during packaging.
The runner waits for normal shutdown, attaches the source and executable hashes,
and reports fixture validity separately from the 60 fps target (revised by the
user from 120 fps). The frame budget is 16.67 ms; acceptance requires mean FPS
at least 60 and p95 frame time at most 1000/60 ms in every phase. Rebuild older
benchmark executables so their recorded target matches the current acceptance.
Target success also requires the full native-4K workload, all five phases, live AI,
the 30 Hz simulation cadence and advancing cycling weather. A faster diagnostic
run at smaller counts or resolution cannot satisfy the goal.

Default workload: Copper Badlands, two teams, four factions/players, 100 mobile
units and 40 legally placed structures per player, three live AI commanders,
normal graphics at 3840×2160 and 1.0 3D scale, VSync off. Elevated fixture HP keeps
the workload alive while normal weapons, targeting, projectiles and effects run.
Default visibility matches the user's per-player fog. `--reveal-terrain` reproduces
the early comparison fixture: terrain is revealed, while unit visibility retains
the normal team observation handler. It does not show all enemy units. Compare
like visibility modes and report the recorded simulation tick rate (currently 30 Hz).
Measurements include daytime movement/combat, nighttime combat/base views and
combat with the day cycle and rain active. Each phase records its lighting options
and actual start/end hour, so fixed-lighting runs cannot stand in for cycling weather.
Screenshots occur outside the measured intervals. Raw frame samples, actual
rendered frames, focus, firing, simulation progress and population are recorded.

Additional fixture arguments go after `--`, for example `--seconds=12`.
Smaller `--mobile=50 --structures=20 --seconds=4` runs are diagnostics and cannot
establish the full-load goal. Never use `--headless` or `--fixed-fps` for timings.
The editor can run the fixture with `--script` for diagnostics, but its results
are marked `release: false` and cannot establish production performance.

Current progress and research: [goal work log](../../docs/plans/2026-10-26-2v2-120fps.md).

`--native-battlefield-index` (with `--native-visibility-runtime`) enables the
experimental persistent native observer/body index. Add `--native-unit-state`
for the base-unit sight fast path. It preserves ordered cell traversal and
reads current positions, ownership and custom sight behavior during queries.
The report records active bodies, rebuilds, nearby queries, visibility scans,
allocations and native sight evaluations. It remains opt-in; functional parity
does not establish a whole-frame speedup. The release checks exercise this path
with `NativeBattlefieldIndexRegression`, `SpatialQueryRegression` and
`NativeCombatQueryRegression`.

`--native-infantry-poses` enables an experimental complete native infantry gait/IK
solver and node-free infantry hierarchy. It retains the script fallback and is
not enabled by default. Compare it against the same executable without the flag;
the report records activation, solved jobs and fallbacks. The isolated
`tests/rendered/InfantryPoseMicrobenchmark.gd` measures solver CPU cost only and
must never be used to claim gameplay FPS.

The cumulative `tests/rendered/RadicalCrowdDiagnostics.gd` ablations deliberately
stop gameplay systems. Reports carry `diagnostic: true` and cannot qualify for
the target. See the [architecture prototypes](../../docs/plans/2026-10-26-radical-crowd-runtime.md).

`--native-crowd-runtime` enables the experimental complete native ground movement
path, retaining Godot routing/avoidance and specialized aircraft movement. The
report records activation plus cumulative steering, velocity-callback and server
projection counts, followed by indexed ground body count. A requested backend
that did not activate/execute invalidates the run. Correctness regressions are
`NativeCrowdMovementRegression.gd` and `NativeCrowdProjectionRegression.gd`;
`NavigationRegression.gd -- --native-crowd-runtime` also asserts native execution.

`--native-visibility-runtime` enables native observer searches, sight/fire checks
and blocker geometry. Live ownership, health, construction, garrisons, aircraft
state and terrain arrays remain authoritative. The report records activation and
observed/point/line/candidate/terrain query counters; requesting an inactive path
invalidates the run. `NativeVisibilityRegression.gd -- --native-visibility-runtime`
compares complete queries with the retained script implementation.

`--profile-runtime` adds optional main-thread elapsed scopes for native movement,
native visibility and seven pose stages. It preserves live gameplay. Native
movement returns begin/steering/callback/server-projection microseconds followed
by their four call counts. Visibility returns configure/observed/point/line/fire
microseconds followed by five counts. Pose stages are roots/prepare/chassis
solve/finish/infantry solve/publish/upload, followed by seven counts. Each phase
records counter deltas rather than startup totals. The benchmark requires the
requested timers to execute. Profiling overhead must be kept in mind when
comparing FPS; compare like flags.

Use `summarize_runtime_profile.py REPORT --output SUMMARY` for per-frame and
per-call values. Server projection is included in movement time, and blocker
configuration may be included in visibility time; do not add these child scopes
again. The unattributed wall-time remainder includes engine work and waits and
is not a CPU utilization measurement.

For sampled function-level evidence, run the editor/debug binary with `--debug
--script res://tests/rendered/HeavyTeamScriptProfile.gd`, the ordinary absolute
`--output=...` argument and desired native flags. This live full-army diagnostic
profiles combat only and records `diagnostic: true`; it cannot qualify for the
FPS goal. Capture stdout and run `summarize_script_profile.py LOG --output SUMMARY`.
The summary excludes test coroutines and accumulated coroutine timings, which
can include frame waits, and ranks sampled game-function self time instead.
Engine warnings are retained separately from genuine runtime errors.

`--native-nearest-surface`, together with `--native-crowd-runtime`, enables an
experimental owned hierarchy over all convex polygons in the published terrain
region. Horizontal/slope containment shortcuts remain unchanged. Boundary
queries use the hierarchy; pending/stale iterations or unsupported region
layouts retain server queries. The flag is off by default. Reports include
activation and `[polygon_count, node_count, queries, polygon_tests, iteration,
elapsed_us]`. The optional profile records native projection as a nested movement
scope; do not add it again to callback time.

`NativeNavigationSurfaceRegression.gd` forces full nearest-point queries against
the server on all 24 maps, including vertices/edges, near-zero plane points,
owned-array mutation, unavailable publication and failed snapshot replacement.
`NativeCrowdProjectionRegression.gd -- --native-nearest-surface` checks the
combined projection path around rebakes; `NativeCrowdMovementRegression.gd` with
the same flag compares complete steering/contact callbacks. Navigation and the
production workload reject a requested surface backend that never executes.

`--profile-runtime` also brackets complete SceneTree callback dispatches and
records Windows process/main-thread CPU deltas. `scene_wall` and `scene_cpu` each
contain physics/process microseconds followed by their call counts. These are
aggregate scopes, not additions to the finer timers. `cpu_usage` reports the
whole sampled interval, plus the main-thread cycle delta without converting
cycles to time. Engine work before/after dispatch is outside those spans.

`--native-pose-rigs` enables resident native transform hierarchies and direct
palette packing for batched units. It remains off by default. Reports include
resident rig count and summed `[parts, local_writes, world_updates, packed_poses,
views_created]`; all batched units must use the requested path and writes/packing
must actually execute. `NativePoseRigRegression.gd` checks transform/hierarchy
and ownership behavior. `DecoupledPoseRegression.gd -- --native-pose-rigs` compares
all factions/roles with direct scene poses, and rendered `UnitBatchRegression.gd`
and `FramePacingRegression.gd` check palette/material/fallback/interpolation.

`--indexed-player-rosters` enables owner/type membership indexes and avoids
whole-army survival scans when a completed headquarters is present. Completion,
deletion and power modifiers remain live. Reports record active player indexes,
rebuilds and query counts. `PlayerRosterRegression.gd` independently checks live
child order, capture, completion, generic role mutation, power overdrive and
immediate deletion. The experiment remains off by default.

Use `compare_benchmarks.py CONTROL CANDIDATE --output COMPARISON` to summarize a
pair. It rejects incomplete/invalid workloads or different executable hashes.
One pair is not a confidence interval, and subsystem changes are not independent
speedup multipliers.

`--native-unit-state` enables the resident unit store shared by movement,
visibility and target legality, plus native movement/weapon modifiers. Unit/team
setters update it at mutations; positions, specialized hooks and unported facts
remain live. The experimental backend is off by default. Reports require every
batched unit to have a record and show actual activity during the sample.
Statistics are `[records, bindings, writes, eligibility_queries, speed_queries,
reads, eligibility_fallbacks, direct_scalar_radius_reads, direct_speed_queries]`.
`NativeUnitStateRegression.gd` compares current script behavior on the same live
objects, including same-tick status/ownership changes and lifecycle cases.

The runner retains `process_log_errors` and `process_log_warnings` from the entire
process. Any engine/script error after the fixture logger stops also rejects the
run; a clean measured interval cannot stand in for a clean process lifetime.

`--native-presentation` implies resident rigs and enables a native batch for
physics root capture, elapsed pose time and direct current/previous palette
publication. Script code still evaluates body animation and submits textures;
the flag does not claim a complete native animation runtime. It is off by default.
Reports require every batched unit to bind, and captures/packed parts must execute
during each sample. Statistics are `[bindings, captures, captured_roots, packs,
packed_parts, migration_checks, migrations]`. `NativePresentationRegression.gd`
checks the complete palette result against the retained renderer; rendered
`UnitBatchRegression.gd` and `FramePacingRegression.gd` also accept the flag.

`--native-exploration` requires `--native-visibility-runtime` and moves complete
exploration cell scans into that runtime. The caller retains live observer reach
and immediate allied ledger publication; native code skips known cells, samples
the current map and evaluates complete visibility for new cells. It does not
cache visibility results or change exploration cadence. Statistics are
`[observer_batches, candidate_cells, point_queries]`; each benchmark sample must
execute batches and scans. `NativeExplorationRegression.gd` compares complete,
ordered exploration histories with script scans and script visibility, including
alliance changes, repeated visits, aircraft, garrisons, boundaries and terrain.
The flag is experimental and off by default.

`--native-combat-queries` combines firing eligibility, effective range, footprint
distance, live observation and terrain/blocker checks in the native visibility
runtime. It requires `--native-unit-state` and `--native-visibility-runtime` for
resident pairs; unsupported objects retain the script path. No visibility answer
is cached. Reports require actual resolved native queries in every interval.
Statistics are `[requests, resolved, fallback]`. The independent script oracle
in `NativeCombatQueryRegression.gd` covers all factions, role pairs, same-tick
mutations, aircraft domains, garrisons, rotated footprints and range boundaries.
The flag remains experimental and off by default.

`trace_engine.py` captures a selected live phase with a separately built,
optimized Tracy-enabled Godot and matching Tracy CLI tools. Prepare the isolated
project with `build_benchmark.py` first, then supply `--godot`, `--project`,
`--capture`, `--csvexport` and a new `--output` directory. Runtime flags follow
`--`. The default capture is six seconds of day combat. Raw traces belong under
ignored `tmp/`; retain metadata and useful summaries as diagnostic evidence.
The runner marks all output as diagnostic and never accepts traced FPS as
production performance. It records tool hashes and terminates only its own
child processes on failure.
Release templates may disallow path overrides: place a copy or hard link of the
tracing executable inside the isolated project directory and pass that path as
`--godot`. The runner uses the project as its working directory and watches
redirected stdout because release file logging may buffer phase markers.
`summarize_engine_trace.py CAPTURE_DIRECTORY --output SUMMARY.json` ranks
inclusive and self zones and groups self time by source. Native calls are
labelled with their calling script source; inclusive zones overlap and worker
elapsed times must not be summed into a frame budget.

The Windows engine diagnostic uses Godot `4.7.2-stable`, LLVM-MinGW
`20261020-ucrt-x86_64`, SCons 4.11.1 and Tracy 0.14.1 (matching capture/export
executables). Sources/toolchains stay outside the repository under
`../work/engine-profile/`. Build with:

```powershell
python -m SCons platform=windows arch=x86_64 target=template_release production=yes debug_symbols=yes use_mingw=yes use_llvm=yes mingw_prefix=ABSOLUTE_LLVM_MINGW_DIRECTORY d3d12=no profiler=tracy profiler_path=ABSOLUTE_TRACY_SOURCE_DIRECTORY profiler_sample_callstack=yes linkflags=-ldbghelp -j6
```

Tracy 0.14.1 required adding `#include <stdio.h>` after `<stdarg.h>` in both
`public/client/TracyProfiler.hpp` and `public/client/TracyScoped.hpp` for this
compiler. This is a local profiler build fix, not a game engine behavior change.
The official production template remains the source of FPS acceptance evidence.
See the official [Godot native profiling guide](https://docs.godotengine.org/en/stable/engine_details/development/profiling/index.html)
and [Tracy integration guide](https://docs.godotengine.org/en/stable/engine_details/development/profiling/tracy.html).

## Live audiovisual battle fixture

`tests/rendered/BenchmarkBattlePerformance.gd` measures 200 visible live
combatants with selection, weapons, effects and audio. It requires graphical
wall-clock rendering. Select a faction and quality with `--av-faction=bastion`
and `--av-quality=high`, and a sample count with `--av-samples=240`. Pass
`--av-output=ABSOLUTE_DIRECTORY` to retain JSON and a capture.

Windowed rendering is the default. `--av-fullscreen` selects exclusive fullscreen
while retaining the verified 1280×720 viewport. Reports include the requested
mode and actual window mode for every sample. Compare like modes; changing the
window presentation mode can materially change frame pacing on macOS. Raw
frame times and physics-tick counts are retained for diagnosing tick-related
spikes. Profiling or cold-effects runs are diagnostic, and failed visibility,
focus, workload or real-time progression checks invalidate any timing result.

`--av-no-driver-timings` omits per-frame GPU and render-CPU timing queries, which
synchronously wait for the rendering command queue. Use paired runs to measure
their overhead, especially with a separate rendering thread. Reports set
`driver_timing_probe` to false and leave those two timing summaries empty; frame
times, draw counts, pipeline counts and every workload check remain present.
The default retains driver timing probes for comparison with earlier reports.
