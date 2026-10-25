# Active Unit Abilities & Modernized QWER Command Card

## Stage 1 — Core Ability Architecture & Unit Abilities
Design and implement a modular unit ability system (`UnitAbilities.gd`) attached to units or integrated cleanly into `Unit.gd`. Implement 1-2 distinct tactical active abilities for core unit classes:
- **Infantry**: Frag Grenade (`Q` - Target point, 10m range, 3.5m AoE explosion, 12s cooldown).
- **Assault Infantry**: Combat Sprint (`W` - Instant, +50% movement speed for 4s, 15s cooldown).
- **Tank**: Smoke Screen (`Q` - Instant, 6m radius smoke cloud granting 50% projectile evasion and breaking targeting for 7s, 20s cooldown).
- **Advanced Tank**: Siege Anchor (`E` - Toggle, immobilizes chassis for +35% attack range and +30% heavy explosive damage).
- **Rocket Infantry**: Guided Salvo (`Q` - Target unit/point, heavy armor-piercing long-range missile, 14s cooldown).

## Stage 2 — Visual Effects & Combat Interaction
Integrate ability execution with battlefield effects (`CombatEffects.gd`):
- Frag Grenade: projectile arc, grenade impact explosion, shockwave, and area damage in `Battlefield.gd`.
- Combat Sprint: movement dust trail particles and speed modifier integration with `Movement.gd`.
- Smoke Screen: smoke particle cloud on ground, evasion/obscured factor in `CombatRules.gd`.
- Siege Anchor: weapon range modifier in `CombatRules.gd` and stationary lock in `Movement.gd`.

## Stage 3 — Modernized Command Card & Input Dispatch
Modernize `CommandCard.gd` to display unit abilities in dedicated slots on the grid with hotkey badges (`Q`, `W`, `E`, `R`), real-time cooldown countdown overlays, and active toggle indicators.
Wire ability targeting and keyboard dispatch into `DirectOrders.gd` and `SkirmishHUD.gd` so abilities can be executed seamlessly via mouse clicks or hotkeys.

## Stage 4 — Headless Regression Test & Verification
Create `tests/headless/ActiveAbilitiesRegression.gd` to verify:
- Ability initialization, cooldown timers, and serialization/restore readiness.
- Activation mechanics: Frag Grenade AoE damage, Combat Sprint speed multiplier, Smoke Screen evasion, and Siege Anchor range bonus.
- Verify existing combat and UI regressions pass without regressions.

## Agent progress

- Plan created. Preparing to delegate Stage 1 (Core Ability Architecture & Unit Abilities) to worker agent Codex CLI (gpt-6.1-sol high).
- Stage 1 implemented: per-unit ability definitions, readiness/target checks, cooldowns and active timers, grenade AoE, sprint movement, stationary smoke area state, siege movement/range/damage modifiers, and physical guided rockets accepting unit or point targets. The trait exposes activation/change signals and capture/restore methods for subsequent stages. Existing match save schema/version are unchanged; ability cooldown/effect persistence and smoke visuals/evasion remain later-stage work.
- Stage 2 implemented: active friendly smoke screens halve incoming weapon damage at their fixed deployment point, including frozen and raw-damage projectile records; overlapping screens do not stack. Active screens use a small scene group rather than scanning every battlefield unit per hit. Added bounded grenade arcs/detonations, lingering smoke, moving sprint dust, and siege anchor feet/weapon lock with spatial deploy audio, respecting pause, observation and reduced flashes.
- Stage 3 implemented: the existing third command-card row now presents QWER abilities, distinct glyphs, live cooldown readouts, complete tooltips and active faces (also during toggle cooldown). Selected ability keys take priority over camera rotation. Instant/toggle casts apply to all ready selected owners; targeted casts use the first ready selected owner, with range ring, targeting cursor, battlefield/visibility/range checks, selection-change cleanup and right-click/Escape cancellation. Casts execute immediately; pause preserves targeting and asks the player to resume before casting. Mixed selections with shared hotkeys expose the first selected available ability on that key consistently in both card and input.
- Verification: expanded `UnitAbilitiesRegression.gd` covers smoke boundaries/overlap/expiry/movement/restoration, frozen/raw shots, card population/cooldowns/toggle state, hotkeys/map clicks/target-unit and point casts, readiness, pause, modified shortcuts, building placement, modals and cancellation. Eleven focused headless regressions passed (abilities, direct orders, combat, projectiles, command reliability, combat audio, save/restore, tier-3 UI, camera feel, battle polish and combat juice). The command reliability run uncovered an existing resource-node `type` access error; a property guard fixes the original three-faction mining scenario.
- Rendered verification: the complete `HudConsolePreview.gd` matrix passed, and `tests/rendered/UnitAbilitiesPreview.gd` passed for every faction, capturing flight, detonation, smoke and expired states in `art/unit-abilities/`. Formatting, lint and whitespace checks pass. The broader headless suite was not exhaustively run; some existing test runs still emit resource/ObjectDB cleanup warnings at shutdown. Ability state persistence in match archives remains outside Stages 2–3; the save schema/version is unchanged.
