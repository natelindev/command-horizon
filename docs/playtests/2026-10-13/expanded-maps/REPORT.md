# Expanded skirmish maps — 13 October 2026

Three larger maps are selectable in Skirmish. A fresh setup selects Expanded Desert Frontier; saved selections retain their chosen map. Existing six menu indices and original map paths/layouts remain available for old archives. New preferences store stable scene paths and still read old numeric selections.

| Map | Size | Starting HQ markers (x, z) | Resource field centers (x, z) |
| --- | --- | --- | --- |
| Expanded Desert Frontier | 192 × 144 m | (27, 39), (165, 105) | (21, 64.5), (171, 79.5), (78, 9), (114, 135), (34, 104), (158, 40), (52, 58), (140, 86) |
| Expanded Alpine Relay | 192 × 156 m | (25.5, 27), (166.5, 129) | (19.5, 51), (172.5, 105), (45, 87), (147, 69), (32, 112), (160, 44), (70, 20), (122, 136) |
| Expanded Coastal Foundry | 192 × 156 m | (24, 51), (168, 51) | (24, 69), (168, 69), (36, 121.5), (156, 121.5), (24, 96), (168, 96), (58, 143), (134, 143) |

Each map has eight fields / 32 deposits, with 6,600 materials and 4,320 electronics initially available. Field locations and stocks are paired between starts. Desert/alpine fields rotate around the map center; coastal fields reflect across the harbor's center line. The coastal electronics offsets also reflect horizontally, preserving equal depth from both starts.

| Map | Refineries | Mercenary camps | Repair shops |
| --- | --- | --- | --- |
| Desert | (66, 20), (126, 124) | (44, 82), (148, 62) | (84, 68), (108, 76) |
| Alpine | (50, 45), (142, 111) | (56, 114), (136, 42) | (72, 78), (120, 78) |
| Coastal | (56, 78), (136, 78) | (78, 149), (114, 149) | (62, 104), (130, 104) |

The six POI nodes on each map use the shared PointOfInterestCatalog. Their footprints have at least 14 m clearance from deposits and major solid landmarks, with four navigable approaches at 6 m. Coastal sites avoid existing civilian traffic loops. The setup preview displays all fields and R/M/+ facility markers with a readable legend.

Existing biome scenes, models, materials, atmosphere and audio supply the presentation. Landmarks retain their original physical dimensions; repositioning opens wider travel corridors. The coastal shoreline is triangulated at the new size, seawalls remain continuous, and ground navigation excludes the water. Coastal ground/water shaders gain a default-1 layout_scale parameter: original maps still use their original coordinates, while the expanded coastal map aligns existing visual masks to its larger geometry. Wildlife/traffic loops and destructible coastal landmarks are retained through explicit expanded-map aliases; alpine scenery remains alpine and coastal scenic districts remain on the inland edge.

## Verification

- Full expanded suite: **0 failures**, 9 faction/map combinations, 72 field cases with real materials and electronics delivered to HQ, plus paid tank production and egress from both live advanced bases on all three maps.
- A later coastal horizontal-pair correction: **0 failures** in the coastal-only rerun, all 3 factions, 24 field cases and both live factory exits.
- Latest resource symmetry/geometry checks: **0 failures** across all 9 combinations, including exact paired resource positions/stocks, base-to-base paths, six populated sites and their approach rings, coastal water rejection, existing biome audio/life and seven destructible coastal landmarks.
- Existing EnvironmentAudioRegression, AmbientLifeRegression and NeutralWorldRegression: **0 failures**.
- Existing-style rendered menu, full-map and facility previews were generated for all three maps and inspected. Formatting, lint and git diff --check passed for the changed files.

Resource tests remove frozen opening mobile units to isolate authored map routes; the paid factory exit cases retain the live starting army. HQ delivery around idle opening units is tracked separately in the mechanics regression work. These checks establish map reachability, resource continuity and production exits; they do not establish human match balance or subjective pacing. Existing engine cleanup warnings remain in raw logs. EnvironmentAudioRegression deliberately exercises failed saves into a missing directory.

Reproduce with the local Godot executable:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script res://tests/headless/ExpandedMapRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script res://tests/headless/ExpandedMapRegression.gd -- --coastal-only
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script res://tests/headless/ExpandedMapRegression.gd -- --geometry-only
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script res://tests/rendered/ExpandedMapsPreview.gd
```
