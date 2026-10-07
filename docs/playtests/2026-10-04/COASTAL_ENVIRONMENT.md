# Coastal Foundry environment follow-up

Coastal Foundry now sits within a continuous sea and coastal landscape instead of ending at a bare rectangular water edge. Rocky headlands and two breakwater arms frame the harbor entrance. Freight yards, a pump house, water utilities, service roads and wind-shaped pine stands establish the surrounding port. Weathered concrete, working-apron stains, subdued tire wear and mixed coastal ground replace the previous uniform treatment.

## Visual comparison

| Earlier current-runtime baseline | Revised surroundings |
| --- | --- |
| ![Before](../../../art/skirmish/environment/coastal-environment-before-overview.png) | ![After](../../../art/skirmish/environment/coastal-environment-overview.png) |

The revised view is 1440×900. Ten final captures were reviewed at normal clock, with 125% interface scale: ordinary home/shore fog, a hidden enemy base, harbor, inland yards, utility edge, rocky headland, the wider overview and both factions' actual combat.

- [Harbor entrance](../../../art/skirmish/environment/coastal-environment-harbor.png) and [headland](../../../art/skirmish/environment/coastal-environment-headland.png).
- [Freight/service yards](../../../art/skirmish/environment/coastal-environment-inland.png) and [utility edge](../../../art/skirmish/environment/coastal-environment-port-edge.png).
- [Home fog](../../../art/skirmish/environment/coastal-environment-home-fog.png), [shore fog](../../../art/skirmish/environment/coastal-environment-shore-fog.png) and [hidden enemy base](../../../art/skirmish/environment/coastal-environment-enemy-fog.png).
- [Bastion combat](../../../art/skirmish/environment/coastal-environment-combat-bastion.png) and [Helix combat](../../../art/skirmish/environment/coastal-environment-combat-helix.png), under ordinary fog beside the new pine stand.

## Editable kit and composition

The original Blender extension contains six assets: CoastalPineStand, CoastalHeadland, HarborBreakwater, PortPumpHouse, PortFreightYard and PortUtilities. It includes articulated-looking branches, exposed rock strata, wave armor, mooring fittings, pump motors, pipework, ladders, container corrugation and weathered freight colors. [The model guide](../../../art/environment/COASTAL_ENVIRONMENT.md) links the editable scene, build recipe and measured export manifest.

The scene uses 28 exterior landmark/grove placements. Every imported exterior vertex remains outside the 128×104 playable rectangle. Surrounding land has shaped coastal relief and flattened infrastructure foundations; it meets the playable land at matching height/normals. The cosmetic water plane now spans 220×196 m and uses the existing simulation clock. The northern entrance remains visually open between the breakwater arms. Rear service paving connects the storage/utility sites to the existing industrial road; it is a material treatment, without collision or new navigation.

The four existing interior pine blockers use the new wind-shaped tree model inside the same 3.6 m radius / 5.5 m height envelope. Additional service equipment fits inside existing crane/foundry footprints. New scenery adds no selectable units, resource stock, blockers or navigation input. The shoreline, field positions, two road corridors, 11 flight/sight landmarks, buildable ground and saved map identity retain their contracts.

Public exterior scenery uses the existing map-local fog treatment from Desert/Alpine. It does not reveal the playable interior. The rendered hidden-base check measures a black pixel at the unseen enemy HQ, and the simulation confirms that the HQ remains unobserved. Loading another map restores its own fog configuration.

## Verification

[Fourteen accepted checks and artifact hashes](coastal-environment-verification.json) cover nine headless suites, one rendered suite and four import/static checks. The Blender build also completes its measured radius/height assertions for all six models.

| Area | Observed result |
| --- | --- |
| Imported geometry | Actual Godot mesh vertices remain inside all existing interior radius/height envelopes or outside the battlefield. Exterior terrain has upward normals and matching land-edge height/normals. Decorative equipment remains inside existing blockers. |
| Ground routes | Both factions move 16 tanks along each of the quay and inland routes, restore their actual moving archive, finish advancing and retreat. Water still rejects ground construction; the land construction sample remains valid. |
| Route measurements | Both factions retain the 133.0 m ground crossing versus 96.0 m air shortcut. Basic-tank estimates remain 51.1 s base-to-base and 22.5 s to the western expansion. These are path estimates, not whole-match durations. |
| Aircraft | Actual drones and strike aircraft cross all 11 landmarks with their existing clearance. A raised aircraft retains altitude across its paused archive, then crosses the inlet. |
| Economy | Both starting fields and both expansions gather/deliver; paid construction and resource transit pass for Bastion and Helix. |
| Sight and fog | Existing landmark sight/fire obstruction remains; new models introduce no blockers. Hidden enemy observation and rendered interior fog remain private; exterior visibility does not leak into another map. |
| Persistence/pause | Moving unit positions, aircraft height, neutral poses and water clock survive restoration. Normal-clock combat damages targets for both factions; tactical pause freezes positions and sea animation. |
| Shared behavior | CoastalAIRegression, CombatRegression, ResourceNavigationRegression, MapStartupRegression, AmbientLifeRegression, EnvironmentAudioRegression, SaveRestoreCombat and DirectOrdersRegression pass alongside the dedicated CoastalEnvironmentRegression. |
| Static/import | Godot import, focused GDScript formatting/lint and whitespace checks pass. The rendered run compiles and exercises all three coastal shaders. |

## Iteration and limits

The first renders showed isolated scenery pads and overly patchy ground. The final composition connects breakwaters/service yards, softens turf contrast and adds stronger exterior relief. Before images preserve the actual pre-change scene; intermediate preview logs remain available. The first test file had a multiline-lambda parse error; [that diagnostic log](coastal-environment-regression-first.log) is excluded from acceptance. The next run completed all route/economy/geometry checks but faulted when a test cast another map's absent optional shader parameter to float and eventually timed out. [Its log](coastal-environment-regression.log) is retained. The corrected null-aware assertion passes in [final gameplay verification](coastal-environment-final-CoastalEnvironmentRegression.log).

The first combat preview inherited identical test-player material colors. The final fixture sets a distinct enemy color and refreshes its already cached material before spawning the combatants; this only corrects the test presentation. [The reviewed normal-clock log](coastal-environment-preview-reviewed.log) passes with both factions dealing 18 damage to the sampled target.

Known navigation-mesh readback and shutdown RID/ObjectDB/resource warnings remain in raw headless logs. Accepted runs contain no script/load errors. These checks establish this environment pass and retained mechanics, not final subjective art approval, broad balance, novice usability or physical-device/platform acceptance. No new complete-match pacing cohort or performance benchmark was run. Wider regional polish, the third faction and release gates remain open; performance optimization stays deferred.

## Reproduction

```sh
blender --background --python art/environment/build_coastal_environment.py
godot --headless --path . --editor --quit
godot --headless --path . --fixed-fps 60 --script tests/headless/CoastalEnvironmentRegression.gd
godot --path . --script tests/rendered/CoastalEnvironmentPreview.gd
```

The [shared runner](coastal-environment-verify.py.txt) records individual exits, markers and script/load diagnostics. Tests used Godot 4.6 on the development M1 Pro; assets were exported with Blender 5.2.1 LTS. Original map/ground/water source copies remain as `coastal-environment-before-*.txt` beside this report.
