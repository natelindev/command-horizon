# Battlefield polish — release frame measurements

Updated 2026-10-24. The final v19 macOS runtime passes both working budgets in
two native foreground runs per workload: **14.95 / 16.53 ms p95** for ordinary
70-unit combat (16.7 ms target), and **28.57 / 30.70 ms p95** for 200 mobile units
plus 80 structures (33.3 ms target). Across 4,557 unique gameplay frames, including
ordinary warm-up, the maximum is **40.50 ms**, with none over 50 or 100 ms.
Loading-time effect preparation preserves paused gameplay and cosmetic state.
The [current v19 results](../2026-10-24/macos-current-v19-performance.json) retain
all four accepted runs, source/artifact hashes, focus evidence and limitations.
The earlier clean Windows run remains **36.80 ms p95**, above 33.3 ms.
Windows and the reported four-player FFA low frame rate
are explicitly deferred at the user's request; see the
[Windows handoff](../2026-10-24/WINDOWS_HANDOFF.md).

## Environment and method

Godot 4.7.2 stable official (`ed1daf0bf`) release templates, full-resolution
1920 × 1080 rendering, Forward+, VSync disabled, no frame cap, 30 Hz physics
with interpolation, and real-time simulation. macOS uses an Apple M1 Pro,
32 GiB RAM, macOS 27.0.1 (`26A434`) and Metal. Windows uses a Ryzen 7 5800X3D,
32 GiB RAM, RTX 4090, driver `32.0.16.1742`, Windows 11 build 26200 and Vulkan.
GPU duration is unavailable on the Mac; all reported frame times are wall-clock.

Each measured process runs without competing engine tests or exports on that
machine. The first final Mac scale and ordinary runs use independent game user
caches; OS and driver caches were not reset. Percentiles remain per run and are
not pooled. Scale phases each cover ten simulation seconds. Ordinary phases
sample 240 rendered frames after at least three seconds of warm-up. The ordinary
fixture cancels setup production and asserts exactly 70 combat units, then kills
eight tanks for the destruction sample.

Official release templates ignore the editor's `--script` entry-point override.
The measured release apps therefore use an isolated staging project with the
benchmark as a custom SceneTree main loop and an empty required bootstrap scene.
The wrapper frees that scene before running the shared benchmark. Source,
executable/PCK hashes, wrapper text, staging settings, arguments and raw logs are
retained in the [current v19 report](../2026-10-24/macos-current-v19-performance.json)
and [historical release measurements](../2026-10-24/release-measurements.json).
Normal game exports use the production main menu and are checked separately.

## Current v19 macOS results

All values below are milliseconds, shown as fresh game-cache / repeat-process
warm game-cache runs. OS and driver caches were not reset. Native foreground PID
samples bracket each preparation/gameplay phase, with no in-engine focus loss.
The production source and assets match the final v19 package file for file.

| Workload | Mean, run 1 / 2 | p95, run 1 / 2 | Working budget |
| --- | ---: | ---: | --- |
| 30-unit base | 12.80 / 13.48 | 13.15 / 14.39 | Reference |
| 70-unit combat | 14.25 / 15.07 | 14.95 / 16.53 | 16.7, both met |
| Eight-tank destruction, subsequent 62-unit combat | 14.52 / 14.05 | 16.19 / 15.84 | 16.7, both met |
| 200 mobile + 80 structures, movement | 19.48 / 20.75 | 27.51 / 28.46 | 33.3, both met |
| 200 mobile + 80 structures, combat | 22.99 / 25.10 | 28.57 / 30.70 | 33.3, both met |
| Command-feedback submission at maximum population | — | 30.62 / 32.86 | 100, both met |

First-combat warm-up maxima are 39.74 / 40.50 ms; destruction warm-up maxima are
16.96 / 17.05 ms. Stress movement maxima are 32.05 / 34.13 ms, and combat maxima
33.48 / 37.25 ms. All four accepted processes exit without warnings or errors.
Stress retains the original full ten-simulation-second phases with AI disabled;
the reported first-three-second subdivisions are diagnostic subsets and are not
counted twice or substituted for the full-phase budget. This synthetic two-player
workload does not validate the reported four-player FFA scenario.

The production preparation helper takes 1,653.54 / 154.03 ms in the ordinary
fixture and 1,702.39 / 564.21 ms in stress. These are helper-only costs, excluding
fixture setup, and are not end-to-end loading times. Every accepted run preserves
the full paused snapshot, cosmetic RNG/pools, node identities/count and process
modes. The first stress attempt was rejected because its baseline preceded
completion of navigation initialization and construction-rig cleanup. A retained
diagnostic identifies the exact changes; the corrected private fixture waits for
those readiness conditions and a further stable physics/process/draw cycle
before measuring. No production code changed for this fixture correction.

The immutable raw reports retain an incorrectly labeled aggregate source hash
caused by differing file-sort conventions. The
[hash correction](../2026-10-24/macos-current-v19-hash-correction.json) verifies
every file in the 5,539-file release manifest and the package's aggregate hash. This correction and
the rejected run are linked from the accepted summary, rather than overwriting
their original evidence. Two runs on one Mac establish these scenario results;
they do not establish long-match, cold-driver or all-device guarantees.

## Historical macOS baseline results

All times are milliseconds. Both scale runs have all 200 mobile units moving and
travelling; 112 and 107 units fire. The full 1920 × 1080 raster is asserted.

| Workload | Mean | p95 | Working budget |
| --- | ---: | ---: | --- |
| 30-unit base | 12.83 | 13.71 | Reference |
| 70-unit combat | 14.46 | 15.41 | 16.7, met |
| Eight-tank destruction, subsequent 62-unit combat | 14.31 | 15.32 | 16.7, met |
| 200 mobile + 80 structures, movement, run 1 / 2 | 20.94 / 20.20 | 28.89 / 28.10 | 33.3, met |
| 200 mobile + 80 structures, combat, run 1 / 2 | 24.89 / 23.99 | 30.46 / 29.84 | 33.3, met |
| Command-feedback submission at maximum population, run 1 / 2 | 24.28 / 23.74 | 28.73 / 31.92 | 100, met |

No sampled scale frame or ordinary/burst warm-up frame exceeds 100 ms. Scale
combat maxima are 37.70 / 35.72 ms; the first movement maximum is 64.40 ms and the
repeat is 33.01 ms. Ordinary combat warm-up reaches 52.72 ms; the destruction
warm-up, including the synchronous eight-tank destruction, shockwaves and wreck
creation, reaches 47.76 ms. All three baseline release runs exit with zero failures
and no script, rendering, resource or teardown diagnostics.

The input probe selects 24 units and sends ten commands. It measures engine event
dispatch to feedback-frame submission. It does not measure a physical mouse,
monitor refresh or input-to-photon latency.

## Historical macOS foreground and first-use investigation

The same production runtime was measured with a wrapper that waits for native
foreground ownership and a separate read-only AppKit observer sampled every
250 ms. All 44/45 scale-phase samples and 24/25/25 ordinary-phase samples matched
the game PID; no in-engine phase lost-focus event occurred. Stress combat measured
24.19 ms mean / 29.94 ms p95 and input-feedback submission 27.80 ms p95. Ordinary
combat measured 14.01 / 14.95 ms; destruction aftermath measured 13.95 / 14.89 ms.

This fresh test user cache exposed two movement frames above 100 ms, with a
989.21 ms maximum, plus 1,377.54 ms combat and 934.05 ms destruction warm-up
frames. Those observations supersede any general inference of stall-free play
from the earlier three clean runs. A same-binary diagnostic with its dedicated
user cache renamed aside did not reproduce the long stalls: movement maximum
51.43 ms and combat maximum 36.19 ms. The 51.41 ms frame coincided with new
pipeline counts. OS/driver caches were not reset, so this does not prove the
cause or a fix. A [bounded traced first-use run](../2026-10-24/macos-stall-attribution/diagnostic.json)
reproduced 1,498.74 / 1,049.27 ms stalls alongside new draw/surface pipelines, new
shader-cache files and Metal compiler stacks. Generated shader identifiers in
those new cache files map them to hit flashes, ground scars and shockwaves;
[cache attribution](../2026-10-24/macos-stall-attribution/decoded-cache-attribution.json)
records hashes and timestamps. Aggregated stripped-binary stacks alone do not
identify the blocking effect.

An [isolated prototype](../2026-10-24/macos-prewarm-prototype/diagnostic.json)
renders disposable cosmetic proxies under a loading cover in the same viewport.
It spends 902.50 ms preparing the variants, then records 79.66 ms maximum at first
combat and 46.58 ms at the destruction burst, with no gameplay/warm-up frame over
100 ms. All native focus samples match the owned process, full paused save and
cosmetic states match, node counts return to 6,691, and exit diagnostics are empty.
This run includes sampling overhead and leaves OS/driver caches uncontrolled;
it is evidence for the approach, not final runtime acceptance.

The [production helper](../2026-10-24/macos-prewarm-production/diagnostic.json)
warms only the identified hit-flash, ground-scar and shockwave paths under the
loading cover. In its frozen v18 release run, preparation took 2,166.66 ms;
first-combat and destruction maxima were 38.48 and 17.26 ms. All six warm-up/steady
phases had no frame over 50 ms, and all 74 native foreground samples matched the
owned process. The full paused snapshot and node count were unchanged, and the
release exited without diagnostics. Separate regression checks cover reduced
flashes, disabled ground detail, live cosmetic pools/RNG, real terrain identity,
loading cancellation and paused restoration. The raw report retains broad
pre-import hash flags that failed because translation import and a later test-only
edit changed the stage; immutable EXE/PCK and production-source identity were
independently verified. This run precedes queued research, commander status and
the later restore-cancellation cleanup; it is not the final v19 package result.

## Windows results

Windows work is paused by the user's explicit instruction. The preserved platform record is
[windows-performance.json](../2026-10-24/windows-performance.json), with retained
raw logs, source/build identities and process-load evidence. The clean native
foreground repeat passed its workload and focus checks: all 27 post-grant Win32
HWND/PID samples matched the benchmark; neither phase had a Godot focus-loss
event. Combat measured 31.89 ms mean / 36.80 ms p95, movement 24.00 / 35.77 ms,
and input-feedback submission 40.41 ms p95. Combat GPU/render-CPU averages were
5.53 / 6.72 ms. No measured frame exceeded 100 ms. The 33.3 ms stress target
remains open. A completed foreground profile confirms spatial queries, movement
callbacks and terrain projection as hot paths. Its ten snapshots are normalized
by independently checked physics-tick counts; the subsequent CPU patch still
needs a release timing run.

Earlier idle release combat p95 values of 39.00 / 40.77 ms lacked verified
foreground focus. A diagnostic profile confirmed Battle.net foreground in all
seven native checks. A subsequent wrapper exposed Godot reporting focus while
Win32 still identified Battle.net, so an independent native token now gates the
benchmark. One run lost focus during movement and is excluded as a clean full
run; its uninterrupted combat phase measured 38.15 ms p95. These records retain
their distinct limitations.
A run made while Heroes of the Storm was active is explicitly confounded and
excluded from acceptance.
Navigation-threading diagnostics did not establish a convincing gain; the
existing Windows project setting was preserved.

## Changes supported by profiling

The implementation avoids repeated work while preserving live gameplay inputs:
unchanged health-bar pixels and hit materials are reused; rank factors update on
rank changes; flat terrain exits before elevation work; walker rest geometry and
unchanged infantry carry poses are reused; airfield lookup uses the live group;
movement reuses speed only within one synchronous call; repair modifiers and
power factors are shared only within one service pass; spatial refresh resolves
one navigation trait and avoids transient key arrays. Off-camera rigs already
stop expensive posing and resume when visible. Regressions cover rank resets,
live power changes, motion, crowd recovery, spatial queries and saved state.

These combined changes improve the measured workload, but the short series does
not isolate individual contributions or establish long-match thermal behavior.
No graphics-detail or simulation-rate reduction was used to meet the Mac target.

A subsequent movement/projection pass narrows settled-ally endpoint queries,
avoids duplicate ground movement calculations and stops flat-map projection at
the first containing indexed polygon. All ten focused correctness checks pass,
including new live endpoint eligibility cases; logs and before/verified source
hashes are retained in [cpu-hotpath-validation.json](../2026-10-24/cpu-hotpath-validation.json).
The current v19 Mac measurements above include this pass and satisfy the targets;
they do not isolate its individual contribution. Its Windows timing remains
deferred.

## Historical diagnostics and reproduction

The earlier [editor/debug measurements](measurements.json) and unchanged
`06d2df35bf89836a3efa3e996935f198d6e73485` baseline used the same 4.7.2 editor
executable. They are not a matched baseline for the release template and are not
presented as final release results. An earlier ordinary release sample accidentally
rendered 8295 × 5206 pixels because of inherited DPI scaling. Its raw record is
retained as `macos_battle_unpinned_raster_diagnostic`; it is excluded from the
ordinary budget. The fixture now pins viewport scaling and asserts actual pixels.
An early 944.85 ms movement spike did not recur in the independent-cache or final
runs; its cause was not established.

For a diagnostic editor run, use the commands below without `--headless`,
`--fixed-fps` or render-loop suppression. To reproduce release-template results,
export the staged custom-main-loop project recorded in the release JSON; passing
`--script` to an ordinary release executable does not run this benchmark.

```sh
godot --path . --script tests/rendered/BattleFrameBenchmark.gd -- --destruction-burst
godot --path . --script tests/rendered/ScaleFrameBenchmark.gd \
  -- --behaviors --realtime --no-capture --input-latency
```

The old particle-resource shutdown warning is resolved and native normal-game
quit is checked separately from forced `--quit-after` teardown. Real novice
trials, subjective listening, physical input/display latency, cold OS/driver
caches and long-match stability remain distinct acceptance work.
