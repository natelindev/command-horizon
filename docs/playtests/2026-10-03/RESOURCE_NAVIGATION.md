# Resource navigation and map startup — 2026-10-03

Engineers now route around resource gaps that are too narrow for their actual movement radius, gather and deliver from the reachable navigation boundary, and resume cargo return from a previously trapped saved position. Starting a new battle also uses its own ground navigation map, preventing the previous battlefield from moving new deposits during startup.

## Changes and reproduced failures

1. **Resource clearance:** resource piles used a 0.2 m navigation footprint and a 0.6 m avoidance radius. A Bastion engineer ordered across two piles 2.5 m apart stopped at `(31.25002, 0, 24.99291)` instead of reaching `(31.25, 0, 30)`. Both resource types now use the same generated circular footprint as other static movement obstacles. Their visual size, avoidance radius, amounts and authored positions are unchanged. Deposits remain transparent to sight/fire.
2. **Reachable contact:** the larger footprint revealed workers waiting a few centimetres outside the old interaction range. The terrain mesh reserves space for the largest 0.9 m unit and rounds geometry to 0.3 m cells. Gathering, HQ delivery and construction now allow contact from this boundary. For a 0.65 m engineer, the border margin becomes 0.55 m: 1.8 m from a standard pile's center and 3.4 m from an HQ's center. Moving-unit contact retains the existing margin. Tests also reject gathering and delivery beyond these bounded distances.
3. **Map lifetime:** ground navigation previously reused the viewport's navigation map. During a scene transition, a nonzero server iteration could still describe the previous battlefield. The field audit caught Great Expanse deposits clamped to Open Plains' `49.2` m boundary. Replaying immediate small→large→small→large transitions with the previous shared-map behavior displaced 48 authored deposit positions. Each match now creates, activates and frees its own ground navigation map, as air navigation already does. The same transition test preserves every deposit position and reaches the new map's open ground.

The first focused movement fix passed isolated harvesting, but the broader field audit exposed the contact-range and startup issues above. Those were fixed before acceptance. An early startup probe also queried ground occupied by an HQ; the final probe uses verified open ground and checks every authored deposit separately.

## Final verification

| Test | Evidence |
| --- | --- |
| `ResourceNavigationRegression.gd` | Both factions' engineers and tanks traverse 2.0, 2.5, 3.0 and 3.5 m deposit spacing in both directions. Units retain physical clearance; the 3.5 m passage stays usable. Materials/electronics harvest and return from four approach directions pass. |
| Interaction bounds | Actual gathering works at 1.75 m and grants nothing at 1.85 m. Actual HQ delivery works at 3.35 m and retains cargo at 3.45 m. Salvage does not block sight. |
| Saved trapped position | Exact position and four electronics survive a paused disk round trip; resuming delivers exactly four. Depleting the piles removes their navigation footprints and restores a direct route. |
| `ResourceMapEconomyRegression.gd` | All **68 paired material/electronics field-return checks** pass across 11 maps. See the matrix below. |
| `MapStartupRegression.gd` | Immediate Open Plains / Great Expanse transitions preserve authored deposits and use the correct navigation extent. |
| `NavigationRegression.gd` | Actual obstacle routing, twelve-tank crowd movement, six-worker gathering, factory egress, dynamic construction/removal and rock clearance pass. |
| `ResourceFieldRegression.gd` | Both-faction work reservations, waiting, depletion, partial return, HQ recovery, queued-order handoff, archives and version-4 migration pass. |
| `SaveRestoreCombat.gd`, `SaveSlotsRegression.gd` | Jobs, actions, programs, cargo, cooldowns, live firing, pause, manual/quicksave, failed-load recovery and rotating mission checkpoints pass with separate navigation lifetimes. |
| `IndustrialRegression.gd` | Both-faction three-street advance/retreat, construction, resource return, infantry capture, aircraft and archives pass. Updated basic-tank path estimates are 45.1 s base-to-base and 20.5 s to the first expansion. |
| Native Godot | A selected engineer crosses the original 2.5 m cluster three times, collects electronics, and returns a full cargo under normal fog. Both rendered assertions pass; 720p captures and the live native window were reviewed. |

| Map | Fields per run | Runs |
| --- | ---: | --- |
| Original Bastion Desert | 4 | Bastion and Helix |
| Desert Frontier | 4 | Bastion and Helix |
| Alpine Relay | 4 | Bastion and Helix |
| Industrial Crossroads | 4 | Bastion and Helix |
| Open Plains | 4 | Bastion and Helix |
| Great Expanse | 8 | Bastion and Helix |
| First Orders | 3 | Campaign Bastion |
| Split Signal | 3 | Campaign Bastion |
| Air Corridor | 2 | Campaign Bastion |
| Broken Foundry | 2 | Campaign Bastion |
| Command Horizon | 2 | Campaign Bastion |

The field audit retains authored HQ/building positions and stationary armies, disables combat/AI/mission responses, and sends two real workers from the closest eligible HQ to each field. Each check requires at least four materials and four electronics credited to that HQ's player within 120 simulated seconds. Campaign fields use the friendly HQ. It tests navigation/economy access, not safe expansion under enemy fire or full-match balance. Supply Line has no harvesting economy and is outside this matrix.

All final listed suites finish successfully with no script errors or failed assertions. Formatting, lint, editor import and whitespace checks pass. Existing navigation-readback and shutdown renderer/ObjectDB/resource warnings remain. The full design, broader environment work, Coastal Foundry, faction/balance and release acceptance remain open; performance optimization stays deferred.

## Evidence and reproduction

- [Engineer clearing the narrow cluster](../../../art/skirmish/resource-clearance-route.png)
- [Gathering from the reachable boundary](../../../art/skirmish/resource-clearance-harvest.png)

From the repository root with Godot 4.6:

```sh
godot --headless --fixed-fps 60 --path . --script tests/headless/ResourceNavigationRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/ResourceMapEconomyRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/MapStartupRegression.gd
godot --path . --script tests/rendered/ResourceNavigationPreview.gd
```

The rendered fixture stages the original narrow cluster in the legacy desert, isolates its worker, and restores window preferences after normal completion. It does not modify persistent campaign progress or skirmish settings. Navigation maps are runtime objects and remain excluded from snapshots; no archive-schema change is needed.
