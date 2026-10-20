# Faction and unit audio

The battle bank contains 759 clips: 365 crew and command lines, 97 robot lines and
297 structure console cues. Its 54 speakers comprise 37 faction crew roles, three
neutral mercenaries, 11 robots and three exclusive announcers. Every unit keeps its
own speaker across selection, movement, attack, readiness and stop responses.

Fighters, bombers and mobile anti-air crews now have their own voices in all three
armies. Camp mercenaries keep one identity whichever faction hires them. The 96 new
recordings preserve all 663 existing clip hashes.

## New cast

All new roles are human crew. Pilot lines use the pilot headset; anti-air crews
use helmet intercoms; mercenaries use their own commercial handsets. Reference
similarity below is the nearest other cast reference, measured with ECAPA cosine.
The entire reference cast's closest pair is 0.392.

| Faction | Role | Reference | Accent | Nearest similarity |
| --- | --- | --- | --- | --- |
| Bastion | Fighter | Gonzalo-1 | US | 0.207 |
| Bastion | Bomber | Antoni | US | 0.353 |
| Bastion | Anti-air | MrHat | US | 0.326 |
| Helix | Fighter | VCTK p286 | English | 0.309 |
| Helix | Bomber | Midlands_Bedfordshire_Dialect | English | 0.282 |
| Helix | Anti-air | 29da | English | 0.350 |
| Frontier | Fighter | VCTK p374 | Australian | 0.358 |
| Frontier | Bomber | Roscoe | Australian | 0.365 |
| Frontier | Anti-air | Jeremy_Q | US | 0.355 |
| Neutral | Iron Warden | VCTK p281 | Scottish | 0.321 |
| Neutral | Dust Ranger | VCTK p255 | Scottish | 0.341 |
| Neutral | Breach Lancer | VCTK p275 | Scottish | 0.353 |

VCTK accents are self-reported; donation accents use the pool's classifier. Frontier
retains its predominantly Irish/Australian cast with native English backups.
Assignments, reference hashes and licenses are recorded in `art/audio/voice_cast.py`
and `art/audio/voice-pool.json`.

## Listen

- [Faction audition reel](faction-voice-audition.ogg) and [cue sheet](audition-cues.json):
  Bastion, Helix, Frontier, then the neutral mercenaries; selection and attack clips
  from every current crew and robot role.
- Earlier gameplay mix captures: [Bastion](bastion-live-mix.wav),
  [Helix](helix-live-mix.wav), [Frontier](frontier-live-mix.wav).
- Earlier caption captures: [Bastion unit](bastion-unit-caption.png),
  [Helix announcer](helix-announcer-caption.png), [Frontier unit](frontier-unit-caption.png).

Chatterbox synthesizes the unit and robot performances; Kokoro synthesizes the
announcers. Crew retain energetic battle dialogue and light radio colouring mixed
with dry speech. Robots keep their own processors and machinery. All speech is
encoded at 24 kHz and mastered to -16 LUFS with a -1.5 dBFS peak limit before
encoding. The runtime Voice bus remains full-band. Speech follows Voice volume;
structure and UI cues follow Effects volume.

Decode, words, identity, levels and event routing have automated checks. Acting
quality remains a listening judgment; the earlier gameplay mixes and screenshots
were not recreated for this cast extension. See [voice credits](../../../../assets/audio/voices/LICENSES.md)
for source attribution and processing details.

## Verification — 2026-10-20

| Check | Result |
| --- | --- |
| Cast validation and reference separation | 51 unique reference voices; closest pair 0.392 cosine; closest announcer/reference 0.284 |
| Shipped speaker separation | 54 speakers; maximum cross-speaker cosine 0.494, below the 0.5 limit |
| Human donor identity | All 40 crew/mercenary voices match their own reference better than any other cast reference |
| Whisper audit of encoded Ogg speech | 462 clips; 451 exact after spelling normalization; mean word mismatch 0.0054; none exceeds its configured limit |
| Decode, hashes and mastering | 759 clips; speech -16.72 to -15.47 LUFS; highest decoded peak -0.89 dBFS |
| Existing content preserved | All 663 pre-existing clip hashes unchanged; 96 new recordings |
| Repeat build | All 759 clip hashes, catalog and manifest unchanged |
| Cast and transcript unit tests | 11 passed |
| Clean mix audit | 54 voices, 462 speech clips at 24 kHz, four quiet regional beds |
| AudioEnhancementRegression | 0 failures across all three factions and neutral hires |
| LocalizationRegression | 0 failures; captions for every new recording translated |
| EnvironmentAudioRegression | 0 failures; all 16 current campaign operations receive the appropriate regional bed |

Machine-readable details: [asset audit](../../../../art/audio/battle-audio-verification.json)
and [speech/identity audit](../../../../art/audio/voice-identity-verification.json).
The speech report preserves raw ASR output for inexact lines. Compound spacing
(`Duststorm` / `dust storm`) does not change the spoken words. Whisper's joined
`Rootset` spelling is
split into `root set`; its mismatch with written `route` still counts, at 0.25 for
that existing supply-truck line. Missing or changed words remain scored. Godot
headless checks completed with inherited resource-cleanup warnings at process exit.

The identity audit transcribes the actual encoded recordings and compares every
speaker with the other speakers and source references. A hash-keyed transcript
cache lets an interrupted audit resume while invalidating changed clips or
recognizer settings. The runtime regression rejects borrowed role identities and
checks that neutral mercenaries retain one voice across all factions.

Build dependencies are pinned in `art/audio/voice-requirements.txt`. See
[build and verification commands](../../../../art/audio/README.md). Models,
reference recordings and synthesis tools stay outside the shipped game; playback
is fully local.
