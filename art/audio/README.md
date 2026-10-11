# Open RTS background score

The game now ships four complete, freely licensed, non-orchestral recordings:

| Context | Recording | Artist | Style | Length |
| --- | --- | --- | --- | --- |
| Menu | Nebulous | Joe Baxter-Webb (BossLevel VGM) | Space ambient | 3:56 |
| Bastion | Rock of War | p0ss | Industrial marching rock | 3:24 |
| Helix | Perpetual Tension | Zander Noriega | Dark sci-fi electronics and guitar | 2:42 |
| Frontier | The Recon Mission | Zander Noriega | Heavy guitar, bass and drums | 3:03 |

See [distribution credits](../../assets/audio/music/LICENSES.md) for source links,
author attribution, licenses, and modification notices. These are CC BY 3.0 /
CC BY-SA 3.0 recordings, not public-domain or Suno-generated music. Instrumentation
was selected from author descriptions; technical checks do not constitute a
subjective listening review.

`licensed-score.json` pins original audio hashes and source downloads. Download
those files into `tmp/music/licensed` (extract the named WAVs from Zander's ZIPs),
then run `python3 art/audio/import_licensed_score.py` with ffmpeg/ffprobe installed.
The importer verifies source hashes, applies constant gain toward -20 LUFS with
peak headroom, adds short endpoint fades, and retains full arrangements. It writes
stereo 44.1 kHz Ogg files, decoded audio measurements in
`licensed-audio-verification.json`, and 30-second MP3 audition excerpts in
`tmp/music/previews`. Looping repeats the full recording, including natural
intro/outro pacing; these are not beat-spliced seamless loops.

`source/audio/MusicDirector.gd` selects the human faction's music in battle and
the menu track elsewhere. Two players crossfade over 2.5 seconds, including during
tactical pause. Music has a separate persisted volume slider. Program test arenas
do not start music. `tests/headless/MusicRegression.gd` covers decode, full-length
assets, looping, crossfades, rapid switching, pause, mute and gain.

## Retired sources

`compose_score.py`, `score-manifest.json` and `audio-verification.json` describe the
retired procedural placeholders. The composer now writes only to
`tmp/music/procedural-legacy`, so it cannot overwrite the selected licensed score.

Four prior AnyInt Suno v5 requests remained `submitting` with no artifacts when
checked on 2026-10-11. `suno-tasks.json` retains their IDs to prevent duplicate
submissions. No new paid jobs were submitted, and the game no longer depends on
those requests. Credentials remain only in macOS Keychain. Music playback is
fully local and requires no account or network connection.
