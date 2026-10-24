# Battlefield polish and strategic refinement

## Scope

Implement the requested readability, HUD hierarchy, movement/command feel,
combat presentation, onboarding, performance, adaptive music and endgame polish,
plus subgroup cycling, patrol, contextual rallies, veterancy and high ground.
Include the follow-up neutral-symbol review and diagnostic-only unit captions.
Address the later four-player FFA sluggishness report, queued technology
upgrades and clear player-elimination indicators.
Preserve faction identities, accessibility, localization, tactical pause and
save/load contracts. Stop work if the Codex CLI reports 0% remaining usage.

## Stage 1 — Inspect and define contracts

- Establish the current implementation and verification commands.
- Use conservative, symmetric bonuses for veterancy and terrain; retain armor
  counters, obstruction and enemy information boundaries.
- Coordinate file ownership across independent implementation agents.

## Stage 2 — Combat presentation and control quality

- Delayed damage chunks, bounded hit flashes, faction selection geometry,
  heavy shockwaves and capped burning wreck effects.
- Mixed-selection subgroup cycling, looping patrol orders and contextual rallies.
- Clearer HUD hierarchy, readable terrain/units and a closer default camera.
- Neutral UI/model emblems and unit information text controlled by F1 diagnostics.
- Review mixed-force passage, retreat, factory exits and crowded arrivals.

## Stage 3 — Strategy, sound and match flow

- Saved Bronze/Silver/Gold veterancy with modest reload/movement bonuses.
- Plateau vision and firing-range advantages, excluding aircraft and preserving
  line of sight and line of fire.
- Adaptive music layers and HQ-collapse cinematic respecting the rebuild grace.
- Post-match battlefield inspection with safe results navigation.
- Contextual introductory guidance for economy, production, orders, recovery
  and capture; retain the existing campaign structure.

## Stage 4 — Integration and verification

- Focused regression checks for new mechanics, save/pause lifecycle and controls.
- Convert archived snapshots if the snapshot version changes, preserving IDs.
- Rebuild localization and generated HUD assets through their source scripts.
- Native rendered review of all faction HUDs, combat/readability and endgame.
- Serial ordinary/stress frame benchmarks with exact hardware/workload reporting.
- Run available desktop-platform checks and prepare a novice playtest protocol;
  actual participant acceptance requires people and cannot be substituted with
  scripted checks.

## Stage 5 — Live-match follow-up

- Reproduce the recovered Copper Badlands four-player FFA setup with active AI,
  the observed graphics options and verified actual rendering resolution. Keep
  the earlier two-player 1080p workload explicitly separate.
- Queue paid technology upgrades in order, including Coordination and dependent
  upgrades; show queued work, allow cancellation/refunds and preserve the queue
  across saves. Convert current archives when the save contract changes.
- Announce actual player elimination and retain a clear status in the player
  list, respecting the HQ rebuild grace period.
- Verify loading-time effect preparation, updated research controls, elimination
  feedback, saved state and representative four-player performance.

## Agent progress

- The repository was clean at kickoff. Independent agents own combat effects,
  controls and music/endgame; the coordinating agent owns strategic mechanics, readability,
  guidance, snapshot integration and final verification.
- Inspection identified existing command feedback, physical projectiles, terrain
  occlusion, faction HUDs and audio priorities; the additions extend these systems.
- Stage 2: damage chunks, hit flashes, faction markers, bounded shockwaves/wreck
  fires, subgroup cycling, patrol and contextual rallies are implemented. Focused
  regression, combat, HUD and terrain rendered checks pass.
- Stage 3: saved veterancy, plateau bonuses, adaptive music, HQ cinematic and
  postgame inspection are implemented; focused strategic, save/pause and endgame
  checks pass. First Orders now gives contextual economy/order/recovery hints.
- Stage 4: 810 archived snapshots passed the v18 schema audit. The later
  user-requested cleanup removed all 927 recognized obsolete snapshots from
  archives, temporary backups, macOS game data and three Windows checkpoint slots.
  Current fixtures are retained.
- Initial movement, combat, music, strategic/save, localization and UI checks
  passed. The first rendered review covered 184 captures. These are historical
  focused results, not a completed final exported-package acceptance gate.
- 2026-10-24 audio review is complete within the available tools: 15 native
  CoreAudio bus recordings have zero clipped samples, and unprompted recognition
  correctly transcribes the base warning in three mixed excerpts and three
  isolated Voice controls. The scenario is moderate combat. Human listening
  quality and maximum-population mixer acceptance are not inferred from it.
- The expert onboarding flow passes with 11 captures. Required instructions now
  precede optional hints, lesson changes reset scrolling, and loss of armor
  leads through completed vehicle-factory, engineer or HQ recovery. A separate
  rendered run confirms six English/Chinese lesson views at exact 720p/150%.
  Tiny placement text was replaced by a compact localized screen-space panel;
  its focused regression and three 1080p/720p native captures pass. Earlier flow
  images retain the old label and are identified as historical. Evidence is in
  [AUDIO_ONBOARDING.md](../playtests/2026-10-23/AUDIO_ONBOARDING.md).
- The earlier catalog contained 2,248 regenerated entries. PlacementFeedbackRegression
  and UnitInfoTextRegression are included in the 73-suite macOS exported-package
  gate. The full macOS baseline passed all 73 suites. A later fixture-only refresh
  reran two corrected suites in English and Chinese and carried forward 71
  unchanged results; exactly two of 5,594 packed resources changed. The initial packaged
  NavigationRegression reached 11 of 12 crowded tanks; later runs reached all 12,
  but the intermittent failure's cause remains unresolved.
- The restored fog-memory material error is resolved by detaching surface
  overrides before mesh deletion in live and restored memories. Three headless
  FixedWingSaveRegression repeats, SaveRestoreEdges, ConstructionStyleRegression
  and native Metal landing pass the affected checks. The native landing harness
  retains known direct-quit audio warnings, documented separately from this fix.
  See the [material-lifetime record](../playtests/2026-10-24/material-memory-lifetime.json).
- Particle-resource and Set cache lifetime fixes pass focused release/rebuild
  checks. The latest native combat preview has 10 captures, active sparks and
  resource-depletion particles, zero failures and no shutdown diagnostics; menu
  and window-close harnesses also exit cleanly. The older particle RID warning
  is resolved. Forced `--quit-after` menu-audio teardown warnings are recorded
  separately. Normal-app Cmd-Q passed on the prior export with exit 0 and no
  ObjectDB/resource/RID teardown diagnostics; its verbose log retains two
  texture-format conversion warnings at startup. The full-suite export after all
  symbol, unit-caption and CPU changes passed all 73 packaged suites, strict deep
  code-signature verification and native menu → live skirmish → Cmd-Q. Source and
  package hashes stayed unchanged. Seven Metal format-conversion warnings remain
  recorded; no native script errors or resource leaks occurred. The
  [preserved baseline](../playtests/2026-10-24/macos-full-suite-baseline.json) links
  all 79 retained text logs. The fixture-only refresh also passes native menu →
  Cmd-Q and strict signature verification, retaining two startup conversions and
  no shutdown errors. The [preserved fixture-refresh report](../playtests/2026-10-24/macos-package-v19/previous-final-macos-packaged.json)
  records the four focused locale runs, 71 carried-forward results, exact resource
  comparison and unchanged unsigned engine binary. Its retained original artifact
  paths map to the [preserved copies](../playtests/2026-10-24/macos-package-v19/previous-release-preservation.json).
- The requested neutral-symbol changes are complete. UI recovery/repair uses
  wrenches, research uses bars/chevrons, targeting uses open brackets, and the
  repair-site map legend matches S/修 markers. Generated Bastion HQ and service
  models use a communications panel and toothed gears. All 45 UI SVGs were
  visually audited; 14 native UI captures at 720p/150% across all factions and
  both languages, 12 weathering captures, nine model views and the localization
  and rich-texture regressions pass without diagnostics. A compact
  [audit summary, logs and hashes](../playtests/2026-10-24/symbol-review/README.md)
  are retained in the playtest record; PNGs remain local. The audit covers
  cross/religious-looking emblems, not ordinary braces, arithmetic or names.
- Repeated unit information text now follows the existing F1 diagnostic toggle
  and starts hidden in every match, including debug builds. Mode, signature,
  preparation, action, garrison and commander captions refresh when enabled;
  health/rank markers, weapon effects, command controls and map-site labels keep
  their normal behavior. The focused regression and six native bilingual
  720p/150% captures pass and reproduce the Water Stop Camp Precision-label
  report through ordinary play, F1 diagnostics and ordinary play restored.
  WeaponModeRegression and PreparationRegression pass; the latter now checks
  restored text under diagnostics and respects the actual shared-reload deadline
  before asserting an immediate Interception shot. Production weapon behavior
  is unchanged. [Evidence, captures and hashes](../playtests/2026-10-24/unit-info-review/README.md)
  retain all results and the older direct-quit teardown warnings.
- The preserved macOS release baseline passes steady-state budgets at actual 1920×1080:
  ordinary 70-unit combat p95 15.41 ms; 200-mobile/80-structure combat p95
  30.46 / 29.84 ms. Both stress repeats move all 200 units and have no sampled
  frame above 100 ms. All three release benchmark processes exit cleanly.
  [PERFORMANCE.md](../playtests/2026-10-23/PERFORMANCE.md) links exact build hashes,
  method and raw results. Later native-focus runs also meet those targets but
  expose roughly one-second first-use rendering stalls. A diagnostic prewarm of
  hit-flash, ground-scar and shockwave variants moves that work into loading and
  preserves paused game/cosmetic state. The production helper subsequently passed
  native timing with no gameplay frame over 50 ms; final v19 integration below confirms this in four accepted runs.
  Windows foreground stress combat p95 is 36.80 ms, above its 33.3 ms target.
  Three further CPU optimizations pass ten focused checks. Windows timing and
  package work are now explicitly deferred at the user's request. Background and
  competing-game samples remain excluded.
- Five real novice trials, subjective listening and physical input-to-photon
  latency remain unverified. Expert scripted UI review and automated speech
  recognition do not substitute for those human/device acceptance results.
- 2026-10-24 live-match feedback: the user closed the Windows game and reported
  sluggish four-player FFA play, requested queued technologies and explicit
  elimination status. The saved setup identifies Copper Badlands, human Helix,
  three random AI opponents and high graphics settings; no live battle snapshot
  exists. Preserve the user's post-play preferences and saves. The user then paused
  all Windows work; the unexecuted four-player fixture, evidence, preserved state
  and precise next steps are recorded in
  [WINDOWS_HANDOFF.md](../playtests/2026-10-24/WINDOWS_HANDOFF.md).
- Stage 5: prepaid FIFO research, dependent-upgrade cancellation/refunds and v19
  save/restore are implemented. Focused queue, research-tile and localization
  checks pass. All 810 current archives validate with 389 refreshed checksums;
  every prior value and unit/resource ID is preserved, and the 810 obsolete
  conversion backups were removed after validation. Bilingual native rendered review passes six cases/18 captures, including keyboard
  queue/cancel/refund, scrolling, focus and pause ownership. The catalog contains
  2,266 entries. Final current-package integration passes as recorded below.
- Stage 5: a persistent commander list and elimination announcement are implemented,
  with actual elimination after the rebuild grace, paused/restored state and
  eight-player scrolling covered. All-faction English/Chinese native 720p/150%
  review passes, including wide resource balances. The remaining four-player
  low-frame-rate report is deferred with Windows and is not claimed fixed.
- Current v19 macOS export passes all 75 registered packaged suites and strict/deep
  signature verification. Source, ZIP, PCK and executable hashes remain unchanged.
  Five additional affected research/save suites also pass against that same PCK.
  Four native foreground runs of the frozen production source pass all working
  budgets: ordinary combat p95 14.95 / 16.53 ms and synthetic stress combat
  28.57 / 30.70 ms. Across 4,557 unique gameplay frames, including ordinary
  warm-up, the maximum is 40.50 ms and none exceed 50 ms. Full paused snapshot,
  cosmetic state, node and process-mode preservation passes. Raw hashes and
  rejected-fixture evidence remain in the
  [current timing record](../playtests/2026-10-24/macos-current-v19-performance.json).
  These short runs use fresh/warm game caches, without resetting OS/driver caches.
  Static checks pass for all 133 changed/new GDScript files and six Python files.
- Final current-PCK native menu → skirmish → F1 running/paused → F5 save → archive
  load → paused restore → resume → Cmd-Q passes in an isolated, locally signed
  copy. The original artifacts and 56 pre-existing user files are unchanged;
  the game log is clean. The existing F1 performance-text/HUD overlap remains a
  documented diagnostic limitation. See the
  [native record](../playtests/2026-10-24/native-final-smoke-071518/result.json).
  All authorized local implementation and verification is complete. Windows
  investigation remains explicitly deferred; actual novice, subjective listening,
  physical-latency and broader performance acceptance require the listed follow-up.
