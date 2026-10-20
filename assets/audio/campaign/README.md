# Campaign narration

`narration.json` holds the four shared Bastion Command cues (defeat, enemy base, siege commander arrival and defeat). Operation-specific lines are recorded dialogue in `conversations.json`, which replaced the earlier single-narrator lines. Every cue has an English and Simplified Chinese recording (8 WAVs). The game has no speech synthesis, network, Python, or Hugging Face dependencies at runtime.

These recordings use neural speech models downloaded from Hugging Face, replacing the initial macOS system voice draft:

| Locale | Official model | Pinned revision | Voice |
| --- | --- | --- | --- |
| English | [hexgrad/Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) | `f3ff3571791e39611d31c381e3a41a3af07b4987` | `af_heart` |
| Simplified Chinese | [hexgrad/Kokoro-82M-v1.1-zh](https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh) | `01e7505bd6a7a2ac4975463114c3a7650a9f7218` | `zf_001` |

Both model cards identify the weights as Apache-2.0 licensed. The Mandarin model adds professional Chinese speakers; the English narrator uses the original model's established English voice. Only the selected model configuration, weights, and voice embedding are downloaded to the build machine's Hugging Face cache, outside the repository. Official model-card weight SHA256 values are checked before synthesis. `generation-manifest.json` records configuration/voice/weight hashes, exact package versions, per-cue random seeds, source-text and final-waveform hashes, durations, peaks, and RMS levels.

English uses speed 0.98. Mandarin is split at sentence boundaries and uses the model author's token-length speed curve with a 1.05 multiplier to avoid rushing long phrases. Sentence boundaries have 160 ms of silence. FFmpeg normalizes clips to `I=-18:TP=-3:LRA=7`, then stores mono 16-bit PCM WAV at 24,000 Hz. The existing Voice audio bus controls volume and radio processing. No image, model, texture, or character artwork is replaced.

`CampaignNarration.gd` plays the English recording in both locales and shows the subtitle in the chosen UI language; a locale change updates captions immediately. Critical battlefield warnings pause narration, then it resumes; routine unit replies are suppressed during narration and work again afterward.

## Regeneration

The build script stages output, checks a complete manifest, and only then installs audio. No arguments prints the current narration inventory. Models are public and need no authentication. The script limits PyTorch to one CPU thread and fixes each cue's seed independently.

```sh
uv venv /tmp/rts-campaign-tts --python 3.12
uv pip install --python /tmp/rts-campaign-tts/bin/python -r tools/audio/requirements.txt
/tmp/rts-campaign-tts/bin/python tools/audio/generate_campaign_narration.py generate --sample
/tmp/rts-campaign-tts/bin/python tools/audio/generate_campaign_narration.py verify
/tmp/rts-campaign-tts/bin/python tools/audio/generate_campaign_narration.py generate
/tmp/rts-campaign-tts/bin/python tools/audio/generate_campaign_narration.py install
```

FFmpeg must be available on PATH. `--output <directory>` selects a staging directory (default `tmp/tooling/campaign-narration-hf`). `verify` checks model provenance, all source/file hashes, sample format, duration, silence and clipping. `install` rejects a partial sample batch and is idempotent. Run the Godot editor import after installing changed WAVs, then `CampaignStoryRegression.gd` and `CampaignStoryMissionsRegression.gd`.
