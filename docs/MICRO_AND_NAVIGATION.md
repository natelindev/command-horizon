# Tactical Micro-Control, Pathfinding & Formations Specification

Status: **Active Design Direction**  
Date: **2026-11-01**  
Foundation: Synthesized from RTS genre benchmarks (**StarCraft II**, **Age of Empires II**, and **Command & Conquer: Red Alert 2**) for **Command Horizon**.  
Supersedes: Single-point destination clustering, lack of tactical formations, desynchronized group march speeds, and clunky weapon wind-up stops during movement.

---

## 1. Executive Summary & Problem Diagnosis

In classical competitive and high-skill real-time strategy, **combat is won in the margins of micro-control and spatial positioning**:
* A player who manually dodges splash artillery or kites melee units with stutter-stepping can defeat an army twice their size.
* An army marching through a narrow canyon in a disciplined column survives, whereas an army clustering into a disorganized blob gets trapped and annihilated.

### 1.1 The Baseline Shortcomings in Command Horizon
1. **Blob Pathfinding (Deathballs):** Issuing a move order to a mixed group sends all units toward a tight cluster around the target coordinate. Units collide, circle each other via `RVO` avoidance, and clump into dense targets for artillery and bombers.
2. **Absence of Tactical Formations:** The player has no native buttons for **Line**, **Box**, **Flank**, or **Staggered** formations. Spreading units manually requires labor-intensive individual unit drag-selection.
3. **Speed Desynchronization:** Grouped units travel at their individual base speeds. Fast reconnaissance buggies and scout drones ($3.5\text{ m/s}$) race ahead into enemy fire, while heavy tanks ($2.9\text{ m/s}$) and siege artillery ($2.2\text{ m/s}$) trail far behind, destroying army cohesion.
4. **Stutter-Step & Fire Inelasticity:** Mobile combat units must come to a dead stop to fire (`Moving.gd` vs `AttackingWhileInRange.gd`). Restarting movement incurs navigation path queries, making tactical kiting feel unresponsive compared to the fluid stutter-stepping of StarCraft II.
5. **No Smart-Casting:** Activating an ability (e.g., Frag Grenade, Spotter Flare, EMP Rocket) across a multi-unit selection triggers the ability on *all* selected units simultaneously on the exact same coordinate, wasting valuable cooldowns.

---

## 2. Benchmark Lessons Matrix

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               BENCHMARK LESSONS MATRIX                                 │
├─────────────────┬────────────────────────────────────┬─────────────────────────────────┤
│ BENCHMARK GAME  │ CORE MECHANICS                     │ APPLICATION TO COMMAND HORIZON  │
├─────────────────┼────────────────────────────────────┼─────────────────────────────────┤
│ StarCraft II    │ • Instant turning & acceleration.  │ • Decouple turret aiming from   │
│                 │ • Fluid Stutter-Stepping (kiting). │   hull motion for smooth kiting.│
│                 │ • Smart-Casting (1 click = 1 cast).│ • Implement Smart-Cast ability  │
│                 │ • Local unit bumping & pushing     │   dispatching across groups.    │
│                 │   (heavier units nudge light).     │ • Heavy armor nudges infantry.  │
├─────────────────┼────────────────────────────────────┼─────────────────────────────────┤
│ Age of Empires  │ • 4 Formations: Line, Box, Flank,  │ • Add HUD buttons for Line,     │
│ II              │   Staggered.                       │   Box, Flank, and Staggered.    │
│                 │ • Split Micro (Flank formation     │ • Flank formation to dodge      │
│                 │   splits army to dodge catapults). │   incoming artillery/bombers.   │
│                 │ • Speed Matching / Group Cohesion. │ • Group cohesion march toggle   │
│                 │ • Stand Ground / Patrol stances.   │   (slowest unit pace).          │
├─────────────────┼────────────────────────────────────┼─────────────────────────────────┤
│ Red Alert 2     │ • Vehicle Crushing (tanks roll     │ • Heavy tanks physically crush  │
│                 │   over infantry).                  │   suppressed enemy foot troops. │
│                 │ • Deploy states (Siege Choppers,   │ • Explicit deployment delays    │
│                 │   Desolators, Prism Anchors).      │   for heavy siege platforms.    │
│                 │ • Drive-By Firing on the move.     │ • Gyro-stabilizers enable       │
│                 │                                    │   firing on the move.           │
└─────────────────┴────────────────────────────────────┴─────────────────────────────────┘
```

---

## 3. Tactical Formations Architecture

When multiple units are selected, the bottom console surfaces four distinct formation postures alongside a **Cohesion Toggle**:

```
                       ┌──────────────────────────────────────────────┐
                       │             TACTICAL FORMATIONS              │
                       └──────────────────────────────────────────────┘
                                      /        │        \
                                     /         │         \
                                    /          │          \
                     [ LINE FORMATION ]        │      [ FLANK / SPLIT ]
                     • Maximizes firing        │      • Splits army into two wings
                       broadside facing        │      • Leaves empty center corridor
                     • Tanks screen front;     │      • Primary counter to incoming
                       infantry reinforce rear │        artillery and carpet bombers
                                              / \
                                             /   \
                                            /     \
                       [ BOX / ESCORT ]            [ STAGGERED / SPREAD ]
                       • Perimeter heavy armor     • 2.5m open spacing between units
                       • Shelters fragile siege,   • Minimizes area splash damage
                         engineers, and heroes       from mortars, rockets & flak
```

### 3.1 Formation Specifications

1. **Line Formation (Default Frontline):**
   * *Geometry:* Units array in 2–3 ranks perpendicular to the movement heading.
   * *Layering:* Heavy tanks and brawlers take the vanguard; combat infantry form the second rank; fragile artillery and support units take the rear.
   * *Tactical Purpose:* Maximizes frontline fire coverage and presents uniform frontal armor to the enemy.
2. **Flank / Split Formation (Artillery & Bomb Evasion):**
   * *Geometry:* Instantly divides the selected group into two distinct wings separated by a $6.0\text{ m}$ central corridor.
   * *Tactical Purpose:* Directly counters incoming projectile artillery (Bastion Siege Colossus) and carpet bombers (Bombers/Airstrikes). When artillery shells are telegraphed, triggering Flank allows units to dodge outward without individual micro.
3. **Box / Escort Formation:**
   * *Geometry:* Combat armor forms an outer square ring with $1.5\text{ m}$ perimeter spacing.
   * *Interior Sanctuary:* High-value fragile units (Engineers, Repair Depots, Heroes, Artillery, Recon Drones) automatically slot into the protected center.
   * *Tactical Purpose:* Safely moving support convoys and siege engines across contested territory.
4. **Staggered / Spread Formation:**
   * *Geometry:* Hexagonal lattice distribution maintaining a loose $2.5\text{ m}$ buffer between every unit.
   * *Tactical Purpose:* Reduces casualty density from splash weapons, minefields, and autocannon flak clouds.

### 3.2 Cohesion & Speed-Matching Mode
* By default, units move at their individual speeds.
* Clicking the **Cohesion Mode** toggle (`HotKey: C`) forces all units in the current selection to match the movement speed of the slowest member in the formation (e.g., a fast escort screen of light technicals slows down to march in step with an advancing siege battery).

---

## 4. Pathfinding & Crowd Flow Dynamics

### 4.1 Formation Slot Projection (Hungarian Matching)
Instead of assigning navigation destinations in arbitrary selection order, group movement commands calculate destination slots using optimal distance projection:
* When a formation move is issued, slot coordinates are projected onto the navigation mesh based on the selected formation shape.
* The Hungarian (Kuhn-Munkres) assignment algorithm pairs each unit to its closest unique slot. This eliminates **path-crossing**, where units in the back crisscross through front units, stalling the column.

```
BAD (Selection Order):                 GOOD (Hungarian Slot Assignment):
Unit 1 (Left)  ───┐   ┌─── Slot 1 (Left)   Unit 1 (Left)  ─────────> Slot 1 (Left)
                  ╲ ╱                                                
                   ╳                       Unit 2 (Center)───────> Slot 2 (Center)
                  ╱ ╲                                                
Unit 2 (Right) ───┘   └─── Slot 2 (Right)  Unit 3 (Right) ────────> Slot 3 (Right)
(Units collide and stall)                   (Zero path crossings; smooth flow)
```

### 4.2 Local Physics: Nudging, Pushing & Infantry Crushing
* **Mass Hierarchy:** Units are categorized into three physical mass tiers:
  * *Light:* Foot infantry, scouts, drones.
  * *Medium:* Wheeled technicals, light tanks, combat walkers.
  * *Heavy:* Main battle tanks, siege colossi, heavy mobile rigs.
* **Non-Disruptive Nudging:** When a Heavy unit moves along a route occupied by a friendly Light unit, it does not stop or initiate a complete path recalculation. Instead, a local avoidance impulse gently nudges the Light unit perpendicular to the Heavy unit's trajectory.
* **Infantry Crushing (Red Alert 2 Rule):** If an enemy infantry unit is fully **Pinned** by suppression fire on open ground, an advancing Heavy Tank driving directly through its bounding circle inflicts instant crushing damage, adding lethality to combined-arms maneuvers.

### 4.3 Choke-Point Funneling
When approaching a narrow corridor (bridge, canyon, gate) whose width is narrower than the active formation:
1. Units dynamically compress their lateral formation width into a 1- or 2-column march.
2. Upon clearing the restriction, units automatically expand back out into their assigned formation footprint.

---

## 5. Micro-Control Mechanics & Combat Responsiveness

```
┌────────────────────────────────────────────────────────────────────────┐
│                        COMBAT MICRO MECHANICS                          │
├────────────────────┬───────────────────────────────────────────────────┤
│ MECHANIC           │ IMPLEMENTATION & BEHAVIOR                         │
├────────────────────┼───────────────────────────────────────────────────┤
│ Decoupled Turret   │ Vehicles rotate hulls toward movement targets     │
│ Aiming             │ while independent turrets maintain aim on hostile │
│                    │ targets, enabling true kiting / retreat firing.   │
├────────────────────┼───────────────────────────────────────────────────┤
│ Fluid Stutter-Step │ Attack intervals are split into Aim Wind-Up (0.1s)│
│ (Kiting)           │ and Weapon Cooldown. Issuing a move command during│
│                    │ cooldown cancels backswing without resetting DPS. │
├────────────────────┼───────────────────────────────────────────────────┤
│ Smart-Casting      │ Activating an ability (e.g. Grenade, EMP) on a    │
│ Dispatcher         │ multi-unit selection commands only the SINGLE     │
│                    │ closest unit in range to cast, preserving others. │
├────────────────────┼───────────────────────────────────────────────────┤
│ Tab Sub-Selection  │ Pressing Tab cycles through unit classes within a │
│ Cycling            │ mixed selection, instantly updating the HUD       │
│                    │ ability tray without clearing group orders.       │
├────────────────────┼───────────────────────────────────────────────────┤
│ Focus-Fire Target  │ Holding Alt + Right Click commands all units to   │
│ Priority           │ focus fire exclusively on the target, ignoring    │
│                    │ intermediate targets even if attacked.            │
└────────────────────┴───────────────────────────────────────────────────┘
```

### 5.1 Fluid Stutter-Stepping (Kiting)
* In the baseline code, issuing a move command while firing cancels the attack and requires a complete re-aiming cycle upon stopping.
* *The Solution:* Weapon cadence is broken down into two distinct phases:
  1. **Aim & Fire Phase ($0.1\text{--}0.2\text{s}$):** The unit must face the target and fire the round.
  2. **Recoil & Cooldown Phase ($0.6\text{--}1.5\text{s}$):** The weapon is reloading. The unit is free to move at full speed without penalty.
* Skilled players can issue: **Attack $\rightarrow$ Move $\rightarrow$ Attack $\rightarrow$ Move** to kite backwards, maintaining full damage output while staying outside the range of slower adversaries.

### 5.2 Smart-Casting Across Multi-Unit Selections
* When an active ability (e.g., `Frag Grenade [Q]`, `Spotter Flare [E]`, `Phase Shift [R]`) is triggered:
  * The selection manager evaluates all selected units that possess the ability and are off cooldown.
  * It filters for the unit closest to the target coordinate.
  * It commands **only that single unit** to execute the ability.
  * The rest of the group continues their existing move or attack orders uninterrupted.

---

## 6. Multi-Stage Implementation Plan

### Stage 1 — Formation Slot Geometry & HUD Postures
* Create `source/match/orders/FormationPlanner.gd`: calculates slot offsets for **Line**, **Box**, **Flank**, and **Staggered** formations based on unit radius and count.
* Add formation posture icons and hotkeys (`Z, X, Alt+C, V`) to the bottom console HUD in `UnitMenus.gd`.
* Wire Hungarian slot assignment to eliminate path crossing during group moves.

### Stage 2 — Group Cohesion & Speed Synchronization
* Implement `CohesionMode` in `ManualOrders.gd`:
  * Computes `min(unit.movement_speed)` across the active selection.
  * Clamps individual group velocities to this minimum speed when cohesion is enabled.
  * Add Cohesion toggle button (`[C]`) to HUD selection band.

### Stage 3 — Decoupled Turret Aiming & Stutter-Step Responsiveness
* Update `ChassisMotion.gd` and `TurretAim.gd`:
  * Turrets maintain independent world-space rotation toward hostile targets within arc limits while chassis rotates along navigation path.
  * Refactor `AttackingWhileInRange.gd` into explicit wind-up and cooldown states, permitting move commands during cooldown without resetting reload progress.

### Stage 4 — Smart-Cast Ability Dispatcher
* Update `source/match/units/traits/UnitAbilities.gd`:
  * Intercept multi-selection ability calls.
  * Route target order to the single nearest eligible candidate.
  * Display individual cooldown feedback on the active HUD ability card.

### Stage 5 — Mass Hierarchy, Nudging & Choke Funneling
* Define mass classes (`LIGHT`, `MEDIUM`, `HEAVY`) in `UnitMotionProfile.gd`.
* Add gentle lateral collision impulses when Heavy units pass Light allies.
* Implement corridor constriction checks in `Movement.gd` to dynamically funnel wide formations into columns through narrow passes.

### Stage 6 — Headless Verification, Regressions & Performance
* Add automated headless test suite `tests/headless/TacticalFormationsRegression.gd`:
  * Verify Hungarian slot assignment zero-crossing.
  * Verify Flank formation corridor clearance.
  * Verify Smart-Cast single-unit ability consumption.
* Benchmark 200-unit formation moves under physics interpolation to guarantee $\le 16.6\text{ ms}$ frame budgets.

---

## Agent Progress

- **Benchmark Synthesis Completed**: Evaluated micro-control and movement mechanics from StarCraft II (stutter-stepping, smart-casting, local nudging), Age of Empires II (Line/Box/Flank/Staggered formations, speed cohesion, dodging), and Red Alert 2 (turret decoupling, deploy delays, vehicle crushing).
- **Core Diagnosis Established**: Identified existing limitations in Command Horizon (deathball clustering, absence of formations, speed desync, lack of smart-cast, clunky weapon wind-ups).
- **Comprehensive Specification Authored**: Created `docs/MICRO_AND_NAVIGATION.md` defining the 4 tactical formation geometries, Hungarian slot assignment, decoupled turret aiming, fluid stutter-step cooldowns, smart-cast dispatching, and a 6-stage engineering plan.

- **2026-11-02 — Runtime implementation verified:** All four geometries, projected Hungarian assignment, direct HUD controls, live cohesion (including formation cruise), turret decoupling,0.12s aim/reload preservation, one-unit smartcasting, Tab/Alt focus, mass contacts and actual choke compression/re-expansion pass current native runtime checks. C is reserved for cohesion; Flank uses configurable Alt+C so the specification’s two C commands remain directly accessible. Evidence: [runtime and bilingual review](playtests/2026-11-02/tactical-formations/). The strict200-unit16.6ms command/maximum-frame performance gate remains open and is being optimized; p95 is not substituted for that requirement.
