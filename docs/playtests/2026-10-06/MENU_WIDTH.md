# Selected-unit control width audit — 2026-10-06

The earlier recovery capture appeared to cut off the rightmost Attack move label. Fresh native and headless reproductions do not reproduce that clipping. No shipping layout change is justified by these results; the discrepancy remains unproven rather than fixed.

## What was exercised

`MenuWidthRegression.gd` restores the earned Helix unsupported-guard archive, checks the panel and its visible buttons/labels/text fields against the horizontal scroll viewport, and repeats after scrolling the program reason into view. It exercises a valid long shortcut profile (Ctrl+Alt+PageUp, Ctrl+Alt+PageDown and Ctrl+Alt+End), then 100%, 125% and 150% interface-scale transitions at a physical 1280×720 window.

The test then checks Worker, Infantry, Tank, Drone, RepairRobot and VehicleFactory selections for Bastion, Helix and Frontier. These are Advanced-start layout fixtures; missing drone/repair units are explicitly spawned for coverage, and the inherited factory fixture buys three tanks. They are not paid opening or balance evidence. Selection and layout inspection preserve paused simulation time, stockpiles and the selected unit's action.

The final headless and rendered suites each check 46 layout states: the earned state, remapped state, three scale states and eighteen faction/role selections, each before and after scrolling. Both pass with zero failures. Three new test scripts pass formatting and lint. Passing logs contain no script/parse errors; existing renderer/resource shutdown diagnostics remain visible in the logs.

The initial `remapped-before.log` experiment inadvertently reset interface scale through the options restore API; it is exploratory evidence only. The final checks explicitly preserve the intended scale and window dimensions. The `before/` files are unchanged shipping-source snapshots, not a failing implementation baseline.

## Native command access

`MenuWidthPreview.gd --interactive` additionally verifies actual input in the paused earned state:

1. A mouse click activates the rightmost Attack move button.
2. Escape cancels the destination assignment.
3. The harness focuses and reveals Set safe point; native Enter activates it.
4. Escape cancels the safe-point assignment.

The harness checks that the original guard action, safe point, funds and paused clock remain unchanged. It records `NATIVE WIDTH: mouse, keyboard and cancellation passed`, and the complete native suite exits zero. This verifies activation from an already focused control; it does not establish the full Tab traversal order.

The retained final images show the earned guard, long remapped shortcuts, Bastion engineer, Helix tank and Frontier repair robot. The default command row occupies 470 pixels within the scroll area. The remapped row expands to 569 pixels and remains fully inside the viewport. Text remains readable and keyboard focus is visible.

## Exact recovery sequence follow-up

`EarnedMenuWidthPreview.gd` repeats the previous recovery preview's resize, camera placement, selection, scrolling and capture sequence with measured command bounds. It restores the same paid Helix state, constructs the same 25 M / 10 E Service cradle, and keeps enemy AI active. All four stages—unsupported, foundation, healing and returned—keep the command controls within their horizontal clip rectangle. The guard returns at 52.74 HP after 56.9 simulation seconds in this observation. This run uses automatic review checkpoints rather than native Space input; the earlier program-recovery report retains the manual continuation evidence.

## Limits and next action

These checks strengthen coverage of selected-unit controls, settings transitions and cancellation authority. They do not explain the earlier single capture, prove absence of every transient layout defect, or validate every possible keybinding/selection/resolution. No game rules, costs, orders or UI source were changed in this audit.

The broader goal remains active. Return to gameplay/content acceptance, especially sustained opening survival and timely recovery investment, rather than treating additional passing layout tests as proof of a complete game. Performance remains deferred.

## Reproduce

Use fresh capture prefixes to preserve evidence:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/MenuWidthRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/MenuWidthPreview.gd -- --interactive --captures=res://tmp/menu-width
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/EarnedMenuWidthPreview.gd -- --captures=res://tmp/earned-menu-width
```
