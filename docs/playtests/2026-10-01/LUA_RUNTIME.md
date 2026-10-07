# Lua runtime and game-action integration

## Delivered

Pinned Lua 5.5.1 with its published GC fix, narrow Godot C++ extension, explicit native limits and reproducible dependency/build sources. Sandbox errors cannot longjmp across C++/Godot object lifetimes. A generated registration file prevents fresh source checkouts from auto-loading a missing native library; that missing-library path crashed Godot 4.6 on macOS during initial integration and was corrected in the build workflow.

`LuaRuntime.gd` validates source and output, isolates explicit state, preserves working code on invalid edits and starts clean on Resume. `LuaAction.gd` connects five intents to actual game actions with bounded observations and current legality checks. Both factions retain chip/technology gates, direct-order priority, pause and non-pursuing idle defense after faults. Program errors are visible with bounded text and deduplicated local-player notifications. This is a developer integration slice; custom source authoring/saving through the game UI is not delivered yet.

## Verification

- Clean checksum-pinned fetch and patch, byte-for-byte source comparison against the actual build, and idempotent reuse: passed.
- `run_sanitizers.py`: **569 assertions passed** with Clang AddressSanitizer and UndefinedBehaviorSanitizer. Covers valid data, infinite loops (including initialization), memory/string/recursive exhaustion, syntax/bytecode/non-function sources, parser nesting, cyclic/sparse/mixed-type outputs, non-finite numbers, depth/node/string bounds, invalid UTF-8/NUL output, unavailable host APIs and 100 repeated OOM → clean-recompile cycles. No sanitizer diagnostics.
- `LuaSandboxRegression.gd`: passed actual Godot C++ bridge, per-VM state isolation, copied snapshots, clean Resume, invalid-edit preservation, strict intents, 16 KiB state, UTF-8/NUL rejection, source/input guards, object/cycle rejection, dense arrays and Unicode. A separate fresh temporary Godot project verified controlled runtime-unavailable behavior without loading the extension.
- `LuaProgramRegression.gd`: passed both factions' actual chip/technology gates, manual movement and invalid edits, paused evaluations, anchor/safe movement, missing assignments, real projectile damage, hidden/stale target rejection, stable capped contacts, repair capability/shared healing, missing/foreign/destroyed escort handling, fault Hold/idle defense, no auto-restart and clean Resume. An initial movement assertion used an unwalkable point; observation confirmed normal navigation projection. The corrected test checks arrival within 0.5 m of the authoritative nearest navigable point, while retaining the requested destination.
- Existing `ProgramRegression.gd`, `SpecialistRegression.gd` and `OrdersRegression.gd`: passed with the native extension and shared Hold changes.
- `LuaPreview.gd`: passed actual rendered Running/Error UI, Manual control and paused Resume at 1280×720. Long errors remain two visible reason lines with full hover trace. The existing `ProgramPreview.gd` preset save/load, assignment, paused Apply and factory/research UI flow also passes. [Running](../../../art/skirmish/lua-running-720p.png), [budget fault](../../../art/skirmish/lua-fault-720p.png), [long diagnostic](../../../art/skirmish/lua-long-error-720p.png) inspected visually.
- Native build, Godot editor import, changed-script formatting/lint and whitespace checks pass. The native dynamic library exports only the GDExtension entry point and depends on system C/C++ libraries; there is no external Lua shared-library dependency.

## Measured workloads

Hardware: development Mac, Apple M1 Pro; Godot 4.6, Metal Forward+, 1920×1080, fixed simulation delta 1/60, uncapped rendering. The microbenchmark is headless. These are developer measurements, not cross-platform guarantees.

| Workload | Result |
| --- | --- |
| Runtime microbenchmark: 200 private VMs × five evaluations, 32 contacts each | 53.066 ms total for 1,000 calls; highest VM allocation 34,482 bytes. Does not include the rendered battle or perception queries. |
| Initial full 200-unit Lua workload, movement | 29.52 ms mean / 54.98 ms p95 |
| Initial full workload, combat | 39.49 ms mean / 62.84 ms p95 |
| After removing duplicate perception work, movement | 27.93 ms mean / 44.17 ms p95 |
| After removing duplicate perception work, combat | 34.13 ms mean / 55.68 ms p95 |

The full workload contains 200 mobile units across both factions, 80 structures and 32 resource nodes. Every unit travelled and had a live Lua VM; no VM faulted. Final combat phase recorded 8,936 program evaluations, 99 units firing, 11 sampled live projectiles/tracers and peak VM allocation 59,868 bytes. Elevated health keeps the workload populated; it is not a balance test. Scripted units move to assignments, choose legal targets and heal through shared service rules. Snapshot construction now ranks contacts once, stops observation after proving the 32-contact cap/truncation flag and avoids redundant visibility queries when creating already-observed records; attack application still revalidates legality.

**Performance acceptance remains open:** 34.13 ms average combat and 55.68 ms p95 do not establish stable 30 FPS, much less 60 FPS. This run also does not exercise the target 300 transient effects or Lua squad-shared memory. [Rendered workload](../../../art/skirmish/scale-lua.png).

Some gameplay suites retain existing navigation GPU-readback warnings and shutdown-only resource/RID diagnostics; the standalone sandbox suite and native sanitizers pass without them. No gameplay assertion or GDScript error remains in the verified runs. Windows/Linux native builds, exported packages, independent security review and broader fuzzing remain unverified.

## Next gate

Finish custom-program draft/editor and exact-version library/factory records, visual-to-Lua rules, arena tests/trace, API examples and the first no-code mission. Continue profiling Lua snapshot cost and the full 200-unit simulation. LLM drafting and save/load remain later dependencies. No completion claim is made for the full programmable-combat or product acceptance gates.
