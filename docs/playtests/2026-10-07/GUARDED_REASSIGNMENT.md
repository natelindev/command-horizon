# Guarded worker reassignment experiment

An opt-in reference commander requires a suitable friendly guard before reassigning a recovering engineer to resources more than 30 metres from HQ. It reuses the game AI's guard-presence rule: an owned armed mobile ground unit with at least 50% health within 10 metres of the resource. Observed-threat and route checks still apply. Safe home work can take priority when the original remote task lacks protection.

This is a reference-policy experiment, not a shipping AI or balance change. All 288 shipping GDScript fingerprints match the preceding arrival-window baseline. The ordinary reference policy retains a default-true eligibility hook. `GuardedWorkerMatches.gd` explicitly selects the guarded variant.

## Motivation and scope

The earlier Industrial archive recorded recovering workers reassigned across the map to resources near the enemy home, including positions (89.5, 12) and (92.5, 14). The shipping AI already gates distant economy work on expansion coordination and guard presence; reference recovery only checked known danger and route access. The new variant adds guard presence to recovery resumption and alternative selection. It does not add the shipping AI's coordination task requirement.

The guard is checked when assigning work. This policy neither escorts workers nor recalls them if the guard subsequently leaves. Routine reference economy orders and its separate scripted expansion remain outside this recovery hook. Alternative selection still considers the existing economy selector's preferred candidate per resource channel; it does not exhaustively search every guarded deposit. These limits matter before interpreting full-match outcomes.

## Verification

`GuardedReassignmentRegression` passes for Bastion, Helix and Frontier:

- An unguarded original remote task yields to safe local work. Depleted home resources cause waiting instead of an unguarded reassignment.
- Foreign units, aircraft, wounded guards and distant guards do not authorize the remote task. A healthy arrived friendly ground guard does; observed danger still rejects the unsafe resource.
- Planning preserves orders and funds. Actual gathering uses normal manual-order descriptors, harvesting and HQ delivery, with finite material conservation.
- An in-flight trip survives a real disk save/load. Pause preserves the clock, position, cargo and action. After resuming, real four-material deliveries complete in approximately 21.57, 18.57 and 19.92 seconds, within the unchanged 120-second deadline.
- Inherited all-faction observed/unseen threat, loaded withdrawal, return-before-resume and safe alternative-income cases pass using the guarded policy.

The final original-policy control fails exactly fifteen guard assertions, five per faction. Its inherited checks and all three actual deliveries pass. The shared default `EngineerReassignmentRegression` also passes. Formatting and lint pass for all four changed/new reference and test scripts. Final runs have no script or parse errors; existing runtime navigation-readback and shutdown resource/ObjectDB/RID diagnostics remain.

The disk test verifies issued shipping orders, not persistence of the reference commander's private recovery-policy state. No UI change, rendered review or native-input acceptance is claimed.

## Complete paid matches

Both runs use current shipping code, Normal difficulty, Standard start, Industrial Crossroads, Helix versus Frontier, seed 4110, screened-air strategy and combined research. Purchases spend ordinary game resources. Both finish in defeat; neither launches the main assault.

| Measure | Ordinary recovery | Guarded recovery |
| --- | ---: | ---: |
| First basic unlock | 202.73 s | 188.73 s |
| First program | 280.23 s | 294.23 s |
| Defeat | 626.60 s | 472.90 s |
| Materials / electronics harvested | 518 / 135 | 294 / 102 |
| Materials / electronics spent | 531 / 144 | 349 / 76 |
| Longest sampled stationary travel, human / AI | 2.0 / 2.5 s | 2.5 / 1.5 s |

The guarded run's six recorded alternative recoveries choose the local (10.5, 62) field. The control includes a later remote alternative at (38.5, 92). The policy changes choices, but this one pair supplies no evidence of a stronger opening: programming is later and survival shorter in the guarded run. It stays opt-in. Both current-code runs reach programming, unlike the preceding pair; differing battle trajectories prevent attributing that improvement to one movement fix.

Reproduction:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/GuardedReassignmentRegression.gd
# Add: -- --original-policy for the fifteen expected negative assertions.
```

For the paid pair, use `tests/playtest/CautiousRelayMatches.gd` and `tests/playtest/GuardedWorkerMatches.gd`, each with `-- --case=6 --repeats=1 --research=combined --strategy=screened-air`. The retained JSON files contain complete metrics and earned checkpoints.

## Failed fixtures and remaining work

The initial regression incorrectly supplied a raw Node instead of the normal weak-reference/point order descriptor. It produced script errors and is rejected. The corrected descriptor exposed a separate fixture issue: the inherited cargo test starts west of HQ behind disabled units whose collision remains active. All three workers stalled near (16.4, 28.8), without collecting, through 120 seconds. The diagnostic logs and source remain retained. This frozen-army congestion was not repaired or counted as passing.

The final isolated policy fixture places the carrier eight metres from HQ toward the same remote deposit, keeping the rest of the setup, real trip, reload and deadline. This bounds what the policy test establishes; it does not establish arbitrary crowd escape. The corrected original-policy control completes identical trips, separating its expected eligibility failures from that fixture obstruction.

Evidence is in `guarded-reassignment/`: rejected source/logs, ten classified Godot runs, complete paid metrics and checkpoints, source fingerprints and SHA-256 inventory. Industrial sustained defense, successful progression, general congestion and broader release acceptance remain open. Performance remains deferred.
