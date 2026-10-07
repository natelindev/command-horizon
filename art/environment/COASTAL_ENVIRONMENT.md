# Coastal Foundry environment extension

Six original models provide a weathered working-port setting. [CoastalEnvironmentKit.blend](CoastalEnvironmentKit.blend) retains separate named meshes and materials. [build_coastal_environment.py](build_coastal_environment.py) is the seeded procedural modeling/export recipe; [coastal-environment-manifest.json](coastal-environment-manifest.json) records measured mesh bounds.

| Asset | Radius / height (m) | Intended use |
| --- | --- | --- |
| CoastalPineStand | 3.218 / 4.832 | Wind-shaped trees and ground stones; fits the existing interior pine envelope. |
| CoastalHeadland | 8.877 / 7.100 | Layered rocky coast outside the battlefield. |
| HarborBreakwater | 7.845 / 2.474 | Sea-wall sections, wave armor, rails and mooring fittings. |
| PortPumpHouse | 6.210 / 5.410 | Maintenance house, roller door, pumps and outflow pipes. |
| PortFreightYard | 8.240 / 4.445 | Corrugated freight stacks and timber on a marked apron. |
| PortUtilities | 7.646 / 5.225 | Water tanks, ladders, manifold and control cabinet. |

GLB exports live in [the coastal asset directory](../../assets/models/environment/coastal). Coordinates are Blender Z-up, exported through glTF into Godot. Radius and height assertions run before export. This is an editable modeling recipe; byte-identical GLB serialization is not an acceptance claim.

The map weathering shaders add salt/concrete variation without changing geometry. Exterior scenery has no collision, target identity or navigation input. Interior tree geometry retains the previous 3.6 m / 5.5 m clearance contract. [Gameplay/render verification](../../docs/playtests/2026-10-04/COASTAL_ENVIRONMENT.md) covers actual imported bounds, scene composition and routes.
