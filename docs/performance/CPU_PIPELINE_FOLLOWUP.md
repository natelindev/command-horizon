# CPU pipeline follow-up — 2026-10-25

Implemented all four proposals, with transform decoupling available behind
`--enable-decoupled-poses`. The complete decoupled path was slightly slower on
the available Mac, so it is not enabled by default. The registry and native
simulation improvements remain active on their supported runtime paths.

## Changes and behavior

- `Match` shares immutable membership snapshots with battlefield, visibility,
  repair, minimap and visual consumers. Spawn, capture/reparent, removal and
  vision changes invalidate them. Invalidation also runs after tree exit:
  callbacks can rebuild a snapshot before the departing node leaves its groups.
- Native contacts evaluate four candidates together, then reduce in traversal
  order. The original clipping, sliding, domain, ghost and speed rules remain.
  Owner masks read live ownership, including same-tick capture; fixtures with
  more than 63 registered owners fall back to script filtering.
- Opt-in articulated poses use parent-indexed worker data and native matrix
  composition. The packer consumes the resulting palette without writing bone
  transforms into the SceneTree. Weapon origins synchronize immediately.
  Inert source nodes remain for visibility, cloning and fallback restoration;
  they are not deleted. Research sensors share the same pose proxies.
- Avoidance threading is explicitly global. It was already effectively enabled
  on the tested Mac, so this setting did not produce a measured gain there.

The existing Windows native default is retained. Mac/Linux host builds are
available for validation via `--enable-native-kernels`; missing or stale native
binaries retain the ordinary renderer and script simulation. Release packaging
still ships native kernels only on Windows. No graphics settings, meshes,
shaders, animation budgets, collision rules or simulation frequency were reduced.

## Measurements

Godot 4.7.2 official editor/debug, Apple M1 Pro, Metal Forward+, 1920×1080,
VSync off, 30 Hz physics. `FourPlayerFrameBenchmark` retains 200 mobile units,
80 structures, physical weapons and real-time rendering. Its commander AI is
disabled and unit HP is increased; this is not a full live-match benchmark.
Every sample in the following runs was focused and rendered.

| Pipeline | Movement mean / p95 (ms) | Combat mean / p95 (ms) |
| --- | ---: | ---: |
| Original `6e41c35f` | 21.90 / 33.87 | 20.88 / 34.52 |
| Registry + native simulation, selected default | 21.65 / 33.39 | 21.04 / 34.84 |
| Including decoupled poses | 22.22 / 34.18 | 21.26 / 35.87 |

These results show no material whole-game speedup. The selected default is
approximately neutral; the decoupled path added about 1.5% movement and 1.8%
combat frame time in this comparison. Earlier repetitions also failed to show
a decoupling gain. Windows release measurements are still required before
enabling it by default or claiming improved FPS on the target PC.

The two-neighbor contact microbenchmark measured **2.379 µs in script versus
1.188 µs native**, about twice as fast for that kernel. It does not measure
spatial lookup, navigation, rendering or total frame time. The final workload
checks reported zero failures and 157–158 shots, with all 280 units retained.

Raw benchmark output is retained in `cpu-pipeline-followup-results.json`.
The baseline was reconstructed from `6e41c35f`; its only native changes enabled
the existing Windows-only uploader on macOS and made its export annotation
portable. Assets and imported resources were shared with the candidate.
These measurements precede integration with `7361139f` (teams, capture and repair
platforms); they should not be treated as fresh benchmarks of the combined game.

## Verification

- `DecoupledPoseRegression`: native and script hierarchy solvers; three factions,
  15 roles, movement, turning, aiming, firing, stopping, teleporting, research
  sensors and fallback. Compares every descendant pose with the original
  SceneTree solver and asserts that source transforms stay frozen.
- `NativeContactRegression`: 2,500 live-state comparisons plus contact ordering.
  `SpatialQueryRegression`: ordered native/script filtering and same-tick
  ownership changes. `NativePoseRegression`: array packing, stale source nodes,
  mirrored scale, visibility and freed anchors.
- `UnitRegistryRegression`: snapshot reuse, spawn, capture, aircraft removal,
  dynamic vision, resources and deletion callbacks that read the cache.
- Existing checks passed for visibility, parallel and infantry workers, unit
  animation, ground motion, crowded and mixed armies, harvesting, contact
  approach, combat, garrison exits, persistent capture, save/navigation timing,
  save restoration, rotorcraft, fixed-wing flight and runtime shutdown.
- Rendered `UnitBatchRegression` and `FramePacingRegression` cover the default
  and decoupled paths. `GpuPoseRegression` validates GPU interpolation, mirrored
  scale, hit pulse and hiding. The frame-pacing tests use a fixed 1280×720
  viewport so Retina desktop size does not turn GPU readback into the bottleneck.

Some older headless fixtures report retained audio resources on abrupt exit;
the new fixtures and shutdown checks exit cleanly. Formatting and Python
compilation pass. GDScript lint retains two pre-existing findings: return count
in `UnitBatchRenderer._eligible` and declaration order in `BastionVisuals`.
The pre-existing Metal batched-material color discrepancy also reproduced with
the original renderer; this change does not certify that experimental renderer
for a new platform.

## Reproduce

Build with `python3 tools/build_native.py` on macOS/Linux, or
`python tools/build_native.py --download-toolchain` on Windows. Supply the
appropriate local Godot executable as `GODOT` below.

```sh
"$GODOT" --headless --path . --fixed-fps 60 \
  --script tests/headless/NativeContactRegression.gd -- --enable-native-kernels
"$GODOT" --headless --path . --fixed-fps 60 \
  --script tests/headless/DecoupledPoseRegression.gd -- --enable-native-kernels
"$GODOT" --path . --script tests/rendered/FourPlayerFrameBenchmark.gd \
  -- --no-capture --enable-native-kernels
"$GODOT" --path . --script tests/rendered/FourPlayerFrameBenchmark.gd \
  -- --no-capture --enable-native-kernels --enable-decoupled-poses
```

Run rendered comparisons serially, with the window focused, without
`--headless`, `--fixed-fps` or diagnostic workload reductions. Use
`--disable-native-kernels` to exercise ordinary rendering and script queries.
