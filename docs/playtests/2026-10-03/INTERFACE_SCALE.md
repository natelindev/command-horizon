# Interface scaling — 2026-10-03

Settings → General → Display → **Interface size** now offers **100%, 125%, and 150%**. The choice previews immediately across menus, the battle HUD, text, subtitles, archives and program editors. Save persists it; Cancel/Esc restores the previous size; Reset defaults previews 100%. Missing, malformed, nonfinite or unsupported values fall back to 100%.

The existing 1920×1080 design canvas remains the baseline. At 16:9, the three choices provide 1920×1080, 1536×864 and 1280×720 logical layouts. The largest setting therefore uses the already supported 720p layout. Subtitle text size still provides an additional independent adjustment.

## Rendering and input

`Globals` applies the preference through the root window's `content_scale_factor`. Canvas Items rendering preserves output resolution while Godot transforms pointer coordinates into the scaled layout. Expand aspect handling uses additional space on wider/taller displays; a 1440×900 window now renders all 1440×900 pixels without 16:9 letterboxing. The separate program arena uses the same canvas and preference, and explicitly requests windowed mode so a pending main-window fullscreen setting cannot reassert itself.

This follows Godot's [UI scaling guidance](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) and [Window scale-factor contract](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-property-content-scale-factor). No camera speed, simulation time or command semantics are changed by the preference.

## Bugs found during verification

- The arena creates test players without `BattleVoice`. Match startup previously created a subtitle layer with a null voice and emitted missing-node/script errors, although the arena's old assertions still reported success. Startup now attaches subtitles only when a voice controller exists. Headless and rendered arena regressions assert that voiceless test matches have no subtitle layer; normal battle speech is checked separately.
- First Orders drew its world-space relay label above selection controls and allowed a partially clipped label at the window edge. The marker now renders behind the HUD and only appears when its full label fits. The rendered check verifies the layer order, edge handling and the **View relay** navigation path.
- The initial display-size fixture captured a 900p-labelled image after an asynchronous fullscreen rollback returned the window to 720p. The fixture now waits for the display transition and asserts both the requested window dimensions and captured pixel dimensions. The final 900p/1080p evidence uses the correct sizes.

## Verification

`InterfaceScalePreview.gd` uses the normal clock and Metal renderer. For both factions and all three interface sizes it checks worker/HQ/factory/tank/lab panels, five real paid production jobs, camera projection, minimap navigation, attack-move destinations, alert history, subtitles, Lua/visual editor controls and archive actions. Mouse events enter in window coordinates, allowing Godot to perform the stretch transform. Keyboard input selects the actual scale dropdown. Save, defaults and Cancel preserve the paused clock and restore the expected preference. Main menu, skirmish setup, campaign selection, First Orders lesson/result and 900p/1080p layouts are also exercised.

Shared checks cover settings persistence/invalid values/write failures, remapped input, archive restoration, battle speech, seven arena scenarios for both factions, all-role manual takeover, and rejected wrong/faulting programs. The arena rendered flow runs, pauses, resumes and restarts a real scenario at 150% in a 1280×720 window, including recovery from a pending fullscreen request.

Reproduction commands (Godot 4.6):

```sh
godot --path . --script tests/rendered/InterfaceScalePreview.gd
godot --path . --script tests/rendered/ArenaPreview.gd
godot --headless --path . --script tests/headless/SettingsRegression.gd
godot --headless --path . --script tests/headless/KeyBindingsRegression.gd
godot --headless --path . --script tests/headless/SaveSlotsRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/ArenaRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/SpeechRegression.gd
```

The fixtures use isolated preference/archive paths and disable autosaves; they do not replace the player's saved preferences. Known navigation readback and shutdown resource warnings remain. The settings failure test intentionally emits an error for an unwritable path; one rendered run also logged a macOS input-method warning.

All listed checks completed successfully. The final interface suite reports zero failures; the final arena run has no missing-voice/script errors. Formatting, lint and whitespace checks pass.

## Reviewed captures

- [100% battle](../../../art/skirmish/interface-battle-bastion-100-720p.png), [125% battle](../../../art/skirmish/interface-battle-bastion-125-720p.png), [150% battle](../../../art/skirmish/interface-battle-bastion-150-720p.png).
- [150% settings](../../../art/skirmish/interface-settings-150-720p.png), [paid Helix queue](../../../art/skirmish/interface-production-helix-150-720p.png), [visual editor](../../../art/skirmish/interface-editor-bastion-150-720p.png).
- [Skirmish setup](../../../art/skirmish/interface-play-150-720p.png), [campaign lesson](../../../art/skirmish/interface-campaign-battle-150-720p.png), [relay navigation](../../../art/skirmish/interface-relay-150-720p.png), [arena](../../../art/skirmish/arena-paused-720p.png).
- [1440×900 settings](../../../art/skirmish/interface-settings-150-900p.png), [1920×1080 battle](../../../art/skirmish/interface-battle-150-1080p.png).

## Limits

These are automated rendered input and layout checks on macOS, not a new direct physical-device test or Windows/Linux acceptance. Very small windows, extreme aspect ratios, 4K/OS scaling, screen readers, localization and novice accessibility acceptance remain open. This work does not establish full-match balance or release performance. Performance optimization remains deferred.
