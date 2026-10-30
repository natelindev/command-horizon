# Unit Differentiation and Tank-Centric Combat Design

Address four core unit design and balance issues:
1. Neutral mercenaries show no difference with regular infantry.
2. Different factions have no really different set of infantries.
3. Tank lines also do not really have a difference across factions.
4. Some infantry is overpowered, and tanks should be the main tactical focus.

## Stage 1 — Core Balance & Tank-Centric Combat Foundation
- **Tank Durability & Focus**: Substantially increase base HP of all tanks and tank destroyers (Bastion tank 80 -> 115 HP, Railgun tank 105 -> 145 HP; Helix Needle 64 -> 70 HP + 40 Plasma Shield capacity; Frontier Outrider 68 -> 95 HP, Ironback 89 -> 125 HP).
- **Speed Realignment**: Ensure combat vehicles are faster than foot infantry on open ground. Adjust base infantry movement speed from 3.5 to 3.1 m/s, while raising tank speeds (Bastion 2.9 m/s, Frontier 3.3 m/s, Helix hover skimmer 3.5 m/s).
- **Tank Cannon Punch**: Increase `Tank cannon`, `Precision rail`, and `Heavy cannon` multipliers against Infantry armor from 0.35–0.50 to 0.60–0.75, so main battle tanks destroy infantry in 3 direct hits rather than 5–6 agonizing shots.
- **Tune Overpowered Infantry Anti-Armor**:
  - Reduce `Infantry rocket` damage multiplier vs Heavy armor from 1.7 to 1.3.
  - Rebalance `RocketInfantry` Guided Salvo base damage from 60 to 34 so a single 12-cost infantry cannot one-shot a full-health tank.
  - Slightly normalize `AssaultInfantry` attack interval from 0.4s to 0.45s and base HP from 42 to 38.

## Stage 2 — Faction Infantry Differentiation
- **Bastion Directorate (The Fortified Line)**:
  - Line: Rifle infantry (`Infantry`), Assault infantry (`AssaultInfantry`), Anti-armor infantry (`RocketInfantry`), Sniper (`SniperInfantry`).
  - Heavy ballistic discipline, solid durability, Frag Grenade garrison breach, Combat Sprint, Tandem Guided Salvo.
- **Helix Systems (Cybernetic Energy Operators)**:
  - Line: Vector operator (`Infantry`), Arc shocktrooper (`AssaultInfantry`), Ion specialist (`RocketInfantry`), Phase infiltrator (`SniperInfantry`).
  - High mobility (3.2–3.6 m/s), plasma/arc repeaters and thermal beam weaponry, lower physical hull HP with plasma shield upgrade path, rapid rate-of-fire cadence.
- **Free Frontier Coalition (Wasteland Guerrillas & Raiders)**:
  - Line: Ridge ranger (`Infantry`), Scrap vanguard (`AssaultInfantry`), Tank hunter (`RocketInfantry`), Frontier marksman (`SniperInfantry`).
  - Rugged wasteland guerrilla weaponry (trench shotguns, scavenged swarm RPGs, heavy hunting rifles), resilient HP, high burst damage.

## Stage 3 — Asymmetrical Tank Lines
- **Bastion Directorate (Armored Juggernaut)**:
  - Heavy frontline tank with composite armor (115 HP, 11 dmg cannon, 1.2s interval) and defensive Smoke Screen.
  - Railgun tank destroyer (145 HP, 22 dmg, 12m range, 0.75s charge) with Siege Anchor.
- **Helix Systems (Hover Skimmers & Directed Energy)**:
  - Needle skimmer: Levitating hover chassis (speed 3.5 m/s, 70 HP + 40 Shield), Twin Pulse Lasers delivering continuous energy fire (6 dmg, 0.65s interval).
  - Prism artillery: Long-range hover siege platform (90 HP + 50 Shield, 14m range, 15m sight, 1.5s deploy) with Prism Anchor.
- **Free Frontier Coalition (Motorized Raiders & Field Howitzers)**:
  - Outrider assault tank: Fast wheeled technical (speed 3.3 m/s, 95 HP) with Twin Autocannons (8 dmg, 0.8s interval) for aggressive flanking and screening.
  - Ironback siege gun: Heavy 152mm field howitzer (125 HP, 20 dmg, 12m range) firing immediately without capacitor preparation delay.

## Stage 4 — Neutral Mercenary Specialization
- **Distinct Visuals**: Author a dedicated gritty mercenary palette (charcoal slate, desert tan, brass insignia) in `InfantryModel.gd` instead of falling back to standard Bastion colors.
- **Iron Warden (`MercenaryWarden`)**:
  - Juggernaut breacher with 85 HP and close-range heavy buckshot (8 dmg, 0.5s interval).
  - Active Ability: `shield_wall` (instant, 18s cooldown, 6s duration) granting 40% damage resistance and suppression immunity.
- **Dust Ranger (`MercenaryRanger`)**:
  - Desert tracker marksman with 30 HP, 18m sight, 13.5m range, and anti-materiel rifle (16 dmg, 2.0s interval).
  - Active Ability: `target_flare` (targeted point, 16s cooldown, 16m range, 6m radius, 8s duration) illuminating fog of war, piercing smoke, and increasing damage taken by marked enemies by 20%.
- **Breach Lancer (`MercenaryLancer`)**:
  - Demolition and vehicle disruption specialist with 50 HP and heavy breach rocket (22 dmg, 2.8s interval).
  - Active Ability: `emp_rocket` (targeted unit, 18s cooldown, 12m range) dealing 35 damage, draining 50 shields, and slowing target vehicle movement and firing rate by 50% for 4s.

## Stage 5 — Localization, Integration & Verification
- Update localization catalogs (`art/localization/factions.tsv`, `tactical-environment.tsv`) and build the binary translation catalog.
- Verify ability execution, cooldowns, targeting, and command card integration.
- Ensure regression tests and save schema contracts remain fully intact.

## Stage 6 — Unit Roster Counter System
- Implement `UnitCounters` in `source/match/combat/UnitCounters.gd`, providing:
  - Multi-counter matrix where every combat unit has at least 3-4 viable counters.
  - Dynamic faction-aware tooltip and unit identity facts (`Strong vs:` and `Countered by:`).
  - Localization entries in `factions.tsv` and rebuilt `ui.csv`.
- Integrate into `RosterInfo.gd` and `UnitMenus.gd` for in-game visibility during production and selection.
- Add headless regression test `tests/headless/UnitCountersRegression.gd`.

## Agent progress
- Inspected codebase, combat formulas, armor multipliers, ability system, save schemas, and faction catalogs.
- Analyzed root causes: tanks had low HP (80), were slower than infantry (2.6 vs 3.5), dealt only 50% damage to infantry, while rocket infantry Guided Salvo dealt 102 damage against heavy armor (one-shotting tanks); neutral mercenaries lacked abilities and unique models; factions shared identical infantry and tank weapons.
- Written design plan with 5 clear stages.
- **Stage 1 Completed**: Rebalanced core tank vs infantry dynamics. Tanks boosted to 115 HP / 11 damage / 2.9 m/s; Advanced Tanks to 145 HP; Infantry speed reduced to 3.1 m/s; Tank cannon vs Infantry multiplier raised from 0.5 to 0.75; Rocket Infantry Guided Salvo adjusted to 34 damage; Infantry rocket vs Heavy armor multiplier reduced to 1.3.
- **Stage 2 Completed**: Distinct infantry rosters implemented across Bastion (Rifle Infantry, Assault Vanguard, Heavy AT Hunter, Marksman), Helix (Vector Operator, Arc Shocktrooper, Ion Specialist, Phase Infiltrator), and Frontier (Ridge Ranger, Scrap Vanguard, Tank Hunter, Frontier Marksman).
- **Stage 3 Completed**: Tank lines differentiated across Bastion (tracked anchor with 90mm cannon and smoke), Helix (high-speed repulsor skimmer with twin pulse lasers), and Frontier (fast raiding technical with twin autocannons).
- **Stage 4 Completed**: Neutral mercenaries upgraded with unique gritty mercenary visual palette, distinct combat profiles, and dedicated active abilities (Iron Warden: Shield Wall, Dust Ranger: Spotter Flare, Breach Lancer: Disruptor Rocket).
- **Stage 5 Completed**: Localized all new unit titles, descriptions, weapon classes, and ability profiles in `art/localization/factions.tsv`; generated translations via `art/localization/build_catalog.py`; verified all GDScript files through `gdlint` with zero errors. All regression contracts and save schemas verified.
- **Stage 6 Completed**: Designed and implemented the comprehensive Unit Roster Counter System in `source/match/combat/UnitCounters.gd` with multiple counters for every combat unit; wired into production tooltips (`RosterInfo.gd`) and selection details (`UnitMenus.gd`); localized in `factions.tsv` (2,496 translations rebuilt); validated via `tests/headless/UnitCountersRegression.gd` and passed `gdlint`.
