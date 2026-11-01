# Macro Economy & Harvesting Dynamics Specification

Status: **Active Design Direction**  
Date: **2026-11-01**  
Foundation: Synthesized from RTS genre benchmarks (**StarCraft II**, **Age of Empires II**, and **Command & Conquer: Red Alert 2**) for **Godot Open RTS**.  
Supersedes: The static two-resource, single-drop-off economic loop where all factions used identical workers, identical haul routines, and passive power penalties.

---

## 1. Executive Summary & The Problem with the Baseline Economy

In the baseline implementation of **Godot Open RTS**:
- **Homogeneous Gathering:** All three factions train identical workers (`Worker.gd`). Every worker drives to a deposit, waits for a fixed collection interval, loads 4 units of cargo into `WorkerCargo.gd`, and drives back to the `CommandCenter`.
- **Single Universal Drop-off Point:** Resources can only be returned to a completed `CommandCenter`. There are no forward drop-off depots, refineries, or specialized mining structures. Expanding to a distant resource field requires building an entire expensive HQ.
- **Passive Power Penalty:** Power is purely an aggregate capacity meter. If demand exceeds supply, production and research globally slow to 35%. There are no localized power outages, no defensive structure shutdowns, and no power grid interactivity.
- **Zero Economic Specialization:** Factions possess no unique economic rhythm, no macro abilities (such as MULEs, Chrono Boost, or Queen Larva Injections), and no interaction with neutral economic points of interest.

This specification redesigns the macro-economy into an active, strategic pillar of the game where economic decisions shape military capability.

---

## 2. Core Lessons from Benchmark RTS Titles

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                            BENCHMARK LESSONS MATRIX                                  │
├─────────────────┬──────────────────────────────────┬─────────────────────────────────┤
│ BENCHMARK GAME  │ CORE ECONOMIC MECHANICS          │ LESSON FOR GODOT OPEN RTS       │
├─────────────────┼──────────────────────────────────┼─────────────────────────────────┤
│ StarCraft II    │ • Strict saturation curves (16/16│ • Add visible field saturation. │
│                 │   on minerals, 3/3 on gas).      │ • Give each faction an active   │
│                 │ • Macro Injections (MULE, Queen   │   macro rhythm / HQ ability     │
│                 │   Inject, Chrono Boost).         │   (e.g., Chrono Overdrive).     │
│                 │ • Finite bases that dry up,      │ • Fast base depletion forcing   │
│                 │   forcing continuous expansion.  │   forward expansion.            │
├─────────────────┼──────────────────────────────────┼─────────────────────────────────┤
│ Age of Empires  │ • 4 interdependent resources.    │ • Introduce specialized forward │
│ II              │ • Dynamic terrain transformation │   drop-offs (Refineries).       │
│                 │   (chopping forests opens paths).│ • Dynamic Market trading to     │
│                 │ • Dynamic Commodity Market for   │   rebalance resource deficits.  │
│                 │   buying/selling resources.      │ • Villager defense & garrison   │
│                 │ • Drop-off optimization (Lumber  │   under town center alarms.     │
│                 │   & Mining camps).               │                                 │
├─────────────────┼──────────────────────────────────┼─────────────────────────────────┤
│ Red Alert 2     │ • Combat Harvesters (Soviet War  │ • Asymmetric Harvester units:   │
│                 │   Miner defends with 20mm gun).  │   armed miners, teleporters,    │
│                 │ • Chrono Miner teleports home.   │   and frontline scrap rigs.     │
│                 │ • Neutral Tech Oil Derricks      │ • Capturable neutral refineries │
│                 │   grant continuous cash trickle. │   yielding continuous passive   │
│                 │ • Power Blackout: shuts down     │   income.                       │
│                 │   defenses, radar, superweapons. │ • Active Power Grid brownouts.  │
└─────────────────┴──────────────────────────────────┴─────────────────────────────────┘
```

---

## 3. The New Multi-Tiered Economic System

### 3.1 Currencies and Resources

1. **Materials (M):**
   * *Role:* The heavy physical construction backbone. Required for all buildings, structures, defenses, conventional armor, ballistic ammunition, and infantry.
   * *Sources:* High-density industrial scrap heaps, mineral outcroppings, and salvaged combat vehicle wrecks.
2. **Electronics (E):**
   * *Role:* The high-tech and cybernetic currency. Required for advanced vehicle chassis, directed energy weapons, plasma shields, radar systems, and technology research.
   * *Sources:* Rare capacitor deposits, server bank ruins, and tech capture points.
3. **Logistics / Fuel (Tactical Dynamic Reserve):**
   * Sourced from neutral Capturable Refineries or generated at Power Plants. Consumed to fuel active vehicle speed boosts, airstrikes, and commander abilities.

---

### 3.2 Active Power Grid: Brownouts & Overcharge

Replacing the passive 35% speed penalty with **active, readable power states**:

```
[ GREEN: SURPLUS ]   ──> Demand < Supply. All systems operate at 100% efficiency.
[ YELLOW: BALANCED ] ──> Demand = Supply. Normal operation; warnings if new queues start.
[ RED: BROWNOUT ]    ──> Demand > Supply. 
                         • Base defense turrets (AntiGroundTurret, AntiAirTurret) SHUT DOWN.
                         • Minimap radar undergoes static interference.
                         • Shield out-of-combat regeneration rate reduced by 50%.
                         • Production & research slow to 25% speed.
[ OVERDRIVE STATE ]  ──> Player actively triggers a Power Plant to surge power (+50% output
                         for 30 seconds), after which the generator undergoes a 10s cooldown.
```

---

## 4. Faction-Specific Macro Engines & Harvester Asymmetry

Each faction will feature a completely distinct economic operation:

```
                  ┌──────────────────────────────────────────────┐
                  │          FACTION MACRO ENGINES               │
                  └──────────────────────────────────────────────┘
                                 /              \
                                /                \
                               /                  \
           BASTION DIRECTORATE                    HELIX SYSTEMS
      "Industrial Bulk Logistics"            "Autonomous Phase Harvesting"
      • Heavy Armored Mule Hauler            • Hovering Flux Skimmer
      • Forward Ore Refineries (Drop-off)    • Chrono-Teleport Return to HQ
      • Built-in Smelting Bonus (+15% M)     • Flux Resonance (Chrono Boost)
      • High Cargo Capacity (8 units)        • High Electronics Gathering Efficiency
                               \                  /
                                \                /
                                 \              /
                           FREE FRONTIER COALITION
                       "Field Scavenging & Scrapper Rigs"
                       • Armed War Scrapper (20mm Defense Gun)
                       • Frontline Wreck Cannibalization
                       • Mobile Drop-Off / On-Site Processing
                       • Black Market Resource Exchange
```

---

### 4.1 Bastion Directorate — Industrial Bulk Logistics & Forward Refineries
*Inspired by Terran macro logistics and AoE2 drop-off efficiency.*

* **Harvester Unit — Heavy Mule Hauler:**
  * Massive tracked hauler with heavy armor plating ($120\text{ HP}$) and passive self-repair ($1.5\text{ HP/s}$ out of combat).
  * *High Capacity:* Carries **8 units** of resources per trip (double the standard 4-unit capacity), spending more time gathering and making fewer trips.
* **Specialized Structure — Forward Ore Refinery:**
  * Cost: $35\text{ M} / 10\text{ E}$. Low-cost dedicated resource drop-off facility.
  * Allows Bastion players to establish expansions without spending the massive cost of an entire Command Center.
  * *Smelting Bonus:* Resources dropped off at a Forward Refinery receive a $+15\%$ material yield bonus through automated refining.
* **Macro Ability — Industrial Overhaul:**
  * Cooldown: 60s. Target a resource field; all Bastion workers on that field gather $+30\%$ faster for 30 seconds.

---

### 4.2 Helix Systems — Autonomous Phase Harvesting & Chrono Delivery
*Inspired by StarCraft II Protoss Chrono Boost and Red Alert 2 Allied Chrono Miners.*

* **Harvester Unit — Flux Skimmer:**
  * Repulsor hovercraft that glides frictionlessly over rough terrain, rocks, and shallow water.
  * High gathering speed for Electronics ($25\%$ faster collection cycle).
* **Harvesting Mechanic — Phase Teleport Delivery:**
  * Once the Flux Skimmer's cargo bay is full ($4\text{ units}$), it does not drive back through dangerous choke points.
  * It channels for $1.2\text{ seconds}$ and **teleports directly back to the Nexus HQ**, drops off its cargo instantly, and glides back to the field. This cuts travel vulnerability and turn-around time by more than $50\%$.
* **Macro Ability — Flux Resonance (Chrono Boost):**
  * Cost: 25 Energy from Nexus HQ.
  * Target any friendly structure (Robotics Foundry, Flight Deck, Signal Lab). Accelerates its production or research rate by $+50\%$ for 25 seconds. Allows urgent army reinforcement or fast-tech rushes.

---

### 4.3 Free Frontier Coalition — Field Scavenging & The Black Market
*Inspired by Red Alert 2 Soviet War Miners and Age of Empires II Commodity Markets.*

* **Harvester Unit — Armed Scrapper Rig:**
  * Rugged 6-wheeled truck equipped with an automated **20mm Defense Autocannon**.
  * Can defend itself against enemy scout drones, light infantry, and raiding buggies without requiring military escorts.
* **Harvesting Mechanic — Frontline Wreck Cannibalization:**
  * Destroyed vehicles and aircraft leave battlefield wrecks containing $35\text{--}50\%$ of their original material value.
  * Scrapper Rigs can break down wrecks directly on the front line without traveling back to HQ, converting scrap into immediate field repairs for damaged allies or assembling improvised combat buggies.
* **Specialized Structure & Ability — The Black Market:**
  * Built at the Scrap Yard.
  * Allows the Frontier player to dynamically buy and sell Materials for Electronics (and vice versa) at fluctuating market rates, allowing instant recovery from economic imbalances.

---

## 5. Secondary Economy & Contested World Objectives

*Inspired by Red Alert 2 Tech Oil Derricks and Age of Empires II Relics.*

```
                                [ NEUTRAL CONTESTED MAP OBJECTIVES ]
                                            │
               ┌────────────────────────────┼────────────────────────────┐
               │                            │                            │
      [ TECH OIL REFINERIES ]       [ SCRAP FREIGHT HUBS ]       [ DATA SATELLITE RELAYS ]
      • Captured by Infantry.       • Timed train / convoy       • Contested hill objective.
      • Grants instant +50 M / +25 E  arrivals.                  • Grants full map radar sweep
        bounty upon capture.        • Drops contested supply       and passive Electronics
      • Steady passive income of      crates with massive cash     trickle (+2 E every 5s).
        +3 M / +1 E every 4s.         windfalls.
```

### 5.1 Rules for Neutral Economic Captures
1. **Infantry Capture Loop:** To capture a Tech Refinery or Satellite Relay, infantry must approach and channel for 12 seconds uninterrupted. Taking hostile damage interrupts the capture timer.
2. **Contested Status:** If enemy infantry enter the capture radius, the structure becomes contested and passive resource income halts until the area is cleared.
3. **Destructible & Rebuildable:** Neutral capture points can be damaged and destroyed by siege weapons to deny resources to the enemy; engineers can repair ruins to restore functionality.

---

## 6. Resource Field Saturation & Depletion Dynamics

*Inspired by StarCraft II worker saturation curves.*

1. **Field Saturation UI:**
   * Selecting a resource deposit or hovering over a field displays an exact worker efficiency counter: `Workers: 4 / 6 (Optimal)`.
   * *Efficiency curve:*
     * 1–2 workers per node: $100\%$ gathering rate.
     * 3 workers per node: $60\%$ gathering rate (diminishing returns).
     * 4+ workers per node: $0\%$ marginal yield (excess workers wait in line).
2. **Pacing and Base Depletion:**
   * Starter home resource fields contain sufficient materials for 7–9 minutes of sustained production.
   * As fields exhaust, deposit meshes visibly degrade into scattered scraps before vanishing completely.
   * To sustain high-tier army production, players are forced to push out and claim contested secondary expansions across the map.

---

## 7. Multi-Stage Implementation Plan

### Stage 1 — Economic Trait Modularization & Harvester Base
* Create `source/match/economy/HarvestingProfile.gd`: defines cargo capacity, harvest interval, travel multipliers, and drop-off validation.
* Implement `ForwardRefinery.tscn` as a valid resource drop-off structure for Bastion.
* Update `CollectingResourcesSequentially.gd` to identify nearest valid drop-off point (`CommandCenter` OR `ForwardRefinery`).

### Stage 2 — Faction Harvester Differentiation
* **Bastion Mule Hauler:** Increase cargo limit to 8; add passive out-of-combat repair trait.
* **Helix Flux Skimmer:** Implement hover movement (ignores terrain elevation penalties) and `PhaseTeleport` action back to Nexus HQ upon reaching full capacity.
* **Frontier Scrapper Rig:** Attach `Weapon` component (20mm autocannon) and targetability rules against hostile light units; implement on-site wreck salvage.

### Stage 3 — Active Power Grid & Brownouts
* Update `source/match/players/Player.gd` power calculation:
  * When `power_demand > power_supply`, trigger `BROWNOUT` state.
  * Disable `AntiGroundTurret` and `AntiAirTurret` firing loops during brownouts.
  * Add HUD audio/visual alarm (`"Warning: Power Grid Deficit"`).
  * Implement temporary generator Overdrive action.

### Stage 4 — Neutral Capturable Economic Structures
* Create `TechRefinery.tscn` and `DataRelay.tscn` in `source/match/world/`.
* Implement passive income timer loop in `Player.gd` (`add_passive_income(delta)`).
* Integrate infantry capture interaction into `NeutralBuilding.gd` with contested radius logic.

### Stage 5 — Macro Abilities & Saturation Feedback
* Implement Helix `Flux Resonance` (Chrono Boost) targeting production facilities.
* Implement Bastion `Industrial Overhaul` area harvesting boost.
* Implement Frontier `Black Market` exchange menu in HUD console.
* Add field worker saturation tooltips (`4 / 6 Workers`) to resource hover cards.

### Stage 6 — AI Adaptation, Persistence & Verification
* Update `SkirmishAI.gd` to recognize forward refineries, expand to secondary fields upon 60% depletion, and target neutral tech oil refineries.
* Update `MatchSnapshot.gd` to serialize harvester teleport cooldowns, active power states, and neutral structure capture ownership.
* Add headless regression test `tests/headless/MacroEconomyRegression.gd`.

---

## Agent Progress

- **Deep Benchmark Analysis Completed**: Evaluated economic pacing and harvesting mechanics from StarCraft II (saturation curves, macro injections), Age of Empires II (multi-resource interdependence, forward drop-offs, commodity markets), and Red Alert 2 (combat miners, teleporter miners, tech oil derricks, power blackouts).
- **Core Diagnosis Established**: Identified existing limitations in Godot Open RTS (homogeneous workers, single HQ drop-off, passive power penalties, lack of secondary income).
- **Comprehensive Specification Authored**: Created `docs/MACRO_ECONOMY.md` laying down the complete multi-tiered resource architecture, active power grid mechanics, faction-specific harvester identities, neutral contested captures, and a 6-stage engineering plan.
