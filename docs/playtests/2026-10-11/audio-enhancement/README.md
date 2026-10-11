# Faction and unit audio

All three factions now have distinct announcers and unit audio identities. The
bank contains 720 clips, including 302 spoken clips using 34 distinct male-only style
profiles derived from seven Kokoro base voices. Human crews,
infantry and heroes use original role-specific dialogue; autonomous machines use
nonverbal motors, servos and telemetry. Building selection also has mechanical
feedback. Speech is English, with matching speaker-labelled captions.

## Listen

- [Faction audition reel](faction-voice-audition.ogg): Bastion, Helix, then Frontier;
  [cue sheet](audition-cues.json) identifies each line and its timestamp.
- Live game mixes: [Bastion](bastion-live-mix.wav), [Helix](helix-live-mix.wav),
  [Frontier](frontier-live-mix.wav). Each uses default audio volumes and includes a real HUD click, selection,
  accepted attack-move, actual incoming damage and completed paid research.
- Caption examples: [Bastion unit](bastion-unit-caption.png),
  [Helix announcer](helix-announcer-caption.png),
  [Frontier unit](frontier-unit-caption.png).

The recordings are synthesized performances, not human voice acting. Decode,
levels, routing and event behavior were verified; subjective acting quality still
benefits from a listening review. Voice attribution and modifications are recorded
in [LICENSES.md](../../../../assets/audio/voices/LICENSES.md).

## Male voice and clean mix revision

Replaced the previous voice bank with explicit male Kokoro styles and full-band
24 kHz speech. Removed the narrow radio filters, added light low-mid equalization,
and mastered speech at -18 LUFS / -3 dBTP. The settings sample and generic fallback
responses use the new bank. Individual role blends are recorded in the cast file.

The four ambience beds now measure 10.3–13.2 dB quieter at their game-player output,
with noise above 2 kHz reduced 22.9–31.5 dB. See
[before/after measurements](ambience-comparison.json). Local ambient actors are
also quieter. Speech/combat ducking and user volume preferences are preserved.
The settings ambience preview shares gameplay's -16 dB bed gain.

## Behavior

- Selection, move, attack, stop, gathering, construction and repair orders receive
  appropriate role responses. Only accepted manual orders speak; automatic rally
  movement and rejected full queues do not. Manually setting a rally point has a
  building response.
- Completed production uses the produced unit's ready line or machine startup cue.
  Construction, research (including Coordination), power changes, insufficient
  resources, incoming fire, losses and match outcomes use the faction announcer.
- One battle channel prevents overlapping voices. Chatter has a shared 1.5-second
  cooldown and never enters the queue. Batch production and identical events
  coalesce. The queue holds at most four notifications, expiring after six seconds;
  dead units cannot play an old ready line.
- Base warnings preempt lesser reports. Attack events have ten-second cooldowns,
  losses six seconds, and lesser danger reports share a four-second budget.
  Power transitions have fifteen-second per-event cooldowns; opposite queued power
  states replace each other. Final results clear the queue and latch it closed.
- Native buttons, toggles, tabs, lists, menus and sliders have short UI cues through
  one player with a 75 ms global debounce. Hover and programmatic value refreshes
  are silent. Keyboard activation works too.
- Voice volume controls speech; Effects volume controls machine and UI sounds.
  Tactical pause permits feedback, settings freeze the battle audio, and save
  reconstruction produces no historical notifications. Existing combat effects,
  ambient sound and their limits remain active.

## Verification

The male/mix revision reran all checks below except DirectOrdersRegression, which
passed during the original integration; order routing is unchanged by this revision.
[Live mix measurements](live-mix-verification.json) record the new default-volume
peaks and duration for each faction.

Godot 4.6 on macOS, headless tests with `--fixed-fps 60`:

| Check | Result |
| --- | --- |
| AudioEnhancementRegression | Passed for all three factions; every clip, role, event, burst, queue, power state, ownership and UI case |
| SettingsRegression | Passed; male preview path, matching ambience gain, persisted controls and lifecycle |
| verify_clean_mix.py | Passed; 34 distinct male-only profiles, all 302 speech clips at 24 kHz, four low-hiss beds |
| SpeechRegression | Passed; paid production, damage, subtitles, pause, mute, restore and terminal behavior |
| CombatAudioRegression | Passed; actual shots, impacts, destruction, visibility and bounded effects |
| EnvironmentAudioRegression | Passed; regional audio, volume, lifecycle and restoration |
| DirectOrdersRegression | Passed; actual move/attack-move behavior |
| SubtitleLayoutRegression | Passed; 720p and regional layouts |
| ResearchFeedbackRegression | Passed for all three factions, including real research completion |
| EnvironmentAudioPreview | Passed; four regions, loop seams, mute/pause, spatial output, ducking and real settings sample/Save/Cancel, with music muted to isolate ambience |
| AudioEnhancementPreview | Passed with rendered 720p UI, actual pointer clicks and default-volume live audio capture |
| gdformat / gdlint / git diff --check | Formatter and patch pass; targeted lint passes except two pre-existing SettingsDialog ArtTheme duplicated-load findings, reproduced on HEAD |
| Asset audit | All 720 Ogg clips decode and match their recorded hashes; highest decoded peak -2.65 dBFS |
| Live mix audit | All three mixes contain audio without clipping; default-volume peaks between -6.41 and -6.22 dBFS |

`ResearchEconomyRegression` reports 15 failures in its AI budget/production
contracts. An isolated pre-audio copy preserving existing workspace changes
reproduces the **same 15 failures**; see
[baseline comparison](research-baseline-comparison.json). The audio work does not
change those policies. Some inherited headless fixtures also emit shutdown
ObjectDB/resource leak diagnostics; the battle audio preview exits cleanly, while
the inherited environment preview fixture reports two retained resources at exit.
Intentional failed-save checks in existing regressions log the expected save error.

Build and asset audit:

```sh
python art/audio/build_battle_audio.py --model tmp/kokoro/kokoro-v1.0.onnx --voices tmp/kokoro/voices-v1.0.bin
python art/audio/verify_battle_audio.py
python art/audio/verify_clean_mix.py
godot --headless --path . --fixed-fps 60 --script tests/headless/AudioEnhancementRegression.gd
godot --path . --script tests/rendered/AudioEnhancementPreview.gd
```

Build dependencies are kokoro-onnx, soundfile, NumPy and ffmpeg. They are not runtime dependencies.
The voice catalog and attribution files are included in each export preset.
