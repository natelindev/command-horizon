# Restore reference electronics assignments after retreat

The preceding earned match shows the reference economy falling to zero or one electronics engineer while its surviving workers stay busy on materials. Safe retreat fallback can change an electronics worker to a material field. The ordinary reference allocator repairs the split only through idle/unassigned engineers, so a busy fallback route can remain permanent even with a large material surplus.

An opt-in `ElectronicsHandoffPolicy` restores the existing opening split: one electronics engineer with three/four workers, two with five or more. It counts an already-queued electronics order once. When the split is short, it explicitly queues a gather order behind a loaded material return. Cargo is delivered before the new resource assignment begins. It preserves protected retreat/delivery orders and existing queues, uses currently observed threats and reachable paths, and requires an arrived friendly ground guard at remote deposits beyond thirty metres from HQ.

This is a reference commander's explicit decision. All 288 shipping scripts match the preceding baseline. Human harvest actions still stay within their assigned resource type and field; they do not silently switch to electronics. Default reference behavior also remains unchanged; the new complete-match runner requires `--electronics-handoff` to enable this policy.

## Verification

`ElectronicsHandoffRegression` passes for Bastion, Helix and Frontier. Starting engineers collect a real four-material load, queue a safe electronics handoff, preserve the in-flight action and cargo, and perform an actual disk save/load. Pause preserves funds, clock, cargo and the pending target. The engineer then delivers four materials followed by four electronics in 16.25 / 15.32 / 15.72 simulation seconds after the saved point, within the unchanged 120-second deadline.

Additional controlled checks cover protected orders, existing manual queues, absence of available electronics, exact opening quota, rejection of unguarded remote fields, acceptance with a friendly ground guard, and rejection after an observed enemy threatens that field. The disabled-handoff control fails six expected acceptance assertions and has no script errors. It disables the new hook; it is not a historical shipping-source comparison.

The final policy regression, earned continuation, SkirmishLaborRegression, SkirmishHandoffRegression and EngineerReassignmentRegression all pass. Formatting and lint pass. Accepted Godot runs have no script or parse errors. Existing navigation-readback warnings and shutdown ObjectDB/resource/RID diagnostics remain.

## Earned battle continuation

The final full match records a queued handoff at 309.23 seconds. Two continuations restore that exact earned checkpoint with the opponent's strategic AI still active. No funds, units, resource stock, sight or positions are added. Existing human orders/programs continue; the external reference commander's private decision loop is not restored.

- Clearing only the pending handoff leaves the carrier on materials: it delivers 20 M / 0 E over sixty seconds and survives.
- Retaining the handoff delivers its carried 4 M and then 4 E in 28.78 seconds; the carrier survives. This branch stops at the first electronics delivery.

The unequal observation lengths are deliberate completion bounds, not comparative income-rate measurements. This pair verifies the specific queued order's effect under active battle conditions, not sustained defense or a match-winning economy.

## Complete paid matches

All three runs use Standard start, Normal difficulty, Industrial Crossroads, Helix versus Frontier, seed 4110, screened-air strategy and combined research. Purchases use ordinary resources and enemy AI stays live. All complete with valid defeat outcomes and zero unresolved harness checks.

| Measure | Disabled control | Final handoff policy |
| --- | ---: | ---: |
| Basic unlock | 180.73 s | 178.23 s |
| First program | 246.23 s | 200.23 s |
| First handoff | None | 309.23 s |
| Main assault | None | None |
| Defeat | 561.10 s | 566.80 s |
| Harvested M / E | 360 / 122 | 335 / 125 |
| Net spent M / E | 416 / 116 | 390 / 80 |
| Queued handoffs | 0 | 5 |

The opening/programming differences occur before the final policy's first issued handoff. They cannot be credited to that policy; runtime battle/navigation trajectories vary despite the same seed. The final run supplies no convincing survival or sustained-income improvement, so the helper stays opt-in and broader strategy promotion is not justified.

The first implementation incorrectly targeted two electronics engineers in the four-worker opening. That intermediate run issued a handoff at 6.73 seconds, reached programming at 238.73 seconds and assault at 321.73 seconds, harvested 754 M / 276 E, and lost at 854.90 seconds. Its game checks pass, but it changes the opening and cannot serve as verification of the final restoration-only policy. Its source, log, metrics and checkpoints are retained separately; the longer survival in one different trajectory is not a balance conclusion.

## Retained development failure

The first regression set all electronics stock to zero and then restored the numbers. Zero stock queues a deposit for deletion, so those deposits were still unavailable for the later positive trip. That run fails three handoff assertions and is rejected as a fixture. The corrected availability check temporarily removes/restores deposits from the resource query group while paused, preserving them for the real trip. The intermediate corrected runner passes before the remote-guard and observed-threat checks were added. All sources/logs remain in `electronics-handoff/` alongside the final evidence, shipping fingerprint and SHA-256 inventory.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ElectronicsHandoffRegression.gd
```

Add `-- --original-policy` for the disabled-hook negative. Use `tests/playtest/ElectronicsHandoffMatches.gd` with `-- --electronics-handoff --case=6 --repeats=1 --research=combined --strategy=screened-air` and fresh `--output`, `--archive` and `--archive-prefix` paths for a complete paid run. Omit the handoff flag for the control. `EarnedElectronicsHandoff.gd` uses the retained final checkpoint and refuses to overwrite its existing continuation output.

No UI change, rendered review or native-input acceptance is claimed. Sustained Industrial home defense, protection of resource routes through subsequent raids, general congestion and broader content/novice/platform acceptance remain open. Performance remains deferred.
