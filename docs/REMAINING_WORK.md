# Remaining work — resumed 2026-10-11

Work resumed at the user's request on 2026-10-11. The last unfinished implementation item, faction ability feedback, has been repaired; the overall gameplay-polish work remains incomplete. Historical paused/active entries below describe their state at the time.

## Last completed work

- Faction ability feedback now keeps setup/active effects visible, preserves partially ready selections, reports the earliest applicable recharge, and gives chip/weapon/target guidance. Button and summary hover help and accessibility descriptions include Simplified Chinese. All-faction rules, pause/disk continuity, 720p/150% layout and rendered hover checks pass. See [the ability feedback report](playtests/2026-10-11/SIGNATURE_FEEDBACK.md) for native-input results, fixture corrections and remaining limits.
- Frontier's 28 wheels across five vehicle roles now articulate from actual chassis travel and turns. Motion, pause, archive, import and shared gameplay checks passed. Cosmetic wheel phase restarts on load. See [Frontier wheel report](playtests/2026-10-07/FRONTIER_WHEELS.md) for classified runs, limitations and the native review clip.
- Command Horizon's desert surroundings and deployment feedback were completed and checked against navigation, observation, archive and mission contracts. See [environment report](playtests/2026-10-07/HORIZON_SURROUNDINGS.md) and [deployment report](playtests/2026-10-07/HORIZON_CONTROL.md).

## Next work

Resume the retained unsuccessful campaign/skirmish cohorts and choose a bounded strategy or gameplay issue from their evidence. The ability-feedback pass did not change balance values or AI/reference strategies. Repeated full-match observations must retain failures as well as victories and distinguish ordinary live continuation from reconstruction of a test commander.

Novice and subjective acceptance require actual participants/user review; do not replace them with scripted assertions. Keep performance optimization deferred as previously requested, and record unavailable provider/platform/device acceptance explicitly.

## Broader acceptance still open

- Repeated campaign and skirmish balance across factions, maps, starts, difficulties, rewards and strategies; Free Frontier balance/usability; intended pacing. Scripted victories do not establish general win rates or 20–30 minute match pacing. Retained unsuccessful cohorts still require review.
- Five real novice trials, including preset assignment, when to edit programs, and understanding Manual override.
- Final subjective art, animation, audio and interface review, accessibility, physical-device checks and supported interface scales. Individual visual passes do not close these gates.
- Live LLM provider/model acceptance, platform credentials, exports and release checks.
- Performance remains explicitly deferred. Existing measurements do not establish the final frame-rate acceptance target.

Naval content, faction variants, elaborate logistics and PvP remain later scope decisions. The [development roadmap](DEVELOPMENT_ROADMAP.md) and individual playtest reports retain the detailed implementation history and evidence limits.

## Agent progress

- 2026-10-11: Resumed at the user's request. Stages 1–2 complete: reproduced the original ten failures, repaired feedback/localization and extended the reviewed regression. Stage 3 complete: all-faction headless, shared rules/Frontier/localization, disk/pause and 720p/150% bilingual rendered hover/layout checks pass. Final real mouse/keyboard repeat passed with zero failures; evidence and the remaining queue are updated. Broader acceptance remains open.
- 2026-10-07: Wrapped up at the user's request. Recorded the unfinished ability-feedback diagnostic and remaining acceptance gates; stopped implementation and further verification. Goal paused for a future explicit resume.
