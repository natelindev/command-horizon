# Opening repair-support discovery — 2026-10-06

The [armor-preservation experiment](ARMOR_PRESERVATION.md) established a paid recovery-to-programming path, while the existing battle plan exposed missing service only after its opening/programming steps. A wounded army could therefore receive lab or urgent defense advice without a visible route to repair support.

## Delivered behavior

The battle plan now offers an optional support action beside its primary action when combat/support units below 50% health lack the appropriate facility or a compatible repair robot. It names the faction facility and exact material/electronics cost; a shortage shows the remaining amount, and a paid foundation shows “Finish” rather than another purchase. Missing prerequisites use the existing building/funding advice. The shortcut is hidden when the primary advice already covers that same step, when support is available, or when the cohort is healthy.

Activation recomputes support needs and selects an engineer using the existing selection controls. It preserves unit actions, queued orders, resources, paused time and primary advice. Players choose placement, construction and retreat orders. It does not automatically build support or commandeer wounded units. Tooltips explain the missing facility, funding/construction step and selection behavior.

`SkirmishTactics.support_step` shares service discovery with the existing later-game repair advice. `SkirmishPlan` exposes it to the panel. The panel retains its existing collapsing behavior and puts the two actions in one row to preserve space for the minimap.

## Verification

- Four original missing-shortcut assertions reproduce in the earned wounded Helix defense and the three faction opening fixtures.
- Corrected headless and native support suites pass: faction names/prices, shortages, paid foundations, prerequisite routing, duplicate suppression, completed/mobile support, healed cohorts and stale activation.
- Native 1280×720 / 150% interface checks use mouse input for the earned state, Bastion and Helix, plus focused Enter for Frontier. Engineer selection preserves the original guard/orders, stockpiles and pause; the opening fixtures retain lab progression.
- Shared battle-plan, low-health selection and partial-recovery coverage regressions pass.
- Five touched scripts pass formatting and lint checks.

The rendered large-cohort check also passes with 95 low-health units and under-fire advice. Its wrapped shortcuts remain above the minimap; the longer funding advice likewise fits. Final captures retain the faction-specific full labels rather than an ambiguous generic repair-price label.

The first vertical-button layout overlapped the minimap in seven native checks. The final shared action row passes the same layout checks while retaining full facility names and prices. Earlier fixture attempts incorrectly inspected building order queues and expected a duplicate prerequisite shortcut; their script/parse and assertion logs are retained separately and are not counted as gameplay failures. An intermediate compact-label preview was stopped for revision before completion. The native app closes after its last assertion, so computer-use reporting “App quit” after the final Enter is corroborated by the completed zero-failure log.

Known navigation readback warnings and renderer/resource shutdown diagnostics remain in the test logs. Tooltip content is checked as text; tooltip popup layout is not a native acceptance claim. This UI change does not establish improved survival or balance. Wider faction/map/content and novice acceptance remain open; performance remains deferred.

## Reproduce

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/SupportDiscoveryRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/SupportDiscoveryPreview.gd -- --captures=res://tmp/support-review
```

The native review waits for mouse activation in the earned/Bastion/Helix cases and focused Enter in Frontier. Use a fresh capture prefix; `--automated` exercises the rendered assertions without native input.
