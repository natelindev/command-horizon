# Remaining work — updated 2026-11-02

The frozen macOS `qualified-run-5` passes the complete current headless workflow: **140/140 packaged scripts**, a strict pre-export `RichTexturesRegression` source check, 811 archived saves with 389 recorded checksums, six dummy resource-lifetime instances, 1,152 layout cases with zero failures, **14/14 actual multiplayer/replay checks**, and startup/clock checks. All **162 workflow rows** pass. The [candidate 5 report](playtests/2026-11-02/headless-continuation/candidate5/report.json) records `headless_checks_passed` with the final command and six CPU query changes included; [artifact verification](playtests/2026-11-02/headless-continuation/candidate5/artifact-verification.json) confirms matching executable/helper/PCK/ZIP hashes and zero source drift. ARM64 executed on macOS; the universal x86-64 slice was built and structurally checked only, with no Windows/Linux execution claim. Candidate 4's [earlier pass](playtests/2026-11-02/headless-continuation/final/report.json) and all failed workflows remain preserved. See the [current continuation report](playtests/2026-11-02/headless-continuation/README.md).

**Current authorization is headless only. Normal and graphical game launches are prohibited until the user allows them again.** Before this renewed restriction, [actual passenger/32-briefing review](playtests/2026-11-02/graphical-resume/README.md) and [six OpenGL lifetime instances](playtests/2026-11-02/graphical-resume/opengl/README.md) passed. The [last actual-release native Low run](playtests/2026-11-02/tactical-formations/fact-reuse-release/low-native-result.json), before the final command changes, retains all 200 units selected and visible and 240/240 focused frames, with zero timed pipeline changes: command 11.823 ms, median 13.984 ms, p95 16.887 ms, maximum 32.736 ms. The strict 16.6 ms maximum-frame gate fails; MI12 and final release acceptance remain open, and further graphical qualification is deferred pending permission. Headless implementation continues. The requested original 3D style is retained; [static inspection](playtests/2026-11-02/original-style-audit.md) found no global pixel-art conversion or saved benchmark graphics leakage.

## Earlier release evidence — 2026-10-24

The latest 24 October follow-up adds inertial camera panning, MMB map grabbing,
Alt + MMB rotation, terrain formation/facing feedback, command rings, shared
four-owner body grids, staggered minimap updates and pooled muzzle/ricochet effects.
Research/commander checks and loading/restore prewarm integration pass. The native
release dispersed-query batch reaches 0.43 ms; dense queries and full four-player
frame pacing remain open performance limits. See the [follow-up report](playtests/2026-10-24/premium-battle/README.md).
These source changes have not replaced the accepted production packages below.
The v0.17.0 release follow-up fixes a recorded ground-recovery corner stall; nine source checks and seven exported-pack checks pass. Final native package verification/publication is blocked by GitHub Actions budget/storage limits; see the [release report](playtests/2026-10-24/release-v0.17.0/README.md).

The earlier 23–24 October release work implements the requested battlefield polish, queued
technology research and clear elimination status. The then-current v19 macOS package
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

Four-player optimization has resumed locally under the latest request. Native
Windows four-player verification remains outstanding; its accepted two-player baseline remains above
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

2026-11-02: faction traits, nine bespoke signature units, exclusive technology/doctrines, faction AI, macro economy, tactical controls, command hubs, collapse/ruins, authoritative multiplayer/replay and exported scenario editing are implemented. Mounted infantry remain hidden while firing and reappear only after unloading. Current evidence and the remaining gates are recorded in the [completion audit](plans/benchmark-completion-audit.md).

The 80 new combat barks, all 16 narrated briefings and the specified faction music instruments are published and audited, including actual in-game speech recognition, headroom and synchronized playback. Earlier corrected actual60Hz multiplayer/replay runs passed the source/native and exported-fallback workflows. The frozen macOS candidate 5 now passes all 162 headless workflow rows, including 140/140 packaged scripts, the strict source texture gate and 14/14 actual multiplayer/replay checks, with the final command and CPU query changes included. Candidate 4 and candidate 3's terminal-receipt failure remain preserved. The strict 200-unit frame budget and final integrated release acceptance remain open in the [benchmark plan](plans/strategic-asymmetry-and-rts-benchmarks.md). Normal/graphical launches and further UI/OpenGL/performance qualification are prohibited under the latest restriction; headless implementation continues. The 30-cohort starter-field pacing matrix and all three faction operational engines are verified. Broader participant and repeated balance cohorts across maps, factions and strategies remain open. Historical defeats remain evidence rather than being rewritten as victories; distinguish ordinary live play from fixture reconstruction.

Novice and subjective acceptance require actual participants/user review; do not replace them with scripted assertions. The historical 2026-10-24 v19 macOS artifact passed its measured ordinary and synthetic maximum-load budgets, including retained warm-up tails; that evidence does not establish current v22 or MI12 qualification. Windows maximum-load acceptance is deferred. Record unavailable participant/platform/device acceptance explicitly.

## Broader acceptance still open

- Repeated campaign and skirmish balance across factions, maps, starts, difficulties, rewards and strategies; Free Frontier balance/usability; intended pacing. Scripted victories do not establish general win rates or 20–30 minute match pacing. Retained unsuccessful cohorts still require review.
- Five real novice trials, including choosing unit behaviors and understanding direct-order authority.
- Final subjective art, animation, audio and interface review, accessibility, physical-device checks and supported interface scales. Individual visual passes do not close these gates.
- Windows current-package exports and release checks remain deferred. Broader platform acceptance is open.
- Windows four-player FFA, longer matches and broader-device performance remain unverified; see the [current performance report](playtests/2026-10-23/PERFORMANCE.md) and [accepted v19 Mac measurements](playtests/2026-10-24/macos-current-v19-performance.json). The passing Mac synthetic workload does not establish four-player or all-platform acceptance.
- The F1 diagnostic overlay's top performance lines overlap the HUD rail in the native check; ordinary game controls remain usable. This diagnostic layout limitation is recorded in the [native report](playtests/2026-10-24/native-final-smoke-071518/result.json).

Naval content, additional faction variants and elaborate logistics remain later scope decisions. Current local/LAN PvP includes host/join, live spectators, reconnect and binary replay controls; the [platform report](playtests/2026-11-02/network-platform.md) records the verified authority boundary and numerical limits. The [development roadmap](DEVELOPMENT_ROADMAP.md) and individual playtest reports retain the detailed implementation history and evidence limits.

## Agent progress

- 2026-11-02 (current candidate 5 pass): The exact frozen macOS `qualified-run-5` passes all 162 headless workflow rows: 140/140 packaged scripts, strict pre-export source texture validation, 811 archives/389 recorded checksums, 1,152 layouts/zero failures, six dummy lifetime instances, startup/clock checks and 14/14 actual multiplayer/replay checks. The final command and six CPU query changes are included; [artifact verification](playtests/2026-11-02/headless-continuation/candidate5/artifact-verification.json) confirms zero source drift and matching signed helper/executable/PCK/ZIP hashes. ARM64 executed; the universal x86-64 slice received structural checks only. Candidate 4 and all failures remain preserved. Normal/graphical launches remain prohibited, headless work is authorized, and original 3D style is retained. The earlier 32.736 ms maximum frame still leaves MI12 and final release acceptance open.

- 2026-11-02 (current headless-only boundary): Normal/graphical launches are again prohibited; headless implementation remains authorized. The completed candidate 4 pass is preserved for its exact pre-optimization snapshot. Six later CPU query changes have focused native/fallback evidence. Before the renewed restriction, actual passenger controls, all 32 bilingual briefing captures and six OpenGL lifetime instances passed. The fresh actual-release native Low run keeps all 200 bodies selected/visible for 240 focused frames, with command 11.823 ms and median/p95/max frames 13.984/16.887/32.736 ms; zero timed pipeline changes do not close the strict 16.6 ms gate. MI12 and final release acceptance remain open. The [static original-style audit](playtests/2026-11-02/original-style-audit.md) records unchanged normal defaults and no saved graphics leakage without inferring the cause of an unseen user image.

- 2026-11-02 (headless verification, current): The frozen macOS `qualified-run-4` completed with `headless_checks_passed`: 139/139 standalone scripts, 811 archived saves/389 recorded checksums, six dummy resource-lifetime instances, 1,152 layout cases/zero failures and 14/14 actual multiplayer/replay checks. The [retained report](playtests/2026-11-02/headless-continuation/final/report.json) preserves the complete result; earlier failures remain intact. Graphical/UI/OpenGL and strict MI12 verification are authorized and pending. Final release acceptance remains open.

- 2026-11-02 (verification authorization): The user has authorized actual game launches. Graphical/UI/OpenGL review and strict MI12 verification are now authorized and pending; final release acceptance remains open. The immutable headless candidate 4 continues its 139-script and 14-check workflow, with its complete result still pending. Earlier launch restrictions and failed candidate evidence remain historical records.

- 2026-11-02 (headless candidate 4, launch): The refreshed frozen `qualified-run-4` is running all 139 standalone scripts and 14 real multiplayer/replay checks. It includes exact terminal receipt confirmation and a bounded terminal-only ENet shutdown drain, with verified host-drop handling and immediate ordinary exits. Focused source/fresh-pack peer checks and native/fallback Foundation checks pass; the complete candidate result is pending. Candidate 3's failed report remains intact. Graphical/UI/OpenGL, strict MI12 and final release acceptance remain deferred.

- 2026-11-02 (headless candidate 3 result): The frozen macOS `qualified-run-3` passed 139/139 standalone scripts, 811 archived saves/389 recorded checksums, six dummy resource-lifetime instances and 1,152/1,152 layout cases with zero failures. Its complete report is failed: the final network runner passed 11/12 because the host did not receive the terminal acknowledgment before the guest disconnected. The original failure remains retained; terminal-receipt delivery/retention and headless qualification stay open. Graphical/UI/OpenGL, strict MI12 and final release acceptance remain deferred.

- 2026-11-02 (final headless candidate, launch): The refreshed immutable `qualified-run-3` is running all 139 standalone scripts with all diagnosed corrections included. Focused checks cover normal startup cleanup and carrier selection for hidden passengers; source and packaged native/fallback tests verify the restored faction exclusions. Release staging discards stale export conversion caches. The complete headless result remains pending. Graphical/UI/OpenGL and strict MI12 qualification remain deferred.

- 2026-11-02 (headless continuation, intermediate snapshot): Source briefing layout passes 1,152 paragraphs across all supported interface/caption sizes. Ability-tray and formation CPU reductions and shared ground-travel accounting have focused native/fallback evidence, including paused v22 restore and hidden garrison handoffs. The immutable 139-script package attempt remains intermediate while startup shutdown and control-group recall corrections are incorporated into a fresh final snapshot. Graphical and strict frame qualification remain deferred; no final headless pass is claimed.

- 2026-11-02: Started the benchmark roadmap with integrated operational traits and regression coverage. Archived-save validation passes for 811 fixtures. Bespoke rosters, wreck-to-buggy conversion, macro economy, formations and narrative stages remain queued. The existing 8 px active-research console height excess at 720p/150% is reproduced on the original baseline and remains open. See the [trait implementation report](playtests/2026-11-02/faction-traits/README.md).

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
