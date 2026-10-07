# Command Horizon deployment feedback and north-route audit — 2026-10-07

Command Horizon now distinguishes advancing capture, retained vacant progress, active recapture, blocked contention, infantry-dependent securing and a missing deployment guard. The mission panel and world marker share the status; the objective uses it while deployment is incomplete or unguarded. Completing the 30-second hold says “Guard in place” only while infantry actually hold the uncontested point. If enemy command is destroyed and the owned point is empty, the objective explicitly says “return infantry to deployment.”

Tooltips explain initial capture, retained securing time and the continuing infantry requirement for victory. Mission labels now receive mouse hover, and the help uses short lines that fit the viewport. Own-HQ rebuilding still takes priority; the completed objective still says “Command destroyed · deployment secured.”

The existing infantry-presence predicate is factored into a shared helper, with an initialization guard for world-marker construction before the battlefield is ready. Its runtime ownership/type/alive/radius checks are unchanged. Capture, scoring, finite responses, combat, prices, route geometry and archive schema remain unchanged. Player orders remain explicit.

## Focused states, save restoration and native controls

The corrected original-source fixture fails nineteen state/wording assertions. This includes genuinely misleading activity/guard states and expected shared wording; it does not represent nineteen independent gameplay bugs. Current source passes actual capture, vacancy, contest, enemy takeover, recapture, retained securing and both guard-return branches. Other units are parked/process-disabled and responses are marked exhausted after first capture to isolate these states. These are controlled objective checks, not earned combat outcomes.

Partial capture and owned-vacant deployment are written through the actual typed SaveFile envelope and restored while paused. Mission state, simulation time, player economy and saved unit positions/HP remain exact. Ordinary infantry return completes the remaining securing in 30.75 simulation seconds on both original and revised headless fixtures. After securing is complete, an absent guard still prevents victory; ordinary return after controlled HQ destruction wins in 2.67 seconds on both versions.

Native mouse activation of Infantry, Enter activation of Deployment and explicit right-clicks queue both returns while paused. Selection preserves funds and pause. The revised rendered fixture secures in 30.98 seconds and completes the final return in 2.75 seconds. Twelve 1280×720 captures at 150% interface scale were inspected, including actual visible tooltips before/after the hold is complete. Panels clear the minimap and tooltip windows fit within viewport dimensions. These are engine-injected input checks, not physical-device acceptance.

## Rejected attempts and corrections

The initial fixture assumed deployment was unclaimed after setup, but enemy infantry had already begun capture during its startup frames. Its unclaimed-state assertion was invalid. The corrected controlled fixture explicitly resets that initial candidate/progress, then reruns against the exact original shipping files. The original-source comparison and restoration were performed serially; the current source was restored before further verification.

The first implementation called the infantry helper from the world marker before the battlefield existed. Several Godot processes reported zero assertion failures despite runtime script errors, so those runs are rejected. A null guard fixes initialization without changing the runtime hold rule. The initial native review also found a one-line tooltip extending off-screen, and one guard-absence check read presentation before its next frame update. Help now has explicit line breaks, the native fixture checks tooltip size, and state assertions wait for UI frames. The in-progress first north-route run was explicitly interrupted to restart on corrected source; its deadline was not a mission outcome.

## Earned recovery and complete north-route fights

The previously retained south-route Veteran battle restores exact funds, positions, HP and the paused simulation clock. Explicit recall of surviving forces and ordinary paid infantry recover it in 20.52 seconds headless (three purchases) and 19.23 seconds in the native replay (two purchases). These timings vary from earlier runs; they do not establish a speed improvement. The native replay also checks Enter activation of Deployment and mouse selection of surviving infantry.

The north-route fixture records Foundry completion before starting a fresh match, opening the actual passage. It uses the existing reference commander with real harvesting, paid replacements, saved Guard/Service doctrines, separate guard/strike assignments and optional explicit deployment recall after enemy command falls. No combat HP, funds or units are injected into these fights. All routes process four finite responses.

| Difficulty / modifier | Outcome | Simulation time |
| --- | --- | ---: |
| Story / normal | Victory; all assertions pass | 140.12 s |
| Standard / normal | Victory; all assertions pass | 155.35 s |
| Veteran / normal | Victory; all assertions pass | 217.77 s |
| Veteran / Lean, initial | Victory; optional repair purchase rejected | 438.22 s |
| Veteran / Reinforced | Victory; all assertions pass | 233.55 s |
| Veteran / normal, native | Victory; all assertions pass | 200.48 s |
| Veteran / Lean, diagnostic replay | Victory; all assertions pass | 332.30 s |

The headless normal-Veteran commander explicitly recalls surviving forces at 174.73 seconds; the native normal route finishes while its guard is still sufficient, without triggering that recall. These are different battle outcomes under the same available policy, not a controlled comparison of route speed.

The first Lean run reaches the actual victory condition but fails its test commander's immediate second-repair purchase assertion. No purchase-time snapshot existed for that run, so final funds alone cannot identify the exact rejection cause. A diagnostic replay records 32 materials / 24 electronics, an empty factory queue and population 30 at the request, successfully pays the ordinary 16 / 8 repair price, and wins. The default reference behavior remains an immediate ordinary purchase; a small test hook adds purchase tracing and an explicitly selected wait option. This does not change shipping production or grant resources. Rejected requests in that diagnostic wrapper retain an actual paused purchase-state archive.

The wait-enabled Lean replay also wins at 323.55 seconds. It has 26 materials / 24 electronics and admits the 16 / 8 job immediately, so no waiting occurs. Neither diagnostic replay exercises the wait loop; no claim is made that waiting fixed the first rejection. These differing outcomes preserve the repeated-balance limitation rather than hiding the initial failed purchase assertion.

The full shared rules suite passes objective transitions, turret firing after restoration, all nine difficulty/modifier response budgets, finite-response and occupied-entry rules, both route geometries and campaign progress migration. The earlier recovery-feedback suite also passes on current source, with its artificial unclaimed setup now explicit.

Seventeen final captures were inspected: twelve controlled states/returns, two earned-recovery views and three native north-route stages. See [vacant capture](horizon-control/final-native-vacant.png), [missing guard and help](horizon-control/final-native-guard-absent.png), [owned-point return instruction](horizon-control/final-native-command-destroyed.png), [actual earned recovery](horizon-control/native-earned-result.png), [north passage](horizon-control/native-north-horizon-pass.png) and [native full victory](horizon-control/native-north-horizon-live-result.png).

## Reproduction and retained evidence

Use Godot 4.6 with `--path . --headless --fixed-fps 60 --script tests/headless/HorizonControlRegression.gd -- --evidence=res://<fresh-prefix>` for controlled states and typed disk restoration. Shared contracts use `tests/headless/CommandHorizonRules.gd` and `HorizonRecoveryFeedback.gd`.

Full unlocked-route fights use `tests/playtest/HorizonDifficultyMatches.gd -- --alternate --difficulty=0|1|2 --retake-deployment --evidence=res://<fresh-prefix>`, with `--lean` or `--reinforced` where wanted. `HorizonSupportPurchase.gd` adds the purchase trace; `--wait-assault-support` enables its test-only bounded wait. Earned recovery uses `tests/playtest/HorizonDeploymentRecovery.gd` with a fresh evidence prefix and the retained default archive. These reference policies issue explicit ordinary orders; they are not new player automation.

For native checks run `tests/rendered/HorizonControlPreview.gd`, `HorizonRecoveryPreview.gd` or `HorizonDifficultyPreview.gd` without headless/fixed-FPS flags, with fresh prefixes. Captures refuse overwrites.

Twenty-three Godot processes are classified in [run-index.json](horizon-control/run-index.json), including rejected initialization runs, the corrected original comparison, the interrupted run and the Lean victory with a rejected purchase. Nine changed/new GDScripts pass format and lint. Accepted final runs have no script errors; known navigation GPU-readback and shutdown ObjectDB/resource/shader/RID diagnostics remain. Snapshots/hashes, exact typed archives, battle results, logs, an evidence analyzer and SHA256 checksums are retained. Run `python3 docs/playtests/2026-10-07/horizon-control/analyze.py` to verify the evidence against current source.

Novice comprehension, repeated strategy/difficulty/reward balance, final environment quality and broader product/platform acceptance remain open. The optional test wait loop was not exercised by these successful immediate-admission replays. Performance remains deferred; the overall development goal stays active.
