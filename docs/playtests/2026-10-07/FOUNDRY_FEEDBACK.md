# Broken Foundry capture and securing feedback — 2026-10-07

Broken Foundry now distinguishes active capture, recapture, a contested standstill, retained vacant capture, active securing and the absence of required infantry. The objective line, mission panel and world marker share that status. The capture tooltip explains the two stages: infantry capture within 3 metres for 10 seconds, then remain for 30 uncontested securing seconds. Accumulated securing time survives leaving or losing control.

The original mission panel could continue saying “Secure” after infantry left and the securing clock stopped. It also described a stored partial capture as active capture and appended “Contested” to a progressing recapture. The new status identifies the immediate action or activity instead. The existing Infantry and Foundry shortcuts remain explicit selection/camera controls.

The scoring branch now calls the same nearby-living-infantry predicate as presentation. Its unit ownership/type/alive/radius checks are unchanged. No capture time, hold duration, contest/ownership rule, difficulty budget, resource price, enemy behavior, map geometry or archive schema changes.

## Focused behavior and restoration

The preceding source fails ten focused state/wording assertions, including both genuinely ambiguous states and the expected shared wording. The revised source passes. The controlled fixture exercises locked control, real partial capture, vacancy, actual enemy contest/takeover, player recapture, owned-but-vacant control and infantry return through ordinary movement. Other units are parked/process-disabled to isolate objective behavior; this is not an earned combat-state recovery.

Partial capture and owned-vacant control are each written through the actual typed SaveFile envelope and restored. Mission state, paused simulation time and each saved unit's position/HP remain exact. The original and revised headless fixtures both finish after 30.60 seconds of ordinary infantry return and remaining securing; that comparison supports a presentation change rather than a scoring change.

## Full mission and native controls

The original Veteran reference route reaches victory at 146.40 seconds, so this audit does not claim to fix an unwinnable mission. The revised routes also reach ordinary victory:

| Route | Time | Human survivors | Remaining infantry |
| --- | ---: | ---: | ---: |
| Story, headless | 133.27 s | 22 | 10 |
| Standard, headless | 149.38 s | 15 | 4 |
| Veteran, headless | 147.97 s | 14 | 4 |
| Veteran, normal-clock | 147.35 s | 15 | 4 |

Each run destroys both production nodes after one northern/two southern batches and resolves the final response. Human funds end at 136 materials / 80 electronics after the existing 24-material replacement purchase. No extra funds, HP or units are injected. The small timing/survivor differences are observations, not causal balance findings.

The full shared BrokenFoundryRegression passes warehouse traversal/sight, artillery threat, bounded Guard pursuit, non-stacking repair, actual paid production and archive continuity, capture/hold/entry denial, difficulty response budgets, HQ defeat and reward/progress migration. Shared relay feedback also passes.

Native mouse activation of Infantry, Enter activation of Foundry and a viewport right-click queue an explicit return while paused. Selection preserves resources and pause; resuming the controlled archived world completes securing in 30.62 seconds. The mission panel remains above the minimap at 1280×720 and 150% interface scale.

Eleven captures were visually reviewed: [locked](foundry-feedback/final-ui-locked.png), [vacant capture](foundry-feedback/final-ui-vacant.png), [paused restoration](foundry-feedback/final-ui-loaded.png), [contested hold](foundry-feedback/final-ui-contested.png), [recapture](foundry-feedback/final-ui-recapturing.png), [missing infantry](foundry-feedback/final-ui-infantry-needed.png), [queued return](foundry-feedback/final-ui-ordered.png), [controlled victory](foundry-feedback/final-ui-victory.png), both full-route node fights and [final normal-clock victory](foundry-feedback/final-veteran-foundry-live-result.png). The eight focused frames precede a final removal of duplicated “Foundry” wording from the completed status; the final battle result verifies that correction. Current-source headless feedback checks pass again.

## Evidence and limitations

The first rendered fixture was stopped while still running after source review identified a later call to a nonexistent selection-inspection method. It had not reached that call. The corrected fixture checks the actual selected-unit group. Its partial captures and log are retained as an interrupted fixture, not accepted verification. An early full rendered run was also stopped to pick up the final completed-status wording correction; its replacement ran to victory. Neither interrupted run is classified as a gameplay failure or a successful full route.

Full routes use the existing reference commander: attack the two production nodes sequentially, retain two infantry in reserve, use Service area support, then pay 24 materials for four capture replacements. Ordinary attack-move and the mission's actual production/response/capture rules remain active. Controlled objective checks are separate from those full fights.

Novice comprehension, repeated difficulty/strategy/reward balance, broader environment/product/platform acceptance and deferred performance remain open. The overall development goal stays active.


## Reproduction and retained evidence

Use the project Godot 4.6 binary with `--path .`. `--headless --fixed-fps 60 --script tests/headless/FoundryFeedbackRegression.gd -- --evidence=res://<fresh-prefix>` checks controlled states and actual disk restoration. For full encounters use `tests/playtest/FoundryDifficultyMatches.gd` with the same flags plus `--difficulty=0`, `1` or `2`. Run `tests/rendered/FoundryFeedbackPreview.gd` or `FoundryDifficultyPreview.gd` without headless/fixed-FPS flags for normal-clock verification. Rendered captures refuse overwriting; use a fresh evidence prefix. Archive fixtures are controlled states, and are explicitly distinguished from the full-route observations.

All thirteen Godot processes are classified in `foundry-feedback/run-index.json`. Seven changed/new GDScripts pass format and lint checks. There are no script errors in these runs; known navigation GPU-readback warnings and shutdown ObjectDB/resource diagnostics remain. Source snapshots/hashes, actual archives, full-route timelines, an evidence analyzer and SHA256 checksums are retained. Run `python3 docs/playtests/2026-10-07/foundry-feedback/analyze.py` to check the recorded evidence against current source.
