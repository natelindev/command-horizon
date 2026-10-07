# Conventional infantry recovery through recommitment

The reference commander can now preserve infantry treatment through guard, regroup and assault transitions, then return healed soldiers to combat. The earned unresolved army that previously stayed below its assault health gate now crosses that gate and returns all four wounded infantry to the assault. This is explicitly selected reference-policy work; shipping healing rates, faction statistics, programmed-unit behavior and player automation are unchanged.

## Actual commander failure and correction

The prior [crowded AttackMove pass](ATTACK_CROWDED_ARRIVAL.md) showed that ordinary Barracks service could heal the four infantry in `reassigned-2-unresolved.json`, but their saved orders never brought them through treatment. `ConventionalRecoveryRegression.gd` now runs the actual `SkirmishDefensePolicy` command loop every half simulation second against that earned army. It restores the recorded recovery phase and pressure time, uses the known defense point and marks already running programs as configured so the test does not replace their authored program. Strategic player processes are disabled; existing actors and battlefield orders remain live. Economy/production and the full test commander are not reconstructed in this focused replay.

With `--original-policy`, none of the four infantry heals or rejoins an assault over 120 seconds, and the army remains in recovery. The harness exits one with three expected assertions. With the new policy, the army enters attack after fourteen seconds at 80.26% average health. The four wounded soldiers remain protected while the rest of the army advances, reach the ordinary service exit threshold and all rejoin the assault by 36.5 seconds. Their release health is 80.21–80.97%; 292 command-loop checks preserve their treatment actions. The regression exits zero.

`ConventionalRecoveryPolicy.gd` starts safe, reachable Barracks treatment below 40% infantry health during ordinary operations and below 80% while regrouping. It reuses shipping `RecoveringAtService` and `SkirmishRecovery` rules for service eligibility, current observed danger, blocked retry, replacement facilities and the 80% treatment exit. It excludes armored/programmed units. Active treatment is preserved in the existing commander's attack-entry, regroup and per-unit guard loops. Its old `retreating` marker is cleared when treatment takes ownership, allowing healed infantry to receive ordinary combat orders again.

`ConventionalRecoveryMatches.gd` enables this behavior on top of engineer reassignment. Earlier reference scripts retain their original default. Each match receives fresh policy state and records treatment episodes, results and command-authority checks. First-treatment and first-ready archives use the normal paused disk snapshot API without adding resources, health or units.

## All-faction service and authority checks

`ConventionalRecoveryPolicyRegression.gd` passes for Bastion, Helix and Frontier. It verifies distinct active-operation/regroup health thresholds, unchanged armored-unit orders, no hidden-enemy influence, blocked treatment when a threat becomes visible, frozen retry time and stable orders while paused, safe replacement Barracks after facility loss, real healing, release after treatment and unchanged stockpiles. Friendly neighboring actors retain normal avoidance. These are controlled Advanced Desert Frontier fixtures with deliberately wounded infantry, a controlled raider and a replacement facility, not paid-match outcomes.

The first harness launches had parse errors: a dynamic script constant was used as a static `is` type, then a formatted multiline lambda caused an indentation parse failure in the separate fixture. Their zero process exit codes do not constitute passes. `original-parse-error.log`, `recovery-parse-error.log` and `policy-parse-error.log` are retained and rejected. Accepted logs are `original.log` for the expected failing characterization, and `recovery.log` / `policy.log` for the corrected regressions.

## Repeated paid matches

All four runs use Coastal Foundry, Standard start, Normal shipping AI, screened-air production and combined paid research. Each pairing uses recorded seeds 4110 and 4111. The current shipping crowded-AttackMove fix is present. These runs therefore do not isolate the recovery policy from all changes since older observations; asynchronous navigation also prevents deterministic paired comparisons.

| Reference → opponent | Seed | Outcome / seconds | Collected M / E | Ready / lost treatment episodes | Infantry lost |
| --- | ---: | --- | ---: | ---: | ---: |
| Frontier → Helix | 4110 | Victory / 1181.7 | 885 / 344 | 29 / 17 | 29 |
| Frontier → Helix | 4111 | Defeat / 1061.0 | 678 / 252 | 7 / 5 | 26 |
| Helix → Frontier | 4110 | Defeat / 967.8 | 427 / 157 | 3 / 3 | 29 |
| Helix → Frontier | 4111 | Defeat / 434.2 | 200 / 82 | 0 / 0 | 12 |

Both match commands exit zero after real results, with no script/parse errors. The command loop preserves treatment across 3181 checks and engineer control across 6713 checks. AI coordination reports no violations over 7289 samples. The longest sampled stationary travel interval is 6.5 seconds; no fifteen-second movement archive is triggered. These are bounded observations, not proof that all movement is stall-free.

Treatment counts are episodes, not distinct soldiers. A ready episode records release at or above the service threshold; it does not by itself prove later survival or damage dealt. Full outcomes, policy checks and AI coordination/stationary-travel observations are retained in `summary.json`. Successful recovery does not establish a generally winning strategy or faction balance.

## Native earned-state review

`ConventionalRecoveryPreview.gd` restores the first-treatment archive from each pairing's first match, selects an infantry with the existing recovery action, and checks unchanged paused time, health, action, funds and queue. Native Space runs each scene for approximately 45 simulation seconds with live enemy AI. The test reference commander is not restored, so this checks ongoing treatment rather than its later strategic recommitment.

The selected Frontier soldier starts at a displayed 7/19 HP and the selected Helix soldier at 3/18 HP. Both survive, reach full health and finish in WaitingForTargets during 45.000 / 45.017 seconds. The four 1280×720 captures at 150% interface scale and normal fog were reviewed. The native log exits zero with zero failures. The actual commander regression above supplies the separate return-to-assault evidence.

## Reproduction and limits

Use fresh output paths and capture prefixes. Raw logs, before-policy source, earned archives and captures are in [conventional-recovery](conventional-recovery/). The original-policy command is intentionally expected to fail.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ConventionalRecoveryRegression.gd -- --original-policy
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ConventionalRecoveryRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ConventionalRecoveryPolicyRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/ConventionalRecoveryMatches.gd -- --case=2 --repeats=2 --research=combined --strategy=screened-air --output=res://tmp/recovery-2.json --archive=res://tmp/recovery-stationary.json --archive-prefix=res://tmp/recovery-earned
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/ConventionalRecoveryPreview.gd -- --captures=res://tmp/recovery-native
```

Case 6 is the reciprocal Helix→Frontier pairing. The native preview reads the retained first-match archives and requires two Space inputs. Six affected scripts pass format/lint, and repository whitespace checks are clean. Existing navigation-readback and renderer/ObjectDB cleanup diagnostics remain distinct from script failures.

The health-gate failure is verified at mechanism level. Weak defensive openings, sustained home pressure, army composition, resource allocation and broader full-match consistency remain open. These strategy observations do not justify automatic changes to faction statistics. Broader player-facing recovery usability, environment, novice/platform and release acceptance also remain open. Performance optimization stays deferred; the overall goal remains active.
