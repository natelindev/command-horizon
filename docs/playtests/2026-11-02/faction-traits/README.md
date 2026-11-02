# Faction operational traits — 2026-11-02

This is the first implementation slice of [the strategic asymmetry roadmap](../../../plans/strategic-asymmetry-and-rts-benchmarks.md), after reading all four linked design specifications. Stage 1 remains in progress; this report does not claim the new rosters, economy, formations or campaign presentation are complete.

## Implemented behavior

- **Helix construction:** an engineer reaches a paid foundation, deploys its nanite beacon and resumes harvesting or queued orders. Assembly proceeds at the existing authored build rate without further workers. Pause, damage, destruction, refunds and save restoration preserve construction progress. Builder dispatch skips active beacons. Bastion and Frontier retain tethered builders.
- **Shields:** `ShieldComponent.gd` owns absorption, hull overflow, EMP drain, five-second damage delay, 8 HP/s recharge and break/recharge events. The existing Helix support multiplier still applies. Cyan world shield tracks update on shield-only damage and follow the health-bar visibility options; neutral objects and ambient actors retain ordinary health bars. Existing shield capacities and research prerequisites are retained until roster and technology rebalancing.
- **Frontier salvage:** `BattlefieldSalvage.gd` owns vehicle scavenging, permanent armor and temporary scrap buffs. Worker wreck orders process materials on site. Scrap Cannibalization grants exactly 50% extra wreck materials and repairs friendly ground vehicles within 8 m by 25 HP; infantry, aircraft and structures receive no repair.
- **Mobile infantry mounts:** the existing Frontier Ironback gets four mounts as the foundation for the future Battle Rig. Infantry embark by right-clicking the vehicle, disappear while inside, and keep firing their weapons from its mounts while it moves. They become visible again when they unload or escape the carrier. Move orders unload passengers; the carrier also has an accessible, localized Unload infantry control. Blocked exits retry safely and retain orders across saves. Carrier death or removal releases passengers; wrecking inflicts 35% passenger hull damage. Exit placement checks navigation and occupancy.
- **Persistence:** current snapshot version 21 is retained. Shield/salvage fields remain unchanged, nanite activation derives from existing construction progress, and mobile mounts add optional validated occupant/slot/evacuation state. Existing archived snapshots remain valid.

## Verification

Godot 4.7.2 on macOS. Headless gameplay checks use `--headless --path . --fixed-fps 60 --script tests/headless/<suite>.gd`.

Passing checks:

| Area | Suites |
| --- | --- |
| Shields and combat | ShieldComponentRegression, PlasmaShieldsRegression, HelixSupportRegression, CombatRegression, CommanderCallInsRegression, UnitAbilitiesRegression |
| Construction and labor | AutonomousAssemblyRegression, ConstructionResumeRegression, ConstructionStyleRegression, ConstructionContractRegression, SkirmishLaborRegression |
| Salvage | BattlefieldSalvageRegression, TacticalEnvironmentRegression, FrontierSalvageEdges |
| Garrisons and persistence | MobileGarrisonRegression, GarrisonCombatExitRegression (three maps), PersistentCaptureRegression, GameplayDepthSaveRegression |
| Presentation and catalogs | CombatPresentationRegression, VehicleDamageVisualsRegression, LocalizationRegression, VisibilityRefreshRegression |
| Archives and native state | ArchivedSnapshotRegression: 811 fixtures, 389 recorded checksums; NativeUnitStateRegression: 26,772 comparisons |

Mobile-garrison checks also pass with the native kernels enabled. They cover stabilized rocket fire during actual carrier movement, ownership/capacity rules, snapshot corruption rejection, blocked unload restoration, queued movement, carrier death and direct removal.

The construction contract fixture had a stale assertion before these changes: it expected the refund quote on the button, although the existing UI displays the quote in its tooltip. The test now checks that existing translated tooltip contract. The blocked-unload fixture waits for deferred navigation rebuilding after removing its surrounding structures, then retains its original destination assertion. Some existing direct-quit suites emit ObjectDB/resource shutdown warnings; new component/assembly checks and the revised plasma-shield teardown exit cleanly.

## Rendered review

Ran `tests/rendered/HudConsolePreview.gd -- --console-only --research` without headless mode for every faction, in English and Simplified Chinese. Shield tracks and bottom-console shield gauges render correctly. Captures are generated under `art/hud-console/`.

The full matrix retains four existing failures: Bastion/Frontier active research at 720p/150% in both languages grows the console 8 px above the minimap (`deck y=466, height=254`, minimap `y=474, height=246`). An isolated checkout of the original HEAD reproduces exactly the same four failures. Research controls remain visible. This layout issue is still open; these changes do not close it.

The focused `tests/rendered/FactionTraitsPreview.gd` review passes with zero failures. Six actual 1280×720 captures at 150% UI scale under `art/faction-traits/` cover Helix autonomous assembly/shields, occupied Frontier vehicles with hidden passengers, and occupancy/unload tooltips in both languages. The review verifies visible infantry after unloading, literal Chinese labels, tooltip accessibility descriptions, no floating operation windows and HUD bounds. Mounted models, health bars and badges remain hidden through visibility refreshes and save/load while weapons and carrier-based vision continue operating.

## Remaining implementation

- Dedicated Siege Colossus, Prism Skimmer and Battle Rig scenes/weapons; role-specific hull/shield balance and exclusionary doctrines.
- Player-controlled wreck-to-buggy conversion and its safe spawn rules; passenger roster/fire-status cards.
- Asymmetric harvesters, forward drop-offs, active brownouts and the remaining economic objectives/abilities.
- Formation geometry, Hungarian assignment, cohesion, smart casting and the remaining movement work.
- Voice banks, music/presentation extensions, motion comics and interactive campaign hubs.
- Broader balance, performance, participant and platform acceptance. These tests verify mechanics and presentation contracts, not faction win rates.

The prior harvest-field hint is transient during an engineer's approach. Loading before beacon deployment returns the engineer to the nearest reachable valid deposit (or an HQ cargo-return fallback), rather than restoring that exact transient hint.
