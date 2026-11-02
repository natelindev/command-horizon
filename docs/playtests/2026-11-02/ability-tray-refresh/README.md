# Ability-tray signature aggregation

The retained [selected-200 v3 evidence](../tactical-formations/selected-v3-run-manifest.json) attributes 5.120 ms of native Low frame CPU to scene processing. A new headless caller-thread diagnostic isolated the ability tray: block updates cost approximately 0.006 ms each, whereas signature aggregation reached 2.703 ms per refresh with 200 controlled tanks and 33 retained six-member activation groups.

`AbilityTray._gather_faction_signature` previously scanned every group for every controlled unit to find the longest group cooldown. It now builds a temporary per-member maximum cooldown map once per synchronous refresh, and combines the two controlled-unit passes. `FactionSignatures.eligible` remains unchanged and is still queried live. No derived map persists between refreshes or enters saves.

The signature button also resolves its fallback recipients when clicked. A unit removed after the display refresh is excluded, and a newly eligible controlled unit is included. Existing selected-unit preference and direct activation validation remain in place.

| 200 tanks / 33 retained groups | Before median / p95 | After median / p95 |
| --- | --- | --- |
| Signature gathering | 2.703 / 2.848 ms | 1.554 / 1.660 ms |
| Complete tray refresh | 4.001 / 4.583 ms | 2.766 / 3.049 ms |

The signature median decreased 42.5%; the full refresh decreased 30.9%. With no groups, signature gathering measured 0.461→0.417 ms. These are forty repeated synchronous `CLOCK_THREAD_CPUTIME_ID` samples on the current native source fixture. They are **headless CPU diagnostics, not rendered frame qualification**; the outstanding graphical acceptance remains deferred.

[Comparison data](cpu-comparison.json), [before log](cpu-before.log), [after log](cpu-after.log) and [the exact diagnostic script](AbilityTrayProfile.gd) are retained. Reproduce the diagnostic with the project path, this script, `--fixed-fps 60`, and user arguments `--enable-native-kernels --native-unit-state --native-crowd-runtime`.

The expanded [native](AbilityTrayRegression-native.log) and [fallback](AbilityTrayRegression-fallback.log) ability-tray regressions pass with zero engine errors or warnings. They exercise actual commander and unit abilities, overlapping group maxima, the earliest recharge across members, immediate group expiry/removal, a stale displayed action after recipient removal and replacement, repeated refreshes across paused process frames, and actual version 22 snapshot restoration with identical signature readiness, cooldown and status. A completion guard prevents an interrupted helper from silently passing. The native case asserts actual native unit-state bindings.

The changes are confined to `source/match/hud/AbilityTray.gd` and `tests/headless/AbilityTrayRegression.gd`. The refresh interval, block controls, focus behavior and presentation assets are untouched. Both files were frozen for inclusion in the release agent's staged headless verification after the two local variants passed.
