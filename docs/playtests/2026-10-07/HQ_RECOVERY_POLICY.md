# Contested HQ recovery reference experiment

A fresh complete paid Industrial pair tests whether reserving an HQ budget under pressure helps the reference player recover. It does not support promoting this policy: the experimental run loses earlier, never reaches programming and never buys a replacement HQ. All 288 shipping scripts remain identical to the preceding foundation-recovery baseline. This is a reference-controller experiment, not a player automation feature or balance change.

## Policy and boundaries

`HQRecoveryMatches.gd` defaults to observation only. `--hq-recovery` enables an opt-in reference policy. It protects the 80 M / 20 E HQ cost from ordinary new construction and troop purchases when every completed HQ is either below 60% health or endangered by currently observed compatible enemies. A healthy HQ outside observed danger releases the reserve. An already-paid HQ foundation does not reserve its cost a second time. Existing queue jobs continue; the rule is not a global spending lock, and existing chip-retrofit behavior remains inherited.

After HQ loss, the reference player follows existing recovery advice: cancel a useful paid production job, paid research or a useful non-HQ foundation, then attempt ordinary paid HQ placement. It excludes engineers protected by its retreat policy and those in observed danger. Candidate HQ sites must satisfy ordinary placement geometry, observed-threat and approach checks, and an estimated route/build time within the remaining defeat window. Travel estimates include a two-second margin but cannot predict future enemies or congestion. Paid foundations retain their existing constructor; an unassigned safe engineer may resume an abandoned one.

The policy is intentionally opt-in. The default commander is unchanged. The experiment's early reserve can compete with field defense and technology, and its release condition can spend the bank during a temporary lull. These are unresolved strategy choices, not reasons to change prices or give either player resources.

## Complete matches

Both runs use current shipping code, Standard start, Normal difficulty, Industrial Crossroads, Helix versus Frontier, seed 4110, screened-air strategy and combined research. They use ordinary paid purchases and live enemy AI. Both finish with valid defeat outcomes and zero unresolved harness checks.

| Measure | Ordinary reference | Recovery policy |
| --- | ---: | ---: |
| Basic program unlock | 203.23 s | Not reached |
| First program | 225.73 s | Not reached |
| First assault | 308.23 s | Not reached |
| Defeat | 637.80 s | 417.60 s |
| Harvested M / E | 568 / 92 | 380 / 98 |
| Net spent M / E | 463 / 94 | 373 / 56 |
| HQ-loss checkpoint | 578.23 s | 357.73 s |
| Funds at checkpoint | 216 / 10 | 67 / 54 |
| Replacement HQ purchases | 0 | 0 |

The experimental reserve first activates at 146.73 seconds with 95 M / 24 E. It later releases at 256.23 seconds while HQ is healthy and immediate observed danger is absent. The bank subsequently falls below the HQ price; renewed danger does not generate the missing resources. HQ dies with 67 M / 54 E. The weaker field force and earlier defeat in this one pair reject promotion, but differing battle trajectories do not isolate a single causal change or establish statistical balance.

## Earned checkpoint audit

Both HQ-loss checkpoints restore successfully while paused. The audit leaves resources, time, worker positions and orders unchanged. It uses ordinary geometry/nav paths and observed contacts, without adding resources, units or sight.

- Control: six surviving engineers, two outside observed danger, 216 M / 10 E in bank and one 6 M / 0 E production refund. No foundation refunds or active research. Sixty-two sampled sites satisfy static placement, observed approach and estimated deadline constraints, but none can cure the ten-electronics shortfall.
- Experiment: six surviving engineers, none outside observed danger, 67 M / 54 E in bank, no production/foundation/research refunds. No eligible safe-worker site is found.

The audit does not reconstruct the reference commander's private retreat-state dictionary from disk; its safe-worker counts omit that additional protection filter. Its site count is a static feasibility upper bound, not evidence of a travelled route, paid replacement, successful rebuild or defended escape. Neither earned checkpoint can afford HQ recovery through existing refunds. No contested rebuild is claimed.

## Regression and evidence

`HQRecoveryPolicyRegression` passes for all three factions: peaceful/damaged/observed-threat reserve conditions, unseen distant contacts, exact excess-budget limits, protected-engineer exclusion, timely versus late sites, abandoned-foundation assignment and preservation of an existing constructor. It also runs the inherited paid HQ crew-rate, manual/death handoff, paused disk, completion-before-defeat, cancellation and legacy construction checks. These are controlled fixtures, separate from the full paid matches.

The archive audit and both full-match runs pass. Formatting and lint pass. All four accepted Godot runs have no script or parse errors. Existing runtime navigation-readback warnings and shutdown ObjectDB/resource/RID diagnostics remain. No shipping/UI change, rendered review or native-input acceptance is claimed.

`hq-recovery-policy/` retains both complete metrics files, earned checkpoints, the observation-only runner used for the control, final experiment/test sources, all four logs, audit results, shipping fingerprints and SHA-256 inventory.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/HQRecoveryMatches.gd -- --case=6 --repeats=1 --research=combined --strategy=screened-air --output=res://tmp/hq-control.json --archive-prefix=res://tmp/hq-control
```

Add `--hq-recovery` and fresh output/archive paths for the experimental branch. Run `tests/headless/HQRecoveryPolicyRegression.gd` for isolated contracts. The retained `HQRecoveryArchiveAudit` intentionally refuses to overwrite its existing evidence file.

This closes the comparison, not contested HQ recovery acceptance. The next task is sustained home defense and protected electronics income before HQ loss, including whether an earned army can hold the Industrial opening and preserve a viable recovery window. Broad content/novice/platform acceptance and congestion remain open. Performance remains deferred.
