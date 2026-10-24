# Game polish performance — 2026-10-19

This is the dated Godot 4.6 record. The later Godot 4.7.2 polish work and release
measurements are tracked in the [23–24 October report](../playtests/2026-10-23/PERFORMANCE.md).

The matched Mac workload improved modestly while adding the new HUD feedback and
base surfaces. Maximum-population combat mean frame time fell from 28.40 ms to
27.18 / 26.85 ms in two repeats, a 4.3–5.5% reduction. This is evidence for the
combined polish pass; it does not isolate the contribution of each change.

## Reference workloads and budgets

Use the local Apple M1 Pro / Metal machine and the previously measured Windows
Ryzen 7 5800X3D / RTX 4090 machine as engineering reference systems. These are
measurement targets, not advertised minimum hardware specifications.

| Workload | Working budget | Local result |
| --- | --- | --- |
| Ordinary 70-unit combat | p95 ≤ 16.7 ms | 14.73 ms, editor executable |
| 200 mobile units + 80 structures | p95 ≤ 33.3 ms | 28.70 / 28.47 ms, macOS release |
| Command acknowledgment at maximum population | p95 ≤ 100 ms from engine event to submitted feedback frame | 28.54 / 28.41 ms, macOS release |

Budgets describe steady-state samples. The stress workload is not at 60 FPS, and
these measurements do not establish the Windows budget or eliminate cold-start
hitches. A production input-latency study also needs physical device and display
measurement; the probe here starts at engine event dispatch.

## Method

Godot 4.6 stable official (`89cea1439`), Metal Forward+, Apple M1 Pro. Scale runs use
1920 × 1080 actual rendered pixels, full 3D resolution, VSync disabled, 30 Hz
physics with interpolation, and real-time simulation. Each phase lasts ten
simulation seconds. All 200 mobile units travel; the two final release runs each
record 105 firing units. The workload also contains 80 structures and 62 resource
nodes. Runs were serial, without another test process competing for the GPU.

The baseline was captured before this polish pass, including the user's existing
command and neutral-site changes. The after samples use the same editor executable
and fixture. The release measurements use the macOS release template with a
benchmark startup scene in an isolated project copy; production startup settings
are unchanged. A regular macOS release export also launches its main menu.

Raw measurements are in [game-polish-measurements.json](game-polish-measurements.json).
Local logs are under `tmp/polish-2026-10-19/`. GPU timing returned zero on this
platform, so no GPU-duration conclusion is drawn from that field.

## Matched editor comparison

| Phase | Run | Mean | p95 | p99 | Frames > 1/30 s / samples |
| --- | --- | ---: | ---: | ---: | ---: |
| Movement | Before | 23.23 | 32.33 | 35.93 | 16 / 431 |
| Movement | After 1 | 22.51 | 30.79 | 33.31 | 4 / 445 |
| Movement | After 2 | 22.39 | 30.62 | 34.18 | 7 / 448 |
| Combat | Before | 28.40 | 33.41 | 35.35 | 18 / 352 |
| Combat | After 1 | 27.18 | 32.17 | 34.28 | 7 / 368 |
| Combat | After 2 | 26.85 | 31.78 | 33.25 | 3 / 372 |

Frame times are milliseconds. Differences this small remain sensitive to system
and simulation variance; repeated samples support a modest improvement, not a
large-battle performance breakthrough.

CPU profiling identified scene-tree/unit presentation, movement callbacks and
battlefield queries as the principal costs, with ambient route lookup and walker
pose work also visible. This pass caches immutable route segment distances and
uses binary search for lookup, replaces walker leg dictionaries with typed
records, and avoids writing unchanged leg transforms. Route equivalence and
all-faction animation regressions pass. Ordinary impacts also create fewer
decorative particles; large debris bursts are reserved for destruction.

## Native release and input samples

| Phase | Run | Mean | p95 | p99 | Maximum | Frames > 100 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Movement | Release 1 | 19.69 | 27.09 | 29.63 | 31.94 | 0 |
| Movement | Release 2 | 19.90 | 27.17 | 30.06 | 32.46 | 0 |
| Combat | Release 1 | 23.76 | 28.70 | 30.34 | 33.97 | 0 |
| Combat | Release 2 | 23.37 | 28.47 | 30.09 | 36.57 | 0 |

These correspond to `scale-release-input.log` and `scale-release-repeat.log`.
There is no matched pre-change release export, so the release/editor difference
must not be presented as an optimization gain.

After each combat sample, the fixture selects 24 units and injects ten mouse
commands through the viewport. Each must produce an accepted destination marker.
Event-to-feedback-frame submission mean / p95 was 24.90 / 28.54 ms and
24.49 / 28.41 ms. The probe runs after the frame-time sample so commands cannot
change the matched combat workload. Ten samples give only a coarse tail estimate.

Earlier release launches recorded movement wall times of 11.07 and 10.78 seconds
for 10.03 seconds of simulation, with mean frame times of 22.64 and 22.46 ms.
Maximum-frame logging was not yet present. Their cause was not isolated. The final
instrumented repeats did not reproduce that delay; this does not prove cold-start
stalls are fixed. Those earlier measurements remain in the raw record.

The ordinary rendered fixture measured a 30-unit base at 9.22 / 11.88 ms mean/p95
and 70-unit combat at 11.24 / 14.73 ms. Its actual viewport was 2304 × 1296, so it
is a separate workload rather than a direct comparison with the scale fixture.

## Remaining platform evidence

No Windows machine was available for this pass. The last recorded Windows stress
combat result remains 48.84 ms mean / 64.69 ms p95 / 73.57 ms p99 in
[WINDOWS_FRAME_PACING.md](WINDOWS_FRAME_PACING.md). The Mac results cannot be used
to claim that bottleneck is resolved. Rerun the same release workload on Windows,
including maximum-frame and input probes, before making a cross-platform claim.

## Reproduction

Run without `--headless` or `--fixed-fps`:

```sh
godot --path . --script tests/rendered/ScaleFrameBenchmark.gd -- --behaviors --realtime --no-capture --input-latency
godot --path . --script tests/rendered/BattleFrameBenchmark.gd
```

The native release template ignores `--script`; export a fixture startup scene
from an isolated project copy to measure release code. Do not accidentally report
the main menu as a benchmark. Keep the production `project.godot` unchanged.
