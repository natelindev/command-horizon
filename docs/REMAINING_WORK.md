# Remaining work — updated 2026-10-24

The 23–24 October work implements the requested battlefield polish, queued
technology research and clear elimination status. The current v19 macOS package
passes all 75 registered suites and strict/deep signature verification, with
unchanged source and package hashes. The bilingual queue/elimination rendered
reviews and the reproduced restore-cancellation test pass. Five additional
research/save suites also pass against the same immutable PCK. Four final native foreground timing runs pass the working budgets: ordinary
combat p95 14.95 / 16.53 ms, stress combat 28.57 / 30.70 ms, and no frame over
50 ms among 4,557 unique sampled frames. The current-PCK native menu, skirmish,
save, archive load, paused restore, resume and Cmd-Q flow also passes with a clean
game log and unchanged pre-existing user data.
See the [polish report](playtests/2026-10-23/POLISH.md) for implementation and evidence.

All 810 current save fixtures validate after conversion to v19, preserving their
prior values and IDs. Cleanup removed the original 927 obsolete snapshots,
810 temporary conversion backups and the owned isolated prewarm UI's v18 quicksave.
Campaign progress and preferences are preserved.

Windows work, including the reported four-player FFA low frame rate, is explicitly
deferred at the user's request. Its accepted two-player baseline remains above
target at 36.80 ms p95; it does not measure the reported four-player scenario.
[WINDOWS_HANDOFF.md](playtests/2026-10-24/WINDOWS_HANDOFF.md) records the artifacts,
preserved player state and exact outstanding work.

Mechanics/campaign completion, 2026-10-13: the requested implementation is complete, including the previously retained engineer, Split Signal and Foundry failures. Starting buildings face bottom; three larger maps provide more resources and infantry-capturable refineries, mercenary camps and repair shops. Campaigns have animated briefings, Hugging Face English/Mandarin narration, operating paid enemy production and a finale siege commander. Existing art style and original map/archive layouts are preserved. Fifty-three headless suites and bilingual 720p/150% controls pass; fresh paid reference matches reach Victory for all three factions. See [the completion report](playtests/2026-10-13/MECHANICS_COMPLETION.md) for verification and bounded acceptance limits.

Historical paused/active entries below describe their state at the time. The current Windows follow-up is deferred; broader participant, balance, device and release acceptance also remains open.

## Last completed work

- 2026-10-16: Integrated the polish and 16-mission hero campaign work; completed the authorized rendered review, expanded-only skirmish selection, lively campaign interiors and persistent captured-building ownership. Campaign routes, construction clearance, save compatibility and packaged checks pass. See the [rendered continuation report](playtests/2026-10-16/rendered-continuation/README.md) for captures, benchmarks and native-input limitations.

- Faction ability feedback now keeps setup/active effects visible, preserves partially ready selections, reports the earliest applicable recharge, and gives chip/weapon/target guidance. Button and summary hover help and accessibility descriptions include Simplified Chinese. All-faction rules, pause/disk continuity, 720p/150% layout and rendered hover checks pass. See [the ability feedback report](playtests/2026-10-11/SIGNATURE_FEEDBACK.md) for native-input results, fixture corrections and remaining limits.
- Frontier's 28 wheels across five vehicle roles now articulate from actual chassis travel and turns. Motion, pause, archive, import and shared gameplay checks passed. Cosmetic wheel phase restarts on load. See [Frontier wheel report](playtests/2026-10-07/FRONTIER_WHEELS.md) for classified runs, limitations and the native review clip.
- Command Horizon's desert surroundings and deployment feedback were completed and checked against navigation, observation, archive and mission contracts. See [environment report](playtests/2026-10-07/HORIZON_SURROUNDINGS.md) and [deployment report](playtests/2026-10-07/HORIZON_CONTROL.md).

## Next work

Run broader participant and repeated balance cohorts across maps, factions and strategies. The retained mechanics failures were resolved in the 13 October continuation; historical defeats remain evidence rather than being rewritten as victories. Keep distinguishing ordinary live play from fixture reconstruction.

Novice and subjective acceptance require actual participants/user review; do not replace them with scripted assertions. The current v19 macOS release passes the measured ordinary and synthetic maximum-load budgets, including the retained warm-up tails; Windows maximum-load acceptance is deferred. Record unavailable participant/platform/device acceptance explicitly.

## Broader acceptance still open

- Repeated campaign and skirmish balance across factions, maps, starts, difficulties, rewards and strategies; Free Frontier balance/usability; intended pacing. Scripted victories do not establish general win rates or 20–30 minute match pacing. Retained unsuccessful cohorts still require review.
- Five real novice trials, including choosing unit behaviors and understanding direct-order authority.
- Final subjective art, animation, audio and interface review, accessibility, physical-device checks and supported interface scales. Individual visual passes do not close these gates.
- Windows current-package exports and release checks remain deferred. Broader platform acceptance is open.
- Windows four-player FFA, longer matches and broader-device performance remain unverified; see the [current performance report](playtests/2026-10-23/PERFORMANCE.md) and [accepted v19 Mac measurements](playtests/2026-10-24/macos-current-v19-performance.json). The passing Mac synthetic workload does not establish four-player or all-platform acceptance.
- The F1 diagnostic overlay's top performance lines overlap the HUD rail in the native check; ordinary game controls remain usable. This diagnostic layout limitation is recorded in the [native report](playtests/2026-10-24/native-final-smoke-071518/result.json).

Naval content, faction variants, elaborate logistics and PvP remain later scope decisions. The [development roadmap](DEVELOPMENT_ROADMAP.md) and individual playtest reports retain the detailed implementation history and evidence limits.

## Agent progress

- 2026-10-24 final v19 integration: all 75 registered packaged suites and five
  additional affected research/save suites pass against the same PCK. Four
  foreground release measurements pass every working budget; full paused-state
  preservation checks and native save/load/resume/quit pass. Original build and
  user-data hashes are unchanged. Static checks cover 133 GDScript and six Python
  files. Windows/four-player and human/device acceptance remain as listed above.

- 2026-10-24 earlier baseline: Implemented the requested battlefield polish and completed obsolete-save cleanup. Audio signal/speech checks, expert onboarding review, all 73 baseline macOS packaged suites
  and native menu/skirmish/quit pass. A fixture-only package refresh passes four
  focused locale runs, native startup/quit and signature checks, carrying forward
  71 unchanged suite results. The Mac baseline meets both steady-state budgets;
  production prewarming addresses the reproduced first-use stall. Windows investigation is explicitly deferred.
  Three further CPU optimizations pass ten focused checks; their final Mac integration is measured above, while Windows timing is deferred.
  An earlier rare crowd-navigation miss is
  retained despite passing repeats on both platforms. Actual novice trials, subjective listening and physical input/display latency remain unverified.

- 2026-10-13: Completed the requested mechanics continuation and expanded map/campaign implementation. Final integration and rendered evidence is linked from the completion report; historical findings below remain retained.

- 2026-10-11: Resumed at the user's request. Stages 1–2 complete: reproduced the original ten failures, repaired feedback/localization and extended the reviewed regression. Stage 3 complete: all-faction headless, shared rules/Frontier/localization, disk/pause and 720p/150% bilingual rendered hover/layout checks pass. Final real mouse/keyboard repeat passed with zero failures; evidence and the remaining queue are updated. Broader acceptance remains open.
- 2026-10-07: Wrapped up at the user's request. Recorded the unfinished ability-feedback diagnostic and remaining acceptance gates; stopped implementation and further verification. Goal paused for a future explicit resume.
