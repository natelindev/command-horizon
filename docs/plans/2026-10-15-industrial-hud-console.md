# Faction HUD consoles

Requested: the battle HUD reads like a web dashboard (floating flat cards, caption-over-number stat tiles, text pills, one body font, no material). Overhaul it into a **chunky industrial console** and restructure into a **bottom console** (minimap left, selection centre, commands right). Do not launch the game; headless runs are allowed. The front-end menus keep their current look.

## Decisions

> Revised mid-task. After the first chunky-industrial pass, the user asked for a more futuristic/tech feel and a different UI per faction. The console language below supersedes the original heavy-steel kit; layout decisions are unchanged.

- Per-faction kits share one futuristic console language (asymmetric chamfers, luminous edge lines with corner ticks, glass screens, slim keys with a soft light strip): Bastion armoured gunmetal + amber, Helix graphite glass + cyan, Frontier salvaged metal + orange. The kit follows the human player's faction.

- Art direction: heavy gunmetal plates with bevelled, chamfered edges, corner bolts, recessed dark "screen" sockets, keycap buttons, hazard-stripe accents and amber/brass highlights. Selection and active states use fills, insets and glow, never coloured borders. Keyboard focus keeps a visible bracket.
- Bitmaps are procedurally generated nine-slice textures (`tools/ui/generate_hud_kit.py` → `assets/ui/hud/`), so the kit is reproducible and editable. Native Godot controls and text are kept for localisation and accessibility.
- Typography: Barlow Condensed (OFL) for numerals, headings and keycaps, with Noto Sans SC fallback for CJK. Noto Sans SC remains the body font.
- Front-end/battle split: `ArtTheme` keeps the existing slate theme. `BattleTheme` becomes the industrial kit.
- Node paths used by tests and tools (`HUD/MarginContainer/Minimap`, `HUD/MarginContainer2/Resources`, `HUD/MarginContainer3/VBoxContainer/{ProductionQueue,UnitMenus}`) are preserved. Panels are re-anchored and restyled rather than renamed.

## Stage 1 — Survey and baseline

Map every battle-HUD surface and its layout constraints, and record a baseline of the 48 HUD-related headless regressions on an unmodified worktree.

## Stage 2 — Art kit

Generator for plates, sockets, keycaps (normal/hover/pressed/disabled/primary), tabs, rails, segmented bar tracks/fills and tooltips. Display font, and SVG glyphs for system and command actions.

## Stage 3 — Industrial theme

Rebuild `BattleTheme` on `StyleBoxTexture` nine-slices with type variations (plate, sub-plate, socket, keycap, primary, quiet, slot, tab, heading, numeral). Move the old theme into `ArtTheme` for the menus.

## Stage 4 — Console layout

- Top: a full-width rail with hanging plates. Resources on the left, mission clock in the centre, system keys and alerts on the right. The mission briefing and battle plan hang below the resources plate.
- Bottom: a rail joining the minimap housing (flush bottom-left) to the command deck (flush bottom-right). When nothing is selected, the deck shows an empty housing. Captions sit on the rail between them.
- Deck: `UnitMenus` becomes a two-bay console. The left info bay holds a portrait socket, name, segmented health bar and status. The right command bay holds the orders, command keycaps and build tiles in the existing scroll. The production queue is a tray on top of the deck.

## Stage 5 — Components and motion

- Resource readouts with icon sockets, large numerals and animated counters; a segmented power gauge.
- Command keycaps with icons and hotkey badges; compact build tiles with cost.
- Chunky tabs, an alerts beacon that pulses while unread, and a comms-style caption card.

## Stage 6 — Verification

- GDScript parse; gdformat/gdlint; `git diff --check`.
- HUD regressions compared against the baseline.
- New `HudConsoleRegression` for console layout invariants (flush anchoring, no overlaps, nothing outside the viewport at every interface scale).
- Review of the generated textures. Record what was not visually verified in a live render.

## Agent progress

- Stage 1 complete. Battle HUD surfaces: `ResourcesBar` (Match.tscn), `SkirmishHUD` mission panel + system buttons + notices, `SkirmishPlanPanel`, `BattleAlertsPanel` (layer 7), `BattleSubtitles`/`SubtitleCard` (layer 8), `Minimap`, `UnitMenus` (+ `CommandCard`, `RosterButton`, `SelectionRoster`, programs/squads/research pages), `ProductionQueue`, campaign objective panels stacked under the mission panel, pause/technology/relay overlays and results. `ControlGroupsDock` and `IdleWorkerBadge` are not instantiated anywhere. Layout constraints come from MenuWidth/RosterLayout (all deck controls inside `_scroll`), SubtitleLayout (caption clears minimap/deck, deck below y=72, caption fixed across selections) and CampaignControls (objective controls stable, above y=500). Baseline worktree: `/private/tmp/rtscheck/hud-base`. 15 of 48 HUD regressions already fail on the unmodified tree (BattleAlerts, BattlePlan, CampaignControls, CargoReturn, DefenseFocus, EngineerResponse, Frontier, ProgramIssues, RosterInfo, SaveRestore, SignatureFeedback, Skirmish, Tier3Ui); later runs are compared against those messages.
- Stage 2 complete.
  - `tools/ui/generate_hud_kit.py` (Pillow + NumPy, fixed seed) writes 2x nine-slice textures to `assets/ui/hud/`: heavy/panel/strip/card plates, sockets, keycaps (normal/hover/pressed/disabled/primary), tabs, rail, hazard, bar segments, focus brackets and glow.
  - `HudStyle.gd` draws them at half scale through `canvas_item_add_nine_patch`.
  - Barlow Condensed SemiBold/Bold (OFL) is added with Noto Sans SC fallback.
  - 17 SVG glyphs are in `assets/ui/hud/icons/`.
- Stage 3 complete. `BattleTheme` is the industrial kit (type variations HudHousing/HudStrip/HudCard/HudSocket/HudNameplate/HudSlotButton, HudHeading/HudCaption/HudNumeral). `ArtTheme` owns the previous slate theme for menus, settings, setup and the archive outside battle. The front-end tab selection now uses a fill instead of the old gold underline.
- Stage 4 complete.
  - `ConsoleFrame` (Match HUD) draws the top rail, the bottom rail with hazard accents, and a closed deck shutter when nothing is selected.
  - Resources plate (top-left) and system plate (top-right: mission clock, icon keys with hotkey badges, alerts beacon slot) hang from the top rail. The mission briefing, battle plan and campaign objectives dock in the left column.
  - The minimap screen has a fixed height (width follows map aspect) in a flush housing.
  - `UnitMenus` is a two-bay deck. The info bay holds portrait, name, segmented health, status and stop/cancel/rally. The command bay holds tab pages; Build/Produce lead for workers and producers.
  - Deck width adapts to the viewport (680–820) so captions keep a fixed gap.
  - The production queue is a tray on the deck and is drawn only while it holds jobs.
- Stage 5 in progress.
  - Done: rolling resource counters with an income glint, segmented power/health/production bars, pulsing alerts beacon, comms-style caption plate, results banner without coloured border or web palette.
  - Found but not changed (pre-existing gameplay issue): the Tier-3 `CommandCard` hard-codes Q W E R / A S D F hotkeys. These overlap the default WASD camera keys, and its Move/Atk Move/Target slots duplicate the rebindable direct-order keys.
- Layout verification so far: `tmp/hud-console/probe/LayoutProbe.gd` dumps console rects for Desert Frontier and Expanded Desert Frontier at interface scales 1.0 and 1.5 across empty/worker/tank/factory/multi selections. `tmp/hud-console/compose.py` renders them with the real kit, icons and fonts for review. 0 layout problems.
- Stage 5 complete.
  - Rolling counters, segmented bars, pulsing beacon, caption comms plate, deck fade-in that also runs during tactical pause, and a queue rack that hugs its jobs.
  - Verification so far: the 48 HUD regressions match the baseline, with CampaignControls newly passing. 80 further HUD-touching regressions run on both trees match the baseline (BlockedAssignment and Mechanics newly pass). The only other differences are an auto-generated node ID in AlpineEnvironment and the timing-sensitive SkirmishExpansionRaid simulation (a `MovingToUnit` action outliving its node; gameplay code, not touched here).
- User allowed launching the game. `tests/rendered/HudConsolePreview.gd` captures closed/worker/tank/factory/multi/alerts/pause/technology states. Reviewing them fixed:
  - order-key icons dropped by `expand_icon`;
  - unit names truncating;
  - the empty production tray spanning the deck;
  - the clipped alerts beacon;
  - mixed worker+tank selections leading with Build.
- Direction change (user): more futuristic/tech and a UI per faction.
  - The generator is now profile-driven and writes `assets/ui/hud/<faction>/`. `BattleTheme` caches a theme per faction, and `Match._enter_tree` selects the human player's kit. Accents (headings, badges, beacon, glow, focus, bars, minimap camera frame) follow the faction palette.
  - `HudConsoleRegression` checks the faction kit and accent. Its node lookups were fixed after a script error had let it pass silently; it now also asserts all 16 console states were checked.
- Stage 6 complete.
  - Final run of 49 HUD regressions: 37 pass (new HudConsoleRegression; CampaignControls fixed). All 12 failures are identical to the unmodified baseline.
  - SkirmishExpansionRaid's `MovingToUnit` script error reproduces on the baseline.
  - gdformat/gdlint clean on changed scripts; `git diff --check` clean; the generator is deterministic.
  - Final rendered captures for Bastion (720p), Helix (1080p) and Frontier (720p) are in `art/hud-console/`.
  - Not changed: the Tier-3 CommandCard hotkey overlap with WASD camera keys (gameplay decision for the user). Test runs rewrite tracked playtest artifacts; those were restored after each run.
