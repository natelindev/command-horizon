# Remaining work — updated 2026-10-16

Mechanics/campaign completion, 2026-10-13: the requested implementation is complete, including the previously retained engineer, Split Signal and Foundry failures. Starting buildings face bottom; three larger maps provide more resources and infantry-capturable refineries, mercenary camps and repair shops. Campaigns have animated briefings, Hugging Face English/Mandarin narration, operating paid enemy production and a finale siege commander. Existing art style and original map/archive layouts are preserved. Fifty-three headless suites and bilingual 720p/150% controls pass; fresh paid reference matches reach Victory for all three factions. See [the completion report](playtests/2026-10-13/MECHANICS_COMPLETION.md) for verification and bounded acceptance limits.

Historical paused/active entries below describe their state at the time. The remaining queue concerns broader participant, balance, device and release acceptance, rather than an unfinished requested feature.

## Last completed work

- 2026-10-16: Integrated the polish and 16-mission hero campaign work; completed the authorized rendered review, expanded-only skirmish selection, lively campaign interiors and persistent captured-building ownership. Campaign routes, construction clearance, save compatibility and packaged checks pass. See the [rendered continuation report](playtests/2026-10-16/rendered-continuation/README.md) for captures, benchmarks and native-input limitations.

- Faction ability feedback now keeps setup/active effects visible, preserves partially ready selections, reports the earliest applicable recharge, and gives chip/weapon/target guidance. Button and summary hover help and accessibility descriptions include Simplified Chinese. All-faction rules, pause/disk continuity, 720p/150% layout and rendered hover checks pass. See [the ability feedback report](playtests/2026-10-11/SIGNATURE_FEEDBACK.md) for native-input results, fixture corrections and remaining limits.
- Frontier's 28 wheels across five vehicle roles now articulate from actual chassis travel and turns. Motion, pause, archive, import and shared gameplay checks passed. Cosmetic wheel phase restarts on load. See [Frontier wheel report](playtests/2026-10-07/FRONTIER_WHEELS.md) for classified runs, limitations and the native review clip.
- Command Horizon's desert surroundings and deployment feedback were completed and checked against navigation, observation, archive and mission contracts. See [environment report](playtests/2026-10-07/HORIZON_SURROUNDINGS.md) and [deployment report](playtests/2026-10-07/HORIZON_CONTROL.md).

## Next work

Run broader participant and repeated balance cohorts across maps, factions and strategies. The retained mechanics failures were resolved in the 13 October continuation; historical defeats remain evidence rather than being rewritten as victories. Keep distinguishing ordinary live play from fixture reconstruction.

Novice and subjective acceptance require actual participants/user review; do not replace them with scripted assertions. Maximum-load CPU optimization remains open after authorized profiling; record unavailable provider/platform/device acceptance explicitly.

## Broader acceptance still open

- Repeated campaign and skirmish balance across factions, maps, starts, difficulties, rewards and strategies; Free Frontier balance/usability; intended pacing. Scripted victories do not establish general win rates or 20–30 minute match pacing. Retained unsuccessful cohorts still require review.
- Five real novice trials, including choosing unit behaviors and understanding direct-order authority.
- Final subjective art, animation, audio and interface review, accessibility, physical-device checks and supported interface scales. Individual visual passes do not close these gates.
- Platform exports and release checks.
- Maximum-load performance remains below a smooth target; see the [performance results](performance/RESULTS.md) for current maximum-population measurements. Ordinary 30/70-unit scenes average 105.2/73.0 FPS; these results do not establish all-platform acceptance.

Naval content, faction variants, elaborate logistics and PvP remain later scope decisions. The [development roadmap](DEVELOPMENT_ROADMAP.md) and individual playtest reports retain the detailed implementation history and evidence limits.

## Agent progress

- 2026-10-13: Completed the requested mechanics continuation and expanded map/campaign implementation. Final integration and rendered evidence is linked from the completion report; historical findings below remain retained.

- 2026-10-11: Resumed at the user's request. Stages 1–2 complete: reproduced the original ten failures, repaired feedback/localization and extended the reviewed regression. Stage 3 complete: all-faction headless, shared rules/Frontier/localization, disk/pause and 720p/150% bilingual rendered hover/layout checks pass. Final real mouse/keyboard repeat passed with zero failures; evidence and the remaining queue are updated. Broader acceptance remains open.
- 2026-10-07: Wrapped up at the user's request. Recorded the unfinished ability-feedback diagnostic and remaining acceptance gates; stopped implementation and further verification. Goal paused for a future explicit resume.
