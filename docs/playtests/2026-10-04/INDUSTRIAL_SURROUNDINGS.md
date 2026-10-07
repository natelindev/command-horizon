# Industrial Crossroads surroundings — 2026-10-04

Industrial Crossroads now sits within a rail and utility district. This pass adds five original editable assets, 23 exterior placements, a freight siding, service yards, birch scrub and distant embankments. Ground wear and industrial surface weathering soften the original blockout. The playable 128 × 104 m rectangle, six existing landmark envelopes, three crossing streets, two relays and four resource fields retain their gameplay contracts.

## Rendered comparison

- [Before, 900p overview](../../../art/skirmish/environment/industrial-surroundings-before-overview.png) → [revised overview](../../../art/skirmish/environment/industrial-surroundings-overview.png).
- [Rail service yard](../../../art/skirmish/environment/industrial-surroundings-rail-yard.png), [utilities court](../../../art/skirmish/environment/industrial-surroundings-utilities.png), [east maintenance yard](../../../art/skirmish/environment/industrial-surroundings-east-edge.png) and [central junction](../../../art/skirmish/environment/industrial-surroundings-junction.png).
- Ordinary fog: [home](../../../art/skirmish/environment/industrial-surroundings-home-fog.png), [north perimeter](../../../art/skirmish/environment/industrial-surroundings-shore-fog.png), [hidden enemy territory](../../../art/skirmish/environment/industrial-surroundings-enemy-fog.png).
- Actual normal-clock combat, captured during tactical pause: [Bastion](../../../art/skirmish/environment/industrial-surroundings-combat-bastion.png), [Helix](../../../art/skirmish/environment/industrial-surroundings-combat-helix.png).

Captures use the real Godot renderer at 1280 × 720 and 1440 × 900 with 125% interface scaling. The preview runs actual combat for both factions, checks damage/current observation and verifies that pause freezes simulation and positions. The enemy HQ pixel remains dark under ordinary fog. This pass changes no controls and does not claim new native-input acceptance.

## Implementation and verification

The [editable kit and builder](../../../art/environment/INDUSTRIAL_SURROUNDINGS.md) retain named meshes and material assignments. Imported vertex checks cover the actual GLBs, not only their authoring manifest. All exterior geometry stays outside the playable rectangle and has no collision or navigation input. Original landmark meshes still fit their existing movement and flight envelopes. Terrain edges match height and normals; model footprints sit on level foundations.

Wear is opt-in on a duplicated district material. Broken Foundry continues using the shared shader's original defaults. Exterior fog visibility is local to this map; changing maps restores the ordinary behavior. Street surfaces continue through the boundary while minimap, pathfinding and construction still use the authored battlefield.

| Check | Result |
| --- | --- |
| Both-faction routes | Three simultaneous 16-tank street advances and retreats, moving disk archives, junction placement/sight/fire, drone and strike-aircraft crossings pass. Base and expansion route estimates remain 45.1 / 20.5 seconds. |
| Economy and objectives | Both home fields and outer electronics returns, charged/completed construction, infantry access to both relays, capture/recapture and exact relay restoration pass for both factions. |
| Geometry | Five bounded assets, 23 exterior placements, imported vertices, level foundations, seam normals, navigation isolation and original roof envelopes pass. |
| Rendered behavior | Hidden enemy fog, normal-clock combat damage/current observation, paused positions and simulation time pass for both factions. |
| Shared behavior | IndustrialEnvironmentRegression (all district and Foundry roof crossings), IndustrialAIRegression, BrokenFoundryRegression, MapStartupRegression, AmbientLifeRegression, EnvironmentAudioRegression and SaveRestoreCombat pass. The six-minute AI run builds eight structures per faction and launches four attacks per faction. |
| Static/import | Focused formatting/lint, whitespace and Godot import pass. Both new/updated surface shaders compile in the real preview. |

The [verification manifest](industrial-surroundings-verification.json) records accepted checks and hashes. The [shared runner](industrial-surroundings-verify.py.txt) records individual suite exits and script/load diagnostics. Original source is retained in [the map baseline](industrial-surroundings-before-map.gd.txt).

## Iteration and limits

The first rendering exposed capped original street ends against the exterior road strips. The private display material now extends those street segments continuously. Service paving connects the utility and rail compounds, and a final foundation pass flattens the sloping outer terrain under each structure. Final image review also caught the foundation blend raising soil into the railway ballast; moving the distant rise back and checking the entire track footprint fixes that visual intersection. Intermediate logs are retained; acceptance uses the final foundation and reviewed-render runs.

Known navigation mesh readback and shutdown RID/ObjectDB/resource warnings remain in raw logs. Accepted runs contain no script/load failures. This verifies the environment implementation and retained mechanics; subjective final art approval, repeated contested full-match balance, novice usability and platform/release acceptance remain open. No performance benchmark was run; performance optimization stays deferred. The broader game-development goal remains active.

## Reproduction

```sh
blender --background --python art/environment/build_industrial_surroundings.py
godot --headless --path . --editor --quit
godot --headless --path . --fixed-fps 60 --script tests/headless/IndustrialSurroundingsRegression.gd
godot --path . --script tests/rendered/IndustrialSurroundingsPreview.gd
```

Verified with Godot 4.6 on the development M1 Pro and Blender 5.2.1 LTS.
