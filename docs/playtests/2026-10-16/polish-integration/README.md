# Polish integration — headless verification, 2026-10-16

The main working tree now contains the five previously isolated HUD, AI, construction,
map and animation workstreams, menu unification, final battle-voice corrections and the
first campaign conversation infrastructure. Changes are uncommitted. Original worktrees
remain intact; pre-integration patches and changed files are preserved under
`/private/tmp/rts-polish-backup-20261016/`.

Only headless Godot runs were used. No game window, editor UI, rendered preview or new
render capture was launched. Rendered appearance and GPU performance remain unverified.

## Changes completed in this continuation

- Integrated the five worktrees, resolved the shared HUD implementation and merged
  translation CSVs by key while preserving the existing voice changes.
- Unified main-menu and match-setup controls with the battle console theme; removed
  simulated telemetry and redundant copy, added responsive layout and a collapsible
  map legend. Headless tests cover English/Chinese, interface scaling, keyboard focus,
  faction-theme selection, difficulty selection and the visible Start action.
- Fixed Easy AI capacity accounting: pending mercenary hires count against the army cap
  in both camp hiring and factory production. Regression covers all three factions.
- Rebuilt four revised Frontier voice lines and eight Frontier drone clips; verified
  the other shipped voice Ogg files remained byte-identical to the pre-integration copy.
- Added ordered campaign dialogue support with stable line IDs, named speakers,
  localized captions, English dialogue recordings and optional portraits. Save state now
  retains the active line, audio position, remaining duration and pending scenes. Tactical
  pause freezes dialogue; skip releases narration suppression. Old history-only saves
  remain readable, and malformed/duplicated conversation state is rejected.
- Authored a first pass of 96 bilingual lines for the approved 16-mission outline in
  `docs/plans/hero-campaign-dialogue.json`. This is a writing draft; the new dialogue is
  not yet voiced or wired into playable missions. Existing narration remains in use.
- Repaired three stale test fixtures: weak-reference rally targets, portrait lookup after
  the custom roster-control change, and application of sealed program records before save.

## Automated results

`headless-results.json` records 40 passing checks, including the six existing campaign
story missions and a new two-speaker save-to-disk/resume regression. Each check has a
corresponding log. Dedicated corrected reruns supersede earlier failed fixtures.
All recorded checks exited 0 without GDScript parse/runtime errors.

Source-wide `gdformat --check source/` and `gdlint source/` pass, as do formatting/lint
for the changed regression scripts and `git diff --check`.

The difficulty test uses Bastion AI against a stationary opponent, with equal starting
resources and identical prices/gathering rules. It does not establish balance against
an active human or active AI, or the full Helix/Frontier difficulty curves.

| Measurement | Easy | Normal | Hard |
| --- | ---: | ---: | ---: |
| First attack, seconds | 181.3 | 121.7 | 75.7 |
| Army value at 600 seconds | 232 | 538 | 680 |
| Worker count | 5 | 6 | 8 |
| Largest attack wave | 6 | 21 | 25 |
| Materials mined | 731 | 846 | 1025 |

The fixed-step scale smoke test passed with 200 mobile units and 80 structures:
200/200 units moved and travelled, 160 fired, and 69 projectiles were live at peak.
Its timings were collected while the CPU voice audit was running and are not an
isolated performance baseline. This is simulation evidence, not rendered FPS evidence.

Audio build QC, `verify_battle_audio.py`, `verify_clean_mix.py` and nine voice unit tests
pass. The final full `verify_voice_identity.py` run passed on the shipped files:

- 390 speech clips, 45 speaker identities, 381 exact transcripts.
- Mean word error 0.006; maximum cross-speaker similarity 0.494 against a 0.5 limit.
- Every cloned crew voice matches its own cast reference better than any rival reference.
- Speech loudness −16.72 to −15.47 LUFS. The updated full audition reel is available.

Several existing headless tests still report ObjectDB/RID/resource cleanup warnings at
shutdown. A passing check here does not imply a leak-free shutdown; see individual logs.

## CPU stress findings

A separate real-time Lua run, after the voice audit finished, passed the same functional
assertions with 200 live Lua VMs. All 200 units moved, 99 fired, and the VMs performed
8,843 evaluations; peak per-VM memory was 59,868 bytes. The process reached approximately
511 MiB maximum resident memory and 415 MiB peak memory footprint (`/usr/bin/time -l`).

Performance acceptance **did not pass**: movement simulated 10.12 seconds in 13.93 wall
seconds and combat simulated 10.02 seconds in 15.77 wall seconds. This debug/headless
maximum-load scenario does not establish rendered or release-build frame rates.

The fixed-step field-query probe records 1.35/1.76 seconds in `is_observed` and
1.66/2.06 seconds in `nearby_units` over movement/combat phases, respectively. Inclusive
query timings overlap and must not be summed as independent costs. A separate diagnostic
run disabling procedural animation still takes 11.43/13.74 wall seconds for each ten
simulated seconds. Animation contributes to the cost but is not the only bottleneck.
No production animation or simulation behavior was disabled to make acceptance pass.
An additional uninstrumented fixed-step Lua run also passed functionally, taking
16.08/18.06 wall seconds for the two ten-second phases. Timing varies between runs;
these samples identify an unmet performance target, not a claimed optimization gain.
Raw stress/profile/diagnostic logs accompany this report.

## Remaining work

- Build the approved campaign content: hero presence, survival/progression and abilities;
  six Bastion mission revisions including a real Cinder Ford scenario; ten new Helix and
  Frontier missions; expanded maps, story triggers, progression/save schema and campaign UI.
- Expand and cast the dialogue, generate/QC the named-character voice recordings, and
  connect them to the playable missions. Review writing and the final listening reel.
- Balance difficulty against active opponents and finish additional dressing of the
  shared BastionDesert/BigArena arenas.
- Profile and optimize the completed game. GPU profiling and rendered HUD/menu/animation/
  construction/map review remain deferred until the user permits non-headless execution.
