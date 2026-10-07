# Two-faction skirmish verification — 2026-10-01

Environment: macOS, Godot 4.6, existing Bastion/Helix GLB assets. This report covers the conventional RTS skirmish milestone, not the future programming/campaign systems.

## Implemented and checked

- Main menu → skirmish setup → loading → actual faction-owned units/buildings.
- All four Bastion/Helix pairings; both random outcomes; opposite spawn slots; replay retains resolved factions.
- All three maps with standard/advanced starts; 1280×720 and 1440×900 rendered setup layouts.
- Full roster production, faction prices, cancellation refunds, lab prerequisites, construction previews/completion, and team-material recoloring on all produced roles.
- Mobile AA deals damage to an aircraft. Simulation time freezes during tactical pause. A paused attack order cannot bypass a pending weapon cooldown.
- Victory, defeat and draw via HQ recovery timers; replay; return to setup without a stale pause.
- Both AI factions build an economy and send attacks over six simulated minutes. Following the movement fix, each built seven structures and launched four waves; Bastion produced seven reinforcements and Helix eight in the controlled no-defense scenario. This verifies activity, not strong tactical play or balanced match duration.
- Native mouse test: choose Helix, choose random enemy, Start Battle, select an engineer, place a Helix generator, toggle tactical pause. Random resolved to a Helix mirror match. Rendered tests also cover production UI, paused attack move, menu/result layouts and return flow.

## Movement bug reproduction and fix

The user reported frequent sticking while trying the skirmish. A controlled route with a factory between tank and destination reproduced the issue: the tank remained **10.09 m short** after 15 simulated seconds. The original crowd scenario had **10/12** tanks near their destinations, and some freshly produced tanks failed to leave the factory area.

The building's baked square was smaller than its circular avoidance footprint. The route entered space rejected by avoidance. Movement additionally submitted per-frame displacement as avoidance velocity, repeatedly queried paths inside avoidance callbacks, used infinite stop targets, and could overwrite an early rally order during initialization.

The fix reconciles static footprints, uses velocity with one delta integration, updates the path once per physics tick, preserves early orders and finite stop state, projects avoidance movement onto the navigation mesh, and provides a bounded sidestep/repath when progress stalls. The behavior follows the path-update/callback constraints documented in [Godot NavigationAgent3D](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html); obstacle geometry and avoidance are distinct mechanisms as documented in [NavigationObstacle3D](https://docs.godotengine.org/en/stable/classes/class_navigationobstacle3d.html).

After the fix, the original tank route stops within **0.15 m** of its destination without crossing the factory footprint. All **12/12** group members reach their assigned destinations (arrival is tracked over time because idle units can yield to later arrivals). Factory-exit, six-worker harvesting, building placement/removal during movement, and a worker reaching/completing a new factory are covered by regression tests. The rock route finishes within 0.17 m of its destination in both headless and rendered runs. That test disables idle target acquisition to isolate pathfinding from tanks correctly chasing a nearby enemy after arrival.

Repeated match creation also exposed a shared navigation-mesh resource being modified by an earlier asynchronous bake. Navigation meshes are now local to each scene instance, with an explicit resource-isolation regression assertion. The final multi-match suite passes without script errors.

## Reproduce checks

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/Skirmish.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/NavigationRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/BastionDemo.gd
godot --path . --fixed-fps 60 --script tests/rendered/SkirmishPreview.gd
godot --path . --fixed-fps 60 --script tests/headless/NavigationRegression.gd
gdformat --check source/ tests/headless/NavigationRegression.gd
gdlint source/ tests/headless/NavigationRegression.gd
```

The navigation test can run headless or rendered; rendered mode writes a group-route screenshot. Screenshots are under `art/skirmish/`.

## Limits and diagnostics

No 200-unit frame-time benchmark, multiplayer verification or long campaign playthrough was performed. AI difficulty and economy need further playtesting. A completely blocked route still cannot make units cross solid terrain. Full program authoring, chips, save/load, campaigns and faction signature abilities remain future work.

Godot still reports the existing runtime navigation mesh parsing performance warning and renderer shader allocations at process shutdown; the Bastion test also reports resource/object cleanup diagnostics. These are recorded separately from gameplay assertions. The tests must be reviewed for script errors as well as their exit status; a printed PASS alone is insufficient.
