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

## Unit speech — Piper / VCTK

Each of the 31 speaking faction/unit roles has a separate male VCTK speaker ID.
No speaker is reused between roles or factions. The explicit assignments are in
`art/audio/voice_cast.py`; selected gender/accent metadata and its source are in
`art/audio/vctk-speakers.json`. Delivery speed does not count as a different voice.

- Synthesis: Piper (`piper-tts` 1.4.2, GPL-3.0 build tool),
  https://github.com/OHF-Voice/piper1-gpl
- Model: `en_GB-vctk-medium`, Michael Hansen / Rhasspy,
  https://huggingface.co/rhasspy/piper-voices/tree/main/en/en_GB/vctk/medium
- Model card / dataset license (CC BY 4.0):
  https://huggingface.co/rhasspy/piper-voices/blob/main/en/en_GB/vctk/medium/MODEL_CARD
- Corpus: Christophe Veaux, Junichi Yamagishi and Kirsten MacDonald (2019),
  CSTR VCTK Corpus: English Multi-speaker Corpus for CSTR Voice Cloning Toolkit,
  version 0.92, University of Edinburgh / Centre for Speech Technology Research.
  https://doi.org/10.7488/ds/2645
- Attribution license: https://creativecommons.org/licenses/by/4.0/

The generated unit speech recordings are distributed under CC BY 4.0 with the
above attribution. They are newly synthesized Open RTS dialogue, not unmodified
corpus recordings. Changes: synthesis of original text, light equalization,
loudness normalization, onset fade, resampling and Ogg encoding. Native synthesis
is 22.05 kHz for units and 24 kHz for command; spoken Oggs are encoded at 24 kHz.
No narrow radio filter, echo, pitch shifting or announcer blending is applied.
No real-person impersonation or endorsement is intended.

## Original sounds and offline playback

Original dialogue text, Kokoro command recordings and procedural machine/UI effects
are distributed under this repository's MIT license. Workers use piston/ratchet
sounds, repair robots use servo/tool sounds, combat robots use heavy gears/latches,
and drones use rotors/telemetry. Faction tuning and event/variant gestures provide
11 autonomous identities with 121 clips. Buildings use separate console motifs.
No borrowed game recordings are used.

Neither synthesis engine, model nor corpus ships with the game. Playback is fully
local and requires no credentials, network, or TTS installation. `catalog.json`
records model/config hashes, engine versions and speaker mappings. The manifest
records each clip's text, profile ID (null for mechanical cues) and SHA-256.
