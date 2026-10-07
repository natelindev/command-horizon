# Frontier wheel motion — 2026-10-07

All five wheeled Frontier roles now articulate their wheels from actual chassis movement: Scrapper rig (6), Outrider (6), Patch crawler (4), Jackal rig (4) and Ironback (8). Forward and reverse displacement drive signed rotation at each model's normalized rolling radius. Pivot turns drive opposite sides independently, including an instantaneous half-turn. Blocked orders, idle body gestures and weapon recoil do not create wheel travel. Tactical pause freezes articulation, and large position jumps are treated as relocations.

This closes the previously documented static-wheel presentation gap. Movement, navigation, orders, damage, weapon cadence, prices and faction abilities retain their existing authority. No new vehicle driving physics or steering rules are introduced.

## Asset correction

The original exports named the pivots `Wheel`. Actual Godot inspection found that import had converted these into `VehicleWheel3D` nodes and removed their identifying suffix. This is consistent with Godot's documented [node-type import suffixes](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html). These units use the RTS movement system, and require ordinary articulated visual nodes.

The five GLBs now use `WheelPivot`. The editable Blender catalogue's 28 corresponding empty nodes and the generator use the same names. The GLB edits change only those node names: all other JSON and every byte of the geometry/material binary payload remain identical. The editable source's mesh coordinates and world transforms also remain unchanged. The asset analyzer verifies these assertions against retained before files. No icons were regenerated.

Both Blender and Godot reimport all seventeen models successfully. Tests now verify all 28 wheel pivots, absence of accidental vehicle-physics nodes, actual child articulation, model bounds/topology/materials, forward muzzles, rotor counts and unclipped icons.

## Original failure and final behavior

The corrected original regression finds the imported wheels and moves all five actual units 3.74–5.21 metres. None of their wheel transforms changes, producing five static-wheel failures. The final run travels comparable distances and articulates every wheel:

| Role | Actual travel in the fixture | Wheels animated |
| --- | ---: | ---: |
| Scrapper rig | 5.21 m | 6 |
| Outrider | 4.24 m | 6 |
| Patch crawler | 4.89 m | 4 |
| Jackal rig | 5.21 m | 4 |
| Ironback | 3.75 m | 8 |

The controlled extension checks a quarter-circumference displacement against the actual resulting wheel basis, reversal, sideways displacement, independent left/right turn rotation, a half-turn, one thousand forward/reverse cycles per role, large relocation, a blocked destination and ten seconds of recoil/idle motion. Comparison tolerance is 0.0005 per basis component. Unit root transform, HP, weapon interval and action retain their expected authoritative values.

A real moving disk archive freezes wheel poses during pause, preserves simulation time, player economy, unit positions, HP, actions, queued orders and production, then resumes wheel articulation after loading. Wheel phase is cosmetic and initializes locally on restoration; exact pre-save wheel phase is not serialized. The archive format is unchanged.

Shared Frontier tests pass ordinary 2 E retrofits/refunds, fitted production, Maneuver travel/authority/doctrine/expiration, observed finite salvage, partial cargo restoration and exact HQ delivery. Heavy-cannon and shared-reload AA combat pass. Existing Bastion/Helix animation tests pass all sixteen mobile/faction combinations, idle bounds, RNG isolation, recoil/aim, fixed building foundations and pause.

## Rendered review

The [7.5-second native clip](frontier-wheels/wheel-motion.mp4) contains 225 frames at 1280×720: three seconds of normal-speed movement, half a second paused and four seconds of close-up movement at 25% simulation speed. The slow section covers approximately one simulation second. This is a controlled visual fixture with explicit terrain reveal and spawned review units, not a paid full-match or pacing result.

The [lineup](frontier-wheels/review-lineup.png), [paused detail](frontier-wheels/review-detail-paused.png), [moving detail](frontier-wheels/review-detail-moving.png) and three adjacent motion samples were visually inspected. Treads change orientation around their axle without separating from the chassis; the native trace records one unchanged pose/time throughout pause and 120 distinct moving poses during the close-up. Stop checks also pass. Display options and simulation speed are restored when the fixture finishes.

Two earlier native takes retain successful motion checks but less useful PlainAndSimple framing; the final review uses Desert Frontier and a side-facing close-up. These earlier captures remain classified separately.

## Evidence and reproduction

[Run index](frontier-wheels/run-index.json) classifies nineteen processes: seventeen Godot runs and two Blender runs. Initial name-based fixtures missed the import-converted wheels; the corrected baseline is the accepted original reproduction. A later test loaded movement code before its autoload dependency was available, and strict round-trip basis comparisons failed in another iteration. Those runs remain rejected. Final motion uses signed turn arc length, includes the half-turn/long-cycle cases and passes all focused/shared checks without script errors. Known navigation readback and shutdown resource/RID diagnostics remain visible.

Use Godot 4.6 with `--headless --fixed-fps 60 --path . --script` and one of:

- `tests/headless/FrontierWheelRegression.gd`
- `tests/headless/FrontierAssetRegression.gd`
- `tests/headless/FrontierGameplayRegression.gd`
- `tests/headless/FrontierCombatRegression.gd`
- `tests/headless/UnitMotionRegression.gd`

Native review uses `tests/rendered/FrontierWheelPreview.gd` without headless/fixed-FPS flags, with `-- --evidence=res://<fresh-prefix> --frames=res://tmp/<fresh-directory>`. It refuses to overwrite captures. Encode the numbered JPEGs at 30 fps. Blender's `art/frontier/verify_faction.py` checks the complete roster. Five changed/new GDScripts pass formatting/lint. `python3 docs/playtests/2026-10-07/frontier-wheels/analyze.py` checks source/assets, lossless node renames, baseline/final results, motion traces and encoded video.

This pass verifies wheel presentation and relevant gameplay contracts. It does not establish repeated faction balance, novice comprehension, final animation/art quality or wider platform/release acceptance. Performance remains deferred and the full development goal stays active.
