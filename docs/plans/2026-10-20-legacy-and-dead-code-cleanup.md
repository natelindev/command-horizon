# Legacy-save and dead-code cleanup — 2026-10-20

Follow-up to [removing programmable units](2026-10-20-remove-programmable-units.md). Battle
saves accept only snapshot version 15, so code that existed only to read older battle saves is
dead. User decisions: delete the unreachable Air Corridor operation; keep the migrations of
campaign progress, key bindings and skirmish-setup preferences (they protect local files).
Legacy map scenes stay: the Expanded maps inherit from three of them, BastionDemo uses
BastionDesert and many regressions use them as fixtures.

## Stages

1. **Baseline.** Snapshot the current tree to `/tmp/rts-base2` and run the full headless suite.
2. **Legacy battle-save code.** Remove point-of-interest legacy counts, legacy mercenary
   contract roles, the legacy harvesting field radius, single-narrator story records and the
   optional hero/story mission records; require those records in version 15.
3. **Air Corridor.** Delete the mission, HUD, map, narration lines/audio, its Broken Foundry
   reward and save contract; keep its campaign-progress keys so existing progress files stay
   readable.
4. **Battle-plan advisor.** Delete the advisor retired from the HUD in 0.12.0
   (`SkirmishPlan`, `SkirmishPlanPanel`, `SkirmishOpening`, `SkirmishTactics`,
   `EconomyAdvice`, `EconomySupply`, `GroundDefenseAdvice`, the `show_battle_plan` option) and
   the tests that only exercised it; move helpers still used by playtest commanders into tests.
5. **Translation catalog.** Make `art/localization/*.tsv` reproduce `assets/translations/ui.csv`
   through `build_catalog.py` again, and drop entries no source text can produce.
6. **Docs.** AGENTS.md test/fixture notes, save docs, changelog.
7. **Verification.** Parse, gdformat/gdlint, archives, full headless suite against the baseline.
8. **Remaining references.** Regenerate the battle-voice reports without the removed transport
   voices, fix tooling counts that still assumed it, and update living docs that describe removed
   content as current.

## Agent progress

- [x] Stage 1 — baseline
- [x] Stage 2 — legacy battle-save code (also fixed the AI hiring a non-mercenary role at camps)
- [x] Stage 3 — Air Corridor (EvacTransport unit, voices and quarry backdrop removed too)
- [x] Stage 4 — battle-plan advisor (26 advisor-only tests deleted, helpers in `tests/UnitQueries.gd`)
- [x] Stage 5 — translation catalog (builder reproduces `ui.csv`; 223 direct rows moved to `interface.tsv`; 243 entries made dead by this change removed)
- [x] Stage 6 — docs (AGENTS.md save/test/localization notes, README, SAVE_LOAD, changelog)
- [x] Stage 7 — verification (full suite on both trees; every remaining difference is an improvement or reproduces only under load; 810 archives validate and round-trip)
- [x] Stage 8 — remaining references (voice cast verifier count, regenerated battle-audio and voice-identity reports, audio/licence counts, quarry kit and preview-command docs, living-doc headers)
