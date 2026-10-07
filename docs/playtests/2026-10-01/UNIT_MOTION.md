# Individual unit motion verification — 2026-10-01

The user requested subtle movement during long idle and varied group animation. This pass extends the existing procedural model animation in both Bastion and Helix. Review: [18-second idle/combat movie](../../../art/skirmish/unit-motion-preview.mp4).

## Delivered behavior

- All eight mobile roles in each faction have independently seeded motion: Infantry, Worker, Tank, AdvancedTank, CombatRobot, RepairRobot, Drone and Helicopter.
- Long-idle onset varies from 4 to 7.5 seconds. Small breathing/suspension motion continues; weight shifts, turret scans and tool adjustments use a smooth 3.2-second gesture with 6–10-second intervals. Aircraft hover continuously. These are visual offsets, not autonomous movement orders.
- Gait and rotor phase/cadence vary per unit. Three recoil recovery durations, per-shot strength/roll and direction-sensitive flinches break up synchronized firing. Actual shot timing, damage and cooldown remain unchanged.
- Deaths vary their direction, short slide, settling duration and sink onset. Infantry topple, vehicles settle, aircraft bank and accelerate down. Building foundations remain fixed during operation; articulated machinery can move and destroyed structures settle vertically. Wrecks still expire at eight seconds, capped at 24.
- Movement intent, active work, aim, shots, hits and fresh orders interrupt/reset long idle. Blocked units with a movement destination do not perform idle gestures. Aim takes priority over turret scanning; firing clears the idle body pose before sampling the muzzle.
- Private per-unit RNG never consumes global gameplay randomness. Unit metadata retains its visual seed for its lifetime; future save/load must explicitly preserve it. All motion follows simulation updates and freezes during pause. Existing GPU particle and tracer budgets remain unchanged.

## Checks and results

| Check | Result |
|---|---|
| `tests/headless/UnitMotionRegression.gd` | Pass: all 16 mobile/faction combinations animate, delayed onset, 60-second drift/bounds checks, unchanged root/order/HP/attack interval, blocked-order interruption, aim priority, barrel recovery, hit side, 24-unit group diversity, finite wreck interpolation, RNG isolation, fixed foundations and actual running-to-paused motion |
| `tests/headless/CombatRegression.gd` | Pass: observation, obstruction, projectile behavior, armor, repair and pause |
| `tests/headless/NavigationRegression.gd` | Pass: crowded movement, obstacles, harvesting, factory egress |
| `tests/headless/Skirmish.gd` | Pass: faction setup/pairings, production, construction, AA, pause, results/restart and AI |
| `tests/rendered/UnitMotionPreview.gd -- --capture` | Rendered Metal review: separated groups idle, then advance and fight; 112 shots, 109 impacts and 12 deaths, pause and bounded pools asserted. Selected stills inspected for placement, varied wreck poses and label readability. |
| `tests/headless/ScaleBenchmark.gd` with rendering | Pass: 200/200 units moved, 159 shots, 59 peak projectiles/tracers, 80 structures and 32 resource nodes |

The rendered scale test used Godot 4.6, Metal Forward+, M1 Pro, a confirmed 1920×1080 viewport, fixed 60 Hz simulation and disabled VSync. Movement averaged **21.37 ms** (p95 **33.16 ms**); combat averaged **20.61 ms** (p95 **38.37 ms**). The earlier run was 20.72/19.98 ms average. This single comparison suggests a small added cost but is not an isolated microbenchmark or a stable-framerate guarantee. Spikes, other hardware and the eventual programmable-unit workload remain performance work.

The review movie intentionally reveals both armies and temporarily disables orders during its idle section. Normal skirmish fog and AI behavior are unchanged. It uses the live visual layer, then actual attack-move combat; it does not inject fabricated muzzle flashes or manually pose deaths.

## Reproduce

From the repository root, use `tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot` as the executable:

```sh
Godot --headless --path . --fixed-fps 60 --script tests/headless/UnitMotionRegression.gd
Godot --path . --fixed-fps 60 --script tests/rendered/UnitMotionPreview.gd -- --capture
Godot --path . --fixed-fps 60 --disable-vsync --script tests/headless/ScaleBenchmark.gd
```

Encode the captured 30 FPS JPEG sequence with ffmpeg:

```sh
ffmpeg -y -framerate 30 -i art/skirmish/motion-frames/frame-%04d.jpg -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart art/skirmish/unit-motion-preview.mp4
```

Format/lint and `git diff --check` passed for the changed implementation and tests.

## Remaining limitations

This remains procedural animation of the existing rigid model parts. Dedicated skeletal breathing/reload/death clips, foot IK, animated tracks, debris rigs and audio remain future art work. Static buildings without articulated machinery intentionally do not wobble. Existing runtime navigation GPU-readback warnings and shutdown ObjectDB/resource/RID diagnostics still occur in the wider test suite; no new GDScript runtime errors were observed.
