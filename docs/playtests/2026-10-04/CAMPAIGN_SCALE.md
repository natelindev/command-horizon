# Campaign scaling and HUD clearance

## Changes

Subtitles now fit between the actual minimap and selection/production controls. Minimap size, HUD geometry, window size and interface-scale changes reposition an existing caption immediately. Normal selection retains the caption position; a wider command panel reserves its real bounds. Text still wraps, keeps the selected subtitle size and ignores pointer input.

Oversized unit panels now scroll below the top resource/Alerts strip, leaving room for the paid production queue. Wheel and arrow-key scrolling work, keyboard focus brings offscreen controls into view, and changing the selection resets the scroll position. Short panels retain their natural height.

## Reproduced defects

The old subtitle layout reserved a fixed 228-pixel left region. Larger maps have wider minimaps: Supply Line reaches x=399 and Command Horizon x=383. At 150%, captions started at x=228 and obscured those maps. At 125%, several overlaps remained. The [original matrix](campaign-scale-before.log) reports 112 failed caption checks across eight mission/scale combinations; all 14 speech lines are checked in each combination. [Previous subtitle source](campaign-scale-before-BattleSubtitles.gd.txt) is retained.

Visual review also found Command Horizon's fully unlocked tank panel starting at y=38 under the top HUD. The [focused failure](campaign-scale-panel-before.log) reproduces this at 150%. The new scroll region keeps its outer panel at or below y=72 and leaves its bottom actions reachable. [Previous unit-menu source](campaign-scale-before-UnitMenus.gd.txt) is retained.

## Verification

- [Campaign matrix](campaign-scale-render-final.log): six real missions × three interface sizes (100/125/150%) × 14 speech lines, with the largest subtitle text. Each line must actually be displayed and its bounds clear the minimap, selection and production controls. Scene geometry and camera-navigation buttons are checked at all 18 mission/scale combinations. Layout checks isolate caption lifetime; the speech suite separately verifies real timing.
- The same rendered test verifies right-click orders through the scaled caption; wheel/arrow scrolling and focused Save version visibility in the oversized Horizon panel; selection scroll reset; and live resize to 1440×900, 1920×1080 and back to 1280×720.
- [Skirmish layout regression](subtitle-layout-regression.log): both factions on all four core maps, three interface sizes, three subtitle sizes, empty/HQ/tank selections and a real paid production job (216 combinations). Captions stay clear and stable through ordinary selection, react to a live minimap resize without a new speech event, and respect visibility/line-end changes. Selection and queue controls leave the top HUD clear.
- [Existing interface workflow](campaign-scale-interface-shared.log): both factions, all interface sizes, production, minimap and attack-move coordinates, alerts, Lua/visual editors, archives, settings Save/Cancel/defaults, larger windows and First Orders results.
- [Eight shared suites](campaign-scale-shared.json): speech, settings, save slots, campaign controls, programs, signatures, squads and battle-plan guidance. Formatting, lint, editor import and whitespace checks also pass. Existing navigation-bake and shutdown resource warnings remain; deliberate settings-write failures are expected.

The first fixture had a [Vector2/Vector2i parse error](campaign-scale-fixture-parse.log), excluded from passing evidence. The [first rendered run](campaign-scale-render-initial.log) failed two exact floating-point texture-size comparisons; its saved images were already 1280×720. Final checks compare the actual image's integer pixel dimensions.

## Captures

Reviewed: [Supply 100%](../../../art/skirmish/campaign-scale-supply_line-100-720p.png), [125%](../../../art/skirmish/campaign-scale-supply_line-125-720p.png), [150%](../../../art/skirmish/campaign-scale-supply_line-150-720p.png); [Horizon](../../../art/skirmish/campaign-scale-command_horizon-150-720p.png), [focused bottom action](../../../art/skirmish/campaign-scale-horizon-focused-150-720p.png), [Foundry](../../../art/skirmish/campaign-scale-broken_foundry-150-720p.png), [Air](../../../art/skirmish/campaign-scale-air_corridor-150-720p.png), [Orders](../../../art/skirmish/campaign-scale-first_orders-150-720p.png), [Signal](../../../art/skirmish/campaign-scale-split_signal-150-720p.png), [900p](../../../art/skirmish/campaign-scale-supply-150-900p.png) and [1080p](../../../art/skirmish/campaign-scale-supply-150-1080p.png).

Fog remains active in these layout fixtures; objective navigation often places the camera over unrevealed terrain. These captures verify the HUD, not environment-art acceptance.

## Reproduction and limits

```sh
godot --path . --script tests/rendered/CampaignScalePreview.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SubtitleLayoutRegression.gd
godot --path . --script tests/rendered/InterfaceScalePreview.gd
```

Input is injected through Godot's window-coordinate path. Physical-device/platform acceptance, extreme aspect ratios, 4K/OS scaling, screen readers, localization and novice usability remain open. This UI work does not settle pacing, strategy, content, final mixing or release performance; performance optimization remains deferred.
