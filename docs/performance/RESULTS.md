# Battle performance and behavior simplification — 2026-10-17

Battle controls now offer **Attack, Defensive, Follow, Guard and Hold Fire**.
Normal production, the battle UI, AI armies and save restoration no longer start
per-unit Lua execution. The former code/rule editors, factory program selectors,
chip purchases and squad-program pages are retired from battle controls. Legacy
source and preset classes remain for archive validation and authored mission
internals. See [behavior rules](../UNIT_BEHAVIORS.md).

Follow-up menu cleanup, soldier animation timing and shared resource spacing are
recorded in [the follow-up report](FOLLOW_UP.md). The measurements below were
recorded during the initial optimization, before that follow-up.

## Rendered measurements

Godot 4.6 official debug executable, Apple M1 Pro, Metal Forward+, VSync disabled.
The stress test renders 1920×1080 at full 3D resolution, with 200 mobile units,
80 structures and 62 resource nodes. Both final runs render every sampled frame,
advance each ten-second phase in approximately ten wall seconds, move all 200
units, and exercise 101–111 weapons with real effects and elevated survival HP.
There are **zero Lua VMs** in the final workload.

| Workload | Movement mean / p95 | Combat mean / p95 |
| --- | ---: | ---: |
| Original Lua control, 60 Hz | 129.56 / 193.44 ms | 191.02 / 220.21 ms |
| Original native presets, 60 Hz | 44.88 / 76.26 ms | 92.40 / 126.40 ms |
| Built-in behaviors, 30 Hz, final run 1 | 25.36 / 33.83 ms | 32.10 / 36.12 ms |
| Built-in behaviors, 30 Hz, final run 2 | 25.41 / 34.03 ms | 32.11 / 36.83 ms |

The final workload averages **39.4 FPS moving** and **31.1–31.2 FPS fighting**,
compared with **7.7 / 5.2 FPS** in the original Lua workload. This is a gameplay
redesign plus optimization: the population, roles and resolution match, while
orders, targeting decisions and shot counts differ. It is not an identical-action
Lua interpreter microbenchmark. The intermediate 60 Hz simple-behavior run measured
39.26 ms moving / 59.03 ms fighting, so the benefit does not come solely from the
lower simulation rate.

The smaller warmed battle benchmark renders 2304×1296 backing pixels: its 70-unit
combat case improves from 13.11 ms / 76.3 FPS to 12.00 ms / 83.3 FPS. Its 30-unit
base case measures 9.12 ms / 109.6 FPS. The first baseline invocation had shader
warm-up spikes (33.85 ms combat mean); that cold result is not used to inflate the
warm-battle improvement.

[Machine-readable measurements](measurements.json) retain the raw benchmark rows.
GPU timestamp measurements returned zero on this Metal backend and are unavailable;
zero is not evidence of free GPU work. No RTX 4090 or Windows measurement was made.
The maximum-population M1 Pro case still does not maintain 60 FPS.

## Changes

- Replace copied per-unit scripting snapshots and VMs with immediate native orders.
- Stop idle compatibility controllers from processing and remove floating program badges.
- Use fine spatial cells for close body contact and coarse cells for perception;
  discard friendly players before enemy-target queries.
- Cache navigation trait lookup and type the contact solver's vector math.
- Run simulation at 30 Hz with smooth rendering. Animated local geometry uses
  display-rate poses driven by interpolated root motion; spawning, navigation
  alignment, camera jumps, restore and pooled tracers reset interpolation.
- Record stance in snapshot v14, accept v1–13 archives, and convert archived script
  actions to Defensive without compiling their source.
- Teach Guard in First Orders, update English/Chinese controls, and replace the
  retired Lua-unit release smoke test with the behavior regression.

The interpolation approach follows [Godot's physics interpolation guidance](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html).

## Verification

Passing checks cover all three factions' five controls, immediate Hold Fire,
paused orders, changed follow destinations, follow/save restoration, invalid
stance rejection, prior save versions, and legacy Lua migration without VM creation.
Combat, navigation/harvest/factory egress, manual queues, procedural animation,
cosmetic gameplay invariance, First Orders victory/defeat/progress, campaign
controls, Frontier damage and neutral-world interaction also pass.

The English/Chinese HUD console preview captures all three factions. The rendered
behavior regression passes across all three factions; reviewed captures are
[Bastion](../../art/hud-console/bastion-behaviors.png),
[Helix](../../art/hud-console/helix-behaviors.png) and
[Frontier](../../art/hud-console/frontier-behaviors.png).
Chinese UI audit passes 1,145 unique strings and 687 voice captions; locale switching
and formatting/lint checks pass. [Verification index](verification.json) records
22 individual passing scripts and static checks. These are targeted checks, not
the entire repository test suite or a Windows export verification. Existing Godot shutdown resource/RID/shader warnings remain;
passing runs are checked for script errors and are not described as clean stderr.

Earlier failures found and corrected an invalid typed iteration over freed cached
bodies, gait phase resets between simulation ticks, missing stance persistence,
and render-frame assumptions in a projectile timing fixture. The latter now waits
for actual damage with a bounded simulation-time deadline, retaining exact damage
assertions. The full campaign fixture now uses the shipped Guard control. A weapon-mode
visibility fixture explicitly recenters its blocking structure after deferred
navigation alignment; its original building had shifted off the sight line.

## Reproduce

```sh
godot --path . --script tests/rendered/ScaleFrameBenchmark.gd -- --behaviors --realtime --no-capture
godot --path . --script tests/rendered/BattleFrameBenchmark.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/BehaviorRegression.gd
godot --path . --script tests/rendered/BehaviorPreview.gd
godot --path . --script tests/rendered/HudConsolePreview.gd
```

Use the same hardware, window backing resolution and graphics preferences for
comparisons. Do not pass `--fixed-fps` to rendered throughput measurements.
