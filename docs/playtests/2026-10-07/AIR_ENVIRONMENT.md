# Air Corridor quarry environment — 2026-10-07

Air Corridor now has an editable seven-asset quarry kit, continuous worn haul roads, battery aprons, evacuation pads, layered quarry cuts, freight containers and exterior crushing/conveyor equipment. Aircraft climb over the map's existing obstacles. This fixes a measured case in which a drone flew through the old visible rock.

## Geometry and flight contract

The original five rocks had visual radius 8.5841 m against 6.5 m ground blockers. Their top was 6.587 m above the 0.6 m obstacle parent, exceeding the 3 m sight contract. An actual moving drone crossed the middle rock at root altitude 1.5 m. Baseline source, imported measurements and images are retained in [the evidence folder](air-environment/).

Replacement benches have maximum radius 6.3065 m and ground-relative height 2.9085 m. Containers measure 2.7811 m / 1.605 m. The thirteen original obstacle positions, radii and sight heights remain; compensating mesh offsets ground the new models. Imported geometry is checked relative to each obstacle parent; the asset manifest instead measures from the model origin at ground level. Ground-height rays remain blocked and rays above the 3 m sight envelope remain clear.

The map uses the existing industrial flight-clearance helper for all thirteen landmarks. The measured root altitude over the cut is now 4.1 m. Actual Drone, Helicopter and EvacTransport units complete all thirteen crossings each: **39 crossings**, with their measured airframe bottoms above the visible mesh and no stalls. These are controlled geometry fixtures with positioned units and disabled enemy processing; they are separate from the complete combat runs below.

All four baseline route lengths match exactly: ground staging→SCREEN 95.7588 m, LAUNCH→north battery 91.1350 m, LAUNCH→south battery 115.3807 m, and direct air LAUNCH→EXIT 112 m. Sites, pads, responses, resources and ground navigation retain their positions. Exterior hills, crusher and conveyor remain wholly outside the 144×104 playable rectangle, with no navigation/physics components. Surrounding terrain joins the ground at zero height. Interior enemy observation remains unchanged in the ordinary-fog opening check.

**Altitude is a gameplay change:** aircraft position affects weapon range and sight. Preserving ground routes does not imply identical combat outcomes. No weapon stats, difficulty budgets, mission rules or save schema were changed.

## Archives and complete routes

A newly captured raised-flight disk archive preserves exact position and paused time, then resumes its ordinary Move order; a separate normal-clock rendered round trip also passes. An archive captured using the original map contains the drone at `(65.74981, 1.5, 51)`. Loading it preserves that exact paused position. Once resumed, movement raises it to 4.1 m within two physics frames and completes the crossing. A paused legacy save can therefore initially show its old low aircraft position.

The previous pass's earned held-flight archive also preserves clock/HP/position and extracts after Continue in 45.03 seconds. This uses the original retained archive, not a reconstructed equivalent.

| Route | Result | Flights safe | Simulation seconds |
| --- | --- | ---: | ---: |
| Story, existing commander | Victory | 3 | 212.45 |
| Standard, existing commander | Victory | 2 | 204.73 |
| Veteran, existing commander | Victory | 2 | 204.33 |
| Veteran, explicit observed-threat response | Victory | 3 | 210.85 |
| Veteran, normal-clock rendered response route | Victory | 3 | 211.10 |

The difficulty fixtures use seed 13001 and ordinary orders/programs. The optional response helper explicitly attacks observed threats near SCREEN and repairs wounded ground units; it does not control transports or change forces, funds, health or enemy authority. The shared Air Corridor suite separately saves three flights at 208.87 seconds and confirms that an unescorted flight still takes damage (31 HP remaining). These are practiced viable routes, not repeated balance or novice acceptance. The existing commander saves fewer flights on Standard than the prior environment; the optional Veteran route demonstrates that a three-flight finish remains possible.

The rendered full match uses two mouse Launch activations, one Enter Launch and Enter Continue, including held-flight pause authority. All six combat captures were inspected at 1280×720 with 150% interface scaling; objective controls remain above the minimap. Its map uses the final interior assets and flight correction. A subsequent exterior-only edit hides the low joining foundation under large background hills; the seven `review-*` art frames show that final composition.

## Visual review

Fifteen accepted captures were inspected:

- Final map: [ordinary-fog opening](air-environment/review-start.png), [quarry cut](air-environment/review-checkpoint-0.png), [SCREEN](air-environment/review-checkpoint-1.png), [exit](air-environment/review-checkpoint-2.png), [1440×900 overview](air-environment/review-overview.png), [crusher](air-environment/review-crusher.png), [conveyor](air-environment/review-conveyor.png).
- Flight round trip: [raised crossing](air-environment/raised-crossing.png), [paused loaded flight](air-environment/raised-loaded.png).
- Full match: [north battery](air-environment/veteran-preview-air-corridor-battery-0.png), [south battery](air-environment/veteran-preview-air-corridor-battery-1.png), [held flight](air-environment/veteran-preview-held.png), [live escort](air-environment/veteran-preview-air-corridor-live-escort.png), [two safe](air-environment/veteran-preview-two-safe.png), [victory](air-environment/veteran-preview-result.png).

The six map composition frames after the opening explicitly reveal terrain and hide the HUD for art inspection. Their filenames retain the fixture's `checkpoint` label; these are quarry/SCREEN/exit views, not convoy checkpoints. The opening and full combat match use ordinary observation. Earlier `before`, `initial` and `final` image sets are retained as development evidence; `review` is the accepted final art set. Large exterior joining boxes visible in the intermediate set were hidden in the final backdrop.

## Reproduction and limits

Use `tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/AirEnvironmentRegression.gd` for imported geometry/routes/sight, and substitute `QuarryFlightRegression.gd` for 39 crossings and raised-flight restoration. `QuarryLegacyArchive.gd` is a baseline-only capture fixture: it must run with the retained old map `.gd` and `.tscn`, then restore current shipping files before running `QuarryLegacyRecovery.gd`. Do not regenerate the retained legacy archive against the revised map.

`AirDifficultyMatches.gd` accepts `--difficulty=0/1/2` and optional `--respond-to-threats`; provide a fresh `--evidence=res://...` prefix. Rendered fixtures run without headless/fixed-fps. Map preview captures refuse overwrites. The [run index](air-environment/run-index.json) records nineteen script invocations, all successful, including intermediate geometry/art iterations. Two Blender builds and two editor imports also succeeded. Nine GDScript files pass formatting/lint; the generator compiles. Source snapshots, scope hashes, archives, logs, analyzer and SHA256 manifest are retained. The first evidence-analyzer attempt rejected the known resource-at-exit messages; its final version explicitly permits only the observed two/four-resource shutdown messages while rejecting other errors. Known runtime navigation readback and shutdown resource/ObjectDB diagnostics remain; no script errors occurred in these nineteen runs.

Final subjective composition, novice/repeated strategy balance, wider product/accessibility and native-platform acceptance remain open. Performance work remains deferred. The overall development goal stays active.
