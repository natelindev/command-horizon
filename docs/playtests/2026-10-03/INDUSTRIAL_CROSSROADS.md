# Industrial Crossroads and Foundry environment — 2026-10-03

Industrial Crossroads is now a selectable 128×104 skirmish map. Three east–west streets and three connecting spines surround opaque workshops, offices, a cooling hall and a damaged warehouse. Infantry can reach two optional vision relays beside the outer junctions. HQ destruction remains the win condition. Broken Foundry now uses the same building kit, including two furnace blocks, within its established navigation and sight footprints.

Follow-up: the [shared resource-navigation correction](RESOURCE_NAVIGATION.md) now fixes resource clearance and map startup across existing maps. Industrial's full regression still passes; its updated path estimates are **45.1 / 20.5 seconds**. The 44.9 / 24.1 figures below record the initial map delivery before that correction.

## Delivered stages

1. **Layout and assets:** five original editable Blender models, six map buildings, continuous road junctions, curbs, service aprons, roof hardware and revised lighting. Two resident cars, eight walking residents and four foxes use authored routes. Their shared yielding, fog, pause and archive behavior applies here too.
2. **Game integration:** skirmish selection, tactical preview/minimap, paired finite fields, infantry relays, AI assignments, snapshot validation and real aircraft clearance. Appending the map preserves existing menu indices. Snapshot version 6 stores its two relays and 14 neutral actors through the existing contracts.
3. **Verification:** both-faction transit, resource return, paid construction, capture, archives, six-minute AI runs, all-roof flight tests, Foundry mission regression and native menu/launch review.

Each home field contains 600 materials and 240 electronics; each outer field contains 900 materials and 400 electronics. The map has 16 deposits totaling 3,000 materials and 1,280 electronics. Final navigation estimates are **44.9 seconds base-to-base** and **24.1 seconds to the first expansion** for a 2.6 m/s basic tank, within the 35–55 / 15–25 second design targets. These are path estimates, not measured first-contact times.

## Verification and fixes

| Check | Result |
| --- | --- |
| Both-faction Advanced movement | Sixteen tanks advance and retreat along each of three street approaches; connecting paths and mid-movement disk restoration pass. |
| Both-faction Standard economy | Materials/electronics return from both home fields, electronics return from both expansions, and actual paid Power Plant placement/construction pass. All four deposits at each starting field are initially observed. |
| Solid scenery and objectives | Model bounds, placement rejection, open-junction placement, sight obstruction, actual infantry access/capture, contest/partial recapture, vision, AI assignments and relay archives pass. |
| Aircraft | Drone and Helicopter traverse all six roofs on each map without clipping or stalling. Actual altitude remains at least 1 m above the sight-blocker height inside the tested footprint. Paused archives retain the exact 8 m unit position. |
| Moving neutrals | Five-map motion, route clearance, yielding, fog/LOS, tactical pause, archive restoration, legacy defaults and malformed-archive rejection pass. |
| Bastion AI, six simulated minutes | Eight structures, four attack waves, eleven produced units, 3,265.2 actual HQ damage. |
| Helix AI, six simulated minutes | Eight structures, four attack waves, twelve produced units, 3,667.5 actual HQ damage. |
| Broken Foundry | Full production, budget, support, geometry, capture, reward and archive suite passes; real Standard victory at 157.90 simulated seconds with 15 surviving mobile units. |
| Native UI | Actual popup keyboard selection and Start Battle mouse input pass; the loaded Standard map has two relays and 14 neutrals. Menu, normal fog and 720p/900p environment views reviewed. |

An extended economy run exposed an engineer carrying electronics stopped between material piles. The original 2.5 m center spacing exactly equaled the combined deposit and worker diameters, leaving no avoidance clearance even though the baked navigation path admitted passage. Industrial's material spacing is now 3.5 m, with the electronics deposit offset 6.5 m. The focused failing return route and the full both-faction economy suite pass after this change. Home fields also moved into starting observation. This fixes the new map; equivalent spacing on older maps still needs an audit.

Two test-fixture issues were corrected without relaxing gameplay rules: the longer combined suite exceeded an inherited 600-second test timeout, so its bound is now 1,200 seconds; synthetic popup key injection did not reliably control the native popup, so the final interaction check used native keyboard input. Earlier failing runs remain separate from the final passing evidence.

The five-model generator validates evaluated mesh bounds: warehouses have a maximum radius of 7.592 m and height of 6.397 m against 8 m / 6.9 m limits; the furnace is 4.564 m / 6.325 m against 5 m / 6.9 m. Broken Foundry retains its original obstacle positions, radii and sight heights. Road surfaces use one continuous shader treatment, avoiding overlapping road meshes at junctions.

Final gameplay and preview runs have zero failed assertions and no script errors. Formatting, lint, editor import and whitespace checks pass. Existing navigation mesh readback and shutdown shader/resource warnings remain.

## Evidence

- [District overview](../../../art/skirmish/environment/industrial-overview.png), [900p view](../../../art/skirmish/environment/industrial-wide-900p.png)
- [Workshop roofs](../../../art/skirmish/environment/industrial-workshop.png), [office](../../../art/skirmish/environment/industrial-office.png), [cooling hall and ruin](../../../art/skirmish/environment/industrial-hall-and-ruin.png)
- [Street junction](../../../art/skirmish/environment/industrial-junction.png), [menu](../../../art/skirmish/environment/industrial-menu-720p.png), [native Standard launch](../../../art/skirmish/environment/industrial-native-launch.png)
- [Foundry district](../../../art/skirmish/environment/industrial-foundry-overview.png), [furnaces](../../../art/skirmish/environment/industrial-foundry-furnaces.png)

Environment previews reveal the map and disable military simulation after initial fog setup; neutral activity continues. Native launch uses ordinary starting fog. AI checks use a stationary, high-health human HQ to preserve the entire six-minute observation window. These checks establish functioning production and attacks, not fair-match balance or novice pacing. Broader terrain composition, off-map surroundings, vegetation, audio, Coastal Foundry and repeated complete-match acceptance remain open. Performance optimization remains deferred.

## Reproduce

From the repository root, use Godot 4.6:

```sh
godot --headless --fixed-fps 60 --path . --script tests/headless/IndustrialRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/IndustrialEnvironmentRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/IndustrialAIRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/AmbientLifeRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/BrokenFoundryRegression.gd
godot --path . --script tests/rendered/IndustrialPreview.gd
```

`IndustrialRegression.gd -- --economy-only` isolates the cargo-return scenarios. `IndustrialPreview.gd -- --menu-inspect` waits for actual selection of Industrial Crossroads. `IndustrialLaunch.gd` opens its Standard setup and waits for an actual Start Battle click, then verifies the loaded map and restores prior local preferences on normal completion.
