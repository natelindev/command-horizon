# Economy recovery and expansion guidance — 2026-10-02

This stage makes economic interruptions actionable in the existing skirmish Battle plan. It adds no automatic commander, emergency resource grants, new currency or save fields. Performance optimization remains deferred.

## Player flows

| Situation | Advice and selection |
| --- | --- |
| Some engineers lose their drop-off while another HQ exists | Select the stranded engineers; explicitly right-click a completed friendly HQ. |
| A local field runs dry while others keep gathering | Select only displaced engineers; use Army to scout/protect the next field and explicitly assign its resource type. |
| Cargo-only delivery completes | Select those engineers and choose a field. |
| At least two engineers await work slots | Select waiting engineers for another field or construction. |
| All engineers lost, replacement already paid | Select the HQ containing that job; do not request another payment. |
| All engineers lost, enough funds | Select HQ and show the actual engineer cost. |
| Insufficient replacement/HQ funds, useful paid jobs remain | Select a producer; the player decides which queue icons to cancel for full refunds. |
| Paid Coordination research can help recovery | Select a surviving completed lab and explain its existing Cancel & refund control. |
| Unit limit prevents an engineer | Select a queued producer if a cancellation can release a reservation; otherwise select the army. |
| HQ lost with surviving engineers | Reuse a paid foundation or show its actual cost, recovery countdown and new-HQ build duration. |
| No usable recovery budget or no HQ/engineer | Explain the restriction and offer the remaining army or Menu restart; cargo is not treated as spendable funds without an HQ. |
| Next recommended building is unaffordable | Show missing M/E and the resource to gather; prefer an available engineer. |

HQ refund advice is offered only when current funds plus accessible production/research refunds can cover the whole rebuild; insufficient refunds do not prompt sacrificing jobs for an impossible recovery. Selection buttons preserve orders and funds. No advice inspects live hidden resources or enemy state. An engineer already working on the required foundation is preferred over replacing that assignment. Recommendations are advisory; they do not lock other UI actions. Campaign missions retain their authored objectives.

## Fixed during actual UI testing

The original production queue inherited the simulation's paused process mode. Paid queue icons were visible while paused but mouse input could not cancel them, blocking the proposed refund flow. The queue UI now processes while paused; the separate production simulation still freezes. Removed the empty focus override so keyboard focus is visible. The native test fails on the original queue behavior and passes after the correction.

## Verification

- `EconomyRecoveryRegression.gd`: both factions; partial depletion alongside active gathering, cargo/slot/delivery advice, idle builder preference, affordability, no automatic spending/order replacement, paid Coordination refund, actual production refund → engineer purchase → timed production → real harvest/delivery income, absent-budget guidance, sufficient/insufficient combined HQ refund budgets, paid HQ placement → construction → defeat-clock reset, and paused archive continuity for replacement jobs and HQ foundations.
- `EconomyRecoveryPreview.gd`: actual 1280×720 mouse/keyboard controls for both factions. Review queue selects the correct producer without refunding; clicking a paid icon (Bastion) or Enter (Helix) refunds; actual HQ engineer button reinvests that money while paused. Expansion selects only the affected engineer and actual world right-click reassigns it. HQ selection preserves funds and tactical pause. Panel bounds remain clear of minimap/unit controls.
- Existing `SkirmishLoopPreview.gd` passes the ordinary opening, world gathering, program configuration and manual override UI for both factions.
- `ResourceFieldRegression.gd` and `SaveRestoreEdges.gd` pass the shared harvesting and archive behavior. Editor import, changed-script format/lint and whitespace checks pass.

The recovery suites use controlled own-unit/resource-loss fixtures to reach adverse states, then exercise real paid actions, navigation, production, construction and reconstruction. They are not a new full-match balance or novice test. The previous full-match outcomes remain in [Resource fields](RESOURCE_FIELDS.md). Existing navigation-bake and shutdown RID/resource warnings remain unresolved.

Reviewed screens: [Bastion paid refund](../../../art/skirmish/recovery-bastion-refund-720p.png), [Helix replacement queued](../../../art/skirmish/recovery-helix-replacement-720p.png), [Bastion field expansion](../../../art/skirmish/recovery-bastion-expansion-720p.png), [HQ recovery](../../../art/skirmish/recovery-bastion-hq-720p.png).

## Remaining work

The player still chooses and scouts expansion locations. There is no new remembered-resource index or automatic safe-route planner. Recovery advice does not guarantee a rebuild is reachable before the countdown; combat, path travel and remaining resources remain constraints. Broader novice pacing, faction balance and the missing conventional campaign opening remain next gameplay work. Final presentation/audio, remaining factions/maps and release performance stay open.
