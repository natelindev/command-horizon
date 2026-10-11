# Battle dialogue and sound credits

Spoken recordings are synthetic speech generated offline with **Kokoro-82M**
(hexgrad) using the MIT-licensed **kokoro-onnx** build tool. The model is licensed
under Apache 2.0. Neither the model nor the synthesis library ships with the game.

- Model and license: https://huggingface.co/hexgrad/Kokoro-82M
- Voice roster: https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md
- ONNX runtime: https://github.com/thewh1teagle/kokoro-onnx
- Build model/voice files: https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1

All speaking profiles use only documented male styles: `am_michael`, `am_fenrir`,
`am_onyx`, `am_eric`, `bm_george`, `bm_fable`, and `bm_lewis`. There are 34 distinct
role profiles (including three announcers), produced from seven base voice styles
with distinct style weights and delivery speeds; these are not 34 voice actors.
No real-person impersonation or endorsement is intended.

Original dialogue was written for Open RTS. Processing consists of voice-style
blending before synthesis, light low-mid equalization and presence adjustment,
loudness normalization, an onset fade and Ogg encoding. Speech retains its full
24 kHz bandwidth; no narrow radio filter, echo or pitch shifting is applied.
Generated dialogue and original procedural mechanical/UI effects are distributed
under this repository's MIT license. They contain no borrowed game recordings.
The model license is recorded as build-input provenance, not a claim that these
outputs are model weights.

`art/audio/voice_cast.py` records every line and style profile. `catalog.json`
records model/voice hashes and engine version. `art/audio/battle-audio-manifest.json`
records each clip's text, profile ID (null for mechanical cues) and SHA-256.
Playback is entirely local and requires no credentials, service, or TTS install.
