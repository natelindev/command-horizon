# Complete illustrated briefing narration — 2026-11-02

All 16 mission introductions are published in the runtime catalog, with 64 original English paragraphs and matching English/Simplified Chinese captions. Aegis, Nyx and Rook retain their established commander voices. Each mission uses every authored word and paragraph; full encoded duration is 45.1200–45.1627 seconds. Mild pitch-preserving tempo adjustment and natural paragraph rests preserve the complete recordings rather than truncate them.

The [independent encoded audit](verification.json) passes with 58 exact paragraph transcripts, mean normalized word error 0.0040, speech loudness −16.00 to −15.99 LUFS and highest decoded peak −1.19 dBFS. Minimum own-donor ECAPA similarity is 0.6465, with minimum margin 0.3965 over the other commanders. All 64 encoded hashes, transcripts, per-file levels and donor comparisons remain in that report and [the audit log](encoded-verification.log). These are objective intelligibility/cast measurements, not a subjective listening or professional-performer claim.

The [complete lossless audition](mission-briefing-audition.flac) includes all 16 missions. [Its cue sheet](audition-cues.json) locates every bilingual paragraph. Only the audition adds 1.5 seconds between missions; shipped mission recordings and runtime timings are unchanged.

The runtime uses distinct `.briefing` cues. All 160 older campaign conversation files and the prior 792 battle recordings retain their exact bytes; older `.intro` cue IDs remain intact. Publication required a complete passing audit and matching encoded hashes, then installed all 16 catalog entries atomically. [Installation](install.log), [Godot import](import.log), and [11 pipeline checks](pipeline-unit.log) are retained. Frontier Wren’s complete, faster delivery uses authored 1.25-second paragraph rests to stay above the 0.8 tempo floor without dropping any words; the other recordings stayed unchanged.

| Mission | Actual encoded seconds |
| --- | ---: |
| supply_line | 45.1387 |
| first_orders | 45.1627 |
| split_signal | 45.1387 |
| bastion_cinder_ford | 45.1440 |
| broken_foundry | 45.1333 |
| command_horizon | 45.1493 |
| helix_quiet_streets | 45.1440 |
| helix_the_gate | 45.1547 |
| helix_cinder_ford | 45.1387 |
| helix_pruning | 45.1280 |
| helix_severance | 45.1307 |
| frontier_drainage | 45.1440 |
| frontier_cinder_ford | 45.1227 |
| frontier_salvage | 45.1200 |
| frontier_wren | 45.1227 |
| frontier_the_coalition | 45.1467 |

Rebuild/audit with `art/audio/build_briefing_audio.py` status/build/verify/install in the voice environment. `art/audio/briefing-script.json` is the bilingual source; `briefing-audio-manifest.json` pins the recording inputs and encoded outputs. Build models, donor references and phrase caches remain offline inputs under `tmp/`; game playback needs no Python, network or synthesis runtime. Credits and source licenses are in [campaign attribution](../../../../assets/audio/campaign/LICENSES.md).

Full catalog/caption/duration and actual paragraph save/resume pass CampaignBriefingRegression with `--require-complete` in both [native](CampaignBriefingRegression-native.log) and [script fallback](CampaignBriefingRegression-fallback.log): 16 missions, 64 paragraphs, zero failures and clean shutdown. Every active paragraph validates as persistent state; every mission also performs a real last-paragraph disk save/restore/resume. Illustrated briefing presentation and secondary objectives are covered by the tactical/campaign evidence.
