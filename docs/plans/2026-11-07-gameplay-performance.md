# Gameplay performance

Improve responsiveness and frame time in ordinary play and large live battles,
using measured bottlenecks while preserving gameplay and graphics settings.

## Stages

1. Profile the current live battle and establish repeatable baseline timings in
   an isolated user-data directory.
2. Optimize the dominant confirmed work with a small, robust implementation.
3. Add regression coverage for affected behavior and repeat the same workload.
4. Record the measured improvement and any remaining limits.

## Release 60 FPS goal

5. Export the 200-unit fixture with the actual macOS release template and record
   a baseline at the same High graphics, raster and 30 Hz simulation cadence.
6. Profile and optimize the remaining dominant CPU work, preserving graphics,
   live combat, command response and route correctness.
7. Repeat release measurements and relevant regressions. Acceptance requires
   mean FPS at least 60 and p95 frame time at most 16.67 ms with all workload,
   focus and real-time progression checks passing.

## Agent progress

- Reviewed existing performance work and current benchmark fixtures. Previous
  HUD/hash improvements are already committed; this pass measures current play.
- Preparing an isolated 200-unit live battle diagnostic on the available Mac.
- The user confirmed choppy frames/delayed commands and requested pathfinding
  improvements. Found that macOS disables existing native batching/queries by
  default and that bottleneck planning repeats identical lane projections for
  every member.
- Enabled the basic kernels on macOS with compatible-library preflight and
  portable fallback. Reused command-local lane projections and moved geometric
  rejection ahead of derived speed queries in portable crowd collision checks.
- The 200-member, 11-gate planning diagnostic fell from 25.276 to 6.698 ms median,
  retaining exact routes. Clean 200-unit rendered diagnostics at 1280x720 High
  measured 76.85 ms/frame without kernels and 46.36 ms/frame with automatic
  kernels; these are short editor/debug runs, not release FPS qualification.
- All 17 focused headless checks, three all-faction rendered suites and 26 release
  runner Python tests pass. New startup/contact regressions are included in the
  release test manifest. Rendered material/fog/destruction/track parity and smooth
  interpolation pass, including 20 tracked poses.
- The final untouched-source comparison measured 90.36 versus 46.36 ms/frame,
  both with full visibility/focus/population/progression guards passing. Results
  and limits are in `docs/performance/2026-11-07-gameplay-performance.md` and its
  companion JSON. Heavy battles remain above the 60 FPS frame budget; exported
  release and other-platform performance were not qualified.
- Completed verification and evidence recording. Both new regressions fail on
  the original production files and pass on the updated code. Editor import,
  formatting and production lint pass; all owned game processes have exited.
- Continuing toward the explicit 60 FPS release goal; the earlier debug results
  do not satisfy it. Preparing a registered release fixture main loop and an
  isolated benchmark package using the installed official export template.

- Release goal continuation: exported an actual official macOS release fixture.
  Ad-hoc hardened-runtime builds could not load the native library; enabled the
  required library-validation entitlement in the macOS export preset. Re-export
  plus the existing release signing helper now loads it successfully.
- All optional native paths together produce valid 120-frame release diagnostics
  around 25–26 ms mean and 31–35 ms p95. The 60 FPS target remains unmet. Those
  paths still remain opt-in. Unprofiled and Vulkan comparisons did not materially
  improve timing. Separate rendering threads produced engine errors and were
  rejected. Long 240-frame samples sometimes lose units outside the camera;
  those reports are invalid for qualification, never accepted as fast runs.
- Fixed a native animation correctness bug: sparse production palettes omitted
  the second muzzle of alternating weapons. The new sparse-muzzle checks in
  DecoupledPoseRegression fail twice on the original and pass on the fix.
- Moved charge spark geometry to a vertex shader. Twenty rendered comparisons
  match the original CPU transforms/material. Charge geometry and presentation
  checks pass; the presentation test now drains audio cleanly on exit.
- Direct palette texture updates had no measured benefit and were removed.
  Preparing an optimized engine with symbols for diagnostic CPU sampling;
  acceptance still uses official release builds. Local continuation details and
  measurement locations are in ignored `tmp/gameplay-release/CHECKPOINT.md`.
- The symbolized live sample confirms script dispatch and rendering submission
  dominate the remaining cost. A larger model-batching cell did not materially
  help and was reverted. The release remains around 25 ms mean / 32 ms p95.
- OpenGL comparison exposed half-precision spark phase offsets; deriving them
  from the shader instance ID now passes all 20 image comparisons on both Metal
  and OpenGL. The graphical check is registered without a headless invocation.
- Native speed queries now evaluate standard movement technologies directly,
  with live research/ownership reads and fallback for custom script rules. The
  expanded parity suite passes over 40,000 comparisons. Two valid release runs
  still do not meet the 60 FPS goal; continuing with pose coordination costs.
- Native pose coordination now batches prepare/finish/publish dispatch; native
  chassis motion preserves spring behavior. Alternating-muzzle, attack-phase,
  chassis and all-faction animation checks pass. The latest valid official
  release run is 24.48 ms mean / 29.44 ms p95, still above the goal.
- Native fog packing preserves byte-for-byte circle/triangle tile buffers in
  503 checks. The actual GPU visibility/exploration/restore suite passes; release
  measurements are in progress. Separate render threads remain disabled after
  core rendering-resource failures, consistent with the engine's experimental
  status for that mode.
- Found that identical Helix infantry created unique emissive weapon materials,
  splitting every soldier into its own model group. Shared immutable authored
  finishes now reduce the fixture from 67 groups / 2,090 draws to 26 groups /
  1,360–1,380 draws. Two valid official-release runs measured 23.06/29.20 and
  23.02/28.92 ms mean/p95 versus 24.26/30.09 before the fix. The target is unmet.
- The material-sharing regression fails on the original code (28 intended
  assertions) and passes on the fix. All-faction actual-rendering comparisons,
  repeated-model sharing, fog, damage, cloning and teardown checks pass.
- Release tracing now separates the remaining work: roughly 3.1 ms/frame waits
  on GPU fences, 2.3 ms submits render commands, and 3.7 ms coordinates poses.
  A Metal trace confirms substantial compute work. Shader-labelled GPU
  diagnostics are in progress; tracing results never qualify as release FPS.
- Removed redundant settled selection-transform and terrain-overlay writes.
  Presentation checks and eleven native/headless regressions pass. A mixed-speed
  cohesion test was starting inside an ambient structure and comparing unequal
  detours; it now checks clear, straight lanes and positive travel. Both script
  and native movement pass the complete functional formation suite.
- Replaced full pose input textures with occupied-row storage-buffer uploads;
  inputs coalesce before drawing and reuse a fixed uniform set. All-faction
  material/track comparisons, native and default-path frame pacing, and 1,332
  actual GPU row checks pass. The release runner now includes the GPU check.
- A paired official windowed release diagnostic measured 22.88/29.26 ms
  mean/p95 before the buffer change and 21.56/26.80 and 22.48/27.03 afterward.
  A later clean windowed run measured 22.81/29.65, so the 60 FPS target remains
  unmet and the small windowed improvement is not a stable frame-time guarantee.
- Tested and removed precomputed normal matrices: the extra palette reads made
  the same scene slower. No normal/shading change remains.
- Fullscreen diagnostics with the exact 1280x720 raster measured 15.70/24.32 and
  15.65/24.70 ms mean/p95. Both retain focus, all 200 visible units and real-time
  progression, but still fail the p95 goal. Per-frame tick counts isolate the
  remaining spike: about 21.3 ms with a simulation tick versus 10.6 ms between
  ticks. Capturing that CPU workload before choosing the next optimization.
- A custom profile-guided release engine (trained on all three factions) measured
  14.49/21.39 and 13.51/20.72 ms mean/p95 in valid fullscreen runs; the target
  remains unmet. A static-typing experiment showed no clear gain and was removed.
- Investigating renderer-thread safety after identifying Godot's confirmed glyph
  upload race. A local engine snapshot fix and shutdown ownership fix pass the
  isolated glyph test, but the full battle still has buffer-thread/list errors.
  Threaded rendering remains disabled; those failed runs never qualify as FPS.
- Local render-thread diagnostics now dispatch built-in MultiMesh interpolation
  uploads on the rendering thread. One clean 120-frame custom release measured
  11.27/18.24 ms mean/p95. Longer repeats were similar but exposed an intermittent
  stale texture-handle error, so they are excluded from qualification.
- Traced that error to a freed RID whose slot had been reallocated but not yet
  initialized. A generation-check regression and rendered release checks are in
  preparation. No experimental engine or rendering mode is enabled by default.
- Added an optional benchmark mode that omits synchronous driver-timing queries;
  frame samples and all workload guards remain unchanged. Its measurement
  overhead will be evaluated in paired runs after the engine checks.

- The stale-RID fix passes both thread-safe and ordinary allocator regressions;
  genuine uninitialized handles still report errors. Clean custom-release runs
  with synchronous driver probes omitted measured 10.54–10.56 ms mean and
  17.60–17.88 ms p95. The target is still unmet.
- The broader frame-pacing check found a separate teardown crash: queued compute
  cleanup Callables did not retain their RefCounted owners. Explicit lifetime
  retention now fixes that original failure across all factions. The GPU palette
  suite includes immediate-owner-release coverage; fog and all 1,332 palette rows
  pass on the actual threaded release engine. A later clean run measured
  11.02/17.76 ms mean/p95. Experimental rendering remains disabled by default.
- Independent main/render submission clocks confirm the measured slow frames;
  the render queue itself adds only about 0.02 ms. A native walker IK experiment
  passed pose comparisons but showed no consistent timing gain and was removed.
  Preparing live-combat-only compiler profiling to exclude scene setup from the
  optimization training. The target remains unmet.
- Reproduced and fixed another engine race: particle view-axis callbacks from
  parallel culling could run after an emitter was freed. The default-threshold
  release regression now has zero errors, versus 4,318 before. All five engine
  fixes are preserved as an experimental, applicable patch with a rendered test.
- Live-combat-only compiler training did not improve repeat timings. No repeated
  run set meets 16.67 ms on both the completion and draw-submission clocks.
  Testing worker scheduling next, with the same graphics and simulation work.
- Instance shader clocks for selection rings pass 18 image comparisons on Metal
  and OpenGL. Worker limits and a parallel body-math experiment did not produce
  repeatable qualification; the body experiment was removed.
- The latest frame trace confirms CPU-bound simulation/presentation spikes.
  Skipping renderer transform uploads for source meshes whose rendering base is
  cleared reduced a paired release sample from 10.73–10.92 ms mean to 9.93–9.97
  ms. Candidate p95 values were 16.14 and 16.77 ms (render submission 16.51 and
  16.92), so repeated qualification is still pending. Checking empty parents,
  child interpolation, mesh restoration and the full rendered suites.

- The optimized engine now advertises a dedicated feature, enabling its native
  runtime allowlist and patched render thread automatically. The ordinary Godot
  defaults and explicit disable override are preserved. An actual playable app
  packages successfully and passes its isolated release startup fixture.
- Added a reproducible pinned-source build and packaging command, with checksums,
  artifact receipts and three packaging contract tests. The full build recipe
  completed successfully. Native startup default/disable/precedence checks pass.
- Disabling unused transform notifications on batched source meshes shows a small
  paired gain. All-faction batching, cloning and restoration checks pass. Fog and
  spark tests exposed render-queue timing assumptions; explicit queue barriers
  fix the original cleanup/capture failures without weakening image checks.
- Comparing the reproducible profile-guided build with a bounded process-list
  sorting candidate. The latter passes 96 ordering checks. Latest plain-engine
  p95 results still exceed 16.67 ms; the release goal remains open.

- Completed the measured release goal with the reproducible PGO engine and
  automatic runtime defaults. Both matching candidate runs from the predefined
  comparison pool to 100.4 FPS mean, 16.23 ms frame p95 and 16.57 ms independent
  submission p95. The second short repeat exceeds the target; the report retains
  that variability and limits qualification to this 1280×720 High fixture.
- Removed the process-sorting experiment. The final engine passes all nine GPU
  suites and eleven gameplay/native suites (Safe dummy mode for native-state
  cleanup, also verified with actual threaded Metal). All 29 Python checks and
  production formatting/lint pass. Packaged the signed playable app/ZIP, verified
  ordinary startup, and retained the compiler profile and qualification receipts.
