# Tactical Gameplay Depth, Faction Asymmetry, and Map Events Plan

## Design Overview & Confirmed Decisions

Based on game design evaluation and confirmed commander decisions:
- **Infantry Suppression & Garrison Breaching:** Sustained fire builds suppression, forcing infantry into lower profiles with clear overhead and HUD indicators. Frag grenades flush garrisoned troops out of neutral buildings.
- **Faction Asymmetry Polish:** Grounded, distinctive macro systems:
  - **Bastion:** Assembly Line continuous production speed bonuses + forward field barricades.
  - **Helix:** Power Grid Overdrive mode + Electronic Warfare drone chaff.
  - **Frontier:** Concealed scrap mines (booby traps) + modular visual scrap hardening on scavenged vehicles.
- **Dynamic Map-Specific Battlefield Events:** Unique mid-game events tailored to map biomes (desert supply airdrops, industrial automated freight/power surges, coastal flotsam/fog banks, alpine satellite uplinks).
- **Commander Off-Map Call-Ins:** High-cost, long-cooldown strategic powers unlocked at Tier 2 technology buildings (Bastion Heavy Artillery Barrage, Helix Orbital EMP Surge, Frontier Smuggler Airdrop) with distinct audio-visual warnings and counterplay.
- **Faction-Specific Vehicle Damage States:**
  - Bastion: Diesel smoke, hull fires, and track squeal.
  - Helix: Cyan plasma venting, electrical arcing, and repulsor wobble.
  - Frontier: Radiator steam leaks, rattling scrap plates, and engine backfires.
- **Camera Rule:** Zero artificial camera shake in Skirmish (preserving competitive readability); camera impulses reserved exclusively for Campaign scripted moments.
- **Excluded Features:** Directional armor is discarded; Super-Units/Behemoths are strictly excluded from Skirmish and reserved only for Campaign boss encounters.

---

## Stage 1 — Infantry Suppression & Garrison Breaching

### 1.1 Suppression System & Overhead Visual Indicators
- In `source/match/units/traits/InfantryMotion.gd` and `source/match/units/Unit.gd`:
  - Add `suppression` (float, 0.0 to 100.0) and `suppression_decay` (10.0/s after 3.0s cooldown).
  - Autocannon rounds, AA fire, and concentrated rifle fire add suppression on hit.
  - Thresholds:
    - `Suppressed` (>= 50.0): -30% movement speed, +20% reload time.
    - `Pinned` (>= 90.0): -60% movement speed, unit assumes prone/low-crawl posture, but gains -20% incoming projectile hit profile.
- Visual & UI indicators:
  - Overhead icon above infantry (`source/match/units/traits/HealthBar.gd` or dedicated `SuppressionIndicator`):
    - Amber shield/bracket at 50% (`Suppressed`).
    - Flashing red pinned icon at 90% (`Pinned!`).
  - Unit selection HUD (`UnitMenus.gd` / bottom console): shows `[SUPPRESSED]` or `[PINNED]` badge with a dedicated suppression meter below health.

### 1.2 Garrison Breaching with Frag Grenades
- In `source/match/units/traits/UnitAbilities.gd` and `source/match/world/NeutralBuilding.gd`:
  - When targeting an infantry-occupied neutral/civilian building with **Frag Grenade (Q)**:
    - Grenade deals 1.5x damage to occupants inside.
    - Occupants are forcefully ejected/evicted from the building to adjacent walkable positions and stunned/disoriented for 2.0 seconds.

---

## Stage 2 — Faction-Specific Vehicle Damage States & Camera Constraints

### 2.1 Faction-Distinct Vehicle Damage Visuals
- In `source/match/effects/CombatEffects.gd` and `source/match/units/Unit.gd`:
  - Expand threshold checks at `<50% HP` (Moderate) and `<25% HP` (Critical):
    - **Bastion:** Heavy black diesel smoke plumes at <50%; active hull fires, trailing sparks, and engine grinding at <25%.
    - **Helix:** Leaking cyan plasma jets from heat sinks at <50%; errant electrical arcs and repulsor hover wobble/altitude instability at <25%.
    - **Frontier:** Hissing white radiator steam clouds and loose vibrating scrap plates at <50%; engine backfiring with dark soot puffs and pronounced chassis rumble at <25%.
- Sound effects: integrate with `CombatAudio.gd` for low-health engine sputtering and clanking.

### 2.2 Strict Camera Control Policy
- In `source/match/IsometricCamera3D.gd`:
  - Ensure impulse/shake methods verify `match.settings.mission_id != ""` before executing any camera shake.
  - Skirmish matches enforce 0.0 camera offset/shake to guarantee stable, competitive clarity.

---

## Stage 3 — Dynamic Map-Specific Battlefield Events

### 3.1 Event System Architecture
- Create `source/match/world/BattlefieldEvents.gd`:
  - Manages timed neutral map events (e.g. at 5:00 and 11:00 match time).
  - Emits global audio warning siren and minimap ping 45 seconds prior to event occurrence.
  - Supports save/restore persistence in `SnapshotSchema.gd`.

### 3.2 Map Biome Event Implementations
- **Desert Maps (*Desert Frontier*, *Redrock Divide*):**
  - *Supply Drop:* Neutral cargo transport drops 2 contested resource crates (Materials + Electronics) in central open terrain.
- **Industrial Maps (*Industrial Crossroads*, *Broken Foundry*):**
  - *Automated Freight Train / Cargo Depot:* Rail convoy delivers high-value electronics container to central rail crossing; secured by holding the depot terminal for 30s.
- **Coastal Maps (*Coastal Foundry*, *Sunken Exchange*):**
  - *Stranded Cargo Flotsam:* Container barge washes ashore in tidal shallows, releasing harvestable salvage crates.
- **Alpine Maps (*Alpine Relay*, *Glacier Narrows*):**
  - *Orbital Relay Uplink:* Central comms antenna powers on for 60s; controlling the station grants temporary global radar sweep.

---

## Stage 4 — Commander Off-Map Call-Ins

### 4.1 Unlock, Resources, and HUD Integration
- Unlocked upon constructing Tier 2 tech structure:
  - Bastion: *Command Lab*
  - Helix: *Signal Lab*
  - Frontier: *Frontier Scrap Yard / Depot*
- Cooldown: 120–150s; Cost: 50 Materials, 30 Electronics.
- UI: Dedicated Commander Powers panel positioned on the HUD console with clear hotkeys, recharge rings, and cost tooltips.

### 4.2 Faction Call-In Mechanics & Telegraphing
- **Bastion — Heavy Artillery Barrage:**
  - Red smoke marker detonates at target coordinate.
  - Siren and incoming shell audio whistle for 3.5s (giving mobile units time to disperse).
  - 6 heavy artillery shells impact over 3 seconds, dealing massive structural and cluster damage.
- **Helix — Orbital EMP Surge:**
  - Expanding holographic energy ring charges at ground target for 2.5s with rising electronic pitch.
  - Discharges an EMP wave that strips plasma shields to 0, slows vehicles by 40% for 6s, and temporarily disables turrets for 12s.
- **Frontier — Smuggler's Airdrop:**
  - Fast cargo transport drops a container with 2 mercenary combat buggies/rangers and an instant repair crate in explored territory. Parachute descent is vulnerable to enemy anti-air.

---

## Stage 5 — Asymmetric Macro Mechanics

### 5.1 Bastion Assembly Line & Field Barricades
- *Assembly Lines:* Consecutive identical unit queues at Vehicle Factory / Barracks receive an 8% speed bonus per queued unit (capped at 24%).
- *Field Barricades:* Bastion workers can erect quick Sandbag Barricades (`DestructibleObstacle`) for 10 materials to secure choke points.

### 5.2 Helix Power Grid Overdrive & EW Drone Chaff
- *Power Overdrive:* Helix Flux Generators can toggle Overdrive mode, increasing regional shield recharge rates by 50% while operating.
- *Drone Chaff:* Kite Drones gain an active chaff dispenser ability (`E`) to jam missile guidance in a 10m radius for 8 seconds.

### 5.3 Frontier Concealed Mines & Scrap Hardening
- *Concealed Mines:* Frontier workers/buggies can deploy concealed proximity scrap mines on roads and passes.
- *Modular Visual Scrap:* Frontier vehicles gain layered visual scrap armor plates upon reaching Tier 2 Scrap Hardened.

---

## Stage 6 — Regression Testing & Verification

1. Unit tests in `tests/headless/`:
   - `SuppressionRegression.gd`: verifies suppression buildup, decay, pinning speed/accuracy penalties, and overhead visual state.
   - `GarrisonBreachRegression.gd`: verifies grenade eviction mechanics from neutral buildings.
   - `VehicleDamageVisualsRegression.gd`: verifies threshold triggers for smoke/flame, plasma, and steam per faction.
   - `BattlefieldEventsRegression.gd`: verifies event scheduling, drop spawning, capture, and save/load persistence.
   - `CommanderCallInsRegression.gd`: verifies unlock gates, costs, cooldowns, telegraph timers, and effect execution.
2. Rendered preview tests in `tests/rendered/`:
   - Preview captures for suppression overhead UI, faction vehicle damage states, and commander call-in telegraphing.

---

## Agent progress

- Plan document created. Ready for staged implementation and verification upon instruction.
