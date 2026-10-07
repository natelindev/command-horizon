# Repeated Industrial defense comparison

Twelve paid Standard-start Industrial matches produce two reference victories, including one at **28:52** with repeated assault and recovery. The results do not support promoting either experimental policy as a general improvement. Shipping rules, costs, geometry and the default reference commander remain unchanged.

## Method

Each variant runs seeds 4110, 4111 and 4112 as Helix versus Frontier, Normal difficulty, screened-air strategy and combined research. Starting resources, production, construction, enemy AI, programs, service and outcomes use ordinary rules. `SustainedDefenseMatches.gd` exposes two existing opt-in helpers:

- **Response:** conventional defenders receive explicit AttackMove orders toward compatible observed armed contacts in the existing home-defense set. Available firing actions, active programs and recovery retain authority; replacement orders are throttled.
- **Handoff:** loaded material workers receive explicit queued electronics orders when the existing electronics allocation is short. Cargo returns first; protected/manual queues, observed approach safety and remote guards retain their checks.
- **Combined:** both helpers. **Control:** neither helper.

Two Godot processes run concurrently. All twelve matches finish normally; the four batch processes exit 0 with zero unresolved checks. There are no AI coordination violations across 18,988 samples. Maximum recorded stationary-travel episodes are 3.0 / 2.5 / 5.5 / 3.0 seconds for control/response/handoff/combined. These are gameplay observations, not performance measurements.

## Results

| Variant | Wins / losses | Matches launching assault | Median finish | Median first program | Median harvested M / E |
| --- | ---: | ---: | ---: | ---: | ---: |
| Control | 0 / 3 | 2 / 3 | 787.2 s | 198.3 s | 625 / 159 |
| Response | 0 / 3 | 1 / 3 | 787.2 s | 191.8 s | 483 / 179 |
| Handoff | 1 / 2 | 1 / 3 | 601.4 s | 209.2 s | 468 / 178 |
| Combined | 1 / 2 | 2 / 3 | 906.5 s | 185.8 s | 476 / 348 |

Median finish mixes victory and defeat; it is not a survival or quality score. Every run reaches its first program within three to five minutes. Three trials per variant, on one faction/map pairing, do not establish general balance or a reliable strategy. Battle/navigation trajectories can diverge before an experimental order even with the same seed.

| Variant | Seed | Result at | First program | First assault |
| --- | ---: | --- | ---: | ---: |
| Control | 4110 | Defeat · 878.3 s | 200.73 s | 505.23 s |
| Control | 4111 | Defeat · 787.2 s | 195.75 s | 665.25 s |
| Control | 4112 | Defeat · 523.8 s | 198.25 s | — |
| Response | 4110 | Defeat · 611.8 s | 185.23 s | — |
| Response | 4111 | Defeat · 791.2 s | 199.75 s | — |
| Response | 4112 | Defeat · 787.2 s | 191.75 s | 244.25 s |
| Handoff | 4110 | Defeat · 671.9 s | 209.23 s | — |
| Handoff | 4111 | Victory · 560.5 s | 200.75 s | 264.75 s |
| Handoff | 4112 | Defeat · 601.4 s | 245.25 s | — |
| Combined | 4110 | Defeat · 906.5 s | 185.23 s | 309.23 s |
| Combined | 4111 | Defeat · 641.9 s | 202.25 s | — |
| Combined | 4112 | Victory · 1731.9 s | 185.75 s | 323.75 s |

The long combined victory contains eight assault phases and seven regroup phases, six authored program applications, ten authored recovery entries and eight recorded returns. Human service restores 1,598.42 HP. It demonstrates a complete paid programming → assault → recovery → renewed assault → victory sequence within the intended 20–30-minute range. The other eleven outcomes do not establish that pacing as typical; none of this is a novice playtest.

## Economy findings and next action

The first combined loss illustrates why adding orders alone is insufficient. Its 161.73-second earned archive contains two engineers travelling toward electronics at (89.5, 12), 84.52 metres from HQ. A checksum-verified read-only decode retains their exact positions and orders in `early-economy-audit.json`; this is not a replay or proof that the route is safe.

At 540.7 seconds, the same run has five electronics assignments and one material assignment, with 9 M / 142 E. At 600.7 it has three of each and 15 M / 186 E; at 660.7 it has two electronics/four materials and 9 M / 188 E. The last new handoff was at 282.23 seconds, long before this imbalance, and no recorded worker-protection episode remains active at the three late samples. The helper restores shortages but does not cap the total after independent retreat/resumption and routine assignment decisions. Sparse samples cannot reconstruct exactly which decision produced each excess assignment.

The next useful experiment is to reconcile those returning and active assignments against material/electronics demand at safe delivery boundaries. It should preserve cargo, protected orders and explicit commander authority, and avoid changing human automatic harvesting semantics. Merely adding more conventional response orders is not supported by this comparison. Both experimental helpers remain opt-in.

## Verification and retained failures

Three final focused suites pass: HomeResponseRegression, ElectronicsHandoffRegression and GuardResponseRegression. New all-faction response checks cover actual approach and firing after a paused disk round trip, compatible domains, hidden contacts, reorder throttling, firing-action preservation, recovery and running-program authority. They use controlled stationary targets and disabled strategic decisions, separately from the twelve live-opponent paid matches.

The first new response fixture used a runtime variable as a GDScript type and failed to parse despite process exit 0. The second assigned a target 1,000 HP, outside the archive schema's legal roster bounds; all three restorations correctly failed. The corrected fixture uses ordinary health and stops that case if restoration fails. Failed sources and logs are retained and classified; their intermediate success-print text is not acceptance evidence.

Final tests, matches, formatting and lint pass without script/parse errors. Existing navigation-readback warnings and shutdown ObjectDB/resource/RID diagnostics remain. Nine Godot processes are classified in `run-index.json`: four match batches, three final regression suites and two rejected fixture attempts. The directory retains 129 earned checkpoints, raw metrics, per-branch commands, source snapshots, an unchanged 288-script shipping fingerprint, the reproducible `analyze.py` validator, `summary.json` and a SHA-256 inventory.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/SustainedDefenseMatches.gd -- --case=6 --repeats=3 --research=combined --strategy=screened-air --output=res://tmp/new-defense.json --archive=res://tmp/new-defense-stall.json --archive-prefix=res://tmp/new-defense
```

Add `--home-response`, `--electronics-handoff`, or both for the other variants. Use fresh output/archive names. No UI or physical-input acceptance is claimed. Broader strategy/faction/map coverage, reliable contested recovery, final environment/novice/platform acceptance and deferred performance remain open. The overall goal stays active.
