# Recover unfinished-building funds

The battle plan previously ignored cancellation refunds from unfinished buildings. It could report that an HQ rebuild lacked funds even when reclaiming the unused cost of another foundation would pay for it. It also overlooked this source when a player with an intact HQ needed to replace their last engineer.

Only `EconomyAdvice.gd` changes in shipping code. HQ affordability now totals current funds, paid production, paid research and live construction refunds. The existing `construction_refund()` calculation supplies each building's remaining, currency-specific amount; completed, dead and queued-for-deletion structures contribute nothing. Advice still refuses to promise HQ recovery when combined funds leave either currency short.

When construction funds are useful, the battle plan names the unfinished building and its current refund. **Review foundation** selects it and focuses the camera; **Cancel construction** remains the player's explicit decision. Reviewing advice does not change funds, construction orders or progress. Existing production/research review has priority, and the next recommendation is recalculated after each cancellation. A paid HQ foundation retains its continue-building guidance.

## Verification scope

Two final runners against the exact preceding 288-script baseline fail thirty expected assertions: six affordability/selection assertions and twenty-four combined-refund/replacement assertions. Neither final negative run has script or parse errors.

The earned-budget path starts with the ordinary 60 M / 12 E, assigns three starting engineers to existing nearby deposits and earns a 120 M / 32 E bank through actual harvesting and delivery. It purchases and completes the required barracks, then buys a factory and constructs it to at least 20%. Worker positions, cargo and resource balances are not injected on this path. The opponent's strategic loop is disabled and HQ destruction is injected while paused to isolate the recovery decision. This is earned-resource recovery under a controlled loss, not survival of an attacking opponent.

After HQ loss, the factory's refund makes recovery possible. A real disk save/load preserves paused time, progress and deadline. Explicit cancellation returns the quoted resources; ordinary paid placement and engineer travel/construction rebuild the HQ within the sixty-second defeat window. Separate isolated boundaries test insufficient total funds, a missing currency, exact floor-rounded affordability and destruction. Combined fixtures cover production plus foundation, research plus foundation, multiple foundations, selection authority and replacing the final engineer. Those boundary/combination fixtures supply units and funds and are distinct from the earned-resource path.

Seven final headless suites pass: FoundationRecoveryRegression, FoundationRefundAdviceRegression, EconomyRecoveryRegression, HQCountdownRegression, ConstructionContractRegression, BattlePlanRegression and ReferenceEconomyRegression. Formatting and lint pass; final accepted runs have no script or parse errors.

The rendered earned Helix run also passes. Three engine-injected button clicks cover Review foundation before/after disk restoration and Cancel construction. All four 1280×720 / 150% UI-scale captures were inspected: refund, restored, rebuilding and recovered. The plan and selection panel agree on the 35 M / 9 E refund; the HQ placement leaves 10 M / 9 E and ordinary construction restores the completed HQ before defeat. The selected building, guidance and controls remain visible and readable. Selection elsewhere and placement are programmatic; native OS input is not claimed.

## Retained development failures

The first fixture attempted factory placement without its barracks prerequisite, then dereferenced the missing foundation. Its advice-only run and interrupted earned run are rejected; source and logs remain. The corrected earned fixture reached the third faction before the inherited 600-second aggregate timer expired. The final runner uses a 1200-second aggregate timer for three sequential earned openings; individual harvesting/construction deadlines are unchanged. The first combined-refund fixture omitted the factory prerequisite for Coordination and assumed all factions pay six materials for infantry. It is rejected and retained. The corrected fixture satisfies research prerequisites and uses the production entry's actual paid cost, including Frontier's cheaper infantry.

## Reproduction

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/FoundationRecoveryRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/FoundationRefundAdviceRegression.gd
```

Pass `-- --advice-only` to the first runner for a short controlled affordability check. Use `tests/rendered/FoundationRecoveryPreview.gd` without `--headless`, with a new `-- --captures=res://tmp/foundation-recovery` prefix, for the earned Helix UI path.

Evidence is retained in `foundation-recovery/`, including source versions, final positive/negative results, rendered review, classifications, source fingerprints and hashes. Existing navigation-readback warnings and shutdown ObjectDB/resource/RID diagnostics remain.

The earlier Industrial loss had no affordable rebuild or refundable production; this change does not establish that it was recoverable through a foundation. Reference-economy HQ priorities, sustained Industrial defense/progression, broad content/novice/platform acceptance and congestion remain open. Performance remains deferred.
