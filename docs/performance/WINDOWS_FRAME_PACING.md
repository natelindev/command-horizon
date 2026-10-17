# Windows frame pacing — 2026-10-17

The menu and early-match investigation found three sources of visible stalls or
motion discontinuity:

- Selecting a map instantiated its battlefield and generated a 384 × 384 terrain
  image in GDScript on the main thread. All 16 selectable maps now have compressed
  preview resources containing identical pixels and overview metadata. Custom and
  legacy maps retain the procedural fallback. Regenerate assets after map edits:
  `godot --headless --path . --script tools/ui/bake_map_previews.gd`.
- Music loaded long Ogg streams synchronously on scene changes. Loading now runs
  through ResourceLoader's background API; playback switches only after completion.
  Superseded requests cannot replace the latest requested track. The bounded cache
  retains at most four streams, and shutdown drains outstanding requests.
- Disabling interpolation on `Geometry` also disabled interpolation inherited from
  the unit root. Display-rate animation now explicitly composes the interpolated
  world root with the local pose. Weapon recoil/muzzle sampling still uses the
  authoritative simulation transform, and pausing removes the render offset.
  Camera input and shake now run at display rate rather than the 30 Hz physics rate.

The camera retains the existing `set_physics_process(false)` disable convention
used by authored scenes and preview fixtures. Simulation frequency, graphics
quality, unit counts, weapon rules, and user preferences are unchanged.

## Measurements

Windows, Ryzen 7 5800X3D, RTX 4090, Godot 4.6 official debug executable, Vulkan
Forward+. These are local before/after samples, not a guarantee of frame deadlines.
Other applications remained open. No synthetic fixed FPS was used for rendered
throughput measurements.

| Measurement | Before | After |
| --- | ---: | ---: |
| Map preview selection, all 16 maps | 363–793 ms | 1.6–2.8 ms |
| Menu startup sample, worst frame, 4K/240 Hz VSync | 89.70 ms | 26.92 ms |
| Menu startup sample, frames over 33.34 ms in 5 seconds | 2 | 0 |
| Warm menu, worst frame in 5 seconds | 16.00 ms | 6.67 ms |
| 30-unit base, mean / p95, 1440 × 900 uncapped | 3.67 / 7.01 ms | 3.83 / 7.53 ms |
| 70-unit combat, mean / p95, same viewport | 12.24 / 20.07 ms | 12.09 / 18.81 ms |
| 200-unit movement, mean / p95, 1920 × 1080 | 45.36 / 77.65 ms | 47.49 / 78.45 ms |
| 200-unit combat, mean / p95, same viewport | 64.86 / 84.22 ms | 66.30 / 82.73 ms |

Battle throughput is essentially unchanged; the maximum-population workload still
does not meet 60 FPS. Its CPU/scene-tree cost remains a separate bottleneck. The
improvements here are removing blocking menu work and correcting rendered motion,
not a claimed large-battle speedup. Menu startup numbers include cache/OS variance.

The existing battle benchmark incorrectly required 240 rendered frames to take
more than one simulation second. Fast hardware completed the base sample in
0.88 seconds. It now checks that simulation time follows measured wall time and
that physics ticks actually advance.

## Verification

- `MapPreviewRegression.gd`: all 16 previews match procedural metadata and image
  bytes exactly.
- `FramePacingRegression.gd`: all three factions move on 73–74 of 100 sampled
  frames between physics ticks; camera input responds without waiting for a tick;
  recoil preserves simulation authority; pause clears the visual offset.
- `UnitAnimationRegression.gd`, `UnitMotionRegression.gd`, `CombatRegression.gd`,
  `SettingsRegression.gd`, and `MusicRegression.gd` pass. Music coverage includes
  rapid requests while background loads are pending, crossfades, looping and mute.
- Rendered battle and maximum-population benchmarks pass their workload checks.
  All 200 mobile units travel; 101 weapons fire in the final scale run.
- `gdformat --check`, `gdlint` for changed GDScript and `git diff --check` pass.

Some headless fixtures retain engine shutdown resource warnings; SettingsRegression
also deliberately exercises a failed save. These do not represent test assertion
failures. No full repository suite or packaged Windows export was run.

Reproduce the menu and motion checks with:

```sh
godot --path . --script tests/rendered/MenuFrameBenchmark.gd
godot --path . --script tests/rendered/FramePacingRegression.gd
godot --headless --path . --script tests/headless/MapPreviewRegression.gd
```

Interpolation behavior follows the [Godot 4.6 documentation](https://docs.godotengine.org/en/4.6/tutorials/physics/interpolation/advanced_physics_interpolation.html).

## In-game follow-up

The follow-up retains the interpolated unit root but builds each body pose in
memory and publishes it once. Previously, each render frame restored the old
local pose, wrote the new pose, then wrote the interpolated world transform.
Turret presentation follows the final rendered pose; firing still explicitly
restores simulation space before sampling the muzzle. Authored rotation and
nonuniform scale are preserved, with a new comparison against Node3D setters.
Chassis integration uses packed double-precision tuning values.

Windows now runs avoidance calculations without per-map worker dispatch. Other
platforms retain the engine default. This changes scheduling, not the simulation
rate, collision constraints, speed, neighbors, or unit limits. The setting is
documented in [Godot ProjectSettings](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-navigation-avoidance-thread-model-avoidance-use-multiple-threads).
An attempted movement-transform batching change was discarded; `Movement.gd`
retains its original implementation.

Final matched-resolution measurements (same hardware and engine as above):

| Workload | Before mean / p95 / p99 | Final mean / p95 / p99 |
| --- | ---: | ---: |
| 200-unit movement, 1920 x 1080 | 35.76 / 62.26 / 80.66 ms | 32.66 / 58.02 / 69.49 ms |
| 200-unit combat, 1920 x 1080 | 50.42 / 67.27 / 71.72 ms | 48.84 / 64.69 / 73.57 ms |
| 30-unit base, 1440 x 900 | 3.26 / 5.88 / not sampled | 3.25 / 5.88 / not sampled |
| 70-unit combat, 1440 x 900 | 9.52 / 15.11 / not sampled | 9.53 / 15.43 / not sampled |

Movement mean improves about 9%, and its p99 about 14%. Combat mean improves
about 3%; its p99 does not improve. Small-battle throughput is unchanged. A
separate single-threaded diagnostic measured 31.71 / 46.26 ms movement/combat
means, so these remain samples subject to workload and system variance. The
earlier, larger apparent gains were not reproduced in the controlled comparison
and should not be used as the claimed improvement. One exploratory comparison
also had a resized Windows viewport; the rendered scale benchmark now holds its
internal viewport at 1920 x 1080 and logs the effective avoidance setting.

All 200 units travel and 101 weapons fire in the final stress run. Graphics and
animation quality are retained. Maximum-population combat is still CPU-limited
at about 20 FPS; this follow-up does not establish stutter-free or locked 60 FPS.

The navigation fixture now recognizes the existing plain-Move policy that allows
completion beside a settled ally occupying the endpoint. It still rejects active
movers, distant stops, overlap beyond the contact tolerance, and stops without a nearby settled
ally. With serial avoidance, the old exact-slot check produced the same 11/12
result and identical missed-unit coordinates before and after the animation
change. This is a fixture correction, not a change to arrival rules.

The separate legacy `CrowdBoundaryRegression.gd` fails on the original code too
(six failures in the baseline replay), including a step-size assertion hardcoded
for 60 Hz and archived-worker progress checks. It is not claimed as passing.

Final verification passes: `NavigationRegression.gd` (12/12 formation arrivals,
obstacle routing, harvesting, construction, rocks and factory egress),
`UnitAnimationRegression.gd` (including authored rotation/nonuniform scale),
`UnitMotionRegression.gd`, `CombatRegression.gd`, and rendered
`FramePacingRegression.gd` (72-74 moving samples between physics ticks across all
three factions). Both rendered performance workloads pass their checks. Changed
GDScript passes formatting/lint and the source diff passes whitespace checks.
Existing headless shutdown resource warnings remain. No full-suite or packaged
export verification is claimed.
