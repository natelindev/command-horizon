# Polish program (2026-10-16)

Goal: make Open RTS extremely polished and well developed. Each workstream is reviewed
against shipped quality (rendered captures, measured audio, clean UI, complete Chinese
localization, regressions) before it is merged.

## Stages

1. **Voices** — battle-hungry native-accent crew, robotic robots, light radio colouring,
   loudness-matched (details: `2026-10-15-unit-voice-overhaul.md`).
2. **Parallel workstreams** (isolated worktrees, reviewed and merged one by one):
   - HUD: hideable skirmish plan card, production icons, queue ≥ 12, global production
     queue indicator, then a HUD declutter pass.
   - AI: Easy / Normal / Hard difficulty.
   - Construction: faction-unique build-in-progress effects.
   - Maps: equal resource path distances per start, then many more points of interest.
   - Animation: unit animation audit and polish (visual only).
3. **Menus** — after the AI difficulty merge: main menu and pre-game picker rebuilt on the
   battle-HUD design system, decluttered.
4. **Campaigns** — three hero-led faction campaigns (Bastion / Marshal Aegis, Helix /
   Spectre Nyx, Frontier / Pathfinder Rook) told from the hero's perspective with personal,
   emotional writing (relationships, loss, revenge), character conversations, many more
   voice lines, fuller maps. Approved scope: 16 missions, English voices with Chinese
   captions, heroes must survive and gain abilities.
5. **Performance** — last, after everything above is merged: profile and optimize the whole
   game (CPU, GPU, memory, load times) without visual or gameplay regressions.

## Verification constraint

The earlier headless-only phase is complete. The user explicitly authorized actual game
launch and rendering on 2026-10-16. Rendered previews, live interaction and GPU/frame-rate
measurements may now proceed. Historical headless evidence remains unchanged.

## Agent progress

- [x] Captions off by default; preserved during integration.
- [x] Campaign outline approved in Claude session: 16 missions (6 Bastion + 5 Helix +
  5 Frontier), English VO + Chinese captions, must-survive heroes with abilities.
- [x] Preserved main checkout and five agent worktrees in
  `/private/tmp/rts-polish-backup-20261016` (patches, original files, HEADs).
- [x] Integrated HUD, AI, construction, maps and animation changes into the main working
  tree. Original worktrees remain intact. Resolved HUD overlap and translations by key.
- [x] Stage 1 correction — rebuilt exactly four revised lines and eight Frontier drone
  clips. No other clip changed. Updated catalog and audition reel; build QC, mix checks,
  asset checks and all nine voice unit tests pass.
- [x] Stage 1 automated acceptance — final shipped-file transcription/identity audit
  passes (390 clips, 45 speakers, mean word error 0.006, max cross-speaker similarity 0.494).
  Final subjective listening acceptance remains.
- [x] Stage 2 integration checks — HUD production/layout, construction styles, animation,
  map balance/POI, save/restore, localization and audio headless suites pass.
- [x] Easy AI cap now counts pending mercenary hires in both factory and camp decisions;
  regression covers all three factions.
- [x] Stage 2 AI acceptance — 600-second headless Easy/Normal/Hard simulation passes;
  first attacks at 181.3/121.7/75.7 seconds and army values at 600 seconds of 232/538/680.
  Menu, roster, orders, construction, save/restore and campaign regressions also pass.
- [x] Stage 2 map follow-up — BastionDesert/BigArena gained symmetric facilities,
  salvage and landmarks; navigation, clearance, symmetry and save checks pass.
- [x] All-faction Easy/Normal/Hard 600-second simulations pass.
- [x] Nine active-opponent AI matches pass (three factions × three difficulties).
- [x] Stage 3 implementation — menus now use BattleTheme through ArtTheme; removed fake
  telemetry and redundant main-menu copy, kept native keyboard controls, added responsive
  skirmish layout and collapsible legend. Player faction controls the setup console theme.
  English/Chinese menu fit, keyboard focus, settings and picker behavior pass headlessly.
- [x] Stage 3 rendered review — bilingual main/skirmish/campaign menus and faction HUD
  captures pass; production tile price overflow and campaign faction frame refresh fixed.
- [x] Stage 4 foundation — drafted 160 bilingual lines across 16 missions; implemented
  ordered conversations, portraits, pause/skip and exact active/queued-scene restoration.
  All 96 authored conversations are installed, with compatibility for legacy narration saves.
- [x] Stage 4 gameplay — hero progression, six Bastion slots, ten Helix/Frontier missions,
  campaign UI and compatible saves are implemented. All eleven new authored operations
  complete in normal headless combat with harvesting and paid reinforcements.
- [x] Stage 4 audio — all 160 English recordings, 13 unique speakers and 96 conversations
  installed. Independent shipped-Ogg transcription/identity audit passes; English/Chinese
  caption, portrait layout and active-dialogue restoration regressions pass.
- [x] Stage 5 preliminary stress check — 200 mobile units and 80 structures pass
  headlessly; all 200 move, 160 fire. This is functional evidence, not rendered FPS acceptance.
- [x] Stage 5 initial CPU/memory profile — 200 Lua VMs remain functional, but the
  maximum-load debug/headless real-time run takes 13.93/15.77 wall seconds per ten
  simulated movement/combat seconds (about 511 MiB peak RSS). Animation ablation and
  spatial-query probes recorded; removing animation alone does not meet real time.
- [x] Stage 5 CPU — typed hot loops, render-frame posing and a verified flat-terrain
  projection index reduce maximum-load movement/combat time by about 23%.
- [x] Broad movement/save/legacy campaign checks pass after fixing a two-turn worker
  contact-recovery gap and correcting stale isolation fixtures. Captured replay,
  crowded harvesting, HQ traffic and all-faction Alpine field approaches pass.
- [x] Stage 5 campaign load/memory — all 16 missions reach navigation readiness,
  214–4165 ms per load; peak RSS 355 MiB, post-close static memory settles near 96 MiB.
- [x] Stage 5 exported resources — six campaign/portrait/native-Lua regressions pass
  against the macOS release PCK in an isolated directory. Both native architectures included.
  Final arm64 release completes 40 million accelerated headless menu frames (173 seconds)
  after removing redundant settled-music volume updates; signature verification passes.
- [x] Stage 5 rendered measurements recorded: ordinary 30/70-unit scenes average 105/73 FPS.
- [ ] Maximum-load performance acceptance: 200 mobile units + 80 structures + 200 Lua VMs
  average only 7.0/4.7 FPS; GPU timestamps are unavailable on this setup.

Evidence: `docs/playtests/2026-10-16/polish-integration/README.md` and
`docs/playtests/2026-10-16/headless-continuation/README.md`.


### Rendered acceptance stages (authorized 2026-10-16)

1. Review faction HUD, menus and bilingual campaign conversations at representative sizes.
2. Review campaign environments, construction and unit animation; fix visual defects.
3. Measure rendered frame times/GPU cost and validate the packaged game startup.
4. Archive captures, results and remaining human acceptance items.

- [x] Rendered UI and campaign review: all 16 openings, 60 faction HUD states, bilingual
  menus and native-style briefing skip/result interactions. Fixed first-frame fog and
  nested alert-layer visibility; regression checks pass.
- [x] Environment, construction and animation captures reviewed: 16 campaign interiors,
  12 construction views and 51 animation sheets.
- [x] Rendered performance measured and packaged main-menu startup observed.
- [ ] Manual packaged UI interaction: native automation reports `noWindowsAvailable` on
  clicks after discovery/rebinding; scripted rendered interactions pass.


### Campaign interiors and map selection (user feedback, 2026-10-16)

1. Retire sparse legacy skirmish choices; migrate saved setup preferences to expanded equivalents.
2. Add biome-appropriate districts, vegetation and terrain inside all campaign battlefields,
   protecting bases, resources, objectives and mission routes.
3. Verify navigation, convoy travel, save/restore and live rendered composition; rebuild the package.

- [x] User approved campaign interior improvements as well as skirmish map retirement.
- [x] Curated three-map roster and legacy path/numeric preference migration verified.
- [x] Campaign interiors implemented and visually reviewed. Final 64 captures pass.
  Command Horizon reinforcement corridors and forward construction space remain clear.
- [x] Campaign mission routes and save/restore checks pass after map changes; all eleven
  new missions plus five legacy campaign combat scenarios complete. Ten packaged checks pass.
  Native main-menu rendering verified; manual interaction remains limited as recorded above.

### Persistent neutral ownership (user request, 2026-10-16)

1. Keep ownership after the final garrison occupant leaves or dies; allow infantry to recapture empty enemy buildings.
2. Persist the independent owner in version 13 snapshots while accepting older saves.
3. Verify contextual commands, occupied-building defense, save/load, facilities and rendered ownership labels; rebuild the release.

- [x] Original six-failure reproduction now passes. Ownership persists through vacancy,
  occupant death and save/load; enemy infantry recapture empty buildings through contextual orders.
- [x] Old version 11 occupied and version 12 vacant saves load correctly. Invalid or
  mismatched owners are rejected. Destroyed buildings retain the existing collapse behavior.
- [x] Neutral world, all-faction facilities, save snapshots and production activity checks pass.
  Three rendered ownership captures pass.
- [x] All 14 rebuilt package checks pass after the ownership change. Native Metal startup
  exits successfully; deep bundle/native-library signature verification passes.

Evidence: `docs/playtests/2026-10-16/rendered-continuation/README.md`.

### Release v0.11.0 (user request, 2026-10-16)

1. Commit the complete integrated project and update release metadata.
2. Push main and build native Lua plus verified desktop packages on each platform.
3. Publish v0.11.0 with release notes and downloadable artifacts.

- [x] Version and changelog updated; release workflow builds native Lua on Linux, Windows
  and macOS and checks exported gameplay resources before uploading packages.
- [ ] Commit/push, native platform builds and release publication.
