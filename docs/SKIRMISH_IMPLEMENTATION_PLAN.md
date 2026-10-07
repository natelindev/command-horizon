# Playable two-faction skirmish

## Stage 1 — Shared faction integration

Keep stable gameplay role identifiers for navigation, gathering and construction, and add faction-specific presentation, models, statistics and prices. Integrate all Helix units/buildings, including construction previews and production icons. Preserve the Bastion art demo.

## Stage 2 — Setup and match flow

Build a dedicated single-player skirmish screen with map, player/enemy faction (including random enemy), difficulty and starting-force options. Add match identity, tactical pause, objective progress, result/restart/return controls and normal starting economies.

## Stage 3 — Opponent and gameplay

Provide a faction-aware opponent that harvests, constructs, produces and attacks. Verify both factions can build their complete rosters and fight ground/air opponents. Keep unavailable programming systems outside the playable UI.

## Stage 4 — Verification and delivery

Test faction combinations/random resolution, starts/maps, construction/production/prerequisites, AI activity, pause, victory/defeat and restart. Run actual rendered setup/match flows and inspect screenshots. Update documentation with implemented behavior and remaining limitations.

## Stage 5 — Movement reliability follow-up

Reproduce the reported sticking, reconcile navigation and avoidance footprints, correct movement integration and path lifecycle, and verify building/rock routes, crowd traffic, construction access and factory exits.

## Agent progress

- Completed: inspected the shared RTS systems and preserved the existing Bastion demo/model viewer.
- Completed: integrated both faction rosters, models/team colors, prices, stats, prerequisites, construction and production.
- Completed: setup screen, three maps, faction/random choices, difficulty/start modes, attack move, tactical pause and result/replay flow.
- Completed: resource-paying AI for both factions, economy/build order, scouts and attack waves.
- Completed: headless scenario suite and legacy Bastion regression; rendered setup/gameplay checks, including 1280×720 layout and native mouse interaction.
- Completed: construction-click regression; placement now uses the click event position.
- Completed: reproduced navigation failures, corrected obstacle footprints and movement integration/lifecycle; headless regressions pass for factory routes, crowds, harvesting, construction and dynamic obstacles.
- Completed: rendered movement/rock regression and final skirmish suite; fixed per-match navigation resource isolation; editor import, lint, formatting and diff checks pass.
- Completed: launcher, README, living design and verification report updated. Known renderer shutdown diagnostics and unmeasured 200-unit performance are documented.
