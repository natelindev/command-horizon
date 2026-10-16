# Battle dialogue and sound credits

## Faction announcements — Kokoro

The three command speakers are synthetic speech generated offline with Kokoro-82M
by hexgrad (Apache 2.0 model), using kokoro-onnx (MIT build tool).
Bastion uses `am_michael`, Helix uses `bm_george`, Frontier uses `am_fenrir`.
These voices are reserved for announcements; no unit uses them or their blends.

- Model/license: https://huggingface.co/hexgrad/Kokoro-82M
- Voice roster: https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md
- Build tool: https://github.com/thewh1teagle/kokoro-onnx
- Build inputs: https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1

## Unit and robot speech — Chatterbox / VCTK / Unmute voice donations

Each of the 31 speaking faction/unit roles and each of the 11 robots has its own voice,
cloned from a separate reference recording. Crew are native English speakers, one accent
family per army (Bastion North American, Helix English, Frontier Australian/Irish). No
reference is reused, none resembles an announcer, and delivery settings do not count as a
different voice. Assignments are in `art/audio/voice_cast.py`; each reference's file,
SHA-256, license, language, accent, pitch and recording metrics are in
`art/audio/voice-pool.json`.

- Synthesis: Chatterbox TTS by Resemble AI (MIT), https://github.com/resemble-ai/chatterbox
  — model https://huggingface.co/ResembleAI/chatterbox. Its output carries Resemble's
  imperceptible Perth watermark.
- Crew references: CSTR VCTK Corpus 0.92 — Christophe Veaux, Junichi Yamagishi and Kirsten
  MacDonald (2019), University of Edinburgh, https://doi.org/10.7488/ds/2645, licensed
  CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/); cleaned sentence-23 clips from
  https://huggingface.co/kyutai/tts-voices (`vctk/`).
- Other references: Unmute Voice Donation Project (Kyutai), `voice-donations/`, CC0,
  donated by volunteers for TTS use: https://huggingface.co/kyutai/tts-voices
  (Volhejn, V., "Unmute Voice Donation Project", 2025, https://unmute.sh/voice-donation)
- Take selection and casting only (not shipped): OpenAI Whisper (MIT) transcription,
  SpeechBrain ECAPA-TDNN (Apache 2.0) speaker similarity, CommonAccent ECAPA accent ID by
  Juan Zuluaga-Gomez (MIT).

The recordings are newly synthesized Open RTS dialogue; no reference recording is shipped.
Changes: silence trimming, equalization, light field-radio colouring for crew (parallel
band limit, presence, saturation/codec grit and speech-gated static; `art/audio/radio_voice.py`),
exact loudness normalization, peak limiting and Ogg encoding at 24 kHz. Robot lines are
instead rebuilt through per-robot voice processing (`art/audio/robot_voice.py`) and layered
over that robot's procedural machinery. No real-person impersonation or endorsement is
intended.

## Original sounds and offline playback

Original dialogue text, Kokoro command recordings and procedural machine/UI effects
are distributed under this repository's MIT license. Under their speech, workers use
piston/ratchet sounds, repair robots use servo/tool sounds, combat robots use heavy
gears/latches, and drones use rotors/telemetry, with faction tuning. Buildings use
separate console motifs. No borrowed game recordings are used.

Neither synthesis engine, model nor corpus ships with the game. Playback is fully
local and requires no credentials, network, or TTS installation. `catalog.json`
records model hashes, engine versions, cast profiles and robot voice designs. The manifest
records each clip's text, profile ID (null for mechanical cues), SHA-256 and the accepted
take's transcription check.
