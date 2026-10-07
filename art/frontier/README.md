# Free Frontier roster — first modeling pass

Third-faction art for the Free Frontier Coalition in `docs/GAME_DESIGN.md`, section 9. These are editable, independently authored subjects using the established Blender primitive and rigid-export workflow. The palette is worn olive, canvas, exposed steel and replaceable team-color panels. Wheeled chassis, cargo cages, field shelters and corrugated modules distinguish this roster from Bastion and Helix.

[Full catalogue](v1/faction-catalogue.png) · [Editable Blender scene](v1/frontier_faction.blend) · [Role mapping](roster.json)

Frontier is now selectable in skirmish with all seventeen subjects integrated. See [gameplay verification](../../docs/playtests/2026-10-04/FRONTIER_GAMEPLAY.md). This is the initial functional balance; the models and regression checks do not establish final visual or competitive acceptance.

| Shared role | Frontier subject | Visual function |
| --- | --- | --- |
| Worker | Scrapper rig | Six-wheel cab, crane grab and open cargo cage |
| Infantry | Ridge ranger | Field vest, bedroll, scarf and carbine |
| Tank | Outrider | Light six-wheel hull with salvaged cannon turret |
| RepairRobot | Patch crawler | Low service chassis, welder, gas bottle and tool drawers |
| CombatRobot | Jackal rig | Shielded autocannon and paired interception tubes |
| AdvancedTank | Ironback | Eight-wheel heavy hull, applique armor and long cannon |
| Drone | Lookout drone | Four exposed rotors, protective rings and camera gimbal |
| Helicopter | Kestrel gunship | Rebuilt rotorcraft, rocket pods and landing skids |
| CommandCenter | Convoy HQ | Linked command containers and outdoor supply canopy |
| Barracks | Ranger camp | Paired canvas field shelters |
| VehicleFactory | Motor pool | Open crane gantry, rails and container workshops |
| AircraftFactory | Rotor pad | Landing plate, fuel tanks and mast |
| PowerPlant | Diesel array | Paired engine housings, exhaust stacks and day tank |
| CommandLab | Relay workshop | Radio container and open-frame receiver dish |
| RepairDepot | Field workshop | Winch, articulated repair arm and gas bottles |
| AntiGroundTurret | Roadblock gun | Sandbag emplacement and shielded cannon |
| AntiAirTurret | Watchtower AA | Braced elevated platform and paired launch pods |

## Build and verification

Run from the repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python art/frontier/build_faction.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python art/frontier/verify_faction.py
```

The build produces seventeen GLBs in `assets/models/frontier/v1`, transparent 256px icons in `assets/ui/frontier`, individual 768px renders, the catalogue, editable `.blend`, and a geometry manifest. Source components retain editable geometry and modifiers. Export copies merge only objects with the same rigid parent, preserve articulation and team-color materials, triangulate and discard numerically degenerate faces.

The catalogue scene uses presentation transforms on each subject root. Reset the root's location, rotation and scale to edit at native metre scale. Exported GLBs already use upright game coordinates; Blender +Y maps to Godot -Z. `TurretPivot`, `BarrelPivot`, `Muzzle`, leg/tool pivots and numbered rotors follow current runtime discovery conventions. Wheel pivots use `WheelPivot` names to avoid Godot’s vehicle-physics import suffix. All five wheeled roles now roll their wheels from signed chassis travel and pivot turns. Body gestures and blocked orders do not drive them; tactical pause freezes them. Wheel phase is cosmetic and initializes anew on save restoration. See [wheel motion verification](../../docs/playtests/2026-10-07/FRONTIER_WHEELS.md).

After Godot editor import, run `tests/headless/FrontierAssetRegression.gd` for all seventeen real imports, gameplay normalization, grounded bounds, muzzle direction, rotor articulation and icons. Run `tests/rendered/FrontierAssetPreview.gd` with native rendering for the two [unit](v1/godot-units.png) / [building](v1/godot-buildings.png) contact views at 1280×720. These previews use existing role radii and the current faction-model normalization formula; they are art review scenes, not combat tests.

## Implemented gameplay

The faction uses the shared construction, paid production and program authority rules. Mobile units have 85% base health; infantry/scouts move 20% faster and other mobile units 10% faster. The Lookout has two additional metres of sight. The Ironback uses an 8 m heavy cannon with no preparation charge, 18 base damage and a 2.2 s reload. The Jackal combines an autocannon with 4.5 m anti-air on one reload.

- Conventional vehicle chips cost 2 E and take 3 s, including factory fitting. Cancellation refunds the amount paid.
- Ground machine deaths leave finite material wrecks whenever a Frontier side participates: `floor(original material cost × 20%)`, 180 s lifetime, at most 128 live wrecks. Frontier engineers must observe, collect and return the cargo to HQ. Infantry, air units and structures leave no recoverable resource. No funds are awarded merely for a kill.
- Coordination unlocks Maneuver Burst for up to six ready chipped ground combatants: +35% movement speed for 6 s, 25 s cooldown. Rapid redeployment doctrine increases the bonus to +50%. Existing orders continue.
- Version-8 saves retain wreck material/lifetime, partial cargo, retrofit payments, movement windows and cohort cooldowns. Older supported archives keep their original two-faction semantics. Old numeric Random preferences migrate to the stable `random` ID.

The skirmish AI fits new conventional armor after the lab unlock, uses Maneuver during observed-contact movement and collects preferred reachable home wrecks after delivering existing cargo. See [AI verification](../../docs/playtests/2026-10-05/FRONTIER_AI.md).

Working names and numerical balance remain provisional. Repeated full matches, equal-budget faction encounters, novice feedback and release/performance acceptance remain open. No campaign faction changes or naval scope are implied.
