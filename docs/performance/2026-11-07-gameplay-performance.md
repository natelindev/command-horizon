# Gameplay responsiveness — 2026-11-07 / 2026-11-08

The optimized macOS release meets the requested performance thresholds in the
pooled 200-unit Bastion/Helix fixture: **100.4 FPS average and 16.23 ms p95**.
An independent render-submission clock measures **16.57 ms p95**. This is a
measurement of the configuration below, not a guarantee for every battle or
short sampling window; the second repeat exceeded the p95 threshold.

## Current release measurement

Apple M1 Pro, Metal Forward+, High graphics, 1280×720 exclusive fullscreen,
VSync off, 30 Hz simulation. The uninstrumented custom Godot 4.7.2 engine uses
the retained rendering fixes and profile-guided optimization. Its feature flag
automatically enables the patched render thread and native runtime allowlist;
these runs have no explicit native-runtime or render-thread launch flags.

| Sample | Mean frame time | Frame p95 | Render-submission p95 |
| --- | ---: | ---: | ---: |
| Release A | 9.90 ms | 16.19 ms | 16.23 ms |
| Release B | 10.02 ms | 17.11 ms | 17.56 ms |
| Both samples pooled | **9.96 ms** | **16.23 ms** | **16.57 ms** |

The pool includes both matching candidate runs from the predefined six-run
comparison, without selecting the faster repeat: 480 post-draw intervals and
478 render-submission intervals. Percentiles use the benchmark's existing
zero-based `int(count * .95)` index. Both retain 200 visible combatants, 100 selected
units, foreground focus, damage/effects/audio and real-time progression. Each
advances 2.40 simulation seconds; wall times are 2.38 and 2.40 seconds. Maximum
frame time is 31.25 ms (31.42 ms on the independent clock). This short sample
establishes the measured percentile, not long-duration tail stability.

The matching ordinary O3/ThinLTO custom-engine controls measured pooled p95s of
17.47/18.14 ms on the two clocks. A bounded process-list sorting experiment did
not meet the target and was removed. The retained source-mesh change suppresses
unused transform callbacks while preserving child interpolation, restoration
and cloning.

The playable artifact is
[`OpenRTS-game-optimized-macos-arm64.zip`](../../build/optimized-macos/OpenRTS-game-optimized-macos-arm64.zip).
[Build and packaging instructions](../../tools/performance/engine/README.md)
record the pinned source and optional compiler profile. Ordinary Godot builds
keep Safe rendering; the automatic profile applies only to the patched engine.
Windowed mode, other platforms and other battle compositions are not covered by
this FPS qualification. All-faction rendering is covered by correctness tests.

## Final verification

The final PGO engine passes nine graphical suites, including all-faction model,
track and frame-pacing comparisons, 1,332 GPU pose rows, fog, selection and charge
sparks. Eleven exported gameplay/native suites cover formations, travel budgets,
save/navigation timing, attack phases, camera behavior and over a million chassis
comparisons. Native state passes 40,980 comparisons on both actual threaded Metal
and the normal Safe headless renderer. The threaded dummy renderer reported two
material leaks at shutdown; it is not used for headless qualification.

All 26 release-runner and three engine-packaging Python tests pass. Changed
production scripts pass formatting/lint, and `git diff --check` is clean. The
signed playable app passes its optimized startup fixture and a normal main-menu
launch. Local build, package and qualification receipts are retained beside the
artifacts. The package receipt itself makes no automatic FPS claim; the separate
qualification receipt records the measured scope and percentile convention.

## Initial editor/debug investigation

The 200-unit live battle diagnostic improved from **90.36 to 46.36 ms per frame**
on this Mac, a 49% reduction. Planning a 200-unit route through eleven formation
gates improved from **25.28 to 6.70 ms**, with exactly the same waypoints.

## Changes

- macOS now uses the existing native pose batching, spatial index and contact
  kernels automatically when a compatible library is installed. Previously those
  paths required an explicit launch flag on Mac. Windows defaults remain
  the same; the additional experimental runtimes remain opt-in.
- Native loading checks that the descriptor matches the current platform and its
  library exists. Missing support and `--disable-native-kernels` retain the
  portable paths.
- Formation commands project each bottleneck's one or two lane positions once,
  instead of repeating the same navmesh query for every member. Each unit keeps
  its own mutable waypoint list. No routes are cached across commands/rebakes.
- Portable ground collision checks reject geometrically impossible contacts
  before evaluating expensive movement modifiers. Actual contacts still read
  live speed, domain and ghost state.

Gameplay speeds, graphics settings, simulation cadence, saves and camera behavior
are unchanged. These pathfinding changes reduce planning/collision cost; they do
not replace the routing algorithm or promise shorter routes.

## Measurements

Godot 4.7.2 official editor/debug, Apple M1 Pro, Metal Forward+, 1280×720 High,
VSync off, 30 Hz simulation. The unchanged `BenchmarkBattlePerformance.gd`
fixture retains 200 visible combatants, 100 selected bodies, real weapons,
effects/audio and production effect preparation. Both retained runs pass the
fixture's focus, population, visibility and real-time progression checks.

| Metric | Original | Updated |
| --- | ---: | ---: |
| Mean frame time | 90.36 ms | 46.36 ms |
| Median frame time | 86.23 ms | 43.54 ms |
| p95 frame time | 132.20 ms | 64.85 ms |
| Mean main-thread CPU/frame | 89.30 ms | 43.75 ms |
| Mean draw calls/frame | 11,290 | 2,166 |
| 200-member bottleneck plan median | 25.28 ms | 6.70 ms |

The original project copy restores the production files from commit `97880b09`.
The updated run uses ordinary defaults; neither run enables experimental unit
state, crowd, visibility or pose runtimes. Samples run serially with no other
Godot process. This is a short 60-frame diagnostic pair, not a confidence interval
or release performance qualification. Different render speeds also advance the
live battle for different wall/simulation durations. Heavy battle frame times
still exceed the 16.67 ms budget for 60 FPS. Metal reports no GPU timing here.

The formation diagnostic uses 200 tanks and an authored seven-metre opening in
BigArena, with nine synchronous samples. It compares every route against the
original planner. These headless subsystem timings do not measure gameplay FPS.

## Verification

All 17 headless checks, three rendered suites and 26 release-runner Python tests
pass. Rendered track coverage includes 20 poses. Both new regression suites
fail against the original production files and pass with these changes. Editor
import and changed production-script formatting/lint checks pass.

- Native startup/defaults, disable precedence, and missing-library fallback.
- Portable contact filtering with explicit speed-read counts and same-tick
  eligibility changes; 2,500 native/script contact parity comparisons.
- Native pose packing/rebasing, spatial queries in both backends, formation
  startup/planning, and independent per-unit funnel route consumption.
- Mixed-army advance/retreat, recorded crowded corners, dynamic construction
  obstacles, harvesting, factory egress, and camera feel.
- Rendered batching/material/fog/destruction parity, frame interpolation and
  tracked-vehicle presentation across all three factions.
- Release runner Python checks; the two new regression suites are registered
  in its standard manifest.

Raw selected benchmark reports and test receipts are in
[gameplay-results.json](2026-11-07-gameplay-results.json). Full local logs and
captures are retained under `tmp/gameplay-performance/`. Exploratory captures
that lost focus, outlived the fixture population, or ended with off-screen units
are excluded from the comparison. Three existing duplicate-load lint findings
in `TacticalFormationsRegression.gd` also reproduce on the original revision.

Windows/Linux execution was not verified. The figures above describe the initial
editor/debug pass; subsequent exported-release work is recorded below.

## Earlier exported-release measurements

At this stage the 60 FPS goal was **not met**. Qualification requires both a mean of at least
60 FPS and p95 at or below 16.67 ms, with graphics, workload and 30 Hz simulation
preserved. These follow-up runs use the official macOS release template at High,
1280×720, with all experimental native runtimes explicitly enabled. Those
additional runtimes remain opt-in in ordinary gameplay.

Subsequent changes include sparse alternating-muzzle bindings, a shader for
charge sparks, native chassis/presentation/fog packing, live native movement
technology queries, phased perception scans, and shared immutable Helix infantry
weapon materials. The weapon fix reduced the battle from 67 model groups and
about 2,090 draws to 26 groups and roughly 1,360 draws. Pose inputs now upload only
occupied buffer rows instead of two full textures; interpolation math is unchanged.

| Official release sample | Mean frame time | p95 frame time |
| --- | ---: | ---: |
| Before shared weapon materials | 24.26 ms | 30.09 ms |
| Shared materials, run A | 23.06 ms | 29.20 ms |
| Shared materials, run B | 23.02 ms | 28.92 ms |
| Before pose-buffer uploads | 22.88 ms | 29.26 ms |
| Pose buffers, run A | 21.56 ms | 26.80 ms |
| Pose buffers, run B | 22.48 ms | 27.03 ms |
| Latest windowed build | 22.81 ms | 29.65 ms |

These are serial 120-frame live-combat diagnostics, each retaining 200 visible
combatants, focus and real-time progression. Their variation limits conclusions
about small gains; none qualifies for the target. No graphics reduction is used.

A separate exclusive-fullscreen diagnostic, with the same verified 1280×720
render target and workload, measured 15.70/24.32 and 15.65/24.70 ms mean/p95.
Its average exceeds 60 FPS, but its p95 fails. Per-frame counters show roughly
21.3 ms on frames containing a simulation tick and 10.6 ms between ticks. These
mode comparisons remain explicitly diagnostic. An earlier fullscreen attempt
rendered at 1280×802 and is excluded.

The retained changes pass actual GPU material, fog, track and interpolation
comparisons across all factions, the focused native/gameplay regressions, and
release-runner checks. The new GPU palette regression covers 1,332 row samples,
coalesced uploads, growing/shrinking row counts, reflected/nonuniform poses,
hidden geometry and frames without a simulation update. A normal-matrix palette
experiment passed rendering checks but made performance worse and was removed.

Selected release reports and verification receipts are included in the companion
JSON. Full local evidence is under `tmp/gameplay-release/`. CPU/GPU traces use
instrumented engines and are never treated as FPS qualification.

A later custom profile-guided release engine, trained on the same fixture across
all three factions, measured 14.49/21.39 and 13.51/20.72 ms mean/p95 in fullscreen.
These uninstrumented custom builds still fail the p95 target. Matched official
control runs measured 15.02/23.28 and 14.67/22.67. A static-typing-only animation
experiment measured 14.76/22.54 and was removed because it showed no clear gain.

Threaded rendering remains disabled in production. Local engine experiments
address the [confirmed glyph-image race](https://github.com/godotengine/godot/issues/122206),
device ownership during shutdown, interpolated MultiMesh uploads and stale RID
generation checks. A related project cleanup fix retains compute owners until
their queued release finishes; the original all-faction frame-pacing crash now
passes, as do palette and fog GPU checks.

Clean custom-engine fullscreen runs subsequently measured 10.48–11.02 ms mean
and 17.34–17.76 ms p95. These still fail the target and use experimental native
paths and a locally patched engine. Independent main/render submission clocks
agree with the frame timings; typical render-queue delay is about 0.02 ms.
Synchronous driver-timing probes are omitted from these runs, while population,
visibility, focus, graphics and simulation-progression guards remain active.

A native walker IK experiment passed pose comparisons but gave no consistent
performance gain and was removed. One repeat also reported a particle-lifetime
error and is excluded. A focused emitter churn test reproduced 1,433 instances
of that engine error. Collecting the updates during parallel culling and applying
them after the join in the current render pass fixes the reproduction. The
regression at the default culling threshold reports 4,318 errors before the fix
and zero afterward on an uninstrumented release engine. The engine patch and
its experimental status are recorded under `tools/performance/engine/`.

Compiler training limited to live combat across all three factions did not
improve timing. Two uninstrumented repeats measured 10.78/17.11 and 10.89/17.52 ms
mean/post-draw p95, with render-submission p95 of 17.00 and 18.62 ms. Matched
controls measured 10.45/16.31 and 10.47/16.74 ms, but render-submission p95 was
16.73 and 16.48 ms respectively. Neither set consistently meets the target
across both clocks. Threaded rendering remains unqualified for production;
worker scheduling is the next diagnostic. Training measurements are never used
as release FPS results.

Later selection-ring checks cover 18 Metal and OpenGL image pairs. Moving its
clock to an instance uniform preserved the rendering; the timing gain was small
and variable. A parallel body-math experiment showed no benefit and was removed.

A separate engine optimization skips transform uploads for visual instances
whose rendering base has been cleared by the model batcher. Paired release runs
measured 9.93–9.97 ms mean versus 10.73–10.92 for the control. Candidate p95 was
16.14–16.77 ms after drawing and 16.51–16.92 ms at render submission. Thus this
pair still does not consistently meet the target. Three four-worker repeats
passed the post-draw threshold but failed the independent submission threshold
(16.94–17.22 ms); no worker-limit change is enabled in production.

The empty-mesh optimization passes 108 image comparisons of moving children and
restored meshes, plus frame pacing, GPU poses, fog, model batching and cleanup.
A track check failed because its root render dimensions changed; fixing the
viewport aspect policy made all 20 poses pass again. Spark and empty-mesh tests
also pass on the official Metal and OpenGL engines. Both retained engine patches
apply to the pristine source archive and reproduce the checked source files.
