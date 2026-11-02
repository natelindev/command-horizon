# Faction Asymmetry Specification — Living Game Design

Status: **Active Design Direction**  
Date: **2026-11-01**  
Foundation: Synthesized from RTS genre benchmarks (**StarCraft II**, **Command & Conquer: Red Alert 2**, and **Age of Empires II**) for **Godot Open RTS**.  
Supersedes: The historical 1:1 mirrored roster and uniform tech tree where factions differed only by percentage stat multipliers (`-20%` HP, `+20%` speed) and cosmetic materials.

---

## 1. Vision & Core Philosophy

### 1.1 The "Symmetrical Trap" in RTS Design
In early prototypes of Godot Open RTS, all three factions (Bastion, Helix, Frontier) shared an identical structural foundation:
- 15 identical unit roles (`Worker`, `Infantry`, `RocketInfantry`, `Tank`, `AdvancedTank`, `AntiAirVehicle`, `Fighter`, etc.)
- 9 identical buildings (`CommandCenter`, `Barracks`, `VehicleFactory`, `AircraftFactory`, `PowerPlant`, `CommandLab`, `RepairDepot`, `Turrets`)
- Identical upgrade queues (`weapons_1/2/3`, `armor_1/2/3`)

While this simplified early engine prototyping in Godot 4, it creates gameplay fatigue: matchups play identically regardless of faction chosen, build orders mirror each other, and battles become purely numerical stat-checks rather than dynamic clashes of opposing philosophies.

### 1.2 The Three Benchmark Pillars
To elevate the game to the caliber of timeless RTS titles, we apply three proven architectural paradigms:
1. **StarCraft II — Operational & Macro Asymmetry:** Each faction must feature a distinct operational engine. How a player gathers, builds, and maintains army continuity must feel mechanically unique (Terran add-ons and SCV commitment vs. Protoss warp/shields vs. Zerg larvae/creep).
2. **Red Alert 2 — High-Concept Unit Roles & Signature "Gimmicks":** Units should possess memorable, exaggerated tactical identities (Prism beam-chaining, Apocalypse dual-cannons, deployable Desolators, mobile Battle Fortresses, and power grid interactions).
3. **Age of Empires II — Exclusionary Tech Trees & Positional Dynamics:** Factions must be defined as much by what they *cannot* build as what they can, featuring branching doctrines and specialized counters rather than universal tech trees.

---

## 2. Faction Architectural Blueprints

```
                     ┌──────────────────────────────────────────────┐
                     │          FACTION ASYMMETRY TRIAD             │
                     └──────────────────────────────────────────────┘
                                    /              \
                                   /                \
                                  /                  \
              BASTION DIRECTORATE                    HELIX SYSTEMS
         "The Fortified Juggernaut"             "The Cybernetic Energy Swarm"
         • High Armor / Kinetic Fire            • Regenerating Plasma Shields
         • Tethered Worker Construction         • "Fire-and-Forget" Nanite Build
         • Deployable Siege Colossus            • Beam-Chaining Prism Skimmers
         • Bunker Networks & Repair             • Phase-Shift Teleportation
         • Attrition Grinding Play              • Hit-and-Run Kiting Play
                                  \                  /
                                   \                /
                                    \              /
                              FREE FRONTIER COALITION
                          "Scavenger Swarm & Raiders"
                          • Batch & Pair Production
                          • Wreck Field Cannibalization
                          • Mobile Garrison Battle Rigs
                          • Concealed Proximity IEDs
                          • Swarm & Guerrilla Ambush
```

---

### 2.1 Bastion Directorate — The Fortified Juggernaut

* **Thematic Identity:** Industrial diesel-punk, heavy cast armor, composite bulkheads, rhythmic combustion engines, heavy ballistic cannons, and grinding positional warfare.
* **Inspirations:** StarCraft II Terran Mech; Red Alert 2 Soviet Armored Divisions.

#### Macro & Operational Engine
* **Tethered Worker Construction:** Bastion engineers must physically remain on-site throughout a structure's assembly. Construction can be disrupted by worker harassment, but Bastion structures boast $+25\%$ base health and higher ballistic damage resistance.
* **Assembly Line Streaks:** Production facilities build kinetic momentum: consecutive completions of the same unit class accelerate production speed by up to $+24\%$. Switching production queues resets the streak.
* **Perimeter Maintenance:** Field Repair Depots and mobile support vehicles continuously repair adjacent damaged armor without resource drain, enabling long, sustained siege pushes where preserved units compound into an unstoppable deathball.

#### Base Defense & Entrenchment
* **Deployable Bunkers:** Heavy concrete pillboxes garrisoning up to 6 infantry units, protecting them from suppression and direct fire while multiplying their firing range.
* **Sandbag Barricades & Tank Traps:** Cheap, instant forward emplacements deployed by workers to shape battlefield choke points and block hostile vehicles.

#### Signature Units
1. **Siege Colossus** *(Replaces generic Advanced Tank)*:
   * Heavy quad-tracked siege platform. Must deploy hydraulic anchor spades (2.0s delay) to fire.
   * *Weapon:* 155mm Heavy Kinetic Cannon. Range: 16 m. Fires devastating explosive shells with wide area splash damage that obliterates infantry clusters and light vehicles. Cannot fire while mobile.
2. **Bulwark Walker** *(Replaces generic Combat Robot)*:
   * Bipedal heavy armored walker equipped with a frontal directional kinetic shield.
   * Absorbs incoming direct-fire projectiles in a 60-degree forward arc, creating a mobile safe corridor for advancing infantry.
3. **Flak Halftrack** *(Anti-Air Vehicle)*:
   * Fires proximity-detonating flak shells that create lingering area-of-effect flak clouds, decimating clustered hostile drones, fighters, and bombers.

#### Strategic Matchup Dynamics
* **Strengths:** Dominates narrow choke points; virtually unbreakable defensive perimeters; excels in slow, methodical deathball pushes.
* **Weaknesses:** Highly sluggish redeployment speed; vulnerable to long-range harassment, multi-prong raids, and energy beam kiting.

---

### 2.2 Helix Systems — The Cybernetic Directed-Energy Swarm

* **Thematic Identity:** Sleek cybernetic levitation, repulsor skimmers, glowing cyan plasma, coherent lasers, phase shifting, and clean energy optimization.
* **Inspirations:** StarCraft II Protoss High-Tech; Red Alert 2 Allied Prism & Chrono Divisions.

#### Macro & Operational Engine
* **Autonomous Nanite Construction:** Mule engineers drop a nanite beacon at the chosen blueprint location and immediately disengage to resume resource gathering. The structure synthesizes itself automatically over time.
* **The Plasma Shield Matrix:**
  * Helix units have low base physical hull HP ($40\text{--}50\%$ of Bastion equivalents), but possess a protective **Plasma Shield Envelope** representing $50\text{--}60\%$ of their total survivability.
  * *Recharge Rule:* After remaining out of combat for 5.0 seconds, shields recharge rapidly at a rate of 8 HP/second.
  * *Micro Implication:* Helix players thrive on hit-and-run tactics, skirmishing to strip enemy health, disengaging before hull damage occurs, and re-engaging with full shields.
* **Flux Power Overdrive:**
  * Selecting a Flux Generator allows the player to trigger *Overdrive* (high power draw mode), speeding up adjacent factory production and doubling shield recharge rates for nearby friendly units.

#### Base Defense & Infrastructure
* **Prism Emitter Pylons:** Defensive towers that fire focused laser beams. When multiple Prism Pylons or Prism Skimmers are clustered, they link their beams together, focusing astronomical single-target damage to vaporize approaching heavy tanks.

#### Signature Units
1. **Prism Skimmer** *(Replaces generic Advanced Tank)*:
   * Hover-skimmer firing a continuous coherent laser beam.
   * *Refraction Beam:* The beam refracts and chains to up to two additional adjacent enemy units. If firing alongside allied Prism Skimmers, beams merge to amplify focused DPS.
2. **Phase Lancer** *(Replaces generic Combat Robot)*:
   * Agile quad-legged energy walker equipped with anti-armor pulse lances.
   * *Active Ability — Phase Shift:* Instantly teleports 8 metres in the target direction on a 15-second cooldown. Allows jumping across cliffs, bypassing tank traps, or escaping encirclements.
3. **Skyward Ion Interceptor** *(Anti-Air Vehicle)*:
   * Fires guided ion torpedoes that strip shields and overload target aircraft engines, inducing a temporary control stall and trajectory drift.

#### Strategic Matchup Dynamics
* **Strengths:** Unrivaled battlefield mobility (hovering over cliffs and shallow water); devastating hit-and-run potential; superior single-target laser focus.
* **Weaknesses:** Catastrophic vulnerability if caught in sustained combat; fragile physical hulls crumble quickly once shields are depleted by EMP or heavy kinetic fire.

---

### 2.3 Free Frontier Coalition — Scavenger Swarm & Guerrilla Raiders

* **Thematic Identity:** Post-collapse wasteland survivors, roaring modified V8 engines, rattling welded steel plates, improvised weapons, salvage mechanics, and unpredictable guerrilla tactics.
* **Inspirations:** StarCraft II Zerg Swarm; Red Alert 2 Yuri / GLA Scrap Raiders.

#### Macro & Operational Engine
* **Batch / Pair Unit Production:** Frontier workshops and motor pools train units in pairs or triplets (e.g., 2 Outrider technicals or 3 militia riflemen per production cycle), rapidly flooding the map with expendable forces.
* **Frontline Wreck Cannibalization:**
  * Ground combat leaves persistent wrecks.
  * Instead of merely returning scrap to HQ for cash, Frontier engineers can cannibalize wrecks directly on the front line to instantly assemble makeshift combat buggies or fuse scrap plates onto damaged vehicles for permanent damage reduction.
* **Decentralized Base Layout:** Low power requirements and cheap structure costs allow Frontier players to build hidden auxiliary workshops across remote corners of the map.

#### Base Defense & Ambush Systems
* **Concealed Proximity IEDs & Minefields:** Frontier workers lay hidden explosive charges along haul roads and choke points, detonating when hostile armor drives over them.
* **Scrap Barricades:** Low-cost junk barriers that can be rapidly thrown up to funnel enemy columns into ambush killzones.

#### Signature Units
1. **Battle Rig** *(Replaces generic Heavy Tank)*:
   * Heavily armored flatbed technical equipped with twin forward autocannons and **4 Open Garrison Mounts**.
   * Embarked infantry units (such as Rocket Hunters and Marksmen) fire their weapons freely while the Battle Rig maneuvers at high speed.
   * Garrisoned infantry bodies and world selection markers remain hidden inside vehicles. The bottom HUD shows their passenger portraits and firing status; unloading restores their world visibility.
2. **Scrap Demolition Buggy** *(Light Specialist)*:
   * High-speed, unarmored buggy packed with volatile munitions.
   * Charges into enemy fortifications, artillery batteries, or clustered columns, detonating on impact to inflict devastating point-blank burst damage.
3. **SAM Technical** *(Anti-Air Vehicle)*:
   * Fast wheeled truck mounted with unguided rocket pods that fire high-velocity swarms, devastating low-flying helicopters and air transports from ambush.

#### Strategic Matchup Dynamics
* **Strengths:** Overwhelming early-game map presence; multi-prong raiding capability; high economic efficiency through battlefield scrap reuse; lethal ambush bursts.
* **Weaknesses:** Total lack of heavy Tier-3 endgame armor; struggles severely in sustained head-on brawls against fortified Bastion lines or concentrated Helix laser choke points.

---

## 3. Roster & Unit Differentiation Matrix

| Role | Bastion Directorate | Helix Systems | Free Frontier Coalition |
| :--- | :--- | :--- | :--- |
| **Worker** | **Engineer Rover:** High HP, tethered build, active repair beam. | **Mule Engineer:** Unarmed hover drone, fire-and-forget nanite build. | **Scrapper Rig:** Fast wheeled truck, dismantles wrecks on-site into units. |
| **Core Infantry** | **Rifle Infantry:** Heavy ballistic rifle, Frag Grenade bunker breach. | **Vector Operator:** Rapid plasma carbine, high sprint, shield-capable. | **Ridge Ranger:** Trench shotgun & assault carbine, fast terrain traversal. |
| **Anti-Armor Infantry** | **Heavy AT Team:** Guided tandem-charge rockets, suppression-resistant. | **Ion Specialist:** Shield-piercing ion disruptor, overloads electronics. | **Tank Hunter:** Scavenged RPG swarm, cheap batch training. |
| **Marksman** | **Heavy Sniper:** High-caliber anti-materiel rifle, halts to aim. | **Phase Infiltrator:** Instant thermal beam, optic cloaking while stationary. | **Frontier Marksman:** Rugged hunting rifle, long sight range, spotter flare. |
| **Main Tank** | **Bastion Battle Tank:** Heavy 90mm cannon, smoke canisters, cast armor. | **Needle Skimmer:** Repulsor hover, rapid twin pulse lasers, regenerating shield. | **Outrider Technical:** Wheeled twin autocannons, high speed, flanking raider. |
| **Endgame Siege** | **Siege Colossus:** Deploys hydraulic anchors; crushing long-range splash. | **Prism Skimmer:** Continuous laser beam chaining to multiple adjacent targets. | **Battle Rig:** Armored flatbed with 4 firing garrison ports; fires on the move. |
| **Anti-Air Vehicle** | **Flak Halftrack:** Bursting flak clouds creating aerial denial zones. | **Skyward Array:** Guided ion pulses causing engine stall and flight wobble. | **SAM Outrider:** High-speed rocket buggy firing rapid unguided salvos. |
| **Specialist Walker** | **Bulwark Walker:** Frontal directional shield blocking incoming fire. | **Phase Lancer:** Short-range Phase Shift teleporting over cliffs & traps. | **Demolition Buggy:** High-speed suicide vehicle for breaking defensive lines. |
| **Air Superiority** | **Fighter Jet:** Runway taxi/takeoff, heavy cannons, air-to-air missiles. | **Talon Interceptor:** Hover flight, beam lasers, vertical climb/bank. | **Hornet Fighter:** Light prop fighter, low cost, swarm dogfighting. |
| **Strategic Air Strike**| **Heavy Bomber:** Carpet bombs structures and dense vehicle columns. | **Shrike Bomber:** Precision plasma torpedo strike with thermal shockwave. | **Buzzard Bomber:** Improvised fuel-air explosive payload. |

---

## 4. Exclusionary Tech Trees & Branching Doctrines

Superseding universal `weapons_1/2/3` and `armor_1/2/3` research paths, each faction gains access to **faction-exclusive branches** and **mutually exclusive Command Lab doctrines**:

### 4.1 Faction-Exclusive Upgrades
* **Bastion Directorate:**
  * *Reactive Composite Armor:* Reduces incoming small-arms and autocannon damage to vehicles by $25\%$.
  * *Tandem-Charge Warheads:* Rockets bypass vehicle armor plating for $+35\%$ damage.
  * *Automated Repair Cranes:* Doubles the simultaneous repair capacity of all Field Depots.
* **Helix Systems:**
  * *Harmonic Shield Resonators:* Increases shield capacity by $+30\%$ and cuts out-of-combat recharge delay from 5.0s to 3.0s.
  * *Coherent Beam Amplification:* Focused laser weapons ramp up damage the longer they remain locked onto a single target.
  * *Flux Capacitors:* Decreases weapon charge and ability cooldown times by $40\%$.
* **Free Frontier Coalition:**
  * *Scrap Cannibalization:* Engineers harvest $+50\%$ material from wrecks and instantly heal nearby friendly vehicles by 25 HP upon salvaging.
  * *High-Octane Superchargers:* Increases movement speed of all wheeled vehicles by $+18\%$.
  * *Concealed Claymores:* Doubles the explosion radius and damage of hidden proximity mines.

### 4.2 Mutually Exclusive Command Lab Doctrines

At the Command Lab tier, players must choose one of two permanent doctrinal paths:

```
┌────────────────────────────────────────────────────────────────────────┐
│                      BRANCHING DOCTRINES (TIER 2)                      │
├──────────────────┬─────────────────────────────┬───────────────────────┤
│ FACTION          │ DOCTRINE A                  │ DOCTRINE B            │
├──────────────────┼─────────────────────────────┼───────────────────────┤
│ Bastion          │ Fortress Doctrine           │ Iron Blitz            │
│                  │ (+30% structure HP, auto-   │ (+20% tank ram speed, │
│                  │ repairing bunkers, sandbag  │ fire on the move with │
│                  │ health doubled)             │ stabilizers)          │
├──────────────────┼─────────────────────────────┼───────────────────────┤
│ Helix            │ Phase Overload              │ Continuous Coherence  │
│                  │ (Shield breaks emit a blind-│ (Lasers chain to +2   │
│                  │ ing EMP flash; Phase Shift  │ targets; Prism towers │
│                  │ cooldown halved)            │ link range +50%)      │
├──────────────────┼─────────────────────────────┼───────────────────────┤
│ Frontier         │ Guerrilla Insurgency        │ Salvage War Machine   │
│                  │ (Infantry spawn from des-   │ (Destroyed enemy tanks│
│                  │ troyed buildings; mine count│ convert directly into │
│                  │ limit doubled)              │ Frontier buggies)     │
└──────────────────┴─────────────────────────────┴───────────────────────┘
```

---

## 5. Architectural Implementation in Godot 4

To implement this design cleanly without destabilizing the engine or breaking save persistence:

### 5.1 Componentized Units (`source/match/units/traits/`)
* **`ShieldComponent.gd`**: Manages shield HP, shield depletion state, damage interception, out-of-combat recharge timers, and visual shield shader effects.
* **`GarrisonMount.gd`**: Manages embarked unit slots, passenger damage mitigation, and passenger line-of-sight targeting while parent vehicle moves.
* **`AutonomousAssembly.gd`**: Enables worker disengagement immediately after spawning a construction foundation.

### 5.2 Roster Data Structure (`source/match/FactionCatalog.gd`)
* Replace static fallback dictionaries with modular `FactionRoster` resources.
* Each faction references its own bespoke `.tscn` unit scenes (e.g., `SiegeColossus.tscn`, `PrismSkimmer.tscn`, `BattleRig.tscn`), eliminating the 1:1 stat multiplier hack.

### 5.3 Skirmish AI Profiles (`source/match/players/skirmish-ai/`)
* **`BastionStrategy.gd`**: Prioritizes defensive choke points, builds bunkers near expansions, and rolls forward with deathballs escorted by repair rovers.
* **`HelixStrategy.gd`**: Leverages hover mobility, conducts multi-prong raids against resource lines, and kites backwards when shields collapse.
* **`FrontierStrategy.gd`**: Saturates the map with light raiders, lays ambush minefields along transit routes, and aggressively scavenges battle wrecks.

### 5.4 Save/Load Compatibility (`source/match/saves/`)
* All new unit traits (`ShieldComponent`, `GarrisonMount`) serialize state deterministically into `MatchSnapshot.gd`.
* Upgrades increment snapshot schema version while preserving backwards validation contracts.
