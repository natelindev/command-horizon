# Unit voice overhaul

Goal: unit speech that is loud, consistent and clearly intelligible; every speaking unit has
its own natural, military-sounding voice; robotic units speak through distinct robotic voices
layered over their own machine signature.

## Findings (baseline)

- The `Voice` bus runs a "radio" chain (380 Hz high-pass, 3.6 kHz low-pass, overdrive,
  compressor). It removes chest resonance and consonant detail from every line — the main
  cause of the muffled sound and of voices blurring together.
- Unit lines come from Piper `en_GB-vctk-medium` (22 kHz, read-aloud prosody, mumbly).
- Single-pass `loudnorm` on 1–2 s clips leaves unit loudness spread from −23.7 to −17.9 LUFS.
- Robots/drones/worker bots only emit procedural tones.

## Stages

1. **Mix** — replace the radio band-pass with a clarity chain (low cut, gentle compression,
   limiter); duck effects harder under speech. Robot voices play on the Voice bus.
2. **Casting** — analyse the 228 CC0 Unmute voice donations (Kyutai `tts-voices`): English
   detection, pitch, recording quality, speaker embeddings. Pick a maximally separated
   male cast for the 31 speaking roles (role-appropriate pitch/age), plus 11 separate base
   voices for robot identities; reject anything close to the Kokoro announcers.
3. **Synthesis** — Chatterbox (MIT) zero-shot cloning at 24 kHz, per-event delivery
   (calm select, brisk move, urgent attack). Several seeded candidates per line; keep the
   best by Whisper transcription match and speaker similarity. Trim, light EQ, exact
   per-clip loudness normalisation with true-peak limit.
4. **Robots** — original robot dialogue; per-role robotic voice DSP (pitch/formant shift,
   ring modulation, comb resonance, bit reduction) tuned per faction, layered over the
   existing role machinery. Buildings keep console cues.
5. **Integration** — catalog/manifest, captions + Chinese translations, credits, cast
   validation (speaker uniqueness by embedding distance, not just ID), regression tests.
6. **Verification** — Python verifiers, Godot headless regressions, audition reel.

## Agent progress

- [x] Baseline investigation and clarity mix (clean runtime bus, combat ducking).
- [x] Native-accent military crew casting and distinct robot base identities.
- [x] User feedback incorporated: energetic scripts and delivery, lighter field-radio
  coloration, resampling-based robot processing that preserves consonants.
- [x] Full build assembled: 687 clips, including 390 speech clips across 45 identities.
- [x] Final correction pass (2026-10-16): four revised Frontier lines and eight Frontier
  drone clips rebuilt. Verified that these were the only 12 changed voice Ogg files.
- [x] Catalog, manifest, captions, translations, credits/licenses and audition reel integrated.
- [x] Build QC, battle-audio verifier, clean-mix verifier and all nine voice unit tests pass.
  Speech loudness ranges from −16.72 to −15.47 LUFS.
- [x] Final shipped-file Whisper/ECAPA audit passes: 390 clips, 381 exact transcripts,
  mean word error 0.006, maximum cross-speaker similarity 0.494 (limit 0.5); no failures.
  Crew identities match their own reference better than every other cast reference.
- [x] Speech, audio enhancement, Chinese UI, localization and subtitle headless regressions pass.
- [x] Rendered English/Chinese caption and portrait review completed after the user
  authorized game launches; all 16 campaign openings and long debrief layouts captured.
- [ ] Human listening acceptance of the final audition reel remains.
