# Research tiles and forgiving placement

## Stages

1. Reuse production tiles for research, including prices, descriptions on hover,
   availability, completion and the shared research progress/refund controls.
2. Permit modest ground variation across building footprints, retaining navigation,
   collision and cliff checks for circular and polygon footprints.
3. Verify research interactions and terrain boundaries with regressions; review
   rendered faction consoles and the original selected-lab layout.

## Agent progress

- Inspected production tiles, research actions and placement validation. Research
  uses oversized text rows; elevated placement currently allows only 5 cm variation.
- Completed stages 1–2: research reuses production tiles and tooltips, with a
  dedicated lab page, completed/active states, and an overlay that fits its contents.
  Foundations permit up to 0.6 m variation from their center and a maximum grade
  of 0.35. Navigation projection allows 5 cm of numerical displacement. Circular
  and polygon placement share these rules; AI polygon sites use ground height.
- Verification passed: `ResearchTilesRegression` (six faction/surface cases),
  `ResearchFeedbackRegression`, `BattleHudProductionRegression`, and
  `TerrainNavRegression`. Run headless suites with `--fixed-fps 60`.
- Rendered `HudConsolePreview` passed the full faction/language matrix, followed
  by its new `--research` subset covering hover, keyboard purchase and refund.
  Reviewed captures under `art/hud-console/`, including active research and the
  compact Tech overlay in English and Chinese.
- `TerrainPlacementPreview` passed: a real blueprint places and charges for a
  turret on the formerly rejected gentle ramp; overlapping buildings and cliffs
  remain blocked. Reviewed blueprint and built-turret captures under
  `art/terrain-placement/`. Water, rocks, excessive relief, polygon foundations,
  AI ground height, navigation, and save/restore are covered by terrain regression.
- Godot reports resource/ObjectDB leaks on shutdown in several existing test
  harnesses; functional assertions pass. No source, parse, or runtime script errors
  remain in the accepted runs. Generated editor import metadata was discarded.
- Completed stage 3: the existing `TechnologyPreview` also passes, including real
  mouse purchases, cancellation, pause restoration, completed upgrades and refunds
  after lab loss. Updated its obsolete scrolling assertion and made capture saving
  checked and independent of pre-existing output folders. Changed GDScript files
  pass formatting/lint checks; `git diff --check` is clean.
- Main integration: research tooltip lines follow the existing production contract
  (title, description, price, timing/status), preserving compatibility with pending
  inline-icon work in the main checkout. Added a regression for this ordering.
