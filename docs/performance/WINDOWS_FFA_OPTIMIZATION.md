# Four-player Windows performance investigation

Target: 120 FPS (8.33 ms/frame), with 60 FPS (16.67 ms/frame) as the minimum
fallback in both phases of the existing four-player
1920×1080 rendered stress test on Ryzen 7 5800X3D / RTX 4090. Retain all
200 mobile units, 80 structures, graphics defaults, animation, physical
projectiles, 30 Hz simulation and real-time rendering. This fixture disables
commander AI and raises HP; it does not certify a complete live match or 240 FPS.

## Research and application

- [Godot CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html)
  and [general optimization](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html):
  measure actual hotspots and use controlled diagnostic ablations; confirm final
  gains with instrumentation removed and the original workload restored.
- [Spatial partition](https://gameprogrammingpatterns.com/spatial-partition.html)
  and [data locality](https://gameprogrammingpatterns.com/data-locality.html):
  local neighbor queries and compact, reused hot data avoid repeated scene-tree
  discovery, dynamic dispatch and allocation. The repo already has spatial grids;
  improve their measured consumers rather than introduce a second competing index.
- [Godot navigation performance](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_optimizing_performance.html):
  retain paths until targets change, stagger expensive requests, and avoid duplicate
  reachability/path queries. Preserve collision, arrival and recovery contracts.
- [Godot MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)
  and [servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html):
  batch repeated geometry and updates while retaining articulated pivots and correct
  culling. Do not replace gameplay objects merely because they have many instances.
- [Typed GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html):
  type math and hot references to enable optimized opcodes where measurements justify it.
- [Thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html):
  active scene-tree access is not thread-safe; arbitrary per-unit threads are not
  a safe optimization. Test render-thread changes independently before adopting them.

## Initial evidence

**Superseded diagnostic results:** the original fixture briefly removed every
starter army while the match was running. This eliminated all four players and
opened the result dialog before the replacement armies spawned. Population and
firing checks still passed. The figures in this section cannot certify active
match performance. Setup now pauses outcome checks during replacement, and the
fixture asserts that the match remains active before and after measurements.

Revision `8f9f71ca`, Godot 4.7.2 official editor/debug engine, Vulkan Forward+.
VSync disabled, full 3D raster, no fixed FPS. Two runs measured movement means
101.53 / 105.86 ms and combat means 72.00 / 69.27 ms. Workload checks passed;
GPU means were 4.57–6.80 ms, far below whole-frame time.

An instrumented callback pass identified movement velocity/contact handling
(1.98 seconds across 241 movement ticks), animation (1.11 seconds across
102 rendered movement frames; 1.37 seconds across 146 combat frames), followed
by visibility and minimap work. Instrumentation has overhead and this run had
different system timing; its FPS is not an optimization result.

A diagnostic with body animation disabled retained 8,413 MeshInstance3D nodes
and roughly 9,000–12,000 draw calls. It measured 43.47 / 27.64 ms movement/combat.
This invalidates the full presentation workload and is diagnostic evidence only.
It establishes that animation/transform propagation and rendering submissions,
as well as simulation, need attention; disabling animation is not the solution.

## Implementation and final verification

Investigation in progress. Final matched-workload results and regression evidence
will be recorded here after changes have been measured.

Corrected fixture, full rendering, focused window, official debug engine,
uncontended serial runs on October 25:

| Version | Movement mean | Combat mean |
| --- | ---: | ---: |
| Latest main `8f9f71ca` | 67.12 ms / 14.90 FPS | 48.74 ms / 20.52 FPS |
| Candidate before projection/contact changes | 61.78 ms / 16.19 FPS | 40.02 ms / 24.99 FPS |

The candidate includes exact damped suspension integration, detached mobile
presentation roots, one movement transform publication, cached visibility and
orthographic directional shadows. Navigation projection and crowd recovery
regressions pass after the later projection-interior cache and packed contact
changes. Animation, movement, combat, wheel motion, infantry death grounding,
battle feedback, save/navigation timing and rendered interpolation regressions
also pass. These gains do **not** meet either performance target.

The architecture now includes:

- GPU pose palettes and merged material variants: shared MultiMeshes receive
  articulated world poses through a texture, retaining authored object-space
  texture coordinates. Static decoration is merged in spatial chunks.
- A compute shader interpolates each articulated part once per displayed frame,
  shared by the model's surfaces and shadow passes. Rotation interpolation uses
  normalized quaternions and preserves scale, including mirrored geometry.
- Decorative mesh leaves are parked beneath a stationary, hidden scene root,
  outside the unit's changing transform hierarchy. Visibility notifications stay
  live, as do animation pivots and weapon sockets. Wreck/fog-memory cloning restores
  the complete posed hierarchy temporarily; destruction frees parked leaves.
- A small native C ABI extension gathers current transforms on the main thread
  and packs the GPU upload. It avoids thousands of GDScript buffer writes; it does
  not access scene nodes from worker threads. Unsupported platforms and missing
  binaries retain the ordinary renderer.
- The native module also runs unfiltered nearby-unit searches. It preserves cell
  traversal order, live positions and deletion checks; filtered ownership queries
  retain the script path. Regression tests compare both ordered result arrays.
- CPU body dynamics use [WorkerThreadPool group tasks](https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html).
  Independent state and input transforms are prepared on the main thread, four
  worker lanes calculate results, and a join precedes scene publication. The
  batch threshold avoids dispatch overhead for small armies.
- Infantry workers execute the full gait, stance, torso, arm and leg solver on
  private transform values. No active Node, rendering resource or gameplay RNG
  is touched by these jobs. The coordinator publishes completed local transforms
  and resolves immediate firing poses on the main thread.
- Animation significance scheduling follows the approach described in Epic's
  [Animation Budget Allocator](https://dev.epicgames.com/documentation/unreal-engine/animation-budget-allocator-in-unreal-engine).
  Root motion and weapon authority must remain continuous, with selected/nearby
  units and immediate reactions receiving full updates.

Shader failures, missing geometry, ended matches, diagnostic feature disabling,
and runs overlapping another benchmark are disqualified.

## Corrected release measurements

Official 4.7.2 release engine, identical corrected fixture and 1920×1080 viewport,
focused window throughout, serial uncontended runs on October 25:

| Version | Movement FPS | Combat FPS | Movement / combat p95 |
| --- | ---: | ---: | ---: |
| Latest main `8f9f71ca` | 22.87 | 26.20 | 57.23 / 60.52 ms |
| GPU batches, native uploader, all material families | 56.34 | 72.73 | 29.64 / 29.68 ms |
| Batched body staging, serial chassis jobs | 58.72 | 77.64 | 28.05 / 26.28 ms |
| Batched body staging, parallel chassis jobs | 60.10 | 78.04 | 28.04 / 27.16 ms |
| Native queries, full pose pipeline executed serially | 59.90 | 68.83 | 28.47 / 31.48 ms |
| Native queries, parallel chassis and infantry | 60.08 | 79.53 | 29.07 / 25.36 ms |
| Above plus engine navigation avoidance workers | 62.77 | 80.69 | 27.26 / 24.96 ms |
| Final implementation, repeat 1 | 63.68 | 82.41 | 27.15 / 25.24 ms |
| Final implementation, repeat 2 | 63.19 | 70.32 | 27.44 / 31.79 ms |

The two final runs include hidden-anchor handling and removal of the redundant
upload allocation. All 280 units remained, real firing continued, every sample
had window focus, and both release runs exited without errors. Combat variability
is material: report the observed **70.32–82.41 FPS** range, not just the best run.
The final movement range is **63.19–63.68 FPS**. Raw output, timing percentiles,
workload settings and the native DLL hash are saved in
[windows-ffa-multicore-measurements.json](windows-ffa-multicore-measurements.json).

These are averages, not minimum FPS guarantees. The complete worker pipeline
improved combat versus its identical serial control, while movement was nearly
unchanged. Navigation workers then improved both phases in this comparison.
These short runs demonstrate a substantial improvement over main, but do not
establish sustained 120 FPS or a 60 FPS minimum. GPU time remains around 3–4 ms;
simulation ticks and scene publication still cause long frames. Increasing the
thread count alone cannot eliminate work that must touch Godot's active scene tree.

Rejected experiments include many tiny per-limb jobs (57.49 / 76.51 FPS), a
per-surface hit-flash pass that doubled geometry, and naive per-mesh batching.
An earlier separate-render-thread experiment produced texture/lifecycle errors;
the default renderer thread setting remains unchanged. A separate physics-thread
experiment produced inaccessible-space query errors and crashed; it is disabled.
Navigation avoidance workers were neutral in an earlier debug comparison, but
are enabled after the release comparison with the new architecture.

## Building and validating the native path

On Windows x86-64 with standard-precision Godot, run:

```powershell
python tools/build_native.py --download-toolchain
# Or supply an existing compiler, without downloading:
python tools/build_native.py --zig C:/path/to/zig.exe
godot --path . --script tests/rendered/FourPlayerFrameBenchmark.gd -- --no-capture
```

The builder pins the official Zig 0.17.0 archive and verifies SHA-256 before
extraction. The public Godot 4.4 C ABI header retains its MIT license. Generated
DLL/config files live in ignored `native/bin/`; the Windows release builder
packages that directory beside the executable. No system compiler installation
is required. `--disable-unit-batching` retains the ordinary renderer for comparison;
`--serial-pose-jobs` keeps identical batching while executing CPU math serially.
`--no-infantry-workers` retains chassis workers and the ordinary infantry solver
for diagnosis. Neither diagnostic flag is used for the final optimized result.

New validation includes native matrix packing/deleted objects, GPU output readback
for quaternion interpolation/reflections/visibility, multi-thread execution and
serial numerical equivalence, full infantry pose comparisons across three
factions/five roles, and rendered batch lifecycle and interpolation tests.
GPU readbacks occur only in correctness tests, never in the game's pose pipeline.

Validated on this PC: native packing and hidden/deleted anchors; four-thread
chassis equivalence; ordered spatial-query equivalence; infantry gait/IK/shot
poses across three factions and five roles; complete unit animation; combat;
crowded movement, recovery, harvesting and factory exits; navigation projection;
GPU interpolation; rendered cloning, fog visibility, part hiding and destruction;
rendered frame pacing for all three factions. The new infantry test uses the
game's audio-draining shutdown path. Existing combat and projection tests pass
their assertions but still report resource warnings during their direct shutdown.

## Remaining 120 FPS work

The next architectural boundary is scene publication. Workers currently calculate
private pose state, then the main thread writes bone nodes and reads their world
transforms for the GPU upload. A compact parent-indexed pose array could calculate
world matrices in workers and upload directly, retaining only weapon sockets and
gameplay transforms in the scene tree. This would remove the write/read round trip.
It requires coverage of equipment changes, hit reactions, wreck snapshots and fog
memories before replacing the current authoritative hierarchy.

Movement/contact resolution also remains synchronous. Parallelizing it safely
requires immutable per-tick spatial snapshots and a deterministic resolution pass;
calling existing Node-based movement callbacks concurrently is unsafe and can
change collision/order semantics. Neither of these larger changes is claimed as
implemented or as a demonstrated path to 120 FPS yet.
