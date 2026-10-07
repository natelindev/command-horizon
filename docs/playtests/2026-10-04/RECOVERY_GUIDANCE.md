# Recovery guidance and Standard-start follow-up

This pass adds actionable recovery advice when the player lacks the matching service, and repairs the automated reference commander's economy after engineer losses. The broader gameplay goal remains active. Combat values, unit costs, map routes and the shipping AI's allocation policy are unchanged in this pass. Performance work remains deferred.

## Player-facing behavior

A damaged ground machine without a depot or eligible friendly repair robot now leads to the paid repair-facility construction step. Infantry and aircraft require their matching facilities. The existing advice system handles prerequisites, missing funds, available engineers and unfinished paid foundations. Enemy facilities and a robot's own repair capability do not satisfy recovery. With appropriate support present, the advice selects damaged units and explains where to hold for service. Programming guidance now asks for a safe point near matching repair support instead of implying that headquarters heals units.

Advice remains a selection shortcut. It does not spend funds, issue orders, resume a program or advance paused simulation. The player still places and pays for construction and orders units into service range.

`RecoveryGuidanceRegression` fails 16 assertions with the archived previous guidance and passes with the new guidance, for both factions. It verifies costs, missing-income priority, paid foundations, a real paused disk round trip, ordinary construction/healing, manual authority, aircraft, infantry, enemy support and robot self-service. Comparison logs: `recovery-guidance-verified-before.log` / `recovery-guidance-verified-after.log`; subsequent shared and rendered runs retain the same checks.

## Reference commander

The previous worker policy used positions in the current worker list. Repeated losses of electronics gatherers shifted replacements into materials jobs: the regression observes electronics assignments fall from two to one to zero, followed by no electronics deliveries. The commander now counts current and queued gather assignments and assigns replacements to the deficit. It preserves the original opening preferences and uses a materials gatherer or idle engineer for construction. Pending orders stay intact. This remains a bounded opening split (one electronics gatherer with three/four engineers, two with five/six), not a demand optimizer or a player automation feature.

Once its opening structures exist, a wounded ground force can cause the commander to fund a depot through ordinary placement. It does not duplicate an existing foundation. The regression verifies actual payment, construction completion, preserved electronics routes and resumed deliveries after repeated casualties. The final fixture fails ten assertions with the archived old commander (`reference-economy-accepted-before.log`); the corrected policy passes (`reference-economy-accepted.log`).

## Verification and limits

The shared run covers recovery guidance, reference economy, battle-plan selection, supply-line campaign, economy supply/recovery, reference retreat, combat, specialists, presets, orders, snapshots/restoration, contact approach, endpoint arrival and crowded harvesting. All 16 valid suites pass in `recovery-guidance-accepted-checks.json`; the corrected Supply Line and final reference-economy results replace their intermediate entries. Raw results remain in `recovery-guidance-checks.json` and `recovery-guidance-economy-checks.json`. An accidentally named nonexistent `EconomyGuidanceRegression` returned exit zero from Godot; its file-load error is **not a pass** and is excluded. The two real economy suites were then run explicitly.

Supply Line initially failed its exact clearance equality by one physics tick. An instrumented replay retained the same living enemy at the checkpoint throughout the check: clearance changed from 3.0 to 3.01667 seconds. The test teleported that enemy after the frame's spatial snapshot. Invalidating that snapshot immediately after the fixture teleport corrects the setup; `recovery-guidance-supply-verified.log` passes the full campaign test. No campaign runtime rule was changed. The failing original and diagnostic logs remain available.

Native rendered checks exercise both factions with the interface scale at 150%, mouse selection, paused authority, actual healing, construction/funding advice and the shared mouse/keyboard battle-plan workflow. Startup reapplies saved display options; previews now enforce 1280 × 720 after startup, and assert the actual capture resolution. The initial shared rendered run failed only its twelve resolution assertions; it is retained rather than counted as a pass. The final dedicated recovery and shared battle-plan runs both pass (`recovery-guidance-input-rendered-720.log`, `recovery-guidance-plan-rendered-720.log`). All 24 final PNGs were checked at 1280 × 720, with both new text states inspected at full size and the full set reviewed for layout. Files are `art/skirmish/recovery-guidance-*.png` and `art/skirmish/battle-plan-*.png`.

Godot still reports navigation mesh readback warnings and shutdown resource/renderer leak warnings in these runs. No new script errors are accepted as passes. These checks do not establish physical-device input, novice comprehension, accessibility, every platform or release readiness.

## Intermittent harvesting deadline

The earlier CrowdBoundary archive's fifteen-second cargo deadline remains open. Twelve exact replays with an early slow-travel capture hook all passed (about 14.39–14.90 m of travel in the first ten seconds); none triggered capture. Sixteen additional nearby-agent perturbations also passed, but those alter the fixture and cannot prove the original condition fixed. This pass changes no movement runtime. The shared CrowdBoundary run passes, which does not erase the prior failure. Keep the diagnostic hooks and capture the next actual recurrence rather than adding speculative movement changes.

## Standard-start trials

These Coastal trials use Normal difficulty, real harvesting and spending, the same ground-first/proactive reference strategy, one run per faction per revision, and a thirty-minute simulation limit. They are diagnostic strategy samples, not balance statistics. Standard begins with its ordinary economy and must unlock and fit programs; the preceding endpoint report's Advanced starts already have infrastructure and forces and are not comparable pacing baselines.

The old reference policy stalled at the thirty-minute limit as Bastion and lost at 9:03.5 as Helix. Intermediate policies are retained: assigning electronics to the builder produced a Bastion loss at 6:50.3 and a Helix victory at 14:25.9; reserving the builder but changing the opening worker choice produced another mixed pair. A further intermediate run preserved initial worker preferences but delayed the second electronics assignment until six workers; both factions lost before assault. The final policy also restores the original fifth-worker assignment, verified explicitly, while fixing casualty replacement and adding paid recovery investment. Full timing data follow below; no claim that Standard pacing or general strategic balance is solved is warranted.

| Policy revision | Faction | Result / time | Lab / first program | First contact / assault | Expansion order / return | Harvest M / E | Longest stationary travel, player / AI |
|---|---|---|---|---|---|---|---|
| current | bastion | Unresolved at 30:00 / 30:00.7 | 2:21.2 / 2:46.7 | 2:24.7 / 11:22.7 | 6:00.2 / 6:37.2 | 1221 / 228 | 2.5 / 1.5 s |
| current | helix | Defeat / 9:03.5 | 2:05.7 / 2:31.2 | 2:29.2 / — | 6:00.2 / 6:32.2 | 456 / 112 | 1.5 / 2.5 s |
| recovery | bastion | Defeat / 6:50.3 | 2:14.2 / 2:39.7 | 2:24.7 / — | — / — | 224 / 56 | 1.0 / 1.5 s |
| recovery | helix | Victory / 14:25.9 | 2:05.7 / 2:31.2 | 2:28.7 / 9:21.7 | 6:00.2 / 7:01.7 | 720 / 290 | 1.5 / 1.5 s |
| final | bastion | Victory / 14:17.8 | 2:08.2 / 2:33.7 | 2:25.7 / 8:37.2 | 6:00.2 / 7:05.7 | 680 / 275 | 2.0 / 1.5 s |
| final | helix | Defeat / 4:52.6 | 2:23.7 / 2:49.2 | 2:27.2 / — | — / — | 180 / 60 | 1.0 / 1.0 s |
| preserved | bastion | Defeat / 5:39.6 | 2:33.2 / 3:00.7 | 2:23.7 / — | — / — | 212 / 56 | 1.0 / 1.5 s |
| preserved | helix | Defeat / 6:10.1 | 2:22.2 / 2:47.7 | 2:27.2 / — | — / — | 196 / 56 | 1.5 / 2.5 s |
| accepted | bastion | Victory / 15:13.9 | 1:59.2 / 2:24.7 | 2:25.7 / 8:56.2 | 6:00.2 / 6:52.2 | 708 / 254 | 5.5 / 1.5 s |
| accepted | helix | Defeat / 6:34.6 | 2:24.2 / 2:49.7 | 2:28.7 / — | — / — | 187 / 64 | 1.5 / 1.5 s |

The final `accepted` pair has 2617 sampled AI coordination checks with no recorded violations. Bastion reaches a completed victory; Helix loses before an assault or expansion. This is evidence of a functioning paid recovery/economy loop in one contested match and an unresolved opening/strategy problem in the other, not acceptance of overall pacing. Next work should inspect the Helix opening loss and compare defensive decisions in repeated ordinary starts before changing faction values.

`recovery-guidance-final-source.json` records the shipping scripts/scenes, project configuration and seven changed/new verification files. The accepted runner and final commander/test sources are retained beside the report. No commits, publication or persistent instruction changes were made.
