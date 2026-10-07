# Reinforcement and research pacing — 2026-10-06

An optional reference commander now defers optional technology upgrades while its eligible ground army is below the existing nine-unit assault requirement. Coordination keeps its original eligibility. The existing cautious relay policy remains the control; no shipping gameplay, prices, AI, health, income, terrain or attack thresholds change.

## What the retained record actually proves

The earlier Industrial match finishes unresolved at 1800.7 seconds with eight healthy ground combatants, no visible home threat and a long quiet period. It purchases optional research during that interval. However, its old human `production: []` telemetry was **not an empty request list**: `_research_snapshot` only populated opponent production requests. It cannot prove an idle factory or a production deadlock by itself.

The retained 1228.25-second archive has no paid jobs in the human vehicle factory, barracks or airfield, and human funds are **0 materials / 27 electronics**, with research active. This differs from the opponent's 72/14 resource-reserve issue fixed in the preceding slice. The audit therefore tests research/reinforcement competition rather than claiming a shipping queue defect.

`PaidProgressionMatches` now records actual human requests, every producer's paid jobs and remaining time, and queue blocking reasons. These fields are read-only observations. Human building/reserve fields were also previously unmeasured zero/empty placeholders; the finalized telemetry emits `null` for these unknown fields. The comparison-run source snapshot retains the earlier placeholders, and their zero values must not be interpreted as measured reserves. The final telemetry regression checks the real request, paid queue, unknown markers and absence of budget/queue mutation. Earlier reports remain historical evidence with this explicit interpretation correction.

## Optional policy and focused verification

`ReinforcementFirstMatches` derives from the cautious relay reference. When its existing research selector proposes an optional upgrade, it withholds that proposal until `_policy_army()` contains nine eligible ground combatants. That uses the same army membership as the attack gate, excluding currently protected expedition members. Coordination is still selected under its previous prerequisites; already-paid research continues. This changes reference purchasing decisions only and introduces no save feature or automatic player behavior.

The [all-faction regression](reinforcement-pacing/final-regression.log) stages six infantry and two ground vehicles, the required completed facilities and exact funds for one fitted tank. The existing policy reserves an optional upgrade and buys nothing; the variant pays exactly for the ninth combatant. It checks the refund, resumes optional research when the ninth eligible unit exists, excludes an expedition member and preserves Coordination access. Paused disk reload preserves exact queue time and funds. Real paid tanks then arrive after **25.017 / 25.017 / 23.017 seconds** for Bastion / Helix / Frontier.

The initial fixture cancelled its first tank and then attempted to repurchase using the advanced production-sequence slot, which requested a different, unaffordable unit. Its subsequent invalid queue read cascaded into additional live-match errors. That run exited zero despite script errors and is explicitly rejected. The corrected isolated repurchase resets the fixture's sequence, verifies the queue before indexing, and cleans up after failures. Final regression has no script/parse errors; failed evidence is retained. Formatting and lint pass. Existing navigation-readback and shutdown resource/RID diagnostics remain.

## Retained live archive comparison

The [paired archived-state audit](reinforcement-pacing/archive-audit.json) restores the same earned 1228.25-second battle for each policy, preserves actors, funds, paid research and existing unit actions, and runs only reference purchasing decisions every half second for 300 simulation seconds. Other player decisions remain disabled; combat, harvesting and production continue. The reference production sequence is explicitly reset to slot zero in both branches because commander bookkeeping is not part of a shipping save. This isolates budget competition; it is not a recreation of every decision in the original full match.

| Budget policy | First new ground unit | First nine ground units | Ground army after 300 s | Actual purchases, materials / electronics |
| --- | --- | --- | --- | --- |
| Existing upgrade priority | None | None | 7 | 65 / 40 |
| Reinforcement priority | 92.0 s | 156.0 s | 9 | 92 / 61 |

The control spends on Combat armor I and Field service; its final real request list still includes a fitted tank. The variant delivers new combatants and resumes optional research after reaching the gate. No funds or units are granted. The two final battle archives are retained alongside samples of requests, queues, timer values and research orders. Both branches complete the 300-second observation without script/parse errors. Physics and live combat can vary, so these values are one paired observation, not a deterministic timing guarantee.

## Complete paid matches

Four current-code paid Standard/Normal trials use seed 4110, combined research, screened-air production, early depot, two opening tanks and the existing cautious relay behavior. Only the optional research selector differs between paired policies.

| Map / reference faction | Policy | Result / time | First program | First main assault | Main assaults / regroups | Own units and structures lost |
| --- | --- | --- | --- | --- | --- | --- |
| Alpine / Frontier | Existing | Victory / 485.5 s | 277.2 s | 291.7 s | 1 / 0 | 11 |
| Alpine / Frontier | Reinforcement first | Victory / 1531.2 s | 265.7 s | 670.7 s | 6 / 5 | 59 |
| Industrial / Helix | Existing | Defeat / 664.6 s | None | None | 0 / 0 | 30 |
| Industrial / Helix | Reinforcement first | Defeat / 293.1 s | None | None | 0 / 0 | 19 |

All four reach real outcomes and exit zero without script/parse errors. There are zero AI coordination violations across 5,948 samples. [Comparison records](reinforcement-pacing/comparison.json) link the exact timings and research events; the full records retain requests, queues, battle results and earned archives.

The variant demonstrates repeated assault/regroup completion in Alpine, but takes much longer and loses substantially more forces in this observation. Neither Industrial run reaches programming. The comparisons do **not** establish a stronger opening or support promoting the variant as the default. Navigation/setup timing is nondeterministic, and even the policies' unchanged early-game periods diverge. The causal conclusion remains the isolated budget competition shown above.

Longest sampled stationary travel is 5.0 / 7.5 / 22.5 / 3.5 seconds for the four reference armies in table order; opponent maxima are at most two seconds. The longer Industrial control episode is retained as another congestion observation, not silently counted as solved. No new shipping movement change is made.

## Scope and reproduction

Shipping source fingerprints match the preceding resource-reserve slice. The variant is an opt-in reference experiment; it does not silently change the existing cautious policy. The broader goal remains active, including home defense, strategic pacing, novice/content/platform acceptance and remaining map/visual work. Performance stays deferred.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ReinforcementResearchRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/ReinforcementFirstMatches.gd -- --case=6 --repeats=1 --research=combined --strategy=screened-air --output=res://tmp/reinforcement-new.json
```

Logs, earned archives, source snapshots, [run classifications](reinforcement-pacing/run-results.json) and [artifact hashes](reinforcement-pacing/SHA256.json) are retained. Use fresh output paths for further audits.
