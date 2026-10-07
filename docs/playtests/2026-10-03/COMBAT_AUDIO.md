# Combat audio delivery

## Delivered behavior

Attacks, accepted impacts and destruction now have audible cues. Eleven original mono WAV assets are synthesized from deterministic noise, pressure envelopes, resonances and debris events; no third-party recordings or voices are used. The [generator/provenance and labelled audition timings](../../../art/audio/README.md), [manifest](../../../art/audio/combat-manifest.json), [isolated audition reel](../../../art/audio/combat-audition.wav), and [rendered runtime capture](../../../art/audio/combat-runtime.wav) are retained.

| Source | Cue |
| --- | --- |
| Bastion infantry | Dry rifle report |
| Bastion basic tank / ground turret | Cannon concussion |
| Bastion walker | Autocannon report |
| Helix infantry | Energy discharge |
| Helix basic tank / ground turret | Lower-pitched energy discharge |
| Advanced tank; Helix Lancer Precision | Rail crack |
| Helix Lancer Interception | Energy discharge |
| Helicopter / anti-air turret | Missile ignition/exhaust |
| Hits | Light or heavy material impact by weapon family |
| Infantry destruction | Equipment/ground fall |
| Other mobile destruction | Chassis explosion/debris |
| Structure destruction | Longer collapse/fracture |

Actual combat effects call the audio channel before the visual/headless early return. This does not alter targeting, damage, armor or projectile timing. Audio uses current allied observation rather than a render-visible flag; remembered structures do not reveal new combat. Sources behind the camera or beyond a 96 px viewport margin are suppressed. A living source that becomes unobserved has its active cue stopped. Legitimate destruction tails can outlive the removed unit.

Screen-projected positions drive stereo direction and attenuation. Identical sounds in one six-metre area merge over 80 ms (40 ms for destruction). A 24-player pool prioritizes destruction over shots over impacts; higher-priority cues replace the oldest lowest-priority entry. Deterministic local pitch variation does not consume simulation randomness. Audible speech ducks effects by 4 dB; muted Voice does not duck the mix. Effects and Master limiters have -4/-1 dBFS ceilings.

Settings → General adds **Effects volume** (default 75%) and **Test combat sound**. The setting participates in live preview, Save, Cancel, legacy defaults and invalid-value handling. Master/Effects mute clears active combat sounds and prevents new ones. Tactical pause suspends playback; settings/archive scene freezing suspends it too. The independent settings sample remains usable. Ended battles reject new cues while allowing existing destruction tails to finish. Restoration suppresses new events; sounds and their transient queue/pool are not archived.

## Verification

| Check | Evidence |
| --- | --- |
| CombatAudioRegression, both factions | Real tank projectiles reduce target HP and emit faction shot/heavy impact cues. Real weapon kills emit separate infantry, vehicle and structure cues. |
| Observation | Hidden on-screen enemy shots/deaths remain silent even with a forced visible render flag; offscreen friendly shots remain silent. Rendered current-observation loss stops an already playing enemy cue. |
| Lifecycle | Repeat merging, tactical pause, Effects zero/mute, Settings sample and Cancel, ended-battle rejection, 24-player saturation and destruction priority pass. |
| Actual archive | A damaged battle with active audio is captured to an isolated file and restored. No active sound or deferred reconstruction cue returns before or after Resume. |
| Preferences/assets | All eleven resources load with nonzero duration; independent Effects gain, actual file persistence, legacy/malformed/nonfinite fallback and nonduplicating limiters pass. Asset manifest covers PCM format, peaks, RMS, DC, zero boundaries and deterministic hashes. |
| CombatAudioPreview, normal-clock Metal | Both factions produce nonzero measured bus output during actual combat. Left/right energy ratios are 1.83 in the expected direction. Actual playback positions freeze/resume during tactical pause and Settings; Settings sample is audible while battle audio stays frozen. |
| Overlap/mix | A rendered burst fills all 24 slots with structure-destruction cues while a warning plays. Effects peak is 0.630961 (-4 dBFS); Master capture peak is 0.771323 (-2.26 dBFS). No capture frames were discarded. Muted speech does not lower Effects gain. |
| SpeechPreview | Real Godot mouse input activates Test combat sound and voice/subtitle samples. Keyboard Small/Large selection, Save/Cancel, mute/pause, caption pass-through, campaign/results and 720p/900p layout pass. Updated screenshots were inspected. |
| Shared checks | SpeechRegression, SettingsRegression, KeyBindingsRegression and CombatRegression all pass after audio integration. Format/lint and whitespace checks pass. |

The runtime WAV is a 10.25-second stereo 44.1 kHz PCM16 recording of the measured Master bus sections, in order: Bastion actual combat, left cannon, right cannon, Settings sample, saturated destruction plus voice, Helix actual combat. Silent waits between sections are omitted. The [measurement JSON](../../../art/audio/combat-runtime.json) retains section sample counts, peaks and left/right squared energy. Captures use Godot's non-mutating [AudioEffectCapture](https://docs.godotengine.org/en/stable/classes/class_audioeffectcapture.html). Bus capture precedes the final bus fader; the saturation measurement uses Master at 100%, while ordinary sections use the default 80% Master and 75% Effects settings.

Reproduce with Godot 4.6 from the repository root:

```sh
godot --headless --fixed-fps 60 --path . --script tests/headless/CombatAudioRegression.gd
godot --path . --script tests/rendered/CombatAudioPreview.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/SpeechRegression.gd
godot --path . --script tests/rendered/SpeechPreview.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/SettingsRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/KeyBindingsRegression.gd
godot --headless --fixed-fps 60 --path . --script tests/headless/CombatRegression.gd
```

## Remaining acceptance

Subjective speaker/headphone listening, long-battle fatigue and final mix tuning remain unverified; no audio listening tool was available. Nonzero output, peak limits and directional energy measurements establish signal delivery, not subjective sound quality. Environmental ambience and new voice performances remain future audio work. Native OS input acceptance remains pending after the earlier bounded computer-use failure; the rendered tests inject events into real Godot controls. Windows/Linux and broader release/full-match balance acceptance remain open. Performance optimization is deferred.

Existing navigation GPU-readback and exit-time ObjectDB/resource warnings persist. The intentionally unwritable settings file produces the expected engine error. No new script errors or regression failures appeared. Test options/archives use isolated paths and prior preferences are restored; rendered autosaves are disabled.
