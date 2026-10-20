# Environment kits

## Horizon kit

Six editable Blender assets for Command Horizon's fortified industrial setting:

- **ServiceRuin:** fractured concrete shell, exposed roof trusses, collapsed lintel and masonry.
- **PumpStation:** banded reservoir, inspection hatch, ladder, railing, pump housing and feed pipes.
- **RelaySubstation:** finned transformers, porcelain insulators, switch cabinet and overhead busbar.
- **CutBerm1–3:** asymmetric basalt outcrops, retaining buttresses, old conduit and scree.

Rebuild from the repository root:

```sh
blender --background --factory-startup --python-exit-code 1 --python art/environment/build_environment.py
```

The generator writes `HorizonKit.blend`, `manifest.json` and six GLBs under `assets/models/environment/`. Independent asset collections remain at their local origin in the editable file. Blender uses Z up; glTF exports to Godot Y up. There are no externally sourced textures or models in this kit.

The generator measures evaluated mesh vertices and rejects assets exceeding the existing 5.6 m obstacle radius or 7 m sight-blocker height. The current maximums are 5.48 m radius and 6.47 m height. Keep rubble, pipes and service hardware inside these footprints; new solid silhouettes outside them need matching navigation and sight rules. Ground road markings, wear and service aprons are authored in `source/shaders/3d/horizon_ground.gdshader`; road endpoints come from the map script, so junctions share one continuous ground surface.

This is the first environment kit pass, not final art acceptance for the complete game. Wider region composition, off-map surroundings, vegetation, additional map identities and environmental audio remain on the development roadmap.

## Industrial building kit

`build_industrial.py` generates `IndustrialKit.blend`, `industrial-manifest.json` and five original GLBs under `assets/models/environment/industrial`: SawtoothWorkshop, CoolingHall, ServiceOffice, DamagedWarehouse and FurnaceBlock. Separate collections retain editable geometry at local origin. Roof seams, windows, doors, vents, pipework, fans, trusses and service clutter are modeled geometry; no external assets are required.

```sh
blender --background --factory-startup --python-exit-code 1 --python art/environment/build_industrial.py
```

The generator checks evaluated mesh vertices against 8 m radius / 6.9 m height for the four buildings and 5 m / 6.9 m for the furnace. Actual maximum warehouse bounds are 7.592 m / 6.397 m; the furnace is 4.564 m / 6.325 m. These limits intentionally differ from the Horizon kit, so its manifest remains separate. Industrial Crossroads uses four full-size buildings and two 0.75-scale outbuildings; Broken Foundry uses the kit within its unchanged solid footprints. `IndustrialLandmarks.gd` couples each mesh with its navigation/sight footprint and supplies aircraft clearance. Roads, junctions and aprons use `district_ground.gdshader`. See [verification](../../docs/playtests/2026-10-03/INDUSTRIAL_CROSSROADS.md).


## Moving neutral kit

`build_ambient.py` generates `AmbientKit.blend`, `ambient-manifest.json` and three GLBs in `assets/models/environment/ambient`: ResidentCar, Resident and Fox. All meshes are original. Cars have glazing, pillars, bumpers, lamps, mirrors and wheels; civilians have a coat, satchel and four animation pivots; foxes have four leg pivots and a tail. Maximum model height is 1.51 m; the vehicle is 1.135 m. Blender forward is -Y, which imports as Godot +Z. Preserve pivot names when editing the rig.

```sh
blender --background --factory-startup --python-exit-code 1 --python art/environment/build_ambient.py
```

`AmbientCatalog.gd` owns map routes and IDs, `AmbientActor.gd` owns travel, yielding, animation and current visibility, and `AmbientLife.gd` connects these to a map. Actors are scenery without gameplay groups or collision bodies. Routes must remain outside authored solid scenery. Changing a saved route's shape or length requires an explicit archive compatibility decision; IDs and route distances form part of snapshot version 6. See [verification](../../docs/playtests/2026-10-03/AMBIENT_LIFE.md).


## Coastal harbor kit

`build_coastal.py` generates `CoastalKit.blend`, `coastal-manifest.json` and six original GLBs under `assets/models/environment/coastal`: HarborCrane, HarborBeacon, CargoBarge, HarborTug, CoastalGull and ShorePines. Cranes include gantry bracing, a truss boom, cab, cable and hook. The beacon has a railed gallery and lantern; vessels have outward-facing hulls, cabins, glazing, freight/fenders and navigation hardware. Pine clusters include three layered crowns and low scrub. Independent collections retain editable geometry at the local origin.

```sh
blender --background --factory-startup --python-exit-code 1 --python art/environment/build_coastal.py
```

The generator validates evaluated radius/height against each asset's own manifest limits. Current radius/height maxima are 6.030/7.703 m for the crane, 2.650/7.300 m for the beacon, 6.033/4.100 m for the freighter, 2.287/1.180 m for the tug, 0.941/0.360 m for the gull and 2.681/5.092 m for the trees. Ships and gulls face Blender -Y / Godot +Z. Preserve `LeftWing` and `RightWing` pivot names. The tug's authored route is at -0.5 m relative to land, just above the water at -0.65 m.

`CoastalFoundry.gd` couples shore meshes to ground/sight/air clearance, and gives the moored freighter only sight/air clearance. The actual shore polygon, ground/water shaders, quays and overview/minimap share the map geometry. Ambient routes are catalog-owned; phase and travel are archived through the existing neutral contract. See [Coastal Foundry verification](../../docs/playtests/2026-10-03/COASTAL_FOUNDRY.md).


## Desert sandstone and freight kit

`build_desert.py` generates `DesertKit.blend`, `desert-manifest.json` and ten original GLBs under `assets/models/environment/desert`: four SandstoneShelf variants, three CanyonMesa variants, DryScrub, FrontierExtractionRig and AbandonedFreightBay. The editable Blender collections remain at their local origins. Layered asymmetric rock, broken weighhouse foundations, abandoned pipework, crane bracing, ladders, platforms and sage branches use original geometry and materials.

```sh
blender --background --factory-startup --python-exit-code 1 --python art/environment/build_desert.py
```

The four playable shelves fit the existing 5.8 m radius / 1.15 m height envelopes (actual maximums: 5.4805 m / 1.0954 m). Do not increase their height independently of navigation, sight, aircraft clearance and archive compatibility. Tall mesas and freight structures are placed entirely outside the 128×96 m playable rectangle. `DesertBackdrop.gd` authors their surrounding terrain and flattened foundations; it contributes no physics, navigation, sight or selectable entities. Twelve low scrub clusters inside the map remain below 0.3 m.

`frontier.gdshader` supplies sand, exposed iron-rich patches, wind ripples, continuous haul roads and a worn freight apron. `DesertMaterials.gd` applies `desert_stone.gdshader` to stone surfaces while preserving industrial materials. Desert Frontier owns its lighting and fog material instances. Optional scenery visibility applies only outside the playable rectangle; unexplored interior terrain and enemy units retain the existing visibility rules.


## Alpine granite and communications kit

`build_alpine.py` generates `AlpineKit.blend`, `alpine-manifest.json` and ten original GLBs under `assets/models/environment/alpine`: four GlacialShelf variants, two AlpineMassif variants, SnowPineGrove, MountainWeatherStation, AbandonedCableStation and WinterSedge. Independent collections preserve editable geometry at local origin. Granite, scree, survey remnants, conduit, layered conifers, branch snow, station glazing and antenna hardware are original modeled geometry.

```sh
blender --background --factory-startup --python-exit-code 1 --python art/environment/build_alpine.py
```

The shelves measure at most 5.8223 m radius / 1.092 m height, within the existing 6.5 m / 1.15 m gameplay envelopes. All tall mountains, trees and stations remain outside the playable 128×104 rectangle; twelve interior sedge clusters stay below 0.3 m. `AlpineBackdrop.gd` supplies surrounding terrain and flattened foundations without gameplay components. `alpine.gdshader` supplies continuous snow/ice/gravel, plowed roads and relay aprons; `AlpineMaterials.gd` applies world-space granite/snow weathering. The map owns its lighting/fog instances. See [alpine environment verification](../../docs/playtests/2026-10-03/ALPINE_ENVIRONMENT.md) for imported bounds, actual movement, relay transitions and rendered evidence.


## Supply Line freight-road kit

`build_supply.py` generates `SupplyKit.blend`, `supply-manifest.json` and six original GLBs under `assets/models/environment/supply`: RoadCutA, RoadCutB, RoadPumpStation, RuinedTransferBay, DrainageRemnant and RoadSage. Independent collections retain editable geometry at local origin. Sandstone strata, scree, the pump house, tank bands, ladder, pipes, broken canopy, trusses, crates, grates and sage use original geometry/materials.

```sh
blender --background --factory-startup --python-exit-code 1 --python art/environment/build_supply.py
```

The four solid models fit the mission's existing 5 m radius / 3 m height limits; maximum evaluated radius is 4.5835 m and height is 2.9222 m. Their Godot parents retain the old 0.6 m navigation alignment, with a compensating mesh offset that places model bases on the ground. Low drainage and sage remain below 0.3 m. The former scaled cliff visuals exceeded their gameplay envelopes; the new models restore that visual contract without moving blockers.

`SupplyLineMap.gd` preserves checkpoint, response and obstacle positions. `supply_ground.gdshader` creates the continuous road, worn paint, tyre tracks, concrete checkpoint aprons and soil. `SupplyBackdrop.gd` reuses the desert kit for exterior mesas and freight landmarks over continuous surrounding terrain; all its geometry stays outside the playable rectangle and carries no gameplay components. The map owns lighting/fog material instances. See [environment verification](../../docs/playtests/2026-10-07/SUPPLY_ENVIRONMENT.md). Final art acceptance and physical-device testing remain open.


## Quarry kit

`build_quarry.py` generates `QuarryKit.blend`, `quarry-manifest.json` and seven original GLBs under `assets/models/environment/quarry`: QuarryBenchA/B/C, QuarryContainerA/B, QuarryCrusher and QuarryConveyor. Independent collections preserve editable geometry at local origin. Layered cut stone, scree, drill scars, container hardware, crusher bracing, cyclone/ducts, deck railings, ladders and conveyor structure use original geometry/materials.

```sh
blender --background --factory-startup --python-exit-code 1 --python art/environment/build_quarry.py
```

The kit was built for the retired Air Corridor operation. It now supplies Cinder Ring's bench landmark, the freight-container neutral landmarks and the crusher/conveyor in tunnel campaign interiors. `QuarryMaterials.gd` weathers the `Quarry *` stone materials through the desert stone shader.
