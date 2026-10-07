# Engineer survival under sustained raids

Four complete paid matches expose a reference-policy problem: withdrawing engineers and delivering their cargo does not by itself restore a working economy. The experimental policy is retained for diagnosis, not accepted as an improved commander. This pass changes test/reference code only; shipping movement, balance and player orders are unchanged.

## Complete matches

All runs use Coastal Foundry, Standard start, Normal shipping AI, screened-air production, combined paid research and recorded seed 4110. One observation per policy/pairing is insufficient for a balance or causal conclusion; Godot navigation and asynchronous setup are not fully deterministic. Every run reached the ordinary game result, exited zero and had no script errors.

| Reference → opponent | Engineer policy | Result / simulation time | Engineers lost | Collected M / E | First program / assault |
| --- | --- | --- | ---: | ---: | --- |
| Frontier → Helix | Established | Victory / 1193.3 s | 7 | 826 / 360 | 154.7 / 576.7 s |
| Frontier → Helix | Retreat/deliver/resume | Defeat / 457.6 s | 6 | 132 / 65 | Neither |
| Helix → Frontier | Established | Defeat / 529.1 s | 19 | 354 / 136 | 157.2 s / none |
| Helix → Frontier | Retreat/deliver/resume | Defeat / 802.1 s | 8 | 517 / 99 | 163.7 / 240.2 s |

The protected Frontier run recorded seven withdrawal episodes: six ended in loss and one resumed work; one recorded cargo delivery. Helix recorded 35 episodes: 28 resumed, one released the worker for assignment and six ended in loss; twelve recorded delivery. These are episodes, not distinct workers. Total time inside the policy was 1271.5 and 1976.0 worker-seconds respectively, including travel, waiting and delivery; it is not a pure idle-time measure.

The ordinary reference economy preserved protected orders across 2543 Frontier and 3952 Helix checks. Shipping AI coordination diagnostics reported no violations over 2387/1058 baseline and 915/1604 protected samples. Longest sampled stationary travel intervals were at most 5.5 seconds; the 15-second failure archive threshold was not reached. This does not establish that retreat routes were efficient or safe.

Raw records and logs are in [engineer-survival](engineer-survival/), with a compact [summary](engineer-survival/summary.json). `baseline-2`, `baseline-6`, `protected-2` and `protected-6` identify the four rows above.

## Declared experimental policy

`EngineerSafetyPolicy.gd` uses currently observed compatible threats through the shipping economy helpers. A threatened worker receives an ordinary Move to the shortest reachable candidate among sixteen points around a completed friendly HQ. Both endpoint and HQ must currently be outside the helper's threat margin. The policy retains the original gather/construction target and cargo, waits for six seconds without a nearby threat, delivers existing cargo through an ordinary HQ gather order, then resumes the original target only when its approach is considered safe. A missing/depleted/completed target releases the worker for assignment.

Protected workers are excluded from the reference economy's harvesting, HQ reconstruction, expansion and airfield-builder selection. The default `_economy_workers` hook returns the same Worker set as before; established commanders retain their existing behavior.

Known strategy limits are consequential: destinations are not reserved across workers, safety is checked at the destination rather than along every route segment, and an unsafe original field can leave a worker waiting indefinitely instead of choosing another field. Many Frontier episodes selected the same initial HQ-side point. The observed income collapse and native crowding make destination spacing and safe alternative work the next reference-policy work. Neither fewer casualties nor successful cargo delivery passes sustained-economy acceptance.

## Controlled regression and corrected diagnosis

`EngineerSafetyPolicyRegression.gd` passes for Bastion, Helix and Frontier: hidden raiders cannot trigger retreat; visible threats issue ordinary Move; cargo and funds remain exact; repeated decisions do not churn orders; removing the threat permits delivery, original-field resumption and newly harvested income. It also checks reduced total material stock and exact initial electronics delivery. The controlled enemy and commander are disabled; neighboring friendly actors retain normal processing and avoidance.

The first fixture froze whole neighboring actors. That produced an apparent Bastion gathering stall, retained in `policy*.log` and `stalled-*.json`. Replaying the same archived scene with normal neighboring avoidance resumed gathering and delivery; an isolated replay also progressed. The initial movement-rule hypothesis was therefore not established. `Movement-before.gd.txt` matches the shipping file exactly, and no movement change was made. The accepted regression is `policy-live-neighbors.log`; the four earlier failed fixture logs are diagnostic evidence, not shipping failures. Earlier single-node stock checks were also corrected to count the whole material stock because harvesting may select another node in the field.

## Native earned-state review

The protected matches retained first withdrawal and first recorded cargo-delivery archives for both factions. `EngineerSurvivalPreview.gd` restores those ordinary disk archives, selects a matching worker while paused, checks that selection leaves time/funds/action/queue unchanged, then requires native Space for a two-second continuation with live enemy AI. The test reference commander is not restored; this reviews existing orders and battle state, not a continued complete reference strategy.

The accepted `native-verified.log` exits zero with zero failures. All eight 1280×720 captures were reviewed at 150% interface scale and normal fog. Selected withdrawal workers survived 2.017 seconds: Frontier moved 0.110 m amid the base crowd; Helix moved 5.762 m. The selected empty carriers visibly showed “Cargo delivered · choose a resource field” and remained stationary over that interval. These observations verify live restoration and readable state, not successful escape or future income.

`native.log` is rejected: its selector required a pending gather order even after delivery had completed, and later captures did not retain the intended window size. `native-final.log` is incomplete: its five-minute wall deadline expired before the final continuation. Both logs and source versions are retained. The accepted preview restores window size after each load and selects an empty carrier whose gather action needs assignment in delivery archives. Archive selection does not track a unique episode identity.

Known navigation-readback and renderer/ObjectDB shutdown diagnostics remain in the logs. They are distinct from script/assertion failures. Format/lint checks pass for all seven changed test scripts; repository whitespace checks pass.

## Reproduce

Use new output/archive/capture paths. For established behavior use `PaidProgressionMatches.gd`; substitute `EngineerSafetyMatches.gd` for the experimental policy. Cases 2 and 6 are the reciprocal Standard pairings.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/EngineerSafetyPolicyRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/EngineerSafetyMatches.gd -- --case=2 --repeats=1 --research=combined --strategy=screened-air --output=res://tmp/engineer-protected-2.json --archive=res://tmp/engineer-protected-2-stationary.json --archive-prefix=res://tmp/engineer-earned-2
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/EngineerSurvivalPreview.gd -- --captures=res://tmp/engineer-survival-native
```

The native preview intentionally reads the four retained archives from this evidence directory and requires four Space inputs. The broader gameplay goal remains active. Performance optimization remains deferred.
