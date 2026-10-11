# Visual world upgrade

1. Establish a cinematic industrial frontier art direction. Generate project-owned menu art and build responsive, animated native controls with a shared theme.
2. Add a shared atmosphere controller: moving sun, time presets/cycle, weather transitions, fog, shadows, ambient occlusion, glow, and optional camera depth of field. Expose supported features in persistent graphics settings with preview/cancel behavior.
3. Enrich the existing maps with coherent inhabited districts, riverside scenery, distant relief, foliage, and animated civilian/wildlife activity while preserving combat navigation and fog of war.
4. Verify settings persistence/rollback, atmosphere behavior, map compatibility and gameplay regressions. Capture and inspect rendered menus and day/night/weather scenes.

## Agent progress

- Inspected existing rendering, map backdrops, ambient actors, menus and settings. Existing scenery and a small ambient population provide reusable foundations; shadows are enabled but configured with excessive bias, and graphics options are absent.
- Working on stages 1–3.
- Completed the original generated menu artwork, animated native UI, shared menu styling and a reduced-motion option.
- Completed persistent graphics controls and the shared atmosphere controller, including deterministic weather fronts, moving sun/moon, shadows, SSAO, fog, bloom, MSAA, optional DOF and rain.
- Completed inhabited district scenery, river/bridges, biome-specific mountain/settlement details, lighting and ambient population; preserved industrial obstruction envelopes and coastal water.
- Passed settings, graphics, menu scaling/input, keybindings, ambient life, industrial movement/economy/archive, map startup, combat and rendered QA. Source formatting/lint and whitespace checks pass. Fixed a detached-observer access exposed by repeated map switching.
- Final screenshots, implementation boundaries and verification details are in `docs/visuals/visual-world-upgrade.md`. All four stages complete.
