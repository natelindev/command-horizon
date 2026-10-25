# Faction Asymmetry: Frontier Salvage Mechanics & Helix Plasma Shields

## Stage 1 — Helix Plasma Shields & Research
1. Add `plasma_shields` research item in `source/match/research/TechnologyCatalog.gd`:
   - Available to Helix faction at Signal Lab (requires `coordination`).
   - Cost: 40 materials, 25 electronics, 40s duration.
   - Description: Equips Helix combat units with modest regenerating plasma shields (15-40 HP based on unit role).
2. Implement shield behavior on units in `source/match/units/Unit.gd`:
   - `shields` and `shields_max`: float properties.
   - Shield absorbs damage first in `receive_damage()`; remaining damage hits `hp`.
   - After 5.0s without taking damage, shields recharge at a balanced rate (e.g. 6 HP/s) up to `shields_max`.
   - Modest values: Vector Operator (15), Needle Skimmer (30), Lancer Walker (35), Prism Artillery (40), aircraft (25).
3. Presentation & UI:
   - In `UnitMenus.gd`: render a sleek cyan/blue shield gauge above the health bar when `shields_max > 0`.
   - In `CombatEffects.gd`: blue shield impact shimmer when a shield absorbs damage.

## Stage 2 — Frontier Salvage Mechanics
1. Enhance Frontier wreck interactions:
   - Wreck yield: Increase Frontier wreck salvage retention to 35% (from 20%) when vehicles are destroyed in matches involving Frontier.
2. Frontier Combat Scavenge:
   - Frontier combat vehicles (`Tank`, `AntiAirVehicle`, `AdvancedTank`, `CombatRobot`) can scavenge wrecks by right-clicking or via direct command.
   - Scavenging a wreck consumes it, instantly repairs 35% HP, and grants a "Scrap Hardened" buff (+15% weapon damage and +10% speed for 60s, stackable up to 2 times).
3. Frontier Worker Rapid Dismantle:
   - Frontier workers can execute instant field salvage on a wreck, converting its scrap directly into player materials without requiring travel back to HQ.
4. Visual & Audio Feedback:
   - Sparks, clanking salvage audio, and scrap buff badge/indicator on scavenged Frontier vehicles.

## Stage 3 — Headless Regression Test & Verification
1. Create `tests/headless/FactionMechanicsRegression.gd`:
   - Verify Helix shield research unlock, damage absorption, recharge after delay, and absence prior to research.
   - Verify Frontier vehicle scrap scavenge (healing, buff application, wreck consumption).
   - Verify Frontier worker instant field salvage.
2. Ensure full compatibility with `SnapshotSchema.gd`, `TechnologyRegression.gd`, `CombatRegression.gd`, and `SaveRestoreRegression.gd`.

## Agent progress

- Plan created. Preparing to delegate Stage 1 (Helix Plasma Shields & Research) to worker agent Codex CLI (gpt-6.1-sol high).
- Stage 1 complete: faction-gated research, role capacities, shield absorption/recharge, cyan HUD gauge, blue impact shimmer, English/Chinese localization and shield save persistence implemented. Existing workspace changes preserved.
- Verification passed: `PlasmaShieldsRegression`, `TechnologyRegression`, `CombatRegression`, `SaveRestoreRegression`, `ResearchTilesRegression`, `TechnologyAIRegression` and `LocalizationRegression`; native `HudConsolePreview --research` passed for all factions/languages, plus Helix full/partial/depleted/impact/worker captures under `art/hud-console/`.
- Updated research-grid/AI fixtures for faction availability and corrected the technology service fixture to use the depot's current service platform. Some existing suites report ObjectDB/resource cleanup diagnostics at exit despite passing all assertions; no script errors occurred.
- Stage 2 & Stage 3 complete: Frontier 35% wreck yield, combat vehicle wreck scavenge with 35% repair and stackable Scrap Hardened buffs (+15% dmg / +10% speed up to Tier 2), worker on-site field dismantle without HQ hauling, save persistence and full regression coverage implemented and verified. All suites pass.
