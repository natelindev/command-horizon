# Combat voice verification — 2026-11-02

The completed bank has 872 distinct recordings: 542 spoken clips across 54 cast voices and 330 mechanical facility cues. The 80 new critical-hull/kill reactions use each combat role’s existing cast and faction processing. No new reaction aliases an accepted order recording. The Bulwark Walker’s new critical-hull line names its current hull, with matching English audio and Chinese caption. All 792 prior battle recordings (the original 759 plus 33 refinery cues) and all 160 campaign conversations retain their exact bytes; [preserved hashes](preserved-recordings.json) record them.

[Native](CombatVoiceRegression-native.log) and [script fallback](CombatVoiceRegression-fallback.log) both pass with clean shutdown. The tests cover every role’s playable low-health/kill clips, actual credited enemy kills, multi-kill coalescing, friendly/enemy isolation, strict below-25% hull warnings, recovery rearming, interruption/priority, obsolete queued reports and silent save reconstruction.

The [encoded speech audit](voice-identity.log) transcribes all 80 new clips and compares the complete 542-clip bank’s 54 speakers. It passes with 71 exact transcripts, mean normalized word error 0.0199 and maximum cross-speaker ECAPA cosine 0.494. Inexact transcripts and donor comparisons remain in [voice-combat-verification.json](../../../../art/audio/voice-combat-verification.json).

The [full asset audit](asset-integrity.log) decodes and hash-checks all 872 clips. Spoken loudness ranges from −16.72 to −15.47 LUFS, within the −16 ±1 LUFS contract. The highest decoded peak across all speech/mechanical clips is −0.89 dBFS. The [mix-format check](clean-mix.log) confirms 542 speech clips at 24 kHz, all cast assignments and four quiet ambient beds. The [complete measurement report](../../../../art/audio/battle-audio-verification.json) retains per-file duration, loudness and peak data.

The [lossless audition reel](faction-voice-audition.flac) and [cue sheet](audition-cues.json) include faction announcements, orders, critical hull and kill reactions, mechanical facilities and neutral mercenaries. FLAC avoids an assertion in FFmpeg’s experimental native Vorbis encoder on the concatenated reel; shipped game Oggs remain unchanged.

These are intelligibility, signal and cast-identity measurements. They do not claim an unperformed subjective listening review. Campaign briefing completion and the final music/speech audition are tracked separately.
