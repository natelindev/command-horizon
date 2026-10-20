# Remove the Lua runtime and programmable-unit system — 2026-10-20

The user approved removing the entire Lua script engine and the remaining
program/preset system. There are no saves to preserve, so battle snapshots drop
all backward compatibility.

## Findings

- Release builds already exclude the native Lua library; the battle UI has no
  reachable program editor, LLM assistant, program panel, squad panel or chip
  installation. `SkirmishAI._arm_units_with_programs` is never called, AI
  `fit_chips` is always false and the `chip_installed` meta is never read.
- Live dependencies on the program system:
  - Signature abilities require `unit.program.ready_to_run()` (always true,
    because `UnitProgram._ready` marks itself installed).
  - `Player.basic_programs_unlocked()` (vehicle factory + lab completed) gates
    Coordination and technology research, First Orders and the AI.
  - Broken Foundry and Command Horizon use guard / fire-support / service
    presets for enemy posts.
  - `ManualOrders`, `AlliedDefense`, `BattleAlerts`, `BattleRecord`,
    `SkirmishOpening`, production queues and the save format read program,
    chip or squad state.

## Stages

1. **Baseline.** Import the project and record the current result of the
   release regressions plus program-adjacent gameplay, save and campaign tests.
2. **Lua/LLM/arena layer.** Delete `native/rts_lua`, `source/native`,
   `assets/programs`, Lua runtime/action/draft check, editors, visual rules,
   LLM provider code, program HUD panels, the program arena and its launch
   hook, and Lua-only release/export/gitignore entries.
3. **Program system.** Delete `UnitProgram`, presets, specialists, chip
   installation, factory programs, squads and recovery advice. Replace:
   - signature eligibility: no program check;
   - `basic_programs_unlocked()` → `lab_research_unlocked()`;
   - campaign posts → native Guard plus a small field-repair step for posted
     repair robots;
   - remove chip costs, fitted-chip production, program milestones, chip
     guidance steps, squad alerts and program assignment input.
4. **Save format.** Write and accept only snapshot version 15. Remove legacy
   version branches and program, squad, chip and Lua records.
5. **Tests.** Delete tests for removed features; update retained tests;
   regenerate the contact-approach fixture; update the release test list.
6. **Docs and localization.** Remove Lua runtime docs, update behavior/save
   docs, README and changelog; drop unreferenced program translation entries.
7. **Verification.** Import, gdformat/gdlint, headless regressions compared
   with the baseline, rendered HUD preview.

## Agent progress

- [x] Stage 1 — baseline (separate worktree at 88d9d99d)
- [x] Stage 2 — Lua/LLM/arena layer
- [x] Stage 3 — program system (campaign posts use `CampaignPosts.gd`)
- [x] Stage 4 — save format (version 15 only; source loads, gdformat/gdlint clean)
- [x] Stage 5 — tests (program-only tests deleted; shared bases `MatchFixture.gd`,
  `PreviewFixture.gd`, `EarnedServiceRecoveryPreview.gd`; 817 `docs/playtests` archives and the
  contact fixture converted to v15 with identities preserved, or canonicalised where the old
  loader had inserted a campaign hero)
- [x] Stage 6 — docs and localization (466 dead program translation rows pruned;
  program TSV catalogs removed)
- [x] Stage 7 — verification (full headless suite on both trees: 191 vs 179 passing; every
  remaining failure matches baseline or is flaky on both; release gates pass except
  BattlefieldExpansion and MapPreview, which fail identically on baseline; HUD preview
  reviewed; all 818 archives validate, keep identities and round-trip)
