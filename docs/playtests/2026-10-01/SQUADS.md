# Coordination squads and shared targeting

## Delivered behavior

Coordination unlocks explicitly created squads of up to 24 mobile units. Each unit belongs to at most one program squad; membership is independent of numeric selection groups. Creation and transfers validate the complete selection before mutation. Conventional units may join for manual commands, and the UI reports the chip-ready count. Rename, Select, Add selected, Leave and Disband are available. Creation, transfer and disband preserve individual queues and programs. Dead members are removed and empty squads disappear.

Spread fire, Focus fire and Independent policies influence existing legal candidate lists. Repair programs spread service targets under shared policies. Soft claims expire after 0.8 simulation seconds and release on manual override, removal, policy changes and death. Claims never extend sight, range, allowed domains, assigned sectors or line of fire. They are preferences, not a guarantee against overkill or synchronized ballistic arrivals.

Squads own bounded JSON-compatible state: 8 KiB serialized UTF-8, bounded keys/depth/collection sizes and bounded validation traversal. Access requires running, chip-ready membership. Reads/writes isolate values; rejected writes retain previous data. No engine objects or nonfinite numbers. This is internal infrastructure for the later custom runtime, not Lua execution or a player-facing state editor.

## Verification

- `SquadRegression.gd`: both factions; research gate, mixed readiness, preserved manual queues, one-squad membership, explicit transfer, foreign/building rejection, atomic cap rejection, 24-member cap, rename normalization, death/empty cleanup and disband preserving programs. State permission/isolation/UTF-8 size/depth/type tests pass. Fire policy, expiry/pause/manual release, actual preset candidate selection, hidden targets and repair spreading pass.
- `SquadPreview.gd`: real 720p Create/Rename/policy/Select/Leave/Add/Disband controls; five-member selection with three programmable members; paused Guard assignment and Apply; running programs after resume. UI bounds and rendered review pass.
- Existing `ProgramRegression.gd`, `OrdersRegression.gd`, `CoordinationRegression.gd`, `Skirmish.gd` and rendered `ProgramPreview.gd` pass. These exercise queue authority/service handoffs, factory inheritance/rally precedence, research/fees/lab loss, full roster/faction pairings and AI economy/attacks.
- Format/lint checks for all changed scripts and `git diff --check` pass.

## 200-unit measurement

`ScaleBenchmark.gd -- --squads`, Godot 4.6 / Metal / M1 Pro, rendered 1920×1080, fixed 60 Hz simulation, uncapped throughput. 200 units in ten squads (four groups of 24 and one group of four per side), 80 structures, 32 resource deposits. Elevated HP keeps the population alive; this is not balance evidence. No other gameplay test ran during the final measurement.

| Phase | Average frame | p95 frame |
| --- | ---: | ---: |
| Advancing | 19.49 ms | 30.10 ms |
| Combat | 25.31 ms | 47.20 ms |

All 200 units moved; 116 weapons fired. Sampled peaks: 122 target claims, 27 live projectiles, 25 tracers. The test asserts meaningful claim participation. The first implementation averaged 20.54/28.02 ms; targeting now builds one claim snapshot per decision instead of repeatedly filtering claims for every candidate. Runs have movement/render variation, so these measurements do not establish an isolated optimization speedup.

Frame spikes and stable 60 FPS remain open, along with Windows measurements and long-match profiling. Existing navigation GPU-readback warnings and shutdown-only resource/RID diagnostics remain; no scenario assertion or script errors remain in the passing runs.

## Scope and review

Persistent game saves, custom Lua/visual state access, role-specific presets and faction coordination abilities remain pending. This pass does not introduce automatic recruitment, squad membership changes by scripts, rigid formations or cross-map targeting.

- [Paused squad and program controls](../../../art/skirmish/squad-paused-720p.png)
- [Running squad](../../../art/skirmish/squad-running-720p.png)
- [200-unit workload](../../../art/skirmish/scale-200.png)
