# Experimental threaded-rendering engine

`godot-4.7.2-threaded-rendering.patch` records the engine changes used by the
macOS performance investigation. It applies to the official Godot 4.7.2 stable
source archive (SHA-256
`a18ce0ccec3ecc40b0dd6c4f5132ca934e9fb7c2979717940ff32aee1eb35481`).
Godot engine changes retain its [MIT license](https://github.com/godotengine/godot/blob/4.7.2-stable/LICENSE.txt).

Ordinary Godot builds still use Safe rendering by default. The optional patched
runtime advertises `copperfin_optimized_macos`, which selects the separate render
thread and the verified native runtime allowlist. This is not a claim that the
60 FPS target is qualified. See
[the performance report](../../../docs/performance/2026-11-07-gameplay-performance.md).

The patch addresses five observed failures:

- Snapshot queued 2D texture images so later CPU edits cannot race their upload.
- Return device ownership to the main thread after the render pump joins at exit.
- Dispatch interpolated MultiMesh buffer uploads on the rendering thread.
- Reject stale RID generations before diagnosing an uninitialized allocation.
- Collect visible particle RIDs during parallel culling, then update their view
  axes after the join in the same render pass. Deferred worker callbacks could
  otherwise run after the particle was freed, or after its intended draw.

Apply from an extracted engine source directory with `git apply` (a Git checkout
is not required). The source archive must be clean. Build a release template
using the official Godot macOS build instructions and run it against an exported
game pack. Project scripts are not a substitute for a release export.

The local Apple Silicon investigation uses `platform=macos arch=arm64
 target=template_release production=yes optimize=speed debug_symbols=no
 vulkan=no metal=yes profiler=none lto=thin`, with `-mcpu=apple-m1` compiler flags.
Profile-guided optimization is separate from the correctness patch. Acceptance
must use a build without counter instrumentation or diagnostic callbacks.

`tests/rendered/ParticleQueueLifetimeRegression.gd` creates and retires 4,608
emitters while rendering. Run it without `--headless` and with
`--render-thread separate`; reject any engine error even if the script exits 0.
Off-camera static instances ensure parallel culling at the default threshold.
The initial focused reproduction instead used a threshold of 32. Recheck the GPU palette,
fog, frame-pacing, model-batch, track and charge-spark regressions before enabling
the mode. Other platforms are not yet verified.

`godot-4.7.2-empty-instance-transforms.patch` is a separate performance change.
It skips server transform uploads when a visual instance has no rendering base,
while retaining its scene transform and visibility for its descendants. Restoring
a base publishes its current transform immediately. The project clears/restores
batched source meshes through `VisualInstance3D.set_base` so that the node and
server agree about this state. Apply this patch after the correctness patch.
`tests/rendered/EmptyMeshTransformRegression.gd` checks moving children and mesh
restoration, with and without interpolation, in 108 actual image comparisons.

## Build and package on Apple Silicon

Use Python 3.12 or newer, Xcode Command Line Tools and an installed Godot 4.7.2
editor with its macOS export template:

```sh
python3 tools/performance/engine/build.py build --jobs 6
python3 tools/performance/engine/build.py status
python3 tools/performance/engine/build.py package \
  --engine /absolute/path/from/build/output \
  --editor /absolute/path/to/Godot.app/Contents/MacOS/Godot \
  --output build/optimized-macos
```

The build command verifies the pinned archive, applies all three patches, and
compiles an uninstrumented release template with O3 and ThinLTO. `--archive PATH`
can reuse the same source archive locally. Optional `--profile PATH` consumes a
merged LLVM `.profdata` file; training data must come from representative play
and must never be used as FPS evidence. Receipts record the source, patch,
profile and binary hashes. The default build does not require training data.

Packaging freezes the game source, builds a universal native library, exports
with the official template, installs the patched engine, and signs the app.
Before producing the playable app and ZIP, it runs an isolated release startup
fixture that checks the native runtimes and optimized renderer configuration.
Use `--entry battle` for the live benchmark fixture or `--entry startup` for the
startup fixture. Those entries use a separate user-data directory. Packaging
does not mark the result as performance-qualified.

The runtime feature patch enables only the explicit allowlist in
`NativePosePacker.gd`; new experimental flags remain opt-in.
`--disable-native-kernels` still overrides automatic and explicit activation.
Missing or incompatible libraries retain the existing portable fallbacks.
These patches and packaging commands target Apple Silicon macOS; Windows and
Linux behavior has not been qualified by this investigation.

The measured release in the report uses the retained local compiler profile:

```sh
python3 tools/performance/engine/build.py build \
  --profile build/optimized-macos/qualification-profile.profdata --jobs 6
```

That profile is retained beside the local app archive, with its hash in the
build receipt. An ordinary build without it is a separate performance result.
Production builds disable loose project/script overrides, so run verification
through exported fixture main loops. Use `--headless --render-thread safe` for
dummy-renderer checks; actual Metal checks exercise the automatic separate
render thread. The threaded dummy renderer reported two material leaks in the
native-state test, while its normal headless mode passed all 40,980 comparisons.
