# Visible heavy-armor defense guidance — 2026-10-06

The battle plan now recognizes rifle-only defense against observed heavy armor near the economy. It recommends a counter, accounts for paid production and blockers, and preserves existing defender selection when a capable mobile weapon is available. Review also exposed and fixed the production panel collapsing when the same factory is selected again.

## Before and after

The original rifle-only fixture fails nine assertions across Bastion, Helix and Frontier (`ground-defense/before.log`): both the tactical helper and full plan select infantry, and the description omits the armor matchup. The previous depleted-army fallback selects Barracks even with a completed vehicle factory. Original files are retained under `ground-defense/before/`.

`GroundDefenseAdvice.gd` uses existing weapon profiles and heavy-armor multipliers to identify counters. No weapon statistics, prices, production times or AI strategy changed.

- Existing compatible tanks, heavy vehicles, strike aircraft and Precision Lancers keep the normal whole-army defense action. Normal reload/deployment does not invalidate a counter.
- Without a mobile counter, Helix stance guidance remains available even when rifle infantry are present. Completed ground batteries within actual weapon range can provide static-cover guidance.
- Otherwise, the plan recognizes already paid counters, including specialists and strike aircraft. A blocked queue exposes its current blocking reason rather than requesting another purchase.
- New tank production uses the same price and availability inspection as roster buttons, including current chip fitting, missing lab, exact resource shortage, population cap and queue capacity. Another ready factory is preferred when the first cannot accept a job. The compact plan shows one obstacle at a time; the roster retains all details.
- Missing production routes through construction prerequisites and existing paid foundations. Aircraft defense and urgent engineer/HQ recovery retain priority.
- Threat classification uses current observation. Recent damage from an unseen attacker gives the existing generic warning. Advice does not purchase, cancel, switch stances, alter orders or advance tactical pause.

## Selection-panel fix

The rendered shortage review revealed that selecting the same factory twice could leave only an empty panel strip. The identical content size after rebuilding the roster could leave the scroll minimum at the intermediate empty size. `UnitMenus.gd` now also schedules a deferred fit after rebuilding controls.

The added all-faction regression fails six assertions before this fix (`reselection-before.log`, the second and third selection for each faction). It passes afterward. This is a general roster sizing fix, with no change to orders or purchases.

## Verification

Final `refit-GroundDefenseAdviceRegression.log`: zero failures, all three factions. Coverage includes the original scenario, repeated factory selection, exact conventional/fitted fees, actual paid completion, paused authority, paid specialist/air counters, lost-lab queue blocking, conventional fallback, full queue, alternate factory, the 100-unit cap, weak autocannons, stance choice, aircraft/heavy counters, static cover/foundations, hidden damage, mixed air threats, depleted army, construction prerequisites and HQ/worker emergency priority.

Shared AirDefenseAdvice, OpeningArmor, BattlePlan, EngineerResponse, RosterInfo and RosterLayout regressions pass. RosterInfo and RosterLayout were repeated after the sizing fix. Seven affected/new scripts pass formatting and lint checks. Passing logs contain no script or parse errors. Existing navigation-readback and renderer/ObjectDB shutdown cleanup diagnostics remain; they are separate from assertion results.

## Native review

`native.log` records zero failures for actual mouse/Enter/Space input at 1280×720 and 150% interface scale, all three factions. Selecting production neither advances pause nor spends resources. Each explicit roster click buys one conventional tank at the displayed price, updates to paid-queue advice, and completes through normal production; advice then returns to Select defenders.

| Faction | Paid materials / electronics |
| --- | --- |
| Bastion | 24 / 6 |
| Helix | 22 / 10 |
| Frontier | 20 / 4 |

The twelve `native-*.png` images retain these transitions. Subsequent wording and blocked-production layout refinements are captured separately. Final `refit-frontier-*.png` images show corrected roster sizing, a checked chip option, exact shortage, missing lab and conventional fallback. The panels fit without overlapping the minimap. Earlier `layout-*` and `final-layout-*` images retain the fixture synchronization issue and the empty-strip bug; they are not final acceptance images.

An additional real-input repeat-click run (`reselected.log`) could not be completed: CUA returned a gray native window after app rediscovery/rebinding, while the engine saved a valid advice frame. The test process was terminated without purchases. The panel fix has automated headless and native-rendered repeated-selection coverage; final manual repeat-click acceptance remains unverified. The earlier all-faction manual purchase flow succeeded.

## Scope and limits

These are controlled advice/interaction fixtures with strategic AI and existing actors disabled, apart from the factory and newly produced counter during completion. They verify decisions, paid production and UI behavior, not survival or win rate. The retained first-contact losses remain strategy acceptance work; no new full-match or faction-balance claim is made. Broader gameplay acceptance remains open, and performance work stays deferred.
