# Campaign and battle console polish — 2026-10-17

Campaign dialogue now always shows its text, regardless of the optional unit-speech
subtitle preference. Briefings and battle conversations use the same localized
lines as their voice playback. Urgent battlefield reports can still pause a story
conversation; it resumes with its caption afterward.

Objectives now explain infantry capture distances, uncontested hold times, convoy
checkpoint controls and hero proximity/survival requirements. **View objective**
focuses the current destination without issuing unit orders. Supply Line explains
when trucks must stop and when Advance convoy must be pressed again.

The command deck spans the remaining bottom edge beside the minimap, matching its
height. Selection details, direct commands and behaviors use separate columns.
Build/produce pages and paid queue controls remain available. Empty pages are
hidden. The skirmish Battle plan panel and its settings toggle are removed;
assigned-engineer shortcuts work independently.

Selection portraits expand into their cards. Empty health labels no longer reserve
space, and a cached atlas trims transparent margins around the existing model art.
No portrait image files were regenerated.

Owned mercenary camps open their recruitment menu when clicked, including during a
tactical pause. Their existing paid queue, population reservation, cancellation,
refund, contest and save/load rules remain in force.

Existing mature tree models and leafy BirchScrub replace flat DryScrub/RoadSage
placeholders. Trees are generally 6.5–7.5 m tall, bushes 1.6–1.9 m. Scenic scatter
remains batched in multimeshes, with reduced density and wider road clearance.
Coastal pines retain their original ground footprint, with increased aircraft
clearance for the taller canopy. No new collision bodies were added for vegetation.

## Verification

Headless checks passed with no script errors:

- CampaignDialogueRegression, CampaignStoryRegression and CampaignStoryMissionsRegression:
  captions with unit subtitles disabled across all 17 supported missions, live
  English/Chinese switching, pause, interruption, skip and save/load.
- CampaignRegression, SupplyLineRegression, HeroCampaignRegression and
  CampaignControlsRegression: First Orders victory, convoy conditions, hero stages,
  objective navigation, pause and controls.
- SelectionRosterRegression and BattleHudProductionRegression: all factions,
  portrait framing, selection, paging, keyboard controls, damaged/dead units,
  production, costs, refunds, queues and save/load.
- PointOfInterestRegression: capture, recruitment UI, production, opposing ownership,
  refunds, services, population reservations and saved contracts for all factions.
- SubtitleLayoutRegression: caption clearance across maps, interface scales and
  subtitle sizes, selected/empty decks and paid queues.
- VegetationRegression and VegetationMapsRegression: real model sizes, no flat
  scatter or new plant collision, and working home-to-home navigation on all six
  standard/expanded skirmish maps.
- ExpandedMapRegression with `--geometry-only`, the focused CoastalFoundry geometry
  checks, WeaponModeRegression, BattlePlanRegression and LocalizationRegression.
- ChineseUIRegression: 1,140 unique UI strings and 687 voice captions, zero failures.
- `gdlint source/` and `git diff --check`.

Rendered checks use the native Godot renderer, without `--headless`:

- HeroCampaignPreview: all 16 current campaign openings, battle captions and map
  views; English and Chinese, including enlarged interface/subtitle settings.
  The portrait/caption fixture freezes combat so urgent reports cannot interrupt
  the line being captured; interruption itself is covered by the headless checks.
- SelectionRosterPreview: all factions, infantry portraits, mixed/full selections,
  paging, mouse and keyboard input, and exact bottom-console/minimap alignment.
- HudConsolePreview: all faction consoles in English/Chinese, selection, production,
  menus and technology, with bottom-band alignment assertions.
- MercenaryCampPreview: actual mouse clicks on captured camps and Hire controls,
  plus camp access during tactical pause, for all three factions.

Raw run logs and JSON summaries are in the ignored local directory
`tmp/campaign-polish-2026-10-17/`. Representative captures are retained under
`art/campaign-polish/` and `art/hud-console/*-behaviors.png`.

## Limits

Verification used macOS/Apple M1 Pro. Windows/RTX 4090 performance and animation
still require a hardware run; the earlier optimization and gait investigation are
recorded in `docs/performance/RESULTS.md` and `FOLLOW_UP.md`.

Some archived environment suites are incompatible with the current map content:
Desert/Alpine assume the first Decorations children are old shelves, but encounter
settlement buildings instead. Horizon compares an older geometry/navigation archive
and an old unpaused save against paused-state expectations. These runs failed and
are not counted as passing. Current vegetation/map navigation and coastal envelope
checks passed; those archived fixtures still need maintenance.

Godot also prints resource/shader cleanup warnings at exit in several harnesses;
passing status above requires successful assertions, exit code zero and no script
errors, rather than relying on a printed summary alone.
