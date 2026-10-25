# Animation polish verification — 25 October 2026

## Delivered behavior

- Bastion tanks and tracked rovers now circulate raised tread shoes according to actual travel, including reverse and differential pivot turns. Exported geometry retains weathering. Hulls remain GPU batched; the two belt meshes use shader deformation outside rigid batching. Teleports reset motion sampling without a track jump.
- Tracked vehicles react more strongly to braking. Authored Bastion and Frontier antennas lag acceleration and settle with a damped spring. Barrel recoil follows the elevated barrel axis through a sharp kick, short hold and hydraulic return.
- Heavy weapon fire adds bounded, exponentially cooling muzzle glow, kinetic casing ejection, ground dust and nearby foliage deflection. Rotor downwash also bends foliage. Ground motion distinguishes sand, snow and soil/clods; water uses the existing water effects.
- Selection rings ease into place. Accepted move commands show expanding ripples and heading arrows; attack markers contract segmented corners. Queued routes carry a small moving pulse. Existing damage catch-up bars remain active.
- Factory preparation starts warning beacons, door movement and pneumatic venting before completion. Departure ramps smoothly with exhaust and hands off the track phase. Bastion welding adds a pooled light; existing faction construction rigs are retained.
- Wrecks collapse unevenly before a delayed ammunition cook-off and leave scars while sliding. Explosive infantry deaths lift/rotate the body and detach the weapon into the shared debris pool.

Effects use bounded budgets: 24 hot weapons, four foliage impulses, a 128-particle clod emitter and the existing 32-body aftermath pool. Visible-effect admission is camera gated. Tactical pause freezes animation; reduced flashes suppress heat/foliage and animated route pulses, including when changed while paused.

## Verification

Godot 4.7.2, Metal Forward+, Apple M1 Pro. The final headless batch passed these ten fixtures with zero assertion failures:

- `AnimationPolishRegression`: exported rigs, forward/reverse/pivot tracks, teleport handling, antenna settling, elevated recoil, selection/order animation, death variant and bounded heat lifecycle.
- `UnitAnimationRegression`: all three factions.
- `InfantryDeathGroundRegression`: 72 faction/role/fall scenarios.
- `StructureActivityRegression`, `BattleFeedbackRegression`, `ChargePresentationRegression`.
- `ChassisSpringRegression`: cadence independence at 15/30/60/144 FPS, long frames and impulses.
- `CombatJuiceRegression`, `BattleAftermathRegression`, `RichTexturesRegression`.

Earlier focused checks also passed: ground vehicle motion, construction contracts/styles, save/restore and object materials (344 models, 7,347 surfaces).

`AnimationPolishPreview` passed through both ordinary rendering and optional native kernels with decoupled GPU poses. It checks native-track/batched-hull alignment, heat creation, pause and reduced-flash changes, delayed cook-off and detached infantry weapons. The alignment assertion covers a failure discovered and corrected during this pass.

Rendered review also passed: six HUD captures covering all three factions in English/Chinese; 22 Bastion/Frontier model captures; terrain captures for Glacier Narrows, Pinebreak Valley and Desert Frontier. Capture fixtures now explicitly draw before reading back an occluded native window.

GDScript formatting, Python generator compilation and `git diff --check` passed. GDScript lint reports the same seven pre-existing findings as the corresponding files at HEAD. Several headless fixtures retain existing audio-resource cleanup warnings at shutdown; these are preserved in the logs and are not assertion failures.

Raw passing logs are in [logs](logs/). Local generated evidence: [animation clip](../../../../art/animation-polish/animation-polish.mp4), [movement](../../../../art/animation-polish/motion-099.png), [collapse](../../../../art/animation-polish/02-collapse.png), [cook-off](../../../../art/animation-polish/03-cookoff.png). Captures are ignored build outputs and can be regenerated.

## Reproduction

From the repository root, with `Godot` pointing at a Godot 4.7.2 executable:

```sh
Godot --headless --path . --script tests/headless/AnimationPolishRegression.gd
Godot --path . --script tests/rendered/AnimationPolishPreview.gd -- --capture
Godot --path . --script tests/rendered/AnimationPolishPreview.gd -- --enable-native-kernels --enable-decoupled-poses --capture
Godot --path . --script tests/rendered/HudConsolePreview.gd -- --full-visibility
Godot --path . --script tests/rendered/WeatheringPreview.gd -- bastion frontier
Godot --path . --script tests/rendered/TerrainLayersPreview.gd -- GlacierNarrowsMap PinebreakValleyMap DesertFrontierMap
```

The optional native path requires a local build with `python3 tools/build_native.py`. Rendered checks must run without `--headless`. The capture option emits PNG frames; the MP4 was encoded at 30 FPS from those frames.

## Limits

Thermal feedback uses emissive muzzle sleeves; this pass does not add screen-space heat shimmer or rocket-launcher hatch rigs. Existing deployment and charge anticipation are extended without delaying authoritative attacks. Existing construction and water systems are reused. This is functional and visual verification on macOS, not a Windows or maximum-army performance benchmark.
