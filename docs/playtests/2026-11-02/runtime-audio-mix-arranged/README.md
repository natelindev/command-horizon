# Final arranged faction mix audit — 2026-11-02

This is the full-native actual CoreAudio capture after publishing the required [faction instrument arrangements](../faction-score-arrangements/README.md). The [runtime log](runtime.log) is clean. Fifteen lossless FLACs retain all three faction masters and their music, voice, effects and ambience buses. The common measured duration is 25.994739 seconds: all taps stop together on a real audio mix-block boundary, about 5 ms before the nominal 26-second deadline. No padding or invented quiet tail is added.

The [live stream/event/duck trace](runtime-mixes.json) verifies exactly the expected calm, tension and combat `.ogg` paths for each faction, with equal synchronized durations. There are still exactly three score streams per faction. Thirty-one Bastion, thirty-one Helix and thirty-five Frontier actual shots drive combat intensity; the fixture produces real critical hull, attack announcement, vehicle destruction and credited kill events.

| Faction | Master integrated LUFS | Master peak dBFS | Captured full-mix speech |
| --- | ---: | ---: | --- |
| [Bastion](bastion-master.flac) | −24.424 | −7.920 | Three exact transcripts |
| [Helix](helix-master.flac) | −24.280 | −6.194 | Three exact transcripts |
| [Frontier](frontier-master.flac) | −24.801 | −8.348 | Three exact transcripts |

[Independent verification](verification.json) and [ASR log](verification.log) pass all nine caption-to-full-master speech transcripts with zero normalized word errors. All 15 buses are finite and unclipped. All live intensity, three-stem activation, exactly −3 dB speech duck and release checks pass. Settings are Master 80%, Music 50%, Voice 80%, Effects 75% and Ambience 55%.

The audit command is `tmp/voice-venv/bin/python art/audio/verify_runtime_mix.py --input /tmp/rts-integrated-audio-arranged --output docs/playtests/2026-11-02/runtime-audio-mix-arranged --cpu-threads 2 --require-score-streams`. Historical captures may omit the metadata requirement; this final capture explicitly requires it. The earlier source-only [runtime audit](../runtime-audio-mix/README.md) remains intact for comparison.

These are measured orchestration, signal, recognition and playback facts. The retained auditions permit listener review, but no subjective musical-style approval or unperformed listening review is claimed.
