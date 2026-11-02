# Actual faction mix audit — 2026-11-02

[IntegratedAudioPreview](../../../../tests/rendered/IntegratedAudioPreview.gd) captured the actual CoreAudio output of three running matches, with 31 Bastion, 31 Helix and 35 Frontier projectile shots, critical hull, an attack announcement, vehicle destruction and a credited kill. Each faction has lossless master, music, voice, effects and ambience FLACs. All use the common first 26 seconds; the temporary WAV capture's sequential bus extraction added different quiet tails, which are excluded consistently.

The recorded settings were Master 80%, Voice 80%, Effects 75%, Ambience 55% and Music 50%. [Runtime events and stem/duck samples](runtime-mixes.json), [per-bus measurements and transcripts](verification.json), and the [audit log](verification.log) retain the evidence. Reproduce the audit with `tmp/voice-venv/bin/python art/audio/verify_runtime_mix.py --input /tmp/rts-integrated-audio-current --output docs/playtests/2026-11-02/runtime-audio-mix` while the raw capture remains available.

| Faction | Master integrated LUFS | Master peak dBFS | Full-mix speech |
| --- | ---: | ---: | --- |
| [Bastion](bastion-master.flac) | −24.460 | −7.995 | Three exact transcripts |
| [Helix](helix-master.flac) | −24.575 | −6.313 | Three exact transcripts |
| [Frontier](frontier-master.flac) | −24.977 | −7.773 | Three exact transcripts |

All 15 buses contain finite audio with no clipped samples. Whisper medium.en recognizes all nine delivered utterances with zero normalized word errors despite simultaneous combat and music. Source-clip correlation locates each actual utterance; it is retained as diagnostic data because the game's playback resampling and bus processing alter waveforms. The voice-to-background energy ratios are measurements of the separately captured buses, not perceptual intelligibility guarantees.

The live trace reaches each of the three synchronized stems, exactly −3 dB speech ducking and zero duck after release. Intensity rises from calm to a peak above 0.7 with actual combat, then falls after fire stops. Source loudness, hashes and cast identity are covered separately by the [complete 872-clip voice audit](../combat-voice/README.md). Music event and exponential-decay contracts are covered by MusicRegression.

The [licensed source manifest](../../../../art/audio/licensed-score.json) identifies Bastion’s Rock of War as industrial marching rock, Helix’s Perpetual Tension as dark sci-fi electronic, and Frontier’s The Recon Mission as guitar-driven heavy rock. These are adaptations of those sources. The audit does not establish the design’s specific slide guitar/blues harp, dark orchestral brass or hypnotic arpeggio/deep-sub instrumentation. That narrower musical acceptance remains open.

These measurements establish signal integrity, recognition and runtime mixing behavior at the captured settings. The audition files preserve the faction music and sound design for listener review; no subjective listening, musical-style approval or professional-performer claim is made here.
