# Materials delivery after surplus electronics

An opt-in reference commander can now queue excess electronics gatherers back to materials when its planned purchases lack materials and already have enough electronics. All three factions deliver their original electronics cargo, preserve the queued job through a paused disk round trip, and then deliver materials. The normal opening electronics floor remains protected.

## Contract

The existing electronics helper only repairs a shortage of electronics assignments. Retreat recovery can also return engineers to electronics; neither routine reverses excess assignments. The preceding paid trials recorded five electronics assignments and one material assignment with 9 M / 142 E. That observation identifies a missing correction, but does not reconstruct which individual earlier decision created the excess.

`MaterialHandoffPolicy.gd` is an opt-in reference helper. Its caller supplies the actual current reference producer requests and selected research costs. It acts only when those purchases lack materials and their electronics cost is already funded. It counts both queued and current assignments, retains one electronics engineer with three/four workers and two with five or more, and changes only excess loaded electronics workers returning to HQ. Existing queues and protected retreat/delivery states retain authority. Observed route safety, HQ availability and remote ground guards retain the forward helper's checks. The policy does not forecast future construction or busy-producer demand.

The helper submits an ordinary queued gather order. No resources, workers, travel, production or damage rules change. Shipping scripts and default reference behavior remain unchanged; `--material-handoff` enables the experiment.

## Direct verification

The all-faction regression starts workers on ordinary electronics gathering and waits for real loaded returns. It supplies a planned-budget threshold to isolate allocation decisions; this fixture is not a paid construction/production proof. It checks funded-plan and unfunded-electronics rejection, opening-floor preservation, protected workers, manual queues, absent fields, remote guards, observed danger, duplicate orders and forward/reverse compatibility. A real paused disk round trip retains the original cargo, funds and simulation time. Every faction subsequently delivers 4 E and 4 M.

Disabling the reverse hook fails six expected assertions: a guarded remote material transition and a real reverse transition per faction. The preceding electronics-only helper is also called and does not correct the surplus. The final full suite, shared ElectronicsHandoffRegression and LaborHandoffRegression pass. The initial narrower suite also passed; its log is retained. One formatting/lint attempt exceeded the line-length limit and was corrected; final format/lint pass.

## Exact earned continuation

The first experimental full match creates a normal paid checkpoint at 219.73 seconds, with 7 M / 29 E and planned purchases costing 22 M / 14 E. The selected worker carries 4 E and has an ordinary material gather order queued behind delivery. Both replays restore that exact archive and leave enemy strategic AI active. They issue no additional reference commander decisions during the observation window.

Keeping the queue produces 4 E / 4 M in 49.38 seconds. Clearing only that queue produces 12 E / 0 M over 60 seconds. The worker survives both. This establishes the local delivery effect of the earned order, not a full-match outcome advantage. The archive is unmodified; real SaveFile/Restore APIs perform both restorations.

## Full matches

Both variants retain the conventional home-response and electronics-restoration helpers. Standard/Normal Industrial Helix-versus-Frontier runs use screened-air production and combined research, seeds 4110 and 4111. Two Godot processes run concurrently; these are gameplay observations, not performance measurements.

| Variant | Seed | Outcome at | First program | First assault | Harvested M / E | Reverse orders |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| Control | 4110 | Defeat · 697.5 s | 272.73 s | 552.23 s | 381 / 246 | 0 |
| Control | 4111 | Unresolved at 30:00 · 1800.7 s | 191.75 s | 269.75 s | 952 / 563 | 0 |
| Reverse | 4110 | Defeat · 685.7 s | 233.73 s | 335.73 s | 394 / 169 | 6 |
| Reverse | 4111 | Defeat · 930.4 s | 196.25 s | — | 609 / 264 | 4 |

**The complete-match gate fails.** Three matches resolve as defeats; the second control reaches the unchanged thirty-minute observation horizon without a result. Its process exits 1 with exactly one unresolved check; the experimental process exits 0. The parent runner exits 0 after recording both child statuses, so its status alone is not acceptance evidence. `control-unresolved.json` and `control-unresolved-policy.json` retain the exact match and reference state. No victory or general improvement is claimed. Same-seed trajectories already differ before the experimental decision.

All ten experimental orders carry electronics, occur with a recorded material shortfall and funded planned electronics cost, and retain the electronics floor. AI coordination records contain no violations across 8,228 samples; maximum stationary-travel episodes are three seconds or less. All four matches reach first programming within three to five minutes. The reverse trials lose nine/four workers versus two/one in controls; this does not establish causation, but it prevents treating corrected allocation as proof of stronger survival.

## Recovery spending is the next hypothesis

At the unresolved horizon the control has seven ground combatants at 94.93% aggregate health, two helicopters, no visible home threat for 638 seconds, and 18 M / 224 E. Its recorded recovery gate requires nine ground combatants; the other assault gates pass. Between 1297.75 and 1736.75 seconds it spends 160 M on Coordination, weapons I, armor I, service and doctrine. No tank purchase is recorded after 244.25 seconds. Current `PaidProgressionMatches._produce()` protects selected research funds before priority-six tank production; `_reference_requests()` continues to request a tank.

This is a concrete conflict between the reference commander's recovery threshold and its purchase priority. The next useful check is an exact earned replay that buys required recovery reinforcements before optional research, preserving paid jobs, essential workers/infantry and ordinary costs. It has not yet been demonstrated to produce a win. The archived production decision dictionary retains first-seen budget fields with cumulative/latest timestamps; those fields must not be misreported as the final exact reserve. `recovery-budget-audit.json` preserves the supporting research ledger, samples and decision records.

## Evidence and limits

`analyze.py` validates the actual terminal outcomes, explicitly writes `complete_match_gate_passed: false`, checks all experimental decisions and confirms that all 288 shipping scripts are unchanged. Four final focused suites pass (all-faction reverse handoff, earned continuation, electronics handoff and shared labor handoff). Eight Godot processes are classified in `run-index.json`; initial narrow success, expected disabled-hook failure and the unresolved control remain retained. Thirty-nine final source/inheritance files, raw metrics, commands, checkpoints and the SHA-256 inventory support reproduction. Existing navigation-readback warnings and shutdown ObjectDB/resource/RID diagnostics remain.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/MaterialHandoffMatches.gd -- --case=6 --repeats=2 --research=combined --strategy=screened-air --home-response --electronics-handoff --material-handoff --output=res://tmp/new-material-trials.json --archive=res://tmp/new-material-stall.json --archive-prefix=res://tmp/new-material
```

Omit `--material-handoff` for the paired control; use fresh output names. This is an opt-in reference experiment, not a human automatic-harvesting change or a generally accepted strategy. UI/input, broader maps/factions, novice/environment/platform acceptance and deferred performance remain open. The overall goal remains active.
