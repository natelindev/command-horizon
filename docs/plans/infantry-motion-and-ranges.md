# Infantry motion and engagement ranges

## Stage 1: Human silhouettes and articulation
Replace rigid infantry geometry with a shared human rig for all factions and classes. Preserve faction palettes, recognizable equipment, hero identity, muzzle placement, and cosmetic RNG isolation. Use articulated knees, planted stance feet, smooth movement transitions, breathing, and coordinated upper-body motion.

## Stage 2: Engagement distance
Increase ranges across armed units and faction weapon modes while retaining assault/rifle/rocket/sniper and armor roles. Keep sight and displayed weapon information consistent. Preserve line-of-fire and target visibility rules.

## Stage 3: Verification
Exercise every infantry class/faction, movement and firing poses, muzzle alignment, and pause behavior. Verify attack orders stop and fire at the new distances; run related combat, movement, weapon-mode, and infantry regressions. Render and inspect the roster and movement cycle.

## Agent progress
- Inspection complete: infantry currently animate single rigid leg pivots; equipment sits outside the body rig. Range defaults and several faction/mode overrides require coordinated updates.
- Stage 1 complete: all 15 class/faction combinations now use connected cloth limbs, visible faces, articulated hips/knees/ankles, grounded stance feet, chest breathing/recoil, and role-specific weapon grips. Class gear follows the chest; player-color patches and hero identity remain intact.
- Stage 2 complete: armed-unit ranges increased by roughly 40–60%, with matching sight, faction overrides, weapon modes, English/Chinese descriptions, and boundary probes. Settled shooters receive higher avoidance priority; attack-move checks its firing boundary every 0.1 seconds.
- Stage 3 complete: all 12 relevant regression suites pass; all source files pass formatting and lint. New tests cover 15 infantry rigs, 33 armed faction/role range boundaries, six eight-soldier engagement scenarios, muzzle/player-color consistency, and release of firing priority on movement. Rendered all faction rosters and gait poses, plus a three-second motion clip.
- Evidence: `docs/playtests/2026-10-11/infantry-motion-ranges/`. Full-match campaign/skirmish balance and maximum-population performance were not audited.
