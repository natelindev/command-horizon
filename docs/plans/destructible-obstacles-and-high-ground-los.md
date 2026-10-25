# Tactical Environment: Destructible Obstacles & True High-Ground Line-of-Sight

## Stage 1 — True High-Ground Line-of-Sight & Tactical Elevation
1. Enhance elevation rules in `source/match/maps/terrain/TerrainSight.gd`, `source/match/combat/Battlefield.gd`, and `source/match/combat/CombatRules.gd`:
   - **Asymmetric Fog & Vision**: Units on high ground (plateaus/hills) see down into low ground with +30% sight range. Low-ground units have strict cliff occlusion: they cannot see up onto high ground beyond 1.5 m without aerial recon or an observer already on the high ground.
   - **High-Ground Combat Advantage**: Firing downhill provides +25% attack range and +15% damage bonus. Firing uphill incurs a 20% range reduction.
   - Ensure `FogOfWar.gd` and `Battlefield.gd` are strictly synchronized with high-ground visibility.

## Stage 2 — Destructible Obstacles & Tactical Breaching
1. Implement destructible environmental obstacles (`source/match/environment/DestructibleObstacle.gd`):
   - Types: Concrete barriers, wooden barricades, rock piles, security fences.
   - Obstacles have HP and belong to group `destructible_obstacles`.
   - Take damage from weapon fire, frag grenades, and force-attack orders.
   - Heavy armor (`Tank`, `AdvancedTank`) can crush light barricades and fences on contact.
2. Battlefield integration:
   - When destroyed: plays debris destruction FX (`CombatEffects.gd`), clears collision/navmesh obstacle, and allows units to path through previously blocked choke points.

## Stage 3 — Frontier Salvage Mechanics
1. Frontier Combat Scavenge:
   - Frontier combat vehicles can scavenge wrecks to instantly heal 35% HP and gain a stackable "Scrap Hardened" buff (+15% damage and +10% movement speed per tier for 60s, capped at two tiers).
2. Frontier Worker Field Salvage:
   - Frontier workers can rapidly dismantle wrecks on-site, directly depositing materials into the player's stockpile.
3. Wreck yield increase for Frontier matches.

## Stage 4 — Regression Tests & Verification
1. Create `tests/headless/TacticalEnvironmentRegression.gd` and update existing Frontier salvage regressions.
2. Verify all existing tests pass without regressions.

## Agent progress

- Stages 1–3 implemented: 1.5 m high-ground contact visibility, shared spotting, directional +30% sight and fog, +25% downhill attack range/+15% damage, and a 20% uphill range penalty.
- Added destructible barriers with health, explicit attacks and grenade damage, contact crushing by heavy vehicles, debris effects, and navigation/sight removal. Authored barriers register after the initial ground bake so breaches cannot remain in the immutable navigation cache.
- Added 35% wreck material retention, Frontier vehicle scavenging (35% repair plus two tiers of 60-second Scrap Hardened), contextual/queued orders, and worker on-site dismantling. Buffs, orders, obstacle health, and breaches survive save/restore through optional validated records; snapshot version remains unchanged.
- Added TacticalEnvironmentRegression and updated sight and Frontier salvage fixtures for the new ranges, yield, and immediate field deposits. Requested CombatRegression, TerrainSightRegression, SaveRestoreRegression and the tactical regression pass, along with Frontier gameplay/edge/AI, abilities, shields, strategic polish and localization checks.
- Extended archive validation accepted all 811 saved schemas. Its 389 checksum failures are pre-existing: both archive files and SHA256SUMS manifests match HEAD. No archive files or manifests were changed. Existing ObjectDB/resource cleanup diagnostics remain at test shutdown.
- Final Godot 4.7.2 import and GDScript lint pass. ProjectileSystemRegression, ProjectilePhysicsRegression, DirectOrdersRegression and SaveSnapshotRegression also pass.
