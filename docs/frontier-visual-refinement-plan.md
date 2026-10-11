# Frontier visual refinement

## Stages
1. Replace enlarged polygon scrub with four deterministic desert tree variants, retaining scenery placement and gameplay clearances.
2. Give Frontier surfaces a subdued, weathered material treatment with readable fabric and metal detail.
3. Replace the rally dot with a flag and connecting route, including resource and moving-unit destinations.
4. Verify rally retargeting/save behavior, desert navigation, and rendered gameplay at two zoom levels.

## Agent progress
- Identified the repeated trees as a single low-poly scrub model stretched vertically; rally targets currently hide their marker.

## Added gameplay stages
5. Add local allied-defense aggression with clear interaction with manual orders.
6. Track match production, harvested resources, and destruction; present a victory/defeat statistics screen and preserve counters in saves.
- Implemented four authored tree meshes with individual folded leaf sprays and tapered branches; replaced repeated shrubs in playable and exterior scenery.
- Added shared weathered Frontier materials and a screen-space rally flag, route, and direction arrow.
- Added nearby idle-unit assistance with a bounded pursuit area; manual orders and active programs retain priority. Defensive state is saved with the existing attack action.
- Expanded saved battle records with actual mining, completed construction, and lethal-hit counters; added a scrollable result table with keyboard-accessible actions.
- Initial verification: rally retarget/save/delivery and battle debrief suites passed for all three factions. New defense/statistics test and native rendering passed. Visual review prompted softer canvas detail and replacement of remaining exterior shrubs.
- Final coverage: also replaced stretched shrubs in the living-world desert town; a shared tree catalogue keeps all three scenery systems consistent. Rally routes now render in the base match layer, including non-skirmish matches.
- All stages complete. Verified actual defensive movement and firing, manual override, pursuit cutoff, saved defensive state, real mining/construction/kill accounting, legacy record compatibility, and saved statistics.
- Passing suites: AlliedDefenseStatisticsRegression, RallyRetargetRegression (three factions), BattleDebriefRegression (three factions), HQCountdownRegression (Victory/Defeat/Draw), CombatRegression, FrontierAssetRegression, and DesertEnvironmentRegression (both factions). Headless simulation checks use `--fixed-fps 60`; the initial unrestricted render-frame-based desert run had timing-related route failures, resolved by the fixed timestep.
- Native rendered review passed: wide/close and moving-target rally markers, four tree silhouettes, Victory, and Defeat at 720p / 150% interface scaling. Captures are in `tmp/frontier-refinement/`.
- Formatting, shader formatting, Python compilation, and diff whitespace checks pass. Lint on new code passes; seven existing warnings in FactionCatalog/SnapshotSchema were confirmed against HEAD. Godot tests still emit resource/shader cleanup warnings on shutdown.
