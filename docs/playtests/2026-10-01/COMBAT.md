# Combat foundation, animation and scale verification

2026-10-01 · Godot 4.6 stable · development Mac: Apple M1 Pro, 32 GiB memory

The user requested sequential development, then identified primitive battle animation. This pass implements the shared combat foundation and a first procedural animation/VFX pass. It does not implement Lua, the campaign, an LLM provider or final skeletal animation.

## Functional evidence

- `CombatRegression.gd`: opaque buildings/Desert cliffs; allied spotting without firing through a wall; reciprocal AI/player observation; elevated and sloping sight lines; foundation/completion/removal; loss of sight; last-observed pursuit rather than hidden coordinates; idle defense without pursuit; rifle/heavy fractional damage; rail counter; independent air eligibility; no friendly damage.
- The same suite checks ten repair robots against one target, strongest depot/mobile channel, low-power priority, the three-second combat repair penalty, two depot slots, infantry/air recovery, self/infantry exclusions for robots, stationary aircraft, and pause. Cannon hits wait for travel, resolve once, freeze in flight, and missiles cancel when targets disappear.
- Existing `Skirmish.gd`: four faction pairings, random selection, maps/starts, full roster production/costs/refunds/prerequisites, AA, cooldown pause/retargeting, win/loss/draw/restart and resource-paying AI. Six-minute AI observations: Bastion six structures/four waves/seven units produced; Helix seven structures/four waves/eight units produced. These are observations, not balance findings.
- Existing `BastionDemo.gd`: roster, models/colors, production/economy/power, construction, updated repair contract, weapons, pause and setup checks pass. The weapon test restores each emplacement's position after its scenario: overlapping two opaque turrets at the same test coordinate would correctly obstruct the later shot.
- `NavigationRegression.gd`: 12/12 group arrivals, factory routes/exits, six-worker harvesting, construction and dynamic obstruction. Final rock-route distance 0.162 m. This verifies the earlier sticking fix survives the combat changes.
- `SkirmishPreview.gd`: rendered menu/setup/Helix production/construction, paused attack move, result and return pass.
- `CombatPreview.gd`: actual mixed Bastion/Helix fight, 110 shots, 103 impacts and nine deaths in the final recorded run. Checks frozen tracer ages, particle speed, simulation clock and shot count during tactical pause, plus tracer/wreck bounds. Selected stills and an eight-second 1440×900 MP4 are in `art/skirmish/`.

## Scale measurement

The synthetic scene uses **200 mobile units, 80 structures and 32 resource nodes**, including both faction models, movement, avoidance, combat, repair, fog/minimap and effects. HP is elevated to keep the complete population alive; this is deliberately not a balance test. Construction availability and placement reject a 41st structure without spending resources. All 200 units move more than two metres; 157 fire in the final 1080p run. Sampled peak live projectiles/tracers: 51.

Each phase samples 600 frames after initial scene warmup. `--fixed-fps 60 --disable-vsync` provides uncapped fixed-step workload throughput. Wall-clock frame durations include render/engine work; these are not a claim of a locked presentation framerate or a long-match simulation-backlog test. No competing verification process was running during the recorded final benchmark.

| Workload | Mean frame ms | p95 frame ms |
| --- | ---: | ---: |
| Initial headless movement, before spatial optimization | 51.29 | 68.82 |
| Initial headless combat, before spatial optimization | 55.80 | 95.25 |
| Spatially optimized headless movement, before animation pass | 13.68 | 27.01 |
| Spatially optimized headless combat, before animation pass | 14.20 | 31.31 |
| Final rendered movement, actual 1920×1080 | 20.72 | 31.34 |
| Final rendered combat, actual 1920×1080 | 19.98 | 37.62 |

The optimization caches stable role names, indexes nearby observers/occluders, and distributes presentation visibility over six physics frames. Legal firing still validates current observations and line of fire. GPU buffers replace per-projectile particle emitters: five particle systems, 1,728 particle slots, 96 reusable tracers and 24 temporary wrecks.

A preceding native Retina run rendered at **3456×1944**, despite the requested window dimensions: movement/combat means 20.78/19.85 ms and p95 33.79/37.02 ms. The benchmark now uses viewport scaling and reports actual texture resolution, avoiding a false 1080p label. At 1080p, average throughput is approximately 48–50 frames/second, but combat p95 exceeds the 33.3 ms budget. Stable 60 FPS and strict stable-30 acceptance are **not** established. Further frame-time profiling, long matches, 200 running programs, a forced 300-transient-effects workload and Windows hardware remain open.

## Presentation checks and limitations

Inspected rendered frames at multiple battle stages. The initial white, oversized particle puffs were replaced by a custom GPU process shader that preserves explicitly emitted tint, size and velocity, with soft smoke/dust edges. Shots now have barrel/hull recoil, readable trails and impacts; wrecks settle and expire. No sound design, authored reload clips, track deformation, ragdoll physics or destructible geometry is implied. The effects use Godot's documented [manual GPU particle emission](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html) and [particle shader state](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/particle_shader.html).

Actual enemy-unit visibility and firing respect opaque volumes; the terrain fog texture still uses reveal circles. Desert cliffs/buildings have authored cylindrical sight proxies; legacy small decoration rocks do not. Wrecks are cosmetic and do not change navigation. Low-volume smoke and limited effect lifetime preserve army readability.

Known runtime diagnostics remain: runtime navigation mesh parsing warns about GPU geometry readback; some shutdown paths report ObjectDB/resource or renderer RID cleanup warnings. The final suites contain no GDScript runtime/parse errors. These diagnostics are not represented as passing a release cleanup/performance gate.

## Reproduce

Use `tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot` on this workspace, or `godot` on PATH:

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/CombatRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/Skirmish.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/BastionDemo.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/NavigationRegression.gd
godot --path . --fixed-fps 60 --script tests/rendered/SkirmishPreview.gd
godot --path . --fixed-fps 60 --script tests/rendered/CombatPreview.gd
godot --path . --fixed-fps 60 --disable-vsync --script tests/headless/ScaleBenchmark.gd
```

Append `-- --capture` to `CombatPreview.gd` to write intermediate JPEG frames to the ignored `art/skirmish/combat-frames/` directory. Encode at 30 FPS. The retained review artifacts are the MP4 and three selected PNG stills, not the intermediate frames.
