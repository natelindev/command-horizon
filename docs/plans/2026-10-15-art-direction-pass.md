# Art direction pass

Requested: address every point of the artistic review (lighting, style coherence, faction identity and team colour, unit readability, terrain detail, combat effects, HUD) without launching the game. Verification is limited to parsing, lint/format and headless regressions; no rendered captures are taken in this pass.

## Stage 1 — Survey

Map the atmosphere controller, per-map environments, tactical fog, minimap, team-colour sources, unit indicators, HUD theme/layout, ground shaders and faction structure materials. Identify which review findings remain in the current code rather than in older screenshots.

## Stage 2 — Lighting, grading and tactical fog

Sky-tinted ambient light, lower key light with longer shadows, ambient occlusion by default, per-biome colour grading and exposure (desert, alpine, coastal, industrial), and a tinted/desaturated fog of war instead of pure black.

## Stage 3 — Team colour, faction identity and unit readability

One designed palette for player colours used consistently by units, structures, minimap, selection and HUD. Replace raw primary accents. Strengthen faction material identity (Bastion, Helix, Frontier) and make the player HQ read as a faction building. Improve unit readability: ground contact markers, restrained overhead indicators, styled health bars and selection.

## Stage 4 — Terrain and combat aftermath

Add mid/fine-scale ground detail and road-edge blending to the biome ground shaders, plus route wear. Make combat aftermath and impacts more legible within the existing effect budgets.

## Stage 5 — HUD

Lighter, more compact battle panels; consistent styling with menus; remove placeholder-looking controls (empty alerts box, empty command slots); terrain-rendered minimap.

## Stage 6 — Verification

GDScript parse, gdformat/gdlint, shader clang-format, `git diff --check`, and the affected headless regressions. Record what was not visually verified.

## Agent progress

- Stage 1 complete. Corrections to the original review: the brick building in the capture is a neutral garrison, not the Bastion HQ (already an octagonal fortified keep); overhead ownership markers were already removed; Helix "pure blue" came from the `PlayerSettings` fallback colour used by fixtures and the battle arena. Remaining issues confirmed in code: per-map lighting mostly overwritten at runtime and no grading; explored fog as a 75% black veil; pure-primary highlights and health bars; centimetre-scale infantry team marks; unfiltered sub-pixel ground grain; hard-coded shader pads misplaced on enlarged maps; transparent alerts toggle; permanently empty ZXCV row; grey minimap.
- Moved work to the `art-direction-pass` worktree because a concurrent session was running the full suite in the main tree.
- Stage 2 complete: biome profiles (key/fill/haze/exposure/contrast/saturation/split-tone curve) in `AtmosphereProfiles.gd`, applied by `WorldAtmosphere`; dead per-map lighting code removed; lower midday sun; desaturated cool fog memory with unchanged unexplored black; matching minimap fog.
- Stage 3 complete: designed eight-colour team palette used by skirmish, campaign, demo and arena (arena previously had two identical pure-blue sides); softer highlight colours; framed, health-coloured bars; team ground footprints for mobile units and aircraft; larger upward-facing infantry team trim; less metallic team material with faint emission. Unit scale and faction structures unchanged (deliberately tuned; HQ already faction-specific).
- Stage 4 complete: anti-aliased grain and crumbled asphalt edges (coastal, district, foundry, horizon), rain on Broken Foundry ground, richer base desert, enlarged-map pad alignment; faction-tinted fire and budgeted heavy muzzle light.
- Stage 5 complete: filled alerts toggle, hidden empty command rows, slightly translucent panels, session-remembered battle plan collapse, biome-tinted minimap with a one-time rendered terrain capture.
- Stage 6 complete. User later allowed launching the game, so rendered review was added.
  - `tests/rendered/ArtDirectionPreview.gd` captured desert, alpine, coastal, urban and Bastion Desert battles plus a minimap close-up (`art/art-direction/`), compared against the same captures on an unmodified worktree. Tuning from review: less orange desert grade, brighter/less cold fog memory, darker minimap terrain beneath markers.
  - `tests/rendered/CombatPreview.gd` passed (118 shots, 109 impacts, 13 deaths, bounded pools); captures inspected, tracked review stills left unchanged.
  - New `tests/headless/ArtDirectionRegression.gd` passes (palette, biome mapping, grading, warm key/cool fill, sun height, layout scale, footprints, health bar colors/frame, hidden empty command row); a mutation restoring the old sun height makes it fail.
  - Targeted headless regressions match or improve on the unmodified baseline. Failures shared with the baseline and unrelated to this pass: Tier3Ui range ring, BattlePlan advice, ProgramIssues explanations, BattleAlerts power resolution, CampaignControls, Combat, InfantryMotion; ExpandedMapRegression times out at 600 s on both (no failures before timeout).
  - gdformat/gdlint on changed scripts, clang-format on the new shader, and `git diff --check` pass.
- Not changed: unit model scale (user-tuned relationships) and faction structure models (already distinct).
