# Audio enhancement

## Stage 1 — Assets and identities

Cover all three factions and every playable unit role with character-specific
selection, movement, attack and production responses. Use distinct synthetic
speakers for crews and infantry, designed nonverbal sounds for autonomous machines,
and short building/UI cues. Keep source text, voice casting and asset provenance.

## Stage 2 — Runtime integration

Extend the existing single-channel battle voice scheduler with bounded queues,
category cooldowns, duplicate suppression, expiry and urgent-alert precedence.
Connect research completion (including Coordination), production, construction,
selection/orders and native UI controls. Preserve volume controls, captions,
ownership filtering, save restoration and scene lifecycle behavior.

## Stage 3 — Verification

Import and decode all assets. Exercise real event paths and mixed-unit bursts,
urgent interruption, expired messages, mute/pause/restore, menu controls and
teardown. Run relevant existing audio, research and subtitle regressions.

## Stage 4 — Male casting and a cleaner mix

User listening feedback: replace female-sounding, muddy speech with clear male
voices, and reduce the continuous white environmental noise. Compare explicitly
male Kokoro voices, regenerate spoken assets with full-band mastering, update
settings previews/legacy fallbacks and credits, and preserve mechanical identities
and the event scheduler. Reduce ambient hiss at its source and in the runtime mix.
Recheck speech, ambience, decoded levels and actual default-volume game playback.

## Stage 5 — Separate speakers for command and units

Replace announcer-derived unit blends with 31 dedicated male VCTK speakers,
one per speaking faction/role. Keep the three Kokoro announcers exclusive to
announcements. Give autonomous units separate piston/ratchet, servo/tool, heavy
gear/latch and rotor/telemetry designs, with faction tuning and event variations. Remove generic unit
replies from the announcer bank and reject unit events without a unit source.
Record speaker provenance, rebuild offline assets, and verify speaker separation,
every role/event, subtitles, scheduling and rendered gameplay audio.

## Agent progress

- Inspected existing combat audio, narrator queue, unit replies and research paths.
- Workspace contains pre-existing gameplay and environment changes; preserve them.
- Completed 720 battle clips: 34 distinct male style profiles, three faction
  announcers, unit-role dialogue, and faction/role-specific mechanical cues.
- Integrated accepted orders, rally/stop, production, construction, research,
  power transitions and global native-control audio. Assets play fully offline.
- Speech, combat, environment, direct-order, subtitle-layout and new three-faction
  audio regressions pass. Rendered real-click/mix verification passes at 720p.
- Every battle asset decodes; highest decoded peak is -2.65 dBFS. Listening reel,
  live mixes and captions are saved with the verification report.
- Research feedback passes for all three factions. The broader AI research-economy
  suite has 15 identical failures before and after this change; isolated baseline
  comparison is recorded in the verification report.
- Final changed-script lint/format, clean patch and Godot import checks pass.
  Initial implementation verified; subjective voice-performance review is supported
  by the audition reel and three captured game mixes.

- Male revision: regenerated all 302 spoken clips using seven explicit male Kokoro
  styles in 34 role profiles, including all faction announcers, settings preview
  and legacy responses. Full-band 24 kHz speech replaces narrow radio filtering.
- Reduced ambience bed gain by 10 dB and rebuilt four regional beds with less hiss.
  Measured bed RMS fell 10.3–13.2 dB; energy above 2 kHz fell 22.9–31.5 dB.
  Settings use gameplay gain; local ambient sources are also quieter.
- All 720 clips decode and match hashes. Male-cast, full-band speech and low-hiss
  asset regressions pass. Seven headless suites and both rendered previews pass.
- Re-recorded all three faction mixes at default audio volumes; peaks remain below
  -6.2 dBFS. Rendered ambience checks confirm looping, pause/mute, spatial playback,
  speech/combat ducking and the real settings sample/Save/Cancel flow.
- Stage 4 complete. The ambience-only preview explicitly mutes music for its silence
  checks; the separate battle preview captures the full default mix. Existing
  headless cleanup diagnostics and two pre-existing SettingsDialog lint findings
  are documented in the verification report.
- Stage 5 complete: 31 unique male VCTK unit speakers; three exclusive male Kokoro
  announcers. Removed nine Command unit-reply assets and reject sourceless unit
  events. All roles keep their speaker across events; real source gender metadata
  and model/config hashes are recorded with credits and distribution licenses.
- Rebuilt 251 unit speech clips and 121 autonomous cues across 11 faction/role
  identities. Each mechanical role has a different body/rhythm, two selection,
  move and attack variants, plus task/startup/stop sounds. Preserved 339 existing
  command/structure recordings. Total bank: 711 clips, including 293 spoken lines.
- Four new Python regressions pass, including identity checks that ignore speed
  and profile names, isolated cache invalidation and different machine bodies.
  Full catalog/hash/decode/mix checks pass; repeat build preserves all clip hashes.
- AudioEnhancementRegression and SpeechRegression pass with zero failures. New
  coverage checks every unit/event identity and subtitle across all factions.
  Expanded rendered preview passes, includes every autonomous role, and exits
  cleanly. All three captured default mixes contain audio without clipping.
- Updated full-roster audition reel, cue sheet, live mixes, documentation and
  credits. Headless fixture shutdown diagnostics are documented in the report;
  rendered playback has no script errors. Targeted format/lint and patch checks pass.
