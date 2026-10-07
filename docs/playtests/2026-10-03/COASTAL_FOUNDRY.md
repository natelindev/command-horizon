# Coastal Foundry — harbor routes and environment

## Delivered layout

Coastal Foundry is a selectable 128×104 skirmish map. Opposite bases sit on the two sides of a harbor inlet. Ground forces go around the water, then choose the quay road or the inland road behind two opaque foundries. Aircraft can cross the inlet directly. HQ destruction and the existing recovery countdown remain the victory condition; ships are scenery.

Each home field has 600 materials / 240 electronics, and each expansion has 900 / 400. Four paired deposits per field retain usable gaps. Basic-tank navigation estimates at 2.6 m/s are **51.1 seconds between bases** and **22.5 seconds to the western expansion**. The measured base route is 133.0 m on land versus 96.0 m by air. These estimates use the actual baked navigation mesh and exclude combat and traffic.

Six original editable Blender assets provide gantry cranes, harbor beacons, a moored freighter, a moving tug, gulls with wing pivots, and clusters of coastal pines. The map reuses the industrial workshop and cooling hall. Continuous concrete/asphalt/turf treatment, quay walls, bollards, shoreline foam and animated water establish its harbor setting. Water derives its animation from the simulation clock, including pause and restoration. Two cars, six residents, four gulls and one tug follow authored loops; ground traffic yields to military units, while gulls and the tug remain on their separate water routes.

The land polygon supplies the actual navigation mesh. Water is excluded from ground navigation and construction, while the rectangular air domain spans the inlet. Solid shore landmarks supply navigation, sight and aircraft-clearance footprints. The moored freighter blocks sight and raises aircraft clearance without snapping to land or carving away the neighboring quay. Maximum authored aircraft altitude is 9.3 m above the crane, within the existing archive position bounds.

## Corrections found during verification

- The first terrain mesh had reversed triangle winding. It rendered from below and produced no ground navigation. Correct winding now renders the surface and produces the expected routes; land construction and both military/economy travel pass.
- The inherited black background plane sat above the new water and hid it. It now sits below both terrain and water.
- Vessel hull normals were corrected outward. The freighter roof uses a light material so it remains distinct from the water. Water normals/highlights were softened and varied after the first rendered review showed a repetitive dotted pattern.

## Verification

| Check | Result |
| --- | --- |
| Both factions, Advanced | Two simultaneous 16-tank groups advance along the quay and inland roads, survive a mid-movement disk archive, then retreat. |
| Terrain and placement | Three water samples reject construction and lie outside the ground navmesh; land accepts placement. Sampled cross-inlet ground routes stay on land. |
| Aircraft | Both drone and strike-aircraft types actually cross every one of the 11 landmarks. A strike aircraft archived at crane height retains its position and resumes a crossing over water. |
| Both factions, Standard | All home deposits are initially observable, both home currencies return, both outer electronics return, and a paid power plant completes. |
| Full field access | Eight paired material/electronics checks cover all four fields with both starting-faction arrangements. Every check delivers at least four of each currency to an existing HQ. Home returns take 13.8–15.9 s; outer returns take 34.9–40.7 s. |
| Normal AI, six minutes each | Bastion builds 8 structures, launches 4 attacks, produces 11 units and inflicts 3,405 HQ damage. Helix builds 8, launches 4, produces 12 and inflicts 3,542 damage. |
| Ambient regression, six maps | Route/scenery separation, movement, ground yielding, current-observation fog, pause, target isolation, exact archive poses, invalid record rejection and version-5 migration pass. Coastal checks also distinguish land routes from water routes and verify both gull wing pivots. |
| Map UI and rendering | Preview/minimap include the inlet. Native mouse selection and Start Battle launch Standard forces with ordinary fog. Rendered 1280×720 and 1440×900 views were inspected for terrain, docks, vessels, trees, civilians and UI readability. |

Reproduce from the repository root, substituting the installed Godot executable:

```sh
godot --headless --fixed-fps 60 --path . --script tests/headless/CoastalRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/CoastalAIRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/ResourceMapEconomyRegression.gd -- --coastal-only
godot --headless --fixed-fps 60 --path . --script tests/headless/AmbientLifeRegression.gd
godot --path . --script tests/rendered/CoastalPreview.gd
godot --path . --script tests/rendered/CoastalLaunch.gd
```

`CoastalLaunch.gd` waits for a real Start Battle click, checks the loaded map/start/population, captures it, and restores prior options/configuration before exiting. `CoastalPreview.gd` sets up revealed views for artwork inspection; these are separate from the native normal-fog launch.

Screenshots: [map menu](../../../art/skirmish/environment/coastal-menu-720p.png), [normal-fog launch](../../../art/skirmish/environment/coastal-native-launch.png), [overview](../../../art/skirmish/environment/coastal-overview.png), [crane](../../../art/skirmish/environment/coastal-crane.png), [vessels](../../../art/skirmish/environment/coastal-vessels.png), [foundries](../../../art/skirmish/environment/coastal-foundries.png), [900p view](../../../art/skirmish/environment/coastal-wide-900p.png).

Formatting, GDScript lint, Blender/Python generation, editor import and whitespace checks pass. Final listed suites report no failed assertions or script errors.

## Limits

Movement/economy checks isolate combat; AI checks use a stationary, high-health human HQ to keep the observation window open. These establish functioning routes, income, production and attacks, not fair-match balance or novice pacing. Existing navigation-readback and exit-time renderer/ObjectDB/resource warnings remain. Off-map surroundings, richer terrain composition, environmental audio, repeated contested matches and broader release acceptance remain open. Performance optimization remains deferred.


## Later environment follow-up

[The 2026-10-04 coastal pass](../2026-10-04/COASTAL_ENVIRONMENT.md) now provides the missing surroundings, shaped coastal relief, port infrastructure and ground/landmark detail. Its imported-envelope, fog, actual ground/air/economy/archive and rendered combat checks retain the original map contracts. Environmental audio was separately delivered; subjective final art and broader match/release acceptance remain open.
