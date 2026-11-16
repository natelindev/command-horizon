# Tiers 1, 3, and 4 RTS Polish Implementation Plan

A comprehensive overhaul implementing **Tier 1 (Input, Micro & Controls)**, **Tier 3 (Standard UI & HUD)**, and **Tier 4 (Programmable RTS USP)** to transform Command Horizon into a responsive, tactical, and readable RTS experience.

---

## Part I: Tier 1 — Input, Micro & Controls

### Stage 1: Formations & Drag-to-Face Directional Move
1. Extend `source/match/utils/UnitMovementUtils.gd`:
   - Implement `calculate_formation_slots(units, target_center, facing_direction, formation_type, spacing)`.
   - Support `line` (rank-and-file abreast), `wedge` (V-arrowhead), and `staggered` (spread out against AoE/artillery).
2. Update `source/match/Terrain.gd` & `MatchSignals.gd`:
   - Detect right-click drag (> 15 px distance).
   - On release, emit `MatchSignals.terrain_targeted_with_heading(target_point, facing_vector)`.
3. In `source/match/players/human/UnitActionsController.gd`:
   - Dispatch units to formation-slotted destinations oriented along the drag facing vector.

### Stage 2: Tactical Unit Stances
1. In `source/match/units/Unit.gd`:
   - Define `enum Stance { AGGRESSIVE, DEFENSIVE, HOLD_POSITION, HOLD_FIRE }`.
   - Add property `stance = Stance.AGGRESSIVE`.
2. Update `source/match/units/actions/WaitingForTargets.gd` and auto-attack logic:
   - `HOLD_FIRE`: Suppress auto-target acquisition entirely.
   - `HOLD_POSITION`: Fire upon targets in range without moving or chasing.
   - `DEFENSIVE`: Attack within tight tether radius around anchor point, disengaging if enemy flees.
   - `AGGRESSIVE`: Full pursue and engage.
3. Add stance switching button and hotkey (`S` key) in unit controls.

### Stage 3: Control Groups HUD Dock & Double-Tap Camera Snap
1. In `source/match/handlers/UnitGroupSelectionHandler.gd`:
   - Add double-tap tracking: tapping group number twice within 350ms snaps camera to group centroid.
   - Support `Shift + [1-9]` to additively append selected units into existing group without overwriting.
2. Create `source/match/hud/ControlGroupsDock.gd`:
   - Displays clean pill buttons (1–9) showing assigned groups with unit count.
   - Clicking a dock button selects the group; double-clicking snaps camera.

### Stage 4: Continuous Shift-Building & Idle Worker Hotkey/Badge
1. In `source/match/players/human/StructurePlacementHandler.gd`:
   - When placing structures with `Shift` held down, keep blueprint active and allow continuous chaining.
2. In `source/match/hud/`:
   - Implement dedicated Idle Worker shortcut (`F1` / `Period`) that cycles through idle workers and centers camera.
   - Add HUD idle worker count badge that lights up amber when workers are unassigned.

---

## Part II: Tier 3 — Standard UI & HUD

### Stage 5: Unified 3x4 Grid Command Card
1. In `source/match/hud/CommandCard.gd` & `UnitMenus.gd`:
   - Build a standard 3x4 button grid mapped to universal hotkeys:
     - Row 1: `Q` (Move), `W` (Stop), `E` (Hold), `R` (Patrol/Repair)
     - Row 2: `A` (Attack Move), `S` (Stance), `D` (Return Cargo / Special), `F` (Focus Target)
     - Row 3: `Z`, `X`, `C`, `V` (Building & Production slots)
   - Route keyboard inputs to activate corresponding grid actions with visual press states.

### Stage 6: Vector Minimap Frustum Cone & Tactical Ping System
1. In `source/match/hud/Minimap.gd`:
   - Draw an illuminated camera frustum trapezoid indicating the exact camera view cone on the terrain.
   - Add tactical ping functionality (`Ctrl + Left Click` on map or minimap):
     - Spawns expanding radar ripple in 3D world and on 2D minimap.
     - Plays subtle acoustic notification ping.

### Stage 7: Selected Unit Tactical Range Rings & Smart Health Bars
1. In `source/match/units/traits/Selection.gd` & `RangeRing.gd`:
   - For selected units, project a clean, smooth circle decal on the ground for weapon `attack_range` (crimson/amber) and `sight_range` (soft white).
2. In `source/match/units/traits/HealthBar.gd`:
   - Display health bar when unit is selected or damaged; smoothly hide when unselected and at full health.

---

## Part III: Tier 4 — Programmable RTS USP

### Stage 8: Live In-Match Program State Telemetry Badges
1. In `source/match/programs/UnitProgram.gd`:
   - Expose current operational state tag (e.g. `KITING`, `RETREATING`, `ENGAGING`, `GUARDING`).
2. Implement 3D billboard telemetry badge above programmed units displaying current active rule state.

### Stage 9: Pre-Match Program Armory Presets & AI Unit Programs
1. In `source/main-menu/Play.gd`:
   - Add "Tactical Doctrine" selector in skirmish setup (Balanced, Hit & Run Kiting, Ironclad Defense).
   - Apply doctrine chips to qualifying player units at match start.
2. In `source/match/players/skirmish-ai/SkirmishAI.gd`:
   - Arm advanced AI units (Combat Robots, Drones, Advanced Tanks) with tactical programs (e.g. dynamic kiting / low-HP retreat) so AI showcases autonomous behaviors.

---

## Part IV: Verification & Regressions

### Stage 10: Headless Regressions & Final Verification
1. Create dedicated headless tests:
   - `tests/headless/Tier1ControlsRegression.gd`
   - `tests/headless/Tier3UiRegression.gd`
   - `tests/headless/Tier4ProgrammableUspRegression.gd`
2. Run full suite including existing combat and audio tests.

---

## Agent progress
- [x] Part I: Tier 1 — Input, Micro & Controls
  - [x] Stage 1: Formations & Drag-to-Face Directional Move
  - [x] Stage 2: Tactical Unit Stances
  - [x] Stage 3: Control Groups HUD Dock & Double-Tap Camera Snap
  - [x] Stage 4: Continuous Shift-Building & Idle Worker Hotkey/Badge
- [x] Part II: Tier 3 — Standard UI & HUD
  - [x] Stage 5: Unified 3x4 Grid Command Card
  - [x] Stage 6: Vector Minimap Frustum Cone & Tactical Ping System
  - [x] Stage 7: Selected Unit Tactical Range Rings & Smart Health Bars
- [x] Part III: Tier 4 — Programmable RTS USP
  - [x] Stage 8: Live In-Match Program State Telemetry Badges
  - [x] Stage 9: Pre-Match Program Armory Presets & AI Unit Programs
- [x] Part IV: Verification & Regressions
  - [x] Stage 10: Headless Regressions & Final Verification
