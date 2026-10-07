# Mixed-unit recovery coverage — 2026-10-06

**Recover health** now previews partial facility coverage on the button, such as **3/4 supported**. The denominator counts wounded selected mobile units, excluding healthy members. When no wounded member has support, the disabled button shows **0/N supported**. Fully supported and fully healthy selections retain the ordinary label; healthy selections remain disabled.

The tooltip and accessibility description name missing service by faction and show the number of affected units, for example **Flight deck: 1 unit**. They explicitly say unsupported units keep their orders. The numbers describe units needing that service, not a count of buildings to construct.

## Implementation and evidence

`DirectOrders.recovery_state` derives the label and missing-service summary from the same compatible-facility search that prepares the orders. `UnitMenus` refreshes the label with the existing tooltip and enabled state. Nearest-service selection, manual/program authority, queue rules, payment and healing behavior are unchanged. Having facility support does not promise a free service slot, a safe/reachable route or immediate healing.

The original sources fail eighteen feedback assertions across Bastion, Helix and Frontier. Final coverage tests pass partial support, faction facility names, affected-unit counts, unfinished facilities, zero support, new completed flight service and fully healthy selection. Actual activation orders the supported infantry/tank/repair robot while preserving the unsupported scout's existing move and the healthy infantry's move. Paused time and resources stay unchanged.

The shared RecoveryOrders regression also passes its live healing, queue, manual/program authority, service loss, nearest-facility, active/pending save restoration and full-health completion checks. All four changed/new scripts pass format and lint. Passing logs have no script/parse errors; existing navigation-readback warnings and shutdown diagnostics remain in the raw logs.

## Native review

The native 1280×720, 150%-scale Helix fixture contains five selected units, four wounded. A real mouse click on **Recover health · 3/4 supported** passes the same authority assertions. Four PNGs show 3/4, 1/4, 0/4 and full support; the labels fit the command panel. Tooltip content is asserted by the regression, not established by a captured hover popup. The native harness also exercises the other factions programmatically and exits zero.

These are controlled Advanced-start fixtures with strategic AI disabled. Missing scouts/facilities are spawned for coverage, and construction progress is varied to test availability. They are not paid opening or survival evidence. The new feedback helps players predict partial commands; broader opening survival and gameplay/content acceptance remain open. Performance remains deferred.

## Reproduction

Use a fresh capture prefix:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/RecoveryCoverageRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/RecoveryCoveragePreview.gd -- --captures=res://tmp/recovery-coverage
```

The native harness waits for one Helix Recover health click. Original sources, logs, captures and hashes are in `recovery-coverage/`.
