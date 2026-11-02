# Adaptive music integration — 2026-11-02

Each faction now plays three distinct, sample-synchronized streams: ambient,
tension and combat. The two existing players retain scene crossfades; each battle
player contains one three-stream `AudioStreamSynchronized` clock.

The offline generator derives complementary atmospheric, transient/rhythm and
upper-harmonic layers from the existing licensed full recordings. These are
source-separated adaptations, not separately recorded instrument stems. The
existing recording attribution and licenses apply to all nine outputs.

Actual weapon launches, hull damage and artillery impacts drive the score.
Moving near observed enemies introduces tension. Per-participant musical budgets
prevent rapid-fire units from dominating; hidden engagements and tactical-pause
events do not introduce activity. Event memory and exponential release return the
mix to its ambient layer. Speech ducks the complete music bus uniformly.

Campaign hubs and briefings can select their faction score through `music_faction`
and add their Voice player to `narration_audio` for speech ducking.

## Verification

- `MusicRegression.gd`: zero failures for all four tracks, nine distinct faction
  stems, decoded duration alignment, looping, crossfades, superseded background
  loads, mute, gain, tactical pause, actual projectile events, artillery intensity,
  rhythm/lead layer activation and exponential release.
- Every encoded stem decodes without errors at stereo 44.1 kHz and has exactly
  the same sample count as its complete source recording.
- Summed encoded stems reconstruct their encoded source at 23.656–29.821 dB SNR
  (the difference includes independent lossy Ogg encoding). No output clips.
- Measurements are retained in [verification.json](verification.json); runtime
  output is retained in [MusicRegression.log](MusicRegression.log).

The final narrative/audio audition and 200-unit audiovisual performance gate
remain open in the completion audit.
