# Broken Foundry sustained production — 2026-10-07

Broken Foundry now retains a ready production batch until the whole batch can enter the ordinary paid queue. The original Veteran mission counted its third batch even when the five-job queue rejected the ninth promised unit. Both factories naturally completed eight units instead of nine. The frozen original mission reproduces that loss; the revised mission pays for and completes all nine per factory without exceeding queue capacity.

## Admission and visible waiting

Each node still has three batches of 1/2/3 chipped Needle skimmers on Story/Standard/Veteran. The first is due ten seconds after the alarm; subsequent batches become due 45 seconds after the previous admission. A ready batch waits for sufficient queue slots, population space, funds and the chip-installation lab. Only complete admission advances the batch counter. All jobs use ordinary prices, chip installation and production duration. Unexpected partial admission is cancelled and refunded through the ordinary queue before retrying; existing paid jobs retain their place.

The HUD displays “Waiting” instead of a misleading zero-second countdown and exposes the blocking reason on hover. Labels now receive mouse input so their tooltips actually appear. Six native 1280×720 captures at 150% interface scale cover queue waiting, reload, resumed production, insufficient funds, absent lab and the unit limit. Mouse and Enter activation of View preserve pause, and the panel stays above the minimap. The controlled UI fixture reveals terrain for context; it does not establish enemy-unit observation behavior.

## Uninterrupted production and restoration

A real scout crosses the alarm threshold, then production runs for 300 simulation seconds with the original budget and no combat-state changes or resource grants.

| Difficulty/source | Paid and completed per node | Peak queue | Remaining materials/electronics |
| --- | ---: | ---: | ---: |
| Story, revised | 3 | 1 | 468 / 216 |
| Standard, revised | 6 | 3 | 336 / 132 |
| Veteran, frozen original | 8 | 5 | 248 / 76 |
| Veteran, revised/current source | 9 | 5 | 204 / 48 |

Current-source Veteran admits its batches at 12.97, 57.98 and 112.98 seconds; the third waits about ten seconds for sufficient slots. Its last unit completes at 237.97 seconds. Across both nodes, the intended 18 jobs cost 396 materials / 252 electronics; the old 16 jobs cost 352 / 224. These are finite paid jobs, not additional waves or resource refills.

The controlled blocked-state regression verifies all-or-nothing funding and queue admission, lab/population denial, paused disk restoration, resumption after a job completes, and factory destruction cancelling unfinished work without refunding it. Funds, lab and population recovery cases deliberately alter fixtures to isolate admission; they are not earned gameplay recoveries.

Actual late-production archives from both old and revised natural runs also restore exactly while paused. Continuing each for 165 seconds yields 18 versus 20 enemy tanks including the two starting defenders, with their original funds, installed chips and active Guard programs. The old archive retains its recorded exhausted budget; loading does not retroactively grant lost jobs. New waiting batches survive through the existing batch-count and zero-timer fields, with no archive schema change.

## Full encounters and acceptance limits

The shared Broken Foundry suite passes its production, geometry, sight, support, capture, response, reward and archive checks, then wins its Standard reference fight at 138.88 seconds. A normal-clock Veteran route wins at 145.85 seconds with 14 survivors, four infantry and 136 materials / 80 electronics after paying 24 materials for four replacements. It destroys the factories after one/two admitted batches, so it does not exercise late production pressure.

A second Veteran route first triggers the alarm and waits 125 simulation seconds before advancing. All three batches are paid at each node before the assault begins at 128.48 seconds. Both factories fall at 167.48 / 217.48 seconds, cancelling any remaining jobs normally; victory follows at 320.12 seconds with six survivors and two infantry. The same 24-material replacement purchase is used. This exercises delayed paid production pressure, but does not imply all 18 produced units finish before the factories fall. No combat HP, resources or extra units are injected into either full route.

These runs establish correct finite production and viable reference routes. They do not establish novice comprehension, repeated strategy/difficulty balance, final environment quality or broader platform acceptance. The overall goal remains active; performance remains deferred.

## Evidence and reproduction

Twelve Godot processes are classified in [run-index.json](foundry-production/run-index.json). An initial baseline was stopped because later cases could pick up source edits; its partial output/archive is not accepted comparison. The replacement loads the frozen exact original mission. One focused fixture was rejected for a Godot parse error despite exit code zero. The first native fixture passed its property checks but exposed absent hover tooltips during visual inspection; final verification checks actual visible tooltip labels after mouse movement. Those unsuccessful/superseded attempts are retained.

The initial revised all-difficulty run predates removal of a redundant availability precheck and source-fingerprint output. A final fingerprinted Veteran run verifies the current mission source and natural ninth-job failure scenario. Nine final images were inspected: six [waiting/reload/constraint views](foundry-production/hover-queue-wait.png), the two full-route node fights and [native victory](foundry-production/native-veteran-foundry-live-result.png). Seven changed/new GDScripts pass format and lint. Accepted runs have no script errors; known navigation GPU-readback and shutdown ObjectDB/resource diagnostics remain.

Use Godot 4.6 with `--path . --headless --fixed-fps 60 --script tests/headless/FoundryProductionBudget.gd -- --evidence=res://<fresh-prefix>` for all difficulties; add `--mode=2 --legacy` for the frozen original Veteran reproduction. `FoundryBatchRegression.gd` accepts the same evidence prefix. `FoundryProductionRestore.gd` uses the retained natural archives. Full delayed encounters use `tests/playtest/FoundryDelayedAdvance.gd -- --difficulty=2 --evidence=res://<fresh-prefix>`. For native verification run `tests/rendered/FoundryBatchPreview.gd` or `FoundryDifficultyPreview.gd` without headless/fixed-FPS flags. Captures refuse overwriting.

Source snapshots, hashes, actual typed archives, timelines, all logs and checksums are retained in `foundry-production/`. Run `python3 docs/playtests/2026-10-07/foundry-production/analyze.py` to verify the recorded evidence against current source.
