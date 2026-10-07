# Explicit Move, Attack target and Attack move

The selection panel now provides three distinct commands, with default M / T / F shortcuts. Move travels without acquiring enemies. Attack target accepts a currently observed enemy that the selected weapon can engage; losing sight preserves only its last observed position. Attack move advances and engages nearby legal targets. The existing contextual right-click remains available.

Arming a command changes no unit orders. Left-click chooses its destination/target; the configured selection modifier appends it to the existing bounded queue. Escape or right-click cancels targeting. Wheel scrolling preserves the active command. Invalid points, empty ground, hidden enemies, friendlies and incompatible target domains leave a useful prompt. Mixed selections apply combat orders only to eligible fighters, preserving engineers' work. Buttons include live remapped labels, descriptions and keyboard activation.

Map targeting is exclusive with building placement and program assignment. Menus, settings, editors, save dialogs and results block command input; tactical pause still allows orders. Live notices cannot replace a targeting prompt. The pending mouse release is consumed when a command button disappears during a unit death, including after an intervening keyboard event.

## Controls migration

Controls profile version 2 adds Move and Attack target, for 33 actions. Every valid version-1 custom binding is retained. If M or T is occupied, the new action receives an available chord; the existing action is never reassigned. Validation remains atomic for malformed/conflicting profiles. The regression exercises occupied plain and modified defaults, all legacy actions, idempotence, non-aliasing and an actual options-file load/save round trip.

## Reproductions and corrections

- [Original command failure](direct-orders-before.log): absent Move/Attack target bindings and targeting module. Retained pre-change HUD and controls files accompany the log.
- [Held-button failure](direct-orders-held-reproducer.log): a pressed command control was rebuilt after death, and its release selected the battlefield. The final rendered workflow verifies the press actually reached the button and that selection survives release.
- The first rendered attack fixture disabled physics picking together with unit processing. Keeping frozen bodies active fixed the fixture; the final workflow uses actual screen-space picking and a physical queue modifier.
- The initial [shared run](direct-orders-final-checks.json) records two failures: the Controls window did not draw before its watchdog, and one final-cargo courier delayed the grouped depletion alert. Neither result is counted as a pass. A two-second window-settle step lets the [Controls capture workflow](direct-orders-controls-window-retry.log) complete all five captures and input checks.
- [Courier diagnosis](direct-orders-alerts-probe.log) shows one depleted worker and one worker still returning cargo. Longer observation completes, but only after repeated avoidance near HQ. Recovery previously treated sideways movement as progress. Near a contact target it now checks progress toward the next route corner over two consecutive windows, retaining the existing stationary recovery. One-window variants interrupted a valid detour; those failed experiments are retained in the recovery/approach/route logs. The [final contact regression](direct-orders-progress-final-ContactApproachRegression.log) preserves its three captured harvest completions at 5.783 seconds, paused disk restoration, manual replacement, crowded HQ delivery/construction, contact distance and movement limits. The alerts regression now also verifies that the final two electronics are delivered exactly once, without extending its deadline.

## Verification

Godot 4.6 on the development M1 Pro. Headless checks use a fixed 60 Hz simulation; rendered workflows use the normal clock and Metal.

- Both factions: explicit targeting, command eligibility, actual Move versus Attack-move behavior, lost sight, bounded queues, manual/program authority, cancellation, placement and modal isolation, tactical pause, and real Move → Attack disk restoration.
- In the 90-frame encounter, Bastion Move travels 3.813 m and Helix Move 4.576 m, with zero damage. Attack move deals 9 damage for each faction while stopping to fight. These are controlled semantics checks, not balance results.
- Actual 720p/150% input: M plus destination click; Shift+T plus enemy click; Enter on Attack move; live Move/Cancel remapping; invalid target and cancellation; held-control death; mixed engineer/fighter selection; First Orders campaign command buttons. Seven command captures were visually reviewed for readable labels/prompts, panel scrolling and minimap/subtitle clearance.
- Shared controls, orders, programs, roster, saves/combat restoration, campaign controls, subtitles, alerts, battle plan and campaign victory checks. Shared rendered Controls, campaign scaling and selection roster workflows. Movement follow-up covers harvesting, supply, recovery, the captured contact archive and rendered conserved collection.

Twenty-five accepted checks comprise sixteen headless suites, five rendered workflows, editor import and three static checks. In the final courier rerun, grouped depletion and exact delivery complete at 19 seconds for Bastion and 15 seconds for Helix within the unchanged 23-second test allowance. The three refreshed contact captures also show cargo increasing from three to four without losing the saved assignment.

The [initial ledger](direct-orders-final-checks.json) preserves the failed attempts. The [acceptance ledger](direct-orders-acceptance-checks.json) records focused reruns after the movement correction and final formatting/lint/whitespace checks. [Combined evidence](direct-orders-verification.json) identifies the accepted log for each suite and records source/capture hashes. Runner copies are retained as `direct-orders-verify.py.txt` and `direct-orders-acceptance.py.txt`.

## Reviewed command captures

| Scenario | Bastion | Helix |
| --- | --- | --- |
| Move targeting | [Move](../../../art/skirmish/direct-orders-bastion-move.png) | [Move](../../../art/skirmish/direct-orders-helix-move.png) |
| Attack target and queued Move | [Attack](../../../art/skirmish/direct-orders-bastion-attack.png) | [Attack](../../../art/skirmish/direct-orders-helix-attack.png) |
| Mixed engineer/fighter selection | [Mixed](../../../art/skirmish/direct-orders-bastion-mixed.png) | [Mixed](../../../art/skirmish/direct-orders-helix-mixed.png) |

[First Orders campaign](../../../art/skirmish/direct-orders-bastion-campaign.png) also retains readable mission instructions, command controls and subtitles at 720p/150%.

## Limits

Synthetic native-window events do not establish physical-device, screen-reader or novice acceptance. Existing navigation readback and shutdown resource/shader warnings remain recorded. No unit prices, damage values, map geometry or battle archive schema changed. Broader strategy/balance, ordinary-match pacing, remaining content and release acceptance remain open. Performance optimization remains deferred.
