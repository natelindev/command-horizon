# Air combat redesign: real aircraft, real anti-air, physical projectiles

## Context

**How it works today:**
- Aircraft are two shared roles: `Drone`, an unarmed scout, and `Helicopter`, a hover striker.
- Both slide across a flat air navmesh at about 1.5 m, stop dead in mid-air, and pop vertically out of a circular airfield.
- Anti-air is only static batteries and the walker's 6.5 m secondary gun.
- Rocket infantry and every tank are ground-only.
- Shots are invisible timers (`units/projectiles/Rocket.gd`, `CannonShell.gd`) that apply damage on expiry and never miss. The visible tracer is a straight lerp that homes in on the target.

**What the user asked for:**
1. Four aircraft with distinct purposes: drone, fighter, bomber and helicopter.
2. Every faction's rocket (anti-armor) infantry also hits aircraft, plus a tank-class mobile AA vehicle per faction.
3. Visible projectiles that follow physics.
4. A long runway airfield where fixed-wing aircraft taxi, take off, climb, bank-turn, glide in, land and roll out.

**Confirmed decisions (2026-10-20):**
- Jets carry limited munitions and land to rearm. There is no fuel.
- Projectiles can really miss.
- One airfield builds everything: runway for jets, helipad apron for helicopters and drones.
- The drone is a kamikaze loitering munition.

**Coordination.** The parallel `map-rebuild` session (branch `map-rebuild`) is adding these in its Stage 1:
- optional polygon structure footprints (PackedVector2Array, local XZ) on `MovementObstacle` plus placement checks;
- a stable ground API: `Map.height_at(xz)`, `ground_point(xz)`, `flight_height_at(point, baseline)`.

It will touch `Battlefield.gd` sight rules later. We build on its footprint and ground API rather than parallel ones. Our `Battlefield.gd` edits stay additive. They will notify us when their Stage 1 is committed.

Implementation runs on a new branch `air-combat-redesign`. This plan is copied to `docs/plans/2026-10-20-air-combat-redesign.md` with an "Agent progress" section.

## Design

### Roster

Role ids are shared across factions. Names and models differ per faction.

| Role | Purpose | Weapon (domain) | Countered by |
|---|---|---|---|
| `Drone` (kamikaze) | Cheap expendable precision strike on armor and turrets. Hovers and scouts indefinitely while loitering. | Guided terminal dive: one heavy hit plus small splash, then destroyed. Ground only. | Any AA, rocket infantry, fighters |
| `Fighter` (new) | Air superiority, escort, interception. Fast, with a wide turn radius. | 4 guided air-to-air missiles plus an unguided cannon. Air only. | AA vehicles, massed AA |
| `Bomber` (new) | Heavy strike on structures and clumps using level passes. | Gravity bomb stick with large splash, one load per sortie. Ground only. | Fighters, AA vehicles |
| `Helicopter` | Sustained anti-armor gunship. Hovers and holds position at low altitude. | Rockets plus gun, limited ammo, rearms on a helipad. Ground only. | Rocket infantry, AA vehicles |
| `AntiAirVehicle` (new, vehicle factory) | Mobile air denial that travels with the army. | Air only. Bastion: radar flak with proximity airburst. Helix: guided interceptors. Frontier: truck-mounted autocannon. | Tanks, infantry |
| `RocketInfantry` | Anti-armor plus shoulder-launched AA. | Existing rocket vs ground; guided SAM vs air with 0.8 s lock-on, lower damage and a shared reload. | Rifle and assault infantry |

**Kept as is:**
- Static AA batteries, which now fire physical guided missiles.
- The walker's secondary AA.
- No AA is added to other tanks or rifles.

**Drone behavior.** Drones default to **Hold Fire** and dive only on an explicit attack order, or when the player sets a stance. This keeps scout presets (`ProgramLibrary.gd:22`) and campaign drones (CommandHorizon, BrokenFoundry, SplitSignal) from suiciding.

**Helicopters without a home pad**, such as campaign patrols (`AirCorridor.gd:61,223`), get unlimited ammo.

**Helix aircraft art.** The Helix `Helicopter` becomes a real tilt-rotor. The swept-wing Wraith design moves to the Helix fighter and bomber.

**Production and costs:**
- `BastionCatalog.PRODUCES`: `AircraftFactory: [Drone, Helicopter, Fighter, Bomber]`; `VehicleFactory += AntiAirVehicle`.
- Fighter and bomber require a CommandLab.
- Cost tables to update: `FactionRules`, `FrontierCatalog.COSTS`, `FactionCatalog` times and requirements, and `MatchConstants`.
- Combat tables to update: `CombatRules` profiles and armor rows, and `TechnologyCatalog` damage lists.
- These values are tuning seeds; Stage 8 matchups set the final values.

### Stage 0 groundwork (no behavior change)

- **Role registry.** `UnitRoles` provides `is_aircraft`, `is_fixed_wing` and `is_rotor`. It replaces about 25 hard-coded `["Drone","Helicopter"]` lists, for example:
  - `RepairService.gd:31`, `CombatRules.gd:32,52`, `ProductionDeparture.gd:32`
  - `SnapshotSchema.gd:17`, `ProgramLibrary.gd:210`, `CombatAudio.gd:80`
- **Combat domain.** `Unit.combat_domain()` initially returns `movement_domain`. `CombatRules.can_target/damage/range_for` (`:59-118`) switch to it. Navigation, AI and HUD keep using `movement_domain`.
- **Action hook.** Add a hook in `Unit._set_action` (`Unit.gd:180`) that lets a unit subclass translate generic actions. Every one of the roughly 38 `issue_manual_order` callers, plus `AlliedDefense`, ends there.
- **ManualOrders fix.** In `ManualOrders._physics_process` (`:112-120`), set `_active = unit.action` after assignment so a translated action doesn't complete the order instantly.
- **Engine probes.** Two headless probes for Godot 4.6:
  - a rotated `NavigationObstacle3D` polygon is respected by both the bake and avoidance;
  - MultiMesh native physics interpolation works.

### Physical projectiles: `source/match/combat/ProjectileSystem.gd`

**Simulation core:**
- One pausable node under `Match`, stepped in `_physics_process` at 30 Hz. All rounds are plain data processed in fire order. No node is allocated per shot.
- A round stores: kind, position, velocity, age, a weak target ref plus id, guidance parameters, fuse radius, and a frozen shot descriptor (player, type, faction, profile, damage, research factor, splash).
- `CombatRules` is split into `can_target` (needs a live source) and `damage_from(descriptor, target)`, so rounds survive their shooter's death. This is a deliberate, documented balance change.
- Hit handling must accept a descriptor:
  - `Unit.receive_damage` (`:106`);
  - `AlliedDefense._on_hit`, which retaliates only when `attacker is Node3D`;
  - `BattleRecord`.

**Round kinds:**
- `bullet` and `shell`: gravity, with a low-angle ballistic solution.
- `rocket`: boost plus gravity.
- `missile`: proportional navigation with a maximum turn rate, a burn time, then coasting and a proximity fuse.
- `bomb`: inherits aircraft velocity, gravity plus drag.
- `drone_dive`: the drone itself is the warhead.
- `wreck`: non-damaging crash trajectory with forward momentum.
- `rail`: kept as a hypervelocity zero-flight segment test with the existing instant beam.

**Aiming and dispersion:**
- Shooters compute a lead intercept.
- Dispersion is deterministic: a stateless hash of `(match_seed, shooter id, per-unit shot serial)`. Only the serial is saved.

**Collision:**
- Sweep each tick's segment in the target-relative frame so fast jets can't tunnel through it.
- Each round always tests its intended target. Bullets test the body-grid cells along the segment; guided rounds test only their fuse.
- Ground: `y <= Map.height_at(xz)`.
- Structures and cliffs: the existing `line_clear` / `segment_hits_cylinder`.
- Splash is evaluated only at detonation, with linear falloff, enemies only. There is no friendly fire.

**Fire path and HUD hooks:**
- `AttackingWhileInRange._hit_target` (`:170-194`) calls `projectile_system.fire(...)`. Recoil, muzzle flash and `CombatAudio` are kept.
- `Battlefield._incoming_damage` (`:254`) reads the system's per-target pending-damage map.

**Rendering:**
- One `MultiMeshInstance3D` per visual kind, using native MultiMesh physics interpolation with slots reset on reuse and a map-sized `custom_aabb`.
- Missiles leave trails using the pooled `_puff("smoke")` effect.
- Misses and impacts produce dust and spark effects.
- Nothing is rendered when headless.

**Fog.** A new `Battlefield.is_point_observed(player, p)` on the observer grid gates round visibility. It is rechecked every few ticks.

**Saves:**
- Rounds go into the snapshot, validated in `SnapshotSchema`.
- Legacy `CannonShell`/`Rocket` entries (`MatchSnapshot.gd:415`) convert into exact-lead rounds that resolve on the original timing.
- Tests get a small API (`debug_rounds()`, `step_round()`) to replace `_flight_left` probing in:
  - `CombatRegression:294,314`, `SaveSnapshotRegression:77`, `SaveRestoreRegression:82`, `IncomingDamageRegression:20`.

### Runway airfield on rotated polygon footprints

**Footprint support** (built on `map-rebuild`'s polygon footprint):
- `Unit.radius` becomes the inscribed size, so readers that still assume a circle never over-reach.
- **Range checks:** `Battlefield.can_fire` / `CombatRules.range_for` use `max(0, distance_to_polygon) + inscribed`.
  - `fireable_targets` pads candidate gathering by a separate `_max_structure_extent`.
  - `_max_unit_radius` (`Battlefield.gd:70`) counts only mobile units, so a 10 m structure doesn't push every `nearby_bodies` query onto the coarse path.
- **Other polygon-aware readers:**
  - placement (`UnitPlacementUtils.gd:66-94`, `StructurePlacementHandler.gd:132`);
  - `MovingToUnit` / `UnitMovementUtils` approach;
  - the `WaitingForTargets` hold filter (`:40`);
  - Selection, Highlight and Targetability outlines;
  - box collision with an enlarged pick area.
- **Excluded from the polygon:**
  - `FactionCatalog` model scaling (`:398`): rectangular structures skip the radius-based rescale.
  - `BaseApron` (`:24`): size is capped.
  - The flat runway opts out of sight blocking.
- **AI site search** tries the orientations 0°, 45°, 90° and 135°.

**Airfield layout.** `AircraftFactory` becomes about 6 × 20 m with a runway, a parallel taxiway, **4 jet stands** and **2 helipads**. Named marker nodes come from the Blender model.

**Stands and service:**
- A queued jet **reserves a stand** at queue time. With no free stand, production is held with the reason "No free stand", shown next to the existing exit-blocked reason (`ProductionQueue.gd:121-135`).
- Population still counts against the shared limit.
- Service is per stand or pad (rearm plus the existing 4%/s repair) and replaces the 5 m centre check in `RepairService` (`:7,107,158`).
- When an airfield dies, its jets are reassigned to another airfield with free stands. Otherwise they hold their station without rearming.

**Pre-placed airfields** are re-sited with the runway orientation verified:
- `BastionDemo.gd:74`;
- `AirCorridor.gd:82`, moving the nearby helicopters and drone;
- `CommandHorizon.gd:62,127`;
- `tests/fixtures/contact-approach.json`;
- about 51 test files, through a `place_airfield(player, center)` test helper.

**Legacy saves.** An old airfield restores as a runway at the same center. It picks the orientation with the fewest overlaps, then relocates overlapping mobile units with `find_valid_position_radially`.

### Fixed-wing flight

**Unit and movement nodes:**
- `FixedWingAircraft.gd` extends `Unit`.
- `FixedWingFlight.gd` extends `Movement`. It keeps the node name `Movement`, sets `avoidance_enabled = false`, bypasses navmesh and RVO, and implements `cancel_exit_clearance()`.

**Point-mass flight model:**
- Airspeed is kept between stall and max speed, using a throttle and drag.
- Turns are coordinated bank turns, with ω = g·tanφ/v and a limited roll rate.
- Climb and sink are limited.
- Terrain clearance comes from `flight_height_at` at a jet cruise baseline.

**Flight phases:** PARKED → TAXI_OUT → TAKEOFF_ROLL → CLIMB → MISSION → RETURN → APPROACH → FLARE → ROLLOUT → TAXI_IN → PARKED/REARM.
- MISSION covers cruise, orbit and attack runs.
- APPROACH flies pattern entry, a base turn, and a final on the glide slope with idle throttle.

**Action translation via `_set_action`:**

| Generic action | Fixed-wing action |
|---|---|
| Moving | AirStation: combat air patrol, a banked orbit that engages per stance |
| AttackMoving | AirStation with a sweep |
| AutoAttacking / AttackingWhileInRange | AirStrike |
| WaitingForTargets | AirIdle |
| RecoveringAtService | AirReturn |
| Ground-only actions | Rejected |

**Sortie rules:**
- When munitions run out, the jet returns, rearms and resumes its station.
- An attack order is a strike followed by a return.
- A new **Return to airfield** command is added.

**Weapons:**
- `AircraftWeapons` fires fighter missiles and cannon inside a nose cone using lead pursuit.
- Bombers fly a straight pass and release at the computed ballistic drop point.

**Combat domain.** `combat_domain()` is TERRAIN while parked or taxiing, so ground weapons and bombs can destroy jets on the airfield, and AIR once airborne.

**Visuals and feedback:**
- `ChassisMotion` uses the real bank and pitch.
- `AirToTerrainMarker` is hidden while parked.
- Death launches a `wreck` round.
- Jets get audio for engines, flak and missiles.
- The minimap gets fast-mover markers.

**Saves.** One flight-state blob covers phase, kinematics, stand, munitions, station and approach waypoints. Three new action kinds are registered in `MatchSnapshot.ACTION_FIELDS`, `SnapshotSchema` and `ActionRestore`.

### Rotorcraft and drones

These stay on hover `Movement` with acceleration and deceleration limits. Tilt and bank follow the actual acceleration.

- **Helicopters** lift off vertically from a helipad, land there to rearm, and carry limited ammo.
- **Drones** launch from a pad and hover or loiter. On attack they become a `drone_dive` round.
- **`ProductionDeparture`** keeps its vertical exit only for rotorcraft and drones. Jets spawn on their stand and taxi out.

### AI, advice and programs

- **Composition** (`SkirmishComposition` / `SkirmishProduction`). Build triggers:
  - fighters when enemy air is observed;
  - bombers vs observed structures and defenses;
  - helicopters vs armor;
  - drones vs high-value armor and turrets;
  - AA vehicles plus rocket infantry vs observed air.
- Quotas, reserves, prerequisites and observed-only rules are kept.
- **`SkirmishTactics._air_defense`** recommends rocket infantry, AA vehicles and fighters.
- **Role lists to update:** `ProgramLibrary`, `LuaProgramEditor`, `llm/RequestContext`, `ArenaScenarios`, `ProgramRecord`.
- **The legacy clairvoyant AI** keeps its helicopter-only air force.

### Art, HUD and localization

**Blender builders.** Extend `art/{bastion,helix,frontier}/build_faction.py` and `art/bastion/build_structures.py` with these models, which need rotor, gear, flap and turret pivots:
- fighter;
- bomber;
- a rebuilt rotorcraft helicopter for Bastion and Helix;
- the kamikaze drone refit;
- the AA vehicle;
- the runway airfield, with stand and pad markers.

**Checks and assets:**
- Verify the models with `verify_faction.py` / `verify_structures.py`.
- Add portraits and icons through the existing render path.
- Add English and Chinese names and descriptions in the catalogs and `assets/translations/ui.csv`.
- The HUD kit PNGs stay untouched.

## Stages

0. Groundwork: role registry, `combat_domain`, the action hook, the `ManualOrders` fix, and engine probes.
1. Projectiles at parity: system, descriptor damage, pending-damage map, saves, legacy conversion and test API, with today's flight times and guaranteed hits. The existing combat suite must pass unchanged.
2. Real ballistics: kinds, dispersion, ground and structure blocking, splash, misses and rendering. Rocket-infantry AA lands here too. Re-baseline combat expectations deliberately and record the changes.
3. Runway airfield: footprint integration on top of `map-rebuild` Stage 1, the layout, stands and pads, gating, service, re-sited pre-placed airfields, and legacy restore. Existing hover aircraft use the helipads first.
4. Fixed-wing flight and actions, then fighter and bomber roles.
5. Rotorcraft inertia, helicopter ammo and rearm, kamikaze drone.
6. AA vehicle for each faction.
7. Art, icons, localization, audio and minimap.
8. AI composition, advice, programs, and balance through scripted role matchups.
9. Acceptance: rendered reviews, performance, and docs (`GAME_DESIGN`, `CORE_GAMEPLAY_SPEC`, `README`, `CHANGELOG` including the shooter-death and miss changes, plus a playtest report).

## Verification

Headless command:

```
/Users/linlilu/godot-open-rts/tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/X.gd
```

**New regressions:**
- **`ProjectilePhysicsRegression`:**
  - gravity arcs;
  - lead hits on a linear target and misses on a jinking target;
  - ground and structure blocking, and splash falloff;
  - a guided round losing its target through turn limits;
  - the shooter dying mid-flight;
  - pause freezes rounds;
  - save and restore mid-flight;
  - legacy conversion;
  - deterministic replay.
- **`FixedWingFlightRegression`:**
  - the take-off roll stays on the runway;
  - measured turn radius within bounds, bank ≤ max, glide slope held;
  - touchdown on the runway, then taxi to the stand;
  - rearm timing;
  - stand reservation and production hold;
  - reassignment after the airfield is lost;
  - save and restore in every phase;
  - orders from `ManualOrders`, AI and `AlliedDefense` all translate.
- **`AntiAirRosterRegression`:**
  - each faction's rocket infantry and AA vehicle engage air;
  - fighters are air-only, bombers and helicopters ground-only;
  - parked jets count as ground targets;
  - drones hold fire by default.
- **`RunwayPlacementRegression`:** rotation, overlap, navigation hole, range to the runway ends, AI site search, every pre-placed layout, and legacy save restore.
- **`AirRoleMatchups`:** cost-equal scripted fights confirm each role beats its intended target and loses to its counter.

**Updated suites:**
- air: `AirArrival`, `QuarryFlight`, `QuarryLegacyRecovery`, `AirCorridor`, `AirHolding`;
- combat and saves: `Combat`, `SaveRestoreCombat`, `IncomingDamage`, `WeaponMode`;
- AI: `SkirmishComposition` / `Budget`, `AirDefenseAdvice`;
- campaign missions;
- the `tools/release/build.py` smoke list gains the new air tests.

**Performance.** Run `tests/rendered/ScaleFrameBenchmark.gd -- --behaviors --realtime --no-capture` before and after, with aircraft and AA in the mix. The target is p95 ≤ 33.3 ms; record results in `docs/performance`.

**Rendered review** (not headless):
- a new `tests/rendered/AirOpsPreview.gd` capturing, per faction:
  - taxi and take-off roll, climb and banked turn;
  - a bombing run, a missile intercept and flak bursts;
  - landing flare and a crash;
- `HudConsolePreview.gd` for the new production buttons;
- a full AI skirmish per faction.

**Lint.** `gdformat --check` and `gdlint` on `source/`.

## Agent progress

- 2026-10-20: Surveyed air, combat, footprint, order and AI code. User confirmed
  ammo + rearm, real misses, single airfield and kamikaze drone. Coordinated with
  the `map-rebuild` session (polygon footprints, `Map.height_at`). Plan approved.
- **Stage 0 complete:** aircraft role registry (`BastionCatalog.AIRCRAFT_ROLES`),
  `Unit.combat_domain()`, `Unit._adapt_action` hook, ManualOrders tracks the
  adapted action. Engine probe: rotated obstacle polygons bake in world space;
  MultiMesh physics interpolation API present in 4.6.
- **Stage 1 complete:** `ProjectileSystem` owns all rounds as data; `Shot`
  descriptor keeps damage after shooter death; `CombatRules.damage_from`;
  snapshot v15 stores `rounds` centrally; v<15 per-unit shots convert as timed
  rounds. Old projectile scenes and `PROJECTILES` removed.
- **Stage 2 complete (pending full-suite diff):** physical bullets, shells,
  rockets, guided missiles and rail lines (`WeaponCatalog`); target-frame sweeps,
  collateral enemies, blockers (`Battlefield.first_blocker`), ground; splash with
  falloff; deterministic dispersion; MultiMesh `ProjectileRenderer`; rocket
  infantry guided AA (0.8 s lock, 9 m, shared reload). New regressions
  `ProjectileSystemRegression`, `ProjectilePhysicsRegression` pass.
- Baseline: 109 of the first 258 headless tests already fail on the base commit
  (stale expectations, Lua runtime); comparisons use that baseline.
- **Stage 4 complete:** `FixedWingFlight` (point-mass flight, coordinated turns,
  taxi/take-off/approach/flare/rollout, two-ended landing with approach-room
  choice and turn-radius-scaled capture, terrain clearance), `FixedWingAircraft`
  (order translation, stores, fire control, rearm, ground target while parked),
  Fighter and Bomber, air actions and saves (`air` record). Regressions
  `FixedWingFlightRegression`, `FixedWingSaveRegression`; rendered
  `AirOpsPreview`.
- **Stage 3 in progress:** runway airfield (`AirfieldLayout`, `RunwayAirfield`
  model, polygon `footprint` identical to map-rebuild's export), footprint-aware
  range/sight/contact/repair (`Footprint.reach_distance`), polygon placement for
  player and AI (with approach-corridor check), stand reservation at queue time,
  jets spawn parked, per-stand/pad service, rectangle selection rings,
  re-sited pre-placed airfields (demo base re-authored; missions use probe-found
  headings). User decision 2026-10-20: no save backward compatibility, so the
  legacy round conversion was removed.
- **Stage 3 code complete; Stages 5, 6 and 8 code complete (unverified):** per
  user instruction (2026-10-20) the game is not launched, so these changes are
  checked only by gdformat/gdlint. Rotorcraft: hover acceleration/braking,
  helipad departure, pad settle, helicopter ground-only with 12 rockets that
  rearm on a pad (scenario patrols unlimited), kamikaze drone (`DroneDive`,
  Hold Fire default). AA vehicle per faction (flak / interceptors / autocannon).
  AI: AA vehicles vs observed air, fighters/bombers/helicopters/drones by role,
  rocket infantry vs air; advice recommends mobile anti-air. Air Corridor's air
  threat is now Talon interceptors. Pending engine runs: airfield-related
  regressions, AirCorridor, CombatRegression, RecoveryOrders, SkirmishRecovery,
  StructureActivity, AttackMoveArrival, CrowdBoundary, flight/projectile suites.
- **Stage 7 art built:** `art/air-combat/build_aircraft.py` (Blender 5.2) builds
  11 models with pivots and Cycles roster icons: Bastion fighter, bomber,
  attack helicopter, flak tank; Helix Talon, Shrike, Wraith tilt-rotor, Halo
  skimmer; Frontier Hornet, Buzzard, Ripsaw truck. Wired into scenes and faction
  catalogs; air wrecks keep forward crash momentum. Godot import of the new GLBs
  happens on the next engine launch.
- **Stage 9 docs:** core spec, design doc, README and changelog updated.
- **Outstanding (needs the engine, not run per user instruction):** import new
  GLBs; full headless suite vs baseline; rendered reviews (`AirOpsPreview` for
  all factions, `ProjectilePreview`, `HudConsolePreview`); AI air matchups and
  balance; `ScaleFrameBenchmark` before/after; Windows check.

- 2026-10-20 (engine runs): GLBs imported; full headless suite shows no
  regressions against base `88d9d99d` (remaining failures all fail on base and
  are being triaged); `AirOpsPreview` passes for all three factions and
  `HudConsolePreview` was reviewed. Still open: `ProjectilePreview` recapture,
  AI air matchups, `ScaleFrameBenchmark`, Windows check.
- 2026-10-20: Frontier balance per user direction. Frontier aircraft: 70%
  health, 80% damage, no faction speed bonus (the drone also loses its +2 sight).
  Frontier Barracks infantry including the hero: 110% health, 115% damage,
  +20% speed kept. `FactionRules.health_factor(faction, role)` feeds both spawn
  stats and save validation. Covered by `FrontierCombatRegression`.
