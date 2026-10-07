# Simultaneous HQ recovery feedback — 2026-10-06

Skirmish objectives now show each missing HQ's independent recovery deadline, with **Your HQ** first and **Enemy HQ** second. These labels remain unambiguous in same-faction matches. A paused HQ loss immediately shows the full 60-second window. The own-HQ instruction explicitly requires completing the rebuild; a paid foundation keeps its countdown until construction finishes.

The recovery advice retains the 45-second construction time when offering a new HQ. Once its foundation is paid, it gives the existing instruction to resume construction without repeating the objective's deadline or presenting a full new-build duration as remaining time. Prices, construction speed, outcome rules and archive format are unchanged.

## Evidence

The finalized regression produces [24 failures with the original implementation](hq-countdowns/original-final-fixture.log). The changed implementation passes the same staggered HQ-loss scenarios in Bastion, Helix and Frontier mirror matches on Industrial Crossroads. Each case verifies distinct countdown values, paused stability, exact disk restoration, a paid replacement foundation, actual construction before the deadline, removal of only the recovered side's warning, and Victory when the enemy's ordinary recovery window expires. Separate accelerated expiry cases preserve Victory, Defeat and Draw.

Accepted headless checks:

- [HQCountdownRegression](hq-countdowns/final-regression.log): three faction recovery scenarios and all three result states, zero failures.
- [EconomyRecoveryRegression](hq-countdowns/final-economy.log): recovery advice and economy behavior, zero failures.
- [SaveRestoreEdges](hq-countdowns/SaveRestoreEdges.log): actual reload retains jobs, actions, programs, cargo, cooldowns and mission state.
- [Skirmish](hq-countdowns/Skirmish.log): setup, faction pairings, production, construction, anti-air, pause, results, restart and AI economy/attacks.
- [CampaignRegression](hq-countdowns/CampaignRegression.log): First Orders victory, capture/contest/vision, pause, defeat and progress.

The [rendered regression](hq-countdowns/verified-render.log) passes five 1280×720 / 150% states: [own HQ lost](hq-countdowns/verified-frontier-own.png), [both HQs lost](hq-countdowns/verified-frontier-both.png), [disk restored](hq-countdowns/verified-frontier-restored.png), [paid foundation](hq-countdowns/verified-frontier-foundation.png), and [own HQ rebuilt](hq-countdowns/verified-frontier-rebuilt.png). Advice-button clicks select units while retaining funds, orders and the paused clock. Fresh objective text, command viewport bounds, and separation between the command panel, advice and minimap are checked. Input is injected through Godot's GUI event path; physical native input is not claimed.

The first rendered run caught a four-pixel advice/minimap overlap during the paid-foundation state. Removing the repeated deadline and inapplicable full construction duration resolves it; the rejected run and its four captures remain alongside the final evidence.

All six accepted runs exit zero without script or parse errors. GDScript formatting and lint pass for both changed shipping files and both new fixtures. Existing navigation-readback and shutdown resource/RID diagnostics remain.

## Scope and reproduction

These are controlled recovery fixtures: AI decisions are disabled, HQ losses are injected, and each player recovery receives exactly the HQ purchase budget (80 materials / 20 electronics). Placement pays that budget through the normal handler, and the engineer performs the actual 45-second construction plus travel. They establish countdown, payment, construction and UI behavior, not the feasibility of funding a comeback in a full match. Separate result checks shorten the timer deliberately.

Only `Skirmish.gd` and `EconomyAdvice.gd` change shipping behavior. Broader strategy, novice, content and platform acceptance remain open; performance remains deferred. Source snapshots, accepted-run metadata, source fingerprints and [artifact hashes](hq-countdowns/SHA256.json) accompany this report.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/HQCountdownRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/HQCountdownPreview.gd -- --captures=docs/playtests/2026-10-06/hq-countdowns/review-new
```

Use a fresh capture prefix to preserve earlier evidence.
