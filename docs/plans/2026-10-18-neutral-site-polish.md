# Neutral sites and resource access

## Stages
1. Add visible refinery machinery tied to active income and expand relay vision.
2. Integrate mercenary recruitment into the standard bottom console, with exclusive infantry, queue progress, cancellation, and archive compatibility.
3. Arrange resource fields in compact circular arcs and verify simultaneous two-worker harvesting, travel, and map balance.
4. Run focused regressions and rendered reviews, then record outcomes and limitations.

## Result
- Captured refineries operate a nodding pump, moving piston, and running light. Contention, tactical pause, depletion, and match completion stop extraction animation.
- Mercenary camps use the existing bottom console, roster tiles, portraits, production queue, progress strip, and click-to-refund controls. Opening recruitment does not pause the battle. The facilities overview opens the same console.
- Three camp-exclusive units have separate scenes, combat statistics, equipment silhouettes, rendered portraits, weapon effects, and research support: Iron Warden (heavy shield infantry), Dust Ranger (fast marksman with 18 m vision), and Breach Lancer (heavy anti-armor rockets). Barracks retain their ordinary roster. Legacy paid camp contracts remain loadable.
- Relay vision increases from 9 m to 27 m. Refineries, camps, and repair shops retain 9 m local vision.
- All 16 selectable skirmish maps use compact circular resource arcs with 3 m node spacing, materials in the middle and electronics at the ends. Each starting node sits 18 m from HQ; the seven-node span is about 17.3 m, down from the initial 24 m row. Arcs follow terrain and maintain start symmetry. Authored field origins persist in saves so workers can use both ends without drifting into another field. Existing two-worker reservations were verified with actual simultaneous harvesting and deliveries for every faction.

## Verification
- `PointOfInterestRegression`: all three factions pass capture, income, active/contested/paused/depleted machinery, production-console interaction, recruitment/refunds, population reservations, blocked exits, ownership transfer, legacy contract validation, unique-unit combat and selection, and save/restore.
- `NeutralPolishRegression`: all three factions pass simultaneous two-worker mining and deliveries, arc spacing and equal starting-node HQ distances, both electronics endpoints belonging to one field, and actual relay fog/shroud radius.
- `ResourceFieldRegression`: all three factions pass two-worker collection, third-worker waiting, cancellation/death slot release, depletion, queued orders, and archive reconstruction.
- `StartingResourceRegression`: all expanded maps and factions pass home harvesting for both players, navigation geometry, and archive round trips. Additional archive checks confirm resource field origins survive restoration.
- `ExpandedMapRegression --geometry-only`: all expanded maps/factions pass shoreline, facility-clearance, resource symmetry, and approach checks.
- `MapResourceBalanceRegression`: full 23-map sweep passes with the final circular arc layouts. No balance tolerances were relaxed.
- `MercenaryCampPreview`: actual mouse clicks pass for all factions in English and Chinese, including recruitment while tactically paused. Captures: `art/neutral-sites/`.
- `NeutralSitesPreview`: reviewed refinery pump poses, specialist silhouettes, and resource arcs in the rendered game (`art/neutral-sites/resource-arc.png`).
- `HudConsolePreview` without `--headless`: all faction, resolution, and language scenarios pass; captures under `art/hud-console/` reviewed.
- Godot import, GDScript formatting/lint, and `git diff --check` pass.

## Compatibility and limitations
- Older saved games retain their recorded resource coordinates and stock; the new arc layout applies to new matches. Old paid generic camp recruits finish normally, while new contracts use the exclusive roster.
- Some headless/rendered test processes still report existing ObjectDB/resource-leak warnings during shutdown. Gameplay assertions complete with zero failures and no script errors.
- Existing command-reliability changes remain intact. No commit or release was requested.

## Agent progress
- All four stages complete.
- Final English/Chinese camp layout and interaction review passes for all three factions.
- User-requested spacing correction complete: compact circular arcs replace straight rows. Re-ran simultaneous two-worker mining, the full expanded-map starting-resource/save suite, and all 23 map balance checks with zero failures; reviewed the rendered arc.
