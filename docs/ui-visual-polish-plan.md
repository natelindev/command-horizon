# Visual polish and asset reliability

## Stages
1. Repair imported infantry portraits and make direct launch import assets reliably.
2. Replace static construction ghosts with progress-driven building assembly and enlarge scenic trees.
3. Unify menu and battle controls, illustrate research, and redesign the home and skirmish map presentation.
4. Run asset, construction, research, and menu checks; inspect rendered captures at supported sizes.

## Agent progress
- Initial investigation: infantry SVG sources exist but their imported textures are missing; direct launch skips imports. Construction uses a static white material. Preview roads ignore map-provided width. Menu and battle themes have diverged.
- Stages 1–3 complete: 15 faction infantry portraits generated from game models; direct launch imports resources; progress-driven construction shader restores original materials; larger desert trees; shared menu/HUD theme, research artwork, redesigned home and terrain map previews.
- Verification: construction contract and restored visual progress passed for Bastion, Helix and Frontier; research feedback, menu scaling/settings, localization, and desert navigation/environment regressions passed.
- Rendered review: all six map previews, English/Chinese menus, 150% setup, visible Barracks portraits, active research, construction at 0/45/100%, and tree scale. Fixed transparent portrait rendering and a clipped setup footer discovered during this pass.
- Targeted GDScript lint/format, shader format and diff whitespace checks passed. Some headless suites still report engine resource cleanup warnings on exit; rendered visual regression exits cleanly.
