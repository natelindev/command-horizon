# Air combat rendered performance — 2026-10-20

Measurements use Godot 4.6 stable (`89cea1439`), Metal Forward+, macOS 27.0.1,
Apple M1 Pro and 32 GiB RAM. These are local editor/debug executable samples,
not packaged release or cross-platform results.

## Method

`ScaleFrameBenchmark.gd` runs at an internal 1920 × 1080 viewport, full 3D
resolution, VSync off, uncapped rendering, 30 Hz physics and interpolation.
It restores the standard graphics settings, including shadows, AO, glow,
fog and ground detail. Avoidance threading is enabled. Each phase measures
10 simulation seconds in real time; no `--fixed-fps` is used.

The baseline is unchanged main `26ebdcd9`; the candidate is `b22f40b7`.
All 3,981 baseline source/asset and
benchmark files were checked against Git before running it. The same engine
binary runs both revisions. One warm-up per variant is excluded. Measured
runs are serialized, with three cycles of baseline, integrated common roster
and integrated aircraft roster. No other Godot test runs concurrently.

Both workloads have 200 mobile units and 80 structures on Big Arena:

- **Common roster:** 40 each of Tank, Drone, CombatRobot, Helicopter and
  RepairRobot. This is the before/after comparison, using the same spawn
  positions and Guard orders. It retains each revision's actual mechanics,
  including the new helicopter ammunition limit; it is not a claim of
  identical weapon activity.
- **Aircraft roster:** 26 each of Tank, Drone, CombatRobot and Helicopter,
  plus 24 each of RepairRobot, AntiAirVehicle, Fighter and Bomber. Aircraft
  have unlimited stores for sustained stress. Main lacks the three new
  roles, so there is no equivalent pre-redesign sample.

The fixture keeps units alive with extra health and checks movement and
weapons activity. A separate headless probe observed live rounds from
mobile AA, fighters, bombers and helicopters. The stock `fired` counter
tracks generic attack metadata and does not count fixed-wing releases.
Old projectile-effect counts and new physical-round counts have different
representations and should not be compared as equivalent workloads.

GPU timing returns zero on this Metal device, which means it is unavailable.
Wall-clock frame intervals are the performance evidence. Raw per-run timing,
simulation progress, resolution and workload counts are recorded in
[air-combat-measurements.json](air-combat-measurements.json).

## Results

Values below are medians of three per-run statistics, in milliseconds. They
are not percentiles pooled across all frames.

| Workload | Before mean / p95 / p99 | Integrated mean / p95 / p99 |
| --- | ---: | ---: |
| Common roster, movement | 24.11 / 32.30 / 35.41 | 26.27 / 35.32 / 38.18 |
| Common roster, combat | 28.23 / 32.74 / 35.30 | 32.45 / 35.94 / 39.67 |
| Aircraft roster, movement | Not available | 35.23 / 57.91 / 61.41 |
| Aircraft roster, combat | Not available | 42.32 / 58.55 / 62.20 |

The common roster's median mean frame time increases approximately 9% during
movement and 15% during combat. This compares the complete integration,
including changed weapon and ammunition rules; it does not isolate the cost
of one subsystem.

**The plan's p95 ≤ 33.3 ms target is not met.** Integrated common-roster p95
ranges are 34.90–35.41 ms for movement and 35.17–37.60 ms for combat. Aircraft
roster ranges are 55.15–57.96 ms and 56.69–59.07 ms. Maximum-population frame
time remains an open performance goal.

Every measured run moves and travels all 200 units. The generic firing counter
ranges from 99 to 113; aircraft-roster runs reach 33–45 simultaneous physical
rounds at the sampling points. No measured frame exceeds 100 ms; the worst
aircraft-roster sample is 66.76 ms. These samples exclude loading and warm-up,
so this is not a claim of hitch-free play.

A separate single run at half 3D raster resolution keeps the same aircraft
workload and produces movement/combat means of 37.06/43.73 ms and p95 values
of 61.28/60.84 ms. Reducing pixel count alone did not improve this sample.
That suggests CPU or scene-submission cost deserves investigation, but this
diagnostic does not isolate a subsystem or establish a GPU timing result.

## Reproduction

```sh
godot --path /path/to/revision --script tests/rendered/ScaleFrameBenchmark.gd \
  -- --behaviors --realtime --no-capture

# Integrated revision only:
godot --path /path/to/revision --script tests/rendered/ScaleFrameBenchmark.gd \
  -- --behaviors --realtime --no-capture --air-combat
```

These short controlled scenarios do not measure a complete match, every
map, startup hitches, input-to-display latency or thermal stability over a
long play session. Windows, Linux and packaged release exports were not run.
