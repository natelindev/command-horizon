# Open RTS background score

Four local stereo Ogg loops currently ship with the game:

| Context | Cue | Duration |
| --- | --- | --- |
| Menu | After the Silence | 96 s |
| Bastion | Hold the Line | 92.3 s |
| Helix | Perfect Compliance | 85.7 s |
| Frontier | No Shutdown Code | 80 s |

These are procedurally composed temporary cues, **not Suno output**. They share a D-minor motif but use different rhythms and instrumentation: quiet piano/strings for the menu, military percussion for Bastion, rigid electronic sequences for Helix, and syncopated plucked strings for Frontier. Rebuild with `uv run --with numpy --with scipy python art/audio/compose_score.py` (requires ffmpeg). The score contains synthesized notes and percussion, with no external samples.

`source/audio/MusicDirector.gd` chooses the human faction's cue during battle and the menu cue elsewhere. Two players provide 2.5-second transitions and keep playing through tactical pause. Music has a separate persisted volume slider. Program test arenas do not start music.

`score-manifest.json` records composition details; `audio-verification.json` records the final decoded durations, peaks, RMS and loop-boundary sample steps. All four decode successfully and remain below full scale. Short edge envelopes reduce codec boundary discontinuities. Playback, looping, switching, pause, mute and gain are covered by `MusicRegression.gd`; settings cancellation is covered by `LocalizationRegression.gd`.

## Suno v5 request status

Four original instrumental briefs were submitted through the user's AnyInt service with model `suno-v5`. Both the generic async-task query and the provider's native Suno query return `submitting`, with no audio artifacts or reported error. `suno-tasks.json` retains task IDs and observed status so they can be resumed without duplicate submissions. The local cues remain active until actual generated audio is available and checked. No Suno result has been downloaded or claimed as complete.

Credentials are stored only in macOS Keychain, not in the repository or manifests. The game itself needs no API key or network access to play its music.
