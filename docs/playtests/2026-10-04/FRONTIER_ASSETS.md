# Free Frontier roster verification — 2026-10-04

Subsequent update: [gameplay integration and acceptance](FRONTIER_GAMEPLAY.md) now supersedes the stage-1-only status below. This report preserves the original asset verification scope.

Stage 1 delivers seventeen proposed third-faction subjects: eight mobile roles and nine structures. [Roster, build commands and integration contract](../../../art/frontier/README.md). The editable Blender scene, GLBs, matching transparent icons, individual renders and catalogue are present. Frontier is not yet selectable; no production game logic or archive schema changed in this stage.

## Evidence

- Blender 5.2.1 rebuilt all assets and reimported every exported GLB. [Machine-readable verification](../../../art/frontier/v1/verification.json) records role/name, triangles, meshes, rotors and pass state. All seventeen pass material presence, team-color material, finite coordinates, nondegenerate triangles, reimported bounds, nonempty articulation, required turrets, forward muzzles, exact rotor counts and nonempty/unclipped 256px icon checks.
- Total exported geometry: 47,846 triangles across 65 rigid meshes; individual assets range from 644 to 7,716 triangles. These are asset counts, not a frame-time or release-performance claim.
- Godot 4.6 headless editor import completes, then `tests/headless/FrontierAssetRegression.gd` reports [zero failures](frontier-assets/godot-import.txt). It instantiates the actual seventeen GLBs and role scenes, applies the existing faction normalization formula, checks nonempty finite bounds and ground alignment, forward combat muzzles, discovered/rotatable child geometry and imported icons.
- `tests/rendered/FrontierAssetPreview.gd` runs using native Metal Forward+ on the M1 Pro at 1280×720. Both contact views capture with [zero out-of-viewport model failures](frontier-assets/native-preview.txt). The [mobile roster](../../../art/frontier/v1/godot-units.png), [structures](../../../art/frontier/v1/godot-buildings.png), full Blender catalogue and individual Outrider/HQ renders were visually reviewed. Canvas structures, low wheeled chassis, open machinery and rotor layouts remain identifiable. These are controlled asset views, not battlefield/fog acceptance.
- Python compilation, changed GDScript formatting/lint and documentation whitespace checks pass.

## Corrections made during verification

The first authored rotor names did not match the current runtime's numbered-rotor wildcard. Renamed the drone rotors `Rotor0`–`Rotor3` and gunship rotor `Rotor0` before final exports; the real Godot test confirms discovery and moving child transforms.

Initial reimport exposed four extremely small triangles in the Scrapper rig's merged rigid body (minimum area approximately 2.9e-11 square metres). Tightened the export cleanup threshold from 1e-10 to 1e-8 and rebuilt the full set; the original reimport checker then passes unchanged.

Increasing the native review magnification clipped the three-row structure view. Adjusted its camera framing and added projected-bounds checks for every model. Raised review labels above depth occlusion. The final captures pass and show all seventeen subjects.

## Remaining work

Stage 2 must implement finite wreck salvage, faction-specific retrofit price/time, coordinated mobility and doctrine, full catalogue/stats/AI/program integration, explicit random-opponent preference migration and validated archive support before menu exposure. Stage 3 must prove paid economy, actual combat/counters, authority, research, salvage conservation, all-map travel and save/load with native player controls.

Detailed mechanics/numbers and working names remain provisional. Art integration must review the Ironback's hull size relative to the Outrider: both normalize to the shared role radius, while the longer cannon reduces the heavy hull's on-screen size. Wheel pivots are exported but not animated by the current runtime. Combat animation, fog/team-color recognition, battle audio, faction balance, novice acceptance and final environment/release gates remain open. Performance work stays deferred.
