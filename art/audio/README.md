# Open RTS audio

## Battle voices and interface sounds

The offline battle bank adds 720 short clips: 302 spoken lines and 418 mechanical cues.
Speech uses 34 distinct male-only style profiles from seven Kokoro base voices
across Bastion, Helix and Free Frontier. Each faction has its own announcer. Infantry,
heroes, vehicle crews and mission transports have role-specific selection, movement,
attack, ready and stop lines; the Frontier scrapper also acknowledges gathering,
building and repairs. Autonomous machines and structures use nonverbal motors,
servos and telemetry motifs. Speech is English with matching captions.

`voice_cast.py` contains casting and original dialogue. `build_battle_audio.py`
uses Kokoro ONNX, soundfile, NumPy and ffmpeg to generate the bank and four UI cues.
The model stays in `tmp/kokoro`; the game needs no TTS installation or network.
Build inputs and output hashes are recorded in `battle-audio-manifest.json` and
`assets/audio/voices/catalog.json`. The per-clip cache checks both source inputs
and output hashes, so edits to dialogue or casting regenerate affected clips.
Speech is synthesized at 24 kHz with light equalization and no narrow radio filter.
The three announcers use Michael (Bastion), George (Helix), and Fenrir (Frontier);
unit roles use documented male-only style blends and delivery rates.

The four regional beds are 10.3–13.2 dB quieter in the mix than the previous
version, with their noise above 2 kHz reduced by 22.9–31.5 dB. Local ambient
actors are quieter too. Settings previews use the same bed gain as gameplay;
persisted volume preferences are preserved. Run `verify_clean_mix.py` to guard
the male cast, speech sample rate and low-hiss ambience asset limits.

See [voice attribution](../../assets/audio/voices/LICENSES.md) and the
[verification and audition files](../../docs/playtests/2026-10-11/audio-enhancement/README.md).
Run `verify_battle_audio.py` to decode every clip, check its peak and hash, and
rebuild the listening reel. These measurements verify asset integrity; listening
quality and performance direction remain subjective.

The shared battle channel coalesces simultaneous production, groups selection/order
chatter behind a 1.5-second cooldown, never queues acknowledgements, and limits
notifications to four pending entries with six-second expiry. Attack warnings,
casualties and match results have priority. Lesser danger reports share a four-second
budget, while base warnings can interrupt immediately. Opposite queued power states
replace one another. Research (including Coordination),
construction and power transitions use the faction announcer. Automatic rally
movement, rejected full queues, enemy activity and save reconstruction stay silent.
UI buttons, toggles, tabs, menus, lists and sliders use one Effects player with a
75 ms global debounce; programmatic refresh and hover do not trigger audio.

Speech follows Voice volume; mechanical responses and UI follow Effects volume.
The existing combat and ambience systems retain their voice ducking and limits.

## Background recordings

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
