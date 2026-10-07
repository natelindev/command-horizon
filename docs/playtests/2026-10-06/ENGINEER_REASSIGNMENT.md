# Safe work after engineer withdrawal

The reference commander now has a separately selectable experimental policy for spaced retreat destinations and safe alternative work. All three factions pass controlled withdrawal/delivery/reassignment checks. Earned Frontier and Helix battle archives also complete real collection and delivery after reassignment. This establishes the mechanism; complete-match strategy acceptance remains open. No shipping gameplay, faction balance or automatic behavior for player-controlled engineers changes in this pass.

## Policy and source scope

`EngineerReassignmentPolicy.gd` extends the earlier `EngineerSafetyPolicy.gd`. It rejects retreat endpoints that overlap another protected engineer's destination or a friendly unit's footprint. It retains the existing sixteen candidate points around completed HQs, navigation projection/path checks, observed-threat filtering, six-second quiet interval and ordinary Move/HQ gather orders.

If original work is unsafe or unavailable after delivery, it tries a safe field in the original resource channel, then the other channel. Resource locations are public map objectives; threat decisions use current allied observation. The selected deposit must be harvestable, have a safe HQ approach and pass a navigation-route check from the worker. With no safe alternative, the worker remains protected from ordinary economy reassignment. Successful reassignment uses the normal gather order and resource prices/timers remain unchanged.

The original policy gained two default-preserving extension points for endpoint availability and work resumption. `EngineerSafetyMatches.gd` and its regression gained a selectable script path; their defaults still use the original policy. New matches use `EngineerReassignmentMatches.gd`. Before sources are retained in [engineer-reassignment](engineer-reassignment/), alongside logs, complete records, archives and captures. Earlier manifests remain historical records; sources changed in this pass have before copies here.

This remains a bounded strategy: it searches HQ-side retreat points rather than arbitrary escape locations, does not guarantee safe traversal during the initial retreat, and tests the economy helper's preferred deposit in each resource channel rather than exhaustively searching every safe field. It does not coordinate a defending army or assure HQ survival. Construction may be postponed in favor of safe gathering. Alternative orders return to the ordinary reference commander's authority once issued.

## Controlled original failure and regression

`EngineerReassignmentRegression.gd --original-policy` exits one with exactly fifteen expected failures: three overlapping destination pairs, an unsafe original field leaving its worker idle, and no fresh alternative-field income, for each of Bastion, Helix and Frontier. Initial cargo still arrives. This is a deliberately failing characterization of the old policy, not a shipping regression.

The same scenarios with the revised policy exit zero with zero failures. Each faction assigns three separated destinations. With the original field kept visibly contested, the loaded engineer returns normally, deposits its initial 3 M / 1 E, selects a safe material field and deposits another 4 M. Owner material income is therefore 7 M, electronics exactly 1 E, and total deposit material stock declines. Original hidden-contact, unchanged-cargo/funds, repeated-order stability and original-field resumption checks also pass.

These fixtures use an Advanced Desert Frontier setup with controlled raiders and an explicit friendly scout observing the contested field. Friendly neighboring actors retain live avoidance. Fixtures add actors/cargo for isolation; the complete matches and earned native archives below use ordinary paid play without those grants.

## Paid-match observations

Four observations use Coastal Foundry, Standard start, Normal shipping AI, screened-air production and combined research. Each pairing runs recorded seeds 4110 and 4111. All purchases, production timers, finite-field income and enemy AI remain ordinary. Repeated seeds do not make asynchronous navigation deterministic, and two observations per pairing do not support a general balance claim.

| Reference → opponent | Seed | Outcome / seconds | Engineers lost | Collected M / E | Alternative / delivery episodes |
| --- | ---: | --- | ---: | ---: | ---: |
| Frontier → Helix | 4110 | Victory / 801.0 | 3 | 630 / 190 | 9 / 30 |
| Frontier → Helix | 4111 | Unresolved at 30:00 / 1800.7 | 11 | 835 / 380 | 7 / 37 |
| Helix → Frontier | 4110 | Defeat / 343.6 | 15 | 228 / 73 | 3 / 2 |
| Helix → Frontier | 4111 | Defeat / 806.6 | 12 | 548 / 134 | 11 / 20 |

The Helix command exits zero after two defeats. The Frontier command exits one because its second match fails the explicit result requirement at the 30-minute bound; that run is retained as unresolved, not counted as a completed match. There are no script/parse errors. Order-authority checks total 10,599 and AI coordination diagnostics report no violations across 7503 samples.

The unresolved Frontier snapshot retains thirteen combatants in recovery. Four infantry have approximately 14.8%, 32.9%, 21.8% and 4.5% health, while the other nine combatants are full health. This leaves average army health around 74.9%, below the existing 80% assault gate. The reference conventional-unit branch issues periodic guard attack-moves after reaching its recovery point; it does not hold these soldiers at their Barracks until healed. The next step is to reproduce and verify the recovery handoff from the retained archive before changing it. The separate first 15-second stationary-travel trigger saved `reassigned-2-stationary.json` for `unit-16`, an infantry AttackMove; the final sampled maximum was 16 seconds. The twenty-second intact replay remained in AttackMove, with at most 0.426 m displacement at sampled points. Another infantry occupied its projected endpoint at (18.6, 0, 41.1). The isolated replay reached WaitingForTargets by five seconds, after 0.571 m displacement. Both replay commands exit zero as observations; the intact replay is not a passing arrival test. This narrows the next movement investigation to crowded destination handling, alongside conventional infantry recovery.

An episode can span movement, waiting and cargo delivery; it is not an idle-time measure or a distinct worker count. Alternative assignments and delivery flags count episodes. Detailed authority, coordination and stationary-travel observations are retained in `summary.json`.

The [previous investigation](ENGINEER_SURVIVAL.md) retained established-policy Frontier victory at 1193.3 seconds, established-policy Helix defeat at 529.1 seconds, and original retreat-policy defeats at 457.6 / 802.1 seconds. Those are separate observations, not deterministic paired controls. The new controlled regression supports the specific spacing/work-resumption improvements; complete-match outcomes do not isolate their causal effect.

## Earned native continuation

`EngineerReassignmentPreview.gd` restores a supplied normal disk archive and selects an explicit archived engineer while paused. Selection must preserve clock, funds, action and pending order. A native Space resumes the live enemy AI and existing orders for twenty simulation seconds; the test reference commander is not reconstructed. No position, cargo, health, resources or enemy behavior is injected after loading.

| Archive / worker | Elapsed | Displacement | Maximum material cargo | Newly delivered near HQ | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| `earned-6-case6-10-worker_alternative.json`, `unit-4` | 20.033 s | 9.945 m | 4 M | 4 M | Alive, then carrying another load |
| `earned-2-case2-10-worker_alternative.json`, `unit-1` | 20.017 s | 12.586 m | 4 M | 4 M | Alive, approaching its next work slot |

Both selected workers began with empty cargo and a pending resource gather order. Delivery observation counts a positive-to-zero cargo transition near a friendly HQ; it does not attribute other workers' income to the selected worker. Both native logs exit zero with zero failures. Four 1280×720 captures at 150% interface scale and normal fog were reviewed. Assigned destination routes, cargo status and continued battlefield activity are readable. These short continuations demonstrate real work resumption, not successful full-match defense.

## Reproduce and remaining work

Use fresh output paths and capture prefixes. The regression intentionally supports a failing original-policy comparison.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/EngineerReassignmentRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/EngineerReassignmentRegression.gd -- --original-policy
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/EngineerReassignmentMatches.gd -- --case=6 --repeats=2 --research=combined --strategy=screened-air --output=res://tmp/reassigned-6.json --archive=res://tmp/reassigned-6-stationary.json --archive-prefix=res://tmp/reassigned-earned-6
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/EngineerReassignmentPreview.gd -- --archive=res://docs/playtests/2026-10-06/engineer-reassignment/earned-6-case6-10-worker_alternative.json --unit=unit-4 --captures=res://tmp/reassignment-helix-native
```

Case 2 is Frontier→Helix; case 6 is Helix→Frontier. The native preview requires one Space input. Format/lint checks pass for all seven affected test scripts, with clean repository whitespace checks. Known navigation-readback and renderer/ObjectDB shutdown diagnostics remain separate from script/assertion failures.

In the first Helix run, contact was recorded at 142.7 seconds, its tank was lost at 159.45 seconds, and basic programs unlocked at 164.7 seconds without a first running program. At the 180.7-second sample it had four infantry and no tank against six infantry and three tanks. This supports investigating the defensive opening and replacement budget before changing faction statistics.

The next investigation is defensive strategy under sustained home pressure, including the availability of safe HQ-side destinations and whether army allocation protects income long enough to reach programmed units. Broader strategy/pacing, environment, novice/platform and release acceptance remain open. Performance optimization stays deferred; the overall goal remains active.
