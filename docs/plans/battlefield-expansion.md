# Battlefield expansion

Add five two-player and eight four-player skirmish maps with distinct scenery and tactical layouts. Keep the three existing maps and stable saved map paths.

## Stage 1 — Authored battlefields

- Create a shared map builder with explicit, deterministic map profiles.
- Author canyon, salt-flat, woodland, glacial, industrial, volcanic and harbor settings with different lanes, obstacles and expansion patterns.
- Give every start equal opening stocks and distances, accessible expansions and capturable facilities.

## Stage 2 — Playable four-player matches

- Register all maps, show every start and terrain feature in previews, and create one human plus three independent AI opponents on four-player maps.
- Support elimination, victory, save validation and restoration for all four sides while preserving two-player and campaign behavior.
- Add English and Chinese names and descriptions.

## Stage 3 — Verification

- Check all maps for startup errors, resource balance, traversable routes, facility access and correct previews.
- Exercise four-player outcomes and save/restore, plus existing roster and save regressions.
- Render every new map and inspect the scenery and setup UI.

## Agent progress

- Inspected current map, navigation, menu, atmosphere and save systems. Found two-player assumptions in setup, victory and save validation/restoration that must be addressed for playable four-player maps.
- Stage 1 complete: thirteen authored scenes, terrain palettes and surface treatments, biome scenery/audio, eight/twelve resource fields, six/twelve capturable facilities, ground-blocking water and aircraft-clearance landmarks.
- Stage 2 complete: sixteen-map picker, all start markers, English/Chinese copy, four-player free-for-all setup, surviving-opponent AI targeting, elimination and full four-player save/restore.
- Stage 3 complete: all thirteen maps passed geometry/economy symmetry/save checks; ten representative starts passed actual harvesting, paid tank production and departure; four-player victory/defeat/draw and elimination restoration passed. Existing roster migration and AI coordination regressions passed. Rendered all thirteen maps and reviewed the faction HUD fixture in English and Chinese.
- Existing unrelated workspace changes preserved. Two older campaign checkpoint assertions also fail with this task's gameplay/save changes removed; the Lua snapshot fixture calls the currently disabled custom-Lua interface. See [verification](battlefield-expansion-verification.md) for details.
