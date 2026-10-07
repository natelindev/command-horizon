# Speech accessibility and announcement delivery

## Delivered behavior

Settings → General now offers **Show speech subtitles**, **Subtitle size** (Small 18 px, Standard 22 px, Large 26 px), and **Test voice and subtitles**. Subtitles default on. Visibility/size preview immediately, persist with Save, restore with Cancel, and use defaults for old or invalid preferences. The existing atomic-save error path retains the live preview until Retry or Cancel.

A shared human speech channel plays the existing 14 English assets and publishes the same accepted line to a speaker-labelled caption. Command announcements and unit acknowledgements no longer talk over one another. Muting Master or Voice leaves enabled captions visible. No new voice recordings are included. The subsequent [combat audio pass](COMBAT_AUDIO.md) adds original weapon, impact and destruction effects on a separate bus.

The caption card occupies the bottom-center gap between the minimap and the 510 px unit/production panel. All its controls ignore mouse input; right-click orders still reach the battlefield. Standard/large text, wrapping, the initial frame layout and viewport changes are handled without decorative selection borders.

| Speech category | Delivery rule |
| --- | --- |
| Victory / defeat / legacy abort | Highest priority; clears pending lines and latches against later chatter. Playable skirmish/campaign result panels now request victory/defeat explicitly. |
| Base under attack | Interrupts lower-priority speech; ten-second cooldown independent of unit warnings. |
| Unit lost / unit under attack | Interrupts routine speech; repeated losses coalesce for six seconds, repeated incoming-fire warnings for ten. |
| Resource failure / completed unit or structure | Bounded priority queue; repeated pending events coalesce. |
| Selection / order acknowledgement / training | Plays when the channel is free; rejected while busy so responses cannot arrive after the relevant action. |

Cooldowns begin when a line actually starts, not on every damage event. A four-entry pending queue discards events older than six seconds. Audio and caption/read lifetime use presentation time, allowing paused orders to be acknowledged without advancing simulation. Settings/archive scene freezing suspends both together. Draw clears speech because there is no recorded draw line.

Only actual weapon-hit notifications generate incoming-fire warnings. Generic HP decreases, foundation initialization and save reconstruction do not. Human ownership is checked before publication; captions do not disclose enemy production, casualties or unseen attacker identities. Transient speech is excluded from battle archives, and reconstruction events are suppressed.

## Corrections found during verification

- The previous damage handler refreshed its timestamp on every hit, starving warnings under sustained fire. It also initially suppressed warnings during the first ten seconds of app uptime. Accepted-playback cooldowns fix both and keep base/unit warning timers separate.
- Construction sets foundation HP, which previously looked like an attack. A weapon-hit signal distinguishes that event without changing damage calculations or the existing generic HP notification.
- Loss signals arrive after tree exit; the parent ownership link is gone. The retained controlled-unit group identifies human losses correctly, and six simultaneous losses produce one line.
- The first caption measured its wrapped height before the container settled and grew beyond the viewport. Fitting again on minimum-size changes fixes the opening line as well as later lines.
- The shared combat suite exposed a fixture displaced by navigation from `(40,0,48)` to `(39.68,0,45.48)`, leaving its intended sightline unobstructed. The fixture now pins the blocker after asynchronous alignment and asserts the geometry before retaining the same foundation/completed/foundation observation checks. No combat rule or visibility assertion was weakened.

## Verification

| Check | Evidence |
| --- | --- |
| SpeechRegression, both factions | All 14 text/asset mappings, legacy/invalid settings, isolated actual preference file, first/sustained/base weapon damage, false-foundation exclusion, six deaths, enemy ownership, selection/orders while paused, repeat suppression, queue priority/expiry and all accepted captions pass. |
| Actual production | A paid HQ worker job reserves materials, emits Training, produces a real worker and emits Unit ready. |
| Settings and mute | Both audio buses can be muted with a visible caption. Live size/visibility, scene freeze, deliberate unwritable-path recovery and Cancel rollback pass. |
| Disk restoration | A battle with damaged units is written/read/restored; no startup, HP, production or selection reconstruction speech leaks immediately or after Resume. |
| Results | Playable result presentation preempts an active warning, clears pending speech and rejects later losses/production. Defeat and silent draw are checked separately. |
| SpeechPreview, normal-clock Metal | Rendered mouse/key events exercise subtitle settings, Small/Large keyboard selection, sample playback, Save/Cancel, caption lifetime, muted audio position while tactically paused, archive audio/caption freeze and real right-click pass-through. |
| Layout | Largest captions fit with actual production queues, two-unit program controls, First Orders' lesson panel and its result overlay at 1280×720; a 1440×900 resize also fits. Opening and later captions were visually inspected. |
| Shared regressions | General settings, remapped controls, combat, save slots/checkpoints/recovery, legacy Bastion and all four skirmish faction pairings including AI economy/attacks pass. |

Speech timing policy checks use controlled presentation deltas; the rendered run separately verifies normal-clock audio advancement, freeze and expiry. Campaign/result screenshots use a presentation fixture, not evidence of campaign victory pacing. New test saves/options are isolated and removed; prior preferences are restored. Preview autosaves are disabled and its archive points to an isolated directory. Two checkpoints created by the initial preview were identified as newly created test files and removed; the pre-existing checkpoint was retained.

Reproduce from the repository root with Godot 4.6:

```sh
godot --headless --fixed-fps 60 --path . --script tests/headless/SpeechRegression.gd
godot --path . --script tests/rendered/SpeechPreview.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/SettingsRegression.gd
godot --path . --script tests/rendered/SettingsPreview.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/KeyBindingsRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/CombatRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/SaveSlotsRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/BastionDemo.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/Skirmish.gd
```

Screenshots: [settings/sample](../../../art/skirmish/speech-settings-720p.png), [opening line](../../../art/skirmish/speech-opening-bastion.png), [production](../../../art/skirmish/speech-production-bastion.png), [Helix group](../../../art/skirmish/speech-group-helix.png), [campaign](../../../art/skirmish/speech-campaign-720p.png), [result](../../../art/skirmish/speech-result-720p.png), [900p](../../../art/skirmish/speech-wide-900p.png).

## Remaining acceptance

Direct operating-system keyboard/mouse acceptance remains unverified after the prior computer-use connection failures; rendered tests inject events through the real Godot controls. Windows/Linux, localization, final voice performance/mixing, general HUD scaling, richer sound design and navigable squad/field alert history remain open. Existing navigation-readback and exit-time ObjectDB/resource/renderer warnings remain. The deliberately unwritable settings path emits the expected engine save error. Performance optimization stays deferred, as do broader full-match/novice/release gates.
