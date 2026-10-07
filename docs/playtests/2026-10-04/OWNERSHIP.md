# Ownership readability — 2026-10-04

The battlefield and minimap previously distinguished forces through player color. Two sides using the same faction and color therefore had no independent ownership cue. The [original regression](ownership-before.log) fails for both Bastion and Helix.

Controlled units now have a small circle symbol; opponents have a triangle. Hovering a currently observed unit displays ownership and faction text, including during tactical pause. The label chooses available space beside the unit and stays behind controls. Minimap markers use the same shapes, while resources remain diamonds. Hovering the minimap shows a text legend. Neutral civilian scenery has no military symbol.

Settings → Display → **Show unit ownership symbols** previews the world overlay, persists through Save, and rolls back through Cancel. Minimap shapes remain enabled. The overlay ignores mouse hit testing and never changes selection, commands or simulation state. It derives ownership from the actual player; matching faction and color do not affect the shape.

## Rendered evidence

The actual normal-clock renderer uses identical player colors and factions on both sides. No recoloring of screenshots is needed to distinguish the two armies.

- [Bastion ownership label at 720p/150%](../../../art/skirmish/ownership-bastion-opponent-hover.png).
- [Helix at 720p/100%](../../../art/skirmish/ownership-helix-scale-100.png), [125%](../../../art/skirmish/ownership-helix-scale-125.png) and [900p/150%](../../../art/skirmish/ownership-helix-900p.png).
- [Keyboard setting preview](../../../art/skirmish/ownership-bastion-settings.png), [restored symbols after Cancel](../../../art/skirmish/ownership-bastion-restored.png).
- Shared campaign layouts: [First Orders](../../../art/skirmish/ownership-shared-interface-campaign-battle-150-720p.png) and [Horizon command scrolling](../../../art/skirmish/ownership-shared-campaign-scale-horizon-focused-150-720p.png).

The [dedicated rendered workflow](ownership-preview-reviewed.log) passes real world selection and movement orders, actual pointer hover, keyboard setting preview, mouse Cancel, paused-clock invariance and both-faction disk restoration. The first rendered fixture paused the tree directly instead of entering tactical pause and spawned units before a fog update; this correctly failed the input checks. The corrected fixture uses the ordinary pause control after live simulation. Paused hover uses a current ray query because ordinary physics mouse-enter signals do not update during pause. Closing settings also clears stale unit hover. A later screenshot exposed a nameplate behind the command panel; the final layout test and image verify its corrected placement.

## Verification

| Area | Evidence |
| --- | --- |
| Identical colors/models | Both Bastion and Helix mirror matches show own circles and opponent triangles in world and minimap, with distinct ownership captions. |
| Current information | Lost sight removes both indicators immediately despite a stale visible flag. Per-player, all-player and full visibility are checked. Hidden HQs and remembered structure geometry receive no live marker. |
| Entity lifecycle | Aircraft and owned structures get correct markers; resources retain diamonds. Death removes world and minimap indicators. Markers reconstruct from the restored battle without new archive fields. |
| Preferences and authority | Default/invalid preference fallback, actual resource-file persistence, live preview/Cancel, mouse-transparent world selection/Move, tactical pause and saved battle reconstruction pass. |
| Shared runtime | SettingsRegression, MapStartupRegression, DirectOrdersRegression, SelectionRosterRegression, CombatRegression, SaveRestoreCombat, SaveRestoreEdges, CampaignControlsRegression and ArenaRegression pass. |
| Shared rendered UI | InterfaceScalePreview, CampaignScalePreview and the real-input ArenaPreview pass, including all six missions, 100/125/150% layouts, 720p/900p/1080p interface checks, production, map targeting, program editors, archives, settings and result controls. |
| Static/import | Focused formatting/lint, whitespace checks and Godot editor import pass. |

The final dedicated [coverage log](ownership-final.log), [shared runner](ownership-verify.py.txt) and [verification manifest](ownership-verification.json) retain individual checks and source/image hashes. The manifest distinguishes the final checks from initial fixture failures. The first shared runner also requested a nonexistent `BattleArenaRegression.gd`; the retained diagnostic is not accepted. A later lint cleanup exposed a test-only preload/autoload ordering error; the final test loads those dependencies after initialization, and its failed diagnostic is retained separately. The corrected run executes the real `ArenaRegression.gd` and checks missing-script/load messages as failures even if Godot exits zero.

## Scope and limits

No combat values, navigation, orders, save schema or economic rules change. Nameplates can be omitted when no unclipped position exists; the symbol remains. An observer-only legacy match uses “Side N” captions and a “Viewed side” legend, including after switching the viewed player. Multi-opponent legacy matches include a side number in the caption; full multiplayer/allied-team semantics are outside the two-side slice. Indicators remain presentation, not additional scouting.

Known navigation readback and engine shutdown ObjectDB/resource diagnostics remain in raw logs. Final accepted runs have no script/load failures. These are automated and injected-input rendered checks, not new physical-device, screen-reader or novice acceptance. Performance benchmarks remain deferred; broader content, pacing/balance and release acceptance stay open.

```sh
godot --headless --path . --fixed-fps 60 --script tests/headless/OwnershipRegression.gd
godot --path . --script tests/rendered/OwnershipPreview.gd
```

Shared rendered wrappers are retained as [interface wrapper](ownership-OwnershipInterfaceScale.gd.txt) and [campaign wrapper](ownership-OwnershipCampaignScale.gd.txt); they preserve earlier screenshots by using a new capture prefix. Verified on Godot 4.6, macOS M1 Pro.
