# Game polish pass

## Scope

Implement the approved review: a compact contextual HUD, clear command feedback
and smooth cursor-centered zoom, faction-specific ground treatment around bases,
readable combat impact, measured large-battle optimization, and clearer opening
mission guidance. Preserve the existing uncommitted command and neutral-site work.

## Stages

1. **Baseline and HUD** — record current performance; collapse the empty console,
   fit selected-unit panels to content, and simplify skirmish objectives. Preserve
   keyboard access, readable text, production queues and English/Chinese layouts.
2. **Commands and camera** — contextual pointer feedback, accepted/rejected order
   feedback at the action, clearer behavior naming, smooth cursor-centered zoom.
   Verify replacement/queued orders, tactical pause, UI capture and camera bounds.
3. **World presentation** — faction-specific foundations and worn approaches,
   with consistent normal-zoom role cues. Decorative work must leave navigation,
   construction rules, visibility and saved-game gameplay state unchanged.
4. **Combat** — tune the existing effects and audio hierarchy for weapon weight
   and crowded fights; preserve damage, pause, fog and reduced-flash behavior.
5. **Performance** — profile the current maximum-population workload; optimize
   measured costs, compare the same rendered workload before/after, and check
   ordinary gameplay. Report remaining platform and frame-time limitations.
6. **Opening experience and acceptance** — improve Supply Line / First Orders
   guidance around the next actionable decision; verify mission progression and
   debrief, run focused regressions, and review rendered faction HUDs and gameplay.

## Acceptance

- Empty selection exposes the battlefield; populated decks fit their contents.
- Commands give timely, legible feedback without changing order semantics.
- Camera zoom preserves the point under the pointer unless constrained by map bounds.
- Base details and combat presentation remain readable at normal zoom and in fog.
- Performance improvements are supported by matched measurements, not estimates.
- Opening guidance follows real mission state and remains useful after save/load.
- Render `tests/rendered/HudConsolePreview.gd` without `--headless`; inspect captures.
- New-player observation and Windows measurements require those actual environments;
  automated/local checks must not be described as substitute evidence.

## Agent progress

- **Stages 1–4 complete:** compact contextual HUD, shared cursor/order feedback,
  smooth anchored zoom, faction foundations, specialist silhouettes, and combat
  effects/audio hierarchy implemented and verified. Existing uncommitted work was
  preserved; no HUD texture was edited.
- **Stage 5 complete locally:** profiled the maximum-population workload and
  optimized route lookup and walker pose updates. Matched Mac combat mean fell
  from 28.40 ms to 27.18 / 26.85 ms. Two native macOS release stress runs pass;
  combat p95 is 28.70 / 28.47 ms and command-feedback submission p95 is
  28.54 / 28.41 ms. Windows verification remains outstanding.
- **Stage 6 implementation complete:** state-aware First Orders instructions,
  Supply Line repair selection/advice, practical debrief guidance and Chinese
  translations. Fixed cinematic exit cleanup found during rendered review.
  Actual new-player observation remains outstanding; a protocol is documented.
- **Acceptance complete locally:** focused regressions pass; 66 faction HUD,
  22 gameplay and 18 combat captures produced and reviewed at representative
  states. Rendered audio verifies spatial mix, saturation, fog, pause and ducking.
  Source formatting/lint and whitespace checks pass.
- Broader legacy Lua/save fixtures, local native-extension cache and baseline
  authored scenery-clearance failures are recorded separately. Early release
  movement delays were not reproduced by the final instrumented runs; their cause
  remains unverified. No full-suite, Windows or human-playtest pass is claimed.
- Reports: [acceptance](../playtests/2026-10-19/game-polish.md) and
  [performance](../performance/GAME_POLISH.md), with machine-readable evidence.
