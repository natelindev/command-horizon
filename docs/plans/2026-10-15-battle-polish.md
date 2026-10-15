# Battle presentation, production and performance

## Stage 1 — Presentation and map life

Share a subtle tactical range ring between selected units and building previews. Replace overhead dots with requested player-color selection outlines. Translate map and HUD text in Chinese. Preserve destroyed vehicle scale and adjust wildlife, civilians and cars. Add playable-area settlements with compatible saves and navigable routes.

## Stage 2 — Production and faction progression

Balance production clicks across selected eligible buildings and expose their paid queues. Clear friendly exit blockers without replacing their orders. Improve construction and production pacing while retaining costs. Differentiate faction unlock paths and specialist production; improve Frontier wreck recovery and update AI priorities and tooltips.

## Stage 3 — Functional and visual verification

Exercise original failure scenarios, resource accounting, archives, all-faction exits and production, scale, localization and all-map civilian behavior. Inspect rendered Chinese gameplay. Measure funded reinforcement batches and standard resource-funded openings.

## Stage 4 — Performance

After functional and visual verification, profile a rendered large battle, remove measured render and simulation hotspots, rerun affected regressions and compare isolated before/after frame times. Check a separate ordinary gameplay sample and document remaining scale limits.

## Stage 5 — Chinese UI follow-up

Audit assembled UI strings in all faction menus, relay markers and overview, campaign HUDs and voice captions. Fix composite translation handling, verify live locale switching, and retain a regression audit plus rendered relay screenshots.

## Agent progress

- Implemented stages 1–2, including later requests for exit clearance, faction differentiation and production pacing.
- Verified functional fixes before starting profiling: all-faction production/scale, Chinese rendered inspection, 11-map routes and legacy archives.
- Measured 20-unit reinforcement batches at 60.1 seconds; standard paid openings reach the same force in 217–278.5 seconds depending on faction.
- Completed performance changes: cached minimap symbols, fewer redraws, dormant empty queues, settled idle structure visuals, spatial neighbor queries, cheaper visibility filtering and stationary navigation handling.
- Isolated 280-entity benchmarks reduced movement frame time by 69% and combat frame time by 83%, restoring approximately real-time simulation. Dense maximum-scale rendering remains below a smooth frame rate.
- Ordinary controlled gameplay measured 124 FPS at base and 89 FPS in midfield combat at 1600×900 on M1 Pro/Metal.
- Final reruns passed exit clearance, funded army pacing, battle polish, all 11 ambient maps, Chinese localization, salvage, resource inspection, combat, crowd boundary and guard arrival scenarios. Updated stale test fixtures to avoid lab occlusion, compare wreck identity safely after deletion, and use actual faction prerequisites.
- All four stages complete. Final AI composition verification, GDScript formatting/lint, translation generation and whitespace checks pass. Results and screenshots are recorded in `docs/playtests/2026-10-15/battle-polish/verification.md`.

- User screenshot exposed the decorated relay locator, which bypassed the translated title. Completed explicit marker composition, paused language switching, assembled tooltip handling and voice-caption coverage. Rendered audit passed 1,102 UI strings and 711 voice-caption entries; localization and relay interaction regressions passed.
