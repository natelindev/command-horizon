# Regional environmental audio — 4 October 2026

The four skirmish regions and all six campaign operations now have environmental soundscapes. Neutral traffic, harbor tugs and gulls add local sound when currently observed near the camera. Settings provides a separate **Ambience volume** and a finite Play/Stop sample. Campaign verification also found and repaired Split Signal’s map-loading regression and overlapping relay titles.

## Sound and control

| Region | Sound | Maps and operations |
| --- | --- | --- |
| Desert | Dry wind, rising sand hiss, granular skitter | Desert Frontier, legacy Bastion Desert, Supply Line, First Orders |
| Alpine | Valley gusts, conifer rustle, restrained ridge whistle | Alpine Relay, Split Signal |
| Industrial | Ventilation, fan bearings, distant mechanical rhythm | Industrial Crossroads, Air Corridor, Broken Foundry, Command Horizon |
| Coastal | Staggered surf, receding foam, sea wind | Coastal Foundry |

The [generator](../../../art/audio/build_environment_audio.py) produces four stereo beds and three mono neutral-source loops at 32 kHz, plus a twelve-second settings sample. All audio is original mathematical synthesis; no external recordings or samples are used. The [asset manifest](../../../art/audio/environment-manifest.json) records seeds, descriptions, duration, peak/RMS, loop joins and hashes. A second generation produces [identical bytes for all eight WAVs](environment-audio-assets-audit.json). Joins stay within ordinary waveform sample-step bounds; no crossfade silence is inserted at a loop boundary.

The [audition reel](../../../art/audio/environment-audition.wav) provides six seconds from each asset, in manifest order, at asset level. The separate [runtime recording](../../../art/audio/environment-runtime.wav) captures actual mixed game output. They are different listening artifacts: the runtime includes gain, spatial attenuation, pause/mute, combat and settings samples.

Each match owns one bed and at most four local players. Only authored neutral actors are queried; military units, hidden production and enemy economic state cannot trigger environment cues. Local sources use current allied observation and camera bounds, stop immediately when observation is lost, and follow screen-relative stereo/distance. Beds describe the disclosed region and are independent of enemy activity. Cosmetic playback uses authored neutral phases, never the simulation RNG.

Beds fade in over 1.5 seconds. Audible speech lowers ambience by 8 dB; recent audible combat lowers it by 4 dB, with gradual release. Muted voice/effects do not retain ducking. Tactical pause, modal settings, restoration and results suspend playback; scene removal frees it. Sound players are transient, while existing neutral actor route/pose archives remain authoritative. A paused load begins silent and fades in after Resume.

Ambience defaults to 55%, independently of Effects and Voice. Master still controls the whole mix. Settings supports live preview, keyboard slider adjustment, Save, Cancel/Escape rollback, defaults and write-error recovery. **Test ambience** changes to **Stop ambience sample** during playback and returns when stopped or finished. The Ambience bus has a −9 dBFS ceiling; the existing Master limiter remains in place. Loop endpoints use the engine’s [sample-index WAV loop API](https://docs.godotengine.org/en/4.5/classes/class_audiostreamwav.html).

## Verification

All [sixteen shared suites](environment-audio-shared.json) pass without script errors: environmental audio, settings, combat audio, speech, key bindings, neutral life, Split Signal, Alpine environment, three archive suites and the remaining five campaign operations. The [final focused check](environment-audio-final-EnvironmentAudioRegression.log) covers both factions/four skirmish maps, six actual campaign scenes, real settings files, legacy/invalid preferences, current fog and camera culling, tactical/modal pause, mute/fade, bounded neutral voices, RNG isolation and actual battle disk restoration.

The [final normal-clock rendered audio run](environment-audio-render-final.log) passes at 1280×720 and 150% interface scale. [Measured output](../../../art/audio/environment-runtime.json) includes all four beds, loop wrap, left/right tug audio, zero-output tactical pause and Ambience/Master mute, actual tank damage, speech/combat ducking and the clicked settings sample. The combined combat/environment sample remains below the Master ceiling. [Settings](../../../art/skirmish/environment-audio-settings-720p.png) and [combat](../../../art/skirmish/environment-audio-combat-720p.png) captures are reviewed. Inputs are injected through Godot’s window event path; physical-device/native computer-use acceptance is not claimed.

## Split Signal regression found during the campaign smoke check

The [initial campaign errors](environment-audio-initial-campaign-errors.log) show that Split Signal could no longer load: its `SHELVES` constant collided with the parent Alpine map’s newly added model-name constant, and its `_pad()` call referenced a removed helper. The parent constant is now named `SHELF_MODELS`; the mission owns its non-colliding relay aprons. Mission ridge/relay/resource coordinates, obstacle envelopes and capture rules are preserved.

Rendered review then exposed [overlapping relay titles](../../../art/skirmish/split-signal-overview-before-label-fix.png): shared 3D labels and mission locators occupied the same place. Split Signal now uses its mission locator for each title and its objective panel for live status. Locators render behind the HUD and hide when clipped. The rendered regression asserts a single visible title owner and safe panel layering. The ordinary shared relay label remains available on other maps. The [final overview](../../../art/skirmish/split-signal-overview-720p.png), [relay locator](../../../art/skirmish/split-signal-relay-720p.png) and [program panel](../../../art/skirmish/split-signal-program-720p.png) are reviewed; the overview deliberately reveals the map for layout inspection. The [final mission regression](environment-audio-final-SplitSignalRegression.log) covers objective rules, routes, optional capture, disk restoration, defeat and a real preset victory.

## Retained failures and limits

Early test setup errors (preloading an autoload-dependent script, requesting a starting drone that is absent, and a formatter-produced chained-lambda parse error) are excluded from passing evidence. The first rendered run’s audio checks passed but its two captures were 1920×1080; [that failure](environment-audio-render-initial.log) is retained. Waiting for the native window transition before setting the size produced the passing 720p run. An initial suite list also referenced nonexistent `HorizonRegression.gd`; its [loader error](environment-audio-verified-HorizonRegression.log) is excluded despite exit code zero. The actual `CommandHorizonRegression.gd` was run separately and passes. The [first campaign UI run](environment-audio-split-render.log), after the map repair and before the label adjustment, passes. Later runs miss different synthetic menu/View/Resume clicks: [Start failure](environment-audio-split-click-failure.log), [operation selection failure](environment-audio-split-selection-failure.log) and [isolated rerun](environment-audio-split-render-isolated.log). A bounded [twenty-click menu trace](environment-audio-campaign-click-probe.log) passes, but a [15 FPS input-timing probe](environment-audio-input-timing-probe.log) still misses one click with render-frame waits. That falsifies timing as a sufficient explanation. The final label-owner/layer assertions and mission logic pass, while repeated campaign mouse-input acceptance remains unresolved. No passing full final campaign-input run is claimed. All outcomes remain retained; neither a general physical-input defect nor its cause is established. Intentional unwritable-settings scenarios emit expected engine errors. Existing navigation-bake and shutdown resource warnings remain.

The [21-file source/WAV manifest](environment-audio-source-sha256.json), [format check](environment-audio-format.log), [lint](environment-audio-lint.log) and [editor import](environment-audio-editor-final.log) identify and check the delivery.

Subjective speaker/headphone listening, final regional mixing, additional environmental event variety, native-platform acceptance, novice pacing and broader content/release gates remain open. This adds playable audio and fixes a reproduced campaign break; it does not establish final audio or campaign balance acceptance. Performance work remains deferred.

```sh
python3 art/audio/build_environment_audio.py
godot --headless --path . --fixed-fps 60 --script tests/headless/EnvironmentAudioRegression.gd
godot --path . --script tests/rendered/EnvironmentAudioPreview.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/SplitSignalRegression.gd
godot --path . --script tests/rendered/SplitSignalPreview.gd
```


## Follow-up: campaign controls

The later [campaign controls investigation](CAMPAIGN_CONTROLS.md) reproduces notice-driven button movement and separately captures native pointer interference during synthetic clicks. The HUD now reserves scrollable notice space, all six 720p campaign layouts clear their real minimaps, and held-click/slow-click/full campaign flow checks pass. This supersedes the open synthetic-input investigation above; it does not claim physical-device/platform acceptance. The audio-stage hashes and logs above remain historical snapshots.
