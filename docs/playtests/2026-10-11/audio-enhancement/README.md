# Faction and unit audio

The current bank has 711 clips: 293 spoken recordings and 418 mechanical cues.
Three male Kokoro announcers speak only command announcements. Each of the 31
speaking faction/unit roles has a unique male Piper/VCTK speaker ID, without
announcer blending or speaker reuse between roles/factions. Original dialogue
and captions retain each unit's identity across selection, orders and readiness.

Autonomous units have 11 faction/role identities and 121 distinct cues. Workers
use piston motors/ratchets, repair robots use servos/tools, combat robots use
heavy gears/latches, and drones use rotors/telemetry. Each has two selection,
movement and attack variants plus separate task/ready/stop cues. Faction tuning
adds engineering character. Buildings retain their existing console cues.

## Listen

- [Faction audition reel](faction-voice-audition.ogg): Bastion, Helix, then Frontier; every speaking unit and autonomous role is included;
  [cue sheet](audition-cues.json) identifies each line and its timestamp.
- Live game mixes: [Bastion](bastion-live-mix.wav), [Helix](helix-live-mix.wav),
  [Frontier](frontier-live-mix.wav). Each uses default audio volumes and includes a real HUD click, selection,
  accepted attack-move, each autonomous unit selection, actual incoming damage and completed paid research.
- Caption examples: [Bastion unit](bastion-unit-caption.png),
  [Helix announcer](helix-announcer-caption.png),
  [Frontier unit](frontier-unit-caption.png).

The recordings are synthesized performances, not human voice acting. Decode,
levels, routing and event behavior were verified; subjective acting quality still
benefits from a listening review. Voice attribution and modifications are recorded
in [LICENSES.md](../../../../assets/audio/voices/LICENSES.md).

## Casting and mixing

All speakers have documented male source voices. The three announcers remain
Michael, George and Fenrir; unit speakers are listed explicitly in
`art/audio/voice_cast.py` with gender/accent provenance in `vctk-speakers.json`.
Distinct profile names, blend weights or delivery rates no longer count as
speaker diversity. The builder rejects borrowed announcers and reused unit IDs.
Generic unit reply assets were removed from Command, and `say` rejects unit
reply events without a source; normal unit replies use `say_unit`.

Speech has light EQ and is mastered at -18 LUFS / -3 dBTP without narrow radio
filters. Native synthesis is 24 kHz for command and 22.05 kHz for units; all spoken
Oggs use 24 kHz encoding. Autonomous cues preserve low gears and high telemetry
through a broad 50–7000 Hz passband. Their Effects volume routing is unchanged.

The previous ambience reduction remains intact: beds are 10.3–13.2 dB quieter,
with noise above 2 kHz reduced 22.9–31.5 dB. See
[before/after measurements](ambience-comparison.json). Settings previews share
gameplay's -16 dB bed gain. No persisted volume preference was changed.

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

## Verification — dedicated unit cast and machine revision

Godot 4.6 on macOS; headless suites use `--fixed-fps 60`.

| Check | Result |
| --- | --- |
| Cast/cache/machine Python regressions | 4 passed: announcer borrowing rejected, rate-only duplicate rejected, cache isolation, distinct machine bodies |
| verify_voice_cast.py | 31 separate male unit speakers, three exclusive male announcers; 11 mechanical identities and 121 distinct clips |
| verify_battle_audio.py | All 711 clips decode and match hashes; highest decoded peak -2.63 dBFS |
| verify_clean_mix.py | All 293 spoken clips encoded at 24 kHz; all four quiet, low-hiss beds pass |
| Repeat build | All 711 existing clip hashes preserved on the second build |
| AudioEnhancementRegression | 0 failures across all three factions, every unit/event identity, captions, source requirements, scheduling and lifecycle |
| SpeechRegression | 0 failures for real orders/production, damage, subtitles, mute/pause, save restoration and terminal events |
| Godot import | Passed |
| AudioEnhancementPreview | 0 failures at 720p; real UI/selection/order/damage/research plus every autonomous role; clean shutdown |
| Live mix audit | All three default-volume mixes contain audio without clipping; see live-mix-verification.json |
| gdformat / gdlint / git diff --check | Passed for changed scripts and patch |

The complete audition reel includes every speaking unit and two selection
variants plus an attack cue for each autonomous role. Decode and routing checks
do not assess subjective performance quality; the reel supports listening review.

The inherited headless fixtures report retained resources at shutdown (38 in the
expanded audio suite, 10 in the speech suite). SpeechRegression also intentionally
logs a failed-save error while checking recovery. No runtime script errors remain
in the audio suite. Mission transports use their authored scene geometry in the
voice fixture: Helix/Frontier skirmish model catalogs have no transport model slots.

Earlier audio/mix work also passed combat/environment, settings, direct-order,
subtitle and research-feedback checks listed in the plan. Those unrelated suites
are not claimed as rerun for this casting change. The prior research-economy
baseline comparison remains in [research-baseline-comparison.json](research-baseline-comparison.json).

Build dependencies are pinned in `art/audio/voice-requirements.txt`; ffmpeg is
also required. See [build commands](../../../../art/audio/README.md). Neither TTS
engine nor model ships with the game. Attribution and the voice catalog are
included by each export preset.
