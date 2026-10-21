# Unit animation overhaul

## Stage 1 — Audit
Build a rendered capture harness (`tests/rendered/UnitAnimationCapture.gd`) that records idle, start, cruise, turn, stop, aim/fire (or gather/repair), hit and destruction contact sheets for all 14 mobile roles in all three factions, plus an eight-soldier squad. Review the sheets and the motion code and list what reads as goofy per unit type.

## Stage 2 — Body dynamics and locomotion
Replace snapping and uniform sine motion with spring-driven, speed-matched animation, visual only: eased headings, suspension pitch/roll, hover float, aircraft banking and drift, stride-matched infantry and walker gaits with planted feet, eased turret traverse, wheel roll for every wheeled model.

## Stage 3 — Polish layers
Weapon carry/raise, braced and kneeling firing stances, recoil, flinches, idle fidgets, work loops, stabilizer deployment, collapse deaths and spinning aircraft wrecks. Desynchronize squads.

## Stage 4 — Verification and performance
Regressions for no skating, desynchronization, gameplay invariance, culling and settling; rerun motion/combat/visual/air suites; before/after sheets; isolated animation cost comparison.

## Agent progress
- Stage 1 complete. Before sheets: `art/animation/before/` (45 sheets). Findings: every turn and target acquisition snapped within 5–10 frames; infantry carried weapons shouldered at all times, skated at creep speeds and while starting/stopping, toppled like planks on death and lifted their planted boots on hits; heroes out-strode their scaled rig by 12 %; hulls bobbed on a uniform sine with no acceleration or cornering response; aircraft popped between a fixed cruise pitch and level, never banked, and wrecks fell without spinning; walker legs swung a fixed sine regardless of leg length and slid back to rest; Helix Mule/Prism wheels and supply-truck wheels never turned; Helix skimmers did not hover; Prism stabilizers never moved; workers and repair robots were frozen while working; turrets slewed with a constant-fraction lerp.
- Stage 2 complete. New `ChassisMotion` (heading filter with steady-turn feed-forward, suspension/bank springs, hover and rotorcraft drift, engine idle), `WalkerGait` (diagonal-pair gait, stance sweep equal to travel, servo re-planting), rewritten `InfantryMotion` (speed-dependent stride, recovery steps, hip roll keeps boots planted), generalized `WheelMotion` (any axle orientation, Helix and convoy wheels), rate/acceleration-limited turret traverse.
- Stage 3 complete. Low-ready carry and shot raise, braced stance (riflemen/assault/heroes) and kneeling (snipers/rockets), role recoil, directional flinch, four idle fidgets, gather/build/repair tool rhythms, Helix stabilizers tied to the deployment timer, knee-buckle collapses that fall away from the shooter, spinning aircraft wrecks, wrecks copied without model scripts.
- Stage 4 complete. `tests/headless/UnitAnimationRegression.gd` passes for all three factions; motion, infantry, combat-juice, wheel, air and visual suites pass (pre-existing failures unchanged against a baseline snapshot). After sheets: `art/animation/after/`. Animation cost for 160 units: rendered with a battle camera 1.0–1.25 ms per tick (baseline 0.95–1.6 ms, off-screen culling is new); fully on-screen headless worst case 1.6–2.4 ms (baseline 0.95–1.6 ms).
- Remaining limitations: Bastion tank/worker/repair tracks are single meshes (no track-link animation without re-authored models); walker articulation and foot planting were subsequently updated in [Robot walking](robot-walking.md); motion remains procedural rather than authored animation clips.
