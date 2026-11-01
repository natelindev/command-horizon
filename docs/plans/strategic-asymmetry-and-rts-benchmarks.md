# Strategic Faction Asymmetry and RTS Benchmark Evolution Plan

## Status and Design Intent

Design and implementation roadmap, 2026-11-01. This plan establishes the strategic evolution of **Godot Open RTS**, bridging the architectural gap between an open-source engine prototype and genre-defining RTS masterworks: **StarCraft II**, **Command & Conquer: Red Alert 2**, and **Age of Empires II**.

The core objective is to replace the historical 1:1 mirrored roster and uniform tech tree with three radically asymmetric operational playstyles:
- **Bastion Directorate (The Fortified Juggernaut):** High-armor, slow, entrenchment-based siege warfare inspired by Terran mech and Soviet armor.
- **Helix Systems (The Cybernetic Directed-Energy Swarm):** Shield-reliant, hover-skimming, beam-chaining precision army inspired by Protoss high-tech and Allied prism technology.
- **Free Frontier Coalition (The Scavenger Swarm & Guerrilla Raiders):** Fast, batch-produced, salvage-cannibalizing raiders inspired by Zerg mass-production, Yuri weirdness, and scrap mechanics.

---

## Architectural Principles Learned from Benchmark Titles

| Benchmark | Core System Mechanism | Application to Godot Open RTS |
| :--- | :--- | :--- |
| **StarCraft II** | **Macro Asymmetry & Distinct Production Engines** | Bastion uses dedicated worker construction; Helix uses "fire-and-forget" nanite projection; Frontier uses batch/pair unit production and frontline wreck cannibalization. |
| **StarCraft II** | **Shield vs. Hull Health Dynamics** | Helix units receive rapidly regenerating Plasma Shields (8 HP/s out of combat), forcing distinct hit-and-run kiting counterplay compared to Bastion's permanent hull attrition. |
| **Red Alert 2** | **Signature Gimmicks & Non-Generic Units** | Differentiate unit roles: Bastion gets deployable Siege Colossus artillery; Helix gets beam-refracting Prism Skimmers; Frontier gets mobile garrison flatbed trucks. |
| **Red Alert 2** | **Power Grid Interactivity** | Power is not just a static capacity check: Helix Flux Overdrive allows temporary localized shield/production supercharging at high power cost. |
| **Age of Empires II** | **Exclusionary Tech Trees** | Remove universal `weapons_1/2/3` and `armor_1/2/3`; give each faction mutually exclusive doctrines and specialized upgrade paths. |
| **AoE2 & SC2** | **Tactical Micro & Formations** | Expand unit navigation beyond single-point clustering to support line, flank, and spread postures against explosive splash weapons. |

---

## Multi-Stage Implementation Plan

### Stage 1 — Core Component Traits Architecture
Decouple faction traits from global multiplier tables into modular, extensible unit components in `source/match/units/traits/`:
- **`ShieldComponent.gd`**: Manages regenerating energy shields that absorb damage before health is impacted. Emits shield break and recharge events, renders floating cyan shield bars above unit health bars, and links with `VehicleDamageProfile.gd`.
- **`GarrisonMount.gd`**: Enables designated vehicles (e.g., Frontier Battle Rigs) to embark infantry units who can fire their individual weapons while the vehicle is in motion.
- **`AutonomousAssembly.gd`**: Modifies building placement so Helix workers spawn a self-assembling nanite beacon and immediately disengage to return to harvesting.
- **`BattlefieldSalvage.gd`**: Expands wreck interaction beyond material transport, allowing Frontier engineers to consume wrecks on-site to spawn light buggies or attach permanent scrap armor.

### Stage 2 — Roster Decoupling & Signature Units
Break the 1:1 unit mirror in `source/match/FactionCatalog.gd` and create dedicated unit scenes:
- **Bastion Siege Colossus (`SiegeColossus.tscn`)**: Replaces the generic Advanced Tank. Deploys heavy stabilizers over 2.0s; fires high-arcing kinetic shells with heavy area splash damage. Cannot fire on the move.
- **Helix Prism Skimmer (`PrismSkimmer.tscn`)**: Replaces the generic hover tank. Fires continuous coherent laser beams that chain to up to 2 adjacent enemy targets, or refract through allied Helix turrets.
- **Frontier Battle Rig (`BattleRig.tscn`)**: Replaces the heavy tank with an armored flatbed mounting 4 garrison firing ports and dual forward autocannons.
- **Dedicated Anti-Air Divergence**:
  - Bastion: Flak halftrack firing bursting area-of-effect flak clouds.
  - Helix: Guided ion interceptor causing engine stall / thrust disablement.
  - Frontier: High-speed buggy firing unguided rocket swarms.

### Stage 3 — Exclusionary Technology & Doctrinal Trees
Refactor `source/match/research/TechnologyCatalog.gd` to abolish universal mirrored upgrades:
- **Hard Tech Exclusions**:
  - Bastion: Exclusive access to heavy composite plating, bunker reinforcements, and automated repair cranes; no directed-energy weapons or airborne cloaking.
  - Helix: Exclusive access to shield harmonic modulators, beam refraction grids, and instant hover thrusters; no heavy ballistic armor.
  - Frontier: Exclusive access to high-octane nitrous boosters, concealed IED density, and scrap cannibalization; no dedicated aerospace production facilities.
- **Branching Faction Doctrines**:
  - Command Lab provides mutually exclusive operational upgrades (e.g., Bastion *Iron Fortress* vs *Blitz Breakthrough*; Helix *Phase Shift Array* vs *Continuous Laser Amplification*).

### Stage 4 — Asymmetric Skirmish AI Archetypes
Extend `source/match/players/skirmish-ai/` so AI commanders embody their faction's strategic doctrine:
- **Bastion AI**: Methodical advance, establishes fortified defensive outposts at expansions, rolls forward with heavy siege lines and dedicated repair support.
- **Helix AI**: Mobile harassment, utilizes hover units to cross shallow water/cliffs, engages in hit-and-run tactics, disengages when shields collapse.
- **Frontier AI**: Rapid map saturation, swarms resource deposits with inexpensive raiders, sets up ambush minefields along transit corridors, rapidly replaces lost units via batch production.

### Stage 5 — Interface, HUD & Feedback Polish
- Integrate shield bars into `HealthBar.gd` and the bottom console selection panel.
- Update `AbilityTray.gd` with signature faction active powers (Bastion Anchor, Helix Phase Shift, Frontier Overdrive).
- Display garrisoned squad members and their fire status within the bottom HUD vehicle cards.
- Update localization catalogs (`art/localization/factions.tsv`, `tactical-environment.tsv`) and compile via `build_catalog.py`.

### Stage 6 — Long-Term Engine Platform Gates (Multiplayer & Tooling)
- **Deterministic Simulation Foundation**: Isolate simulation math from float non-determinism in preparation for lockstep multiplayer.
- **Deterministic Input Replay Engine**: Implement binary command-logging (`.rtsreplay`) for match playback, spectator casting, and desync detection.
- **In-Engine Scenario & Map Editor**: Expose an in-game level builder utilizing the modular environment kits.

---

## Agent Progress

- **Exploration & Benchmarking Completed**: Conducted deep comparative analysis of `godot-open-rts` against StarCraft II, Red Alert 2, and Age of Empires II. Identified root structural issues: 1:1 mirrored rosters, uniform tech trees, absence of distinct macro engines, and lack of networking/replay infrastructure.
- **Living Game Design Updated**: Added Section 141 ("Strategic Faction Asymmetry & RTS Benchmark Evolution") to `docs/GAME_DESIGN.md` defining the architectural vision and faction identities.
- **Implementation Plan Formulated**: Created `docs/plans/strategic-asymmetry-and-rts-benchmarks.md` establishing a 6-stage roadmap for engine traits, roster decoupling, tech exclusions, AI doctrines, and long-term benchmark platform goals.
