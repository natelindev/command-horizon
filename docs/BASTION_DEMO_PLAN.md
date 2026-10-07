# Bastion playable demo — Implementation plan

## Scope

Complete a cohesive first-faction demo using the approved concept direction and Blender CLI. Deliver editable source, game exports and icons, then connect the models to actual economy, production, movement, combat, repair, and a playable scenario.

The demo roster is infantry, engineer rover, main battle tank, advanced tank, repair robot, combat robot, reconnaissance drone, and strike aircraft. Structures are command headquarters, barracks, vehicle factory, airfield, power generator, command lab, repair depot, ground turret, and anti-air turret. Materials/electronics deposits and desert scenery complete the setting.

This extends the existing RTS systems. Full Lua/LLM authoring, campaign content, and conditional naval gameplay remain separate design milestones; the demo must accurately describe its available capabilities.

## Stage 1 — Assets and import

- Produce remaining Bastion models with a shared material/silhouette language.
- Preserve component-level Blender source and export game-ready GLBs and UI icons.
- Integrate tank articulation, team colors, model scale, and matching scene bounds.

## Stage 2 — Playable faction systems

- Add infantry, combat/repair robots, advanced armor, and missing structures.
- Connect production and construction menus to the expanded roster.
- Implement power capacity, lab prerequisites, repair behavior, and population limits appropriate to the demo.
- Keep existing AI, gathering, placement, rally points, selection, and victory behavior working.

## Stage 3 — Demo presentation

- Add a desert scenario with a playable starting force and enemy opposition.
- Provide a clear main-menu entry, readable resource/roster UI, and accurate unit descriptions.
- Add useful unit visual motion and targeting feedback.

## Stage 4 — Verification and delivery

- Import assets and parse scripts in Godot 4.6.
- Run existing startup/navigation checks and new faction-specific gameplay checks.
- Run the rendered demo, inspect screenshots/UI, and verify playable interactions.
- Document controls, assets, tested behavior, and remaining limitations.

## Agent progress

- Completed: inspected the existing RTS systems and original tank asset.
- Completed: generated 20 faction/environment GLBs, icons, and an editable Blender catalogue; independently re-imported every asset for validation.
- Completed: integrated all eight mobile units and nine structures, economy/power/production/prerequisites, repairs, team colors, articulation, and UI.
- Completed: added the desert AI demo, main-menu entry, direct Mac launcher, and tactical pause orders.
- Completed: rendered gameplay/UI previews and verified scaled viewport and paused-order behavior. Fixed harvesting integration, queue time consumption, construction HP, destroyed-target handling, selected-producer cleanup, and two-player skirmish slot filtering.
- Completed: faction and original-map regressions pass, all offensive unit types fire and damage targets, and formatting/lint checks pass. Recorded remaining Godot navigation and process-exit shader/resource diagnostics.
- Completed: launched the demo, verified factory selection through the live UI, and left it tactically paused for user review (Space resumes).
