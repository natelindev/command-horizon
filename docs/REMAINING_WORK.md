# Remaining work — paused 2026-10-07

Work stopped at the user's request. The gameplay-polish goal is paused, not complete. Existing implementation and evidence are retained; resume only when requested. Earlier roadmap entries saying the goal is active describe their historical completion state.

## Last completed work

- Frontier's 28 wheels across five vehicle roles now articulate from actual chassis travel and turns. Motion, pause, archive, import and shared gameplay checks passed. Cosmetic wheel phase restarts on load. See [Frontier wheel report](playtests/2026-10-07/FRONTIER_WHEELS.md) for classified runs, limitations and the native review clip.
- Command Horizon's desert surroundings and deployment feedback were completed and checked against navigation, observation, archive and mission contracts. See [environment report](playtests/2026-10-07/HORIZON_SURROUNDINGS.md) and [deployment report](playtests/2026-10-07/HORIZON_CONTROL.md).

## Unfinished: faction ability feedback

The latest pass reproduced presentation problems in `source/match/hud/SignaturePanel.gd`; no shipping fix was made before stopping.

- Recharge text hides Frontier Maneuver, Helix Precision, and Bastion Anchor setup/active feedback, including settled Anchor.
- A mixed selection reports the latest selected cooldown rather than the earliest return to readiness.
- Units lacking the required chip receive no useful hardware instruction.
- Code inspection also found long single-string help and missing accessibility descriptions/summary hover handling. Native usability of these controls was not verified in this pass.

The new [diagnostic fixture](../tests/headless/SignatureFeedbackRegression.gd) is deliberately left with unresolved assertions: its baseline run exited 1 with **10 failures**. Actual activation, readiness and partial-ready checks did not fail. Mixed-recharge checks use controlled ended-effect state to isolate the display calculation. This is diagnostic evidence, not completed acceptance coverage.

Retained evidence: [baseline log](playtests/2026-10-07/signature-feedback/baseline.log), [state records](playtests/2026-10-07/signature-feedback/baseline.json), and [unchanged panel snapshot](playtests/2026-10-07/signature-feedback/before-SignaturePanel.gd.txt). The run had no script error, but retained shutdown ObjectDB/resource diagnostics. The fixture was formatted; lint, its non-baseline archive branch, and native verification remain unfinished. No test process remains running from this pass.

When resumed, implement state-aware effect/setup feedback, earliest recharge and hardware guidance while preserving eligibility, activation costs/timers, cohort rules and order authority. Then verify actual activation, mixed selections, pause/disk restoration, all-faction rules and native 720p mouse, keyboard and hover behavior. Review the unfinished fixture before treating it as a regression gate.

## Broader acceptance still open

- Repeated campaign and skirmish balance across factions, maps, starts, difficulties, rewards and strategies; Free Frontier balance/usability; intended pacing. Scripted victories do not establish general win rates or 20–30 minute match pacing. Retained unsuccessful cohorts still require review.
- Five real novice trials, including preset assignment, when to edit programs, and understanding Manual override.
- Final subjective art, animation, audio and interface review, accessibility, physical-device checks and supported interface scales. Individual visual passes do not close these gates.
- Live LLM provider/model acceptance, platform credentials, exports and release checks.
- Performance remains explicitly deferred. Existing measurements do not establish the final frame-rate acceptance target.

Naval content, faction variants, elaborate logistics and PvP remain later scope decisions. The [development roadmap](DEVELOPMENT_ROADMAP.md) and individual playtest reports retain the detailed implementation history and evidence limits.

## Agent progress

- 2026-10-07: Wrapped up at the user's request. Recorded the unfinished ability-feedback diagnostic and remaining acceptance gates; stopped implementation and further verification. Goal paused for a future explicit resume.
