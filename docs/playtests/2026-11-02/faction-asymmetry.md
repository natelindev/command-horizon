# Faction asymmetry implementation verification — 2026-11-02

Faction rosters now resolve through authored resources and dedicated signature scenes. Bastion has hydraulic siege deployment, directional Bulwark interception and persistent flak zones. Helix uses low hull durability with majority innate shields, chained/linked Prism beams, engine-stalling ion weapons, Phase Shift and stationary optical cloak. Frontier fields twin-autocannon Battle Rigs with four hidden firing-port passengers, demolition buggies, salvo AA and cheap pair/triplet production.

Faction-specific research replaces the available mirrored upgrade ladders. Doctrine reservations exclude their opposing choice while queued, active and completed. Runtime effects include reinforced auto-repairing bunkers, tank mobility, shield-break EMP, expanded Prism links, building-death militia and battlefield vehicle cannibalization. Faction AI now varies wave timing, deployment, shield withdrawal, garrison use and mine placement.

Frontier has no constructible aerospace facility. The spec's Hornet/Buzzard matrix entries and existing Kestrel are accessible as **paid Black Market sorties at the Scrap Yard**. Each aircraft starts airborne with finite ammunition and 90 seconds of fuel, remains directly controllable, and departs through a legal edge corridor when depleted. Contracts share a 20-second cooldown, consume one population slot, and provide no on-map rearming. Contract timers, ammunition and departure state survive pause/save/reload. Frontier AI buys an appropriate contract when its economy permits. Lookout drones remain ordinary Motor Pool production.

## Verification

Godot 4.7.2, macOS. New suites collect script/runtime exceptions and fail on them.

| Check | Result |
| --- | --- |
| `FactionAsymmetryRegression.gd` | 0 failures: nine dedicated canonical scenes, authored hull/shields, deployment and splash, Bulwark arcs, flak, ion stalls, beam links/chains, batch costs/population/refunds/releases, hidden four-port passengers, twin muzzle rounds, demolition, six-port bunkers, doctrine effects and mines |
| `UnitAnimationRegression.gd` | 0 failures in script and full native; authored Bastion biped and Helix quadrupeds retain planted feet, with measured Bulwark slide 0.00000344 m/frame and IK error 0.00000427 m; Helix harvesters/Prism Skimmers correctly use hover motion |
| `FactionStrategyRegression.gd` | 0 failures, including after adding Frontier aircraft contracts |
| `OpticalCloakRegression.gd` | 0 failures: idle delay, movement/firing reveal, proximity, flare detection, targeting and allied visibility |
| `TechnologyAIRegression.gd` / `FrontierProductionAIRegression.gd` | 0 failures with authored exclusive branches and full batch accounting |
| `ProjectileSystemRegression.gd` / `ProjectilePhysicsRegression.gd` | PASS: persistence, exactly-once shield/hull damage and physical weapon trajectories |
| `FrontierAirContractsRegression.gd` | 0 failures: payment, legal airborne entry, faction/facility/population/cooldown limits, finite stores/fuel, rejected-purchase atomicity, saved/paused timers and all three aircraft physically departing |
| `FixedWingFlightRegression.gd` / `AirSaveContinuityRegression.gd` | PASS: normal taxi/runway/turn/orbit/landing/rearm/strike behavior and saved aircraft state remain intact |
| `HudConsolePreview.gd -- --console-only --research` | 0 failures across all three factions in English/Chinese: icons, prices, geometry, keyboard start/refund, queue cancellation, doctrine exclusion and innate shield gauges |
| `ResearchTilesRegression.gd` | 0 failures in six selected-lab/global-console contexts, including the full legal paid queue, preserved pictures/prices, cancellation/refunds, doctrine exclusion and the explicit 246-pixel deck limit |
| `ResearchFeedbackRegression.gd` | 0 failures: all faction clocks, 25% brownout timing and tooltip, pause continuity, lost-lab save/reload/rebuild, completion notices and affordable branch counts; runtime exceptions are collected as failures |
| `FrontierMarketPreview.gd` | 0 failures at 1280×720 / 150% UI in English/Chinese: five direct cards, visible pictures/names/prices, keyboard hiring, cooldown states and unchanged 246-pixel deck height |
| `ArchivedSnapshotRegression.gd` | 811 current v22 archives / 389 recorded checksums / 0 failures; [conversion report](benchmark-archives.md) records identity and health-percentage preservation |

Native rendered artifacts: [signature rosters](../../../art/faction-rosters/), [research consoles](../../../art/hud-console/) and [Black Market](../../../art/frontier-market/). The market captures include ready and cooldown states in both languages. Models were generated through each faction's Blender/weathering script; localization was built from the source TSV catalog.

Research cards retain prices through active, queued and completed states. Their existing state markers and tooltips show progress without adding a third caption line; the progress/cancel control and paid queue share one footer row. Native review confirms that the Frontier Research/Black Market tabs and a paid queue fit within the unchanged console height.

Command outputs for the final integration checks are retained in [faction-asymmetry/](faction-asymmetry/).

The updated `TechnologyRegression.gd` also verifies current faction research prices, actual clocks, 25% brownouts, lab-loss pause, restoration and permanent doctrine exclusions in full native mode. `CoordinationRegression.gd` retains its payment/refund/prerequisite/AI checks with the current 25% clock.


Final native integration also verifies [Bastion fortification and free perimeter maintenance](faction-asymmetry/fortification.log): +25% structure hull, 15% physical-projectile reduction with energy exclusions, fractional/frozen-shot damage and paused save/restore, plus actual resource-free Depot/Rover repair. [Assembly streaks](faction-asymmetry/assembly.log), [autonomous nanite work](faction-asymmetry/autonomous-assembly.log), [innate shields/resonators](faction-asymmetry/shield-resonators.log), [engineering](faction-asymmetry/field-engineering.log), [salvage](faction-asymmetry/salvage.log), [modular ability tiles](faction-asymmetry/ability-tray.log) and [all-faction signature feedback](faction-asymmetry/signature-feedback.log) pass. The signature feedback fixture now writes temporary archives under user://, preserving historical source identities.

## Selection refresh CPU verification

A refresh-local eligibility snapshot now serves the command card, command buttons, cargo and recovery hints. Activations still recompute current ownership, selection, weapon/domain, facilities and navigation. Recovery uses owner-indexed structure membership and validates completion, HP and active service for this refresh; facility titles are resolved once per owner/role. The ability tray groups each ability in one pass while preserving mixed readiness, active state and minimum cooldown.

With 200 selected Bastion tanks and 40 synchronous samples per function, actual caller-thread CPU medians measured healthy button refresh 7.47–7.65 → 4.68–4.85 ms; 100 wounded 8.69–8.72 → 4.88–5.36 ms; 200 wounded 9.63–10.38 → 5.73–5.92 ms. Recovery alone at 200 wounded measured 2.15–2.58 → 1.07–1.20 ms. [Before](integrated-benchmark/hud-refresh-before.log), [after](integrated-benchmark/hud-refresh-after.log), [all CPU cases](integrated-benchmark/hud-refresh-cpu.json). These are shared-load function diagnostics using native CPU clocks, not a rendered frame gate. Refresh frequency and selected-unit animation cadence are unchanged.

Full-native [direct orders](integrated-benchmark/hud-DirectOrdersRegression.log), [cargo return](integrated-benchmark/hud-CargoReturnRegression.log), [micro controls](integrated-benchmark/hud-MicroControlsRegression.log), [ability tray](integrated-benchmark/hud-AbilityTrayRegression.log) and [three-faction disconnected recovery routes](integrated-benchmark/hud-HudRecoveryRoutesRegression.log) pass with zero failures. Added cases check weapon removal between refreshes/clicks, same-tick service completion and queued deletion, and a two-unit mixed-ready/active cooldown aggregate. Existing modal, stale-HQ, target-domain, queue and disk-restore checks remain strict.

The subsequent [release integration review](release-readiness-review.md) retains exact terrain-query invalidation, selected footprint suppression, canonical charge geometry and rendered parity checks, plus copied-corpus release validation and fatal engine-output contracts. These preserve selected-unit animation cadence and do not stand in for the strict rendered frame gate.
