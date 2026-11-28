# Macro Economy & Risk-the-Batch Refining Specification

Status: **Active Design Direction (v2 — Risk-the-Batch Refining)**  
Date: **2026-11-27**  
Supersedes: The v1 dual-pile economy where `Materials` (`resource_a`) and `Electronics` (`resource_b`) were both harvested identically from static ground deposits.

---

## 1. Executive Summary & Why We Are Pivoting

Command Horizon's v1 macro overhaul established strong asymmetric foundations—faction-distinct harvesters (`HarvestingProfile.gd`), Bastion's `ForwardRefinery`, Helix's phase delivery, Frontier's wreck salvage (`WreckSalvage.gd`), field saturation (`ResourceUnit.gd`), and active power brownouts (`PowerGrid.gd`).

However, the **resource layer itself** still felt generic compared to iconic RTS economies:
- **Identical harvesting verbs:** `Materials` (`ResourceA`) and `Electronics` (`ResourceB`) sat in mirrored StarCraft-style 9 m arcs (`LegacyHomeFields.gd`) and used the exact same gather-and-return loop.
- **Inert battlefield presence:** Deposits were passive, risk-free counters on the floor with no combat interplay, scouting tells, or raiding drama.
- **Derivative feel:** Simply adding bigger trucks or regrowing crystals would only mimic Red Alert 2 / C&C Tiberium rather than giving Command Horizon its own economic identity.

### The New Core Fantasy: **Risk-the-Batch Refining**
1. **One Raw Map Resource:** Maps contain a single harvestable base resource—**Raw Materials** (`resource_a`)—keeping terrain readable and expansion decisions crisp.
2. **High-Tech Must Be Refined Under Risk:** **Refined Cores** (`resource_b`, replacing mined Electronics) are **never** gathered from safe starting piles. Players must actively convert Raw into Refined through **faction-unique, exposed refining processes** where committed wealth is physically vulnerable on the battlefield.
3. **Raiding Is a Heist:** Destroying an enemy refiner mid-cycle detonates the active batch and **spills lootable Refined Core canisters** onto the ground that *any* faction can claim.
4. **Late-Game Tech Evolves the Rules:** Tier-2 and Tier-3 technologies in the Command Lab / Signal Lab / Scrap Yard—plus each faction's mutually exclusive Doctrines—upgrade and transform how each faction manages refining risk, speed, and battlefield synergy.

---

## 2. Two-Currency Architecture & Pacing Calibration

Existing HUD counters, unit costs (`FactionRules.gd`), and snapshot keys (`player.resource_a`, `player.resource_b`) remain intact—only their acquisition rules and labels evolve.

| Currency | Internal Key | Map Source | Primary Role |
| :--- | :--- | :--- | :--- |
| **Raw Materials (M)** | `resource_a` | Harvested from map fields (`ResourceA`), basic wrecks, and Catalyst POIs. | Workers, Tier-1 infantry, Power Plants, Barracks, basic defenses, **Tier-1 Refiners**, and feedstock for refining. |
| **Refined Cores (R)** | `resource_b` | **Manufactured** from Raw via faction refiners; stripped from high-tech wrecks (Frontier); looted from spilled canisters or contested Catalyst POIs. | Vehicle/Aircraft Factories, Labs, Tier-2/3 combat units, Heroes, research upgrades, doctrines, and programmable chips. |

### 2.1 Bootstrap & Anti-Deadlock Guarantees
- **Every Tier-1 refining structure/unit costs `0 Refined`** (pure Raw) so a player can never be soft-locked out of high-tech production.
- **Skirmish Starting Stockpiles (`Skirmish.gd`):**
  - *Standard Start:* `80 Raw / 8 Refined` (enough to open Barracks + Power + first Refiner immediately, with a small 8 Refined reserve for an early Rocket/Assault squad or faster Vehicle Factory).
  - *Advanced Start:* `140 Raw / 40 Refined` (plus 1 pre-built faction Refiner).
- **Skirmish Map Field Unification (`LegacyHomeFields.gd` & `ResourceFieldStocks.gd`):**
  - Remove `ResourceB` piles from skirmish home and expansion arcs, replacing them with unified **Raw Materials** fields so every home base has `6` Raw piles (`6 × 650 = 3,900 Raw`) and expansions carry `6–7` Raw piles (`950–1,250 Raw` each).
  - *Compatibility note:* `ResourceB.gd` / `ResourceB.tscn` remain loadable for legacy Campaign missions until migrated separately.
- **Throughput Target:**
  - Standard early-mid Raw harvest with 8–10 workers produces `~5.0–6.0 Raw/s`.
  - A single active Tier-1 refiner converts roughly `2.0 Raw/s` into `0.75–1.35 Refined/s` depending on faction risk tier—matching the original `ResourceB` pacing (`~1.6–2.0/s` with 2 active refiners) so existing unit/research prices in `FactionRules.gd` and `TechnologyCatalog.gd` stay balanced without a full roster re-price.

---

## 3. Faction-Distinct Refining Engines

```
                       ┌───────────────────────────────────────────────┐
                       │      FACTION RISK-THE-BATCH REFINING          │
                       └───────────────────────────────────────────────┘
                                  /            │            \
                                 /             │             \
              BASTION DIRECTORATE         HELIX SYSTEMS        FREE FRONTIER COALITION
             "Industrial Smelting"    "Harmonic Condensing"     "Nomad Crack-Rigs &
              • Armored Kilns          • Continuous Siphon       Combat Piracy"
              • Upfront Batch Lock     • Hold for Multiplier    • Mobile Refiner Truck
              • Bigger Batch = Better    (T1 -> T2 -> T3 -> T4) • Faster Near Wrecks
                Conversion Ratio       • Power-Grid Dependent   • Strips Tech Wrecks
              • Field-Fed Bonus          (Brownout Bleed-Off)     Directly Into Cores
              • Thermal Rupture Risk   • EMP Shockwave Risk     • Fuel-Air Bomb Risk
```

---

### 3.1 Bastion Directorate — Industrial Batch Smelting
*Fantasy: Heavy diesel-punk commitment—lock in a massive molten batch, fortify the kiln, and crush the enemy with industrial scale.*

- **Structure — Industrial Smelter (evolves `ForwardRefinery`):**
  - Cost: **`35 Raw / 0 Refined`** | Build time: `18s` | Power usage: **`3 Power`** | HP: `420` (Bastion armor bonus applies).
  - Retains `ForwardRefinery`'s worker drop-off role and `+15%` Raw smelting yield bonus.
- **Refining Mechanic — Escalating Batch Commitment:**
  - Player selects a batch tier (with **Auto-Cycle** enabled by default so macro never requires tedious re-clicking). Upfront Raw is locked inside the furnace at cycle start:

| Batch Tier | Unlock | Upfront Raw | Refined Output | Base Time | Ratio (Raw:Ref) | Base Rate |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **Standard Batch** | Default | `30` | `12` | `15s` | `2.50 : 1` | `0.80 R/s` |
| **Heavy Batch** | Default | `60` | `30` | `30s` | `2.00 : 1` | `1.00 R/s` |
| **Super-Heavy Batch** | `pressurized_furnaces` (T2) | `100` | `60` | `42s` | `1.67 : 1` | `1.43 R/s` |

- **Operational Modifiers & Anti-Turtle Incentive:**
  - **Field-Fed Bonus (`+20%` speed):** Active whenever a Bastion harvester has dropped off Raw at this Smelter within the last `15s`, encouraging Bastion to place fortified smelting hubs right next to forward Raw fields instead of hiding them in a back corner.
  - **Overpressure Toggle (`+30%` speed):** Draws **`+4` extra Power** while active. After the boosted batch completes, Overpressure enters a `15s` thermal cooldown (removed by `iron_blitz`).
- **Risk, Abort & Counterplay:**
  - **Visual Tell:** Furnace grates glow brighter orange and exhaust stacks vent thicker diesel smoke/sparks as the batch progresses (super-heavy batches emit a white-hot slag flare).
  - **Emergency Slag Dump (Abort):** Instant cancel; recovers **`50%` Raw** (`80%` with `pressurized_furnaces`) and `0 Refined`.
  - **Destruction Mid-Batch:** Molten rupture deals `45` thermal splash damage in a `3.5 m` radius (damaging clustered buildings/units) and spills **`45%`** of accrued Refined progress as pickup canisters.

---

### 3.2 Helix Systems — Harmonic Capacitor Condensing
*Fantasy: High-wire cybernetic greed—ride an escalating plasma multiplier while keeping your Power Grid spotless.*

- **Structure — Phase Condenser (new Helix-exclusive structure, `PhaseCondenser.tscn`):**
  - Cost: **`35 Raw / 0 Refined`** | Build time: `18s` (autonomous nanite build) | Power usage: **`4 Power`** | HP: `160` hull + `140` shield (with `failsafe_capacitors`, `160` hull / `80` base shield before).
  - **Anti-Turtle Spacing Rule:** Minimum **`8 m`** spacing from any other friendly Phase Condenser (harmonic interference prevents stacking them under a single turret dome).
- **Refining Mechanic — Continuous Siphon & Escalating Discharge:**
  - While active, a Phase Condenser continuously siphons **`2.0 Raw/s`** into a visible floating cyan energy ring above the spire (pauses cleanly if Raw reaches `0`, resuming without losing accrued tier).
  - Player chooses an **Auto-Discharge** target (`T1`, `T2`, `T3`, or `T4` once unlocked) or hits **Discharge Now** manually at any moment to bank Refined Cores at the highest completed tier multiplier (partial progress above a tier pays at the lower tier's ratio):

| Resonance Tier | Charge Time | Raw Siphoned | Refined Yield | Multiplier | Ratio (Raw:Ref) | Avg Rate |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Tier 1 (Safe)** | `15s` | `30` | `12` | `1.00×` | `2.50 : 1` | `0.80 R/s` |
| **Tier 2 (Charged)** | `30s` | `60` | `32` | `1.33×` | `1.88 : 1` | `1.07 R/s` |
| **Tier 3 (Resonant)** | `45s` | `90` | `60` | `1.67×` | `1.50 : 1` | `1.33 R/s` |
| **Tier 4 (Over-Resonance)** | `60s` *(requires `harmonic_lattice`)* | `120` | `100` | `2.08×` | `1.20 : 1` | `1.67 R/s` |

- **Risk, Power Grid Interaction & Counterplay:**
  - **Visual Tell:** Levitating crystal ring rises and accelerates across tiers; at **Tier 3+**, the spire emits a tall cyan/violet vertical beam visible even at camera edge so enemies can spot greedy holds.
  - **Brownout Instability:** Requires uninterrupted Power Grid surplus/balance. If an enemy snipes Flux Generators and triggers **Brownout**, every charging Condenser immediately bleeds charge at `-12%/s` and cancels after `2.0s` (dumping 0 Refined unless manually discharged first). With Tier-2 `failsafe_capacitors`, Condensers gain a **`6.0s` emergency buffer** with red alarm pulses so Helix can trigger `Grid Surge` or cash out safely.
  - **Destruction While Charged:** Unleashes an **EMP shockwave** (`4.5 m` radius, drains shields and stalls nearby engines for `1.5s`) and scatters **`45%`** of its current Refined value as pickup Phase Cores.

---

### 3.3 Free Frontier Coalition — Mobile Crack-Rigs & Combat Piracy
*Fantasy: Guerrilla survivalists who refuse to sit still—hide roving distillers in canyons, strip enemy elite wrecks on the front line, and steal everyone else's cores.*

Frontier has **no static Tier-1 refinery structure**. Instead, they combine three scrappy channels:

#### A. Crack-Rig (Mobile Refiner Truck, `CrackRig.tscn`)
- **Production:** Trained directly at the **`CommandCenter`** (zero tech deadlock) for **`28 Raw / 0 Refined`**, `12s` train time, `1` population, `95 HP`, wheeled mobility, unarmed.
- **Deploy & Distill:**
  - Deploy time: `1.5s` | Pack-up time: **`2.0s`** (`0.5s` with `exhaust_scrubbers`).
  - While deployed, runs fast auto-repeating bursts: **`24 Raw → 12 Refined` in `16s`** (`2.00 : 1` ratio, `0.75 R/s`).
  - **Hot-Zone Bonus (`+40%` speed → `11.4s`, `1.05 R/s`):** Automatically triggers when deployed within **`10 m`** of a fresh battlefield wreck, active Raw field, or neutral Catalyst POI—tempting Frontier out onto contested ground.
- **Risk & Counterplay:**
  - **Visual Tell:** Emits a tall, unmistakable **black smoke plume and exhaust flare** while distilling (suppressed for the first `75%` of each cycle after `exhaust_scrubbers`).
  - **Rolling Fuel-Air Bomb:** Packing up aborts the active burst (`50%` Raw refund). If destroyed while deployed and distilling, the tanker detonates in a **fuel-air blast** (`40` splash damage in `4.0 m` radius) and drops **`45%`** of accrued Refined progress as pickup canisters.

#### B. High-Tech Wreck Stripping (Frontline Combat Refining)
- Extends `SalvageRules.gd` and `WreckSalvage.gd`:
  - Any destroyed vehicle, aircraft, or tech structure whose cost included `Refined > 0` leaves a **Hot Tech Wreck** carrying **`35%` Raw AND `40%` Refined** of its original cost (180s lifetime).
  - Frontier Scrapper Rigs dismantle wrecks **on-site** for immediate `Raw + Refined` without returning to HQ.
  - *Example:* Destroying a Bastion Siege Colossus (`40 M / 18 R`) or Helix Prism Skimmer (`36 M / 22 R`) drops `7–9` instant Refined Cores right on the battlefield for Frontier to scoop up.

#### C. Black Market Fence (Emergency Fallback)
- Built into Frontier's **Scrap Yard (`CommandLab`)**: direct one-click exchange **`40 Raw → 10 Refined`** (`4.0 : 1` steep penalty, `25s` cooldown) so Frontier can always rebuild momentum even if every Crack-Rig is hunted down.

---

## 4. Spilled Core Canisters & Neutral Catalyst Objectives

### 4.1 Spilled Refined Core Canisters (Shared Raid Payoff)
- Implemented on top of `TacticalCargo.gd` (`kind = "refined_core"`).
- **Drop Formula:** When any active Smelter, Phase Condenser, or deployed Crack-Rig is destroyed with `>= 20%` batch/charge progress, it scatters `1–3` glowing **Refined Core Canisters** totaling **`floor(accrued_refined_value * 0.45)`** (minimum `4 Refined`).
- **Claim Rules:** Any friendly or hostile ground unit (combat unit or worker) moving within `1.2 m` claims a canister in `0.5s` for immediate `player.resource_b += amount`, accompanied by a crisp pickup chime and floating `+R` indicator.
- **Decay:** Unclaimed canisters stabilize and expire after `90s`.

### 4.2 Neutral Catalyst Map POIs (`PointOfInterestCatalog.gd`)
Neutral objectives reinforce the refining economy instead of bypassing it:
- **Catalyst Refinery (`TechRefinery`):**
  - Capture bounty: `+25 Raw / +15 Refined`.
  - Passive trickle: `+2 Raw / +1 Refined` every `4s`.
  - **Catalyst Aura (`12 m` radius):** Grants **`+20%` refining speed** to any nearby Bastion Smelter, Helix Condenser, or deployed Frontier Crack-Rig.
- **Orbital Relay (`DataRelay`):**
  - Grants periodic radar sweep AND every **`60s`** ejects a contested **Refined Core Canister (`+15 Refined`)** onto its landing pad—creating recurring mid-map skirmishes.

---

## 5. Late-Game Refining Technologies & Doctrine Synergies

Every faction receives **two dedicated refining technologies** (Tier 2 Mid-Game Safety/Scaling + Tier 3 Late-Game Rule-Breaker) in `TechnologyCatalog.gd`, plus direct synergies with their existing mutually exclusive Doctrines in `FactionDoctrineEffects.gd`.

### 5.1 Dedicated Refining Research Tree

| Faction | Tech ID & Title | Tier & Prereq | Cost (M / R) | Time | Gameplay Effect |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **Bastion** | `pressurized_furnaces` — **Pressurized Blast Furnaces** | T2 (`coordination`) | `40 / 25` | `35s` | Unlocks **Super-Heavy Batch** (`100 M → 60 R / 42s`). Emergency Abort recovers `80%` Raw (up from `50%`), and cooking Smelters take `25%` less splash damage. |
| **Bastion** | `slag_recirculation` — **Slag Heat Recirculation** | T3 (`pressurized_furnaces`) | `60 / 40` | `45s` | Finishing any Smelter batch surges adjacent Factories (`8 m`) by **`+25%` production speed for `15s`**, and Smelters auto-siphon Raw from adjacent `ForwardRefinery` drop-offs. |
| **Helix** | `failsafe_capacitors` — **Fail-Safe Capacitor Buffers** | T2 (`coordination`) | `40 / 25` | `35s` | Phase Condensers gain `+60` Plasma Shield capacity and a **`6.0s` brownout grace buffer** (flashing red warning instead of immediate bleed-off) so Helix can trigger `Grid Surge` or manually discharge. |
| **Helix** | `harmonic_lattice` — **Harmonic Lattice** | T3 (`failsafe_capacitors`) | `60 / 45` | `45s` | Two Phase Condensers within `14 m` beam-link into a **Lattice**, unlocking **Tier 4 Over-Resonance (`120 M → 100 R / 60s`)** and radiating a `+6 HP/s` shield aura to nearby Helix units at T3+. *Catch: destroying either partner shocks the other down 1 tier and spills bonus Phase Cores.* |
| **Frontier** | `exhaust_scrubbers` — **Exhaust Scrubbers & Quick-Hitch** | T2 (`coordination`) | `35 / 20` | `30s` | Crack-Rig pack-up time drops from **`2.0s → 0.5s`**, pops a brief **smoke-screen burst** when packing up under fire, and suppresses the black smoke plume until the final `25%` of distillation. |
| **Frontier** | `battlefield_alchemy` — **Total Battlefield Alchemy** | T3 (`exhaust_scrubbers`) | `55 / 35` | `40s` | **Tier-1 wrecks and collapsed structure ruins** now also yield Refined Cores (`+4` to `+8 R`) when stripped. Unlocks **Fuel Injection** on Crack-Rigs: expend a ready batch on the front line to grant nearby Frontier vehicles (`9 m`) **`+25%` speed and fire rate for `15s`**. |

### 5.2 Existing Doctrine Synergies (`FactionDoctrineEffects.gd`)

| Faction | Doctrine | Refining Synergy |
| :--- | :--- | :--- |
| **Bastion** | **Fortress Doctrine** | Smelters gain `+30%` max HP and auto-repair (`4 HP/s`) between active batches. |
| **Bastion** | **Iron Blitz** | Smelter **Overpressure** has `0s` cooldown and costs no extra Power while active. |
| **Helix** | **Phase Overload** | Discharging a Tier 2+ Phase Condenser emits an allied pulse (`10 m`) that tops off shields and resets `Phase Shift` cooldowns. |
| **Helix** | **Continuous Coherence** | Linked Condensers extend **Prism Pylon link range** by `50%` and siphon Raw even while a Nexus is under attack. |
| **Frontier** | **Guerrilla Insurgency** | A Crack-Rig destroyed mid-distillation triggers a **double-damage fuel-air ambush blast** (`80` dmg, `5.5 m`) and spawns `2` ambush Riflemen from the wreck. |
| **Frontier** | **Salvage War Machine** | Stripping enemy Tier-2/3 wrecks yields **`+50%` bonus Refined Cores**, and a deployed Crack-Rig with a ready batch can **field-assemble an Outrider or Demolition Buggy** on the spot. |

---

## 6. Preserved Core Macro Pillars

The following v1 pillars remain active and integrate directly with the refining economy:
1. **Active Power Grid (`PowerGrid.gd`):**
   - `SURPLUS` / `BALANCED` / `BROWNOUT` (`demand > supply`).
   - Brownouts shut down defensive turrets, disrupt minimap radar, slow shield regen by `50%`, slow production/research to `25%`, halt Bastion Overpressure, and destabilize Helix Phase Condensers.
   - Power Plants retain the **Grid Surge (`+50%` output for `30s`, `10s` cooldown)** emergency ability—now vital for saving Helix Condensers or powering Bastion Overpressure.
2. **Asymmetric Harvesters (`HarvestingProfile.gd`):**
   - **Bastion Mule Hauler:** Heavy armor (`120 HP`), out-of-combat self-repair (`1.5 HP/s`), doubled cargo (`8 Raw`), triggers Smelter Field-Fed bonus on delivery.
   - **Helix Flux Skimmer:** Hover movement over rough terrain/shallow water, `Phase Teleport` delivery back to Nexus HQ (`1.2s` channel).
   - **Frontier Scrapper Rig:** Armed with `20mm` defense autocannon, strips Hot Tech Wrecks directly into `Raw + Refined` on the front line.
3. **Field Saturation & Depletion (`ResourceUnit.gd`):**
   - Visible field saturation (`Optimal: 2/node`, `3rd worker: 60%`, `4th+: waiting`).
   - Home Raw fields exhaust after ~7–9 minutes of sustained production, forcing expansion onto contested fields to keep feeding refiners.
4. **Faction Macro Abilities (`MacroEconomy.gd`):**
   - Bastion: **Industrial Overhaul** (`+30%` Raw harvesting on targeted field for `30s`).
   - Helix: **Flux Resonance** (`+50%` factory/lab speed for `25s`, `25` Nexus Energy).

---

## 7. Bottom HUD, Diegetic Feedback & Art Contracts

All UI and art additions follow `AGENTS.md` contracts:
- **Bottom HUD Only (Zero Floating Windows / Nested Menus):**
  - Selecting a refiner immediately surfaces its direct one-click controls in the bottom command panel, with clear icons, costs/ratios, and tooltips:
    - **Bastion Smelter:** `[Small 30→12] [Heavy 60→30] [Super 100→60*] [Overpressure] [Auto-Cycle] [Abort Dump]`
    - **Helix Phase Condenser:** `[Auto T1] [Auto T2] [Auto T3] [Auto T4*] [Discharge Now]`
    - **Frontier Crack-Rig:** `[Deploy & Distill] [Pack Up] [Fuel Inject*]`
  - Build menu shortcuts act directly on visible tabs (e.g., Bastion Smelter / Helix Phase Condenser in Infrastructure; Frontier Crack-Rig at CommandCenter).
- **Diegetic World Readability:**
  - Every refiner displays progress in 3D space (Bastion furnace glow + smoke density; Helix levitating crystal ring height + Tier 3/4 vertical beam; Frontier smoke plume + pressurized tank gauge) plus a crisp progress/tier bar when hovered or selected.
  - Spilled Refined Core canisters use a distinct glowing beacon/model so players spot heist opportunities immediately.
- **Asset & Localization Pipeline:**
  - New models (`PhaseCondenser`, `CrackRig`, `RefinedCoreCanister`) must be authored via `art/<faction>/build_*.py` using `art/common/weathering.py` (never edit `.glb` directly) and verified with `tests/rendered/WeatheringPreview.gd`.
  - All new strings go into `art/localization/*.tsv` followed by `python3 art/localization/build_catalog.py` (never edit `assets/translations/ui.csv`).
  - HUD layouts verified across all three factions with `tests/rendered/HudConsolePreview.gd` (run without `--headless`).

---

## 8. Staged Implementation & Verification Plan

### Stage 1 — Refining Runtime Core & Spilled Core Canisters
- Add `source/match/economy/RefiningProfile.gd` (pure balance constants, batch tables, tier multipliers, and deterministic tick helpers—no autoload preloads).
- Add `source/match/units/traits/RefiningComponent.gd` managing active batch/charge state, auto-cycle/auto-discharge settings, brownout handling, abort refunds, and mid-cycle destruction rupture/spill.
- Extend `source/match/world/TacticalCargo.gd` (and manager) to spawn and claim `refined_core` canisters on refiner destruction and `DataRelay` periodic ejections.
- Update `source/match/economy/PowerGrid.gd` to account for Bastion Overpressure draw and notify Helix Condensers on Brownout transitions.

### Stage 2 — Faction Refiners & Frontier Tech-Wreck Stripping
- **Bastion:** Upgrade `source/match/units/ForwardRefinery.gd` / `.tscn` with `RefiningComponent` (`35 Raw / 0 Refined`, `3 Power`), Field-Fed proximity tracking, Overpressure toggle, and thermal rupture FX.
- **Helix:** Add `source/match/units/PhaseCondenser.gd` / `.tscn` (`35 Raw / 0 Refined`, `4 Power`), `8 m` placement spacing validator, continuous Raw siphon, Tier 1–4 discharge logic, lattice beam-linking, and EMP shockwave FX.
- **Frontier:** Add `source/match/units/CrackRig.gd` / `.tscn` (trained at `CommandCenter`, `28 Raw / 0 Refined`), deploy/pack-up state machine, Hot-Zone bonus detection, smoke plume FX, and fuel-air detonation.
- Upgrade `source/match/economy/SalvageRules.gd`, `WreckSalvage.gd`, and `source/match/units/non-player/Wreck.gd` to store and award both `resource_a` and `resource_b` on Hot Tech Wrecks, plus add Scrap Yard Black Market Fence action.

### Stage 3 — Map Unification & Catalyst POIs
- Update `source/match/economy/LegacyHomeFields.gd` and `ResourceFieldStocks.gd` to generate unified Raw-only skirmish fields (`6 × 650 Raw` at home, `6–7 × 950–1,250 Raw` at expansions) while preserving Campaign `ResourceB` compatibility.
- Update `source/match/Skirmish.gd` starting stockpiles (`80 Raw / 8 Refined` standard; `140 Raw / 40 Refined` + 1 refiner advanced).
- Upgrade `source/match/world/PointOfInterest.gd` so `TechRefinery` provides the `12 m` `+20%` Catalyst Aura and `DataRelay` ejects a `+15 Refined` canister every `60s`.

### Stage 4 — Late-Game Refining Technologies & Doctrine Hooks
- Add the 6 refining technologies (`pressurized_furnaces`, `slag_recirculation`, `failsafe_capacitors`, `harmonic_lattice`, `exhaust_scrubbers`, `battlefield_alchemy`) to `source/match/research/TechnologyCatalog.gd` and `TechnologyResearch.gd`.
- Implement the 6 doctrine refining synergies in `source/match/research/FactionDoctrineEffects.gd` and `RefiningComponent.gd`.

### Stage 5 — Bottom HUD Controls, Diegetic FX & Art Pipeline
- Expose direct one-click refiner controls and tooltips in `source/match/hud/` following `AGENTS.md` (no floating menus, keyboard shortcuts preserved).
- Author `PhaseCondenser`, `CrackRig`, and `RefinedCoreCanister` models in `art/<faction>/build_*.py` + localization entries in `art/localization/*.tsv` (`python3 art/localization/build_catalog.py`).
- Verify visual quality with `tests/rendered/HudConsolePreview.gd` and `tests/rendered/WeatheringPreview.gd` (without `--headless`).

### Stage 6 — AI, Deterministic Saves & Regression Suite
- Update `source/match/players/skirmish-ai/` faction strategies:
  - Bastion AI builds Field-Fed Smelters, scales from Standard → Heavy → Super-Heavy batches, and fortifies smelting hubs.
  - Helix AI spaces Phase Condensers `>= 8 m`, pairs them for `harmonic_lattice`, protects Power Plants, and emergency-discharges during brownouts.
  - Frontier AI trains Crack-Rigs, deploys near Hot-Zones, packs up under threat, aggressively strips tech wrecks, and raids enemy refiners to grab spilled canisters.
- Bump `MatchSnapshot.VERSION` (`22 → 23`) in `source/match/saves/MatchSnapshot.gd` to deterministically serialize refiner state (active mode, progress, auto-cycle/tier, grace timer, spilled canisters, hot wreck `resource_b`), and convert archived saves in `docs/playtests/` and `tests/fixtures/` while preserving unit/resource IDs.
- Add headless contract coverage in `tests/headless/MacroEconomyRegression.gd` (using runtime `load()`, never top-level `preload()`, for autoload-touching `source/` scripts) verifying:
  - Bootstrap buildability (`0 Refined` refiner cost for all 3 factions)
  - Batch conversion math, Field-Fed / Hot-Zone / Lattice multipliers, and abort refunds
  - Helix Brownout bleed-off vs. `failsafe_capacitors` 6s grace buffer
  - Mid-cycle destruction blast, `45%` Refined Core canister spill, and cross-faction pickup
  - All 6 refining techs, 6 doctrine synergies, and exact save/load round-trip determinism.
