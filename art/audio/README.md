# Open RTS audio

## Battle voices and interface sounds

The offline battle bank contains 687 clips: 293 crew/command lines, 97 robot lines and
297 structure console cues. Three male Kokoro voices are reserved for faction
announcements. The 31 speaking faction/unit roles and the 11 robots each clone their own
reference voice with Chatterbox. Crew are native English speakers with one accent family
per army — Bastion North American, Helix English, Frontier mostly Irish/Australian — cast
from VCTK speakers (self-reported accents) and confidently native CC0 donations. Casting is
chosen for distinctness: across all 42 references the closest pair scores 0.39 ECAPA
cosine (same-person pairs score above roughly 0.5), and none is close to an announcer.
Selection, movement, attack, ready and stop responses stay with the same voice. Soldiers are
spoiling for a fight: the script is battle-hungry, delivery runs hot (Chatterbox
exaggeration 0.65–1.0, most intense on attack) and Frontier's scrapper also speaks for
gathering, building and repair orders. All speech has matching captions.

Every spoken line is the best of up to nine seeded takes: Whisper `medium.en` must hear the
written words, the take must still sound like its cast voice (ECAPA similarity) and must not
leap into a screech; among those, the most fired-up take wins (vocal effort plus raised
pitch). Crew lines get light, baked field-radio colouring by unit class and faction
(`radio_voice.py`: handset, throat mic, command net, helmet intercom, pilot headset or CB
radio; Bastion analog, Helix digital, Frontier rough), blended in parallel with the dry
voice so consonants stay clear. Speech is trimmed, equalized and normalized to −16 LUFS per
clip with a −1.5 dBFS peak limit. The game's Voice bus plays it full-band (low cut, gentle
compression, limiter); a runtime radio band-pass previously muffled words and made
speakers sound alike. Crew and command lines keep a short radio chirp.

Robots speak short machine reports through their own voice designs in `robot_voice.py`:
Bastion machines are metallic and clean, Helix machines are vocoded and glassy, Frontier
machines are scrap-built and gritty, and within a faction each role has its own register
and mechanism. Their speech sits over role-specific machinery: workers use piston motors
and ratchets, repair robots use servos and tool taps, combat robots use heavy gears and
latches, and drones use rotors and telemetry. Structures use short console cues. Generic
sourceless unit events are rejected; only a real unit can supply a unit reply.

`voice_cast.py` contains explicit casting, delivery and original dialogue.
`analyze_voice_pool.py` profiles the reference voices (language, accent, pitch, quality)
into `voice-pool.json`, and `select_voice_cast.py` proposes a native, maximally distinct cast. `build_battle_audio.py` uses
Kokoro ONNX, Chatterbox, Whisper, SpeechBrain, soundfile, NumPy and ffmpeg. Build
inputs stay under `tmp`; the game requires no TTS installation or network. The catalog
and manifest pin inputs, output hashes and each accepted take's transcription. The
per-clip cache includes only its own voice/model, so recasting one unit leaves other
speech and mechanical clips untouched.

```sh
uv venv --python 3.11 tmp/voice-venv
VIRTUAL_ENV=tmp/voice-venv uv pip install -r art/audio/voice-requirements.txt
VIRTUAL_ENV=tmp/voice-venv uv pip install --no-deps kokoro-onnx==0.6.1
# Reference voices from huggingface.co/kyutai/tts-voices: voice-donations/*_enhanced.wav into
# tmp/voice-refs/donations/, vctk/*_enhanced.wav into tmp/voice-refs/vctk/ (hashes are checked
# against voice-pool.json). A CUDA machine can render a slice: --shard <prefixes> --checkpoint <file>;
# merge its Oggs and checkpoint, then run the full build once to assemble the catalog.
tmp/voice-venv/bin/python art/audio/build_battle_audio.py --model tmp/kokoro/kokoro-v1.0.onnx --voices tmp/kokoro/voices-v1.0.bin
cd art/audio
../../tmp/voice-venv/bin/python -m unittest test_voice_cast
../../tmp/voice-venv/bin/python verify_voice_cast.py
../../tmp/voice-venv/bin/python verify_battle_audio.py
../../tmp/voice-venv/bin/python verify_voice_identity.py
../../tmp/voice-venv/bin/python verify_clean_mix.py
```

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

Crew, command and robot speech follow Voice volume; structure cues and UI follow Effects
volume. While anyone speaks, combat effects duck by 6 dB and ambience by 8 dB.

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

## Hero campaign conversations

`docs/plans/hero-campaign-dialogue.json` authors 160 English/Chinese lines for 16
missions and 13 characters. `build_campaign_audio.py` uses the battle pipeline's
reference voices and quality checks; CANTOR adds a distinct vocoder design. Aegis,
Nyx and Rook keep their battle identities. Source hashes allow interrupted builds
to resume without replacing accepted recordings. Each take is encoded to Ogg before
transcription, and accepted bytes are retained unchanged. The builder and audit share
a vocabulary and normalize equivalent spoken spellings (including written numbers
and the homophones Ren/Wren); wrong numbers and missing words still fail checks.

Run `verify_campaign_audio.py` with the voice environment to audit the actual Ogg
files, including transcript accuracy, loudness, peaks and cast identity. Its
transcript cache is keyed by file hash and expected text. Only after the complete
audit passes does `install_campaign_dialogue.py` assemble the runtime conversation
catalog. It verifies the shipped hashes against that audit. Import with Godot's
headless editor before running the campaign dialogue regressions.

Portraits are original SVGs produced by `tools/ui/generate_campaign_portraits.py`.
The campaign distribution credits are `assets/audio/campaign/LICENSES.md`. Legacy
narration remains for save compatibility. Listening and rendered review remain
separate from these automated checks.
