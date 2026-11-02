# Exported faction exclusions

Godot 4.7.2 exported the roster's authored `PackedStringArray` exclusions as empty arrays when their script defaults used `[]`. The unchanged source project retained the values, so source-only checks passed while the packaged HUD displayed forbidden Helix/Frontier Forward Refinery tiles with Bastion portraits. Frontier's aircraft-factory and heavy-aircraft exclusions were also lost.

`FactionRoster.gd` now initializes both fields with `PackedStringArray()`. The authored `.tres` data and every legal-choice portrait assertion remain intact. `BattleHudProductionRegression.gd` additionally checks the exact faction exclusions, the actual Worker build choices in English/Chinese, and real native state/movement binding when requested.

Export cache invalidation is also necessary: copying the old `.godot/exported` directory reused its bad converted resources after the script correction. Release staging now excludes this derived directory while retaining imported assets. A clean private export preserves all authored exclusions.

## Verification

| Check | Native | Fallback |
| --- | --- | --- |
| Source `BattleHudProductionRegression` | 0 failures / 6 sections | 0 failures / 6 sections |
| Fresh PCK `BattleHudProductionRegression` | 0 failures / 6 sections | 0 failures / 6 sections |
| Fresh PCK `FactionAsymmetryRegression` | 0 failures | 0 failures |
| Fresh PCK `FrontierAirContractsRegression` | 0 failures | 0 failures |

All final runtime checks exited 0 without errors or shutdown leaks. The native HUD assertions cover actual Worker state/crowd bindings for all three factions; [native-bind-probe.log](native-bind-probe.log) independently confirms the native classes loaded. `gdlint` and the changed-file whitespace check passed.

The PCK was exported from a private APFS clone of `inputs-retry-3` with only the two owned source/test files overlaid, its export cache cleared, and native staging matching the release builder. [targeted-checks.json](targeted-checks.json) records the exact commands, code hashes, PCK hash and six final results. The editor emitted a universal-library feature warning; the installed sidecar bound successfully in the guarded runtime checks.

## Preserved diagnosis

- `original-pack-*.log` retains the failures from the intermediate immutable package. Its inputs and results were not rewritten.
- `source-before.log` records the original source-only pass, showing why a packaged check was required.
- [minimal-reproducer.json](minimal-reproducer.json) contains a complete small export project and both script variants. Materialize the listed files in a private directory, write the desired variant to `script_path`, clear that directory's `.godot/exported`, and run its two commands. `minimal-before-*.log` shows empty exported exclusions; `minimal-after-*.log` shows the correct authored arrays.
- `stale-export-cache/` retains the six failures from overlaying the fix while retaining old converted resources.
- `missing-native-sidecar/` retains the rejected probe setup: its full input clone kept `native/.gdignore`, which hid the extension from export. The added native-binding assertions caught the fallback. The final private staging omits this ignore file, matching `stage_release_project`, and all six checks were repeated.

These are focused headless checks. They do not establish the pending full 139-script package result or deferred graphical/performance acceptance.
