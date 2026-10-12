# Mechanics improvement pass — 2026-10-12

This pass changes game mechanics and the text for a targeting choice. Models,
textures, materials, lighting, art style and interface styling are unchanged.
Unit health, damage, costs, production times, resource stock, difficulty timings
and victory rules are unchanged.

## Changed behavior

- **Group destinations:** pack actual reachable positions so map edges and
  coincident origins do not collapse the army onto overlapping destinations.
  Preserve separate ground/air groups and exact single-unit targets. Ground-plane
  coordinates remain independent of navigation-mesh bake height. The full
  100-unit mixed armor selection is checked at both base corners and the center
  for all three factions, with no overlaps or off-mesh slots.
- **Mixed attack-move:** selected unarmed support advances with the combatants
  using ordinary Move. An unarmed-only selection continues to use Move.
- **Automatic fire:** prefer threats and suitable weapon counters, then wounded
  targets with comparable effectiveness. Deprioritize a target already covered
  by lethal unresolved allied projectiles when another legal target is available.
  Claims use actual projectiles, not intentions, and are rebuilt from live state.
- **Garrison fire:** use the same target choice and complete legal firing range,
  including the host's range contribution.
- **Preset targeting:** fresh presets default to **Best counter**. An available
  legal shot takes precedence over pursuing another counter. Existing assignment
  boundaries, visibility, fire obstruction, squad policy and retreat rules apply.
  Explicit and saved nearest, lowest-health and armor-first priorities retain
  their behavior. Lua and visual rule source remains under the player's control.
- **Recovery:** player and AI service choices use reachable route distance rather
  than straight-line distance. A nearer facility on an inaccessible island does
  not prevent using another reachable facility.
- **Cargo delivery:** automatic HQ selection uses reachable delivery routes and
  existing contact limits. Ownership-loss scenarios preserve cargo and already
  retire invalid operations; no speculative ownership repair was introduced.
- **Resume authority:** stop the old execution immediately when Resume is
  accepted, including while paused. Start the program on the next simulation
  tick. Defensive assistance respects the Ready state and cannot replace that
  pending request. Manual orders continue to override programs explicitly.
- **AI spending under raids:** preserve emergency worker/counter/infantry funds
  before optional construction, and let urgent production use optional-building
  savings. Peaceful technology saving and critical HQ/power/anti-air construction
  retain their precedence. Every purchase uses its normal cost.

## Regression evidence

`tests/headless/MechanicsRegression.gd` exercises Bastion, Helix and Frontier:
boundary and coincident-origin slots, automatic counters, lethal incoming shots,
garrison range, preset/explicit priorities, ownership loss, pending Resume,
mixed support orders, disconnected service/HQ routes and paid raid response.

The original gameplay source is compared in an isolated checkout. The final
verification summary and original failures are retained beside this report.
The final mechanics regression reports **18 distinct failed assertions on the
original source and zero on the changed source**, exercising all three factions.
The formation-cap regression also fails on the original source and passes with
the expanded slot search. These are assertion counts, not independent bug counts.
Fixture corrections include deferred script loading after autoload initialization,
faction-specific infantry prices and explicit synchronization of the isolated
navigation map. Failed fixture attempts are not gameplay evidence.

Saved Lua/visual records keep their canonical configuration separate from fresh
preset defaults. Both legacy and transitional sealed records retain their exact
hashes. The preserved visual-guard fixture and pre-block guard archives pass.

Existing order/program/recovery/squad fixtures were also corrected: factory/lab
or added flight service exceeded the fixture's power supply after earlier economy
tuning; a previous Hold-programmed factory unit occupied the next rally case's
exit. These fixes declare the intended test conditions and preserve separate
low-power and factory-egress coverage. No production rule is bypassed in gameplay.
Guard-area fixtures now isolate spotter loss from the current tank's own sight,
and artillery standoff checks allow its actual travel, deployment and preparation
time. Both original suites failed those stale assumptions before this pass.

Rendered direct-order verification uses engine-routed mouse/key input at
1280×720 / 150% interface scale, including targeting, queueing, cancellation,
remapping, held-button unit death, live Move versus attack-move and campaign
commands. This is not a physical native-input or novice-participant claim.

## Broader acceptance

Complete-match victories, faction win rates, novice usability and intended match
pacing require further playtesting. Successful regressions do not close those
gates. The initial paid Bastion reference run lost at 513.63 simulation seconds,
with 44 produced units and four enemy attacks, before reaching its nine-unit
assault condition. The later run with role-aware presets is retained separately.
That later run also lost before assault, at 447.75 seconds, with 27 produced units
and three enemy attacks. These are different asynchronous trajectories, not a
deterministic paired comparison or evidence of a balance improvement.

The archived AI engineer check also fails under original gameplay: the worker
spends most of its first 60 seconds constructing two paid structures before
resuming harvesting. This does not demonstrate a new movement regression. The
original/current Split Signal preset encounter and Broken Foundry batch-count
failures are retained and reviewed separately from the new targeted checks.

Some suites retain engine resource/shader cleanup warnings. Campaign checks also
expose pre-existing missing radio-chirp imports and a mission-truck icon. These
resource diagnostics are not accepted as a clean release/export pass. Performance
optimization remains outside this pass.

## Final checks — 2026-10-13

- **33 headless suites pass**, covering the new mechanics, 100-unit slot
  correctness, physical navigation/egress, orders, recovery, resource flow,
  programs/squads/legacy records, heroes, neutral interaction, AI, save/load,
  localization and four campaign checks.
- **Three broader suites remain failing:** archived AI engineer income timing,
  Split Signal's preset-only victory strategy, and Broken Foundry's surviving
  tank count. The same cases fail with the original gameplay source.
- Rendered direct orders pass, including the fourth targeting-priority choice.
- Godot import, changed-script formatting/lint and diff whitespace checks pass.
- [Summary and source hashes](mechanics/summary.json) list individual results and
  retained logs. These results do not establish overall balance or release readiness.

## Reproduction

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/MechanicsRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/NavigationRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/SignatureRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/RecoveryOrdersRegression.gd
```
