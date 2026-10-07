# Low-health selection under pressure — 2026-10-06

The battle plan now shows a contextual **Low health · N** shortcut for owned combat and support units below 50% HP. It includes unarmed scouts and repair units that the Army shortcut does not select. Activating it selects those units and focuses the camera; their current orders and programs remain intact.

## Problem and behavior

In the retained earned Helix pressure state, defense advice correctly stays on **Protect your economy**, while the programmed tank remains at 13.15/64 HP at an unsupported safe point. Recovery advice has lower priority, and the Army shortcut mixes that tank with healthy combatants. The new shortcut makes low-health units discoverable without replacing emergency defense advice or automatically retreating them.

`SkirmishTactics.damaged_units` supplies the same below-50% cohort already used by recovery advice. `SkirmishPlan` exposes it to the panel. The cohort excludes engineers, structures, dead/queued units and enemies. Engineers retain their separate idle/endangered shortcut. Units at exactly 50% HP are excluded. The shortcut recomputes its targets on activation, so healing and deaths do not leave stale targets between quarter-second UI refreshes. It disappears when no eligible units remain; an empty activation preserves the existing selection.

The tooltip explains the threshold, preserved orders, manual Recover health command and program safe-point review. The footer uses a flow container to keep the shortcuts inside the panel when counts need another line. Existing battle-plan priority, recovery thresholds, service rules and costs are unchanged.

## Verification

The original implementation fails four missing-shortcut assertions: the earned pressure state and one mixed combat/support fixture for each faction. `before.log` and the three `before/` sources retain that baseline.

The final headless regression passes selection of infantry, tank, drone and repair robot; excludes a wounded enemy, wounded engineer and wounded HQ; checks the 50% boundary and dead-unit removal before the next refresh; hides the empty shortcut; and preserves current actions. The earned archive check also preserves tank HP, safe point, action, funds, paused clock and emergency-defense priority.

BattlePlan and GroundDefenseAdvice shared regressions pass, including their existing fog, counter-production and guidance-priority checks. All five changed/new scripts pass format and lint. Passing logs have no script/parse errors; existing renderer/ObjectDB/resource shutdown diagnostics remain distinct from test assertions.

## Native review

At 1280×720 and 150% UI scale, actual mouse clicks select the earned guard, Bastion cohort and Helix cohort. Native Enter activates the focused Frontier shortcut. The selected mixed groups contain the four intended roles. Fresh activation after healing/death selects only the two remaining eligible support/scout units. The initial native run has one test-harness failure because two checkpoints used the same screenshot filename; it is retained in `native.log`. The corrected `native-verified.log` exits zero.

Automated rendered follow-ups check command-button bounds after mixed selection, healthy/empty states, and a 99-population fixture with 95 low-health units. The extra units are explicit layout fixtures, not paid gameplay evidence. The pressure follow-up also marks an engineer as recently hit to exercise the longer endangered-engineer footer and wrapped shortcuts. Captures verify that the battle plan stays inside the viewport and does not cover the minimap. This is layout coverage, not performance acceptance.

The previously reported intermittent command-label capture discrepancy is not claimed fixed here. The mixed-selection follow-up records command bounds inside the scroll viewport; no UnitMenus layout change was made.

## Limits and next work

This improves access to existing recovery controls. It does not heal units, choose safe points, build support, or demonstrate better full-match survival. The earlier paid Service cradle continuation establishes that the stranded guard can recover with an explicit investment; novice discovery and sustained opening outcomes still need broader acceptance. Performance work remains deferred.

## Reproduce

Use fresh capture prefixes:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/LowHealthSelectionRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/LowHealthSelectionPreview.gd -- --captures=res://tmp/low-health-native
```

The native flow requires three mouse activations, then Enter for Frontier. `--automated` uses programmatic button activation for repeatable rendered geometry checks.
